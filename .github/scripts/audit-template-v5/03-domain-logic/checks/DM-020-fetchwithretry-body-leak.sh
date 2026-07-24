#!/usr/bin/env bash
# DM-020 — SEC-012 fetchWithRetry_ response body leak in log
# v5 NEW: ตรวจว่า fetchWithRetry_ ไม่ log full response body
# (ต้อง truncate ไม่เกิน 200 chars ก่อน log)
#
# Rule:
#   - ถ้ามี fetchWithRetry_ และมีการ log response → ต้อง truncate
#   - ห้าม log: logError(..., res.getBody(), ...)
#   - ต้อง: logError(..., res.getBody().slice(0, 200), ...)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-020: SEC-012 fetchWithRetry_ response body leak in log"

# Find fetchWithRetry_ function
fetch_files=$(grep -rlE "function\s+fetchWithRetry_" "$REPO/src" --include="*.gs" 2>/dev/null)

if [[ -z "$fetch_files" ]]; then
  # Check if UrlFetchApp is used at all
  if ! grep -rq "UrlFetchApp\.fetch" "$REPO/src" --include="*.gs" 2>/dev/null; then
    echo "  ℹ️  No UrlFetchApp usage — skipping"
    exit 0
  fi
  echo "  ⚠️  UrlFetchApp.fetch used but no fetchWithRetry_() wrapper"
  echo "  💡 Fix: Define fetchWithRetry_(url, options) that wraps fetch with retry + body truncation"
  exit 1
fi

violations=0
for fetch_file in $fetch_files; do
  echo "  📊 Checking: ${fetch_file#$REPO/}"

  # Find fetchWithRetry_ function body (limit to 80 lines to find body)
  func_start=$(grep -nE "function\s+fetchWithRetry_" "$fetch_file" 2>/dev/null | head -1 | cut -d: -f1)
  if [[ -z "$func_start" ]]; then continue; fi

  func_body=$(sed -n "${func_start},$((func_start + 80))p" "$fetch_file" 2>/dev/null)

  # Find logError/console.log calls in func_body that include response body
  # Pattern: logError(..., res.body, ...) or logError(..., getBody(), ...) or console.log(..., response.body)
  body_log_patterns=(
    "logError\s*\([^)]*\.body[^]]*"
    "logError\s*\([^)]*getBody\(\)[^]]*"
    "console\.(log|error)\s*\([^)]*\.body[^]]*"
    "console\.(log|error)\s*\([^)]*getBody\(\)[^]]*"
  )

  body_logged=0
  for pattern in "${body_log_patterns[@]}"; do
    matches=$(echo "$func_body" | grep -nE "$pattern" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      body_logged=1
      # Check if truncation is on same line or within ±2 lines
      while IFS= read -r match_line; do
        line_no_in_func=$(echo "$match_line" | cut -d: -f1)
        actual_line=$((func_start + line_no_in_func - 1))
        # Check ±2 lines for slice/substring
        context_start=$((actual_line - 1))
        context_end=$((actual_line + 1))
        context=$(sed -n "${context_start},${context_end}p" "$fetch_file" 2>/dev/null)

        if echo "$context" | grep -qE "slice\(0,\s*[0-9]+\)|substring\(0,\s*[0-9]+\)|substr\(0,\s*[0-9]+\)"; then
          echo "  ✅ Body logged with truncation (line $actual_line)"
        else
          echo "  ❌ ${fetch_file#$REPO/}:$actual_line — body logged without truncation:"
          echo "      $match_line" | head -c 200
          echo ""
          violations=$((violations + 1))
        fi
      done <<< "$matches"
    fi
  done

  if [[ "$body_logged" -eq 0 ]]; then
    echo "  ✅ fetchWithRetry_ does not log response body (no leak risk)"
  fi
done

echo ""
echo "  📊 Total violations: $violations"

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ fetchWithRetry_ response body leak prevention in place"
  exit 0
fi

echo ""
echo "  💡 Fix: Truncate response body before logging:"
echo '      logError("fetch failed", { url: url, body: res.getBody().slice(0, 200) }, e);'
exit 1
