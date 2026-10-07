---
name: review-pr
description: Review a pull request (or the current branch diff) against the team checklist and produce findings ordered by severity with file:line references. Read-only. Use when the user says "review PR #12", "review my changes", "code review", or before opening a PR.
allowed-tools: Read, Grep, Glob, Bash(git diff *), Bash(git log *), Bash(gh pr view *), Bash(gh pr diff *), Bash(gh pr checks *)
---

# Review a pull request

Input: `$ARGUMENTS` = PR number/URL, or empty for the current branch vs the default branch.

## Gather

- PR: `gh pr view <n> --json title,body,labels,files,additions,deletions,baseRefName` then `gh pr diff <n>`.
- Branch: `git diff origin/<default>...HEAD`.
- Read `AGENTS.md` and any `.claude/rules/*.md` whose `paths` match the changed files; those rules are the review standard.

## Review order (stop early on blockers)

1. **Scope & size**: does the diff match the linked issue? Unrelated changes → request split. > 400 lines without justification → request split.
2. **Correctness**: logic errors, off-by-one, null/undefined, race conditions, error handling, resource cleanup. Trace at least one realistic input path per changed function.
3. **Tests**: are the acceptance criteria covered? Do tests assert behaviour (not implementation)? Any skipped/disabled tests?
4. **Security**: injection (SQL/command/template), authn/authz checks, secrets in code or logs, unsafe deserialisation, SSRF, path traversal, dependency additions (why, license, maintenance).
5. **Compatibility**: public API / schema / config changes, migrations reversible, feature flags for risky paths.
6. **Readability & conventions**: naming, structure, duplication vs existing helpers, comments explain *why*.
7. **Docs & ops**: README/ADR/CHANGELOG updated when behaviour or architecture changes; logging/metrics for new paths.

## Output format

```
### Verdict: APPROVE | REQUEST CHANGES | COMMENT
Summary (2–3 lines)

#### Blocking
- [path:line] problem → why it matters → suggested fix
#### Should fix
- ...
#### Nits (optional)
- ...
#### Tested / not tested by the author (from PR body)
```

Rules: cite `file:line`; no praise-only comments; never invent issues to look thorough; if you did not run the code, say so. Do not post to GitHub unless the user explicitly asks (then use `gh pr review` / `gh pr comment`).
