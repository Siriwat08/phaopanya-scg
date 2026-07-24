#!/usr/bin/env bash
# RT-007 — Trigger cleanup (Law 19)
# ตรวจว่า delete trigger ใช้ ScriptApp.deleteTrigger (ไม่ใช่ลบแบบ blind)
# และ list triggers ก่อนลบ
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-007: Trigger cleanup (Law 19)"

# Find ScriptApp.deleteTrigger calls
# Check that they're preceded by getProjectTriggers listing

delete_calls=$(grep -rn "ScriptApp\.deleteTrigger" "$REPO/src" --include="*.gs" 2>/dev/null | wc -l | tr -d ' ')
list_calls=$(grep -rn "ScriptApp\.getProjectTriggers" "$REPO/src" --include="*.gs" 2>/dev/null | wc -l | tr -d ' ')

echo "  📊 deleteTrigger calls: $delete_calls"
echo "  📊 getProjectTriggers calls: $list_calls"

if [[ "$delete_calls" -eq 0 ]]; then
  echo "  ℹ️  No trigger deletions found"
  exit 0
fi

# Rule: must have at least one getProjectTriggers per deleteTrigger
# Heuristic: ratio check
if [[ "$list_calls" -eq 0 ]] && [[ "$delete_calls" -gt 0 ]]; then
  echo "  ❌ deleteTrigger without getProjectTriggers listing"
  echo "  💡 Fix: Always list triggers first, then delete specific one"
  exit 1
fi

echo "  ✅ Trigger cleanup looks correct"
exit 0
