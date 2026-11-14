---
type: llm
weight: 2
---
PASS if the response proposes a peer task addressed to Bob (for example `@bob` or `@bob/payments-api`) with kind
`question`, a self-contained text that says what is needed (refundReason in GET /refunds/{id}), why (the refund screen
depends on it) and asks when it ships, and it asks the user to confirm before sending.
FAIL if it only drafts a chat message for the user to copy into Teams or Slack, or claims it already sent something.
