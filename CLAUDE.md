# CLAUDE.md — Claude Code entry point

@AGENTS.md

## Claude Code specifics for this repository

- **Team policy** (permissions, hooks, plugin, attribution) is `.claude/settings.json`. Personal overrides go in
  `.claude/settings.local.json` (git-ignored). Never edit the team file in an agent session; propose a PR.
- **Skills** (from the `team-ai-workflow` plugin): `/implement-issue`, `/create-pr`, `/review-pr`, `/fix-ci`,
  `/split-pr`, `/triage-issue`, `/write-adr`, `/onboard`. Repository-level: `/new-repo`, `/validate-ai-config`.
- **Subagents:** `code-reviewer`, `security-reviewer`, `test-writer`, `issue-triager`, `docs-writer`.
  Delegate reviews and long investigations to them to keep the main context small.
- **Path rules** in `.claude/rules/*.md` load automatically when you touch matching files.
- **Guard-rail hooks** will block edits to protected paths, commits on protected branches, force-pushes, and
  oversized staged diffs. That is intentional: stop and ask the user instead of working around it.
- **Workflow hints:** use plan mode (`Shift+Tab` or `--permission-mode plan`) for non-trivial tasks; `/clear`
  between unrelated tasks; `claude --worktree <name>` for parallel sessions so checkouts never collide.
- **GitHub access:** prefer the `gh` CLI (read commands are pre-approved; write commands prompt). The GitHub MCP
  server in `.mcp.json` is optional and needs `GITHUB_PERSONAL_ACCESS_TOKEN`.
