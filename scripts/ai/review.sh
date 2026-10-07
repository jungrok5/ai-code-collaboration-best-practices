#!/usr/bin/env bash
# Review a pull request with Claude (headless, read-only). With --post, publish ONE review comment (never approves).
# Usage: scripts/ai/review.sh <pr-number> [--post]
set -euo pipefail
# shellcheck source=scripts/ai/common.sh
. "$(dirname "$0")/common.sh"
ai_need gh jq claude
PR="${1:?pr number}"; POST=0; [ "${2:-}" = "--post" ] && POST=1
cd "$(ai_root)"
ai_log "backend: $(ai_backend)"

meta="$(gh pr view "$PR" --json title,body,baseRefName,headRefName,additions,deletions,labels --jq '{title,body,base:.baseRefName,head:.headRefName,additions,deletions,labels:[.labels[].name]}')"
diff_file="$(mktemp)"; gh pr diff "$PR" > "$diff_file"
lines="$(wc -l < "$diff_file" | tr -d ' ')"; [ "$lines" -gt 6000 ] && ai_warn "diff is $lines lines; the review covers the first part only" && head -6000 "$diff_file" > "$diff_file.tmp" && mv "$diff_file.tmp" "$diff_file"

prompt="$(cat <<PROMPT
$(ai_untrusted_banner)
Review pull request #$PR using REVIEW.md and AGENTS.md as the standard (same procedure as the /review-pr skill).
PR metadata (JSON): $meta
The unified diff is in the file: $diff_file (read it). You may read repository files for context. Do not modify anything.

Priorities: 1) correctness bugs and edge cases, 2) security, 3) missing/weak tests, 4) scope creep or > 400 changed lines, 5) compatibility.
Do NOT comment on formatting that CI enforces. Cite \`path:line\`. No praise-only comments. Say what you did not verify.
Output markdown exactly in this shape:
### Verdict: APPROVE | REQUEST CHANGES | COMMENT
<2-3 line summary>
#### 🔴 Blocking
#### 🟡 Should fix
#### ⚪ Nits
#### Not verified
PROMPT
)"
export AI_PERMISSION_MODE="${AI_PERMISSION_MODE:-dontAsk}"
export AI_ALLOWED_TOOLS="${AI_ALLOWED_TOOLS:-Read,Glob,Grep,Bash(git diff *),Bash(git log *),Bash(gh pr view *)}"
export AI_MAX_TURNS="${AI_MAX_TURNS:-25}"
review="$(ai_run "$prompt")" || { ai_warn "review failed"; rm -f "$diff_file"; exit 1; }
rm -f "$diff_file"
printf '%s\n' "$review"

if [ "$POST" = 1 ]; then
  body="$(printf '%s\n\n---\n_AI review (advisory, headless Claude Code via %s). It never approves; a human CODEOWNER decides._\n' "$review" "$(ai_backend | cut -d'(' -f1)")"
  gh pr comment "$PR" --body "$body" >/dev/null && ai_log "review comment posted on #$PR"
else
  ai_log "dry run: re-run with --post to publish as a PR comment"
fi
