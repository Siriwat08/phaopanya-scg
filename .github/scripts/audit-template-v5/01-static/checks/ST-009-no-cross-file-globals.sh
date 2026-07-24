#!/usr/bin/env bash
# ST-009 — No cross-file globals (Law 9)
# ตรวจว่าไม่มี top-level non-CONFIG vars นอก 01_Config.gs
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-009: No cross-file globals (Law 9)"

# Allowed: 01_Config.gs (CONFIG namespace), constants like APP_NAME
# Forbidden: top-level mutable vars
# Heuristic: look for `let foo = ` or `var foo = ` at top-level (not inside function)

violations=0
while IFS= read -r gsfile; do
  base=$(basename "$gsfile")

  # Skip 01_Config.gs (it's allowed to have CONFIG.*)
  if [[ "$base" == "01_Config.gs" ]]; then continue; fi

  # Find top-level let/var (no leading whitespace before let/var)
  matches=$(grep -nE '^(let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' "$gsfile" 2>/dev/null || true)

  if [[ -n "$matches" ]]; then
    while IFS= read -r line; do
      # Skip if it's a const (immutable, allowed for module-level constants)
      if echo "$line" | grep -qE '^const[[:space:]]'; then continue; fi
      echo "  ⚠️  ${gsfile#$REPO/}:${line%%:*} — top-level let/var: $line"
      violations=$((violations + 1))
    done <<< "$matches"
  fi
done < <(find "$REPO/src" -name "*.gs" 2>/dev/null)

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ No cross-file mutable globals"
  exit 0
fi

echo ""
echo "  💡 Fix: Use CONFIG.* from 01_Config.gs, or pass via parameters"
exit 1
