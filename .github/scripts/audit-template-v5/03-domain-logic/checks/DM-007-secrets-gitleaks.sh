#!/usr/bin/env bash
# DM-007 — SEC-007 Hardcoded secrets
# ใช้ gitleaks ถ้ามี, ไม่งั้นใช้ grep pattern
#
# Returns: 0 = pass, 1 = fail

set -uo pipefail
REPO="${1:-.}"

echo "📋 DM-007: Hardcoded secrets (SEC-007)"

# Try gitleaks first
if command -v gitleaks >/dev/null 2>&1; then
  echo "  🔍 Running gitleaks..."
  if gitleaks detect --source "$REPO" --no-banner -q 2>/dev/null; then
    echo "  ✅ gitleaks clean"
    exit 0
  else
    echo "  ❌ gitleaks found secrets"
    exit 1
  fi
fi

# Fallback: simple grep
echo "  🔍 Using grep fallback (install gitleaks for thorough check)"

patterns=(
  'AKIA[0-9A-Z]{16}'                     # AWS
  'AIza[0-9A-Za-z\-_]{35}'               # Google API key
  'sk-[A-Za-z0-9]{48}'                   # OpenAI
  'ghp_[A-Za-z0-9]{36}'                  # GitHub PAT
  '["\x27][A-Za-z0-9]{32,}["\x27]'      # Generic long string
)

violations=0
for pat in "${patterns[@]}"; do
  matches=$(grep -rnE "$pat" "$REPO/src" --include="*.gs" 2>/dev/null || true)
  if [[ -n "$matches" ]]; then
    echo "  ❌ Pattern: $pat"
    echo "$matches" | head -3 | sed 's/^/    /'
    violations=$((violations + 1))
  fi
done

if [[ "$violations" -eq 0 ]]; then
  echo "  ✅ No obvious hardcoded secrets (heuristic only)"
  exit 0
fi

echo ""
echo "  💡 Fix: Move secrets to PropertiesService.getScriptProperties()"
exit 1
