<!-- DOC-TYPE: historical -->

# Agent: Agent 3 (Domain-Logic)

**Date:** 2026-07-26T15:31:57Z
**Repo:** /home/user/webapp/audit/repo-git

## Raw output from check scripts

📋 DM-001: Match Engine 8-rule decision matrix
📊 Rule markers found: 21 (need 8)
📊 Outcomes: MERGE=7 CREATE=4 ESCALATE=10 IGNORE=15
✅ Match Engine looks complete (8 rules + 3 required outcomes + IGNORE optional)

📋 DM-002: Single Writer Pattern
✅ Only Group 1 writes master sheets (verified via setValues/setValue/appendRow)

📋 DM-003: Hybrid Alias single writer
✅ M_ALIAS only written via 21_AliasService

📋 DM-004: RBAC deny-by-default
📊 isAuthorizedUser_ references: 8
📊 Deny-by-default patterns: 5
📊 Menu items: 0
📊 isAuthorizedUser calls in App: 1
✅ RBAC structure looks correct

📋 DM-005: Invoice number normalization (Law 21)
✅ All invoice handling uses normalizeInvoiceNo_()

📋 DM-006: Thai prefix stripping (Thai data helper)
📊 Total Thai string literals (rough count): 208
✅ Thai prefix stripping looks complete

📋 DM-007: Hardcoded secrets (SEC-007)
🔍 Using grep fallback (install gitleaks for thorough check)
✅ No obvious hardcoded secrets (heuristic only)

📋 DM-008: PII masking in logs (SEC-008)
📊 Files with logging: 30
📊 Files with mask helper: 9
📊 Files logging PII without masker: 0
✅ No PII logging without masker detected

📋 DM-009: Sheet protection on master sheets
📊 Checking files: src/O_core_system/03_SetupSheets.gs src/O_core_system/19_Hardening.gs src/O_core_system/22_WebApp.gs
src/O_core_system/03_SetupSheets.gs: 0 protect-related calls
src/O_core_system/19_Hardening.gs: 20 protect-related calls
src/O_core_system/22_WebApp.gs: 0 protect-related calls
📊 Total protect/Protection calls: 20
📊 Master sheets with protection: 4 / 8
✅ Sheet protection in place (20 calls across 3 files)

📋 DM-010: Formula injection prevention
✅ No formula injection risk detected (heuristic)

📋 DM-011: Q_REVIEW decision routing (MAKE_MATCH_DECISION)
📊 Found match decision function in: src/1_group1_master_db/10_MatchEngine.gs
📊 Checking return shapes per outcome:
✅ MERGE — return shape OK (action + supporting fields)
✅ CREATE — return shape OK (action + supporting fields)
✅ ESCALATE — return shape OK (action + supporting fields)
ℹ️ IGNORE — not found as explicit outcome (may be implicit null return)
✅ Q_REVIEW routing detected
✅ Q_REVIEW decision routing looks correct

📋 DM-012: No data contamination (Law 1 architect)
📊 Found ingest pipeline: src/2_group2_daily_ops/04_SourceRepository.gs
✅ 04_SourceRepository.gs has ingest entry function
✅ No data contamination detected — raw data flows through ingest pipeline

📋 DM-013: SEC-001 Hardcoded OAuth credentials

📊 Files scanned: 39
📊 Hardcoded secrets found: 0
✅ No hardcoded OAuth credentials or API keys detected

📋 DM-014: SEC-002 OAuth scope least privilege
📊 Total OAuth scopes: 6
📊 Scopes in use: - https://www.googleapis.com/auth/spreadsheets - https://www.googleapis.com/auth/userinfo.email - https://www.googleapis.com/auth/script.storage - https://www.googleapis.com/auth/script.container.ui - https://www.googleapis.com/auth/script.scriptapp - https://www.googleapis.com/auth/script.external_request

⚠️ 1 broad scope(s) in use (may be necessary — review each)
ℹ️ Some broad scopes may be required (e.g. spreadsheets for master data writes)
💡 Consider .readonly alternatives where possible

📋 DM-015: SEC-003 Cookie CRLF injection prevention
📊 sanitizeCookie_ found in: src/2_group2_daily_ops/18_ServiceSCG.gs
✅ RFC 6265 cookie sanitization pattern detected
✅ Cookie sanitization in place

📋 DM-016: SEC-004 PII hashing + fetchWithRetry body truncation
📊 PII helper found: maskReviewerEmail_
📊 fetchWithRetry_ found in: src/2_group2_daily_ops/18_ServiceSCG.gs
✅ fetchWithRetry_ does not log response body (no leak risk — no truncation needed)
📊 Files with logError: 30
📊 Files with logError AND masker: 2
✅ PII masking + body truncation in place

📋 DM-017: SEC-005 + SEC-011 Sheet protection completeness
📊 Protection function in: src/O_core_system/19_Hardening.gs
📊 Protected master sheets: 6 / 9
📊 Protected: M_PERSON M_PLACE M_GEO_POINT M_ALIAS FACT_DELIVERY Q_REVIEW
📊 Unprotected: M_DESTINATION M_DAILY_JOB SYS_TH_GEO
✅ Q_REVIEW uses Range Protection (allows reviewer to edit R-V)
✅ Sufficient protection (6/9 — ≥70%)

📋 DM-018: SEC-006 API key in URL (must use header)
📊 Files with UrlFetchApp/fetchWithRetry: 4
📊 API key in URL violations: 0
✅ No API keys passed via URL parameter (using headers correctly)

📋 DM-019: SEC-009 RFC 6265 cookie regex compliance
📊 Checking: src/2_group2_daily_ops/18_ServiceSCG.gs
✅ Found RFC 6265 indicator: RFC6265
✅ Found RFC 6265 indicator: [;, "\\]

📊 sanitizeCookie_ files: 1
📊 RFC 6265 compliant: 1
📊 Issues: 0
✅ Cookie sanitization uses RFC 6265 compliant regex

📋 DM-020: SEC-012 fetchWithRetry_ response body leak in log
📊 Checking: src/2_group2_daily_ops/18_ServiceSCG.gs
✅ fetchWithRetry_ does not log response body (no leak risk)

📊 Total violations: 0
✅ fetchWithRetry_ response body leak prevention in place

📋 DM-021: SEC-002 + SEC-010 AuthZ guard + audit trail
📊 Destructive functions detected: 15
📊 With AuthZ guard: 5
📊 With audit trail: 0

⚠️ Functions without AuthZ guard (showing first 10): - src/1_group1_master_db/06_PersonService.gs:717 updatePersonStats - src/1_group1_master_db/06_PersonService.gs:690 createPersonAlias - src/1_group1_master_db/07_PlaceService.gs:873 updatePlaceStats - src/1_group1_master_db/07_PlaceService.gs:845 createPlaceAlias - src/1_group1_master_db/08_GeoService.gs:332 updateGeoStats - src/1_group1_master_db/09_DestinationService.gs:161 updateDestinationStats

📊 AuthZ guard coverage: 33%
📊 Audit trail coverage: 0%
✅ AuthZ guard coverage sufficient (≥30%)
ℹ️ 6 public functions lack direct guard — manual review:
(likely stat-updaters called by guarded entry points) - src/1_group1_master_db/06_PersonService.gs:717 updatePersonStats - src/1_group1_master_db/06_PersonService.gs:690 createPersonAlias - src/1_group1_master_db/07_PlaceService.gs:873 updatePlaceStats - src/1_group1_master_db/07_PlaceService.gs:845 createPlaceAlias - src/1_group1_master_db/08_GeoService.gs:332 updateGeoStats - src/1_group1_master_db/09_DestinationService.gs:161 updateDestinationStats
⚠️ Audit trail coverage < 50% — many destructive ops not recorded
💡 Fix: Add logAction_() or AuditTrailService.record() after each destructive op
