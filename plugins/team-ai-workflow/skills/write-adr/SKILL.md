---
name: write-adr
description: Write an Architecture Decision Record in docs/adr using the team template (context, options, decision, consequences). Use when the user says "write an ADR", "document this decision", "record why we chose X", or when a change alters architecture, a public API, data model, or a dependency.
---

# Write an ADR

Input: `$ARGUMENTS` = short decision title (e.g. "use pnpm workspaces").

1. Number: next sequential id from `ls docs/adr` (format `NNNN-kebab-title.md`; start at `0001`).
2. Copy the structure from `docs/adr/0000-template.md`.
3. Fill every section concretely:
   - **Context**: the problem, constraints, who is affected, links to issue/PR.
   - **Options considered**: ≥ 2 options with pros/cons (one line each), including "do nothing".
   - **Decision**: one paragraph in the active voice ("We will …").
   - **Consequences**: positive, negative, follow-ups (as issues), how to revisit.
   - **Status**: Proposed → Accepted/Rejected/Superseded (link).
4. Keep it under ~80 lines. Facts over adjectives. Add the ADR link to the PR body and, if the decision changes team rules, update `AGENTS.md` in the same PR.
