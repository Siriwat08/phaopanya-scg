#!/usr/bin/env bash
# ============================================================
# 🛡️ Pre-commit Hook — ตรวจสอบก่อน commit
# ติดตั้ง: cp scripts/pre-commit.sh .git/hooks/pre-commit
# ============================================================

set -e

echo "🛡️  Pre-commit check (16 Immutable Laws)..."
echo ""

errors=0
warnings=0

# ดูไฟล์ที่กำลังจะ commit
changed_files=$(git diff --cached --name-only --diff-filter=ACM | grep -E "\.gs$|\.json$|\.md$" || true)

if [[ -z "$changed_files" ]]; then
    echo "  ℹ️  ไม่มีไฟล์ .gs/.json/.md ที่เปลี่ยน — ผ่าน"
    exit 0
fi

for f in $changed_files; do
    # [FIX SonarCloud S7688] Use [[ ]] instead of [ ] for safer conditional
    [[ ! -f "$f" ]] && continue

    # ========================================
    # Law 1: Hardcoded Index
    # ========================================
    if [[ "$f" == *.gs ]]; then
        hardcoded=$(grep -nE "row\[[0-9]+\]|getRange\([^)]*,\s*[0-9]+\s*," "$f" 2>/dev/null | wc -l)
        if [[ "$hardcoded" -gt 0 ]]; then
            echo "  ❌ Law 1: $f — มี Hardcoded Index ($hardcoded จุด)"
            grep -nE "row\[[0-9]+\]|getRange\([^)]*,\s*[0-9]+\s*," "$f" | head -3 | sed 's/^/      /'
            errors=$((errors+hardcoded))
        fi
    fi

    # ========================================
    # Law 3: setValue ในลูป (เฉพาะ .gs)
    # ========================================
    if [[ "$f" == *.gs ]]; then
        loop_setvalue=$(grep -nB5 "\.setValue(\|\.appendRow(" "$f" 2>/dev/null | grep -E "for\s*\(|while\s*\(|forEach\(" | wc -l)
        if [[ "$loop_setvalue" -gt 0 ]]; then
            echo "  ⚠️  Law 3: $f — อาจมี setValue ในลูป — ตรวจด้วยตา"
            warnings=$((warnings+1))
        fi
    fi

    # ========================================
    # Law 16: Secret ในไฟล์
    # [FIX SonarCloud + GitHub Token Format Change 2026-06-30]
    #   เพิ่ม ghs_ pattern (GitHub App installation token stateless format ใหม่)
    #   และ github_pat_ (fine-grained PAT) รองรับ token ยาวถึง ~520 ตัวอักษร
    #   Reference: GitHub Changelog — Upcoming change to GitHub App installation token format
    # ========================================
    secret_pattern="AIza[A-Za-z0-9_-]{35}|AQ\\.[A-Za-z0-9_-]{30,}|gh[pousr]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{82}|password\\s*[:=]|cookie\\s*[:=]\\s*[\"\\']?[a-zA-Z0-9]{20,}"
    # [FIX SonarCloud S1066] Merged nested if into single condition with && to reduce nesting
    if { [[ "$f" == *.gs ]] || [[ "$f" == *.json ]]; } && grep -iE "$secret_pattern" "$f" 2>/dev/null | grep -vE "^\\s*\\*|^//|^#" > /dev/null; then
        echo "  ❌ Law 16: $f — มี Secret ในไฟล์!"
        grep -iE "$secret_pattern" "$f" | head -3 | sed 's/^/      /'
        errors=$((errors+1))
    fi

    # ========================================
    # ตรวจ JSON syntax
    # ========================================
    # [FIX SonarCloud S1066] Merged nested if into single condition with &&
    if [[ "$f" == *.json ]] && ! python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
        echo "  ❌ JSON Invalid: $f"
        errors=$((errors+1))
    fi
done

echo ""
echo "================================"
echo "  📊 สรุป: errors=$errors, warnings=$warnings"
echo "================================"

if [[ $errors -gt 0 ]]; then
    echo "  ❌ Commit ถูก block — แก้ไขก่อน"
    exit 1
fi

if [[ $warnings -gt 0 ]]; then
    echo "  ⚠️  มี warning — แนะนำตรวจสอบ"
    read -p "  ต้องการ commit ต่อหรือไม่? (y/N): " cont
    if [[ ! "$cont" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "  ✅ ผ่าน pre-commit check"
exit 0