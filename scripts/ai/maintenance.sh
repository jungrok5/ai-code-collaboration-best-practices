#!/usr/bin/env bash
# Weekly maintenance report (stale issues, merged work, TODOs without issues, AGENTS.md drift). With --post: creates ONE issue.
# Usage: scripts/ai/maintenance.sh [--post]
set -euo pipefail
# shellcheck source=scripts/ai/common.sh
. "$(dirname "$0")/common.sh"
ai_need gh jq claude git
POST=0; [ "${1:-}" = "--post" ] && POST=1
cd "$(ai_root)"
ai_log "backend: $(ai_backend)"
issues="$(gh issue list --state open --limit 200 --json number,title,labels,updatedAt --jq '[.[] | {number,title,labels:[.labels[].name],updatedAt}]')"
log="$(git log --since='7 days ago' --no-merges --pretty='- %h %s' | head -100)"
prompt="$(cat <<PROMPT
$(ai_untrusted_banner)
Produce this repository's weekly maintenance report as markdown checklists:
1. Open issues with no update for > 60 days, and ai:needs-human issues waiting on a decision. Data (JSON): $issues
2. What merged this week (summarise): $log
3. TODO/FIXME added this week without an issue number (grep the repo).
4. Drift: do the commands in the AGENTS.md Commands table still exist in the Makefile? Any docs/ links broken?
5. If a package manifest exists, list outdated or vulnerable dependencies (read lockfiles/manifests only; do not install).
Keep it under 60 lines. No changes to files.
PROMPT
)"
export AI_PERMISSION_MODE="${AI_PERMISSION_MODE:-dontAsk}"
export AI_ALLOWED_TOOLS="${AI_ALLOWED_TOOLS:-Read,Glob,Grep,Bash(git log *)}"
export AI_MAX_TURNS="${AI_MAX_TURNS:-20}"
report="$(ai_run "$prompt")" || { ai_warn "report failed"; exit 1; }
printf '%s\n' "$report"
if [ "$POST" = 1 ]; then
  url="$(gh issue create --title "Weekly maintenance report — $(date +%F)" --body "$report" --label type/chore 2>/dev/null || gh issue create --title "Weekly maintenance report — $(date +%F)" --body "$report")"
  ai_log "issue created: $url"
fi
