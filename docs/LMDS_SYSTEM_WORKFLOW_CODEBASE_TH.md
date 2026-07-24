<!-- DOC-TYPE: living -->

# LMDS System Workflow อธิบายการทำงานระบบ (ตามโค้ดจริง)

ไฟล์นี้อธิบายระบบ LMDS V6.0 จากโค้ดจริงในโปรเจกต์ `Siriwat08/phaopanya-scg` — เน้นว่าแต่ละกลุ่มทำงานอย่างไร ชีตใดเป็นจุดเชื่อม กฎธุรกิจล่าสุดของกลุ่ม 2 ที่ต้องใช้ `ShipToName` เป็น anchor หลัก และกลไกของกลุ่ม 1 ที่เรียนรู้ Master จากข้อมูลส่งจริง

> **โครงสร้างเอกสาร:** ยึดแบบเดิมที่เริ่มจากภาพรวมระบบ → หลักฐานในโค้ด → คำอธิบายแต่ละกลุ่ม → ความสัมพันธ์ชีต → ตาราง mapping → วิธีใช้งานจริง → ข้อห้าม → troubleshooting
>
> **⚠️ หมายเหตุสำหรับผู้ดูแล:** ระหว่างเขียนเอกสารนี้ ผมได้ตรวจโค้ดไปด้วยและพบ **bug/inconsistency 6 จุด** (สรุปไว้ใน Section 13) ขอให้รีบตรวจสอบและแก้ไข

---

## สารบัญ

1. [ภาพรวมระบบ](#1-ภาพรวมระบบ)
2. [หลักฐานจากโค้ดที่ยืนยันชื่อชีตหลัก](#2-หลักฐานจากโค้ดที่ยืนยันชื่อชีตหลัก)
3. [Group 0: Core System (โครงสร้างพื้นฐาน)](#3-group-0-core-system-โครงสร้างพื้นฐาน)
4. [Group 1: Actual Delivery / Master Learning](#4-group-1-actual-delivery--master-learning)
5. [Group 2: SCG API / Daily Job / Coordinate Fill](#5-group-2-scg-api--daily-job--coordinate-fill)
6. [Group 3: WebApp (Dashboard ออนไลน์)](#6-group-3-webapp-dashboard-ออนไลน)
7. [Group 4: Pipeline Manager (ตัวจัดการทำงานอัตโนมัติ)](#7-group-4-pipeline-manager-ตัวจัดการทำงานอตโนมต)
8. [ความสัมพันธ์ชีตต่อชีต](#8-ความสัมพันธชีตตอชีต)
9. [ตาราง mapping สำคัญ](#9-ตาราง-mapping-สำคัญ)
10. [วิธีใช้งานจริงที่แนะนำ](#10-วิธีใชงานจริงทแนะนำ)
11. [ข้อห้ามสำคัญเพื่อไม่ให้ระบบเพี้ยน](#11-ขอหามสำคญเพอไมใหระบบเพยน)
12. [Troubleshooting](#12-troubleshooting)
13. [บันทึก bug / inconsistency ที่พบระหว่างตรวจทานโค้ด](#13-บนทก-bug--inconsistency-ทพบระหวางตรวจทานโคด)

---

## 1. ภาพรวมระบบ

LMDS แบ่งโค้ดออกเป็น **5 กลุ่ม** ตามโฟลเดอร์ใน `src/`:

| กลุ่ม                          | โฟลเดอร์                     | จำนวนไฟล์                 | บทบาท                                                                                          |
| ------------------------------ | ---------------------------- | ------------------------- | ---------------------------------------------------------------------------------------------- |
| **Group 0 — Core**             | `src/O_core_system/`         | 14 ไฟล์ .gs               | โครงสร้างพื้นฐาน: config, schema, utils, RBAC, audit, hardening, WebApp gateway, snapshot test |
| **Group 1 — Master DB**        | `src/1_group1_master_db/`    | 16 ไฟล์ .gs               | เรียนรู้ Master (Person/Place/Geo/Destination) จากข้อมูลส่งจริง + เขียน Alias อัตโนมัติ        |
| **Group 2 — Daily Ops**        | `src/2_group2_daily_ops/`    | 8 ไฟล์ .gs                | โหลดงานประจำวันจาก SCG API → เติม `LatLong_Actual` จาก Master                                  |
| **Group 3 — WebApp**           | `src/3_group3_webapp/`       | 16 ไฟล์ .html             | Dashboard ออนไลน์แบบ SPA พร้อม 9 views + RBAC                                                  |
| **Group 4 — Pipeline Manager** | `src/4_group4_pipeline_mgr/` | 1 ไฟล์ .gs (1,534 บรรทัด) | ตั้งเวลาทำงานอัตโนมัติของ Group 1 พร้อม quota/circuit breaker                                  |

ถ้ามองในเชิง **business flow** ระบบมี **2 สายงานหลัก** ที่ทำงานคู่กัน:

1. **สายงานเรียนรู้ Master (Group 1)** — รับข้อมูลจริงจากคนขับผ่าน AppSheet ในชีต `SCGนครหลวงJWDภูมิภาค` มาสร้าง/ปรับปรุง Master (`M_PERSON`, `M_PLACE`, `M_GEO_POINT`, `M_DESTINATION`) บันทึกธุรกรรมลง `FACT_DELIVERY` และถ้าไม่มั่นใจก็ส่งเข้า `Q_REVIEW` พร้อมเขียน Alias อัตโนมัติผ่าน `autoEnrichAliasesFromFactBatch_()`

2. **สายงานงานประจำวัน (Group 2)** — รับแผนงานจาก SCG API ในชีต `Input` แล้วเขียนลง `ตารางงานประจำวัน` จากนั้นย้อนกลับไปยืมพิกัดจาก Master มาเติมในคอลัมน์ `LatLong_Actual` โดยใช้ `ShipToName` เป็น anchor หลัก (ใช้ `ShipToAddress` เป็น tie-breaker เมื่อจำเป็น)

Group 0, 3, 4 เป็นกลุ่มสนับสนุน:

- **Group 0** คือ "พื้นหลัง" ที่รองรับทั้ง 2 สายงาน (config, schema, auth, audit, hardening)
- **Group 3** คือ "หน้าต่าง" ที่ให้ผู้ใช้ทั้ง 2 สายงานเข้ามาดูผ่านเว็บ
- **Group 4** คือ "นาฬิกา" ที่ตั้งเวลาให้ Group 1 รันอัตโนมัติ

### หลักสำคัญของระบบ: Trinity Framework

```text
Person_ID + Place_ID + Geo_ID = Destination Node
```

`M_DESTINATION` เก็บโหนดที่ผูก Person + Place + Geo เข้าด้วยกัน และเป็นจุดที่ Group 2 ใช้ย้อนกลับมาเอาพิกัดที่เคยเรียนรู้จาก Group 1

การ implement จริงอยู่ที่ `resolveDestination(personId, placeId, geoId)` ใน `src/1_group1_master_db/09_DestinationService.gs:46` โดยใช้ตรรกะ:

```javascript
if (!personId || !placeId || !geoId) return { status: 'INSUFFICIENT' };
// หา exact match (P+PL+G) → FOUND
// หากเจอแค่ P+G (ไม่มี place) → PARTIAL_MATCH
// ไม่งั้น → NOT_FOUND
```

> ต้องมีครบทั้ง 3 ID ถึงจะถือว่า sufficient (โค้ดใช้ `||` ในการ reject)

---

## 2. หลักฐานจากโค้ดที่ยืนยันชื่อชีตหลัก

ชื่อชีตหลักถูกกำหนดใน `src/O_core_system/01_Config.gs:125-161`:

```javascript
const SHEET = Object.freeze({
  M_PERSON: 'M_PERSON',
  M_PERSON_ALIAS: 'M_PERSON_ALIAS',
  M_PLACE: 'M_PLACE',
  M_PLACE_ALIAS: 'M_PLACE_ALIAS',
  M_ALIAS: 'M_ALIAS',
  M_GEO_POINT: 'M_GEO_POINT',
  M_DESTINATION: 'M_DESTINATION',
  FACT_DELIVERY: 'FACT_DELIVERY',
  Q_REVIEW: 'Q_REVIEW',
  SOURCE: 'SCGนครหลวงJWDภูมิภาค',
  SYS_CONFIG: 'SYS_CONFIG',
  SYS_LOG: 'SYS_LOG',
  SYS_TH_GEO: 'SYS_TH_GEO',
  RPT_QUALITY: 'RPT_DATA_QUALITY',
  SYS_NOTES: 'SYS_NOTES', // [V6.0.001] Semantic Note Parser storage
  SYS_NEGATIVE_SAMPLES: 'SYS_NEGATIVE_SAMPLES', // [V6.0.003] System Learning — negative feedback
  SYS_AUDIT_TRAIL: 'SYS_AUDIT_TRAIL', // [V6.0.007] Audit Trail (ALIAS + Q_REVIEW scope)
  PIPELINE_RUN_LOG: 'PIPELINE_RUN_LOG', // [V6.0.012 P1.6] Stats per pipeline run
  TEST_MATCH_RESULTS: 'TEST_MATCH_RESULTS', // [V6.0.012 P1.7] Dry-run output
  DAILY_JOB: 'ตารางงานประจำวัน',
  INPUT: 'Input',
  EMPLOYEE: 'ข้อมูลพนักงาน',
  OWNER_SUMMARY: 'สรุป_เจ้าของสินค้า',
  SHIPMENT_SUM: 'สรุป_Shipment'
});
```

> **หมายเหตุ:** `MAPS_CACHE: 'MAPS_CACHE'` ถูกลบตั้งแต่ V5.5.013 — ปัจจุบันใช้ `CacheService.getDocumentCache()` ใน `15_GoogleMapsAPI.gs` แทน (เป็น `@customFunction` สำหรับ Google Sheet cells)

### `*_IDX` constants ทั้งหมด (21 objects)

นอกจาก SHEET object ยังมี `*_IDX` constants ที่กำหนด index ของคอลัมน์ (0-based) สำหรับทุกชีต — เป็น single source of truth ที่ห้ามใช้เลข index ตรง ๆ:

| Constant                                      | ไลน์ใน `01_Config.gs` | จำนวนคอลัมน์ | ชีตที่อ้างถึง                                        |
| --------------------------------------------- | --------------------- | ------------ | ---------------------------------------------------- |
| `PERSON_IDX`                                  | 168–187               | 13           | M_PERSON (มี PHONETIC_PRIMARY/SECONDARY + BRANCH_NO) |
| `PERSON_ALIAS_IDX`                            | 189–196               | 6            | M_PERSON_ALIAS                                       |
| `PLACE_IDX`                                   | 198–221               | 18           | M_PLACE (มี phonetic + reverse_geocode cols 16-17)   |
| `PLACE_ALIAS_IDX`                             | 223–230               | 6            | M_PLACE_ALIAS                                        |
| `ALIAS_IDX`                                   | 232–245               | 11           | M_ALIAS (มี VERIFIED_BY/REVIEW_ID/VERIFIED_AT)       |
| `GEO_IDX`                                     | 247–262               | 14           | M_GEO_POINT                                          |
| `DEST_IDX`                                    | 264–276               | 11           | M_DESTINATION                                        |
| `FACT_IDX`                                    | 278–314               | 34           | FACT_DELIVERY (มี DRIVER_VERIFIED_NAME/ADDR)         |
| `REVIEW_IDX`                                  | 316–339               | 22           | Q_REVIEW                                             |
| `SYS_LOG_IDX`                                 | 342–349               | 6            | SYS_LOG                                              |
| `TH_GEO_IDX`                                  | 357–374               | 16           | SYS_TH_GEO                                           |
| `EMPLOYEE_IDX`                                | 381–390               | 8            | ข้อมูลพนักงาน                                        |
| `SRC_IDX`                                     | 397–438               | 39           | SCGนครหลวงJWDภูมิภาค                                 |
| `DATA_IDX`                                    | 445–478               | 31           | ตารางงานประจำวัน                                     |
| `NOTES_IDX`                                   | 675–687               | 11           | SYS_NOTES                                            |
| `NEGATIVE_SAMPLE_IDX`                         | 693–702               | 8            | SYS_NEGATIVE_SAMPLES                                 |
| `OWNER_SUM_IDX`                               | 706–713               | 6            | สรุป_เจ้าของสินค้า                                   |
| `SHIPMENT_SUM_IDX`                            | 716–724               | 7            | สรุป_Shipment                                        |
| `PIPELINE_LOG_IDX`                            | 729–742               | 12           | PIPELINE_RUN_LOG                                     |
| `TEST_MATCH_IDX`                              | 747–756               | 8            | TEST_MATCH_RESULTS                                   |
| `AUDIT_IDX` (ใน `26_AuditTrailService.gs:43`) | —                     | 11           | SYS_AUDIT_TRAIL                                      |

นอกจากนี้ยังมี `SRC_READ_COLS = Object.keys(SRC_IDX).length` (computed ที่ `01_Config.gs:483`) เพื่อ auto-adapt เมื่อมีการเพิ่มคอลัมน์ใหม่

### `AI_CONFIG` (ไลน์ 619–638)

```javascript
const AI_CONFIG = Object.freeze({
  THRESHOLD_AUTO: 85, // ≥85 → FOUND
  THRESHOLD_REVIEW: 70, // 70-84 → NEEDS_REVIEW
  THRESHOLD_IGNORE: 50, // <50 → NOT_FOUND
  SCORE_MIN_THRESHOLD: 60, // Person name score gate
  PLACE_SCORE_MIN: 55,
  MODEL: 'gemini-1.5-flash',
  BATCH_SIZE: 20, // ประมวลผล batch ละ 20 แถว
  RETRIEVAL_LIMIT: 50,
  CACHE_TTL_SEC: 21600, // 6 ชั่วโมง
  GEO_RADIUS_M: 100, // V6.0.013 เพิ่มจาก 50 → 100
  GEO_GRID_SIZE: 0.01, // ~1.1 กม. (3×3 grid filter)
  USE_AI_REASONING: false, // safety — AI ไม่ควรเดาพิกัด
  TIME_LIMIT_MS: 280000 // 4.67 นาที (เหลือ buffer สำหรับ GAS 6-min limit)
});
```

> **⚠️ bug ที่พบ:** header comment ของ `01_Config.gs:19` อ้างว่ามี `ENV_*` constants แต่ grep ทั้ง codebase ไม่พบ — environment config จริง ๆ อยู่ใน `PropertiesService.getScriptProperties()` ทั้งหมด (`GEMINI_API_KEY`, `SCG_API_URL`, `SCG_COOKIE`, `LMDS_ADMINS`, `DASHBOARD_USERS`, `ROLE_ASSIGNMENTS`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `AUDIT_RETENTION_DAYS` ฯลฯ) — ดูรายละเอียดใน Section 13

---

## 3. Group 0: Core System (โครงสร้างพื้นฐาน)

Group 0 เป็นกลุ่มที่ทุก Group อื่นพึ่งพา มี 14 ไฟล์ .gs รวม ~12,000 บรรทัด

### 3.1 สถาปัตยกรรมสำคัญ

| ไฟล์                      | ไลน์  | หน้าที่จริง                                                                                                                |
| ------------------------- | ----- | -------------------------------------------------------------------------------------------------------------------------- |
| `00_App.gs`               | 1,709 | Entry point: `onOpen` (สร้าง 30+ เมนู), `onEdit` (watch Q_REVIEW.DECISION), `runFullPipeline` (RBAC + lock + 3 ขั้นตอน)    |
| `01_Config.gs`            | 899   | SHEET, *_IDX, AI_CONFIG, APP_CONST, SCG_CONFIG, TH_PROVINCES (77 จว. รวม บึงกาฬ)                                           |
| `02_Schema.gs`            | 648   | `SCHEMA` object — column headers ของทั้ง 24 ชีต + `validateSchemaConsistency()`                                            |
| `03_SetupSheets.gs`       | 529   | `setupAllSheets()` (RBAC-gated) — สร้างชีตทั้งหมดครั้งแรก + ลง data validation dropdowns                                   |
| `14_Utils.gs`             | 1,454 | String matching (Levenshtein/Dice/JaroWinkler/ensemble), haversine, locking, cache chunking, UUID↔ID conversion            |
| `19_Hardening.gs`         | 1,054 | Preflight audit, dedup audit, sheet protection, `validateInput_()`                                                         |
| `22_WebApp.gs`            | 342   | `doGet()` — WebApp entry, dashboard auth, PII masking                                                                      |
| `22b_WebAppViews.gs`      | 983   | Read-only view data: `getDashboardData`, `getFactDeliveryPage`, `getQReviewPage`, `getMatchEngineMetrics`, `getSourcePage` |
| `22c_WebAppActions.gs`    | 939   | Direct `google.script.run` actions: `submitReviewDecision`, `getReviewDetail`, `searchLocations`, `getMapAnalyticsData`    |
| `26_AuditTrailService.gs` | 413   | `logAuditTrail()`, `queryAuditTrail()` — scope: ALIAS + Q_REVIEW เท่านั้น                                                  |
| `27_RbacService.gs`       | 189   | RBAC: 3 roles, 11 permissions, `requirePermission_()`, `isAuthorizedOrFail_()`                                             |
| `28_WebAppActions.gs`     | 937   | Registry pattern — `WEB_APP_ACTION_REGISTRY` (37 actions) + `runWebAppAction()` dispatcher สำหรับ MobileActions            |
| `29_SnapshotTest.gs`      | 263   | Regression test: `snapshotSaveBaseline_()` + `snapshotCompare_()`                                                          |
| `99_Legacy.gs`            | 132   | Deprecated shims (`getColIndex`, `getDestinationsByPerson/Place`) — sunset target V7.0.0                                   |

### 3.2 Entry Points (เมนูหลัก)

`onOpen(e)` ใน `00_App.gs:58` สร้างเมนู `🚚 LMDS V6.0` แบ่งเป็น 4 sub-menus:

- 🟩 **กลุ่ม 1: ล้างข้อมูล & Master** — `runFullPipeline`, `runLoadSource`, `runNormalize`, `runMatchEngine`, dry-run, Rule-5 analyzer, Emergency Stop, Safe Reset, Review Queue, Quality Report
- 🟦 **กลุ่ม 2: งานประจำวัน SCG** — `fetchDataFromSCGJWD`, `applyMasterCoordinatesToDailyJob`, `clearAllSCGSheets`
- ⚙️ **ตั้งค่าระบบ** — admin list, role assignments, pipeline triggers, SCG cookie
- 🔍 **ตรวจสอบ & วินิจฉัย** — `checkSystemIntegrity`, `diagnoseSystemState`, `runPipelinePreflightStrict_UI`, `snapshotCompare_UI`
- 🧹 **ล้าง & Cleanup** — `cleanupStaleTriggers_UI`, `cleanupAutoResumeTriggers_UI`, `clearCache`, `resetSourceSyncStatus`
- 📸 **Snapshot & ข้อมูล** — `snapshotSaveBaseline_UI`, `snapshotCompare_UI`, `snapshotClearBaseline_UI`

`onEdit(e)` (`00_App.gs:192`) watch คอลัมน์ `Q_REVIEW.DECISION` — เมื่อ user edit decision → acquire LockService + check RBAC `action:approve_review` + เรียก `applyReviewDecision()`

`runFullPipeline()` (`00_App.gs:272`): RBAC-gated ผ่าน `requirePermission_('action:run_pipeline')`, acquire script lock 3s timeout, รัน 3 ขั้นตอนตามลำดับ:

1. `runLoadSource()` (Step 1)
2. `runNormalize()` (Step 2)
3. `runMatchEngine()` (Step 3) — มี internal 4.67-min time guard + auto-resume trigger

### 3.3 RBAC (Role-Based Access Control)

กำหนดใน `27_RbacService.gs`:

**3 Roles** (`RBAC_CONFIG.ROLES` ไลน์ 35):

- `VIEWER` — ดูได้อย่างเดียว
- `REVIEWER` — viewer + อนุมัติ Q_REVIEW
- `ADMIN` — เต็มสิทธิ์

**11 Permissions**:

| Permission              | VIEWER | REVIEWER | ADMIN |
| ----------------------- | :----: | :------: | :---: |
| `view:dashboard`        |   ✅   |    ✅    |  ✅   |
| `view:fact_delivery`    |   ✅   |    ✅    |  ✅   |
| `view:qreview`          |   ✅   |    ✅    |  ✅   |
| `view:map_analytics`    |   ✅   |    ✅    |  ✅   |
| `view:source_sheet`     |   ❌   |    ✅    |  ✅   |
| `view:live_feed`        |   ❌   |    ✅    |  ✅   |
| `action:approve_review` |   ❌   |    ✅    |  ✅   |
| `action:run_pipeline`   |   ❌   |    ❌    |  ✅   |
| `action:edit_master`    |   ❌   |    ❌    |  ✅   |
| `action:config`         |   ❌   |    ❌    |  ✅   |
| `action:clear_cache`    |   ❌   |    ❌    |  ✅   |

**การ resolve role** (`getCurrentUserRole_` ไลน์ 65):

1. email อยู่ใน `LMDS_ADMINS` script property → ADMIN
2. ไม่งั้นหาใน `ROLE_ASSIGNMENTS` script property (รูปแบบ `email:role`)
3. default → VIEWER

`isAuthorizedOrFail_()` (V6.0.072) เป็น fail-closed: ถ้า RBAC module โหลดไม่สำเร็จ → return `false` + logError (ไม่ใช่ fail-open แบบเดิม)

### 3.4 Audit Trail

กำหนดใน `26_AuditTrailService.gs`:

- **Scope:** เฉพาะ `ALIAS` และ `Q_REVIEW` (ขยายได้ในอนาคต)
- **Actions 4 ตัว:** `CREATE`, `UPDATE`, `DELETE`, `MERGE`
- **11 คอลัมน์** (`AUDIT_IDX`): `audit_id, entity_type, entity_id, action, field_changed, old_value, new_value, changed_by, changed_at, change_reason, ip_address`
- **Retention:** 90 วัน (override ได้ด้วย `AUDIT_RETENTION_DAYS` script property)
- **Failsafe:** ไม่มีทาง throw — ถ้า validation พังจะ log warning แล้วข้ามไป
- ถูกเรียกจาก `10_MatchEngine.gs`, `12_ReviewService.gs`, `21_AliasService.gs`, `10e_MatchResolvePersist.gs`

### 3.5 Hardening

กำหนดใน `19_Hardening.gs` (1,054 บรรทัด):

- `runPreflightAudit()` — Phase 2 preflight ก่อนรัน pipeline
- `detectDoubleProcessing()` — ตรวจ duplicate ใน FACT_DELIVERY
- `generatePersonAliasesFromHistory()` — enrich aliases จาก FACT_DELIVERY history พร้อม checkpoint/resume
- **Sheet Protection:** `applySheetProtection_UI()` ป้องกันชีตระดับ cell (Q_REVIEW.DECISION → reviewer/admin เท่านั้น, M_GEO_POINT.lat/lng → admin เท่านั้น)
- `runDedupAudit(entityType)` — ตรวจ person/place duplicate
- `validateInput_(input, schema)` (ไลน์ 953) — input validation สำหรับ WebApp actions (type/required/maxLength/minLength/pattern/enum/control-chars/number-range)

### 3.6 SnapshotTest (Regression Test)

กำหนดใน `29_SnapshotTest.gs`:

1. รัน `runTestMatchDryRunForceAll_UI()` (200-250 แถว) → เขียน TEST_MATCH_RESULTS
2. `snapshotSaveBaseline_()` (ไลน์ 48) เก็บ compact array `[source_row, action, reason, confidence, evidence]` ใน `PropertiesService.SNAPSHOT_TEST_BASELINE` (~32KB)
3. Refactor โค้ด
4. รัน dry run ใหม่
5. `snapshotCompare_()` (ไลน์ 105) diff กับ baseline — ถ้า differences = 0 → ปลอดภัย merge

### 3.7 ไฟล์อื่น ๆ ใน Group 0

- **`99_Legacy.gs`** — Deprecated shims (`getColIndex`, `getDestinationsByPerson/Place`) sunset target V7.0.0 — internal modules ไม่ได้เรียกใช้แล้ว
- **`14_Utils.gs`** — utility functions รวม ~40 ฟังก์ชัน:
  - String matching: `levenshteinDistance`, `diceCoefficient`, `jaroWinklerDistance`, `ensembleNameMatch`, `buildBigramSet_`
  - Geo/math: `haversineDistanceM/Km`, `isValidLatLng`, `parseLatLng`, `hasTimePassed_`
  - ID/hash: `generateShortId(prefix)`, `generateMd5Hash(input)`
  - Auth: `isAuthorizedUser_()` (ไลน์ 876), `setupAdminList_UI`, `getMaskedEmail_`
  - UI safety: `safeUiAlert_` (trigger-safe), `withEntryPointGuard_`
  - Locking: `acquireScriptLockOrWarn_`, `releaseScriptLock_` (null-safe)
  - Cache chunking: `saveChunkedCache_`, `loadChunkedCache_`, `invalidateChunkedCache_` (handle >100KB cache values)
  - UUID ↔ ID conversion: `convertUuidToPersonId/convertUuidToPlaceId/convertPersonIdToUuid/convertPlaceIdToUuid`
  - AI: `callGeminiAPI(prompt, modelName)` (ไลน์ 407), `cleanAIResponse_`

---

## 4. Group 1: Actual Delivery / Master Learning

### 4.1 ชีตต้นทาง

ชีต: `SCGนครหลวงJWDภูมิภาค`

ข้อมูลนี้เป็นข้อมูลจริงจากการส่งงานของคนขับผ่าน AppSheet จึงเป็นข้อมูลที่ระบบใช้เรียนรู้ Master ได้ เพราะมีชื่อปลายทาง ที่อยู่ และพิกัดจากการทำงานจริง

คอลัมน์สำคัญของชีตนี้อ้างอิงจาก `SRC_IDX` ใน `src/O_core_system/01_Config.gs:397-438` (39 คอลัมน์):

| ความหมาย             |                       Constant | คอลัมน์ 0-based | ใช้ทำอะไร                                         |
| -------------------- | -----------------------------: | --------------: | ------------------------------------------------- |
| ID source            |            `SRC_IDX.SOURCE_ID` |               1 | อ้างอิงกลับแถวต้นทาง                              |
| วันที่ส่ง            |        `SRC_IDX.DELIVERY_DATE` |               2 | วิเคราะห์งานตามวัน                                |
| พิกัดรวม             |      `SRC_IDX.LATLNG_COMBINED` |               4 | แหล่งพิกัดรวมจากหน้างาน                           |
| คนขับ                |          `SRC_IDX.DRIVER_NAME` |               5 | ข้อมูลปฏิบัติการ                                  |
| Shipment             |          `SRC_IDX.SHIPMENT_NO` |               7 | เชื่อมกับงานขนส่ง                                 |
| Invoice              |           `SRC_IDX.INVOICE_NO` |               8 | ใช้ dedupe/upsert FACT                            |
| เจ้าของสินค้า        |         `SRC_IDX.SOLD_TO_NAME` |              11 | ใช้รายงาน/บริบท                                   |
| ชื่อปลายทางจริง      |      `SRC_IDX.RAW_PERSON_NAME` |              12 | เข้า `resolvePerson()`                            |
| Email พนักงาน        |       `SRC_IDX.EMPLOYEE_EMAIL` |              13 | เชื่อมไป EMPLOYEE sheet                           |
| Lat                  |                  `SRC_IDX.LAT` |              14 | เข้า `resolveGeo()`                               |
| Lng                  |                  `SRC_IDX.LNG` |              15 | เข้า `resolveGeo()`                               |
| ที่อยู่ดิบ           |          `SRC_IDX.RAW_ADDRESS` |              18 | เข้า `resolvePlace()`/review                      |
| ที่อยู่จาก LatLong   |        `SRC_IDX.RESOLVED_ADDR` |              24 | ช่วยสร้าง Place ที่สะอาดกว่า                      |
| สถานะ sync           |          `SRC_IDX.SYNC_STATUS` |              36 | กันประมวลผลซ้ำ                                    |
| ชื่อจริงที่ยืนยัน    | `SRC_IDX.DRIVER_VERIFIED_NAME` |              37 | ชื่อลูกค้าปลายทางจริง (V5.5.014 เพิ่ม)            |
| ที่อยู่จริงที่ยืนยัน | `SRC_IDX.DRIVER_VERIFIED_ADDR` |              38 | ชื่อสถานที่อยู่ลูกค้าปลายทางจริง (V5.5.014 เพิ่ม) |

### 4.2 Entry Points ของ Group 1

| Function                                                          | ไฟล์:ไลน์                          | หน้าที่                                                            |
| ----------------------------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------ |
| `runMatchEngine()`                                                | `10_MatchEngine.gs:68`             | Pipeline หลัก (ผูกเมนู) — lock → ctx → loop → finalize             |
| `processOneRow(srcObj)`                                           | `10g_MatchRowProcessor.gs:50`      | ประมวลผล 1 แถว (resolve → tie-break → decision → execute)          |
| `makeMatchDecision(...)`                                          | `10_MatchEngine.gs:499`            | Dispatcher 9 rules → `{action, reason, confidence, priority}`      |
| `executeDecision(...)`                                            | `10g_MatchRowProcessor.gs:105`     | Switch ตาม action → AUTO_MATCH/CREATE_NEW/REVIEW handler           |
| `autoEnrichAliasesFromFactBatch_(factBatch)`                      | `10f_MatchAliasEnrichment.gs:109`  | Single Writer ของ alias ใน pipeline ปกติ                           |
| `runTestMatchDryRun_(maxRows, forceAllRows)`                      | `10d_MatchTestHarness.gs:58`       | Dry-run mode (ไม่เขียน master) — เขียน TEST_MATCH_RESULTS          |
| `resolveAndPersist_(...)`                                         | `10e_MatchResolvePersist.gs:60`    | Q_REVIEW reprocessing gateway (MERGE_TO_CANDIDATE หรือ CREATE_NEW) |
| `resolvePerson / resolvePlace / resolveGeo / resolveDestination`  | `06:58 / 07:54 / 08:69 / 09:46`    | Public resolve services (read-only)                                |
| `createPerson / createPlace / createGeoPoint / createDestination` | `06:600 / 07:732 / 08:227 / 09:89` | Master CRUD (writers จริง)                                         |
| `createGlobalAlias`                                               | `21_AliasService.gs:106`           | PUBLIC alias writer — มี caller 5 จุด (ดู 4.7)                     |

> **หมายเหตุสถาปัตยกรรม:** Group 1 ถูก split ออกเป็น 7 ไฟล์ตั้งแต่ V6.0.050–V6.0.051 เพื่อลด single point of fragility:
>
> - `10_MatchEngine.gs` — lifecycle + makeMatchDecision dispatcher + persistResult_ + tie-breaker
> - `10b_MatchDecision.gs` — 9 decision rules + scoring
> - `10d_MatchTestHarness.gs` — dry-run harness
> - `10e_MatchResolvePersist.gs` — Q_REVIEW resolve/persist
> - `10f_MatchAliasEnrichment.gs` — alias enrichment (Single Writer)
> - `10g_MatchRowProcessor.gs` — row processor (processOneRow + executeDecision + 3 handlers)
> - `10h_MatchAutoResume.gs` — auto-resume + stop signal

### 4.3 ขั้นตอนประมวลผล Group 1 (end-to-end)

```text
runMatchEngine()                                       # 10_MatchEngine.gs:68
├─ clearPipelineStopSignal_()                          # 10h:268
├─ acquireMatchEngineLock_()                           # 10:163 — LockService.tryLock
├─ runPipelinePreflight() [optional]                   # external guard (24:1126)
├─ prepareMatchEngineContext_()                        # 10:182
│  ├─ resetProcessingState_()                          # 10h:48 — ลบ MATCH_CHECKPOINT_* props เก่า
│  ├─ loadSourceBatch_() → getUnprocessedRows()        # 04_SourceRepository:144
│  │     (filter SYNC_STATUS — ข้ามแถวที่ SUCCESS/ERROR/REVIEW)
│  └─ return ctx {pendingRows, factBatch=[], reviewBatch=[], statsSets, …}
├─ runMatchEngineLoop_(ctx, startTime)                 # 10:226
│  FOR each srcObj in ctx.pendingRows:
│  ├─ [time guard every iteration] if elapsed > TIME_LIMIT_MS → installAutoResume + return
│  ├─ [stop signal check every 10 rows] isPipelineStopRequested_() → clearPipelineStopSignal + return
│  ├─ processOneRow(srcObj)                            # 10g:50
│  │  ├─ resolvePerson(srcObj.rawPersonName, null, {soldToName})    # 06:58
│  │  ├─ resolvePlace(srcObj.rawPlaceName||srcObj.rawAddress,
│  │  │                srcObj.rawAddress)              # 07:54  ← arg 2 คือ rawAddress ไม่ใช่ province
│  │  ├─ resolveGeo(srcObj.rawLat, srcObj.rawLng)      # 08:69
│  │  ├─ [if NEEDS_REVIEW && secondBest] breakTieAmongCandidates()  # 10:759
│  │  ├─ makeMatchDecision(srcObj, personResult, placeResult, geoResult)  # 10:499
│  │  └─ executeDecision(srcObj, decision, …)          # 10g:105
│  │     ├─ getEnrichedGeoData(srcObj.rawAddress, srcObj.rawPlaceName)  # 07:379 (3-tier)
│  │     ├─ [if !geoId && hasGeo && status!=='NEARBY_PENDING']
│  │     │     createGeoPoint(...)                     # 08:227 ← ตำแหน่งเดียวที่เขียน M_GEO_POINT
│  │     └─ switch(decision.action):
│  │        ├─ AUTO_MATCH → handleAutoMatch_           # 10g:162
│  │        │  ├─ resolveDestination(pId, plId, gId)   # 09:46
│  │        │  ├─ [if !FOUND && !PARTIAL_MATCH] createDestination(...)  # 09:89
│  │        │  ├─ persistSemanticNotesForEntity_(...)  # 10e:92 → SYS_NOTES
│  │        │  └─ upsertFactDelivery(...)              # 11:49 → FACT_DELIVERY
│  │        ├─ CREATE_NEW → handleCreateNew_           # 10g:226
│  │        │  ├─ createPerson(...)                    # 06:600 ← เขียน M_PERSON
│  │        │  ├─ createGlobalAlias(personUuid, rawName, 'PERSON', 95, 'AUTO_ENRICH_FACT')  # 21:106
│  │        │  │     ← ⚠️ SECONDARY writer of M_ALIAS ระหว่าง CREATE_NEW
│  │        │  ├─ createPlace(...)                     # 07:732 ← เขียน M_PLACE
│  │        │  ├─ resolveDestination() → or createDestination()
│  │        │  └─ upsertFactDelivery(...)
│  │        └─ REVIEW → handleReview_                  # 10g:329
│  │           ├─ enqueueReview(...)                   # 12:59 → Q_REVIEW + สีแถว
│  │           └─ updateSyncStatus_([srcObj], 'REVIEW')  # 04:445
│  ├─ ctx.processed++; accumulate factBatch/reviewBatch/StatsSets
│  ├─ [ทุก BATCH_SIZE=20 แถว] flushBatches_(…)         # 10:437
│  │  ├─ persistResult_(factData, reviewData)          # 10:664
│  │  │  ├─ persistFactRows_(factData)                 # 10:675
│  │  │  │  ├─ FACT_DELIVERY sheet.appendRow batch
│  │  │  │  ├─ invalidateFactInvoiceCache_()
│  │  │  │  └─ autoEnrichAliasesFromFactBatch_(factData)  # 10f:109  ← THE Single Writer
│  │  │  │     ├─ prepareAliasEnrichmentData_()        # 10f:149
│  │  │  │     ├─ processFactRowsForAliases_()         # 10f:247
│  │  │  │     ├─ commitAliasChanges_()                # 10f:492
│  │  │  │     │  ├─ matchCommitGlobalAlias_()          # 10f:651 → M_ALIAS
│  │  │  │     │  ├─ matchCommitPersonAlias_()          # 10f:696 → M_PERSON_ALIAS
│  │  │  │     │  └─ matchCommitPlaceAlias_()           # 10f:720 → M_PLACE_ALIAS
│  │  │  │     └─ cleanupStaleCanonicalAliases_()       # 10f:518
│  │  │  └─ persistReviewRows_(reviewData)             # 10:719 → Q_REVIEW + สี
│  │  ├─ batchUpdatePersonStats_ / PlaceStats / GeoStats / DestStats
│  │  ├─ updateSyncStatus_(successRows, 'SUCCESS')     # 04:445
│  │  ├─ updateSyncStatus_(failedRows, 'ERROR')        # 04:445
│  │  └─ flushGeoCacheIfDirty_()                       # 08:467
├─ finalizeMatchEngine_(ctx, startTime, lock)          # 10:339
│  ├─ flushBatches_() (final)
│  ├─ [if processed+errorCount >= pendingRows.length] removeAutoResume_()  # 10h:276
│  ├─ [if ctx.stoppedByUser] removeAutoResume_() + clearPipelineStopSignal_()
│  └─ logPipelineRun_(ctx, startTime)                  # 10:387 → PIPELINE_RUN_LOG
└─ finally: cleanupMatchEngineRun_(lock)               # 10:151
   ├─ lock.releaseLock()
   ├─ resetAliasEnrichmentContext_()                   # 10f:90
   └─ flushLogBuffer_()
```

**Insight สำคัญ:** `upsertFactDelivery` เกิดขึ้นใน `processOneRow` (per row) แต่ batch-flush ไป sheet จริง ๆ ทุก 20 แถว (BATCH_SIZE) — ไม่ใช่ทีละแถว  
Alias enrichment ถูก trigger **หลัง** flush FACT_DELIVERY ไม่ใช่ตอน per-row

### 4.4 resolvePerson / resolvePlace / resolveGeo / resolveDestination

ทั้ง 4 ฟังก์ชันเป็น **read-only** (lookup + score) — **ไม่ได้เขียน sheet ใด ๆ** การเขียนจริงเกิดใน `create*()` functions ที่ถูกเรียกจาก `handleCreateNew_` หรือ `executeDecision`

#### `resolvePerson(rawName, preNormResult, contextHint)` — `06_PersonService.gs:58`

- **3-arg signature** — `preNormResult` ส่งต่อ normResult ที่คำนวณแล้ว (กัน double normalization), `contextHint` มี `soldToName` สำหรับ Contextual Disambiguation
- Return: `{personId, status, confidence, normResult, secondBestPerson?, secondBestScore?}`
- `status ∈ {LOW_QUALITY, NOT_FOUND, FOUND, NEEDS_REVIEW}`
- Process: `normalizePersonNameFull` → `findPersonCandidates` (6 strategies: M_ALIAS Fast Path → Phone Match → Alias Match → Phonetic Match → Note Search → Double Metaphone) → `scorePersonCandidate` (ensembleNameMatch + Levenshtein + Dice + branch number adjustment) → Contextual Disambiguation using SoldToName ถ้า score ใกล้กัน (±8)
- อ่าน: M_PERSON, M_PERSON_ALIAS, M_ALIAS, FACT_DELIVERY (สร้าง SoldToName index)

#### `resolvePlace(rawName, rawAddress)` — `07_PlaceService.gs:54`

- **2nd arg คือ `rawAddress` ไม่ใช่ `province`** — ใช้สกัด province ภายใน
- Return: `{placeId, status, confidence, normResult}`
- `status ∈ {LOW_QUALITY, NOT_FOUND, FOUND, NEEDS_REVIEW, BRANCH_MATCH}`
- Process: `normalizePlaceName` → `extractProvince_(rawAddress)` → `findPlaceCandidates` (5 strategies) → `scorePlaceCandidate` (คำนวณ 2 scores จาก rawPlaceName + rawAddress เอา max) → `tryMatchBranch` fallback (CHAIN_STORE_LIST match, score 75-85)
- อ่าน: M_PLACE, M_PLACE_ALIAS, M_ALIAS, SYS_TH_GEO (ผ่าน `enrichByDictionary`)

#### `resolveGeo(lat, lng)` — `08_GeoService.gs:69`

- Validate lat/lng numeric + bounds (5.5-20.5 lat, 97.5-105.7 lng — ประเทศไทย)
- Return: `{geoId, status, confidence, distanceM, issue_type?, candidateGeoIds?}`
- `status ∈ {INVALID, OUT_OF_BOUNDS, NOT_FOUND, FOUND, NEARBY_PENDING}`
- `findGeoCandidates_` (3×3 grid filter ด้วย `GEO_GRID_SIZE=0.01`) → haversine → `geoClassifyDistance_` (tiered: ≤radius=FOUND, ≤120m=GEO_NEARBY_YELLOW, ≤150m=GEO_NEARBY_ORANGE, >150m=NOT_FOUND)
- อ่าน: M_GEO_POINT (loadAllGeos_)

#### `resolveDestination(personId, placeId, geoId)` — `09_DestinationService.gs:46`

- **Trinity required** — `!personId || !placeId || !geoId` → INSUFFICIENT
- Return: `{destId, status, isNew}`
- Exact match (P+PL+G) → FOUND; partial (P+G only) → PARTIAL_MATCH; else NOT_FOUND
- อ่าน: M_DESTINATION

### 4.5 `makeMatchDecision` — Dispatcher 9 Rules

อยู่ที่ `10_MatchEngine.gs:499` (V6.0.030 แยก logic ไป `10b_MatchDecision.gs`)

ลอง 9 rules ตามลำดับ คืน rule แรกที่ match:

| Rule          | เงื่อนไข                                              | Action                                                 | Reason                              | Confidence               |
| ------------- | ----------------------------------------------------- | ------------------------------------------------------ | ----------------------------------- | ------------------------ |
| 1 (10b:53)    | `!srcObj.hasGeo`                                      | REVIEW                                                 | INVALID_LATLNG                      | 0                        |
| 2 (10b:70)    | person/place status==='LOW_QUALITY'                   | REVIEW                                                 | LOW_QUALITY_DATA                    | 0                        |
| 3 (10b:91)    | isGeoInMaster && geoProvince ≠ srcProvince            | REVIEW                                                 | GEO_PROVINCE_CONFLICT               | 50                       |
| 3.5 (10b:125) | geoResult.status==='NEARBY_PENDING'                   | REVIEW                                                 | GEO_NEARBY_YELLOW/ORANGE            | 50                       |
| 4 (10b:147)   | isGeoInMaster && isPersonInMaster && isPlaceInMaster  | **AUTO_MATCH**                                         | MATCH_FULL                          | weightedScore            |
| 5 (10b:180)   | isGeoInMaster && isPersonInMaster (place optional)    | **AUTO_MATCH** (หรือ REVIEW ถ้า >1km)                  | MATCH_GEO / GEO_ANCHOR_FAR_APART    | ≤95                      |
| 5b (10b:238)  | isGeoInMaster && isPlaceInMaster && !isPersonInMaster | REVIEW                                                 | GEO_ANCHOR_PLACE_ONLY_NO_NAME       | ≤70                      |
| 6 (10b:269)   | person/place NEEDS_REVIEW                             | **AUTO_MATCH** ถ้า ≤GEO_RADIUS_M(100m), ไม่งั้น REVIEW | MATCH_FUZZY / FUZZY_MATCH_FAR_APART | max(person, place) 50-90 |
| 7 (10b:337)   | hasGeoInSource && !isGeoInMaster                      | **CREATE_NEW**                                         | NEW_GEO_WITH_GPS                    | 100                      |
| 8 (10b:353)   | hasGeoInSource                                        | **CREATE_NEW**                                         | NEW_GEO_FROM_GPS                    | 90                       |
| Default       | —                                                     | REVIEW                                                 | NEW_RECORD_PENDING                  | 0                        |

**Decision action values มี 3 ตัวเท่านั้น:** `AUTO_MATCH`, `CREATE_NEW`, `REVIEW`  
(`NEEDS_REVIEW` เป็น resolve status ไม่ใช่ decision action)

**Weighted scoring** (`10b:431 calculateWeightedScore`): geo=0.35 + person=0.45 + place=0.20 (V6.0.016 rebalanced — name เป็นหลัก)  
Dynamic shift (`calcDynamicWeights_` 10b:380): ถ้า rawAddress < 10 chars → shift 0.08 จาก place→person; ถ้า person confidence ≥95 → shift 0.04

### 4.6 `executeDecision` — 3 Action Handlers

| Action         | Handler                      | ทำอะไร                                                                                                                                                                                                                                                                                   |
| -------------- | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AUTO_MATCH** | `handleAutoMatch_` (10g:162) | Defer stats updates (สะสม ID ใน Set); flag PARTIAL_MATCH_NO_PLACE/NO_PERSON; `resolveDestination` → reuse หรือ `createDestination`; `persistSemanticNotesForEntity_` → SYS_NOTES; `upsertFactDelivery` → FACT_DELIVERY. **ไม่ create Person/Place/Geo ใหม่** (มีอยู่แล้ว)                |
| **CREATE_NEW** | `handleCreateNew_` (10g:226) | `createPerson` (ถ้า !personId) → `addEntityToEnrichmentContext_` + `createGlobalAlias(personUuid, rawPersonName, 'PERSON', 95, 'AUTO_ENRICH_FACT')` ← ⚠️ **SECONDARY M_ALIAS writer**; `createPlace` (ถ้า !placeId); `resolveDestination` → or `createDestination`; `upsertFactDelivery` |
| **REVIEW**     | `handleReview_` (10g:329)    | `enqueueReview(srcObj, decision, …)` → Q_REVIEW (เขียนแถว + สีตาม issue_type); `updateSyncStatus_([srcObj], 'REVIEW')`. **ไม่ create FACT row** (กัน null-FK garbage)                                                                                                                    |

### 4.7 Single Writer Pattern — ความจริง

`autoEnrichAliasesFromFactBatch_` เป็น **Single Writer ใน pipeline ปกติ** แต่เป็น convention ไม่ได้ enforce — `createGlobalAlias` (21:106) เป็น PUBLIC alias writer ที่ถูกเรียกจาก 5 จุด:

| Caller                                           | File:Line                        | Source             | Purpose                                                                                   |
| ------------------------------------------------ | -------------------------------- | ------------------ | ----------------------------------------------------------------------------------------- |
| `autoEnrichAliasesFromFactBatch_` (via internal) | 10f                              | `AUTO_ENRICH_FACT` | Single Writer ใน pipeline ปกติ (หลัง flush FACT_DELIVERY)                                 |
| `handleCreateNew_`                               | `10g_MatchRowProcessor.gs:257`   | `AUTO_ENRICH_FACT` | เขียน alias ทันทีหลัง createPerson (V6.0.015 P2.5) — ทำให้แถวถัดไปใน batch match เร็วขึ้น |
| `resolveAndPersistMerge_` (Person)               | `10e_MatchResolvePersist.gs:213` | `HUMAN`            | Self-Healing Alias จาก Q_REVIEW MERGE_APPROVED                                            |
| `resolveAndPersistMerge_` (Place)                | `10e_MatchResolvePersist.gs:230` | `HUMAN`            | เหมือนด้านบน สำหรับ Place                                                                 |
| `mergePersonRecords`                             | `06_PersonService.gs:817`        | `ADMIN_MERGE_ACT`  | Alias สร้างตอน admin-initiated person merge                                               |

เพิ่มเติม `populateAliasFromSCGRawData_` (21:1339) และ `populateAliasFromFactDelivery_` (21:1484) เป็น admin-triggered batch writers ที่เขียน M_ALIAS โดยตรง (ไม่ผ่าน `createGlobalAlias`)

### 4.8 `21_AliasService.gs` vs `21b_AliasSafeguard.gs`

**`21_AliasService.gs`** มี:

- `createGlobalAlias` (PUBLIC, ใช้โดย 5 callers ข้างต้น)
- `fastLookupByShipToName` (21:593) — **Group 2 fast-track lookup** (คืน coordinates + destId ผ่าน M_ALIAS reverse index)
- `populateAliasFromSCGRawData_` (21:1339) และ `populateAliasFromFactDelivery_` (21:1484) — admin batch writers พร้อม checkpoint/resume + auto-resume
- `MIGRATION_HybridAliasSystem` (21:821) — one-time migration tool
- `assignMasterUuidIfMissing` (21:720) และ `backfillAliasAuditFields` (21:245) — admin repair utilities

**`21b_AliasSafeguard.gs` — CHECKER only, ไม่ใช่ writer:**

- **Layer 1:** `validateAliasStructure_` (21b:66) — Levenshtein similarity floor `MIN_SIMILARITY_RATIO=0.5` — reject aliases ที่ dissimilar จาก canonical มากเกินไป
- **Layer 5:** `checkAliasCircuitBreaker_` (21b:145) — daily rate limit `MAX_DAILY_ALIAS_WRITES=50` — trip เมื่อเกิน limit เก็บ remaining เป็น PENDING
- Entry point: `runAliasSafeguardForHumanAlias_` (21b:201) — ถูกเรียกเฉพาะจาก `createGlobalAlias` เมื่อ `source='HUMAN'` (21:115) — **auto-alias bypass safeguard ทั้งหมด**
- Layers 2/3/4 (Repetition Consensus, Conflict Detection, Probation Lifecycle) — **deferred ยังไม่ implement** (ดู comment ที่ 21b:14-17)

### 4.9 Auto-Resume / Idempotency — `10h_MatchAutoResume.gs`

| Function                       | ไลน์ | หน้าที่                                                                                  |
| ------------------------------ | ---- | ---------------------------------------------------------------------------------------- |
| `resetProcessingState_()`      | 48   | ลบ `MATCH_CHECKPOINT_*` props เก่า — ไม่ได้ save/load checkpoint อีกต่อไป                |
| `installAutoResume_(funcName)` | 73   | สร้าง time-based trigger `ScriptApp.newTrigger().timeBased().after(60_000).create()`     |
| `removeAutoResume_()`          | 276  | ลบ trigger เมื่อ process ครบ หรือ user-stopped                                           |
| `isPipelineStopRequested_()`   | 252  | อ่าน `PIPELINE_STOP_REQUESTED` property — เรียกทุก 10 แถว                                |
| `clearPipelineStopSignal_()`   | 268  | ลบ stop signal — เรียกตอนเริ่ม runMatchEngine + user stop + เมนู "🟢 ยกเลิก Stop Signal" |

**Resume mechanism:** เดิมมี `saveCheckpoint_`/`loadCheckpoint_` แต่ถูกลบใน REF-018 — resume ตอนนี้ใช้ `SYNC_STATUS` filtering ใน `getUnprocessedRows()` (04_SourceRepository:144) แทน คือแถวที่ processed แล้วจะถูกกรองออกโดยอัตโนมัติ

**Idempotency:** `upsertFactDelivery` (11:49) เป็น dedup gate — เช็ค hash `invoiceNo + deliveryDate` ก่อน insert

### 4.10 Dry-Run Harness — `10d_MatchTestHarness.gs`

`runTestMatchDryRun_(maxRows, forceAllRows)` ที่ไลน์ 58:

- โหลด source rows ผ่าน `loadSourceBatch_()` (default) หรือ `getAllSourceRowsForceAll()` (force all ข้าม SYNC_STATUS filter)
- Per row: mirror `processOneRow` resolution แบบเดียวกัน — resolvePerson + resolvePlace + resolveGeo + tie-break + makeMatchDecision
- **ไม่เรียก `executeDecision()`** — ไม่เขียน master/fact/review/alias ใด ๆ
- **เขียน TEST_MATCH_RESULTS เท่านั้น** — clear-and-replace (คอลัมน์: source_row, invoice_no (masked), person_name (truncated 100), place_name, action, reason, confidence, evidence)
- 5-minute time guard (DRY_RUN_TIME_LIMIT_MS = 300000) เช็คทุก 10 แถว
- Trigger: เมนู `runTestMatchDryRun_UI` / `runTestMatchDryRunForceAll_UI` และ WebApp action

### 4.11 GeoDictionaryBuilder / ThGeoService — Role ใน Group 1

Group 1 ใช้ `SHEET.SYS_TH_GEO` ทางอ้อมผ่าน `getEnrichedGeoData()` (ใน `07_PlaceService.gs:379`) ซึ่งเป็น shared geo-enrichment helper ที่ถูกเรียกจาก:

- `executeDecision` (10g:116) — สำหรับ AUTO_MATCH และ CREATE_NEW
- `resolveAndPersistCreate_` (10e:299)
- `resolveAndPersistMerge_` (10e:173)
- `reprocResolveOrCreatePlaceForReview_` (10e:450)

`getEnrichedGeoData(rawAddress, rawPlaceName)` ใช้ **3 tiers**:

1. **Tier 0+1 (Dictionary)** — `enrichByDictionary_` (07:411) → เรียก `extractGeoFromAddress` (20:45) และ `scanAddressAgainstDictionary` (16:334) — ทั้งคู่อ่าน `SYS_TH_GEO` ผ่าน `loadCachedGeoRows_` (16:396)
2. **Tier 2 (Regex+Fuzzy)** — `enrichByRegexFuzzy_` (07:455) → ใช้ `extractProvince_/District_/SubDistrict_` regex + `lookupPostcodeByArea` (16:253) สำหรับ fuzzy match
3. **Tier 3 (Postcode)** — `enrichByPostcode_` (07:504) → `lookupByPostcode` (16:236)

คืน `{province, district, subDistrict, postcode, fullAddress, houseNumber, source}` โดย `source ∈ {'dictionary','regex_fuzzy','postcode','none'}`

`20_ThGeoService.gs` ยังมี `populateGeoMetadata` (ไลน์ 136) — admin-only migration tool เติม 16 metadata columns (F-P) ใน SYS_TH_GEO จาก source columns (A-E)

`16_GeoDictionaryBuilder.gs` มี `buildGeoDictionary` (ไลน์ 75) — admin-only tool สร้าง postcode map + province set + district map จาก SYS_TH_GEO และ cache ไว้ มี checkpoint/resume support

### 4.12 ตารางที่ Group 1 เขียน

| ปลายทาง                | ฟังก์ชันที่เขียน                                   | หน้าที่                                                              |
| ---------------------- | -------------------------------------------------- | -------------------------------------------------------------------- |
| `M_PERSON`             | `createPerson` (06:600)                            | Master ของชื่อปลายทาง/บุคคล/ร้าน/ลูกค้า                              |
| `M_PLACE`              | `createPlace` (07:732)                             | Master ของสถานที่/ที่อยู่                                            |
| `M_GEO_POINT`          | `createGeoPoint` (08:227)                          | Master ของพิกัด GPS                                                  |
| `M_DESTINATION`        | `createDestination` (09:89)                        | จุดเชื่อม Person + Place + Geo                                       |
| `FACT_DELIVERY`        | `upsertFactDelivery` (11:49)                       | ประวัติธุรกรรมการส่งจริง                                             |
| `Q_REVIEW`             | `enqueueReview` (12:59)                            | คิวให้คนตรวจในเคสไม่มั่นใจ                                           |
| `M_ALIAS`              | `autoEnrichAliasesFromFactBatch_` + 4 writers อื่น | ชื่อแฝง global                                                       |
| `M_PERSON_ALIAS`       | `autoEnrichAliasesFromFactBatch_`                  | ชื่อแฝง Person                                                       |
| `M_PLACE_ALIAS`        | `autoEnrichAliasesFromFactBatch_`                  | ชื่อแฝง Place                                                        |
| `SYS_NOTES`            | `persistSemanticNotesForEntity_` (10e:92)          | Semantic Note Parser storage — extract structured notes จาก raw text |
| `PIPELINE_RUN_LOG`     | `logPipelineRun_` (10:387)                         | Stats per pipeline run (12 cols)                                     |
| `TEST_MATCH_RESULTS`   | `runTestMatchDryRun_` (10d:58)                     | Dry-run output (8 cols)                                              |
| `SYS_NEGATIVE_SAMPLES` | `markAsNegativeSample_` (12:881)                   | บันทึก IGNORE'd matches — กัน autoEnrich สร้าง alias ผิดในรอบถัดไป   |
| `SYS_AUDIT_TRAIL`      | `logAuditTrail` (26:108)                           | CREATE/UPDATE/DELETE/MERGE on M_ALIAS + Q_REVIEW                     |

---

## 5. Group 2: SCG API / Daily Job / Coordinate Fill

### 5.1 ชีตต้นทางและปลายทาง

| ขั้น | ชีต                                    | หน้าที่                                                                 |
| ---- | -------------------------------------- | ----------------------------------------------------------------------- |
| 1    | `Input`                                | ใส่ Cookie (ตอนนี้เก็บใน PropertiesService ไม่ใช่ cell) และ Shipment No |
| 2    | SCG API                                | แหล่งข้อมูลแผนงานประจำวัน                                               |
| 3    | `ตารางงานประจำวัน`                     | เก็บงานที่โหลดจาก API และใช้ใน AppSheet                                 |
| 4    | `M_ALIAS`, `M_PERSON`, `M_DESTINATION` | ฐานค้นหาพิกัดจาก Master                                                 |
| 5    | `LatLong_Actual` ใน `ตารางงานประจำวัน` | พิกัดที่ระบบเติมให้ใช้งานจริง                                           |
| 6    | `สรุป_เจ้าของสินค้า`, `สรุป_Shipment`  | รายงานสรุปงาน                                                           |
| 7    | `RPT_DATA_QUALITY`                     | รายงานคุณภาพข้อมูล (per run)                                            |

### 5.2 โครงสร้าง `ตารางงานประจำวัน`

คอลัมน์ถูกกำหนดใน `DATA_IDX` ที่ `01_Config.gs:445-478` (31 คอลัมน์):

```javascript
const DATA_IDX = Object.freeze({
  JOB_ID: 0,
  PLAN_DELIVERY: 1,
  INVOICE_NO: 2,
  SHIPMENT_NO: 3,
  DRIVER_NAME: 4,
  TRUCK_LICENSE: 5,
  CARRIER_CODE: 6,
  CARRIER_NAME: 7,
  SOLD_TO_CODE: 8,
  SOLD_TO_NAME: 9,
  SHIP_TO_NAME: 10, // ← anchor หลัก
  SHIP_TO_ADDR: 11, // ← tie-breaker (V5.5.022-PATCH1)
  LATLNG_SCG: 12, // ← เก็บไว้แสดง ไม่ใช้
  MATERIAL: 13,
  QTY: 14,
  QTY_UNIT: 15,
  WEIGHT: 16,
  DELIVERY_NO: 17,
  DEST_COUNT: 18,
  DEST_LIST: 19,
  SCAN_STATUS: 20,
  DELIVERY_STATUS: 21,
  EMAIL: 22,
  TOT_QTY: 23,
  TOT_WEIGHT: 24,
  SCAN_INV: 25,
  LATLNG_ACTUAL: 26, // ← ผลลัพธ์จาก Master
  OWNER_LABEL: 27,
  SHOP_KEY: 28, // ← FK สำหรับ join กับ SOURCE sheet
  DRIVER_VERIFIED_NAME: 29, // V5.5.014 เพิ่ม — copy จาก SOURCE col 37
  DRIVER_VERIFIED_ADDR: 30 // V5.5.014 เพิ่ม — copy จาก SOURCE col 38
});
```

คอลัมน์ที่ต้องเข้าใจเป็นพิเศษ:

| คอลัมน์                                 | Constant                                 | ใช้จริงหรือไม่                                  | เหตุผล                                                                                     |
| --------------------------------------- | ---------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `ShipToName`                            | `DATA_IDX.SHIP_TO_NAME`                  | **anchor หลัก** สำหรับ lookup (Tier 0 + Tier 1) | ผูกกับ Master/Alias ได้ดีที่สุด                                                            |
| `ShipToAddress`                         | `DATA_IDX.SHIP_TO_ADDR`                  | **tie-breaker เท่านั้น** (V5.5.022-PATCH1)      | ข้อมูล API มักมีแค่อำเภอ — ใช้แค่ตอน ShipToName match หลาย destination                     |
| `LatLong_SCG`                           | `DATA_IDX.LATLNG_SCG`                    | ไม่ใช้                                          | ป้องกันพิกัดผิดที่ยังไม่ verified — ใช้แค่เก็บไว้แสดง                                      |
| `LatLong_Actual`                        | `DATA_IDX.LATLNG_ACTUAL`                 | ผลลัพธ์                                         | ได้จาก Master เท่านั้น (ค่าว่าง = ไม่พบ)                                                   |
| `ShopKey`                               | `DATA_IDX.SHOP_KEY`                      | FK สำหรับ join                                  | สร้างจาก `buildShopKey_(shipmentNo, shipToName)` — ใช้ใน `copyDriverVerifiedToDailyJob_()` |
| `Email พนักงาน`                         | `DATA_IDX.EMAIL`                         | ผลลัพธ์                                         | จาก `enrichEmployeeEmailsToDailyJob_()` lookup EMPLOYEE sheet                              |
| `ชื่อเจ้าของสินค้า_Invoice_ที่ต้องสแกน` | `DATA_IDX.OWNER_LABEL`                   | ผลลัพธ์                                         | จาก `aggregateShopData_()` (SoldToName)                                                    |
| `DRIVER_VERIFIED_NAME`                  | `DATA_IDX.DRIVER_VERIFIED_NAME` (col 29) | ผลลัพธ์                                         | copy จาก SOURCE col 37 ผ่าน ShopKey join (V5.5.014)                                        |
| `DRIVER_VERIFIED_ADDR`                  | `DATA_IDX.DRIVER_VERIFIED_ADDR` (col 30) | ผลลัพธ์                                         | copy จาก SOURCE col 38 ผ่าน ShopKey join (V5.5.014)                                        |

### 5.3 Entry Points ของ Group 2

| Function                                          | ไฟล์:ไลน์                      | หน้าที่                                                                                                      |
| ------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `fetchDataFromSCGJWD()`                           | `18_ServiceSCG.gs:120`         | โหลดงานจาก SCG API → `ตารางงานประจำวัน` (entry point หลัก)                                                   |
| `applyMasterCoordinatesToDailyJob()`              | `18_ServiceSCG.gs:601`         | Wrapper ที่เรียก `runLookupEnrichment` + `copyDriverVerifiedToDailyJob_` + `enrichEmployeeEmailsToDailyJob_` |
| `runLookupEnrichment()`                           | `17_SearchService.gs:370`      | Batch lookup ShipToName → เขียน LatLong_Actual + สี                                                          |
| `lookupSingleRow(rowNumber)`                      | `17_SearchService.gs:528`      | Single-row debug lookup                                                                                      |
| `findBestGeoByPersonPlace(rawPerson, rawAddress)` | `17_SearchService.gs:75`       | Core lookup logic (Tier 0 + Tier 1)                                                                          |
| `buildOwnerSummary(optData)`                      | `18_ServiceSCG.gs:836`         | สรุปงานตาม SoldToName → `สรุป_เจ้าของสินค้า`                                                                 |
| `buildShipmentSummary(optData)`                   | `18_ServiceSCG.gs` (section 6) | สรุปงานตาม ShipmentNo + TruckLicense → `สรุป_Shipment`                                                       |
| `buildFullQualityReport()`                        | `13_ReportService.gs:54`       | สรุปคุณภาพข้อมูล → `RPT_DATA_QUALITY`                                                                        |
| `reprocessReviewQueue()`                          | `12b_ReviewReprocessor.gs:51`  | Auto-resolve Q_REVIEW 3 รูปแบบปลอดภัย                                                                        |
| `setSCGCookie_UI()`                               | `18_ServiceSCG.gs:269`         | ตั้งค่า Cookie ผ่าน UI prompt (เก็บใน PropertiesService)                                                     |
| `readInputConfig_(ss)`                            | `18_ServiceSCG.gs:221`         | อ่าน cookie + shipmentString                                                                                 |

### 5.4 Pipeline จริงของ Group 2 (end-to-end)

```text
[User ใส่ Shipment numbers ใน Input sheet (col A, เริ่ม row 2)]
[User set SCG Cookie ผ่านเมนู setSCGCookie_UI → เก็บใน PropertiesService.SCG_COOKIE]

fetchDataFromSCGJWD()                                  # 18_ServiceSCG.gs:120
├─ [Authorization Guard] isAuthorizedOrFail_() — กันคนไม่มีสิทริ์เรียก API
├─ readInputConfig_(ss)                                # 18:221
│  ├─ getSCGCookie_() → PropertiesService (primary) → fallback cell B1
│  │   (ถ้าเจอใน cell B1 → auto-migrate ไป PropertiesService + clear cell — V6.0.036 SECURITY FIX)
│  ├─ อ่าน shipmentNumbers จาก Input sheet (col A ทุกแถว)
│  └─ เขียน shipmentString (join ด้วย comma) ลง cell B3 (SCG_CONFIG.SHIPMENT_STRING_CELL)
├─ callSCGApi_(inputCfg)                               # HTTP POST + retry
├─ flattenShipmentsToRows_(shipments)                  # JSON → flat row array
├─ aggregateShopData_(allFlatData)                     # per-shop qty/weight/epod/invoices
├─ writeDailyJobSheet_(ss, allFlatData)                # 18:528 — clear + bold headers + write rows
│     ← headers ดึงจาก SCHEMA[SHEET.DAILY_JOB] (02_Schema.gs)
├─ [Time Guard check] — ถ้า elapsed > TIME_LIMIT_MS ข้าม enrichment + safeUiAlert
├─ applyMasterCoordinatesToDailyJob()                  # 18:601 (call site: 18:183)
│  ├─ acquireScriptLockOrWarn_(30000, ...)             # LockService 30s timeout (V6.0.009)
│  ├─ [one-time cleanup] ลบ stale LOCK_ENRICHMENT property จาก pre-V6.0.009
│  ├─ runLookupEnrichment()                            # 17:370 — เขียน LatLong_Actual + สี
│  │  FOR each row in ตารางงานประจำวัน:
│  │  ├─ อ่าน ShipToName (DATA_IDX.SHIP_TO_NAME) + ShipToAddress (DATA_IDX.SHIP_TO_ADDR)
│  │  ├─ findBestGeoByPersonPlace(rawPerson, rawAddress)  # 17:75
│  │  │  ├─ Tier 0: fastLookupByShipToName(cleanName, normResult, rawAddr) → M_ALIAS → M_DESTINATION → lat,lng
│  │  │  └─ Tier 1: resolvePerson(rawName, normResult) → M_PERSON → getDestsByPersonId() → M_DESTINATION → lat,lng
│  │  │     └─ [if หลาย dest + มี rawAddr] selectBestDestByAddress_(dests, rawAddr) # 17:181
│  │  │        → Dice coefficient ≥ 0.70 (V5.5.022-PATCH1)
│  │  ├─ [if existing valid LatLong_Actual] SKIP (กันทับข้อมูลเดิม) — 17:449
│  │  ├─ [if found] write LatLong_Actual + bgColor=COLOR_FOUND (เขียว)
│  │  └─ [if NOT_FOUND] write '' (empty string) + bgColor=COLOR_NOT_FOUND (แดง)
│  ├─ copyDriverVerifiedToDailyJob_()                  # 18:752 — SOURCE sheet → DAILY_JOB cols 29-30 ผ่าน ShopKey join
│  └─ enrichEmployeeEmailsToDailyJob_()                # 18:651 — EMPLOYEE sheet → DAILY_JOB col 22 (ผ่าน DRIVER_NAME match)
├─ buildOwnerSummary(dailyData)                        # 18:836 → สรุป_เจ้าของสินค้า (group by SoldToName)
└─ buildShipmentSummary(dailyData)                     # 18 section 6 → สรุป_Shipment (group by ShipmentNo + TruckLicense)

[Optional — รันแยก]
buildFullQualityReport() → 13:54 → เขียน 1 row ลง RPT_DATA_QUALITY
   (stats: totalFact, autoCount, newCount, reviewCount, errorCount, personCount, placeCount, geoCount, destCount, pendingInQueue)

[Optional — รันแยก]
reprocessReviewQueue() → 12b:51 → auto-resolve Q_REVIEW 3 รูปแบบปลอดภัย (ดู 5.9)
```

### 5.5 `findBestGeoByPersonPlace` — Core Lookup Logic

ที่ `17_SearchService.gs:75`:

```javascript
function findBestGeoByPersonPlace(rawPerson, rawAddress) { ... }
// rawAddress เป็น optional และใช้แค่เป็น tie-breaker
```

**Logic จริง (lines 75-157):**

```text
1. Guard (line 77): empty / <2 chars → NOT_FOUND immediately

2. Tier 0 — M_ALIAS Fast Track (lines 107-129):
   ├─ normalizePersonNameFull(rawName) → cleanName           # 17:97
   ├─ fastLookupByShipToName(cleanName, normResult, rawAddr)  # 21:593
   │     → M_ALIAS.variant_name → master_uuid
   │     → M_PERSON/M_PLACE.master_uuid
   │     → M_DESTINATION → lat,lng
   ├─ if miss และ cleanName !== rawName → retry ด้วย rawName
   └─ if found → return FOUND_ALIAS_FAST

3. Tier 1 — resolvePerson + M_DESTINATION (lines 131-151):
   ├─ resolvePerson(rawName, normResult)                     # 06:58
   ├─ getDestsByPersonId(personId)                           # 09:230 (sort by usageCount desc ภายใน)
   ├─ if multiple + rawAddr → selectBestDestByAddress_(dests, rawAddr)  # 17:181
   │     → Dice coefficient ≥ 0.70 (V5.5.022-PATCH1)
   └─ if found → return FOUND_DOMINANT (confidence 90)

4. NOT_FOUND (lines 153-156):
   return { lat: null, lng: null, status: 'NOT_FOUND', score: 0, ... }
```

> **ShipToName เป็น anchor หลัก** — ShipToAddress ใช้แค่เป็น tie-breaker (ไม่ใช่ fallback) เมื่อ ShipToName match หลาย destination  
> **LatLong_SCG ไม่ถูกใช้** — confirmed ไม่มี code path ที่เอามาเขียน LatLong_Actual

### 5.6 สิ่งที่เขียนลง `LatLong_Actual` เมื่อ NOT_FOUND

จาก `lookupEnrichOneRow_()` (17:479):

```javascript
return { latActual: [''], bgColor: [APP_CONST.COLOR_NOT_FOUND], found: 0, notFound: 1, skipped: 0 };
```

→ **Empty string `''`** (ไม่ใช่ 'NOT_FOUND' string) + **background color แดง** (`APP_CONST.COLOR_NOT_FOUND`)

แถวที่มี `LatLong_Actual` valid อยู่แล้วจะถูก **skip** (17:449-454) — กันทับข้อมูลเดิม

### 5.7 Sheets ที่ Group 2 อ่าน

- **Directly:** `ตารางงานประจำวัน` (R/W ShipToName/ShipToAddress/LatLong_Actual), `Input` (อ่าน cookie + shipments), `ข้อมูลพนักงาน` (lookup email), `SCGนครหลวงJWDภูมิภาค` (lookup DriverVerified)
- **Indirectly via services:** M_ALIAS (fastLookupByShipToName → 21), M_PERSON (resolvePerson → 06), M_DESTINATION (getDestsByPersonId → 09), M_PLACE (loadAllPlaces_ → 07, เฉพาะตอน tie-breaker)
- **M_GEO_POINT ไม่ถูกอ่านโดยตรง** — dest.lat/lng ถูก preload ใน DestinationService

### 5.8 ความสัมพันธ์ของไฟล์ใน Group 2 (Functional vs Folder Label)

> **⚠️ สำคัญ:** "Group 2" เป็น **folder label** ไม่ใช่ functional group ที่แท้จริง — หลายไฟล์ในโฟลเดอร์นี้ให้บริการ Group 1 จริง ๆ

| ไฟล์                       | Folder Label | Functional Group จริง   | เหตุผล                                                                       |
| -------------------------- | ------------ | ----------------------- | ---------------------------------------------------------------------------- |
| `04_SourceRepository.gs`   | Group 2      | **Group 1**             | อ่าน SOURCE sheet ไม่ใช่ DAILY_JOB — feed MatchEngine                        |
| `11_TransactionService.gs` | Group 2      | **Group 1**             | `upsertFactDelivery` — ถูกเรียกจาก MatchEngine เท่านั้น                      |
| `12_ReviewService.gs`      | Group 2      | **SHARED**              | `enqueueReview` จาก Group 1; `applyAllPendingDecisions` จาก Group 2 menu/web |
| `12b_ReviewReprocessor.gs` | Group 2      | Group 1 (auto-resolver) | แก้ Q_REVIEW 3 รูปแบบปลอดภัย                                                 |
| `13_ReportService.gs`      | Group 2      | SHARED                  | `buildFullQualityReport` — รายงานคุณภาพ                                      |
| `15_GoogleMapsAPI.gs`      | Group 2      | **Group 1 + WebApp**    | `@customFunction` สำหรับ sheet cells — ไม่ได้ใช้ใน daily ops                 |
| `17_SearchService.gs`      | Group 2      | **Group 2** ✅          | lookup ShipToName → LatLong_Actual                                           |
| `18_ServiceSCG.gs`         | Group 2      | **Group 2** ✅          | โหลดจาก SCG API + สรุปรายงาน                                                 |

### 5.9 `12_ReviewService` (shared) + `12b_ReviewReprocessor`

**`12_ReviewService.gs`:**

- `enqueueReview(srcObj, decision, ...)` (12:59) — เขียนแถว pending ลง Q_REVIEW (ถูกเรียกจาก **Group 1 MatchEngine** เมื่อ decision=REVIEW)
- `applyAllPendingDecisions()` (12:204) — batch apply decisions (IGNORE/ESCALATE/CREATE_NEW/MERGE_TO_CANDIDATE) จาก **Group 2 menu/web**
- `applyReviewDecision(reviewId, decisionVal, rowData, optTargetRow)` (12:444) — single decision side effects
- `markAsNegativeSample_(rowData)` (12:881) — บันทึก IGNORE'd matches เป็น negative learning samples ใน `SYS_NEGATIVE_SAMPLES`

**`12b_ReviewReprocessor.gs` — ไม่ใช่ re-run Match Engine แบบง่าย ๆ:**

`reprocessReviewQueue()` (12b:51) — auto-resolves **เฉพาะ 3 รูปแบบปลอดภัย**:

- **Group A:** GEO_NEARBY_YELLOW + name match → AUTO_MATCH (GPS 50-200m + Person/Place match)
- **Group B:** NEW_RECORD_PENDING + Geo candidate → CREATE_NEW (GPS ที่จุด known, ชื่อใหม่)
- **Group C:** FUZZY_MATCH score ≥ 85 → AUTO_MATCH (name similarity 85%+)

มี Checkpoint/Resume (`REPROCESS_REVIEW_CHECKPOINT_KEY`)  
เรียก `resolveAndPersist_()` สำหรับเคสปลอดภัย — **ไม่ใช่** full Match Engine pipeline

### 5.10 `13_ReportService.gs`

- สร้าง **ครั้งเดียว**: `buildFullQualityReport()` (13:54) → เขียน `RPT_DATA_QUALITY`
- Stats ที่เก็บ: totalFact (Active only), autoCount, newCount, reviewCount, errorCount, personCount, placeCount, geoCount, destCount, pendingInQueue
- Output row: `[report_date, total_records, auto_matched, reviewed, created_new, failed, match_rate, notes]`
- **ไม่ได้สร้าง buildOwnerSummary / buildShipmentSummary** — สองอันนี้อยู่ใน `18_ServiceSCG.gs`

### 5.11 `15_GoogleMapsAPI.gs` — Custom Function Module (ไม่ใช่ Group 2 dependency)

เป็น `@customFunction` ที่ผู้ใช้พิมพ์ลงใน cell ของ Google Sheet ตรง ๆ ได้:

- `GOOGLEMAPS_DISTANCE`, `GOOGLEMAPS_DURATION`, `GOOGLEMAPS_LATLONG`, `GOOGLEMAPS_ADDRESS`, `GOOGLEMAPS_REVERSEGEOCODE`, `GOOGLEMAPS_COUNTRY`, `GOOGLEMAPS_DIRECTIONS`
- ใช้ `CacheService.getDocumentCache()` (ไม่ใช่ ScriptCache) TTL 6 ชั่วโมง
- ถูก export ไปยัง `08_GeoService.gs` (Group 1 geocoding) และ `22c_WebAppActions.gs` (map analytics view)
- **ไม่ถูกเรียกจาก Group 2 daily ops pipeline เลย**

### 5.12 เส้นทางค้นหาพิกัดแบบย่อ

```text
ตารางงานประจำวัน.ShipToName
  → normalizePersonNameFull()                       # 17:97
  → fastLookupByShipToName()                         # 21:593 — Tier 0 (alias fast track)
      → M_ALIAS.variant_name
      → M_ALIAS.master_uuid
      → M_PERSON.master_uuid / M_PLACE.master_uuid
      → M_DESTINATION
      → lat,lng
  → ถ้า Alias ไม่เจอ: resolvePerson(ShipToName)      # 06:58 — Tier 1
      → M_PERSON.person_id
      → getDestsByPersonId(person_id)                # 09:230 (sort by usageCount desc ในตัว)
      → M_DESTINATION top usageCount
      → [if หลาย destination + มี rawAddr]
        → selectBestDestByAddress_(dests, rawAddr)   # 17:181 — tie-breaker (V5.5.022-PATCH1)
        → Dice coefficient ≥ 0.70
      → lat,lng
  → ถ้าไม่เจอ: LatLong_Actual = '' (empty string)
              bgColor = COLOR_NOT_FOUND (แดง)
              ไม่ fallback ไปที่ address/API/AI/SCG_LatLong
```

### 5.13 SCG Cookie Management (Security)

[V6.0.036 SECURITY FIX] เปลี่ยนจาก cell-primary → PropertiesService-primary:

- `setSCGCookie_UI()` (18:269) — admin-only (ผ่าน `isAuthorizedOrFail_()`), รับ cookie ผ่าน `ui.prompt()`, sanitize ผ่าน `sanitizeCookie_()`, เก็บใน `PropertiesService.SCG_COOKIE`
- ถ้ามี cookie ค้างใน cell B1 → auto-clear ทันที (กัน plaintext leak)
- `getSCGCookie_()` อ่าน PropertiesService เป็น primary → fallback cell B1 (พร้อม auto-migrate)
- `readInputConfig_(ss)` (18:221) เรียก `getSCGCookie_()` — ไม่ได้อ่าน cell ตรง ๆ อีกต่อไป

---

## 6. Group 3: WebApp (Dashboard ออนไลน์)

Group 3 เป็น full-page dashboard SPA ที่ให้ผู้ใช้ดูและจัดการระบบผ่านเว็บ มี 16 ไฟล์ .html รวม ~7,000 บรรทัด

### 6.1 สถาปัตยกรรม

```text
Browser URL (https://script.google.com/macros/s/.../exec)
  → doGet(e) [22_WebApp.gs:51]
  → isAuthorizedDashboardUser_() [22:130]
    → fail → Unauthorized.html
    → pass → Index.html (HtmlService.createTemplateFromFile)
            → inject: appVersion, appName, currentUser, deployedAt
            → initialData = null (force client-side fetch since V6.0)
            → evaluate() + setXFrameOptionsMode(ALLOWALL)

Index.html (309 บรรทัด) — Full-page dashboard SPA
  ← โหลดผ่าน <?!= include_('Filename') ?> 16 partials:
    Api, Auth, StatCard, DataTable, ChartCard, ViewHelpers,
    Dashboard, QReview, FactDelivery, SourceSheet, MatchEngine,
    Search, MapAnalytics, LiveFeed, MobileActions, App

  Tech Stack (CDN + SRI):
  - Tailwind CSS v4 (@tailwindcss/browser@4.3.2)
  - Chart.js 4.4.6
  - Lucide Icons 0.460.0
  - Inter font (Google Fonts)

  Layout:
  - Header (sticky): Logo 🚚 + user info + Mobile Menu button (≡) + Manual Refresh
  - Sidebar (w-56, hidden on mobile): 9 nav buttons
  - Main content (flex-1 p-6): loading spinner / error / viewContainer
  - Toast container (bottom-right)
```

### 6.2 Views (10 ไฟล์ใน `views/`)

| File                 | ไลน์  | Module              | หน้าที่                                                                                                                   |
| -------------------- | ----- | ------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `Dashboard.html`     | 638   | `DashboardView`     | KPI cards + 7-day trend chart + top issues + sheet status                                                                 |
| `FactDelivery.html`  | 562   | `FactDeliveryView`  | Paginated FACT_DELIVERY table + status filter                                                                             |
| `QReview.html`       | 1,012 | `QReviewView`       | Q_REVIEW queue + decision buttons (CREATE_NEW/MERGE/IGNORE/ESCALATE) + candidate detail panel                             |
| `SourceSheet.html`   | 579   | `SourceSheetView`   | Raw SCG AppSheet data browser + filter by SYNC_STATUS                                                                     |
| `MatchEngine.html`   | 564   | `MatchEngineView`   | Match Engine metrics: score distribution, match reasons, match actions                                                    |
| `Search.html`        | 358   | `SearchView`        | Search by name/address/phone/postcode → calls `searchLocations()`                                                         |
| `MapAnalytics.html`  | 159   | `MapAnalyticsView`  | Map of delivery points (Leaflet via CDN)                                                                                  |
| `LiveFeed.html`      | 93    | `LiveFeedView`      | Real-time Match Engine monitor (polls `getMatchEngineLiveStatus`)                                                         |
| `MobileActions.html` | 426   | `MobileActionsView` | Mobile menu mirror ของ Google Sheet custom menu — 37 action buttons จาก registry, two-press confirm สำหรับ danger actions |
| `Unauthorized.html`  | 100   | (standalone HTML)   | แสดงเมื่อ `isAuthorizedDashboardUser_()` คืน false                                                                        |

### 6.3 JS Modules

**`js/App.html` (663 บรรทัด):** Router + view orchestrator + toast

- `init()` on DOMContentLoaded → `auth.init()` → `bindEvents_()` → `refresh_(true)` → fetches `getDashboardData()` → `renderCurrentRoute_(false)`
- จัดการ `hashchange` สำหรับ browser back/forward (V6.0.010 P3.11)
- Auto-polling ถูก **ลบ** ตั้งแต่ V5.5.049 — ต้องกด Manual Refresh

**`js/Api.html` (243 บรรทัด):** Promisified `google.script.run` wrapper (V6.0.008)

- 30s timeout
- Max 6 concurrent calls (CLIENT_OVERLOAD reject)
- 13 API methods: `ping, getDashboardData, getFactDeliveryPage, getQReviewPage, submitReviewDecision, getReviewDetail, getMatchEngineMetrics, getSourcePage, searchLocations, getMapAnalyticsData, getMatchEngineLiveStatus, getWebAppActionRegistry, runWebAppAction` + `getStats` (diagnostic)

**`js/Auth.html` (157 บรรทัด):** Frontend session management (defense-in-depth; server re-validates ทุก call)

- 30-min inactivity timeout ผ่าน localStorage (`lmds_session` key)
- Refreshes on user interaction (click/keydown/scroll/touchstart) — debounced 30s
- Dispatches `auth:session-expired` event on timeout
- **ไม่ใช่ RBAC** — เป็น frontend session timer อย่างเดียว

### 6.4 Components (`js/components/`)

| File               | ไลน์ | หน้าที่                                                                                                           |
| ------------------ | ---- | ----------------------------------------------------------------------------------------------------------------- |
| `StatCard.html`    | 219  | Single-stat card with label + icon + trend arrow                                                                  |
| `ChartCard.html`   | 160  | Wrapper around Chart.js with title + subtitle + canvas                                                            |
| `DataTable.html`   | 326  | Sortable + paginated table with loading state                                                                     |
| `ViewHelpers.html` | 187  | Shared helpers: `escapeHtml`, `formatDate`, `formatNumber`, `truncate` (extracted เพื่อลด SonarCloud duplication) |

### 6.5 CSS (`css/Styles.html`, 240 บรรทัด)

Custom CSS ที่เสริม Tailwind:

- `html { scroll-behavior: smooth }`
- Custom scrollbar (8px wide, gray-300 thumb)
- `.nav-link.active` (blue-50 bg, blue-700 text, font-weight 600)
- CSS variables สำหรับ LMDS color palette (`--color-lmds-found: #b6d7a8` ฯลฯ — match กับ `APP_CONST.COLOR_*`)

### 6.6 WebApp Pipeline (User flow จริง)

```text
1. User เปิด WebApp URL
2. GAS เรียก doGet(e) [22_WebApp.gs:51]
3. Auth check: isAuthorizedDashboardUser_() อ่าน email จาก Session
   → fail → return Unauthorized.html
   → pass → render Index.html
4. Browser โหลด Index.html + 16 partials
5. DOMContentLoaded → App.init():
   ├─ auth.init() — เริ่ม 30-min session timer
   ├─ refresh_(true) → api.getDashboardData() (server ~4.5s)
   └─ renderCurrentRoute_('dashboard') → DashboardView.render(data)
6. User คลิก sidebar nav (เช่น "Q_REVIEW"):
   → navigateTo_('qreview') [App.html:178]
   → window.location.hash = 'qreview'
   → renderRouteView_('qreview') → QReviewView.render()
7. QReview view โหลดข้อมูล:
   → api.getQReviewPage(0, 50, 'Pending') [Api.html]
   → server 22b:getQReviewPage() [22b:559]
   → คืน paginated rows
8. User เลือก decision (เช่น MERGE_TO_CANDIDATE):
   → api.submitReviewDecision(reviewId, 'MERGE_TO_CANDIDATE', note)
   → server 22c:submitReviewDecision() [22c:87]
      ├─ isAuthorizedDashboardUser_() check
      ├─ requirePermission_('action:approve_review') [RBAC]
      ├─ validateInput_(reviewId, decision, note maxLength 500)
      └─ applyReviewDecision() [12_ReviewService:444]
   → คืน {ok, reviewId, decision, message}
9. QReview view อัพเดทแถว in-place + toast notification
```

### 6.7 MobileActions (37 actions ผ่าน registry)

`MobileActions.html` ใช้ `WEB_APP_ACTION_REGISTRY` (จาก `28_WebAppActions.gs:60`) — 37 actions แต่ละอันมี `{id, label, group, danger, confirmMsg, description, serverFn, icon}`

- `getWebAppActionRegistry()` กรองตาม `isAuthorizedOrFail_()` — admin เห็นทั้งหมด, non-admin เห็นเฉพาะ `danger==='safe'`
- `runWebAppAction(actionId, params)` (28:457) dispatcher — route ไปยัง `serverFn` เช่น `runFullPipeline_Web(params)` (28:542)
- Danger actions ต้องกดยืนยัน 2 ครั้ง (two-press confirm)

### 6.8 22c vs 28 — ไม่ใช่ duplicate

- `22c_WebAppActions.gs` ใช้ **direct named functions** (1 endpoint = 1 function) — สำหรับ action เฉพาะ view (`submitReviewDecision`, `searchLocations`)
- `28_WebAppActions.gs` ใช้ **registry + dispatcher pattern** (37 actions ผ่าน `runWebAppAction(actionId, params)`) — สำหรับ MobileActions menu

ทั้งคู่เรียก function หลังบ้านตัวเดียวกัน เป็น abstraction คนละแบบ

---

## 7. Group 4: Pipeline Manager (ตัวจัดการทำงานอัตโนมัติ)

Group 4 เป็น 1 ไฟล์ขนาด 1,534 บรรทัด ควบคุมการรัน production pipeline ทั้งหมด

### 7.1 วัตถุประสงค์

Standalone batched pipeline manager สำหรับ `runMatchEngine()` ออกแบบมาเพื่อรองรับ dataset 10,000+ แถวที่เกิน Google Apps Script 6-minute execution limit และ 90 min/day Free tier quota

ใช้ Script Properties เก็บ state ทั้งหมด (prefix `PIPELINE_*`)

### 7.2 สิ่งที่จัดการ

**Group 1 เท่านั้น** — เรียก `runMatchEngine()` (จาก `10_MatchEngine.gs`) — **ไม่** ยุ่งกับ Group 2 (SCG daily job / coordinate fill)  
Group 2 (`fetchDataFromSCGJWD`, `applyMasterCoordinatesToDailyJob`) ถูก trigger ด้วย manual menu หรือ MobileActions view เท่านั้น

### 7.3 Trigger

**Time-based trigger** — ไม่ใช่ menu item

ติดตั้งผ่าน `installPipelineTriggers()` (24:440):

- `runPipelineBatch` — ทุก 1 ชั่วโมง, 08:00–22:00 (สูงสุด 15 รอบ/วัน) ที่นาที `:15` (หลีกเวลา 00:00 congestion)
- `resetDailyQuotaJob` — รายวัน 00:05

เริ่มด้วย manual ผ่าน `startPipeline()` (24:868) admin menu ได้

### 7.4 Script Properties State Machine

| Key                        | โครงสร้าง                                                                        | หน้าที่                     |
| -------------------------- | -------------------------------------------------------------------------------- | --------------------------- |
| `PIPELINE_STATE`           | `IDLE \| RUNNING \| PAUSED_QUOTA \| PAUSED_ERRORS \| PAUSED_MANUAL \| COMPLETED` | State machine หลัก          |
| `PIPELINE_CHECKPOINT`      | `{lastRunAt, runCount, totalRuntimeMs, lastBatchRows, startedAt}`                | Checkpoint resume           |
| `PIPELINE_DAILY_QUOTA`     | `{date, runtimeMs, runCount, lastResetAt}`                                       | auto-reset ตอนเปลี่ยนวัน    |
| `PIPELINE_CIRCUIT_BREAKER` | `{consecutiveErrors, lastError, lastErrorAt, pausedAt}`                          | trip เมื่อ error 3 ครั้งติด |
| `PIPELINE_HISTORY`         | last 7 completed pipeline summaries                                              | Audit log                   |

> **⚠️ สำคัญ:** PipelineManager **ไม่ได้** เขียน `PIPELINE_RUN_LOG` sheet — sheet นั้นถูกเขียนโดย `logPipelineRun_()` ใน `10_MatchEngine.gs:387`  
> PipelineManager ใช้ Script Properties สำหรับ state ของตัวเอง

### 7.5 Quota Limits (`PIPELINE_CONFIG` ไลน์ 42)

| Setting                    | ค่า                    | เหตุผล                                   |
| -------------------------- | ---------------------- | ---------------------------------------- |
| `MAX_RUNTIME_MS_PER_DAY`   | 75 นาที (4,500,000 ms) | เหลือ buffer 15 นาทีใต้ 90-min Free tier |
| `MAX_RUNTIME_MS_PER_RUN`   | 4 นาที (240,000 ms)    | buffer ใต้ 6-min GAS hard limit          |
| `MAX_RUNS_PER_DAY`         | 15                     | จำกัดรอบ/วัน                             |
| `MAX_CONSECUTIVE_ERRORS`   | 3                      | trip circuit breaker                     |
| `ERROR_COOLDOWN_MS`        | 1 ชั่วโมง              | cooldown หลัง trip                       |
| `BATCH_RUN_INTERVAL_HOURS` | 1                      | ระยะห่างรอบ                              |
| `BATCH_RUN_START_HOUR`     | 8                      | เริ่ม 08:00                              |
| `BATCH_RUN_END_HOUR`       | 22                     | จบ 22:00                                 |

### 7.6 `runPipelineBatch()` (24:568) — Main Entry Point

ถูกเรียกโดย hourly trigger:

```text
1. Runtime hour check — skip ถ้านอก 08:00–22:59
2. Check state — skip ถ้า COMPLETED/PAUSED_MANUAL/PAUSED_ERRORS
3. If PAUSED_QUOTA → re-check quota (อาจ reset ตอนเปลี่ยนวัน)
4. Check quota (isQuotaAvailable_) → if exhausted → set PAUSED_QUOTA + return
5. Check circuit breaker (isCircuitBreakerTripped_) → if tripped → set PAUSED_ERRORS + Telegram alert + return
6. removeMatchEngineAutoResumeTriggers_() — กัน run stacking กับ MatchEngine's auto-resume
7. Acquire LockService.getScriptLock() (30s timeout) — skip ถ้า batch อื่นกำลังรัน
8. Call runMatchEngine()
9. incrementQuotaUsage_(runtimeMs) + update checkpoint
10. Check Q_REVIEW backlog — warn ถ้า > 100 pending ผ่าน Telegram
11. Remove MatchEngine auto-resume triggers อีกครั้ง (post-run cleanup)
12. If error → recordBatchError_ → if 3rd consecutive → PAUSED_ERRORS + alert
13. If success → recordBatchSuccess_ → check checkHasMoreWork_ (SOURCE rows ที่ SYNC_STATUS != SUCCESS)
14. If no more work → completePipeline_() (set COMPLETED, save history, clear checkpoint)
15. Release lock in finally
```

### 7.7 `runPipelinePreflight(opts)` (24:1126, V6.0.007) — 6 Dependency Checks

ถูกเรียกจาก `runPipelinePreflightStrict_UI` ใน `00_App.gs`:

1. **(BLOCKING)** SOURCE has unprocessed rows (SYNC_STATUS ≠ SUCCESS/REVIEW)
2. **(BLOCKING)** SYS_TH_GEO ≥100 rows
3. **(CONDITIONAL)** GEMINI_API_KEY set (เฉพาะถ้า `AI_CONFIG.USE_AI_REASONING === true`)
4. **(BLOCKING)** M_PERSON exists, ≥12 cols, header col[10] === 'phonetic_primary'
5. **(BLOCKING)** M_PLACE exists, ≥16 cols, header col[14] === 'phonetic_primary'
6. **(WARNING)** M_ALIAS has ≥11 cols (V6.0.003 audit fields)

คืน `{ready, issues, warnings, checks}` — Strict mode throws ถ้ามี issue

### 7.8 Admin Menu Actions

`startPipeline`, `pausePipeline`, `resumePipeline`, `resetPipeline`, `showPipelineStatus`, `resetCircuitBreakerMenu`, `uninstallPipelineTriggers`

### 7.9 Telegram Alerts (`sendPipelineAlert_` 24:1428, V5.5.047)

ส่งผ่าน Telegram Bot API:

- Exponential backoff retry (2s, 4s, 8s) บน 429/5xx
- Fail-safe: ไม่มีทาง throw (alerts ต้องไม่ break pipeline)
- Trigger เมื่อ: circuit breaker trip, batch error trip, Q_REVIEW backlog > 100

---

## 8. ความสัมพันธ์ชีตต่อชีต

### 8.1 Actual delivery flow (Group 1)

```text
SCGนครหลวงJWDภูมิภาค (SOURCE)
  → 04_SourceRepository.gs: getUnprocessedRows() (filter SYNC_STATUS)
       สร้าง srcObj ผ่าน buildSourceObj_()
  → 10_MatchEngine.gs: runMatchEngine() → runMatchEngineLoop_() → processOneRow()
       ├─ 06_PersonService.gs: resolvePerson()    → อ่าน M_PERSON, M_PERSON_ALIAS, M_ALIAS, FACT_DELIVERY
       ├─ 07_PlaceService.gs:  resolvePlace()     → อ่าน M_PLACE, M_PLACE_ALIAS, M_ALIAS, SYS_TH_GEO
       ├─ 08_GeoService.gs:    resolveGeo()       → อ่าน M_GEO_POINT
       ├─ 10_MatchEngine.gs:   makeMatchDecision() (9 rules)
       └─ 10g_MatchRowProcessor.gs: executeDecision()
            ├─ [CREATE_NEW] createPerson() → M_PERSON
            ├─ [CREATE_NEW] createGlobalAlias() → M_ALIAS
            ├─ [CREATE_NEW] createPlace() → M_PLACE
            ├─ [CREATE_NEW/AUTO_MATCH] createGeoPoint() → M_GEO_POINT (ถ้ายังไม่มี)
            ├─ [CREATE_NEW/AUTO_MATCH] resolveDestination()/createDestination() → M_DESTINATION
            ├─ [AUTO_MATCH] persistSemanticNotesForEntity_() → SYS_NOTES
            ├─ [AUTO_MATCH/CREATE_NEW] upsertFactDelivery() → FACT_DELIVERY
            └─ [REVIEW] enqueueReview() → Q_REVIEW
  → [batch ทุก 20 แถว] autoEnrichAliasesFromFactBatch_() → M_ALIAS, M_PERSON_ALIAS, M_PLACE_ALIAS
  → [batch ทุก 20 แถว] updateSyncStatus_(success, 'SUCCESS') / (failed, 'ERROR') → SOURCE col SYNC_STATUS
  → [batch ทุก 20 แถว] batchUpdatePersonStats_/PlaceStats/GeoStats/DestStats → master sheets (last_seen, usage_count)
  → [final] logPipelineRun_() → PIPELINE_RUN_LOG
  → [time guard exceeded] installAutoResume_('runMatchEngine') → trigger 60s
```

### 8.2 Daily job flow (Group 2)

```text
Input (Cookie + ShipmentNos)
  → 18_ServiceSCG.gs: fetchDataFromSCGJWD()
       ├─ readInputConfig_() (cookie จาก PropertiesService, shipmentString จาก Input sheet)
       ├─ callSCGApi_(inputCfg) (HTTP POST + retry)
       ├─ flattenShipmentsToRows_(shipments) (JSON → flat row array)
       ├─ aggregateShopData_(allFlatData) (per-shop qty/weight/epod/invoices)
       └─ writeDailyJobSheet_(ss, allFlatData) (clear + bold headers + write rows)
            → headers จาก SCHEMA[SHEET.DAILY_JOB]
  → 18_ServiceSCG.gs: applyMasterCoordinatesToDailyJob()
       ├─ runLookupEnrichment() [17_SearchService.gs:370]
       │   FOR each row in ตารางงานประจำวัน:
       │   ├─ อ่าน ShipToName (DATA_IDX.SHIP_TO_NAME) + ShipToAddress (DATA_IDX.SHIP_TO_ADDR)
       │   ├─ findBestGeoByPersonPlace(rawPerson, rawAddress)
       │   │   ├─ Tier 0: fastLookupByShipToName() → M_ALIAS → M_DESTINATION → lat,lng
       │   │   └─ Tier 1: resolvePerson() → M_PERSON → getDestsByPersonId() → M_DESTINATION → lat,lng
       │   ├─ [if found] write LatLong_Actual + bgColor=COLOR_FOUND (เขียว)
       │   ├─ [if NOT_FOUND] write '' + bgColor=COLOR_NOT_FOUND (แดง)
       │   └─ [if existing valid LatLong_Actual] SKIP (กันทับ)
       ├─ copyDriverVerifiedToDailyJob_() → SOURCE.DRIVER_VERIFIED_NAME/ADDR → DAILY_JOB cols 29-30 (ผ่าน ShopKey join)
       └─ enrichEmployeeEmailsToDailyJob_() → EMPLOYEE.EMAIL → DAILY_JOB col 22 (ผ่าน DRIVER_NAME match)
  → 18_ServiceSCG.gs: buildOwnerSummary(dailyData) → สรุป_เจ้าของสินค้า (group by SoldToName)
  → 18_ServiceSCG.gs: buildShipmentSummary(dailyData) → สรุป_Shipment (group by ShipmentNo + TruckLicense)
```

### 8.3 Production auto-run flow (Group 4)

```text
[Time-based trigger ทุกชั่วโมง 08:00–22:00]
  → 24_PipelineManager.gs: runPipelineBatch()
       ├─ Check state machine (IDLE/RUNNING/PAUSED_*)
       ├─ Check quota (75 min/day, 4 min/run, 15 runs/day)
       ├─ Check circuit breaker (3 consecutive errors)
       ├─ Acquire LockService.getScriptLock() (30s timeout)
       ├─ runMatchEngine() [10_MatchEngine.gs:68] ← Group 1 pipeline เต็มรูปแบบ
       ├─ incrementQuotaUsage_(runtimeMs)
       ├─ Check Q_REVIEW backlog (> 100 → Telegram alert)
       └─ If no more work → completePipeline_() (set COMPLETED)
[Daily 00:05] resetDailyQuotaJob → reset PIPELINE_DAILY_QUOTA
```

### 8.4 Review reprocessing flow (Group 1 auto-resolver)

```text
Q_REVIEW (เฉพาะ 3 รูปแบบปลอดภัย)
  → 12b_ReviewReprocessor.gs: reprocessReviewQueue()
       ├─ Group A: GEO_NEARBY_YELLOW + name match → resolveAndPersist_(decisionType='MERGE_TO_CANDIDATE')
       ├─ Group B: NEW_RECORD_PENDING + Geo candidate → resolveAndPersist_(decisionType='CREATE_NEW')
       └─ Group C: FUZZY_MATCH score ≥ 85 → resolveAndPersist_(decisionType='MERGE_TO_CANDIDATE')
  → 10e_MatchResolvePersist.gs: resolveAndPersist_()
       ├─ resolveAndPersistMerge_() → MERGE_TO_CANDIDATE (writes alias แบบ HUMAN source)
       └─ resolveAndPersistCreate_() → CREATE_NEW (writes master + alias + FACT_DELIVERY)
  → Checkpoint/Resume ผ่าน REPROCESS_REVIEW_CHECKPOINT_KEY
```

### 8.5 WebApp decision flow (Group 3 → Group 1/2)

```text
Browser → 22_WebApp.gs: doGet() → isAuthorizedDashboardUser_() → Index.html
  → 22b_WebAppViews.gs: getDashboardData() (read FACT_DELIVERY, Q_REVIEW, SOURCE)
  → User clicks QReview view → 22b:getQReviewPage()
  → User picks decision MERGE_TO_CANDIDATE
  → 22c_WebAppActions.gs: submitReviewDecision()
       ├─ requirePermission_('action:approve_review') [27_RbacService.gs]
       ├─ validateInput_(...) [19_Hardening.gs]
       └─ 12_ReviewService.gs: applyReviewDecision()
            ├─ write FACT_DELIVERY (ถ้า CREATE_NEW/MERGE)
            ├─ logAuditTrail('Q_REVIEW', reviewId, 'UPDATE', 'status', ...) [26_AuditTrailService.gs]
            ├─ [if IGNORE] markAsNegativeSample_() → SYS_NEGATIVE_SAMPLES
            └─ update Q_REVIEW row (status, reviewer, reviewed_at, decision, note)
```

---

## 9. ตาราง mapping สำคัญ

### 9.1 จาก AppSheet actual delivery ไป Master/Fact

| Source sheet           | Source constant                                                   | ปลายทางในระบบ                            | ใช้โดย                                                                    |
| ---------------------- | ----------------------------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------- |
| `SCGนครหลวงJWDภูมิภาค` | `SRC_IDX.RAW_PERSON_NAME` (col 12)                                | `M_PERSON`, `FACT_DELIVERY.SHIP_TO_NAME` | `resolvePerson()`, `upsertFactDelivery()`                                 |
| `SCGนครหลวงJWDภูมิภาค` | `SRC_IDX.RAW_ADDRESS` (col 18) / `SRC_IDX.RESOLVED_ADDR` (col 24) | `M_PLACE`, `FACT_DELIVERY.SHIP_TO_ADDR`  | `resolvePlace()`, review                                                  |
| `SCGนครหลวงJWDภูมิภาค` | `SRC_IDX.LAT` (col 14) / `SRC_IDX.LNG` (col 15)                   | `M_GEO_POINT`, `M_DESTINATION`           | `resolveGeo()`, `createGeoPoint()`, `createDestination()`                 |
| `SCGนครหลวงJWDภูมิภาค` | `SRC_IDX.INVOICE_NO` (col 8)                                      | `FACT_DELIVERY`                          | dedupe/upsert ผ่าน `upsertFactDelivery()` (hash invoiceNo + deliveryDate) |
| `SCGนครหลวงJWDภูมิภาค` | `SRC_IDX.SYNC_STATUS` (col 36)                                    | source control                           | กันประมวลผลซ้ำใน `getUnprocessedRows()`                                   |
| `SCGนครหลวงJWDภูมิภาค` | `SRC_IDX.DRIVER_VERIFIED_NAME/ADDR` (cols 37-38)                  | `ตารางงานประจำวัน` cols 29-30            | `copyDriverVerifiedToDailyJob_()` ผ่าน ShopKey join                       |
| `SCGนครหลวงJWDภูมิภาค` | `SRC_IDX.EMPLOYEE_EMAIL` (col 13)                                 | `ข้อมูลพนักงาน` cross-ref                | (ข้อมูลเดียวกัน เก็บต่างชีต)                                              |

### 9.2 จาก SCG API daily job ไป LatLong_Actual

| Daily job column                        | Constant                                 | บทบาท                                                                                                |
| --------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `ShipToName`                            | `DATA_IDX.SHIP_TO_NAME` (col 10)         | **anchor หลัก** สำหรับ lookup (Tier 0 + Tier 1)                                                      |
| `ShipToAddress`                         | `DATA_IDX.SHIP_TO_ADDR` (col 11)         | **tie-breaker เท่านั้น** (V5.5.022-PATCH1) — ไม่ใช่ anchor และไม่ใช่ fallback                        |
| `LatLong_SCG`                           | `DATA_IDX.LATLNG_SCG` (col 12)           | เก็บไว้แสดง/อ้างอิง แต่ **ไม่ใช้ fallback** — confirmed ไม่มี code path ที่เอามาเขียน LatLong_Actual |
| `LatLong_Actual`                        | `DATA_IDX.LATLNG_ACTUAL` (col 26)        | ผลลัพธ์จาก Master เท่านั้น (ค่าว่าง = ไม่พบ)                                                         |
| `ShopKey`                               | `DATA_IDX.SHOP_KEY` (col 28)             | FK สำหรับ join กับ SOURCE sheet ใน `copyDriverVerifiedToDailyJob_()`                                 |
| `ชื่อเจ้าของสินค้า_Invoice_ที่ต้องสแกน` | `DATA_IDX.OWNER_LABEL` (col 27)          | ผลลัพธ์จาก `aggregateShopData_()` (SoldToName)                                                       |
| `Email พนักงาน`                         | `DATA_IDX.EMAIL` (col 22)                | ผลลัพธ์จาก `enrichEmployeeEmailsToDailyJob_()` (lookup EMPLOYEE sheet)                               |
| `DRIVER_VERIFIED_NAME`                  | `DATA_IDX.DRIVER_VERIFIED_NAME` (col 29) | ผลลัพธ์จาก `copyDriverVerifiedToDailyJob_()` (จาก SOURCE col 37)                                     |
| `DRIVER_VERIFIED_ADDR`                  | `DATA_IDX.DRIVER_VERIFIED_ADDR` (col 30) | ผลลัพธ์จาก `copyDriverVerifiedToDailyJob_()` (จาก SOURCE col 38)                                     |

### 9.3 ตาราง mapping ของ V6.0 sheets ใหม่

| Sheet                  | Index constant                                         | ใช้โดย                                      | บทบาท                                                                 |
| ---------------------- | ------------------------------------------------------ | ------------------------------------------- | --------------------------------------------------------------------- |
| `SYS_NOTES`            | `NOTES_IDX` (11 cols, ใน 01_Config:675)                | `persistSemanticNotesForEntity_()` (10e:92) | Semantic Note Parser storage — extract structured notes จาก raw text  |
| `SYS_NEGATIVE_SAMPLES` | `NEGATIVE_SAMPLE_IDX` (8 cols, ใน 01_Config:693)       | `markAsNegativeSample_()` (12:881)          | บันทึก IGNORE'd matches เพื่อกัน autoEnrich สร้าง alias ผิดในรอบถัดไป |
| `SYS_AUDIT_TRAIL`      | `AUDIT_IDX` (11 cols, ใน `26_AuditTrailService.gs:43`) | `logAuditTrail()` (26:108)                  | CREATE/UPDATE/DELETE/MERGE on M_ALIAS + Q_REVIEW — scope จำกัด        |
| `PIPELINE_RUN_LOG`     | `PIPELINE_LOG_IDX` (12 cols, ใน 01_Config:729)         | `logPipelineRun_()` (10:387)                | stats per run (total/auto/created/review/error/elapsed)               |
| `TEST_MATCH_RESULTS`   | `TEST_MATCH_IDX` (8 cols, ใน 01_Config:747)            | `runTestMatchDryRun_()` (10d:58)            | dry-run output (no master writes)                                     |

---

## 10. วิธีใช้งานจริงที่แนะนำ

### 10.1 รอบเรียนรู้ Master จากงานจริง (Group 1 แบบ manual)

1. ให้คนขับส่งงานผ่าน AppSheet ลง `SCGนครหลวงJWDภูมิภาค` (ต้องมี LatLong ที่ถูกต้อง)
2. รันเมนู `🟩 กลุ่ม 1: ล้างข้อมูล & Master → runFullPipeline` (RBAC: `action:run_pipeline`, admin เท่านั้น)
   - หรือรันเฉพาะขั้น `runMatchEngine` ถ้า loadSource + normalize ทำไปแล้ว
3. ระบบประมวลผล batch ละ 20 แถว, มี time guard 4.67 นาที (เหลือ buffer ใต้ 6-min GAS limit)
4. ถ้า timeout → `installAutoResume_('runMatchEngine')` สร้าง trigger +60s รันต่อ
5. ตรวจ `Q_REVIEW` สำหรับรายการที่ระบบไม่มั่นใจ (decision=REVIEW)
6. Reviewer อนุมัติผ่านเว็บ (WebApp QReview view) หรือ edit DECISION column ใน Google Sheet (RBAC: `action:approve_review`)
7. เมื่อข้อมูลผ่าน/ถูกยืนยันแล้ว ระบบจะมี Master และ Destination ที่ดีขึ้น
8. Alias จะค่อย ๆ ดีขึ้นจาก `autoEnrichAliasesFromFactBatch_` (Single Writer ใน pipeline ปกติ)
9. ตรวจ stats ล่าสุดใน `PIPELINE_RUN_LOG`

### 10.2 รอบเรียนรู้ Master แบบอัตโนมัติ (Group 4 — ทาง production)

1. ติดตั้ง triggers ผ่านเมนู `⚙️ ตั้งค่าระบบ → installPipelineTriggers` (admin เท่านั้น)
2. ระบบจะรัน `runPipelineBatch` ทุกชั่วโมง 08:00–22:00 (สูงสุด 15 รอบ/วัน)
3. แต่ละรอบรันไม่เกิน 4 นาที (MAX_RUNTIME_MS_PER_RUN)
4. ใช้ runtime รวมไม่เกิน 75 นาที/วัน (MAX_RUNTIME_MS_PER_DAY)
5. ถ้า error 3 ครั้งติด → circuit breaker trip → PAUSED_ERRORS + Telegram alert
6. ถ้า Q_REVIEW backlog > 100 → Telegram alert (เตือนให้ reviewer มาดู)
7. เมื่อ SOURCE rows ที่ SYNC_STATUS != SUCCESS = 0 → COMPLETED (clear checkpoint)
8. ดูสถานะผ่านเมนู `showPipelineStatus` หรือ WebApp LiveFeed view

### 10.3 รอบงานประจำวันจาก SCG API (Group 2)

1. ใส่ Shipment numbers ใน `Input` sheet (col A, เริ่ม row 2)
2. Set SCG Cookie ผ่านเมนู `setSCGCookie_UI` (เก็บใน PropertiesService — **ไม่ใช่ cell B1**)
3. รันเมนู `🟦 กลุ่ม 2: งานประจำวัน SCG → ดึงข้อมูล SCG API` → `fetchDataFromSCGJWD()`
4. ระบบเขียนข้อมูลลง `ตารางงานประจำวัน` (clear + headers + rows)
5. ระบบเรียก `applyMasterCoordinatesToDailyJob()` ต่อทันที:
   - `runLookupEnrichment()` เติม `LatLong_Actual` โดยใช้ `ShipToName` เป็น anchor หลัก (เขียว=found, แดง=not found)
   - `copyDriverVerifiedToDailyJob_()` copy ชื่อ/ที่อยู่ที่คนขับยืนยันจาก SOURCE sheet (ผ่าน ShopKey)
   - `enrichEmployeeEmailsToDailyJob_()` lookup email คนขับจาก EMPLOYEE sheet
6. `buildOwnerSummary(dailyData)` → `สรุป_เจ้าของสินค้า`
7. `buildShipmentSummary(dailyData)` → `สรุป_Shipment`
8. แถวที่ไม่พบต้องกลับไปเพิ่มคุณภาพ Master ผ่าน Group 1 หรือสร้าง alias ผ่าน admin/migration ที่ถูกต้อง
9. (Optional) รันเมนู `📊 รายงาน Data Quality` → `buildFullQualityReport()` เพื่อเก็บ stats ลง `RPT_DATA_QUALITY`

### 10.4 รอบตรวจสอบ Q_REVIEW (Reviewer)

1. เปิด WebApp → login ด้วย email ที่อยู่ใน `DASHBOARD_USERS` หรือ `LMDS_ADMINS`
2. คลิก sidebar "Q_REVIEW" → `QReviewView`
3. เลือกแถวที่ status=Pending → คลิก candidate panel ดูรายละเอียด
4. เลือก decision:
   - `CREATE_NEW` — สร้าง Master ใหม่ + FACT_DELIVERY
   - `MERGE_TO_CANDIDATE` — รวมเข้า candidate ที่เลือก + สร้าง alias แบบ HUMAN source
   - `IGNORE` — ไม่สร้าง Master + บันทึก negative sample
   - `ESCALATE` — ส่งต่อให้ admin
5. ใส่ note (maxLength 500) → submit
6. ระบบเขียน FACT_DELIVERY (ถ้ามี) + logAuditTrail + อัพเดท Q_REVIEW row
7. (Auto) `reprocessReviewQueue()` (12b) รันเป็น batch แก้ 3 รูปแบบปลอดภัยอัตโนมัติ

### 10.5 รอบ dry-run / regression test (Developer)

1. รันเมนู `🔍 ตรวจสอบ & วินิจฉัย → Dry Run (100 rows)` → `runTestMatchDryRun_UI()`
2. ระบบ mirror processOneRow แต่ **ไม่เขียน master/fact/review/alias** — เขียน TEST_MATCH_RESULTS เท่านั้น
3. บันทึก baseline ผ่าน `📸 Snapshot & ข้อมูล → snapshotSaveBaseline`
4. Refactor โค้ด
5. รัน dry-run ใหม่
6. `snapshotCompare_UI` — diff กับ baseline ถ้า differences = 0 → ปลอดภัย merge

---

## 11. ข้อห้ามสำคัญเพื่อไม่ให้ระบบเพี้ยน

1. **ห้ามใช้ `ShipToAddress` จาก SCG API เป็น anchor ใน Group 2** — ใช้ได้แค่เป็น tie-breaker (V5.5.022-PATCH1) ใน `selectBestDestByAddress_()` ด้วย Dice coefficient ≥ 0.70
2. **ห้ามใช้ `LatLong_SCG` เป็น fallback เพื่อเขียน `LatLong_Actual`** — confirmed ไม่มี code path นี้ และห้ามเพิ่ม
3. **ห้ามให้ `18_ServiceSCG.gs` เขียน `M_ALIAS` อัตโนมัติ** — confirmed ไม่ได้เขียน (Group 2 ไม่เขียน alias ใด ๆ)
4. **ห้ามเพิ่มจุดเขียน `M_ALIAS` นอกเส้นทางที่กำหนด** — ในโค้ดจริงมี 5 writers: `autoEnrichAliasesFromFactBatch_` (default), `handleCreateNew_` (per-row V6.0.015), `resolveAndPersistMerge_` ×2 (Q_REVIEW HUMAN), `mergePersonRecords` (admin). เพิ่ม writer ใหม่ต้องผ่าน `createGlobalAlias()` (21:106) เพื่อให้ safeguard ทำงาน
5. **ห้ามเขียน alias ด้วย source='HUMAN' โดยไม่ผ่าน safeguard** — `createGlobalAlias` เรียก `runAliasSafeguardForHumanAlias_` อัตโนมัติ (Layer 1 similarity floor 0.5 + Layer 5 circuit breaker 50/day)
6. **ห้ามใช้เลข index ตรง ๆ สำหรับคอลัมน์ข้อมูล** — ใช้ `DATA_IDX`, `SRC_IDX`, `FACT_IDX`, `REVIEW_IDX`, `*_IDX` ทั้งหมด
7. **ห้ามเขียนทีละแถวใน loop** — ใช้ batch write (`getRange().setValues()`)
8. **ห้าม bypass RBAC** — ทุก menu action, WebApp endpoint ต้องเรียก `requirePermission_()` หรือ `isAuthorizedOrFail_()` ก่อน execute. V6.0.072 เปลี่ยนเป็น fail-closed (เดิม fail-open)
9. **ห้าม refactor Match Engine โดยไม่มี baseline snapshot** — ใช้ `snapshotSaveBaseline_` + `snapshotCompare_` เพื่อยืนยันว่า action/reason/confidence distribution ไม่เปลี่ยน
10. **ห้ามเรียก `runMatchEngine` โดยไม่ acquire LockService** — `acquireMatchEngineLock_` (10:163) ป้องกัน concurrent runs
11. **ห้ามเกิน GAS 6-min limit** — `TIME_LIMIT_MS = 280000` (4.67 นาที) + auto-resume trigger +60s
12. **ห้ามเกิน Free tier 90-min/day quota** — `MAX_RUNTIME_MS_PER_DAY = 4,500,000` (75 นาที) + circuit breaker
13. **ห้ามเขียน Audit Trail ที่ throw** — `logAuditTrail` เป็น failsafe (validate แล้ว silent skip ถ้า invalid)
14. **ห้าม enable `AI_CONFIG.USE_AI_REASONING` โดยไม่ set `GEMINI_API_KEY`** — preflight check (24:1126) จะ block
15. **ห้ามเปลี่ยน `*_IDX` constants โดยไม่ update `SCHEMA`** — `validateSchemaConsistency()` (02_Schema:597) throws ถ้า length mismatch

---

## 12. Troubleshooting

| อาการ                              | สาเหตุที่พบบ่อย                                                                                          | วิธีแก้                                                                                                   |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `LatLong_Actual` ว่าง              | ยังไม่มี `ShipToName` ใน `M_ALIAS`/`M_PERSON` หรือยังไม่มี destination                                   | ให้คนขับส่งงานจริงก่อน หรือแก้ alias/master ผ่าน path ที่ถูกต้อง                                          |
| พิกัดไม่เปลี่ยนตอนรันซ้ำ           | แถวนั้นมี `LatLong_Actual` ที่ valid อยู่แล้ว ระบบ SKIP (17:449-454)                                     | ถ้าต้องคำนวณใหม่ ให้ล้าง `LatLong_Actual` เฉพาะแถวที่ต้องการก่อนรัน                                       |
| ชื่อเดียวมีหลายพิกัด               | ระบบเลือก destination ที่ usageCount สูงสุด หรือใช้ `selectBestDestByAddress_` tie-breaker (Dice ≥ 0.70) | ตรวจ `M_DESTINATION` และ `Q_REVIEW` เพื่อรวม/แก้ข้อมูล                                                    |
| ข้อมูลไม่เข้า Master               | Source row อาจถูก mark `SYNC_STATUS` แล้ว หรือเข้า `Q_REVIEW`                                            | ตรวจ `SYNC_STATUS` (col 36), `SYS_LOG`, `Q_REVIEW`                                                        |
| Alias ไม่เกิดจาก daily job         | เป็นพฤติกรรมที่ถูกต้อง — Group 2 ไม่เขียน alias                                                          | ให้ alias เกิดจาก Group 1 pipeline หรือ admin/migration path                                              |
| Pipeline ไม่รันอัตโนมัติ           | `PIPELINE_STATE` = PAUSED_QUOTA / PAUSED_ERRORS / PAUSED_MANUAL / COMPLETED                              | รัน `showPipelineStatus` → แก้ตาม state (resetCircuitBreakerMenu / resumePipeline)                        |
| Circuit breaker trip               | 3 consecutive errors → PAUSED_ERRORS + Telegram alert                                                    | ตรวจ `PIPELINE_CIRCUIT_BREAKER.lastError` → แก้ root cause → `resetCircuitBreakerMenu` → `resumePipeline` |
| WebApp ขึ้น Unauthorized           | email ไม่อยู่ใน `DASHBOARD_USERS` หรือ `LMDS_ADMINS` script property                                     | admin เพิ่ม email ผ่าน `setupRoleAssignments_UI`                                                          |
| WebApp session timeout             | 30-min inactivity (Auth.html)                                                                            | กด Manual Refresh หรือ re-login                                                                           |
| `runMatchEngine` รันไม่จบ          | time guard 4.67 นาที + dataset ใหญ่                                                                      | auto-resume trigger +60s จะรันต่อ — ดู `PIPELINE_RUN_LOG` หรือ trigger list                               |
| Snapshot test fail                 | action/reason/confidence distribution เปลี่ยนหลัง refactor                                               | ดู `snapshotCompare_` output (max 20 differences) → ย้อนกลับ fix หรือ update baseline                     |
| `validateSchemaConsistency` throws | `SCHEMA[name].length` ≠ `Object.keys(*_IDX).length`                                                      | แก้ SCHEMA หรือ *_IDX ให้ตรง — ใช้ `runPipelinePreflightStrict_UI` เพื่อ pre-check                        |
| Audit Trail ไม่ log                | entity_type ไม่ใช่ ALIAS/Q_REVIEW หรือ action ไม่ใช่ CREATE/UPDATE/DELETE/MERGE                          | ขยาย `AUDIT_ENTITY_TYPES` (26:73) หรือใช้ entity_type ที่รองรับ                                           |
| Telegram alert ไม่ส่ง              | `TELEGRAM_BOT_TOKEN` หรือ `TELEGRAM_CHAT_ID` ไม่ได้ set                                                  | set ผ่าน script properties → ทดสอบด้วย `sendPipelineAlert_` manual                                        |
| SCG Cookie ไม่ทำงาน                | อาจยังเก็บใน cell B1 แบบเก่า (V6.0.036 ขึ้นไปเก็บใน PropertiesService)                                   | รัน `setSCGCookie_UI` ใหม่ → ระบบจะ auto-migrate และ clear cell B1                                        |

---

## 13. บันทึก bug / inconsistency ที่พบระหว่างตรวจทานโค้ด

> ระหว่างเขียนเอกสารนี้ ผมได้ตรวจโค้ดไปด้วยและพบ bug/inconsistency 6 จุด ขอให้รีบตรวจสอบและแก้ไขครับ

### 13.1 `bindAlias` เป็น dead reference

**ตำแหน่ง:** `src/1_group1_master_db/10e_MatchResolvePersist.gs:25`

**ปัญหา:** ใน dependency comment ของ `10e_MatchResolvePersist.gs` บรรทัดที่ 25 ระบุว่า:

```
*     - bindAlias()                             → 21_AliasService.gs
```

แต่ grep ทั้ง codebase **ไม่พบ function definition ของ `bindAlias`** ในไฟล์ใด ๆ — เป็น dead reference ที่ชี้ไปยังฟังก์ชันที่ไม่มีอยู่จริง

**ผลกระทบ:** ไม่มี runtime impact (เป็นแค่ comment) แต่ทำให้ผู้ดูแลคนใหม่สับสนว่าฟังก์ชัน `bindAlias` มีอยู่จริง

**วิธีแก้:** ลบบรรทัดนี้ออกจาก dependency comment หรือเปลี่ยนเป็น `createGlobalAlias()` ซึ่งเป็นฟังก์ชันจริงที่ `10e_MatchResolvePersist.gs` เรียกใช้

---

### 13.2 `readInputConfig_` ถูกอ้างผิดที่ใน header comment

**ตำแหน่ง:**

- `src/O_core_system/01_Config.gs:20` — ระบุว่า export `readInputConfig_` ไปยัง `00_App.gs`
- `src/O_core_system/01_Config.gs:23` — ระบุว่า `SHEET.SYS_CONFIG` ถูกอ่านโดย `readInputConfig_`
- `src/O_core_system/14_Utils.gs:25` — ระบุว่า `SHEET.INPUT` ถูกอ่านโดย `readInputConfig_` (fallback)

**ปัญหา:** `readInputConfig_` จริง ๆ อยู่ใน `src/2_group2_daily_ops/18_ServiceSCG.gs:221` — **ไม่ใช่**ใน `01_Config.gs` หรือ `14_Utils.gs`

**ผลกระทบ:** ผู้ดูแลที่ค้นหา `readInputConfig_` จาก header comment จะหาผิดที่

**วิธีแก้:** แก้ header comment ใน `01_Config.gs:20` และ `14_Utils.gs:25` ให้ชี้ไปยัง `18_ServiceSCG.gs:221` หรือลบบรรทัดที่อ้างถึง `readInputConfig_` ออก

---

### 13.3 `ENV_*` constants ไม่มีอยู่จริง

**ตำแหน่ง:** `src/O_core_system/01_Config.gs:19`

**ปัญหา:** header comment ระบุว่า export `ENV_*` constants ไปยัง all .gs modules แต่ grep ทั้ง codebase **ไม่พบ `ENV_*` constant ใด ๆ**

Environment config จริง ๆ อยู่ใน `PropertiesService.getScriptProperties()` ทั้งหมด:

- `GEMINI_API_KEY`, `SCG_API_URL`, `SCG_COOKIE`, `LMDS_ADMINS`, `DASHBOARD_USERS`, `ROLE_ASSIGNMENTS`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `AUDIT_RETENTION_DAYS`, `PIPELINE_STOP_REQUESTED`, `AUTO_RESUME_TRIGGER_ID`, `SNAPSHOT_TEST_BASELINE`, plus all `PIPELINE_*` keys

**ผลกระทบ:** ผู้ดูแลที่อ่าน header อาจคิดว่ามี `ENV_*` constants ใช้งาน แล้วเสียเวลาค้นหา

**วิธีแก้:** แก้ header comment ใน `01_Config.gs:19` ให้เป็น `PropertiesService.getScriptProperties() keys` หรือลบการอ้างถึง `ENV_*` ออก

---

### 13.4 `ENV_MAPS_API_KEY` ใน comment ของ `15_GoogleMapsAPI.gs`

**ตำแหน่ง:** `src/2_group2_daily_ops/15_GoogleMapsAPI.gs:16`

**ปัญหา:** comment ระบุว่า module นี้ใช้ `ENV_MAPS_API_KEY` จาก `01_Config.gs` แต่:

1. `ENV_MAPS_API_KEY` ไม่มีอยู่จริง (เป็น subset ของ bug 13.3)
2. `15_GoogleMapsAPI.gs` ใช้ Google Maps API แบบฟรี (ไม่ต้อง API key สำหรับ custom functions พื้นฐาน) และ cache ผ่าน `CacheService.getDocumentCache()` — ไม่ได้ใช้ API key เลย

**ผลกระทบ:** ผู้ดูแลอาจคิดว่าต้อง set `ENV_MAPS_API_KEY` ทั้งที่จริง ๆ ไม่ต้อง

**วิธีแก้:** ลบบรรทัดที่อ้างถึง `ENV_MAPS_API_KEY` ออกจาก dependency comment

---

### 13.5 Inconsistency ระหว่าง `FACT_IDX` และ `SRC_IDX` ของ `DRIVER_VERIFIED_NAME/ADDR`

**ตำแหน่ง:**

- `src/O_core_system/01_Config.gs:312-313` — `FACT_IDX.DRIVER_VERIFIED_NAME = 32`, `FACT_IDX.DRIVER_VERIFIED_ADDR = 33`
- `src/O_core_system/01_Config.gs:436-437` — `SRC_IDX.DRIVER_VERIFIED_NAME = 37`, `SRC_IDX.DRIVER_VERIFIED_ADDR = 38`
- `src/O_core_system/01_Config.gs:476-477` — `DATA_IDX.DRIVER_VERIFIED_NAME = 29`, `DATA_IDX.DRIVER_VERIFIED_ADDR = 30`

**ปัญหา:** ชื่อ constant เหมือนกันทั้ง 3 IDX (`DRIVER_VERIFIED_NAME`, `DRIVER_VERIFIED_ADDR`) แต่ค่า index ต่างกัน (32/33, 37/38, 29/30) — เป็นไปตาม schema ของแต่ละ sheet จริง ๆ แต่อาจทำให้สับสนตอนอ่านโค้ด

**ตัวอย่าง:** ใน `copyDriverVerifiedToDailyJob_()` (`18_ServiceSCG.gs:770-771`) ใช้ `SRC_IDX.DRIVER_VERIFIED_NAME` (col 37) — ตรงกับ SOURCE sheet schema ที่มี 39 คอลัมน์  
ใน `upsertFactDelivery()` (`11_TransactionService.gs`) ใช้ `FACT_IDX.DRIVER_VERIFIED_NAME` (col 32) — ตรงกับ FACT_DELIVERY schema ที่มี 34 คอลัมน์

**ผลกระทบ:** ไม่มี runtime bug (เพราะแต่ละไฟล์ใช้ IDX ของ sheet ตัวเอง) แต่ถ้ามีคน copy-paste โค้ดระหว่างไฟล์โดยไม่เปลี่ยน IDX prefix จะพัง

**วิธีแก้:** ไม่ต้องแก้โค้ด — แต่ขอแนะนำให้เพิ่ม comment ใน `01_Config.gs` ย้ำว่าค่า index เหมือนกันเพียงเพราะ schema บังเอิญ และต้องใช้ IDX prefix ของ sheet นั้น ๆ เสมอ

---

### 13.6 ฟังก์ชันที่ถูกลบใน V5.5.044 แต่อาจมี external caller

**ตำแหน่ง:** หลายไฟล์ (ดู comment `[REMOVED V5.5.044]`)

**ปัญหา:** ฟังก์ชันต่อไปนี้ถูกลบใน V5.5.044 เพราะ mark @deprecated ใน V5.5.043 และ grep ยืนยันไม่มี caller ใน .gs ใด:

- `getDestsByPersonAndPlace` — ลบจาก `09_DestinationService.gs`
- `getDominantDestByGeo` — ลบจาก `09_DestinationService.gs`
- `processSrcBatch_` — ลบจาก `04_SourceRepository.gs`
- `clearDailyJobLatLng` — ลบจาก `18_ServiceSCG.gs`
- `analyzeReviewPatterns` — ลบจาก `12_ReviewService.gs`
- `invalidateSameDayDestCache_` — ลบจากหลายไฟล์
- `safeCacheGet_/safeCachePut_/safeCacheRemoveAll_` — ลบจาก `14_Utils.gs`
- `validatePersonName + validateAddress` — ลบจาก `05_NormalizeService.gs`
- `lookupProvinceFromAddress` — ลบจาก `16_GeoDictionaryBuilder.gs` (V6.0.069)
- `isValidProvince + lookupDistrictsByProvince` — ลบจาก `16_GeoDictionaryBuilder.gs` (V6.0.069)
- `listAllAreasByPostcode` — ลบจาก `16_GeoDictionaryBuilder.gs` (V5.5.044)
- `safeAlert_` — ลบจาก `16_GeoDictionaryBuilder.gs` (V5.4.003, ย้ายไป `14_Utils.gs` เป็น `safeUiAlert_`)
- `safeUiAlert_Report_` — ลบจาก `13_ReportService.gs` (V5.4.003, ย้ายไป `14_Utils.gs` เป็น `safeUiAlert_`)
- `callGeminiReasoning_` — ลบจาก `17_SearchService.gs` (V5.4.003 ตาม ShipToName-Only Policy)

**ผลกระทบ:** ถ้ามี external script หรือ library อื่นที่ยังเรียกฟังก์ชันเหล่านี้ จะพัง (ReferenceError)

**วิธีแก้:** ตรวจสอบว่าไม่มี external caller (เช่น Google Sheet custom menu, other libraries, webhooks) ที่ยังเรียกใช้ — ถ้ามี ให้สร้าง shim ใน `99_Legacy.gs` หรือแจ้งผู้ใช้ให้เปลี่ยนไปใช้ฟังก์ชันใหม่

---

### สรุปคำแนะนำ

1. **ลำดับความเร่งด่วน:**
   - **ปานกลาง:** bug 13.1 (`bindAlias` dead reference), 13.2 (`readInputConfig_` อ้างผิดที่), 13.3 (`ENV_*` ไม่มีจริง), 13.4 (`ENV_MAPS_API_KEY`) — ทั้งหมดเป็น comment-only bugs แก้ง่าย แต่ทำให้ผู้ดูแลคนใหม่สับสน
   - **ต่ำ:** bug 13.5 (IDX inconsistency) — เป็นไปตาม schema จริง แค่เพิ่ม comment ย้ำ
   - **ตรวจสอบ:** bug 13.6 (deleted functions) — ตรวจ external callers ก่อน

2. **แนวทางป้องกัน regression:**
   - เพิ่ม GitHub Action ที่ grep หา `function X` ที่ถูกอ้างใน dependency comments แล้ว verify ว่ามีจริง
   - เพิ่ม lint rule ที่ห้ามอ้าง `ENV_*` ใน comment ใหม่
   - ใช้ `runPipelinePreflightStrict_UI` ก่อน deploy เพื่อ verify schema consistency

3. **เอกสารนี้ควรเป็น source of truth** — ถ้ามี code ใหม่ที่ขัดกับเอกสารนี้ ให้แก้เอกสารพร้อมแก้โค้ดใน PR เดียวกัน
