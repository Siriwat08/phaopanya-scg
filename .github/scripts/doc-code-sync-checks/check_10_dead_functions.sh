#!/usr/bin/env bash
# Check 10 — Dead Functions (functions with 0 callers)
# ตรวจหา function ที่ไม่มี caller ใน codebase (potential dead code)
#
# Returns:
#   0 = pass (no dead functions, or only warnings)
#   1 = fail (dead functions found — STRICT_MODE=1 to block)
#
# Notes:
#   - Excludes entry points (doGet, doGet, onEdit, onInstall, menu callbacks _UI)
#   - Excludes functions called via string (globalThis[fn], eval) — can't detect
#   - This is a WARNING check by default (STRICT_MODE=0)

set -uo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 10: Dead Functions (zero callers)"

STRICT_MODE="${STRICT_MODE:-0}"

# Get all function definitions
FUNCS=$(grep -rohE "^function [a-zA-Z_][a-zA-Z0-9_]*" src/ --include="*.gs" 2>/dev/null | sed 's/^function //' | sort -u)

if [[ -z "$FUNCS" ]]; then
  echo "  ℹ️  No functions found"
  exit 0
fi

# Patterns to exclude (entry points that are called by GAS, not by code)
EXCLUDE_PATTERN='_UI$|^doGet$|^doPost$|^onEdit$|^onInstall$|^onOpen$|^include$'

dead_count=0
total_count=0

while IFS= read -r func; do
  # Skip excluded patterns
  if echo "$func" | grep -qE "$EXCLUDE_PATTERN"; then
    continue
  fi

  total_count=$((total_count + 1))

  # Count callers: grep for funcname( but NOT the definition line
  callers=$(grep -rn "$func(" src/ --include="*.gs" 2>/dev/null | grep -v "^.*:function $func" | wc -l | tr -d ' ')

  if [[ "$callers" -eq 0 ]]; then
    # Also check .html files (google.script.run calls)
    html_callers=$(grep -rn "$func" src/ --include="*.html" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$html_callers" -eq 0 ]]; then
      echo "  ⚠️  Dead function: $func (0 callers in .gs + .html)"
      dead_count=$((dead_count + 1))
    fi
  fi
done <<< "$FUNCS"

echo ""
echo "─────────────────────────────────────"
echo "  Scanned: $total_count functions"
echo "  Dead:    $dead_count functions"
echo "─────────────────────────────────────"

if [[ $dead_count -gt 0 ]]; then
  if [[ "$STRICT_MODE" -eq 1 ]]; then
    echo "❌ Dead functions found — remove or mark with @deprecated"
    exit 1
  else
    echo "⚠️  Dead functions found — warning (STRICT_MODE=0)"
    exit 0
  fi
fi

echo "✅ No dead functions detected"
exit 0
