#!/usr/bin/env bash
# SessionStart hook: make a fresh clone (local, devcontainer, Claude Code on the web) ready to run checks,
# and give the agent the one thing it cannot discover cheaply: who is working on what (active designs).
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" || exit 0

if [ -f package.json ] && [ ! -d node_modules ]; then
  if [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null; then pnpm install --frozen-lockfile >/dev/null 2>&1 || true
  elif command -v npm >/dev/null; then npm ci >/dev/null 2>&1 || npm install >/dev/null 2>&1 || true; fi
fi
if [ -f pyproject.toml ] && [ ! -d .venv ] && command -v uv >/dev/null; then uv sync >/dev/null 2>&1 || true; fi
if [ -f go.mod ] && command -v go >/dev/null; then go mod download >/dev/null 2>&1 || true; fi
if [ -f .pre-commit-config.yaml ] && command -v pre-commit >/dev/null && [ ! -f .git/hooks/pre-commit ]; then
  pre-commit install --install-hooks >/dev/null 2>&1 || true
fi

# Active designs across the team (one line each). DESIGN_BOARD_URL points at the hub's board.json.
board="$root/.claude/board.json"
if [ -n "${DESIGN_BOARD_URL:-}" ] && command -v curl >/dev/null; then
  curl -fsSL --max-time 5 "$DESIGN_BOARD_URL" -o "$board" 2>/dev/null || rm -f "$board"
fi
if [ -f scripts/designs/board.py ] && command -v python3 >/dev/null; then
  if [ -f "$board" ]; then export DESIGN_BOARD="$board"; fi
  brief="$(python3 scripts/designs/board.py brief 2>/dev/null)"
  if [ -n "$brief" ] && [ "$brief" != "(no active designs)" ]; then
    echo "Active designs and claimed areas on the team (check overlap before starting new work):"
    printf '%s\n' "$brief"
  fi
fi
exit 0
