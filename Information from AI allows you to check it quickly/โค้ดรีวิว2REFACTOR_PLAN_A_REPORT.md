# Refactor Plan A — แตก 10_MatchEngine.gs (Execution Report)

## สิ่งที่ทำเสร็จแล้ว

สร้าง `10f_MatchAliasEnrichment.gs` (722 บรรทัด, 13 ฟังก์ชัน) โดย **extract แบบ
verbatim 100%** — ไม่แก้ logic แม้แต่บรรทัดเดียว ยืนยันด้วย `diff` เทียบกับต้นฉบับ
บรรทัดต่อบรรทัดแล้ว (identical)

**ฟังก์ชันที่ย้าย (เรียงตามลำดับเดิม):**
1. `addEntityToEnrichmentContext_` (+ module state `_ALIAS_ENRICHMENT_CONTEXT`)
2. `autoEnrichAliasesFromFactBatch_` — 🟩 Single Writer entry point (ไม่เปลี่ยน)
3. `prepareAliasEnrichmentData_`
4. `matchBuildDedupSets_`
5. `processFactRowsForAliases_`
6. `matchEnrichEntityAliases_`
7. `matchEnrichPersonAliases_`
8. `matchEnrichPlaceAliases_`
9. `commitAliasChanges_`
10. `cleanupStaleCanonicalAliases_`
11. `matchCommitGlobalAlias_`
12. `matchCommitPersonAlias_`
13. `matchCommitPlaceAlias_`

**Syntax check:** ผ่าน (`node --check`) ✅

---

## ⚠️ ประเด็นสำคัญที่พบระหว่างทำ — cross-file state coupling

`_ALIAS_ENRICHMENT_CONTEXT` เป็น module-level `let` ที่ไม่ได้ถูกใช้แค่ในกลุ่มฟังก์ชัน
ที่ย้าย — `runMatchEngine()` (orchestration, ต้องอยู่ใน `10_MatchEngine.gs` ต่อ) มีจุด
reset ตัวแปรนี้เป็น `null` อยู่ 3 จุด (early-return ตอน preflight fail, early-return ตอน
ไม่มี pending rows, และใน `finally` block ตอนจบ execution)

**นี่ทำงานได้ปกติ** เพราะ GAS V8 runtime concatenate ทุกไฟล์ `.gs` เป็น script เดียว
ก่อน execute (ตามที่ระบุไว้ในโจทย์ audit ตั้งแต่ต้น: "all .gs files share a single
global scope") — แต่ผมทำเครื่องหมายไว้ชัดเจนในคอมเมนต์หัวไฟล์ใหม่ เพราะเป็นจุดที่
**เสี่ยงต่อการพังเงียบๆ ถ้ามีคนมาแก้ทีหลังโดยไม่รู้ที่มา** (เช่น ถ้าเปลี่ยนชื่อตัวแปรใน
10f แต่ลืมไล่แก้ 10_MatchEngine.gs ทั้ง 3 จุด จะไม่มี compile error เพราะ GAS ไม่
type-check ข้ามไฟล์ — จะพังตอนรันจริงเท่านั้น)

---

## ต้องทำเอง: ลบโค้ดออกจาก `10_MatchEngine.gs`

**ไม่ได้แก้ไฟล์ต้นฉบับให้อัตโนมัติ** (เหตุผลเดียวกับรอบที่แล้ว — ให้คุณรีวิวก่อน apply)
วิธีลบที่ตรงที่สุด: ลบ **บรรทัด 56-85 และบรรทัด 492-1134** ของ `10_MatchEngine.gs`
ปัจจุบัน (2 ช่วง ไม่ติดกัน) แล้วแทนที่ด้วยคอมเมนต์ชี้ตำแหน่งใหม่ ดังนี้:

**ช่วงที่ 1 — แทนที่บรรทัด 56-85** (module state + `addEntityToEnrichmentContext_`):
```js
// [MOVED → 10f_MatchAliasEnrichment.gs] _ALIAS_ENRICHMENT_CONTEXT +
//   addEntityToEnrichmentContext_() — ย้ายไปรวมกับกลุ่มฟังก์ชัน alias-enrichment
//   ยังเรียกใช้ตัวแปร/ฟังก์ชันนี้ข้ามไฟล์ได้ปกติ (shared global scope)
```

**ช่วงที่ 2 — แทนที่บรรทัด 492-1134** (`autoEnrichAliasesFromFactBatch_` ถึง
`matchCommitPlaceAlias_`, 11 ฟังก์ชัน):
```js
// [MOVED → 10f_MatchAliasEnrichment.gs] autoEnrichAliasesFromFactBatch_() และกลุ่ม
//   ฟังก์ชัน alias-writing ทั้งหมด (Single Writer M_ALIAS) — ย้ายไปไฟล์แยกตาม
//   Refactor Plan A เพื่อลดขนาดไฟล์หลัก ดู 10f_MatchAliasEnrichment.gs
```

**วิธี apply ที่ปลอดภัยสุด:** เปิด `10_MatchEngine.gs` ใน Apps Script editor →
เลือกทั้ง 2 ช่วง (ใช้เนื้อหาด้านบนเป็นตัวช่วยค้นหาจุดเริ่ม/จบ เช่น ค้นหาข้อความ
`function addEntityToEnrichmentContext_` เพื่อหาจุดเริ่มช่วง 1 และ `function
processOneRow` เพื่อหาจุดสิ้นสุดช่วง 2) → ลบ → วางคอมเมนต์แทน → เพิ่มไฟล์ใหม่
`10f_MatchAliasEnrichment.gs` เข้าโปรเจกต์ → save → **รัน `29_SnapshotTest.gs`
เทียบ baseline ก่อน/หลังทันที** (นี่คือจุดที่เหมาะกับ regression test เพราะเป็นการ
ย้ายไฟล์ล้วนๆ ไม่มี logic เปลี่ยน ถ้า snapshot ต่างกันแปลว่ามีบางอย่างหลุดระหว่างย้าย)

---

## ผลลัพธ์ขนาดไฟล์ (ต้องบอกตรงๆ — ยังไม่ถึงเป้า 800 บรรทัด)

| | บรรทัด |
|---|---|
| `10_MatchEngine.gs` เดิม | 2,276 |
| หักลบ 2 ช่วงที่ย้าย (30 + 643 บรรทัด) | -673 |
| `10_MatchEngine.gs` หลัง apply (โดยประมาณ, รวมคอมเมนต์แทนที่) | **~1,610** |
| เป้าหมายที่ตั้งไว้ | < 800 |

**การย้ายรอบนี้ยังไปไม่ถึงเป้า < 800 บรรทัด** — กลุ่ม alias-writing เป็นก้อนที่คุณระบุ
มาชัดเจนและ extract ได้สะอาดที่สุด (self-contained, ผลกระทบ cross-file ต่ำ) แต่ไฟล์
หลักยังมีอีก 2 กลุ่มใหญ่ที่เหลืออยู่ ถ้าอยากไปถึงเป้าจริงต้องทำต่อเป็น **Phase 2**
(ยังไม่ได้ทำในรอบนี้ เพราะคุณระบุ scope Plan A ไว้แค่กลุ่ม alias-writing):

- กลุ่ม decision/scoring (`makeMatchDecision`, `calcDynamicWeights_`,
  `calculateWeightedScore`, `matchCalcFullScore_`, `matchCalcGeoAnchorScore_`,
  `breakTieAmongCandidates`) — ~370 บรรทัด — หมายเหตุ: header comment เดิมของไฟล์
  บอกว่า "decision rules แยกไป 10b แล้ว" แต่ตรวจโค้ดจริงพบว่ากลุ่มนี้ยังอยู่ใน
  `10_MatchEngine.gs` — comment เดิมอาจไม่ตรงกับสถานะจริง (คล้ายปัญหาที่เจอกับ
  embedded analysis doc ก่อนหน้านี้) ควรตรวจ `10b_MatchDecision.gs` เทียบก่อนว่า
  ทับซ้อนกันหรือไม่ ก่อนย้ายกลุ่มนี้
- กลุ่ม row-processing/decision-execution (`processOneRow`, `executeDecision`,
  `handleAutoMatch_`, `handleCreateNew_`, `handleReview_`) — ~540 บรรทัด — ผูกกับ
  orchestration ค่อนข้างแน่น ต้องดูให้ละเอียดกว่านี้ก่อนตัดสินใจว่าแยกได้สะอาดแค่ไหน

ถ้าต้องการ ผมไปตรวจ `10b_MatchDecision.gs` ให้ละเอียดต่อ (แก้ปมเรื่อง comment เดิม
ไม่ตรงกับโค้ดจริง) แล้วเสนอ Phase 2 extraction plan ที่แม่นยำกว่านี้ได้เป็นขั้นถัดไป
