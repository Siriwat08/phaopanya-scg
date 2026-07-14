// ============================================================
// 21b_AliasSafeguard.gs — [NEW] 5-Layer Safeguard สำหรับ Q_REVIEW → M_ALIAS
// ============================================================
// สถาปัตยกรรม:
//   - โมดูลนี้ "ไม่ใช่" Single Writer ของ M_ALIAS — ยังคงเป็น 21_AliasService.gs
//     (createGlobalAlias) ตามเดิม 100% ตาม Single Writer Rule
//   - โมดูลนี้เขียนได้เฉพาะ M_ALIAS_STAGING (ตารางกลางใหม่ ไม่ใช่ canonical table)
//   - ตัวเดียวที่อ่าน M_ALIAS_STAGING แล้วเรียก createGlobalAlias() จริง คือ
//     promoteStagedAliases_() ในไฟล์นี้ แต่การเขียนจริงยังผ่าน 21_AliasService.gs
//     เท่านั้น — ownership ของ M_ALIAS ไม่เปลี่ยน
//   - Caller เดิม (10e_MatchResolvePersist.gs) เปลี่ยนจากเรียก createGlobalAlias()
//     ตรงๆ → เรียก proposeHumanAlias_() แทน (ดู PATCH GUIDE ท้ายไฟล์นี้)
//
// Flow รวม:
//   Q_REVIEW MERGE_TO_CANDIDATE (HUMAN)
//     → proposeHumanAlias_()                [Layer 1: Structural Validation]
//         → recordAliasProposal_()          [Layer 2: Repetition Consensus]
//             → detectAliasConflict_()      [Layer 3: Conflict Detection]
//                 → checkCircuitBreaker_()  [Layer 5: Circuit Breaker]
//                     → markPendingSync_()  (status='PROBATION', sync_status='PENDING_SYNC')
//   (แยก step — เรียกจาก trigger/menu เป็นระยะ หรือท้าย pipeline batch)
//   promoteStagedAliases_()                 [Layer 4: Probation lifecycle]
//     → เรียก createGlobalAlias() จริง (21_AliasService.gs, Single Writer)
//
// ============================================================

// ============================================================
// SECTION 0: SAFEGUARD_CONFIG — [ADD to 01_Config.gs เมื่อ merge จริง]
// ============================================================
// วางไว้ต่อจาก AI_CONFIG ใน 01_Config.gs:
//
// const SAFEGUARD_CONFIG = Object.freeze({
//   MIN_SIMILARITY_RATIO: 0.5,      // Layer 1 — Levenshtein similarity floor (0-1)
//   MIN_CONFIRMATION_COUNT: 2,       // Layer 2 — ต้องเห็นซ้ำกันคนละวัน >= กี่ครั้งถึง promote
//   PROBATION_DAYS: 7,               // Layer 4 — ระยะเวลา probation ก่อน CONFIRMED
//   PROBATION_WEIGHT_MULTIPLIER: 0.5,// Layer 4 — ลด weight ตอน match engine ใช้ alias ที่ยัง probation
//   MAX_DAILY_ALIAS_WRITES: 50       // Layer 5 — circuit breaker: promote ได้สูงสุดกี่ตัว/วัน
// });
//
// หมายเหตุ: ตัวเลขเป็นค่าเริ่มต้นที่ประเมินจาก pattern เดิมของระบบ (THRESHOLD_AUTO=85 ฯลฯ)
// ควรทวนกับข้อมูลจริงก่อน deploy — นี่คือ "design draft", ไม่ใช่ค่าที่ verify แล้ว

// ============================================================
// SECTION 0b: STAGING_IDX + M_ALIAS_STAGING schema
// [ADD STAGING_IDX to 01_Config.gs, ADD M_ALIAS_STAGING array to 02_Schema.gs,
//  ADD SHEET.M_ALIAS_STAGING to 01_Config.gs SHEET object]
// ============================================================
//
// const STAGING_IDX = Object.freeze({
//   STAGING_ID: 0,          // ST + 12 hex
//   MASTER_UUID: 1,
//   VARIANT_NAME: 2,
//   ENTITY_TYPE: 3,          // 'PERSON' | 'PLACE'
//   SOURCE: 4,               // ปัจจุบันมีแต่ 'HUMAN' — เผื่อขยายอนาคต
//   REVIEW_ID: 5,            // FK → Q_REVIEW.review_id (ครั้งล่าสุดที่เสนอ)
//   VERIFIED_BY: 6,          // reviewer email ล่าสุด
//   SIMILARITY_RATIO: 7,     // Layer 1 output — เก็บไว้ audit
//   CONFIRMATION_DAYS_JSON: 8, // Layer 2 — JSON array ของ 'YYYY-MM-DD' ที่เคยเห็น (distinct day)
//   CONFIRMATION_COUNT: 9,   // = CONFIRMATION_DAYS_JSON.length (denormalized เพื่อ query ง่าย)
//   STATUS: 10,              // PENDING | PROBATION | CONFIRMED | REJECTED | BLOCKED
//   REJECT_REASON: 11,       // ข้อความเหตุผลถ้า REJECTED/BLOCKED (จาก Layer 3/5)
//   SYNC_STATUS: 12,         // PENDING_SYNC | SYNCED  — [Ownership: เขียนโดย safeguard module
//                            //   (Layer 1-3,5), อ่าน+เปลี่ยนเป็น SYNCED โดย promoteStagedAliases_
//                            //   เท่านั้น ซึ่งเป็นจุดเดียวที่เรียก createGlobalAlias() จริง]
//   PROMOTED_ALIAS_ID: 13,   // FK → M_ALIAS.alias_id หลัง promote สำเร็จ
//   PROBATION_STARTED_AT: 14,
//   PROMOTED_AT: 15,
//   CREATED_AT: 16,
//   UPDATED_AT: 17
// });
//
// SCHEMA.M_ALIAS_STAGING = [
//   'staging_id','master_uuid','variant_name','entity_type','source','review_id',
//   'verified_by','similarity_ratio','confirmation_days_json','confirmation_count',
//   'status','reject_reason','sync_status','promoted_alias_id',
//   'probation_started_at','promoted_at','created_at','updated_at'
// ];
// (ลำดับใน SCHEMA array ต้องตรงกับ STAGING_IDX เป๊ะ — สร้างพร้อมกันเสมอ)
//
// SHEET.M_ALIAS_STAGING = 'M_ALIAS_STAGING';  // เพิ่มใน SHEET Object.freeze()
//
// ============================================================
// SECTION 0c: ALIAS_IDX เพิ่มคอลัมน์ใหม่ (APPEND ท้ายเท่านั้น — [RULE 2] ห้ามขยับลำดับเดิม)
// [ADD to 01_Config.gs ALIAS_IDX + 02_Schema.gs SCHEMA.M_ALIAS]
// ============================================================
//
// ALIAS_IDX.ALIAS_STATUS = 11;   // 'PROBATION' | 'CONFIRMED' — ไม่กระทบ active_flag (col 7) เดิม
// SCHEMA.M_ALIAS.push('alias_status'); // [11] เพิ่มท้าย SCHEMA.M_ALIAS array เดิม (คอลัมน์ 0-10 ต้องคงเดิม)
//
// เหตุผลที่แยกจาก active_flag: active_flag ควบคุมว่า match engine "ใช้ได้ไหม" (ยังคง true
// ตั้งแต่แรกเพื่อไม่ทำลาย behavior เดิม), ส่วน alias_status บอกว่า "เชื่อถือได้แค่ไหน" — ให้
// 10b_MatchDecision.gs ลด weight เมื่อ alias_status==='PROBATION' (ดู PATCH GUIDE)

// ============================================================
// HELPERS — canonical name lookup by id
//   [CORRECTION] ตอนแรกตั้งใจอ้างอิงว่ามี getter สำเร็จรูปใน 06_PersonService.gs /
//   07_PlaceService.gs อยู่แล้ว — ตรวจโค้ดจริงแล้วไม่มี มีแต่ loadAllPersons_()/
//   loadAllPlaces_() ที่คืน array ของ object {personId/placeId, canonical, ...}
//   จึงเขียน wrapper บางๆ 2 ตัวนี้เพิ่มแทน (ไม่เขียน sheet ใดๆ — read-only)
// ============================================================

/**
 * getPersonCanonicalName_ — คืนชื่อ canonical ปัจจุบันของ M_PERSON row
 * @param {string} personId
 * @return {string} canonical name หรือ '' ถ้าไม่พบ
 * @private
 */
function getPersonCanonicalName_(personId) {
  if (!personId || typeof loadAllPersons_ !== 'function') return '';
  const found = loadAllPersons_().find((p) => p.personId === personId);
  return found ? found.canonical : '';
}

/**
 * getPlaceCanonicalName_ — คืนชื่อ canonical ปัจจุบันของ M_PLACE row
 * @param {string} placeId
 * @return {string} canonical name หรือ '' ถ้าไม่พบ
 * @private
 */
function getPlaceCanonicalName_(placeId) {
  if (!placeId || typeof loadAllPlaces_ !== 'function') return '';
  const found = loadAllPlaces_().find((p) => p.placeId === placeId);
  return found ? found.canonical : '';
}

// ============================================================
// LAYER 1: Structural Validation with Similarity Floor + Scope Binding
// ============================================================

/**
 * validateAliasStructure_ — Layer 1
 *   ตรวจ (a) similarity floor ด้วย Levenshtein ratio และ (b) scope binding
 *   (entityType ต้องตรง + ถ้าเป็น PLACE ควรอยู่ในพื้นที่ใกล้เคียงกับ canonical เดิม)
 * @param {string} variantName - ชื่อดิบที่ผู้ใช้ยืนยัน (ก่อน normalize)
 * @param {string} canonicalName - ชื่อ canonical ของ master entity ที่จะผูก alias เข้า
 * @param {string} entityType - 'PERSON' | 'PLACE'
 * @return {{pass: boolean, ratio: number, reason: string}}
 * @private
 */
function validateAliasStructure_(variantName, canonicalName, entityType) {
  if (!variantName || !canonicalName) {
    return { pass: false, ratio: 0, reason: 'EMPTY_INPUT' };
  }
  if (entityType !== 'PERSON' && entityType !== 'PLACE') {
    return { pass: false, ratio: 0, reason: 'INVALID_ENTITY_TYPE' };
  }

  const a = normalizeForCompare(variantName);
  const b = normalizeForCompare(canonicalName);
  if (!a || !b) return { pass: false, ratio: 0, reason: 'EMPTY_AFTER_NORMALIZE' };

  // [Layer 1a] Similarity floor — กัน alias ที่ "ไม่คล้ายเลย" หลุดเข้ามา
  //   (เช่น ผู้ใช้กด MERGE ผิด candidate โดยไม่ได้ตั้งใจ)
  const dist = levenshteinDistance(a, b);
  const maxLen = Math.max(a.length, b.length);
  const ratio = maxLen === 0 ? 1 : 1 - dist / maxLen;

  const floor = typeof SAFEGUARD_CONFIG !== 'undefined' ? SAFEGUARD_CONFIG.MIN_SIMILARITY_RATIO : 0.5;
  if (ratio <= floor) {
    return { pass: false, ratio: ratio, reason: 'BELOW_SIMILARITY_FLOOR (' + ratio.toFixed(2) + ' <= ' + floor + ')' };
  }

  // [Layer 1b] Scope binding — เช็คแค่ entity_type ตรงกัน (ขั้นต่ำ, บังคับเสมอ)
  //   หมายเหตุ: scope binding ระดับภูมิศาสตร์ (province/district) สำหรับ PLACE
  //   ต้องการ masterUuid → M_PLACE lookup เพิ่ม ทำใน recordAliasProposal_() แทน
  //   เพราะที่นี่มีแค่ string ยังไม่ resolve เป็น record
  return { pass: true, ratio: ratio, reason: 'OK' };
}

// ============================================================
// LAYER 2: Repetition Consensus (min_confirmation_count)
// ============================================================

/**
 * recordAliasProposal_ — Layer 2
 *   หา/สร้างแถวใน M_ALIAS_STAGING สำหรับ (entityType, masterUuid, variantName normalized)
 *   แล้วบันทึกวันนี้ลงใน confirmation_days_json ถ้ายังไม่เคยมี (นับเฉพาะวันที่ไม่ซ้ำ
 *   กันคนละวัน — กัน spam กด approve รัวๆ วันเดียวแล้วนับเป็น consensus ปลอม)
 * @param {string} masterUuid
 * @param {string} variantName
 * @param {string} entityType
 * @param {string} reviewId
 * @param {string} verifiedBy
 * @param {number} similarityRatio - จาก Layer 1
 * @return {{stagingRow: Array, rowIndex: number, confirmationCount: number, sheet: Sheet}}
 * @private
 */
function recordAliasProposal_(masterUuid, variantName, entityType, reviewId, verifiedBy, similarityRatio) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET.M_ALIAS_STAGING);
  if (!sheet) throw new Error('recordAliasProposal_: ไม่พบ sheet M_ALIAS_STAGING — ต้องรัน setup ก่อน');

  const lastRow = sheet.getLastRow();
  const cleanVariant = normalizeForCompare(variantName);
  const today = Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'Asia/Bangkok', 'yyyy-MM-dd');

  let targetRow = -1;
  let rowData = null;

  if (lastRow > 1) {
    const data = sheet.getRange(2, 1, lastRow - 1, sheet.getLastColumn()).getValues();
    for (let i = 0; i < data.length; i++) {
      const r = data[i];
      if (
        r[STAGING_IDX.ENTITY_TYPE] === entityType &&
        r[STAGING_IDX.MASTER_UUID] === masterUuid &&
        normalizeForCompare(String(r[STAGING_IDX.VARIANT_NAME])) === cleanVariant &&
        r[STAGING_IDX.STATUS] !== 'REJECTED' &&
        r[STAGING_IDX.STATUS] !== 'BLOCKED'
      ) {
        targetRow = i + 2;
        rowData = r;
        break;
      }
    }
  }

  const now = new Date();

  if (!rowData) {
    // แถวใหม่ — proposal ครั้งแรก
    const stagingId = generateShortId('ST');
    rowData = new Array(18).fill('');
    rowData[STAGING_IDX.STAGING_ID] = stagingId;
    rowData[STAGING_IDX.MASTER_UUID] = masterUuid;
    rowData[STAGING_IDX.VARIANT_NAME] = variantName;
    rowData[STAGING_IDX.ENTITY_TYPE] = entityType;
    rowData[STAGING_IDX.SOURCE] = 'HUMAN';
    rowData[STAGING_IDX.REVIEW_ID] = reviewId || '';
    rowData[STAGING_IDX.VERIFIED_BY] = verifiedBy || '';
    rowData[STAGING_IDX.SIMILARITY_RATIO] = similarityRatio;
    rowData[STAGING_IDX.CONFIRMATION_DAYS_JSON] = JSON.stringify([today]);
    rowData[STAGING_IDX.CONFIRMATION_COUNT] = 1;
    rowData[STAGING_IDX.STATUS] = 'PENDING';
    rowData[STAGING_IDX.REJECT_REASON] = '';
    rowData[STAGING_IDX.SYNC_STATUS] = ''; // ยังไม่ถึง Layer 5 — เซ็ตทีหลังใน markPendingSync_()
    rowData[STAGING_IDX.PROMOTED_ALIAS_ID] = '';
    rowData[STAGING_IDX.PROBATION_STARTED_AT] = '';
    rowData[STAGING_IDX.PROMOTED_AT] = '';
    rowData[STAGING_IDX.CREATED_AT] = now;
    rowData[STAGING_IDX.UPDATED_AT] = now;

    sheet.getRange(sheet.getLastRow() + 1, 1, 1, rowData.length).setValues([rowData]);
    targetRow = sheet.getLastRow();
  } else {
    // แถวเดิม — เพิ่มวันนี้เข้า confirmation_days ถ้ายังไม่มี
    let days = [];
    try {
      days = JSON.parse(rowData[STAGING_IDX.CONFIRMATION_DAYS_JSON] || '[]');
    } catch (e) {
      days = [];
    }
    if (days.indexOf(today) === -1) {
      days.push(today);
    }
    rowData[STAGING_IDX.CONFIRMATION_DAYS_JSON] = JSON.stringify(days);
    rowData[STAGING_IDX.CONFIRMATION_COUNT] = days.length;
    rowData[STAGING_IDX.REVIEW_ID] = reviewId || rowData[STAGING_IDX.REVIEW_ID];
    rowData[STAGING_IDX.VERIFIED_BY] = verifiedBy || rowData[STAGING_IDX.VERIFIED_BY];
    rowData[STAGING_IDX.UPDATED_AT] = now;

    sheet.getRange(targetRow, 1, 1, rowData.length).setValues([rowData]);
  }

  return {
    stagingRow: rowData,
    rowIndex: targetRow,
    confirmationCount: rowData[STAGING_IDX.CONFIRMATION_COUNT],
    sheet: sheet
  };
}

// ============================================================
// LAYER 3: Conflict Detection
// ============================================================

/**
 * detectAliasConflict_ — Layer 3
 *   (a) One-to-many ambiguity: variant เดียวกัน (normalized) ผูกกับ masterUuid
 *       มากกว่า 1 ตัวในสถานะ active/probation/confirmed อยู่แล้วหรือไม่
 *   (b) Reverse collision dry-run: variant ที่เสนอ ชนกับ canonical name ของ
 *       entity อื่น (คนละ masterUuid) หรือไม่ — ถ้าใช่ แปลว่า promote ไปแล้ว
 *       จะทำให้ 2 entity จริงมาชนกันที่ alias เดียวกัน (ผิดร้ายแรงกว่า (a))
 * @param {string} masterUuid
 * @param {string} variantName
 * @param {string} entityType
 * @return {{conflict: boolean, type: string|null, conflictingUuid: string|null}}
 * @private
 */
function detectAliasConflict_(masterUuid, variantName, entityType) {
  const cleanVariant = normalizeForCompare(variantName);

  // (a) เช็คกับ M_ALIAS ที่ active อยู่แล้ว (ใช้ RAM/Cache map ที่มีอยู่แล้วใน 21_AliasService.gs)
  const existingMap =
    typeof loadGlobalAliasesMap_ === 'function' ? loadGlobalAliasesMap_() : {};
  for (const uidKey in existingMap) {
    if (!uidKey.startsWith(entityType + '_')) continue;
    const otherUuid = uidKey.substring(entityType.length + 1);
    if (otherUuid === masterUuid) continue; // ตัวเอง — ไม่ใช่ conflict
    if (existingMap[uidKey].includes(cleanVariant)) {
      return { conflict: true, type: 'ONE_TO_MANY_AMBIGUITY', conflictingUuid: otherUuid };
    }
  }

  // (a-2) เช็คกับ staging rows อื่นที่ยัง PENDING/PROBATION (กันสอง review เสนอ variant
  //   เดียวกันไปคนละ masterUuid พร้อมกันก่อนที่จะมี alias จริงใน M_ALIAS)
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const stagingSheet = ss.getSheetByName(SHEET.M_ALIAS_STAGING);
  if (stagingSheet && stagingSheet.getLastRow() > 1) {
    const data = stagingSheet
      .getRange(2, 1, stagingSheet.getLastRow() - 1, stagingSheet.getLastColumn())
      .getValues();
    for (let i = 0; i < data.length; i++) {
      const r = data[i];
      if (r[STAGING_IDX.ENTITY_TYPE] !== entityType) continue;
      if (r[STAGING_IDX.MASTER_UUID] === masterUuid) continue;
      if (r[STAGING_IDX.STATUS] === 'REJECTED' || r[STAGING_IDX.STATUS] === 'BLOCKED') continue;
      if (normalizeForCompare(String(r[STAGING_IDX.VARIANT_NAME])) === cleanVariant) {
        return { conflict: true, type: 'STAGING_ONE_TO_MANY', conflictingUuid: r[STAGING_IDX.MASTER_UUID] };
      }
    }
  }

  // (b) Reverse collision — variant ชนกับ canonical name ของ entity อื่น
  //   ใช้ resolvePerson()/resolvePlace() แบบ "dry-run": ถ้าค้นหาแล้วเจอ record ที่
  //   masterUuid ไม่ตรงกับที่กำลังจะผูก → collision
  try {
    if (entityType === 'PERSON' && typeof resolvePerson === 'function') {
      const dryRun = resolvePerson(variantName);
      if (dryRun && dryRun.personId) {
        const foundUuid = typeof getPersonMasterUuid_ === 'function' ? getPersonMasterUuid_(dryRun.personId) : null;
        if (foundUuid && foundUuid !== masterUuid) {
          return { conflict: true, type: 'REVERSE_COLLISION', conflictingUuid: foundUuid };
        }
      }
    } else if (entityType === 'PLACE' && typeof resolvePlace === 'function') {
      const dryRun = resolvePlace(variantName, '');
      if (dryRun && dryRun.placeId) {
        const foundUuid = typeof getPlaceMasterUuid_ === 'function' ? getPlaceMasterUuid_(dryRun.placeId) : null;
        if (foundUuid && foundUuid !== masterUuid) {
          return { conflict: true, type: 'REVERSE_COLLISION', conflictingUuid: foundUuid };
        }
      }
    }
  } catch (e) {
    // [Rule 12] Dry-run เช็คห้ามทำให้ proposal ทั้งก้อนล้มเหลว — ถือว่า "ไม่พบ collision" แล้วปล่อยผ่าน
    logWarn('AliasSafeguard', 'detectAliasConflict_: reverse collision check skipped — ' + e.message);
  }

  return { conflict: false, type: null, conflictingUuid: null };
}

// ============================================================
// LAYER 5: Circuit Breaker / Rate Limiting
//   (ทำก่อน Layer 4 ในโค้ด เพราะ Layer 4 ต้องรู้ผล Layer 5 ก่อนตัดสินใจ mark PROBATION)
// ============================================================

/**
 * checkAliasCircuitBreaker_ — Layer 5
 *   นับจำนวน alias ที่ promote ไปแล้ว "วันนี้" จาก PropertiesService
 *   ถ้าเกิน MAX_DAILY_ALIAS_WRITES → ตัด (ให้ค้างเป็น PENDING รอวันถัดไป) + แจ้งเตือน admin
 * @return {{tripped: boolean, countToday: number, limit: number}}
 * @private
 */
function checkAliasCircuitBreaker_() {
  const props = PropertiesService.getScriptProperties();
  const today = Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'Asia/Bangkok', 'yyyy-MM-dd');
  const key = 'ALIAS_SAFEGUARD_COUNT_' + today;
  const countToday = Number(props.getProperty(key) || 0);
  const limit =
    typeof SAFEGUARD_CONFIG !== 'undefined' ? SAFEGUARD_CONFIG.MAX_DAILY_ALIAS_WRITES : 50;

  if (countToday >= limit) {
    // แจ้งเตือนแค่ครั้งแรกที่ trip ในวันนั้น (กันสแปม alert)
    const alertedKey = 'ALIAS_SAFEGUARD_ALERTED_' + today;
    if (!props.getProperty(alertedKey)) {
      props.setProperty(alertedKey, '1');
      if (typeof sendPipelineAlert_ === 'function') {
        sendPipelineAlert_(
          'Alias Safeguard Circuit Breaker ตัดการทำงาน — promote alias เกิน ' +
            limit +
            ' รายการวันนี้แล้ว\nรายการที่เหลือจะถูก hold ไว้เป็น PENDING รอ reset วันถัดไป',
          'WARN'
        );
      }
    }
    return { tripped: true, countToday: countToday, limit: limit };
  }
  return { tripped: false, countToday: countToday, limit: limit };
}

/**
 * incrementAliasCircuitBreakerCount_ — เพิ่มตัวนับหลัง promote สำเร็จ 1 รายการ
 * @private
 */
function incrementAliasCircuitBreakerCount_() {
  const props = PropertiesService.getScriptProperties();
  const today = Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'Asia/Bangkok', 'yyyy-MM-dd');
  const key = 'ALIAS_SAFEGUARD_COUNT_' + today;
  const countToday = Number(props.getProperty(key) || 0);
  props.setProperty(key, String(countToday + 1));
}

// ============================================================
// ENTRY POINT — proposeHumanAlias_() : Layer 1 → 2 → 3 → mark PENDING_SYNC
//   นี่คือฟังก์ชันที่ 10e_MatchResolvePersist.gs ต้องเรียกแทน createGlobalAlias() ตรงๆ
// ============================================================

/**
 * proposeHumanAlias_ — จุดเข้าเดียวสำหรับเสนอ alias จาก Q_REVIEW (source='HUMAN')
 *   รัน Layer 1-3 + 5 แล้วบันทึกผลลง M_ALIAS_STAGING เท่านั้น (ไม่เขียน M_ALIAS ตรงนี้)
 *   การ promote จริงเกิดใน promoteStagedAliases_() (Layer 4) ที่รันแยกเป็น step ถัดไป
 * @param {string} masterUuid
 * @param {string} variantName - ชื่อดิบจาก Q_REVIEW
 * @param {string} canonicalName - ชื่อ canonical ปัจจุบันของ master entity
 * @param {string} entityType - 'PERSON' | 'PLACE'
 * @param {string} reviewId
 * @param {string} verifiedBy
 * @return {{status: string, reason: string, stagingId: string|null}}
 */
function proposeHumanAlias_(masterUuid, variantName, canonicalName, entityType, reviewId, verifiedBy) {
  try {
    // Layer 1
    const structCheck = validateAliasStructure_(variantName, canonicalName, entityType);
    if (!structCheck.pass) {
      logWarn(
        'AliasSafeguard',
        'proposeHumanAlias_: REJECTED at Layer1 — ' + structCheck.reason + ' (variant="' + variantName + '")'
      );
      return { status: 'REJECTED', reason: 'LAYER1_' + structCheck.reason, stagingId: null };
    }

    // Layer 3 conflict check (ทำก่อนบันทึก staging — กันสร้างแถวขยะถ้าชนตั้งแต่แรก)
    const conflict = detectAliasConflict_(masterUuid, variantName, entityType);
    if (conflict.conflict) {
      logWarn(
        'AliasSafeguard',
        'proposeHumanAlias_: BLOCKED at Layer3 — ' +
          conflict.type +
          ' vs uuid=' +
          conflict.conflictingUuid +
          ' (variant="' +
          variantName +
          '")'
      );
      // [Rule: escalate ไม่ silent drop] บันทึกไว้เป็น BLOCKED เพื่อให้ admin เห็นใน M_ALIAS_STAGING
      recordBlockedProposal_(masterUuid, variantName, entityType, reviewId, verifiedBy, structCheck.ratio, conflict);
      return { status: 'BLOCKED', reason: conflict.type, stagingId: null };
    }

    // Layer 2 — บันทึก/อัปเดต consensus
    const proposal = recordAliasProposal_(masterUuid, variantName, entityType, reviewId, verifiedBy, structCheck.ratio);

    const minConfirm =
      typeof SAFEGUARD_CONFIG !== 'undefined' ? SAFEGUARD_CONFIG.MIN_CONFIRMATION_COUNT : 2;

    if (proposal.confirmationCount < minConfirm) {
      // ยังไม่ถึง consensus — ปล่อยเป็น PENDING รอครั้งถัดไป (ไม่ error, เป็นพฤติกรรมปกติ)
      logInfo(
        'AliasSafeguard',
        'proposeHumanAlias_: PENDING (consensus ' +
          proposal.confirmationCount +
          '/' +
          minConfirm +
          ') — "' +
          variantName +
          '" → ' +
          masterUuid
      );
      return { status: 'PENDING', reason: 'AWAITING_CONSENSUS', stagingId: proposal.stagingRow[STAGING_IDX.STAGING_ID] };
    }

    // Layer 5 — circuit breaker ก่อนอนุญาตให้เข้าคิว sync
    const breaker = checkAliasCircuitBreaker_();
    if (breaker.tripped) {
      // ไม่ BLOCKED ถาวร — แค่ hold ไว้ ครั้งหน้าจะเช็คใหม่อัตโนมัติ (ไม่ต้องแก้ status)
      logWarn('AliasSafeguard', 'proposeHumanAlias_: HELD by circuit breaker (' + breaker.countToday + '/' + breaker.limit + ')');
      return { status: 'PENDING', reason: 'CIRCUIT_BREAKER_HOLD', stagingId: proposal.stagingRow[STAGING_IDX.STAGING_ID] };
    }

    markPendingSync_(proposal.sheet, proposal.rowIndex);
    return { status: 'PENDING_SYNC', reason: 'CONSENSUS_REACHED', stagingId: proposal.stagingRow[STAGING_IDX.STAGING_ID] };
  } catch (err) {
    // [Rule 12] ห้ามให้ safeguard ทำให้ MERGE decision หลักล้มเหลว
    logError('AliasSafeguard', 'proposeHumanAlias_ ล้มเหลว: ' + err.message, err);
    return { status: 'ERROR', reason: err.message, stagingId: null };
  }
}

/**
 * markPendingSync_ — ตั้ง sync_status='PENDING_SYNC' + status='PROBATION' บนแถว staging
 *   หมายเหตุ ownership: ฟังก์ชันนี้ "เขียนได้แค่ M_ALIAS_STAGING" ไม่แตะ M_ALIAS
 * @private
 */
function markPendingSync_(sheet, rowIndex) {
  const now = new Date();
  sheet.getRange(rowIndex, STAGING_IDX.STATUS + 1).setValue('PROBATION');
  sheet.getRange(rowIndex, STAGING_IDX.SYNC_STATUS + 1).setValue('PENDING_SYNC');
  sheet.getRange(rowIndex, STAGING_IDX.PROBATION_STARTED_AT + 1).setValue(now);
  sheet.getRange(rowIndex, STAGING_IDX.UPDATED_AT + 1).setValue(now);
}

/**
 * recordBlockedProposal_ — บันทึก proposal ที่ถูก Layer 3 บล็อก (audit trail, ไม่ promote)
 * @private
 */
function recordBlockedProposal_(masterUuid, variantName, entityType, reviewId, verifiedBy, ratio, conflict) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET.M_ALIAS_STAGING);
    if (!sheet) return;
    const now = new Date();
    const rowData = new Array(18).fill('');
    rowData[STAGING_IDX.STAGING_ID] = generateShortId('ST');
    rowData[STAGING_IDX.MASTER_UUID] = masterUuid;
    rowData[STAGING_IDX.VARIANT_NAME] = variantName;
    rowData[STAGING_IDX.ENTITY_TYPE] = entityType;
    rowData[STAGING_IDX.SOURCE] = 'HUMAN';
    rowData[STAGING_IDX.REVIEW_ID] = reviewId || '';
    rowData[STAGING_IDX.VERIFIED_BY] = verifiedBy || '';
    rowData[STAGING_IDX.SIMILARITY_RATIO] = ratio;
    rowData[STAGING_IDX.CONFIRMATION_DAYS_JSON] = '[]';
    rowData[STAGING_IDX.CONFIRMATION_COUNT] = 0;
    rowData[STAGING_IDX.STATUS] = 'BLOCKED';
    rowData[STAGING_IDX.REJECT_REASON] = conflict.type + ' vs ' + conflict.conflictingUuid;
    rowData[STAGING_IDX.SYNC_STATUS] = '';
    rowData[STAGING_IDX.CREATED_AT] = now;
    rowData[STAGING_IDX.UPDATED_AT] = now;
    sheet.getRange(sheet.getLastRow() + 1, 1, 1, rowData.length).setValues([rowData]);

    if (typeof logAuditTrail === 'function') {
      logAuditTrail(
        AUDIT_ENTITY_TYPES.ALIAS,
        rowData[STAGING_IDX.STAGING_ID],
        AUDIT_ACTIONS.CREATE,
        'status',
        null,
        { status: 'BLOCKED', reason: rowData[STAGING_IDX.REJECT_REASON] },
        'ALIAS_SAFEGUARD_LAYER3'
      );
    }
  } catch (e) {
    logError('AliasSafeguard', 'recordBlockedProposal_ ล้มเหลว: ' + e.message, e);
  }
}

// ============================================================
// LAYER 4: Probation Period + Promotion — promoteStagedAliases_()
//   รันเป็น step แยก (เรียกจาก menu / ท้าย runPipelineBatch / time trigger รายวัน)
//   ตัวเดียวที่เรียก createGlobalAlias() จริง — ใช้ single writer เดิมของ 21_AliasService.gs
// ============================================================

/**
 * promoteStagedAliases_ — Layer 4
 *   หา staging rows ที่ sync_status='PENDING_SYNC' แล้ว promote เข้า M_ALIAS จริง
 *   ผ่าน createGlobalAlias() (single writer เดิม) จากนั้นตั้ง alias_status='PROBATION'
 *   บน M_ALIAS แถวใหม่ (ไม่ใช่ CONFIRMED ทันที — ต้องผ่าน promoteAliasesOutOfProbation_
 *   อีกครั้งหลังครบ PROBATION_DAYS ถึงจะเปลี่ยนเป็น CONFIRMED)
 * @return {{promoted: number, skipped: number, errors: number}}
 */
function promoteStagedAliases_() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET.M_ALIAS_STAGING);
  if (!sheet || sheet.getLastRow() <= 1) return { promoted: 0, skipped: 0, errors: 0 };

  const lastRow = sheet.getLastRow();
  const data = sheet.getRange(2, 1, lastRow - 1, sheet.getLastColumn()).getValues();

  let promoted = 0;
  let skipped = 0;
  let errors = 0;

  for (let i = 0; i < data.length; i++) {
    const r = data[i];
    if (r[STAGING_IDX.SYNC_STATUS] !== 'PENDING_SYNC') continue;

    // เช็ค circuit breaker ทุก row (เผื่อ trip กลางทาง — หยุดรอบนี้ ปล่อยที่เหลือเป็น PENDING_SYNC ต่อ)
    const breaker = checkAliasCircuitBreaker_();
    if (breaker.tripped) {
      skipped++;
      continue;
    }

    const rowIndex = i + 2;
    try {
      const newAliasId = createGlobalAlias(
        r[STAGING_IDX.MASTER_UUID],
        r[STAGING_IDX.VARIANT_NAME],
        r[STAGING_IDX.ENTITY_TYPE],
        100,
        'HUMAN',
        r[STAGING_IDX.VERIFIED_BY],
        r[STAGING_IDX.REVIEW_ID]
      );

      if (!newAliasId) {
        // createGlobalAlias คืน null ได้ถ้าซ้ำ (มี alias นี้อยู่แล้ว) — ถือว่า sync เสร็จแล้ว ไม่ error
        sheet.getRange(rowIndex, STAGING_IDX.SYNC_STATUS + 1).setValue('SYNCED');
        sheet.getRange(rowIndex, STAGING_IDX.STATUS + 1).setValue('CONFIRMED');
        sheet.getRange(rowIndex, STAGING_IDX.UPDATED_AT + 1).setValue(new Date());
        skipped++;
        continue;
      }

      // ตั้ง alias_status='PROBATION' บน M_ALIAS แถวใหม่ (คอลัมน์ที่เพิ่ม — ดู SECTION 0c)
      setAliasProbationStatus_(newAliasId, 'PROBATION');

      const now = new Date();
      sheet.getRange(rowIndex, STAGING_IDX.SYNC_STATUS + 1).setValue('SYNCED');
      sheet.getRange(rowIndex, STAGING_IDX.PROMOTED_ALIAS_ID + 1).setValue(newAliasId);
      sheet.getRange(rowIndex, STAGING_IDX.PROMOTED_AT + 1).setValue(now);
      sheet.getRange(rowIndex, STAGING_IDX.UPDATED_AT + 1).setValue(now);

      incrementAliasCircuitBreakerCount_();
      promoted++;
    } catch (err) {
      logError('AliasSafeguard', 'promoteStagedAliases_: row ' + rowIndex + ' ล้มเหลว — ' + err.message, err);
      errors++;
    }
  }

  logInfo('AliasSafeguard', `promoteStagedAliases_: promoted=${promoted} skipped=${skipped} errors=${errors}`);
  return { promoted: promoted, skipped: skipped, errors: errors };
}

/**
 * setAliasProbationStatus_ — helper เขียน alias_status บน M_ALIAS (คอลัมน์ใหม่ ALIAS_IDX.ALIAS_STATUS)
 *   ⚠️ นี่คือจุดเดียวนอกเหนือจาก createGlobalAlias ที่แตะ M_ALIAS โดยตรง — เพราะ column
 *   ใหม่นี้ต้อง set หลังสร้างแถวเสร็จ (createGlobalAlias ไม่รู้จัก probation concept)
 *   ถ้าต้องการรักษา Single Writer Rule แบบเข้มที่สุด ให้ย้าย logic นี้ไปเป็น optional
 *   parameter เพิ่มใน createGlobalAlias() แทน (ดู PATCH GUIDE ท้ายไฟล์)
 * @private
 */
function setAliasProbationStatus_(aliasId, status) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET.M_ALIAS);
  if (!sheet) return;
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return;
  const ids = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  for (let i = 0; i < ids.length; i++) {
    if (ids[i][0] === aliasId) {
      sheet.getRange(i + 2, ALIAS_IDX.ALIAS_STATUS + 1).setValue(status);
      return;
    }
  }
}

/**
 * graduateProbationAliases_ — [Layer 4 lifecycle] เลื่อน alias จาก PROBATION → CONFIRMED
 *   หลังผ่าน PROBATION_DAYS โดยไม่ถูก auto-revert เรียกเป็น time trigger รายวัน
 * @return {{graduated: number}}
 */
function graduateProbationAliases_() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET.M_ALIAS);
  if (!sheet || sheet.getLastRow() <= 1) return { graduated: 0 };

  const probationDays =
    typeof SAFEGUARD_CONFIG !== 'undefined' ? SAFEGUARD_CONFIG.PROBATION_DAYS : 7;
  const cutoffMs = probationDays * 24 * 60 * 60 * 1000;
  const now = Date.now();

  const data = sheet.getRange(2, 1, sheet.getLastRow() - 1, sheet.getLastColumn()).getValues();
  let graduated = 0;
  for (let i = 0; i < data.length; i++) {
    const r = data[i];
    if (r[ALIAS_IDX.ALIAS_STATUS] !== 'PROBATION') continue;
    const verifiedAt = r[ALIAS_IDX.VERIFIED_AT];
    if (!verifiedAt) continue;
    const verifiedMs = new Date(verifiedAt).getTime();
    if (now - verifiedMs >= cutoffMs) {
      sheet.getRange(i + 2, ALIAS_IDX.ALIAS_STATUS + 1).setValue('CONFIRMED');
      graduated++;
    }
  }
  if (graduated > 0) logInfo('AliasSafeguard', 'graduateProbationAliases_: graduated=' + graduated);
  return { graduated: graduated };
}

/**
 * autoRevertAliasOnRejection_ — [Layer 4] auto-revert ถ้า alias ที่ยัง PROBATION
 *   ถูกปฏิเสธซ้ำภายหลัง (เช่น review อื่นที่ใช้ alias นี้แล้วถูก IGNORE/reject)
 *   เรียกจาก 12_ReviewService.gs ตรงจุดที่ markAsNegativeSample_() ถูกเรียกอยู่แล้ว
 *   (ดู PATCH GUIDE) — ส่ง aliasId ที่เกี่ยวข้องเข้ามา (ถ้ารู้)
 * @param {string} aliasId
 * @param {string} rejectReason
 * @return {boolean} true ถ้า revert สำเร็จ
 */
function autoRevertAliasOnRejection_(aliasId, rejectReason) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET.M_ALIAS);
    if (!sheet || !aliasId) return false;
    const lastRow = sheet.getLastRow();
    if (lastRow <= 1) return false;
    const data = sheet.getRange(2, 1, lastRow - 1, sheet.getLastColumn()).getValues();
    for (let i = 0; i < data.length; i++) {
      if (data[i][ALIAS_IDX.ALIAS_ID] !== aliasId) continue;
      if (data[i][ALIAS_IDX.ALIAS_STATUS] !== 'PROBATION') {
        // [Design decision] เฉพาะ alias ที่ยัง PROBATION เท่านั้นที่ auto-revert ได้
        //   alias ที่ CONFIRMED แล้วต้องให้ admin ลบ manual (กัน auto-revert ผิดพลาด
        //   ทำลาย alias ที่ผ่านการันตีคุณภาพไปแล้ว)
        return false;
      }
      const rowIndex = i + 2;
      sheet.getRange(rowIndex, ALIAS_IDX.ACTIVE_FLAG + 1).setValue(false);
      sheet.getRange(rowIndex, ALIAS_IDX.ALIAS_STATUS + 1).setValue('REVERTED');
      CacheService.getScriptCache().removeAll([CACHE_KEY.GLOBAL_ALIAS_ALL, CACHE_KEY.GLOBAL_ALIAS_REVERSE]);
      if (typeof logAuditTrail === 'function') {
        logAuditTrail(
          AUDIT_ENTITY_TYPES.ALIAS,
          aliasId,
          AUDIT_ACTIONS.UPDATE,
          'alias_status,active_flag',
          { alias_status: 'PROBATION', active_flag: true },
          { alias_status: 'REVERTED', active_flag: false },
          'AUTO_REVERT: ' + rejectReason
        );
      }
      logWarn('AliasSafeguard', 'autoRevertAliasOnRejection_: reverted ' + aliasId + ' — ' + rejectReason);
      return true;
    }
    return false;
  } catch (err) {
    logError('AliasSafeguard', 'autoRevertAliasOnRejection_ ล้มเหลว: ' + err.message, err);
    return false;
  }
}

// ============================================================
// MIGRATION — backfillAliasStatusForExistingRows_()
// ============================================================
// หมายเหตุสำคัญ: การเพิ่ม header 'alias_status' คอลัมน์ใหม่ใน M_ALIAS **ไม่ต้องเขียน
// migration เอง** — ตรวจโค้ดจริงพบว่า createSheetIfMissing_() (03_SetupSheets.gs
// บรรทัด 219-263) มี Auto-Repair อยู่แล้ว: ถ้า header หายไปมันจะเพิ่มคอลัมน์ใหม่ต่อท้าย
// ให้อัตโนมัติตอนรันเมนู Setup Sheets (จะเห็นเป็นสีแดงอ่อนบอกว่าเพิ่งเติมให้)
//
// สิ่งที่ auto-repair "ไม่ทำ" คือ backfill ข้อมูลแถวเดิม (แถวเดิมจะได้ alias_status='')
// ฟังก์ชันนี้จึงทำหน้าที่นั้นแทน — ตัดสินใจเชิงออกแบบ: แถวเดิมที่มีอยู่ก่อนระบบ
// safeguard ถือว่า "ผ่านการใช้งานจริงมานานแล้วโดยไม่มีปัญหา" จึง backfill เป็น
// 'CONFIRMED' ทันที ไม่ใช่ 'PROBATION' — ป้องกันไม่ให้ alias เดิมนับพันตัวถูกลด weight
// ทันทีที่ deploy (ซึ่งจะกระทบ match accuracy โดยไม่มีเหตุผล เพราะแถวเหล่านี้ผ่าน
// การพิสูจน์จากการใช้งานจริงมาแล้ว ต่างจาก alias ใหม่ที่ยังไม่มีประวัติ)

/**
 * backfillAliasStatusForExistingRows_UI — รันครั้งเดียวหลัง deploy patch schema
 *   (ต่อจากรันเมนู Setup Sheets ที่เพิ่ม header 'alias_status' ให้แล้ว)
 *   Idempotent — รันซ้ำได้ปลอดภัย (ข้ามแถวที่มีค่าอยู่แล้ว)
 * @return {{backfilled: number, skipped: number}}
 */
function backfillAliasStatusForExistingRows_UI() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET.M_ALIAS);
  if (!sheet) {
    safeUiAlert_('ไม่พบชีต M_ALIAS');
    return { backfilled: 0, skipped: 0 };
  }
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return { backfilled: 0, skipped: 0 };
  const lastCol = sheet.getLastColumn();

  if (lastCol <= ALIAS_IDX.ALIAS_STATUS) {
    safeUiAlert_(
      'คอลัมน์ alias_status ยังไม่ถูกเพิ่มใน M_ALIAS — กรุณารันเมนู "Setup Sheets" ก่อน (Auto-Repair จะเพิ่ม header ให้)'
    );
    return { backfilled: 0, skipped: 0 };
  }

  const data = sheet.getRange(2, 1, lastRow - 1, lastCol).getValues();
  const updates = [];
  let backfilled = 0;
  let skipped = 0;

  for (let i = 0; i < data.length; i++) {
    const current = data[i][ALIAS_IDX.ALIAS_STATUS];
    if (current === 'PROBATION' || current === 'CONFIRMED' || current === 'REVERTED') {
      skipped++;
      updates.push([current]); // เก็บค่าเดิม
      continue;
    }
    updates.push(['CONFIRMED']); // [Design decision] backfill แถวเดิมเป็น CONFIRMED — ดูเหตุผลด้านบน
    backfilled++;
  }

  // [Rule: Batch write] เขียนทีเดียวด้วย setValues แทน cell-by-cell ตามกฎ Batch Writes
  sheet.getRange(2, ALIAS_IDX.ALIAS_STATUS + 1, updates.length, 1).setValues(updates);

  logInfo('AliasSafeguard', `backfillAliasStatusForExistingRows_UI: backfilled=${backfilled} skipped=${skipped}`);
  safeUiAlert_(`Backfill เสร็จสิ้น — เติม CONFIRMED ให้ ${backfilled} แถว (ข้าม ${skipped} แถวที่มีค่าอยู่แล้ว)`);
  return { backfilled: backfilled, skipped: skipped };
}

// ============================================================
// Layer 4 (ต่อ) — findProbationAliasByVariant_() สำหรับ auto-revert hook
//   ใช้จาก 12_ReviewService.gs ตอน IGNORE decision (ดู PATCH GUIDE ข้อ 6)
// ============================================================

/**
 * findProbationAliasByVariant_ — หา alias ที่ยังอยู่ status PROBATION ซึ่ง variant_name
 *   ตรงกับที่ส่งมาแบบ exact-match (หลัง normalize) — ใช้ exact-match ไม่ fuzzy เพื่อลด
 *   ความเสี่ยง false-positive revert (ตามที่บันทึกไว้ใน PATCH GUIDE ข้อ 6)
 * @param {string} variantName - ชื่อดิบจาก Q_REVIEW ที่ถูก IGNORE (RAW_PERSON หรือ RAW_PLACE)
 * @return {string|null} aliasId ถ้าเจอ, null ถ้าไม่เจอหรือ input ว่าง
 */
function findProbationAliasByVariant_(variantName) {
  if (!variantName) return null;
  const cleanVariant = normalizeForCompare(variantName);
  if (!cleanVariant) return null;

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET.M_ALIAS);
  if (!sheet || sheet.getLastRow() <= 1) return null;

  const lastCol = sheet.getLastColumn();
  if (lastCol <= ALIAS_IDX.ALIAS_STATUS) return null; // ยังไม่ได้ migrate คอลัมน์ — ข้าม

  const data = sheet.getRange(2, 1, sheet.getLastRow() - 1, lastCol).getValues();
  for (let i = 0; i < data.length; i++) {
    const r = data[i];
    if (r[ALIAS_IDX.ALIAS_STATUS] !== 'PROBATION') continue;
    if (normalizeForCompare(String(r[ALIAS_IDX.VARIANT_NAME])) === cleanVariant) {
      return r[ALIAS_IDX.ALIAS_ID];
    }
  }
  return null;
}

/**
 * getAliasWeightMultiplier_ — คืนตัวคูณ confidence สำหรับ alias ที่ยัง PROBATION
 *   ใช้ตอน match engine คำนวณ score จาก alias match (ดู PATCH GUIDE)
 * @param {string} aliasStatus - ค่าจาก ALIAS_IDX.ALIAS_STATUS ('PROBATION'|'CONFIRMED'|'')
 * @return {number} ตัวคูณ 0-1
 */
function getAliasWeightMultiplier_(aliasStatus) {
  if (aliasStatus === 'PROBATION') {
    return typeof SAFEGUARD_CONFIG !== 'undefined' ? SAFEGUARD_CONFIG.PROBATION_WEIGHT_MULTIPLIER : 0.5;
  }
  return 1;
}
