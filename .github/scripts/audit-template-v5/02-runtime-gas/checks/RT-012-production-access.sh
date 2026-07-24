#!/usr/bin/env bash
# RT-012 — Production access config (Check 17)
# ตรวจ appsscript.json — access ต้องเป็น DOMAIN หรือ ANYONE ไม่ใช่ MYSELF
# executeAs ควรเป็น USER_ACCESSING เพื่อกระจาย quota
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-012: Production access config (appsscript.json)"

config="$REPO/appsscript.json"

if [[ ! -f "$config" ]]; then
  echo "  ℹ️  No appsscript.json — skipping"
  exit 0
fi

access=$(grep -oP '"access"\s*:\s*"\K[^"]+' "$config" 2>/dev/null || echo "")
executeAs=$(grep -oP '"executeAs"\s*:\s*"\K[^"]+' "$config" 2>/dev/null || echo "")

echo "  📊 access:    ${access:-<not set>}"
echo "  📊 executeAs: ${executeAs:-<not set>}"

warnings=0

case "$access" in
  MYSELF)
    echo "  ❌ access: MYSELF — development/staging only"
    echo "     Fix: change to DOMAIN (Google Workspace) or ANYONE (public)"
    warnings=$((warnings + 1))
    ;;
  DOMAIN|ANYONE)
    echo "  ✅ access: $access — production-ready"
    ;;
  *)
    echo "  ⚠️  access: $access — verify this is intentional"
    warnings=$((warnings + 1))
    ;;
esac

if [[ "$warnings" -gt 0 ]]; then
  echo ""
  echo "  ❌ Not production-ready"
  exit 1
fi

echo "  ✅ Production config OK"
exit 0
