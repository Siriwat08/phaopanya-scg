<!-- DOC-TYPE: living -->
---
name: skill-creator
description: |
  Create a new Mavis skill. Use when the user asks to create a skill, turn a repeated
  workflow into a skill, or build a new reusable procedure. Do not use for improving or
  fixing an existing skill, or when the user only wants to run a skill or learn what skills exist.
---

# Skill Creator

Turn a reusable workflow into a dense skill, then verify it against a real prompt.

## Inputs to collect

Collect only the missing information:

1. **Goal**: What should the skill help the model do?
2. **Triggers**: What user phrases should activate it?
3. **Boundaries**: What nearby requests should not trigger it?
4. **Success bar**: What does one good run look like?

If the user only has a vague idea, load `plan-mode` to clarify the request. Do not invent a long interview flow inside this skill.

## Procedure

1. Check whether a matching skill already exists.

Review the skills currently loaded in your context. If a nearby skill already covers the use case, **do not create a duplicate**. Instead, suggest improving the existing skill.

2. Capture the reusable workflow from the lightest source available.

- Prefer the just-finished conversation or user-provided workflow doc.
- Condense it into the minimum procedure another model needs.
- If the idea is still vague, use `plan-mode`, then return here.

3. Design the skill around progressive disclosure.

- Put trigger/boundary information in frontmatter `description`, not in a `When to use` section.
- Keep `SKILL.md` focused on execution rules: procedure, output contract, failure handling.
- Move bulky background, schemas, or variants into `references/`.

4. Draft `SKILL.md` with high information density.

- Keep body sections short and imperative.
- Remove README-style teaching, feature tours, redundant trigger lists, and API-overview prose.
- Keep only one or two canonical examples.
- Follow `references/skill-template.md`, `references/description-rubric.md`, and `references/anti-patterns.md`.

Write the skill into the synced skills directory:

```
.skills/<skill-name>/SKILL.md
```

The skill syncer will automatically detect and upload new skills from this directory at session end.

Use this structure only when needed:

```
.skills/<skill-name>/
├── SKILL.md          # required
├── scripts/          # deterministic local work only
└── references/       # bulk material the main file should not inline
```

Do not create extra scaffolding by default: `README.md`, `CHANGELOG.md`, `install.sh`, `.env`, `.env.example`, `.gitignore`, `assets/`, or `evals/`.

5. Validate the skill.

Before declaring done, verify:
- Frontmatter has `name` (matching directory name, kebab-case) and `description` (concrete, trigger-rich).
- Body is under ~300 lines. If larger, move bulk content to `references/`.
- No forbidden files (`README.md`, `CHANGELOG.md`, etc.).
- All `references/` links resolve to actual files.

6. Eval against a real user prompt.

Pick a genuine user question that should trigger this skill. Use two **parallel** subagent calls:

1. **Producer**: "Load skill at `.skills/<skill-name>`, use it to handle: `<EVAL_PROMPT>`."
2. **Baseline**: "Handle this task without loading any skill: `<EVAL_PROMPT>`."

After both return, compare the results on these dimensions:
- Did the skill produce a more structured/complete result?
- Did it avoid unnecessary work or tangents?
- Was the output contract met?
- Any regressions vs baseline?

7. Iterate only if eval exposes a real weakness.

Stop when any of these is true:
- the user is satisfied
- the skill clearly beats or matches baseline without major regressions
- two rounds in a row produce no meaningful gain

## Output contract

Deliver:
- a skill directory at `.skills/<skill-name>/` with a valid `SKILL.md`
- at least one evaluation round where the skill is not worse than baseline

## Failure handling

- If validation keeps failing, rewrite the skill more simply instead of padding it.
- If eval says the skill is worse than baseline, check whether the problem is description quality, body bloat, over-strict procedure, or whether the skill should exist at all.
- If the user cancels the idea, remove the unfinished skill directory instead of keeping a half-product.

## Examples

**Input**: "I just figured out how to check someone's availability in Feishu Calendar. Turn this into a skill."

**Good path**:
1. Check loaded skills — no existing availability-checking skill.
2. Draft a concise `SKILL.md`, write to `.skills/feishu-availability/SKILL.md`.
3. Run eval, iterate if needed. Syncer uploads automatically.

**Bad path**: immediately create a brand-new skill without checking for overlap first.

## Additional resources

- `references/skill-template.md` - section skeleton
- `references/description-rubric.md` - description guidance
- `references/anti-patterns.md` - common failure modes
- `references/when-to-bundle-scripts.md` - script vs direct procedure
