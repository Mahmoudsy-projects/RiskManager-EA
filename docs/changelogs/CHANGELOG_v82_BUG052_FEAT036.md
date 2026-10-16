# RiskManager Workstation — v82 Changelog

**Base:** v81 (FEAT-037 + FEAT-033)
**EA version:** RiskManager_EA_v82.mq4, `#property version "82.00"`
**Hub version:** unchanged, v1.14 (not touched by this release)
**Source:** Task dispatch BUG-052 + FEAT-036 (handoff from the Fable line — execution audit)

---

## Scope note (file-location correction)

The task brief named `RM_TradeExecution.mqh` / `CheckClosedTrades()` as the target. As of the
Architecture Refactor (R6), `CheckClosedTrades()` actually lives in **`RM_CooldownEngine.mqh`**
— `RM_TradeExecution.mqh` only still mentions it in comments. The diff below is scoped to where
the function actually is, plus the CSV/report file — no other module touched, same intent as the
brief's acceptance criterion.

**Files touched:** `RM_CooldownEngine.mqh`, `RM_Reports.mqh`. Nothing else in the diff.

---

## BUG-052 — Directional SL/TP classification fix

**Root cause:** `CheckClosedTrades()`'s `hitSL` test was non-directional — `|ClosePrice − SL| ≤
tol`. A stop that filled *beyond* its level (worse, with slippage) was just as likely to fail
that test as a manual exit in the *opposite* direction (better than the level, a real early
exit) — both produce a large `|diff|`. The result: legitimate stops with real slippage were
misclassified as `EarlyExit`, which (a) wrote the wrong `Result` to the trade journal and (b)
incorrectly added a Behavior strike toward Behavior Cooldown for a trade that was actually a
correctly-taken stop.

**Audit finding (account A4160750, Feb–Aug 2026, 273 trades):** 84% of stops (109/130) filled
beyond their level with slippage — $2,978 (≈7.88R) in real cost over 6 months, and an unknown
share of that mistakenly counted toward Behavior Cooldown.

**Fix — directional, in both places that classify a close:**
- `CheckClosedTrades()` (`RM_CooldownEngine.mqh`) — the live classification that drives Market/
  Behavior Cooldown. Fixed in **both** the Snapshot-based path and the no-Snapshot legacy
  fallback path (pre-v11 tickets).
- `ExportTradeJournalCSV()` (`RM_Reports.mqh`) — its read-only `Result` mirror, kept in sync with
  the same rule per the file's own stated contract.

```
Long:  ClosePrice ≤ SL + tol   → SL   |   ClosePrice ≥ TP − tol   → TP
Short: ClosePrice ≥ SL − tol   → SL   |   ClosePrice ≤ TP + tol   → TP
```

i.e. "at or beyond the level" = hit; only a fill in the *opposite* direction (better than the
designed level) is excluded. The 10% tolerance itself, the Initial-Risk-based `oneR`/`origDist`
basis, and everything downstream (Market/Behavior Cooldown counters, `reached1R`, `EarlyExit`
branch, `IsHalfExempt`) is **unchanged** — only the direction of the boundary test changed.

**Out of scope, confirmed untouched:** trade sizing, AutoBE, order execution, past-trade
reclassification (no backfill — a closed trade's `Result` in history isn't retroactively
recomputed; only trades closed from v82 onward get the corrected classification).

---

## FEAT-036 — 8 new CSV journal columns

All appended at the end of `RM_TradeJournal_<Magic>.csv` — existing column order/content
untouched (same convention as every prior CSV extension: v61/v64/v66/v69/FEAT-037).

| Column | Content | Notes |
|---|---|---|
| `SL_Final` | Last recorded SL before close | `OrderStopLoss()` from history — already reflects the latest value after any AutoBE/Trailing/manual edit, no new tracking needed |
| `TP_Final` | Last recorded TP before close | `OrderTakeProfit()` from history; `"N/A"` if no TP was set |
| `Slippage_USD` | Signed $ diff between ClosePrice and whichever level (SL or TP) actually decided `Result` | Positive = worse than that level. `"N/A"` for `EarlyExit`/`N/A` results or trades without a valid Snapshot |
| `Slippage_R` | `Slippage_USD` ÷ the trade's designed Initial Risk ($) | Same `"N/A"` conditions as above |
| `CloseReason_Server` | Dealer comment tag on the order: `[sl]` / `[tp]` / empty | Read from `OrderComment()`; empty (not `"N/A"`) for manual closes, per spec |
| `Spread_AtClose` | Live `Ask−Bid` spread | **Captured at the exact moment `CheckClosedTrades()` detects the close** (same "closest the EA can get" philosophy as `TakeExitScreenshot()`), persisted via `GlobalVariable` (same pattern as `WasEmergencyClosed`) since MT4's order history has no spread field and CSV export can happen long after — even after a restart. `"N/A"` for trades closed before v82 was installed |
| `ServerHour_Close` | Server-time hour (0–23) of `CloseTime` | Derived directly from `OrderCloseTime()`, no new tracking |
| `IsEAManaged` | `"true"`/`"false"` — does this ticket have a valid Trade Snapshot | The existing clean/dirty-data boundary already used everywhere else in this file (`snapIdx>=0`), just exposed as its own column |

**Out of scope, confirmed untouched:** no backfill of slippage on trades closed before v82 (per
the brief — the manual audit already covered that); no change to sizing/AutoBE/trading logic —
registration only.

---

## Testing

**Stage 1 (technical, pre-dispatch)** — verified by code-level trace against all 6 required
scenarios (long/short × SL/TP + manual close); see the test summary returned alongside this
package. Could not run an actual MT4 strategy tester pass in this environment — Mahmoud's own
compile + a few days of live/demo trading is Stage 2, per the task's own two-stage plan.

**Stage 2 (practical, next week, real market)** — per task: a few days of normal trading, then
confirm in the CSV that slipped stops now read `Result=SL` (not `EarlyExit`) and that Behavior
Cooldown does not climb during the week for slipped-but-correct stops.
