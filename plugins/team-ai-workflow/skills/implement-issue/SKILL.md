---
name: implement-issue
description: Implement a GitHub issue end-to-end on a new branch (read issue → plan → tests → code → verify → commit), stopping before push/PR for a human checkpoint. Use when the user says "implement issue #123", "work on #45", "take this ticket", or pastes an issue URL.
---

# Implement a GitHub issue

Arguments: `$ARGUMENTS` = issue number or URL (e.g. `123` or `https://github.com/org/repo/issues/123`).

## 0. Rules that always apply

- Follow `AGENTS.md` (single source of truth). If a rule here conflicts with it, `AGENTS.md` wins.
- Scope = the issue's **Acceptance Criteria**, nothing more. No drive-by refactors; note ideas in the PR body instead.
- Keep the change small (target ≤ 400 changed lines). If it cannot be small, stop and use `/split-pr` to propose a stack.

## 1. Read and restate the issue

1. `gh issue view $ARGUMENTS --comments` (read the body AND the comments, later comments can change scope).
2. Restate in 3–6 bullets: goal, acceptance criteria, impacted areas, out-of-scope, open questions.
3. If an acceptance criterion is ambiguous or missing, ask the user **before** coding (one message with all questions).

## 2. Branch

- Determine default branch: `git symbolic-ref --short refs/remotes/origin/HEAD` (fallback `main`).
- `git fetch origin && git switch -c <type>/<issue>-<slug> origin/<default>` where `<type>` ∈ feat|fix|chore|docs|refactor|test|ci|perf and `<slug>` is 2–5 kebab-case words from the title.

## 3. Plan before code

- Explore the relevant code first (read, grep). Identify existing patterns to copy rather than inventing new ones.
- Write a short plan (files to touch, tests to add). For non-trivial work use plan mode or ask the user to confirm the plan.

## 4. Tests first, then implementation

- Add or update tests that encode the acceptance criteria. Run them and confirm they fail for the right reason.
- Implement the minimal change. Re-run the tests plus the project's full fast check (`make check` if present, else the commands in `AGENTS.md`).

## 5. Verify like a reviewer

- Run `/review-pr` style self-check: correctness, edge cases, error handling, security, docs.
- Confirm no protected files were touched (lockfiles only via the package manager; never `.env`/secrets).

## 6. Commit (small, conventional)

- One logical change per commit: `<type>(<scope>): <summary> (#<issue>)`, body explains **why**.
- Keep the attribution trailer that Claude Code adds (team policy for AI-assisted audit trail).

## 7. Hand-off (do NOT push or open a PR unless the user asked)

Report: what changed, how it was verified (exact commands + results), what was intentionally not done, and the next step (`/create-pr`).
