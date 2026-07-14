# 5-Layer Safeguard System — Integration Guide
### Q_REVIEW → M_ALIAS Promotion Path

ไฟล์นี้อธิบายว่าไฟล์ `21b_AliasSafeguard.gs` (โมดูลใหม่) ต้องต่อเข้ากับไฟล์เดิม 6 ไฟล์
อย่างไร พร้อม diff แบบ exact ที่ทำตามได้ทันที **ไม่มีการแก้ไฟล์เดิมโดยอัตโนมัติ — คุณ
ต้อง apply เองหลังรีวิว** เพื่อรักษา Zero-Hallucination Policy (ให้คุณเห็นทุกจุดที่กระทบ)

---

## สรุป Ownership ที่ตอบคำถามค้างจาก memory

> "Clarify module ownership for writes to Q_REVIEW.sync_status and M_ALIAS"

**คำตอบจากการออกแบบนี้:**
- `M_ALIAS` (canonical) — เขียนได้เฉพาะ `21_AliasService.gs::createGlobalAlias()` เหมือนเดิม
  100% ไม่เปลี่ยน — Single Writer Rule ไม่ถูกแตะต้อง
- `M_ALIAS_STAGING` (ตารางใหม่ ไม่ใช่ canonical) — เขียนได้จากหลายจุด (Layer 1-3, 5 ใน
  `21b_AliasSafeguard.gs`) เพราะไม่ใช่ตารางกลางที่มีความเสี่ยงเดียวกับ M_ALIAS
- `sync_status` เป็นคอลัมน์ **ของ `M_ALIAS_STAGING`** (ไม่ใช่ Q_REVIEW ตามที่ memory เดา
  ไว้ก่อนตรวจโค้ดจริง) — เพราะจุดที่ต้องการ "queue รอ sync เข้า canonical table" คือ
  staging table ไม่ใช่ Q_REVIEW เอง — `PENDING_SYNC` ถูกเปลี่ยนเป็น `SYNCED` โดย
  `promoteStagedAliases_()` เท่านั้น ซึ่งเป็นจุดเดียวที่เรียก `createGlobalAlias()`

---

## 1) `01_Config.gs` — เพิ่ม 3 จุด

**(a)** ต่อจาก `AI_CONFIG` (บรรทัด ~626):
```js
const SAFEGUARD_CONFIG = Object.freeze({
  MIN_SIMILARITY_RATIO: 0.5,
  MIN_CONFIRMATION_COUNT: 2,
  PROBATION_DAYS: 7,
  PROBATION_WEIGHT_MULTIPLIER: 0.5,
  MAX_DAILY_ALIAS_WRITES: 50
});
```

**(b)** ใน `SHEET` object (บรรทัด 125-161), เพิ่มหลัง `M_ALIAS: 'M_ALIAS',`:
```js
  M_ALIAS_STAGING: 'M_ALIAS_STAGING',
```

**(c)** ใน `ALIAS_IDX` (บรรทัด 232-245), เพิ่มหลัง `VERIFIED_AT: 10`:
```js
  VERIFIED_AT: 10,
  ALIAS_STATUS: 11 // [NEW] 'PROBATION' | 'CONFIRMED' | 'REVERTED' — 5-layer safeguard
```
⚠️ นี่คือการ **append ท้าย** เท่านั้น — คอลัมน์ 0-10 เดิมห้ามขยับตาม [RULE 2]

**(d)** เพิ่มหลัง `ALIAS_IDX` ทั้งก้อน:
```js
const STAGING_IDX = Object.freeze({
  STAGING_ID: 0, MASTER_UUID: 1, VARIANT_NAME: 2, ENTITY_TYPE: 3, SOURCE: 4,
  REVIEW_ID: 5, VERIFIED_BY: 6, SIMILARITY_RATIO: 7, CONFIRMATION_DAYS_JSON: 8,
  CONFIRMATION_COUNT: 9, STATUS: 10, REJECT_REASON: 11, SYNC_STATUS: 12,
  PROMOTED_ALIAS_ID: 13, PROBATION_STARTED_AT: 14, PROMOTED_AT: 15,
  CREATED_AT: 16, UPDATED_AT: 17
});
```

---

## 2) `02_Schema.gs` — เพิ่ม 2 จุด

**(a)** ใน `SCHEMA.M_ALIAS` array (บรรทัด 103-116) เพิ่มท้าย `'verified_at' // [10]`:
```js
    'verified_at', // [10] timestamp when verified
    'alias_status' // [11] [NEW] PROBATION | CONFIRMED | REVERTED
```

**(b)** เพิ่ม key ใหม่ในระดับเดียวกับ `M_ALIAS:` (หลังปิด array ของ M_ALIAS):
```js
  M_ALIAS_STAGING: [
    'staging_id', 'master_uuid', 'variant_name', 'entity_type', 'source',
    'review_id', 'verified_by', 'similarity_ratio', 'confirmation_days_json',
    'confirmation_count', 'status', 'reject_reason', 'sync_status',
    'promoted_alias_id', 'probation_started_at', 'promoted_at',
    'created_at', 'updated_at'
  ],
```
ลำดับต้องตรงกับ `STAGING_IDX` เป๊ะ — 18 คอลัมน์

---

## 3) `03_SetupSheets.gs` — เพิ่ม 1 บรรทัด

ในฟังก์ชัน setup หลัก (จุดเดียวกับบรรทัด 120 ที่สร้าง `SHEET.M_ALIAS`) เพิ่ม:
```js
createSheetIfMissing_(ss, SHEET.M_ALIAS_STAGING, getSheetHeaders(SHEET.M_ALIAS_STAGING));
```
รันเมนู "Setup Sheets" 1 ครั้งหลัง deploy เพื่อสร้างชีตจริง

**เรื่อง header `alias_status` ใหม่ใน M_ALIAS ที่มีอยู่แล้ว — ไม่ต้องทำอะไรเพิ่ม:**
ตรวจโค้ดจริงพบว่า `createSheetIfMissing_()` (บรรทัด 219-263) มี Auto-Repair
อยู่แล้ว — ถ้า header ไหนหายไปจาก `SCHEMA.M_ALIAS` มันจะเพิ่มคอลัมน์ใหม่ต่อท้ายให้
อัตโนมัติตอนรันเมนู Setup Sheets (จะขึ้นสีแดงอ่อนบอกว่าเพิ่งเติมให้) ดังนั้นแค่ apply
patch 2(a) แล้วรัน Setup Sheets ก็พอ

**สิ่งที่ auto-repair ไม่ทำ (ต้องรันเพิ่ม 1 ครั้ง):** backfill ค่าให้แถวข้อมูลเดิม —
เขียนให้แล้วใน `21b_AliasSafeguard.gs::backfillAliasStatusForExistingRows_UI()`
รันจากเมนู/Apps Script editor 1 ครั้งหลัง Setup Sheets เสร็จ จะ backfill แถว M_ALIAS
เดิมทั้งหมดเป็น `alias_status='CONFIRMED'` (เหตุผล: แถวเดิมผ่านการใช้งานจริงมาแล้ว
ไม่ควรถูกลด weight เป็น PROBATION ย้อนหลัง — ดู comment ในโค้ดสำหรับรายละเอียด)
ฟังก์ชันนี้ idempotent รันซ้ำได้ปลอดภัย

---

## 4) `10e_MatchResolvePersist.gs` — จุดสำคัญที่สุด

ใน `resolveAndPersistMerge_()` (บรรทัด 156-201 ปัจจุบัน) เปลี่ยนจากเรียก
`createGlobalAlias(..., 'HUMAN', ...)` ตรงๆ → เรียก `proposeHumanAlias_()` แทน

**เดิม** (บรรทัด 165-181, ตัวอย่างฝั่ง PERSON):
```js
if (targetPersonId && srcObj.rawPersonName) {
  const personUuid = getPersonMasterUuid_(targetPersonId);
  if (personUuid) {
    const newAliasId = createGlobalAlias(
      personUuid, srcObj.rawPersonName, 'PERSON', 100, 'HUMAN', verifiedBy, optReviewId || ''
    );
    if (newAliasId) {
      logInfo('MatchEngine', 'Self-Healing Alias: PERSON "' + srcObj.rawPersonName + '" → ' + targetPersonId);
    }
  }
}
```

**ใหม่:**
```js
if (targetPersonId && srcObj.rawPersonName) {
  const personUuid = getPersonMasterUuid_(targetPersonId);
  if (personUuid) {
    // [SAFEGUARD] ต้องมี canonical name เดิมไปให้ Layer 1 เทียบ similarity
    //   getPersonCanonicalName_() เป็นฟังก์ชันใหม่ที่เพิ่มมาใน 21b_AliasSafeguard.gs
    //   (ตรวจแล้วว่า 06_PersonService.gs ไม่มี getter สำเร็จรูปสำหรับสิ่งนี้)
    const canonicalName = getPersonCanonicalName_(targetPersonId);
    const proposalResult = proposeHumanAlias_(
      personUuid, srcObj.rawPersonName, canonicalName, 'PERSON', optReviewId || '', verifiedBy
    );
    logInfo(
      'MatchEngine',
      'Self-Healing Alias proposal: PERSON "' + srcObj.rawPersonName + '" → ' + targetPersonId +
        ' — status=' + proposalResult.status + ' (' + proposalResult.reason + ')'
    );
  }
}
```
ทำแบบเดียวกันกับฝั่ง PLACE (บรรทัด 182-198) — ใช้ `getPlaceCanonicalName_(targetPlaceId)`

**ผลลัพธ์เชิงพฤติกรรม:** alias จาก Q_REVIEW จะ**ไม่ active ทันทีอีกต่อไป** — ต้องผ่าน
consensus (Layer 2) และรอ `promoteStagedAliases_()` รันเป็น step ถัดไปก่อน นี่คือการ
เปลี่ยน behavior ที่ตั้งใจ (จุดประสงค์ของ safeguard system) — ควรสื่อสารกับทีม reviewer
ว่า "แก้ 1 ครั้งจะยังไม่เห็นผลอัตโนมัติทันทีในรอบถัดไป ต้องแก้ซ้ำคนละวัน 2 ครั้งก่อน"

⚠️ **ถ้ายังไม่พร้อมเปลี่ยน behavior ทันที** แนะนำ deploy แบบ shadow-mode ก่อน: เรียก
`proposeHumanAlias_()` ควบคู่กับของเดิม (ไม่ลบของเดิมออก) แล้วดู log เทียบผลว่า
safeguard จะ reject/block กี่ % ก่อนตัดของเดิมออกจริง

---

## 5) `24_PipelineManager.gs` — เพิ่ม promotion step

ใน `runPipelineBatch()` หลัง Step 7 (บันทึก quota + checkpoint, ตำแหน่งเดิมประมาณ
บรรทัด 685) เพิ่ม:
```js
// [SAFEGUARD Layer 4] Promote staged aliases ที่ผ่าน consensus แล้ว
try {
  if (typeof promoteStagedAliases_ === 'function') promoteStagedAliases_();
} catch (safeguardErr) {
  logError('PipelineManager', 'promoteStagedAliases_ ล้มเหลว (ไม่กระทบ pipeline หลัก): ' + safeguardErr.message, safeguardErr);
}
```
และเพิ่ม time trigger รายวัน (ใช้ pattern `installOrRecycleTrigger_` ที่มีอยู่แล้วใน
skill `lmds-gas-best-practices`) เรียก `graduateProbationAliases_()` วันละ 1 ครั้ง

---

## 6) `12_ReviewService.gs` — auto-revert hook (optional, Layer 4)

ที่จุด `markAsNegativeSample_(rowArr)` (บรรทัด 500) เพิ่มก่อนหน้า:
```js
// [SAFEGUARD Layer 4] ถ้า raw name/place ตรงกับ alias ที่ยัง PROBATION → auto-revert
try {
  const probationAliasId =
    findProbationAliasByVariant_(rowArr[REVIEW_IDX.RAW_PERSON]) ||
    findProbationAliasByVariant_(rowArr[REVIEW_IDX.RAW_PLACE]);
  if (probationAliasId) {
    autoRevertAliasOnRejection_(probationAliasId, 'Q_REVIEW IGNORE decision — reviewId=' + reviewId);
  }
} catch (e) {
  logWarn('ReviewService', 'Safeguard auto-revert check skipped: ' + e.message);
}
```
`findProbationAliasByVariant_()` เขียนไว้แล้วใน `21b_AliasSafeguard.gs` — ใช้
exact-match กับ `normalizeForCompare()` (ไม่ fuzzy) เพื่อลดความเสี่ยง false-positive
revert ตามที่ตัดสินใจไว้

---

## 7) `10b_MatchDecision.gs` — ใช้ probation weight ตอนให้คะแนน (optional)

จุดที่คำนวณ confidence จาก alias match ควรคูณด้วย
`getAliasWeightMultiplier_(aliasRow[ALIAS_IDX.ALIAS_STATUS])` — ผมยังไม่ได้ระบุบรรทัด
exact เพราะยังไม่ได้อ่าน `10b_MatchDecision.gs` ทั้งไฟล์ในรอบนี้ (มี 353 บรรทัด, 8 rules
ตาม skill) — ถ้าต้องการ ผมไปอ่านไฟล์นี้ให้ละเอียดแล้วเสนอ exact patch ต่อได้เป็นขั้นถัดไป

---

## Rollout Checklist

1. Deploy `21b_AliasSafeguard.gs` เป็นไฟล์ใหม่ (ยังไม่กระทบอะไร — ยังไม่มีใครเรียก)
2. Apply patch 1-3 (constants + schema + setup) → รัน Setup Sheets 1 ครั้ง
3. Migration: รัน Setup Sheets (auto-repair เติม header `alias_status` ให้) แล้วรัน
   `backfillAliasStatusForExistingRows_UI()` 1 ครั้ง (ดูข้อ 3 ด้านบน)
4. รัน `29_SnapshotTest.gs` เทียบ baseline ก่อน apply patch 4 (จุดเปลี่ยน behavior จริง)
5. Apply patch 4 แบบ shadow-mode ก่อน (ดูหมายเหตุในข้อ 4) อย่างน้อย 1-2 สัปดาห์
6. เมื่อมั่นใจ → ตัดของเดิมออก, apply patch 5-6, เปิด time trigger `graduateProbationAliases_`
7. Optional: patch 7 (match engine weight integration)
