#!/usr/bin/env bash
# Verify that this machine and the GitHub repository are set up the way the docs describe, and say exactly what is left.
#   scripts/doctor.sh [--scope local|github|all] [--json] [--fix-safe] [--repo owner/name]
# Each result: STATUS id message → fix: <command or who must act>. STATUS is PASS, WARN, FAIL, SKIP, MANUAL or INFO.
#   SKIP   = could not check (no gh, offline, or the caller lacks the permission; the line says whom to ask)
#   MANUAL = only a person can do it (approval, purchase, a value only they have); the line says exactly what to do
# --fix-safe runs only idempotent local fixes (git hooks, commit template, plugin install/update). It never touches
# secrets, GitHub settings or protected files. Exit code: 1 if any FAIL, else 0. Works offline (GitHub checks SKIP).
# Check ids are listed in docs/12-setup-checklist.md.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1
# shellcheck source=lib/github.sh
. scripts/lib/github.sh

SCOPE=all; JSON=0; FIX=0; REPO="${GITHUB_REPOSITORY:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --scope) SCOPE="${2:-all}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --fix-safe) FIX=1; shift ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$SCOPE" in local|github|all) ;; *) echo "--scope must be local, github or all" >&2; exit 2 ;; esac
export GH_TIMEOUT="${GH_TIMEOUT:-15}"

results="$(mktemp)"; trap 'rm -f "$results"' EXIT
fails=0
have() { command -v "$1" >/dev/null 2>&1; }
# emit STATUS id message [fix]
emit() {
  local st="$1" id="$2" msg="$3" fix="${4:-}"
  [ "$st" = FAIL ] && fails=$((fails+1))
  printf '%s\t%s\t%s\t%s\n' "$st" "$id" "$msg" "$fix" >> "$results"
  if [ "$JSON" = 0 ]; then
    local c=0; case "$st" in PASS) c=32 ;; WARN|MANUAL) c=33 ;; FAIL) c=31 ;; *) c=90 ;; esac
    if [ -n "$fix" ]; then printf '\033[%sm%-6s\033[0m %s %s → fix: %s\n' "$c" "$st" "$id" "$msg" "$fix"
    else printf '\033[%sm%-6s\033[0m %s %s\n' "$c" "$st" "$id" "$msg"; fi
  fi
}
section() { [ "$JSON" = 0 ] && printf '\n\033[1m== %s\033[0m\n' "$1"; return 0; }

MODE=project; if [ -d plugins ] && [ -f .claude-plugin/marketplace.json ]; then MODE=hub; fi
HUB="$(jq -r '.extraKnownMarketplaces["ai-collab"].source.repo // empty' .claude/settings.json 2>/dev/null)"
PLUGIN_ID="team-ai-workflow@ai-collab"
LOCAL_LLM=0; if [ -n "${ANTHROPIC_BASE_URL:-}" ] && ! grep -q 'api\.anthropic\.com' <<<"$ANTHROPIC_BASE_URL"; then LOCAL_LLM=1; fi

# ------------------------------------------------------------------------------------------------ local
local_checks() {
  section "1. Local tools"
  for t in git jq make python3; do
    if have "$t"; then emit PASS "tools.$t" "$t found"; else emit FAIL "tools.$t" "$t is required" "install $t with your OS package manager"; fi
  done
  if have gh; then emit PASS tools.gh "gh $(gh --version 2>/dev/null | awk 'NR==1{print $3}')"
  else emit WARN tools.gh "gh not found (labels, rulesets, PR helpers, all GitHub checks)" "install from https://cli.github.com"; fi
  if have claude; then emit PASS tools.claude "claude $(claude --version 2>/dev/null | awk '{print $1}')"
  else emit WARN tools.claude "claude CLI not found (plugin, skills, make ai-*)" "npm i -g @anthropic-ai/claude-code"; fi
  for t in pre-commit shellcheck actionlint yamllint; do
    if have "$t"; then emit PASS "tools.$t" "$t found"; else emit WARN "tools.$t" "$t not installed (CI still runs it)" "make setup"; fi
  done

  section "2. Auth"
  if ! have gh; then emit SKIP auth.gh "gh not installed"
  elif gh auth status >/dev/null 2>&1 || [ -n "${GH_TOKEN:-}" ]; then
    local scopes; scopes="$(gh auth status 2>&1 | grep -i 'token scopes' | head -1)"
    if [ -n "$scopes" ] && ! printf '%s' "$scopes" | grep -q workflow; then
      emit WARN auth.gh "gh is logged in without the 'workflow' scope (needed to push workflow changes)" "gh auth refresh -s workflow"
    else emit PASS auth.gh "gh is logged in"; fi
  else emit FAIL auth.gh "gh is not logged in" "gh auth login"; fi
  if ! have claude; then emit SKIP auth.claude "claude not installed"
  elif [ "$LOCAL_LLM" = 1 ] || [ -n "${ANTHROPIC_API_KEY:-}${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    emit PASS auth.claude "claude uses $(bash -c '. scripts/ai/common.sh; ai_backend' 2>/dev/null)"
  elif [ -f "$HOME/.claude/.credentials.json" ] || jq -e '.oauthAccount // empty' "$HOME/.claude.json" >/dev/null 2>&1; then
    emit PASS auth.claude "claude is logged in on this machine"
  else emit WARN auth.claude "no claude login found (needed for make ai-* and the plugin)" "run 'claude' once and log in (macOS keychain logins are not visible here; ignore if claude works)"; fi
  if [ "$LOCAL_LLM" = 1 ] && [ -x scripts/ai/local-llm-check.sh ]; then
    if scripts/ai/local-llm-check.sh >/dev/null 2>&1; then emit PASS auth.local-llm "local LLM at $ANTHROPIC_BASE_URL answers"
    else emit FAIL auth.local-llm "ANTHROPIC_BASE_URL is set but the server does not answer" "make ai-local-check (infra/local-llm/README.md)"; fi
  fi

  section "3. This clone"
  local gd; gd="$(git rev-parse --git-path hooks 2>/dev/null || echo .git/hooks)"
  if [ ! -f .pre-commit-config.yaml ]; then emit SKIP local.hooks "no .pre-commit-config.yaml"
  elif grep -qs pre-commit "$gd/pre-commit" && grep -qs pre-commit "$gd/commit-msg"; then emit PASS local.hooks "pre-commit and commit-msg hooks installed"
  elif [ "$FIX" = 1 ] && have pre-commit && pre-commit install --install-hooks >/dev/null 2>&1 && pre-commit install --hook-type commit-msg >/dev/null 2>&1; then
    emit PASS local.hooks "git hooks installed (fixed)"
  else emit FAIL local.hooks "git hooks are not installed, so secrets and commit format are not checked before commit" "make hooks"; fi
  if [ ! -f .gitmessage.txt ]; then :
  elif [ "$(git config --local commit.template 2>/dev/null)" = .gitmessage.txt ]; then emit PASS local.commit-template "commit template set"
  elif [ "$FIX" = 1 ] && git config --local commit.template .gitmessage.txt; then emit PASS local.commit-template "commit template set (fixed)"
  else emit WARN local.commit-template "commit template not set" "git config --local commit.template .gitmessage.txt"; fi
  if [ -n "$(git config user.email 2>/dev/null)" ]; then emit PASS local.git-identity "git user.email set"
  else emit FAIL local.git-identity "git user.email is not set" "git config --global user.email <you@example.com>"; fi

  local want inst; want="$(jq -r '.plugins[]? | select(.name=="team-ai-workflow") | .version' .claude-plugin/marketplace.json 2>/dev/null)"
  inst="$(jq -r --arg id "$PLUGIN_ID" '.plugins[$id][0].version // empty' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null)"
  if ! have claude; then emit SKIP local.plugin "claude not installed"
  elif [ -z "$inst" ] && [ "$FIX" = 1 ] && [ -n "$HUB" ] && claude plugin marketplace add "$HUB" >/dev/null 2>&1 && claude plugin install "$PLUGIN_ID" >/dev/null 2>&1; then
    emit PASS local.plugin "$PLUGIN_ID installed (fixed)"
  elif [ -z "$inst" ]; then
    emit WARN local.plugin "$PLUGIN_ID is not installed: no guard-rail hooks or team skills in your sessions" "claude plugin marketplace add ${HUB:-<hub>} && claude plugin install $PLUGIN_ID (or rerun with --fix-safe)"
  elif [ -n "$want" ] && [ "$inst" != "$want" ]; then
    if [ "$FIX" = 1 ] && claude plugin update "$PLUGIN_ID" >/dev/null 2>&1; then emit PASS local.plugin "$PLUGIN_ID updated to the latest version (fixed)"
    else emit WARN local.plugin "$PLUGIN_ID $inst installed, marketplace has $want" "claude plugin update $PLUGIN_ID"; fi
  else emit PASS local.plugin "$PLUGIN_ID ${inst} installed"; fi
  # team-ai-workflow depends on ai-design (writing and UI standard). New installs pull it in; older installs may lack it.
  if have claude && [ -n "$inst" ]; then
    if jq -e '.plugins["ai-design@ai-collab"]' "$HOME/.claude/plugins/installed_plugins.json" >/dev/null 2>&1; then
      emit PASS local.ai-design "ai-design installed (writing and UI skills, style check after edits)"
    elif [ "$FIX" = 1 ] && claude plugin install ai-design@ai-collab >/dev/null 2>&1; then emit PASS local.ai-design "ai-design installed (fixed)"
    else emit WARN local.ai-design "ai-design is not installed: no polish-writing/polish-ui skills or style check after edits" "claude plugin install ai-design@ai-collab (or rerun with --fix-safe)"; fi
  fi

  local ph=()
  grep -qsF '<one line>' AGENTS.md && ph+=("AGENTS.md Project section")
  grep -qs 'OWNER/REPO' .github/ISSUE_TEMPLATE/config.yml && ph+=(".github/ISSUE_TEMPLATE/config.yml OWNER/REPO")
  grep -qsE '@OWNER([[:space:]]|$)' .github/CODEOWNERS && ph+=(".github/CODEOWNERS @OWNER (human-owned)")
  [ "$HUB" = OWNER/REPO ] && ph+=(".claude/settings.json marketplace repo (human-owned)")
  if [ "${#ph[@]}" = 0 ]; then emit PASS local.placeholders "no template placeholders left"
  else emit WARN local.placeholders "placeholders left: $(IFS=';'; echo "${ph[*]}")" "ask the agent to fill AGENTS.md (/onboard); a person edits CODEOWNERS and settings.json"; fi
  if [ "$MODE" = project ] && [ -d plugins ]; then emit WARN local.mode "product repo still contains the hub-only plugins/ directory" "scripts/bootstrap.sh --mode project"; fi

  if jq -e '((.permissions.ask // []) | length) > 2 or ((.env // {}) | has("AI_MAX_COMMIT_LINES"))' .claude/settings.json >/dev/null 2>&1; then
    emit MANUAL local.lean-permissions ".claude/settings.json still has the long ask list / AI_MAX_* env (docs/15); agents may not edit their own permissions" "a person runs scripts/apply-lean-permissions.sh, reviews git diff, opens a PR"
  elif [ -f .claude/settings.json ]; then emit PASS local.lean-permissions "lean permissions applied"; fi
}

# ------------------------------------------------------------------------------------------------ github
var_get()    { printf '%s' "$VARS" | jq -r --arg n "$1" '.variables[]? | select(.name==$n) | .value' 2>/dev/null; }
has_secret() { printf '%s' "$SECRETS" | jq -e --arg n "$1" '.secrets[]? | select(.name==$n)' >/dev/null 2>&1; }
ADMIN_HINT="run make doctor with a repo admin's own gh login (not a CI/proxy token), or ask a CODEOWNER to"

github_checks() {
  section "4. GitHub repository (read access)"
  if ! have gh; then emit SKIP gh.repo "gh not installed; GitHub checks skipped" "install gh, then gh auth login"; return; fi
  if ! gh auth status >/dev/null 2>&1 && [ -z "${GH_TOKEN:-}" ]; then emit SKIP gh.repo "gh not logged in; GitHub checks skipped" "gh auth login"; return; fi
  [ -n "$REPO" ] || REPO="$(repo_from_remote)"
  if [ -z "$REPO" ]; then emit SKIP gh.repo "no GitHub origin remote" "pass --repo owner/name"; return; fi
  local info; info="$(apiq "/repos/$REPO" 2>/dev/null)"
  if [ -z "$info" ]; then emit SKIP gh.repo "cannot read $REPO (offline, no access, or it does not exist)" "check the network and gh auth status"; return; fi
  local admin push private def
  admin="$(jq -r '.permissions.admin // false' <<<"$info")"; push="$(jq -r '.permissions.push // false' <<<"$info")"
  private="$(jq -r .private <<<"$info")"; def="$(jq -r .default_branch <<<"$info")"
  local role="read"; [ "$push" = true ] && role="write"; [ "$admin" = true ] && role="admin"
  emit INFO gh.repo "$REPO (mode: $MODE, your access: $role)"

  if [ "$def" = main ]; then emit PASS gh.default-branch "default branch is main"
  else emit WARN gh.default-branch "default branch is $def; rulesets and docs assume main" "admin: gh api -X PATCH repos/$REPO -f default_branch=main"; fi
  if [ "$MODE" = hub ]; then
    if [ "$(jq -r .is_template <<<"$info")" = true ]; then emit PASS gh.template "marked as template repository"
    else emit WARN gh.template "hub is not a template repository, so 'Use this template' and make new-repo fail" "admin: make github-setup TEMPLATE=1"; fi
  fi

  # Rulesets (read access is enough). Profile = REVIEW_PROFILE variable when readable, else inferred from the live ruleset.
  local rs; rs="$(apiq "/repos/$REPO/rulesets" 2>/dev/null)"
  VARS=""; SECRETS=""
  if [ "$push" = true ]; then VARS="$(apiq "/repos/$REPO/actions/variables?per_page=100" 2>/dev/null)"; SECRETS="$(apiq "/repos/$REPO/actions/secrets?per_page=100" 2>/dev/null)"; fi
  local profile; profile="$(var_get REVIEW_PROFILE)"; profile="${profile:-production}"
  if [ -z "$rs" ]; then
    if [ "$private" = true ] && [ "$admin" = true ]; then emit MANUAL gh.rulesets "rulesets are not available on $REPO (private repo on a free plan?)" "an org owner upgrades to GitHub Pro/Team, or makes the repo public; then make github-setup"
    else emit SKIP gh.rulesets "could not read rulesets"; fi
  else
    local f name live id want_n live_n
    for f in scripts/rulesets/main.json scripts/rulesets/feature-branches.json; do
      [ -f "$f" ] || continue
      name="$(jq -r .name "$f")"; id="$(jq -r --arg n "$name" '.[] | select(.name==$n) | .id' <<<"$rs" | head -1)"
      if [ -z "$id" ]; then emit FAIL "gh.ruleset.$(basename "$f" .json)" "ruleset missing: $name" "admin: make github-setup$([ "$profile" = prototype ] && echo ' PROFILE=prototype')"; continue; fi
      live="$(apiq "/repos/$REPO/rulesets/$id" 2>/dev/null)"
      if [ -z "$live" ]; then emit SKIP "gh.ruleset.$(basename "$f" .json)" "cannot read ruleset '$name'"; continue; fi
      if [ "$(jq -r .enforcement <<<"$live")" != "$(jq -r .enforcement "$f")" ]; then
        emit FAIL "gh.ruleset.$(basename "$f" .json)" "ruleset '$name' enforcement is $(jq -r .enforcement <<<"$live")" "admin: make github-setup"; continue; fi
      want_n="$(ruleset_for_profile "$f" "$profile" | jq '[.rules[].type] | sort')"; live_n="$(jq '[.rules[].type] | sort' <<<"$live")"
      if [ "$want_n" != "$live_n" ]; then emit WARN "gh.ruleset.$(basename "$f" .json)" "ruleset '$name' rules differ from $f" "admin: make github-setup$([ "$profile" = prototype ] && echo ' PROFILE=prototype')"
      else emit PASS "gh.ruleset.$(basename "$f" .json)" "ruleset '$name' active"; fi
      if [ "$(basename "$f")" = main.json ]; then
        local appr; appr="$(jq '[.rules[] | select(.type=="pull_request") | .parameters.required_approving_review_count][0] // 0' <<<"$live")"
        if [ "$profile" = prototype ]; then
          emit WARN gh.profile "prototype profile: no human approval on main" "switch when docs/16 §5 applies (real users/data, consumers, on-call, secrets): make github-setup PROFILE=production"
        elif [ "$appr" = 0 ]; then
          emit WARN gh.profile "main needs 0 approvals but the profile is production$([ -z "$VARS" ] && echo ' (REVIEW_PROFILE unreadable)')" "admin: make github-setup"
        else emit PASS gh.profile "production profile: $appr human approval(s) on main"; fi
      fi
    done
  fi

  local live_labels missing=()
  live_labels="$(apiq "/repos/$REPO/labels?per_page=100" --paginate --jq '.[].name' 2>/dev/null)"
  if [ -z "$live_labels" ]; then emit FAIL gh.labels "no labels on $REPO" "make labels (write access) or gh workflow run labels-sync.yml"
  else
    while IFS=$'\t' read -r n _ _; do grep -qxF "$n" <<<"$live_labels" || missing+=("$n"); done < <(labels_yml .github/labels.yml)
    if [ "${#missing[@]}" = 0 ]; then emit PASS gh.labels "all labels from .github/labels.yml exist"
    else emit FAIL gh.labels "${#missing[@]} labels missing (e.g. ${missing[0]}); automation keys on them" "make labels"; fi
    grep -q '^area/' <<<"$live_labels" || grep -q 'name: *"\?area/' .github/labels.yml || emit WARN gh.area-labels "no area/* labels; PR area labelling and triage cannot route work" "ask the agent to propose area/* labels in .github/labels.yml"
  fi

  local wf; wf="$(apiq "/repos/$REPO/actions/workflows?per_page=100" --jq '.workflows[] | select(.state != "active") | "\(.path|split("/")|last) (\(.state))"' 2>/dev/null)"
  if [ -z "$wf" ]; then emit PASS gh.workflows "all workflows enabled"
  else emit FAIL gh.workflows "disabled workflows: $(tr '\n' ' ' <<<"$wf")" "gh workflow enable <file> (write access); new repos from a template may need Actions turned on by an admin"; fi
  local ci; ci="$(apiq "/repos/$REPO/actions/workflows/ci.yml/runs?branch=$def&per_page=1" --jq '.workflow_runs[0].conclusion // "none"' 2>/dev/null)"
  case "$ci" in success) emit PASS gh.ci-main "last ci.yml run on $def succeeded" ;; none|"") emit INFO gh.ci-main "no ci.yml run on $def yet" ;;
    *) emit WARN gh.ci-main "last ci.yml run on $def: $ci" "ask the agent: /fix-ci, or make ai-fix-ci";; esac

  if [ "$MODE" = hub ] && [ -f .github/workflows/work-board.yml ]; then
    local bt; bt="$(apiq "/repos/$REPO/pages" --jq .build_type 2>/dev/null)"
    if [ "$bt" = workflow ]; then emit PASS gh.pages "Pages source is GitHub Actions"
    elif [ -z "$bt" ] && ! apiq "/repos/$REPO" >/dev/null; then emit SKIP gh.pages "cannot read Pages settings"
    elif [ -z "$bt" ] && [ "$admin" = true ] && [ -n "$(apiq "/repos/$REPO" --jq 'select(.has_pages)|1')" ]; then emit SKIP gh.pages "Pages is on but its settings are not readable here (token or proxy)" "$ADMIN_HINT"
    else emit FAIL gh.pages "Pages ${bt:+source is $bt}${bt:-is off}; the work board and guide are not published" "admin: scripts/setup-github.sh pages"; fi
    local owner="${REPO%%/*}" nm="${REPO#*/}" url
    url="https://$(tr '[:upper:]' '[:lower:]' <<<"$owner").github.io/$nm/board.json"
    if have curl && curl -fsS --max-time 8 -o /dev/null "$url" 2>/dev/null; then emit PASS gh.board "board.json is published ($url)"
    else emit WARN gh.board "board.json not reachable at $url" "gh workflow run work-board.yml (write access), after gh.pages passes"; fi
    local r priv=0 bad=()
    while read -r r; do
      [ -z "$r" ] && continue
      local p; p="$(apiq "/repos/$r" --jq .private 2>/dev/null)"
      if [ -z "$p" ]; then bad+=("$r"); elif [ "$p" = true ] && [ "$r" != "$REPO" ]; then priv=1; fi
    done < <(grep -vE '^[[:space:]]*(#|$)' .github/work-board-repos.txt 2>/dev/null)
    if [ "${#bad[@]}" -gt 0 ]; then emit WARN gh.board-repos "cannot read: ${bad[*]}" "fix .github/work-board-repos.txt, or a person adds BOARD_TOKEN"
    else emit PASS gh.board-repos "every repo in .github/work-board-repos.txt is readable"; fi
    if [ "$priv" = 1 ]; then
      if [ -z "$SECRETS" ]; then emit SKIP gh.board-token "private repos on the board; cannot list secrets" "$ADMIN_HINT"
      elif has_secret BOARD_TOKEN; then emit PASS gh.board-token "BOARD_TOKEN present"
      else emit MANUAL gh.board-token "private repos on the board but no BOARD_TOKEN secret" "a person creates a fine-grained PAT (contents:read, pull_requests:read on those repos) and runs: gh secret set BOARD_TOKEN"; fi
    fi
  fi

  section "5. GitHub repository (write / admin)"
  if [ "$push" != true ]; then emit SKIP gh.write "you have read access only; variables, secrets and settings not checked" "$ADMIN_HINT"
  else
    if jq -e 'has("allow_squash_merge")' <<<"$info" >/dev/null; then
      if jq -e '.allow_squash_merge and (.allow_merge_commit|not) and (.allow_rebase_merge|not) and .delete_branch_on_merge and .allow_auto_merge' <<<"$info" >/dev/null; then
        emit PASS gh.merge "squash-only, auto-merge, delete branch on merge"
      else emit FAIL gh.merge "merge settings differ (squash-only, auto-merge, delete-branch expected)" "admin: scripts/setup-github.sh settings"; fi
    else emit SKIP gh.merge "merge settings not visible to you" "$ADMIN_HINT"; fi

    local backend; backend="$(var_get AI_BACKEND)"
    [ -z "$VARS" ] && backend="?unreadable"
    case "$backend" in
      "?unreadable") emit SKIP gh.ai-backend "cannot read Actions variables (token or proxy); AI_BACKEND, DESIGN_BOARD_URL, MAX_OPEN_PRS_PER_AUTHOR not checked" "$ADMIN_HINT" ;;
      "") emit INFO gh.ai-backend "AI_BACKEND unset: AI workflows skip (the default); people run make ai-* from their seat" ;;
      anthropic)
        if [ -z "$SECRETS" ]; then emit SKIP gh.ai-backend "AI_BACKEND=anthropic; cannot list secrets" "$ADMIN_HINT"
        elif has_secret CLAUDE_CODE_OAUTH_TOKEN || has_secret ANTHROPIC_API_KEY; then emit PASS gh.ai-backend "AI_BACKEND=anthropic with a token secret"
        else emit MANUAL gh.ai-backend "AI_BACKEND=anthropic but no CLAUDE_CODE_OAUTH_TOKEN / ANTHROPIC_API_KEY secret" "a person runs: claude setup-token, then gh secret set CLAUDE_CODE_OAUTH_TOKEN (or unset AI_BACKEND)"; fi
        local cr; cr="$(apiq "/repos/$REPO/actions/workflows/claude-code-review.yml/runs?per_page=1" --jq '.workflow_runs[0].conclusion // empty' 2>/dev/null)"
        if [ "$cr" = failure ]; then emit MANUAL gh.claude-app "last Claude Code Review run failed; the Claude GitHub App may not be installed" "an org/repo admin installs https://github.com/apps/claude for $REPO (or /install-github-app in claude)"; fi ;;
      local)
        local miss=(); [ -n "$(var_get AI_BASE_URL)" ] || miss+=(AI_BASE_URL); [ -n "$(var_get AI_MODEL)" ] || miss+=(AI_MODEL)
        if [ "${#miss[@]}" = 0 ]; then emit PASS gh.ai-backend "AI_BACKEND=local with AI_BASE_URL and AI_MODEL"
        else emit FAIL gh.ai-backend "AI_BACKEND=local but ${miss[*]} unset" "gh variable set ${miss[0]} -b <value> (infra/local-llm/README.md)"; fi
        if [ "$admin" = true ]; then
          if apiq "/repos/$REPO/actions/runners" --jq '.runners[] | select(.status=="online") | .labels[].name' 2>/dev/null | grep -qx ai; then emit PASS gh.runner "online self-hosted runner with label 'ai'"
          else emit MANUAL gh.runner "no online self-hosted runner labelled 'ai'" "the server owner registers a runner with labels self-hosted,ai (infra/local-llm/README.md §3)"; fi
        else emit SKIP gh.runner "runner list needs admin" "$ADMIN_HINT"; fi
        [ "$private" = false ] && emit WARN gh.runner-public "public repo with a self-hosted runner" "use a disposable, isolated runner (infra/local-llm/README.md §3)" ;;
      *) emit FAIL gh.ai-backend "AI_BACKEND='$backend' is not local or anthropic" "gh variable set AI_BACKEND -b local|anthropic, or gh variable delete AI_BACKEND" ;;
    esac
    local m; m="$(var_get MAX_OPEN_PRS_PER_AUTHOR)"
    if [ -n "$m" ] && ! [[ "$m" =~ ^[0-9]+$ ]]; then emit FAIL gh.max-open-prs "MAX_OPEN_PRS_PER_AUTHOR='$m' is not a number" "gh variable set MAX_OPEN_PRS_PER_AUTHOR -b 3"; fi
    if [ "$MODE" = project ] && [ -n "$VARS" ]; then
      local bu; bu="$(var_get DESIGN_BOARD_URL)"
      if [ -z "$bu" ]; then emit WARN gh.design-board-url "DESIGN_BOARD_URL unset: overlap checks only see this repo" "gh variable set DESIGN_BOARD_URL -b https://<hub-owner>.github.io/<hub>/board.json, and add $REPO to the hub's .github/work-board-repos.txt"
      elif have curl && ! curl -fsS --max-time 8 -o /dev/null "$bu" 2>/dev/null; then emit WARN gh.design-board-url "DESIGN_BOARD_URL not reachable: $bu" "check the hub's Pages (make doctor in the hub)"
      else emit PASS gh.design-board-url "DESIGN_BOARD_URL set"; fi
    fi
    if [ -n "$SECRETS" ]; then
      local opt=(); for s in RELEASE_PLEASE_TOKEN REPO_ADMIN_TOKEN; do has_secret "$s" || opt+=("$s"); done
      [ "${#opt[@]}" -gt 0 ] && emit INFO gh.optional-secrets "optional secrets not set: ${opt[*]} (release tags trigger no workflows; bootstrap-repo.yml uses GITHUB_TOKEN)"
    fi
    if [ -f .github/workflows/codeql.yml ]; then
      local ds; ds="$(apiq "/repos/$REPO/code-scanning/default-setup" --jq .state 2>/dev/null)"
      [ "$ds" = configured ] && emit WARN gh.codeql "CodeQL default setup and codeql.yml both run" "keep one: delete codeql.yml, or turn default setup off (Settings → Advanced Security)"
    fi

    if [ "$admin" != true ]; then emit SKIP gh.admin "Actions permissions and secret scanning need admin" "$ADMIN_HINT"
    else
      local en wp; en="$(apiq "/repos/$REPO/actions/permissions" --jq .enabled)"
      case "$en" in false) emit FAIL gh.actions "GitHub Actions is disabled" "gh api -X PUT repos/$REPO/actions/permissions -F enabled=true" ;;
        true) emit PASS gh.actions "GitHub Actions enabled" ;; *) emit SKIP gh.actions "cannot read Actions permissions (token or proxy)" "$ADMIN_HINT" ;; esac
      wp="$(apiq "/repos/$REPO/actions/permissions/workflow" --jq '.default_workflow_permissions=="read" and .can_approve_pull_request_reviews')"
      if [ -z "$wp" ]; then emit SKIP gh.actions-token "cannot read workflow token permissions (token or proxy)" "$ADMIN_HINT"
      elif [ "$wp" = true ]; then
        emit PASS gh.actions-token "workflow token read-only and may create/approve PRs"
      else emit FAIL gh.actions-token "workflow token permissions differ (release-please and Dependabot auto-merge fail)" "scripts/setup-github.sh settings (org policy may block it: ask an org owner)"; fi
      local ss; ss="$(jq -r '.security_and_analysis.secret_scanning_push_protection.status // empty' <<<"$info")"
      if ! jq -e 'has("security_and_analysis") and .security_and_analysis != null' <<<"$info" >/dev/null; then emit SKIP gh.secret-scanning "security settings not visible to this token" "$ADMIN_HINT"
      elif [ "$ss" = enabled ]; then emit PASS gh.secret-scanning "secret scanning push protection on"
      elif [ "$private" = true ]; then emit MANUAL gh.secret-scanning "push protection off on a private repo" "needs GitHub Secret Protection (an org owner buys/enables it), then scripts/setup-github.sh settings"
      else emit FAIL gh.secret-scanning "push protection off" "scripts/setup-github.sh settings"; fi
    fi
  fi
}

# ------------------------------------------------------------------------------------------------ stack fit
stack_checks() {
  section "6. Stack fit"
  local st; st="$(scripts/stack.sh detect 2>/dev/null)"
  if [ -z "$st" ] || [ "$st" = none ]; then emit INFO stack.detect "no project manifest yet (package.json, pyproject.toml, go.mod, Cargo.toml)"; return; fi
  emit INFO stack.detect "stack: $st"
  local lang; case "$st" in node) lang=javascript-typescript ;; python) lang=python ;; go) lang=go ;; rust) lang=rust ;; esac
  if [ -f .github/workflows/codeql.yml ] && ! grep -qE "^[[:space:]]*-[^#]*language: *$lang" .github/workflows/codeql.yml; then
    emit WARN stack.codeql "codeql.yml does not scan $lang" "ask the agent to add $lang to the codeql.yml matrix"; fi
  if [ "$(jq -r '."release-type" // empty' release-please-config.json 2>/dev/null)" = simple ] && [ "$st" != rust ]; then
    emit WARN stack.release-type "release-please-config.json release-type is 'simple' for a $st project" "ask the agent to set release-type: $st"; fi
  if git ls-files '*.proto' | grep -q . && [ ! -f buf.yaml ]; then emit WARN stack.buf "*.proto files without buf.yaml: breaking changes are not detected" "add buf.yaml (docs/16 §2)"; fi
}

[ "$SCOPE" != github ] && local_checks
[ "$SCOPE" != local ] && github_checks
[ "$SCOPE" != github ] && stack_checks

if [ "$JSON" = 1 ]; then
  jq -Rn '[inputs | split("\t") | {status: .[0], id: .[1], message: .[2], fix: (.[3] // "")}]
          | {ok: (map(select(.status=="FAIL")) | length == 0), counts: (group_by(.status) | map({(.[0].status): length}) | add // {}), results: .}' < "$results"
else
  echo
  for s in FAIL WARN MANUAL SKIP PASS; do printf '%s=%s ' "$s" "$(grep -c "^$s"$'\t' "$results")"; done; echo
  [ "$fails" -gt 0 ] && echo "Fix the FAIL lines (or ask the agent: /onboard). MANUAL lines need a person; the fix text says who and what."
fi
[ "$fails" = 0 ]
