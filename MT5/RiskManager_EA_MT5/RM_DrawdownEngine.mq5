//+------------------------------------------------------------------+
//| RM_DrawdownEngine.mq5                                              |
//| Risk Manager EA - Drawdown Protection Engine (MT5 Port, Stage 4)   |
//| پورت مستقیم از RM_DrawdownEngine.mqh (RiskManager EA v70, MQL4).    |
//| Golden Rule: فرمول‌ها/آستانه‌ها/ترتیب عملیات عوض نشدن - فقط           |
//| فراخوانی‌های API از MT4 به MT5 ترجمه شدن.                            |
//+------------------------------------------------------------------+

// === v10 (BUG-012): نتیجه‌ی خالص واقعی% یک دوره - سود و ضرر معاملات بسته‌شده (نه فقط ضررها)
// نسبت به بالانس شروع همون دوره. مبنای مشترک هم برای منطق قفل (زیر) و هم باکس‌های نمایشی P/L%.
//
// [Stage 4 - deal-based history translation, same mapping decision as CheckClosedTrades() -
// see RM_CooldownEngine.mq5's header comment for the full write-up]. MT4's flat
// OrdersHistoryTotal()/OrderSelect(SELECT_BY_POS,MODE_HISTORY) loop over CLOSED ORDERS becomes
// MT5's HistorySelect()+HistoryDealsTotal()/HistoryDealGetTicket() loop over DEALS, filtered to
// DEAL_ENTRY_OUT (closing deals) only. Unlike CheckClosedTrades() (which needs ONE classification
// event per position), this function only needs a period TOTAL - so every OUT deal in the window is
// summed directly, including each individual partial-close deal. This is not just compatible with
// partial closes, it's the textbook-correct way to total realized P&L for a period on MT5: a
// half-closed position's realized portion is already counted the moment it closes, and the
// remaining open portion is correctly excluded (it isn't a deal yet).
// v74.2 (HF3, B3): allSymbols=false = this chart's symbol only. v74.3 (HF2, D1): CalcNetResultPercent() below now
// passes true, so protection and the Performance panel are the same account-wide number.
// v74.3 (HF2, A3, MT4 v102): period boundaries from SERVER time (TimeCurrent), identical for every chart/symbol.
datetime RM_DayStartSrv()   { datetime t = TimeCurrent(); return (datetime)((long)t - ((long)t % 86400)); }
datetime RM_WeekStartSrv()  { datetime d = RM_DayStartSrv(); MqlDateTime s; TimeToStruct(d, s); return (datetime)((long)d - (long)s.day_of_week * 86400); } // Sunday = 0
datetime RM_MonthStartSrv() { MqlDateTime s; TimeToStruct(TimeCurrent(), s); return StringToTime(StringFormat("%04d.%02d.01", s.year, s.mon)); }

// v74.3 (HF2, A3): registers a new period account-wide. If another chart already registered newStart, ADOPT its
// start balance (never overwrite it) and return false; otherwise publish the balance, claim the period atomically
// and return true (this chart is the "winner" and does the once-per-period work).
bool RM_PeriodStartBalance(string gvStart, string gvBal, datetime newStart, double &bal)
{
   double cur = AccountInfoDouble(ACCOUNT_BALANCE);
   if(GlobalVariableCheck(gvStart) && GlobalVariableGet(gvStart) == (double)newStart && GlobalVariableCheck(gvBal))
   { bal = GlobalVariableGet(gvBal); return false; }
   GlobalVariableSet(gvBal, cur);                       // balance first, then the atomic claim of the period
   if(!GlobalVariableCheck(gvStart)) { GlobalVariableSet(gvStart, (double)newStart); GlobalVariablesFlush(); bal = cur; return true; }   // v74.6 (HF6b)
   double oldStart = GlobalVariableGet(gvStart);
   if(GlobalVariableSetOnCondition(gvStart, (double)newStart, oldStart)) { GlobalVariablesFlush(); bal = cur; return true; }   // v74.6 (HF6b)
   bal = GlobalVariableGet(gvBal);                      // lost the race - the winner already published its balance
   return false;
}

double CalcNetResultPercentEx(datetime periodStart, double startBalance, bool allSymbols);
double CalcNetResultPercent(datetime periodStart, double startBalance)
{
   // v74.3 (HF2, D1): ACCOUNT-WIDE (all symbols, this EA's magic) - Daily/Weekly/Monthly DD locks, GetDailyRisk and the
   // Performance panel now all use the same number. Before: only the chart's symbol counted toward the limit.
   return CalcNetResultPercentEx(periodStart, startBalance, true);
}
double CalcNetResultPercentEx(datetime periodStart, double startBalance, bool allSymbols)
{
   if(startBalance<=0) return 0;
   if(!HistorySelect(periodStart, TimeCurrent())) return 0;

   // Pass 1: collect candidate closing (OUT) deal tickets for this symbol, under the wide
   // period-based history selection - INCLUDING their DEAL_POSITION_ID, read here and only here.
   //
   // [Stage 5b bug fix, retroactively applied to this Stage 4 function] Originally, DEAL_POSITION_ID
   // was read in Pass 2, one deal at a time, interleaved with HistorySelectByPosition() calls.
   // Discovered via live Stage 5b testing (ExportTradeJournalCSV hit the identical pattern and
   // produced posId=0 for every deal after the first): HistorySelectByPosition() narrows the
   // terminal's "currently selected" history set, and by-ticket property reads for deals OUTSIDE
   // that narrowed set silently return 0 - contrary to the assumption (stated in Stage 4's original
   // comment here) that by-ticket getters work independent of the active selection. That assumption
   // was wrong. Concretely, this meant: for any period covering 2+ distinct positions, every
   // position's OUT deal AFTER the first one processed would read posId=0 -> HistorySelectByPosition
   // (0) fails -> oursOpen stays false -> that position's P&L was silently excluded from the total.
   // This function (GetDailyRisk/GetWeeklyDrawdown/GetMonthlyDrawdown/CheckDrawdownLimits' basis)
   // has been live since Stage 4 - this bug could have under-counted realized P&L for any day/week/
   // month with more than one closed position, potentially delaying a drawdown lock that should have
   // fired. Fix: read DEAL_POSITION_ID (and profit/swap/commission, also safe to capture now) for
   // EVERY candidate deal while the wide selection is still active, before any narrowing happens.
   ulong  outDeals[];    ArrayResize(outDeals,0);
   ulong  outPosIds[];   ArrayResize(outPosIds,0);
   double outProfit[];   ArrayResize(outProfit,0);
   double outSwap[];     ArrayResize(outSwap,0);
   double outComm[];     ArrayResize(outComm,0);
   int total = HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket==0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue; // only closing deals - entries into a position are not P&L events
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType!=DEAL_TYPE_BUY && dealType!=DEAL_TYPE_SELL) continue;
      if(!allSymbols && HistoryDealGetString(dealTicket, DEAL_SYMBOL)!=_Symbol) continue; // v74.2 (HF3 B3)
      int n=ArraySize(outDeals);
      ArrayResize(outDeals,n+1);  ArrayResize(outPosIds,n+1);
      ArrayResize(outProfit,n+1); ArrayResize(outSwap,n+1); ArrayResize(outComm,n+1);
      outDeals[n]  = dealTicket;
      outPosIds[n] = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      outProfit[n] = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      outSwap[n]   = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      outComm[n]   = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   }

   // Pass 2: for each candidate (using the STORED posId, never re-reading it from history at this
   // point), re-select by position and check the position's OPENING (DEAL_ENTRY_IN) deal's magic -
   // not the closing deal's magic (same reasoning as the original Stage 4 comment below).
   // [Stage 4 bug found via live testing, fixed] Same root cause as the CheckClosedTrades() fix:
   // a closing deal's DEAL_MAGIC is unreliable (a manual close from the terminal, or in this case a
   // broker-triggered SL/TP execution, does not reliably carry the position's original magic).
   // Unlike CheckClosedTrades() (which already knows a tracked ticket is ours from when it was
   // opened), this function scans raw account history with no such prior filter, so it genuinely
   // needs a magic check to scope the total to this EA's trades only - it just needs to check the
   // right deal. The position's IN deal reliably carries request.magic as set by
   // RM_SendMarketOrder()/RM_SendPendingOrder() at open time, regardless of how the position was
   // later closed.
   double net=0;
   for(int j=0;j<ArraySize(outDeals);j++)
   {
      ulong posId = outPosIds[j];
      bool oursOpen=false;
      if(HistorySelectByPosition(posId))
      {
         int posDeals = HistoryDealsTotal();
         for(int k=0;k<posDeals;k++)
         {
            ulong pd = HistoryDealGetTicket(k);
            if(pd==0) continue;
            if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_IN && HistoryDealGetInteger(pd, DEAL_MAGIC)==MagicNumber)
               oursOpen = true;
         }
      }
      if(oursOpen) net += outProfit[j]+outSwap[j]+outComm[j];
   }
   return net/startBalance*100.0;
}

double GetDailyNetResultPercent()   { return CalcNetResultPercent(g_dayStart,   g_dayStartBalance); }
double GetWeeklyNetResultPercent()  { return CalcNetResultPercent(g_weekStart,  g_weekStartBalance); }
double GetMonthlyNetResultPercent() { return CalcNetResultPercent(g_monthStart, g_monthStartBalance); }
// v74.2 (HF3, B3): account-wide versions, for the Performance panel display only.
double GetDailyNetResultPercentAll()   { return CalcNetResultPercentEx(g_dayStart,   g_dayStartBalance,   true); }
double GetWeeklyNetResultPercentAll()  { return CalcNetResultPercentEx(g_weekStart,  g_weekStartBalance,  true); }
double GetMonthlyNetResultPercentAll() { return CalcNetResultPercentEx(g_monthStart, g_monthStartBalance, true); }

// v64 (آیتم ۱ - PriorDayResult): آستانه‌ی نزدیک-صفر برای طبقه‌بندی Breakeven - عمداً کوچیک،
// فقط برای رد کردن نویز اعشاری/کارمزد جزئی، نه یه محدوده‌ی معنادار معاملاتی.
#define PRIOR_DAY_BREAKEVEN_THRESHOLD_PCT 0.05

// v64 (آیتم ۱ - PriorDayResult): درست *قبل* از overwrite شدن g_dayStart/g_dayStartBalance در
// OnTick (فایل اصلی) صدا زده می‌شه - یعنی این دو global هنوز مقادیر روزی هستن که داره تموم می‌شه.
// از همون CalcNetResultPercent بالا (پایه‌ی مشترک Daily P/L) استفاده می‌کنه - هیچ منطق جدیدی
// برای محاسبه‌ی نتیجه‌ی خالص اضافه نمی‌شه. نتیجه هم در حافظه (g_priorDayResultCode) هم در
// GlobalVariable حساب‌محور (GV_PRIOR_DAY_RESULT) ذخیره می‌شه تا بعد از ری‌استارت EA از دست نره.
void ComputePriorDayResult()
{
   double net = CalcNetResultPercent(g_dayStart, g_dayStartBalance);

   double code;
   if(net > PRIOR_DAY_BREAKEVEN_THRESHOLD_PCT)       code = 1.0;   // Win
   else if(net < -PRIOR_DAY_BREAKEVEN_THRESHOLD_PCT) code = -1.0;  // Loss
   else                                                code = 0.0;  // Breakeven

   g_priorDayResultCode = code;
   GlobalVariableSet(GV_PRIOR_DAY_RESULT, code);
   GlobalVariablesFlush();   // v74.6 (HF6b)
}

// v64 (آیتم ۱ - PriorDayResult): تبدیل کد عددی (Snapshot/GlobalVariable - چون GlobalVariable در
// MT4 فقط double قبول می‌کنه) به رشته‌ی خوانا برای CSV. کد -2 (یا هر مقدار نامعتبر/ناشناخته)
// محافظه‌کارانه به "N/A" نگاشت می‌شه.
string PriorDayResultCodeToString(double code)
{
   if(code > 0.5)  return "Win";
   if(code < -0.5 && code > -1.5) return "Loss";
   if(code >= -0.5 && code <= 0.5) return "Breakeven";
   return "N/A"; // شامل -2 (هنوز محاسبه نشده) و هر مقدار غیرمنتظره‌ی دیگه
}

//+------------------------------------------------------------------+
// Calculate weekly drawdown
//+------------------------------------------------------------------+
// v10 (BUG-012): بازنویسی - همون منطق GetDailyRisk، برای دوره‌ی هفتگی
double GetWeeklyDrawdown()
{
   double projected = GetWeeklyNetResultPercent() - GetTotalOpenRisk();
   return (projected<0) ? MathAbs(projected) : 0.0;
}

// v61 (bugfix - BUG-048): نسخه‌ی excluding از GetWeeklyDrawdown بالا - همون فرمول، فقط با
// GetTotalOpenRiskExcludingTicket (RM_RiskCalc.mqh) به‌جای GetTotalOpenRisk. خودِ
// GetWeeklyDrawdown() بالا دست‌نخورده می‌مونه - جاهای دیگه (CheckDrawdownLimits/Dashboard)
// بدون استثنا لازمش دارن.
// [Stage 4] int excludeTicket -> ulong، همون دلیل Stage 2/3 (MT5 ticket 64-بیتی).
double GetWeeklyDrawdownExcludingTicket(ulong excludeTicket)
{
   double projected = GetWeeklyNetResultPercent() - GetTotalOpenRiskExcludingTicket(excludeTicket);
   return (projected<0) ? MathAbs(projected) : 0.0;
}

//+------------------------------------------------------------------+
// Calculate monthly drawdown
//+------------------------------------------------------------------+
// v10 (BUG-012): بازنویسی - همون منطق GetDailyRisk، برای دوره‌ی ماهانه
double GetMonthlyDrawdown()
{
   double projected = GetMonthlyNetResultPercent() - GetTotalOpenRisk();
   return (projected<0) ? MathAbs(projected) : 0.0;
}

// با بالاترین اولویت از OnTick صدا زده می‌شه، مستقل از همه‌ی کول‌داون‌ها و محدودیت‌ها
void CheckFloatingDrawdown()
{
   if(!InpEnableFloatingDD) return;

   double floatPct = GetFloatingPLPercent();

   if(floatPct <= -MathAbs(InpMaxFloatingDDPercent))
   {
      if(!g_floatingDDTriggered)
      {
         g_floatingDDTriggered = true;
         Print("Emergency Close: Floating Drawdown Limit Reached");
         Alert("Emergency Close: Floating Drawdown Limit Reached");
      }
      EmergencyCloseAll();
   }
   else
   {
      g_floatingDDTriggered = false; // ریست تا اگه دوباره به حد رسید، Alert تازه بزنه
   }
}

void CheckDrawdownLimits()
{
   datetime now = TimeCurrent();

   // unlock if expired
   // v51 (Parking Lot #1): آنلاک روزانه، دقیقاً هم‌الگوی weekly/monthly زیر
   if(g_dailyLockEnd>0 && now>=g_dailyLockEnd)
   { g_dailyLockEnd=0; GlobalVariableSet(GV_DAILY_END,0); GlobalVariablesFlush(); }
   if(g_weeklyLockEnd>0 && now>=g_weeklyLockEnd)
   { g_weeklyLockEnd=0; GlobalVariableSet(GV_WEEKLY_END,0); GlobalVariablesFlush(); }
   if(g_monthlyLockEnd>0 && now>=g_monthlyLockEnd)
   { g_monthlyLockEnd=0; GlobalVariableSet(GV_MONTHLY_END,0); GlobalVariablesFlush(); }

   if(g_dailyLockEnd>0 || g_weeklyLockEnd>0 || g_monthlyLockEnd>0) return; // already locked

   // v74 (BUG-051 - MT5 port of MT4 v72's URGENT fix, false Weekly/Monthly DD lock on
   // real-account restart, account A4160750): پنجره‌ی Grace Period بعد از OnInit(). فقط جلوی
   // *ست‌شدن قفل جدید* رو می‌گیره - ddd/wdd/mdd پایین همچنان محاسبه و برای Dashboard/دیباگ
   // استفاده می‌شن؛ قفل‌های از قبل فعال (خط بالا، g_*LockEnd>0 از LoadDrawdownState) اصلاً به
   // این شرط نرسیدن - دست‌نخورده می‌مونن.
   bool inStartupGrace = (now < g_eaStartupTime + StartupGracePeriodSeconds);

   // check daily
   // v51 (Parking Lot #1): همون GetDailyRisk() که قبلاً فقط زنده مقایسه می‌شد (در CheckLimits/
   // Dashboard) - همون منبع مقایسه، فقط الان علاوه‌بر بلاک لحظه‌ای، یه قفل persisted هم می‌سازه
   // که مستقل از تغییر بعدی Input/EnableDailyDD تا پایان مدت پابرجا می‌مونه.
   double ddd = GetDailyRisk();
   if(EnableDailyDD && ddd >= g_effMaxDailyRisk && g_dailyLockEnd==0 && !inStartupGrace)
   {
      g_dailyLockEnd = now + DailyDDLockHours*3600;
      GlobalVariableSet(GV_DAILY_END, (double)g_dailyLockEnd);
      GlobalVariablesFlush();   // v74.6 (HF6b)
      Alert("RM: Daily DD "+DoubleToString(ddd,2)+"% - Locked "+IntegerToString(DailyDDLockHours)+"h");
   }

   // check weekly
   double wdd = GetWeeklyDrawdown();
   if(EnableWeeklyDD && wdd >= g_effMaxWeeklyDD && g_weeklyLockEnd==0 && !inStartupGrace)
   {
      g_weeklyLockEnd = now + WeeklyDDHours*3600;
      GlobalVariableSet(GV_WEEKLY_END, (double)g_weeklyLockEnd);
      GlobalVariablesFlush();   // v74.6 (HF6b)
      Alert("RM: Weekly DD "+DoubleToString(wdd,2)+"% - Locked "+IntegerToString(WeeklyDDHours)+"h");
   }

   // check monthly
   double mdd = GetMonthlyDrawdown();
   if(EnableMonthlyDD && mdd >= g_effMaxMonthlyDD && g_monthlyLockEnd==0 && !inStartupGrace)
   {
      g_monthlyLockEnd = now + MonthlyDDDays*24*3600;
      GlobalVariableSet(GV_MONTHLY_END, (double)g_monthlyLockEnd);
      GlobalVariablesFlush();   // v74.6 (HF6b)
      Alert("RM: Monthly DD "+DoubleToString(mdd,2)+"% - Locked "+IntegerToString(MonthlyDDDays)+"d");
   }

   // v74: دیاگنوستیک - فقط در پنجره‌ی Grace Period، هر بار CheckDrawdownLimits() صدا زده می‌شه
   // (Print نه Alert - مزاحم ترید نمی‌شه). اگه دوباره این اتفاق افتاد، لاگ Experts دقیقاً مسیر
   // ddd/wdd/mdd رو از تیک اول نشون می‌ده - از همون تیک ۱۶٪ بوده یا از یه مقدار منطقی ramp کرده.
   // v74.4 (HF4): at most one line per second per chart (it used to print on every tick/timer call).
   static long s_lastGraceDiagSec = -1;
   if(RM_GRACE_DIAG && inStartupGrace && (long)now != s_lastGraceDiagSec)   // v75.2: پیام تشخیصی v74 به‌طور پیش‌فرض خاموش (RM_GRACE_DIAG در RM_Config)
   {
      s_lastGraceDiagSec = (long)now;
      Print("RM v74 startup-grace diag: ddd=", DoubleToString(ddd,2), "% wdd=", DoubleToString(wdd,2),
            "% mdd=", DoubleToString(mdd,2), "% (grace ends in ",
            (long)(g_eaStartupTime + StartupGracePeriodSeconds - now), "s)");
   }
}

//+------------------------------------------------------------------+
// Save/Load drawdown lock
//+------------------------------------------------------------------+
void SaveDrawdownState()
{
   // v51 (Parking Lot #1): GV_DAILY_END، دقیقاً هم‌الگوی دو خط زیر
   GlobalVariableSet(GV_DAILY_END,   (double)g_dailyLockEnd);
   GlobalVariableSet(GV_WEEKLY_END,  (double)g_weeklyLockEnd);
   GlobalVariableSet(GV_MONTHLY_END, (double)g_monthlyLockEnd);
   GlobalVariablesFlush();   // v74.6 (HF6b): قفل‌ها باید بعد از کرش/ریست زنده بمونن

   // v74.3 (HF2, A3): period start/balance GVs are no longer written from this chart's local copy here (a chart
   // that had not yet rolled over could overwrite the new period registered by another chart). They are written
   // only by RM_PeriodStartBalance() (rollover) and LoadDrawdownState() (attach).
}

void LoadDrawdownState()
{
   // v51 (Parking Lot #1): بارگذاری GV_DAILY_END، دقیقاً هم‌الگوی دو خط زیر
   if(GlobalVariableCheck(GV_DAILY_END))   g_dailyLockEnd   = (datetime)GlobalVariableGet(GV_DAILY_END);
   if(GlobalVariableCheck(GV_WEEKLY_END))  g_weeklyLockEnd  = (datetime)GlobalVariableGet(GV_WEEKLY_END);
   if(GlobalVariableCheck(GV_MONTHLY_END)) g_monthlyLockEnd = (datetime)GlobalVariableGet(GV_MONTHLY_END);
   datetime now = TimeCurrent();
   if(g_dailyLockEnd>0   && now>=g_dailyLockEnd)   g_dailyLockEnd=0;
   if(g_weeklyLockEnd>0  && now>=g_weeklyLockEnd)  g_weeklyLockEnd=0;
   if(g_monthlyLockEnd>0 && now>=g_monthlyLockEnd) g_monthlyLockEnd=0;

   // v10 (BUG-012): بارگذاری بالانس شروع دوره. اگه دوره‌ی ذخیره‌شده با دوره‌ی جاری (g_dayStart/weekStart/monthStart
   // که قبل از این تابع در OnInit محاسبه شدن) یکی باشه، از GV می‌خونیم. در غیر این صورت (اولین اجرا، یا مرز دوره
   // در حین خاموش بودن EA رد شده) با بالانس فعلی مقداردهی اولیه می‌شه.
   // v74.3 (HF2, A3, MT4 v102): g_*Start are SERVER-time boundaries (same on every chart). A stored period is
   // accepted (balance ADOPTED, never overwritten) if its start is within a tolerance of this chart's boundary -
   // that covers the old per-symbol iTime boundaries (e.g. gold vs crypto W1/MN1 opens) and the first run after
   // upgrading. Only a clearly different (older) period gets a fresh balance.
   // Daily: if the new account-wide day keys do not exist yet, migrate today's value from the old per-symbol keys.
   if(!GlobalVariableCheck(GV_DAY_START) && GlobalVariableCheck(GV_DAY_START_OLD) && GlobalVariableCheck(GV_DAY_START_BAL_OLD) &&
      MathAbs(GlobalVariableGet(GV_DAY_START_OLD) - (double)g_dayStart) <= 43200)
   {
      GlobalVariableSet(GV_DAY_START_BAL, GlobalVariableGet(GV_DAY_START_BAL_OLD));
      GlobalVariableSet(GV_DAY_START, (double)g_dayStart);
      Print("[RM-PERIOD] daily start balance migrated from the old per-symbol key");
   }
   if(GlobalVariableCheck(GV_DAY_START) && GlobalVariableCheck(GV_DAY_START_BAL) &&
      MathAbs(GlobalVariableGet(GV_DAY_START) - (double)g_dayStart) <= 43200)
   {
      g_dayStartBalance = GlobalVariableGet(GV_DAY_START_BAL);
      GlobalVariableSet(GV_DAY_START, (double)g_dayStart);
   }
   else
   {
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      GlobalVariableSet(GV_DAY_START_BAL, g_dayStartBalance);
      GlobalVariableSet(GV_DAY_START, (double)g_dayStart);
   }

   if(GlobalVariableCheck(GV_WEEK_START) && GlobalVariableCheck(GV_WEEK_START_BAL) &&
      MathAbs(GlobalVariableGet(GV_WEEK_START) - (double)g_weekStart) <= 259200)
   {
      g_weekStartBalance = GlobalVariableGet(GV_WEEK_START_BAL);
      GlobalVariableSet(GV_WEEK_START, (double)g_weekStart);
   }
   else
   {
      g_weekStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      GlobalVariableSet(GV_WEEK_START_BAL, g_weekStartBalance);
      GlobalVariableSet(GV_WEEK_START, (double)g_weekStart);
   }

   if(GlobalVariableCheck(GV_MONTH_START) && GlobalVariableCheck(GV_MONTH_START_BAL) &&
      MathAbs(GlobalVariableGet(GV_MONTH_START) - (double)g_monthStart) <= 432000)
   {
      g_monthStartBalance = GlobalVariableGet(GV_MONTH_START_BAL);
      GlobalVariableSet(GV_MONTH_START, (double)g_monthStart);
   }
   else
   {
      g_monthStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      GlobalVariableSet(GV_MONTH_START_BAL, g_monthStartBalance);
      GlobalVariableSet(GV_MONTH_START, (double)g_monthStart);
   }

   // v64 (آیتم ۱ - PriorDayResult): بازیابی مقدار حساب‌محور بعد از ری‌استارت EA - اگه هنوز هیچ
   // day-reset ای برای این حساب اتفاق نیفتاده (کلید وجود نداره)، محافظه‌کارانه با -2 (N/A) که
   // مقدار پیش‌فرض همون global هست باقی می‌مونه.
   if(GlobalVariableCheck(GV_PRIOR_DAY_RESULT))
      g_priorDayResultCode = GlobalVariableGet(GV_PRIOR_DAY_RESULT);
}
