"""End-to-end tests for agent-relay over real HTTP (standard library only; jsonschema optional)."""

import json
import pathlib
import threading
import time
import unittest
import urllib.error
import urllib.request

from agent_relay.server import Config, build

ROOT = pathlib.Path(__file__).resolve().parents[3]
SCHEMA = ROOT / "contracts/peer-message/v1/task.schema.json"
try:
    from jsonschema import Draft202012Validator
except ImportError:  # pragma: no cover
    Draft202012Validator = None


class Relay:
    def __init__(self, **cfg):
        self.httpd, self.store, self.svc = build(Config(db=":memory:", port=0, **cfg))
        self.url = f"http://127.0.0.1:{self.httpd.server_address[1]}"
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def close(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.store.db.close()

    def req(self, method, path, token=None, body=None, headers=None):
        h = dict(headers or {})
        if token:
            h["Authorization"] = f"Bearer {token}"
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            h["Content-Type"] = "application/json"
        r = urllib.request.Request(self.url + path, data=data, method=method, headers=h)
        try:
            with urllib.request.urlopen(r, timeout=10) as resp:
                raw = resp.read()
                return resp.status, (
                    json.loads(raw) if raw and resp.headers.get_content_type() == "application/json" else raw
                )
        except urllib.error.HTTPError as e:
            raw = e.read()
            return e.code, raw

    def call(self, token, tool, **args):
        code, out = self.req(
            "POST",
            "/mcp",
            token,
            {"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": tool, "arguments": args}},
        )
        assert code == 200, (code, out)
        res = out["result"]
        return res.get("structuredContent"), res["isError"], res["content"][0]["text"]


class RelayTest(unittest.TestCase):
    def setUp(self):
        self.r = Relay()
        self.alice = self.r.store.issue_token("alice", "alice@example.com")
        self.bob = self.r.store.issue_token("bob")

    def tearDown(self):
        self.r.close()

    def test_auth_required(self):
        self.assertEqual(self.r.req("POST", "/mcp", None, {"jsonrpc": "2.0", "id": 1, "method": "ping"})[0], 401)
        self.assertEqual(self.r.req("POST", "/mcp", "prt_wrong", {"jsonrpc": "2.0", "id": 1, "method": "ping"})[0], 401)
        self.assertEqual(self.r.req("GET", "/api/wait?timeout=0", None)[0], 401)

    def test_mcp_handshake_and_tools(self):
        code, out = self.r.req(
            "POST",
            "/mcp",
            self.alice,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": "2025-06-18", "capabilities": {}},
            },
        )
        self.assertEqual(out["result"]["protocolVersion"], "2025-06-18")
        self.assertIn("tools", out["result"]["capabilities"])
        self.assertEqual(
            self.r.req("POST", "/mcp", self.alice, {"jsonrpc": "2.0", "method": "notifications/initialized"})[0], 202
        )
        _, out = self.r.req("POST", "/mcp", self.alice, {"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        names = {t["name"] for t in out["result"]["tools"]}
        self.assertEqual(names, {"peer_list", "peer_send", "peer_inbox", "peer_get", "peer_reply", "peer_cancel"})
        self.assertEqual(self.r.req("GET", "/mcp", self.alice)[0], 405)

    def test_question_round_trip_wakes_both_sides(self):
        sent, err, _ = self.r.call(
            self.alice,
            "peer_send",
            to="@bob/payments-api",
            text="When does refundReason ship?",
            subject="refundReason",
            data={"repo": "acme/web", "files": ["acme/web@4f2c1e:src/api.ts"]},
        )
        self.assertFalse(err)
        tid = sent["taskId"]
        # bob in another repo is not woken; bob in payments-api is
        self.assertEqual(self.r.req("GET", "/api/wait?repo=other&timeout=0", self.bob)[0], 204)
        code, out = self.r.req("GET", "/api/wait?repo=payments-api&timeout=1", self.bob)
        self.assertEqual((code, out["events"][0]["taskId"], out["events"][0]["event"]), (200, tid, "new"))
        # not acknowledged yet: delivered again (a replaced waiter must not swallow it)
        self.assertEqual(self.r.req("GET", "/api/wait?repo=payments-api&timeout=0", self.bob)[0], 200)
        ack = self.r.req("POST", "/api/ack", self.bob, {"ids": [out["events"][0]["eventId"]]})
        self.assertEqual(ack, (200, {"acknowledged": 1}))
        self.assertEqual(self.r.req("GET", "/api/wait?repo=payments-api&timeout=0", self.bob)[0], 204)
        self.assertEqual(self.r.req("POST", "/api/ack", self.alice, {"ids": [1, 2, 3]})[1], {"acknowledged": 0})
        box, _, _ = self.r.call(self.bob, "peer_inbox")
        self.assertEqual([t["taskId"] for t in box["toMe"]], [tid])
        _, err, msg = self.r.call(self.alice, "peer_reply", task_id=tid, text="I am not the recipient")
        self.assertTrue(err and "only the recipient" in msg)
        done, err, _ = self.r.call(
            self.bob, "peer_reply", task_id=tid, text="PR #456", artifact_links=["https://example.com/pr/456"]
        )
        self.assertEqual((err, done["state"]), (False, "TASK_STATE_COMPLETED"))
        code, out = self.r.req("GET", "/api/wait?repo=web&timeout=1", self.alice)
        self.assertEqual((code, out["events"][0]["event"]), (200, "reply"))
        task, _, _ = self.r.call(self.alice, "peer_get", task_id=tid)
        self.assertEqual([m["role"] for m in task["history"]], ["ROLE_USER", "ROLE_AGENT"])
        self.assertEqual(task["artifacts"][0]["parts"], [{"url": "https://example.com/pr/456"}])
        if Draft202012Validator:
            Draft202012Validator(json.loads(SCHEMA.read_text())).validate(task)

    def test_long_poll_returns_when_message_arrives(self):
        result = {}

        def wait():
            result["resp"] = self.r.req("GET", "/api/wait?timeout=10", self.bob)

        t = threading.Thread(target=wait)
        t.start()
        time.sleep(0.3)
        start = time.monotonic()
        self.r.call(self.alice, "peer_send", to="@bob", text="ping", kind="handoff")
        t.join(5)
        self.assertLess(time.monotonic() - start, 3)
        self.assertEqual(result["resp"][0], 200)

    def test_fyi_does_not_wake_and_shows_in_summary(self):
        self.r.call(self.alice, "peer_send", to="@bob", text="PR #456 merged", kind="fyi")
        self.assertEqual(self.r.req("GET", "/api/wait?timeout=0", self.bob)[0], 204)
        code, out = self.r.req("GET", "/api/summary", self.bob)
        self.assertEqual((code, out["events"][0]["kind"], out["waitingForYou"]), (200, "fyi", 1))
        self.assertEqual(self.r.req("GET", "/api/summary", self.bob)[1]["events"], [])

    def test_follow_up_and_input_required(self):
        sent, _, _ = self.r.call(self.alice, "peer_send", to="@bob", text="Can you add a field?", kind="request")
        tid = sent["taskId"]
        self.r.call(self.bob, "peer_reply", task_id=tid, text="Asking my owner", state="TASK_STATE_WORKING")
        self.assertEqual(self.r.req("GET", "/api/wait?timeout=0", self.alice)[0], 204)  # acknowledgement does not wake
        self.assertEqual(self.r.req("GET", "/api/summary", self.alice)[1]["events"][0]["event"], "reply")
        self.r.call(self.bob, "peer_reply", task_id=tid, text="Which name?", state="TASK_STATE_INPUT_REQUIRED")
        self.assertEqual(self.r.req("GET", "/api/summary", self.alice)[1]["needsYourInput"], 1)
        again, err, _ = self.r.call(self.alice, "peer_send", task_id=tid, text="refundReason")
        self.assertEqual((err, again["state"]), (False, "TASK_STATE_WORKING"))
        _, err, msg = self.r.call(self.bob, "peer_send", task_id=tid, text="x")
        self.assertTrue(err and "peer_reply" in msg)
        self.r.call(self.alice, "peer_cancel", task_id=tid, reason="done elsewhere")
        _, err, msg = self.r.call(self.bob, "peer_reply", task_id=tid, text="late")
        self.assertTrue(err and "closed" in msg)

    def test_rejects_secrets_unknown_agents_and_bad_input(self):
        cases = [
            ({"to": "@bob", "text": "key AKIAABCDEFGHIJKLMNOP"}, "secret"),
            ({"to": "@bob", "text": "-----BEGIN RSA PRIVATE KEY-----"}, "secret"),
            ({"to": "@bob", "text": "x" * 20000}, "limit"),
            ({"to": "@carol", "text": "hi"}, "unknown agent"),
            ({"to": "bob", "text": "hi"}, "@handle"),
            ({"to": "@bob", "text": "hi", "kind": "order"}, "kind"),
            ({"to": "@bob", "text": "hi", "bogus": 1}, "unknown argument"),
        ]
        for args, needle in cases:
            _, err, msg = self.r.call(self.alice, "peer_send", **args)
            self.assertTrue(err, args)
            self.assertIn(needle, msg)
        self.assertEqual(self.r.store.tasks(open_only=False), [])

    def test_peer_list_marks_online(self):
        self.r.req("GET", "/api/wait?timeout=0&repo=web", self.bob)
        agents, _, _ = self.r.call(self.alice, "peer_list")
        bob = next(a for a in agents["agents"] if a["address"] == "@bob")
        self.assertEqual((bob["online"], bob["lastRepo"]), (True, "web"))

    def test_web_ui_requires_login_and_escapes(self):
        self.r.call(self.alice, "peer_send", to="@bob", text="<script>alert(1)</script>", subject="<b>x</b>")
        code, page = self.r.req("GET", "/", None)  # urllib follows the 303 to /login
        self.assertIn(b"Sign in", page)
        self.assertNotIn(b"&lt;b&gt;", page)
        code, page = self.r.req("GET", "/", None, headers={"Cookie": f"relay_token={self.alice}"})
        self.assertEqual(code, 200)
        self.assertIn(b"&lt;b&gt;x&lt;/b&gt;", page)
        self.assertNotIn(b"<b>x</b>", page)


class TrustedHeaderTest(unittest.TestCase):
    def test_sso_header_identifies_and_issues_tokens(self):
        r = Relay(trusted_header="X-Forwarded-Email")
        try:
            code, out = r.req("GET", "/api/summary", None, headers={"X-Forwarded-Email": "dana.kim@example.com"})
            self.assertEqual((code, out["you"]), (200, "@dana.kim"))
            self.assertEqual(r.store.agent("dana.kim")["email"], "dana.kim@example.com")
            code, page = r.req("POST", "/token", None, headers={"X-Forwarded-Email": "dana.kim@example.com"})
            token = page.split(b"<pre>")[1].split(b"</pre>")[0].decode()
            self.assertEqual(r.store.handle_for_token(token), "dana.kim")
        finally:
            r.close()


if __name__ == "__main__":
    unittest.main()
