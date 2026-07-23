Now I have enough data to write the comprehensive audit report. Let me compile the findings into the structured output.Now I have all the data needed for the complete report. Let me write it.ผมมีข้อมูลครบแล้ว เขียนรายงานเต็มรูปแบบได้เลย

---

# 📊 LMDS V6.0 Pre-Delivery Audit Report
### Version Audited: **6.0.072** | Runtime on Production: **6.0.069** ⚠️

---

## Phase 0 — Full Read Status

| รายการ | จำนวน | สถานะ |
|--------|-------|-------|
| ✅ GS source files | 39/39 | อ่านครบ |
| ✅ HTML files | 19/19 | อ่านครบ |
| ✅ Root docs (.md) | 6/6 | อ่านครบ |
| ✅ docs/*.md | 41/41 | อ่านครบ |
| ✅ Skills (SKILL.md) | 1/1 (consolidated) | อ่านครบ |
| ✅ GitHub Workflows | 9/9 | อ่านครบ |
| ✅ Config files | appsscript.json, .eslintrc.yml, .gitleaks.toml | อ่านครบ |

**Mental Model สรุป:**
- **Functions:** 544 (ยืนยันโดย grep)
- **Lines:** 28,208 (GS) + HTML
- **JSDoc coverage:** 82% (451/544)
- **Duplicate functions:** 0
- **Undefined function calls (ยืนยันแล้ว):** 0 — false positives ทั้งหมดมาจาก DEPENDENCIES comment blocks เท่านั้น

---

## Phase 1 — Technical Debt Analysis

## Technical Debt Inventory

| # | Category | File:Line | Description | Priority | Effort | Impact | Fix Suggestion |
|---|----------|-----------|-------------|----------|--------|--------|----------------|
| TD-001 | A | `09_DestinationService.gs:144` | ใช้ bare `lock.releaseLock()` แทน `releaseScriptLock_(lock)` — ไม่สอดคล้องกับมาตรฐาน V6.0.071 | P1 | S | Medium | เปลี่ยนเป็น `releaseScriptLock_(lock)` ใน finally block |
| TD-002 | A | `21b_AliasSafeguard.gs:1-242` | Layer 2 (Repetition Consensus), Layer 3 (Conflict Detection), Layer 4 (Probation Lifecycle) ยังไม่ implement — มีแค่ Layer 1+5 | P1 | L | Medium | Implement ตาม design ใน docs/ai-reviews/ เมื่อทีมโตขึ้น หรือมี misclick merge เกิดขึ้นจริง |
| TD-003 | A | `10_MatchEngine.gs:810-835` | `getDriverHistory_()` อ่าน FACT_DELIVERY ทั้งชีต (14k+ rows) ทุกครั้งที่เรียก tie-breaking — N+1 pattern | P1 | M | High | Cache ผลลัพธ์ใน module-level var ต่อ run เหมือนที่ `_ALIAS_ENRICHMENT_CONTEXT` ทำ |
| TD-004 | A | `26_AuditTrailService.gs:171` | `sheet.appendRow(row)` แทน `sheet.getRange(...).setValues([row])` — ช้ากว่าและ inconsistent กับมาตรฐาน | P2 | S | Low | เปลี่ยนเป็น `getRange(lastRow+1, 1, 1, len).setValues([row])` |
| TD-005 | A | `28_WebAppActions.gs:621` | Magic number `8` — `sheet.getRange(2, 1, lastRow - 1, 8).getValues()` ควรใช้ `Object.keys(TEST_MATCH_IDX).length` | P2 | S | Low | แทนด้วย `SCHEMA[SHEET.TEST_MATCH_RESULTS].length` |
| TD-006 | A | `22b_WebAppViews.gs:908-918` | `getRangeList(a1Notations).getRanges()` แล้ว `getValues()` ทีละ Range ใน for-loop — N API calls ต่อ page (N=limit) | P2 | M | Medium | ใช้ Sheets API v4 `batchGet` หรือ spread rows เป็น 1 block read แล้ว filter |
| TD-007 | A | หลายไฟล์ | `haversineDistance` มี 4 implementations ที่แตกต่างกันชื่อ: `haversineDistanceM`, `haversineDistanceKm`, `haversineDistance`, `haversineDistanceMeters_` | P2 | S | Low | Consolidate เป็น 1 ฟังก์ชันใน `14_Utils.gs` แล้ว alias ที่เหลือ |
| TD-008 | A | `24_PipelineManager.gs:1370-1376` | `console.log/warn/error` fallback ใน `logPipeline_` — ควรใช้ project logging pattern | P2 | S | Low | ใช้ `logInfo/logWarn/logError` ตลอด (with typeof guard) |
| TD-009 | C | `22c_WebAppActions.gs:296-503` | `getReviewDetail()` ทำ linear scan O(n) บน Q_REVIEW เพื่อหา reviewId — ไม่มี index | P2 | M | Low | Build Map `reviewId → rowIndex` ครั้งเดียวก่อน search (ตรงที่ bulk load เสร็จ) |
| TD-010 | D | `docs/TODO.md` | ⚠️ WebApp ที่ deploy จริงยังเป็น V6.0.069 — โค้ดคือ V6.0.072 มีความแตกต่าง 3 PR (#191/#192/#193) | **P0** | S | **Critical** | Deploy V6.0.072 ขึ้น production ก่อนส่งมอบ |
| TD-011 | B | `21_AliasService.gs` | 1,796 บรรทัด — monolith file, deferred เป็น Group D | P3 | L | Low | Split เมื่อเจอปัญหา maintenance จริง (cohesion ยังสูง) |
| TD-012 | B | `05_NormalizeService.gs` | 1,419 บรรทัด — monolith file, deferred เป็น Group D | P3 | L | Low | Split เมื่อเจอปัญหา maintenance จริง |
| TD-013 | D | `15_GoogleMapsAPI.gs:232` | `GOOGLEMAPS_REVERSEGEOCODE` — const arrow function ใช้เป็น custom formula ใน Sheets; status "deferred" (ISSUE-009) | P3 | S | Low | ยืนยัน status เป็น active Sheets formula หรือลบ |
| TD-014 | D | ทั้งโปรเจกต์ | JSDoc coverage 82% (451/544) — เหลือ 93 functions ไม่มี JSDoc | P3 | M | Low | เพิ่ม JSDoc ในรอบ Sprint 3 (Polish) |

**Summary:**
- Total: 14 items (P0: 1 / P1: 3 / P2: 6 / P3: 4)
- Quick wins (< 1 วัน): TD-001, TD-004, TD-005, TD-007, TD-008 (5 items)
- **Critical (P0) ต้องแก้ก่อนส่งมอบ: TD-010 — Deploy V6.0.072 ขึ้น production**

---

## Phase 2 — Code Review Tips

---

### Code Review Tips — `09_DestinationService.gs`

#### ✅ จุดที่ทำได้ดี
- Nested try-finally รอบ lock ใน `createDestination` — ป้องกัน lock leak ได้ถูก pattern
- ตรวจ lat/lng validity ก่อนเก็บ (`isNaN`, zero-check)
- ใช้ `sanitizeRowForSheet_()` ก่อน setValues ทุกครั้ง (formula injection guard)
- AuthZ check ด้วย `isAuthorizedOrFail_()` ก่อน lock ทุก write operation

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: `lock.releaseLock()` → `releaseScriptLock_(lock)`**
- 📍 Location: `src/1_group1_master_db/09_DestinationService.gs:144`
- 🔍 Issue: ใช้ bare `lock.releaseLock()` ใน finally แทน wrapper `releaseScriptLock_(lock)` ที่โปรเจกต์ migrate มาใน V6.0.071-072 (TD-001 รอบ 4, P2-R5-3 รอบ 5)
- 💡 Suggestion:
```javascript
// Before (09_DestinationService.gs:144)
} finally {
  lock.releaseLock();
}

// After
} finally {
  releaseScriptLock_(lock); // null-safe hasLock() guard — pattern มาตรฐาน V6.0.071+
}
```
- 🎯 Why: GAS documentation ยืนยันว่า `releaseLock()` บน lock ที่ไม่ได้ acquire ไม่ throw (V6.0.069 audit confirmed) แต่ผลคือ inconsistent กับ 3 จุดอื่นที่แก้แล้ว (00_App.gs:327, 24_PipelineManager.gs:761, 12b_ReviewReprocessor.gs:90)

---

### Code Review Tips — `10_MatchEngine.gs`

#### ✅ จุดที่ทำได้ดี
- `makeMatchDecision()` refactored เป็น dispatcher ที่สะอาด — 8 rules แยกชัดเจนใน `10b_MatchDecision.gs`
- Time guard `hasTimePassed_()` ทุก iteration
- `cleanupMatchEngineRun_()` ทำ cleanup ครบ (lock, context, log flush)
- Emergency stop `isPipelineStopRequested_()` ตรวจทุก batch

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #2: `getDriverHistory_()` — N+1 Sheet Read**
- 📍 Location: `src/1_group1_master_db/10_MatchEngine.gs:810-835`
- 🔍 Issue: ฟังก์ชันนี้อ่าน FACT_DELIVERY ทั้งชีต (14k+ rows ตาม user report) ทุกครั้งที่เรียกเพื่อ tie-breaking ใน `breakTieAmongCandidates()` (line 769) ซึ่งอาจเรียกหลายรอบใน 1 pipeline run
- 💡 Suggestion:
```javascript
// เพิ่ม module-level cache (reset โดย resetAliasEnrichmentContext_)
let _DRIVER_HISTORY_CACHE = null;

function getDriverHistory_(driverName) {
  // Lazy-load FACT_DELIVERY ครั้งเดียวต่อ match engine run
  if (!_DRIVER_HISTORY_CACHE) {
    _DRIVER_HISTORY_CACHE = _buildDriverHistoryIndex_();
  }
  return _DRIVER_HISTORY_CACHE[driverName] || [];
}

function _buildDriverHistoryIndex_() {
  const index = {};
  // ... อ่าน FACT_DELIVERY ครั้งเดียว แล้ว group by driverName ...
  return index;
}
```
- 🎯 Why: ลด API calls จาก O(n) → O(1) per driver lookup ใน single pipeline run

---

### Code Review Tips — `26_AuditTrailService.gs`

#### ✅ จุดที่ทำได้ดี
- Input validation (entityType/action whitelist) ก่อนเขียน
- truncate_ local function ป้องกัน row overflow (500 chars)
- logDebug level — ไม่สร้าง log spam
- `try { email = Session.getEffectiveUser() } catch {}` — resilient

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #3: `appendRow` → `setValues` + Batch Buffer**
- 📍 Location: `src/O_core_system/26_AuditTrailService.gs:171`
- 🔍 Issue: `sheet.appendRow(row)` ทำ 1 API call ต่อ audit event แม้จะ low-frequency ก็ยัง inconsistent กับ project standard (Immutable Law: batch ops)
- 💡 Suggestion:
```javascript
// After
const lastRow = sheet.getLastRow();
sheet.getRange(lastRow + 1, 1, 1, row.length).setValues([row]);
```
- 🎯 Why: `setValues` เร็วกว่า `appendRow` เล็กน้อยและ consistent กับ createDestination, createPerson, createPlace ที่ใช้ pattern นี้แล้ว

---

### Code Review Tips — `22b_WebAppViews.gs`

#### ✅ จุดที่ทำได้ดี
- V6.0.009 P2.4: Read single status column ก่อน, แล้ว read full columns เฉพาะ page — ลด payload 10-50x
- `parsePaginationParams_()` DRY helper ใช้ทุก 3 paginated endpoints
- `bucketSyncStatus_` local function ชัดเจน

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #4: `getRangeList + getValues per-range` ยังทำ N API calls**
- 📍 Location: `src/O_core_system/22b_WebAppViews.gs:909-916`
- 🔍 Issue: `sheet.getRangeList(a1Notations).getRanges()` แล้วเรียก `ranges[r].getValues()` ใน for-loop ยังทำ N Sheets API calls สำหรับ page size N (เช่น 20 calls สำหรับหน้า 20 rows)
- 💡 Suggestion:
```javascript
// Option A (ถ้า page indices contiguous): read 1 block
// Option B (scattered): ใช้ Sheets API v4 batchGet ผ่าน advanced service
// Option C (pragmatic สำหรับ GAS): ถ้า pageIndices ไม่ห่างกันมาก
//   หา min-max row แล้วอ่าน block เดียว แล้ว filter
const minIdx = Math.min(...pageIndices);
const maxIdx = Math.max(...pageIndices);
const blockData = sheet.getRange(minIdx + 2, 1, maxIdx - minIdx + 1, lastCol).getValues();
pageRows = pageIndices.map(idx => blockData[idx - minIdx]);
```
- 🎯 Why: ลดจาก N Sheets API calls → 1 call สำหรับ dashboard ที่ responsive ต้องการ

---

### Code Review Tips — `28_WebAppActions.gs`

#### ✅ จุดที่ทำได้ดี
- Action Registry pattern สะอาด — `getWebAppActionRegistry()` dispatch table ชัดเจน
- ทุก action ผ่าน RBAC `isAuthorizedOrFail_()` ก่อน execute
- Result object consistent: `{ ok, message, data }`

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #5: Magic Number 8 ใน `analyzeRule5PlaceOnlyImpact_Web`**
- 📍 Location: `src/O_core_system/28_WebAppActions.gs:621`
- 🔍 Issue: `sheet.getRange(2, 1, lastRow - 1, 8).getValues()` ใช้ magic number 8 แทน constant
- 💡 Suggestion:
```javascript
// Before
const data = sheet.getRange(2, 1, lastRow - 1, 8).getValues();
// After
const numCols = SCHEMA[SHEET.TEST_MATCH_RESULTS]
  ? SCHEMA[SHEET.TEST_MATCH_RESULTS].length
  : Object.keys(TEST_MATCH_IDX).length; // fallback
const data = sheet.getRange(2, 1, lastRow - 1, numCols).getValues();
```
- 🎯 Why: ถ้า TEST_MATCH_RESULTS เพิ่ม column ในอนาคต magic number จะพลาดโดยไม่มี compile-time error

---

### 📊 สรุปรายไฟล์

| File | Tips Count | Severity | Top Issue |
|------|-----------|---------|-----------|
| `09_DestinationService.gs` | 1 | LOW | bare lock.releaseLock() |
| `10_MatchEngine.gs` | 1 | MEDIUM | getDriverHistory_ N+1 |
| `26_AuditTrailService.gs` | 1 | LOW | appendRow |
| `22b_WebAppViews.gs` | 1 | MEDIUM | N API calls per page |
| `28_WebAppActions.gs` | 1 | LOW | magic number 8 |
| `14_Utils.gs` | 0 | — | ✅ ดีมาก |
| `10b_MatchDecision.gs` | 0 | — | ✅ ดีมาก |
| `27_RbacService.gs` | 0 | — | ✅ ดีมาก |
| `22_WebApp.gs` | 0 | — | ✅ ดีมาก (known XFrame trade-off documented) |
| `24_PipelineManager.gs` | 0 | — | ✅ ดีมาก |
| อื่นๆ (29 files) | 0 | — | ไม่พบ issue เพิ่มเติม |

> ⚠️ NOT YET CHECKED (Phase 2): รูปแบบการ render ของ HTML views ไม่สามารถทดสอบ live ใน GAS sandbox ได้ — ต้องทดสอบบน production URL

---

## Phase 3 — Security Protocols

### 1. Executive Summary

- **Overall Risk:** LOW-MEDIUM (ลดลงจาก MEDIUM ในรอบก่อน หลัง V6.0.070-072)
- **Critical findings:** 0
- **New findings นอก SEC-001→012:** 2 (SEC-013, SEC-014)
- **Compliance status:** 11/12 PASS, 1 DOCUMENTED RISK (SEC-011 XFrame)

---

### 2. SEC-001 → SEC-012 Audit

| ID | Description | Status | Evidence | Fix |
|----|-------------|--------|----------|-----|
| SEC-001 | SCG API URL ไม่ hardcode | ✅ PASS | `01_Config.gs: SCG_CONFIG.API_URL` throws ถ้าไม่ได้ตั้งค่า `SCG_API_URL` ใน PropertiesService | — |
| SEC-002 | Gemini API Key ไม่ hardcode | ✅ PASS | `01_Config.gs:883` ดึงจาก `PropertiesService` + validate pattern | — |
| SEC-003 | Cookie ไม่ใช้ cell B1 (deprecated) | ✅ PASS | V6.0.070: `getSCGCookie_()` อ่านจาก PropertiesService; B1 ใน config มี comment `DEPRECATED` | — |
| SEC-004 | Input sanitization | ✅ PASS | `sanitizeForSheet_()`, `sanitizeRowForSheet_()`, `validateInput_()` ใช้ก่อน write ทุกจุด | — |
| SEC-005 | Formula injection guard | ✅ PASS | V6.0.066: `sanitizeRowForSheet_()` strip `=,+,-,@` prefix | — |
| SEC-006 | XSS protection ใน HTML | ✅ PASS | `escapeHtml_()` ใช้ใน 112 จุดตาม SECURITY.md (ตรวจด้วย grep ยืนยัน QReview.html, Dashboard.html) | — |
| SEC-007 | RBAC deny-by-default | ✅ PASS | V6.0.072: `isAuthorizedOrFail_()` fail-closed helper — 24 call sites migrate ครบ | — |
| SEC-008 | PII email masking ใน log | ✅ PASS | V6.0.071: `maskEmailSafe_()` ใน submitReviewDecision; V6.0.071: `maskSearchQuery_()` ใน searchLocations | — |
| SEC-009 | Telegram token ไม่ hardcode | ✅ PASS | `24_PipelineManager.gs:1432` ดึงจาก `PropertiesService.getScriptProperties()` | — |
| SEC-010 | UrlFetch: muteHttpExceptions + response check | ✅ PASS | ทุก UrlFetch call ใช้ `muteHttpExceptions: true` + `getResponseCode()` check | — |
| SEC-011 | XFrameOptionsMode | ⚠️ DOCUMENTED RISK | `22_WebApp.gs:61,85` ใช้ `ALLOWALL` — อธิบายใน SECURITY.md พร้อม 5-layer mitigation | ใช้ DEFAULT ถ้า Google sandbox อนุญาต |
| SEC-012 | OAuth scopes (least privilege) | ✅ PASS | `appsscript.json`: 6 scopes ที่จำเป็นเท่านั้น — ตรวจแล้ว ไม่มี `auth/drive` ที่ไม่จำเป็น | — |

---

### 3. New Findings (นอกเหนือจาก 12 ข้อเดิม)

| ID | Severity | Description | File:Line | Fix |
|----|----------|-------------|-----------|-----|
| SEC-013 | LOW | `logAuditTrail()` log email โดยไม่ mask ที่ DEBUG level: `' by ' + changedBy` | `26_AuditTrailService.gs:180` | ใช้ `getMaskedEmail_(changedBy)` แทน raw email ใน debug log |
| SEC-014 | LOW | `getReviewDetail()` return raw `reviewer` email field ใน response object (line ~340) โดยไม่ mask — frontend อาจ display หรือ log | `22c_WebAppActions.gs:~340` | `reviewer: maskEmailSafe_(String(reviewRow[REVIEW_IDX.REVIEWER] || ''))` |

---

### 4. Security Protocols (กฎบังคับใช้)

#### Protocol S-01: API Key Management
- **Rule:** ห้าม hardcode secrets ทุกรูปแบบใน .gs, .html, .json, .yml
- **Implementation:** ใช้ `PropertiesService.getScriptProperties()` เสมอ; validate format ก่อนใช้ (เช่น `getGeminiApiKey()` validate pattern)
- **Verification:** `.gitleaks.toml` + workflow `08-gitleaks.yml` scan ทุก push

#### Protocol S-02: Authentication & Authorization
- **Rule:** ทุก entry point (menu action, WebApp handler, trigger handler) ต้องผ่าน auth check ก่อน execute
- **Implementation:** `isAuthorizedOrFail_()` (fail-closed) สำหรับ admin ops; `isAuthorizedDashboardUser_()` สำหรับ WebApp views; `requirePermission_()` สำหรับ sensitive actions
- **Verification:** ตรวจด้วย `check_10` ใน CI workflow

#### Protocol S-03: Input Validation & Output Encoding
- **Rule:** ทุก user input ผ่าน `validateInput_()` ก่อนใช้; ทุก sheet write ผ่าน `sanitizeRowForSheet_()`; ทุก HTML render ใช้ `escapeHtml_()`
- **Implementation:** ดู `14_Utils.gs:1410,1434` และ `19_Hardening.gs:953`
- **Verification:** Code review checklist ใน PR template

#### Protocol S-04: PII Protection
- **Rule:** Email address ห้าม log ใน plain text; ใช้ `maskEmailSafe_()` หรือ `getMaskedEmail_()` ทุกครั้ง
- **Implementation:** V6.0.071 fix สำหรับ submitReviewDecision + searchLocations
- **Exception ที่ยังค้าง:** `26_AuditTrailService.gs:180` (SEC-013 above)

#### Protocol S-05: Lock Management
- **Rule:** ทุก LockService acquisition ต้องใช้ `releaseScriptLock_(lock)` ใน finally block — ห้ามใช้ bare `lock.releaseLock()`
- **Implementation:** `14_Utils.gs:697-710` defines `releaseScriptLock_`
- **Exception ที่ยังค้าง:** `09_DestinationService.gs:144` (TD-001)

---

### 5. Threat Model (STRIDE — Summary)

| Threat | Asset | Attack Vector | Mitigation |
|--------|-------|---------------|------------|
| **Spoofing** | Dashboard | Bypass Google OAuth | isAuthorizedDashboardUser_ + DASHBOARD_USERS whitelist |
| **Tampering** | M_ALIAS, Q_REVIEW | Direct sheet edit | Sheet protection (applySheetProtection_UI) + Audit Trail |
| **Repudiation** | Review decisions | Deny approval action | SYS_AUDIT_TRAIL (logAuditTrail) + reviewer email |
| **Info Disclosure** | SCG API Cookie | Sheet B1 visible to editors | V6.0.070: migrate to PropertiesService |
| **DoS** | Pipeline | Trigger spam / concurrent runs | LockService + Circuit Breaker (24_PipelineManager) |
| **Elevation** | Admin functions | Viewer tries to run pipeline | RBAC 3-role deny-by-default (V6.0.072) |

---

### 6. Compliance Checklist (ก่อน deploy)

- [x] API keys อยู่ใน PropertiesService (SEC-001, 002, 009)
- [x] Cookie ย้ายจาก B1 → PropertiesService (V6.0.070)
- [x] RBAC deny-by-default (V6.0.072)
- [x] XSS escapeHtml ใน 112 จุด (V6.0.064)
- [x] Formula injection guard (V6.0.066)
- [x] PII masking ใน search + review logs (V6.0.071)
- [ ] **SEC-013: mask email ใน audit trail debug log** (ยังค้าง)
- [ ] **SEC-014: mask reviewer email ใน getReviewDetail response** (ยังค้าง)
- [ ] **Deploy V6.0.072 ขึ้น production** (CRITICAL)

---

## Phase 4 — Coding Style Scorecard

### Overall Score: **84/100** (Grade: **B+**)

### Per-Category Breakdown

| หมวด | น้ำหนัก | คะแนน/100 | Weighted | หมายเหตุ |
|------|---------|----------|---------|---------|
| 1. Naming Convention | 10% | 92 | 9.2 | camelCase ถูกต้อง, private suffix `_` สม่ำเสมอ, constants UPPER_SNAKE |
| 2. Function Size & SRP | 15% | 74 | 11.1 | 8 functions > 150 lines; `submitReviewDecision` (195L), `getReviewDetail` (208L) ใหญ่เกิน |
| 3. Comment & Documentation | 10% | 82 | 8.2 | JSDoc 82% (451/544); file header ทุกไฟล์ดีมาก; แต่ 93 functions ขาด JSDoc |
| 4. Error Handling | 15% | 88 | 13.2 | try-catch ครบ, logError consistent, safeUiAlert_ แทน ui.alert ทุกจุด |
| 5. Consistency (style) | 10% | 90 | 9.0 | indent 2-space, single quote, semicolons — `.eslintrc.yml` enforce |
| 6. GAS Best Practices | 15% | 86 | 12.9 | batch getValues/setValues, chunked cache, LockService pattern ดี (ยกเว้น 1 จุด) |
| 7. Security Mindset | 15% | 85 | 12.8 | RBAC ครบ, no secrets, escapeHtml ใช้ (ยกเว้น SEC-013/014) |
| 8. Maintainability | 10% | 80 | 8.0 | DRY ดี (parsePaginationParams_, clearSheetsPreserveHeaders_) แต่ monolith files ใหญ่ |
| **รวม** | **100%** | — | **84.4** | |

---

### Top 5 Strengths

1. **Config-driven architecture** — `SHEET.*`, `*_IDX`, `CACHE_KEY` ใช้แทน magic strings/numbers ทั่วโปรเจกต์ (ยกเว้น 1 จุด TD-005)
2. **Lock pattern สอดคล้อง** — `releaseScriptLock_()` wrapper ใช้แล้ว 3/4 จุด; pattern ชัดเจน (V6.0.071-072)
3. **RBAC deny-by-default** — `isAuthorizedOrFail_()` fail-closed ใน 24 call sites (V6.0.072)
4. **3-layer cache** — RAM → CacheService (chunked) → Sheet ออกแบบดีมาก; `saveChunkedCache_/loadChunkedCache_` ครอบคลุมทุก entity
5. **Error resilience** — `safeRun()`, `callSpreadsheetWithRetry()`, `withEntryPointGuard_()` ครอบคลุม entry points

---

### Top 5 Improvements Needed

1. **Function size** — `getReviewDetail` (208L), `runTestMatchDryRun_` (214L), `submitReviewDecision` (195L) ควรแตกย่อย
2. **JSDoc coverage 82%** — 93 functions ขาด — ควรครบ 95%+ ก่อนส่งมอบ
3. **Monolith files** — `21_AliasService.gs` (1,796L), `05_NormalizeService.gs` (1,419L) ทำให้ navigate ยาก
4. **Haversine duplication × 4** — ควรมี 1 canonical implementation ใน `14_Utils.gs`
5. **getSourcePage N API calls** — `getRangeList + per-range getValues` ทำให้ paginated view ช้า

---

### Sample Code Review

**✅ Good example:**
```javascript
// src/O_core_system/14_Utils.gs:697-710
function releaseScriptLock_(lock) {
  if (lock && lock.hasLock()) {
    try {
      lock.releaseLock();
    } catch (e) {
      /* ignore */
    }
  }
}
```
เพราะ: null-safe, hasLock() guard, swallow exception — ป้องกัน double-release error โดยไม่กระทบ control flow

---

**❌ Needs improvement:**
```javascript
// src/1_group1_master_db/09_DestinationService.gs:144
} finally {
  lock.releaseLock(); // ← ควรเป็น releaseScriptLock_(lock)
}
```
ปัญหา: ไม่สอดคล้องกับมาตรฐาน V6.0.071 ที่ migrate จุดอื่นแล้ว
แก้เป็น: `releaseScriptLock_(lock);`

---

## Phase 5 — Refactoring Plans

## Refactoring Roadmap — 4 Sprints

### Sprint 0: Quick Wins (1-3 วัน, ไม่กระทบ behavior)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R0-1 | `09_DestinationService.gs:144` | `lock.releaseLock()` → `releaseScriptLock_(lock)` | ⬤ Zero | `grep releaseLock` ยืนยัน 0 bare calls |
| R0-2 | `26_AuditTrailService.gs:171` | `sheet.appendRow(row)` → `getRange(lastRow+1,...).setValues([row])` | ⬤ Zero | Run logAuditTrail test ดู SYS_AUDIT_TRAIL |
| R0-3 | `28_WebAppActions.gs:621` | `8` → `SCHEMA[SHEET.TEST_MATCH_RESULTS].length` หรือ `Object.keys(TEST_MATCH_IDX).length` | ⬤ Zero | analyzeRule5PlaceOnlyImpact_Web ยังทำงานปกติ |
| R0-4 | `26_AuditTrailService.gs:180` | mask email → `getMaskedEmail_(changedBy)` | ⬤ Zero | ตรวจ SYS_AUDIT_TRAIL ว่า email ถูก mask |
| R0-5 | `22c_WebAppActions.gs:~340` | mask reviewer email → `maskEmailSafe_(...)` | ⬤ Zero | QReview detail modal ยังแสดง reviewer |
| R0-6 | Deploy V6.0.072 | Push V6.0.072 ขึ้น WebApp production | 🟡 Medium | ทดสอบ 6 จุดใน TODO.md |

---

### Sprint 1: Foundation (1 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R1-1 | `10_MatchEngine.gs:810` | `getDriverHistory_()` → module-level `_DRIVER_HISTORY_CACHE` (lazy-load, reset in `resetAliasEnrichmentContext_`) | 🟡 Medium | Run dry-run `runTestMatchDryRun_` → ผล tie-breaking เหมือนเดิม |
| R1-2 | `22b_WebAppViews.gs:908` | `getRangeList + per-range getValues` → single block read + filter | 🟡 Medium | QReview/Source page pagination ยังทำงาน (offset/limit ถูก) |
| R1-3 | หลายไฟล์ | Consolidate haversine → 1 canonical `haversineDistanceM` ใน `14_Utils.gs`; alias `haversineDistance` และ `haversineDistanceMeters_` เป็น call-through | 🟡 Medium | 29_SnapshotTest.gs ผ่าน 0 differences |
| R1-4 | `24_PipelineManager.gs:1370-1376` | `console.log/warn/error` → `logInfo/logWarn/logError` with typeof guard | ⬤ Zero | ดู SYS_LOG หลัง pipeline run |

---

### Sprint 2: Architecture (2 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R2-1 | `22c_WebAppActions.gs:296` | แตก `getReviewDetail()` (208L) ออกเป็น `_fetchReviewRow_()`, `_fetchSourceContext_()`, `_buildPersonPlaceContext_()`, `_buildDestContext_()` | 🔴 High | QReview detail modal ทุก field ถูกต้อง |
| R2-2 | `22c_WebAppActions.gs:87` | แตก `submitReviewDecision()` (195L) ออกเป็น `_validateReviewInput_()`, `_acquireReviewLock_()`, `_executeReviewDecision_()`, `_writeFactRow_()` | 🔴 High | Approve review ใน QReview → FACT_DELIVERY ถูก + Rollback ถ้า FACT write fail |
| R2-3 | `21b_AliasSafeguard.gs` | Implement Layer 2 (Repetition Consensus) ถ้าทีมพร้อม | 🔴 High | createGlobalAlias source='HUMAN' → ต้องผ่าน Layer 2 check |

---

### Sprint 3: Polish (1 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R3-1 | ทั้งโปรเจกต์ | เพิ่ม JSDoc ให้ 93 functions ที่ขาด (เน้น private helpers) | ⬤ Zero | JSDoc coverage ≥ 95% |
| R3-2 | `22c_WebAppActions.gs:296` | `getReviewDetail()` linear scan → build Map ก่อน search | 🟡 Medium | Response time ลดลงสำหรับ Q_REVIEW ขนาดใหญ่ |
| R3-3 | docs/ | Sync docs ทุกครั้งหลัง merge — บทเรียนจาก V6.0.069→072 doc debt | ⬤ Zero | Version number ตรงกันใน README, BLUEPRINT, docs ทุกไฟล์ |

---

### Refactor Pattern Library

**Pattern R-01: Extract Function from God Function**
```javascript
// Before: submitReviewDecision (195 lines)
function submitReviewDecision(reviewId, decision, note) {
  // ... 195 lines ทุกอย่าง ...
}

// After: Dispatcher + extracted helpers
function submitReviewDecision(reviewId, decision, note) {
  if (!isAuthorizedDashboardUser_()) throw new Error('Unauthorized');
  const lock = _acquireReviewLock_();
  if (!lock) return { ok: false, code: 'LOCK_BUSY', ... };
  try {
    const context = _buildReviewContext_(reviewId);
    const result  = _executeReviewDecision_(context, decision, note);
    if (result.factRowData) _writeFactRow_(result.factRowData);
    return { ok: true, ... };
  } catch (e) { ... }
  finally { releaseScriptLock_(lock); }
}
```

**Pattern R-02: Module-level Lazy Cache**
```javascript
// Before: N+1 read
function getDriverHistory_(driverName) {
  const data = sheet.getRange(...).getValues(); // อ่านทุกครั้ง
  ...
}

// After: lazy-load once per run
let _DRIVER_HISTORY_INDEX = null;
function getDriverHistory_(driverName) {
  if (!_DRIVER_HISTORY_INDEX) _DRIVER_HISTORY_INDEX = _buildDriverHistoryIndex_();
  return _DRIVER_HISTORY_INDEX[driverName] || [];
}
// Reset ใน resetAliasEnrichmentContext_() (ซึ่ง reset ทุก run)
```

**Pattern R-03: Replace Magic Number**
```javascript
// Before
sheet.getRange(2, 1, lastRow - 1, 8).getValues();
// After
sheet.getRange(2, 1, lastRow - 1, Object.keys(TEST_MATCH_IDX).length).getValues();
```

---

### Rollback Plan

การทำ Sprint 0 ทุกข้อ: rollback ง่ายเพราะเป็น 1-line changes — ใช้ `git revert` ต่อ commit

Sprint 1-2: ทุก refactor ต้องรัน `29_SnapshotTest.gs` (`snapshotSaveBaseline_` ก่อน, `snapshotCompare_` หลัง) ยืนยัน 0 differences ก่อน merge

---

## 🎯 Final Verdict: **⚠️ CONDITIONAL GO**

| รายการ | สถานะ |
|--------|-------|
| P0 blocking issues (code bugs) | ✅ 0 |
| P0 blocking issue (deployment) | ❌ **1** — WebApp ยังเป็น V6.0.069 |
| Security critical | ✅ 0 (2 LOW ค้าง: SEC-013, SEC-014) |
| Data integrity risk | ✅ 0 |
| Lock leak risk | ✅ 0 (getDriverHistory_ ไม่ใช้ lock) |

**Recommendation:**

> โค้ด V6.0.072 พร้อมส่งมอบ **หลัง** ทำ 2 สิ่งนี้:
> 1. **Deploy V6.0.072 ขึ้น production** (WebApp ยังเป็น 6.0.069) — นี่คือ blocker เดียว
> 2. ทำ **Sprint 0 quick wins** (R0-1 ถึง R0-5) ก่อน deploy — เวลารวม < 1 วัน, risk ต่ำ

---

## ⚠️ NOT YET CHECKED — ต้องตรวจเพิ่ม

1. **Live runtime test** — ทดสอบ 6 จุดใน TODO.md (Menu, Pipeline, Search mask, Review mask, M_PLACE normalized, AuthZ viewer) ต้องรันบน production GAS environment จริง — ไม่สามารถ emulate ได้จาก static code audit
2. **SYS_TH_GEO data quality** — ข้อมูลภูมิศาสตร์ไทยใน sheet (10,540 rows ตาม docs) ไม่ได้ตรวจ live
3. **Performance ที่ 14k+ rows** — `getMatchEngineMetrics`, `getDashboardData` ที่ผู้ใช้รายงาน 22,174ms ต้องวัดใหม่หลัง deploy V6.0.072 (มี optimizations จาก V6.0.070)
4. **Trigger health** — `ScriptApp.getProjectTriggers()` — ต้องรัน live ดูว่ามี orphan triggers ค้างหรือไม่
5. **CacheService TTL behavior** — cache expiry พฤติกรรมจริงใน production (GAS CacheService 6h limit)
6. **WebApp render บน mobile** — `MobileActions.html` ต้องทดสอบบน device จริง
7. **Telegram alert** — ต้องตั้ง `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` ก่อนทดสอบ alert flow

---

**Health Score: 84/100** | **สถานะ: CONDITIONAL GO — Deploy แล้วไป ✈️**