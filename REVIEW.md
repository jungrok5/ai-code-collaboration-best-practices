# REVIEW.md: review standard for humans and AI reviewers

Copilot code review and Claude Code Review read this file in addition to `AGENTS.md`. Keep it short.

## What to flag, in priority order

1. Correctness: logic errors, off-by-one, null/undefined, races, error handling, resource cleanup. Trace a concrete
   input path before flagging.
2. Security: injection (SQL/command/template), missing authn/authz, secrets in code or logs, SSRF, path traversal,
   unsafe deserialisation, risky new dependencies, GitHub Actions hardening (`pull_request_target`, unpinned actions,
   `${{ }}` in `run:`).
3. Tests: acceptance criteria not covered; tests asserting implementation details; skipped or disabled tests.
4. Scope and size: unrelated changes; a diff over 400 lines without justification (ask for a split).
5. Compatibility: public API, schema, config or migration changes without backward compatibility, a feature flag, or
   an ADR.
6. Docs and ops: missing README or ADR updates; missing logging or metrics on new paths.

## What not to flag

- Formatting and style that CI enforces (prettier/ruff/gofmt, `make style`), naming nits with no correctness impact,
  praise.
- Pre-existing issues outside the diff (mention once, as non-blocking).

## Severity labels

AI reviewers prefix each finding with the marker.

| Marker | Label | Meaning |
| --- | --- | --- |
| 🔴 | Blocking | Must be fixed before merge (correctness, security, missing tests for new behaviour) |
| 🟡 | Should fix | Fix in this PR or in an immediate follow-up issue |
| ⚪ | Nit (optional) | Author's call |

## Output expectations for AI reviewers

- One concise summary comment, plus inline comments only for concrete findings with `file:line` and a suggested fix
  (use ```suggestion blocks when a drop-in replacement exists).
- Never approve, request changes, merge, or push. Human CODEOWNERS own the decision.
