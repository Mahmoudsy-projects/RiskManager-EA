# RiskManager Workstation — v83 Changelog

**Base:** v82 (BUG-052 + FEAT-036)
**EA version:** RiskManager_EA_v83.mq4, `#property version "83.00"`
**Hub version:** unchanged, v1.14 (not touched by this release)
**Source:** Task dispatch "Small Batch — Open line position fix + KEY TIME contrast increase"

Two small, fully independent fixes, both in `RM_Tools.mqh` (Utility panel). **Diff confined to
`RM_Tools.mqh` — no other file touched.**

---

## Fix 1 — Daily H/L "Open" line position (bug reported 2026-08-20)

**Diagnosis:** Compared the Open line's code path line-by-line against its siblings (PDH/PDL/
PDC). The `HLine()`/`HLineLabel()` calls, the color-contrast helper, and the label-anchoring
logic are byte-identical across all four lines — the **only** actual difference is the candle
shift used to read the price:

- PDH / PDL / PDC: `iHigh/iLow/iClose(Symbol(), PERIOD_D1, 1)` — yesterday's **completed** candle
- Open (as shipped in FEAT-032/v79): `iOpen(Symbol(), PERIOD_D1, 0)` — **today's**, still-forming candle

The tool's whole purpose is to draw a closed box around *yesterday's* range. With Open reading
from *today's* candle instead, it plotted a value with no relationship to that box — wherever
today's market happened to be — which is exactly what reads as "positioned wrong" next to three
lines that correctly bound yesterday's range.

**Fix:** shift changed from `0` to `1`, so Open now reads **Previous Day Open** — the same frame
of reference as PDH/PDL/PDC, forming a complete, coherent previous-day OHLC box. Label renamed
`"OPEN"` → `"PDO"` to match the PDH/PDL/PDC naming convention and to correctly describe what the
line now shows (yesterday's open, not today's). No other part of the Open line's code changed —
same `HLine()`/`HLineLabel()` calls, same color family, same toggle (`g_hlDailyOn`).

**Note for Mahmoud:** if what you actually wanted was *today's* open (not yesterday's) displayed
correctly, this is the opposite fix — flag it and I'll revert the shift and look for a different
cause instead.

**Out of scope, confirmed untouched:** High/Low/Close lines, Weekly H/L, Monthly H/L, the
`g_hlDailyOn` toggle itself.

---

## Fix 2 — KEY TIME line contrast increase

`GetKeyTimeLineColor()`'s `blendPct` raised so both line types sit 5 percentage points further
from the chart background than before:

| | Before | After |
|---|---|---|
| Main lines | 12 | 17 |
| Sub lines | 5 | 10 |

Everything else in the function — background-luminance light/dark detection, which direction
(toward black vs. white) the blend goes — is untouched. Lines are still meant to read as
low-contrast reference marks, not bold lines; this just nudges both a notch more visible per your
request.

**Out of scope, confirmed untouched:** KEY TIME line count/positions/labels, Daily H/L.
