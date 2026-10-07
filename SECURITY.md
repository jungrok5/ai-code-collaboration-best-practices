# Security policy

## Reporting a vulnerability

Please **do not** open a public issue. Use GitHub's private vulnerability reporting
(Security → Advisories → "Report a vulnerability") or email the maintainers listed in `.github/CODEOWNERS`.
We acknowledge reports within 3 business days.

## Scope notes for AI-assisted work

- AI agents in this repository run with least privilege: write-access-only triggers, allow-listed tools, no secrets
  exposed to fork PRs, and human approval required for agent-authored commits (`agent-approval-check`).
- Issue/PR/comment text is treated as untrusted input by every agent workflow. If you find a prompt-injection path
  that makes an agent leak secrets or bypass review, report it as a vulnerability.
- Secrets never belong in the repository; push protection and gitleaks (pre-commit) are enabled.
See `docs/08-security-and-governance.md` for the full model.
