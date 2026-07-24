#!/usr/bin/env bash
# ST-002 — Load order prefix (00-29) (Law 14)
# ตรวจว่าชื่อไฟล์ .gs ขึ้นต้นด้วย 2-digit load order (00-29)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-002: Load order prefix (Law 14)"

# Pattern: 2-digit prefix + optional letter suffix + _ + name + .gs
# v3: รองรับ suffix letter เช่น 10b_, 21b_, 22c_ (LMDS pattern)
# Allow also .html, .js for completeness
violations=0
while IFS= read -r f; do
  base=$(basename "$f")
  if [[ ! "$base" =~ ^[0-2][0-9][a-z]?_[A-Za-z][A-Za-z0-9_]*\.(gs|js|html)$ ]]; then
    echo "  ⚠️  ${f#$REPO/} — bad filename format"
    violations=$((violations + 1))
  fi
done < <(find "$REPO/src" -type f \( -name "*.gs" -o -name "*.js" -o -name "*.html" \) 2>/dev/null)

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ All files have NN_Name.ext format"
  exit 0
fi

echo ""
echo "  💡 Fix: Rename to NN_Name.gs (NN = load order 00-29)"
exit 1
