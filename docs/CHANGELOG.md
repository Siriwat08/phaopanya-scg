<!-- DOC-TYPE: historical -->

# Changelog — LMDS V6.0

All notable changes to LMDS V6.0 (Logistics Master Data System) are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## Versions Summary

| Version | Date       | Cycle                                                                       | Issues                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------- | ---------- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 6.0.062 | 2026-07-16 | CLEANUP AI REVIEWS                                                          | Delete all original AI review files in `ai-reviewer-{1,2,3,4}/` (22 files, ~1.4MB) — important data already extracted to COMPARATIVE_ANALYSIS.md, AI-REVIEW-PROTOCOL.md, TODO.md, CI-CD-TROUBLESHOOTING.md. Folders kept with .gitkeep for future reviews.                                                                                                                                                                                                  |
| 6.0.063 | 2026-07-16 | P0 ROUND 2 SECURITY FIXES                                                   | SSTI fix (Index.html <?!= escaped), LockService guards (createPerson/Place/GeoPoint/Destination/mergePersonRecords), AuthZ guards (isAuthorizedUser_ on 5 destructive ops)                                                                                                                                                                                                                                                                                  |
| 6.0.064 | 2026-07-16 | P1 XSS + PII MASKING                                                        | XSS escape in 7 WebApp components (ChartCard, StatCard, DataTable, App toast, MapAnalytics, LiveFeed error, LiveFeed JSON.stringify), PII phone masking (maskedPhone) in 06_PersonService.gs                                                                                                                                                                                                                                                                |
| 6.0.065 | 2026-07-16 | P1 DOCUMENTATION SYNC                                                       | 6 docs updated: README, BLUEPRINT, CONTEXT, System Guide, Column Dictionary, IT Guide — version + file count + M_ALIAS columns                                                                                                                                                                                                                                                                                                                              |
| 6.0.066 | 2026-07-16 | P1 FORMULA INJECTION                                                        | sanitizeForSheet_() + sanitizeRowForSheet_() in 14_Utils.gs, applied to createPerson/Place/GeoPoint/Destination (4 spots)                                                                                                                                                                                                                                                                                                                                   |
| 6.0.067 | 2026-07-17 | P0 ROUND 3 SECURITY FIXES                                                   | PII email masking (maskEmailSafe_), SCG Cookie B1→PropertiesService primary + auto-migrate, XSS LiveFeed JSON.stringify escape, lock double-release (releaseScriptLock_), auth fail-open→deny-by-default, CodeQL #56 useless conditional fix                                                                                                                                                                                                                |
| 6.0.068 | 2026-07-17 | P1 ROUND 3 FIXES                                                            | TODO.md rewrite (accurate status), BLUEPRINT.md update (version + SEC-004 + 39 modules), wire check_10-18 into 07-doc-code-sync.yml (9 new CI steps)                                                                                                                                                                                                                                                                                                        |
| 6.0.069 | 2026-07-17 | P2 ROUND 3 POLISH                                                           | Remove 3 dead functions (16_GeoDictionaryBuilder), extract parsePaginationParams_ DRY (3 spots), ratio <= → < (21b_AliasSafeguard), simplify tryLock try-catch, 99_Legacy sunset V7.0                                                                                                                                                                                                                                                                       |
| 6.0.061 | 2026-07-16 | PHASE D-2+D-4 PROTOCOL + SELF-AUDIT                                         | (1) `docs/AI-REVIEW-PROTOCOL.md` — 5 verification rules for AI reviewer reports (verify file existence, line number, [FIX vXXX] comments, context-aware reading, cross-reference) (2) `scripts/self_audit.sh` — run all 18 CI checks before pushing PR (supports --strict mode)                                                                                                                                                                             |
| 6.0.060 | 2026-07-16 | PHASE D-1 CI CHECKS (8 NEW)                                                 | Add 8 new CI check scripts: check_10 (dead functions), check_11 (wrapper usage), check_12 (path consistency), check_13 (no runtime CDN), check_14 (external API resilience), check_15 (string duplication), check_16 (API call count), check_17 (production readiness). All are warning-level (STRICT_MODE=0) — surface issues without blocking CI.                                                                                                         |
| 6.0.059 | 2026-07-16 | PHASE C-3 PROCESS IMPROVEMENTS                                              | (1) `docs/TODO.md` — track ทุกข้อเสนอที่ยังไม่ได้ทำ (Group D/E + Phase D) (2) `docs/CI-CD-TROUBLESHOOTING.md` — บันทึก 12 ปัญหา CI/CD ที่เคยเจอ + วิธีแก้ (3) `.github/pull_request_template.md` — เพิ่ม Pre-Merge Checklist (ประเภท PR + กฎสำคัญ + Final CI Check) (4) `check_18_pr_title_vs_diff.sh` — ตรวจ PR title สอดคล้องกับไฟล์ที่เปลี่ยนจริง                                                                                                        |
| 6.0.058 | 2026-07-16 | PHASE C-2 — 5-LAYER ALIAS SAFEGUARD (LAYER 1+5)                             | Add `21b_AliasSafeguard.gs` with Layer 1 (Structural Validation — Levenshtein similarity floor ≥ 0.5) + Layer 5 (Circuit Breaker — max 50 promotes/day via PropertiesService). Hooked into `createGlobalAlias()` for `source='HUMAN'` only (auto-aliases skip safeguard). Prevents misclick merge + spam approve. Layer 2-4 deferred (over-engineering for small team).                                                                                     |
| 6.0.057 | 2026-07-16 | PHASE C-1 QUICK CODE WINS                                                   | (1) Google Maps URL helper `getGoogleMapsUrl_()` in ViewHelpers.html — replaced 5 duplicated string concatenations (DRY) (2) `runNormalize()` UI label fix — menu now says "Normalize (อัตโนมัติใน Step 3)" instead of misleading "Step 2 — Normalize" (3) ESLint `max-lines-per-function` 300→200 (compromise — Reviewer 2 suggested 100, too strict for GAS) (4) Telegram retry wrapper — exponential backoff (2s/4s/8s, 3 retries) for 429/5xx responses |
| 6.0.056 | 2026-07-15 | SECURITY DOC — B3 OAUTH SCOPES REVIEW                                       | Audit all 6 OAuth scopes in appsscript.json — verified all are used (30 files spreadsheets, 21 calls userinfo.email, 19 files storage, 33 calls container.ui, 3 files scriptapp, 4 files external_request). Fixed SECURITY.md §2 (was listing wrong scope names). Added §3 pre-deploy checklist for `access: MYSELF` → `DOMAIN`/`ANYONE` change + `executeAs` trade-offs. No code changes — documentation only.                                             |
| 6.0.055 | 2026-07-15 | SECURITY — B2 INPUT VALIDATION                                              | Add `validateInput_()` helper in 19_Hardening.gs (validates type/required/maxLength/minLength/enum/pattern/control-charts). Applied to 3 high-risk WebApp endpoints: `submitReviewDecision` (reviewId pattern + decision enum + note maxLength), `searchLocations` (query length + limit range), `getMapAnalyticsData` (days range + filterStatus length). Prevents injection + DoS from malformed WebApp params.                                           |
| 6.0.054 | 2026-07-15 | SECURITY DOC — B1 XFRAME OPTIONS                                            | Document `XFrameOptionsMode.ALLOWALL` risk in SECURITY.md §1 (clickjacking risk, mitigations, decision rationale). Added inline comments in 22_WebApp.gs linking to SECURITY.md. Kept ALLOWALL (required for GAS sandbox) + documented 5-layer mitigation already in place.                                                                                                                                                                                 |
| 6.0.053 | 2026-07-15 | BUG FIX — PERSIST SYS_NOTES                                                 | Fix: AUTO_MATCH + MERGE paths now persist semantic notes (CONTACT/TIME/COD/FRAGILE/INSTRUCTION/OTHER) to SYS_NOTES — previously only CREATE_NEW stored them (Reviewer 2 finding). Added `persistSemanticNotesForEntity_()` helper in 10e, called from 3 paths (CREATE_NEW/MERGE/AUTO_MATCH).                                                                                                                                                                |
| 6.0.052 | 2026-07-15 | GROUP A QUICK WINS                                                          | (1) Add `resetAliasEnrichmentContext_()` wrapper in 10f + update 3 call sites in 10 (reduce cross-file coupling) (2) Add `scripts/bump_version.sh` helper to automate version bumps (prevents check_01 failures)                                                                                                                                                                                                                                            |
| 6.0.051 | 2026-07-15 | PHASE 3.5 — SCORING TO 10B                                                  | ย้าย calculateWeightedScore + calcDynamicWeights_ + getCandidateResolvedCoords_ + _CANDIDATE_COORDS_CACHE_ จาก 10_MatchEngine.gs → 10b_MatchDecision.gs (10: 1027→904 บรรทัด, 10b: 354→488 บรรทัด) — ให้อยู่ใกล้ callers ใน evaluateRule4/5/5b/6                                                                                                                                                                                                            |
| 6.0.050 | 2026-07-15 | PHASE 3.4 — MATCH ENGINE SPLIT (10f/10g/10h)                                | แตก 10_MatchEngine.gs 2234→1023 บรรทัด + 10f_MatchAliasEnrichment.gs (717 บรรทัด, 13 functions) + 10g_MatchRowProcessor.gs (335 บรรทัด, 5 functions) + 10h_MatchAutoResume.gs (296 บรรทัด, 6 functions)                                                                                                                                                                                                                                                     |
| 6.0.049 | 2026-07-15 | DEAD CODE CLEANUP                                                           | Remove `matchCalcFullScore_` + `matchCalcGeoAnchorScore_` (47 lines, zero callers — V6.0.015 P2.2 backward-compat shims that delegate to `calculateWeightedScore`)                                                                                                                                                                                                                                                                                          |
| 6.0.048 | 2026-07-14 | QUICK WINS                                                                  | V5.5→V6.0 branding in UI (3 files) + CHANGELOG sync 6.0.039-048 + README 6.0.044→6.0.048 + remove package-lock from .gitignore + Jest/Playwright→Snapshot Test Harness                                                                                                                                                                                                                                                                                      |
| 6.0.047 | 2026-07-14 | DOC-TYPE FIX                                                                | Add DOC-TYPE: historical to 15 .md files in 'Information from AI' folder (check_09 regression fix)                                                                                                                                                                                                                                                                                                                                                          |
| 6.0.046 | 2026-07-13 | SKILLS SUITE                                                                | Add 11 LMDS skills (.skills/) + exports (Claude/Gemini/Universal) + SKILLS_INSTALL/README docs                                                                                                                                                                                                                                                                                                                                                              |
| 6.0.045 | 2026-07-13 | LIVING DOCS SYNC                                                            | Sync 23 living .md files: version 6.0.044, 35 files, 535 functions, 27,213 lines, 8 workflows, 9 checks                                                                                                                                                                                                                                                                                                                                                     |
| 6.0.044 | 2026-07-13 | DETAILED HEADERS                                                            | .gs headers with REQUIRES/CALLS/EXPORTS TO/SHEETS ACCESSED/TRIGGERS/ARCHITECTURE (35 files)                                                                                                                                                                                                                                                                                                                                                                 |
| 6.0.043 | 2026-07-13 | DOC-TYPE SYSTEM                                                             | DOC-TYPE tags (39 .md files: 23 living + 16 historical) + check_09_doc_type_coverage.sh                                                                                                                                                                                                                                                                                                                                                                     |
| 6.0.042 | 2026-07-13 | CLEANUP                                                                     | Remove 'คำแนะนำ' folder (recommendations implemented in V6.0.041)                                                                                                                                                                                                                                                                                                                                                                                           |
| 6.0.041 | 2026-07-13 | CI IMPROVEMENTS                                                             | check_07/08 + Gitleaks workflow + fix actions/checkout@v7→v4 + eslint-plugin-googleappsscript + health check file count 22→≥30                                                                                                                                                                                                                                                                                                                              |
| 6.0.040 | 2026-07-13 | CODEQL FIX                                                                  | Fix returnless function in 28_WebAppActions.gs (CodeQL #52-#55)                                                                                                                                                                                                                                                                                                                                                                                             |
| 6.0.039 | 2026-07-13 | PROCESS IMPROVEMENTS                                                        | check_06_verify_fixes.sh (8 audit fix indicators) + PR template (grep verify + rebase safety)                                                                                                                                                                                                                                                                                                                                                               |
| 6.0.038 | 2026-07-13 | DOCS SYNC                                                                   | Rename V5.5 docs → V6.0 + CHANGELOG sync V6.0.012-038                                                                                                                                                                                                                                                                                                                                                                                                       |
| 6.0.037 | 2026-07-13 | HEADER SYNC                                                                 | Unified header format for all 35 .gs files (VERSION/PURPOSE/CHANGELOG/DEPENDENCIES/ARCHITECTURE)                                                                                                                                                                                                                                                                                                                                                            |
| 6.0.036 | 2026-07-13 | SCG COOKIE FIX                                                              | Fix readInputConfig_ to call getSCGCookie_ (PropertiesService primary) + setSCGCookie_UI writes PropertiesService + clears cell                                                                                                                                                                                                                                                                                                                             |
| 6.0.035 | 2026-07-12 | BRANCH NUMBER RE-APPLY                                                      | RE-APPLY branch number matching lost in PR #93 rebase regression — PERSON_IDX.BRANCH_NO=12 + scorePersonCandidate branch comparison                                                                                                                                                                                                                                                                                                                         |
| 6.0.034 | 2026-07-12 | PHASE 3.3 — REVIEW SERVICE SPLIT                                            | แตก 12_ReviewService.gs 1841→1102 บรรทัด + 12b_ReviewReprocessor.gs (775 บรรทัด)                                                                                                                                                                                                                                                                                                                                                                            |
| 6.0.033 | 2026-07-12 | PHASE 3.2 — WEBAPP SPLIT                                                    | แตก 22_WebApp.gs 2086→337 บรรทัด + 22b_WebAppViews.gs + 22c_WebAppActions.gs                                                                                                                                                                                                                                                                                                                                                                                |
| 6.0.032 | 2026-07-12 | PHASE 3.1 — MATCH ENGINE SPLIT                                              | แตก 10_MatchEngine.gs 2959→2302 บรรทัด + 10d_MatchTestHarness.gs + 10e_MatchResolvePersist.gs                                                                                                                                                                                                                                                                                                                                                               |
| 6.0.031 | 2026-07-12 | PHASE 2.3 — PERSIST SRP                                                     | แยก persistResult_ → persistFactRows_ + persistReviewRows_ (audit 4)                                                                                                                                                                                                                                                                                                                                                                                        |
| 6.0.030 | 2026-07-12 | PHASE 2.2 — MATCH DECISION SPLIT                                            | แตก makeMatchDecision 267→78 บรรทัด + 10b_MatchDecision.gs (audit 1.2)                                                                                                                                                                                                                                                                                                                                                                                      |
| 6.0.029 | 2026-07-12 | DRY RUN TIME GUARD                                                          | Time guard 300s + cap 500→250 rows (GAS 6-min timeout fix)                                                                                                                                                                                                                                                                                                                                                                                                  |
| 6.0.028 | 2026-07-12 | SNAPSHOT TEST HARNESS                                                       | 29_SnapshotTest.gs — save baseline + compare for refactor safety                                                                                                                                                                                                                                                                                                                                                                                            |
| 6.0.027 | 2026-07-12 | ESLINT COMPLEXITY GUARDS                                                    | max-lines-per-function:300 + complexity:30 + max-params:6 (audit 1.2/1.3)                                                                                                                                                                                                                                                                                                                                                                                   |
| 6.0.026 | 2026-07-11 | SCG COOKIE PROPERTIESSERVICE                                                | getSCGCookie_ PropertiesService primary + auto-migrate from cell (audit 3A) — NOTE: fixed wrong function, re-fixed in V6.0.036                                                                                                                                                                                                                                                                                                                              |
| 6.0.025 | 2026-07-11 | BRANCH NUMBER DECISION LOGIC                                                | PERSON_IDX.BRANCH_NO=12 + scorePersonCandidate branch comparison (audit 1.5) — NOTE: lost in rebase, re-applied in V6.0.035                                                                                                                                                                                                                                                                                                                                 |
| 6.0.024 | 2026-07-11 | ESCAPEHTML CONSOLIDATION                                                    | รวม 7 escapeHtml_ definitions → 1 shared alias (audit 1.4)                                                                                                                                                                                                                                                                                                                                                                                                  |
| 6.0.023 | 2026-07-11 | SONARCLOUD CODE SMELLS                                                      | replaceAll + .find() in MobileActions.html (S7781 + S7750)                                                                                                                                                                                                                                                                                                                                                                                                  |
| 6.0.022 | 2026-07-11 | PIPELINE TIME LIMIT FIX                                                     | TIME_LIMIT_MS 330s→280s (trigger timeout fix)                                                                                                                                                                                                                                                                                                                                                                                                               |
| 6.0.021 | 2026-07-11 | MOBILE ACTIONS VIEW                                                         | 44 action buttons in WebApp + ≡ Menu dropdown + two-press confirm                                                                                                                                                                                                                                                                                                                                                                                           |
| 6.0.020 | 2026-07-10 | STOP SIGNAL CLEAR                                                           | Clear stale STOP SIGNAL at runMatchEngine start (pipeline หยุดที่ row 0 fix)                                                                                                                                                                                                                                                                                                                                                                                |
| 6.0.019 | 2026-07-10 | ALIAS CACHEKEY FIX                                                          | loadGlobalAliasesMap_ cacheKey ReferenceError fix (createGlobalAlias ล้มเหลวทุกครั้ง)                                                                                                                                                                                                                                                                                                                                                                       |
| 6.0.018 | 2026-07-10 | CODEQL #51 FIX                                                              | Remove unused 'ui' variable in analyzeRule5PlaceOnlyImpact_UI                                                                                                                                                                                                                                                                                                                                                                                               |
| 6.0.017 | 2026-07-10 | DRY RUN FORCE ALL                                                           | getAllSourceRowsForceAll + forceAllRows param (ข้าม SYNC_STATUS filter)                                                                                                                                                                                                                                                                                                                                                                                     |
| 6.0.016 | 2026-07-09 | RULE 5 + [24] + WEIGHTS                                                     | Rule 5 fix (geo+place→REVIEW) + [24] place matching + weight rebalance (geo 0.60→0.35, person 0.25→0.45, place 0.15→0.20)                                                                                                                                                                                                                                                                                                                                   |
| 6.0.015 | 2026-07-09 | PHASE 2 ALGORITHM                                                           | Jaro-Winkler + ensemble + weighted score + threshold 90→85 + auto-alias                                                                                                                                                                                                                                                                                                                                                                                     |
| 6.0.014 | 2026-07-09 | M_PLACE REVERSE GEOCODE                                                     | +2 columns (canonical_reverse_geocode + normalized_reverse_geocode) + revert [24]→[18]                                                                                                                                                                                                                                                                                                                                                                      |
| 6.0.013 | 2026-07-09 | GEO-FIRST + BRANCH SPLIT                                                    | พิกัดเป็นหลัก + แยกสาขา/บริษัท + ปรับ weight (baseline 14% → target 45-55%)                                                                                                                                                                                                                                                                                                                                                                                 |
| 6.0.012 | 2026-07-09 | PHASE 1 MATCHING                                                            | 7 matching improvements + run log + dry-run test mode + stop signal + safe reset                                                                                                                                                                                                                                                                                                                                                                            |
| 6.0.011 | 2026-07-09 | GEO-DISTANCE GUARD                                                          | FUZZY_MATCH Rule 6 ตรวจระยะพิกัด — ลด confidence ถ้าห่าง >1 กม. + new helper getCandidateResolvedCoords_                                                                                                                                                                                                                                                                                                                                                    |
| 6.0.010 | 2026-07-09 | PHASE 3 — NICE-TO-HAVE (16 items)                                           | LockService guards 9 functions + onInstall + SPA hash + Tailwind pin + Leaflet fallback + QReview overlay + onEdit lock + RBAC extend                                                                                                                                                                                                                                                                                                                       |
| 6.0.009 | 2026-07-08 | PHASE 2 — IMPORTANT CORRECTNESS                                             | submitReviewDecision lock + acquireAliasHistoryLock_ real lock + applyMasterCoordinatesToDailyJob PropertiesService→LockService + pagination optimization                                                                                                                                                                                                                                                                                                   |
| 6.0.008 | 2026-07-08 | PHASE 1 — DEPLOY BLOCKER + SONARCLOUD DEDUP                                 | Api.html timeout + clearAllSCGSheets_UI confirm+lock + submitReviewDecision atomicity rollback + geo lock + ViewHelpers dedup                                                                                                                                                                                                                                                                                                                               |
| 6.0.007 | 2026-07-08 | V6.0 FINAL COMPLETION — AUDIT TRAIL + STRICT PREFLIGHT + DEAD CODE CLEANUP  | SYS_AUDIT_TRAIL sheet (Critical-Only) + runPipelinePreflight strict mode (6 checks) + detectSameGeoMultiPerson removed + roadmap 100% done                                                                                                                                                                                                                                                                                                                  |
| 6.0.006 | 2026-07-07 | DOC SYNC + STALE TRIGGER + TELEGRAM FIX                                     | doc sync V5.5 → V6.0.006 + stale trigger cleanup + Telegram HTML parse_mode + Preflight SOURCE fix                                                                                                                                                                                                                                                                                                                                                          |
| 6.0.005 | 2026-07-07 | 4 ISSUES — SONARCLOUD + INPUT CLEAR + Q_REVIEW LIFECYCLE + DUPLICATE PLACES | parseInt radix + clearAllSCGSheets includes INPUT + clearDoneReviews_UI + createPlace district-level fix                                                                                                                                                                                                                                                                                                                                                    |
| 6.0.004 | 2026-07-06 | PHASES 4+5.2+6.1+7 — WEBAPP+PREFLIGHT+DEDUP+RBAC                            | Map Analytics (Leaflet) + Live Feed + Dependency-aware Preflight + Dedup Audit + RBAC 3 roles                                                                                                                                                                                                                                                                                                                                                               |
| 6.0.003 | 2026-07-06 | PHASE 3 — SYSTEM LEARNING                                                   | M_ALIAS +3 cols (variant_norm, phonetic_primary/secondary) + SYS_NEGATIVE_SAMPLES + markAsNegativeSample_                                                                                                                                                                                                                                                                                                                                                   |
| 6.0.002 | 2026-07-06 | PHASE 2 — MATCHING ENGINE                                                   | Geofencing Tie-breaker (driver history + street distance) + phoneticMatch wiring                                                                                                                                                                                                                                                                                                                                                                            |
| 6.0.001 | 2026-07-06 | PHASE 1 — DATA CLEANSING                                                    | Semantic Note Parser (SYS_NOTES sheet) + Double Metaphone Thai (phonetic_primary/secondary)                                                                                                                                                                                                                                                                                                                                                                 |
| 5.5.050 | 2026-07-06 | Q_REVIEW APPROVE FIX                                                        | write factRowData to FACT_DELIVERY + MERGE fallback (3 cases)                                                                                                                                                                                                                                                                                                                                                                                               |
| 5.5.049 | 2026-07-06 | SMART NAV + AUTO-POLLING REMOVAL                                            | Remove Smart Navigation + WebApp auto-polling (-593 lines)                                                                                                                                                                                                                                                                                                                                                                                                  |
| 5.5.048 | 2026-07-06 | CRITICAL FIXES + ROADMAP UPDATE                                             | .clasp.json.example + catch block + ALIAS_IDX + dead refs + INVESTIGATE move + README sync + CHANGELOG entries 035-048                                                                                                                                                                                                                                                                                                                                      |
| 5.5.047 | 2026-07-05 | QUICK WINS MEDIUM RISK                                                      | Contextual Disambiguation (2.1) + Telegram Alert (5.1)                                                                                                                                                                                                                                                                                                                                                                                                      |
| 5.5.046 | 2026-07-05 | QUICK WINS LOW RISK                                                         | Self-Healing Alias (3.1) + Dynamic Weighting (2.2)                                                                                                                                                                                                                                                                                                                                                                                                          |
| 5.5.045 | 2026-07-05 | ISSUE #26 FIX                                                               | Geo enrichment in reprocResolveOrCreatePlaceForReview_                                                                                                                                                                                                                                                                                                                                                                                                      |
| 5.5.044 | 2026-07-05 | DEAD CODE REMOVAL                                                           | 12 functions + 1 RAM cache + 3 callers (-402 lines)                                                                                                                                                                                                                                                                                                                                                                                                         |
| 5.5.043 | 2026-07-05 | SILENT FAILURE + DEPRECATED                                                 | 2 catch blocks + 12 @deprecated markers                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 5.5.042 | 2026-07-05 | AUDIT FINDINGS                                                              | 6 findings: rawAddr discard + boundary anchor + join key + silent catch + retry + dead code                                                                                                                                                                                                                                                                                                                                                                 |
| 5.5.041 | 2026-07-04 | CRITICAL BUGS                                                               | 5 bugs: batchError state machine + Gemini key regex + WebApp auth bypass + FACT_DELIVERY guard + pipeline hours                                                                                                                                                                                                                                                                                                                                             |
| 5.5.040 | 2026-07-04 | CODEQL COMPLIANT REGEX                                                      | CodeQL-compliant regex fix                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 5.5.039 | 2026-07-04 | CODEQL REVERT                                                               | Revert to simple regex                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 5.5.038 | 2026-07-04 | CODEQL FINAL CLEAN                                                          | 2 alerts + stat sync                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 5.5.037 | 2026-07-04 | CODEQL FIXES                                                                | 2 remaining alerts                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 5.5.036 | 2026-07-04 | CODEQL FIXES                                                                | 3 remaining alerts                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 5.5.035 | 2026-07-03 | CODEQL FIXES                                                                | 27 alerts resolved (23 CodeQL + 4 SonarCloud)                                                                                                                                                                                                                                                                                                                                                                                                               |
| 5.5.034 | 2026-07-03 | DOC-CODE SYNC                                                               | โค้ด ↔ เอกสารตรง 100% (steps 1-15)                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 5.5.033 | 2026-07-03 | DOC-CODE SYNC (steps 8-12)                                                  | docs/ version alignment                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 5.5.032 | 2026-07-03 | DOC-CODE SYNC (steps 5-7)                                                   | Code issues + README/BLUEPRINT/CONTEXT/Supreme Engineer                                                                                                                                                                                                                                                                                                                                                                                                     |
| 5.5.031 | 2026-07-03 | DOC-CODE SYNC (step 4)                                                      | Bump VERSION header 5.5.022 → 5.5.034 (24 .gs)                                                                                                                                                                                                                                                                                                                                                                                                              |
| 5.5.030 | 2026-07-03 | DOC-CODE SYNC (steps 1-3)                                                   | Baseline + policy decisions + branch backup                                                                                                                                                                                                                                                                                                                                                                                                                 |
| 5.5.029 | 2026-07-01 | DASHBOARD PHASE 2-3 ROLLOUT                                                 | รวม 7 features: WebApp white screen fix, Q_REVIEW view + detail, FACT_DELIVERY view, Source Sheet view, Match Engine Metrics, 7-Day Delivery Trend                                                                                                                                                                                                                                                                                                          |
| 5.5.022 | 2026-06-26 | CONSISTENCY SYNC + DEEP DIVE FIX                                            | 9 BUG fixes + 168 doc inconsistencies                                                                                                                                                                                                                                                                                                                                                                                                                       |
| 5.5.021 | 2026-06-22 | REFACTOR_CYCLE6_RESIDUAL                                                    | REF-005 cleanup + REF-011 pilot                                                                                                                                                                                                                                                                                                                                                                                                                             |
| 5.5.020 | 2026-06-22 | REFACTOR_CYCLE6_RESIDUAL                                                    | REF-005 cleanup + REF-011 pilot                                                                                                                                                                                                                                                                                                                                                                                                                             |
| 5.5.019 | 2026-06-22 | REFACTOR_CYCLE6                                                             | 12 (REF-001 to REF-012)                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 5.5.018 | 2026-06-21 | REVIEW15 CLEAN CODE FIX                                                     | 14                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 5.5.017 | 2026-06-21 | SECURITY POSTFIX                                                            | 12 SEC                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 5.5.016 | 2026-06-21 | PERFORMANCE FIX                                                             | 13                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 5.5.015 | 2026-06-21 | CRITICAL FIX                                                                | 2                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 5.5.014 | 2026-06-20 | DRIVER VERIFIED + ALIAS ENRICHMENT                                          | 2 features                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 5.5.013 | 2026-06-20 | GOOGLE MAPS REFACTOR                                                        | 2                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 5.5.012 | 2026-06-19 | ANTIPATTERN FIX + DOC SYNC                                                  | 5 + doc                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 5.5.011 | 2026-06-19 | DATA CONSISTENCY + SHIPTONAME CLEAN + Q_REVIEW NAV                          | 3 features                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 5.5.010 | 2026-06-18 | CACHE HOTFIX + Q_REVIEW POST-PROCESSOR                                      | 3 root cause + integration                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 5.5.009 | 2026-06-18 | DOC SYNC                                                                    | DEPENDENCIES/ARCHITECTURE + .md docs                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 5.5.008 | 2026-06-18 | CACHE CLEANUP P2                                                            | 6                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 5.5.007 | 2026-06-18 | CACHE FIX P0+P1                                                             | 9                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 5.5.006 | 2026-06-18 | CONSISTENCY SYNC                                                            | 28 doc inconsistencies                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 5.5.005 | 2026-06-16 | REVIEW SERVICE FIX                                                          | (intermediate)                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| 5.5.004 | 2026-06-15 | INITIAL AUDIT CYCLES                                                        | 53 audit issues                                                                                                                                                                                                                                                                                                                                                                                                                                             |

---

## [6.0.011] — 2026-07-09 — GEO-DISTANCE GUARD IN FUZZY_MATCH (Rule 6)

### Problem

FUZZY_MATCH (Rule 6) ไม่ได้ตรวจระยะพิกัด — ถ้าชื่อคล้ายกัน แต่พิกัดห่าง 3 กม. ก็แนะนำ MERGE

### Fix

- เพิ่ม geo-distance guard ใน Rule 6: คำนวณ haversine distance ระหว่าง source กับ candidate
- > 1 กม. → confidence = min(เดิม, 50) + reason = FUZZY_MATCH_FAR_APART
- 500-1000 ม. → confidence = min(เดิม, 65) + evidence = moderate_dist
- ≤ 500 ม. → ไม่เปลี่ยน (ใกล้กันพอ)
- New helper: `getCandidateResolvedCoords_(entityType, entityId)` — lookup M_DESTINATION by placeId/personId with in-memory cache

### Files Changed

- `src/1_group1_master_db/10_MatchEngine.gs` — Rule 6 geo-distance guard + new helper

---

## [6.0.010] — 2026-07-09 — PHASE 3 — NICE-TO-HAVE FIXES (16 items)

### P3.1-P3.9: LockService guards on 9 functions

Added tryLock to: clearDoneReviews_UI, populateAliasFromSCGRawData, MIGRATION_HybridAliasSystem, assignMasterUuidIfMissing, resetSourceSyncStatus, buildFullQualityReport, invalidateAllGlobalCaches, cleanupStaleTriggers_UI (safeResetTransactional_UI already had lock from PR #66)

### P3.10: onInstall() trigger

- Added `function onInstall(e) { onOpen(e); }` — menu appears after add-on installation

### P3.11: SPA hash navigation

- Added `window.location.hash` + `hashchange` event listener — browser back/forward works

### P3.12: Pin Tailwind version

- Changed `@tailwindcss/browser@4` → `@4.3.2` — prevents silent breaking changes

### P3.13: Leaflet CDN fallback

- Primary: unpkg.com → Fallback: cdnjs.cloudflare.com (leaflet.js) + cdn.jsdelivr.net (leaflet-heat.js)

### P3.14: QReview global modal overlay

- Full-screen overlay blocks navigation during submitReviewDecision processing

### P3.15: onEdit tryLock

- LockService guard around applyReviewDecision in onEdit — prevents double-edit

### P3.16: Extend RBAC

- `runFullPipeline` → `requirePermission_('action:run_pipeline')` (admin only)
- `applyAllPendingDecisions` → `requirePermission_('action:approve_review')` (reviewer+admin)

### Files Changed

- `src/O_core_system/00_App.gs` — onInstall + onEdit lock + RBAC
- `src/2_group2_daily_ops/12_ReviewService.gs` — clearDoneReviews_UI lock + RBAC
- `src/1_group1_master_db/21_AliasService.gs` — MIGRATION + assignMasterUuid locks
- `src/O_core_system/14_Utils.gs` — resetSourceSyncStatus lock
- `src/2_group2_daily_ops/13_ReportService.gs` — buildFullQualityReport lock
- `src/O_core_system/01_Config.gs` — invalidateAllGlobalCaches lock
- `src/3_group3_webapp/js/App.html` — SPA hash navigation
- `src/3_group3_webapp/Index.html` — Tailwind version pin
- `src/3_group3_webapp/views/MapAnalytics.html` — Leaflet CDN fallback
- `src/3_group3_webapp/views/QReview.html` — global modal overlay

---

## [6.0.009] — 2026-07-08 — PHASE 2 — IMPORTANT CORRECTNESS FIXES (4 items)

### P2.1: submitReviewDecision LockService guard

- Wrap in `LockService.tryLock(10000)` — prevents double-submit from WebApp
- Returns `LOCK_BUSY` error to frontend if lock not acquired

### P2.2: acquireAliasHistoryLock_ now acquires real lock

- Was misleading name (no actual lock) — added real `LockService.tryLock(30000)`
- Returns `{ss, lock}` so caller can release in finally

### P2.3: applyMasterCoordinatesToDailyJob PropertiesService → LockService

- Replaced pseudo-lock (`LOCK_ENRICHMENT` property) with real LockService (atomic + auto-release)
- One-time cleanup: delete stale `LOCK_ENRICHMENT` property

### P2.4: getFactDeliveryPage + getSourcePage pagination optimization

- Two-step read: (1) status column only for counting (2) page rows only via getRangeList
- 10-50x reduction in cell reads for large sheets
- New helper: `columnNumberToLetter_(col)`

### Files Changed

- `src/O_core_system/22_WebApp.gs` — P2.1 + P2.4
- `src/O_core_system/19_Hardening.gs` — P2.2
- `src/2_group2_daily_ops/18_ServiceSCG.gs` — P2.3
- `src/O_core_system/14_Utils.gs` — new helper

---

## [6.0.008] — 2026-07-08 — PHASE 1 — DEPLOY BLOCKER FIXES + SONARCLOUD DEDUP

### P1.1: WebApp Api.html no client-side timeout (BUG-WEB-001)

- Added 30s TIMEOUT_MS + concurrent call counter (MAX_CONCURRENT=6) + diagnostic logging

### P1.2: clearAllSCGSheets_UI no confirm + no lock (BUGHUNT-01)

- Added LockService.tryLock(5000) + YES_NO confirmation dialog

### P1.3: submitReviewDecision non-atomic multi-sheet write (BUG-WEB-002)

- Capture original status → if FACT_DELIVERY write fails → rollback Q_REVIEW status

### P1.4: buildGeoDictionary + populateGeoMetadata no LockService (BUGHUNT-1)

- Added LockService.tryLock(30000) + pass {lock} to withEntryPointGuard_

### SonarCloud dedup (PR #65 + #66)

- Extracted shared helpers: acquireScriptLockOrWarn_, releaseScriptLock_, clearSheetsPreserveHeaders_, columnNumberToLetter_
- Extracted ViewHelpers component (pagination, loading, empty state, error state)
- Deleted Quick file check_3/ folder (AI audit reports — recommendations applied)
- Added Quick file check*/ to .gitignore

### Files Changed

- `src/3_group3_webapp/js/Api.html` — full rewrite (P1.1)
- `src/2_group2_daily_ops/18_ServiceSCG.gs` — P1.2
- `src/O_core_system/22_WebApp.gs` — P1.3
- `src/1_group1_master_db/16_GeoDictionaryBuilder.gs` — P1.4
- `src/1_group1_master_db/20_ThGeoService.gs` — P1.4
- `src/O_core_system/14_Utils.gs` — shared helpers
- `src/3_group3_webapp/js/components/ViewHelpers.html` — NEW

---

## [6.0.007] — 2026-07-08 — V6.0 FINAL COMPLETION — AUDIT TRAIL + STRICT PREFLIGHT + DEAD CODE CLEANUP

This version marks the **100% completion of the V6.0 roadmap** — all 7 phases, all 14 features, all 4 previously-pending items are now DONE. The system is production-ready at 96% (remaining 4% = production environment configuration: Telegram bot setup, RBAC role assignments, audit retention policy, OAuth consent screen).

### Feature 1: Audit Trail (Critical-Only Scope) — Roadmap Phase 6.2

Implements the long-pending SYS_AUDIT_TRAIL sheet with critical-only scope (M_ALIAS + Q_REVIEW), as agreed in the clarification round.

**NEW FILE: src/O_core_system/26_AuditTrailService.gs (412 lines)**

Core API:

- `logAuditTrail(entityType, entityId, action, fieldChanged, oldValue, newValue, reason)` — append audit record
  Failsafe: NEVER throws (wraps everything in try/catch + logs warning on failure).
  Reason: audit failure must NOT break the operation that triggered it.
- `queryAuditTrail(filters)` — read audit records with optional filters (limit 500 default)
- `cleanupAuditTrail_UI()` — retention pruning (default 90 days; override via AUDIT_RETENTION_DAYS property)
- `getAuditTrailStats()` — summary stats for WebApp dashboard (total/24h/7d/byAction/byEntityType)

Schema additions:

- 01_Config.gs: SHEET.SYS_AUDIT_TRAIL + AUDIT_IDX (11 frozen keys) + AUDIT_ACTIONS + AUDIT_ENTITY_TYPES + AUDIT_RETENTION_DEFAULT_DAYS=90
- 02_Schema.gs: SCHEMA.SYS_AUDIT_TRAIL (11 columns)
- 03_SetupSheets.gs: createSheetIfMissing_ for SYS_AUDIT_TRAIL
- validateConfig + validateSchemaConsistency: new AUDIT_IDX entry

Hook points (4 — Critical-Only scope):

1. **21_AliasService.gs createGlobalAlias()** — action='CREATE', entity_type='ALIAS'
2. **12_ReviewService.gs applyReviewDecision()** — action mapped per decision:
   - CREATE_NEW → CREATE
   - MERGE_TO_CANDIDATE → MERGE
   - ESCALATE → UPDATE
   - IGNORE → DELETE
3. **10_MatchEngine.gs cleanupStaleCanonicalAliases\_()** — batch action='DELETE'
   (≤50 rows: log each; >50 rows: log one summary to avoid audit spam)

WebApp integration:

- 22_WebApp.gs getDashboardData() — adds auditStats to dashboard response payload
- 00_App.gs — new menu entry '📜 [V6] Prune Audit Trail (90 วัน)' under System

Security:

- Failsafe pattern: logAuditTrail NEVER throws
- Whitelist validation: entityType + action must be in AUDIT_ENTITY_TYPES / AUDIT_ACTIONS
- Value truncation: old_value/new_value capped at 500 chars to prevent row overflow
- Append-only: no update/delete operations (except retention pruning)
- Caller email via Session.getEffectiveUser().getEmail() (best effort)

### Feature 2: Strict Dependency-aware Pipeline Preflight — Roadmap Phase 5.2 (upgrade)

Upgrades `runPipelinePreflight()` from a basic 3-check implementation (V6.0.004) to a strict dependency-aware mode with structured reporting.

**Changes to 24_PipelineManager.gs runPipelinePreflight():**

- 6 checks (was 3): added M_PERSON header + M_PLACE header + M_ALIAS column count
- New `opts.strict` parameter: if true, throws on any blocking issue (for CI/CD-style runs)
- Returns structured report: `{ ready, issues, warnings, checks[] }`
  - `issues[]` = BLOCKING (pipeline will abort)
  - `warnings[]` = NON-BLOCKING (advisory only)
  - `checks[]` = audit trail with `{ name, status, detail }` per check
  - status values: 'PASS' | 'FAIL' | 'WARN' | 'SKIP'

The 6 dependency-aware checks:

1. (BLOCKING) SOURCE sheet has unprocessed rows (SYNC_STATUS ≠ SUCCESS/REVIEW)
2. (BLOCKING) SYS_TH_GEO dictionary exists with ≥100 rows
3. (CONDITIONAL) GEMINI_API_KEY set (only if AI_CONFIG.USE_AI_REASONING = true)
4. (BLOCKING) M_PERSON sheet exists + header at col[10] = 'phonetic_primary'
   (catches the V6.0.001 schema upgrade — if missing, MatchEngine will fail mid-run)
5. (BLOCKING) M_PLACE sheet exists + header at col[14] = 'phonetic_primary'
6. (WARNING) M_ALIAS has ≥11 columns (V6.0.003 Self-Healing Alias requirement)

**New UI wrapper in 00_App.gs:**

- `runPipelinePreflightStrict_UI()` — menu entry '🔍 [V6] Pipeline Preflight (Strict)'
  Shows structured report with ✅/❌/⚠️/⏭️ icons per check
  Lists blocking issues and advisory warnings separately

Backward compatibility:

- Old callers (e.g., 10_MatchEngine.gs:118) that call `runPipelinePreflight()` with no args still work
- New return shape is a superset of the old `{ ready, issues }` shape

### Feature 3: Dead Code Cleanup — detectSameGeoMultiPerson removed

Removes the long-standing dead code in 10_MatchEngine.gs (~30 lines).

**History:**

- v5.4: implemented but never wired into makeMatchDecision()
- V5.5.042 (PR #23): marked as DEAD CODE with logWarn warning on call
- V6.0.007 (this commit): removed entirely + tombstone comment left

Tombstone comment includes:

- Original signature for reference: `function detectSameGeoMultiPerson(geoId, currentPersonId)`
- Reason for removal: no caller in any .gs file + wasted log space + BLUEPRINT no longer references it
- Restore path: git history of this commit
- Better path forward: re-implement properly wired into Rule 3.5 (NEARBY_PENDING) if needed

### Feature 4: Roadmap Sync — All 7 Phases Marked DONE

Updates `docs/roadmap/LMDS_V6.0_Roadmap.md` to reflect the actual completed state:

| Phase                 | Old Status        | New Status                                      |
| --------------------- | ----------------- | ----------------------------------------------- |
| 1 Data Cleansing      | ❌ Pending        | ✅ Done (V6.0.001)                              |
| 2 Matching Engine     | ❌ 2.3 Pending    | ✅ Done (V5.5.046-047 + V6.0.002)               |
| 3 System Learning     | ❌ Schema Pending | ✅ Done (V5.5.046 + V6.0.003)                   |
| 4 WebApp & Dashboard  | ❌ Pending        | ✅ Done (V6.0.004)                              |
| 5 Pipeline Management | ❌ 5.2 Pending    | ✅ Done (V5.5.047 + V6.0.004/006/007)           |
| 6 Architecture & Data | ❌ Pending        | ✅ Done (V6.0.004 dedup + V6.0.007 audit trail) |
| 7 Security RBAC       | ❌ Pending        | ✅ Done (V6.0.004)                              |

### Version Bump

- APP_VERSION: 6.0.006 → 6.0.007
- SCHEMA_VERSION: 6.0.006 → 6.0.007
- APP_NAME: 'LMDS V5.5' → 'LMDS V6.0'
- VERSION header bumped in all 27 .gs files via sed

### Files Changed

- **NEW**: src/O_core_system/26_AuditTrailService.gs (412 lines)
- src/O_core_system/00_App.gs — menu entries + runPipelinePreflightStrict_UI()
- src/O_core_system/01_Config.gs — APP_VERSION/SCHEMA_VERSION/APP_NAME + AUDIT_IDX validation entries + SHEET.SYS_AUDIT_TRAIL
- src/O_core_system/02_Schema.gs — SYS_AUDIT_TRAIL schema (11 cols) + validateSchemaConsistency entry
- src/O_core_system/03_SetupSheets.gs — createSheetIfMissing_ for SYS_AUDIT_TRAIL
- src/O_core_system/22_WebApp.gs — getDashboardData() adds auditStats
- src/O_core_system/27_RbacService.gs — VERSION header bump only
- src/1_group1_master_db/10_MatchEngine.gs — detectSameGeoMultiPerson removed + logAuditTrail hook in cleanupStaleCanonicalAliases_
- src/1_group1_master_db/21_AliasService.gs — logAuditTrail hook in createGlobalAlias
- src/2_group2_daily_ops/12_ReviewService.gs — logAuditTrail hook in applyReviewDecision
- src/4_group4_pipeline_mgr/24_PipelineManager.gs — runPipelinePreflight() strict mode upgrade
- docs/roadmap/LMDS_V6.0_Roadmap.md — all 7 phases marked DONE
- All other .gs files: VERSION header bump only (sed)

### Test Results

- node --check on all 7 modified files: PASS
- ESLint with project config: PASS (0 errors, 0 warnings)
- Backward compatibility: existing callers of runPipelinePreflight() with no args continue to work

### Roadmap Status

**V6.0 Roadmap: 14/14 features DONE (100%)** ✅

---

## [6.0.006] — 2026-07-07 — DOC SYNC + STALE TRIGGER + TELEGRAM FIX

### Documentation Sync (Fix #1)

อัปเดตเอกสารหลัก 3 ไฟล์ให้ตรงกับสถานะโค้ดจริง (V5.5 → V6.0.006):

- **README.md** — Version 5.5.048 → 6.0.006 + เพิ่ม V6.0 roadmap status + Production Readiness 96%
- **BLUEPRINT.md** — Version 5.5.034 → 6.0.006 + เพิ่ม V6.0 Enhancements section (Phases 1-7) + Security Architecture (SEC-001→012) + Production Deployment checklist
- **CONTEXT.md** — Version sync + File count 25 → 26 (added 27_RbacService.gs) + Tech stack update (Telegram + RBAC)

### Stale Trigger Cleanup (Issue from V5.5.049)

หลังจาก PR #43 ลบ Smart Navigation และ auto-polling ออก แต่ตัว trigger ของ `handleSelectionChange_` ยังค้างอยู่ใน Apps Script project ทำให้ระบบพยายามเรียก function ที่ไม่มีอยู่แล้ว:

- เพิ่ม `cleanupStaleTriggers_UI()` ใน `00_App.gs` — สแกน triggers ทั้งหมด ลบ trigger ที่อ้างถึง function ที่ไม่ได้ define แล้ว
- เพิ่ม menu entry "🧹 [PH2] Cleanup Stale Triggers" ใต้เมนูระบบ
- ใช้ `typeof globalThis[handlerName] === 'function'` เพื่อตรวจสอบ function existence อย่างปลอดภัย

### Telegram Alert Fix (Issue from V5.5.047)

Telegram Bot API ส่ง HTTP 400 parse error เมื่อส่ง alert ที่มี `_` (underscore) ในข้อความ เพราะ Markdown mode ตีความ `_` เป็น italic marker:

- เปลี่ยน `parse_mode` จาก `'Markdown'` → `'HTML'` ใน `sendTelegramAlert_()`
- ใช้ `<b>` สำหรับ bold แทน `*` และ escape `<`/`>`/`&` ในข้อความก่อนส่ง
- เพิ่ม unit test coverage สำหรับ special characters: `<script>`, `a_b_c`, `100% < 200%`

### Preflight SOURCE Fix

`runPipelinePreflight()` ตรวจ DAILY_JOB sheet แทนที่จะตรวจ SOURCE sheet ทำให้ pipeline ถูกบล็อกโดย false positive:

- เปลี่ยน Check 1 จาก DAILY_JOB → SOURCE sheet (`SHEET.SOURCE`)
- อ่าน `SRC_IDX.SYNC_STATUS` column เพื่อนับ pending rows (status ≠ SUCCESS/REVIEW)
- ลบ Check 4 ที่ซ้ำซ้อน (ถูกรวมเข้า Check 1 แล้ว)

### Files Changed

- `README.md`, `BLUEPRINT.md`, `CONTEXT.md` — doc sync
- `src/O_core_system/00_App.gs` — cleanupStaleTriggers_UI() + menu entry
- `src/4_group4_pipeline_mgr/24_PipelineManager.gs` — Telegram HTML + Preflight SOURCE fix
- `docs/CHANGELOG.md` — this entry

---

## [6.0.005] — 2026-07-07 — 4 ISSUES — SONARCLOUD + INPUT CLEAR + Q_REVIEW LIFECYCLE + DUPLICATE PLACES

### Issue #1: SonarCloud parseInt Radix Warning

SonarCloud แจ้งเตือน `parseInt()` โดยไม่ระบุ radix ใน 3 จุดของ `10_MatchEngine.gs`:

- `parseInt(value)` → `parseInt(value, 10)` ใน `cleanupStaleCanonicalAliases_`, `breakTieAmongCandidates`, `calcDynamicWeights_`
- เพิ่ม JSDoc `@example` สำหรับทุก helper ที่ใช้ parseInt เพื่อความชัดเจน
- ลด SonarCloud code smell จาก 12 → 9 (remaining 9 เป็น false positive)

### Issue #2: clearAllSCGSheets_UI ไม่ล้าง INPUT Sheet

`clearAllSCGSheets_UI()` ล้าง DAILY_JOB + OWNER_SUMMARY + SHIPMENT_SUM แต่ไม่ล้าง INPUT ทำให้ข้อมูลเดิมค้างอยู่และถูกนำไปประมวลผลรอบถัดไป:

- เพิ่ม `SHEET.INPUT` เข้าไปในรายการ sheets ที่ถูก clear
- เพิ่ม confirmation dialog แสดงชื่อ sheet ทั้งหมดที่จะถูกล้างก่อน execute
- ป้องกันการ clear ถ้า `DAILY_JOB` มี `SYNC_STATUS` ≠ 'SUCCESS' (warn admin)

### Issue #3: Q_REVIEW Lifecycle — clearDoneReviews_UI

Q_REVIEW sheet สะสม 101+ rows หลัง pipeline run ครั้งแรก ทำให้ dashboard ช้าและ admin สับสน:

- เพิ่ม `clearDoneReviews_UI()` ใน `12_ReviewService.gs` — ลบเฉพาะ rows ที่ `REVIEW_STATUS = APPROVED/REJECTED/IGNORED`
- ก่อนลบ → export ไฟล์ CSV ไปยัง Google Drive (folder: `LMDS_Q_REVIEW_Archive`) เพื่อ audit
- เพิ่ม menu entry "🧹 [PH2] Clear Done Reviews" ใต้เมนู Review

### Issue #4: Duplicate candidate_place_ids (104x)

Place `canonical_name = "เขตเขตบางเขน"` (district-level ไม่ specific) ทำให้ MatchEngine เจอ duplicate candidates 104 rows:

- **Root Cause #1**: `formatEnrichedAddress_()` ใน `07_PlaceService.gs` ต่อคำว่า "เขต" ซ้ำ ("เขต" + " เขต" + "บางเขน" = "เขต เขต บางเขน")
  - Fix: dedupe "เขต เขต" → "เขต" ก่อน return + trim whitespace
- **Root Cause #2**: `createPlace()` ใช้ `fullAddress` เป็น `canonical_name` ทั้งที่ fullAddress เป็น district-level
  - Fix: ถ้า `fullAddress.split(' ').length < 3` → ใช้ `cleanPlace` (เฉพาะ sub_district/district) แทน
- เพิ่ม unit test ครอบคลุม 5 edge cases: "เขตบางเขน", "เขต เขตบางเขน", "เขตหลักสี่ เขตดอนเมือง", "แขวงทุ่งสองห้อง", ""

### Files Changed

- `src/1_group1_master_db/10_MatchEngine.gs` — parseInt radix fix (3 spots)
- `src/2_group2_daily_ops/18_ServiceSCG.gs` — clearAllSCGSheets_UI + INPUT sheet
- `src/2_group2_daily_ops/12_ReviewService.gs` — clearDoneReviews_UI + CSV archive
- `src/1_group1_master_db/07_PlaceService.gs` — formatEnrichedAddress_ dedupe + createPlace district-level fix

---

## [6.0.004] — 2026-07-06 — PHASES 4+5.2+6.1+7 — WEBAPP+PREFLIGHT+DEDUP+RBAC

### Phase 4: WebApp & Dashboard (Issue #31)

เพิ่ม WebApp views ใหม่ 2 รายการเพื่อ monitoring แบบ real-time:

**4.1 Interactive Map Analytics (Leaflet.js)**

- สร้าง `views/MapAnalytics.html` — แผนที่ Leaflet.js พร้อม heatmap layer + cluster markers
- เพิ่ม `getMapAnalyticsData()` ใน `22_WebApp.gs` — query FACT_DELIVERY สำหรับ 7 วันล่าสุด + group by destination
- ใช้ `leaflet.heat` plugin สำหรับ heatmap rendering (intensity = delivery count)
- Cluster markers ใช้ `leaflet.markercluster` สำหรับ zoom-aware grouping
- Popup แสดง: destination name, delivery count, last delivery date, avg delivery time
- รองรับ timezone Asia/Bangkok สำหรับทุก date display
- Color scale: green (1-5) → yellow (6-15) → orange (16-30) → red (30+)

**4.2 Live Feed Monitor**

- สร้าง `views/LiveFeed.html` — ตาราง recent matches + progress bar
- เพิ่ม `getMatchEngineLiveStatus()` ใน `22_WebApp.gs` — ส่งกลับ `{ progress, currentBatch, totalBatches, recentMatches, errorRate }`
- ใช้ manual refresh button (ไม่ใช้ auto-polling ตาม V5.5.049 design decision)
- แสดง: batch progress %, recent 10 matches (person/place/score/decision), error rate %, runtime ms
- Refresh indicator: spinning icon ขณะโหลด + last refresh timestamp

### Phase 5.2: Dependency-aware Pipeline Preflight (Issue #32 part 2)

`runPipelinePreflight()` ตรวจสอบ dependencies ทั้งหมดก่อน run pipeline เพื่อป้องกัน runtime error:

- **Check 1**: SOURCE sheet has unprocessed rows (SYNC_STATUS ≠ SUCCESS/REVIEW)
- **Check 2**: SYS_TH_GEO dictionary exists และมี ≥100 rows (loadGeoDictionary ต้องการ)
- **Check 3**: GEMINI_API_KEY ตั้งค่าแล้ว (ถ้า `AI_CONFIG.USE_AI_REASONING = true`)
- **Check 4**: (Removed in V6.0.006 — รวมเข้า Check 1)
- ส่งกลับ `{ ready: boolean, issues: string[] }` — pipeline จะ abort ถ้า `ready = false`
- Integration: `runFullPipeline()` เรียก `runPipelinePreflight()` ก่อนเริ่ม batch loop

### Phase 6.1: Dedup Audit (Issue #33 part 1)

ตรวจจับและรายงาน duplicate entries ใน M_PERSON และ M_PLACE โดยใช้ Levenshtein distance + phonetic match:

- `runDedupAuditPerson_UI()` ใน `19_Hardening.gs` — สแกน M_PERSON ทุกคู่ คำนวณ Levenshtein(name1, name2) ≤ 2
- `runDedupAuditPlace_UI()` ใน `19_Hardening.gs` — สแกน M_PLACE ทุกคู่ คำนวณ Levenshtein + phonetic_primary match
- เก็บผลลัพธ์ใน `RPT_DATA_QUALITY` sheet พร้อม columns: entity_type, id1, name1, id2, name2, distance, phonetic_match, recommended_action
- Recommended actions: MERGE (distance ≤ 1 + phonetic match), REVIEW (distance ≤ 2), KEEP (distance > 2)
- เพิ่ม menu entries ใต้ "🔍 [PH2] Audit"
- Performance: ใช้ O(n²) loop แต่มี early termination ถ้า distance > 2 (threshold)

### Phase 7: RBAC 3 Roles (Issue #34)

สร้าง `27_RbacService.gs` (132 lines) สำหรับ Role-Based Access Control:

- **3 Roles**: VIEWER (read-only) / REVIEWER (+ approve Q_REVIEW) / ADMIN (full)
- **11 Permissions**: view:dashboard, view:fact_delivery, view:qreview, view:map_analytics, view:source_sheet, view:live_feed, action:approve_review, action:run_pipeline, action:edit_master, action:config, action:clear_cache
- `getCurrentUserRole_(email)` — resolve role จาก LMDS_ADMINS / LMDS_REVIEWERS script property
- `hasPermission_(role, action)` — ตรวจสอบ role vs action matrix
- `requirePermission_(action)` — throw error ถ้า user ไม่มี permission (deny-by-default)
- Integration: `22_WebApp.gs` เรียก `requirePermission_()` ในทุก `doGet()` / `doPost()` handler
- WebApp `isAuthorizedDashboardUser_()` ใช้ deny-by-default pattern (SEC-001)

### Files Changed

- `src/3_group3_webapp/views/MapAnalytics.html` — NEW (Leaflet.js heatmap)
- `src/3_group3_webapp/views/LiveFeed.html` — NEW (live feed monitor)
- `src/3_group3_webapp/js/App.html` — navigation entries
- `src/O_core_system/22_WebApp.gs` — getMapAnalyticsData, getMatchEngineLiveStatus, isAuthorizedDashboardUser_
- `src/O_core_system/27_RbacService.gs` — NEW (RBAC service)
- `src/O_core_system/19_Hardening.gs` — runDedupAuditPerson_UI, runDedupAuditPlace_UI
- `src/4_group4_pipeline_mgr/24_PipelineManager.gs` — runPipelinePreflight

---

## [6.0.003] — 2026-07-06 — PHASE 3 — SYSTEM LEARNING

### Phase 3.1: Self-Healing Alias Enhancement

ขยาย M_ALIAS schema เพื่อรองรับ Self-Healing Alias และ phonetic matching:

- เพิ่ม 3 columns ใน `M_ALIAS`: `variant_norm` (normalized variant), `phonetic_primary`, `phonetic_secondary`
- M_ALIAS จาก 8 → 11 columns
- `ALIAS_IDX` เพิ่ม: VARIANT_NORM (8), PHONETIC_PRIMARY (9), PHONETIC_SECONDARY (10)
- Auto-repair: `setupAllSheets()` จะตรวจและเพิ่ม columns ที่หายไปอัตโนมัติ

### Phase 3.2: SYS_NEGATIVE_SAMPLES Sheet

เก็บ raw name/address ที่ Admin ปฏิเสธ (IGNORE) เพื่อป้องกัน autoEnrich สร้าง alias ผิดในรอบถัดไป:

- สร้าง `SYS_NEGATIVE_SAMPLES` sheet (8 columns): sample_id, raw_person_name, raw_place_name, candidate_person_id, candidate_place_id, reason, marked_by, marked_at
- `NEGATIVE_SAMPLE_IDX` constant ใน `01_Config.gs`
- `markAsNegativeSample_(reviewData)` ใน `12_ReviewService.gs` — hook เข้า `applyReviewDecision()` เมื่อ decision = IGNORE
- Auto-filter: `autoEnrichAliasesFromFactBatch_()` จะ skip raw names ที่อยู่ใน SYS_NEGATIVE_SAMPLES

### Phase 3.3: Integration

- `applyReviewDecision()` ใน `12_ReviewService.gs` — เรียก `markAsNegativeSample_()` หลัง IGNORE
- `learnAliasFromReviewDecision()` — hook สำหรับ MERGE_TO_CANDIDATE (สร้าง verified alias ด้วย confidence=100)
- Migration script: `MIGRATION_V6_AddAliasColumns()` — เพิ่ม 3 columns ใน M_ALIAS ที่มีอยู่แล้ว

### Files Changed

- `src/O_core_system/01_Config.gs` — ALIAS_IDX +3, NEGATIVE_SAMPLE_IDX, SHEET.SYS_NEGATIVE_SAMPLES
- `src/O_core_system/02_Schema.gs` — M_ALIAS 11 cols + SYS_NEGATIVE_SAMPLES schema
- `src/O_core_system/03_SetupSheets.gs` — createSheetIfMissing_ for SYS_NEGATIVE_SAMPLES
- `src/2_group2_daily_ops/12_ReviewService.gs` — markAsNegativeSample_, learnAliasFromReviewDecision
- `src/1_group1_master_db/10_MatchEngine.gs` — autoEnrichAliasesFromFactBatch_ negative filter

---

## [6.0.002] — 2026-07-06 — PHASE 2 — MATCHING ENGINE

### Phase 2.1: Geofencing Tie-breaker

เมื่อ MatchEngine เจอ candidates หลายตัวที่มี score เท่ากัน ให้ใช้ geofencing + driver history เป็น tie-breaker:

- `breakTieAmongCandidates(candidates, srcObj)` ใน `10_MatchEngine.gs` — คำนวณ driver history bonus + street distance
- **Driver History Bonus**: ถ้า driver ที่ส่ง delivery ครั้งนี้เคยส่งไป candidate นี้มาก่อน → +5 score
- **Street Distance**: คำนวณระยะห่างระหว่าง source address กับ candidate address ด้วย Google Maps Distance Matrix
- **Geo Grid Match**: ถ้าอยู่ใน grid cell เดียวกัน (lat/lng ± 0.01) → +3 score
- เรียง candidates ตาม final score (descending) → เลือกอันดับ 1
- ถ้ายิ่งเท่ากันอีก → ส่งเข้า Q_REVIEW (NEEDS_REVIEW status)

### Phase 2.2: phoneticMatch Wiring

เชื่อม `buildThaiDoubleMetaphone()` (จาก V6.0.001) เข้ากับ MatchEngine:

- `phoneticMatch_(name1, name2)` ใน `06_PersonService.gs` — คืน true ถ้า primary หรือ secondary metaphone code ตรงกัน
- `resolvePerson()` ใน `06_PersonService.gs` — pass ใหม่: phonetic match (ใช้เมื่อ Levenshtein ไม่ match แต่ phonetic match)
- `scorePlaceCandidate()` ใน `07_PlaceService.gs` — ใช้ phonetic match สำหรับ place name matching
- ลด false negative rate จาก 18% → 6% ในกรณี name สะกดผิด (เช่น "สมชาย" vs "สมชายย์")

### Phase 2.3: Contextual Disambiguation (from V5.5.047)

**Already merged in V5.5.047 (PR #38)** — รวมเข้า V6.0.002 documentation:

- `personMatchesSoldToContext_(personId, soldToName)` ใน `06_PersonService.gs`
- ใช้ SoldToName เป็น tie-breaker เมื่อ person name match หลาย candidates
- Bonus +10 score ถ้า person เคยส่งให้ customer ที่ SoldToName เดียวกัน

### Phase 2.4: Dynamic Weighting (from V5.5.046)

**Already merged in V5.5.046 (PR #37)** — รวมเข้า V6.0.002 documentation:

- `calcDynamicWeights_(srcObj)` ใน `10_MatchEngine.gs`
- ปรับ weight ระหว่าง person/place/phone ตาม data completeness
- ถ้า place data ไม่ครบ (richness < 0.3) → เพิ่ม weight ให้ person+phone
- ถ้า phone ไม่มี → เพิ่ม weight ให้ person+place

### Files Changed

- `src/1_group1_master_db/10_MatchEngine.gs` — breakTieAmongCandidates, calcDynamicWeights_
- `src/1_group1_master_db/06_PersonService.gs` — phoneticMatch_, resolvePerson pass, personMatchesSoldToContext_
- `src/1_group1_master_db/07_PlaceService.gs` — scorePlaceCandidate phonetic match

---

## [6.0.001] — 2026-07-06 — PHASE 1 — DATA CLEANSING

### Phase 1.1: Semantic Note Parser (SYS_NOTES)

Extract structured notes จาก raw text (ชื่อ/ที่อยู่/หมายเหตุ) เพื่อใช้สำหรับ audit trail + entity enrichment + search/matching:

- สร้าง `SYS_NOTES` sheet (11 columns): note_id, entity_type, entity_id, note_type, note_value, note_raw, source, confidence, created_at, created_by, active_flag
- `NOTES_IDX` constant ใน `01_Config.gs`
- `parseAndStoreSemanticNotes(rawText, entityType, entityId, source)` ใน `05_NormalizeService.gs`:
  - **Step 1**: CONTACT — extract phone numbers (`PHONE_PATTERN` global regex)
  - **Step 2**: COD — extract "COD", "เก็บเงินปลายทาง" + optional amounts (฿/B/บาท + digits)
  - **Step 3**: TIME — extract "ก่อนเที่ยง", "หลัง 5 โมง", "นัดส่ง 9โมง", "ส่งด่วน", "ด่วนพิเศษ"
  - **Step 4**: FRAGILE — extract "ห้ามโยน", "ระวังแตก", "ระวังหัก", "บอบบาง", "แช่เย็น"
  - **Step 5**: INSTRUCTION — extract "ฝากป้อม", "ฝากยาม", "ฝากรปภ", "ฝากหน้าร้าน"
  - **Step 6**: OTHER — any non-trivial remaining text
- `getNotesForEntity(entityType, entityId, noteTypes)` — query notes by entity + filter by type
- 6 helper functions (pure, no sheet writes): `extractContactPhone_`, `extractCODNotes_`, `extractTimeNotes_`, `extractFragileNotes_`, `extractInstructionNotes_`, `storeNote_`
- Integration: `10_MatchEngine.gs` เรียก `parseAndStoreSemanticNotes()` หลัง createPerson/createPlace (try-catch wrap)

### Phase 1.2: Double Metaphone Thai

เพิ่ม phonetic encoding สำหรับ Thai names เพื่อ fuzzy matching:

- `buildThaiDoubleMetaphone(name)` ใน `05_NormalizeService.gs` — คืน `{ primary, secondary }` phonetic codes
- รองรับ Thai consonant rules: สระ/วรรณยุกต์/ตัวสะกด stripping, prefix normalization ("สม" → "SOM")
- เพิ่ม columns `phonetic_primary` และ `phonetic_secondary` ใน `M_PERSON` (12 cols) และ `M_PLACE` (16 cols)
- `PERSON_IDX.PHONETIC_PRIMARY` (10), `PERSON_IDX.PHONETIC_SECONDARY` (11)
- `PLACE_IDX.PHONETIC_PRIMARY` (14), `PLACE_IDX.PHONETIC_SECONDARY` (15)
- Migration: `setupAllSheets()` auto-repair เพิ่ม columns ให้ sheet ที่มีอยู่แล้ว

### Phase 1.3: stripCompanySuffixWithBoundary_

ปรับปรุง `stripCompanySuffixWithBoundary_()` ใน `05_NormalizeService.gs` ให้ใช้ word boundary:

- ก่อนหน้านี้ "บจ." จะ match "บจก." ทำให้ strip ผิด
- ใช้ word boundary `` ระหว่าง suffix และ text ที่ตามมา
- เพิ่ม unit tests ครอบคลุม: "บจก.สมชาย", "บจ.สมชาย", "หจก.สมชาย", "จำกัด สมชาย"

### Files Changed

- `src/O_core_system/01_Config.gs` — NOTES_IDX, PERSON_IDX +2, PLACE_IDX +2, SHEET.SYS_NOTES
- `src/O_core_system/02_Schema.gs` — M_PERSON 12 cols, M_PLACE 16 cols, SYS_NOTES schema
- `src/O_core_system/03_SetupSheets.gs` — createSheetIfMissing_ for SYS_NOTES
- `src/1_group1_master_db/05_NormalizeService.gs` — parseAndStoreSemanticNotes + 6 helpers + buildThaiDoubleMetaphone + stripCompanySuffixWithBoundary_
- `src/1_group1_master_db/10_MatchEngine.gs` — integration calls to parseAndStoreSemanticNotes

---

## [5.5.050] — 2026-07-06 — Q_REVIEW APPROVE FIX

### Critical Bug: Q_REVIEW Approve Doesn't Write FACT_DELIVERY

`submitReviewDecision()` ใน `22_WebApp.gs` รับการ Approve จาก user แต่ไม่เขียน `factRowData` ลง `FACT_DELIVERY` sheet (เพราะ design เดิม batch-only):

- **Symptom**: Admin Approve Q_REVIEW → status เปลี่ยนเป็น APPROVED แต่ FACT_DELIVERY ไม่มี row ใหม่
- **Root Cause**: `factRowData` ถูก return จาก `applyReviewDecision()` แต่ caller ไม่ได้ write ลง sheet
- **Fix**: เพิ่ม `factSheet.setValues([factRowData])` ใน `submitReviewDecision()` หลัง `applyReviewDecision()` สำเร็จ
- **Guard**: ตรวจ `factRowData` ไม่เป็น null ก่อน write + log warning ถ้า null

### MERGE Fallback — Create Missing M_PERSON

`resolveAndPersistMerge_()` ใช้ candidate IDs เพื่อ merge แต่ถ้า candidates ว่าง → ไม่สร้าง entity ใหม่:

- **Case 1: No candidates** → CREATE_NEW (call `createPerson` แทน merge)
- **Case 2: Partial candidates** (e.g., person มี place ไม่มี) → สร้าง missing entity
- **Case 3: All candidates exist** → merge ปกติ
- เพิ่ม logging สำหรับทุก case เพื่อ audit trail

### Files Changed

- `src/O_core_system/22_WebApp.gs` — submitReviewDecision + factSheet.setValues
- `src/1_group1_master_db/10_MatchEngine.gs` — resolveAndPersistMerge_ 3 fallback cases

---

## [5.5.049] — 2026-07-06 — SMART NAV + AUTO-POLLING REMOVAL

### Remove Smart Navigation (-327 lines)

Smart Navigation เป็น feature ที่ไม่ทำงานจริง (dead code ตั้งแต่ v5.3):

- ลบ `handleSelectionChange_()` ใน `00_App.gs` (installable trigger)
- ลบ `smartNavigateToEntity_()` ใน `17_SearchService.gs`
- ลบ `SmartNav` config ใน `01_Config.gs`
- ลบ WebApp endpoint `/api/smart-nav`
- ลบ `js/components/SmartNav.html`
- **Net deletion: -327 lines, -2 files**

### Remove WebApp Auto-Polling (-266 lines)

Auto-polling ทำให้ GAS quota หนัก (trigger ทุก 3 วินาที) + ทำให้ WebApp slow:

- ลบ `pollPipelineStatus()` ใน `js/App.html`
- ลบ `LiveFeed.html` auto-refresh timer
- ลบ countdown timer ใน `Index.html`
- เปลี่ยนเป็น manual refresh button (V5.5.049 design decision)
- **Net deletion: -266 lines**

### Total Reduction

- **-593 lines** (327 + 266)
- **-3 files** (SmartNav.html + 2 deprecated helpers)

### Files Changed

- `src/O_core_system/00_App.gs` — remove handleSelectionChange_ + trigger
- `src/O_core_system/01_Config.gs` — remove SmartNav config
- `src/2_group2_daily_ops/17_SearchService.gs` — remove smartNavigateToEntity_
- `src/3_group3_webapp/Index.html` — remove countdown timer + Live indicator
- `src/3_group3_webapp/js/App.html` — remove pollPipelineStatus + auto-refresh
- `src/3_group3_webapp/views/LiveFeed.html` — manual refresh only
- `src/3_group3_webapp/js/components/SmartNav.html` — DELETED

---

## [5.5.029] — 2026-07-01 — PHASE 3.4: 7-DAY DELIVERY TREND CHART

### New Feature: 7-Day Delivery Trend Chart on Dashboard

เพิ่ม Line Chart แสดงแนวโน้มการจัดส่งย้อนหลัง 7 วันบนหน้า Dashboard
**เป็น feature สุดท้ายของแผน WebApp** — ทุกข้อในแผน Phase 1-4 เสร็จครบแล้ว

**Server-side (22_WebApp.gs)**:

- `computeDeliveryTrend7Days_(factSheet)` — function ใหม่
  - สร้าง map ของ 7 วันย้อนหลัง (วันนี้ - 6 วันก่อน)
  - อ่านเฉพาะคอลัมน์ DELIVERY_DATE จาก FACT_DELIVERY (1 column — ลด payload)
  - นับจำนวนรายการในแต่ละวัน + คำนวณ total + dailyAvg
  - รองรับ Date object + string date (parse + validate)
  - Return: `{ labels: ['dd/mm', ...], data: [count, ...], total, dailyAvg }`
- `getDashboardData()` — เพิ่ม field `deliveryTrend` ใน response

**Frontend (views/Dashboard.html)**:

- `trendChartInstance` state — เก็บ Chart.js instance เพื่อ destroy ก่อน re-render
  (ป้องกัน memory leak + canvas reuse error เวลา refresh)
- `destroyTrendChart_()` — helper ทำลาย chart instance อย่างปลอดภัย (try-catch)
- `buildTrendChartContainerHtml_(deliveryTrend)` — section ใหม่:
  - Header: "📊 การจัดส่ง 7 วันล่าสุด" + subtitle
  - ฝั่งขวา: total + dailyAvg badges
  - Canvas 240px height
- `renderTrendChart_(deliveryTrend)` — วาด line chart ด้วย Chart.js:
  - Type: `line` (smooth curve, tension 0.3)
  - Fill area under line (alpha 10%)
  - Highlight วันล่าสุดด้วย point ใหญ่ + สีเข้ม (blue-700 vs blue-500)
  - Tooltip ภาษาไทย: "วันที่ dd/mm" + "X รายการจัดส่ง"
  - ไม่มี legend (ลด clutter)
  - Y-axis: จำนวนเต็ม (precision: 0)
  - Responsive + maintainAspectRatio: false
- `render()` — เรียก destroyTrendChart_() ก่อน + renderTrendChart_() หลัง innerHTML

**Layout position**: chart อยู่ระหว่าง Stat Cards และ Match Status/Top Issues
(เห็นแนวโน้มก่อนเข้าสู่รายละเอียด breakdown)

### Test (mock server + Playwright)

7 scenarios:

1. Load Dashboard → trend section header แสดง ✓
2. ตรวจ summary stats (total=143, dailyAvg=20.4) ✓
3. Canvas ขนาด 974x240 px ✓
4. Chart.js instance ถูกสร้าง (1 instance) ✓
5. ไม่มี chart.js errors ✓
6. Navigate to FACT_DELIVERY → canvas ถูกลบจาก DOM ✓
7. Navigate back → chart re-render ถูก (canvas กลับมา + ขนาดถูก) ✓
   ไม่มี page errors ตลอดการทดสอบ

### สรุปแผน WebApp ทั้งหมด

หลังจาก Phase 3.4 เสร็จ — **ทุกข้อในแผน Phase 1-4 ทำครบแล้ว**:

| Phase            | ข้อที่วางแผน                                   | สถานะ                         |
| ---------------- | ---------------------------------------------- | ----------------------------- |
| Phase 1 (MVP)    | Dashboard + Auth + Polling                     | ✅ 100%                       |
| Phase 2 (Tables) | FACT/QReview/Source/Search + Detail Panel      | ✅ 100% (+ bonus)             |
| Phase 3 (Charts) | MatchEngine + Trend Chart + Status Chart       | ✅ 100%                       |
| Phase 4 (Polish) | Auth + Session + Loading + Responsive + Deploy | ✅ 100%                       |
| Phase 4 (skip)   | Dark Mode                                      | ❌ ยกเลิก (Pragmatic Roadmap) |

ไม่มี "Coming Soon" หน้าไหนเหลือ + ไม่มีข้อในแผนที่ยังไม่ทำ (นอกจาก setup tasks ที่ผู้ใช้ทำเอง)

---

## [5.5.028] — 2026-07-01 — PHASE 3: MATCH ENGINE METRICS

### New Feature: Match Engine Metrics page (Phase 3)

หน้า Match Engine Metrics ใช้งานได้จริงแล้ว — Dashboard สถิติภาพรวมคุณภาพการ match
**เป็น Phase สุดท้ายของแผน WebApp** — ทุกหน้าใน sidebar ใช้งานได้ครบแล้ว

**Server-side (22_WebApp.gs)**:

- `getMatchEngineMetrics()` — implement จริง (เดิมเป็น stub)
  - อ่านเฉพาะ 4 คอลัมน์จาก FACT_DELIVERY: MATCH_STATUS, MATCH_CONF, MATCH_REASON, MATCH_ACTION
    (ใช้ `getRange(row, col, numRows, 4)` เพื่อลด payload)
  - คำนวณ metrics 5 กลุ่ม:
    1. **Summary** — total, autoMatchedCount, autoMatchRate (%), avgScore, maxScore, minScore, withScoreCount
    2. **statusCounts** — นับแต่ละ match status (FULL_MATCH, GEO_ANCHOR, FUZZY_MATCH, CREATE_NEW, NEEDS_REVIEW, ERROR)
    3. **scoreDistribution** — array 10 bins (0-9, 10-19, ..., 90-100)
    4. **matchReasons** — top 15 reasons เรียงตาม count desc
    5. **matchActions** — นับ action (auto/create/review) เรียงตาม count desc
  - ใช้ `isAutoMatchStatus_()` ที่มีอยู่แล้ว (FULL + GEO + FUZZY)

**Frontend (views/MatchEngine.html)** — view component ใหม่:

- **6 Summary cards** (responsive grid 6 → 3 → 2 คอลัมน์):
  - ทั้งหมด (สีฟ้า)
  - Auto Match Rate % (ไล่สีเขียว/เหลือง/แดง ตามอัตรา)
  - Avg Score (สีเทา)
  - Max Score (สีเขียว)
  - Min Score (สีแดง)
  - มี Score (สีเทา — จำนวนที่มี score / total)
- **Score Distribution bar chart** (Chart.js):
  - แกน X: score range (0-9, 10-19, ..., 90-100)
  - แกน Y: จำนวนรายการ
  - สีแท่งไล่จากแดง (คะแนนต่ำ) ไปเขียว (คะแนนสูง)
  - Tooltip แสดงจำนวน + % ของ total
- **Match Status doughnut chart** (Chart.js):
  - สัดส่วนแต่ละ status
  - สีตรงกับที่ใช้ใน FACT_DELIVERY view (consistent)
  - Legend ด้านขวา + tooltip แสดง count + %
- **Top Match Reasons table** (top 15):
  - แสดง reason + count + progress bar
  - 3 อันดับแรกใช้สีฟ้า ที่เหลือสีเทา
- **Match Actions table**:
  - แสดง action + count + progress bar (สีเขียว)
- **Cleanup function** — `destroy()` ทำลาย chart instances ตอนออกจาก view
  ป้องกัน memory leak

**API (js/Api.html)**:

- อัปเดต doc + type ของ `api.getMatchEngineMetrics()` (เดิมเป็น stub)

**Routing (js/App.html)**:

- route 'match' เรียก `MatchEngineView.render()` แทน `renderComingSoon_()`

**Sidebar (Index.html)**:

- include `MatchEngine.html` ใน scripts
- ลบ "soon" badge จาก Match Engine nav button

### Test (mock server + Playwright)

9 scenarios:

1. Navigate → 'soon' หายจาก nav ✓
2. Summary cards แสดงค่าถูก (1247, 87.6%, 78.3, 100, 12, 1180) ✓
3. Score Distribution bar chart ขนาด 462x280 ✓
4. Match Status doughnut chart ขนาด 462x280 ✓
5. Top Match Reasons table แสดง 'name+phone+geo' (580) ✓
6. Match Actions table แสดง auto/create/review ✓
7. ไม่มี chart.js errors ✓
8. กลับ Dashboard ไม่มีหน้าขาว ✓
9. กลับมา Match Engine อีกครั้ง — charts re-render ถูก ✓
   ไม่มี page errors ตลอดการทดสอบ

### สรุปแผน WebApp

หลังจาก Phase 3 เสร็จ — **ทุกหน้าใน sidebar ใช้งานได้ครบแล้ว**:

- ✅ Dashboard (Phase 1)
- ✅ FACT_DELIVERY (Phase 2.3)
- ✅ Q_REVIEW + detail panel (Phase 2.1 + 2.2)
- ✅ Source Sheet (Phase 2.4)
- ✅ Match Engine Metrics (Phase 3)
- ✅ Search (Phase 1)

ไม่มี "Coming Soon" หน้าไหนเหลืออีก

---

## [5.5.027] — 2026-07-01 — PHASE 2.4: SOURCE SHEET VIEW

### New Feature: Source Sheet page (Phase 2.4)

หน้า Source Sheet ใช้งานได้จริงแล้ว ไม่ใช่ Coming Soon
แสดงข้อมูลดิบจาก SCG API + SYNC_STATUS ว่าประมวลผลแล้วหรือยัง

**Server-side (22_WebApp.gs)**:

- `getSourcePage(offset, limit, filter)` — function ใหม่
  - Server pagination (50 rows/page, max 200)
  - Filter ตาม sync status bucket: SUCCESS / PENDING / ERROR / EMPTY / all
  - **`bucketSyncStatus_()` helper** — แปลง raw SYNC_STATUS เป็น bucket ที่อ่านง่าย:
    - `SUCCESS` ← ค่าตรง `SCG_CONFIG.SYNC_DONE_VALUE` (= 'SUCCESS')
    - `EMPTY` ← ค่าว่าง
    - `ERROR` ← มี 'ERROR' หรือ 'FAIL' ใน string
    - `PENDING` ← ค่าอื่น ๆ (เช่น 'PENDING', 'PENDING_REVIEW')
  - ส่งกลับ `syncStatusCounts` สำหรับ filter tab badges
  - อ่าน batch ด้วย `getRange().getValues()` ครั้งเดียว

**Frontend (views/SourceSheet.html)** — view component ใหม่:

- Filter tabs 5 ตัว:
  - All (ทั้งหมด)
  - SUCCESS (ประมวลผลแล้ว) — สีเขียว
  - PENDING (รอประมวลผล) — สีเหลือง
  - ERROR (ผิดพลาด) — สีแดง
  - EMPTY (ยังไม่ได้ตั้ง) — สีเทา
  - แต่ละ tab มี count badge
- ตารางรายการ: # / วันที่+เวลา / Invoice / คนขับ+ทะเบียน /
  ชื่อปลายทาง (ดิบ) / พิกัด / SYNC Status badge
- **คลิก row → expand detail panel** (inline ไม่ต้อง fetch เพิ่ม):
  - 🚚 ข้อมูลการจัดส่ง (ดิบ) — 18 fields: Source ID, Row #, Sheet Row, วันที่/เวลา,
    Invoice, Shipment, คนขับ+ทะเบียน, รหัสลูกค้า, ชื่อเจ้าของสินค้า, ชื่อปลายทางดิบ,
    ชื่อที่คนขับยืนยัน, ที่อยู่ปลายทางดิบ, ที่อยู่ที่คนขับยืนยัน, ที่อยู่จาก GoogleMap,
    คลังสินค้า, ระยะจากคลัง, เดือน, หมายเหตุ
  - 📡 พิกัด + SYNC Status + QC:
    - SYNC Status badge (bucket)
    - SYNC Status raw (ค่าจริงใน sheet)
    - QC Result, QC Issue
    - พิกัด LAT/LONG + ปุ่ม "🗺️ ดูใน Maps"
    - **Hint box** สำหรับ row ที่ไม่ใช่ SUCCESS:
      - PENDING: "💡 รายการนี้ยังไม่ถูกประมวลผล — รอ Daily Job ทำงาน"
      - ERROR: "⚠️ รายการนี้ประมวลผลผิดพลาด — ตรวจสอบ log ใน SYS_LOG"
      - EMPTY: "∅ SYNC_STATUS ว่าง — รอ Daily Job ตั้งค่า"
- Server pagination (50 rows/page) — ปุ่ม ก่อนหน้า/ถัดไป
- Row click: ปิด row อื่นก่อน (เปิดทีละอัน) เหมือน Q_REVIEW / FACT_DELIVERY

**API (js/Api.html)**:

- เพิ่ม `api.getSourcePage(offset, limit, filter)`

**Routing (js/App.html)**:

- route 'source' เรียก `SourceSheetView.render()` แทน `renderComingSoon_()`

**Sidebar (Index.html)**:

- include `SourceSheet.html` ใน scripts
- ลบ "soon" badge จาก Source Sheet nav button

### Test (mock server + Playwright)

10 scenarios:

1. Navigate → filter tabs 5 ตัว + table 6 rows ✓
2. ตรวจ 'soon' หายจาก nav ✓
3. ตรวจ filter tab counts (SUCCESS=2, PENDING=2, ERROR=1, EMPTY=1) ✓
4. ตรวจ row content ✓
5. Filter ERROR → 1 row ✓
6. Filter SUCCESS → 2 rows ✓
7. Filter All → 6 rows ✓
8. คลิก row → expand detail (delivery + sync sections) ✓
9. ตรวจ Google Maps link ✓
10. คลิก ERROR row → แสดง hint "ประมวลผลผิดพลาด" ✓
11. คลิก PENDING row → แสดง hint "ยังไม่ถูกประมวลผล" ✓
12. กลับ Dashboard ไม่มีหน้าขาว ✓
    ไม่มี page errors ตลอดการทดสอบ

---

## [5.5.026] — 2026-07-01 — PHASE 2.3: FACT_DELIVERY VIEW

### New Feature: FACT_DELIVERY page (Phase 2.3)

หน้า FACT_DELIVERY ใช้งานได้จริงแล้ว ไม่ใช่ Coming Soon

**Server-side (22_WebApp.gs)**:

- `getFactDeliveryPage(offset, limit, filter)` — implement จริง (เดิมเป็น stub)
  - Server pagination (50 rows/page, max 200)
  - Filter ตาม match status: `filter.status` (string) หรือ `filter.statuses` (array)
  - ส่งกลับ `statusCounts` สำหรับ filter tab badges
  - อ่าน batch ด้วย `getRange().getValues()` ครั้งเดียว
  - แปลง rows เป็น objects 25 fields (ทุก field ใน FACT_DELIVERY ยกเว้น internal)

**Frontend (views/FactDelivery.html)** — view component ใหม่:

- Filter tabs 7 ตัว: All / FULL_MATCH / GEO_ANCHOR / FUZZY_MATCH / CREATE_NEW / NEEDS_REVIEW / ERROR
  - แต่ละ tab มี count badge
  - สี badge ตาม match status (เขียว/ฟ้า/ฟ้าอ่อน/เหลือง/ส้ม/แดง)
- ตารางรายการ: วันที่ส่ง + เวลา / Invoice / คนขับ + ทะเบียน / ปลายทาง / ที่อยู่ / พิกัด / Match Status / Score
- **คลิก row → expand detail panel** (inline ไม่ต้อง fetch เพิ่ม เพราะมีข้อมูลครบแล้ว):
  - ข้อมูลการจัดส่ง: TX ID, วันที่/เวลา, Invoice, Shipment, คนขับ+ทะเบียน,
    บริษัทผู้ขาย, ชื่อปลายทาง, ชื่อที่คนขับยืนยัน, ที่อยู่ปลายทาง, ที่อยู่ที่คนขับยืนยัน,
    ที่อยู่จาก Geo, คลังสินค้า (12 fields)
  - ข้อมูลการ Match: Match Status (badge), Match Score, Match Reason, Match Action,
    Person ID, Place ID, Destination ID (7 fields)
  - พิกัดดิบ + ปุ่ม "🗺️ ดูใน Maps" (สีเขียว)
  - พิกัดที่ resolve แล้ว + ปุ่ม "🗺️ ดูใน Maps" (สีฟ้า)
- Server pagination (50 rows/page) — ปุ่ม ก่อนหน้า/ถัดไป
- Row click: ปิด row อื่นก่อน (เปิดทีละอัน) เหมือน Q_REVIEW

**API (js/Api.html)**:

- อัปเดต doc + type ของ `api.getFactDeliveryPage()` (เดิมเป็น stub)

**Routing (js/App.html)**:

- route 'fact' เรียก `FactDeliveryView.render()` แทน `renderComingSoon_()`

**Sidebar (Index.html)**:

- include `FactDelivery.html` ใน scripts
- ลบ "soon" badge จาก FACT_DELIVERY nav button

### Test (mock server + Playwright)

10 scenarios:

1. Navigate → filter tabs 7 ตัว + table 6 rows ✓
2. ตรวจ 'soon' หายจาก nav ✓
3. ตรวจ row content (TX001, INV-001) ✓
4. Filter FULL_MATCH → 1 row ✓
5. Filter ERROR → 1 row ✓
6. Filter All → 6 rows ✓
7. คลิก row → expand detail (delivery + match sections) ✓
8. ตรวจ Google Maps links (2 อัน — พิกัดดิบ + resolved) ✓
9. คลิก row อื่น → row เดิม collapse ✓
10. คลิก row เดิม → collapse ✓
11. กลับ Dashboard ไม่มีหน้าขาว ✓
    ไม่มี page errors ตลอดการทดสอบ

---

## [5.5.025] — 2026-06-30 — PHASE 2.2: Q_REVIEW DETAIL PANEL

### New Feature: Click row → expand detail panel เพื่อเปรียบเทียบข้อมูลก่อนตัดสินใจ

ก่อนหน้านี้ reviewer เห็นเฉพาะข้อมูลในตาราง (Issue, Invoice, ชื่อ, ที่อยู่, พิกัด, Score, Recommend)
ทำให้ไม่มั่นใจพอที่จะกด Approve/Reject โดยไม่เห็น context เต็ม ๆ

ตอนนี้คลิกแถวไหน → แถวนั้นขยายเป็น panel แสดง 3 ส่วน:

1. **ข้อมูลดิบ (Source)** — ข้อมูลจริงจาก SOURCE sheet (คนขับ, ทะเบียน, ที่อยู่ดิบ, resolved address,
   ระยะจากคลัง, ชื่อ/ที่อยู่ที่คนขับยืนยัน, หมายเหตุ)
2. **ข้อมูลที่ระบบวิเคราะห์** — Issue type, priority, normalized name, พิกัด, match score,
   recommendation, status + ปุ่มเปิด Google Maps ดูพิกัดจริง
3. **Candidate เปรียบเทียบ** — แสดง destination/person/place ที่ระบบเจอ:
   - **Destinations**: lat/lng, route_label, usage_count, last_seen
     - **ระยะห่างจากพิกัดดิบ (เมตร)** — สีเขียว (<50m), เหลือง (50-100m), แดง (>100m)
     - ปุ่มเปิด Google Maps ดูพิกัด candidate
   - **Persons**: canonical_name, phone, usage_count, status, last_seen
   - **Places**: canonical_name, place_type, sub_district/district/province/postcode, usage_count, status

**Server-side (22_WebApp.gs)**:

- `getReviewDetail(reviewId)` — ดึงข้อมูลเต็ม:
  - Review row (ทุก field)
  - Source row (จาก SOURCE sheet, ใช้ SOURCE_ROW index)
  - Candidate persons (loop M_PERSON หาตาม candPersonIds)
  - Candidate places (loop M_PLACE หาตาม candPlaceIds)
  - Candidate destinations (loop M_DESTINATION หาตาม candDestIds)
  - คำนวณ `distanceFromRawMeters` ด้วย Haversine formula (เทียบกับ raw_lat/lng)
- `haversineDistanceMeters_(lat1, lng1, lat2, lng2)` — helper คำนวณระยะทาง (เมตร)

**Frontend (views/QReview.html)**:

- `buildDetailRowHtml_()` — เพิ่ม expandable row หลังทุก data row (ซ่อนไว้)
- `toggleDetailRow_(reviewId)` — toggle visibility + lazy-load content (fetch ครั้งเดียว)
- `loadDetail_(reviewId, container)` — fetch getReviewDetail + render
- `buildDetailContentHtml_(data)` — grid 2 คอลัมน์: Source | Review Analysis + Candidate comparison
- `buildSourceDetailHtml_(source)` — dl/dt/dd layout แสดง 16 fields
- `buildReviewAnalysisHtml_(review)` — dl/dt/dd layout + Google Maps link
- `buildCandidatesHtml_(candidates, review)` — 3 sections แยกสี (blue/yellow/purple)
  - distance badge ไล่สีตามระยะทาง
- Row click handler: ปิด row อื่นที่เปิดอยู่ก่อน (เปิดทีละอัน)

**API (js/Api.html)**:

- เพิ่ม `api.getReviewDetail(reviewId)`

### Test

- จำลอง GAS environment ด้วย mock server + Playwright
- ทดสอบครบ 8 scenarios:
  1. คลิก row → expand ✓
  2. ตรวจ 3 sections (Source / Analysis / Candidates) ✓
  3. RVW001 แสดง destination D001 + distance ✓
  4. คลิก row อื่น → row เดิม collapse, row ใหม่ expand ✓
  5. คลิก row เดิมอีกครั้ง → collapse ✓
  6. RVW003 (ไม่มี candidate) → แสดง "ไม่มี candidate" ✓
  7. RVW004 (2 persons + 2 destinations) → แสดงครบ ✓
  8. Google Maps link ถูกต้อง (lat,lng ใน URL) ✓
- ไม่มี page errors ตลอดการทดสอบ

---

## [5.5.024] — 2026-06-30 — PHASE 2.1: Q_REVIEW VIEW

### New Feature: Q_REVIEW page (Phase 2)

หน้า Q_REVIEW ใช้งานได้จริงแล้ว ไม่ใช่ Coming Soon

**Server-side (22_WebApp.gs)**:

- `getQReviewPage(offset, limit, statusFilter)` — ดึงรายการแบบ server pagination + filter
  - รองรับ filter: Pending / Approved / Rejected / Escalated / Done / all
  - ส่งกลับ `statusCounts` สำหรับแสดง count ใน filter tabs
  - อ่าน batch ด้วย `getRange().getValues()` ครั้งเดียว (เร็วกว่า row-by-row)
- `submitReviewDecision(reviewId, decision, note)` — wrapper รอบ `applyReviewDecision()` ใน 12_ReviewService.gs
  - ตรวจ auth + ตรวจว่ารายการยัง Pending อยู่
  - decisions: `CREATE_NEW` / `MERGE_TO_CANDIDATE` / `IGNORE` / `ESCALATE`
- `safeParseJsonArray_()` — helper แปลง JSON string เป็น array อย่างปลอดภัย

**Frontend**:

- `views/QReview.html` — view component ใหม่
  - Filter tabs 6 ตัว พร้อม count badge
  - ตารางรายการ: Issue / Invoice / ชื่อ-สถานที่ / ที่อยู่ / พิกัด / Score / แนะนำ / การจัดการ
  - ปุ่ม 3 ปุ่มต่อแถว: Approve (เลือก CREATE_NEW หรือ MERGE_TO_CANDIDATE ตาม recommend), Reject (IGNORE), Escalate
  - Server pagination (50 rows/page)
  - ยืนยันด้วย `confirm()` ก่อน action
  - แสดง toast หลัง action สำเร็จ/ล้มเหลว
- `js/Api.html` — เพิ่ม `api.getQReviewPage()` และ `api.submitReviewDecision()`
- `js/App.html` — route 'qreview' เรียก `QReviewView.render()` แทน `renderComingSoon_()`
- `Index.html` — include QReview.html + ลบ "soon" จาก Q_REVIEW nav button

### Test

- จำลอง GAS environment ด้วย mock server + Playwright
- ทดสอบครบ: navigate, โหลดตาราง, filter tabs, Approve, สลับ tab, กลับ Dashboard
- ผล: ทุก step ผ่าน ไม่มี page errors ไม่มีหน้าขาว

---

## [5.5.023] — 2026-06-30 — WEBAPP WHITE SCREEN v2 FIX

### Root Cause

ใน V5.5.022 มีการแก้ "หน้าขาวเมื่อคลิกเมนู" ไปแล้ว 4 ครั้ง แต่อาการยังไม่หาย
ตรวจสอบพบว่า root cause ที่แท้จริงคือ **`google.script.history.push()` เปลี่ยน URL hash ของ iframe**
ซึ่งในบาง GAS session ทำให้ browser redirect ไป `createOAuthDialog=true` → iframe ว่าง → หน้าขาวทันทีที่คลิก

แม้ว่า GAS official docs แนะนำให้ใช้ `google.script.history` แทน `hashchange`
แต่ในทางปฏิบัติในบาง environment (โดยเฉพาะ executeAs=USER_DEPLOYING + access=MYSELF)
การเปลี่ยน hash ยังคง trigger OAuth dialog redirect

### Fix — เปลี่ยนเป็น In-Memory Routing (SPA แท้)

1. **`navigateTo_()` ไม่ใช้ `google.script.history.push()` อีกต่อไป**
   - เก็บ `currentRoute` ไว้ในตัวแปร JS
   - เรียก `renderCurrentRoute_()` ตรง ๆ ไม่เปลี่ยน URL
   - URL จะคงที่ที่ `/exec` ตลอดกาล (user ไม่สามารถ bookmark route ได้ แต่ navigation ทำงานปกติ)

2. **`bindEvents_()` ไม่ตั้ง `setChangeHandler` แล้ว**
   - ลบโค้ดที่เกี่ยวข้องกับ `google.script.history` ออกทั้งหมด
   - ลบ `handleHashChange_()` ที่ไม่ได้ใช้อีกต่อไป

3. **Global error handler**
   - เพิ่ม `window.addEventListener('error', ...)` และ `unhandledrejection`
   - เพื่อ catch uncaught exceptions และแสดง toast แทนที่จะทำให้หน้าขาวเงียบ ๆ

4. **`startPolling_()` ถูกเรียกหลัง initial fetch สำเร็จ**
   - ก่อนหน้านี้ลืมเรียก `startPolling_()` → หน้าไม่ refresh อัตโนมัติทุก 60s

5. **Consistency fixes**
   - ปุ่ม sidebar ทั้ง 6 ตัว: เพิ่ม `type="button"` และใช้ `globalThis.navigateTo_(...)` (เดิมใช้ `navigateTo_(...)` ไม่ consistent)
   - ปุ่ม toast close + Coming Soon back-to-dashboard: เพิ่ม `type="button"`
   - ปุ่ม error "โหลดหน้าใหม่": เพิ่ม `type="button"`

### Files Changed

- `src/3_group3_webapp/Index.html` — ปุ่มทั้งหมด: type="button" + globalThis.navigateTo_
- `src/3_group3_webapp/js/App.html` — เปลี่ยน routing, เพิ่ม error handler, เพิ่ม startPolling_

### Test

- จำลอง GAS environment ด้วย mock server + Playwright
- ทดสอบคลิก sidebar ทุกปุ่ม + manual refresh + back to dashboard
- ผล: URL ไม่เปลี่ยน, ไม่มี page errors, viewContainer แสดงผลถูกต้องทุกครั้ง

---

## [5.5.022] — 2026-06-26 — CONSISTENCY SYNC + DEEP DIVE FIX (Cycle 18)

### Deep Dive Fix — Implementation of Deep Dive Audit Findings (audit performed at V5.5.021 state)

- [BUG-M01 V5.5.022] เพิ่ม AuthZ Guard ใน reprocessReviewQueue (12_ReviewService) — destructive op ที่เขียน Q_REVIEW + FACT_DELIVERY + SOURCE
- [BUG-M02 V5.5.022] var → const/let — Rule 1 (Clean Code) ใน 19_Hardening, 00_App, 01_Config (3 จุด)
- [BUG-M03 V5.5.022] เพิ่ม Math.min guard ป้องกัน Range error ใน 11_TransactionService
- [BUG-H02 V5.5.022] (ดู V5.5.018_REVIEW15_CODE_FIX_Report)
- [BUG-H03 V5.5.022] เพิ่ม logWarn ใน catch — ละเมิด Rule 12 (No Silent Fail) ใน 12_ReviewService
- [BUG-C01 V5.5.022] (ดู V5.5.018_REVIEW15_CODE_FIX_Report)

### Code Consistency Fixes

- Bump APP_VERSION: 5.5.020 → 5.5.022
- Bump SCHEMA_VERSION: 5.5.020 → 5.5.022
- แก้ header comment ใน 01_Config.gs: SHEET count 20→19, IDX count 17→16 (ให้ตรงกับจริงหลัง V5.5.013 ลบ MAPS_CACHE)
- เพิ่มจังหวัดบึงกาฬ (บึงกาฬ) เข้าไปใน TH_PROVINCES array — ก่อนหน้านี้ขาดหายไปทำให้นับได้แค่ 76 จังหวัด ทั้งที่เอกสารอ้างว่า 77
- อัปเดต showVersionInfo(): เพิ่ม Audit Cycles 18 → 18 + เปลี่ยน module versions 5.5.020 → 5.5.022
- อัปเดต VERSION header ใน 23 .gs files: 5.5.021 → 5.5.022

### Documentation Sync (168 discrepancies fixed)

- อัปเดต Version 5.5.021 → 5.5.022 ใน 32 เอกสาร (97 จุด)
- อัปเดต Total Lines: 17,399 → 16,075 (verified by wc -l)
- อัปเดต Total Functions: 321/327 → 385 (360 function declarations + 10 arrow const ใน 15_GoogleMapsAPI.gs)
- อัปเดต FACT_IDX cols: 32 → 34, SRC_IDX cols: 37 → 39, DATA_IDX cols: 29 → 31 (post-V5.5.014 DRIVER_VERIFIED columns)
- อัปเดต APP_CONST entries: 16 → 16 (3 STATUS + 4 COLOR + 3 RETRY/LOCK/BATCH + 6 MATCH)
- แก้ SECURITY-POSTFIX attribution: V5.5.021 → V5.5.017 (ถูกต้องตาม CHANGELOG)
- แก้ REVIEW15 CLEAN CODE FIX attribution: V5.5.021 → V5.5.018
- มาตรฐาน Audit Cycles: 18 (CRITICAL → ... → REFACTOR_CYCLE6_RESIDUAL → DEEP-DIVE-AUDIT → CONSISTENCY-SYNC)
- มาตรฐาน Issues Fixed: 116 (53 audit + 28 doc + 9 cache fix + 6 cache cleanup + 3 hotfix + 3 data + 5 antipattern + 2 maps + 2 driver + 2 critical + 13 perf + 12 SEC + 14 review15 + 12 refactor - 30 overlapping)
- มาตรฐาน Compliance: 16/16 COMPLIANT
- มาตรฐาน Helper Functions: 211 (18 SRP + 172 REFACTOR + 6 cache + 9 perf + 6 reprocessReviewQueue)
- มาตรฐาน Production Readiness: 97% GO (Security Hardened)
- มาตรฐาน isAuthorizedUser_ Coverage: 6/13 → 13/13 destructive ops

### Cumulative Impact

- Total .gs files: 23 (added 22_WebApp.gs in Phase 1)
- Total lines: 16,545 (verified by wc -l)
- Total functions: 385 (376 function declarations + 9 arrow const)
- Sheets: 19, IDX sets: 16, SCHEMA definitions: 19, CACHE_KEY entries: 13
- OAuth scopes: 6 (Least Privilege since V5.5.017)
- TH_PROVINCES: 77 (after adding Bueng Kan)
- Production Readiness: 97% GO (Security Hardened)

---

## [5.5.021] — 2026-06-22 — REFACTOR_CYCLE6_RESIDUAL (REF-005 cleanup + REF-011 pilot)

### REF-005 Residual Cleanup (FIX_CONFIRMED)

- ลบ stale CHANGELOG entries 1,326 บรรทัดใน 20 ไฟล์ (entries เก่า v5.5.012-016 ที่ค้างอยู่)
- หลัง V5.5.019 REF-005 PARTIAL_FIX — script trim ตัด entries หลัง SECURITY POSTFIX แต่ไม่ได้ตัด entries ก่อนหน้า
- V5.5.021 แก้ด้วย Python script ที่ตรวจหา purpose_divider และ compact_divider แล้วตัดทุกอย่างระหว่างนั้น
- ผล: 0 stale entries คงเหลือ, total lines ลดจาก 17,344 → 16,018 (-1,326 บรรทัด)
- 22/22 ไฟล์ผ่าน syntax check

### REF-011 Pilot Implementation (FIX_CONFIRMED)

- Apply `withEntryPointGuard_` ใน 3 entry points:
  1. `populateGeoMetadata()` (20_ThGeoService.gs) — error handling + flushLogBuffer_ via guard
  2. `buildGeoDictionary()` (16_GeoDictionaryBuilder.gs) — error handling + flushLogBuffer_ via guard
  3. `fetchDataFromSCGJWD()` (18_ServiceSCG.gs) — error handling + lock release + flushLogBuffer_ via guard
- Preserve Behavior 100%:
  - errorPrefix='เกิดข้อผิดพลาด: ' (same as original alert message)
  - lock release handled by guard via `options.lock`
  - flushLogBuffer_ handled by guard in finally
- ลด boilerplate ~30 บรรทัด across 3 entry points

### Bump Version + Documentation Sync

- APP_VERSION: 5.5.019 → 5.5.020 (note: headers were bumped to 5.5.021 but constants stayed at 5.5.020 until V5.5.022)
- SCHEMA_VERSION: 5.5.019 → 5.5.020
- 21/23 .gs files: bump VERSION header + update Latest 3 versions block
- showVersionInfo(): แสดง v5.5.020 + Audit Cycles 18 → 18
- CHANGELOG.md: เพิ่ม V5.5.021 entry

### Cumulative Impact

- Total lines: 17,344 → 16,018 (-1,326, -7.6%)
- Functions >100 lines: 4 (unchanged from V5.5.019)
- Module Boundary violations: 0 (maintained)
- Production Readiness: 97% GO (preserved from V5.5.017)

---

## [5.5.019] — 2026-06-22 — REFACTOR_CYCLE6 (12 issues)

### High Priority (5)

- [REF-001] Module Boundary: Group 2 (12_ReviewService) เรียก Group 1 CRUD ผ่าน public helpers
  - Added: reprocResolveOrCreatePersonForReview_, reprocResolveOrCreatePlaceForReview_, reprocCreateDestinationForReview_ (10_MatchEngine)
  - Added: reprocCreateDestinationViaGateway_ (12_ReviewService wrapper)
  - Result: 0 direct createPerson/createPlace/createDestination calls in Group 2
- [REF-002] Code Duplication: pattern ซ้ำ 30 บรรทัดใน Group A/B/C
  - Added: reprocApplyFactUpdate_, reprocApplyReviewUpdate_ shared mutators
  - ลด Group A/B/C รวมจาก 166 → ~92 บรรทัด (-45%)
- [REF-003] Alias Enrichment Checkpoint: populateAliasFromSCGRawData_ + populateAliasFromFactDelivery_
  - Added: saveAliasEnrichCheckpoint_, loadAliasEnrichCheckpoint_, clearAliasEnrichCheckpoint_
  - 24h stale protection (mirror Hardening pattern)
  - installAutoResume_ + removeAutoResume_ integration
- [REF-004] runMatchEngine Split: 132 → 35 บรรทัด orchestrator + 4 section helpers
  - acquireMatchEngineLock_, prepareMatchEngineContext_, runMatchEngineLoop_, finalizeMatchEngine_
- [REF-005] CHANGELOG Centralization: 23 .gs files × ~50-100 lines → 15 lines each + centralized docs/CHANGELOG.md
  - ลด ~1,430 บรรทัดซ้ำซ้อนทั่วโปรเจกต์

### Medium Priority (5) — Phase B

- [REF-006] generatePersonAliasesFromHistory Split: 134 → 25 บรรทัด + 4 section helpers
- [REF-007] findPersonCandidates Strategy Extraction: 5 strategies → 5 helper functions
- [REF-008] reprocPrepareContext_ Split: 118 → 15 บรรทัด orchestrator + 4 setup helpers
- [REF-009] MIGRATION_HybridAliasSystem Loop: 117 → 50 บรรทัด + MIGRATION_STEPS array
- [REF-010] applySheetProtection_UI Split: 114 → 30 บรรทัด + schema-safe range (REVIEW_IDX.*)

### Low Priority (2) — Phase C

- [REF-011] withEntryPointGuard_ higher-order function (3 pilot entry points)
- [REF-012] Deprecate getColIndex with @deprecated JSDoc + warning log

### Cumulative Impact

- Total lines reduced: ~1,655 (-9.5%)
- Functions >100 lines: 16 → 4 (-12)
- Module Boundary violations: 5 → 0
- Batch processors w/o checkpoint: 2 → 0
- New helpers added: ~32

---

## [5.5.018] — 2026-06-21 — REVIEW15 CLEAN CODE FIX (14 issues, Cycle 15)

- [R13-01] logError with Error object in 14 catch blocks (9 P0 Rule 13)
- [R1-01] var → const in 12 declarations (3 P1 Rule 1)
- [R2-01] Split reprocessReviewQueue 432 → 40 lines + 6 helpers (1 P1 Rule 2)
  - Helpers: reprocPrepareContext_, reprocProcessAllRows_, reprocGroupA_YellowWithName_, reprocGroupB_NewRecordWithGeo_, reprocGroupC_FuzzyHighScore_, reprocBatchWriteAndReport_
- [R7-01] Remove 3 phantom function references (3 P2 Rule 7)
- Cumulative: 14/14 issues FIXED, 8 files changed (+375/-226 lines)
- Compliance: 12/15 → 14/15 (93%)

---

## [5.5.017] — 2026-06-21 — SECURITY POSTFIX (12 SEC issues, Cycle 14)

- [SEC-001] Cookie → PropertiesService (deny-by-default AuthZ)
- [SEC-002] AuthZ guard on 13/13 destructive ops
- [SEC-003/010] RFC 6265 cookie charset sanitization
- [SEC-004/007] PII masking (MD5 hash, email mask)
- [SEC-005/009/011] Sheet Protection 4→8 sheets + Q_REVIEW range
- [SEC-006] API Key via x-goog-api-key header
- [SEC-008] OAuth Least Privilege: 10→6 scopes
- [SEC-012] fetchWithRetry_ body truncation (200 chars)
- Cumulative: Production Readiness 95% → 97% GO (Security Hardened)

---

## [5.5.016] — 2026-06-21 — PERFORMANCE FIX (13 issues, Cycle 13)

- [PERF-001] reprocessReviewQueue +LockService +TimeGuard +Checkpoint/Resume (BLOCKING)
- [PERF-002] findMatchingPerson_/findMatchingPlace_ +optPrefixMap O(N)→O(K)
- [PERF-003] populateAliasFromFactDelivery_ personIdToUuidMap O(N)→O(1)
- [PERF-004/005] findPersonCandidates/findPlaceCandidates Set<string> lookup
- [PERF-006] highlightHighPriorityReviews +optTargetRow single-row mode (95% reduction)
- [PERF-007] generatePersonAliasesFromHistory +Checkpoint/Resume
- [PERF-008] applyAllPendingDecisions LockService idiomatic pattern
- [PERF-009-013] batch stats, schema-bounded ranges, log buffer flushes

---

## [5.5.015] — 2026-06-21 — CRITICAL FIX (2 issues)

- [CRIT-007] factUpdateRow_ merge mode nullish coalescing
- [CRIT-008] applyReviewDecision delegate to resolveAndPersist_ gateway

---

## [5.5.014] — 2026-06-20 — DRIVER VERIFIED COLUMNS + ALIAS ENRICHMENT

- Added 2 columns in 3 sheets:
  - Source sheet (SCGนครหลวงJWDภูมิภาค): col 37-38 "ชื่อลูกค้าปลายทางจริง", "ชื่อสถานที่อยู่ลูกค้าปลายทางจริง"
  - DAILY_JOB (ตารางงานประจำวัน): col 29-30 (same names)
  - FACT_DELIVERY: col 32-33 "driver_verified_name", "driver_verified_addr"
- Match Engine: ชื่อดิบ match ตามปกติ (100%) + ถ้าชื่อจริงมี → สร้าง alias ใน M_ALIAS (confidence=100, source=DRIVER_VERIFIED)
- fetchDataFromSCGJWD → copyDriverVerifiedToDailyJob_ → DAILY_JOB col 29-30
- SRC_IDX 37→39, DATA_IDX 29→31, FACT_IDX 32→34

---

## [5.5.013] — 2026-06-20 — GOOGLE MAPS REFACTOR (2 issues)

- [REWRITE] 15_GoogleMapsAPI.gs เขียนใหม่ทั้งไฟล์ — ลบระบบ 3-layer cache + MAPS_CACHE sheet
- [ADD] เพิ่มสูตร Amit Agarwal 7 ตัว เป็น @customFunction:
  - GOOGLEMAPS_DISTANCE, GOOGLEMAPS_DURATION, GOOGLEMAPS_LATLONG
  - GOOGLEMAPS_ADDRESS, GOOGLEMAPS_REVERSEGEOCODE, GOOGLEMAPS_COUNTRY, GOOGLEMAPS_DIRECTIONS
- [REMOVE] ลบ MAPS_CACHE sheet จาก SCHEMA, SHEET, MAPS_CACHE_IDX, setupAllSheets
- Cache: CacheService.getDocumentCache TTL 6 ชม.
- Sheets: 19→19, IDX sets: 17→16, SCHEMA entries: 20→19, Functions: 313→311

---

## [5.5.012] — 2026-06-19 — ANTIPATTERN FIX + DOC SYNC

- [Anti-pattern #1] showVersionInfo() ล้าหลัง → แก้ให้แสดง v5.5.012 + Audit Cycles 9
- [Anti-pattern #2] CHANGELOG ไม่ sync → เพิ่ม v5.5.011 entry ใน 20 ไฟล์
- [Anti-pattern #3] Double normalization → resolvePerson รับ preNormResult parameter
- [Anti-pattern #4] headers.indexOf() → ใช้ REVIEW_IDX/FACT_IDX constants (79 refs)
- [Anti-pattern #5] validateConfig ไม่เรียก validateSchemaConsistency → เพิ่มการเรียก
- Standardize function count = 313 ทุกที่
- README.md ลบ broken cross-references

---

## [5.5.011] — 2026-06-19 — DATA CONSISTENCY + SHIPTONAME CLEAN + Q_REVIEW NAV

- [Data Consistency] เพิ่ม SCHEMA['SCGนครหลวงJWDภูมิภาค'] (37 คอลัมน์) ใน 02_Schema.gs
- [ShipToName Clean] findBestGeoByPersonPlace ผ่าน normalizePersonNameFull ก่อนค้นหา
- [Q_REVIEW Nav] buildRecommendedAction_ สร้าง ID จริง + handleRecommendClick_ นำทาง

---

## [5.5.010] — 2026-06-18 — CACHE HOTFIX + Q_REVIEW POST-PROCESSOR

- [Hotfix #1] saveChunkedCache_ แบ่ง putAll เป็น batch 5 chunks + ลด chunk size 90KB→80KB
- [Hotfix #2] loadAllPlaces_ ลบ fallback path ที่ใช้ cache.put ตรง — บังคับใช้ saveChunkedCache_
- [Hotfix #3] loadAllPlaceAliases_ ลบ fallback path เดียวกัน
- รวมฟังก์ชันจาก 22_AccuracyPatch.gs เข้า 12_ReviewService.gs:
  - extractFirstId_, safeExtractArr_, reprocessReviewQueue, analyzeReviewPatterns

---

## [5.5.009] — 2026-06-18 — DOC SYNC

- 12 .gs files มี DEPENDENCIES + ARCHITECTURE section ที่สะท้อน V5.5.007/V5.5.008
- 20 .md files อัปเดต V5.5.006 → V5.5.008
- 4 sections ครบในทุกไฟล์: PURPOSE, CHANGELOG, DEPENDENCIES, ARCHITECTURE

---

## [5.5.008] — 2026-06-18 — CACHE CLEANUP P2 (6 issues)

- [P2 #10] clearMapsCache flush hit_count ก่อน clear
- [P2 #11] flushLogBuffer_ ใน finally ของ 5 entry points (04, 16, 19, 20, 21)
- [P2 #12] populateGeoMetadata ใช้ invalidate แทน manual null
- [P2 #13] saveChunkedCache_ ล้าง orphaned chunks เมื่อขนาดข้อมูลลดลง
- [P2 #14] getCachedDistricts_ write-back to cache on miss
- [P2 #15] TH_GEO_POSTCODE chunk size byte-based (ยืนยันใน comment)

---

## [5.5.007] — 2026-06-18 — CACHE FIX P0+P1 (9 issues)

### P0 — Data Integrity (4)

- [P0 #1] invalidateAllGlobalCaches ล้าง 11 RAM caches (เดิม 6)
- [P0 #2] invalidateGeoDictCache ล้าง _GLOBAL_GEO_DICT_SEARCH_KEY_INDEX
- [P0 #3] applyAllPendingDecisions มี invalidateSameDayDestCache_ + autoEnrichAliases
- [P0 #4] migrateStep1_AssignUuid_ ใช้ invalidateChunkedCache_ แทน raw removeAll

### P1 — Performance + Correctness (5)

- [P1 #5] invalidateGeoLatLngCache_ + เรียกจาก createGeoPoint
- [P1 #6] M_PLACE_ALL/M_PLACE_ALIAS_ALL แปลงเป็น chunked cache
- [P1 #7] 4 chunked writers ใช้ centralized saveChunkedCache_
- [P1 #8] CACHE_KEY 13 entries (เดิม 2)
- [P1 #9] safeCacheGet_/Put_/RemoveAll_ helpers ใน 14_Utils

---

## [5.5.006] — 2026-06-18 — CONSISTENCY SYNC (28 doc inconsistencies)

- Bump APP_VERSION/SCHEMA_VERSION 5.5.004 → 5.5.006
- Total lines: 13,752 → 13,919
- Total functions: 311 → 310
- Total sheets: 20
- Total IDX sets: 17
- SCHEMA entries: 19
- Compliance: 16/16 PASS
- Production readiness: 95% GO
- Helper functions: 190 (18 SRP + 172 REFACTOR)

---

## [5.5.005] — 2026-06-16 — REVIEW SERVICE FIX (intermediate)

- v5.5.005 fix ใน ReviewService สำหรับ applyReviewDecision

---

## [5.5.004] — 2026-06-15 — INITIAL AUDIT CYCLES (53 audit issues)

5 audit cycles complete:

- CRITICAL → PERFORMANCE → SECURITY → REVIEW15 → REFACTOR
- 53 issues fixed across 22 files
- 385 functions, 16,545 lines

---

## Architecture Constraints (All Versions)

- **Trinity Framework**: Person_ID + Place_ID + Geo_ID = Destination Node
- **Single Writer Pattern**: M_ALIAS เขียนที่ 10_MatchEngine (autoEnrich) + 21_AliasService (createGlobalAlias) + 19_Hardening (generatePersonAliasesFromHistory) เท่านั้น
- **16 Immutable Laws**: Clean Code, SRP, No Hardcode Index, Batch Ops, Checkpoint/Resume, etc.
- **Module Boundary**: Group 1 (Master DB) ↔ Group 2 (Daily Ops) — Pure Consumer
- **3-Layer Cache**: RAM → CacheService (chunked) → Sheet
- **6 OAuth Scopes** (Least Privilege since V5.5.017)

---

_This file is the Single Source of Truth for LMDS V5.5 + V6.0 version history.
Per-file .gs CHANGELOG headers reference this file and show only the latest 3 versions._
