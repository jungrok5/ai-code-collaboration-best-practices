# CLAUDE.md

@AGENTS.md

## Claude Code notes

- Team settings: `.claude/settings.json` (human-owned). Personal overrides: `.claude/settings.local.json` (git-ignored).
- Plugin `team-ai-workflow` adds skills (`/design`, `/check-overlap`, `/implement-issue`, `/create-pr`, `/review-pr`, `/fix-ci`, …),
  review subagents, and hooks that block edits to secrets and policy files, commits on `main`, and force-pushes to shared branches.
  If a hook blocks you, tell the user what you were trying to do instead of working around it.
- The session-start hook lists active designs and who owns which area; check it before starting non-trivial work.
- For parallel sessions use `claude --worktree <name>` so checkouts don't collide.
