<!-- DOC-TYPE: living -->
---
name: lmds-predeploy-checker
description: PREDEPLOY verification for LMDS V6.0 — runs the 35-item pre-deployment checklist covering code quality, documentation, configuration, environment, and monitoring. Use before merging to main, before clasp push to production, or as a release gate. Triggers on "/PREDEPLOY", "ready to deploy?", "pre-deployment checklist", "go-live", "production readiness", "merge to main", "release", "go/no-go", "go decision".
---

# PREDEPLOY Verification

LMDS Pre-Deploy Checker — Production Go/No-Go Gate
Status: LMDS V6.0.046 — 96% Production Ready (after 18 audit cycles, 116 fixes)
Purpose: Final gate before clasp push to production. Catches the last 4% of issues that slip through code review and bug hunt.
Decision rule: Any P0 or unfixed P1 = NO-GO. All P2 must have an issue filed.

This skill is the final gate — load lmds-architect first, then run lmds-code-reviewer and lmds-bug-hunter to clear their respective gates, then run this skill for the final pre-deploy verification.

How to Use This Skill
When the user asks "are we ready to deploy?" or says /PREDEPLOY, [CMD: PREDEPLOY], "go-live", or is about to merge to main:

1.
Run the 35-point checklist below in 5 categories (§ 1-5).
2.
Run the automated bash verifications in § 6.
3.
Output the Go/No-Go decision using the § 7 template.
4.
If NO-GO, list the blocking issues with file:line + patch.
The user is responsible for running the live verifications (System Integrity, Preflight Audit) inside Apps Script — this skill guides what to run and what to look for.

1. Code Quality (20 items)
#	Check	How to verify	Pass criteria
1.1	ESLint passes	npm run lint	0 errors (warnings allowed)
1.2	Prettier passes	npm run format:check	100% files compliant
1.3	16 Immutable Laws	lmds-code-reviewer skill	16/16 PASS
1.4	Security audit (SEC-001→012)	lmds-security-auditor skill	12/12 PASS
1.5	No dead code	grep -rn 'function .*{' src/**/*.gs cross-ref'd with callers	0 unused functions
1.6	Test coverage on entry points	manual review of 00_App.gs	every menu handler covered
1.7	Documentation up-to-date	diff README vs 01_Config.APP_VERSION	versions match
1.8	CHANGELOG entry	grep "6.0.046" CHANGELOG.md	entry exists
1.9	VERSION headers consistent	grep "VERSION:" src/**/*.gs | uniq -c	all show 6.0.046
1.10	No hardcoded secrets	grep -rnE "AIza[A-Za-z0-9_-]{35}" src/	0 matches
1.11	No TODO/FIXME	grep -rnE "TODO|FIXME" src/**/*.gs	0 matches (or all assigned)
1.12	No stray console.log	grep -rn "console.log" src/**/*.gs	only in dev/debug wrappers
1.13	Try-catch on entry points	grep -c "try {" 00_App.gs vs menu function count	ratio ≥ 0.9
1.14	Lock release in finally	grep -A 5 "LockService" src/**/*.gs	every acquire has a finally { lock.releaseLock() }
1.15	Time guard on long pipelines	grep "hasTimePassed_" src/*Pipeline* src/*MatchEngine*	present
1.16	Cache invalidation chain	lmds-bug-hunter § 2.6	all writes invalidated
1.17	Batch ops only (Law 4)	grep -rn "setValue(|getValue(" src/**/*.gs	all outside loops
1.18	AuthZ on destructive ops	grep -B 1 "setValue|setValues" src/*Master*	each has isAuthorizedUser_ above
1.19	PII masked in logs	grep -rn "logError" src/**/*.gs	all use maskEmail_ or md5Hash_
1.20	API keys in headers	grep "UrlFetchApp.fetch" src/**/*.gs	all use headers: {'x-goog-api-key': ...}
2. Environment Setup (10 items)
#	Check	How to verify	Pass criteria
2.1	Google Sheet exists	open sheet	not in trash
2.2	Script Properties set	Apps Script → Project Settings → Script Properties	GEMINI_API_KEY (or empty), LMDS_ADMINS, SCG_COOKIE (if used)
2.3	.clasp.json correct	cat .clasp.json	scriptId matches Apps Script project (~57 chars), rootDir: "src"
2.4	Sheet backup created	File → Make a copy	backup file URL saved in deploy log
2.5	Sheet protection enabled	menu → "🛡️ ป้องกันข้อมูล Sensitive"	8 sheets protected + Q_REVIEW range
2.6	RBAC roles assigned	27_RbacService.getUserRole(email) for each admin	correct role per user
2.7	Test data loaded	SCGนครหลวงJWDภูมิภาค has ≥ 20 rows	met
2.8	MatchEngine tested	run menu "▶️ รัน Full Pipeline" with 20 sample rows	output rows in FACT_DELIVERY + Q_REVIEW
2.9	WebApp loads	clasp deploy --description "test" then open URL	all pages render
2.10	36 menu items visible	refresh sheet, count menu items	36 (or current count per roadmap)
3. Monitoring Setup (5 items)
#	Check	How to verify	Pass criteria
3.1	SYS_LOG monitoring	Apps Script → Executions → filter "Failed"	0 failed in last 24h
3.2	Error alerts enabled	menu → "🔧 ระบบ & ตั้งค่า → ⚙️ ตั้งค่า API Key" → set Telegram	Telegram bot token + chat ID set
3.3	Telegram bot configured (if using)	check PropertiesService for TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID	set, test message received
3.4	Daily health check scheduled	GitHub Actions tab → 05-scheduled-health.yml	workflow exists + last run green
3.5	Admin contact list updated	LMDS_ADMINS ScriptProperty	current admins only
4. Documentation Sync (5 items)
#	Check	How to verify	Pass criteria
4.1	README.md version	header line	V6.0.046
4.2	BLUEPRINT.md version	grep "Version:" BLUEPRINT.md	6.0.046
4.3	CHANGELOG.md	grep "\[6.0.046\]" CHANGELOG.md	entry exists
4.4	9 doc-code-sync checks	GitHub Actions tab → 07-doc-code-sync workflow	all 9 green
4.5	Sheet count matches docs	count sheets, compare to docs/01_SOP_Admin_LMDS.md § 12.1	19 (MAPS_CACHE removed)
5. Risk Acknowledgment (3 items)
#	Check	Decision
5.1	Google Apps Script 6-min hard limit	acknowledge + confirm Time Guard active
5.2	SCG cookie expires ~24h	acknowledge + runbook for re-grab exists
5.3	Roll-back plan ready	last known-good .gs bundle saved in apps-script-target (or use clasp versions)
6. Automated Verifications (bash)
Run these in order before deciding:

bash

Copy
# 6.1 — Files exist & structured correctly

ls src/O_core_system/00_App.gs && \

ls src/O_core_system/01_Config.gs && \

ls src/O_core_system/02_Schema.gs && \

ls src/1_group1_master_db/10_MatchEngine.gs && \

ls src/2_group2_daily_ops/18_ServiceSCG.gs && \

echo "✅ All required files present"


# 6.2 — appsscript.json valid

python3 -c "import json; d=json.load(open('appsscript.json')); assert d['runtimeVersion']=='V8'; assert len(d['oauthScopes'])==6; print('✅ appsscript.json valid + 6 OAuth scopes')"


# 6.3 — No hardcoded secrets

! grep -rnE "AIza[A-Za-z0-9_-]{35}|password\s*=\s*[\"'][^\"']{6,}" src/ appsscript.json .clasp.json 2>/dev/null && \

echo "✅ No hardcoded secrets"


# 6.4 — ESLint clean

npm run lint && echo "✅ ESLint pass" || echo "❌ ESLint failed"


# 6.5 — Prettier clean

npm run format:check && echo "✅ Prettier pass" || echo "❌ Prettier failed"


# 6.6 — No TODO/FIXME

! grep -rnE "TODO|FIXME" src/**/*.gs && echo "✅ No TODO/FIXME" || echo "❌ Found TODO/FIXME"


# 6.7 — Function count

grep -hE "^function " src/**/*.gs | wc -l   # expect ~535


# 6.8 — VERSION headers consistent

grep -hE "^\s*\*\s*VERSION:" src/**/*.gs | sort -u

# expect: ' * VERSION: 6.0.046' (one line)


# 6.9 — Function collisions

grep -hE "^function \w+" src/**/*.gs | sed -E 's/.*function (\w+).*/\1/' | sort | uniq -c | awk '$1>1' | head

# expect: empty


# 6.10 — Hardcoded indices (Law 3)

grep -rnE "row\[[0-9]+\]" src/**/*.gs | head

# expect: 0 (except in 01_Config.gs where defaults are defined)
7. Decision Output Template
markdown

Copy
# LMDS Pre-Deploy Verification — V6.0.046


**Date:** 2026-07-13

**Branch:** main

**Commit:** abc1234

**Reviewer:** <name>


## Verdict: ✅ GO / ❌ NO-GO / 🟡 GO with caveats


## Score

- **Code Quality:** 18/20 (2 minor warnings)

- **Environment:** 10/10 ✅

- **Monitoring:** 4/5 (1 advisory)

- **Documentation:** 5/5 ✅

- **Risks acknowledged:** 3/3 ✅

- **Total:** 40/43 (93%)


## Blockers (must fix before deploy)

- (none)


## Warnings (deploy OK, file follow-up issues)

- [ ] 1.12: 2 stray `console.log` in 14_Utils.gs (low risk)

- [ ] 3.2: Telegram chat ID not set (alerts disabled, no immediate impact)


## Automated Checks

| # | Check | Result |

|---|-------|--------|

| 6.1 | Files exist | ✅ |

| 6.2 | appsscript.json valid + 6 scopes | ✅ |

| 6.3 | No hardcoded secrets | ✅ |

| 6.4 | ESLint | ✅ 0 errors |

| 6.5 | Prettier | ✅ |

| 6.6 | No TODO/FIXME | ✅ |

| 6.7 | Function count | 535 ✅ |

| 6.8 | VERSION headers | All 6.0.046 ✅ |

| 6.9 | No function collisions | ✅ |

| 6.10 | No hardcoded indices | ✅ |


## Live Checks (run inside Apps Script)

- [ ] `checkSystemIntegrity()` → "✅ System is ready"

- [ ] `runPreflightAudit()` → all green

- [ ] `setupAllSheets()` → no errors

- [ ] WebApp URL loads all 8 pages

- [ ] Sample 20 rows → 16+ land in FACT_DELIVERY

- [ ] Q_REVIEW decisions applied correctly


## Deploy Command (only if GO)

```bash

git tag v6.0.046

git push origin v6.0.046

gh workflow run 04-release.yml

# Wait for release, then:

clasp push

clasp deploy --description "V6.0.046 production"
Post-Deploy Verification

 WebApp URL still works

 checkSystemIntegrity() still "✅ ready"

 Menu still shows 36 items

 SYS_LOG has no FATAL entries in next 24h

 One Q_REVIEW decision applied end-to-end (golden path)

Sign-off

 Tech lead

 Product owner

 DevOps (if clasp + GitHub Actions)

text

Copy

---


## 8. Common Pre-Deploy Pitfalls (Lessons Learned from Audit Cycles)


These are issues that **slipped past code review** and were caught only at deploy time. Always re-check:


1. **VERSION drift** — `01_Config.APP_VERSION` says `6.0.045` but a file header still says `6.0.046`. The `07-doc-code-sync.yml` check should catch this; if it didn't, the check is broken.


2. **Function added but not in DEPENDENCIES** — a new helper uses `personMerge_` but the calling file's header doesn't list `06_PersonService` in DEPENDENCIES.


3. **Sheet name typo** — new code references `SHEET.FACT` but the actual constant is `SHEET.FACT_DELIVERY`. Sheet name not found = entire pipeline halts.


4. **Cache invalidation order** — invalidation called *before* the write, not after. Stale data served.


5. **Property name mismatch** — code reads `ADMIN_EMAILS` but property was set as `LMDS_ADMINS`. Both keys exist for back-compat but using the right one matters.


6. **OAuth scope added but appsscript.json not updated** — code calls Gmail API but the scope `gmail.send` isn't in the manifest. Silent fail on auth.


7. **Triggers orphaned** — previous deploy's auto-resume trigger still hanging. The new code's `installAutoResume_()` adds a new one, leaving duplicates.


8. **Branch protection bypassed** — PR merged without required approval. Audit trail broken.


9. **CHANGELOG entry added in wrong version** — `[6.0.045]` entry but only `[6.0.046]` is being deployed. Doc-code drift.


10. **Snapshot test not run** — `29_SnapshotTest` exists but skipped. A subtle behavior change slips through.


---


## 9. Rollback Procedure (if something goes wrong post-deploy)


```bash

# 9.1 — Find the last good version

clasp versions


# 9.2 — Deploy the previous version

clasp deploy --versionNumber <previous_version> --description "rollback to V6.0.043"


# 9.3 — Or revert via git

git revert <bad_commit_sha>

git push origin main

# This triggers CI/CD; the deploy workflow will push the revert
Critical: If data was corrupted (e.g. wrong master writes), do not just rollback code — also:

1.
Restore sheet from backup (File → Version history, or from the "Make a copy" backup)
2.
Run invalidateAllGlobalCaches() after restore
3.
Re-run checkSystemIntegrity()
4.
File post-mortem
10. Integration with Other Skills

lmds-architect — load first.

lmds-code-reviewer — required before this skill.

lmds-bug-hunter — required before this skill.

lmds-refactor-advisor — use if the deploy is blocked by a Law 2 violation.

lmds-security-auditor — required before this skill.

lmds-cicd-pipeline — use to verify the deploy workflow itself is healthy.
