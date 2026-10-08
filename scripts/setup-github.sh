#!/usr/bin/env bash
# Apply the GitHub-side configuration that a template repository cannot copy:
#   settings  : squash-only merges, auto-merge, delete-branch-on-merge, update-branch, secret scanning + push protection
#   labels    : create/update every label in .github/labels.yml (idempotent)
#   rulesets  : create or update rulesets from scripts/rulesets/*.json (main.json + feature-branches.json)
#               PROFILE=prototype applies main.json without the human-approval gates (PR + CI + history rules stay);
#               see docs/16-team-scale-ai.md for when a repo should switch back (PROFILE=production, the default)
#   check     : print the current state without changing anything
#   all       : settings + labels + rulesets
# Requires: gh (authenticated as a repo admin) and jq. Usage: scripts/setup-github.sh <what> [owner/repo]
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1

WHAT="${1:-check}"
PROFILE="${PROFILE:-production}"
case "$PROFILE" in production|prototype) ;; *) echo "PROFILE must be production or prototype"; exit 2 ;; esac
REPO="${2:-${GITHUB_REPOSITORY:-}}"
command -v gh >/dev/null || { echo "gh is required: https://cli.github.com"; exit 1; }
command -v jq >/dev/null || { echo "jq is required"; exit 1; }
if [ -z "$REPO" ]; then REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"; fi
[ -n "$REPO" ] || { echo "cannot determine repository; pass owner/repo"; exit 1; }
gh auth status >/dev/null 2>&1 || [ -n "${GH_TOKEN:-}" ] || { echo "run: gh auth login"; exit 1; }

api() { gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "$@"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

do_settings() {
  bold "Repository settings ($REPO)"
  api --method PATCH "/repos/$REPO" \
    -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
    -F allow_auto_merge=true -F delete_branch_on_merge=true -F allow_update_branch=true \
    -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY >/dev/null \
    && ok "squash-only, PR title as commit subject, auto-merge, delete branch on merge, update-branch"
  if api --method PATCH "/repos/$REPO" --input - >/dev/null 2>&1 <<'JSON'
{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}
JSON
  then ok "secret scanning + push protection enabled"; else warn "secret scanning not enabled (private repo without GitHub Secret Protection?)"; fi
  # Allow GitHub Actions to create/approve PRs (needed by dependabot-auto-merge and release-please with GITHUB_TOKEN)
  if api --method PUT "/repos/$REPO/actions/permissions/workflow" --input - >/dev/null 2>&1 <<'JSON'
{"default_workflow_permissions":"read","can_approve_pull_request_reviews":true}
JSON
  then ok "Actions: default token read-only, may create/approve PRs"; else warn "could not set Actions workflow permissions (org policy?)"; fi
  warn "Manual (UI only): Settings → General → 'Template repository' (if this is the template); Copilot → Code review / MCP / firewall; Advanced Security → CodeQL default setup if you prefer it over .github/workflows/codeql.yml"
}

do_labels() {
  bold "Labels from .github/labels.yml"
  local name="" color="" desc="" n=0
  flush() {
    if [ -n "$name" ]; then
      if gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force >/dev/null 2>&1; then n=$((n+1)); else warn "label failed: $name"; fi
    fi
  }
  while IFS= read -r line; do
    case "$line" in
      "- name:"*)        flush; name="$(printf '%s' "$line" | sed -E 's/^- name:[[:space:]]*"?//; s/"?[[:space:]]*$//')"; color=""; desc="" ;;
      *"color:"*)        color="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*color:[[:space:]]*"?//; s/"?[[:space:]]*$//')" ;;
      *"description:"*)  desc="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*description:[[:space:]]*"?//; s/"?[[:space:]]*$//')" ;;
    esac
  done < .github/labels.yml
  flush
  ok "$n labels created/updated"
}

do_rulesets() {
  bold "Rulesets from scripts/rulesets/ (profile: $PROFILE)"
  local existing tmp
  existing="$(api "/repos/$REPO/rulesets" 2>/dev/null || echo '[]')"
  tmp="$(mktemp)"
  for f in scripts/rulesets/main.json scripts/rulesets/feature-branches.json; do
    [ -f "$f" ] || continue
    local rname rid src="$f"
    rname="$(jq -r .name "$f")"
    if [ "$PROFILE" = prototype ] && [ "$f" = scripts/rulesets/main.json ]; then
      # Prototype: keep PR-only, CI, squash, no force-push/deletion; drop human-approval gates.
      jq '(.rules[] | select(.type == "pull_request") | .parameters) |= (.required_approving_review_count = 0
            | .require_code_owner_review = false | .require_last_push_approval = false | .required_review_thread_resolution = false)
          | (.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks)
            |= map(select(.context != "agent-approval-check"))' "$f" > "$tmp"
      src="$tmp"
    fi
    rid="$(printf '%s' "$existing" | jq -r --arg n "$rname" '.[] | select(.name==$n) | .id' | head -1)"
    if [ -n "$rid" ]; then
      api --method PUT "/repos/$REPO/rulesets/$rid" --input "$src" >/dev/null && ok "updated ruleset: $rname (id $rid)"
    else
      api --method POST "/repos/$REPO/rulesets" --input "$src" >/dev/null && ok "created ruleset: $rname"
    fi
  done
  rm -f "$tmp"
  if [ "$PROFILE" = prototype ]; then
    api --method POST "/repos/$REPO/actions/variables" -f name=REVIEW_PROFILE -f value=prototype >/dev/null 2>&1 \
      || api --method PATCH "/repos/$REPO/actions/variables/REVIEW_PROFILE" -f value=prototype >/dev/null 2>&1 || true
    warn "prototype profile: human approval is optional on $REPO. Switch back with: make github-setup PROFILE=production"
  else
    api --method DELETE "/repos/$REPO/actions/variables/REVIEW_PROFILE" >/dev/null 2>&1 || true
  fi
  warn "Optional: scripts/rulesets/optional-copilot-review.json (apply with: gh api --method POST /repos/$REPO/rulesets --input scripts/rulesets/optional-copilot-review.json)"
  warn "Rulesets need GitHub Pro/Team/Enterprise for private repos (free for public repos)."
}

do_check() {
  bold "Current state ($REPO)"
  api "/repos/$REPO" --jq '"  merge: squash=\(.allow_squash_merge) merge=\(.allow_merge_commit) rebase=\(.allow_rebase_merge) auto-merge=\(.allow_auto_merge) delete-branch=\(.delete_branch_on_merge) update-branch=\(.allow_update_branch) template=\(.is_template)"'
  api "/repos/$REPO/rulesets" --jq '.[] | "  ruleset: \(.name) [\(.enforcement)]"' 2>/dev/null || echo "  rulesets: none / not available"
  echo "  labels: $(api "/repos/$REPO/labels?per_page=100" --jq 'length' 2>/dev/null || echo '?')"
  echo "  secrets needed by workflows: ANTHROPIC_API_KEY (or CLAUDE_CODE_OAUTH_TOKEN), optional RELEASE_PLEASE_TOKEN, REPO_ADMIN_TOKEN"
  api "/repos/$REPO/actions/secrets" --jq '.secrets[] | "  secret present: \(.name)"' 2>/dev/null || true
}

case "$WHAT" in
  settings) do_settings ;;
  labels)   do_labels ;;
  rulesets) do_rulesets ;;
  check)    do_check ;;
  all)      do_settings; do_labels; do_rulesets; do_check ;;
  *) echo "usage: $0 <settings|labels|rulesets|check|all> [owner/repo]"; exit 2 ;;
esac
