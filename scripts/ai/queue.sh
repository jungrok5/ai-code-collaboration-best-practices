#!/usr/bin/env bash
# Process every issue labelled ai:ready, one after another, from your own seat (no server needed).
# Usage: scripts/ai/queue.sh [--post] [--limit N]
set -euo pipefail
# shellcheck source=scripts/ai/common.sh
. "$(dirname "$0")/common.sh"
ai_need gh jq claude git
POST=""; LIMIT=5
while [ $# -gt 0 ]; do case "$1" in --post) POST="--post"; shift ;; --limit) LIMIT="$2"; shift 2 ;; *) shift ;; esac; done
cd "$(ai_root)"
mapfile -t issues < <(gh issue list --label ai:ready --state open --limit "$LIMIT" --json number -q '.[].number')
[ "${#issues[@]}" -gt 0 ] || { ai_log "no ai:ready issues"; exit 0; }
ai_log "processing ${#issues[@]} issue(s): ${issues[*]} (backend: $(ai_backend))"
for n in "${issues[@]}"; do
  ai_log "=== issue #$n ==="
  scripts/ai/implement.sh "$n" ${POST:+--post} || ai_warn "issue #$n did not complete"
done
