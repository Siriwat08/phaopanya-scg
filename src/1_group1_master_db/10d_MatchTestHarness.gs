/**
 * VERSION: 6.0.083
 * FILE: 10d_MatchTestHarness.gs
 * LMDS V6.0 — Match Engine Test Harness
 * ===================================================
 * PURPOSE:
 *   รวม Dry Run + test functions ที่ไม่เขียน master sheets
 *   แยกออกจาก 10_MatchEngine.gs เพื่อลดขนาดไฟล์ (audit 1.2)
 *   ถูกเรียกโดย 00_App.gs menu (runTestMatchDryRun_UI / runTestMatchDryRunForceAll_UI)
 *
 * CHANGELOG:
 *   See /docs/CHANGELOG.md for full history.
 *
 * DEPENDENCIES:
 *   REQUIRES: (Load Order)
 *     - 01_Config.gs, 02_Schema.gs, 03_SetupSheets.gs, 14_Utils.gs (core)
 *     - 10_MatchEngine.gs       (core match logic for dry run)
 *     - 04_SourceRepository.gs (getAllSourceRowsForceAll)
 *     - 29_SnapshotTest.gs      (baseline capture before dry run)
 *   CALLS: (Invokes)
 *     - runMatchEngine()                        → 10_MatchEngine.gs
 *     - getAllSourceRowsForceAll()              → 04_SourceRepository.gs
 *     - saveSnapshot()                          → 29_SnapshotTest.gs
 *     - logInfo()                               → 03_SetupSheets.gs
 *   EXPORTS TO:
 *     - 00_App.gs (runTestMatchDryRun_UI, runTestMatchDryRunForceAll_UI menus)
 *     - 29_SnapshotTest.gs (baseline capture before dry run)
 *     - 28_WebAppActions.gs (dry run action)
 *   SHEETS ACCESSED:
 *     - SHEET.TEST_MATCH_RESULTS (Write — append dry run results; Read — comparison)
 *   TRIGGERS: None
 *
 * ARCHITECTURE:
 *   Group 1 — Master data building (normalize, persons, places, geo, match engine, aliases)
 * ===================================================
 */

// ============================================================
// SECTION: MASTER_PLACE Acceptance Contract (R0)
//   Fixtures are de-identified and never write to source/master sheets.
//   This is a decision-contract baseline, not a Google Sheets production run.
// ============================================================

/**
 * runMasterPlaceAcceptanceContractTests_ — R0 acceptance gate for MP-01..MP-09.
 *   Runs only pure decision fixtures where the contract can be evaluated without
 *   a master-sheet write. Cases that require a spreadsheet copy remain explicitly
 *   pending rather than being represented as a false pass.
 *
 * @return {{passed:number,knownGapsConfirmed:number,pendingEvidence:number,
 *   unexpectedFailures:number,readyForR1:boolean,results:Array}}
 * @private
 */
function runMasterPlaceAcceptanceContractTests_() {
  const testCases = getMasterPlaceAcceptanceCases_();
  const results = testCases.map(runMasterPlaceAcceptanceCase_);
  const summary = summarizeMasterPlaceAcceptanceResults_(results);

  logInfo(
    'MatchTestHarness',
    'MASTER_PLACE acceptance R0: passed=' +
      summary.passed +
      ' known_gaps=' +
      summary.knownGapsConfirmed +
      ' pending_evidence=' +
      summary.pendingEvidence +
      ' unexpected_failures=' +
      summary.unexpectedFailures
  );

  return {
    passed: summary.passed,
    knownGapsConfirmed: summary.knownGapsConfirmed,
    pendingEvidence: summary.pendingEvidence,
    unexpectedFailures: summary.unexpectedFailures,
    readyForR1: summary.unexpectedFailures === 0 && summary.knownGapsConfirmed === 1,
    results: results
  };
}

/**
 * getMasterPlaceAcceptanceCases_ — source-of-truth fixtures for MP-01..MP-09.
 *   Google Sheets-only assertions are intentionally represented as pending.
 * @return {Array<Object>}
 * @private
 */
function getMasterPlaceAcceptanceCases_() {
  return getMasterPlaceDecisionCases_().concat(getMasterPlaceSheetEvidenceCases_());
}

/**
 * getMasterPlaceDecisionCases_ — cases whose dispatcher outcome is testable
 *   without writes or master-data lookups.
 * @return {Array<Object>}
 * @private
 */
function getMasterPlaceDecisionCases_() {
  return [
    createMasterPlaceAcceptanceCase_(
      'MP-01',
      'new identity with reverse geo',
      'Google Sheets run',
      createAcceptanceDecisionInput_(
        createAcceptanceSource_({ rawAddress: 'REVERSE-GEO-ALPHA' }),
        createAcceptanceResults_('NOT_FOUND', 'NOT_FOUND', 'NOT_FOUND')
      ),
      { action: 'CREATE_NEW', reason: 'NEW_GEO_WITH_GPS' },
      ''
    ),
    createMasterPlaceAcceptanceCase_(
      'MP-02',
      'duplicate normalized identity',
      'Google Sheets run',
      createAcceptanceDecisionInput_(createAcceptanceSource_(), createAcceptanceResults_('FOUND', 'FOUND', 'FOUND')),
      { action: 'AUTO_MATCH', reason: APP_CONST.MATCH_FULL },
      ''
    ),
    createMasterPlaceAcceptanceCase_(
      'MP-03',
      'text variation accepted by resolver',
      'Controlled offline + Google Sheets run',
      createAcceptanceDecisionInput_(
        createAcceptanceSource_({ rawPersonName: 'TEST ALPHA  BRANCH', rawPlaceName: 'TEST-ALPHA-BRANCH' }),
        createAcceptanceResults_('FOUND', 'BRANCH_MATCH', 'FOUND')
      ),
      { action: 'AUTO_MATCH', reason: APP_CONST.MATCH_FULL },
      ''
    ),
    createMasterPlaceAcceptanceCase_(
      'MP-05',
      'missing or invalid coordinates',
      'Controlled offline + Google Sheets run',
      createAcceptanceDecisionInput_(
        createAcceptanceSource_({ hasGeo: false, rawLat: '', rawLng: '' }),
        createAcceptanceResults_('NOT_FOUND', 'NOT_FOUND', 'NOT_FOUND')
      ),
      { action: 'REVIEW', reason: 'INVALID_LATLNG' },
      ''
    ),
    createMasterPlaceAcceptanceCase_(
      'MP-06',
      'reverse geo differs from raw destination address',
      'Google Sheets run',
      createAcceptanceDecisionInput_(
        createAcceptanceSource_({ rawPlaceName: 'RAW-DESTINATION-ALPHA', rawAddress: 'REVERSE-GEO-ALPHA' }),
        createAcceptanceResults_('NOT_FOUND', 'NOT_FOUND', 'NOT_FOUND')
      ),
      { action: 'CREATE_NEW', reason: 'NEW_GEO_WITH_GPS' },
      ''
    ),
    createMasterPlaceAcceptanceCase_(
      'MP-07',
      'geo and person found but place absent',
      'Code contract + simulation + Google Sheets run',
      createAcceptanceDecisionInput_(
        createAcceptanceSource_(),
        createAcceptanceResults_('FOUND', 'NOT_FOUND', 'FOUND')
      ),
      { action: 'REVIEW', reason: APP_CONST.MATCH_GEO_PERSON_NO_PLACE },
      'R1'
    )
  ];
}

/**
 * getMasterPlaceSheetEvidenceCases_ — cases that cannot be proven by dry-run.
 * @return {Array<Object>}
 * @private
 */
function getMasterPlaceSheetEvidenceCases_() {
  return [
    createMasterPlaceAcceptanceCase_(
      'MP-04',
      'same identity with material GPS change',
      'Controlled offline + Google Sheets run',
      null,
      { action: 'REVIEW', reason: 'DISTANCE_GUARD_OR_EVIDENCE_REQUIRED' },
      ''
    ),
    createMasterPlaceAcceptanceCase_(
      'MP-08',
      'approved review reprocess preserves reverse geo',
      'Code contract + Google Sheets run',
      null,
      { action: 'PRESERVE_REVERSE_GEO', reason: 'REPROCESS_TRACE_BACK' },
      'R2'
    ),
    createMasterPlaceAcceptanceCase_(
      'MP-09',
      'batch accounting reconciles every eligible source row',
      'Code contract + Google Sheets run',
      null,
      { action: 'ACCOUNT_ALL_ROWS', reason: 'BATCH_RECONCILIATION' },
      'R3'
    )
  ];
}

/**
 * createMasterPlaceAcceptanceCase_ — creates a de-identified contract fixture.
 * @return {Object}
 * @private
 */
function createMasterPlaceAcceptanceCase_(id, title, evidenceClass, decisionInput, expected, remediationPhase) {
  return {
    id: id,
    title: title,
    evidenceClass: evidenceClass,
    decisionInput: decisionInput,
    expected: expected,
    remediationPhase: remediationPhase
  };
}

/**
 * createAcceptanceDecisionInput_ — combines de-identified source and resolver fixtures.
 * @return {Object}
 * @private
 */
function createAcceptanceDecisionInput_(source, resolverResults) {
  return {
    source: source,
    personResult: resolverResults.personResult,
    placeResult: resolverResults.placeResult,
    geoResult: resolverResults.geoResult
  };
}

/**
 * createAcceptanceSource_ — returns minimum source shape used by dispatcher.
 * @return {Object}
 * @private
 */
function createAcceptanceSource_(overrides) {
  const source = {
    sourceRow: 'ACCEPTANCE-ROW',
    invoiceNo: 'TEST-INVOICE',
    rawPersonName: 'TEST ALPHA BRANCH',
    rawPlaceName: 'TEST-PLACE-ALPHA',
    rawAddress: 'REVERSE-GEO-ALPHA',
    rawLat: 13.7563,
    rawLng: 100.5018,
    hasGeo: true,
    province: ''
  };
  return Object.assign(source, overrides || {});
}

/**
 * createAcceptanceResults_ — returns minimum resolver shape used by dispatcher.
 * @return {Object}
 * @private
 */
function createAcceptanceResults_(personStatus, placeStatus, geoStatus) {
  return {
    personResult: { status: personStatus, confidence: 100 },
    placeResult: { status: placeStatus, confidence: 100 },
    geoResult: { status: geoStatus, confidence: 100, geoId: '' }
  };
}

/**
 * runMasterPlaceAcceptanceCase_ — evaluates a decision fixture or records why
 *   a Sheets-only evidence case is deliberately pending.
 * @return {Object}
 * @private
 */
function runMasterPlaceAcceptanceCase_(testCase) {
  if (!testCase.decisionInput) return createPendingAcceptanceResult_(testCase);

  const inputs = testCase.decisionInput;
  const decision = makeMatchDecision(inputs.source, inputs.personResult, inputs.placeResult, inputs.geoResult);
  const matchesExpectation =
    decision.action === testCase.expected.action && decision.reason === testCase.expected.reason;

  if (matchesExpectation) return createPassedAcceptanceResult_(testCase, decision);
  if (testCase.remediationPhase) return createKnownGapAcceptanceResult_(testCase, decision);
  return createFailedAcceptanceResult_(testCase, decision);
}

/**
 * createPendingAcceptanceResult_ — marks evidence requiring a test spreadsheet.
 * @return {Object}
 * @private
 */
function createPendingAcceptanceResult_(testCase) {
  return {
    id: testCase.id,
    title: testCase.title,
    verdict: testCase.remediationPhase ? 'PENDING_' + testCase.remediationPhase : 'PENDING_SHEETS_RUN',
    expected: testCase.expected,
    actual: null,
    evidenceClass: testCase.evidenceClass,
    note: 'Dry-run cannot prove writes, reprocess persistence, or batch reconciliation.'
  };
}

/**
 * createPassedAcceptanceResult_ — records a matching dispatcher outcome.
 * @return {Object}
 * @private
 */
function createPassedAcceptanceResult_(testCase, decision) {
  return {
    id: testCase.id,
    title: testCase.title,
    verdict: 'PASS',
    expected: testCase.expected,
    actual: { action: decision.action, reason: decision.reason },
    evidenceClass: testCase.evidenceClass,
    note: 'Decision contract passed; required Google Sheets evidence remains outstanding.'
  };
}

/**
 * createKnownGapAcceptanceResult_ — records an approved remediation baseline.
 * @return {Object}
 * @private
 */
function createKnownGapAcceptanceResult_(testCase, decision) {
  return {
    id: testCase.id,
    title: testCase.title,
    verdict: 'KNOWN_GAP_CONFIRMED',
    expected: testCase.expected,
    actual: { action: decision.action, reason: decision.reason },
    evidenceClass: testCase.evidenceClass,
    note: 'Expected pre-remediation baseline for ' + testCase.remediationPhase + '.'
  };
}

/**
 * createFailedAcceptanceResult_ — records an unexpected decision mismatch.
 * @return {Object}
 * @private
 */
function createFailedAcceptanceResult_(testCase, decision) {
  return {
    id: testCase.id,
    title: testCase.title,
    verdict: 'FAIL',
    expected: testCase.expected,
    actual: { action: decision.action, reason: decision.reason },
    evidenceClass: testCase.evidenceClass,
    note: 'Unexpected contract mismatch; stop before remediation changes.'
  };
}

/**
 * summarizeMasterPlaceAcceptanceResults_ — counts R0 result categories.
 * @return {{passed:number,knownGapsConfirmed:number,pendingEvidence:number,unexpectedFailures:number}}
 * @private
 */
function summarizeMasterPlaceAcceptanceResults_(results) {
  return results.reduce(
    function (summary, result) {
      if (result.verdict === 'PASS') summary.passed++;
      else if (result.verdict === 'KNOWN_GAP_CONFIRMED') summary.knownGapsConfirmed++;
      else if (result.verdict === 'FAIL') summary.unexpectedFailures++;
      else summary.pendingEvidence++;
      return summary;
    },
    { passed: 0, knownGapsConfirmed: 0, pendingEvidence: 0, unexpectedFailures: 0 }
  );
}

/**
 * runTestMatchDryRun_ — [V6.0.012 P1.7] Dry-run matching on SOURCE data
 *   Reads unprocessed source rows, calls resolvePerson/Place/Geo + makeMatchDecision
 *   for each row WITHOUT executing the decision (no writes to master sheets).
 *   Writes results to TEST_MATCH_RESULTS sheet (clear-and-replace pattern).
 *
 *   Use case: compare match rates before/after tweaking matching algorithm
 *   without polluting production data.
 *
 * [V6.0.017] เพิ่ม param forceAllRows (optional, default false)
 *   - false (default): ใช้ loadSourceBatch_() — กรองเฉพาะ unprocessed rows (เหมือนเดิม)
 *   - true: ใช้ getAllSourceRowsForceAll() — ข้าม SYNC_STATUS filter เพื่อทดสอบซ้ำกับข้อมูลที่ processed แล้ว
 *     ใช้เพื่อเปรียบเทียบ algorithm เก่า vs ใหม่ บนข้อมูลชุดเดิมโดยไม่ต้องรีเซ็ต SYNC_STATUS
 *
 * @param {number} [maxRows=100] - max rows to test (default 100)
 * @param {boolean} [forceAllRows=false] - [V6.0.017] ถ้า true → ข้าม SYNC_STATUS filter (ทดสอบได้ซ้ำ)
 * @return {{ tested: number, totalRows: number, autoMatched: number,
 *            createdNew: number, queuedReview: number, errors: number,
 *            matchRate: number, elapsedSec: number, forceAllRows: boolean }}
 */
function runTestMatchDryRun_(maxRows, forceAllRows) {
  maxRows = maxRows || 100;
  forceAllRows = forceAllRows === true; // [V6.0.017] explicit boolean coercion
  const startTime = new Date();

  // Load source rows
  // [V6.0.012 P1.7] Reset cached state — same pattern as prepareMatchEngineContext_
  resetProcessingState_();

  // [V6.0.017] เลือก loader ตาม forceAllRows flag
  //   - false: loadSourceBatch_() → getUnprocessedRows() → กรอง SYNC_STATUS + PROCESSED_INVOICES
  //   - true:  getAllSourceRowsForceAll() → ข้ามทั้งคู่ (test ได้ทุกแถว)
  let allPendingRows;
  if (forceAllRows) {
    allPendingRows = typeof getAllSourceRowsForceAll === 'function' ? getAllSourceRowsForceAll() : [];
    logInfo('MatchEngine', 'runTestMatchDryRun_: forceAllRows=true — ข้าม SYNC_STATUS filter');
  } else {
    allPendingRows = loadSourceBatch_();
  }

  if (allPendingRows.length === 0) {
    logInfo('MatchEngine', 'runTestMatchDryRun_: ไม่มีแถวที่ต้องประมวลผล');
    return {
      tested: 0,
      totalRows: 0,
      autoMatched: 0,
      createdNew: 0,
      queuedReview: 0,
      errors: 0,
      matchRate: 0,
      elapsedSec: 0,
      forceAllRows: forceAllRows
    };
  }

  const rowsToTest = allPendingRows.slice(0, maxRows);
  logInfo(
    'MatchEngine',
    'runTestMatchDryRun_: testing ' +
      rowsToTest.length +
      '/' +
      allPendingRows.length +
      ' rows' +
      (forceAllRows ? ' (forceAllRows=true)' : '')
  );

  // Initialize counters
  let autoMatched = 0;
  let createdNew = 0;
  let queuedReview = 0;
  let errors = 0;

  // Collect result rows for batch write to TEST_MATCH_RESULTS sheet
  const resultRows = [];

  // [V6.0.029] Time guard — ป้องกัน GAS 6-min timeout
  //   เดิม: Dry Run ไม่มี time guard → 400 rows × 1.5s = 600s → timeout at 360s
  //   ใหม่: หยุดที่ 300s (5 min) เพื่อเหลือ buffer 60s สำหรับ write TEST_MATCH_RESULTS
  //   ถ้าหยุดกลางทาง → เขียนผลที่ได้ + บอก user ว่าเหลือกี่แถว
  const DRY_RUN_TIME_LIMIT_MS = 300000; // 5 minutes
  let stoppedByTimeGuard = false;

  for (let i = 0; i < rowsToTest.length; i++) {
    // [V6.0.029] Time guard check — ทุก 10 rows เพื่อลด overhead
    if (i % 10 === 0 && i > 0) {
      const elapsed = new Date() - startTime;
      if (elapsed > DRY_RUN_TIME_LIMIT_MS) {
        logWarn(
          'MatchEngine',
          'runTestMatchDryRun_: Time guard หยุดที่แถว ' +
            i +
            '/' +
            rowsToTest.length +
            ' (elapsed=' +
            Math.round(elapsed / 1000) +
            's, limit=' +
            DRY_RUN_TIME_LIMIT_MS / 1000 +
            's) — เขียนผลที่ได้ ' +
            resultRows.length +
            ' rows'
        );
        stoppedByTimeGuard = true;
        break;
      }
    }

    const srcObj = rowsToTest[i];
    try {
      // Mirror processOneRow() resolution calls — but stop BEFORE executeDecision()
      // [V6.0.014 REVERT V6.0.013] sync with processOneRow — use rawPlaceName [18] as primary
      //   (with fallback to rawAddress [24]) — see processOneRow comment for full rationale
      const personResult = resolvePerson(srcObj.rawPersonName, null, { soldToName: srcObj.soldToName });
      const placeResult = resolvePlace(srcObj.rawPlaceName || srcObj.rawAddress, srcObj.rawAddress || '');
      const geoResult = resolveGeo(srcObj.rawLat, srcObj.rawLng);

      // [V6.0.002] Tie-breaker — same as processOneRow (mirror logic for accuracy)
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

      // Make decision ONLY — do NOT call executeDecision() (no writes!)
      const decision = makeMatchDecision(srcObj, personResult, placeResult, geoResult);

      // Count
      if (decision.action === 'AUTO_MATCH') autoMatched++;
      else if (decision.action === 'CREATE_NEW') createdNew++;
      else if (decision.action === 'REVIEW') queuedReview++;

      // Build result row — invoice_no masked (3 chars + ***)
      const maskedInvoice = srcObj.invoiceNo ? String(srcObj.invoiceNo).substring(0, 3) + '***' : '';

      resultRows.push([
        srcObj.sourceRow, // [0] source_row
        maskedInvoice, // [1] invoice_no (masked)
        String(srcObj.rawPersonName || '').substring(0, 100), // [2] person_name (trunc)
        String(srcObj.rawPlaceName || '').substring(0, 100), // [3] place_name (trunc)
        decision.action || '', // [4] action
        String(decision.reason || '').substring(0, 80), // [5] reason
        decision.confidence || 0, // [6] confidence
        String(decision.evidence || '').substring(0, 200) // [7] evidence
      ]);
    } catch (rowErr) {
      errors++;
      logError('MatchEngine', 'runTestMatchDryRun_: row ' + srcObj.sourceRow + ' failed — ' + rowErr.message, rowErr);
      // Still push a placeholder row so user can see which row errored
      const maskedInvoice = srcObj.invoiceNo ? String(srcObj.invoiceNo).substring(0, 3) + '***' : '';
      resultRows.push([
        srcObj.sourceRow,
        maskedInvoice,
        String(srcObj.rawPersonName || '').substring(0, 100),
        String(srcObj.rawPlaceName || '').substring(0, 100),
        'ERROR',
        String(rowErr.message || '').substring(0, 80),
        0,
        ''
      ]);
    }
  }

  // Write results to TEST_MATCH_RESULTS sheet (clear-and-replace pattern)
  //   Clear existing data rows (keep header) → write new rows in one batch
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET.TEST_MATCH_RESULTS);
    if (!sheet) {
      logWarn(
        'MatchEngine',
        'runTestMatchDryRun_: TEST_MATCH_RESULTS sheet not found — skipping write (results in log only)'
      );
    } else {
      // Clear existing data rows (keep header row 1)
      const lastRow = sheet.getLastRow();
      if (lastRow > 1) {
        const schemaLen = getSheetHeaders(SHEET.TEST_MATCH_RESULTS).length;
        sheet.getRange(2, 1, lastRow - 1, schemaLen).clearContent();
      }
      // Write new rows in one batch
      if (resultRows.length > 0) {
        sheet.getRange(2, 1, resultRows.length, resultRows[0].length).setValues(resultRows);
      }
      logInfo('MatchEngine', 'runTestMatchDryRun_: wrote ' + resultRows.length + ' rows to TEST_MATCH_RESULTS');
    }
  } catch (writeErr) {
    logError('MatchEngine', 'runTestMatchDryRun_: write to TEST_MATCH_RESULTS failed — ' + writeErr.message, writeErr);
    // Non-fatal — counts are still returned to caller
  }

  // Compute match rate
  const tested = resultRows.length;
  const matchRate = tested > 0 ? Math.round((autoMatched / tested) * 100) : 0;
  const elapsedSec = Math.round((new Date() - startTime) / 1000);

  logInfo(
    'MatchEngine',
    'runTestMatchDryRun_ done: tested=' +
      tested +
      ' auto_match=' +
      autoMatched +
      ' create_new=' +
      createdNew +
      ' review=' +
      queuedReview +
      ' errors=' +
      errors +
      ' match_rate=' +
      matchRate +
      '% (' +
      elapsedSec +
      's)'
  );

  return {
    tested: tested,
    totalRows: allPendingRows.length,
    autoMatched: autoMatched,
    createdNew: createdNew,
    queuedReview: queuedReview,
    errors: errors,
    matchRate: matchRate,
    elapsedSec: elapsedSec,
    forceAllRows: forceAllRows, // [V6.0.017] expose mode in summary
    stoppedByTimeGuard: stoppedByTimeGuard, // [V6.0.029] true if time guard stopped processing early
    requestedRows: maxRows // [V6.0.029] how many rows user requested
  };
}
