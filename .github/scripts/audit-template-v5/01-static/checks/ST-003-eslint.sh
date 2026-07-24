#!/usr/bin/env bash
# ST-003 — ESLint 0 errors
# ตรวจว่า ESLint ผ่าน 0 errors (ไม่บล็อก warning)
# ใช้กับ .eslintrc.yml ของ LMDS
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-003: ESLint passes with 0 errors"

# Skip if no package.json or node_modules
if [[ ! -f "$REPO/package.json" ]]; then
  echo "  ℹ️  No package.json — skipping"
  exit 0
fi

if [[ ! -d "$REPO/node_modules" ]]; then
  echo "  ℹ️  No node_modules — skipping (run npm install first)"
  exit 0
fi

cd "$REPO"

# Run eslint; ignore warnings, only fail on errors
if npx eslint src/ --ext .gs,.js,.html --quiet 2>/dev/null; then
  echo "  ✅ ESLint 0 errors"
  exit 0
fi

echo "  ❌ ESLint found errors"
echo "  💡 Fix: Run 'npm run lint:fix' then review remaining errors"
exit 1
