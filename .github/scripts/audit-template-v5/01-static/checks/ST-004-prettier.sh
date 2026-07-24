#!/usr/bin/env bash
# ST-004 — Prettier formatting
# ตรวจว่า Prettier format ถูกต้อง
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-004: Prettier formatting"

if [[ ! -f "$REPO/package.json" ]] || [[ ! -d "$REPO/node_modules" ]]; then
  echo "  ℹ️  No package.json/node_modules — skipping"
  exit 0
fi

cd "$REPO"

if npx prettier --check "src/**/*.{gs,js,html,css}" 2>/dev/null; then
  echo "  ✅ Prettier OK"
  exit 0
fi

echo "  ❌ Prettier found formatting issues"
echo "  💡 Fix: Run 'npm run format'"
exit 1
