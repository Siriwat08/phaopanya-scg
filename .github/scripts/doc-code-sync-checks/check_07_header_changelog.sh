#!/usr/bin/env bash
# Check 7 — Header CHANGELOG Sync
# ตรวจว่า CHANGELOG section ใน header ของทุกไฟล์ .gs ไม่มี "Latest N versions"
# แบบ hardcode ที่ค้างเป็นเวอร์ชันเก่า
#
# กติกา: CHANGELOG section ควรมี entries ที่สะท้อนการเปลี่ยนแปลงจริงของไฟล์
# ไม่ควรมี "Latest 3 versions" แบบ copy-paste ที่เหมือนกันทุกไฟล์
#
# Returns:
#   0 = pass (all headers have valid CHANGELOG)
#   1 = fail (some header has stale or missing CHANGELOG)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "❌ ไม่พบ repo root"; exit 1; }

STRICT_MODE="${STRICT_MODE:-0}"
FAIL_COUNT=0
WARN_COUNT=0
OK_COUNT=0

echo "📋 Check 7: Header CHANGELOG Sync"

# Get APP_VERSION for reference
CONFIG_FILE="src/O_core_system/01_Config.gs"
if [[ -f "$CONFIG_FILE" ]]; then
  APP_VERSION=$(grep -oP "const\s+APP_VERSION\s*=\s*['\"]\K[^'\"]+" "$CONFIG_FILE" || echo "UNKNOWN")
  echo "  📌 APP_VERSION: $APP_VERSION"
fi
echo ""

while IFS= read -r -d '' file; do
  fname="$(basename "$file")"

  # Extract header comment block
  header=$(awk '/^\/\*\*/{flag=1} flag{print} /^ \*\//{if(flag)exit}' "$file")

  if [[ -z "$header" ]]; then
    echo "  ⚠️  $fname: ไม่พบ header comment block"
    ((WARN_COUNT++))
    continue
  fi

  # Check CHANGELOG section exists
  if ! grep -q "CHANGELOG:" <<< "$header"; then
    echo "  ❌ $fname: ไม่มี CHANGELOG: section"
    ((FAIL_COUNT++))
    continue
  fi

  # Extract CHANGELOG block (from CHANGELOG: to next section or end of header)
  changelog_block=$(awk '/CHANGELOG:/{flag=1} flag{print} /DEPENDENCIES:|ARCHITECTURE:/{if(flag && !/CHANGELOG:/) exit}' <<< "$header")

  # Check for stale "Latest N versions" pattern
  if grep -qiE "Latest [0-9]+ versions?" <<< "$changelog_block"; then
    stale_versions=$(grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" <<< "$changelog_block" | head -3 | tr '\n' ' ')
    echo "  ⚠️  $fname: มี 'Latest N versions' แบบ hardcode ค้างอยู่ (เจอ: $stale_versions)"
    ((WARN_COUNT++))
    continue
  fi

  # Check that CHANGELOG has at least one version entry
  if ! grep -qE "v[0-9]+\.[0-9]+\.[0-9]+" <<< "$changelog_block"; then
    echo "  ⚠️  $fname: CHANGELOG section ไม่มี version entry เลย"
    ((WARN_COUNT++))
    continue
  fi

  echo "  ✅ $fname: CHANGELOG header มี entries ที่สะท้อนการเปลี่ยนแปลง"
  ((OK_COUNT++))

done < <(find src -name "*.gs" -print0 | sort -z)

echo ""
echo "─────────────────────────────────────"
echo "  ✅ ผ่าน:  $OK_COUNT ไฟล์"
echo "  ⚠️  เตือน: $WARN_COUNT ไฟล์"
echo "  ❌ ล้มเหลว: $FAIL_COUNT ไฟล์"
echo "─────────────────────────────────────"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "❌ พบไฟล์ที่ไม่มี CHANGELOG section — ต้องแก้ก่อน merge"
  exit 1
fi

if [[ "$WARN_COUNT" -gt 0 && "$STRICT_MODE" == "1" ]]; then
  echo "❌ STRICT_MODE=1: พบ $WARN_COUNT ไฟล์ที่มี stale changelog — บล็อก PR"
  exit 1
fi

if [[ "$WARN_COUNT" -gt 0 ]]; then
  echo "⚠️  พบปัญหาแต่ยังไม่บล็อก (STRICT_MODE=0) — ควรทยอยแก้"
fi

exit 0
