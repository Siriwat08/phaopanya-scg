#!/usr/bin/env bash
# Check 6 — Verify Claimed Fixes
# ตรวจว่า key indicators ของ audit fixes ยังอยู่ในโค้ดจริง
# ป้องกัน regression แบบที่เกิดกับ PR #92 (branch number หายจาก rebase)
#
# Returns:
#   0 = pass (all fixes present)
#   1 = fail (some fix missing — DO NOT MERGE)

set -euo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 6: Verify Claimed Fixes"

failures=0

# ─── Fix 1: escapeHtml consolidation (audit 1.4) ───
# Expected: only 1 definition in ViewHelpers.html, aliases elsewhere
escape_defs=$(grep -rn "function escapeHtml" src/3_group3_webapp/ 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')
if [[ "$escape_defs" -le 2 ]]; then
  echo "  ✅ escapeHtml consolidation: $escape_defs definitions (≤2 = OK)"
else
  echo "  ❌ escapeHtml consolidation: $escape_defs definitions (expected ≤2)"
  failures=$((failures+1))
fi

# ─── Fix 2: Branch number matching (audit 1.5) ───
# Expected: BRANCH_NO in PERSON_IDX + branchNo in PersonService
if grep -q "BRANCH_NO: 12" src/O_core_system/01_Config.gs 2>/dev/null; then
  echo "  ✅ Branch number: BRANCH_NO in PERSON_IDX"
else
  echo "  ❌ Branch number: BRANCH_NO NOT in PERSON_IDX — regression!"
  failures=$((failures+1))
fi
if grep -q "sourceBranchNo" src/1_group1_master_db/06_PersonService.gs 2>/dev/null; then
  echo "  ✅ Branch number: sourceBranchNo in scorePersonCandidate"
else
  echo "  ❌ Branch number: sourceBranchNo NOT in PersonService — regression!"
  failures=$((failures+1))
fi

# ─── Fix 3: SCG cookie security (audit 3A) ───
# Expected: readInputConfig_ calls getSCGCookie_, NOT reading cell directly
if grep -A5 "function readInputConfig_" src/2_group2_daily_ops/18_ServiceSCG.gs 2>/dev/null | grep -q "getSCGCookie_"; then
  echo "  ✅ SCG cookie: readInputConfig_ calls getSCGCookie_"
else
  echo "  ❌ SCG cookie: readInputConfig_ does NOT call getSCGCookie_ — regression!"
  failures=$((failures+1))
fi
# Expected: setSCGCookie_UI writes to PropertiesService, NOT cell
if grep -A30 "function setSCGCookie_UI" src/2_group2_daily_ops/18_ServiceSCG.gs 2>/dev/null | grep -q "PropertiesService.*setProperty.*SCG_COOKIE"; then
  echo "  ✅ SCG cookie: setSCGCookie_UI writes to PropertiesService"
else
  echo "  ❌ SCG cookie: setSCGCookie_UI does NOT write to PropertiesService — regression!"
  failures=$((failures+1))
fi

# ─── Fix 4: ESLint complexity guards (audit 1.2/1.3) ───
if grep -q "max-lines-per-function" .eslintrc.yml 2>/dev/null; then
  echo "  ✅ ESLint complexity: max-lines-per-function rule present"
else
  echo "  ❌ ESLint complexity: max-lines-per-function rule MISSING"
  failures=$((failures+1))
fi

# ─── Fix 5: makeMatchDecision split (audit 1.2) ───
# Expected: 10b_MatchDecision.gs exists + evaluateRule functions
if [[ -f "src/1_group1_master_db/10b_MatchDecision.gs" ]] && grep -q "evaluateRule1_NoGeoInSource_" src/1_group1_master_db/10b_MatchDecision.gs 2>/dev/null; then
  echo "  ✅ makeMatchDecision split: 10b_MatchDecision.gs + evaluateRule functions"
else
  echo "  ❌ makeMatchDecision split: 10b_MatchDecision.gs or evaluateRule functions MISSING"
  failures=$((failures+1))
fi

# ─── Fix 6: persistResult_ SRP (audit 4) ───
if grep -q "function persistFactRows_" src/1_group1_master_db/10_MatchEngine.gs 2>/dev/null && grep -q "function persistReviewRows_" src/1_group1_master_db/10_MatchEngine.gs 2>/dev/null; then
  echo "  ✅ persistResult_ SRP: persistFactRows_ + persistReviewRows_ present"
else
  echo "  ❌ persistResult_ SRP: persistFactRows_ or persistReviewRows_ MISSING"
  failures=$((failures+1))
fi

if [[ $failures -eq 0 ]]; then
  echo "  ✅ All claimed fixes verified present"
  exit 0
else
  echo "  ❌ $failures fix(es) missing — DO NOT MERGE until investigated"
  exit 1
fi
