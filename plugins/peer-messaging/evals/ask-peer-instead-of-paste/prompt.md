---
description: Asking a teammate goes through ask-peer, not a paste-ready chat message.
tags: [peer-messaging, smoke]
runs: 3
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

Bob owns payments-api. My refund screen in this repo needs a refundReason field from his GET /refunds/{id} response.
Can you ask his agent when that field will ship? The peer relay tools are not connected in this test, so stop right
before sending and show me exactly what you would send.
