//+------------------------------------------------------------------+
//| RM_Snapshot.mqh                                                    |
//| Risk Manager EA - Trade Snapshot (Architecture Refactor, R3)       |
//| استخراج‌شده از RiskManager_EA_v45_R2.mq4 - لایه‌ی داده‌ی مستقل Trade  |
//| Snapshot: آرایه‌های خام + توابع ذخیره/بازیابی/خواندن. بقیه‌ی ماژول‌ها  |
//| (Cooldown، Reports، Trailing و...) فقط مصرف‌کننده‌ی این لایه‌ان، نه   |
//| صاحبش. صرفاً جابه‌جایی کد، بدون هیچ تغییر مقدار/رفتار (Golden Rule فاز R3).|
//+------------------------------------------------------------------+

// === v11 (FEAT-016): Trade Snapshot - رکورد تغییرناپذیر هر معامله در لحظه‌ی باز شدن ===
// هیچ‌کدوم از این مقادیر بعد از ثبت اولیه عوض نمی‌شن (نه با جابه‌جایی دستی SL، نه BE، نه Trailing).
// فقط برای محاسبه‌ی R استفاده می‌شن؛ در GlobalVariable هم پایدار می‌شن تا بعد از ری‌استارت EA نمونن.
int      g_snapTickets[];
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
// جهت کاهش به‌روزرسانی می‌شه (هیچ‌وقت بالا نمی‌ره). دقیقاً هم‌الگو: تیک‌به‌تیک آپدیت می‌شه
// (UpdateSnapshotMinFavorableR، صدا زده‌شده کنار UpdateSnapshotMaxFavorableR از TrackOpenTrades)،
// در Trade Snapshot ذخیره می‌شه، و به تیکت باقیمونده‌ی Half Close ارث می‌رسه - هیچ محاسبه‌ای بعد
// از بسته‌شدن معامله انجام نمی‌شه (برخلاف تلاش rolled-back قبلی Post-Exit MFE).
double   g_snapMinFavR[];
// v18 (BUG-021 refinement): آیا این معامله (تیکت) از قبل یک Behavior Strike به‌خاطر
// اقدام زودهنگام گرفته؟ یک معامله فقط یک‌بار می‌تونه به این خاطر Strike بگیره - حتی اگه
// چند اقدام مدیریتی زودهنگام (مثلاً هم BE هم Half Close قبل از +1R) روش اتفاق بیفته،
// همه‌شون یک تصمیم رفتاری‌ان (مدیریت زودهنگام)، نه چند مورد جدا. با تیکت جدید (معامله‌ی
// بعدی) خودکار false شروع می‌شه - نیازی به ریست دستی نیست چون شماره‌ی تیکت هیچ‌وقت تکرار نمی‌شه.
bool     g_snapStriked[];
// v19 (BUG-022): آیا این معامله در لحظه‌ی باز شدنش با Half Risk فعال بوده؟ مستقیماً از
// g_halfRiskActive در همون لحظه‌ی OrderSend گرفته می‌شه - هیچ‌وقت بعداً از روی درصد ریسک
// یا حجم لات استنتاج نمی‌شه. مثل بقیه‌ی فیلدهای Snapshot، تغییرناپذیره؛ باقیمونده‌ی Half
// Close هم همین مقدار رو از معامله‌ی اصلی به ارث می‌بره.
bool     g_snapWasHalfRisk[];
// v84 (FEAT-038 Addendum): وزن دقیق پله‌ی ریسک لحظه‌ی «باز شدن» معامله نسبت به Full (1.0 / 0.5 / 0.25 / 0.125)،
// از g_riskStep همان لحظه‌ی OrderSend گرفته می‌شه (نه لحظه‌ی بسته‌شدن). مقدار -1 یعنی «ثبت نشده» (Snapshot
// پیش از v84) و فقط در همین حالت SnapRiskWeight() به WasHalfRisk بولین فال‌بک می‌کنه (true=0.5, false=1.0).
double   g_snapRiskWeight[];
// v86 (FEAT-042 فاز ۱): تیکت ریشه‌ی زنجیره‌ی Half Close. معامله‌ی تازه: ریشه = خودِ تیکت. باقی‌مانده‌ی Half Close:
// ریشه = ریشه‌ی تیکت قبلی (پس با Half Close پشت‌سرهم همیشه همان تیکت اول می‌ماند). Snapshot قبل از v86 کلید ندارد -> ریشه = خودش.
int      g_snapRootTicket[];
// v90 (FEAT-044 فاز ۱ - Scale-in): آیا این تیکت «ورود ادامه» است (با ریسک آزاد‌شده‌ی یک زنجیره باز شده)؟ برای معافیت از Strike
// فاصله‌ی ورود و EarlyExit. باقی‌مانده‌ی Half Close آن هم همین پرچم را به ارث می‌برد.
bool     g_snapIsContinuation[];
// v90 (FEAT-044): پایه‌ی R زنجیره (دلار). معامله‌ی عادی = RiskUSD خودش؛ ورود ادامه و باقی‌مانده‌اش = RiskBaseUSD ریشه.
// ۰ یا ثبت‌نشده (Snapshot پیش از v90) -> SnapRiskBase() به RiskUSD خود تیکت فال‌بک می‌کند.
double   g_snapRiskBaseUSD[];
// v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله - اولین از سه ورژن): شش فیلد جدید که همگی در
// لحظه‌ی «باز شدن واقعی» معامله (نه صرفاً لحظه‌ی ثبت اردر - برای Pending این دو با هم فرق
// دارن) خونده می‌شن. برای Market، این دو لحظه یکی‌ان پس مقدار واقعی همون‌جا (AutoExecute)
// پر می‌شه؛ برای Pending، لحظه‌ی ثبت فقط placeholder می‌ذاره و مقدار واقعی بعداً در لحظه‌ی
// فعال‌شدن واقعی (CheckPendingActivation) با SetSnapshotBehaviorFieldsAtActivation پر می‌شه.
double   g_snapBehaviorErrorCountAtOpen[];  // شمارنده‌ی یکپارچه‌ی رویدادهای رفتاری واقعی تا همین لحظه (قبل از خود این معامله)
bool     g_snapOpenedDuringCooldownLock[];  // آیا لحظه‌ی باز شدن این معامله، یک قفل Cooldown (Market/Behavior) فعال بوده؟
bool     g_snapEntryIntervalViolation[];    // آیا این معامله‌ی خاص چک Entry Interval رو نقض کرده؟
// برخلاف ۵ فیلد دیگه‌ی این بلوک، SLTampered ذاتاً در لحظه‌ی باز شدن معلوم نیست - فقط بعداً
// (هر زمان CheckSLTampering تشخیص بده) با MarkSnapshotTampered پر می‌شه؛ مثل g_snapStriked،
// mutable ولی فقط در جهت false->true.
bool     g_snapSLTampered[];
double   g_snapDailyRiskUsedPctAtOpen[];    // چند درصد از سقف ریسک روزانه، لحظه‌ی باز شدن این معامله مصرف شده بود
double   g_snapWeeklyDDUsedPctAtOpen[];     // چند درصد از سقف Drawdown هفتگی، لحظه‌ی باز شدن این معامله مصرف شده بود
// v64 (آیتم ۱ - PriorDayResult): نتیجه‌ی خالص روز معاملاتیِ *قبل*، لحظه‌ی باز شدن این معامله
// (نه لحظه‌ی ثبت اردر برای Pending - دقیقاً هم‌الگوی ۵ فیلد رفتاری v61 بالا). کد عددی چون
// GlobalVariable در MT4 فقط double قبول می‌کنه: -2=N/A، -1=Loss، 0=Breakeven، 1=Win.
double   g_snapPriorDayResult[];
// v64 (آیتم ۳ - SLLoosenedCount): شمارنده‌ی دفعاتی که SL این تیکت در جهت افزایش ریسک (دورتر از
// قیمت) جابه‌جا شده - چه مجاز چه غیرمجاز. برخلاف بقیه‌ی فیلدهای این بلوک، این یکی به‌جای «ثبت
// یک‌بار در لحظه‌ی باز شدن»، در طول عمر تیکت افزایش پیدا می‌کنه (mutable، فقط در جهت افزایش) -
// دقیقاً هم‌الگوی g_snapMaxFavR بالا، فقط با شمارش به‌جای max.
int      g_snapSLLoosenedCount[];
// v64 (آیتم ۴ - BehaviorErrorsThisTrade): برخلاف بقیه‌ی این بلوک که «لحظه‌ی باز شدن» ثبت می‌شن،
// این یکی «لحظه‌ی بسته‌شدن» یک‌بار محاسبه و ثبت می‌شه (توسط SetSnapshotBehaviorErrorsThisTrade
// در CheckClosedTrades - RM_CooldownEngine.mqh). سنتینل -1 = هنوز محاسبه نشده (تیکت هنوز بازه،
// یا هیچ‌وقت با v64+ بسته نشده - مثل تیکت‌های تاریخی قبل از نصب این ورژن)؛ چون مقدار واقعی
// همیشه >=0 هست (تفاضل یه شمارنده‌ی هرگز-ریست-نشونده از دو لحظه‌ی متوالی)، -1 هیچ‌وقت با یه
// مقدار واقعی تداخل نداره.
double   g_snapBehaviorErrorsThisTrade[];
// v64 (آیتم ۶ - TimeframeAtOpen): تایم‌فریم چارت لحظه‌ی باز شدن واقعی معامله (Period()، عدد خام -
// چون GlobalVariable فقط double قبول می‌کنه؛ تبدیل به رشته‌ی خوانا فقط لحظه‌ی نمایش/CSV با
// TimeframeCodeToString پایین انجام می‌شه). سنتینل 0 = هنوز ثبت نشده (placeholder برای Pending
// قبل از فعال‌شدن واقعی) - چون هیچ Period() معتبری صفر نیست (کمترین مقدار PERIOD_M1=1).
double   g_snapTimeframeAtOpen[];
int      g_snapCount = 0;

//+------------------------------------------------------------------+
// v11 (FEAT-016): Trade Snapshot System
// شماره‌ی تیکت در کل یک حساب یکتاست، پس در ابتدا کلید فقط بر اساس تیکت ساخته می‌شد.
// v77 (اصلاحِ تداخلِ بین‌اکانتی - دسته ۴): شماره‌ی تیکت بین بروکرها/اکانت‌های مختلف *می‌تونه* تکراری
// باشه (عدد ۸رقمیِ شانسیِ یکسان). دو اکانتِ روی یک ترمینال با تیکتِ یکسان، اسنپ‌شاتِ هم رو می‌خوندن
// → ثبتِ ژورنالِ خراب. حالا scopeِ A<حساب>_M<مجیک>_ جلوی کلید اضافه شد (SnapScope) تا هر اکانت
// namespace جدا داشته باشه. scope *جلوی* کلید گذاشته شد تا prefix-scanِ LoadTradeSnapshots (که تیکت
// رو با بریدنِ prefix درمی‌آره) بعد از افزودنِ همون scope به prefix، همچنان درست کار کنه.
// (SnapScope تابع است، نه رشته‌ی global - پس مثل کلیدهای حساب‌محورِ EA دچار مشکلِ stale-string نمی‌شه.)
//+------------------------------------------------------------------+
string SnapScope() { return "A" + IntegerToString(AccountNumber()) + "_M" + IntegerToString(MagicNumber) + "_"; }
string SnapKeyEntry(int ticket)    { return SnapScope() + "RM_SNAP_ENTRY_"    + IntegerToString(ticket); }
string SnapKeySL(int ticket)       { return SnapScope() + "RM_SNAP_SL_"       + IntegerToString(ticket); }
string SnapKeyRiskUSD(int ticket)  { return SnapScope() + "RM_SNAP_RISKUSD_"  + IntegerToString(ticket); }
string SnapKeyRiskPct(int ticket)  { return SnapScope() + "RM_SNAP_RISKPCT_"  + IntegerToString(ticket); }
string SnapKeyOpenTime(int ticket) { return SnapScope() + "RM_SNAP_OPENTIME_" + IntegerToString(ticket); }
string SnapKeyMagic(int ticket)    { return SnapScope() + "RM_SNAP_MAGIC_"    + IntegerToString(ticket); }
string SnapKeyMaxFavR(int ticket)  { return SnapScope() + "RM_SNAP_MAXFAVR_"  + IntegerToString(ticket); } // v18 (BUG-021)
string SnapKeyMinFavR(int ticket)  { return SnapScope() + "RM_SNAP_MINFAVR_"  + IntegerToString(ticket); } // v66 (آیتم ۲ب)
string SnapKeyStriked(int ticket)  { return SnapScope() + "RM_SNAP_STRIKED_"  + IntegerToString(ticket); } // v18 (BUG-021 refinement)
string SnapKeyWasHalfRisk(int ticket) { return SnapScope() + "RM_SNAP_WASHALFRISK_" + IntegerToString(ticket); } // v19 (BUG-022)
string SnapKeyRiskWeight(int ticket)  { return SnapScope() + "RM_SNAP_RISKWEIGHT_"  + IntegerToString(ticket); } // v84 (FEAT-038 Addendum)
string SnapKeyRootTicket(int ticket)  { return SnapScope() + "RM_SNAP_ROOT_"        + IntegerToString(ticket); } // v86 (FEAT-042 فاز ۱)
string SnapKeyIsContinuation(int ticket) { return SnapScope() + "RM_SNAP_ISCONT_"    + IntegerToString(ticket); } // v90 (FEAT-044)
string SnapKeyRiskBaseUSD(int ticket)    { return SnapScope() + "RM_SNAP_RISKBASE_"  + IntegerToString(ticket); } // v90 (FEAT-044)

// v84 (FEAT-038 Addendum): تنها نقطه‌ی تفسیر وزن ریسک یک Snapshot - هر سه مصرف‌کننده (RB، Market Cooldown،
// CSV) از همین می‌خونن. فیلد جدید اگه ثبت شده باشه (>0) همون؛ وگرنه منطق قدیمی بولین (۰.۵ اگه true، ۱.۰ اگه false).
double SnapRiskWeight(int idx)
{
   if(idx < 0) return 1.0;
   if(g_snapRiskWeight[idx] > 0.0) return g_snapRiskWeight[idx];
   return g_snapWasHalfRisk[idx] ? 0.5 : 1.0;
}
// v90 (FEAT-044): پایه‌ی R زنجیره‌ای یک Snapshot (دلار). تنها نقطه‌ی تفسیر؛ مصرف‌کننده‌ها (CalcNetResultR/RB، Market Cooldown، Reports).
double SnapRiskBase(int idx)
{
   if(idx < 0) return 0.0;
   if(g_snapRiskBaseUSD[idx] > 0.0) return g_snapRiskBaseUSD[idx];
   return g_snapRiskUSD[idx];
}
// v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله):
string SnapKeyBehErrCount(int ticket)  { return SnapScope() + "RM_SNAP_BEHERRCNT_"  + IntegerToString(ticket); }
string SnapKeyDuringLock(int ticket)   { return SnapScope() + "RM_SNAP_DURINGLOCK_" + IntegerToString(ticket); }
string SnapKeyIntervalViol(int ticket) { return SnapScope() + "RM_SNAP_INTVIOL_"    + IntegerToString(ticket); }
string SnapKeySLTampered(int ticket)   { return SnapScope() + "RM_SNAP_SLTAMPER_"   + IntegerToString(ticket); }
string SnapKeyDailyPctAtOpen(int ticket)  { return SnapScope() + "RM_SNAP_DAILYPCT_"  + IntegerToString(ticket); }
string SnapKeyWeeklyPctAtOpen(int ticket) { return SnapScope() + "RM_SNAP_WEEKLYPCT_" + IntegerToString(ticket); }
// v64:
string SnapKeyPriorDayResult(int ticket)  { return SnapScope() + "RM_SNAP_PRIORDAY_"  + IntegerToString(ticket); }
string SnapKeySLLoosened(int ticket)      { return SnapScope() + "RM_SNAP_SLLOOSE_"   + IntegerToString(ticket); }
// v64 (آیتم ۴):
string SnapKeyBehErrThisTrade(int ticket) { return SnapScope() + "RM_SNAP_BEHTHIS_"   + IntegerToString(ticket); }
// v64 (آیتم ۶):
string SnapKeyTimeframeAtOpen(int ticket) { return SnapScope() + "RM_SNAP_TFOPEN_"    + IntegerToString(ticket); }

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

int FindSnapshotIndex(int ticket)
{
   for(int i=0;i<g_snapCount;i++)
      if(g_snapTickets[i]==ticket) return i;
   return -1;
}

// v90 (FEAT-044): آیا این تیکت ورود ادامه است؟ بدون Snapshot -> false.
bool IsContinuationTicket(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return false;
   return g_snapIsContinuation[idx];
}

// v86 (FEAT-042 فاز ۱): ریشه‌ی زنجیره‌ی یک تیکت. بدون Snapshot، یا Snapshot بدون فیلد ریشه (قبل از v86) -> خودِ تیکت.
// تنها نقطه‌ی تفسیر ریشه - تگ‌ها (RM_Tools.mqh) و ستون RootTicket در CSV (RM_Reports.mqh) هر دو از همین می‌خونن.
int GetRootTicket(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx >= 0 && g_snapRootTicket[idx] > 0) return g_snapRootTicket[idx];
   return ticket;
}

// v87 (FEAT-042 فاز ۲): تعداد تیکت‌های Snapshot‌دار یک زنجیره. ۱ = معامله‌ی تکی (یا زنجیره‌ی پیش از v86 که هر تیکتش ریشه‌ی خودش است)،
// >۱ = زنجیره‌ی چندتیکتی واقعی (حداقل یک Half Close بعد از v86 انجام شده).
int ChainMemberCount(int root)
{
   int n = 0;
   for(int i=0;i<g_snapCount;i++)
   {
      int r = (g_snapRootTicket[i] > 0) ? g_snapRootTicket[i] : g_snapTickets[i];
      if(r == root) n++;
   }
   return n;
}

// v87 (FEAT-042 فاز ۲): تابع مشترک «زنجیره کامل بسته شد؟» - تنها جایی که الف (Trading Reports) و ب (Market Cooldown)
// تصمیم می‌گیرند زنجیره تمام شده یا نه. false اگر هر سفارش بازِ هم‌مجیک (بازار یا Pending) با همین ریشه وجود داشته باشد.
// توجه: OrderSelect(MODE_TRADES) انتخاب سفارش جاری را عوض می‌کند - فراخواننده بعد از آن باید دوباره OrderSelect کند.
bool IsChainFullyClosed(int root)
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(GetRootTicket(OrderTicket()) == root) return false;
   }
   return true;
}

// v87: GlobalVariable‌های MT4 بعد از ~۴ هفته بدون دسترسی پاک می‌شوند. فقط برای زنجیره‌های چندتیکتی (که کلید ریشه‌ی فرزند
// معنی دارد) کلید ریشه‌ی فرزندان را دوباره می‌نویسد و RiskUSD ریشه را «لمس» می‌کند. بار روزانه و ناچیز (چند کلید).
void RefreshChainRootKeys()
{
   int touched = 0;
   for(int i=0;i<g_snapCount;i++)
   {
      int tk = g_snapTickets[i];
      int rt = g_snapRootTicket[i];
      if(rt <= 0 || rt == tk) continue;                       // معامله‌ی تکی یا خودِ ریشه: فال‌بک ریشه=خودش، کلید لازم نیست
      GlobalVariableSet(SnapKeyRootTicket(tk), (double)rt);
      if(GlobalVariableCheck(SnapKeyRiskBaseUSD(tk)))    GlobalVariableSet(SnapKeyRiskBaseUSD(tk), GlobalVariableGet(SnapKeyRiskBaseUSD(tk)));       // v90: تازه‌سازی انقضا
      if(GlobalVariableCheck(SnapKeyIsContinuation(tk))) GlobalVariableSet(SnapKeyIsContinuation(tk), GlobalVariableGet(SnapKeyIsContinuation(tk))); // v90
      if(GlobalVariableCheck(SnapKeyRiskUSD(rt))) GlobalVariableGet(SnapKeyRiskUSD(rt));  // دسترسی = تازه‌سازی زمان انقضا
      touched++;
   }
   if(touched > 0) Print("RM: RefreshChainRootKeys - refreshed ", touched, " chain root key(s)");
}

// v90 (FEAT-044): جدا کردن ریشه‌ی یک ورود ادامه‌ی Pending که بدون پر شدن حذف/منقضی شد - ریشه = خودِ تیکت می‌شود تا
// ChainMemberCount / IsChainFullyClosed زنجیره‌ی هدف را بدون این شبح ارزیابی کنند. فقط از CheckPendingActivation صدا زده می‌شود.
void DetachSnapshotRoot(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   g_snapRootTicket[idx] = ticket;
   GlobalVariableSet(SnapKeyRootTicket(ticket), (double)ticket);
   RM_BumpSnapshotVersion();  // v101: نمونه‌های دیگر هم ریشه‌ی جدید را ببینند (فقط وقتی تغییر کرد؛ رویداد نادر)
}

// v11: تغییرناپذیر - اگه از قبل برای این تیکت Snapshot ثبت شده باشه، دوباره بازنویسی نمی‌شه
// (نه در حافظه، نه در GlobalVariable). این تنها راهیه که تضمین می‌کنه BE/Trailing/SL دستی
// نتونن مقادیر اولیه رو تغییر بدن.
// v18 (BUG-021): پارامتر جدید و اختیاری initMaxFavR - پیش‌فرض 0 برای معامله‌ی تازه‌باز‌شده.
// تنها استثنا: وقتی Half Close یک تیکت جدید برای باقیمونده می‌سازه، R ای که تیکت اصلی از لحظه‌ی
// ورود تا الان لمس کرده باید به باقیمونده منتقل بشه (چون از نظر قیمتی هر دو همون معامله‌ان،
// فقط حجم فرق می‌کنه) - وگرنه بعد از Half Close، MaxFavorableR باقیمونده غلط از صفر شروع می‌شه.
// v18 (BUG-021 refinement): پارامتر جدید و اختیاری initStriked - پیش‌فرض false برای معامله‌ی
// تازه‌باز‌شده. تنها استثنا: انتقال به تیکت باقیمونده‌ی Half Close (پایین‌تر) - اگه معامله‌ی
// اصلی از قبل به‌خاطر اقدام زودهنگام Strike گرفته، باقیمونده هم باید همون وضعیت رو به ارث ببره
// (یک معامله = حداکثر یک Strike، حتی وقتی حجمش با Half Close تقسیم شده).
// v61: شش پارامتر اختیاری جدید در انتها - دقیقاً همون الگوی initMaxFavR/initStriked/
// initWasHalfRisk بالا. برای معامله‌ی تازه‌باز‌شده (Market) با مقدار واقعی همون لحظه پر
// می‌شن؛ برای Pending، فراخوان (AutoExecute) عمداً placeholder (صفر/false) پاس می‌ده و مقدار
// واقعی بعداً با SetSnapshotBehaviorFieldsAtActivation در لحظه‌ی فعال‌شدن واقعی پر می‌شه.
// تنها استثنا: انتقال به تیکت باقیمونده‌ی Half Close - هر شش مقدار از معامله‌ی اصلی به ارث
// می‌رسه (دقیقاً هم‌الگوی initMaxFavR/initStriked/initWasHalfRisk).
// v66 (آیتم ۲ب): پارامتر اختیاری جدید در انتها - initMinFavR، پیش‌فرض 0.0 برای معامله‌ی
// تازه‌باز‌شده (دقیقاً هم‌الگوی initMaxFavR). چون در انتهای لیست پارامترها اضافه شده، هیچ فراخوان
// موجودی (که این آرگومان رو پاس نمی‌ده) نیازی به تغییر نداره.
void SaveTradeSnapshot(int ticket, double entry, double sl, double riskUSD, double riskPct, datetime openTime, int magic, double initMaxFavR=0.0, bool initStriked=false, bool initWasHalfRisk=false,
                        double initBehErrCountAtOpen=0.0, bool initOpenedDuringCooldownLock=false, bool initEntryIntervalViolation=false, bool initSLTampered=false,
                        double initDailyRiskUsedPctAtOpen=0.0, double initWeeklyDDUsedPctAtOpen=0.0,
                        double initPriorDayResult=-2.0, int initSLLoosenedCount=0, double initBehaviorErrorsThisTrade=-1.0, double initTimeframeAtOpen=0.0,
                        double initMinFavR=0.0, double initRiskWeight=-1.0, int initRootTicket=0,
                        bool initIsContinuation=false, double initRiskBaseUSD=0.0)
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
   ArrayResize(g_snapMinFavR,  g_snapCount+1);  // v66 (آیتم ۲ب)
   ArrayResize(g_snapStriked,  g_snapCount+1);
   ArrayResize(g_snapWasHalfRisk, g_snapCount+1);
   ArrayResize(g_snapRiskWeight,  g_snapCount+1);  // v84 (FEAT-038 Addendum)
   ArrayResize(g_snapRootTicket,  g_snapCount+1);  // v86 (FEAT-042 فاز ۱)
   ArrayResize(g_snapIsContinuation, g_snapCount+1); // v90 (FEAT-044)
   ArrayResize(g_snapRiskBaseUSD,    g_snapCount+1); // v90 (FEAT-044)
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

   g_snapTickets[g_snapCount]  = ticket;
   g_snapEntry[g_snapCount]    = entry;
   g_snapSL[g_snapCount]       = sl;
   g_snapRiskUSD[g_snapCount]  = riskUSD;
   g_snapRiskPct[g_snapCount]  = riskPct;
   g_snapOpenTime[g_snapCount] = openTime;
   g_snapMagic[g_snapCount]    = magic;
   g_snapMaxFavR[g_snapCount]  = initMaxFavR;
   g_snapMinFavR[g_snapCount]  = initMinFavR;  // v66 (آیتم ۲ب)
   g_snapStriked[g_snapCount]  = initStriked;
   g_snapWasHalfRisk[g_snapCount] = initWasHalfRisk;
   g_snapRiskWeight[g_snapCount]  = initRiskWeight;  // v84 (FEAT-038 Addendum)
   int rootVal = (initRootTicket > 0) ? initRootTicket : ticket;  // v86: پیش‌فرض = ریشه خودِ تیکت
   g_snapRootTicket[g_snapCount]  = rootVal;
   double riskBaseVal = (initRiskBaseUSD > 0.0) ? initRiskBaseUSD : riskUSD;  // v90: پیش‌فرض = ریسک خودِ تیکت
   g_snapIsContinuation[g_snapCount] = initIsContinuation;
   g_snapRiskBaseUSD[g_snapCount]    = riskBaseVal;
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
   g_snapCount++;

   GlobalVariableSet(SnapKeyEntry(ticket),    entry);
   GlobalVariableSet(SnapKeySL(ticket),       sl);
   GlobalVariableSet(SnapKeyRiskUSD(ticket),  riskUSD);
   GlobalVariableSet(SnapKeyRiskPct(ticket),  riskPct);
   GlobalVariableSet(SnapKeyOpenTime(ticket), (double)openTime);
   GlobalVariableSet(SnapKeyMagic(ticket),    (double)magic);
   GlobalVariableSet(SnapKeyMaxFavR(ticket),  initMaxFavR);
   GlobalVariableSet(SnapKeyMinFavR(ticket),  initMinFavR);  // v66 (آیتم ۲ب)
   GlobalVariableSet(SnapKeyStriked(ticket),  initStriked ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeyWasHalfRisk(ticket), initWasHalfRisk ? 1.0 : 0.0);
   GlobalVariableSet(SnapKeyRiskWeight(ticket),  initRiskWeight);  // v84 (FEAT-038 Addendum)
   GlobalVariableSet(SnapKeyRootTicket(ticket),  (double)rootVal); // v86 (FEAT-042 فاز ۱)
   GlobalVariableSet(SnapKeyIsContinuation(ticket), initIsContinuation ? 1.0 : 0.0); // v90 (FEAT-044)
   GlobalVariableSet(SnapKeyRiskBaseUSD(ticket),    riskBaseVal);                    // v90 (FEAT-044)
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
   RM_BumpSnapshotVersion();  // v101 (BUG-054/057): بعد از نوشتن *همه‌ی* کلیدها - نمونه‌های دیگر Snapshot کامل را می‌بینند
}

// v61: پر کردن ۵ فیلد رفتاری (همه به‌جز SLTampered) در لحظه‌ی فعال‌شدن واقعیِ یک تیکت که با
// placeholder ساخته شده بود (فقط مسیر Pending - AutoExecute در لحظه‌ی ثبت این مقادیر رو نمی‌دونه
// چون فعال‌شدن واقعی بعداً اتفاق می‌افته). اگه از قبل Snapshot این تیکت نبود، کاری نمی‌کنه.
// برخلاف SaveTradeSnapshot، این تابع immutability نداره - عمداً، چون همینجا داره جای placeholder
// اولیه (صفر/false) رو با مقدار واقعی پر می‌کنه؛ بعد از این یک‌بار پر شدن دیگه صدا زده نمی‌شه
// (فقط از CheckPendingActivation، دقیقاً یک‌بار به‌ازای هر تیکت).
// v64 (آیتم ۱ - PriorDayResult): پارامتر ششم priorDayResultAtOpen اضافه شد - دقیقاً هم‌الگوی
// ۵ فیلد رفتاری v61 موجود؛ برای Pending، مقدار واقعی همینجا (لحظه‌ی فعال‌شدن واقعی) پر می‌شه.
// v64 (آیتم ۶ - TimeframeAtOpen): پارامتر هفتم timeframeAtOpen اضافه شد - همون الگو، برای
// Pending مقدار واقعی همین‌جا (لحظه‌ی فعال‌شدن واقعی) پر می‌شه.
void SetSnapshotBehaviorFieldsAtActivation(int ticket, double behErrCountAtOpen, bool openedDuringCooldownLock, bool entryIntervalViolation, double dailyRiskUsedPctAtOpen, double weeklyDDUsedPctAtOpen, double priorDayResultAtOpen=-2.0, double timeframeAtOpen=0.0)
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
}

// v61: SLTampered - جدا از تابع بالا چون این فیلد ذاتاً «بعداً معلوم می‌شه» است (نه لحظه‌ی
// فعال‌شدن) و ممکنه چندبار در طول عمر تیکت صدا زده بشه (idempotent - فقط false->true).
void MarkSnapshotTampered(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   if(g_snapSLTampered[idx]) return; // از قبل true بوده - کاری نیست
   g_snapSLTampered[idx] = true;
   GlobalVariableSet(SnapKeySLTampered(ticket), 1.0);
}

// v64 (آیتم ۳ - SLLoosenedCount): یک واحد به شمارنده‌ی این تیکت اضافه می‌کنه - از
// CheckSLTampering (RM_TradeExecution.mqh) صدا زده می‌شه، فقط وقتی جهت جابه‌جایی SL واقعاً
// افزایش ریسک (دورتر از قیمت) بوده باشه؛ مستقل و بدون Strike/تخلف. بدون Snapshot معتبر
// (idx<0) کاری نمی‌کنه - مثل بقیه‌ی توابع mutable این فایل.
void IncrementSLLoosenedCount(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   g_snapSLLoosenedCount[idx]++;
   GlobalVariableSet(SnapKeySLLoosened(ticket), (double)g_snapSLLoosenedCount[idx]);
}

// v64 (آیتم ۴ - BehaviorErrorsThisTrade): بر خلاف بقیه‌ی setter های این فایل که «لحظه‌ی باز
// شدن» یک‌بار مقداردهی می‌شن، این یکی «لحظه‌ی بسته‌شدن» یک‌بار صدا زده می‌شه (از
// CheckClosedTrades - RM_CooldownEngine.mqh) - مقدار نهایی، نه یه افزایش تدریجی.
void SetSnapshotBehaviorErrorsThisTrade(int ticket, double count)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   g_snapBehaviorErrorsThisTrade[idx] = count;
   GlobalVariableSet(SnapKeyBehErrThisTrade(ticket), count);
}

// v11: در OnInit صدا زده می‌شه - همه‌ی Snapshotهای ذخیره‌شده‌ی این EA (بر اساس MagicNumber)
// رو از GlobalVariableها بازیابی می‌کنه تا Trade Snapshotهای قبل از ری‌استارت از دست نرن
// v101 (BUG-054/057): بارگذاری (یا تازه‌سازی) Snapshot «یک» تیکت از GlobalVariableهای مشترک. قبلاً این منطق فقط داخل
// حلقه‌ی LoadTradeSnapshots (OnInit) بود، پس Snapshotی که نمونه‌ی دیگر EA بعد از OnInit ساخته بود (معامله‌ی باز
// شده روی چارت دیگر، باقی‌مانده‌ی Half Close، ...) هرگز در حافظه‌ی این نمونه نبود -> R/RB/آمار/تگ‌ها/زنجیره غلط یا خالی.
// مقدار برگشتی: 0 = چیزی بارگذاری نشد (ناقص/مجیک دیگر/از قبل موجود وقتی refreshExisting=false)، 1 = اضافه شد، 2 = تازه‌سازی شد.
// تازه‌سازی (refreshExisting=true) فقط فیلدهای «قابل‌تغییر» را به‌روز می‌کند و آن‌ها را فقط در جهت امن می‌گیرد
// (MaxFavR بزرگ‌ترین، MinFavR کوچک‌ترین، Striked/SLTampered/SLLoosened فقط افزایشی)؛ فیلدهای تغییرناپذیر (Entry/SL/RiskUSD/...) دست نمی‌خورند.
int RM_LoadSnapshotTicket(int ticket, bool refreshExisting)
{
   int existingIdx = FindSnapshotIndex(ticket);
   if(existingIdx >= 0 && !refreshExisting) return 0;
   if(ticket<=0) return 0;

   if(!GlobalVariableCheck(SnapKeyEntry(ticket)) ||
      !GlobalVariableCheck(SnapKeySL(ticket)) || !GlobalVariableCheck(SnapKeyRiskUSD(ticket)) ||
      !GlobalVariableCheck(SnapKeyRiskPct(ticket)) || !GlobalVariableCheck(SnapKeyOpenTime(ticket)) ||
      !GlobalVariableCheck(SnapKeyMagic(ticket)))
      return 0; // رکورد ناقص - نادیده گرفته می‌شه

   int magic = (int)GlobalVariableGet(SnapKeyMagic(ticket));
   if(magic != MagicNumber) return 0; // متعلق به یک EA/Magic دیگه‌ست

   double entry    = GlobalVariableGet(SnapKeyEntry(ticket));
   double sl       = GlobalVariableGet(SnapKeySL(ticket));
   double riskUSD  = GlobalVariableGet(SnapKeyRiskUSD(ticket));
   double riskPct  = GlobalVariableGet(SnapKeyRiskPct(ticket));
   datetime openTm = (datetime)GlobalVariableGet(SnapKeyOpenTime(ticket));
   // v18 (BUG-021): MaxFavorableR - اگه این Snapshot قبل از نصب v18 ذخیره شده باشه
   // (کلید MaxFavR وجود نداره)، با 0 شروع می‌شه - یعنی محافظه‌کارانه فرض می‌شه هنوز به
   // +1R نرسیده؛ فقط باعث می‌شه یک تیک اول بعد از ری‌استارت زودتر از واقع به‌روزرسانی بشه، نه بیشتر.
   double maxFavR  = GlobalVariableCheck(SnapKeyMaxFavR(ticket)) ? GlobalVariableGet(SnapKeyMaxFavR(ticket)) : 0.0;
   // v66 (آیتم ۲ب): همون فلسفه‌ی فال‌بک محافظه‌کارانه‌ی بالا - Snapshotهای قبل از نصب v66
   // بدون کلید MinFavR هستن، پس با 0 شروع می‌شه (یعنی محافظه‌کارانه فرض می‌شه هیچ‌وقت وارد
   // ضرر شناور نشده؛ فقط باعث می‌شه یک تیک اول بعد از ری‌استارت زودتر از واقع به‌روزرسانی بشه).
   double minFavR  = GlobalVariableCheck(SnapKeyMinFavR(ticket)) ? GlobalVariableGet(SnapKeyMinFavR(ticket)) : 0.0;
   // v18 (BUG-021 refinement): همون منطق فال‌بک - Snapshotهای قبل از این نسخه بدون کلید
   // Striked هستن، پس با false (هنوز Strike نگرفته) شروع می‌شن.
   bool striked = GlobalVariableCheck(SnapKeyStriked(ticket)) && (GlobalVariableGet(SnapKeyStriked(ticket)) != 0.0);
   // v19 (BUG-022): WasHalfRisk - اگه این Snapshot قبل از نصب v19 ذخیره شده باشه (کلید
   // وجود نداره)، با false شروع می‌شه - یعنی محافظه‌کارانه به‌عنوان Full Risk فرض می‌شه
   // (همون فلسفه‌ی فال‌بک محافظه‌کارانه‌ای که در بقیه‌ی جاهای Snapshot استفاده شده).
   bool wasHalfRisk = GlobalVariableCheck(SnapKeyWasHalfRisk(ticket)) && (GlobalVariableGet(SnapKeyWasHalfRisk(ticket)) != 0.0);
   // v84 (FEAT-038 Addendum): Snapshot قبل از v84 این کلید رو نداره -> -1 (ثبت نشده) و SnapRiskWeight() به بولین بالا فال‌بک می‌کنه.
   double riskWeight = GlobalVariableCheck(SnapKeyRiskWeight(ticket)) ? GlobalVariableGet(SnapKeyRiskWeight(ticket)) : -1.0;
   // v86 (FEAT-042 فاز ۱): Snapshot قبل از v86 کلید ریشه ندارد -> ریشه = خودِ تیکت (بدون خطا)؛ مقدار نامعتبر هم همین فال‌بک را می‌گیرد.
   int rootTicket = GlobalVariableCheck(SnapKeyRootTicket(ticket)) ? (int)MathRound(GlobalVariableGet(SnapKeyRootTicket(ticket))) : ticket;
   if(rootTicket <= 0) rootTicket = ticket;
   // v90 (FEAT-044): Snapshot قبل از v90 این دو کلید را ندارد -> false و RiskBase = RiskUSD خودش (رفتار قبلی).
   bool   isContinuation    = GlobalVariableCheck(SnapKeyIsContinuation(ticket)) && (GlobalVariableGet(SnapKeyIsContinuation(ticket)) != 0.0);
   double riskBaseUSD       = GlobalVariableCheck(SnapKeyRiskBaseUSD(ticket)) ? GlobalVariableGet(SnapKeyRiskBaseUSD(ticket)) : riskUSD;
   if(riskBaseUSD <= 0.0) riskBaseUSD = riskUSD;

   // v61: همون فلسفه‌ی فال‌بک محافظه‌کارانه‌ی بالا - Snapshotهای قبل از نصب v61 بدون این
   // کلیدها هستن؛ عددی‌ها با 0 و بولی‌ها با false شروع می‌شن (یعنی «هیچ تخلفی ثبت نشده/صفر
   // درصد مصرف‌شده» - محافظه‌کارانه‌ترین فرض ممکن برای داده‌ی از‌دست‌رفته).
   double behErrCountAtOpen = GlobalVariableCheck(SnapKeyBehErrCount(ticket)) ? GlobalVariableGet(SnapKeyBehErrCount(ticket)) : 0.0;
   bool   duringLock        = GlobalVariableCheck(SnapKeyDuringLock(ticket)) && (GlobalVariableGet(SnapKeyDuringLock(ticket)) != 0.0);
   bool   intervalViol      = GlobalVariableCheck(SnapKeyIntervalViol(ticket)) && (GlobalVariableGet(SnapKeyIntervalViol(ticket)) != 0.0);
   bool   slTampered        = GlobalVariableCheck(SnapKeySLTampered(ticket)) && (GlobalVariableGet(SnapKeySLTampered(ticket)) != 0.0);
   double dailyPctAtOpen    = GlobalVariableCheck(SnapKeyDailyPctAtOpen(ticket)) ? GlobalVariableGet(SnapKeyDailyPctAtOpen(ticket)) : 0.0;
   double weeklyPctAtOpen   = GlobalVariableCheck(SnapKeyWeeklyPctAtOpen(ticket)) ? GlobalVariableGet(SnapKeyWeeklyPctAtOpen(ticket)) : 0.0;

   // v64: همون فلسفه‌ی فال‌بک محافظه‌کارانه‌ی بالا - Snapshotهای قبل از نصب v64 بدون این
   // کلیدها هستن؛ PriorDayResult با -2 (N/A - محافظه‌کارانه‌ترین فرض، نه حدس زدن Win/Loss)
   // و SLLoosenedCount با 0 (هیچ جابه‌جایی افزایش-ریسکی ثبت نشده) شروع می‌شن.
   double priorDayResult    = GlobalVariableCheck(SnapKeyPriorDayResult(ticket)) ? GlobalVariableGet(SnapKeyPriorDayResult(ticket)) : -2.0;
   int    slLoosenedCount   = GlobalVariableCheck(SnapKeySLLoosened(ticket)) ? (int)MathRound(GlobalVariableGet(SnapKeySLLoosened(ticket))) : 0;
   // v64 (آیتم ۴): فال‌بک -1 (N/A) برای تیکت‌هایی که با v64+ بسته نشدن (تاریخی، یا هنوز بازن).
   double behErrThisTrade   = GlobalVariableCheck(SnapKeyBehErrThisTrade(ticket)) ? GlobalVariableGet(SnapKeyBehErrThisTrade(ticket)) : -1.0;
   // v64 (آیتم ۶): فال‌بک 0 (N/A) برای تیکت‌های تاریخی قبل از v64.
   double timeframeAtOpen   = GlobalVariableCheck(SnapKeyTimeframeAtOpen(ticket)) ? GlobalVariableGet(SnapKeyTimeframeAtOpen(ticket)) : 0.0;


   if(existingIdx >= 0)
   {
      int x = existingIdx;
      if(maxFavR > g_snapMaxFavR[x]) g_snapMaxFavR[x] = maxFavR;
      if(minFavR < g_snapMinFavR[x]) g_snapMinFavR[x] = minFavR;
      if(striked) g_snapStriked[x] = true;
      if(slTampered) g_snapSLTampered[x] = true;
      if(slLoosenedCount > g_snapSLLoosenedCount[x]) g_snapSLLoosenedCount[x] = slLoosenedCount;
      g_snapRiskWeight[x]            = riskWeight;
      g_snapRootTicket[x]            = rootTicket;
      g_snapIsContinuation[x]        = isContinuation;
      g_snapRiskBaseUSD[x]           = riskBaseUSD;
      g_snapBehaviorErrorCountAtOpen[x] = behErrCountAtOpen;
      g_snapOpenedDuringCooldownLock[x] = duringLock;
      g_snapEntryIntervalViolation[x]   = intervalViol;
      g_snapDailyRiskUsedPctAtOpen[x]   = dailyPctAtOpen;
      g_snapWeeklyDDUsedPctAtOpen[x]    = weeklyPctAtOpen;
      g_snapPriorDayResult[x]           = priorDayResult;
      g_snapBehaviorErrorsThisTrade[x]  = behErrThisTrade;
      g_snapTimeframeAtOpen[x]          = timeframeAtOpen;
      return 2;
   }

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
   ArrayResize(g_snapMinFavR,  g_snapCount+1);  // v66 (آیتم ۲ب)
   ArrayResize(g_snapStriked,  g_snapCount+1);
   ArrayResize(g_snapWasHalfRisk, g_snapCount+1);
   ArrayResize(g_snapRiskWeight,  g_snapCount+1);  // v84 (FEAT-038 Addendum)
   ArrayResize(g_snapRootTicket,  g_snapCount+1);  // v86 (FEAT-042 فاز ۱)
ArrayResize(g_snapIsContinuation, g_snapCount+1); // v90 (FEAT-044)
ArrayResize(g_snapRiskBaseUSD,    g_snapCount+1); // v90 (FEAT-044)
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

   g_snapTickets[g_snapCount]  = ticket;
   g_snapEntry[g_snapCount]    = entry;
   g_snapSL[g_snapCount]       = sl;
   g_snapRiskUSD[g_snapCount]  = riskUSD;
   g_snapRiskPct[g_snapCount]  = riskPct;
   g_snapOpenTime[g_snapCount] = openTm;
   g_snapMagic[g_snapCount]    = magic;
   g_snapMaxFavR[g_snapCount]  = maxFavR;
   g_snapMinFavR[g_snapCount]  = minFavR;  // v66 (آیتم ۲ب)
   g_snapStriked[g_snapCount]  = striked;
   g_snapWasHalfRisk[g_snapCount] = wasHalfRisk;
   g_snapRiskWeight[g_snapCount]  = riskWeight;  // v84 (FEAT-038 Addendum)
   g_snapRootTicket[g_snapCount]  = rootTicket;  // v86 (FEAT-042 فاز ۱)
   g_snapIsContinuation[g_snapCount] = isContinuation; // v90 (FEAT-044)
   g_snapRiskBaseUSD[g_snapCount]    = riskBaseUSD;    // v90 (FEAT-044)
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
   g_snapCount++;
   return 1;
}

// v101: نسخه‌ی «بدون refresh» که فقط تیکتِ ناموجود در حافظه را از GV می‌آورد؛ برای جاهایی که یک اقدام روی تیکتی انجام می‌شود
// که ممکن است روی چارت دیگر باز شده باشد (Half Close/اقدام زودهنگام/pending یتیم).
bool RM_EnsureSnapshot(int ticket)
{
   if(FindSnapshotIndex(ticket) >= 0) return true;
   int r = RM_LoadSnapshotTicket(ticket, false);
   if(r == 1) Print("[RM-MI] snapshot reload #", ticket, " on ", RM_InstTag());
   return (r == 1);
}

// v101: اسکن prefix (مثل OnInit) و اضافه‌کردن Snapshotهای ناموجود در حافظه. هزینه: یک پیمایش جدول GV - فقط روی رویداد
// (تغییر نسخه‌ی مشترک Snapshot، یا لحظه‌ی بسته‌شدن/Export)، هرگز هر تیک. تعداد تیکت‌های جدید را برمی‌گرداند.
int RM_SyncSnapshotsFromGV()
{
   string prefix = SnapScope() + "RM_SNAP_ENTRY_";
   int total = GlobalVariablesTotal();
   int added = 0;
   for(int i=0;i<total;i++)
   {
      string nm = GlobalVariableName(i);
      if(StringFind(nm, prefix) != 0) continue;
      int ticket = (int)StringToInteger(StringSubstr(nm, StringLen(prefix)));
      if(ticket<=0) continue;
      if(FindSnapshotIndex(ticket) >= 0) continue;
      if(RM_LoadSnapshotTicket(ticket, false) == 1)
      {
         added++;
         Print("[RM-MI] snapshot reload #", ticket, " on ", RM_InstTag());
      }
   }
   return added;
}

// v101: فیلدهای قابل‌تغییر Snapshot خودِ تیکت و همه‌ی اعضای زنجیره‌ی آن (هم‌ریشه) را از GV تازه می‌کند - لحظه‌ی close (فقط
// توسط نمونه‌ی claim-winner) تا Striked/MaxFavR/ریشه/ریسک‌پایه از نمونه‌ی دیگر دیده شود. اعضا بعد از RM_SyncSnapshotsFromGV
// در حافظه هستند. refresh فقط در جهت امن (جزئیات بالای RM_LoadSnapshotTicket).
void RM_RefreshChainSnapshots(int ticket)
{
   RM_LoadSnapshotTicket(ticket, true);
   int root = GetRootTicket(ticket);
   for(int m=0; m<g_snapCount; m++)
   {
      int rm = (g_snapRootTicket[m] > 0) ? g_snapRootTicket[m] : g_snapTickets[m];
      if(rm != root) continue;
      RM_LoadSnapshotTicket(g_snapTickets[m], true);
   }
}

// v101: نسخه‌ی مشترک Snapshot - هر ذخیره‌ی جدید (SaveTradeSnapshot) / جداشدن ریشه آن را بالا می‌برد (CAS)، و هر نمونه
// هر تیک فقط یک GlobalVariableGet می‌کند؛ فقط اگر عوض شده بود RM_SyncSnapshotsFromGV اجرا می‌شود.
double g_snapVerSeen = -1.0;
string SnapVerKey() { return SnapScope() + "RM_SNAPVER"; }
void RM_BumpSnapshotVersion()
{
   double prevSeen = g_snapVerSeen;
   double v = CAS_AddToGlobal(SnapVerKey(), 1.0);
   // این نمونه خودش منبع تغییر است و آنچه نوشته از قبل در حافظه دارد؛ ولی فقط اگر هیچ نمونه‌ی دیگری بین آخرین sync و
   // این افزایش نسخه را بالا نبرده باشد (v == prevSeen+1) آن را «دیده‌شده» حساب می‌کنیم - وگرنه تغییر نمونه‌ی دیگر
   // گم می‌شد؛ در آن حالت seen را دست‌نخورده می‌گذاریم تا AutoSync بعدی یک اسکن انجام دهد.
   if(prevSeen >= 0.0 && v == prevSeen + 1.0) g_snapVerSeen = v;
}
void RM_SnapshotAutoSync()
{
   double v = GlobalVariableCheck(SnapVerKey()) ? GlobalVariableGet(SnapVerKey()) : 0.0;
   if(v == g_snapVerSeen) return;
   g_snapVerSeen = v;
   RM_SyncSnapshotsFromGV();
}

void LoadTradeSnapshots()
{
   // v77 (دسته ۴): scope جلوی prefix اضافه شد؛ همون scope که SnapKey* استفاده می‌کنن. نتیجه:
   // (۱) اسکن فقط اسنپ‌شاتِ همین اکانت رو می‌بینه، (۲) StringSubstr بعدِ prefix همچنان دقیقاً تیکت رو می‌ده.
   // v101: منطق هر تیکت به RM_LoadSnapshotTicket (بالا) منتقل شد - رفتار OnInit دقیقاً مثل قبل.
   double verAtStart = GlobalVariableCheck(SnapVerKey()) ? GlobalVariableGet(SnapVerKey()) : 0.0;  // قبل از اسکن: اگر نمونه‌ی دیگری وسط اسکن Snapshot بسازد، AutoSync بعدی آن را می‌گیرد
   string prefix = SnapScope() + "RM_SNAP_ENTRY_";
   int total = GlobalVariablesTotal();
   for(int i=0;i<total;i++)
   {
      string nm = GlobalVariableName(i);
      if(StringFind(nm, prefix) != 0) continue;

      int ticket = (int)StringToInteger(StringSubstr(nm, StringLen(prefix)));
      if(ticket<=0) continue;
      RM_LoadSnapshotTicket(ticket, false); // قبلاً بارگذاری‌شده/ناقص/مجیک دیگر -> 0، نادیده گرفته می‌شه
   }
   g_snapVerSeen = verAtStart;
}

//+------------------------------------------------------------------+
// v18 (BUG-021): هر تیک برای یک تیکت باز با Snapshot معتبر صدا زده می‌شه (از داخل
// TrackOpenTrades). سود جاری (شامل سواپ/کمیسیون - هم‌مبنا با محاسبه‌ی reached1R در
// CheckClosedTrades) رو بر مبنای Initial Risk ($) همون Snapshot به R تبدیل می‌کنه و اگه
// از بالاترین مقدار قبلی بیشتر بود، هم در حافظه و هم در GlobalVariable به‌روزرسانی می‌شه.
// هرگز کم نمی‌شه - این یه "بالاترین سقف" تاریخی برای این تیکته، نه سود لحظه‌ای.
//+------------------------------------------------------------------+
void UpdateSnapshotMaxFavorableR(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return; // بدون Snapshot - نمی‌شه R رو معنادار محاسبه کرد

   double oneR = g_snapRiskUSD[idx];
   if(oneR <= 0) return;

   double profit = OrderProfit() + OrderSwap() + OrderCommission();
   double curR   = profit / oneR;

   if(curR > g_snapMaxFavR[idx])
   {
      // v101 (BUG-054): قبلاً مقدار محلی این نمونه مستقیم روی GV نوشته می‌شد؛ اگر نمونه‌ی دیگری بالاترین R بزرگ‌تری
      // ثبت کرده بود (مثلاً این نمونه چند تیک را از دست داده)، با یک عدد کوچک‌تر بازنویسی می‌شد. حالا با GV مقایسه می‌شود
      // (فقط وقتی curR از حافظه‌ی محلی بیشتر شد = نادر، نه هر تیک) و فقط افزایشی نوشته می‌شود.
      double gvMax = GlobalVariableCheck(SnapKeyMaxFavR(ticket)) ? GlobalVariableGet(SnapKeyMaxFavR(ticket)) : curR;
      double newMax = MathMax(curR, gvMax);
      g_snapMaxFavR[idx] = newMax;
      if(newMax > gvMax || !GlobalVariableCheck(SnapKeyMaxFavR(ticket))) GlobalVariableSet(SnapKeyMaxFavR(ticket), newMax);
   }
}

//+------------------------------------------------------------------+
// v66 (آیتم ۲ب - MAE): قرینه‌ی دقیق UpdateSnapshotMaxFavorableR بالا - همون فراخوانی (از
// TrackOpenTrades، هر تیک برای هر معامله‌ی باز با Snapshot معتبر)، همون مبنای R (Initial Risk
// $ همون Snapshot)، فقط جهت مقایسه برعکس (کمترین/بدترین R به‌جای بیشترین). هیچ محاسبه‌ای بعد از
// بسته‌شدن معامله انجام نمی‌شه - دقیقاً همون محدودیتی که باعث rollback تلاش Post-Exit MFE شد،
// اینجا رعایت شده (این تابع فقط وقتی معنا داره که OrderSelect روی یک تیکت هنوز-باز موفق شده).
//+------------------------------------------------------------------+
void UpdateSnapshotMinFavorableR(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return; // بدون Snapshot - نمی‌شه R رو معنادار محاسبه کرد

   double oneR = g_snapRiskUSD[idx];
   if(oneR <= 0) return;

   double profit = OrderProfit() + OrderSwap() + OrderCommission();
   double curR   = profit / oneR;

   if(curR < g_snapMinFavR[idx])
   {
      // v101: قرینه‌ی MaxFavR بالا - فقط کاهشی روی GV نوشته می‌شود
      double gvMin = GlobalVariableCheck(SnapKeyMinFavR(ticket)) ? GlobalVariableGet(SnapKeyMinFavR(ticket)) : curR;
      double newMin = MathMin(curR, gvMin);
      g_snapMinFavR[idx] = newMin;
      if(newMin < gvMin || !GlobalVariableCheck(SnapKeyMinFavR(ticket))) GlobalVariableSet(SnapKeyMinFavR(ticket), newMin);
   }
}

// v18 (BUG-021): آیا این تیکت تا این لحظه هرگز واقعاً به +1R رسیده؟ (تلورانس ±5%،
// دقیقاً همون آستانه‌ای که در بقیه‌ی جاهای پروژه برای "رسیدن به +1R" استفاده می‌شه).
// بدون Snapshot معتبر، قابل تشخیص نیست - پس false برمی‌گرده (این اقدام به‌عنوان زودهنگام علامت نمی‌خوره).
bool IsPrematureBeforeOneR(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return false;
   return (g_snapMaxFavR[idx] < 0.95);
}

// v18 (BUG-021 refinement): آیا این معامله از قبل به‌خاطر اقدام زودهنگام Strike گرفته؟
// بدون Snapshot معتبر، false برمی‌گرده (یعنی رفتار قبلی - می‌تونه Strike بگیره - حفظ می‌شه؛
// در عمل هیچ‌وقت به اینجا نمی‌رسه چون IsPrematureBeforeOneR قبلش خودش false برمی‌گردونه).
bool IsAlreadyStrikedThisTrade(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return false;
   return g_snapStriked[idx];
}

// v18 (BUG-021 refinement): این معامله رو به‌عنوان «Strike‌گرفته» علامت می‌زنه - هم در
// حافظه هم در GlobalVariable (تا بعد از ری‌استارت هم این وضعیت یادش بمونه).
void MarkStrikedThisTrade(int ticket)
{
   int idx = FindSnapshotIndex(ticket);
   if(idx < 0) return;
   g_snapStriked[idx] = true;
   GlobalVariableSet(SnapKeyStriked(ticket), 1.0);
}
