#!/usr/bin/env bash
# ============================================================
# 🔐 Clasp Setup Script
# สร้าง CLASPRC สำหรับใช้กับ GitHub Actions
# ============================================================

set -e

# [FIX SonarCloud S1192] Define separator constant instead of repeating literal
SEP="=========================================="

echo "$SEP"
echo "  🔐 Clasp Setup for GitHub Actions"
echo "$SEP"
echo ""

# ตรวจสอบว่ามี clasp ติดตั้งหรือยัง
if ! command -v clasp &> /dev/null; then
    echo "📦 กำลังติดตั้ง clasp..."
    npm install -g @google/clasp
fi

echo "✅ clasp version: $(clasp --version)"
echo ""

# Login ครั้งแรก
echo "🔑 ขั้นตอนที่ 1: Login ด้วย Google Account"
echo "   (ต้องเป็น account ที่มีสิทธิ์เข้าถึง Apps Script project)"
echo ""

if [[ -f ~/.clasprc.json ]]; then
    echo "⚠️  พบไฟล์ ~/.clasprc.json เดิม"
    read -p "   ต้องการ login ใหม่หรือไม่? (y/N): " re_login
    if [[ ! "$re_login" =~ ^[Yy]$ ]]; then
        echo "   ใช้ไฟล์เดิม"
    else
        rm -f ~/.clasprc.json
        clasp login
    fi
else
    clasp login
fi

echo ""
echo "✅ Login สำเร็จ"
echo ""

# ดู Apps Script ID
echo "📋 ขั้นตอนที่ 2: ระบุ Apps Script ID"
echo ""
echo "   วิธีหา Script ID:"
echo "   1. เปิด https://script.google.com"
echo "   2. เปิดโปรเจกต์ Phaopanya LMDS"
echo "   3. ดูที่ Project Settings (⚙️) > IDs > Script ID"
echo ""

read -p "   กรอก Script ID: " script_id

if [[ -z "$script_id" ]]; then
    echo "❌ ไม่ได้ระบุ Script ID"
    exit 1
fi

echo ""
echo "📋 Script ID: $script_id"
echo ""

# ตรวจสอบว่าเข้าถึงได้หรือไม่
echo "🔍 ทดสอบว่าเข้าถึง Apps Script ได้..."
cd /tmp
mkdir -p test-clasp
cd test-clasp
clasp clone --scriptId "$script_id" 2>&1 | head -5

if [[ ! -f "appsscript.json" ]]; then
    echo "❌ ไม่สามารถ clone ได้ — ตรวจสอบ Script ID และสิทธิ์"
    exit 1
fi

echo "✅ Clone สำเร็จ — สิทธิ์ถูกต้อง"
cd /tmp
rm -rf test-clasp

echo ""
echo "$SEP"
echo "  📤 ขั้นตอนที่ 3: เตรียม Secret สำหรับ GitHub"
echo "$SEP"
echo ""

# แสดง CLASPRC content
echo "📄 เนื้อหาไฟล์ ~/.clasprc.json (ให้ copy ทั้งหมด):"
echo ""
echo "----------------------------------------"
cat ~/.clasprc.json
echo "----------------------------------------"
echo ""

echo "📝 วิธีใช้:"
echo ""
echo "1. ไปที่ GitHub Repo: https://github.com/Siriwat08/phaopanya-scg/settings/secrets/actions"
echo ""
echo "2. กด 'New repository secret'"
echo ""
echo "3. เพิ่ม 2 secrets:"
echo ""
echo "   ┌─────────────────────────────────────────────────────┐"
echo "   │ Name:  CLASPRC                                       │"
echo "   │ Value: (paste เนื้อหา clasprc.json ทั้งหมด)         │"
echo "   └─────────────────────────────────────────────────────┘"
echo ""
echo "   ┌─────────────────────────────────────────────────────┐"
echo "   │ Name:  APPS_SCRIPT_ID                                │"
echo "   │ Value: $script_id"
echo "   └─────────────────────────────────────────────────────┘"
echo ""
echo "4. (Optional) เพิ่ม DEPLOY_WEBHOOK สำหรับแจ้งเตือน Discord/Slack"
echo ""
echo "✅ Setup เสร็จสมบูรณ์!"