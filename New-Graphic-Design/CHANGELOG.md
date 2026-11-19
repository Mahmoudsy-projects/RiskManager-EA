# New Graphic Design - Changelog (branch feature/new-graphic-design)
Theme D "Mono Gray" (input `DashTheme` / `HubDesign`; Classic = old dark look). Appearance only - trading/risk/cooldown/drawdown logic untouched.

- MT4 EA v110 (replaces v109 in this branch): P1 theme table (RM_Theme.mqh), P2 layout, P3 Mono look, P4 sub-tabs/Close menu/floating windows.
- MT4 Hub 1.23 (ExecutiveHub_v1.23.mq4, v1.22 kept): themed bar, raised buttons via static underlays.
- MT5 EA v75.17 (RM_Theme.mq5 added) + MT5 Hub 1.17: same look. MT5 specifics: button fonts 8pt (small sizes render pixelated), Segoe UI Bold in Hub.
- Known notes: no per-tick cost added (static underlays); Hub shadows must never have OBJPROP_TIMEFRAMES toggled (re-orders them above buttons).
