#!/usr/bin/env bash
# One-time local setup after cloning (make setup).
#   scripts/bootstrap.sh [--mode project|hub] [--marketplace owner/repo] [--no-claude] [--yes]
#
# --mode project : this clone is a *product* repository created from the template.
#                  Removes hub-only files (plugins/, .claude-plugin/, research docs) and points
#                  .claude/settings.json at the shared marketplace (--marketplace).
# --mode hub     : this clone IS the shared template/marketplace repository (default when
#                  plugins/ exists and --mode is not given).
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1

MODE=""; MARKETPLACE=""; USE_CLAUDE=1; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --marketplace) MARKETPLACE="$2"; shift 2 ;;
    --no-claude) USE_CLAUDE=0; shift ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$MODE" ]; then if [ -d plugins ] && [ -f .claude-plugin/marketplace.json ]; then MODE=hub; else MODE=project; fi; fi

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
# tool <name> <version-cmd-or-empty> <hint>  → ok line or warning with hint
tool() {
  local name="$1" vcmd="$2" hint="$3" v=""
  if have "$name"; then
    [ -n "$vcmd" ] && v="$(bash -c "$vcmd" 2>/dev/null | head -1)"
    ok "$name ${v}"
  else
    warn "$name not found: $hint"
  fi
}

bold "1/6 Tooling"
for t in git jq; do if ! have "$t"; then echo "  ✘ $t is required"; exit 1; fi; ok "$t"; done
tool gh "gh --version | awk 'NR==1{print \$3}'" "https://cli.github.com (needed for labels, rulesets, PR helpers)"
tool claude "claude --version | awk '{print \$1}'" "npm i -g @anthropic-ai/claude-code (optional, for Claude Code users)"
tool node "node --version" "https://nodejs.org (only if the project uses Node)"
tool python3 "python3 --version | awk '{print \$2}'" "only if the project uses Python"

bold "2/6 Validation tools (python)"
if ! have pre-commit || ! have yamllint || ! have check-jsonschema || ! have actionlint; then
  if have uv; then uv tool install -q pre-commit yamllint check-jsonschema actionlint-py 2>/dev/null || true
  elif have pipx; then for p in pre-commit yamllint check-jsonschema actionlint-py; do pipx install -q "$p" 2>/dev/null || true; done
  elif have pip3; then pip3 install -q --user pre-commit yamllint check-jsonschema actionlint-py 2>/dev/null || true
  fi
fi
export PATH="$HOME/.local/bin:$PATH"
for t in pre-commit yamllint check-jsonschema actionlint shellcheck; do tool "$t" "" "not installed locally (CI still runs it)"; done
if ! have markdownlint-cli2 && have npm; then npm i -g markdownlint-cli2 >/dev/null 2>&1 || true; fi
tool markdownlint-cli2 "" "npm i -g markdownlint-cli2"

bold "3/6 Mode: $MODE"
if [ "$MODE" = project ]; then
  if [ -z "$MARKETPLACE" ]; then
    MARKETPLACE="$(jq -r '.extraKnownMarketplaces | to_entries[0].value.source.repo // empty' .claude/settings.json 2>/dev/null || true)"
  fi
  if [ -d plugins ] || [ -d .claude-plugin ]; then
    if [ "$YES" = 1 ] || { read -r -p "  Remove hub-only files (plugins/, .claude-plugin/, docs/10-research-crosscheck.md)? [y/N] " a && [ "${a:-n}" = y ]; }; then
      git rm -rq --cached plugins .claude-plugin docs/10-research-crosscheck.md 2>/dev/null || true
      rm -rf plugins .claude-plugin docs/10-research-crosscheck.md
      ok "hub-only files removed; this repo now consumes plugins from the marketplace: ${MARKETPLACE:-<unset>}"
    fi
  fi
  if [ -n "$MARKETPLACE" ]; then
    tmp="$(mktemp)"; jq --arg r "$MARKETPLACE" '.extraKnownMarketplaces["ai-collab"].source.repo = $r' .claude/settings.json > "$tmp" && mv "$tmp" .claude/settings.json
    ok ".claude/settings.json marketplace → $MARKETPLACE"
  fi
  # The hub README describes the template itself; give the product repo a fresh stub and keep the original for reference.
  if grep -q '팀 템플릿 레포' README.md 2>/dev/null; then
    mkdir -p docs
    if ! git mv -q README.md docs/00-template-readme.md 2>/dev/null; then mv README.md docs/00-template-readme.md; fi
    name="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
    cat > README.md <<README
# $name

> Created from the AI code collaboration template (${MARKETPLACE:-hub}). Team rules for humans and AI agents: \`AGENTS.md\`.

## Quick start

\`\`\`bash
make setup      # deps, pre-commit hooks, Claude plugin, config validation
make check      # lint + typecheck + test (same as CI)
\`\`\`

## Docs

- Daily workflow: [docs/01-playbook.md](docs/01-playbook.md)
- All docs: [docs/README.md](docs/README.md) · template overview: [docs/00-template-readme.md](docs/00-template-readme.md)
README
    ok "README.md → fresh project stub (hub README kept at docs/00-template-readme.md)"
  fi
  if [ -f docs/README.md ] && grep -q '10-research-crosscheck' docs/README.md; then
    sed -i.bak '/10-research-crosscheck/d' docs/README.md && rm -f docs/README.md.bak
    ok "docs index: removed the hub-only research cross-check entry"
  fi
else
  ok "hub mode: keeping plugins/ and marketplace manifest"
fi

# Fill in repository placeholders from the git remote (OWNER/REPO, @OWNER) when they are still present.
remote="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##' || true)"
if [ -n "$remote" ] && printf '%s' "$remote" | grep -q '/'; then
  owner="${remote%%/*}"
  if grep -q 'OWNER/REPO' .github/ISSUE_TEMPLATE/config.yml 2>/dev/null; then
    sed -i.bak "s#OWNER/REPO#$remote#g" .github/ISSUE_TEMPLATE/config.yml && rm -f .github/ISSUE_TEMPLATE/config.yml.bak
    ok "issue template links → $remote"
  elif [ "$MODE" = project ] && [ -n "$MARKETPLACE" ] && [ "$MARKETPLACE" != "$remote" ] && grep -q "$MARKETPLACE" .github/ISSUE_TEMPLATE/config.yml 2>/dev/null; then
    sed -i.bak "s#$MARKETPLACE#$remote#g" .github/ISSUE_TEMPLATE/config.yml && rm -f .github/ISSUE_TEMPLATE/config.yml.bak
    ok "issue template links: $MARKETPLACE → $remote"
  fi
  if grep -q '@OWNER' .github/CODEOWNERS 2>/dev/null; then
    sed -i.bak "s#@OWNER#@$owner#g" .github/CODEOWNERS && rm -f .github/CODEOWNERS.bak
    ok "CODEOWNERS default owner → @$owner (edit to a team, e.g. @org/maintainers)"
  elif [ "$MODE" = project ] && [ -n "$MARKETPLACE" ]; then
    hub_owner="${MARKETPLACE%%/*}"
    if [ "$hub_owner" != "$owner" ] && grep -qE "@$hub_owner([[:space:]]|$)" .github/CODEOWNERS 2>/dev/null; then
      sed -i.bak -E "s#@$hub_owner([[:space:]]|\$)#@$owner\1#g" .github/CODEOWNERS && rm -f .github/CODEOWNERS.bak
      ok "CODEOWNERS owner: @$hub_owner → @$owner"
    fi
  fi
fi

bold "4/6 Project dependencies + git hooks"
scripts/stack.sh setup || warn "dependency install failed (fix and re-run: make setup)"
if have pre-commit; then pre-commit install --install-hooks >/dev/null && pre-commit install --hook-type commit-msg >/dev/null && ok "pre-commit hooks installed"; fi
if git config --local commit.template .gitmessage.txt 2>/dev/null; then ok "commit template set (.gitmessage.txt)"; fi

bold "5/6 Claude Code plugin"
if [ "$USE_CLAUDE" = 1 ] && have claude; then
  mp="$(jq -r '.extraKnownMarketplaces["ai-collab"].source.repo // empty' .claude/settings.json 2>/dev/null || true)"
  if [ -n "$mp" ]; then
    if claude plugin marketplace add "$mp" >/dev/null 2>&1; then ok "marketplace registered: $mp"; else warn "could not add marketplace $mp (private repo or offline? run: claude plugin marketplace add $mp)"; fi
    if claude plugin install team-ai-workflow@ai-collab >/dev/null 2>&1; then ok "plugin installed: team-ai-workflow@ai-collab"; else warn "plugin install skipped (Claude Code prompts on first session; or try: claude --plugin-dir ./plugins/team-ai-workflow)"; fi
  fi
else
  warn "skipping Claude plugin setup"
fi

bold "6/6 Validate"
scripts/check-ai-config.sh || warn "validation reported problems (see above)"

echo
bold "What is left: scripts/doctor.sh (make doctor) checks this machine and the GitHub repo and prints each open item"
scripts/doctor.sh || true
cat <<'TXT'

  GitHub settings, labels, rulesets need a repo admin once: make github-setup (TEMPLATE=1 in the hub).
  The AI backend is optional. With none set, AI workflows skip and people run make ai-* with their own claude login
  (docs/13-ai-backends.md). An agent can walk the rest with you: run claude, then /onboard.
TXT
