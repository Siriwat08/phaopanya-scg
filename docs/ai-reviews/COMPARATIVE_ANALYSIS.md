<!-- DOC-TYPE: living -->

# AI Reviews — Comparative Analysis & Task List

> **สรุปการวิเคราะห์เปรียบเทียบ** AI reviewers ที่ตรวจรีวิว LMDS V6.0 codebase
>
> **วันที่สร้าง:** 2026-07-15 | **อัปเดตล่าสุด:** 2026-07-23 (รอบ 6 — 4 audit reports ใหม่ + Dependabot dismissed)
> **เวอร์ชันที่ตรวจ:** รอบ 1: V6.0.046–V6.0.051 | รอบ 2: V6.0.062 | รอบ 3: V6.0.066 | รอบ 4: V6.0.070 | รอบ 5: V6.0.071 → แก้ครบใน V6.0.072 | รอบ 6: V6.0.072 → แก้ใน V6.0.073

---

## 1. ภาพรวม AI 3 ท่าน

| มิติ                      | Reviewer 1                                          | Reviewer 2                                       | Reviewer 3                                |
| ------------------------- | --------------------------------------------------- | ------------------------------------------------ | ----------------------------------------- |
| **บทบาท**                 | Refactor Partner                                    | Architect Consultant                             | Pre-Delivery Auditor                      |
| **จำนวนไฟล์**             | 8 (.md)                                             | 6 (1 .md + 5 .html)                              | 1 (.md) + 5 .zip                          |
| **วิธีการ**               | Top-down + evidence-driven (call-graph)             | Architecture-first + visual dashboards           | Checklist + CI verification               |
| **เครื่องมือ**            | grep, diff, node --check, wc -l                     | Chart.js, SVG, radar scorecard                   | 9 check scripts, npm audit, ESLint        |
| **ขอบเขต**                | 10_MatchEngine.gs decomposition + 5-Layer Safeguard | Full-stack architecture + security + tech debt   | Production readiness assessment           |
| **รูปแบบผลลัพธ์**         | Code diffs + implementation files                   | Executive dashboards + roadmap                   | Pass/Fail table + quick wins              |
| **จุดเด่น**               | Zero-Hallucination discipline, self-correction      | 4-sprint Strangler Fig roadmap, Defense-in-Depth | 92% readiness score, actionable checklist |
| **จำนวน recommendations** | 11                                                  | 22                                               | 12                                        |

---

## 2. เปรียบเทียบวิธีการวิเคราะห์ (Methodology Comparison)

### Reviewer 1 — "Refactor Partner"

**วิธี:** Call-graph based decomposition + evidence-driven

**จุดเด่น:**

- ✅ ตรวจสอบ caller ทุก function ก่อนแนะนำการย้าย (`grep` ทั้ง repo)
- ✅ Diff byte-exact ทุกครั้งที่ย้ายโค้ด
- ✅ `node --check` syntax verification ทุกไฟล์ใหม่
- ✅ **Zero-Hallucination Policy** — ถ้าพูดผิด จะแก้ตัวเองสาธารณะ (เกิดขึ้น 2 ครั้งในเอกสาร)
- ✅ รายงานผลแบบตรงไปตรงมา ถ้าไม่ถึงเป้า จะบอกว่าไม่ถึง

**จุดอ่อน:**

- ⚠️ โฟกัสแค่ `10_MatchEngine.gs` — ไม่ได้ดูภาพรวม architecture
- ⚠️ ไม่มี visualizations — อ่านยากสำหรับ stakeholder ที่ไม่ใช่ developer

### Reviewer 2 — "Architect Consultant"

**วิธี:** Architecture-first + Q&A-direct + visual report-heavy

**จุดเด่น:**

- ✅ สร้าง **8-stage data-flow map** ที่อธิบาย "ข้อมูลไปไหน" ได้ชัดเจน
- ✅ แยกการประเมินเป็น 2 แกน: operational (✅) vs data-engineering (⚠️)
- ✅ **5 HTML dashboards** (radar, SVG architecture, sprint roadmap, defense-in-depth, debt bar chart)
- ✅ ตั้งชื่อ design patterns ชัดเจน (Strangler Fig, Defense-in-Depth, Single Writer, type-brand)
- ✅ 4-sprint roadmap พร้อม risk level + success criteria ที่วัดได้
- ✅ ทุก claim มี source link ไป GitHub raw file

**จุดอ่อน:**

- ⚠️ ไม่มี line-level bug reports — เป็นการวิเคราะห์ระดับสูงเกินไปสำหรับการแก้ปัญหาเฉพาะจุด
- ⚠️ การ migrate ไป Cloud Run/PostgreSQL เป็น proposal ใหญ่ที่อาจไม่จำเป็นสำหรับทีมเล็ก

### Reviewer 3 — "Pre-Delivery Auditor"

**วิธี:** Checklist-based + CI verification

**จุดเด่น:**

- ✅ รัน check scripts ทั้ง 9 ตัวของโปรเจกต์เอง — เคารพ infrastructure ที่มีอยู่
- ✅ ให้คะแนน readiness แบบตัวเลข (92% GO แบบมีเงื่อนไข)
- ✅ แยกปัญหาเป็น 🔴 สูง / 🟡 กลาง / 🟢 ต่ำ — จัดลำดับการแก้ไขได้ง่าย
- ✅ แยก "ต้องแก้ในโค้ด" vs "ต้องตั้งใน environment" — ปฏิบัติได้จริง
- ✅ เสนอ Quick Wins ที่ทำได้ใน 1-2 ชม.

**จุดอ่อน:**

- ⚠️ ไม่ได้วิเคราะห์ architecture หรือ tech debt เชิงลึก
- ⚠️ บางข้อ (เช่น V5.5 branding, CHANGELOG sync) แก้ไขแล้วใน PR #134

---

## 3. ทำไมเราถึงพลาดบางข้อ? (Why We Missed Things)

### สิ่งที่ AI ทั้ง 3 ท่านพบ แต่เราพลาด:

| ข้อพลาด                                                                                                                      | ใครพบ          | สาเหตุที่พลาด                                                                    | สถานะปัจจุบัน                          |
| ---------------------------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------- | -------------------------------------- |
| lmds-supreme-engineer skill หายไปใน PR #133 (empty commit)                                                                   | ผมเองพบตอนตรวจ | เชื่อ PR title โดยไม่ verify ไฟล์จริง                                            | ✅ กู้คืนแล้ว (PR #139)                |
| `resetAliasEnrichmentContext_()` wrapper ถูกสร้างใน 10f แต่ 3 call sites ใน 10 ยังใช้ raw `_ALIAS_ENRICHMENT_CONTEXT = null` | Reviewer 1     | ผมสร้าง wrapper แต่ไม่ได้ update call sites                                      | ⚠️ ยังไม่ได้แก้                        |
| `console.log` 7 จุด "ควรเปลี่ยนเป็น logDebug"                                                                                | Reviewer 3     | ผมตรวจแล้วพบว่าเป็น false positive — ทั้ง 5 จุดจริงอยู่ใน logging infrastructure | ✅ ไม่ต้องแก้ (วิเคราะห์ถูก)           |
| Version bump ต้องทำทุกที่พร้อมกัน (check_01)                                                                                 | Reviewer 3     | ผม bump แค่ในไฟล์เดียว ทำให้ PR #136 ล้มเหลว                                     | ✅ แก้แล้ว + บันทึกเป็น lesson learned |
| 5-Layer Alias Safeguard ไม่เคยถูก implement                                                                                  | Reviewer 1     | ผมบันทึกไว้ใน memory แต่ไม่ได้สร้าง task tracking                                | 🔜 อยู่ใน task list ด้านล่าง           |
| `STG_CLEANED` / `CLEAN_AUDIT` middle layer                                                                                   | Reviewer 2     | ไม่เคยอยู่ใน scope ของ PR 2-4 (เป็น architectural change ใหญ่)                   | 🔜 อยู่ใน task list                    |
| Rate limiting (Security Layer 4) ขาดหายไป                                                                                    | Reviewer 2     | ไม่เคยอยู่ใน scope                                                               | 🔜 อยู่ใน task list                    |

### บทเรียนสำหรับการทำงานครั้งต่อไป:

1. **Verify ไม่ใช่ Trust** — หลัง merge PR ต้องตรวจว่าไฟล์จริงเข้าไปหรือไม่ ไม่ใช่แค่เช็ค CI เขียว
2. **Task Tracking** — ข้อเสนอที่ยังไม่ได้ทำ ต้องสร้าง issue/task ทันที อย่าเก็บไว้ใน memory
3. **Scope Discipline** — แยก refactor จาก feature อย่างชัดเจน อย่าผสมใน PR เดียว
4. **Cross-Reference** — เมื่อ AI หลายท่านแนะนำสิ่งเดียวกัน ให้รวมเป็น high-priority task

---

## 4. สิ่งที่ทำไปแล้ว (Implemented from AI Reviews)

| PR      | Version  | ที่มา                                               | สถานะ                                                                              |
| ------- | -------- | --------------------------------------------------- | ---------------------------------------------------------------------------------- |
| PR #136 | V6.0.049 | Reviewer 1 (dead code) + Reviewer 2 (TD-04)         | ✅ Merged — ลบ `matchCalcFullScore_` + `matchCalcGeoAnchorScore_`                  |
| PR #137 | V6.0.050 | Reviewer 1 (10f/10g/10h split) + Reviewer 2 (TD-01) | ✅ Merged — แตก `10_MatchEngine.gs` 2234→904 บรรทัด                                |
| PR #138 | V6.0.051 | Reviewer 1 (scoring to 10b)                         | ✅ Merged — ย้าย scoring functions ไป 10b                                          |
| PR #134 | V6.0.048 | Reviewer 3 (Quick Wins 1-5)                         | ✅ Merged — V5.5→V6.0 branding + CHANGELOG + README + .gitignore + Jest/Playwright |
| PR #139 | —        | Reviewer 1 (lmds-supreme-engineer)                  | ✅ Merged — สร้าง placeholder folder                                               |
| PR #140 | —        | —                                                   | ✅ Merged — สร้าง ai-reviews folder structure                                      |

---

## 5. Task List — สิ่งที่ยังไม่ได้ทำ (Unimplemented Recommendations)

### 🔴 ความสำคัญสูง (Critical/High)

| #   | Task                                                      | ที่มา              | ประเภท                     | ความยาก                              |
| --- | --------------------------------------------------------- | ------------------ | -------------------------- | ------------------------------------ |
| 1   | **5-Layer Alias Safeguard (21b_AliasSafeguard.gs)**       | Reviewer 1         | New feature                | ใหญ่ (840 บรรทัด + schema migration) |
| 2   | **STG_CLEANED / CLEAN_AUDIT middle layer**                | Reviewer 2         | New feature / architecture | ใหญ่ (reviewer's #1 proposal)        |
| 3   | **Rate Limiting (Security Layer 4, Protocol C)**          | Reviewer 2         | New feature                | ปานกลาง (CacheService, 30/min)       |
| 4   | **Input Validation layer (Security Layer 5, Protocol A)** | Reviewer 2         | Refactor + security        | ปานกลาง (type-brand safeHtml_)       |
| 5   | **Unit test framework (GasT / QUnitGS2, >30% baseline)**  | Reviewer 2 (TD-11) | New feature / process      | ปานกลาง                              |
| 6   | **Split 21_AliasService.gs (1,771 LOC → 4 modules)**      | Reviewer 2 (TD-02) | Refactor                   | ใหญ่ (Sprint 4)                      |

### 🟡 ความสำคัญปานกลาง (Medium)

| #   | Task                                                   | ที่มา               | ประเภท                | ความยาก                          |
| --- | ------------------------------------------------------ | ------------------- | --------------------- | -------------------------------- |
| 7   | **Update `resetAliasEnrichmentContext_()` call sites** | Reviewer 1          | Refactor (defensive)  | เล็ก (3 จุดใน 10_MatchEngine.gs) |
| 8   | **Version bump helper script**                         | Lesson from PR #136 | Process improvement   | เล็ก                             |
| 9   | **Make `runNormalize()` real or remove placeholder**   | Reviewer 2          | Refactor (honesty)    | ปานกลาง                          |
| 10  | **Persist `SYS_NOTES` on all code paths**              | Reviewer 2          | Bug fix / refactor    | ปานกลาง                          |
| 11  | **Audit trail expansion (Protocol D + G)**             | Reviewer 2          | Refactor + process    | ปานกลาง                          |
| 12  | **Tighten ESLint (lines 300→100, complexity 30→15)**   | Reviewer 2 (TD-05)  | Policy                | เล็ก                             |
| 13  | **Replace `typeof===function` soft deps**              | Reviewer 2 (TD-06)  | Refactor              | ปานกลาง                          |
| 14  | **`safeHtml_` type-brand for innerHTML**               | Reviewer 2 (TD-07)  | Refactor + security   | ปานกลาง                          |
| 15  | **Gold dataset + 4-metric benchmark**                  | Reviewer 2          | New feature / process | ใหญ่                             |

### 🟢 ความสำคัญต่ำ (Low)

| #   | Task                                                           | ที่มา              | ประเภท        | ความยาก |
| --- | -------------------------------------------------------------- | ------------------ | ------------- | ------- |
| 16  | **Rename misleading vars in `buildSourceObj_()`**              | Reviewer 2         | Refactor      | เล็ก    |
| 17  | **Unify `normalized_name` semantics**                          | Reviewer 2         | Refactor      | เล็ก    |
| 18  | **Clean up orphaned section headers**                          | Reviewer 1         | Process       | เล็ก    |
| 19  | **`PIPELINE_STOP_KEY` constant usage** (instead of raw string) | Reviewer 1         | Refactor      | เล็ก    |
| 20  | **Comment archaeology cleanup**                                | Reviewer 2 (TD-08) | Refactor      | เล็ก    |
| 21  | **Git tag release** (latest tag v6.0.9, should be v6.0.51)     | Reviewer 3         | Process       | เล็ก    |
| 22  | **Document `XFrameOptionsMode.ALLOWALL` risk in SECURITY.md**  | Reviewer 3         | Documentation | เล็ก    |

---

## 6. ข้อเสนอแนะลำดับถัดไป (Recommended Next Steps)

### Phase A: Quick Wins (1-2 ชม. each)

1. Task #7 — Update `resetAliasEnrichmentContext_()` call sites (3 จุด)
2. Task #8 — Version bump helper script
3. Task #12 — Tighten ESLint thresholds
4. Task #21 — Git tag v6.0.51

### Phase B: Security Hardening (1-2 วัน)

5. Task #3 — Rate Limiting (Protocol C)
6. Task #4 — Input Validation layer (Protocol A)
7. Task #11 — Audit trail expansion (Protocol D + G)

### Phase C: Test Infrastructure (2-3 วัน)

8. Task #5 — Unit test framework (GasT / QUnitGS2)
9. Task #15 — Gold dataset + benchmark

### Phase D: Architecture (1-2 สัปดาห์)

10. Task #1 — 5-Layer Alias Safeguard (shadow-mode rollout)
11. Task #2 — STG_CLEANED / CLEAN_AUDIT layer
12. Task #6 — Split 21_AliasService.gs

---

## 7. Quotes ที่น่าจดจำ

### Reviewer 1 (Refactor Partner)

> _"จัดกลุ่มตามหลักฐานการเรียกใช้จริง ไม่ใช่แค่กะขนาดบรรทัด"_

> _"ผมเข้าใจผิดเองตอนสรุปรอบก่อนโดยไม่ได้เปิดไฟล์ 10b ดูจริง ขอโทษด้วยครับ"_ (Zero-Hallucination discipline)

### Reviewer 2 (Architect Consultant)

> _"ระบบนี้ไม่ผิดทิศ แต่ตอนนี้มันเป็น matching system ที่มี cleaning logic ฝังอยู่ข้างใน ยังไม่ใช่ clean-data platform ที่ตรวจสอบผลลัพธ์ได้ชัดเจน"_

> _"ถ้าจะเริ่มย้ายจริง ผมจะย้าย MatchEngine + NormalizeService + Alias learning ออกก่อน เพราะ 3 ส่วนนี้คือสมองของระบบ"_

### Reviewer 3 (Pre-Delivery Auditor)

> _"พร้อมส่งมอบ ~92% — GO แบบมีเงื่อนไข"_

> _"สิ่งที่ต้องทำก่อนส่งมอบจริง (Quick Wins ~1-2 ชม.): sync เอกสาร, เติม CHANGELOG, แก้ V5.5 → V6.0, ยืนยัน access, ลบ Jest/Playwright"_

---

## 8. ไฟล์ต้นฉบับ (Source Files)

| Reviewer           | โฟลเดอร์         | ไฟล์                                                    |
| ------------------ | ---------------- | ------------------------------------------------------- |
| Reviewer 1 (รอบ 1) | `ai-reviewer-1/` | 8 .md files (code review series) — **DELETED V6.0.062** |
| Reviewer 2 (รอบ 1) | `ai-reviewer-2/` | 1 .md + 5 .html — **DELETED V6.0.062**                  |
| Reviewer 3 (รอบ 1) | `ai-reviewer-3/` | 1 .md + 5 .zip — **DELETED V6.0.062**                   |
| Reviewer 4 (รอบ 1) | `ai-reviewer-4/` | 1 .md (audit report) — **DELETED V6.0.062**             |

### รอบ 2 — ไฟล์ใหม่ (V6.0.062)

| Reviewer           | โฟลเดอร์         | ไฟล์                                                                           | ขนาด  |
| ------------------ | ---------------- | ------------------------------------------------------------------------------ | ----- |
| Reviewer 1 (kamon) | `ai-reviewer-1/` | LMDS_V6.0_PreDelivery_Audit_Reportkamon.docx                                   | 32KB  |
| Reviewer 2         | `ai-reviewer-2/` | LMDS_V6.0_PreDelivery_Audit_Report.md                                          | 46KB  |
| Reviewer 3         | `ai-reviewer-3/` | 4 JSON: AUD1 Code Quality + AUD2 Architecture + AUD3 Security + AUD4 Technical | 143KB |

**หมายเหตุ:** ไฟล์ต้นฉบับรอบ 1 ถูกลบแล้ว (V6.0.062) — ข้อมูลสำคัญสกัดไว้ในเอกสารนี้ + AI-REVIEW-PROTOCOL.md + TODO.md

---

## 9. รอบ 2 — สรุปการวิเคราะห์ AI 3 ท่านใหม่ (V6.0.062)

### ภาพรวม

| Reviewer        | ไฟล์            | คะแนน       | Findings | จุดเด่น                                                            |
| --------------- | --------------- | ----------- | -------- | ------------------------------------------------------------------ |
| **#1 (kamon)**  | .docx (32KB)    | 87/100 (B+) | ~32      | รอบด้าน — code + security + docs + 4-sprint roadmap                |
| **#2**          | .md (46KB)      | 84/100 (B+) | ~22      | ละเอียด file:line + STRIDE threat model + SEC-001→012 + 6 new      |
| **#3 (4 JSON)** | 4 .json (143KB) | 78+67/100   | ~74      | เข้มข้นสุด — แยก 4 audits (Code/Arch/Security/Tech) + SSTI finding |

### P0 — 3 ท่านยืนยันตรงกัน (Block deploy)

| #    | ปัญหา                                                               | ที่ไหน                        | ใครพบ                              | สถานะ             |
| ---- | ------------------------------------------------------------------- | ----------------------------- | ---------------------------------- | ----------------- |
| P0-1 | **SSTI in Index.html** — `<?= currentUser.name/email ?>` ไม่ escape | `Index.html:74-75`            | Reviewer #3 (AUD3-NEW-001/002)     | ❌ แก้ใน V6.0.063 |
| P0-2 | **Missing LockService** บน createPerson/Place/GeoPoint              | `06:595, 07:732, 08:227`      | Reviewer #3 (AUD2-ATD-009/010/011) | ❌ แก้ใน V6.0.063 |
| P0-3 | **Missing AuthZ** บน destructive ops (create/merge)                 | `06, 07, 08, 09`              | Reviewer #3 (AUD3-SEC-002 FAIL)    | ❌ แก้ใน V6.0.063 |
| P0-4 | **Group 2 writes FACT_DELIVERY directly**                           | `12_ReviewService.gs:266-282` | Reviewer #3 (AUD2-ATD-001)         | 🔜 ทำภายหลัง      |

### P1 — ควรทำเร็วๆ นี้

| #    | ปัญหา                                                                                | ที่ไหน                    | ใครพบ             |
| ---- | ------------------------------------------------------------------------------------ | ------------------------- | ----------------- |
| P1-1 | XSS in 5 WebApp components (ChartCard, DataTable, StatCard, App toast, MapAnalytics) | 5 .html files             | #2 + #3           |
| P1-2 | 21_AliasService.gs 1796 lines (God file)                                             | `21_AliasService.gs`      | #1 + #2 + #3      |
| P1-3 | PII leak — raw phone ใน log                                                          | `06_PersonService.gs:489` | #3 (AUD3-NEW-013) |
| P1-4 | Documentation drift — README/BLUEPRINT ค้าง V6.0.044-048                             | 6 docs                    | #3 (AUD4)         |
| P1-5 | Formula injection — user input สู่ Sheets ไม่เช็ค `=+-@`                             | ทั่วโปรเจกต์              | #3 (AUD3-NEW-012) |

### สิ่งที่ทำไปแล้ว (ยืนยันโดย 3 ท่าน)

- ✅ Dead code cleanup (V6.0.049)
- ✅ 10f/10g/10h split (V6.0.050)
- ✅ Scoring → 10b (V6.0.051)
- ✅ 5-Layer Safeguard Layer 1+5 (V6.0.058)
- ✅ validateInput_() (V6.0.055)
- ✅ ESLint 200 (V6.0.057)
- ✅ Telegram retry (V6.0.057)
- ✅ SECURITY.md (V6.0.054)
- ✅ 8 CI checks (V6.0.060)
- ✅ SEC-001→012 all PASS (12/12 = 100%)

### ความเห็นของเรา — ทำอะไรต่อ

**ทำทันที (P0 — V6.0.063):**

1. SSTI fix — เปลี่ยน `<?= ?>` เป็น escaped output
2. LockService guards — createPerson/Place/GeoPoint
3. AuthZ guards — destructive ops

**ทำในสัปดาห์นี้ (P1):** 4. XSS escape ใน 5 components 5. PII masking — mask phone 6. Docs sync — อัปเดตเป็น V6.0.062

**เก็บไว้ทีหลัง (P2 — รอเงื่อนไข):** 7. Split 21_AliasService.gs — cohesion สูง รอเจอปัญหาจริง 8. Split 05_NormalizeService.gs — เหมือนกัน 9. Formula injection sanitizer — low priority

---

## 10. รอบ 3 — สรุป AI Reviewers ใหม่ (V6.0.066)

### ภาพรวม

| Reviewer | ไฟล์                                         | คะแนน       | Findings       | จุดเด่น                                              |
| -------- | -------------------------------------------- | ----------- | -------------- | ---------------------------------------------------- |
| **#1**   | LMDS_V6_Audit_Report.md (47KB)               | 86/100 (B+) | 15 TDs + 3 SEC | STRIDE + รอบด้าน — พบ PII email ใน log               |
| **#2**   | LMDS_V6.0_PreDelivery_Audit_Report.md (43KB) | 74/100 (B)  | 15 TDs + 6 SEC | เข้มข้น — พบ cookie regression + lock double-release |

### P0 — 2 ท่านยืนยันตรงกัน (Block deploy)

| #    | ปัญหา                                                        | ที่ไหน                     | ใครพบ       | สถานะ             |
| ---- | ------------------------------------------------------------ | -------------------------- | ----------- | ----------------- |
| P0-1 | **PII email ใน log** — `logInfo` เก็บ email ดิบ              | `22_WebApp.gs:140, 220`    | ทั้ง 2 ท่าน | ❌ แก้ใน V6.0.067 |
| P0-2 | **SCG Cookie อ่าน B1 เป็น primary**                          | `18_ServiceSCG.gs:329-339` | Reviewer #2 | ❌ แก้ใน V6.0.067 |
| P0-3 | **XSS ใน LiveFeed.html:72** — `JSON.stringify(m)` ไม่ escape | `LiveFeed.html:72`         | Reviewer #2 | ❌ แก้ใน V6.0.067 |
| P0-4 | **Lock double-release** — `lock.releaseLock()` เดิม          | `00_App.gs:303`            | Reviewer #2 | ❌ แก้ใน V6.0.067 |

### P1 — ควรแก้เร็วๆ นี้

| #    | ปัญหา                                           | ที่ไหน                 | ใครพบ       |
| ---- | ----------------------------------------------- | ---------------------- | ----------- |
| P1-1 | Auth fail-open — `return true` ตอน no whitelist | `22_WebApp.gs:184-186` | Reviewer #2 |
| P1-2 | TODO.md stale — version ค้าง V6.0.058           | `docs/TODO.md`         | Reviewer #1 |
| P1-3 | BLUEPRINT.md stale + SEC-004 overstate          | `BLUEPRINT.md`         | Reviewer #1 |
| P1-4 | check_10-18 ไม่ได้ wire ใน workflow             | `07-doc-code-sync.yml` | Reviewer #1 |

### สิ่งที่เราเรียนรู้ (ใส่ใน logic)

1. **PII masking ต้องครบทุก type** — เรา mask phone แต่ลืม email
2. **XSS escape ต้อง grep หาครบทุกจุด** — เราทำ 6 จุดแต่พลาดจุดที่ 7 (LiveFeed:72)
3. **Helper ต้องใช้ทุกที่** — มี `releaseScriptLock_()` แต่ไม่ได้ใช้ที่ `00_App.gs:303`
4. **Cookie fix ถูก revert** — V6.0.036 เคยแก้แต่ถูก revert — check_06 ต้องครอบ cookie path

---

## 11. รอบ 4 — สรุปการตรวจสอบ V6.0.070 (2026-07-21)

### ภาพรวม

| รายงาน                          | ขอบเขต                                           | จำนวน claims | ผล verification                     |
| ------------------------------- | ------------------------------------------------ | ------------ | ----------------------------------- |
| **รายงานที่ 1 — 5-Phase Audit** | Tech debt + Code review + SEC + Style + Refactor | ~90          | 48% จริง / 29% ไม่แม่นยำ / 20% หลอน |
| **รายงานที่ 2 — Static Audit**  | 9 issues (file:line specific)                    | 9            | 6 จริง / 2 แก้บางส่วน / 1 หลอน      |

> **หมายเหตุสำคัญ:** การตรวจสอบทำตาม `AI-REVIEW-PROTOCOL.md` 5 กฎ — ตรวจสอบไฟล์จริงใน V6.0.070 ก่อนเชื่อ claim ใดๆ หลายข้อที่ AI "พบ" ถูกแก้ไปแล้วใน PR #186 (V6.0.070)

### รายงานที่ 1 — 5-Phase Audit (สรุปย่อ)

| Phase   | ขอบเขต                             | ผล verification                                                                                       |
| ------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Phase 1 | 35 technical debt items            | P0:1 (PipelineManager lock — จริง) / P1:7 (3 จริง, 2 แก้แล้ว, 2 หลอน) / P2:27 (ส่วนใหญ่เป็น cosmetic) |
| Phase 2 | 18 code review suggestions         | 8 จริง / 5 แก้แล้ว / 5 หลอน                                                                           |
| Phase 3 | SEC-001→012 audit + 12 new         | 8 PASS ✅ / 4 WARN (อธิบายได้) / 12 new: 4 จริง, 8 หลอน                                               |
| Phase 4 | Coding style 82/100 (B grade)      | ส่วนใหญ่เป็น subjective — ใช้ AI-REVIEW-PROTOCOL กฎ 4 (context-aware) ปฏิเสธ                          |
| Phase 5 | 28 refactor items across 4 sprints | 14 จริง (ส่วนใหญ่อยู่ใน Group D แล้ว) / 14 หลอนหรือซ้ำกับที่มี                                        |

### รายงานที่ 2 — Static Code Audit (9 issues — ตรวจทุกข้อกับโค้ด V6.0.070)

| Issue     | คำกล่าวหา                                           | ไฟล์:บรรทัด (อ้าง)         | สถานะใน V6.0.070               | การพิสูจน์                                                          |
| --------- | --------------------------------------------------- | -------------------------- | ------------------------------ | ------------------------------------------------------------------- |
| ISSUE-001 | PipelineManager ใช้ bare `lock.releaseLock()`       | `24:759`                   | ❌ **จริง** — ยังไม่ได้แก้     | grep ยืนยัน line 759 ยังเป็น `lock.releaseLock();` ใน finally block |
| ISSUE-002 | searchLocations log rawQuery เป็น PII               | `22c:697`                  | ❌ **จริง** — ยังไม่ได้แก้     | logInfo('WebApp', 'searchLocations("' + rawQuery + '")...') ยังอยู่ |
| ISSUE-003 | submitReviewDecision log email ดิบ                  | `22c:257`                  | ❌ **จริง** — ยังไม่ได้แก้     | logInfo(... 'โดย ' + getCurrentDashboardUser_().email) ยังอยู่      |
| ISSUE-004 | isCurrentUserAdmin_ ไม่มีใน repo                    | (อ้างหลายไฟล์)             | ✅ **แก้บางส่วนแล้ว**          | V6.0.070 PR #186 ลบ dead reference แล้ว แต่ยังมีบางจุดเก่า          |
| ISSUE-005 | getDriverHistory_ ไม่ cache                         | (อ้าง)                     | ⚠️ **จริง — แต่ low priority** | ใช้ loadAllPlaces_ pattern ไม่ได้ใช้ cache                          |
| ISSUE-006 | Audit trail ใช้ N×appendRow                         | (อ้าง)                     | ⚠️ **จริง — แต่ low priority** | ใช้ batch setValues ในจุดหลัก แต่ edge case ยัง appendRow           |
| ISSUE-007 | recordAuditTrail vs logAuditTrail doc mismatch      | (อ้าง docs)                | ✅ **จริง — แต่เล็กน้อย**      | doc อ้างผิด แต่ function ใช้งานได้ปกติ                              |
| ISSUE-008 | getSheetByNameSafe_ ถูกอ้าง แต่ไม่มี definition     | (อ้าง 9 ไฟล์)              | ❌ **หลอน** — มีจริง           | grep ยืนยันว่ามี definition ใน 03_SetupSheets.gs                    |
| ISSUE-009 | GOOGLEMAPS_REVERSEGEOCODE/DIRECTIONS เป็น dead code | (อ้าง 15_GoogleMapsAPI.gs) | ⚠️ **จริง — defer**            | ใช้ในอนาคตเมื่อเปิดใช้ Google Maps API                              |

### P2-R4 — งานที่ต้องทำจากรอบ 4

| #        | งาน                                                                            | Priority | สถานะ       |
| -------- | ------------------------------------------------------------------------------ | -------- | ----------- |
| P2-R4-1  | **PipelineManager: เปลี่ยน `lock.releaseLock()` → `releaseScriptLock_(lock)`** | P1       | 🔜 V6.0.071 |
| P2-R4-2  | **searchLocations: mask rawQuery ใน logInfo**                                  | P1       | 🔜 V6.0.071 |
| P2-R4-3  | **submitReviewDecision: mask email ด้วย `maskEmailSafe_()`**                   | P1       | 🔜 V6.0.071 |
| P2-R4-4  | M_PLACE.normalized_name ใช้ `normalizeForCompare()` (เหมือน M_PERSON)          | P2       | 🔜 รอบถัดไป |
| P2-R4-5  | M_PLACE.normalized_reverse_geocode ใช้ `normalizeForCompare()`                 | P2       | 🔜 รอบถัดไป |
| P2-R4-6  | Menu "🔧 ระบบ & ตั้งค่า" split เป็น sub-menus (30+ รายการ)                     | P2       | 🔜 รอบถัดไป |
| P2-R4-7  | ISSUE-005: getDriverHistory_ cache                                             | P3       | 🔜 Group D  |
| P2-R4-8  | ISSUE-006: Audit trail N×appendRow                                             | P3       | 🔜 Group D  |
| P2-R4-9  | ISSUE-007: recordAuditTrail doc fix                                            | P3       | 🔜 Cosmetic |
| P2-R4-10 | ISSUE-009: GOOGLEMAPS_REVERSEGEOCODE dead code                                 | P3       | 🔜 Group D  |

### สิ่งที่เราเรียนรู้เพิ่ม (รอบ 4)

1. **AI ยังหลอนเรื่อง function existence** — ISSUE-008 อ้างว่าไม่มี `getSheetByNameSafe_` แต่ grep ยืนยันมีจริงใน 03_SetupSheets.gs
2. **AI ไม่เช็ค version ล่าสุด** — หลายข้อใน Phase 1-2 ถูกแก้ไปแล้วใน V6.0.063-070 แต่ AI ตรวจบน V6.0.066
3. **Static Audit แม่นยำกว่า 5-Phase Audit** — Issue 9 ข้อมี 6 จริง (67%) เทียบกับ 5-phase 48%
4. **Helper ใช้ไม่ครบทุกที่** — `releaseScriptLock_()` มีตั้งแต่ V6.0.067 แต่ PipelineManager ยังใช้ bare `lock.releaseLock()` — ต้อง grep ทุก `.releaseLock()` เพื่อหาจุดที่พลาด

---

## 12. รอบ 5 — สรุปการตรวจสอบ V6.0.071 (2026-07-22)

### ภาพรวม

หลัง V6.0.071 merged (PR #189), ผู้ใช้ส่งรายงาน AI audit **3 ฉบับใหม่** เข้ามาตรวจสอบ:

| รายงาน                                      | ขอบเขต                                                                   | จำนวน claims | ผล verification                          |
| ------------------------------------------- | ------------------------------------------------------------------------ | ------------ | ---------------------------------------- |
| **รายงานที่ 1 — Principal Auditor**         | Tech debt (20) + Code review (10 tips) + SEC + Style (84/100) + Refactor | ~90          | ตรวจทุก claim กับโค้ด V6.0.071 จริง      |
| **รายงานที่ 2 — Static Code Audit**         | 9 issues (file:line specific) — H-1, H-2, M-1, M-2, M-3, L-1~4           | 9            | 6 จริง / 1 แก้แล้ว / 2 หลอนหรือไม่แม่นยำ |
| **รายงานที่ 3 — AUD-4 Documentation Audit** | Doc version sync (17 issues — P0:3, P1:10, P2:4)                         | 17           | เกือบทั้งหมดจริง — แต่ความรุนแรงเกินไป   |

### รายงานที่ 1 — Principal Auditor (V6.0.071) — สรุปย่อ

| Phase              | ผล verification                                                                                                               |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| Phase 1 (TD)       | 20 items: P0:2 (TD-016 AuthZ fail-open + TD-017 webapp.access), P1:4 (TD-010 menu + TD-011 audit + TD-014/015 M_PLACE), P2:14 |
| Phase 2 (Tips)     | 10 tips — TD-016 P0 สำคัญที่สุด (AuthZ fail-open pattern)                                                                     |
| Phase 3 (SEC)      | SEC-001→012 ทั้ง 12 PASS ✅ + 4 new findings (N-001 webapp.access, N-002 fail-open, N-003 innerHTML, N-004 LMDS_ADMINS)       |
| Phase 4 (Style)    | 84/100 (B+) — สมเหตุสมผล                                                                                                      |
| Phase 5 (Refactor) | Sprint 0-3 — ส่วนใหญ่อยู่ใน Group D แล้ว (21_AliasService, 05_NormalizeService split)                                         |

### รายงานที่ 2 — Static Code Audit (V6.0.071) — 9 issues ตรวจทุกข้อ

| Issue | คำกล่าวหา                                                | ไฟล์:บรรทัด             | สถานะใน V6.0.071           | การพิสูจน์                                                                   |
| ----- | -------------------------------------------------------- | ----------------------- | -------------------------- | ---------------------------------------------------------------------------- |
| H-1   | `getDriverHistory_` ไม่มี cache (O(N²) risk)             | `10:810`                | ⚠️ **จริง — แต่ low risk** | เรียกจาก tie-break path เท่านั้น ไม่ใช่ main loop → P3 (Group D)             |
| H-2   | `getMatchEngineLiveStatus` JSON.parse ไม่มี try-catch    | `22c:916`               | ❌ **จริง** — ต้องแก้      | `JSON.parse(props.getProperty('MATCH_ENGINE_RECENT') \|\| '[]')` ไม่มี guard |
| M-1   | doc drift `recordAuditTrail` ≠ `logAuditTrail`           | (3 doc comments)        | ✅ จริง — เล็กน้อย         | cosmetic doc fix                                                             |
| M-2   | `12b_ReviewReprocessor.gs:90` bare `lock.releaseLock()`  | `12b:90`                | ❌ **จริง** — ต้องแก้      | เหมือนที่ PipelineManager แก้ใน V6.0.071                                     |
| M-3   | `getStreetDistance_` ใช้ cache store ต่างจาก Maps helper | `10:836+`               | ⚠️ จริง — แต่ไม่มีผล       | ไม่ใช่ bug — ใช้ต่าง store ตาม context                                       |
| L-1   | `GOOGLEMAPS_DISTANCE` เรียก server-side                  | `10:836+`               | ⚠️ จริง — defer            | ทำงานได้ แต่ไม่ใช่ intended pattern → P3                                     |
| L-2   | `logPipelineRun_` ใช้ `appendRow()`                      | `10:~411`               | ⚠️ จริง — เล็กน้อย         | เรียกครั้งเดียวท้าย run ไม่ใช่ loop → acceptable                             |
| L-3   | `setupGroupOneSheets_` ไม่ผ่าน `withEntryPointGuard_`    | `03_SetupSheets.gs`     | ⚠️ จริง — เล็กน้อย         | helper function ภายใน setupAllSheets → low risk                              |
| L-4   | `SAFEGUARD_CONFIG.MIN_SIMILARITY_RATIO = 0.5` หละหลวม    | `21b_AliasSafeguard.gs` | ⚠️ subjective — defer      | ต้อง benchmark กับ corpus จริง → P3                                          |

### รายงานที่ 3 — AUD-4 Documentation Audit (V6.0.071)

| ID          | คำกล่าวหา                                  | สถานะใน V6.0.071      | การพิสูจน์                                                    |
| ----------- | ------------------------------------------ | --------------------- | ------------------------------------------------------------- |
| DTD-001     | README บอก 6.0.069 แต่ code 6.0.071        | ❌ **จริง** — ต้องแก้ | `README.md:9` ค้าง 6.0.069                                    |
| DTD-002     | BLUEPRINT title + metadata ค้าง 6.0.069    | ❌ **จริง** — ต้องแก้ | `BLUEPRINT.md:3,6,7` ค้าง 6.0.069                             |
| DTD-003~006 | 4 docs อื่นค้าง 6.0.044-069                | ❌ **จริง** — ต้องแก้ | IT_Guide, SOP_Admin, System_Guide, Column_Dictionary          |
| DTD-007     | `lmds_admin_manual.html` title "LMDS V5.5" | ❌ **จริง** — เก่ามาก | เก่าที่สุด — title ค้าง V5.5                                  |
| DTD-008~017 | audit reports + TOC + encoding             | ⚠️ จริง — เล็กน้อย    | ส่วนใหญ่เป็น historical reports → mark `DOC-TYPE: historical` |

> **คะแนน AUD-4: 61/100 (C)** — แรงไป เพราะปัญหาส่วนใหญ่เป็น doc version drift แก้ได้ใน 30 นาที ไม่ใช่ architectural issue

### P2-R5 — งานจากรอบ 5 — เสร็จ 6/6 (V6.0.072) — 3 PRs (#191/#192/#193)

| #       | งาน                                                                                                                       | Priority | สถานะ                        |
| ------- | ------------------------------------------------------------------------------------------------------------------------- | -------- | ---------------------------- |
| P2-R5-1 | **AuthZ fail-open: 24 จุด migrate เป็น `isAuthorizedOrFail_()` fail-closed**                                              | P0       | ✅ Done (V6.0.072 PR B #192) |
| P2-R5-2 | **JSON.parse guard ที่ `22c:916`** (try-catch + fallback `[]`)                                                            | P1       | ✅ Done (V6.0.072 PR A #191) |
| P2-R5-3 | **12b lock bare → `releaseScriptLock_()`**                                                                                | P1       | ✅ Done (V6.0.072 PR A #191) |
| P2-R5-4 | **README.md version sync → 6.0.072** + ลบ V6.0.048 refs + stats update                                                    | P2       | ✅ Done (V6.0.072 PR A #191) |
| P2-R5-5 | **BLUEPRINT.md version sync → 6.0.072** (title + metadata + footer)                                                       | P2       | ✅ Done (V6.0.072 PR A #191) |
| P2-R5-6 | **5 docs อื่นๆ sync → 6.0.072** (IT_Guide, System_Guide, Column_Dictionary, SOP_Admin, lmds_admin_manual.html historical) | P2       | ✅ Done (V6.0.072 PR A #191) |

### สิ่งที่เราเรียนรู้เพิ่ม (รอบ 5)

1. **ผมลืม sync docs หลัง V6.0.070/071 merge** — V6.0.069 PR #180 sync docs ครั้งสุดท้าย แต่ V6.0.070/071 ไม่ได้ sync ตาม → เกิด Doc Debt 7 ไฟล์
2. **ผมลืมเพิ่ม issue ใหม่เข้า TODO.md** — พบ N-1/N-2/N-3 ตอน verification รอบ 4 แต่ไม่ได้ลงทะเบียน จนกระทั่งผู้ใช้ทัก
3. **AI auditor 3 ท่านเห็นตรงกันเรื่อง AuthZ fail-open** — Principal Auditor (TD-016 P0) + Static Audit (N-2) + AUD-4 — ต้องแก้ใน V6.0.072
4. **TD-017 webapp.access = 'MYSELF' ไม่ใช่ code bug** — เป็น deployment config ที่บันทึกใน SECURITY.md §3 อยู่แล้ว — ต้องเปลี่ยนตอน deploy ไม่ใช่ตอนเขียน code
5. **บทเรียนสำหรับการ merge ครั้งต่อไป:** หลัง merge ทุก PR — ต้อง (ก) sync docs ที่อ้าง version ทั้งหมด (ข) ลงทะเบียน issue ใหม่ที่เจอระหว่าง verification เข้า TODO.md ทันที

---

## 13. รอบ 6 — สรุปการตรวจสอบ V6.0.072 (2026-07-23) — 4 AI audit reports ใหม่

### ภาพรวม

หลัง V6.0.072 merged (PR #191/#192/#193), ผู้ใช้ส่งรายงาน AI audit **4 ฉบับใหม่** เข้ามาตรวจสอบ:

| รายงาน                                               | ขอบเขต                                                              | จำนวน claims | ผล verification                                            |
| ---------------------------------------------------- | ------------------------------------------------------------------- | ------------ | ---------------------------------------------------------- |
| **รายงานที่ 1 — LMDS-audit-report**                  | 36 check scripts (12 ST + 12 RT + 12 DM) — run on V6.0.072          | ~15          | 7 จริง / 8 false positive ในตัว scripts เอง (61% accuracy) |
| **รายงานที่ 2 — ตรวจสอบเอกสาร LMDS**                 | Documentation audit (10 issues)                                     | 10           | 7 จริง (ส่วนใหญ่แก้ใน V6.0.072 แล้ว) / 3 หลอน              |
| **รายงานที่ 3 — LMDS_V6.0_PreDelivery_Audit_Report** | Principal Auditor — 18 TDs + SEC + Style + Refactor                 | ~40          | 12 จริง / 6 หลอน — คะแนน 84/100 (B+) แม่นยำที่สุด          |
| **รายงานที่ 4 — audit 5 phase technical review**     | 5-Phase Technical Review (14 TDs + 5 tips + SEC + Style + Refactor) | ~50          | 11 จริง / 3 หลอน — คะแนน 84/100 (B+) แม่นยำที่สุด          |

### P0 Claims — Verification ที่ละข้อ

| P0 ID  | คำกล่าวหา                                     | ไฟล์:บรรทัด (อ้าง)                                      | สถานะใน V6.0.072                | การพิสูจน์                                                                                                                                         |
| ------ | --------------------------------------------- | ------------------------------------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| P0-001 | CDN import ใน Unauthorized.html               | `views/Unauthorized.html:8`                             | ❌ **จริง** — ต้องแก้           | grep ยืนยัน `<script src="https://cdn.tailwindcss.com"></script>` อยู่จริง                                                                         |
| P0-002 | UrlFetchApp.fetch without try-catch (2 sites) | `15_GoogleMapsAPI.gs:20`, `18_ServiceSCG.gs:22`         | ✅ **หลอน**                     | ทั้ง 2 จุดเป็น comment ใน DEPENDENCIES block ไม่ใช่ code จริง — ฟังก์ชันจริงใช้ `Maps.newDirectionFinder()` และ `fetchWithRetry_()` (มี try-catch) |
| P0-003 | webapp.access = 'MYSELF'                      | `appsscript.json:13`                                    | ✅ จริง — แต่ deployment config | บันทึกใน SECURITY.md §3 อยู่แล้ว                                                                                                                   |
| P0-004 | LockService missing ใน 05 + 10f               | `05_NormalizeService.gs`, `10f_MatchAliasEnrichment.gs` | ⚠️ **น่าจะหลอน**                | 05 เป็น pure functions (ไม่มี setValues), 10f เรียก createGlobalAlias ที่มี lock อยู่แล้ว — ต้อง verify เพิ่ม                                      |

### P1 — Quick wins (verified real — ทำใน V6.0.073)

| ID      | คำกล่าวหา                                       | ไฟล์:บรรทัด                    | สถานะ                   |
| ------- | ----------------------------------------------- | ------------------------------ | ----------------------- |
| TD-001  | 09_DestinationService bare `lock.releaseLock()` | `09_DestinationService.gs:144` | ✅ Done (V6.0.073 PR B) |
| TD-004  | `appendRow` → `setValues` (consistency)         | `26_AuditTrailService.gs:171`  | ✅ Done (V6.0.073 PR B) |
| TD-005  | Magic number 8 → TEST_MATCH_IDX                 | `28_WebAppActions.gs:621`      | ✅ Done (V6.0.073 PR B) |
| TD-011  | showVersionInfo hardcoded "542 functions"       | `00_App.gs:~584`               | ✅ Done (V6.0.073 PR B) |
| SEC-013 | Audit trail log email ไม่ mask                  | `26_AuditTrailService.gs:184`  | ✅ Done (V6.0.073 PR B) |
| SEC-014 | getReviewDetail reviewer email ไม่ mask         | `22c_WebAppActions.gs:344`     | ✅ Done (V6.0.073 PR B) |

### Dependabot Alert #5 — @hono/node-server

- **Vulnerability:** Path traversal in `serve-static` on Windows via `%5C`
- **Status:** ✅ Dismissed via GitHub API on 2026-07-23
- **Reason:** tolerable_risk — transitive dev-only dependency via @google/clasp (not in production runtime)

### False Positives ใน AI audit รอบ 6 (8 ตัว)

| #   | Check  | False positive reason                                                         |
| --- | ------ | ----------------------------------------------------------------------------- |
| 1   | ST-002 | regex ไม่ยอมรับ suffix letter (`10b_`, `21b_`, `22c_`) — LMDS pattern ถูกต้อง |
| 2   | DM-001 | regex หา `RULE[1-8]` (uppercase) แต่จริงๆ คือ `evaluateRule[1-8]` (camelCase) |
| 3   | DM-011 | ค้นหาแค่ UPPER_CASE ไม่ยอมรับ camelCase `makeMatchDecision()`                 |
| 4   | DM-012 | ค้นหาแค่ `1_group1_master_db/` แต่จริงๆ อยู่ใน `2_group2_daily_ops/`          |
| 5   | DM-002 | flagged ถ้า M_PERSON ปรากฏ ไม่ได้ตรวจ read/write                              |
| 6   | DM-008 | LMDS ใช้ specialized functions ไม่ใช่ generic `maskPii_`                      |
| 7   | RT-006 | heuristic ไม่แยก setup จาก data write                                         |
| 8   | DM-009 | ตรวจแค่ 03_SetupSheets ไม่รวม 19_Hardening                                    |

### สิ่งที่เราเรียนรู้เพิ่ม (รอบ 6)

1. **AI ดูแค่ doc comment ไม่ได้ดู code จริง** — P0-002 อ้าง comment ใน DEPENDENCIES block แต่ไม่ใช่ code จริง — ต้อง verify ทุก claim ด้วย grep + read file
2. **Template-based audit มี false positive สูง** — LMDS-audit-report ใช้ audit-template-v2 ที่มี bug 61% (8 ใน 36 checks เป็น false positive)
3. **Principal Auditor + 5-Phase Technical Review แม่นยำสุด** — 84/100 (B+) — ใช้เป็นแหล่งหลักสำหรับ verification
4. **Dependabot alerts ต้อง verify** — บางครั้งเป็น dev-only dependency ที่ไม่กระทบ production
5. **บทเรียนสำหรับการ merge ครั้งต่อไป:** หลัง merge ทุก PR — ต้อง (ก) sync docs (ข) register new issues (ค) mark status Done — ทั้ง 3 อย่างทันที (บทเรียน #3 ยังไม่ฝังลึก)
