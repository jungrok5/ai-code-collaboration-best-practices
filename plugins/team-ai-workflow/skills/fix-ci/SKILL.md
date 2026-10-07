---
name: fix-ci
description: Diagnose a failing GitHub Actions run for the current PR/branch, reproduce locally, fix the root cause (never skip or disable tests), and re-verify. Use when the user says "CI is red", "fix the failing check", "why did the build fail", or pastes a run URL.
---

# Fix a failing CI run

Input: `$ARGUMENTS` = run id / run URL / PR number, or empty for the current branch.

## 1. Find the failure

- `gh run list --branch "$(git branch --show-current)" --limit 5` → pick the failed run.
- `gh run view <run-id> --log-failed` (read the first error, not the last line; collect the failing job, step and test names).
- `gh pr checks <pr>` to see all required checks.

## 2. Classify (be honest)

| Class | Signal | Action |
| --- | --- | --- |
| Your change broke it | failing test/lint touches files in this diff | fix the code (root cause) |
| Pre-existing / base branch red | same failure on the default branch | report; do not paper over |
| Environment/infra | checkout, install, runner loss, network | re-run once (`gh run rerun <id> --failed`) only if the user agrees; if it fails again it is real |
| Flaky test | passes locally and on re-run | make the test deterministic; never add `skip`/`retry` without a comment and an issue |

## 3. Reproduce locally

Run the exact command from the workflow step (see `.github/workflows/ci.yml`), e.g. `make check`, `npm test -- <name>`, `pytest <path>::<test>`.

## 4. Fix the root cause

- Minimal change; no unrelated refactors. Update the test only if the test itself was wrong (explain in the commit body).
- Never: delete/skip/quarantine tests, loosen lint rules, add `|| true`, bump timeouts without a reason, or push an empty commit to re-trigger CI.

## 5. Verify and commit

- Re-run the same command locally and the full fast check. Commit as `fix(ci): <what> (#<issue>)` or `fix(<scope>): ...`.
- Report: root cause, fix, evidence (commands + output), and anything you could not reproduce.
