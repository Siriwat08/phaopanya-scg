#!/usr/bin/env bash
# ST-007 — Function name uniqueness (Law 8)
# ตรวจว่าไม่มี function ที่ประกาศซ้ำในหลายไฟล์
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-007: Function name uniqueness (Law 8)"

# Extract all top-level function definitions (not ending with _ for private)
funcs=$(grep -rnE '^(function|const) +[A-Za-z][A-Za-z0-9_]*[ \t]*[=(]' "$REPO/src" --include="*.gs" 2>/dev/null \
  | sed -E 's/.*(function|const) +([A-Za-z][A-Za-z0-9_]*).*/\2/' \
  | sort)

# Count duplicates
dups=$(echo "$funcs" | sort | uniq -d)

if [[ -z "$dups" ]]; then
  echo "  ✅ All public function names are unique"
  exit 0
fi

echo "  ❌ Duplicate function names found:"
for f in $dups; do
  locations=$(grep -rnE "^(function|const) +${f}[ \t]*[=(]" "$REPO/src" --include="*.gs")
  echo "    $f:"
  echo "$locations" | sed 's/^/      /'
done
echo ""
echo "  💡 Fix: Apply namespace pattern (e.g. PersonService.findCandidates)"
exit 1
