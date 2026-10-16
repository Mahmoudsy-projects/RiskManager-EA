# RiskManager Workstation — EA v86 Changelog (FEAT-042 Phase 1)

**Base:** EA v85 + Hub v1.15 (Hub untouched, byte-identical).
**EA:** `RiskManager_EA_v86.mq4`, `#property version "86.00"`.
**Changed:** `RM_Snapshot.mqh`, `RM_TradeExecution.mqh`, `RM_Tools.mqh`, `RM_Reports.mqh`, main `.mq4` (header + version). All other modules byte-identical to v85.
**Scope rule kept:** no report / cooldown number changes. Win Rate, PF, Avg R:R, Expectancy, Trade Count, Performance (R / RB / %), Market & Behavior Cooldown, `CalcNetResultR/RB`, `CheckClosedTrades` are not touched.

## Task 1 — `RootTicket` in the Snapshot (`RM_Snapshot.mqh`)
- New array `g_snapRootTicket[]`, GlobalVariable `A<account>_M<magic>_RM_SNAP_ROOT_<ticket>`.
- `SaveTradeSnapshot(...)`: new last parameter `int initRootTicket=0` (0 → root = the ticket itself). Existing call sites compile unchanged.
- `LoadTradeSnapshots`: key missing (snapshot saved before v86) or invalid → root = the ticket itself, no error.
- New `GetRootTicket(ticket)`: root from the Snapshot; no Snapshot / no root → the ticket itself. Single interpreter used by tags and the CSV.

## Task 2 — Root assignment
- `AutoExecute`: root = own ticket (passed explicitly). Pending orders keep their ticket on activation, so the root stays the same.
- `HalfCloseTicket`: remainder's root = `GetRootTicket(old ticket)` (not the old ticket). Repeated Half Closes keep the FIRST ticket as root.
- **Not-found log (was silent):** after the diff search, if no remainder ticket is found → `Print`:
  - partial close but no remainder: `RM WARNING: ... remainder ticket NOT FOUND ... ticket / symbol / closedLots / lotsBefore / time`;
  - whole position closed (Half Close of a position at minimum lot closes all of it): informational `Print`, no warning.
- **Cross-check added (non-blocking):** if the chosen remainder's `OpenTime` or entry price differ from the original, a `RM WARNING ... chain link may be wrong` is printed. It does not skip the candidate, so v85 behaviour is unchanged (the real XChief data shows remainders always keep OpenTime and Entry). Making it blocking is a possible phase-2 decision.

## Task 3 — Context checklist now follows the chain
Fixed by reading from the root (Task 4). Additionally, if the remainder could NOT be linked (the old ticket had no Snapshot, so root = the remainder itself), the context checklist is copied directly as a fallback.

## Task 4 — Tags read/write from the root (`RM_Tools.mqh`)
- `FindTagIndex` / `FindCtxTagIndex`: map to the root first; if the root has no tag but the ticket itself has a legacy one (copies made by the old Half Close code), that is read. Exact (non-mapping) lookups kept as `FindTagIndexExact` / `FindCtxTagIndexExact`.
- `SetTradeTag` / `SetContextTag`: always write on the root → one edit applies to the whole chain, including tags set AFTER the Half Close. Old child entries stay in the files untouched and are shadowed by the root's.
- All dependants work through those two functions: CSV (Strategy / Setup / MentalState / 5 context columns), open-position label, Tag Trade window and its row colours, `BuildTodayTicketList` (still lists every ticket as its own row).
- `CountUntaggedToday`: a chain is counted once (tagged if the root or any member is tagged). **Side effect:** the untagged counter on the Tag Trade button can be lower than in v85 for open/today's chains — display only.

## Task 5 — CSV column
`RootTicket` appended as the LAST column (47th, after `RiskStepWeight`); no column moved; still one row per ticket. Tickets without a Snapshot or with a pre-v86 Snapshot show their own ticket number. Header and row both have 47 fields (checked).

## Task 6 — Are Snapshots ever deleted?
- **In the EA code: no.** No Snapshot, root or tag is ever removed; the only `GlobalVariableDel` in the project is the unrelated `GV_AUTOCLOSE_DAY`. Arrays only grow; they are reloaded from GlobalVariables at `OnInit`.
- **Platform caveat for phase 2 (not verified on your terminal):** MT4 itself deletes a GlobalVariable that has not been accessed for about 4 weeks. `LoadTradeSnapshots` reads every key at each EA start, which refreshes them; a chain's snapshot keys could expire only if the EA/terminal runs more than ~4 weeks without a restart. If that happened, an old chain would lose its root link and appear as separate tickets. Phase 2 should either re-read periodically or not depend only on GlobalVariables for closed chains.

## Verification
- Brace / parenthesis / bracket balance 0 on all 14 EA files; CSV header and row both 47 columns.
- Python port of the logic: chain of 4 via 3 Half Closes → all root = first ticket; tag set after Half Close visible on all parts; edit made from a child writes ONE root entry; legacy child tag still read; ticket without Snapshot → root = itself, no error; unlinked remainder gets the context checklist copied; untagged count counts a 3-part chain once.
- **Not compiled in MetaEditor and not run on MT4.** Suggested live test: one manual Half Close and one repeated Half Close, check `RootTicket` in the CSV, tags in the Tag Trade window, then restart the EA in the middle of a chain; watch the Experts log for the new warnings.
