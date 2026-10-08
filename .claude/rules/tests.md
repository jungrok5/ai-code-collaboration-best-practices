---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/__tests__/**"
  - "**/test_*.py"
  - "**/*_test.go"
---

# Tests

Tests encode the issue's acceptance criteria; name regression tests after the issue (`issue_123_*`) so the link survives.
If a test fails, fix the cause — a skipped or loosened test hides the bug from the next person. Use fakes for network and time so tests run in any order.
