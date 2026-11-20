# RiskManager Workstation

A risk-management and trade-discipline toolkit for MetaTrader. It is **not** a trading strategy and generates no buy/sell signals; the trader makes every trade decision.

| Component | Platform | Version | Folder |
|---|---|---|---|
| RiskManager EA | MT4 | v110 | `MT4/RiskManager_EA/` |
| Strategy list data | MT4 | v107 | `MT4/MQL4_Files/` |
| Executive Hub (indicator) | MT4 | v1.23 | `Hub/` |
| RiskManager EA | MT5 | v75.17 | `MT5/RiskManager_EA_MT5/` |
| Executive Hub (indicator) | MT5 | v1.17 | `MT5/ExecutiveHub_MT5/` |

## Status
2026-11-19: MT4 EA **v110**, MT4 Hub **1.23**, MT5 EA **v75.17** and MT5 Hub **1.17** were compiled and tested by Mahmoud (confirmed by the author; see `New-Graphic-Design/CHANGELOG.md`).

## Install (MT4)
1. Copy the contents of `MT4/RiskManager_EA/` to `MQL4/Experts/RiskManager_EA/` and compile `RiskManager_EA_v111.mq4` in MetaEditor.
2. Copy `Hub/` to `MQL4/Indicators/` and compile `ExecutiveHub_v1.23.mq4`.
3. Copy `MT4/MQL4_Files/RM_StrategySetups.txt` to `MQL4/Files/` (the EA migrates an older list once and keeps a backup).

## Install (MT5, hedging account)
1. Copy `MT5/RiskManager_EA_MT5/` (all files, incl. `Sounds/`) to `MQL5/Experts/RiskManager_EA_MT5/` and compile `RM_RiskManager_Main.mq5` in MetaEditor.
2. Copy `MT5/ExecutiveHub_MT5/` to `MQL5/Indicators/ExecutiveHub_MT5/` and compile `RM_Hub_Main.mq5`.
3. Strategy list, context checklist and journal files are created automatically in `MQL5/Files/`.
4. Note: v75.15 renamed 22 shared inputs with an `In_` prefix, so old `.set` files must be re-saved.

## Docs
- `docs/changelogs/` — one changelog per version (Persian).
- `docs/guide/` — Persian user guides. MT4: `..._MT4_v110_Hub1.23.pdf` (Mono Gray; guide not yet updated for v111); MT5: `..._MT5_v75.17_Hub1.17.pdf` (latest). Older PDFs are kept for history.
- `docs/reports/` — delivery reports.

## Tags
`mt4-v107`, `hub-v1.20`, `mt4-v108`, `hub-v1.21`, `hub-v1.22`, `mt4-v109`, `mt5-v75.16`, `mt5-v75.15`, `hub-mt5-v1.16`, `mt4-v110`, `hub-v1.23`, `mt5-v75.17`, `hub-mt5-v1.17` (tags are created via GitHub Releases)

Personal data (trade journals/CSV, logs, account numbers, personal `.set` files) must never be committed; see `.gitignore`.

## Trade dashboard (MT4 v109 / MT5 v75.16, no DLL)
The EA writes `RM_Dashboard.html` and `RM_Dashboard_Data.js` into `MQL4\Files` / `MQL5\Files` (data refreshed on every CSV export). Open the HTML in Chrome (double-click or bookmark). A reference copy of the page is in `Dashboard/`. No DLL imports are needed.
