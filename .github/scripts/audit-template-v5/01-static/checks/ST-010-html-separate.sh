#!/usr/bin/env bash
# ST-010 — HTML files separate (Law 11)
# ตรวจว่าไม่มี HTML literals ยาวๆ ใน .gs
# ทุก HTML ต้องอยู่ใน .html file แยก แล้วเรียกด้วย createHtmlOutputFromFile
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-010: HTML files separate (Law 11)"

# Heuristic: find string literals containing <html, <body, <div with attributes
# in .gs files
violations=0
while IFS= read -r gsfile; do
  # Look for createHtmlOutput( with multi-line string starting with <
  matches=$(grep -nE "createHtmlOutput\s*\(\s*['\"]<\s*(html|body|div|script|style)" "$gsfile" 2>/dev/null || true)
  if [[ -n "$matches" ]]; then
    echo "  ⚠️  ${gsfile#$REPO/} — inline HTML in createHtmlOutput:"
    echo "$matches" | head -3 | sed 's/^/      /'
    violations=$((violations + 1))
  fi
done < <(find "$REPO/src" -name "*.gs" 2>/dev/null)

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ No inline HTML in .gs files"
  exit 0
fi

echo ""
echo "  💡 Fix: Move HTML to .html file, use createHtmlOutputFromFile('name')"
exit 1
