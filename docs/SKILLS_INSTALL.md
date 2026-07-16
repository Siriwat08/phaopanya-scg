<!-- DOC-TYPE: living -->

# LMDS Skills Pack — Installation Guide

## What you get

A `.skills/` folder containing **10 LMDS V6.0 skills** for Mavis:

| #   | Skill                       | Lines | Purpose                                                                 |
| --- | --------------------------- | ----- | ----------------------------------------------------------------------- |
| 1   | `lmds-architect`            | 657   | Master architecture overview (3-Domain, 16 Laws, 8 Rules, 35 .gs files) |
| 2   | `lmds-code-reviewer`        | 791   | Enforce 16 Immutable Laws + 5 Hard Rules on any .gs/.js change          |
| 3   | `lmds-bug-hunter`           | 603   | BUGHUNT scanner (P0/P1/P2/P3, CRIT-001 to CRIT-012 regressions)         |
| 4   | `lmds-refactor-advisor`     | 784   | Plan the split of god functions (>100 lines, complexity >30)            |
| 5   | `lmds-predeploy-checker`    | 366   | 35-item pre-deployment go/no-go gate                                    |
| 6   | `lmds-match-engine-builder` | 657   | Trinity + 8 Rules + Hybrid Alias match engine builder                   |
| 7   | `lmds-gas-best-practices`   | 620   | GAS quotas/limits/workarounds (6-min, CacheService 100KB, etc.)         |
| 8   | `lmds-cicd-pipeline`        | 666   | 8 GitHub Actions workflows + clasp deploy                               |
| 9   | `lmds-security-auditor`     | 870   | SEC-001 → SEC-012 (12 security fixes)                                   |
| 10  | `lmds-thai-data-helper`     | 1066  | Thai name/address normalization + Double Metaphone + 7,537-row geo dict |

Bonus: `skill-creator` — meta-skill for creating your own skills.

## Install

### Option A — Mavis cloud workspace (recommended)

1. Extract this zip anywhere
2. Copy or merge the `.skills/` folder into your target workspace:

   ```bash
   # from the extracted location
   cp -r .skills/ <target-workspace>/.skills/
   ```

3. End the current Mavis session (or start a new one)
4. The skill syncer will auto-detect the new skills and upload them to the agent's roster
5. New sessions will load them automatically when trigger keywords match

### Option B — Mavis CLI (local)

Drop the same `.skills/` folder into your project root. The CLI syncer picks it up the same way.

### Option C — Manual upload

If your Mavis deployment uses a different sync mechanism (e.g. admin dashboard, registry), point it at the `.skills/<name>/SKILL.md` paths — each one is independently loadable.

## Verify

After install, in a new Mavis session:

```
skill({ name: "lmds-architect" })
```

Should return the full skill body. Or just say:

> "Explain the LMDS 16 Immutable Laws"

and the trigger should auto-load `lmds-code-reviewer` (or `lmds-architect` first).

## Trigger keywords (for auto-load)

Each skill has a `description:` frontmatter that lists its triggers. Examples:

- `lmds-architect` → "LMDS", "phaopanya", "Trinity", "16 Immutable Laws", "8 Match Rules"
- `lmds-code-reviewer` → "/REVIEW15", "code review", "law check", "compliance"
- `lmds-bug-hunter` → "/BUGHUNT", "find bugs", "critical issue", "timeout"
- `lmds-predeploy-checker` → "/PREDEPLOY", "ready to deploy", "go-live"
- `lmds-match-engine-builder` → "match engine", "8-rule", "Hybrid Alias", "M_ALIAS"
- `lmds-gas-best-practices` → "GAS limit", "6 minute timeout", "CacheService", "clasp"
- `lmds-cicd-pipeline` → "GitHub Actions", "workflow", "clasp push failed", "deploy"
- `lmds-security-auditor` → "SEC-001", "PII", "hardcoded secret", "OAuth scope"
- `lmds-thai-data-helper` → "Thai name", "prefix", "province", "Double Metaphone"
- `lmds-refactor-advisor` → "/REFACTOR", "god function", "SRP violation", "complexity"

Mention any of these in a prompt and the matching skill loads automatically.

## Source

Built from: https://github.com/Siriwat08/phaopanya-scg (LMDS V6.0.046)
Created: 2026-07-13

## License

MIT (matches the source repo).
