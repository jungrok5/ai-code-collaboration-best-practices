---
name: split-pr
description: Turn an oversized change into a stack of small, independently reviewable PRs with a dependency order and a per-PR test plan. Use when a diff exceeds ~400 lines, when a reviewer asks to split, or when the user says "split this PR".
---

# Split a large change into a PR stack

1. Measure: `git diff --stat origin/<default>...HEAD` and list the changed files grouped by area. Exclude lockfiles/generated files from the count.
2. Propose a stack in dependency order. Typical slices (use the ones that apply):
   1. refactor/prep with no behaviour change (pure moves, renames, extractions)
   2. interfaces/types/schema + their unit tests
   3. core implementation behind a feature flag (default off)
   4. wiring/integration + integration tests
   5. docs, flag flip, cleanup
3. For each PR give: title (conventional), files, ~line count, test plan, and what reviewers should focus on. Target ≤ 300 lines each.
4. Only after the user agrees, create the branches: use `git worktree add` or interactive `git add -p` to carve the first slice; never rewrite history on a branch others have pulled.
5. Open PRs in order; each later PR targets the previous PR's branch (stacked) or waits for merge (sequential), per the user's choice. Label them `stack/1-of-N` … in the body.
