#!/usr/bin/env bash
# ST-013 — Skills catalog schema validation
# v4 NEW: ตรวจ .skills/*/SKILL.md ว่ามี required YAML frontmatter
# (name + description) และมี <!-- DOC-TYPE: ... --> marker
#
# Rule:
#   - ทุก skill folder ต้องมี SKILL.md
#   - SKILL.md ต้องมี YAML frontmatter ที่มี `name:` และ `description:`
#   - แนะนำให้มี <!-- DOC-TYPE: living|frozen|stable --> marker
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-013: Skills catalog schema validation"

SKILLS_DIR="$REPO/.skills"

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "  ℹ️  No .skills/ directory — skipping"
  exit 0
fi

total_skills=0
missing_skill_md=0
missing_name=0
missing_desc=0
missing_doc_type=0

while IFS= read -r skill_dir; do
  [[ -z "$skill_dir" ]] && continue
  total_skills=$((total_skills + 1))
  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"

  if [[ ! -f "$skill_md" ]]; then
    echo "  ❌ $skill_name — missing SKILL.md"
    missing_skill_md=$((missing_skill_md + 1))
    continue
  fi

  # v4: Check for skill metadata — accept EITHER:
  #   (A) YAML frontmatter: --- \n name: x \n description: y \n ---
  #   (B) HTML comment marker: <!-- DOC-TYPE: living -->
  # LMDS skills use (B), modern skills use (A) — both are valid

  # Check YAML frontmatter (between first two --- lines)
  has_frontmatter=0
  if head -1 "$skill_md" 2>/dev/null | grep -q "^---$"; then
    second_line=$(grep -n "^---$" "$skill_md" 2>/dev/null | head -2 | tail -1 | cut -d: -f1)
    if [[ -n "$second_line" ]] && [[ "$second_line" -gt 1 ]]; then
      has_frontmatter=1
      frontmatter=$(sed -n "2,$((second_line - 1))p" "$skill_md" 2>/dev/null)

      if ! echo "$frontmatter" | grep -q "^name:"; then
        echo "  ⚠️  $skill_name — frontmatter missing 'name:'"
        missing_name=$((missing_name + 1))
      fi

      if ! echo "$frontmatter" | grep -q "^description:"; then
        echo "  ⚠️  $skill_name — frontmatter missing 'description:'"
        missing_desc=$((missing_desc + 1))
      fi
    fi
  fi

  # Check DOC-TYPE marker (LMDS pattern — alternative to frontmatter)
  has_doc_type=0
  if grep -q "<!-- DOC-TYPE:" "$skill_md" 2>/dev/null; then
    has_doc_type=1
  fi

  # v4: If neither frontmatter nor DOC-TYPE, that's a real problem
  if [[ "$has_frontmatter" -eq 0 ]] && [[ "$has_doc_type" -eq 0 ]]; then
    echo "  ⚠️  $skill_name — no YAML frontmatter AND no DOC-TYPE marker"
    missing_name=$((missing_name + 1))
    missing_desc=$((missing_desc + 1))
  elif [[ "$has_frontmatter" -eq 0 ]] && [[ "$has_doc_type" -eq 1 ]]; then
    # DOC-TYPE only — try to extract name from filename + first heading
    skill_label=$(head -1 "$skill_md" 2>/dev/null | sed 's/^# *//')
    if [[ -z "$skill_label" ]]; then
      echo "  ℹ️  $skill_name — uses DOC-TYPE marker (no frontmatter, OK if name derivable)"
    fi
  fi

  if [[ "$has_doc_type" -eq 0 ]] && [[ "$has_frontmatter" -eq 1 ]]; then
    missing_doc_type=$((missing_doc_type + 1))
  fi
done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

echo ""
echo "  📊 Total skills: $total_skills"
echo "  📊 Missing SKILL.md: $missing_skill_md"
echo "  📊 Missing 'name:' field: $missing_name"
echo "  📊 Missing 'description:' field: $missing_desc"
echo "  📊 Missing DOC-TYPE marker (recommended): $missing_doc_type"

total_issues=$((missing_skill_md + missing_name + missing_desc))

if [[ "$total_issues" -eq 0 ]]; then
  if [[ "$missing_doc_type" -gt 0 ]]; then
    echo "  ✅ All skills have valid metadata (YAML frontmatter OR DOC-TYPE marker)"
    echo "  ℹ️  $missing_doc_type skill(s) missing DOC-TYPE marker (recommended, not required)"
  else
    echo "  ✅ All skills have complete schema (frontmatter or DOC-TYPE)"
  fi
  exit 0
fi

echo ""
echo "  💡 Fix: Add EITHER YAML frontmatter OR DOC-TYPE marker to each SKILL.md:"
echo "      Option A (YAML frontmatter):"
echo "        ---"
echo "        name: skill-name"
echo "        description: <description for AI to know when to invoke>"
echo "        ---"
echo "      Option B (DOC-TYPE marker, LMDS style):"
echo "        <!-- DOC-TYPE: living -->"
exit 1
