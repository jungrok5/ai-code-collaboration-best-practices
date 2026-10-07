# Team entry points. AI agents and CI call exactly these targets (see AGENTS.md §2).
SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help setup setup-ci lint typecheck test build check ai-validate labels github-setup new-repo hooks

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

check: lint typecheck test ## Full fast check — run before every commit

ai-validate: ## Validate AI/automation config (plugin manifests, settings schema, workflows, hooks)
	@scripts/check-ai-config.sh

hooks: ## (Re)install git hooks via pre-commit
	@pre-commit install --install-hooks && pre-commit install --hook-type commit-msg

labels: ## Sync GitHub labels from .github/labels.yml (needs gh auth)
	@scripts/setup-github.sh labels

github-setup: ## Apply repo settings, labels and rulesets to the current GitHub repo (needs gh auth, admin)
	@scripts/setup-github.sh all

new-repo: ## Create a new repo from this template: make new-repo REPO=owner/name [VISIBILITY=private]
	@scripts/new-repo.sh "$(REPO)" --$(or $(VISIBILITY),private)
