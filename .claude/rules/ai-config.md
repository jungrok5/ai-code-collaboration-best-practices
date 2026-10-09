---
paths:
  - "AGENTS.md"
  - "CLAUDE.md"
  - ".claude/**"
  - "plugins/**"
  - ".github/copilot-instructions.md"
  - ".github/instructions/**"
  - ".cursor/**"
  - "GEMINI.md"
---

# AI configuration

`AGENTS.md` is the single source; tool files point to it. Before adding a line, ask whether an agent would get it wrong without it.
Newer models follow instructions closely, so redundant or emphatic rules cost tokens and cause over-triggering (see `docs/15-lean-harness.md`).
Permissions and hooks are team policy: change them in a human-reviewed PR. Bump `plugin.json` and `marketplace.json` versions together.
