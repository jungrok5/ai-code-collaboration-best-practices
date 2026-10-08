---
paths:
  - ".github/workflows/**"
---

# GitHub Actions changes

Workflows here run with repository secrets, so the usual hardening matters: top-level `permissions:` at the minimum and widened per job,
third-party actions pinned to a commit SHA (`scripts/pin-actions.sh`; Dependabot keeps them current), untrusted event text
(issue/PR titles and bodies, comments, branch names) passed through `env:` rather than inlined in `run:`, and no `pull_request_target`
job that checks out PR code. Give PR-triggered jobs `concurrency` and every job `timeout-minutes`. `make ai-validate` runs actionlint.
