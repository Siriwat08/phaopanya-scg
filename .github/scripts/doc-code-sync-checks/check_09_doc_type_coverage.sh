#!/usr/bin/env bash
# Check 9 — DOC-TYPE Coverage
# ตรวจว่าทุกไฟล์ .md ใน repo มี DOC-TYPE tag บรรทัดแรก
# - living: ต้อง sync กับ APP_VERSION (จะตรวจในอนาคต)
# - historical: ต้องมีบรรทัดระบุ "รายงาน ณ..."
# - ไม่มี tag เลย → FAIL (ไฟล์ใหม่ต้องประกาศตัวเอง)
#
# ไม่ใช้ whitelist รายชื่อไฟล์ — ใช้ "ไฟล์ประกาศตัวเอง" แทน
# ป้องกันไฟล์ใหม่ในอนาคตหลุดการตรวจ
#
# Returns:
#   0 = pass (all .md files have DOC-TYPE tag)
#   1 = fail (some .md file missing DOC-TYPE tag)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "❌ ไม่พบ repo root"; exit 1; }

FAIL_COUNT=0
OK_COUNT=0
LIVING_COUNT=0
HISTORICAL_COUNT=0

echo "📋 Check 9: DOC-TYPE Coverage"
echo "  📂 Scanning all .md files (excluding node_modules + .github templates)"
echo ""

# Find all .md files, exclude node_modules, .github/pull_request_template, .github/ISSUE_TEMPLATE
while IFS= read -r -d '' file; do
  fname="${file#./}"

  # Skip .github templates
  if [[ "$fname" == .github/pull_request_template.md ]] || [[ "$fname" == .github/ISSUE_TEMPLATE/* ]]; then
    continue
  fi

  # Read first 5 lines to find DOC-TYPE tag
  first_lines=$(head -5 "$file")

  if echo "$first_lines" | grep -q "<!-- DOC-TYPE: living -->"; then
    ((LIVING_COUNT++))
    ((OK_COUNT++))
  elif echo "$first_lines" | grep -q "<!-- DOC-TYPE: historical -->"; then
    ((HISTORICAL_COUNT++))
    ((OK_COUNT++))
  else
    echo "  ❌ $fname: ไม่มี DOC-TYPE tag — ไฟล์ .md ใหม่ต้องระบุ DOC-TYPE ก่อน merge"
    echo "      💡 เพิ่มบรรทัดแรก: <!-- DOC-TYPE: living --> หรือ <!-- DOC-TYPE: historical -->"
    ((FAIL_COUNT++))
  fi

done < <(find . -name "*.md" -not -path "./node_modules/*" -print0 | sort -z)

echo ""
echo "─────────────────────────────────────"
echo "  ✅ ผ่าน:     $OK_COUNT ไฟล์"
echo "  📄 Living:    $LIVING_COUNT ไฟล์"
echo "  📚 Historical: $HISTORICAL_COUNT ไฟล์"
echo "  ❌ ล้มเหลว:  $FAIL_COUNT ไฟล์ (ไม่มี DOC-TYPE tag)"
echo "─────────────────────────────────────"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "❌ พบ $FAIL_COUNT ไฟล์ .md ที่ไม่มี DOC-TYPE tag — ต้องเติมก่อน merge"
  exit 1
fi

echo "✅ ทุกไฟล์ .md มี DOC-TYPE tag ครบ"
exit 0
