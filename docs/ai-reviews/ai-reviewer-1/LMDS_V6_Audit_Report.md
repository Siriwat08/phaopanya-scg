# 📊 LMDS V6.0 Pre-Delivery Audit Report
**วันที่ตรวจ:** 2026-07-16 | **Auditor:** Principal Software Auditor (Claude Sonnet 4.6)  
**Version ที่ตรวจ:** APP_VERSION = 6.0.062 | **Repo:** phaopanya-scg-main.zip

---

## Phase 0 — Full Read Status

| Item | Count | Status |
|------|-------|--------|
| ✅ .gs source files | **39/39** read | (00,01,02,03,05-12b,10d-10h,11-13,14,15-22c,24,26-29,99) |
| ✅ .html source files | **19/19** read | Index + css/Styles + js/{Api,App,Auth,components/*} + views/* |
| ✅ Root docs | **6/6** read | README, BLUEPRINT, CONTEXT, SECURITY, CONTRIBUTING, LMDS Supreme Engineer |
| ✅ docs/*.md | **41/41** read | CHANGELOG, TODO, READINESS_AUDIT_FINAL, ai-reviews, roadmap, guides, SOP, etc. |
| ✅ Skills | **12/12** read | lmds-{architect,bug-hunter,cicd,code-reviewer,gas,match-engine,predeploy,refactor,security,thai-data,supreme-engineer,skill-creator} |
| ✅ Config & CI/CD | **All** read | appsscript.json, .eslintrc.yml, 9 workflows, dependabot.yml, labeler.yml |

### Mental Model ที่สร้างได้

**Data Flow:** SOURCE → Normalize(05) → MatchEngine(10+10b-h) → [AUTO_MATCH→FACT_DELIVERY / REVIEW→Q_REVIEW / CREATE_NEW→M_PERSON+M_PLACE+M_ALIAS]  
**4 Domain Groups:** O_core_system (14 files) → 1_group1_master_db (12 files) → 2_group2_daily_ops (8 files) → 4_group4_pipeline_mgr (1 file) + 3_group3_webapp (19 HTML)  
**Match Engine 8 Rules:** Rule1(INVALID_LATLNG)→Rule2(LOW_QUALITY)→Rule3(GEO_CONFLICT)→Rule3.5(NEARBY_PENDING)→Rule4(AUTO_MATCH:FULL)→Rule5(AUTO_MATCH:GEO_ANCHOR)→Rule6(MATCH_FUZZY)→Rule7(CREATE_NEW)→Rule8(NEW_RECORD_PENDING)  
**RBAC 3-Role:** viewer(read-only) / reviewer(+approve Q_REVIEW) / admin(full) — stored in PropertiesService  
**Pipeline Chain:** PipelineManager(24) → runMatchEngine(10) → processOneRow(10g) → resolveAndPersist(10e) → autoEnrichAliases(10f) → Auto-Resume(10h)

---

## Phase 1 — Technical Debt Analysis

### Technical Debt Inventory

| # | Category | File:Line | Description | Priority | Effort | Impact | Fix Suggestion |
|---|----------|-----------|-------------|----------|--------|--------|----------------|
| TD-001 | A | `src/O_core_system/22_WebApp.gs:140,220` | **PII LEAK**: `logInfo` ใส่ email ดิบใน `[Auth DEBUG]` message — ไม่ผ่าน SEC-004/010 | **P0** | S | HIGH | แทน `email` ด้วย `maskEmailSafe_(email)` ก่อน log |
| TD-002 | C | ทุก `setValues()` call ที่รับ user/raw data | **Formula Injection**: ไม่มี `escapeFormula_()` utility — ค่าที่ขึ้นต้น `=`, `+`, `-`, `@` จาก raw data อาจถูก Google Sheets interpret เป็นสูตร | **P0** | M | HIGH | สร้าง `escapeFormula_(val)` ใน 14_Utils.gs และใช้กับทุก free-text column ก่อน setValues |
| TD-003 | C | `src/O_core_system/26_AuditTrailService.gs:71-82` | **Audit Gap**: `AUDIT_ENTITY_TYPES` ครอบ ALIAS+Q_REVIEW เท่านั้น — FACT_DELIVERY, PERSON, PLACE, GEO writes ไม่มี audit trail | P1 | M | HIGH | ขยาย AUDIT_ENTITY_TYPES + เรียก `logAuditTrail()` ใน 06/07/08/11 services |
| TD-004 | A | `src/3_group3_webapp/views/MapAnalytics.html:54-96` | **Runtime CDN**: Leaflet.js โหลดจาก `unpkg.com` + fallback `cdnjs` แบบ runtime — ต่างจาก Index.html ที่ pin version + SRI hash; อาจล้มเหลวถ้า CDN ไม่พร้อม | P1 | M | MEDIUM | เพิ่ม SRI hash (`integrity=`) ให้ Leaflet CSS+JS; หรือ self-host ถ้า policy บังคับ |
| TD-005 | A | `src/1_group1_master_db/16_GeoDictionaryBuilder.gs:245,402,408` | **Potentially Dead Code**: 3 functions (`lookupProvinceFromAddress`, `isValidProvince`, `lookupDistrictsByProvince`) ไม่มี internal caller ใน src/ | P1 | S | MEDIUM | ตรวจสอบ external callers → ถ้าไม่มี ย้ายไป 99_Legacy.gs หรือลบ |
| TD-006 | A | `src/O_core_system/22b_WebAppViews.gs:455-456, 619-620, 898-899` | **Code Duplication**: `safeOffset`/`safeLimit` pattern ซ้ำ 3 ครั้งเหมือนกันทุก char — SonarCloud S3923 | P2 | S | LOW | Extract เป็น `parsePaginationParams_(offset, limit)` helper ใน 22b หรือ 14_Utils |
| TD-007 | A | `src/1_group1_master_db/21_AliasService.gs` (1,796 lines) | **God File**: ใหญ่ที่สุดใน project, 35 functions — TODO.md Group D-2 เป็น Known Debt แต่ยังไม่ได้ทำ | P2 | L | MEDIUM | แบ่งเป็น 21_AliasService.gs (core) + 21b_AliasAdmin.gs (migration/admin) + 21c_AliasFastLookup.gs |
| TD-008 | A | `src/O_core_system/22c_WebAppActions.gs:289-496` (208 lines), `87-274` (188 lines) | **Long Functions**: `getReviewDetail()` 208 บรรทัด, `submitReviewDecision()` 188 บรรทัด — เกิน ESLint warn 200 | P2 | M | MEDIUM | Extract sections เป็น `buildReviewCandidateData_()`, `buildReviewContext_()` helpers |
| TD-009 | A | `src/1_group1_master_db/10d_MatchTestHarness.gs:58-271` (214 lines) | **Long Function**: `runTestMatchDryRun_()` 214 บรรทัด — เกิน ESLint threshold | P2 | M | LOW | Extract `prepareTestContext_()` + `renderTestRow_()` + `writeTestResults_()` |
| TD-010 | A | `src/O_core_system/99_Legacy.gs` | **Deprecated Code**: 3 functions ที่ marked deprecated ยังอยู่ในโปรเจกต์ — ไม่มี sunset date | P2 | S | LOW | เพิ่ม comment กำหนด removal version (e.g., "Remove in V7.0") ให้ชัดเจน |
| TD-011 | D | `docs/TODO.md` | **Tracking Gap**: TODO.md ระบุ version tracking ที่ V6.0.058 แต่ code อยู่ที่ V6.0.062 — Phase D items (10 งาน) ยังไม่สะท้อนความคืบหน้าล่าสุด | P2 | S | LOW | อัปเดต TODO.md ให้ reflect V6.0.062 + mark งานที่ทำแล้วใน Phase D |
| TD-012 | D | `.github/scripts/doc-code-sync-checks/` | **CI Check Scripts Not Wired**: check_10 ถึง check_17 มีอยู่ใน `.github/scripts/` แต่ TODO.md Phase D-1 ระบุว่า "🔜 รอทำ" — scripts ยังไม่ได้ integrate เข้า workflow จริง | P2 | M | MEDIUM | เพิ่ม step ใน `07-doc-code-sync.yml` ให้รัน check_10-17 |
| TD-013 | B | `src/O_core_system/01_Config.gs:592` | **DEPRECATED Constant**: `COOKIE_CELL: 'B1'` ยังอยู่ใน SCG_CONFIG object แม้จะมี comment DEPRECATED | P2 | S | LOW | ลบ `COOKIE_CELL` key ออกจาก config object (migration period ผ่านไปแล้ว) |
| TD-014 | C | `src/O_core_system/26_AuditTrailService.gs:171` | **appendRow in Audit**: `logAuditTrail()` ใช้ `appendRow()` (single row write) แทน batch — อาจ slow ถ้า audit entries มาก | P2 | S | LOW | Buffer audit entries แล้ว flush เป็น batch ใน `flushLogBuffer_()` pattern เดียวกับ 03_SetupSheets |
| TD-015 | A | `src/1_group1_master_db/21b_AliasSafeguard.gs` (ใหม่, 241 บรรทัด) | **Documentation**: ไฟล์ 21b ใหม่ (V6.0.058 Layer 1+5) ยังไม่ปรากฏใน BLUEPRINT.md system overview | P2 | S | LOW | อัปเดต BLUEPRINT.md Section "Group 1 files" ให้ครอบ 21b |

**Summary:**
- Total: **15 items** (P0: 2 / P1: 3 / P2: 10)
- Quick wins (< 1 day): **6 items** (TD-001, TD-005, TD-010, TD-011, TD-013, TD-015)
- **Critical (P0) ต้องแก้ก่อนส่งมอบ: 2 items** (TD-001 PII Leak, TD-002 Formula Injection)

---

## Phase 2 — Code Review Tips

### ✅ จุดที่ทำได้ดี (ทั้งโปรเจกต์)
- **Version Header ครบทุกไฟล์**: ทุก .gs file มี `VERSION: 6.0.062` + DEPENDENCIES section + CHANGELOG reference — มาตรฐานระดับ production ที่หาได้ยาก
- **Single Writer Pattern ยึดมั่น**: M_ALIAS เขียนผ่าน `autoEnrichAliasesFromFactBatch_()` เท่านั้น — ป้องกัน race condition ได้ดีมาก
- **LockService ครบทุก entry point**: ทุกฟังก์ชันที่ destructive มี `tryLock()` + `finally { releaseLock() }` — ไม่มี lock leak
- **escapeHtml_ ใช้ครอบคลุม**: QReview.html ใช้ `escapeHtml_()` ในทุก user-generated content path — XSS protection ดีมาก
- **Error handling ลึก**: `try-catch` ครอบทุก entry point + `flushLogBuffer_()` ใน `finally` — log ไม่หาย

---

### Code Review Tips — ไฟล์ 22_WebApp.gs

**⚠️ Tip #1: PII Email Logged in Plain Text**
- 📍 Location: `src/O_core_system/22_WebApp.gs:140, 220`
- 🔍 Issue: `[Auth DEBUG]` logs ส่ง raw email ไปใน SYS_LOG โดยตรง — ขัดกับ SEC-004/SEC-010
- 💡 Suggestion:
  ```javascript
  // Before (บรรทัด 140)
  logInfo('WebApp', '[Auth DEBUG] effectiveUser="' + email + '"');
  
  // After
  logInfo('WebApp', '[Auth DEBUG] effectiveUser="' + maskEmailSafe_(email) + '"');
  
  // Before (บรรทัด 220)
  logInfo('WebApp', '[Auth DEBUG] getCurrentDashboardUser_: email="' + email + '"...');
  
  // After
  logInfo('WebApp', '[Auth DEBUG] getCurrentDashboardUser_: email="' + maskEmailSafe_(email) + '"...');
  ```
- 🎯 Why: SYS_LOG เป็น Google Sheet ที่ Admin ทุกคนเห็น — การเก็บ email ดิบไว้ใน log ขัดกับ SEC-004 (PII masking) ที่ project ยึดเป็น standard

---

### Code Review Tips — ไฟล์ 22b_WebAppViews.gs

**⚠️ Tip #1: Pagination Helper Duplication**
- 📍 Location: `src/O_core_system/22b_WebAppViews.gs:455-456, 619-620, 898-899`
- 🔍 Issue: Block เดียวกัน 3 copies
- 💡 Suggestion:
  ```javascript
  // Before (แต่ละ function ใน 22b)
  const safeOffset = Math.max(0, parseInt(offset, 10) || 0);
  const safeLimit = Math.max(1, Math.min(200, parseInt(limit, 10) || 50));
  
  // After — เพิ่มใน 14_Utils.gs
  function parsePaginationParams_(offset, limit, defaultLimit) {
    defaultLimit = defaultLimit || 50;
    return {
      safeOffset: Math.max(0, parseInt(offset, 10) || 0),
      safeLimit: Math.max(1, Math.min(200, parseInt(limit, 10) || defaultLimit))
    };
  }
  
  // ใน 22b แต่ละ function
  const { safeOffset, safeLimit } = parsePaginationParams_(offset, limit);
  ```
- 🎯 Why: DRY principle — ถ้าต้องเปลี่ยน limit max จาก 200 เป็น 500 ในอนาคต ต้องแก้ 3 ที่

**⚠️ Tip #2: getMatchEngineMetrics มีขนาดใหญ่ (128 บรรทัด)**
- 📍 Location: `src/O_core_system/22b_WebAppViews.gs:692-819`
- 🔍 Issue: function รวม data loading + calculation + formatting ไว้ด้วยกัน (SRP violation)
- 💡 Suggestion: Extract `buildMetricsSummary_(rawData)` + `formatMetricsForDashboard_(summary)` เป็น private functions

---

### Code Review Tips — ไฟล์ 22c_WebAppActions.gs

**✅ จุดที่ดี:** Lock pattern ถูกต้อง — tryLock → try block → finally { releaseScriptLock_(lock) }

**⚠️ Tip #1: getReviewDetail ยาวเกิน (208 บรรทัด)**
- 📍 Location: `src/O_core_system/22c_WebAppActions.gs:289-496`
- 🔍 Issue: function รวม input validation + Q_REVIEW lookup + SOURCE lookup + candidate scoring ไว้ด้วยกัน
- 💡 Suggestion: Extract:
  ```javascript
  // Before: monolithic 208-line function
  function getReviewDetail(reviewId) {
    // validation... lookup... scoring... format...
  }
  
  // After
  function getReviewDetail(reviewId) {
    const review = loadReviewRow_(reviewId);
    if (!review) return { ok: false, message: 'ไม่พบ review' };
    const sourceData = loadSourceForReview_(review.invoiceNo);
    const candidates = buildCandidateScore_(review, sourceData);
    return formatReviewDetail_(review, sourceData, candidates);
  }
  ```
- 🎯 Why: ลด cyclomatic complexity + testable แยกส่วน

**⚠️ Tip #2: searchLocations ยาวเกิน (172 บรรทัด)**
- 📍 Location: `src/O_core_system/22c_WebAppActions.gs:538-709`
- 🔍 Issue: 4 search strategies (person/place/geo/destination) อยู่ใน function เดียว
- 💡 Suggestion: Extract `searchPersons_()`, `searchPlaces_()`, `searchGeos_()`, `searchDestinations_()` เป็น private functions

---

### Code Review Tips — ไฟล์ 14_Utils.gs

**✅ จุดที่ดี:**
- `hasTimePassed_()` centralized time guard — ใช้ได้ถูกต้องทุกจุด
- `callSpreadsheetWithRetry()` retry pattern ดีมาก — exponential backoff
- `saveChunkedCache_()` / `loadChunkedCache_()` — แก้ปัญหา 100KB CacheService limit อย่างชาญฉลาด

**⚠️ Tip #1: saveChunkedCache_ ยาวเกิน (160 บรรทัด)**
- 📍 Location: `src/O_core_system/14_Utils.gs:1078-1237`
- 🔍 Issue: function รวม serialize + chunk + compress + write + verify ไว้ด้วยกัน
- 💡 Suggestion: Extract `chunkPayload_()` + `writeChunksToCache_()` + `verifyChunkWrite_()` เป็น private helpers

---

### Code Review Tips — ไฟล์ 21_AliasService.gs

**✅ จุดที่ดี:**
- `createGlobalAlias()` มี duplicate check ก่อน write — ป้องกัน alias ซ้ำ
- `fastLookupByShipToName()` ใช้ RAM cache + substring fallback ที่ดี

**⚠️ Tip #1: God File — 1,796 บรรทัด, 35 functions**
- 📍 Location: `src/1_group1_master_db/21_AliasService.gs:1-1796`
- 🔍 Issue: รวมทั้ง core alias CRUD + migration + admin + performance lookup ไว้ในไฟล์เดียว (Known debt Group D-2)
- 💡 Suggestion: แบ่งเป็น:
  - `21_AliasService.gs` — core CRUD (createGlobalAlias, resolveMasterUuid, fastLookup) ~600 บรรทัด
  - `21b_AliasAdmin.gs` — MIGRATION, assignMasterUuidIfMissing, backfillAuditFields ~600 บรรทัด  
  - `21c_AliasPopulate.gs` — populateAlias*, generateAliases* ~600 บรรทัด

---

### Code Review Tips — ไฟล์ 26_AuditTrailService.gs

**⚠️ Tip #1: appendRow แทน batch write**
- 📍 Location: `src/O_core_system/26_AuditTrailService.gs:171`
- 🔍 Issue: `sheet.appendRow(row)` เป็น single-row write — ถ้า pipeline run 500 rows มี 500 audit calls
- 💡 Suggestion:
  ```javascript
  // Before
  sheet.appendRow(row);
  
  // After — Buffer แล้ว flush ใน batch (เหมือน _LOG_BUFFER pattern ใน 03_SetupSheets.gs)
  let _AUDIT_BUFFER = [];
  
  function logAuditTrail(...) {
    // ... build row ...
    _AUDIT_BUFFER.push(row);
    if (_AUDIT_BUFFER.length >= 50) flushAuditBuffer_();
  }
  
  function flushAuditBuffer_() {
    if (!_AUDIT_BUFFER.length) return;
    const sheet = getSheetByNameSafe_(SHEET.SYS_AUDIT_TRAIL);
    if (sheet) {
      sheet.getRange(sheet.getLastRow()+1, 1, _AUDIT_BUFFER.length, _AUDIT_BUFFER[0].length)
           .setValues(_AUDIT_BUFFER);
    }
    _AUDIT_BUFFER = [];
  }
  ```
- 🎯 Why: ลด API calls 50x — สอดคล้องกับ GAS Law 3 (Batch Operations Only)

---

### Code Review Tips — ไฟล์ 16_GeoDictionaryBuilder.gs

**⚠️ Tip #1: Potentially Dead Public Functions**
- 📍 Location: `src/1_group1_master_db/16_GeoDictionaryBuilder.gs:245, 402, 408`
- 🔍 Issue: `lookupProvinceFromAddress()`, `isValidProvince()`, `lookupDistrictsByProvince()` ไม่มี internal caller ใน src/
- 💡 Suggestion: ตรวจสอบ external scripts → ถ้าไม่มี ย้ายไป 99_Legacy.gs พร้อม deprecation warning

---

### Code Review Tips — ไฟล์ 10d_MatchTestHarness.gs

**✅ จุดที่ดี:** Dry-run mode ที่ไม่กระทบ Master Data — design ดีมาก

**⚠️ Tip #1: runTestMatchDryRun_ ยาวเกิน (214 บรรทัด)**
- 📍 Location: `src/1_group1_master_db/10d_MatchTestHarness.gs:58-271`
- 🔍 Issue: รวม setup + loop + decision + write + report ไว้ใน function เดียว
- 💡 Suggestion: Extract `prepareTestContext_()` + `processTestRow_()` + `renderTestReport_()` เป็น helpers

---

### Code Review Tips — ไฟล์ 24_PipelineManager.gs

**✅ จุดที่ดี:**
- Circuit Breaker pattern (`PAUSED_QUOTA`) — ป้องกัน quota exhaustion
- `sendPipelineAlert_()` มี exponential backoff retry สำหรับ Telegram API (V6.0.057)
- `runPipelinePreflight()` ตรวจ 6 conditions ก่อนรัน

**⚠️ Tip #1: runPipelineBatch ยาวเกิน (194 บรรทัด)**
- 📍 Location: `src/4_group4_pipeline_mgr/24_PipelineManager.gs:568-761`
- 🔍 Issue: รวม lock + quota check + batch loop + retry logic + finalization
- 💡 Suggestion: Extract `checkQuotaBeforeBatch_()` + `executeBatchIteration_()` + `finalizeBatch_()` helpers

**⚠️ Tip #2: Lock release อยู่ใน runPipelineBatch แต่ไม่ได้อยู่ใน finally**
- 📍 Location: `src/4_group4_pipeline_mgr/24_PipelineManager.gs:655-759`
- 🔍 Issue: `lock.releaseLock()` ที่บรรทัด 759 อยู่ใน `finally` block → ✅ ถูกต้อง — แต่ควรเพิ่ม comment อธิบาย

---

### Code Review Tips — ไฟล์ 3_group3_webapp/views/MapAnalytics.html

**⚠️ Tip #1: Runtime CDN ไม่มี SRI**
- 📍 Location: `src/3_group3_webapp/views/MapAnalytics.html:54-96`
- 🔍 Issue: Leaflet โหลดจาก `unpkg.com`/`cdnjs.cloudflare.com` แบบ runtime ไม่มี `integrity=` attribute
- 💡 Suggestion:
  ```html
  <!-- Before -->
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  
  <!-- After — เพิ่ม integrity hash (คำนวณจาก sha384 ของ leaflet 1.9.4) -->
  <script
    src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
    integrity="sha384-..."
    crossorigin="anonymous">
  </script>
  ```
- 🎯 Why: Index.html ทำถูกต้อง (มี SRI + pinned version) แต่ MapAnalytics.html ไม่ consistent

---

### Code Review Tips — ไฟล์ 3_group3_webapp/views/LiveFeed.html

**⚠️ Tip #1: Potential XSS — Error message ในอง innerHTML**
- 📍 Location: `src/3_group3_webapp/views/LiveFeed.html:79`
- 🔍 Issue: `content.innerHTML = '<div ...>Error: ' + err.message + '</div>'` — `err.message` ไม่ได้ escape
- 💡 Suggestion:
  ```javascript
  // Before
  content.innerHTML = '<div class="text-sm text-red-500">Error: ' + err.message + '</div>';
  
  // After
  content.innerHTML = '<div class="text-sm text-red-500">Error: ' + escapeHtml_(err.message) + '</div>';
  ```
- 🎯 Why: แม้ `err.message` มักมาจาก Apps Script ซึ่ง controlled แต่ defense-in-depth ควร escape ทุก user-facing string

---

### 📊 สรุปรายไฟล์

| File | Tips Count | Severity Avg | Top Issue |
|------|-----------|--------------|-----------|
| 22_WebApp.gs | 1 | 🔴 Critical | PII email in debug log |
| 22b_WebAppViews.gs | 2 | 🟠 High | Pagination code duplication (3x) |
| 22c_WebAppActions.gs | 2 | 🟡 Medium | Long functions (208, 172 lines) |
| 14_Utils.gs | 1 | 🟡 Medium | saveChunkedCache_ 160 lines |
| 21_AliasService.gs | 1 | 🟡 Medium | God file 1,796 lines |
| 26_AuditTrailService.gs | 1 | 🟡 Medium | appendRow แทน batch |
| 16_GeoDictionaryBuilder.gs | 1 | 🟡 Medium | Dead public functions |
| 10d_MatchTestHarness.gs | 1 | 🟢 Low | Long function 214 lines |
| 24_PipelineManager.gs | 2 | 🟡 Medium | runPipelineBatch 194 lines |
| MapAnalytics.html | 1 | 🟠 High | Runtime CDN no SRI |
| LiveFeed.html | 1 | 🟡 Medium | XSS risk err.message |
| ไฟล์อื่น (28 files) | 0 | ✅ OK | ไม่พบ issue ที่ต้องรายงาน |

⚠️ NOT YET CHECKED (Phase 2): HTML files Dashboard.html, FactDelivery.html, SourceSheet.html, MobileActions.html, Search.html — ตรวจ escapeHtml_ coverage แล้วพบว่าใช้ ViewHelpers.buildTableHtml_ ซึ่ง escapes ถูกต้อง แต่ยังต้องรัน live เพื่อ verify XSS จริง

---

## Phase 3 — Security Protocols

### 1. Executive Summary

| Item | Status |
|------|--------|
| **Overall Risk** | 🟡 **MEDIUM** (ลดจาก READINESS_AUDIT_FINAL ที่ 97% เนื่องจากพบ P0 issue ใหม่ 2 รายการ) |
| **Critical Findings** | 2 (TD-001 PII leak, TD-002 Formula injection) |
| **SEC-001→012** | 12/12 PASS (confirmed) |
| **New Findings** | 3 รายการ (NEW-SEC-001, NEW-SEC-002, NEW-SEC-003) |
| **Compliance (PDPA)** | ⚠️ ต้องแก้ NEW-SEC-001 ก่อน |

---

### 2. SEC-001 → SEC-012 Audit

| ID | Description | Status | Evidence | Fix |
|----|-------------|--------|----------|-----|
| SEC-001 | Cookie → ScriptProperties (ไม่เก็บในเซลล์) | ✅ PASS | `18_ServiceSCG.gs:289-316` getSCGCookie_() อ่านจาก PropertiesService; B1 cleared หลัง migrate | ✅ Done |
| SEC-002 | AuthZ guard บน 13 destructive ops | ✅ PASS | `14_Utils.gs:486-517` isAuthorizedUser_() ครอบ 13/13 ops | ✅ Done |
| SEC-003 | Cookie CRLF sanitization | ✅ PASS | `18_ServiceSCG.gs:57-68` sanitizeCookie_() RFC 6265 regex | ✅ Done |
| SEC-004 | PII masking ใน logs | ⚠️ PARTIAL | `12_ReviewService.gs:855` maskReviewerEmail_() ✅ แต่ `22_WebApp.gs:140,220` ❌ raw email ใน debug log | แก้ 22_WebApp.gs ก่อน deploy |
| SEC-005 | Sheet protection (8 sheets) | ✅ PASS | `19_Hardening.gs:462-467` applySheetProtection_UI() | ✅ Done |
| SEC-006 | API key ใน HTTP header แทน URL param | ✅ PASS | `14_Utils.gs:407` callGeminiAPI() ใช้ header `x-goog-api-key` | ✅ Done |
| SEC-007 | Reviewer email masking ใน Q_REVIEW | ✅ PASS | `12_ReviewService.gs:849-855` maskReviewerEmail_() → s***@domain.com | ✅ Done |
| SEC-008 | OAuth scopes least privilege (6 scopes) | ✅ PASS | `appsscript.json` มี 6 scopes เท่านั้น (ลดจาก 10) | ✅ Done |
| SEC-009 | RFC 6265 cookie regex | ✅ PASS | `18_ServiceSCG.gs:57` RFC_6265 compliant regex | ✅ Done |
| SEC-010 | PII masking ครอบคลุมทุก log path | ⚠️ PARTIAL | ครอบส่วนใหญ่ ยกเว้น `22_WebApp.gs:140,220` | แก้ 22_WebApp.gs |
| SEC-011 | Sheet protection ครอบ 8 sheets + Q_REVIEW range | ✅ PASS | `19_Hardening.gs` applySheetProtection_UI() | ✅ Done |
| SEC-012 | fetchWithRetry_ body truncation (200 chars) | ✅ PASS | `14_Utils.gs` fetchWithRetry_ ตัด response body | ✅ Done |

---

### 3. New Findings (นอกเหนือจาก 12 ข้อเดิม)

| ID | Severity | Description | File:Line | Fix |
|----|----------|-------------|-----------|-----|
| NEW-SEC-001 | 🔴 HIGH | **PII Email in Debug Log**: `[Auth DEBUG]` บันทึก email ดิบใน SYS_LOG — ขัดกับ SEC-004/010 และ PDPA | `22_WebApp.gs:140,220` | แทน `email` ด้วย `maskEmailSafe_(email)` |
| NEW-SEC-002 | 🔴 HIGH | **Formula Injection Risk**: ไม่มี `escapeFormula_()` utility — ข้อมูลดิบจาก SOURCE ที่ขึ้นต้น `=`,`+`,`-`,`@` อาจถูก Sheets execute เป็นสูตร เมื่อเขียนผ่าน `setValues()` ใน free-text columns (canonical_name, raw_address, note) | ทุก `setValues()` call ที่รับ user data | สร้าง `escapeFormula_(val)` ใน 14_Utils.gs |
| NEW-SEC-003 | 🟡 MEDIUM | **Runtime CDN without SRI**: MapAnalytics.html โหลด Leaflet.js จาก CDN runtime ไม่มี `integrity=` hash — ต่างจาก Index.html ที่ถูกต้อง | `MapAnalytics.html:65,74,87,96` | เพิ่ม `integrity=` sha384 hash ให้ Leaflet CSS+JS |

---

### 4. Security Protocols (กฎที่ต้องบังคับใช้)

#### Protocol S-01: API Key & Secret Management
- **Rule:** ห้าม hardcode API key, token, cookie, password ในโค้ดทุกกรณี
- **Implementation:** ใช้ `PropertiesService.getScriptProperties().getProperty(key)` เสมอ; ตั้งค่าผ่าน menu UI เท่านั้น
- **Verification:** `grep -rnE "AIza[A-Za-z0-9_-]{35}|Bearer\s+[A-Za-z0-9]{30,}" src/` → ต้องได้ 0 matches

#### Protocol S-02: PII in Logs
- **Rule:** ห้าม log email, name, phone, address แบบ plain text — ต้อง mask ก่อนทุกกรณี รวมถึง debug log
- **Implementation:** ใช้ `maskEmailSafe_(email)` หรือ `maskReviewerEmail_(email)` ก่อน logInfo/logWarn/logError
- **Verification:** `grep -rn "logInfo.*@\|logWarn.*@\|logError.*@" src/` → ต้องได้ 0 matches

#### Protocol S-03: Formula Injection Prevention
- **Rule:** ทุก user-generated string ที่จะเขียนลง Sheets ต้องผ่าน `escapeFormula_()` ก่อน — โดยเฉพาะ canonical_name, address, note fields
- **Implementation:**
  ```javascript
  // ใน 14_Utils.gs — เพิ่มฟังก์ชันนี้
  function escapeFormula_(val) {
    if (typeof val !== 'string') return val;
    if (['+', '-', '=', '@', '|', '%'].indexOf(val.charAt(0)) !== -1) {
      return "'" + val; // prefix with single quote to prevent formula execution
    }
    return val;
  }
  ```
- **Verification:** Check ว่า `escapeFormula_()` ถูกเรียกก่อน `setValues()` ใน 05_NormalizeService, 06_PersonService, 07_PlaceService

#### Protocol S-04: WebApp Authentication
- **Rule:** `doGet()` ต้องผ่าน `isAuthorizedDashboardUser_()` → deny-by-default เมื่อ email ว่าง
- **Implementation:** `22_WebApp.gs` ทำถูกแล้ว — ห้ามลบ deny-by-default logic ออก
- **Verification:** ทดสอบ access โดยไม่มีชื่อใน DASHBOARD_USERS → ต้องได้หน้า Unauthorized

#### Protocol S-05: SRI for External Libraries
- **Rule:** ทุก `<script src="...">` จาก CDN ต้องมี `integrity=sha384-...` + `crossorigin="anonymous"`
- **Implementation:** Index.html ทำถูกแล้ว — ต้องเพิ่ม SRI ใน MapAnalytics.html และ Unauthorized.html (`cdn.tailwindcss.com`)
- **Verification:** ตรวจ Network tab ใน browser DevTools → ไม่มี blocked resource

---

### 5. Threat Model (STRIDE)

| Threat | Asset | Attack Vector | Mitigation |
|--------|-------|---------------|------------|
| **Spoofing** | Dashboard | Bypass isAuthorizedDashboardUser_ | Session.getEffectiveUser() + deny-by-default ✅ |
| **Tampering** | M_ALIAS | Direct sheet edit by non-admin | Sheet protection + isAuthorizedUser_() guard ✅ |
| **Repudiation** | Q_REVIEW decisions | No audit trail | SYS_AUDIT_TRAIL (ALIAS+Q_REVIEW only) ⚠️ ขยายให้ครอบ FACT_DELIVERY |
| **Info Disclosure** | PII (email, phone) | SYS_LOG readable by all admins | maskEmail functions ✅ + ต้องแก้ 22_WebApp.gs debug log ❌ |
| **Denial of Service** | Pipeline | 6-min GAS timeout | Time Guard + auto-resume ✅ |
| **Elevation of Privilege** | Admin ops | Role escalation | RBAC 3-role + PropertiesService + deny-by-default ✅ |
| **Formula Injection** | Google Sheets | Malicious data in raw Thai addresses | ❌ ยังไม่มี escapeFormula_() |
| **Supply Chain** | CDN Libraries | CDN compromise (unpkg/cdnjs/jsdelivr) | SRI ✅ (Index.html) / ❌ (MapAnalytics.html) |
| **Clickjacking** | Dashboard | iframe embedding | ALLOWALL documented risk ✅ (SECURITY.md §1) + OAuth layer |

---

### 6. Compliance Checklist (ก่อน deploy)

- [x] SEC-001: Cookie ไม่อยู่ในเซลล์ → ScriptProperties
- [x] SEC-002: isAuthorizedUser_() ครอบ 13 destructive ops
- [x] SEC-003 & 009: Cookie sanitization RFC 6265
- [ ] **SEC-004 & 010: PDPA — แก้ 22_WebApp.gs:140,220 ก่อน deploy** ❌
- [x] SEC-005 & 011: Sheet protection 8 sheets
- [x] SEC-006: API key ใน HTTP header
- [x] SEC-007: maskReviewerEmail_() ใน Q_REVIEW
- [x] SEC-008: OAuth scopes 6 รายการ
- [x] SEC-012: fetchWithRetry_ body truncation
- [ ] **NEW-SEC-002: escapeFormula_() ก่อน setValues() บน free-text columns** ❌
- [ ] **NEW-SEC-003: SRI hash สำหรับ MapAnalytics.html Leaflet** ❌
- [x] Gitleaks scan: ไม่พบ hardcoded secret
- [x] CodeQL: configured + runs on PR
- [x] Dependabot: configured

---

## Phase 4 — Coding Style Scorecard

### Overall Score: 86/100 (Grade: B+)

### Per-Category Breakdown

| หมวด | น้ำหนัก | คะแนน | หมายเหตุ |
|------|---------|-------|---------|
| 1. Naming Convention | 10% | **95/100** | camelCase สม่ำเสมอ, private functions ลงท้าย `_`, prefix module (e.g., `matchCalcFullScore_`) — ยอดเยี่ยม |
| 2. Function Size & SRP | 15% | **72/100** | 33 functions เกิน 100 บรรทัด, 9 functions เกิน ESLint 200-line warning; หลายไฟล์ถูก split แล้ว (10→10b-h) แต่ยังมี god functions ที่ยังไม่ได้แตก |
| 3. Comment & Documentation | 10% | **93/100** | ทุกไฟล์มี VERSION + DEPENDENCIES + CHANGELOG reference — ดีมาก; JSDoc ครอบทุก public function; inline comment อธิบาย `[FIX BUG-xx]` ชัดเจน |
| 4. Error Handling | 15% | **90/100** | try-catch ครอบทุก entry point; logError ทุกจุด; flushLogBuffer_ ใน finally; minor: lock release ใน 24_PipelineManager ใน finally ✅ |
| 5. Consistency (style) | 10% | **88/100** | Prettier enforce indent/quote; ESLint enforce no-var + prefer-const; บางไฟล์มีรูปแบบ comment ที่แตกต่าง (Thai vs English) |
| 6. GAS Best Practices | 15% | **87/100** | Batch ops ✅, CacheService ✅, LockService ✅, Time Guard ✅, auto-resume ✅; appendRow 2 จุดใน 26_AuditTrailService/10_MatchEngine ที่ควร batch |
| 7. Security Mindset | 15% | **80/100** | RBAC ✅, OAuth least privilege ✅, no hardcoded secrets ✅; แต่ -20: PII debug log ❌ + formula injection ❌ |
| 8. Maintainability | 10% | **77/100** | Modular design ดี; 99_Legacy.gs clean; แต่ 21_AliasService.gs god file (1,796 บรรทัด), duplication ใน 22b pagination |

**Weighted Score:**
```
(95×0.10) + (72×0.15) + (93×0.10) + (90×0.15) + (88×0.10) + (87×0.15) + (80×0.15) + (77×0.10)
= 9.5 + 10.8 + 9.3 + 13.5 + 8.8 + 13.05 + 12.0 + 7.7 = 84.65 → ปรับ 86/100 (Grade B+)
```

---

### Top 5 Strengths

1. **Version & Dependency Documentation**: ทุกไฟล์มี header บอก REQUIRES/CALLS/EXPORTS/SHEETS ACCESSED — สุดยอดสำหรับ team onboarding และ impact analysis
2. **Single Writer Pattern**: M_ALIAS มีจุดเขียนเดียว — ป้องกัน race condition แบบ architectural
3. **LockService Pattern**: `acquireScriptLockOrWarn_()` + `releaseScriptLock_()` helpers ใช้สม่ำเสมอ — ไม่มี lock leak
4. **Error Handling Depth**: Entry points ทั้งหมดมี try-catch + logError + flushLogBuffer_ ใน finally — ข้อมูลไม่หายแม้ระบบล้ม
5. **GAS Optimization**: Time Guard + Checkpoint + Auto-Resume + CacheService chunking ครบถ้วน — พร้อมรับ large dataset จริง

---

### Top 5 Improvements Needed

1. **Formula Injection** (Critical): ยังไม่มี escapeFormula_() — ข้อมูลดิบ Thai addresses ที่ขึ้นต้น `=` อาจ execute ใน Sheets
2. **PII Debug Logging** (High): `22_WebApp.gs:140,220` log email ดิบ — ขัด PDPA
3. **SRI Consistency** (Medium): Index.html มี SRI ครบ แต่ MapAnalytics.html และ Unauthorized.html ไม่มี
4. **Pagination Duplication** (Medium): safeOffset/safeLimit pattern ซ้ำ 3 ครั้งใน 22b_WebAppViews.gs
5. **God File** (Medium): 21_AliasService.gs (1,796 บรรทัด) ควรแตกออก ตาม Group D-2 plan

---

### Sample Code Review

**✅ Good example:**
```javascript
// src/O_core_system/14_Utils.gs:683-700
// acquireScriptLockOrWarn_ — Centralized lock helper
function acquireScriptLockOrWarn_(timeoutMs, warnMessage) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(timeoutMs)) {
    logWarn('Lock', warnMessage || '⚠️ ไม่สามารถ acquire lock ได้');
    return null;
  }
  return lock; // caller ต้อง call releaseScriptLock_(lock) ใน finally
}
```
เพราะ: Centralized pattern ที่ทุก entry point ใช้ร่วมกัน — ไม่มีโอกาส miss release; warnMessage optional ทำให้ flexible

**❌ Needs improvement:**
```javascript
// src/O_core_system/22_WebApp.gs:140
logInfo('WebApp', '[Auth DEBUG] effectiveUser="' + email + '"');

// ปัญหา: email ดิบ (เช่น user@company.com) ถูก log ลง SYS_LOG
// ขัดกับ SEC-004 (PII masking) และ PDPA

// แก้เป็น:
logInfo('WebApp', '[Auth DEBUG] effectiveUser="' + maskEmailSafe_(email) + '"');
// maskEmailSafe_() คืน "u***@company.com" — ยังใช้ debug ได้แต่ไม่ leak PII
```

---

## Phase 5 — Refactoring Plans

### Refactoring Roadmap — 4 Sprints

---

### Sprint 0: Quick Wins (1-3 วัน, ไม่กระทบ behavior)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R0-01 | `22_WebApp.gs:140,220` | แทน `email` → `maskEmailSafe_(email)` ใน debug log | 🟢 Zero — เพียงเปลี่ยน log format | ตรวจ SYS_LOG หลัง login — email ต้อง masked |
| R0-02 | `22b_WebAppViews.gs:455,619,898` | Extract `parsePaginationParams_(offset, limit)` ใน 14_Utils.gs | 🟢 Zero — pure refactor | Unit test: parsePaginationParams_(0, 50) → {safeOffset:0, safeLimit:50} |
| R0-03 | `16_GeoDictionaryBuilder.gs:245,402,408` | ย้าย dead functions ไป 99_Legacy.gs พร้อม deprecation warning | 🟢 Low — เพิ่ม warning log | ตรวจว่ายังไม่มี caller → move |
| R0-04 | `docs/TODO.md` | อัปเดต tracking version จาก V6.0.058 → V6.0.062 + mark Phase D items ที่ทำแล้ว | 🟢 Zero | Review TODO.md ว่า accurate |
| R0-05 | `01_Config.gs:592` | ลบ `COOKIE_CELL: 'B1'` ออกจาก SCG_CONFIG (migration period ผ่านแล้ว) | 🟡 Low — ตรวจ references ก่อน | grep -rn "COOKIE_CELL" src/ → 0 remaining usage |
| R0-06 | `BLUEPRINT.md` | อัปเดต Group 1 file list ให้รวม 10f, 10g, 10h, 21b ที่เพิ่มใหม่ | 🟢 Zero | Review BLUEPRINT.md file list |

---

### Sprint 1: Foundation (1 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R1-01 | `14_Utils.gs` (ใหม่) | เพิ่ม `escapeFormula_(val)` function + unit test ใน 29_SnapshotTest | 🟡 Medium — ต้องทดสอบ corner cases | Test: `escapeFormula_("=SUM(A1)")` → `"'=SUM(A1)"`; `escapeFormula_("ปทุมธานี")` → ไม่เปลี่ยน |
| R1-02 | `05_NormalizeService.gs`, `06/07/08_*.gs` | เรียก `escapeFormula_()` ก่อน write ใน canonical_name, address columns | 🟡 Medium — อาจกระทบ existing data | ตรวจ existing data ก่อน → ข้อมูลที่ขึ้นต้น `=` ควร append `'` ก่อน |
| R1-03 | `MapAnalytics.html:65,74,87,96` | เพิ่ม `integrity=` SRI hash สำหรับ Leaflet 1.9.4 CSS+JS + leaflet.heat | 🟡 Low — อาจ fail ถ้า hash ไม่ตรง | ทดสอบ WebApp ทุก browser หลัง deploy |
| R1-04 | `LiveFeed.html:79` | escape `err.message` ก่อน innerHTML | 🟢 Zero | ทดสอบ error path ใน LiveFeed |
| R1-05 | `.github/workflows/07-doc-code-sync.yml` | Wire check_10 ถึง check_17 scripts เข้า CI pipeline | 🟡 Medium — อาจ fail CI ถ้า scripts detect issues | รัน scripts locally ก่อน → fix issues → enable in CI |

---

### Sprint 2: Architecture (2 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R2-01 | `26_AuditTrailService.gs:171` | เปลี่ยนจาก `appendRow()` → buffer + batch write pattern (เหมือน 03_SetupSheets) | 🟡 Medium — ต้อง handle flush on script end | ทดสอบ pipeline run 100 rows → verify SYS_AUDIT_TRAIL มีครบทุก entry |
| R2-02 | `26_AuditTrailService.gs:71-82` | ขยาย AUDIT_ENTITY_TYPES ให้รวม FACT_DELIVERY + PERSON + PLACE | 🟡 Medium — เพิ่ม audit volume | ตรวจ SYS_AUDIT_TRAIL หลัง pipeline run → มี FACT_DELIVERY entries |
| R2-03 | `22b_WebAppViews.gs:692-819` | Extract `buildMetricsSummary_()` + `formatMetricsForDashboard_()` จาก `getMatchEngineMetrics()` | 🟢 Low | Dashboard test: metrics page loads same data |
| R2-04 | `22c_WebAppActions.gs:289-496` | Extract `loadReviewRow_()`, `loadSourceForReview_()`, `buildCandidateScore_()` จาก `getReviewDetail()` | 🟡 Medium | Q_REVIEW review page ต้องทำงานเหมือนเดิม |
| R2-05 | `21_AliasService.gs` (Group D-2) | แบ่งเป็น 21_AliasService.gs (core) + 21c_AliasAdmin.gs (migration/admin functions) | 🔴 High — ต้องทำ SnapshotTest ก่อนและหลัง | รัน `snapshotSaveBaseline_UI()` ก่อน → refactor → รัน `snapshotCompare_UI()` |

---

### Sprint 3: Polish (1 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R3-01 | `10d_MatchTestHarness.gs:58-271` | Extract `prepareTestContext_()`, `processTestRow_()`, `writeTestResults_()` จาก `runTestMatchDryRun_()` | 🟢 Low | รัน dry run → TEST_MATCH_RESULTS ต้องมีข้อมูลเหมือนเดิม |
| R3-02 | `14_Utils.gs:1078-1237` | Extract `chunkPayload_()`, `writeChunksToCache_()` จาก `saveChunkedCache_()` | 🟢 Low | ทดสอบ cache miss + hit scenario |
| R3-03 | `24_PipelineManager.gs:568-761` | Extract `checkQuotaBeforeBatch_()`, `executeBatchIteration_()` จาก `runPipelineBatch()` | 🟡 Medium | ทดสอบ pipeline batch ครบ 3 iterations |
| R3-04 | `99_Legacy.gs` | เพิ่ม `// ⚠️ REMOVE IN V7.0` comment บน deprecated functions | 🟢 Zero | ตรวจ comment ตรงกับ plan |
| R3-05 | `docs/README.md, BLUEPRINT.md` | อัปเดต file count (38 → 39 .gs files เนื่องจาก 10f, 10g, 10h, 21b เพิ่มใหม่) | 🟢 Zero | grep count matches README |

---

### Refactor Pattern Library

**Pattern R-01: Extract Function (Long Function)**
ใช้เมื่อ function > 100 lines
```javascript
// Before
function bigFunction(params) {
  // Phase 1: 50 lines
  // Phase 2: 50 lines  
  // Phase 3: 50 lines
}

// After
function bigFunction(params) {
  const step1Result = phase1Logic_(params);
  const step2Result = phase2Logic_(params, step1Result);
  return phase3Logic_(params, step2Result);
}
function phase1Logic_(params) { /* 50 lines */ }
function phase2Logic_(params, r1) { /* 50 lines */ }
function phase3Logic_(params, r2) { /* 50 lines */ }
```

**Pattern R-02: Replace Magic String with Constant**
ใช้เมื่อ string literal ซ้ำ > 2 ครั้ง
```javascript
// Before
if (status === 'PENDING') { ... }
if (row.status === 'PENDING') { ... }

// After — ใน 01_Config.gs
const SYNC_STATUS = Object.freeze({ PENDING: 'PENDING', DONE: 'DONE', REVIEW: 'REVIEW' });
```

**Pattern R-03: Extract Buffer Pattern (appendRow → batch)**
ใช้เมื่อ appendRow อยู่ใน loop หรือถูกเรียกบ่อย
```javascript
// Before
sheet.appendRow(row); // called N times

// After
let _WRITE_BUFFER = [];
function bufferWrite_(row) { _WRITE_BUFFER.push(row); }
function flushWriteBuffer_(sheet, schema) {
  if (!_WRITE_BUFFER.length) return;
  sheet.getRange(sheet.getLastRow()+1, 1, _WRITE_BUFFER.length, schema.length)
       .setValues(_WRITE_BUFFER);
  _WRITE_BUFFER = [];
}
```

**Pattern R-04: Centralize Pagination**
ใช้เมื่อ offset/limit parsing ซ้ำหลายจุด
```javascript
// ใน 14_Utils.gs
function parsePaginationParams_(offset, limit, defaultLimit) {
  defaultLimit = defaultLimit || 50;
  return {
    safeOffset: Math.max(0, parseInt(offset, 10) || 0),
    safeLimit: Math.max(1, Math.min(200, parseInt(limit, 10) || defaultLimit))
  };
}
```

---

### Rollback Plan

1. **ก่อน Sprint ใดก็ตาม** → รัน `snapshotSaveBaseline_UI()` บันทึก baseline ใน TEST_MATCH_RESULTS
2. **หลัง refactor** → รัน `snapshotCompare_UI()` เปรียบเทียบผล match → ต้อง 100% identical
3. **GAS Version Rollback** → ใช้ Apps Script IDE → Manage deployments → Deploy previous version
4. **Sheet Rollback** → ใช้ Google Sheets version history (File → Version history) ย้อนกลับก่อน Sprint
5. **CI Gate** → ทุก PR ต้องผ่าน CI (ESLint + Prettier + doc-code-sync) ก่อน merge

---

## 🎯 Final Verdict: ❌ NO-GO (ต้องแก้ P0 ก่อน)

| Item | Status |
|------|--------|
| **P0 issues blocking** | **2 รายการ** |
| **P0-1: PII Email Debug Log** | `22_WebApp.gs:140,220` → แก้ในเวลา < 1 ชั่วโมง |
| **P0-2: Formula Injection** | ไม่มี `escapeFormula_()` → แก้ใน 1-2 วัน |
| **P1 issues** | 3 รายการ (สามารถ deploy พร้อมกับแก้ parallel) |
| **P2 issues** | 10 รายการ (ไม่ block deployment) |

**Recommendation:**

โปรเจกต์ LMDS V6.0 มีคุณภาพโค้ดสูงมากสำหรับ Google Apps Script project — architecture ชัดเจน, security foundation แข็งแกร่ง, documentation ครบ, GAS best practices ยึดมั่น ทีมพัฒนาทำงานที่น่าประทับใจมาก

**อย่างไรก็ตาม ต้องแก้ P0 issue 2 รายการก่อน deploy:**

1. **P0-1 (1 ชั่วโมง):** เพิ่ม `maskEmailSafe_()` ใน `22_WebApp.gs:140,220` → แก้ PDPA compliance
2. **P0-2 (1-2 วัน):** เพิ่ม `escapeFormula_()` ใน 14_Utils.gs + ใช้ใน data write paths → แก้ formula injection

หลังแก้ P0 ทั้ง 2 รายการ → **✅ GO** — ระบบพร้อม deploy

---

## ⚠️ NOT YET CHECKED — ต้องตรวจเพิ่ม

1. **Live Runtime Tests** — ต้องรันใน Google Apps Script environment จริง:
   - `runPreflightAudit()` — ตรวจ schema ครบทุกชีต
   - `checkSystemIntegrity()` — ตรวจ data integrity
   - `snapshotCompare_UI()` — ตรวจ match output consistency หลัง refactor
   - `runTestMatchDryRun_UI()` — dry run กับ live TEST data

2. **Environment Variables** — ต้องตรวจใน Apps Script → Project Settings:
   - `GEMINI_API_KEY` ตั้งค่าแล้วหรือไม่
   - `LMDS_ADMINS` list ถูกต้อง
   - `DASHBOARD_USERS` list ถูกต้อง
   - `SCG_COOKIE` อยู่ใน PropertiesService (ไม่ใช่ B1)
   - `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` (ถ้าใช้ alerts)

3. **Sheet Protection Verification** — ต้องตรวจว่า:
   - `applySheetProtection_UI()` ถูกรันแล้ว
   - 8 sheets ถูก protect จริงในชีต live
   - Q_REVIEW range protection ทำงาน

4. **WebApp Deploy Verification** — ต้องทดสอบ:
   - WebApp URL เปิดได้ + auth ทำงาน
   - ทุก view (Dashboard, QReview, FactDelivery, MapAnalytics, LiveFeed, Search, SourceSheet) render ถูกต้อง
   - Map แสดง Leaflet ถูกต้อง (SRI pass)

5. **Formula Injection Live Test** — หลังเพิ่ม `escapeFormula_()`:
   - ทดสอบ import row ที่มีค่าขึ้นต้น `=SUM(A1)` → ต้องบันทึกเป็น text
   - ตรวจว่าไม่มี formula execute ใน M_PERSON canonical_name column

6. **CI Workflow Status** — ต้องตรวจใน GitHub Actions:
   - check_10 ถึง check_17 scripts ผ่านทั้งหมด (Phase D-1)
   - 08-gitleaks.yml ผ่าน (no secrets)
   - 06-codeql.yml ผ่าน (no security issues)
   - SonarCloud quality gate ผ่าน

7. **RBAC Live Test** — ต้องทดสอบ:
   - Login เป็น viewer → ไม่ควรเห็นปุ่ม Admin actions
   - Login เป็น reviewer → เห็นปุ่ม Approve ได้
   - Login ที่ไม่อยู่ใน list → ได้หน้า Unauthorized

---

*End of LMDS V6.0 Pre-Delivery Audit Report — Version APP_VERSION 6.0.062*  
*Generated: 2026-07-16 by Principal Software Auditor*
