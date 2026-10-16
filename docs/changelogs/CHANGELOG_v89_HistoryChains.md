# RiskManager Workstation — EA v89 (History per chain) + Hub v1.16 (unchanged)

**Base:** EA v88 (BUG-058 fix) + Hub v1.16. **Changed:** `RM_Tools.mqh` (`History_Build`) and the main `.mq4` (version/header). Everything else, including the Hub and the v88 fix, is byte-identical to v88.

## History button — one box set per Half Close chain
- Before: one TP box + one SL box **per ticket**; a 3-part trade drew three overlapping pairs (each ending at its own part's close).
- Now: history rows are grouped by `RootTicket`. Each chain gets ONE light box (entry → TP) and ONE dark box (entry → SL), from the mother's open time to the close time of the LAST part. Single trades (root = own ticket) are unchanged.
- TP = the TP of the last-closing part; SL = the initial SL from the root's Snapshot (falls back to the ticket's, then to `OrderStopLoss`); entry = shared entry.
- A chain that still has an open part (same rule as Trading Reports: `IsChainFullyClosed`) is not drawn yet; its box appears complete when the last part closes (the History refresh already triggers on every new closed row).
- Object names are now `RM9HIST_<root>_TP/_SL`; colours, day window (`HistoryDaysBack`) and the toggle are unchanged.

## Verification
Brace/paren/bracket balance 0. Grouping logic checked on the demo CSV (3 chains/tickets: the 3-part chain gives one pair 2026.10.04 03:21:29 → 10:58:23 instead of three). **Not compiled, not run on a chart.**
