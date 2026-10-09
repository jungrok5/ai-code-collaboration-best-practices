#!/usr/bin/env bash
# Apply the GitHub-side configuration that a template repository cannot copy:
#   settings  : squash-only merges, auto-merge, delete-branch-on-merge, update-branch, secret scanning + push protection
#   labels    : create/update every label in .github/labels.yml (idempotent)
#   rulesets  : create or update rulesets from scripts/rulesets/*.json (main.json + feature-branches.json)
#               PROFILE=prototype applies main.json without the human-approval gates (PR + CI + history rules stay);
#               see docs/16-team-scale-ai.md for when a repo should switch back (PROFILE=production, the default)
#   pages     : (hub) Pages source = GitHub Actions, and let main deploy to the github-pages environment
#   check     : verify the current state without changing anything (same as: scripts/doctor.sh --scope github)
#   all       : settings + labels + rulesets (+ pages in the hub)
# TEMPLATE=1 also marks the repository as a template (the hub). Nothing here needs the web UI except the
# Copilot settings (code review / MCP / firewall) and installing GitHub Apps; `make doctor` reports those.
# Requires: gh (authenticated as a repo admin) and jq. Usage: scripts/setup-github.sh <what> [owner/repo]
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1

WHAT="${1:-check}"
if [ "$WHAT" = check ]; then exec scripts/doctor.sh --scope github ${2:+--repo "$2"}; fi
# shellcheck source=lib/github.sh
. scripts/lib/github.sh
PROFILE="${PROFILE:-production}"
case "$PROFILE" in production|prototype) ;; *) echo "PROFILE must be production or prototype"; exit 2 ;; esac
REPO="${2:-${GITHUB_REPOSITORY:-}}"
command -v gh >/dev/null || { echo "gh is required: https://cli.github.com"; exit 1; }
command -v jq >/dev/null || { echo "jq is required"; exit 1; }
if [ -z "$REPO" ]; then REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"; fi
[ -n "$REPO" ] || { echo "cannot determine repository; pass owner/repo"; exit 1; }
gh auth status >/dev/null 2>&1 || [ -n "${GH_TOKEN:-}" ] || { echo "run: gh auth login"; exit 1; }

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
  if [ "${TEMPLATE:-0}" = 1 ]; then api --method PATCH "/repos/$REPO" -F is_template=true >/dev/null && ok "marked as template repository"; fi
  if api --method PATCH "/repos/$REPO" --input - >/dev/null 2>&1 <<'JSON'
{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}
JSON
  then ok "secret scanning + push protection enabled"; else warn "secret scanning not enabled (private repo without GitHub Secret Protection?)"; fi
  # Allow GitHub Actions to create/approve PRs (needed by dependabot-auto-merge and release-please with GITHUB_TOKEN)
  if api --method PUT "/repos/$REPO/actions/permissions/workflow" --input - >/dev/null 2>&1 <<'JSON'
{"default_workflow_permissions":"read","can_approve_pull_request_reviews":true}
JSON
  then ok "Actions: default token read-only, may create/approve PRs"; else warn "could not set Actions workflow permissions (org policy?)"; fi
  warn "Web UI only: Copilot code review / MCP / firewall settings and GitHub App installs. Verify everything else with: make doctor"
}

do_labels() {
  bold "Labels from .github/labels.yml"
  local n=0 name color desc
  while IFS=$'	' read -r name color desc; do
    if gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force >/dev/null 2>&1; then n=$((n+1)); else warn "label failed: $name"; fi
  done < <(labels_yml .github/labels.yml)
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
    ruleset_for_profile "$f" "$PROFILE" > "$tmp"; src="$tmp"
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

do_pages() {
  bold "GitHub Pages (work board + guide)"
  if api "/repos/$REPO/pages" >/dev/null 2>&1; then
    if api --method PUT "/repos/$REPO/pages" -f build_type=workflow >/dev/null 2>&1; then ok "Pages source: GitHub Actions"; else warn "could not set Pages source"; fi
  else
    if api --method POST "/repos/$REPO/pages" -f build_type=workflow >/dev/null 2>&1; then ok "Pages enabled (source: GitHub Actions)"; else warn "could not enable Pages (private repo on a free plan?)"; fi
  fi
  api --method PUT "/repos/$REPO/environments/github-pages" --input - >/dev/null 2>&1 <<'JSON' || true
{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
JSON
  api --method POST "/repos/$REPO/environments/github-pages/deployment-branch-policies" -f name=main -f type=branch >/dev/null 2>&1 || true
  ok "github-pages environment: main may deploy"
}

is_hub() { [ -f .claude-plugin/marketplace.json ] && [ -f .github/workflows/work-board.yml ]; }

case "$WHAT" in
  settings) do_settings ;;
  labels)   do_labels ;;
  rulesets) do_rulesets ;;
  pages)    do_pages ;;
  all)      do_settings; do_labels; do_rulesets; if is_hub; then do_pages; fi; scripts/doctor.sh --scope github --repo "$REPO" || true ;;
  *) echo "usage: $0 <settings|labels|rulesets|pages|check|all> [owner/repo]"; exit 2 ;;
esac
