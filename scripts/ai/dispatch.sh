#!/usr/bin/env bash
# Route a GitHub Actions event to the matching script (used by .github/workflows/ai-local-runner.yml on a
# self-hosted runner with a local LLM; also handy for testing: GITHUB_EVENT_NAME=... GITHUB_EVENT_PATH=... scripts/ai/dispatch.sh)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ev="${GITHUB_EVENT_NAME:?GITHUB_EVENT_NAME}"; path="${GITHUB_EVENT_PATH:-}"
j() { [ -n "$path" ] && jq -r "$1" "$path" 2>/dev/null || echo ""; }
case "$ev" in
  issues)
    action="$(j .action)"; n="$(j .issue.number)"
    case "$action" in
      opened) exec "$here/triage.sh" "$n" --post ;;
      labeled) [ "$(j .label.name)" = "ai:ready" ] && exec "$here/implement.sh" "$n" --post; echo "label $(j .label.name): nothing to do" ;;
      *) echo "issues/$action: nothing to do" ;;
    esac ;;
  issue_comment)
    body="$(j .comment.body)"; n="$(j .issue.number)"; cid="$(j .comment.id)"
    if printf '%s' "$body" | grep -qiE '(^|[[:space:]])@claude([[:space:][:punct:]]|$)'; then exec "$here/respond.sh" "$n" --post --comment-id "$cid"; fi
    echo "no @claude mention" ;;
  pull_request) exec "$here/review.sh" "$(j .pull_request.number)" --post ;;
  workflow_run)
    n="$(j '.workflow_run.pull_requests[0].number')"
    [ -n "$n" ] && [ "$n" != "null" ] && exec "$here/fix-ci.sh" "$n" --post; echo "workflow_run without PR: nothing to do" ;;
  schedule) exec "$here/maintenance.sh" --post ;;
  workflow_dispatch)
    task="$(j .inputs.task)"; n="$(j .inputs.number)"
    case "$task" in
      triage|review|implement|fix-ci) exec "$here/$task.sh" "$n" --post ;;
      respond) exec "$here/respond.sh" "$n" --post --text "$(j .inputs.text)" ;;
      maintenance) exec "$here/maintenance.sh" --post ;;
      queue) exec "$here/queue.sh" --post ;;
      *) echo "unknown task: $task"; exit 2 ;;
    esac ;;
  *) echo "event $ev: nothing to do" ;;
esac
