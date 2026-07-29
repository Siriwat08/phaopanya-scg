<!-- DOC-TYPE: living -->

# 📋 Issues Analysis & Fix Plan — 8 Open Issues

> **วิเคราะห์ละเอียด + แผนแก้ไข + เช็คลิสต์** สำหรับ GitHub Issues #205–#215 (ทั้ง 8 ข้อ)
> ทุก Issue ถูกตรวจสอบกับโค้ด V6.0.078 จริง (grep + read file)
>
> **วันที่สร้าง:** 2026-07-26
> **เวอร์ชั่น:** V6.0.078
> **สถานะ:** รอหลังส่งมอบ v1.0-submit

---

## 📊 ภาพรวม 8 Issues

| #        | Issue                                 | Priority | Labels                    | สถานะปัจจุบัน                                    | Effort   | Risk       |
| -------- | ------------------------------------- | -------- | ------------------------- | ------------------------------------------------ | -------- | ---------- |
| **#205** | Refactor 30 functions >100 บรรทัด     | P2       | refactor, tech-debt       | 36 functions จริง (audit พบ 36 ไม่ใช่ 30)        | 5 วัน    | 🟡 ปานกลาง |
| **#206** | Split 9 God files >1000 บรรทัด        | P2       | refactor, tech-debt       | 9 ไฟล์จริง (1,796–1,056 บรรทัด)                  | 10 วัน   | 🔴 สูง     |
| **#207** | Checkpoint pattern missing (15 files) | P2       | enhancement, tech-debt    | 22 ไฟล์จริง (audit บอก 15, grep พบ 22)           | 5 วัน    | 🟡 ปานกลาง |
| **#208** | Layer 2-4 Alias Safeguard             | P2       | enhancement, security     | 3 references ใน comment เท่านั้น (ไม่ implement) | 3-10 วัน | 🔴 สูง     |
| **#209** | STG_CLEANED middle layer              | P3       | enhancement, architecture | ยังไม่มี sheet STG_CLEANED                       | 5 วัน    | 🔴 สูง     |
| **#210** | 6 codebase bugs (comment-only)        | P2       | bug, documentation        | ทั้ง 6 จริง (verified ทุกตัว)                    | 2 ชม.    | 🟢 ต่ำ     |
| **#214** | Vendor Tailwind CSS locally           | P2       | enhancement, security     | 4 CDN references จริง                            | 2 ชม.    | 🟢 ต่ำ     |
| **#215** | Audit trail coverage 0%               | P2       | enhancement, security     | 0 logAuditTrail calls ใน 5 create functions จริง | 1 วัน    | 🟢 ต่ำ     |

**รวม effort:** ~22 วันทำงาน (ถ้าทำทั้งหมด)
**รวม risk:** ต่ำ 4 + ปานกลาง 2 + สูง 3

---

## 🔍 วิเคราะห์ละเอียดแต่ละ Issue

---

### Issue #205 — Refactor 36 functions >100 บรรทัด

**สถานะ verification:** ✅ จริง — audit พบ 36 functions (ไม่ใช่ 30 ตามที่เขียนใน Issue)

#### Functions ที่ยาวที่สุด 5 อันดับแรก (verified)

| Function                    | บรรทัด | ไฟล์                       | วิธีแก้ (split pattern)                                                     |
| --------------------------- | ------ | -------------------------- | --------------------------------------------------------------------------- |
| `submitBulkReviewDecisions` | 216    | 22c_WebAppActions.gs:294   | → `validateBulkInput_()` + `processBulkItem_()` + `flushBulkFactRows_()`    |
| `runTestMatchDryRun_`       | 214    | 10d_MatchTestHarness.gs:58 | → `loadTestRows_()` + `processOneTestRow_()` + `buildTestSummary_()`        |
| `getReviewDetail`           | 212    | 22c_WebAppActions.gs:524   | → `readQReviewRow_()` + `resolveEntityNames_()` + `buildCandidatesList_()`  |
| `runPipelineBatch`          | 198    | 24_PipelineManager.gs:568  | → `initBatch_()` + `processBatchChunk_()` + `finalizeBatch_()`              |
| `submitReviewDecision`      | 195    | 22c_WebAppActions.gs:87    | → `validateReviewInput_()` + `executeReviewDecision_()` + `writeFactRow_()` |

#### แผนแก้ไข

| Sprint   | Functions                           | วิธี                                        | เวลา  |
| -------- | ----------------------------------- | ------------------------------------------- | ----- |
| Sprint 1 | 5 functions ยาวสุด (216-195 บรรทัด) | Extract helper functions ตาม pattern ด้านบน | 3 วัน |
| Sprint 2 | 15 functions ยาว 150-190 บรรทัด     | Extract 2-3 helpers ต่อ function            | 2 วัน |
| Sprint 3 | 16 functions ยาว 100-149 บรรทัด     | Extract 1-2 helpers ต่อ function            | 2 วัน |

#### เช็คลิสต์

```
[ ] รัน snapshotSaveBaseline_() ก่อนเริ่ม
[ ] Sprint 1: แก้ 5 functions ยาวสุด
  [ ] submitBulkReviewDecisions → split เป็น 3 helpers
  [ ] runTestMatchDryRun_ → split เป็น 3 helpers
  [ ] getReviewDetail → split เป็น 4 helpers
  [ ] runPipelineBatch → split เป็น 3 helpers
  [ ] submitReviewDecision → split เป็น 3 helpers
  [ ] รัน snapshotCompare_() → ต้อง 0 differences
  [ ] รัน prettier + syntax check
  [ ] รัน audit-template-v5 ST-008 → ลดลง 5 functions
[ ] Sprint 2: แก้ 15 functions กลาง
  [ ] แก้ทีละ function + snapshot compare ทุกครั้ง
[ ] Sprint 3: แก้ 16 functions เล็ก
  [ ] แก้ทีละ function + snapshot compare
[ ] รัน audit-template-v5 ทั้งหมด → ST-008 ต้อง 0 warnings
[ ] อัปเดต Issue #205 → close
```

---

### Issue #206 — Split 9 God files >1000 บรรทัด

**สถานะ verification:** ✅ จริง — 9 ไฟล์ (verified ด้วย `wc -l`)

#### ไฟล์ที่ต้อง split (เรียงตามขนาด)

| ไฟล์                     | บรรทัด | Functions | แผน split                                                                 |
| ------------------------ | ------ | --------- | ------------------------------------------------------------------------- |
| `21_AliasService.gs`     | 1,796  | 35        | → 21 (core) + 21c (history) + 21d (enrich) + 21e (migration)              |
| `00_App.gs`              | 1,709  | 30+       | → 00 (onOpen/onEdit/dispatcher) + 00b (diagnostics) + 00c (cleanup menus) |
| `24_PipelineManager.gs`  | 1,534  | 25+       | → 24 (batch runner) + 24b (preflight) + 24c (alerts)                      |
| `14_Utils.gs`            | 1,454  | 40+       | → 14 (core utils) + 14b (cache helpers) + 14c (string/geo utils)          |
| `05_NormalizeService.gs` | 1,432  | 30+       | → 05 (core) + 05b (person normalize) + 05c (place normalize + phonetic)   |
| `18_ServiceSCG.gs`       | 1,246  | 25+       | → 18 (fetch) + 18b (daily job write) + 18c (cookie/config)                |
| `22c_WebAppActions.gs`   | 1,167  | 15+       | → 22c (review actions) + 22d (search actions)                             |
| `07_PlaceService.gs`     | 1,160  | 20+       | → 07 (core CRUD) + 07b (resolve + candidates)                             |
| `12_ReviewService.gs`    | 1,056  | 20+       | → 12 (core review) + 12c (batch processing)                               |

#### แผนแก้ไข

| Sprint   | ไฟล์                                                                  | เวลา  | Risk                                       |
| -------- | --------------------------------------------------------------------- | ----- | ------------------------------------------ |
| Sprint 1 | `21_AliasService.gs` → 4 ไฟล์                                         | 3 วัน | 🔴 สูง (cohesion สูง ต้องระวัง dependency) |
| Sprint 2 | `05_NormalizeService.gs` → 3 ไฟล์                                     | 2 วัน | 🟡 ปานกลาง                                 |
| Sprint 3 | `00_App.gs` + `14_Utils.gs`                                           | 3 วัน | 🟡 ปานกลาง                                 |
| Sprint 4 | `24_PipelineManager.gs` + `18_ServiceSCG.gs`                          | 3 วัน | 🟡 ปานกลาง                                 |
| Sprint 5 | `22c_WebAppActions.gs` + `07_PlaceService.gs` + `12_ReviewService.gs` | 2 วัน | 🟢 ต่ำ                                     |

#### เช็คลิสต์

```
[ ] รัน snapshotSaveBaseline_() ก่อนเริ่มแต่ละ Sprint
[ ] Sprint 1: Split 21_AliasService.gs
  [ ] สร้าง 21c_AliasHistory.gs (backfill + populate*)
  [ ] สร้าง 21d_AliasEnrich.gs (enrich + auto-migrate)
  [ ] สร้าง 21e_AliasMigration.gs (MIGRATION_HybridAliasSystem)
  [ ] อัปเดต header comments ทุกไฟล์
  [ ] อัปเดต 00_App.gs menu references (ถ้ามี)
  [ ] รัน snapshotCompare_() → 0 differences
  [ ] รัน audit-template-v5 → ST-008 ลดลง
[ ] Sprint 2-5: ทำซ้ำตาม pattern เดียวกัน
[ ] อัปเดต README.md stats (file count เปลี่ยน)
[ ] อัปเดต BLUEPRINT.md file listing
[ ] อัปเดต docs/LMDS_System_Guide.md
[ ] รัน check_01_version + check_02_stats
[ ] อัปเดต Issue #206 → close
```

---

### Issue #207 — Checkpoint pattern missing (22 files)

**สถานะ verification:** ✅ จริง — grep พบ 22 ไฟล์ (audit บอก 15, จริงมีมากกว่า)

#### ไฟล์ที่ affected (verified)

| กลุ่ม            | ไฟล์                                                                                                   | มี AutoResume?                                 |
| ---------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| Group 1 Master   | 05_Normalize, 06_Person, 07_Place, 08_Geo, 09_Destination, 10_MatchEngine, 10d_TestHarness, 16_GeoDict | ❌ ไม่มี (ยกเว้น 10 ที่มี 10h_MatchAutoResume) |
| Group 2 Daily    | 11_Transaction, 12_Review, 17_Search, 18_ServiceSCG                                                    | ❌ ไม่มี                                       |
| Group 4 Pipeline | 24_PipelineManager                                                                                     | ✅ มี (batch + circuit breaker)                |
| Group 0 Core     | 03_SetupSheets, 22b_WebAppViews, 26_AuditTrail                                                         | ❌ ไม่มี                                       |

#### แผนแก้ไข

| ขั้น | งาน                                                                            | เวลา  |
| ---- | ------------------------------------------------------------------------------ | ----- |
| 1    | สร้าง `checkpointHelper_()` ใน 14_Utils.gs (save/load/clear PropertiesService) | 2 ชม. |
| 2    | แทรก checkpoint ทุก 100 rows ใน 10_MatchEngine (สำคัญสุด)                      | 3 ชม. |
| 3    | แทรก checkpoint ใน 06_Person, 07_Place, 08_Geo (batch loaders)                 | 3 ชม. |
| 4    | แทรก checkpoint ใน 12_Review, 11_Transaction                                   | 2 ชม. |
| 5    | ทดสอบ: หยุดกลางคัน → รันต่อ → ต้อง resume จากที่หยุด                           | 4 ชม. |

#### เช็คลิสต์

```
[ ] สร้าง checkpointHelper_() ใน 14_Utils.gs
  [ ] saveCheckpoint_(sheetName, rowIndex)
  [ ] loadCheckpoint_(sheetName) → rowIndex หรือ 2
  [ ] clearCheckpoint_(sheetName)
[ ] แทรก checkpoint ใน 10_MatchEngine (ทุก 100 rows)
[ ] แทรก checkpoint ใน 06_Person, 07_Place, 08_Geo
[ ] แทรก checkpoint ใน 12_Review, 11_Transaction
[ ] ทดสอบ resume:
  [ ] รัน pipeline → หยุดกลางคัน (Ctrl+C หรือ timeout)
  [ ] รันใหม่ → ต้องเริ่มจาก row ที่หยุด ไม่ใช่ row 1
[ ] ทดสอบ idempotent:
  [ ] รัน 2 ครั้งซ้อน → ไม่ duplicate data
[ ] อัปเดต Issue #207 → close
```

---

### Issue #208 — Layer 2-4 Alias Safeguard

**สถานะ verification:** ✅ จริง — มีแค่ comment อ้างถึง Layer 2-4 แต่ไม่มี implementation

#### สถานะปัจจุบัน (verified)

| Layer                                              | สถานะ           | ไฟล์                  |
| -------------------------------------------------- | --------------- | --------------------- |
| Layer 1: Structural Validation (Levenshtein ≥ 0.5) | ✅ Implemented  | 21b_AliasSafeguard.gs |
| Layer 2: Repetition Consensus                      | ❌ Comment only | 21b:15                |
| Layer 3: Conflict Detection                        | ❌ Comment only | 21b:16                |
| Layer 4: Probation Lifecycle                       | ❌ Comment only | 21b:17                |
| Layer 5: Circuit Breaker (max 50/day)              | ✅ Implemented  | 21b_AliasSafeguard.gs |

#### แผนแก้ไข (3 ตัวเลือก)

| ตัวเลือก          | Scope                | เวลา   | Risk       | เงื่อนไขทำ                          |
| ----------------- | -------------------- | ------ | ---------- | ----------------------------------- |
| ก: Defer          | ไม่ทำ                | 0      | —          | ถ้ายังไม่เจอ pain point             |
| ข: Layer 2 only   | Repetition Consensus | 3 วัน  | 🟡 ปานกลาง | เมื่อเริ่มเห็น alias ผิดจาก outlier |
| ค: Full Layer 2-4 | ทั้ง 3 layers        | 10 วัน | 🔴 สูง     | เมื่อทีมโต 5+ คน หรือมีหลาย admin   |

#### เช็คลิสต์ (ถ้าเลือกตัวเลือก ข — Layer 2)

```
[ ] เพิ่ม columns ใน M_ALIAS: confirm_count (INT), first_seen_at (DATETIME)
[ ] สร้าง Layer 2 check function: checkRepetitionConsensus_(masterUuid, variantName)
  [ ] ตรวจว่า alias เดียวกันเคยเห็นใน FACT_DELIVERY กี่ครั้ง
  [ ] ถ้า < 2 ครั้ง → ตั้ง status = 'probation' (ไม่ promote)
  [ ] ถ้า >= 2 ครั้งในคนละวัน → promote เป็น 'confirmed'
[ ] เชื่อมเข้า createGlobalAlias() → เรียก checkRepetitionConsensus_ ก่อน promote
[ ] ทดสอบ:
  [ ] สร้าง alias จาก FACT 1 ครั้ง → status = probation
  [ ] สร้าง alias จาก FACT อีกครั้ง (คนละวัน) → status = confirmed
[ ] อัปเดต Issue #208 → close
```

---

### Issue #209 — STG_CLEANED middle layer

**สถานะ verification:** ✅ จริง — ไม่มี sheet STG_CLEANED ในระบบ

#### แผนแก้ไข

| ขั้น | งาน                                                             | เวลา  |
| ---- | --------------------------------------------------------------- | ----- |
| 1    | สร้าง sheet STG_CLEANED + SCHEMA + IDX                          | 2 ชม. |
| 2    | สร้าง sheet CLEAN_AUDIT + SCHEMA + IDX                          | 1 ชม. |
| 3    | แก้ runLoadSource() → เขียน STG_CLEANED แทนตรงเข้า MatchEngine  | 1 วัน |
| 4    | แก้ MatchEngine → อ่านจาก STG_CLEANED แทน SOURCE                | 1 วัน |
| 5    | สร้าง `validateCleanedData_()` → ตรวจคุณภาพก่อนเข้า MatchEngine | 1 วัน |
| 6    | Migration: ย้ายข้อมูลเดิมจาก SOURCE → STG_CLEANED               | 4 ชม. |

#### เช็คลิสต์

```
[ ] สร้าง SCHEMA['STG_CLEANED'] ใน 02_Schema.gs
[ ] สร้าง STG_CLEANED_IDX ใน 01_Config.gs
[ ] สร้าง SCHEMA['CLEAN_AUDIT']
[ ] แก้ runLoadSource() → ส่งข้อมูลผ่าน STG_CLEANED
[ ] แก้ MatchEngine → อ่านจาก STG_CLEANED
[ ] สร้าง validateCleanedData_() + log ลง CLEAN_AUDIT
[ ] Migration script: SOURCE → STG_CLEANED
[ ] ทดสอบ: รัน pipeline → ข้อมูลผ่าน STG_CLEANED → MatchEngine → FACT_DELIVERY
[ ] อัปเดต Issue #209 → close
```

---

### Issue #210 — 6 codebase bugs (comment-only)

**สถานะ verification:** ✅ จริงทั้ง 6 ข้อ (verified ทุกตัว)

#### รายการ bugs (verified)

| #   | Bug                              | ไฟล์:บรรทัด               | Verification                      | วิธีแก้                                          |
| --- | -------------------------------- | ------------------------- | --------------------------------- | ------------------------------------------------ |
| 1   | `bindAlias` dead reference       | 10e:25                    | ✅ grep ไม่พบ function definition | ลบ comment หรือเปลี่ยนเป็น `createGlobalAlias()` |
| 2   | `readInputConfig_` อ้างผิดที่    | 01_Config:19, 14_Utils:23 | ✅ จริงอยู่ใน 18_ServiceSCG:207   | แก้ comment ให้ชี้ไป 18                          |
| 3   | `ENV_*` constants ไม่มีจริง      | 01_Config:19              | ✅ grep ไม่พบ const ENV_          | แก้ comment เป็น "PropertiesService keys"        |
| 4   | `ENV_MAPS_API_KEY` ไม่จำเป็น     | 15_GoogleMapsAPI:16       | ✅ ไม่มี const                    | ลบบรรทัดที่อ้าง                                  |
| 5   | IDX inconsistency (32/37/29)     | 01_Config:312,436,476     | ✅ จริง — แต่ตรงตาม schema        | เพิ่ม comment ย้ำว่าใช้ IDX ของ sheet นั้น       |
| 6   | MIGRATION_HybridAliasSystem dead | 21_AliasService:821       | ✅ มีแค่ใน menu (00_App:130)      | ย้ายไป 99_Legacy หรือลบ                          |

#### เช็คลิสต์

```
[ ] Bug 1: แก่ bindAlias dead reference ใน 10e:25
  [ ] เปลี่ยน "bindAlias()" → "createGlobalAlias()" ใน comment
[ ] Bug 2: แก้ readInputConfig_ ใน 01_Config:19 + 14_Utils:23
  [ ] เปลี่ยน "01_Config.gs" → "18_ServiceSCG.gs" ใน comment
[ ] Bug 3: แก้ ENV_* ใน 01_Config:19
  [ ] เปลี่ยน "ENV_*" → "PropertiesService keys (GEMINI_API_KEY, SCG_COOKIE, ฯลฯ)"
[ ] Bug 4: ลบ ENV_MAPS_API_KEY ใน 15_GoogleMapsAPI:16
[ ] Bug 5: เพิ่ม comment ใน 01_Config ย้ำ IDX per-sheet
[ ] Bug 6: ย้าย MIGRATION_HybridAliasSystem ไป 99_Legacy
  [ ] หรือลบออกจาก menu 00_App:130
[ ] รัน check_04_phantom_deps → ต้อง 0 phantom
[ ] อัปเดต Issue #210 → close
```

---

### Issue #214 — Vendor Tailwind CSS locally

**สถานะ verification:** ✅ จริง — 4 CDN references (verified)

#### ไฟล์ที่ affected

| ไฟล์                | บรรทัด | URL                                                       |
| ------------------- | ------ | --------------------------------------------------------- |
| `Index.html`        | 17     | `https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4.3.2` |
| `Unauthorized.html` | 12     | same                                                      |

(2 ไฟล์ × 2 references = 4 total)

#### แผนแก้ไข

| ขั้น | งาน                                                                                  | เวลา    |
| ---- | ------------------------------------------------------------------------------------ | ------- |
| 1    | Download `@tailwindcss/browser@4.3.2` (minified)                                     | 15 นาที |
| 2    | Save เป็น `src/3_group3_webapp/js/vendor/tailwind-browser.min.js`                    | 5 นาที  |
| 3    | เปลี่ยน `<script src="cdn...">` → `<script src="js/vendor/tailwind-browser.min.js">` | 15 นาที |
| 4    | ทดสอบ WebApp → styling แสดงปกติ                                                      | 30 นาที |

#### เช็คลิสต์

```
[ ] Download tailwind-browser.min.js (version 4.3.2)
[ ] Save ใน src/3_group3_webapp/js/vendor/
[ ] แก้ Index.html: CDN → local path
[ ] แก้ Unauthorized.html: CDN → local path
[ ] ทดสอบ WebApp → ทุกหน้า styling ปกติ
[ ] ทดสอบ Unauthorized.html → styling ปกติ
[ ] รัน check_13_no_runtime_cdn → ต้อง 0 CDN
[ ] อัปเดต Issue #214 → close
```

---

### Issue #215 — Audit trail coverage 0%

**สถานะ verification:** ✅ จริง — 0 logAuditTrail calls ใน 5 create functions (verified)

#### Functions ที่ขาด audit trail

| Function             | ไฟล์                  | AuthZ | Audit Trail |
| -------------------- | --------------------- | ----- | ----------- |
| `createPerson`       | 06_PersonService      | ✅ มี | ❌ ไม่มี    |
| `createPlace`        | 07_PlaceService       | ✅ มี | ❌ ไม่มี    |
| `createGeoPoint`     | 08_GeoService         | ✅ มี | ❌ ไม่มี    |
| `createDestination`  | 09_DestinationService | ✅ มี | ❌ ไม่มี    |
| `createGlobalAlias`  | 21_AliasService       | ✅ มี | ❌ ไม่มี    |
| `mergePersonRecords` | 06_PersonService      | ✅ มี | ❌ ไม่มี    |

#### แผนแก้ไข

| ขั้น | งาน                                                        | เวลา    |
| ---- | ---------------------------------------------------------- | ------- |
| 1    | เพิ่ม `logAuditTrail()` ใน `createPerson` (หลัง setValues) | 15 นาที |
| 2    | เพิ่ม `logAuditTrail()` ใน `createPlace`                   | 15 นาที |
| 3    | เพิ่ม `logAuditTrail()` ใน `createGeoPoint`                | 15 นาที |
| 4    | เพิ่ม `logAuditTrail()` ใน `createDestination`             | 15 นาที |
| 5    | เพิ่ม `logAuditTrail()` ใน `createGlobalAlias`             | 15 นาที |
| 6    | เพิ่ม `logAuditTrail()` ใน `mergePersonRecords`            | 15 นาที |
| 7    | ทดสอบ: สร้าง entity → ตรวจ SYS_AUDIT_TRAIL                 | 30 นาที |

#### เช็คลิสต์

```
[ ] createPerson → เพิ่ม logAuditTrail('PERSON', newId, 'CREATE', ...)
[ ] createPlace → เพิ่ม logAuditTrail('PLACE', newId, 'CREATE', ...)
[ ] createGeoPoint → เพิ่ม logAuditTrail('GEO', newId, 'CREATE', ...)
[ ] createDestination → เพิ่ม logAuditTrail('DEST', newId, 'CREATE', ...)
[ ] createGlobalAlias → เพิ่ม logAuditTrail('ALIAS', aliasId, 'CREATE', ...)
[ ] mergePersonRecords → เพิ่ม logAuditTrail('PERSON', targetId, 'MERGE', sourceId)
[ ] ทดสอบ:
  [ ] รัน pipeline → สร้าง entity ใหม่
  [ ] ตรวจ SYS_AUDIT_TRAIL → ต้องมี entries CREATE
  [ ] ทดสอบ merge → ต้องมี entry MERGE
[ ] รัน audit-template-v5 DM-021 → audit trail coverage > 0%
[ ] อัปเดต Issue #215 → close
```

---

## 📅 ลำดับการแก้ไขแนะนำ (Priority Order)

| ลำดับ | Issue | เหตุผล                                                     | Effort   | Risk |
| ----- | ----- | ---------------------------------------------------------- | -------- | ---- |
| **1** | #210  | Quick win — 6 bugs เป็น comment-only แก้ง่าย + ลดความสับสน | 2 ชม.    | 🟢   |
| **2** | #214  | Quick win — vendor Tailwind ลด supply-chain risk           | 2 ชม.    | 🟢   |
| **3** | #215  | Quick win — เพิ่ม audit trail ใน 6 functions               | 1 วัน    | 🟢   |
| **4** | #205  | Refactor 36 functions — เริ่มจาก 5 ยาวสุดก่อน              | 5 วัน    | 🟡   |
| **5** | #207  | Checkpoint pattern — ป้องกัน data loss เมื่อ timeout       | 5 วัน    | 🟡   |
| **6** | #206  | Split 9 God files — เริ่มจาก 21_AliasService ก่อน          | 10 วัน   | 🔴   |
| **7** | #208  | Layer 2 Safeguard — ทำเมื่อเจอ pain point                  | 3-10 วัน | 🔴   |
| **8** | #209  | STG_CLEANED — ทำเมื่อทีมโต                                 | 5 วัน    | 🔴   |

**รวม:** 31-38 วันทำงาน (ถ้าทำทั้งหมด)

---

## 🎯 คำแนะนำ

### ทำหลังส่งมอบ v1.0-submit (Sprint 1 — Quick Wins)

1. **#210** — 6 comment bugs (2 ชม.) → ลดความสับสน
2. **#214** — Vendor Tailwind (2 ชม.) → ลด supply-chain risk
3. **#215** — Audit trail (1 วัน) → เพิ่ม compliance

### ทำใน Sprint 2-3 (1-2 สัปดาห์หลังส่ง)

4. **#205** — Refactor 5 functions ยาวสุดก่อน (3 วัน)
5. **#207** — Checkpoint ใน 10_MatchEngine ก่อน (1 วัน)

### ทำใน Sprint 4-5 (1-2 เดือนหลังส่ง)

6. **#206** — Split 21_AliasService + 05_NormalizeService (5 วัน)
7. **#208** — Layer 2 (ถ้าเจอ pain point)

### ทำเมื่อทีมโต (3+ เดือน)

8. **#209** — STG_CLEANED (architectural change)

---

**เอกสารนี้จัดทำโดย:** LMDS Development Team
**วันที่:** 2026-07-26
**เวอร์ชั่น:** V6.0.078
