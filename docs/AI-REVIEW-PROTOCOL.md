<!-- DOC-TYPE: living -->

# 🔍 AI Review Verification Protocol

> กฎสำหรับการรับรายงานจาก AI reviewer ภายนอก — ป้องกัน hallucination + false positive
>
> สร้าง: 2026-07-16 | เวอร์ชั่น: V6.0.061

---

## ทำไมต้องมี Protocol นี้

ในรอบการตรวจรีวิว LMDS V6.0 โดย AI 4 ท่าน เราพบว่า:

| Reviewer             | ข้อเสนอทั้งหมด | ถูกต้อง   | Hallucination     | False Positive   |
| -------------------- | -------------- | --------- | ----------------- | ---------------- |
| Reviewer 1           | 11             | 10 (91%)  | 0                 | 1 (ห้ามทำตาม)    |
| Reviewer 2           | 22             | 14 (64%)  | 0                 | 8 (ไม่เหมาะ GAS) |
| Reviewer 3           | 12             | 12 (100%) | 0                 | 0                |
| Reviewer 4 (ฉบับแรก) | 5              | 1 (20%)   | 4 (ไฟล์ไม่มีจริง) | 0                |
| Reviewer 4 (ฉบับแก้) | 5              | 3 (60%)   | 0                 | 2 (ตีความผิด)    |

**บทเรียน:** ถ้าเราทำตามทุกข้อเสนอโดยไม่ verify เราจะเสียเวลาแก้ของที่ไม่มีปัญหา + ทำลายโค้ดที่ทำงานอยู่แล้ว

---

## กฎที่ 1: Verify File Existence

**ก่อน act ตาม recommendation ใด ต้องตรวจว่าไฟล์ที่ AI อ้างมีจริง**

```bash
ls <file_path>
```

ถ้าไม่มี → ทิ้งข้อนั้น + mark เป็น "hallucination"

**ตัวอย่างที่เจอ:** Reviewer 4 อ้าง `src/4_group4_pipeline_mgr/Notification.gs` และ `src/O_core_system/DataStore.gs` — ไฟล์ทั้งสอง **ไม่มีอยู่จริง**

---

## กฎที่ 2: Verify Line Number

**อ่านบรรทัดที่ AI อ้าง + ±10 บรรทัดรอบข้าง**

```bash
sed -n '<line-10>,<line+10>p' <file>
```

ถ้าเนื้อหาไม่ตรงกับที่ AI บอก → ทิ้งข้อนั้น

**ตัวอย่างที่เจอ:** Reviewer 4 บอก `00_App.gs:110` มี `[FIX v003]` + `getSheetHeaders` — จริงๆ บรรทัด 110 คือ `.addItem('🔐 ตั้งค่า SCG Cookie', ...)` ไม่มีสิ่งที่อ้าง

---

## กฎที่ 3: Check for [FIX vXXX] Comments

**ก่อน mark เป็น "debt" หรือ "bug" ต้องเช็คว่ามี comment `[FIX vXXX]`**

```bash
grep -B2 -A2 "\[FIX v" <file>:<line>
```

ถ้ามี `[FIX vXXX]` → แปลว่าทำไปแล้ว ไม่ใช่ debt

**ตัวอย่างที่เจอ:** Reviewer 4 TD-002 บอก `03_SetupSheets.gs:281` มี hardcode 1000 — จริงๆ comment บอก `[FIX v003] ใช้จำนวนแถวจริงจากชีต ไม่ hardcode 1000` (ทำไปแล้ว!)

---

## กฎที่ 4: Context-Aware Reading

**ก่อน mark เป็น "security issue" ต้องอ่าน context รอบข้าง**

### 4a: String ที่ดูเหมือน secret

ถ้าเจอ string ที่ดูเหมือน API key → เช็คว่าเป็น **help text URL** หรือไม่

```bash
# ตัวอย่าง: aistudio.google.com/app/apikey เป็น help text ไม่ใช่ API key
sed -n '<line-5>,<line+5>p' <file>
```

**ตัวอย่างที่เจอ:** Reviewer 4 SEC-001 บอก line 479 มี API Key หลุด — จริงๆ เป็น help text URL ที่บอกผู้ใช้ว่าจะขอ API key ได้ที่ไหน

### 4b: Function call

ถ้าเจอ function call ที่ดูเหมือนไม่มี error handling → เช็คว่ามี **wrapper** หรือไม่

```bash
grep -n "<function_name>" <file>
```

### 4c: Number

ถ้าเจอ number ที่ดูเหมือน hardcoded → เช็คว่าเป็น **dynamic** หรือไม่

```bash
# ตัวอย่าง: getMaxRows() เป็น dynamic, 1000 เป็น hardcoded
grep -n "getMaxRows\|getLastRow\|hardcode" <file>
```

---

## กฎที่ 5: Cross-Reference Multiple Reviewers

**ถ้า AI หลายท่านแนะนำสิ่งเดียวกัน → high confidence**
**ถ้า AI ท่านเดียวแนะนำ → medium confidence (verify ก่อน)**
**ถ้า AI แนะนำขัดกับ GAS best practices → low confidence (อย่าทำ)**

### GAS Best Practices ที่ต้องรู้

| Pattern                                 | เหมาะกับ GAS? | เหตุผล                                            |
| --------------------------------------- | :-----------: | ------------------------------------------------- |
| `typeof === 'function'` guard           |      ✅       | GAS ไม่มี module system — ใช้สำหรับ optional deps |
| `PropertiesService` สำหรับ secrets      |      ✅       | ไม่มี .env ใน GAS                                 |
| `LockService` สำหรับ concurrency        |      ✅       | ไม่มี async/await แบบ Node.js                     |
| `getValues()` / `setValues()` (batch)   |      ✅       | ลด API calls — สำคัญเพราะ quota จำกัด             |
| Critical-Only audit logging             |      ✅       | GAS log quota จำกัด — ไม่ควร log ทุกอย่าง         |
| `escapeHtml()` output encoding          |      ✅       | เพียงพอสำหรับ XSS ป้องกัน                         |
| `typeof === 'function'` → module import |      ❌       | จะพัง — GAS ไม่มี module system                   |
| Rate limiting (30/min)                  |      ❌       | เป็น public API pattern — เราใช้ Google OAuth     |
| GasT / QUnitGS2 unit test               |      ❌       | abandoned projects — ใช้ snapshot test แทน        |
| `safeHtml_` type-brand                  |      ❌       | TypeScript pattern — GAS ไม่มี compile-time types |
| Audit log ทุก action                    |      ❌       | อันตราย — GAS quota log จำกัด                     |

---

## ขั้นตอนการ Verify (Step-by-Step)

เมื่อได้รับรายงานจาก AI reviewer ใหม่ ทำตามขั้นตอนนี้:

### Step 1: อ่านทั้งรายงานก่อน

อย่าเริ่มแก้ทันที — อ่านทั้งหมดก่อน เข้าใจ scope + methodology

### Step 2: สร้างตาราง verify

สร้างตารางที่มีคอลัมน์: `ข้อเสนอ | ไฟล์มีจริง? | บรรทัดตรง? | เป็น [FIX vXXX]? | Context ถูก? | สรุป`

### Step 3: Verify ทีละข้อ

```bash
# กฎ 1: ไฟล์มีจริง?
ls src/path/to/file.gs

# กฎ 2: บรรทัดตรง?
sed -n '100,120p' src/path/to/file.gs

# กฎ 3: เป็น [FIX vXXX]?
grep -B2 -A2 "\[FIX v" src/path/to/file.gs

# กฎ 4: Context ถูก?
sed -n '95,105p' src/path/to/file.gs
```

### Step 4: จัดประเภท

- ✅ **Do** — verify ผ่านทุกกฎ + คุ้มค่า
- ⚠️ **Adjust** — verify ผ่าน แต่ต้องปรับขนาด (เช่น ESLint 100→200)
- ❌ **Skip** — hallucination / false positive / ไม่เหมาะ GAS
- 🔜 **Defer** — verify ผ่าน แต่รอเงื่อนไข (เช่น ทีมโต)

### Step 5: Track ใน docs/TODO.md

บันทึกผลการ verify ใน `docs/TODO.md` เพื่อไม่ให้ตกหล่น

---

## ประวัติการใช้ Protocol นี้

| วันที่     | Reviewer          | ข้อเสนอ | ผ่าน | ทิ้ง | ปรับ |
| ---------- | ----------------- | ------- | ---- | ---- | ---- |
| 2026-07-15 | Reviewer 1        | 11      | 10   | 0    | 1    |
| 2026-07-15 | Reviewer 2        | 22      | 14   | 5    | 3    |
| 2026-07-15 | Reviewer 3        | 12      | 10   | 0    | 2    |
| 2026-07-16 | Reviewer 4 (เดิม) | 5       | 1    | 4    | 0    |
| 2026-07-16 | Reviewer 4 (แก้)  | 5       | 2    | 2    | 1    |

---

## อ้างอิง

- `docs/ai-reviews/COMPARATIVE_ANALYSIS.md` — เปรียบเทียบ AI 3 ท่านแรก
- `docs/ai-reviews/ai-reviewer-4/LMDS-Pre-DeliveryAuditReport.md` — Reviewer 4 (ฉบับแก้)
- `docs/TODO.md` — track ข้อเสนอที่ยังไม่ได้ทำ
- `docs/CI-CD-TROUBLESHOOTING.md` — ปัญหา CI/CD ที่เคยเจอ
