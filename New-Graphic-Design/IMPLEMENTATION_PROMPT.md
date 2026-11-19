# دستور اجرا (برای Claude Code)

این متن را در یک جلسه Claude Code روی ریپو RiskManager-EA کپی کنید.

---

You are implementing the approved dashboard redesign for the Risk Manager EA (MT4).

**Read first:** `New-Graphic-Design/README.md` (decisions, palette) and the HTML mockups in `New-Graphic-Design/mockups/` (V3 dashboard, V4 Hub, V5 sub-tabs, V6 Tag Trades, V7 collapsed, V8 alerts; each in light-chart and dark-chart variants). The mockups are the source of truth for colors, sizes and layout.

**Hard rules**
- Native MT4 objects only (OBJ_BUTTON, OBJ_RECTANGLE_LABEL, OBJ_LABEL, OBJ_EDIT). NO bitmaps / ResourceCreate / DLL.
- Do not touch trading logic, risk calculation, cooldown/drawdown engines or any behavior. This is a visual change only.
- Work on a new branch `feature/new-graphic-design`; do not modify the archived/released EA v109 and Hub v1.22 files. Create the new versions as separate files (EA v110, Hub v1.23) following the repo's archive/versioning convention.
- No per-tick cost increase: static decoration objects (bevel underlays) are created once at build/rebuild only.

**Plan (do in phases, stop after each phase and report so the user can test on a demo chart)**
1. **Color table refactor:** replace the ~100 hardcoded color literals in `RM_Dashboard.mqh` with named variables/constants (one theme table; only the new theme D "Mono Gray" is needed now, but structure it so another theme can be added later). Keep the current look identical after this phase (pure refactor). Keep it independent from the Hub theme feature.
2. **Layout:** new 3-tab single panel (Trading · Utility · Reports), width 220px, all text centered. Remove Performance and Reports from the main dashboard and move them to the Reports tab. Notification box 34px high with 2 lines (use L_STATUS + L_STATUS2; shrink font via FitBoxFont for long texts). Cooldown block (MKT CD / BEH CD) prominent as in the mockup.
3. **Theme D look:** apply the palette in README; raised-button look with 1px light top/left + dark bottom/right borders plus static underlay rectangle; teal (#0E7C86) for selected/active buttons; Market/Pending/Risk/RR lighter as in mockup; semantic muted colors only for Close / Half Close buttons; only cooldown/drawdown notices in red; "1 trade untagged" small red line; KEY TIME teal = full, KEY TIME C blue = compact.
4. **Sub-tabs:** Close menu (ALL/CHART/WINNERS/LOSERS), Half Close All / Profitable Only, Tag Trades flow (steps 1/4–4/4 + Mental State panel, shortened titles so text never overflows), disabled-button style (flat gray) for locked entry buttons, collapsed bar (300px).
5. **Hub (indicator):** apply theme D to the Hub bar and its four tabs (Ind / Label / Draw / Theme). Keep semantic colors of Draw and Theme buttons.
6. **MT5 port:** after MT4 is approved, port the same look to the MT5 version (no separate design needed).

**Deliverables for each phase:** compile without errors/warnings, a short Persian summary of what changed (the user is a trader, not a programmer), and screenshots instructions for testing on a demo chart (light and dark chart backgrounds). Update the changelog and README checklist in `New-Graphic-Design/`.
