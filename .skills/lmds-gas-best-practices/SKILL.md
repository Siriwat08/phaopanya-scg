<!-- DOC-TYPE: living -->
---
name: lmds-gas-best-practices
description: Google Apps Script-specific best practices for LMDS V6.0 — quotas, time limits, CacheService vs RAM, batch operations, LockService, PropertiesService, UrlFetch, HtmlService, Triggers, custom functions, and clasp. Use when designing pipelines, hitting timeouts, debugging quota errors, optimizing performance, or building web apps. Triggers on "GAS limit", "6 minute", "timeout", "CacheService", "LockService", "PropertiesService", "UrlFetchApp", "HtmlService", "Trigger", "custom function", "clasp", "quota", "exhausted", "batch", "chunked cache", "checkpoint", "auto-resume", "service account".
---

# LMDS GAS Best Practices — Quotas, Limits & Workarounds

> **Status:** LMDS V6.0.046 — built on Google Apps Script V8 runtime
> **Purpose:** Help design and debug within GAS's hard constraints.
> **Key insight:** GAS has a 6-minute execution time and 100 KB cache limit. LMDS uses Checkpoint + Auto-Resume + Chunked Cache to work around them.

This skill is the **platform knowledge layer** — load `lmds-architect` first to know the LMDS-specific patterns, then use this for GAS-specific questions.

---

## 1. The 7 Hard Limits (Memorize)

| Limit | Value | LMDS Workaround |
|---|---|---|
| **Execution time** | 6 min / invocation | Time Guard + Checkpoint + Auto-Resume |
| **CacheService** | 100 KB per key, 6h TTL, ~1000 keys total | Chunked Cache (200 items/chunk) |
| **PropertiesService** | ~500 KB total per property, 9 KB / key | Use only for config + checkpoint + trigger IDs |
| **UrlFetchApp** | 20,000 calls/day, 50 MB / call | 3-Layer Cache, dedup before fetch |
| **Sheet API** | 20,000 calls/day, 10 MB / call | Batch getValues/setValues, no per-cell calls |
| **Triggers** | 20 per user, 90 min max runtime for time-based | Spread triggers, use one for auto-resume |
| **Concurrent executions** | 30 per script | LockService for critical sections |

> **V5.5.013** `MAPS_CACHE` sheet removed — use `@customFunction` formulas + RAM cache.

---

## 2. The 6-Minute Time Limit (Law 5)

This is the #1 issue. Every long-running function needs the **checkpoint + auto-resume pattern**.

### The Pattern

```js
function runMatchEngine_() {
  const props = PropertiesService.getScriptProperties();
  const CURSOR_KEY = 'LMDS_PIPELINE_CURSOR';
  const startCursor = Number(props.getProperty(CURSOR_KEY) || 0);
  const TIME_LIMIT_MS = AI_CONFIG.TIME_LIMIT_MS;  // 300000 = 5 min
  const startTime = Date.now();
  
  const allRows = getUnprocessedRows_(startCursor);
  
  for (let i = 0; i < allRows.length; i++) {
    // Time Guard
    if (Date.now() - startTime > TIME_LIMIT_MS) {
      props.setProperty(CURSOR_KEY, String(startCursor + i));
      installAutoResume_(CURSOR_KEY);
      logInfo('10_MatchEngine', `Checkpoint at ${startCursor + i}, auto-resume installed.`);
      return { status: 'resumed', processed: i };
    }
    
    processOneRow_(allRows[i]);
  }
  
  // Done
  props.deleteProperty(CURSOR_KEY);
  removeAutoResume_();
  return { status: 'complete', processed: allRows.length };
}
```

### The Trigger Installer

```js
function installAutoResume_(cursorKey) {
  // Avoid duplicates
  const existing = ScriptApp.getProjectTriggers().filter(t => t.getHandlerFunction() === 'autoResume_');
  if (existing.length > 0) {
    logInfo('installAutoResume_', 'Trigger already exists, skipping.');
    return;
  }
  
  const trigger = ScriptApp.newTrigger('autoResume_')
    .timeBased()
    .after(60 * 1000)  // run after 1 minute
    .create();
  
  // Store the trigger ID for safe deletion
  PropertiesService.getScriptProperties()
    .setProperty('AUTO_RESUME_TRIGGER_ID', trigger.getUniqueId());
  PropertiesService.getScriptProperties()
    .setProperty('AUTO_RESUME_CURSOR_KEY', cursorKey);
}

function autoResume_() {
  // Re-launch the orchestrator (it reads the cursor from props)
  runMatchEngine_();
  
  // If pipeline completed, remove this trigger
  const props = PropertiesService.getScriptProperties();
  if (!props.getProperty(props.getProperty('AUTO_RESUME_CURSOR_KEY'))) {
    removeAutoResume_();
  }
}

function removeAutoResume_() {
  const props = PropertiesService.getScriptProperties();
  const triggerId = props.getProperty('AUTO_RESUME_TRIGGER_ID');
  if (!triggerId) return;
  
  const trigger = ScriptApp.getProjectTriggers().find(t => t.getUniqueId() === triggerId);
  if (trigger) {
    ScriptApp.deleteTrigger(trigger);
  }
  
  props.deleteProperty('AUTO_RESUME_TRIGGER_ID');
  props.deleteProperty('AUTO_RESUME_CURSOR_KEY');
}
```

### Best Practices

1. **5 min, not 6 min** — `AI_CONFIG.TIME_LIMIT_MS = 300000` leaves a 1-minute buffer for cleanup.
2. **Save checkpoint before install** — order matters: `setProperty` first, then `installAutoResume_`.
3. **One trigger per pipeline** — don't install multiple; check existing first.
4. **Test with `console.log`** — manually time your function before adding the guard.
5. **Batch work before saving** — process 100 rows, then check time, not every row.

---

## 3. CacheService 100 KB Limit (Law 4, P1)

`CacheService` throws if a single key's value exceeds 100 KB. LMDS uses **chunked cache**.

### The Pattern

```js
// In 14_Utils.gs
function saveChunkedCache_(baseKey, array, chunkSize = 200) {
  const cache = CacheService.getScriptCache();
  cache.remove(`${baseKey}__count`);  // clear old count
  
  for (let i = 0; i < array.length; i += chunkSize) {
    const chunk = array.slice(i, i + chunkSize);
    cache.put(`${baseKey}__${Math.floor(i / chunkSize)}`, JSON.stringify(chunk), 21600);
  }
  cache.put(`${baseKey}__count`, String(Math.ceil(array.length / chunkSize)), 21600);
}

function loadChunkedCache_(baseKey) {
  const cache = CacheService.getScriptCache();
  const count = Number(cache.get(`${baseKey}__count`) || 0);
  if (count === 0) return [];
  
  const result = [];
  for (let i = 0; i < count; i++) {
    const chunk = cache.get(`${baseKey}__${i}`);
    if (chunk) result.push(...JSON.parse(chunk));
  }
  return result;
}
```

### When to Use Each Layer

| Data size | Layer | Why |
|---|---|---|
| < 100 KB total | CacheService | fast, 6h TTL |
| 100 KB – 10 MB | Chunked CacheService | multiple keys, each < 100 KB |
| > 10 MB | Sheet cache or @customFunction formulas | no RAM pressure |
| Persistent across deploys | Sheet or PropertiesService | survives code changes |

---

## 4. The 3-Layer Cache

```
L1: RAM cache (fastest, dies with script invocation)
    ↓ miss
L2: CacheService (fast, 6h TTL, chunked if needed)
    ↓ miss
L3: Sheet or @customFunction formula (persistent)
    ↓ miss
External API (slowest, has quota cost)
```

### RAM Cache Pattern

In `01_Config.gs`:
```js
const _GLOBAL_RAM_CACHE = Object.create(null);
const RAM_TTL_MS = 5 * 60 * 1000;  // 5 min

function ramCacheGet_(key) {
  const entry = _GLOBAL_RAM_CACHE[key];
  if (!entry) return null;
  if (Date.now() - entry.ts > RAM_TTL_MS) {
    delete _GLOBAL_RAM_CACHE[key];
    return null;
  }
  return entry.value;
}

function ramCachePut_(key, value) {
  _GLOBAL_RAM_CACHE[key] = { value, ts: Date.now() };
}
```

### L3: @customFunction Formulas (V5.5.013+)

For read-only data that needs to be live in cells (e.g. Maps address lookup):

```js
/**
 * @customFunction
 * Resolves an address to coordinates using 3-layer cache.
 * Returns [lat, lng] or [null, null].
 */
function GEOCODE_LOOKUP(address) {
  if (!address) return [null, null];
  
  const cached = ramCacheGet_('GEO_' + address);
  if (cached) return [cached.lat, cached.lng];
  
  const fromSheet = lookupFromGeoSheet_(address);
  if (fromSheet) {
    ramCachePut_('GEO_' + address, fromSheet);
    return [fromSheet.lat, fromSheet.lng];
  }
  
  // API call
  const result = geocodeAddress_(address);
  if (result) {
    writeToGeoSheet_(address, result);
    ramCachePut_('GEO_' + address, result);
    return [result.lat, result.lng];
  }
  
  return [null, null];
}
```

Then in the cell: `=GEOCODE_LOOKUP(A2)` — Google Sheets calls this on edit, with full L1+L2+L3 caching.

### Cache Invalidation Chain (Law 20)

| Write happens | Must call |
|---|---|
| Master sheet write | `invalidateAllGlobalCaches()` (or specific invalidator) |
| Maps cache write | `clearMapsCache()` + `invalidateGeoRamCache_()` |
| Alias write | `invalidateAliasCache_()` |
| FACT write | `invalidateFactInvoiceCache_()` |
| Menu "🧹 ล้างความจำระบบ" | `invalidateAllGlobalCaches()` |

`invalidateAllGlobalCaches()`:
```js
function invalidateAllGlobalCaches() {
  // L1: RAM
  Object.keys(_GLOBAL_RAM_CACHE).forEach(k => delete _GLOBAL_RAM_CACHE[k]);
  
  // L2: CacheService
  const cache = CacheService.getScriptCache();
  cache.removeAll([
    'SOURCE_ROWS', 'GEO_DICT_ROWS', 'GEO_DICT_MAP', 'GEO_DICT_PROVINCES',
    'GEO_DICT_DISTRICTS', 'ALL_PERSONS', 'ALL_PLACES', 'ALL_GEOS',
    'ALL_DESTINATIONS', 'ALL_FACTS', 'ALIAS_MAP'
    // ... all base keys
  ]);
  
  // L3: Maps cache
  clearMapsCache();
}
```

---

## 5. LockService for Critical Sections

Whenever a function writes to a master sheet, use `LockService` to prevent concurrent runs from clobbering each other.

```js
function createPerson_(name, phone) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(APP_CONST.LOCK_TIMEOUT_MS)) {  // 10 sec
    throw new Error('Could not acquire lock — another write in progress');
  }
  try {
    // ... read-modify-write logic ...
    return { success: true, person_id: newId };
  } finally {
    lock.releaseLock();
  }
}
```

### Rules

1. **Always use `tryLock` with timeout** — `tryLock()` (no args) waits forever, which can exceed 6 min.
2. **Always release in `finally`** — even on error.
3. **Don't hold the lock longer than necessary** — read the data, release, then do slow work outside.
4. **Nested locks are not allowed** — if function A acquires the lock and calls function B which also tries, B will time out.

---

## 6. PropertiesService — Config + Checkpoint + Trigger IDs

Three use cases, three properties:

```js
const props = PropertiesService.getScriptProperties();

// 1. Config (set once, read often)
props.setProperty('GEMINI_API_KEY', '...');
props.setProperty('LMDS_ADMINS', 'a@x.com,b@y.com');
props.setProperty('TELEGRAM_BOT_TOKEN', '...');
props.setProperty('TELEGRAM_CHAT_ID', '...');

// 2. Checkpoint (set/clear by pipelines)
props.setProperty('LMDS_PIPELINE_CURSOR', '142');
// On completion:
props.deleteProperty('LMDS_PIPELINE_CURSOR');

// 3. Trigger IDs (for safe deletion)
props.setProperty('AUTO_RESUME_TRIGGER_ID', trigger.getUniqueId());
props.setProperty('AUTO_RESUME_CURSOR_KEY', 'LMDS_PIPELINE_CURSOR');
```

### Size Limits

- Per key: ~9 KB
- Total per script: ~500 KB
- If you exceed, you get a silent fail (no exception)

### Convention in LMDS

All property keys are `UPPER_SNAKE_CASE` and prefixed with `LMDS_` for app-level or `AUTO_RESUME_` for trigger system.

---

## 7. UrlFetchApp — 20K/Day Quota

### Best Practices

1. **Dedup before fetch** — group rows by normalized address, fetch each unique once.
2. **Use 3-Layer cache** — almost never call the API directly.
3. **Add retry with backoff** — `callSpreadsheetWithRetry()` in `14_Utils.gs` shows the pattern (applies to any fetch).
4. **Truncate response body in logs** — bug SEC-012.
5. **API key in header, not URL** — bug SEC-006.

```js
function callGeminiAPI(prompt) {
  const cacheKey = 'GEMINI_' + md5Hash_(prompt);
  const cached = ramCacheGet_(cacheKey) || loadFromCacheService_(cacheKey);
  if (cached) return cached;
  
  const res = UrlFetchApp.fetch('https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent', {
    method: 'post',
    contentType: 'application/json',
    headers: { 'x-goog-api-key': CONFIG.GEMINI_API_KEY },
    payload: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
    muteHttpExceptions: true
  });
  
  if (res.getResponseCode() !== 200) {
    logError('14_Utils', `Gemini API returned ${res.getResponseCode()}`);
    return null;
  }
  
  const body = JSON.parse(res.getContentText());
  const result = body.candidates?.[0]?.content?.parts?.[0]?.text;
  
  // Truncate before log
  logInfo('14_Utils', `Gemini response (truncated): ${result?.slice(0, 200)}`);
  
  ramCachePut_(cacheKey, result);
  saveToCacheService_(cacheKey, result, 21600);
  return result;
}
```

---

## 8. HtmlService — Web Apps

### The Pattern

```js
// In 22_WebApp.gs
function doGet(e) {
  return HtmlService.createHtmlOutputFromFile('Index')
    .setTitle('LMDS Dashboard V6.0.046')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}
```

In `Index.html`:
```html
<?!= include('Sidebar'); ?>
<?!= include('Dashboard'); ?>
```

In `Sidebar.html`:
```html
<div class="sidebar">
  <a href="?page=dashboard">Dashboard</a>
  <a href="?page=qreview">Q_REVIEW</a>
</div>
```

### Server-Client Communication

```js
// 22b_WebAppViews.gs
function getDashboardData() {
  return {
    autoMatchRate: 0.85,
    pendingReview: 12,
    lastRun: new Date().toISOString(),
    matchEngineMetrics: getMatchEngineMetrics_()
  };
}

// In Dashboard.html
<script>
  google.script.run
    .withSuccessHandler(renderDashboard)
    .withFailureHandler(showError)
    .getDashboardData();
</script>
```

### Security in WebApp

1. **Always call `isAuthorizedUser_()`** in the data providers (22b/22c).
2. **Never trust client-side data** — re-validate on server.
3. **Use `google.script.run` for actions** — never embed secrets in HTML.
4. **Limit response size** — return only what the page needs.

---

## 9. Triggers

### Types

| Type | Use case | Max runtime |
|---|---|---|
| `onOpen` | Build menu | N/A (instant) |
| `onEdit` | React to cell change | 30 sec |
| `onSelectionChange` | Smart navigation | N/A |
| Time-based (`after`, `everyHours`) | Scheduled runs | 90 sec for `after`, 6 min for recurring |

### The 20-Trigger Limit

If you exceed, `newTrigger` throws. Solution: **recycle** triggers.

```js
function installOrRecycleTrigger_(handlerName, delayMin) {
  const existing = ScriptApp.getProjectTriggers().find(t => t.getHandlerFunction() === handlerName);
  if (existing) {
    ScriptApp.deleteTrigger(existing);
  }
  return ScriptApp.newTrigger(handlerName)
    .timeBased()
    .after(delayMin * 60 * 1000)
    .create();
}
```

### Filtered Triggers (Law 19)

```js
// In 00_App.gs (entry point)
function onEdit(e) {
  if (!e) return;
  if (e.range.getSheet().getName() !== SHEET.Q_REVIEW) return;
  if (e.range.getColumn() !== Q_REVIEW_IDX.DECISION + 1) return;
  if (e.range.getRow() < 2) return;
  
  try {
    applyReviewDecision_(e.range.getRow());
  } catch (err) {
    logError('00_App.onEdit', `row ${e.range.getRow()} failed`, err);
  }
}
```

---

## 10. clasp — Local Development

### Setup

```bash
# Install
npm install -g @google/clasp

# Login (one-time)
clasp login

# Create .clasp.json (NEVER commit)
cat > .clasp.json <<EOF
{
  "scriptId": "your_script_id_here",
  "rootDir": "src"
}
EOF

# Pull current state
clasp pull

# Edit files locally

# Push
clasp push

# Deploy (create versioned deployment)
clasp deploy --description "V6.0.046 production"
```

### Apps Script Structure

Apps Script doesn't support subdirectories. The CI flattens:
```
src/1_group1_master_db/10_MatchEngine.gs
                          ↓
apps-script-target/10_MatchEngine.gs
```

### Node Version

clasp 3.x has a bug with Node 22.23.0+, 24.17.0+, 25+, 26+ (Premature close error). Pin Node 20.x in CI (already done in `02-deploy.yml`).

### OAuth Setup

For CI, use `clasp login --creds` to get a `~/.clasprc.json`, then store its contents in GitHub Secret `CLASPRC`.

---

## 11. Common GAS Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| "Exceeded maximum execution time" | 6 min hit | Add checkpoint + auto-resume |
| "Service invoked too many times" | Quota exhausted | Batch operations, add cache |
| "Cache value too large" | > 100 KB per key | Use chunked cache |
| "You do not have permission" | OAuth scope missing or auth failed | Check appsscript.json, re-authorize |
| "Script function not found" | clasp push didn't include all files | Check flattening, all .gs at root |
| "We're sorry, a server error occurred" | Usually internal GAS bug, transient | Retry, or add try-catch + resume |
| "Premature close" (clasp) | Node 22/24+ incompatibility | Pin Node 20.x |
| "Address in use" (LockService) | Lock not released | Always use `finally { releaseLock }` |
| "Cannot find method" | Wrong type passed | Type-check with `typeof` |
| "Argument too large" | UrlFetch payload > 50 MB | Split into multiple calls |
| "Sortable range too large" | Trying to sort 100K+ rows | Sort in code, not in Sheet |

---

## 12. Performance Anti-Patterns (Top 10)

| # | Anti-pattern | Impact | Fix |
|---|---|---|---|
| 1 | `getValue()` in loop | 100x slower | `getValues()` once, iterate in JS |
| 2 | `setValue()` in loop | 100x slower | `setValues()` with array |
| 3 | `appendRow()` in loop | 50x slower | Build 2D array, single `setValues` |
| 4 | `getDataRange().getValues()` on 50K rows | OOM error | Chunk reads: 1000 rows at a time |
| 5 | `SpreadsheetApp.flush()` in loop | Each flush = network call | Flush once at end |
| 6 | `UrlFetchApp.fetch` per row | Hits 20K/day quota fast | Dedup, then fetch |
| 7 | Re-reading the same Sheet repeatedly | Slow | Read once into memory |
| 8 | `Math.random()` (not seeded) in match | Non-deterministic | Use a seed for reproducibility |
| 9 | `JSON.stringify` of huge object | OOM | Use chunked or specific keys |
| 10 | `Logger.log` in hot loop | Sheet write overhead | Use buffered logger |

---

## 13. LMDS-Specific Performance Wins (Documented)

These were the wins from the 18 audit cycles:

| Area | Before | After | Improvement |
|---|---|---|---|
| Stats Update | ~200 API calls/batch | ~8 API calls/batch | 96% |
| FACT_DELIVERY write | N setValues | 1 batch setValues | 98% |
| Alias flush | ~400-600 calls | ~2-3 batch calls | 99% |
| Geo Dictionary scan | O(10,000) full | O(130) per province | 97% |
| Geo searchKey lookup | O(N) scan | O(1) exact match | 100% |
| Log writing | 1 call/entry | 1 call/50 entries | 98% |
| Cache > 100KB | Failed | Chunked Cache | 100% reliable |

The pattern in all cases: **batch, cache, chunk**.

---

## 14. Testing Without Burning Quota

For unit tests, use a mock Spreadsheet:

```js
function testWithMockSheet_() {
  const mockSheet = {
    getRange: (r, c) => ({ getValues: () => mockData, setValues: () => {} }),
    appendRow: () => {},
    getDataRange: () => ({ getValues: () => mockData })
  };
  
  // inject via context
  const result = processOneRow_(testRow, { sheet: mockSheet });
  // assert...
}
```

For integration tests, use a **dedicated test spreadsheet** (not production):
- Separate `.clasp.json` with the test script ID
- Separate `LMDS_ADMINS` (test admins only)
- Reset to known state before each test run

`29_SnapshotTest.gs` is the canonical snapshot test — run it before/after any major change to detect unintended behavior drift.

---

## 15. Integration with Other Skills

- **`lmds-architect`** — load first.
- **`lmds-code-reviewer`** — for code-level issues.
- **`lmds-bug-hunter`** — for the historical bug patterns.
- **`lmds-predeploy-checker`** — for the final go/no-go.
- **`lmds-cicd-pipeline`** — for the deploy workflow itself.
