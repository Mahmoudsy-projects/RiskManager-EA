# RiskManager Workstation

A risk-management and trade-discipline toolkit for MetaTrader. It is **not** a trading strategy and generates no buy/sell signals; the trader makes every trade decision.

| Component | Platform | Version | Folder |
|---|---|---|---|
| RiskManager EA | MT4 | v107 (frozen, hotfixes only) | `MT4/RiskManager_EA/` |
| Strategy list data | MT4 | v107 | `MT4/MQL4_Files/` |
| Executive Hub (indicator) | MT4 | v1.19 | `Hub/` |
| MT5 port | MT5 | v74.4 r2 + Hub 1.08 | planned (not yet archived here) |

## Install (MT4)
1. Copy the contents of `MT4/RiskManager_EA/` to `MQL4/Experts/RiskManager_EA/` and compile `RiskManager_EA_v107.mq4` in MetaEditor.
2. Copy `Hub/` to `MQL4/Indicators/` and compile `ExecutiveHub_v1.19.mq4`.
3. Copy `MT4/MQL4_Files/RM_StrategySetups.txt` to `MQL4/Files/` (the EA migrates an older list once and keeps a backup).

## Docs
- `docs/changelogs/` — one changelog per version (Persian).
- `docs/guide/` — Persian user guide (v107 file = v106 guide + v107 addendum).
- `docs/reports/` — delivery reports.

## Tags
`mt4-v107`, `hub-v1.19`

Personal data (trade journals/CSV, logs, account numbers, personal `.set` files) must never be committed; see `.gitignore`.
