//+------------------------------------------------------------------+
//| RM_CooldownEngine.mqh                                              |
//| Risk Manager EA - Cooldown & Behavior Engine (Architecture         |
//| Refactor, R6)                                                      |
//| استخراج‌شده از RiskManager_EA_v45_R5.mq4 - موتور کول‌داون و رفتار:    |
//| Entry Interval / Pending Activation Tracking، Behavior Strike،      |
//| ردیابی معاملات باز/بسته‌شده (Market+Behavior Cooldown classification)،|
//| ریست زمان‌محور Market Cooldown، Save/LoadCooldownState، و            |
//| IsTradingAllowed() (gatekeeper مشترک Cooldown+Drawdown Lock).       |
//| صرفاً جابه‌جایی کد، بدون هیچ تغییر مقدار/رفتار (Golden Rule فاز R6). |
//+------------------------------------------------------------------+

// v53 (شمارنده‌های Market/Behavior Cooldown مشترک بین چارت‌ها):
// -------------------------------------------------------------------------
// چون از این نسخه به بعد چند نمونه‌ی EA (چارت‌های مختلف) هم‌زمان می‌تونن همون
// GlobalVariable مشترک رو بخونن/بنویسن، یه read-modify-write ساده (GlobalVariableGet
// → +delta → GlobalVariableSet) خطر lost-update داره: اگه دو چارت تقریباً هم‌زمان
// مقدار قدیمی رو بخونن و هر دو +1 کنن، یکی از دو افزایش گم می‌شه. به‌جاش از
// GlobalVariableSetOnCondition() استفاده می‌شه (compare-and-swap واقعی MQL4): مقدار
// فعلی خونده می‌شه، نوشتن مقدار جدید فقط زمانی موفقه که GV هنوز همون مقدار قدیمی
// باشه؛ اگه یه چارت دیگه بین خوندن و نوشتن ما مقدار رو عوض کرده بود، دوباره از GV
// (نه از کش محلی) می‌خونیم و دوباره تلاش می‌کنیم - با یه سقف تلاش معقول تا گیر نکنه.
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
         return newVal; // موفق - هیچ چارت دیگه‌ای بین خوندن و نوشتن ما مقدار رو عوض نکرد
      current = GlobalVariableGet(gvName); // شرط برقرار نبود - دوباره بخون و دوباره تلاش کن
   }
   // v53: بعد از RM_CAS_MAX_RETRY بار رقابت پشت‌سرهم (عملاً خیلی بعیده) - به‌جای گیر کردن
   // بی‌نهایت، مستقیم می‌نویسیم. حداکثر ریسک: یکی از افزایش‌های هم‌زمان (نادر) گم بشه، ولی
   // سیستم هیچ‌وقت قفل نمی‌مونه یا کرش نمی‌کنه.
   double fallback = current + delta;
   GlobalVariableSet(gvName, fallback);
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
         return value;
      current = GlobalVariableGet(gvName);
   }
   GlobalVariableSet(gvName, value); // fallback نهایی
   return value;
}

// === v101 (BUG-054 - پردازش دقیقاً-یک‌بار بسته‌شدن تیکت بین چند نمونه‌ی EA) ======================
// مشکل: چند چارتِ هم‌نماد (مثلاً M5+H1) هر کدام EA جدا دارند و هر کدام مستقل بسته‌شدن یک تیکت را
// تشخیص می‌دهند -> Market CD / Behavior / CSV / اسکرین‌شات / صدا چندبار. راه‌حل: «claim» per-ticket روی
// GlobalVariable مشترک؛ اولین نمونه‌ای که claim را می‌گیرد همه‌ی اثرهای یک‌باره را انجام می‌دهد و بقیه
// فقط لاگ می‌کنند و رد می‌شوند. اثرهای per-chart (حذف آبجکت‌های همین چارت، پنل، History) روی همه می‌ماند.
//
// اتمیک‌بودن: MQL4 هیچ «ساخت-اگر-نبود» اتمیک ندارد. GlobalVariableSetOnCondition فقط روی GV *موجود* کار
// می‌کند. اگر ساده بنویسیم «اگر نبود بساز(0)؛ بعد CAS(0->من)» یک race دارد: نمونه‌ی B بین Check و Set
// گیر کند، بعد از این‌که A claim را گرفت B دوباره 0 بنویسد و B هم برنده شود. پس از یک «قفل» (mutex) مشترک
// استفاده می‌شود که GV آن از قبل (OnInit/نگهداری روزانه) ساخته شده و فقط با CAS (0 -> زمان) گرفته و با Set(0)
// آزاد می‌شود؛ داخل قفل، «Check کلید claim + Set» امن (سریالی) است. قفلِ گیرکرده (EA وسط کار کرش کند) بعد
// از RM_CLAIM_LOCK_STALE_SEC ثانیه با CAS دزدیده می‌شود. اگر قفل در RM_CLAIM_LOCK_TRIES تلاش گرفته نشد،
// «کم‌بدترین گزینه»: همان Check+Set بدون قفل + بازخوانی تأییدی (احتمال تداخل بسیار ناچیز) و یک لاگ هشدار.
// محدودیت: GlobalVariableها per-terminal هستند؛ نمونه‌های EA در ترمینال‌های جدا هماهنگ نمی‌شوند.
// ماهیت claim: «حداکثر یک‌بار» (at-most-once) - اگر نمونه‌ی برنده وسط پردازش کرش کند، نمونه‌ی دیگر دوباره
// پردازش نمی‌کند (ترجیح داده شد به شمارش دوبل).
#define RM_CLAIM_LOCK_TRIES      40
#define RM_CLAIM_LOCK_SLEEP_MS   2
#define RM_CLAIM_LOCK_STALE_SEC  5
#define RM_CLAIM_KEEP_DAYS       14

string RM_ClaimScope()   { return "A" + IntegerToString(AccountNumber()) + "_M" + IntegerToString(MagicNumber) + "_"; }
string RM_ClaimLockKey() { return "RM_CLAIMLOCK_" + RM_ClaimScope(); }
string RM_CloseClaimKey(int ticket) { return "RM_CLOSECLAIM_" + RM_ClaimScope() + IntegerToString(ticket); }
string RM_InstTag()      { return Symbol() + "/" + TimeframeCodeToString((double)Period()); }
string RM_TfName(double periodCode) { return TimeframeCodeToString(periodCode); }

// ساخت/تازه‌سازی GV قفل. ایمن برای صدازدن چندباره؛ فقط وقتی کلید غایب است می‌سازد (۰ = آزاد).
void RM_ClaimEnsureLock()
{
   string lk = RM_ClaimLockKey();
   if(!GlobalVariableCheck(lk)) GlobalVariableSet(lk, 0.0);
   else GlobalVariableGet(lk);  // دسترسی = تازه‌سازی انقضای ۴هفته‌ای MT4
}

// تلاش برای claim کردن یک کلید. true = من اولین بودم (و کلید با مقدار owner نوشته شد)؛ false = قبلاً کس دیگری
// claim کرده و existingOwner مقدار او (کد تایم‌فریمش) است.
bool RM_ClaimKey(string key, double owner, double &existingOwner)
{
   existingOwner = 0.0;
   string lk = RM_ClaimLockKey();
   bool locked = false;
   for(int t=0; t<RM_CLAIM_LOCK_TRIES; t++)
   {
      if(!GlobalVariableCheck(lk)) GlobalVariableSet(lk, 0.0);   // فقط اگر کلید قفل منقضی/پاک شده باشد
      double cur  = GlobalVariableGet(lk);
      double nowL = (double)TimeLocal();
      if(cur == 0.0 || (nowL - cur) > RM_CLAIM_LOCK_STALE_SEC)
      {
         if(GlobalVariableSetOnCondition(lk, nowL, cur)) { locked = true; break; }
      }
      Sleep(RM_CLAIM_LOCK_SLEEP_MS);
   }

   bool claimed = false;
   if(GlobalVariableCheck(key))
      existingOwner = GlobalVariableGet(key);
   else
   {
      GlobalVariableSet(key, owner);
      // بازخوانی تأییدی: در حالت بدون قفل (fallback)، اگر نمونه‌ی دیگری همزمان نوشت و مقدارش ماند، ما بازنده‌ایم
      double chk = GlobalVariableGet(key);
      if(chk == owner) claimed = true; else existingOwner = chk;
   }

   if(locked) GlobalVariableSet(lk, 0.0);
   else Print("[RM-MI] WARNING: claim lock not acquired on ", RM_InstTag(), " (key ", key, ") - non-atomic fallback used");
   return claimed;
}

// claim روی خودِ تیکت بسته‌شده (مقدار ذخیره‌شده = کد تایم‌فریم نمونه‌ی برنده تا لاگ «skipped» بتواند اسمش را بگوید)
bool RM_ClaimCloseTicket(int ticket, double &existingOwner)
{
   return RM_ClaimKey(RM_CloseClaimKey(ticket), (double)Period(), existingOwner);
}

// پاک‌سازی claimهای قدیمی (جلوگیری از انباشت بی‌پایان) - هم‌زمان تعداد کلیدهای موجود را برمی‌گرداند.
// GlobalVariableTime = آخرین دسترسی. فقط کلیدهای همین حساب+مجیک. بار: یک اسکن روی جدول GV (OnInit و روزانه).
int RM_ClaimPurgeOld()
{
   string prefix = "RM_CLOSECLAIM_" + RM_ClaimScope();
   datetime limit = TimeCurrent() - (datetime)(RM_CLAIM_KEEP_DAYS*86400);
   int kept = 0, purged = 0;
   for(int i=GlobalVariablesTotal()-1; i>=0; i--)
   {
      string nm = GlobalVariableName(i);
      if(StringFind(nm, prefix) != 0) continue;
      if(GlobalVariableTime(nm) < limit) { GlobalVariableDel(nm); purged++; }
      else kept++;
   }
   if(purged > 0) Print("[RM-MI] purged ", purged, " old close-claim key(s) (> ", RM_CLAIM_KEEP_DAYS, " days)");
   return kept;
}

// صدا زده می‌شه از OnInit و نگهداری روزانه
int RM_ClaimHousekeeping()
{
   RM_ClaimEnsureLock();
   return RM_ClaimPurgeOld();
}
// === پایان v101 claim ===============================================================================

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
   // v101 (BUG-054): پایان قفل‌های Market/Behavior و g_lastEntryTime هم mirror محلی بودند که فقط در OnInit
   // خوانده می‌شدند؛ وقتی نمونه‌ی دیگری (claim-winner) قفل را می‌گذاشت، چارت‌های هم‌نمادِ دیگر آزاد می‌ماندند و
   // پنل‌شان وضعیت متفاوت نشان می‌داد. کلیدها per-symbol (A+M+نماد) هستند -> فقط نمونه‌های هم‌نماد را هم‌گام می‌کند
   // (دامنه‌ی کلیدها عوض نشد). فقط GlobalVariableGet (جدول حافظه‌ی ترمینال)، بدون I/O فایل.
   g_mktCooldownEnd = GlobalVariableCheck(GV_MKT_END)    ? (datetime)GlobalVariableGet(GV_MKT_END)    : 0;
   g_behCooldownEnd = GlobalVariableCheck(GV_BEH_END)    ? (datetime)GlobalVariableGet(GV_BEH_END)    : 0;
   g_lastEntryTime  = GlobalVariableCheck(GV_LAST_ENTRY) ? (datetime)GlobalVariableGet(GV_LAST_ENTRY) : 0;
}

// آرایه‌های ردیابی داخلی این ماژول - فقط توسط توابع همین فایل استفاده می‌شن
// (با grep در همه‌ی فایل‌ها تأیید شد)، برخلاف g_weeklyLockEnd/g_monthlyLockEnd/
// g_mktCooldownEnd/g_behCooldownEnd که چون RM_Dashboard.mqh (و g_mktCooldownEnd
// همچنین RM_TradeExecution.mqh) هم مستقیم بهشون دسترسی دارن، در فایل اصلی می‌مونن.
// v9.8: ردیابی پندینگ‌های ثبت‌شده تا لحظه‌ی فعال‌شدن واقعی‌شون (نه لحظه‌ی ثبت)
int      g_pendingTrackTickets[];
int      g_pendingTrackCount = 0;
// track open trades for manual close detection
int      g_trackedTickets[];
double   g_trackedSL[];
double   g_trackedEntry[];
bool     g_trackedBuy[];
int      g_trackedCount = 0;

// v62 (تفکیک ExitReason - EmergencyClose در برابر خروج دستی): آرایه‌ی موقت که EmergencyCloseAll()
// (فایل اصلی .mq4) درست قبل از بستن هر پوزیشن، تیکتش رو بهش اضافه می‌کنه - هیچ تغییری در منطق
// خودِ EmergencyCloseAll() (چی رو کِی می‌بنده) داده نشده. CheckClosedTrades() پایین‌تر، توی همون
// لحظه‌ای که بسته‌شدن هر تیکت رو تشخیص می‌ده، حضورش توی این آرایه رو چک می‌کنه (ConsumeEmergencyClosedTicket)
// و اگه بود، پرچم persisted (GlobalVariable، چون Export CSV ممکنه خیلی بعدتر/بعد از ری‌استارت
// صدا زده بشه) رو با MarkEmergencyClosed ثبت می‌کنه - جدا و مستقل از منطق موجود شمارش
// Market/Behavior Cooldown (که دست‌نخورده می‌مونه).
int      g_emergencyClosedTickets[];
int      g_emergencyClosedCount = 0;

// اگه این تیکت توی آرایه‌ی بالا باشه، حذفش می‌کنه و true برمی‌گردونه (مصرفِ یک‌باره - هر تیکت
// فقط یک‌بار توسط CheckClosedTrades پردازش می‌شه، پس نیازی به موندنش توی آرایه بعد از اون نیست)
bool ConsumeEmergencyClosedTicket(int ticket)
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
// v77 (اصلاحِ تداخلِ بین‌اکانتی - دسته ۴): کلید با شماره‌ی تیکت ساخته می‌شد و تیکت بین بروکرها/اکانت‌ها
// می‌تونه تکراری باشه؛ حالا A<حساب>_M<مجیک> جلوش اضافه شد تا دو اکانتِ هم‌ترمینال پرچمِ هم رو نخونن.
string EmergencyKey(int ticket)
{
   return "RM_EMERGENCY_A" + IntegerToString(AccountNumber()) + "_M" + IntegerToString(MagicNumber) + "_" + IntegerToString(ticket);
}
void MarkEmergencyClosed(int ticket)
{
   GlobalVariableSet(EmergencyKey(ticket), 1.0);
}

bool WasEmergencyClosed(int ticket)
{
   return GlobalVariableCheck(EmergencyKey(ticket));
}

// BUG-052/FEAT-036 (v82): Spread_AtClose - تاریخچه‌ی MT4 هیچ فیلد اسپرد ذخیره‌شده‌ای نداره
// (نه در OrderStopLoss/OrderTakeProfit/OrderComment، هیچ‌کدوم)، پس تنها لحظه‌ای که Ask-Bid
// واقعی این معامله قابل‌ثبته همین‌جا، توی CheckClosedTrades، همون لحظه‌ای که بسته‌شدن تشخیص داده
// می‌شه (دقیقاً همون فلسفه‌ی TakeExitScreenshot در RM_Tools.mqh - نزدیک‌ترین تیکی که EA می‌تونه
// به لحظه‌ی واقعی بسته‌شدن داشته باشه). چون ExportTradeJournalCSV() (RM_Reports.mqh) ممکنه خیلی
// بعدتر - حتی بعد از ری‌استارت EA - صدا زده بشه، این مقدار هم دقیقاً مثل WasEmergencyClosed/
// MarkEmergencyClosed بالا در GlobalVariable (نه آرایه‌ی موقت حافظه) نگه داشته می‌شه؛ همون کلید
// A<حساب>_M<مجیک>_<تیکت> (v77) برای جلوگیری از تداخل بین‌حسابی.
string SpreadAtCloseKey(int ticket)
{
   return "RM_SPREADCLOSE_A" + IntegerToString(AccountNumber()) + "_M" + IntegerToString(MagicNumber) + "_" + IntegerToString(ticket);
}
void RecordSpreadAtClose(int ticket, double spreadPrice)
{
   GlobalVariableSet(SpreadAtCloseKey(ticket), spreadPrice);
}
// معامله‌ای که قبل از نصب v82 بسته شده (یا EA وسط تشخیص بسته‌شدنش خاموش بوده) هیچ مقداری برای
// این تیکت ثبت نکرده - false برمی‌گردونه تا صداکننده (ExportTradeJournalCSV) همون قرارداد
// فال‌بک "N/A" رو که بقیه‌ی ستون‌های وابسته به لحظه‌ی خاص اعمال می‌کنن، اینجا هم اعمال کنه.
bool GetSpreadAtClose(int ticket, double &spreadOut)
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
// v90 (FEAT-044): پارامتر exempt (پیش‌فرض false = رفتار قبلی). ورود ادامه (Scale-in) -> هیچ Strike‌ای نمی‌گیرد و g_lastEntryTime هم
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
void AddPendingTrack(int ticket)
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

// v90 (FEAT-044): یک ورود ادامه‌ی Pending بدون پر شدن حذف/منقضی شد. هیچ اثر رفتاری ندارد و لغو خودکار هم نیست؛ فقط از زنجیره جدا می‌شود
// (ریشه = خودش) تا زنجیره‌ی هدف بدون آن ارزیابی شود. اگر هدف در فاصله‌ی انتظار Pending با SL بسته شده بود (Market Cooldown آن به‌خاطر
// عضو Pending به تعویق افتاده بود)، همین‌جا ارزیابی عقب‌افتاده انجام می‌شود. Pending عادی (غیرِ ورود ادامه) هیچ تغییری نمی‌کند.
void HandleVanishedContinuationPending(int tk)
{
   RM_EnsureSnapshot(tk);  // v101: Pending ممکن است روی چارت دیگر ثبت شده باشد
   int idx = FindSnapshotIndex(tk);
   if(idx < 0 || !g_snapIsContinuation[idx]) return;
   int root = GetRootTicket(tk);
   if(root == tk) return;                 // قبلاً جدا شده
   DetachSnapshotRoot(tk);
   Print("RM: Scale-in pending #", tk, " vanished without fill - detached from chain #", root);
   ProcessChainMarketStop(root, true);
}

// v90.1 (FEAT-044، تصمیم Mahmoud): وقتی همه‌ی بخش‌های بازِ زنجیره (با TP، SL یا هر بستنی) بسته شدند، Pending ادامه‌ی پرنشده
// دلیلی برای ماندن ندارد و خودکار حذف می‌شود. فقط Pending علامت‌خورده به‌عنوان ادامه (IsContinuation) و متصل به ریشه؛ Pending عادی دست‌نخورده.
// بعد از حذف، همان مسیر «Pending ناپدید شد» (جداکردن از زنجیره + ارزیابی عقب‌افتاده‌ی Market Cooldown) اجرا می‌شود.
void CancelOrphanContinuationPendings()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      int ty = OrderType();
      if(ty==OP_BUY || ty==OP_SELL) continue;
      int tk = OrderTicket();
      RM_EnsureSnapshot(tk);  // v101: این تابع روی همه‌ی نمونه‌ها (بدون فیلتر نماد) اجرا می‌شود؛ OrderSelect بعد از GV-load عوض نمی‌شود (فقط GlobalVariable)
      if(!IsContinuationTicket(tk)) continue;
      int root = GetRootTicket(tk);
      if(root == tk) continue;
      // آیا هنوز بخش بازی از زنجیره هست؟
      bool anyOpen = false;
      for(int j=0; j<OrdersTotal(); j++)
      {
         if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES)) continue;
         if(OrderMagicNumber()!=MagicNumber) continue;
         int tj = OrderType();
         if(tj!=OP_BUY && tj!=OP_SELL) continue;
         if(GetRootTicket(OrderTicket())==root){ anyOpen = true; break; }
      }
      if(anyOpen) continue;
      if(!OrderSelect(tk,SELECT_BY_TICKET)) continue;
      if(OrderDelete(tk))
      {
         Print("RM: Scale-in pending #", tk, " auto-cancelled - chain #", root, " has no open part left");
         HandleVanishedContinuationPending(tk);
      }
      else
         Print("RM: Scale-in pending #", tk, " auto-cancel FAILED err=", GetLastError());
   }
}

// v9.8: هر تیک چک می‌کنه آیا یکی از پندینگ‌های ردیابی‌شده فعال (پر) شده یا حذف/منقضی شده
void CheckPendingActivation()
{
   for(int i=g_pendingTrackCount-1; i>=0; i--)
   {
      int tk = g_pendingTrackTickets[i];
      if(!OrderSelect(tk, SELECT_BY_TICKET))
      {
         HandleVanishedContinuationPending(tk);  // v90 (FEAT-044)
         RemovePendingTrackAt(i); // دیگه پیدا نشد - نادیده بگیر
         continue;
      }
      int t = OrderType();
      if(t==OP_BUY || t==OP_SELL)
      {
         // v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله): این همون لحظه‌ی «باز شدن واقعی» این
         // پندینگه (نه لحظه‌ی ثبتش در AutoExecute، که فقط placeholder گذاشته بود) - پس همین‌جا،
         // قبل از هر تغییر state (RunEntryIntervalCheck زیرش g_lastEntryTime/شمارنده‌ها رو
         // مستقیم عوض می‌کنه)، فیلدهای رفتاری Snapshot این تیکت با وضعیت زنده‌ی همین لحظه پر می‌شن.
         bool   isContinuationFill = IsContinuationTicket(tk);  // v90 (FEAT-044)
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
         // v61: خودِ تخلف Entry Interval توسط RunEntryIntervalCheck زیر شمارش می‌شه (تا دوبار
         // شمرده نشه) - اینجا فقط رویداد «باز شدن وسط قفل Cooldown» که هیچ مسیر دیگه‌ای برای
         // شمارشش وجود نداره اضافه می‌شه.
         if(duringLock) IncrementBehaviorErrorTotal();

         // همین الان فعال شد - این لحظه‌ی واقعی ورود محسوب می‌شه
         RunEntryIntervalCheck(isContinuationFill);  // v90 (FEAT-044): ورود ادامه معاف
         PlaySound(SND_ORDER_FILLED);  // v45 (Punch List Round 3, Item 8)
         RemovePendingTrackAt(i);
      }
      else if(OrderCloseTime() > 0)
      {
         // قبل از فعال‌شدن حذف/منقضی شده (مثلاً Del Pending یا انقضای بروکر) - شمارش نمی‌شه
         HandleVanishedContinuationPending(tk);  // v90 (FEAT-044)
         RemovePendingTrackAt(i);
      }
      // در غیر این صورت هنوز پندینگه؛ صبر می‌کنیم
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

void CheckPrematureAction(int ticket, string actionTag)
{
   RM_EnsureSnapshot(ticket);  // v101 (BUG-054): تیکت ممکن است روی چارت دیگر باز شده باشد؛ بدون Snapshot محافظه‌کارانه «زودهنگام نیست» می‌شد و Strike گم می‌شد
   if(!IsPrematureBeforeOneR(ticket)) return;
   // v90 (FEAT-044): ورود ادامه (Scale-in) از Strike اقدام زودهنگام معاف است (باقی‌مانده‌ی Half Close آن هم همین پرچم را دارد)
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
// همچنان با همین الگوی save/load ساده نوشته/خونده می‌شن. v77: این سه کلید حالا account-scoped
// شدن (A<حساب>_M<مجیک>_<نماد>، ساخته‌شده در BuildAccountScopedKeys()) - رفتارِ per-chart داخلِ
// یک اکانت حفظ شده، فقط دیگه بین دو اکانتِ هم‌نماد روی یک ترمینال نشت نمی‌کنن.
void SaveCooldownState()
{
   GlobalVariableSet(GV_MKT_END,   (double)g_mktCooldownEnd);
   GlobalVariableSet(GV_BEH_END,   (double)g_behCooldownEnd);
   GlobalVariableSet(GV_LAST_ENTRY,(double)g_lastEntryTime);
}

void LoadCooldownState()
{
   // v77 (ریشه‌ی واقعیِ strikeِ کاذبِ بین‌اکانتی): این سه متغیرِ درون‌حافظه‌ای با سوییچِ حساب صفر
   // نمی‌شن (باینریِ EA دوباره لود نمی‌شه، فقط OnDeinit/OnInit صدا زده می‌شه). قبلاً اینجا الگوی
   // «if(check) load» بود؛ اگه کلیدِ حساب‌محورِ این اکانت وجود نداشت (اکانتِ تازه‌ای که هنوز ترید
   // نکرده)، بلاک رد می‌شد و مقدارِ اکانتِ *قبلی* در حافظه می‌موند → g_lastEntryTime کهنه → strikeِ
   // کاذبِ «0min». حالا مثل RefreshSharedCooldownState از الگوی authoritativeِ «check ? get : 0»
   // استفاده می‌شه: کلیدِ غایب صریحاً صفر می‌ده، پس هیچ نشتی از اکانتِ قبلی نمی‌مونه.
   g_mktCooldownEnd = GlobalVariableCheck(GV_MKT_END)    ? (datetime)GlobalVariableGet(GV_MKT_END)    : 0;
   g_behCooldownEnd = GlobalVariableCheck(GV_BEH_END)    ? (datetime)GlobalVariableGet(GV_BEH_END)    : 0;
   g_lastEntryTime  = GlobalVariableCheck(GV_LAST_ENTRY) ? (datetime)GlobalVariableGet(GV_LAST_ENTRY) : 0;

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
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      int tk = OrderTicket();

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
            g_trackedSL[j] = OrderStopLoss();
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
         g_trackedTickets[g_trackedCount] = tk;
         g_trackedSL[g_trackedCount]      = OrderStopLoss();
         g_trackedEntry[g_trackedCount]   = OrderOpenPrice();
         g_trackedBuy[g_trackedCount]     = (OrderType()==OP_BUY);
         g_trackedCount++;
      }
   }
}

// v87 (FEAT-042 فاز ۲): Market Cooldown زنجیره‌ای - فقط برای زنجیره‌های چندتیکتی (ChainMemberCount > 1).
// بعد از بسته‌شدن «کامل» زنجیره (IsChainFullyClosed) یک‌بار فراخوانی اثر می‌کند: برایند R کل زنجیره = سود خالص مجموع بخش‌ها (سود+سواپ+کمیسیون،
// از History) تقسیم بر RiskUSD کامل Snapshot (مشترک همه‌ی بخش‌ها). اگر برایند منفی‌تر از -0.1R باشد، شمارنده به اندازه‌ی
// min(1, |ضرر برحسب R|) x RiskWeight زیاد می‌شود؛ وگرنه استاپ حساب نمی‌شود. Behavior/EarlyExit تیکت‌به‌تیکت و دست‌نخورده‌اند.
// کلید RM_CHAINMKT_<ریشه> (GlobalVariable) تضمین می‌کند اگر دو بخش در یک تیک بسته شدند یا EA ری‌استارت شد، زنجیره دوبار شمرده نشود.
#define CHAIN_MKT_MIN_LOSS_R 0.10
// v90 (FEAT-044): پارامتر دوم fromPendingGone (پیش‌فرض false). وقتی true است یعنی یک ورود ادامه‌ی Pending بدون پر شدن از زنجیره جدا شد و
// زنجیره‌ی هدف حالا تک‌تیکتی شده؛ فقط اگر همان هدف قبلاً با SL بسته و به‌خاطر عضو Pending «به تعویق افتاده» (کلید RM_CHAINDEFER_) باشد،
// با همان فرمول زنجیره‌ای ارزیابی می‌شود. پایه‌ی R همیشه Snapshot ریشه است (نه «اولین عضو دارای RiskUSD»).
void ProcessChainMarketStop(int tk, bool fromPendingGone=false)
{
   int root = GetRootTicket(tk);
   string deferKey = SnapScope() + "RM_CHAINDEFER_" + IntegerToString(root);
   if(fromPendingGone)
   {
      if(!GlobalVariableCheck(deferKey)) return;     // هدف با SL تعویق‌شده نبود - چیزی برای ارزیابی عقب‌افتاده نیست
   }
   else if(ChainMemberCount(root) <= 1) return;     // معامله‌ی تکی - قانون قبلی (hitSL) قبلاً اعمال شده
   if(!IsChainFullyClosed(root)) return;             // منتظر آخرین بخش
   string doneKey = SnapScope() + "RM_CHAINMKT_" + IntegerToString(root);
   if(GlobalVariableCheck(doneKey))                  // این زنجیره قبلاً محاسبه شده
   {
      Print("[RM-MI] chain #", root, " stop skipped on ", RM_InstTag(), " (already counted by ", RM_TfName(GlobalVariableGet(doneKey)), ")");
      return;
   }

   double   netUSD = 0.0;
   datetime lastClose = 0;
   int      idxRisk = -1;
   for(int m=0;m<g_snapCount;m++)
   {
      int rm = (g_snapRootTicket[m] > 0) ? g_snapRootTicket[m] : g_snapTickets[m];
      if(rm != root) continue;
      if(!OrderSelect(g_snapTickets[m], SELECT_BY_TICKET, MODE_HISTORY) || OrderCloseTime() <= 0)
      {
         Print("RM WARNING: ProcessChainMarketStop - chain root #", root, " member #", g_snapTickets[m],
               " not found in history; chain Market Cooldown NOT evaluated");
         return;
      }
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;  // v90: ورود ادامه‌ی Pending که هیچ‌وقت پر نشد (سود/ریسک ندارد)
      netUSD += OrderProfit()+OrderSwap()+OrderCommission();
      if(OrderCloseTime() > lastClose) lastClose = OrderCloseTime();
      if(idxRisk < 0 && g_snapRiskUSD[m] > 0) idxRisk = m;
   }
   // v90 (FEAT-044): پایه‌ی R = RiskBaseUSD Snapshot ریشه (صریحاً)، نه اولین عضوِ دارای RiskUSD. فقط اگر Snapshot ریشه موجود نبود به همان رفتار قبلی فال‌بک می‌شود.
   int idxRootSnap = FindSnapshotIndex(root);
   if(idxRootSnap >= 0 && SnapRiskBase(idxRootSnap) > 0) idxRisk = idxRootSnap;
   else if(idxRisk >= 0) Print("RM WARNING: ProcessChainMarketStop - root #", root, " Snapshot missing/zero risk; falling back to first member with risk");
   // v101 (BUG-054): قبلاً «Check بالا ... Set اینجا» اتمیک نبود و دو نمونه‌ی هم‌نماد می‌توانستند هر دو از Check رد شوند و
   // زنجیره دوبار شمرده شود. حالا claim اتمیک (mutex + بازخوانی)؛ مقدار کلید = کد تایم‌فریم نمونه‌ی برنده (قبلاً 1.0؛
   // هر مقدار غیرصفر معنی «انجام شده» را می‌دهد، سازگار با GVهای قدیمی).
   double chainOwner = 0.0;
   if(!RM_ClaimKey(doneKey, (double)Period(), chainOwner))   // هر نتیجه‌ای (استاپ یا نه) فقط یک‌بار ثبت می‌شود
   {
      Print("[RM-MI] chain #", root, " stop skipped on ", RM_InstTag(), " (already counted by ", RM_TfName(chainOwner), ")");
      return;
   }
   Print("[RM-MI] chain #", root, " stop counted by ", RM_InstTag());

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

// v101: حذف ردیف j از لیست ردیابی این نمونه (بلوک قبلی انتهای CheckClosedTrades، بدون تغییر منطق)
void RM_RemoveTrackedAt(int j)
{
   for(int k=j;k<g_trackedCount-1;k++)
   {
      g_trackedTickets[k] = g_trackedTickets[k+1];
      g_trackedSL[k]      = g_trackedSL[k+1];
      g_trackedEntry[k]   = g_trackedEntry[k+1];
      g_trackedBuy[k]     = g_trackedBuy[k+1];
   }
   g_trackedCount--;
   ArrayResize(g_trackedTickets, g_trackedCount);
   ArrayResize(g_trackedSL,      g_trackedCount);
   ArrayResize(g_trackedEntry,   g_trackedCount);
   ArrayResize(g_trackedBuy,     g_trackedCount);
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
      int tk = g_trackedTickets[j];
      // check if still open
      bool stillOpen = false;
      for(int i=0;i<OrdersTotal();i++)
      {
         if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
         if(OrderTicket()==tk){ stillOpen=true; break; }
      }
      if(stillOpen) continue;

      // v68: anyClosedThisTick (Auto Export CSV) - v101: حالا فقط وقتی true می‌شود که *این نمونه* claim آن تیکت را گرفته باشد
      // (پایین‌تر)، تا Export فایل CSV توسط چند نمونه هم‌زمان و با Snapshot ناقص بازنویسی نشود.

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

      // v8 (BUG-010 fix #2): آبجکت‌های خودکار خود MT4 مربوط به این تیکت هم پاک بشن
      // (مثل فلش/خط "#تیکت sl modified" که ترمینال موقع هر OrderModify خودش می‌سازه)
      string tickStrClosed = "#"+IntegerToString(tk);
      for(int oi=ObjectsTotal()-1; oi>=0; oi--)
      {
         string objNameClosed = ObjectName(oi);
         if(StringFind(objNameClosed, tickStrClosed) >= 0)
            ObjectDelete(0, objNameClosed);
      }
      ChartRedraw();

      // closed - read history
      if(!OrderSelect(tk,SELECT_BY_TICKET,MODE_HISTORY)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;

      // v62 (تفکیک ExitReason - EmergencyClose): همین‌جا، قبل از هر منطق طبقه‌بندی/شمارش موجود
      // (که دست‌نخورده می‌مونه)، فقط چک می‌کنیم آیا این تیکت توسط EmergencyCloseAll بسته شده -
      // اگه بله، پرچم persisted ثبت می‌شه تا بعداً ExportTradeJournalCSV بتونه Result رو
      // "EmergencyClose" بنویسه به‌جای EarlyExit. هیچ اثری روی hitSL/hitTP/شمارنده‌های
      // Market-Behavior Cooldown زیر این بلوک نداره.
      // v101: این مصرف+پرچم‌گذاری روی *همه‌ی* نمونه‌ها (قبل از claim) اجرا می‌شود - idempotent است (GlobalVariableSet
      // یک پرچم)، و هر نمونه‌ای که EmergencyCloseAll را اجرا کرده تیکت را در آرایه‌ی موقت خودش دارد؛ نمونه‌ی claim-winner
      // لزوماً همان نمونه‌ی بسنده نیست.
      if(ConsumeEmergencyClosedTicket(tk))
         MarkEmergencyClosed(tk);

      // === v101 (BUG-054): claim دقیقاً-یک‌بار ===========================================================
      // از این‌جا به بعد اثرهای «یک‌باره» (اسکرین‌شات، Spread، شمارنده‌های Market/Behavior، زنجیره، صدا، Export CSV)
      // شروع می‌شوند. فقط نمونه‌ای که اول claim را بگیرد ادامه می‌دهد؛ بقیه فقط حافظه‌ی محلی‌شان را پاک می‌کنند
      // (پاک‌سازی آبجکت‌های همین چارت و لیست‌های Trail/AutoHalf/... بالاتر انجام شد - per-chart/per-instance است).
      double miOwner = 0.0;
      if(!RM_ClaimCloseTicket(tk, miOwner))
      {
         Print("[RM-MI] close #", tk, " skipped on ", RM_InstTag(), " (already claimed by ", RM_TfName(miOwner), ")");
         RemoveHalfExemptLocal(tk);   // فقط حافظه‌ی محلی؛ GV را claim-winner موقع پردازش پاک می‌کند
         RM_RemoveTrackedAt(j);
         continue;
      }
      anyClosedThisTick = true;      // v68 (فقط نمونه‌ی claim-winner Export می‌کند)
      string miOutcome = "unclassified";
      // Snapshot ممکن است روی چارت دیگر ساخته/به‌روز شده باشد (R، RootTicket، Striked، MaxFavR، اعضای زنجیره) - قبل از هر
      // طبقه‌بندی از GV مشترک (منبع واقعی) بارگذاری/تازه‌سازی می‌شود. رویداد-محور (فقط لحظه‌ی close)، نه هر تیک.
      RM_SyncSnapshotsFromGV();
      RM_RefreshChainSnapshots(tk);

      // v59 (Item 2 - Chart Screenshot at Exit): همین لحظه‌ای که بسته‌شدن این تیکت تشخیص داده شد -
      // Exit، نه Entry - از وضعیت فعلی چارت عکس گرفته می‌شه (RM_Tools.mqh)
      TakeExitScreenshot(tk);

      // BUG-052/FEAT-036 (v82): همون لحظه‌ی دقیق بالا - اسپرد زنده‌ی همین الان (Ask-Bid) به‌عنوان
      // بهترین تخمین "اسپرد لحظه‌ی بسته‌شدن" این تیکت ثبت می‌شه (persisted - جزئیات فلسفه بالای
      // GetSpreadAtClose). فقط ثبت؛ هیچ اثری روی منطق طبقه‌بندی/کولداون زیر این خط نداره.
      RecordSpreadAtClose(tk, Ask-Bid);

      // v88 (BUG-058): TakeExitScreenshot() بالا از مسیر BuildEntryExitMarkers() روی همه‌ی سفارش‌های History و بعد سفارش‌های باز
      // OrderSelect می‌زند و «سفارش جاری» را عوض می‌کند. اگر همان لحظه پوزیشن باز دیگری وجود داشت، OrderClosePrice()/OrderProfit()/
      // OrderTakeProfit() پایین از آن پوزیشن خوانده می‌شد (نه تیکت بسته‌شده) و SL به‌اشتباه TP/+1R یا EarlyExit طبقه‌بندی می‌شد
      // (Market Cooldown نمی‌شمرد، Behavior به‌جای Strike ریست می‌شد). تیکت دوباره انتخاب می‌شود.
      if(!OrderSelect(tk,SELECT_BY_TICKET,MODE_HISTORY)) continue;

      double openPrice  = g_trackedEntry[j];
      double slPrice    = g_trackedSL[j];
      bool   isBuy      = g_trackedBuy[j];
      double closePrice = OrderClosePrice();
      // v17 (BUG-013 + BUG-020 fix): net result now includes swap+commission,
      // matching the BUG-019 fix already applied to Daily/Weekly/Monthly and Floating P/L.
      double profit     = OrderProfit()+OrderSwap()+OrderCommission();

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
         // BUG-052 (v82 fix): آستانه‌ی بالا هنوز غیرجهت‌داره (|close-SL|<=tol) - یعنی یک fill
         // که ۱۰٪+origDist آن‌سوی SL (بدتر، با اسلیپیج) بسته شده هم همون‌قدر رد می‌شد که یک fill
         // در جهت مخالف (بهتر از SL - عملاً EarlyExit واقعی). ممیزی اجرا (حساب A4160750، فوریه تا
         // آگوست ۲۰۲۶، ۲۷۳ معامله) نشون داد ۸۴٪ استاپ‌ها (۱۰۹ از ۱۳۰) دقیقاً همین حالت بودن - آن‌سوی
         // SL با اسلیپیج، ولی چون از تلورانس غیرجهت‌دار رد می‌زدن، به‌غلط EarlyExit ثبت می‌شدن (+
         // خطای رفتاری روی معامله‌ای که در واقع استاپ درست‌وحسابی بود). فیکس: جهت‌دار شد - «روی یا
         // آن‌سوی SL» (برابر یا بدتر از سطح) = SL؛ فقط فیل در جهت مخالف (بهتر از سطح طراحی‌شده،
         // یعنی تلورانس نویز معمولی بروکر) نباید SL حساب بشه.
         hitSL     = isBuy ? (closePrice <= slPrice + tolPrice)
                            : (closePrice >= slPrice - tolPrice);
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
         // BUG-052 (v82 fix): همون فیکس جهت‌دار بالا - مسیر fallback (بدون Snapshot معتبر) هم
         // باید همون قرارداد رو داشته باشه، وگرنه معاملات قدیمی‌تر (قبل از v11) از این باگ در امان
         // نمی‌موندن.
         hitSL    = isBuy ? (closePrice <= slPrice + tolPrice)
                           : (closePrice >= slPrice - tolPrice);
         double pipVal = GetPipValueForSymbol(Symbol(), Point, PipFactor());
         oneR      = origDist/Point/PipFactor() * pipVal * OrderLots();
         reached1R = (profit >= oneR * 0.95);
      }

      // v52 (BUG-045 fix, consistency): hitTP now uses a tolerance based on the
      // TP-to-entry price distance (same 10% pattern as hitSL above), instead of
      // reusing the SL-based tolPrice. Keeps SL and TP checks independent of each
      // other's distance, and both are now purely price-based (no $ involved).
      double tpPriceVal = OrderTakeProfit();
      bool   hitTP;
      if(tpPriceVal > 0)
      {
         double tpDist = MathAbs(tpPriceVal - openPrice);
         double tpTol  = tpDist * 0.10;
         // BUG-052 (v82 fix): قرینه‌ی فیکس SL بالا - «روی یا آن‌سوی TP» (برابر یا بهتر از هدف) = TP؛
         // فقط فیل در جهت مخالف (بدتر از TP) نباید TP حساب بشه.
         hitTP = isBuy ? (closePrice >= tpPriceVal - tpTol)
                       : (closePrice <= tpPriceVal + tpTol);
      }
      else
      {
         hitTP = false; // no TP was set on this order - can't have hit it
      }

      // v103 (BUG-053): آیا آخرین SL هنوز سمت ضرر ورود بوده؟ (فقط مقایسه‌ی قیمت؛ اسپرد/کمیسیون بی‌اثر - BUG-045).
      // slPrice = آخرین SL (هر تیک در TrackOpenTrades همگام می‌شود). SL دقیقاً روی ورود (BE خالص) = سمت ضرر نیست.
      // SL منتقل‌شده به BE/سود (دستی، Auto BE، Trailing) = «استاپ محافظت‌شده» -> شمارنده‌ی Market را زیاد نمی‌کند.
      bool slOnLossSide = isBuy ? (slPrice < openPrice) : (slPrice > openPrice);

      if(hitSL && !hitTP && slOnLossSide)
      {
         // Market Cooldown: full stop
         // v19 (BUG-022): a Half Risk stop is a deliberately cautious trade - it adds only
         // 0.5 to the streak instead of the usual 1.0. A ticket with no Snapshot (pre-v19
         // legacy) falls back to the full 1.0, same conservative philosophy used elsewhere
         // in the Snapshot system (treat as Full Risk when we can't tell).
         // v87 (FEAT-042 فاز ۲): بخشی از زنجیره‌ی چندتیکتی -> شمارش Market برای این تیکت انجام نمی‌شود؛ بعد از بسته‌شدن کامل زنجیره
         // یک‌بار بر اساس برایند کل محاسبه می‌شود (ProcessChainMarketStop پایین). معامله‌ی تکی دقیقاً مثل قبل (بلوک زیر بدون تغییر).
         bool chainDeferMkt = (ChainMemberCount(GetRootTicket(tk)) > 1);
         // v90 (FEAT-044): علامت «تعویق‌شده» - اگر بعداً عضو Pending بدون پر شدن ناپدید شد، HandleVanishedContinuationPending با همین علامت می‌فهمد این SL باید ارزیابی شود.
         if(chainDeferMkt) GlobalVariableSet(SnapScope() + "RM_CHAINDEFER_" + IntegerToString(GetRootTicket(tk)), 1.0);
         if(!chainDeferMkt)
         {
         double mktIncrement = 1.0;
         if(snapIdx >= 0) mktIncrement = SnapRiskWeight(snapIdx);  // v84 (FEAT-038 Addendum): وزن دقیق پله (1/0.5/0.25/0.125)؛ Snapshot قدیمی -> ۰.۵ اگه WasHalfRisk، وگرنه ۱.۰ (رفتار قبلی)
         // v53: افزایش امن (CAS) روی شمارنده‌ی Market مشترک بین چارت‌ها
         g_mktStopCount = CAS_AddToGlobal(GV_MKT_COUNT, mktIncrement);
         g_lastStopCloseTime = OrderCloseTime(); // v13 (BUG-017): reference point for the time-based streak reset
         CAS_SetGlobal(GV_LAST_STOP_CLOSE, (double)g_lastStopCloseTime); // v53: کمکی مستقیم‌ِ شمارنده هم همراهش به GV مشترک نوشته می‌شه
         // stop = correct, reset Behavior - v53: این ریست هم account-wide شد (طبق تصمیم چت اصلی:
         // "SL درست = ریست Behavior" روی همون شمارنده‌ی مشترک اعمال بشه)
         }
         miOutcome = chainDeferMkt ? "Reset(SL), Market stop deferred to chain" : "Reset(SL)";  // v101 [RM-MI]
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
         // v103 (BUG-053): استاپ محافظت‌شده (SL روی BE یا سمت سود). شمارنده‌ی Market و g_lastStopCloseTime دست‌نخورده؛
         // Behavior مثل استاپ درست ریست می‌شود؛ هرگز EarlyExit/Strike نمی‌شود.
         miOutcome = "Reset(SL-protected)";  // v101 [RM-MI]
         int behBeforePS = g_behCount;
         g_behCount = (int)MathRound(CAS_SetGlobal(GV_BEH_COUNT, 0.0));
         Print("[DEBUG-BEHCOUNT] Reset (SL-protected) | ticket=#"+IntegerToString(tk)+" | before="+IntegerToString(behBeforePS)+" after="+IntegerToString(g_behCount));
         Print("[RM-MC] ticket=#"+IntegerToString(tk)+" protectedStop sl="+DoubleToString(slPrice,Digits)+" open="+DoubleToString(openPrice,Digits)
               +" close="+DoubleToString(closePrice,Digits)+" profit="+DoubleToString(profit,2)+" mktCountUnchanged="+DoubleToString(g_mktStopCount,2));
         RemoveHalfExempt(tk);
         SaveCooldownState();
         PlaySound(profit >= 0 ? SND_TARGET_REACHED : SND_STOP_LOSS);
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
         miOutcome = "Reset(+1R/TP)";  // v101 [RM-MI]
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
         if(IsHalfExempt(tk))
         {
            miOutcome = "Exempt(HalfClose@TP1+)";  // v101 [RM-MI]
            RemoveHalfExempt(tk);
            SaveCooldownState();
         }
         else if(snapIdx >= 0 && g_snapIsContinuation[snapIdx])
         {
            // v90 (FEAT-044): خروج زودهنگام یک ورود ادامه (Scale-in) Strike رفتاری ندارد
            miOutcome = "Exempt(ScaleIn)";  // v101 [RM-MI]
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
               miOutcome = "NoStrike(AlreadyStruck)";  // v101 [RM-MI]
               Print("RM: EarlyExit close (ticket #"+IntegerToString(tk)+") - trade already struck via CheckPrematureAction, no additional GV_BEH_COUNT increment"); // v65 (BUG-049 fix)
               // v64 (آیتم ۵): شمارنده‌ی جدای گزارش‌گیری v61 (GV_BEHERR_TOTAL) مستقل از
               // GV_BEH_COUNT است و اسکوپ این فیکس نیست - همچنان طبق رفتار قبلی +۱ می‌شه.
               IncrementBehaviorErrorTotal();
               SaveCooldownState();
            }
            else
            {
               miOutcome = "Strike(EarlyExit)";  // v101 [RM-MI]
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

      Print("[RM-MI] close #", tk, " claimed by ", RM_InstTag(), " -> processed (", miOutcome, ")");

      ProcessChainMarketStop(tk);  // v87 (FEAT-042 فاز ۲): Market Cooldown زنجیره‌ای (فقط وقتی زنجیره‌ی چندتیکتی کاملاً بسته شد)

      // v64 (آیتم ۴ - BehaviorErrorsThisTrade): *بعد* از کل زنجیره‌ی طبقه‌بندی بالا (نه قبلش) -
      // چون آیتم ۵ (بالا) حالا ممکنه همین لحظه GV_BEHERR_TOTAL رو برای همین تیکت افزایش داده
      // باشه (شاخه‌ی EarlyExit)؛ برای این‌که سهم خودِ همین معامله واقعاً لحاظ بشه، باید بعد از
      // اون افزایش خونده بشه، نه قبلش. مقدار زنده‌ی GetBehaviorErrorTotal() منهای همون
      // BehaviorErrorCountAtOpen که لحظه‌ی باز شدن این تیکت ثبت شده بود = «چند خطای جدید
      // مختص خودِ این معامله».
      if(snapIdx>=0)
         SetSnapshotBehaviorErrorsThisTrade(tk, GetBehaviorErrorTotal() - g_snapBehaviorErrorCountAtOpen[snapIdx]);

      // remove from tracked list
      RM_RemoveTrackedAt(j);  // v101: همان بلوک قبلی، به تابع منتقل شد تا مسیر «claim نشد» هم از آن استفاده کند
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

