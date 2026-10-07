---
applyTo: "AGENTS.md,CLAUDE.md,GEMINI.md,REVIEW.md,.claude/**,.claude-plugin/**,plugins/**,.github/copilot-instructions.md,.github/instructions/**,.github/agents/**,.cursor/**,.gemini/**"
---
# AI configuration rules

- `AGENTS.md` is the single source of truth; tool-specific files only point to it plus tool-specific notes. Never duplicate rules.
- Keep `AGENTS.md` under 200 lines; long material goes to `docs/` and is linked.
- Permissions, hooks and protected paths (`.claude/settings.json`, plugin `hooks/`) are policy: human-authored PR + CODEOWNERS review. Agents must not widen their own permissions.
- Bump plugin versions in `plugin.json` and `marketplace.json` together; validate with `make ai-validate`.
