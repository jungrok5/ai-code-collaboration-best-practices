#!/usr/bin/env bash
# PostToolUse hook (matcher: Edit|Write|MultiEdit)
# Runs the project's formatter on the file that was just changed, if a
# formatter is available. Never fails the tool call (always exit 0) so a
# missing formatter does not interrupt the agent; it only keeps diffs clean.
set -uo pipefail

input="$(cat)"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
[ -z "$file_path" ] || [ ! -f "$file_path" ] && exit 0

ext="${file_path##*.}"
run() { command -v "$1" >/dev/null 2>&1 && "$@" >/dev/null 2>&1 || true; }

case "$ext" in
  js|jsx|ts|tsx|json|css|scss|md|mdx|yml|yaml|html|vue|svelte)
    if [ -f node_modules/.bin/prettier ]; then node_modules/.bin/prettier --write "$file_path" >/dev/null 2>&1 || true
    elif [ -f node_modules/.bin/biome ]; then node_modules/.bin/biome format --write "$file_path" >/dev/null 2>&1 || true
    else run prettier --write "$file_path"; fi
    ;;
  py)
    if command -v ruff >/dev/null 2>&1; then ruff format "$file_path" >/dev/null 2>&1 || true; ruff check --fix --quiet "$file_path" >/dev/null 2>&1 || true
    else run black -q "$file_path"; fi
    ;;
  go)  run gofmt -w "$file_path" ;;
  rs)  run rustfmt "$file_path" ;;
  sh|bash) run shfmt -w -i 2 -ci "$file_path" ;;
  tf)  run terraform fmt "$file_path" ;;
  kt|kts) run ktlint -F "$file_path" ;;
  *) ;;
esac
exit 0
