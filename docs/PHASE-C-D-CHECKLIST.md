<!-- DOC-TYPE: living -->

# 📋 Phase C+D Checklist — LMDS V6.0 Improvement Roadmap

> เอกสารนี้ track ความคืบหน้าของ Phase C (โค้ด) + Phase D (กระบวนการ)
> สร้าง: 2026-07-16 | อัปเดตล่าสุด: ดูที่ git blame

---

## Phase C — แก้ไขโค้ด (Code Fixes)

### C-1: Quick Code Wins (1 วัน) — ✅ เสร็จ (V6.0.057)

| #     | งาน                                                                                 | ที่มา                       | ความยาก | สถานะ   | PR   |
| ----- | ----------------------------------------------------------------------------------- | --------------------------- | ------- | ------- | ---- |
| C-1.1 | Google Maps URL helper — `getGoogleMapsUrl()` in ViewHelpers.html (5 spots deduped) | Reviewer 4 Tip #2           | 30 นาที | ✅ Done | #TBD |
| C-1.2 | `runNormalize()` UI label fix — menu + log message ชัดเจนขึ้น                       | Reviewer 2 (adjusted)       | 15 นาที | ✅ Done | #TBD |
| C-1.3 | ESLint `max-lines-per-function` 300 → 200                                           | Reviewer 2 TD-05 (adjusted) | 1 ชม.   | ✅ Done | #TBD |
| C-1.4 | Telegram retry wrapper — exponential backoff (2s/4s/8s, 3 retries)                  | Reviewer 4 TD-004           | 1 ชม.   | ✅ Done | #TBD |

### C-2: Feature (2-3 วัน) — ✅ เสร็จ (V6.0.058)

| #     | งาน                                        | ที่มา                                     | ความยาก | สถานะ   | PR   |
| ----- | ------------------------------------------ | ----------------------------------------- | ------- | ------- | ---- |
| C-2.1 | 5-Layer Alias Safeguard (Layer 1 + 5 only) | Reviewer 1 (adjusted — ทำ 2/5 layer ก่อน) | 1 วัน   | ✅ Done | #TBD |

### C-3: Process Improvements (ทำควบคู่กัน) — ✅ เสร็จ (V6.0.059)

| #     | งาน                                                       | สถานะ   | PR   |
| ----- | --------------------------------------------------------- | ------- | ---- |
| C-3.1 | สร้าง `docs/TODO.md` track ทุกข้อเสนอ                     | ✅ Done | #TBD |
| C-3.2 | สร้าง `docs/CI-CD-TROUBLESHOOTING.md`                     | ✅ Done | #TBD |
| C-3.3 | เพิ่ม PR template บังคับเลือกประเภท (refactor vs feature) | ✅ Done | #TBD |
| C-3.4 | เพิ่ม CI check: verify PR title vs actual diff            | ✅ Done | #TBD |

---

## Phase D — แก้ไข Logic กระบวนการตรวจสอบ (Methodology Fixes)

### D-1: สร้าง CI checks ใหม่ (8 ตัว) — 🔜 รอ

| #     | Script                                | ตรวจอะไร                                                  | ผลลัพธ์       | สถานะ   | PR  |
| ----- | ------------------------------------- | --------------------------------------------------------- | ------------- | ------- | --- |
| D-1.1 | `check_10_dead_functions.sh`          | function ที่ไม่มี caller                                  | warning       | 🔜 รอทำ | —   |
| D-1.2 | `check_11_wrapper_usage.sh`           | wrapper function ต้องถูกใช้ทุกที่                         | error (block) | 🔜 รอทำ | —   |
| D-1.3 | `check_12_path_consistency.sh`        | CREATE_NEW/AUTO_MATCH/MERGE ต้องทำ side effects เหมือนกัน | warning       | 🔜 รอทำ | —   |
| D-1.4 | `check_13_no_runtime_cdn.sh`          | ห้าม `@tailwindcss/browser` หรือ CDN runtime              | warning       | 🔜 รอทำ | —   |
| D-1.5 | `check_14_external_api_resilience.sh` | `UrlFetchApp.fetch` ต้องอยู่ใน try-catch                  | warning       | 🔜 รอทำ | —   |
| D-1.6 | `check_15_string_duplication.sh`      | string literal ซ้ำกัน > 2 ครั้ง                           | warning       | 🔜 รอทำ | —   |
| D-1.7 | `check_16_api_call_count.sh`          | นับ `getSheetByName` / `getValue` / `setValue`            | warning       | 🔜 รอทำ | —   |
| D-1.8 | `check_17_production_readiness.sh`    | `appsscript.json` access + executeAs                      | warning       | 🔜 รอทำ | —   |

### D-2: AI Review Verification Protocol — 🔜 รอ

| #     | งาน                                              | สถานะ   | PR  |
| ----- | ------------------------------------------------ | ------- | --- |
| D-2.1 | สร้าง `docs/AI-REVIEW-PROTOCOL.md` (5 กฎ verify) | 🔜 รอทำ | —   |

### D-3: ปรับ PR Template — 🔜 รอ

| #     | งาน                                                             | สถานะ   | PR  |
| ----- | --------------------------------------------------------------- | ------- | --- |
| D-3.1 | เพิ่ม Pre-Merge Checklist ใน `.github/pull_request_template.md` | 🔜 รอทำ | —   |

### D-4: Self-Audit Script — 🔜 รอ

| #     | งาน                                                 | สถานะ   | PR  |
| ----- | --------------------------------------------------- | ------- | --- |
| D-4.1 | สร้าง `scripts/self_audit.sh` รันทุก checks ก่อน PR | 🔜 รอทำ | —   |

---

## สรุปความคืบหน้า

| Phase             | ทั้งหมด | เสร็จ | กำลังทำ | รอ     |
| ----------------- | ------- | ----- | ------- | ------ |
| C-1 (Quick Wins)  | 4       | 0     | 4       | —      |
| C-2 (Feature)     | 1       | 0     | 0       | 1      |
| C-3 (Process)     | 4       | 0     | 0       | 4      |
| D-1 (CI checks)   | 8       | 0     | 0       | 8      |
| D-2 (Protocol)    | 1       | 0     | 0       | 1      |
| D-3 (PR template) | 1       | 0     | 0       | 1      |
| D-4 (Self-audit)  | 1       | 0     | 0       | 1      |
| **รวม**           | **20**  | **0** | **4**   | **16** |

---

## ประวัติการอัปเดต

| วันที่     | งาน                         | สถานะ   |
| ---------- | --------------------------- | ------- |
| 2026-07-16 | สร้าง checklist (Phase C+D) | ✅ Done |
