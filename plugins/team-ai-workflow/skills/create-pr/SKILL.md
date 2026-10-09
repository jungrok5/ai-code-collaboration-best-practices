---
name: create-pr
description: Push the current branch and open a pull request that follows this repo's template. Use for "open a PR", "create the pull request", "ship this".
---

Before opening: `make check` passes, and the diff is about 400 lines or less (otherwise suggest `/split-pr`).
Title: Conventional Commit, it becomes the squash commit. Body: `.github/pull_request_template.md` with a summary and `Closes #n`,
test evidence (commands and results), exactly one AI-assistance box ticked, and a link to the design in `docs/designs/` if there is one.
Open as a draft when CI has not run yet or an agent wrote the code (label `ai:generated`). Print the URL.
