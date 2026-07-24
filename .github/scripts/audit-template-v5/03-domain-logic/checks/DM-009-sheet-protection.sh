#!/usr/bin/env bash
# DM-009 — Sheet protection (deny-by-default)
# ตรวจว่า master sheets ถูก protect ใน 03_SetupSheets.gs
# ต้องมี protect() / Protection Type
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-009: Sheet protection on master sheets"

# v3: ตรวจหลายไฟล์เพราะ LMDS กระจาย protection logic ไว้ใน:
#   - 03_SetupSheets.gs (setup)
#   - 19_Hardening.gs (applySheetProtection_UI, applySheetLevelProtection_)
#   - 22_WebApp.gs (might also reference)
# ไม่ใช่แค่ SetupSheets อย่างเดียว
CHECK_FILES=(
  "$REPO/src/O_core_system/03_SetupSheets.gs"
  "$REPO/src/O_core_system/19_Hardening.gs"
  "$REPO/src/O_core_system/22_WebApp.gs"
)

# Filter to existing files
EXISTING_FILES=()
for f in "${CHECK_FILES[@]}"; do
  [[ -f "$f" ]] && EXISTING_FILES+=("$f")
done

if [[ ${#EXISTING_FILES[@]} -eq 0 ]]; then
  echo "  ❌ None of expected setup files found (03_SetupSheets / 19_Hardening / 22_WebApp)"
  exit 1
fi

echo "  📊 Checking files: ${EXISTING_FILES[@]#$REPO/}"

# Aggregate protect count across all files
total_protect_count=0
for check_file in "${EXISTING_FILES[@]}"; do
  cnt=$(grep -cE "\.protect\(|Protection\.|protectMaster|applySheetProtection|applySheetLevelProtection" "$check_file" 2>/dev/null) || cnt=0
  cnt=${cnt//[^0-9]/}
  cnt=${cnt:-0}
  total_protect_count=$((total_protect_count + cnt))
  echo "    ${check_file#$REPO/}: $cnt protect-related calls"
done

# Check for master sheet names being protected (any file)
master_sheets=("M_PERSON" "M_PLACE" "M_GEO_POINT" "M_DESTINATION" "M_ALIAS" "M_DAILY_JOB" "FACT_DELIVERY" "Q_REVIEW")
protected=0
for sheet in "${master_sheets[@]}"; do
  for check_file in "${EXISTING_FILES[@]}"; do
    if grep -q "$sheet" "$check_file" 2>/dev/null; then
      # Look for protect/Protection within 5 lines of sheet mention
      if grep -A 5 "$sheet" "$check_file" 2>/dev/null | grep -qE "protect|Protection"; then
        protected=$((protected + 1))
        break
      fi
    fi
  done
done

echo "  📊 Total protect/Protection calls: $total_protect_count"
echo "  📊 Master sheets with protection: $protected / ${#master_sheets[@]}"

if [[ "$total_protect_count" -eq 0 ]]; then
  echo "  ⚠️  No protect() calls found in any setup file"
  echo "  💡 Fix: Add Protection helper, call on every master sheet in setupAllSheets() or applySheetProtection_UI()"
  exit 1
fi

echo "  ✅ Sheet protection in place ($total_protect_count calls across ${#EXISTING_FILES[@]} files)"
exit 0
