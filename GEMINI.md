# GEMINI.md — Gemini CLI notes

`.gemini/settings.json` makes Gemini CLI load `AGENTS.md` (the single source of truth) together with this file.
Do not duplicate rules here.

Gemini-specific:

- Run `make check` before finishing; paste the result in the PR body.
- Never edit protected paths (`.env*`, lockfiles, `.github/CODEOWNERS`, `scripts/rulesets/`, `.claude/settings.json`).
- Gemini Code Assist PR review (enterprise) is configured in `.gemini/config.yaml` and `.gemini/styleguide.md`.
