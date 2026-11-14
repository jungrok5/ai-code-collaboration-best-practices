"""Task operations behind the MCP tools. Every function takes the caller's handle and returns plain dicts."""

import re
import time

from . import guard
from .store import TERMINAL, Store, new_id, now

ADDRESS = re.compile(r"^@([A-Za-z0-9][A-Za-z0-9._-]{0,63})(?:/([A-Za-z0-9._-]{1,100}))?$")
KINDS = ("question", "request", "fyi", "handoff")
REPLY_STATES = ("TASK_STATE_WORKING", "TASK_STATE_INPUT_REQUIRED", "TASK_STATE_COMPLETED", "TASK_STATE_REJECTED")
ONLINE_SECONDS = 90


class ToolError(ValueError):
    """A caller mistake; the text goes back to the agent as a tool error."""


class Service:
    def __init__(self, store: Store, *, max_message_bytes: int = 16384, notify=None, public_url: str = ""):
        self.store = store
        self.max_bytes = max_message_bytes
        self.notify = notify or (lambda payload: None)
        self.public_url = public_url.rstrip("/")

    # --- helpers ---
    def _message(self, author: str, role: str, text: str, data=None, links=()) -> dict:
        try:
            guard.check(text, self.max_bytes)
        except guard.Rejected as e:
            raise ToolError(str(e)) from None
        parts = [{"text": text}]
        if data:
            parts.append({"data": data})
        parts += [{"url": u} for u in links or ()]
        return {
            "messageId": new_id("msg"),
            "role": role,
            "parts": parts,
            "metadata": {"peer/v1": {"author": f"@{author}", "sentAt": now()}},
        }

    def _load(self, task_id: str) -> dict:
        task = self.store.task(task_id or "")
        if not task:
            raise ToolError(f"no task {task_id!r}")
        return task

    def _set_state(self, task: dict, state: str) -> None:
        ts = now()
        task["status"] = {"state": state, "timestamp": ts}
        task["metadata"]["peer/v1"]["updatedAt"] = ts

    def _notify(self, event: str, task: dict, recipient: str, text: str) -> None:
        meta = task["metadata"]["peer/v1"]
        agent = self.store.agent(recipient) or {}
        self.notify(
            {
                "event": event,
                "taskId": task["id"],
                "kind": meta["kind"],
                "state": task["status"]["state"],
                "from": meta["from"],
                "to": meta["to"],
                "recipient": f"@{recipient}",
                "recipientEmail": agent.get("email"),
                "subject": meta.get("subject", ""),
                "text": text[:300],
                "url": f"{self.public_url}/t/{task['id']}" if self.public_url else "",
            }
        )

    @staticmethod
    def brief(task: dict) -> dict:
        meta = task["metadata"]["peer/v1"]
        first = next((p["text"] for p in task["history"][0]["parts"] if "text" in p), "")
        return {
            "taskId": task["id"],
            "state": task["status"]["state"],
            "kind": meta["kind"],
            "from": meta["from"],
            "to": meta["to"],
            "subject": meta.get("subject") or first[:80],
            "updatedAt": meta.get("updatedAt"),
        }

    # --- tools ---
    def list_agents(self, caller: str) -> dict:
        t = time.time()
        return {
            "agents": [
                {
                    "address": f"@{a['handle']}",
                    "online": bool(a["last_seen"] and t - a["last_seen"] < ONLINE_SECONDS),
                    "lastSeen": a["last_seen"] and time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(a["last_seen"])),
                    "lastRepo": a["last_repo"],
                    "you": a["handle"] == caller,
                }
                for a in self.store.agents()
            ]
        }

    def send(
        self,
        caller: str,
        to: str = "",
        text: str = "",
        kind: str = "question",
        subject: str = "",
        data=None,
        links=(),
        task_id: str = "",
        reply_by: str = "",
    ) -> dict:
        if task_id:
            return self._follow_up(caller, task_id, text, data, links)
        m = ADDRESS.match(to or "")
        if not m:
            raise ToolError("`to` must look like @handle or @handle/repo")
        handle, repo = m.group(1), m.group(2)
        if not self.store.agent(handle):
            known = ", ".join(f"@{a['handle']}" for a in self.store.agents())
            raise ToolError(f"unknown agent @{handle}. Known: {known or 'none'}")
        if kind not in KINDS:
            raise ToolError(f"`kind` must be one of {', '.join(KINDS)}")
        if not text.strip():
            raise ToolError("`text` is empty")
        tid, ts = new_id("tsk"), now()
        meta = {"kind": kind, "from": f"@{caller}", "to": to, "createdAt": ts, "updatedAt": ts}
        if subject:
            meta["subject"] = subject[:200]
        if reply_by:
            meta["replyBy"] = reply_by
        task = {
            "id": tid,
            "contextId": new_id("ctx"),
            "status": {"state": "TASK_STATE_SUBMITTED", "timestamp": ts},
            "history": [self._message(caller, "ROLE_USER", text, data, links)],
            "artifacts": [],
            "metadata": {"peer/v1": meta},
        }
        self.store.save_task(task)
        wake = kind != "fyi"
        self.store.add_event(handle, repo, tid, "new", wake)
        if wake:
            self._notify("task.created", task, handle, text)
        return self.brief(task)

    def _follow_up(self, caller: str, task_id: str, text: str, data, links) -> dict:
        task = self._load(task_id)
        meta = task["metadata"]["peer/v1"]
        if meta["from"] != f"@{caller}":
            raise ToolError("only the sender adds follow-ups with peer_send; the recipient answers with peer_reply")
        if task["status"]["state"] in TERMINAL:
            raise ToolError(f"task is closed ({task['status']['state']}); send a new task instead")
        task["history"].append(self._message(caller, "ROLE_USER", text, data, links))
        self._set_state(task, "TASK_STATE_WORKING")
        self.store.save_task(task)
        handle, _, repo = meta["to"][1:].partition("/")
        self.store.add_event(handle, repo or None, task_id, "followup", True)
        self._notify("task.followup", task, handle, text)
        return self.brief(task)

    def reply(
        self,
        caller: str,
        task_id: str = "",
        text: str = "",
        state: str = "TASK_STATE_COMPLETED",
        artifact_name: str = "",
        artifact_links=(),
        artifact_text: str = "",
    ) -> dict:
        task = self._load(task_id)
        meta = task["metadata"]["peer/v1"]
        if meta["to"][1:].partition("/")[0] != caller:
            raise ToolError(f"only the recipient ({meta['to']}) can reply; the sender uses peer_send with task_id")
        if task["status"]["state"] in TERMINAL:
            raise ToolError(f"task is closed ({task['status']['state']})")
        if state not in REPLY_STATES:
            raise ToolError(f"`state` must be one of {', '.join(REPLY_STATES)}")
        if not text.strip():
            raise ToolError(
                "`text` is empty" + (" (a rejection needs a reason)" if state == "TASK_STATE_REJECTED" else "")
            )
        task["history"].append(self._message(caller, "ROLE_AGENT", text))
        if artifact_links or artifact_text:
            parts = ([{"text": artifact_text}] if artifact_text else []) + [{"url": u} for u in artifact_links or ()]
            guard_text = artifact_text + " ".join(artifact_links or ())
            try:
                guard.check(guard_text, self.max_bytes)
            except guard.Rejected as e:
                raise ToolError(str(e)) from None
            task["artifacts"].append({"artifactId": new_id("art"), "name": artifact_name or "result", "parts": parts})
        self._set_state(task, state)
        self.store.save_task(task)
        sender = meta["from"][1:]
        wake = state != "TASK_STATE_WORKING"  # an acknowledgement shows up in the next summary instead
        self.store.add_event(sender, None, task_id, "reply", wake)
        if wake:
            self._notify("task.replied", task, sender, text)
        return self.brief(task)

    def cancel(self, caller: str, task_id: str = "", reason: str = "") -> dict:
        task = self._load(task_id)
        meta = task["metadata"]["peer/v1"]
        if meta["from"] != f"@{caller}":
            raise ToolError("only the sender can cancel")
        if task["status"]["state"] in TERMINAL:
            raise ToolError(f"task is already closed ({task['status']['state']})")
        if reason:
            task["history"].append(self._message(caller, "ROLE_USER", f"Canceled: {reason}"))
        self._set_state(task, "TASK_STATE_CANCELED")
        self.store.save_task(task)
        handle, _, repo = meta["to"][1:].partition("/")
        self.store.add_event(handle, repo or None, task_id, "canceled", False)
        return self.brief(task)

    def inbox(self, caller: str, include_closed: bool = False, limit: int = 20) -> dict:
        open_only = not include_closed
        return {
            "toMe": [self.brief(t) for t in self.store.tasks(to=caller, open_only=open_only, limit=limit)],
            "fromMe": [self.brief(t) for t in self.store.tasks(frm=caller, open_only=open_only, limit=limit)],
        }

    def get(self, caller: str, task_id: str = "") -> dict:
        return self._load(task_id)

    def events_view(self, events: list[dict]) -> list[dict]:
        out = []
        for e in events:
            task = self.store.task(e["task_id"])
            if task:
                out.append({"eventId": e["id"], "event": e["type"], **self.brief(task)})
        return out
