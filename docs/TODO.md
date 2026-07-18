<!-- DOC-TYPE: living -->

# 📋 TODO — Pending Recommendations from AI Reviews

> Track ทุกข้อเสนอที่ยังไม่ได้ทำ จาก AI reviewers ทั้งหมด
> อัปเดต: 2026-07-17 | เวอร์ชั่นปัจจุบัน: V6.0.069

---

## สถานะ Group ทั้งหมด

| Group                   | งานทั้งหมด | เสร็จ | สถานะ                 |
| ----------------------- | ---------- | ----- | --------------------- |
| ✅ Group A (Quick Wins) | 4          | 4     | เสร็จ (V6.0.052-053)  |
| ✅ Group B (Security)   | 4          | 4     | เสร็จ (V6.0.054-056)  |
| ✅ Group C (Code Fixes) | 5          | 5     | เสร็จ (V6.0.057-059)  |
| ✅ Phase D (Process)    | 12         | 12    | เสร็จ (V6.0.060-062)  |
| ✅ P0 รอบ 2             | 3          | 3     | เสร็จ (V6.0.063)      |
| ✅ P1 รอบ 2             | 4          | 4     | เสร็จ (V6.0.064-066)  |
| ✅ P0 รอบ 3             | 4          | 4     | เสร็จ (V6.0.069)      |
| ✅ P1 รอบ 3             | 4          | 4     | เสร็จ (V6.0.069-068)  |
| 🟡 Group D (Defer)      | 3          | 0     | รอเงื่อนไข            |
| 🔴 Group E (No-Go)      | 5          | 0     | ห้ามทำ (ไม่เหมาะ GAS) |

---

## ✅ งานที่เสร็จแล้วทั้งหมด (V6.0.049-068)

| เวอร์ชั่น | งาน                                                                   | ที่มา                  |
| --------- | --------------------------------------------------------------------- | ---------------------- |
| V6.0.049  | Dead code cleanup                                                     | Reviewer 1             |
| V6.0.050  | Split 10_MatchEngine.gs → 10f/10g/10h                                 | Reviewer 1 + 2         |
| V6.0.051  | Move scoring functions to 10b                                         | Reviewer 1             |
| V6.0.052  | resetAliasEnrichmentContext_ wrapper + bump_version.sh                | Reviewer 1 + Lesson    |
| V6.0.053  | Persist SYS_NOTES on all code paths                                   | Reviewer 2             |
| V6.0.054  | SECURITY.md + XFrameOptions docs                                      | Reviewer 3             |
| V6.0.055  | validateInput_() helper                                               | Reviewer 2 (adjusted)  |
| V6.0.056  | OAuth scopes audit                                                    | Reviewer 3             |
| V6.0.057  | Google Maps helper + runNormalize label + ESLint 200 + Telegram retry | Reviewer 2+4           |
| V6.0.058  | 5-Layer Alias Safeguard (Layer 1+5)                                   | Reviewer 1 (adjusted)  |
| V6.0.059  | TODO.md + CI-CD-TROUBLESHOOTING.md + PR template + check_18           | Process improvement    |
| V6.0.060  | 8 new CI checks (check_10-17)                                         | Process improvement    |
| V6.0.061  | AI Review Protocol + self_audit.sh                                    | Process improvement    |
| V6.0.062  | Cleanup AI review files                                               | Cleanup                |
| V6.0.063  | P0 รอบ 2: SSTI + LockService + AuthZ guards                           | Reviewer #3 (รอบ 2)    |
| V6.0.064  | P1 รอบ 2: XSS escape (6 components) + PII masking (phone)             | Reviewer #2+#3 (รอบ 2) |
| V6.0.065  | P1 รอบ 2: Documentation sync (6 docs)                                 | Reviewer #3 (รอบ 2)    |
| V6.0.066  | P1 รอบ 2: Formula injection sanitizer                                 | Reviewer #3 (รอบ 2)    |
| V6.0.069  | P0 รอบ 3: PII email + Cookie B1→PropsService + XSS LiveFeed + Lock    | Reviewer #1+#2 (รอบ 3) |
| V6.0.069  | P1 รอบ 3: Auth fail-open → deny-by-default                            | Reviewer #2 (รอบ 3)    |
| V6.0.069  | CodeQL #56: Useless conditional fix                                   | CodeQL                 |
| V6.0.068  | P1 รอบ 3: TODO.md update + BLUEPRINT.md update + wire check_10-18     | Reviewer #1 (รอบ 3)    |

---

## 🟡 Group D — รอเงื่อนไข (ทำเมื่อจำเป็น)

| #   | งาน                                          | ที่มา                                         | เงื่อนไขที่จะทำ                                                            |
| --- | -------------------------------------------- | --------------------------------------------- | -------------------------------------------------------------------------- |
| D-1 | **STG_CLEANED / CLEAN_AUDIT middle layer**   | Reviewer 2's #1 proposal (รอบ 1)              | ทำเมื่อทีมโตขึ้น หรือเจอปัญหา audit จริง                                   |
| D-2 | **Split 21_AliasService.gs (1,796 LOC)**     | รอบ 1 + รอบ 2 ทั้ง 3 ท่าน + รอบ 3 ทั้ง 2 ท่าน | ทำเมื่อเจอปัญหา maintenance จริง (cohesion สูง — อย่า split ถ้าไม่มีปัญหา) |
| D-3 | **Split 05_NormalizeService.gs (1,419 LOC)** | Reviewer #3 (รอบ 2 AUD2-ATD-004)              | เหมือนกัน — cohesion สูง                                                   |
| D-4 | **Group 2 writes FACT_DELIVERY directly**    | Reviewer #3 (รอบ 2 AUD2-ATD-001)              | ทำเมื่อ refactor ReviewService                                             |

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

## 🟡 P2 รอบ 3 — ทยอยแก้

| #       | งาน                                               | ที่ไหน                      | สถานะ |
| ------- | ------------------------------------------------- | --------------------------- | ----- |
| P2-R3-1 | Dead functions ใน 16_GeoDictionaryBuilder.gs      | lines 245, 402, 408         | 🔜    |
| P2-R3-2 | Pagination duplication 3 จุดใน 22b_WebAppViews.gs | lines 455, 619, 898         | 🔜    |
| P2-R3-3 | `ratio <= floor` ควรเป็น `<`                      | `21b_AliasSafeguard.gs:85`  | 🔜    |
| P2-R3-4 | try-catch รอบ tryLock ไม่จำเป็น                   | `10_MatchEngine.gs:166-172` | 🔜    |
| P2-R3-5 | COOKIE_CELL: 'B1' ยังอยู่ใน config แม้ deprecated | `01_Config.gs:592`          | 🔜    |
| P2-R3-6 | 99_Legacy.gs ไม่มี sunset version                 | `99_Legacy.gs`              | 🔜    |
