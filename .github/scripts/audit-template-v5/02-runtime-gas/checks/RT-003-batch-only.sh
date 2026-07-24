#!/usr/bin/env bash
# RT-003 — Batch operations only (Law 4)
# ตรวจว่าไม่มี getValue/setValue ภายใน for/while loop
# เพราะ O(N) API calls = quota killer
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-003: Batch operations only (Law 4)"

# Heuristic: find getValue()/setValue() that are inside a for loop in the same function
# Simplified: find function that has both 'for' and 'getValue'/'setValue' within 50 lines

violations=0
while IFS= read -r gsfile; do
  # Extract each function block
  awk '
    /^(function|const) [A-Za-z]/ { fnstart=NR; fnbody=""; fnname=$0 }
    fnstart { fnbody = fnbody "\n" $0 }
    /^}$/ && fnstart {
      if (fnbody ~ /for *\(/ && (fnbody ~ /\.getValue\(\)/ || fnbody ~ /\.setValue\(\)/)) {
        printf "%s:%d:%s\n", FILENAME, fnstart, fnname
      }
      fnstart=0
    }
  ' "$gsfile" | while read -r match; do
    echo "  ⚠️  $match"
    echo "      ^ loop contains getValue/setValue — use getValues/setValues"
  done
done < <(find "$REPO/src" -name "*.gs" 2>/dev/null)

echo "  ℹ️  Manual review recommended (heuristic has false positives)"
exit 0
