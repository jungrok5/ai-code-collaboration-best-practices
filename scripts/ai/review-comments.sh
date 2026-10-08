#!/usr/bin/env bash
# Print last N days of PR review comments (inline + review summaries) as compact JSON lines, for the weekly
# "recurring findings → rules" step. Deterministic; no LLM. Usage: scripts/ai/review-comments.sh [days=7]
set -euo pipefail
days="${1:-7}"
repo="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
since="$(date -u -d "-${days} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"${days}"d +%Y-%m-%dT%H:%M:%SZ)"
gh api --paginate -X GET "repos/$repo/pulls/comments" -f since="$since" -f per_page=100 \
  --jq '.[] | {pr: (.pull_request_url | split("/") | last), path, by: .user.login, body: (.body | gsub("\\s+"; " ") | .[0:300])}'
