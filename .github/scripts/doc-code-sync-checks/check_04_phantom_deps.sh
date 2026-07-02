#!/usr/bin/env bash
# Check 4 — No Phantom Dependencies
# ตรวจว่า docstrings ที่อ้าง function names ใน REQUIRES section อ้างถึงฟังก์ชันที่มีจริง
#
# This is a heuristic check — looks for known phantom patterns
#
# Returns:
#   0 = pass
#   1 = fail

set -euo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 4: No Phantom Dependencies"

# Known phantom patterns from previous audits
phantom_patterns=("loadAllFacts_" "syncAliasToEntityTable_" "getMapCache_")

failures=0
for pattern in "${phantom_patterns[@]}"; do
  matches=$(grep -r "$pattern" src/ 2>/dev/null | wc -l || echo 0)
  if [[ $matches -gt 0 ]]; then
    echo "  ❌ Found phantom dep '$pattern': $matches references"
    grep -rn "$pattern" src/ 2>/dev/null | head -3
    failures=$((failures+1))
  fi
done

if [[ $failures -eq 0 ]]; then
  echo "  ✅ No known phantom dependencies"
  exit 0
else
  exit 1
fi
