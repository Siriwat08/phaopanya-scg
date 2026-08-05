<!-- DOC-TYPE: historical -->

# Agent: Agent 1 (Static)

**Date:** 2026-07-26T15:31:53Z
**Repo:** /home/user/webapp/audit/repo-git

## Raw output from check scripts

📋 ST-001: GS file header complete (VERSION/FILE/PURPOSE/CHANGELOG/DEPENDENCIES)
✅ All .gs files have complete header

📋 ST-002: Load order prefix (Law 14)
⚠️ src/3_group3_webapp/Index.html — bad filename format
⚠️ src/3_group3_webapp/css/Styles.html — bad filename format
⚠️ src/3_group3_webapp/js/Api.html — bad filename format
⚠️ src/3_group3_webapp/js/App.html — bad filename format
⚠️ src/3_group3_webapp/js/Auth.html — bad filename format
⚠️ src/3_group3_webapp/js/components/ChartCard.html — bad filename format
⚠️ src/3_group3_webapp/js/components/DataTable.html — bad filename format
⚠️ src/3_group3_webapp/js/components/StatCard.html — bad filename format
⚠️ src/3_group3_webapp/js/components/ViewHelpers.html — bad filename format
⚠️ src/3_group3_webapp/views/Dashboard.html — bad filename format
⚠️ src/3_group3_webapp/views/FactDelivery.html — bad filename format
⚠️ src/3_group3_webapp/views/LiveFeed.html — bad filename format
⚠️ src/3_group3_webapp/views/MapAnalytics.html — bad filename format
⚠️ src/3_group3_webapp/views/MatchEngine.html — bad filename format
⚠️ src/3_group3_webapp/views/MobileActions.html — bad filename format
⚠️ src/3_group3_webapp/views/QReview.html — bad filename format
⚠️ src/3_group3_webapp/views/Search.html — bad filename format
⚠️ src/3_group3_webapp/views/SourceSheet.html — bad filename format
⚠️ src/3_group3_webapp/views/Unauthorized.html — bad filename format
⚠️ src/O_core_system/99_Legacy.gs — bad filename format

💡 Fix: Rename to NN_Name.gs (NN = load order 00-29)

📋 ST-003: ESLint passes with 0 errors
ℹ️ No node_modules — skipping (run npm install first)

📋 ST-004: Prettier formatting
ℹ️ No package.json/node_modules — skipping

📋 ST-005: No var keyword (Law 1)
✅ No var declarations found

📋 ST-006: No magic column index (Law 3)
⚠️ Found 2 potential magic index usage(s) (col ≥ 2):
/home/user/webapp/audit/repo-git/src/O_core_system/03_SetupSheets.gs:525: const row1Values = sheet.getRange(1, 2, 1, Math.max(0, lastCol - 1)).getValues()[0];
/home/user/webapp/audit/repo-git/src/O_core_system/14_Utils.gs:740: sheet.getRange(1, 2, lastRow, 1).clearContent();

💡 Fix: Define column index constant in 01_Config.gs, e.g. PERSON_NAME_IDX = 5
ℹ️ Review each — some may be dynamic (function calls, vars)

📋 ST-007: Function name uniqueness (Law 8)
✅ All public function names are unique

📋 ST-008: Function length ≤ 100 lines (Law 2)
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/05_NormalizeService.gs:233:114: function normalizePersonNameFull(rawName) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/07_PlaceService.gs:732:112: function createPlace(normResult, province, district, subDistrict, postcode, reverseGeocodeAddress) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/10_MatchEngine.gs:226:104: function runMatchEngineLoop_(ctx, startTime) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/10d_MatchTestHarness.gs:58:214: function runTestMatchDryRun_(maxRows, forceAllRows) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/10e_MatchResolvePersist.gs:126:159: function resolveAndPersistMerge_(srcObj, candidates, optReviewId) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/10f_MatchAliasEnrichment.gs:518:124: function cleanupStaleCanonicalAliases_(newGlobalAliasRows, context) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/10h_MatchAutoResume.gs:73:112: function installAutoResume_(funcName) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/16_GeoDictionaryBuilder.gs:75:156: function buildGeoDictionary() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/20_ThGeoService.gs:136:107: function populateGeoMetadata() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/21_AliasService.gs:106:110: function createGlobalAlias(masterUuid, variantName, entityType, confidence, source, optVerifiedBy, optReviewId) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/21_AliasService.gs:245:102: function backfillAliasAuditFields() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/21_AliasService.gs:821:102: function MIGRATION_HybridAliasSystem() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/21_AliasService.gs:1339:132: function populateAliasFromSCGRawData_() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/1_group1_master_db/21_AliasService.gs:1484:143: function populateAliasFromFactDelivery_() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/2_group2_daily_ops/12_ReviewService.gs:204:122: function applyAllPendingDecisions() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/2_group2_daily_ops/12b_ReviewReprocessor.gs:282:113: function reprocProcessAllRows_(ctx, startTime, timeLimit) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/2_group2_daily_ops/12b_ReviewReprocessor.gs:640:108: function reprocBatchWriteAndReport_(ctx, stats, startTime) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/2_group2_daily_ops/17_SearchService.gs:181:136: function selectBestDestByAddress_(dests, rawAddress) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/2_group2_daily_ops/18_ServiceSCG.gs:1111:133: function safeResetTransactional_UI() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/4_group4_pipeline_mgr/24_PipelineManager.gs:568:198: function runPipelineBatch() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/4_group4_pipeline_mgr/24_PipelineManager.gs:1126:151: function runPipelinePreflight(opts) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/4_group4_pipeline_mgr/24_PipelineManager.gs:1428:107: function sendPipelineAlert_(message, severity) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/00_App.gs:58:114: function onOpen(e) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/00_App.gs:840:127: function cleanupAutoResumeTriggers_UI() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/00_App.gs:1458:116: function analyzeRule5PlaceOnlyImpact_UI() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/14_Utils.gs:1078:160: function saveChunkedCache_(cache, keyPrefix, data, optChunkSizeKB) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/19_Hardening.gs:953:102: function validateInput_(input, schema) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/22b_WebAppViews.gs:389:156: function getFactDeliveryPage(offset, limit, filter) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/22b_WebAppViews.gs:559:118: function getQReviewPage(offset, limit, statusFilter) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/22b_WebAppViews.gs:692:128: function getMatchEngineMetrics() {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/22b_WebAppViews.gs:830:154: function getSourcePage(offset, limit, filter) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/22c_WebAppActions.gs:87:195: function submitReviewDecision(reviewId, decision, note) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/22c_WebAppActions.gs:294:216: function submitBulkReviewDecisions(decisions) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/22c_WebAppActions.gs:524:212: function getReviewDetail(reviewId) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/22c_WebAppActions.gs:777:184: function searchLocations(query, limit) {
^ function > 100 lines, split per SRP
⚠️ /home/user/webapp/audit/repo-git/src/O_core_system/29_SnapshotTest.gs:105:139: function snapshotCompare_() {
^ function > 100 lines, split per SRP
📊 Files checked: 39
📊 Functions > 100 lines: 36

💡 Fix: Split long functions per Single Responsibility Principle
ℹ️ Use lmds-refactor-advisor to plan split

📋 ST-009: No cross-file globals (Law 9)
⚠️ src/1_group1_master_db/06_PersonService.gs:42 — top-level let/var: 42:let _PERSON_NOTE_INVERTED_INDEX = null;
⚠️ src/1_group1_master_db/06_PersonService.gs:46 — top-level let/var: 46:let _PERSON_ALIAS_INVERTED_INDEX = null;
⚠️ src/1_group1_master_db/07_PlaceService.gs:48 — top-level let/var: 48:let _PLACE_ALIAS_INVERTED_INDEX = null;
⚠️ src/1_group1_master_db/08_GeoService.gs:54 — top-level let/var: 54:let _GEO_CACHE_DIRTY = false;
⚠️ src/1_group1_master_db/10b_MatchDecision.gs:463 — top-level let/var: 463:let _CANDIDATE_COORDS_CACHE_ = null;
⚠️ src/1_group1_master_db/10f_MatchAliasEnrichment.gs:45 — top-level let/var: 45:let _ALIAS_ENRICHMENT_CONTEXT = null;
⚠️ src/1_group1_master_db/16_GeoDictionaryBuilder.gs:69 — top-level let/var: 69:let _GLOBAL_GEO_DICT_PROVINCE_INDEX = null;
⚠️ src/1_group1_master_db/20_ThGeoService.gs:39 — top-level let/var: 39:let _GLOBAL_GEO_DICT_SEARCH_KEY_INDEX = null;
⚠️ src/2_group2_daily_ops/04_SourceRepository.gs:50 — top-level let/var: 50:let _SOURCE_ROWS_RAM_CACHE = null;
⚠️ src/2_group2_daily_ops/11_TransactionService.gs:284 — top-level let/var: 284:let _FACT_INVOICE_RAM_CACHE = null; // Map: normalizedInvoice → rowIndex (1-based)
⚠️ src/2_group2_daily_ops/11_TransactionService.gs:320 — top-level let/var: 320:let _GEO_LATLNG_RAM_CACHE = null;
⚠️ src/O_core_system/03_SetupSheets.gs:42 — top-level let/var: 42:let _isClearingOldLogs_ = false;
⚠️ src/O_core_system/03_SetupSheets.gs:45 — top-level let/var: 45:let _LOG_BUFFER = [];

💡 Fix: Use CONFIG.* from 01_Config.gs, or pass via parameters

📋 ST-010: HTML files separate (Law 11)
✅ No inline HTML in .gs files

📋 ST-011: No ellipsis/placeholder in code (Law 15)
✅ No ellipsis/placeholder in code blocks

📋 ST-012: Internal link integrity in docs
✅ All internal doc links resolve

📋 ST-013: Skills catalog schema validation

📊 Total skills: 12
📊 Missing SKILL.md: 0
📊 Missing 'name:' field: 0
📊 Missing 'description:' field: 0
📊 Missing DOC-TYPE marker (recommended): 0
✅ All skills have complete schema (frontmatter or DOC-TYPE)
