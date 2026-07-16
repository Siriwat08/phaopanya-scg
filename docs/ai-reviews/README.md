<!-- DOC-TYPE: living -->

# AI Code Reviews — External Analysis Archive

This folder archives code review and analysis reports from 3 external AI agents
who reviewed the LMDS codebase. These documents are preserved as reference
material for future refactoring decisions.

## Structure

```
docs/ai-reviews/
├── ai-reviewer-1/   ← AI ท่านที่ 1 (multiple .md files)
├── ai-reviewer-2/   ← AI ท่านที่ 2 (multiple .md files)
├── ai-reviewer-3/   ← AI ท่านที่ 3 (multiple .md files)
└── README.md        ← This file
```

## How to Upload

### Step 1: Rename folders (optional)

If you know the AI names/identifiers, rename the folders:

- `ai-reviewer-1/` → e.g., `gemini-review/` or `claude-review/`
- `ai-reviewer-2/` → e.g., `chatgpt-review/`
- `ai-reviewer-3/` → e.g., `copilot-review/`

### Step 2: Upload .md files

For each AI reviewer folder:

1. Navigate to the folder on GitHub
2. Click **"Add file"** → **"Upload files"**
3. Drag and drop all .md files for that AI
4. Commit message: `docs: add AI review from <AI name>`
5. Click **"Commit changes"**

### Step 3: Add DOC-TYPE tag (IMPORTANT)

Each .md file MUST have a DOC-TYPE tag as the first line for check_09 to pass:

```markdown
<!-- DOC-TYPE: historical -->
```

**Option A (recommended):** Add the tag yourself before uploading
**Option B:** Upload first, then ask the bot to add tags in a follow-up commit

## What's Already Implemented from These Reviews

| Source     | Recommendation                                                    | Status     | PR                 |
| ---------- | ----------------------------------------------------------------- | ---------- | ------------------ |
| AI reviews | Remove dead code (matchCalcFullScore_ + matchCalcGeoAnchorScore_) | ✅ Done    | PR #136 (V6.0.049) |
| AI reviews | Split 10_MatchEngine.gs into 10f/10g/10h                          | ✅ Done    | PR #137 (V6.0.050) |
| AI reviews | Move scoring functions to 10b                                     | ✅ Done    | PR #138 (V6.0.051) |
| AI reviews | 5-Layer Alias Safeguard (21b_AliasSafeguard.gs)                   | 🔜 Pending | Future PR          |
| AI reviews | Version bump helper script                                        | 🔜 Pending | Future PR          |

## SonarCloud Exclusion

This folder is excluded from SonarCloud analysis via `sonar-project.properties`:

```
sonar.exclusions=...,**/docs/**,...
```

So .md and .html files here will NOT trigger SonarCloud issues.

## 📋 Status: Original files DELETED (V6.0.062)

ไฟล์ต้นฉบับทั้งหมดใน `ai-reviewer-{1,2,3,4}/` ถูกลบแล้ว (V6.0.062) — ข้อมูลสำคัญได้ถูกสกัดและบันทึกแล้วใน:

- `docs/ai-reviews/COMPARATIVE_ANALYSIS.md` — สรุปเปรียบเทียบ 3 reviewers
- `docs/AI-REVIEW-PROTOCOL.md` — 5 กฎ verify AI reports
- `docs/TODO.md` — track ข้อเสนอที่ยังไม่ได้ทำ
- `docs/CI-CD-TROUBLESHOOTING.md` — ปัญหา CI/CD ที่เคยเจอ

โฟลเดอร์ `ai-reviewer-{1,2,3,4}/` เก็บไว้เพื่อรอคำแนะนำใหม่ในอนาคต
