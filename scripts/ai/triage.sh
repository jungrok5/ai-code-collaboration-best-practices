#!/usr/bin/env bash
# Triage an issue with Claude (headless) and, with --post, apply labels + one comment. Never closes issues.
# Usage: scripts/ai/triage.sh <issue-number> [--post]
set -euo pipefail
# shellcheck source=scripts/ai/common.sh
. "$(dirname "$0")/common.sh"
ai_need gh jq claude
ISSUE="${1:?issue number}"; POST=0; [ "${2:-}" = "--post" ] && POST=1
cd "$(ai_root)"
ai_log "backend: $(ai_backend)"

issue_json="$(gh issue view "$ISSUE" --json number,title,body,labels,author,comments --jq '{number,title,body,labels:[.labels[].name],author:.author.login,comments:[.comments[] | {author:.author.login, body:.body}]}')"
labels_available="$(ai_existing_labels | tr '\n' ' ')"
schema='{"type":"object","properties":{"type":{"type":"string"},"areas":{"type":"array","items":{"type":"string"}},"priority":{"type":"string"},"size":{"type":"string"},"ready":{"type":"boolean"},"missing":{"type":"array","items":{"type":"string"}},"duplicates":{"type":"array","items":{"type":"integer"}},"comment":{"type":"string"}},"required":["type","priority","ready","missing","comment"]}'

prompt="$(cat <<PROMPT
$(ai_untrusted_banner)
You are the issue triage assistant for this repository (same rules as the /triage-issue skill).
Available labels (use ONLY these, never invent): $labels_available
Issue (JSON): $issue_json

1. Check completeness against .github/ISSUE_TEMPLATE/*.yml: background, goal, testable acceptance criteria, scope/files, out of scope, test plan.
2. Classify: exactly one type/* label, zero or more area/* labels (only when clearly supported), exactly one priority/p0..p3, optionally one size/* label.
3. ready = true ONLY if acceptance criteria are testable, scope is bounded, and no product decision is pending.
4. duplicates: issue numbers that look like duplicates (search with gh if allowed; otherwise leave empty).
5. comment: at most 8 lines of markdown for humans: classification + one-line rationale, what is missing for ai:ready, possible duplicates, suggested first step.
Return the JSON object only.
PROMPT
)"
export AI_PERMISSION_MODE="${AI_PERMISSION_MODE:-dontAsk}"
export AI_ALLOWED_TOOLS="${AI_ALLOWED_TOOLS:-Read,Glob,Grep,Bash(gh issue list *),Bash(gh issue view *)}"
export AI_MAX_TURNS="${AI_MAX_TURNS:-12}"
result="$(ai_run "$prompt" --json-schema "$schema")" || { ai_warn "triage failed"; exit 1; }
printf '%s\n' "$result" | jq .

if [ "$POST" = 1 ]; then
  labels="$(printf '%s' "$result" | jq -r '[.type, .priority, (.size // empty)] + (.areas // []) | .[]' | ai_filter_labels | paste -sd, -)"
  [ -n "$labels" ] && gh issue edit "$ISSUE" --add-label "$labels" && ai_log "labels applied: $labels"
  readiness="$(printf '%s' "$result" | jq -r 'if .ready then "ready for an agent" else "needs human input" end')"
  comment="$(printf '**Triage (AI-assisted, advisory)**\n\n%s\n\n_Agent-readiness: %s. A maintainer adds the ai:ready label._' "$(printf '%s' "$result" | jq -r .comment)" "$readiness")"
  gh issue comment "$ISSUE" --body "$comment" >/dev/null && ai_log "comment posted on #$ISSUE"
else
  ai_log "dry run: re-run with --post to apply labels and comment"
fi
