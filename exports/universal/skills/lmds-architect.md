<!-- DOC-TYPE: living -->
# lmds-architect

# Master Architecture

LMDS V6.0 Architect — Master Knowledge Base
Status: V6.0.046 Production Ready (96%) — 18 audit cycles, 116 issues fixed
Scope: 35 .gs files (34 production + 1 legacy 99_Legacy.gs) + 19 .html files
Volume: ~27,213 lines (.gs only, non-blank) — 535 functions

This is the master skill for the LMDS (Logistics Master Data System) project. Load this first whenever working on the repo — all other LMDS skills (lmds-code-reviewer, lmds-bug-hunter, lmds-match-engine-builder, etc.) build on this knowledge.

1. Project Identity
Field	Value
System name	LMDS (Logistics Master Data System)
Version	6.0.046 (set in 01_Config.APP_VERSION and 02_Schema.SCHEMA_VERSION)
Platform	Google Apps Script (V8 runtime) + Google Sheets
Domain	Logistics / Delivery for SCG JWD (Thailand)
Repo	https://github.com/Siriwat08/phaopanya-scg
License	MIT
Last updated	2026-07-13
Tech stack

Runtime: Google Apps Script V8 (JavaScript ES2022)

Database: Google Sheets (used as RDBMS — 19 sheets, 16 IDX sets, 19 SCHEMA definitions)

External APIs: Google Maps (Geocoding), Gemini (AI — currently disabled in prod), Telegram Bot (alerts), SCG e-POD FSM API

Frontend: Vanilla JS + Chart.js + Leaflet.js (in WebApp)

CI/CD: clasp + 8 GitHub Actions workflows

Quality tools: ESLint (with eslint-plugin-googleappsscript) + Prettier

Secret scan: Gitleaks + CodeQL

Tests: Jest unit + 29_SnapshotTest.gs + 10d_MatchTestHarness.gs

2. Architecture — 3-Domain Groups (The Iron Rule)
text

Copy
┌─────────────────────────────────────────────────────────────┐

│           00_App.gs (Menu + Triggers + Orchestration)        │

└──────┬──────────────────────────────────┬───────────────────┘

       │                                  │

       ▼                                  ▼

┌──────────────────┐              ┌──────────────────┐

│ 🟩 Group 1       │              │ 🟦 Group 2       │

│ Master DB        │◄───reads─────│ Daily Ops        │

│ (The Brain)      │              │ (Pure Consumer)  │

│                  │              │                  │

│ Single Writer    │              │  ❌ NEVER writes  │

│ of M_ALIAS,      │              │  Master sheets   │

│ M_PERSON,        │              │                  │

│ M_PLACE,         │              │  ✅ May write:    │

│ M_GEO_POINT,     │              │  FACT_DELIVERY,  │

│ M_DESTINATION    │              │  Q_REVIEW,       │

│                  │              │  daily sheets    │

└──────────────────┘              └──────────────────┘
File map (35 .gs + 1 source dir)
NOTE: The src/ directory structure described in CONTRIBUTING.md and CI is the target structure. The current repo at this skill's snapshot has .gs files living in the actual Apps Script project (not in this repo). All knowledge below applies to the src/ tree.

#	File	Group	Purpose
00	00_App.gs	Core	onOpen menu, runFullPipeline, onEdit, onSelectionChange, checkSystemIntegrity
01	01_Config.gs	Core	CONFIG, AI_CONFIG, SCG_CONFIG, APP_CONST, SHEET, all *_IDX constants
02	02_Schema.gs	Core	SCHEMA definitions for all 19 sheets, header validators
03	03_SetupSheets.gs	Core	setupAllSheets(), logInfo/Warn/Error/Debug, flushLogBuffer_
04	04_SourceRepository.gs	Daily	runLoadSource, getAllSourceRows, getUnprocessedRows, invalidateSourceCache
05	05_NormalizeService.gs	Master	Thai name/address cleaning (80+ prefixes), phonetic keys, normalizeForCompare
06	06_PersonService.gs	Master	Person CRUD + 5-strategy search (resolvePerson, findPersonCandidates, scorePersonCandidate, createPerson, mergePersonRecords)
07	07_PlaceService.gs	Master	Place CRUD + Geo extraction + address enrichment
08	08_GeoService.gs	Master	Geo CRUD + proximity analysis + loadAllGeos_
09	09_DestinationService.gs	Master	Trinity Intersection: Person+Place+Geo → Destination
10	10_MatchEngine.gs	Master ⭐	runMatchEngine, processOneRow, makeMatchDecision, executeDecision, autoEnrichAliasesFromFactBatch_ (single writer of M_ALIAS in auto-pipeline)
10b	10b_MatchDecision.gs	Master	Decision rules split from 10
10d	10d_MatchTestHarness.gs	Master	runMatchTest — dry-run testing
10e	10e_MatchResolvePersist.gs	Master	resolveAndPersistMerge_ — split from 10
11	11_TransactionService.gs	Daily	FACT_DELIVERY CRUD, upsertFactDelivery, invalidateFactInvoiceCache_
12	12_ReviewService.gs	Daily	Q_REVIEW management, applyReviewDecision, applyAllPendingDecisions, getReviewStats
12b	12b_ReviewReprocessor.gs	Daily	reprocessReviewQueue (post-processor)
13	13_ReportService.gs	Daily	Reports incl. buildFullQualityReport
14	14_Utils.gs	Core	levenshteinDistance, diceCoefficient, haversineDistanceM, generateShortId, callGeminiAPI, normalizeInvoiceNo, callSpreadsheetWithRetry, batchUpdateEntityStats_, saveChunkedCache_/loadChunkedCache_, isAuthorizedUser_
15	15_GoogleMapsAPI.gs	Daily	geocodeAddress, reverseGeocode, cachedGeoLookup_, getRouteDistanceKm, clearMapsCache
16	16_GeoDictionaryBuilder.gs	Master	buildGeoDictionary, lookupByPostcode, lookupPostcodeByArea, scanAddressAgainstDictionary
17	17_SearchService.gs	Daily	findBestGeoByPersonPlace, runLookupEnrichment — 2-Tier (M_ALIAS Fast Track + Person Resolve)
18	18_ServiceSCG.gs	Daily	SCG e-POD API: fetchDataFromSCGJWD, applyMasterCoordinatesToDailyJob, buildOwnerSummary, buildShipmentSummary
19	19_Hardening.gs	Core	runPreflightAudit, detectDoubleProcessing, generatePersonAliasesFromHistory, applySheetProtection_UI
20	20_ThGeoService.gs	Master	Thai geo extraction, populateGeoMetadata
21	21_AliasService.gs	Master	Hybrid Alias: resolveMasterUuidViaGlobalAlias, fastLookupByShipToName, createGlobalAlias (admin/migration writer), assignMasterUuidIfMissing, MIGRATION_HybridAliasSystem
22	22_WebApp.gs	Core	doGet, getAppHtml, include_ (Dashboard server)
22b	22b_WebAppViews.gs	Core	getDashboardData, getQReviewData, getFactDeliveryData
22c	22c_WebAppActions.gs	Core	handleAction, applyDecisionFromWebApp
24	24_PipelineManager.gs	Pipeline Mgr	Smart scheduling, runPipelinePreflight, scheduleNextRun, sendTelegramAlert
26	26_AuditTrailService.gs	Core	logAuditEvent, getAuditTrail
27	27_RbacService.gs	Core	isAuthorizedUser_, getUserRole, canPerformAction (3-role RBAC)
28	28_WebAppActions.gs	Core	handleMobileAction, getMobileMenuData (mobile menu)
29	29_SnapshotTest.gs	Core	runSnapshotTest, compareSnapshots
99	99_Legacy.gs	Legacy	Deprecated functions, compatibility shims
Domain dependency rules (Zero Tolerance)
1.
Group 1 = Single Writer of Master sheets (M_PERSON, M_PLACE, M_GEO_POINT, M_DESTINATION, M_ALIAS).
2.
M_ALIAS specifically may be written only by:

autoEnrichAliasesFromFactBatch_() in 10_MatchEngine.gs (auto-pipeline), OR

createGlobalAlias() in 21_AliasService.gs (admin/migration)

3.
Group 2 = Pure Consumer. Group 2 may read master, may write to FACT_DELIVERY / Q_REVIEW / ตารางงานประจำวัน / SCGนครหลวงJWDภูมิภาค / สรุป_*. NEVER to M_ALIAS / M_PERSON / M_PLACE / M_GEO_POINT / M_DESTINATION directly — must call Group 1 helpers (e.g. resolveAndPersist_ gateway).
4.
Cross-group writes must go through a resolveAndPersist_ gateway, never direct setValues to master sheets.
3. The 16 Immutable Laws (Zero Tolerance)
The full enforcement is in lmds-code-reviewer skill. Quick reference:

#	Law	One-line
1	Clean Code	camelCase, no var (use const/let), ESLint 0 errors
2	SRP	1 function = 1 job (~30-50 lines, max 100). Use _ suffix for private helpers
3	No Hardcode Index	Use row[PERSON_IDX.NAME] not row[7]. getRange() adds 1
4	Batch Operations	setValues() not setValue(). Chunked arrays if >10K rows
5	Checkpoint & Resume	Pipeline >1K rows or >2 min → Time Guard + saveCheckpoint_ + auto-resume trigger
6	Document Dependencies	Every file has DEPENDENCIES section in header
7	No Phantom Calls	Don't call functions that don't exist; no undefined globals
8	Namespace Pattern	Module prefix + _ suffix. No duplicate function names across files
9	No Global State	Don't declare var temp = {} outside 01_Config.gs. Use CONFIG.* or CacheService
10	Lock Library Version	Pin version: '8', never HEAD
11	Separate HTML	.html files via HtmlService.createHtmlOutputFromFile() and include()
12	Error Handling	Entry points have try-catch + logError(module, msg, err). No silent fail
13	Logging with Context	logError includes `e.stack
14	Structured File Names	XX_ComponentName.gs (00-21 for load order)
15	Full Files Only	Output 100% of file (no ... or // old code)
16	Security-First	Secrets in PropertiesService (not Cells), AuthZ guards on destructive ops, PII masking, API key in HTTP header
Plus 5 hard rules (zero tolerance):


17 Schema Truthfulness — read index from 01_Config + 02_Schema; if changing, update both

18 Read All Dependencies First — before editing, read all files in module-map

19 Never Remove Triggers Blindly — filter by trigger ID, store ID in ScriptProperties

20 Cache Invalidation Chain — every master write must call invalidate*Cache_()

21 Invoice No Normalization — use normalizeInvoiceNo() from 14_Utils.gs (prevents scientific notation bug 1.22e+23)

4. Data Model — 19 Sheets, 16 IDX Sets, 19 SCHEMA
Sheet names (Thai-aware — use exact strings, NEVER rename)
javascript

Copy
SHEET = {

  PERSON:           'M_PERSON',

  PERSON_ALIAS:     'M_PERSON_ALIAS',  // kept for legacy; new aliases go to M_ALIAS

  PLACE:            'M_PLACE',

  PLACE_ALIAS:      'M_PLACE_ALIAS',   // kept for legacy; new aliases go to M_ALIAS

  ALIAS:            'M_ALIAS',         // Hybrid Alias central table

  GEO_POINT:        'M_GEO_POINT',

  DESTINATION:      'M_DESTINATION',

  FACT_DELIVERY:    'FACT_DELIVERY',   // 34 cols (FACT_IDX)

  Q_REVIEW:         'Q_REVIEW',        // 22 cols

  SOURCE:           'SCGนครหลวงJWDภูมิภาค',  // ⚠ Thai name

  DAILY_JOB:        'ตารางงานประจำวัน',       // ⚠ Thai name

  TH_GEO:           'SYS_TH_GEO',      // 7,537 rows

  SYS_LOG:          'SYS_LOG',

  SYS_CONFIG:       'SYS_CONFIG',

  EMPLOYEE:         'ข้อมูลพนักงาน',          // ⚠ Thai name

  INPUT:            'Input',           // cookie + shipmentNos

  OWNER_SUMMARY:    'สรุป_เจ้าของสินค้า',     // ⚠ Thai name

  SHIPMENT_SUMMARY: 'สรุป_Shipment',         // ⚠ Thai name

  RPT_DATA_QUALITY: 'RPT_DATA_QUALITY'

}

// V5.5.013: MAPS_CACHE removed (replaced by @customFunction formulas)
IDX sets (in 01_Config.gs)

PERSON_IDX, PERSON_ALIAS_IDX, PLACE_IDX, PLACE_ALIAS_IDX, ALIAS_IDX

GEO_IDX, DEST_IDX

FACT_IDX (34 columns, 0-indexed)

Q_REVIEW_IDX (22 columns)

SOURCE_IDX, DAILY_JOB_IDX, EMPLOYEE_IDX

TH_GEO_IDX (16 metadata columns)

SYS_LOG_IDX, SYS_CONFIG_IDX, OWNER_SUMMARY_IDX, SHIPMENT_SUMMARY_IDX

INPUT_IDX, RPT_DATA_QUALITY_IDX

18 SCHEMA Definitions (was 19; MAPS_CACHE removed in V5.5.013).

Trinity framework (the conceptual model)
A complete Destination is the intersection of 3 FKs:

M_DESTINATION = M_PERSON × M_PLACE × M_GEO_POINT
All 3 FKs must be resolvable for the destination to be valid. A row with missing Geo is "pending geo", not a destination.

FACT_DELIVERY (34 cols, FACT_IDX)
Idx	Field	Note
0	tx_id	TX + 12 hex
1-3	source_sheet, source_row, source_record_id	lineage
4-5	delivery_date, delivery_time	
6-7	invoice_no, shipment_no	must use normalizeInvoiceNo()
8-9	driver_name, truck_license	
10-11	sold_to_code, sold_to_name	contextual disambiguation
12-13	ship_to_name, ship_to_address	search input
14	geo_resolved_addr	from LatLong
15-18	person_id, place_id, geo_id, dest_id	FKs
19	warehouse	
20-21	raw_lat, raw_lng	from source
22	match_status	FULL_MATCH / GEO_ANCHOR / FUZZY_MATCH / CREATE_NEW / NEEDS_REVIEW / REVIEW_INVALID / ERROR
23	match_confidence	0-100
24	match_reason	human-readable
25	match_action	
26-27	resolved_lat, resolved_lng	
28-29	created_at, updated_at	
30	record_status	Active/Archived
31	match_evidence	name|phone|geo
32-33	driver_verified_name, driver_verified_addr	added V5.5.014
5. Match Engine V6.0 — 8 Rules
The 8-rule decision matrix lives in 10_MatchEngine.gs (makeMatchDecision) and was split into 10b_MatchDecision.gs. Evaluate in order, first match wins:

Rule	Trigger	Action	Priority
1	INVALID_LATLNG — raw_lat==0 && raw_lng==0 (or empty)	REVIEW_INVALID (confidence 0)	CRITICAL
2	LOW_QUALITY — name too short or address incomplete	REVIEW	HIGH
3	GEO_PROVINCE_CONFLICT — resolved province ≠ address province	REVIEW (conf 50)	HIGH
3.5	NEARBY_PENDING — Tiered Spatial: ≤50m → AutoMerge, 51-79m Yellow, 80-100m Orange, >100m new	per distance band	MEDIUM
4	FULL_MATCH — Person + Place + Geo all match	AUTO_MATCH (high conf)	—
5	GEO_ANCHOR — existing Geo + existing Person, Place may be new	AUTO_MATCH	—
6	FUZZY_MATCH — score ≥ THRESHOLD_AUTO (90)	AUTO_MATCH	—
7	ALL_NEW_WITH_GEO — everything new but has lat/lng	CREATE_NEW	—
8	DEFAULT — none of the above	REVIEW (NEEDS_REVIEW)	—
Key constants
javascript

Copy
AI_CONFIG = {

  THRESHOLD_AUTO:  90,

  THRESHOLD_REVIEW: 70,

  THRESHOLD_IGNORE: 50,

  GEO_GRID_SIZE:   0.01,    // ~1.1 km/cell

  GEO_RADIUS_M:    50,

  TIME_LIMIT_MS:   300000,  // 5 min (GAS allows 6)

  BATCH_SIZE:      20

}

APP_CONST = {

  STATUS_ACTIVE:   'Active',

  STATUS_ARCHIVED: 'Archived',

  STATUS_MERGED:   'Merged',

  COLOR_FOUND:     '#b6d7a8',  // green — high confidence

  COLOR_FALLBACK:  '#ffe599',  // yellow — fallback

  COLOR_NOT_FOUND: '#f4cccc',  // red — not found

  COLOR_BRANCH:    '#cfe2f3',  // blue — warehouse/SCG source

  MAX_RETRIES:     3,

  LOCK_TIMEOUT_MS: 10000,

  PIPELINE_BATCH:  50

}

APP_VERSION    = '6.0.046'

SCHEMA_VERSION = '6.0.046'
Match scoring strategies (Group 1)

06_PersonService uses 5 strategies: exact phone → exact name → exact phonetic → fuzzy name → hybrid context (sold_to_name tie-breaker)

Dynamic Weighting: weight depends on data completeness (if phone present, name weight reduces)

Contextual Disambiguation (V5.5.047): when names overlap, use sold_to_name as tie-breaker

Geofencing Tie-breaker (V5.5.047): use history + street distance

Search service (17_SearchService) — 2-Tier
text

Copy
Tier 0: M_ALIAS Fast Track  → fastLookupByShipToName()  // O(1) reverse index

Tier 1: resolvePerson() → getDestsByPersonId()

NOT_FOUND → return null (do NOT use unreliable data)
This is ShipToName-Only v5.4.003. The older 6-Tier was removed.

6. Hybrid Alias Architecture
The "Hybrid" comes from merging two legacy tables (M_PERSON_ALIAS + M_PLACE_ALIAS) into a single M_ALIAS table that uses a master_uuid to FK back to either a person or a place.

text

Copy
M_ALIAS (8 cols)

  0 alias_id         A + 12 hex

  1 master_uuid      FK → M_PERSON.master_uuid OR M_PLACE.master_uuid

  2 variant_name     the alternative spelling / abbreviation

  3 entity_type      'PERSON' | 'PLACE'

  4 confidence       0-1

  5 source           'FACT_DELIVERY' | 'MANUAL' | 'MIGRATION'

  6 created_at

  7 last_used
Self-Healing Alias (Phase 3 — V5.5.046+)
When Q_REVIEW.decision = MERGE_TO_CANDIDATE is approved, applyReviewDecision calls the single-writer autoEnrichAliasesFromFactBatch_() which adds a new row to M_ALIAS so the same mistake won't recur. Confidence is bumped each time the alias is re-validated.

Negative samples (SYS_NEGATIVE_SAMPLES)
Tracked separately — when admin picks IGNORE or chooses a different candidate, the rejected pair is logged so the engine doesn't propose it again. Synced with M_ALIAS lookups via the fast-track path.

Hybrid Alias Migration
MIGRATION_HybridAliasSystem() — one-shot migration:

1.
Copy M_PERSON_ALIAS → M_ALIAS
2.
Copy M_PLACE_ALIAS → M_ALIAS
3.
Assign master_uuid to all M_PERSON / M_PLACE rows that don't have one (assignMasterUuidIfMissing())
7. Core Workflows
Daily flow (Group 2 — fast path)
text

Copy
fetchDataFromSCGJWD()

  ↓ read SCG e-POD API

  ↓ write to "ตารางงานประจำวัน"

applyMasterCoordinatesToDailyJob()

  ↓ 17_SearchService.findBestGeoByPersonPlace()

  ↓ Tier 0: fastLookupByShipToName() (M_ALIAS reverse index)

  ↓ Tier 1: resolvePerson → getDestsByPersonId

  ↓ NOT_FOUND → null

  ↓ write LatLong_Actual + background color to DAILY_JOB
Master flow (Group 1 — full pipeline)
text

Copy
runMatchEngine()  // in 00_App.gs or menu

  ↓ for each PENDING source row:

  ↓   05_NormalizeService.normalizePersonNameFull / normalizePlaceName

  ↓   06_PersonService.resolvePerson      → may call createPerson

  ↓   07_PlaceService.resolvePlace        → 20_ThGeoService.extractGeoFromAddress

  ↓   08_GeoService.resolveGeo            → may call createGeoPoint

  ↓   09_DestinationService.resolveDestination  (Trinity check)

  ↓   makeMatchDecision()                  (8-rule matrix)

  ↓   executeDecision():

  ↓     AUTO_MATCH  → 11_TransactionService.upsertFactDelivery

  ↓     CREATE_NEW  → create master + upsertFactDelivery

  ↓     NEEDS_REVIEW → 12_ReviewService → Q_REVIEW

  ↓   autoEnrichAliasesFromFactBatch_()   (single writer, batched)
Pipeline resilience

Time Guard (hasTimePassed_()) every 100 rows

Checkpoint saved to PropertiesService (key: LMDS_PIPELINE_CURSOR)

Auto-Resume via time-based trigger installed by installAutoResume_()

Lock via LockService.getScriptLock(timeout=10000) for critical sections

8. Security Architecture — SEC-001 → SEC-012
All 12 issues fixed in V5.5.017 SECURITY-POSTFIX:

ID	Issue	Fix
SEC-001	Secrets in Sheet cells	PropertiesService.getScriptProperties() only
SEC-002	No AuthZ guard on destructive ops	isAuthorizedUser_() covers 13/13 destructive ops (deny-by-default)
SEC-003	Cookie CRLF injection	sanitizeCookie_() (RFC 6265 regex)
SEC-004	PII in logs	MD5 hash + email masking; fetchWithRetry_ truncates body to 200 chars
SEC-005	No sheet protection	8 sheets protected + Q_REVIEW range lock
SEC-006	API key in URL	x-goog-api-key HTTP header
SEC-007	Reviewer email not masked	maskReviewerEmail_() → s***i@company.com
SEC-008	OAuth scope creep	10 → 6 scopes (Least Privilege)
SEC-009	Cookie regex non-RFC	RFC 6265 compliant
SEC-010	PII masking incomplete	All log paths covered
SEC-011	Sheet protection incomplete	4 → 8 sheets + Q_REVIEW range
SEC-012	fetchWithRetry_ body leak	Truncate response body before log
OAuth scopes (current, 6)
json

Copy
[

  "https://www.googleapis.com/auth/spreadsheets",

  "https://www.googleapis.com/auth/userinfo.email",

  "https://www.googleapis.com/auth/script.storage",

  "https://www.googleapis.com/auth/script.container.ui",

  "https://www.googleapis.com/auth/script.scriptapp",

  "https://www.googleapis.com/auth/script.external_request"

]
RBAC (3 roles, in 27_RbacService.gs)
Role	Can do
Viewer	Read-only on FACT, RPT, WebApp Dashboard
Reviewer	+ Approve Q_REVIEW (CREATE_NEW, MERGE_TO_CANDIDATE, ESCALATE, IGNORE)
Admin	+ Master writes, full pipeline runs, system config, hard-reset operations
Admin list is stored in PropertiesService as LMDS_ADMINS (comma-separated emails). Replaces the older ADMIN_EMAILS (legacy key still read for back-compat).

8 Protected sheets (V5.5.017 expanded)
ข้อมูลพนักงาน, M_PERSON, SCGนครหลวงJWDภูมิภาค, M_GEO_POINT, M_PLACE, M_DESTINATION, M_ALIAS, FACT_DELIVERY — protected via applySheetProtection_UI(). Plus Q_REVIEW range (reviewer + decision cols).

Input and SYS_CONFIG are hidden.

9. 3-Layer Cache (V5.5+)
text

Copy
L1: RAM cache (_GLOBAL_* in 01_Config)        → fastest, dies with script

        ↓ miss

L2: CacheService (100KB/key, 6h TTL)         → chunked if >100KB

        ↓ miss

L3: Sheet cache (or @customFunction formulas)  → persistent

        ↓ miss

    External API (Maps / SCG / Gemini)
V5.5.013 MAPS_CACHE sheet was removed. Maps lookups now use @customFunction formulas + RAM cache.

Cache invalidation chain (Law 20)
Every master write must call the matching invalidator:


invalidateAllGlobalCaches() — nuke everything (used by 🧹 ล้างความจำระบบ menu)

invalidateSourceCache() — after 04_SourceRepository writes

invalidateFactInvoiceCache_() — after 11_TransactionService writes

clearMapsCache() — 15_GoogleMapsAPI reset

For cache >100KB, use saveChunkedCache_() / loadChunkedCache_() (in 14_Utils.gs).

10. CI/CD — 8 GitHub Actions Workflows
#	Workflow	Trigger	Purpose
1	01-ci.yml	push / PR	Lint + Prettier + Syntax + Anti-pattern + Domain check + REVIEW15
2	02-deploy.yml	push to main	clasp push (flatten src/) + versioned deploy + Web App URL update + post-deploy diff verify
3	03-pr-validation.yml	PR	Size check + anti-pattern + version bump + Conventional Commits + auto-label
4	04-release.yml	push to main	Auto-bump version + tag + GitHub Release
5	05-scheduled-health.yml	Mon 09:00 ICT	Health stats + version consistency check
6	06-codeql.yml	push / PR / weekly	Semantic security analysis
7	07-doc-code-sync.yml	push / PR	9 checks (version, stats, paths, phantom deps, links, claimed fixes, changelog, dependencies, doc-type)
8	08-gitleaks.yml	push / PR	Hardcoded secret scan
GitHub Secrets (required for deploy)

CLASPRC — content of ~/.clasprc.json

APPS_SCRIPT_ID — Apps Script project ID (~57 chars)

DEPLOY_WEBHOOK (optional) — Discord/Slack webhook

Pre-commit hook (recommended)
scripts/pre-commit.sh blocks: hardcoded index, secrets, setValue in loop.

11. Decision Workflow — How to Use This Skill Stack
When the user asks anything about LMDS, follow this decision tree:

1.
"What is the project / overview / status" → use lmds-architect (this skill)
2.
"Is my code compliant with the 16 laws" → use lmds-code-reviewer
3.
"Find bugs / critical issues / performance" → use lmds-bug-hunter
4.
"Refactor this long function" → use lmds-refactor-advisor
5.
"Ready to deploy / pre-deploy check" → use lmds-predeploy-checker
6.
"Implement match logic / 8 rules / Trinity" → use lmds-match-engine-builder
7.
"GAS-specific concern: timeout, cache, batch" → use lmds-gas-best-practices
8.
"Build / fix CI / deploy pipeline" → use lmds-cicd-pipeline
9.
"Security check / SEC-001 to SEC-012" → use lmds-security-auditor
10.
"Thai name / address / geo normalization" → use lmds-thai-data-helper
12. Common Gotchas (Top 10)
1.
Sheet names are Thai — ตารางงานประจำวัน, SCGนครหลวงJWDภูมิภาค, ข้อมูลพนักงาน. Hardcoded everywhere. Don't rename.
2.
MAPS_CACHE is gone (V5.5.013). Don't recreate it. Use @customFunction instead.
3.
FACT_DELIVERY has 34 cols, not 32. V5.5.014 added driver_verified_name + driver_verified_addr. Same for SOURCE and DAILY_JOB.
4.
PERSON_IDX is 0-indexed but getRange() is 1-indexed. Always add 1: sheet.getRange(row, PERSON_IDX.NAME + 1).
5.
M_ALIAS single writer — if you're not in 10_MatchEngine or 21_AliasService, you cannot write to M_ALIAS.
6.
Group 2 never writes master — even reading M_PERSON.last_seen then writing back is forbidden; use batchUpdateEntityStats_().
7.
Invoice numbers get mangled by Sheets into scientific notation (1.22e+23). Always call normalizeInvoiceNo() from 14_Utils.gs before comparison or write.
8.
PII in logs is a SEC-004/SEC-010 violation — use md5Hash_() and maskReviewerEmail_(). Don't write raw emails.
9.
Triggers are sticky — never ScriptApp.getProjectTriggers() and deleteTrigger() blindly; filter by handler name + check ScriptProperties for stored trigger ID.
10.
6-min hard limit — anything that might run >2 min needs a Time Guard + installAutoResume_() trigger. AI_CONFIG.TIME_LIMIT_MS = 300000 (5 min, with 1 min buffer).
13. Reference Doc Map

README.md — quick start, install, deploy

CONTEXT.md — code conventions, build/test, rules summary

BLUEPRINT.md — full architecture, data model, 8 rules, security

LMDS Supreme Engineer.md — the system prompt for AI coding agents

CONTRIBUTING.md — git workflow, branch naming, commit conventions

SECURITY.md — vulnerability reporting policy

docs/01_SOP_Admin_LMDS.md — admin SOP (Thai, very detailed)

docs/02_IT_Guide_LMDS.md — IT installation & maintenance (Thai)

docs/03_Executive_Summary_LMDS.md — exec summary

docs/04_WebApp_Guide.md — WebApp usage

docs/01-github-actions-overview.md — CI/CD guide

14. Quick-Reference Recipe: Adding a New Feature
text

Copy
1. Identify which group (1 / 2 / system) — based on whether you read or write master

2. Create new file: NN_NewFeature.gs in the right src/<group>/ folder

3. Header must include:

   * /* FILE: NN_NewFeature.gs

   *  VERSION: 6.0.046

   *  DEPENDENCIES: 01_Config, 14_Utils, ...

   *  CALLED BY: 00_App, 11_TransactionService

   *  SHEETS TOUCHED: FACT_DELIVERY

   *  CACHE INVALIDATION: invalidateFactInvoiceCache_

   *  PURPOSE: ...

   *  */

4. Add menu item in 00_App.gs (under the right group)

5. Add config to 01_Config.gs if needed

6. Add SCHEMA entry to 02_Schema.gs if creating a sheet

7. Add IDX set to 01_Config.gs

8. Write the function with try-catch + logError if it's an entry point

9. Update README.md + CHANGELOG.md version

10. Bump version header in ALL files if version changes

11. Run /[CMD: REVIEW15] and /[CMD: BUGHUNT] before PR

12. CI runs the 8 workflows automatically
This 12-step recipe is the canonical way to add a feature. Skipping steps 3, 6, 7, 8, 9, 10 = guaranteed CI failure.