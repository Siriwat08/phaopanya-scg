#!/usr/bin/env bash
# self_audit.sh — Run all CI checks before pushing a PR
# ============================================================
# Usage:
#   ./scripts/self_audit.sh          # run all checks (warning mode)
#   ./scripts/self_audit.sh --strict # run all checks (strict mode — warnings become errors)
#
# What it runs:
#   1. Prettier format check
#   2. ESLint (errors only)
#   3. check_01 — Version consistency
#   4. check_02 — Stats consistency
#   5. check_03 — No local paths
#   6. check_04 — No phantom dependencies
#   7. check_05 — Internal links (known issues — warning only)
#   8. check_06 — Verify claimed fixes (8 audit indicators)
#   9. check_09 — DOC-TYPE coverage
#  10. check_10 — Dead functions (warning)
#  11. check_11 — Wrapper usage (error)
#  12. check_12 — Path consistency (error)
#  13. check_13 — No runtime CDN (warning)
#  14. check_14 — External API resilience (warning)
#  15. check_15 — String duplication (warning)
#  16. check_16 — API call count (warning)
#  17. check_17 — Production readiness (warning)
#  18. check_18 — PR title vs diff
# ============================================================

set -uo pipefail
cd "$(dirname "$0")/.."

# ─── Args ───
STRICT=false
if [[ "${1:-}" == "--strict" || "${1:-}" == "-s" ]]; then
  STRICT=true
fi

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  🔍 Self-Audit — LMDS V6.0 CI Check Suite${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

if $STRICT; then
  echo -e "${YELLOW}  ⚠️  STRICT MODE — warnings will be treated as errors${NC}"
  export STRICT_MODE=1
else
  echo -e "  ℹ️  Warning mode (use --strict for strict mode)"
  export STRICT_MODE=0
fi
echo ""

# ─── Counters ───
PASS=0
WARN=0
FAIL=0
TOTAL=0

# ─── Helper function ───
run_check() {
  local name="$1"
  local cmd="$2"
  local is_critical="${3:-false}"

  TOTAL=$((TOTAL + 1))
  echo -e "${BLUE}── [$TOTAL] $name ──${NC}"

  if $is_critical || $STRICT; then
    # Critical checks always fail on error; strict mode fails on warning too
    if eval "$cmd" > /tmp/audit_${TOTAL}.log 2>&1; then
      echo -e "  ${GREEN}✅ PASS${NC}"
      PASS=$((PASS + 1))
    else
      # Check if it's a warning (exit 0 with warning text) or error (exit 1)
      if grep -q "⚠️" /tmp/audit_${TOTAL}.log && ! $is_critical; then
        echo -e "  ${YELLOW}⚠️  WARN${NC}"
        WARN=$((WARN + 1))
      else
        echo -e "  ${RED}❌ FAIL${NC}"
        FAIL=$((FAIL + 1))
        cat /tmp/audit_${TOTAL}.log | tail -5
      fi
    fi
  else
    # Warning mode — don't fail on warnings
    if eval "$cmd" > /tmp/audit_${TOTAL}.log 2>&1; then
      if grep -q "⚠️" /tmp/audit_${TOTAL}.log; then
        echo -e "  ${YELLOW}⚠️  WARN${NC}"
        WARN=$((WARN + 1))
      else
        echo -e "  ${GREEN}✅ PASS${NC}"
        PASS=$((PASS + 1))
      fi
    else
      echo -e "  ${RED}❌ FAIL${NC}"
      FAIL=$((FAIL + 1))
      cat /tmp/audit_${TOTAL}.log | tail -5
    fi
  fi
  echo ""
}

# ─── Run all checks ───

# Code quality
run_check "Prettier format" 'npx prettier --check "src/**/*.{gs,js,html,css}" 2>&1' true
run_check "ESLint (errors)" 'npx eslint src/ --ext .gs,.js,.html --quiet 2>&1' true

# Doc-code sync checks
run_check "check_01 Version consistency" 'bash .github/scripts/doc-code-sync-checks/check_01_version.sh' true
run_check "check_02 Stats consistency" 'bash .github/scripts/doc-code-sync-checks/check_02_stats.sh' true
run_check "check_03 No local paths" 'bash .github/scripts/doc-code-sync-checks/check_03_local_paths.sh' true
run_check "check_04 No phantom deps" 'bash .github/scripts/doc-code-sync-checks/check_04_phantom_deps.sh' true
run_check "check_05 Internal links" 'bash .github/scripts/doc-code-sync-checks/check_05_internal_links.sh 2>&1 || true' false
run_check "check_06 Verify fixes" 'bash .github/scripts/doc-code-sync-checks/check_06_verify_fixes.sh' true
run_check "check_09 DOC-TYPE coverage" 'bash .github/scripts/doc-code-sync-checks/check_09_doc_type_coverage.sh' true

# New D-1 checks (warning by default)
run_check "check_10 Dead functions" 'bash .github/scripts/doc-code-sync-checks/check_10_dead_functions.sh' false
run_check "check_11 Wrapper usage" 'bash .github/scripts/doc-code-sync-checks/check_11_wrapper_usage.sh' true
run_check "check_12 Path consistency" 'bash .github/scripts/doc-code-sync-checks/check_12_path_consistency.sh' true
run_check "check_13 No runtime CDN" 'bash .github/scripts/doc-code-sync-checks/check_13_no_runtime_cdn.sh' false
run_check "check_14 API resilience" 'bash .github/scripts/doc-code-sync-checks/check_14_external_api_resilience.sh' false
run_check "check_15 String duplication" 'bash .github/scripts/doc-code-sync-checks/check_15_string_duplication.sh' false
run_check "check_16 API call count" 'bash .github/scripts/doc-code-sync-checks/check_16_api_call_count.sh' false
run_check "check_17 Production readiness" 'bash .github/scripts/doc-code-sync-checks/check_17_production_readiness.sh' false
run_check "check_18 PR title vs diff" 'bash .github/scripts/doc-code-sync-checks/check_18_pr_title_vs_diff.sh' false

# ─── Summary ───
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  📊 Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "  Total checks: $TOTAL"
echo -e "  ${GREEN}✅ Pass: $PASS${NC}"
echo -e "  ${YELLOW}⚠️  Warn: $WARN${NC}"
echo -e "  ${RED}❌ Fail: $FAIL${NC}"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}❌ Self-audit FAILED — fix errors before pushing${NC}"
  exit 1
fi

if $STRICT && [[ $WARN -gt 0 ]]; then
  echo -e "${YELLOW}❌ Self-audit FAILED (strict) — $WARN warning(s) treated as error(s)${NC}"
  exit 1
fi

if [[ $WARN -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  Self-audit PASSED with $WARN warning(s) — review before merge${NC}"
else
  echo -e "${GREEN}✅ Self-audit PASSED — all checks green!${NC}"
fi
exit 0
