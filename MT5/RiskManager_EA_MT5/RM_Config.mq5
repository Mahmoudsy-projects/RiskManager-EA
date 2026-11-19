//+------------------------------------------------------------------+
//| RM_Config.mq5                                                    |
//| Risk Manager EA - Configuration (MT5 Port, Stage 2)               |
//| پورت مستقیم از RM_Config.mqh (RiskManager EA v70, MQL4). طبق       |
//| Golden Rule این استیج: هیچ Input/#define/enum یا مقدار پیش‌فرضی    |
//| تغییر نکرده - فقط سینتکس MQL5 (که برای این فایل تقریباً عیناً همون |
//| MQL4 است، چون input group/enum/#define بین دو زبان مشترکن).       |
//+------------------------------------------------------------------+

// v45 (Punch List Round 3, Item 8): سه فایل صوتی داخل خود .ex4 جاسازی می‌شن (به‌جای خوندن از
// MQL4/Sounds در لحظه‌ی اجرا) - روی هر نصب/بروکر جدید بدون کپی دستی کار می‌کنه. PlaySound() باید
// با پیشوند "::" صدا زده بشه تا از منبع جاسازی‌شده بخونه، نه از دیسک.
// (Stage 2 note: this #define block ports unchanged. Sound files themselves are an .ex4/.ex5
// embedding concern, not part of this stage's Config/RiskCalc scope - left as-is for a later stage.)
#define SND_ORDER_FILLED   "::Sounds\\order_filled.wav"
#define SND_STOP_LOSS      "::Sounds\\stop_loss.wav"
#define SND_TARGET_REACHED "::Sounds\\target_reached.wav"

// v14 (Advanced Break Even): حالت‌های موجود برای دکمه‌ی Break Even -
// Individual = رفتار فعلی/پیش‌فرض دست‌نخورده (هر پوزیشن به نقطه‌ی ورود خودش)
// BasketAverage = همه‌ی پوزیشن‌های هم‌بسکت (Magic+Symbol+جهت یکسان) با هم به یه نقطه‌ی میانگین وزنی منتقل می‌شن
// این enum قبل از گروه Inputها تعریف شده چون Input مربوط به BreakEvenMode به این نوع نیاز داره.
enum EBreakEvenMode { BE_INDIVIDUAL, BE_BASKET_AVERAGE };

// v38 (BUG-023): سقف‌های سخت (hard ceiling) روی Input های ریسک - مقدار خام Input هیچ‌وقت مستقیم
// توی محاسبات استفاده نمی‌شه؛ ApplyRiskCeilings() (صدا زده شده از OnInit) نسخه‌ی effective/کلمپ‌شده
// رو توی g_eff* می‌سازه و اگه مقدار خام از سقف رد شده باشه Alert() می‌زنه. خودِ فرمول‌های
// Risk/Drawdown دست‌نخورده‌ن - فقط ورودی‌ای که بهشون می‌رسه کلمپ می‌شه.
#define RISKPERTRADE_CEILING  3.0   // = دیفالت Max Daily Net Loss؛ یه معامله نباید بیشتر از کل بودجه‌ی ضرر روزانه ریسک کنه
#define MAXTOTALRISK_CEILING  10.0  // 2x دیفالت
#define MAXDAILYRISK_CEILING  6.0   // 2x دیفالت
#define MAXWEEKLYDD_CEILING   16.0  // 2x دیفالت
#define MAXMONTHLYDD_CEILING  20.0  // 2x دیفالت

// v64 (فیدبک محمود بعد از تست SLLoosenedCount - نسخه‌ی اصلاح‌شده): جابه‌جایی‌های خیلی کوچیک SL
// (مثل «دستم خورد» - چند تیک، نه یه تصمیم آگاهانه) نباید به‌عنوان یه رویداد رفتاری شمرده بشن.
// ملاک درصد باید نسبت به فاصله‌ی اصلی ریسک (origDist = |entry-origSL|) باشه، نه نسبت به قیمت
// نمودار طلا - چون قیمت طلا مقیاسی نداره که به ریسک این معامله‌ی خاص ربط داشته باشه (یه معامله
// با استاپ کوچیک باید به همون نسبت حساس‌تر باشه، نه با یه عدد دلاری ثابت وابسته به قیمت لحظه‌ای).
#define SL_LOOSEN_NOISE_THRESHOLD_PCT 10.0

// v66 (آیتم ۱ - سازمان‌دهی پوشه‌ی اسکرین‌شات‌ها): زیرپوشه‌ی مقصد اسکرین‌شات‌های لحظه‌ی خروج (v59)
// زیر MQL4/Files - به‌جای ریخته‌شدن مستقیم توی ریشه‌ی Files. یک‌بار در OnInit با FolderCreate()
// ساخته می‌شه (RM_Tools.mqh/EnsureScreenshotFolder)، بدون هیچ تغییری در منطق خودِ گرفتن عکس.
// (Stage 2 note: MT5's FolderCreate() default sandbox root is MQL5/Files, not MQL4/Files - a
// path-resolution detail for whichever later stage ports RM_Tools.mqh, not this string itself.)
#define SCREENSHOT_FOLDER "TRADE SCREENSHOTS"

input group "=== Startup Safety ==="
// v74 (BUG-051 - MT5 port of MT4 v72's URGENT fix, false Weekly/Monthly DD lock on real-account
// restart, account A4160750): پورت مستقیم از RM_Config.mqh (RiskManager EA v72/v73, MQL4) -
// ببین RM_DrawdownEngine.mq5/CheckDrawdownLimits() برای توضیح کامل. روی یه ری‌کانکت کند حساب
// واقعی، AccountInfoDouble(ACCOUNT_BALANCE)/تاریخچه‌ی دیل‌ها ممکنه برای یه پنجره‌ی کوتاه بعد از
// تکمیل OnInit() مقدار موقت/ناپایدار برگردونن - به‌اندازه‌ی کافی برای ساختن یه breach کاذب.
// StartupGracePeriodSeconds فقط جلوی *ست‌شدن قفل جدید* رو می‌گیره (محاسبه/نمایش دست‌نخورده
// می‌مونه) به مدت این تعداد ثانیه بعد از OnInit(). حادثه‌ی واقعی مشاهده‌شده ۷ ثانیه فاصله‌ی بین
// "loaded successfully" و "initialized" داشت به‌تنهایی؛ ۳۰ ثانیه حاشیه‌ی امنیت واقعی فراتر از
// اون می‌ده، در حالی که به‌اندازه‌ی کافی کوتاهه که یه breach واقعی حین ترید زنده همچنان توی چند
// لحظه بعد از تمام‌شدن پنجره گرفته بشه. روی قفل‌های از-قبل-فعال (بارگذاری‌شده از
// LoadDrawdownState()) هیچ اثری نداره - فقط قفل‌های تازه‌فعال‌شونده رو سرکوب می‌کنه.
input int    StartupGracePeriodSeconds = 30;  // Seconds after EA init during which new DD locks are suppressed (calc/display unaffected)

input group "=== Risk Limits: Per-Trade / Total Open ==="
input double RiskPerTrade = 0.25;             // Full risk per trade (%) - max 3%, halved automatically when Half Risk toggled
input double In_MaxTotalRisk = 5.0;              // Max total open risk (%) - blocks NEW entries - max 10%

// v74.4 (HF4): moved here (display order only) - the floating limit sits next to the other loss limits.
input group "=== Floating Drawdown Protection (v9.5) ==="
input bool   In_InpEnableFloatingDD     = true; // Enable emergency close on floating DD
input double In_InpMaxFloatingDDPercent = 2.0;  // Max floating loss before EMERGENCY close-ALL (%)

input group "=== Risk Limits: Daily ==="
input double In_MaxDailyNetLossAllowed   = 3.0;  // Max Daily Net Loss Allowed % - max 6%
input bool   In_EnableDailyDD   = true;   // Enable Daily Net Loss lock (blocks new entries once daily limit is hit)
// v51 (Parking Lot #1): تا این نسخه Daily برخلاف Weekly/Monthly یه قفل واقعی/persisted نداشت -
// صرفاً یه مقایسه‌ی زنده بود (GetDailyRisk() >= g_effMaxDailyRisk در CheckLimits)، پس عوض‌کردن
// MaxDailyNetLossAllowed یا خاموش/روشن‌کردن EnableDailyDD وسط روز فوراً قفل رو دور می‌زد، بدون
// جریمه. DailyDDLockHours دقیقاً هم‌الگوی WeeklyDDHours/MonthlyDDDays - مدت قفل بعد از برخورد به
// آستانه. پیش‌فرض اولیه ۲۴ ساعت بود ولی طبق بازبینی Mahmoud به ۸ ساعت تغییر کرد: نسبت قفل/دوره
// در Weekly (~۲۹٪ = ۴۸از۱۶۸) و Monthly (~۲۳٪ = ۱۶۸از۷۲۰) خیلی کمتر از ۱۰۰٪ (۲۴از۲۴) بود که ۲۴
// ساعت برای Daily می‌داد - یه روز کامل تعطیلی نسبت به دو تای دیگه بی‌تناسب سنگین بود. برخورد به
// سقف ضرر روزانه معمولاً عصر/اوایل شب اتفاق می‌افته نه صبح، پس ۸ ساعت هم کافیه از مرز روز رد بشه
// (همون هدف اصلی - جلوگیری از دورزدن با رسیدن روز بعد) و هم نسبتش به طول دوره منطقی‌تر بمونه.
input int    In_DailyDDLockHours = 8;     // Daily lock duration after breach (hours)

input group "=== Risk Limits: Weekly ==="
input double In_MaxWeeklyNetLossAllowed  = 8.0;  // Max Weekly Net Loss Allowed % - max 16%
input bool   In_EnableWeeklyDD  = true;   // Enable Weekly Net Loss lock
input int    In_WeeklyDDHours  = 48;    // Weekly lock duration after breach (hours)

input group "=== Risk Limits: Monthly ==="
input double In_MaxMonthlyNetLossAllowed = 10.0; // Max Monthly Net Loss Allowed % - max 20%
input bool   In_EnableMonthlyDD = true;   // Enable Monthly Net Loss lock
input int    In_MonthlyDDDays  = 7;     // Monthly lock duration after breach (days)

input group "=== Trade Settings ==="
input double RiskReward   = 3.0;    // Initial Risk:Reward ratio (1-5, changeable via dashboard)
input int    MagicNumber  = 12345;  // Unique ID for this EA's orders

// v45 (Punch List Round 3, Item 9): سه زیربخش به‌جای یه گروه تخت - فقط ظاهری، هیچ Input جابه‌جا/
// حذف/اضافه نشده، فقط بازچینش و جداکننده‌های بیشتر.
input group "=== Break Even: Mode ==="
input EBreakEvenMode BreakEvenMode = BE_INDIVIDUAL; // Break Even Mode

input group "=== Break Even: Auto Trigger ==="
input bool   AutoBE       = false;  // Enable automatic Break Even (off = manual only)
input double BEatR        = 2.0;    // R level at which Auto BE triggers

input group "=== Break Even: Reference / Spread ==="
input int    BEextra      = 2;      // Extra pips added above/below entry when BE triggers

input group "=== Auto Close At Time (FEAT-031) ==="
input bool   EnableAutoCloseAtHour = false;   // Close ALL open positions once per day at the time below (off = no change in behavior)
input string AutoCloseTime         = "11:55"; // HH:MM in BROKER (server) time - compared directly with TimeCurrent(), no timezone conversion

input group "=== Cooldown: Market (losing streak) ==="
input bool   In_EnableMarketCD   = true;  // Enable Market Cooldown (losing streak lock)
input int    In_MarketCDCount    = 4;     // Consecutive stop-losses to trigger lock
input int    In_MarketCDHours    = 2;     // Market Cooldown lock duration (hours)
input int    In_MarketCDResetHours = 3;   // Hours since last SL close before streak counter resets

input group "=== Cooldown: Behavior (early exit) ==="
input bool   In_EnableBehaviorCD = true;  // Enable Behavior Cooldown (early exit lock - triggers: Early Exit, Management Before Reward 1, Stop Loss Change)
input int    In_BehaviorCDCount  = 4;     // Early exits (before +1R) to trigger lock
input int    In_BehaviorCDHours  = 1;     // Behavior Cooldown lock duration (hours)

input group "=== Entry Spacing ==="
input bool   In_EnableEntryInterval    = true;  // Enable minimum time gap between entries
input int    In_MinEntryIntervalMinutes = 5;    // Minimum minutes required between entries

input group "=== SL Tampering Protection (v41 - BUG-018) ==="
input double In_MaxSLWidenMultiplier = 2.0; // Max allowed SL widening vs original risk distance (e.g. 2.0 = up to 2x original SL distance before auto-correction). Does NOT limit tightening the SL (reducing risk).

// v39 (FEAT: Multiple Trailing Modes): حالت‌های موجود برای موتور Trailing -
// TRAIL_CANDLE = رفتار فعلی/پیش‌فرض دست‌نخورده (بر پایه‌ی سقف/کف کندل بسته‌شده، v12/v13)
// TRAIL_EMA = مسیر جدید موازی - SL بر اساس مقدار EMA کندل بسته‌شده دنبال می‌شه
// این enum قبل از گروه Inputها تعریف شده چون Input مربوط به TrailingMode به این نوع نیاز داره.
enum ETrailingMode { TRAIL_CANDLE, TRAIL_EMA };

input group "=== Trailing: Trigger ==="
input bool   EnableAutoTrailing     = false; // Auto-start Trailing when trade reaches trigger RR
input double AutoTrailingTriggerRR  = 3.0;   // RR level that triggers Auto Trailing (if enabled)

input group "=== Trailing: Mode ==="
input ETrailingMode TrailingMode    = TRAIL_CANDLE; // Trailing Mode: Candle (Structure) or EMA - default keeps existing behavior unchanged
// v49 (Punch List, Item 3): default bumped 60 -> 70 (Mahmoud's live observation: when price grazes
// EMA60 without actually breaking it, the move usually continues rather than reversing - the old
// default was too tight and got stopped out by ordinary noise around EMA60). Only the default
// value changed - input still fully user-adjustable, no other logic touched.
input int    TrailingEMAPeriod      = 70;    // EMA period for EMA Trailing mode (Exponential MA, user-adjustable; 70 = smoother/longer-term trailing baseline)

// v40 (FEAT-019): همون الگوی Reward-Based Automation موجود (Auto BE / Auto Trailing) - وقتی
// معامله به RR تعیین‌شده برسه، درصد مشخص‌شده از پوزیشن به‌صورت خودکار بسته می‌شه. از همون
// مسیر کد خانواده‌ی HalfClose() استفاده می‌کنه (HalfCloseTicket - پایین‌تر)؛ منطق core دوباره
// نوشته نشده، فقط trigger خودکار روش سوار شده.
input group "=== Auto Half Close: Trigger ==="
input bool   EnableAutoHalfClose    = false; // Auto Half Close when trade reaches trigger RR
input double AutoHalfCloseTriggerRR = 3.0;   // RR level that triggers Auto Half Close (if enabled)

input group "=== Auto Half Close: Amount ==="
input double AutoHalfClosePercent   = 50.0;  // Percent of position to close when Auto Half Close triggers

input group "=== Panel Position ==="
input bool   PanelRight   = true;   // Panel Position (Left Corner = False, Right Corner = True)

// v32 (Global Layout Scaling): dashboard size as an independent preference from dashboard TYPE
// (Trading vs Utility, v31). One multiplier, applied identically to both dashboards' shared
// layout-constant system (PW/TH/MX/GP/ALERT_H/... from v28) - not two separate scaling paths.
// Input-only (requires EA restart to change) rather than a dashboard control: see v32 changelog
// for the reasoning - short version is a live-rescale control would need every open panel object
// resized/repositioned in place (or a full ObjectsDeleteAll+BuildPanel rebuild) triggered from
// inside OnChartEvent, on top of persisting the choice - meaningfully more moving parts than an
// Input for a preference that's set once and rarely touched, so this defaults to the simpler path.
enum ELayoutScale
{
   LAYOUT_100 = 100,  // 100% (Default)
   LAYOUT_90  = 90,   // 90%
   LAYOUT_80  = 80    // 80%
};
enum EDashTheme
{
   THEME_MONO    = 1,   // Mono Gray (New - light)
   THEME_CLASSIC = 0    // Classic (dark)
};
input EDashTheme DashTheme = THEME_MONO; // Dashboard theme (EA restart to change)
input ELayoutScale LayoutScale = LAYOUT_100; // Dashboard size - applies to Trading + Utility (EA restart to change)

// v68 (بازطراحی v67 طبق فیدبک محمود): از یه ساعت ثابت روزانه به export بعد از هر بسته‌شدن
// معامله تغییر کرد - همون تابع موجود ExportTradeJournalCSV() (v55) کاملاً دست‌نخورده، فقط
// caller/trigger عوض شد (حالا از CheckClosedTrades()، RM_CooldownEngine.mqh). توضیح ورودی
// زیر عمداً انگلیسیه - فونت فارسی توی دیالوگ Inputs متاتریدر درست رندر نمی‌شه/خونا نیست.
input group "=== Auto Export CSV (v68) ==="
input bool AutoExportOnClose = true; // Automatically export the CSV Trade Journal right after any trade closes (independent of the manual EXPORT CSV button)

// v75.1 (MT4 v106 FEAT-047): شدت خطوط و عدد ساعت KEY TIME. تنظیم نمایشی هر چارت است.
// مقدار = درصد ترکیب رنگ بک‌گراند به سمت سفید/سیاه برای خطوط اصلی؛ فرعی با همان نسبت ۱۰:۱۷. خارج از بازه بی‌صدا clamp می‌شود.
#define KEYTIME_INTENSITY_MIN  5
#define KEYTIME_INTENSITY_MAX  80
input group "=== Trade History Boxes (v75.11) ==="
input int HistoryDaysBack = 7; // How many days back the History button draws closed trades (default 7)

input group "=== Key Time Lines (v75.1) ==="
input int InpKeyTimeIntensity = 30; // Key Time line intensity (%)

// v75.2: پیام تشخیصی «startup-grace diag» هر ثانیه در ۳۰ ثانیه‌ی اول هر شروع EA لاگ را شلوغ می‌کرد؛ برای فعال‌سازی true کن.
#define RM_GRACE_DIAG false

// === v75.15 (MT4 v101/v102/v104 port): shared account-wide settings ===
// Inputs with In_ prefix are the 22 account-wide settings; MQL5 inputs are read-only, so the working globals below
// (same names as before - no other code changes) are filled from In_ in OnInit and then from the shared GV block.
input bool PublishSettings = false; // ON = this chart's shared inputs are WRITTEN to all charts (turn OFF after publishing; OFF = this chart uses the shared values)
double MaxTotalRisk = In_MaxTotalRisk;
double MaxDailyNetLossAllowed = In_MaxDailyNetLossAllowed;
bool EnableDailyDD = In_EnableDailyDD;
int DailyDDLockHours = In_DailyDDLockHours;
double MaxWeeklyNetLossAllowed = In_MaxWeeklyNetLossAllowed;
bool EnableWeeklyDD = In_EnableWeeklyDD;
int WeeklyDDHours = In_WeeklyDDHours;
double MaxMonthlyNetLossAllowed = In_MaxMonthlyNetLossAllowed;
bool EnableMonthlyDD = In_EnableMonthlyDD;
int MonthlyDDDays = In_MonthlyDDDays;
bool InpEnableFloatingDD = In_InpEnableFloatingDD;
double InpMaxFloatingDDPercent = In_InpMaxFloatingDDPercent;
bool EnableMarketCD = In_EnableMarketCD;
int MarketCDCount = In_MarketCDCount;
int MarketCDHours = In_MarketCDHours;
int MarketCDResetHours = In_MarketCDResetHours;
bool EnableBehaviorCD = In_EnableBehaviorCD;
int BehaviorCDCount = In_BehaviorCDCount;
int BehaviorCDHours = In_BehaviorCDHours;
bool EnableEntryInterval = In_EnableEntryInterval;
int MinEntryIntervalMinutes = In_MinEntryIntervalMinutes;
double MaxSLWidenMultiplier = In_MaxSLWidenMultiplier;

string RM_CfgKey(string n) { return "RM_CFG_A" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + n; }
string RM_CfgVerKey()      { return RM_CfgKey("VER"); }
double g_cfgVerSeen = 0;
#define RM_CFG_N 22
string g_cfgNames = "MaxTotalRisk,MaxDailyNetLossAllowed,EnableDailyDD,DailyDDLockHours,MaxWeeklyNetLossAllowed,EnableWeeklyDD,WeeklyDDHours,MaxMonthlyNetLossAllowed,EnableMonthlyDD,MonthlyDDDays,InpEnableFloatingDD,InpMaxFloatingDDPercent,EnableMarketCD,MarketCDCount,MarketCDHours,MarketCDResetHours,EnableBehaviorCD,BehaviorCDCount,BehaviorCDHours,EnableEntryInterval,MinEntryIntervalMinutes,MaxSLWidenMultiplier";
string RM_CfgInstTag() { return Symbol() + "/" + IntegerToString((int)Period()); }
string RM_CfgPrevKey(int i) { return "RM_CFGPREV_" + IntegerToString((long)ChartID()) + "_" + IntegerToString(i); }

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

void RM_CfgPublish()
{
   double v[RM_CFG_N]; RM_CfgInVals(v);
   string nm[]; StringSplit(g_cfgNames, ',', nm);
   for(int i=0;i<RM_CFG_N;i++) GlobalVariableSet(RM_CfgKey(nm[i]), v[i]);
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

// v104 port: on an inputs-dialog change (REASON_PARAMETERS) with PublishSettings OFF, only the fields the user changed are published.
// MQL5 re-creates globals on parameter change, so the previous In_ values are kept in per-chart GVs.
void RM_CfgAutoPublishChanged(double &cur[])
{
   if(PublishSettings || UninitializeReason() != REASON_PARAMETERS) return;
   if(!GlobalVariableCheck(RM_CfgVerKey()) || !GlobalVariableCheck(RM_CfgPrevKey(0))) return;
   string nm[];
   if(StringSplit(g_cfgNames, ',', nm) != RM_CFG_N) return;
   int n = 0; string list = "";
   for(int i=0;i<RM_CFG_N;i++)
   {
      if(!GlobalVariableCheck(RM_CfgPrevKey(i))) continue;
      if(MathAbs(cur[i] - GlobalVariableGet(RM_CfgPrevKey(i))) < 0.0000001) continue;
      GlobalVariableSet(RM_CfgKey(nm[i]), cur[i]);
      list += (n>0 ? "," : "") + nm[i];
      n++;
   }
   if(n == 0) return;
   GlobalVariableSet(RM_CfgVerKey(), GlobalVariableGet(RM_CfgVerKey()) + 1.0);
   Print("[RM-CFG] auto-published ", IntegerToString(n), " changed input(s) from ", RM_CfgInstTag(), ": ", list);
}

// OnInit: block missing or PublishSettings=true -> publish this chart's values; otherwise read from the block
void RM_LoadSharedSettings()
{
   double curIn[RM_CFG_N];
   RM_CfgInVals(curIn);
   RM_CfgAutoPublishChanged(curIn);
   bool have = GlobalVariableCheck(RM_CfgVerKey());
   if(PublishSettings || !have)
   {
      RM_CfgPublish();
      Print("[RM-CFG] shared settings ", (have ? "PUBLISHED" : "created (first chart)"), " by ", RM_CfgInstTag(), " (version ", DoubleToString(g_cfgVerSeen,0), ")");
      if(PublishSettings) Print("[RM-CFG] Publish Settings is ON - turn it OFF after publishing so other charts are not overwritten on restart");
   }
   else
   {
      RM_CfgApply();
      Print("[RM-CFG] shared settings loaded on ", RM_CfgInstTag(), " (version ", DoubleToString(g_cfgVerSeen,0), ")");
   }
   for(int i=0;i<RM_CFG_N;i++) GlobalVariableSet(RM_CfgPrevKey(i), curIn[i]);
}

// every tick: a single GlobalVariableGet; if another chart published, re-read and recompute effective ceilings
void RM_CfgSyncIfChanged()
{
   if(!GlobalVariableCheck(RM_CfgVerKey())) return;
   if(GlobalVariableGet(RM_CfgVerKey()) == g_cfgVerSeen) return;
   RM_CfgApply();
   ApplyRiskCeilings();
   Print("[RM-CFG] shared settings updated from another chart, applied on ", RM_CfgInstTag(), " (version ", DoubleToString(g_cfgVerSeen,0), ")");
}
