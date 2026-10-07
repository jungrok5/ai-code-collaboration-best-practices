---
name: validate-ai-config
description: Validate every AI/automation config in this repository - Claude plugin & marketplace manifests, settings.json against its JSON schema, skills/agents frontmatter, GitHub workflow YAML (actionlint), shell hooks (shellcheck), YAML (yamllint) and Markdown links - and report what to fix. Use before committing changes to .claude/, plugins/, or .github/.
---

# Validate AI configuration

Run `make ai-validate` (wrapper around `scripts/check-ai-config.sh`). If `make` is unavailable, run the script directly.

Interpret the output:

- `claude plugin validate --strict` warnings are errors for this repo (unknown frontmatter fields, missing descriptions).
- `actionlint` findings about `${{ github.event.* }}` inside `run:` are security issues (script injection) - fix by moving the value into `env:`.
- `check-jsonschema` errors on `.claude/settings.json` usually mean a misspelt permission rule (`Bash(cmd *)` syntax) or an unknown key.

Fix, re-run until clean, then summarise what changed. Do not disable a check to make it pass.
