# Team entry points. AI agents and CI call exactly these targets (see AGENTS.md §2).
SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: new-skill style ai-eval designs overlap help setup setup-ci lint typecheck test build check ai-validate labels github-setup new-repo hooks ai-check ai-triage ai-review ai-implement ai-fix-ci ai-respond ai-maintenance ai-queue ai-local-check

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## One-time setup after clone (deps, pre-commit, Claude plugin, validation)
	@scripts/bootstrap.sh

setup-ci: ## Install project dependencies only (used by CI and agent workflows)
	@scripts/stack.sh setup

lint: ## Lint + format check (auto-detects stack)
	@scripts/stack.sh lint

typecheck: ## Type check (auto-detects stack)
	@scripts/stack.sh typecheck

test: ## Unit tests (auto-detects stack)
	@scripts/stack.sh test

build: ## Build (auto-detects stack)
	@scripts/stack.sh build

check: lint style typecheck test ## Full fast check — run before every commit

STYLE_CHECK ?= $(firstword $(wildcard plugins/team-ai-workflow/style/style_check.py) $(wildcard $(HOME)/.claude/plugins/*/team-ai-workflow/style/style_check.py))
style: ## Writing + UI style check (AI tone / AI look; docs/17). FILES="a.md b.tsx" to limit
	@if [ -z "$(STYLE_CHECK)" ]; then echo "style: team-ai-workflow plugin not found, skipped"; \
	else python3 "$(STYLE_CHECK)" $(or $(FILES),$$(git ls-files '*.md' '*.mdx' '*.html' '*.css' '*.scss' '*.tsx' '*.jsx' '*.vue' '*.svelte' '*.astro' | grep -v '^docs/site/index.html$$' | grep -v '/evals/')); fi

doctor: ## What is set up and what is left (tools, auth, plugin, GitHub settings). SCOPE=local|github JSON=1 FIX=1
	@scripts/doctor.sh --scope $(or $(SCOPE),all) $(if $(JSON),--json) $(if $(FIX),--fix-safe)

ai-validate: ## Validate AI/automation config (plugin manifests, settings schema, workflows, hooks)
	@scripts/check-ai-config.sh

hooks: ## (Re)install git hooks via pre-commit
	@pre-commit install --install-hooks && pre-commit install --hook-type commit-msg

labels: ## Sync GitHub labels from .github/labels.yml (needs gh auth)
	@scripts/setup-github.sh labels

github-setup: ## Apply repo settings, labels, rulesets (+Pages in the hub; needs admin). PROFILE=prototype drops approval gates, TEMPLATE=1 marks the hub as template
	@PROFILE="$(or $(PROFILE),production)" scripts/setup-github.sh all

new-repo: ## Create a new repo from this template: make new-repo REPO=owner/name [VISIBILITY=private]
	@scripts/new-repo.sh "$(REPO)" --$(or $(VISIBILITY),private)

# ---- Key-free AI tasks: run at your own seat with your claude.ai login (no API key), or point at a local LLM
# ---- via ANTHROPIC_BASE_URL (infra/local-llm/). Add POST=1 to publish results to GitHub; default is a dry run.
POSTFLAG := $(if $(POST),--post,)

ai-check: ## Show which AI backend `claude` would use (login / local LLM / key)
	@bash -c '. scripts/ai/common.sh; echo "backend: $$(ai_backend)"; command -v claude >/dev/null && claude --version || echo "claude CLI not installed: npm i -g @anthropic-ai/claude-code"'

ai-triage: ## Triage an issue: make ai-triage ISSUE=12 [POST=1]
	@scripts/ai/triage.sh "$(ISSUE)" $(POSTFLAG)

ai-review: ## Review a PR (advisory, never approves): make ai-review PR=34 [POST=1]
	@scripts/ai/review.sh "$(PR)" $(POSTFLAG)

ai-implement: ## Implement an issue in an isolated worktree: make ai-implement ISSUE=12 [POST=1 → draft PR]
	@scripts/ai/implement.sh "$(ISSUE)" $(POSTFLAG)

ai-fix-ci: ## Diagnose/fix the failing CI run of a PR: make ai-fix-ci PR=34 [POST=1]
	@scripts/ai/fix-ci.sh "$(PR)" $(POSTFLAG)

ai-respond: ## Answer a question on an issue/PR: make ai-respond NUM=12 TEXT="..." [POST=1]
	@scripts/ai/respond.sh "$(NUM)" --text "$(TEXT)" $(POSTFLAG)

ai-maintenance: ## Weekly maintenance report: make ai-maintenance [POST=1 → creates an issue]
	@scripts/ai/maintenance.sh $(POSTFLAG)

ai-queue: ## Implement every ai:ready issue from this seat: make ai-queue [POST=1] [LIMIT=5]
	@scripts/ai/queue.sh $(POSTFLAG) --limit $(or $(LIMIT),5)

ai-local-check: ## Verify a local LLM endpoint (ANTHROPIC_BASE_URL) speaks the Anthropic Messages API
	@scripts/ai/local-llm-check.sh

new-skill: ## Scaffold a skill: make new-skill NAME=my-skill TIER=personal|community|team DESC="what + when"
	@scripts/new-skill.sh "$(NAME)" "$(TIER)" "$(DESC)"

ai-eval: ## Run the team plugin's skill evals with your own claude login (no API key). CASE=<glob> to filter
	@claude plugin eval plugins/team-ai-workflow --trust-plugin --no-publish --runs $(or $(RUNS),1) --threshold $(or $(THRESHOLD),0.67) $(if $(CASE),--case "$(CASE)")

# ---- Design-first and overlap (deterministic, no LLM) ----
designs: ## Rebuild docs/designs/INDEX.md and board.json from design front matter
	@python3 scripts/designs/board.py index

overlap: ## Who else is working here? make overlap AREAS="src/auth/** api:/login"  (or DIFF=origin/main)
	@if [ -n "$(DIFF)" ]; then python3 scripts/designs/board.py overlap --diff "$(DIFF)"; else python3 scripts/designs/board.py overlap $(AREAS); fi
