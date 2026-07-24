#!/usr/bin/env bash
# DM-008 — PII masking in logs (SEC-008)
# v4: ตรวจเฉพาะไฟล์ที่จริงๆ log PII fields (phone/email/citizenId/address/...)
# ไม่ใช่ทุกไฟล์ที่มี logError — ลด false positive จาก 8 → ~0
#
# Strategy:
#   1. Find files with logError/console.log calls
#   2. Within +/- 2 lines of each log call, look for PII field names
#   3. If PII field found near log AND no masker pattern → flag
#   4. If no PII field near log → safe (skip)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-008: PII masking in logs (SEC-008)"

# v4: mask patterns ขยายครอบคลุม helper ที่ LMDS จริงใช้ + ทั่วไป
MASK_PATTERN="maskPii_|maskPhone_|maskId_|maskEmail|maskSearchQuery|maskReviewer|sanitizeForSheet|sanitizeRow|sanitizeCookie|sanitizeUser|sanitizeInput|redactPii|hidePii|filterPii"

# v4: PII field patterns (case-insensitive) — ใช้ตรวจว่ามี PII ในบริบท log จริงไหม
PII_FIELDS="phone|mobile|tel|email|citizenId|idCard|id_card|nationalId|national_id|passport|address|addr|street|password|passwd|secret|token|apiKey|api_key|oauth|refreshToken|accessToken|sessionKey|ssn|dob|birthDate|birth_date|firstName|lastName|full_name|fullName|personalId"

# Find logError calls and check surrounding context for PII fields
violations=0
files_with_logging=0
files_with_pii_log=0
files_with_masker=0

while IFS= read -r gsfile; do
  if ! grep -qE "logError|console\.(log|error|warn)" "$gsfile"; then continue; fi
  files_with_logging=$((files_with_logging + 1))

  # v4: Check if file uses any mask function (broad search)
  if grep -qE "$MASK_PATTERN" "$gsfile"; then
    files_with_masker=$((files_with_masker + 1))
    continue
  fi

  # v4: Check if file actually logs PII fields (within +/- 2 lines of log call)
  # Get line numbers of log calls
  log_lines=$(grep -nE "logError|console\.(log|error|warn)" "$gsfile" 2>/dev/null | cut -d: -f1)

  pii_in_log_context=0
  for line_no in $log_lines; do
    # Extract context: 2 lines before to 2 lines after
    start=$((line_no - 2))
    [[ "$start" -lt 1 ]] && start=1
    end=$((line_no + 2))
    context=$(sed -n "${start},${end}p" "$gsfile" 2>/dev/null)

    # v4 refined: Look for PII fields being PASSED to log (not just mentioned)
    # Patterns that indicate PII is being logged:
    #   logError(..., phone, ...)
    #   logError(..., user.phone, ...)
    #   logError(..., 'phone: ' + phone, ...)
    #   logError(..., `phone: ${phone}`, ...)
    # Exclude: map[email] (dict access), this.email (property access in non-log context)
    if echo "$context" | grep -qE "(logError|console\.(log|error|warn)).*(\\\$\\{|\\+|,)[[:space:]]*[a-zA-Z_]*\\.?\\b($PII_FIELDS)\\b"; then
      pii_in_log_context=1
      offending_line=$(echo "$context" | grep -iE "\b($PII_FIELDS)\b" | head -1)
      echo "  ⚠️  ${gsfile#$REPO/}:$line_no — logs PII without mask helper"
      echo "      → $offending_line" | head -c 200
      echo ""
      break
    fi
    # Also catch: logError(..., phone.toString(), ...) or logError(..., phone, ...)
    # where PII field is directly passed as argument
    if echo "$context" | grep -qE "(logError|console\.(log|error|warn))\\s*\\([^)]*\\b($PII_FIELDS)\\b"; then
      # But exclude dict access: map[email], obj['phone'], etc.
      if ! echo "$context" | grep -qE "(map|dict|obj|hash)\\[($PII_FIELDS)\\]"; then
        pii_in_log_context=1
        offending_line=$(echo "$context" | grep -iE "\b($PII_FIELDS)\b" | head -1)
        echo "  ⚠️  ${gsfile#$REPO/}:$line_no — logs PII without mask helper"
        echo "      → $offending_line" | head -c 200
        echo ""
        break
      fi
    fi
  done

  if [[ "$pii_in_log_context" -eq 1 ]]; then
    files_with_pii_log=$((files_with_pii_log + 1))
    violations=$((violations + 1))
  fi
done < <(find "$REPO/src" -name "*.gs" 2>/dev/null)

echo "  📊 Files with logging: $files_with_logging"
echo "  📊 Files with mask helper: $files_with_masker"
echo "  📊 Files logging PII without masker: $files_with_pii_log"

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ No PII logging without masker detected"
  exit 0
fi

echo ""
echo "  💡 Fix: Use one of: maskEmailSafe_, maskSearchQuery_, maskReviewerEmail_, sanitizeForSheet_, sanitizeCookie_, or maskPii_"
echo "  ℹ️  v4 heuristic: only flags files that actually log PII fields (phone/email/id/address/etc.) within ±2 lines of log call"
exit 1
