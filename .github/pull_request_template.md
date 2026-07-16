## 📝 Description

<!-- อธิบายว่า PR นี้ทำอะไร -->

## 🎯 Type of Change

- [ ] 🐛 Bug fix (non-breaking change)
- [ ] ✨ New feature (non-breaking change)
- [ ] 💥 Breaking change (fix/feature ที่ทำให้ของเดิมเสีย)
- [ ] 📝 Documentation
- [ ] ♻️ Refactor (ไม่เปลี่ยน behavior)
- [ ] ⚡ Performance improvement

## 📋 Module ที่แตะ

- [ ] 00_App.gs
- [ ] 01_Config.gs _(breaking change ต้องระวัง)_
- [ ] 02_Schema.gs _(breaking change ต้องระวัง)_
- [ ] 03-21: ________________
- [ ] 22_WebApp.gs / 22b / 22c
- [ ] 24_PipelineManager.gs
- [ ] 99_Legacy.gs (deprecated functions)

## ✅ 16 Immutable Laws Checklist

- [ ] **Law 1**: ไม่มี Hardcoded Index (ใช้ `XXX_IDX.NAME` แทน `row[N]`)
- [ ] **Law 2**: Single Writer Pattern (M_ALIAS เขียนโดย 10/21 เท่านั้น)
- [ ] **Law 3**: Batch Operations (ใช้ `setValues()` ไม่ใช่ `setValue()` ในลูป)
- [ ] **Law 4**: ใช้ Index จาก `01_Config`
- [ ] **Law 5**: Entry Point มี `try-catch`
- [ ] **Law 6**: Log error ด้วย `logError('Module', msg, err)`
- [ ] **Law 13**: ไม่มี Silent Fail
- [ ] **Law 16**: ไม่มี Secret ใน Cell (API Key/Cookie เก็บใน Script Properties)

## 🧪 Testing

<!-- ทดสอบยังไงบ้าง -->

- [ ] ทดสอบด้วยตัวเอง
- [ ] ทดสอบในโหมด [CMD: PREDEPLOY]
- [ ] ตรวจสอบ SYS_LOG ไม่มี error

## 🔍 Verification with grep (บังคับสำหรับ PR ที่แก้ logic)

<!-- ถ้า PR นี้แก้ logic หรือ fix bug — ต้อง grep ยืนยันกับ main HEAD จริงหลัง push -->
<!-- ตัวอย่าง: grep -n "BRANCH_NO" src/O_core_system/01_Config.gs → ต้องเจอ -->

```
grep ที่รัน:
ผลลัพธ์ (จาก origin/branch ไม่ใช่ local):
```

- [ ] ผ่าน — grep ยืนยัน fix อยู่จริงบน remote branch

## 📸 Screenshots / Evidence

<!-- แนบรูปหรือ log -->

## 🔗 Related Issues

<!-- เชื่อมโยง issue เช่น Fixes #123 -->

## 🚀 Deployment Notes

<!-- มีอะไรต้องทำเพิ่มหลัง deploy ไหม เช่น ตั้งค่า Script Property ใหม่ -->

## ⚠️ Rebase Safety (ถ้ามี conflict ระหว่าง rebase)

- [ ] ไม่ใช้ `git checkout --theirs` แบบ blind — ต้องอ่านทุกไฟล์ที่ resolve
- [ ] หลัง rebase + force push → grep ยืนยัน functional changes ยังอยู่
- [ ] ทำ PR ทีละตัว — merge ก่อนเปิด PR ถัดไป

## 🚦 Pre-Merge Checklist (V6.0.059+)

<!-- ทำเครื่องหมายเฉพาะข้อที่เกี่ยวข้องกับ PR นี้ -->

### ประเภท PR (เลือกอย่างเดียว)

- [ ] ♻️ **Refactor** — ไม่เปลี่ยน behavior (เช่น ย้ายฟังก์ชัน, เปลี่ยนชื่อตัวแปร)
- [ ] 🐛 **Bug fix** — แก้ไข behavior ที่ผิด (เช่น notes หาย, decision ผิด)
- [ ] ✨ **Feature** — เพิ่ม behavior ใหม่ (เช่น 5-Layer Safeguard, validateInput_)
- [ ] 📝 **Documentation** — เฉพาะ docs/SECURITY.md/CHANGELOG (ไม่แตะ src/)
- [ ] 🔧 **CI/CD** — เฉพาะ .github/workflows/ หรือ scripts/

### กฎสำคัญ (ตรวจทุกข้อ)

- [ ] **ถ้า Refactor:** ไม่ผสมกับ feature ใน PR เดียวกัน (แยก PR)
- [ ] **ถ้า Feature:** ไม่ผสมกับ refactor ใน PR เดียวกัน (แยก PR)
- [ ] **ถ้าสร้าง wrapper function:** grep ยืนยันไม่มี raw pattern เหลือ (`grep -rn "raw_pattern" src/`)
- [ ] **ถ้า bump version:** รัน `./scripts/bump_version.sh <new-version>` (อย่า bump ด้วยมือ)
- [ ] **ถ้าเพิ่ม/แก้ CI check:** ทดสอบบน PR นี้ก่อน merge
- [ ] **ถ้า AI recommendation:** verify file/line กับโค้ดจริงแล้ว (ดู `docs/AI-REVIEW-PROTOCOL.md`)
- [ ] **ถ้าเพิ่มไฟล์ .md ใหม่:** มี `<!-- DOC-TYPE: living -->` หรือ `<!-- DOC-TYPE: historical -->` ที่บรรทัดแรก

### Version Bump (ถ้ามี)

- [ ] รัน `./scripts/bump_version.sh` แล้ว (อย่าลืม!)
- [ ] CHANGELOG.md มี entry สำหรับเวอร์ชั่นใหม่
- [ ] README.md stats ตรงกับ check_02 (ถ้าจำนวนไฟล์/ฟังก์ชันเปลี่ยน)

### Final CI Check (รันทั้งหมดก่อน push)

```bash
bash .github/scripts/doc-code-sync-checks/check_01_version.sh
bash .github/scripts/doc-code-sync-checks/check_02_stats.sh
bash .github/scripts/doc-code-sync-checks/check_04_phantom_deps.sh
bash .github/scripts/doc-code-sync-checks/check_06_verify_fixes.sh
bash .github/scripts/doc-code-sync-checks/check_09_doc_type_coverage.sh
npx prettier --check "src/**/*.{gs,js,html,css}"
npx eslint src/ --ext .gs,.js,.html --quiet
```

- [ ] ทุก check เขียว
