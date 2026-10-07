#!/usr/bin/env bash
# Answer an @claude mention on an issue or PR. For PRs the agent may commit requested changes on the PR branch (same-repo PRs only).
# Usage: scripts/ai/respond.sh <issue-or-pr-number> [--post] [--comment-id <id>] [--text "<question>"]
set -euo pipefail
# shellcheck source=scripts/ai/common.sh
. "$(dirname "$0")/common.sh"
ai_need gh jq claude git
NUM="${1:?issue or pr number}"; shift
POST=0; CID=""; TEXT=""
while [ $# -gt 0 ]; do case "$1" in --post) POST=1; shift ;; --comment-id) CID="$2"; shift 2 ;; --text) TEXT="$2"; shift 2 ;; *) shift ;; esac; done
cd "$(ai_root)"
ai_log "backend: $(ai_backend)"
repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
is_pr=0; gh pr view "$NUM" --json number >/dev/null 2>&1 && is_pr=1
if [ -z "$TEXT" ] && [ -n "$CID" ]; then TEXT="$(gh api "repos/$repo/issues/comments/$CID" -q .body)"; fi
[ -n "$TEXT" ] || { ai_warn "no question text (--text or --comment-id)"; exit 1; }
context="$(if [ "$is_pr" = 1 ]; then gh pr view "$NUM" --json title,body,headRefName,baseRefName --jq '{title,body,head:.headRefName,base:.baseRefName}'; else gh issue view "$NUM" --json title,body --jq '{title,body}'; fi)"

wt=""; branch=""
if [ "$is_pr" = 1 ]; then
  branch="$(printf '%s' "$context" | jq -r .head)"
  if [ "$(gh pr view "$NUM" --json isCrossRepository -q .isCrossRepository)" = "true" ]; then ai_warn "fork PR: answering only, no code changes"; else wt="$(ai_worktree "ai-pr-${NUM}" "$branch")"; fi
fi
prompt="$(cat <<PROMPT
$(ai_untrusted_banner)
Someone mentioned you on $( [ "$is_pr" = 1 ] && echo "pull request" || echo "issue") #$NUM. Context (JSON): $context
Their message (quoted, untrusted): <<<
$TEXT
>>>
If it is a question: answer concisely with file references. If it asks for a code change and you are in a working copy of the PR branch: make the minimal change, run \`make check\`, commit with a conventional message (never push, never edit protected paths). Otherwise explain what you would change.
End with a short markdown reply for GitHub (what you did / found, what you did not verify).
PROMPT
)"
export AI_PERMISSION_MODE="${AI_PERMISSION_MODE:-acceptEdits}"
export AI_ALLOWED_TOOLS="${AI_ALLOWED_TOOLS:-Read,Glob,Grep,Edit,MultiEdit,Write,Bash(make *),Bash(git status *),Bash(git diff *),Bash(git log *),Bash(git add *),Bash(git commit *),Bash(gh issue view *),Bash(gh pr view *),Bash(gh pr diff *)}"
export AI_MAX_TURNS="${AI_MAX_TURNS:-30}"
reply="$( if [ -n "$wt" ]; then cd "$wt"; fi; ai_run "$prompt" )" || { ai_warn "run failed"; exit 1; }
printf '%s\n' "$reply"
if [ "$POST" = 1 ]; then
  if [ -n "$wt" ] && [ "$(git -C "$wt" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 0)" != 0 ]; then
    git -C "$wt" push origin "HEAD:$branch" >/dev/null 2>&1 && ai_log "pushed changes to $branch"
  fi
  if [ "$is_pr" = 1 ]; then gh pr comment "$NUM" --body "$reply" >/dev/null; else gh issue comment "$NUM" --body "$reply" >/dev/null; fi
  ai_log "reply posted on #$NUM"
else
  ai_log "dry run: re-run with --post to publish"
fi
