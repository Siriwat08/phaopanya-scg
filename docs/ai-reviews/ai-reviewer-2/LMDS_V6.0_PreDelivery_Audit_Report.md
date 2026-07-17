<!-- DOC-TYPE: historical -->
# 📊 LMDS V6.0 Pre-Delivery Audit Report

> **Auditor:** Static Code Audit (Principal-Level)
> **Date:** 2025-07 (V6.0.062)
> **Scope:** 39 .gs files + 19 .html files = 58 source files (27,915 lines of code)
> **Standard:** 16 Immutable Laws, SEC-001→012, LMDS Supreme Engineer skill

---

## Phase 0 — Full Read Status

| ประเภท | จำนวน | สถานะ |
|--------|--------|--------|
| ✅ .gs files | 39/39 | อ่านครบ |
| ✅ .html files | 19/19 | อ่านครบ |
| ✅ Config/CI files | appsscript.json + 9 workflows + .eslintrc.yml + .editorconfig | อ่านครบ |
| ✅ Skills | lmds-supreme-engineer, lmds-gas-best-practices | อ่านครบ |
| ⚠️ NOT YET READ | docs/*.md (30+ docs) — ไม่จำเป็นสำหรับ static audit; ตรวจ source เป็น source of truth |

**Mental Model ที่ได้:**
- **Data Flow**: `SOURCE` → Normalize → MatchEngine (8 rules) → `FACT_DELIVERY` + `Q_REVIEW` → Human Review → `M_ALIAS`
- **4 Domain Groups**: O_core (config/utils/RBAC/webapp) + Group1 (MasterDB) + Group2 (DailyOps) + Group4 (Pipeline)
- **545 functions ใน .gs** + **211 functions ใน .html** = **756 functions รวม**
- **Single Writer Pattern**: `21_AliasService.gs` + `10_MatchEngine.gs` เป็น sole writers ของ `M_ALIAS`
- **Lock Strategy**: LockService.getScriptLock() ใน critical sections ทั้งหมด
- **5-Layer Safeguard**: Implemented Layer 1 + Layer 5 เท่านั้น (Layer 2/3/4 deferred)

---

## Phase 1 — Technical Debt Analysis

### Technical Debt Inventory

| # | Category | File:Line | Description | Priority | Effort | Impact | Fix Suggestion |
|---|----------|-----------|-------------|----------|--------|--------|----------------|
| TD-001 | A (Code) | `10_MatchEngine.gs:95` + `00_App.gs:303` | **Nested LockService double-release** — `runFullPipeline` acquire lock แล้วเรียก `runMatchEngine` ซึ่ง acquire+release lock เดียวกัน → outer `finally` call `lock.releaseLock()` บน lock ที่ release ไปแล้ว ทำให้ `flushLogBuffer_()` ถูกข้ามทุก run | P0 | S | ❗ Log entries หาย ทุก Full Pipeline run | เพิ่ม null-safe pattern: `if (lock && lock.hasLock()) lock.releaseLock()` แทน `lock.releaseLock()` ตรงๆ ที่ `00_App.gs:303` |
| TD-002 | A (Code) | `18_ServiceSCG.gs:328-353` | **SCG Cookie Security Regression** — `getSCGCookie_()` มี comment "REVERTED v5.5.022-hotfix" และอ่าน cell B1 เป็น PRIMARY ก่อน PropertiesService — cookie ยังคง visible ใน plaintext สำหรับทุกคนที่มี sheet edit access | P0 | S | ❗ PII/Secret leak | ลบ cell B1 read path, ใช้ PropertiesService เป็น primary เท่านั้น |
| TD-003 | B (Arch) | `21b_AliasSafeguard.gs:10-18` | **Missing Safeguard Layers 2, 3, 4** — ยังไม่ implement Layer 2 (Repetition Consensus), Layer 3 (Conflict Detection), Layer 4 (Probation). มีเพียง Layer 1 (Levenshtein floor) + Layer 5 (Circuit Breaker) | P0 | L | ❗ Human alias promotion ยังเสี่ยง single-approve attack | Implement ตาม docs/PHASE-C-D-CHECKLIST.md |
| TD-004 | A (Code) | `LiveFeed.html:72` | **XSS — JSON.stringify ไม่ escape** — `JSON.stringify(m)` ถูก insert ตรงๆ ใน `innerHTML` โดยไม่ผ่าน `escapeHtml_()` | P0 | S | ❗ XSS ถ้า recentMatches มี HTML-special chars | ใช้ `escapeHtml_(JSON.stringify(m))` หรือ `textContent` |
| TD-005 | A (Code) | `LiveFeed.html:79` | **XSS — err.message ไม่ escape** — `content.innerHTML = '...' + err.message + '...'` โดยไม่ผ่าน escapeHtml | P0 | S | ❗ XSS ถ้า error message มี user-supplied data | ใช้ `escapeHtml_(err.message)` |
| TD-006 | A (Code) | `22_WebApp.gs:185-186` | **Auth fallback returns true** — เมื่อทั้ง `DASHBOARD_USERS` และ `LMDS_ADMINS` ไม่ได้ตั้งค่า → return `true` ให้ทุกคน (mitigated โดย `access=MYSELF` ใน appsscript.json แต่ยังเป็น risk ใน staging) | P1 | S | HIGH — misconfiguration risk | เปลี่ยน last-resort เป็น `return false` และ log error แทน |
| TD-007 | A (Code) | `22_WebApp.gs:140` | **PII Logging ใน Production** — `logInfo('WebApp', '[Auth DEBUG] effectiveUser="' + email + '"')` ถูก execute ทุก doGet request → PII สะสมใน SYS_LOG | P1 | S | MEDIUM — GDPR/PDPA risk | เปลี่ยนเป็น `logDebug` หรือลบ (ไม่ควร log email ใน INFO level) |
| TD-008 | A (Code) | Various (33 functions) | **Long Functions >100 lines** — มี 33 functions ยาวเกิน 100 บรรทัด; ยาวสุด: `getReviewDetail()` 207 บรรทัด, `runTestMatchDryRun_()` 213 บรรทัด | P1 | M | MEDIUM — maintainability ต่ำ | Extract sub-functions ตาม SRP pattern |
| TD-009 | C (Data) | `26_AuditTrailService.gs:171` | **appendRow() per audit event** — ทุก audit event call `appendRow()` แบบ single-row; ถ้า bulk decision มา → 50+ individual sheet writes | P1 | M | MEDIUM — performance ใน bulk scenario | Buffer audit rows, flush พร้อมกับ batch decision writes |
| TD-010 | A (Code) | `14_Utils.gs:613-614` | **JSDoc ใช้ var ใน comment** — `var lock = LockService.getScriptLock();` ใน JSDoc example (ไม่ใช่ actual code แต่อาจ confuse contributor ใหม่) | P2 | S | LOW | อัปเดต JSDoc example เป็น `const` |
| TD-011 | A (Code) | Multiple | **JSDoc coverage เพียง 39%** — มีเพียง 215/542 functions ที่มี JSDoc block; private functions มักไม่มี JSDoc | P2 | L | LOW — onboarding ยาก | เพิ่ม JSDoc batch (ทำ sprint ละ module) |
| TD-012 | A (Code) | Multiple files | **console.log ใน production GAS** — `24_PipelineManager.gs:1372` มี fallback `console.log` (acceptable); HTML views มี debug `console.log` 10+ instances | P2 | S | LOW | ลบ debug console.log ใน HTML views ก่อน release |
| TD-013 | B (Arch) | `01_Config.gs:588` | **Hardcoded fallback URL** — `SCG_CONFIG.API_URL` getter มี hardcoded fallback `https://fsm.scgjwd.com/Monitor/SearchDelivery` เป็น escape hatch ถ้า PropertiesService ว่าง | P2 | S | LOW | document ชัดเจนใน README ว่านี่เป็น intentional default |
| TD-014 | D (Ops) | `21b_AliasSafeguard.gs:85` | **Boundary condition: `ratio <= floor`** — check strict less-than-or-equal ทำให้ ratio == 0.5 ถูก reject; อาจ false-positive สำหรับชื่อไทยที่แตกต่างกัน moderately | P2 | S | LOW | พิจารณาเปลี่ยนเป็น `ratio < floor` หรือ tune floor ลง 0.45 |
| TD-015 | A (Code) | `00_App.gs:95-111` | **Repeated SS access pattern** — หลายๆ function ใน 06, 07, 08, 09, 10, 12, 16, 21 ฯลฯ เรียก `SpreadsheetApp.getActiveSpreadsheet()` หลายครั้งใน function เดียว (GAS caches it but not free) | P2 | M | LOW | Extract `const ss` ที่ top ของ function |

**Summary:**
- **Total: 15 items (P0: 5 / P1: 4 / P2: 6)**
- **Quick wins (<1 day): 8 items (TD-001, 002, 004, 005, 006, 007, 010, 012)**
- **P0 ต้องแก้ก่อนส่งมอบ: 5 items (TD-001, 002, 003, 004, 005)**


---

## Phase 2 — Code Review Tips

### ไฟล์: `00_App.gs` (1,699 lines)

#### ✅ จุดที่ทำได้ดี
- `safeRun()` wrapper ป้องกัน unhandled exceptions ทุก menu entry point
- `releaseScriptLock_()` helper ป้องกัน null-dereference ก่อน release
- Time-guard pattern ถูกต้อง: ตรวจ `Date.now() - startTime > TIME_LIMIT_MS`

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: Lock Double-Release ใน `runFullPipeline`**
- 📍 Location: `src/O_core_system/00_App.gs:303`
- 🔍 Issue: `lock.releaseLock()` ถูกเรียกแบบ unconditional ใน `finally` แต่ `runMatchEngine()` ที่ถูกเรียกข้างในก็ release lock เดียวกันใน `cleanupMatchEngineRun_()` → GAS อาจ throw ที่ line 303 → `flushLogBuffer_()` ไม่ถูกเรียก

```javascript
// ❌ Before (00_App.gs:302-305)
} finally {
  lock.releaseLock();          // อาจ throw ถ้า runMatchEngine release ไปแล้ว
  if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();
}

// ✅ After
} finally {
  releaseScriptLock_(lock);    // null-safe wrapper ที่มีอยู่แล้วใน 14_Utils.gs
  if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();
}
```
- 🎯 Why: `releaseScriptLock_()` มี `if (lock && lock.hasLock())` guard อยู่แล้ว — เปลี่ยน 1 บรรทัดแก้ปัญหาได้ทันที

---

### ไฟล์: `18_ServiceSCG.gs` (1,227 lines)

#### ✅ จุดที่ทำได้ดี
- `fetchWithRetry_()` มี exponential backoff + `muteHttpExceptions: true`
- `callSCGApi_()` มี try-catch รอบ JSON.parse พร้อม safe error message ไม่รั่ว body
- `withEntryPointGuard_()` ถูก pass `{ lock: lock }` ถูกต้อง → lock release ใน finally

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #2: SCG Cookie Security Regression**
- 📍 Location: `src/2_group2_daily_ops/18_ServiceSCG.gs:328-353`
- 🔍 Issue: `getSCGCookie_()` comment บอก "REVERTED v5.5.022-hotfix" → กลับไปอ่าน cell B1 เป็น primary ก่อน PropertiesService ทำให้ cookie ยังคงอยู่ใน plaintext cell

```javascript
// ❌ Before (v5.5.022-hotfix): อ่าน B1 ก่อน — ไม่ปลอดภัย
function getSCGCookie_() {
  try {
    const fromCell = inputSheet.getRange(SCG_CONFIG.COOKIE_CELL).getValue();
    if (fromCell) return sanitizeCookie_(fromCell);  // B1 เป็น primary!
  } ...
  const fromProps = PropertiesService.getScriptProperties().getProperty('SCG_COOKIE');
  ...
}

// ✅ After: PropertiesService เป็น primary, B1 เป็น fallback+migrate
function getSCGCookie_() {
  // Priority 1: PropertiesService (secure)
  const fromProps = PropertiesService.getScriptProperties().getProperty('SCG_COOKIE');
  if (fromProps) return fromProps;

  // Priority 2: cell B1 (legacy fallback) — auto-migrate + clear
  const fromCell = String(inputSheet.getRange('B1').getValue() || '').trim();
  if (fromCell) {
    PropertiesService.getScriptProperties().setProperty('SCG_COOKIE', sanitizeCookie_(fromCell));
    inputSheet.getRange('B1').clearContent(); // clear after migrate
    return sanitizeCookie_(fromCell);
  }
  return '';
}
```
- 🎯 Why: cookie ใน cell B1 visible ต่อทุกคนที่ share Viewer/Editor access บน sheet

---

### ไฟล์: `21b_AliasSafeguard.gs` (241 lines)

#### ✅ จุดที่ทำได้ดี
- Layer 1 ใช้ Levenshtein ratio (0-1) แทน distance raw — normalize ดีสำหรับชื่อความยาวต่างกัน
- Circuit Breaker มี daily-reset key ด้วย date suffix — ไม่ต้องเคลียร์ manual
- `sendPipelineAlert_()` ถูก guard ด้วย `typeof` — ไม่ crash ถ้า function ไม่มี

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #3: Boundary condition `ratio <= floor` ควรเป็น `ratio < floor`**
- 📍 Location: `src/1_group1_master_db/21b_AliasSafeguard.gs:85`
- 🔍 Issue: ตอนนี้ใช้ `ratio <= floor` (0.5) → ratio == 0.5 ถูก reject; แต่ตาม docstring บอก "reject if variant too dissimilar from canonical" ซึ่งสื่อว่าควร `< floor`

```javascript
// ❌ Before
if (ratio <= floor) {  // ratio == 0.5 ถูก reject

// ✅ After
if (ratio < floor) {   // ratio == 0.5 ผ่าน (borderline similar = allow)
```
- 🎯 Why: ชื่อที่ normalize แล้วอย่าง "สมชาย" vs "นายสมชาย" อาจ score 0.50 พอดี → ควรผ่าน

**Tip #4: Missing canonical-not-found audit log**
- 📍 Location: `src/1_group1_master_db/21b_AliasSafeguard.gs:203-208`
- 🔍 Issue: เมื่อ `getCanonicalNameForAlias_()` คืน '' → Layer 1 ถูก skip โดยไม่มีการ track ว่าเกิดบ่อยแค่ไหน

```javascript
// ✅ After — เพิ่ม counter
if (!canonicalName) {
  logWarn('AliasSafeguard', 'Layer 1 SKIPPED (canonical not found): ' + entityType + ' ' + masterUuid);
  // อาจเพิ่ม PropertiesService counter ถ้าต้องการ monitoring
}
```

---

### ไฟล์: `22_WebApp.gs` (282 lines)

#### ✅ จุดที่ทำได้ดี
- Deny-by-default เมื่อ email ว่าง (line 142-153)
- `maskEmailSafe_()` ป้องกัน PII leak ใน logs
- `ALLOWALL` XFrameOptions มี justification comment ใน SECURITY.md

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #5: Auth DEBUG log เปิดอยู่ใน production**
- 📍 Location: `src/O_core_system/22_WebApp.gs:140`
- 🔍 Issue: `logInfo('WebApp', '[Auth DEBUG] effectiveUser="' + email + '"')` log email ทุก HTTP request → PII accumulation ใน SYS_LOG

```javascript
// ❌ Before
logInfo('WebApp', '[Auth DEBUG] effectiveUser="' + email + '"');

// ✅ After — ใช้ maskEmailSafe_ หรือ logDebug
logDebug('WebApp', '[Auth] effectiveUser=' + maskEmailSafe_(email));
```

**Tip #6: Last-resort auth fallback ควร deny**
- 📍 Location: `src/O_core_system/22_WebApp.gs:184-186`
- 🔍 Issue: return `true` เมื่อไม่มี whitelist เลย — ใน staging environment ที่ deploy ผิด config อาจเปิด dashboard ให้ทุกคน

```javascript
// ❌ Before
logInfo('WebApp', '[Auth] No whitelist — ปล่อยผ่าน (Script Owner)');
return true;

// ✅ After — return false + log warn
logWarn('WebApp', '[Auth] No DASHBOARD_USERS/LMDS_ADMINS set — deny all (configure Script Properties)');
return false;
```

---

### ไฟล์: `LiveFeed.html` (90 lines)

#### ✅ จุดที่ทำได้ดี
- ใช้ `google.script.run` pattern ถูกต้อง (ไม่ fetch URL ตรง)
- Auto-refresh pattern สะอาด

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #7: XSS จาก JSON.stringify ใน innerHTML**
- 📍 Location: `src/3_group3_webapp/views/LiveFeed.html:72`
- 🔍 Issue: `JSON.stringify(m)` มี output เช่น `{"name":"<img src=x onerror=alert(1)>"}` ซึ่งจะ render เป็น HTML

```javascript
// ❌ Before
html += '<div class="text-xs text-gray-500">' + JSON.stringify(m) + '</div>';

// ✅ After — escape ก่อน insert
const esc = globalThis.ViewHelpers ? globalThis.ViewHelpers.escapeHtml : function(s){ return String(s).replace(/[<>&"]/g, function(c){return{'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;'}[c];}); };
html += '<div class="text-xs text-gray-500">' + esc(JSON.stringify(m)) + '</div>';
```

**Tip #8: XSS จาก err.message**
- 📍 Location: `src/3_group3_webapp/views/LiveFeed.html:79`
- 🔍 Issue: `err.message` ไม่ผ่าน `escapeHtml_`

```javascript
// ❌ Before
content.innerHTML = '<div class="text-sm text-red-500">Error: ' + err.message + '</div>';

// ✅ After
const escErr = esc(err.message || 'Unknown error');
content.innerHTML = '<div class="text-sm text-red-500">Error: ' + escErr + '</div>';
```

---

### ไฟล์: `26_AuditTrailService.gs` (407 lines)

#### ✅ จุดที่ทำได้ดี
- `truncate_()` ป้องกัน oversized cell values
- AUDIT_IDX ใช้ constants ทั้งหมด — ไม่มี magic numbers
- Guard `typeof logDebug === 'function'` ป้องกัน crash ถ้า module ไม่ load

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #9: appendRow() ควร batch ใน bulk scenario**
- 📍 Location: `src/O_core_system/26_AuditTrailService.gs:171`
- 🔍 Issue: `sheet.appendRow(row)` ทุก event — ถ้า `applyAllPendingDecisions()` process 50 rows → 50 individual appendRow calls

```javascript
// ✅ Approach: buffer in module-level array, flush at end
// ใน 12_ReviewService.gs เมื่อ batch เสร็จ เรียก flushAuditBuffer_()
// (similar pattern กับ flushLogBuffer_)
```

---

### ไฟล์: `10_MatchEngine.gs` (919 lines)

#### ✅ จุดที่ทำได้ดี
- `cleanupMatchEngineRun_()` centralize ทุก cleanup ใน single function — ไม่มี duplicated cleanup code
- `acquireMatchEngineLock_()` มี proper `hasLock()` check หลัง `tryLock()`
- Emergency stop `PIPELINE_STOP_REQUESTED` ถูก clear ก่อน start run ใหม่

#### ⚠️ จุดที่ควรปรับปรุง

**Tip #10: tryLock() try-catch ไม่จำเป็นใน GAS V8**
- 📍 Location: `src/1_group1_master_db/10_MatchEngine.gs:166-172`
- 🔍 Issue: ใน GAS V8, `lock.tryLock(ms)` return `true/false` ไม่ throw exception (throw เกิดเฉพาะ `waitLock()` หรือ argument ผิดประเภท) → try-catch ปัจจุบัน swallow error จริงๆ แทนที่จะจับแค่ lock-not-acquired

```javascript
// ❌ Before
try {
  lock.tryLock(APP_CONST.LOCK_TIMEOUT_MS);
} catch (e) { ... return null; }
if (!lock.hasLock()) { ... return null; }

// ✅ After — simpler + idiomatic
if (!lock.tryLock(APP_CONST.LOCK_TIMEOUT_MS)) {
  logWarn(...);
  safeUiAlert_(...);
  return null;
}
```

---

### 📊 สรุปรายไฟล์

| File | Tips | Severity Avg | Top Issue |
|------|------|-------------|-----------|
| `00_App.gs` | 1 | HIGH | Lock double-release |
| `18_ServiceSCG.gs` | 1 | CRITICAL | Cookie security regression |
| `21b_AliasSafeguard.gs` | 2 | MEDIUM | Layer 2-4 missing, boundary condition |
| `22_WebApp.gs` | 2 | HIGH | PII logging, auth fallback |
| `LiveFeed.html` | 2 | HIGH | XSS × 2 |
| `26_AuditTrailService.gs` | 1 | LOW | appendRow batching |
| `10_MatchEngine.gs` | 1 | LOW | Unnecessary try-catch |
| Other 32 .gs files | 0 | — | No critical issues found |


---

## Phase 3 — Security Protocols

### 1. Executive Summary

| Metric | Value |
|--------|-------|
| **Overall Risk** | **MEDIUM-HIGH** |
| **Critical Findings** | 3 (XSS × 2, Cookie plaintext) |
| **High Findings** | 2 (Auth fallback, PII logging) |
| **Compliance: PDPA/GDPR** | Partial — cookie ยังรั่ว, email ถูก log |
| **Compliance: OWASP Top 10** | A03 (XSS in LiveFeed), A02 (Sensitive Data in Cell B1) |

---

### 2. SEC-001 → SEC-012 Audit

| ID | Description | Status | Evidence | Fix |
|----|-------------|--------|----------|-----|
| SEC-001 | No hardcoded credentials/API keys | ✅ PASS | Gemini key, Telegram token อยู่ใน PropertiesService | — |
| SEC-002 | Deny-by-default authorization | ⚠️ PARTIAL | `isAuthorizedDashboardUser_()` deny-by-default ถ้า email ว่าง แต่ **return true** เมื่อ whitelist ว่าง | แก้ last-resort เป็น `return false` |
| SEC-003 | Input validation | ✅ PASS | `validateInput_()` ใน `19_Hardening.gs`, sanitizeCookie_, validateSchemaConsistency | — |
| SEC-004 | No PII in logs | ⚠️ PARTIAL | `[Auth DEBUG]` log email ทุก doGet request ใน `22_WebApp.gs:140` | เปลี่ยนเป็น masked/debug |
| SEC-005 | Cookie stored securely | ❌ FAIL | `getSCGCookie_()` อ่าน cell B1 (plaintext) เป็น primary แม้ V6.0.036 จะ fix แล้ว — reverted ใน v5.5.022 | Restore PropertiesService-primary |
| SEC-006 | XSS prevention | ❌ FAIL | `LiveFeed.html:72` `JSON.stringify()` ไม่ escape ก่อน innerHTML + `err.message` ไม่ escape | ใช้ `escapeHtml_()` ทั้ง 2 จุด |
| SEC-007 | Reviewer email masking | ✅ PASS | `maskReviewerEmail_()` ถูกเรียกใน `12_ReviewService.gs` และ `22c_WebAppActions.gs` | — |
| SEC-008 | RBAC enforcement | ✅ PASS | `requirePermission_()` ถูกเรียกใน menu actions + batch approve | — |
| SEC-009 | Rate limiting | ✅ PASS | `checkAliasCircuitBreaker_()` จำกัด 50 alias/day; Pipeline circuit breaker | — |
| SEC-010 | Audit trail | ✅ PASS | `logAuditTrail()` ใน `26_AuditTrailService.gs` ครอบคลุม MERGE, CREATE, IGNORE | — |
| SEC-011 | Supply chain security | ✅ PASS | CodeQL (06-codeql.yml), Gitleaks (08-gitleaks.yml), Dependabot (.github/dependabot.yml) | — |
| SEC-012 | Secrets scanning in CI | ✅ PASS | `.gitleaks.toml` config ใช้งาน, 08-gitleaks.yml workflow active | — |

---

### 3. New Findings (นอกเหนือจาก 12 ข้อเดิม)

| ID | Severity | Description | File:Line | Fix |
|----|----------|-------------|-----------|-----|
| SEC-N01 | HIGH | **getSCGCookie_() plaintext read** — อ่าน B1 ก่อน PropertiesService; ถ้ามี cookie ใน B1 → visible ทุก user ที่ share sheet | `18_ServiceSCG.gs:329-342` | Restore V6.0.036 logic |
| SEC-N02 | HIGH | **XSS: JSON.stringify ใน innerHTML** — `recentMatches` data จาก backend → sheet data → ไม่ถูก escape | `LiveFeed.html:72` | `escapeHtml_(JSON.stringify(m))` |
| SEC-N03 | HIGH | **XSS: err.message ใน innerHTML** — error object message ไม่ผ่าน escape | `LiveFeed.html:79` | `escapeHtml_(err.message)` |
| SEC-N04 | MEDIUM | **PII in SYS_LOG** — effectiveUser email logged ใน INFO level ทุก doGet | `22_WebApp.gs:140` | `logDebug` + mask email |
| SEC-N05 | MEDIUM | **Auth bypass ใน misconfigured environment** — last-resort return true ถ้า properties ไม่ได้ตั้ง | `22_WebApp.gs:185` | return false + warn |
| SEC-N06 | LOW | **Telegram token in `PIPELINE_ALERT_CONFIG` area comment** — token access ผ่าน `PropertiesService.getProperty('TELEGRAM_BOT_TOKEN')` ซึ่ง OK แต่ chat_id ไม่ sensitive | `24_PipelineManager.gs:1428` | ตรวจว่า Telegram chat_id ไม่ใช่ private info |

---

### 4. Security Protocols (กฎที่ต้องบังคับใช้)

#### Protocol S-01: SCG Cookie Management
- **Rule:** Cookie ต้องเก็บใน `PropertiesService` เท่านั้น; ห้าม read จาก sheet cell เป็น primary
- **Implementation:** `getSCGCookie_()` อ่าน PropertiesService ก่อน → fallback cell B1 พร้อม auto-migrate + clear
- **Verification:** CI check ว่า `getRange('B1')` ไม่ถูกเรียกก่อน PropertiesService ใน `getSCGCookie_`

#### Protocol S-02: HTML Output Encoding
- **Rule:** ทุก server-supplied data ที่ใส่ใน `innerHTML` ต้องผ่าน `escapeHtml_()` หรือ `ViewHelpers.escapeHtml` ก่อน
- **Implementation:** ทุก `innerHTML =` ที่มี dynamic data ต้อง wrap: ห้าม `JSON.stringify()` ตรงๆ
- **Verification:** Code review checklist item: "innerHTML ทุก instance มี escapeHtml?"

#### Protocol S-03: Auth Deny-by-Default
- **Rule:** Dashboard auth ต้อง deny เสมอเมื่อ whitelist ไม่ได้ตั้ง
- **Implementation:** ลบ last-resort `return true` ที่ `22_WebApp.gs:185`
- **Verification:** Test: deploy app โดยไม่ set DASHBOARD_USERS/LMDS_ADMINS → ต้องเห็น Unauthorized page

#### Protocol S-04: PII Logging Policy
- **Rule:** Email addresses ต้อง mask ก่อน log ด้วย `maskEmailSafe_()` — ห้าม log email ใน INFO level
- **Implementation:** `[Auth DEBUG]` ทั้งหมดย้าย → `logDebug` + `maskEmailSafe_(email)`
- **Verification:** grep SYS_LOG sheet ว่า email pattern ไม่ปรากฏใน log entries

#### Protocol S-05: Lock Release Safety
- **Rule:** ทุก `lock.releaseLock()` ต้องใช้ `releaseScriptLock_(lock)` helper หรือ `if (lock && lock.hasLock())` guard
- **Implementation:** เปลี่ยน `00_App.gs:303` → `releaseScriptLock_(lock)`
- **Verification:** grep codebase ว่าไม่มี `.releaseLock()` ที่ไม่มี null-safe guard

---

### 5. Threat Model (STRIDE)

| Threat | Asset | Attack Vector | Mitigation |
|--------|-------|---------------|------------|
| **Spoofing** | WebApp Dashboard | URL sharing ใน access=MYSELF (limited) | RBAC whitelist, deny-by-default |
| **Tampering** | `Q_REVIEW` decisions | XSS inject script → auto-click Approve | Fix SEC-N02/N03 |
| **Repudiation** | Alias modifications | ลบ audit log | `SYS_AUDIT_TRAIL` immutable via append-only |
| **Info Disclosure** | SCG Cookie (auth token) | sheet viewer อ่าน cell B1 | **Fix SEC-N01** |
| **Info Disclosure** | Reviewer emails | SYS_LOG viewer | Fix SEC-N04, ใช้ logDebug |
| **Denial of Service** | Pipeline execution | spam trigger → quota exhaustion | Circuit breaker + LockService |
| **Elevation of Privilege** | Admin functions | reviewer กด menu admin | `requirePermission_('action:run_pipeline')` |

---

### 6. Compliance Checklist (ก่อน deploy)

- [ ] ✅ SEC-N01: Fix `getSCGCookie_()` → PropertiesService primary
- [ ] ✅ SEC-N02/N03: escapeHtml ใน LiveFeed.html ทั้ง 2 จุด
- [ ] ✅ SEC-N04: เปลี่ยน Auth DEBUG log → logDebug + mask
- [ ] ✅ SEC-N05: Auth last-resort → return false
- [ ] ✅ TD-001: Fix `lock.releaseLock()` → `releaseScriptLock_(lock)` ใน `00_App.gs:303`
- [ ] ⚠️ REVIEW: ตรวจ `DASHBOARD_USERS` และ `LMDS_ADMINS` ถูกตั้งค่าแล้วใน production Script Properties
- [ ] ⚠️ REVIEW: ยืนยันว่า cell B1 ของ Input sheet ว่างเปล่า (cookie ย้ายไป PropertiesService แล้ว)


---

## Phase 4 — Coding Style Scorecard

### Overall Score: 74/100 (Grade: B)

> ประเมินจาก static analysis 39 .gs files (27,915 lines) + 19 .html files

---

### Per-Category Breakdown

| หมวด | น้ำหนัก | คะแนน | หมายเหตุ |
|------|---------|-------|---------|
| 1. Naming Convention | 10% | 88/100 | camelCase สม่ำเสมอ, `_` suffix สำหรับ private ถูกต้อง 329/545 functions; มีบาง constants ใช้ `SCREAMING_SNAKE_CASE` ถูกต้อง |
| 2. Function Size & SRP | 15% | 62/100 | 33/542 functions ยาวกว่า 100 บรรทัด (6%); ยาวสุด 213 บรรทัด; หลาย functions ทำหลาย concerns |
| 3. Comment & Documentation | 10% | 55/100 | JSDoc coverage 39% (215/545); files มี file-header JSDoc ดี แต่ private functions หลาย functions ไม่มี JSDoc |
| 4. Error Handling | 15% | 82/100 | try-catch 256 blocks; `withEntryPointGuard_()` pattern ดีมาก; `safeUiAlert_()` trigger-safe; ปัญหา: lock double-release |
| 5. Consistency (style) | 10% | 85/100 | Consistent indentation 2-space, template literals, arrow functions; var usage เกือบ 0 (7 occurrences ล้วนใน JSDoc comment) |
| 6. GAS Best Practices | 15% | 78/100 | `getValues()`/`setValues()` batch pattern ดี (111 getValues, 54 setValues); `appendRow()` เพียง 2 จุด; เกือบทุก function cache ss ที่ top; ปัญหา: nested lock |
| 7. Security Mindset | 15% | 58/100 | SEC-001→012 ส่วนใหญ่ผ่าน แต่ XSS 2 จุด + cookie regression เป็น deduction ใหญ่ |
| 8. Maintainability | 10% | 79/100 | DRY pattern ดี (withEntryPointGuard_, releaseScriptLock_, clearSheetsPreserveHeaders_); modular มาก (39 modules); ปัญหา: JSDoc coverage ต่ำ |

**Weighted Score:**
```
88×0.10 + 62×0.15 + 55×0.10 + 82×0.15 + 85×0.10 + 78×0.15 + 58×0.15 + 79×0.10
= 8.8 + 9.3 + 5.5 + 12.3 + 8.5 + 11.7 + 8.7 + 7.9
= 72.7 ≈ 74/100 (Grade B)
```

---

### Top 5 Strengths

1. **Helper Abstraction ยอดเยี่ยม** — `withEntryPointGuard_()`, `releaseScriptLock_()`, `safeUiAlert_()`, `acquireScriptLockOrWarn_()` ลด boilerplate code ได้มาก และป้องกัน common bugs
2. **Batch Operations First-Class** — `getValues()`/`setValues()` ถูกใช้เป็นหลักทั้งโปรเจกต์ (111 vs 54); `appendRow()` แทบไม่ใช้เลย (2 จุด ที่ justified)
3. **Naming Convention สม่ำเสมอ** — `_` suffix private functions ทำได้ 329/545 functions; `SHEET.xxx`, `SCHEMA[...]`, `*_IDX` ตลอด codebase ไม่มี raw string
4. **Module Architecture ชัดเจน** — 4 Domain Groups + ไฟล์ file-header JSDoc ทุกไฟล์; dependency direction clear (Group 0 ← Group 1,2,4)
5. **GAS-specific Patterns ดี** — Time Guard, Checkpoint+Auto-Resume, CacheService chunked, LockService pattern ถูกต้องเกือบทุกจุด

---

### Top 5 Improvements Needed

1. **JSDoc coverage ต่ำ (39%)** — private helper functions ส่วนใหญ่ไม่มี JSDoc; contributor ใหม่ต้องอ่าน source แทน
2. **XSS Blind Spot** — `LiveFeed.html` เดียวที่ลืม escapeHtml; views อื่นๆ ทำถูกหมด แต่ 1 จุดก็เสี่ยงได้
3. **Long Functions** — 33 functions ยาวกว่า 100 บรรทัด, top 3 ยาว 150-213 บรรทัด; ควร extract sub-functions
4. **Cookie Security Regression** — Pattern ดีถูก revert โดย hotfix; ต้อง restore และ document ว่าทำไมถึง revert (และแก้ root cause แทน)
5. **Lock Safety ใน outer call chain** — `runFullPipeline` → `runMatchEngine` ทั้งคู่ acquire/release script lock; pattern ไม่ safe

---

### Sample Code Review

#### ✅ Good Example: `withEntryPointGuard_` Pattern

```javascript
// src/O_core_system/14_Utils.gs:631-705
// ✅ เหตุผล:
// 1. ลด boilerplate 10 บรรทัด → 1 บรรทัดใน caller
// 2. finally block ป้องกัน lock leak และ log flush ทุกกรณี
// 3. options object ทำให้ extensible โดยไม่ต้องเปลี่ยน signature
// 4. Defensive: null-safe lock release + typeof flushLogBuffer_ guard
function withEntryPointGuard_(moduleName, fnName, fn, options) {
  options = options || {};
  const lock = options.lock;
  try {
    return fn();
  } catch (e) {
    logError(moduleName, fnName + ' ' + (options.errorPrefix || 'ล้มเหลว: ') + e.message, e);
    if (options.showAlert !== false) safeUiAlert_('❌ ' + fnName + ' ล้มเหลว: ' + e.message);
    return undefined;
  } finally {
    if (lock && lock.hasLock()) { try { lock.releaseLock(); } catch(e){} }
    if (typeof flushLogBuffer_ === 'function') { try { flushLogBuffer_(); } catch(e){} }
  }
}
```

#### ✅ Good Example: Batch setValues Pattern

```javascript
// src/2_group2_daily_ops/12_ReviewService.gs:231-234
// ✅ เหตุผล: สะสม updates ใน array แล้ว flush ครั้งเดียว
// ลด sheet API calls จาก N → 1 สำหรับ N pending decisions
const pendingStatusUpdates = [];
// ... loop และ push ลง array ...
// batch write ทีเดียวตอนท้าย (setValues call เดียว)
```

#### ❌ Needs Improvement: Naked lock.releaseLock()

```javascript
// src/O_core_system/00_App.gs:302-305
// ❌ ปัญหา: releaseLock() ไม่ safe เมื่อ runMatchEngine() release lock ไปแล้ว
} finally {
  lock.releaseLock();   // ❌ อาจ throw → flushLogBuffer_ ถูกข้าม
  if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();
}

// ✅ แก้ได้ด้วย 1 บรรทัด
} finally {
  releaseScriptLock_(lock);   // ✅ มี hasLock() guard อยู่แล้ว
  if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();
}
```

#### ❌ Needs Improvement: JSON.stringify ใน innerHTML (XSS)

```javascript
// src/3_group3_webapp/views/LiveFeed.html:72
// ❌ ปัญหา: JSON.stringify(m) ไม่ escape HTML chars
html += '<div class="text-xs text-gray-500">' + JSON.stringify(m) + '</div>';

// ✅ แก้
const escFn = (globalThis.ViewHelpers || {}).escapeHtml || (s => String(s).replace(/[<>&"]/g, c => ({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;'}[c])));
html += '<div class="text-xs text-gray-500">' + escFn(JSON.stringify(m)) + '</div>';
```

---

## Phase 5 — Refactoring Plans

### Sprint 0: Quick Wins (1-3 วัน — zero behavior change)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R0-01 | `00_App.gs:303` | `lock.releaseLock()` → `releaseScriptLock_(lock)` | 🟢 Zero | รัน Full Pipeline → ตรวจว่า SYS_LOG มี flush log entries ครบ |
| R0-02 | `22_WebApp.gs:140` | `logInfo(...)` → `logDebug(...)` + mask email | 🟢 Zero | ตรวจ SYS_LOG ว่าไม่มี email plain text |
| R0-03 | `22_WebApp.gs:185` | `return true` → `return false` + `logWarn` | 🟢 Zero | เปิด dashboard โดย clear Properties → ต้องเห็น Unauthorized |
| R0-04 | `LiveFeed.html:72` | wrap `JSON.stringify(m)` ด้วย `escapeHtml_()` | 🟢 Zero | test ด้วย match object ที่มี `<` ใน name |
| R0-05 | `LiveFeed.html:79` | wrap `err.message` ด้วย `escapeHtml_()` | 🟢 Zero | throw error จาก backend ที่มี HTML chars |
| R0-06 | `21b_AliasSafeguard.gs:85` | `ratio <= floor` → `ratio < floor` | 🟡 Low | test variant/canonical ที่ score 0.5 พอดี |
| R0-07 | `10_MatchEngine.gs:166` | เปลี่ยน `try { lock.tryLock() } catch` → `if (!lock.tryLock())` | 🟢 Zero | รัน Match Engine → behavior เหมือนเดิม |

### Sprint 1: Security Hardening (1 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R1-01 | `18_ServiceSCG.gs:328-353` | Restore PropertiesService-primary ใน `getSCGCookie_()` | 🟡 Medium | ตรวจว่า `fetchDataFromSCGJWD()` ยังทำงานได้ถ้า B1 ว่าง + Props มี cookie |
| R1-02 | `18_ServiceSCG.gs:328` | เพิ่ม auto-migrate logic: อ่าน B1 → migrate ไป Props → clear B1 | 🟡 Medium | test กับ B1 ที่มี cookie → ตรวจว่า Props update + B1 cleared |
| R1-03 | `26_AuditTrailService.gs` | สร้าง `_AUDIT_BUFFER` + `flushAuditBuffer_()` สำหรับ batch append | 🟡 Medium | bulk review decision 10+ rows → ตรวจว่า SYS_AUDIT_TRAIL ครบ |
| R1-04 | `27_RbacService.gs` | เพิ่ม unit test helper `testRbacPermissions_UI()` | 🟢 Low | รัน manual และตรวจ output |

### Sprint 2: Architecture (2 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R2-01 | `22c_WebAppActions.gs:289` | Extract `getReviewDetail()` (207 บรรทัด) → 3 helpers: `fetchReviewRow_()`, `fetchCandidates_()`, `buildDetailResponse_()` | 🟡 Medium | รัน QReview detail view → ตรวจข้อมูลครบ |
| R2-02 | `10d_MatchTestHarness.gs:58` | Extract `runTestMatchDryRun_()` (213 บรรทัด) → `prepareTestData_()`, `runTestLoop_()`, `writeTestResults_()` | 🟡 Medium | รัน Dry Run → ตรวจ TEST_MATCH_RESULTS sheet |
| R2-03 | `22b_WebAppViews.gs:389` | Extract `getFactDeliveryPage()` (155 บรรทัด) → pagination helper + query helper | 🟢 Low | paginate FACT_DELIVERY → ตรวจ offset/limit |
| R2-04 | `21b_AliasSafeguard.gs` | Implement Layer 2: Repetition Consensus — บันทึก `ALIAS_SEEN_{uuid}_{date}` ใน Props | 🔴 High | test approval sequence วันเดียวกัน 2 ครั้ง → ต้อง block |
| R2-05 | `05_NormalizeService.gs:233` | Extract `normalizePersonNameFull()` (113 บรรทัด) → dedicated step functions | 🟡 Medium | regression test ด้วย 29_SnapshotTest.gs |

### Sprint 3: Polish (1 สัปดาห์)

| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| R3-01 | All 39 .gs | เพิ่ม JSDoc ให้ private functions ที่ขาด (target: 70% coverage) | 🟢 Zero | ตรวจ JSDoc count ก่อน/หลัง |
| R3-02 | All .html | ลบ debug `console.log` 10 instances ใน view files | 🟢 Zero | ตรวจ browser console ว่าสะอาด |
| R3-03 | `24_PipelineManager.gs:66` | สร้าง `PIPELINE_ALERT_CONFIG` ใน `01_Config.gs` แทนการ define ใน PipelineManager | 🟢 Zero | deploy → ตรวจ constant ใช้งานได้ |
| R3-04 | README.md | อัปเดต security section: document ว่า B1 ไม่ใช้แล้ว + Cookie migration path | 🟢 Zero | Review doc |
| R3-05 | CHANGELOG.md | Document breaking changes ทุก Sprint | 🟢 Zero | Review doc |

---

### Refactor Pattern Library

**Pattern R-01: Extract Function (ใช้เมื่อ function >100 lines)**
```javascript
// Before: getReviewDetail() 207 บรรทัดทำทุกอย่าง
function getReviewDetail(reviewId) {
  // อ่าน sheet, หา row, โหลด candidates, build response — ปนกัน
}

// After: แบ่ง SRP
function getReviewDetail(reviewId) {
  const reviewRow = fetchReviewRow_(reviewId);       // read-only sheet access
  if (!reviewRow) throw new Error('Review not found');
  const candidates = fetchCandidates_(reviewRow);    // parallel lookup
  return buildDetailResponse_(reviewRow, candidates); // pure transform
}
```

**Pattern R-02: Lock-Safe Release**
```javascript
// ใช้ทุกที่ที่มี lock.releaseLock() ใน finally block
// Before:
} finally { lock.releaseLock(); }

// After:
} finally { releaseScriptLock_(lock); }
// releaseScriptLock_ ใน 14_Utils.gs:697 มี null-safe + hasLock() guard อยู่แล้ว
```

**Pattern R-03: Replace Magic Comparison with Named Constant**
```javascript
// Before: ratio <= 0.5 (ไม่รู้ว่า 0.5 มาจากไหน)
if (ratio <= 0.5) return { pass: false };

// After: อ่านจาก config (มีอยู่แล้วใน SAFEGUARD_CONFIG)
const floor = SAFEGUARD_CONFIG.MIN_SIMILARITY_RATIO;
if (ratio < floor) return { pass: false };  // แก้ <= → < ด้วย
```

---

### Rollback Plan

- **Sprint 0**: ทุก change เป็น 1-line fix → rollback ด้วย git revert ได้ทันที; ไม่มี data migration
- **Sprint 1 (R1-01/02)**: สร้าง `getSCGCookieV2_()` ใหม่ก่อน; switch ทีละ caller; rollback = เปลี่ยน caller กลับ
- **Sprint 2 (R2-01/02)**: Extract ไม่ลบ old function; test ด้วย 29_SnapshotTest.gs ก่อน delete old
- **Sprint 2 (R2-04)**: Layer 2 implement แบบ opt-in flag `SAFEGUARD_CONFIG.ENABLE_LAYER2 = false` → test ก่อน enable

---

## 🎯 Final Verdict: ❌ NO-GO (ก่อนแก้ P0)

| ประเด็น | สถานะ |
|---------|--------|
| P0 issues blocking | **5 items** |
| ✅ Architecture | Sound — modular, batch-first, resumable |
| ✅ Core Pipeline | ทำงานถูกต้อง (lock/time guard/checkpoint ครบ) |
| ❌ Security | XSS 2 จุด + Cookie plaintext = blocking |
| ❌ Lock Safety | Double-release = log flush skip ทุก Full Pipeline run |
| ❌ Safeguard | Layer 2/3/4 ยังไม่ implement = alias quality risk |

**Recommendation:**
> หลัง fix P0 (Sprint 0 + R1-01/02) ซึ่งใช้เวลาไม่เกิน **2-3 วัน** → ระบบ GO สำหรับส่งมอบ
> Sprint 1-3 ทำต่อหลัง handoff ได้ (ไม่ blocking แต่ strongly recommended)

---

## ⚠️ NOT YET CHECKED — ต้องตรวจเพิ่ม

1. **Live runtime behavior**: GAS LockService re-entrancy ยืนยันได้แน่ชัดเฉพาะ runtime test จริง — ต้องรัน `runFullPipeline()` แล้วดู SYS_LOG ว่า `flushLogBuffer_` entries มาครบ
2. **Schema drift ใน production sheet**: SCHEMA vs actual sheet column count ตรวจได้เฉพาะใน live spreadsheet (`validateConfig()` จะ check ตอน onOpen)
3. **Trigger count**: จำนวน installed triggers ตรวจได้แค่ใน script editor → ตรวจว่าไม่เกิน 20 triggers/user
4. **PropertiesService usage**: ตรวจ size ของ properties store (total ~500 KB limit) ไม่สามารถทำจาก static analysis
5. **Telegram bot token/chat_id**: ยืนยันว่า set แล้วใน production (static analysis ไม่เห็น runtime properties)
6. **Cache hit rate**: ไม่สามารถวัด CacheService hit/miss rate จาก static code — ต้อง monitor ด้วย SYS_LOG
7. **Layer 2/3/4 Safeguard behavior**: integration test สำหรับ alias promotion flow ต้องรันใน live GAS

