<!-- DOC-TYPE: living -->

# 📋 TODO — Pending Recommendations from AI Reviews

> Track ทุกข้อเสนอที่ยังไม่ได้ทำ จาก AI reviewers ทั้ง 4 ท่าน
> อัปเดต: 2026-07-16 | เวอร์ชั่นปัจจุบัน: V6.0.058

---

## สถานะ Group ทั้งหมด

| Group                   | งานทั้งหมด | เสร็จ | สถานะ                 |
| ----------------------- | ---------- | ----- | --------------------- |
| ✅ Group A (Quick Wins) | 4          | 4     | เสร็จ (V6.0.052-053)  |
| ✅ Group B (Security)   | 4          | 4     | เสร็จ (V6.0.054-056)  |
| ✅ Group C (Code Fixes) | 5          | 5     | เสร็จ (V6.0.057-058)  |
| 🟡 Group D (Defer)      | 2          | 0     | รอเงื่อนไข            |
| 🔴 Group E (No-Go)      | 5          | 0     | ห้ามทำ (ไม่เหมาะ GAS) |
| 🟡 Phase D (Process)    | 12         | 0     | กำลังทำ               |

---

## 🟡 Group D — รอเงื่อนไข (ทำเมื่อจำเป็น)

| #   | งาน                                        | ที่มา                    | เงื่อนไขที่จะทำ                                                            |
| --- | ------------------------------------------ | ------------------------ | -------------------------------------------------------------------------- |
| D-1 | **STG_CLEANED / CLEAN_AUDIT middle layer** | Reviewer 2's #1 proposal | ทำเมื่อทีมโตขึ้น หรือเจอปัญหา audit จริง                                   |
| D-2 | **Split 21_AliasService.gs (1,771 LOC)**   | Reviewer 2 TD-02         | ทำเมื่อเจอปัญหา maintenance จริง (cohesion สูง — อย่า split ถ้าไม่มีปัญหา) |

---

## 🔴 Group E — ห้ามทำ (ไม่เหมาะกับ GAS)

| #   | งาน                                   | ที่มา      | ทำไมห้าม                                                |
| --- | ------------------------------------- | ---------- | ------------------------------------------------------- |
| E-1 | Replace `typeof===function` soft deps | Reviewer 2 | เป็น idiomatic pattern ของ GAS — ถ้าเอาออกจะพัง         |
| E-2 | Rate Limiting (30/min)                | Reviewer 2 | เป็น public API pattern — เราใช้ Google OAuth + RBAC    |
| E-3 | Unit test framework (GasT / QUnitGS2) | Reviewer 2 | abandoned projects — เรามี snapshot test อยู่แล้ว       |
| E-4 | `safeHtml_` type-brand                | Reviewer 2 | TypeScript/React pattern — GAS ไม่มี compile-time types |
| E-5 | Audit trail expansion (log ทุกอย่าง)  | Reviewer 2 | อันตราย — GAS quota log จำกัด                           |

---

## 🟡 Phase D — กระบวนการตรวจสอบ (กำลังทำ)

### D-1: CI checks ใหม่ (8 ตัว)

| #     | Script                                | ตรวจอะไร                                | สถานะ   |
| ----- | ------------------------------------- | --------------------------------------- | ------- |
| D-1.1 | `check_10_dead_functions.sh`          | function ที่ไม่มี caller                | 🔜 รอทำ |
| D-1.2 | `check_11_wrapper_usage.sh`           | wrapper ต้องถูกใช้ทุกที่                | 🔜 รอทำ |
| D-1.3 | `check_12_path_consistency.sh`        | CREATE_NEW/AUTO_MATCH/MERGE consistency | 🔜 รอทำ |
| D-1.4 | `check_13_no_runtime_cdn.sh`          | ห้าม CDN runtime                        | 🔜 รอทำ |
| D-1.5 | `check_14_external_api_resilience.sh` | UrlFetchApp ต้องมี try-catch            | 🔜 รอทำ |
| D-1.6 | `check_15_string_duplication.sh`      | string ซ้ำ > 2 ครั้ง                    | 🔜 รอทำ |
| D-1.7 | `check_16_api_call_count.sh`          | นับ getSheetByName/getValue/setValue    | 🔜 รอทำ |
| D-1.8 | `check_17_production_readiness.sh`    | appsscript.json access + executeAs      | 🔜 รอทำ |

### D-2: AI Review Verification Protocol

| #     | งาน                                | สถานะ   |
| ----- | ---------------------------------- | ------- |
| D-2.1 | สร้าง `docs/AI-REVIEW-PROTOCOL.md` | 🔜 รอทำ |

### D-3: PR Template

| #     | งาน                       | สถานะ                      |
| ----- | ------------------------- | -------------------------- |
| D-3.1 | เพิ่ม Pre-Merge Checklist | ✅ Done (V6.0.059 — C-3.3) |

### D-4: Self-Audit Script

| #     | งาน                           | สถานะ   |
| ----- | ----------------------------- | ------- |
| D-4.1 | สร้าง `scripts/self_audit.sh` | 🔜 รอทำ |

---

## 📊 สรุปความคืบหน้าทั้งหมด

### งานที่เสร็จแล้ว (V6.0.049-058)

| เวอร์ชั่น | งาน                                                                   | ที่มา                 |
| --------- | --------------------------------------------------------------------- | --------------------- |
| V6.0.049  | Dead code cleanup (matchCalcFullScore_ + matchCalcGeoAnchorScore_)    | Reviewer 1            |
| V6.0.050  | Split 10_MatchEngine.gs → 10f/10g/10h                                 | Reviewer 1 + 2        |
| V6.0.051  | Move scoring functions to 10b                                         | Reviewer 1            |
| V6.0.052  | resetAliasEnrichmentContext_ wrapper + bump_version.sh                | Reviewer 1 + Lesson   |
| V6.0.053  | Persist SYS_NOTES on all code paths                                   | Reviewer 2            |
| V6.0.054  | SECURITY.md + XFrameOptions docs                                      | Reviewer 3            |
| V6.0.055  | validateInput_() helper                                               | Reviewer 2 (adjusted) |
| V6.0.056  | OAuth scopes audit                                                    | Reviewer 3            |
| V6.0.057  | Google Maps helper + runNormalize label + ESLint 200 + Telegram retry | Reviewer 2+4          |
| V6.0.058  | 5-Layer Alias Safeguard (Layer 1+5)                                   | Reviewer 1 (adjusted) |
| V6.0.059  | TODO.md + CI-CD-TROUBLESHOOTING.md + PR template + check_18           | Process improvement   |

### งานที่ยังไม่ได้ทำ

- **Group D:** 2 งาน (รอเงื่อนไข)
- **Phase D:** 10 งาน (กำลังทำ — D-1 + D-2 + D-4)

---

## ประวัติการอัปเดต

| วันที่     | เวอร์ชั่น | งาน                   |
| ---------- | --------- | --------------------- |
| 2026-07-16 | V6.0.059  | สร้าง TODO.md (C-3.1) |
