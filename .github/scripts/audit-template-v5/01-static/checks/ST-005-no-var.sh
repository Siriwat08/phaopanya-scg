#!/usr/bin/env bash
# ST-005 — No var keyword (Law 1)
# ตรวจว่าไม่มี 'var' ในโค้ด (ใช้ const/let แทน)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-005: No var keyword (Law 1)"

# Find 'var ' not in comments, not in strings
# Pattern: ^var or whitespace + var (declaration), not 'variant' etc
# Skip lines starting with // or *
violations=$(grep -rnE '^[[:space:]]*var[[:space:]]+[A-Za-z_]' "$REPO/src" --include="*.gs" 2>/dev/null \
  | grep -vE '^\s*//' \
  | grep -vE '^\s*\*' || true)

count=0
if [[ -n "$violations" ]]; then
  count=$(echo "$violations" | wc -l | tr -d ' ')
fi

if [[ "$count" -eq 0 ]]; then
  echo "  ✅ No var declarations found"
  exit 0
fi

echo "  ⚠️  Found $count 'var' usage(s):"
echo "$violations" | head -10 | sed 's/^/    /'
echo ""
echo "  💡 Fix: Replace 'var x' with 'const x' or 'let x'"
exit 1
