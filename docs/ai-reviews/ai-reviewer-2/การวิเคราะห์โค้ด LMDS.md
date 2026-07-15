<!-- DOC-TYPE: historical -->
## วิเคราะห์ [LMDS V6.0](https://github.com/Siriwat08/phaopanya-scg) แบบตอบตรงคำถาม

สรุปสั้นก่อนเลย: ระบบนี้ **แนวคิดหลักถูกทาง** ถ้าเป้าหมายคือ “เอาข้อมูลส่งของดิบ → จับคู่ Person/Place/Geo → เก็บผลลง master + fact + review queue” แต่ถ้าเป้าหมายของคุณคือ “มีชั้น clean data ที่ชัดเจน ตรวจสอบ before/after ได้ง่าย และเอาไปใช้ต่อได้แบบ data engineering” ตอนนี้ระบบยัง **ไม่ครบในมุมนั้น** เพราะการทำความสะอาดถูกฝังอยู่ใน flow ของ matching มากกว่าจะเป็น output ชั้นกลางที่แยกชัดเจน [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/00_App.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/05_NormalizeService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/10_MatchEngine.gs)

อีกประเด็นที่สำคัญมากคือ `runNormalize()` ในโค้ดปัจจุบัน **ไม่ได้เป็น batch cleaning stage จริง** แต่เป็น placeholder; การ normalize จริงเกิดตอน `processOneRow()` ผ่าน `resolvePerson()` และ `resolvePlace()` ขณะ Match Engine วิ่ง ดังนั้นถ้าคุณคาดหวังว่า “Step 2 Normalize” จะสร้างชุดข้อมูล cleaned output แยกออกมา คำตอบคือ **ยังไม่ใช่** [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/05_NormalizeService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/00_App.gs)

---

## แผนที่การไหลของข้อมูล: ทำความสะอาดแล้วผลไปอยู่ตรงไหน

| ขั้น | สิ่งที่เกิดขึ้นจริง | ผลลัพธ์ไปอยู่ที่ไหน | ผมมองว่าโอเคไหม |
|---|---|---|---|
| 1. รับข้อมูลดิบ | Source rows ถูกสร้างจากชีตต้นทาง, กรองเฉพาะแถวที่มี invoice และยังไม่ `SUCCESS/REVIEW` | `SOURCE` | โอเค เป็น staging ต้นทาง |
| 2. ทำความสะอาดชื่อ/สถานที่ | `normalizePersonNameFull()` / `normalizePlaceName()` คืน `normResult` ในหน่วยความจำ | **ยังไม่มี clean table แยก** | นี่คือจุดที่ยังไม่โปร่งใส |
| 3. ตัดสินใจ match | `processOneRow()` เรียก person/place/geo resolver แล้วตัดสินใจ Rule-based | ผลไปต่อที่ `FACT_DELIVERY` หรือ `Q_REVIEW` | ถูกกับ use case แบบ operational |
| 4. สร้าง master ใหม่ | ถ้าไม่พบ จะสร้าง `M_PERSON` / `M_PLACE` | `M_PERSON`, `M_PLACE` | ดี แต่ควรมี audit ของ cleaned payload |
| 5. สร้างประวัติธุรกรรม | insert/update fact row พร้อม match status/confidence/IDs | `FACT_DELIVERY` | ถูกต้องสำหรับ transaction sink |
| 6. กรณีกำกวม | เก็บ candidate และรอคนตัดสิน | `Q_REVIEW` | ดีมากสำหรับ human-in-the-loop |
| 7. เรียนรู้ alias | สร้าง canonical/variant alias จาก fact หลังบันทึกสำเร็จ | `M_ALIAS`, `M_PERSON_ALIAS`, `M_PLACE_ALIAS` | ดี เป็น self-learning layer |
| 8. ปิดสถานะต้นทาง | แถวใน `SOURCE` ถูก mark `SUCCESS` / `REVIEW` / `ERROR` | `SOURCE.SYNC_STATUS` | ดี ใช้งานจริงได้ |

ข้อมูลด้านบนตรงกับโค้ดใน `04_SourceRepository.gs`, `10_MatchEngine.gs`, `11_TransactionService.gs`, และ schema กลางใน `02_Schema.gs` [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/2_group2_daily_ops/04_SourceRepository.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/10_MatchEngine.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/2_group2_daily_ops/11_TransactionService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/02_Schema.gs)

---

## คำตอบตรงๆ: “ผลลัพธ์นำไปใส่ตรงไหน”

ถ้ามองตาม business output จริง ผลจากการ clean + match ถูกกระจายไป 5 จุดหลัก คือ `M_PERSON`, `M_PLACE`, `FACT_DELIVERY`, `Q_REVIEW`, และ alias tables ไม่ได้ถูกรวมเป็น “cleaned dataset กลาง” ก้อนเดียว [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/02_Schema.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/06_PersonService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/07_PlaceService.gs)

ถ้าถามเฉพาะ “cleaned person name ไปอยู่ไหน” คำตอบคือไปอยู่ใน `M_PERSON.canonical_name` และ `M_PERSON.normalized_name`; ส่วนเบอร์โทร, notes, phonetic key, branch number ก็ถูกเก็บใน row เดียวกันตอน `createPerson()` [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/06_PersonService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/02_Schema.gs)

ถ้าถามเฉพาะ “cleaned place/address ไปอยู่ไหน” คำตอบคือไปอยู่ใน `M_PLACE` โดยเก็บทั้ง canonical, normalized, geo fields และ reverse-geocode columns แยกอีกชุดหนึ่ง แต่ไม่ได้มีตาราง `STG_CLEANED_PLACE` หรือ clean audit table สำหรับตรวจ before/after โดยตรง [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/07_PlaceService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/02_Schema.gs)

ถ้าถามว่า “ผลลัพธ์สุดท้ายของ pipeline ไปอยู่ไหน” คำตอบคือ `FACT_DELIVERY` เพราะตารางนี้เก็บ source reference, raw source fields, resolved person/place/geo/destination IDs, confidence, reason, action, resolved lat/lng และ evidence ซึ่งเป็น transaction sink หลักของระบบ [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/2_group2_daily_ops/11_TransactionService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/02_Schema.gs)

---

## “ถูกต้องมั้ย?” — ผมตอบแบบแยก 2 มุม

### 1) ถ้าหมายถึง “ถูก architecture สำหรับงาน matching logistics ไหม”
**ค่อนข้างถูก** ครับ เพราะ flow นี้มี source → normalize → resolve → decision → persist → review → alias learning ครบวงจร และมี human review queue รองรับเคสกำกวมด้วย [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/README.md) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/10_MatchEngine.gs)

### 2) ถ้าหมายถึง “ผล clean data ถูกเก็บในที่ที่เหมาะที่สุดไหม”
**ยังไม่สุด** ครับ เพราะ clean result ไม่ได้ถูก materialize เป็นชั้นข้อมูลกลางที่ตรวจสอบง่าย แต่ถูกฝังเป็นผลข้างเคียงของ matching และ create master มากกว่า ทำให้ตรวจ regression, compare ก่อน/หลัง, หรือ reuse ในงาน analytics/ML ยากกว่าที่ควร [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/05_NormalizeService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/00_App.gs)

---

## “ผลลัพธ์ที่ได้มาใช่ที่ต้องการจริงไหม?”

ถ้า requirement จริงของคุณคือ “ต้องการระบบ operational ที่เอาข้อมูลขนส่งดิบไปผูกกับ master ให้ได้ และส่ง ambiguous case ไปคิว review” ผมว่าใช่ค่อนข้างมาก เพราะ schema และ write path รองรับชัดเจน [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/02_Schema.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/10_MatchEngine.gs)

แต่ถ้า requirement จริงของคุณคือ “อยากได้ data cleaning pipeline ที่พิสูจน์ได้ว่า cleaned output ถูกต้อง” ตอนนี้ยังตอบไม่เต็มปากว่าใช่ เพราะ repo มี dry-run และ snapshot harness อยู่แล้วก็จริง แต่ยังไม่เห็นชุด gold dataset / labeled benchmark / precision-recall ที่ใช้ตัดสินเชิงคุณภาพอย่างเป็นระบบ [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/10d_MatchTestHarness.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/29_SnapshotTest.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/package.json)

พูดอีกแบบ: ตอนนี้ระบบมี “เครื่องมือทดสอบการเปลี่ยนแปลง” แต่ยังไม่เห็น “หลักฐานความถูกต้องตาม business truth” แบบชัดเจน ถ้าจะตอบให้มั่นใจจริง ต้องมี sample ที่มนุษย์เฉลยไว้ แล้ววัดอย่างน้อย 4 ค่า คือ auto-match precision, review rate, false positive ข้ามจังหวัด/ข้ามสาขา, และ create-new precision

---

## จุดที่ผมเห็นว่าควรปรับปรุงทันที

### 1) ทำ `runNormalize()` ให้เป็นของจริง หรือไม่ก็ลบภาพลวงตานี้ออก
ตอนนี้ UI / pipeline บอกว่ามี Step 2 Normalize แต่ในเชิง implementation มันไม่ได้สร้างผลลัพธ์ใหม่ เป็นแค่ log placeholder ทำให้คนดูระบบเข้าใจว่ามี clean stage แยก ทั้งที่จริงไม่มี [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/00_App.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/05_NormalizeService.gs)

### 2) เพิ่มชั้น `STG_CLEANED` หรือ `CLEAN_AUDIT`
นี่คือข้อเสนอที่สำคัญที่สุดของผม ถ้าคุณอยากตรวจว่าการ clean ถูกไหม ควรมีตาราง/ชีตกลางที่เก็บ `source_row`, `raw_person`, `clean_person`, `raw_place`, `clean_place`, `phone_extracted`, `doc_extracted`, `structured_notes`, `normalize_version`, `matched_action` เพื่อ compare ก่อน/หลังได้ตรงๆ แทนการไปไล่ดูหลายตาราง

### 3) ทำ naming ให้ตรงความจริงของข้อมูล
ใน `buildSourceObj_()` มี mapping ที่ต้องอ่านคอมเมนต์ถึงจะเข้าใจ เช่น `rawPlaceName` ถูกใส่จาก `RAW_ADDRESS (18)` ส่วน `rawAddress` กลับเป็น `RESOLVED_ADDR (24)` ซึ่ง technically อาจตั้งใจ แต่ชื่อแปรทำให้คนดูโค้ดเข้าใจผิดง่ายมาก [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/2_group2_daily_ops/04_SourceRepository.gs)

### 4) ทำ normalized field ให้ consistent
ฝั่ง `M_PERSON.normalized_name` ใช้ `normalizeForCompare(cleanName)` แต่ฝั่ง `M_PLACE.normalized_name` ตอน create ใช้ `cleanPlace` ตรงๆ เลย ชื่อคอลัมน์เลยสื่อความหมายไม่เท่ากัน แม้ downstream จะยัง call `normalizeForCompare()` ซ้ำได้ก็ตาม จุดนี้ไม่ใช่ bug ร้ายแรง แต่เป็น debt ที่จะทำให้คน maintain สับสน [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/06_PersonService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/07_PlaceService.gs)

### 5) ทำ semantic notes ให้ persist ครบทุกทางเดิน
ผมเห็นว่า structured notes ถูก extract ใน normalize layer แล้ว แต่การเขียนลง `SYS_NOTES` ถูกผูกไว้กับ `resolveAndPersist` path ใน `10e_MatchResolvePersist.gs` มากกว่าทางเดินหลักทั้งหมด ถ้าอยากใช้ notes เป็น feature จริง ควรทำให้ auto-match/create-new ปกติเก็บเหมือนกันทุกเคส [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/05_NormalizeService.gs) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/1_group1_master_db/10e_MatchResolvePersist.gs)

### 6) แก้ version drift
README บอก `6.0.044` แต่ package/config ใน repo ที่ผมเปิดดูเป็น `6.0.046` ซึ่งสะท้อนว่าข้อมูล version กระจายหลายที่และเริ่มไม่ sync กันแล้ว จุดนี้เล็กแต่มีผลกับ audit/debug มาก [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/README.md) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/package.json) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/src/O_core_system/01_Config.gs)

---

## ระบบนี้ “ใหญ่เกินไปมั้ย?”

คำตอบตรงๆ คือ **ใหญ่สำหรับ Google Apps Script แล้ว** แต่ **ยังไม่ถึงขั้นต้องรีบย้ายทันที** ถ้าปริมาณงานยังอยู่ในระดับทีมปฏิบัติการและคนใช้ยังผูกกับ Google Sheets เป็นหลัก

จากที่ผมวัดใน zip ที่คุณแนบ โค้ด `.gs` รวมประมาณ **27,213 บรรทัด**; ไฟล์หนักสุดคือ `10_MatchEngine.gs` ประมาณ **2,276 บรรทัด**, `21_AliasService.gs` ประมาณ **1,771**, `00_App.gs` ประมาณ **1,699**, `24_PipelineManager.gs` ประมาณ **1,470**, และ `05_NormalizeService.gs` ประมาณ **1,415** ซึ่งถือว่าใหญ่มากสำหรับโปรเจกต์ Apps Script ที่ต้องดูแลระยะยาว

ภาพรวมจึงเป็นแบบนี้: ถ้าระบบนี้ใช้กับปริมาณงานไม่สูงมาก, ผู้ใช้หลักคือ admin/reviewer ไม่กี่คน, และการทำงานยังยอมรับข้อจำกัดของ quota/time guard/lock/cache ได้ ก็ **ยังอยู่ต่อบน Apps Script ได้** แต่ถ้าคุณเริ่มต้องการ multi-user จริง, response time สม่ำเสมอ, observability ดี, deploy pipeline จริงจัง, และทดสอบเชิงคุณภาพแบบ CI/CD ผมมองว่าควรเริ่ม **ย้าย core engine ออก** [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/README.md) [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/appsscript.json)

อีกสัญญาณหนึ่งคือใน manifest ตอนนี้ web app ถูกตั้ง `access: MYSELF` และ `executeAs: USER_DEPLOYING` ดังนั้นถ้าเจตนาคือทำ dashboard/review ให้หลายคนใช้แบบ production-ready จริง repo นี้ในสถานะปัจจุบันยังไม่ใช่ปลายทางสุดท้ายอยู่แล้ว [Source](https://raw.githubusercontent.com/Siriwat08/phaopanya-scg/main/appsscript.json)

---

## ถ้าจะย้าย ควรย้าย “อะไร” ก่อน

ผม **ไม่แนะนำ rewrite ทั้งหมดทีเดียว** แต่แนะนำย้ายแบบ hybrid เป็น 3 ชั้น

| ชั้น | ควรอยู่ที่ไหน | เหตุผล |
|---|---|---|
| UI รีวิว / Ops | Google Sheets + WebApp เดิม | ทีมใช้งานคุ้นมือ |
| Core normalize + match + scoring | Cloud Run / FastAPI / Node service | หลุดจาก quota/time limit และเทสง่ายขึ้น |
| Master/Fact storage | PostgreSQL / Cloud SQL | query, audit, versioning, constraint ดีกว่า Sheets |

ถ้าจะเริ่มย้ายจริง ผมจะย้าย **MatchEngine + NormalizeService + Alias learning** ออกก่อน เพราะ 3 ส่วนนี้คือสมองของระบบและเป็นส่วนที่รับผลจาก technical debt มากที่สุด ส่วน Google Sheets ค่อยคงไว้เป็น review console ชั่วคราว

---

## คำตัดสินของผม

ถ้าถามผมแบบเจ้าของระบบ ผมจะสรุปว่า:

**ระบบนี้ไม่ผิดทิศ**  
แต่ตอนนี้มันเป็น **matching system ที่มี cleaning logic ฝังอยู่ข้างใน**  
ยังไม่ใช่ **clean-data platform ที่ตรวจสอบผลลัพธ์ได้ชัดเจน**

ดังนั้นคำตอบต่อคำถามคุณคือ:

- ผล clean data ตอนนี้ **ไม่ได้ลงที่เดียว** แต่กระจายไป `M_PERSON`, `M_PLACE`, `FACT_DELIVERY`, `Q_REVIEW`, alias tables
- ในเชิง operational ถือว่า **ค่อนข้างถูก**
- ในเชิง data engineering / auditability ถือว่า **ยังไม่สุด**
- ระบบ **ใหญ่แล้วสำหรับ Apps Script** แต่ยังไม่จำเป็นต้องย้ายทั้งหมดทันที
- ทางที่ดีที่สุดคือ **ทำ staging clean layer + test benchmark ก่อน** แล้วค่อยแยก core engine ออกเป็น service

ถ้าคุณต้องการ ผมทำต่อให้ได้ 2 แบบ:

1. ผมสรุปเป็น **ตาราง mapping ระดับไฟล์ → หน้าที่ → input/output → จุดเสี่ยง** ให้ทั้ง repo  
2. ผมทำ **refactor plan แบบเป็นเฟส** ว่าอะไรควร “แก้ในที่เดิม”, อะไรควร “แยกเป็น service”, และอะไร “ยังคงอยู่ใน Google Sheets” ได้

ถ้าต้องการ ผมเริ่มจากแบบที่ 1 ได้เลยครับ