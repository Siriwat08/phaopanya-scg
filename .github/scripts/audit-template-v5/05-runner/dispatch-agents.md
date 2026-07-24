# วิธีรัน 3 Agent แบบ Parallel (สำหรับคนที่มี AI Agent หลายตัว)

> คุณบอกว่าอยาก "แยก Agent แล้วเอาผลมาต่อกัน" — นี่คือวิธี

---

## 🎯 Pattern A: 3 Session แยกกัน (แนะนำสำหรับ AI Agent หลายตัว)

### ขั้นที่ 1: Spawn 3 Session
```
Session 1: agent_name = "static-auditor"
  System prompt: 01-static/agent.md
  First user message: "ตรวจ LMDS ที่ /path/to/repo"

Session 2: agent_name = "runtime-gas-auditor"
  System prompt: 02-runtime-gas/agent.md
  First user message: "ตรวจ LMDS ที่ /path/to/repo"

Session 3: agent_name = "domain-logic-auditor"
  System prompt: 03-domain-logic/agent.md
  First user message: "ตรวจ LMDS ที่ /path/to/repo"
```

### ขั้นที่ 2: รอ 3 Session จบ → เก็บ report
แต่ละ Session จะเขียน report ลง:
- `06-evidence/static-report.md`
- `06-evidence/runtime-report.md`
- `06-evidence/domain-report.md`

### ขั้นที่ 3: Spawn Session 4 (Aggregator)
```
Session 4: agent_name = "audit-aggregator"
  System prompt: 04-aggregator/agent.md
  First user message: "อ่าน 06-evidence/{static,runtime,domain}-report.md แล้วสร้าง final-report.md"
```

### ขั้นที่ 4: คุณ (user) ตรวจ final-report
- ดู P0 → fix ก่อน deploy
- ดู Template Gaps → approve/reject/defer
- ตัดสิน release verdict

---

## 🎯 Pattern B: 1 Agent แต่สลับ persona (เหมาะกับ context window เล็ก)

```
คุณ 1 prompt → "คุณคือ Agent 1 (Static Audit). ตรวจ repo. เขียน static-report.md"
คุณ 1 prompt ต่อ → "ตอนนี้คุณคือ Agent 2 (Runtime-GAS). ตรวจ repo. เขียน runtime-report.md"
คุณ 1 prompt ต่อ → "ตอนนี้คุณคือ Agent 3 (Domain-Logic). ตรวจ repo. เขียน domain-report.md"
คุณ 1 prompt ต่อ → "ตอนนี้คุณคือ Agent 4 (Aggregator). รวม 3 report → final-report.md"
```

> Pattern B ใช้ context น้อยกว่า แต่ Agent เดียวอาจมี bias สะสม

---

## 🎯 Pattern C: Shell script (เร็วที่สุด แต่ไม่ละเอียดเท่า AI)

```bash
cd audit-template
./05-runner/run-audit.sh /path/to/lmds-repo all
```

ผลที่ได้คือ raw output จาก check scripts ใน 3 report
**แต่ไม่มี** AI analysis (evidence interpretation, fix proposal, severity grading ที่ละเอียด)

→ เหมาะสำหรับ "quick check" ระหว่าง dev

---

## 📊 เปรียบเทียบ

| | Pattern A (3 session) | Pattern B (1 session, 4 personas) | Pattern C (shell) |
|---|---|---|---|
| **ความละเอียด** | สูงสุด | สูง | ต่ำ |
| **Speed** | ช้า (parallel ได้) | กลาง | เร็ว |
| **Cost** | 3-4× token | 1× token | น้อยมาก |
| **Bias risk** | ต่ำ (แยก session) | กลาง (accumulated bias) | ต่ำ (rule-based) |
| **เหมาะกับ** | Production release | Sprint end | Daily dev |

---

## ✅ คำแนะนำของผม

ใช้ **Pattern A** สำหรับการ audit ก่อน release (ตรงตามที่คุณอธิบาย)
ใช้ **Pattern C** สำหรับ daily check
ใช้ **Pattern B** เมื่อ context window เล็ก
