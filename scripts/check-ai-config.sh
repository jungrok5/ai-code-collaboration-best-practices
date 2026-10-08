#!/usr/bin/env bash
# Validate every AI / automation configuration file in the repository.
# Runs locally (make ai-validate), in pre-commit, and in CI (validate-ai-config.yml).
# Missing optional tools are reported as SKIP, never as failure, so the script is
# usable on a fresh machine; CI installs everything.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1

fail=0; pass() { echo "  ✔ $1"; }; skip() { echo "  – skip: $1"; }; bad() { echo "  ✘ $1"; fail=1; }
section() { echo; echo "== $1"; }

section "JSON syntax"
while IFS= read -r f; do
  if jq -e . "$f" >/dev/null 2>&1; then pass "$f"; else bad "$f is not valid JSON"; fi
done < <(git ls-files '*.json' 2>/dev/null || true)

section "Claude Code manifests (claude plugin validate --strict)"
if command -v claude >/dev/null 2>&1; then
  for p in . plugins/*; do
    [ -d "$p/.claude-plugin" ] || continue
    if claude plugin validate "$p" --strict >/tmp/cpv.out 2>&1; then pass "$p"; else bad "$p"; cat /tmp/cpv.out; fi
  done
  if [ -d .claude ]; then
    if claude plugin validate ./.claude --strict >/tmp/cpv.out 2>&1; then pass ".claude (skills/agents)"; else bad ".claude"; cat /tmp/cpv.out; fi
  fi
else skip "claude CLI not installed (npm i -g @anthropic-ai/claude-code)"; fi

section "Plugin version consistency"
if [ -f .claude-plugin/marketplace.json ]; then
  while IFS=$'\t' read -r name src ver; do
    pj="${src#./}/.claude-plugin/plugin.json"
    if [ -f "$pj" ]; then
      pv="$(jq -r .version "$pj")"
      if [ "$pv" = "$ver" ]; then pass "$name $ver"; else bad "$name: marketplace says $ver, plugin.json says $pv"; fi
    fi
  done < <(jq -r '.plugins[] | select(.source|type=="string") | [.name, .source, (.version // "")] | @tsv' .claude-plugin/marketplace.json)
fi

section "settings.json against JSON schema"
if command -v check-jsonschema >/dev/null 2>&1 && [ -f .claude/settings.json ]; then
  if check-jsonschema --schemafile https://www.schemastore.org/claude-code-settings.json .claude/settings.json >/tmp/cjs.out 2>&1; then pass ".claude/settings.json"; else bad ".claude/settings.json"; cat /tmp/cjs.out; fi
else skip "check-jsonschema not installed (pip install check-jsonschema)"; fi

section "GitHub workflows (actionlint)"
if ! compgen -G ".github/workflows/*.y*ml" >/dev/null; then skip "no workflows yet"
elif command -v actionlint >/dev/null 2>&1; then
  if actionlint -no-color >/tmp/al.out 2>&1; then pass ".github/workflows"; else bad "actionlint"; cat /tmp/al.out; fi
else skip "actionlint not installed (pip install actionlint-py)"; fi

section "Shell scripts (shellcheck)"
if command -v shellcheck >/dev/null 2>&1; then
  files="$(git ls-files '*.sh' 2>/dev/null)"
  # shellcheck disable=SC2086
  if [ -n "$files" ] && shellcheck $files >/tmp/sc.out 2>&1; then pass "$(echo "$files" | wc -l | tr -d ' ') scripts"; elif [ -z "$files" ]; then skip "no scripts"; else bad "shellcheck"; cat /tmp/sc.out; fi
else skip "shellcheck not installed"; fi

section "YAML (yamllint)"
if command -v yamllint >/dev/null 2>&1; then
  if yamllint -c .yamllint.yml . >/tmp/yl.out 2>&1; then pass "yaml"; else bad "yamllint"; cat /tmp/yl.out; fi
else skip "yamllint not installed (pip install yamllint)"; fi

section "Markdown (markdownlint-cli2)"
if command -v markdownlint-cli2 >/dev/null 2>&1; then
  if markdownlint-cli2 "**/*.md" >/tmp/ml.out 2>&1; then pass "markdown"; else bad "markdownlint"; tail -30 /tmp/ml.out; fi
else skip "markdownlint-cli2 not installed (npm i -g markdownlint-cli2)"; fi

section "Label descriptions (GitHub limit: 100 characters)"
if [ -f .github/labels.yml ]; then
  bad_labels=0
  while IFS= read -r line; do
    desc="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*description:[[:space:]]*"?//; s/"?[[:space:]]*$//')"
    if [ "${#desc}" -gt 100 ]; then bad ".github/labels.yml: description longer than 100 chars: ${desc:0:60}…"; bad_labels=1; fi
  done < <(grep -E '^[[:space:]]*description:' .github/labels.yml)
  [ "$bad_labels" = 0 ] && pass "all label descriptions ≤ 100 chars"
fi

section "AGENTS.md size (a warning sign, not a rule)"
if [ -f AGENTS.md ]; then
  n=$(wc -l < AGENTS.md)
  if [ "$n" -le 150 ]; then pass "AGENTS.md is $n lines"; else echo "  ! AGENTS.md is $n lines: check each line still prevents a real mistake (docs/15-lean-harness.md)"; fi
fi

echo; if [ "$fail" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit "$fail"
