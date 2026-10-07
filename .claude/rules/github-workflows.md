---
paths:
  - ".github/workflows/**"
  - ".github/actions/**"
---

# Rules for GitHub Actions changes

- Every workflow declares top-level `permissions:` with the minimum scopes; jobs widen only what they need.
- Third-party actions are pinned to a full commit SHA with a version comment (`uses: owner/action@<sha> # vX.Y.Z`). Dependabot keeps them fresh. First-party `actions/*` may use a major tag.
- Never interpolate untrusted event text (`github.event.issue.body`, comment bodies, PR titles, branch names) directly inside `run:` scripts; pass it through `env:` and quote it.
- Do not use `pull_request_target` with a checkout of the PR head. AI-agent workflows that run on PRs must not expose secrets to forks.
- Add `concurrency` with `cancel-in-progress: true` for PR-triggered jobs and `timeout-minutes` on every job.
- Run `actionlint` locally (`make ai-validate`) before committing a workflow change.
