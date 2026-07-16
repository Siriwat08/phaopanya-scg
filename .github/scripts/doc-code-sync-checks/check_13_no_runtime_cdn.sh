#!/usr/bin/env bash
# Check 13 — No Runtime CDN (no @tailwindcss/browser or similar runtime compilers)
# ตรวจหา CDN แบบ runtime compilation ที่ทำให้โหลดช้า
#
# Returns:
#   0 = pass (no runtime CDN, or only warnings)
#   1 = fail (runtime CDN found — STRICT_MODE=1 to block)
#
# Known runtime compilers:
#   - @tailwindcss/browser (Tailwind v4 runtime)
#   - tailwindcss/browser (legacy)
#   - babel-standalone
#   - vue.global.js (Vue runtime)
#   - react.development.js (React dev runtime)

set -uo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 13: No Runtime CDN"

STRICT_MODE="${STRICT_MODE:-0}"

# Patterns that indicate runtime compilation
PATTERNS=(
  '@tailwindcss/browser'
  'tailwindcss/browser'
  'babel-standalone'
  'vue.global.js'
  'react.development.js'
)

found=0
for pattern in "${PATTERNS[@]}"; do
  matches=$(grep -rn "$pattern" src/ --include="*.html" 2>/dev/null | grep -v '^\s*//' | grep -v '^\s*<!--' | wc -l | tr -d ' ')
  if [[ "$matches" -gt 0 ]]; then
    echo "  ⚠️  Runtime CDN found: '$pattern' ($matches occurrence(s))"
    grep -rn "$pattern" src/ --include="*.html" 2>/dev/null | grep -v '^\s*//' | grep -v '^\s*<!--' | head -3
    found=$((found + 1))
  fi
done

echo ""
echo "─────────────────────────────────────"
if [[ $found -gt 0 ]]; then
  if [[ "$STRICT_MODE" -eq 1 ]]; then
    echo "❌ Runtime CDN found — switch to pre-compiled CSS/JS"
    exit 1
  else
    echo "⚠️  Runtime CDN found — warning (known trade-off for GAS: Tailwind v3+ has no precompiled CDN)"
    exit 0
  fi
fi

echo "✅ No runtime CDN detected"
exit 0
