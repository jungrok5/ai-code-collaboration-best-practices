#!/usr/bin/env bash
# Shared GitHub helpers for scripts/setup-github.sh and scripts/doctor.sh. Source it; it defines functions only.
# shellcheck shell=bash

# api <args...>: gh api with the versioned JSON headers. GH_TIMEOUT (seconds) bounds each call when `timeout` exists.
api() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "${GH_TIMEOUT:-20}" gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "$@"
  else
    gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "$@"
  fi
}

# repo_from_remote: owner/name parsed from the origin remote (no network), or empty.
repo_from_remote() {
  git remote get-url origin 2>/dev/null | sed -E 's#^(git@github.com:|https://github.com/|ssh://git@github.com/)##; s#\.git$##' \
    | grep -E '^[^/]+/[^/]+$' || true
}

# labels_yml <file>: prints "name<TAB>color<TAB>description" for every label in .github/labels.yml.
labels_yml() {
  local name="" color="" desc=""
  while IFS= read -r line; do
    case "$line" in
      "- name:"*)
        [ -n "$name" ] && printf '%s\t%s\t%s\n' "$name" "$color" "$desc"
        name="$(printf '%s' "$line" | sed -E 's/^- name:[[:space:]]*"?//; s/"?[[:space:]]*$//')"; color=""; desc="" ;;
      *"color:"*)       color="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*color:[[:space:]]*"?//; s/"?[[:space:]]*$//')" ;;
      *"description:"*) desc="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*description:[[:space:]]*"?//; s/"?[[:space:]]*$//')" ;;
    esac
  done < "${1:-.github/labels.yml}"
  [ -n "$name" ] && printf '%s\t%s\t%s\n' "$name" "$color" "$desc"
  return 0
}

# ruleset_for_profile <file> <production|prototype>: the ruleset JSON as it should be applied for that profile.
# Prototype keeps PR-only, CI, squash and history rules and drops the human-approval gates on main.json.
ruleset_for_profile() {
  local f="$1" profile="${2:-production}"
  if [ "$profile" = prototype ] && [ "$(basename "$f")" = main.json ]; then
    jq '(.rules[] | select(.type == "pull_request") | .parameters) |= (.required_approving_review_count = 0
          | .require_code_owner_review = false | .require_last_push_approval = false | .required_review_thread_resolution = false)
        | (.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks)
          |= map(select(.context != "agent-approval-check"))' "$f"
  else
    cat "$f"
  fi
}
