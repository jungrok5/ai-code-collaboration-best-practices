---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/__tests__/**"
  - "**/test_*.py"
  - "**/*_test.go"
---

# Rules for test code

- Tests encode acceptance criteria from the issue; name them after the behaviour, and after the issue for regressions (`issue_123_*`).
- Never use focus/only/skip markers or disable a failing test to get CI green; fix the cause or open an issue and reference it in a comment.
- No real network, clock, or filesystem side effects without fakes; tests must pass in parallel and in any order.
- Assert behaviour, not implementation details; avoid snapshot tests for logic.
