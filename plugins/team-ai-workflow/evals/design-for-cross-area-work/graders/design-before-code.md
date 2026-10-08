---
type: llm
weight: 2
---
PASS if the response puts a design step before any implementation: it drafts or outlines a short design (scope,
components or a diagram, affected areas/repos, open questions such as whether billing webhooks are in scope) and
says the design should be reviewed or approved — for example as its own PR — before code is written.
FAIL if the response writes implementation code or jumps to an implementation task list without a design to approve.
