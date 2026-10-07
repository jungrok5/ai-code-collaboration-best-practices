# Copilot instructions

Read and follow `AGENTS.md` at the repository root. It is the single source of truth for commands,
workflow, coding/testing/git rules, protected paths and agent behaviour. Do not duplicate it here.

## Copilot-specific notes

- Path-scoped rules live in `.github/instructions/*.instructions.md`; review standards in `REVIEW.md`.
- Reusable procedures are Agent Skills in `.claude/skills/` and `plugins/team-ai-workflow/skills/`
  (Copilot reads `SKILL.md` files from `.claude/skills/` and `.github/skills/`).
- Cloud agent: only work on issues labelled `ai:ready`; open PRs as **draft**; title in Conventional
  Commit form; body must follow `.github/pull_request_template.md` incl. the AI disclosure section.
- Run `make check` before finishing; paste the result in the PR body. Never skip or disable tests.
- Use `.github/workflows/copilot-setup-steps.yml` to see what is pre-installed in your environment.
