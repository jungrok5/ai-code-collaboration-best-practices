---
name: check-overlap
description: Before starting work, check whether teammates already have an active design or an open PR touching the same files or areas, in this repo or across the team's repos. Use at the start of any non-trivial task, when the user asks "is anyone working on this", or before writing a design.
---

# Check for overlapping work

Run `python3 scripts/designs/board.py overlap <paths, globs or named areas you expect to touch>` (or `--diff origin/main` for work already started). Set `DESIGN_BOARD` to the hub's `board.json` (see `docs/14-design-first-and-overlap.md`) to include other repos and every open PR.

Report the result in two lines: either "no overlap", or for each hit the owner, the design or PR link, and the shared area, followed by a concrete suggestion (talk to the owner, join their design, split the area, or sequence the work). Do not start the overlapping part yourself.
