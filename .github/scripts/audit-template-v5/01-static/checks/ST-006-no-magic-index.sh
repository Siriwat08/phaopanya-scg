#!/usr/bin/env bash
# ST-006 — No magic column index (Law 3) — improved to avoid FPs
#
# Heuristic v2:
#   - Pattern: getRange(row, COL, ...) where COL is integer > 0
#   - Allow: getRange(row, 1, ...)  (1 is universal header/start col)
#   - Allow: getRange(row, var) or getRange(row, getLastRow()-1, ...)  (vars, function calls)
#   - Allow: getRange(row, COL, 1, ...) where the 1 is row count
#   - Skip: comments
#
# Returns: 0 = pass (or warning only), 1 = hard fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-006: No magic column index (Law 3)"

# Find getRange calls where the 2nd arg is a non-1 integer literal
# Pattern: getRange(<anything>, 2..9+, <maybe more>)
violations=$(grep -rnE 'getRange\s*\(\s*[^,]+,\s*[2-9][0-9]*\s*,' "$REPO/src" --include="*.gs" 2>/dev/null \
  | grep -vE '^\s*\*' \
  | grep -vE '^\s*//' \
  | grep -vE '//\s*' || true)

count=0
if [[ -n "$violations" ]]; then
  count=$(echo "$violations" | wc -l | tr -d ' ')
fi

if [[ "$count" -eq 0 ]]; then
  echo "  ✅ No high-risk magic column indices (>=2 literal in 2nd arg)"
  echo "  ℹ️  Note: getRange(row, 1, ...) is excluded (start col convention)"
  exit 0
fi

echo "  ⚠️  Found $count potential magic index usage(s) (col ≥ 2):"
echo "$violations" | head -20 | sed 's/^/    /'
echo ""
echo "  💡 Fix: Define column index constant in 01_Config.gs, e.g. PERSON_NAME_IDX = 5"
echo "  ℹ️  Review each — some may be dynamic (function calls, vars)"
exit 1
