#!/usr/bin/env bash
# RT-002 — No runtime CDN imports
# ตรวจว่าไม่มี <script src="https://cdn..."> ใน HTML ที่ ship ไป production
# เพราะ GAS WebApp โหลดจาก Google server, CDN อาจโดน block
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-002: No runtime CDN imports"

violations=$(grep -rnE '<script[^>]+src=["\x27]https?://(cdn|unpkg|jsdelivr|cdnjs|googleapis)' "$REPO/src" --include="*.html" 2>/dev/null || true)

count=0
if [[ -n "$violations" ]]; then
  count=$(echo "$violations" | wc -l | tr -d ' ')
fi

if [[ "$count" -eq 0 ]]; then
  echo "  ✅ No runtime CDN imports found"
  exit 0
fi

echo "  ❌ Found $count runtime CDN import(s):"
echo "$violations" | head -10 | sed 's/^/    /'
echo ""
echo "  💡 Fix: Bundle locally, or use Apps Script library"
exit 1
