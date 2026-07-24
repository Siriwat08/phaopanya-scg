#!/usr/bin/env bash
# DM-017 — SEC-005 + SEC-011 Sheet protection completeness
# v5 NEW: ตรวจว่า applySheetProtection_UI() ครอบคลุม master sheets ครบ
# (combines SEC-005 no sheet protection + SEC-011 incomplete protection)
#
# Rule:
#   - ต้องมี applySheetProtection_UI() หรือ applySheetLevelProtection_()
#   - ต้องครอบ master sheets: M_PERSON, M_PLACE, M_GEO_POINT, M_DESTINATION, M_ALIAS,
#     M_DAILY_JOB, FACT_DELIVERY, Q_REVIEW, SYS_TH_GEO (8 sheets + Q_REVIEW range)
#   - Q_REVIEW ใช้ Range Protection (ปกป้อง A1:Q — ปล่อย R-V ให้ reviewer แก้)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-017: SEC-005 + SEC-011 Sheet protection completeness"

# Setup files where protection is applied
CHECK_FILES=(
  "$REPO/src/O_core_system/03_SetupSheets.gs"
  "$REPO/src/O_core_system/19_Hardening.gs"
  "$REPO/src/O_core_system/22_WebApp.gs"
)

EXISTING_FILES=()
for f in "${CHECK_FILES[@]}"; do
  [[ -f "$f" ]] && EXISTING_FILES+=("$f")
done

if [[ ${#EXISTING_FILES[@]} -eq 0 ]]; then
  echo "  ❌ No setup files found (03_SetupSheets / 19_Hardening / 22_WebApp)"
  exit 1
fi

# Check 1: applySheetProtection function exists
has_protect_func=0
for check_file in "${EXISTING_FILES[@]}"; do
  if grep -qE "function\s+applySheetProtection|function\s+applySheetLevelProtection_|function\s+protectMasterSheet_" "$check_file" 2>/dev/null; then
    has_protect_func=1
    echo "  📊 Protection function in: ${check_file#$REPO/}"
    break
  fi
done

if [[ "$has_protect_func" -eq 0 ]]; then
  echo "  ❌ No applySheetProtection_UI() or applySheetLevelProtection_() function found"
  echo "  💡 Fix: Define applySheetProtection_UI() in 19_Hardening.gs that protects all master sheets"
  exit 1
fi

# Check 2: Master sheets coverage (within ±5 lines of each sheet name mention)
MASTER_SHEETS=("M_PERSON" "M_PLACE" "M_GEO_POINT" "M_DESTINATION" "M_ALIAS" "M_DAILY_JOB" "FACT_DELIVERY" "Q_REVIEW" "SYS_TH_GEO")

protected_sheets=()
unprotected_sheets=()

for sheet in "${MASTER_SHEETS[@]}"; do
  is_protected=0
  for check_file in "${EXISTING_FILES[@]}"; do
    # Find sheet name mentions and check if protect() is within ±5 lines
    sheet_lines=$(grep -n "$sheet" "$check_file" 2>/dev/null | cut -d: -f1)
    for line_no in $sheet_lines; do
      start=$((line_no - 5))
      [[ "$start" -lt 1 ]] && start=1
      end=$((line_no + 5))
      if sed -n "${start},${end}p" "$check_file" 2>/dev/null | grep -qE "protect|Protection"; then
        is_protected=1
        break 2
      fi
    done
  done

  if [[ "$is_protected" -eq 1 ]]; then
    protected_sheets+=("$sheet")
  else
    unprotected_sheets+=("$sheet")
  fi
done

echo "  📊 Protected master sheets: ${#protected_sheets[@]} / ${#MASTER_SHEETS[@]}"
echo "  📊 Protected: ${protected_sheets[*]}"
if [[ ${#unprotected_sheets[@]} -gt 0 ]]; then
  echo "  📊 Unprotected: ${unprotected_sheets[*]}"
fi

# Check 3: Q_REVIEW should use Range Protection (not full sheet protection)
qreview_range_protected=0
for check_file in "${EXISTING_FILES[@]}"; do
  if grep -q "Q_REVIEW" "$check_file" 2>/dev/null; then
    # Look for Range protection pattern near Q_REVIEW
    qreview_lines=$(grep -n "Q_REVIEW" "$check_file" 2>/dev/null | cut -d: -f1)
    for line_no in $qreview_lines; do
      start=$((line_no - 3))
      [[ "$start" -lt 1 ]] && start=1
      end=$((line_no + 5))
      if sed -n "${start},${end}p" "$check_file" 2>/dev/null | grep -qE "Range|getRange\(.*protect"; then
        qreview_range_protected=1
        break 2
      fi
    done
  fi
done

if [[ "$qreview_range_protected" -eq 1 ]]; then
  echo "  ✅ Q_REVIEW uses Range Protection (allows reviewer to edit R-V)"
else
  echo "  ⚠️  Q_REVIEW range protection not detected (reviewers may not be able to edit decisions)"
fi

# Verdict
coverage_threshold=$(( ${#MASTER_SHEETS[@]} * 7 / 10 ))  # 70% threshold
if [[ ${#protected_sheets[@]} -ge ${#MASTER_SHEETS[@]} ]]; then
  echo "  ✅ All ${#MASTER_SHEETS[@]} master sheets protected"
  exit 0
elif [[ ${#protected_sheets[@]} -ge $coverage_threshold ]]; then
  echo "  ✅ Sufficient protection (${#protected_sheets[@]}/${#MASTER_SHEETS[@]} — ≥70%)"
  exit 0
else
  echo "  ❌ Insufficient protection (${#protected_sheets[@]}/${#MASTER_SHEETS[@]} — need ≥70%)"
  echo "  💡 Fix: Add protect() calls for: ${unprotected_sheets[*]}"
  exit 1
fi
