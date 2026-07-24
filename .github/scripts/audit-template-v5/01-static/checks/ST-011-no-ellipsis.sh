#!/usr/bin/env bash
# ST-011 — No ellipsis in code (Law 15) — improved to avoid FPs
#
# Heuristic v2:
#   - Real placeholder: /* ... */, // ... (line is mostly just dots)
#   - Not FP: doc comment mentioning "existing callers", "previous step" etc.
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 ST-011: No ellipsis/placeholder in code (Law 15)"

violations=0

# Pattern 1: Block comment that's JUST dots / placeholder
matches=$(grep -rnE '/\*\s*(\.\.\.|TODO|FIXME|XXX|existing code|unchanged)\s*\*/' "$REPO/src" --include="*.gs" 2>/dev/null || true)
if [[ -n "$matches" ]]; then
  echo "  ❌ Block comment placeholder:"
  echo "$matches" | head -10 | sed 's/^/    /'
  violations=$((violations + 1))
fi

# Pattern 2: Line that's just // ... (with optional space)
matches=$(grep -rnE '^\s*//\s*\.\.\.\s*$' "$REPO/src" --include="*.gs" 2>/dev/null || true)
if [[ -n "$matches" ]]; then
  echo "  ❌ Line-only ellipsis placeholder:"
  echo "$matches" | head -10 | sed 's/^/    /'
  violations=$((violations + 1))
fi

# Pattern 3: Real placeholders only (line is JUST the placeholder, not a doc sentence)
# Real pattern: a line where the comment body is the placeholder word, optionally with ellipsis
matches=$(grep -rnE '^\s*//\s*(rest of code|existing code|unchanged|same as before|previous implementation)\s*$' "$REPO/src" --include="*.gs" 2>/dev/null || true)
if [[ -n "$matches" ]]; then
  echo "  ❌ Line-only placeholder comment:"
  echo "$matches" | head -10 | sed 's/^/    /'
  violations=$((violations + 1))
fi

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ No ellipsis/placeholder in code blocks"
  exit 0
fi

echo ""
echo "  💡 Fix: Commit the full file (line 1 to last })"
exit 1
