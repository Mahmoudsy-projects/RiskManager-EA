//+------------------------------------------------------------------+
//| RM_MainEventHandlers.mq5                                           |
//| Risk Manager EA - Event Handlers (MT5 Port, Stage 5c-ii)            |
//| پورت مستقیم OnInit/OnDeinit/OnTimer/OnTick/OnChartEvent + ۵ تابع     |
//| کمکی رنگ از خودِ RiskManager_EA_v70.mq4. Golden Rule: فرمول‌ها/         |
//| آستانه‌ها/ترتیب عملیات دست‌نخورده - این استیج فقط سیم‌کشیه، نه         |
//| بازطراحی. OnChartEvent() دقیقاً همون توالی if-گاردهای مستقلیه که      |
//| بود - هیچ سوییچ/دیسپچر جدیدی معرفی نشده.                             |
//|                                                                     |
//| [Stage 5c-ii] وابستگی زیادی به RM_Tools.mqh (Stage 5d، هنوز پورت      |
//| نشده) داره - طبق دستور صریح تسک، خودِ کد سیم‌کشی (فراخوانی‌ها به این    |
//| توابع) کامل پورت شده؛ فقط بدنه‌ی خودِ توابع RM_Tools.mqh استاب شدن.    |
//| لیست کامل هدف‌های استاب‌شده در گزارش این استیج آورده شده.              |
//+------------------------------------------------------------------+

// v13 (فیکس فلش زدن): جلوگیری از rebuild بیش‌ازحد مکرر پنل روی CHARTEVENT_CHART_CHANGE - فقط
// همین‌جا (خودِ OnChartEvent، تنها مصرف‌کننده‌ش) لازمه، نه یه استاب خارجی.
datetime g_panelLastRebuild = 0;

//+------------------------------------------------------------------+
// v30 (Button Click Feedback Part 1) / v34.5 / v42 / v49 / v51: رنگ‌های کمکی پیش‌نمایش/دکمه -
// [Stage 5c-ii] الحاق پیش‌دستانه‌ی اسکوپ - این ۵ تابع کوچیک و خودکفا از خودِ .mq4 اصلی، مستقیم
// داخل رندر پیش‌نمایش زنده‌ی OnChartEvent (ابزارهای Risk/Reward و Measure Move) لازمن. طبق همون
// فلسفه‌ی الحاق RM_Common.mqh (Stage 3) و GetFloatingPLPercent/EmergencyCloseAll (Stage 4)، الان
// واقعاً پورت شدن، نه Stub - RM_Tools.mqh (Stage 5d) وقتی نوبتش برسه همین نسخه‌های پورت‌شده رو صدا می‌زنه.
//+------------------------------------------------------------------+
color DimForButton(color c)
{
   int r = (int)(c & 0xFF);
   int g = (int)((c >> 8) & 0xFF);
   int b = (int)((c >> 16) & 0xFF);
   r = (int)(r*0.55); g = (int)(g*0.55); b = (int)(b*0.55);
   return (color)(r + (g<<8) + (b<<16));
}

color ResolveFiboLineColor(color bodyColor)
{
   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   double bgLum   = 0.299*(chartBg & 0xFF)   + 0.587*((chartBg >> 8) & 0xFF)   + 0.114*((chartBg >> 16) & 0xFF);
   double bodyLum = 0.299*(bodyColor & 0xFF) + 0.587*((bodyColor >> 8) & 0xFF) + 0.114*((bodyColor >> 16) & 0xFF);
   color lvlColor = bodyColor;
   bool bodyBlendsIntoBg = (MathAbs(bodyLum - bgLum) < 30) || (bodyColor == clrNONE);
   if(bodyBlendsIntoBg) lvlColor = (color)ChartGetInteger(0, CHART_COLOR_CHART_LINE);
   if(bgLum > 140) lvlColor = DimForButton(lvlColor);
   return lvlColor;
}
// v75.5 (پورت MT4 v84 «کار سوم»): رنگ خطوط R/R و Measure Move دیگر به رنگ کندل وابسته نیست - یک خاکستری ثابت با
// فاصله‌ی luminance تضمین‌شده از بک‌گراند چارت. بک‌گراند روشن (>=128) -> خاکستری تیره‌تر؛ تیره -> خاکستری روشن‌تر.
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
// Session Level قبلاً از GetFiboMeasureColor() رنگ می‌گرفت؛ منطق قبلی (بدنه‌ی کندل نزولی + کنتراست خودکار) عیناً اینجا
// نگه داشته شد تا رنگ Session Level تغییر نکند (مثل MT4 v84).
color GetSessionLevelBoxColor()
{
   color bodyColor = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
   return ResolveFiboLineColor(bodyColor);
}
color GetPreviewLabelColor()
{
   return ResolveFiboLineColor(clrWhite);
}

// v9.7: هر کلیک یک واحد به RR اضافه می‌کنه، در بازه ۱ تا ۵؛ بعد از ۵ به ۱ برمی‌گرده.
// [Stage 5c-ii] یه الحاق کوچیک دیگه، همون دلیل بالا - BTN_RR مستقیم صداش می‌زنه، خودکفا و بی‌خطره.
void CycleRR()
{
   g_riskReward += 1.0;
   if(g_riskReward > 5.0 + 0.0001)
      g_riskReward = 1.0;
}

// [Stage 5c-ii, corrected via live testing] SetStatus() was initially mis-scoped as a Stage 5d
// (RM_Tools.mqh) dependency and stubbed - but it's actually declared in the main .mq4 alongside the
// event handlers this stage already owns, and it's small/self-contained: every symbol it touches
// (FitBoxFont, ALERT_PAD, g_statusBoxTop, ACTION_MSG_SECONDS, g_actionMsgUntil) is already real.
// Found live: every button's status-bar feedback throughout this stage's click-testing was silently
// only reaching Print()/the Experts log via the stub, never the visible panel text, until this fix.
// Same proactive-port reasoning as CycleRR/RectC/PadR/PadL/RRGlowColors/BestFitMonoFont above.
void SetStatus(string msg,color clr)
{
   ObjectSetString(0,P+"L_STATUS",OBJPROP_TEXT,msg);
   ObjectSetInteger(0,P+"L_STATUS",OBJPROP_COLOR,RM_Txt(clr));
   FitBoxFont(P+"L_STATUS", msg);
   ObjectSetString(0,P+"L_STATUS2",OBJPROP_TEXT," "); // [Stage 5c-i empty-label fix, carried forward] "" renders as literal "Label" text on MT5
   ObjectSetInteger(0,P+"L_STATUS",OBJPROP_YDISTANCE, g_statusBoxTop + SC(17));
   g_actionMsgUntil = TimeCurrent() + ACTION_MSG_SECONDS;
   ChartRedraw();
}

// v9.4 - not called anywhere in the current source (superseded by SetStatus() for the permanent
// status line since v8), kept for compatibility per the original's own comment. Ported alongside
// SetStatus() since it's equally small/self-contained and shares the exact same empty-label risk.
void SetStatus2(string msg,color clr)
{
   ObjectSetString(0,P+"L_STATUS2",OBJPROP_TEXT, (msg=="" ? " " : msg)); // [Stage 5c-i empty-label fix, carried forward]
   ObjectSetInteger(0,P+"L_STATUS2",OBJPROP_COLOR,RM_Txt(clr));
   if(msg != "")
   {
      ObjectSetInteger(0,P+"L_STATUS",  OBJPROP_YDISTANCE, g_statusBoxTop + SC(10));
      ObjectSetInteger(0,P+"L_STATUS2", OBJPROP_YDISTANCE, g_statusBoxTop + SC(24));
   }
   else
   {
      ObjectSetInteger(0,P+"L_STATUS", OBJPROP_YDISTANCE, g_statusBoxTop + SC(17));
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
int OnInit()
{
   // v74 (BUG-051 - MT5 port of MT4 v72's URGENT fix): ثبت می‌شه به‌عنوان اولین خط OnInit() -
   // قبل از هر Load*()ای که ممکنه در طول یک reconnect کند (حساب واقعی) روی
   // AccountInfoDouble(ACCOUNT_BALANCE)/تاریخچه‌ی دیل‌ها مقدار ناپایدار/موقت بخونه. مبنای
   // پنجره‌ی Grace Period (CheckDrawdownLimits در RM_DrawdownEngine.mq5) دقیقاً از همین لحظه
   // شمرده می‌شه.
   g_eaStartupTime = TimeCurrent();
   RM_ThemeInit((int)DashTheme);   // v75.17 (MT4 v110): theme colour table must be initialised first
   ApplyLayoutScale();
   RM_LoadSharedSettings();      // v75.15 (MT4 v102/v104): shared account-wide settings, before any consumer
   ApplyRiskCeilings();
   g_riskReward = RiskReward;
   g_dayStart   = RM_DayStartSrv();    // v74.3 (HF2, A3): server-time boundaries, identical on every chart
   g_weekStart  = RM_WeekStartSrv();
   g_monthStart = RM_MonthStartSrv();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
   InitAutoCloseAtHour();        // v75.4 (MT4 v80 FEAT-031)
   LoadRiskStepState();          // v75.10 (FEAT-038)
   LoadCooldownState();
   LoadDrawdownState();
   LoadDashboardModeState();
   ST_ServerOffsetSec();         // v75.0 (P0-1): GV آفست پایدار را زود لود می‌کند (قبل از ساخت اولین باکس Session)
   LoadCandleTimerState();       // [Stage 5c-ii, RM_Tools.mqh stub]
   LoadSessionWindowsState();    // [Stage 5c-ii, RM_Tools.mqh stub]
   SessionLevel_LoadState();     // [Stage 5c-ii, RM_Tools.mqh stub]
   History_LoadState();          // v75.11 (MT4 v85)
   LoadEntryExitMarkersState();  // [Stage 5c-ii, RM_Tools.mqh stub]
   LoadTradeSnapshots();         // real, Stage 5a
   RefreshChainRootKeys();       // v75.13 (MT4 v87)
   GlobalVariablesDeleteAll("RM_Claim_", TimeCurrent()-7*86400); // v74.2 (HF3 B2): purge old closed-ticket claim markers
   GlobalVariablesDeleteAll("RM_PendClaim_", TimeCurrent()-7*86400); // v74.5 (HF5): purge old pending-activation claim markers
   GlobalVariablesDeleteAll("RM_HALFEXEMPT_A",   TimeCurrent()-30*86400); // v75.0: purge old persistent flags
   GlobalVariablesDeleteAll("RM_TAMPERSTRIKED_A", TimeCurrent()-30*86400); // v75.0
   RM_PendingResumeAtInit();     // v74.5 (HF5): one-time at init - re-track live pendings, log placement-source snapshots
   RM_ReconcileClosedAtInit();   // v75.0 (P0): classify closed positions that were never processed (EA was off/restarting)
   EnsureStrategySetupsSeed();   // [Stage 5c-ii, RM_Tools.mqh stub]
   LoadTradeTagsFile();          // [Stage 5c-ii, RM_Tools.mqh stub]
   EnsureContextChecklistSeed(); // v75.14 (MT4 v81 FEAT-037): فایل جدا/مستقل RM_ContextChecklist.txt
   RM_EnsureDashboardFiles();    // v75.16: RM_Dashboard.html + RM_Dashboard_Data.js در MQL5\Files (بدون DLL)
   LoadContextTagsFile();        // v75.14: نگاشت Ticket->۵ Boolean (RM_ContextTags.csv)
   EnsureScreenshotFolder();     // [Stage 5c-ii, RM_Tools.mqh stub]
   BuildPanel();                 // real, Stage 5c-i
   UpdateRiskDisplay();          // real, Stage 5c-i
   UpdateCandleTimerChart(true); // [Stage 5c-ii, RM_Tools.mqh stub]
   if(g_swOn) BuildSessionWindows();             // [Stage 5c-ii, RM_Tools.mqh stub]
   if(g_sessLvlOn) SessionLevel_BuildWindows();  // [Stage 5c-ii, RM_Tools.mqh stub]
   if(g_histOn) History_Build();                 // v75.11
   if(g_markersOn) BuildEntryExitMarkers();      // [Stage 5c-ii, RM_Tools.mqh stub]
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

string GetDeinitReasonText(const int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:     return "EA called ExpertRemove";
      case REASON_REMOVE:      return "EA removed from chart";
      case REASON_RECOMPILE:   return "EA recompiled";
      case REASON_CHARTCHANGE: return "symbol/timeframe changed";
      case REASON_CHARTCLOSE:  return "chart closed";
      case REASON_PARAMETERS:  return "inputs changed";
      case REASON_ACCOUNT:     return "account changed/reconnected";
      case REASON_TEMPLATE:    return "template applied";
      case REASON_INITFAILED:  return "OnInit failed";
      case REASON_CLOSE:       return "terminal closed";
   }
   return "unknown";
}

void OnDeinit(const int reason)
{
   // v75.0 (P0): دلیل حذف/ری‌استارت EA در لاگ (برای پیدا کردن علت ری‌استارت‌های ناشناخته‌ی 11:35 و 13:49)
   Print("[RM-DEINIT] reason=", reason, " (", GetDeinitReasonText(reason), ") chart=", _Symbol, ",", EnumToString((ENUM_TIMEFRAMES)_Period));
   RM_GVFlushIfDirty();
   GlobalVariablesFlush();
   EventKillTimer();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0);
   ObjectsDeleteAll(0, P);
   ObjectDelete(0,LN_CUR); ObjectDelete(0,LN_ENT);
   ObjectDelete(0,LN_SL);  ObjectDelete(0,LN_TP);
   ObjectDelete(0,LN_CUR+"_LBL"); ObjectDelete(0,LN_SL+"_LBL"); ObjectDelete(0,LN_TP+"_LBL");
   RemoveCandleTimerChart();   // [Stage 5c-ii, RM_Tools.mqh stub]
   RemoveDailyHL();            // [Stage 5c-ii, RM_Tools.mqh stub]
   RemoveWeeklyHL();           // [Stage 5c-ii, RM_Tools.mqh stub]
   RemoveMonthlyHL();          // [Stage 5c-ii, RM_Tools.mqh stub]
   RemoveBERefLines();         // [Stage 5c-ii, RM_Tools.mqh stub]
   RemoveSessionWindows();     // [Stage 5c-ii, RM_Tools.mqh stub]
   SessionLevel_RemoveWindows();  // [Stage 5c-ii, RM_Tools.mqh stub]
   History_Remove();              // v75.11
   RemoveEntryExitMarkers();      // [Stage 5c-ii, RM_Tools.mqh stub]
   ObjectsDeleteAll(0, TAG_WIN_PREFIX);
   ObjectsDeleteAll(0, SCL_WIN_PREFIX);   // v75.13: پنجره‌ی انتخاب زنجیره‌ی Scale-in
   ObjectsDeleteAll(0, HALFSEL_WIN_PREFIX);  // real prefix, defined in RM_TradeExecution.mq5 (Stage 3)
   ChartRedraw();
}

// v74.6 (HF6): مدت آخرین OnTick (بدنه‌ی خود EA) برای تشخیص منبع توقف‌های OnTimer
uint g_rmPerfLastTickMs = 0;

// v26.1 (FEAT-018 fix): OnTimer با EventSetTimer(1) دقیقاً هر ۱ ثانیه (مستقل از ورود تیک) فایر می‌شه.
void OnTimer()
{
   // v26.12 (FEAT-018 diagnostic - TEMPORARY, remove before final sign-off): هنوز توی سورس v70 حذف
   // نشده بود - طبق Golden Rule دست‌نخورده پورت شد، نه چیزی که من اضافه کرده باشم.
   // v74.1 (HF1 A1): the per-second "OnTimer interval" Print is gone; one line only when the timer
   // stalls (> 2000 ms) - the measurement tool for the M1 freeze test.
   static uint lastTimerMs = 0;
   static uint prevBodyMs  = 0;   // v74.6 (HF6): مدت بدنه‌ی OnTimer قبلی - می‌گه توقف داخل خود EA بوده یا بیرونش
   uint nowMs = GetTickCount();
   if(lastTimerMs != 0 && (nowMs - lastTimerMs) > 2000)
      Print("[RM-PERF] OnTimer stall ", nowMs - lastTimerMs, " ms chart=", _Symbol, ",", EnumToString((ENUM_TIMEFRAMES)_Period),
            " prevBodyMs=", prevBodyMs, " lastTickMs=", g_rmPerfLastTickMs);   // v74.6 (HF6): دو فیلد اضافه
   lastTimerMs = nowMs;

   // v74.6 (HF6c): فقط اندازه‌گیری - هر ۴ فراخوانی همون ترتیب قبلی؛ اگه هرکدوم > 1000ms طول بکشه یک خط لاگ
   uint tm0 = GetTickCount();
   UpdateCandleTimerChart(true);  // [Stage 5c-ii, RM_Tools.mqh stub]
   uint tm1 = GetTickCount();
   CheckButtonFlashExpiry();      // real, Stage 5c-i
   uint tm2 = GetTickCount();
   CheckPanelIntegrity();         // real, Stage 5c-i
   uint tm3 = GetTickCount();
   SyncTagsIfChanged();           // v75.0 (P0، MT4 v101 RM_SyncTagsIfChanged): یک GlobalVariableGet؛ فایل فقط وقتی چارت دیگر تگ ذخیره کرده دوباره خوانده می‌شود
   ST_ServerOffsetSec();          // v75.0 (P0-1): کالیبراسیون سه‌تیکی آفست (MT5 مصرف‌کننده‌ی دوره‌ای مثل News در MT4 ندارد)
   CheckAutoCloseAtHour();        // v75.4 (FEAT-031): با EnableAutoCloseAtHour=false دقیقاً no-op
   RM_NewsTick();                 // v75.3 (MT4 v105): خبر USD؛ throttle ۲۰ث، فقط وقتی KEY TIME روشن است، دانلود ساعتی با WebRequest
   RM_GVFlushIfDirty();           // v74.6 (HF6b): فقط اگه MaxFav/MinFav عوض شده و ≥15s از flush قبلی گذشته
   CancelOrphanContinuationPendings();   // v75.13 (MT4 v90.1): روی نمادهای کم‌تیک هم
   ScaleInPickerRefresh();               // v75.13 (MT4 v90): throttle داخلی
   uint tm4 = GetTickCount();
   if((tm4 - tm0) > 1000)
      Print("[RM-PERF] OnTimer body slow ", tm4 - tm0, " ms: candleTimer=", tm1 - tm0, " flash=", tm2 - tm1,
            " panelIntegrity=", tm3 - tm2, " gvFlush=", tm4 - tm3, " chart=", _Symbol, ",", EnumToString((ENUM_TIMEFRAMES)_Period));   // v74.6 (HF6c)
   prevBodyMs = GetTickCount() - nowMs;   // v74.6 (HF6)
}

// v74.6 (HF6d): فقط اندازه‌گیری - زمان هر فراخوانی نمایش/ابزار جدا ثبت می‌شه؛ خود فراخوانی‌ها و ترتیب‌شون دست‌نخورده
#define RM_TM(i, call) { uint _tq = GetTickCount(); call; tkv[i] = GetTickCount() - _tq; }
void OnTick()
{
   uint tkv[16]; ArrayInitialize(tkv, 0);
   uint pf0 = GetTickCount();   // v74.6 (HF6): فقط اندازه‌گیری، هیچ کار جدیدی انجام نمی‌ده
   RM_CfgSyncIfChanged();    // v75.15: one GlobalVariableGet per tick
   CheckFloatingDrawdown();  // real, Stage 4
   CheckAutoCloseAtHour();   // v75.4 (FEAT-031): no-op وقتی خاموش است

   datetime today = RM_DayStartSrv();   // v74.3 (HF2, A3): server time
   if(today != g_dayStart)
   {
      // v74.3 (HF2, A3/D2): the FIRST chart to see the new day registers it (start balance published to the shared
      // GVs) and does the once-per-day work (prior-day result, counter reset). Other charts adopt the registered
      // balance and prior-day result and do NOT touch the shared counters again (a stop in the first seconds of
      // the day used to be wiped by a slower chart's reset).
      double newDayBal = g_dayStartBalance;
      bool dayWinner = RM_PeriodStartBalance(GV_DAY_START, GV_DAY_START_BAL, today, newDayBal);
      if(dayWinner)
         ComputePriorDayResult();  // real, Stage 4 (uses this chart's OLD g_dayStart/g_dayStartBalance)
      else if(GlobalVariableCheck(GV_PRIOR_DAY_RESULT))
         g_priorDayResultCode = GlobalVariableGet(GV_PRIOR_DAY_RESULT);
      g_dayStart = today;
      g_dayStartBalance = newDayBal;
      RefreshSharedLockEnds();   // v74.3 (HF2): never write a stale lock end back to the shared GVs
      if(dayWinner)
      {
         g_mktStopCount = CAS_SetGlobal(GV_MKT_COUNT, 0.0);
         g_behCount     = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
         g_lastStopCloseTime = (datetime)CAS_SetGlobal(GV_LAST_STOP_CLOSE, 0.0);
      }
      SaveCooldownState();
      SaveDrawdownState();
      if(g_swOn) BuildSessionWindows();             // [Stage 5c-ii, RM_Tools.mqh stub]
      if(g_sessLvlOn) SessionLevel_BuildWindows();   // [Stage 5c-ii, RM_Tools.mqh stub]
      if(g_histOn) History_Build();                  // v75.11: پنجره‌ی N روز با عوض‌شدن روز جابه‌جا می‌شود
      RefreshChainRootKeys();                        // v75.13 (MT4 v87): جلوگیری از انقضای ۴هفته‌ای GlobalVariable کلید ریشه‌ی زنجیره‌ها
   }

   datetime thisWeek = RM_WeekStartSrv();   // v74.3 (HF2, A3)
   if(thisWeek != g_weekStart) { double nb = g_weekStartBalance; RM_PeriodStartBalance(GV_WEEK_START, GV_WEEK_START_BAL, thisWeek, nb); g_weekStartBalance = nb; g_weekStart = thisWeek; RefreshSharedLockEnds(); SaveDrawdownState(); }

   datetime thisMonth = RM_MonthStartSrv();   // v74.3 (HF2, A3)
   if(thisMonth != g_monthStart) { double nb2 = g_monthStartBalance; RM_PeriodStartBalance(GV_MONTH_START, GV_MONTH_START_BAL, thisMonth, nb2); g_monthStartBalance = nb2; g_monthStart = thisMonth; RefreshSharedLockEnds(); SaveDrawdownState(); }

   CheckMarketCDTimeReset();  // real, Stage 4

   if(AutoBE) CheckAutoBE();  // real, Stage 4 (self-gated here, matching the original main .mq4's OnTick - see the Stage 5b harness note about CheckAutoBE() not self-gating)
   CheckClosedTrades();       // real, Stage 4
   EnsureTrailingReset();     // real, Stage 4
   CheckPendingActivation();  // real, Stage 4
   CancelOrphanContinuationPendings();   // v75.13 (MT4 v90.1 FEAT-044)
   ScaleInPickerRefresh();               // v75.13 (MT4 v90): تازه‌سازی فهرست انتخابگر / اعتبار زنجیره‌ی انتخاب‌شده (throttle ۱ثانیه‌ای داخل خود تابع)
   uint pf1 = GetTickCount();   // v74.6 (HF6)

   CheckSLTampering();        // real, Stage 3 (Snapshot-backed since Stage 5a)

   CheckAutoTrailingTrigger();               // real, Stage 4
   if(g_trailingButtonOn) SyncManualTrailing(); // real, Stage 4
   RunTrailingUpdate();                      // real, Stage 4

   CheckAutoHalfCloseTrigger();  // real, Stage 4
   UpdateAutoTriggerPreviewLines();  // real, Stage 4

   RM_TM(0, CheckDrawdownLimits());     // real, Stage 4
   RM_TM(1, UpdateCooldownDisplay());   // real, Stage 5c-i
   RM_TM(2, UpdateSystemStatus());      // real, Stage 5c-i
   RM_TM(3, UpdateUntaggedReminder());  // real, Stage 5c-i (CountUntaggedToday() itself is a Stage 5d stub)
   RM_TM(4, UpdateFloatingDisplay());   // real, Stage 5c-i
   RM_TM(5, UpdateRiskDisplay());       // real, Stage 5c-i
   RM_TM(6, UpdatePLDisplay());         // real, Stage 5c-i
   RM_TM(7, UpdateReportsDisplay());    // real, Stage 5c-i (uses Stage 5b's real CalcTradingReportStats())
   uint pf2 = GetTickCount();   // v74.6 (HF6)
   RM_TM(8, UpdateCandleTimerChart());  // [Stage 5c-ii, RM_Tools.mqh stub]
   RM_TM(9, UpdateDailyHL());           // [Stage 5c-ii, RM_Tools.mqh stub]
   RM_TM(10, UpdateWeeklyHL());          // [Stage 5c-ii, RM_Tools.mqh stub]
   RM_TM(11, UpdateMonthlyHL());         // [Stage 5c-ii, RM_Tools.mqh stub]
   RM_TM(12, UpdateBERefLine());         // [Stage 5c-ii, RM_Tools.mqh stub]
   RM_TM(13, UpdateSessionWindowsVertical());  // [Stage 5c-ii, RM_Tools.mqh stub]
   RM_TM(14, SessionLevel_UpdateVertical());   // [Stage 5c-ii, RM_Tools.mqh stub]
   RM_TM(15, RefreshEntryExitMarkers());       // [Stage 5c-ii, RM_Tools.mqh stub]
   History_Refresh();                          // v75.11: HISTORY روشن و معامله‌ی تازه باز/بسته شده -> بازسازی
   // v74.6 (HF6): اگه کل OnTick بیش از ۲ ثانیه طول کشید، یک خط لاگ (trade = منطق معامله/بسته‌شدن/export،
   // dash = نمایش‌های پنل، tools = ابزارهای چارت)
   uint pf3 = GetTickCount();
   g_rmPerfLastTickMs = pf3 - pf0;
   if(g_rmPerfLastTickMs > 2000)
      Print("[RM-PERF] OnTick slow ", g_rmPerfLastTickMs, " ms (trade=", pf1-pf0, " dash=", pf2-pf1, " tools=", pf3-pf2, ") chart=", _Symbol, ",", EnumToString((ENUM_TIMEFRAMES)_Period));
   if(g_rmPerfLastTickMs > 2000)   // v74.6 (HF6d): ریز زمان هر فراخوانی
   {
      string brk = "";
      for(int bi=0; bi<16; bi++) brk += IntegerToString((int)tkv[bi]) + (bi<15 ? "," : "");
      Print("[RM-PERF] OnTick breakdown ms: ddLimits,cooldown,status,untagged,floating,risk,pl,reports,candleTimer,dailyHL,weeklyHL,monthlyHL,beLine,sessVert,sessLvlVert,markers = ", brk);
   }
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
{
   int mx=(int)lp, my=(int)dp;

   // rebuild panel on window resize or chart change - rate-limited to max once/second
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      datetime now = TimeLocal();
      if(now == g_panelLastRebuild) return;
      g_panelLastRebuild = now;
      ObjectsDeleteAll(0, P);
      BuildPanel();
      UpdateRiskDisplay();
      UpdatePLDisplay();
      UpdateReportsDisplay();
      UpdateCooldownDisplay();
      UpdateSystemStatus();
      // v75.1 (MT4 v78/v95): Key Time/Session Level با زوم/اسکرول/تغییر اندازه هم‌گام می‌شوند (cull چپ + موقعیت عمودی)؛
      // throttle ۱ ثانیه‌ای بالا از فلش‌زدن جلوگیری می‌کند.
      if(g_swOn)      BuildSessionWindows();
      if(g_sessLvlOn) SessionLevel_BuildWindows();
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE && g_step != STEP_IDLE && !IsOnPanel(mx,my))
   {
      datetime dt; double price; int win;
      if(ChartXYToTimePrice(0,mx,my,win,dt,price))
      {
         price = NormalizeDouble(price,_Digits);
         HLine(LN_CUR, price, C'130,130,130', 1, STYLE_DOT);
         if(g_step==STEP_SL)
         {
            double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
            double entryRef = (g_entryPrice>0) ? g_entryPrice : (ask+bid)/2.0;
            bool pb  = (price < entryRef);
            double d = MathAbs(entryRef-price);
            double preTP = NormalizeDouble(pb?entryRef+d*g_riskReward:entryRef-d*g_riskReward,_Digits);
            HLine(LN_TP, preTP, C'0,150,0', 1, STYLE_DOT);

            double slPipsCalc = d/(_Point*PipFactor());
            double pipVal = GetPipValueForSymbol(_Symbol, _Point, PipFactor());
            double tpPipsCalc = MathAbs(preTP-entryRef)/(_Point*PipFactor());
            double lot=0, lossAmt=0, profitAmt=0;
            double previewRisk = GetEntryRiskPct();   // v75.13: Scale-in -> سقف زنجیره
            if(slPipsCalc>0)
            {
               lot = CalcLot(slPipsCalc, previewRisk, false);
               lossAmt   = NormalizeDouble(lot*slPipsCalc*pipVal,2);
               profitAmt = NormalizeDouble(lot*tpPipsCalc*pipVal,2);
            }

            if(ObjectFind(0,LN_CUR+"_LBL")<0) ObjectCreate(0,LN_CUR+"_LBL",OBJ_TEXT,0,0,0);
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_TIME,TimeCurrent());
            ObjectSetDouble (0,LN_CUR+"_LBL",OBJPROP_PRICE,price);
            ObjectSetString (0,LN_CUR+"_LBL",OBJPROP_TEXT,"Stop Loss  -$"+DoubleToString(lossAmt,2)+"  (Lot "+DoubleToString(lot,2)+")");
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_COLOR,GetPreviewLabelColor());
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_FONTSIZE,9);
            ObjectSetString (0,LN_CUR+"_LBL",OBJPROP_FONT,"Arial Bold");
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_ANCHOR,ANCHOR_LOWER);
            ObjectSetInteger(0,LN_CUR+"_LBL",OBJPROP_SELECTABLE,false);

            if(ObjectFind(0,LN_TP+"_LBL")<0) ObjectCreate(0,LN_TP+"_LBL",OBJ_TEXT,0,0,0);
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_TIME,TimeCurrent());
            ObjectSetDouble (0,LN_TP+"_LBL",OBJPROP_PRICE,preTP);
            ObjectSetString (0,LN_TP+"_LBL",OBJPROP_TEXT,"Target  +$"+DoubleToString(profitAmt,2));
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_COLOR,GetPreviewLabelColor());
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_FONTSIZE,9);
            ObjectSetString (0,LN_TP+"_LBL",OBJPROP_FONT,"Arial Bold");
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_ANCHOR,ANCHOR_LOWER);
            ObjectSetInteger(0,LN_TP+"_LBL",OBJPROP_SELECTABLE,false);

            string ordTypeTxt; color ordTypeClr = pb?clrDodgerBlue:clrRed;
            if(g_mode==MODE_MARKET)
            {
               ordTypeTxt = pb?"BUY":"SELL";
            }
            else
            {
               double midRef=(ask+bid)/2.0;
               if(pb && g_entryPrice<midRef)       ordTypeTxt="BUY LIMIT";
               else if(pb && g_entryPrice>midRef)   ordTypeTxt="BUY STOP";
               else if(!pb && g_entryPrice>midRef)  ordTypeTxt="SELL LIMIT";
               else if(!pb && g_entryPrice<midRef)  ordTypeTxt="SELL STOP";
               else                                 ordTypeTxt=pb?"BUY":"SELL";
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

   // v42/v42-follow-up: Fibo tool live cursor tag + rubber-band preview (armed, before 1st click)
   if(id == CHARTEVENT_MOUSE_MOVE && (g_fiboArmedRR || g_fiboArmedMeasure) && !g_fiboWaitingP2 && !IsOnPanel(mx,my))
   {
      string tagTxt1 = (g_fiboArmedRR ? "R/R: click start point" : "Measure Move: click start point");
      color  tagClr1 = g_fiboArmedRR ? GetFiboRRColor() : GetFiboMeasureColor();
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

   // (armed, after 1st click - waiting for 2nd point) - live rubber-band preview
   if(id == CHARTEVENT_MOUSE_MOVE && (g_fiboArmedRR || g_fiboArmedMeasure) && g_fiboWaitingP2 && !IsOnPanel(mx,my))
   {
      datetime dt; double price; int win;
      if(ChartXYToTimePrice(0,mx,my,win,dt,price))
      {
         price = NormalizeDouble(price,_Digits);
         if(g_fiboArmedRR)
            CreateFiboRMultiple(FIBO_RMULT_PREVIEW, g_fiboP1Time, g_fiboP1Price, dt, price, true);  // [Stage 5c-ii, RM_Tools.mqh stub]
         else
            CreateFiboMeasureMove(FIBO_MEASURE_PREVIEW, g_fiboP1Time, g_fiboP1Price, dt, price, true);  // [Stage 5c-ii, RM_Tools.mqh stub]
      }
      string tagTxt2 = (g_fiboArmedRR ? "R/R: click end point" : "Measure Move: click end point");
      color  tagClr2 = g_fiboArmedRR ? GetFiboRRColor() : GetFiboMeasureColor();
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

   if(id == CHARTEVENT_CLICK && g_fullCloseMenuOpen && !IsOnPanel(mx,my))
   {
      CloseFullCloseMenu();  // real, Stage 3
      ChartRedraw();
      return;
   }

   if(id == CHARTEVENT_CLICK && g_halfCloseMenuOpen && !IsOnPanel(mx,my))
   {
      CloseHalfCloseMenu();  // real, Stage 3
      ChartRedraw();
      return;
   }

   if(id == CHARTEVENT_CLICK && g_step != STEP_IDLE && !IsOnPanel(mx,my))
   {
      datetime dt; double price; int win;
      if(ChartXYToTimePrice(0,mx,my,win,dt,price))
         ProcessClick(NormalizeDouble(price,_Digits));  // real, Stage 3
      return;
   }

   // Fibo tool click capture (base point, then target point)
   if(id == CHARTEVENT_CLICK && (g_fiboArmedRR || g_fiboArmedMeasure) && !IsOnPanel(mx,my))
   {
      datetime dt; double price; int win;
      if(ChartXYToTimePrice(0,mx,my,win,dt,price))
      {
         price = NormalizeDouble(price,_Digits);
         if(!g_fiboWaitingP2)
         {
            g_fiboP1Time  = dt;
            g_fiboP1Price = price;
            g_fiboWaitingP2 = true;
            g_fiboArmDeadline = GetTickCount() + FIBO_ARM_MS;
            SetStatus(g_fiboArmedRR ? "R/R: click target point on chart" : "Measure Move: click target point on chart",
                      g_fiboArmedRR ? GetFiboRRColor() : GetFiboMeasureColor());
         }
         else
         {
            g_fiboInstanceSeq++;
            if(g_fiboArmedRR)
            {
               ObjectDelete(0, FIBO_RMULT_PREVIEW);
               CreateFiboRMultiple(FIBO_RMULT_OBJ+"_"+IntegerToString(g_fiboInstanceSeq), g_fiboP1Time, g_fiboP1Price, dt, price);  // [Stage 5c-ii, RM_Tools.mqh stub]
            }
            else
            {
               ObjectDelete(0, FIBO_MEASURE_PREVIEW);
               CreateFiboMeasureMove(FIBO_MEASURE_OBJ+"_"+IntegerToString(g_fiboInstanceSeq), g_fiboP1Time, g_fiboP1Price, dt, price);  // [Stage 5c-ii, RM_Tools.mqh stub]
            }
            CancelFiboArm();  // [Stage 5c-ii, RM_Tools.mqh stub]
         }
         ChartRedraw();
      }
      return;
   }

   // v75.13 (MT4 v90 FEAT-044): کلیک‌های پنجره‌ی انتخاب زنجیره‌ی Scale-in (پیشوند جدا SCL_WIN_PREFIX) - self-contained، بعد از هر شاخه return.
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

   // Trade Tag window - self-contained, independent prefix (TAG_WIN_PREFIX)
   if(id == CHARTEVENT_OBJECT_CLICK && g_tagWindowOpen && StringFind(sp, TAG_WIN_PREFIX) == 0)
   {
      g_tagLastObjClickMs = GetTickCount(); // v74.1 (HF1 B5): the CHARTEVENT_CLICK that follows must not be judged against the rebuilt window
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);

      if(sp == TAG_WIN_PREFIX+"CLOSE")
      {
         CloseTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
         return;
      }
      if(sp == TAG_WIN_PREFIX+"BACK")
      {
         if(g_tagStep>0) g_tagStep--;
         BuildTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
         return;
      }
      if(g_tagStep==0 && StringFind(sp, TAG_WIN_PREFIX+"TRADE_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"TRADE_")));
         if(idx>=0 && idx<ArraySize(g_tagTodayTickets))
         {
            g_tagSelectedTicket = g_tagTodayTickets[idx];
            g_tagSelectedMentalState = GetTagMentalStateRaw(g_tagSelectedTicket);  // real, Stage 5b stub -> Stage 5d real
            // v75.14 (FEAT-037): چک‌لیست کانتکست ذخیره‌شده‌ی این ترید (یا ریشه‌ی زنجیره) از قبل در سشن ست می‌شود
            g_ctxSelLevel  = GetCtxLevelBool(g_tagSelectedTicket);
            g_ctxSelCycle  = GetCtxCycleBool(g_tagSelectedTicket);
            g_ctxSelTime   = GetCtxTimeBool(g_tagSelectedTicket);
            g_ctxSelCandle = GetCtxCandleBool(g_tagSelectedTicket);
            g_ctxSelNone   = GetCtxNoneBool(g_tagSelectedTicket);
            g_tagStep = 1;   // استپ بعدی چک‌لیست کانتکست است (نه Strategy)
            BuildTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
         }
         return;
      }
      // v75.14 (FEAT-037): "CTX_NEXT" باید قبل از چک عمومی پیشوند "CTX_" بیاید (وگرنه StringToInteger("NEXT")=0 گزینه‌ی اول را toggle می‌کند).
      if(g_tagStep==1 && sp == TAG_WIN_PREFIX+"CTX_NEXT")
      {
         g_tagStep = 2;
         BuildTagWindow();
         return;
      }
      if(g_tagStep==1 && StringFind(sp, TAG_WIN_PREFIX+"CTX_")==0)
      {
         int cidx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"CTX_")));
         if(cidx>=0 && cidx<5)
         {
            if(cidx==0)      g_ctxSelLevel  = !g_ctxSelLevel;
            else if(cidx==1) g_ctxSelCycle  = !g_ctxSelCycle;
            else if(cidx==2) g_ctxSelTime   = !g_ctxSelTime;
            else if(cidx==3) g_ctxSelCandle = !g_ctxSelCandle;
            else if(cidx==4) g_ctxSelNone   = !g_ctxSelNone;
            // هر toggle بلافاصله ذخیره می‌شود (بستن پنجره بدون NEXT انتخاب‌ها را از بین نبرد)
            SetContextTag(g_tagSelectedTicket, g_ctxSelLevel, g_ctxSelCycle, g_ctxSelTime, g_ctxSelCandle, g_ctxSelNone);
            BuildTagWindow();
         }
         return;
      }
      if(g_tagStep==2 && StringFind(sp, TAG_WIN_PREFIX+"STRAT_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"STRAT_")));
         if(idx>=0 && idx<g_stratCount)
         {
            g_tagSelectedStrategy = g_stratNames[idx];
            g_tagStep = 3;
            BuildTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
         }
         return;
      }
      if(g_tagStep==3 && sp == TAG_WIN_PREFIX+"MENTAL_CLEAR")
      {
         g_tagSelectedMentalState = "";
         // [Stage 5d fix, found live during Mahmoud's Stage 5d testing] Mental State wasn't
         // persisted when picked/cleared AFTER Setup was already tagged (window stays open past
         // Setup per v70's Change 2, so this is a real, reachable sequence) - only local selection
         // state updated, SetTradeTag() was never re-called. If this ticket already has a real
         // Setup tag, re-save immediately so a later-changed Mental State isn't silently lost.
         if(GetTagSetup(g_tagSelectedTicket)!="N/A")
            SetTradeTag(g_tagSelectedTicket, g_tagSelectedStrategy, GetTagSetup(g_tagSelectedTicket), g_tagSelectedMentalState);
         BuildTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
         return;
      }
      if(g_tagStep==3 && StringFind(sp, TAG_WIN_PREFIX+"MENTAL_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"MENTAL_")));
         string mentalOpts[];
         int mc = GetMentalStateOptions(mentalOpts);  // [Stage 5c-ii, RM_Tools.mqh stub]
         if(idx>=0 && idx<mc)
         {
            g_tagSelectedMentalState = (g_tagSelectedMentalState==mentalOpts[idx]) ? "" : mentalOpts[idx];
            // [Stage 5d fix] same reasoning as MENTAL_CLEAR above.
            if(GetTagSetup(g_tagSelectedTicket)!="N/A")
               SetTradeTag(g_tagSelectedTicket, g_tagSelectedStrategy, GetTagSetup(g_tagSelectedTicket), g_tagSelectedMentalState);
            BuildTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
         }
         return;
      }
      if(g_tagStep==3 && StringFind(sp, TAG_WIN_PREFIX+"SETUP_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(TAG_WIN_PREFIX+"SETUP_")));
         string setups[];
         int sc = GetSetupsForStrategy(g_tagSelectedStrategy, setups);  // [Stage 5c-ii, RM_Tools.mqh stub]
         if(idx>=0 && idx<sc)
         {
            SetTradeTag(g_tagSelectedTicket, g_tagSelectedStrategy, setups[idx], g_tagSelectedMentalState);  // real, Stage 5b stub -> Stage 5d real
            SetStatus("Tagged #"+IntegerToString(g_tagSelectedTicket), clrLightGreen);
            BuildTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
         }
         return;
      }
      return;
   }

   // v74.1 (HF1 B5): ignore the CHARTEVENT_CLICK that MT5 sends for the same click, <=400 ms after a tag-window object click
   if(id == CHARTEVENT_CLICK && g_tagWindowOpen && g_tagLastObjClickMs != 0 && (int)(GetTickCount() - g_tagLastObjClickMs) <= 400)
      return;

   if(id == CHARTEVENT_CLICK && g_tagWindowOpen && !IsOnPanel(mx,my) && !IsOnTagWindow(mx,my))
   {
      CloseTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
      ChartRedraw();
      return;
   }

   // Half-Close ticket-select window - self-contained, independent prefix (HALFSEL_WIN_PREFIX, real, Stage 3)
   if(id == CHARTEVENT_OBJECT_CLICK && g_halfSelWindowOpen && StringFind(sp, HALFSEL_WIN_PREFIX) == 0)
   {
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);

      if(sp == HALFSEL_WIN_PREFIX+"CLOSE")
      {
         CloseHalfSelectWindow();  // real, Stage 3
         return;
      }
      if(StringFind(sp, HALFSEL_WIN_PREFIX+"ROW_")==0)
      {
         int idx = (int)StringToInteger(StringSubstr(sp, StringLen(HALFSEL_WIN_PREFIX+"ROW_")));
         if(idx>=0 && idx<ArraySize(g_halfSelTickets))
         {
            ulong tkt = g_halfSelTickets[idx];
            CloseHalfSelectWindow();  // real, Stage 3
            if(HalfCloseTicket(tkt, 50.0, "Half Close"))  // real, Stage 3
            {
               SetStatus("Half Close #"+IntegerToString(tkt), clrYellow);
               StartButtonFlash(P+"BTN_HALF", CLR_FLASH_HALF, g_halfFlashEnd);  // real, Stage 5c-i
            }
            else
               SetStatus("Half Close #"+IntegerToString(tkt)+" failed", clrRed);
         }
         return;
      }
      return;
   }

   // Entry/Exit marker click - toggle ticket-number label
   if(id == CHARTEVENT_OBJECT_CLICK && g_markersOn &&
      (StringFind(sp, MARK_ENTRY_PREFIX) == 0 || StringFind(sp, MARK_EXIT_PREFIX) == 0))
   {
      ulong tktFromMarker;
      if(StringFind(sp, MARK_ENTRY_PREFIX) == 0)
         tktFromMarker = (ulong)StringToInteger(StringSubstr(sp, StringLen(MARK_ENTRY_PREFIX)));
      else
         tktFromMarker = (ulong)StringToInteger(StringSubstr(sp, StringLen(MARK_EXIT_PREFIX)));

      ToggleMarkTicketLabel(tktFromMarker);  // [Stage 5c-ii, RM_Tools.mqh stub]
      return;
   }

   // === main dashboard button dispatcher ===
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);

      if(g_fullCloseMenuOpen && sp!=P+"BTN_FULL" && sp!=P+"SUB_CLOSEALL" &&
         sp!=P+"SUB_CLOSECHART" && sp!=P+"SUB_CLOSEPROFIT" && sp!=P+"SUB_CLOSELOSS")
         CloseFullCloseMenu();  // real, Stage 3

      if(g_halfCloseMenuOpen && sp!=P+"BTN_HALF" && sp!=P+"SUB_HALFALL" &&
         sp!=P+"SUB_HALFCHART" && sp!=P+"SUB_HALFPROFIT" && sp!=P+"SUB_HALFSELECT")
         CloseHalfCloseMenu();  // real, Stage 3

      if(sp == P+"BTN_MIN")
      {
         g_minimized = !g_minimized;
         if(g_minimized && g_tagWindowOpen) CloseTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
         if(g_minimized && g_scaleInPickerOpen) CloseScaleInPicker();   // v75.13 (MT4 v90)
         ObjectsDeleteAll(0, P);
         BuildPanel();  // real, Stage 5c-i
         ChartRedraw();
         return;
      }

      if(sp == P+"BTN_DASH_TRADING" && (g_dashboardMode != DASH_TRADING || g_minimized))
      {
         g_dashboardMode = DASH_TRADING;
         g_minimized = false;
         SaveDashboardModeState();  // real, Stage 5c-i
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
         SaveDashboardModeState();  // real, Stage 5c-i
         ObjectsDeleteAll(0, P);
         BuildPanel();
         SetStatus("Dashboard: Utility", clrLimeGreen);
         ChartRedraw();
         return;
      }

      // v75.17 (MT4 v110 P2): Reports tab
      if(sp == P+"BTN_DASH_REPORTS" && (g_dashboardMode != DASH_REPORTS || g_minimized))
      {
         g_dashboardMode = DASH_REPORTS;
         g_minimized = false;
         SaveDashboardModeState();
         ObjectsDeleteAll(0, P);
         BuildPanel();
         SetStatus("Dashboard: Reports", clrLimeGreen);
         ChartRedraw();
         return;
      }

      // v75.13 (MT4 v90): انتخابگر Scale-in باز بود و تریدر مستقیم MARKET/PENDING زد -> انتخابگر بسته و Scale-in خاموش (ورود عادی)
      if((sp==P+"BTN_MARKET" || sp==P+"BTN_PENDING") && g_scaleInPickerOpen)
      { CloseScaleInPicker(); UpdateScaleInButton(); }
      if(sp==P+"BTN_SCALEIN") ScaleInButtonClick();   // v75.13 (MT4 v90)
      if(sp==P+"BTN_MARKET")
      {
         if(!IsTradingAllowed()) return;  // real, Stage 4
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
      if(sp==P+"BTN_BE")      ManualBE();  // real, Stage 3
      if(sp==P+"BTN_HALF")
      {
         if(g_halfCloseMenuOpen) CloseHalfCloseMenu();  // real, Stage 3
         else                    OpenHalfCloseMenu();   // real, Stage 3
      }
      if(sp==P+"SUB_HALFALL")      { CloseHalfCloseMenu(); HalfClose(false); }
      if(sp==P+"SUB_HALFCHART")    { CloseHalfCloseMenu(); HalfClose(false, true); }   // v75.18
      if(sp==P+"SUB_HALFPROFIT")   { CloseHalfCloseMenu(); HalfClose(true); }
      if(sp==P+"SUB_HALFSELECT")   { CloseHalfCloseMenu(); OpenHalfSelectWindow(); }  // real, Stage 3

      if(sp==P+"BTN_FULL")
      {
         if(g_fullCloseMenuOpen) CloseFullCloseMenu();  // real, Stage 3
         else                    OpenFullCloseMenu();   // real, Stage 3
      }
      if(sp==P+"SUB_CLOSEALL")     { CloseFullCloseMenu(); FullClose(); }
      if(sp==P+"SUB_CLOSECHART")   { CloseFullCloseMenu(); CloseChartPositions(); }
      if(sp==P+"SUB_CLOSEPROFIT")  { CloseFullCloseMenu(); CloseProfitablePositions(); }
      if(sp==P+"SUB_CLOSELOSS")    { CloseFullCloseMenu(); CloseLosingPositions(); }
      if(sp==P+"BTN_TRAIL")
      {
         g_trailingButtonOn = !g_trailingButtonOn;
         if(g_trailingButtonOn)
         {
            SyncManualTrailing();  // real, Stage 4
            SetStatus("Trailing: ON", C'0,180,180');
         }
         else
         {
            g_trailCount = 0;
            ArrayResize(g_trailTickets, 0);
            ArrayResize(g_trailExtreme, 0);
            ArrayResize(g_trailPeriod,  0);
            ArrayResize(g_trailLastBar, 0);
            SetStatus("Trailing: OFF", C'150,150,150');
         }
         UpdateTrailButton();  // real, Stage 5c-i
      }
      if(sp==P+"BTN_RR")
      {
         CycleRR();          // [Stage 5c-ii, small self-contained - see judgment call in report]
         UpdateRRButton();   // real, Stage 5c-i
         SetStatus("RR set to "+RRRatioText(), C'255,200,80');
      }
      if(sp==P+"BTN_RISKTOGGLE")
      {
         CycleRiskStep();   // v75.10 (FEAT-038)
         UpdateHalfRiskButton();
         SetStatus(RiskStepName(g_riskStep)+" Risk selected", (g_riskStep==0) ? C'170,30,30' : C'220,90,90');
      }

      // v75.17 (MT4 v110 P2): BTN_PERF / BTN_REPORTS are static headers now (no collapse) - handlers removed.

      if(sp == P+"BTN_REP_DAILY" && g_reportsPeriod != 0)
      {
         g_reportsPeriod = 0;
         UpdateReportsDisplay();  // real, Stage 5c-i
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

      // v75.0 (P0-5): بلوک کلیک BTN_CANDLETIMER حذف شد (تایمر کندل همیشه روشن).

      if(sp == P+"BTN_HLDAILY")
      {
         g_hlDailyOn = !g_hlDailyOn;
         if(!g_hlDailyOn) RemoveDailyHL(); else UpdateDailyHL();  // [Stage 5c-ii, RM_Tools.mqh stub]
         UpdateHLDailyButton();  // real, Stage 5c-i
         SetStatus(g_hlDailyOn ? "Daily High-Low: ON" : "Daily High-Low: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_HLWEEKLY")
      {
         g_hlWeeklyOn = !g_hlWeeklyOn;
         if(!g_hlWeeklyOn) RemoveWeeklyHL(); else UpdateWeeklyHL();  // [Stage 5c-ii, RM_Tools.mqh stub]
         UpdateHLWeeklyButton();  // real, Stage 5c-i
         SetStatus(g_hlWeeklyOn ? "Weekly High-Low: ON" : "Weekly High-Low: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_HLMONTHLY")
      {
         g_hlMonthlyOn = !g_hlMonthlyOn;
         if(!g_hlMonthlyOn) RemoveMonthlyHL(); else UpdateMonthlyHL();  // [Stage 5c-ii, RM_Tools.mqh stub]
         UpdateHLMonthlyButton();  // real, Stage 5c-i
         SetStatus(g_hlMonthlyOn ? "Monthly High-Low: ON" : "Monthly High-Low: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_HIDEOBJ")
      {
         ToggleHideObjects();  // [Stage 5c-ii, RM_Tools.mqh stub]
         UpdateHideObjButton();  // real, Stage 5c-i
      }
      if(sp == P+"BTN_BEREF")
      {
         g_beRefOn = !g_beRefOn;
         if(!g_beRefOn) RemoveBERefLines(); else UpdateBERefLine();  // [Stage 5c-ii, RM_Tools.mqh stub]
         UpdateBERefButton();  // real, Stage 5c-i
         SetStatus(g_beRefOn ? "BE Reference Line: ON" : "BE Reference Line: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_HISTORY")
      {
         g_histOn = !g_histOn;
         History_SaveState();
         History_Build();
         UpdateHistoryButton();
         SetStatus(g_histOn ? "History: ON (" + IntegerToString(g_histDrawn) + " trades, " + IntegerToString((int)MathMax(1, HistoryDaysBack)) + "d)" : "History: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_SW")
      {
         // v75.1 (MT4 v107 FEAT-061): چرخه OFF -> FULL -> COMPACT -> OFF
         if(!g_swOn)                               { g_swOn = true;  g_swMode = KEYTIME_MODE_FULL; }
         else if(g_swMode == KEYTIME_MODE_FULL)    { g_swMode = KEYTIME_MODE_COMPACT; }
         else                                      { g_swOn = false; g_swMode = KEYTIME_MODE_FULL; }
         SaveSessionWindowsState();
         BuildSessionWindows();      // ON: (re)builds; OFF: RemoveSessionWindows و برمی‌گردد
         UpdateSWButton();
         SetStatus(g_swOn ? (g_swMode == KEYTIME_MODE_COMPACT ? "Key Time: ON (COMPACT)" : "Key Time: ON (FULL)") : "Key Time: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_SESSLVL")
      {
         // v75.2 (MT4 v107 FEAT-063): چرخه OFF -> COMPACT -> EXPANDED -> OFF
         if(!g_sessLvlOn)                           { g_sessLvlOn = true;  g_slMode = SL_MODE_COMPACT; }
         else if(g_slMode == SL_MODE_COMPACT)       { g_slMode = SL_MODE_EXPANDED; }
         else                                       { g_sessLvlOn = false; g_slMode = SL_MODE_COMPACT; }
         SessionLevel_SaveState();
         SessionLevel_BuildWindows();
         UpdateSessLvlButton();
         SetStatus(g_sessLvlOn ? (g_slMode == SL_MODE_EXPANDED ? "Session Level: ON (EXPANDED)" : "Session Level: ON (COMPACT)") : "Session Level: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_MARKERS")
      {
         g_markersOn = !g_markersOn;
         if(g_rmPerfLog) Print("[DEBUG-MARKERS] BTN_MARKERS clicked, g_markersOn now=", g_markersOn);
         SaveEntryExitMarkersState();  // [Stage 5c-ii, RM_Tools.mqh stub]
         BuildEntryExitMarkers();      // [Stage 5c-ii, RM_Tools.mqh stub]
         UpdateMarkersButton();  // real, Stage 5c-i
         SetStatus(g_markersOn ? "Entry/Exit Markers: ON" : "Entry/Exit Markers: OFF", C'150,160,180');
      }
      if(sp == P+"BTN_FIBRMULT")
      {
         if(g_fiboArmedRR) { CancelFiboArm(); SetStatus("Cancelled", clrOrange); }  // [Stage 5c-ii, RM_Tools.mqh stub]
         else ArmFiboTool(1);  // [Stage 5c-ii, RM_Tools.mqh stub]
      }
      if(sp == P+"BTN_FIBMEASURE")
      {
         if(g_fiboArmedMeasure) { CancelFiboArm(); SetStatus("Cancelled", clrOrange); }  // [Stage 5c-ii, RM_Tools.mqh stub]
         else ArmFiboTool(2);  // [Stage 5c-ii, RM_Tools.mqh stub]
      }

      if(sp == P+"BTN_EXPORTCSV")
      {
         string exportedFile = "";
         if(ExportTradeJournalCSV(exportedFile))  // real, Stage 5b
         {
            Print("RM: CSV Trade Journal exported -> ", exportedFile);
            SetStatus("CSV Exported", clrLightGreen);
         }
         else
            SetStatus("CSV Export Failed", clrRed);
         StartButtonFlash(P+"BTN_EXPORTCSV", CLR_TOOLS_ACTIVE, g_exportFlashEnd);  // real, Stage 5c-i
      }

      if(sp == P+"BTN_TAGTRADES")
      {
         if(g_tagWindowOpen) CloseTagWindow();  // [Stage 5c-ii, RM_Tools.mqh stub]
         else                OpenTagWindow();   // [Stage 5c-ii, RM_Tools.mqh stub]
      }

      // Risk Lab / Journal / AI Coach - silent placeholders, no action on click (matches original)
      ChartRedraw();
   }
}
