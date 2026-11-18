# MT5 EA v75.15 — Shared settings (port of MT4 v101/v102/v104) — NOT COMPILED
22 account-wide inputs renamed with `In_` prefix (RM_Config.mq5): In_MaxTotalRisk, In_MaxDailyNetLossAllowed, In_EnableDailyDD, In_DailyDDLockHours, In_MaxWeeklyNetLossAllowed, In_EnableWeeklyDD, In_WeeklyDDHours, In_MaxMonthlyNetLossAllowed, In_EnableMonthlyDD, In_MonthlyDDDays, In_InpEnableFloatingDD, In_InpMaxFloatingDDPercent, In_EnableMarketCD, In_MarketCDCount, In_MarketCDHours, In_MarketCDResetHours, In_EnableBehaviorCD, In_BehaviorCDCount, In_BehaviorCDHours, In_EnableEntryInterval, In_MinEntryIntervalMinutes, In_MaxSLWidenMultiplier.
- New input `PublishSettings` (default false). ON = this chart writes its values to the shared block (GV `RM_CFG_A<account>_M<magic>_*`); OFF = chart reads the shared block.
- First chart ever creates the block; other charts read it. One GlobalVariableGet per tick detects changes from other charts (applied live + ApplyRiskCeilings).
- v104 auto-publish: changing a field in the inputs dialog (OK) publishes only the changed fields, no PublishSettings needed (previous values kept in per-chart GVs `RM_CFGPREV_<chartId>_<i>` since MQL5 re-creates globals on parameter change).
- Other inputs (RiskPerTrade, trailing, BE, etc.) stay per-chart. Old .set files: re-save (renamed inputs are ignored by old sets).
- Log lines: `[RM-CFG] shared settings loaded/created/PUBLISHED/updated/auto-published`.
Files: RM_Config.mq5, RM_MainEventHandlers.mq5 (OnInit + OnTick hooks), RM_RiskManager_Main.mq5 (version). Hub unchanged (1.16).
