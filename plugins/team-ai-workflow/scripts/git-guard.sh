#!/usr/bin/env bash
# PreToolUse hook with `if: Bash(git commit *)` / `Bash(git push *)`.
# Enforces team git rules before Claude commits or pushes:
#  - never commit directly on main/master/develop
#  - never push with --force to a shared branch
set -uo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

# symbolic-ref also works on an unborn branch (fresh repo with no commits)
branch="$(git symbolic-ref --short -q HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
protected='^(main|master|develop|release/.*)$'

if printf '%s' "$cmd" | grep -Eq '(^|\s)git\s+commit' && printf '%s' "$branch" | grep -Eq "$protected"; then
  echo "BLOCKED: you are on protected branch '$branch'. Create a feature branch first: git switch -c <type>/<issue>-<slug>" >&2
  exit 2
fi

if printf '%s' "$cmd" | grep -Eq '(^|\s)git\s+push.*(--force|-f\b|--force-with-lease)' && ! printf '%s' "$branch" | grep -Eq '^(feat|fix|chore|docs|refactor|test|ci|perf)/'; then
  echo "BLOCKED: force-push is only allowed on your own feature branch (current: '$branch')." >&2
  exit 2
fi

exit 0
