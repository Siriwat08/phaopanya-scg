<!-- DOC-TYPE: living -->

# 🔧 CI/CD Troubleshooting Guide — LMDS V6.0

> บันทึกปัญหา CI/CD ที่เจอ + วิธีแก้ เพื่อไม่ให้พลาดซ้ำ
> อัปเดต: 2026-07-16

---

## ปัญหาที่เจอและแก้แล้ว

### 1. check_01_version.sh — Version Inconsistency

**อาการ:** PR fail ที่ check_01 บอก "VERSION: X (expected Y)"

**สาเหตุ:** bump version ในไฟล์เดียว แต่ check_01 บังคับให้ทุกไฟล์เท่ากัน:

- VERSION header ในทุก .gs (39 ไฟล์)
- APP_VERSION + SCHEMA_VERSION ใน 01_Config.gs
- version ใน package.json

**วิธีแก้:**

```bash
# อย่า bump ด้วยมือ — ใช้ helper script
./scripts/bump_version.sh 6.0.060
```

**PR ที่เจอ:** #136, #137, #138 (เกิดซ้ำ 3 ครั้งก่อนสร้าง script)

---

### 2. prettier format:check — Extra Blank Lines

**อาการ:** PR fail ที่ `npm run format:check` บอก "Code style issues found"

**สาเหตุ:** Python script ที่ใช้ split/move โค้ดใส่ blank lines เกิน 1 บรรทัดระหว่าง sections — Prettier บังคับ blank line เดียว

**วิธีแก้:**

```bash
npx prettier --write src/path/to/file.gs
```

**PR ที่เจอ:** #137 (10f/10g/10h split)

---

### 3. SonarCloud — HTML/CSS Files Flagged

**อาการ:** SonarCloud flag .html files ใน docs/ai-reviews/ ทั้งที่ docs/** อยู่ใน exclusions

**สาเหตุ:** SonarCloud's HTML/CSS analyzers ทำงานแยกจาก `sonar.language=js` — folder exclusion ไม่ block HTML analyzer

**วิธีแก้ (ถาวร):**

1. ใช้ file-type patterns ใน `sonar.exclusions`:
   ```
   sonar.exclusions=...,**/*.html,**/*.css
   ```
2. สร้าง GitHub Actions workflow (`.github/workflows/09-sonarcloud.yml`) ที่ใช้ `sonar-scanner` CLI พร้อม `-D` args (override ทุกอย่าง)
3. ปิด SonarCloud's "Automatic Analysis" ใน dashboard เพื่อให้ workflow เป็นตัวสแกนหลัก

**⚠️ สำคัญ:** SonarCloud เก็บ issues เก่าใน database — แม้ exclude แล้ว ต้องรอ scan รอบใหม่ถึงจะ mark เป็น "Fixed"

**PR ที่เจอ:** #146, #147, #148, #149, #150, #151 (เกิดซ้ำ 6 ครั้งก่อนแก้ถูกจุด)

---

### 4. SonarCloud — Code Duplication

**อาการ:** Quality Gate fail บอก "4.7% Duplication on New Code (required ≤ 3%)"

**สาเหตุ:** 3 call sites ใน runMatchEngine() มี pattern ซ้ำกัน (releaseLock + resetContext + flushLog)

**วิธีแก้:** สกัด 3 บรรทัดซ้ำเป็น helper function เดียว — `cleanupMatchEngineRun_(lock)`

**PR ที่เจอ:** #146

---

### 5. Gitleaks — sonar-project.properties False Positive

**อาการ:** Gitleaks flag `sonar.projectKey=Siriwat08_phaopanya-scg` เป็น `generic-api-key`

**สาเหตุ:** SonarCloud project key มี entropy สูง (4.0018) — Gitleaks ตีความผิดว่าเป็น secret

**วิธีแก้:**

1. สร้าง `.gitleaks.toml` พร้อม allowlist:
   ```toml
   [[allowlists]]
   paths = ['''sonar-project\.properties$''']
   regexes = ['''sonar\.projectKey=.*''']
   ```
2. เปิดใช้ใน workflow: `GITLEAKS_CONFIG: .gitleaks.toml`

**PR ที่เจอ:** #134

---

### 6. Gitleaks — scan-mode Input Not Valid

**อาการ:** Warning "Unexpected input(s) 'scan-mode'" ใน Gitleaks workflow

**สาเหตุ:** `scan-mode` เป็น input ของ gitleaks-action เวอร์ชันใหม่ แต่เรา pin เป็น SHA เก่า

**วิธีแก้:** ลบ `scan-mode` input ออก — action จะ detect PR mode อัตโนมัติ

**PR ที่เจอ:** #134

---

### 7. GitHub Actions — Action Not Pinned to SHA

**อาการ:** CI fail บอก "Use full commit SHA hash for this dependency" (S7637)

**สาเหตุ:** Branch protection บังคับให้ทุก action ต้อง pin เป็น full SHA (ไม่ใช่ @v2)

**วิธีแก้:**

```bash
# หา SHA ของ tag ที่ต้องการ
curl -s "https://api.github.com/repos/<owner>/<repo>/git/refs/tags/v5.0.0" | grep sha
```

แล้วใช้: `uses: Owner/repo@<full-sha>  # v5.0.0`

**PR ที่เจอ:** #151 (SonarSource action)

---

### 8. GitHub Actions — Shell Args Split on Spaces

**อาการ:** Workflow fail บอก "ERROR Unrecognized option: from"

**สาเหตุ:** Path ที่มีช่องว่าง (เช่น "Information from AI allows you to check it quickly") ทำให้ shell แบ่ง args ผิด

**วิธีแก้:**

1. ลบ path ที่มีช่องว่างออกจาก CLI args (ใช้ folder exclusion แทน)
2. เปลี่ยน YAML `>` → `>-` (folded scalar, strip newline)

**PR ที่เจอ:** #150

---

### 9. GitHub Actions — Deprecated Action

**อาการ:** Warning "This action is deprecated and will be removed in a future release"

**สาเหตุ:** `SonarSource/sonarcloud-github-action` deprecated → เปลี่ยนเป็น `SonarSource/sonarqube-scan-action`

**วิธีแก้:** เปลี่ยน action name + หา SHA ใหม่:

```yaml
# ก่อน:
uses: SonarSource/sonarcloud-github-action@<sha>
# หลัง:
uses: SonarSource/sonarqube-scan-action@<sha>
```

**PR ที่เจอ:** #151

---

### 10. GitHub Actions — SONAR_TOKEN Missing

**อาการ:** Workflow fail บอก "Set the SONAR_TOKEN env variable"

**สาเหตุ:** ยังไม่ได้เพิ่ม `SONAR_TOKEN` secret ใน repo settings

**วิธีแก้:**

1. ไปที่ https://sonarcloud.io/account/security/
2. Generate token
3. เพิ่มใน repo: Settings > Secrets and variables > Actions > New repository secret
4. Name: `SONAR_TOKEN`, Value: (token)

---

### 11. Empty Commit — Files Lost During Merge

**อาการ:** PR title บอก "add lmds-supreme-engineer skill (7,287 lines)" แต่ไฟล์ไม่อยู่ใน main หลัง merge

**สาเหตุ:** PR ที่ซ้อนทับกัน (PR #133 vs #134) ทำให้ commit เป็น empty — ไฟล์หาย

**วิธีแก้:**

1. หลัง merge PR ที่อ้างว่าเพิ่มไฟล์ → ตรวจด้วย `git diff HEAD~1 --stat | grep <filename>`
2. ถ้าไฟล์ไม่อยู่ → สร้าง PR ใหม่เพื่อ restore

**PR ที่เจอ:** #133 (supreme-engineer skill หาย → กู้คืนใน PR #144)

---

### 12. check_09_doc_type_coverage — Missing DOC-TYPE Tag

**อาการ:** PR fail ที่ check_09 บอก ".md ใหม่ต้องระบุ DOC-TYPE ก่อน merge"

**สาเหตุ:** ทุกไฟล์ .md ต้องมี `<!-- DOC-TYPE: living -->` หรือ `<!-- DOC-TYPE: historical -->` ที่บรรทัดแรก

**วิธีแก้:**

```bash
# เพิ่ม DOC-TYPE ที่บรรทัดแรกของไฟล์ .md ใหม่
sed -i '1i <!-- DOC-TYPE: historical -->' docs/path/to/new-file.md
```

**PR ที่เจอ:** #127, #157 (ai-reviewer-4 report ไม่มี tag)

---

## ปัญหาที่ยังไม่ได้แก้ (Known Issues)

### check_05_internal_links — 8 Broken Links

**สถานะ:** ⚠️ Pre-existing (ไม่ใช่ PR ใหม่)

**รายละเอียด:** ลิงก์ที่มี `%20` (ภาษาไทย/ช่องว่าง) ใน README/CONTEXT — ไฟล์มีอยู่จริง แต่สคริปต์ไม่ decode URL

**ผลกระทบ:** ไม่ block CI (continue-on-error: true)

**แนวทางแก้:** แก้ check_05 ให้ decode `%20` ก่อนเช็ค — ทำใน Phase D-1

---

## วิธีตรวจสอบ CI ก่อน Push

```bash
# รันทุก checks พร้อมกัน
bash .github/scripts/doc-code-sync-checks/check_01_version.sh
bash .github/scripts/doc-code-sync-checks/check_02_stats.sh
bash .github/scripts/doc-code-sync-checks/check_04_phantom_deps.sh
bash .github/scripts/doc-code-sync-checks/check_06_verify_fixes.sh
bash .github/scripts/doc-code-sync-checks/check_09_doc_type_coverage.sh

# Prettier + ESLint
npx prettier --check "src/**/*.{gs,js,html,css}"
npx eslint src/ --ext .gs,.js,.html --quiet
```

หรือใช้ self-audit script (Phase D-4 — ยังไม่ได้สร้าง):

```bash
bash scripts/self_audit.sh
```
