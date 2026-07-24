#!/usr/bin/env bash
# RT-011 — API call count per pipeline (Check 16)
# นับ API calls (UrlFetchApp, PropertiesService, CacheService) ในไฟล์ pipeline
# เทียบกับ budget ที่ตั้งไว้
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-011: API call count per pipeline"

# Count API calls per file
echo "  📊 API call counts per file:"
printf "    %-50s %8s %8s %8s\n" "FILE" "URLFETCH" "PROPS" "CACHE"
printf "    %-50s %8s %8s %8s\n" "----" "--------" "-----" "-----"

high_count_files=0
for f in $(find "$REPO/src" -name "*.gs" 2>/dev/null); do
  base=$(basename "$f")
  # Skip non-pipeline files
  if echo "$base" | grep -qE "Config|Schema|Test|Harness|Legacy"; then continue; fi

  urlfetch=$(grep -c "UrlFetchApp\.fetch" "$f" 2>/dev/null) || urlfetch=0
  props=$(grep -cE "PropertiesService\." "$f" 2>/dev/null) || props=0
  cache=$(grep -cE "CacheService\." "$f" 2>/dev/null) || cache=0

  total=$((urlfetch + props + cache))
  if [[ "$total" -gt 5 ]]; then
    printf "    %-50s %8d %8d %8d\n" "${base:0:50}" "$urlfetch" "$props" "$cache"
    high_count_files=$((high_count_files + 1))
  fi
done

echo ""
if [[ "$high_count_files" -gt 0 ]]; then
  echo "  ⚠️  $high_count_files files have > 5 API calls each"
  echo "  ℹ️  Review high-count files for unnecessary calls"
  echo "  💡 Typical budget: < 50 calls per pipeline run"
  exit 1
fi

echo "  ✅ API call counts within typical budget"
exit 0
