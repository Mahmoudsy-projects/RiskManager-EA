//+------------------------------------------------------------------+
//| RM_RiskManager_Main.mq5                                          |
//| RiskManager EA — MT5 port, final assembled entry file.           |
//| #includes all 16 real, fully-ported modules (Stages 1–5d).       |
//| No stubs remain anywhere in this build.                          |
//+------------------------------------------------------------------+
#property copyright   "Risk Manager EA"
#property version     "75.15"   // v75.14 (FEAT-037 چک‌لیست کانتکست - P5). v75.13 (Scale-in + ریشه‌ی زنجیره + FEAT-045 خط ریسک)
#property description "A discipline enforcement engine, not a predictive tool."
#property description "Focuses on what can be controlled: risk, behavior, execution."
#property description "1. Mathematical: sizing, capital preservation, D/W/M limits, Emergency Stop."
#property description "2. Behavioral: Market & Behavior Cooldown, disciplined execution."
#property description "3. Execution: minimize friction, simplify decisions, reduce errors."
#property description "Survive long enough to let your edge work."
#property description "Developed by Mahmoud Seyedi"
#property strict
#property icon "RiskManager.ico"

// v45 (Punch List Round 3, Item 8), carried into the MT5 port: 3 sound files embedded directly
// into the compiled .ex5 (not read live from MQL5/Sounds) — works on any new install/broker
// without manual copying. PlaySound() must be called with the "::" prefix (already the case in
// RM_Config.mq5's SND_* defines) to read from the embedded resource, not disk.
#resource "\\Sounds\\order_filled.wav"
#resource "\\Sounds\\stop_loss.wav"
#resource "\\Sounds\\target_reached.wav"

// ============================================================
// SECTION 1 — globals with NO cross-file dependency. Safe before
// any #include. Values copied verbatim from RiskManager_EA_v70.mq4.
// ============================================================

string  P = "RM9_";
enum EStep { STEP_IDLE, STEP_ENTRY, STEP_SL };
EStep   g_step       = STEP_IDLE;
enum EMode { MODE_MARKET, MODE_PENDING };
EMode   g_mode       = MODE_MARKET;
double  g_entryPrice = 0, g_slPrice = 0, g_tpPrice = 0;
bool    g_isBuy      = true;
double  g_riskReward = 3.0;
bool    g_halfRiskActive = false;
int     g_riskStep = 0;
string GV_RISK_STEP = "";   // v75.10 (FEAT-038): per chart; در LoadRiskStepState ساخته می‌شود (MagicNumber هنوز اینجا تعریف نشده)
// v75.13 (MT4 v90 FEAT-044): Scale-in - دکمه‌ی یک‌بارمصرف (پایدار نیست) و فهرست زنجیره‌های مجاز (آرایه‌های هم‌ایندکس، توسط BuildScaleInCandidates پر می‌شن)
bool    g_scaleInOn   = false;
ulong   g_scaleInRoot = 0;
ulong   g_scCandRoot[];
double  g_scCandCap[];
bool    g_scCandBuy[];
double  g_scCandEntry[];
bool    g_scaleInPickerOpen = false;   // پنجره‌ی انتخاب زنجیره (وقتی ۲+ زنجیره‌ی مجاز) باز است؟
const int Slippage = 3;
string  LN_ENT="RM9LN_ENT", LN_SL="RM9LN_SL", LN_TP="RM9LN_TP", LN_TYPE="RM9LN_TYPE", LN_CUR="RM9LN_CUR";
#define LN_FIBOCURSOR "RM9_FIBOCURSOR"
ulong   g_lastHalfCloseRemainderTicket = 0;

double  g_priorDayResultCode = -2;
int     g_trailCount = 0;
datetime g_dailyLockEnd=0, g_weeklyLockEnd=0, g_monthlyLockEnd=0;
// v74 (BUG-051 - MT5 port of MT4 v72's URGENT fix): لحظه‌ی شروع OnInit() - مبنای پنجره‌ی Grace
// Period (StartupGracePeriodSeconds در RM_Config.mq5). فقط برای جلوگیری از ست‌شدن قفل جدید در
// همون پنجره استفاده می‌شه؛ محاسبه/نمایش dd% دست‌نخورده می‌مونه و قفل‌های از قبل فعال
// (بارگذاری‌شده توسط LoadDrawdownState) اصلاً به این global وابسته نیستن.
datetime g_eaStartupTime = 0;
datetime g_mktCooldownEnd=0, g_behCooldownEnd=0;
datetime g_lastEntryTime=0, g_lastStopCloseTime=0;
double  g_mktStopCount=0;
int     g_behCount=0;
bool    g_floatingDDTriggered=false;
datetime g_dayStart, g_weekStart, g_monthStart;
double  g_dayStartBalance, g_weekStartBalance, g_monthStartBalance;
const int PanelX = 15;  // Panel horizontal offset from corner (pixels)
const int PanelY = 25;  // Panel vertical offset from corner (pixels)

// [RESTORED — dropped by mistake in the previous reassembly pass, caught by
// the compiler] Effective (post-ceiling-clamp) risk values, written by
// ApplyRiskCeilings() (RM_RiskCalc.mq5, real since Stage 2), read throughout
// RM_RiskCalc/TradeExecution/DrawdownEngine/CooldownEngine.
double g_effRiskPerTrade, g_effMaxTotalRisk, g_effMaxDailyRisk, g_effMaxWeeklyDD, g_effMaxMonthlyDD;

// Dashboard UI state — real, unchanged since Stage 5c-i/5c-ii. (Note:
// g_dashboardMode itself is declared further down, AFTER
// RM_MainEA_DashboardHelpers.mq5's #include, since its type (EDashboardMode)
// is defined there, not here — seeit below.)
bool    g_perfDrawerOpen = false, g_perfWasOpenBeforeSubmenu = false;
bool    g_reportsDrawerOpen = false;
bool    g_fullCloseMenuOpen = false, g_halfCloseMenuOpen = false;
bool    g_minimized = false;
int     g_closeMenuAnchorX=0, g_closeMenuAnchorY=0, g_closeMenuAnchorW=200;
int     g_halfCloseMenuAnchorX=0, g_halfCloseMenuAnchorY=0, g_halfCloseMenuAnchorW=200;
uint    g_beFlashEnd=0, g_fullFlashEnd=0, g_halfFlashEnd=0, g_exportFlashEnd=0;
int     CLOSE_GRID_GAP, CLOSE_GRID_ROW_H;
int     ALERT_PAD;
int     g_reportsPeriod=0;

// RM_CooldownEngine.mq5 dependency: Half Close TP1+ exemption tracking
// (real, unchanged since Stage 3).
// v75.0 (P0، MT4 v101 BUG-054): معافیت Half Close @ TP1+ فقط در حافظه‌ی EA بود؛ با ری‌استارت EA (یا بسته‌شدن توسط
// چارت دیگر) از بین می‌رفت و بسته‌شدن نهایی همان تیکت یک Strike اشتباه EarlyExit می‌خورد (تیکت 124459854).
// حالا هر معافیت یک GV حساب‌محور هم دارد (RM_HALFEXEMPT_A<حساب>_M<مجیک>_<تیکت>) که با GlobalVariablesFlush روی
// «رویداد» (Add/Remove) روی دیسک می‌نشیند. IsHalfExempt هر دو را چک می‌کند. GV را RemoveHalfExempt (برنده‌ی claim) پاک
// می‌کند؛ چارتی که claim را نبرده فقط حافظه‌ی خودش را با RemoveHalfExemptLocal پاک می‌کند.
ulong g_halfExemptTickets[]; int g_halfExemptCount=0;
string HalfExemptKey(ulong ticket)
{
   return "RM_HALFEXEMPT_A" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + IntegerToString(ticket);
}
bool IsHalfExempt(ulong ticket)
{
   for(int i=0;i<g_halfExemptCount;i++) if(g_halfExemptTickets[i]==ticket) return true;
   return GlobalVariableCheck(HalfExemptKey(ticket));
}
void AddHalfExempt(ulong ticket)
{
   if(!GlobalVariableCheck(HalfExemptKey(ticket)))
   {
      GlobalVariableSet(HalfExemptKey(ticket), 1.0);   // مشترک بین چارت‌ها و ماندگار
      GlobalVariablesFlush();                           // رویداد نادر (فقط Half Close @TP1+) - flush فوری روی دیسک
   }
   for(int i=0;i<g_halfExemptCount;i++) if(g_halfExemptTickets[i]==ticket) return;
   ArrayResize(g_halfExemptTickets, g_halfExemptCount+1);
   g_halfExemptTickets[g_halfExemptCount]=ticket;
   g_halfExemptCount++;
}
void RemoveHalfExemptLocal(ulong ticket)
{
   for(int i=0;i<g_halfExemptCount;i++)
      if(g_halfExemptTickets[i]==ticket)
      {
         for(int k=i;k<g_halfExemptCount-1;k++) g_halfExemptTickets[k]=g_halfExemptTickets[k+1];
         g_halfExemptCount--;
         ArrayResize(g_halfExemptTickets, g_halfExemptCount);
         return;
      }
}
void RemoveHalfExempt(ulong ticket)
{
   RemoveHalfExemptLocal(ticket);
   if(GlobalVariableCheck(HalfExemptKey(ticket)))
   {
      GlobalVariableDel(HalfExemptKey(ticket));
      GlobalVariablesFlush();
   }
}

// Simple utility helpers (real, unchanged since Stage 3).
void CaptureOpenTickets(ulong &arr[])
{
   ArrayResize(arr, 0);
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      int n = ArraySize(arr);
      ArrayResize(arr, n+1);
      arr[n] = tk;
   }
}
bool TicketInList(ulong ticket, const ulong &arr[])
{
   for(int i=0;i<ArraySize(arr);i++)
      if(arr[i]==ticket) return true;
   return false;
}

// ============================================================
// SECTION 2 — includes that SECTION 3 depends on (MagicNumber from
// Config, EDashboardMode enum from DashboardHelpers).
// ============================================================
#include "RM_Config.mq5"
#include "RM_RiskCalc.mq5"
#include "RM_MainEA_DashboardHelpers.mq5"

// ============================================================
// SECTION 3 — globals that depend on something in Section 2's includes.
// Real values (NOT the "RM_TEST4_..." placeholders that were sitting in
// Stage 5d's now-retired stub file). AccountNumber() [MT4-only, doesn't
// exist in MQL5] translated to AccountInfoInteger(ACCOUNT_LOGIN).
// ============================================================
// v74.2 (HF3, B4): Daily lock END is now account-wide (no symbol suffix) like Weekly/Monthly - a Daily lock set
// on one chart blocks every chart within a tick. (The DD% measurement itself is unchanged.)
string GV_AUTOCLOSE_DAY     = "RM_AutoCloseDay_A"    + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);   // v75.4 (MT4 v80 FEAT-031)
string GV_DAILY_END        = "RM_DailyEnd_A"        + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_WEEKLY_END       = "RM_WeeklyEnd_A"       + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_MONTHLY_END      = "RM_MonthlyEnd_A"      + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
// v74.3 (HF2, A3): day start / start balance / prior-day result are now ACCOUNT-WIDE (no symbol suffix), like
// Weekly/Monthly. The old per-symbol keys are kept only to migrate an in-progress day on upgrade.
string GV_DAY_START        = "RM_DayStart_A"        + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_DAY_START_BAL    = "RM_DayStartBal_A"     + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_DAY_START_OLD    = "RM_DayStart_A"        + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + Symbol();
string GV_DAY_START_BAL_OLD= "RM_DayStartBal_A"     + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + Symbol();
string GV_WEEK_START       = "RM_WeekStart_A"       + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_WEEK_START_BAL   = "RM_WeekStartBal_A"    + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_MONTH_START      = "RM_MonthStart_A"      + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_MONTH_START_BAL  = "RM_MonthStartBal_A"   + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_PRIOR_DAY_RESULT = "RM_PriorDayResult_A"  + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber); // v74.3 (HF2): account-wide
string GV_MKT_COUNT        = "RM_MktCount_A"        + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_MKT_END          = "RM_MktEnd_A"          + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_BEH_COUNT        = "RM_BehCount_A"        + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_BEH_END          = "RM_BehEnd_A"          + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
// v74.2 (HF3, B4): Entry Interval stays PER SYMBOL (it was account-wide in name but per-chart in effect).
string GV_LAST_ENTRY       = "RM_LastEntry_A"       + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + Symbol();
string GV_LAST_STOP_CLOSE  = "RM_LastStopClose_A"   + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);
string GV_BEHERR_TOTAL     = "RM_BehErrTotal_A"     + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber);

// EDashboardMode is defined in RM_MainEA_DashboardHelpers.mq5 (included just
// above) — this variable itself was never given a permanent home anywhere
// else, same category as every other orphan main-.mq4 global in this file.
EDashboardMode g_dashboardMode = DASH_TRADING;

// ============================================================
// SECTION 4 — everything else.
// ============================================================
#include "RM_Common.mq5"
#include "RM_SessionTime.mq5"   // v75.0 (P0-1): آفست پایدار سرور->UTC
#include "RM_Snapshot.mq5"
#include "RM_TradeExecution.mq5"
#include "RM_DrawdownEngine.mq5"
#include "RM_Trailing.mq5"
#include "RM_AutoActions.mq5"
#include "RM_CooldownEngine.mq5"
#include "RM_MainEA_FloatingDD.mq5"
#include "RM_MainEA_NetResultR.mq5"
#include "RM_Reports.mq5"
#include "RM_Dashboard.mq5"
#include "RM_Tools.mq5"
#include "RM_MainEventHandlers.mq5"
