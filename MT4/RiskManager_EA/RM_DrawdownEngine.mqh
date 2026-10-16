//+------------------------------------------------------------------+
//| RM_DrawdownEngine.mqh                                              |
//| Risk Manager EA - Drawdown Protection Engine (Architecture         |
//| Refactor, R6)                                                      |
//| استخراج‌شده از RiskManager_EA_v45_R5.mq4 - موتور محافظت از Drawdown:  |
//| GetWeeklyDrawdown/GetMonthlyDrawdown، CheckFloatingDrawdown،        |
//| CheckDrawdownLimits، Save/LoadDrawdownState، و پایه‌ی مشترک نتیجه‌ی   |
//| خالص%: CalcNetResultPercent + سه wrapper روزانه/هفتگی/ماهانه‌اش.     |
//| صرفاً جابه‌جایی کد، بدون هیچ تغییر مقدار/رفتار (Golden Rule فاز R6). |
//+------------------------------------------------------------------+

// === v10 (BUG-012): نتیجه‌ی خالص واقعی% یک دوره - سود و ضرر معاملات بسته‌شده (نه فقط ضررها)
// نسبت به بالانس شروع همون دوره. مبنای مشترک هم برای منطق قفل (زیر) و هم باکس‌های نمایشی P/L%.
double CalcNetResultPercent(datetime periodStart, double startBalance)
{
   if(startBalance<=0) return 0;
   double net=0;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderCloseTime()<periodStart) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      net += OrderProfit()+OrderSwap()+OrderCommission();
   }
   return net/startBalance*100.0;
}

double GetDailyNetResultPercent()   { return CalcNetResultPercent(g_dayStart,   g_dayStartBalance); }
double GetWeeklyNetResultPercent()  { return CalcNetResultPercent(g_weekStart,  g_weekStartBalance); }
double GetMonthlyNetResultPercent() { return CalcNetResultPercent(g_monthStart, g_monthStartBalance); }

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
double GetWeeklyDrawdownExcludingTicket(int excludeTicket)
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

   // v77 (URGENT bugfix - Pattern A, false Monthly/Weekly DD lock after long sleep/reconnect WITHOUT
   // OnInit): v72's grace window keys off g_eaStartupTime, which only updates on a *real OnInit*. The
   // 2026-08-10 incident (account A4160750) resumed from a ~9h machine sleep with NO OnInit and fired a
   // false Monthly DD lock 37s later - inStartupGrace was false because g_eaStartupTime was ~9h stale.
   // Fix: if the gap since the last DD-check cycle is abnormally large, RE-OPEN the very same grace
   // window (set g_eaStartupTime = now) so this path behaves identically to a fresh OnInit. Detected via
   // BOTH clocks - GetTickCount() (wall-clock; captured this exact incident as a 32,202,250ms OnTimer
   // gap) AND TimeCurrent() (market-time; catches reconnect tick-replay where wall-clock alone wouldn't).
   // This runs BEFORE the unlock/early-return block below so it can never be skipped by an active lock.
   uint nowMs = GetTickCount();
   bool longGap = false;
   if(g_lastDDCheckMs != 0 && (nowMs - g_lastDDCheckMs) > (uint)LongGapGraceThresholdSeconds*1000)
      longGap = true;   // unsigned subtraction -> correct across GetTickCount()'s ~49.7-day wrap
   if(g_lastDDCheckTime != 0 && (long)(now - g_lastDDCheckTime) > (long)LongGapGraceThresholdSeconds)
      longGap = true;
   if(longGap)
   {
      g_eaStartupTime = now;   // re-open the SAME grace window used after OnInit
      Print("RM v77 Pattern-A: long gap between DD checks (wall=", (g_lastDDCheckMs!=0 ? (nowMs-g_lastDDCheckMs)/1000 : 0),
            "s, market=", (g_lastDDCheckTime!=0 ? (long)(now-g_lastDDCheckTime) : 0),
            "s, no OnInit) -> grace re-opened, new DD locks suppressed for ", StartupGracePeriodSeconds, "s");
   }
   g_lastDDCheckMs   = nowMs;
   g_lastDDCheckTime = now;

   // v102: قفل‌های روزانه/هفتگی/ماهانه account-wide هستند؛ هر تیک از GV (منبع مشترک) تازه می‌شوند (۳ GlobalVariableGet) تا
   // قفلی که چارت دیگر (نماد دیگر) نشانده همین‌جا هم دیده شود.
   if(GlobalVariableCheck(GV_DAILY_END))   g_dailyLockEnd   = (datetime)GlobalVariableGet(GV_DAILY_END);
   if(GlobalVariableCheck(GV_WEEKLY_END))  g_weeklyLockEnd  = (datetime)GlobalVariableGet(GV_WEEKLY_END);
   if(GlobalVariableCheck(GV_MONTHLY_END)) g_monthlyLockEnd = (datetime)GlobalVariableGet(GV_MONTHLY_END);

   // unlock if expired
   // v51 (Parking Lot #1): آنلاک روزانه، دقیقاً هم‌الگوی weekly/monthly زیر
   if(g_dailyLockEnd>0 && now>=g_dailyLockEnd)
   { g_dailyLockEnd=0; GlobalVariableSet(GV_DAILY_END,0); }
   if(g_weeklyLockEnd>0 && now>=g_weeklyLockEnd)
   { g_weeklyLockEnd=0; GlobalVariableSet(GV_WEEKLY_END,0); }
   if(g_monthlyLockEnd>0 && now>=g_monthlyLockEnd)
   { g_monthlyLockEnd=0; GlobalVariableSet(GV_MONTHLY_END,0); }

   if(g_dailyLockEnd>0 || g_weeklyLockEnd>0 || g_monthlyLockEnd>0) return; // already locked

   // v72 (URGENT bugfix - false Weekly/Monthly DD lock on real-account restart, account
   // A4160750): پنجره‌ی Grace Period بعد از OnInit(). فقط جلوی *ست‌شدن قفل جدید* رو می‌گیره -
   // ddd/wdd/mdd پایین همچنان محاسبه و برای Dashboard/دیباگ استفاده می‌شن؛ قفل‌های از قبل فعال
   // (خط بالا، g_*LockEnd>0 از LoadDrawdownState) اصلاً به این شرط نرسیدن - دست‌نخورده می‌مونن.
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
      Alert("RM: Daily DD "+DoubleToStr(ddd,2)+"% - Locked "+IntegerToString(DailyDDLockHours)+"h");
   }

   // check weekly
   double wdd = GetWeeklyDrawdown();
   if(EnableWeeklyDD && wdd >= g_effMaxWeeklyDD && g_weeklyLockEnd==0 && !inStartupGrace)
   {
      g_weeklyLockEnd = now + WeeklyDDHours*3600;
      GlobalVariableSet(GV_WEEKLY_END, (double)g_weeklyLockEnd);
      Alert("RM: Weekly DD "+DoubleToStr(wdd,2)+"% - Locked "+IntegerToString(WeeklyDDHours)+"h");
   }

   // check monthly
   double mdd = GetMonthlyDrawdown();
   if(EnableMonthlyDD && mdd >= g_effMaxMonthlyDD && g_monthlyLockEnd==0 && !inStartupGrace)
   {
      g_monthlyLockEnd = now + MonthlyDDDays*24*3600;
      GlobalVariableSet(GV_MONTHLY_END, (double)g_monthlyLockEnd);
      Alert("RM: Monthly DD "+DoubleToStr(mdd,2)+"% - Locked "+IntegerToString(MonthlyDDDays)+"d");
   }

   // v72: دیاگنوستیک - فقط در پنجره‌ی Grace Period، هر بار CheckDrawdownLimits() صدا زده می‌شه
   // (Print نه Alert - مزاحم ترید نمی‌شه). اگه دوباره این اتفاق افتاد، لاگ Experts دقیقاً مسیر
   // ddd/wdd/mdd رو از تیک اول نشون می‌ده - از همون تیک ۱۶٪ بوده یا از یه مقدار منطقی ramp کرده.
   if(inStartupGrace)
   {
      Print("RM v72 startup-grace diag: ddd=", DoubleToStr(ddd,2), "% wdd=", DoubleToStr(wdd,2),
            "% mdd=", DoubleToStr(mdd,2), "% (grace ends in ",
            (long)(g_eaStartupTime + StartupGracePeriodSeconds - now), "s)");
   }
}

//+------------------------------------------------------------------+
// Save/Load drawdown lock
//+------------------------------------------------------------------+
void SaveDrawdownState()
{
   PatternBDiag("SaveDrawdownState");  // v77 (Pattern B investigation - TEMPORARY): لحظه‌ی نوشتنِ واقعیِ بالانس شروع دوره - اگه کلید به حساب اشتباه اشاره کنه، همین‌جا لو می‌ره
   // v51 (Parking Lot #1): GV_DAILY_END، دقیقاً هم‌الگوی دو خط زیر
   GlobalVariableSet(GV_DAILY_END,   (double)g_dailyLockEnd);
   GlobalVariableSet(GV_WEEKLY_END,  (double)g_weeklyLockEnd);
   GlobalVariableSet(GV_MONTHLY_END, (double)g_monthlyLockEnd);

   // v10 (BUG-012): بالانس/زمان شروع دوره - تا بعد از ری‌استارت EA از دست نره
   GlobalVariableSet(GV_DAY_START,       (double)g_dayStart);
   GlobalVariableSet(GV_DAY_START_BAL,   g_dayStartBalance);
   GlobalVariableSet(GV_WEEK_START,      (double)g_weekStart);
   GlobalVariableSet(GV_WEEK_START_BAL,  g_weekStartBalance);
   GlobalVariableSet(GV_MONTH_START,     (double)g_monthStart);
   GlobalVariableSet(GV_MONTH_START_BAL, g_monthStartBalance);
}

void LoadDrawdownState()
{
   PatternBDiag("LoadDrawdownState");  // v77 (Pattern B investigation - TEMPORARY): لحظه‌ی خوندنِ بالانس شروع دوره از GV - اگه کلید به حساب اشتباه اشاره کنه (مخرج Drawdown% غلط می‌شه)، همین‌جا لو می‌ره
   // v51 (Parking Lot #1): بارگذاری GV_DAILY_END، دقیقاً هم‌الگوی دو خط زیر
   // v77 (نشتِ درون‌حافظه‌ایِ زمانِ پایانِ قفل - هم‌کلاسِ فیکسِ LoadCooldownState): این سه متغیر
   // با سوییچِ حساب صفر نمی‌شن. قبلاً «if(check) load» بود؛ اگه اکانتِ تازه کلیدِ END نداشت، مقدارِ
   // اکانتِ قبلی در حافظه می‌موند → اکانتِ B قفلِ اکانتِ A رو به ارث می‌بُرد (قفلِ کاذب). چکِ انقضای
   // پایین فقط قفلِ *منقضی‌شده* رو صفر می‌کنه نه قفلِ آینده‌ی نشت‌کرده رو. حالا authoritative: کلیدِ
   // غایب صریحاً 0 می‌ده. (LoadDrawdownState فقط در OnInit صدا زده می‌شه و هر تغییرِ قفل بلافاصله
   // SaveDrawdownState می‌شه، پس امنه.)
   g_dailyLockEnd   = GlobalVariableCheck(GV_DAILY_END)   ? (datetime)GlobalVariableGet(GV_DAILY_END)   : 0;
   g_weeklyLockEnd  = GlobalVariableCheck(GV_WEEKLY_END)  ? (datetime)GlobalVariableGet(GV_WEEKLY_END)  : 0;
   g_monthlyLockEnd = GlobalVariableCheck(GV_MONTHLY_END) ? (datetime)GlobalVariableGet(GV_MONTHLY_END) : 0;
   datetime now = TimeCurrent();
   if(g_dailyLockEnd>0   && now>=g_dailyLockEnd)   g_dailyLockEnd=0;
   if(g_weeklyLockEnd>0  && now>=g_weeklyLockEnd)  g_weeklyLockEnd=0;
   if(g_monthlyLockEnd>0 && now>=g_monthlyLockEnd) g_monthlyLockEnd=0;

   // v10 (BUG-012): بارگذاری بالانس شروع دوره. اگه دوره‌ی ذخیره‌شده با دوره‌ی جاری (g_dayStart/weekStart/monthStart
   // که قبل از این تابع در OnInit محاسبه شدن) یکی باشه، از GV می‌خونیم. در غیر این صورت (اولین اجرا، یا مرز دوره
   // در حین خاموش بودن EA رد شده) با بالانس فعلی مقداردهی اولیه می‌شه.
   // v102: تحمل زمانی برای گذار از مرز دوره‌ی قدیمی (iTime per-symbol) به مرز زمان سرور؛ دوره‌ی قبلی خارج از تحمل می‌افتد (۱ روز/۷ روز/۲۸+ روز)
   if(GlobalVariableCheck(GV_DAY_START) && MathAbs((double)((datetime)GlobalVariableGet(GV_DAY_START) - g_dayStart)) <= 43200 && GlobalVariableCheck(GV_DAY_START_BAL))
      { g_dayStartBalance = GlobalVariableGet(GV_DAY_START_BAL); GlobalVariableSet(GV_DAY_START, (double)g_dayStart); }
   else
   {
      g_dayStartBalance = AccountBalance();
      GlobalVariableSet(GV_DAY_START, (double)g_dayStart);
      GlobalVariableSet(GV_DAY_START_BAL, g_dayStartBalance);
   }

   // v102: تحمل زمانی برای گذار از مرز دوره‌ی قدیمی (iTime per-symbol) به مرز زمان سرور؛ دوره‌ی قبلی خارج از تحمل می‌افتد (۱ روز/۷ روز/۲۸+ روز)
   if(GlobalVariableCheck(GV_WEEK_START) && MathAbs((double)((datetime)GlobalVariableGet(GV_WEEK_START) - g_weekStart)) <= 259200 && GlobalVariableCheck(GV_WEEK_START_BAL))
      { g_weekStartBalance = GlobalVariableGet(GV_WEEK_START_BAL); GlobalVariableSet(GV_WEEK_START, (double)g_weekStart); }
   else
   {
      g_weekStartBalance = AccountBalance();
      GlobalVariableSet(GV_WEEK_START, (double)g_weekStart);
      GlobalVariableSet(GV_WEEK_START_BAL, g_weekStartBalance);
   }

   // v102: تحمل زمانی برای گذار از مرز دوره‌ی قدیمی (iTime per-symbol) به مرز زمان سرور؛ دوره‌ی قبلی خارج از تحمل می‌افتد (۱ روز/۷ روز/۲۸+ روز)
   if(GlobalVariableCheck(GV_MONTH_START) && MathAbs((double)((datetime)GlobalVariableGet(GV_MONTH_START) - g_monthStart)) <= 432000 && GlobalVariableCheck(GV_MONTH_START_BAL))
      { g_monthStartBalance = GlobalVariableGet(GV_MONTH_START_BAL); GlobalVariableSet(GV_MONTH_START, (double)g_monthStart); }
   else
   {
      g_monthStartBalance = AccountBalance();
      GlobalVariableSet(GV_MONTH_START, (double)g_monthStart);
      GlobalVariableSet(GV_MONTH_START_BAL, g_monthStartBalance);
   }

   // v64 (آیتم ۱ - PriorDayResult): بازیابی مقدار حساب‌محور بعد از ری‌استارت EA - اگه هنوز هیچ
   // day-reset ای برای این حساب اتفاق نیفتاده (کلید وجود نداره)، محافظه‌کارانه با -2 (N/A) که
   // مقدار پیش‌فرض همون global هست باقی می‌مونه.
   if(GlobalVariableCheck(GV_PRIOR_DAY_RESULT))
      g_priorDayResultCode = GlobalVariableGet(GV_PRIOR_DAY_RESULT);
}

