#!/usr/bin/env bash
# RT-004 — LockService for shared writes (Law 16)
# ตรวจว่า function ที่เขียน master sheet ใช้ LockService
# ป้องกัน race condition ระหว่าง concurrent runs
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-004: LockService for shared writes (Law 16)"

# Find functions that write to master sheets (M_PERSON, M_PLACE, etc.)
# but don't use LockService

violations=0
# Files in Group 1 that should always lock
group1_files=$(find "$REPO/src/1_group1_master_db" -name "*.gs" 2>/dev/null)

for f in $group1_files; do
  # Skip test harness
  if echo "$f" | grep -qE "Test|Harness"; then continue; fi

  # Check if file has setValues or setValue (writes to sheet)
  if ! grep -qE "\.setValues?\(" "$f"; then continue; fi

  # Check if file uses LockService
  if ! grep -q "LockService\|acquireScriptLock" "$f"; then
    echo "  ⚠️  ${f#$REPO/} — writes to master but no LockService"
    violations=$((violations + 1))
  fi
done

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ All Group 1 writers use LockService"
  exit 0
fi

echo ""
echo "  💡 Fix: Wrap master write in acquireScriptLock_() / try / finally / releaseLock"
exit 1
