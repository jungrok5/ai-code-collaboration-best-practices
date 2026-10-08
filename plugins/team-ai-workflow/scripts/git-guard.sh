#!/usr/bin/env bash
# PreToolUse hook for Bash: blocks commits on protected branches and force-pushes/deletes of shared
# branches. The logic lives in git_guard.py (shell-aware tokenizing is not practical in bash).
set -uo pipefail
if ! command -v python3 >/dev/null 2>&1; then
  echo "git-guard: python3 not found; team git rules are not checked locally (branch protection still applies)." >&2
  exit 0
fi
exec python3 "$(dirname "${BASH_SOURCE[0]}")/git_guard.py"
