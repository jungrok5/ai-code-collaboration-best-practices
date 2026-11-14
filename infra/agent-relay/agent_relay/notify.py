"""Optional outbound webhook: POSTs a small JSON payload for every event that wakes a recipient.
Point AGENT_RELAY_NOTIFY_URL at a Teams Workflows / Power Automate HTTP trigger, a Slack workflow, or anything else."""

import json
import logging
import threading
import urllib.request

log = logging.getLogger("agent_relay.notify")


def webhook(url: str):
    if not url:
        return None

    def send(payload: dict) -> None:
        def post():
            req = urllib.request.Request(
                url,
                data=json.dumps(payload).encode("utf-8"),
                method="POST",
                headers={"Content-Type": "application/json"},
            )
            try:
                urllib.request.urlopen(req, timeout=5).close()
            except Exception as e:  # never let a notification failure affect delivery
                log.warning("notify failed: %s", e)

        threading.Thread(target=post, daemon=True).start()

    return send
