---
name: onboard
description: Walk a new team member (or a fresh agent session) through this repository's AI collaboration workflow - rules file hierarchy, branch/PR policy, labels, automations, and the commands to run on day one. Use when the user says "onboard me", "how does this repo work", "explain the workflow", or on first session in a repo created from the template.
---

# Onboarding tour

Give a concise, repo-specific tour (read the actual files, do not recite generic advice):

1. **Rules**: `AGENTS.md` (source of truth) → `CLAUDE.md` / `.github/copilot-instructions.md` / `.cursor/rules` / `GEMINI.md` are thin wrappers. Path rules in `.claude/rules/`.
2. **Day-one commands**: `make setup` (or `scripts/bootstrap.sh`), `make check`, `make ai-validate`.
3. **Workflow**: issue (template + `ai:ready` label) → branch `<type>/<issue>-<slug>` → small PR (≤ 400 lines) → CI + AI review (advisory) → human review (CODEOWNERS) → squash merge → release-please.
4. **Automations** in `.github/workflows/`: list each file and its trigger in one line.
5. **Guard rails**: protected paths, git rules, permissions in `.claude/settings.json`; what will be blocked and why.
6. **Where to ask**: `docs/01-playbook.md`, `SUPPORT.md`, CODEOWNERS.

Finish with three concrete next actions for the user.
