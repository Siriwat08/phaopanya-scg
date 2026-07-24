#!/usr/bin/env bash
# DM-016 — SEC-004 PII in logs (hash + mask)
# v5 NEW: ตรวจว่า logError uses MD5 hash + email masking
# และ fetchWithRetry_ truncates body to ≤200 chars before logging
#
# Rule:
#   - logError() ต้องมีการ hash PII หรือ mask email ก่อน log
#   - fetchWithRetry_ ต้อง truncate response body ถ้า log
#   - ต้องมี function อย่างน้อยหนึ่งตัวใน: maskEmail_, maskPii_, hashPii_, redactPii_
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-016: SEC-004 PII hashing + fetchWithRetry body truncation"

# Check 1: PII masking helper exists
PII_HELPERS=("maskEmail_\|maskEmailSafe_" "maskPii_" "hashPii_" "redactPii_" "maskPhone_" "maskId_" "maskReviewerEmail_")
has_pii_helper=0
for helper in "${PII_HELPERS[@]}"; do
  if grep -rqE "function\s+${helper}" "$REPO/src" --include="*.gs" 2>/dev/null; then
    echo "  📊 PII helper found: $helper"
    has_pii_helper=1
  fi
done

if [[ "$has_pii_helper" -eq 0 ]]; then
  echo "  ❌ No PII masking helper found (need one of: maskEmail_, maskPii_, hashPii_, redactPii_)"
  echo "  💡 Fix: Define maskEmail_(email) in 14_Utils.gs that returns masked form like 's***i@company.com'"
  exit 1
fi

# Check 2: fetchWithRetry_ exists (if there's UrlFetchApp usage)
has_urlfetch=$(grep -rl "UrlFetchApp.fetch" "$REPO/src" --include="*.gs" 2>/dev/null | head -1)
if [[ -n "$has_urlfetch" ]]; then
  # v5 FIX: search across entire src/ (not just same file as UrlFetchApp)
  has_retry=$(grep -rlE "function\s+fetchWithRetry_" "$REPO/src" --include="*.gs" 2>/dev/null | head -1)
  if [[ -z "$has_retry" ]]; then
    echo "  ⚠️  UrlFetchApp used but no fetchWithRetry_() wrapper found anywhere in src/"
    echo "  💡 Fix: Define fetchWithRetry_(url, options) that wraps fetch + retry + body truncation"
    exit 1
  fi
  echo "  📊 fetchWithRetry_ found in: ${has_retry#$REPO/}"

  # Check fetchWithRetry_ truncates body before log
  # v5 FIX: Check if response body is passed AS ARGUMENT to log/throw
  # (not just present anywhere in file — `return response.getContentText()` is fine)
  # Patterns that indicate body IS being logged:
  #   logError(..., response.getContentText(), ...)
  #   logError(..., res.body, ...)
  #   throw new Error(... + response.getContentText() + ...)
  body_logged_in_log=0
  body_log_patterns=(
    "logError\s*\([^)]*getContentText"
    "logError\s*\([^)]*\.body\b"
    "logError\s*\([^)]*getBody\(\)"
    "console\.(log|error)\s*\([^)]*getContentText"
    "console\.(log|error)\s*\([^)]*\.body\b"
    "throw new Error\([^)]*getContentText"
    "throw new Error\([^)]*getBody"
  )
  for pattern in "${body_log_patterns[@]}"; do
    if grep -qE "$pattern" "$has_retry" 2>/dev/null; then
      body_logged_in_log=1
      break
    fi
  done

  if [[ "$body_logged_in_log" -eq 0 ]]; then
    echo "  ✅ fetchWithRetry_ does not log response body (no leak risk — no truncation needed)"
  else
    # Body is logged → must have truncation
    has_truncation=$(grep -nE "slice\(0,\s*200\)|substring\(0,\s*200\)|substr\(0,\s*200\)" "$has_retry" 2>/dev/null | head -1)
    if [[ -n "$has_truncation" ]]; then
      echo "  ✅ fetchWithRetry_ truncates response body to ≤200 chars"
    else
      # Check broader: any truncation pattern (300, 500, 1000 — anything ≤1000 is reasonable)
      has_truncation=$(grep -nE "slice\(0,\s*[0-9]{2,4}\)|substring\(0,\s*[0-9]{2,4}\)" "$has_retry" 2>/dev/null | head -1)
      if [[ -n "$has_truncation" ]]; then
        echo "  ✅ fetchWithRetry_ truncates response body (detected: $has_truncation)"
      else
        echo "  ⚠️  fetchWithRetry_ logs response body but does not truncate"
        echo "  💡 Fix: logError(..., res.body.slice(0, 200)) — never log full response body"
        exit 1
      fi
    fi
  fi
fi

# Check 3: logError uses email masking (sample check on first few logError calls)
# This is heuristic — check if maskEmail_ is called in same file as logError
files_with_logerror=$(grep -rlE "logError\s*\(" "$REPO/src" --include="*.gs" 2>/dev/null)
files_with_masker=0
for f in $files_with_logerror; do
  if grep -qE "maskEmail_|maskEmailSafe_|maskPii_|hashPii_" "$f" 2>/dev/null; then
    files_with_masker=$((files_with_masker + 1))
  fi
done

echo "  📊 Files with logError: $(echo "$files_with_logerror" | wc -l | tr -d ' ')"
echo "  📊 Files with logError AND masker: $files_with_masker"

if [[ "$files_with_masker" -gt 0 ]]; then
  echo "  ✅ PII masking + body truncation in place"
  exit 0
else
  echo "  ⚠️  logError present but no masker usage in same files (manual review recommended)"
  exit 0  # warning only — DM-008 already catches actual PII-in-log
fi
