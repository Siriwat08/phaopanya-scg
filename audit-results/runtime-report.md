# Agent: Agent 2 (Runtime-GAS)
**Date:** 2026-07-26T15:31:56Z
**Repo:** /home/user/webapp/audit/repo-git

## Raw output from check scripts

📋 RT-001: UrlFetchApp.fetch in try-catch (Law 16)
  📊 Total fetch calls: 5
  ⚠️  src/2_group2_daily_ops/15_GoogleMapsAPI.gs:20 — fetch without nearby try
  ⚠️  src/2_group2_daily_ops/18_ServiceSCG.gs:22 — fetch without nearby try

  ❌ 2 fetch call(s) may be unprotected
  💡 Fix: Wrap in try { ... } catch (e) { logError(...) }

📋 RT-002: No runtime CDN imports
  ✅ No runtime CDN imports found

📋 RT-003: Batch operations only (Law 4)
  ⚠️  /home/user/webapp/audit/repo-git/src/O_core_system/03_SetupSheets.gs:478:function setupInputSheet_(ss) {
      ^ loop contains getValue/setValue — use getValues/setValues
  ℹ️  Manual review recommended (heuristic has false positives)

📋 RT-004: LockService for shared writes (Law 16)
  ⚠️  src/1_group1_master_db/05_NormalizeService.gs — writes to master but no LockService
  ⚠️  src/1_group1_master_db/10f_MatchAliasEnrichment.gs — writes to master but no LockService

  💡 Fix: Wrap master write in acquireScriptLock_() / try / finally / releaseLock

📋 RT-005: Checkpoint & resume (Law 5)
  ⚠️  src/1_group1_master_db/05_NormalizeService.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/1_group1_master_db/06_PersonService.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/1_group1_master_db/07_PlaceService.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/1_group1_master_db/08_GeoService.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/1_group1_master_db/09_DestinationService.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/1_group1_master_db/10_MatchEngine.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/1_group1_master_db/10d_MatchTestHarness.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/1_group1_master_db/16_GeoDictionaryBuilder.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/2_group2_daily_ops/11_TransactionService.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/2_group2_daily_ops/12_ReviewService.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/2_group2_daily_ops/17_SearchService.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/4_group4_pipeline_mgr/24_PipelineManager.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/O_core_system/03_SetupSheets.gs — iterates over lastRow but no PropertiesService checkpoint
  ⚠️  src/O_core_system/22b_WebAppViews.gs — iterates over lastRow but no PropertiesService checkpoint

  💡 Fix: Save progress to PropertiesService every N rows, resume on next run

📋 RT-006: Cache invalidation chain (Law 20)
  🔍 Checking PERSON...
  🔍 Checking PLACE...
  🔍 Checking GEO_POINT...
  🔍 Checking DESTINATION...
  🔍 Checking ALIAS...
  🔍 Checking DAILY_JOB...
  🔍 Checking TH_GEO...

  📊 Total violations: 0
  ✅ All master-sheet writers use CacheService (or no writes outside skip list)

📋 RT-007: Trigger cleanup (Law 19)
  📊 deleteTrigger calls: 6
  📊 getProjectTriggers calls: 9
  ✅ Trigger cleanup looks correct

📋 RT-008: Library version locked (Law 10)
  ✅ All libraries are version-pinned

📋 RT-009: Time budget awareness (6 min hard limit)
  📊 Files with time check: 8 / 39
  ✅ Time budget awareness looks reasonable

📋 RT-010: Quota awareness
  📊 Files with quota/throttle logic: 5
  📊 Files with UrlFetchApp: 4
  ✅ Quota awareness present (or no UrlFetchApp usage)

📋 RT-011: API call count per pipeline
  📊 API call counts per file:
    FILE                                               URLFETCH    PROPS    CACHE
    ----                                               --------    -----    -----
    10h_MatchAutoResume.gs                                    0        7        0
    16_GeoDictionaryBuilder.gs                                0        1        6
    21_AliasService.gs                                        0        6        9
    18_ServiceSCG.gs                                          2        5        1
    24_PipelineManager.gs                                     1       14        0
    14_Utils.gs                                               1        4        3
    19_Hardening.gs                                           0        5        1

  ⚠️  7 files have > 5 API calls each
  ℹ️  Review high-count files for unnecessary calls
  💡 Typical budget: < 50 calls per pipeline run

📋 RT-012: Production access config (appsscript.json)
  📊 access:    MYSELF
  📊 executeAs: USER_DEPLOYING
  ❌ access: MYSELF — development/staging only
     Fix: change to DOMAIN (Google Workspace) or ANYONE (public)

  ❌ Not production-ready

📋 RT-013: GitHub Workflows permissions (least privilege)
  ✅ 01-ci.yml — has permissions block
    contents: read
    pull-requests: write
    checks: write
  ✅ 02-deploy.yml — has permissions block
    contents: read
    pull-requests: write
    checks: write
  ✅ 03-pr-validation.yml — has permissions block
    contents: read
    pull-requests: write
    checks: write
  ✅ 04-release.yml — has permissions block
    contents: read
    pull-requests: write
    checks: write
  ✅ 05-scheduled-health.yml — has permissions block
    contents: read
    pull-requests: write
    checks: write
  ✅ 06-codeql.yml — has permissions block
    contents: read
    pull-requests: write
    checks: write
    actions: read
  ✅ 07-doc-code-sync.yml — has permissions block
    contents: read
    pull-requests: write
  ✅ 08-gitleaks.yml — has permissions block
    contents: read
    pull-requests: write
  ✅ 09-sonarcloud.yml — has permissions block
    contents: read
    pull-requests: write

  📊 Total workflows: 9
  📊 With permissions block: 9
  📊 Missing permissions (default write-all): 0
  📊 Using write-all explicitly: 0
  ✅ All workflows have explicit permissions (least privilege)

📋 RT-014: Frozen header row on master sheets
  📊 src/O_core_system/03_SetupSheets.gs: 9 setFrozenRows calls
  📊 Total setFrozenRows calls: 9
  📊 Master sheets with frozen rows: 7 / 9
  ✅ Frozen rows present (7/9 master sheets — sufficient coverage)

