#!/usr/bin/env bash
# Check 17 — Production Readiness (appsscript.json access + executeAs)
# ตรวจว่า appsscript.json พร้อมสำหรับ production deploy หรือยัง
#
# Returns:
#   0 = pass (production-ready, or only warnings)
#   1 = fail (not production-ready — STRICT_MODE=1 to block)
#
# Rules:
#   - access: MYSELF = warning (development only, not production)
#   - access: DOMAIN or ANYONE = OK (production-ready)
#   - executeAs: USER_DEPLOYING = info (quota shared with deployer)
#   - executeAs: USER_ACCESSING = info (each user uses own quota)

set -uo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 17: Production Readiness (appsscript.json)"

STRICT_MODE="${STRICT_MODE:-0}"

CONFIG_FILE="appsscript.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "  ℹ️  No appsscript.json found — skipping"
  exit 0
fi

# Extract access and executeAs from JSON
access=$(grep -oP '"access"\s*:\s*"\K[^"]+' "$CONFIG_FILE" 2>/dev/null || echo "")
executeAs=$(grep -oP '"executeAs"\s*:\s*"\K[^"]+' "$CONFIG_FILE" 2>/dev/null || echo "")

echo "  📊 appsscript.json settings:"
echo "     access:    ${access:-<not set>}"
echo "     executeAs: ${executeAs:-<not set>}"
echo ""

warnings=0

# Check access
case "$access" in
  MYSELF)
    echo "  ⚠️  access: MYSELF — development/staging only"
    echo "     Before production deploy, change to:"
    echo "       DOMAIN (Google Workspace) or ANYONE (public, requires Google login)"
    echo "     See SECURITY.md §3 for checklist"
    warnings=$((warnings + 1))
    ;;
  DOMAIN|ANYONE)
    echo "  ✅ access: $access — production-ready"
    ;;
  *)
    echo "  ⚠️  access: ${access:-<empty>} — unknown value"
    warnings=$((warnings + 1))
    ;;
esac

# Check executeAs (informational)
case "$executeAs" in
  USER_DEPLOYING)
    echo "  ℹ️  executeAs: USER_DEPLOYING — all users share deployer's quota"
    echo "     (OK for small team — see SECURITY.md §3 for trade-offs)"
    ;;
  USER_ACCESSING)
    echo "  ℹ️  executeAs: USER_ACCESSING — each user uses own quota"
    echo "     (Requires sharing Google Sheet with all users)"
    ;;
esac

echo ""
echo "─────────────────────────────────────"
if [[ $warnings -gt 0 ]]; then
  if [[ "$STRICT_MODE" -eq 1 ]]; then
    echo "❌ Not production-ready — fix appsscript.json before deploy"
    exit 1
  else
    echo "⚠️  Production readiness warning (STRICT_MODE=0)"
    exit 0
  fi
fi

echo "✅ Production-ready configuration"
exit 0
