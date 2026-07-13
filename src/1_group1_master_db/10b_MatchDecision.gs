/**
 * VERSION: 6.0.043
 * FILE: 10b_MatchDecision.gs
 * LMDS V6.0 — Match Decision Rules
 * ===================================================
 * PURPOSE:
 *   แยก match decision rules ออกจาก makeMatchDecision() (267 บรรทัด)
 *   เป็น pure functions แต่ละ rule — ลด complexity เพื่อ maintainability (audit 1.2)
 *   BACKWARD COMPATIBLE: makeMatchDecision() signature + return shape เหมือนเดิม 100%
 *
 * CHANGELOG:
 *   v6.0.037 (2026-07-13) — Header sync — no functional change
 *   v6.0.036 (2026-07-13) — SCG cookie security fix (fix readInputConfig_ caller)
 *   v6.0.035 (2026-07-12) — RE-APPLY branch number matching (lost in PR #93 rebase regression)
 *
 * DEPENDENCIES:
 *   REQUIRES: 01_Config, 14_Utils, 05_NormalizeService, 10_MatchEngine
 *   CALLED BY: 10_MatchEngine (makeMatchDecision dispatcher)
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
