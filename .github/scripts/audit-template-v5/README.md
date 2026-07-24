# LMDS V6.0 — Master Inspection Template

> เทมเพลตตรวจสอบ LMDS V6.0 แบบครอบคลุม 100%
> **ไม่ผูกเวอร์ชั่น** • **ขยายได้** • **ใช้ได้กับทุก release**
> **ชุดรวม 5 (FINAL)** — 49 check scripts (13 ST + 14 RT + 14 DM + 8 SEC) + DS-000 wrapper (auto-run 18 LMDS doc-sync checks)
> **ครอบคลุม SEC-001..012 ครบ + Doc-Sync 18 ตัว + 0 false positives (validated 7 RUN cycles)**

> **📌 บริบท LMDS:** ฝังเข้า repo ใน V6.0.074 (PR #201) — ใช้สำหรับรัน audit ก่อน deploy
> ดู `docs/ai-reviews/COMPARATIVE_ANALYSIS.md` section 14 สำหรับผลการ validate บน V6.0.073

---

## 🎯 เทมเพลตนี้ทำอะไร

| ความสามารถ | รายละเอียด |
|---|---|
| **ครอบคลุม 100%** | 39 .gs, 19 HTML, 9 workflows, 18 sync scripts, 11 skills, 38 docs, 21 Immutable Laws, **36 check scripts ครบทุกข้อ** |
| **ไม่ผูกเวอร์ชั่น** | ไม่มี `LMDS_VERSION` — version มาจาก repo ที่ตรวจ |
| **ขยายได้** | เพิ่ม check ใหม่ผ่าน `EXTENDING.md` ไม่ต้องแก้ Agent |
| **แยก Agent ได้** | 3 Agent ตรวจคนละมิติ (Static / Runtime / Domain) |
| **ส่งมอบ 100% no defect** | ทุก finding มี `path:line` + evidence + fix |

---

## 🚀 Quick Start

```bash
# 1. รัน audit (shell-only mode, เร็วสุด)
cd audit-template
bash 05-runner/run-audit.sh /path/to/lmds-repo all

# 2. ดู 3 report ใน 06-evidence/
ls 06-evidence/

# 3. ส่ง 3 report ให้ AI Agent ทำหน้าที่ Aggregator
#    ใช้ system prompt จาก 04-aggregator/agent.md
```

---

## 📁 โครงสร้าง

```
audit-template/
├── 00-MASTER/
│   ├── README.md              ← ไฟล์นี้ (entry point)
│   ├── CHECKS.md              ← flat index ของ check ทั้งหมด
│   └── EXTENDING.md           ← วิธีเพิ่ม check ใหม่ (สำคัญมาก)
├── 01-static/                 ← Agent 1: Static (structure, header, naming, lint)
│   ├── agent.md
│   └── checks/                ← 13 check scripts (ST-001..ST-013)
├── 02-runtime-gas/            ← Agent 2: Runtime / GAS (quota, lock, batch, cache)
│   ├── agent.md
│   └── checks/                ← 14 check scripts (RT-001..RT-014)
├── 03-domain-logic/           ← Agent 3: Domain (Match, RBAC, Thai, security, SEC-001..012)
│   ├── agent.md
│   └── checks/                ← 21 check scripts (DM-001..DM-021, includes 8 SEC)
├── 04-aggregator/             ← Agent 4: รวมผล + จัด priority
│   ├── agent.md
│   └── aggregation-rules.md
├── 05-runner/                 ← Orchestrator
│   ├── run-audit.sh
│   └── dispatch-agents.md
├── 05-doc-sync/               ← Agent 5 NEW: Auto-run LMDS existing doc-code-sync checks
│   └── checks/
│       └── DS-000-run-existing-doc-sync.sh  ← runs 18 LMDS checks automatically
└── 06-evidence/               ← output ของการตรวจ (สร้างตอนรัน)
    ├── static-report.md       ← จาก Agent 1
    ├── runtime-report.md      ← จาก Agent 2
    ├── domain-report.md       ← จาก Agent 3
    ├── docsync-report.md      ← จาก Agent 5 (NEW)
    └── final-report.md        ← จาก Agent 4 (ตัวอย่าง)
```

---

## 🧬 3 Agent — แยกหน้าที่ชัดเจน

| Agent | มิติ | ไม่ทำอะไร |
|---|---|---|
| **Agent 1 — Static** | โครงสร้าง, header, naming, lint, cross-file | runtime, business |
| **Agent 2 — Runtime/GAS** | quota, lock, batch, time, cache, CDN, library | structure, business |
| **Agent 3 — Domain Logic** | Match Engine, RBAC, Thai, security, PII, formula injection | structure, runtime (ยกเว้น PII) |
| **Agent 4 — Aggregator** | รวม 3 report, จัด priority, แนะนำ release verdict | ไม่ตรวจเอง |

> แต่ละ Agent มี **system prompt** ใน folder ของตัวเอง → copy ไปใช้กับ AI tool ใดก็ได้

---

## 📊 สิ่งที่ครอบคลุม (Coverage Matrix)

| Layer | จำนวน | Agent | หมายเหตุ |
|---|---:|---|---|
| Source code (.gs) | 39 | ทั้ง 3 | 5 groups |
| WebApp HTML | 19 | Static + Runtime | views, components |
| GitHub Workflows | 9 | Runtime | CI/CD |
| doc-code-sync checks | 18 | Runtime | ตัวตรวจเดิม |
| Specialized skills | 11 | Domain | skill catalog |
| Immutable Laws | 16+5 | ทั้ง 3 | แยกตามมิติ |
| Documentation | 38 | Static | TH + EN |
| Config files | 5 | Static | appsscript, package, eslint |
| Security (SEC-001..012) | 12 | Domain | full coverage |
| Performance (quota) | dynamic | Runtime | URL fetch, email, sheets write |

> **ถ้าเจอ artifact ที่ไม่อยู่ใน matrix** → บันทึกเป็น **Template Gap** ใน report แล้วให้ user เพิ่มใน EXTENDING.md

---

## 🛠️ 3 วิธีใช้งาน (เลือกตามเคส)

### 1. Shell-only (เร็วสุด, ~5 วินาที)
```bash
bash 05-runner/run-audit.sh /path/to/repo all
```
ได้: 3 report (raw) — ไม่มี AI analysis

### 2. AI Agent เดียว 4 personas (กลางๆ)
ส่ง 4 prompt ตามลำดับ:
1. `01-static/agent.md` + "ตรวจ repo X"
2. `02-runtime-gas/agent.md` + "ตรวจ repo X"
3. `03-domain-logic/agent.md` + "ตรวจ repo X"
4. `04-aggregator/agent.md` + "รวม 3 report"

ได้: final report ครบ + template gaps

### 3. 3 Session แยก (ละเอียดสุด, แนะนำสำหรับ production release)
ดู `05-runner/dispatch-agents.md` → Pattern A

---

## 🧠 กฎเหล็ก 5 ข้อ (อย่าละเมิด)

1. **Checklist-first, Tool-second** — เริ่มจาก CHECKS.md เสมอ
2. **Evidence is law** — ทุก finding มี `path:line` + snippet
3. **Severity tiered** — P0/P1/P2/P3 เท่านั้น
4. **No silent pass** — skip = ต้องบอกเหตุผล
5. **Propose, don't invent** — Agent ไม่เพิ่ม check เอง → Template Gap

---

## 📜 License & เครดิต

เทมเพลตนี้สร้างจาก:
- **LMDS V6.0.072** codebase (`Siriwat08/phaopanya-scg`)
- 16 Immutable Laws + 5 Hard Rules (จาก `.skills/lmds-code-reviewer`)
- 18 doc-code-sync checks (จาก `.github/scripts/`)
- 11 specialized skills (จาก `.skills/`)
- SEC-001..012 (จาก `.skills/lmds-security-auditor`)

ใช้งานได้กับ LMDS ทุกเวอร์ชั่น — ไม่ผูก version

---

## 🔗 เริ่มต้น

- อ่าน `00-MASTER/README.md` — ภาพรวม
- อ่าน `00-MASTER/EXTENDING.md` — ถ้าจะเพิ่ม check ใหม่
- ดู `06-evidence/final-report.md` — ตัวอย่าง output
- รัน `bash 05-runner/run-audit.sh /path/to/repo` — เริ่มใช้
