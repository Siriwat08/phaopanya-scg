# CHECKS — รายการ check ทั้งหมด (flat index)

> **ไฟล์นี้ generate มาจาก `EXTENDING.md#active-checks`** — ห้ามแก้ที่นี่
> แก้ที่ EXTENDING.md แล้วรัน `bash 05-runner/regen-index.sh` (ถ้ามี)

| ID | Agent | Severity | Name | Target |
|---|---|---|---|---|
| ST-001 | static | P1 | GS file header present | src/**/*.gs |
| ST-002 | static | P2 | Load order prefix 00-29 | src/**/*.gs |
| ST-003 | static | P1 | ESLint 0 errors | src/**/*.{gs,js,html} |
| ST-004 | static | P3 | Prettier formatting | src/**/*.{gs,js,html,css} |
| ST-005 | static | P2 | No var keyword (Law 1) | src/**/*.gs |
| ST-006 | static | P1 | No magic column index (Law 3) | src/**/*.gs |
| ST-007 | static | P1 | Function name unique (Law 8) | src/**/*.gs |
| ST-008 | static | P2 | Function ≤ 100 lines (Law 2) | src/**/*.gs |
| ST-009 | static | P1 | No cross-file globals (Law 9) | src/**/*.gs |
| ST-010 | static | P1 | HTML files separate (Law 11) | src/**/*.gs |
| ST-011 | static | P0 | No ellipsis in code (Law 15) | src/**/*.gs |
| ST-012 | static | P3 | Internal link integrity in docs | docs/**/*.md |
| RT-001 | runtime | P0 | UrlFetchApp in try-catch | src/**/*.gs |
| RT-002 | runtime | P0 | No runtime CDN | src/**/*.{html,js} |
| RT-003 | runtime | P1 | Batch operations only (Law 4) | src/**/*.gs |
| RT-004 | runtime | P0 | LockService for shared writes | src/**/*.gs |
| RT-005 | runtime | P1 | Checkpoint for long pipelines | src/**/*.gs |
| RT-006 | runtime | P0 | Cache invalidation chain | src/**/*.gs |
| RT-007 | runtime | P1 | Trigger cleanup | src/**/*.gs |
| RT-008 | runtime | P1 | Library version locked | src/**/*.gs |
| RT-009 | runtime | P1 | Time budget under 6 min | src/**/*.gs |
| RT-010 | runtime | P2 | Quota awareness | src/**/*.gs |
| RT-011 | runtime | P2 | API call count per pipeline | .github/scripts/** |
| RT-012 | runtime | P0 | Production access config | appsscript.json |
| DM-001 | domain | P0 | Match Engine 8-rule | 10b_MatchDecision.gs |
| DM-002 | domain | P0 | Single Writer Pattern | src/**/*.gs |
| DM-003 | domain | P0 | Hybrid Alias single writer | 21_AliasService.gs |
| DM-004 | domain | P0 | RBAC deny-by-default | 27_RbacService.gs |
| DM-005 | domain | P0 | Invoice normalization | src/**/*.gs |
| DM-006 | domain | P1 | Thai prefix stripping | 05_NormalizeService.gs |
| DM-007 | domain | P0 | SEC-001..012 compliance | src/** + workflows |
| DM-008 | domain | P0 | PII masking in logs | src/**/*.gs |
| DM-009 | domain | P1 | Sheet protection | src/**/*.gs |
| DM-010 | domain | P0 | Formula injection prevention | src/**/*.gs |
| DM-011 | domain | P0 | Q_REVIEW decision routing | 10b_MatchDecision.gs |
| DM-012 | domain | P0 | No data contamination | src/**/*.gs |
| DM-013 | domain | P0 | SEC-001 Hardcoded OAuth credentials | src/**/*.gs |
| DM-014 | domain | P1 | SEC-002 OAuth scope least privilege | appsscript.json |
| DM-015 | domain | P0 | SEC-003 Cookie CRLF injection | src/**/*.gs |
| DM-016 | domain | P0 | SEC-004 PII hashing + fetchWithRetry truncation | src/**/*.gs |
| DM-017 | domain | P0 | SEC-005+011 Sheet protection completeness | src/**/*.gs |
| DM-018 | domain | P0 | SEC-006 API key in URL (must use header) | src/**/*.gs |
| DM-019 | domain | P0 | SEC-009 RFC 6265 cookie regex | src/**/*.gs |
| DM-020 | domain | P0 | SEC-012 fetchWithRetry body leak | src/**/*.gs |
| DM-021 | domain | P0 | SEC-002+010 AuthZ guard + audit trail | src/**/*.gs |

**Agent 5 (Doc-Sync) — v5 NEW:**

| ID | Agent | Severity | Name | Target |
|---|---|---|---|---|
| DS-000 | doc-sync | varies | Auto-run LMDS existing doc-code-sync checks | .github/scripts/doc-code-sync-checks/*.sh (auto-discover, runs up to 18) |

**Total: 49 active checks (13 Static + 14 Runtime + 21 Domain + 1 Doc-Sync wrapper that runs 18 LMDS checks)**

**Coverage:** SEC-001..012 ครบทั้ง 12 ข้อ ✅ (DM-007, 008, 010 จาก v1 + DM-013..021 จาก v5)

---

## 🏷️ Severity definitions

| Tier | Meaning | Action |
|---|---|---|
| **P0** | Production blocker / data corruption / security hole | Must fix before deploy — no exception |
| **P1** | Law violation / potential runtime failure | Must fix before release |
| **P2** | Maintainability / style | Fix in current sprint |
| **P3** | Nice-to-have / docs | Backlog |
