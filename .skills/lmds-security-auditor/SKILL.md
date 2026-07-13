<!-- DOC-TYPE: living -->
---
name: lmds-security-auditor
description: Security audit for LMDS V6.0 against the SEC-001 → SEC-012 checklist (12 fixes in V5.5.017 SECURITY-POSTFIX). Use when reviewing for hardcoded secrets, PII leaks, missing AuthZ, OAuth scope creep, formula injection, unprotected sheets, or before any production deploy. Triggers on "SEC-001", "SEC-002", "PII", "hardcoded secret", "API key", "AuthZ", "authorization", "OAuth scope", "least privilege", "cookie sanitization", "sheet protection", "formula injection", "PII masking", "reviewer email", "deny-by-default", "data exfiltration", "RFC 6265", "response body leak".
---

# SEC-001→012

LMDS Security Auditor — SEC-001 → SEC-012 Compliance
Status: LMDS V6.0.046 — 12/12 SEC checks PASS (after V5.5.017 SECURITY-POSTFIX)
Purpose: Deep security review beyond what CI automatically checks.
Origin: 12 issues found in audit round 14 (SECURITY-POSTFIX). 3 BLOCKING + 9 SHOULD_FIX.

This skill is the defense layer — load lmds-architect first to know the LMDS structure, then use this for any security review or before any production deploy.

The SEC-001 → SEC-012 Matrix
ID	Severity	Issue	Fix	Verification
SEC-001	🔴 BLOCKING	Hardcoded secrets in Sheet cells	Use PropertiesService.getScriptProperties() only	grep -rn "AIza|password|cookie.*=" src/ Input returns 0
SEC-002	🔴 BLOCKING	No AuthZ guard on destructive ops (13 ops)	isAuthorizedUser_() covers 13/13 ops (deny-by-default)	All write functions have isAuthorizedUser_() above
SEC-003	🟠 HIGH	Cookie CRLF injection	sanitizeCookie_() (RFC 6265 regex)	Cookie setter uses sanitized value
SEC-004	🟠 HIGH	PII in logs	MD5 hash + email masking; fetchWithRetry_ body truncation	All logError calls use maskEmail_
SEC-005	🟠 HIGH	No sheet protection	8 sheets protected + Q_REVIEW range	applySheetProtection_UI() covers all
SEC-006	🟠 HIGH	API key in URL	x-goog-api-key HTTP header	All UrlFetchApp uses headers
SEC-007	🟡 MEDIUM	Reviewer email not masked	maskReviewerEmail_() → s***i@company.com	Q_REVIEW shows masked email
SEC-008	🟡 MEDIUM	OAuth scope creep (10 scopes)	Reduced to 6 (Least Privilege)	appsscript.json has exactly 6
SEC-009	🟡 MEDIUM	Cookie regex non-RFC	RFC 6265 compliant regex	sanitizeCookie_ uses RFC_6265_COOKIE_REGEX
SEC-010	🟡 MEDIUM	PII masking incomplete	All log paths covered	Audit log audit
SEC-011	🟡 MEDIUM	Sheet protection incomplete (4 sheets)	Expanded to 8 sheets + Q_REVIEW range	applySheetProtection_UI() runs
SEC-012	🟡 MEDIUM	fetchWithRetry_ body leak in log	Truncate to 200 chars	logError(..., res.body.slice(0, 200))
How to Use This Skill
When the user asks "is this secure?" or says /SECAUDIT, [CMD: SECAUDIT], "SEC-001 to SEC-012", or before any production deploy:

1.
Run the 12-point checklist below in 4 categories.
2.
Run the automated bash verifications in § 6.
3.
For each finding, output: ID | Severity | File:Line | Pattern | Patch.
4.
Final verdict: PASS / FAIL with the overall risk score.
1. SEC-001 — Hardcoded Secrets in Cells or Code
Threat
A developer pastes an API key or cookie into a cell (e.g. Input!B1) or directly into .gs code. The Sheet is shareable, the code is in git. The secret leaks.

Detection
bash

Copy
# In source code

grep -rnE "AIza[A-Za-z0-9_-]{35}|AKIA[0-9A-Z]{16}|password\s*=\s*['\"][^'\"]+['\"]|sk_live_|Bearer\s+[A-Za-z0-9]{30,}" src/


# In Input sheet (only ShipmentNos and masked cookie are allowed)

# Manual: open the Sheet, check Input!A1:Z100 for any credential-looking string
Fix
js

Copy
// ❌ BEFORE — in 14_Utils.gs

const apiKey = 'AIzaSyD...';  // leaked


// ✅ AFTER

const apiKey = PropertiesService.getScriptProperties().getProperty('GEMINI_API_KEY');

if (!apiKey) throw new Error('GEMINI_API_KEY not set in ScriptProperties');
For the cookie specifically: Input!B1 is where the user enters the cookie. The system must move it to PropertiesService immediately:

js

Copy
function setSCGCookie_UI() {

  const ui = SpreadsheetApp.getUi();

  const response = ui.prompt('Enter SCG cookie:', ui.ButtonSet.OK_CANCEL);

  if (response.getSelectedButton() !== ui.Button.OK) return;

  

  const sanitized = sanitizeCookie_(response.getResponseText());

  PropertiesService.getScriptProperties().setProperty('SCG_COOKIE', sanitized);

  // Clear the cell immediately

  SpreadsheetApp.getActiveSpreadsheet()

    .getSheetByName(SHEET.INPUT)

    .getRange('B1').clearContent();

}
Verdict
✅ PASS if no matches in source AND Input sheet has no credentials in cells.
❌ FAIL if any match.

2. SEC-002 — AuthZ on Destructive Operations (13/13)
Threat
A non-admin user (Viewer or Reviewer) calls a destructive operation (create master, delete alias, change Q_REVIEW decision) and the system allows it.

The 13 Destructive Operations
#	Function	File	Required role
1	createPerson_	06_PersonService	Admin
2	mergePersonRecords_	06_PersonService	Admin
3	createPlace_	07_PlaceService	Admin
4	createGeoPoint_	08_GeoService	Admin
5	createDestination_	09_DestinationService	Admin
6	executeDecision (AUTO_MATCH or CREATE_NEW)	10_MatchEngine	Admin
7	autoEnrichAliasesFromFactBatch_	10_MatchEngine	Admin
8	applyReviewDecision (for MERGE/CREATE)	12_ReviewService	Reviewer+
9	createGlobalAlias	21_AliasService	Admin
10	MIGRATION_HybridAliasSystem	21_AliasService	Admin
11	assignMasterUuidIfMissing	21_AliasService	Admin
12	applySheetProtection_UI	19_Hardening	Admin
13	invalidateAllGlobalCaches (destructive in some contexts)	01_Config	Admin
The Pattern
js

Copy
function createPerson_(name, phone) {

  // ✅ AuthZ FIRST (deny-by-default)

  if (!isAuthorizedUser_()) {

    logError('06_PersonService', 'Unauthorized createPerson attempt', new Error('SEC-002'));

    throw new Error('Unauthorized: Admin role required to create Person');

  }

  

  // Then business logic

  const lock = LockService.getScriptLock();

  if (!lock.tryLock(APP_CONST.LOCK_TIMEOUT_MS)) {

    throw new Error('Could not acquire lock');

  }

  try {

    // ... write logic ...

  } finally {

    lock.releaseLock();

  }

}
Detection
bash

Copy
# For each of the 13 destructive ops, check that isAuthorizedUser_ is called within first 5 lines

for func in createPerson_ mergePersonRecords_ createPlace_ createGeoPoint_ createDestination_ createGlobalAlias applySheetProtection_UI; do

  echo "=== $func ==="

  grep -A 5 "function $func" src/**/*.gs | head -10

done
Verdict
✅ PASS if all 13/13 have isAuthorizedUser_() check.
❌ FAIL if any missing.

3. SEC-003 + SEC-009 — Cookie Sanitization (RFC 6265)
Threat
A malicious cookie value contains \r\nSet-Cookie: ... which allows header injection. Or contains characters outside the RFC 6265 allowed set, leading to parsing bugs.

The Pattern (in 14_Utils.gs or 19_Hardening.gs)
js

Copy
const RFC_6265_COOKIE_REGEX = /^[!#$%&'*+\-.^_`|~0-9A-Za-z]+=[!#$%&'*+\-.^_`|~0-9A-Za-z]*(;.*)?$/;


function sanitizeCookie_(rawCookie) {

  if (typeof rawCookie !== 'string') {

    throw new Error('Cookie must be a string');

  }

  // Remove CR/LF (CRLF injection)

  let sanitized = rawCookie.replace(/[\r\n]/g, '');

  // Trim

  sanitized = sanitized.trim();

  // Validate against RFC 6265

  if (!RFC_6265_COOKIE_REGEX.test(sanitized)) {

    logError('14_Utils', 'Cookie failed RFC 6265 validation', new Error('SEC-003/009'));

    throw new Error('Invalid cookie format (RFC 6265)');

  }

  return sanitized;

}
Detection
bash

Copy
# Check that setSCGCookie_UI uses sanitizeCookie_

grep -A 10 "function setSCGCookie_UI" src/**/*.gs

# Must contain: sanitizeCookie_(response.getResponseText())
Verdict
✅ PASS if sanitizeCookie_ is used wherever a cookie enters the system.
❌ FAIL if a raw cookie is stored without sanitization.

4. SEC-004 + SEC-010 — PII Masking in Logs
Threat
Logs include raw email, phone, or person name. The SYS_LOG sheet is visible to all admins, and may be exfiltrated via the WebApp dashboard.

The Pattern
js

Copy
// In 14_Utils.gs

function maskEmail_(email) {

  if (!email || typeof email !== 'string' || !email.includes('@')) return email;

  const [local, domain] = email.split('@');

  if (local.length <= 2) return `${local[0]}***@${domain}`;

  return `${local[0]}***${local[local.length - 1]}@${domain}`;

}


function md5Hash_(value) {

  if (!value) return '';

  return Utilities.computeDigest(Utilities.DigestAlgorithm.MD5, String(value))

    .map(b => (b < 0 ? b + 256 : b).toString(16).padStart(2, '0'))

    .join('');

}


function maskReviewerEmail_(email) {

  // For Q_REVIEW — show domain only

  if (!email || !email.includes('@')) return '***';

  return `***@${email.split('@')[1]}`;

}
js

Copy
// In any function that logs

// ❌ BEFORE

logError('10_MatchEngine', `Failed for ${row.driver_name} (${row.driver_phone})`, e);


// ✅ AFTER

logError('10_MatchEngine', `Failed for ${md5Hash_(row.driver_name)} (${md5Hash_(row.driver_phone)})`, e);
Detection
bash

Copy
# Find all logError calls and check for raw PII

grep -rnE "logError\(|logInfo\(" src/**/*.gs | grep -vE "mask\w+_|md5Hash_"

# Any output is suspicious
The grep targets

Raw email patterns: [\w.]+@[\w.]+

Raw phone patterns (Thai): 0[0-9]{9} or 0[0-9]-[\d-]+

Raw person names in logError context: requires manual review

Verdict
✅ PASS if all logError/logInfo calls use masking helpers.
⚠️ WARN if some logs use raw data but in DEV-only context (gated by if (DEV_MODE)).
❌ FAIL if production logs contain raw PII.

5. SEC-005 + SEC-011 — Sheet Protection (8 sheets + Q_REVIEW range)
Threat
A user with edit access deletes a row in M_PERSON directly, breaking all FK references. Or changes a Q_REVIEW Decision cell that wasn't theirs.

The Pattern (in 19_Hardening.gs)
js

Copy
function applySheetProtection_UI() {

  const ss = SpreadsheetApp.getActiveSpreadsheet();

  const me = Session.getActiveUser().getEmail();

  

  if (!isAuthorizedUser_()) {

    throw new Error('Unauthorized: Admin role required');

  }

  

  // 8 sheets to fully protect

  const protectedSheets = [

    SHEET.EMPLOYEE,

    SHEET.PERSON,

    SHEET.SOURCE,

    SHEET.GEO_POINT,

    SHEET.PLACE,

    SHEET.DESTINATION,

    SHEET.ALIAS,

    SHEET.FACT_DELIVERY

  ];

  

  protectedSheets.forEach(name => {

    const sheet = ss.getSheetByName(name);

    if (!sheet) return;

    const protection = sheet.protect().setDescription(`Protected: ${name}`);

    protection.setWarningOnly(false);

    // Add me as editor (admin can edit)

    protection.addEditor(me);

    // Remove all other editors

    const editors = protection.getEditors();

    editors.forEach(e => { if (e.getEmail() !== me) protection.removeEditor(e); });

  });

  

  // Q_REVIEW range protection (Decision + Reviewer columns)

  const qReview = ss.getSheetByName(SHEET.Q_REVIEW);

  if (qReview) {

    const lastRow = qReview.getLastRow();

    const decisionCol = Q_REVIEW_IDX.DECISION + 1;

    const reviewerCol = Q_REVIEW_IDX.REVIEWER + 1;

    const range = qReview.getRange(2, decisionCol, lastRow - 1, reviewerCol - decisionCol + 1);

    const protection = range.protect().setDescription('Q_REVIEW: Decision + Reviewer');

    protection.setWarningOnly(false);

    protection.addEditor(me);

  }

  

  // Hide sensitive sheets

  [SHEET.INPUT, SHEET.SYS_CONFIG].forEach(name => {

    const sheet = ss.getSheetByName(name);

    if (sheet) sheet.hideSheet();

  });

  

  SpreadsheetApp.getUi().alert('✅ Sheet protection applied (8 sheets + Q_REVIEW range)');

}
Detection
bash

Copy
grep -A 50 "function applySheetProtection_UI" src/**/*.gs | head -60

# Should list 8 sheets + Q_REVIEW range
Verdict
✅ PASS if exactly 8 sheets in the list + Q_REVIEW range protected.
⚠️ WARN if < 8 (regression).
❌ FAIL if 0 (no protection).

6. SEC-006 — API Key in HTTP Header (not URL)
Threat
API keys in URL query strings are logged by UrlFetchApp execution logs and may appear in:


Apps Script Executions dashboard

Stackdriver / Cloud Logging

Browser history (if called from WebApp)

The Pattern
js

Copy
// ❌ BEFORE (BAD)

const res = UrlFetchApp.fetch(

  `https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=${API_KEY}`,

  { method: 'post', contentType: 'application/json', payload: JSON.stringify(body) }

);


// ✅ AFTER

const res = UrlFetchApp.fetch(

  'https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent',

  {

    method: 'post',

    contentType: 'application/json',

    headers: { 'x-goog-api-key': API_KEY },

    payload: JSON.stringify(body),

    muteHttpExceptions: false

  }

);
Detection
bash

Copy
grep -rnE "UrlFetchApp\.fetch\(" src/**/*.gs | grep -E '\?.*(api_?key|access_?token|key)='

# Any match is SEC-006 violation
Verdict
✅ PASS if no matches.
❌ FAIL if any key in URL.

7. SEC-007 — Reviewer Email Masking
Threat
The Q_REVIEW sheet has a reviewer_email column. Showing full emails leaks the team structure.

The Pattern
js

Copy
function maskReviewerEmail_(email) {

  if (!email || !email.includes('@')) return '***';

  const parts = email.split('@');

  const local = parts[0];

  const domain = parts[1];

  if (local.length <= 2) return `${local[0]}***@${domain}`;

  return `${local[0]}***${local[local.length - 1]}@${domain}`;

}


// In 12_ReviewService when writing to Q_REVIEW

function writeReviewRow_(row) {

  row[Q_REVIEW_IDX.REVIEWER] = maskReviewerEmail_(Session.getActiveUser().getEmail());

  // ...

}
Detection
bash

Copy
# Check Q_REVIEW writes use maskReviewerEmail_

grep -B 1 -A 3 "Q_REVIEW_IDX.REVIEWER" src/**/*.gs

# Should see maskReviewerEmail_ or equivalent
Verdict
✅ PASS if all writes go through the masking function.
❌ FAIL if raw Session.getActiveUser().getEmail() is written.

8. SEC-008 — OAuth Scopes (10 → 6, Least Privilege)
The Current 6 Scopes (in appsscript.json)
json

Copy
"oauthScopes": [

  "https://www.googleapis.com/auth/spreadsheets",

  "https://www.googleapis.com/auth/userinfo.email",

  "https://www.googleapis.com/auth/script.storage",

  "https://www.googleapis.com/auth/script.container.ui",

  "https://www.googleapis.com/auth/script.scriptapp",

  "https://www.googleapis.com/auth/script.external_request"

]
Removed Scopes (10 → 6)

❌ https://www.googleapis.com/auth/gmail.send — not used (we use Telegram, not email)

❌ https://www.googleapis.com/auth/gmail.readonly — not used

❌ https://www.googleapis.com/auth/gmail.compose — not used

❌ https://www.googleapis.com/auth/gmail.modify — not used

Detection
bash

Copy
# Must have exactly 6 scopes

python3 -c "import json; d=json.load(open('appsscript.json')); print(len(d['oauthScopes']))"

# Expected: 6


# Check what each scope is

python3 -c "import json; d=json.load(open('appsscript.json')); [print(s) for s in d['oauthScopes']]"
Verdict
✅ PASS if exactly 6, all from the list above.
❌ FAIL if any extra or different.

9. SEC-012 — Response Body Truncation in Logs
Threat
fetchWithRetry_ in 14_Utils.gs may log the full response body for debugging — which can contain PII or large blobs.

The Pattern
js

Copy
function fetchWithRetry_(url, options, maxRetries = 3) {

  for (let attempt = 1; attempt <= maxRetries; attempt++) {

    try {

      const res = UrlFetchApp.fetch(url, options);

      if (res.getResponseCode() >= 500 && attempt < maxRetries) {

        Utilities.sleep(attempt * 1000);

        continue;

      }

      return res;

    } catch (e) {

      if (attempt === maxRetries) {

        // ✅ TRUNCATE before logging

        const truncatedMsg = String(e.message || e).slice(0, 200);

        logError('14_Utils', `fetchWithRetry_ failed (truncated): ${truncatedMsg}`, e);

        throw e;

      }

    }

  }

}
Detection
bash

Copy
grep -A 20 "function fetchWithRetry_" src/**/*.gs | head -30

# Should NOT contain: getContentText() in the logError call
Verdict
✅ PASS if all logError in fetch paths truncate to 200 chars.
❌ FAIL if raw getContentText() is in the log.

10. Additional Security Checks (Beyond SEC-001→012)
10.1 Formula injection (P0)
Any cell write of a user-provided string must escape leading =, +, -, @.

js

Copy
function sanitizeForSheet_(value) {

  if (typeof value !== 'string') return value;

  return /^[=+\-@]/.test(value) ? "'" + value : value;

}
10.2 XSS in WebApp
The WebApp (22_WebApp.gs + .html files) must escape any user-provided string before rendering:

html

Copy

Preview
<!-- In Dashboard.html -->

<div class="data"><?= data.name ?>  <!-- ❌ if data.name contains HTML -->

<div class="data"><?!= HtmlService.createHtmlOutput(data.name).getContent() ?>  <!-- ❌ same -->
Use a JS-side escape:

html

Copy

Preview
<script>

  function escapeHtml(s) {

    return String(s).replace(/[&<>"']/g, m => ({

      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'

    }[m]));

  }

  document.getElementById('cell').textContent = data.name;  // safe

</script>
10.3 CSRF on WebApp actions
The 22c_WebAppActions.gs functions must verify the user via Session.getActiveUser() and re-check role. Don't trust client-side flags.

js

Copy
function applyDecisionFromWebApp(decisionData) {

  if (!isAuthorizedUser_()) {

    throw new Error('Unauthorized');

  }

  // Re-validate decisionData structure

  if (!decisionData.decision || !['CREATE_NEW','MERGE_TO_CANDIDATE','ESCALATE','IGNORE'].includes(decisionData.decision)) {

    throw new Error('Invalid decision');

  }

  // ... apply ...

}
11. Automated Bash Audit
bash

Copy
#!/bin/bash

# Run from repo root

set +e


echo "=== SEC-001: Hardcoded secrets ==="

grep -rnE "AIza[A-Za-z0-9_-]{35}|AKIA[0-9A-Z]{16}|password\s*=\s*['\"][^'\"]+['\"]" src/ appsscript.json .clasp.json 2>/dev/null && echo "❌ FAIL" || echo "✅ PASS"


echo "=== SEC-002: AuthZ on destructive ops (sample) ==="

for func in createPerson_ createPlace_ createGlobalAlias applySheetProtection_UI; do

  result=$(grep -A 5 "function $func" src/**/*.gs 2>/dev/null | grep -c "isAuthorizedUser_")

  if [[ $result -eq 0 ]]; then

    echo "❌ $func: missing isAuthorizedUser_"

  else

    echo "✅ $func"

  fi

done


echo "=== SEC-003/009: Cookie sanitization ==="

grep -q "sanitizeCookie_" src/**/*.gs 2>/dev/null && echo "✅ sanitizeCookie_ defined" || echo "❌ FAIL"


echo "=== SEC-004/010: PII masking ==="

grep -q "maskEmail_\|md5Hash_" src/**/*.gs 2>/dev/null && echo "✅ masking functions defined" || echo "❌ FAIL"


echo "=== SEC-005/011: Sheet protection count ==="

protected=$(grep -c "protect().setDescription" src/**/*.gs 2>/dev/null)

if [[ $protected -ge 8 ]]; then echo "✅ $protected protections"; else echo "⚠️ Only $protected protections"; fi


echo "=== SEC-006: API key in URL ==="

grep -rnE "UrlFetchApp\.fetch\([^)]*\?(api_?key|access_?token|key)=" src/**/*.gs 2>/dev/null && echo "❌ FAIL" || echo "✅ PASS"


echo "=== SEC-007: Reviewer email masking ==="

grep -q "maskReviewerEmail_" src/**/*.gs 2>/dev/null && echo "✅ PASS" || echo "❌ FAIL"


echo "=== SEC-008: OAuth scope count ==="

scopes=$(python3 -c "import json; print(len(json.load(open('appsscript.json'))['oauthScopes']))" 2>/dev/null)

if [[ $scopes -eq 6 ]]; then echo "✅ $scopes scopes"; else echo "⚠️ $scopes scopes (expected 6)"; fi


echo "=== SEC-012: Response body truncation ==="

grep -A 30 "function fetchWithRetry_" src/**/*.gs 2>/dev/null | grep -q "slice(0, 200)" && echo "✅ Truncation present" || echo "⚠️ Check fetchWithRetry_ manually"
12. Output Template (the security audit report)
markdown

Copy
# LMDS Security Audit — V6.0.046


**Date:** 2026-07-13

**Scope:** src/ + appsscript.json

**Auditor:** <name>


## Overall: ✅ PASS / ❌ FAIL


## SEC-001 to SEC-012


| ID | Severity | Status | Evidence | Fix |

|----|----------|--------|----------|-----|

| SEC-001 | 🔴 BLOCKING | ✅ PASS | No AIza* in src/ | — |

| SEC-002 | 🔴 BLOCKING | ✅ PASS | 13/13 destructive ops guarded | — |

| SEC-003 | 🟠 HIGH | ✅ PASS | sanitizeCookie_ used | — |

| SEC-004 | 🟠 HIGH | ✅ PASS | All logError use md5Hash_ | — |

| SEC-005 | 🟠 HIGH | ✅ PASS | 8 sheets protected | — |

| SEC-006 | 🟠 HIGH | ✅ PASS | All fetches use headers | — |

| SEC-007 | 🟡 MEDIUM | ✅ PASS | maskReviewerEmail_ used | — |

| SEC-008 | 🟡 MEDIUM | ✅ PASS | 6 OAuth scopes | — |

| SEC-009 | 🟡 MEDIUM | ✅ PASS | RFC 6265 regex | — |

| SEC-010 | 🟡 MEDIUM | ✅ PASS | All logs covered | — |

| SEC-011 | 🟡 MEDIUM | ✅ PASS | 8 sheets + Q_REVIEW | — |

| SEC-012 | 🟡 MEDIUM | ✅ PASS | 200-char truncation | — |


## Additional Checks


- [ ] Formula injection: PASS

- [ ] XSS in WebApp: PASS

- [ ] CSRF protection: PASS


## Risk Score: 0 (all 12 PASS)


## Required Follow-ups

- (none)


## Sign-off

- [ ] Security lead

- [ ] Tech lead
13. Integration with Other Skills

lmds-architect — load first.

lmds-code-reviewer — for Law 16 enforcement.

lmds-bug-hunter — for P0 critical patterns (overlaps with SEC-001, 002, 004, 006).

lmds-predeploy-checker — must pass before any production deploy.

lmds-cicd-pipeline — for the automated parts (Gitleaks = SEC-001, CodeQL = SEC-002/006).
