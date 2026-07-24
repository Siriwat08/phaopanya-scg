#!/usr/bin/env bash
# ST-001 — GS file header complete
# ตรวจว่าทุก .gs มี /** block ที่มี VERSION, FILE, PURPOSE, CHANGELOG, DEPENDENCIES
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-001: GS file header complete (VERSION/FILE/PURPOSE/CHANGELOG/DEPENDENCIES)"

required_fields=("VERSION" "FILE" "PURPOSE" "CHANGELOG" "DEPENDENCIES")
violations=0

for f in $(find "$REPO/src" -name "*.gs" 2>/dev/null); do
  if [[ ! -s "$f" ]]; then continue; fi

  # Read first 50 lines
  header=$(head -50 "$f")

  missing=()
  for field in "${required_fields[@]}"; do
    if ! echo "$header" | grep -q "$field"; then
      missing+=("$field")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "  ⚠️  ${f#$REPO/}: missing ${missing[*]}"
    violations=$((violations + 1))
  fi
done

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ All .gs files have complete header"
  exit 0
fi

echo ""
echo "  💡 Fix: See template header in 99_Legacy.gs"
exit 1
