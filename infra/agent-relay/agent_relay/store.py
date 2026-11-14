"""SQLite storage: agents, tokens, A2A-shaped tasks and per-recipient delivery events."""

import hashlib
import json
import secrets
import sqlite3
import threading
import time
from datetime import datetime, timezone

TERMINAL = {"TASK_STATE_COMPLETED", "TASK_STATE_FAILED", "TASK_STATE_CANCELED", "TASK_STATE_REJECTED"}
SCHEMA = """
CREATE TABLE IF NOT EXISTS agents (handle TEXT PRIMARY KEY, email TEXT, created_at TEXT, last_seen REAL, last_repo TEXT);
CREATE TABLE IF NOT EXISTS tokens (hash TEXT PRIMARY KEY, handle TEXT NOT NULL, label TEXT, created_at TEXT, revoked INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS tasks (id TEXT PRIMARY KEY, from_handle TEXT, to_handle TEXT, to_repo TEXT, kind TEXT,
  state TEXT, created_at TEXT, updated_at TEXT, doc TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS tasks_to ON tasks(to_handle, state);
CREATE INDEX IF NOT EXISTS tasks_from ON tasks(from_handle, state);
CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY AUTOINCREMENT, handle TEXT, repo TEXT, task_id TEXT,
  type TEXT, wake INTEGER, delivered INTEGER DEFAULT 0, created_at TEXT);
CREATE INDEX IF NOT EXISTS events_pending ON events(handle, delivered);
"""


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def new_id(prefix: str) -> str:
    return f"{prefix}_{secrets.token_hex(6)}"


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


class Store:
    def __init__(self, path: str):
        self.db = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.lock = threading.RLock()
        self.changed = threading.Condition(self.lock)
        with self.lock:
            if path != ":memory:":
                self.db.execute("PRAGMA journal_mode=WAL")
            self.db.executescript(SCHEMA)

    # --- agents and tokens ---
    def issue_token(self, handle: str, email: str | None = None, label: str | None = None) -> str:
        token = "prt_" + secrets.token_urlsafe(32)
        with self.lock:
            self.db.execute(
                "INSERT INTO agents(handle, email, created_at) VALUES(?,?,?) ON CONFLICT(handle) DO UPDATE SET "
                "email=COALESCE(excluded.email, agents.email)",
                (handle, email, now()),
            )
            self.db.execute(
                "INSERT INTO tokens(hash, handle, label, created_at) VALUES(?,?,?,?)",
                (hash_token(token), handle, label, now()),
            )
        return token

    def revoke_tokens(self, handle: str) -> int:
        with self.lock:
            return self.db.execute("UPDATE tokens SET revoked=1 WHERE handle=? AND revoked=0", (handle,)).rowcount

    def handle_for_token(self, token: str) -> str | None:
        with self.lock:
            row = self.db.execute(
                "SELECT handle FROM tokens WHERE hash=? AND revoked=0", (hash_token(token),)
            ).fetchone()
        return row["handle"] if row else None

    def ensure_agent(self, handle: str, email: str | None = None) -> None:
        with self.lock:
            self.db.execute(
                "INSERT INTO agents(handle, email, created_at) VALUES(?,?,?) ON CONFLICT(handle) DO NOTHING",
                (handle, email, now()),
            )

    def touch(self, handle: str, repo: str | None) -> None:
        with self.lock:
            self.db.execute(
                "UPDATE agents SET last_seen=?, last_repo=COALESCE(?, last_repo) WHERE handle=?",
                (time.time(), repo or None, handle),
            )

    def agents(self) -> list[dict]:
        with self.lock:
            rows = self.db.execute("SELECT handle, email, last_seen, last_repo FROM agents ORDER BY handle").fetchall()
        return [dict(r) for r in rows]

    def agent(self, handle: str) -> dict | None:
        with self.lock:
            row = self.db.execute(
                "SELECT handle, email, last_seen, last_repo FROM agents WHERE handle=?", (handle,)
            ).fetchone()
        return dict(row) if row else None

    # --- tasks ---
    def save_task(self, task: dict) -> None:
        meta = task["metadata"]["peer/v1"]
        to_handle, _, to_repo = meta["to"][1:].partition("/")
        with self.lock:
            self.db.execute(
                "INSERT INTO tasks(id, from_handle, to_handle, to_repo, kind, state, created_at, updated_at, doc) "
                "VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET state=excluded.state, "
                "updated_at=excluded.updated_at, doc=excluded.doc",
                (
                    task["id"],
                    meta["from"][1:],
                    to_handle,
                    to_repo or None,
                    meta["kind"],
                    task["status"]["state"],
                    meta["createdAt"],
                    meta.get("updatedAt", meta["createdAt"]),
                    json.dumps(task, ensure_ascii=False),
                ),
            )

    def task(self, task_id: str) -> dict | None:
        with self.lock:
            row = self.db.execute("SELECT doc FROM tasks WHERE id=?", (task_id,)).fetchone()
        return json.loads(row["doc"]) if row else None

    def tasks(
        self, *, to: str | None = None, frm: str | None = None, open_only: bool = True, limit: int = 50
    ) -> list[dict]:
        sql, args = "SELECT doc FROM tasks WHERE 1=1", []
        if to:
            sql += " AND to_handle=?"
            args.append(to)
        if frm:
            sql += " AND from_handle=?"
            args.append(frm)
        if open_only:
            sql += f" AND state NOT IN ({','.join('?' * len(TERMINAL))})"
            args += sorted(TERMINAL)
        sql += " ORDER BY updated_at DESC LIMIT ?"
        args.append(limit)
        with self.lock:
            return [json.loads(r["doc"]) for r in self.db.execute(sql, args).fetchall()]

    # --- delivery events ---
    def add_event(self, handle: str, repo: str | None, task_id: str, type_: str, wake: bool) -> None:
        with self.changed:
            self.db.execute(
                "INSERT INTO events(handle, repo, task_id, type, wake, created_at) VALUES(?,?,?,?,?,?)",
                (handle, repo, task_id, type_, int(wake), now()),
            )
            self.changed.notify_all()

    def take_events(self, handle: str, repo: str | None, *, wake_only: bool) -> list[dict]:
        sql = "SELECT id, task_id, type, wake FROM events WHERE handle=? AND delivered=0 AND (repo IS NULL OR repo=?)"
        if wake_only:
            sql += " AND wake=1"
        with self.lock:
            rows = [dict(r) for r in self.db.execute(sql + " ORDER BY id", (handle, repo or "")).fetchall()]
            if rows:
                self.db.execute(
                    f"UPDATE events SET delivered=1 WHERE id IN ({','.join('?' * len(rows))})", [r["id"] for r in rows]
                )
        return rows

    def wait_events(self, handle: str, repo: str | None, timeout: float) -> list[dict]:
        deadline = time.monotonic() + timeout
        with self.changed:
            while True:
                events = self.take_events(handle, repo, wake_only=True)
                remaining = deadline - time.monotonic()
                if events or remaining <= 0:
                    return events
                self.changed.wait(remaining)
