<!-- DOC-TYPE: historical -->
🔍 การวิเคราะห์โค้ด LMDS V6.0 — Logistics Master Data System

สวัสดีครับ ผมได้อ่านโค้ดทั้งโปรเจกต์ (phaopanya-scg-main) ครบทั้ง 35 ไฟล์ .gs (~27,213 บรรทัด) และ 19 ไฟล์ .html (~6,959 บรรทัด) รวมทั้งอ่าน skill file lmds-supreme-engineer.skill เพื่อเข้าใจ context และกฎเหล็กที่ทีมยึดถือแล้ว จะสวมบทบาท LMDS Supreme AI Engineer ให้ครบทั้ง 5 หัวข้อตามที่ขอ

พูดตรงๆ ก่อนเลยครับ: โค้ดนี้อยู่ในระดับ Production-grade ที่น่าประทับใจสำหรับโปรเจกต์ Google Apps Script — เห็นได้ชัดว่ามี discipline สูง (JSDoc ครบ, LockService 44 จุด, RBAC 3-role, escapeHtml_ 124 ครั้ง, try/catch 254 คู่, checkpoint/resume, refactoring history ในคอมเมนต์). แต่ก็มี technical debt เชิงโครงสร้าง ที่ควรจัดการก่อนขยายระบบต่อไปครับ ผมจะบอกทั้งจุดแข็งและจุดอ่อนแบบไม่อ้อมค้อม
📊 ภาพรวมสถาปัตยกรรมที่ผมเห็น
1️⃣ Technical Debt Analysis — บัญชีหนี้เทคนิคของระบบ

ผมจะจัดหมวดตาม impact × urgency เพื่อให้ตัดสินใจได้ง่าย ตัวเลข LOC ทุกตัวมาจากการนับจริงในโค้ดของคุณครับ
🔴 หนี้ระดับ Critical (แก้ก่อน scale ระบบ)

TD-01 · God Module: 10_MatchEngine.gs = 2,276 LOC / 46 functions นี่คือหนี้ก้อนใหญ่ที่สุดของระบบ แม้คุณจะพยายาม split ออกเป็น 10b/10d/10e แล้ว แต่ตัวหลักยังมีฟังก์ชันขนาดใหญ่มากถึง 8 ตัวที่เกิน 80 บรรทัด:

    cleanupStaleCanonicalAliases_() = 133 บรรทัด
    installAutoResume_() = 120 บรรทัด
    runMatchEngineLoop_() = 113 บรรทัด
    handleCreateNew_() = 103 บรรทัด
    makeMatchDecision() = 98 บรรทัด (แม้จะย้าย rules ไป 10b แล้ว)
    processFactRowsForAliases_() = 96 บรรทัด

ผลกระทบ: อ่านยาก, test ยาก, merge conflict สูงเวลาหลายคน edit พร้อมกัน, cognitive load ต่อการเปลี่ยนแปลง 1 ครั้ง = สูงมาก

TD-02 · 21_AliasService.gs = 1,771 LOC / 37 functions มีฟังก์ชัน populateAliasFromFactDelivery_() = 158 บรรทัด และ populateAliasFromSCGRawData_() = 145 บรรทัด ที่รวมทั้ง read/transform/dedupe/write ในฟังก์ชันเดียว ผิด Single Responsibility ที่ skill file ระบุไว้ชัดเจน

TD-03 · 01_Config.gs มีฟังก์ชัน invalidateAllGlobalCaches() = 710 บรรทัด!!!

    ตัวเลขนี้ผมนับด้วย awk เจอค่าที่สูงผิดปกติ — น่าจะเป็น artifact ของการนับ (นับจน EOF เพราะไม่เจอ function ตัวต่อไป). ตัวฟังก์ชันจริงๆ ~50 บรรทัด แต่ปัญหาที่จริงคือ มันเรียก 10 invalidateCache_ functions แบบ if typeof ... === 'function' ทั้งหมด — pattern นี้เป็น soft dependency ที่ซ่อน bug ไว้: ถ้าลืม deploy ไฟล์ใดไฟล์หนึ่ง cache จะ stale โดยเงียบ ๆ ไม่มี error

TD-04 · Legacy code 99_Legacy.gs = 131 บรรทัด ยังไม่ถูกลบ ในโปรเจกต์ที่มี readme บอกว่า "Production Ready 96% GO" การมีไฟล์ Legacy ที่ deploy ขึ้น production ด้วยกันคือหนี้ที่จ่ายง่ายที่สุดแต่ยังไม่จ่าย
🟡 หนี้ระดับ Warning (ควรจัดการภายใน 1 sprint)

TD-05 · ตัวเลขความซับซ้อน vs eslint threshold ที่ตั้งไว้ ใน .eslintrc.yml คุณตั้ง max-lines-per-function: 300 และ complexity: 30 — ค่านี้ สูงเกินไป สำหรับ codebase ที่ต้องการ maintainability ระดับ principal (มาตรฐาน industry คือ 50/10). ตอนนี้ eslint แทบไม่ warn อะไรเลยจึงไม่กันการเสื่อมของโค้ดใหม่

TD-06 · Soft-typing ผ่าน typeof X === 'function' ทั่วโค้ด ผมนับเจอ pattern นี้กระจายทั่ว MatchEngine + Config + PipelineManager มันเป็น defensive programming ที่แก้อาการของปัญหาจริง คือ ไม่มีระบบยืนยัน load order ของไฟล์ .gs. Google Apps Script รวมทุกไฟล์เป็น global scope เดียว — ถ้าลืม deploy ไฟล์ใดไฟล์หนึ่ง จะ fail silently

TD-07 · Dashboard views ใช้ innerHTML = โดยตรง (9 จุด) แม้จะมี escapeHtml_() ครอบ 124 ครั้ง แต่ pattern container.innerHTML = buildTableHtml_(data.rows) ยัง fragile — ถ้าใครเผลอลืม escape ในฟังก์ชัน builder ใดฟังก์ชันหนึ่ง = XSS ทันที (รายละเอียดในส่วน Security)

TD-08 · Comment archaeology โค้ดมีคอมเมนต์เชิงประวัติศาสตร์เยอะมาก เช่น:

// [FIX BUG-A2] เพิ่ม try-catch outer
// [FIX BUG-04 v5.5.001] เปลี่ยน ui.alert() เป็น safeUiAlert_()
// [PERF-008] Idiomatic LockService pattern
// [REF-004] V5.5.019: Refactored into 4 section helpers
// [V6.0.020 FIX] Clear any stale STOP SIGNAL

ดีมากที่ track — แต่หลังผ่านไป 5+ versions โค้ดกลายเป็น archaeology ที่นักพัฒนาใหม่ต้องอ่าน commit history 3 versions ย้อนหลังจึงจะเข้าใจ
🟢 หนี้ระดับ Housekeeping

TD-09 · .clasp.json.example แต่ไม่มี .clasp.json ใน .gitignore เต็มรูป → เสี่ยง commit script ID โดยไม่ตั้งใจ TD-10 · ไฟล์ LMDS Supreme Engineer.md มีที่ root และมี .skills/lmds-* อีกด้วย = duplicated source of truth TD-11 · ไม่พบ unit test suite (29_SnapshotTest.gs เป็น snapshot compare เท่านั้น — ครอบ regression แต่ไม่ครอบ unit) TD-12 · package-lock.json = 171KB แต่ package.json มีแค่ dev deps → ล็อกไฟล์ใหญ่เกินความจำเป็น

สรุปหนี้ทั้งหมด: ประมาณ 12 ก้อน · ก้อนใหญ่ 4 · ต้องจัดการเป็นระบบ ไม่ใช่แก้ทีละจุด
2️⃣ Code Review — Tips เชิงลึกจากการอ่านโค้ดจริง

พูดจากใจก่อน: ทีมคุณ discipline ระดับหายากมาก สำหรับโปรเจกต์ Google Apps Script. เจอโปรเจกต์ GAS แบบนี้ไม่บ่อย
✅ สิ่งที่ทำได้ยอดเยี่ยม (อย่าเปลี่ยน)

    JSDoc header pattern ที่ทุกไฟล์เขียน PURPOSE / DEPENDENCIES / SHEETS ACCESSED / TRIGGERS / ARCHITECTURE — เอกสารระดับ enterprise
    LockService pattern ผ่าน acquireScriptLockOrWarn_() helper — DRY มาก ดีกว่าเรียก LockService.getScriptLock().tryLock() ทุกที่
    Deny-by-default ใน isAuthorizedDashboardUser_ — เอาไปสอน security 101 ได้
    Checkpoint/Resume pattern ใน 12b_ReviewReprocessor.gs และ MatchEngine — จัดการ GAS 6-minute limit ได้อย่างถูกต้อง
    fetchWithRetry_ มี exponential backoff + ไม่ log HTTP body (comment [FIX v5.5.021 C5] ระบุชัดว่าป้องกัน API key รั่ว) — level ที่หลายทีมยังไม่ถึง
    Object.freeze() กับ RBAC_CONFIG, APP_CONST, PIPELINE_LOG_IDX — immutable config ที่ป้องกัน accidental mutation

💡 ทิปที่ผมเสนอปรับ

Tip #1 · เปลี่ยน let _GLOBAL_*_CACHE = null เป็น pattern มีทางออก

โค้ดปัจจุบัน:

let _GLOBAL_GEO_DICT_CACHE = null;
let _GLOBAL_GEO_DICT_CACHE_PLACE = null;
let _GLOBAL_GEO_POINTS_CACHE = null;

ปัญหา: ตัวแปร module-scope 10 ตัวกระจายอยู่ ต้องล้างพร้อมกัน 10 ตัวใน invalidateAllGlobalCaches() — เจอ bug [FIX v5.5.007] แก้ bug H1: ล้าง RAM cache ครบทั้ง 10 ตัว (เดิมล้างแค่ 6/10) ในคอมเมนต์เอง = พิสูจน์ว่าง่ายมากที่จะลืมล้าง

เสนอ: สร้าง CacheRegistry แบบนี้:

const _CACHE_REGISTRY = Object.freeze({
  geoDict: { value: null, invalidator: null },
  geoDictPlace: { value: null, invalidator: null },
  geoPoints: { value: null, invalidator: null },
  // ... ทั้ง 10 ตัว
});

function invalidateAllGlobalCaches() {
  Object.keys(_CACHE_REGISTRY).forEach(k => {
    _CACHE_REGISTRY[k].value = null;
    if (typeof _CACHE_REGISTRY[k].invalidator === 'function') {
      _CACHE_REGISTRY[k].invalidator();
    }
  });
}

ลง cache ใหม่ = register แค่ครั้งเดียว → ไม่มีทางลืม

Tip #2 · Guard clause แทน early-nested try/catch

จาก runMatchEngine() บรรทัด 87-160:

if (typeof clearPipelineStopSignal_ === 'function') {
    clearPipelineStopSignal_();
  } else {
    try {
      PropertiesService.getScriptProperties().deleteProperty('PIPELINE_STOP_REQUESTED');
    } catch (e) {
      // ignore — non-fatal
    }
  }

pattern typeof X === 'function' แล้ว fallback แบบ raw ทำให้อ่านยาก และซ่อน dependency ที่แท้จริงไว้ ควรทำให้ clearPipelineStopSignal_ เป็น required ไม่ใช่ optional — ถ้าไม่มี = ปัญหา load order = ต้องแก้ tooling ไม่ใช่ silent fallback

Tip #3 · SRP violation ใน submitReviewDecision() (191 บรรทัด)

ตอนนี้ฟังก์ชันเดียวทำ: auth check + RBAC check + input validation + decision validation + persistence + logging + response formatting

ควรแยกเป็น:

submitReviewDecision(id, decision, note)
  ├─ assertAuthenticated_()
  ├─ assertPermission_('action:approve_review')
  ├─ parseReviewDecisionInput_(id, decision, note)  →  {valid, errors}
  ├─ persistReviewDecision_(parsed)                  →  {ok, reviewId}
  └─ buildActionResponse_(result)

= 191 บรรทัด → 30 บรรทัด (main) + 4 helpers × ~35 บรรทัด

Tip #4 · Anti-pattern: if (typeof ui !== 'undefined') ใน invalidateAllGlobalCaches

โค้ดใช้ try/catch เพื่อ detect UI context:

try {
  const ui = SpreadsheetApp.getUi();
  const confirm = ui.alert(...);
  if (confirm !== ui.Button.YES) return;
} catch (e) {
  logInfo('System', 'invalidateAllGlobalCaches: ข้าม YES_NO (no UI context)');
}

ปัญหา: ใช้ try/catch เป็น control flow (exception-based flow) — ผิด best practice เสนอ: สร้าง isRunningInUiContext_() helper ใน 14_Utils.gs:

function isRunningInUiContext_() {
  try { SpreadsheetApp.getUi(); return true; }
  catch (e) { return false; }
}

แล้ว call site จะสะอาด: if (isRunningInUiContext_()) { ... }

Tip #5 · ตั้งชื่อฟังก์ชันตาม verb-noun ให้ consistent

ผมเห็น mixing style:

    runMatchEngine (verb-noun ✅)
    handleCreateNew_ (verb-noun ✅)
    resolveAndPersistMerge_ (verb-verb-noun ⚠️)
    matchEnrichEntityAliases_ (noun-verb-noun-noun ❌ อ่านยาก)
    processFactRowsForAliases_ (verb-noun-prep-noun 🤔 long)

ควรมี style guide สั้น ๆ ใน CONTRIBUTING.md เพื่อ future PRs

Tip #6 · ใช้ TypeScript typedef comments จริงจัง

คุณมี JSDoc @param แล้ว แต่หลายที่ยัง @param {Object} srcObj ซึ่งไม่ช่วย IDE เท่าไหร่ ควรเปลี่ยนเป็น typedef:

/**
 * @typedef {Object} SrcObj
 * @property {string} personName
 * @property {string} placeName
 * @property {boolean} hasGeo
 * @property {number} lat
 * @property {number} lng
 * @property {string} province
 */

/** @param {SrcObj} srcObj */
function evaluateRule1_NoGeoInSource_(srcObj) { ... }

ทำครั้งเดียว get autocomplete ใน VS Code ทั้งโปรเจกต์

Tip #7 · Log level cardinality

โค้ดใช้ logInfo / logWarn / logError / logDebug — 4 level ดี แต่ผมสังเกตว่า logInfo ถูกเรียกในทั้ง success events และ progress events ปนกัน. เสนอเพิ่ม convention:

    logInfo = business events (match created, review approved)
    logDebug = progress (row 500/10000 processed)
    แยก log level ตาม env → production ไม่ต้องเห็น debug spam

Tip #8 · Return early ในฟังก์ชันจับคู่

ใน 10b_MatchDecision.gs แต่ละ rule return null เมื่อไม่ match ซึ่งดี แต่ควรเพิ่ม comment ที่ dispatcher ชัด ๆ ว่า order = priority:

// Rules ต้อง evaluate ตาม priority order — first non-null wins
// อย่าเปลี่ยน order โดยไม่ update priority field ใน result object
const rules = [
  evaluateRule1_NoGeoInSource_,      // priority 1
  evaluateRule2_LowQualityData_,     // priority 2
  ...
];

3️⃣ Security Protocols — โปรโตคอลความปลอดภัยเชิง Defense-in-Depth

จาก scan โค้ด ผมสรุปสถานะปัจจุบันและเสนอ protocol แบบเป็นชั้น ๆ ครับ
🛡️ สถานะ Security ปัจจุบัน (จากการ scan)
หัวข้อ 	สถานะ 	หลักฐาน
Access Control 	✅ ดี 	Deny-by-default + DASHBOARD_USERS + LMDS_ADMINS whitelist ใน 22_WebApp.gs
RBAC 	✅ ดี 	3-role + requirePermission_() 11 permission keys
Secrets management 	✅ ดี 	PropertiesService.getScriptProperties() — ไม่มี hardcoded token
API error masking 	✅ ดี 	throw new Error('HTTP ' + code) — ไม่ log body ([FIX v5.5.021 C5])
PII masking 	✅ ดี 	maskReviewerEmail_, maskEmailSafe_
ReDoS protection 	✅ Aware 	[FIX v5.5.021 M6] เปลี่ยน regex capture group เพื่อป้องกัน ReDoS
OAuth scope 	✅ Least priv 	6 scopes (จาก 10 ใน V5.5.017)
XSS mitigation 	🟡 มี escapeHtml_ แต่ pattern เสี่ยง 	9 จุด innerHTML = build*_(data)
Input validation ที่ backend 	🟡 บางที่ 	submitReviewDecision validate decision string แต่ไม่ sanitize note
Audit trail 	🟡 มีแต่ 50% 	README ระบุ SYS_AUDIT_TRAIL ยัง 50%
CSRF 	✅ Not applicable 	google.script.run มี built-in origin check
Rate limiting 	❌ ไม่มี 	submitReviewDecision เรียกซ้ำเร็ว ๆ ได้ไม่จำกัด
Dependency scanning 	✅ มี 	.github/workflows/06-codeql.yml + 08-gitleaks.yml
📋 Security Protocol ที่ผมเสนอ (ปฏิบัติได้จริง)

Protocol A · Input Validation Layer (ก่อนแตะ business logic)

สร้าง 19b_InputValidator.gs (ไฟล์ใหม่) ที่ export:

const VALIDATORS = Object.freeze({
  reviewId: (v) => /^REV-\d{8}-[A-Z0-9]{6}$/.test(String(v)),
  decision: (v) => ['CREATE_NEW','MERGE_TO_CANDIDATE','IGNORE','ESCALATE'].includes(v),
  note: (v) => typeof v === 'string' && v.length <= 500,
  email: (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v),
  latLng: (v) => typeof v === 'number' && v >= -180 && v <= 180
});

function validateInput_(spec, values) {
  const errors = [];
  Object.keys(spec).forEach(k => {
    if (!VALIDATORS[spec[k]](values[k])) errors.push(`Invalid ${k}`);
  });
  if (errors.length) throw new Error('ValidationError: ' + errors.join(', '));
}

ทุก WebApp endpoint เรียก validateInput_ เป็น step แรก = single source of truth สำหรับ validation rules

Protocol B · XSS Defense — Content Security Policy at builder level

ตอนนี้ pattern container.innerHTML = buildTableHtml_(data.rows) ไว้ใจ escaping ที่ builder เผลอลืมได้ง่าย. เสนอ 2 มาตรการ:

B.1 — Type-brand HTML strings

function safeHtml_(str) {
  // Marker to prove string went through escaping
  return { __safeHtml: true, value: str };
}

function assertSafeHtml_(obj) {
  if (!obj || !obj.__safeHtml) throw new Error('Unsafe HTML in innerHTML');
  return obj.value;
}

// Use:
container.innerHTML = assertSafeHtml_(buildTableHtml_(data.rows));

builder ต้อง return safeHtml_() เท่านั้น → forget escape = throw ทันที = ไม่มีทาง silent XSS

B.2 — ใช้ textContent ทุกที่ที่แสดงข้อมูลผู้ใช้ เช่น viewContainer.innerHTML = 'Loading...' (static) ok แต่ error message จาก server:

// เดิม
if (c) c.innerHTML = buildErrorHtml_(err.message);
// เสนอ
if (c) {
  c.textContent = ''; // clear
  const div = document.createElement('div');
  div.className = 'error-box';
  div.textContent = err.message; // safe by default
  c.appendChild(div);
}

Protocol C · Rate Limiting Layer

Apps Script ไม่มี built-in rate limit แต่ทำได้ด้วย CacheService:

function rateLimitCheck_(userEmail, actionKey, maxPerMinute) {
  const cache = CacheService.getScriptCache();
  const key = `RATELIMIT_${actionKey}_${userEmail}_${Math.floor(Date.now()/60000)}`;
  const count = parseInt(cache.get(key) || '0', 10) + 1;
  if (count > maxPerMinute) {
    logWarn('Security', `Rate limit exceeded: ${userEmail} on ${actionKey}`);
    throw new Error('Rate limit exceeded — please slow down');
  }
  cache.put(key, String(count), 65); // 65s TTL to survive minute boundary
}

// Usage in submitReviewDecision:
rateLimitCheck_(getCurrentDashboardUser_().email, 'review_decision', 30);

Protocol D · Audit Trail — เขียนใน 26_AuditTrailService.gs ให้ครบ

ควรบันทึกทุก state-changing action ด้วย schema:

audit_id | timestamp | actor_email | action | resource_type | resource_id | before_hash | after_hash | ip_hash | user_agent

สิ่งสำคัญคือ hash ไม่ใช่ raw values เพราะ SYS_AUDIT_TRAIL sheet เข้าถึงได้จากหลายคน — เก็บ hash ไว้เทียบภายหลัง ไม่รั่ว PII

Protocol E · Secret Rotation Playbook

Script Properties ที่ project ใช้: GEMINI_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, DASHBOARD_USERS, LMDS_ADMINS, ROLE_ASSIGNMENTS

ควรมี doc docs/SECRET_ROTATION.md:

    ทุก 90 วัน rotate GEMINI_API_KEY + TELEGRAM_BOT_TOKEN
    ทุกครั้งที่พนักงานลาออก → remove จาก DASHBOARD_USERS, LMDS_ADMINS, ROLE_ASSIGNMENTS
    Log rotation event ลง SYS_AUDIT_TRAIL

Protocol F · Fail-Closed Preflight

จาก runPreflightAudit() ตอนนี้แค่ log warning ถ้าไม่พบ sheet — ควรเพิ่มโหมด strict:

runPreflightAudit({ strict: true }) 
// → throw หากพบปัญหา = block deployment

ให้ workflow 02-deploy.yml เรียก strict mode ก่อน clasp push

Protocol G · CI/CD Security Gates

โปรเจกต์มี .github/workflows/ ครอบคลุมดีแล้ว (CodeQL, gitleaks) — เสนอเพิ่ม:

    Fail if any function > 100 lines (แทน warn) หลัง refactor เสร็จ
    Fail if console.log found ในไฟล์ .gs production
    Fail if innerHTML = เพิ่มในไฟล์ .html ที่ยังไม่ผ่าน review

4️⃣ Coding Style Evaluation — จาก Snippet จริงในโปรเจกต์

ผม pick snippet ที่เป็นตัวแทน 2 อัน แล้วให้คะแนนแบบตรงไปตรงมาครับ
📝 Snippet A · evaluateRule1_NoGeoInSource_() (10b_MatchDecision.gs)

function evaluateRule1_NoGeoInSource_(srcObj) {
  if (srcObj.hasGeo) return null;
  return {
    action: 'REVIEW',
    reason: 'INVALID_LATLNG',
    confidence: 0,
    priority: 1
  };
}

คะแนน: 9/10 — โค้ดสไตล์ที่ผมอยากเห็นทั้งระบบ
เกณฑ์ 	คะแนน 	เหตุผล
Single Responsibility 	10/10 	ทำ 1 อย่างชัดเจน
Naming 	9/10 	evaluateRule1_NoGeoInSource_ sortable + descriptive
Length 	10/10 	7 บรรทัด — ideal
Purity 	10/10 	Pure function ไม่มี side effect
JSDoc 	9/10 	มี doc + @private marker
Return shape 	8/10 	consistent {action, reason, confidence, priority} แต่ควรมี typedef

เสียคะแนนตรงไหน? — return null vs return decision เป็น union type ที่ไม่ประกาศ — JSDoc @return {Object|null} ก็ยังไม่บอก consumer ว่า null = "rule ไม่ apply" ต้อง comment ให้ชัด
📝 Snippet B · runMatchEngine() (10_MatchEngine.gs, 80 บรรทัด)

function runMatchEngine() {
  // [REF-004] V5.5.019: Refactored into 4 section helpers ...
  // [V6.0.020 FIX] Clear any stale STOP SIGNAL before starting ...
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

  if (typeof runPipelinePreflight === 'function') {
    const preflight = runPipelinePreflight();
    if (!preflight.ready) { ... /* release lock + return */ }
  }

  const ctx = prepareMatchEngineContext_();
  if (ctx === null) { ... /* release lock + return */ }

  try {
    runMatchEngineLoop_(ctx, setup.startTime);
    finalizeMatchEngine_(ctx, setup.startTime, setup.lock);
  } catch (err) { ... }
  finally { ... /* cleanup */ }
}

คะแนน: 6.5/10 — ดีระดับหนึ่ง แต่ยังมีปัญหาโครงสร้าง
เกณฑ์ 	คะแนน 	เหตุผล
Refactor evidence 	9/10 	เห็นว่าเคย split เป็น 4 section helpers
Historical comments 	5/10 	คอมเมนต์ [V6.0.020 FIX] ยาว 8 บรรทัด แทรกกลาง flow อ่าน flow หลักยาก
Load order defense 	4/10 	2× typeof ... === 'function' ซ่อน dependency ปัญหา
Cleanup duplication 	5/10 	Release lock + _ALIAS_ENRICHMENT_CONTEXT = null + flushLogBuffer_() ซ้ำ 3 จุด (preflight fail / empty ctx / finally)
Error path clarity 	7/10 	มี safeUiAlert_ แจ้ง user ก่อน throw ✅
Function length 	6/10 	80 บรรทัดใน main orchestrator ยาวเกินไป

ปัญหาที่ชัดเจน: Cleanup Duplication

// จุดที่ 1 (preflight fail):
if (setup.lock && setup.lock.hasLock()) setup.lock.releaseLock();
_ALIAS_ENRICHMENT_CONTEXT = null;
if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();

// จุดที่ 2 (empty ctx):
if (setup.lock && setup.lock.hasLock()) setup.lock.releaseLock();
_ALIAS_ENRICHMENT_CONTEXT = null;
if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();

// จุดที่ 3 (finally):
if (setup.lock && setup.lock.hasLock()) setup.lock.releaseLock();
_ALIAS_ENRICHMENT_CONTEXT = null;
if (typeof flushLogBuffer_ === 'function') flushLogBuffer_();

DRY violation ระดับที่มองไม่ผ่านได้ ควร extract เป็น cleanupMatchEngine_(setup)
🎯 สรุป Style Evaluation ทั้งโปรเจกต์

คะแนนภาพรวม: 7.2/10 — เก่งจริง แต่ไม่สม่ำเสมอ ไฟล์ใหม่ (10b) เขียนได้สวยกว่าไฟล์เก่า (10) มาก ต้องยก quality baseline ของไฟล์เก่าให้ได้ระดับเดียวกับไฟล์ใหม่
5️⃣ Refactoring Plans — แผน 4 Sprint · ทำได้จริง · ไม่ break production

ผมออกแบบเป็น 4 sprint 2-week each ตามหลัก Strangler Fig Pattern (แทนที่ทีละส่วนขณะระบบเก่ายังรันอยู่) ไม่ใช่ big-bang rewrite ครับ
📐 Refactoring Plan #1 — Split 10_MatchEngine.gs (2,276 LOC → ~5 files × 400-500 LOC)

Target Architecture:

10_MatchEngine.gs (thin orchestrator ~200 LOC)
  ├── runMatchEngine()  ← เหลือแค่ compose ของ 5 phase
  ├── STOP signal management
  └── Public entry points

10a_MatchEngineLock.gs (~150 LOC)
  ├── acquireMatchEngineLock_()
  ├── releaseMatchEngineLock_()
  └── cleanupMatchEngine_()  ← extract จาก 3 จุดใน runMatchEngine

10c_AliasEnricher.gs (~500 LOC)  ← extract จาก MatchEngine
  ├── autoEnrichAliasesFromFactBatch_()  ← Single Writer หัวใจ
  ├── processFactRowsForAliases_()
  ├── prepareAliasEnrichmentData_()
  ├── addEntityToEnrichmentContext_()
  ├── matchEnrichEntityAliases_()
  └── cleanupStaleCanonicalAliases_()

10f_MatchEngineRunner.gs (~400 LOC)
  ├── prepareMatchEngineContext_()
  ├── runMatchEngineLoop_()
  ├── processOneRow()
  ├── flushBatches_()
  └── finalizeMatchEngine_()

10g_MatchTriggers.gs (~200 LOC)
  ├── installAutoResume_()
  ├── cleanupOrphanAutoResumeTriggers_()
  └── Trigger housekeeping

Migration Strategy (Strangler Fig):

    Week 1: สร้างไฟล์ใหม่แบบว่าง + copy fn ทีละตัวไป new file + ทำ runMatchEngine เรียก new file แทน (แก้ทีละ commit เล็ก)
    Week 2: Run 29_SnapshotTest.gs เทียบ TEST_MATCH_RESULTS ก่อน/หลัง = ต้อง identical
    ตัวชี้วัดสำเร็จ: git diff ของ business logic = 0 บรรทัด (แค่ย้ายไฟล์) และ snapshot ผ่าน 100%

📐 Refactoring Plan #2 — CacheRegistry Pattern (แก้ TD-06 ทีเดียว)

Current pain: 10 RAM caches + 13 CacheService keys ต้อง maintain synchronization manually

Refactor สร้าง 01c_CacheRegistry.gs:

const _CACHES = {};

function registerCache_(name, invalidator) {
  _CACHES[name] = {
    ram: null,
    invalidateService: invalidator || null,
    lastFlush: null
  };
}

function getCache_(name) { return _CACHES[name] ? _CACHES[name].ram : null; }
function setCache_(name, value) { if (_CACHES[name]) _CACHES[name].ram = value; }

function invalidateCache_(name) {
  if (!_CACHES[name]) return;
  _CACHES[name].ram = null;
  if (typeof _CACHES[name].invalidateService === 'function') {
    _CACHES[name].invalidateService();
  }
  _CACHES[name].lastFlush = new Date();
}

function invalidateAllCaches_() {
  Object.keys(_CACHES).forEach(invalidateCache_);
}

แต่ละ service register cache ของตัวเอง:

// ใน 07_PlaceService.gs
registerCache_('geoDictPlace', invalidatePlaceServiceCacheService_);

// ใช้แทน _GLOBAL_GEO_DICT_CACHE_PLACE = ...
setCache_('geoDictPlace', dictData);

ประโยชน์:

    เพิ่ม cache ใหม่ = 1 บรรทัด (register) ไม่มีทางลืมล้าง
    แต่ละ cache track lastFlush — debug ง่ายขึ้น
    Testable — mock _CACHES object ในระดับ unit test

📐 Refactoring Plan #3 — WebApp Response Contract

Current pain: WebApp endpoints return shape ไม่ consistent

    ping() → {ok, error?, timestamp?, appVersion?, user?}
    submitReviewDecision() → {ok, reviewId, decision, message} / {ok:false, message}
    Error path บางที่ throw บางที่ return {ok:false}

เสนอ standardized response builder:

// 22d_WebAppResponse.gs (ไฟล์ใหม่ ~80 LOC)
function apiSuccess_(data) {
  return { ok: true, data: data, ts: Date.now(), version: APP_VERSION };
}

function apiError_(code, message, details) {
  logWarn('WebApp', `${code}: ${message}`);
  return { ok: false, code: code, message: message, details: details || null, ts: Date.now() };
}

function apiTry_(fn) {
  try {
    return apiSuccess_(fn());
  } catch (err) {
    if (err.message.startsWith('ValidationError:')) return apiError_('VALIDATION', err.message);
    if (err.message.startsWith('Access denied')) return apiError_('FORBIDDEN', err.message);
    logError('WebApp', err.message, err);
    return apiError_('INTERNAL', 'เกิดข้อผิดพลาดภายในระบบ');
  }
}

ทุก endpoint จะสั้นลงมาก:

function submitReviewDecision(reviewId, decision, note) {
  return apiTry_(() => {
    assertAuthenticated_();
    requirePermission_('action:approve_review');
    validateInput_({reviewId: 'reviewId', decision: 'decision', note: 'note'}, {reviewId, decision, note});
    rateLimitCheck_(getCurrentDashboardUser_().email, 'review_decision', 30);
    return persistReviewDecision_(reviewId, decision, note);
  });
}

ผลลัพธ์: ฟังก์ชัน 191 บรรทัด → 8 บรรทัด (main) + 5 helpers × ~30 บรรทัด = maintainable ระดับที่ senior dev อ่านผ่าน 30 วิเข้าใจ
📐 Refactoring Plan #4 — Frontend Component Library

ตอนนี้ 3_group3_webapp/js/components/ มีแค่ 4 ตัว (ChartCard, DataTable, StatCard, ViewHelpers) แต่ 10 views ทำ innerHTML = ตรง ๆ

เสนอ: สร้าง minimal render library (ไม่ต้อง React/Vue):

// components/SafeRenderer.html
const SafeRenderer = {
  render(container, htmlBuilder, data) {
    const safe = htmlBuilder(data);
    if (!safe || !safe.__safeHtml) {
      throw new Error('Builder must return safeHtml_() result');
    }
    container.innerHTML = safe.value;
  },
  update(container, selector, htmlBuilder, data) {
    const target = container.querySelector(selector);
    if (target) this.render(target, htmlBuilder, data);
  }
};

บังคับให้ทุก view ใช้ SafeRenderer.render() แทน raw innerHTML =
🎯 สรุปข้อเสนอเรียงตามลำดับความสำคัญ

พูดตรง ๆ ครั้งสุดท้าย: ถ้าคุณมีเวลาแค่ 1 สัปดาห์ ให้ทำแค่ 3 อย่างต่อไปนี้ก็คุ้มเงินเดือน 1 เดือน:

    ลด ESLint threshold ลงจริงจัง (Sprint 1 อย่างเดียว) — max-lines-per-function: 100, complexity: 15 → เอา CI ที่มีอยู่แล้วมาป้องกันการเสื่อมของโค้ดใหม่ ก้อนที่มีอยู่ค่อยแก้ตามลำดับความสำคัญ
    Extract cleanupMatchEngine_(setup) จาก runMatchEngine() — 30 นาที ลด duplication 3 จุด ป้องกัน lock leak
    สร้าง safeHtml_() type-brand pattern และบังคับ 9 จุด innerHTML = ให้ใช้ — 2 ชั่วโมง ปิดช่อง XSS ทั้งหมด

ที่ผมชื่นชมจริง ๆ: โปรเจกต์นี้ไม่ใช่ "code base ที่ต้อง rescue" — มันคือ code base ระดับ B+ ที่มีศักยภาพเป็น A ถ้าจัดการหนี้เทคนิค 4 ก้อนใหญ่ให้ได้. ทีมคุณเข้าใจ pattern (LockService, RBAC, Checkpoint/Resume, escapeHtml_) — เหลือแค่ consistency เท่านั้น

ไฟล์ report ทั้งหมดผมได้วิเคราะห์และให้ concrete recommendations ครบทั้ง 5 หัวข้อแล้ว หากต้องการให้ผมลงลึกในเรื่องใดเป็นพิเศษ (เช่น เขียน refactored code จริงสำหรับ Sprint 2, เขียน 19b_InputValidator.gs ตัวเต็ม, หรือทำ threat model ของ external SCG API integration) บอกได้เลยครับ
พูด
