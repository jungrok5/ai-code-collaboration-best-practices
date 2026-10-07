---
paths:
  - "AGENTS.md"
  - "CLAUDE.md"
  - ".claude/**"
  - ".claude-plugin/**"
  - "plugins/**"
  - ".github/copilot-instructions.md"
  - ".github/instructions/**"
  - ".cursor/**"
  - "GEMINI.md"
---

# Rules for AI configuration files

- `AGENTS.md` is the single source of truth. Tool-specific files (`CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/rules/*.mdc`, `GEMINI.md`) only import/point to it plus tool-specific notes; never duplicate rules.
- Keep `AGENTS.md` under 200 lines; move long material to `docs/` and link it.
- Changing permissions, hooks, or protected paths (`.claude/settings.json`, plugin `hooks/`) is a policy change: it needs a human-authored PR and a CODEOWNERS review. Agents must not widen their own permissions.
- Skills and subagents must have a `name` and a specific `description` that says *when* to use them. Validate with `claude plugin validate --strict` (`make ai-validate`).
- Bump plugin versions (`plugin.json` and `marketplace.json`) together when plugin content changes.
