<!-- DOC-TYPE: living -->

# LMDS Skills Suite

ชุด Skills สำหรับ Mavis ที่ออกแบบมาเพื่อช่วย AI Agent และนักพัฒนาในการทำงานกับโปรเจกต์ **LMDS (Logistics Master Data System) V6.0** — ระบบจัดการข้อมูลหลักด้านการขนส่งที่พัฒนาบน **Google Apps Script + Google Sheets** สำหรับ SCG JWD Logistics

## รายการ Skills (10 ตัว)

| #   | Skill                           | Purpose                                     | ใช้เมื่อ...                                                                                   |
| --- | ------------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------- |
| 1   | **`lmds-architect`**            | Master architecture overview                | ต้องการเข้าใจโครงสร้างโปรเจกต์, 3-Domain Groups, 16 Laws, 8 Rules, 35 .gs files, Sheet schema |
| 2   | **`lmds-code-reviewer`**        | 16 Immutable Laws enforcement               | Review code, audit PR, enforce SRP / No Hardcode Index / Batch Operations / Security-First    |
| 3   | **`lmds-bug-hunter`**           | BUGHUNT scanner (Critical + Performance)    | หา bugs / critical issues / timeout / stale cache / scientific notation                       |
| 4   | **`lmds-refactor-advisor`**     | Refactor planning (SRP, complexity, length) | แตก god function, ลด coupling, plan major refactor                                            |
| 5   | **`lmds-predeploy-checker`**    | Production go/no-go gate                    | ก่อน deploy, ตรวจ 35-item checklist, verify version sync                                      |
| 6   | **`lmds-match-engine-builder`** | Trinity + 8 Rules + Hybrid Alias            | สร้าง/แก้ match logic, เพิ่ม rule ใหม่, debug matching                                        |
| 7   | **`lmds-gas-best-practices`**   | GAS limitations & workarounds               | 6-min limit, CacheService 100KB, LockService, custom function, clasp                          |
| 8   | **`lmds-cicd-pipeline`**        | GitHub Actions for clasp                    | ตั้ง CI/CD, แก้ deploy fail, เพิ่ม workflow, secret management                                |
| 9   | **`lmds-security-auditor`**     | SEC-001 → SEC-012 (12 fixes)                | Security review, hardcoded secret, PII leak, OAuth scope, sheet protection                    |
| 10  | **`lmds-thai-data-helper`**     | Thai name/address/phonetic/geo              | Thai prefix stripping, phone normalization, Double Metaphone, Thai geo lookup                 |

## Decision Tree — เลือก Skill ที่ถูกต้อง

```
❓ คำถามของผู้ใช้
│
├─ "โปรเจกต์นี้คืออะไร / ทำอะไรได้ / โครงสร้างเป็นยังไง"
│  └─> lmds-architect ✅ (load อันนี้ก่อนเสมอ)
│
├─ "โค้ดนี้ผ่าน 16 Laws ไหม / review code"
│  └─> lmds-code-reviewer ✅
│
├─ "หา bug / critical issue / performance / timeout"
│  └─> lmds-bug-hunter ✅
│
├─ "function นี้ยาวเกินไป / แตก god function ยังไง"
│  └─> lmds-refactor-advisor ✅
│
├─ "พร้อม deploy หรือยัง / pre-deploy check"
│  └─> lmds-predeploy-checker ✅
│
├─ "เพิ่ม match rule ใหม่ / แก้ 8-rule / Trinity / Alias"
│  └─> lmds-match-engine-builder ✅
│
├─ "GAS timeout / CacheService / clasp / Trigger ใช้ยังไง"
│  └─> lmds-gas-best-practices ✅
│
├─ "CI/CD / GitHub Actions / workflow พัง"
│  └─> lmds-cicd-pipeline ✅
│
├─ "Security audit / SEC-001 / PII / hardcoded secret"
│  └─> lmds-security-auditor ✅
│
└─ "Thai name / Thai address / prefix / province / phonetic"
   └─> lmds-thai-data-helper ✅
```

## Quick Start

```bash
# 1. Extract this archive
tar -xzf lmds-skills-suite.zip -C /your/workspace/

# 2. Verify
ls /your/workspace/.skills/lmds-*/SKILL.md

# 3. End current Mavis session, start a new one
#    → skills auto-sync to agent roster
```

## Trigger Keywords (อัตโนมัติ load)

- `lmds-architect` → "LMDS", "phaopanya", "Trinity", "16 Immutable Laws", "8 Match Rules"
- `lmds-code-reviewer` → "/REVIEW15", "code review", "law check", "compliance"
- `lmds-bug-hunter` → "/BUGHUNT", "find bugs", "critical issue", "timeout"
- `lmds-predeploy-checker` → "/PREDEPLOY", "ready to deploy", "go-live"
- `lmds-match-engine-builder` → "match engine", "8-rule", "Hybrid Alias", "M_ALIAS"
- `lmds-gas-best-practices` → "GAS limit", "6 minute timeout", "CacheService", "clasp"
- `lmds-cicd-pipeline` → "GitHub Actions", "workflow", "clasp push failed", "deploy"
- `lmds-security-auditor` → "SEC-001", "PII", "hardcoded secret", "OAuth scope"
- `lmds-thai-data-helper` → "Thai name", "prefix", "province", "Double Metaphone"
- `lmds-refactor-advisor` → "/REFACTOR", "god function", "SRP violation", "complexity"

แค่พูดคำเหล่านี้ใน prompt → skill ที่ตรงจะ load เองอัตโนมัติ

## Source

- **Project:** https://github.com/Siriwat08/phaopanya-scg
- **Version:** LMDS V6.0.046
- **Created:** 2026-07-13
- **License:** MIT
