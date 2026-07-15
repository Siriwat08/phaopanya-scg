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

### สถานะ: ✅ Compliant

### ไฟล์

- `appsscript.json`

### Scopes ปัจจุบัน (6 ตัว)

1. `script.appsscript.run` — สำหรับ `google.script.run`
2. `script.external_request` — สำหรับ SCG API + Google Maps
3. `script.spreadsheets` — สำหรับอ่าน/เขียน Google Sheets
4. `script.userinfo.email` — สำหรับดึง email ผู้ใช้ (RBAC)
5. `script.locale` — สำหรับ locale formatting
6. `script.timezone` — สำหรับ timezone handling

### การตัดสินใจ

- ลดจาก 10 scopes (V5.5.017) → 6 scopes (V5.5.017+)
- ทุก scope ใช้จริง — ไม่มี unused scope

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

### ก่อนส่งมอบ production

**ต้อง** เปลี่ยน `access` เป็น:

- `DOMAIN` — ถ้าใช้ Google Workspace (คนในองค์กรเข้าได้)
- `ANYONE` — ถ้าเปิดให้คนนอกองค์กร (ต้อง login Google)

แล้วให้ RBAC (`27_RbacService.gs`) เป็นตัวคุมสิทธิ์จริง

### หมายเหตุ

ค่า `MYSELF` เหมาะสำหรับ development/staging เท่านั้น — ไม่ใช่ production

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
