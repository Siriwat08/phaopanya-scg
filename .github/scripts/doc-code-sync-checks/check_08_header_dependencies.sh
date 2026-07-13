#!/usr/bin/env bash
# Check 8 — Header DEPENDENCIES Sync
# ตรวจว่า DEPENDENCIES section ใน header ของทุกไฟล์ .gs มีครบ
# REQUIRES + CALLED BY และไม่ว่าง
#
# Returns:
#   0 = pass (all headers have valid DEPENDENCIES)
#   1 = fail (some header missing DEPENDENCIES or sub-sections)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "❌ ไม่พบ repo root"; exit 1; }

STRICT_MODE="${STRICT_MODE:-0}"
FAIL_COUNT=0
WARN_COUNT=0
OK_COUNT=0

echo "📋 Check 8: Header DEPENDENCIES Sync"
echo ""

while IFS= read -r -d '' file; do
  fname="$(basename "$file")"

  # Extract header comment block
  header=$(awk '/^\/\*\*/{flag=1} flag{print} /^ \*\//{if(flag)exit}' "$file")

  if [[ -z "$header" ]]; then
    continue  # check_07 handles missing header
  fi

  # Check DEPENDENCIES section exists
  if ! grep -q "DEPENDENCIES:" <<< "$header"; then
    echo "  ❌ $fname: ไม่มี DEPENDENCIES: section"
    ((FAIL_COUNT++))
    continue
  fi

  # Check REQUIRES sub-section
  has_requires=false
  if grep -qi "REQUIRES:" <<< "$header"; then
    has_requires=true
  fi

  # Check CALLED BY sub-section
  has_called_by=false
  if grep -qi "CALLED BY:" <<< "$header"; then
    has_called_by=true
  fi

  if [[ "$has_requires" == false ]]; then
    echo "  ❌ $fname: ไม่มี REQUIRES: sub-section ใน DEPENDENCIES"
    ((FAIL_COUNT++))
    continue
  fi

  if [[ "$has_called_by" == false ]]; then
    echo "  ⚠️  $fname: ไม่มี CALLED BY: sub-section ใน DEPENDENCIES"
    ((WARN_COUNT++))
    continue
  fi

  echo "  ✅ $fname: DEPENDENCIES ครบ (REQUIRES + CALLED BY)"
  ((OK_COUNT++))

done < <(find src -name "*.gs" -print0 | sort -z)

echo ""
echo "─────────────────────────────────────"
echo "  ✅ ผ่าน:  $OK_COUNT ไฟล์"
echo "  ⚠️  เตือน: $WARN_COUNT ไฟล์"
echo "  ❌ ล้มเหลว: $FAIL_COUNT ไฟล์"
echo "─────────────────────────────────────"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "❌ พบไฟล์ที่ไม่มี DEPENDENCIES หรือ REQUIRES section — ต้องแก้ก่อน merge"
  exit 1
fi

if [[ "$WARN_COUNT" -gt 0 && "$STRICT_MODE" == "1" ]]; then
  echo "❌ STRICT_MODE=1: พบ $WARN_COUNT ไฟล์ที่ขาด CALLED BY — บล็อก PR"
  exit 1
fi

if [[ "$WARN_COUNT" -gt 0 ]]; then
  echo "⚠️  พบปัญหาแต่ยังไม่บล็อก (STRICT_MODE=0) — ควรทยอยแก้"
fi

exit 0
