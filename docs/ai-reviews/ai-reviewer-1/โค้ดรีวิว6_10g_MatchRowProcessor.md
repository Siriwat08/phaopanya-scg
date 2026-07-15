/**
 * VERSION: 6.0.046 (extracted from 10_MatchEngine.gs — no logic changes)
 * FILE: 10g_MatchRowProcessor.gs
 * LMDS V6.0 — Match Engine: Per-Row Decision Execution
 * ===================================================
 * PURPOSE:
 *   แยกออกมาจาก 10_MatchEngine.gs [Phase 2 Refactor, ต่อจาก Phase 1 → 10f]
 *   กลุ่มฟังก์ชัน "ตัดสินใจแล้ว → ทำจริง" ต่อ 1 Source Record: เรียก
 *   makeMatchDecision() (10b_MatchDecision.gs) แล้ว dispatch ไปยัง handler
 *   ที่เหมาะสม (AUTO_MATCH / CREATE_NEW / REVIEW)
 *   Extract แบบ verbatim 100% — ไม่เปลี่ยน logic
 *
 * DEPENDENCIES:
 *   REQUIRES:
 *     - 10b_MatchDecision.gs (makeMatchDecision — dispatcher หลัก)
 *     - 10f_MatchAliasEnrichment.gs (addEntityToEnrichmentContext_ — เรียกจาก
 *       handleCreateNew_ เมื่อสร้าง entity ใหม่)
 *     - 06_PersonService.gs, 07_PlaceService.gs (resolvePerson/resolvePlace ฯลฯ)
 *     - 21_AliasService.gs (createGlobalAlias ผ่าน handler)
 *     - 12_ReviewService.gs (enqueueReview — เรียกจาก handleReview_)
 *   CALLED BY:
 *     - runMatchEngineLoop_() → 10_MatchEngine.gs (เรียก processOneRow ต่อแถว)
 *     - 10d_MatchTestHarness.gs (เรียก breakTieAmongCandidates ตรงๆ สำหรับ test)
 *
 * ARCHITECTURE:
 *   Group 1 — Master data building (แยกจาก 10_MatchEngine.gs orchestration)
 * ===================================================
 */

// ============================================================
// SECTION 1: processOneRow + decision execution handlers
// ============================================================

/**
 * processOneRow — ประมวลผล 1 Source Record
 * [FIX v003] resolvePlace ส่ง rawPlaceName + province
 * [FIX P1 Static Audit] ส่ง rawAddress (ที่อยู่เต็ม) แทน province เพื่อให้
 *   tryMatchBranch → extractProvince_ สามารถ fallback หารหัสไปรษณีย์ได้
 *   เดิมส่งแค่ province (สตริงสั้น) ทำให้ extractProvince_ หา postcode ไม่เจอ
 */
function processOneRow(srcObj) {
  // [UPGRADE v5.5.047] ส่ง contextHint (soldToName) เพื่อ Contextual Disambiguation (2.1)
  //   ถ้าชื่อซ้ำ + คะแนนใกล้กัน → ใช้ SoldToName เป็น tie-breaker
  const personResult = resolvePerson(srcObj.rawPersonName, null, { soldToName: srcObj.soldToName });

  // [V6.0.014 REVERT V6.0.013] [18] (rawPlaceName) คือ primary place name อีกครั้ง
  //   เหตุผล: [24] (rawAddress = reverse geocode) จะถูกเก็บแยกใน M_PLACE คอลัมน์
  //   canonical_reverse_geocode / normalized_reverse_geocode (V6.0.014) สำหรับ matching ในอนาคต
  //   ส่วน canonical_name / normalized_name ยังคงเก็บ [18] เพื่อรักษา behavior เดิม
  //   ถ้า rawPlaceName ว่าง → fallback ไปใช้ rawAddress เพื่อไม่ให้ resolvePlace พัง
  //   [18] ยังเก็บใน srcObj.scgAddress สำหรับ FACT_DELIVERY (ดูข้อมูลดิบได้)
  const placeResult = resolvePlace(srcObj.rawPlaceName || srcObj.rawAddress, srcObj.rawAddress || '');

  const geoResult = resolveGeo(srcObj.rawLat, srcObj.rawLng);

  // [V6.0.002] Tie-breaker: if person needs review with multiple candidates, try tie-breaker
  //   using driver history + street distance as secondary signals. Only fires when
  //   best & second-best scores are within ±2 (handled inside breakTieAmongCandidates).
  //   Non-breaking: if no tiebreaker fires (no destId/latLng context), personResult
  //   is left unchanged and downstream makeMatchDecision proceeds as before.
  if (personResult.status === 'NEEDS_REVIEW' && personResult.secondBestPerson) {
    const candidates = [
      { personId: personResult.personId, score: personResult.confidence },
      { personId: personResult.secondBestPerson.personId, score: personResult.secondBestScore }
    ];
    const chosen = breakTieAmongCandidates(candidates, srcObj);
    if (chosen && chosen.tiebreaker) {
      personResult.personId = chosen.personId;
      personResult.confidence = chosen.score;
      personResult.status = chosen.score >= AI_CONFIG.THRESHOLD_AUTO ? 'FOUND' : 'NEEDS_REVIEW';
    }
  }

  const decision = makeMatchDecision(srcObj, personResult, placeResult, geoResult);
  const result = executeDecision(srcObj, decision, personResult, placeResult, geoResult);

  // [PERF-001] ส่ง statsToDefer กลับให้ runMatchEngine เก็บรวมใน Set
  return {
    action: decision.action,
    txId: result.txId,
    factData: result.factData,
    reviewData: result.reviewData,
    statsToDefer: result.statsToDefer || null // [PERF-001]
  };
}

/**
 * executeDecision — [REFACTOR-04] Dispatcher: เรียก handler ตาม action
 * REVIEW ไม่สร้าง FACT row — ป้องกัน null-FK garbage rows
 */
function executeDecision(srcObj, decision, personResult, placeResult, geoResult) {
  const personId = personResult ? personResult.personId : null;
  const placeId = placeResult ? placeResult.placeId : null;
  let geoId = geoResult ? geoResult.geoId : null;

  // [FIX v5.5.001] Only call getEnrichedGeoData() for AUTO_MATCH and CREATE_NEW
  // REVIEW rows don't need expensive geo enrichment
  let geoEnrich = null;
  const needsGeoEnrich = decision.action === 'AUTO_MATCH' || decision.action === 'CREATE_NEW';

  if (needsGeoEnrich) {
    geoEnrich = getEnrichedGeoData(srcObj.rawAddress, srcObj.rawPlaceName);

    // [FIX v5.5.001] Only create GeoPoint for AUTO_MATCH and CREATE_NEW, not REVIEW
    // REVIEW rows should not create GeoPoints — they need human review first
    if (!geoId && srcObj.hasGeo && geoResult && geoResult.status !== 'NEARBY_PENDING') {
      geoId = createGeoPoint(
        srcObj.rawLat,
        srcObj.rawLng,
        'driver',
        geoEnrich.fullAddress || srcObj.rawAddress,
        geoEnrich.province || srcObj.province,
        geoEnrich.district || srcObj.district,
        placeId
      );
      // [FIX CodeQL js/trivial-conditional V5.5.035] outer if บนบรรทัด 1080 ตรวจ geoResult แล้ว จึงไม่จำเป็นต้องเช็คซ้ำ
      geoResult.geoId = geoId;
    }
  }

  // ─── Dispatch to handler ───────────────────────────────────
  switch (decision.action) {
    case 'AUTO_MATCH':
      return handleAutoMatch_(srcObj, decision, personId, placeId, geoId);
    case 'CREATE_NEW':
      return handleCreateNew_(srcObj, decision, personResult, placeResult, geoId, geoEnrich);
    case 'REVIEW':
      return handleReview_(srcObj, decision, personResult, placeResult, geoResult);
    default:
      logError(
        'MatchEngine',
        `executeDecision: Unknown action: ${decision.action}`,
        new Error('UNKNOWN_ACTION:' + decision.action)
      );
      return { txId: null, factData: null, reviewData: null };
  }
}

/**
 * handleAutoMatch_ — [REFACTOR-04] AUTO_MATCH handler
 * [PERF-001] เปลี่ยนจากเรียก stats update ทันที → ส่ง ID กลับให้ caller เก็บไว้ batch
 * เหตุผล: เดิมเรียก updatePersonStats/PlaceStats/GeoStats/DestStats ทุกแถว
 *         แต่ละฟังก์ชันใช้ 2-3 API calls (getValues+setValues+cache invalidate)
 *         ทำให้ N แถว = N×4×2-3 = 8-12N API calls เฉพาะ stats
 *         แก้แล้ว: เก็บ ID ใน Set/Array → flush ทีเดียวใน flushBatches_()
 *         ใช้ Set เพื่อ dedup: ถ้า personId เดียวกันโดนหลายแถว → อัปเดตครั้งเดียว
 */
function handleAutoMatch_(srcObj, decision, personId, placeId, geoId) {
  // [PERF-001] Defer stats updates — collect IDs instead of calling immediately
  // Stats updates will be done in flushBatches_() via processOneRow() return values
  const statsToDefer = {
    personIds: [],
    placeIds: [],
    geoIds: [],
    destStats: []
  };

  if (personId) statsToDefer.personIds.push(personId);
  if (placeId) statsToDefer.placeIds.push(placeId);
  if (geoId) statsToDefer.geoIds.push(geoId);

  // [FIX Phase-B #13] Flag incomplete destination for Rule 5 (geo + person only — V6.0.016)
  //   [V6.0.016] Rule 5 ตอนนี้ AUTO_MATCH เฉพาะ geo+person (place อาจตกไป REVIEW)
  //   ดังนั้น partial ที่เข้าถึงตรงนี้คือ "มี person แต่ไม่มี place" เท่านั้น
  //   Rule 5 (geo+person, place missing) สร้าง destination ที่ placeId='' (by design)
  //   เดิม: ไม่มี flag บอกว่า incomplete → reviewer เห็น GEO_ANCHOR ธรรมดา ไม่รู้ว่าขาด place
  //   ตอนนี้: enrich reason/evidence ด้วย PARTIAL_MATCH_NO_PLACE
  //   ไม่เปลี่ยน logic การทำงาน — แค่เพิ่ม flag ใน MATCH_REASON column ของ FACT_DELIVERY เพื่อ audit
  let enrichedDecision = decision;
  const hasPerson = !!personId;
  const hasPlace = !!placeId;
  if (hasPerson !== hasPlace) {
    // XOR — only one of person/place present (Rule 5 partial — geo+person, no place)
    enrichedDecision = Object.assign({}, decision);
    const flagStr = hasPerson ? 'PARTIAL_MATCH_NO_PLACE' : 'PARTIAL_MATCH_NO_PERSON';
    enrichedDecision.reason = (decision.reason || '') + '|' + flagStr;
    enrichedDecision.evidence = (decision.evidence || '') + '|' + flagStr;
  }

  const destResult = resolveDestination(personId, placeId, geoId);
  let destId = null;
  if (destResult.status === 'FOUND' || destResult.status === 'PARTIAL_MATCH') {
    destId = destResult.destId;
    if (destId) statsToDefer.destStats.push({ destId: destId, deliveryDate: srcObj.deliveryDate });
  } else {
    destId = createDestination(personId, placeId, geoId, srcObj.rawLat, srcObj.rawLng, srcObj.deliveryDate);
  }

  const txRes = upsertFactDelivery(srcObj, personId, placeId, geoId, destId, enrichedDecision);
  return {
    txId: txRes ? txRes.txId : null,
    factData: txRes && txRes.isNew ? txRes.rowData : null,
    reviewData: null,
    statsToDefer: statsToDefer // [PERF-001] ส่งกลับให้ caller
  };
}

/**
 * handleCreateNew_ — [REFACTOR-04] CREATE_NEW handler
 * Create Person/Place/Geo/Dest → write FACT
 * [PERF-001] NOTE: CREATE_NEW intentionally does NOT return statsToDefer because
 *   createPerson()/createPlace()/createGeoPoint()/createDestination() already set
 *   initial usage_count = 1 and last_seen = now. Deferring stats would double-count.
 *   Only handleAutoMatch_ (which reuses existing entities) needs deferred stats.
 */
function handleCreateNew_(srcObj, decision, personResult, placeResult, geoId, geoEnrich) {
  let personId = personResult ? personResult.personId : null;
  let placeId = placeResult ? placeResult.placeId : null;
  let destId = null;

  if (!personId && personResult.normResult) {
    personId = createPerson(personResult.normResult);
    // [FIX CRIT-005] เพิ่ม Person ใหม่เข้า alias enrichment context — ป้องกัน stale cache
    if (personId) {
      const pUuid = typeof convertPersonIdToUuid === 'function' ? convertPersonIdToUuid(personId) : null;
      addEntityToEnrichmentContext_(
        'PERSON',
        personId,
        pUuid,
        personResult.canonical || '',
        personResult.normalized || ''
      );

      // [V6.0.015 P2.5] Immediately store raw name as alias for faster matching
      //   เดิม: alias ถูกสร้างที่ flush time โดย autoEnrichAliasesFromFactBatch_ เท่านั้น
      //         ทำให้ row ถัดไปใน batch เดียวกัน (ที่มี SCG raw name ซ้ำ) ยังคงต้องเข้า
      //         matching pipeline ใหม่ทั้งหมด → match rate ต่ำใน batch แรก
      //   ใหม่: เก็บ alias ทันทีหลัง createPerson → row ถัดไปใน batch เดียวกันจะ match
      //         ผ่าน M_ALIAS ได้ทันที (skip fuzzy matching)
      //   Non-fatal: try-catch เพื่อไม่ให้ alias failure ทำลาย CREATE_NEW flow
      //   Note: ใช้ srcObj.rawPersonName (SCG raw) ไม่ใช่ normResult.cleanName เพราะ
      //         alias ต้องเก็บ "ชื่อที่เขียนผิด/สกปรก" ตาม design ของ M_ALIAS
      if (typeof createGlobalAlias === 'function' && srcObj.rawPersonName) {
        try {
          const personUuid = typeof getPersonMasterUuid_ === 'function' ? getPersonMasterUuid_(personId) : pUuid;
          if (personUuid) {
            createGlobalAlias(personUuid, srcObj.rawPersonName, 'PERSON', 95, 'AUTO_ENRICH_FACT', '', '');
          }
        } catch (aliasErr) {
          // [V6.0.015 P2.5] Non-fatal — don't break CREATE_NEW if alias creation fails
          //   autoEnrichAliasesFromFactBatch_ จะเก็บ alias อีกครั้งที่ flush time อยู่แล้ว
          logWarn('MatchEngine', 'handleCreateNew_: createGlobalAlias failed (non-fatal) — ' + aliasErr.message);
        }
      }
    }
  }
  if (!placeId && placeResult.normResult) {
    const placeNorm = placeResult.normResult || {};
    // [V6.0.014 REVERT V6.0.013] ไม่ override placeNorm.fullAddress เป็น [24] อีกต่อไป
    //   เหตุผล: createPlace (V6.0.014) ใช้ normResult.cleanPlace เป็น canonical_name เสมอ
    //   ไม่ใช้ fullAddress อีก → ไม่จำเป็นต้อง set fullAddress ที่นี่
    //   [24] (rawAddress) จะถูกส่งผ่าน reverseGeocodeAddress parameter แยก ให้ createPlace
    //   เก็บใน canonical_reverse_geocode / normalized_reverse_geocode (cols 16/17) แทน
    placeId = createPlace(
      placeNorm,
      geoEnrich.province,
      geoEnrich.district,
      geoEnrich.subDistrict,
      geoEnrich.postcode,
      srcObj.rawAddress
    );
    // [FIX CRIT-005] เพิ่ม Place ใหม่เข้า alias enrichment context — ป้องกัน stale cache
    if (placeId) {
      const plUuid = typeof convertPlaceIdToUuid === 'function' ? convertPlaceIdToUuid(placeId) : null;
      addEntityToEnrichmentContext_('PLACE', placeId, plUuid, placeNorm.canonical || '', placeNorm.normalized || '');
    }
  }
  // geoId created before switch (v5.2.003)

  if (geoId && (personId || placeId)) {
    // [V6.0.012 P1.1] Dedup: resolve existing destination first before creating new
    //   เดิม: เรียก createDestination() ทันที → ถ้า (personId, placeId, geoId) ชุดเดิมมีอยู่แล้ว
    //         จะสร้าง duplicate destination row (ใช้เกิดจาก reprocess / race condition)
    //   ใหม่: เรียก resolveDestination() ก่อน ถ้าเจอ → reuse destId, ไม่สร้างใหม่
    //   Pattern เดียวกับ handleAutoMatch_ (line ~1478)
    if (typeof resolveDestination === 'function') {
      try {
        const existingDestResult = resolveDestination(personId, placeId, geoId);
        if (
          existingDestResult &&
          (existingDestResult.status === 'FOUND' || existingDestResult.status === 'PARTIAL_MATCH')
        ) {
          destId = existingDestResult.destId;
          logDebug('MatchEngine', 'handleCreateNew_: reused existing destination ' + destId);
        }
      } catch (destErr) {
        // Non-fatal — fallback to createDestination below
        logDebug('MatchEngine', 'handleCreateNew_: resolveDestination failed, will create new — ' + destErr.message);
      }
    }
    if (!destId) {
      destId = createDestination(personId, placeId, geoId, srcObj.rawLat, srcObj.rawLng, srcObj.deliveryDate);
    }
  }

  const txRes = upsertFactDelivery(srcObj, personId, placeId, geoId, destId, decision);
  return {
    txId: txRes ? txRes.txId : null,
    factData: txRes && txRes.isNew ? txRes.rowData : null,
    reviewData: null
  };
}

/**
 * handleReview_ — [REFACTOR-04] REVIEW handler
 * ❌ ไม่สร้าง FACT row — REVIEW ไม่มี personId/placeId/geoId/destId ครบ
 * REVIEW ถูกบันทึกใน Q_REVIEW แทน
 */
function handleReview_(srcObj, decision, personResult, placeResult, geoResult) {
  const qRes = enqueueReview(srcObj, decision, personResult, placeResult, geoResult);
  if (qRes && qRes.rowData) {
    // [FIX CRIT-006] ใช้ 'REVIEW' แทน 'SUCCESS' — แถวยังไม่ได้ประมวลผลจริง แค่อยู่ในคิวรอตรวจ
    updateSyncStatus_([srcObj], 'REVIEW');
  }
  return {
    txId: null,
    factData: null,
    reviewData: qRes ? qRes.rowData : null
  };
}

// ============================================================
// SECTION 2: Tie-breaking among multiple candidates
// ============================================================

/**
 * breakTieAmongCandidates — [V6.0.002] Resolve tie between candidates with similar scores
 *   When top candidates have score within ±2, use driver history + street distance as tie-breaker
 * @param {Array} candidates - array of { personId, placeId, geoId, destId, score, resolvedLat, resolvedLng }
 * @param {Object} srcObj - source row
 * @return {Object} chosen candidate (mutated with tiebreaker info)
 */
function breakTieAmongCandidates(candidates, srcObj) {
  if (!candidates || candidates.length <= 1) return candidates ? candidates[0] : null;

  // Filter to top candidates within ±2 score
  const topScore = candidates[0].score;
  const tied = candidates.filter((c) => topScore - c.score <= 2);
  if (tied.length === 1) return tied[0];

  // Tie-breaker 1: Driver history (same driver visited this destination before)
  if (srcObj.driverName) {
    const driverHistory = getDriverHistory_(srcObj.driverName);
    if (driverHistory.length > 0) {
      for (const c of tied) {
        if (c.destId && driverHistory.some((h) => h.destId === c.destId)) {
          c.score += 5;
          c.tiebreaker = 'driver_history';
        }
      }
    }
  }

  // Tie-breaker 2: Street distance (if scores still tied)
  const stillTied = tied.filter((c) => c.score === Math.max(...tied.map((t) => t.score)));
  if (stillTied.length > 1 && srcObj.rawLat && srcObj.rawLng) {
    for (const c of stillTied) {
      if (c.resolvedLat && c.resolvedLng) {
        const streetDist = getStreetDistance_(srcObj.rawLat, srcObj.rawLng, c.resolvedLat, c.resolvedLng);
        if (streetDist !== null) {
          c.streetDistM = streetDist;
        }
      }
    }
    const withDist = stillTied.filter((c) => c.streetDistM !== undefined);
    if (withDist.length > 1) {
      withDist.sort((a, b) => a.streetDistM - b.streetDistM);
      withDist[0].score += 3;
      withDist[0].tiebreaker = (withDist[0].tiebreaker || '') + '+street_dist';
    }
  }

  // Sort and return top
  tied.sort((a, b) => b.score - a.score);
  return tied[0];
}

/**
 * getDriverHistory_ — [V6.0.002] Query FACT_DELIVERY for driver's past destinations
 * @param {string} driverName
 * @return {Array} array of { destId, personId, deliveryDate }
 * @private
 */
function getDriverHistory_(driverName) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET.FACT_DELIVERY);
    if (!sheet || sheet.getLastRow() < 2) return [];

    const cols = Math.min(SCHEMA[SHEET.FACT_DELIVERY].length, sheet.getLastColumn());
    const data = sheet.getRange(2, 1, sheet.getLastRow() - 1, cols).getValues();
    const history = [];

    for (let i = 0; i < data.length; i++) {
      const rowDriver = String(data[i][FACT_IDX.DRIVER_NAME] || '').trim();
      if (rowDriver !== driverName) continue;
      const destId = String(data[i][FACT_IDX.DEST_ID] || '').trim();
      const personId = String(data[i][FACT_IDX.PERSON_ID] || '').trim();
      if (destId) {
        history.push({ destId: destId, personId: personId, deliveryDate: data[i][FACT_IDX.DELIVERY_DATE] });
      }
    }
    return history;
  } catch (e) {
    logError('MatchEngine', 'getDriverHistory_ failed: ' + e.message, e);
    return [];
  }
}

/**
 * getStreetDistance_ — [V6.0.002] Get street distance via Google Maps API
 *   Uses cache (6h TTL) to reduce API calls.
 *   NOTE: GOOGLEMAPS_DISTANCE returns a string like "15.2 km" — we parse it
 *   to meters; if parsing fails we fall back to Haversine (always available).
 * @param {number} lat1
 * @param {number} lng1
 * @param {number} lat2
 * @param {number} lng2
 * @return {number|null} distance in meters, or null if unavailable
 * @private
 */
function getStreetDistance_(lat1, lng1, lat2, lng2) {
  const cacheKey = 'street_dist_' + lat1 + '_' + lng1 + '_' + lat2 + '_' + lng2;
  const cache = CacheService.getScriptCache();
  const cached = cache.get(cacheKey);
  if (cached) return Number(cached);

  try {
    // Use existing GOOGLEMAPS_DISTANCE custom function from 15_GoogleMapsAPI.gs
    if (typeof GOOGLEMAPS_DISTANCE === 'function') {
      const dist = GOOGLEMAPS_DISTANCE(lat1 + ',' + lng1, lat2 + ',' + lng2, 'driving');
      // [V6.0.002] GOOGLEMAPS_DISTANCE returns a string like "15.2 km" or "850 m".
      //   Parse to meters so the cache + tie-breaker logic can use a numeric value.
      const meters = parseDistanceStringToMeters_(dist);
      if (meters !== null) {
        cache.put(cacheKey, String(meters), 6 * 60 * 60); // 6h TTL
        return meters;
      }
    }
  } catch (e) {
    logDebug('MatchEngine', 'getStreetDistance_ failed (fallback to Haversine): ' + e.message);
  }

  // Fallback: Haversine distance (less accurate but always available)
  const havDist = haversineDistanceM(lat1, lng1, lat2, lng2);
  return havDist;
}

/**
 * parseDistanceStringToMeters_ — [V6.0.002] Parse GOOGLEMAPS_DISTANCE output to meters
 *   Handles formats: "15.2 km", "850 m", "1,200 m", "0.5 km"
 * @param {string} distStr - distance string from GOOGLEMAPS_DISTANCE
 * @return {number|null} meters, or null if parsing fails
 * @private
 */
function parseDistanceStringToMeters_(distStr) {
  if (!distStr || typeof distStr !== 'string') return null;
  const s = distStr.trim().toLowerCase();
  // km match — e.g. "15.2 km"
  const kmMatch = s.match(/^([\d.]+)\s*km$/);
  if (kmMatch) {
    const val = Number(kmMatch[1]);
    if (!isNaN(val)) return Math.round(val * 1000);
  }
  // m match — e.g. "850 m" or "1,200 m"
  const mMatch = s.match(/^([\d,.]+)\s*m$/);
  if (mMatch) {
    const val = Number(mMatch[1].replace(/,/g, ''));
    if (!isNaN(val)) return Math.round(val);
  }
  return null;
}

