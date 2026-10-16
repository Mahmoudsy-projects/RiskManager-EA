# RiskManager Workstation — EA v85 + Hub v1.15 Changelog

**Base:** EA v84 + Hub v1.14
**EA:** `RiskManager_EA_v85.mq4`, `#property version "85.00"` — changed: `RM_Config.mqh`, `RM_Dashboard.mqh`, `RM_Tools.mqh`, main `.mq4`. All other EA modules byte-identical to v84. MagicNumber and trading/risk logic untouched.
**Hub:** `ExecutiveHub_v1.15.mq4`, `#property version "1.15"`. `RM_SessionTime.mqh` (Hub copy) byte-identical.
**Source:** task batch "History (EA) + editable Hub labels + continuing Weekly Map + two new Draw tools". The task message listed "Task 4" twice with the same content; it was implemented once.

---

## Task 1 — HISTORY button (EA, Utility panel)
- The full-width **BE REF LINE** button is now half width (left, behaviour unchanged, font auto-fits). The right half is the new **HISTORY** toggle (teal = on, grey = off; same convention as SESSION / KEY TIME; state persisted per symbol in GlobalVariable `RM_HistOn_<symbol>`).
- On: for every closed BUY/SELL of this symbol + MagicNumber whose CloseTime is within the last **`HistoryDaysBack`** days (new input, default **7**) two filled `OBJ_RECTANGLE`s are drawn (same technique as Session Level, `BACK=true`, not selectable): **light** = entry → TP, **dark** = entry → SL. Horizontal extent is exactly **OpenTime → CloseTime** of that ticket. Objects are prefixed `RM9HIST_` and removed on off / deinit.
- Data comes from the same sources as the journal CSV (MT4 history + Snapshot): Entry = `OrderOpenPrice`, TP = `OrderTakeProfit` (= `TP_Final`). **SL choice (needs your OK):** the dark box uses the Snapshot's *original* SL (planned risk); only if a ticket has no Snapshot does it fall back to `OrderStopLoss` (= `SL_Final`). Reason: after Break Even / Trailing `SL_Final` sits on or beyond entry, which would give a zero-height or inverted risk box. Switching to pure `SL_Final` is a one-line change in `History_Build()`.
- A box is skipped when its level is 0 or equal to entry (e.g. TP removed).
- Colours: from chart-background luminance (same detection idea as `GetFiboToolGrayColor()` / `GetKeyTimeLineColor()`), no hard-coded colour. Dark bg → both boxes lighter than bg (light ≈150–225, dark ≈55–180). Light bg → both darker than bg. Light/dark boxes always ≥ 45/255 apart, each ≥ 45 from the background.
- Refresh: rebuilt on toggle, on EA start / timeframe change, at the daily rollover (window moves), and whenever `OrdersHistoryTotal()` changes (a trade just closed).
- Not touched: BE REF LINE logic, the existing Entry/Exit Markers tool.

## Task 2 — Editable Hub labels (Hub)
- Label texts are read from **`RM_HubLabels.txt`** (MQL4/Files), one line per slot: `L01: LEG 1` … `L18: BTB`. `#` lines are comments; a missing slot gets its built-in default; **an empty text (`L05:`) hides that button**. Same seed / migration / backup pattern as `RM_ContextChecklist.txt`: file missing → seeded with defaults; file present but GlobalVariable `RM_HubLabelsVer` older than 115 → copied to `RM_HubLabels_backup.txt`, replaced by defaults once. Edits apply the next time the Hub starts.
- Slot count fixed at **18**. Two new default labels **SP2L** and **BTB** (slots 17–18).
- **Layout:** slots 1–16 stay in the 2-row grid exactly as before. Slots 17–18 sit in the empty area under the three master buttons (the same area the RANGE button uses on the Draw tab), so the panel does **not** get wider. Grid width math (`ComputeContentWidth`) deliberately counts only the 16 grid slots. If your eye finds the y-alignment of the two extra buttons off by a few pixels versus the grid's second row, tell me — I could only compute it, not see it.
- **Long names — decision: auto font-fit + 20-char cap** (not auto-width). Font 7 up to 11 chars (what GOLDEN ZONE needed), then shrinks proportionally to a floor of 5; texts over 20 chars are truncated at load. Button width is unchanged.
- Button object names are now index-based (`LblBtn_0..17`) instead of text-based, so duplicate / empty / odd-character labels cannot collide.
- **Dependency check:** the label text is used only for the button caption, the "armed" comparison and the text of the placed chart label. No other Hub logic keys off any of the 16 names. (`NY-EDGE` as a *label* is unrelated to the NY Edge *indicator* button.)
- Known limit: an empty slot leaves a gap in the grid (buttons are not re-packed).

## Task 3 — Weekly Map keeps extending (Hub)
- Base unchanged: step = (WH − WL) / 4; levels WH, WL, 25/50/75 %, WH+25 %, WL−25 %.
- New: whenever price passes the highest (or lowest) drawn level, one more step of the same size is added, repeatedly (WH+50 %, WH+75 %, … / WL−50 %, …), so a line is always ahead of price. Reference price = week's running high/low (wicks included) and Bid, so extra levels stay once drawn even if price pulls back. Redrawn automatically on the tick the count changes; resets when the week rolls.
- Extra levels use the extension colour and respect the existing `WMAP_ShowExtensions` / `WMAP_ShowLabels` inputs. Safety cap: 40 extra steps per side.
- Static check: price crossing a drawn level always produces the next one (e.g. step 10: price 2010 → level 2020 appears; 2020 → 2030).

## Task 4 — Two Draw tools (Hub)
- **Horizontal Line**: one click → a horizontal line from the clicked point to the right edge of the chart (an `OBJ_TREND` with right-ray, not a two-sided `OBJ_HLINE`, not a finite segment). Uses the Line colour/width, solid.
- **Dash Line**: identical interaction to **Line** (two clicks, live preview, Shift-snap), thin dashed style (`STYLE_DASH`, width 1 — MT4 only renders dashes at width 1). Colour = Line colour.
- Both are new buttons in the Draw grid (8 → 10 items, 4 → 5 columns; Draw stays narrower than Label/Indicator grids). The existing **Line** tool is untouched.
- **Defaults (revision after your feedback):** each new tool has its **own** remembered default (colour / width / style), saved when you edit an object on the chart — same behaviour as Line and Path (GlobalVariables `…HRayColor/Width/Style`, `…DashColor/Width/Style`). First run starts from the current Line colour; Dash starts as `STYLE_DASH`, width 1. Their defaults are separate from Line's on purpose: sharing would mean changing a Dash Line to red also turns every new solid Line red (and vice-versa). Objects are named `HRay_…` / `Dash_…` (no "Line_"), so editing them never touches Line's or the rectangles' defaults. The tool button colour and the Dash live preview follow the tool's own colour.
- Note: a Dash Line whose width you raise above 1 loses its dashes in MT4 (platform rule); the default you save will then be that thicker width.

## Static verification
- Brace / parenthesis / bracket balance 0 on all 14 EA files and the Hub.
- Python ports of the new logic checked: Weekly Map step counts (price always behind the top/bottom level), label-file parsing (comments, empty slot hides, bad slot ignored, 20-char cap), font-fit table, History colour contrast on 7 background shades.
- **Not compiled in MetaEditor and not run on a chart.** Please compile both (delete the old `.ex4` first) and eyeball: label slots 17–18 placement, button text fit, History boxes, Horizontal/Dash tools.
