---
name: new-repo
description: Create a new team repository from this template (gh repo create --template), strip hub-only files, point it at the shared marketplace, apply labels/rulesets/repo settings, and print the remaining manual steps (secrets, app install). Use when the user says "create a new repo from the template", "bootstrap a project repo", or "new service repo".
disable-model-invocation: true
---

# Create a new repository from this template

Arguments: `$ARGUMENTS` = `<owner>/<new-repo-name> [--private|--public] [--mode project|hub]`

Run `scripts/new-repo.sh $ARGUMENTS` and follow its output. What it does, so you can explain it:

1. `gh repo create <owner>/<name> --template <this-template> --private --clone`
2. In the clone: `scripts/bootstrap.sh --mode project` → removes hub-only paths (`plugins/`, `.claude-plugin/`, `docs/10-research-crosscheck.md`), rewrites marketplace/owner placeholders, installs pre-commit, validates config.
3. `scripts/setup-github.sh` → repo settings (squash-only, auto-merge, delete-branch-on-merge, required status checks), label sync from `.github/labels.yml`, ruleset import from `scripts/rulesets/`.
4. Prints the manual checklist: add `ANTHROPIC_API_KEY` (or `CLAUDE_CODE_OAUTH_TOKEN`) secret, install the Claude GitHub App (`/install-github-app`), enable Copilot code review / Dependabot / CodeQL in repo settings, fill CODEOWNERS.

If `gh` is not authenticated, stop and tell the user to run `gh auth login`.
