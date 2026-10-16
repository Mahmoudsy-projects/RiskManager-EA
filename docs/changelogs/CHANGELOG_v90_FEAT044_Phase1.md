# CHANGELOG v90 — FEAT-044 Phase 1: Scale-in (Continuation Entry), Mode 1

Base: EA v89 / Hub v1.16 (Hub unchanged). MT5 untouched. MagicNumber untouched.
NOTE: not compiled in the sandbox (no MetaEditor) — compile before use.

## Behavior
- New row `Scale-in: OFF/ON` above MARKET/PENDING (grey off/unavailable, purple ON, one-shot).
- 0 eligible chains -> status says why; 1 -> auto-selected; 2+ -> picker window (Tag-window style).
- Lot = Mode 1 cap / SL distance. Full/Half button ignored while ON. Cap = max(0, root.RiskUSD - signed live open risk of chain).
- Opposite direction -> rejected, stays ON. After execute/Cancel -> OFF. Not persisted on restart.
- Re-validated at EXECUTE; lot below min lot -> refused with message.
- Exempt (continuation only): Entry Interval strike, EarlyExit Behavior strike, g_lastEntryTime not updated.
- Still enforced: MaxTotalRisk, MaxDailyRisk, Cooldown locks, Weekly/Monthly DD, Floating DD.
- RiskWeight = continuationRiskUSD / (balance x RiskPerTrade%), clamped (0,1] (existing RiskStepWeight field reused).

## Files / functions
- RM_Snapshot: g_snapIsContinuation[], g_snapRiskBaseUSD[] (persisted), SnapRiskBase(), IsContinuationTicket(), DetachSnapshotRoot(); SaveTradeSnapshot +2 trailing params.
- RM_RiskCalc: GetChainLiveOpenRiskUSD, ChainHasPendingOrder, ScaleInCapUSD, ScaleInChainIsBuy, BuildScaleInCandidates, GetEntryRiskPct. GetTotalOpenRisk unchanged.
- RM_TradeExecution: ScaleIn flow helpers, ProcessClick checks, AutoExecute (cap, root, exemptions), HalfCloseTicket carries flags.
- RM_CooldownEngine: RunEntryIntervalCheck(exempt), CheckPendingActivation, HandleVanishedContinuationPending, CheckPrematureAction, EarlyExit branch, ProcessChainMarketStop (root Snapshot base, deferral GV RM_CHAINDEFER_<root>).
- RM_Reports: chain R base via SnapRiskBase(root).
- RM_Dashboard: SCALEIN_H, button row, UpdateScaleInButton.
- RM_Tools: History_Build uses root entry explicitly; picker window (SCL_WIN_PREFIX).
- RiskManager_EA_v90.mq4: globals, events, CalcNetResultR via RiskBaseUSD, timer/tick refresh.

## Open points
1. CalcNetResultRB left unchanged (RB = tradeR x weight already carries the weight; dividing by root base would double-weight). One-line switch if you prefer the literal spec.
2. Mode 1 ignores realized losses of closed parts (per spec).
3. A pending's risk can exceed the cap if the target SL is loosened before fill.
4. Pending tracking is memory-only (FEAT-005): after restart a vanished pending is not evaluated.
5. A chain with an outstanding pending continuation is ineligible (prevents double-funding the cap).

## v90.1 (Mahmoud's decision on point 5)
- When all open parts of a chain are closed (TP, SL or any close), unfilled Scale-in pendings of that chain are auto-cancelled (`CancelOrphanContinuationPendings`, run in OnTick/OnTimer). Normal pendings untouched. The chain Market Cooldown is then evaluated immediately (no waiting).
- CalcNetResultRB stays unchanged (confirmed correct: already weighted).
