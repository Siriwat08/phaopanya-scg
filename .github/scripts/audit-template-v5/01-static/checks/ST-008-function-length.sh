#!/usr/bin/env bash
# ST-008 — Function length ≤ 100 lines (Law 2 / SRP)
# v4: ปรับ awk heuristic ให้แม่นยำขึ้น
#   - นับเฉพาะ `function name(...)` declarations (ไม่นับ const X = Object.freeze({...}))
#   - ใช้ brace depth tracking ที่ถูกต้อง
#   - ข้าม const/let/var blocks ที่ไม่ใช่ function
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-008: Function length ≤ 100 lines (Law 2)"

MAX_LINES=100
violations=0
files_checked=0

while IFS= read -r gsfile; do
  files_checked=$((files_checked + 1))

  # v4: awk script ที่ track function blocks อย่างถูกต้อง
  # - เริ่มนับเมื่อเจอ `function name(...)` ที่ start of line (จริงๆ หรือ leading whitespace นิดหน่อย)
  # - ข้าม `const X = ...` และ `Object.freeze({...})` blocks
  # - ใช้ brace depth เพื่อจำกัดขอบเขต function
  awk -v max="$MAX_LINES" -v file="$gsfile" '
    # Match function declaration: function name(...) { — at start of line or with small indent
    /^[[:space:]]*function[[:space:]]+[A-Za-z_]/ && /\{/ {
      fnstart = NR
      fnname = $0
      gsub(/^[[:space:]]+/, "", fnname)
      # Count braces on this line
      depth = gsub(/\{/, "{") - gsub(/\}/, "}")
      if (depth < 0) depth = 0
      # If function ends on same line (one-liner), skip
      if (depth == 0) {
        fnstart = 0
        next
      }
      next
    }

    # Inside a function — track brace depth
    fnstart > 0 {
      # Skip comment lines and string-only lines (rough)
      if ($0 ~ /^[[:space:]]*\/\//) next
      if ($0 ~ /^[[:space:]]*\*/) next

      opens = gsub(/\{/, "{")
      closes = gsub(/\}/, "}")
      depth += opens - closes

      if (depth <= 0) {
        # Function ended
        len = NR - fnstart + 1
        if (len > max) {
          printf "  ⚠️  %s:%d:%d: %s\n", file, fnstart, len, fnname
          printf "      ^ function > %d lines, split per SRP\n", max
        }
        fnstart = 0
        depth = 0
      }
    }
  ' "$gsfile" 2>/dev/null

  # Count violations from awk output (rough — count warning lines)
  cnt=$(awk -v max="$MAX_LINES" -v file="$gsfile" '
    /^[[:space:]]*function[[:space:]]+[A-Za-z_]/ && /\{/ {
      fnstart = NR
      depth = gsub(/\{/, "{") - gsub(/\}/, "}")
      if (depth < 0) depth = 0
      if (depth == 0) { fnstart = 0; next }
      next
    }
    fnstart > 0 {
      if ($0 ~ /^[[:space:]]*\/\//) next
      if ($0 ~ /^[[:space:]]*\*/) next
      depth += gsub(/\{/, "{") - gsub(/\}/, "}")
      if (depth <= 0) {
        len = NR - fnstart + 1
        if (len > max) print "X"
        fnstart = 0
      }
    }
  ' "$gsfile" 2>/dev/null | wc -l | tr -d ' ')

  cnt=${cnt:-0}
  violations=$((violations + cnt))

done < <(find "$REPO/src" -name "*.gs" 2>/dev/null)

echo "  📊 Files checked: $files_checked"
echo "  📊 Functions > $MAX_LINES lines: $violations"

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ All functions are ≤ $MAX_LINES lines"
  exit 0
fi

echo ""
echo "  💡 Fix: Split long functions per Single Responsibility Principle"
echo "  ℹ️  Use lmds-refactor-advisor to plan split"
exit 1
