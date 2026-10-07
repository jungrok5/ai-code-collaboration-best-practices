#!/usr/bin/env bash
# Pin every third-party `uses: owner/repo@<tag-or-branch>` in .github/workflows to a full commit SHA,
# keeping the human-readable version as a trailing comment (Dependabot updates both together):
#   uses: actions/checkout@v7   →   uses: actions/checkout@<40-hex-sha> # v7
# Usage: scripts/pin-actions.sh [--check]     (--check: exit 1 if any unpinned action remains)
# Requires: git (network access to github.com). Local actions (./), docker://, and already-pinned refs are skipped.
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1

check_only=0; [ "${1:-}" = "--check" ] && check_only=1
unpinned=0; changed=0
declare -A cache

resolve() { # owner/repo ref -> sha (peeled tag preferred), empty when not found
  local repo="$1" ref="$2" key="$1@$2" out
  if [ -n "${cache[$key]:-}" ]; then printf '%s' "${cache[$key]}"; return; fi
  out="$(git ls-remote "https://github.com/$repo.git" "refs/tags/$ref^{}" "refs/tags/$ref" "refs/heads/$ref" 2>/dev/null || true)"
  local sha
  sha="$(printf '%s\n' "$out" | awk '/\^\{\}$/ {print $1; exit}')"
  [ -z "$sha" ] && sha="$(printf '%s\n' "$out" | awk 'NR==1 {print $1}')"
  cache[$key]="$sha"; printf '%s' "$sha"
}

while IFS= read -r file; do
  tmp="$(mktemp)"
  while IFS= read -r line; do
    if [[ "$line" =~ ^([[:space:]]*-?[[:space:]]*uses:[[:space:]]*)([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(/[^@[:space:]]*)?@([^[:space:]#]+)([[:space:]]*#.*)?$ ]]; then
      prefix="${BASH_REMATCH[1]}"; repo="${BASH_REMATCH[2]}"; sub="${BASH_REMATCH[3]}"; ref="${BASH_REMATCH[4]}"
      if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then printf '%s\n' "$line" >> "$tmp"; continue; fi
      if [ "$check_only" = 1 ]; then echo "unpinned: $file: $repo$sub@$ref"; unpinned=1; printf '%s\n' "$line" >> "$tmp"; continue; fi
      sha="$(resolve "$repo" "$ref")"
      if [ -n "$sha" ]; then
        printf '%s%s%s@%s # %s\n' "$prefix" "$repo" "$sub" "$sha" "$ref" >> "$tmp"; changed=$((changed+1))
        echo "pinned: $repo$sub@$ref -> ${sha:0:12}"
      else
        echo "WARN: could not resolve $repo@$ref (left as is)"; unpinned=1; printf '%s\n' "$line" >> "$tmp"
      fi
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$file"
  if ! cmp -s "$tmp" "$file"; then mv "$tmp" "$file"; else rm -f "$tmp"; fi
done < <(find .github/workflows -name '*.yml' -o -name '*.yaml' | sort)

if [ "$check_only" = 1 ]; then [ "$unpinned" = 0 ] && echo "all actions pinned" ; exit "$unpinned"; fi
echo "done: $changed uses: lines pinned"; exit 0
