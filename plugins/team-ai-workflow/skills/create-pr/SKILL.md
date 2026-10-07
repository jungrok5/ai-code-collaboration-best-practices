---
name: create-pr
description: Push the current branch and open a small, well-described pull request that follows the team PR template (conventional title, linked issue, test evidence, AI-assistance disclosure). Use when the user says "open a PR", "create the pull request", "ship this", or after /implement-issue.
---

# Create a pull request

## Preconditions (check, don't assume)

1. Not on a protected branch (`main`, `master`, `develop`, `release/*`).
2. Working tree clean (`git status --porcelain` empty) and all commits are conventional.
3. Fast checks pass: run `make check` if a Makefile target exists, otherwise the lint/test commands in `AGENTS.md`. Paste the summary of results in the PR body.
4. Diff size: `git diff --stat origin/<default>...HEAD`. If > 400 lines (excluding lockfiles and generated files) stop and run `/split-pr` first, unless the user explicitly accepts a large PR (then add label `size/XL` and explain why).

## Steps

1. Rebase or merge the default branch if behind (`git fetch origin && git rebase origin/<default>` on your own branch only).
2. `git push -u origin HEAD` (ask for confirmation if the permission prompt appears, it is intentional).
3. Build the PR body from `.github/pull_request_template.md`. Required sections:
   - **Summary**: what and why (2–5 lines). Link the issue with `Closes #<n>`.
   - **Changes**: bullet list by area.
   - **How it was tested**: exact commands and results; screenshots for UI.
   - **AI assistance**: which parts were AI-generated vs human-written/verified, and which tool.
   - **Checklist**: ticks for size, tests, docs, no secrets, no unrelated refactors.
4. Title = conventional commit style: `<type>(<scope>): <summary>` (≤ 72 chars; CI lints this).
5. Create as **draft** when the checks have not run in CI yet: `gh pr create --draft --title "..." --body-file <tmp> --label ai:assisted`.
   Add labels: `ai:assisted` (always when AI wrote code), the `type/*` and `area/*` labels that match.
6. Request reviewers from CODEOWNERS automatically (GitHub does this); if the change touches auth, payments, infra or data migrations, explicitly mention a human owner in the PR body.
7. Print the PR URL and the one-line next step for the human (e.g. "mark ready for review after CI is green").

## Never

- Never merge, never enable auto-merge, never approve your own PR.
- Never force-push a branch someone else has commits on.
