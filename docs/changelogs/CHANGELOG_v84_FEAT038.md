# RiskManager Workstation — v84 Changelog

**Base:** v83 (small batch)
**EA version:** RiskManager_EA_v84.mq4, `#property version "84.00"`
**Hub version:** unchanged, v1.14 (not touched)
**Source:** Task dispatch "FEAT-038 — multi-step Risk button (Full→1/2→1/4→1/8) + fixed grey for R/R & Measure Move"
**Files changed:** `RiskManager_EA_v84.mq4` (renamed from v83), `RM_RiskCalc.mqh`, `RM_TradeExecution.mqh`, `RM_Dashboard.mqh`, `RM_Tools.mqh`, `RM_Snapshot.mqh`, `RM_CooldownEngine.mqh`, `RM_Reports.mqh`. All other modules byte-identical to v83. MagicNumber untouched.

---

## Task 1 — Architecture check (reported before any code change)

**Question:** do `CalcLot()` and the `TradeR` calculation read "current risk %" from one shared variable?

**Answer: not literally one variable — but the condition the task cares about is met, so work proceeded.**

- **Lot side.** `CalcLot(slPips, riskPct)` receives the risk % as an argument. Before v84 that argument came from the ternary `g_halfRiskActive ? g_effRiskPerTrade/2.0 : g_effRiskPerTrade`, **duplicated in 3 places** (live hover preview in the `.mq4`, final SL/TP labels and `AutoExecute()` in `RM_TradeExecution.mqh`).
- **TradeR side.** `TradeR` never reads a risk-% variable. Both the journal export (`RM_Reports.mqh`) and the performance/R functions divide the closed trade's net P/L by the **per-ticket Snapshot `RiskUSD`**, which `AutoExecute()` writes at order time from the real order (`SL distance × pip value × OrderLots()`). So TradeR is relative to the actual dollar risk taken for that exact trade — not a fixed number — and adding risk steps needs **no change** to TradeR / Daily-Weekly-Monthly R / Drawdown %.
- **Caveat found → resolved by the Addendum below:** three consumers used the *boolean* `WasHalfRisk` Snapshot flag (RB weight, Market Cooldown increment, CSV). The flag could only say yes/no, so 1/4 and 1/8 would have been weighted 0.5.
- **Also found:** the old Half Risk toggle was **never persisted** (`g_halfRiskActive` always started `false`). Persistence is therefore new in v84, not an extension.

## Task 2 — 4-step Risk button

- Cycle: **Full → 1/2 → 1/4 → 1/8 → Full**, one step per click (same cycling pattern as the RR button). Fixed fractions of `RiskPerTrade` (after the existing 3% ceiling). No OBJ_EDIT, no free input.
- New single source of truth `g_riskStep` (0–3) + `GetActiveRiskPct()` in `RM_RiskCalc.mqh`. All three former ternaries now call it. `CalcLot()` and base sizing are unchanged.
- Button text: `Full Risk: 0.25%`, `1/2 Risk: 0.125%`, `1/4 Risk: 0.063%`, `1/8 Risk: 0.031%` (display only: max 3 decimals, trailing zeros trimmed, min. 2 decimals — actual risk/lot use full precision; font auto-fits via the existing `FitBtnFontHalf`). Two new muted-red steps continue the existing colour ladder (`RISK_BG_Q4/Q8`, `RISK_BORDER_Q4/Q8`).
- Status bar: `<step> Risk selected`; order confirmation tag `[1/2 Risk]` / `[1/4 Risk]` / `[1/8 Risk]` (was `[Half Risk]`).
- Persistence: GlobalVariable `RM_RiskStep_A<account>_M<magic>_<symbol>`, written on every click, loaded in `OnInit` before `BuildPanel()`. Out-of-range values fall back to Full.
- `CalcLot()` still floors to LotStep and blocks below MinLot, so at 1/4 and 1/8 the executed lot is the floored value (or blocked) — TradeR stays correct because it uses the Snapshot's real risk.

## Task 3 — Fixed grey for R/R and Measure Move

- `GetFiboRRColor()` and `GetFiboMeasureColor()` now both return `GetFiboToolGrayColor()`: a neutral grey chosen from chart-background luminance (same light/dark detection idea as `GetKeyTimeLineColor()`): dark bg → light grey (150–225), light bg → dark grey (30–130), guaranteed ≥ ~97/255 luminance distance, including on mid-grey backgrounds. Buy/sell and candle colours no longer matter.
- The cursor tag / status text for these tools use the same functions, so they match the lines.
- `SessionLevel_BuildWindows()` used `GetFiboMeasureColor()` for its boxes; to keep **Session Level colours unchanged**, the previous logic moved verbatim into `GetSessionLevelBoxColor()`.
- Already-placed R/R or Measure Move objects keep their old colour until redrawn.

## Addendum — exact risk-step weight (replaces the yes/no WasHalfRisk weighting)

- **New Snapshot field `RiskWeight`** (`RM_Snapshot.mqh`): `g_snapRiskWeight[]` + GlobalVariable `RM_SNAP_RISKWEIGHT_<ticket>`. Written **at entry** by `AutoExecute()` as `1 / RiskStepDivisor(g_riskStep)` (the step active at `OrderSend`, same source as `GetActiveRiskPct()`), so later button clicks cannot change an open trade's weight. Values: Full 1.0 / 1/2 0.5 / 1/4 0.25 / 1/8 0.125. Pending orders get it at placement (the step is the one that sized the order). The Half Close remainder ticket inherits it from the original.
- **Single interpreter `SnapRiskWeight(idx)`**: returns the stored weight if present (> 0); otherwise falls back to the old rule (`WasHalfRisk` true → 0.5, false → 1.0). Snapshots saved before v84 have no such key (load sets -1) so they behave exactly as in v83.
- **`WasHalfRisk` kept** (now "any reduced step", step > 0) — nothing was removed, so no regression risk for older data/readers.
- **Three consumers updated:**
  1. **RB** — `CalcNetResultRB()` (`.mq4`): factor = `SnapRiskWeight(idx)` instead of fixed 0.5.
  2. **Market Cooldown** — `CheckClosedTrades()` (`RM_CooldownEngine.mqh`): stop increment = `SnapRiskWeight(snapIdx)`. No Snapshot → still 1.0, as before.
  3. **CSV** — new last column **`RiskStepWeight`** (3 decimals, `N/A` without Snapshot) in `RM_Reports.mqh`. *Chosen over replacing `WasHalfRisk`* because appending at the end leaves every existing column position and name intact (same convention as FEAT-036); the CSV is rewritten in full on each export so old and new rows always share one header. Legacy rows show 1.000 / 0.500 derived from the old flag.
- **Related display fix (small, not in the brief):** the Market Cooldown stop counter on the dashboard printed one decimal, so 0.25 would show as "0.3" and 0.125 as "0.1". New `FmtStopCount()` (`RM_Dashboard.mqh`) prints up to 3 decimals with trailing zeros trimmed (1.5 still shows "1.5"). Whole numbers unchanged.
- **Behavioural consequence to be aware of:** with `MarketCDCount = 3`, it takes 12 consecutive stops at 1/4 (24 at 1/8) to trigger Market Cooldown, versus 6 at 1/2. That is what the requested weights imply.
- Static simulation: Full/1/2/1/4/1/8 → RB for a -1R stop = -1 / -0.5 / -0.25 / -0.125; Market increment 1 / 0.5 / 0.25 / 0.125; CSV 1.000 / 0.500 / 0.250 / 0.125; legacy true/false → 0.5 / 1.0.

## Static verification
- Brace / parenthesis / bracket balance: 0 on all 14 `.mq4`/`.mqh` files.
- `diff -u` vs v83 reviewed; all other modules, Hub, sounds, icon, `MQL4_Files` byte-identical to v83.
- Numeric simulation of cycle, button text, lot ratio (1 : 0.5 : 0.25 : 0.125) and TradeR (−1R at SL, +2R at 2R, in all 4 steps) passed.
- **Not compiled in MetaEditor, not run on a chart** — compile and live-test on MT4 are still required.
