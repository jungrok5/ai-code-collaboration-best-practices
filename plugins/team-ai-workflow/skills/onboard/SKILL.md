---
name: onboard
description: Set a newcomer up and give them a short tour of how this repo works — checks what is installed and configured, fixes the safe parts, lists what only a person can do, then explains rules, commands, design-first flow, automation, guard rails. Use for "onboard me", "set me up", "what's left to configure", "how does this repo work".
---

1. Run `scripts/doctor.sh --json` (fall back to `make doctor` if the script is missing). Treat its output as the source of truth for setup state; do not re-check by hand.
2. If any FAIL or WARN has a fix that `--fix-safe` covers (git hooks, commit template, plugin install/update), ask once, then run `scripts/doctor.sh --fix-safe --scope local`.
3. Fix what an agent may fix when the user agrees (e.g. fill the `AGENTS.md` Project section, propose `area/*` labels or the CodeQL language in a PR). Never set secrets, change GitHub settings, or edit protected files (`.claude/settings.json`, `CODEOWNERS`, rulesets).
4. List every remaining MANUAL, FAIL and SKIP item as: who must act → the exact command or URL from the `fix` field.
5. Then the tour, one screen, based on the actual files: `AGENTS.md`, `make help`, `docs/14-design-first-and-overlap.md`, `.github/workflows/`, active designs (`python3 scripts/designs/board.py brief`). End with three concrete next steps for this person.
