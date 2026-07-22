<!-- DOC-TYPE: living -->

# 📋 TODO — Pending Recommendations from AI Reviews

> Track ทุกข้อเสนอที่ยังไม่ได้ทำ จาก AI reviewers ทั้งหมด
> อัปเดต: 2026-07-22 | เวอร์ชั่น repo ปัจจุบัน: V6.0.072 (PR #191/#192/#193 merged)
> ⚠️ WebApp ที่ deploy จริงยังเป็น V6.0.069 — ต้อง deploy V6.0.072 ขึ้น production (รวม 070+071+072)

---

## สถานะ Group ทั้งหมด

| Group                   | งานทั้งหมด | เสร็จ | สถานะ                             |
| ----------------------- | ---------- | ----- | --------------------------------- |
| ✅ Group A (Quick Wins) | 4          | 4     | เสร็จ (V6.0.052-053)              |
| ✅ Group B (Security)   | 4          | 4     | เสร็จ (V6.0.054-056)              |
| ✅ Group C (Code Fixes) | 5          | 5     | เสร็จ (V6.0.057-059)              |
| ✅ Phase D (Process)    | 12         | 12    | เสร็จ (V6.0.060-062)              |
| ✅ P0 รอบ 2             | 3          | 3     | เสร็จ (V6.0.063)                  |
| ✅ P1 รอบ 2             | 4          | 4     | เสร็จ (V6.0.064-066)              |
| ✅ P0 รอบ 3             | 4          | 4     | เสร็จ (V6.0.070)                  |
| ✅ P1 รอบ 3             | 4          | 4     | เสร็จ (V6.0.070-068)              |
| 🟡 Group D (Defer)      | 3          | 0     | รอเงื่อนไข                        |
| 🔴 Group E (No-Go)      | 5          | 0     | ห้ามทำ (ไม่เหมาะ GAS)             |
| ✅ P2 รอบ 4             | 10         | 6     | 3+3 เสร็จ (V6.0.071+072) + 4 ค้าง |
| ✅ P2 รอบ 5             | 6          | 6     | เสร็จ (V6.0.072)                  |
| ✅ Doc Debt (V6.0.072)  | 7          | 7     | เสร็จ (V6.0.072)                  |

---

## ✅ งานที่เสร็จแล้วทั้งหมด (V6.0.049-068)

| เวอร์ชั่น | งาน                                                                                                                                     | ที่มา                            |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| V6.0.049  | Dead code cleanup                                                                                                                       | Reviewer 1                       |
| V6.0.050  | Split 10_MatchEngine.gs → 10f/10g/10h                                                                                                   | Reviewer 1 + 2                   |
| V6.0.051  | Move scoring functions to 10b                                                                                                           | Reviewer 1                       |
| V6.0.052  | resetAliasEnrichmentContext_ wrapper + bump_version.sh                                                                                  | Reviewer 1 + Lesson              |
| V6.0.053  | Persist SYS_NOTES on all code paths                                                                                                     | Reviewer 2                       |
| V6.0.054  | SECURITY.md + XFrameOptions docs                                                                                                        | Reviewer 3                       |
| V6.0.055  | validateInput_() helper                                                                                                                 | Reviewer 2 (adjusted)            |
| V6.0.056  | OAuth scopes audit                                                                                                                      | Reviewer 3                       |
| V6.0.057  | Google Maps helper + runNormalize label + ESLint 200 + Telegram retry                                                                   | Reviewer 2+4                     |
| V6.0.058  | 5-Layer Alias Safeguard (Layer 1+5)                                                                                                     | Reviewer 1 (adjusted)            |
| V6.0.059  | TODO.md + CI-CD-TROUBLESHOOTING.md + PR template + check_18                                                                             | Process improvement              |
| V6.0.060  | 8 new CI checks (check_10-17)                                                                                                           | Process improvement              |
| V6.0.061  | AI Review Protocol + self_audit.sh                                                                                                      | Process improvement              |
| V6.0.062  | Cleanup AI review files                                                                                                                 | Cleanup                          |
| V6.0.063  | P0 รอบ 2: SSTI + LockService + AuthZ guards                                                                                             | Reviewer #3 (รอบ 2)              |
| V6.0.064  | P1 รอบ 2: XSS escape (6 components) + PII masking (phone)                                                                               | Reviewer #2+#3 (รอบ 2)           |
| V6.0.065  | P1 รอบ 2: Documentation sync (6 docs)                                                                                                   | Reviewer #3 (รอบ 2)              |
| V6.0.066  | P1 รอบ 2: Formula injection sanitizer                                                                                                   | Reviewer #3 (รอบ 2)              |
| V6.0.070  | P0 รอบ 3: PII email + Cookie B1→PropsService + XSS LiveFeed + Lock                                                                      | Reviewer #1+#2 (รอบ 3)           |
| V6.0.070  | P1 รอบ 3: Auth fail-open → deny-by-default                                                                                              | Reviewer #2 (รอบ 3)              |
| V6.0.070  | CodeQL #56: Useless conditional fix                                                                                                     | CodeQL                           |
| V6.0.068  | P1 รอบ 3: TODO.md update + BLUEPRINT.md update + wire check_10-18                                                                       | Reviewer #1 (รอบ 3)              |
| V6.0.071  | P2-R4-1: PipelineManager `lock.releaseLock()` → `releaseScriptLock_(lock)`                                                              | Audit Round 4 ISSUE-001          |
| V6.0.071  | P2-R4-2: `maskSearchQuery_()` helper + apply in `searchLocations` logInfo                                                               | Audit Round 4 ISSUE-002          |
| V6.0.071  | P2-R4-3: `submitReviewDecision` mask email ด้วย `maskEmailSafe_()`                                                                      | Audit Round 4 ISSUE-003          |
| V6.0.072  | P2-R5-2: `getMatchEngineLiveStatus` JSON.parse guard (try-catch + fallback)                                                             | Audit Round 5 — Static H-2       |
| V6.0.072  | P2-R5-3: `12b_ReviewReprocessor` lock bare → `releaseScriptLock_(lock)`                                                                 | Audit Round 5 — Static M-2       |
| V6.0.072  | P2-R5-4/5/6: 7 docs sync 6.0.069 → 6.0.072 (README, BLUEPRINT, IT_Guide, System_Guide, Column_Dictionary, SOP_Admin, admin_manual.html) | Audit Round 5 — AUD-4            |
| V6.0.072  | P2-R5-1: AuthZ fail-open → fail-closed (24 sites) — new `isAuthorizedOrFail_()` helper                                                  | Audit Round 5 — TD-016 P0        |
| V6.0.072  | P2-R4-4: M_PLACE.normalized_name ใช้ `normalizeForCompare()` (เหมือน M_PERSON)                                                          | Audit Round 4 — user observation |
| V6.0.072  | P2-R4-5: M_PLACE.normalized_reverse_geocode ใช้ `normalizeForCompare()`                                                                 | Audit Round 4 — user observation |
| V6.0.072  | P2-R4-6: Menu "🔧 ระบบ & ตั้งค่า" split เป็น 4 sub-menus (12+7+5+4=28 items)                                                            | Audit Round 4 — user observation |

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

| #       | งาน                                               | ที่ไหน                      | สถานะ                        |
| ------- | ------------------------------------------------- | --------------------------- | ---------------------------- |
| P2-R3-1 | Dead functions ใน 16_GeoDictionaryBuilder.gs      | lines 245, 402, 408         | ✅ Done (V6.0.070)           |
| P2-R3-2 | Pagination duplication 3 จุดใน 22b_WebAppViews.gs | lines 455, 619, 898         | ✅ Done (V6.0.070)           |
| P2-R3-3 | `ratio <= floor` ควรเป็น `<`                      | `21b_AliasSafeguard.gs:85`  | ✅ Done (V6.0.070)           |
| P2-R3-4 | try-catch รอบ tryLock ไม่จำเป็น                   | `10_MatchEngine.gs:166-172` | ✅ Done (V6.0.070)           |
| P2-R3-5 | COOKIE_CELL: 'B1' ยังอยู่ใน config แม้ deprecated | `01_Config.gs:592`          | ⏭️ ยังใช้อยู่ (auto-migrate) |
| P2-R3-6 | 99_Legacy.gs ไม่มี sunset version                 | `99_Legacy.gs`              | ✅ Done (V6.0.070)           |

---

## ✅ P2 รอบ 4 — เสร็จ 6/10 (V6.0.071 + V6.0.072) — เหลือ 4 P3 (Group D)

> **แหล่ง:** รายงาน AI audit 2 ฉบับ (5-Phase Audit + Static Code Audit) ตรวจทุก claim กับโค้ด V6.0.070 จริง
> ตาม `docs/AI-REVIEW-PROTOCOL.md` 5 กฎ — ดูผล verification เต็มที่ `docs/ai-reviews/COMPARATIVE_ANALYSIS.md` section 11

### ✅ P1 — ทำเสร็จใน V6.0.071 (PR #189) — 3 รายการ

| #       | งาน                                                                            | ไฟล์:บรรทัด                 | สถานะ              |
| ------- | ------------------------------------------------------------------------------ | --------------------------- | ------------------ |
| P2-R4-1 | **PipelineManager: เปลี่ยน `lock.releaseLock()` → `releaseScriptLock_(lock)`** | `24_PipelineManager.gs:759` | ✅ Done (V6.0.071) |
| P2-R4-2 | **searchLocations: mask rawQuery ใน logInfo** (ป้องกัน PII leak)               | `22c_WebAppActions.gs:697`  | ✅ Done (V6.0.071) |
| P2-R4-3 | **submitReviewDecision: mask email ด้วย `maskEmailSafe_()`**                   | `22c_WebAppActions.gs:257`  | ✅ Done (V6.0.071) |

### ✅ P2 — เสร็จใน V6.0.072 (PR #193) — 3 รายการ

| #       | งาน                                                                       | ไฟล์                     | สถานะ              |
| ------- | ------------------------------------------------------------------------- | ------------------------ | ------------------ |
| P2-R4-4 | **M_PLACE.normalized_name ใช้ `normalizeForCompare()`** (เหมือน M_PERSON) | `07_PlaceService.gs:801` | ✅ Done (V6.0.072) |
| P2-R4-5 | **M_PLACE.normalized_reverse_geocode ใช้ `normalizeForCompare()`**        | `07_PlaceService.gs:790` | ✅ Done (V6.0.072) |
| P2-R4-6 | **Menu "🔧 ระบบ & ตั้งค่า" split เป็น 4 sub-menus** (12+7+5+4=28 items)   | `00_App.gs:111-168`      | ✅ Done (V6.0.072) |

### 🟢 P3 — Defer ไป Group D — 4 รายการค้าง

| #        | งาน                                 | ที่มา (Issue) | สถานะ       |
| -------- | ----------------------------------- | ------------- | ----------- |
| P2-R4-7  | getDriverHistory_ cache             | ISSUE-005     | 🔜 Group D  |
| P2-R4-8  | Audit trail N×appendRow → batch     | ISSUE-006     | 🔜 Group D  |
| P2-R4-9  | recordAuditTrail doc fix            | ISSUE-007     | 🔜 Cosmetic |
| P2-R4-10 | GOOGLEMAPS_REVERSEGEOCODE dead code | ISSUE-009     | 🔜 Group D  |

---

## ✅ P2 รอบ 5 — เสร็จ 6/6 (V6.0.072) — 3 PRs (#191/#192/#193)

> **แหล่ง:** รายงาน AI audit 3 ฉบับใหม่ (Principal Auditor 5-Phase + Static Code Audit + AUD-4 Documentation Audit)
> ตรวจทุก claim กับโค้ด V6.0.071 จริง ตาม `docs/AI-REVIEW-PROTOCOL.md` 5 กฎ
> ดูผล verification เต็มที่ `docs/ai-reviews/COMPARATIVE_ANALYSIS.md` section 12

### ✅ P0 — Security — เสร็จใน V6.0.072 PR B (#192)

| #       | งาน                                                                                                            | ไฟล์:บรรทัด             | สถานะ              | ความเสี่ยง              |
| ------- | -------------------------------------------------------------------------------------------------------------- | ----------------------- | ------------------ | ----------------------- |
| P2-R5-1 | **AuthZ fail-open**: 24 จุด migrate เป็น `isAuthorizedOrFail_()` fail-closed (new helper in 27_RbacService.gs) | 14 ไฟล์ (24 call sites) | ✅ Done (V6.0.072) | ปานกลาง — CI 14/14 ผ่าน |

### ✅ P1 — Quick wins — เสร็จใน V6.0.072 PR A (#191)

| #       | งาน                                                                                                     | ไฟล์:บรรทัด                   | สถานะ              | ความเสี่ยง    |
| ------- | ------------------------------------------------------------------------------------------------------- | ----------------------------- | ------------------ | ------------- |
| P2-R5-2 | **JSON.parse guard**: `getMatchEngineLiveStatus` try-catch + fallback `[]` + logWarn                    | `22c_WebAppActions.gs:916`    | ✅ Done (V6.0.072) | ต่ำ — 10 นาที |
| P2-R5-3 | **12b lock bare**: `12b_ReviewReprocessor.gs:90` → `releaseScriptLock_(lock)` (null-safe hasLock guard) | `12b_ReviewReprocessor.gs:90` | ✅ Done (V6.0.072) | ต่ำ — 5 นาที  |

### ✅ P2 — Documentation sync — เสร็จใน V6.0.072 PR A (#191)

| #       | งาน                                                                                                                                    | ไฟล์                  | สถานะ              |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------- | --------------------- | ------------------ |
| P2-R5-4 | **README.md version 6.0.069 → 6.0.072** + ลบ stale "V6.0.048" references + อัปเดต stats (28135 lines, 543 functions)                   | `README.md`           | ✅ Done (V6.0.072) |
| P2-R5-5 | **BLUEPRINT.md version 6.0.069 → 6.0.072** (title + metadata + footer)                                                                 | `BLUEPRINT.md`        | ✅ Done (V6.0.072) |
| P2-R5-6 | **5 ไฟล์ docs อื่นๆ** sync → 6.0.072: IT_Guide, System_Guide, Column_Dictionary, SOP_Admin, lmds_admin_manual.html (historical banner) | `docs/*.md` + `.html` | ✅ Done (V6.0.072) |

---

## ✅ Doc Debt — V6.0.072 (sync 6.0.069 → 6.0.072) — เสร็จ 7/7

> **สาเหตุเดิม:** V6.0.069 PR #180 sync docs ครั้งสุดท้าย แต่ V6.0.070/071 ไม่ได้ sync ตาม — ทั้ง 7 ไฟล์ค้าง 6.0.069 หรือเก่ากว่า
> **สถานะปัจจุบัน:** ✅ แก้ครบใน V6.0.072 PR A (#191) — sync ทั้ง 7 ไฟล์ → 6.0.072

| #   | ไฟล์                                        | ปัญหาเดิม                                                                  | สถานะ   |
| --- | ------------------------------------------- | -------------------------------------------------------------------------- | ------- |
| 1   | `README.md:9`                               | บอก "6.0.069 (Production Ready)" → sync 6.0.072 + ลบ V6.0.048 refs + stats | ✅ Done |
| 2   | `BLUEPRINT.md:3,6,7`                        | title + metadata + footer ค้าง 6.0.069 → sync 6.0.072                      | ✅ Done |
| 3   | `docs/01_SOP_Admin_LMDS.md:482,484`         | อ้างอิง 6.0.044 → sync 6.0.072                                             | ✅ Done |
| 4   | `docs/02_IT_Guide_LMDS.md:250,968,972`      | ค้าง 6.0.069 → sync 6.0.072                                                | ✅ Done |
| 5   | `docs/LMDS_System_Guide.md:6,583,690`       | ค้าง 6.0.069 → sync 6.0.072                                                | ✅ Done |
| 6   | `docs/LMDS_Column_Dictionary_TH.md:3,8,325` | ค้าง 6.0.069 → sync 6.0.072                                                | ✅ Done |
| 7   | `docs/lmds_admin_manual.html`               | title "LMDS V5.5" → "(Historical)" + banner + DOC-TYPE                     | ✅ Done |

---

## 📋 หมายเหตุสำคัญ (V6.0.072 รอบ 4 + รอบ 5)

### การพิสูจน์ AI audit (9 issues)

ตาม `AI-REVIEW-PROTOCOL.md` กฎ 1 (File existence) และกฎ 2 (Line number):

- **6 จริง** — ISSUE-001, 002, 003, 005, 006, 007
- **2 แก้บางส่วน** — ISSUE-004 (isCurrentUserAdmin_ — V6.0.070 ลบไปแล้วบางจุด)
- **1 หลอน** — ISSUE-008 (getSheetByNameSafe_ — grep ยืนยันมีจริงใน 03_SetupSheets.gs)
- **1 defer** — ISSUE-009 (GOOGLEMAPS_REVERSEGEOCODE — จะใช้ในอนาคต)

### ข้อสังเกตจากผู้ใช้จริง (V6.0.070 ที่ deploy เป็น V6.0.069)

- Dashboard 22,174ms — ช้าแต่ยังใช้ได้ (14k+ rows)
- 3 ชีตว่าง (RPT_DATA_QUALITY, TEST_MATCH_RESULTS, SYS_NEGATIVE_SAMPLES) — ปกติ ยังไม่ได้ trigger รายงาน
- PIPELINE_RUN_LOG 337 รอบ, 19/7→20/7 timestamp — auto-resume ปกติ
- **สำคัญ:** WebApp ยังเป็น V6.0.069 → ต้อง deploy V6.0.072 ขึ้น production (รวม V6.0.070 + 071 + 072)
- ✅ Menu "🔧 ระบบ & ตั้งค่า" split เป็น 4 sub-menus แล้ว (P2-R4-6 — V6.0.072 PR C)
- ✅ M_PLACE.normalized_name ใช้ `normalizeForCompare()` แล้ว (P2-R4-4 — V6.0.072 PR C)

### บทเรียนจาก V6.0.071 → V6.0.072 (ลืมบ่อย — ต้องระวัง)

1. **ลืม sync docs หลัง V6.0.070/071 merge** — V6.0.069 PR #180 sync docs ครั้งสุดท้าย แต่ V6.0.070/071 ไม่ได้ sync ตาม → เกิด Doc Debt 7 ไฟล์ (แก้ครบใน V6.0.072 PR A)
2. **ลืมเพิ่ม issue ใหม่เข้า TODO.md** — พบ N-1/N-2/N-3 ตอน verification รอบ 4 แต่ไม่ได้ลงทะเบียน จนกระทั่งผู้ใช้ทัก → ต้องเพิ่มในรอบ 5 (PR #190)
3. **ลืม mark status เป็น Done หลัง merge** — V6.0.072 (3 PRs) merge แล้วแต่ TODO.md ยังค้าง "🔜 V6.0.072" → ต้องอัปเดตเป็น "✅ Done (V6.0.072)" (PR นี้)
4. **บทเรียนสรุป:** หลัง merge ทุก PR — ต้อง (ก) sync docs ที่อ้าง version ทั้งหมด (ข) ลงทะเบียน issue ใหม่ที่เจอระหว่าง verification เข้า TODO.md ทันที (ค) mark status เป็น Done ใน TODO.md ทันทีหลัง merge

### สถานะการทดสอบ V6.0.072

- ✅ V6.0.071 ผ่านการทดสอบบน production (user confirmed "ผ่านครับ")
- ⏳ V6.0.072 ยังไม่ได้ deploy ขึ้น production — ต้อง deploy ทั้ง 070+071+072 (WebApp ยังเป็น V6.0.069)
- จุดทดสอบที่จำเป็นหลัง deploy V6.0.072:
  1. **Menu** — เปิด Google Sheet ดูว่าเมนู "🔧 ระบบ & ตั้งค่า" ถูกแทนด้วย 4 sub-menus ใหม่ (⚙️/🔍/🧹/📸)
  2. **Pipeline** — กด "🚀 Run Full Pipeline" ดู SYS_LOG ไม่มี lock error
  3. **Search** — ค้นหาใน WebApp ดู log ว่า query ถูก mask (`08***78`)
  4. **Review** — Approve review ดู log ว่า email ถูก mask (`s***@example.com`)
  5. **M_PLACE** — รัน pipeline แล้วเช็ค M_PLACE.normalized_name ว่าเป็น lowercase + ไม่มี space (เหมือน M_PERSON)
  6. **AuthZ** — ทดสอบ viewer role พยายาม run pipeline → ต้องถูกปฏิเสธ (deny-by-default)
