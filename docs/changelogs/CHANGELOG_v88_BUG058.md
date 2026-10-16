# RiskManager Workstation — EA v88 (BUG-058) + Hub v1.16 (unchanged)

**Base:** EA v87 + Hub v1.16. **Changed:** `RM_CooldownEngine.mqh` (one `OrderSelect` line + comment) and the main `.mq4` (version/header). Everything else, including the Hub, is byte-identical to the v87 package.

## BUG-058 — closed ticket classified from the wrong order
**Symptom (2026-10-04, BTCUSD, demo):** ticket `#139377689` (Buy, SL 85030.02) was closed by the server at exactly its SL (`[sl]`, −1.00R, CSV Result = `SL`), but the Market Cooldown counter did not move. Experts log for that ticket: `[DEBUG-BEHCOUNT] Reset (+1R/TP)` instead of `Reset (SL)`. Same pattern for chain remainder `#139377682` (CSV `EarlyExit`, log `Reset (+1R/TP)`). Both closed while another position was still open. Tickets closed with nothing else open were classified correctly.

**Cause:** in `CheckClosedTrades()` the closed ticket is selected with `OrderSelect(tk, SELECT_BY_TICKET, MODE_HISTORY)`, then `TakeExitScreenshot(tk)` is called. That function calls `BuildEntryExitMarkers()`, which loops `OrderSelect` over all history rows and then over all OPEN orders and leaves the LAST one selected. The following `OrderClosePrice()`, `OrderProfit()` and `OrderTakeProfit()` therefore read the other open position. Example: a Buy's close check `closePrice >= TP - tol` evaluated against the TP of an open Sell (far below price) is always true → `hitTP` → branch "+1R/TP" → no Market stop, Behavior reset instead of Strike. Present since the exit-screenshot feature (v59); it only shows when another position is open at the close. It is not caused by half risk or by spread.

**Fix:** re-select the closed ticket right before the values are read (`OrderSelect(tk, SELECT_BY_TICKET, MODE_HISTORY)`, `continue` if it fails). No other logic changed.

**Effect:** SL/TP/EarlyExit classification, the Market stop (+weight), Behavior Strike/Reset now follow the closed ticket also when other positions are open. Past misclassifications are not corrected.

## Verification
Brace/paren/bracket balance 0 on all 14 EA files and the Hub; diff vs v87 = the one `OrderSelect` line + comments. **Not compiled, not run on a chart.** Test: open two positions, let one hit its SL while the other stays open → Experts log must show `Reset (SL)` for it and the Market counter must rise by the risk weight.
