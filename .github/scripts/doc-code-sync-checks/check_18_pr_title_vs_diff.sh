#!/usr/bin/env bash
# Check 18 — PR Title vs Actual Diff Verification
# ตรวจว่า PR title สอดคล้องกับไฟล์ที่เปลี่ยนจริงหรือไม่
#
# Returns:
#   0 = pass (title matches diff)
#   1 = fail (title doesn't match — possible mismatch)
#
# Rules:
#   - ถ้า title บอก "add" → ต้องมีไฟล์ใหม่ (A ใน git diff)
#   - ถ้า title บอก "remove/delete" → ต้องมีไฟล้ถูกลบ (D ใน git diff)
#   - ถ้า title บอก "refactor" → ไม่ควรมีไฟล์ใหม่/ลบจำนวนมาก (เปลี่ยน behavior)
#   - ถ้า title บอก "docs" → ไม่ควรแตะ src/*.gs

set -uo pipefail
cd "$(dirname "$0")/../../.."

echo "📋 Check 18: PR Title vs Actual Diff"

# ─── Get PR title from commit message (latest commit on branch) ───
PR_TITLE=$(git log --format='%s' -1 2>/dev/null || echo "")

if [[ -z "$PR_TITLE" ]]; then
  echo "  ⚠️  Cannot determine PR title (no commits)"
  exit 0
fi

echo "  📝 PR Title: $PR_TITLE"
echo ""

# ─── Get diff stats vs main ───
DIFF_STATS=$(git diff --name-status main...HEAD 2>/dev/null || echo "")
if [[ -z "$DIFF_STATS" ]]; then
  echo "  ℹ️  No changes vs main (might be already merged)"
  exit 0
fi

# Count file types
ADDED_FILES=$(echo "$DIFF_STATS" | grep -c '^A' || echo 0)
DELETED_FILES=$(echo "$DIFF_STATS" | grep -c '^D' || echo 0)
MODIFIED_FILES=$(echo "$DIFF_STATS" | grep -c '^M' || echo 0)
TOTAL_CHANGES=$((ADDED_FILES + DELETED_FILES + MODIFIED_FILES))

# Check if src/ was touched
SRC_CHANGED=$(echo "$DIFF_STATS" | grep -c 'src/' || echo 0)
DOCS_CHANGED=$(echo "$DIFF_STATS" | grep -c 'docs/' || echo 0)
CI_CHANGED=$(echo "$DIFF_STATS" | grep -c '.github/' || echo 0)

echo "  📊 Diff Stats:"
echo "     Added: $ADDED_FILES | Deleted: $DELETED_FILES | Modified: $MODIFIED_FILES"
echo "     src/ changed: $SRC_CHANGED | docs/ changed: $DOCS_CHANGED | .github/ changed: $CI_CHANGED"
echo ""

failures=0

# ─── Rule 1: Title says "add" but no new files ───
if echo "$PR_TITLE" | grep -qiE 'add|เพิ่ม|สร้าง'; then
  if [[ "$ADDED_FILES" -eq 0 ]]; then
    echo "  ❌ Title says 'add' but no new files (A) in diff"
    failures=$((failures + 1))
  else
    echo "  ✅ Title 'add' matches: $ADDED_FILES new file(s) in diff"
  fi
fi

# ─── Rule 2: Title says "remove/delete" but no deleted files ───
if echo "$PR_TITLE" | grep -qiE 'remove|delete|ลบ|remove dead'; then
  if [[ "$DELETED_FILES" -eq 0 ]]; then
    echo "  ❌ Title says 'remove/delete' but no deleted files (D) in diff"
    failures=$((failures + 1))
  else
    echo "  ✅ Title 'remove/delete' matches: $DELETED_FILES deleted file(s)"
  fi
fi

# ─── Rule 3: Title says "docs" but src/ changed ───
if echo "$PR_TITLE" | grep -qiE '^docs:|documentation|เอกสาร'; then
  if [[ "$SRC_CHANGED" -gt 0 ]]; then
    echo "  ⚠️  Title says 'docs' but src/ files changed ($SRC_CHANGED) — should be docs-only?"
    # Warning only — don't fail (might be legitimate: e.g., adding comments to .gs files)
  else
    echo "  ✅ Title 'docs' matches: no src/ changes"
  fi
fi

# ─── Rule 4: Title says "refactor" but many new files ───
if echo "$PR_TITLE" | grep -qiE 'refactor|refac'; then
  if [[ "$ADDED_FILES" -gt 5 ]]; then
    echo "  ⚠️  Title says 'refactor' but $ADDED_FILES new files — might be feature, not refactor"
    # Warning only — refactor might legitimately add new split files
  else
    echo "  ✅ Title 'refactor' matches: $ADDED_FILES new file(s) (≤5)"
  fi
fi

# ─── Rule 5: Title says "fix" but 0 src changes ───
if echo "$PR_TITLE" | grep -qiE '^fix:|bug fix|แก้'; then
  if [[ "$SRC_CHANGED" -eq 0 && "$CI_CHANGED" -eq 0 ]]; then
    echo "  ⚠️  Title says 'fix' but no src/ or .github/ changes — might be docs-only?"
  else
    echo "  ✅ Title 'fix' matches: src/ or .github/ changes detected"
  fi
fi

echo ""
if [[ $failures -eq 0 ]]; then
  echo "  ✅ PR title matches diff"
  exit 0
else
  echo "  ❌ $failures mismatch(es) found — check if title is accurate"
  exit 1
fi
