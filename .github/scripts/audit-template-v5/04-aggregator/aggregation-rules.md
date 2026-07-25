<!-- DOC-TYPE: living -->

# Aggregation Rules — กฎการรวมผล

> ใช้โดย Agent 4 (Aggregator) — ถ้า conflict กันระหว่าง Agent ให้ยึดตามนี้

---

## 1. Deduplication

ถ้า Agent 2 และ Agent 3 เจอ finding เดียวกัน (เช่น PII leak ใน logError):
- รวมเป็น 1 finding
- ระบุ "Reported by" ทั้ง 2 Agent
- ใช้ severity สูงกว่า

ตัวอย่าง:
- Agent 2 บอก P3 (cosmetic)
- Agent 3 บอก P0 (PII leak)
- → รวมเป็น P0, "Reported by: Agent 2 (informational), Agent 3 (authoritative)"

---

## 2. Priority Matrix

| Combination | Final severity |
|---|---|
| Static P0 + Runtime P0 | P0 |
| Static P1 + Domain P0 | P0 |
| Runtime P0 + Domain P1 | P0 |
| Static P2 + Runtime P1 | P1 |
| Any + Domain P0 (data corruption) | P0 |
| Any + Runtime P0 (crash) | P0 |

> **Data corruption และ runtime crash ชนะทุกอย่าง**

---

## 3. False positive handling

ถ้า Aggregator เห็นว่า finding น่าจะ false positive:
- ยังคงบันทึกไว้
- ใส่ marker `🤔 LIKELY_FP` ใน final report
- User จะเป็นคนตัดสิน

---

## 4. Template Gap promotion

ถ้า Agent 1/2/3 รายงาน Template Gap เดียวกัน (> 1 Agent เห็นตรงกัน):
- เลื่อนเป็น "STRONG_GAP"
- แนะนำให้ APPROVE แทน DEFER

ถ้า Agent เดียวเจอ และ severity P3:
- "WEAK_GAP"
- แนะนำ DEFER หรือเก็บไว้ดู

---

## 5. Release Verdict logic

```
P0_count == 0 AND P1_count <= 5  → 🟢 GO
P0_count == 0 AND P1_count > 5   → 🟡 CONDITIONAL
P0_count > 0                      → 🔴 NO-GO
```

Aggregator ไม่ตัดสินเอง — แค่คำนวณและแสดง

---

## 6. Re-run vs Skip

ถ้า finding ถูก mark ว่า "skipped" ใน Agent 1/2/3:
- บันทึกไว้ใน "Skipped" section ของ final report
- User ต้องรู้ว่ามี check ที่ข้ามไป (เพื่อ transparency)
