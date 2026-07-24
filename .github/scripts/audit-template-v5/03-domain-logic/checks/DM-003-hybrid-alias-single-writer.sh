#!/usr/bin/env bash
# DM-003 — Hybrid Alias single writer
# ตรวจว่า createGlobalAlias เป็น single entry point สำหรับเขียน M_ALIAS
# ห้ามมีการ appendRow / setValues ลง M_ALIAS นอก createGlobalAlias
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-003: Hybrid Alias single writer"

alias_file="$REPO/src/1_group1_master_db/21_AliasService.gs"

if [[ ! -f "$alias_file" ]]; then
  echo "  ❌ 21_AliasService.gs not found"
  exit 1
fi

# Check createGlobalAlias exists
if ! grep -q "createGlobalAlias" "$alias_file"; then
  echo "  ❌ createGlobalAlias not found in 21_AliasService.gs"
  exit 1
fi

# Find M_ALIAS writes outside 21_AliasService.gs
# v5 FIX: Filter out comment lines — pattern must match the `: *` or `: //` after line number
# grep -rn output format: "path:line_no:content"
# So we look for ": *" (JSDoc comment) or ": //" (single-line comment) after the line number
violations=$(grep -rn "M_ALIAS" "$REPO/src" --include="*.gs" 2>/dev/null \
  | grep -v "21_AliasService" \
  | grep -E "appendRow|setValues|setValue" \
  | grep -vE ":[0-9]+:\s*//" \
  | grep -vE ":[0-9]+:\s*\*" \
  | grep -v "Test\|Harness" || true)

if [[ -z "$violations" ]]; then
  echo "  ✅ M_ALIAS only written via 21_AliasService"
  exit 0
fi

echo "  ⚠️  M_ALIAS write outside 21_AliasService:"
echo "$violations" | head -5 | sed 's/^/    /'
echo ""
echo "  💡 Fix: Route all M_ALIAS writes through createGlobalAlias()"
exit 1
