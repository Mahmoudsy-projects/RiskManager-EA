# RiskManager Workstation — v81 Changelog

**Base:** v80 (BUG-056 + FEAT-031)
**EA version:** RiskManager_EA_v81.mq4, `#property version "81.00"`
**Hub version:** unchanged, v1.14 (not touched by this release)

---

## FEAT-037 — 5-Option Context Checklist (before Tag Trade)

A new, fully independent step inserted into the existing Tag Trade flow, **before** Strategy/Setup/Mental State. Built as its own module — no code shared with or copied from the existing Tag Trade logic (per the task's explicit instruction, since that module recently had structural bugs).

**New Tag Trade step order:**
1. Select Trade (unchanged)
2. **Context Checklist (new)**
3. Select Strategy (was step 2, renumbered — logic untouched)
4. Select Setup + Mental State (was step 3, renumbered — logic untouched)

**The 5 checkboxes (flat, independent, 0–5 selectable):**
- Key Level
- Cycle Clarity
- Key Time
- Candle Confirmation
- No Checklist Confirmation (catch-all)

**Storage — fully independent files, parallel to the existing Strategy/Setup pattern but not sharing any code or file with it:**
- `RM_ContextChecklist.txt` — editable label text for the 5 options (`KEY: label` format). Same seed/migration pattern as `RM_StrategySetups.txt`: created with defaults on first run; if an older/missing version is detected, the existing file is backed up to `RM_ContextChecklist_backup.txt` once and replaced with the current default — after that, manual edits are never touched.
- `RM_ContextTags.csv` — `Ticket,ContextLevelOK,ContextCycleClarityOK,ContextTimeOK,ContextCandleConfirmOK,ContextNone` (1/0 per field). Independent of `RM_TradeTags.csv`.

**CSV journal export:** 5 new trailing columns added to `RM_TradeJournal_<Magic>.csv` (`ExportTradeJournalCSV()`, RM_Reports.mqh) — `ContextLevelOK, ContextCycleClarityOK, ContextTimeOK, ContextCandleConfirmOK, ContextNone` — `"true"`/`"false"`, defaulting to `"false"` for trades where the checklist was skipped/never reached.

**Behavior:**
- Each checkbox toggle persists immediately (`SetContextTag()`), so closing the window before pressing "NEXT >>" never loses a selection.
- Default state for all 5 fields is `false` — a trade that never entered/completed this step has all fields false/empty in the CSV.
- Selecting a trade already tagged pre-loads its saved checklist state for the highlight (same pattern as the existing Mental State pre-load).
- Works identically across all strategies (BTB, SP2L, and the rest) — context is independent of setup type.
- `ContextScore` / breakdown reporting in Performance was explicitly out of scope for this dispatch (deferred, per task).

**Files touched:** `RM_Tools.mqh` (new module + Tag Trade step renumbering), `RiskManager_EA_v81.mq4` (OnInit seed/load calls + OnChartEvent click handling), `RM_Reports.mqh` (CSV columns).

---

## FEAT-033 — KEY TIME: box display → global vertical lines

The old KEY TIME behavior (3 bottom-anchored session boxes — Tokyo/London/NewYork) is **completely removed** and replaced with **14 full-height vertical dashed lines**. No toggle, no second display mode — this one behavior only. Internal module name unchanged (`SW` / "Session Windows"); only what it draws changed. The dashboard button, its ON/OFF persistence (GlobalVariable), and the KEY TIME caption are untouched.

**Display style:**
- All 14 lines: dashed (`STYLE_DASH`).
- Color: automatic, computed from live `CHART_COLOR_BACKGROUND` luminance, blended toward black/white depending on chart theme — deliberately low-contrast/hard-to-see.
- Main lines (8): more visible — stronger color blend + width 2.
- Sub lines (6): very thin — weaker color blend + width 1.
- An hour label is drawn under each line, always in **broker time** (converted live from the internally-stored New York time on every rebuild, via the shared `RM_SessionTime.mqh` — so a future NY DST change updates the labels automatically with no new dispatch needed).

**Internal storage — New York time (14 lines total), exactly per the task table:**

| Main (8) | NY time | Sub (6) | NY time |
|---|---|---|---|
| M1 | 17:00 (prev. NY day) | S1 | 00:00 |
| M2 | 20:00 (prev. NY day) | S2 | 01:00 |
| M3 | 21:00 (prev. NY day) | S3 | 06:00 |
| M4 | 02:00 | S4 | 08:30 |
| M5 | 03:00 | S5 | 14:00 |
| M6 | 09:30 | S6 | 16:00 |
| M7 | 11:00 | | |
| M8 | 13:00 | | |

The 3 "previous NY day" main lines are computed by passing `daysAgo+1` into the shared `ST_ComputeSessionByDaysAgo()` (one calendar day further back than the rest of that day's set) — no separate date logic.

**History:** unchanged from v80 — still rebuilt for "today" plus `SW_HISTORY_DAYS` (30) days back on toggle-on/OnInit/day-reset, same as before (now producing 14 lines × ~32 days instead of 3 boxes × ~32 days).

**Files touched:** `RM_Tools.mqh` only (`BuildOneSessionBox` → `BuildOneKeyTimeLine`, `BuildSessionWindows`, `UpdateSessionWindowsVertical`, new `KeyTime_GetLine()` / `GetKeyTimeLineColor()` helpers). No other tool (SOB, Session Level, etc.) touched.

---

## Verification performed

- Python brace/bracket/parenthesis balance check on every touched file (`RiskManager_EA_v81.mq4`, `RM_Tools.mqh`, `RM_Reports.mqh`) — clean, matching the pre-existing baseline of each file (RM_Tools.mqh carries a pre-existing −5 parenthesis count from Persian-comment style, confirmed identical to v80 before any edits).
- `diff -rq` against the original v80 package: **every file except `RiskManager_EA_v81.mq4` (renamed from v80), `RM_Tools.mqh`, and `RM_Reports.mqh` is byte-identical** — including the entire Executive Hub folder, `RM_SessionTime.mqh`, and all other RM_*.mqh modules.
- `diff -u` reviewed line-by-line against v80 for all three changed files.

## Not yet done (pending Mahmoud's compile/live test on MT4)

- Actual MetaEditor compile pass (not available in this environment).
- On-chart confirmation of KEY TIME line color contrast, broker-time label correctness, and step-4 Tag Trade flow on a live/demo chart.
