# MT5 EA v75.16 — Trade Dashboard (no DLL)
- New: RM_DashboardExport.mq5 + RM_DashboardHtml.mq5 (HTML embedded as Base64).
- OnInit: creates MQL5\Files\RM_Dashboard.html if missing/old; Experts log prints its path ([RM-DASH]).
- After each CSV export: writes MQL5\Files\RM_Dashboard_Data.js.
- Open RM_Dashboard.html in Chrome (double-click / bookmark). Button reloads data.
- No DLL, only writes inside MQL5\Files.
- Edited: RM_Reports.mq5 (1 line), RM_RiskManager_Main.mq5 (version 75.16, include), RM_MainEventHandlers.mq5 (OnInit call).
- NOT COMPILED. Install: overwrite files in MQL5\Experts\RiskManager_EA_MT5\.
