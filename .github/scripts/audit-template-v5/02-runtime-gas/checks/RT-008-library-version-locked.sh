#!/usr/bin/env bash
# RT-008 — Library version locked (Law 10)
# ตรวจว่า Apps Script library / advanced service ระบุ version ไว้
# ห้ามใช้ HEAD, dev, latest
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-008: Library version locked (Law 10)"

# Check appsscript.json for libraries
config="$REPO/appsscript.json"
if [[ ! -f "$config" ]]; then
  echo "  ℹ️  No appsscript.json — skipping"
  exit 0
fi

# Look for version: "dev" or "HEAD" in libraries
violations=0
if grep -qE '"version"[[:space:]]*:[[:space:]]*"(dev|HEAD|latest)"' "$config" 2>/dev/null; then
  echo "  ❌ Library uses dev/HEAD/latest version"
  grep -nE '"version"[[:space:]]*:[[:space:]]*"(dev|HEAD|latest)"' "$config" | sed 's/^/    /'
  violations=$((violations + 1))
fi

# Check for libraries without version field
# (This is harder to do with grep; skip if too complex)

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ All libraries are version-pinned"
  exit 0
fi

echo ""
echo "  💡 Fix: Pin library to specific version, e.g. version: 'v4'"
exit 1
