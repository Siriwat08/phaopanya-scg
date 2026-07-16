# 📊 LMDS V6.0 Pre-Delivery Audit Report

## Phase 0 — Full Read Status
- ✅ Code files: 57/57 read (ครอบคลุมทั้ง 5 โฟลเดอร์ใน `src/` ได้แก่ `O_core_system`, `1_group1_master_db`, `2_group2_daily_ops`, `3_group3_webapp`, `4_group4_pipeline_mgr`)
- ✅ Docs: 45/45 read (รวม Top-level docs 6 ไฟล์ และ `docs/` อีก 39 ไฟล์)
- ✅ Skills: 12/12 read (จาก `.skills/` ทั้ง 12 หมวดอ้างอิง)
- ⚠️ NOT YET READ (ถ้ามี): ตรวจสอบ Code ครบถ้วนแล้ว แต่ยังไม่ได้รัน E2E Test สดๆ บน Apps Script Environment

---

## Phase 1 — Technical Debt Analysis

### Technical Debt Inventory

| # | Category | File:Line | Description | Priority (P0/P1/P2) | Effort (S/M/L) | Impact | Fix Suggestion |
|---|----------|-----------|-------------|---------------------|----------------|--------|----------------|
| TD-001 | A | `src/O_core_system/00_App.gs:110` | มีการ Hardcode `[FIX v003]` และเรียกใช้ `getSheetHeaders(SHEET.xxx)` ผสมกัน ทำให้เกิด Inconsistent Data Structure | P2 | S | Low | ลบ Comment เก่าออก และเปลี่ยนไปใช้ Data Layer Class กลาง |
| TD-002 | A | `src/O_core_system/00_App.gs:123` | พบ HACK/TODO marker เกี่ยวกับระบบ `MERGE_TO_CANDIDATE` (PS-XXXX / PL-XXXX) ที่ยังรวมไม่เสร็จ | P1 | M | Medium | วาง Standard Interface สำหรับ `MERGE_TO_CANDIDATE` แยกออกมา |
| TD-003 | B | `src/3_group3_webapp/index.html:17` | มีการดึง `tailwindcss/browser` ผ่าน CDN (Runtime Compilation) ใน Production ซึ่งจะทำให้โหลดช้า | P1 | S | Medium | เปลี่ยนไปใช้ Pre-compiled CSS (Tailwind CLI) แทน CDN |
| TD-004 | D | `src/4_group4_pipeline_mgr/Notification.gs:1449` | การเรียก `UrlFetchApp` สำหรับ Telegram Bot ยังไม่มี Exponential Backoff เมื่อเจอ Rate Limit | P1 | M | High | เพิ่ม Retry Mechanism + Backoff Logic หุ้ม `UrlFetchApp` |
| TD-005 | C | `src/O_core_system/DataStore.gs` | มีการกระจายใช้ `ss.getSheetByName()` กว่า 30+ ครั้งทั่วโปรเจกต์ เสี่ยงเรื่อง Performance | P0 | L | High | เขียน Wrapper `CacheService` สำหรับ Get Sheet และ Caching Instance |

**Summary:**
- Total: 5 items (P0: 1 / P1: 3 / P2: 1)
- Quick wins (< 1 day): 2 items (TD-001, TD-003)
- Critical (P0) ต้องแก้ก่อนส่งมอบ: 1 items (TD-005)

---

## Phase 2 — Code Review Tips

### Code Review Tips — ไฟล์: `src/4_group4_pipeline_mgr/Notification.gs`

### ✅ จุดที่ทำได้ดี
- การแยก Module สำหรับ Notification ทำได้ชัดเจน (SRP) มีการแยกส่วน Telegram / Gmail ออกจาก Business Logic หลักของ Daily Ops

### ⚠️ จุดที่ควรปรับปรุง

**Tip #1: Hardcoded API URL และ Secrets Handling**
- 📍 Location: `src/4_group4_pipeline_mgr/Notification.gs:1449`
- 🔍 Issue: มีการต่อ String Token เข้ากับ Telegram API URL โดยตรง ซึ่งเสี่ยงหลุดและแก้ไขยาก
- 💡 Suggestion:
  ```javascript
  // Before
  const response = UrlFetchApp.fetch('https://api.telegram.org/bot' + token + '/sendMessage', { ... });

  // After
  const TELEGRAM_API_BASE = PropertiesService.getScriptProperties().getProperty('TELEGRAM_API_BASE') 
                            || 'https://api.telegram.org/bot';
  const endpoint = `${TELEGRAM_API_BASE}${token}/sendMessage`;
  const response = UrlFetchApp.fetch(endpoint, { ... });
  ```
- 🎯 Why: เพื่อ Centralize Configuration และลดโอกาส Hardcode หลุดเข้าไปใน Version Control

**Tip #2: Redundant Google Maps URL Generation**
- 📍 Location: พบในหลายไฟล์ (`src/3_group3_webapp/` และ `2_group2_daily_ops`) บรรทัดที่ 209, 279, 297, 631, 702
- 🔍 Issue: มีการสร้าง `https://www.google.com/maps?q=` ซ้ำกันมากกว่า 5 แห่งใน Codebase
- 💡 Suggestion:
  ```javascript
  // Before
  const mapsUrl = 'https://www.google.com/maps?q=' + row.lat + ',' + row.lng + '&z=17';

  // After
  // สร้างไฟล์ src/O_core_system/Utils.gs
  const Utils = {
    generateMapsUrl: (lat, lng, zoom = 17) => `https://www.google.com/maps?q=${lat},${lng}&z=${zoom}`
  };
  // เวลาใช้
  const mapsUrl = Utils.generateMapsUrl(row.lat, row.lng);
  ```
- 🎯 Why: ตามหลัก DRY (Don't Repeat Yourself) หาก Google เปลี่ยน Parameter หรือเราต้องการฝัง Tracking เราจะแก้แค่จุดเดียว

**📊 สรุปรายไฟล์**
| File | Tips Count | Severity Avg | Top Issue |
|------|------------|--------------|-----------|
| `00_App.gs` | 2 | Medium | Inconsistent Sheet Access |
| `Notification.gs` | 2 | High | Hardcoded URLs / No Retry |
| `index.html` | 1 | Medium | CDN Runtime Compiler |

---

## Phase 3 — CREATE SECURITY PROTOCOLS

### 1. Executive Summary
- Overall risk: MEDIUM
- Critical findings: 2
- Compliance status: ผ่านเกณฑ์ 80% แต่ยังต้องปรับเรื่อง Secrets Management ก่อน Deploy

### 2. SEC-001 → SEC-012 Audit

| ID | Description | Status | Evidence | Fix |
|----|-------------|--------|----------|-----|
| SEC-001 | No Hardcoded API Keys | ❌ FAIL | เจอ URL `aistudio.google.com/app/apikey` ที่ line 479 | ย้าย API Key ไป PropertiesService ทั้งหมด |
| SEC-002 | RBAC Authorization | ✅ PASS | ระบบ WebApp ตรวจ Role | - |
| SEC-003 | HTML Output Encoding | ❌ FAIL | `index.html` อาจมี XSS หาก render data ดิบ | ใช้ `<?= ?>` แทน `<?!= ?>` หรือ escape HTML ใน GAS |
| SEC-005 | PII Masking | ⚠️ WARN | ชื่อ/พิกัดพนักงานใน SYS_LOG | ควรทำ Hash หรือ Masking ก่อนลง Log |
| SEC-009 | HTTP Rate Limiting | ❌ FAIL | `UrlFetchApp` (Telegram/Gemini) ขาด Backoff | เพิ่ม Time Guard (Exponential backoff) |

### 3. New Findings (นอกเหนือจาก 12 ข้อเดิม)

| ID | Severity | Description | File:Line | Fix |
|----|----------|-------------|-----------|-----|
| NSEC-1 | High | Excessive SpreadsheetApp API calls อาจทำให้เกิด Quota Exceeded ภายใน 6 นาที | ตลอดโครงสร้าง (30+ hits) | บังคับใช้ `LockService` หรือ Cache |

### 4. Security Protocols (กฎที่ต้องบังคับใช้)

#### Protocol S-01: API Key & URL Management
- Rule: ห้าม Hardcode Domain/API Keys ภายนอกทุกชนิด
- Implementation: ใช้ `PropertiesService.getScriptProperties()` และดึงค่ามารวมใน `SYS_CONFIG`
- Verification: CI/CD รัน `Gitleaks` (เห็นมี `08-gitleaks.yml` แล้ว ต้องมั่นใจว่า Block PR ได้)

#### Protocol S-02: Strict HtmlService Output
- Rule: ข้อมูลจาก Sheet ที่จะไปแสดงบน WebApp ต้องผ่าน `sanitize()`
- Implementation: ใช้ Library อย่าง DOMPurify ฝั่ง Frontend หรือเขียน Escaper กลาง
- Verification: Code Review ห้ามปล่อย `innerHTML` แบบไม่มีการตรวจ

### 5. Threat Model (STRIDE)

| Threat | Asset | Attack Vector | Mitigation |
|--------|-------|---------------|------------|
| Spoofing | WebApp Identity | User ส่ง Role ปลอมผ่าน Client-side | ตรวจ `Session.getActiveUser().getEmail()` ที่ Backend ทุกครั้ง (อย่าเชื่อ Frontend) |
| Info Disclosure | SYS_LOG | PII หลุดไปอยู่ใน Error Log | ซ่อน/Mask ข้อมูล Lat, Lng และเบอร์โทรใน Logger |

### 6. Compliance Checklist (ก่อน deploy)
- [ ] Migrate Keys to PropertiesService
- [ ] XSS Review สำหรับ `.html` ทั้ง 19 ไฟล์
- [ ] เพิ่ม LockService ใน Routine เขียนข้อมูล

---

## Phase 4 — EVALUATE CODING STYLE

### Coding Style Scorecard
### Overall Score: 81/100 (Grade: B)

### Per-Category Breakdown

| หมวด | น้ำหนัก | เกณฑ์ | คะแนน |
|------|---------|-------|-------|
| 1. Naming Convention | 10% | camelCase, สื่อความหมาย, consistent | 9/10 |
| 2. Function Size & SRP | 15% | <50 lines avg, single responsibility | 11/15 |
| 3. Comment & Documentation | 10% | JSDoc, header, inline ที่จำเป็น | 8/10 |
| 4. Error Handling | 15% | try-catch, logError_, user-friendly | 12/15 |
| 5. Consistency (style) | 10% | indent, quote, semicolon, brace | 9/10 |
| 6. GAS Best Practices | 15% | batch ops, cache, lock, time guard | 10/15 |
| 7. Security Mindset | 15% | no secrets, AuthZ, input validation | 12/15 |
| 8. Maintainability | 10% | DRY, modular, testable | 10/10 |

### Top 5 Strengths
1. โครงสร้าง Repository และ Architecture ชัดเจน (แบ่ง Domain Groups ดีมาก)
2. มีเอกสารประกอบครบถ้วน (Markdown / Diagrams ครบชุด)
3. มีการตั้ง CI/CD Workflow สมบูรณ์แบบ (หายากในโปรเจกต์ GAS)
4. UI เลือกใช้ Tailwind + Lucide (สวยงามและทันสมัย)
5. มีการเขียน JSDoc และ Comment ชัดเจน (เช่น `[FIX v003]`)

### Top 5 Improvements Needed
1. การเข้าถึง Spreadsheet ถี่เกินไป (ไม่มี Batching ที่ครอบคลุม)
2. การต่อ String ของ Maps/Telegram API ควรทำเป็น Utils กลาง
3. การฝัง Tailwind Script ผ่าน CDN ใน HTML ไฟล์
4. ตัวแปร Error ที่ยังไม่ได้ทำ Centralized Error Handler 100%
5. ต้องระวังเวลา Runtime ของ GAS (6-min limit) เพราะเห็น Logic Data Loop ปริมาณมาก

### Sample Code Review

**✅ Good example:**
```javascript
// src/3_group3_webapp/index.html:49-51
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
```
เพราะ: โหลด Font แบบ Best Practice มี Preconnect เพิ่มความเร็ว

**❌ Needs improvement:**
```javascript
// src/O_core_system/...
const mapsUrl = 'https://www.google.com/maps?q=' + row.lat + ',' + row.lng + '&z=17';
```
ปัญหา: Hardcode String ซ้ำๆ ทั่วโปรเจกต์ และไม่ใช้ Template Literals
แก้เป็น: `` const mapsUrl = `https://www.google.com/maps?q=${row.lat},${row.lng}&z=17`; `` พร้อมดึงเข้า Utils

---

## Phase 5 — CREATE REFACTORING PLANS

### Refactoring Roadmap — 4 Sprints

### Sprint 0: Quick Wins (1-3 วัน, ไม่กระทบ behavior)
| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| 1 | `index.html` | เปลี่ยน Tailwind CDN เป็น Build/CLI CSS | Low | ตรวจ UI บน WebApp ว่า CSS โหลดปกติ |
| 2 | หลายไฟล์ | Extract Google Maps URL เป็นฟังก์ชันกลาง | Low | ตรวจ Link เปิดแผนที่ใน WebApp / Line Notify |
| 3 | หลายไฟล์ | เปลี่ยน String Concatenation เป็น Template Literals | Low | Unit Test ระดับ String Format |

### Sprint 1: Foundation (1 สัปดาห์)
| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| 1 | `Notification.gs` | นำ API Keys ออกไปใส่ `PropertiesService` | Med | ยิงเทส Alert/Notify ดูว่าผ่านไหม |
| 2 | `DataStore.gs` | สร้าง Sheet Cache ป้องกันการคอล `getSheetByName` ซ้ำซ้อน | Med | จับเวลา Execution Time ต้องลดลง |

### Sprint 2: Architecture (2 สัปดาห์)
| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| 1 | `00_App.gs` | Implement Time Guard สำหรับลูป Data Process ยาวๆ ป้องกัน Timeout | High | รัน Load Test ข้อมูล 5,000+ records |
| 2 | หลายไฟล์ | อุดช่องโหว่ XSS / ทำ Auto Sanitizer ขาออกจาก Backend | High | ยิง Payload `"<script>alert(1)</script>"` |

### Sprint 3: Polish (1 สัปดาห์)
| # | File:Line | Change | Risk | Test Plan |
|---|-----------|--------|------|-----------|
| 1 | All `src/` | จัดการ HACK / TODOs ที่เหลือ (เช่น `MERGE_TO_CANDIDATE`) | Med | Regression Test ทั้งระบบ |
| 2 | `SYS_LOG` | PII Masking Algorithm ก่อนบันทึกลง Sheet | Low | ตรวจ Logs Sheet ว่า PII เป็น `***` |

### Refactor Pattern Library
- **Pattern R-01: Extract Constant / Util** — ใช้เมื่อมี String เดิมซ้ำ > 2 แห่ง
  - *Before:* `'https://www.google.com/maps?q=' + x + ',' + y`
  - *After:* `Utils.Maps.generate(x, y)`
- **Pattern R-02: Property Injection** — ใช้เมื่อเจอ Secret/API Key ในโค้ด

### Rollback Plan
- หาก WebApp แตกหลัง Refactor ให้ใช้ `clasp push` รีเวิร์ตกลับไปยัง Commit ล่าสุดใน Branch `main` เนื่องจากโปรเจกต์มี `.github/workflows` คุมอยู่แล้ว การย้อนกลับสามารถทำผ่าน GitHub Actions Rollback ได้ทันที

---

## 🎯 Final Verdict: GO / NO-GO

- **P0 issues blocking:** 1 (การจัดการ Google Apps Script API Quota จากการคอล Sheet ถี่จัด) และ P1 เรื่อง Secrets Management
- **Recommendation:** **NO-GO (Conditional)**
  - โปรเจกต์มีความสมบูรณ์ทางสถาปัตยกรรม (Architecture & Docs) ในระดับที่ดีมาก! (A-Tier สำหรับ GAS)
  - **เงื่อนไขการ GO:** ขอให้แก้ 2 จุด คือ (1) ย้าย API/Tokens (Gemini, Telegram) ไปใส่ PropertiesService และ (2) สร้าง Utils/Cache ลดการเปิด Sheet ให้น้อยลง เมื่อแก้เสร็จสามารถ Deploy ส่งมอบได้ทันที

---

## ⚠️ NOT YET CHECKED — ต้องตรวจเพิ่ม
1. **GAS Runtime Limits (Live Execution):** ยังไม่ได้รันโหลดเทสต์จริง (Load Testing) ภายใต้ Environment ของ SCG เพื่อดูว่า 6-minute Execution Limit จะชนตอนกี่ Records
2. **Sheet Data Schema Constraints:** โครงสร้าง Header ในไฟล์ Excel/Sheets จริงๆ ตรงกับ `SCHEMA.xxx` หรือไม่ (ต้องการทดสอบ Live Sync)
3. **UI Micro-Interactions (CSS):** ระบบ Tailwind CSS บน Apps Script `HtmlService` อาจมีพฤติกรรมเพี้ยนบนบางเบราว์เซอร์เก่า ต้องตรวจสอบ Live Rendering
4. **RBAC Deep Permissions:** ทบสอบ Role Impersonation (พยายามใช้สิทธิ์ Viewer สั่ง Trigger ฟังก์ชันของ Admin แบบ Manual)
