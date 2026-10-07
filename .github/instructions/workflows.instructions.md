---
applyTo: ".github/workflows/**"
---
# GitHub Actions rules

- Every workflow declares top-level `permissions:` with the minimum scopes; widen only per job.
- Pin third-party actions to a full commit SHA with a `# vX.Y.Z` comment; Dependabot updates them.
- Never interpolate untrusted event text (`github.event.issue.body`, comment bodies, PR titles, branch names) inside `run:`; pass it through `env:` and quote it.
- Never use `pull_request_target` with a checkout of PR code. Agent workflows must not expose secrets to fork PRs.
- Add `concurrency` with `cancel-in-progress: true` for PR-triggered jobs and `timeout-minutes` on every job.
- Validate with `make ai-validate` (actionlint, zizmor) before committing.
