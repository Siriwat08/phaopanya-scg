#!/usr/bin/env bash
# RT-013 — GitHub Workflows permissions (least privilege)
# v4 NEW: ตรวจ .github/workflows/*.yml ว่ามี permissions: block
# และไม่ใช้ permissions: write-all หรือไม่ระบุเลย (default = write-all)
#
# Rule:
#   - ทุก workflow ต้องมี `permissions:` block ที่ top level หรือ job level
#   - ห้ามใช้ `permissions: write-all`
#   - ควรระบุเฉพาะที่จำเป็น (contents: read, checks: write, etc.)
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 RT-013: GitHub Workflows permissions (least privilege)"

WORKFLOW_DIR="$REPO/.github/workflows"

if [[ ! -d "$WORKFLOW_DIR" ]]; then
  echo "  ℹ️  No .github/workflows/ directory — skipping"
  exit 0
fi

total_workflows=0
missing_permissions=0
write_all=0
has_permissions=0

while IFS= read -r workflow; do
  [[ -z "$workflow" ]] && continue
  total_workflows=$((total_workflows + 1))
  base=$(basename "$workflow")

  # Check if workflow has permissions block at all
  if ! grep -qE "^permissions:" "$workflow" 2>/dev/null; then
    echo "  ⚠️  $base — no permissions: block (defaults to write-all)"
    missing_permissions=$((missing_permissions + 1))
    continue
  fi

  # Check for write-all (anti-pattern)
  if grep -qE "^permissions:\s*write-all" "$workflow" 2>/dev/null; then
    echo "  ❌ $base — uses permissions: write-all (overly broad)"
    write_all=$((write_all + 1))
    continue
  fi

  has_permissions=$((has_permissions + 1))

  # Show what permissions are declared
  perms=$(grep -A10 "^permissions:" "$workflow" 2>/dev/null \
    | grep -E "^\s+(contents|pull-requests|checks|deployments|statuses|actions|packages|id-token|security-events|pages):" \
    | head -5 | sed 's/^[[:space:]]*/    /')
  if [[ -n "$perms" ]]; then
    echo "  ✅ $base — has permissions block"
    echo "$perms"
  fi
done < <(find "$WORKFLOW_DIR" -maxdepth 1 -name "*.yml" -o -name "*.yaml" 2>/dev/null)

echo ""
echo "  📊 Total workflows: $total_workflows"
echo "  📊 With permissions block: $has_permissions"
echo "  📊 Missing permissions (default write-all): $missing_permissions"
echo "  📊 Using write-all explicitly: $write_all"

total_issues=$((missing_permissions + write_all))

if [[ "$total_issues" -eq 0 ]]; then
  echo "  ✅ All workflows have explicit permissions (least privilege)"
  exit 0
fi

echo ""
echo "  💡 Fix: Add 'permissions:' block at top of each workflow, e.g.:"
echo "      permissions:"
echo "        contents: read"
echo "        checks: write"
echo "        pull-requests: write  # only if needed"
exit 1
