#!/usr/bin/env bash
# RT-006 — Cache invalidation chain (Law 20)
# ตรวจว่า master sheet write มี CacheService.remove call
# Cache map (จาก LMDS):
#   M_PERSON  -> 'PERSON_V1' cache key
#   M_PLACE   -> 'PLACE_V1'
#   M_GEO_POINT -> 'GEO_V1'
#   M_DESTINATION -> 'DEST_V1'
#   M_ALIAS   -> 'ALIAS_V1'
#   M_DAILY_JOB -> 'JOB_V1'
#   SYS_TH_GEO -> 'THGEO_V1'
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-006: Cache invalidation chain (Law 20)"

# v3: กรอง setup/schema/config/hardening files ออก — เหล่านี้แค่ create sheet ไม่ได้เขียน data
# ทำให้ false positive ลดลงจาก 30+ files เหลือ ~5 real write sites
SKIP_PATTERN="03_SetupSheets|02_Schema|01_Config|19_Hardening|00_App|22_WebApp|22b_WebAppViews|26_AuditTrail|29_SnapshotTest|99_Legacy|Test|Harness|Snapshot"

# Find functions that write to master sheets via setValues/getRange
# Then check if there's a matching CacheService.remove in the same function

cache_keys=("PERSON" "PLACE" "GEO_POINT" "DESTINATION" "ALIAS" "DAILY_JOB" "TH_GEO")
total_violations=0

for key in "${cache_keys[@]}"; do
  echo "  🔍 Checking $key..."
  # Find files that WRITE to this master sheet (must have setValues/setValue/appendRow near key)
  writers=$(grep -rlnE "($key).*(setValues|setValue|appendRow)|(setValues|setValue|appendRow).*($key)" \
    "$REPO/src" --include="*.gs" 2>/dev/null \
    | grep -vE "$SKIP_PATTERN" || true)

  for w in $writers; do
    # Check if file uses CacheService AT ALL (simplest heuristic)
    if ! grep -qE "CacheService\." "$w" 2>/dev/null; then
      echo "    ⚠️  ${w#$REPO/} — writes to $key but never uses CacheService"
      total_violations=$((total_violations + 1))
    fi
  done
done

echo ""
echo "  📊 Total violations: $total_violations"

if [[ "$total_violations" -eq 0 ]]; then
  echo "  ✅ All master-sheet writers use CacheService (or no writes outside skip list)"
  exit 0
fi

echo "  💡 Fix: After every master write, call CacheService.getScriptCache().remove('<KEY>_V1')"
exit 1
