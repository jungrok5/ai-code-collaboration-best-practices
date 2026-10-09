# Security policy

## Reporting a vulnerability

Do not open a public issue. Use GitHub's private vulnerability reporting
(Security → Advisories → "Report a vulnerability") or email the maintainers listed in `.github/CODEOWNERS`.
We acknowledge reports within 3 business days.

## Scope notes for AI-assisted work

- AI agents in this repository run with least privilege: only users with write access can trigger them, tools are
  allow-listed, fork PRs get no secrets, and agent-authored commits need human approval (`agent-approval-check`).
- Every agent workflow treats issue, PR and comment text as untrusted input. If you find a prompt-injection path
  that makes an agent leak secrets or bypass review, report it as a vulnerability.
- Secrets never belong in the repository. Push protection and gitleaks (pre-commit) are enabled.

See `docs/08-security-and-governance.md` for the full model.
