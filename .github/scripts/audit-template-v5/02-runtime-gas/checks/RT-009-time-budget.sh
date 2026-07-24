#!/usr/bin/env bash
# RT-009 — Time budget under 6 min (GAS hard limit)
# ตรวจว่า pipeline มี Date.now() check หรือ checkpoint ทุก ~3-4 นาที
# เพราะ GAS hard limit = 6 นาที
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-009: Time budget awareness (6 min hard limit)"

# Find pipeline entry points (functions called from menu/trigger)
# Check if they have time check or checkpoint

# Simple heuristic: count files with "Date.now" or "checkpoint" pattern
files_with_time_check=$(grep -rlE "Date\.now\(\)|new Date\(\)\.getTime" "$REPO/src" --include="*.gs" 2>/dev/null | wc -l | tr -d ' ')

total_gs=$(find "$REPO/src" -name "*.gs" 2>/dev/null | wc -l | tr -d ' ')

echo "  📊 Files with time check: $files_with_time_check / $total_gs"

# Allow if at least 10% of files have time awareness
min_required=$((total_gs / 10))
if [[ "$files_with_time_check" -lt "$min_required" ]]; then
  echo "  ⚠️  Few files have Date.now() / time awareness"
  echo "  💡 Fix: Add Date.now() check before long loops; abort/continue at 4.5 min"
  exit 1
fi

echo "  ✅ Time budget awareness looks reasonable"
exit 0
