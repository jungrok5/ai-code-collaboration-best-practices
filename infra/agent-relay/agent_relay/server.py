"""HTTP server: /mcp (MCP), /api/wait and /api/summary (hooks), /token (SSO mode), / and /t/<id> (web UI)."""

import html
import json
import logging
import re
import urllib.parse
from dataclasses import dataclass
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import mcp
from .service import Service
from .store import Store

log = logging.getLogger("agent_relay")
REPO = re.compile(r"^[A-Za-z0-9._-]{1,100}$")
HANDLE_CHARS = re.compile(r"[^A-Za-z0-9._-]")
MAX_BODY = 1 << 20


@dataclass
class Config:
    db: str = "agent-relay.db"
    host: str = "127.0.0.1"
    port: int = 8765
    public_url: str = ""
    trusted_header: str = ""  # e.g. X-Forwarded-Email, set only when a trusted SSO proxy is the sole way in
    max_message_bytes: int = 16384
    notify_url: str = ""
    max_wait: int = 55


def handle_from_identity(identity: str) -> str:
    local = identity.split("@", 1)[0] if "@" in identity else identity
    return HANDLE_CHARS.sub("-", local).strip("-.")[:64] or "user"


PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title><style>
:root{{--bg:#fff;--fg:#1a1a1a;--muted:#5c5c5c;--line:#e2e2e2;--accent:#0b57d0}}
@media (prefers-color-scheme:dark){{:root{{--bg:#141414;--fg:#ededed;--muted:#a3a3a3;--line:#333;--accent:#8ab4f8}}}}
body{{margin:0;padding:24px 16px;background:var(--bg);color:var(--fg);font:15px/1.55 system-ui,sans-serif}}
main{{max-width:880px;margin:0 auto}} a{{color:var(--accent)}} h1{{font-size:20px;margin:0 0 16px}}
table{{width:100%;border-collapse:collapse}} th,td{{text-align:left;padding:8px 6px;border-bottom:1px solid var(--line);vertical-align:top}}
th{{color:var(--muted);font-weight:500;font-size:13px}} .m{{color:var(--muted);font-size:13px}}
pre{{white-space:pre-wrap;word-break:break-word;margin:4px 0 0;font:13px/1.5 ui-monospace,monospace}}
.msg{{border-top:1px solid var(--line);padding:12px 0}} input,button{{font:inherit;padding:6px 10px}}
</style></head><body><main>{body}</main></body></html>"""


def esc(v) -> str:
    return html.escape(str(v if v is not None else ""))


def make_handler(cfg: Config, store: Store, svc: Service):
    class Handler(BaseHTTPRequestHandler):
        server_version = "agent-relay"

        def log_message(self, fmt, *args):
            log.info("%s %s", self.address_string(), fmt % args)

        # --- plumbing ---
        def _send(self, code: int, body: bytes = b"", ctype: str = "application/json", headers: dict | None = None):
            self.send_response(code)
            if body:
                self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            for k, v in (headers or {}).items():
                self.send_header(k, v)
            self.end_headers()
            if body and self.command != "HEAD":
                self.wfile.write(body)

        def _json(self, code: int, obj):
            self._send(code, json.dumps(obj, ensure_ascii=False).encode("utf-8"))

        def _page(self, code: int, title: str, body: str, headers: dict | None = None):
            self._send(
                code, PAGE.format(title=esc(title), body=body).encode("utf-8"), "text/html; charset=utf-8", headers
            )

        def _query(self) -> dict:
            return {k: v[-1] for k, v in urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query).items()}

        def _body(self) -> bytes:
            n = int(self.headers.get("Content-Length") or 0)
            if n > MAX_BODY:
                raise ValueError("body too large")
            return self.rfile.read(n) if n else b""

        def _caller(self, allow_cookie: bool = False) -> str | None:
            auth = self.headers.get("Authorization", "")
            if auth.lower().startswith("bearer "):
                return store.handle_for_token(auth[7:].strip())
            if cfg.trusted_header and self.headers.get(cfg.trusted_header):
                identity = self.headers[cfg.trusted_header].strip()
                handle = handle_from_identity(identity)
                store.ensure_agent(handle, identity if "@" in identity else None)
                return handle
            if allow_cookie:
                c = cookies.SimpleCookie(self.headers.get("Cookie", ""))
                if "relay_token" in c:
                    return store.handle_for_token(c["relay_token"].value)
            return None

        def _repo(self) -> str | None:
            repo = self._query().get("repo", "")
            return repo if REPO.match(repo) else None

        # --- routes ---
        def do_GET(self):
            path = urllib.parse.urlsplit(self.path).path
            if path == "/healthz":
                return self._json(200, {"ok": True})
            if path == "/mcp":
                return self._send(405, headers={"Allow": "POST"})
            if path in ("/api/wait", "/api/summary"):
                who = self._caller()
                if not who:
                    return self._json(401, {"error": "missing or invalid token"})
                repo = self._repo()
                store.touch(who, repo)
                if path == "/api/wait":
                    timeout = max(0.0, min(float(self._query().get("timeout", "25") or 25), cfg.max_wait))
                    events = svc.events_view(store.wait_events(who, repo, timeout))
                    store.touch(who, repo)
                    return self._json(200, {"events": events}) if events else self._send(204)
                events = svc.events_view(store.take_events(who, repo, wake_only=False))
                box = svc.inbox(who)
                return self._json(
                    200,
                    {
                        "you": f"@{who}",
                        "events": events,
                        "waitingForYou": len(box["toMe"]),
                        "needsYourInput": sum(t["state"] == "TASK_STATE_INPUT_REQUIRED" for t in box["fromMe"]),
                    },
                )
            if path == "/login":
                return self._page(
                    200,
                    "Sign in",
                    '<h1>agent-relay</h1><form method="post" action="/login">'
                    '<label>Token <input name="token" type="password" autocomplete="off"></label> '
                    "<button>Sign in</button></form>",
                )
            who = self._caller(allow_cookie=True)
            if not who:
                return self._send(303, headers={"Location": "/login"})
            if path == "/token":
                return self._token_page(who)
            if path == "/":
                return self._list_page(who)
            m = re.fullmatch(r"/t/([A-Za-z0-9_]{1,128})", path)
            if m:
                return self._task_page(m.group(1))
            return self._page(404, "Not found", "<h1>Not found</h1>")

        do_HEAD = do_GET

        def do_POST(self):
            path = urllib.parse.urlsplit(self.path).path
            try:
                raw = self._body()
            except ValueError:
                return self._json(413, {"error": "body too large"})
            if path == "/login":
                token = urllib.parse.parse_qs(raw.decode("utf-8", "replace")).get("token", [""])[-1].strip()
                if not store.handle_for_token(token):
                    return self._page(401, "Sign in", "<h1>Invalid token</h1><p><a href='/login'>Try again</a></p>")
                c = cookies.SimpleCookie()
                c["relay_token"] = token
                c["relay_token"].update(
                    {"httponly": True, "samesite": "Strict", "path": "/", "max-age": str(30 * 86400)}
                )
                if cfg.public_url.startswith("https://"):
                    c["relay_token"]["secure"] = True
                return self._send(303, headers={"Location": "/", "Set-Cookie": c.output(header="").strip()})
            if path == "/token" and cfg.trusted_header and self.headers.get(cfg.trusted_header):
                who = self._caller()
                token = store.issue_token(who, label="self-service")
                return self._page(
                    200,
                    "Your token",
                    f"<h1>Token for @{esc(who)}</h1><p>Shown once. Put it in "
                    f"<code>PEER_RELAY_TOKEN</code>.</p><pre>{esc(token)}</pre>",
                )
            if path != "/mcp":
                return self._json(404, {"error": "not found"})
            who = self._caller()
            if not who:
                return self._json(
                    401,
                    {"error": "missing or invalid token"},
                )
            store.touch(who, None)
            try:
                body = json.loads(raw or b"null")
            except json.JSONDecodeError:
                return self._json(
                    400, {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "parse error"}}
                )
            out = mcp.handle(svc, who, body)
            return self._json(200, out) if out is not None else self._send(202)

        # --- pages ---
        def _token_page(self, who: str):
            if not cfg.trusted_header:
                return self._page(
                    200,
                    "Token",
                    "<h1>Tokens</h1><p>Ask an administrator: <code>python3 -m agent_relay token issue @you</code>.</p>",
                )
            return self._page(
                200,
                "Token",
                f"<h1>@{esc(who)}</h1><form method='post' action='/token'>"
                "<button>Issue a new personal token</button></form>",
            )

        def _list_page(self, who: str):
            rows = []
            for t in store.tasks(open_only=False, limit=200):
                b = svc.brief(t)
                rows.append(
                    f"<tr><td><a href='/t/{esc(b['taskId'])}'>{esc(b['subject'] or b['taskId'])}</a></td>"
                    f"<td>{esc(b['from'])} → {esc(b['to'])}</td><td>{esc(b['kind'])}</td>"
                    f"<td>{esc(b['state'].replace('TASK_STATE_', '').lower())}</td><td class='m'>{esc(b['updatedAt'])}</td></tr>"
                )
            table = (
                (
                    "<table><tr><th>Subject</th><th>From → To</th><th>Kind</th><th>State</th><th>Updated</th></tr>"
                    + "".join(rows)
                    + "</table>"
                )
                if rows
                else "<p>No tasks yet.</p>"
            )
            return self._page(200, "agent-relay", f"<h1>Tasks</h1><p class='m'>Signed in as @{esc(who)}</p>{table}")

        def _task_page(self, task_id: str):
            t = store.task(task_id)
            if not t:
                return self._page(404, "Not found", "<h1>Not found</h1>")
            meta = t["metadata"]["peer/v1"]
            msgs = []
            for m in t["history"] + [
                {"role": "ARTIFACT", "parts": a["parts"], "metadata": {"peer/v1": {"author": a.get("name")}}}
                for a in t["artifacts"]
            ]:
                author = (m.get("metadata") or {}).get("peer/v1", {}).get("author", "")
                parts = "".join(
                    f"<pre>{esc(p['text'])}</pre>"
                    if "text" in p
                    else f"<p><a href='{esc(p['url'])}' rel='noreferrer'>{esc(p['url'])}</a></p>"
                    if "url" in p
                    else f"<pre>{esc(json.dumps(p.get('data'), ensure_ascii=False, indent=1))}</pre>"
                    for p in m["parts"]
                )
                msgs.append(f"<div class='msg'><span class='m'>{esc(author)} · {esc(m['role'])}</span>{parts}</div>")
            head = (
                f"<h1>{esc(meta.get('subject') or t['id'])}</h1><p class='m'>{esc(meta['from'])} → {esc(meta['to'])} · "
                f"{esc(meta['kind'])} · {esc(t['status']['state'])} · {esc(t['id'])}</p>"
            )
            return self._page(
                200, meta.get("subject") or t["id"], head + "".join(msgs) + "<p><a href='/'>All tasks</a></p>"
            )

    return Handler


def build(cfg: Config) -> tuple[ThreadingHTTPServer, Store, Service]:
    from .notify import webhook

    store = Store(cfg.db)
    svc = Service(
        store, max_message_bytes=cfg.max_message_bytes, notify=webhook(cfg.notify_url), public_url=cfg.public_url
    )
    httpd = ThreadingHTTPServer((cfg.host, cfg.port), make_handler(cfg, store, svc))
    httpd.daemon_threads = True
    return httpd, store, svc
