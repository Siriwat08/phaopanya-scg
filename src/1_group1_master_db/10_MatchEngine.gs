/**
 * VERSION: 6.0.038
 * FILE: 10_MatchEngine.gs
 * LMDS V6.0 — Core Match & Resolution Engine
 * ===================================================
 * PURPOSE:
 *   ประมวลผลข้อมูลต้นทาง → จับคู่ Person/Place/Geo → ตัดสินใจ → บันทึกผล
 *   เป็นหัวใจหลักของ Pipeline และเป็น Single Writer สำหรับ M_ALIAS
 *   ตั้งแต่ V6.0.030+ decision rules แยกไป 10b, test harness ไป 10d, resolve/persist ไป 10e
 *
 * CHANGELOG:
 *   v6.0.037 (2026-07-13) — Header sync — no functional change
 *   v6.0.036 (2026-07-13) — SCG cookie security fix (fix readInputConfig_ caller)
 *   v6.0.035 (2026-07-12) — RE-APPLY branch number matching (lost in PR #93 rebase regression)
 *
 * DEPENDENCIES:
 *   REQUIRES: 01_Config, 02_Schema, 03_SetupSheets, 05_NormalizeService, 14_Utils, 06_PersonService, 07_PlaceService, 08_GeoService, 09_DestinationService, 11_TransactionService, 12_ReviewService, 04_SourceRepository, 10b_MatchDecision, 10d_MatchTestHarness, 10e_MatchResolvePersist, 26_AuditTrailService
 *   CALLED BY: 00_App (runMatchEngine — Pipeline menu), 24_PipelineManager (runMatchEngine wrapper), 12_ReviewService (handleReview_ → resolveAndPersist_)
 *
 * ARCHITECTURE:
 *   Group 1 — Master data building (normalize, persons, places, geo, match engine, aliases)
 * ===================================================
 */

// ============================================================
// SECTION 1: runMatchEngine
// ============================================================

// [FIX CRIT-018] Module-level cache สำหรับ alias enrichment context
// ลดการอ่านชีตซ้ำซ้อนเมื่อ flushBatches_ เรียก autoEnrich หลายครั้งใน execution เดียวกัน
let _ALIAS_ENRICHMENT_CONTEXT = null;

/**
 * [FIX CRIT-005] เพิ่ม entity ใหม่เข้า alias enrichment context แบบ incremental
 * เรียกจาก handleCreateNew_ หลังสร้าง Person/Place สำเร็จ
 * ทำให้ entity ใหม่มี alias ทันทีใน batch flush รอบเดียวกัน
 * @param {string} entityType - 'PERSON' หรือ 'PLACE'
 * @param {string} entityId - personId หรือ placeId
 * @param {string} masterUuid - UUID v4
 * @param {string} canonical - Canonical name
 * @param {string} normalized - Normalized name
 */
function addEntityToEnrichmentContext_(entityType, entityId, masterUuid, canonical, normalized) {
  if (!_ALIAS_ENRICHMENT_CONTEXT) return;
  if (entityType === 'PERSON' && entityId) {
    _ALIAS_ENRICHMENT_CONTEXT.personMap[entityId] = {
      canonical: canonical,
      normalized: normalized,
      masterUuid: masterUuid
    };
  } else if (entityType === 'PLACE' && entityId) {
    _ALIAS_ENRICHMENT_CONTEXT.placeMap[entityId] = {
      canonical: canonical,
      normalized: normalized,
      masterUuid: masterUuid
    };
  }
}

function runMatchEngine() {
  // [REF-004] V5.5.019: Refactored into 4 section helpers for Separation of Concerns
  //   1. acquireMatchEngineLock_   — SECTION A: Lock + AuthZ
  //   2. prepareMatchEngineContext_ — SECTION B: Initialize stats + load source rows
  //   3. runMatchEngineLoop_       — SECTION C: Main loop with Time Guard + batch flush
  //   4. finalizeMatchEngine_      — SECTION D: Final flush + cleanup + report
  // Preserve Behavior 100% — same lock, same loop order, same flush triggers, same stats

  // [V6.0.020 FIX] Clear any stale STOP SIGNAL before starting — prevents
  //   pipeline from immediately stopping at row 0 if a previous Emergency Stop
  //   signal was left behind (e.g., from a crashed or manually aborted run).
  //   This is a common issue: user clicks Emergency Stop → pipeline stops →
  //   signal stays in PropertiesService → next run stops at row 0.
  //   Note: This fix existed in commit 3eb4fc8 (branch fix/v6.0.012-phase1-matching)
  //   but was never merged to main — re-applied here.
  //   The stop signal is still functional DURING the run — if user clicks
  //   Emergency Stop during a run, the running loop checks it every 10 rows.
  if (typeof clearPipelineStopSignal_ === 'function') {
    clearPipelineStopSignal_();
  } else {
    try {
      PropertiesService.getScriptProperties().deleteProperty('PIPELINE_STOP_REQUESTED');
    } catch (e) {
      // ignore — non-fatal
    }
  }

  const setup = acquireMatchEngineLock_();
  if (!setup) return;

  // [V6.0.004] Pre-flight check
  if (typeof runPipelinePreflight === 'function') {
    const preflight = runPipelinePreflight();
    if (!preflight.ready) {
      const msg = 'Pipeline preflight failed:\n' + preflight.issues.join('\n');
      logWarn('MatchEngine', msg);
      if (typeof sendPipelineAlert_ === 'function') {
        sendPipelineAlert_('Pipeline preflight failed:\n' + preflight.issues.join('\n'), 'WARN');
      }
      safeUiAlert_('⚠️ Pipeline ไม่พร้อมรัน', msg);
      // Release lock + cleanup before returning — preserve existing pattern
      if (setup.lock && setup.lock.hasLock()) setup.lock.releaseLock();
      _ALIAS_ENRICHMENT_CONTEXT = null;
      if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();
      return;
    }
  }

  const ctx = prepareMatchEngineContext_();
  if (ctx === null) {
    // Empty pendingRows path — release lock + cleanup + return
    if (setup.lock && setup.lock.hasLock()) setup.lock.releaseLock();
    _ALIAS_ENRICHMENT_CONTEXT = null;
    if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();
    return;
  }

  try {
    runMatchEngineLoop_(ctx, setup.startTime);
    finalizeMatchEngine_(ctx, setup.startTime, setup.lock);
  } catch (err) {
    logError('MatchEngine', `runMatchEngine ล้มเหลว: ${err.message}`, err);
    // [FIX CRIT-013] แจ้ง user ก่อน throw — ป้องกัน silent failure
    safeUiAlert_('❌ Match Engine ล้มเหลว:\n' + err.message + '\n\nกรุณาตรวจสอบ SYS_LOG');
    throw err;
  } finally {
    if (setup.lock && setup.lock.hasLock()) setup.lock.releaseLock();
    // [FIX CRIT-018] ล้าง alias enrichment context เมื่อ execution จบ
    _ALIAS_ENRICHMENT_CONTEXT = null;
    // [PERF-012] Flush log buffer ก่อน execution จบ — ป้องกัน log entries สูญหาย
    if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();
  }
}

/**
 * acquireMatchEngineLock_ — [REF-004] SECTION A: Lock acquisition
 *   รักษา behavior เดิม 100% — tryLock with APP_CONST.LOCK_TIMEOUT_MS, same error messages
 * @return {{lock: object, startTime: Date}|null} null if lock cannot be acquired
 * @private
 */
function acquireMatchEngineLock_() {
  const lock = LockService.getScriptLock();
  // [FIX CRIT-009] ใช้ tryLock แทน waitLock — ไม่รอคิว แจ้ง user ทันที่ถ้า lock ไม่ได้
  try {
    lock.tryLock(APP_CONST.LOCK_TIMEOUT_MS);
  } catch (e) {
    logWarn('MatchEngine', 'ไม่สามารถ Lock ได้ — อาจมีการรันซ้อน กรุณารันใหม่ภายหลัง');
    safeUiAlert_('⚠️ ไม่สามารถรัน Match Engine ได้ — มีการรันซ้อนอยู่\nกรุณารอให้การรันก่อนหน้าเสร็จก่อน แล้วลองใหม่');
    return null;
  }
  if (!lock.hasLock()) {
    logWarn('MatchEngine', 'ไม่สามารถ Lock ได้ — อาจมีการรันซ้อน กรุณารันใหม่ภายหลัง');
    safeUiAlert_('⚠️ ไม่สามารถรัน Match Engine ได้ — มีการรันซ้อนอยู่\nกรุณารอให้การรันก่อนหน้าเสร็จก่อน แล้วลองใหม่');
    return null;
  }
  return { lock: lock, startTime: new Date() };
}

/**
 * prepareMatchEngineContext_ — [REF-004] SECTION B: Initialize stats + load source rows
 *   รักษา behavior เดิม 100% — resetProcessingState_, loadSourceBatch_, logInfo messages
 * @param {Date} startTime
 * @return {Object|null} context object หรือ null ถ้าไม่มี pending rows
 * @private
 */
function prepareMatchEngineContext_(startTime) {
  logInfo('MatchEngine', 'เริ่ม Match Engine');

  // [FIX v5.2.007] ลบ Checkpoint Index — เริ่มจาก 0 เสมอ
  // เหตุผล: getAllSourceRows() กรอง SUCCESS ออกอยู่แล้ว ดังนั้น Array ที่ได้จะมีเฉพาะแถวที่ยังไม่ได้ทำ
  //   Checkpoint เดิมเก็บ "ตำแหน่ง" ใน Array แต่ Array หดเล็กลงทุกรอบ ทำให้ตำแหน่งชี้ผิด → ข้อมูลถูกข้ามไป (BUG)
  resetProcessingState_(); // [REF-018] renamed from clearCheckpoint_ — ล้าง stale processing state
  const startIndex = 0;
  const pendingRows = loadSourceBatch_(); // [REF-002] Abstraction layer

  if (pendingRows.length === 0) {
    logInfo('MatchEngine', 'ไม่มีแถวที่ต้องประมวลผล');
    removeAutoResume_(); // ลบ trigger ที่ค้างอยู่ด้วย
    return null;
  }

  logInfo('MatchEngine', `ประมวลผล ${pendingRows.length} แถว (เริ่มจาก index ${startIndex})`);

  return {
    pendingRows: pendingRows,
    startIndex: startIndex,
    processed: 0,
    autoMatched: 0,
    created: 0,
    queued: 0,
    errorCount: 0,
    factBatch: [],
    reviewBatch: [],
    successRows: [],
    failedRows: [],
    personIdsToStats: new Set(),
    placeIdsToStats: new Set(),
    geoIdsToStats: new Set(),
    destStatsQueue: []
  };
}

/**
 * runMatchEngineLoop_ — [REF-004] SECTION C: Main processing loop with Time Guard + batch flush
 *   รักษา behavior เดิม 100% — same iteration order, same Time Guard (ทุก iteration), same BATCH_SIZE modulo
 * @param {Object} ctx - context from prepareMatchEngineContext_
 * @param {Date} startTime
 * @private
 */
function runMatchEngineLoop_(ctx, startTime) {
  const timeLimit = AI_CONFIG.TIME_LIMIT_MS || 5 * 60 * 1000;

  // [V6.0.007] Emergency Stop Signal Check
  //   User can request stop via menu "🛑 หยุด Pipeline (Emergency Stop)".
  //   We check every STOP_CHECK_INTERVAL rows (10) to balance responsiveness
  //   with PropertiesService read latency (~5-10ms per call).
  //   On stop: flush current batch via finalizeMatchEngine_ + clear signal +
  //   set ctx.stoppedByUser = true so finalizeMatchEngine_ removes any
  //   existing auto-resume trigger (don't want it to fire after user stop).
  const STOP_CHECK_INTERVAL = 10;
  let lastStopCheck = -STOP_CHECK_INTERVAL; // force first check at i=0

  for (let i = ctx.startIndex; i < ctx.pendingRows.length; i++) {
    if (new Date() - startTime > timeLimit) {
      logWarn('MatchEngine', `Time Guard: หยุดที่แถว ${i}/${ctx.pendingRows.length} (ติดตั้ง Auto-Trigger)`);
      // [FIX v5.2.007] ไม่บันทึก checkpoint อีกต่อไป — SYNC_STATUS ทำหน้าที่แทน
      installAutoResume_('runMatchEngine');
      return;
    }

    // [V6.0.007] Stop Signal Check — user requested emergency stop
    if (i - lastStopCheck >= STOP_CHECK_INTERVAL) {
      lastStopCheck = i;
      if (isPipelineStopRequested_()) {
        ctx.stoppedByUser = true;
        logWarn(
          'MatchEngine',
          '🛑 STOP SIGNAL: หยุดที่แถว ' +
            i +
            '/' +
            ctx.pendingRows.length +
            ' (user requested via menu) — กำลัง flush batch และปิด gracefully...'
        );
        // Clear the stop signal so the next manual run starts clean
        clearPipelineStopSignal_();
        // Return — finalizeMatchEngine_ will flush the current batch
        // and remove auto-resume trigger (because ctx.stoppedByUser = true)
        return;
      }
    }

    const srcObj = ctx.pendingRows[i];
    try {
      const result = processOneRow(srcObj);
      ctx.processed++;

      if (result.action === 'AUTO_MATCH') ctx.autoMatched++;
      if (result.action === 'CREATE_NEW') ctx.created++;
      if (result.action === 'REVIEW') ctx.queued++;

      if (result.factData) ctx.factBatch.push(result.factData);
      if (result.reviewData) ctx.reviewBatch.push(result.reviewData);

      // [PERF-001] เก็บ stats IDs ไว้อัปเดตเป็น batch ใน flushBatches_
      if (result.statsToDefer) {
        result.statsToDefer.personIds.forEach(function (id) {
          ctx.personIdsToStats.add(id);
        });
        result.statsToDefer.placeIds.forEach(function (id) {
          ctx.placeIdsToStats.add(id);
        });
        result.statsToDefer.geoIds.forEach(function (id) {
          ctx.geoIdsToStats.add(id);
        });
        result.statsToDefer.destStats.forEach(function (item) {
          ctx.destStatsQueue.push(item);
        });
      }

      ctx.successRows.push(srcObj);
    } catch (rowErr) {
      ctx.errorCount++;
      ctx.failedRows.push(srcObj);
      logError(
        'MatchEngine',
        `แถว ${srcObj.sourceRow} (Invoice hash: ${generateMd5Hash(String(srcObj.invoiceNo || '')).substring(0, 8)}): ${rowErr.message}`,
        rowErr
      );
    }

    // Batch Write & Sync Status every BATCH_SIZE
    if (ctx.processed % AI_CONFIG.BATCH_SIZE === 0 && ctx.processed > 0) {
      flushBatches_(
        ctx.factBatch,
        ctx.reviewBatch,
        ctx.successRows,
        ctx.failedRows,
        ctx.personIdsToStats,
        ctx.placeIdsToStats,
        ctx.geoIdsToStats,
        ctx.destStatsQueue
      );
      ctx.factBatch = [];
      ctx.reviewBatch = [];
      ctx.successRows = [];
      ctx.failedRows = [];
      ctx.personIdsToStats = new Set();
      ctx.placeIdsToStats = new Set();
      ctx.geoIdsToStats = new Set();
      ctx.destStatsQueue = [];
    }
  }
}

/**
 * finalizeMatchEngine_ — [REF-004] SECTION D: Final flush + cleanup + report
 *   รักษา behavior เดิม 100% — same final flush, same removeAutoResume_ condition, same log format
 * @param {Object} ctx
 * @param {Date} startTime
 * @param {object} lock
 * @private
 */
function finalizeMatchEngine_(ctx, startTime, lock) {
  // Final Flush
  flushBatches_(
    ctx.factBatch,
    ctx.reviewBatch,
    ctx.successRows,
    ctx.failedRows,
    ctx.personIdsToStats,
    ctx.placeIdsToStats,
    ctx.geoIdsToStats,
    ctx.destStatsQueue
  );

  // [FIX v5.2.007] ถ้าประมวลผลครบทุกแถว → ลบ Auto-Trigger
  if (ctx.processed + ctx.errorCount >= ctx.pendingRows.length) {
    removeAutoResume_();
  }

  // [V6.0.007] Emergency Stop — remove auto-resume trigger so it doesn't fire
  //   after user explicitly stopped. Also clear any stop signal that might
  //   have been set after the loop's last check (defensive).
  if (ctx.stoppedByUser) {
    removeAutoResume_();
    clearPipelineStopSignal_();
    logInfo('MatchEngine', '🛑 Pipeline หยุดโดย user — ลบ Auto-Resume trigger + clear stop signal เรียบร้อย');
  }

  const elapsedSec = Math.round((new Date() - startTime) / 1000);
  logInfo(
    'MatchEngine',
    `เสร็จสิ้น — รัน:${ctx.processed} Match:${ctx.autoMatched} ` +
      `สร้างใหม่:${ctx.created} Review:${ctx.queued} Error:${ctx.errorCount} (${elapsedSec}s)`
  );

  // [V6.0.012 P1.6] Log run stats to PIPELINE_RUN_LOG sheet for before/after comparison
  //   Non-fatal: ถ้า logging ล้มเหลว ไม่กระทบ pipeline result
  logPipelineRun_(ctx, startTime);
}

/**
 * logPipelineRun_ — [V6.0.012 P1.6] Append run stats to PIPELINE_RUN_LOG sheet
 *   ใช้สำหรับ before/after comparison เมื่อปรับ matching algorithm
 *   Append-only: เพิ่ม row ใหม่เสมอ ไม่ update row เดิม
 *   Non-fatal: ถ้า sheet ไม่มีหรือ write ล้มเหลว จะ log warn แล้วข้ามไป
 * @param {Object} ctx - pipeline context (pendingRows, processed, autoMatched, created, queued, errorCount)
 * @param {Date} startTime - pipeline start time
 * @private
 */
function logPipelineRun_(ctx, startTime) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET.PIPELINE_RUN_LOG);
    if (!sheet) {
      logDebug('MatchEngine', 'logPipelineRun_: PIPELINE_RUN_LOG sheet not found — skipping');
      return;
    }
    const elapsedSec = Math.round((new Date() - startTime) / 1000);
    const matchRate = ctx.processed > 0 ? Math.round((ctx.autoMatched / ctx.processed) * 100) : 0;
    const row = [
      new Date().getTime(), // run_id (timestamp-based millis)
      new Date(), // run_at
      APP_VERSION, // app_version
      ctx.pendingRows.length, // total_rows
      ctx.processed, // processed
      ctx.autoMatched, // auto_matched
      ctx.created, // created_new
      ctx.queued, // queued_review
      ctx.errorCount, // errors
      matchRate, // match_rate (%)
      elapsedSec, // elapsed_sec
      '' // notes (empty for auto runs)
    ];
    sheet.appendRow(row);
    logInfo(
      'MatchEngine',
      'Pipeline run logged: match_rate=' +
        matchRate +
        '%, processed=' +
        ctx.processed +
        ', auto_matched=' +
        ctx.autoMatched +
        ', elapsed=' +
        elapsedSec +
        's'
    );
  } catch (e) {
    logWarn('MatchEngine', 'logPipelineRun_ failed (non-fatal): ' + e.message);
  }
}

/**
 * [NEW v5.2.001] flushBatches_ — Internal helper for transaction writing
 * [PERF-001] เพิ่ม batch stats update parameters เพื่อลด API calls จาก O(N) เหลือ O(1) per entity type
 * [REF-002] Delegates fact+review persistence to persistResult_()
 * [FIX Phase-B #11] เพิ่มการเรียก flushGeoCacheIfDirty_() เพื่อ flush deferred geo cache invalidation
 *   ที่สะสมไว้จาก createGeoPoint ในระหว่าง batch — ลด API calls จาก N (N = createGeoPoint count)
 *   เหลือ 1 ต่อ batch
 */
function flushBatches_(
  factBatch,
  reviewBatch,
  successRows,
  failedRows,
  personIdsToStats,
  placeIdsToStats,
  geoIdsToStats,
  destStatsQueue
) {
  // [REF-002] Persist fact + review data via abstraction layer
  persistResult_(factBatch, reviewBatch);

  // [PERF-001] Batch stats updates — อ่านทั้ง column 1 ครั้ง แก้ใน RAM ทั้งหมด เขียนทีเดียว
  // ลดจาก O(N × 4 entity types × 2-3 API calls) → O(4 entity types × 2 API calls) = ~8 calls
  if (personIdsToStats && personIdsToStats.size > 0) {
    batchUpdatePersonStats_(personIdsToStats);
  }
  if (placeIdsToStats && placeIdsToStats.size > 0) {
    batchUpdatePlaceStats_(placeIdsToStats);
  }
  if (geoIdsToStats && geoIdsToStats.size > 0) {
    batchUpdateGeoStats_(geoIdsToStats);
  }
  if (destStatsQueue && destStatsQueue.length > 0) {
    batchUpdateDestinationStats_(destStatsQueue);
  }

  if (successRows.length > 0) {
    updateSyncStatus_(successRows, 'SUCCESS');
  }

  if (failedRows.length > 0) {
    updateSyncStatus_(failedRows, 'ERROR');
  }

  // [FIX Phase-B #11] Flush deferred geo cache invalidation
  //   createGeoPoint ในระหว่าง batch จะ set _GEO_CACHE_DIRTY = true แทนการ invalidate ทันที
  //   ตอนนี้ batch เสร็จแล้ว → flush ครั้งเดียวเพื่อให้ batch ถัดไปเห็นข้อมูลใหม่
  //   ใช้ typeof guard เพื่อป้องกัน error ถ้า 08_GeoService.gs ยังไม่ได้ load
  if (typeof flushGeoCacheIfDirty_ === 'function') {
    flushGeoCacheIfDirty_();
  }
}

/**
 * autoEnrichAliasesFromFactBatch_ — [REWRITE v5.4.001] Single Writer Pattern
 * ============================================================
 * 🟩 จุดเขียนเดียวสำหรับ M_ALIAS — ทุก alias เกิดที่นี่เท่านั้น
 * ============================================================
 * ทำงานอัตโนมัติเมื่อมี Fact ใหม่ → สร้าง alias ใน:
 *   1. M_ALIAS (Global) — PERSON canonical(100) + variant(95), PLACE canonical(100) + variant(90)
 *   2. M_PERSON_ALIAS  — variant name (ถ้า ≠ canonical)
 *   3. M_PLACE_ALIAS   — variant address (ถ้า ≠ canonical)
 *
 * ❌ ไม่เรียก createGlobalAlias() / syncAliasToEntityTable_()
 * ❌ ไม่เรียก createPersonAlias() / createPlaceAlias()
 * ✅ เขียน Batch ตรงทั้ง 3 ชีตเอง — เร็ว + ไม่มี circular dependency
 * ✅ รวม Canonical Name เข้า M_ALIAS ด้วย (เดิมข้าม → ทำให้ค้นไม่เจอ)
 */
function autoEnrichAliasesFromFactBatch_(factBatch) {
  if (!factBatch || factBatch.length === 0) return;

  try {
    // 1. เตรียมข้อมูล (Extract Data Loading)
    const context = prepareAliasEnrichmentData_();

    // 2. ประมวลผลหา Alias ใหม่ (Extract Processing Logic)
    const results = processFactRowsForAliases_(factBatch, context);

    // 3. บันทึกผลลงฐานข้อมูล (Extract Writing Logic)
    commitAliasChanges_(results, context);

    // 4. Log
    const totalGlobal = results.globalAliasRows.length;
    const totalPerson = results.personAliasRows.length;
    const totalPlace = results.placeAliasRows.length;

    if (totalGlobal > 0 || totalPerson > 0 || totalPlace > 0) {
      logInfo(
        'MatchEngine',
        'Auto-Enrich (Single Writer v5.4.001): ' +
          'M_ALIAS=' +
          totalGlobal +
          ' M_PERSON_ALIAS=' +
          totalPerson +
          ' M_PLACE_ALIAS=' +
          totalPlace
      );
    }
  } catch (err) {
    logError('autoEnrichAliasesFromFactBatch_', err.message, err);
    throw err;
  }
}

/**
 * [Helper 1] โหลดและเตรียม Map ข้อมูลจาก Sheets
 * @returns {Object} context object พร้อม entity maps และ alias sets
 */
function prepareAliasEnrichmentData_() {
  // [FIX CRIT-018] ใช้ cached context ถ้ามีอยู่แล้ว — ลดการอ่านชีตซ้ำซ้อน
  if (_ALIAS_ENRICHMENT_CONTEXT) return _ALIAS_ENRICHMENT_CONTEXT;

  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // Person map: personId → { canonical, normalized, masterUuid }
  const allPersons = loadAllPersons_();
  const personMap = {};
  allPersons.forEach(function (p) {
    if (p.personId && p.masterUuid) {
      personMap[p.personId] = {
        canonical: p.canonical,
        normalized: p.normalized,
        masterUuid: p.masterUuid
      };
    }
  });

  // Place map: placeId → { canonical, normalized, masterUuid }
  const allPlaces = loadAllPlaces_();
  const placeMap = {};
  allPlaces.forEach(function (p) {
    if (p.placeId && p.masterUuid) {
      placeMap[p.placeId] = {
        canonical: p.canonical,
        normalized: p.normalized,
        masterUuid: p.masterUuid
      };
    }
  });

  // === 2. โหลด Alias ที่มีอยู่แล้ว เพื่อ Dedup ===
  const dedupSets = matchBuildDedupSets_();
  const existingPersonAliasSet = dedupSets.existingPersonAliasSet;
  const existingPlaceAliasSet = dedupSets.existingPlaceAliasSet;
  const existingGlobalAliasSet = dedupSets.existingGlobalAliasSet;
  const mAliasSheet = ss.getSheetByName(SHEET.M_ALIAS);

  const contextObj = {
    ss: ss,
    personMap: personMap,
    placeMap: placeMap,
    existingPersonAliasSet: existingPersonAliasSet,
    existingPlaceAliasSet: existingPlaceAliasSet,
    existingGlobalAliasSet: existingGlobalAliasSet,
    mAliasSheet: mAliasSheet
  };

  // [FIX CRIT-018] Cache the context for reuse within same execution
  _ALIAS_ENRICHMENT_CONTEXT = contextObj;

  return contextObj;
}

/**
 * matchBuildDedupSets_ — [F-11] สร้าง Dedup Sets สำหรับ alias enrichment
 * แยกออกจาก prepareAliasEnrichmentData_() เพื่อ SRP
 * @returns {Object} { existingPersonAliasSet, existingPlaceAliasSet, existingGlobalAliasSet }
 */
function matchBuildDedupSets_() {
  // M_PERSON_ALIAS dedup: "personId::normalized"
  const existingPersonAliasSet = new Set();
  const existingPersonAliasData = loadAllAliases_();
  existingPersonAliasData.forEach(function (r) {
    if (!r[PERSON_ALIAS_IDX.ACTIVE_FLAG]) return;
    const pId = String(r[PERSON_ALIAS_IDX.PERSON_ID] || '').trim();
    const aNorm = normalizeForCompare(r[PERSON_ALIAS_IDX.ALIAS_NAME]);
    if (pId && aNorm) existingPersonAliasSet.add(pId + '::' + aNorm);
  });

  // M_PLACE_ALIAS dedup: "placeId::normalized"
  const existingPlaceAliasSet = new Set();
  const existingPlaceAliasData = loadAllPlaceAliases_();
  existingPlaceAliasData.forEach(function (r) {
    if (!r[PLACE_ALIAS_IDX.ACTIVE_FLAG]) return;
    const plId = String(r[PLACE_ALIAS_IDX.PLACE_ID] || '').trim();
    const aNorm = normalizeForCompare(r[PLACE_ALIAS_IDX.ALIAS_NAME]);
    if (plId && aNorm) existingPlaceAliasSet.add(plId + '::' + aNorm);
  });

  // M_ALIAS dedup: "ENTITY_TYPE::masterUuid::normalized"
  // [PERF-008] ใช้ buildGlobalAliasDedupSet_() แทนการอ่าน Sheet ตรง — ใช้ cache ที่มีอยู่แล้ว
  const existingGlobalAliasSet = buildGlobalAliasDedupSet_();

  return {
    existingPersonAliasSet: existingPersonAliasSet,
    existingPlaceAliasSet: existingPlaceAliasSet,
    existingGlobalAliasSet: existingGlobalAliasSet
  };
}

/**
 * [Helper 2] วนลูปตรวจสอบ Fact Rows และสร้าง Row ใหม่
 * @param {Array} factBatch - แถวข้อมูลจาก M_FACT
 * @param {Object} context - ข้อมูลที่เตรียมจาก prepareAliasEnrichmentData_()
 * @returns {Object} results object พร้อม rows ใหม่ทั้ง 3 ประเภท
 */
function processFactRowsForAliases_(factBatch, context) {
  const personMap = context.personMap;
  const placeMap = context.placeMap;

  const newGlobalAliasRows = []; // M_ALIAS
  const newPersonAliasRows = []; // M_PERSON_ALIAS
  const newPlaceAliasRows = []; // M_PLACE_ALIAS
  const now = new Date();

  factBatch.forEach(function (r) {
    const pId = String(r[FACT_IDX.PERSON_ID] || '').trim();
    const plId = String(r[FACT_IDX.PLACE_ID] || '').trim();
    const pInfo = pId ? personMap[pId] : null;
    const plInfo = plId ? placeMap[plId] : null;

    // ─── PERSON: Canonical + Variant ───
    if (pInfo) {
      matchEnrichPersonAliases_(r, pInfo, context, newGlobalAliasRows, newPersonAliasRows, now);
    }

    // ─── PLACE: Canonical + Variant ───
    if (plInfo) {
      matchEnrichPlaceAliases_(r, plInfo, context, newGlobalAliasRows, newPlaceAliasRows, now);
    }

    // [ADD v5.5.014] ─── DRIVER VERIFIED: ชื่อจริง/ที่อยู่จริง → M_ALIAS ───
    // ถ้ามี "ชื่อจริง" (col 32) และ Person match ได้ → สร้าง alias "ชื่อจริง" → master_uuid
    // ถ้ามี "ที่อยู่จริง" (col 33) และ Place match ได้ → สร้าง alias "ที่อยู่จริง" → master_uuid
    const driverVerifiedName = String(r[FACT_IDX.DRIVER_VERIFIED_NAME] || '').trim();
    const driverVerifiedAddr = String(r[FACT_IDX.DRIVER_VERIFIED_ADDR] || '').trim();

    if (driverVerifiedName && pInfo) {
      // สร้าง alias สำหรับ "ชื่อจริง" → Person master_uuid
      matchEnrichEntityAliases_(
        'PERSON',
        pId,
        pInfo.masterUuid,
        pInfo.canonical,
        pInfo.normalized,
        driverVerifiedName,
        100, // confidence=100 เพราะคนขับยืนยันเอง
        {
          existingGlobalAliasSet: context.existingGlobalAliasSet,
          entityAliasSet: context.existingPersonAliasSet,
          source: 'DRIVER_VERIFIED'
        },
        newGlobalAliasRows,
        newPersonAliasRows,
        now
      );
    }

    if (driverVerifiedAddr && plInfo) {
      // สร้าง alias สำหรับ "ที่อยู่จริง" → Place master_uuid
      matchEnrichEntityAliases_(
        'PLACE',
        plId,
        plInfo.masterUuid,
        plInfo.canonical,
        plInfo.normalized,
        driverVerifiedAddr,
        100, // confidence=100 เพราะคนขับยืนยันเอง
        {
          existingGlobalAliasSet: context.existingGlobalAliasSet,
          entityAliasSet: context.existingPlaceAliasSet,
          source: 'DRIVER_VERIFIED'
        },
        newGlobalAliasRows,
        newPlaceAliasRows,
        now
      );
    }
  });

  return {
    globalAliasRows: newGlobalAliasRows,
    personAliasRows: newPersonAliasRows,
    placeAliasRows: newPlaceAliasRows
  };
}

/**
 * matchEnrichEntityAliases_ — [REF-015] Generic alias enricher for both Person and Place
 * Replaces duplicate logic in matchEnrichPersonAliases_ and matchEnrichPlaceAliases_.
 * @param {string} entityType - 'PERSON' or 'PLACE'
 * @param {string} entityId - person_id or place_id
 * @param {string} masterUuid - master UUID for the entity
 * @param {string} canonical - Canonical name (clean version)
 * @param {string} canonicalNorm - Normalized canonical name
 * @param {string} rawVariant - Raw variant name/address from source
 * @param {number} variantConfidence - Confidence score for variant (95 for PERSON, 90 for PLACE)
 * @param {Object} context - { existingGlobalAliasSet, entityAliasSet, source }
 * @param {Array} globalRows - M_ALIAS accumulator
 * @param {Array} entityRows - M_PERSON_ALIAS or M_PLACE_ALIAS accumulator
 * @param {Date} now - timestamp
 */
function matchEnrichEntityAliases_(
  entityType,
  entityId,
  masterUuid,
  canonical,
  canonicalNorm,
  rawVariant,
  variantConfidence,
  context,
  globalRows,
  entityRows,
  now
) {
  const entityAliasSet = context.entityAliasSet;

  // 3a/3c. Canonical Name → M_ALIAS (confidence 100)
  if (canonicalNorm && canonicalNorm.length >= 2) {
    const canonKey = entityType + '::' + masterUuid + '::' + canonicalNorm;
    if (!context.existingGlobalAliasSet.has(canonKey)) {
      context.existingGlobalAliasSet.add(canonKey);
      // [FIX V6.0.007] Push 11 columns to match SCHEMA.M_ALIAS (V6.0.003 added 3 cols)
      //   0-7: alias_id, master_uuid, variant_name, entity_type, confidence, source, created_at, active_flag
      //   8-10: verified_by, review_id, verified_at (empty for AUTO_ENRICH — not human-verified)
      //   Previous bug: pushed only 8 cols → Sheets API threw
      //   "จำนวนคอลัมน์ในข้อมูลไม่ตรงกับจำนวนคอลัมน์ในช่วง ข้อมูลมี 8 คอลัมน์ แต่ช่วงดังกล่าวมี 11 คอลัมน์"
      globalRows.push([
        generateShortId('A'), // [0] alias_id
        masterUuid, // [1] master_uuid
        canonical, // [2] variant_name
        entityType, // [3] entity_type
        100, // [4] confidence (canonical = 100)
        context.source || 'AUTO_ENRICH_FACT', // [5] source
        now, // [6] created_at
        true, // [7] active_flag
        '', // [8] verified_by (empty — AUTO_ENRICH is not human-verified)
        '', // [9] review_id (empty — not from Q_REVIEW)
        '' // [10] verified_at (empty — not verified)
      ]);
    }
  }

  // 3b/3d. Variant → M_ALIAS + Entity Alias
  if (rawVariant && rawVariant.length >= 2) {
    const rawNorm = normalizeForCompare(rawVariant);
    if (rawNorm && rawNorm.length >= 2) {
      // M_ALIAS variant
      const variantKey = entityType + '::' + masterUuid + '::' + rawNorm;
      if (!context.existingGlobalAliasSet.has(variantKey)) {
        context.existingGlobalAliasSet.add(variantKey);
        // [FIX V6.0.007] Push 11 columns to match SCHEMA.M_ALIAS (V6.0.003 added 3 cols)
        //   Same fix as canonical push above — must include verified_by/review_id/verified_at
        globalRows.push([
          generateShortId('A'), // [0] alias_id
          masterUuid, // [1] master_uuid
          rawVariant, // [2] variant_name
          entityType, // [3] entity_type
          variantConfidence, // [4] confidence (95 for PERSON, 90 for PLACE)
          context.source || 'AUTO_ENRICH_FACT', // [5] source
          now, // [6] created_at
          true, // [7] active_flag
          '', // [8] verified_by (empty — AUTO_ENRICH is not human-verified)
          '', // [9] review_id (empty — not from Q_REVIEW)
          '' // [10] verified_at (empty — not verified)
        ]);
      }

      // Entity-specific alias (เฉพาะ variant ≠ canonical)
      if (rawNorm !== canonicalNorm) {
        const eaKey = entityId + '::' + rawNorm;
        if (!entityAliasSet.has(eaKey)) {
          entityAliasSet.add(eaKey);
          const entityPrefix = entityType === 'PERSON' ? 'PA' : 'PLA';
          entityRows.push([generateShortId(entityPrefix), entityId, rawVariant, variantConfidence, now, true]);
        }
      }
    }
  }
}

/**
 * matchEnrichPersonAliases_ — [REF-015] Thin wrapper → matchEnrichEntityAliases_
 * Preserves original signature for backward compatibility.
 * @param {Array} factRow - แถวข้อมูลจาก M_FACT
 * @param {Object} pInfo - { canonical, normalized, masterUuid } จาก personMap
 * @param {Object} context - dedup sets + maps
 * @param {Array} globalRows - shared M_ALIAS accumulator (mutated in-place)
 * @param {Array} personRows - shared M_PERSON_ALIAS accumulator (mutated in-place)
 * @param {Date} now - timestamp
 */
function matchEnrichPersonAliases_(factRow, pInfo, context, globalRows, personRows, now) {
  const pId = String(factRow[FACT_IDX.PERSON_ID] || '').trim();
  const rawPersonName = String(factRow[FACT_IDX.SHIP_TO_NAME] || '').trim();
  matchEnrichEntityAliases_(
    'PERSON',
    pId,
    pInfo.masterUuid,
    pInfo.canonical,
    pInfo.normalized,
    rawPersonName,
    95,
    {
      existingGlobalAliasSet: context.existingGlobalAliasSet,
      entityAliasSet: context.existingPersonAliasSet,
      source: 'AUTO_ENRICH_FACT'
    },
    globalRows,
    personRows,
    now
  );
}

/**
 * matchEnrichPlaceAliases_ — [REF-015] Thin wrapper → matchEnrichEntityAliases_
 * Preserves original signature for backward compatibility.
 * @param {Array} factRow - แถวข้อมูลจาก M_FACT
 * @param {Object} plInfo - { canonical, normalized, masterUuid } จาก placeMap
 * @param {Object} context - dedup sets + maps
 * @param {Array} globalRows - shared M_ALIAS accumulator (mutated in-place)
 * @param {Array} placeRows - shared M_PLACE_ALIAS accumulator (mutated in-place)
 * @param {Date} now - timestamp
 */
function matchEnrichPlaceAliases_(factRow, plInfo, context, globalRows, placeRows, now) {
  const plId = String(factRow[FACT_IDX.PLACE_ID] || '').trim();
  const rawPlaceAddr = String(factRow[FACT_IDX.SHIP_TO_ADDR] || '').trim();
  matchEnrichEntityAliases_(
    'PLACE',
    plId,
    plInfo.masterUuid,
    plInfo.canonical,
    plInfo.normalized,
    rawPlaceAddr,
    90,
    {
      existingGlobalAliasSet: context.existingGlobalAliasSet,
      entityAliasSet: context.existingPlaceAliasSet,
      source: 'AUTO_ENRICH_FACT'
    },
    globalRows,
    placeRows,
    now
  );
}

/**
 * [Helper 3] บันทึกข้อมูลลง Sheet ทั้ง 3 แบบ Batch
 * [F-12] Delegates to matchCommit* helpers for SRP
 * @param {Object} results - ผลลัพธ์จาก processFactRowsForAliases_()
 * @param {Object} context - Context ที่เตรียมไว้
 */
function commitAliasChanges_(results, context) {
  matchCommitGlobalAlias_(context.mAliasSheet, results.globalAliasRows);
  matchCommitPersonAlias_(context.ss, results.personAliasRows, context);
  matchCommitPlaceAlias_(context.ss, results.placeAliasRows, context);

  // [FIX Phase-B #16] Cleanup stale canonical aliases
  //   หลังเขียน canonical alias ใหม่ → deactivate canonical alias เก่าที่ variant_name ≠ canonical ปัจจุบัน
  //   ป้องกัน stale canonical alias หลงเหลือใน M_ALIAS หลัง user แก้ canonical_name ใน M_PERSON/M_PLACE
  cleanupStaleCanonicalAliases_(results.globalAliasRows, context);
}

/**
 * cleanupStaleCanonicalAliases_ — [FIX Phase-B #16] Deactivate stale canonical aliases
 *   ปัญหา: autoEnrichAliasesFromFactBatch_ สร้าง canonical alias ทุก batch — ถ้า user แก้ canonical_name manual
 *          → alias เก่ายัง active อยู่ → ค้นเจอ alias เก่าที่ variant_name ≠ canonical ปัจจุบัน → match ผิด
 *   วิธีแก้: หลังเขียน canonical alias ใหม่ → ค้นหา alias เก่าที่ canonical ≠ ปัจจุบัน → set active_flag=false
 *   Target criteria (only these are deactivated):
 *     - Same masterUuid + entityType
 *     - confidence == 100 (canonical)
 *     - active_flag == true
 *     - source starts with 'AUTO_ENRICH' (preserve DRIVER_VERIFIED / MANUAL / MIGRATION aliases)
 *     - normalized variant_name ≠ current canonical_norm
 *   Performance: 1 read of M_ALIAS + 1 batched getRangeList().setValue(false) per batch
 * @param {Array<Array>} newGlobalAliasRows - rows being written this batch (from results.globalAliasRows)
 * @param {Object} context - context with mAliasSheet
 */
function cleanupStaleCanonicalAliases_(newGlobalAliasRows, context) {
  try {
    if (!newGlobalAliasRows || newGlobalAliasRows.length === 0) return;
    if (typeof loadGlobalAliasAll_ !== 'function') return; // guard — AliasService must be loaded

    // 1. Collect canonical aliases being written this batch
    //    globalRow format: [aliasId, masterUuid, variantName, entityType, confidence, source, createdAt, activeFlag]
    // [FIX V5.5.048] ใช้ ALIAS_IDX.* (จาก 01_Config.gs) แทน magic numbers row[1]/row[2]/row[3]/row[4] — Law 1 (No Hardcoded Index)
    const canonicalMap = {}; // key: "entityType::masterUuid" → canonicalNorm (current canonical)
    newGlobalAliasRows.forEach(function (row) {
      const confidence = Number(row[ALIAS_IDX.CONFIDENCE] || 0);
      if (confidence !== 100) return; // only canonical aliases
      const masterUuid = String(row[ALIAS_IDX.MASTER_UUID] || '').trim();
      const entityType = String(row[ALIAS_IDX.ENTITY_TYPE] || '').trim();
      const variantName = String(row[ALIAS_IDX.VARIANT_NAME] || '').trim();
      const canonicalNorm = normalizeForCompare(variantName);
      if (!masterUuid || !entityType || !canonicalNorm) return;
      const key = entityType + '::' + masterUuid;
      // Keep the last one if multiple (shouldn't happen but safe)
      canonicalMap[key] = canonicalNorm;
    });

    const keysToCheck = Object.keys(canonicalMap);
    if (keysToCheck.length === 0) return;

    // 2. Load all M_ALIAS rows (including inactive) to find stale canonical aliases
    const allAliases = loadGlobalAliasAll_();
    if (allAliases.length === 0) return;

    // 3. Find rows to deactivate
    const rowsToDeactivate = [];
    allAliases.forEach(function (alias) {
      if (!alias.activeFlag) return; // already inactive — skip
      if (Number(alias.confidence) !== 100) return; // only canonical aliases
      const source = String(alias.source || '');
      // Only deactivate AUTO_ENRICH aliases — preserve DRIVER_VERIFIED / MANUAL / MIGRATION
      if (source.indexOf('AUTO_ENRICH') !== 0) return;

      const key = alias.entityType + '::' + alias.masterUuid;
      const currentCanonicalNorm = canonicalMap[key];
      if (!currentCanonicalNorm) return; // not in this batch — skip

      const existingNorm = normalizeForCompare(alias.variantName);
      if (existingNorm === currentCanonicalNorm) return; // matches current canonical — keep

      // Stale canonical — mark for deactivation
      rowsToDeactivate.push(alias._rowNum);
    });

    if (rowsToDeactivate.length === 0) return;

    // 4. Batch deactivate: set active_flag = false สำหรับ stale rows
    const mAliasSheet = context.mAliasSheet;
    if (!mAliasSheet) return;

    const activeFlagCol = ALIAS_IDX.ACTIVE_FLAG + 1; // 1-indexed column number
    const a1Notations = rowsToDeactivate.map(function (rn) {
      // Convert column number to letter (inline — avoid cross-module dependency)
      let col = activeFlagCol;
      let letter = '';
      let temp;
      while (col > 0) {
        temp = (col - 1) % 26;
        letter = String.fromCharCode(temp + 65) + letter;
        col = (col - temp - 1) / 26;
      }
      return letter + rn;
    });

    mAliasSheet.getRangeList(a1Notations).setValue(false);

    // 5. Invalidate cache so next read sees deactivated rows
    if (typeof invalidateChunkedCache_ === 'function') {
      invalidateChunkedCache_(CACHE_KEY.GLOBAL_ALIAS_ALL);
      invalidateChunkedCache_(CACHE_KEY.GLOBAL_ALIAS_REVERSE);
    } else {
      CacheService.getScriptCache().removeAll([CACHE_KEY.GLOBAL_ALIAS_ALL, CACHE_KEY.GLOBAL_ALIAS_REVERSE]);
    }

    logInfo(
      'MatchEngine',
      'cleanupStaleCanonicalAliases_: deactivated ' +
        rowsToDeactivate.length +
        ' stale canonical aliases across ' +
        keysToCheck.length +
        ' entities'
    );

    // [V6.0.007] Audit Trail — record batch alias deactivation (Critical-Only scope)
    //   Since this is a batch operation, we log one DELETE record per deactivated row.
    //   For very large batches (>50), we summarize to avoid audit spam.
    //   Failsafe: logAuditTrail never throws — wrapped in its own try/catch
    if (typeof logAuditTrail === 'function' && typeof AUDIT_ENTITY_TYPES !== 'undefined') {
      if (rowsToDeactivate.length <= 50) {
        // Log each row individually for fine-grained audit
        rowsToDeactivate.forEach(function (rowNum) {
          logAuditTrail(
            AUDIT_ENTITY_TYPES.ALIAS,
            'row:' + rowNum,
            AUDIT_ACTIONS.DELETE,
            'active_flag',
            'true',
            'false',
            'cleanupStaleCanonicalAliases_ (batch)'
          );
        });
      } else {
        // Large batch — log one summary record
        logAuditTrail(
          AUDIT_ENTITY_TYPES.ALIAS,
          'batch:' + keysToCheck.length,
          AUDIT_ACTIONS.DELETE,
          'active_flag',
          String(rowsToDeactivate.length) + ' rows',
          'false',
          'cleanupStaleCanonicalAliases_ (batch summary)'
        );
      }
    }
  } catch (err) {
    // Non-fatal — don't break the pipeline just because cleanup failed
    logError('cleanupStaleCanonicalAliases_', err.message, err);
  }
}

/**
 * matchCommitGlobalAlias_ — [F-12] เขียน M_ALIAS + cache invalidation
 *   [V6.0.007] Defensive width check — auto-pad short rows to SCHEMA.M_ALIAS.length
 *   to prevent "จำนวนคอลัมน์ไม่ตรง" Sheets API error if a future schema change
 *   misses a row push site.
 * @param {Sheet} mAliasSheet - Sheet object สำหรับ M_ALIAS
 * @param {Array} rows - Array of row arrays สำหรับ M_ALIAS
 */
function matchCommitGlobalAlias_(mAliasSheet, rows) {
  if (rows.length > 0 && mAliasSheet) {
    const expectedWidth = SCHEMA[SHEET.M_ALIAS].length; // 11 (V6.0.003)
    // [V6.0.007] Defensive: pad short rows to expected width (fill with '')
    //   This prevents total pipeline failure if a row push site was missed
    //   during a schema migration. Logs a warning so the missed site can be fixed.
    let widthMismatchFound = false;
    const paddedRows = rows.map(function (row) {
      if (row.length < expectedWidth) {
        widthMismatchFound = true;
        const padded = row.slice();
        while (padded.length < expectedWidth) padded.push('');
        return padded;
      }
      return row;
    });
    if (widthMismatchFound) {
      logWarn(
        'MatchEngine',
        'matchCommitGlobalAlias_: detected row(s) with width < ' +
          expectedWidth +
          ' — auto-padded with empty strings. Check matchEnrichEntityAliases_ and generatePersonAliasesFromHistory_' +
          ' to ensure all row pushes include the V6.0.003 columns (verified_by, review_id, verified_at).'
      );
    }
    mAliasSheet.getRange(mAliasSheet.getLastRow() + 1, 1, paddedRows.length, expectedWidth).setValues(paddedRows);
    // [FIX BUG-C01 V5.5.022] Use invalidateChunkedCache_ instead of removeAll
    //   เดิมใช้ removeAll เฉพาะ base keys ทำให้ chunk keys (_CHUNKS, _0, _1, ...) ตกค้าง
    //   loadGlobalAliasesMap_/loadGlobalAliasReverseIndex_ อ่านจาก chunk keys เก่า → stale alias data
    //   ทำให้ fastLookupByShipToName ไม่เจอ alias ใหม่จนกว่า TTL จะหมด
    if (typeof invalidateChunkedCache_ === 'function') {
      invalidateChunkedCache_(CACHE_KEY.GLOBAL_ALIAS_ALL);
      invalidateChunkedCache_(CACHE_KEY.GLOBAL_ALIAS_REVERSE);
    } else {
      CacheService.getScriptCache().removeAll([CACHE_KEY.GLOBAL_ALIAS_ALL, CACHE_KEY.GLOBAL_ALIAS_REVERSE]);
    }
  }
}

/**
 * matchCommitPersonAlias_ — [F-12] เขียน M_PERSON_ALIAS + cache + dedup update
 * @param {Spreadsheet} ss - Active spreadsheet
 * @param {Array} rows - Array of row arrays สำหรับ M_PERSON_ALIAS
 * @param {Object} context - Context สำหรับ dedup set update
 */
function matchCommitPersonAlias_(ss, rows, context) {
  if (rows.length > 0) {
    const paSheet = ss.getSheetByName(SHEET.M_PERSON_ALIAS);
    if (paSheet) {
      paSheet.getRange(paSheet.getLastRow() + 1, 1, rows.length, SCHEMA[SHEET.M_PERSON_ALIAS].length).setValues(rows);
      invalidateAliasCache_();
      // [FIX CRIT-018] Update in-memory dedup sets incrementally
      if (_ALIAS_ENRICHMENT_CONTEXT) {
        rows.forEach(function (paRow) {
          const pId = String(paRow[PERSON_ALIAS_IDX.PERSON_ID] || '').trim();
          const aNorm = normalizeForCompare(paRow[PERSON_ALIAS_IDX.ALIAS_NAME]);
          if (pId && aNorm) _ALIAS_ENRICHMENT_CONTEXT.existingPersonAliasSet.add(pId + '::' + aNorm);
        });
      }
    }
  }
}

/**
 * matchCommitPlaceAlias_ — [F-12] เขียน M_PLACE_ALIAS + cache + dedup update
 * @param {Spreadsheet} ss - Active spreadsheet
 * @param {Array} rows - Array of row arrays สำหรับ M_PLACE_ALIAS
 * @param {Object} context - Context สำหรับ dedup set update
 */
function matchCommitPlaceAlias_(ss, rows, context) {
  if (rows.length > 0) {
    const plaSheet = ss.getSheetByName(SHEET.M_PLACE_ALIAS);
    if (plaSheet) {
      plaSheet.getRange(plaSheet.getLastRow() + 1, 1, rows.length, SCHEMA[SHEET.M_PLACE_ALIAS].length).setValues(rows);
      invalidatePlaceAliasCache_();
      // [FIX CRIT-018] Update in-memory dedup sets incrementally
      if (_ALIAS_ENRICHMENT_CONTEXT) {
        rows.forEach(function (plaRow) {
          const plId = String(plaRow[PLACE_ALIAS_IDX.PLACE_ID] || '').trim();
          const aNorm = normalizeForCompare(plaRow[PLACE_ALIAS_IDX.ALIAS_NAME]);
          if (plId && aNorm) _ALIAS_ENRICHMENT_CONTEXT.existingPlaceAliasSet.add(plId + '::' + aNorm);
        });
      }
    }
  }
}
// ============================================================
// SECTION 2: processOneRow
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

// ============================================================
// SECTION 3: makeMatchDecision — 8 Rules
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

/**
 * matchCalcFullScore_ — [F-8] Confidence for Rule 4 (Full Match: geo + person + place)
 * [UPGRADE v5.5.046] รับ srcObj/personResult เพิ่มเติมเพื่อ Dynamic Weighting (2.2) — optional, backward compatible
 * [V6.0.015 P2.2] Delegates to `calculateWeightedScore` — backward compatible for existing callers
 *   that pass (geoConf, personConf, placeConf, srcObj, personResult) directly.
 * [V6.0.016] Base Weight: person=0.45, geo=0.35, place=0.20 (name primary, geo reduced)
 * @param {number} geoConf - geoResult.confidence
 * @param {number} personConf - personResult.confidence
 * @param {number} placeConf - placeResult.confidence
 * @param {Object} [srcObj] - source row (optional — for dynamic weighting)
 * @param {Object} [personResult] - resolvePerson result (optional)
 * @returns {number} confidence (0-100)
 */
function matchCalcFullScore_(geoConf, personConf, placeConf, srcObj, personResult) {
  // [V6.0.015 P2.2] Delegate to unified calculateWeightedScore for consistency with Rule 5
  return calculateWeightedScore(
    srcObj,
    personResult ? Object.assign({}, personResult, { confidence: personConf }) : { confidence: personConf },
    { confidence: placeConf },
    { confidence: geoConf }
  );
}

/**
 * matchCalcGeoAnchorScore_ — [F-8] Confidence for Rule 5 (Geo Anchor: geo + one of person/place)
 * [V6.0.015 P2.2] Delegates to `calculateWeightedScore` — backward compatible for existing callers
 *   that pass (geoConf, personConf, placeConf, hasPerson) directly. The unused half (person or
 *   place) is zeroed out so that only the matched entity contributes to the final score.
 *   The result is capped at 95 to preserve the pre-V6.0.015 behavior of Rule 5 (geo anchor
 *   partial match should never reach 100 since one signal is missing).
 * [V6.0.016] Weight: person=0.45, geo=0.35, place=0.20 (capped at 95)
 * @param {number} geoConf - geoResult.confidence
 * @param {number} personConf - personResult.confidence (0 if not found)
 * @param {number} placeConf - placeResult.confidence (0 if not found)
 * @param {boolean} hasPerson - true if person matched, false if place matched
 * @returns {number} confidence (0-95)
 */
function matchCalcGeoAnchorScore_(geoConf, personConf, placeConf, hasPerson) {
  const personScore = hasPerson ? personConf : 0;
  const placeScore = hasPerson ? 0 : placeConf;
  const raw = calculateWeightedScore(
    null,
    { confidence: personScore },
    { confidence: placeScore },
    { confidence: geoConf }
  );
  return Math.min(95, raw);
}

// ============================================================
// SECTION 4: executeDecision — [REFACTOR-04] Dispatcher Pattern
// แยก AUTO_MATCH / CREATE_NEW / REVIEW ออกเป็น handler แยก
// ============================================================

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
// SECTION 5: Helper Functions
// ============================================================

// [REMOVED V5.5.044] getSameDayDestinations + _SAME_DAY_DEST_CACHE + invalidateSameDayDestCache_
//   ทั้ง 3 อย่างเป็น dead code — mark @deprecated ใน V5.5.043
//   - getSameDayDestinations: ไม่มี caller ใน .gs ใด (ตรวจด้วย grep)
//   - _SAME_DAY_DEST_CACHE: ใช้เฉพาะใน getSameDayDestinations
//   - invalidateSameDayDestCache_: ถูกเรียกใน 10_MatchEngine:1459, 12_ReviewService:319, 01_Config:106
//     แต่ทั้ง 3 caller ใช้ `typeof === 'function'` guard → จะ skip อัตโนมัติ
//   Caller cleanup:
//   - 10_MatchEngine.gs:1459 — ลบบรรทัด invalidateSameDayDestCache_()
//   - 12_ReviewService.gs:319 — ลบบรรทัด invalidateSameDayDestCache_()
//   - 01_Config.gs:106 — ลบบรรทัด invalidateSameDayDestCache_()
//   หากต้องการ restore → ดู git history ของ commit นี้

// [REMOVED V6.0.007] detectSameGeoMultiPerson — dead code since v5.4
//   ฟังก์ชันนี้ถูก implement สมบูรณ์ตั้งแต่ v5.4 แต่ไม่เคยถูก wire เข้า makeMatchDecision()
//   หรือ flow อื่นใดใน pipeline ทำให้เป็น dead code มาตลอด
//   ตั้งแต่ V5.5.042 ถูก mark เป็น "DEAD CODE — ไม่ถูกเรียกใช้ใน production"
//   ใน V6.0.007 ลบทิ้งสุดท้ายเพื่อลดความสับสน + ลด code maintenance burden
//
//   หากต้องการ restore → ดู git history ของ commit V6.0.007 (Feature 4: Dead Code Cleanup)
//   หากต้องการฟีเจอร์ "ตรวจจับหลายบุคคลใช้พิกัดเดียวกัน" → สร้างใหม่แบบ wire เข้า
//   makeMatchDecision() Rule 3.5 (NEARBY_PENDING) ตั้งแต่ต้น อย่า restore แบบเดิม
//
//   Original signature (for reference):
//   function detectSameGeoMultiPerson(geoId, currentPersonId) { ... }
//   - Returns true ถ้ามี person อื่นใช้ geoId เดียวกัน (ใน M_DESTINATION)
//   - ใช้ loadAllDestinations_() + .some() check
//
//   Reason for removal:
//   - ไม่มี caller ใน .gs ใด (ตรวจด้วย grep "detectSameGeoMultiPerson" src/ → 0 ผลลัพธ์)
//   - ฟังก์ชัน log warning ทุกครั้งที่ถูกเรียก = wasted log space
//   - BLUEPRINT.md (current version) ไม่ได้อ้างถึงฟีเจอร์นี้อีกแล้ว (V6.0 doc sync)

function getGeoProvince_(geoId) {
  if (!geoId) return '';
  const allGeos = loadAllGeos_();
  const geo = allGeos.find((g) => g.geoId === geoId);
  return geo ? geo.province || '' : '';
}

/**
 * getCandidateResolvedCoords_ — [V6.0.011] Get resolved lat/lng for a candidate entity
 *   Looks up M_DESTINATION by placeId or personId and returns its lat/lng directly
 *   (destinations already store resolved coordinates — no need to look up M_GEO_POINT)
 *
 *   Uses in-memory cache (_CANDIDATE_COORDS_CACHE_) built once per execution context
 *   to avoid repeated loadAllDestinations_() calls per row.
 *
 * @param {string} entityType — 'PLACE' or 'PERSON'
 * @param {string} entityId — placeId or personId
 * @return {{lat: number, lng: number}|null} coordinates or null if not found
 * @private
 */
let _CANDIDATE_COORDS_CACHE_ = null;
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

// ============================================================
// SECTION 6: Processing State Reset + Auto-Resume
// [REF-018] ลบ saveCheckpoint_, loadCheckpoint_ (dead code)
// เปลี่ยนชื่อ clearCheckpoint_ → resetProcessingState_ (ชัดเจนขึ้น)
// ============================================================

/**
 * resetProcessingState_ — [REF-018] ล้าง stale processing state จาก PropertiesService
 * เดิมชื่อ clearCheckpoint_ — เปลี่ยนชื่อเพื่อให้ชัดเจนว่าคือ reset state ไม่ใช่ checkpoint
 * รักษาพฤติกรรมเดิม 100% — ลบ MATCH_CHECKPOINT_INDEX และ MATCH_CHECKPOINT_ROW
 */
function resetProcessingState_() {
  try {
    const props = PropertiesService.getScriptProperties();
    props.deleteProperty('MATCH_CHECKPOINT_INDEX');
    props.deleteProperty('MATCH_CHECKPOINT_ROW');
  } catch (e) {
    /* ignore — cleanup only */
  }
  logInfo('MatchEngine', 'ล้าง Processing State เรียบร้อย');
}

// [REF-018] DELETED: saveCheckpoint_ — ไม่ถูกเรียกใช้แล้ว (SYNC_STATUS ทำหน้าที่แทน)
// [REF-018] DELETED: loadCheckpoint_ — ไม่ถูกเรียกใช้แล้ว (SYNC_STATUS ทำหน้าที่แทน)

/**
 * [NEW v5.2.003] Auto-Trigger System
 * [FIX v5.2.015] ป้องกันการลบทริกเกอร์ตั้งเวลาถาวรของผู้ใช้โดยการจำ ID
 * [FIX V6.0.007] Resilient trigger creation:
 *   - 3 retries with exponential backoff (2s, 4s, 8s) for transient GAS server errors
 *   - Quota check before create (warn if >15 time-based triggers exist)
 *   - Non-fatal: if all retries fail, log warning + alert user but DON'T throw
 *     Reason: pipeline has already done useful work in this batch — losing it
 *     because trigger creation failed would be worse than just asking user
 *     to manually re-run via menu.
 */
function installAutoResume_(funcName) {
  removeAutoResume_(); // ลบของเก่าก่อนถ้ามี

  // [V6.0.007] Pre-check: count existing triggers + cleanup orphans if approaching quota
  //   GAS limit: 20 time-based triggers per user per script
  //   If we have >15, try to cleanup any orphans (auto-resume triggers that lost their property mapping)
  try {
    const triggers = ScriptApp.getProjectTriggers();
    if (triggers.length > 15) {
      logWarn(
        'MatchEngine',
        'installAutoResume_: trigger count = ' +
          triggers.length +
          ' (approaching GAS quota of 20) — cleaning up orphans'
      );
      cleanupOrphanAutoResumeTriggers_();
    }
  } catch (quotaErr) {
    // Non-fatal — log and continue with trigger creation attempt
    logWarn('MatchEngine', 'installAutoResume_: quota pre-check failed (non-fatal): ' + quotaErr.message);
  }

  // [V6.0.007] Retry loop with exponential backoff for transient GAS server errors
  //   Common error: "ขออภัย มีข้อผิดพลาดของเซิร์ฟเวอร์เกิดขึ้น โปรดรอสักครู่แล้วลองอีกครั้ง"
  //   This is a Google-side transient error — retry usually succeeds within 2-3 attempts.
  const maxRetries = 3;
  const backoffMs = [2000, 4000, 8000]; // 2s, 4s, 8s
  let lastError = null;
  let trigger = null;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      trigger = ScriptApp.newTrigger(funcName)
        .timeBased()
        .after(60 * 1000) // ให้รันต่อในอีก 1 นาที (หลบ Timeout)
        .create();
      break; // success — exit retry loop
    } catch (err) {
      lastError = err;
      const isLastAttempt = attempt === maxRetries;
      if (isLastAttempt) {
        logError(
          'MatchEngine',
          'installAutoResume_: trigger creation failed after ' + maxRetries + ' attempts — ' + err.message,
          err
        );
      } else {
        logWarn(
          'MatchEngine',
          'installAutoResume_: attempt ' +
            attempt +
            '/' +
            maxRetries +
            ' failed — ' +
            err.message +
            ' — retrying in ' +
            backoffMs[attempt - 1] / 1000 +
            's...'
        );
        Utilities.sleep(backoffMs[attempt - 1]);
      }
    }
  }

  // [V6.0.007] Non-fatal failure handling
  //   If all retries failed, don't throw — just log + alert user
  //   Pipeline has already done useful work (e.g., processed 72/650 rows)
  //   Throwing here would discard that work AND make the next manual run harder
  //   because SYNC_STATUS would still show in-flight.
  if (!trigger) {
    const errMsg = lastError ? lastError.message : 'unknown error';
    logError(
      'MatchEngine',
      'installAutoResume_: ALL RETRIES FAILED — trigger NOT created. ' +
        'Pipeline will NOT auto-resume. User must manually re-run via menu "🔄 รัน Pipeline (Match Engine)". ' +
        'Last error: ' +
        errMsg
    );
    // Alert user (non-blocking — safeUiAlert_ handles trigger context)
    if (typeof safeUiAlert_ === 'function') {
      try {
        safeUiAlert_(
          '⚠️ Auto-Resume ล้มเหลว',
          'ไม่สามารถติดตั้ง trigger สำหรับรันต่อได้หลังจากลอง 3 ครั้ง\n\n' +
            'Pipeline หยุดที่แถวปัจจุบัน — ข้อมูลที่ประมวลผลแล้วยังถูกบันทึก\n\n' +
            'กรุณารันต่อด้วยตนเอง:\n' +
            'เมนู LMDS > Pipeline > 🔄 รัน Pipeline (Match Engine)\n\n' +
            'Error: ' +
            errMsg
        );
      } catch (alertErr) {
        // ignore — alert is best-effort
      }
    }
    // Send Telegram alert if available (for visibility)
    if (typeof sendPipelineAlert_ === 'function') {
      try {
        sendPipelineAlert_(
          '⚠️ Auto-Resume ล้มเหลว — กรุณารัน Pipeline ต่อด้วยตนเอง (last error: ' + errMsg + ')',
          'WARN'
        );
      } catch (alertErr) {
        // ignore
      }
    }
    return; // exit without throwing
  }

  const triggerId = trigger.getUniqueId();
  PropertiesService.getScriptProperties().setProperty('AUTO_RESUME_TRIGGER_ID', triggerId);
  logInfo('MatchEngine', `ติดตั้ง Auto-Trigger: ${funcName} (ID: ${triggerId}) จะทำงานต่อใน 1 นาที`);
}

/**
 * cleanupOrphanAutoResumeTriggers_ — [V6.0.007] Remove orphan time-based triggers
 *   that call runMatchEngine but have no matching AUTO_RESUME_TRIGGER_ID property.
 *   These orphans accumulate when removeAutoResume_ fails (e.g., property was
 *   cleared but trigger wasn't deleted, or vice versa).
 * @private
 */
function cleanupOrphanAutoResumeTriggers_() {
  try {
    const props = PropertiesService.getScriptProperties();
    const knownTriggerId = props.getProperty('AUTO_RESUME_TRIGGER_ID');
    const triggers = ScriptApp.getProjectTriggers();
    let deletedCount = 0;

    for (const trigger of triggers) {
      const handler = trigger.getHandlerFunction();
      const triggerId = trigger.getUniqueId();
      // Only delete time-based triggers that call runMatchEngine AND are not the known one
      // (preserve any user-created triggers for other functions)
      if (handler === 'runMatchEngine' && triggerId !== knownTriggerId) {
        ScriptApp.deleteTrigger(trigger);
        deletedCount++;
      }
    }

    if (deletedCount > 0) {
      logInfo(
        'MatchEngine',
        'cleanupOrphanAutoResumeTriggers_: deleted ' + deletedCount + ' orphan runMatchEngine triggers'
      );
    }
  } catch (err) {
    logWarn('MatchEngine', 'cleanupOrphanAutoResumeTriggers_ failed (non-fatal): ' + err.message);
  }
}

// ============================================================
// SECTION: [V6.0.007] Emergency Stop Signal
//   User can request pipeline stop via menu "🛑 หยุด Pipeline (Emergency Stop)".
//   The running pipeline checks isPipelineStopRequested_() every 10 rows
//   and exits gracefully if true (flushes current batch + removes auto-resume
//   trigger so it doesn't fire after user stop).
//
//   Communication channel: PropertiesService script property 'PIPELINE_STOP_REQUESTED'
//   - "true" = stop requested
//   - absent/other = no stop requested (default)
//
//   Why PropertiesService instead of LockService?
//   - PropertiesService is readable from any execution context (menu UI vs
//     pipeline execution run in different processes)
//   - LockService is for mutual exclusion, not signaling
//   - CacheService would also work but has TTL (we want the signal to persist
//     until the pipeline sees it)
// ============================================================

const PIPELINE_STOP_KEY = 'PIPELINE_STOP_REQUESTED';

/**
 * isPipelineStopRequested_ — [V6.0.007] Check if user requested emergency stop
 *   Called every 10 rows from runMatchEngineLoop_. Returns true if the
 *   PIPELINE_STOP_REQUESTED property is set to 'true'.
 *   Failsafe: returns false on any error (don't break pipeline just because
 *   PropertiesService had a hiccup).
 * @return {boolean}
 * @private
 */
function isPipelineStopRequested_() {
  try {
    return PropertiesService.getScriptProperties().getProperty(PIPELINE_STOP_KEY) === 'true';
  } catch (e) {
    // Non-fatal — don't break pipeline just because stop check failed
    return false;
  }
}

/**
 * clearPipelineStopSignal_ — [V6.0.007] Clear the stop signal
 *   Called by finalizeMatchEngine_ after a graceful stop, OR by the
 *   "🟢 ยกเลิก Stop Signal" menu if user wants to manually clear.
 *   Failsafe: silently ignores errors.
 * @private
 */
function clearPipelineStopSignal_() {
  try {
    PropertiesService.getScriptProperties().deleteProperty(PIPELINE_STOP_KEY);
  } catch (e) {
    // ignore
  }
}

function removeAutoResume_() {
  const props = PropertiesService.getScriptProperties();
  const autoResumeTriggerId = props.getProperty('AUTO_RESUME_TRIGGER_ID');
  const triggers = ScriptApp.getProjectTriggers();
  let deletedCount = 0;

  for (const trigger of triggers) {
    const triggerId = trigger.getUniqueId();
    if (autoResumeTriggerId && triggerId === autoResumeTriggerId) {
      ScriptApp.deleteTrigger(trigger);
      deletedCount++;
    }
  }

  props.deleteProperty('AUTO_RESUME_TRIGGER_ID');

  if (deletedCount > 0) {
    logInfo('MatchEngine', `ลบ Auto-Trigger ที่ค้างอยู่ (${deletedCount} รายการ)`);
  }
}

// ============================================================
// SECTION 6: Abstraction Layer [REF-002]
// Thin wrappers around Group 2 calls for decoupling
// ============================================================

/**
 * loadSourceBatch_ — [REF-002] Load unprocessed rows from source
 * Thin wrapper around getUnprocessedRows() from 04_SourceRepository
 * @return {Array} Array of source objects to process
 */
function loadSourceBatch_() {
  return getUnprocessedRows();
}

/**
 * persistResult_ — [V6.0.031 REFACTOR] Wrapper สำหรับ backward compatibility
 *   ถูกแยกเป็น persistFactRows_() + persistReviewRows_() เพื่อ SRP
 *   (Audit finding 4: persistResult_ ทำ 2 หน้าที่ในฟังก์ชันเดียว)
 *
 *   Wrapper นี้คงไว้เพื่อไม่ให้ break existing callers — signature เหมือนเดิม
 *
 * @param {Array} factData - Array of fact row arrays to write to FACT_DELIVERY
 * @param {Array} reviewData - Array of review row arrays to write to Q_REVIEW
 */
function persistResult_(factData, reviewData) {
  persistFactRows_(factData);
  persistReviewRows_(reviewData);
}

/**
 * persistFactRows_ — [V6.0.031 EXTRACTED] เขียน FACT_DELIVERY rows + auto-enrich aliases
 *   แยกจาก persistResult_ เพื่อ Single Responsibility
 * @param {Array} factData - Array of fact row arrays (empty array = no-op)
 * @private
 */
function persistFactRows_(factData) {
  if (!factData || factData.length === 0) return;

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const factSheet = ss.getSheetByName(SHEET.FACT_DELIVERY);
  factSheet.getRange(factSheet.getLastRow() + 1, 1, factData.length, factData[0].length).setValues(factData);

  // [FIX CRIT-003] ล้าง FACT invoice RAM cache เพราะมีแถวใหม่ถูกเขียน
  if (typeof invalidateFactInvoiceCache_ === 'function') invalidateFactInvoiceCache_();
  // [REMOVED V5.5.044] invalidateSameDayDestCache_ — ลบ dead code (ดู comment ใน SECTION 5)

  // [UPGRADE v5.2.010] สร้าง Alias อัตโนมัติแบบ Real-time ทันทีที่บันทึก FACT สำเร็จ
  // [FIX v5.4.001] ห่อด้วย try-catch เพื่อป้องกัน alias error ทำให้ SYNC_STATUS ไม่ถูกอัปเดต
  try {
    autoEnrichAliasesFromFactBatch_(factData);
  } catch (aliasErr) {
    // [SEC-006 FIX] Mask invoice numbers — log เฉพาะจำนวน + ตัวอย่างแรก (3 ตัวแรก + ***)
    const failedInvoices = factData
      .map(function (r) {
        return normalizeInvoiceNo(r[FACT_IDX.INVOICE_NO]);
      })
      .filter(Boolean);
    const sampleMasked = failedInvoices[0] ? String(failedInvoices[0]).substring(0, 3) + '***' : 'n/a';
    logError(
      'MatchEngine',
      'autoEnrichAliases ล้มเหลว — M_ALIAS ขาดสำหรับ ' +
        failedInvoices.length +
        ' invoices ' +
        '(ตัวอย่างแรก: ' +
        sampleMasked +
        '). ' +
        'กรุณารัน generatePersonAliasesFromHistory เพื่อซ่อมแซม: ' +
        aliasErr.message,
      aliasErr
    );
  }
}

/**
 * persistReviewRows_ — [V6.0.031 EXTRACTED] เขียน Q_REVIEW rows + ระบายสีตาม issue_type
 *   แยกจาก persistResult_ เพื่อ Single Responsibility
 * @param {Array} reviewData - Array of review row arrays (empty array = no-op)
 * @private
 */
function persistReviewRows_(reviewData) {
  if (!reviewData || reviewData.length === 0) return;

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const reviewSheet = ss.getSheetByName(SHEET.Q_REVIEW);
  const startRow = reviewSheet.getLastRow() + 1;
  const numCols = reviewData[0].length;
  reviewSheet.getRange(startRow, 1, reviewData.length, numCols).setValues(reviewData);

  // [UPGRADE v5.2.005] ระบายสีแถว Q_REVIEW ตาม issue_type
  const backgrounds = reviewData.map((row) => {
    const issueType = String(row[REVIEW_IDX.ISSUE_TYPE] || '').trim();
    let color = null;
    if (issueType === 'GEO_NEARBY_YELLOW') color = '#fff2cc';
    else if (issueType === 'GEO_NEARBY_ORANGE') color = '#fce5cd';
    return new Array(numCols).fill(color);
  });
  reviewSheet.getRange(startRow, 1, reviewData.length, numCols).setBackgrounds(backgrounds);
}

// ============================================================
// SECTION 7: Group 1 Gateway [REF-001]
// resolveAndPersist_ — Encapsulates resolve-create-enrich-upsert sequence
// so Group 2 (ReviewService) doesn't call Group 1 CRUD directly
// ============================================================

// ============================================================
// SECTION 8: Tie-breaker — Geofencing Multi-Candidate [V6.0.002]
//   Resolve ties between candidates with similar scores using
//   driver history + street distance as secondary signals.
//   Invoked from processOneRow when personResult.status === 'NEEDS_REVIEW'.
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

// ============================================================
// SECTION: [REF-001] Group 1 Public Helpers for Reproc Flow
//   expose resolve-or-create operations โดยไม่ upsert FACT_DELIVERY
//   เพื่อให้ Group 2 (12_ReviewService.reprocessReviewQueue) เรียกผ่าน public interface
//   แทนการเรียก createPerson/createPlace/createDestination โดยตรง (Module Boundary)
//   Preserve Behavior 100% — เรียก create* ภายในเหมือนเดิม แค่ผ่าน wrapper
// ============================================================

// ============================================================
// SECTION: [V6.0.012 P1.7] Test Match Dry Run
//   รัน matching algorithm บน SOURCE data โดยไม่บันทึกผลลัพธ์ลง master sheets
//   ใช้สำหรับ comparison ก่อน/หลังเปลี่ยน matching algorithm
//   ⚠️ ไม่เรียก executeDecision() หรือ flushBatches_() — ไม่เขียน master sheets
// ============================================================
