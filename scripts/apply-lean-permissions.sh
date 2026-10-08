#!/usr/bin/env bash
# Loosen .claude/settings.json for auto mode (run by a human — agents are not allowed to edit their own permissions).
# Why: explicit "ask" rules force a prompt even in auto mode, and auto mode's classifier already blocks the
# dangerous variants (force-push, reset --hard, exfiltration, merging unapproved PRs). We keep every deny rule
# (secrets, destructive git, `gh auth *` so tokens are never printed), add a deny for pushing straight to main
# (auto mode would allow it) and for merging PRs, replace the whole "ask" list with recursive deletes only, and
# drop the AI_MAX_* env vars that no hook reads any more. Idempotent. See docs/15-lean-harness.md.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
f=.claude/settings.json
tmp="$(mktemp)"
jq '
  .permissions.ask = ["Bash(rm -rf *)", "Bash(rm -r *)"]
  | .permissions.deny |= (. + ["Bash(git push origin main)", "Bash(git push origin main *)", "Bash(git push * HEAD:main)", "Bash(gh pr merge *)"] | unique)
  | .permissions.allow |= ((. - ["Bash(gh auth status)"]) + ["Bash(gh repo view *)", "Bash(gh workflow list *)", "Bash(python3 scripts/designs/board.py *)"] | unique)
  | .permissions.defaultMode = "auto"
  | del(.env.AI_MAX_COMMIT_LINES, .env.AI_MAX_PR_LINES)
  | if .env == {} then del(.env) else . end
' "$f" > "$tmp"
before="$(jq '.permissions.ask | length' "$f")"
cat "$tmp" > "$f" && rm -f "$tmp"   # keep the file's mode and owner
echo "updated $f (ask list: $before rule(s) replaced by recursive deletes only):"
jq '.permissions | {defaultMode, ask, deny_count: (.deny|length), allow_count: (.allow|length)}' "$f"
echo "Review with: git diff $f   — then commit it in a PR."
