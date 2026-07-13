<!-- DOC-TYPE: living -->
# lmds-refactor-advisor

# REFACTOR Helper

LMDS Refactor Advisor — Plan the Split
Status: LMDS V6.0.046 — all major god functions already split (round 3 of 18 audit cycles)
Target: Keep new functions < 50 lines, complexity < 15, max 6 params
Origin of the discipline: makeMatchDecision() was 267 lines → split into orchestrator + 8 small rules across 10b_MatchDecision.gs. runTestMatchDryRun_ was 190 lines.

This skill is the restructuring layer — load lmds-architect first to know what the file is supposed to do, then use this to plan the split.

How to Use This Skill
When the user pastes a function (or a file) and asks for a refactor (or says /REFACTOR, [CMD: REFACTOR], "this function is too long"):

1.
Profile — measure lines, branches, params, side effects.
2.
Identify smells — apply the 7 smell detectors in § 2.
3.
Propose split plan — output the § 3 template.
4.
Generate the refactored code — always full file (Law 15). Use the 5 refactoring recipes in § 4.
If the user only has a vague complaint ("this is messy"), start with the profiling questions in § 1.

1. Profiling — Measure Before You Cut
Run these checks on the function in question:

Metric	How to measure	Target	Hard limit
Lines	awk '/^function NAME/{s=NR}/\}/{if(s){print NR-s+1; s=0}}'	<50	<100 (Law 2)
Cyclomatic complexity	ESLint complexity: ['warn', 15]	<15	<30 (current eslint config)
Parameters	Count commas in signature	≤4	≤6 (eslint max-params)
Return points	grep -c 'return ' (excluding early returns)	1	3
Nesting depth	Manual — count if/for/while/try nesting	≤3	≤4
Side effects	Does it write to sheet / call UrlFetch / send email?	documented	—
Cyclomatic deps	Unique functions it calls	≤10	≤20
Output this profile table in every refactor proposal:

markdown

Copy
## Profile


| Metric | Current | Target | Status |

|---|---|---|---|

| Lines | 267 | <50 | ❌ |

| Complexity | 28 | <15 | ❌ |

| Params | 7 | ≤4 | ❌ |

| Returns | 4 | 1 | ❌ |

| Nesting | 5 | ≤3 | ❌ |

| Side effects | 2 (sheet write + log) | documented | ✅ |

| Calls | 12 | ≤10 | ⚠️ |
2. Seven Smells (LMDS-specific)
Smell 1 — "AND" in the docstring
If the function's docstring contains "and" between two verbs, it's two functions.

Examples:


❌ "Resolve person and write to master"

❌ "Match and persist to FACT_DELIVERY"

❌ "Fetch SCG data and enrich with coordinates"

✅ "Resolve person" (writes happen in a separate *AndPersist function)

Fix: split into doX_() and doXAndPersist_(). The persistence layer becomes a thin wrapper.

Smell 2 — Multiple early returns with different types
js

Copy
// ❌ SMELLY

function classifyMatch(row) {

  if (row.shipToName.includes('บจก.')) return 'COMPANY';

  if (row.lat === 0) return 'INVALID';

  if (score > 90) return 'AUTO';

  if (score > 70) return 'REVIEW';

  return 'UNKNOWN';

}
Fix: replace with a rule chain in a single orchestrator:

js

Copy
function classifyMatch_(row, score) {

  return [

    ['COMPANY',       isCompany_(row)],

    ['INVALID',       isInvalidLatLng_(row)],

    ['AUTO',          score >= AI_CONFIG.THRESHOLD_AUTO],

    ['REVIEW',        score >= AI_CONFIG.THRESHOLD_REVIEW],

    ['UNKNOWN',       true]

  ].find(([_, cond]) => cond)[0];

}
Smell 3 — Long parameter list
js

Copy
// ❌ SMELLY

function processOneRow(row, person, place, geo, dest, ctx, opts, callbacks) { ... }
Fix: introduce a RowContext object:

js

Copy
// ✅ BETTER

function processOneRow_(row, ctx) { ... }

// where ctx = { person, place, geo, dest, opts, callbacks }
This is the pattern 10_MatchEngine.processOneRow_ uses.

Smell 4 — Mixed levels of abstraction
js

Copy
// ❌ SMELLY

function runMatchEngine() {

  // ... orchestration ...

  for (let i = 0; i < rows.length; i++) {

    if (hasTimePassed_(300000)) { ... }

    const name = String(row[12]).toLowerCase().replace(/[^a-zก-๙]/g, '');

    const score = levenshtein(name, candidate) / Math.max(name.length, candidate.length);

    if (score > 0.9) { ... }

    // ... 200 more lines of low-level work ...

  }

}
Fix: separate the orchestrator (loop, time guard, checkpoint) from the worker (one row's logic):

js

Copy
// ✅ ORCHESTRATOR (high-level)

function runMatchEngine() {

  return runPipelineWithCheckpoint_({

    cursor: 'LMDS_PIPELINE_CURSOR',

    getRows: getUnprocessedRows_,

    processRow: processOneRow_,

    timeLimitMs: AI_CONFIG.TIME_LIMIT_MS

  });

}


// ✅ WORKER (low-level, 1 row)

function processOneRow_(row) {

  const ctx = createRowContext_(row);

  return executeDecision_(makeMatchDecision_(row, ctx), row, ctx);

}
Smell 5 — Duplicated try-catch around the same operation
js

Copy
// ❌ SMELLY

function step1() { try { ... } catch (e) { logError('s1', e.message, e) } }

function step2() { try { ... } catch (e) { logError('s2', e.message, e) } }

function step3() { try { ... } catch (e) { logError('s3', e.message, e) } }
Fix: wrap the orchestration:

js

Copy
// ✅ BETTER

function runFullPipeline() {

  try {

    runLoadSource();

    runNormalize();

    runMatchEngine();

  } catch (e) {

    logError('00_App.runFullPipeline', e.message, e);

    SpreadsheetApp.getUi().alert('Pipeline failed: ' + e.message);

  }

}

// Then individual steps can stay without try-catch (they're not entry points)
Exception: if step1, step2, step3 are each called independently from a menu, each still needs its own try-catch (entry point rule, Law 12).

Smell 6 — Hard-coded sheet names inside the function body
js

Copy
// ❌ SMELLY

function summarize() {

  const sheet = SpreadsheetApp.getActive().getSheetByName('FACT_DELIVERY');

  // ...

}
Fix: use SHEET.FACT_DELIVERY from 01_Config.gs:

js

Copy
const sheet = SpreadsheetApp.getActive().getSheetByName(SHEET.FACT_DELIVERY);
Bonus: if the function needs to work on multiple sheets, accept the sheet name as a param.

Smell 7 — Logic that depends on global flags instead of context
js

Copy
// ❌ SMELLY

let _isDryRun = false;

function processRow(row) {

  if (_isDryRun) { console.log('skipping'); return; }

  // ... real work ...

}
Fix: pass a context object:

js

Copy
function processRow_(row, ctx) {

  if (ctx.dryRun) return;

  // ...

}
ctx is built by the orchestrator and passed explicitly. No global state.

3. Split Plan Template
When proposing a refactor, output this exact structure:

markdown

Copy
## Refactor Plan: [functionName] in [file:lines]


### Profile

| Metric | Before | After (target) |

|---|---|---|


### Smells Detected

- [ ] Smell X: [evidence]

- [ ] Smell Y: [evidence]


### Target Structure
functionName (orchestrator)  [N lines, complexity C1]
├─ step1_()                   [M1 lines, C2]
├─ step2_()                   [M2 lines, C3]
└─ step3_()                   [M3 lines, C4]

text

Copy

### Migration Steps

1. Create new file `NN_NewModule.gs` (or extend existing)

2. Add header with VERSION, DEPENDENCIES, etc.

3. Move private helpers one at a time

4. Add `_` suffix to all moved helpers

5. Add `functionName_` orchestrator

6. Update call site

7. Run `/REVIEW15` on the new file

8. Run `/BUGHUNT` for regressions

9. Bump version, update CHANGELOG


### Risks

- [ ] Cache invalidation chain must be preserved

- [ ] Time guard logic must transfer

- [ ] AuthZ check must transfer
4. Five Refactoring Recipes
Recipe 1 — Extract Function
js

Copy
// BEFORE

function processInvoice(invoice) {

  // 20 lines of validation

  if (!invoice.number) throw new Error('no number');

  if (!invoice.date) throw new Error('no date');

  if (!invoice.amount || invoice.amount <= 0) throw new Error('no amount');

  // ... 20 lines of normalize

  const norm = invoice.number.trim().toUpperCase();

  // ... 20 lines of lookup

  const match = findByInvoice(norm);

  // ... 20 lines of write

  if (match) updateInvoice(match, invoice);

  else insertInvoice(invoice);

}


// AFTER

function processInvoice_(invoice) {

  validateInvoice_(invoice);

  const normalized = normalizeInvoice_(invoice);

  return persistInvoice_(findByInvoice(normalized.number), normalized);

}


function validateInvoice_(invoice) { /* 20 lines */ }

function normalizeInvoice_(invoice) { /* 20 lines */ }

function persistInvoice_(match, invoice) { /* 20 lines */ }
Recipe 2 — Extract Orchestrator + Worker
The pattern used in 10_MatchEngine.gs itself:

js

Copy
// ORCHESTRATOR (in 10_MatchEngine.gs)

function runMatchEngine_() {

  return runPipelineWithCheckpoint_({

    cursorKey: 'LMDS_PIPELINE_CURSOR',

    getRows: getUnprocessedRows_,

    processRow: processOneRow_,

    timeLimitMs: AI_CONFIG.TIME_LIMIT_MS,

    batchSize: APP_CONST.PIPELINE_BATCH

  });

}


// WORKER (in 10_MatchEngine.gs)

function processOneRow_(row) {

  const ctx = createRowContext_(row);

  const decision = makeMatchDecision_(row, ctx);

  return executeDecision_(decision, row, ctx);

}
runPipelineWithCheckpoint_ lives in 00_App.gs or a shared *_Pipeline.gs.

Recipe 3 — Replace Conditional with Polymorphism (Strategy)
For the 8-rule match decision, use a rules table:

js

Copy
// BEFORE — 267 lines of if-else

function makeMatchDecision(row, ctx) {

  if (isInvalidLatLng_(row)) return decideInvalid_(row);

  if (isLowQuality_(row)) return decideLowQuality_(row);

  if (isProvinceConflict_(row)) return decideProvinceConflict_(row);

  // ... 200 more lines

}


// AFTER — table-driven

const MATCH_RULES = [

  { name: 'INVALID_LATLNG',     check: isInvalidLatLng_,        decide: decideInvalidLatLng_ },

  { name: 'LOW_QUALITY',        check: isLowQuality_,           decide: decideLowQuality_ },

  { name: 'PROVINCE_CONFLICT',  check: isProvinceConflict_,     decide: decideProvinceConflict_ },

  { name: 'NEARBY_PENDING',     check: isNearbyPending_,        decide: decideNearbyPending_ },

  { name: 'FULL_MATCH',         check: isFullMatch_,            decide: decideFullMatch_ },

  { name: 'GEO_ANCHOR',         check: isGeoAnchor_,            decide: decideGeoAnchor_ },

  { name: 'FUZZY_MATCH',        check: isFuzzyMatch_,           decide: decideFuzzyMatch_ },

  { name: 'ALL_NEW_WITH_GEO',   check: isAllNewWithGeo_,        decide: decideAllNewWithGeo_ }

];


function makeMatchDecision_(row, ctx) {

  for (const rule of MATCH_RULES) {

    if (rule.check(row, ctx)) {

      return rule.decide(row, ctx);

    }

  }

  return decideDefault_(row, ctx);

}
This is exactly how 10b_MatchDecision.gs is structured. The rules table lives at the top of the file; each decide* is < 20 lines.

Recipe 4 — Replace Magic Numbers with Named Constants
js

Copy
// BEFORE

if (score > 0.9) return 'AUTO';

if (score > 0.7) return 'REVIEW';

if (distance < 50) autoMerge;


// AFTER

if (score > AI_CONFIG.THRESHOLD_AUTO / 100) return 'AUTO';

if (score > AI_CONFIG.THRESHOLD_REVIEW / 100) return 'REVIEW';

if (distance < AI_CONFIG.GEO_RADIUS_M) autoMerge;
Source of truth: all thresholds live in AI_CONFIG (or APP_CONST) in 01_Config.gs.

Recipe 5 — Replace Nested If with Guard Clauses
js

Copy
// BEFORE

function processRow(row) {

  if (row) {

    if (row.invoice) {

      if (row.amount > 0) {

        // ... real work ...

      } else {

        throw new Error('amount <= 0');

      }

    } else {

      throw new Error('no invoice');

    }

  } else {

    throw new Error('no row');

  }

}


// AFTER

function processRow(row) {

  if (!row) throw new Error('no row');

  if (!row.invoice) throw new Error('no invoice');

  if (row.amount <= 0) throw new Error('amount <= 0');

  // ... real work (nesting depth 0) ...

}
5. Helper Library — Boilerplate Templates
runPipelineWithCheckpoint_ (the standard pipeline shape)
js

Copy
/**

 * Generic pipeline runner with checkpoint + auto-resume.

 * @param {Object} opts

 * @param {string} opts.cursorKey - ScriptProperties key

 * @param {Function} opts.getRows - (startIdx) => rows[]

 * @param {Function} opts.processRow - (row) => result

 * @param {number} opts.timeLimitMs - e.g. AI_CONFIG.TIME_LIMIT_MS

 * @param {number} opts.batchSize - rows per call

 */

function runPipelineWithCheckpoint_(opts) {

  const props = PropertiesService.getScriptProperties();

  const cursor = Number(props.getProperty(opts.cursorKey) || 0);

  const rows = opts.getRows(cursor);

  const startTime = Date.now();

  

  for (let i = 0; i < rows.length; i++) {

    if (Date.now() - startTime > opts.timeLimitMs) {

      props.setProperty(opts.cursorKey, String(cursor + i));

      installAutoResume_(opts.cursorKey);

      logInfo('pipeline', `Checkpoint saved at ${cursor + i}, auto-resume installed.`);

      return { status: 'resumed', processed: i };

    }

    opts.processRow(rows[i]);

  }

  

  props.deleteProperty(opts.cursorKey);

  removeAutoResume_();

  return { status: 'complete', processed: rows.length };

}
The 8-rule decision table (for any new decision logic)
js

Copy
/**

 * @typedef {Object} DecisionRule

 * @property {string} name - Human-readable rule name

 * @property {number} priority - Lower = evaluated first

 * @property {Function} check - (row, ctx) => boolean

 * @property {Function} decide - (row, ctx) => Decision

 */


/** @type {DecisionRule[]} */

const RULES_TABLE = [

  { name: 'RULE_1', priority: 1, check: isRule1_, decide: decideRule1_ },

  // ...

];


/**

 * Run rules in priority order, first match wins.

 */

function applyRules_(row, ctx) {

  const sorted = [...RULES_TABLE].sort((a, b) => a.priority - b.priority);

  for (const rule of sorted) {

    if (rule.check(row, ctx)) {

      return { rule: rule.name, ...rule.decide(row, ctx) };

    }

  }

  return { rule: 'DEFAULT', action: 'REVIEW' };

}
6. Anti-Patterns to Avoid in Refactors
Anti-pattern	Why it's bad	Use instead
Pass a "kitchen sink" context object with 30+ fields	Hides dependencies; refactor just moves the mess	Pass only what each function needs
Over-split into 5-line functions	Adds call overhead, hurts readability	Split at logical boundaries, not arbitrary line counts
Move helpers to a generic Utils.gs	Violates Law 8 (namespace); groups unrelated code	Put helpers next to their public function (<file>_helpers section)
Use class-based OOP	GAS V8 supports it but the codebase style is functional + namespaced	Stick with personFindCandidates_ style
Add intermediate abstraction layers prematurely	YAGNI	Wait until 3+ use cases appear
Don't bump version after refactor	Docs drift	Bump APP_VERSION, update CHANGELOG
7. Output Template (the final refactor deliverable)
When you deliver a refactor, the response must include:

markdown

Copy
# Refactor: [functionName] (file:lines)


## Before

- 267 lines, complexity 28, 7 params, 4 returns

- Smells: AND in docstring, mixed abstraction, long param list


## After

- orchestrator: 18 lines, complexity 3, 2 params, 1 return

- 5 private helpers: avg 22 lines each, complexity ≤ 8


## New file structure

- `10b_NewModule.gs` (orchestrator + rules table)

- `10b_NewModule_helpers.gs` (private helpers — optional)

- `10b_NewModule_tests.gs` (Jest + 10d test harness)


## Code (full file, Law 15)

```js

/* FILE: 10b_NewModule.gs

 * VERSION: 6.0.045

 * DEPENDENCIES: 01_Config, 14_Utils

 * CALLED BY: 10_MatchEngine

 * ...

 * */

// ... full file, no ellipsis ...
Validation

 ESLint: 0 errors

 Prettier: 100%

 Complexity < 15 per function

 All call sites updated

 All tests pass (10d_MatchTestHarness)

 Snapshot test passes (29_SnapshotTest)

 CHANGELOG entry added

 Version bumped to 6.0.045

text

Copy

---


## 8. Integration with Other Skills


- **`lmds-architect`** — load first to know the file's role and dependencies.

- **`lmds-code-reviewer`** — run after the refactor to verify 16 Laws.

- **`lmds-bug-hunter`** — run after the refactor to catch regressions.

- **`lmds-predeploy-checker`** — final gate.

- **`lmds-gas-best-practices`** — if the refa