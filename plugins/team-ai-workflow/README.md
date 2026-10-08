# team-ai-workflow (Claude Code plugin)

Guard rails, skills and subagents that make AI-assisted work on GitHub predictable across all team repositories.

| Component | What it does |
| --- | --- |
| `hooks/hooks.json` | **PreToolUse** blocks edits to protected paths (secrets, lockfiles, policy files) and enforces git rules (no commits on `main`/`master`/`develop`/`release/*`, no force-push — including `+refspec` and `--mirror` — or branch deletion except on feature-prefixed branches such as `feat/`, `fix/`, `ai/`; the hook cannot tell who else committed to a branch, so shared-branch etiquette still relies on people and rulesets). **PostToolUse** formats edited files. |
| `skills/` | `/design`, `/check-overlap`, `/implement-issue`, `/create-pr`, `/review-pr`, `/fix-ci`, `/split-pr`, `/triage-issue`, `/write-adr`, `/onboard` |
| `agents/` | `code-reviewer`, `security-reviewer`, `test-writer`, `issue-triager`, `docs-writer` |

## Install (any repository)

```bash
claude plugin marketplace add jungrok5/ai-code-collaboration-best-practices   # once per machine
claude plugin install team-ai-workflow@ai-collab
```

Or commit it as team policy in the repo's `.claude/settings.json` (members are prompted to install on first session):

```json
{
  "extraKnownMarketplaces": {
    "ai-collab": { "source": { "source": "github", "repo": "jungrok5/ai-code-collaboration-best-practices" } }
  },
  "enabledPlugins": { "team-ai-workflow@ai-collab": true }
}
```

Try it without installing: `claude --plugin-dir ./plugins/team-ai-workflow`.

## Configuration

Protected path patterns live in `scripts/protect-files.sh`; extend them there and document the change in `AGENTS.md`.

## Validate / release

```bash
claude plugin validate ./plugins/team-ai-workflow --strict
claude plugin validate . --strict          # marketplace manifest at repo root
```

Bump `version` in `.claude-plugin/plugin.json` and in `.claude-plugin/marketplace.json` together (CI checks they agree).
