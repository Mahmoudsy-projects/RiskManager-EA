# RiskManager Workstation — EA v87 (FEAT-042 Phase 2) + Hub v1.16

**Base:** EA v86 + Hub v1.15. Two independent code bases in one package.
**EA:** `RiskManager_EA_v87.mq4` (`#property version "87.00"`). Changed: `RM_Snapshot.mqh`, `RM_Reports.mqh`, `RM_CooldownEngine.mqh`, main `.mq4` (header, version, 2 hook lines). Byte-identical to v86: `RM_AutoActions`, `RM_Common`, `RM_Config`, `RM_Dashboard`, `RM_DrawdownEngine`, `RM_RiskCalc`, `RM_SessionTime`, `RM_Tools`, `RM_TradeExecution`, `RM_Trailing`.
**Hub:** `ExecutiveHub_v1.16.mq4` (`#property version "1.16"`). `RM_SessionTime.mqh` (Hub copy) byte-identical. No EA file touched by the Hub work.

---
# PART A — EA v87: FEAT-042 Phase 2

## A1 — Shared function `IsChainFullyClosed(root)` (`RM_Snapshot.mqh`)
False if ANY open order (market or pending) with this magic has the same root. Both A-parts below use only this function. New helper `ChainMemberCount(root)` (Snapshot entries sharing the root): 1 = single trade or a pre-v86 chain (each ticket its own root), >1 = real multi-ticket chain.

## A2 — Trading Reports by chain (`CalcTradingReportStats`, `RM_Reports.mqh`)
- Pass 1 key changed from ticket to `GetRootTicket(ticket)`; net = profit + swap + commission summed over the chain. Close time = last part.
- Chain parts closed BEFORE the period start (e.g. Half Close yesterday, remainder today) are added from History via the Snapshot members, so the chain carries its full net in the period where it ends (multi-ticket chains only).
- Chains with any open ticket of the same root (market or pending) are dropped before sorting/statistics → not in Win Rate, PF, Avg R:R, Expectancy, Trade Count or the R/$ drawdown curves until the last part closes.
- Pass 2 unchanged: chain R = net / full `RiskUSD` of the root's Snapshot = sum of the parts' TradeR. Single tickets behave exactly as in v86.
- NOT touched: `CalcNetResultR`, `CalcNetResultRB`, Performance box.

## A3 — Chain Market Cooldown (`RM_CooldownEngine.mqh`)
- Single trade (`ChainMemberCount ≤ 1`): the existing price-based `hitSL` block is unchanged (only wrapped in a guard that is true for singles).
- Part of a multi-ticket chain: the per-ticket Market increment is skipped. New `ProcessChainMarketStop(tk)` runs when a chain's last part closes: net R = chain net USD / root `RiskUSD`; if net R < −0.10R → counter += `min(1, |net R|) × RiskWeight` (weight from the Snapshot), updates `g_lastStopCloseTime`, same lock logic as before; otherwise nothing. A GlobalVariable `RM_CHAINMKT_<root>` guarantees a chain is evaluated once (two parts closing in one tick, restart).
- The Market counter does not change while a chain is open.
- Unchanged, per ticket: Behavior Cooldown, EarlyExit, the +1R Half-Close exemption, the Behavior reset on an SL-closed part, sounds.
- Edge: if a chain member is missing in History or no member has `RiskUSD`, a `RM WARNING` is printed and nothing is counted.

## A4 — GlobalVariable expiry (done, small)
`RefreshChainRootKeys()` (~15 lines, `RM_Snapshot.mqh`): rewrites the ROOT key of every child ticket and touches its root's `RiskUSD` key. Runs at `OnInit` and at the daily rollover. Missing key still falls back to root = ticket.

## A5 — Offline validation on the real CSV (key OpenTime+Direction+Entry+Symbol)
| Set | Row-based (v86) | Chain-based (v87) |
|---|---|---|
| whole file (224 rows / 199 trades) | 47.3 % | 42.7 % |
| Snapshot era, IsEAManaged (151 rows / 133 trades) | 45.0 % | **38.3 %** |
| rows with CloseTime ≥ 2026.09.01 (122 rows / 104 trades) | 50.0 % | **42.3 %** |

**Note:** the 38.3 % in the task message belongs to the Snapshot-era set (starts in August), not to "1 September onward"; a strict 1 Sept filter gives 42.3 %. The algorithm itself reproduces the 38.3 % on its own set. Market increments over the Snapshot era: old per-ticket 52.5 vs chain 51.5 (the only difference is the 15 Sept chain, net −0.05R: +1 → 0). Rule examples: −0.05R → 0, −0.10R → 0, −0.11R → +0.11, −0.5R → +0.5, −1R → +1, −1.6R at weight 0.5 → +0.5.

## A6 — Not run / limits
- Not compiled in MetaEditor, not run on MT4 (market closed, no live Half Close). Acceptance 1–3, 5 and 8 need a demo Half Close.
- A chain whose LAST closing ticket was closed while the EA was off is not seen by `CheckClosedTrades` (existing limitation), so its Market stop would not be counted; Trading Reports use History and are unaffected.
- Pre-v86 chains are not linked (no Backfill, as decided) → their parts stay separate trades in the statistics until the windows are filled with new trades.

---
# PART B — Hub v1.16

## B1 — New default list
Seed = `LEG 1, LEG 2, LEG 3, TR, SP, CH, HH, LL, 3 PUSH, D-B/T, POI, LQ, BR, MM, EQ-L, EQ-H, SP2L, BTB` (L01..L18). Migration key `HUB_LABELS_VERSION` 115 → 116: a file written under an older version is copied to `RM_HubLabels_backup.txt` and replaced once; afterwards manual edits are left alone. Empty slot = hidden button and the 20-char cap are unchanged.
**The reference `RM_HubLabels.txt` and the screenshot were not attached to the chat**, so the two header comment lines are the ones v1.15 already writes (your current file was created with them). Please compare the generated file with your reference.

## B2 — Geometry of the Label tab
- **Height:** all 18 label buttons use `BtnHeight` (22, = Ind+/Label/Draw+). Root cause of the misalignment: label buttons used `LabelBtnHeight` (18) with the second row at +18+gap, while SP2L/BTB sat at +22+gap. Now the grid's second row = the left block's second row (`gridRow1YTools`), the panel background height uses `BtnHeight`. Input `LabelBtnHeight` stays declared but is unused.
- **Width:** new input `LabelBtnWidth = 52` (longest default name "3 PUSH" ≈ 34–40 px at font 7 + ~7 px margin each side), scaled down with the other widths on small charts (floor 36). `ComputeContentWidth` got a 4th parameter so only the Label tab uses it. Draw/Indicator widths and Master size are unchanged.
- **SP2L / BTB** still fill the left block under the three Master buttons (3×58+2×4 = 182 px wide → 89 px each), at the same height and Y as the grid's second row.
- **Panel width, Label tab:** v1.15 = 934 px → v1.16 = 630 px (−304 px). The widest tab is now Draw (652 px, unchanged).
- Button objects are re-sized on every `PositionButtons` (also old objects that survive a reload), and the font is recomputed with the current effective width.

## B3 — Long custom names (explicit report, as requested)
Font fit (7 → 5 pt, estimate 0.9 × font px per capital letter, 6 px margin) at 52 px: up to ≈ 7 characters at 7 pt, 8 at 6 pt, **10 at 5 pt**. All 18 defaults fit at 7 pt. **A 20-character name does NOT fit legibly** (needs ≈ 90 px at 5 pt) and is clipped at the button edge. Suggest lowering `LABEL_MAX_CHARS` to ~10 (or widening `LabelBtnWidth`) — your call. The estimate is not measured on screen; verify visually.

## Verification
Brace/paren/bracket balance 0 on all 14 EA files and the Hub. Numbers above computed from the code constants and the real CSV; **no compile and no chart test was possible here.**
