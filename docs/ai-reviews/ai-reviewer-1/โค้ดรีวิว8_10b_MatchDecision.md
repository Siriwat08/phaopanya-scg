/**
 * VERSION: 6.0.046
 * FILE: 10b_MatchDecision.gs
 * LMDS V6.0 — Match Decision Rules
 * ===================================================
 * PURPOSE:
 *   แยก match decision rules ออกจาก makeMatchDecision() (267 บรรทัด)
 *   เป็น pure functions แต่ละ rule — ลด complexity เพื่อ maintainability (audit 1.2)
 *   BACKWARD COMPATIBLE: makeMatchDecision() signature + return shape เหมือนเดิม 100%
 *
 * CHANGELOG:
 *   See /docs/CHANGELOG.md for full history.
 *
 * DEPENDENCIES:
 *   REQUIRES: (Load Order)
 *     - 01_Config.gs, 14_Utils.gs (core)
 *     - 05_NormalizeService.gs (normalize for similarity comparison)
 *     - 10_MatchEngine.gs       (match context types — referenced)
 *   CALLS: (Invokes)
 *     - normalizePersonName() / normalizePlaceName() → 05_NormalizeService.gs
 *     - levenshtein() / similarity helpers         → 14_Utils.gs
 *   EXPORTS TO:
 *     - 10_MatchEngine.gs (makeMatchDecision dispatcher)
 *   SHEETS ACCESSED:
 *     - (none — pure decision functions, no sheet access)
 *   TRIGGERS: None
 *
 * ARCHITECTURE:
 *   Group 1 — Master data building (normalize, persons, places, geo, match engine, aliases)
 * ===================================================
 */

// ============================================================
// SECTION: Match Decision Rules (extracted from makeMatchDecision)
//   Each rule returns { action, reason, confidence, priority, evidence? } or null
//   Rules are tried in order — first non-null wins
// ============================================================

/**
 * evaluateRule1_NoGeoInSource — ไม่มีพิกัดใน Source Sheet (0,0 หรือว่าง)
 * @param {Object} srcObj
 * @return {Object|null} decision or null if rule doesn't apply
 * @private
 */
function evaluateRule1_NoGeoInSource_(srcObj) {
  if (srcObj.hasGeo) return null;
  return {
    action: 'REVIEW',
    reason: 'INVALID_LATLNG',
    confidence: 0,
    priority: 1
  };
}

/**
 * evaluateRule2_LowQualityData — ชื่อคุณภาพต่ำ (สั้นเกินไปหรือมั่ว)
 * @param {Object} personResult
 * @param {Object} placeResult
 * @return {Object|null} decision or null
 * @private
 */
function evaluateRule2_LowQualityData_(personResult, placeResult) {
  if (personResult.status === 'LOW_QUALITY' || placeResult.status === 'LOW_QUALITY') {
    return {
      action: 'REVIEW',
      reason: 'LOW_QUALITY_DATA',
      confidence: 0,
      priority: 2
    };
  }
  return null;
}

/**
 * evaluateRule3_GeoProvinceConflict — จังหวัดข้ามโซน
 *   ถ้าพิกัดอยู่ใน Master แล้ว + จังหวัดต่างกัน → REVIEW
 * @param {boolean} isGeoInMaster
 * @param {string} geoProvince
 * @param {string} srcProvince
 * @return {Object|null} decision or null
 * @private
 */
function evaluateRule3_GeoProvinceConflict_(isGeoInMaster, geoProvince, srcProvince) {
  if (!isGeoInMaster || !geoProvince || !srcProvince) return null;

  const normalizedGeoProvince =
    typeof normalizeProvinceForCompare_ === 'function' ? normalizeProvinceForCompare_(geoProvince) : geoProvince;
  const normalizedSrcProvince =
    typeof normalizeProvinceForCompare_ === 'function' ? normalizeProvinceForCompare_(srcProvince) : srcProvince;

  if (normalizedGeoProvince === normalizedSrcProvince) return null;

  return {
    action: 'REVIEW',
    reason: 'GEO_PROVINCE_CONFLICT',
    confidence: 50,
    priority: 2,
    evidence:
      'geoProvince="' +
      geoProvince +
      '"|srcProvince="' +
      srcProvince +
      '"|normalizedGeo="' +
      normalizedGeoProvince +
      '"|normalizedSrc="' +
      normalizedSrcProvince +
      '"'
  };
}

/**
 * evaluateRule3_5_NearbyPending — Tiered Spatial Fuzzy Matching (รอคนตรวจ)
 * @param {Object} geoResult
 * @return {Object|null} decision or null
 * @private
 */
function evaluateRule3_5_NearbyPending_(geoResult) {
  if (geoResult.status !== 'NEARBY_PENDING') return null;
  return {
    action: 'REVIEW',
    reason: geoResult.issue_type, // 'GEO_NEARBY_YELLOW' or 'GEO_NEARBY_ORANGE'
    confidence: 50,
    priority: 1
  };
}

/**
 * evaluateRule4_FullMatch — พบครบทั้ง 3 อย่างใน Master → AUTO_MATCH
 * @param {Object} srcObj
 * @param {Object} personResult
 * @param {Object} placeResult
 * @param {Object} geoResult
 * @param {boolean} isGeoInMaster
 * @param {boolean} isPersonInMaster
 * @param {boolean} isPlaceInMaster
 * @return {Object|null} decision or null
 * @private
 */
function evaluateRule4_FullMatch_(
  srcObj,
  personResult,
  placeResult,
  geoResult,
  isGeoInMaster,
  isPersonInMaster,
  isPlaceInMaster
) {
  if (!(isGeoInMaster && isPersonInMaster && isPlaceInMaster)) return null;

  const confidence = calculateWeightedScore(srcObj, personResult, placeResult, geoResult);
  return {
    action: 'AUTO_MATCH',
    reason: APP_CONST.MATCH_FULL,
    confidence: confidence,
    priority: 0,
    evidence: 'name|place|geo'
  };
}

/**
 * evaluateRule5_GeoPersonAnchor — [V6.0.016] geo + person → AUTO_MATCH
 *   มี geo-distance guard: >1km → REVIEW, >500m → ลด confidence
 * @param {Object} srcObj
 * @param {Object} personResult
 * @param {Object} placeResult
 * @param {Object} geoResult
 * @param {boolean} isGeoInMaster
 * @param {boolean} isPersonInMaster
 * @return {Object|null} decision or null
 * @private
 */
function evaluateRule5_GeoPersonAnchor_(srcObj, personResult, placeResult, geoResult, isGeoInMaster, isPersonInMaster) {
  if (!(isGeoInMaster && isPersonInMaster)) return null;

  const placeResultForScore = { confidence: 0 };
  let confidence = Math.min(95, calculateWeightedScore(srcObj, personResult, placeResultForScore, geoResult));
  let reason = APP_CONST.MATCH_GEO;
  let evidence = 'name|geo';

  // Geo-distance guard
  if (srcObj.hasGeo && srcObj.rawLat && srcObj.rawLng) {
    const srcLat = Number(srcObj.rawLat);
    const srcLng = Number(srcObj.rawLng);
    if (!isNaN(srcLat) && !isNaN(srcLng) && srcLat !== 0 && srcLng !== 0) {
      let candidateCoords = null;
      let candidateType = '';

      if (placeResult.placeId) {
        candidateCoords = getCandidateResolvedCoords_('PLACE', placeResult.placeId);
        if (candidateCoords) candidateType = 'place';
      }
      if (!candidateCoords && personResult.personId) {
        candidateCoords = getCandidateResolvedCoords_('PERSON', personResult.personId);
        if (candidateCoords) candidateType = 'person';
      }

      if (candidateCoords && candidateCoords.lat && candidateCoords.lng) {
        const distM = haversineDistanceM(srcLat, srcLng, candidateCoords.lat, candidateCoords.lng);
        if (distM > 1000) {
          confidence = Math.min(confidence, 50);
          reason = 'GEO_ANCHOR_FAR_APART';
          evidence = evidence + '|far_apart|dist=' + Math.round(distM) + 'm|' + candidateType;
        } else if (distM > 500) {
          confidence = Math.min(confidence, 70);
          evidence = evidence + '|moderate_dist|dist=' + Math.round(distM) + 'm|' + candidateType;
        }
      }
    }
  }

  if (reason === 'GEO_ANCHOR_FAR_APART' && confidence < AI_CONFIG.THRESHOLD_REVIEW) {
    return { action: 'REVIEW', reason: reason, confidence: confidence, priority: 1, evidence: evidence };
  }
  return { action: 'AUTO_MATCH', reason: reason, confidence: confidence, priority: 0, evidence: evidence };
}

/**
 * evaluateRule5b_GeoPlaceOnlyNoName — [V6.0.016] geo + place only → REVIEW
 *   เหตุผล: [24] มาจากพิกัด [4] → place + geo เป็นสัญญาณเดียวกัน
 * @param {Object} srcObj
 * @param {Object} personResult
 * @param {Object} placeResult
 * @param {Object} geoResult
 * @param {boolean} isGeoInMaster
 * @param {boolean} isPlaceInMaster
 * @param {boolean} isPersonInMaster
 * @return {Object|null} decision or null
 * @private
 */
function evaluateRule5b_GeoPlaceOnlyNoName_(
  srcObj,
  personResult,
  placeResult,
  geoResult,
  isGeoInMaster,
  isPlaceInMaster,
  isPersonInMaster
) {
  if (!(isGeoInMaster && isPlaceInMaster && !isPersonInMaster)) return null;

  const personResultForScore = { confidence: 0 };
  const confidence = Math.min(70, calculateWeightedScore(srcObj, personResultForScore, placeResult, geoResult));
  return {
    action: 'REVIEW',
    reason: 'GEO_ANCHOR_PLACE_ONLY_NO_NAME',
    confidence: confidence,
    priority: 1,
    evidence: 'place|geo|no_person'
  };
}

/**
 * evaluateRule6_FuzzyMatch — มีความกำกวม (NEEDS_REVIEW)
 *   มี geo-distance guard: ≤100m → AUTO_MATCH, >1km → ลด confidence
 * @param {Object} srcObj
 * @param {Object} personResult
 * @param {Object} placeResult
 * @return {Object|null} decision or null
 * @private
 */
function evaluateRule6_FuzzyMatch_(srcObj, personResult, placeResult) {
  if (personResult.status !== 'NEEDS_REVIEW' && placeResult.status !== 'NEEDS_REVIEW') return null;

  let confidence = Math.max(personResult.confidence, placeResult.confidence);
  let reason = APP_CONST.MATCH_FUZZY;
  let evidence = 'fuzzy';

  if (srcObj.hasGeo && srcObj.rawLat && srcObj.rawLng) {
    const srcLat = Number(srcObj.rawLat);
    const srcLng = Number(srcObj.rawLng);
    if (!isNaN(srcLat) && !isNaN(srcLng) && srcLat !== 0 && srcLng !== 0) {
      let candidateCoords = null;
      let candidateType = '';

      if (placeResult.placeId) {
        candidateCoords = getCandidateResolvedCoords_('PLACE', placeResult.placeId);
        if (candidateCoords) candidateType = 'place';
      }
      if (!candidateCoords && personResult.personId) {
        candidateCoords = getCandidateResolvedCoords_('PERSON', personResult.personId);
        if (candidateCoords) candidateType = 'person';
      }

      if (candidateCoords && candidateCoords.lat && candidateCoords.lng) {
        const distM = haversineDistanceM(srcLat, srcLng, candidateCoords.lat, candidateCoords.lng);

        // ≤ GEO_RADIUS_M → AUTO_MATCH (same place, name fuzzy)
        if (distM <= AI_CONFIG.GEO_RADIUS_M) {
          confidence = Math.max(confidence, 90);
          reason = APP_CONST.MATCH_FUZZY;
          evidence = 'fuzzy|geo_close|dist=' + Math.round(distM) + 'm|' + candidateType;
          return {
            action: 'AUTO_MATCH',
            reason: reason,
            confidence: confidence,
            priority: 0,
            evidence: evidence
          };
        }

        if (distM > 1000) {
          confidence = Math.min(confidence, 50);
          reason = 'FUZZY_MATCH_FAR_APART';
          evidence = 'fuzzy|far_apart|dist=' + Math.round(distM) + 'm|' + candidateType;
        } else if (distM > 500) {
          confidence = Math.min(confidence, 65);
          evidence = 'fuzzy|moderate_dist|dist=' + Math.round(distM) + 'm|' + candidateType;
        }
      }
    }
  }

  return {
    action: 'REVIEW',
    reason: reason,
    confidence: confidence,
    priority: 2,
    evidence: evidence
  };
}

/**
 * evaluateRule7_NewGeoWithGPS — มี GPS จริง + ไม่มี geo ใน master → CREATE_NEW
 * @param {boolean} hasGeoInSource
 * @param {boolean} isGeoInMaster
 * @return {Object|null} decision or null
 * @private
 */
function evaluateRule7_NewGeoWithGPS_(hasGeoInSource, isGeoInMaster) {
  if (!(hasGeoInSource && !isGeoInMaster)) return null;
  return {
    action: 'CREATE_NEW',
    reason: 'NEW_GEO_WITH_GPS',
    confidence: 100,
    priority: 0
  };
}

/**
 * evaluateRule8_NewGeoFromGPS — มี GPS จริง (default CREATE_NEW)
 * @param {boolean} hasGeoInSource
 * @return {Object|null} decision or null
 * @private
 */
function evaluateRule8_NewGeoFromGPS_(hasGeoInSource) {
  if (!hasGeoInSource) return null;
  return {
    action: 'CREATE_NEW',
    reason: 'NEW_GEO_FROM_GPS',
    confidence: 90,
    priority: 0
  };
}

// ============================================================
// [PHASE 2 REFACTOR] merged from 10_MatchEngine.gs — dispatcher + scoring
//   Fixes backward dependency: this file previously called calculateWeightedScore()
//   and getCandidateResolvedCoords_() which lived in 10_MatchEngine.gs. Now this
//   file is self-contained for all decision + scoring logic.
//   NOTE: matchCalcFullScore_ / matchCalcGeoAnchorScore_ were NOT moved here — they
//   were dead code (0 callers repo-wide, superseded by calculateWeightedScore per
//   the v6.0.030 comment on makeMatchDecision) and were deleted instead.
// ============================================================

/**
 * makeMatchDecision
 * [FIX v003] Rule 1: !hasGeo (เดิม Logic ผิด)
 * [FIX v003] Rule 3: ใช้ srcObj.province แทน placeResult.normResult.province
 * [FIX v003] Rule 5: Weight รวม = 1.0 (เดิม 1.2)
 * [FIX v003] Rule 7: !isPersonOk && !isPlaceOk (เดิม hasPerson ผิด)
 */
function makeMatchDecision(srcObj, personResult, placeResult, geoResult) {
  // [V6.0.030] Refactored — extracted rules to 10b_MatchDecision.gs
  //   Audit finding 1.2: was 267 lines (single point of fragility)
  //   Now: dispatcher that tries each rule in order, returns first non-null
  //   BACKWARD COMPATIBLE: same signature, same return shape, same decisions
  //   Verified by snapshot test (V6.0.028) — 0 differences expected

  const isGeoInMaster = geoResult.status === 'FOUND';
  const isPersonInMaster = personResult.status === 'FOUND';
  const isPlaceInMaster = placeResult.status === 'FOUND' || placeResult.status === 'BRANCH_MATCH';
  const geoProvince = isGeoInMaster ? getGeoProvince_(geoResult.geoId) : '';
  const hasGeoInSource = srcObj.hasGeo;

  // Try rules in order — first non-null wins
  // Rule 1: ไม่มีพิกัดใน Source Sheet
  let decision = evaluateRule1_NoGeoInSource_(srcObj);
  if (decision) return decision;

  // Rule 2: ชื่อคุณภาพต่ำ
  decision = evaluateRule2_LowQualityData_(personResult, placeResult);
  if (decision) return decision;

  // Rule 3: จังหวัดข้ามโซน
  decision = evaluateRule3_GeoProvinceConflict_(isGeoInMaster, geoProvince, srcObj.province);
  if (decision) return decision;

  // Rule 3.5: NEARBY_PENDING (tiered spatial fuzzy)
  decision = evaluateRule3_5_NearbyPending_(geoResult);
  if (decision) return decision;

  // Rule 4: พบครบทั้ง 3 อย่าง → AUTO_MATCH (Full)
  decision = evaluateRule4_FullMatch_(
    srcObj,
    personResult,
    placeResult,
    geoResult,
    isGeoInMaster,
    isPersonInMaster,
    isPlaceInMaster
  );
  if (decision) return decision;

  // Rule 5: geo + person → AUTO_MATCH (Geo Anchor) [V6.0.016]
  decision = evaluateRule5_GeoPersonAnchor_(
    srcObj,
    personResult,
    placeResult,
    geoResult,
    isGeoInMaster,
    isPersonInMaster
  );
  if (decision) return decision;

  // Rule 5b: geo + place only → REVIEW [V6.0.016]
  decision = evaluateRule5b_GeoPlaceOnlyNoName_(
    srcObj,
    personResult,
    placeResult,
    geoResult,
    isGeoInMaster,
    isPlaceInMaster,
    isPersonInMaster
  );
  if (decision) return decision;

  // Rule 6: Fuzzy Match / Needs Review
  decision = evaluateRule6_FuzzyMatch_(srcObj, personResult, placeResult);
  if (decision) return decision;

  // Rule 7: GPS จริง + ไม่มี geo ใน master → CREATE_NEW
  decision = evaluateRule7_NewGeoWithGPS_(hasGeoInSource, isGeoInMaster);
  if (decision) return decision;

  // Rule 8: GPS จริง (default CREATE_NEW)
  decision = evaluateRule8_NewGeoFromGPS_(hasGeoInSource);
  if (decision) return decision;

  // Default fallback
  return {
    action: 'REVIEW',
    reason: 'NEW_RECORD_PENDING',
    confidence: 0,
    priority: 3
  };
}

/**
 * calcDynamicWeights_ — [NEW v5.5.046 Dynamic Weighting 2.2]
 * ปรับน้ำหนัก geo/person/place ตามความสมบูรณ์ของข้อมูล
 *   - ที่อยู่ดิบสั้นมาก (< 10 ตัวอักษร = สัญญาณรบกวนสูง) → ลด weight place, เพิ่ม weight person
 *   - เบอร์โทรตรงเป๊ะ (personResult.confidence >= 95) → เพิ่ม weight person อีกเล็กน้อย
 * Backward compatible: ไม่ส่ง srcObj มา → คืน baseWeights เดิมทุกประการ
 * @param {{geo:number, person:number, place:number}} baseWeights
 * @param {Object} [srcObj] - source row object (optional — backward compatible)
 * @param {Object} [personResult] - resolvePerson result (optional)
 * @return {{geo:number, person:number, place:number}}
 * @private
 */
function calcDynamicWeights_(baseWeights, srcObj, personResult) {
  const geo = baseWeights.geo;
  let person = baseWeights.person;
  let place = baseWeights.place;
  if (!srcObj) return { geo, person, place };

  const SHIFT = 0.08;
  const rawAddrLen = String(srcObj.rawAddress || '').trim().length;
  const addressIsThin = rawAddrLen > 0 && rawAddrLen < 10;
  const personIsStrongPhoneMatch = !!(personResult && personResult.confidence >= 95);

  if (addressIsThin && place > SHIFT) {
    place -= SHIFT;
    person += SHIFT;
  } else if (personIsStrongPhoneMatch && place > SHIFT / 2) {
    const bump = SHIFT / 2;
    place -= bump;
    person += bump;
  }
  return { geo, person, place };
}

/**
 * calculateWeightedScore — [V6.0.015 P2.2] Single weighted score across geo/person/place
 *   Replaces the binary per-rule scoring formulas (`matchCalcFullScore_` /
 *   `matchCalcGeoAnchorScore_`) with a unified weighted approach. Both Rule 4
 *   (Full Match) and Rule 5 (Geo Anchor) use this function so that confidence
 *   is always computed with the same dynamic-weight logic, eliminating the
 *   inconsistency that previously existed between the two rules.
 *
 * [V6.0.016] Re-balanced weights — name [12] is now the primary decision maker.
 *   Rationale: ที่อยู่ ([18]+[24]) กับพิกัด [4] ล้วนบอกแค่ "ตรงไหน" ไม่บอก "ร้านไหน"
 *   เฉพาะชื่อ [12] เท่านั้นที่แยกร้านในห้าง/ปั๊มที่มีหลายร้านในพิกัดใกล้กันได้
 *   นอกจากนี้ [24] มาจากพิกัด [4] อยู่แล้ว ไม่ใช่ข้อมูลอิสระ — ถ้าให้ geo กับ place
 *   (ที่มาจาก [24]) น้ำหนักเต็ม ๆ พร้อมกัน จะเท่ากับนับสัญญาณเดียวซ้ำสองรอบ
 *
 * Weights (V6.0.016):
 *   - person : 0.45 (PRIMARY — เพิ่มจาก 0.25 — ตัวเดียวที่บอก "ร้านไหน")
 *   - geo    : 0.35 (ลดจาก 0.60 — ซ้ำกับ [24] ที่อยู่ใน place score)
 *   - place  : 0.20 (เพิ่มจาก 0.15 — ตอนนี้ใช้ better of [18]/[24])
 *
 * Dynamic adjustment via `calcDynamicWeights_`:
 *   - If raw address is thin (< 10 chars) → shift 0.08 from place → person
 *   - If person confidence is very high (>= 95, phone match) → shift 0.04 from place → person
 *
 * @param {Object} srcObj - source row (for dynamic weighting; pass null/undefined to skip)
 * @param {Object} personResult - resolvePerson result (must have .confidence)
 * @param {Object} placeResult - resolvePlace result (must have .confidence)
 * @param {Object} geoResult - resolveGeo result (must have .confidence)
 * @return {number} weighted confidence score (0-100, clamped)
 */
function calculateWeightedScore(srcObj, personResult, placeResult, geoResult) {
  const geoScore = (geoResult && geoResult.confidence) || 0;
  const personScore = (personResult && personResult.confidence) || 0;
  const placeScore = (placeResult && placeResult.confidence) || 0;

  // [V6.0.016] New base weights — name primary, geo reduced (overlaps with [24] in place)
  const w = calcDynamicWeights_({ geo: 0.35, person: 0.45, place: 0.2 }, srcObj, personResult);

  const score = Math.round(geoScore * w.geo + personScore * w.person + placeScore * w.place);
  return Math.min(100, Math.max(0, score));
}

function getGeoProvince_(geoId) {
  if (!geoId) return '';
  const allGeos = loadAllGeos_();
  const geo = allGeos.find((g) => g.geoId === geoId);
  return geo ? geo.province || '' : '';
}

function getCandidateResolvedCoords_(entityType, entityId) {
  if (!entityType || !entityId) return null;

  // Build cache once per execution
  if (!_CANDIDATE_COORDS_CACHE_) {
    _CANDIDATE_COORDS_CACHE_ = { PLACE: {}, PERSON: {} };
    try {
      if (typeof loadAllDestinations_ !== 'function') return null;
      const dests = loadAllDestinations_();
      for (let i = 0; i < dests.length; i++) {
        const d = dests[i];
        if (d.status !== APP_CONST.STATUS_ACTIVE) continue;
        if (d.lat === null || d.lng === null) continue;

        // Index by placeId
        if (d.placeId) {
          _CANDIDATE_COORDS_CACHE_.PLACE[d.placeId] = { lat: d.lat, lng: d.lng };
        }
        // Index by personId (first active destination wins)
        if (d.personId && !_CANDIDATE_COORDS_CACHE_.PERSON[d.personId]) {
          _CANDIDATE_COORDS_CACHE_.PERSON[d.personId] = { lat: d.lat, lng: d.lng };
        }
      }
    } catch (e) {
      // Non-fatal — return null
    }
  }

  const cache = _CANDIDATE_COORDS_CACHE_[entityType];
  if (!cache) return null;
  return cache[entityId] || null;
}
