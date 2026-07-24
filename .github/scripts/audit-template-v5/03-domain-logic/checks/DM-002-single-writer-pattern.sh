#!/usr/bin/env bash
# DM-002 — Single Writer Pattern
# ตรวจว่าเฉพาะ Group 1 (1_group1_master_db) เท่านั้นที่เขียน Master sheets
# (M_PERSON, M_PLACE, M_GEO_POINT, M_DESTINATION, M_ALIAS)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-002: Single Writer Pattern"

master_sheets=("M_PERSON" "M_PLACE" "M_GEO_POINT" "M_DESTINATION" "M_ALIAS")
violations=0

# v4: เพิ่ม 19_Hardening ใน skip list — เป็น security hardening script
# ที่จงใจ write เพื่อ apply protection / cleanup (ไม่ใช่ business logic write)
# เพิ่ม 22c_WebAppActions / 28_WebAppActions — UI actions ที่ผ่าน service layer แล้ว
# v3: ตรวจ write จริงเท่านั้น (setValues/setValue/appendRow) ไม่ใช่แค่ reference
# เพื่อหลีกเลี่ยง false positive บน 01_Config, 02_Schema, 03_SetupSheets ที่แค่อ้างชื่อ sheet
SKIP_PATTERN="03_SetupSheets|02_Schema|01_Config|19_Hardening|00_App|22_WebApp|22b_WebAppViews|22c_WebAppActions|28_WebAppActions|26_AuditTrail|29_SnapshotTest|99_Legacy|Test|Harness|Snapshot"

for sheet in "${master_sheets[@]}"; do
  # Find files outside Group 1 that WRITE to this master sheet
  # Pattern: sheet name followed by setValues/setValue/appendRow on same or next line
  offenders=$(grep -rnE "($sheet).*(setValues|setValue|appendRow)|(setValues|setValue|appendRow).*($sheet)" \
    "$REPO/src" --include="*.gs" 2>/dev/null \
    | grep -v "/1_group1_master_db/" \
    | grep -vE "$SKIP_PATTERN|//|\\*" \
    | cut -d: -f1 | sort -u || true)

  if [[ -n "$offenders" ]]; then
    echo "  ⚠️  $sheet is WRITTEN outside Group 1:"
    echo "$offenders" | head -5 | sed 's/^/      /'
    violations=$((violations + 1))
  fi
done

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ Only Group 1 writes master sheets (verified via setValues/setValue/appendRow)"
  exit 0
fi

echo ""
echo "  💡 Fix: Move all M_* sheet writes to Group 1 services"
echo "  ℹ️  Skip list (security/setup/UI files): $SKIP_PATTERN"
exit 1
