---
name: triage-issue
description: Triage a GitHub issue — completeness against the issue template, likely duplicates, labels from .github/labels.yml, and whether an agent can take it. Never closes issues. Use for "triage #12", "is this ready for an agent".
---

Propose `type/*`, `area/*`, `priority/*`, `size/*` from `.github/labels.yml` only, and say what is missing for `ai:ready`
(testable acceptance criteria, bounded scope, no open product decision). Check overlap for the areas it names (`/check-overlap`).
Apply labels or comment only when the user confirms.
