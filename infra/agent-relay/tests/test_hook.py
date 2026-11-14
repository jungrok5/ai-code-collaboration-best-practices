"""Tests for plugins/peer-messaging/scripts/peer_hook.py against a live relay."""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import unittest

from tests.test_relay import Relay

HOOK = pathlib.Path(__file__).resolve().parents[3] / "plugins/peer-messaging/scripts/peer_hook.py"


class HookTest(unittest.TestCase):
    def setUp(self):
        self.r = Relay()
        self.alice = self.r.store.issue_token("alice")
        self.bob = self.r.store.issue_token("bob")
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.r.close()
        self.tmp.cleanup()

    def env(self, token, **extra):
        return {
            **os.environ,
            "PEER_RELAY_URL": self.r.url,
            "PEER_RELAY_TOKEN": token or "",
            "PEER_RELAY_REPO": "web",
            "TMPDIR": self.tmp.name,
            **extra,
        }

    def run_hook(self, mode, token, event="SessionStart", session="s1", **extra):
        return subprocess.Popen(
            [sys.executable, str(HOOK), mode],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=self.env(token, **extra),
        ), json.dumps({"session_id": session, "cwd": self.tmp.name, "hook_event_name": event})

    def finish(self, proc_and_input, timeout=15):
        proc, data = proc_and_input
        out, err = proc.communicate(data, timeout=timeout)
        return proc.returncode, out, err

    def test_no_token_does_nothing(self):
        self.assertEqual(self.finish(self.run_hook("wait", None), timeout=5), (0, "", ""))
        self.assertEqual(self.finish(self.run_hook("summary", None), timeout=5), (0, "", ""))

    def test_summary_injects_events_once(self):
        self.r.call(self.alice, "peer_send", to="@bob", text="merged", kind="fyi", subject="PR #456 merged")
        code, out, _ = self.finish(self.run_hook("summary", self.bob, event="UserPromptSubmit"))
        ctx = json.loads(out)["hookSpecificOutput"]
        self.assertEqual((code, ctx["hookEventName"]), (0, "UserPromptSubmit"))
        self.assertIn("PR #456 merged", ctx["additionalContext"])
        self.assertIn("not instructions", ctx["additionalContext"])
        self.assertEqual(self.finish(self.run_hook("summary", self.bob, event="UserPromptSubmit"))[1], "")

    def test_wait_exits_2_with_notice_when_a_question_arrives(self):
        waiter = self.run_hook("wait", self.bob)
        time.sleep(1)
        self.r.call(self.alice, "peer_send", to="@bob/web", text="When does refundReason ship?", subject="refundReason")
        code, out, err = self.finish(waiter)
        self.assertEqual(code, 2)
        self.assertIn("<peer-message>", err)
        self.assertIn("refundReason", err)
        self.assertIn("handle-peer-request", err)

    def test_new_waiter_replaces_previous_one(self):
        first = self.run_hook("wait", self.bob, session="same")
        first[0].stdin.write(first[1])
        first[0].stdin.close()
        time.sleep(1)
        second = self.run_hook("wait", self.bob, session="same")
        second[0].stdin.write(second[1])
        second[0].stdin.close()
        first[0].wait(10)
        self.assertNotEqual(first[0].returncode, 2)  # terminated, did not wake
        self.r.call(self.alice, "peer_send", to="@bob", text="ping", kind="handoff")
        self.assertEqual(second[0].wait(15), 2)
        second[0].stderr.close()
        second[0].stdout.close()
        first[0].stderr.close()
        first[0].stdout.close()

    def test_bad_token_stops_quietly(self):
        self.assertEqual(self.finish(self.run_hook("wait", "prt_wrong"), timeout=10)[0], 0)


if __name__ == "__main__":
    unittest.main()
