//+------------------------------------------------------------------+
//| RM_Snapshot.mq5                                                    |
//| Risk Manager EA - Trade Snapshot (MT5 Port, Stage 5a)               |
//| پورت مستقیم از RM_Snapshot.mqh (RiskManager EA v70, MQL4). Golden    |
//| Rule: فرمول‌ها/آستانه‌ها/ترتیب عملیات عوض نشدن - این فایل تقریباً      |
//| کاملاً از آرایه‌های خام در حافظه و فراخوانی‌های GlobalVariable* تشکیل  |
//| شده که بین MQL4/MQL5 عیناً یکسانن (طبق ممیزی Stage 1) - تنها تغییر    |
//| واقعی، نوع تیکت (int → ulong) در سرتاسر فایله.                       |
//+------------------------------------------------------------------+

// === v11 (FEAT-016): Trade Snapshot - رکورد تغییرناپذیر هر معامله در لحظه‌ی باز شدن ===
// هیچ‌کدوم از این مقادیر بعد از ثبت اولیه عوض نمی‌شن (نه با جابه‌جایی دستی SL، نه BE، نه Trailing).
// فقط برای محاسبه‌ی R استفاده می‌شن؛ در GlobalVariable هم پایدار می‌شن تا بعد از ری‌استارت EA نمونن.
// [Stage 5a] int → ulong، همون دلیل هر جای دیگه‌ی این پورت (تیکت‌های MT5 64-بیتی). SnapKeyMagic و
// g_snapMagic دست‌نخورده می‌مونن (int) - طبق دستور صریح تسک، فقط تیکت‌ها تغییر نوع می‌دن، نه Magic.
ulong    g_snapTickets[];
double   g_snapEntry[];
double   g_snapSL[];
double   g_snapRiskUSD[];   // مبنای محاسبه‌ی R - چون % با تغییر بالانس دریفت می‌کنه
double   g_snapRiskPct[];   // فقط نمایشی
datetime g_snapOpenTime[];
int      g_snapMagic[];
// v18 (BUG-021): بالاترین سطح R واقعاً لمس‌شده از لحظه‌ی باز شدن معامله تا الان (per-ticket).
// برخلاف بقیه‌ی فیلدهای Snapshot، این یکی immutable نیست - هر تیک به‌روزرسانی می‌شه، فقط
// در جهت افزایش (هیچ‌وقت کم نمی‌شه). مبنای تشخیص "آیا این تیکت واقعاً به +1R رسیده یا نه"
// برای چک اقدام زودهنگام (Premature Action) - مستقل از سود لحظه‌ی بسته‌شدن.
double   g_snapMaxFavR[];
// v66 (آیتم ۲ب - MAE جدید): قرینه‌ی دقیق g_snapMaxFavR بالا - پایین‌ترین سطح R واقعاً لمس‌شده
// (بدترین حرکت نامطلوب، قبل از بسته‌شدن معامله) از لحظه‌ی باز شدن تا الان (per-ticket). فقط در
// جهت کاهش به‌روزرسانی می‌شه (هیچ‌وقت بالا نمی‌ره).
double   g_snapMinFavR[];
double   g_snapRiskWeight[];   // v75.10: -1 = not recorded
// v75.13 (MT4 v86/v90): ریشه‌ی زنجیره، پرچم «ورود ادامه (Scale-in)» و پایه‌ی R زنجیره (دلار).
// در MT5 (hedging) Half Close همان پوزیشن را کوچک می‌کند، پس ریشه فقط برای Scale-in معنی دارد: ورود ادامه = پوزیشن جدید با ریشه‌ی هدف.
ulong    g_snapRootTicket[];
bool     g_snapIsContinuation[];
double   g_snapRiskBaseUSD[];   // ۰ یا ثبت‌نشده -> SnapRiskBase() به RiskUSD خود پوزیشن فال‌بک می‌کند
// v18 (BUG-021 refinement): آیا این معامله (تیکت) از قبل یک Behavior Strike به‌خاطر
// اقدام زودهنگام گرفته؟ یک معامله فقط یک‌بار می‌تونه به این خاطر Strike بگیره.
bool     g_snapStriked[];
// v19 (BUG-022): آیا این معامله در لحظه‌ی باز شدنش با Half Risk فعال بوده؟
bool     g_snapWasHalfRisk[];
// v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله):
double   g_snapBehaviorErrorCountAtOpen[];
bool     g_snapOpenedDuringCooldownLock[];
bool     g_snapEntryIntervalViolation[];
bool     g_snapSLTampered[];
double   g_snapDailyRiskUsedPctAtOpen[];
double   g_snapWeeklyDDUsedPctAtOpen[];
// v64 (آیتم ۱ - PriorDayResult): کد عددی -2=N/A، -1=Loss، 0=Breakeven، 1=Win.
double   g_snapPriorDayResult[];
// v64 (آیتم ۳ - SLLoosenedCount):
int      g_snapSLLoosenedCount[];
// v64 (آیتم ۴ - BehaviorErrorsThisTrade): سنتینل -1 = هنوز محاسبه نشده.
double   g_snapBehaviorErrorsThisTrade[];
// v64 (آیتم ۶ - TimeframeAtOpen): سنتینل 0 = هنوز ثبت نشده.
double   g_snapTimeframeAtOpen[];
int      g_snapCount = 0;

//+------------------------------------------------------------------+
// v11 (FEAT-016): Trade Snapshot System
// شماره‌ی تیکت در کل حساب یکتاست (نه فقط در نماد جاری)، پس کلید GlobalVariable
// فقط بر اساس شماره‌ی تیکت ساخته می‌شه - نیازی به پسوند Symbol() نیست.
//+------------------------------------------------------------------+
string SnapKeyEntry(ulong ticket)    { return "RM_SNAP_ENTRY_"    + IntegerToString(ticket); }
string SnapKeySL(ulong ticket)       { return "RM_SNAP_SL_"       + IntegerToString(ticket); }
string SnapKeyRiskUSD(ulong ticket)  { return "RM_SNAP_RISKUSD_"  + IntegerToString(ticket); }
string SnapKeyRiskPct(ulong ticket)  { return "RM_SNAP_RISKPCT_"  + IntegerToString(ticket); }
string SnapKeyOpenTime(ulong ticket) { return "RM_SNAP_OPENTIME_" + IntegerToString(ticket); }
string SnapKeyMagic(ulong ticket)    { return "RM_SNAP_MAGIC_"    + IntegerToString(ticket); }
string SnapKeyMaxFavR(ulong ticket)  { return "RM_SNAP_MAXFAVR_"  + IntegerToString(ticket); } // v18 (BUG-021)
string SnapKeyMinFavR(ulong ticket)  { return "RM_SNAP_MINFAVR_"  + IntegerToString(ticket); } // v66 (آیتم ۲ب)
string SnapKeyStriked(ulong ticket)  { return "RM_SNAP_STRIKED_"  + IntegerToString(ticket); } // v18 (BUG-021 refinement)
string SnapKeyRiskWeight(ulong ticket) { return "RM_SNAP_RISKWEIGHT_" + IntegerToString(ticket); }
string SnapKeyWasHalfRisk(ulong ticket) { return "RM_SNAP_WASHALFRISK_" + IntegerToString(ticket); } // v19 (BUG-022)
string SnapKeyRootTicket(ulong ticket)    { return "RM_SNAP_ROOT_"       + IntegerToString(ticket); } // v75.13
string SnapKeyIsContinuation(ulong ticket){ return "RM_SNAP_ISCONT_"     + IntegerToString(ticket); } // v75.13
string SnapKeyRiskBaseUSD(ulong ticket)   { return "RM_SNAP_RISKBASE_"   + IntegerToString(ticket); } // v75.13
// v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله):
string SnapKeyBehErrCount(ulong ticket)  { return "RM_SNAP_BEHERRCNT_"  + IntegerToString(ticket); }
string SnapKeyDuringLock(ulong ticket)   { return "RM_SNAP_DURINGLOCK_" + IntegerToString(ticket); }
string SnapKeyIntervalViol(ulong ticket) { return "RM_SNAP_INTVIOL_"    + IntegerToString(ticket); }
string SnapKeySLTampered(ulong ticket)   { return "RM_SNAP_SLTAMPER_"   + IntegerToString(ticket); }
string SnapKeyDailyPctAtOpen(ulong ticket)  { return "RM_SNAP_DAILYPCT_"  + IntegerToString(ticket); }
string SnapKeyWeeklyPctAtOpen(ulong ticket) { return "RM_SNAP_WEEKLYPCT_" + IntegerToString(ticket); }
// v64:
string SnapKeyPriorDayResult(ulong ticket)  { return "RM_SNAP_PRIORDAY_"  + IntegerToString(ticket); }
string SnapKeySLLoosened(ulong ticket)      { return "RM_SNAP_SLLOOSE_"   + IntegerToString(ticket); }
// v64 (آیتم ۴):
string SnapKeyBehErrThisTrade(ulong ticket) { return "RM_SNAP_BEHTHIS_"   + IntegerToString(ticket); }
// v64 (آیتم ۶):
string SnapKeyTimeframeAtOpen(ulong ticket) { return "RM_SNAP_TFOPEN_"    + IntegerToString(ticket); }

// v64 (آیتم ۶ - TimeframeAtOpen): تبدیل عدد خام Period() (ذخیره‌شده در Snapshot/GlobalVariable)
// به رشته‌ی خوانا - فقط لحظه‌ی export/نمایش صدا زده می‌شه، نه لحظه‌ی ذخیره.
string TimeframeCodeToString(double code)
{
   if(code <= 0) return "N/A"; // سنتینل - هنوز ثبت نشده یا Snapshot معتبر نیست
   int period = (int)MathRound(code);
   switch(period)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "TF"+IntegerToString(period); // نامتعارف/سفارشی - فال‌بک خوانا به‌جای گم‌کردن داده
   }
}

int FindSnapshotIndexLocal(ulong ticket)   // v74.2 (HF3): memory-only lookup (the original FindSnapshotIndex)
{
   for(int i=0;i<g_snapCount;i++)
      if(g_snapTickets[i]==ticket) return i;
   return -1;
}

bool LoadOneSnapshot(ulong ticket);   // defined below (v74.2 HF3)

// v74.2 (HF3, MT4 v101 snapshot sync): a snapshot written by ANOTHER chart (position opened on chart A,
// handled on chart B) is not in this chart's memory. On a miss, try to pull that one ticket from the
// shared GlobalVariables before giving up.
int FindSnapshotIndex(ulong ticket)
{
   int idx = FindSnapshotIndexLocal(ticket);
   if(idx >= 0) return idx;
   if(ticket == 0 || !GlobalVariableCheck(SnapKeyEntry(ticket))) return -1;
   if(!LoadOneSnapshot(ticket)) return -1;
   return FindSnapshotIndexLocal(ticket);
}

// v11: تغییرناپذیر - اگه از قبل برای این تیکت Snapshot ثبت شده باشه، دوباره بازنویسی نمی‌شه
// (نه در حافظه، نه در GlobalVariable). این تنها راهیه که تضمین می‌کنه BE/Trailing/SL دستی
// نتونن مقادیر اولیه رو تغییر بدن.
//
// [Stage 5a - confirms and closes out the Stage 3 finding] initMaxFavR/initStriked/
// initWasHalfRisk و شش پارامتر اختیاری v61 (initBehErrCountAtOpen و بقیه) عمداً در امضای این
// تابع نگه داشته شده‌ن (وفاداری ساختاری، دقیقاً مثل فیلتر مرده‌ی نوع اردر در Stage 3) - ولی طبق
// یافته‌ی Stage 3، تنها caller واقعی این مقادیر (انتقال Snapshot به تیکت باقیمونده‌ی Half Close،
// در HalfCloseTicket - RM_TradeExecution.mq5) روی MT5 هیچ‌وقت اجرا نمی‌شه، چون Half Close تیکت
// جدیدی نمی‌سازه. یعنی این پارامترها روی این پورت **قابل‌دسترسی ولی بدون caller واقعی**ان -
// تأیید صریح، نه حذف سایلنت.
void SaveTradeSnapshot(ulong ticket, double entry, double sl, double riskUSD, double riskPct, datetime openTime, int magic, double initMaxFavR=0.0, bool initStriked=false, bool initWasHalfRisk=false,
                        double initBehErrCountAtOpen=0.0, bool initOpenedDuringCooldownLock=false, bool initEntryIntervalViolation=false, bool initSLTampered=false,
                        double initDailyRiskUsedPctAtOpen=0.0, double initWeeklyDDUsedPctAtOpen=0.0,
                        double initPriorDayResult=-2.0, int initSLLoosenedCount=0, double initBehaviorErrorsThisTrade=-1.0, double initTimeframeAtOpen=0.0,
                        double initMinFavR=0.0, double initRiskWeight=-1.0,
                        ulong initRootTicket=0, bool initIsContinuation=false, double initRiskBaseUSD=0.0)   // v75.13 (MT4 v86/v90)
{
   if(FindSnapshotIndex(ticket) >= 0) return;

   ArrayResize(g_snapTickets,  g_snapCount+1);
   ArrayResize(g_snapEntry,    g_snapCount+1);
   ArrayResize(g_snapSL,       g_snapCount+1);
   ArrayResize(g_snapRiskUSD,  g_snapCount+1);
   ArrayResize(g_snapRiskPct,  g_snapCount+1);
   ArrayResize(g_snapOpenTime, g_snapCount+1);
   ArrayResize(g_snapMagic,    g_snapCount+1);
   ArrayResize(g_snapMaxFavR,  g_snapCount+1);
   ArrayResize(g_snapMinFavR,  g_snapCount+1);
   ArrayResize(g_snapRiskWeight, g_snapCount+1);  // v66 (آیتم ۲ب)
   ArrayResize(g_snapStriked,  g_snapCount+1);
   ArrayResize(g_snapWasHalfRisk, g_snapCount+1);
   ArrayResize(g_snapBehaviorErrorCountAtOpen, g_snapCount+1);
   ArrayResize(g_snapOpenedDuringCooldownLock, g_snapCount+1);
   ArrayResize(g_snapEntryIntervalViolation,   g_snapCount+1);
   ArrayResize(g_snapSLTampered,               g_snapCount+1);
   ArrayResize(g_snapDailyRiskUsedPctAtOpen,   g_snapCount+1);
   ArrayResize(g_snapWeeklyDDUsedPctAtOpen,    g_snapCount+1);
   ArrayResize(g_snapPriorDayResult,           g_snapCount+1);
   ArrayResize(g_snapSLLoosenedCount,          g_snapCount+1);
   ArrayResize(g_snapBehaviorErrorsThisTrade,  g_snapCount+1);
   ArrayResize(g_snapTimeframeAtOpen,          g_snapCount+1);
   ArrayResize(g_snapRootTicket,     g_snapCount+1);   // v75.13
   ArrayResize(g_snapIsContinuation, g_snapCount+1);
   ArrayResize(g_snapRiskBaseUSD,    g_snapCount+1);

   g_snapTickets[g_snapCount]  = ticket;
   g_snapEntry[g_snapCount]    = entry;
   g_snapSL[g_snapCount]       = sl;
   g_snapRiskUSD[g_snapCount]  = riskUSD;
   g_snapRiskPct[g_snapCount]  = riskPct;
   g_snapOpenTime[g_snapCount] = openTime;
   g_snapMagic[g_snapCount]    = magic;
   g_snapMaxFavR[g_snapCount]  = initMaxFavR;
   g_snapMinFavR[g_snapCount]  = initMinFavR;
   g_snapRiskWeight[g_snapCount] = initRiskWeight;  // v66 (آیتم ۲ب)
   g_snapStriked[g_snapCount]  = initStriked;
   g_snapWasHalfRisk[g_snapCount] = initWasHalfRisk;
   g_snapBehaviorErrorCountAtOpen[g_snapCount] = initBehErrCountAtOpen;
   g_snapOpenedDuringCooldownLock[g_snapCount] = initOpenedDuringCooldownLock;
   g_snapEntryIntervalViolation[g_snapCount]   = initEntryIntervalViolation;
   g_snapSLTampered[g_snapCount]               = initSLTampered;
   g_snapDailyRiskUsedPctAtOpen[g_snapCount]   = initDailyRiskUsedPctAtOpen;
   g_snapWeeklyDDUsedPctAtOpen[g_snapCount]    = initWeeklyDDUsedPctAtOpen;
   g_snapPriorDayResult[g_snapCount]           = initPriorDayResult;
   g_snapSLLoosenedCount[g_snapCount]          = initSLLoosenedCount;
   g_snapBehaviorErrorsThisTrade[g_snapCount]  = initBehaviorErrorsThisTrade;
   g_snapTimeframeAtOpen[g_snapCount]          = initTimeframeAtOpen;
   ulong  rootVal     = (initRootTicket > 0) ? initRootTicket : ticket;                // v75.13: پیش‌فرض = ریشه‌ی خودِ پوزیشن
   double riskBaseVal = (initRiskBaseUSD > 0.0) ? initRiskBaseUSD : riskUSD;           // v75.13: پیش‌فرض = ریسک خودِ پوزیشن
   g_snapRootTicket[g_snapCount]     = rootVal;
   g_snapIsContinuation[g_snapCount] = initIsContinuation;
   g_snapRiskBaseUSD[g_snapCount]    = riskBaseVal;
   g_snapCount++;

   GlobalVariableSet(SnapKeyEntry(ticket),    entry);
   GlobalVariableSet(SnapKeySL(ticket),       sl);
   GlobalVariableSet(SnapKeyRiskUSD(ticket),  riskUSD);
   GlobalVariableSet(SnapKeyRiskPct(ticket),  riskPct);
   GlobalVariableSet(SnapKeyOpenTime(ticket), (double)openTime);
   GlobalVariableSet(SnapKeyMagic(ticket),    (double)magic);
   GlobalVariableSet(SnapKeyMaxFavR(ticket),  initMaxFavR);
   GlobalVariableSet(SnapKeyMinFavR(ticket),  initMinFavR);
   GlobalVariableSet(SnapKeyRiskWeight(ticket), initRiskWeight);  // v66 (آیتم ۲ب)
   GlobalVariableSet(SnapKeyStriked(ticket),  initStriked ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeyWasHalfRisk(ticket), initWasHalfRisk ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeyBehErrCount(ticket),    initBehErrCountAtOpen);
   GlobalVariableSet(SnapKeyDuringLock(ticket),     initOpenedDuringCooldownLock ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeyIntervalViol(ticket),   initEntryIntervalViolation ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeySLTampered(ticket),     initSLTampered ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeyDailyPctAtOpen(ticket), initDailyRiskUsedPctAtOpen);
   GlobalVariableSet(SnapKeyWeeklyPctAtOpen(ticket),initWeeklyDDUsedPctAtOpen);
   GlobalVariableSet(SnapKeyPriorDayResult(ticket), initPriorDayResult);
   GlobalVariableSet(SnapKeySLLoosened(ticket),     (double)initSLLoosenedCount);
   GlobalVariableSet(SnapKeyBehErrThisTrade(ticket),initBehaviorErrorsThisTrade);
   GlobalVariableSet(SnapKeyTimeframeAtOpen(ticket),initTimeframeAtOpen);
   GlobalVariableSet(SnapKeyRootTicket(ticket),     (double)rootVal);                    // v75.13
   GlobalVariableSet(SnapKeyIsContinuation(ticket), initIsContinuation ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeyRiskBaseUSD(ticket),    riskBaseVal);
   // v74.6 (HF6): GlobalVariableها فقط موقع بستن تمیز ترمینال روی دیسک ذخیره می‌شن. اگه ترمینال
   // بدون بسته‌شدن تمیز تموم بشه (کرش/kill/خاموشی)، Snapshot همه‌ی معاملات اون جلسه از دست می‌ره و
   // export بعدی CSV ستون‌های Snapshot رو N/A می‌نویسه. این فراخوانی فقط روی رویداد (ساخت Snapshot)
   // اجرا می‌شه، نه هر تیک.
   GlobalVariablesFlush();
}

// v61: پر کردن ۵ فیلد رفتاری (همه به‌جز SLTampered) در لحظه‌ی فعال‌شدن واقعیِ یک تیکت که با
// placeholder ساخته شده بود (فقط مسیر Pending). اگه از قبل Snapshot این تیکت نبود، کاری نمی‌کنه.
void SetSnapshotBehaviorFieldsAtActivation(ulong ticket, double behErrCountAtOpen, bool openedDuringCooldownLock, bool entryIntervalViolation, double dailyRiskUsedPctAtOpen, double weeklyDDUsedPctAtOpen, double priorDayResultAtOpen=-2.0, double timeframeAtOpen=0.0)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;

   g_snapBehaviorErrorCountAtOpen[idx] = behErrCountAtOpen;
   g_snapOpenedDuringCooldownLock[idx] = openedDuringCooldownLock;
   g_snapEntryIntervalViolation[idx]   = entryIntervalViolation;
   g_snapDailyRiskUsedPctAtOpen[idx]   = dailyRiskUsedPctAtOpen;
   g_snapWeeklyDDUsedPctAtOpen[idx]    = weeklyDDUsedPctAtOpen;
   g_snapPriorDayResult[idx]           = priorDayResultAtOpen;
   g_snapTimeframeAtOpen[idx]          = timeframeAtOpen;

   GlobalVariableSet(SnapKeyBehErrCount(ticket),    behErrCountAtOpen);
   GlobalVariableSet(SnapKeyDuringLock(ticket),     openedDuringCooldownLock ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeyIntervalViol(ticket),   entryIntervalViolation ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeyDailyPctAtOpen(ticket), dailyRiskUsedPctAtOpen);
   GlobalVariableSet(SnapKeyWeeklyPctAtOpen(ticket),weeklyDDUsedPctAtOpen);
   GlobalVariableSet(SnapKeyPriorDayResult(ticket), priorDayResultAtOpen);
   GlobalVariableSet(SnapKeyTimeframeAtOpen(ticket),timeframeAtOpen);
   GlobalVariablesFlush();   // v74.6 (HF6): فقط روی رویداد فعال‌شدن پندینگ، نه هر تیک - توضیح در SaveTradeSnapshot
}

// v61: SLTampered - جدا از تابع بالا چون این فیلد ذاتاً «بعداً معلوم می‌شه» است و ممکنه چندبار
// در طول عمر تیکت صدا زده بشه (idempotent - فقط false->true).
// v74.6 (HF6b): GlobalVariableها فقط روی خروج تمیز ترمینال روی دیسک ذخیره می‌شن؛ این فلگ + تابع زیر باعث می‌شه
// مقدارهای «به‌مرور-رشدکننده» (MaxFav/MinFav) حداکثر هر ~15 ثانیه یک‌بار (از OnTimer) flush بشن، نه هر تیک.
bool g_gvDirty = false;
uint g_gvLastFlushMs = 0;
void RM_GVFlushIfDirty()
{
   if(!g_gvDirty) return;
   uint nowMs = GetTickCount();
   if(g_gvLastFlushMs != 0 && (nowMs - g_gvLastFlushMs) < 15000) return;
   GlobalVariablesFlush();
   g_gvDirty = false;
   g_gvLastFlushMs = nowMs;
}

void MarkSnapshotTampered(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   if(g_snapSLTampered[idx]) return; // از قبل true بوده - کاری نیست
   g_snapSLTampered[idx] = true;
   GlobalVariableSet(SnapKeySLTampered(ticket), 1.0);
   GlobalVariablesFlush();   // v74.6 (HF6b): رویداد نادر
}

// v64 (آیتم ۳ - SLLoosenedCount): یک واحد به شمارنده‌ی این تیکت اضافه می‌کنه.
void IncrementSLLoosenedCount(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   g_snapSLLoosenedCount[idx]++;
   GlobalVariableSet(SnapKeySLLoosened(ticket), (double)g_snapSLLoosenedCount[idx]);
   GlobalVariablesFlush();   // v74.6 (HF6b): رویداد نادر
}

// v64 (آیتم ۴ - BehaviorErrorsThisTrade): «لحظه‌ی بسته‌شدن» یک‌بار محاسبه و ثبت می‌شه.
void SetSnapshotBehaviorErrorsThisTrade(ulong ticket, double count)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   g_snapBehaviorErrorsThisTrade[idx] = count;
   GlobalVariableSet(SnapKeyBehErrThisTrade(ticket), count);
   GlobalVariablesFlush();   // v74.6 (HF6b): فقط لحظه‌ی بسته‌شدن
}

// v74.5 (HF5): حذف کامل Snapshot یک پندینگ که قبل از فعال‌شدن لغو/منقضی شده (هم از حافظه‌ی این چارت، هم
// از GlobalVariableها). فقط از CheckPendingActivation صدا زده می‌شه، فقط وقتی تاریخچه ثابت کرده اردر
// CANCELED/EXPIRED/REJECTED بوده (هیچ‌وقت FILLED) - پس هیچ پوزیشنی به این تیکت وصل نیست.
void DropPendingSnapshot(ulong ticket)
{
   if(ticket == 0) return;
   if(GlobalVariableCheck(SnapKeyMagic(ticket)) && (int)GlobalVariableGet(SnapKeyMagic(ticket)) != MagicNumber) return; // متعلق به Magic دیگه
   int idx = FindSnapshotIndexLocal(ticket);
   if(idx >= 0)
   {
      for(int k=idx; k<g_snapCount-1; k++)
      {
         g_snapTickets[k] = g_snapTickets[k+1];
         g_snapEntry[k] = g_snapEntry[k+1];
         g_snapSL[k] = g_snapSL[k+1];
         g_snapRiskUSD[k] = g_snapRiskUSD[k+1];
         g_snapRiskPct[k] = g_snapRiskPct[k+1];
         g_snapOpenTime[k] = g_snapOpenTime[k+1];
         g_snapMagic[k] = g_snapMagic[k+1];
         g_snapMaxFavR[k] = g_snapMaxFavR[k+1];
         g_snapMinFavR[k] = g_snapMinFavR[k+1];
         g_snapRiskWeight[k] = g_snapRiskWeight[k+1];
         g_snapStriked[k] = g_snapStriked[k+1];
         g_snapWasHalfRisk[k] = g_snapWasHalfRisk[k+1];
         g_snapBehaviorErrorCountAtOpen[k] = g_snapBehaviorErrorCountAtOpen[k+1];
         g_snapOpenedDuringCooldownLock[k] = g_snapOpenedDuringCooldownLock[k+1];
         g_snapEntryIntervalViolation[k] = g_snapEntryIntervalViolation[k+1];
         g_snapSLTampered[k] = g_snapSLTampered[k+1];
         g_snapDailyRiskUsedPctAtOpen[k] = g_snapDailyRiskUsedPctAtOpen[k+1];
         g_snapWeeklyDDUsedPctAtOpen[k] = g_snapWeeklyDDUsedPctAtOpen[k+1];
         g_snapPriorDayResult[k] = g_snapPriorDayResult[k+1];
         g_snapSLLoosenedCount[k] = g_snapSLLoosenedCount[k+1];
         g_snapBehaviorErrorsThisTrade[k] = g_snapBehaviorErrorsThisTrade[k+1];
         g_snapTimeframeAtOpen[k] = g_snapTimeframeAtOpen[k+1];
         g_snapRootTicket[k] = g_snapRootTicket[k+1];
         g_snapIsContinuation[k] = g_snapIsContinuation[k+1];
         g_snapRiskBaseUSD[k] = g_snapRiskBaseUSD[k+1];
      }
      g_snapCount--;
      ArrayResize(g_snapTickets, g_snapCount);
      ArrayResize(g_snapEntry, g_snapCount);
      ArrayResize(g_snapSL, g_snapCount);
      ArrayResize(g_snapRiskUSD, g_snapCount);
      ArrayResize(g_snapRiskPct, g_snapCount);
      ArrayResize(g_snapOpenTime, g_snapCount);
      ArrayResize(g_snapMagic, g_snapCount);
      ArrayResize(g_snapMaxFavR, g_snapCount);
      ArrayResize(g_snapMinFavR, g_snapCount);
      ArrayResize(g_snapRiskWeight, g_snapCount);
      ArrayResize(g_snapStriked, g_snapCount);
      ArrayResize(g_snapWasHalfRisk, g_snapCount);
      ArrayResize(g_snapBehaviorErrorCountAtOpen, g_snapCount);
      ArrayResize(g_snapOpenedDuringCooldownLock, g_snapCount);
      ArrayResize(g_snapEntryIntervalViolation, g_snapCount);
      ArrayResize(g_snapSLTampered, g_snapCount);
      ArrayResize(g_snapDailyRiskUsedPctAtOpen, g_snapCount);
      ArrayResize(g_snapWeeklyDDUsedPctAtOpen, g_snapCount);
      ArrayResize(g_snapPriorDayResult, g_snapCount);
      ArrayResize(g_snapSLLoosenedCount, g_snapCount);
      ArrayResize(g_snapBehaviorErrorsThisTrade, g_snapCount);
      ArrayResize(g_snapTimeframeAtOpen, g_snapCount);
      ArrayResize(g_snapRootTicket, g_snapCount);
      ArrayResize(g_snapIsContinuation, g_snapCount);
      ArrayResize(g_snapRiskBaseUSD, g_snapCount);
   }
   GlobalVariableDel(SnapKeyEntry(ticket));
   GlobalVariableDel(SnapKeySL(ticket));
   GlobalVariableDel(SnapKeyRiskUSD(ticket));
   GlobalVariableDel(SnapKeyRiskPct(ticket));
   GlobalVariableDel(SnapKeyOpenTime(ticket));
   GlobalVariableDel(SnapKeyMagic(ticket));
   GlobalVariableDel(SnapKeyMaxFavR(ticket));
   GlobalVariableDel(SnapKeyMinFavR(ticket));
   GlobalVariableDel(SnapKeyStriked(ticket));
   GlobalVariableDel(SnapKeyWasHalfRisk(ticket));
   GlobalVariableDel(SnapKeyRiskWeight(ticket));
   GlobalVariableDel(SnapKeyBehErrCount(ticket));
   GlobalVariableDel(SnapKeyDuringLock(ticket));
   GlobalVariableDel(SnapKeyIntervalViol(ticket));
   GlobalVariableDel(SnapKeySLTampered(ticket));
   GlobalVariableDel(SnapKeyDailyPctAtOpen(ticket));
   GlobalVariableDel(SnapKeyWeeklyPctAtOpen(ticket));
   GlobalVariableDel(SnapKeyPriorDayResult(ticket));
   GlobalVariableDel(SnapKeySLLoosened(ticket));
   GlobalVariableDel(SnapKeyBehErrThisTrade(ticket));
   GlobalVariableDel(SnapKeyTimeframeAtOpen(ticket));
   GlobalVariableDel(SnapKeyRootTicket(ticket));
   GlobalVariableDel(SnapKeyIsContinuation(ticket));
   GlobalVariableDel(SnapKeyRiskBaseUSD(ticket));
}

// v11: در OnInit صدا زده می‌شه - همه‌ی Snapshotهای ذخیره‌شده‌ی این EA (بر اساس MagicNumber)
// رو از GlobalVariableها بازیابی می‌کنه تا Trade Snapshotهای قبل از ری‌استارت از دست نرن.
//
// [Stage 5a judgment call - explicit, per task instructions] MT4: `int ticket =
// (int)StringToInteger(...)`. MQL5's StringToInteger() returns a `long` (not `int`), so the port
// casts to `ulong` instead of `int`. This is safe: every real MT5 ticket value fits well within a
// positive `long` (StringToInteger never returns a negative value for a numeric ticket string), and
// converting a positive `long` to `ulong` is a lossless, direct bit-pattern reinterpretation -
// there is no value any real ticket could take that would overflow or wrap during this cast.
// v74.2 (HF3): loads ONE ticket's snapshot from GlobalVariables into this chart's arrays (the body of the
// old LoadTradeSnapshots() loop, unchanged). Returns false if incomplete / other magic / already loaded.
bool LoadOneSnapshot(ulong ticket)
{
   if(FindSnapshotIndexLocal(ticket) >= 0) return false;
   if(!GlobalVariableCheck(SnapKeySL(ticket)) || !GlobalVariableCheck(SnapKeyRiskUSD(ticket)) ||
      !GlobalVariableCheck(SnapKeyRiskPct(ticket)) || !GlobalVariableCheck(SnapKeyOpenTime(ticket)) ||
      !GlobalVariableCheck(SnapKeyMagic(ticket)))
      return false; // رکورد ناقص - نادیده گرفته می‌شه

   int magic = (int)GlobalVariableGet(SnapKeyMagic(ticket));
   if(magic != MagicNumber) return false; // متعلق به یک EA/Magic دیگه‌ست

   double entry    = GlobalVariableGet(SnapKeyEntry(ticket));
   double sl       = GlobalVariableGet(SnapKeySL(ticket));
   double riskUSD  = GlobalVariableGet(SnapKeyRiskUSD(ticket));
   double riskPct  = GlobalVariableGet(SnapKeyRiskPct(ticket));
   datetime openTm = (datetime)GlobalVariableGet(SnapKeyOpenTime(ticket));
   double maxFavR  = GlobalVariableCheck(SnapKeyMaxFavR(ticket)) ? GlobalVariableGet(SnapKeyMaxFavR(ticket)) : 0.0;
   double minFavR  = GlobalVariableCheck(SnapKeyMinFavR(ticket)) ? GlobalVariableGet(SnapKeyMinFavR(ticket)) : 0.0;
   bool striked = GlobalVariableCheck(SnapKeyStriked(ticket)) && (GlobalVariableGet(SnapKeyStriked(ticket)) != 0.0);
   double riskWeight = GlobalVariableCheck(SnapKeyRiskWeight(ticket)) ? GlobalVariableGet(SnapKeyRiskWeight(ticket)) : -1.0;
   bool wasHalfRisk = GlobalVariableCheck(SnapKeyWasHalfRisk(ticket)) && (GlobalVariableGet(SnapKeyWasHalfRisk(ticket)) != 0.0);

   double behErrCountAtOpen = GlobalVariableCheck(SnapKeyBehErrCount(ticket)) ? GlobalVariableGet(SnapKeyBehErrCount(ticket)) : 0.0;
   bool   duringLock        = GlobalVariableCheck(SnapKeyDuringLock(ticket)) && (GlobalVariableGet(SnapKeyDuringLock(ticket)) != 0.0);
   bool   intervalViol      = GlobalVariableCheck(SnapKeyIntervalViol(ticket)) && (GlobalVariableGet(SnapKeyIntervalViol(ticket)) != 0.0);
   bool   slTampered        = GlobalVariableCheck(SnapKeySLTampered(ticket)) && (GlobalVariableGet(SnapKeySLTampered(ticket)) != 0.0);
   double dailyPctAtOpen    = GlobalVariableCheck(SnapKeyDailyPctAtOpen(ticket)) ? GlobalVariableGet(SnapKeyDailyPctAtOpen(ticket)) : 0.0;
   double weeklyPctAtOpen   = GlobalVariableCheck(SnapKeyWeeklyPctAtOpen(ticket)) ? GlobalVariableGet(SnapKeyWeeklyPctAtOpen(ticket)) : 0.0;

   double priorDayResult    = GlobalVariableCheck(SnapKeyPriorDayResult(ticket)) ? GlobalVariableGet(SnapKeyPriorDayResult(ticket)) : -2.0;
   int    slLoosenedCount   = GlobalVariableCheck(SnapKeySLLoosened(ticket)) ? (int)MathRound(GlobalVariableGet(SnapKeySLLoosened(ticket))) : 0;
   double behErrThisTrade   = GlobalVariableCheck(SnapKeyBehErrThisTrade(ticket)) ? GlobalVariableGet(SnapKeyBehErrThisTrade(ticket)) : -1.0;
   double timeframeAtOpen   = GlobalVariableCheck(SnapKeyTimeframeAtOpen(ticket)) ? GlobalVariableGet(SnapKeyTimeframeAtOpen(ticket)) : 0.0;
   // v75.13: Snapshot قبل از این نسخه این سه کلید را ندارد -> ریشه = خودش، ادامه = false، RiskBase = RiskUSD (رفتار قبلی)
   ulong  rootTk            = GlobalVariableCheck(SnapKeyRootTicket(ticket)) ? (ulong)MathRound(GlobalVariableGet(SnapKeyRootTicket(ticket))) : ticket;
   if(rootTk == 0) rootTk = ticket;
   bool   isContinuation    = GlobalVariableCheck(SnapKeyIsContinuation(ticket)) && (GlobalVariableGet(SnapKeyIsContinuation(ticket)) != 0.0);
   double riskBaseUSD       = GlobalVariableCheck(SnapKeyRiskBaseUSD(ticket)) ? GlobalVariableGet(SnapKeyRiskBaseUSD(ticket)) : riskUSD;
   if(riskBaseUSD <= 0.0) riskBaseUSD = riskUSD;

   // مستقیم به آرایه‌ها اضافه می‌شه (نه از طریق SaveTradeSnapshot) چون این مقادیر از قبل
   // در GlobalVariable ذخیره شدن و نیازی به GlobalVariableSet دوباره نیست
   ArrayResize(g_snapTickets,  g_snapCount+1);
   ArrayResize(g_snapEntry,    g_snapCount+1);
   ArrayResize(g_snapSL,       g_snapCount+1);
   ArrayResize(g_snapRiskUSD,  g_snapCount+1);
   ArrayResize(g_snapRiskPct,  g_snapCount+1);
   ArrayResize(g_snapOpenTime, g_snapCount+1);
   ArrayResize(g_snapMagic,    g_snapCount+1);
   ArrayResize(g_snapMaxFavR,  g_snapCount+1);
   ArrayResize(g_snapMinFavR,  g_snapCount+1);
   ArrayResize(g_snapRiskWeight, g_snapCount+1);  // v66 (آیتم ۲ب)
   ArrayResize(g_snapStriked,  g_snapCount+1);
   ArrayResize(g_snapWasHalfRisk, g_snapCount+1);
   ArrayResize(g_snapBehaviorErrorCountAtOpen, g_snapCount+1);
   ArrayResize(g_snapOpenedDuringCooldownLock, g_snapCount+1);
   ArrayResize(g_snapEntryIntervalViolation,   g_snapCount+1);
   ArrayResize(g_snapSLTampered,               g_snapCount+1);
   ArrayResize(g_snapDailyRiskUsedPctAtOpen,   g_snapCount+1);
   ArrayResize(g_snapWeeklyDDUsedPctAtOpen,    g_snapCount+1);
   ArrayResize(g_snapPriorDayResult,           g_snapCount+1);
   ArrayResize(g_snapSLLoosenedCount,          g_snapCount+1);
   ArrayResize(g_snapBehaviorErrorsThisTrade,  g_snapCount+1);
   ArrayResize(g_snapTimeframeAtOpen,          g_snapCount+1);
   ArrayResize(g_snapRootTicket,     g_snapCount+1);   // v75.13
   ArrayResize(g_snapIsContinuation, g_snapCount+1);
   ArrayResize(g_snapRiskBaseUSD,    g_snapCount+1);

   g_snapTickets[g_snapCount]  = ticket;
   g_snapEntry[g_snapCount]    = entry;
   g_snapSL[g_snapCount]       = sl;
   g_snapRiskUSD[g_snapCount]  = riskUSD;
   g_snapRiskPct[g_snapCount]  = riskPct;
   g_snapOpenTime[g_snapCount] = openTm;
   g_snapMagic[g_snapCount]    = magic;
   g_snapMaxFavR[g_snapCount]  = maxFavR;
   g_snapMinFavR[g_snapCount]  = minFavR;
   g_snapRiskWeight[g_snapCount] = riskWeight;  // v66 (آیتم ۲ب)
   g_snapStriked[g_snapCount]  = striked;
   g_snapWasHalfRisk[g_snapCount] = wasHalfRisk;
   g_snapBehaviorErrorCountAtOpen[g_snapCount] = behErrCountAtOpen;
   g_snapOpenedDuringCooldownLock[g_snapCount] = duringLock;
   g_snapEntryIntervalViolation[g_snapCount]   = intervalViol;
   g_snapSLTampered[g_snapCount]               = slTampered;
   g_snapDailyRiskUsedPctAtOpen[g_snapCount]   = dailyPctAtOpen;
   g_snapWeeklyDDUsedPctAtOpen[g_snapCount]    = weeklyPctAtOpen;
   g_snapPriorDayResult[g_snapCount]           = priorDayResult;
   g_snapSLLoosenedCount[g_snapCount]          = slLoosenedCount;
   g_snapBehaviorErrorsThisTrade[g_snapCount]  = behErrThisTrade;
   g_snapTimeframeAtOpen[g_snapCount]          = timeframeAtOpen;
   g_snapRootTicket[g_snapCount]               = rootTk;
   g_snapIsContinuation[g_snapCount]           = isContinuation;
   g_snapRiskBaseUSD[g_snapCount]              = riskBaseUSD;
   g_snapCount++;
   return true;
}

void LoadTradeSnapshots()
{
   string prefix = "RM_SNAP_ENTRY_";
   int total = GlobalVariablesTotal();
   for(int i=0;i<total;i++)
   {
      string nm = GlobalVariableName(i);
      if(StringFind(nm, prefix) != 0) continue;

      ulong ticket = (ulong)StringToInteger(StringSubstr(nm, StringLen(prefix)));
      if(ticket<=0) continue;
      LoadOneSnapshot(ticket); // v74.2 (HF3): same checks as before, now in one reusable function
   }
}

//+------------------------------------------------------------------+
// v18 (BUG-021): هر تیک برای یک تیکت باز با Snapshot معتبر صدا زده می‌شه (از داخل
// TrackOpenTrades). سود جاری رو بر مبنای Initial Risk ($) همون Snapshot به R تبدیل می‌کنه و اگه
// از بالاترین مقدار قبلی بیشتر بود، هم در حافظه و هم در GlobalVariable به‌روزرسانی می‌شه.
//
// [Stage 5a judgment call] MT4: profit = OrderProfit()+OrderSwap()+OrderCommission() - روی یک
// اردر باز، هر سه فیلد در دسترس بودن. MT5: PositionGetDouble(POSITION_PROFIT) و
// POSITION_SWAP هر دو موجودن، ولی هیچ POSITION_COMMISSION ای وجود نداره - دقیقاً همون شکاف
// پلتفرمی که در Stage 4 (GetFloatingPLPercent) مستند شده: کمیسیون در MT5 فقط سطح Deal ثبت
// می‌شه (باز/بسته)، نه به‌عنوان یک فیلد زنده روی پوزیشن باز. چیزی برای اضافه‌کردن به‌عنوان
// «کمیسیون شناور» روی یک پوزیشن هنوز-باز وجود نداره - این یه شکاف واقعی تعریف بین پلتفرم‌هاست،
// نه یه فرمول که عمداً حذف شده باشه.
//+------------------------------------------------------------------+
void UpdateSnapshotMaxFavorableR(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return; // بدون Snapshot - نمی‌شه R رو معنادار محاسبه کرد

   double oneR = g_snapRiskUSD[idx];
   if(oneR <= 0) return;

   double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   double curR   = profit / oneR;

   if(curR > g_snapMaxFavR[idx])
   {
      g_snapMaxFavR[idx] = curR;
      GlobalVariableSet(SnapKeyMaxFavR(ticket), curR);
      g_gvDirty = true;   // v74.6 (HF6b): flush دسته‌ای از OnTimer
   }
}

// v66 (آیتم ۲ب - MAE): قرینه‌ی دقیق UpdateSnapshotMaxFavorableR بالا - همون شکاف کمیسیون
// (بالا مستند شده) اینجا هم صدق می‌کنه.
void UpdateSnapshotMinFavorableR(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return; // بدون Snapshot - نمی‌شه R رو معنادار محاسبه کرد

   double oneR = g_snapRiskUSD[idx];
   if(oneR <= 0) return;

   double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   double curR   = profit / oneR;

   if(curR < g_snapMinFavR[idx])
   {
      g_snapMinFavR[idx] = curR;
      GlobalVariableSet(SnapKeyMinFavR(ticket), curR);
      g_gvDirty = true;   // v74.6 (HF6b)
   }
}

// v18 (BUG-021): آیا این تیکت تا این لحظه هرگز واقعاً به +1R رسیده؟ (تلورانس ±5%).
bool IsPrematureBeforeOneR(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return false;
   return (g_snapMaxFavR[idx] < 0.95);
}

// v18 (BUG-021 refinement): آیا این معامله از قبل به‌خاطر اقدام زودهنگام Strike گرفته؟
bool IsAlreadyStrikedThisTrade(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return false;
   // v74.2 (HF3): the strike flag may have been set by another chart after this chart loaded the snapshot -
   // the shared GlobalVariable is the truth, so a strike is never counted twice across charts.
   if(!g_snapStriked[idx] && GlobalVariableCheck(SnapKeyStriked(ticket)) && GlobalVariableGet(SnapKeyStriked(ticket)) != 0.0)
      g_snapStriked[idx] = true;
   return g_snapStriked[idx];
}

// v18 (BUG-021 refinement): این معامله رو به‌عنوان «Strike‌گرفته» علامت می‌زنه.
void MarkStrikedThisTrade(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   g_snapStriked[idx] = true;
   GlobalVariableSet(SnapKeyStriked(ticket), 1.0);
   GlobalVariablesFlush();   // v74.6 (HF6b): رویداد نادر
}

// v75.10 (MT4 v84): وزن ریسک واقعی معامله (1, 0.5, 0.25, 0.125). اگر ثبت نشده: WasHalfRisk ? 0.5 : 1.0
double SnapRiskWeight(int idx)
{
   if(idx < 0 || idx >= g_snapCount) return 1.0;
   if(g_snapRiskWeight[idx] > 0.0) return g_snapRiskWeight[idx];
   return g_snapWasHalfRisk[idx] ? 0.5 : 1.0;
}

// v75.13 (MT4 v90 FEAT-044): پایه‌ی R زنجیره‌ای یک Snapshot (دلار). تنها نقطه‌ی تفسیر؛ مصرف‌کننده‌ها: Net R / RB، Market Cooldown، Reports.
double SnapRiskBase(int idx)
{
   if(idx < 0 || idx >= g_snapCount) return 0.0;
   if(g_snapRiskBaseUSD[idx] > 0.0) return g_snapRiskBaseUSD[idx];
   return g_snapRiskUSD[idx];
}

// آیا این پوزیشن ورود ادامه (Scale-in) است؟ بدون Snapshot -> false.
bool IsContinuationTicket(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return false;
   return g_snapIsContinuation[idx];
}

// ریشه‌ی زنجیره‌ی یک پوزیشن. بدون Snapshot -> خودش. تنها نقطه‌ی تفسیر ریشه (تگ‌ها و ستون RootTicket در CSV هم از همین می‌خونن).
ulong GetRootTicket(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx >= 0 && g_snapRootTicket[idx] > 0) return g_snapRootTicket[idx];
   return ticket;
}

// تعداد پوزیشن‌های Snapshot‌دار یک زنجیره. ۱ = معامله‌ی تکی؛ >۱ = ریشه + حداقل یک ورود ادامه.
int ChainMemberCount(ulong root)
{
   int n = 0;
   for(int i=0;i<g_snapCount;i++)
   {
      ulong r = (g_snapRootTicket[i] > 0) ? g_snapRootTicket[i] : g_snapTickets[i];
      if(r == root) n++;
   }
   return n;
}

// «زنجیره کامل بسته شد؟» - false اگر هر پوزیشن بازِ هم‌مجیک یا Pending منتظر با همین ریشه وجود داشته باشد.
bool IsChainFullyClosed(ulong root)
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(GetRootTicket(tk) == root) return false;
   }
   for(int j=OrdersTotal()-1; j>=0; j--)
   {
      ulong ot = OrderGetTicket(j);
      if(ot == 0) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if(GetRootTicket(ot) == root) return false;
   }
   return true;
}

// GlobalVariableها بعد از ~۴ هفته بدون دسترسی پاک می‌شن. فقط برای عضوهای ورود ادامه (کلید ریشه معنی دارد) تازه‌سازی انجام می‌شود.
void RefreshChainRootKeys()
{
   int touched = 0;
   for(int i=0;i<g_snapCount;i++)
   {
      ulong tk = g_snapTickets[i];
      ulong rt = g_snapRootTicket[i];
      if(rt == 0 || rt == tk) continue;
      GlobalVariableSet(SnapKeyRootTicket(tk), (double)rt);
      if(GlobalVariableCheck(SnapKeyRiskBaseUSD(tk)))    GlobalVariableSet(SnapKeyRiskBaseUSD(tk), GlobalVariableGet(SnapKeyRiskBaseUSD(tk)));
      if(GlobalVariableCheck(SnapKeyIsContinuation(tk))) GlobalVariableSet(SnapKeyIsContinuation(tk), GlobalVariableGet(SnapKeyIsContinuation(tk)));
      if(GlobalVariableCheck(SnapKeyRiskUSD(rt))) GlobalVariableGet(SnapKeyRiskUSD(rt));
      touched++;
   }
   if(touched > 0) Print("RM: RefreshChainRootKeys - refreshed ", touched, " chain root key(s)");
}

// جدا کردن ریشه‌ی یک ورود ادامه‌ی Pending که بدون پر شدن لغو/منقضی شد: ریشه = خودش، تا زنجیره‌ی هدف بدون این شبح ارزیابی شود.
void DetachSnapshotRoot(ulong ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   g_snapRootTicket[idx] = ticket;
   GlobalVariableSet(SnapKeyRootTicket(ticket), (double)ticket);
}


//+------------------------------------------------------------------+
// === v75.13 (MT4 v90 FEAT-044): Scale-in - ورود ادامه با ریسک آزادشده‌ی یک زنجیره (حالت ۱: محافظه‌کار) ===
// سقف = max(0, RiskUSD ریشه - ریسک بازِ زنده‌ی علامت‌دار زنجیره). «ریسک بازِ زنده» از SL زنده‌ی پوزیشن‌ها می‌آید (نه Snapshot):
// SL فراتر از ورود (سود قفل‌شده) ریسک *منفی* حساب می‌شود و سقف را بزرگ‌تر می‌کند. سود بانک‌شده لحاظ نمی‌شود.
// توجه: PositionGetTicket/OrderGetTicket «انتخاب جاری» را عوض می‌کنند - فراخواننده اگر لازم دارد دوباره PositionSelect کند.
//+------------------------------------------------------------------+
double GetChainLiveOpenRiskUSD(ulong root, bool &ok, int &openParts, bool &isBuy, string &sym)
{
   ok = true; openParts = 0; isBuy = true; sym = "";
   double risk = 0.0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      long ty = PositionGetInteger(POSITION_TYPE);
      if(ty != POSITION_TYPE_BUY && ty != POSITION_TYPE_SELL) continue;
      if(GetRootTicket(tk) != root) continue;

      string osym = PositionGetString(POSITION_SYMBOL);
      if(openParts == 0){ isBuy = (ty == POSITION_TYPE_BUY); sym = osym; }
      openParts++;

      double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0){ ok = false; continue; }
      double opt   = SymbolInfoDouble(osym, SYMBOL_POINT);
      double opipf = PipFactorForSymbol(osym);
      if(opt <= 0){ ok = false; continue; }
      double pval  = GetPipValueForSymbol(osym, opt, opipf);
      if(pval <= 0){ ok = false; continue; }
      double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
      double signedDist = (ty == POSITION_TYPE_BUY) ? (openPx - sl) : (sl - openPx);   // >0 = هنوز ریسک؛ <0 = سود قفل‌شده
      risk += signedDist/(opt*opipf) * pval * PositionGetDouble(POSITION_VOLUME);
   }
   return risk;
}

// آیا برای این ریشه یک سفارش Pending (پر‌نشده) وجود دارد؟ (ورود ادامه‌ی منتظرِ پر شدن)
bool ChainHasPendingOrder(ulong root)
{
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong ot = OrderGetTicket(i);
      if(ot == 0) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if(GetRootTicket(ot) == root) return true;
   }
   return false;
}

// سقف حالت ۱ (دلار) برای یک ریشه. کمتر/مساوی صفر = مجاز نیست؛ why دلیل کوتاه (برای نوار وضعیت).
double ScaleInCapUSD(ulong root, string &why)
{
   why = "";
   int idxRoot = FindSnapshotIndex(root);
   if(idxRoot < 0 || g_snapRiskUSD[idxRoot] <= 0){ why = "no root risk record"; return 0.0; }

   bool ok; int parts; bool isBuy; string sym;
   double live = GetChainLiveOpenRiskUSD(root, ok, parts, isBuy, sym);
   if(parts <= 0)       { why = "chain not open"; return 0.0; }
   if(sym != _Symbol)   { why = "other symbol"; return 0.0; }
   if(!ok)              { why = "open part without SL"; return 0.0; }
   if(ChainHasPendingOrder(root)){ why = "pending continuation waiting"; return 0.0; }

   double cap = g_snapRiskUSD[idxRoot] - live;
   if(cap < 0.01)       { why = "no freed risk"; return 0.0; }
   return cap;
}

// جهت زنجیره (true=BUY). فقط وقتی معنا دارد که بخش بازی باشد.
bool ScaleInChainIsBuy(ulong root)
{
   bool ok; int parts; bool isBuy; string sym;
   GetChainLiveOpenRiskUSD(root, ok, parts, isBuy, sym);
   return isBuy;
}

// فهرست زنجیره‌های مجاز (باز، هم‌نماد، سقف>0، بدون Pending منتظر). آرایه‌ها هم‌ایندکس. خروجی = تعداد.
int BuildScaleInCandidates(string &whyNone)
{
   ArrayResize(g_scCandRoot,0); ArrayResize(g_scCandCap,0); ArrayResize(g_scCandBuy,0); ArrayResize(g_scCandEntry,0);
   int n = 0, seenRoots = 0;
   string lastWhy = "";
   ulong  roots[]; ArrayResize(roots,0);

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      ulong r = GetRootTicket(tk);
      bool dup = false;
      for(int k=0;k<seenRoots;k++) if(roots[k]==r){ dup = true; break; }
      if(dup) continue;
      ArrayResize(roots, seenRoots+1); roots[seenRoots] = r; seenRoots++;
   }

   for(int q=0;q<seenRoots;q++)
   {
      string why;
      double cap = ScaleInCapUSD(roots[q], why);
      if(cap <= 0){ lastWhy = why; continue; }
      int idxRoot = FindSnapshotIndex(roots[q]);
      ArrayResize(g_scCandRoot,n+1); ArrayResize(g_scCandCap,n+1); ArrayResize(g_scCandBuy,n+1); ArrayResize(g_scCandEntry,n+1);
      g_scCandRoot[n]  = roots[q];
      g_scCandCap[n]   = cap;
      g_scCandBuy[n]   = ScaleInChainIsBuy(roots[q]);
      g_scCandEntry[n] = (idxRoot>=0) ? g_snapEntry[idxRoot] : 0.0;
      n++;
   }
   if(n == 0) whyNone = (seenRoots==0) ? "no open trade" : lastWhy;
   return n;
}

// درصدِ ریسکِ ورود. در حالت Scale-in = سقف زنده‌ی زنجیره‌ی انتخاب‌شده به درصد بالانس (دکمه‌ی Full/Half نادیده)؛ وگرنه همان GetActiveRiskPct().
// ضریب (1+1e-9) فقط جلوی خطای ممیز شناور را می‌گیرد (لات به LotStep پایین گرد می‌شود، پس ریسک واقعی از سقف بیشتر نمی‌شود).
double GetEntryRiskPct()
{
   if(!g_scaleInOn) return GetActiveRiskPct();
   string why;
   double cap = ScaleInCapUSD(g_scaleInRoot, why);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(cap <= 0 || bal <= 0) return 0.0;
   return cap/bal*100.0*(1.0+1e-9);
}

// حذف یک سفارش Pending (MT5: TRADE_ACTION_REMOVE). true اگر موفق.
bool RM_RemovePendingOrder(ulong ticket)
{
   MqlTradeRequest req; ZeroMemory(req);
   MqlTradeResult  res; ZeroMemory(res);
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;
   bool sent = OrderSend(req, res);
   Print("RM_Trade[RemovePending]: retcode=",res.retcode," (",res.comment,") order=",ticket);
   return (sent && (res.retcode==TRADE_RETCODE_DONE || res.retcode==TRADE_RETCODE_DONE_PARTIAL));
}
