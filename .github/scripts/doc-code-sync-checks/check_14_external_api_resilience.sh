#!/usr/bin/env bash
# Check 14 — External API Resilience (UrlFetchApp.fetch must be in try-catch)
# ตรวจว่าทุก UrlFetchApp.fetch อยู่ใน try-catch block
#
# Returns:
#   0 = pass (all UrlFetchApp.fetch in try-catch, or only warnings)
#   1 = fail (unprotected UrlFetchApp.fetch found)
#
# Rule: Every UrlFetchApp.fetch() should be inside a try block
#   (GAS throws on network errors — unhandled = pipeline crash)

set -uo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 14: External API Resilience (UrlFetchApp in try-catch)"

STRICT_MODE="${STRICT_MODE:-0}"

# Find all UrlFetchApp.fetch calls
FETCH_CALLS=$(grep -rn 'UrlFetchApp\.fetch' src/ --include="*.gs" 2>/dev/null)

if [[ -z "$FETCH_CALLS" ]]; then
  echo "  ℹ️  No UrlFetchApp.fetch calls found"
  exit 0
fi

total=$(echo "$FETCH_CALLS" | wc -l | tr -d ' ')
echo "  📊 Total UrlFetchApp.fetch calls: $total"

unprotected=0
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)

  # Check if there's a try { within 20 lines before this line
  # (GAS convention: try block wraps the fetch call)
  start=$((lineno - 20))
  if [[ $start -lt 1 ]]; then start=1; fi

  has_try=$(sed -n "${start},${lineno}p" "$file" 2>/dev/null | grep -c 'try {' || echo 0)

  if [[ "$has_try" -eq 0 ]]; then
    echo "  ⚠️  Unprotected UrlFetchApp.fetch at $file:$lineno (no try block within 20 lines above)"
    unprotected=$((unprotected + 1))
  fi
done <<< "$FETCH_CALLS"

echo ""
echo "─────────────────────────────────────"
echo "  Total: $total | Protected: $((total - unprotected)) | Unprotected: $unprotected"
echo "─────────────────────────────────────"

if [[ $unprotected -gt 0 ]]; then
  if [[ "$STRICT_MODE" -eq 1 ]]; then
    echo "❌ Unprotected UrlFetchApp.fetch found — wrap in try-catch"
    exit 1
  else
    echo "⚠️  Unprotected UrlFetchApp.fetch — warning (STRICT_MODE=0)"
    exit 0
  fi
fi

echo "✅ All UrlFetchApp.fetch calls are in try-catch blocks"
exit 0
