<!-- DOC-TYPE: historical -->

# LMDS V6.0 — Final Audit Report (Aggregated)

**Repo:** https://github.com/Siriwat08/phaopanya-scg (main, version 6.0.077)
**Template:** audit-template-v5 (49 checks: 13 ST + 14 RT + 21 DM + DS-000 → 18 LMDS doc-sync)
**Date:** 2026-07-26
**Aggregator:** Agent 4 (per 04-aggregator/agent.md + aggregation-rules.md)

> หมายเหตุ: รัน 2 รอบ — (1) จาก zip ที่อัปโหลด (2) จาก git clone จริง
> ผล zip มี false positive เพิ่ม 2 กลุ่มจากการที่ unzip แปลงชื่อไฟล์ภาษาไทยเป็น `#U0e..`
> (ST-012 broken links + check_05 internal links) — **รายงานนี้ยึดผลจาก git clone จริง**

---

## 📊 Scoreboard

| Agent                               | Checks | Passed | Warn/Fail                                           |
| ----------------------------------- | ------ | ------ | --------------------------------------------------- |
| Agent 1 — Static                    | 13     | 9      | 4 (ST-002, ST-006, ST-008, ST-009)                  |
| Agent 2 — Runtime-GAS               | 14     | 9      | 5 (RT-001, RT-003, RT-004, RT-005, RT-011, RT-012*) |
| Agent 3 — Domain-Logic              | 21     | 21     | 0 (มี advisory ใน DM-014, DM-021)                   |
| Agent 5 — Doc-Sync (18 LMDS checks) | 18     | 15     | 1 fail-class†, advisory หลายรายการ                  |

*RT-012 = ❌ production readiness (access: MYSELF)
†check_17 = production readiness (ตัวเดียวกับ RT-012, dedup แล้ว)

---

## 🔴 Verdict: 🟢 GO (with conditions)

- **P0 (blocker): 0**
- **P1: 2** → `P0_count == 0 AND P1_count <= 5` → **🟢 GO**
- เงื่อนไข: P1 ทั้ง 2 ข้อควรปิดก่อน deploy production จริง

---

## Findings (deduplicated, prioritized)

### P1 — ควรแก้ก่อน production

**F-01 — Web App ยังไม่ production-ready (access: MYSELF)**

- Reported by: RT-012 (Agent 2) + check_17 (Doc-Sync) — STRONG (2 agents)
- Evidence: `appsscript.json` → `"access": "MYSELF"`, `"executeAs": "USER_DEPLOYING"`
- Impact: ผู้ใช้อื่นเข้า Web App ไม่ได้ — เป็น config สำหรับ dev/staging เท่านั้น
- Fix: เปลี่ยนเป็น `DOMAIN` (หรือ `ANYONE_WITH_GOOGLE_ACCOUNT` ตาม RBAC design) ตอน deploy จริง
- 🤔 หมายเหตุ: ถ้าตอนนี้ตั้งใจอยู่ใน staging → ยอมรับได้ แต่ต้องอยู่ใน release checklist

**F-02 — Master writes ไม่มี LockService 2 ไฟล์ (Law 16)**

- Reported by: RT-004 (Agent 2)
- Evidence:
  - `src/1_group1_master_db/05_NormalizeService.gs` — เขียน master แต่ไม่พบ LockService
  - `src/1_group1_master_db/10f_MatchAliasEnrichment.gs` — เขียน master แต่ไม่พบ LockService
- Impact: ถ้ามี concurrent execution → เสี่ยง race condition / data corruption บน master sheet
- Fix: ครอบ write ด้วย `acquireScriptLock_()` / try / finally / release
- 🤔 LIKELY_PARTIAL_FP: ถ้าไฟล์เหล่านี้ถูกเรียกจาก entry point ที่ถือ lock อยู่แล้ว (เช่น MatchEngine loop) → เพิ่ม comment marker ให้ checker เห็น หรือยืนยัน call path

### P2 — ควรวางแผนแก้

**F-03 — Long-running loops ไม่มี checkpoint/resume 14 ไฟล์ (Law 5) — RT-005**

- ไฟล์เด่น: 05_Normalize, 06_Person, 07_Place, 08_Geo, 09_Destination, 10_MatchEngine, 16_GeoDictBuilder, 11_Transaction, 12_Review, 24_PipelineManager ฯลฯ
- Impact: ถ้า execution ชน 6-min limit กลางคัน → ต้องเริ่มใหม่ทั้งหมด
- 🤔 บางไฟล์มี AutoResume กลไกกลาง (10h_MatchAutoResume มี Props 7 จุด) — heuristic ตรวจ per-file จึงอาจนับซ้ำ ควร manual review ว่าไฟล์ไหน cover แล้วจริง

**F-04 — Runtime CDN: `@tailwindcss/browser` 4 จุด (check_13 / ขัด Law no-runtime-CDN)**

- Web App โหลด Tailwind จาก CDN ตอน runtime → ถ้า CDN ล่ม UI พัง + supply-chain risk
- Fix: vendor CSS ที่ build แล้วเข้า `css/Styles.html`

**F-05 — Audit trail coverage 0% บน destructive functions (DM-021)**

- Destructive functions 15 ตัว, มี AuthZ guard 33% (ผ่านเกณฑ์ ≥30%) แต่ **ไม่มี audit trail เลย**
- ตัวอย่างไม่มี guard ตรง ๆ: `updatePersonStats`, `createPersonAlias`, `updatePlaceStats`, `createPlaceAlias`, `updateGeoStats`, `updateDestinationStats` (น่าจะเป็น internal ที่ถูกเรียกจาก guarded entry — ควรยืนยัน)
- Fix: เรียก `26_AuditTrailService` จาก destructive ops หลัก

### P3 — Style / Convention / Tech-debt

| #    | Check       | สรุป                                                                                                                                                                                                                   |
| ---- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F-06 | ST-002      | 19 ไฟล์ HTML ใน `3_group3_webapp` + `99_Legacy.gs` ไม่ตรง load-order naming (Law 14) — 🤔 LIKELY_FP บางส่วน: HTML views ไม่ใช่ .gs load-order; `99_` เกินช่วง 00-29 โดยตั้งใจ (legacy) → พิจารณา whitelist ใน template |
| F-07 | ST-006      | Magic column index 2 จุด: `03_SetupSheets.gs:525`, `14_Utils.gs:740` (getRange col=2 ตรง ๆ)                                                                                                                            |
| F-08 | ST-008      | ฟังก์ชันยาว >100 บรรทัด 36 ตัว (สูงสุด `runTestMatchDryRun_` 214 บรรทัด, `submitBulkReviewDecisions` 216) — refactor ทีละตัวตาม priority                                                                               |
| F-09 | ST-009      | Top-level `let` 13 จุด (RAM cache pattern: `_PERSON_NOTE_INVERTED_INDEX` ฯลฯ) — 🤔 เป็น intentional RAM-cache pattern ของ LMDS; ถ้ายอมรับ ควรเปลี่ยนเป็น lazy-init function หรือ whitelist                             |
| F-10 | RT-003      | `setupInputSheet_` (03_SetupSheets.gs:478) มี getValue/setValue ใน loop — ตรวจว่า batch ได้ไหม                                                                                                                         |
| F-11 | RT-011      | 7 ไฟล์มี API calls >5 (เด่น: 24_PipelineManager Props=14, 21_AliasService Cache=9) — review ลด quota                                                                                                                   |
| F-12 | DM-014      | OAuth scope กว้าง 1 ตัว (`auth/spreadsheets` เต็ม) — จำเป็นสำหรับเขียน master → ACCEPT พร้อมบันทึกเหตุผล                                                                                                               |
| F-13 | check_07/08 | `05_NormalizeService.gs` header: CHANGELOG ไม่มี version entry + ไม่มี `CALLED BY:` ใน DEPENDENCIES                                                                                                                    |
| F-14 | check_10    | Dead function: `MIGRATION_HybridAliasSystem` (0 callers) — migration เสร็จแล้ว → ย้ายไป 99_Legacy หรือลบ                                                                                                               |
| F-15 | check_15    | String ซ้ำ 16 ครั้ง: `'❌ ล้มเหลว: '` → ควรเป็น const                                                                                                                                                                  |

### 🤔 False Positives (ยืนยันแล้ว — ไม่ใช่ defect)

| Check                       | รายการ                                                              | เหตุผล                                                                                                                                  |
| --------------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| RT-001                      | `15_GoogleMapsAPI.gs:20`, `18_ServiceSCG.gs:22` "fetch without try" | บรรทัดที่ flag คือ **comment ใน file header** (`CALLS: UrlFetchApp.fetch()`) — fetch จริงทุกจุดอยู่ใน try-catch (ยืนยันโดย check_14 ✅) |
| ST-012 / check_05 (zip run) | broken Thai-named doc links                                         | เกิดจาก unzip mangle ชื่อไฟล์ไทยเป็น `#U0e..` — บน git clone จริง links resolve ครบ ✅                                                  |

### ✅ จุดแข็งที่ผ่านครบ

- **Domain-Logic 21/21** — Match Engine 8 rules + MERGE/CREATE/ESCALATE/IGNORE ครบ, Single-writer pattern, Hybrid Alias single-writer, RBAC deny-by-default, Invoice normalization, Thai prefix stripping, no secrets, PII masking, formula-injection safe, RFC 6265 cookie sanitization, no API key in URL, no fetch body leak
- Version consistency ทั้ง repo = **6.0.077** ✅
- GitHub Actions ทั้ง 9 workflows มี least-privilege permissions ✅
- Library version-pinned, trigger cleanup ถูกต้อง, batch getValues 112 จุด ✅
- Skills catalog 12 ตัว schema ครบ, DOC-TYPE coverage 107 ไฟล์ ✅

---

## 📋 Recommended action order

1. (ก่อน production) F-01: เปลี่ยน `access` ใน appsscript.json ตอน deploy จริง
2. (ก่อน production) F-02: ยืนยัน lock path ของ 05/10f — ถ้าไม่มีจริงให้เพิ่ม LockService
3. F-04: vendor Tailwind แทน CDN
4. F-05: ต่อ AuditTrailService เข้ากับ destructive ops
5. F-03: ยืนยัน AutoResume coverage รายไฟล์
6. P3 ทั้งหมด: จัดเป็น tech-debt backlog
