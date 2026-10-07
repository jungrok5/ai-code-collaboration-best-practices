#!/usr/bin/env bash
# SessionStart hook: make a fresh clone (local, devcontainer, or Claude Code
# on the web) ready to run lint/tests, and surface team context to the agent.
# Must be idempotent and fast; heavy installs are skipped when already done.
# Anything printed to stdout is added to Claude's context.
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" || exit 0

# 1) Dependencies (best effort, only when a manifest exists and deps are missing)
if [ -f package.json ] && [ ! -d node_modules ]; then
  if [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null; then pnpm install --frozen-lockfile >/dev/null 2>&1 || true
  elif [ -f yarn.lock ] && command -v yarn >/dev/null; then yarn install --immutable >/dev/null 2>&1 || true
  elif command -v npm >/dev/null; then npm ci >/dev/null 2>&1 || npm install >/dev/null 2>&1 || true; fi
fi
if [ -f pyproject.toml ] && [ ! -d .venv ]; then
  if command -v uv >/dev/null; then uv sync >/dev/null 2>&1 || true
  elif command -v python3 >/dev/null; then python3 -m venv .venv >/dev/null 2>&1 && .venv/bin/pip install -q -e . >/dev/null 2>&1 || true; fi
fi
if [ -f go.mod ] && command -v go >/dev/null; then go mod download >/dev/null 2>&1 || true; fi

# 2) Git hygiene: pre-commit hooks installed once
if [ -f .pre-commit-config.yaml ] && command -v pre-commit >/dev/null && [ ! -f .git/hooks/pre-commit ]; then
  pre-commit install --install-hooks >/dev/null 2>&1 || true
fi

# 3) Context for the agent (stdout => injected into the session)
branch="$(git symbolic-ref --short -q HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "## Session context (from .claude/hooks/session-start.sh)"
echo "- Branch: $branch (default branch: $(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#origin/##' || echo main))"
echo "- Read AGENTS.md first; it is the single source of truth for team rules."
if [ -f docs/01-playbook.md ]; then echo "- Daily workflow: docs/01-playbook.md"; fi
open_issue="$(git log -1 --pretty=%s 2>/dev/null | grep -oE '#[0-9]+' | head -1 || true)"
[ -n "$open_issue" ] && echo "- Last commit references issue $open_issue"
exit 0
