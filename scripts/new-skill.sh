#!/usr/bin/env bash
# Scaffold a skill at the right tier (docs/18-adding-skills.md).
#   scripts/new-skill.sh <name> <personal|community|team> ["one-line description: what it does and when to use it"]
# personal  → ~/.claude/skills/<name>/SKILL.md            (only you; no review)
# community → plugins/team-ai-community/skills/<name>/      (opt-in plugin; one reviewer)
# team      → plugins/team-ai-workflow/skills/<name>/       (default plugin; + positive/negative eval stubs)
set -euo pipefail

name="${1:-}"; tier="${2:-}"; desc="${3:-}"
usage() { echo "usage: $0 <name> <personal|community|team> [\"description\"]" >&2; exit 2; }
[ -n "$name" ] && [ -n "$tier" ] || usage
printf '%s' "$name" | grep -Eq '^[a-z][a-z0-9-]{1,40}$' || { echo "name must be kebab-case (a-z, 0-9, -)" >&2; exit 2; }
root="$(git rev-parse --show-toplevel)"

case "$tier" in
  personal) dir="$HOME/.claude/skills/$name" ;;
  community) dir="$root/plugins/team-ai-community/skills/$name"; plugin="$root/plugins/team-ai-community" ;;
  team) dir="$root/plugins/team-ai-workflow/skills/$name"; plugin="$root/plugins/team-ai-workflow" ;;
  *) usage ;;
esac
[ ! -e "$dir" ] || { echo "already exists: $dir" >&2; exit 1; }
[ -n "$desc" ] || desc="TODO: what this skill does, and when to use it (the words a user would say)."

mkdir -p "$dir"
cat > "$dir/SKILL.md" <<EOF
---
name: $name
description: $desc
---

# ${name//-/ }

State the goal and the constraints, not a step-by-step script the model would follow anyway (docs/15-lean-harness.md).

- Goal: TODO
- Constraints: TODO (what must not change, what to check before finishing)
- Output: TODO (what the user gets back)
EOF

if [ "$tier" = team ]; then
  ev="$plugin/evals"
  mkdir -p "$ev/$name-use/graders" "$ev/$name-skip/graders"
  cat > "$ev/$name-use/prompt.md" <<EOF
---
description: A request that should use the $name skill.
tags: [$name]
runs: 3
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

TODO: a realistic user request where $name should be used.
EOF
  cat > "$ev/$name-use/graders/uses-skill.md" <<EOF
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?$name"'
---
EOF
  cat > "$ev/$name-use/graders/result.md" <<'EOF'
---
type: llm
---
PASS if TODO (what a correct result contains).
FAIL if TODO.
EOF
  cat > "$ev/$name-skip/prompt.md" <<EOF
---
description: A nearby request that must NOT use the $name skill.
tags: [$name, negative]
runs: 3
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

TODO: a similar-looking request where $name would be overkill or wrong.
EOF
  cat > "$ev/$name-skip/graders/no-skill.md" <<EOF
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?$name"'
min: 0
max: 0
arm: both
---
EOF
fi

echo "created $dir/SKILL.md"
[ "$tier" = team ] && echo "created eval stubs: $ev/$name-use, $ev/$name-skip"
if [ -n "${plugin:-}" ] && command -v claude >/dev/null 2>&1; then
  claude plugin validate "$plugin" --strict >/dev/null 2>&1 && echo "plugin validate: ok" || echo "plugin validate: fix the frontmatter (claude plugin validate $plugin --strict)"
fi
case "$tier" in
  personal) echo "next: edit the TODOs; it loads in your next session" ;;
  community) echo "next: edit the TODOs, bump plugins/team-ai-community/.claude-plugin/plugin.json version, open a PR (one reviewer)" ;;
  team) echo "next: edit the TODOs and both eval cases, run 'make ai-eval CASE=$name-*', bump plugin.json and marketplace.json versions together, open a PR" ;;
esac
