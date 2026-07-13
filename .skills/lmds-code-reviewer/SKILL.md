<!-- DOC-TYPE: living -->
---
name: lmds-code-reviewer
description: Enforce the LMDS V6.0 16 Immutable Laws (plus 5 hard rules) on any .gs / .js code change. Use when reviewing PRs, drafting new functions, or auditing existing code. Triggers on "/REVIEW15", "code review", "law check", "compliance", "16 laws", "single writer", "hardcode index", "batch operations", "SRP", "single responsibility", "security-first", "PII", "no silent fail", "lock", "logError", "namespace", "dependency map", "full file output", "HTML separate", or any user asking "is this code LMDS-compliant".
---

# 16 Immutable Laws

LMDS Code Reviewer — 16 Immutable Laws + 5 Hard Rules
Status: LMDS V6.0.046 — 16/16 COMPLIANT (after 18 audit cycles)
Purpose: Stop regressions on the 16 laws. Reject any PR that violates even one law.
Severity: Errors block merge. Warnings are advisory.

This skill is the enforcement layer for the architecture described in lmds-architect. Load both skills together.

How to Use This Skill
When the user pastes code (or points to a file) and asks for a review, run the 21-point checklist below. Format the answer as a markdown table with: # | Law | Status (✅/❌/⚠️) | Evidence (line numbers + snippet) | Fix.

If the user uses the command /REVIEW15 or [CMD: REVIEW15], do a deep audit and report:


compliance score: N/16

grouped violations (Critical / High / Medium / Low)

concrete patches (full file diff, never ...)

If a critical bug is suspected, chain to lmds-bug-hunter. If refactor is needed, chain to lmds-refactor-advisor.

The 21-Point Checklist (16 Immutable + 5 Hard Rules)
For each law: What it means, How to detect it, How to fix it, Severity.

LAW 1 — Clean Code
Meaning: camelCase for variables/functions. No var (use const/let). ESLint must pass with 0 errors. Names are self-documenting; no data, temp, x, arr, obj, tmp. Prettier config: single quote, 2-space indent, no trailing comma, 120 col width, LF endings.

Detect:


grep -nE '^\s*var\s' src/**/*.gs (should be 0 matches in non-legacy files)

grep -nE '\b(var|x|tmp|temp|data|arr|obj)\s*=' src/**/*.gs (warnings)

ESLint: no-var: error, prefer-const: warn (see .eslintrc.yml)

Fix pattern:

js

Copy
// ❌ BAD

var data = fetchData();

var x = data[0];


// ✅ GOOD

const shipments = fetchShipmentsFromScg();

const firstShipment = shipments[0];
Severity: ERROR (ESLint error)

LAW 2 — Single Responsibility (SRP)
Meaning: 1 function = 1 job, explainable without the word "AND". Max ~50 lines, hard cap 100 (.eslintrc.yml: max-lines-per-function: 300 is a generous upper bound for god functions; new code must stay under 100). If a function reads + writes + matches + persists → split. Use _ suffix for private helpers. Cyclomatic complexity ≤ 30 (target ≤ 15). Max 6 params (target ≤ 4).

Detect:


Function length: awk '/^function|^const \w+ = (function|\(.*\) =>|\(.*\) => {)/ {start=NR} /^}/ {if (start) {print FILENAME":"start"-"NR" ("NR-start+1" lines)"; start=0}}'

Cognitive complexity: use eslint --rule '{"complexity":["warn",15]}'

Long parameter list: grep -nE 'function \w+\([^)]*,[^)]*,[^)]*,[^)]*,' src/**/*.gs (≥4 commas)

Fix pattern: extract helpers

js

Copy
// ❌ BAD — 267 lines

function makeMatchDecision(row, person, place, geo, dest, ctx, opts) { ... }


// ✅ GOOD — orchestrator + 8 small rule helpers

function makeMatchDecision_(row, person, place, geo, dest, ctx) {

  if (isInvalidLatLng_(row)) return decideInvalidLatLng_(row);

  if (isLowQuality_(row)) return decideLowQuality_(row);

  // ... 8 rules, each a tiny function

}
Severity: ERROR (god functions) / WARN (>50 lines)

LAW 3 — No Hardcoded Index
Meaning: Never use numeric column indices. Always use *_IDX constants from 01_Config.gs. getRange() is 1-indexed — always add 1.

Detect:


grep -nE 'row\[[0-9]+\]' src/**/*.gs (any match in non-legacy is a violation)

grep -nE 'getRange\([^,]+,\s*[0-9]+\s*,' src/**/*.gs (matches without + 1)

grep -nE 'getRange\([^,]+,\s*[0-9]+\s*,\s*[0-9]+' src/**/*.gs

Fix pattern:

js

Copy
// ❌ BAD

const name = row[7];

sheet.getRange(r, 8).setValue(name);


// ✅ GOOD

const name = row[FACT_IDX.SHIP_TO_NAME];

sheet.getRange(r, FACT_IDX.SHIP_TO_NAME + 1).setValue(name);
Severity: ERROR

Bonus tip: If you need to add a column to FACT_DELIVERY, you must update both 01_Config.gs (FACT_IDX) and 02_Schema.gs (SCHEMA.FACT_DELIVERY). Forgetting one = Law 17 violation.

LAW 4 — Batch Operations Only
Meaning: Never call getValue(), setValue(), appendRow(), setBackground(), setFontColor(), setNumberFormat() in a loop. Use getValues(), setValues(), setBackgrounds(), setFontColors(), setNumberFormats() once with arrays. For >10K rows, use chunkArray_() (in 14_Utils.gs).

Detect:


grep -nE '\.setValue\(|\.getValue\(|\.appendRow\(|\.setBackground\(|\.setFontColor\(|\.setNumberFormat\(' src/**/*.gs

Manual review: any of the above inside a for / while / forEach is a violation.

Performance: eslint --plugin googleappsscript --rule 'no-restricted-syntax:[error,{"selector":"MemberExpression[property.name=/^setValue$|^getValue$/]"}]'

Fix pattern:

js

Copy
// ❌ BAD

for (let i = 0; i < rows.length; i++) {

  sheet.getRange(i + 2, 1).setValue(rows[i].name);

}


// ✅ GOOD

const values = rows.map(r => [r.name]);

sheet.getRange(2, 1, values.length, 1).setValues(values);
Exception: @customFunction formula cells in 15_GoogleMapsAPI (read-only).

Severity: ERROR

LAW 5 — Checkpoint & Resume
Meaning: Any pipeline that may exceed 2 minutes or process >1,000 rows must:

1.
Have a Time Guard (hasTimePassed_(AI_CONFIG.TIME_LIMIT_MS)) every 100 rows.
2.
Save checkpoint to PropertiesService (key: LMDS_PIPELINE_CURSOR).
3.
Install an auto-resume trigger via installAutoResume_().
4.
Resume from checkpoint on next run.
5.
Clear checkpoint on completion.
Detect:


grep -nE 'hasTimePassed_|saveCheckpoint_|installAutoResume_' src/**/*.gs (presence check)

grep -nE 'PropertiesService' src/*Pipeline*.gs src/*MatchEngine*.gs (must reference)

Manual: any function that does for (let i = 0; i < largeArray.length; ...) without hasTimePassed_ check is suspect.

Required pattern:

js

Copy
function runMatchEngine_() {

  const cursor = Number(PropertiesService.getScriptProperties().getProperty('LMDS_PIPELINE_CURSOR') || '0');

  const rows = getUnprocessedRows_(cursor);

  

  for (let i = 0; i < rows.length; i++) {

    if (hasTimePassed_(AI_CONFIG.TIME_LIMIT_MS)) {

      saveCheckpoint_(cursor + i);

      installAutoResume_();

      return;

    }

    processOneRow_(rows[i]);

  }

  

  clearCheckpoint_();

}
Severity: ERROR for runMatchEngine, applyAllPendingDecisions, buildFullQualityReport, buildOwnerSummary, buildShipmentSummary, MIGRATION_HybridAliasSystem. WARN for other batch operations.

LAW 6 — Document Dependencies
Meaning: Every .gs file must start with a header comment block:

js

Copy
/* FILE: NN_FileName.gs

 * VERSION: 6.0.046

 * DEPENDENCIES: 01_Config, 14_Utils, 21_AliasService

 * CALLED BY: 00_App, 17_SearchService

 * SHEETS TOUCHED: M_ALIAS, FACT_DELIVERY

 * CACHE INVALIDATION: invalidateAliasCache_, invalidateFactInvoiceCache_

 * PURPOSE: Hybrid Alias CRUD with single-writer enforcement.

 * */
Detect: grep -L '^ \* FILE:\|^ \* DEPENDENCIES:' src/**/*.gs (files missing header)

Fix pattern: copy the template above and fill in the actual deps. To find deps, look at all function calls in the file and check which other files define them.

Severity: ERROR (block CI doc-code-sync check 8)

LAW 7 — No Phantom Function Calls
Meaning: Never call a function that doesn't exist. Never use an undefined global. Before adding a foo() call, verify foo is defined somewhere in src/.

Detect:


eslint --rule '{"no-undef":["error"]}' (note: .eslintrc.yml has it off for GAS — must run manually)

Static check: extract every function call and grep for definition.

Grep your calls: grep -rn 'functionName_' src/

Fix pattern:

js

Copy
// ❌ BAD — calling something that doesn't exist

const result = resolvePersonMaster_(row);  // typo, should be resolvePerson_


// ✅ GOOD — verify the definition exists

const result = resolvePerson_(row);  // defined in 06_PersonService.gs
Severity: ERROR

LAW 8 — Namespace Pattern (No Function Name Collisions)
Meaning: Function names must be unique across all .gs files. Use a module prefix (e.g. personFindCandidates_, placeResolve_) and a _ suffix for private helpers. For public functions, prefer Object Namespace: PersonService.findCandidates().

Detect: grep -rn '^function \|^const \w+ = (' src/**/*.gs | awk -F: '{print $3}' | sort | uniq -c | awk '$1 > 1'

Fix pattern:

js

Copy
// ❌ BAD

// 06_PersonService.gs

function findCandidates(person) { ... }

// 09_DestinationService.gs

function findCandidates(dest) { ... }  // COLLISION


// ✅ GOOD — prefix per module

// 06_PersonService.gs

function personFindCandidates_(person) { ... }

// 09_DestinationService.gs

function destFindCandidates_(dest) { ... }
Severity: ERROR (collision) / WARN (no prefix)

LAW 9 — No Global State (No Cross-File Globals)
Meaning: Don't declare var temp = {} or const cache = {} outside 01_Config.gs. Pass data via parameters. Use CONFIG.* from 01_Config.gs for shared constants. Use CacheService for cross-invocation state. Use PropertiesService for checkpoint.

Detect:


grep -nE '^(var|let|const)\s+\w+\s*=\s*[\{\[]' src/**/*.gs then check the file is not 01_Config.gs

Look for module-level mutable state.

Fix pattern:

js

Copy
// ❌ BAD

let _lastProcessed = null;  // module-level mutable

function processRow(row) {

  _lastProcessed = row;

}


// ✅ GOOD

function processRow_(row, options = {}) {

  return processRowCore_(row, options);

}
Exception: 01_Config.gs may define CONFIG and module-level frozen constants. _GLOBAL_* is allowed for cache proxies in 01_Config only.

Severity: ERROR

LAW 10 — Lock Library Version
Meaning: Apps Script advanced services and external libraries must specify a version. Never use HEAD or dev. Lock to a stable version (e.g. version: 'v4' for Sheets API).

Detect: grep -nE "version:\s*['\"]HEAD['\"]|version:\s*['\"]dev['\"]" src/**/*.gs (0 matches expected) + check appsscript.json for dependencies.enabledAdvancedServices[].version.

Fix pattern: appsscript.json:

json

Copy
{

  "dependencies": {

    "enabledAdvancedServices": [

      { "userSymbol": "Sheets", "version": "v4", "serviceId": "sheets" }

    ],

    "libraries": [

      { "userSymbol": "MyLib", "version": "8", "libraryId": "..." }

    ]

  }

}
Severity: ERROR

LAW 11 — Separate HTML Files
Meaning: Never hardcode HTML in .gs files. Use HtmlService.createHtmlOutputFromFile('name') for top-level pages, and include('Component') for partials. 19 .html files expected (matches the WebApp pages + partials).

Detect: grep -nE '<html|<body|<div|<script' src/**/*.gs (these strings should never appear in a .gs file).

Fix pattern:

js

Copy
// ❌ BAD

function getAppHtml() {

  return HtmlService.createHtmlOutput('<html><body><h1>Dashboard</h1></body></html>');

}


// ✅ GOOD

// 22_WebApp.gs

function getAppHtml() {

  return HtmlService.createHtmlOutputFromFile('Index')

    .setTitle('LMDS Dashboard V6.0.046')

    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);

}


// Index.html

<?!= include('Sidebar'); ?>
Severity: ERROR

LAW 12 — Error Handling (No Silent Fail)
Meaning: Every entry point (function called from a menu, trigger, or HTTP request) must:

1.
Be wrapped in try-catch.
2.
In the catch block, call logError(moduleName, errorMessage, errorObject).
3.
Never catch {} silently.
4.
Helper functions don't need try-catch (caller handles).
Detect: grep -nE 'try\s*\{' src/**/*.gs | wc -l (count try blocks) vs grep -nE '\}\s*catch' src/**/*.gs | wc -l (count catch blocks) — ratio should be similar.

Fix pattern:

js

Copy
// ❌ BAD

function runFullPipeline() {

  runLoadSource();

  runNormalize();

  runMatchEngine();

}


// ✅ GOOD

function runFullPipeline() {

  try {

    runLoadSource();

    runNormalize();

    runMatchEngine();

  } catch (e) {

    logError('00_App', e.message, e);

    SpreadsheetApp.getUi().alert('Pipeline failed: ' + e.message);

  }

}
Targets: 187 try-catch blocks (per README). Coverage: every public function in 00_App.gs and every menu handler.

Severity: ERROR (no catch on entry point) / WARN (silent catch)

LAW 13 — Logging with Context
Meaning: logError(module, msg, err) must include:


module: filename (e.g. '10_MatchEngine')

msg: a human-readable description with row/context

err.stack || new Error().stack (full stack)

Logs go to SYS_LOG sheet (via SYS_LOG_IDX). Auto-clean at 5,000 rows.

Detect: grep -nE 'logError\(' src/**/*.gs — verify the calls include all 3 args.

Fix pattern:

js

Copy
// ❌ BAD

} catch (e) {

  console.log('Error: ' + e);

}


// ✅ GOOD

} catch (e) {

  logError('10_MatchEngine', `processOneRow failed at row=${row[1]}`, e);

}
Severity: WARN (upgrade to ERROR if stack missing)

LAW 14 — Structured File Names
Meaning: Format: XX_ComponentName.gs where XX is the load order (00-29). Examples: 00_App.gs, 10_MatchEngine.gs, 21_AliasService.gs. Never: code.gs, test.gs, myScript.gs.

Detect: find src -name "*.gs" | grep -vE '^[0-9]+_.*\.gs$|^99_Legacy\.gs$' (anything not matching pattern is a violation)

Fix: rename with git mv and update all references.

Severity: WARN

LAW 15 — Full Files Only
Meaning: When AI outputs or humans edit a .gs file, the output must be the entire file from line 1 to the last }. No ..., no // existing code, no // unchanged, no ellipsis anywhere. The repo must contain the full source at all times.

Detect:


grep -nE '^\s*//\s*\.\.\.|^\s*\.\.\.|^\s*//\s*unchanged|^\s*//\s*existing' src/**/*.gs (any match = violation)

For diffs, use proper unified diff format, not ellipsis.

Fix pattern:

diff

Copy
--- a/10_MatchEngine.gs

+++ b/10_MatchEngine.gs

@@ -120,7 +120,9 @@ function processOneRow_(row) {

-  const person = personFindCandidates_(row);

+  // [V6.0.045] add phone as 2nd strategy

+  const person = personFindCandidates_(row, { phone: row[FACT_IDX.DRIVER_PHONE] });

   if (person) {
Severity: ERROR (in PRs that touch .gs)

LAW 16 — Security-First Design
Meaning: Every function that writes master data must:

1.
Call isAuthorizedUser_() (from 27_RbacService.gs or 14_Utils.gs).
2.
Validate input before write (no formula injection — escape leading =, +, -, @).
3.
Sanitize cookies via sanitizeCookie_() (RFC 6265).
4.
Mask PII in logs (maskEmail_(), md5Hash_()).
5.
Never store secrets in cells — use PropertiesService.
6.
API keys in HTTP header, never URL.
Detect:


Find all setValue / setValues to master sheets and verify each has isAuthorizedUser_() check above.

grep -rn 'PropertiesService' src/**/*.gs for secret storage check.

grep -nE 'AIza[A-Za-z0-9_-]{35}' src/**/*.gs (raw API keys).

grep -nE '\?.*=.*[A-Za-z0-9]{30,}' src/**/*.gs (keys in URL).

Fix pattern:

js

Copy
// ❌ BAD

function createPerson(name) {

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET.PERSON);

  sheet.appendRow([generateShortId(), name]);

}


// ✅ GOOD

function createPerson_(name) {

  if (!isAuthorizedUser_()) {

    throw new Error('Unauthorized: createPerson requires Admin role');

  }

  const sanitized = sanitizeInput_(name);  // strip leading =, +, -, @

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET.PERSON);

  sheet.appendRow([generateShortId(), sanitized]);

}
Coverage required: 13/13 destructive ops guarded. See docs/02_IT_Guide_LMDS.md § 9.3 for the full list.

Severity: ERROR (PII / secrets) / ERROR (no AuthZ on destructive op)

LAW 17 — Schema Truthfulness (HARD RULE)
Meaning: Never guess *_IDX values. Always read from 01_Config.gs. If you add/remove a column:

1.
Update *_IDX in 01_Config.gs.
2.
Update SCHEMA in 02_Schema.gs.
3.
Bump SCHEMA_VERSION and APP_VERSION.
4.
Update all callers.
Detect: grep -nE 'FACT_IDX\.\w+' src/**/*.gs — then verify the named indices exist in 01_Config.gs.

Fix: always read from 01_Config.gs. If you need a new column, file an issue first.

Severity: ERROR (any mismatch)

LAW 18 — Read All Dependencies First (HARD RULE)
Meaning: Before editing a file, read all files it depends on and all files that depend on it (use module-map.md if present, otherwise the DEPENDENCIES header).

Process:

1.
Read target file's DEPENDENCIES header → load those.
2.
Grep all other files for CALLED BY matching target → load them.
3.
Trace one more hop for safety.
Severity: PROCESS (not auto-detectable; reviewer must verify PR description)

LAW 19 — Never Remove Triggers Blindly (HARD RULE)
Meaning: When removing a trigger:

1.
Filter by trigger ID, not just handler function name.
2.
Store the trigger ID in PropertiesService before deletion (for recovery).
3.
Never delete user-installed triggers (only system-installed auto-resume).
Detect: grep -nE 'ScriptApp\.deleteTrigger' src/**/*.gs and verify the deletion is guarded by ID check.

Fix pattern:

js

Copy
// ❌ BAD

ScriptApp.getProjectTriggers().forEach(t => {

  if (t.getHandlerFunction() === 'autoResume_') ScriptApp.deleteTrigger(t);

});


// ✅ GOOD

ScriptApp.getProjectTriggers().forEach(t => {

  if (t.getHandlerFunction() === 'autoResume_' && t.getUniqueId() === storedAutoResumeId) {

    ScriptApp.deleteTrigger(t);

    PropertiesService.getScriptProperties().deleteProperty('AUTO_RESUME_TRIGGER_ID');

  }

});
Severity: ERROR

LAW 20 — Cache Invalidation Chain (HARD RULE)
Meaning: Every write to a master sheet must call the matching invalidator. Map:

Write happens in	Must call
05_Normalize (none)	—
06_PersonService.createPerson/merge	invalidateAllGlobalCaches()
07_PlaceService.create/merge	invalidateAllGlobalCaches()
08_GeoService.createGeoPoint	invalidateAllGlobalCaches()
09_DestinationService.create	invalidateAllGlobalCaches()
10_MatchEngine writes to FACT	invalidateFactInvoiceCache_()
10_MatchEngine writes to M_ALIAS	invalidateAliasCache_()
11_TransactionService.upsertFactDelivery	invalidateFactInvoiceCache_()
12_ReviewService.applyReviewDecision	invalidateFactInvoiceCache_() + invalidateAliasCache_()
15_GoogleMapsAPI (none)	—
21_AliasService.createGlobalAlias	invalidateAliasCache_()
21_AliasService.MIGRATION_HybridAliasSystem	invalidateAllGlobalCaches()
For the menu command 🧹 ล้างความจำระบบ (Clear Cache), use invalidateAllGlobalCaches() which nukes everything (RAM + CacheService + maps cache).

Detect: review the write call sites and check the next 2-3 lines for an invalidator.

Severity: ERROR (stale cache = wrong match results)

LAW 21 — Invoice No Normalization (HARD RULE)
Meaning: Invoice numbers in Google Sheets get auto-formatted as scientific notation (e.g. INV2024070100123 → 2.02407E+12). Always call normalizeInvoiceNo() from 14_Utils.gs before comparison, write, or hash.

Detect: grep -nE 'invoice_no|invoiceNo|INVOICE_NO' src/**/*.gs — verify each occurrence is wrapped in normalizeInvoiceNo() or stored as a string from the start.

Fix pattern:

js

Copy
// ❌ BAD

const match = rows.find(r => r[6] === searchInvoice);  // scientific notation bug


// ✅ GOOD

const match = rows.find(r => normalizeInvoiceNo(r[6]) === normalizeInvoiceNo(searchInvoice));
Severity: ERROR (silent data corruption)

Review Output Template
When the user asks for a review, output this exact structure:

markdown

Copy
# LMDS Code Review — [filename or PR#]


**Compliance:** 16/16 (or N/16) | **Hard rules:** M/5 | **Overall:** PASS / FAIL


## Compliance Matrix


| # | Law | Status | Evidence | Fix |

|---|-----|--------|----------|-----|

| 1 | Clean Code | ✅ | no `var` in NN_File.gs | — |

| 3 | No Hardcode Index | ❌ | L42: `row[7]` should be `row[FACT_IDX.SHIP_TO_NAME]` | see patch below |

| ... | ... | ... | ... | ... |


## Critical Issues (block merge)

- **L42** hardcoded index → patch shown below


## Warnings (advisory)

- **L88** missing JSDoc


## Suggested Patch

```diff

- const name = row[7];

+ const name = row[FACT_IDX.SHIP_TO_NAME];
Required Follow-ups

 Bump APP_VERSION if any change touches 01_Config.gs

 Update CHANGELOG.md

 Run /[CMD: BUGHUNT] and /[CMD: PREDEPLOY]

text

Copy

---


## Integration with Other Skills


- **`lmds-bug-hunter`** — after this review, chain to scan for critical bugs and performance anti-patterns.

- **`lmds-refactor-advisor`** — if Law 2 (SRP) fails, use this to plan the split.

- **`lmds-predeploy-checker`** — before merging, run this for a final gate.

- **`lmds-security-auditor`** — for Law 16 deep audit.
