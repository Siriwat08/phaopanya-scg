<!-- DOC-TYPE: living -->
# AI Code Reviews — External Analysis Archive

This folder archives code review and analysis reports from 3 external AI agents
who reviewed the LMDS codebase. These documents are preserved as reference
material for future refactoring decisions.

## Structure

```
docs/ai-reviews/
├── ai-reviewer-1/   ← AI ท่านที่ 1 (.md, .html, .zip — อัปโหลดได้ทุกประเภท)
├── ai-reviewer-2/   ← AI ท่านที่ 2
├── ai-reviewer-3/   ← AI ท่านที่ 3
└── README.md        ← This file (คู่มือ — ไม่ต้องแก้ไข)
```

## What Can Be Uploaded

| ประเภทไฟล์ | ต้องทำอะไรก่อนอัปโหลด? | หมายเหตุ |
|-----------|------------------------|---------|
| `.md` | ไม่ต้อง — บอทจะเพิ่ม `<!-- DOC-TYPE: historical -->` ให้หลังอัปโหลด | ไฟล์หลักที่ใช้บทวิเคราะห์ |
| `.html` | ไม่ต้อง — SonarCloud ไม่ตรวจโฟลเดอร์นี้ | มักเป็น report ที่ export จาก AI |
| `.txt` | ไม่ต้อง | ข้อความดิบ |
| `.pdf` | ไม่ต้อง | เอกสาร |
| `.zip` | ไม่ต้อง | ไฟล์บีบอัด (เช่น lmds-supreme-engineer) |

**สรุป:** อัปโหลดได้ทุกประเภทเลยครับ ไม่ต้องเตรียมอะไรก่อน

## How to Upload

### สำหรับแต่ละ AI reviewer folder:
1. Navigate to the folder on GitHub (เช่น `docs/ai-reviews/ai-reviewer-1/`)
2. Click **"Add file"** → **"Upload files"**
3. Drag and drop all files for that AI (.md, .html, .zip, ฯลฯ)
4. Commit message: `docs: add AI review from <AI name>`
5. Click **"Commit changes"**

### กรณีพิเศษ: lmds-supreme-engineer
หากคุณมี `.zip` ของ lmds-supreme-engineer อัปโหลดได้ที่:
- `docs/ai-reviews/ai-reviewer-X/lmds-supreme-engineer.zip`

บอทจะแตกไฟล์และย้ายไป `.skills/lmds-supreme-engineer/SKILL.md` ให้หลังอัปโหลด

## Bot Workflow (หลังอัปโหลด)

เมื่อคุณอัปโหลดเสร็จทั้ง 3 ท่าน บอทจะ:
1. ✅ เพิ่ม `<!-- DOC-TYPE: historical -->` ให้ทุกไฟล์ .md ที่ยังไม่มี
2. ✅ อ่านเนื้อหาทุกไฟล์ครบถ้วน
3. ✅ เขียนเอกสารสรุป + เปรียบเทียบวิธีการวิเคราะห์ของ 3 ท่าน
4. ✅ สร้าง task list สำหรับข้อเสนอที่ยังไม่ได้ทำ
5. ⚠️ **ถามคุณก่อนลบไฟล์** — บอทจะไม่ลบไฟล์ใดๆ โดยไม่ได้รับการยืนยันจากคุณ

## What's Already Implemented from These Reviews

| Source | Recommendation | Status | PR |
|--------|---------------|--------|-----|
| AI reviews | Remove dead code (matchCalcFullScore_ + matchCalcGeoAnchorScore_) | ✅ Done | PR #136 (V6.0.049) |
| AI reviews | Split 10_MatchEngine.gs into 10f/10g/10h | ✅ Done | PR #137 (V6.0.050) |
| AI reviews | Move scoring functions to 10b | ✅ Done | PR #138 (V6.0.051) |
| AI reviews | 5-Layer Alias Safeguard (21b_AliasSafeguard.gs) | 🔜 Pending | Future PR |
| AI reviews | Version bump helper script | 🔜 Pending | Future PR |

## SonarCloud Exclusion

This folder is excluded from SonarCloud analysis via `sonar-project.properties`:
```
sonar.exclusions=...,**/docs/**,...
```

So .md, .html, .zip files here will NOT trigger SonarCloud issues.
