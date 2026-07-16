#!/usr/bin/env bash
# Check 16 — API Call Count (count GAS API calls — quota risk indicator)
# นับการเรียก GAS API ที่ใช้ quota (getSheetByName, getValue, setValue, getValues, setValues)
#
# Returns:
#   0 = pass (under threshold, or only warnings)
#   1 = fail (over threshold — STRICT_MODE=1 to block)
#
# Thresholds (warning levels):
#   - getSheetByName: > 100 calls = warning (quota risk)
#   - getValue/setValue (single cell): > 50 = warning (should use batch)
#   - getValues/setValues (batch): no limit (good practice)

set -uo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 16: API Call Count (quota risk)"

STRICT_MODE="${STRICT_MODE:-0}"

# Count API calls
getSheetByName=$(grep -rn 'getSheetByName(' src/ --include="*.gs" 2>/dev/null | wc -l | tr -d ' ')
getValue=$(grep -rn '\.getValue(' src/ --include="*.gs" 2>/dev/null | grep -v 'getValues' | wc -l | tr -d ' ')
setValue=$(grep -rn '\.setValue(' src/ --include="*.gs" 2>/dev/null | grep -v 'setValues' | wc -l | tr -d ' ')
getValues=$(grep -rn '\.getValues(' src/ --include="*.gs" 2>/dev/null | wc -l | tr -d ' ')
setValues=$(grep -rn '\.setValues(' src/ --include="*.gs" 2>/dev/null | wc -l | tr -d ' ')

echo "  📊 GAS API Call Counts:"
echo "     getSheetByName: $getSheetByName  (threshold: 100)"
echo "     getValue (single): $getValue  (threshold: 50)"
echo "     setValue (single): $setValue  (threshold: 50)"
echo "     getValues (batch):  $getValues  ✅ good practice"
echo "     setValues (batch):  $setValues  ✅ good practice"

warnings=0

if [[ "$getSheetByName" -gt 100 ]]; then
  echo "  ⚠️  getSheetByName count ($getSheetByName) > 100 — consider sheet caching"
  warnings=$((warnings + 1))
fi

if [[ "$getValue" -gt 50 ]]; then
  echo "  ⚠️  getValue (single cell) count ($getValue) > 50 — use getValues (batch) instead"
  warnings=$((warnings + 1))
fi

if [[ "$setValue" -gt 50 ]]; then
  echo "  ⚠️  setValue (single cell) count ($setValue) > 50 — use setValues (batch) instead"
  warnings=$((warnings + 1))
fi

echo ""
echo "─────────────────────────────────────"
if [[ $warnings -gt 0 ]]; then
  if [[ "$STRICT_MODE" -eq 1 ]]; then
    echo "❌ $warnings quota risk(s) — optimize API calls"
    exit 1
  else
    echo "⚠️  $warnings quota risk(s) — warning (STRICT_MODE=0)"
    exit 0
  fi
fi

echo "✅ API call counts within thresholds"
exit 0
