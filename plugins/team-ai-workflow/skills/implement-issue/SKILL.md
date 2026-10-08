---
name: implement-issue
description: Implement a GitHub issue on a new branch and leave it ready for a PR. Use for "implement #123", "work on this issue", or an issue URL.
---

Read the issue and its comments (`gh issue view $ARGUMENTS --comments`); later comments can change the scope.
If the work is bigger than a one-sentence change, check `/check-overlap`, and if it needs a design that does not exist yet, stop and suggest `/design`.
If the acceptance criteria are ambiguous, ask before coding.

Repo specifics: branch `<type>/<issue>-<slug>` from the default branch; tests that encode the acceptance criteria;
`make check` must pass before you commit; Conventional Commit messages ending in `(#<issue>)`.
Finish with what changed, the commands you ran and their results, and anything left out. Push or open a PR only if asked (`/create-pr`).
