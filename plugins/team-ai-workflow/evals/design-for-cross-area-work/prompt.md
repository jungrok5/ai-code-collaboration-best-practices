---
description: Ambiguous, cross-service work should start with a one-page design, not code.
tags: [design, smoke]
runs: 3
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

We need rate limiting for login attempts. It probably touches the API gateway, the auth service, and maybe the
billing webhooks too — nobody has decided yet, and none of that code is in this checkout. Can you get this started
for the team? Just reply in chat; don't create files.
