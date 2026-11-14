"""agent-relay CLI.

python3 -m agent_relay serve                      run the relay (settings from AGENT_RELAY_* env vars)
python3 -m agent_relay token issue @alice [--email alice@example.com]
python3 -m agent_relay token revoke @alice
python3 -m agent_relay agents
"""

import argparse
import logging
import os
import sys

from .server import Config, build
from .service import ADDRESS
from .store import Store


def config_from_env() -> Config:
    e = os.environ.get
    return Config(
        db=e("AGENT_RELAY_DB", "agent-relay.db"),
        host=e("AGENT_RELAY_HOST", "127.0.0.1"),
        port=int(e("AGENT_RELAY_PORT", "8765")),
        public_url=e("AGENT_RELAY_PUBLIC_URL", ""),
        trusted_header=e("AGENT_RELAY_TRUSTED_HEADER", ""),
        max_message_bytes=int(e("AGENT_RELAY_MAX_MESSAGE_BYTES", "16384")),
        notify_url=e("AGENT_RELAY_NOTIFY_URL", ""),
    )


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="agent_relay")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("serve")
    tok = sub.add_parser("token")
    tok.add_argument("action", choices=["issue", "revoke"])
    tok.add_argument("handle")
    tok.add_argument("--email")
    sub.add_parser("agents")
    a = p.parse_args(argv)
    cfg = config_from_env()
    if a.cmd == "serve":
        logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
        httpd, _, _ = build(cfg)
        logging.info("agent-relay listening on http://%s:%d (db %s)", cfg.host, cfg.port, cfg.db)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
        return 0
    store = Store(cfg.db)
    if a.cmd == "agents":
        for ag in store.agents():
            print(f"@{ag['handle']}\t{ag['email'] or ''}\t{ag['last_repo'] or ''}")
        return 0
    m = ADDRESS.match("@" + a.handle.lstrip("@"))
    if not m or m.group(2):
        print("handle must look like @alice", file=sys.stderr)
        return 2
    handle = m.group(1)
    if a.action == "issue":
        print(store.issue_token(handle, a.email, label="cli"))
    else:
        print(f"revoked {store.revoke_tokens(handle)} token(s) for @{handle}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
