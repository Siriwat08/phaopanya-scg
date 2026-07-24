#!/usr/bin/env bash
# DM-012 — No data contamination (Law 1 architect)
# ตรวจว่า Raw data (Source sheets S_*) ไม่ถูกเขียนตรงๆ ลง Master sheets (M_*)
# ต้อง route ผ่าน 04_SourceRepository.gs ingest pipeline เท่านั้น
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-012: No data contamination (Law 1 architect)"

# Strategy:
# 1. Find all Source sheet names (S_*) referenced in code
# 2. Find all Master sheet names (M_*) referenced in code
# 3. Look for files that:
#    a. Read from S_* AND write to M_* directly (without going through 04_SourceRepository.gs)
#    b. Have setValue/setValues/appendRow to M_* after reading from S_*

source_repo_file=$(find "$REPO/src" -name "04_SourceRepository.gs" 2>/dev/null | head -1)

if [[ -z "$source_repo_file" ]]; then
  echo "  ⚠️  04_SourceRepository.gs not found anywhere in src/ — cannot verify ingest pipeline"
  echo "  💡 Fix: Create 04_SourceRepository.gs as the single ingest entry point"
  exit 1
fi

echo "  📊 Found ingest pipeline: ${source_repo_file#$REPO/}"

# Common Source sheet prefixes (raw data)
source_patterns="S_PERSON|S_PLACE|S_GEO|S_DEST|S_DAILY|S_SOURCE|S_RAW|S_INPUT|S_IMPORT"
# Common Master sheet prefixes (processed data)
master_patterns="M_PERSON|M_PLACE|M_GEO_POINT|M_DESTINATION|M_ALIAS|M_DAILY_JOB|M_MASTER"

violations=0

# Find files that reference BOTH source and master sheets (potential contamination)
while IFS= read -r gsfile; do
  base=$(basename "$gsfile")

  # Skip the Source Repository itself (it's the legitimate ingest pipeline)
  if [[ "$base" == "04_SourceRepository.gs" ]]; then continue; fi
  # Skip test/harness/legacy files
  if echo "$base" | grep -qE "Test|Harness|Snapshot|Legacy"; then continue; fi
  # Skip setup file (legitimate to reference master sheets)
  if [[ "$base" == "03_SetupSheets.gs" ]]; then continue; fi

  # Check if file references Source sheets
  has_source=$(grep -cE "$source_patterns" "$gsfile" 2>/dev/null) || has_source=0
  # Check if file writes to Master sheets (setValues/setValue/appendRow near M_*)
  has_master_write=$(grep -nE "($master_patterns).*(setValues|setValue|appendRow)" "$gsfile" 2>/dev/null \
    | grep -v "^.*://" | head -1)

  if [[ "$has_source" -gt 0 ]] && [[ -n "$has_master_write" ]]; then
    echo "  ⚠️  ${gsfile#$REPO/} — reads Source AND writes Master directly"
    echo "      → potential contamination (should route via 04_SourceRepository.gs)"
    echo "      $has_master_write" | head -1 | sed 's/^/      /'
    violations=$((violations + 1))
  fi
done < <(find "$REPO/src" -name "*.gs" 2>/dev/null)

# Verify 04_SourceRepository.gs is the actual entry point for ingest
# (has function like ingestSource, importSource, or similar)
has_ingest_func=$(grep -cE "function\s+(ingest|import|processSource|loadSource)" "$source_repo_file" 2>/dev/null) || has_ingest_func=0
if [[ "$has_ingest_func" -eq 0 ]]; then
  echo "  ⚠️  04_SourceRepository.gs has no ingest/import entry function"
  echo "  💡 Fix: Define ingestSource(sheetName) that reads Source and writes Master safely"
  violations=$((violations + 1))
else
  echo "  ✅ 04_SourceRepository.gs has ingest entry function"
fi

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ No data contamination detected — raw data flows through ingest pipeline"
  exit 0
fi

echo ""
echo "  💡 Fix: Route all Raw → Master writes through 04_SourceRepository.gs ingest pipeline"
exit 1
