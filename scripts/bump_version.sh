#!/usr/bin/env bash
# bump_version.sh — Automate version bumps across all LMDS files
# ============================================================
# Usage:
#   ./scripts/bump_version.sh 6.0.052        # bump to 6.0.052
#   ./scripts/bump_version.sh 6.0.052 --dry  # preview only, no changes
#
# What it updates:
#   1. VERSION: header in ALL .gs files (src/**/*.gs)
#   2. APP_VERSION + SCHEMA_VERSION in src/O_core_system/01_Config.gs
#   3. version field in package.json
#
# What it does NOT update (do manually):
#   - docs/CHANGELOG.md (add entry yourself)
#   - README.md stats (run check_02 to see actual numbers)
#   - Git tag (run: git tag v6.0.XXX && git push origin v6.0.XXX)
#
# After running:
#   1. bash .github/scripts/doc-code-sync-checks/check_01_version.sh
#   2. bash .github/scripts/doc-code-sync-checks/check_02_stats.sh
#   3. npx prettier --check "src/**/*.{gs,js,html,css}"
#   4. Commit with message: "chore: bump version X → Y"
# ============================================================

set -euo pipefail

# ─── Args ───
NEW_VERSION="${1:-}"
DRY_RUN=false
if [[ "${2:-}" == "--dry" || "${2:-}" == "-n" ]]; then
  DRY_RUN=true
fi

if [[ -z "$NEW_VERSION" ]]; then
  echo "❌ Usage: $0 <new-version> [--dry]"
  echo "   Example: $0 6.0.052"
  echo "   Example: $0 6.0.052 --dry"
  exit 1
fi

# Validate version format (X.Y.ZZZ)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Invalid version format: $NEW_VERSION"
  echo "   Expected: X.Y.ZZZ (e.g., 6.0.052)"
  exit 1
fi

cd "$(dirname "$0")/.."

# ─── Detect current version ───
CURRENT_VERSION=$(grep -oP "const\s+APP_VERSION\s*=\s*['\"]\K[^'\"]+" src/O_core_system/01_Config.gs || echo "")
if [[ -z "$CURRENT_VERSION" ]]; then
  echo "❌ Cannot find APP_VERSION in src/O_core_system/01_Config.gs"
  exit 1
fi

if [[ "$CURRENT_VERSION" == "$NEW_VERSION" ]]; then
  echo "⚠️  Current version is already $NEW_VERSION — nothing to do."
  exit 0
fi

echo "📋 Bumping version: $CURRENT_VERSION → $NEW_VERSION"
if $DRY_RUN; then
  echo "   (DRY RUN — no files will be modified)"
fi
echo ""

# ─── 1. Update VERSION: header in all .gs files ───
echo "── Updating VERSION: headers in .gs files ──"
GS_FILES=$(grep -rl "VERSION: $CURRENT_VERSION" src/ --include="*.gs" 2>/dev/null || echo "")
GS_COUNT=0
if [[ -n "$GS_FILES" ]]; then
  for f in $GS_FILES; do
    if $DRY_RUN; then
      echo "  [DRY] Would update: $f"
    else
      sed -i "s/VERSION: $CURRENT_VERSION/VERSION: $NEW_VERSION/g" "$f"
    fi
    GS_COUNT=$((GS_COUNT + 1))
  done
fi
echo "  → $GS_COUNT .gs files"
echo ""

# ─── 2. Update APP_VERSION + SCHEMA_VERSION in 01_Config.gs ───
echo "── Updating APP_VERSION + SCHEMA_VERSION in 01_Config.gs ──"
CONFIG_FILE="src/O_core_system/01_Config.gs"
if $DRY_RUN; then
  echo "  [DRY] Would update:"
  echo "    - APP_VERSION = '$CURRENT_VERSION' → '$NEW_VERSION'"
  echo "    - SCHEMA_VERSION = '$CURRENT_VERSION' → '$NEW_VERSION'"
else
  sed -i "s/const APP_VERSION = '$CURRENT_VERSION';/const APP_VERSION = '$NEW_VERSION';/g" "$CONFIG_FILE"
  sed -i "s/const SCHEMA_VERSION = '$CURRENT_VERSION';/const SCHEMA_VERSION = '$NEW_VERSION';/g" "$CONFIG_FILE"
  echo "  → Updated $CONFIG_FILE"
fi
echo ""

# ─── 3. Update package.json ───
echo "── Updating package.json version ──"
PKG_FILE="package.json"
if $DRY_RUN; then
  echo "  [DRY] Would update: $PKG_FILE"
else
  sed -i "s/\"version\": \"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/g" "$PKG_FILE"
  echo "  → Updated $PKG_FILE"
fi
echo ""

# ─── Summary ───
echo "═══════════════════════════════════════════════"
echo "✅ Version bump complete: $CURRENT_VERSION → $NEW_VERSION"
echo "═══════════════════════════════════════════════"
echo ""
echo "Files updated:"
echo "  - $GS_COUNT .gs files (VERSION: header)"
echo "  - 01_Config.gs (APP_VERSION + SCHEMA_VERSION)"
echo "  - package.json (version field)"
echo ""
echo "⚠️  Manual steps remaining:"
echo "  1. Add entry to docs/CHANGELOG.md"
echo "  2. Update README.md stats if file/function count changed (run check_02)"
echo "  3. Run verification:"
echo "     bash .github/scripts/doc-code-sync-checks/check_01_version.sh"
echo "     bash .github/scripts/doc-code-sync-checks/check_02_stats.sh"
echo "     npx prettier --check \"src/**/*.{gs,js,html,css}\""
echo "  4. Commit: git add -A && git commit -m 'chore: bump version $CURRENT_VERSION → $NEW_VERSION'"
echo "  5. After merge: git tag v$NEW_VERSION && git push origin v$NEW_VERSION"
