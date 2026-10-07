# REVIEW.md — review standard for humans and AI reviewers

Read by Copilot code review and Claude Code Review in addition to `AGENTS.md`. Keep it short.

## What to flag (in priority order)

1. **Correctness**: logic errors, off-by-one, null/undefined, races, error handling, resource cleanup. Trace a concrete input path before flagging.
2. **Security**: injection (SQL/command/template), missing authn/authz, secrets in code or logs, SSRF, path traversal, unsafe deserialisation, risky new dependencies, GitHub Actions hardening (`pull_request_target`, unpinned actions, `${{ }}` in `run:`).
3. **Tests**: acceptance criteria not covered; tests asserting implementation details; skipped/disabled tests.
4. **Scope & size**: unrelated changes; diff > 400 lines without justification → ask for a split.
5. **Compatibility**: public API/schema/config/migration changes without backward compatibility, feature flag, or ADR.
6. **Docs/ops**: missing README/ADR updates; missing logging/metrics on new paths.

## What NOT to flag

- Formatting and style that CI enforces (prettier/ruff/gofmt), naming nits without a correctness impact, praise.
- Pre-existing issues outside the diff (mention once, as non-blocking).

## Severity labels

- 🔴 **Blocking**: must be fixed before merge (correctness, security, missing tests for new behaviour).
- 🟡 **Should fix**: fix in this PR or in an immediate follow-up issue.
- ⚪ **Nit (optional)**: author's call.

## Output expectations for AI reviewers

- One concise summary comment + inline comments only for concrete findings with `file:line` and a suggested fix (use ```suggestion blocks when a drop-in replacement exists).
- Never approve, request changes, merge, or push. Human CODEOWNERS own the decision.
