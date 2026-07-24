#!/usr/bin/env bash
# RT-005 — Checkpoint for long pipelines (Law 5)
# ตรวจว่า pipeline ที่อาจใช้เวลา > 2 นาที มี checkpoint + resume logic
# ใช้ PropertiesService เก็บ progress
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-005: Checkpoint & resume (Law 5)"

# Pipeline files (Group 4) + Match Engine (Group 1) are candidates
# Check if they have PropertiesService.setProperty for checkpoint

# v3: แก้ bug `grep -c || echo 0` ที่ทำให้ค่าเป็น "0\n0" → syntax error ใน [[ ]]
# Pattern ใหม่: `$(grep -c ...) || var=0` + sanitize ให้เป็น integer เท่านั้น

violations=0
pipeline_files=$(find "$REPO/src" -name "*.gs" 2>/dev/null | xargs grep -lE "for\s*\(.*lastRow|for\s*\(.*\.length" 2>/dev/null | head -20)

for f in $pipeline_files; do
  # Skip trivial loops
  if ! grep -qE "lastRow|getLastRow" "$f"; then continue; fi

  # Check for checkpoint pattern (v3: safe pattern)
  has_checkpoint=$(grep -cE "PropertiesService\.(get|set)ScriptProperties\(\)\.setProperty" "$f" 2>/dev/null) || has_checkpoint=0
  # Sanitize to integer only (strip newlines, etc.)
  has_checkpoint=${has_checkpoint//[^0-9]/}
  has_checkpoint=${has_checkpoint:-0}

  if [[ "$has_checkpoint" -eq 0 ]]; then
    # Allow if file is clearly a single-shot operation (no for loop over lastRow)
    if ! grep -qE "for\s*\(" "$f"; then continue; fi
    # Allow if file is small (< 50 lines) — too simple to need checkpoint
    lines=$(wc -l < "$f")
    if [[ "$lines" -lt 50 ]]; then continue; fi

    echo "  ⚠️  ${f#$REPO/} — iterates over lastRow but no PropertiesService checkpoint"
    violations=$((violations + 1))
  fi
done

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ Long pipelines have checkpoint mechanism"
  exit 0
fi

echo ""
echo "  💡 Fix: Save progress to PropertiesService every N rows, resume on next run"
exit 1
