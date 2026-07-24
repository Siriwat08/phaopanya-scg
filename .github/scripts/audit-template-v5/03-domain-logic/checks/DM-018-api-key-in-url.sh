#!/usr/bin/env bash
# DM-018 — SEC-006 API key in URL (must use HTTP header)
# v5 NEW: ตรวจว่าไม่มี API key ใน URL parameter (ต้องใช้ x-goog-api-key header แทน)
#
# Rule:
#   - ห้ามส่ง API key เป็น query string parameter (เช่น ?key=AIza..., ?api_key=...)
#   - ต้องใช้ HTTP header (x-goog-api-key, Authorization: Bearer, X-API-Key)
#   - รับ exception: localhost, test fixtures, documentation strings
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-018: SEC-006 API key in URL (must use header)"

# Patterns that indicate API key in URL
URL_KEY_PATTERNS=(
  # ?key=... or &key=...
  "[?&]key=[A-Za-z0-9_-]{20,}"
  # ?api_key=... or &api_key=...
  "[?&]api_key=[A-Za-z0-9_-]{20,}"
  # ?apikey=... or &apikey=...
  "[?&]apikey=[A-Za-z0-9_-]{20,}"
  # ?access_token=... (OAuth in URL — bad practice)
  "[?&]access_token=[A-Za-z0-9_.-]{20,}"
  # Google API key in URL specifically
  "[?&]key=AIza[a-zA-Z0-9_-]{35}"
  # Stripe / AWS / GitHub tokens in URL
  "[?&](token|key)=[A-Za-z0-9_-]*(sk_live_|AKIA|gh[pousr]_)[A-Za-z0-9_-]+"
)

violations=0
files_with_urlfetch=0

while IFS= read -r gsfile; do
  if ! grep -qE "UrlFetchApp\.fetch|fetchWithRetry_" "$gsfile"; then continue; fi
  files_with_urlfetch=$((files_with_urlfetch + 1))

  for pattern in "${URL_KEY_PATTERNS[@]}"; do
    # Find matches, exclude comments and string literals with example.com
    matches=$(grep -nE "$pattern" "$gsfile" 2>/dev/null \
      | grep -vE "^\s*//" \
      | grep -vE "^\s*\*" \
      | grep -vE "example\.com|test\.com|localhost|placeholder|sample" \
      || true)

    if [[ -n "$matches" ]]; then
      while IFS= read -r line; do
        echo "  ❌ ${gsfile#$REPO/} — API key in URL detected:"
        echo "      $line" | head -c 200
        echo ""
        violations=$((violations + 1))
      done <<< "$matches"
    fi
  done
done < <(find "$REPO/src" -name "*.gs" 2>/dev/null)

# Also check HTML files (WebApp views might call external APIs)
while IFS= read -r htmlfile; do
  for pattern in "${URL_KEY_PATTERNS[@]}"; do
    matches=$(grep -nE "$pattern" "$htmlfile" 2>/dev/null \
      | grep -vE "example\.com|test\.com|localhost|placeholder|sample" \
      || true)
    if [[ -n "$matches" ]]; then
      while IFS= read -r line; do
        echo "  ❌ ${htmlfile#$REPO/} — API key in URL detected:"
        echo "      $line" | head -c 200
        echo ""
        violations=$((violations + 1))
      done <<< "$matches"
    fi
  done
done < <(find "$REPO/src" -name "*.html" 2>/dev/null)

echo "  📊 Files with UrlFetchApp/fetchWithRetry: $files_with_urlfetch"
echo "  📊 API key in URL violations: $violations"

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ No API keys passed via URL parameter (using headers correctly)"
  exit 0
fi

echo ""
echo "  💡 Fix: Move API keys from URL to HTTP headers:"
echo "      options.headers['x-goog-api-key'] = apiKey;  // for Google APIs"
echo "      options.headers['Authorization'] = 'Bearer ' + token;  // for OAuth"
echo "      options.headers['X-API-Key'] = apiKey;  // for custom APIs"
exit 1
