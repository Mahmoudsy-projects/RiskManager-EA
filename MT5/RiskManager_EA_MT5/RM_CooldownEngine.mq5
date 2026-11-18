//+------------------------------------------------------------------+
//| RM_CooldownEngine.mq5                                              |
//| Risk Manager EA - Cooldown & Behavior Engine (MT5 Port, Stage 4)   |
//| پورت مستقیم از RM_CooldownEngine.mqh (RiskManager EA v70, MQL4).    |
//| Golden Rule: فرمول‌ها/آستانه‌ها/ترتیب عملیات عوض نشدن - فقط           |
//| فراخوانی‌های API از MT4 به MT5 ترجمه شدن.                            |
//|                                                                     |
//| ==================================================================|
//| [Stage 4 - CheckClosedTrades() deal-vs-position mapping decision, |
//| written out explicitly BEFORE the function itself, per task       |
//| instructions]                                                     |
//| ==================================================================|
//| MT4 model: OrdersHistoryTotal()/OrderSelect(SELECT_BY_POS,          |
//| MODE_HISTORY) treats "one order ticket" as "one closed trade" -    |
//| this held even for Half Close, because MT4's OrderClose() on a     |
//| partial volume closes the ORIGINAL ticket for that partial amount |
//| and opens a BRAND NEW ticket for the remainder (confirmed by this  |
//| project's own v11/FEAT-016 comments). So in MT4, every entry in    |
//| order history really is a single, final classification event.     |
//|                                                                     |
//| MT5 model (confirmed empirically in Stage 3 testing): a partial    |
//| close does NOT create a new position ticket - the SAME position    |
//| ticket just has its POSITION_VOLUME reduced, and the position       |
//| stays OPEN (still present in PositionsTotal()) until the very last |
//| portion closes. History in MT5 is deal-based: an open and a close  |
//| are two separate deals linked by DEAL_POSITION_ID; a position that |
//| was partially closed twice before its final close has THREE deals |
//| total (one IN, two OUT) under the same position ID.                |
//|                                                                     |
//| Decision (three parts):                                            |
//| 1) "Is this position still open?" detection needs NO redesign.     |
//|    TrackOpenTrades()'s "is this ticket still in the open list"      |
//|    check translates directly to "is this position ticket still in  |
//|    PositionsTotal()/PositionGetTicket()" - a partially-closed        |
//|    position is still found there (same ticket, smaller volume), so |
//|    it correctly stays untouched by CheckClosedTrades() until it's   |
//|    genuinely gone. No behavior difference from MT4 here.            |
//| 2) Classification (hitSL/hitTP/EarlyExit, Market/Behavior Cooldown |
//|    counters) fires exactly ONCE per position, at the moment it      |
//|    finally disappears from PositionsTotal() - matching MT4's        |
//|    "one order = one classification event" model. Partial-close      |
//|    deals along the way are NOT separately reported to the           |
//|    behavioral classification system; there is no MT5 equivalent    |
//|    of "the remainder got a new ticket that gets tracked separately" |
//|    to preserve, because that MT4 mechanism doesn't exist here.      |
//| 3) For that single classification event, once the position is       |
//|    confirmed gone, HistorySelectByPosition(ticket) loads every deal |
//|    under that position ID. The classification's "close price"       |
//|    comes from the LAST deal with DEAL_ENTRY==DEAL_ENTRY_OUT (the    |
//|    deal that brought the position to zero volume - the direct       |
//|    equivalent of MT4's OrderClosePrice() on the final closing        |
//|    order). The classification's "profit" is the SUM of              |
//|    DEAL_PROFIT+DEAL_SWAP+DEAL_COMMISSION across ALL OUT deals for    |
//|    that position (every partial close's realized P&L plus the       |
//|    final close's) - this matches the original variable's meaning    |
//|    ("net result of this trade") more faithfully than using only the |
//|    last deal's P&L, since a half-closed position's overall result   |
//|    should reflect the whole position, not just its last fraction.   |
//|                                                                     |
//| Consequence requiring a structural (not formula) change: MT4's       |
//| classification reads OrderTakeProfit()/OrderLots() directly off the |
//| closed historical ORDER. MT5 deals carry no SL/TP/volume-at-open     |
//| fields - only price/profit/swap/commission per execution. So this   |
//| port adds two new tracked arrays, g_trackedTP[] and g_trackedLots[],|
//| populated by TrackOpenTrades() the same way g_trackedSL[] already    |
//| was (synced live each tick while the position is open), so their    |
//| last-known values are still available at the moment classification  |
//| runs, after the position itself is gone. This is a data-capture     |
//| addition made necessary by the API difference, not a formula        |
//| change - TP/Lots were always implicitly available in MT4's history   |
//| record; MT5 just doesn't keep them there, so this port keeps them    |
//| itself instead, sourced from the same live position data the rest    |
//| of this function already reads every tick.                          |
//+------------------------------------------------------------------+

// v53 (شمارنده‌های Market/Behavior Cooldown مشترک بین چارت‌ها):
// -------------------------------------------------------------------------
// چون از این نسخه به بعد چند نمونه‌ی EA (چارت‌های مختلف) هم‌زمان می‌تونن همون
// GlobalVariable مشترک رو بخونن/بنویسن، یه read-modify-write ساده (GlobalVariableGet
// → +delta → GlobalVariableSet) خطر lost-update داره: اگه دو چارت تقریباً هم‌زمان
// مقدار قدیمی رو بخونن و هر دو +1 کنن، یکی از دو افزایش گم می‌شه. به‌جاش از
// GlobalVariableSetOnCondition() استفاده می‌شه (compare-and-swap واقعی MQL4/MQL5،
// همون امضا و رفتار در هر دو زبان): مقدار فعلی خونده می‌شه، نوشتن مقدار جدید فقط
// زمانی موفقه که GV هنوز همون مقدار قدیمی باشه؛ اگه یه چارت دیگه بین خوندن و نوشتن ما
// مقدار رو عوض کرده بود، دوباره از GV (نه از کش محلی) می‌خونیم و دوباره تلاش می‌کنیم -
// با یه سقف تلاش معقول تا گیر نکنه.
#define RM_CAS_MAX_RETRY 8

// افزایش امن یک GlobalVariable مشترک به‌اندازه‌ی delta (برای reset از CAS_SetGlobal
// با value=0 استفاده کن). مقدار نهایی که واقعاً نوشته شد رو برمی‌گردونه، تا صدازننده
// بتونه mirror محلی‌اش (g_mktStopCount/g_behCount) رو دقیقاً با همون مقدار sync کنه.
double CAS_AddToGlobal(string gvName, double delta)
{
   if(!GlobalVariableCheck(gvName)) GlobalVariableSet(gvName, 0.0);
   double current = GlobalVariableGet(gvName);
   for(int attempt=0; attempt<RM_CAS_MAX_RETRY; attempt++)
   {
      double newVal = current + delta;
      if(GlobalVariableSetOnCondition(gvName, newVal, current))
      { GlobalVariablesFlush(); return newVal; }   // v74.6 (HF6b): شمارنده‌ها فقط روی رویداد تغییر می‌کنن // موفق - هیچ چارت دیگه‌ای بین خوندن و نوشتن ما مقدار رو عوض نکرد
      current = GlobalVariableGet(gvName); // شرط برقرار نبود - دوباره بخون و دوباره تلاش کن
   }
   // v53: بعد از RM_CAS_MAX_RETRY بار رقابت پشت‌سرهم (عملاً خیلی بعیده) - به‌جای گیر کردن
   // بی‌نهایت، مستقیم می‌نویسیم. حداکثر ریسک: یکی از افزایش‌های هم‌زمان (نادر) گم بشه، ولی
   // سیستم هیچ‌وقت قفل نمی‌مونه یا کرش نمی‌کنه.
   double fallback = current + delta;
   GlobalVariableSet(gvName, fallback);
   GlobalVariablesFlush();   // v74.6 (HF6b)
   return fallback;
}

// ست کردن امن یک GlobalVariable مشترک به یک مقدار مطلق مشخص (مثلاً ریست به صفر) -
// همون الگوی CAS بالا، ولی به‌جای افزایش، مقدار هدف رو مستقیم می‌نویسه.
double CAS_SetGlobal(string gvName, double value)
{
   if(!GlobalVariableCheck(gvName)) { GlobalVariableSet(gvName, value); return value; }
   double current = GlobalVariableGet(gvName);
   for(int attempt=0; attempt<RM_CAS_MAX_RETRY; attempt++)
   {
      if(current == value) return value; // یه چارت دیگه از قبل همین مقدار رو نوشته - کاری نیست
      if(GlobalVariableSetOnCondition(gvName, value, current))
      { GlobalVariablesFlush(); return value; }   // v74.6 (HF6b)
      current = GlobalVariableGet(gvName);
   }
   GlobalVariableSet(gvName, value); // fallback نهایی
   GlobalVariablesFlush();   // v74.6 (HF6b)
   return value;
}

// v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله): شمارنده‌ی یکپارچه‌ی رویدادهای رفتاری واقعی -
// account-wide (CAS)، دقیقاً هم‌الگوی GV_MKT_COUNT/GV_BEH_COUNT بالا؛ فقط هیچ‌وقت ریست نمی‌شه.
// خوندن، مستقیم از GV زنده (نه یه mirror محلی) - این شمارنده جایی روی داشبورد نمایش داده نمی‌شه،
// فقط لحظه‌ی باز شدن هر معامله‌ی جدید یک‌بار خونده می‌شه (Snapshot)، پس نیازی به mirror نیست.
double GetBehaviorErrorTotal()
{
   return GlobalVariableCheck(GV_BEHERR_TOTAL) ? GlobalVariableGet(GV_BEHERR_TOTAL) : 0.0;
}

void IncrementBehaviorErrorTotal()
{
   CAS_AddToGlobal(GV_BEHERR_TOTAL, 1.0);
}

// خوندن زنده‌ی سه مقدار مشترک بین چارت‌ها (دو شمارنده + کمکی مستقیم‌شون) از
// GlobalVariable مشترک، به mirror محلی (g_mktStopCount/g_behCount/g_lastStopCloseTime).
// چون GlobalVariableGet همیشه از جدول ترمینال (سراسری، نه کش این EA) می‌خونه، این تابع
// همیشه آخرین مقداری که هر چارت دیگه‌ای نوشته رو می‌بینه. صدا زده می‌شه توی OnInit
// (از طریق LoadCooldownState) و هر تیک (از طریق CheckMarketCDTimeReset، قبل از
// CheckClosedTrades و UpdateCooldownDisplay) تا mirror محلی همیشه تازه بمونه.
void RefreshSharedCooldownState()
{
   g_mktStopCount      = GlobalVariableCheck(GV_MKT_COUNT) ? GlobalVariableGet(GV_MKT_COUNT) : 0.0;
   g_behCount           = GlobalVariableCheck(GV_BEH_COUNT) ? (int)MathRound(GlobalVariableGet(GV_BEH_COUNT)) : 0;
   g_lastStopCloseTime  = GlobalVariableCheck(GV_LAST_STOP_CLOSE) ? (datetime)GlobalVariableGet(GV_LAST_STOP_CLOSE) : 0;
}

// v74.2 (HF3, B4, MT4 v101/v102): lock END times are account-wide too. Every tick this chart adopts the values
// other charts wrote (Market, Behavior, Daily, Weekly, Monthly). A missing GlobalVariable leaves the local value.
// Writers always publish to the GV in the same call that sets the local value (SaveCooldownState / the DD engine),
// so adopting the GV never loses a lock that was just set here.
void RefreshSharedLockEnds()
{
   if(GlobalVariableCheck(GV_MKT_END))     g_mktCooldownEnd = (datetime)GlobalVariableGet(GV_MKT_END);
   if(GlobalVariableCheck(GV_BEH_END))     g_behCooldownEnd = (datetime)GlobalVariableGet(GV_BEH_END);
   if(GlobalVariableCheck(GV_DAILY_END))   g_dailyLockEnd   = (datetime)GlobalVariableGet(GV_DAILY_END);
   if(GlobalVariableCheck(GV_WEEKLY_END))  g_weeklyLockEnd  = (datetime)GlobalVariableGet(GV_WEEKLY_END);
   if(GlobalVariableCheck(GV_MONTHLY_END)) g_monthlyLockEnd = (datetime)GlobalVariableGet(GV_MONTHLY_END);
}

// v74.2 (HF3, B2, MT4 v101 BUG-054): "who processes this closed position" claim. Two charts on the same symbol
// (e.g. M1 + M5) both see the same ticket close; only the first to claim it runs the Market/Behavior
// classification, so the stop is counted ONCE. GlobalVariableSetOnCondition(…,1,0) is atomic.
string ClaimKey(ulong ticket) { return "RM_Claim_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + IntegerToString(ticket); }
bool ClaimClosedTicket(ulong ticket)
{
   string k = ClaimKey(ticket);
   if(!GlobalVariableCheck(k)) GlobalVariableSet(k, 0.0);
   return GlobalVariableSetOnCondition(k, 1.0, 0.0);
}

// v74.5 (HF5): claim جدا (کلید متفاوت از RM_Claim_ تا با claim بسته‌شدن همان تیکت قاطی نشود) برای
// «کدام چارت فعال‌شدن این پندینگ را پردازش می‌کند». دو چارت هر دو ممکنه همان پندینگ را ردیابی کنند
// (بعد از ری‌استارت/تغییر تایم‌فریم)؛ فقط اولی RunEntryIntervalCheck/شمارنده‌ها را اجرا می‌کند.
string PendClaimKey(ulong ticket) { return "RM_PendClaim_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + IntegerToString(ticket); }
bool ClaimPendingActivation(ulong ticket)
{
   string k = PendClaimKey(ticket);
   if(!GlobalVariableCheck(k)) GlobalVariableSet(k, 0.0);
   return GlobalVariableSetOnCondition(k, 1.0, 0.0);
}

// آرایه‌های ردیابی داخلی این ماژول - فقط توسط توابع همین فایل استفاده می‌شن
// (با grep در همه‌ی فایل‌ها تأیید شد)، برخلاف g_weeklyLockEnd/g_monthlyLockEnd/
// g_mktCooldownEnd/g_behCooldownEnd که چون RM_Dashboard.mqh (و g_mktCooldownEnd
// همچنین RM_TradeExecution.mqh) هم مستقیم بهشون دسترسی دارن، در فایل اصلی می‌مونن.
// v9.8: ردیابی پندینگ‌های ثبت‌شده تا لحظه‌ی فعال‌شدن واقعی‌شون (نه لحظه‌ی ثبت)
// [Stage 4] int -> ulong، همون دلیل هر جای دیگه‌ی این پورت.
ulong    g_pendingTrackTickets[];
int      g_pendingTrackCount = 0;
// track open trades for manual close detection
ulong    g_trackedTickets[];
double   g_trackedSL[];
double   g_trackedEntry[];
bool     g_trackedBuy[];
// [Stage 4 - part of the CheckClosedTrades() mapping decision above] two NEW tracked arrays -
// MT5 deals don't carry TP/volume, so these are captured live (same pattern as g_trackedSL)
// while the position is still open, for use once it's gone.
double   g_trackedTP[];
double   g_trackedLots[];
int      g_trackedCount = 0;

// v62 (تفکیک ExitReason - EmergencyClose در برابر خروج دستی): آرایه‌ی موقت که EmergencyCloseAll()
// (فایل اصلی .mq4) درست قبل از بستن هر پوزیشن، تیکتش رو بهش اضافه می‌کنه - هیچ تغییری در منطق
// خودِ EmergencyCloseAll() (چی رو کِی می‌بنده) داده نشده. CheckClosedTrades() پایین‌تر، توی همون
// لحظه‌ای که بسته‌شدن هر تیکت رو تشخیص می‌ده، حضورش توی این آرایه رو چک می‌کنه (ConsumeEmergencyClosedTicket)
// و اگه بود، پرچم persisted (GlobalVariable، چون Export CSV ممکنه خیلی بعدتر/بعد از ری‌استارت
// صدا زده بشه) رو با MarkEmergencyClosed ثبت می‌کنه - جدا و مستقل از منطق موجود شمارش
// Market/Behavior Cooldown (که دست‌نخورده می‌مونه).
ulong    g_emergencyClosedTickets[];
int      g_emergencyClosedCount = 0;

// اگه این تیکت توی آرایه‌ی بالا باشه، حذفش می‌کنه و true برمی‌گردونه (مصرفِ یک‌باره - هر تیکت
// فقط یک‌بار توسط CheckClosedTrades پردازش می‌شه، پس نیازی به موندنش توی آرایه بعد از اون نیست)
bool ConsumeEmergencyClosedTicket(ulong ticket)
{
   for(int i=0;i<g_emergencyClosedCount;i++)
   {
      if(g_emergencyClosedTickets[i]==ticket)
      {
         g_emergencyClosedTickets[i] = g_emergencyClosedTickets[g_emergencyClosedCount-1];
         ArrayResize(g_emergencyClosedTickets, g_emergencyClosedCount-1);
         g_emergencyClosedCount--;
         return true;
      }
   }
   return false;
}

// پرچم persisted (نه فقط حافظه‌ی موقت) - چون ExportTradeJournalCSV() (RM_Reports.mqh) ممکنه
// خیلی بعدتر، حتی بعد از ری‌استارت EA، صدا زده بشه؛ آرایه‌ی بالا با ری‌استارت پاک می‌شد ولی این
// GlobalVariable نه.
void MarkEmergencyClosed(ulong ticket)
{
   GlobalVariableSet("RM_EMERGENCY_" + IntegerToString(ticket), 1.0);
   GlobalVariablesFlush();   // v74.6 (HF6b)
}

bool WasEmergencyClosed(ulong ticket)
{
   return GlobalVariableCheck("RM_EMERGENCY_" + IntegerToString(ticket));
}

// v75.9 (پورت MT4 v82 BUG-052/FEAT-036): Spread_AtClose. تاریخچه‌ی MT5 هم اسپرد لحظه‌ی بسته‌شدن را ندارد؛ تنها لحظه‌ی قابل‌ثبت
// همان لحظه‌ای است که CheckClosedTrades بسته‌شدن را تشخیص می‌دهد. در GlobalVariable ذخیره می‌شود (نه حافظه) تا بعد از ری‌استارت
// EA هم برای Export در دسترس باشد؛ کلید با حساب و Magic مثل MT4.
string SpreadAtCloseKey(ulong ticket)
{
   return "RM_SPREADCLOSE_A" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + IntegerToString(ticket);
}
void RecordSpreadAtClose(ulong ticket, double spreadPrice)
{
   GlobalVariableSet(SpreadAtCloseKey(ticket), spreadPrice);
}
bool GetSpreadAtClose(ulong ticket, double &spreadOut)
{
   string key = SpreadAtCloseKey(ticket);
   if(!GlobalVariableCheck(key)) return false;
   spreadOut = GlobalVariableGet(key);
   return true;
}

// v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله): نسخه‌ی read-only (بدون تغییر state) از شرط
// تخلف Entry Interval - دقیقاً همون شرط داخل RunEntryIntervalCheck زیر، فقط بدون
// عوض‌کردن g_lastEntryTime/شمارنده‌ها. برای Snapshot لحظه‌ی باز شدن معامله (EntryIntervalViolation)
// باید بدونیم «آیا همین الان تخلفه» بدون این‌که خودِ محاسبه رو انجام بدیم (اون یک‌بار دیگه،
// بلافاصله بعدش، توسط خود RunEntryIntervalCheck واقعی انجام می‌شه).
bool WouldViolateEntryInterval()
{
   if(!EnableEntryInterval || MinEntryIntervalMinutes<=0 || g_lastEntryTime<=0) return false;
   int elapsedMin = (int)((TimeCurrent() - g_lastEntryTime)/60);
   return (elapsedMin < MinEntryIntervalMinutes);
}

// v61: نسخه‌ی read-only - آیا همین الان یک قفل Cooldown (Market یا Behavior) فعاله؟ عمداً
// فقط Cooldown (نه DD Lock) - دقیقاً هم‌معنی نام فیلد OpenedDuringCooldownLock.
bool IsCooldownLockActiveNow()
{
   if(g_mktCooldownEnd > 0 && TimeCurrent() < g_mktCooldownEnd) return true;
   if(g_behCooldownEnd > 0 && TimeCurrent() < g_behCooldownEnd) return true;
   return false;
}

// v9.8: این تابع فقط زمانی صدا زده می‌شه که یک ستاپ واقعاً «فعال» شده باشه
// (پر شدن مارکت در لحظه، یا فعال‌شدن یک پندینگ بعداً) - نه لحظه‌ی صرفِ ثبت پندینگ
// v75.13 (MT4 v90 FEAT-044): پارامتر exempt (پیش‌فرض false = رفتار قبلی). ورود ادامه (Scale-in) -> هیچ Strike‌ای نمی‌گیرد و g_lastEntryTime هم
// به‌روز نمی‌شود (تا معامله‌ی مستقل بعدی به‌خاطر آن Strike نگیرد).
void RunEntryIntervalCheck(bool exempt=false)
{
   if(exempt) return;
   datetime nowEntry = TimeCurrent();
   if(EnableEntryInterval && MinEntryIntervalMinutes>0 && g_lastEntryTime>0)
   {
      int elapsedMin = (int)((nowEntry - g_lastEntryTime)/60);
      if(elapsedMin < MinEntryIntervalMinutes)
      {
         // v53: افزایش امن (CAS) روی شمارنده‌ی مشترک بین چارت‌ها - مقدار برگشتی، مقدار
         // واقعی‌ای‌ست که نوشته شد (نه g_behCount کهنه‌ی محلی + 1)
         int behBeforeEI = g_behCount; // v65 (DEBUG-BEHCOUNT - آیتم ۲): مقدار محلیِ قبل از تغییر
         g_behCount = (int)MathRound(CAS_AddToGlobal(GV_BEH_COUNT, 1.0));
         Print("[DEBUG-BEHCOUNT] Strike | ticket=N/A (EntryInterval) | before="+IntegerToString(behBeforeEI)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
         // v61: همین رویداد (تخلف Entry Interval) یک واحد به شمارنده‌ی یکپارچه‌ی رفتاری هم
         // اضافه می‌شه - مستقل از این‌که همین الان Behavior Cooldown هم قفل بزنه یا نه.
         IncrementBehaviorErrorTotal();
         if(EnableBehaviorCD && g_behCount >= BehaviorCDCount && g_behCooldownEnd == 0)
         {
            g_behCooldownEnd = nowEntry + BehaviorCDHours*3600;
            int behBeforeEILock = g_behCount; // v65 (DEBUG-BEHCOUNT)
            g_behCount       = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
            Print("[DEBUG-BEHCOUNT] Reset (Lock) | ticket=N/A (EntryInterval) | before="+IntegerToString(behBeforeEILock)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
         }
         Alert("RM: Entry interval "+IntegerToString(elapsedMin)+"min < min "+IntegerToString(MinEntryIntervalMinutes)+"min - Behavior strike");
      }
   }
   g_lastEntryTime = nowEntry;
   SaveCooldownState();
}

// v9.8: اضافه کردن یک تیکت پندینگ به لیست انتظار برای فعال‌شدن
void AddPendingTrack(ulong ticket)
{
   ArrayResize(g_pendingTrackTickets, g_pendingTrackCount+1);
   g_pendingTrackTickets[g_pendingTrackCount] = ticket;
   g_pendingTrackCount++;
}

void RemovePendingTrackAt(int idx)
{
   for(int k=idx; k<g_pendingTrackCount-1; k++)
      g_pendingTrackTickets[k] = g_pendingTrackTickets[k+1];
   g_pendingTrackCount--;
   ArrayResize(g_pendingTrackTickets, g_pendingTrackCount);
}

// === v75.13 (MT4 v87/v90 FEAT-042/044): Market Cooldown زنجیره‌ای + مدیریت Pending ورود ادامه ===
#define CHAIN_MKT_MIN_LOSS_R 0.10
string ChainKeyScope() { return "A" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_"; }

// وقتی همه‌ی اعضای زنجیره بسته شدند، Market Cooldown یک‌بار بر اساس «برایند کل زنجیره» (نه تک‌پوزیشن) ارزیابی می‌شود.
// برایند منفی‌تر از -0.1R = یک «استاپ بازار» به اندازه‌ی min(1,|R|) x RiskWeight. پایه‌ی R همیشه RiskBase ریشه است.
// fromPendingGone=true: یک ورود ادامه‌ی Pending بدون پر شدن از زنجیره جدا شد؛ فقط اگر هدف قبلاً با SL بسته و «به تعویق افتاده» (کلید RM_CHAINDEFER_) باشد ارزیابی می‌شود.
void ProcessChainMarketStop(ulong tk, bool fromPendingGone=false)
{
   ulong root = GetRootTicket(tk);
   string deferKey = "RM_CHAINDEFER_" + ChainKeyScope() + IntegerToString(root);
   if(fromPendingGone)
   {
      if(!GlobalVariableCheck(deferKey)) return;
   }
   else if(ChainMemberCount(root) <= 1) return;      // معامله‌ی تکی - قانون قبلی (hitSL) قبلاً اعمال شده
   if(!IsChainFullyClosed(root)) return;             // منتظر آخرین بخش
   string doneKey = "RM_CHAINMKT_" + ChainKeyScope() + IntegerToString(root);
   if(GlobalVariableCheck(doneKey))
   {
      Print("[RM-CHAIN] chain #", root, " stop skipped (already counted)");
      return;
   }

   double   netUSD = 0.0;
   datetime lastClose = 0;
   int      idxRisk = -1;
   for(int m=0;m<g_snapCount;m++)
   {
      ulong rm = (g_snapRootTicket[m] > 0) ? g_snapRootTicket[m] : g_snapTickets[m];
      if(rm != root) continue;
      if(!HistorySelectByPosition(g_snapTickets[m]))
      {
         Print("RM WARNING: ProcessChainMarketStop - chain root #", root, " member #", g_snapTickets[m], " history not readable; chain Market Cooldown NOT evaluated");
         return;
      }
      int nd = HistoryDealsTotal();
      bool hasIn = false, hasOut = false; double memNet = 0; datetime memLast = 0;
      for(int d=0; d<nd; d++)
      {
         ulong dk = HistoryDealGetTicket(d);
         if(dk==0) continue;
         long en = HistoryDealGetInteger(dk, DEAL_ENTRY);
         if(en==DEAL_ENTRY_IN) hasIn = true;
         if(en==DEAL_ENTRY_OUT)
         {
            hasOut = true;
            memNet += HistoryDealGetDouble(dk, DEAL_PROFIT) + HistoryDealGetDouble(dk, DEAL_SWAP) + HistoryDealGetDouble(dk, DEAL_COMMISSION);
            datetime dt = (datetime)HistoryDealGetInteger(dk, DEAL_TIME);
            if(dt > memLast) memLast = dt;
         }
      }
      if(!hasIn) continue;                    // ورود ادامه‌ی Pending که هیچ‌وقت پر نشد (سود/ریسک ندارد)
      if(!hasOut)
      {
         Print("RM WARNING: ProcessChainMarketStop - chain root #", root, " member #", g_snapTickets[m], " has no closing deal yet; chain Market Cooldown NOT evaluated");
         return;
      }
      netUSD += memNet;
      if(memLast > lastClose) lastClose = memLast;
      if(idxRisk < 0 && g_snapRiskUSD[m] > 0) idxRisk = m;
   }
   int idxRootSnap = FindSnapshotIndex(root);
   if(idxRootSnap >= 0 && SnapRiskBase(idxRootSnap) > 0) idxRisk = idxRootSnap;
   else if(idxRisk >= 0) Print("RM WARNING: ProcessChainMarketStop - root #", root, " Snapshot missing/zero risk; falling back to first member with risk");

   // claim اتمیک: هر نتیجه‌ای (استاپ یا نه) فقط یک‌بار ثبت می‌شود (دو چارت هم‌نماد همزمان ارزیابی نکنند)
   if(!GlobalVariableCheck(doneKey)) GlobalVariableSet(doneKey, 0.0);
   if(!GlobalVariableSetOnCondition(doneKey, 1.0, 0.0))
   {
      Print("[RM-CHAIN] chain #", root, " stop skipped (claimed by another chart)");
      return;
   }
   if(idxRisk < 0)
   {
      Print("RM WARNING: ProcessChainMarketStop - chain root #", root, " has no RiskUSD in any Snapshot; chain Market Cooldown NOT evaluated");
      return;
   }
   double netR = netUSD / SnapRiskBase(idxRisk);
   if(netR >= -CHAIN_MKT_MIN_LOSS_R)
   {
      Print("RM: chain #", root, " closed, net ", DoubleToString(netR,2), "R (> -", DoubleToString(CHAIN_MKT_MIN_LOSS_R,2), "R) - not a Market stop");
      return;
   }
   double inc = MathMin(1.0, -netR) * SnapRiskWeight(idxRisk);
   g_mktStopCount = CAS_AddToGlobal(GV_MKT_COUNT, inc);
   g_lastStopCloseTime = lastClose;
   CAS_SetGlobal(GV_LAST_STOP_CLOSE, (double)g_lastStopCloseTime);
   if(EnableMarketCD && g_mktStopCount >= MarketCDCount && g_mktCooldownEnd == 0)
   {
      g_mktCooldownEnd = TimeCurrent() + MarketCDHours*3600;
      g_mktStopCount   = CAS_SetGlobal(GV_MKT_COUNT, 0.0);
      g_lastStopCloseTime = 0;
      CAS_SetGlobal(GV_LAST_STOP_CLOSE, 0.0);
   }
   SaveCooldownState();
   Print("RM: chain #", root, " closed, net ", DoubleToString(netR,2), "R -> Market stop +", DoubleToString(inc,3));
}

// یک ورود ادامه‌ی Pending بدون پر شدن حذف/منقضی شد. هیچ اثر رفتاری ندارد؛ فقط از زنجیره جدا می‌شود (ریشه = خودش) تا زنجیره‌ی هدف بدون آن
// ارزیابی شود. اگر هدف در فاصله‌ی انتظار با SL بسته و Market Cooldown آن به تعویق افتاده بود، همین‌جا ارزیابی عقب‌افتاده انجام می‌شود.
void HandleVanishedContinuationPending(ulong tk)
{
   int idx = FindSnapshotIndex(tk);
   if(idx < 0 || !g_snapIsContinuation[idx]) return;
   ulong root = GetRootTicket(tk);
   if(root == tk) return;                 // قبلاً جدا شده
   DetachSnapshotRoot(tk);
   Print("RM: Scale-in pending #", tk, " vanished without fill - detached from chain #", root);
   ProcessChainMarketStop(root, true);
}

// وقتی همه‌ی بخش‌های بازِ زنجیره بسته شدند، Pending ادامه‌ی پرنشده دلیلی برای ماندن ندارد و خودکار حذف می‌شود
// (فقط Pending علامت‌خورده به‌عنوان ادامه و متصل به ریشه؛ Pending عادی دست‌نخورده).
void CancelOrphanContinuationPendings()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if(!IsContinuationTicket(tk)) continue;
      ulong root = GetRootTicket(tk);
      if(root == tk) continue;
      bool anyOpen = false;
      for(int j=PositionsTotal()-1; j>=0; j--)
      {
         ulong pt = PositionGetTicket(j);
         if(pt == 0) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(GetRootTicket(pt) == root){ anyOpen = true; break; }
      }
      if(anyOpen) continue;
      if(RM_RemovePendingOrder(tk))
      {
         Print("RM: Scale-in pending #", tk, " auto-cancelled - chain #", root, " has no open part left");
         HandleVanishedContinuationPending(tk);
         DropPendingSnapshot(tk);
      }
      else
         Print("RM: Scale-in pending #", tk, " auto-cancel FAILED");
   }
}

// v9.8: هر تیک چک می‌کنه آیا یکی از پندینگ‌های ردیابی‌شده فعال (پر) شده یا حذف/منقضی شده
// [Stage 4] MT4's combined order list (pendings + positions together, OrderSelect(ticket,
// SELECT_BY_TICKET) works for both while pending) has no single MT5 equivalent - a pending order
// and the position it becomes are two different lists in MT5. Translation: first check
// PositionSelectByTicket(tk) (did it activate into a position - matches OrderType()==OP_BUY/
// OP_SELL below); if not a position, check OrderSelect(tk) (MT5's pending-order select, not
// history) to see if it's still a live pending order (still waiting, matches the original's
// implicit "else, still pending" fall-through); if neither, it's gone (deleted/expired before
// activating) - matches the original's OrderCloseTime()>0 branch (MT4 marks a cancelled/expired
// pending as "closed" in its unified history; MT5 has no history record for a pending that never
// filled, it simply stops existing in the pending list, so "not found anywhere" is the correct
// MT5-native equivalent of that branch).
void CheckPendingActivation()
{
   for(int i=g_pendingTrackCount-1; i>=0; i--)
   {
      ulong tk = g_pendingTrackTickets[i];

      if(PositionSelectByTicket(tk))
      {
         // v74.5 (HF5): فقط یک چارت فعال‌شدن را پردازش می‌کند؛ بقیه فقط ردیابی خودشان را پاک می‌کنند.
         if(!ClaimPendingActivation(tk))
         {
            RemovePendingTrackAt(i);
            continue;
         }
         // v74.5 (HF5): پندینگ‌های ثبت‌شده قبل از HF5 (یا Snapshot گم‌شده) placement-snapshot ندارند؛ از روی
         // خود پوزیشن ساخته می‌شود (WasHalfRisk نامعلوم = false). بدون این، Snapshot برای همیشه نمی‌ماند.
         bool pendFallback = false;
         if(FindSnapshotIndex(tk) < 0)
         {
            double fEntry = PositionGetDouble(POSITION_PRICE_OPEN);
            double fSL    = PositionGetDouble(POSITION_SL);
            if(fSL > 0)
            {
               double fPips    = MathAbs(fEntry-fSL)/(_Point*PipFactor());
               double fRiskUSD = fPips * GetPipValueForSymbol(_Symbol, _Point, PipFactor()) * PositionGetDouble(POSITION_VOLUME);
               double fBal     = AccountInfoDouble(ACCOUNT_BALANCE);
               SaveTradeSnapshot(tk, fEntry, fSL, fRiskUSD, (fBal>0) ? fRiskUSD/fBal*100.0 : 0, (datetime)PositionGetInteger(POSITION_TIME), (int)PositionGetInteger(POSITION_MAGIC), 0.0, false, false,
                                 0.0, false, false, false, 0.0, 0.0,
                                 -2.0, 0, -1.0, 0.0);
               pendFallback = true;
            }
         }
         // v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله): این همون لحظه‌ی «باز شدن واقعی» این
         // پندینگه (نه لحظه‌ی ثبتش در AutoExecute، که فقط placeholder گذاشته بود) - پس همین‌جا،
         // قبل از هر تغییر state (RunEntryIntervalCheck زیرش g_lastEntryTime/شمارنده‌ها رو
         // مستقیم عوض می‌کنه)، فیلدهای رفتاری Snapshot این تیکت با وضعیت زنده‌ی همین لحظه پر می‌شن.
         bool   isContinuationFill = IsContinuationTicket(tk);   // v75.13 (MT4 v90 FEAT-044)
         bool   duringLock      = IsCooldownLockActiveNow();
         bool   intervalViol    = isContinuationFill ? false : WouldViolateEntryInterval();
         double behErrAtOpen    = GetBehaviorErrorTotal();
         // v61 bugfix (BUG-048): همون فیکس AutoExecute (RM_TradeExecution.mqh) - این تیکت (tk)
         // خودش هم از قبل جزو OrdersTotal() است، پس با نسخه‌ی Excluding محاسبه می‌شه تا خودش
         // رو جزو «ریسک باز» حساب نکنه.
         double dailyPctAtOpen  = (g_effMaxDailyRisk>0) ? (GetDailyRiskExcludingTicket(tk)/g_effMaxDailyRisk*100.0)      : 0.0;
         double weeklyPctAtOpen = (g_effMaxWeeklyDD>0)  ? (GetWeeklyDrawdownExcludingTicket(tk)/g_effMaxWeeklyDD*100.0)  : 0.0;
         // v64 (آیتم ۱ - PriorDayResult): این همون لحظه‌ی «باز شدن واقعی» پندینگه - پس مقدار
         // زنده‌ی g_priorDayResultCode (نه placeholder ثبت‌شده در AutoExecute) همین‌جا خونده می‌شه.
         double priorDayResultAtOpen = g_priorDayResultCode;
         // v64 (آیتم ۶ - TimeframeAtOpen): این همون لحظه‌ی «باز شدن واقعی» پندینگه - تایم‌فریم
         // زنده‌ی چارت همین‌جا خونده می‌شه (نه لحظه‌ی ثبت اردر در AutoExecute).
         double timeframeAtOpen = (double)Period();
         SetSnapshotBehaviorFieldsAtActivation(tk, behErrAtOpen, duringLock, intervalViol, dailyPctAtOpen, weeklyPctAtOpen, priorDayResultAtOpen, timeframeAtOpen);
         if(FindSnapshotIndex(tk) >= 0)
            Print("[RM-PEND] snapshot "+(pendFallback ? "created for" : "completed at fill for")+" position #"+IntegerToString(tk)+
                  " (from order #"+IntegerToString(tk)+", source="+(pendFallback ? "fill-fallback: no placement data, built from the position" : "fill")+")");
         else
            Print("[RM-PEND] WARNING position #"+IntegerToString(tk)+" filled but has no snapshot (no SL on the position)");
         // v61: خودِ تخلف Entry Interval توسط RunEntryIntervalCheck زیر شمارش می‌شه (تا دوبار
         // شمرده نشه) - اینجا فقط رویداد «باز شدن وسط قفل Cooldown» که هیچ مسیر دیگه‌ای برای
         // شمارشش وجود نداره اضافه می‌شه.
         if(duringLock) IncrementBehaviorErrorTotal();

         // همین الان فعال شد - این لحظه‌ی واقعی ورود محسوب می‌شه
         RunEntryIntervalCheck(isContinuationFill);   // v75.13: ورود ادامه معاف
         PlaySound(SND_ORDER_FILLED);  // v45 (Punch List Round 3, Item 8)
         RemovePendingTrackAt(i);
      }
      else if(!OrderSelect(tk))
      {
         // قبل از فعال‌شدن حذف/منقضی شده (مثلاً Del Pending یا انقضای بروکر) - شمارش نمی‌شه
         // v74.5 (HF5): Snapshotِ زمان ثبت هم پاک می‌شود - ولی فقط اگر تاریخچه صراحتاً CANCELED/EXPIRED/
         // REJECTED بگوید. اگر FILLED است (پندینگ فعال و همان لحظه بسته شده، بین دو تیک) Snapshot لازم است
         // و CheckClosedTrades هنوز می‌خواهدش؛ اگر تاریخچه خوانده نشد هم نگه می‌داریم (محافظه‌کارانه).
         if(HistoryOrderSelect(tk))
         {
            ENUM_ORDER_STATE pendSt = (ENUM_ORDER_STATE)HistoryOrderGetInteger(tk, ORDER_STATE);
            if(pendSt==ORDER_STATE_CANCELED || pendSt==ORDER_STATE_EXPIRED || pendSt==ORDER_STATE_REJECTED)
            {
               HandleVanishedContinuationPending(tk);   // v75.13 (MT4 v90): قبل از حذف Snapshot (به پرچم ادامه و ریشه‌اش نیاز دارد)
               DropPendingSnapshot(tk);
               Print("[RM-PEND] pending order #"+IntegerToString(tk)+" ended without a fill ("+EnumToString(pendSt)+") - snapshot removed");
            }
         }
         RemovePendingTrackAt(i);
      }
      // در غیر این صورت هنوز پندینگه؛ صبر می‌کنیم
   }
}

// v74.5 (HF5): یک‌بار در OnInit (نه هر تیک): (۱) پندینگ‌های زنده‌ی این نماد/Magic که بعد از ری‌استارت یا
// تغییر تایم‌فریم از لیست ردیابی حافظه افتاده‌اند دوباره ثبت می‌شوند تا فعال‌شدنشان باز هم به
// CheckPendingActivation برسد. (۲) پوزیشن‌های بازی که Snapshotِ زمان ثبت دارند ولی فیلدهای «لحظه‌ی باز
// شدن» هنوز placeholder است (TimeframeAtOpen=0)، یعنی EA هنگام فعال‌شدن اجرا نبوده، فقط لاگ می‌شوند.
void RM_PendingResumeAtInit()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong ot = OrderGetTicket(i);
      if(ot == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      ENUM_ORDER_TYPE ty = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ty==ORDER_TYPE_BUY || ty==ORDER_TYPE_SELL) continue;
      bool known = false;
      for(int k=0; k<g_pendingTrackCount; k++) if(g_pendingTrackTickets[k]==ot) { known = true; break; }
      if(!known) AddPendingTrack(ot);
   }
   for(int p=PositionsTotal()-1; p>=0; p--)
   {
      ulong pt = PositionGetTicket(p);
      if(pt == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      int si = FindSnapshotIndexLocal(pt);
      if(si >= 0 && g_snapTimeframeAtOpen[si] == 0.0)
         Print("[RM-PEND] snapshot created for position #"+IntegerToString(pt)+" (from order #"+IntegerToString(pt)+", source=placement - behaviour-at-open fields are placeholders: the EA was not running at the fill)");
   }
}

// v18 (BUG-021) اصلاح‌شده: یک معامله ممکنه چند اقدام مدیریتی زودهنگام داشته باشه (مثلاً هم
// BE زودهنگام هم بعداً Half Close زودهنگام) - همه‌شون یک تصمیم رفتاری‌ان، نه چندتا. پس فقط
// اولین تخلف این معامله یک Behavior Strike واقعی ثبت می‌کنه؛ تخلف‌های بعدی همون معامله فقط
// لاگ می‌شن (Print)، بدون Strike اضافه. با بسته‌شدن معامله، چون تیکت جدید هیچ‌وقت تکرار
// نمی‌شه، معامله‌ی بعدی خودکار از صفر (Strike-پذیر) شروع می‌شه.
// v41 (BUG-018): استخراج‌شده از انتهای این تابع - منطق شمارش/قفل Behavior Cooldown
// (بدون هیچ تغییری در رفتار قبلی) حالا یه تابع مشترکه، چون CheckSLTampering هم باید دقیقاً
// از همون مسیر Strike اضافه کنه (نه یه شمارنده‌ی موازی جدید) - طبق خواسته‌ی صریح Mahmoud.
void AddBehaviorStrike(string reason)
{
   // v53: افزایش امن (CAS) روی شمارنده‌ی مشترک بین چارت‌ها
   int behBeforeABS = g_behCount; // v65 (DEBUG-BEHCOUNT - آیتم ۲): مقدار محلیِ قبل از تغییر
   g_behCount = (int)MathRound(CAS_AddToGlobal(GV_BEH_COUNT, 1.0));
   Print("[DEBUG-BEHCOUNT] Strike | reason="+reason+" | before="+IntegerToString(behBeforeABS)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
   if(EnableBehaviorCD && g_behCount >= BehaviorCDCount && g_behCooldownEnd == 0)
   {
      g_behCooldownEnd = TimeCurrent() + BehaviorCDHours*3600;
      int behBeforeABSLock = g_behCount; // v65 (DEBUG-BEHCOUNT)
      g_behCount       = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
      Print("[DEBUG-BEHCOUNT] Reset (Lock) | reason="+reason+" | before="+IntegerToString(behBeforeABSLock)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
   }
   SaveCooldownState();
   Alert("RM: "+reason+" - Behavior strike");
}

void CheckPrematureAction(ulong ticket, string actionTag)
{
   if(!IsPrematureBeforeOneR(ticket)) return;
   // v75.13 (MT4 v90 FEAT-044): ورود ادامه (Scale-in) از Strike اقدام زودهنگام معاف است
   if(IsContinuationTicket(ticket))
   {
      Print("RM: Premature "+actionTag+" (ticket #"+IntegerToString(ticket)+") - Scale-in continuation entry, exempt from Behavior strike");
      return;
   }

   if(IsAlreadyStrikedThisTrade(ticket))
   {
      Print("RM: Premature "+actionTag+" (ticket #"+IntegerToString(ticket)+") - trade already struck, no additional strike");
      return;
   }
   MarkStrikedThisTrade(ticket);
   AddBehaviorStrike("Premature "+actionTag+" before +1R (ticket #"+IntegerToString(ticket)+")");
}

// v53: GV_MKT_COUNT/GV_BEH_COUNT/GV_LAST_STOP_CLOSE دیگه اینجا با یه GlobalVariableSet ساده
// نوشته نمی‌شن - چون این سه‌تا حالا account-wide (مشترک بین چارت‌ها) هستن، یه "بنویس کل مقدار
// محلی من روشون" اینجا دقیقاً همون lost-update ای می‌شد که CAS قراره جلوش رو بگیره (مثلاً یه
// تغییر کاملاً بی‌ربط مثل SaveCooldownState() که از AddBehaviorStrike صدا زده می‌شه، می‌تونست
// شمارنده‌ی Market رو با یه کش محلی کهنه بازنویسی کنه). این سه‌تا حالا فقط از طریق
// CAS_AddToGlobal/CAS_SetGlobal (که خودشون بلافاصله می‌نویسن) و RefreshSharedCooldownState()
// (که همیشه زنده می‌خونه) مدیریت می‌شن. بقیه‌ی مقادیر (GV_MKT_END/GV_BEH_END/GV_LAST_ENTRY)
// دست‌نخورده‌ن - همچنان per-chart، همچنان با همین الگوی save/load ساده.
void SaveCooldownState()
{
   GlobalVariableSet(GV_MKT_END,   (double)g_mktCooldownEnd);
   GlobalVariableSet(GV_BEH_END,   (double)g_behCooldownEnd);
   GlobalVariableSet(GV_LAST_ENTRY,(double)g_lastEntryTime);
   GlobalVariablesFlush();   // v74.6 (HF6b)
}

void LoadCooldownState()
{
   if(GlobalVariableCheck(GV_MKT_END))   g_mktCooldownEnd = (datetime)GlobalVariableGet(GV_MKT_END);
   if(GlobalVariableCheck(GV_BEH_END))   g_behCooldownEnd  = (datetime)GlobalVariableGet(GV_BEH_END);
   if(GlobalVariableCheck(GV_LAST_ENTRY))g_lastEntryTime   = (datetime)GlobalVariableGet(GV_LAST_ENTRY);

   // v53: مقادیر مشترک (شمارنده‌ها + کمکی‌شون) رو زنده از GV مشترک بخون - نه از یه بلوک
   // GlobalVariableCheck/Get جدا که ممکنه دیگه با CAS هماهنگ نباشه
   RefreshSharedCooldownState();

   // reset if expired (این بخش صرفاً دفاعی/idempotent‌ه: شمارنده‌ی مشترک همون لحظه‌ای که
   // قفل شروع شد قبلاً صفر شده - lock timer اما همچنان per-chart‌ه، پس این چک اینجا فقط
   // برای این چارت مشخصه؛ صفر کردن شمارنده‌ی مشترک با CAS انجام می‌شه تا اگه واقعاً هنوز
   // غیرصفر مونده بود [مثلاً بعد از ری‌استارت EA]، درست و امن ریست بشه)
   datetime now = TimeCurrent();
   if(g_mktCooldownEnd > 0 && now >= g_mktCooldownEnd)
   {
      g_mktCooldownEnd = 0;
      g_mktStopCount      = CAS_SetGlobal(GV_MKT_COUNT, 0.0);
      g_lastStopCloseTime = (datetime)CAS_SetGlobal(GV_LAST_STOP_CLOSE, 0.0);
   }
   if(g_behCooldownEnd > 0 && now >= g_behCooldownEnd)
   {
      g_behCooldownEnd = 0;
      int behBeforeLoad = g_behCount; // v65 (DEBUG-BEHCOUNT - آیتم ۲)
      g_behCount = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
      Print("[DEBUG-BEHCOUNT] Reset (Time Expiry/Load) | ticket=N/A | before="+IntegerToString(behBeforeLoad)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
   }

   // v13 (BUG-017): apply the time-based streak reset immediately on load too,
   // in case the gap already elapsed while the EA/terminal was offline
   if(g_mktStopCount > 0 && g_lastStopCloseTime > 0 &&
      now - g_lastStopCloseTime >= MarketCDResetHours*3600)
   {
      g_mktStopCount      = CAS_SetGlobal(GV_MKT_COUNT, 0.0);
      g_lastStopCloseTime = (datetime)CAS_SetGlobal(GV_LAST_STOP_CLOSE, 0.0);
   }
}

void TrackOpenTrades()
{
   // add new trades
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;

      // v18 (BUG-021): هر تیک، برای هر معامله‌ی باز با Snapshot معتبر، بالاترین R لمس‌شده
      // به‌روزرسانی می‌شه - چه تیکت جدید باشه چه از قبل ردیابی می‌شده. سفارش همین الان
      // انتخاب‌شده‌ست (OrderSelect بالا)، پس نیازی به select دوباره نیست.
      UpdateSnapshotMaxFavorableR(tk);
      // v66 (آیتم ۲ب): قرینه‌ی MAE - همون لحظه، همون تیکت انتخاب‌شده، بدون OrderSelect اضافه.
      UpdateSnapshotMinFavorableR(tk);

      bool found = false;
      for(int j=0;j<g_trackedCount;j++)
      {
         if(g_trackedTickets[j]==tk)
         {
            // v3 (BUG-005 fix): اگه SL دستی جابه‌جا شده، مقدار ردیابی‌شده رو با SL زنده sync کن
            // تا تشخیص hitSL همیشه بر اساس آخرین SL باشه، نه SL لحظه‌ی باز شدن معامله
            g_trackedSL[j] = PositionGetDouble(POSITION_SL);
            // [Stage 4] TP/Lots هم هر تیک sync می‌شن - همون دلیل SL بالا؛ لازمه چون بعد از
            // بسته‌شدن پوزیشن دیگه از هیچ Deal ای قابل‌خوندن نیستن (بخش بالای فایل رو ببین).
            g_trackedTP[j]   = PositionGetDouble(POSITION_TP);
            g_trackedLots[j] = PositionGetDouble(POSITION_VOLUME);
            found=true;
            break;
         }
      }
      if(!found)
      {
         ArrayResize(g_trackedTickets, g_trackedCount+1);
         ArrayResize(g_trackedSL,      g_trackedCount+1);
         ArrayResize(g_trackedEntry,   g_trackedCount+1);
         ArrayResize(g_trackedBuy,     g_trackedCount+1);
         ArrayResize(g_trackedTP,      g_trackedCount+1);
         ArrayResize(g_trackedLots,    g_trackedCount+1);
         g_trackedTickets[g_trackedCount] = tk;
         g_trackedSL[g_trackedCount]      = PositionGetDouble(POSITION_SL);
         g_trackedEntry[g_trackedCount]   = PositionGetDouble(POSITION_PRICE_OPEN);
         g_trackedBuy[g_trackedCount]     = (posType==POSITION_TYPE_BUY);
         g_trackedTP[g_trackedCount]      = PositionGetDouble(POSITION_TP);
         g_trackedLots[g_trackedCount]    = PositionGetDouble(POSITION_VOLUME);
         g_trackedCount++;
      }
   }
}

//+------------------------------------------------------------------+
// v75.0 (P0): بازیابی بسته‌شدن‌های پردازش‌نشده هنگام شروع EA.
// فهرست g_trackedTickets فقط در حافظه است؛ اگر پوزیشنی وقتی EA خاموش/در حال ری‌استارت بود بسته شود، هرگز
// طبقه‌بندی نمی‌شد (نه Strike، نه شمارنده، نه CSV). این تابع یک‌بار در OnInit تاریخچه‌ی ۴۸ ساعت اخیر را می‌گردد و
// هر پوزیشنِ بسته‌شده‌ی همین نماد را که (۱) Snapshot دارد (یعنی معامله‌ی خود EA بوده)، (۲) claim ندارد (یعنی هیچ
// چارتی پردازشش نکرده)، به g_trackedTickets اضافه می‌کند تا CheckClosedTrades همان مسیر عادی را روی آن اجرا کند
// (خودش claim می‌گیرد، پس دوباره‌شماری ممکن نیست). محدودیت: SL «آخرین» قبل از بسته‌شدن از DEAL_SL دیل خروج
// خوانده می‌شود (ثبت‌شده‌ی خود بروکر)، نه از ردیابی زنده.
//+------------------------------------------------------------------+
void RM_ReconcileClosedAtInit()
{
   datetime now = TimeCurrent();
   if(!HistorySelect(now - 48*3600, now + 60)) return;
   int total = HistoryDealsTotal();
   ulong posIds[]; int pc = 0;
   for(int i=total-1;i>=0;i--)
   {
      ulong dt = HistoryDealGetTicket(i);
      if(dt==0) continue;
      if(HistoryDealGetInteger(dt, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      if(HistoryDealGetString(dt, DEAL_SYMBOL)!=_Symbol) continue;
      ulong pid = (ulong)HistoryDealGetInteger(dt, DEAL_POSITION_ID);
      if(pid==0) continue;
      bool dup=false;
      for(int q=0;q<pc;q++) if(posIds[q]==pid){dup=true;break;}
      if(dup) continue;
      ArrayResize(posIds, pc+1); posIds[pc]=pid; pc++;
   }
   int added = 0;
   for(int p=0;p<pc;p++)
   {
      ulong pid = posIds[p];
      if(PositionSelectByTicket(pid)) continue;                        // هنوز باز است
      if(GlobalVariableCheck(ClaimKey(pid))) continue;                 // قبلاً پردازش شده
      if(FindSnapshotIndex(pid) < 0) continue;                         // معامله‌ی خود EA نیست / Snapshot ندارد
      bool already=false;
      for(int j=0;j<g_trackedCount;j++) if(g_trackedTickets[j]==pid){already=true;break;}
      if(already) continue;
      if(!HistorySelectByPosition(pid)) continue;
      int dn = HistoryDealsTotal();
      double entry=0, lots=0, sl=0, tp=0; bool isBuy=true; bool haveIn=false; datetime lastOut=-1;
      for(int d=0; d<dn; d++)
      {
         ulong dk = HistoryDealGetTicket(d);
         if(dk==0) continue;
         long en = HistoryDealGetInteger(dk, DEAL_ENTRY);
         if(en==DEAL_ENTRY_IN && !haveIn)
         {
            haveIn = true;
            entry  = HistoryDealGetDouble(dk, DEAL_PRICE);
            lots   = HistoryDealGetDouble(dk, DEAL_VOLUME);
            isBuy  = (HistoryDealGetInteger(dk, DEAL_TYPE)==DEAL_TYPE_BUY);
         }
         else if(en==DEAL_ENTRY_OUT)
         {
            datetime t = (datetime)HistoryDealGetInteger(dk, DEAL_TIME);
            if(t>=lastOut){ lastOut=t; sl=HistoryDealGetDouble(dk, DEAL_SL); tp=HistoryDealGetDouble(dk, DEAL_TP); }
         }
      }
      if(!haveIn) continue;
      ArrayResize(g_trackedTickets, g_trackedCount+1);
      ArrayResize(g_trackedSL,      g_trackedCount+1);
      ArrayResize(g_trackedEntry,   g_trackedCount+1);
      ArrayResize(g_trackedBuy,     g_trackedCount+1);
      ArrayResize(g_trackedTP,      g_trackedCount+1);
      ArrayResize(g_trackedLots,    g_trackedCount+1);
      g_trackedTickets[g_trackedCount] = pid;
      g_trackedSL[g_trackedCount]      = sl;
      g_trackedEntry[g_trackedCount]   = entry;
      g_trackedBuy[g_trackedCount]     = isBuy;
      g_trackedTP[g_trackedCount]      = tp;
      g_trackedLots[g_trackedCount]    = lots;
      g_trackedCount++;
      added++;
      Print("[RM-RECON] closed-while-off pos=#"+IntegerToString(pid)+" queued for classification on "+_Symbol);
   }
   if(added>0) Print("[RM-RECON] "+IntegerToString(added)+" unprocessed closed position(s) queued at init");
}

//+------------------------------------------------------------------+
// Check closed trades since last tick
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   TrackOpenTrades();

   // v68 (Auto Export CSV - export بعد از close): مستقل از حلقه‌ی پایین که ممکنه چند تیکت رو
   // توی یه تیک واحد ببنده (مثلاً بعد از یه گپ قیمتی) - export فقط یک‌بار در انتهای این تابع
   // انجام می‌شه، نه به ازای هر تیکت جداگانه.
   bool anyClosedThisTick = false;

   for(int j=g_trackedCount-1;j>=0;j--)
   {
      ulong tk = g_trackedTickets[j];
      // check if still open - [Stage 4] PositionSelectByTicket directly answers this on MT5
      // (see the mapping-decision header comment, point 1) - no need for the MT4-style manual
      // loop-and-compare, since MT5 offers a direct select-by-ticket for positions.
      bool stillOpen = PositionSelectByTicket(tk);
      if(stillOpen) continue;

      anyClosedThisTick = true;  // v68

      // v8 (BUG-009 fix #2): همین لحظه (هر تیک) که بسته‌شدن تشخیص داده شد، اگه این
      // تیکت زیر پوشش Trailing بود از لیست حذف بشه - معطل کندل بعدی نمونه
      RemoveTrailTicket(tk);

      // v40 (FEAT-019): همین‌جا، اگه این تیکت توی لیست «قبلاً Auto Half Close شده» بود،
      // هم پاک بشه - تیکت‌ها در MT4 هیچ‌وقت تکرار نمی‌شن، پس این فقط برای جلوگیری از رشد
      // بی‌رویه‌ی آرایه در طول عمر طولانی EA لازمه (مثل RemoveTrailTicket بالا)
      RemoveAutoHalfDone(tk);

      // v41 (BUG-018): همین‌جا، اگه این تیکت توی لیست ردیابی SL=0 (grace period) بود، هم
      // پاک بشه - همون دلیل بالا (جلوگیری از رشد بی‌رویه‌ی آرایه با تیکت‌های بسته‌شده)
      RemoveSLZeroTicket(tk);

      // v41 (Mahmoud feedback): همین‌جا، ردیابی «آخرین SL معتبر» این تیکت هم پاک می‌شه - همون دلیل بالا
      RemoveLastSLTicket(tk);

      // v8 (BUG-010): همین لحظه که بسته‌شدن معامله تشخیص داده شد، خط‌های Trailing/BE
      // مربوط به این تیکت (اگه وجود داشته باشن) پاک می‌شن
      ObjectDelete(0, TrailLineName(tk));
      ObjectDelete(0, BELineName(tk));

      // v40 (Mahmoud feedback): خط‌ها/لیبل‌های پیش‌نمایش Auto Half Close/Trailing این تیکت هم
      // همین‌جا پاک می‌شن - وگرنه تا تیک بعدی روی چارت باقی می‌موندن
      ObjectDelete(0, AutoHalfPreviewLineName(tk));
      ObjectDelete(0, AutoHalfPreviewLabelName(tk));
      ObjectDelete(0, AutoTrailPreviewLineName(tk));
      ObjectDelete(0, AutoTrailPreviewLabelName(tk));
      // v48 (فیچر جدید): خط پیش‌نمایش Auto BE هم همون‌جا/همون دلیل پاک می‌شه - هم‌خانواده‌ی
      // دو خط بالا.
      ObjectDelete(0, BEPreviewLineName(tk));
      ObjectDelete(0, BEPreviewLabelName(tk));

      // v74.1 (HF1 A1): the object sweep + ChartRedraw moved below, after the closing deal is confirmed
      // in history, so a not-yet-ready history no longer repeats them on every tick.

      // closed - read history
      // [Stage 4 - mapping decision, point 3] HistorySelectByPosition() loads every deal under
      // this position ID; we then find the LAST DEAL_ENTRY_OUT deal for close price/time, and sum
      // profit+swap+commission across ALL OUT deals for the total realized result. See the header
      // comment at the top of this file for the full reasoning.
      //
      // [Stage 4 bug found via live testing, fixed] The closing deal's DEAL_MAGIC is NOT reliable
      // for filtering - a position closed MANUALLY from the terminal (not through this EA's own
      // close buttons) generates a closing deal with a different magic (commonly 0, "no EA"), not
      // the position's original magic. Checking DEAL_MAGIC on the OUT deal here would silently
      // strand every manually-closed ticket in g_trackedTickets forever (confirmed live: 3 manually
      // -closed test positions all stuck at "still tracked" until this filter was removed). This
      // check is also redundant regardless: tk only ever enters g_trackedTickets via
      // TrackOpenTrades(), which already filtered on POSITION_MAGIC while the position was open -
      // by the time we get here, we already know this ticket is ours. Filtering by symbol on the
      // closing deal is kept (harmless, and DEAL_SYMBOL is reliable regardless of who closed it).
      if(!HistorySelectByPosition(tk)) continue;
      int dealsTotal = HistoryDealsTotal();
      if(dealsTotal<=0) continue;

      double sumProfit = 0;
      double closePrice = 0;
      datetime closeTimeVal = 0, latestOutTime = -1;
      string dealSymbol = "";
      bool foundOut = false;
      for(int d=0; d<dealsTotal; d++)
      {
         ulong dealTicket = HistoryDealGetTicket(d);
         if(dealTicket==0) continue;
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue; // skip the opening (IN) deal
         sumProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         datetime dTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         if(dTime >= latestOutTime)
         {
            latestOutTime      = dTime;
            closeTimeVal        = dTime;
            closePrice          = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            dealSymbol          = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            foundOut            = true;
         }
      }
      if(!foundOut) continue;
      if(dealSymbol!=_Symbol) continue;

      // v74.1 (HF1 A1): moved here from above (runs once, when the closed position is actually processed)
      // v8 (BUG-010 fix #2): آبجکت‌های خودکار خود MT4 مربوط به این تیکت هم پاک بشن
      // (مثل فلش/خط "#تیکت sl modified" که ترمینال موقع هر OrderModify خودش می‌سازه)
      string tickStrClosed = "#"+IntegerToString(tk);
      for(int oi=ObjectsTotal(0)-1; oi>=0; oi--)
      {
         string objNameClosed = ObjectName(0,oi);
         if(StringFind(objNameClosed, tickStrClosed) >= 0)
            ObjectDelete(0, objNameClosed);
      }
      ChartRedraw();

      // v62 (تفکیک ExitReason - EmergencyClose): همین‌جا، قبل از هر منطق طبقه‌بندی/شمارش موجود
      // (که دست‌نخورده می‌مونه)، فقط چک می‌کنیم آیا این تیکت توسط EmergencyCloseAll بسته شده -
      // اگه بله، پرچم persisted ثبت می‌شه تا بعداً ExportTradeJournalCSV بتونه Result رو
      // "EmergencyClose" بنویسه به‌جای EarlyExit. هیچ اثری روی hitSL/hitTP/شمارنده‌های
      // Market-Behavior Cooldown زیر این بلوک نداره.
      if(ConsumeEmergencyClosedTicket(tk))
         MarkEmergencyClosed(tk);
      // v74.4 (HF4): emergency-closed trade = protective action by the EA, not trader behavior.
      // The flag is the GV set by EmergencyCloseAll() before closing, so it is also seen by the
      // chart that owns the position's symbol when another chart fired the emergency.
      bool wasEmergency = WasEmergencyClosed(tk);

      // v59 (Item 2 - Chart Screenshot at Exit): همین لحظه‌ای که بسته‌شدن این تیکت تشخیص داده شد -
      // Exit، نه Entry - از وضعیت فعلی چارت عکس گرفته می‌شه (RM_Tools.mqh)
      TakeExitScreenshot(tk);

      // v75.9 (MT4 v82 FEAT-036): اسپرد زنده‌ی همین لحظه (Ask-Bid) = بهترین تخمین «اسپرد لحظه‌ی بسته‌شدن». فقط ثبت؛ اثری روی منطق زیر ندارد.
      RecordSpreadAtClose(tk, SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID));

      double openPrice  = g_trackedEntry[j];
      double slPrice    = g_trackedSL[j];
      bool   isBuy      = g_trackedBuy[j];
      // closePrice/profit already computed above from the deal history (mapping decision, point 3)
      double profit     = sumProfit;

      // v17 (BUG-013 + BUG-020 fix): classification base changed from the CURRENT
      // SL distance (g_trackedSL, which shrinks toward zero once Break Even or
      // Trailing moves the stop near entry) to the Initial Risk ($) recorded in
      // this ticket's Trade Snapshot at open time (v11, FEAT-016). The Snapshot
      // value never changes with BE/Trailing/manual SL edits, so it stays a
      // meaningful definition of "1R" no matter where the live SL has moved to.
      int    snapIdx = FindSnapshotIndex(tk);
      double oneR, tolUSD, tolPrice, origDist;
      bool   hitSL, reached1R;

      if(snapIdx >= 0 && MathAbs(g_snapEntry[snapIdx]-g_snapSL[snapIdx]) > 0)
      {
         origDist = MathAbs(g_snapEntry[snapIdx]-g_snapSL[snapIdx]); // stable, never shrinks
         oneR     = g_snapRiskUSD[snapIdx];                          // Initial Risk ($)
         tolUSD   = oneR * 0.10;                                     // 10% of Initial Risk ($) - kept for reference/other consumers, no longer drives hitSL
         tolPrice = origDist * 0.10;                                 // price-space tolerance, drives hitSL below

         // $-per-price-unit factor derived from the ORIGINAL (Snapshot) risk/distance -
         // stable, so it can't blow up even though the live SL may now sit only a
         // couple of points from entry (BE) or beyond entry into profit (Trailing).
         double dollarPerUnit = oneR / origDist;

         // Signed $ value of the CURRENT (live) SL - what closing at that stop is
         // actually worth today: negative while still on the loss side of entry,
         // positive once BE/Trailing has moved it into profit territory.
         // (Retained for other consumers/future R-multiple work - no longer used
         // to decide hitSL itself, see v52 fix note below.)
         double signedCurrentStopPL = isBuy ? (slPrice - openPrice) * dollarPerUnit
                                             : (openPrice - slPrice) * dollarPerUnit;

         // v52 (BUG-045 fix): hitSL now decided purely on PRICE distance, not the
         // $ result of the close. The old $-based check (|profit - signedCurrentStopPL|
         // <= tolUSD) broke on tight stops: OrderProfit()+Swap+Commission includes the
         // real spread/commission cost of the close, but signedCurrentStopPL is a pure
         // price-distance projection that has no spread/commission in it. On a normal
         // stop the gap is a small fraction of oneR and stays inside the 10% tolerance;
         // on a tight stop (a couple of points) that same fixed spread/commission cost
         // can be a large fraction of oneR and blow past tolUSD even though the trade
         // closed exactly on the SL price. Comparing price-to-price instead sidesteps
         // spread/commission entirely, so it works the same regardless of stop width,
         // broker, or symbol.
         // v74.1 (HF1 A4, MT4 v82 BUG-052): directional - "at or beyond SL" is a stop; only a fill
         // clearly better than SL (past the tolerance) is not. Tolerance value unchanged.
         hitSL     = isBuy ? (closePrice <= slPrice + tolPrice) : (closePrice >= slPrice - tolPrice);
         // did it reach +1R? Still measured in $ against the full original Initial Risk -
         // untouched, this is a separate R-multiple question, not part of this fix.
         reached1R = (profit >= oneR * 0.95);
      }
      else
      {
         // Fallback: no Trade Snapshot exists for this ticket (e.g. opened before
         // v11 was installed on this account). Falls back to the pre-fix SL-distance
         // based logic so classification doesn't crash or divide by zero - this path
         // is expected to be rare/legacy-only.
         origDist = MathAbs(openPrice - slPrice);
         tolPrice = origDist * 0.10;
         hitSL    = isBuy ? (closePrice <= slPrice + tolPrice) : (closePrice >= slPrice - tolPrice); // v74.1 (HF1 A4): directional
         double pipVal = GetPipValueForSymbol(_Symbol, _Point, PipFactor());
         // [Stage 4] OrderLots() (closed order, MT4) -> g_trackedLots[j] (live-tracked, see header
         // comment) - MT5 deals don't carry a "position volume at open" field to fall back to here.
         oneR      = origDist/_Point/PipFactor() * pipVal * g_trackedLots[j];
         reached1R = (profit >= oneR * 0.95);
      }

      // v52 (BUG-045 fix, consistency): hitTP now uses a tolerance based on the
      // TP-to-entry price distance (same 10% pattern as hitSL above), instead of
      // reusing the SL-based tolPrice. Keeps SL and TP checks independent of each
      // other's distance, and both are now purely price-based (no $ involved).
      // [Stage 4] OrderTakeProfit() (closed order, MT4) -> g_trackedTP[j] (live-tracked, see
      // header comment) - the position is already gone from PositionsTotal() by this point.
      double tpPriceVal = g_trackedTP[j];
      bool   hitTP;
      if(tpPriceVal > 0)
      {
         double tpDist = MathAbs(tpPriceVal - openPrice);
         double tpTol  = tpDist * 0.10;
         hitTP = isBuy ? (closePrice >= tpPriceVal - tpTol) : (closePrice <= tpPriceVal + tpTol); // v74.1 (HF1 A4): directional
      }
      else
      {
         hitTP = false; // no TP was set on this order - can't have hit it
      }

      // v74.1 (HF1 B1, MT4 v103 BUG-053): SL on the loss side of entry? Exactly at entry = NOT loss side.
      // Price comparison only; slPrice is the last tracked SL (synced every tick in TrackOpenTrades).
      bool slOnLossSide = isBuy ? (slPrice < openPrice) : (slPrice > openPrice);

      // v74.2 (HF3, B2): claim this closed position. If another chart already claimed it, it has counted it
      // (shared counters / lock ends / strike flag); we only do our own local cleanup below.
      bool claimLost = !ClaimClosedTicket(tk);
      if(claimLost)
      {
         Print("[RM-CLAIM] pos=#"+IntegerToString(tk)+" already processed by another chart - skipped on "+_Symbol+","+EnumToString((ENUM_TIMEFRAMES)_Period));
         RemoveHalfExemptLocal(tk);   // v75.0: فقط حافظه‌ی محلی؛ GV را برنده‌ی claim پاک می‌کند
         RefreshSharedCooldownState();
         RefreshSharedLockEnds();
      }
      else if(hitSL && !hitTP && slOnLossSide) // v74.1 (HF1 B1): was hitSL && !hitTP
      {
         // Market Cooldown: full stop
         // v19 (BUG-022): a Half Risk stop is a deliberately cautious trade - it adds only
         // 0.5 to the streak instead of the usual 1.0. A ticket with no Snapshot (pre-v19
         // legacy) falls back to the full 1.0, same conservative philosophy used elsewhere
         // in the Snapshot system (treat as Full Risk when we can't tell).
         // v75.13 (MT4 v87/v90): بخشی از زنجیره‌ی چندعضوی (ریشه + ورود ادامه) -> شمارش Market برای این پوزیشن انجام نمی‌شود؛
         // بعد از بسته‌شدن کامل زنجیره یک‌بار بر اساس برایند کل محاسبه می‌شود (ProcessChainMarketStop). معامله‌ی تکی دقیقاً مثل قبل.
         bool chainDeferMkt = (ChainMemberCount(GetRootTicket(tk)) > 1);
         if(chainDeferMkt) GlobalVariableSet("RM_CHAINDEFER_" + ChainKeyScope() + IntegerToString(GetRootTicket(tk)), 1.0);
         if(!chainDeferMkt)
         {
         double mktIncrement = 1.0;
         if(snapIdx >= 0) mktIncrement = SnapRiskWeight(snapIdx);
         // v53: افزایش امن (CAS) روی شمارنده‌ی Market مشترک بین چارت‌ها
         g_mktStopCount = CAS_AddToGlobal(GV_MKT_COUNT, mktIncrement);
         g_lastStopCloseTime = closeTimeVal; // v13 (BUG-017): reference point for the time-based streak reset
         CAS_SetGlobal(GV_LAST_STOP_CLOSE, (double)g_lastStopCloseTime); // v53: کمکی مستقیم‌ِ شمارنده هم همراهش به GV مشترک نوشته می‌شه
         }
         // stop = correct, reset Behavior - v53: این ریست هم account-wide شد (طبق تصمیم چت اصلی:
         // "SL درست = ریست Behavior" روی همون شمارنده‌ی مشترک اعمال بشه)
         int behBeforeSL = g_behCount; // v65 (DEBUG-BEHCOUNT - آیتم ۲)
         g_behCount = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
         Print("[DEBUG-BEHCOUNT] Reset (SL) | ticket=#"+IntegerToString(tk)+" | before="+IntegerToString(behBeforeSL)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
         if(EnableMarketCD && g_mktStopCount >= MarketCDCount && g_mktCooldownEnd == 0)
         {
            g_mktCooldownEnd = TimeCurrent() + MarketCDHours*3600;
            g_mktStopCount   = CAS_SetGlobal(GV_MKT_COUNT, 0.0);
            g_lastStopCloseTime = 0; // v13 (BUG-017): streak already resolved via lock, nothing left to time out
            CAS_SetGlobal(GV_LAST_STOP_CLOSE, 0.0);
         }
         RemoveHalfExempt(tk);
         SaveCooldownState(); // v13 (BUG-017): persist g_lastStopCloseTime immediately so it survives a restart
         PlaySound(SND_STOP_LOSS);  // v45 (Punch List Round 3, Item 8)
      }
      else if(hitSL && !hitTP)
      {
         // v74.1 (HF1 B1): protected stop (SL moved to BE/profit by manual BE, Auto BE or trailing).
         // Market counter, GV_LAST_STOP_CLOSE and the lock check are untouched. Behavior resets like a
         // normal stop. Never EarlyExit / Strike.
         int behBeforeProt = g_behCount;
         g_behCount = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
         Print("[DEBUG-BEHCOUNT] Reset (SL-protected) | ticket=#"+IntegerToString(tk)+" | before="+IntegerToString(behBeforeProt)+" after="+IntegerToString(g_behCount));
         Print("[RM-MC] pos=#"+IntegerToString(tk)+" protectedStop sl="+DoubleToString(slPrice,_Digits)+
               " open="+DoubleToString(openPrice,_Digits)+" close="+DoubleToString(closePrice,_Digits)+
               " profit="+DoubleToString(profit,2)+" mktCountUnchanged="+DoubleToString(g_mktStopCount,1)+
               " outcome=Reset(SL-protected)");
         RemoveHalfExempt(tk);
         SaveCooldownState();
         if(profit >= 0) PlaySound(SND_TARGET_REACHED); else PlaySound(SND_STOP_LOSS);
      }
      else if(hitTP || reached1R)
      {
         // v13 (BUG-017): Market Cooldown no longer resets on +1R - only the time gap
         // since the last SL close (MarketCDResetHours) or an active lock reset it now.
         // Behavior Cooldown's +1R reset is untouched - different philosophy (in-the-moment
         // emotional behavior detection, not market-context detection).
         // v53: ریست Behavior حالا account-wide (CAS). توجه: منطق v13 BUG-017 دست‌نخورده موند -
         // یعنی Market روی +1R ریست نمی‌شه، فقط Behavior. این دقیقاً همون رفتار v52 است، فقط حالا
         // روی شمارنده‌ی مشترک اعمال می‌شه (نه یه تغییر رفتاری جدید - خارج از دامنه‌ی این تسک بود).
         int behBeforeTP = g_behCount; // v65 (DEBUG-BEHCOUNT - آیتم ۲)
         g_behCount = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
         Print("[DEBUG-BEHCOUNT] Reset (+1R/TP) | ticket=#"+IntegerToString(tk)+" | before="+IntegerToString(behBeforeTP)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
         RemoveHalfExempt(tk);
         SaveCooldownState();
         PlaySound(SND_TARGET_REACHED);  // v45 (Punch List Round 3, Item 8)
      }
      else if(!hitSL && !hitTP)
      {
         // v9.3: اگه این تیکت قبلاً با Half Close در TP1+ معاف شده، خروج نهایی‌اش
         // رو به‌عنوان رفتار اشتباه حساب نکن
         if(wasEmergency)
         {
            // v74.4 (HF4): Emergency Close never adds a Behavior (EarlyExit) strike.
            Print("[RM-EMERG] pos=#"+IntegerToString(tk)+" closed by Emergency Close - no Behavior strike");
            if(IsHalfExempt(tk))
               RemoveHalfExempt(tk);
            SaveCooldownState();
         }
         else if(IsHalfExempt(tk))
         {
            RemoveHalfExempt(tk);
            SaveCooldownState();
         }
         else if(snapIdx >= 0 && g_snapIsContinuation[snapIdx])
         {
            // v75.13 (MT4 v90 FEAT-044): خروج زودهنگام یک ورود ادامه (Scale-in) Strike رفتاری ندارد
            Print("RM: EarlyExit close (ticket #"+IntegerToString(tk)+") - Scale-in continuation entry, exempt from Behavior strike");
         }
         else
         {
            // Manual close before +1R - v53: افزایش امن (CAS) روی شمارنده‌ی مشترک
            //
            // v65 (BUG-049 fix): این تیکت ممکنه از قبل، لحظه‌ی کلیک دکمه (Manual Close
            // Full/Chart/Profit/Loss یا Auto BE/Trailing)، توسط CheckPrematureAction() یک
            // Strike واقعی گرفته باشه (IsAlreadyStrikedThisTrade/MarkStrikedThisTrade - همون
            // مکانیزم single-strike-per-trade که از قبل برای BUG-021 وجود داره). قبل از این
            // فیکس، اینجا بدون هیچ چکی دوباره GV_BEH_COUNT رو +۱ می‌کرد - یعنی همون تصمیم
            // رفتاری (خروج زودهنگام) دو بار شمرده می‌شد. حالا از همون تابع موجود استفاده
            // می‌شه: اگه قبلاً Strike خورده، اینجا GV_BEH_COUNT دوباره دست نمی‌خوره.
            if(IsAlreadyStrikedThisTrade(tk))
            {
               Print("RM: EarlyExit close (ticket #"+IntegerToString(tk)+") - trade already struck via CheckPrematureAction, no additional GV_BEH_COUNT increment"); // v65 (BUG-049 fix)
               // v64 (آیتم ۵): شمارنده‌ی جدای گزارش‌گیری v61 (GV_BEHERR_TOTAL) مستقل از
               // GV_BEH_COUNT است و اسکوپ این فیکس نیست - همچنان طبق رفتار قبلی +۱ می‌شه.
               IncrementBehaviorErrorTotal();
               SaveCooldownState();
            }
            else
            {
               MarkStrikedThisTrade(tk); // v65 (BUG-049 fix): این تیکت رو هم علامت بزن تا هیچ مسیر بعدی دوباره نشمردش
               int behBeforeEE = g_behCount; // v65 (DEBUG-BEHCOUNT - آیتم ۲)
               g_behCount = (int)MathRound(CAS_AddToGlobal(GV_BEH_COUNT, 1.0));
               Print("[DEBUG-BEHCOUNT] Strike | ticket=#"+IntegerToString(tk)+" (EarlyExit) | before="+IntegerToString(behBeforeEE)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
               // v64 (آیتم ۵ - اصلاح شمارنده‌ی EarlyExit): این خط، شمارنده‌ی جدای گزارش‌گیری v61
               // (GV_BEHERR_TOTAL، هرگز-ریست-نشونده) رو هم +۱ می‌کنه - قبلاً EarlyExit فقط
               // GV_BEH_COUNT بالا (شمارنده‌ی واقعی Cooldown) رو تحت‌تأثیر قرار می‌داد. این خط
               // هیچ اثری روی منطق واقعی قفل‌شدن Cooldown نداره (GV_BEH_COUNT کاملاً دست‌نخورده) -
               // فقط باعث می‌شه BehaviorErrorsThisTrade/BehaviorErrorCountAtOpen (v61/v64) با
               // تعریف واقعی «خطای رفتاری» از دید تریدر هم‌خونی داشته باشن.
               IncrementBehaviorErrorTotal();
               if(EnableBehaviorCD && g_behCount >= BehaviorCDCount && g_behCooldownEnd == 0)
               {
                  g_behCooldownEnd = TimeCurrent() + BehaviorCDHours*3600;
                  int behBeforeEELock = g_behCount; // v65 (DEBUG-BEHCOUNT)
                  g_behCount       = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
                  Print("[DEBUG-BEHCOUNT] Reset (Lock) | ticket=#"+IntegerToString(tk)+" | before="+IntegerToString(behBeforeEELock)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
               }
               SaveCooldownState();
            }
         }
      }

      // v75.13 (MT4 v87): Market Cooldown زنجیره‌ای - فقط برنده‌ی claim، و فقط وقتی زنجیره‌ی چندعضوی کاملاً بسته شد
      if(!claimLost) ProcessChainMarketStop(tk);

      // v64 (آیتم ۴ - BehaviorErrorsThisTrade): *بعد* از کل زنجیره‌ی طبقه‌بندی بالا (نه قبلش) -
      // چون آیتم ۵ (بالا) حالا ممکنه همین لحظه GV_BEHERR_TOTAL رو برای همین تیکت افزایش داده
      // باشه (شاخه‌ی EarlyExit)؛ برای این‌که سهم خودِ همین معامله واقعاً لحاظ بشه، باید بعد از
      // اون افزایش خونده بشه، نه قبلش. مقدار زنده‌ی GetBehaviorErrorTotal() منهای همون
      // BehaviorErrorCountAtOpen که لحظه‌ی باز شدن این تیکت ثبت شده بود = «چند خطای جدید
      // مختص خودِ این معامله».
      if(snapIdx>=0)
         SetSnapshotBehaviorErrorsThisTrade(tk, GetBehaviorErrorTotal() - g_snapBehaviorErrorCountAtOpen[snapIdx]);

      // remove from tracked list
      for(int k=j;k<g_trackedCount-1;k++)
      {
         g_trackedTickets[k] = g_trackedTickets[k+1];
         g_trackedSL[k]      = g_trackedSL[k+1];
         g_trackedEntry[k]   = g_trackedEntry[k+1];
         g_trackedBuy[k]     = g_trackedBuy[k+1];
         g_trackedTP[k]      = g_trackedTP[k+1];
         g_trackedLots[k]    = g_trackedLots[k+1];
      }
      g_trackedCount--;
      ArrayResize(g_trackedTickets, g_trackedCount);
      ArrayResize(g_trackedSL,      g_trackedCount);
      ArrayResize(g_trackedEntry,   g_trackedCount);
      ArrayResize(g_trackedBuy,     g_trackedCount);
      ArrayResize(g_trackedTP,      g_trackedCount);
      ArrayResize(g_trackedLots,    g_trackedCount);
   }

   // v14 (Advanced Break Even - BasketAverage, فیدبک کاربر): برخلاف خط‌های BE/Trailing که
   // per-ticket هستن و همین بالا با بسته‌شدن هر تیکت پاک می‌شن، خط میانگین بسکت per-direction
   // (یه خط برای کل بسکت Buy، یه خط برای کل بسکت Sell) است - پس باید جدا چک بشه: وقتی دیگه
   // هیچ پوزیشن بازی توی اون جهت نمونده (کل بسکت بسته شده)، خط مربوطه هم پاک بشه. هر تیک چک
   // می‌شه (نه فقط لحظه‌ی بسته‌شدن یه تیکت خاص) تا مطمئن باشیم عقب نمی‌مونه.
   double tmpAvg;
   if(!GetBasketAveragePrice(true,  tmpAvg)) ObjectDelete(0, BasketAvgLineName(true));
   if(!GetBasketAveragePrice(false, tmpAvg)) ObjectDelete(0, BasketAvgLineName(false));

   // v68 (Auto Export CSV - بازطراحی v67 طبق فیدبک محمود): مستقل از دکمه‌ی دستی EXPORT CSV.
   // همون تابع موجود ExportTradeJournalCSV() (v55، RM_Reports.mqh) صدا زده می‌شه - بدون هیچ
   // تغییری در خودش. فقط وقتی این تیک واقعاً حداقل یه تیکت بسته شده باشه (anyClosedThisTick)
   // و AutoExportOnClose روشن باشه - نه هر تیک، نه یه GlobalVariable/ساعت جداگانه لازمه (بر
   // خلاف v67) چون trigger خودش طبیعتاً idempotent-per-close است.
   if(anyClosedThisTick && AutoExportOnClose)
   {
      string autoExportedFile;
      if(ExportTradeJournalCSV(autoExportedFile))
         Print("RM: Auto Export CSV (on trade close) -> ", autoExportedFile); // قابل تفکیک از لاگ اکسپورت دستی (RiskManager_EA_v68.mq4)
   }
}

//+------------------------------------------------------------------+
// v13 (BUG-017): Time-based Market Cooldown streak reset
// If MarketCDResetHours have passed since the last SL close and the streak
// counter isn't already zero, reset it - even if no new trade has been placed.
//+------------------------------------------------------------------+
void CheckMarketCDTimeReset()
{
   // v53: قبل از هر مقایسه‌ای، آخرین مقدار مشترک رو زنده بخون - ممکنه یه چارت دیگه اخیراً
   // شمارنده/g_lastStopCloseTime رو تغییر داده باشه. این تابع هر تیک (از OnTick، قبل از
   // CheckClosedTrades) صدا زده می‌شه، پس همینجا mirror محلی برای بقیه‌ی همین تیک هم تازه می‌شه.
   RefreshSharedCooldownState();
   RefreshSharedLockEnds();   // v74.2 (HF3, B4): lock ends are account-wide and refreshed every tick
   if(g_mktStopCount > 0 && g_lastStopCloseTime > 0 &&
      TimeCurrent() - g_lastStopCloseTime >= MarketCDResetHours*3600)
   {
      g_mktStopCount      = CAS_SetGlobal(GV_MKT_COUNT, 0.0);
      g_lastStopCloseTime = (datetime)CAS_SetGlobal(GV_LAST_STOP_CLOSE, 0.0);
      SaveCooldownState();
   }
}

//+------------------------------------------------------------------+
// Check if trading is allowed
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // check drawdown locks
   // v51 (Parking Lot #1): قفل Daily، دقیقاً هم‌الگوی Weekly/Monthly - چک g_dailyLockEnd
   if(g_dailyLockEnd>0   && TimeCurrent() < g_dailyLockEnd)   return false;
   if(g_weeklyLockEnd>0  && TimeCurrent() < g_weeklyLockEnd)  return false;
   if(g_monthlyLockEnd>0 && TimeCurrent() < g_monthlyLockEnd) return false;

   if(g_mktCooldownEnd > 0 && TimeCurrent() < g_mktCooldownEnd) return false;
   if(g_mktCooldownEnd > 0 && TimeCurrent() >= g_mktCooldownEnd)
   {
      g_mktCooldownEnd = 0;
      // v53: ریست شمارنده‌ی مشترک با CAS (نه assignment ساده‌ی محلی)
      g_mktStopCount      = CAS_SetGlobal(GV_MKT_COUNT, 0.0);
      g_lastStopCloseTime = (datetime)CAS_SetGlobal(GV_LAST_STOP_CLOSE, 0.0);
      SaveCooldownState();
   }

   if(g_behCooldownEnd > 0 && TimeCurrent() < g_behCooldownEnd) return false;
   if(g_behCooldownEnd > 0 && TimeCurrent() >= g_behCooldownEnd)
   {
      g_behCooldownEnd = 0;
      int behBeforeITA = g_behCount; // v65 (DEBUG-BEHCOUNT - آیتم ۲)
      g_behCount = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
      Print("[DEBUG-BEHCOUNT] Reset (Time Expiry) | ticket=N/A | before="+IntegerToString(behBeforeITA)+" after="+IntegerToString(g_behCount)); // v65 موقت، برای حذف بعدی
      SaveCooldownState();
   }

   return true;
}
