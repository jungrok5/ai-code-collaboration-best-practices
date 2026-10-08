---
name: fix-ci
description: Find why CI failed for the current branch or a PR and fix the root cause. Use for "CI is red", "fix the failing check", or a run URL.
---

`gh run view <id> --log-failed` for the first real error; reproduce with the same `make` target.
Decide honestly whether this change broke it, the base branch is already red, or it is infrastructure — only the first is yours to fix here; report the others.
Fix the cause with a minimal change and re-run `make check`. Skipping, loosening or re-running tests until green is not a fix.
