---
name: new-skill
description: Create a new Claude Code skill at the right tier (personal, community or team) with the scaffold, eval stubs and checks the repo expects. Use when the user wants to add, write, share or promote a skill, or asks how skills are added to the marketplace.
---

# Add a skill

Follow `docs/18-adding-skills.md`. Ask the user for the tier only if it is unclear:

- personal: only the user needs it, or it is an experiment.
- community: others may want it; opt-in plugin `team-ai-community`, one reviewer.
- team: the team relies on it by default; plugin `team-ai-workflow`, needs a positive and a negative eval.
- team standard (always applied, enforced by checks) is not a skill task: point to docs/17 §5.

Run `make new-skill NAME=<kebab-name> TIER=<tier> DESC="<what it does and when to use it>"`, then write the body
as goals and constraints (not a script the model would follow anyway), fill the eval prompts for team skills, and run
`claude plugin validate <plugin> --strict` (and `make ai-eval CASE=<name>-*` for team skills). If the skill adapts
text from elsewhere, check the license and add a row to the plugin's THIRD_PARTY_NOTICES.md. Bump the plugin version
(team: plugin.json and marketplace.json together) and open a PR with the tier in the title, e.g.
`feat(skills): add <name> (community)`.
