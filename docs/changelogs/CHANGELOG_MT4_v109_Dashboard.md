# MT4 v109 — Trade Dashboard (no DLL)
- New: RM_DashboardExport.mqh + RM_DashboardHtml.mqh (HTML embedded as Base64).
- OnInit: creates MQL4\Files\RM_Dashboard.html if missing/old; Experts log prints its path ([RM-DASH]).
- After each CSV export: writes MQL4\Files\RM_Dashboard_Data.js (same data).
- Open RM_Dashboard.html in Chrome (double-click / bookmark). Button "به‌روزرسانی" reloads data.
- No DLL, no program launch; only writes inside MQL4\Files.
- Edited: RM_Reports.mqh (1 line), RiskManager_EA_v109.mq4 (version, include, OnInit call).
- NOT COMPILED. Delete old RiskManager_EA_v108.mq4 / .ex4.
