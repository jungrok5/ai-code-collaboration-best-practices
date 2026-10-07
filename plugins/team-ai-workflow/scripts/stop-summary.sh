#!/usr/bin/env bash
# Stop hook: when Claude finishes a turn with uncommitted changes, remind it
# (via additionalContext-style stdout) to run checks and summarise. Never blocks.
set -uo pipefail
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then exit 0; fi
dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
if [ "${dirty:-0}" -gt 0 ]; then
  echo "Reminder: ${dirty} file(s) are modified and uncommitted. Before handing off, run 'make check' (or the project's lint+test) and state clearly what was verified."
fi
exit 0
