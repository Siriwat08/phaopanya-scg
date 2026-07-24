#!/usr/bin/env bash
# DM-015 — SEC-003 Cookie CRLF injection prevention
# v5 NEW: ตรวจว่ามี sanitizeCookie_() function และใช้ RFC 6265 regex
# และทุก cookie setter เรียก sanitize ก่อน
#
# Rule:
#   - ต้องมี function sanitizeCookie_() ใน codebase
#   - ต้องมี RFC 6265 regex pattern (cookie-name / cookie-value pattern)
#   - ทุกที่ที่ set cookie ต้องผ่าน sanitizeCookie_() ก่อน
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-015: SEC-003 Cookie CRLF injection prevention"

# Check 1: sanitizeCookie_ function exists
sanitize_func=$(grep -rlE "function\s+sanitizeCookie_" "$REPO/src" --include="*.gs" 2>/dev/null | head -1)
if [[ -z "$sanitize_func" ]]; then
  echo "  ❌ No sanitizeCookie_() function found in src/"
  echo "  💡 Fix: Define sanitizeCookie_(raw) in 14_Utils.gs using RFC 6265 regex"
  exit 1
fi
echo "  📊 sanitizeCookie_ found in: ${sanitize_func#$REPO/}"

# Check 2: RFC 6265 regex pattern present (avoid backtick in pattern to prevent bash parsing issues)
has_rfc_regex=$(grep -rE "RFC_6265|RFC6265|cookie-value.*replace|sanitize.*cookie" \
  "$REPO/src" --include="*.gs" 2>/dev/null | head -3)
if [[ -z "$has_rfc_regex" ]]; then
  # Try alternative: look for cookie-value character class pattern
  has_rfc_regex=$(grep -rlE "cookie[-_]?value\s*[:=].*replace|sanitize.*cookie" \
    "$REPO/src" --include="*.gs" 2>/dev/null | head -1)
fi

if [[ -n "$has_rfc_regex" ]]; then
  echo "  ✅ RFC 6265 cookie sanitization pattern detected"
else
  echo "  ⚠️  No RFC 6265 regex pattern detected — verify sanitizeCookie_ uses proper character class"
  echo "  💡 RFC 6265 cookie-value allowed chars: A-Z a-z 0-9 !#$%&'*+.^_\`|~-"
fi

# Check 3: Cookie setters use sanitizeCookie_
# Find all places that set/get cookies — should call sanitizeCookie_
cookie_setters=$(grep -rnE "setHeader\(['\"]set-cookie|setCookie|\.cookie\s*=" \
  "$REPO/src" --include="*.gs" 2>/dev/null \
  | grep -v "//" | grep -v sanitizeCookie_ || true)

if [[ -n "$cookie_setters" ]]; then
  unsanitized=0
  while IFS= read -r line; do
    file_line=$(echo "$line" | cut -d: -f1-2)
    # Check if this line calls sanitizeCookie_ within ±2 lines
    file=$(echo "$file_line" | cut -d: -f1)
    line_no=$(echo "$file_line" | cut -d: -f2)
    start=$((line_no - 2))
    [[ "$start" -lt 1 ]] && start=1
    end=$((line_no + 2))

    if ! sed -n "${start},${end}p" "$file" 2>/dev/null | grep -qE "sanitizeCookie_"; then
      echo "  ⚠️  ${file#$REPO/}:$line_no — cookie set without sanitizeCookie_"
      unsanitized=$((unsanitized + 1))
    fi
  done <<< "$cookie_setters"

  if [[ "$unsanitized" -gt 0 ]]; then
    echo ""
    echo "  💡 Fix: Wrap every cookie set with sanitizeCookie_(value)"
    exit 1
  fi
fi

echo "  ✅ Cookie sanitization in place"
exit 0
