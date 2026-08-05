<!-- DOC-TYPE: historical -->

# Agent: Agent 5 (Doc-Sync)

**Date:** 2026-07-26T15:32:03Z
**Repo:** /home/user/webapp/audit/repo-git

## Raw output from check scripts

📋 DS-000: Auto-discover + run existing doc-code-sync checks
📊 Found 18 doc-code-sync check scripts

✅ check_01_version.sh — ✅ All versions consistent: 6.0.077
✅ check_02_stats.sh — ✅ Stats consistent
✅ check_03_local_paths.sh — ✅ No file:/// paths in docs
✅ check_04_phantom_deps.sh — ✅ No known phantom dependencies (active references)
✅ check_05_internal_links.sh — ✅ All 17 internal links resolve
✅ check_06_verify_fixes.sh — ✅ escapeHtml consolidation: 1 definitions (≤2 = OK)
✅ check_07_header_changelog.sh — ⚠️ 05_NormalizeService.gs: CHANGELOG section ไม่มี version entry เลย
✅ check_08_header_dependencies.sh — ⚠️ 05_NormalizeService.gs: ไม่มี CALLED BY: sub-section ใน DEPENDENCIES
✅ check_09_doc_type_coverage.sh — ✅ ผ่าน: 107 ไฟล์
✅ check_10_dead_functions.sh — ⚠️ Dead function: MIGRATION_HybridAliasSystem (0 callers in .gs + .html)
✅ check_11_wrapper_usage.sh — ✅ resetAliasEnrichmentContext_() used correctly (no raw pattern outside 10f)
✅ check_12_path_consistency.sh — ✅ cleanupMatchEngineRun_ called in all 3 cleanup paths
✅ check_13_no_runtime_cdn.sh — ⚠️ Runtime CDN found: '@tailwindcss/browser' (4 occurrence(s))
✅ check_14_external_api_resilience.sh — ✅ All UrlFetchApp.fetch calls are in try-catch blocks
✅ check_15_string_duplication.sh — ⚠️ String repeated 16x: '❌ ล้มเหลว: '...
✅ check_16_api_call_count.sh — getValues (batch): 112 ✅ good practice
ℹ️ check_17_production_readiness.sh — ⚠️ access: MYSELF — development/staging only
ℹ️ check_18_pr_title_vs_diff.sh — ℹ️ No changes vs main (might be already merged)

📊 Summary:
Total checks: 18
Passed: 16
Failed: 0
Skipped: 2
✅ All 18 doc-code-sync checks passed (or skipped)
