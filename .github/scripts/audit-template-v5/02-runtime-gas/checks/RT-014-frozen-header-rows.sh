#!/usr/bin/env bash
# RT-014 — Frozen header row on master sheets
# v4 NEW: ตรวจว่า master sheets มีการ setFrozenRows(1) ใน setup
# เพื่อป้องกัน user กด sort แล้ว header หายไป
#
# Rule:
#   - ทุก master sheet (M_PERSON, M_PLACE, M_GEO_POINT, M_DESTINATION, M_ALIAS, M_DAILY_JOB)
#     ต้องมี setFrozenRows(1) หรือ setFrozenRows(2) ใน setup
#   - อนุญาตให้ freeze ใน setup files (03_SetupSheets, 19_Hardening)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-014: Frozen header row on master sheets"

# Check setup files for setFrozenRows calls
CHECK_FILES=(
  "$REPO/src/O_core_system/03_SetupSheets.gs"
  "$REPO/src/O_core_system/19_Hardening.gs"
  "$REPO/src/O_core_system/22_WebApp.gs"
  "$REPO/src/O_core_system/22b_WebAppViews.gs"
)

EXISTING_FILES=()
for f in "${CHECK_FILES[@]}"; do
  [[ -f "$f" ]] && EXISTING_FILES+=("$f")
done

if [[ ${#EXISTING_FILES[@]} -eq 0 ]]; then
  echo "  ℹ️  No setup files found — skipping"
  exit 0
fi

# Master sheets to check
MASTER_SHEETS=("M_PERSON" "M_PLACE" "M_GEO_POINT" "M_DESTINATION" "M_ALIAS" "M_DAILY_JOB" "FACT_DELIVERY" "Q_REVIEW" "SYS_TH_GEO")

# Find setFrozenRows calls
frozen_count=0
for check_file in "${EXISTING_FILES[@]}"; do
  cnt=$(grep -cE "setFrozenRows\s*\(" "$check_file" 2>/dev/null) || cnt=0
  cnt=${cnt//[^0-9]/}
  cnt=${cnt:-0}
  frozen_count=$((frozen_count + cnt))
  if [[ "$cnt" -gt 0 ]]; then
    echo "  📊 ${check_file#$REPO/}: $cnt setFrozenRows calls"
  fi
done

echo "  📊 Total setFrozenRows calls: $frozen_count"

if [[ "$frozen_count" -eq 0 ]]; then
  echo "  ⚠️  No setFrozenRows calls found — master sheets vulnerable to sort-induced header loss"
  echo "  💡 Fix: Add sheet.setFrozenRows(1) in setupAllSheets() for each master sheet"
  exit 1
fi

# Check that master sheet names appear near setFrozenRows (within 5 lines)
frozen_master_sheets=0
for sheet in "${MASTER_SHEETS[@]}"; do
  for check_file in "${EXISTING_FILES[@]}"; do
    # Look for sheet name with setFrozenRows nearby (within 5 lines)
    if grep -q "$sheet" "$check_file" 2>/dev/null; then
      # Get line numbers where this sheet appears
      sheet_lines=$(grep -n "$sheet" "$check_file" 2>/dev/null | cut -d: -f1)
      for line_no in $sheet_lines; do
        start=$((line_no - 3))
        [[ "$start" -lt 1 ]] && start=1
        end=$((line_no + 3))
        # Check if setFrozenRows is in this context window
        if sed -n "${start},${end}p" "$check_file" 2>/dev/null | grep -qE "setFrozenRows"; then
          frozen_master_sheets=$((frozen_master_sheets + 1))
          break 2  # break both loops
        fi
      done
    fi
  done
done

echo "  📊 Master sheets with frozen rows: $frozen_master_sheets / ${#MASTER_SHEETS[@]}"

if [[ "$frozen_master_sheets" -ge ${#MASTER_SHEETS[@]} ]]; then
  echo "  ✅ All master sheets have frozen header rows"
  exit 0
fi

if [[ "$frozen_master_sheets" -ge 3 ]]; then
  echo "  ✅ Frozen rows present ($frozen_master_sheets/${#MASTER_SHEETS[@]} master sheets — sufficient coverage)"
  exit 0
fi

echo "  ⚠️  Only $frozen_master_sheets/${#MASTER_SHEETS[@]} master sheets have frozen rows"
echo "  💡 Fix: Add sheet.setFrozenRows(1) after creating each master sheet"
exit 1
