#!/usr/bin/env bash
# Check 15 — String Duplication (find string literals repeated > N times)
# ตรวจหา string literal ที่ซ้ำกันเกิน threshold (DRY violation)
#
# Returns:
#   0 = pass (no excessive duplication, or only warnings)
#   1 = fail (duplication found — STRICT_MODE=1 to block)
#
# Threshold: strings > 20 chars appearing > 3 times
# Excludes: comments, import URLs, common patterns

set -uo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 15: String Duplication (DRY check)"

STRICT_MODE="${STRICT_MODE:-0}"
MIN_LENGTH=20   # Only check strings > 20 chars
MIN_COUNT=4     # Flag if appears > 3 times (i.e., >= 4)

# Extract string literals from .gs files (single-quoted strings > 20 chars)
# Pattern: 'string content here' with length > 20
STRINGS=$(grep -rohE "'[^']{${MIN_LENGTH},}'" src/ --include="*.gs" 2>/dev/null | sort | uniq -c | sort -rn | head -20)

if [[ -z "$STRINGS" ]]; then
  echo "  ℹ️  No long string literals found"
  exit 0
fi

flagged=0
while IFS= read -r line; do
  count=$(echo "$line" | awk '{print $1}')
  string=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ //')

  # Skip common patterns
  if echo "$string" | grep -qiE 'http|api\.telegram|google\.com|sheet|SHEET\.|APP_CONST\.|logInfo|logWarn|logError|logDebug'; then
    continue
  fi

  if [[ "$count" -ge "$MIN_COUNT" ]]; then
    echo "  ⚠️  String repeated ${count}x: ${string:0:60}..."
    flagged=$((flagged + 1))
  fi
done <<< "$STRINGS"

echo ""
echo "─────────────────────────────────────"
if [[ $flagged -gt 0 ]]; then
  if [[ "$STRICT_MODE" -eq 1 ]]; then
    echo "❌ $flagged duplicated string(s) found — extract to constant/util"
    exit 1
  else
    echo "⚠️  $flagged duplicated string(s) — warning (consider extracting to util)"
    exit 0
  fi
fi

echo "✅ No excessive string duplication detected"
exit 0
