---
name: triage-issue
description: Triage a GitHub issue - check it against the issue template, propose type/area/priority/size labels, detect duplicates, and ask for missing acceptance criteria. Never closes issues. Use when the user says "triage #12", "label this issue", or "is this issue ready for an agent".
---

# Triage an issue

Input: `$ARGUMENTS` = issue number.

1. Read: `gh issue view <n> --comments --json title,body,labels,author,comments`.
2. Completeness against the template (`.github/ISSUE_TEMPLATE/*.yml`): background, expected behaviour, acceptance criteria, scope/impacted files, out of scope, test plan. List what is missing.
3. Duplicates: `gh issue list --search "<3-5 keywords> in:title" --state all --limit 10`; mention likely duplicates with numbers (do not close).
4. Propose labels from `.github/labels.yml` (do not invent new ones):
   - `type/*` (bug, feature, chore, docs, security)
   - `area/*`
   - `priority/p0..p3` with a one-line justification
   - `size/*` estimate (XS ≤ 50 lines … XL > 800)
   - `ai:ready` **only if** acceptance criteria are testable, scope is bounded, and no product decision is pending; otherwise `ai:needs-human`.
5. Apply only when the user confirms: `gh issue edit <n> --add-label ...` and post a short triage comment (template below). Never close, never change assignees without being asked.

Comment template:

```
**Triage** (AI-assisted, verified by @<human>)
- Type/Area/Priority/Size: …
- Missing for agent-readiness: …
- Possible duplicates: #…
```
