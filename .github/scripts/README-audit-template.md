<!-- DOC-TYPE: living -->

# Audit Template v5 — Embedded in LMDS repo

> **Embedded:** V6.0.074 (PR #201) — 2026-07-24
> **Source:** audit-template-v5.zip (provided by user, validated on V6.0.073)
> **Location:** `.github/scripts/audit-template-v5/`

## Quick Start

```bash
# Run all 4 agents (Static + Runtime + Domain + Doc-Sync)
bash .github/scripts/audit-template-v5/05-runner/run-audit.sh . all

# Run single agent
bash .github/scripts/audit-template-v5/05-runner/run-audit.sh . static
bash .github/scripts/audit-template-v5/05-runner/run-audit.sh . runtime
bash .github/scripts/audit-template-v5/05-runner/run-audit.sh . domain

# Evidence output (gitignored — not committed)
ls .github/scripts/audit-template-v5/06-evidence/
```

## What it checks (49 checks total)

| Agent                             | Checks    | Coverage                                          |
| --------------------------------- | --------- | ------------------------------------------------- |
| **01-static** (ST-001..013)       | 13        | Structure, headers, naming, lint, function length |
| **02-runtime-gas** (RT-001..014)  | 14        | Quota, lock, batch, cache, CDN, library version   |
| **03-domain-logic** (DM-001..021) | 21        | Match Engine, RBAC, Thai, PII, SEC-001..012       |
| **05-doc-sync** (DS-000)          | 1 wrapper | Auto-runs 18 existing LMDS doc-code-sync checks   |

**Total:** 49 checks (13 ST + 14 RT + 21 DM + 1 DS wrapper that runs 18 LMDS checks)

## When to run

- **Before every PR** (manual): `bash .github/scripts/audit-template-v5/05-runner/run-audit.sh . all`
- **Before deploy** (mandatory): Same command + review 4 evidence reports
- **CI automation** (planned V6.0.075+): When system is stable, add `.github/workflows/10-audit-template.yml`

## False positives

Template v5 has ~0% false positive rate (validated on 7 RUN cycles per upstream).
If you find a false positive, report it via `docs/ai-reviews/COMPARATIVE_ANALYSIS.md`.

## Agent 4 (Aggregator) requires AI

The 4 evidence reports (`static-report.md`, `runtime-report.md`, `domain-report.md`, `docsync-report.md`)
should be sent to an AI Agent for aggregation into `final-report.md` per `04-aggregator/agent.md`.

This is intentional — shell-only checks can't prioritize findings across agents.

## Updating the template

Template is versioned. To update:

1. Download new version from upstream
2. Replace `.github/scripts/audit-template-v5/` contents
3. Run audit to verify no regression
4. Commit with message: `chore: update audit-template-vX → vY`

## See also

- `.github/scripts/audit-template-v5/00-MASTER/README.md` — Template's own README
- `.github/scripts/audit-template-v5/00-MASTER/CHECKS.md` — Flat index of all 49 checks
- `.github/scripts/audit-template-v5/00-MASTER/EXTENDING.md` — How to add new checks
- `docs/ai-reviews/COMPARATIVE_ANALYSIS.md` section 14 — Validation results on V6.0.073
