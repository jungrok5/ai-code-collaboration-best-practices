---
name: review-pr
description: Review a pull request or the current branch against REVIEW.md and report findings with file:line. Read-only. Use for "review PR #12", "review my changes".
allowed-tools: Read, Grep, Glob, Bash(git diff *), Bash(git log *), Bash(gh pr view *), Bash(gh pr diff *), Bash(gh pr checks *)
---

Standard: `REVIEW.md`, plus the linked design in `docs/designs/` if any (does the code match what was approved?).
Report a verdict, then blocking / should-fix / nits with `file:line`, a concrete failure path for each finding, and what you did not verify.
Skip style that CI enforces. Post to GitHub only if asked.
