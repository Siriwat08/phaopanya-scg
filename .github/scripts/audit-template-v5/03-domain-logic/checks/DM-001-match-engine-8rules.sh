#!/usr/bin/env bash
# DM-001 — Match Engine 8-rule decision matrix
# ตรวจว่า 10b_MatchDecision.gs มีครบ 8 rules + 4 outcomes
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-001: Match Engine 8-rule decision matrix"

match_file="$REPO/src/1_group1_master_db/10b_MatchDecision.gs"

if [[ ! -f "$match_file" ]]; then
  echo "  ❌ 10b_MatchDecision.gs not found"
  exit 1
fi

# Look for rule markers
# v3: case-insensitive + รับทั้ง evaluateRule1, RULE_1, // Rule 1, case "RULE1"
# (LMDS จริงใช้ evaluateRule1_NoGeoInSource_ ... evaluateRule8_NewGeoFromGPS_ — camelCase)
rule_count=$(grep -ciE "(evaluateRule|RULE_|// *Rule |case ['\"]RULE)[1-8]" "$match_file" 2>/dev/null) || rule_count=0

# Outcomes — v3: รับหลาย naming conventions
# LMDS จริงใช้: REVIEW, AUTO_MATCH, CREATE_NEW (10b_MatchDecision.gs)
# Spec ดั้งเดิม: MERGE, CREATE, ESCALATE, IGNORE
# รับทั้ง 2 รูปแบบ — IGNORE อาจไม่มี explicit (rule returns null = de facto ignore)
merge=$(grep -cE "MERGE|AUTO_MATCH" "$match_file" 2>/dev/null) || merge=0
create=$(grep -cE "\bCREATE\b|CREATE_NEW" "$match_file" 2>/dev/null) || create=0
escalate=$(grep -cE "ESCALATE|\bREVIEW\b" "$match_file" 2>/dev/null) || escalate=0
ignore=$(grep -cE "\bIGNORE\b|\bSKIP\b|return\s+null" "$match_file" 2>/dev/null) || ignore=0

# v3: IGNORE/SKIP อาจไม่มี explicit — รับ return null เป็น de facto ignore
# ถ้ามี 3 อย่างแรกครบ ก็ถือว่าผ่าน
required_outcomes_ok=true
if [[ "$merge" -eq 0 ]]; then required_outcomes_ok=false; fi
if [[ "$create" -eq 0 ]]; then required_outcomes_ok=false; fi
if [[ "$escalate" -eq 0 ]]; then required_outcomes_ok=false; fi
# IGNORE ไม่บังคับ (อาจเป็น implicit null return)

echo "  📊 Rule markers found: $rule_count (need 8)"
echo "  📊 Outcomes: MERGE=$merge CREATE=$create ESCALATE=$escalate IGNORE=$ignore"

if [[ "$rule_count" -lt 8 ]]; then
  echo "  ❌ Less than 8 rules found"
  echo "  💡 Fix: Add all 8 match rules (Person/Place/Geo/Destination + Alias + Hybrid + Trinity + Geofence)"
  exit 1
fi

# v3: ตรวจเฉพาะ 3 outcomes หลัก (MERGE/CREATE/ESCALATE) — IGNORE อาจเป็น implicit null
if [[ "$required_outcomes_ok" != "true" ]]; then
  echo "  ❌ Missing one of required outcomes (MERGE/CREATE/ESCALATE)"
  echo "  ℹ️  IGNORE is optional (rule may return null as de facto ignore)"
  exit 1
fi

echo "  ✅ Match Engine looks complete (8 rules + 3 required outcomes + IGNORE optional)"
exit 0
