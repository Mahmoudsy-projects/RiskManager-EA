# CHANGELOG v93 — DIAGNOSTIC build (BUG-059). Base v92. No behavior change. Not compiled in the sandbox.

v92 log showed: mouse events cost ~0.01 ms (innocent); every OnTick costs ~30-40 ms on average, with repeated ~1000 ms stalls; chart-change rebuild 50-1000 ms.
v93 adds a per-section breakdown inside OnTick:
- `RM_PfBegin()` at the start and `RM_PfMark("<function>")` after each of the 32 top-level calls of OnTick (sections >= 2 ms are recorded).
- When a whole tick takes >= 30 ms, one line (max 2/sec):
  `[RM-PERF] TICK BREAKDOWN total=..ms | CheckClosedTrades=..ms UpdateReportsDisplay=..ms ...`
- The 10-second `[RM-PERF]` summary and SLOW lines from v92 remain.
Main file: RiskManager_EA_v93.mq4, #property version 93.00. Hub unchanged. Temporary — remove after the cause is found.
