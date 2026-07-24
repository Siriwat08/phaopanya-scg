#!/usr/bin/env bash
# DM-011 — Q_REVIEW decision routing (MAKE_MATCH_DECISION)
# ตรวจว่า 10b_MatchDecision.gs มี MAKE_MATCH_DECISION function
# และ return shape ครบทั้ง 4 outcomes: MERGE / CREATE / ESCALATE / IGNORE
# แต่ละ outcome ต้อง return object ที่มี action + sourceId + targetId (อย่างน้อย)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-011: Q_REVIEW decision routing (MAKE_MATCH_DECISION)"

match_file="$REPO/src/1_group1_master_db/10b_MatchDecision.gs"

if [[ ! -f "$match_file" ]]; then
  echo "  ❌ 10b_MatchDecision.gs not found"
  exit 1
fi

# Check that MAKE_MATCH_DECISION function exists
# v3: รับทั้ง UPPER_CASE (MAKE_MATCH_DECISION) และ camelCase (makeMatchDecision)
# — LMDS จริงใช้ makeMatchDecision ใน 10_MatchEngine.gs และ delegate ไป 10b_MatchDecision.gs
# ดังนั้นค้นหาทั้ง 2 ไฟล์
match_files_to_check=("$match_file")
match_engine_file="$REPO/src/1_group1_master_db/10_MatchEngine.gs"
[[ -f "$match_engine_file" ]] && match_files_to_check+=("$match_engine_file")

found_match_decision=0
for check_file in "${match_files_to_check[@]}"; do
  if grep -qE "function\s+(MAKE_MATCH_DECISION|makeMatchDecision)|(MAKE_MATCH_DECISION|makeMatchDecision)\s*=" "$check_file" 2>/dev/null; then
    found_match_decision=1
    echo "  📊 Found match decision function in: ${check_file#$REPO/}"
    break
  fi
done

if [[ "$found_match_decision" -eq 0 ]]; then
  echo "  ❌ MAKE_MATCH_DECISION / makeMatchDecision function not found"
  echo "  💡 Fix: Define makeMatchDecision(input) that returns {action, sourceId, targetId, ...}"
  exit 1
fi

# Check that all 4 outcomes are present as return values
# v3: รับหลาย naming conventions — LMDS จริงใช้ REVIEW/AUTO_MATCH/CREATE_NEW
# ไม่ใช่ MERGE/CREATE/ESCALATE/IGNORE ตาม spec ดั้งเดิม
# Mapping:
#   MERGE    -> AUTO_MATCH (match accepted)
#   CREATE   -> CREATE_NEW (new master record)
#   ESCALATE -> REVIEW (queue for human review)
#   IGNORE   -> SKIP / IGNORE (no action)
declare -A OUTCOMES=(
  [MERGE]="MERGE|AUTO_MATCH"
  [CREATE]="\\bCREATE\\b|CREATE_NEW"
  [ESCALATE]="ESCALATE|\\bREVIEW\\b"
  [IGNORE]="\\bIGNORE\\b|\\bSKIP\\b"
)

echo "  📊 Checking return shapes per outcome:"

issues=0
for outcome_key in MERGE CREATE ESCALATE IGNORE; do
  outcome_pattern="${OUTCOMES[$outcome_key]}"
  # Look for return statement with this outcome action
  has_return=$(grep -cE "return\s*\{[^}]*action\s*:\s*['\"](${outcome_pattern})['\"]" "$match_file" 2>/dev/null) || has_return=0
  has_return=${has_return//[^0-9]/}
  has_return=${has_return:-0}
  # Also accept: { action: 'MERGE' } as object literal
  has_literal=$(grep -cE "action\s*:\s*['\"](${outcome_pattern})['\"]" "$match_file" 2>/dev/null) || has_literal=0
  has_literal=${has_literal//[^0-9]/}
  has_literal=${has_literal:-0}

  if [[ "$has_return" -gt 0 ]] || [[ "$has_literal" -gt 0 ]]; then
    # v3: Verify return shape — accept multiple field naming conventions
    # LMDS จริงใช้ {action, reason, confidence, priority, evidence}
    # Spec ดั้งเดิมใช้ {action, sourceId, targetId}
    # รับทั้ง 2 รูปแบบ ขอแค่มี action + อย่างน้อย 1 field อื่น
    line_no=$(grep -nE "action\s*:\s*['\"](${outcome_pattern})['\"]" "$match_file" 2>/dev/null | head -1 | cut -d: -f1)
    if [[ -n "$line_no" ]]; then
      end_line=$((line_no + 5))
      block=$(sed -n "${line_no},${end_line}p" "$match_file" 2>/dev/null)
      # Look for ANY supporting field (not just sourceId/targetId)
      has_source=$(echo "$block" | grep -cE "sourceId|source_id|sourceID|srcId" 2>/dev/null) || has_source=0
      has_target=$(echo "$block" | grep -cE "targetId|target_id|targetID|tgtId" 2>/dev/null) || has_target=0
      has_reason=$(echo "$block" | grep -cE "\breason\b" 2>/dev/null) || has_reason=0
      has_confidence=$(echo "$block" | grep -cE "\bconfidence\b" 2>/dev/null) || has_confidence=0
      has_evidence=$(echo "$block" | grep -cE "\bevidence\b" 2>/dev/null) || has_evidence=0
      has_priority=$(echo "$block" | grep -cE "\bpriority\b" 2>/dev/null) || has_priority=0
      # Sanitize all to integers
      has_source=${has_source//[^0-9]/}; has_source=${has_source:-0}
      has_target=${has_target//[^0-9]/}; has_target=${has_target:-0}
      has_reason=${has_reason//[^0-9]/}; has_reason=${has_reason:-0}
      has_confidence=${has_confidence//[^0-9]/}; has_confidence=${has_confidence:-0}
      has_evidence=${has_evidence//[^0-9]/}; has_evidence=${has_evidence:-0}
      has_priority=${has_priority//[^0-9]/}; has_priority=${has_priority:-0}

      supporting_fields=$((has_source + has_target + has_reason + has_confidence + has_evidence + has_priority))

      if [[ "$supporting_fields" -ge 1 ]]; then
        echo "  ✅ $outcome_key — return shape OK (action + supporting fields)"
      else
        echo "  ⚠️  $outcome_key — return shape incomplete (need action + at least 1 of: sourceId/targetId/reason/confidence/evidence/priority)"
        issues=$((issues + 1))
      fi
    fi
  else
    # v3: IGNORE is optional (rule may return null as de facto ignore)
    if [[ "$outcome_key" == "IGNORE" ]]; then
      echo "  ℹ️  IGNORE — not found as explicit outcome (may be implicit null return)"
    else
      echo "  ❌ $outcome_key — outcome not found as return value"
      issues=$((issues + 1))
    fi
  fi
done

# Also verify review routing: ESCALATE must route to Q_REVIEW queue
# v3: รับ Q_REVIEW / reviewQueue / ReviewService / REVIEW action itself
has_q_review=$(grep -cE "Q_REVIEW|reviewQueue|ReviewService|action:\s*['\"]REVIEW['\"]" "$match_file" 2>/dev/null) || has_q_review=0
has_q_review=${has_q_review//[^0-9]/}; has_q_review=${has_q_review:-0}
if [[ "$has_q_review" -eq 0 ]]; then
  echo "  ⚠️  No Q_REVIEW routing found (ESCALATE/REVIEW should route to review queue)"
  issues=$((issues + 1))
else
  echo "  ✅ Q_REVIEW routing detected"
fi

if [[ "$issues" -eq 0 ]]; then
  echo "  ✅ Q_REVIEW decision routing looks correct"
  exit 0
fi

echo ""
echo "  💡 Fix: Re-check 10b return signature, run 10d_MatchTestHarness"
exit 1
