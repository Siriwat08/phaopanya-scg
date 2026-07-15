<!-- DOC-TYPE: living -->

# 🔒 Security Documentation — LMDS V6.0

> เอกสารนี้บันทึก known security risks, mitigations, และ decisions ที่เกี่ยวกับความปลอดภัยของ LMDS V6.0

---

## 0. การรายงานช่องโหว่ด้านความปลอดภัย

หากคุณพบช่องโหว่ด้านความปลอดภัยในโปรเจกต์ LMDS V6.0 กรุณารายงานให้เราทราบ

### วิธีรายงาน

**แนะนำ**: ใช้ **Private Vulnerability Reporting** ของ GitHub

1. ไปที่ tab **Security** ใน repository
2. คลิก **Report a vulnerability**
3. กรอกรายละเอียด: ปัญหา, ขั้นตอนการเกิด, ผลกระทบ, วิธีแก้ (ถ้ามี)
4. รายงานจะเป็น private — เฉพาะ maintainer เห็นเท่านั้น

**ทางเลือก**: ส่ง email ไปยังผู้ดูแลระบบโดยตรง

### ภายในกี่วันจะตอบกลับ?

- **ยืนยันการรับ**: ภายใน 48 ชั่วโมง
- **ประเมินความรุนแรง**: ภายใน 5 วันทำการ
- **แจ้งวิธีแก้**: ภายใน 30 วัน (ขึ้นกับความรุนแรง)

### ขอบเขต

ช่องโหว่ที่ควรรายงาน:

- ✅ SQL injection / XSS / CSRF
- ✅ การเข้าถึงข้อมูลโดยไม่ได้รับอนุญาต
- ✅ การ bypass authentication
- ✅ Hardcoded secrets ในโค้ด

**ไม่ใช่ช่องโหว่** (ไม่ต้องรายงาน):

- ❌ Dependency vulnerabilities (ใช้ Dependabot แทน)
- ❌ Code style / best practice
- ❌ Performance issues

---

## 1. XFrameOptionsMode.ALLOWALL (Clickjacking Risk)

### สถานะ: ⚠️ Known Risk — Mitigated

### ที่ตั้งค่า

- **ไฟล์:** `src/O_core_system/22_WebApp.gs`
- **บรรทัด:** 61, 85
- **ค่า:** `HtmlService.XFrameOptionsMode.ALLOWALL`

### ความเสี่ยง

`ALLOWALL` ปิด X-Frame-Options header ทำให้ WebApp สามารถถูก embed ใน `<iframe>` บนเว็บไซต์อื่นได้ — เปิดโอกาสให้ **clickjacking attack** (ผู้ไม่ประสงค์ดีซ่อน WebApp ของเราใน iframe ด้านบนปุ่มปลอม เพื่อหลอกผู้ใช้คลิก)

### ทำไมยังใช้ ALLOWALL

1. **GAS sandbox:** Apps Script WebApp ทำงานใน sandboxed iframe ของ Google เอง — ถ้าตั้งเป็น `DEFAULT` (X-Frame-Options: SAMEORIGIN) อาจทำให้ WebApp ไม่แสดงผลในบาง context
2. **ไม่มี embedding ภายนอก:** ตรวจสอบแล้ว — ไม่มีเว็บไซต์ภายนอกใด embed LMDS WebApp (ไม่มีการใช้ `iframe src=...script.google.com`)
3. **Auth layer แรก:** WebApp มี auth check (`isAuthorizedDashboardUser_`) ก่อนทุกอย่าง — ผู้ใช้ที่ไม่ได้รับอนุญาตจะเห็นหน้า Unauthorized ไม่ใช่ dashboard จริง

### Mitigations ที่มีอยู่

| Layer    | Protection                                                   | สถานะ                     |
| -------- | ------------------------------------------------------------ | ------------------------- |
| 1. Auth  | `isAuthorizedDashboardUser_()` + `DASHBOARD_USERS` whitelist | ✅ Deny-by-default        |
| 2. RBAC  | `27_RbacService.gs` — 3 roles (viewer/reviewer/admin)        | ✅ Permission-based       |
| 3. OAuth | Google OAuth login บังคับ                                    | ✅ ไม่มี anonymous access |
| 4. XSS   | `escapeHtml()` ใช้ใน 112 จุด                                 | ✅ Output encoding        |
| 5. CSRF  | GAS ใช้ same-origin policy สำหรับ `google.script.run`        | ✅ Built-in               |

### ถ้าจะย้ายไป DEFAULT ในอนาคต

ต้องทดสอบ:

1. WebApp ยังแสดงผลใน Google Sheets sidebar ได้
2. WebApp ยังแสดงผลเมื่อเปิดผ่าน direct URL
3. ไม่มี console error เรื่อง X-Frame-Options

ถ้าทดสอบผ่าน → สามารถเปลี่ยนเป็น `DEFAULT` ได้ (ลด risk)

---

## 2. OAuth Scopes (Least Privilege)

### สถานะ: ✅ Compliant — All 6 scopes verified in use (V6.0.056)

### ไฟล์

- `appsscript.json`

### Scopes ปัจจุบัน (6 ตัว) — verified V6.0.056

| #   | Scope                     | Used By                                 | Usage Count | Purpose                                                                   |
| --- | ------------------------- | --------------------------------------- | ----------- | ------------------------------------------------------------------------- |
| 1   | `spreadsheets`            | `SpreadsheetApp`                        | 30 files    | อ่าน/เขียน Google Sheets (master data, FACT_DELIVERY, Q_REVIEW, SYS_LOG)  |
| 2   | `userinfo.email`          | `Session.getEffectiveUser().getEmail()` | 21 calls    | ดึง email ผู้ใช้สำหรับ RBAC + audit trail (verified_by, created_by)       |
| 3   | `script.storage`          | `PropertiesService`                     | 19 files    | เก็บ secrets (GEMINI_API_KEY, SCG_COOKIE, LMDS_ADMINS) + processing state |
| 4   | `script.container.ui`     | `SpreadsheetApp.getUi()`                | 33 calls    | Custom menu, alerts, modals, sidebar                                      |
| 5   | `script.scriptapp`        | `ScriptApp.getProjectTriggers()`        | 3 files     | Auto-resume triggers + trigger cleanup                                    |
| 6   | `script.external_request` | `UrlFetchApp`                           | 4 files     | SCG API + Google Maps geocoding                                           |

### การตัดสินใจ

- **ลดจาก 10 scopes (V5.5.017) → 6 scopes (V5.5.017+)**
- **V6.0.056 audit:** ทุก scope ใช้จริง — ไม่มี unused scope (verified via grep)
- ไม่มี scope ที่ขาด — ทุก feature ทำงานได้โดยไม่ต้องเพิ่ม scope

### หมายเหตุ

- `google.script.run` ไม่ต้องการ scope แยก — ใช้ `script.container.ui` ครอบคลุมแล้ว
- `Logger.log` ไม่ต้องการ scope
- `CacheService` ใช้ `script.storage` (same as PropertiesService)
- `LockService` ใช้ `script.scriptapp` (same as ScriptApp triggers)

---

## 3. Access Control (`appsscript.json`)

### สถานะ: ⚠️ Review Required Before Production Deploy

### ค่าปัจจุบัน

```json
{
  "access": "MYSELF",
  "executeAs": "USER_DEPLOYING"
}
```

### ความหมาย

- `access: MYSELF` — เฉพาะคน deploy เท่านั้นเข้า WebApp ได้
- `executeAs: USER_DEPLOYING` — โค้ดทำงานในฐานะคน deploy (ไม่ใช่ผู้ใช้ที่เรียก)

### ก่อนส่งมอบ production — Checklist

**ต้อง** เปลี่ยน `access` เป็น:

| ค่า      | เหมาะสำหรับ             | หมายเหตุ                               |
| -------- | ----------------------- | -------------------------------------- |
| `MYSELF` | Development / staging   | ค่าปัจจุบัน — ไม่เหมาะ production      |
| `DOMAIN` | Google Workspace องค์กร | คนในองค์กรเข้าได้ (ต้อง login)         |
| `ANYONE` | เปิดสาธารณะ             | คนนอกองค์กรเข้าได้ (ต้อง login Google) |

**หลังเปลี่ยน access:**

1. ทดสอบว่า RBAC (`27_RbacService.gs`) ยังทำงาน — คนที่ไม่ใช่ admin ไม่สามารถใช้ danger actions
2. ทดสอบว่า `isAuthorizedDashboardUser_()` ยัง reject คนที่ไม่ใน `DASHBOARD_USERS` list
3. ตั้ง `LMDS_ADMINS` ใน PropertiesService — รายชื่อ email ของ admin (comma-separated)
4. ตั้ง `DASHBOARD_USERS` ใน `01_Config.gs` — รายชื่อ email ของผู้ใช้ที่เข้า dashboard ได้

### `executeAs` — ข้อควรระวัง

`USER_DEPLOYING` หมายถึง:

- โค้ดทำงานในฐานะคน deploy → ผู้ใช้ทุกคนแชร์ quota ของคน deploy
- ข้อดี: ไม่ต้อง share Google Sheet กับผู้ใช้ทุกคน
- ข้อเสีย: ถ้าโค้ดเขียนข้อมูลผิด → ใช้ quota ของคน deploy (อาจหมดเร็ว)

ถ้าต้องการให้ผู้ใช้ใช้ quota ของตัวเอง → เปลี่ยนเป็น `USER_ACCESSING`

- ข้อเสีย: ต้อง share Google Sheet กับผู้ใช้ทุกคนที่จะเข้า dashboard

### หมายเหตุ

ค่า `MYSELF` เหมาะสำหรับ development/staging เท่านั้น — ไม่ใช่ production
หลังเปลี่ยน `access` → ให้ RBAC (`27_RbacService.gs`) เป็นตัวคุมสิทธิ์จริง

---

## 4. Secrets Management

### สถานะ: ✅ Compliant

### ที่เก็บ secrets

| Secret           | Storage                                                                | หมายเหตุ                                       |
| ---------------- | ---------------------------------------------------------------------- | ---------------------------------------------- |
| `GEMINI_API_KEY` | `PropertiesService.getScriptProperties()`                              | ไม่อยู่ในโค้ด                                  |
| `SCG_COOKIE`     | `PropertiesService.getScriptProperties()` (primary) + cell B1 (legacy) | V6.0.036: migrate จาก cell → PropertiesService |
| `LMDS_ADMINS`    | `PropertiesService.getScriptProperties()`                              | comma-separated email list                     |
| GitHub PAT       | GitHub Secrets (`.env` not tracked)                                    | สำหรับ CI/CD                                   |

### การตรวจสอบ

- `gitleaks` workflow (`.github/workflows/08-gitleaks.yml`) สแกนทุก PR
- `.gitignore` ป้องกัน `.clasp.json`, `.clasprc`, credentials, `.env`
- ไม่มี hardcoded API key / token / password ใน source code

---

## 5. Audit Trail

### สถานะ: ✅ Critical-Only (by design)

### การออกแบบ

ระบบ audit ปัจจุบันใช้ "Critical-Only" pattern — บันทึกเฉพาะเหตุการณ์สำคัญ:

- Auth failures
- Permission denials
- Data modifications (alias creation, merge, delete)
- Pipeline errors

### ทำไมไม่ log ทุกอย่าง

**GAS quota จำกัด** — การ log ทุก action จะทำให้:

- เร็วๆ นี้เจอ `Logger.log()` quota exceeded
- `SYS_LOG` sheet โตเร็วเกินไป (Google Sheets มี cell limit 10M cells)
- ช้าลงเพราะ sheet write ทุก action

### ทางเลือก

ถ้าต้องการ audit ละเอียดขึ้นในอนาคต:

- ใช้ Cloud Logging (ผ่าน `console.log` ที่ส่งไป Stackdriver)
- ไม่ใช้ Google Sheets สำหรับ audit log ระดับ low-level

---

## 6. Input Validation

### สถานะ: ✅ Output Encoding (escapeHtml)

### การป้องกัน XSS

- `escapeHtml()` ใช้ใน **112 จุด** ทั่ว codebase
- ทุก output ที่รับจาก user input จะถูก encode ก่อนแสดงผล
- ไม่มีการใช้ `innerHTML` กับ raw user input โดยตรง

### การป้องกัน SQL Injection

- GAS ไม่ใช้ SQL — ใช้ Google Sheets API
- ไม่มี query string concatenation

---

## 7. Security Review History

| Date       | Reviewer               | Findings                                      | Status                                      |
| ---------- | ---------------------- | --------------------------------------------- | ------------------------------------------- |
| 2026-07-15 | Reviewer 2 (Architect) | Defense-in-Depth 7-layer model                | ✅ Layers 2, 3, 6 strong; others documented |
| 2026-07-15 | Reviewer 3 (Auditor)   | 12 findings — most Quick Wins done in PR #134 | ✅ Resolved                                 |
| 2026-07-15 | Reviewer 1 (Refactor)  | Code-level review                             | ✅ Refactored in PRs #136-138               |

---

## 8. Security-Related Files

| File                                  | Purpose                              |
| ------------------------------------- | ------------------------------------ |
| `.github/workflows/06-codeql.yml`     | CodeQL security analysis             |
| `.github/workflows/08-gitleaks.yml`   | Secret scanning                      |
| `.gitleaks.toml`                      | Gitleaks allowlist (false positives) |
| `src/O_core_system/19_Hardening.gs`   | Preflight checks + runtime hardening |
| `src/O_core_system/27_RbacService.gs` | Role-based access control            |
| `appsscript.json`                     | OAuth scopes + access control        |
