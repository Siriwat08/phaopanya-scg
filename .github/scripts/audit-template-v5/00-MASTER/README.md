# LMDS V6.0 — Master Inspection Template

> **คำเตือนด้านเวอร์ชั่น** — ไฟล์นี้ **ไม่ผูกกับเวอร์ชั่น** ของ LMDS (6.0.xxx) โดยตั้งใจ
> เพราะ checklist จะถูกใช้ซ้ำกับทุก release และต้องไม่ต้องมาแก้ทุกครั้งที่ version bump
> ถ้ามี check ใหม่ที่อยากเพิ่ม → ดูวิธีที่ `EXTENDING.md`

---

## 🎯 เป้าหมายของเทมเพลตนี้

| เป้าหมาย | คำอธิบาย |
|---|---|
| **ครอบคลุม 100%** | ทุก artifact ใน LMDS ต้องมี check (5 code groups, 9 workflows, 18 sync scripts, 11 skills, 38 docs, 19 HTML, 21 Immutable Laws, 5 Hard Rules) |
| **ขยายได้** | เพิ่ม check ใหม่ได้ทันที โดยไม่กระทบ check เดิม |
| **แยก Agent ได้** | 3 Agent ตรวจคนละมิติ (Static / Runtime / Domain) แล้ว Aggregator รวมผล |
| **ส่งมอบ 100% no defect** | ทุก finding ต้องมี evidence (ไฟล์:บรรทัด) + fix proposal + severity |
| **ไม่ผูกเวอร์ชั่น** | ไม่มี `LMDS_VERSION` ในเทมเพลต — version จะมาจาก repo ที่ตรวจ |

---

## 📁 โครงสร้าง

```
audit-template/
├── 00-MASTER/                      ← ไฟล์นี้ + EXTENDING.md + CHECKS.md (รายการ check หลัก)
├── 01-static/                      ← Agent 1: Static Audit (โครงสร้าง, header, deps, naming, lint)
│   ├── agent.md                    ← system prompt ของ Agent 1
│   └── checks/                     ← check scripts แบบ static
├── 02-runtime-gas/                 ← Agent 2: Runtime / GAS-specific (quota, lock, batch, time)
│   ├── agent.md
│   └── checks/
├── 03-domain-logic/                ← Agent 3: Domain Logic (Match Engine, RBAC, Thai data, security)
│   ├── agent.md
│   └── checks/
├── 04-aggregator/                  ← Agent 4: รวมผล + จัด priority + แจ้ง "ควรเพิ่มเข้าเทมเพลต"
│   ├── agent.md
│   └── aggregation-rules.md
├── 05-runner/                      ← Orchestrator: รัน 3 Agent แบบ parallel, เก็บ evidence
│   ├── run-audit.sh                ← main entry point
│   └── dispatch-agents.md
├── 06-evidence/                    ← output ของการตรวจ (สร้างตอนรัน)
│   ├── static-report.md
│   ├── runtime-report.md
│   ├── domain-report.md
│   └── final-report.md             ← ผลรวมสุดท้าย
└── EXTENDING.md                    ← วิธีเพิ่ม check ใหม่เข้าเทมเพลต (สำคัญมาก อ่านก่อน)
```

---

## 🧬 หลักการ 5 ข้อ (อย่าละเมิด)

1. **Checklist-first, Tool-second** — เริ่มจากรายการ check ก่อน แล้วค่อยเขียน tool
2. **Evidence is law** — ทุก finding ต้องมี `path:line` + snippet + คำแนะนำแก้
3. **Severity tiered** — ใช้ระดับ P0/P1/P2/P3 เท่านั้น (ห้ามใช้คำว่า "minor/major" คลุมเครือ)
4. **No silent pass** — ถ้า Agent ตรวจไม่ได้ ต้องบอก "skipped" + เหตุผล ไม่ปล่อยผ่าน
5. **Propose, don't invent** — Agent ห้ามเพิ่ม check ใหม่เอง แต่ต้อง **แจ้ง** ให้ user เพิ่มใน `EXTENDING.md`

---

## 🚀 เริ่มใช้งาน

### แบบเร็ว (1 คำสั่ง)
```bash
cd audit-template/05-runner
./run-audit.sh /path/to/lmds-repo
```

### แบบแยก Agent (manual)
1. อ่าน `01-static/agent.md` → รัน check ของ Agent 1
2. อ่าน `02-runtime-gas/agent.md` → รัน check ของ Agent 2
3. อ่าน `03-domain-logic/agent.md` → รัน check ของ Agent 3
4. อ่าน `04-aggregator/agent.md` → รวม report ทั้ง 3 → ผลลัพธ์ใน `06-evidence/final-report.md`

### แบบขยาย (เพิ่ม check ใหม่)
→ อ่าน `EXTENDING.md` (สำคัญที่สุดถ้าอยากปรับเทมเพลต)

---

## 📊 Coverage Matrix (สรุปสิ่งที่เทมเพลตนี้ครอบคลุม)

| Layer | จำนวน | Agent ที่รับผิดชอบ | หมายเหตุ |
|---|---:|---|---|
| **Source code (.gs)** | 39 | Static + Runtime + Domain | ครอบคลุมทั้ง 5 groups |
| **WebApp HTML** | 19 | Static + Runtime | views, components, js |
| **GitHub Workflows** | 9 | Runtime | CI/CD gates |
| **doc-code-sync checks** | 18 | Runtime | ตัวตรวจที่มีอยู่ |
| **Specialized skills** | 11 | Domain | skill catalog |
| **Immutable Laws** | 16+5 | ทั้ง 3 Agent | แยกตามมิติ |
| **Documentation** | 38 | Static | เอกสารภาษาไทย+EN |
| **Config files** | 5 | Static | appsscript.json, package.json, .eslintrc, etc. |
| **Security surface** | 12 | Domain | SEC-001 ถึง SEC-012 |
| **Performance surface** | dynamic | Runtime | quota, time, batch |

> **ถ้าเจอ artifact ที่ไม่อยู่ใน matrix** → ต้องเพิ่มที่ `EXTENDING.md` (อย่า hardcode check ใหม่)
