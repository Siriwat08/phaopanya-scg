<!-- DOC-TYPE: living -->
# LMDS Skills Export

โฟลเดอร์นี้รวบรวมไฟล์ Export ของ LMDS Skills ทั้ง 10 ตัว สำหรับนำไปใช้งานกับ AI platforms ต่างๆ อย่างสมบูรณ์แบบ
*อัปเดตล่าสุดจากการแปลงไฟล์ SKILL.md ดั้งเดิม*

## 📂 โครงสร้างและวิธีใช้งาน

### 1. Google Gemini (โฟลเดอร์ `gemini/`)
- **`gemini_individual/`**: (แนะนำ) นำไฟล์ `.txt` แต่ละอันไปใส่เป็น System Instructions แยกกันใน Google AI Studio เพื่อไม่ให้กิน Context เปล่าๆ ในเรื่องที่ไม่เกี่ยวข้อง
- **`gemini_master_prompt.txt`**: รวมทุก skill ไว้ในไฟล์เดียว พร้อม **Decision Tree** นำไปแปะใน System Instructions หรือ Prompt ครั้งเดียวจบ (เหมาะสำหรับ Gemini 1.5/2.0 ที่รองรับ Context ได้ 1M-2M tokens)
- **`gemini_skills_config.json`**: สำหรับนักพัฒนาที่ต้องการนำไปใช้เรียกผ่าน Gemini API

### 2. Claude - Anthropic (โฟลเดอร์ `claude/`)
- **`claude_individual/`**: (แนะนำ) นำไฟล์ `.md` ไปอัปโหลดเข้า **Claude Projects** ในส่วนของ Project Knowledge
- **`claude_master_prompt.md`**: รวมทุก skill ไว้ในไฟล์เดียว นำไปแปะเป็น Custom Instructions (System Prompt) ของ Claude 
- **`claude_skills_config.json`**: สำหรับการเรียกใช้งานผ่าน Claude API แบบมีโครงสร้าง

### 3. Universal (โฟลเดอร์ `universal/`)
- **`skills/`**: ไฟล์ markdown สะอาด (ตัด YAML header ออกแล้ว) เหมาะสำหรับนำไปใช้อ้างอิงกับ AI Editor เช่น Cursor, Windsurf หรือ GitHub Copilot
- **`skills_registry.yaml`**: ไฟล์สารบัญ (Metadata) ของระบบ สำหรับการสร้าง custom loader

## 🛠️ การปรับปรุงที่ทำในเวอร์ชันนี้
1. ตัด YAML frontmatter ออกจากเนื้อหาหลัก เพื่อไม่ให้รบกวน AI Prompting
2. เพิ่ม Decision Tree อัตโนมัติใน Master Prompt เพื่อให้ AI รู้ว่าควรดึง Skill ไหนมาใช้เมื่อใด
3. แก้ไขบั๊กเนื้อหาที่ขาดหายใน `lmds-refactor-advisor` และเคลียร์ข้อความส่วนเกินใน `lmds-thai-data-helper`
