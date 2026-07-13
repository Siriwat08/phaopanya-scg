<!-- DOC-TYPE: living -->
# 🚀 GitHub Actions สำหรับ Phaopanya SCG

คู่มือติดตั้งและใช้งาน GitHub Actions สำหรับโปรเจกต์ **Phaopanya SCG** (Google Apps Script)

---

## 📋 Workflows ที่มีให้

| # | Workflow | ไฟล์ | ทำอะไร | Trigger |
|---|----------|------|--------|---------|
| 1 | 🔍 CI | `01-ci.yml` | ตรวจสอบ syntax + 16 Laws | push, PR |
| 2 | 🚀 Deploy | `02-deploy.yml` | Deploy ไป Apps Script ผ่าน clasp | push to main |
| 3 | 🔍 PR Validation | `03-pr-validation.yml` | ตรวจ PR + Auto comment + Label | PR |
| 4 | 🏷️ Release | `04-release.yml` | ตัด Git Tag + สร้าง Release | push to main |
| 5 | 💓 Health Check | `05-scheduled-health.yml` | เช็คสุขภาพระบบ | ทุกวันจันทร์ 09:00 |
| 6 | 🛡️ CodeQL | `06-codeql.yml` | CodeQL semantic security analysis | push, PR, weekly |
| 7 | 📚 Doc-Code Sync | `07-doc-code-sync.yml` | ตรวจ 9 checks เอกสาร ↔ โค้ดตรงกัน | push, PR |
| 8 | 🔐 Gitleaks | `08-gitleaks.yml` | สแกน hardcoded secrets | push, PR |

---

## 🏗️ โครงสร้างไฟล์

```
.github/
├── workflows/
│   ├── 01-ci.yml                    # CI - ตรวจโค้ด
│   ├── 02-deploy.yml                # Deploy - อัปโหลดไป Apps Script
│   ├── 03-pr-validation.yml         # PR - ตรวจ + Comment + Label
│   ├── 04-release.yml               # Release - Tag + Release Notes
│   ├── 05-scheduled-health.yml      # Health - เช็คอัตโนมัติ
│   ├── 06-codeql.yml                # CodeQL - semantic security scan
│   ├── 07-doc-code-sync.yml         # Doc-Code Sync - 9 checks (check_01 - check_09)
│   └── 08-gitleaks.yml              # Gitleaks - hardcoded secret scan
├── scripts/
│   └── doc-code-sync-checks/        # 9 check scripts (check_01 - check_09)
├── ISSUE_TEMPLATE/
│   ├── bug_report.md
│   └── feature_request.md
├── pull_request_template.md
├── labeler.yml                       # Auto-label config
scripts/
├── setup-clasp.sh                    # 🔐 ติดตั้ง clasp + เตรียม Secret
└── pre-commit.sh                     # 🛡️ ตรวจก่อน commit
docs/
└── (คู่มืออื่นๆ)
.gitignore                            # ห้าม commit Secret
```

---

## 🚀 เริ่มต้นใช้งาน

### ขั้นตอนที่ 1: เพิ่มไฟล์เข้าโปรเจกต์

```bash
# ใน repo Phaopanya SCG
cp -r .github/ /path/to/phaopanya-scg/
cp scripts/ /path/to/phaopanya-scg/ -r
cp .gitignore /path/to/phaopanya-scg/

cd /path/to/phaopanya-scg
git add .github/ scripts/ .gitignore
git commit -m "ci: เพิ่ม GitHub Actions workflows"
git push origin main
```

### ขั้นตอนที่ 2: ติดตั้ง clasp + Login

```bash
bash scripts/setup-clasp.sh
```

Script นี้จะ:
1. ติดตั้ง clasp (ถ้ายังไม่มี)
2. Login Google account
3. ตรวจสอบ Script ID
4. แสดง CLASPRC content ให้ copy ไปใส่ GitHub Secret

### ขั้นตอนที่ 3: ตั้ง GitHub Secrets

ไปที่: **https://github.com/Siriwat08/phaopanya-scg/settings/secrets/actions**

กด **"New repository secret"** แล้วเพิ่ม 2 ตัว:

#### 🔐 Secret 1: `CLASPRC`
- ใส่เนื้อหาทั้งหมดจากไฟล์ `~/.clasprc.json`
- (ได้จากการรัน `scripts/setup-clasp.sh`)

#### 🔐 Secret 2: `APPS_SCRIPT_ID`
- ค่า Script ID ของ Apps Script project
- หาได้จาก: เปิด https://script.google.com → Project Settings (⚙️) → IDs

#### 🔐 (Optional) Secret 3: `DEPLOY_WEBHOOK`
- Webhook URL สำหรับแจ้งเตือน Discord/Slack
- ถ้าไม่ใส่ workflow จะไม่ส่งแจ้งเตือน

### ขั้นตอนที่ 4: ทดสอบ

```bash
# สร้างไฟล์ test
echo "// Test" >> src/O_core_system/00_App.gs
git add .
git commit -m "test: ทดสอบ CI"
git push origin develop  # push ไป develop เพื่อไม่ให้ deploy
```

ไปดู Actions ที่: **https://github.com/Siriwat08/phaopanya-scg/actions**

---

## 🎯 การใช้งาน Workflow แต่ละตัว

### 1. 🔍 CI (ตรวจโค้ด)
**Trigger:** push ทุก branch + PR

**ทำอะไร:**
- ✅ ตรวจ syntax ของไฟล์ .gs (วงเล็บสมดุล, JSON valid)
- ✅ นับบรรทัด/ขนาดไฟล์
- ✅ ตรวจ Anti-pattern ตามกฎ 16 Immutable Laws
- ✅ ตรวจ Secret ห้ามหลุดเข้า repo
- ✅ ตรวจ Domain Architecture (3 กลุ่ม)
- ✅ ตรวจ REVIEW15 Compliance
- ✅ ตรวจ appsscript.json valid

**ดูผล:** Actions tab → CI run

---

### 2. 🚀 Deploy (Deploy จริง)
**Trigger:** push ไป `main` เท่านั้น (เพื่อความปลอดภัย)

**ทำอะไร:**
- 🛡️ Pre-flight: ตรวจ Secret + ไฟล์ที่จำเป็น
- 📦 ติดตั้ง clasp + Node.js
- 🔐 Login ด้วย CLASPRC
- 📥 Clone Apps Script project
- 📋 Copy source files
- 🚀 Push ไป Apps Script
- 📝 สร้าง versioned deployment
- ✅ Post-deploy verification (ดึงกลับมาเทียบ)
- 📢 แจ้งเตือน Discord/Slack (ถ้าตั้ง Webhook)

**⚠️ ข้อควรระวัง:**
- ตั้ง Environment `production` ใน GitHub Settings เพื่อบังคับ approve
- ทุก push ไป main = deploy จริง

**Manual deploy:**
- Actions → Deploy → Run workflow → ใส่ version label

---

### 3. 🔍 PR Validation (ตรวจ PR)
**Trigger:** เมื่อเปิด/update PR

**ทำอะไร:**
- 📊 ตรวจขนาด PR (แจ้งเตือนถ้าใหญ่เกิน)
- 🔍 ตรวจเฉพาะไฟล์ที่เปลี่ยน
- 🛡️ ตรวจ Anti-pattern (Law 1, 3, 16)
- 📋 ตรวจ Version bump
- 🏷️ ตรวจ PR Title (Conventional Commits)
- 💬 Auto comment บน PR พร้อม checklist
- 🏷️ Auto label (feature, bug, breaking-change, size)

---

### 4. 🏷️ Release (ตัด Tag)
**Trigger:** push ไป main (เฉพาะไฟล์ใน src/)

**ทำอะไร:**
- 🔍 ดึง Version ปัจจุบันจากโค้ด
- 📊 รวบรวม commits ตั้งแต่ tag ที่แล้ว
- 📝 สร้าง Release Notes อัตโนมัติ
- 🏷️ สร้าง Git Tag (auto-bump patch version)
- 📦 สร้าง GitHub Release
- 🆕 Manual: ระบุ version เองได้ (เช่น v5.6.0)

**Manual release:**
- Actions → Release → Run workflow → ใส่ version

---

### 5. 💓 Health Check (ตรวจสุขภาพ)
**Trigger:** ทุกวันจันทร์ 09:00 ICT (02:00 UTC)

**ทำอะไร:**
- 📊 ตรวจสถิติโปรเจกต์ (ไฟล์, บรรทัด, ขนาด)
- 🔍 ตรวจ VERSION tag ครบทุกไฟล์
- 📝 ดู commit activity
- 📢 แจ้งเตือนถ้าเจอปัญหา

---

### 6. 🛡️ CodeQL (Semantic Security Scan)
**Trigger:** push ทุก branch + PR + weekly schedule

**ทำอะไร:**
- 🔍 วิเคราะห์โค้ดด้วย CodeQL (semantic, ไม่ใช่แค่ regex)
- 🛡️ ตรวจหา SQL injection, XSS, hardcoded credentials, ฯลฯ
- 📝 อัปโหลดผลลัพธ์เข้า GitHub Security tab

---

### 7. 📚 Doc-Code Sync (9 checks)
**Trigger:** push ทุก branch + PR

**ทำอะไร:** รัน check scripts 9 ตัว (check_01 — check_09):
- ✅ check_01 — VERSION ในไฟล์ .gs ตรงกับ `01_Config.gs`
- ✅ check_02 — สถิติ (file count, line count, function count) ตรงกับที่อ้างใน docs
- ✅ check_03 — local path references (no absolute paths)
- ✅ check_04 — phantom dependencies (function calls ต้องมี definition)
- ✅ check_05 — internal markdown links ใช้ได้
- ✅ check_06 — verify fixed issues ใน docs ไม่กล่าวถึงปัญหาที่ยังไม่แก้
- ✅ check_07 — VERSION header + CHANGELOG entry match
- ✅ check_08 — DEPENDENCIES header ครบทุกไฟล์
- ✅ check_09 — DOC-TYPE coverage (ทุกไฟล์ .md ต้องมี DOC-TYPE tag)

---

### 8. 🔐 Gitleaks (Hardcoded Secret Scan)
**Trigger:** push ทุก branch + PR

**ทำอะไร:**
- 🔍 สแกนโค้ดและ commit history เพื่อหา hardcoded secrets (API keys, tokens, passwords)
- 🛡️ ป้องกันการ commit secret เข้า repo โดย accident
- 📝 แจ้งเตือนบน PR ถ้าเจอ secret

---

## 🛡️ Pre-commit Hook (แนะนำให้ติดตั้ง)

ติดตั้ง hook เพื่อตรวจก่อน commit:

```bash
cp scripts/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

ทุกครั้งที่ commit ระบบจะ:
- ❌ Block ถ้ามี Hardcoded Index
- ❌ Block ถ้ามี Secret
- ⚠️ เตือนถ้ามี setValue ในลูป
- ✅ ผ่านถ้าโค้ดสะอาด

---

## 🔧 Troubleshooting

### ❌ `clasp: command not found`
```bash
npm install -g @google/clasp
```

### ❌ `Permission denied` ตอน push
- ตรวจว่า Google account ที่ login มีสิทธิ์ edit Apps Script project
- ลอง `clasp login --status` ดูว่า login อยู่

### ❌ `Script ID not found`
- ตรวจ Secret `APPS_SCRIPT_ID` ว่าถูกต้อง
- ตรวจว่า Apps Script project ยังอยู่ (ไม่ถูกลบ)

### ❌ Workflow ไม่ทำงาน
1. ตรวจ GitHub Actions เปิดอยู่: Settings → Actions → General
2. ตรวจ branch name ตรงกับ trigger
3. ดู Logs ใน Actions tab

### ❌ Diff ไม่ตรงหลัง Deploy
- อาจมีไฟล์ที่ Apps Script ไม่มีใน repo
- ลอง `clasp pull` มาดูว่ามีอะไรต่าง

---

## 📞 ติดต่อ

- **Repo**: https://github.com/Siriwat08/phaopanya-scg
- **Issues**: https://github.com/Siriwat08/phaopanya-scg/issues
- **Wiki**: https://github.com/Siriwat08/phaopanya-scg/wiki

---

Made with ❤️ for Phaopanya Logistics Team