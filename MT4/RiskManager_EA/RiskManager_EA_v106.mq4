//+------------------------------------------------------------------+
//|   Risk Manager v42 - UI/UX Punch List (last version before the   |
//|   Architecture Refactor). Six independent, low-risk items - no   |
//|   change to Risk/Drawdown/Cooldown/RB calculation, v29 color     |
//|   philosophy, v31 Trading/Utility split, v32 Global Layout        |
//|   Scaling, trade execution logic, or any Input.                   |
//|   Part 1 (Utility Tools drawer, R/R + Measure Move): reworked     |
//|   from "instant auto-anchor near the last 20 bars" action         |
//|   buttons into "arm, then click the chart" placement tools - the  |
//|   button turns the shared Tools-drawer active teal                |
//|   (CLR_TOOLS_ACTIVE), then the trader clicks two points directly  |
//|   on the chart (base, then target), exactly like MT4's own        |
//|   native Fibo tools. Each placement builds a brand-new, uniquely- |
//|   named object (g_fiboInstanceSeq) so multiple instances can      |
//|   coexist on the chart at once - no more manual deletion of the   |
//|   old one first. A 10s arm deadline (FIBO_ARM_MS, was 5s until v54,|
//|   same GetTickCount()                                              |
//|   pattern as the existing BE/Half/Full Close flash timers) auto-  |
//|   cancels back to grey if the trader doesn't finish clicking both |
//|   points in time. Show Objects' active color (was a one-off       |
//|   amber, C'190,140,0') and both Fibo tools now match the same     |
//|   teal every other Tools drawer toggle uses. R/R also gained the  |
//|   same light-chart-background contrast darkening Measure Move     |
//|   already had since v34.6 - its lines were washing out against a  |
//|   light background with a bull candle behind them.                |
//|   Part 2 (Status module): Floating text's max auto-fit font size  |
//|   trimmed one point (10->9) and its row nudged up 2px - at size   |
//|   10 the row had zero spare margin inside the merged Status box   |
//|   (STATUS_H+SUBROW_H+SUBROW_H, exact fit) and was touching the    |
//|   row below it.                                                   |
//|   Part 3 (Performance box): R and RB now share the same number-   |
//|   before-label order ("+0.0R +0.0RB" - RB used to read "R RB      |
//|   +0.0", label before number, the one inconsistent with R). Also  |
//|   1 char shorter, and PERF_PCT_W_RATIO rebalanced 0.50->0.52 to   |
//|   match the columns' actual text-length ratio - frees up unused   |
//|   width in the R/RB column so BestFitMonoFont() can pick a larger |
//|   shared font for both columns.                                   |
//|   Part 4 (Auto Half Close/Auto Trail preview labels, from v40):   |
//|   HLineLabel() gained an optional aboveLine parameter (default    |
//|   false - the 6 existing Daily/Weekly/Monthly H/L callers are     |
//|   unaffected) that anchors the text above its line instead of     |
//|   centered on it; both preview labels now pass true.              |
//|   Part 5 (BUG-035): new EnsureTrailingReset(), called every tick  |
//|   right after CheckClosedTrades(), before any Trailing sync/      |
//|   trigger logic runs - a consistency safety net alongside the     |
//|   existing g_trailCount==0 reset inside RemoveTrailTicketAt()     |
//|   (BUG-009, v8), which only fires at the exact moment of a        |
//|   removal. Live testing found g_trailingButtonOn staying ON after |
//|   a full close with no remainder ticket, which then silently swept|
//|   the next unrelated trade into Trailing. The Half Close-with-    |
//|   remainder case Mahmoud confirmed already correct (g_trailCount  |
//|   stays >0, nothing to reset) is untouched.                       |
//|   Part 6: the two BUG-026 diagnostic blocks left in CalcLot()     |
//|   since v22/v23 (an unconditional Print() of every raw value      |
//|   feeding the calculation, and a matching on-chart Comment()      |
//|   overlay) are removed now that this is the final version before  |
//|   the Refactor - BUG-026 itself was confirmed resolved back in    |
//|   v24. Only the diagnostic output is gone; CalcLot()'s path       |
//|   selection, NaN/Inf/sanity guard, and lot rounding/clamping are  |
//|   byte-for-byte unchanged.                                        |
//+------------------------------------------------------------------+
//|                                            RiskManager_EA.mq4    |
//|   Risk Manager v37 - Half Close Confirmation Window (FEAT-021).  |
//|   دکمه‌ی Half Close دیگه فوری اجرا نمی‌شه - یه پنجره‌ی تأیید دو-گزینه‌ای   |
//|   باز می‌کنه: "Half Close All" (رفتار قبلی) و "Profitable Only"     |
//|   (فقط پوزیشن‌های در سود همین الان نصف می‌شن). همون مکانیزم منوی      |
//|   Full Close (v15/v28) استفاده شده - GreyOutPanel، anchor pattern،  |
//|   collapse/restore موقت Performance drawer. HalfClose() یه پارامتر |
//|   جدید گرفت (onlyProfitable) - فقط یه فیلتر روی همون حلقه‌ی موجود؛   |
//|   clamp روی MODE_MINLOT و CheckPrematureAction/BUG-021 دست‌نخورده.  |
//|   بدون تغییر در Risk/Drawdown/Cooldown/RB، v29 color philosophy،    |
//|   v31 split، v32 Global Layout Scaling، یا هر Input.                |
//|   Risk Manager v35 - Utility Phase A, Part 2: Trading Reports     |
//|   module. New second collapsible drawer on the Utility            |
//|   dashboard, below the "Tools" drawer: "Trading Reports" with a   |
//|   Daily/Weekly/Monthly tab row and six derived-on-the-fly         |
//|   statistics - Win Rate, Profit Factor, Avg R:R (payoff ratio),   |
//|   Expectancy, Drawdown, Trade Count. No new persisted data of any |
//|   kind - everything is computed live from OrdersHistoryTotal()    |
//|   plus the existing Trade Snapshot arrays (g_snapRiskUSD,         |
//|   g_snapWasHalfRisk) each time the drawer is shown. New shared    |
//|   CalcTradingReportStats() function scans closed-trade history    |
//|   using the same filter pattern already used three times          |
//|   (CalcNetResultR/RB/Percent) - those three are deliberately NOT  |
//|   refactored to share it, to keep this addition low-risk.         |
//|   Avg R:R is the payoff ratio (avg win R : avg loss R), kept      |
//|   distinct from Expectancy (which folds in win rate) so the two   |
//|   boxes never show the same number. Drawdown here is a purely     |
//|   statistical peak-to-trough of the period's realized R curve -   |
//|   NOT connected to the existing Weekly/Monthly DD lock system     |
//|   (GetWeeklyDrawdown()/GetMonthlyDrawdown()/CheckDrawdownLimits() |
//|   are completely untouched). Collapsed by default, same header/  |
//|   toggle mechanic as the Tools drawer. No changes to any Risk/    |
//|   Drawdown/Cooldown/RB calculation logic, trade execution, v29    |
//|   color philosophy, v30 button-flash feedback, v31 Trading/       |
//|   Utility split, v32 Global Layout Scaling, or any Input          |
//|   parameter. Persian inline comments throughout preserved.        |
//+------------------------------------------------------------------+
//|   Risk Manager v34 - Tools Refinements + Dashboard Object         |
//|   Deletion Fix. Bundles 7 items collected after v33 testing - all |
//|   continuations/fixes to the v33 Tools module, plus one           |
//|   independent bug fix (BUG-033). NO changes to any Risk/          |
//|   Drawdown/Cooldown/RB calculation logic, the v29 Part 3 color    |
//|   philosophy, the v30 button-flash feedback, the v31 Trading/     |
//|   Utility split, the v32 Global Layout Scaling mechanism, trade   |
//|   execution, or any Input parameter. Seven items:                 |
//|   Item 1 (Contrast-aware colors): new shared GetContrastColor()   |
//|   helper - same CHART_COLOR_BACKGROUND luminance logic            |
//|   UpdateCandleTimerChart() (v26.6) already uses, generalized to a |
//|   per-tool dark-bg/light-bg color pair. Applied to Daily/Weekly/  |
//|   Monthly H/L, the BE reference line, and both Fibonacci tools -  |
//|   no more fixed blue/orange/gold/aqua colors that could go        |
//|   low-contrast on some chart themes.                              |
//|   Item 2 (Hide/Show split): the single v33 "Hide/Show All         |
//|   Drawings" toggle is now two fully independent buttons - chart   |
//|   objects (BTN_HIDEOBJ, ObjectsTotal()/OBJPROP_TIMEFRAMES) and    |
//|   real attached indicators (BTN_HIDEIND,                          |
//|   ChartIndicatorsTotal()/ChartIndicatorName()/                    |
//|   ChartIndicatorDelete()) - toggling one never touches the other. |
//|   Indicator removal keeps the same v33.1 platform-limitation      |
//|   behavior (delete-only, reports the count removed).              |
//|   Items 3+5 (Hi-Lo split into 3): the single v33 "PD/PW Hi-Lo"    |
//|   toggle is now three independent buttons - Daily H/L, Weekly     |
//|   H/L, and a new Monthly H/L - laid out together in one           |
//|   dashboard row (thirds width). Reuses the existing HLine()       |
//|   helper and the v33-final simple native-candle-read approach     |
//|   (iHigh()/iLow() off PERIOD_D1/PERIOD_W1, plus a new PERIOD_MN1  |
//|   read for Monthly) with the same iBars()<2/<=0 history-readiness |
//|   guard already proven working for Daily/Weekly.                  |
//|   Item 4 (Fibonacci Measure Move): a second, independent          |
//|   OBJ_FIBO-based action button (BTN_FIBMEASURE) alongside the     |
//|   existing R-Multiple tool, in the same dashboard row. Levels:    |
//|   0 = BASE, 1+ = MEASURE 1, 2, 3... Same no-ray, solid-line,      |
//|   purely-manual/draggable philosophy as the R-Multiple tool - no  |
//|   anchoring to trade data of any kind.                            |
//|   Item 6 (R-Multiple line style fix): the existing R-Multiple     |
//|   Fibo tool's level lines changed from STYLE_DOT to STYLE_SOLID.  |
//|   Item 7 (BUG-033): MT4's own "Delete All Objects" has no true    |
//|   object "lock" that survives it, regardless of                  |
//|   OBJPROP_SELECTABLE. New CheckPanelIntegrity(), called once per  |
//|   second from the EXISTING 1Hz OnTimer() (no second timer added), |
//|   verifies the titlebar background (P+"TITLEBAR" - the first      |
//|   object BuildPanel() creates, present on both Trading/Utility    |
//|   and even when minimized) still exists via ObjectFind(); if      |
//|   missing, immediately calls BuildPanel() to fully reconstruct    |
//|   the dashboard. Trader sees at most a sub-second flash.          |
//|                                                                    |
//|   v34.1 - small corrections from Mahmoud's first compile/review   |
//|   pass, before live testing: (1) both Fibo tools' level line      |
//|   width bumped one degree (OBJPROP_LEVELWIDTH 1->2). (2) Fib      |
//|   Measure Move trimmed from 8 levels down to 3 (BASE, MEASURE 1,  |
//|   MEASURE 2 - that's all it needs). (3) Daily/Weekly/Monthly H/L  |
//|   lines each now carry a small OBJ_TEXT identifier to their right |
//|   (new HLineLabel() helper) - PDH/PDL, PWH/PWL, PMH/PML - so it's |
//|   clear at a glance which line is which. Indicator Hide/Show      |
//|   (true non-destructive toggle instead of delete) was requested   |
//|   but is NOT implemented - MQL4 has no API to hide an attached    |
//|   indicator without removing it (no counterpart to                |
//|   OBJPROP_TIMEFRAMES exists for indicators), so ChartIndicatorDelete()   |
//|   remains the only mechanism; BTN_HIDEIND behavior is unchanged   |
//|   from the base v34 delete-and-report design pending Mahmoud's    |
//|   direction on how to proceed.                                    |
//|                                                                    |
//|   v34.2 - fixed HLineLabel() from v34.1 landing in the middle of  |
//|   the chart instead of the right edge (used ChartXYToTimePrice()  |
//|   instead of a fixed 2-bar offset). v34.3 - fixed a compile error |
//|   in that same fix (called ChartXYToTime(), which doesn't exist   |
//|   in MQL4 - corrected to ChartXYToTimePrice(), already used       |
//|   elsewhere in this file).                                        |
//|                                                                    |
//|   v34.4 - final round of refinements before sign-off, per         |
//|   Mahmoud's decision on the Indicator Hide/Show question above:   |
//|   (1) "Remove Indicators" (BTN_HIDEIND) removed entirely -        |
//|   g_indicatorsHidden, ToggleHideIndicators(),                     |
//|   UpdateHideIndButton(), and the ChartIndicatorsTotal()/           |
//|   ChartIndicatorName()/ChartIndicatorDelete() code added only for |
//|   it are all gone; "Hide Objects" is unaffected. (2) Tools drawer |
//|   relaid out as a uniform 2-per-row grid (half-width buttons      |
//|   throughout) now that the remaining count is even (8 items).     |
//|   (3) ON/OFF suffix dropped from Daily/Weekly/Monthly H/L, Candle |
//|   Timer, and BE Ref Line button labels - color alone now carries  |
//|   the on/off state, same convention Trailing already established |
//|   in v29. (4) R/R tool's line color now reads the chart's own     |
//|   bullish-candle color (CHART_COLOR_CANDLE_BULL) instead of the   |
//|   dark/light contrast-aware helper. (5) Measure Move's line color |
//|   likewise now reads the chart's bearish-candle color             |
//|   (CHART_COLOR_CANDLE_BEAR) - Daily/Weekly/Monthly H/L and BE Ref |
//|   Line keep the base v34 contrast-aware treatment, unchanged.     |
//|   (6) Risk Lab/Journal/AI Coach placeholders: Risk Lab moved to   |
//|   the bottom-most position (Journal/AI Coach keep their relative  |
//|   order above it); "Coming soon" status message removed entirely |
//|   - clicking now does nothing at all; dimmed text color alone     |
//|   conveys the inactive state. (7)+(8) "Fib R-Multiple" renamed to |
//|   "R/R" and "Fib Measure Move" renamed to "Measure Move" (typo    |
//|   fixed, "Fib" prefix dropped) on the dashboard and in status     |
//|   messages - internal object/function names unchanged (never     |
//|   shown to the trader).                                           |
//|                                                                    |
//|   Risk Manager v33 - Utility Phase A, Part 1 (Tools Expansion +  |
//|   Placeholder Buttons + BUG-032), REVISED per Mahmoud's live-    |
//|   test feedback (rounds 2-4, this is the current/final state).   |
//|   NO changes to any Risk/Drawdown/Cooldown/RB calculation logic, |
//|   the v29 Part 3 color philosophy, the v30 button-flash          |
//|   feedback, the v31 Trading/Utility split, the v32 Global Layout |
//|   Scaling mechanism, trade execution, or any Input parameter.    |
//|   Three parts:                                                   |
//|   Part 1 (Tools drawer - lives inside the existing v31 Utility   |
//|   Tools drawer, alongside the v26 Candle Timer): FOUR items      |
//|   remain after two were removed on request (see below) -         |
//|   PD/PW High-Low (4 HLine() reference lines: daily from          |
//|   iHigh()/iLow() on PERIOD_D1 shift 1; weekly rebuilt manually   |
//|   as a calendar Monday-to-Monday range over real D1 bars,        |
//|   NOT read off the native PERIOD_W1 candle, since MT4's own W1   |
//|   week-start day is a platform/broker setting outside the EA's   |
//|   control - this naturally handles forex's 2 closed days and     |
//|   crypto's full 7-day week without special-casing either);       |
//|   Hide/Show All Drawings (single toggle - snapshots every        |
//|   non-panel chart OBJECT's current OBJPROP_TIMEFRAMES before     |
//|   setting it to OBJ_NO_PERIODS, restoring each object's EXACT    |
//|   original value on toggle-back; ALSO removes every real         |
//|   attached indicator via ChartIndicatorsTotal()/                 |
//|   ChartIndicatorName()/ChartIndicatorDelete() and WindowsTotal() |
//|   - MT4 has no "hide" for indicators, only delete, and no way    |
//|   to recreate one from just its name, so indicators removed      |
//|   this way are gone, not hidden - "Show" only restores chart     |
//|   objects, and reports how many indicators need manual           |
//|   re-adding); Break Even reference line (BE Ref Line - reuses    |
//|   the existing GetBasketAveragePrice() calc from v14 Basket      |
//|   Break-Even, drawn via HLine() as a read-only preview, separate |
//|   object names from the real BE Basket execution line so the    |
//|   two never collide); Fibonacci R-Multiple tool (a BTN_FIBRMULT  |
//|   action button that (re)creates one native OBJ_FIBO object,     |
//|   Ray/extend-right OFF, levels relabeled to risk-multiple        |
//|   semantics - level 0 = SL, level 1 = Entry, levels 2+ = R1,     |
//|   R2, R3... - instead of a plain integer count; purely a manual  |
//|   drawing tool, no auto-anchor to trade data of any kind,        |
//|   SELECTABLE so the trader can drag it, and NOT deleted by       |
//|   OnDeinit/panel rebuilds since it behaves like any other        |
//|   manually-placed native chart object). REMOVED on request:      |
//|   Session Timer (on-chart countdown - dropped entirely, along    |
//|   with its GlobalVariable persistence and on-chart object) and   |
//|   the 3 simultaneous Moving Averages tool (manually-drawn        |
//|   OBJ_TREND segments weren't what was wanted - a genuinely       |
//|   native, zero-EA-computation MA needs ChartApplyTemplate() with |
//|   a pre-built .tpl file, a bigger follow-up, not this version).  |
//|   Remaining 4 items are laid out as a 2x2 grid of half-width     |
//|   buttons (Candle Timer/PD-PW, BE Ref/Fib R-Multiple) with       |
//|   Hide/Show All Drawings alone on its own full-width row below - |
//|   noticeably less vertical space than one row per item. Every    |
//|   toggle button follows the existing Candle Timer on/off color   |
//|   convention (teal = ON, C'70,70,80' = OFF) and updates in-place |
//|   without a full panel rebuild, same as BTN_CANDLETIMER; PD/PW,  |
//|   Hide/Show, and BE Ref are intentionally NOT persisted (reset   |
//|   to off on EA restart) - no persistence requirement was given   |
//|   for those. All new on-chart objects use the same               |
//|   non-P-prefixed naming convention as                            |
//|   TrailLineName/BELineName/CANDLE_TIMER_OBJ so they survive the  |
//|   ObjectsDeleteAll(0,P) panel-rebuild cycle.                     |
//|   Part 2 (Placeholder buttons): three always-visible, disabled-  |
//|   look buttons (Risk Lab / Journal / AI Coach) added below the   |
//|   Tools drawer on Utility - clicking any of them just shows a    |
//|   "Coming soon" status message; no functionality behind them.    |
//|   Part 3 (BUG-032): the Behavior CD box is HALF the width        |
//|   FitBoxFontBig()'s length thresholds were tuned for (it shares  |
//|   the CD row with Market CD, side by side) - the active-lock     |
//|   countdown format ("Beh CD: 0:53:26", 15 chars) stayed at that  |
//|   function's un-shrunk size-10 tier and overflowed the box even  |
//|   though the same length would fit fine in a full-width box.     |
//|   Fix: new FitBoxFontHalf(objName, txt, boxW) - width-aware,     |
//|   estimates rendered text width per candidate font size (10 down |
//|   to the existing 6-floor) against the box's actual pixel width  |
//|   and picks the largest size that clears it, same general        |
//|   "shrink font dynamically" spirit as FitBoxFont()/               |
//|   FitBoxFontBig() but box-width-aware instead of length-tier-    |
//|   only. Only L_BEHCD's call site is switched to it - Market CD,  |
//|   Weekly/Monthly DD, and Floating P/L are unaffected (not part   |
//|   of the reported bug, and their existing thresholds already fit |
//|   their boxes).                                                  |
//|                                                                    |
//|   Risk Manager v32 - Global Layout Scaling (Part 2 of 2 - v31    |
//|   was the rename/split itself; this is the deferred scaling      |
//|   system). NO changes to any Risk/Drawdown/Cooldown/RB           |
//|   calculation logic, the v29 Part 3 color philosophy, the v30    |
//|   button-flash feedback, the v31 Trading/Utility split itself    |
//|   (element placement/order within each dashboard), trade         |
//|   execution, or any other Input parameter.                       |
//|   New input: LayoutScale (100%/90%/80%, default 100% - no        |
//|   visual change unless the trader picks a smaller size).         |
//|   Every layout constant that drives panel geometry - PW, TH, MX, |
//|   GP, ALERT_H, STATUS_H, SUBROW_H, RISKRR_H, MP_H, ACT_H, CD_H,  |
//|   PERF_HDR_H, PERF_ROW_H, PERF_BOX_PAD, PERF_ROW_FONT,           |
//|   TOOLS_HDR_H, TOOLS_ROW_H, CLOSE_GRID_ROW_H, CLOSE_GRID_GAP -   |
//|   changed from fixed #define literals to global variables set    |
//|   once by the new ApplyLayoutScale() (called first thing in      |
//|   OnInit(), before BuildPanel()) using two new rounding helpers, |
//|   SC() for pixel dimensions and SCF() for font sizes (same       |
//|   clamp-floor idea as FitBoxFont()/FitBoxFontBig() - never below |
//|   size 6). BtnC()/LblC()/LblCC() now scale their own sz          |
//|   parameter internally via SCF(), so every font size on the      |
//|   panel - default or explicit, at every call site - is scaled    |
//|   automatically with no per-call-site edits needed. The same     |
//|   mechanism (one scale, one set of constants) drives both        |
//|   Trading and Utility - there is no second/duplicate scaling     |
//|   path. A handful of literal pixel offsets that weren't behind a |
//|   named constant (title bar button/label/toggle positions, the   |
//|   MARKET/PENDING stacked-label vertical gap, the two drawer top  |
//|   paddings, the status-text vertical-centering offsets) are      |
//|   individually wrapped in SC()/SCF() so they scale in lockstep   |
//|   with everything else instead of staying fixed while the panel  |
//|   around them resizes. IsOnPanel() needed no direct changes - it |
//|   already computes its hit-test rectangle from PW/TH/            |
//|   ComputeBodyH(), all of which are now scaled, so click           |
//|   detection automatically matches the rendered (scaled) panel.   |
//|   Implemented as an Input (not a dashboard control) - see the    |
//|   comment beside the LayoutScale input declaration for why.      |
//|                                                                    |
//|   Risk Manager v31 - Dashboard Architecture: Trading + Utility   |
//|   Split (Part 1 of 2 - the rename/split itself; a separate       |
//|   future version handles Global Layout Scaling, out of scope     |
//|   here). NO changes to any Risk/Drawdown/Cooldown/RB calculation |
//|   logic, the v29 Part 3 color philosophy, the v30 button-flash   |
//|   feedback, trade execution, or any Input parameter. Core        |
//|   principle: "A dashboard should be defined by its               |
//|   responsibility, not by its size." Four changes:                |
//|   (1) FULL -> Trading, COMPACT -> Utility: renamed everywhere -   |
//|   the EDashboardMode enum (DASH_FULL/DASH_COMPACT ->              |
//|   DASH_TRADING/DASH_UTILITY, ordinal values unchanged so           |
//|   GV_DASH_MODE needs no migration), the titlebar toggle buttons   |
//|   (BTN_DASH_FULL/COMPACT -> BTN_DASH_TRADING/UTILITY, labels      |
//|   "FULL"/"COMPACT" -> "Trading"/"Utility"), and every status      |
//|   message/comment referencing dashboard mode. This is a rename    |
//|   WITH a behavior change (Changes 2-4), not a cosmetic text swap: |
//|   Trading is now trading-only (trade execution, risk management, |
//|   position management, performance monitoring - Risk/RR,          |
//|   Market/Pending, BE/Half Close/Full Close/Trailing, Market CD/   |
//|   Behavior CD, Performance), and Utility is a dedicated           |
//|   workspace for supporting tools with no trading controls at      |
//|   all - v28 Change 8's condensed COMPACT 4-button action row      |
//|   (BE/Half/Close/Trl) and the Risk/RR + Market/Pending rows that  |
//|   used to build unconditionally for both modes are removed from   |
//|   Utility entirely, not just hidden.                              |
//|   (2) Tools drawer migrated Trading -> Utility: the v26 Tools     |
//|   drawer (Candle Timer toggle) is now the first and only module   |
//|   on Utility. Candle Timer's own functionality (on-chart          |
//|   countdown, toggle state, GlobalVariable persistence) is         |
//|   byte-for-byte unchanged - only its home dashboard changes.      |
//|   (3) Alert/status box (status + Open Risk + Floating, v27/v28)   |
//|   is unaffected by this split - it already built unconditionally  |
//|   before the Trading/Utility branch and continues to, so open     |
//|   trades and account state stay visible from Utility too. Same    |
//|   content, same v29 Part 3 color rules, on both dashboards.       |
//|   (4) Trading cleanup: the Tools header button, its expand/       |
//|   collapse handling, and its reserved ComputeBodyH() layout       |
//|   space are removed from Trading's build path entirely (not      |
//|   hidden/dead) now that Tools lives on Utility. UpdateTrailButton |
//|   simplified (its now-unreachable COMPACT short-label branch      |
//|   removed, since BTN_TRAIL only exists on Trading and Trading     |
//|   never needed the short "Trl" label). GreyOutPanel()'s object    |
//|   list drops BTN_TOOLS/BTN_CANDLETIMER (unreachable - it's only   |
//|   called from the Trading-only Close submenu). COMPACT_ACT_H      |
//|   define removed (no longer used anywhere).                       |
//|                                                                    |
//|   Risk Manager v30 - Button Click Feedback + MARKET/PENDING      |
//|   Visibility. NO changes to any Risk/Drawdown/Cooldown/RB        |
//|   calculation logic, the v29 Part 3 color philosophy (grey/      |
//|   orange/red forbidden-zone elements), the v26 Tools drawer's    |
//|   Candle Timer functionality, trade execution, or any Input      |
//|   parameter. Two parts:                                          |
//|   Part 1 (Click feedback): Break Even/Half Close/Full Close -    |
//|   the one-shot action buttons made permanently grey in v29       |
//|   Revision 1 - now flash a full, solid, per-button color         |
//|   (purple/gold/magenta) the instant their action fires, and      |
//|   revert to the resting grey after exactly 5 real seconds.       |
//|   Driven by GetTickCount() deadlines (g_beFlashEnd/               |
//|   g_halfFlashEnd/g_fullFlashEnd) checked once per second from    |
//|   the EXISTING OnTimer() (already running at 1Hz for the v26     |
//|   Candle Timer) - no second competing timer added. Each button   |
//|   has its own independent deadline, so clicking two within the   |
//|   same 5-second window colors/reverts each on its own schedule.  |
//|   Part 2: MARKET ORDER/PENDING ORDER base (inactive) color        |
//|   MP_BASE_GREY brightened again (C'105,105,118'->C'142,142,158') |
//|   per Mahmoud feedback that v29 Revision 2's lightening still    |
//|   wasn't visible enough at a glance. Selected-state blue/orange  |
//|   accents unchanged.                                              |
//|                                                                    |
//|   Risk Manager v29 - Dashboard Visual Polish, Part 2 (Panel-Wide |
//|   Color Philosophy + Bug Fixes). NO changes to any Risk/         |
//|   Drawdown/Cooldown/RB calculation logic, the v26 Tools drawer's |
//|   Candle Timer functionality, trade execution, or any Input      |
//|   parameter. Three parts:                                        |
//|   Part 1 (BUG-031): MARKET ORDER/PENDING ORDER click dead-zone - |
//|   the overlay label objects (L_MKT1/L_MKT2/L_PND1/L_PND2) were   |
//|   already SELECTABLE=false, but MT4's click hit-testing on       |
//|   overlapping objects is governed separately by OBJPROP_ZORDER,  |
//|   and could still intercept clicks meant for the button beneath. |
//|   BTN_MARKET/BTN_PENDING now get an explicit higher Z-order than |
//|   their overlay labels. Also tightened the vertical gap between  |
//|   the two stacked "MARKET"/"ORDER" and "PENDING"/"ORDER" label   |
//|   lines (previously ~28px center-to-center, now 16px).           |
//|   Part 2: "RISK MANAGER" titlebar text was getting clipped       |
//|   against the FULL/COMPACT toggle in the 195px titlebar - title  |
//|   moved left and dropped one font size (8->7), FULL/COMPACT      |
//|   tightened/shifted slightly to free up room.                    |
//|   Part 3 (Panel-wide color philosophy): replaced the ad-hoc      |
//|   color logic across the informational displays with one         |
//|   consistent rule - elements with NO real forbidden zone stay a  |
//|   neutral grey (CLR_NEUTRAL); elements WITH a real forbidden     |
//|   zone (a limit that can warn or lock) use a 3-state grey ->     |
//|   orange (CLR_APPROACHING, >=85% of the limit) -> red            |
//|   (CLR_BREACHED, at/beyond the limit) treatment. Applied to:     |
//|   Open Risk (vs MaxTotalRisk), Floating P/L (vs the emergency-   |
//|   close threshold), Market CD (vs its lock threshold, text +     |
//|   BG_MKT background), Behavior CD (vs its lock threshold, text + |
//|   BG_BEH background - previously this box's background never    |
//|   changed dynamically), and Daily/Weekly/Monthly P/L (vs         |
//|   MaxDailyRisk/MaxWeeklyDD/MaxMonthlyDD, replacing the old        |
//|   green/red-by-sign scheme). Each Daily/Weekly/Monthly row is    |
//|   now two label objects (e.g. L_DPL + L_DPL_RB) instead of one,  |
//|   so only the "<Period> P/L: x.xx%" segment follows the 3-state  |
//|   rule while the Trade R and RB figures (L_*_RB) stay            |
//|   permanently CLR_NEUTRAL regardless of sign, since they have no |
//|   limit/lock tied to them. Toggle/selection controls (FULL/      |
//|   COMPACT, MARKET/PENDING, BE/Half Close/Full Close/Trailing,    |
//|   Close submenu) are a separate, pre-existing mechanism and are  |
//|   untouched by this change - still grey when inactive, colored   |
//|   only when active.                                              |
//|                                                                    |
//|   Risk Manager v28 - Dashboard Visual Polish, Part 1 (Layout &   |
//|   Structure). Pure visual/layout pass - NO changes to any Risk/  |
//|   Drawdown/Cooldown/RB calculation logic, the v26 Tools drawer's |
//|   Candle Timer functionality, trade execution, or any Input      |
//|   parameter. Part 2 (v29, a panel-wide color-theme change) is    |
//|   explicitly deferred - not touched here beyond what Change 6    |
//|   below requires for the Close submenu specifically. Changes:    |
//|   (1) Panel widened 145->210px and font sizes increased          |
//|   throughout (FitBoxFont/FitBoxFontBig base sizes and length     |
//|   thresholds raised) so v27's cramped, hard-to-read text has     |
//|   room to breathe.                                                |
//|   (2) Top section reordered: Alert/status box -> Full Risk/RR    |
//|   row -> MARKET ORDER/PENDING ORDER -> everything else in the    |
//|   same relative order as v27.                                    |
//|   (3) TRUE single-box merge for the alert/status area - Status   |
//|   (2 lines) + Open Risk + Floating now share ONE background      |
//|   (BG_ALERT) instead of v27's three adjacent boxes; still three  |
//|   separate text lines/colors, only the container is unified.     |
//|   Per-row background threshold tinting (BG_OPEN/BG_FDD) is       |
//|   dropped since there's no longer a separate background per row  |
//|   to tint - the existing text-color feedback already carries the |
//|   same information.                                               |
//|   (4) MARKET ORDER/PENDING ORDER made visibly taller (44px vs    |
//|   the ~28px of surrounding rows) - primary trade-entry actions.  |
//|   (5) TRUE single-box merge for the Performance box - Daily/     |
//|   Weekly/Monthly now share ONE background (BG_PERF) instead of   |
//|   v27's three individual color blocks (BG_DPL/BG_WDD/BG_MDD).    |
//|   Same background/text-color simplification as Change 3 applies  |
//|   to the weekly/monthly lock-countdown tint.                     |
//|   (6) Close submenu rebuilt as a 2x2 grid (Close All/Close Chart |
//|   on top, Close Profit/Close Loss below), sized like the rest of |
//|   the panel's buttons instead of full-width stacked rows. While  |
//|   open, GreyOutPanel() dims every other panel object to neutral  |
//|   grey except the Close button and the grid itself - a           |
//|   self-contained exception to the "no color-theme work" scope    |
//|   limit, since it's part of this specific interaction, not the   |
//|   panel-wide theme deferred to v29.                              |
//|   (7) The Performance box (FULL mode) auto-collapses when the    |
//|   Close submenu opens and only re-expands on close if it was     |
//|   actually open beforehand (g_perfWasOpenBeforeSubmenu) - never  |
//|   forces it open if the trader had it manually collapsed.        |
//|   (8) COMPACT mode reordered/rebuilt: Alert box -> Full Risk/RR  |
//|   -> MARKET/PENDING -> all 4 action buttons (Break Even/Half     |
//|   Close/Close/Trailing) on one condensed row with shortened      |
//|   labels - previously COMPACT had NO action buttons at all       |
//|   (FULL-mode-only in v26/v27); all four are now present and      |
//|   functional in COMPACT too, sharing the same BTN_BE/BTN_HALF/   |
//|   BTN_FULL/BTN_TRAIL object names as FULL mode so all existing   |
//|   click-handler logic (ManualBE/HalfClose/Open-CloseFullClose    |
//|   Menu/trailing toggle) carries over unchanged.                  |
//|   Internally, BuildPanel()'s hand-computed yy+N magic-number     |
//|   offsets are replaced with a running layout cursor, and a new   |
//|   ComputeBodyH() pure function (mirroring that same cursor       |
//|   arithmetic) is shared by BuildPanel() (to size the BG          |
//|   rectangle up front), IsOnPanel() (hit-testing), and             |
//|   OpenFullCloseMenu() (submenu anchor position) - replacing      |
//|   v27's separate BH/BH_COMPACT/BH_PERF_OPEN_EXTRA/                |
//|   BH_TOOLS_OPEN_EXTRA constants so all of these always agree.    |
//|                                                                    |
//|   Risk Manager v27 - Dashboard Layout Restructuring. Pure visual |
//|   reorganization/information-density pass - NO changes to any    |
//|   Risk/Drawdown/Cooldown/RB calculation logic, the v26 Tools     |
//|   drawer's Candle Timer functionality, trade execution, or any   |
//|   Input parameter. Five changes, all display-only:               |
//|   (1) Open Risk + Floating P/L merged into one 2-line alert area |
//|   directly under the Status bar (previously two separate boxes   |
//|   elsewhere on the panel) - kept as two adjacent Rect+Label      |
//|   pairs (not one shared text object) so each one's independent   |
//|   background+text color scheme survives unchanged; Floating P/L  |
//|   is now shown in COMPACT mode too (previously FULL-only).       |
//|   (2) Daily/Weekly/Monthly P/L collapsed from three tall 3-line/ |
//|   44px boxes into one new collapsible "Performance" box (one     |
//|   compact row per period: "Daily P/L: +0.00%   +0.0R   RB +0.0", |
//|   RB as a prefix per spec, "of X%" threshold text dropped) -     |
//|   same collapsible header mechanic as the v26 Tools drawer, but  |
//|   defaults to OPEN on every EA attach (g_perfDrawerOpen, not     |
//|   persisted - Tools stays collapsed-by-default, unchanged).      |
//|   Weekly/Monthly lock-countdown display still works inside the   |
//|   new row format; the underlying %/R/RB VALUES and lock logic    |
//|   are untouched, only their rendering is. FULL mode only, same   |
//|   as the boxes it replaces.                                      |
//|   (3) FULL/COMPACT toggle moved off its own dedicated MODEBAR    |
//|   row (removed entirely) into the titlebar, inline beside "RISK  |
//|   MANAGER" (TH grown 20->24 to fit both).                        |
//|   (4) Market CD + Behavior CD merged onto one shared row (two    |
//|   half-width Rect+Label pairs side by side, each keeping its own |
//|   independent color logic from v26).                             |
//|   (5) Full panel reflow to account for 1-4 - net effect is a     |
//|   much shorter default panel (BH 420->266, +58 when the now-     |
//|   open-by-default Performance box is expanded = 324 typical vs   |
//|   420-443 in v26) despite the Performance box being visible by   |
//|   default, per the standing principle established this round:    |
//|   "if a control doesn't deserve its own row, it shouldn't have   |
//|   one." IsOnPanel()/OpenFullCloseMenu() updated for the new      |
//|   geometry (MH term removed, Performance drawer state added to   |
//|   the bodyH formula) so click routing and the Full Close submenu |
//|   still land on the right coordinates.                           |
//|                                                                    |
//|   Risk Manager v26 - FEAT-018: Candle Timer + Tools Drawer       |
//|   Foundation. New collapsible "🛠️ Tools" drawer on the dashboard  |
//|   (FULL mode only, directly under the Performance/Floating P/L   |
//|   boxes) - built as a generic, extensible drawer container (not  |
//|   a one-off toggle) so a future Phase B "Trading Workspace" can  |
//|   later add more tools inside it without rebuilding this         |
//|   mechanic. This version builds the drawer shell + exactly one   |
//|   working item inside it: a dashboard-driven Candle Timer toggle |
//|   (BTN_CANDLETIMER) - NOT a static Input, which was the original |
//|   single-purpose spec before Mahmoud expanded scope.             |
//|   Drawer header (BTN_TOOLS) is collapsed by default and does NOT |
//|   persist across EA restarts (resets to collapsed on reattach,   |
//|   by design - kept simple); reuses the same click->rebuild->     |
//|   dynamic-height pattern as the existing FULL/COMPACT toggle and |
//|   the v25 RB line addition (BH grew 396->420 for the always-     |
//|   visible header row; +23 more via BH_TOOLS_OPEN_EXTRA only      |
//|   while expanded). IsOnPanel() updated with the same bodyH       |
//|   formula so clicks on the expanded drawer route correctly.      |
//|   Candle Timer ON/OFF persists via GlobalVariable (GV_CANDLE_    |
//|   TIMER, Symbol()-scoped) - same simpler pattern as GV_DASH_MODE,|
//|   not the account-scoped BUG-029/030 convention, since this is a |
//|   display preference, not a risk/balance figure. The on-chart    |
//|   countdown itself (UpdateCandleTimerChart, OBJ_TEXT named       |
//|   CANDLE_TIMER_OBJ, drawn next to the last candle - deliberately |
//|   outside the "RM9_" panel-object namespace so panel rebuilds    |
//|   don't wipe it) computes remaining = (current bar open time +   |
//|   chart period in seconds) - current server time every tick,     |
//|   formatted M:SS or H:MM:SS (>=1 hour remaining). Object is      |
//|   created/updated only while the toggle is ON and is removed     |
//|   immediately on toggle-OFF (not deferred to next tick) and on   |
//|   OnDeinit. No changes to Trade R, RB, Drawdown %, Cooldown       |
//|   counters, lock logic, or any BUG-029/030 logic from v25.       |
//|                                                                    |
//|   Risk Manager v25 - FEAT-017: Base R (RB) Metric. New, fully    |
//|   independent derived display metric shown next to the existing |
//|   R figure on the Daily/Weekly/Monthly P/L boxes: RB = Trade R x |
//|   (0.5 if that trade's Snapshot WasHalfRisk==true, else 1.0).    |
//|   New CalcNetResultRB()/GetDailyRB()/GetWeeklyRB()/GetMonthlyRB()|
//|   read the same OrdersHistoryTotal loop and per-ticket Snapshot  |
//|   (g_snapRiskUSD, g_snapWasHalfRisk - both existing, v11/v19,    |
//|   no new stored fields) as the existing R functions, but as a    |
//|   completely separate code path - CalcNetResultR()/GetDailyR()/  |
//|   GetWeeklyR()/GetMonthlyR() and everything they feed (Drawdown  |
//|   %, Cooldown counters, lock logic) are untouched. Each trade's  |
//|   own already-correct Trade R (including partial R from an early |
//|   exit) is what gets weighted - not an assumed full-target R.    |
//|   Legacy fallback: a ticket with no Snapshot at all is skipped   |
//|   (identical to the existing R functions - not computable); a    |
//|   ticket with a Snapshot but no WasHalfRisk data (pre-v19) uses  |
//|   g_snapWasHalfRisk's existing LoadTradeSnapshots() fallback of  |
//|   false, so RB automatically defaults to Full Risk (RB==R) with  |
//|   no extra fallback code needed here. Display: Daily/Weekly/     |
//|   Monthly P/L boxes grew from 32px to 44px (BH +36, same pattern |
//|   v11 used to add the R line) to fit a new compact third line    |
//|   ("RB +x.x") below the existing R line; the existing % and R    |
//|   lines keep their exact text/logic, only their vertical offset  |
//|   shifted to fit the taller box. Floating P/L box moved down     |
//|   accordingly (yy+329 -> yy+365). Locked-state Weekly/Monthly    |
//|   boxes blank the RB line the same way they already blank the R  |
//|   line. No changes to Trade R, Drawdown, or Cooldown logic.      |
//|                                                                    |
//|   BUG-029: GlobalVariable keys for the day/week/month start-time/ |
//|   start-balance pair (GV_DAY_START[_BAL], GV_WEEK_START[_BAL],    |
//|   GV_MONTH_START[_BAL]) were scoped by MagicNumber only (v20,     |
//|   BUG-025). MT4 GlobalVariables are terminal-wide, not per-       |
//|   account - so two different accounts sharing a terminal and the  |
//|   same Magic Number read/wrote the exact same keys, letting one   |
//|   account's start-of-week/month balance leak into another         |
//|   account's Drawdown% denominator (observed: a fresh demo account |
//|   inherited a cent-real account's balance and immediately false-  |
//|   locked on Weekly/Monthly DD before any trade). Fix: added       |
//|   AccountNumber() as one more scoping level, same pattern as      |
//|   BUG-025 itself - key format is now RM_..._A<AccountNumber>_     |
//|   M<MagicNumber> instead of RM_..._M<MagicNumber>. Old keys are   |
//|   abandoned, same no-migration approach as BUG-025 - each         |
//|   account's first run under the new format freshly captures its   |
//|   own correct start balance. No change to the time-based reset    |
//|   trigger logic - only the key-name construction changed.        |
//|                                                                    |
//|   BUG-030 (found inspecting this same v25 build): GV_WEEKLY_END   |
//|   and GV_MONTHLY_END (store whether a Weekly/Monthly lock is      |
//|   active and until when) were scoped by Symbol() only - missed by |
//|   the BUG-029 fix above, which only added AccountNumber() scoping |
//|   to the six START/START_BAL keys. Result: a lock flag set by one |
//|   account stayed shared with every other account trading the same |
//|   symbol on the same terminal, so a fresh demo account could      |
//|   still show locked even after BUG-029 fixed the Drawdown%        |
//|   denominator - the leftover lock-active flag itself was the      |
//|   contamination, not the balance. Fix: added the same             |
//|   AccountNumber()+MagicNumber scoping as BUG-029, ahead of the    |
//|   existing Symbol() (kept, not removed) - RM_..._A<AccountNumber>_|
//|   M<MagicNumber>_<Symbol> instead of RM_..._<Symbol>. All read/    |
//|   write call sites (SaveDrawdownState/LoadDrawdownState) already   |
//|   reference these constants by name - no other change needed.    |
//|   Risk Manager v24 - BUG-026 (real root cause, via on-chart diag |
//|   confirmed on Silver/ErranteTrading-Demo2): the broker does NOT |
//|   report MODE_TICKVALUE as 0 for Silver as originally suspected  |
//|   from the Specification dialog (which rounds to 3 decimals) -   |
//|   the raw value is a nonzero 0.0001, equal to MODE_TICKSIZE, so  |
//|   the v21-v23 tickValue>0 && tickSize>0 check passed and trusted |
//|   a tick-based pval of 0.01 - which is wrong by a factor of      |
//|   ~5000 (the contract size) versus the correct value derivable   |
//|   from MODE_LOTSIZE=5000. A >0 check cannot catch a nonzero but  |
//|   still-wrong tick value. Fix: CalcLot() now branches on         |
//|   MarketInfo(Symbol(),MODE_PROFITCALCMODE) instead - 0 (Forex)   |
//|   uses the tick-based calc as before (XAUUSD, Forex-mode, is     |
//|   PROFITCALCMODE 0, so its path and output are unchanged from    |
//|   v20/byte-for-byte identical); 1 (CFD) or 2 (Futures) goes      |
//|   straight to the MODE_LOTSIZE-based contract-size calc,         |
//|   bypassing the unreliable tick value/size entirely rather than  |
//|   trying to validate it. The NaN/Inf/sanity guard, the           |
//|   Alert()+Print() on unresolvable pip value, and the v22/v23     |
//|   CalcLot DIAG Print()/Comment() diagnostics are all unchanged   |
//|   and kept for one more confirmation pass.                       |
//|                                                                    |
//|   BUG-027 (same root cause, found live during BUG-026 testing):  |
//|   GetTotalOpenRisk() had the identical unconditional              |
//|   tickValue/tickSize pip-value calc, so open Silver positions     |
//|   priced Open Risk at an effectively-zero (~0.00%) instead of     |
//|   their real risk. Fixed with the same MODE_PROFITCALCMODE        |
//|   branch as CalcLot(): Forex-mode (calcMode 0) with valid tick    |
//|   data keeps the v20/BUG-024 tick-based calc unchanged; CFD/      |
//|   Futures (or invalid tick data) uses MODE_LOTSIZE-based pip      |
//|   value instead. Same NaN/Inf/garbage guard added (skips that     |
//|   order's contribution rather than corrupting the total). No      |
//|   change to which orders are included (still all orders with      |
//|   this EA's MagicNumber and a valid SL, across all symbols) or    |
//|   to the % of balance conversion at the end.                      |
//|                                                                    |
//|   BUG-028 (same root cause, found live via absurd +14054.1R on    |
//|   the dashboard after the Silver trades from BUG-026/027 testing):|
//|   the Trade Snapshot's risk-in-$ capture (used as "1R" for all    |
//|   Daily/Weekly/Monthly P/L-in-R display) had the same broken      |
//|   tickValue/tickSize calc, so a Silver trade's snapshot risk was  |
//|   captured as a near-zero $ value - dividing real profit by that  |
//|   near-zero risk produced the runaway R figure. The same broken   |
//|   formula was found duplicated in 3 more places (live SL/TP $     |
//|   preview x2, legacy no-snapshot fallback classification). All 4  |
//|   are fixed and consolidated into one new shared function,        |
//|   GetPipValueForSymbol(sym, point, pipFactor), so this exact bug  |
//|   pattern can no longer drift out of sync across the file.        |
//|   CalcLot() and GetTotalOpenRisk() keep their own already-tested   |
//|   inline versions of the same logic, untouched in this pass.      |
//|   Risk Manager v23 - BUG-026 (continued): the v22 CalcLot DIAG   |
//|   Print() lines live in the Experts tab, which is easy to miss   |
//|   or confuse with the Journal tab (both were pasted back         |
//|   identically twice). This version adds the same diagnostic      |
//|   string directly on the chart via Comment() - always visible,   |
//|   no tab-hunting required - in addition to keeping the Print()   |
//|   log. No other behavior change from v22.                       |
//|   Risk Manager v22 - BUG-026 (continued): Diagnostic logging     |
//|   added to CalcLot(). The v21 fallback still produces oversized  |
//|   lots on Silver on this broker (confirmed: still fails with     |
//|   ERR_NOT_ENOUGH_MONEY even at 1% risk, ruling out a simple      |
//|   risk% scaling issue - the pval itself is wrong, just not       |
//|   NaN/zero, so the v21 guard doesn't catch it). This version     |
//|   adds an unconditional Print() at the top of CalcLot() logging  |
//|   the raw Digits, Point, AccountBalance, MODE_TICKVALUE,         |
//|   MODE_TICKSIZE, MODE_LOTSIZE, PipFactor(), the chosen pval, and |
//|   the resulting lot for every call - so the next Silver attempt  |
//|   reveals the actual broker-reported values instead of guessing. |
//|   No behavior change: CalcLot()'s calculation and return value   |
//|   are identical to v21, this only adds a diagnostic log line.    |
//|   Risk Manager v21 - BUG-026: CalcLot() Fails on CFD-Mode        |
//|   Symbols (e.g. Silver). Root cause: CalcLot() computed pip      |
//|   value as MODE_TICKVALUE/MODE_TICKSIZE*Point*PipFactor(),       |
//|   assuming both MarketInfo values are always valid/non-zero -    |
//|   true for Forex-mode symbols but not guaranteed for CFD-mode    |
//|   symbols. On the affected broker, Silver's MODE_TICKVALUE is    |
//|   0.000, which either zeroed pval (returning lot 0) or produced  |
//|   NaN on division - and MQL4's pval<=0 check does not catch NaN, |
//|   silently letting an invalid/oversized lot reach OrderSend()    |
//|   (consistent with the observed ERR_NOT_ENOUGH_MONEY). Fix:      |
//|   MODE_TICKVALUE and MODE_TICKSIZE are now validated             |
//|   individually before dividing; if either is invalid, pip value  |
//|   falls back to MarketInfo(MODE_LOTSIZE)*Point*PipFactor(), the  |
//|   standard CFD/commodity approach (profit = price-diff x         |
//|   contract size x lots, independent of tick-value/tick-size).    |
//|   An explicit pval!=pval NaN guard plus a >1e6 sanity ceiling    |
//|   now catch NaN/Inf regardless of which path computed pval. If   |
//|   pip value still can't be determined, CalcLot() returns 0 and   |
//|   fires Alert()+Print() so the trader is informed instead of a   |
//|   silent failure or corrupted order. No change to risk-amount    |
//|   or lot-rounding logic (rAmt, MathFloor/step, min/max clamping),|
//|   and XAUUSD (Forex-mode) lot calculation is byte-for-byte       |
//|   unchanged. GetTotalOpenRisk()'s per-order pip logic (BUG-024)  |
//|   is untouched - separate function, out of scope for this fix.  |
//|   Risk Manager v20 - BUG-024 + BUG-025: Multi-Symbol Risk/       |
//|   Drawdown Calculation Fixes. BUG-024: GetTotalOpenRisk() now    |
//|   computes pip distance and pip value from each order's OWN      |
//|   symbol (OrderSymbol() + MarketInfo) via new PipFactorForSymbol |
//|   helper, instead of the current chart's Symbol()/Point/Digits.  |
//|   Previously, viewing any chart other than an open order's own   |
//|   symbol produced meaningless Open Risk % (e.g. gold/crypto risk |
//|   computed using EURUSD's pip value). BUG-025: the day/week/     |
//|   month start-balance + start-time GlobalVariable keys (GV_DAY_  |
//|   START, GV_DAY_START_BAL, and the week/month equivalents) moved |
//|   from per-symbol (+Symbol()) to account-wide (+MagicNumber)     |
//|   namespacing, matching CalcNetResultPercent()'s existing        |
//|   account-wide (Magic-Number-only) scope for realized P/L. Both  |
//|   the start-time keys and the start-balance keys were moved      |
//|   together (not balance-only) - leaving the start-time key       |
//|   per-symbol would let a first-ever load on a second symbol's    |
//|   chart fail the "same period already started" check and         |
//|   silently reinitialize the shared balance, reproducing the same |
//|   chart-dependent drawdown bug this fix targets. Old per-symbol  |
//|   GV keys are simply abandoned (no migration needed - fresh      |
//|   values are captured under the new keys on first tick/OnInit).  |
//|   No other logic changed - lot calculation, order execution,     |
//|   Behavior Cooldown, Market Cooldown, Trade Snapshot system      |
//|   (BUG-021/022), Floating DD Emergency Close, and dashboard core |
//|   layout are all untouched.                                      |
//|   Risk Manager v19 - BUG-022: Market Cooldown Fractional         |
//|   Counting for Half Risk. New per-ticket Trade Snapshot field    |
//|   WasHalfRisk (same family as v18's MaxFavorableR/Striked) is    |
//|   captured once at open time from g_halfRiskActive - the EA's    |
//|   Full/Half Risk toggle state at that exact moment - and is      |
//|   never inferred later from risk % or lot size. g_mktStopCount   |
//|   is now a double instead of an int: on a stop-loss hit, tickets |
//|   whose Snapshot WasHalfRisk==true add 0.5 instead of the usual  |
//|   1.0. Tickets with no Snapshot (pre-v19 legacy) still add the   |
//|   full 1.0 (same conservative fallback philosophy as the rest    |
//|   of the Snapshot system - treat as Full Risk when unknown).     |
//|   MarketCDCount (still 3 by default) is unchanged as the trigger |
//|   threshold, just now compared against the fractional total.    |
//|   MarketCDResetHours (v13, BUG-017) and all other reset paths    |
//|   work unchanged against the fractional counter. The "Market CD: |
//|   X/3" dashboard box now formats X with one decimal when it's    |
//|   fractional. Half Close's remainder ticket inherits the         |
//|   original's WasHalfRisk, same as MaxFavorableR/Striked. No other|
//|   logic changed - lot calculation, order execution, Behavior     |
//|   Cooldown, Drawdown Protection, BUG-021's premature-action      |
//|   detection, and dashboard core layout are all untouched.        |
//|   Risk Manager v18 - BUG-021: Pre-1R Management Action Detection.|
//|   New per-ticket Trade Snapshot field MaxFavorableR tracks the   |
//|   highest R level genuinely touched since entry (basis: Initial  |
//|   Risk $, same as v17's oneR/reached1R), updated every tick and   |
//|   persisted via GlobalVariable. At the moment Break Even (manual  |
//|   or Auto), Trailing activation (manual or Auto trigger), Half    |
//|   Close, or any Manual Close (Full/Chart/Profit/Loss) is issued,  |
//|   if that ticket's MaxFavorableR has never reached +1R (0.95      |
//|   tolerance), one Behavior Cooldown strike is added. A second new |
//|   per-ticket Snapshot flag (Striked) caps this at ONE strike per  |
//|   trade - further premature actions on the same ticket (or its    |
//|   Half Close remainder) are logged only, no extra strike.         |
//|   Half Close's remainder ticket inherits the original's           |
//|   MaxFavorableR AND Striked flag so a later BE/Trailing on the    |
//|   remainder isn't misjudged as premature or double-punished.      |
//|   Plain manual SL nudges via the platform (not routed through any |
//|   of the 4 tracked actions) are never flagged, regardless of size.|
//|   Existing Cooldown classification (CheckClosedTrades, BUG-013/   |
//|   BUG-020) is untouched - this is an isolated addition on top.    |
//|   Risk Manager v17 - BUG-013 + BUG-020: CheckClosedTrades()      |
//|   classification (hit SL / reached +1R / Early Exit) no longer   |
//|   bases oneR/tolerance on the CURRENT SL distance (which shrinks |
//|   toward zero after Break Even or Trailing moves the stop near   |
//|   entry). Now uses the immutable Initial Risk ($) from each      |
//|   ticket's Trade Snapshot (v11). Falls back to the old SL-       |
//|   distance logic only if a ticket has no Snapshot (pre-v11       |
//|   trade). Cooldown lock thresholds (MarketCDCount/BehaviorCDCount)|
//|   are untouched - only the classification inputs changed.        |
//|   Carried over from v16: BUG-019 - Daily/Weekly/Monthly net       |
//|   result % and R calculations now include OrderSwap() and         |
//|   OrderCommission() alongside OrderProfit(), matching the         |
//|   Floating P/L box's existing formula. Spread needed no fix -    |
//|   OrderProfit() already reflects the real fill price.             |
//|   Carried over from v15: Advanced Close Management - the existing|
//|   Full Close button no longer closes everything directly. It     |
//|   now opens a 4-option temporary submenu (Close All / Close      |
//|   Chart Positions / Close Profitable / Close Losing) built from  |
//|   the same manual-object pattern as the rest of the panel. No    |
//|   new permanent dashboard button was added; Half Close stays a   |
//|   fully independent one-click action, untouched.                 |
//|   Carried over from v14: Advanced Break Even - new BreakEvenMode |
//|   input (Individual [default, unchanged] / BasketAverage). In    |
//|   BasketAverage, the existing Break Even button moves the SL of  |
//|   every same-direction, same-Magic, same-Symbol position ("a     |
//|   basket") to their shared lot-weighted average entry price,     |
//|   instead of each position's own entry. No new dashboard button. |
//|   Carried over from v13: BUG-017 Market Cooldown streak resets   |
//|   after a configurable time gap since the last SL close.         |
//|   Carried over from v12: Trailing Stop logic bug fix - SL only   |
//|   advances on a genuine new high/low beyond the last recorded    |
//|   extreme; each ticket's Trailing locks to its starting          |
//|   timeframe; dashboard rebuild throttled to once per second.     |
//|   Risk Manager v39 - Multiple Trailing Modes. New TrailingMode    |
//|   input (TRAIL_CANDLE [default, unchanged] / TRAIL_EMA) lets the  |
//|   existing Structure/Candle Trailing engine (v12/v13, untouched)  |
//|   run side-by-side with a new EMA Trailing path: SL follows the   |
//|   closed-bar EMA value (new TrailingEMAPeriod input, default 60)  |
//|   on the same per-ticket locked timeframe (g_trailPeriod[]) as    |
//|   Candle mode, still governed by the same never-move-backward and |
//|   broker Stop Level guards. Only the newSL calculation branches   |
//|   inside RunTrailingUpdate() - new-bar detection, ticket          |
//|   add/remove, OrderModify, and the trail line all stay shared.    |
//|   Dashboard Trail toggle and EnableAutoTrailing/                  |
//|   AutoTrailingTriggerRR behave identically for both modes; mode   |
//|   selection is Input-only, not a dashboard control. No change to  |
//|   Risk/Drawdown/Cooldown/RB, v29 color philosophy, v31 split,     |
//|   v32 Global Layout Scaling, trade execution logic, or any other  |
//|   Input.                                                          |
//|   Risk Manager v40 - Auto Half Close at Specific Reward           |
//|   (FEAT-019), replacing the removed Multi Target Engine. Same     |
//|   Reward-Based Automation pattern as Auto BE/Auto Trailing: new   |
//|   EnableAutoHalfClose / AutoHalfCloseTriggerRR / AutoHalfClose-    |
//|   Percent inputs. Core Half Close logic extracted (no behavior    |
//|   change) into HalfCloseTicket(ticket, percent, reasonTag) so the |
//|   manual button (still exactly 50%) and the new automatic trigger |
//|   (configurable percent) share one code path - nothing rewritten. |
//|   CheckAutoHalfCloseTrigger() mirrors CheckAutoTrailingTrigger()  |
//|   exactly; g_autoHalfDoneTickets (in-memory, same pattern as      |
//|   Trailing's tracking list) stops a ticket firing more than once, |
//|   and is also propagated to any remainder ticket MT4 creates so   |
//|   the split-off remainder can't re-trigger. BUG-021 (premature-   |
//|   action detection) applies automatically through the shared      |
//|   CheckPrematureAction() call inside HalfCloseTicket() - no       |
//|   special-casing needed; see v40 changelog for the RR<1 edge-case |
//|   analysis. BE, Trailing (both modes), manual close, and TP       |
//|   management all continue to operate normally on the remainder    |
//|   afterward - no new position-management system. No change to    |
//|   Risk/Drawdown/Cooldown/RB, v29 color philosophy, v31 split,     |
//|   v32 Global Layout Scaling, trade execution logic, existing      |
//|   Auto BE/Auto Trailing/either Trailing mode, or any other Input. |
//|   Risk Manager v80 - BUG-056 + FEAT-031 (v79 + minimal patch).    |
//|   BUG-056: Tag Trade window closed itself (looked "stuck") when   |
//|   the last Strategies were clicked - a click-outside geometry     |
//|   race, not a fixed-size array (see OnChartEvent). Strategy list  |
//|   replaced (6 strategies). Today's closed trades listed newest-   |
//|   first. FEAT-031: EnableAutoCloseAtHour + AutoCloseTime (broker  |
//|   time) closes all open positions once per day via FullClose().   |
//|   No change to Risk/Drawdown/Cooldown/sizing logic.               |
//|   Risk Manager v81 - FEAT-037 + FEAT-033.                         |
//|   FEAT-037: new, fully independent 5-checkbox Context Checklist   |
//|   step inserted into Tag Trade, between trade selection and       |
//|   Strategy (Strategy/Setup/Mental State steps renumbered, logic   |
//|   untouched). Own external editable file (RM_ContextChecklist.txt,|
//|   same seed/migration pattern as RM_StrategySetups.txt) and own   |
//|   independent CSV (RM_ContextTags.csv, ticket->5 booleans) - no   |
//|   dependency on the existing Tag Trade code. 5 new CSV journal    |
//|   columns. FEAT-033: KEY TIME (Session Windows/"SW") box display  |
//|   fully replaced with 14 full-height dashed vertical lines (8     |
//|   main + 6 sub), NY-time-based storage (via RM_SessionTime.mqh),  |
//|   broker-time labels, automatic near-chart-background color.      |
//|   No other module touched; both features independently scoped.   |
//|   Risk Manager v82 - BUG-052 + FEAT-036.                          |
//|   BUG-052: SL/TP classification (CheckClosedTrades,                |
//|   RM_CooldownEngine.mqh) was non-directional (|close-level|<=tol) -|
//|   a stop filled beyond its level with slippage was wrongly counted |
//|   as EarlyExit (+ a Behavior strike). Execution audit (account     |
//|   A4160750, Feb-Aug 2026, 273 trades): 84% of stops (109/130)      |
//|   filled beyond level with slippage, $2,978 real cost over 6       |
//|   months. Fix: directional - "at or beyond the level" = SL/TP;     |
//|   only the opposite (better-than-level) direction is excluded.     |
//|   Mirrored identically in ExportTradeJournalCSV's read-only Result |
//|   mirror (RM_Reports.mqh). FEAT-036: 8 new CSV journal columns -   |
//|   SL_Final/TP_Final, Slippage_USD/Slippage_R (signed vs. the level |
//|   that actually decided Result, positive=worse), CloseReason_Server|
//|   (dealer [sl]/[tp] comment tag), Spread_AtClose (captured live at |
//|   the moment CheckClosedTrades detects the close, persisted via    |
//|   GlobalVariable - MT4 history has no spread field), ServerHour_   |
//|   Close, IsEAManaged (has a valid Trade Snapshot). No change to    |
//|   trading logic, sizing, or AutoBE - registration only. Diff       |
//|   confined to RM_CooldownEngine.mqh (where CheckClosedTrades       |
//|   actually lives - the task brief named RM_TradeExecution.mqh,     |
//|   which held it prior to the Architecture Refactor) + RM_Reports.  |
//|   mqh. No other module touched.                                    |
//|   Risk Manager v83 - small batch: Daily H/L Open line position fix |
//|   + KEY TIME contrast increase (both in RM_Tools.mqh, independent  |
//|   of each other).                                                   |
//|   Open-line bug (reported 2026-08-20): the FEAT-032 (v79) Open line|
//|   used shift=0 (today's still-forming candle) while PDH/PDL/PDC all|
//|   use shift=1 (yesterday's completed candle) - the only actual     |
//|   code-level difference between Open and its siblings. Since this  |
//|   tool draws a closed box of YESTERDAY's range, an unrelated       |
//|   today's-open value inside that box is what read as "wrong        |
//|   position". Fix: shift changed to 1 (now genuinely Previous Day   |
//|   Open, matching PDH/PDL/PDC); label renamed "OPEN"->"PDO" to match|
//|   and to correctly describe the new value. HLine/HLineLabel calls, |
//|   price source pattern, and every other Daily/Weekly/Monthly H/L   |
//|   line untouched.                                                   |
//|   KEY TIME contrast: GetKeyTimeLineColor()'s blendPct raised        |
//|   12->17 (main) and 5->10 (sub) - both lines exactly 5 percentage  |
//|   points further from chart background, per Mahmoud's request.     |
//|   Background-luminance detection and blend-direction logic          |
//|   untouched - only these two numbers changed.                      |
//|   Diff confined to RM_Tools.mqh. No other module touched.          |
//|   Risk Manager v84 - FEAT-038 + fixed grey for R/R & Measure Move.|
//|   FEAT-038: Risk Toggle button is now a 4-step cycle Full -> 1/2 ->|
//|   1/4 -> 1/8 -> Full (was Full <-> Half). Fraction of the Full     |
//|   Risk input only, no free-form input / OBJ_EDIT. One shared      |
//|   GetActiveRiskPct() now feeds CalcLot in all 3 call sites (live  |
//|   preview, final labels, AutoExecute) - previously the Full/Half  |
//|   ternary was duplicated 3 times. Selected step persists across   |
//|   restarts via GlobalVariable (RM_RiskStep_A<acct>_M<magic>_<sym>)|
//|   - NOTE: the old Half Risk flag was never persisted. TradeR is   |
//|   unchanged: it divides by the per-ticket Snapshot RiskUSD (actual|
//|   lots x SL distance at open), so it is correct at every step.    |
//|   WasHalfRisk bool is kept as 'any reduced step' (step > 0).      |
//|   Fixed grey: R/R and Measure Move lines no longer follow bull/   |
//|   bear candle color; one grey with guaranteed luminance distance  |
//|   from the chart background. Session Level boxes keep their       |
//|   previous color via GetSessionLevelBoxColor().                   |
//|   Addendum: exact risk-step weight stored per ticket at entry     |
//|   (Snapshot RiskWeight 1/0.5/0.25/0.125); RB, Market Cooldown and |
//|   a new CSV column RiskStepWeight (appended last) read it via     |
//|   SnapRiskWeight(); pre-v84 tickets fall back to WasHalfRisk bool.|
//|   Risk Manager v90 - FEAT-044 phase 1: Scale-in (continuation     |
//|   entry, Mode 1). New "Scale-in" row above MARKET/PENDING. Entry |
//|   risk = max(0, root RiskUSD - signed live open risk of chain);   |
//|   Full/Half button ignored while ON. Entry joins the chain via    |
//|   RootTicket (Snapshot: IsContinuation, RiskBaseUSD). Exempt from |
//|   Entry-Interval strike, EarlyExit strike, g_lastEntryTime.       |
//|   RiskWeight = entry risk / Full risk. Chain Market Cooldown uses |
//|   the explicit ROOT Snapshot. History box uses root entry price.  |
//|   See CHANGELOG_v90_FEAT044_Phase1.md.                            |
//|                                                                    |
//|   Risk Manager v89 - History boxes per CHAIN: one TP box + one SL  |
//|   box per root ticket, from the mother's open time to the close of |
//|   the LAST part; chains with an open part are drawn once fully     |
//|   closed. Diff: RM_Tools.mqh (History_Build) + this file.          |
//|                                                                    |
//|   Risk Manager v88 - BUG-058: CheckClosedTrades re-selects the     |
//|   closed ticket after TakeExitScreenshot (which left another open  |
//|   order selected => wrong close price / profit / TP => SL stops    |
//|   classified as TP/+1R). One-line fix in RM_CooldownEngine.mqh.    |
//|                                                                    |
//|   Risk Manager v87 - FEAT-042 phase 2: chain-based statistics     |
//|   Trading Reports (CalcTradingReportStats) group history by       |
//|   RootTicket: a Half Close chain = ONE trade, counted only after   |
//|   IsChainFullyClosed(root), win/loss by net sum, R = sum of parts. |
//|   Market Cooldown: multi-ticket chains are evaluated once when the |
//|   chain is fully closed: net R < -0.1R => +min(1,|R|) x RiskWeight;|
//|   single trades keep the price-based hitSL rule. Behavior/EarlyExit|
//|   stay per ticket. RefreshChainRootKeys() daily (GV 4-week expiry).|
//|   Diff: RM_Snapshot/RM_Reports/RM_CooldownEngine + this file.      |
//|                                                                    |
//|   Risk Manager v86 - FEAT-042 phase 1: RootTicket + tags from root |
//|   Snapshot field RootTicket (GV RM_SNAP_ROOT_<ticket>): new trade  |
//|   = own ticket; Half Close remainder inherits the root, so chains  |
//|   of any length share the FIRST ticket. FindTagIndex /            |
//|   FindCtxTagIndex read the root (legacy child tags as fallback),   |
//|   SetTradeTag / SetContextTag write the root => tags + context     |
//|   checklist follow the whole chain, also if set after Half Close.  |
//|   New CSV column RootTicket (last). Remainder-not-found now logged.|
//|   No report/cooldown number changes (phases 2-3 later).            |
//|   Diff: this file + RM_Snapshot/RM_TradeExecution/RM_Tools/        |
//|   RM_Reports. Hub unchanged (v1.15).                               |
//|                                                                    |
//|   Risk Manager v85 - History button (Utility), batch with Hub v1.15|
//|   History: BE REF LINE button halved; new toggle HISTORY draws two|
//|   filled boxes per closed trade of the last HistoryDaysBack days   |
//|   (input, default 7): entry->TP light, entry->SL dark, spanning    |
//|   OpenTime->CloseTime. Colours follow chart background luminance.  |
//|   v85 diff: this file + RM_Config/RM_Dashboard/RM_Tools.         |
//|   (v84 diff, kept for reference:) this file + RM_RiskCalc/        |
//|   RM_TradeExecution/RM_Dashboard/                                 |
//|   RM_Tools/RM_Snapshot/RM_CooldownEngine/RM_Reports.              |
//|   v95: BUG-059 - candle timer/session vertical sync throttled + SLOWSTEP diag. v94: UpdateRiskDisplay redraws only when its text changes (BUG-059).|
//|   v93: + per-section OnTick breakdown ([RM-PERF] TICK BREAKDOWN). |
//|   v106: FEAT-047 Key Time line intensity input; BUG-062 Measure   |
//|   Move uses the owner's own Fibo levels (thin solid, click order);|
//|   STRAT-LIST new strategy/setup default list. See CHANGELOG_v106.md|
//|   v102: Shared settings across charts (Publish Settings input) + |
//|   account-wide Daily/Weekly/Monthly locks + account-wide Market/ |
//|   Behavior lock end + Floating DD/Emergency Close on all symbols.|
//|   Period starts (day/week/month) now server-time based, not per-symbol. |
//|   See CHANGELOG_v102_SharedSettings.md.                          |
//|   v101: BUG-054/055/057 + tag-state family - multi-instance     |
//|   (same-symbol / multi-chart) shared-state audit and fix. Exactly-|
//|   once close processing via an atomic per-ticket claim (GV mutex +|
//|   GlobalVariableSetOnCondition); Snapshot/Half-Exempt/AutoHalf/   |
//|   tamper flags/cooldown lock-ends/tag files now shared across     |
//|   instances; [RM-MI] diagnostic log lines. Risk/Cooldown/Reports  |
//|   rules, MagicNumber and CSV column order untouched. See          |
//|   CHANGELOG_v101_BUG054_MultiInstance.md.                         |
//|   v92: DIAGNOSTIC build - [RM-PERF] timing log every 10s (lag     |
//|   investigation, BUG-059). No behavior change.                     |
//|   v91: (1) Scale-in Market lot from real fill price (Ask/Bid);    |
//|   (2) removed noisy diagnostic Prints ([ST-DIAG] box, OnTimer     |
//|   interval). v90.1: orphan Scale-in pendings auto-cancelled.       |
//|   MagicNumber and base sizing untouched.                          |
//+------------------------------------------------------------------+
#property copyright "Risk Manager EA"
#property version   "106.00"
// v45 (Punch List Round 3, Item 7): custom icon embedded straight into the compiled .ex4 - shows
// up in the Navigator panel and the Properties/About dialog. RiskManager.ico must sit next to this
// .mq4 at compile time only; after that it's baked into the .ex4, no external file needed at runtime.
#property icon "RiskManager.ico"
#property description "A discipline enforcement engine, not a predictive tool."
#property description "Focuses on what can be controlled: risk, behavior, execution."
#property description "1. Mathematical: sizing, capital preservation, D/W/M limits, Emergency Stop."
#property description "2. Behavioral: Market & Behavior Cooldown, disciplined execution."
#property description "3. Execution: minimize friction, simplify decisions, reduce errors."
#property description "Survive long enough to let your edge work."
#property description "Developed by Mahmoud Seyedi"
#property strict

// v45 (Punch List Round 3, Item 8): سه فایل صوتی داخل خود .ex4 جاسازی می‌شن (به‌جای خوندن از
// MQL4/Sounds در لحظه‌ی اجرا) - روی هر نصب/بروکر جدید بدون کپی دستی کار می‌کنه. PlaySound() باید
// با پیشوند "::" صدا زده بشه تا از منبع جاسازی‌شده بخونه، نه از دیسک.
#resource "\\Sounds\\order_filled.wav"
#resource "\\Sounds\\stop_loss.wav"
#resource "\\Sounds\\target_reached.wav"

#include "RM_Config.mqh"
// R8 (Architecture Refactor, Final Phase): RM_Common.mqh باید بلافاصله بعد از RM_Config.mqh
// include بشه، نه قبلش - چون HLine/HLineLabel/GetBasketAveragePrice/BELineName/
// BasketAvgLineName (توابع مشترک بین چند ماژول که به RM_Common.mqh منتقل شدن) به MagicNumber
// (تعریف‌شده در RM_Config.mqh) وابسته‌ن.
#include "RM_Common.mqh"

// v78 (بازنویسیِ Session Tools): ماژولِ مشترکِ زمانِ سشن (DST/NY->server + آفستِ
// پایدار). همان فایلِ canonicalِ byte-identical که Executive Hub هم استفاده می‌کند.
// اینجا (قبل از RM_Tools که مصرف‌کننده است) include می‌شود تا توابعِ ST_* در دسترس باشند.
#include "RM_SessionTime.mqh"


// v38 (Input restructure, Part 3.2): این‌ها هیچ‌وقت قرار نبود در طول اجرای واقعی تغییر کنن -
// از Input به ثابت تبدیل شدن تا از دیالوگ Inputs حذف بشن (تنها راه غیرقابل‌ویرایش‌کردن در MQL4)
const int PanelX   = 15;  // Panel horizontal offset from corner (pixels)
const int PanelY   = 25;  // Panel vertical offset from corner (pixels)
const int Slippage = 3;   // Max allowed slippage (points)

// v38 (BUG-023): نسخه‌ی effective/کلمپ‌شده‌ی هر کدوم از Input های ریسک - توسط ApplyRiskCeilings()
// (از OnInit) پر می‌شن؛ همه‌ی محاسبات/چک‌ها از این متغیرها استفاده می‌کنن، نه از Input خام.
double g_effRiskPerTrade  = 0;
double g_effMaxTotalRisk  = 0;
double g_effMaxDailyRisk  = 0;
double g_effMaxWeeklyDD   = 0;
double g_effMaxMonthlyDD  = 0;

enum EStep { STEP_IDLE, STEP_ENTRY, STEP_SL };
enum EMode { MODE_MARKET, MODE_PENDING };
enum EDashboardMode { DASH_TRADING, DASH_UTILITY };  // v31: renamed from DASH_FULL/DASH_COMPACT (Dashboard Architecture: Trading + Utility Split) - ordinal values unchanged (0/1), so GV_DASH_MODE persistence needs no migration

EStep   g_step       = STEP_IDLE;
EMode   g_mode       = MODE_MARKET;
double  g_entryPrice = 0;
double  g_slPrice    = 0;
double  g_tpPrice    = 0;
bool    g_isBuy      = true;
bool    g_minimized  = false;
EDashboardMode g_dashboardMode = DASH_TRADING;  // v104: پیش‌فرض Trading (قبلاً DASH_UTILITY) -  // v31: default on first load = Utility (renamed from DASH_COMPACT, same default behavior)
bool    g_fullCloseMenuOpen = false;  // v15 (Advanced Close Management): وضعیت باز/بسته‌بودن زیرمنوی Full Close
bool    g_halfCloseMenuOpen = false;  // v37 PART B: وضعیت باز/بسته‌بودن پنجره‌ی تأیید Half Close

// === v30 (Button Click Feedback): BE / Half Close / Full Close one-shot flash state ===
// GetTickCount()-based deadline per button (0 = not flashing). Independent per button so clicking
// one doesn't affect another's timing, even if two are clicked within the same 5-second window.
// Driven by the existing OnTimer() (1 Hz, already used for the v26 Candle Timer) - no second timer
// system added, per spec.
uint    g_beFlashEnd   = 0;
uint    g_halfFlashEnd = 0;
uint    g_fullFlashEnd = 0;
uint    g_exportFlashEnd = 0;  // v60 (EXPORT CSV Feedback): همون الگوی flash بالا، اما با رنگ CLR_TOOLS_ACTIVE (فیروزه‌ای) به‌جای رنگ اختصاصی، چون این دکمه Action است نه یه دکمه‌ی خطرناک/متمایز مثل BE/Half/Full
#define BTN_FLASH_MS    5000
#define CLR_BTN_DEFAULT C'70,70,80'     // resting grey - matches every other one-shot action button
#define CLR_TOOLS_ACTIVE C'0,150,150'   // v42 (Punch List, Item 1.4): the same active teal already used by Auto Trail/Candle Timer/BE Ref Line/Daily-Weekly-Monthly H-L - Show Objects and the two Fibo tools now match it too
#define CLR_FLASH_BE    C'150,80,200'   // purple - distinct from blue(Market)/orange(Pending)/teal(Trail)/red(danger)
#define CLR_FLASH_HALF  C'210,175,20'   // gold - distinct from CLR_APPROACHING(orange) and Pending's orange
#define CLR_FLASH_FULL  C'200,60,140'   // magenta - distinct from the submenu's red/green Close options
int     g_statusBoxTop = 0;   // v2: موقعیت بالای کادر وضعیت - برای وسط‌چین کردن پویا متن Ready
datetime g_actionMsgUntil = 0; // v8 (BUG-011): تا این لحظه پیام اکشن لحظه‌ای روی نوار وضعیت می‌مونه؛ بعدش UpdateSystemStatus() وضعیت دائمی رو جایگزین می‌کنه
#define  ACTION_MSG_SECONDS 4  // v8 (BUG-011): مدت نمایش پیام اکشن قبل از برگشت خودکار به وضعیت دائمی (ثانیه)
bool    g_halfRiskActive = false;  // v9.6: حالت Risk Toggle (Full/Half) - تا کلیک بعدی پایدار می‌مونه
// v84 (FEAT-038): منبع حقیقت پله‌ی ریسک: 0=Full, 1=1/2, 2=1/4, 3=1/8. g_halfRiskActive حالا فقط مشتق (step>0) است
// و فقط برای مصرف‌کننده‌های قدیمی Snapshot (WasHalfRisk) نگه داشته شده؛ فقط SetRiskStep() مقدارش رو می‌نویسه.
int     g_riskStep = 0;
// v90 (FEAT-044 فاز ۱ - Scale-in): وضعیت دکمه‌ی Scale-in (یک‌بارمصرف، پایدار نیست) و فهرست زنجیره‌های مجاز (آرایه‌های هم‌ایندکس، توسط BuildScaleInCandidates پر می‌شن).
bool    g_scaleInOn   = false;
int     g_scaleInRoot = 0;
int     g_scCandRoot[];
double  g_scCandCap[];
bool    g_scCandBuy[];
double  g_scCandEntry[];
bool    g_scaleInPickerOpen = false;   // پنجره‌ی انتخاب زنجیره (وقتی ۲+ زنجیره‌ی مجاز) باز است؟
double  g_riskReward = 2.0;        // v9.7: مقدار زنده‌ی RR - از روی دکمه قابل تغییره (مقدار اولیه از Input میاد)
datetime g_dayStart  = 0;

// === v27: Dashboard Layout Restructuring (Performance drawer) ===
bool    g_perfDrawerOpen = true;   // expand/collapse state of the "📊 Performance" box - intentionally NOT persisted, but unlike Tools it defaults to OPEN on every EA attach (per spec: important enough to be visible at a glance)

// === v28 (Dashboard Visual Polish Part 1) ===
// Change 7: remembers whether the Performance box was open right before the Close submenu forced
// it collapsed, so it can be restored (and ONLY restored if it was actually open) once the
// submenu closes again - collapsing it must never force it open if the trader had it collapsed.
bool    g_perfWasOpenBeforeSubmenu = false;
// Change 6: top-left anchor of the row the Close button sits on (Full Close/Trailing row in FULL,
// the 4-button action row in COMPACT) - captured live in BuildPanel() and reused by
// OpenFullCloseMenu() to position the 2x2 grid without duplicating the layout math.
int     g_closeMenuAnchorX = 0;
int     g_closeMenuAnchorY = 0;
int     g_closeMenuAnchorW = 0;
int     g_halfCloseMenuAnchorX = 0;  // v37 PART B
int     g_halfCloseMenuAnchorY = 0;
int     g_halfCloseMenuAnchorW = 0;




// === v35 (Utility Phase A, Part 2): "Trading Reports" drawer - second collapsible module on the
// Utility dashboard, lives below the Tools drawer. Collapsed by default like Tools (not persisted,
// resets on every EA restart - no persistence requirement was given). g_reportsPeriod selects which
// of the three tabs (Daily/Weekly/Monthly) is currently displayed - also session-only, defaults to
// Daily (0) on every restart/attach, same as the Tools sub-toggles.
bool     g_reportsDrawerOpen = false;
int      g_reportsPeriod     = 0;   // 0=Daily, 1=Weekly, 2=Monthly

// === Cooldown System ===
// Market Cooldown
double   g_mktStopCount  = 0;        // consecutive stops (v19, BUG-022: fractional - Half Risk stops add 0.5 instead of 1.0)
datetime g_mktCooldownEnd = 0;        // lock end time
datetime g_lastStopCloseTime = 0;    // v13 (BUG-017): close time of the last SL-hit trade, used for time-based streak reset

// Behavior Cooldown
int      g_behCount      = 0;        // early closes count
datetime g_behCooldownEnd = 0;        // lock end time

// === v9.3: Entry interval tracking ===
datetime g_lastEntryTime = 0;


// === v7 (FEAT-002): وضعیت Trailing Stop ===
// v42 (Punch List, Part 5)/R7: بقیه‌ی state این بخش (g_trailingButtonOn/g_trailTickets/
// g_trailExtreme/g_trailPeriod/g_trailLastBar) به RM_Trailing.mqh منتقل شد. g_trailCount عمداً
// اینجا موند - چون OnChartEvent (همین فایل، دائمی) مستقیم بهش دسترسی داره (ریست دستی
// g_trailCount=0 توی منوی Full Close) - طبق grep تأیید و در Parking Lot این فاز مستند شده.
int      g_trailCount        = 0;
datetime g_panelLastRebuild  = 0;      // v13 (فیکس فلش زدن): جلوگیری از rebuild بیش‌ازحد مکرر پنل روی CHARTEVENT_CHART_CHANGE

// === Drawdown Protection ===
datetime g_dailyLockEnd   = 0;  // v51 (Parking Lot #1): قفل واقعی/persisted روزانه - هم‌الگوی g_weeklyLockEnd/g_monthlyLockEnd
datetime g_weeklyLockEnd  = 0;
datetime g_monthlyLockEnd = 0;
datetime g_weekStart      = 0;
datetime g_monthStart     = 0;
// v72 (URGENT bugfix - false Weekly/Monthly DD lock on real-account restart): لحظه‌ی شروع
// OnInit() - مبنای پنجره‌ی Grace Period (StartupGracePeriodSeconds در RM_Config.mqh). فقط برای
// جلوگیری از ست‌شدن قفل جدید در همون پنجره استفاده می‌شه؛ محاسبه/نمایش dd% دست‌نخورده می‌مونه و
// قفل‌های از قبل فعال (بارگذاری‌شده توسط LoadDrawdownState) اصلاً به این global وابسته نیستن.
datetime g_eaStartupTime  = 0;

// v77 (URGENT bugfix - Pattern A): زمان/تیک آخرین چرخه‌ی CheckDrawdownLimits(). برای تشخیص «وقفه‌ی
// غیرعادی بین دو محاسبه‌ی متوالی» (خواب طولانی/reconnect بدون OnInit) استفاده می‌شن - اگه فاصله از
// LongGapGraceThresholdSeconds بیشتر شد، همون پنجره‌ی Grace بعد از OnInit دوباره باز می‌شه. هر دو
// کلاک نگه داشته می‌شن: g_lastDDCheckMs (GetTickCount - همون کلاکی که وقفه‌ی ~۹ساعته‌ی این حادثه رو
// ثبت کرد) و g_lastDDCheckTime (TimeCurrent - برای گیرانداختن replayِ تیک‌های قدیمی موقع reconnect).
uint     g_lastDDCheckMs   = 0;
datetime g_lastDDCheckTime = 0;

// === v10 (BUG-012): بالانس شروع هر دوره - مبنای محاسبه‌ی نتیجه‌ی خالص واقعی% ===
// AccountBalance() لحظه‌ای نیست؛ فقط در شروع دوره یا هنگام بارگذاری EA (اگه دوره عوض شده باشه) مقداردهی می‌شه
double   g_dayStartBalance   = 0;
double   g_weekStartBalance  = 0;
double   g_monthStartBalance = 0;

// v64 (آیتم ۱ - PriorDayResult): نتیجه‌ی خالص روز معاملاتیِ *قبل* (Win/Loss/Breakeven)، برای
// الگوهایی مثل «تهاجمی‌تر شدن بعد از یه روز خوب». برخلاف g_dayStart/g_dayStartBalance بالا که هر
// روز overwrite می‌شن، این یکی «نتیجه‌ی روز قبل از ریست» رو نگه می‌داره - محاسبه‌اش باید *قبل* از
// overwrite شدن g_dayStart/g_dayStartBalance در OnTick انجام بشه (وگرنه مبنای محاسبه از دست می‌ره).
// کدگذاری: -2 = هنوز محاسبه نشده (N/A - قبل از اولین day-reset)، -1 = Loss، 0 = Breakeven، 1 = Win.
// حساب‌محور و persisted (نه symbol-specific) - GV_PRIOR_DAY_RESULT پایین.
double   g_priorDayResultCode = -2.0;

// === v9.5: Floating Drawdown Protection ===
bool     g_floatingDDTriggered = false;  // جلوگیری از Alert تکراری تا وقتی فلوتینگ از حد خارج بمونه

// v25 (BUG-030 fix): همون Scope که BUG-029 برای شش کلید START/START_BAL اضافه کرد، اینجا هم لازم
// بود ولی جا افتاده بود. این دو کلید وضعیت "قفل فعاله یا نه، تا کِی" رو نگه می‌دارن؛ چون فقط با
// Symbol() اسکوپ شده بودن (نه AccountNumber/MagicNumber)، یک قفلی که روی یک حساب (مثلاً حساب
// cent-real، قبل از فیکس BUG-025/029) فعال شده بود، با هر حساب دیگه‌ای که همون نماد رو روی همین
// ترمینال ترید می‌کرد به اشتراک گذاشته می‌شد - حتی بعد از فیکس BUG-029 (که فقط مخرج Drawdown% رو
// درست کرد، نه خودِ فلگ قفل). فیکس: همون AccountNumber()+MagicNumber که BUG-029 اضافه کرد، اینجا
// هم قبل از Symbol() اضافه شد؛ Symbol() به‌عنوان لایه‌ی per-symbol موجود حذف نشد، فقط دو لایه‌ی
// جدید جلوش اضافه شدن - دقیقاً همون الگوی BUG-029.
// v51 (Parking Lot #1): GV_DAILY_END - دقیقاً همون convention scoping بالا (AccountNumber+MagicNumber+Symbol)
// v77 (Pattern B fix): مقداردهیِ این کلیدهای حساب‌محور از اینجا به BuildAccountScopedKeys() منتقل شد
// (پایینِ فایل، صدا زده‌شده اولِ OnInit). فرمتِ کلید *فقط* اونجا زندگی می‌کنه (تک‌منبع). دلیل: این
// رشته‌ها فقط یک‌بار موقع لود ساخته می‌شدن و بعد از سوییچ حساب داخل ترمینال کهنه می‌موندن → قفل کاذبِ DD.
string GV_DAILY_END    = "";
string GV_WEEKLY_END   = "";
string GV_MONTHLY_END  = "";

// === v10 (BUG-012): کلیدهای ذخیره‌سازی بالانس/زمان شروع دوره - تا بعد از ری‌استارت EA از دست نره ===
// v20 (BUG-025 fix): کلیدها از per-symbol (+ Symbol()) به account-wide (+ MagicNumber) تغییر کردن.
// CalcNetResultPercent() (صورت‌کسر - سود/ضرر واقعی‌شده) از قبل کل حساب رو بر اساس MagicNumber
// حساب می‌کرد؛ ولی این کلیدها (مخرج - بالانس/زمان شروع دوره) per-symbol بودن. نتیجه: هر چارت نماد
// جدید، مخرج جدا و chart-dependent می‌ساخت. حالا هر دو یک namespace مشترک دارن.
// v25 (BUG-029 fix): یک سطح Scope دیگه اضافه شد - AccountNumber(). GlobalVariableهای MT4 به کل
// ترمینال محدودن، نه به یک حساب مشخص؛ پس وقتی دو حساب متفاوت (مثلاً یک حساب cent-real و یک دمو
// تازه) با همون Magic Number روی یک ترمینال اجرا می‌شن، هر دو دقیقاً همون کلیدهای MagicNumber-only
// رو می‌خوندن/می‌نوشتن - بالانس شروع دوره‌ی یک حساب، مخرج Drawdown% حساب دیگه می‌شد و باعث قفل
// کاذب فوری می‌شد. فرمت کلید حالا RM_..._A<AccountNumber>_M<MagicNumber> - همون الگوی خودِ BUG-025
// (رفتن از Scope خیلی محدود به Scope درست)، فقط یک لایه‌ی دیگه. کلیدهای قدیمی (بدون AccountNumber)
// به‌سادگی رها می‌شن - بدون migration دستی؛ اولین اجرای هر حساب با فرمت جدید، بالانس شروع درست
// خودش رو تازه ثبت می‌کنه. منطق reset (زمان‌محور) کاملاً دست‌نخورده - فقط خودِ کلیدها Scope عوض کردن.
// v77 (Pattern B fix): مقداردهی به BuildAccountScopedKeys() منتقل شد (تک‌منبع؛ rebuild در هر OnInit).
string GV_DAY_START       = "";
string GV_DAY_START_BAL   = "";
string GV_WEEK_START      = "";
string GV_WEEK_START_BAL  = "";
string GV_MONTH_START     = "";
string GV_MONTH_START_BAL = "";

// v64 (آیتم ۱ - PriorDayResult): همون convention حساب‌محور بالا (بدون Symbol - طبق درخواست صریح
// تسک: "حساب‌محور و persisted، نه symbol-specific").
string GV_PRIOR_DAY_RESULT = "";  // v77 (Pattern B fix): ساخته‌شده در BuildAccountScopedKeys()
// v80 (FEAT-031): تاریخِ (yyyymmdd، وقت سرور) آخرین روزی که Auto Close At Time اجرا شده - حساب‌محور
// (account+magic، بدون Symbol) چون FullClose() هم روی کل حساب/مجیک کار می‌کنه.
string GV_AUTOCLOSE_DAY    = "";  // v80 (FEAT-031): ساخته‌شده در BuildAccountScopedKeys()
string GV_RISK_STEP        = "";  // v84 (FEAT-038): پله‌ی ریسک (0..3) - ساخته‌شده در BuildAccountScopedKeys()

// v77 (Pattern B investigation - TEMPORARY diagnostic, remove after root cause confirmed): استخراج
// شماره‌حسابی که داخل یه کلید حساب‌محور جاسازی شده (فرمت "..._A<digits>_M<digits>..."). اگه پیدا نشد
// -1 برمی‌گردونه. صرفاً برای مقایسه با AccountNumber() زنده - هیچ رفتاری تغییر نمی‌ده.
long GVKeyAccount(string key)
{
   int a = StringFind(key, "_A");
   if(a < 0) return -1;
   a += 2;
   int m = StringFind(key, "_M", a);
   if(m < 0) return -1;
   return StringToInteger(StringSubstr(key, a, m - a));
}

// v77 (Pattern B investigation - TEMPORARY diagnostic): فرضیه‌ی ریشه - رشته‌های کلید حساب‌محور
// (GV_MONTH_START_BAL و بقیه) فقط یک‌بار موقع لود برنامه با AccountNumber() ساخته می‌شن؛ اگه سوییچ
// حساب داخل همون ترمینال باعث نشه این رشته‌های global دوباره ارزیابی بشن، کلید به حسابِ *قبلی* اشاره
// می‌کنه و مقدار حساب فعلی زیر کلید حساب دیگه نوشته/خونده می‌شه (دقیقاً رگرسیونِ همون BUG-029). این
// تابع فقط وقتی چیزی چاپ می‌کنه که واقعاً mismatch باشه - پس هر خطی که چاپ بشه، خودش سند مستقیمه.
void PatternBDiag(string where)
{
   long keyAcc = GVKeyAccount(GV_MONTH_START_BAL);

   // (1) همیشه یه خط context جمع‌وجور - چون همه‌ی این نقطه‌ها کم‌فرکانس‌ان (OnInit + مرزهای دوره،
   // نه هر تیک). این خط هر دو جهتِ فرضیه‌ی تسک رو پوشش می‌ده:
   //  - جهت «کلید کهنه»: keyAcc (شماره‌حساب داخل کلید) با AccountNumber() زنده فرق کنه.
   //  - جهت «مقدار کهنه»: کلید درست باشه ولی AccountBalance() زنده مقدار حسابِ دیگه رو برگردونه
   //    (مثلاً بعد از reconnect/سوییچ حساب)، که اون‌وقت g_monthStartBalance با AccountBalance() نمی‌خونه.
   Print("RM v77 PatternB ctx @", where, ": liveAcc=", AccountNumber(), " keyAcc=", keyAcc,
         " AccountBalance=", DoubleToStr(AccountBalance(),2), " AccountEquity=", DoubleToStr(AccountEquity(),2),
         " g_monthStartBal=", DoubleToStr(g_monthStartBalance,2), " key='", GV_MONTH_START_BAL, "'");

   // (2) اگه واقعاً کلید کهنه بود، یه خط بلندِ راحت‌گرپ - خودش سند مستقیمِ جهتِ «کلید کهنه»ست.
   if(keyAcc != (long)AccountNumber())
      Print("RM v77 PATTERN-B SMOKING GUN @", where, ": live AccountNumber()=", AccountNumber(),
            " but GV key embeds account ", keyAcc,
            " -> account-scoped GV strings are STALE (not re-evaluated after in-terminal account switch)");
}


// === v9.3: Half Close @ TP1+ exemption list (Behavior Cooldown) ===
int      g_halfExemptTickets[];
int      g_halfExemptCount = 0;



// v43 (Item 4): uniform top-margin/gap/gap/bottom-margin spacing unit for the 3 alert-box lines
// (Status, Open Risk, Floating) - previously the box was an exact-fit stack with zero margin at
// the top and an ad-hoc SC(2) nudge on just one gap (v42), so the three lines weren't evenly
// spaced and the top/bottom padding didn't match. ALERT_H now includes room for this on both ends
// plus both inter-line gaps (4x ALERT_PAD total), so all four spacings are equal by construction.
int ALERT_PAD;


// v29 (Part 3 - Panel-wide color philosophy): shared constants for the 3-state informational
// coloring rule. Elements with a real forbidden zone (a limit that can warn or lock) cycle
// grey (normal) -> orange (approaching the limit) -> red (limit reached/locked). Elements with
// no forbidden zone stay permanently grey (CLR_NEUTRAL) regardless of sign. This is a distinct
// mechanism from the existing toggle/selection coloring (FULL/COMPACT, MARKET/PENDING, BE/Half
// Close/Full Close/Trailing, Close submenu), which is untouched by this version.
#define CLR_NEUTRAL      C'190,190,195'   // grey - normal, no forbidden zone, or zone not yet approached
#define CLR_APPROACHING  clrOrange        // orange - approaching the forbidden zone
#define CLR_BREACHED     clrRed           // red - forbidden zone reached / locked
#define WARN_RATIO       0.85             // fraction of the limit at which "approaching" (orange) begins

// v29 revision 3 (Mahmoud feedback - Risk/RR are SETTINGS, not actions): the previous revision's
// whole-button "glow" (bright BGCOLOR fill) was still too attention-grabbing for two buttons that
// just reflect a configuration value. Both now stay within the panel's dark grey palette at all
// times - state is carried mainly by a subtle BORDER_COLOR accent, with only a small, muted shift
// in the button's own background brightness alongside it. Nothing here ever reaches a bright/neon
// hue - Market/Pending, Break Even, Half Close, Full Close etc. remain the only true "action"
// colors on the panel.
#define RISK_BG_FULL      C'55,55,62'    // Full Risk - dark grey button
#define RISK_BORDER_FULL  C'120,45,45'   // Full Risk - thin, subtle dark red border
#define RISK_BG_HALF      C'85,85,95'    // Half Risk - slightly lighter grey button
#define RISK_BORDER_HALF  C'195,60,60'   // Half Risk - slightly brighter (still muted) red border
// v84 (FEAT-038): ادامه‌ی همان پلکان - هر پله‌ی کم‌ریسک‌تر کمی روشن‌تر از قبلی (همان فلسفه‌ی v29)
#define RISK_BG_Q4        C'100,100,112' // 1/4 Risk
#define RISK_BORDER_Q4    C'215,80,80'
#define RISK_BG_Q8        C'115,115,130' // 1/8 Risk
#define RISK_BORDER_Q8    C'235,105,105'

// RR: background and border each ramp across 5 steps (RR 1-5). Background stays capped in the
// grey palette (never white); the border is allowed to travel further, up to a near-white accent
// at RR5, so most of the visual progression is carried by the border rather than the fill -
// keeps the button surface calm while still making the level readable at a glance. The whole
// scale sits roughly one shade darker than the previous "glow" revision.
#define RR_BG_LO_R 55
#define RR_BG_LO_G 55
#define RR_BG_LO_B 62
#define RR_BG_HI_R 140
#define RR_BG_HI_G 140
#define RR_BG_HI_B 150
#define RR_BORDER_LO_R 65
#define RR_BORDER_LO_G 65
#define RR_BORDER_LO_B 75
#define RR_BORDER_HI_R 235
#define RR_BORDER_HI_G 235
#define RR_BORDER_HI_B 240
// Market/Pending are the panel's primary action buttons - kept ~2-3 brightness levels lighter
// than the rest of the grey controls (C'70,70,80') so they naturally attract the eye without
// needing an accent color while inactive. Accent colors (blue/orange) still apply when selected.
#define MP_BASE_GREY     C'142,142,158'  // v30 (Part 2): brightened further from v29's C'105,105,118' - Mahmoud found that still not visible enough at a glance; selected-state blue/orange accents (C'30,130,220'/C'190,140,0') are unchanged


#define PERF_MONO_CHAR_RATIO 0.78  // v36: نسبت پهنای مونواسپیس (Consolas) به فونت‌سایز - از نسبت
                                    // 0.62 مخصوص Arial که FitBoxFontHalf() استفاده می‌کنه پهن‌تره
#define ARIALBOLD_CHAR_RATIO 0.68  // v44 (Punch List Round 2, Item 1): دکمه‌های پنل (BtnC) همه از
                                    // "Arial Bold" استفاده می‌کنن که از Arial معمولی (نسبت 0.62 که
                                    // FitBoxFontHalf برایش تنظیم شده) پهن‌تره - همون منطق تفکیک نسبت
                                    // به‌ازای فونت که PERF_MONO_CHAR_RATIO بالا برای Consolas داره.
// v45 (Punch List Round 3, Item 6): سه‌ لایه‌ی Z-order برای کل پنل - نه فقط یه عدد بزرگ روی
// پس‌زمینه. اگه فقط پس‌زمینه (BG/TITLEBAR/...) بالا برده بشه، طبق همون قاعده‌ی
// "Z-order بالاتر = برنده‌ی کلیک" که کامنت BUG-031 پایین‌تر توضیح می‌ده، پس‌زمینه
// جلوی کلیک خود دکمه‌ها/لیبل‌های روش رو هم می‌گیره - دقیقاً عکس هدف. پس هر سه لایه با هم،
// با همون فاصله‌ی نسبی قبلی (BUG-031: دکمه بالاتر از لیبل روش) ولی روی یه پایه‌ی مشترک خیلی
// بزرگ‌تر از صفر (پیش‌فرض هر آبجکت دیگه‌ای روی چارت) بالا برده می‌شن:
//   BG (پس‌زمینه/کانتینر)  <  FG (دکمه‌ها و لیبل‌های معمولی پنل)  <  FG_TOP (BUG-031: دکمه‌ی
//   MARKET/PENDING، باید حتی از لیبل روی خودش هم بالاتر بمونه)
// نتیجه: کل پنل (پس‌زمینه تا دکمه) از هر آبجکت خارجی روی چارت بالاتره، و ترتیب داخلی پنل هم
// دقیقاً همون چیزیه که قبلاً بود - فقط روی یه پایه‌ی بالاتر شیفت شده.
#define PANEL_ZORDER_BG      1000000
#define PANEL_ZORDER_FG      1000001
#define PANEL_ZORDER_FG_TOP  1000002
#define PERF_PCT_W_RATIO 0.52  // v42 (Punch List, Part 3): 0.50->0.52 - after the R/RB reorder above shortened the R/RB column's text by 1 char (13->12), the % column's still-13-char text was the tighter fit at 50/50; rebalancing toward the actual text-length ratio frees up the R/RB column's now-unused width and lets BestFitMonoFont() pick a larger shared font for both columns. (v36 (فیدبک Mahmoud): از 0.55 به 0.50 - بعد از کوتاه‌شدن لیبل‌ها)
                                // (Change 1 revision) طول متن ستون % و ستون R/RB تقریباً برابر
                                // شدن (~۱۳ کاراکتر هرکدوم)، پس تقسیم قدیمی 55/45 (که برای متن
                                // بلندتر قبلی تنظیم شده بود) به ستون RB فضای کمتر از لازم می‌داد
                                // و چون فونت مشترکه (min دو ستون)، همین باعث ریز موندن کل ردیف می‌شد.

// v34.4 (Item 2): drawer holds 4 PHYSICAL rows, was a uniform 2-per-row grid (half-width buttons
// throughout) - Candle Timer/BE Ref Line, Daily H/L/Weekly H/L, Monthly H/L/Hide Objects, R/R/
// Measure Move - 8 items in 4 rows (Remove Indicators removed entirely, Item 1, dropping the count
// from 9 to 8 and making the mixed half/third-width layout unnecessary). Both ComputeBodyH() and
// BuildPanel() use this constant so the two stay in sync automatically, same principle as every
// other named layout constant on this panel.
// v54: still 4 physical rows (count unchanged) but the composition shifted to fit in Session
// Windows - Row 1 unchanged (Candle Timer/BE Ref Line); Row 2 is now Daily H/L + Weekly H/L +
// Monthly H/L together (equal thirds, not half-width); Row 3 is Session Windows + Hide Objects
// (SW takes the row slot Monthly H/L freed up by moving into Row 2); Row 4 unchanged (R/R/
// Measure Move). See BuildPanel()'s DASH_UTILITY branch for the actual geometry.
// v55 (CSV Export - Trade Journal پایه): یک ردیف پنجم (تمام‌عرض) اضافه شد - "Export CSV"، یک
// دکمه‌ی Action (نه Toggle) که ExportTradeJournalCSV() (RM_Reports.mqh) رو صدا می‌زنه. ردیف
// جدید بعد از ردیف R/R‌/Measure Move می‌شینه، قبل از هدر Trading Reports.
// v56 (Trade Tagging): ردیف پنجم از تمام‌عرض به نصف/نصف تبدیل شد - "EXPORT CSV" | "TAG TRADES"
// (خودِ TOOLS_ROW_COUNT دست‌نخورده موند، فقط ترکیب داخلی ردیف ۵ عوض شد - همون الگوی v54 برای
// Session Windows). دکمه‌ی جدید پنجره‌ی مستقل تگ‌گذاری (BuildTagWindow، RM_Tools.mqh) رو باز/بسته می‌کنه.
// v57 (Item 3 - هماهنگی لایه‌بندی): یک ردیف ششم (نصف/نصف) اضافه شد - "SESSION LEVEL" |
// "ENTRY/EXIT MARKERS". هر دو toggle با هم در همین یک ردیف اضافه شدن (نه هرکدوم یک ردیف تمام‌عرض
// جدا) دقیقاً طبق تصمیم تسک: عدد فرد ردیف/دکمه لایه‌بندی هم‌ردیف‌های نصفی رو خراب می‌کنه، پس هر دو
// آیتم جدید همیشه با هم (یک ردیف کامل) اضافه/حذف می‌شن.
#define TOOLS_ROW_COUNT 6
// v43 (Item 2): Risk Lab / Journal / AI Coach placeholder rows removed entirely from the panel
// (were previously always-visible dimmed rows below the Tools drawer) - PLACEHOLDER_ROW_COUNT
// constant no longer needed.

#define REPORTS_ROW_COUNT 3   // 3 rows x 2 metrics = Win Rate/PF, Avg R:R/Expectancy, Drawdown/Trade Count

int CLOSE_GRID_ROW_H;  // v28 (Change 6): Close submenu 2x2 grid, sized like other panel buttons
int CLOSE_GRID_GAP;

// v32 (Global Layout Scaling): current scale multiplier (from LayoutScale, e.g. 0.80 for 80%) and
// the two rounding helpers used to derive every scaled constant above plus the handful of literal
// pixel offsets inside BuildPanel() that aren't behind a named constant (title bar row, MARKET/
// PENDING stacked-label gap, drawer top padding, status text vertical centering).
double g_layoutScale = 1.0;

// v32: scales a geometry value (width/height/gap/margin) and rounds to the nearest pixel.
int SC(int v)
{
   return (int)MathRound(v * g_layoutScale);
}

string P = "RM9_";
#define LN_CUR "RM9_CUR"
#define LN_ENT "RM9_ENT"
#define LN_SL  "RM9_SL"
#define LN_TP  "RM9_TP"
// v36 (Change 5): لیبل زنده‌ی نوع سفارش کنار cursor حین پیش‌نمایش SL - جدا از خطوط قیمتی چون
// pixel-anchored هست نه price-anchored (باید دقیقاً کنار ماوس بمونه، نه روی یه قیمت ثابت).
#define LN_TYPE "RM9_ORDTYPE"
// v42 (Punch List follow-up, Mahmoud feedback): MQL4 has no API to change the actual OS mouse
// cursor icon (that's a terminal-level feature, not exposed without a DLL import, which isn't
// appropriate here) - same practical effect via a small text tag that follows the cursor while a
// Fibo tool is armed, same screen-anchored XDISTANCE/YDISTANCE pattern as LN_TYPE above. Kept
// inside the P-prefixed panel namespace (unlike the Fibo drawing objects themselves) so it's also
// swept automatically by any ObjectsDeleteAll(0,P) panel rebuild, as a second safety net on top of
// the explicit cleanup in CancelFiboArm().
#define LN_FIBOCURSOR "RM9_FIBOCURSOR"

// R2 (Architecture Refactor): BuildPanel و همه‌ی توابع رسم/آپدیت پنل، به‌همراه ثابت‌های
// layout مخصوص خودشون، به RM_Dashboard.mqh منتقل شدن. اینجا (بعد از تمام global state ای
// که این توابع بهش نیاز دارن، از جمله P و همه‌ی g_* بالا) include می‌شه تا هر شناسه‌ای که
// BuildPanel/Update*/... استفاده می‌کنن، قبل از include دیده شده باشه.
#include "RM_Dashboard.mqh"

// R3 (Architecture Refactor): آرایه‌های خام Trade Snapshot و توابع ذخیره/بازیابی/خواندنش
// (لایه‌ی داده‌ی مستقل) به RM_Snapshot.mqh منتقل شدن. بعد از RM_Config.mqh و RM_Dashboard.mqh
// و قبل از OnInit include می‌شه - همون منطق ترتیبی که برای RM_Dashboard.mqh در R2 استفاده شد.
#include "RM_Snapshot.mqh"

// R4 (Architecture Refactor): توابع اجرای معامله (ProcessClick/AutoExecute/BE/Half-Close/
// Full-Close/منوها) + SL Tampering Protection (BUG-018) به RM_TradeExecution.mqh منتقل شدن.
// چون از API عمومی Snapshot (مثل IsPrematureBeforeOneR/MarkStrikedThisTrade) مستقیم استفاده
// می‌کنه، بعد از RM_Snapshot.mqh و قبل از OnInit include می‌شه - همون الگوی R2/R3.
#include "RM_TradeExecution.mqh"

// R5 (Architecture Refactor): توابع محاسبه‌ی ریسک (ApplyRiskCeilings/CheckLimits/
// GetTotalOpenRisk/GetDailyRisk/CalcLot/PipFactor/PipFactorForSymbol/GetPipValueForSymbol)
// به RM_RiskCalc.mqh منتقل شدن. بعد از RM_TradeExecution.mqh و قبل از OnInit include می‌شه -
// همون الگوی ترتیبی R2/R3/R4. محل فراخوانی ApplyRiskCeilings() در OnInit (بلافاصله قبل از
// BuildPanel()) دست‌نخورده باقی می‌مونه - فقط تعریف تابع منتقل شده، نه محل فراخوانیش.
#include "RM_RiskCalc.mqh"

// R6 (Architecture Refactor): موتور Drawdown (GetWeeklyDrawdown/GetMonthlyDrawdown/
// CheckFloatingDrawdown/CheckDrawdownLimits/Save-LoadDrawdownState + پایه‌ی مشترک
// CalcNetResultPercent و سه wrapper‌اش) به RM_DrawdownEngine.mqh منتقل شد. بعد از
// RM_RiskCalc.mqh و قبل از OnInit include می‌شه - همون الگوی ترتیبی R2-R5.
#include "RM_DrawdownEngine.mqh"

// R6 (Architecture Refactor): موتور Cooldown و رفتار (Entry Interval/Pending
// Activation Tracking/Behavior Strike/Track-CheckClosedTrades/Market Cooldown
// Time Reset/Save-LoadCooldownState/IsTradingAllowed) به RM_CooldownEngine.mqh
// منتقل شد. بعد از RM_DrawdownEngine.mqh include می‌شه چون IsTradingAllowed از
// globalهای Drawdown (g_weeklyLockEnd/g_monthlyLockEnd) هم می‌خونه؛ از نظر فنی این
// ترتیب اجباری نیست (forward-reference قبلاً در R4/R5 تأیید شده که کار می‌کنه)، فقط برای خوانایی.
#include "RM_CooldownEngine.mqh"

// R7 (Architecture Refactor): موتور Trailing Stop، Auto Trigger Actions، Trading Reports
// Stats، و ابزارهای دستی چارت (Fibo/Candle Timer/H-L/BE Ref/Hide-Show) به این ۴ ماژول
// منتقل شدن. ترتیب داخلی این ۴ تا با هم مهم نیست (forward-reference قبلاً تأیید شده که کار
// می‌کنه)؛ برای خوانایی: Trailing، بعد AutoActions (چون یک‌طرفه به Trailing وابسته‌ست)، بعد
// Reports، بعد Tools.
#include "RM_Trailing.mqh"
#include "RM_AutoActions.mqh"
#include "RM_Reports.mqh"
#include "RM_Tools.mqh"

//+------------------------------------------------------------------+
int OnInit()
{
   // v72 (URGENT bugfix - false Weekly/Monthly DD lock on real-account restart): ثبت می‌شه به‌عنوان
   // اولین خط OnInit() - قبل از هر Load*()ای که ممکنه در طول یک reconnect کند (حساب واقعی) روی
   // AccountBalance()/تاریخچه‌ی سفارش‌ها مقدار ناپایدار/موقت بخونه. مبنای پنجره‌ی Grace Period
   // (CheckDrawdownLimits در RM_DrawdownEngine.mqh) دقیقاً از همین لحظه شمرده می‌شه.
   g_eaStartupTime = TimeCurrent();
   // v77 (Pattern B fix): کلیدهای حساب‌محور رو با AccountNumber()ِ زنده بازبساز - قبل از هر Load*State
   // و قبل از PatternBDiag. این تنها نقطه‌ای‌ست که سوییچِ حساب (OnInit بدونِ reloadِ برنامه) رو خنثی می‌کنه.
   BuildAccountScopedKeys();
   RM_LoadSharedSettings();  // v102: بعد از ساخت کلیدها و قبل از هر مصرف‌کننده‌ی تنظیمات مشترک (ApplyRiskCeilings و ...)
   InitAutoCloseAtHour();  // v80 (FEAT-031): اینپوت ساعت رو پارس/اعتبارسنجی می‌کنه - بعد از BuildAccountScopedKeys (کلید GV اونجا ساخته می‌شه)
   PatternBDiag("OnInit");  // v77 (Pattern B investigation - TEMPORARY): اگه این OnInit به‌خاطر سوییچ حساب (REASON_ACCOUNT) بوده و رشته‌ی کلید بازارزیابی نشده، اینجا لو می‌ره
   ApplyLayoutScale();  // v32: must run before anything that reads PW/TH/MX/GP/... or calls BuildPanel()
   ApplyRiskCeilings();  // v38 (BUG-023): must run before BuildPanel() - Risk Toggle button reads g_effRiskPerTrade
   g_riskReward = RiskReward;  // v9.7: مقدار اولیه از Input، بعد از این فقط از داشبورد قابل تغییره
   g_dayStart   = RM_DayStartSrv();    // v102: مستقل از نماد (زمان سرور)
   g_weekStart  = RM_WeekStartSrv();
   g_monthStart = RM_MonthStartSrv();
   // v13: نیازی به مقداردهی اولیه‌ی سراسری برای زمان کندل Trailing نیست - چون حالا هر تیکت
   // زمان و تایم‌فریم خودش رو جدا نگه می‌داره (g_trailPeriod / g_trailLastBar)، در AddTrailTicket()
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
   LoadCooldownState();
   LoadDrawdownState();
   LoadDashboardModeState();
   LoadRiskStepState();  // v84 (FEAT-038): پله‌ی ذخیره‌شده‌ی ریسک - قبل از BuildPanel() تا دکمه از همان ابتدا درست رسم شود
   // v79 (Item 4): LoadCandleTimerState() حذف شد - دیگه وضعیتی برای لود کردن نیست (همیشه‌فعال).
   LoadSessionWindowsState();  // v54: بارگذاری وضعیت ذخیره‌شده‌ی توگل Session Windows
   SessionLevel_LoadState();       // v57: بارگذاری وضعیت ذخیره‌شده‌ی توگل Session Level (فیچر جدید مستقل)
   History_LoadState();   // v85: وضعیت روشن/خاموش دکمه‌ی HISTORY بعد از ری‌استارت
   LoadEntryExitMarkersState();    // v57: بارگذاری وضعیت ذخیره‌شده‌ی توگل Entry/Exit Markers
   LoadTradeSnapshots();  // v11 (FEAT-016): بارگذاری Trade Snapshotهای ذخیره‌شده از ری‌استارت‌های قبلی
   RefreshChainRootKeys();  // v87 (FEAT-042 فاز ۲): جلوگیری از انقضای ۴هفته‌ای GlobalVariable کلید ریشه‌ی زنجیره‌ها
   {
      // v101 (BUG-054): قفل claim را بساز/تازه کن، claimهای قدیمی را پاک کن و تعداد کلیدهای موجود را لاگ کن
      int miClaimKeys = RM_ClaimHousekeeping();
      Print("[RM-MI] instance ", RM_InstTag(), " started, claim keys: ", miClaimKeys);
   }
   EnsureStrategySetupsSeed();  // v56 (Trade Tagging): اگه اولین اجراست، فایل با seed مشخص‌شده در تسک ساخته می‌شه؛ وگرنه فقط لود می‌شه
   g_tagVerSeen = GlobalVariableCheck(GV_TAGFILE_VER) ? GlobalVariableGet(GV_TAGFILE_VER) : 0.0;  // v101: قبل از خواندن فایل - اگر نمونه‌ی دیگری همین لحظه ذخیره کند، sync بعدی دوباره می‌خواند
   LoadTradeTagsFile();         // v56 (Trade Tagging): نگاشت Ticket->Strategy/Setup ذخیره‌شده از قبل
   EnsureContextChecklistSeed();  // FEAT-037 (v81): هم‌الگوی EnsureStrategySetupsSeed بالا - فایل جدا/مستقل RM_ContextChecklist.txt
   g_ctxTagVerSeen = GlobalVariableCheck(GV_CTXTAGFILE_VER) ? GlobalVariableGet(GV_CTXTAGFILE_VER) : 0.0;  // v101 (همان دلیل بالا)
   LoadContextTagsFile();         // FEAT-037 (v81): هم‌الگوی LoadTradeTagsFile بالا - نگاشت Ticket->۵ Boolean ذخیره‌شده از قبل (RM_ContextTags.csv)
   EnsureScreenshotFolder();    // v66 (آیتم ۱): یک‌بار می‌سازه (اگه از قبل نبود) - زیرپوشه‌ی TRADE SCREENSHOTS برای اسکرین‌شات‌های لحظه‌ی خروج (v59)
   BuildPanel();
   UpdateRiskDisplay();
   UpdateCandleTimerChart(true);  // v26 (FEAT-018): اگه از ری‌استارت قبلی روشن بوده، بدون معطلی برای اولین تیک نمایش داده بشه - true چون هنوز هیچ تیکی نیومده که خودش چارت رو رفرش کنه
   if(g_swOn) BuildSessionWindows();  // v54: اگه از ری‌استارت قبلی روشن بوده، بدون معطلی برای اولین تیک رسم بشه
   if(g_sessLvlOn) SessionLevel_BuildWindows();  // v57: همون الگو - اگه از ری‌استارت قبلی روشن بوده، بدون معطلی رسم بشه
   if(g_histOn) History_Build();  // v85: همین الگو - HISTORY روشن بوده -> بعد از ری‌استارت/تغییر تایم‌فریم دوباره رسم می‌شه
   if(g_markersOn) BuildEntryExitMarkers();      // v57: همون الگو - اگه از ری‌استارت قبلی روشن بوده، بدون معطلی رسم بشه
   EventSetTimer(1);  // v26.1 (FEAT-018 fix): شمارش معکوس رو مستقل از تیک‌های واقعی قیمت، هر ۱ ثانیه واقعی آپدیت می‌کنه - در نمادها/تایم‌فریم‌هایی که تیک کم داره (فاصله‌ی چند ثانیه‌ای بین تیک‌ها) بدون این، شمارش به‌جای نرم بودن، هر چند ثانیه یهو می‌پرید جلو
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();  // v26.1 (FEAT-018 fix): متقارن با EventSetTimer(1) در OnInit
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0);
   ObjectsDeleteAll(0, P);
   ObjectDelete(0,LN_CUR); ObjectDelete(0,LN_ENT);
   ObjectDelete(0,LN_SL);  ObjectDelete(0,LN_TP);
   ObjectDelete(0,LN_CUR+"_LBL"); ObjectDelete(0,LN_SL+"_LBL"); ObjectDelete(0,LN_TP+"_LBL");
   RemoveCandleTimerChart();  // v26 (FEAT-018): آبجکت شمارش معکوس هم مثل بقیه‌ی خط‌های چارت (LN_*) باید پاک بشه
   // v33/v34: همون منطق برای آبجکت‌های چارتی جدید - RM9LN_FIBO_RMULT و RM9LN_FIBO_MEASURE عمداً
   // حذف نمی‌شن چون ابزار ترسیم دستی‌ان (مثل هر آبجکت دستی دیگه‌ی MT4، باید بین ری‌استارت‌ها روی چارت بمونن)
   RemoveDailyHL();
   RemoveWeeklyHL();
   RemoveMonthlyHL();
   RemoveBERefLines();
   RemoveSessionWindows();  // v54
   SessionLevel_RemoveWindows();   // v57
   History_Remove();               // v85
   RemoveEntryExitMarkers();       // v57
   ObjectsDeleteAll(0, TAG_WIN_PREFIX);  // v56 (Trade Tagging): پنجره‌ی تگ‌گذاری، اگه باز مونده بود، هم پاک بشه
   ObjectsDeleteAll(0, SCL_WIN_PREFIX);  // v90 (FEAT-044): پنجره‌ی انتخاب زنجیره‌ی Scale-in
   ObjectsDeleteAll(0, HALFSEL_WIN_PREFIX);  // v59 (Item 1): پنجره‌ی انتخاب تک‌تیکت، اگه باز مونده بود، هم پاک بشه
   ChartRedraw();
}

// v26.1 (FEAT-018 fix): OnTick() فقط با تیک واقعی قیمت فایر می‌شه - روی نمادها/تایم‌فریم‌هایی که
// تیک کم داره، فاصله‌ی چند ثانیه‌ای بین دو تیک باعث می‌شد شمارش معکوس به‌جای نرم بودن، یهو چند
// ثانیه بپره جلو. OnTimer با EventSetTimer(1) دقیقاً هر ۱ ثانیه (مستقل از ورود تیک) فایر می‌شه،
// پس شمارش رو صرف‌نظر از نرخ تیک نرم و لحظه‌به‌لحظه نگه می‌داره. فقط همین یک تابع رو صدا می‌زنه -
// هیچ منطق دیگه‌ای (Risk/Cooldown/Drawdown) به این تایمر وابسته نیست و همچنان فقط با OnTick() اجرا می‌شه.
void RM_OnTimerImpl()
{
   // v80 (FEAT-031): روی نمادهای کم‌تیک ممکنه بین دو تیک، لحظه‌ی مرز ساعت رد بشه - همین تایمر ۱ ثانیه‌ای
   // موجود (بدون تایمر دوم) هم چک می‌کنه؛ پرچم روزانه (GV) تضمین می‌کنه OnTick/OnTimer با هم دوبار اجرا نشن.
   // RefreshRates() چون FullClose() از Bid/Ask استفاده می‌کنه و بین تیک‌ها ممکنه کهنه باشن.
   if(EnableAutoCloseAtHour) { RefreshRates(); CheckAutoCloseAtHour(); }
   CancelOrphanContinuationPendings();  // v90.1 (FEAT-044)
   ScaleInPickerRefresh();  // v90 (FEAT-044): روی نمادهای کم‌تیک هم فهرست انتخابگر/اعتبار Scale-in تازه بماند (throttle داخلی)

   // v91: چاپ تشخیصی «OnTimer interval» (v26.12) حذف شد - هر ثانیه یک خط لاگ بی‌مصرف می‌نوشت.

   UpdateCandleTimerChart(true);  // v26.5: true چون OnTimer با تیک واقعی همزمان نیست و چارت خودش رفرش نمی‌شه

   CheckButtonFlashExpiry();  // v30 (Button Click Feedback): همون تایمر ۱ ثانیه‌ای موجود، بدون تایمر دوم

   RM_NewsTick();  // v105: خبرهای USD (throttle ۲۰ثانیه، فقط وقتی KEY TIME روشن است؛ دانلود ساعتی)

   CheckPanelIntegrity();  // v34 (BUG-033): همون تایمر ۱ ثانیه‌ای موجود، بدون تایمر دوم - نگاه کن به تعریف تابع برای جزئیات
}

// v30 (Button Click Feedback - Part 1): وقتی BE/Half Close/Full Close کلیک می‌شه و اکشن اجرا می‌شه،
// این تابع رنگ دکمه رو فوراً به یه رنگ کاملاً پر (نه فقط یه فلش لحظه‌ای) عوض می‌کنه و ددلاین ۵
// ثانیه‌ای (بر اساس GetTickCount()، نه TimeCurrent()/تیک قیمت - پس حتی روی نمادهای کم‌تیک هم دقیقاً
// ۵ ثانیه‌ی واقعی می‌مونه) رو در متغیر global مخصوص همون دکمه ذخیره می‌کنه. هر دکمه متغیر ددلاین
// جدای خودش رو داره - کلیک روی یکی، تایمر بقیه رو ریست یا لمس نمی‌کنه.
// v34.5 (Mahmoud feedback): darkens a candle-based color (Items 4/5's full-brightness bull/bear
// colors, which are often too bright for white button text to stay readable) down to ~55%
// brightness for use as a button flash color, WITHOUT touching the actual on-chart Fibo line
// color (CreateFiboRMultiple()/CreateFiboMeasureMove() still use the full-brightness color for
// the drawn lines - only the button feedback gets dimmed).
color DimForButton(color c)
{
   int r = (int)(c & 0xFF);
   int g = (int)((c >> 8) & 0xFF);
   int b = (int)((c >> 16) & 0xFF);
   r = (int)(r*0.55); g = (int)(g*0.55); b = (int)(b*0.55);
   return (color)(r + (g<<8) + (b<<16));
}

// v42 (Punch List follow-up, Mahmoud feedback): the cursor tag's color was two arbitrary fixed
// colors, unrelated to the actual line color each tool draws. Pulled the exact color logic
// CreateFiboRMultiple()/CreateFiboMeasureMove() already used inline out into these two shared
// helpers - both the line color and the cursor tag color now read from the same single source of
// truth, so they can never drift apart (light-background contrast darkening included).
// v49 (Punch List, Item 1, first pass): source switched to CHART_COLOR_CHART_LINE (MT4's shared
// wick/shadow color) for both tools, to dodge themes where the candle body blends into the
// background. REVERTED per Mahmoud follow-up: MT4 has no separate bull-wick/bear-wick colors -
// CHART_COLOR_CHART_LINE is one single value shared by both directions, so it can't give R/R and
// Measure Move distinct colors from each other. Mahmoud confirmed he wants the original body-based
// split back (R/R = bull body, Measure Move = bear body), since that's the only MT4 property that
// is actually direction-specific.
// v49 (Punch List, Item 1, second pass): body color restored, but now routed through
// ResolveFiboLineColor() below, which auto-substitutes the wick/line color whenever the body color
// is (near-)indistinguishable from the chart background - covers both "body deliberately left
// blending into the background" templates and literal same-color/colorless (clrNONE) cases -
// while still using the real bull/bear body color (and therefore two genuinely different colors
// for the two tools) on any normal theme.
color ResolveFiboLineColor(color bodyColor)
{
   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   double bgLum   = 0.299*(chartBg & 0xFF)   + 0.587*((chartBg >> 8) & 0xFF)   + 0.114*((chartBg >> 16) & 0xFF);
   double bodyLum = 0.299*(bodyColor & 0xFF) + 0.587*((bodyColor >> 8) & 0xFF) + 0.114*((bodyColor >> 16) & 0xFF);
   color lvlColor = bodyColor;
   // نزدیک به بک‌گراند (اختلاف luminance کمتر از ۳۰ از ۲۵۵) یا اصلاً بدون رنگ (clrNONE) -> به
   // جای بدنه، رنگ Wick/Line چارت (که خیلی از تمپلیت‌ها عمداً متفاوت از بدنه نگه می‌دارن) استفاده
   // می‌شه
   bool bodyBlendsIntoBg = (MathAbs(bodyLum - bgLum) < 30) || (bodyColor == clrNONE);
   if(bodyBlendsIntoBg) lvlColor = (color)ChartGetInteger(0, CHART_COLOR_CHART_LINE);
   if(bgLum > 140) lvlColor = DimForButton(lvlColor);
   return lvlColor;
}
// v84 (کار سوم): رنگ خطوط R/R و Measure Move دیگه به رنگ کندل صعودی/نزولی وابسته نیست - یک خاکستری ثابت،
// با فاصله‌ی luminance تضمین‌شده از بک‌گراند چارت (الگوی تشخیص روشن/تیره همان GetKeyTimeLineColor).
// بک‌گراند روشن (luminance >= 128) -> خاکستری تیره‌تر از بک‌گراند؛ بک‌گراند تیره -> خاکستری روشن‌تر.
// حداقل فاصله ~98 از 255 حتی روی بک‌گراند خاکستری میانی؛ clamp فقط تا خاکستری خیلی نزدیک سیاه/سفید نشه.
color GetFiboToolGrayColor()
{
   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   double bgLum = 0.299*(chartBg & 0xFF) + 0.587*((chartBg >> 8) & 0xFF) + 0.114*((chartBg >> 16) & 0xFF);
   int gv;
   if(bgLum >= 128) gv = (int)MathMax(30.0,  MathMin(130.0, bgLum - 100.0));
   else             gv = (int)MathMin(225.0, MathMax(150.0, bgLum + 100.0));
   return (color)(gv | (gv<<8) | (gv<<16));
}
color GetFiboRRColor()      { return GetFiboToolGrayColor(); }
color GetFiboMeasureColor() { return GetFiboToolGrayColor(); }
// v84: Session Level (RM_Tools.mqh) قبلاً از GetFiboMeasureColor() رنگ می‌گرفت. چون کار سوم فقط R/R و
// Measure Move رو خاکستری می‌کنه، منطق قبلی (رنگ بدنه‌ی کندل نزولی + کنتراست خودکار) عیناً اینجا نگه داشته
// شد تا رنگ Session Level هیچ تغییری نکنه.
color GetSessionLevelBoxColor()
{
   color bodyColor = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
   return ResolveFiboLineColor(bodyColor);
}

// v51 (Item 4، پیدا شده حین تست v50): رنگ متن لیبل پیش‌نمایش SL/TP حین hover (MOUSE_MOVE) ثابت
// clrWhite بود - روی بک‌گراند روشن دیده نمی‌شد. wrapper کوچیک روی همون ResolveFiboLineColor() بالا
// (بدون بازنویسی منطق luminance/fallback) - فقط رنگ کاندید سفید رو به‌جای رنگ بدنه‌ی کندل بهش می‌ده؛
// اگه سفید با بک‌گراند کم‌کنتراست/نزدیک بود (یا بک‌گراند روشن بود)، همون تابع خودکار می‌ره سراغ رنگ
// Wick/Line چارت یا نسخه‌ی تیره‌شده - دقیقاً همون الگوی v49 برای خطوط R:R/Measure Move.
color GetPreviewLabelColor()
{
   return ResolveFiboLineColor(clrWhite);
}



// R8 (Architecture Refactor, Final Phase): EstimateServerTime() به داخل RM_Tools.mqh منتقل شد
// (نه RM_Common.mqh) - طبق grep تک‌مصرف‌کننده‌ست (فقط RM_Tools.mqh)، پس مشترک بین چند ماژول
// نیست و لازم نیست توی RM_Common.mqh باشه؛ globalهای g_ctLastServerSync/g_ctLastLocalSync/
// g_ctLastEstimate از قبل توی RM_Tools.mqh مقیم بودن.
// BELineName() و BasketAvgLineName() به RM_Common.mqh منتقل شدن - طبق grep BELineName() توسط
// RM_AutoActions.mqh + RM_CooldownEngine.mqh + RM_TradeExecution.mqh مصرف می‌شه (۳ ماژول) و
// BasketAvgLineName() توسط RM_CooldownEngine.mqh + RM_TradeExecution.mqh.



// R8 (Architecture Refactor, Final Phase): HLineLabel() به RM_Common.mqh منتقل شد - طبق grep
// توسط RM_AutoActions.mqh + RM_Tools.mqh مصرف می‌شه.





















void RM_OnTickImpl()
{
   RM_PfBegin();
   RM_CfgSyncIfChanged();   // v102: تنظیمات مشترک - یک GlobalVariableGet در هر تیک
   // v9.5: بالاترین اولویت - مستقل از همه‌ی کول‌داون‌ها و چک‌های دیگه اجرا می‌شه
   CheckFloatingDrawdown();
   RM_PfMark("CheckFloatingDrawdown");

   // v80 (FEAT-031): بستن خودکار همه‌ی معاملات باز در ساعت مشخص (وقت بروکر) - بعد از Floating DD
   // (بالاترین اولویت) و قبل از بقیه‌ی OnTick تا CheckClosedTrades() همین تیک نتیجه‌ی بستن رو طبقه‌بندی کنه.
   // با EnableAutoCloseAtHour=false دقیقاً no-op است.
   CheckAutoCloseAtHour();
   RM_PfMark("CheckAutoCloseAtHour");

   datetime today = RM_DayStartSrv();   // v102
   // v10 (BUG-012): با تغییر روز، بالانس شروع روز هم ریست و ذخیره می‌شه (مبنای نتیجه‌ی خالص روزانه)
   if(today != g_dayStart)
   {
      // v64 (آیتم ۱ - PriorDayResult): *قبل* از overwrite شدن g_dayStart/g_dayStartBalance -
      // یعنی درست همون‌جایی که هنوز مبنای محاسبه‌ی نتیجه‌ی روزی که داره تموم می‌شه معتبره.
      ComputePriorDayResult();

      g_dayStart = today;
      g_dayStartBalance = RM_PeriodStartBalance(GV_DAY_START, GV_DAY_START_BAL, today);  // v102: اگر چارت دیگر همین روز را ثبت کرده همان
      // v53: g_mktStopCount/g_behCount/g_lastStopCloseTime حالا مشترک بین چارت‌هان - ریست روزانه
      // باید روی GlobalVariable مشترک هم اعمال بشه (CAS)، وگرنه این ریست محلی بی‌اثره چون اولین
      // Refresh بعدی (CheckMarketCDTimeReset هر تیک) فوراً مقدار مشترک قبلی رو دوباره می‌نویسه.
      g_mktStopCount = CAS_SetGlobal(GV_MKT_COUNT, 0.0);
      g_behCount     = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
      g_lastStopCloseTime = (datetime)CAS_SetGlobal(GV_LAST_STOP_CLOSE, 0.0);
      SaveCooldownState();
      SaveDrawdownState();
      // v54: با تغییر روز، اگه Session Windows روشنه دوباره ساخته می‌شه - هم DST مستقلاً برای
      // همون روز دوباره ارزیابی می‌شه، هم امروز همون لحظه‌ی شروع روز رسم می‌شه (نه وقتی زمان
      // شروع بازه‌اش می‌رسه)، هم پنجره‌ی تاریخچه‌ی ~۱ ماهه یه روز جلو می‌ره.
      if(g_swOn) BuildSessionWindows();
      // v57: با تغییر روز، اگه Session Level روشنه دوباره ساخته می‌شه - همون سه دلیل بالا
      // (DST دوباره برای همون روز، "امروز" همون لحظه‌ی شروع روز، پنجره‌ی تاریخچه یه روز جلو)،
      // به‌علاوه‌ی این‌که باکس "فردا" (daysAgo=-1) هم یه روز جلوتر می‌ره.
      if(g_sessLvlOn) SessionLevel_BuildWindows();
      if(g_histOn) History_Build();  // v85: پنجره‌ی N روز با عوض‌شدن روز جابه‌جا می‌شه
      RefreshChainRootKeys();        // v87 (FEAT-042 فاز ۲): تازه‌سازی روزانه‌ی کلیدهای ریشه
      RM_ClaimHousekeeping();        // v101 (BUG-054): نگهداری روزانه‌ی claimها (تازه‌سازی قفل + پاک‌سازی claimهای قدیمی‌تر از RM_CLAIM_KEEP_DAYS)
   }

   // weekly reset
   datetime thisWeek = RM_WeekStartSrv();   // v102
   // v10 (BUG-012): با تغییر هفته، بالانس شروع هفته هم ریست و ذخیره می‌شه
   if(thisWeek != g_weekStart) { g_weekStartBalance = RM_PeriodStartBalance(GV_WEEK_START, GV_WEEK_START_BAL, thisWeek); g_weekStart = thisWeek; SaveDrawdownState(); }

   // monthly reset
   datetime thisMonth = RM_MonthStartSrv();   // v102
   // v10 (BUG-012): با تغییر ماه، بالانس شروع ماه هم ریست و ذخیره می‌شه
   if(thisMonth != g_monthStart) { g_monthStartBalance = RM_PeriodStartBalance(GV_MONTH_START, GV_MONTH_START_BAL, thisMonth); g_monthStart = thisMonth; SaveDrawdownState(); }

   // v13 (BUG-017): time-based Market Cooldown streak reset - checked every tick,
   // independent of whether a new trade is entered. Reference point is the close
   // time of the last SL-hit trade, not the entry time of the next trade.
   CheckMarketCDTimeReset();
   RM_PfMark("CheckMarketCDTimeReset");

   if(AutoBE) CheckAutoBE();
   RM_PfMark("CheckAutoBE");
   RM_SnapshotAutoSync();  // v101 (BUG-054/057): فقط یک GlobalVariableGet؛ اسکن فقط وقتی نمونه‌ی دیگری Snapshot جدید ساخته باشد
   RM_PfMark("RM_SnapshotAutoSync");
   CheckClosedTrades();
   RM_PfMark("CheckClosedTrades");
   History_Refresh();   // v85: اگه HISTORY روشنه و معامله‌ای تازه بسته شده، باکس‌هاش اضافه بشه
   RM_PfMark("History_Refresh");
   EnsureTrailingReset();  // v42 (Punch List, Part 5, BUG-035): safety net, see comment above - runs before CheckAutoTrailingTrigger/SyncManualTrailing below so a stale ON flag never sweeps a new trade into Trailing
   RM_PfMark("EnsureTrailingReset");
   CheckPendingActivation();
   RM_PfMark("CheckPendingActivation");
   CancelOrphanContinuationPendings();  // v90.1 (FEAT-044)
   RM_PfMark("CancelOrphanContinuationPendings");
   ScaleInPickerRefresh();  // v90 (FEAT-044): تازه‌سازی فهرست انتخابگر / اعتبار زنجیره‌ی انتخاب‌شده (throttle ۱ثانیه‌ای داخل خود تابع)
   RM_PfMark("ScaleInPickerRefresh");

   // v41 (BUG-018): SL Tampering Protection - بعد از CheckClosedTrades/CheckPendingActivation
   // (تا لیست‌های ردیابی هر تیک به‌روز باشن) و قبل از Trailing/BE (که خودشون فقط تنگ می‌کنن،
   // نه پهن، پس تداخلی با قانون ۲ ندارن؛ ولی منطقاً محافظت باید قبل از هر تغییر دیگه‌ای چک بشه)
   CheckSLTampering();
   RM_PfMark("CheckSLTampering");

   // === v7 (FEAT-002): Trailing Stop ===
   CheckAutoTrailingTrigger();          // چک می‌کنه آیا معامله‌ای به RR تعیین‌شده رسیده تا Trailing خودکار شروع بشه
   RM_PfMark("CheckAutoTrailingTrigger");
   if(g_trailingButtonOn) SyncManualTrailing(); // معاملات باز جدید رو هم زیر پوشش Trailing قرار می‌ده
   RM_PfMark("SyncManualTrailing");
   // v13: تشخیص کندل جدید حالا per-ticket و بر اساس تایم‌فریم قفل‌شده‌ی هر تیکته - هر تیک صدا زده می‌شه
   RunTrailingUpdate();
   RM_PfMark("RunTrailingUpdate");

   // v40 (FEAT-019): چک می‌کنه آیا معامله‌ای به RR تعیین‌شده رسیده تا درصد مشخص‌شده خودکار
   // Half Close بشه - دقیقاً همون الگوی CheckAutoTrailingTrigger بالا، مستقل و موازی باهاش
   CheckAutoHalfCloseTrigger();
   RM_PfMark("CheckAutoHalfCloseTrigger");

   // v40 (Mahmoud feedback): بعد از هر دو چک trigger بالا صدا زده می‌شه - تا اگه همین تیک
   // یکی از دو ویژگی واقعاً trigger شده باشه، خط پیش‌نمایش همون تیک ناپدید بشه (نه یک تیک بعد)
   UpdateAutoTriggerPreviewLines();
   RM_PfMark("UpdateAutoTriggerPreviewLines");

   CheckDrawdownLimits();
   RM_PfMark("CheckDrawdownLimits");
   UpdateCooldownDisplay();
   RM_PfMark("UpdateCooldownDisplay");
   UpdateSystemStatus();
   RM_PfMark("UpdateSystemStatus");
   RM_SyncTagsIfChanged();    // v101 (BUG-054): دو GlobalVariableGet؛ فایل فقط وقتی نمونه‌ی دیگری تگ ذخیره کرده باشد دوباره خوانده می‌شود
   UpdateUntaggedReminder();  // v59 (Item 4): یادآوری معاملات تگ‌نخورده - بعد از UpdateSystemStatus، همون دلیل چیدمان دوخطی
   RM_PfMark("UpdateUntaggedReminder");
   UpdateFloatingDisplay();
   RM_PfMark("UpdateFloatingDisplay");
   UpdateRiskDisplay();
   RM_PfMark("UpdateRiskDisplay");
   UpdatePLDisplay();
   RM_PfMark("UpdatePLDisplay");
   UpdateReportsDisplay();  // v35: same "loop history every tick, no-op if drawer/box not on screen" pattern as UpdatePLDisplay()
   RM_PfMark("UpdateReportsDisplay");
   // v26.3 (FEAT-018 fix): برگردوندن فراخوانی از OnTick - چون حالا موقعیت آبجکت (نه فقط متنش) به
   // Bid زنده وصله (v26.2)، اگه فقط با تایمر ثابت هر ۱ ثانیه آپدیت بشه، موقع حرکت سریع قیمت
   // موقعیت روی چارت از خط Ask/Bid واقعی عقب می‌مونه. الان هم اینجا (هر تیک، برای ردیابی لحظه‌ای
   // موقعیت) هم در OnTimer() (v26.1 - هر ۱ ثانیه ثابت، تضمین حداقل یک آپدیت حتی روی نمادهای کم‌تیک)
   // صدا زده می‌شه؛ هر دو مسیر همون تابع idempotent رو صدا می‌زنن، بدون تداخل منطقی.
   // v26.5 (FEAT-018 fix): از اینجا با forceRedraw=false (پیش‌فرض) صدا زده می‌شه - چون خودِ MT4 با
   // هر تیک واقعی همین‌طوری چارت رو دوباره رسم می‌کنه، ChartRedraw() صریح اضافه‌ی خودمون اینجا فقط
   // رسم تکراری بود (روی نمادهای پرنوسان، گاهی چندبار در ثانیه) و همین داشت لگ کلی چارت رو بدتر
   // می‌کرد - نه فقط پرش عدد شمارش معکوس.
   UpdateCandleTimerChart();
   RM_PfMark("UpdateCandleTimerChart");
   // v33/v34 (Tools Refinements): live-updating Tools drawings - each of these is idempotent and
   // internally no-ops (just removes its own object, if any) when its toggle is off, same pattern
   // as UpdateCandleTimerChart() above.
   UpdateDailyHL();
   RM_PfMark("UpdateDailyHL");
   UpdateWeeklyHL();
   RM_PfMark("UpdateWeeklyHL");
   UpdateMonthlyHL();
   RM_PfMark("UpdateMonthlyHL");
   UpdateBERefLine();
   RM_PfMark("UpdateBERefLine");
   UpdateSessionWindowsVertical();  // v54: فقط موقعیت عمودی رو با بازه‌ی قیمت دیده‌شده هماهنگ می‌کنه - زمان‌ها دست‌نخورده
   RM_PfMark("UpdateSessionWindowsVertical");
   SessionLevel_UpdateVertical();   // v57: همون الگو برای Session Level
   RM_PfMark("SessionLevel_UpdateVertical");
   RefreshEntryExitMarkers();       // v57: هر تیک صدا زده می‌شه، ولی داخلش فقط یک‌بار در هر کندل جدید واقعاً rebuild می‌کنه
   RM_PfMark("RefreshEntryExitMarkers");
}

//+------------------------------------------------------------------+
void RM_OnChartEventImpl(const int id, const long &lp, const double &dp, const string &sp)
{
   int mx=(int)lp, my=(int)dp;

   // rebuild panel on window resize or chart change
   // v13 (فیکس فلش زدن): این رویداد موقع اسکرول/زوم/سوییچ تایم‌فریم می‌تونه پشت‌سرهم زیاد فایر بشه.
   // rebuild کامل پنل رو به حداکثر یک‌بار در هر ثانیه محدود می‌کنیم تا در حین بررسی چارت چشمک نزنه.
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      datetime now = TimeLocal();
      if(now == g_panelLastRebuild) return;  // کمتر از ۱ ثانیه از rebuild قبلی گذشته - نادیده گرفته می‌شه
      g_panelLastRebuild = now;
      ObjectsDeleteAll(0, P);
      BuildPanel();
      UpdateRiskDisplay();
      UpdatePLDisplay();
      UpdateReportsDisplay();  // v35
      UpdateCooldownDisplay();
      UpdateSystemStatus();
      // v78 (فیکس رفرشِ زوم): موقعیتِ عمودیِ باکس‌های Session Windows/Key Time و Session Level
      // به بازه‌ی قیمتیِ نمایانِ چارت بند است (WindowPriceMax/Min). قبلاً CHART_CHANGE فقط پنل را
      // بازسازی می‌کرد، نه این باکس‌ها - پس با زوم، موقعیتشان تا یک toggle کهنه می‌ماند. مخصوصاً
      // وقتی بازار بسته است (بدونِ تیک) که هیچ رفرشِ تیک-محوری آن را ماسک نمی‌کند. همان الگوی
      // مسیرِ تغییرِ روز؛ throttleِ ۱ ثانیه‌ایِ بالا از فلش‌زدن جلوگیری می‌کند. (زمان/High-Low از
      // ماژول قطعی و immutable می‌ماند؛ فقط موقعیتِ عمودی زوم را دنبال می‌کند.)
      if(g_swOn)      BuildSessionWindows();
      if(g_sessLvlOn) SessionLevel_BuildWindows();
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE && g_step != STEP_IDLE && !IsOnPanel(mx,my))
   {
      datetime dt; double price; int win;
      if(ChartXYToTimePrice(0,mx,my,win,dt,price))
      {
         price = NormalizeDouble(price,Digits);
         HLine(LN_CUR, price, C'130,130,130', 1, STYLE_DOT);
         if(g_step==STEP_SL)
         {
            double entryRef = (g_entryPrice>0) ? g_entryPrice : (Ask+Bid)/2.0;
            bool pb  = (price < entryRef);
            double d = MathAbs(entryRef-price);
            double preTP = NormalizeDouble(pb?entryRef+d*g_riskReward:entryRef-d*g_riskReward,Digits);
            HLine(LN_TP, preTP, C'0,150,0', 1, STYLE_DOT);

            double slPipsCalc = d/(Point*PipFactor());
            double pipVal = GetPipValueForSymbol(Symbol(), Point, PipFactor());
            double tpPipsCalc = MathAbs(preTP-entryRef)/(Point*PipFactor());
            double lot=0, lossAmt=0, profitAmt=0;
            // باگ‌فیکس (پیدا شده حین تست v36): وقتی ماوس حین حرکت طبیعی دقیقاً از روی entryRef رد
            // می‌شه (d=0 لحظه‌ای)، slPipsCalc صفر می‌شه و CalcLot(0,...) وارد مسیر Alert() می‌شد -
            // چون MOUSE_MOVE خیلی پرتکرار فایر می‌شه، این باعث اسپم popup "cannot determine pip
            // value" می‌شد (بیشتر توی Pending چون entryRef اونجا یه خط ثابته که ماوس طبیعتاً روش
            // رد می‌شه؛ توی Market، entryRef قیمت زنده‌ی در حال حرکته پس به‌ندرت پیش میاد). این
            // فقط پیش‌نمایش رو گارد می‌کنه - خود CalcLot()، ProcessClick() و رفتار Alert روی کلیک
            // واقعی (که درسته و باید بمونه) دست‌نخورده‌ست.
            // BUG-036 (v44): پیش‌نمایش همیشه g_effRiskPerTrade خام رو می‌خوند، نه ریسک واقعی‌ای که
            // AutoExecute() موقع ثبت واقعی استفاده می‌کنه (اونجا وقتی Half Risk فعاله نصف می‌شه -
            // ببین riskToUse توی AutoExecute()). حجم واقعی معامله (CalcLot در AutoExecute) از قبل
            // درست بود؛ فقط این عدد $ روی خط راهنما نصف نمی‌شد. همون فرمول اونجا رو اینجا هم تکرار
            // می‌کنیم تا پیش‌نمایش با چیزی که واقعاً ثبت می‌شه یکی باشه.
            double previewRisk = GetEntryRiskPct();  // v84 (FEAT-038): منبع واحد ریسک فعلی؛ v90 (FEAT-044): در حالت Scale-in = سقف زنجیره
            if(slPipsCalc>0)
            {
               // v51 (parking lot, found in v50 testing): alertOnBlock=false - این صرفاً پیش‌نمایش
               // زنده‌ی hover (MOUSE_MOVE) هست، نه تصمیم واقعی معامله؛ لات پیشنهادی (حتی صفر) همچنان
               // روی لیبل نشون داده می‌شه، فقط دیگه موقع رد شدن ماوس از حالت‌های زیر MinLot/pval نامعتبر
               // popup نمی‌زنه. Alert واقعی همچنان روی کلیک واقعی (ProcessClick → AutoExecute) می‌مونه.
               lot = CalcLot(slPipsCalc, previewRisk, false);
               lossAmt   = NormalizeDouble(lot*slPipsCalc*pipVal,2);
               profitAmt = NormalizeDouble(lot*tpPipsCalc*pipVal,2);
            }

            // لیبل زنده روی خط SL در حال حرکت
            // v51 (Item 3، درخواست قبلی جا افتاده): عدد لات پیشنهادی (همون `lot` که چند خط بالاتر
            // از CalcLot(...,false) گرفته شد - آیتم ۲) الان کنار مبلغ ضرر لحظه‌ای هم نمایش داده می‌شه.
            if(ObjectFind(0,LN_CUR+"_LBL")<0) ObjectCreate(0,LN_CUR+"_LBL",OBJ_TEXT,0,0,0);
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_TIME,TimeCurrent());
            ObjectSetDouble (0,LN_CUR+"_LBL",OBJPROP_PRICE,price);
            ObjectSetString (0,LN_CUR+"_LBL",OBJPROP_TEXT,"Stop Loss  -$"+DoubleToStr(lossAmt,2)+"  (Lot "+DoubleToStr(lot,2)+")");
            // v51 (Item 4): رنگ ثابت clrWhite جاش رو به GetPreviewLabelColor() داد - همون رنگ سفید
            // به‌عنوان کاندید اولیه به ResolveFiboLineColor() پاس می‌شه و اگه با بک‌گراند کم‌کنتراست
            // بود خودکار جایگزین می‌شه (بالا، تعریف تابع).
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_COLOR,GetPreviewLabelColor());
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_FONTSIZE,9);
            ObjectSetString (0,LN_CUR+"_LBL",OBJPROP_FONT,"Arial Bold");
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_ANCHOR,ANCHOR_LOWER);
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_SELECTABLE,false);

            // لیبل زنده روی خط TP در حال حرکت
            if(ObjectFind(0,LN_TP+"_LBL")<0) ObjectCreate(0,LN_TP+"_LBL",OBJ_TEXT,0,0,0);
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_TIME,TimeCurrent());
            ObjectSetDouble (0,LN_TP+"_LBL",OBJPROP_PRICE,preTP);
            ObjectSetString (0,LN_TP+"_LBL",OBJPROP_TEXT,"Target  +$"+DoubleToStr(profitAmt,2));
            // v51 (Item 4): همون فیکس کنتراست بالا، برای یکدستی روی هر دو لیبل پیش‌نمایش hover.
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_COLOR,GetPreviewLabelColor());
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_FONTSIZE,9);
            ObjectSetString (0,LN_TP+"_LBL",OBJPROP_FONT,"Arial Bold");
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_ANCHOR,ANCHOR_LOWER);
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_SELECTABLE,false);

            // v36 (Change 5): پیش‌نمایش زنده‌ی نوع واقعی سفارش، کنار cursor - همون فرمول دقیقی
            // که AutoExecute() در لحظه‌ی اجرا استفاده می‌کنه (منطق دست‌نخورده، فقط همینجا هم
            // محاسبه شده تا تریدر قبل از کلیک بدونه واقعاً چی ثبت می‌شه).
            string ordTypeTxt; color ordTypeClr = pb?clrDodgerBlue:clrRed;
            if(g_mode==MODE_MARKET)
            {
               ordTypeTxt = pb?"BUY":"SELL";
            }
            else // MODE_PENDING - همون ۴ شاخه‌ی OP_BUYLIMIT/OP_BUYSTOP/OP_SELLLIMIT/OP_SELLSTOP در AutoExecute()
            {
               double midRef=(Ask+Bid)/2.0;
               if(pb && g_entryPrice<midRef)       ordTypeTxt="BUY LIMIT";
               else if(pb && g_entryPrice>midRef)   ordTypeTxt="BUY STOP";
               else if(!pb && g_entryPrice>midRef)  ordTypeTxt="SELL LIMIT";
               else if(!pb && g_entryPrice<midRef)  ordTypeTxt="SELL STOP";
               else                                 ordTypeTxt=pb?"BUY":"SELL"; // نادر: entry دقیقاً روی mid
            }
            if(ObjectFind(0,LN_TYPE)<0)
            {
               ObjectCreate(0,LN_TYPE,OBJ_LABEL,0,0,0);
               ObjectSetInteger(0,LN_TYPE,OBJPROP_CORNER,CORNER_LEFT_UPPER);
               ObjectSetInteger(0,LN_TYPE,OBJPROP_SELECTABLE,false);
               ObjectSetString (0,LN_TYPE,OBJPROP_FONT,"Arial Bold");
               ObjectSetInteger(0,LN_TYPE,OBJPROP_FONTSIZE,10);
            }
            ObjectSetInteger(0,LN_TYPE,OBJPROP_XDISTANCE,mx+18);
            ObjectSetInteger(0,LN_TYPE,OBJPROP_YDISTANCE,my-18);
            ObjectSetString (0,LN_TYPE,OBJPROP_TEXT,ordTypeTxt);
            ObjectSetInteger(0,LN_TYPE,OBJPROP_COLOR,ordTypeClr);
         }
         ChartRedraw();
      }
      return;
   }

   // v42 (Punch List follow-up, Mahmoud feedback): while an armed Fibo tool is waiting for a
   // click, a small text tag follows the cursor (LN_FIBOCURSOR, same screen-anchored
   // XDISTANCE/YDISTANCE pattern as the existing BUY/SELL order-type preview, LN_TYPE) - MQL4 has
   // no API to change the actual mouse cursor icon itself (that's a terminal-level feature,
   // unavailable without a DLL import), so this is the closest practical equivalent to MT4's own
   // native "waiting for a click" cue. Two phases: before the 1st click, just the tag (nothing to
   // draw yet); after it, the tag switches to "click end point" AND the live rubber-band preview
   // (added earlier this session) tracks the cursor as point 2 - matching MT4's own native Fibo
   // tool behavior.
   if(id == CHARTEVENT_MOUSE_MOVE && (g_fiboArmedRR || g_fiboArmedMeasure) && !g_fiboWaitingP2 && !IsOnPanel(mx,my))
   {
      string tagTxt1 = (g_fiboArmedRR ? "R/R: click start point" : "Measure Move: click start point");
      color  tagClr1 = g_fiboArmedRR ? GetFiboRRColor() : GetFiboMeasureColor();  // v42 follow-up (Mahmoud feedback): now matches the tool's actual line color, not an arbitrary fixed one
      if(ObjectFind(0,LN_FIBOCURSOR)<0)
      {
         ObjectCreate(0,LN_FIBOCURSOR,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_SELECTABLE,false);
         ObjectSetString (0,LN_FIBOCURSOR,OBJPROP_FONT,"Arial Bold");
         ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_FONTSIZE,10);
      }
      ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_XDISTANCE,mx+18);
      ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_YDISTANCE,my-18);
      ObjectSetString (0,LN_FIBOCURSOR,OBJPROP_TEXT,tagTxt1);
      ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_COLOR,tagClr1);
      ChartRedraw();
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE && (g_fiboArmedRR || g_fiboArmedMeasure) && g_fiboWaitingP2 && !IsOnPanel(mx,my))
   {
      datetime dt; double price; int win;
      if(ChartXYToTimePrice(0,mx,my,win,dt,price))
      {
         price = NormalizeDouble(price,Digits);
         if(g_fiboArmedRR)
            CreateFiboRMultiple(FIBO_RMULT_PREVIEW, g_fiboP1Time, g_fiboP1Price, dt, price, true);
         else
            CreateFiboMeasureMove(FIBO_MEASURE_PREVIEW, g_fiboP1Time, g_fiboP1Price, dt, price, true);
      }
      string tagTxt2 = (g_fiboArmedRR ? "R/R: click end point" : "Measure Move: click end point");
      color  tagClr2 = g_fiboArmedRR ? GetFiboRRColor() : GetFiboMeasureColor();  // v42 follow-up (Mahmoud feedback): now matches the tool's actual line color, not an arbitrary fixed one
      if(ObjectFind(0,LN_FIBOCURSOR)<0)
      {
         ObjectCreate(0,LN_FIBOCURSOR,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_SELECTABLE,false);
         ObjectSetString (0,LN_FIBOCURSOR,OBJPROP_FONT,"Arial Bold");
         ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_FONTSIZE,10);
      }
      ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_XDISTANCE,mx+18);
      ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_YDISTANCE,my-18);
      ObjectSetString (0,LN_FIBOCURSOR,OBJPROP_TEXT,tagTxt2);
      ObjectSetInteger(0,LN_FIBOCURSOR,OBJPROP_COLOR,tagClr2);
      ChartRedraw();
      return;
   }
   // نکته‌ی مهم (فیکس باگ): توی بعضی بیلدهای MT4، همون کلیک فیزیکی که روی دکمه‌ی BTN_FULL خورده و
   // OBJECT_CLICK رو برای بازکردن منو فایر کرده، بلافاصله بعدش یه CHARTEVENT_CLICK هم با همون
   // مختصات (که هنوز روی پنله) فایر می‌شه. اگه اینجا بدون چک IsOnPanel می‌بستیمش، همون کلیک اول
   // منو رو در همون تیک باز و فوراً بسته می‌کرد (کشو اصلاً دیده نمی‌شد). با اضافه‌کردن !IsOnPanel،
   // این بلاک فقط برای کلیک‌های واقعاً روی چارت (بیرون از کل پنل) فعال می‌شه.
   if(id == CHARTEVENT_CLICK && g_fullCloseMenuOpen && !IsOnPanel(mx,my))
   {
      CloseFullCloseMenu();
      ChartRedraw();
      return;
   }

   if(id == CHARTEVENT_CLICK && g_halfCloseMenuOpen && !IsOnPanel(mx,my))
   {
      CloseHalfCloseMenu();
      ChartRedraw();
      return;
   }

   if(id == CHARTEVENT_CLICK && g_step != STEP_IDLE && !IsOnPanel(mx,my))
   {
      datetime dt; double price; int win;
      if(ChartXYToTimePrice(0,mx,my,win,dt,price))
         ProcessClick(NormalizeDouble(price,Digits));
      return;
   }

   // v42 (Punch List, Item 1.1+1.2+1.3): R/R or Measure Move armed - capture the trader's own two
   // chart clicks (base point, then target point) as the Fibo anchor, exactly like MT4's native
   // Fibo/measure tools. Kept fully independent of g_step (the trade-entry click workflow above)
   // so arming a Fibo tool never interferes with an in-progress Market/Pending entry, or vice versa
   // - only one of the two click workflows can meaningfully be "active" at a time in practice, but
   // neither reads or writes the other's state.
   if(id == CHARTEVENT_CLICK && (g_fiboArmedRR || g_fiboArmedMeasure) && !IsOnPanel(mx,my))
   {
      datetime dt; double price; int win;
      if(ChartXYToTimePrice(0,mx,my,win,dt,price))
      {
         price = NormalizeDouble(price,Digits);
         if(!g_fiboWaitingP2)
         {
            g_fiboP1Time  = dt;
            g_fiboP1Price = price;
            g_fiboWaitingP2 = true;
            g_fiboArmDeadline = GetTickCount() + FIBO_ARM_MS;  // fresh window for the 2nd click (v54: 10s, was 5s)
            SetStatus(g_fiboArmedRR ? "R/R: click target point on chart" : "Measure Move: click target point on chart",
                      g_fiboArmedRR ? GetFiboRRColor() : GetFiboMeasureColor());  // v42 follow-up (Mahmoud feedback): matches the tool's actual line color
         }
         else
         {
            g_fiboInstanceSeq++;
            if(g_fiboArmedRR)
            {
               ObjectDelete(0, FIBO_RMULT_PREVIEW);  // v42 follow-up: swap the temp drag preview for the final, uniquely-named instance
               CreateFiboRMultiple(FIBO_RMULT_OBJ+"_"+IntegerToString(g_fiboInstanceSeq), g_fiboP1Time, g_fiboP1Price, dt, price);
            }
            else
            {
               ObjectDelete(0, FIBO_MEASURE_PREVIEW);  // v42 follow-up: swap the temp drag preview for the final, uniquely-named instance
               CreateFiboMeasureMove(FIBO_MEASURE_OBJ+"_"+IntegerToString(g_fiboInstanceSeq), g_fiboP1Time, g_fiboP1Price, dt, price);
            }
            CancelFiboArm();  // placement done - button back to grey, ready for a fresh arm next time
         }
         ChartRedraw();
      }
      return;
   }

   // v56.5 (Mahmoud - تصمیم نهایی): بلوک CHARTEVENT_OBJECT_ENDEDIT/CHANGE که قبلاً این‌جا بود
   // (برای باکس‌های OBJ_EDIT تایپ Strategy/Setup جدید) کامل حذف شد - دیگه هیچ OBJ_EDIT ای توی
   // پنجره‌ی تگ‌گذاری نیست (ببین توضیح کامل بالای OpenTagWindow()، RM_Tools.mqh).

   // v56 (Trade Tagging - Strategy/Setup): همه‌ی کلیک‌های پنجره‌ی تگ‌گذاری (پیشوند جدا
   // TAG_WIN_PREFIX، مستقل از پنل اصلی P="RM9_") این‌جا و فقط این‌جا هندل می‌شن - self-contained،
   // بعد از هر شاخه return می‌شه تا با بقیه‌ی دیسپچ پنل اصلی زیرش تداخل نکنه.
   // v90 (FEAT-044): کلیک‌های پنجره‌ی انتخاب زنجیره‌ی Scale-in (پیشوند جدا SCL_WIN_PREFIX) - self-contained، بعد از هر شاخه return.
   if(id == CHARTEVENT_OBJECT_CLICK && g_scaleInPickerOpen && StringFind(sp, SCL_WIN_PREFIX) == 0)
   {
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);
      if(sp == SCL_WIN_PREFIX+"CLOSE")
      {
         CloseScaleInPicker();
         UpdateScaleInButton();
         SetStatus("Scale-in: cancelled", clrOrange);
         return;
      }
      if(StringFind(sp, SCL_WIN_PREFIX+"ROW_") == 0)
      {
         int ri = (int)StringToInteger(StringSubstr(sp, StringLen(SCL_WIN_PREFIX+"ROW_")));
         ScaleInPickerSelect(ri);
         return;
      }
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK && g_tagWindowOpen && StringFind(sp, TAG_WIN_PREFIX) == 0)
   {
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);
      // v80 (BUG-056): MT4 بعد از هر OBJECT_CLICK روی دکمه، یه CHARTEVENT_CLICK هم برای همون کلیک
      // می‌فرسته - *بعد از* این‌که این هندلر پنجره رو rebuild کرده. زمان همین کلیک ثبت می‌شه تا
      // چک «کلیک بیرون پنجره» (پایین) اون رویداد دوم رو نادیده بگیره - ریشه‌ی BUG-056 توضیح داده شده اونجا.
      g_tagLastObjClickMs = GetTickCount();

      if(sp == TAG_WIN_PREFIX+"CLOSE")
      {
         CloseTagWindow();
         return;
      }
      if(sp == TAG_WIN_PREFIX+"BACK")
      {
         if(g_tagStep>0) g_tagStep--;
         BuildTagWindow();
         return;
      }
      if(g_tagStep==0 && StringFind(sp, TAG_WIN_PREFIX+"TRADE_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"TRADE_")));
         if(idx>=0 && idx<ArraySize(g_tagTodayTickets))
         {
            g_tagSelectedTicket = g_tagTodayTickets[idx];
            // v70 (Change 3): این تیکت اگه قبلاً تگ خورده باشه، Mental State خامش رو از قبل ست
            // می‌کنیم - همون متغیری که BuildTagWindow() برای هایلایت دکمه‌های Mental State
            // (استپ ۳) استفاده می‌کنه، پس نیازی به منطق هایلایت جدا نیست. GetTagMentalStateRaw()
            // "" برمی‌گردونه (نه "N/A" - اون فقط fallback نمایشی CSV Export‌ه) اگه تگ نخورده یا
            // Mental State ست نشده بود - دقیقاً همون رفتار "همه خاموش" فعلی حفظ می‌شه.
            // هایلایت Strategy/Setup توی BuildTagWindow() مستقیماً از GetTagStrategy/GetTagSetup
            // خونده می‌شه (نیازی به متغیر جدا نیست).
            g_tagSelectedMentalState = GetTagMentalStateRaw(g_tagSelectedTicket);
            // FEAT-037 (v81): همون الگو - چک‌لیست کانتکست persisted این تیکت (اگه از قبل انجام
            // شده) از قبل توی سشن ست می‌شه، تا BuildTagWindow() (استپ ۱) درست هایلایتش کنه.
            g_ctxSelLevel  = GetCtxLevelBool(g_tagSelectedTicket);
            g_ctxSelCycle  = GetCtxCycleBool(g_tagSelectedTicket);
            g_ctxSelTime   = GetCtxTimeBool(g_tagSelectedTicket);
            g_ctxSelCandle = GetCtxCandleBool(g_tagSelectedTicket);
            g_ctxSelNone   = GetCtxNoneBool(g_tagSelectedTicket);
            g_tagStep = 1;  // FEAT-037: استپ بعدی حالا چک‌لیست کانتکسته (نه Strategy)
            BuildTagWindow();
         }
         return;
      }
      // FEAT-037 (v81 - چک‌لیست کانتکست): چک "CTX_NEXT" باید *قبل* از چک عمومی پیشوندی "CTX_"
      // بیاد - وگرنه StringFind(sp, TAG_WIN_PREFIX+"CTX_")==0 اول می‌گیردش (چون "CTX_NEXT" هم با
      // همون پیشوند "CTX_" شروع می‌شه) و StringToInteger("NEXT") به‌جای رفتن به استپ بعد، اشتباهاً
      // idx=0 (گزینه‌ی اول) رو toggle می‌کنه - دقیقاً همون خانواده‌ی گارد MENTAL_CLEAR پایین‌تر.
      if(g_tagStep==1 && sp == TAG_WIN_PREFIX+"CTX_NEXT")
      {
         g_tagStep = 2;  // برو به Strategy
         BuildTagWindow();
         return;
      }
      if(g_tagStep==1 && StringFind(sp, TAG_WIN_PREFIX+"CTX_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"CTX_")));
         if(idx>=0 && idx<5)
         {
            // هرکدوم یه چک‌باکس مستقل - toggle ساده، بدون هیچ انحصار متقابلی بین ۵ گزینه (طبق تسک).
            if(idx==0)      g_ctxSelLevel  = !g_ctxSelLevel;
            else if(idx==1) g_ctxSelCycle  = !g_ctxSelCycle;
            else if(idx==2) g_ctxSelTime   = !g_ctxSelTime;
            else if(idx==3) g_ctxSelCandle = !g_ctxSelCandle;
            else if(idx==4) g_ctxSelNone   = !g_ctxSelNone;
            // هر toggle بلافاصله persist می‌شه - هم‌الگوی MENTAL_ پایین‌تر - تا اگه تریدر بدون زدن
            // NEXT پنجره رو ببنده، انتخاب‌هاش از دست نره.
            SetContextTag(g_tagSelectedTicket, g_ctxSelLevel, g_ctxSelCycle, g_ctxSelTime, g_ctxSelCandle, g_ctxSelNone);
            BuildTagWindow();
         }
         return;
      }
      // v56.5 (Mahmoud - تصمیم نهایی): STRAT_ADD/SETUP_ADD حذف شدن - دیگه OBJ_EDIT ای برای
      // تایپ نیست (ببین توضیح کامل بالای OpenTagWindow()، RM_Tools.mqh). استثنای "!=...EDIT"
      // زیر هم دیگه لازم نیست چون اون آبجکت‌ها اصلاً ساخته نمی‌شن.
      if(g_tagStep==2 && StringFind(sp, TAG_WIN_PREFIX+"STRAT_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"STRAT_")));
         if(idx>=0 && idx<g_stratCount)
         {
            g_tagSelectedStrategy = g_stratNames[idx];
            g_tagStep = 3;
            BuildTagWindow();
         }
         return;
      }
      // v69 (FEAT-026 - Mental State Tag): چک "MENTAL_CLEAR" باید *قبل* از چک عمومی پیشوندی
      // "MENTAL_" بیاد - وگرنه StringFind(sp, TAG_WIN_PREFIX+"MENTAL_")==0 اول می‌گیردش (چون
      // "MENTAL_CLEAR" هم با همون پیشوند "MENTAL_" شروع می‌شه) و StringToInteger("CLEAR") به‌جای
      // پاک کردن، اشتباهاً idx=0 (گزینه‌ی اول) رو انتخاب می‌کنه.
      if(g_tagStep==3 && sp == TAG_WIN_PREFIX+"MENTAL_CLEAR")
      {
         g_tagSelectedMentalState = "";
         // BUG-050 fix: قبلاً این‌جا فقط متغیر session پاک می‌شد و پنجره rebuild می‌شد - هیچ‌وقت
         // SetTradeTag() صدا زده نمی‌شد، پس پاک‌شدن Mental State هیچ‌وقت به RM_TradeTags.csv
         // نمی‌رسید. اینجا از GetTagStrategy/GetTagSetup (مقادیر واقعاً persisted شده‌ی همین
         // تیکت) استفاده می‌کنیم، نه متغیرهای session - تا اگه Strategy/Setup قبلاً برای این
         // تیکت ذخیره شده بودن، دست‌نخورده بمونن و فقط Mental State پاک بشه.
         SetTradeTag(g_tagSelectedTicket, GetTagStrategy(g_tagSelectedTicket), GetTagSetup(g_tagSelectedTicket), g_tagSelectedMentalState);
         BuildTagWindow();
         return;
      }
      if(g_tagStep==3 && StringFind(sp, TAG_WIN_PREFIX+"MENTAL_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"MENTAL_")));
         string mentalOpts[];
         int mc = GetMentalStateOptions(mentalOpts);
         if(idx>=0 && idx<mc)
         {
            // انتخاب دوباره‌ی همون گزینه = toggle خاموش (بازگشت به «انتخاب نشده») - رفتار
            // معمول این‌جور دکمه‌های تک‌انتخابی؛ کلیک روی گزینه‌ی دیگه هم به‌طور طبیعی جایگزینش می‌شه.
            g_tagSelectedMentalState = (g_tagSelectedMentalState==mentalOpts[idx]) ? "" : mentalOpts[idx];
            // BUG-050 fix: قبلاً این‌جا فقط متغیر session آپدیت و پنجره rebuild می‌شد - این دقیقاً
            // همون مسیریه که وقتی Mental State *بعد* از Setup زده می‌شه (رفتار عمدی v70 Change 2،
            // نگه‌داشتن پنجره باز) هیچ‌وقت SetTradeTag() صدا زده نمی‌شد و مقدار به CSV نمی‌رسید.
            // مثل MENTAL_CLEAR بالا، از GetTagStrategy/GetTagSetup (مقادیر persisted فعلی) استفاده
            // می‌کنیم، نه متغیرهای session، تا Strategy/Setup قبلاً-ذخیره‌شده دست‌نخورده بمونن.
            SetTradeTag(g_tagSelectedTicket, GetTagStrategy(g_tagSelectedTicket), GetTagSetup(g_tagSelectedTicket), g_tagSelectedMentalState);
            BuildTagWindow();
         }
         return;
      }
      if(g_tagStep==3 && StringFind(sp, TAG_WIN_PREFIX+"SETUP_")==0)  // FEAT-037 (v81): قبلاً g_tagStep==2 بود
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"SETUP_")));
         string setups[];
         int sc = GetSetupsForStrategy(g_tagSelectedStrategy, setups);
         if(idx>=0 && idx<sc)
         {
            SetTradeTag(g_tagSelectedTicket, g_tagSelectedStrategy, setups[idx], g_tagSelectedMentalState);
            SetStatus("Tagged #"+IntegerToString(g_tagSelectedTicket), clrLightGreen);
            // v70 (Change 2): پنجره دیگه با انتخاب Setup بسته نمی‌شه - فقط تگ ثبت و rebuild می‌شه
            // (تا دکمه‌ی Setup تازه‌تگ‌شده هم طبق منطق Change 3 هایلایت بشه) تا تریدر فرصت داشته
            // باشه Mental State رو هم (قبل یا بعد) بزنه. بستن فقط با X یا کلیک بیرون پنجره
            // (IsOnTagWindow()، پایین همین فایل / RM_Tools.mqh) انجام می‌شه.
            BuildTagWindow();
         }
         return;
      }
      return; // کلیک دیگه‌ای روی پنجره (مثلاً خود لیبل راهنما) - بدون اقدام، ولی جلوی افتادن به دیسپچ پنل اصلی گرفته می‌شه
   }

   // v70 (Change 2): کلیک روی چارت *بیرون* از پنجره‌ی TAG TRADE (و بیرون از پنل اصلی، چون دکمه‌ی
   // BTN_TAGTRADES خودش یه toggle جداست) پنجره رو می‌بنده - همون الگوی دقیق g_fullCloseMenuOpen/
   // g_halfCloseMenuOpen بالا (چک !IsOnPanel برای رد کلیک "ارتداد" همون تیکی که دکمه باز شد).
   // IsOnTagWindow() (RM_Tools.mqh) دقیقاً همون فرمول هندسی BuildTagWindow() رو برای محاسبه‌ی
   // محدوده‌ی پنجره (که با g_tagStep عوض می‌شه) تکرار می‌کنه.
   // v80 (BUG-056 - ریشه): این چک هندسه‌ی پنجره رو با g_tagStep *بعد از rebuild* حساب می‌کنه، ولی
   // نقطه‌ی کلیک مال پنجره‌ی *قبل از* rebuild بود. Step 1 (لیست Strategy: ۶ ردیف + راهنما) بلندتر از
   // Step 2 (۲-۳ Setup + راهنما) است - پس کلیک روی Strategy‌های پایینِ لیست (آخرین‌ها) بعد از رفتن به
   // Step 2 خارج از پنجره‌ی کوتاه‌تر حساب می‌شد و کل پنجره بسته می‌شد (= «گیر کردن»). همین خانواده‌ی
   // Step 0->1 هم هست (لیست معاملاتِ بلند). فیکس: کلیکی که تا TAG_OBJCLICK_GUARD_MS بعد از یک
   // OBJECT_CLICK روی همین پنجره برسه، کلیک بیرونی واقعی نیست. (هیچ آرایه‌ی ثابتی در کار نبود.)
   bool tagObjClickJustHandled = (g_tagLastObjClickMs != 0 && (GetTickCount() - g_tagLastObjClickMs) <= TAG_OBJCLICK_GUARD_MS);
   if(id == CHARTEVENT_CLICK && g_tagWindowOpen && !tagObjClickJustHandled && !IsOnPanel(mx,my) && !IsOnTagWindow(mx,my))
   {
      CloseTagWindow();
      ChartRedraw();
      return;
   }

   // v59 (Item 1 - Trade Identification): همه‌ی کلیک‌های پنجره‌ی انتخاب تک‌تیکت (پیشوند جدا
   // HALFSEL_WIN_PREFIX، مستقل از پنل اصلی) این‌جا و فقط این‌جا هندل می‌شن - self-contained، دقیقاً
   // همون الگوی بلوک TAG_WIN_PREFIX بالا.
   if(id == CHARTEVENT_OBJECT_CLICK && g_halfSelWindowOpen && StringFind(sp, HALFSEL_WIN_PREFIX) == 0)
   {
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);

      if(sp == HALFSEL_WIN_PREFIX+"CLOSE")
      {
         CloseHalfSelectWindow();
         return;
      }
      if(StringFind(sp, HALFSEL_WIN_PREFIX+"ROW_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(HALFSEL_WIN_PREFIX+"ROW_")));
         if(idx>=0 && idx<ArraySize(g_halfSelTickets))
         {
            int tkt = g_halfSelTickets[idx];
            CloseHalfSelectWindow();
            if(HalfCloseTicket(tkt, 50.0, "Half Close"))
            {
               SetStatus("Half Close #"+IntegerToString(tkt), clrYellow);
               StartButtonFlash(P+"BTN_HALF", CLR_FLASH_HALF, g_halfFlashEnd);
            }
            else
               SetStatus("Half Close #"+IntegerToString(tkt)+" failed", clrRed);
         }
         return;
      }
      return; // کلیک دیگه‌ای روی پنجره (مثلاً خود هدر) - بدون اقدام
   }

   // v59 (Item 3a - Ticket Label on Click): کلیک روی هر فلش Entry/Exit (پیشوند MARK_ENTRY_PREFIX/
   // MARK_EXIT_PREFIX، RM_Tools.mqh) لیبل شماره‌ی تیکت رو کنار هر دو فلش همون معامله toggle می‌کنه.
   // مستقل از دیسپچ پنل اصلی - قبل از هر چیز دیگه چک و در صورت match، return می‌شه.
   if(id == CHARTEVENT_OBJECT_CLICK && g_markersOn &&
      (StringFind(sp, MARK_ENTRY_PREFIX) == 0 || StringFind(sp, MARK_EXIT_PREFIX) == 0))
   {
      int tktFromMarker;
      if(StringFind(sp, MARK_ENTRY_PREFIX) == 0)
         tktFromMarker = (int)StringToInteger(StringSubstr(sp, StringLen(MARK_ENTRY_PREFIX)));
      else
         tktFromMarker = (int)StringToInteger(StringSubstr(sp, StringLen(MARK_EXIT_PREFIX)));

      ToggleMarkTicketLabel(tktFromMarker);
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);

      // v15 (Advanced Close Management): کلیک روی هر دکمه‌ی دیگه‌ای غیر از خود BTN_FULL و
      // ۴ گزینه‌ی زیرمنو، یعنی "جای دیگه" کلیک شده - طبق مشخصات، زیرمنو باید بدون اقدام بسته بشه.
      // این فقط زیرمنو رو می‌بنده و return نمی‌کنه، پس اکشن خود دکمه‌ی کلیک‌شده (مثلاً Half Close
      // یا Break Even) طبیعتاً و کامل زیرش اجرا می‌شه.
      if(g_fullCloseMenuOpen && sp!=P+"BTN_FULL" && sp!=P+"SUB_CLOSEALL" &&
         sp!=P+"SUB_CLOSECHART" && sp!=P+"SUB_CLOSEPROFIT" && sp!=P+"SUB_CLOSELOSS")
         CloseFullCloseMenu();

      if(g_halfCloseMenuOpen && sp!=P+"BTN_HALF" && sp!=P+"SUB_HALFALL" && sp!=P+"SUB_HALFPROFIT")
         CloseHalfCloseMenu();

      if(sp == P+"BTN_MIN")
      {
         g_minimized = !g_minimized;
         // v60 (فیدبک پیگیری - بستن خودکار پنجره‌ی Tag Trade موقع Minimize): پنجره‌ی Tag Trade
         // پیشوند کاملاً جدا و مستقلی داره (TAG_WIN_PREFIX ≠ P)، پس ObjectsDeleteAll(0, P) پایین‌تر
         // بهش دست نمی‌زنه و بدون این چک روی چارت یتیم می‌مونه، بی‌ارتباط با پنل والدش که minimize
         // شده. از همون CloseTagWindow() موجود استفاده می‌شه (دقیقاً همون تابعی که کلیک روی X یا
         // BTN_TAGTRADES موقع باز‌بودن صداش می‌زنه) - فقط وقتی داریم minimize می‌کنیم (نه وقتی
         // داریم دوباره باز می‌کنیم) و فقط اگه واقعاً باز باشه.
         if(g_minimized && g_tagWindowOpen) CloseTagWindow();
         if(g_minimized && g_scaleInPickerOpen) { CloseScaleInPicker(); }  // v90 (FEAT-044)
         // rebuild panel
         ObjectsDeleteAll(0, P);
         BuildPanel();
         ChartRedraw();
         return;
      }

      // v31: Dashboard Mode switch (Trading / Utility) - renamed from FULL/COMPACT, same mechanism
      // v43 (Item 1): while minimized, these tabs are still built/clickable (see BuildPanel()) but
      // previously only flipped g_dashboardMode internally - the panel stayed minimized and needed
      // a SEPARATE click on BTN_MIN to actually see the tab that was just selected. Clicking a tab
      // now also un-minimizes (opens/maximizes) the panel in the same click, so tab click always
      // means "show me that dashboard" regardless of prior minimized state.
      if(sp == P+"BTN_DASH_TRADING" && (g_dashboardMode != DASH_TRADING || g_minimized))
      {
         g_dashboardMode = DASH_TRADING;
         g_minimized = false;
         SaveDashboardModeState();
         ObjectsDeleteAll(0, P);
         BuildPanel();
         SetStatus("Dashboard: Trading", clrLimeGreen);
         ChartRedraw();
         return;
      }
      if(sp == P+"BTN_DASH_UTILITY" && (g_dashboardMode != DASH_UTILITY || g_minimized))
      {
         g_dashboardMode = DASH_UTILITY;
         g_minimized = false;
         SaveDashboardModeState();
         ObjectsDeleteAll(0, P);
         BuildPanel();
         SetStatus("Dashboard: Utility", clrLimeGreen);
         ChartRedraw();
         return;
      }

      // v90 (FEAT-044): انتخابگر Scale-in باز بود و تریدر مستقیم MARKET/PENDING زد -> انتخابگر بسته و Scale-in خاموش (ورود عادی)
      if((sp==P+"BTN_MARKET" || sp==P+"BTN_PENDING") && g_scaleInPickerOpen)
      { CloseScaleInPicker(); UpdateScaleInButton(); }
      if(sp==P+"BTN_SCALEIN") ScaleInButtonClick();   // v90 (FEAT-044)
      if(sp==P+"BTN_MARKET")
      {
         if(!IsTradingAllowed()) return;
         if(g_step!=STEP_IDLE && g_mode==MODE_MARKET)
         { g_step=STEP_IDLE; UpdateModeButtons(); ResetLines(); ScaleInTurnOff(); SetStatus("Cancelled",clrOrange); }
         else
         { ResetLines(); g_mode=MODE_MARKET; g_step=STEP_SL; UpdateModeButtons(); SetStatus(">> Click: SL level",clrYellow); }
      }
      if(sp==P+"BTN_PENDING")
      {
         if(!IsTradingAllowed()) return;
         if(g_step!=STEP_IDLE && g_mode==MODE_PENDING)
         { g_step=STEP_IDLE; UpdateModeButtons(); ResetLines(); ScaleInTurnOff(); SetStatus("Cancelled",clrOrange); }
         else
         { ResetLines(); g_mode=MODE_PENDING; g_step=STEP_ENTRY; UpdateModeButtons(); SetStatus(">> Click: Entry price",clrYellow); }
      }
      if(sp==P+"BTN_BE")      ManualBE();
      if(sp==P+"BTN_HALF")
      {
         if(g_halfCloseMenuOpen) CloseHalfCloseMenu();
         else                    OpenHalfCloseMenu();
      }
      if(sp==P+"SUB_HALFALL")      { CloseHalfCloseMenu(); HalfClose(false); }
      if(sp==P+"SUB_HALFPROFIT")   { CloseHalfCloseMenu(); HalfClose(true); }
      // v59 (Item 1 - Trade Identification): دکمه‌ی سوم زیرمنو - پنجره‌ی انتخاب تک‌تیکت رو باز می‌کنه
      if(sp==P+"SUB_HALFSELECT")   { CloseHalfCloseMenu(); OpenHalfSelectWindow(); }

      // v15 (Advanced Close Management): دکمه‌ی Full Close دیگه مستقیم همه‌چیز رو نمی‌بنده -
      // به‌جاش یه زیرمنوی ۴ گزینه‌ای (Close All / Close Chart / Close Profitable / Close Losing)
      // باز می‌کنه. کلیک دوباره روی همین دکمه در حالی که زیرمنو بازه => بستن بدون اقدام.
      if(sp==P+"BTN_FULL")
      {
         if(g_fullCloseMenuOpen) CloseFullCloseMenu();
         else                    OpenFullCloseMenu();
      }
      if(sp==P+"SUB_CLOSEALL")     { CloseFullCloseMenu(); FullClose(); }
      if(sp==P+"SUB_CLOSECHART")   { CloseFullCloseMenu(); CloseChartPositions(); }
      if(sp==P+"SUB_CLOSEPROFIT")  { CloseFullCloseMenu(); CloseProfitablePositions(); }
      if(sp==P+"SUB_CLOSELOSS")    { CloseFullCloseMenu(); CloseLosingPositions(); }
      // v7 (FEAT-002): دکمه‌ی Del Pending حذف شد؛ جاش رو دکمه‌ی Trailing (Toggle ON/OFF) گرفته
      if(sp==P+"BTN_TRAIL")
      {
         g_trailingButtonOn = !g_trailingButtonOn;
         if(g_trailingButtonOn)
         {
            SyncManualTrailing();  // فوراً معاملات باز فعلی رو زیر پوشش Trailing قرار بده
            SetStatus("Trailing: ON", C'0,180,180');
         }
         else
         {
            g_trailCount = 0;
            ArrayResize(g_trailTickets, 0);  // خاموش کردن کامل - همه از لیست پاک می‌شن
            ArrayResize(g_trailExtreme, 0);  // v12: هم‌ایندکس، باید هم‌زمان پاک بشه
            ArrayResize(g_trailPeriod,  0);  // v13
            ArrayResize(g_trailLastBar, 0);  // v13
            SetStatus("Trailing: OFF", C'150,150,150');
         }
         UpdateTrailButton();
      }
      if(sp==P+"BTN_RR")
      {
         CycleRR();
         UpdateRRButton();
         SetStatus("RR set to "+RRRatioText(), C'255,200,80');  // v45 (Punch List Round 3, Item 3): shares the same no-decimal formatter as the button caption
      }
      if(sp==P+"BTN_RISKTOGGLE")
      {
         CycleRiskStep();  // v84 (FEAT-038): Full -> 1/2 -> 1/4 -> 1/8 -> Full
         UpdateHalfRiskButton();
         SetStatus(RiskStepName(g_riskStep)+" Risk selected", (g_riskStep==0) ? C'170,30,30' : C'220,90,90');
      }

      // v27 (Change 2): "📊 Performance" box header - expand/collapse changes panel height (bodyH),
      // same rebuild pattern as BTN_TOOLS below (and BTN_DASH_TRADING/UTILITY above).
      if(sp == P+"BTN_PERF")
      {
         g_perfDrawerOpen = !g_perfDrawerOpen;
         ObjectsDeleteAll(0, P);
         BuildPanel();
         SetStatus(g_perfDrawerOpen ? "Performance: expanded" : "Performance: collapsed", C'150,160,180');
         ChartRedraw();
         return;
      }

      // v43 (Item 3): BTN_TOOLS click handler removed entirely - "Tools" is now a static section
      // separator only (buttons below it are always visible, no expand/collapse), so clicking the
      // header itself does nothing.

      // v35 (Utility Phase A, Part 2): "Trading Reports" drawer header - expand/collapse changes
      // panel height (bodyH), so it needs a full rebuild, same pattern as BTN_TOOLS/BTN_PERF above.
      if(sp == P+"BTN_REPORTS")
      {
         g_reportsDrawerOpen = !g_reportsDrawerOpen;
         ObjectsDeleteAll(0, P);
         BuildPanel();
         SetStatus(g_reportsDrawerOpen ? "Trading Reports: expanded" : "Trading Reports: collapsed", C'150,160,180');
         ChartRedraw();
         return;
      }

      // v35: Daily/Weekly/Monthly report tabs - only change which period's stats are shown, same
      // row count/panel height either way, so (like BTN_CANDLETIMER etc. below) no full rebuild is
      // needed - just flip the selected period and refresh the tab colors + metric text in place.
      if(sp == P+"BTN_REP_DAILY" && g_reportsPeriod != 0)
      {
         g_reportsPeriod = 0;
         UpdateReportsDisplay();
      }
      if(sp == P+"BTN_REP_WEEKLY" && g_reportsPeriod != 1)
      {
         g_reportsPeriod = 1;
         UpdateReportsDisplay();
      }
      if(sp == P+"BTN_REP_MONTHLY" && g_reportsPeriod != 2)
      {
         g_reportsPeriod = 2;
         UpdateReportsDisplay();
      }

      // v79 (Item 4): بلوک توگل Candle Timer حذف شد - دکمه‌ی BTN_CANDLETIMER دیگه وجود نداره؛
      // شمارش معکوس همیشه‌فعاله (مستقیماً از OnInit()).

      // v33/v34 (Tools Refinements): remaining Tools toggles/actions - same "no full panel
      // rebuild" pattern as BTN_CANDLETIMER above, since none of these change the drawer's row
      // count/panel height.
      // v34 (Items 3+5): PD/PW replaced by three fully independent Daily/Weekly/Monthly toggles.
      if(sp == P+"BTN_HLDAILY")
      {
         g_hlDailyOn = !g_hlDailyOn;
         if(!g_hlDailyOn) RemoveDailyHL(); else UpdateDailyHL();
         UpdateHLDailyButton();
         SetStatus(g_hlDailyOn ? "Daily High-Low: ON" : "Daily High-Low: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_HLWEEKLY")
      {
         g_hlWeeklyOn = !g_hlWeeklyOn;
         if(!g_hlWeeklyOn) RemoveWeeklyHL(); else UpdateWeeklyHL();
         UpdateHLWeeklyButton();
         SetStatus(g_hlWeeklyOn ? "Weekly High-Low: ON" : "Weekly High-Low: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_HLMONTHLY")
      {
         g_hlMonthlyOn = !g_hlMonthlyOn;
         if(!g_hlMonthlyOn) RemoveMonthlyHL(); else UpdateMonthlyHL();
         UpdateHLMonthlyButton();
         SetStatus(g_hlMonthlyOn ? "Monthly High-Low: ON" : "Monthly High-Low: OFF", C'150,160,180');
      }
      // v34 (Item 2)/v34.4: Hide/Show's indicator side (BTN_HIDEIND) removed entirely - only the
      // chart-objects toggle remains.
      if(sp == P+"BTN_HIDEOBJ")
      {
         ToggleHideObjects();
         UpdateHideObjButton();
      }
      if(sp == P+"BTN_BEREF")
      {
         g_beRefOn = !g_beRefOn;
         if(!g_beRefOn) RemoveBERefLines(); else UpdateBERefLine();
         UpdateBERefButton();
         SetStatus(g_beRefOn ? "BE Reference Line: ON" : "BE Reference Line: OFF", C'150,160,180');
      }
      // v85: History - toggle + GlobalVariable persistence (همان الگوی Session Level / Key Time)
      if(sp == P+"BTN_HISTORY")
      {
         g_histOn = !g_histOn;
         History_SaveState();
         History_Build();   // روشن: رسم؛ خاموش: History_Remove داخل Build انجام می‌شه و برمی‌گرده
         UpdateHistoryButton();
         SetStatus(g_histOn ? "History: ON (" + IntegerToString(g_histDrawn) + " trades, " + IntegerToString((int)MathMax(1, HistoryDaysBack)) + "d)" : "History: OFF", C'150,160,180');
      }
      // v54: Session Windows toggle - same click-toggle + GlobalVariable persistence pattern as
      // Candle Timer/Daily H/L (display preference, not a risk/balance value). BuildSessionWindows()
      // does its own no-op/cleanup when g_swOn is false, same idempotent shape as the other tools.
      if(sp == P+"BTN_SW")
      {
         g_swOn = !g_swOn;
         SaveSessionWindowsState();
         BuildSessionWindows();  // ON: (re)builds today + history; OFF: BuildSessionWindows() calls RemoveSessionWindows() and returns
         UpdateSWButton();
         SetStatus(g_swOn ? "Key Time: ON" : "Key Time: OFF", C'150,160,180');  // v57.1: متن وضعیت هم‌راستا با کپشن جدید دکمه شد
      }
      // v57: Session Level toggle - همون الگوی click-toggle + GlobalVariable persistence که
      // Session Windows/Candle Timer/Daily H/L استفاده می‌کنن (یه display preference‌ه، نه یه
      // مقدار ریسک/بالانس). SessionLevel_BuildWindows() خودش idempotent پاک‌سازی می‌کنه وقتی خاموشه.
      if(sp == P+"BTN_SESSLVL")
      {
         g_sessLvlOn = !g_sessLvlOn;
         SessionLevel_SaveState();
         SessionLevel_BuildWindows();
         UpdateSessLvlButton();
         SetStatus(g_sessLvlOn ? "Session Level: ON" : "Session Level: OFF", C'150,160,180');
      }
      // v57: Entry/Exit Markers toggle - همون الگو. BuildEntryExitMarkers() خودش idempotent
      // پاک‌سازی می‌کنه وقتی خاموشه.
      if(sp == P+"BTN_MARKERS")
      {
         g_markersOn = !g_markersOn;
         SaveEntryExitMarkersState();
         BuildEntryExitMarkers();
         UpdateMarkersButton();
         SetStatus(g_markersOn ? "Entry/Exit Markers: ON" : "Entry/Exit Markers: OFF", C'150,160,180');
      }
      // v42 (Punch List, Item 1.1+1.2+1.3): clicking the button no longer auto-places instantly -
      // it arms the tool (teal, Item 1.4) and waits for two chart clicks (captured in the
      // CHARTEVENT_CLICK block below) to place it exactly where the trader points. Clicking an
      // already-armed button again cancels the arm instead of re-arming.
      if(sp == P+"BTN_FIBRMULT")  // v34.4 (Item 7): button now labeled "R/R" on the panel
      {
         if(g_fiboArmedRR) { CancelFiboArm(); SetStatus("Cancelled", clrOrange); }
         else ArmFiboTool(1);
      }
      if(sp == P+"BTN_FIBMEASURE")  // v34 (Item 4) / v34.4 (Item 8): button now labeled "Measure Move" on the panel
      {
         if(g_fiboArmedMeasure) { CancelFiboArm(); SetStatus("Cancelled", clrOrange); }
         else ArmFiboTool(2);
      }

      // v55 (CSV Export - Trade Journal پایه): Action button (نه Toggle) - هر کلیک بلافاصله
      // یه فایل CSV جدید توی MQL4/Files می‌نویسه (ExportTradeJournalCSV، RM_Reports.mqh) و
      // نتیجه رو توی Status Bar نشون می‌ده. هیچ حالتی نگه نمی‌داره، پس نیازی به رنگ toggle یا
      // Update تابع جدا نداره - همون الگوی BTN_BE/BTN_HALF/BTN_FULL (Action pattern، بخش 8
      // مستندات UI Design Philosophy).
      // v55.1 (فیکس - گزارش Mahmoud): پیام قبلی شامل اسم کامل فایل بود ("CSV Exported: RM_Trade
      // Journal_12345_1785225580.csv"، ~۵۰ کاراکتر) که از سقف طول FitBoxFont() (>36 کاراکتر ->
      // فونت سایز ۶، بدون هیچ محدودیت عرض‌آگاهی مثل FitBoxFontHalf) عبور می‌کرد و از کادر Status
      // Bar بیرون می‌زد - دقیقاً همون کلاس مشکلی که BUG-003 (v9.4/v9.7) قبلاً برای همین جعبه حل
      // کرده بود: راه‌حل، کوتاه نگه‌داشتن متن روی پنله، نه بازنویسی FitBoxFont(). اسم کامل فایل
      // حذف نشده - توی Experts log (Print) ثبت می‌شه تا محمود بتونه هر وقت لازم شد پیداش کنه.
      if(sp == P+"BTN_EXPORTCSV")
      {
         string exportedFile = "";
         if(ExportTradeJournalCSV(exportedFile))
         {
            Print("RM: CSV Trade Journal exported -> ", exportedFile);
            SetStatus("CSV Exported", clrLightGreen);
         }
         else
            SetStatus("CSV Export Failed", clrRed);
         // v60 (EXPORT CSV Feedback): همون الگوی StartButtonFlash موجود برای BE/Half/Full - دکمه
         // ۵ ثانیه فیروزه‌ای (CLR_TOOLS_ACTIVE) می‌شه و بعد CheckButtonFlashExpiry() برش می‌گردونه
         // به CLR_BTN_DEFAULT. مستقل از نتیجه‌ی export (موفق یا ناموفق) چون این فقط تأیید کلیکه.
         StartButtonFlash(P+"BTN_EXPORTCSV", CLR_TOOLS_ACTIVE, g_exportFlashEnd);
      }

      // v56 (Trade Tagging - Strategy/Setup): Action button - باز/بسته می‌کنه پنجره‌ی تگ‌گذاری
      // (OpenTagWindow/CloseTagWindow، RM_Tools.mqh). خود پنجره پیشوند و دیسپچ کاملاً جدا داره
      // (TAG_WIN_PREFIX، بالای همین OnChartEvent) - این‌جا فقط toggle باز/بسته‌شدنشه.
      if(sp == P+"BTN_TAGTRADES")
      {
         if(g_tagWindowOpen) CloseTagWindow();
         else                OpenTagWindow();
      }

      // v34.4 (Item 6): Risk Lab / Journal / AI Coach are silent placeholders now - no status
      // message, no functionality, nothing happens on click. Dimmed text alone (set in
      // BuildPanel()) conveys their inactive state.
      ChartRedraw();
   }
}


// === v11 (FEAT-016): R تجمعی یک دوره - مجموع (سود/ضرر واقعی‌شده ÷ Initial Risk($)) همه‌ی
// معاملات بسته‌شده‌ی اون دوره. عمداً مثل CalcNetResultPercent هر بار از روی تاریخچه محاسبه می‌شه
// (نه یک accumulator ذخیره‌شده) - دقیقاً همون درسی که از بازنویسی BUG-012 گرفته شد: accumulator
// مستعد drift/باگه، اسکن مستقیم از OrdersHistoryTotal همیشه نتیجه‌ی درست رو می‌ده.
double CalcNetResultR(datetime periodStart)
{
   double totalR = 0;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderCloseTime()<periodStart) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;

      int idx = FindSnapshotIndex(OrderTicket());
      if(idx<0) continue;               // بدون Snapshot (مثلاً معامله‌ی قبل از نصب v11) - قابل محاسبه نیست
      if(SnapRiskBase(idx)<=0) continue;

      // v90 (FEAT-044): پایه‌ی R = RiskBaseUSD (معامله‌ی عادی/باقی‌مانده‌ی Half Close = RiskUSD خودش، بدون تغییر عددی؛ ورود ادامه = ریسک ریشه)
      // تا مجموع R بخش‌های یک زنجیره با «سود خالص ÷ ریسک ریشه» در Reports هم‌خوان بماند. زمان‌بندی (Q4-A: هر بخش لحظه‌ی بسته‌شدنش) دست‌نخورده.
      totalR += (OrderProfit()+OrderSwap()+OrderCommission())/SnapRiskBase(idx);
   }
   return totalR;
}

double GetDailyR()   { return CalcNetResultR(g_dayStart); }
double GetWeeklyR()  { return CalcNetResultR(g_weekStart); }
double GetMonthlyR() { return CalcNetResultR(g_monthStart); }

// === v25 (FEAT-017): RB (Base R) - مجموع نسخه‌ی وزن‌دهی‌شده‌ی R هر معامله‌ی بسته‌شده‌ی یک دوره.
// هر معامله‌ی Half Risk (بر اساس g_snapWasHalfRisk همون Snapshot) با ضریب 0.5 به‌جای 1.0 اضافه
// می‌شه. کاملاً مستقل از CalcNetResultR - همون Trade R واقعی هر معامله (شامل خروج زودهنگام با
// R جزئی) رو می‌خونه و فقط قبل از جمع زدن در ضریب ضرب می‌کنه؛ خود CalcNetResultR/GetDailyR/
// GetWeeklyR/GetMonthlyR و هر چیزی که به اونا وابسته‌ست (Drawdown%, Cooldown, قفل‌ها) دست‌نخورده می‌مونه.
// فال‌بک Legacy: تیکت بدون Snapshot (پیش از v11) مثل CalcNetResultR نادیده گرفته می‌شه (قابل
// محاسبه نیست)؛ تیکتی که Snapshot داره ولی WasHalfRisk قدیمی/غایبه (پیش از v19)، g_snapWasHalfRisk
// از قبل توسط LoadTradeSnapshots() به false فال‌بک شده (همون فلسفه‌ی محافظه‌کارانه‌ی بقیه‌ی Snapshot) -
// یعنی اینجا خودکار Full Risk (RB == R) در نظر گرفته می‌شه، بدون نیاز به منطق فال‌بک اضافه.
double CalcNetResultRB(datetime periodStart)
{
   double totalRB = 0;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderCloseTime()<periodStart) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;

      int idx = FindSnapshotIndex(OrderTicket());
      if(idx<0) continue;               // بدون Snapshot - مثل CalcNetResultR، قابل محاسبه نیست
      if(g_snapRiskUSD[idx]<=0) continue;

      double tradeR = (OrderProfit()+OrderSwap()+OrderCommission())/g_snapRiskUSD[idx];
      double factor = SnapRiskWeight(idx);  // v84 (FEAT-038 Addendum): وزن دقیق پله (1/0.5/0.25/0.125)؛ Snapshot قدیمی -> همان ۰.۵/۱.۰ بولین
      totalRB += tradeR * factor;
   }
   return totalRB;
}

double GetDailyRB()   { return CalcNetResultRB(g_dayStart); }
double GetWeeklyRB()  { return CalcNetResultRB(g_weekStart); }
double GetMonthlyRB() { return CalcNetResultRB(g_monthStart); }



// v11: لیست تیکت‌های باز فعلی (کل حساب) - برای تشخیص تیکت جدیدی که MT4 موقع Half Close
// برای باقیمونده‌ی پوزیشن می‌سازه (قبل/بعد از OrderClose مقایسه می‌شن)
void CaptureOpenTickets(int &list[])
{
   int total = OrdersTotal();
   ArrayResize(list, total);
   for(int p=0;p<total;p++)
   {
      if(OrderSelect(p, SELECT_BY_POS, MODE_TRADES))
         list[p] = OrderTicket();
   }
}

bool TicketInList(int ticket, int &list[])
{
   for(int k=0;k<ArraySize(list);k++)
      if(list[k]==ticket) return true;
   return false;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
// Track open trades for manual close detection
//+------------------------------------------------------------------+

// Global Variables for state storage
// v53 (شمارنده‌های Market/Behavior Cooldown مشترک بین چارت‌ها): فلسفه‌ی این دو Cooldown
// درباره‌ی رفتار/روانشناسی خودِ تریدره، نه یه نماد خاص - دقیقاً هم‌فلسفه‌ی Performance/Reports
// که از قبل account-wide (فقط AccountNumber()+MagicNumber، بدون Symbol) کار می‌کنه. کلید این سه
// GV (دو شمارنده + کمکی مستقیم‌شون g_lastStopCloseTime) از per-symbol به account-wide تغییر کرد -
// دقیقاً همون الگوی AccountNumber()+MagicNumber که BUG-029 برای GV_DAY_START و بقیه معرفی کرد.
// v77 (اصلاحِ تداخلِ بین‌اکانتی): تصمیمِ قبلیِ v53 که GV_MKT_END/GV_BEH_END/GV_LAST_ENTRY رو per-symbol
// (بدون AccountNumber) نگه می‌داشت، فرضش «یک اکانت روی ترمینال» بود. در عمل، دو اکانتِ هم‌نماد روی یک
// ترمینال این سه کلید رو مشترک می‌کردن → strikeِ کاذبِ فاصله‌ی ورود و نشتِ زمانِ پایانِ قفل بین اکانت‌ها.
// حالا هر سه هم account-scoped شدن (A<حساب>_M<مجیک>_<نماد>): جداییِ کامل بین اکانت‌ها، ضمنِ حفظِ
// اشتراکِ per-symbol/بین‌چارت داخلِ یک اکانت. مقداردهیِ همه‌ی این کلیدهای حساب‌محور به
// BuildAccountScopedKeys() منتقل شد (تک‌منبع؛ rebuild در هر OnInit تا سوییچِ حساب کهنه‌شون نکنه).
string GV_MKT_COUNT  = "";
string GV_MKT_END    = "";
string GV_BEH_COUNT  = "";
string GV_BEH_END    = "";
string GV_LAST_ENTRY = "";
string GV_LAST_STOP_CLOSE = "";  // v13 (BUG-017); v53: account-wide; v77: در BuildAccountScopedKeys()
// v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله): شمارنده‌ی یکپارچه‌ی رویدادهای رفتاری واقعی (SL
// Tampering strike / Entry Interval violation / باز شدن معامله وسط قفل Cooldown فعال) - دقیقاً
// هم‌فلسفه‌ی GV_MKT_COUNT/GV_BEH_COUNT بالا: account-wide (AccountNumber()+MagicNumber)، نه
// per-symbol. برخلاف اون دو، این یکی هیچ‌وقت ریست نمی‌شه (نه با قفل، نه با +1R) - فقط برای
// Snapshot لحظه‌ی باز شدن هر معامله (BehaviorErrorCountAtOpen) خونده می‌شه، هیچ نمایش داشبوردی نداره.
string GV_BEHERR_TOTAL = "";  // v77 (Pattern B fix): ساخته‌شده در BuildAccountScopedKeys()

// === v77 (Pattern B fix - تک‌منبعِ کلیدهای حساب‌محور) =================================
// همه‌ی کلیدهای GlobalVariable که به AccountNumber() بسته‌ان اینجا (و فقط اینجا) ساخته می‌شن.
// این تابع اولِ OnInit صدا زده می‌شه (قبل از هر Load*State) و در هر OnInit دوباره اجرا می‌شه.
// چرا: رشته‌های global فقط یک‌بار موقع لودِ برنامه ارزیابی می‌شن؛ سوییچِ حساب داخلِ همون ترمینال
// OnInit رو صدا می‌زنه ولی این رشته‌ها رو دوباره نمی‌سازه → کلید به حسابِ *قبلی* اشاره می‌مونه و
// مقدارِ حسابِ فعلی زیر کلیدِ حسابِ دیگه نوشته/خونده می‌شه (ریشه‌ی قفل کاذبِ DD - رگرسیونِ BUG-029).
// با rebuildِ صریح در هر OnInit، کلیدها همیشه با AccountNumber()ِ زنده هم‌خوان می‌مونن.
// نکته: فرمتِ کلیدها اینجا باید تنها نسخه‌ی موجود باشه - در محلِ declaration فقط "" مقداردهی شدن.

// === v102: تنظیمات مشترک بین چارت‌ها (بلوک GV حساب‌محور) ===============================================
// ورودی‌های مشترک با پیشوند In_ در RM_Config.mqh. چارتی که PublishSettings=true دارد مقدارهای خودش را می‌نویسد؛
// بقیه‌ی چارت‌ها (PublishSettings=false) مقدارها را از بلوک می‌خوانند و هر تیک فقط یک GlobalVariableGet برای تغییر نسخه می‌زنند.
string RM_CfgKey(string n) { return "RM_CFG_A" + IntegerToString(AccountNumber()) + "_M" + IntegerToString(MagicNumber) + "_" + n; }
string RM_CfgVerKey()      { return RM_CfgKey("VER"); }
double g_cfgVerSeen = 0;

void RM_CfgPublish()
{
   // v102 (fix): در MQL4 با تغییر پارامتر (OK در پنجره‌ی ورودی‌ها) متغیرهای سراسری دوباره مقداردهی نمی‌شوند و مقدار قبلی (از بلوک) می‌ماند؛
   // پس انتشار باید مستقیماً از ورودی‌های In_ باشد، نه از متغیرهای سراسری - وگرنه مقدار تازه‌ی تایپ‌شده منتشر نمی‌شد.
   MaxTotalRisk = In_MaxTotalRisk;
   MaxDailyNetLossAllowed = In_MaxDailyNetLossAllowed;
   EnableDailyDD = In_EnableDailyDD;
   DailyDDLockHours = In_DailyDDLockHours;
   MaxWeeklyNetLossAllowed = In_MaxWeeklyNetLossAllowed;
   EnableWeeklyDD = In_EnableWeeklyDD;
   WeeklyDDHours = In_WeeklyDDHours;
   MaxMonthlyNetLossAllowed = In_MaxMonthlyNetLossAllowed;
   EnableMonthlyDD = In_EnableMonthlyDD;
   MonthlyDDDays = In_MonthlyDDDays;
   InpEnableFloatingDD = In_InpEnableFloatingDD;
   InpMaxFloatingDDPercent = In_InpMaxFloatingDDPercent;
   EnableMarketCD = In_EnableMarketCD;
   MarketCDCount = In_MarketCDCount;
   MarketCDHours = In_MarketCDHours;
   MarketCDResetHours = In_MarketCDResetHours;
   EnableBehaviorCD = In_EnableBehaviorCD;
   BehaviorCDCount = In_BehaviorCDCount;
   BehaviorCDHours = In_BehaviorCDHours;
   EnableEntryInterval = In_EnableEntryInterval;
   MinEntryIntervalMinutes = In_MinEntryIntervalMinutes;
   MaxSLWidenMultiplier = In_MaxSLWidenMultiplier;
   GlobalVariableSet(RM_CfgKey("MaxTotalRisk"), MaxTotalRisk);
   GlobalVariableSet(RM_CfgKey("MaxDailyNetLossAllowed"), MaxDailyNetLossAllowed);
   GlobalVariableSet(RM_CfgKey("EnableDailyDD"), (double)EnableDailyDD);
   GlobalVariableSet(RM_CfgKey("DailyDDLockHours"), (double)DailyDDLockHours);
   GlobalVariableSet(RM_CfgKey("MaxWeeklyNetLossAllowed"), MaxWeeklyNetLossAllowed);
   GlobalVariableSet(RM_CfgKey("EnableWeeklyDD"), (double)EnableWeeklyDD);
   GlobalVariableSet(RM_CfgKey("WeeklyDDHours"), (double)WeeklyDDHours);
   GlobalVariableSet(RM_CfgKey("MaxMonthlyNetLossAllowed"), MaxMonthlyNetLossAllowed);
   GlobalVariableSet(RM_CfgKey("EnableMonthlyDD"), (double)EnableMonthlyDD);
   GlobalVariableSet(RM_CfgKey("MonthlyDDDays"), (double)MonthlyDDDays);
   GlobalVariableSet(RM_CfgKey("InpEnableFloatingDD"), (double)InpEnableFloatingDD);
   GlobalVariableSet(RM_CfgKey("InpMaxFloatingDDPercent"), InpMaxFloatingDDPercent);
   GlobalVariableSet(RM_CfgKey("EnableMarketCD"), (double)EnableMarketCD);
   GlobalVariableSet(RM_CfgKey("MarketCDCount"), (double)MarketCDCount);
   GlobalVariableSet(RM_CfgKey("MarketCDHours"), (double)MarketCDHours);
   GlobalVariableSet(RM_CfgKey("MarketCDResetHours"), (double)MarketCDResetHours);
   GlobalVariableSet(RM_CfgKey("EnableBehaviorCD"), (double)EnableBehaviorCD);
   GlobalVariableSet(RM_CfgKey("BehaviorCDCount"), (double)BehaviorCDCount);
   GlobalVariableSet(RM_CfgKey("BehaviorCDHours"), (double)BehaviorCDHours);
   GlobalVariableSet(RM_CfgKey("EnableEntryInterval"), (double)EnableEntryInterval);
   GlobalVariableSet(RM_CfgKey("MinEntryIntervalMinutes"), (double)MinEntryIntervalMinutes);
   GlobalVariableSet(RM_CfgKey("MaxSLWidenMultiplier"), MaxSLWidenMultiplier);
   double ver = GlobalVariableCheck(RM_CfgVerKey()) ? GlobalVariableGet(RM_CfgVerKey()) : 0.0;
   ver += 1.0;
   GlobalVariableSet(RM_CfgVerKey(), ver);
   g_cfgVerSeen = ver;
}

void RM_CfgApply()
{
   string k;
   k = RM_CfgKey("MaxTotalRisk"); if(GlobalVariableCheck(k)) MaxTotalRisk = GlobalVariableGet(k);
   k = RM_CfgKey("MaxDailyNetLossAllowed"); if(GlobalVariableCheck(k)) MaxDailyNetLossAllowed = GlobalVariableGet(k);
   k = RM_CfgKey("EnableDailyDD"); if(GlobalVariableCheck(k)) EnableDailyDD = (GlobalVariableGet(k) > 0.5);
   k = RM_CfgKey("DailyDDLockHours"); if(GlobalVariableCheck(k)) DailyDDLockHours = (int)MathRound(GlobalVariableGet(k));
   k = RM_CfgKey("MaxWeeklyNetLossAllowed"); if(GlobalVariableCheck(k)) MaxWeeklyNetLossAllowed = GlobalVariableGet(k);
   k = RM_CfgKey("EnableWeeklyDD"); if(GlobalVariableCheck(k)) EnableWeeklyDD = (GlobalVariableGet(k) > 0.5);
   k = RM_CfgKey("WeeklyDDHours"); if(GlobalVariableCheck(k)) WeeklyDDHours = (int)MathRound(GlobalVariableGet(k));
   k = RM_CfgKey("MaxMonthlyNetLossAllowed"); if(GlobalVariableCheck(k)) MaxMonthlyNetLossAllowed = GlobalVariableGet(k);
   k = RM_CfgKey("EnableMonthlyDD"); if(GlobalVariableCheck(k)) EnableMonthlyDD = (GlobalVariableGet(k) > 0.5);
   k = RM_CfgKey("MonthlyDDDays"); if(GlobalVariableCheck(k)) MonthlyDDDays = (int)MathRound(GlobalVariableGet(k));
   k = RM_CfgKey("InpEnableFloatingDD"); if(GlobalVariableCheck(k)) InpEnableFloatingDD = (GlobalVariableGet(k) > 0.5);
   k = RM_CfgKey("InpMaxFloatingDDPercent"); if(GlobalVariableCheck(k)) InpMaxFloatingDDPercent = GlobalVariableGet(k);
   k = RM_CfgKey("EnableMarketCD"); if(GlobalVariableCheck(k)) EnableMarketCD = (GlobalVariableGet(k) > 0.5);
   k = RM_CfgKey("MarketCDCount"); if(GlobalVariableCheck(k)) MarketCDCount = (int)MathRound(GlobalVariableGet(k));
   k = RM_CfgKey("MarketCDHours"); if(GlobalVariableCheck(k)) MarketCDHours = (int)MathRound(GlobalVariableGet(k));
   k = RM_CfgKey("MarketCDResetHours"); if(GlobalVariableCheck(k)) MarketCDResetHours = (int)MathRound(GlobalVariableGet(k));
   k = RM_CfgKey("EnableBehaviorCD"); if(GlobalVariableCheck(k)) EnableBehaviorCD = (GlobalVariableGet(k) > 0.5);
   k = RM_CfgKey("BehaviorCDCount"); if(GlobalVariableCheck(k)) BehaviorCDCount = (int)MathRound(GlobalVariableGet(k));
   k = RM_CfgKey("BehaviorCDHours"); if(GlobalVariableCheck(k)) BehaviorCDHours = (int)MathRound(GlobalVariableGet(k));
   k = RM_CfgKey("EnableEntryInterval"); if(GlobalVariableCheck(k)) EnableEntryInterval = (GlobalVariableGet(k) > 0.5);
   k = RM_CfgKey("MinEntryIntervalMinutes"); if(GlobalVariableCheck(k)) MinEntryIntervalMinutes = (int)MathRound(GlobalVariableGet(k));
   k = RM_CfgKey("MaxSLWidenMultiplier"); if(GlobalVariableCheck(k)) MaxSLWidenMultiplier = GlobalVariableGet(k);
   g_cfgVerSeen = GlobalVariableCheck(RM_CfgVerKey()) ? GlobalVariableGet(RM_CfgVerKey()) : 0.0;
}

// v104: Publish خودکار - فقط فیلدی که کاربر همین الان در پنجره‌ی ورودی‌ها عوض کرده منتشر می‌شود (بدون نیاز به PublishSettings)
// مقدار قبلی ورودی‌های In_ در g_cfgPrevIn نگه داشته می‌شود (در MQL4 با تغییر پارامتر، متغیرهای سراسری حفظ می‌شوند).
#define RM_CFG_N 22
string g_cfgNames = "MaxTotalRisk,MaxDailyNetLossAllowed,EnableDailyDD,DailyDDLockHours,MaxWeeklyNetLossAllowed,EnableWeeklyDD,WeeklyDDHours,MaxMonthlyNetLossAllowed,EnableMonthlyDD,MonthlyDDDays,InpEnableFloatingDD,InpMaxFloatingDDPercent,EnableMarketCD,MarketCDCount,MarketCDHours,MarketCDResetHours,EnableBehaviorCD,BehaviorCDCount,BehaviorCDHours,EnableEntryInterval,MinEntryIntervalMinutes,MaxSLWidenMultiplier";
double g_cfgPrevIn[RM_CFG_N];
bool   g_cfgPrevValid = false;

void RM_CfgInVals(double &a[])
{
   a[0] = (double)In_MaxTotalRisk;
   a[1] = (double)In_MaxDailyNetLossAllowed;
   a[2] = (double)In_EnableDailyDD;
   a[3] = (double)In_DailyDDLockHours;
   a[4] = (double)In_MaxWeeklyNetLossAllowed;
   a[5] = (double)In_EnableWeeklyDD;
   a[6] = (double)In_WeeklyDDHours;
   a[7] = (double)In_MaxMonthlyNetLossAllowed;
   a[8] = (double)In_EnableMonthlyDD;
   a[9] = (double)In_MonthlyDDDays;
   a[10] = (double)In_InpEnableFloatingDD;
   a[11] = (double)In_InpMaxFloatingDDPercent;
   a[12] = (double)In_EnableMarketCD;
   a[13] = (double)In_MarketCDCount;
   a[14] = (double)In_MarketCDHours;
   a[15] = (double)In_MarketCDResetHours;
   a[16] = (double)In_EnableBehaviorCD;
   a[17] = (double)In_BehaviorCDCount;
   a[18] = (double)In_BehaviorCDHours;
   a[19] = (double)In_EnableEntryInterval;
   a[20] = (double)In_MinEntryIntervalMinutes;
   a[21] = (double)In_MaxSLWidenMultiplier;
}

// فقط وقتی دلیل OnInit «تغییر پارامتر» باشد و PublishSettings خاموش: فیلدهای تغییرکرده را در بلوک مشترک می‌نویسد و نسخه را بالا می‌برد
void RM_CfgAutoPublishChanged(double &cur[])
{
   if(PublishSettings || !g_cfgPrevValid || UninitializeReason() != REASON_PARAMETERS) return;
   if(!GlobalVariableCheck(RM_CfgVerKey())) return;
   string nm[];
   if(StringSplit(g_cfgNames, ',', nm) != RM_CFG_N) return;
   int n = 0;
   string list = "";
   for(int i=0;i<RM_CFG_N;i++)
   {
      if(MathAbs(cur[i] - g_cfgPrevIn[i]) < 0.0000001) continue;
      GlobalVariableSet(RM_CfgKey(nm[i]), cur[i]);
      list += (n>0 ? "," : "") + nm[i];
      n++;
   }
   if(n == 0) return;
   GlobalVariableSet(RM_CfgVerKey(), GlobalVariableGet(RM_CfgVerKey()) + 1.0);
   Print("[RM-CFG] auto-published ", IntegerToString(n), " changed input(s) from ", RM_InstTag(), ": ", list);
}

// OnInit: بلوک موجود نیست یا PublishSettings=true -> انتشار مقدارهای همین چارت؛ وگرنه خواندن از بلوک
void RM_LoadSharedSettings()
{
   double curIn[RM_CFG_N];
   RM_CfgInVals(curIn);
   RM_CfgAutoPublishChanged(curIn);   // v104: تغییر دستی ورودی -> خودکار منتشر می‌شود
   bool have = GlobalVariableCheck(RM_CfgVerKey());
   if(PublishSettings || !have)
   {
      RM_CfgPublish();
      Print("[RM-CFG] shared settings ", (have ? "PUBLISHED" : "created (first chart)"), " by ", RM_InstTag(), " (version ", DoubleToString(g_cfgVerSeen,0), ")");
      if(PublishSettings) Print("[RM-CFG] Publish Settings is ON - turn it OFF after publishing so other charts are not overwritten on restart");
   }
   else
   {
      RM_CfgApply();
      Print("[RM-CFG] shared settings loaded on ", RM_InstTag(), " (version ", DoubleToString(g_cfgVerSeen,0), ")");
   }
   ArrayCopy(g_cfgPrevIn, curIn);   // v104: مبنای مقایسه برای تغییر پارامتر بعدی
   g_cfgPrevValid = true;
}

// هر تیک: فقط یک GlobalVariableGet؛ اگر چارت دیگری منتشر کرده باشد، مقدارها دوباره خوانده و سقف‌های effective بازمحاسبه می‌شوند
void RM_CfgSyncIfChanged()
{
   if(!GlobalVariableCheck(RM_CfgVerKey())) return;
   if(GlobalVariableGet(RM_CfgVerKey()) == g_cfgVerSeen) return;
   RM_CfgApply();
   ApplyRiskCeilings();
   Print("[RM-CFG] shared settings updated from another chart, applied on ", RM_InstTag(), " (version ", DoubleToString(g_cfgVerSeen,0), ")");
}

// === v102: شروع روز/هفته/ماه مستقل از نماد (زمان سرور) ================================================
// قبلاً iTime(Symbol(), D1/W1/MN1) بود؛ مرز دوره‌ی هر نماد (طلا/شاخص/فارکس) می‌تواند کمی فرق کند، پس هر چارت مقدار مشترک GV را
// «ناهم‌خوان» می‌دید و بالانس شروع دوره را با بالانس همان لحظه بازنویسی می‌کرد (درصدهای روزانه/هفتگی/ماهانه بین چارت‌ها فرق می‌کرد
// و ضرر کمتر از واقع نمایش داده می‌شد). حالا مرز دوره از TimeCurrent() (زمان سرور) و برای همه‌ی چارت‌ها یکسان است.
datetime RM_DayStartSrv()   { datetime t = TimeCurrent(); return (datetime)((long)t - ((long)t % 86400)); }
datetime RM_WeekStartSrv()  { datetime d = RM_DayStartSrv(); return (datetime)((long)d - (long)TimeDayOfWeek(d) * 86400); } // یکشنبه = ۰
datetime RM_MonthStartSrv() { datetime t = TimeCurrent(); return StringToTime(StringFormat("%04d.%02d.01", TimeYear(t), TimeMonth(t))); }

// بالانس شروع دوره: اگر چارت دیگری همین دوره را قبلاً ثبت کرده (GV) همان؛ وگرنه بالانس فعلی
double RM_PeriodStartBalance(string gvStartKey, string gvBalKey, datetime newStart)
{
   if(GlobalVariableCheck(gvStartKey) && GlobalVariableCheck(gvBalKey) && (datetime)GlobalVariableGet(gvStartKey) == newStart)
      return GlobalVariableGet(gvBalKey);
   return AccountBalance();
}

void BuildAccountScopedKeys()
{
   string A = "_A" + IntegerToString(AccountNumber());
   string M = "_M" + IntegerToString(MagicNumber);
   string S = "_" + Symbol();

   // Drawdown / period reset markers (account + magic + symbol)
   // v102: قفل‌های روزانه/هفتگی/ماهانه account-wide شد (بدون نماد) - رسیدن به سقف روی هر نماد، همه‌ی چارت‌ها را قفل می‌کند
   GV_DAILY_END       = "RM_DailyEnd"     + A + M;
   GV_WEEKLY_END      = "RM_WeeklyEnd"    + A + M;
   GV_MONTHLY_END     = "RM_MonthlyEnd"   + A + M;

   // Period start balance/time markers (account + magic, بدون symbol - عمداً account-wide)
   GV_DAY_START       = "RM_DayStart"     + A + M;
   GV_DAY_START_BAL   = "RM_DayStartBal"  + A + M;
   GV_WEEK_START      = "RM_WeekStart"    + A + M;
   GV_WEEK_START_BAL  = "RM_WeekStartBal" + A + M;
   GV_MONTH_START     = "RM_MonthStart"   + A + M;
   GV_MONTH_START_BAL = "RM_MonthStartBal"+ A + M;
   GV_PRIOR_DAY_RESULT= "RM_PriorDayResult"+ A + M;
   GV_AUTOCLOSE_DAY   = "RM_AutoCloseDay"   + A + M;  // v80 (FEAT-031)
   GV_RISK_STEP       = "RM_RiskStep"       + A + M + S;  // v84 (FEAT-038): هم‌دامنه‌ی خود چارت (حساب+مجیک+نماد)، چون g_riskStep هم state همین EA/چارته

   // Cooldown counters + helper (account + magic, account-wide - عمداً بدون symbol)
   GV_MKT_COUNT       = "RM_MktCount"     + A + M;
   GV_BEH_COUNT       = "RM_BehCount"     + A + M;
   GV_LAST_STOP_CLOSE = "RM_LastStopClose"+ A + M;
   GV_BEHERR_TOTAL    = "RM_BehErrTotal"  + A + M;

   // v77: قبلاً per-symbol (بدون account) بودن → تداخلِ بین‌اکانتی. حالا account + magic + symbol.
   // v101 (BUG-055، تصمیم صریح مالک): زمان پایان قفل Market/Behavior هم‌فلسفه‌ی شمارنده‌هاست → account-wide (بدون نماد).
   // قبلاً per-symbol بود: ۴ استاپ روی داوجونز شمارنده را بالا می‌برد ولی قفل فقط روی چارت داوجونز می‌نشست و چارت انس آزاد می‌ماند.
   GV_MKT_END         = "RM_MktEnd"       + A + M;
   GV_BEH_END         = "RM_BehEnd"       + A + M;
   GV_LAST_ENTRY      = "RM_LastEntry"    + A + M + S;  // فاصله‌ی ورود: عمداً per-symbol ماند (تغییر قاعده نیست؛ در گزارش سؤال شد)
}
// ====================================================================================


// === v9.3: Half Close @ TP1+ exemption helpers (Behavior Cooldown) ===
// v101 (BUG-054): معافیت Half Close @ TP1+ فقط در آرایه‌ی حافظه‌ی همان نمونه بود. اگر Half Close روی چارت A زده می‌شد و
// بسته‌شدن تیکت را نمونه‌ی B (claim-winner) پردازش می‌کرد، B معافیت را نمی‌دید و یک Strike اشتباه EarlyExit می‌زد
// (همان باگ BUG-002 ولی بین نمونه‌ها). حالا هر معافیت یک GV حساب‌محور هم دارد (RM_HALFEXEMPT_A<حساب>_M<مجیک>_<تیکت>)؛
// IsHalfExempt هر دو را چک می‌کند. GV توسط RemoveHalfExempt (claim-winner موقع پردازش) پاک می‌شود؛ نمونه‌ای که claim را
// نبرده فقط حافظه‌ی محلی‌اش را با RemoveHalfExemptLocal پاک می‌کند (تا GV را قبل از خواندن claim-winner نابود نکند).
string HalfExemptKey(int ticket) { return "RM_HALFEXEMPT_A" + IntegerToString(AccountNumber()) + "_M" + IntegerToString(MagicNumber) + "_" + IntegerToString(ticket); }

bool IsHalfExempt(int ticket)
{
   for(int i=0;i<g_halfExemptCount;i++)
      if(g_halfExemptTickets[i]==ticket) return true;
   return GlobalVariableCheck(HalfExemptKey(ticket));
}

void AddHalfExempt(int ticket)
{
   GlobalVariableSet(HalfExemptKey(ticket), 1.0);   // v101: مشترک بین نمونه‌ها (قبل از early-return حافظه، تا اگر حافظه از قبل داشت هم GV ثبت شود)
   for(int i=0;i<g_halfExemptCount;i++)
      if(g_halfExemptTickets[i]==ticket) return;
   ArrayResize(g_halfExemptTickets, g_halfExemptCount+1);
   g_halfExemptTickets[g_halfExemptCount] = ticket;
   g_halfExemptCount++;
}

void RemoveHalfExemptLocal(int ticket)
{
   for(int i=0;i<g_halfExemptCount;i++)
   {
      if(g_halfExemptTickets[i]==ticket)
      {
         for(int k=i;k<g_halfExemptCount-1;k++)
            g_halfExemptTickets[k]=g_halfExemptTickets[k+1];
         g_halfExemptCount--;
         ArrayResize(g_halfExemptTickets, g_halfExemptCount);
         return;
      }
   }
}

void RemoveHalfExempt(int ticket)
{
   RemoveHalfExemptLocal(ticket);
   if(GlobalVariableCheck(HalfExemptKey(ticket))) GlobalVariableDel(HalfExemptKey(ticket));
}






//+------------------------------------------------------------------+
// Check drawdown and lock
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v9.5: Floating Drawdown Protection                                |
//+------------------------------------------------------------------+
double GetFloatingPLPercent()
{
   double bal = AccountBalance();
   if(bal<=0) return 0;
   double floatingPL = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;   // v101: account-wide (بدون فیلتر نماد) - حفاظت از حساب، نه یک نماد
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      floatingPL += OrderProfit()+OrderSwap()+OrderCommission();
   }
   return floatingPL/bal*100.0;
}

void EmergencyCloseAll()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;   // v101: همه‌ی نمادها (حفاظت حساب)
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      bool buy=(OrderType()==OP_BUY);
      int  tk = OrderTicket();
      // v101: چون حالا روی چند نماد کار می‌کند، نمونه‌ی claim-winner ممکن است چارت دیگری باشد؛ پرچم GV همین‌جا ثبت می‌شود
      MarkEmergencyClosed(tk);
      // v62 (تفکیک ExitReason - EmergencyClose): قبل از بستن، تیکت به آرایه‌ی موقت
      // g_emergencyClosedTickets[] (RM_CooldownEngine.mqh) اضافه می‌شه تا CheckClosedTrades این
      // بسته‌شدن رو به‌عنوان اقدام حفاظتی سیستم (نه خروج دستی تریدر) تشخیص بده. هیچ تغییری در
      // منطق پایین (چی رو کِی می‌بنده) داده نشده.
      ArrayResize(g_emergencyClosedTickets, g_emergencyClosedCount+1);
      g_emergencyClosedTickets[g_emergencyClosedCount] = tk;
      g_emergencyClosedCount++;
      // v6 (BUG-007 fix): نتیجه‌ی OrderClose چک می‌شه؛ اگه بسته نشد (ریکوت/آف‌کوتز و...)، یه بار دیگه با قیمت تازه امتحان می‌شه
      double px = buy ? MarketInfo(OrderSymbol(),MODE_BID) : MarketInfo(OrderSymbol(),MODE_ASK); // v101: قیمت نماد خود معامله
      bool closed = OrderClose(tk, OrderLots(), px, Slippage, clrRed);
      if(!closed)
      {
         int err = GetLastError();
         Print("EmergencyCloseAll: OrderClose failed for ticket ", tk, " (error ", err, "), retrying once");
         RefreshRates();
         if(OrderSelect(tk, SELECT_BY_TICKET))
         {
            if(OrderCloseTime()>0) closed = true;   // v101: نمونه‌ی دیگری همزمان بسته است
            else
            {
               bool buy2 = (OrderType()==OP_BUY);
               double px2 = buy2 ? MarketInfo(OrderSymbol(),MODE_BID) : MarketInfo(OrderSymbol(),MODE_ASK);
               closed = OrderClose(tk, OrderLots(), px2, Slippage, clrRed);
               if(!closed && OrderSelect(tk, SELECT_BY_TICKET) && OrderCloseTime()>0) closed = true;
            }
         }
         if(!closed)
            GlobalVariableDel(EmergencyKey(tk));  // بسته نشد: پرچم نباید بماند
         if(!closed)
         {
            Print("EmergencyCloseAll: retry failed for ticket ", tk, " (error ", GetLastError(), ") - position still open!");
            Alert("Emergency Close FAILED for ticket ", tk, " - check platform manually!");
         }
      }
   }
}




//+------------------------------------------------------------------+
// Save/Load Dashboard Mode (Trading/Utility, renamed v31 from FULL/COMPACT) - persists across EA
// restarts. Stored as the enum's ordinal value, unchanged by the v31 rename, so no migration needed.
//+------------------------------------------------------------------+
string GV_DASH_MODE = "RM_DashMode_" + Symbol();








//+------------------------------------------------------------------+
// v8 (BUG-011): برای نوار وضعیت - true اگه حداقل یک معامله‌ی باز این EA فعلاً
// SL‌اش طرف سود نسبت به قیمت ورود باشه (یعنی به Break Even رسیده - دستی یا خودکار)
//+------------------------------------------------------------------+
bool IsBreakEvenActive()
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      double sl=OrderStopLoss();
      if(sl<=0) continue;
      bool buy=(OrderType()==OP_BUY);
      if(buy  && sl>=OrderOpenPrice()) return true;
      if(!buy && sl<=OrderOpenPrice()) return true;
   }
   return false;
}



// R8 (Architecture Refactor, Final Phase): GetBasketAveragePrice() به RM_Common.mqh منتقل شد -
// طبق grep توسط RM_CooldownEngine.mqh + RM_Tools.mqh (UpdateBERefLine) + RM_TradeExecution.mqh
// مصرف می‌شه.


// v9.7: هر کلیک یک واحد به RR اضافه می‌کنه، در بازه ۱ تا ۵؛ بعد از ۵ به ۱ برمی‌گرده
void CycleRR()
{
   g_riskReward += 1.0;
   if(g_riskReward > 5.0 + 0.0001)
      g_riskReward = 1.0;
}

// v29 revision 3 (Mahmoud feedback - Risk/RR are settings, not actions): RR's own background
// stays capped inside the grey palette (never white) while the border is allowed to travel all
// the way to a near-white accent at RR5 - the border carries most of the visual progression, the
// button surface only shifts subtly, and the white text label stays legible at every level.
// Passed by reference since MQL4 has no tuple/multi-return - fills both bg and border for the
// given RR value in one pass.
void RRGlowColors(double rr, color &bg, color &border)
{
   int level = (int)MathRound(rr);
   if(level<1) level=1;
   if(level>5) level=5;
   double t = (level-1)/4.0;
   int bgR = RR_BG_LO_R + (int)((RR_BG_HI_R-RR_BG_LO_R)*t);
   int bgG = RR_BG_LO_G + (int)((RR_BG_HI_G-RR_BG_LO_G)*t);
   int bgB = RR_BG_LO_B + (int)((RR_BG_HI_B-RR_BG_LO_B)*t);
   bg = (color)(bgR | (bgG<<8) | (bgB<<16));
   int brR = RR_BORDER_LO_R + (int)((RR_BORDER_HI_R-RR_BORDER_LO_R)*t);
   int brG = RR_BORDER_LO_G + (int)((RR_BORDER_HI_G-RR_BORDER_LO_G)*t);
   int brB = RR_BORDER_LO_B + (int)((RR_BORDER_HI_B-RR_BORDER_LO_B)*t);
   border = (color)(brR | (brG<<8) | (brB<<16));
}

// v36 (Change 1 revision - Mahmoud feedback): مثل FitBoxFontHalf() بالا (بزرگ‌ترین فونتی که جا
// می‌شه رو انتخاب می‌کنه)، با دو فرق: (۱) نسبت پیکسل/کاراکتر مخصوص فونت مونواسپیس Consolas
// (پهن‌تر از Arial که FitBoxFontHalf برایش تنظیم شده)، و (۲) طول متن رو مستقیم می‌گیره نه خود
// متن رو - چون فراخوان (UpdatePLDisplay) از قبل بلندترین طول بین هر سه ردیف Daily/Weekly/Monthly
// رو محاسبه کرده و همینجا یه فونت مشترک برای هر سه برمی‌گردونه، دقیقاً همون قانونی که
// PERF_ROW_FONT/PERF_MONO_FONT قبلاً اعمال می‌کردن (هیچ‌وقت ردیف‌ها رو مستقل از هم سایز نکن).
int BestFitMonoFont(int len, int boxW)
{
   int sizes[5] = {10,9,8,7,6};
   int pad = SC(6);
   int avail = boxW - pad;
   int chosen = 6;
   for(int i=0;i<5;i++)
   {
      int sz = sizes[i];
      int estW = (int)(len * SCF(sz) * PERF_MONO_CHAR_RATIO);
      chosen = sz;
      if(estW <= avail) break;
   }
   return SCF(chosen);
}

void SetStatus(string msg,color clr)
{ 
   ObjectSetString(0,P+"L_STATUS",OBJPROP_TEXT,msg); 
   ObjectSetInteger(0,P+"L_STATUS",OBJPROP_COLOR,clr); 
   FitBoxFont(P+"L_STATUS", msg); // v8 (BUG-014)
   ObjectSetString(0,P+"L_STATUS2",OBJPROP_TEXT,"");
   // v2: خط دوم خالیه، پس متن خط اول رو دقیقاً وسط کادر قرار بده (نه چسبیده به بالا)
   // v28 revision 2: 15->12 (half of STATUS_H=24, was 30)
   // v43 (Item 4): +ALERT_PAD added - row1's slot now starts ALERT_PAD below the box top instead
   // of flush with it (see BuildPanel()), so centering has to account for that offset too.
   ObjectSetInteger(0,P+"L_STATUS",OBJPROP_YDISTANCE, g_statusBoxTop + ALERT_PAD + SC(12));
   // v8 (BUG-011): این یک پیام اکشن لحظه‌ایه - چند ثانیه نمایش داده می‌شه و بعدش
   // UpdateSystemStatus() خودکار وضعیت دائمی سیستم رو جایگزینش می‌کنه
   g_actionMsgUntil = TimeCurrent() + ACTION_MSG_SECONDS;
   ChartRedraw(); 
}

// v9.4 (دیگه از v8 به بعد برای وضعیت دائمی استفاده نمی‌شه - نگه‌داشته شده برای سازگاری، فعلاً جایی صداش نمی‌زنه)
void SetStatus2(string msg,color clr)
{
   ObjectSetString(0,P+"L_STATUS2",OBJPROP_TEXT,msg);
   ObjectSetInteger(0,P+"L_STATUS2",OBJPROP_COLOR,clr);
   if(msg != "")
   {
      // v2: وقتی خط دوم پر می‌شه، خط اول رو کمی بالاتر و خط دوم رو پایین‌تر بچین (دو خط متقارن)
      // v28 revision 2: 15/7 -> 12/6 (matches STATUS_H=24, was 30)
      // v43 (Item 4): +ALERT_PAD, same reasoning as SetStatus() above.
      ObjectSetInteger(0,P+"L_STATUS",  OBJPROP_YDISTANCE, g_statusBoxTop + ALERT_PAD + SC(12) - SC(6));
      ObjectSetInteger(0,P+"L_STATUS2", OBJPROP_YDISTANCE, g_statusBoxTop + ALERT_PAD + SC(12) + SC(6));
   }
   else
   {
      // v2: خط دوم دوباره خالی شد - خط اول رو برگردون وسط کادر
      ObjectSetInteger(0,P+"L_STATUS", OBJPROP_YDISTANCE, g_statusBoxTop + ALERT_PAD + SC(12));
   }
   ChartRedraw();
}

// v36 (Change 1): پد کردن رشته با فاصله سمت راست (چپ‌چین) تا عرض ثابت w برسه - برای اینکه بخش
// عددی هر ردیف Performance (Daily/Weekly/Monthly) دقیقاً زیر هم بیفته، چون طول متن لیبل‌ها
// ("Daily P/L:" / "Weekly P/L:" / "Monthly P/L:") فرق می‌کنه. با فونت مونواسپیس (Consolas) روی
// همین آبجکت‌ها، پد کردن به عرض ثابت یعنی بخش بعدی رشته همیشه از یه پیکسل ثابت شروع می‌شه.
string PadR(string s,int w)
{
   while(StringLen(s)<w) s = s+" ";
   return s;
}

// v36 (Change 1): پد کردن رشته با فاصله سمت چپ (راست‌چین) تا عرض ثابت w برسه - برای بخش‌های
// عددی (%، R، RB) که باید نقطه‌ی اعشارشون هم زیر هم بیفته، نه فقط شروعشون.
string PadL(string s,int w)
{
   while(StringLen(s)<w) s = " "+s;
   return s;
}

// R8 (Architecture Refactor, Final Phase): HLine() به RM_Common.mqh منتقل شد - طبق grep توسط
// ۴ ماژول مصرف می‌شه (RM_AutoActions.mqh + RM_Tools.mqh + RM_TradeExecution.mqh + RM_Trailing.mqh).

void RectC(string n,int x,int y,int w,int h,color bg, int corner=CORNER_LEFT_UPPER)
{
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);     ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);  ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);  ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   // v45 (Punch List Round 3, Item 6): RectC is only ever used for the panel's own backgrounds/
   // containers (TITLEBAR, BG, BG_ALERT, BG_MKT, BG_BEH, BG_PERF, BG_REPORTS - every call site in
   // the file) - one shared function, so one change here covers all of them, same "34 buttons from
   // one BtnC" philosophy as v36 Change 3. BG tier - see the PANEL_ZORDER_* comment above for why
   // this has to move together with BtnC/Btn/Lbl/LblC/LblCC below, not alone.
   ObjectSetInteger(0,n,OBJPROP_ZORDER, PANEL_ZORDER_BG);
}

void Rect(string n,int x,int y,int w,int h,color bg)
{
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);     ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);  ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);  ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
}

void Btn(string n,int x,int y,int w,int h,string t,color bg)
{
   ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);     ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString(0,n,OBJPROP_TEXT,t);        ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clrWhite); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,7);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| v92 (BUG-059 - DIAGNOSTIC، فقط زمان‌سنجی؛ هیچ رفتاری عوض نمی‌شود)   |
//| OnTick/OnTimer/OnChartEvent واقعی به RM_On*Impl منتقل شدند و این   |
//| پوشش‌ها زمان اجرای هرکدام را اندازه می‌گیرند. هر ۱۰ ثانیه حداکثر    |
//| یک خط [RM-PERF] در لاگ Experts می‌نویسد (فقط اگر فعالیتی بوده).     |
//| busy = درصد زمانی که EA در این ۱۰ ثانیه مشغول بوده.                 |
//| بعد از پیدا شدن علت لگ، این بخش و پوشش‌ها حذف می‌شوند.              |
//+------------------------------------------------------------------+
#define RM_PF_CATS 6
string g_pfName[RM_PF_CATS] = {"tick","timer","mouse","chartchg","click","other"};
ulong  g_pfUs[RM_PF_CATS];
ulong  g_pfMaxUs[RM_PF_CATS];
int    g_pfN[RM_PF_CATS];
uint   g_pfWindowStart = 0;
uint   g_pfLastSlowLog = 0;

void RM_PerfRecord(int cat, ulong us)
{
   g_pfUs[cat] += us;
   g_pfN[cat]++;
   if(us > g_pfMaxUs[cat]) g_pfMaxUs[cat] = us;
   uint now = GetTickCount();
   if(us > 30000 && now - g_pfLastSlowLog > 500)
   {
      g_pfLastSlowLog = now;
      if(g_rmPerfLog) Print("[RM-PERF] SLOW ", g_pfName[cat], " call: ", DoubleToString(us/1000.0,1), "ms");
   }
   if(g_pfWindowStart == 0) g_pfWindowStart = now;
   uint wall = now - g_pfWindowStart;
   if(wall >= 10000)
   {
      ulong tot = 0; int n = 0;
      string line = "";
      for(int i=0;i<RM_PF_CATS;i++)
      {
         tot += g_pfUs[i]; n += g_pfN[i];
         if(g_pfN[i] > 0)
            line += " | " + g_pfName[i] + " n=" + IntegerToString(g_pfN[i]) +
                    " avg=" + DoubleToString(g_pfUs[i]/1000.0/g_pfN[i],2) + "ms" +
                    " max=" + DoubleToString(g_pfMaxUs[i]/1000.0,1) + "ms";
         g_pfUs[i] = 0; g_pfMaxUs[i] = 0; g_pfN[i] = 0;
      }
      if(n > 0)
         if(g_rmPerfLog) Print("[RM-PERF] ", IntegerToString((int)(wall/1000)), "s busy=", DoubleToString(tot/1000.0/wall*100.0,1), "%", line);
      g_pfWindowStart = now;
   }
}

// v93: تفکیک زمان داخل OnTick - هر مرحله‌ی ≥۲ms ثبت می‌شود؛ اگر کل تیک ≥۳۰ms شد، یک خط BREAKDOWN چاپ می‌شود (حداکثر ۲ بار در ثانیه).
string g_pfmName[40];
ulong  g_pfmUs[40];
int    g_pfmN = 0;
ulong  g_pfmLast = 0;
uint   g_pfmLastLog = 0;

void RM_PfBegin()
{
   g_pfmN = 0;
   g_pfmLast = GetMicrosecondCount();
}

void RM_PfMark(string name)
{
   ulong now = GetMicrosecondCount();
   ulong d = now - g_pfmLast;
   g_pfmLast = now;
   if(d >= 2000 && g_pfmN < 40)
   {
      g_pfmName[g_pfmN] = name;
      g_pfmUs[g_pfmN]   = d;
      g_pfmN++;
   }
}

void RM_PfDump(ulong totalUs)
{
   if(totalUs < 30000) return;
   uint now = GetTickCount();
   if(now - g_pfmLastLog < 500) return;
   g_pfmLastLog = now;
   string line = "";
   for(int i=0;i<g_pfmN;i++)
      line += " " + g_pfmName[i] + "=" + DoubleToString(g_pfmUs[i]/1000.0,1) + "ms";
   if(g_rmPerfLog) Print("[RM-PERF] TICK BREAKDOWN total=", DoubleToString(totalUs/1000.0,1), "ms |", line);
}

void OnTick()
{
   ulong t0 = GetMicrosecondCount();
   RM_OnTickImpl();
   ulong dt = GetMicrosecondCount() - t0;
   RM_PfDump(dt);
   RM_PerfRecord(0, dt);
}

void OnTimer()
{
   ulong t0 = GetMicrosecondCount();
   RM_OnTimerImpl();
   RM_PerfRecord(1, GetMicrosecondCount() - t0);
}

void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
{
   ulong t0 = GetMicrosecondCount();
   RM_OnChartEventImpl(id, lp, dp, sp);
   int cat = 5;
   if(id == CHARTEVENT_MOUSE_MOVE) cat = 2;
   else if(id == CHARTEVENT_CHART_CHANGE) cat = 3;
   else if(id == CHARTEVENT_OBJECT_CLICK || id == CHARTEVENT_CLICK) cat = 4;
   RM_PerfRecord(cat, GetMicrosecondCount() - t0);
}
