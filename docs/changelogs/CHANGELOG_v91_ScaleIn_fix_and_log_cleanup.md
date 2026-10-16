# CHANGELOG v91 (EA) — base v90 (+v90.1) / Hub v1.16 unchanged

NOTE: not compiled in the sandbox — compile in MetaEditor (delete old .ex4 first).

## v90.1 (already in v90 package update)
- Orphan Scale-in pendings auto-cancelled when the chain has no open part left (CancelOrphanContinuationPendings).

## v91
1. FEAT-044 fix — Scale-in Market lot is calculated from the real fill price (Ask/Bid at EXECUTE), not the click price.
   Real test showed risk $39.76 vs cap $37.44 because price moved between click and EXECUTE. If price is already beyond the SL -> "Scale-in: price already beyond SL - retry". Normal entries unchanged.
   File: RM_TradeExecution.mqh (AutoExecute).
2. Log cleanup (BUG-059 lead) — removed two noisy diagnostic Prints:
   - `[ST-DIAG] box` in RM_SessionTime.mqh (~81,000 lines/day; shared static flipped between windows). The Hub's byte-identical copy of RM_SessionTime.mqh is updated too (Hub version unchanged; recompiling the Hub is optional).
   - `OnTimer interval` in OnTimer (RiskManager_EA_v91.mq4, 1 line/second).
   Other low-volume diagnostics ([ST-DIAG] GV-load/calibrate/offset on change, PatternBDiag at init/save) left as is.
- Main file renamed RiskManager_EA_v91.mq4, #property version 91.00. No logic change except item 1.
