# 📊 LMDS V6.0 Pre-Delivery Audit Report

**Audited By:** Principal Software Auditor (AI Agent)
**Date:** 2026-07-23
**Repo:** https://github.com/Siriwat08/phaopanya-scg
**Version Audited:** 6.0.072 (commit: main branch)
**Standards Applied:** 16 Immutable Laws · SEC-001→012 · 35-item Pre-Deploy Checklist

---

## Phase 0 — Full Read Status

| รายการ | สถานะ | จำนวน |
|--------|--------|--------|
| .gs source files | ✅ อ่านครบ | 39/39 ไฟล์ |
| .html source files | ✅ อ่านครบ | 19/19 ไฟล์ |
| Docs root (README/BLUEPRINT/CONTEXT/SECURITY/CONTRIBUTING) | ✅ อ่านครบ | 5 ไฟล์ |
| docs/*.md | ✅ อ่านครบ | 30+ ไฟล์ รวม CHANGELOG, TODO, READINESS_AUDIT_FINAL, AI-REVIEW-PROTOCOL ฯลฯ |
| .skills/ SKILL.md | ✅ อ่านครบ | 12 ไฟล์ (1 consolidated lmds-supreme-engineer + 11 individual) |
| .github/workflows | ✅ อ่านครบ | 9 workflows (01-09) |
| appsscript.json | ✅ | runtimeVersion=V8, 6 OAuth scopes |
| .eslintrc.yml | ✅ | max-lines-per-function:200, complexity:30 |
| .github/dependabot.yml, labeler.yml | ✅ | ทำงานปกติ |

**Mental Model ที่สร้างได้:**
- **Data Flow:** Source → Normalize → MatchEngine (8 Rules) → AUTO_MATCH/CREATE_NEW/REVIEW → FACT_DELIVERY/Q_REVIEW → Alias Enrichment
- **4 Domain Groups:** O_core_system (14 files) → Group 1 Master DB (13 files) → Group 2 Daily Ops (8 files) → Group 4 Pipeline Mgr (1 file) + Group 3 WebApp (19 html)
- **Match Engine 8-Rules Matrix:** Rule1-NoGeo → Rule2-LowQuality → Rule3-GeoConflict → Rule3.5-NearbyPending → Rule4-FullMatch → Rule5-GeoPersonAnchor → Rule5b-PlaceOnlyNoName → Rule6-FuzzyMatch → Rule7-NewGeo → Rule8-NewGeoFromGPS
- **RBAC 3-Role:** Viewer (read-only) / Reviewer (+approve Q_REVIEW) / Admin (full)
- **Pipeline Chain:** loadSourceBatch_ → processOneRow → executeDecision → flushBatches_ → autoEnrichAliasesFromFactBatch_ → AutoResume (installAutoResume_)

✅ **Phase 0 เสร็จ — อ่านครบ 58 ไฟล์โค้ด, 35+ เอกสาร, 12 skills**

---

## Phase 1 — Technical Debt Analysis

### Technical Debt Inventory

| # | Category | File:Line | Description | Priority | Effort | Impact | Fix Suggestion |
|---|----------|-----------|-------------|----------|--------|--------|----------------|
| TD-001 | **A (Arch)** | `appsscript.json:13` | `access: "MYSELF"` — WebApp เข้าได้เฉพาะ deployer เท่านั้น ไม่ใช่ production-ready | **P0** | S | CRITICAL — user อื่นเข้า dashboard ไม่ได้ | เปลี่ยนเป็น `DOMAIN` (org) หรือ `ANYONE` (+ ทดสอบ RBAC ยังทำงานได้) |
| TD-002 | **A (Code)** | `10d_MatchTestHarness.gs:58` | `runTestMatchDryRun_` — 214 บรรทัด, CC=20 — ยาวเกิน rule 1.1 (>100 บรรทัด) | P1 | M | Medium — hard to maintain/test | แยกเป็น 3 helpers: `loadTestRows_()`, `processOneTestRow_()`, `buildTestSummary_()` |
| TD-003 | **A (Code)** | `22c_WebAppActions.gs:296` | `getReviewDetail` — 208 บรรทัด, CC=19 — WebApp endpoint เดี่ยวทำงานหลายอย่างเกินไป | P1 | M | Medium — SRP violation | แยก detail-building logic ออกเป็น `buildReviewDetailObject_()` helper |
| TD-004 | **A (Code)** | `24_PipelineManager.gs:568` | `runPipelineBatch` — 198 บรรทัด, CC=19 — God function สำหรับ pipeline execution | P1 | L | High — pipeline core ยาวมาก | แยกเป็น: `initBatch_()`, `processBatchChunk_()`, `finalizeBatch_()` |
| TD-005 | **A (Code)** | `22c_WebAppActions.gs:87` | `submitReviewDecision` — 195 บรรทัด, CC=18 — validation + dispatch + response ใน function เดียว | P1 | M | Medium | แยก validation block ออกเป็น `validateReviewDecisionInput_()` |
| TD-006 | **A (Code)** | `05_NormalizeService.gs:1230` | `phoneticSubstitute_` — CC=40 (สูงสุดในโปรเจกต์) ลำดับ if-else ยาวมาก | P1 | M | Medium — หากิดาเพิ่มยาก | เปลี่ยนเป็น lookup map: `const PHONETIC_MAP = { 'ก': 'K', 'ข': 'K', ... }` |
| TD-007 | **A (Code)** | `01_Config.gs:66` | `invalidateAllGlobalCaches` — CC=30 — เช็คทุก module ในฟังก์ชันเดียว | P2 | S | Low | ยอมรับได้ใน GAS (pattern ที่จำเป็น) — ถ้า refactor ใช้ registry pattern |
| TD-008 | **B (Data)** | `28_WebAppActions.gs:627-629` | `row[4]`, `row[5]`, `row[7]` — hardcoded magic indices ไม่ใช้ `TEST_MATCH_IDX` | P2 | S | Low | แทนด้วย `TEST_MATCH_IDX.ACTION`, `TEST_MATCH_IDX.REASON`, `TEST_MATCH_IDX.EVIDENCE` |
| TD-009 | **B (Data)** | `22b_WebAppViews.gs:743-746` | `row[0]`, `row[1]`, `row[2]`, `row[3]` — hardcoded indices ใน getMatchEngineMetrics | P2 | S | Low | สร้าง const ใน scope หรือเชื่อมกับ `PIPELINE_IDX` |
| TD-010 | **A (Code)** | `00_App.gs:837` | `cleanupAutoResumeTriggers_UI` — 127 บรรทัดใน App entry point ควรย้ายออก | P2 | S | Low | ย้าย body ไป `10h_MatchAutoResume.gs` เป็น `cleanupAutoResumeTriggers_()` helper |
| TD-011 | **D (Ops)** | `00_App.gs:showVersionInfo()` | Hardcoded "542 functions" แต่จริงๆ มี 544 functions (grep ยืนยัน) | P2 | S | Low | เปลี่ยนเป็น dynamic หรืออัปเดตเลข — เป็น cosmetic issue แต่ทำให้ version info ผิด |
| TD-012 | **C (Data)** | ทั้ง codebase | `SpreadsheetApp.flush()` — ไม่พบ การใช้งานเลยใน .gs ทั้งหมด | P2 | S | Medium | เพิ่ม `SpreadsheetApp.flush()` หลัง `setValues()` batches ที่สำคัญ (FACT_DELIVERY, Q_REVIEW) เพื่อยืนยัน write ก่อน read ต่อ |
| TD-013 | **D (Ops)** | `24_PipelineManager.gs:1370-1376` | `console.log/warn/error` fallback ใน `logPipeline_` — ปล่อยออก Stackdriver โดยตรง | P2 | S | Low | ยอมรับได้เป็น last-resort fallback — แต่ควร document ว่าเป็น intentional |
| TD-014 | **D (Ops)** | `BLUEPRINT.md:L40-100+` | หลาย section ใน BLUEPRINT.md เป็น placeholder "Same as before" — เอกสารไม่สมบูรณ์ | P2 | M | Medium | เขียน content จริงใน sections 2-9 แทน placeholder |
| TD-015 | **B (Arch)** | `21_AliasService.gs` | 1,796 บรรทัด (ไฟล์ใหญ่สุด) — deferred D-2 ตาม TODO.md | P2 | L | Low-Medium | Deferred ถูกต้อง — cohesion สูง split เมื่อ maintenance pain จริงๆ |
| TD-016 | **B (Arch)** | `05_NormalizeService.gs` | 1,419 บรรทัด — deferred D-3 ตาม TODO.md | P2 | L | Low-Medium | Deferred ถูกต้อง — เหมือน TD-015 |
| TD-017 | **D (Ops)** | `26_AuditTrailService.gs` | SYS_AUDIT_TRAIL มีข้อมูล แต่ไม่มี Dashboard view ใน WebApp | P2 | M | Low | เพิ่ม AuditTrail view ใน 22b_WebAppViews.gs เมื่อ Phase 5-6 complete |
| TD-018 | **A (Code)** | `22c_WebAppActions.gs:545` | `searchLocations` — 184 บรรทัด, CC=18 — ค้นหาหลาย entity type ในฟังก์ชันเดียว | P2 | M | Low | แยก search logic per entity: `searchPersons_()`, `searchPlaces_()`, `searchGeos_()` |

**Summary:**
- **Total: 18 items** (P0: 1 / P1: 5 / P2: 12)
- **Quick wins (< 1 day):** TD-008, TD-009, TD-010, TD-011 (4 items)
- **Critical (P0) ต้องแก้ก่อนส่งมอบ:** TD-001 (appsscript.json access)

---

## Phase 2 — Code Review Tips

### รวม .gs Files (39 ไฟล์)

---

### ไฟล์: `src/O_core_system/00_App.gs` (1,706 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- onEdit มี LockService guard (`tryLock(5000)`) + RBAC check ก่อน `applyReviewDecision` — ถูกต้องตาม SEC-002
- `safeRun()` wrapper ครอบทุก pipeline step — ป้องกัน uncaught exception
- `getPipelineDiagnosticSummary_()` แยกออกมา — clean SRP pattern
- `diagnoseSystemState()` แยกเป็น 4 sub-functions — rule 1.1 ปฏิบัติดี

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: cleanupAutoResumeTriggers_UI ยาวเกินไปสำหรับ App entry point**
- 📍 Location: `src/O_core_system/00_App.gs:837-964`
- 🔍 Issue: 127 บรรทัดอยู่ใน entry point file — logic จัดการ trigger ควรอยู่ใกล้ `10h_MatchAutoResume.gs`
- 💡 Suggestion:
  ```javascript
  // Before (ใน 00_App.gs — 127 lines)
  function cleanupAutoResumeTriggers_UI() {
    // ... 127 lines of trigger management ...
  }

  // After (ใน 00_App.gs — เหลือ 3 lines)
  function cleanupAutoResumeTriggers_UI() {
    try { return cleanupAutoResumeTriggers_(); }
    catch(e) { logError('App', e.message, e); safeUiAlert_('❌ ' + e.message); }
  }
  // ย้าย body ไปเป็น cleanupAutoResumeTriggers_() ใน 10h_MatchAutoResume.gs
  ```
- 🎯 Why: 00_App.gs ควรเป็น thin dispatcher เท่านั้น — ปัจจุบันอ้วนเกิน (1,706 บรรทัด)

**Tip #2: showVersionInfo() มีตัวเลขฮาร์ดโค้ดผิด**
- 📍 Location: `src/O_core_system/00_App.gs:~584`
- 🔍 Issue: ข้อความ `"39 .gs files | 542 functions"` แต่ `grep "^function "` ได้ **544** functions
- 💡 Suggestion:
  ```javascript
  // Before
  '📦 Source: 39 .gs files | 542 functions | 25,421 lines\\n'
  // After — ใช้ค่าจาก APP_STATS constant ใน 01_Config.gs
  '📦 Source: ' + APP_STATS.GS_FILES + ' .gs files | ' + APP_STATS.FUNCTIONS + ' functions\\n'
  ```
- 🎯 Why: ตัวเลขนี้จะเปลี่ยนทุก version — hardcode ทำให้ผิดได้ง่าย

---

### ไฟล์: `src/O_core_system/01_Config.gs` (899 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- `getGeminiApiKey()` validate format ก่อน return — ป้องกัน invalid key leak
- SCHEMA definitions ครบ 19 sheets
- `_IDX` constants ทุก sheet — Law 3 (Index-based access) ✅

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: COOKIE_CELL ยังคงค้างอยู่ใน SCG_CONFIG**
- 📍 Location: `src/O_core_system/01_Config.gs:595`
- 🔍 Issue: `COOKIE_CELL: 'B1'` มี comment `DEPRECATED` แต่ยังคงเป็น field ที่ active — 18_ServiceSCG.gs:304 ยังใช้มันเป็น fallback
- 💡 Suggestion: ถ้าจะ deprecate จริง ให้ mark ว่าจะลบใน V7.0 และใส่ migration warning ในฟังก์ชันที่ยังเรียกใช้

---

### ไฟล์: `src/O_core_system/14_Utils.gs` (1,454 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- `saveChunkedCache_` / `loadChunkedCache_` จัดการ CacheService 100KB limit — sophisticated solution
- `diceCoefficient()` + `levenshteinDistance()` — robust string matching
- `callSpreadsheetWithRetry()` — exponential backoff pattern ดีมาก
- `sanitizeForSheet_()` + `sanitizeRowForSheet_()` — ป้องกัน formula injection

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: saveChunkedCache_ ยาว 160 บรรทัด, CC=20**
- 📍 Location: `src/O_core_system/14_Utils.gs:1078-1238`
- 🔍 Issue: ทำ 3 strategy (single-key, putAll batch, fallback individual) ใน function เดียว — ยากทดสอบ
- 💡 Suggestion:
  ```javascript
  // แยก strategy เป็น 3 helpers:
  function saveCacheSingleKey_(cache, keyPrefix, json, ttl) { ... }
  function saveCacheBatch_(cache, keyPrefix, json, ttl) { ... }
  function saveCacheFallback_(cache, keyPrefix, json, ttl) { ... }
  // saveChunkedCache_ เป็น dispatcher เท่านั้น
  ```

---

### ไฟล์: `src/O_core_system/22b_WebAppViews.gs` (983 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- Pagination pattern สม่ำเสมอ — `parsePaginationParams_()` ใช้ DRY
- `getSourcePage` + `getFactDeliveryPage` batch read ด้วย `getValues()` ไม่ใช้ `getValue()` loop

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: Magic indices ใน getMatchEngineMetrics**
- 📍 Location: `src/O_core_system/22b_WebAppViews.gs:743-746`
- 🔍 Issue: `row[0]`, `row[1]`, `row[2]`, `row[3]` ไม่มี constant name — เมื่อ schema เปลี่ยน หาบรรทัดแก้ยากมาก
- 💡 Suggestion:
  ```javascript
  // Before
  const status = String(row[0] || '').trim();
  const score  = Number(row[1] || 0);
  const reason = String(row[2] || '').trim();
  const action = String(row[3] || '').trim();

  // After — ประกาศ local const ที่ top ของ function
  const PIPELINE_COL = { STATUS: 0, SCORE: 1, REASON: 2, ACTION: 3 };
  const status = String(row[PIPELINE_COL.STATUS] || '').trim();
  const score  = Number(row[PIPELINE_COL.SCORE]  || 0);
  ```

---

### ไฟล์: `src/O_core_system/22c_WebAppActions.gs` (935 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- `validateInput_()` applied ใน 3 endpoints — Rule SEC-003 ✅
- `maskEmailSafe_()` + `maskSearchQuery_()` ใน log — PII protection ✅
- `acquireScriptLockOrWarn_` ใน `submitReviewDecision` — ป้องกัน double-submit

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: getReviewDetail 208 บรรทัด — SRP violation**
- 📍 Location: `src/O_core_system/22c_WebAppActions.gs:296-504`
- 🔍 Issue: Function เดียวทำ: อ่าน Q_REVIEW row, resolve names, build candidates list, format response — 4 concerns ใน function เดียว
- 💡 Suggestion:
  ```javascript
  function getReviewDetail(reviewId) {
    const rawRow = readQReviewRow_(reviewId);           // 20 lines
    const names  = resolveEntityNames_(rawRow);         // 30 lines
    const cands  = buildCandidatesList_(rawRow, names); // 50 lines
    return formatDetailResponse_(rawRow, names, cands); // 20 lines
  }
  ```

---

### ไฟล์: `src/O_core_system/28_WebAppActions.gs` (932 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- Mobile menu dispatcher pattern clean
- RBAC checks ก่อน destructive actions

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: Magic indices row[4], row[5], row[7] ไม่ใช้ TEST_MATCH_IDX**
- 📍 Location: `src/O_core_system/28_WebAppActions.gs:627-629`
- 🔍 Issue: ชีต TEST_MATCH_RESULTS มี `TEST_MATCH_IDX` อยู่แล้วใน 01_Config.gs แต่ 28_WebAppActions ใช้ magic number แทน
- 💡 Suggestion:
  ```javascript
  // Before
  const action   = String(row[4] || '').trim();
  const reason   = String(row[5] || '').trim();
  const evidence = String(row[7] || '').trim();

  // After
  const action   = String(row[TEST_MATCH_IDX.ACTION]   || '').trim();
  const reason   = String(row[TEST_MATCH_IDX.REASON]   || '').trim();
  const evidence = String(row[TEST_MATCH_IDX.EVIDENCE] || '').trim();
  ```
- 🎯 Why: Law 3 (Index-based access) — ถ้า schema เปลี่ยน แก้ที่ 01_Config.gs ที่เดียว

---

### ไฟล์: `src/1_group1_master_db/05_NormalizeService.gs` (1,419 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- `normalizePersonNameFull()` มี 7-step pipeline ที่ชัดเจน — documented ดีมาก
- regex patterns ทำงานถูกต้องกับ Thai Unicode
- Phone extraction logic ครอบคลุม Thai number formats

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: phoneticSubstitute_ มี Cyclomatic Complexity = 40 (สูงสุดทั้ง codebase)**
- 📍 Location: `src/1_group1_master_db/05_NormalizeService.gs:1230`
- 🔍 Issue: ลำดับ if-else/replace chain ยาวมาก — ไม่มีหลักฐานจาก grep ว่ามี test coverage ด้วย
- 💡 Suggestion:
  ```javascript
  // Before — ลำดับ if/replace ยาว
  // After — Lookup Map pattern
  const PHONETIC_SUBSTITUTIONS = [
    [/[กขฃคฅฆ]/g, 'K'],
    [/[งญ]/g, 'N'],
    [/[จฉชซศษส]/g, 'S'],
    // ...
  ];
  function phoneticSubstitute_(str) {
    return PHONETIC_SUBSTITUTIONS.reduce(
      (s, [pattern, replacement]) => s.replace(pattern, replacement), str
    );
  }
  ```
- 🎯 Why: CC=40 เกิน ESLint limit (complexity:30) — ควรแก้ก่อน ESLint จะ fail

---

### ไฟล์: `src/1_group1_master_db/10d_MatchTestHarness.gs` (271 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- Dry-run pattern ถูกต้อง — ไม่ write master sheets
- Time guard ใน loop ป้องกัน GAS timeout

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: runTestMatchDryRun_ 214 บรรทัด, CC=20**
- 📍 Location: `src/1_group1_master_db/10d_MatchTestHarness.gs:58-272`
- 🔍 Issue: Load rows, process loop, build summary ใน function เดียว — ยากทดสอบ unit-level
- 💡 Suggestion: แยกเป็น `loadTestSourceRows_(maxRows, forceAll)`, `processTestRow_(srcObj)`, `buildTestSummary_(results, elapsed)`

---

### ไฟล์: `src/1_group1_master_db/10_MatchEngine.gs` (913 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- Emergency stop `PIPELINE_STOP_REQUESTED` ทำงานทุก 10 rows — well-designed
- `flushBatches_` แยกออกมาชัดเจน
- `acquireMatchEngineLock_` wrapper สะอาด

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: makeMatchDecision ที่ 10_MatchEngine.gs line 499 ยังมีอยู่ แต่ actual logic อยู่ใน 10b**
- 📍 Location: `src/1_group1_master_db/10_MatchEngine.gs:499`
- 🔍 Issue: มี comment "Moved to 10b" แต่ function declaration ยังอยู่ที่ 10_MatchEngine — อาจสร้าง confusion
- 💡 Suggestion: Add explicit JSDoc `@see 10b_MatchDecision.gs#makeMatchDecision` หรือ redirect comment

---

### ไฟล์: `src/4_group4_pipeline_mgr/24_PipelineManager.gs` (1,534 บรรทัด)

#### ✅ จุดที่ทำได้ดี
- Circuit Breaker pattern ใน `checkCircuitBreaker_` — ป้องกัน spam retry
- Preflight 6-check system (`runPipelinePreflight`) — dependency-aware
- Telegram retry wrapper ด้วย exponential backoff

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: runPipelineBatch 198 บรรทัด, CC=19**
- 📍 Location: `src/4_group4_pipeline_mgr/24_PipelineManager.gs:568-766`
- 🔍 Issue: pipeline batch ทำ: pre-checks, load rows, process loop, flush, log — 5 concerns ในฟังก์ชันเดียว
- 💡 Suggestion: แยก `validateBatchPreconditions_()`, `processRowsInChunks_()`, `recordBatchMetrics_()`

---

### สรุปรายไฟล์ (.gs)

| File | Tips Count | Severity Avg | Top Issue |
|------|-----------|-------------|-----------|
| 00_App.gs | 2 | P2 | showVersionInfo hardcoded count |
| 01_Config.gs | 1 | P2 | COOKIE_CELL deprecated แต่ยังใช้งาน |
| 14_Utils.gs | 1 | P2 | saveChunkedCache_ 160 lines |
| 22b_WebAppViews.gs | 1 | P2 | Magic indices row[0]-[3] |
| 22c_WebAppActions.gs | 1 | P1 | getReviewDetail 208 lines (SRP) |
| 28_WebAppActions.gs | 1 | P2 | Magic indices row[4]/[5]/[7] |
| 05_NormalizeService.gs | 1 | P1 | phoneticSubstitute_ CC=40 |
| 10d_MatchTestHarness.gs | 1 | P1 | runTestMatchDryRun_ 214 lines |
| 10_MatchEngine.gs | 1 | P2 | makeMatchDecision redirect unclear |
| 24_PipelineManager.gs | 1 | P1 | runPipelineBatch 198 lines |
| **ไฟล์ที่ไม่มี issue สำคัญ** | - | - | 02_Schema.gs, 03_SetupSheets.gs, 06_PersonService.gs, 07_PlaceService.gs, 08_GeoService.gs, 09_DestinationService.gs, 10b-10h, 12_ReviewService.gs, 12b, 13, 15, 16, 17, 18, 19_Hardening.gs, 20, 21, 21b, 22_WebApp.gs, 26, 27_RbacService.gs, 29_SnapshotTest.gs, 99_Legacy.gs |

---

### Code Review Tips — .html Files (19 ไฟล์)

#### ✅ จุดที่ทำได้ดี (รวม):
- `escapeHtml_()` ใช้ **121 จุด** ทั่ว HTML files — XSS protection แข็งแกร่ง
- `ViewHelpers.escapeHtml()` shared helper ใช้ใน LiveFeed.html และ components
- CDN ทั้งหมดโหลดจาก build-time (ไม่มี runtime CDN load — check_13 ผ่าน)

#### ⚠️ ปัญหาที่พบ:

**Tip #1: buildErrorHtml_(err.message) → innerHTML — minor XSS risk**
- 📍 Location: `src/3_group3_webapp/views/QReview.html:860`, `MatchEngine.html:497`
- 🔍 Issue: `container.innerHTML = buildErrorHtml_(err.message)` — ถ้า err.message มี HTML chars (เช่น จาก network error ที่ไม่ได้ escape) จะ inject HTML ได้
- 💡 Suggestion:
  ```javascript
  // Before
  container.innerHTML = buildErrorHtml_(err.message);
  // After
  container.innerHTML = buildErrorHtml_(escapeHtml_(String(err.message || 'Unknown error')));
  ```
- 🎯 Why: low risk เพราะ error มาจาก GAS server-side แต่ defence-in-depth ควรทำ

---

## Phase 3 — Security Protocols

### 1. Executive Summary

| รายการ | ค่า |
|--------|-----|
| Overall Risk Level | 🟡 **MEDIUM** (ลดจาก HIGH หลัง 18 audit cycles) |
| Critical Findings | 1 (appsscript.json access:MYSELF — production blocker) |
| SEC-001→012 Pass Rate | **11/12** (SEC-007 pass เมื่อแก้ access) |
| New Findings | 3 (1 MEDIUM, 1 LOW, 1 INFO) |
| Compliance | PDPA-compliant ผ่าน PII masking + PropertiesService secrets |

---

### 2. SEC-001 → SEC-012 Audit

| ID | Description | Status | Evidence | Fix |
|----|-------------|--------|----------|-----|
| SEC-001 | Cookie/Credentials ไม่อยู่ใน Spreadsheet | ✅ PASS | `getSCGCookie_()` อ่าน PropertiesService primary; cell B1 เป็น deprecated fallback + auto-migrate ใน V6.0.036+067 | - |
| SEC-002 | Authorization Guard บน destructive actions | ✅ PASS | `isAuthorizedOrFail_()` ใหม่ใน V6.0.072 (fail-closed) ใช้ที่ 44 จุด; `requirePermission_()` ใน RBAC | - |
| SEC-003 | Input Validation บน WebApp endpoints | ✅ PASS | `validateInput_()` ใน 19_Hardening.gs ใช้ใน 3 endpoints: submitReviewDecision, searchLocations, getMapAnalyticsData | - |
| SEC-004 | PII ไม่ถูก log แบบ raw | ✅ PASS | `maskEmailSafe_()`, `maskSearchQuery_()`, `maskedPhone` ใน 06_PersonService — V6.0.067+071 | - |
| SEC-005 | XSS ป้องกันใน HtmlService output | ✅ PASS (minor gap) | `escapeHtml_()` 121 จุด; ⚠️ err.message บางจุด ยังไม่ escape (กดหมาย N-002) | ดู N-002 |
| SEC-006 | API Key ส่งผ่าน Header ไม่ใช่ URL | ✅ PASS | `headers: {'x-goog-api-key': apiKey}` ใน 14_Utils.gs:430; comment `[SEC-006]` ชัดเจน | - |
| SEC-007 | WebApp Access Control เหมาะกับ production | ❌ FAIL | `appsscript.json:13` มี `"access": "MYSELF"` — ผู้ใช้อื่นเข้า WebApp ไม่ได้ | เปลี่ยนเป็น `DOMAIN` หรือ `ANYONE` ก่อน deploy |
| SEC-008 | Formula Injection Prevention | ✅ PASS | `sanitizeForSheet_()` + `sanitizeRowForSheet_()` ใน 14_Utils.gs:1396 + ใช้ใน 4 master write locations (06/07/08/09) | - |
| SEC-009 | Supply Chain Security | ✅ PASS | Gitleaks workflow (08), CodeQL (06), Dependabot (.github/dependabot.yml), .gitleaks.toml allowlist | - |
| SEC-010 | Rate Limiting & Quota Awareness | ✅ PASS | Telegram retry wrapper (exponential 2s/4s/8s, 3 retries); Time Guard ทุก loop; GAS 6-min cap ใน Dry Run | - |
| SEC-011 | RBAC ครอบคลุมทุก permission | ✅ PASS | `27_RbacService.gs` — 3 roles × 11 permissions; deny-by-default Viewer role | - |
| SEC-012 | No Log Leakage (API key/Cookie ไม่โผล่ใน log) | ✅ PASS | `[SEC-012]` comment ใน 14_Utils.gs:461 "ไม่แสดง resText ทั้งหมด เพื่อกัน API key/cookie รั่วผ่าน log" | - |

---

### 3. New Findings (นอกเหนือจาก 12 ข้อเดิม)

| ID | Severity | Description | File:Line | Fix |
|----|----------|-------------|-----------|-----|
| N-001 | 🔴 MEDIUM | `appsscript.json access: "MYSELF"` — production blocker; ไม่มีใครนอกจาก deployer เข้า WebApp ได้ | `appsscript.json:13` | เปลี่ยนเป็น `DOMAIN` (ถ้าใช้ Google Workspace org) หรือ `ANYONE` + ทดสอบ RBAC ยังทำงาน |
| N-002 | 🟡 LOW | `buildErrorHtml_(err.message)` → `innerHTML` — err.message ไม่ผ่าน escapeHtml ก่อน | `QReview.html:860`, `MatchEngine.html:497` | `buildErrorHtml_(escapeHtml_(String(err.message)))` |
| N-003 | 🔵 INFO | `XFrameOptionsMode.ALLOWALL` — clickjacking risk ที่ documented ไว้ใน SECURITY.md §1 | `22_WebApp.gs:61,85` | Documented + 5-layer mitigation มี (Auth, RBAC, OAuth, XSS, CSRF) — ยอมรับได้ |

---

### 4. Security Protocols (กฎที่ต้องบังคับใช้)

#### Protocol S-01: API Key & Secret Management
- **Rule:** Secrets (GEMINI_API_KEY, SCG_COOKIE, LMDS_ADMINS, TELEGRAM_BOT_TOKEN) ต้องอยู่ใน `PropertiesService.getScriptProperties()` เท่านั้น ห้ามอยู่ใน source code, Spreadsheet cell (เว้น fallback migration path), หรือ log
- **Implementation:** `getGeminiApiKey()` ใน 01_Config.gs, `getSCGCookie_()` ใน 18_ServiceSCG.gs, auto-migrate B1→PropertiesService
- **Verification:** `grep -rnE "AIza[A-Za-z0-9_-]{35}" src/` → 0 matches ✅

#### Protocol S-02: Authorization (Fail-Closed)
- **Rule:** ทุก destructive action ต้องเรียก `isAuthorizedOrFail_()` หรือ `requirePermission_()` ก่อน — ถ้า RBAC module ไม่โหลด → DENY (ไม่ใช่ ALLOW)
- **Implementation:** `isAuthorizedOrFail_()` ใน 27_RbacService.gs (V6.0.072)
- **Verification:** 44 call sites ผ่าน `grep -n "isAuthorizedOrFail_\|requirePermission_"`

#### Protocol S-03: Input Validation
- **Rule:** WebApp endpoints ที่รับ user input ทุก endpoint ต้องผ่าน `validateInput_()` ก่อน process
- **Implementation:** 3 endpoints covered; pattern: `reviewId`, `decision` enum, `query` length
- **Verification:** ตรวจ endpoint ใหม่ทุกตัวก่อน merge — เพิ่มใน PR checklist

#### Protocol S-04: Output Encoding
- **Rule:** ทุก user-controlled data ที่จะแสดงผลใน HTML ต้องผ่าน `escapeHtml_()` ก่อน → innerHTML
- **Implementation:** 121 จุด; shared via ViewHelpers.html
- **Verification:** grep `innerHTML` ทุก .html file และตรวจว่าค่าที่ใส่ผ่าน escape แล้ว

#### Protocol S-05: PII Protection in Logs
- **Rule:** email, phone, ชื่อบุคคล, ที่อยู่ ห้าม log แบบ raw — ต้องใช้ `maskEmailSafe_()`, `maskSearchQuery_()`, หรือ `maskedPhone`
- **Implementation:** 22_WebApp.gs:239, 264; 06_PersonService.gs:489
- **Verification:** ตรวจ `logInfo.*email` และ `logError.*phone` ทุก PR

#### Protocol S-06: WebApp Deployment Access
- **Rule:** ก่อน deploy production เปลี่ยน `appsscript.json` access จาก `MYSELF` → `DOMAIN` หรือ `ANYONE`
- **Implementation:** หลังเปลี่ยน ต้องทดสอบ: RBAC ยังทำงาน, DASHBOARD_USERS whitelist reject ถูกต้อง, LMDS_ADMINS set ใน PropertiesService
- **Verification:** Checklist 2.6 ใน predeploy-checker

---

### 5. Threat Model (STRIDE) — สรุป

| Threat | Asset | Attack Vector | Mitigation |
|--------|-------|--------------|------------|
| Spoofing | RBAC identity | User เปลี่ยน email ใน Session | Google OAuth + `Session.getEffectiveUser()` — server-side |
| Tampering | Master data (M_PERSON, M_PLACE) | Direct Sheet edit โดย user | Sheet protection + `applySheetProtection_UI()` |
| Repudiation | Review decisions | Admin deny ว่า approve | `SYS_AUDIT_TRAIL` บันทึก changed_by + changed_at |
| Information Disclosure | PII ใน log | Stackdriver log export | PII masking in logInfo/Error calls |
| Denial of Service | GAS quota (6-min limit) | Trigger flooding | LockService, Time Guard, Circuit Breaker |
| Elevation of Privilege | Admin menu actions | Non-admin เรียก runFullPipeline | `requirePermission_('action:run_pipeline')` + `isAuthorizedOrFail_()` |

---

### 6. Compliance Checklist ก่อน Deploy

- [ ] **N-001 FIX**: เปลี่ยน `appsscript.json` access จาก `MYSELF` → `DOMAIN` หรือ `ANYONE`
- [ ] ตั้ง `LMDS_ADMINS` ใน Script Properties (email ของ Admin ทั้งหมด)
- [ ] ตั้ง `DASHBOARD_USERS` ใน 01_Config.gs (email ของผู้ใช้ Dashboard)
- [ ] รัน `applySheetProtection_UI()` บน production Spreadsheet
- [ ] ทดสอบ RBAC: Viewer เข้า dashboard ได้, เรียก runFullPipeline ไม่ได้
- [ ] ทดสอบ Unauthorized.html แสดงผลสำหรับ user ที่ไม่ใน whitelist
- [ ] ตรวจ N-002: escapeHtml ครอบ err.message ใน buildErrorHtml_

---

## Phase 4 — Coding Style Scorecard

### Overall Score: **85/100** (Grade: **B+**)

### Per-Category Breakdown

| หมวด | น้ำหนัก | คะแนน | หมายเหตุ |
|------|---------|-------|---------|
| 1. Naming Convention | 10% | 88/100 | camelCase สม่ำเสมอ, `_` private suffix ชัดเจน, ชื่อสื่อความหมายทุกไฟล์ |
| 2. Function Size & SRP | 15% | 72/100 | ส่วนใหญ่ดี แต่ 10 functions > 100 บรรทัด; phoneticSubstitute_ CC=40 เกิน limit |
| 3. Comment & Documentation | 10% | 96/100 | JSDoc ครบ 39 files; REQUIRES/CALLS/EXPORTS TO headers ยอดเยี่ยม |
| 4. Error Handling | 15% | 87/100 | try-catch ครบ entry points; LockService finally pattern ดี |
| 5. Consistency (style) | 10% | 91/100 | indent, quote, semicolon สม่ำเสมอ; Prettier enforce ผ่าน CI |
| 6. GAS Best Practices | 15% | 85/100 | batch ops ดี; cache/lock ถูกต้อง; แต่ไม่มี SpreadsheetApp.flush() เลย |
| 7. Security Mindset | 15% | 87/100 | RBAC, input validation, sanitization ครบ; N-001/N-002 ยังรอ |
| 8. Maintainability | 10% | 80/100 | DRY ดี (parsePaginationParams_, escapeHtml_); แต่ 21_AliasService 1796 บรรทัด |

**Weighted Score:** (88×10 + 72×15 + 96×10 + 87×15 + 91×10 + 85×15 + 87×15 + 80×10) / 100 = **85.15/100**

---

### Top 5 Strengths

1. **JSDoc Headers ยอดเยี่ยม** — ทุกไฟล์มี `REQUIRES/CALLS/EXPORTS TO/SHEETS ACCESSED/TRIGGERS` — อ้างอิงง่ายมาก
2. **RBAC Architecture แข็งแกร่ง** — 3-role deny-by-default, fail-closed pattern (V6.0.072), 44 enforcement sites
3. **Error Handling Pattern สม่ำเสมอ** — `safeUiAlert_()` ทุก entry point; `releaseScriptLock_()` ใน finally blocks
4. **Input Sanitization ครบวงจร** — `validateInput_()` + `sanitizeForSheet_()` + `escapeHtml_()` (121 sites)
5. **GAS Batch Operations** — `getValues()` / `setValues()` pattern ทั่วทั้ง codebase; ไม่พบ `getValue()` ใน loop

### Top 5 Improvements Needed

1. **phoneticSubstitute_ CC=40** — เกิน ESLint complexity:30 limit; ใช้ lookup map แทน if-else chain
2. **Magic indices** — `row[4]`, `row[7]` ใน 28_WebAppActions.gs ควรใช้ `TEST_MATCH_IDX` constants
3. **Function Size** — 10 functions > 100 บรรทัด: runTestMatchDryRun_ (214), getReviewDetail (208), runPipelineBatch (198)
4. **SpreadsheetApp.flush() ขาด** — ไม่มีเลยทั้ง codebase — ควรเพิ่มหลัง batch writes สำคัญ
5. **BLUEPRINT.md placeholder sections** — sections 2-9 มีข้อความ "Same as before" ทำให้เอกสาร architecture ไม่สมบูรณ์

---

### Sample Code Review

**✅ Good example:**

```javascript
// src/O_core_system/27_RbacService.gs:38-55
// Fail-closed authorization pattern
function isAuthorizedOrFail_() {
  if (typeof isAuthorizedUser_ !== 'function') {
    logError('Security', '[SEC-002] isAuthorizedUser_ not loaded — denying operation (fail-closed)');
    return false;
  }
  try {
    return isAuthorizedUser_();
  } catch (e) {
    logError('Security', '[SEC-002] isAuthorizedUser_ threw — denying operation: ' + e.message, e);
    return false;
  }
}
```
เพราะ: Fail-closed pattern ถูกต้อง — ถ้า module ไม่โหลด → DENY ไม่ใช่ ALLOW; ครบทั้ง try-catch และ log

**❌ Needs improvement:**

```javascript
// src/O_core_system/28_WebAppActions.gs:627-629
// Magic indices — ถ้า TEST_MATCH_RESULTS schema เปลี่ยน หาไม่เจอ
const action   = String(row[4] || '').trim();
const reason   = String(row[5] || '').trim();
const evidence = String(row[7] || '').trim();
```
ปัญหา: Violates Law 3 (Index-based access) — ควรใช้ `TEST_MATCH_IDX.ACTION` ฯลฯ
แก้เป็น: `String(row[TEST_MATCH_IDX.ACTION] || '').trim()`

---

## Phase 5 — Refactoring Plans

### Refactoring Roadmap — 4 Sprints

---

### Sprint 0: Quick Wins (1-3 วัน, ไม่กระทบ behavior)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R-01 | `28_WebAppActions.gs:627-629` | row[4]/[5]/[7] → `TEST_MATCH_IDX.ACTION/.REASON/.EVIDENCE` | ⚪ NONE — ค่าเดิม mapping เหมือนกัน | grep ยืนยัน TEST_MATCH_IDX ใน 01_Config.gs ตรงกัน |
| R-02 | `22b_WebAppViews.gs:743-746` | row[0]-[3] → local const `PIPELINE_COL` | ⚪ NONE | Manual review getMatchEngineMetrics output เท่ากัน |
| R-03 | `00_App.gs:~584` | showVersionInfo() hardcoded counts → `APP_STATS` constant | 🟡 LOW — ต้อง add APP_STATS ใน 01_Config.gs ก่อน | showVersionInfo แสดงเลขถูกต้อง |
| R-04 | `appsscript.json:13` | access: `"MYSELF"` → `"DOMAIN"` หรือ `"ANYONE"` | 🔴 HIGH (ต้องทดสอบ) — อาจ break WebApp auth | ทดสอบ Unauthorized.html reject correctly; test all 3 roles |
| R-05 | `QReview.html:860`, `MatchEngine.html:497` | `buildErrorHtml_(err.message)` → `buildErrorHtml_(escapeHtml_(String(err.message)))` | ⚪ NONE | ทดสอบ error state แสดงผลถูกต้อง |

---

### Sprint 1: Foundation (1 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R-06 | `05_NormalizeService.gs:1230` | `phoneticSubstitute_` if-else chain → PHONETIC_MAP lookup array | 🟡 LOW — ผลลัพธ์ต้องเหมือนเดิม | `testThaiNormalization()` ใน 10d + snapshot test ก่อน/หลัง |
| R-07 | `10d_MatchTestHarness.gs:58` | แยก `runTestMatchDryRun_` (214 lines) → 3 helpers | 🟡 LOW — ต้องไม่กระทบผล dry-run | Snapshot test ก่อน refactor; เปรียบเทียบ TEST_MATCH_RESULTS |
| R-08 | `00_App.gs:837` | ย้าย body ของ `cleanupAutoResumeTriggers_UI` → `10h_MatchAutoResume.gs` | 🟡 LOW | ทดสอบ menu trigger + verify triggers ถูกลบถูก |
| R-09 | `22c_WebAppActions.gs:296` | แยก `getReviewDetail` (208 lines) → 3 helpers | 🟡 LOW | WebApp QReview detail panel แสดงข้อมูลเหมือนเดิม |
| R-10 | `14_Utils.gs:1078` | แยก `saveChunkedCache_` (160 lines) → 3 strategy helpers | 🟡 LOW | Cache round-trip test: save → load → compare |

---

### Sprint 2: Architecture (2 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R-11 | `24_PipelineManager.gs:568` | แยก `runPipelineBatch` (198 lines) → `initBatch_()`, `processRowsInChunks_()`, `recordBatchMetrics_()` | 🟠 MEDIUM — core pipeline | Snapshot test 200 rows ก่อน/หลัง; compare FACT_DELIVERY count |
| R-12 | `22c_WebAppActions.gs:545` | แยก `searchLocations` (184 lines) → `searchPersons_()`, `searchPlaces_()`, `searchGeos_()` | 🟡 LOW | Search UI ทดสอบ ≥5 queries |
| R-13 | `26_AuditTrailService.gs` | เพิ่ม Dashboard view ใน `22b_WebAppViews.gs` สำหรับ SYS_AUDIT_TRAIL | 🟡 LOW — additive | Dashboard Audit tab โหลดข้อมูลได้ |
| R-14 | ทั้ง codebase | เพิ่ม `SpreadsheetApp.flush()` หลัง batch writes สำคัญ (FACT_DELIVERY, Q_REVIEW writes) | 🟡 LOW | ทดสอบว่า data persist ถูกก่อน read ต่อ |

---

### Sprint 3: Polish (1 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R-15 | `BLUEPRINT.md` sections 2-9 | เขียน content จริงแทน "Same as before" placeholder | ⚪ NONE — doc only | check_07 (header sync) + manual review |
| R-16 | `.eslintrc.yml` | ลด max-lines-per-function: 200 → 150 (หลัง Sprint 1 เสร็จ) | 🟡 LOW — CI อาจ fail ถ้ายังมี functions ยาว | รัน `npm run lint` ก่อน apply |
| R-17 | `01_Config.gs` | เพิ่ม `APP_STATS` constant `{ GS_FILES: 39, HTML_FILES: 19, FUNCTIONS: 544 }` | ⚪ NONE | showVersionInfo แสดงเลขถูกต้อง |
| R-18 | `21_AliasService.gs` (Deferred D-2) | Split เมื่อ maintenance pain จริง — ไม่บังคับในรอบนี้ | 🔴 HIGH ถ้าทำ — ไฟล์ใหญ่สุด | Snapshot test 400 rows ก่อน/หลัง |

---

### Refactor Pattern Library

**Pattern R-01: Extract Function (สำหรับ function > 100 บรรทัด)**

```javascript
// Before: runTestMatchDryRun_ ทำทุกอย่าง
function runTestMatchDryRun_(maxRows, forceAll) {
  // 50 lines: load rows
  // 100 lines: process loop
  // 64 lines: build summary + write sheet
}

// After: แต่ละ concern มี function ของตัวเอง
function runTestMatchDryRun_(maxRows, forceAll) {
  const rows    = loadTestSourceRows_(maxRows, forceAll);   // step 1
  const results = processTestRows_(rows);                   // step 2
  return writeTestSummary_(results, maxRows);               // step 3
}
```

**Pattern R-02: Replace Magic Number with Constant**

```javascript
// Before
const action = String(row[4] || '').trim();

// After — อ้างอิง IDX constant
const action = String(row[TEST_MATCH_IDX.ACTION] || '').trim();
```

**Pattern R-03: Lookup Map แทน if-else chain (สำหรับ CC > 20)**

```javascript
// Before: if/else chain ยาว
if (char === 'ก' || char === 'ข' || char === 'ฃ') return 'K';
else if (...) ...

// After: O(1) lookup
const CHAR_TO_PHONETIC = { 'ก':'K','ข':'K','ฃ':'K','ค':'K',... };
function phoneticCode_(char) { return CHAR_TO_PHONETIC[char] || char; }
```

---

### Rollback Plan

1. **Sprint 0 (Quick Wins):** ทุก item เป็น mechanical rename — rollback ด้วย `git revert` ทันที
2. **Sprint 1 (Foundation):** ใช้ `snapshotSaveBaseline_UI()` ก่อน refactor แต่ละ function → `snapshotCompare_UI()` หลัง → commit เฉพาะเมื่อ 0 differences
3. **Sprint 2 (Architecture):** ทดสอบ Dry Run (Force All 200 rows) ก่อน/หลัง → compare match rate ต้องไม่เปลี่ยน
4. **appsscript.json (R-04):** test บน staging deployment ก่อน production เสมอ; rollback: เปลี่ยนกลับเป็น `MYSELF` ใน clasp deploy

---

## 🎯 Final Verdict

### Pre-Deploy Verification Score

| Category | Score | Weight | Weighted |
|----------|-------|--------|----------|
| Code Quality (Phase 2+4) | 85% | 35% | 29.75 |
| Security (Phase 3) | 11/12 = 91.7% | 30% | 27.5 |
| Documentation | 90% | 15% | 13.5 |
| Architecture | 88% | 15% | 13.2 |
| Operational Readiness | 75% (access:MYSELF ปิดกั้น) | 5% | 3.75 |
| **Total** | | | **87.7%** |

---

### ❌ **NO-GO (ณ ปัจจุบัน)** — แก้ P0 ก่อนส่งมอบ Production

**P0 Blocking Issue:**

```
TD-001 / N-001 / SEC-007:
  File: appsscript.json:13
  Current: "access": "MYSELF"
  Required: "access": "DOMAIN" (Google Workspace org)
            หรือ "ANYONE" (+ Google login required)
  Impact: WebApp ใช้ได้เฉพาะ deployer ไม่มีผู้ใช้คนอื่นเข้า dashboard ได้
  Fix Time: 30 นาที (เปลี่ยนค่า + clasp deploy + ทดสอบ RBAC)
```

### ✅ **GO (หลังแก้ P0)** — ระบบมีคุณภาพสูง พร้อม Production

**หลังแก้ TD-001:**

- ✅ Security Architecture แข็งแกร่ง (18 audit cycles, 116 fixes)
- ✅ RBAC fail-closed, input validation, PII masking ครบ
- ✅ 9 CI/CD workflows (ESLint, Prettier, CodeQL, Gitleaks, Health Check)
- ✅ 8-Rules Match Engine ทดสอบด้วย Snapshot Test + Dry Run
- ✅ LockService, Time Guard, Circuit Breaker, AutoResume ครบ
- ✅ CHANGELOG ครบทุก version จาก V5.2 ถึง V6.0.072
- 🟡 P1 items (5 ข้อ) ควรแก้ใน Sprint 1 แต่ไม่ blocking production

---

## ⚠️ NOT YET CHECKED — ต้องตรวจเพิ่มใน Live Environment

1. **Live Runtime Test:** รัน Full Pipeline จริงใน Apps Script — ตรวจ GAS quota, execution time, Auto-Resume trigger
2. **WebApp Loading Test:** เปิด dashboard หลังเปลี่ยน `access: DOMAIN` — ทดสอบทุก view (Dashboard, QReview, FACT, Search, Maps, LiveFeed)
3. **RBAC Integration Test:** ทดสอบ 3 roles จริง: Viewer reject runFullPipeline; Reviewer approve Q_REVIEW; Admin ทำได้ทุกอย่าง
4. **SCG API Integration:** `fetchDataFromSCGJWD()` เรียก external API — ต้องทดสอบ cookie ยังใช้งานได้ (expire ทุก ~24h)
5. **Google Maps Geocoding:** `15_GoogleMapsAPI.gs` เรียก Maps API — ตรวจ quota และ rate limit
6. **Telegram Alert Test:** ส่ง test message ผ่าน bot เพื่อยืนยัน `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` ถูกต้อง
7. **SYS_TH_GEO Data Quality:** ตรวจ `buildGeoDictionary()` ว่า geo dictionary มีข้อมูลครบก่อน Pipeline รัน
8. **Sheet Protection Verification:** หลัง `applySheetProtection_UI()` ตรวจว่า 8 sheets protected + Q_REVIEW range ถูกต้อง
9. **Concurrent User Test:** ทดสอบ 2+ users รัน Pipeline พร้อมกัน — ยืนยัน LockService ทำงาน
10. **Performance Test:** รัน 500+ rows ด้วย Force All Dry Run — ตรวจ time guard หยุดถูกที่ และ match rate อยู่ระดับที่คาดหวัง

---

*Audit Report สร้างโดย: LMDS Principal Software Auditor (AI Agent)*
*Date: 2026-07-23 | Version Audited: LMDS V6.0.072*
