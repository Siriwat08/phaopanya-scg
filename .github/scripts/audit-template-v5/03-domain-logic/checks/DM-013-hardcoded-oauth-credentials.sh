#!/usr/bin/env bash
# DM-013 — SEC-001 Hardcoded OAuth credentials
# v4 NEW: ตรวจว่าไม่มี OAuth client_id, client_secret, refresh_token, API key
# ใน source code (hardcoded)
#
# Rule:
#   - ห้ามมี client_secret, refresh_token, access_token เป็น literal string
#   - อนุญาตให้มี client_id (เพราะเป็น public identifier) แต่ต้องมาจาก PropertiesService
#   - ห้ามมี API key pattern (sk_live_..., AKIA..., etc.)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-013: SEC-001 Hardcoded OAuth credentials"

# Patterns that indicate hardcoded secrets
# (case-insensitive, but excludes comments and PropertiesService.get calls)
SECRET_PATTERNS=(
  "client_secret\s*[:=]\s*['\"][a-zA-Z0-9_-]{20,}['\"]"
  "refresh_token\s*[:=]\s*['\"][a-zA-Z0-9_.-]{30,}['\"]"
  "access_token\s*[:=]\s*['\"][a-zA-Z0-9_.-]{30,}['\"]"
  "api_key\s*[:=]\s*['\"][a-zA-Z0-9_-]{20,}['\"]"
  "apikey\s*[:=]\s*['\"][a-zA-Z0-9_-]{20,}['\"]"
  "secret_key\s*[:=]\s*['\"][a-zA-Z0-9_-]{20,}['\"]"
  # Common API key prefixes
  "['\"]sk_live_[a-zA-Z0-9]{20,}['\"]"           # Stripe live key
  "['\"]AKIA[A-Z0-9]{16}['\"]"                   # AWS access key
  "['\"]AIza[a-zA-Z0-9_-]{35}['\"]"              # Google API key
  "['\"]gh[pousr]_[A-Za-z0-9]{36,}['\"]"         # GitHub token
  "['\"]xox[baprs]-[A-Za-z0-9-]{10,}['\"]"       # Slack token
)

violations=0
files_scanned=0

while IFS= read -r gsfile; do
  files_scanned=$((files_scanned + 1))
  base=$(basename "$gsfile")

  # Skip test/harness files (may have test fixtures)
  if echo "$base" | grep -qE "Test|Harness|Snapshot|Legacy|Mock|Fixture"; then continue; fi

  for pattern in "${SECRET_PATTERNS[@]}"; do
    # Find matches, excluding comments and PropertiesService.getScriptProperties calls
    matches=$(grep -nE "$pattern" "$gsfile" 2>/dev/null \
      | grep -vE "^\s*//" \
      | grep -vE "^\s*\*" \
      | grep -vE "getScriptProperties\(\)\.(getProperty|get)" \
      || true)

    if [[ -n "$matches" ]]; then
      while IFS= read -r line; do
        echo "  ❌ ${gsfile#$REPO/} — hardcoded secret detected:"
        echo "      $line" | head -c 200
        echo ""
        violations=$((violations + 1))
      done <<< "$matches"
    fi
  done
done < <(find "$REPO/src" -name "*.gs" 2>/dev/null)

# Also check .env files (should not exist in committed code)
while IFS= read -r envfile; do
  if [[ -f "$envfile" ]]; then
    echo "  ❌ ${envfile#$REPO/} — .env file committed to repo (should be in .gitignore)"
    violations=$((violations + 1))
  fi
done < <(find "$REPO" -maxdepth 3 -name ".env" -o -name ".env.local" -o -name ".env.production" 2>/dev/null)

echo ""
echo "  📊 Files scanned: $files_scanned"
echo "  📊 Hardcoded secrets found: $violations"

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ No hardcoded OAuth credentials or API keys detected"
  exit 0
fi

echo ""
echo "  💡 Fix: Move secrets to PropertiesService and access via:"
echo "      const clientSecret = PropertiesService.getScriptProperties().getProperty('OAUTH_CLIENT_SECRET');"
echo "  ℹ️  Run DM-007 (gitleaks) for thorough scan if installed"
exit 1
