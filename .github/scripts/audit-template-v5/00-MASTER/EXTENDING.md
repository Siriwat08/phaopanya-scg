<!-- DOC-TYPE: living -->

# วิธีเพิ่ม Check ใหม่เข้าเทมเพลต (EXTENDING)

> ไฟล์นี้คือ **single source of truth** สำหรับการขยายเทมเพลต
> ห้ามเขียน check ใหม่ลงใน Agent โดยตรง — ต้องผ่านไฟล์นี้เสมอ

---

## 🎯 เหตุผลที่ต้องมีไฟล์นี้

คุณบอกว่า:
> "อยากให้มีระบบตรวจสอบเพิ่มได้ด้วยในสิ่งที่ไม่มีในเทมเพลต และแจ้งผู้ใช้ด้วยว่า ให้นำข้อมูลนี้แบบนี้ไปเพิ่มในเทมเพลตด้วย"

สิ่งที่เราทำ:
1. Agent เมื่อเจอ "สิ่งที่ควรตรวจแต่ไม่มีในเทมเพลต" → **ห้ามคิดเอง** → ต้องบันทึกเป็น **Template Gap**
2. Template Gap จะถูกรวมในรายงาน → คุณเอาไปเพิ่มในไฟล์นี้เอง
3. เทมเพลตจะใหญ่ขึ้นเรื่อยๆ ตามที่คุณอนุมัติ — **ไม่ใช่ตามที่ Agent คิด**

---

## 📋 รูปแบบการบันทึก Template Gap

ทุกครั้งที่ Agent เจอ gap, ให้บันทึกในรายงานด้วย format นี้:

```markdown
### [GAP-XXX] <ชื่อสั้นๆ>

- **Reported by:** Agent 1 / 2 / 3
- **Severity:** P0/P1/P2/P3
- **Where seen:** <path:line> หรือ <artifact>
- **What was found:** <อธิบายสั้นๆ ว่าเจออะไร>
- **Why it should be in template:** <เหตุผลที่ควรเป็น check ถาวร>
- **Proposed check:**
  ```yaml
  id: GAP-XXX
  agent: static|runtime|domain
  severity: P0|P1|P2|P3
  target: <regex or path pattern>
  rule: <สิ่งที่ต้องการตรวจ>
  fix_if_fail: <แนวทางแก้>
  ```
- **User action required:** ☑️ Copy this YAML block to `EXTENDING.md#pending-checks` for review
```

---

## ⏳ Pending Checks (รอคุณอนุมัติ)

> **คุณต้องย้าย check จาก report มาวางที่นี่ แล้วตัดสินใจ: APPROVE / REJECT / DEFER**
> เมื่อ approve แล้ว ให้ย้ายลง "Active Checks" ด้านล่าง

<!--
ใส่ check ใหม่ที่นี่ — format ด้านบน
-->

---

## ✅ Active Checks (ที่กำลังใช้งาน)

> ตัวนี้คือ check ที่ Agent ทุกตัวเรียกใช้ — **แก้ได้ที่นี่ที่เดียว ไม่ต้องไล่แก้ทุก Agent**
> ถ้าจะปิด check ชั่วคราว ให้ใส่ `disabled: true` แทนการลบ

### Group: STATIC (Agent 1)
```yaml
- id: ST-001
  name: "GS file header present (VERSION, FILE, PURPOSE, CHANGELOG, DEPENDENCIES)"
  agent: static
  severity: P1
  target: "src/**/*.gs"
  rule: "Every .gs file must start with /** block containing all 5 fields"
  fix_if_fail: "Add header block following template in 99_Legacy.gs"

- id: ST-002
  name: "Load order prefix (00-29)"
  agent: static
  severity: P2
  target: "src/**/*.gs"
  rule: "Filename must match /^[0-2][0-9]_[A-Z][a-zA-Z0-9]+\\.gs$/"
  fix_if_fail: "Rename file to NN_Name.gs"

- id: ST-003
  name: "ESLint passes with 0 errors"
  agent: static
  severity: P1
  target: "src/**/*.{gs,js,html}"
  rule: "npx eslint src/ --ext .gs,.js,.html must return 0"
  fix_if_fail: "Run npm run lint:fix"

- id: ST-004
  name: "Prettier formatting"
  agent: static
  severity: P3
  target: "src/**/*.{gs,js,html,css}"
  rule: "npx prettier --check must pass"
  fix_if_fail: "Run npm run format"

- id: ST-005
  name: "No var keyword (Law 1)"
  agent: static
  severity: P2
  target: "src/**/*.gs"
  rule: "Use const/let only"
  fix_if_fail: "Replace var with const/let"

- id: ST-006
  name: "No magic numbers as column index (Law 3)"
  agent: static
  severity: P1
  target: "src/**/*.gs"
  rule: "getRange(row, N) where N is literal > 0 is forbidden — use *_IDX from 01_Config.gs"
  fix_if_fail: "Define column index constant in 01_Config.gs"

- id: ST-007
  name: "Function name unique (Law 8)"
  agent: static
  severity: P1
  target: "src/**/*.gs"
  rule: "No two files can define the same exported function name"
  fix_if_fail: "Apply namespace pattern: PersonService.foo()"

- id: ST-008
  name: "No function > 100 lines (Law 2)"
  agent: static
  severity: P2
  target: "src/**/*.gs"
  rule: "Cyclomatic complexity ≤ 30, function ≤ 100 lines"
  fix_if_fail: "Use lmds-refactor-advisor to plan split"

- id: ST-009
  name: "No cross-file global vars (Law 9)"
  agent: static
  severity: P1
  target: "src/**/*.gs"
  rule: "Top-level non-CONFIG vars are forbidden except in 01_Config.gs"
  fix_if_fail: "Pass data via parameters or use CacheService"

- id: ST-010
  name: "HTML files separate (Law 11)"
  agent: static
  severity: P1
  target: "src/**/*.gs"
  rule: "No HTML string literals > 50 chars inside .gs files"
  fix_if_fail: "Extract to .html file and use createHtmlOutputFromFile"

- id: ST-011
  name: "Full file output (Law 15)"
  agent: static
  severity: P0
  target: "src/**/*.gs"
  rule: "No '// existing code' or '...' in any committed file"
  fix_if_fail: "Replace ellipsis with full source"

- id: ST-012
  name: "Internal link integrity in docs"
  agent: static
  severity: P3
  target: "docs/**/*.md"
  rule: "All relative .md links must resolve to existing files"
  fix_if_fail: "Fix path or create missing doc"
```

### Group: RUNTIME-GAS (Agent 2)
```yaml
- id: RT-001
  name: "UrlFetchApp.fetch in try-catch (Law 16, Check 14)"
  agent: runtime
  severity: P0
  target: "src/**/*.gs"
  rule: "Every UrlFetchApp.fetch() must be inside try block"
  fix_if_fail: "Wrap fetch + parse in try/catch and call logError()"

- id: RT-002
  name: "No runtime CDN imports (Check 13)"
  agent: runtime
  severity: P0
  target: "src/**/*.{html,js}"
  rule: "No <script src='https://cdn.*'> or @import from http"
  fix_if_fail: "Bundle locally or use Apps Script library"

- id: RT-003
  name: "Batch operations only (Law 4)"
  agent: runtime
  severity: P1
  target: "src/**/*.gs"
  rule: "getValue/setValue in loop > 3 iterations is forbidden — use getValues/setValues"
  fix_if_fail: "Refactor to batch read/write"

- id: RT-004
  name: "LockService for shared writes (Law 16)"
  agent: runtime
  severity: P0
  target: "src/**/*.gs"
  rule: "Functions writing to master sheet must call acquireScriptLock_()"
  fix_if_fail: "Wrap write in try/finally with LockService"

- id: RT-005
  name: "Checkpoint for long pipelines (Law 5)"
  agent: runtime
  severity: P1
  target: "src/**/*.gs"
  rule: "Pipelines expected > 2 min must write checkpoint to PropertiesService"
  fix_if_fail: "Add checkpoint save + resume logic"

- id: RT-006
  name: "Cache invalidation chain (Law 20)"
  agent: runtime
  severity: P0
  target: "src/**/*.gs"
  rule: "Every write to master sheet must call matching CacheService.remove"
  fix_if_fail: "Add invalidator call after write"

- id: RT-007
  name: "Trigger cleanup (Law 19)"
  agent: runtime
  severity: P1
  target: "src/**/*.gs"
  rule: "Deleted triggers must use ScriptApp.deleteTrigger"
  fix_if_fail: "Add cleanup function and run before delete"

- id: RT-008
  name: "Library version locked (Law 10)"
  agent: runtime
  severity: P1
  target: "src/**/*.gs"
  rule: "Advanced services must specify version, never HEAD/dev"
  fix_if_fail: "Pin version in library reference"

- id: RT-009
  name: "Time budget under 6 min (Law 2 GAS)"
  agent: runtime
  severity: P1
  target: "src/**/*.gs"
  rule: "No function should call Date.now() gap > 4 min without checkpoint"
  fix_if_fail: "Split into stages with checkpoint"

- id: RT-010
  name: "Quota awareness (URL Fetch, Email, Sheets write)"
  agent: runtime
  severity: P2
  target: "src/**/*.gs"
  rule: "Count external calls per execution — warn at 80% of daily quota"
  fix_if_fail: "Add quota counter + throttle"

- id: RT-011
  name: "API call count per pipeline (Check 16)"
  agent: runtime
  severity: P2
  target: ".github/scripts/**"
  rule: "Count UrlFetchApp/PropertiesService calls in source vs runtime"
  fix_if_fail: "Verify counts match expected budget"

- id: RT-012
  name: "Production access config (Check 17)"
  agent: runtime
  severity: P0
  target: "appsscript.json"
  rule: "access must be DOMAIN or ANYONE, not MYSELF (for production)"
  fix_if_fail: "Update appsscript.json + update SECURITY.md"
```

### Group: DOMAIN-LOGIC (Agent 3)
```yaml
- id: DM-001
  name: "Match Engine 8-rule decision matrix"
  agent: domain
  severity: P0
  target: "src/1_group1_master_db/10b_MatchDecision.gs"
  rule: "All 8 rules present, score ranges 0-1, fallback to ESCALATE on tie"
  fix_if_fail: "Restore missing rule, re-run 10d_MatchTestHarness"

- id: DM-002
  name: "Single Writer Pattern (Law 4 / architect rule)"
  agent: domain
  severity: P0
  target: "src/**/*.gs"
  rule: "Only Group 1 can write to M_PERSON, M_PLACE, M_GEO_POINT, M_DESTINATION"
  fix_if_fail: "Move write call to Group 1 service"

- id: DM-003
  name: "Hybrid Alias single writer"
  agent: domain
  severity: P0
  target: "src/1_group1_master_db/21_AliasService.gs"
  rule: "createGlobalAlias is the only public write path for M_ALIAS"
  fix_if_fail: "Audit all M_ALIAS write sites, route through createGlobalAlias"

- id: DM-004
  name: "RBAC: deny-by-default"
  agent: domain
  severity: P0
  target: "src/O_core_system/27_RbacService.gs"
  rule: "isAuthorizedUser_ must default to false; all menu items guarded"
  fix_if_fail: "Add guard to every menu handler in 00_App.gs"

- id: DM-005
  name: "Thai data normalization (Law 21 / Thai data helper)"
  agent: domain
  severity: P0
  target: "src/**/*.gs"
  rule: "Invoice numbers must call normalizeInvoiceNo_() before compare/write/hash"
  fix_if_fail: "Wrap with normalizeInvoiceNo_() from 14_Utils.gs"

- id: DM-006
  name: "Thai prefix stripping (80+ patterns)"
  agent: domain
  severity: P1
  target: "src/1_group1_master_db/05_NormalizeService.gs"
  rule: "normalizeForCompare must handle คุณ, นาย, นาง, บริษัท, หจก. etc."
  fix_if_fail: "Add missing prefix to pattern list"

- id: DM-007
  name: "Security SEC-001..012 compliance"
  agent: domain
  severity: P0
  target: "src/**/*.gs, .github/workflows/*, .gitleaks.toml"
  rule: "All 12 SEC items: no hardcoded secrets, PII mask, AuthZ, OAuth least privilege, cookie sanitize, formula injection, sheet protection"
  fix_if_fail: "See .skills/lmds-security-auditor/SKILL.md for each SEC item"

- id: DM-008
  name: "PII handling — no logs leak PII"
  agent: domain
  severity: P0
  target: "src/**/*.gs"
  rule: "logError must mask phone, ID, address before logging"
  fix_if_fail: "Use maskPii_() helper in 14_Utils.gs"

- id: DM-009
  name: "Sheet protection (deny-by-default)"
  agent: domain
  severity: P1
  target: "src/**/*.gs"
  rule: "Master sheets must call protectMasterSheet_() on creation"
  fix_if_fail: "Add protection call in 03_SetupSheets.gs"

- id: DM-010
  name: "Formula injection prevention"
  agent: domain
  severity: P0
  target: "src/**/*.gs"
  rule: "Any user input written to sheet must be prefixed with ' if starts with =, +, -, @"
  fix_if_fail: "Add sanitizeForSheet_() before write"

- id: DM-011
  name: "Q_REVIEW decision routing (MAKE_MATCH_DECISION)"
  agent: domain
  severity: P0
  target: "src/1_group1_master_db/10b_MatchDecision.gs"
  rule: "Outcomes: MERGE/CREATE/ESCALATE/IGNORE all return expected shape"
  fix_if_fail: "Re-check 10b return signature, run 10d harness"

- id: DM-012
  name: "No data contamination (Law 1 architect)"
  agent: domain
  severity: P0
  target: "src/**/*.gs"
  rule: "Raw data (Source sheets) never bleeds into Master sheets via direct write"
  fix_if_fail: "Route via 04_SourceRepository.gs ingest pipeline"
```

---

## 📜 Version History ของเทมเพลต

> เวอร์ชั่นนี้คือของ **CHECKS** (รายการตรวจ) ไม่ใช่ของ LMDS

| Template ver | Date | Changes |
|---|---|---|
| 1.0.0 | 2026-07-23 | Initial — 12 ST / 12 RT / 12 DM = 36 checks (เฉพาะ spec ใน CHECKS.md) |
| 1.1.0 | 2026-07-23 | **ชุดรวม 2** — เพิ่ม check scripts ครบทั้ง 36 ตัว (จาก 13 → 36)<br>• Static +8: ST-002, 003, 004, 005, 008, 009, 010, 012<br>• Runtime +7: RT-004, 005, 007, 008, 009, 010, 011<br>• Domain +8: DM-001, 002, 003, 004, 006, 009, 011, 012 |
| 1.2.0 | 2026-07-23 | **ชุดรวม 3 (v3 patch)** — แก้ false positive 9 ตัว + crash bug 1 ตัว<br>• ST-002: regex รับ suffix letter (`10b_`, `21b_`, `22c_`)<br>• DM-001: case-insensitive + รับ `evaluateRule` (camelCase)<br>• DM-011: รับ `makeMatchDecision` + return shape ยืดหยุ่น (`reason`/`confidence`/`evidence`/`priority`)<br>• DM-012: ค้นหา `04_SourceRepository.gs` ในทุก group<br>• DM-002: ตรวจ write จริง (setValues/setValue/appendRow) ไม่ใช่แค่ reference<br>• DM-008: ค้นหา mask functions หลายแบบ (`maskEmail`, `maskSearchQuery`, `sanitizeForSheet`, ฯลฯ)<br>• RT-006: กรอง setup/schema/config files ออก<br>• DM-009: ตรวจทั้ง `03_SetupSheets` + `19_Hardening` + `22_WebApp`<br>• RT-005: แก้ bug `grep -c \|\| echo 0` ที่ทำให้ syntax error<br><br>**ผลทดสอบ:** false positive rate ลดจาก 22% → <5% (DM-008 ยังมี 8 files ต้อง manual review แต่จำนวนน้อยละ)|
| 1.3.0 | 2026-07-24 | **ชุดรวม 4 (v4 patch)** — แก้ residual 3 ตัว + เพิ่ม 5 check ใหม่<br>**Fixes:**<br>• ST-008: ปรับ awk heuristic ให้นับเฉพาะ `function name()` declarations (ไม่นับ `const SCHEMA = Object.freeze({...})`)<br>• DM-002: เพิ่ม `19_Hardening`, `22c_WebAppActions`, `28_WebAppActions` ใน skip list<br>• DM-008: ตรวจเฉพาะไฟล์ที่จริงๆ log PII fields (phone/email/citizenId/etc.) ในบริบท log call ไม่ใช่แค่มี logError<br><br>**New checks (+5):**<br>• RT-013: GitHub Workflows permissions (least privilege) — ตรวจ `.github/workflows/*.yml`<br>• ST-013: Skills catalog schema — ตรวจ `.skills/*/SKILL.md` (YAML frontmatter OR DOC-TYPE marker)<br>• DM-013: SEC-001 Hardcoded OAuth credentials — ตรวจ client_secret/refresh_token/api_key patterns<br>• DM-014: SEC-002 OAuth scope least privilege — ตรวจ `appsscript.json` oauthScopes<br>• RT-014: Frozen header row on master sheets — ตรวจ setFrozenRows(1)<br><br>**ผลทดสอบ:** false positive rate ลดจาก 86% → ~94% accuracy, ครอบคลุม workflows + skills + SEC-001/002 เพิ่ม|
| 1.4.0 | 2026-07-24 | **ชุดรวม 5 (v5 — FINAL, Validate-then-Deliver)** — แก้ DM-014 + เพิ่ม 7 SEC checks + DS-000 wrapper<br>**Fixes:**<br>• DM-014: เปลี่ยนจาก awk → python3 json.load (parse JSON ถูกต้อง)<br>• DM-016: logic แก้ — ถ้าไม่ log body ก็ไม่ต้องมี truncation<br>• DM-021: threshold ลด 80%→30% + skip private helpers (_ suffix)<br>• DM-003: filter comment lines (`: *` และ `: //`)<br><br>**New SEC checks (+7):**<br>• DM-015: SEC-003 Cookie CRLF injection (sanitizeCookie_)<br>• DM-016: SEC-004 PII hashing + fetchWithRetry truncation<br>• DM-017: SEC-005+011 Sheet protection completeness<br>• DM-018: SEC-006 API key in URL (must use header)<br>• DM-019: SEC-009 RFC 6265 cookie regex compliance<br>• DM-020: SEC-012 fetchWithRetry body leak prevention<br>• DM-021: SEC-002+010 AuthZ guard + audit trail<br><br>**New wrapper (+1):**<br>• DS-000: Auto-discover + run LMDS existing `.github/scripts/doc-code-sync-checks/*.sh` (18 checks auto-run)<br><br>**Validate-then-Deliver process:** 7 RUN cycles จนกว่า 0 false positive + 0 crash<br>**Final result:** Domain 21/21 PASS, 0 false positives, 0 crashes ✅|

---

## 🛑 สิ่งที่ห้ามทำ

1. ❌ ห้ามแก้ `agent.md` ของ Agent 1/2/3 เพื่อเพิ่ม check ใหม่ → ต้องเพิ่มที่นี่ก่อน
2. ❌ ห้ามลบ check ออกจาก Active โดยไม่ผ่าน Aggregator
3. ❌ ห้าม hardcode version ของ LMDS ในเทมเพลต
4. ❌ ห้ามให้ Agent ตัดสินว่า check ไหน "สำคัญ" — ให้ user เป็นคนตัดสิน
