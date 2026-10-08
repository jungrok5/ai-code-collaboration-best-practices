#!/usr/bin/env bash
# Loosen .claude/settings.json for auto mode (run by a human — agents are not allowed to edit their own permissions).
# Why: explicit "ask" rules force a prompt even in auto mode, and auto mode's classifier already blocks the
# dangerous variants (force-push, reset --hard, exfiltration, merging unapproved PRs). We keep deny rules for
# secrets and destructive git, add a deny for pushing straight to main (auto mode would allow it), and keep
# "ask" only for recursive deletes. See docs/15-lean-harness.md.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
f=.claude/settings.json
tmp="$(mktemp)"
jq '
  .permissions.ask = ["Bash(rm -rf *)", "Bash(rm -r *)"]
  | .permissions.deny |= ((. - ["Bash(gh auth *)"]) + ["Bash(git push origin main)", "Bash(git push origin main *)", "Bash(git push * HEAD:main)", "Bash(gh pr merge *)"] | unique)
  | .permissions.allow |= ((. + ["Bash(gh auth status)", "Bash(gh repo view *)", "Bash(gh workflow list *)", "Bash(python3 scripts/designs/board.py *)"]) | unique)
  | .permissions.defaultMode = "auto"
' "$f" > "$tmp" && mv "$tmp" "$f"
echo "updated $f:"; jq '.permissions | {defaultMode, ask, deny_count: (.deny|length), allow_count: (.allow|length)}' "$f"
echo "Review with: git diff $f   — then commit it in a PR."
