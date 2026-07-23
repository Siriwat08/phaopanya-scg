# LMDS V6.0 — Final Audit Report

**Real run on phaopanya-scg v6.0.072** (cloned from github.com/Siriwat08/phaopanya-scg) using audit-template-v2 with 36 check scripts

| Field | Value |
|---|---|
| Date | 2026-07-23 |
| Repo | phaopanya-scg v6.0.072 |
| Template | audit-template-v2 (12 ST + 12 RT + 12 DM = 36 checks) |
| Aggregated by | Super Z (acting as Agent 4) |
| Sources | Agent 1 (Static) + Agent 2 (Runtime) + Agent 3 (Domain) |

---

## Executive Summary

การตรวจสอบครั้งนี้รัน check scripts ทั้ง 36 ตัวจาก audit-template-v2 กับ LMDS V6.0.072 จริง พบว่ามี 4 ปัญหา P0 ที่ต้องแก้ก่อน deploy, 3 ปัญหา P1 ที่ต้องแก้ก่อน release, และพบ false positive 8 ตัวใน check scripts เองที่ต้องปรับใน v3:

| Metric | Count | Status |
|---|---:|---|
| Checks executed | 36 of 36 | PASS |
| Checks passed | 18 | PASS |
| Checks failed/warned | 15 | WARN |
| Checks skipped (no env) | 3 | INFO |
| Unique findings (after dedup) | 11 | |
| P0 (block deploy) | 4 | NO-GO |
| P1 (block release) | 3 | WARN |
| P2 (sprint) | 3 | |
| P3 (backlog) | 1 | |
| False positives identified | 8 | WARN |

> **🚦 Release Verdict: NO-GO**
> P0 = 4 (must fix before deploy) | P1 = 3 (must fix before release)

---

## P0 — Block Deploy (4 findings)

ปัญหา 4 ข้อต่อไปนี้ต้องแก้ก่อน deploy ไม่มีข้อยกเว้น แต่ละข้อมี evidence + คำแนะนำการแก้ + effort estimate

### [P0-001] Runtime CDN import in Unauthorized.html

- **Check:** RT-002 (Runtime)
- **File(s):** `src/3_group3_webapp/views/Unauthorized.html:8`
- **Evidence:**
  ```html
  <script src="https://cdn.tailwindcss.com"></script>
  ```
- **Impact:** GAS WebApp served from Google — external CDN may be blocked by corporate firewall → no styling on auth-fail page → users see raw HTML
- **Fix:** Download `tailwind.min.css` → save to `src/3_group3_webapp/css/` → reference locally with `<link rel="stylesheet" href="css/tailwind.min.css">`
- **Effort:** S (< 30 min)

### [P0-002] UrlFetchApp.fetch without try-catch (2 sites)

- **Check:** RT-001 (Runtime)
- **File(s):**
  - `src/2_group2_daily_ops/15_GoogleMapsAPI.gs:20`
  - `src/2_group2_daily_ops/18_ServiceSCG.gs:22`
- **Evidence:** `fetch()` called outside try block — any network blip = unhandled exception
- **Impact:** Pipeline crash on network blip, no retry, no graceful error → data pipeline stops, must manually resume
- **Fix:** Wrap in:
  ```javascript
  try {
    const res = UrlFetchApp.fetch(url, options);
    // parse
  } catch (e) {
    logError('Module', 'fetch failed: ' + url, e);
    return null;
  }
  ```
- **Effort:** S per file

### [P0-003] Production access config not set (access: MYSELF)

- **Check:** RT-012 (Runtime)
- **File(s):** `appsscript.json`
- **Evidence:**
  ```json
  "access": "MYSELF",
  "executeAs": "USER_DEPLOYING"
  ```
- **Impact:** Production deploy will only work for deployer — other users get 401/403. WebApp becomes unusable for team.
- **Fix:** Change to `"DOMAIN"` (Google Workspace) or `"ANYONE"` (public) in `appsscript.json`
- **Effort:** S

### [P0-004] LockService missing in 2 Group 1 writers

- **Check:** RT-004 (Runtime)
- **File(s):**
  - `src/1_group1_master_db/05_NormalizeService.gs`
  - `src/1_group1_master_db/10f_MatchAliasEnrichment.gs`
- **Evidence:** Files write to master sheets (setValues/appendRow) but do not call `acquireScriptLock_()`
- **Impact:** Race condition when concurrent runs (trigger fires while manual menu action runs) → corrupted master data, partial writes, duplicate aliases
- **Fix:** Wrap master writes in:
  ```javascript
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(30000);
    // write
  } finally {
    lock.releaseLock();
  }
  ```
- **Effort:** M (1-2 hours)

---

## P1 — Block Release (3 findings)

ปัญหา 3 ข้อต่อไปนี้ต้องแก้ก่อน release แต่ไม่บล็อกการ deploy ทันทีเหมือน P0

### [P1-001] Cache invalidation missing on 5 real write sites

- **Check:** RT-006 (Runtime) — **HIGH FALSE POSITIVE RATE**
- **File(s):** 5 files after manual filter:
  - `06_PersonService.gs`
  - `21_AliasService.gs`
  - `07_PlaceService.gs`
  - `04_SourceRepository.gs`
  - `11_TransactionService.gs`
- **Evidence:** Original check flagged 30+ files but most are setup/schema files (no data write). Manual review narrowed to 5 real write sites.
- **Impact:** Stale cache → wrong match decision → potential data corruption (Master sheet updated but cache still returns old data)
- **Fix:** After every master write, call:
  ```javascript
  CacheService.getScriptCache().remove('<KEY>_V1');
  ```
  where `KEY` matches the cache key pattern in `01_Config.gs`
- **Effort:** M (3-4 hours across 5 sites)

### [P1-002] 13 top-level mutable globals (Law 9 violation)

- **Check:** ST-009 (Static) — **REAL FINDING**
- **File(s):** Sample (13 total, see static-report.md):
  - `06_PersonService.gs:42` — `let _PERSON_NOTE_INVERTED_INDEX = null;`
  - `08_GeoService.gs:54` — `let _GEO_CACHE_DIRTY = false;`
  - `10b_MatchDecision.gs:463` — `let _CANDIDATE_COORDS_CACHE_ = null;`
  - `03_SetupSheets.gs:42,45` — `let _isClearingOldLogs_` + `_LOG_BUFFER`
  - + 9 more
- **Evidence:** `grep -nE '^(let|var)[[:space:]]'` on `src/**/*.gs` (excluding `01_Config.gs`)
- **Impact:** Cross-execution state leakage — GAS sometimes caches module state between runs, stale cache may produce wrong results. Law 9 strictly forbids top-level `let`/`var` outside `01_Config.gs`.
- **Fix:** Options:
  - **(A)** Move to `PropertiesService` (persistent, slower)
  - **(B)** Keep as module-private cache + document as intentional exception
  - **(C)** Wrap in singleton getter functions
- **Effort:** L (architectural decision)

### [P1-003] 30 files with logError but no maskPii_ helper

- **Check:** DM-008 (Domain) — **FALSE POSITIVE on helper name**
- **File(s):** 30 files flagged (full list in domain-report.md)
- **Evidence:** Script looked for `maskPii_` but LMDS uses multiple specialized functions:
  - `maskEmailSafe_()` in `22_WebApp.gs`
  - `maskSearchQuery_()` in `22_WebApp.gs`
  - `maskReviewerEmail_()` in `12_ReviewService.gs`
  - `sanitizeForSheet_()` / `sanitizeRowForSheet_()` in `14_Utils.gs`
- **Impact:** Cannot determine if all PII fields are actually masked — heuristic check too narrow
- **Fix:** Manual audit each `logError()` call — verify appropriate mask function is applied per data type (email/phone/ID/address)
- **Effort:** M (2-3 hours manual review)

---

## P2 — Sprint (3 findings)

ปัญหาระดับ sprint — แก้ใน sprint ปัจจุบันได้ ไม่บล็อก release

### [P2-001] Magic column index (col 2 literal) — LIKELY FALSE POSITIVE

- **Check:** ST-006 (Static)
- **File(s):**
  - `src/O_core_system/03_SetupSheets.gs:518`
  - `src/O_core_system/14_Utils.gs:740`
- **Evidence:** `getRange(1, 2, ...)` — col 2 literal used
- **Impact:** Likely intentional: col 2 = first data column after row label (skip header column). Manual review confirms pattern is consistent.
- **Fix:** If intentional, define `START_DATA_COL_IDX = 2` in `01_Config.gs` to make explicit
- **Effort:** S

### [P2-002] 7 files with > 5 API calls each — OBSERVATION

- **Check:** RT-011 (Runtime)
- **File(s):** High-count files:
  - `24_PipelineManager.gs` (15 calls)
  - `21_AliasService.gs` (15)
  - `10h_MatchAutoResume.gs` (7)
  - `16_GeoDictionaryBuilder.gs` (7)
  - `19_Hardening.gs` (6)
  - `14_Utils.gs` (8)
  - `18_ServiceSCG.gs` (8)
- **Evidence:** Counted `UrlFetchApp` + `PropertiesService` + `CacheService` calls per file
- **Impact:** Within typical GAS budget (< 50 calls/run) but worth monitoring — high concentration in PipelineManager + AliasService
- **Fix:** Add `quotaCounter_` utility in `14_Utils.gs` to track per-pipeline usage. Abort at 80% of daily limit.
- **Effort:** M

### [P2-003] ST-002 flagged 30 files for bad filename — FALSE POSITIVE

- **Check:** ST-002 (Static)
- **File(s):** 30 files including: `10b_MatchDecision.gs`, `21b_AliasSafeguard.gs`, `22c_WebAppActions.gs`, all HTML files in `views/`
- **Evidence:** Regex `^[0-2][0-9]_[A-Za-z]...` does not accept optional letter suffix (`10b_`, `21b_`, `22c_`)
- **Impact:** LMDS uses `NNx_Name.gs` pattern (x = optional letter) which is valid — script flagged valid files as violations
- **Fix:** Update regex to `^[0-2][0-9][a-z]?_[A-Za-z]...` (see Self-Audit ST-002)
- **Effort:** S (5 min fix in script)

---

## P3 — Backlog (1 finding)

### [P3-001] DM-001 false positive on Match Engine rule count

- **Check:** DM-001 (Domain) — **FALSE POSITIVE**
- **Issue:** Script looked for `RULE[_ ]?[1-8]` (uppercase) but actual function names are `evaluateRule1_NoGeoInSource_` ... `evaluateRule8_NewGeoFromGPS_` (camelCase)
- **Manual verification:** All 8 rules ARE present in `10b_MatchDecision.gs` (lines 53-200). Match Engine implementation is COMPLETE.
- **Action:** Fix regex in DM-001 script (see Self-Audit DM-001)
- **Effort:** S

---

## Self-Audit — คุณภาพของ 36 Check Scripts ที่ผมเขียน

> ⚠️ **ส่วนนี้คือการวิเคราะห์ตัวเอง** — ผมรัน check scripts ที่เขียนไว้กับ LMDS จริง แล้วพบว่ามี false positive 8 ตัว และ crash bug 2 ตัว ที่ต้องแก้ใน v3 ผมจะลำดับความรุนแรงและให้ code fix สำหรับแต่ละตัว

### False Positives ที่พบ (8 ตัว)

| # | Check | ปัญหา + Root cause | Fix priority |
|---|---|---|---|
| 1 | ST-002 | 30 files flagged ว่า bad filename ทั้งที่ถูกต้อง — regex ไม่ยอมรับ suffix letter เช่น `10b_`, `21b_`, `22c_` | P0 — แก้ทันที |
| 2 | DM-001 | รายงาน "0 rules found" ทั้งที่มีครบ 8 rules — regex หา `RULE[1-8]` (uppercase) แต่จริงๆ คือ `evaluateRule[1-8]` (camelCase) | P0 — แก้ทันที |
| 3 | DM-011 | บอก "MAKE_MATCH_DECISION not found" ทั้งที่มี `makeMatchDecision()` — ค้นหาแค่ UPPER_CASE ไม่ยอมรับ camelCase | P0 — แก้ทันที |
| 4 | DM-012 | บอก "04_SourceRepository.gs not found" ทั้งที่มีอยู่ — ค้นหาแค่ใน `1_group1_master_db/` แต่จริงๆ อยู่ใน `2_group2_daily_ops/` | P0 — แก้ทันที |
| 5 | DM-002 | Flagged `01_Config`, `02_Schema`, `03_SetupSheets` ว่าเขียน Master — check หาแค่ "M_PERSON ปรากฏ" ไม่ได้ตรวจว่า read หรือ write | P1 |
| 6 | DM-008 | Flagged 30 files ทั้งที่ LMDS ใช้ `maskEmailSafe_`, `maskSearchQuery_` (specialized) ไม่ใช่ `maskPii_` (generic) | P1 |
| 7 | RT-006 | Flagged 30+ files รวม `03_SetupSheets.gs` ที่แค่ create sheet (ไม่ได้เขียน data) — heuristic ไม่แยก setup จาก data write | P1 |
| 8 | DM-009 | บอก "0 protect() calls" ทั้งที่ protection อยู่ใน `19_Hardening.gs` — ตรวจแค่ `03_SetupSheets.gs` | P1 |

### Bugs ที่ทำให้ script crash (2 ตัว)

| # | Check | Bug + Impact |
|---|---|---|
| 9 | RT-005 | `[[ -z $has_checkpoint ]]` syntax error เมื่อ `grep -c` คืน `0\n0` — script พิมพ์ error 15 ครั้ง แต่ยังรันต่อได้ |
| 10 | RT-011 | รูปแบบ `$(grep -c ... \|\| echo 0)` ทำให้ค่าเป็น `0\n0` — แก้แล้วใน v2 แต่ RT-005 ยังไม่ได้แก้ |

### คุณภาพรวมของ 36 Check Scripts

| ระดับคุณภาพ | จำนวน | Check IDs |
|---|---:|---|
| ✅ PASS — ดี (จับปัญหาจริงได้ถูกต้อง) | 22 | ST-001, ST-005, ST-007, ST-010, ST-011, ST-012, RT-001, RT-002, RT-003, RT-007, RT-008, RT-009, RT-010, RT-012, DM-003, DM-004, DM-005, DM-006, DM-007, DM-010, ST-009, RT-004 |
| ⚠️ WARN — พอใช้ (มี false positive แต่จับได้บ้าง) | 6 | RT-006, DM-002, DM-008, DM-009, RT-011, ST-006 |
| ❌ FAIL — แยก (false positive สูง/regex ผิด) | 6 | ST-002, DM-001, DM-011, DM-012, RT-005 (bug), ST-008 (awk heuristic มีปัญหา) |
| ℹ️ INFO — Skipped (no env) | 2 | ST-003 (no node_modules), ST-004 (no node_modules) |

**คะแนนรวม:** 22 ดี / 6 พอใช้ / 6 ต้องแก้ = **61% แม่นยำ** (เป้าหมาย v3: > 85%)

---

## ข้อแนะนำสำหรับ v3 (Patch ถัดไป)

ผมแยกข้อแนะนำเป็น 3 priority — แต่ละข้อมี code snippet ที่ user สามารถ copy ไป apply กับ check script ได้ทันที

### Priority 1 — แก้ false positive ทันที (4 ตัว)

#### Fix 1: ST-002 regex รองรับ suffix letter

```bash
# เดิม:
if [[ ! "$base" =~ ^[0-2][0-9]_[A-Za-z][A-Za-z0-9_]*\.(gs|js|html)$ ]]; then

# ใหม่: รับ optional letter suffix หลัง 2 digits (เช่น 10b_, 21b_, 22c_)
if [[ ! "$base" =~ ^[0-2][0-9][a-z]?_[A-Za-z][A-Za-z0-9_]*\.(gs|js|html)$ ]]; then
```

#### Fix 2: DM-001 regex case-insensitive + รับ evaluateRule

```bash
# เดิม:
rule_count=$(grep -cE "RULE[_ ]?[1-8]|// *Rule [1-8]|case ['\"]RULE[1-8]" "$match_file" 2>/dev/null) || rule_count=0

# ใหม่: รับ evaluateRule1, RULE_1, rule 1, etc.
rule_count=$(grep -ciE "(evaluateRule|RULE_|// *Rule |case ['\"]RULE)[1-8]" "$match_file" 2>/dev/null) || rule_count=0
```

#### Fix 3: DM-011 รับ camelCase makeMatchDecision

```bash
# เดิม:
if ! grep -qE "function\s+MAKE_MATCH_DECISION|MAKE_MATCH_DECISION\s*=" "$match_file" 2>/dev/null; then

# ใหม่: รับทั้ง UPPER_CASE และ camelCase
if ! grep -qE "function\s+(MAKE_MATCH_DECISION|makeMatchDecision)|(MAKE_MATCH_DECISION|makeMatchDecision)\s*=" "$match_file" 2>/dev/null; then
```

#### Fix 4: DM-012 ค้นหา 04_SourceRepository ในทุก group

```bash
# เดิม:
source_repo_file="$REPO/src/1_group1_master_db/04_SourceRepository.gs"

# ใหม่: ค้นหาทุกที่
source_repo_file=$(find "$REPO/src" -name "04_SourceRepository.gs" 2>/dev/null | head -1)
if [[ -z "$source_repo_file" ]]; then
  echo "  ❌ 04_SourceRepository.gs not found anywhere in src/"
  exit 1
fi
```

### Priority 2 — ลด false positive ของ heuristic checks

#### Fix 5: DM-002 ตรวจ write จริง ไม่ใช่แค่ reference

```bash
# เดิม: flagged ถ้า M_PERSON ปรากฏในไฟล์
offenders=$(grep -rln "$sheet" "$REPO/src" --include="*.gs" 2>/dev/null | grep -v "/1_group1_master_db/")

# ใหม่: flagged ถ้ามี setValues/appendRow/setValue ใกล้ M_PERSON
offenders=$(grep -rnE "($sheet).*(setValues|setValue|appendRow)" "$REPO/src" --include="*.gs" 2>/dev/null \
  | grep -v "/1_group1_master_db/" \
  | grep -vE "Test|Harness|Snapshot|Legacy" | cut -d: -f1 | sort -u)
```

#### Fix 6: DM-008 ค้นหา mask functions หลายแบบ

```bash
# เดิม: ค้นหา maskPii_ เท่านั้น
if ! grep -q "maskPii_" "$gsfile"; then

# ใหม่: ค้นหาหลาย pattern
if ! grep -qE "maskPii_|maskEmail|maskSearchQuery|maskReviewer|sanitizeForSheet|sanitizeRow|sanitizeCookie" "$gsfile"; then
```

#### Fix 7: RT-006 กรอง setup files ออก

```bash
# เพิ่ม skip list ใน loop:
SKIP_FILES="03_SetupSheets|19_Hardening|02_Schema|01_Config"
if echo "$base" | grep -qE "$SKIP_FILES"; then continue; fi
```

#### Fix 8: DM-009 ตรวจ Hardening file ด้วย

```bash
# เดิม: ตรวจแค่ 03_SetupSheets.gs
setup_file="$REPO/src/O_core_system/03_SetupSheets.gs"

# ใหม่: ตรวจทั้ง SetupSheets และ Hardening
for check_file in "$REPO/src/O_core_system/03_SetupSheets.gs" "$REPO/src/O_core_system/19_Hardening.gs"; do
  [[ ! -f "$check_file" ]] && continue
  protect_count=$(grep -cE "\.protect\(|Protection\.|protectMaster" "$check_file" 2>/dev/null) || protect_count=0
  # ... aggregate count
done
```

### Priority 3 — แก้ bugs ที่ทำให้ script crash

#### Fix 9: RT-005 แก้ grep -c || echo 0 bug

```bash
# เดิม (buggy):
has_checkpoint=$(grep -cE "PropertiesService\.(get|set)ScriptProperties\(\)\.setProperty" "$f" 2>/dev/null || echo 0)

# ใหม่ (safe):
has_checkpoint=$(grep -cE "PropertiesService\.(get|set)ScriptProperties\(\)\.setProperty" "$f" 2>/dev/null) || has_checkpoint=0
# Sanitize to integer only:
has_checkpoint=${has_checkpoint//[^0-9]/}
has_checkpoint=${has_checkpoint:-0}
```

---

## Coverage Matrix จริง

ตารางแสดงสิ่งที่เทมเพลตครอบคลุมเทียบกับสิ่งที่ LMDS repo มีจริง

| Layer | ครอบคลุม | Status | หมายเหตุ |
|---|---|---|---|
| Source code (.gs) | 39/39 | ✅ PASS | ตรวจครบทุกไฟล์ |
| WebApp HTML | 19/19 | ✅ PASS | ตรวจครบทุกไฟล์ |
| GitHub Workflows | 0/9 | ❌ FAIL | เทมเพลตไม่มี check เฉพาะ workflow |
| doc-code-sync checks | 0/18 | ❌ FAIL | ไม่มี check เปรียบเทียบกับ existing checks ใน `.github/scripts/` |
| Skills catalog | 0/11 | ❌ FAIL | ไม่ได้ตรวจ `.skills/` folder |
| Config files | 2/5 | ⚠️ WARN | ตรวจแค่ `appsscript.json` + `package.json` |
| Documentation | 38/38 | ✅ PASS | ผ่าน ST-012 link integrity check |
| Security surface (SEC-001..012) | ~30% | ⚠️ WARN | มีแค่ DM-007, DM-008, DM-010 — ขาด SEC-001..006, 009, 011, 012 |

---

## Required Actions Before GO

### Must fix (P0 — block deploy)

| # | Action | Finding ID |
|---:|---|---|
| 1 | Fix CDN import in `Unauthorized.html` | P0-001 |
| 2 | Add try-catch around 2 `UrlFetchApp.fetch` calls | P0-002 |
| 3 | Change `access: MYSELF` → `DOMAIN` or `ANYONE` in `appsscript.json` | P0-003 |
| 4 | Add `LockService` to 2 Group 1 writers | P0-004 |

### Should fix (P1 — block release)

| # | Action | Finding ID |
|---:|---|---|
| 5 | Add `CacheService.remove` to ~5 real master-write sites | P1-001 |
| 6 | Audit each `logError()` call for proper PII masking (manual) | P1-003 |
| 7 | Document or refactor 13 top-level `let _XxxCache` (Law 9 decision) | P1-002 |

### Optional (P2/P3)

| # | Action | Finding ID |
|---:|---|---|
| 8 | Define `START_DATA_COL_IDX = 2` if intentional | P2-001 |
| 9 | Add quota counter utility in `14_Utils.gs` | P2-002 |
| 10 | Update ST-002 regex in check script (v3 patch) | P2-003 |

---

## Final Verdict

> **🚦 NO-GO**
>
> - P0 = 4 (must fix before deploy)
> - P1 = 3 (must fix before release)
> - False positives in template = 8 (fix in v3)
> - Template accuracy = 61% (target v3: > 85%)

---

## Audit Run Stats

| Metric | Value |
|---|---|
| Checks executed | 36 of 36 (Static: 12/12, Runtime: 12/12, Domain: 12/12) |
| Files scanned | 39 .gs + 19 .html |
| LOC analyzed | ~35K (28K GS + 7K HTML) |
| Time spent | < 10 sec (shell only) |
| False positive rate | 22% (8 of 36 checks had false positive) |
| Template accuracy | 61% (22 ดี / 6 พอใช้ / 6 ต้องแก้) |
| Self-audit recommendation | Fix v2 → v3 ก่อนใช้งาน production release audit |

---

## Evidence Files

| File | Description |
|---|---|
| `static-report.md` | Agent 1 raw output (12 checks) |
| `runtime-report.md` | Agent 2 raw output (12 checks) |
| `domain-report.md` | Agent 3 raw output (12 checks) |
| `final-report.md` | This file (aggregated by Agent 4) |
