#!/usr/bin/env bash
# DM-010 — Formula injection prevention
# ตรวจว่า user input ที่เขียนลง sheet ถูก prefix ' ถ้าเริ่มด้วย =, +, -, @
# Formula injection เป็น OWASP top — ถ้าไม่ป้องกัน attacker เขียน =IMPORTXML(...) ได้
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-010: Formula injection prevention"

# Look for sanitizeForSheet_ or ' prefix pattern before setValue
violations=0
files_with_setvalue=$(grep -rl "setValue\|setValues" "$REPO/src" --include="*.gs" 2>/dev/null)

for f in $files_with_setvalue; do
  # If file never references sanitizeForSheet_ and writes user-shaped data
  if ! grep -q "sanitizeForSheet_\|startsWith.*['\"]=\\|prefix.*single.*quote" "$f" 2>/dev/null; then
    # Heuristic: check if there are column refs that come from form/UI input
    if grep -qE "formData|e\.parameter|requestBody|userInput" "$f" 2>/dev/null; then
      echo "  ⚠️  ${f#$REPO/} — writes user input but no sanitizeForSheet_"
      violations=$((violations + 1))
    fi
  fi
done

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ No formula injection risk detected (heuristic)"
  exit 0
fi

echo ""
echo "  💡 Fix: Add sanitizeForSheet_() helper, prefix ' when value starts with =+-@"
exit 1
