//+------------------------------------------------------------------+
//| RM_Config.mqh                                                    |
//| Risk Manager EA - Configuration (Architecture Refactor, R1)       |
//| استخراج‌شده از RiskManager_EA_v45.mq4 - شامل تمام Input declarations|
//| و enum/constant های وابسته به Input. صرفاً جابه‌جایی کد، بدون هیچ  |
//| تغییر مقدار/رفتار (Golden Rule فاز R1).                            |
//+------------------------------------------------------------------+

// v45 (Punch List Round 3, Item 8): سه فایل صوتی داخل خود .ex4 جاسازی می‌شن (به‌جای خوندن از
// MQL4/Sounds در لحظه‌ی اجرا) - روی هر نصب/بروکر جدید بدون کپی دستی کار می‌کنه. PlaySound() باید
// با پیشوند "::" صدا زده بشه تا از منبع جاسازی‌شده بخونه، نه از دیسک.
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
#define SCREENSHOT_FOLDER "TRADE SCREENSHOTS"

input group "=== Startup Safety ==="
// v72 (URGENT bugfix - false Weekly/Monthly DD lock on real-account restart, account A4160750):
// see RM_DrawdownEngine.mqh/CheckDrawdownLimits() for full context. On a slow real-account
// reconnect, AccountBalance()/order history can read stale/transitional values for a brief
// window right after OnInit() completes - long enough to produce a false drawdown breach.
// StartupGracePeriodSeconds suppresses *new* lock-setting only (calc/display still run
// normally) for this many seconds after OnInit(). The observed real incident had a 7s gap
// between "loaded successfully" and "initialized" alone; 30s gives real margin beyond that
// while staying short enough that genuine live-trading breaches are still caught within
// moments once the window ends. Does not affect already-active locks loaded via
// LoadDrawdownState() - only suppresses freshly-triggered ones.
input int    StartupGracePeriodSeconds = 30;  // Seconds after EA init during which new DD locks are suppressed (calc/display unaffected)

// v77 (URGENT bugfix - Pattern A, false Monthly/Weekly DD lock after long sleep/reconnect WITHOUT
// OnInit, real account A4160750): StartupGracePeriodSeconds (v72) only opens a grace window after a
// *real OnInit*. The 2026-08-10 incident had NO OnInit - the terminal simply resumed from a ~9h
// machine sleep (OnTimer interval jumped 32,202,250ms) and fired a false Monthly DD lock 37s later,
// because AccountBalance()/history/period-start values were still transitional right after wake and
// g_eaStartupTime was ~9h stale (so inStartupGrace was false). This threshold makes CheckDrawdownLimits()
// ALSO re-open the exact same grace window whenever the gap between two consecutive DD-check cycles
// exceeds this many seconds - i.e. treat "abnormal time gap between calculations" identically to a
// fresh OnInit. Measured belt-and-suspenders via BOTH GetTickCount() (wall-clock, which captured this
// very incident) and TimeCurrent() (market-time, catches reconnect tick-replay). Default 120s: far above
// any normal 1-tick spacing on XAUUSD, well below the ~9h real gap, so it only fires on genuine gaps.
input int    LongGapGraceThresholdSeconds = 120;  // Gap (s) between DD-check cycles that re-opens the startup grace window (long sleep/reconnect protection)

input group "=== Risk Limits: Per-Trade / Total Open ==="
input double RiskPerTrade = 0.25;             // Full risk per trade (%) - max 3%, halved automatically when Half Risk toggled
input double In_MaxTotalRisk = 5.0;              // Max total open risk (%) - blocks NEW entries - max 10%

input group "=== Floating Drawdown Protection (v9.5, v102: moved up after Open Risk) ==="
input bool In_InpEnableFloatingDD = true; // Enable emergency close on floating DD
input double In_InpMaxFloatingDDPercent = 2.0;  // Max floating loss before EMERGENCY close-ALL (%)

input group "=== Risk Limits: Daily ==="
input double In_MaxDailyNetLossAllowed = 3.0;  // Max Daily Net Loss Allowed % - max 6%
input bool In_EnableDailyDD = true;   // Enable Daily Net Loss lock (blocks new entries once daily limit is hit)
// v51 (Parking Lot #1): تا این نسخه Daily برخلاف Weekly/Monthly یه قفل واقعی/persisted نداشت -
// صرفاً یه مقایسه‌ی زنده بود (GetDailyRisk() >= g_effMaxDailyRisk در CheckLimits)، پس عوض‌کردن
// MaxDailyNetLossAllowed یا خاموش/روشن‌کردن EnableDailyDD وسط روز فوراً قفل رو دور می‌زد، بدون
// جریمه. DailyDDLockHours دقیقاً هم‌الگوی WeeklyDDHours/MonthlyDDDays - مدت قفل بعد از برخورد به
// آستانه. پیش‌فرض اولیه ۲۴ ساعت بود ولی طبق بازبینی Mahmoud به ۸ ساعت تغییر کرد: نسبت قفل/دوره
// در Weekly (~۲۹٪ = ۴۸از۱۶۸) و Monthly (~۲۳٪ = ۱۶۸از۷۲۰) خیلی کمتر از ۱۰۰٪ (۲۴از۲۴) بود که ۲۴
// ساعت برای Daily می‌داد - یه روز کامل تعطیلی نسبت به دو تای دیگه بی‌تناسب سنگین بود. برخورد به
// سقف ضرر روزانه معمولاً عصر/اوایل شب اتفاق می‌افته نه صبح، پس ۸ ساعت هم کافیه از مرز روز رد بشه
// (همون هدف اصلی - جلوگیری از دورزدن با رسیدن روز بعد) و هم نسبتش به طول دوره منطقی‌تر بمونه.
input int In_DailyDDLockHours = 8;     // Daily lock duration after breach (hours)

input group "=== Risk Limits: Weekly ==="
input double In_MaxWeeklyNetLossAllowed = 8.0;  // Max Weekly Net Loss Allowed % - max 16%
input bool In_EnableWeeklyDD = true;   // Enable Weekly Net Loss lock
input int In_WeeklyDDHours = 48;    // Weekly lock duration after breach (hours)

input group "=== Risk Limits: Monthly ==="
input double In_MaxMonthlyNetLossAllowed = 10.0; // Max Monthly Net Loss Allowed % - max 20%
input bool In_EnableMonthlyDD = true;   // Enable Monthly Net Loss lock
input int In_MonthlyDDDays = 7;     // Monthly lock duration after breach (days)

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
input bool In_EnableMarketCD = true;  // Enable Market Cooldown (losing streak lock)
input int In_MarketCDCount = 4;     // Consecutive stop-losses to trigger lock
input int In_MarketCDHours = 2;     // Market Cooldown lock duration (hours)
input int In_MarketCDResetHours = 3;   // Hours since last SL close before streak counter resets

input group "=== Cooldown: Behavior (early exit) ==="
input bool In_EnableBehaviorCD = true;  // Enable Behavior Cooldown (early exit lock - triggers: Early Exit, Management Before Reward 1, Stop Loss Change)
input int In_BehaviorCDCount = 4;     // Early exits (before +1R) to trigger lock
input int In_BehaviorCDHours = 1;     // Behavior Cooldown lock duration (hours)

input group "=== Entry Spacing ==="
input bool In_EnableEntryInterval = true;  // Enable minimum time gap between entries
input int In_MinEntryIntervalMinutes = 5;    // Minimum minutes required between entries

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
input ELayoutScale LayoutScale = LAYOUT_100; // Dashboard size - applies to Trading + Utility (EA restart to change)

// v68 (بازطراحی v67 طبق فیدبک محمود): از یه ساعت ثابت روزانه به export بعد از هر بسته‌شدن
// معامله تغییر کرد - همون تابع موجود ExportTradeJournalCSV() (v55) کاملاً دست‌نخورده، فقط
// caller/trigger عوض شد (حالا از CheckClosedTrades()، RM_CooldownEngine.mqh). توضیح ورودی
// زیر عمداً انگلیسیه - فونت فارسی توی دیالوگ Inputs متاتریدر درست رندر نمی‌شه/خونا نیست.
input group "=== Auto Export CSV (v68) ==="
input bool AutoExportOnClose = true; // Automatically export the CSV Trade Journal right after any trade closes (independent of the manual EXPORT CSV button)

// v85 (کار اول): دکمه‌ی History در Utility - برای هر معامله‌ی بسته‌شده‌ی این نماد/مجیک در N روز اخیر، دو باکس (ورود->TP روشن، ورود->SL تیره)
input group "=== Trade History Boxes (v85) ==="
input int HistoryDaysBack = 7; // How many days back the History button draws closed trades (default 7)

// v106 (FEAT-047): شدت خطوط و عدد ساعت KEY TIME. تنظیم نمایشیِ هر چارت است (جزو ۲۲ ورودی مشترک نیست و Publish نمی‌شود).
// مقدار = درصد ترکیب رنگ بک‌گراند به سمت سفید/سیاه برای خطوط اصلی؛ خطوط فرعی با همان نسبت ۱۰:۱۷ (حداقل ۸).
// خارج از بازه‌ی KEYTIME_INTENSITY_MIN..MAX بی‌صدا clamp می‌شود (داخل GetKeyTimeLineColor در RM_Tools.mqh).
#define KEYTIME_INTENSITY_MIN  5
#define KEYTIME_INTENSITY_MAX  80
input group "=== Key Time Lines (v106) ==="
input int InpKeyTimeIntensity = 30; // Key Time line intensity (%)


// === v102: تنظیمات مشترک بین چارت‌ها ===========================================================
// ورودی‌های حساب‌محور (ریسک کل/روزانه/هفتگی/ماهانه، Floating DD، Cooldown، فاصله‌ی ورود، SL Tamper) با پیشوند In_ تعریف شده‌اند.
// متغیرهای هم‌نامِ قبلی حالا سراسریِ قابل‌تغییرند و در OnInit از بلوک GV مشترک پر می‌شوند (RM_LoadSharedSettings در فایل اصلی).
input group "=== Shared Settings (v102) ==="
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
