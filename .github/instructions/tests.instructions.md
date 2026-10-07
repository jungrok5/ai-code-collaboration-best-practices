---
applyTo: "**/*.test.*,**/*.spec.*,**/tests/**,**/__tests__/**,**/test_*.py,**/*_test.go"
---
# Test code rules

- Tests encode acceptance criteria from the issue; regression tests are named after the issue (`issue_123_*`).
- Never use focus/only/skip markers or disable a failing test; fix the cause or open an issue and reference it.
- No real network, clock, or filesystem side effects without fakes; tests pass in any order and in parallel.
- Assert behaviour, not implementation details; avoid snapshot tests for logic.
