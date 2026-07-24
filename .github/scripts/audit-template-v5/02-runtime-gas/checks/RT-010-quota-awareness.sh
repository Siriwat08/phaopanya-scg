#!/usr/bin/env bash
# RT-010 — Quota awareness
# ตรวจว่ามี quota counter หรือ throttle logic
# โดยเฉพาะ UrlFetch quota (20K/day)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-010: Quota awareness"

# Look for quota counter or throttle logic
# Patterns: 'quota', 'count++', 'rateLimit', 'backoff'

has_quota_tracker=$(grep -rlE "quota|rateLimit|backoff|retry.*delay" "$REPO/src" --include="*.gs" 2>/dev/null | wc -l | tr -d ' ')

# Count UrlFetchApp usages
urlfetch_count=$(grep -rlE "UrlFetchApp\.fetch" "$REPO/src" --include="*.gs" 2>/dev/null | wc -l | tr -d ' ')

echo "  📊 Files with quota/throttle logic: $has_quota_tracker"
echo "  📊 Files with UrlFetchApp: $urlfetch_count"

if [[ "$urlfetch_count" -gt 0 ]] && [[ "$has_quota_tracker" -eq 0 ]]; then
  echo "  ⚠️  Has UrlFetchApp but no quota/throttle logic"
  echo "  💡 Fix: Add quota counter (PropertiesService) + abort at 80% of daily limit"
  exit 1
fi

echo "  ✅ Quota awareness present (or no UrlFetchApp usage)"
exit 0
