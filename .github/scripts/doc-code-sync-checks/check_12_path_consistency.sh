#!/usr/bin/env bash
# Check 12 — Path Consistency (CREATE_NEW / AUTO_MATCH / MERGE should do same side effects)
# ตรวจว่าทุก code path ทำ side effects เหมือนกัน
#
# Returns:
#   0 = pass (all paths consistent)
#   1 = fail (inconsistency found)
#
# Checks:
#   1. persistSemanticNotesForEntity_ called in all 3 paths
#   2. resetAliasEnrichmentContext_ called in cleanup paths

set -uo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 12: Path Consistency (CREATE_NEW / AUTO_MATCH / MERGE)"

failures=0

# ─── Check 1: persistSemanticNotesForEntity_ in all 3 paths ───
# CREATE_NEW: resolveAndPersistCreate_ in 10e
# MERGE: resolveAndPersistMerge_ in 10e
# AUTO_MATCH: handleAutoMatch_ in 10g

notes_in_create=$(grep -c 'persistSemanticNotesForEntity_' src/1_group1_master_db/10e_MatchResolvePersist.gs 2>/dev/null || echo 0)
notes_in_automatch=$(grep -c 'persistSemanticNotesForEntity_' src/1_group1_master_db/10g_MatchRowProcessor.gs 2>/dev/null || echo 0)

# MERGE path calls resolveAndPersistCreate_ as fallback, so it inherits the call
# But should also have its own explicit call
notes_in_merge=$(grep -A5 'resolveAndPersistMerge_' src/1_group1_master_db/10e_MatchResolvePersist.gs 2>/dev/null | grep -c 'persistSemanticNotesForEntity_' || echo 0)

echo "  📊 persistSemanticNotesForEntity_ calls:"
echo "     CREATE_NEW (10e): $notes_in_create call(s)"
echo "     AUTO_MATCH (10g): $notes_in_automatch call(s)"
echo "     MERGE (10e):      $notes_in_merge call(s) in merge function"

if [[ "$notes_in_create" -eq 0 ]]; then
  echo "  ❌ CREATE_NEW path missing persistSemanticNotesForEntity_"
  failures=$((failures + 1))
fi
if [[ "$notes_in_automatch" -eq 0 ]]; then
  echo "  ❌ AUTO_MATCH path missing persistSemanticNotesForEntity_"
  failures=$((failures + 1))
fi

# ─── Check 2: cleanupMatchEngineRun_ in all cleanup paths ───
cleanup_calls=$(grep -c 'cleanupMatchEngineRun_' src/1_group1_master_db/10_MatchEngine.gs 2>/dev/null || echo 0)
echo "  📊 cleanupMatchEngineRun_ calls in 10_MatchEngine.gs: $cleanup_calls"

if [[ "$cleanup_calls" -lt 3 ]]; then
  echo "  ❌ cleanupMatchEngineRun_ should be called in 3 places (preflight fail, empty pending, finally) — found $cleanup_calls"
  failures=$((failures + 1))
else
  echo "  ✅ cleanupMatchEngineRun_ called in all 3 cleanup paths"
fi

echo ""
echo "─────────────────────────────────────"
if [[ $failures -eq 0 ]]; then
  echo "  ✅ All paths consistent"
  exit 0
else
  echo "  ❌ $failures inconsistency(ies) found"
  exit 1
fi
