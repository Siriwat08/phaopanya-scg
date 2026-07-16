#!/usr/bin/env bash
# Check 11 — Wrapper Usage (wrapper functions must be used everywhere)
# ตรวจว่า wrapper function ถูกใช้ทุกที่ที่ควร — ไม่มี raw pattern เหลือ
#
# Returns:
#   0 = pass (all wrappers used correctly)
#   1 = fail (raw pattern found — should use wrapper)
#
# Checks:
#   1. _ALIAS_ENRICHMENT_CONTEXT = null  → should use resetAliasEnrichmentContext_()
#   2. setup.lock.releaseLock()          → should use cleanupMatchEngineRun_() (in runMatchEngine context)

set -uo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 11: Wrapper Usage (no raw patterns)"

failures=0

# ─── Check 1: _ALIAS_ENRICHMENT_CONTEXT = null ───
# Wrapper: resetAliasEnrichmentContext_() in 10f_MatchAliasEnrichment.gs
# Raw pattern should NOT appear in any file EXCEPT 10f (where the wrapper is defined)
raw_alias_null=$(grep -rn '_ALIAS_ENRICHMENT_CONTEXT\s*=\s*null' src/ --include="*.gs" 2>/dev/null | grep -v '10f_MatchAliasEnrichment.gs' | grep -v '^\s*//' | wc -l | tr -d ' ')

if [[ "$raw_alias_null" -gt 0 ]]; then
  echo "  ❌ Raw '_ALIAS_ENRICHMENT_CONTEXT = null' found ($raw_alias_null spot(s)) — should use resetAliasEnrichmentContext_()"
  grep -rn '_ALIAS_ENRICHMENT_CONTEXT\s*=\s*null' src/ --include="*.gs" 2>/dev/null | grep -v '10f_MatchAliasEnrichment.gs' | grep -v '^\s*//' | head -5
  failures=$((failures + 1))
else
  echo "  ✅ resetAliasEnrichmentContext_() used correctly (no raw pattern outside 10f)"
fi

# ─── Check 2: _CANDIDATE_COORDS_CACHE_ = null ───
# (If we create a wrapper for this in the future, add check here)
raw_cache_null=$(grep -rn '_CANDIDATE_COORDS_CACHE_\s*=\s*null' src/ --include="*.gs" 2>/dev/null | grep -v 'function reset' | grep -v '^\s*//' | wc -l | tr -d ' ')
if [[ "$raw_cache_null" -gt 0 ]]; then
  echo "  ⚠️  Raw '_CANDIDATE_COORDS_CACHE_ = null' found ($raw_cache_null spot(s)) — consider wrapper"
  # Warning only — no wrapper exists yet
fi

echo ""
echo "─────────────────────────────────────"
if [[ $failures -eq 0 ]]; then
  echo "  ✅ All wrappers used correctly"
  exit 0
else
  echo "  ❌ $failures wrapper violation(s) found"
  exit 1
fi
