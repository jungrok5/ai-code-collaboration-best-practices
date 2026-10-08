---
name: design
description: Write a one-page design doc with a Mermaid structure diagram for work that is ambiguous, spans several areas or repos, changes an interface, or will take more than a day — check it against the team board for overlap, and open it as its own small PR for human approval before any code is written. Use when the user asks to design, plan, propose, kick off or "get started on" work whose scope is still undecided or that spans several services, teams or repos, or when /implement-issue finds the issue too vague.
---

# Design before building

Goal: a reviewer understands the whole change in five minutes, and nobody else on the team is already doing it.

Output: `docs/designs/NNNN-slug.md` following `docs/designs/TEMPLATE.md` (front matter + problem, Mermaid diagram of before/after, design, alternatives, PR-sized work split, verification, open questions), opened as a PR titled `docs(design): <title>`.

What matters:

- Read the relevant code first; the diagram shows the real components and data flow, not generic boxes.
- `areas` in the front matter is what the overlap check matches — list the path globs and named areas (`api:/x`, `db:table`, `ui:screen`) the work will touch, across every repo in `repos`.
- Run `python3 scripts/designs/board.py overlap --design <file>` (set `DESIGN_BOARD` to the hub's board.json for cross-repo). If it reports overlap, stop and tell the user who owns it — joining their design or splitting the area beats a parallel one.
- Keep it to one page. Unknowns go under "open questions"; approval waits until they are answered.
- Status stays `draft` in the PR. Merging the PR is the human approval; the author then flips it to `approved`, and to `in-progress`/`done` as work proceeds. Each line of the work split becomes an issue that links the design.
- Do not write implementation code in this step.
