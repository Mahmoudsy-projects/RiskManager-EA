# CHANGELOG v94 — BUG-059 (lag). Base v93 (diagnostic instrumentation kept). Not compiled in the sandbox.

v93 log result: in ~every slow tick, one call blocked for ~1000 ms; in most cases it was `UpdateRiskDisplay` (its unconditional `ChartRedraw()` ran on every tick). Mouse events cost ~0.01 ms (not the cause). Occasionally the same ~1 s wait showed up in UpdateCandleTimerChart / UpdateSessionWindowsVertical (other chart-sync calls) -> the chart UI thread is busy (repaint cost of EA panel + Hub redraws).

Change (RM_Dashboard.mqh, UpdateRiskDisplay): the Open Risk label is still set every tick, but `ChartRedraw()` is called only when its text/colour changed (i.e. when a trade/SL/limit changes), not on every tick.
No other behavior change. `[RM-PERF]` instrumentation from v92/v93 stays so the effect can be measured. Version 94.00, main file RiskManager_EA_v94.mq4. Hub unchanged.
