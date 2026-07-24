#!/usr/bin/env bash
# ST-012 — Internal link integrity in docs
# ตรวจว่า relative .md links ใน docs/ ชี้ไปยังไฟล์ที่มีอยู่จริง
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-012: Internal link integrity in docs"

if [[ ! -d "$REPO/docs" ]]; then
  echo "  ℹ️  No docs/ folder — skipping"
  exit 0
fi

violations=0
# Find all markdown links: [text](path.md) where path doesn't start with http
while IFS= read -r doc; do
  docdir=$(dirname "$doc")
  # Extract [text](relative/path.md) patterns
  links=$(grep -oE '\[[^]]+\]\(([^)]+\.md)\)' "$doc" 2>/dev/null \
    | sed -E 's/\[[^]]+\]\(([^)]+)\)/\1/' || true)

  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    # Skip absolute URLs
    if echo "$link" | grep -qE '^https?://'; then continue; fi
    # Skip anchors
    if echo "$link" | grep -qE '^#'; then continue; fi
    # Resolve relative to doc location
    target="$docdir/$link"
    # Handle ../ paths
    target=$(realpath -m "$target" 2>/dev/null || echo "$target")
    if [[ ! -f "$target" ]]; then
      echo "  ⚠️  ${doc#$REPO/} → broken link: $link"
      violations=$((violations + 1))
    fi
  done <<< "$links"
done < <(find "$REPO/docs" -name "*.md" 2>/dev/null)

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ All internal doc links resolve"
  exit 0
fi

echo ""
echo "  💡 Fix: Update path or create missing doc"
exit 1
