# CHANGELOG v92 — DIAGNOSTIC build (BUG-059 lag investigation). Base v91.

NOTE: not compiled in the sandbox. No trading/behavior change. Temporary — to be removed once the cause is found.

- OnTick / OnTimer / OnChartEvent were renamed to RM_OnTickImpl / RM_OnTimerImpl / RM_OnChartEventImpl (bodies untouched);
  thin wrappers with the original names measure execution time with GetMicrosecondCount().
- Every 10 s (only if there was activity) one line is written to the Experts log:
  `[RM-PERF] 10s busy=X% | tick n=.. avg=..ms max=..ms | timer ... | mouse ... | chartchg ... | click ... | other ...`
  busy = share of wall time the EA spent running in those handlers.
- A single call slower than 30 ms also prints `[RM-PERF] SLOW <name> call: N ms` (at most twice per second).
- Main file: RiskManager_EA_v92.mq4, #property version 92.00. Hub unchanged.
