---
name: split-pr
description: Propose how to split an oversized change into small, independently reviewable PRs. Use when a diff is well over ~400 lines or a reviewer asks for a split.
---

Group the changed files by purpose and propose an order (behaviour-free prep → interfaces with tests → implementation behind a flag → wiring → docs), each with a title, files, rough size and test plan.
Create branches only after the user agrees; never rewrite history others have pulled.
