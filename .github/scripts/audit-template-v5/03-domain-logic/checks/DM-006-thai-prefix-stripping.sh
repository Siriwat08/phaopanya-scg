#!/usr/bin/env bash
# DM-006 — Thai prefix stripping (80+ patterns)
# ตรวจว่า 05_NormalizeService.gs มี prefix patterns ครบ
# ต้องมี คุณ, นาย, นาง, บริษัท, หจก, ห้างหุ้นส่วน อย่างน้อย
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-006: Thai prefix stripping (Thai data helper)"

norm_file="$REPO/src/1_group1_master_db/05_NormalizeService.gs"

if [[ ! -f "$norm_file" ]]; then
  echo "  ❌ 05_NormalizeService.gs not found"
  exit 1
fi

# Required Thai prefixes
required=("คุณ" "นาย" "นาง" "น.ส." "บริษัท" "หจก" "ห้างหุ้นส่วน")

missing=()
for prefix in "${required[@]}"; do
  if ! grep -q "$prefix" "$norm_file"; then
    missing+=("$prefix")
  fi
done

# Count total prefix patterns (rough)
prefix_count=$(grep -cE "['\"]\s*[ก-๛]" "$norm_file" 2>/dev/null) || prefix_count=0

echo "  📊 Total Thai string literals (rough count): $prefix_count"

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "  ⚠️  Missing required Thai prefixes: ${missing[*]}"
  echo "  💡 Fix: Add missing prefix to normalizeForCompare() pattern array"
  exit 1
fi

echo "  ✅ Thai prefix stripping looks complete"
exit 0
