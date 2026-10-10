#!/usr/bin/env bash
# The writing and UI standard lives in jungrok5/ai-design. The hub pins one commit of it in
# .claude-plugin/marketplace.json (the "ai-design" entry's sha); a product repo made from the template keeps that
# commit in .ai-design-version (written by bootstrap.sh). The same commit is used everywhere:
#   scripts/ai-design.sh             print the path of a checkout at the pinned commit (fetched into .cache/ on first use)
#   scripts/ai-design.sh style FILE… run its style check on files (make style, pre-commit, CI)
# AI_DESIGN_DIR=/path/to/ai-design overrides the checkout, e.g. to try local changes to ai-design.
set -euo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

checkout() {
  if [ -n "${AI_DESIGN_DIR:-}" ]; then echo "$AI_DESIGN_DIR"; return; fi
  local sha dir
  if [ -f "$root/.claude-plugin/marketplace.json" ]; then
    sha=$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); print(next(p["source"]["sha"] for p in m["plugins"] if p["name"] == "ai-design"))' \
      "$root/.claude-plugin/marketplace.json")
  elif [ -s "$root/.ai-design-version" ]; then sha=$(tr -d '[:space:]' < "$root/.ai-design-version")
  else echo "ai-design.sh: no pin found (.claude-plugin/marketplace.json or .ai-design-version)" >&2; exit 1; fi
  dir="$root/.cache/ai-design"
  if [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" != "$sha" ]; then
    rm -rf "$dir" && mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" fetch -q --depth 1 https://github.com/jungrok5/ai-design "$sha" >&2
    git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
  fi
  echo "$dir"
}

case "${1:-path}" in
  path) checkout ;;
  style) shift; dir=$(checkout); exec python3 "$dir/plugins/ai-design/style/style_check.py" "$@" ;;
  *) echo "usage: $0 [path | style FILE...]" >&2; exit 2 ;;
esac
