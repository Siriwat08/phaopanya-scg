#!/usr/bin/env bash
# RT-001 — UrlFetchApp.fetch must be in try-catch
# ตรวจว่าทุก UrlFetchApp.fetch อยู่ใน try block (Law 16 + Check 14)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-001: UrlFetchApp.fetch in try-catch (Law 16)"

# Find all fetch calls with line numbers
fetch_calls=$(grep -rn "UrlFetchApp\.fetch" "$REPO/src" --include="*.gs" 2>/dev/null)

if [[ -z "$fetch_calls" ]]; then
  echo "  ℹ️  No UrlFetchApp.fetch calls found"
  exit 0
fi

total=$(echo "$fetch_calls" | wc -l | tr -d ' ')
echo "  📊 Total fetch calls: $total"

# For each call, check if it's inside a try block
# Simple heuristic: look backwards 20 lines for "try {"
unprotected=0
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  lineno=$(echo "$line" | cut -d: -f2)
  start=$((lineno > 20 ? lineno - 20 : 1))
  context=$(sed -n "${start},${lineno}p" "$file")
  if ! echo "$context" | grep -q "try"; then
    echo "  ⚠️  ${file#$REPO/}:${lineno} — fetch without nearby try"
    unprotected=$((unprotected + 1))
  fi
done <<< "$fetch_calls"

if [[ "$unprotected" -eq 0 ]]; then
  echo "  ✅ All fetch calls are protected"
  exit 0
fi

echo ""
echo "  ❌ $unprotected fetch call(s) may be unprotected"
echo "  💡 Fix: Wrap in try { ... } catch (e) { logError(...) }"
exit 1
