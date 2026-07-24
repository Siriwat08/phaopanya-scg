#!/usr/bin/env bash
# DM-019 — SEC-009 RFC 6265 cookie regex compliance
# v5 NEW: ตรวจว่า sanitizeCookie_ uses RFC 6265 compliant regex
# (not custom/loose regex that may allow injection)
#
# RFC 6265 allowed characters:
#   cookie-name: A-Z a-z 0-9 !#$%&'*+.^_`|-
#   cookie-value: A-Z a-z 0-9 !#$%&'*+.^_`|~  (also octets outside this set are allowed but quoted)
#   forbidden: ; , " \ and control chars (0x00-0x1F, 0x7F)
#
# Rule:
#   - sanitizeCookie_ ต้องมี regex pattern ที่ reject ; , " \ และ control chars
#   - ห้ามใช้ simple replace เช่น value.replace(';', '') (too loose)
#   - แนะนำ: const RFC_6265_COOKIE_REGEX = /^[^\x00-\x1F\x7F;, "\]+$/;
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-019: SEC-009 RFC 6265 cookie regex compliance"

# Find sanitizeCookie_ function definition
sanitize_files=$(grep -rlE "function\s+sanitizeCookie_" "$REPO/src" --include="*.gs" 2>/dev/null)

if [[ -z "$sanitize_files" ]]; then
  echo "  ❌ No sanitizeCookie_() function found"
  echo "  💡 Fix: Define sanitizeCookie_(raw) with RFC 6265 regex"
  exit 1
fi

# Patterns indicating RFC 6265 compliance
RFC_COMPLIANT_PATTERNS=(
  "RFC_6265"
  "RFC6265"
  # Hex escapes for control chars (0x00-0x1F = \x00-\x1F, 0x7F = \x7F)
  "\\\\x00-\\\\x1F"
  "\\\\x7F"
  # Explicit forbidden chars list
  '[;, "\\]'
  # RegExp constructor with character class
  "new RegExp\\([\"']\\^\\["  # new RegExp("^[
  # replace with strict regex
  "replace\\s*\\(\\s*/\\^"  # replace(/^
)

issues=0
compliant_files=0

for sanitize_file in $sanitize_files; do
  echo "  📊 Checking: ${sanitize_file#$REPO/}"

  # Find the function body (between function declaration and next function or EOF)
  func_start=$(grep -n "function\s*sanitizeCookie_" "$sanitize_file" 2>/dev/null | head -1 | cut -d: -f1)
  if [[ -z "$func_start" ]]; then continue; fi

  # Read ~30 lines after function start
  func_body=$(sed -n "${func_start},$((func_start + 30))p" "$sanitize_file" 2>/dev/null)

  # Check for RFC 6265 compliance indicators
  has_compliance=0
  for pattern in "${RFC_COMPLIANT_PATTERNS[@]}"; do
    if echo "$func_body" | grep -qE "$pattern"; then
      echo "    ✅ Found RFC 6265 indicator: $pattern"
      has_compliance=1
    fi
  done

  # Anti-pattern: simple replace (not RFC compliant)
  if echo "$func_body" | grep -qE "value\.replace\(['\"][,;'\"]" ; then
    echo "    ⚠️  Simple replace detected — not RFC 6265 compliant"
    echo "    💡 Use regex pattern: const RFC_6265_COOKIE_REGEX = /^[^\\x00-\\x1F\\x7F;, \"\\\\]+$/;"
    issues=$((issues + 1))
    has_compliance=0
  fi

  if [[ "$has_compliance" -eq 1 ]]; then
    compliant_files=$((compliant_files + 1))
  else
    issues=$((issues + 1))
  fi
done

echo ""
echo "  📊 sanitizeCookie_ files: $(echo "$sanitize_files" | wc -l | tr -d ' ')"
echo "  📊 RFC 6265 compliant: $compliant_files"
echo "  📊 Issues: $issues"

if [[ "$compliant_files" -gt 0 ]] && [[ "$issues" -eq 0 ]]; then
  echo "  ✅ Cookie sanitization uses RFC 6265 compliant regex"
  exit 0
fi

if [[ "$issues" -gt 0 ]]; then
  echo ""
  echo "  ⚠️  Cookie sanitization may not be RFC 6265 compliant"
  echo "  💡 Define a strict regex:"
  echo '      const RFC_6265_COOKIE_REGEX = /^[^\x00-\x1F\x7F;, "\]+$/;'
  echo '      function sanitizeCookie_(raw) {'
  echo '        if (typeof raw !== "string") return "";'
  echo '        return raw.match(RFC_6265_COOKIE_REGEX) ? raw : "";'
  echo '      }'
  exit 1
fi

echo "  ✅ Cookie sanitization in place"
exit 0
