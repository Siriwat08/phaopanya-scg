<!-- DOC-TYPE: historical -->

# 🔍 LMDS V6.0.078 — Full System Audit Report (Pre-Production)

> **วันที่ตรวจ:** 2026-08-04
> **Commit ที่ตรวจ:** `7ae73ec` (main HEAD)
> **ขอบเขต:** ทั้ง repo — 39 ไฟล์ .gs (~28,490 บรรทัด) + 19 ไฟล์ .html + config + CI + docs
> **บริบท:** ผู้ใช้กำลังจะรันกับข้อมูลจริง (Production run)

---

## 🎯 สรุปผลรวม (Executive Verdict)

| ด้าน                                              | ผล                                                        | คะแนน |
| ------------------------------------------------- | --------------------------------------------------------- | ----- |
| Static Analysis (ESLint/Prettier/Syntax)          | ✅ ผ่าน — 0 errors, 43 warnings (คุณภาพโค้ด ไม่ใช่ bug)   | 🟢    |
| Cross-file Integrity (function bridge)            | ✅ ผ่าน — frontend↔backend ครบ 100%, ไม่มี phantom call   | 🟢    |
| Schema & Config Consistency                       | ✅ ผ่าน — SCHEMA vs IDX ตรงกันทุกชุด (16/16 IDX sets)     | 🟢    |
| Version Consistency                               | ✅ ผ่าน — 6.0.078 ตรงกันทุกไฟล์ .gs                       | 🟢    |
| Secrets Scan (working tree + history 200 commits) | ✅ ไม่พบ API key / token / cookie hardcoded               | 🟢    |
| Architecture (Single Writer Rule)                 | ✅ ผ่าน — Group 2 ไม่เขียน Master tables                  | 🟢    |
| RBAC + Endpoint Guards                            | ✅ โครงสร้างถูกต้อง (deny-by-default, fail-closed)        | 🟢    |
| **WebApp Access Config**                          | 🔴 **`access: ANYONE_ANONYMOUS` — ความเสี่ยงสูงสุดที่พบ** | 🔴    |
| Self-Audit Suite (18 checks)                      | 12 PASS / 5 WARN / 1 FAIL → **แก้ FAIL แล้วใน audit นี้** | 🟡    |

**คำตัดสิน: 🟡 GO with CONDITIONS — รันกับข้อมูลจริงได้ แต่ต้องทำ P0 checklist ด้านล่างก่อน deploy**

---

## 🔴 P0 — ต้องทำก่อนรันข้อมูลจริง (BLOCKER)

### P0-1: `appsscript.json` ตั้ง `access: ANYONE_ANONYMOUS` ⚠️ ความเสี่ยงสูงสุด

**ที่พบ:** `appsscript.json` (เปลี่ยนใน PR #219, 2026-07-27 — เดิมเป็น `MYSELF`)

```json
"webapp": {
  "executeAs": "USER_DEPLOYING",
  "access": "ANYONE_ANONYMOUS"
}
```

**ปัญหา 3 ชั้น:**

1. **ขัดกับ SECURITY.md ของโปรเจกต์เอง** — SECURITY.md §"Production checklist" ระบุตัวเลือกที่รองรับคือ `MYSELF` / `DOMAIN` / `ANYONE` (ต้อง login Google) — **ไม่มี `ANYONE_ANONYMOUS` ในตัวเลือกที่อนุมัติ** และ check_17 ของ CI เองก็ flag เป็น "unknown value"

2. **Auth ทั้งระบบพังเชิงตรรกะเมื่อผู้ใช้ anonymous:** เมื่อ `executeAs: USER_DEPLOYING` + ผู้ใช้ไม่ login:
   - `Session.getActiveUser().getEmail()` → ว่าง
   - `Session.getEffectiveUser().getEmail()` → **คืน email เจ้าของ script เสมอ** (22_WebApp.gs:136, 27_RbacService.gs:67)
   - ผลคือ: **ผู้ใช้นิรนามทุกคนถูก resolve เป็น "เจ้าของ script"** → ถ้า email เจ้าของอยู่ใน `DASHBOARD_USERS`/`LMDS_ADMINS` (ซึ่งแทบแน่นอนว่าอยู่) → **คนแปลกหน้าที่มี URL จะผ่าน `isAuthorizedDashboardUser_()` และได้ role ระดับเดียวกับเจ้าของ**
   - เกราะ deny-by-default ที่เขียนไว้อย่างดี (V6.0.067) **ถูก bypass ทั้งหมด** เพราะ email ไม่เคย "ว่าง"

3. **Endpoint ที่เสี่ยงจริง:** `submitReviewDecision` / `submitBulkReviewDecisions` (เขียน FACT_DELIVERY + M_ALIAS ผ่าน approve), `runWebAppAction` → `runFullPipeline_Web`, `safeResetTransactional_Web` (danger actions) — ทั้งหมด guard ด้วย chain เดียวกันที่ถูก bypass

**วิธีแก้ (เลือก 1):**

| ทางเลือก     | ค่า access                           | ผล                                                                          |
| ------------ | ------------------------------------ | --------------------------------------------------------------------------- |
| ✅ **แนะนำ** | `ANYONE` (ไม่ใช่ `ANYONE_ANONYMOUS`) | ผู้ใช้ต้อง login Google → `getActiveUser()` ใช้งานได้ → whitelist ทำงานจริง |
| ปลอดภัยสุด   | `DOMAIN` (ถ้ามี Workspace)           | จำกัดเฉพาะคนในองค์กร                                                        |
| ชั่วคราว     | `MYSELF`                             | ใช้ได้เฉพาะเจ้าของ — เหมาะช่วง run ข้อมูลจริงรอบแรก                         |

**และควรแก้โค้ดเสริม (defense-in-depth):** ใน `isAuthorizedDashboardUser_()` และ `getCurrentUserRole_()` ให้เช็ค `Session.getActiveUser().getEmail()` ก่อน — ถ้าว่างและ deployment เป็น anonymous ให้ deny ทันที แทนที่จะ fallback ไป `getEffectiveUser()` (ซึ่งเป็นเจ้าของเสมอใน `USER_DEPLOYING`)

### P0-2: ตั้ง Script Properties ก่อนรัน

ยืนยันก่อน deploy ว่าตั้งครบ (ระบบ deny-by-default ถ้าไม่ตั้ง — ดีแล้ว แต่ต้องตั้งให้ถูก):

- [ ] `LMDS_ADMINS` — comma-separated admin emails
- [ ] `DASHBOARD_USERS` — ผู้ใช้ dashboard
- [ ] `ROLE_ASSIGNMENTS` — `email:role,...` สำหรับ reviewer
- [ ] `GEMINI_API_KEY` (ถ้าเปิด USE_AI_REASONING)
- [ ] `SCG_COOKIE` (ผ่านเมนู — ห้ามวางใน cell B1)
- [ ] `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` (ถ้าต้องการ alert)

### P0-3: check_09 DOC-TYPE FAIL (CI Blocker) — ✅ แก้แล้วใน audit นี้

`audit-results/*.md` 5 ไฟล์ไม่มี DOC-TYPE tag → self_audit FAIL → block merge
**แก้แล้ว:** เติม `<!-- DOC-TYPE: historical -->` ครบ 5 ไฟล์ → check_09 ผ่าน

---

## 🟡 P1 — ควรแก้เร็ว (ภายใน 1-2 สัปดาห์หลังรันจริง)

### P1-1: Dashboard.html ไม่ escape ข้อมูลก่อน innerHTML (XSS เชิงลึก)

- `Dashboard.html` ใช้ `escapeHtml` **0 ครั้ง** (เทียบ QReview 42, FactDelivery 21)
- จุดเสี่ยง: `renderBreakdownAndIssues_` — `issue.issueType` จาก backend ถูกต่อ string เข้า `innerHTML` ตรง ๆ (บรรทัด ~596-617) เมื่อ issueType ไม่อยู่ใน `issueLabels` map
- ความเสี่ยงจริง: **ต่ำ-กลาง** (ค่ามาจาก MatchEngine enum ภายใน ไม่ใช่ user input ตรง) แต่ raw data จาก SCG API ไหลเข้าระบบ → ถ้า status/issueType ปนเปื้อนจะ inject ได้
- **แก้:** ครอบ `ViewHelpers.escapeHtml()` ทุกค่าที่มาจาก server ใน Dashboard.html (~30 นาที)

### P1-2: README.md เวอร์ชันค้างที่ 6.0.072 (โค้ดจริง 6.0.078)

- README อ้าง "6.0.072 / 96% GO" 5 จุด — คลาดเคลื่อน 6 เวอร์ชัน
- สถิติ (39 files, 543 functions) ยังตรง แต่ตัวเลขเวอร์ชัน + compliance status เก่า
- **แก้:** รัน `./scripts/bump_version.sh` sync docs หรืออัปเดต README manual

### P1-3: `getSheetByName` 157 ครั้ง (เกิน threshold 100 — quota risk)

- check_16 เตือน — ควรทำ sheet handle caching (module-level memo) ในไฟล์ hot path: `10_MatchEngine`, `12_ReviewService`, `22b_WebAppViews`
- ความเสี่ยงตอนรันข้อมูลจริง: ถ้า SOURCE มีหลายหมื่น rows + trigger ถี่ → ชน quota execution time

### P1-4: Dead functions 58 ตัว (check_10)

- ตรวจสอบแล้วส่วนใหญ่เป็น **false positive** — `runFullPipeline_Web` ฯลฯ ถูกเรียกผ่าน registry (`serverFn: 'runFullPipeline_Web'` → `globalThis[action.serverFn]`) และ `showVersionInfo` ผ่าน `.addItem(...)` menu string — checker มองไม่เห็น dynamic dispatch
- ของจริงที่น่าเก็บกวาด: `saveSourceRowsToCache_` (0 callers ทุกรูปแบบ)
- **แก้:** ปรับ check_10 ให้ scan `serverFn:` + `addItem(` patterns เพื่อลด noise

### P1-5: Audit Trail coverage ยังไม่ครบ (Issue #215 ที่ทีมรู้อยู่แล้ว)

- `logAuditTrail()` ยังไม่ถูกเรียกจาก create functions 5 ตัว → การรันข้อมูลจริงรอบแรกจะ**ไม่มี audit trail ของการสร้าง master records** — ยอมรับได้ถ้าตั้งใจ แต่ควรรู้ก่อนรัน

---

## 🟢 P2 — ทราบไว้ / ทำภายหลัง

1. **Runtime CDN (Tailwind browser compiler)** — Issue #214 เปิดอยู่แล้ว; มี SRI pin version ครบ (`@4.3.2`, Chart.js `4.4.6`, Lucide `0.460.0`) → ความเสี่ยง supply-chain ต่ำแต่มี availability risk ถ้า CDN ล่ม
2. **ESLint 43 warnings** — complexity สูงสุด 60 (`getReviewDetail`), functions >200 บรรทัดใน views — ตรงกับ Issue #205/#206 ที่วางแผนไว้แล้ว
3. **String duplication 14 จุด** (check_15) — DRY debt เล็กน้อย
4. **`fetchWithRetry_` (18_ServiceSCG) ไม่ตั้ง `muteHttpExceptions: true`** — non-2xx จะ throw แทน retry ตาม status code ที่ตั้งใจ (โชคดีที่ catch ครอบไว้จึง retry ได้ แต่แยก 4xx/5xx ไม่ได้ — ควรเพิ่ม option นี้เพื่อ retry อย่างฉลาด)
5. **`.skills/`, `LMDS Supreme Engineer.md`, `exports/`** — ไฟล์ meta/AI-tooling อยู่ใน repo production; ไม่อันตราย แต่ควรพิจารณาแยก repo

---

## ✅ สิ่งที่ตรวจแล้ว "ผ่าน" (ยืนยันด้วยหลักฐาน)

| การตรวจ                                             | วิธี                                                                                          | ผล                                                |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| Frontend→Backend bridge                             | สแกน `google.script.run.*` + registry `serverFn` ทุกตัว vs function definitions               | **0 missing**                                     |
| Duplicate global functions                          | grep `^function` ทั้ง 39 ไฟล์                                                                 | **0 ซ้ำ** (GAS จะ silent-override ถ้าซ้ำ — ไม่มี) |
| SCHEMA vs IDX (comment-stripped parse)              | M_PERSON 13=13, FACT 34=34, Q_REVIEW 22=22, SYS_NOTES 11=11, NEG_SAMPLES 8=8, AUDIT 11=11 ฯลฯ | **ตรงทุกชุด**                                     |
| Secrets ใน working tree + git history (200 commits) | regex: AIza…, bot token, sk-, ghp_, AKIA, Bearer                                              | **ไม่พบ**                                         |
| SCG Cookie handling                                 | เก็บใน Script Properties + auto-clear cell B1 + ไม่ log HTTP body                             | **ถูกต้อง**                                       |
| Gemini API key                                      | ส่งผ่าน header (`x-goog-api-key`) ไม่ใช่ URL + retry 429/503 exponential backoff              | **ถูกต้อง**                                       |
| Telegram alert                                      | `muteHttpExceptions: true` + retry + ไม่ throw เข้า pipeline (Rule 12)                        | **ถูกต้อง**                                       |
| LockService coverage                                | 23 ไฟล์ใช้ lock, onEdit มี tryLock(5000) + finally release                                    | **ถูกต้อง**                                       |
| onEdit permission guard                             | `hasPermission_('action:approve_review')` เช็คก่อน apply (V6.0.070 P0-2)                      | **ถูกต้อง**                                       |
| Single Writer Rule                                  | สแกน write ops ใกล้ `SHEET.M_*` ใน Group 2 ทั้ง 8 ไฟล์                                        | **0 violation**                                   |
| Input validation                                    | `validateInput_` enum+pattern+maxLength บน review endpoints                                   | **ถูกต้อง**                                       |
| PII masking                                         | `maskEmailSafe_` / `maskReviewerEmail_` ก่อน log                                              | **ถูกต้อง**                                       |
| Version headers                                     | ทุกไฟล์ .gs = 6.0.078 = APP_VERSION = SCHEMA_VERSION                                          | **ตรง**                                           |
| Fail-closed auth                                    | `isAuthorizedOrFail_` deny เมื่อ module ไม่โหลด/throw                                         | **ถูกต้อง** (แต่ดู P0-1)                          |

---

## 📋 Pre-Production Runbook (ลำดับที่แนะนำก่อนรันข้อมูลจริง)

```text
1. [BLOCKER] แก้ appsscript.json → access: "ANYONE" (หรือ MYSELF สำหรับรอบแรก)
2. [BLOCKER] ตั้ง Script Properties ครบ 6 ตัว (P0-2 checklist)
3. Deploy ใหม่ (clasp push + New deployment) — เวอร์ชัน deployment เก่าจะยังใช้ config เก่า
4. ทดสอบ auth 3 กรณี:
   a. เจ้าของ → เข้าได้ + role admin
   b. email ใน ROLE_ASSIGNMENTS (reviewer) → เข้าได้ + approve ได้ + run pipeline ไม่ได้
   c. คนนอก whitelist (เปิด incognito + login Google อื่น) → ต้องเจอหน้า Unauthorized
5. รัน [CMD: PREDEPLOY] / runPreflightAudit ใน production sheet
6. รัน Test Match Dry Run (100 rows) ก่อน — ตรวจ TEST_MATCH_RESULTS
7. Backup spreadsheet (File > Make a copy) ก่อนรัน runFullPipeline จริง
8. รันจริง batch แรกขนาดเล็ก → ตรวจ SYS_LOG ว่าไม่มี ERROR → ค่อยรันเต็ม
9. Monitor: Q_REVIEW ratio, Telegram alerts, quota (Executions ใน GAS console)
```

---

## 🧪 หลักฐานการรันเครื่องมือ (Tool Evidence)

- `npx eslint src/ --ext .gs,.js,.html` → **0 errors / 43 warnings**
- `npx prettier --check` → **PASS**
- `bash scripts/self_audit.sh` → 12 PASS / 5 WARN / 1 FAIL (check_09) → **หลังแก้: 13 PASS / 5 WARN / 0 FAIL**
- Custom static analysis (Python AST-lite): function bridge, duplicate scan, schema-IDX diff → ผ่านทั้งหมด
- Git history secret scan (200 commits) → สะอาด

---

_รายงานนี้สร้างโดยการตรวจสอบอัตโนมัติ + manual code review เชิงลึก — ประเด็น P0-1 (ANYONE_ANONYMOUS) เป็นข้อค้นพบใหม่ที่ยังไม่อยู่ใน Issues #205-#215_
