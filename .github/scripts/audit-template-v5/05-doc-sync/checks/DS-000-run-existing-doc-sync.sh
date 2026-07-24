#!/usr/bin/env bash
# DS-000 — Auto-discover + run LMDS doc-code-sync checks
# v5 NEW: Wrapper ที่หา .github/scripts/doc-code-sync-checks/*.sh ใน repo ที่ตรวจ
# แล้วรันทั้งหมด รวบรวมผล
#
# Strategy:
#   - ถ้า repo มี existing doc-code-sync checks (LMDS pattern) → run ทั้งหมด
#   - ถ้าไม่มี → report ว่าไม่มี (ไม่ fail)
#   - ห้าม duplicate logic ของ LMDS — ใช้ของเดิม
#
# Returns: 0 = all passed, 1 = some failed

set -uo pipefail
REPO="${1:-.}"

echo "📋 DS-000: Auto-discover + run existing doc-code-sync checks"

DOC_SYNC_DIR="$REPO/.github/scripts/doc-code-sync-checks"

if [[ ! -d "$DOC_SYNC_DIR" ]]; then
  echo "  ℹ️  No .github/scripts/doc-code-sync-checks/ in repo — skipping"
  echo "  ℹ️  (LMDS-style projects would have 18 checks here)"
  exit 0
fi

# Count available checks
check_files=$(find "$DOC_SYNC_DIR" -maxdepth 1 -name "check_*.sh" 2>/dev/null)
total=$(echo "$check_files" | grep -c .)
echo "  📊 Found $total doc-code-sync check scripts"
echo ""

total_passed=0
total_failed=0
total_skipped=0

# Run each check_NN_*.sh in order
for check in $(echo "$check_files" | sort); do
  [[ -z "$check" ]] && continue
  base=$(basename "$check")

  # Run check — note these scripts use `cd "$(dirname "$0")/../../.."` internally
  # which will resolve to repo root
  output=$(bash "$check" 2>&1)
  exit_code=$?

  # Parse output for pass/fail indicators
  if [[ $exit_code -eq 0 ]]; then
    if echo "$output" | grep -qE "ℹ️|skipping|skipped"; then
      total_skipped=$((total_skipped + 1))
      status="ℹ️"
    else
      total_passed=$((total_passed + 1))
      status="✅"
    fi
  else
    total_failed=$((total_failed + 1))
    status="❌"
  fi

  # Show check name + brief status (first non-empty line with key info)
  brief=$(echo "$output" | grep -E "✅|❌|⚠️|ℹ️" | head -1 | sed 's/^[[:space:]]*//')
  printf "  %s %s — %s\n" "$status" "$base" "$brief"
done

echo ""
echo "  📊 Summary:"
echo "    Total checks: $total"
echo "    Passed: $total_passed"
echo "    Failed: $total_failed"
echo "    Skipped: $total_skipped"

if [[ "$total_failed" -gt 0 ]]; then
  echo ""
  echo "  💡 Review failed checks above — each is a LMDS-specific doc-code-sync validation"
  exit 1
fi

echo "  ✅ All $total doc-code-sync checks passed (or skipped)"
exit 0
