//+------------------------------------------------------------------+
//| RM_Tools.mqh                                                       |
//| Risk Manager EA - Chart Tools & Utility Drawings (Architecture      |
//| Refactor, R7)                                                       |
//| استخراج‌شده از RiskManager_EA_v45_R6.mq4 - ابزارهای دستی چارت:       |
//| Fibonacci R-Multiple/Measure Move (arm+click flow)، Candle Timer،   |
//| Daily/Weekly/Monthly H/L، BE Reference Line، Hide/Show Objects.     |
//| R8 (Architecture Refactor، فاز نهایی): HLine()/HLineLabel()/         |
//| GetBasketAveragePrice() که قبلاً به‌خاطر اشتراک بین چند ماژول در      |
//| فایل اصلی مونده بودن، حالا به RM_Common.mqh منتقل شدن (خونه‌ی نهایی   |
//| توابع چندماژوله‌ی مشترک). EstimateServerTime() هم طبق grep تک‌مصرف‌   |
//| کننده بود (فقط همین‌جا) پس مستقیماً به همین فایل منتقل شد، نه          |
//| RM_Common.mqh - globalهای g_ctLastServerSync/g_ctLastLocalSync/      |
//| g_ctLastEstimate از قبل همین‌جا مقیم بودن.                            |
//| GetContrastColor() و AutoHalfPreviewLineName/LabelName() هم در       |
//| اسکوپ اصلی این فاز نبودن ولی به این ماژول/AutoActions تعلق دارن -    |
//| Parking Lot این فاز رو ببین. صرفاً جابه‌جایی کد، بدون تغییر           |
//| مقدار/رفتار (Golden Rule فاز R7).                                    |
//+------------------------------------------------------------------+

// === v42 (Punch List, Part 1): Fibo arm-state (R/R + Measure Move) - "arm, then click the
// chart" placement tools. g_fiboArmedRR/g_fiboArmedMeasure توی RM_Dashboard.mqh هم خونده
// می‌شن (رنگ دکمه) - طبق grep تأیید شد؛ چون MQL4 کل برنامه رو یک واحد کامپایل می‌کنه (همون
// الگوی IsTradingAllowed() که RM_Dashboard.mqh از RM_CooldownEngine.mqh - ماژولی که بعدتر
// include می‌شه - صدا می‌زنه)، ترتیب include مشکلی ایجاد نمی‌کنه.
// v42 (Punch List, Part 1): R/R and Measure Move reworked from "instant auto-anchor near last
// candle" action buttons into "arm, then click the chart" placement tools - same two-click
// point-capture idea already used for Entry/SL (g_step/STEP_ENTRY/STEP_SL), but kept as a fully
// separate/independent flag set so nothing about the existing trade-entry click workflow is
// touched. Clicking the button arms it (button turns the shared Tools-drawer active teal,
// CLR_TOOLS_ACTIVE); the trader then clicks two points directly on the chart (base, then target)
// exactly like MT4's own native Fibo/measure tools; each placement builds a brand-new, uniquely-
// named object (g_fiboInstanceSeq) so multiple instances can coexist across the chart in the same
// session - no more manual deletion of the old one, and no more fixed single-object overwrite.
// g_rrFlashEnd/g_measureFlashEnd (old one-shot post-click flash) are superseded by this arm/point-
// capture flow and removed; CLR_BTN_DEFAULT/BTN_FLASH_MS below are still used by BE/Half/Full Close.
bool     g_fiboArmedRR      = false;  // true while R/R is armed and waiting for chart clicks
bool     g_fiboArmedMeasure = false;  // true while Measure Move is armed and waiting for chart clicks
bool     g_fiboWaitingP2    = false;  // false = waiting for the 1st (base) click, true = waiting for the 2nd (target) click
datetime g_fiboP1Time       = 0;
double   g_fiboP1Price      = 0;
uint     g_fiboArmDeadline  = 0;      // GetTickCount()-based, same pattern as the flash deadlines below - 0 = not armed
int      g_fiboInstanceSeq  = 0;      // ever-increasing - appended to the object name so every placement is a fresh instance
#define FIBO_ARM_MS     10000         // v42 (Punch List, Item 1.3): originally 5s auto-timeout back to grey if the
                                       // trader doesn't click in time; v54 (independent small fix, Mahmoud feedback):
                                       // 5s proved too short in practice on some setups - bumped to 10s. Pure constant
                                       // change only, arm/disarm logic itself (ArmFiboTool()/CancelFiboArm()/the
                                       // CheckButtonFlashExpiry() deadline check) is untouched.
// v42 (Punch List follow-up, Mahmoud feedback): fixed names for the live "rubber-band" preview
// object shown while waiting for the 2nd click - moved up here (next to the other Fibo arm-state
// declarations) instead of down by FIBO_RMULT_OBJ/FIBO_MEASURE_OBJ, since #define is a textual
// preprocessor substitution in MQL4 (not a function) and CancelFiboArm() below uses these names -
// they must appear earlier in the file than that first use, or the compiler reports them as
// undeclared identifiers.
#define FIBO_RMULT_PREVIEW   "RM9LN_FIBO_RMULT_PREVIEW"
#define FIBO_MEASURE_PREVIEW "RM9LN_FIBO_MEASURE_PREVIEW"

// === v26 (FEAT-018): Tools drawer + Candle Timer ===
// v43 (Item 3): g_toolsDrawerOpen removed - the "Tools" section no longer expands/collapses,
// its rows are always visible now.
// v79 (Item 4 - همیشه‌فعال): g_candleTimerOn/دکمه‌ی توگل/پرسیستنس GlobalVariable مربوطه کاملاً
// حذف شدن - شمارش معکوس کندل دیگه یه ویژگی قابل‌خاموش‌کردن نیست، مستقیماً از OnInit() همیشه
// فعاله (UpdateCandleTimerChart() صدا زده می‌شه بدون هیچ چک g_candleTimerOn). چیزی برای
// persist کردن نمونده چون همیشه روشنه.
// v26.4 (FEAT-018 fix): TimeCurrent() فقط با تیک واقعی جلو می‌ره (کوانتیزه به تیک، نه ساعت واقعی) -
// این دو مقدار برای درون‌یابی نرم بین دو تیک واقعی با ساعت محلی سیستم استفاده می‌شن (EstimateServerTime)
datetime g_ctLastServerSync = 0;
datetime g_ctLastLocalSync  = 0;
datetime g_ctLastEstimate   = 0;  // v26.9 (FEAT-018 fix): تضمین monotonic - تخمین هیچ‌وقت نباید به عقب برگرده
uint     g_ctLastRedrawMs   = 0;  // v26.7 (FEAT-018 fix): throttle برای ChartRedraw() صریح از مسیر OnTick - نوعش uint چون GetTickCount() همینو برمی‌گردونه (v26.8: فیکس هشدار type conversion)

// R8 (Architecture Refactor، فاز نهایی): EstimateServerTime() از فایل اصلی به اینجا منتقل شد -
// طبق grep تک‌مصرف‌کننده‌ست (فقط همین ماژول، تابع UpdateCandleTimerChart() پایین‌تر همین فایل)،
// پس مشترک بین چند ماژول نیست و نیازی به RM_Common.mqh نداره. globalهای بالا
// (g_ctLastServerSync/g_ctLastLocalSync/g_ctLastEstimate) از قبل همین‌جا مقیم بودن؛ صرفاً
// جابه‌جایی کد، بدون تغییر مقدار/رفتار (Golden Rule).
// v26.4 (FEAT-018 fix): TimeCurrent() برمی‌گردونه آخرین زمان سرور که از یه تیک واقعی رسیده -
// بین دو تیک واقعی اصلاً جلو نمی‌ره (کوانتیزه‌ست). همین باعث می‌شه شمارش معکوس، حتی با
// EventSetTimer(1)، روی نمادهایی که تیکشون فاصله داره بین دو تیک واقعی ثابت بمونه و بعد یهو
// چند ثانیه جلو بپره - دقیقاً همون لگ ریزی که گزارش شد. این تابع با TimeLocal() (ساعت واقعی
// خود سیستم، هر ثانیه‌ی واقعی جلو می‌ره) بین دو تیک درون‌یابی می‌کنه، و با هر تیک واقعی جدید
// دوباره دقیقاً روی TimeCurrent() کالیبره می‌شه - پس نه drift بلندمدت داره، نه بین دو تیک ثابت می‌مونه.
// v26.9 (FEAT-018 fix): مشکل جدید - همین کالیبره‌شدن دوره‌ای گاهی تخمین رو به عقب می‌بره: اگه
// درون‌یابی محلی بین دو تیک کمی جلوتر از واقعیت رفته باشه، تیک بعدی که میاد و دوباره دقیقاً
// روی TimeCurrent() ست می‌کنه، ممکنه عددی کمتر از چیزی بده که همین الان رو چارت نشون داده
// بودیم - یعنی شمارش لحظه‌ای به عقب می‌پره (دقیقاً چیزی که گزارش شد). فیکس: تخمین رو monotonic
// نگه می‌داریم - هیچ‌وقت اجازه نمی‌دیم کمتر از آخرین مقداری بشه که قبلاً برگردوندیم، چون زمان
// واقعی هیچ‌وقت به عقب نمی‌ره.
datetime EstimateServerTime()
{
   if(TimeCurrent() != g_ctLastServerSync)
   {
      g_ctLastServerSync = TimeCurrent();
      g_ctLastLocalSync  = TimeLocal();
   }
   datetime est = (g_ctLastServerSync == 0) ? TimeCurrent() : g_ctLastServerSync + (TimeLocal() - g_ctLastLocalSync);
   if(est < g_ctLastEstimate) est = g_ctLastEstimate;  // v26.9: هرگز به عقب برنگرده
   g_ctLastEstimate = est;
   return est;
}

// === v33 (Utility Phase A, Part 1): Tools drawer expansion. PD/PW, Hide/Show, and BE Ref are
// intentionally NOT persisted (reset to off on every EA restart) - no persistence requirement was
// given for those.
// v33.2 (Mahmoud feedback): Session Timer and the 3 Moving Averages tools were both removed
// entirely (Session Timer per explicit request; the 3 MAs because manually-drawn OBJ_TREND
// segments weren't what was wanted - a genuinely native, zero-EA-computation indicator needs
// ChartApplyTemplate() with a pre-built .tpl file, which is a bigger follow-up, not this version).
// All their global state, GlobalVariable persistence, on-chart drawing functions, OnInit/OnDeinit/
// OnTick/OnTimer hooks, OnChartEvent handlers, and BuildPanel() rows are gone, not just hidden.
// v34 (Items 3+5): PD/PW High-Low split into three fully independent toggles - each timeframe now
// has its own state, so switching one on/off never affects the others.
bool     g_hlDailyOn     = false;  // Daily H/L toggle
bool     g_hlWeeklyOn    = false;  // Weekly H/L toggle
bool     g_hlMonthlyOn   = false;  // Monthly H/L toggle - new in v34
bool     g_beRefOn        = false;  // BE reference line toggle - preview of basket-average BE price

// v34 (Item 2)/v34.4 (Item 1 - Remove Indicators dropped entirely): Hide/Show All Drawings was
// split into two toggles in the base v34 build (chart objects vs real attached indicators); the
// indicator side is now removed altogether per Mahmoud's decision (no workable non-destructive
// mechanism exists in MQL4 - see the v34.2/v34.3 discussion). Only the objects toggle remains.
bool     g_objectsHidden    = false;  // chart objects (ObjectsTotal()/OBJPROP_TIMEFRAMES) toggle
// Snapshots every non-panel chart object's OBJPROP_TIMEFRAMES before hiding it, so toggling back
// restores each object's exact original visibility (not a blanket "show everywhere").
string   g_hiddenObjNames[];
long     g_hiddenObjTF[];
int      g_hiddenObjCount = 0;

// v34 (Item 3+5): PD/PW/Monthly High-Low reference lines - fixed names (one instance of each per
// chart, not per-ticket). Renamed from v33's PDPW_LN_* to HL_LN_* now that Daily/Weekly/Monthly are
// three independent tools instead of one combined "PD/PW" toggle - object names themselves are
// purely internal and never shown to the trader, so the rename has no visible effect.
#define HL_LN_D1HIGH  "RM9LN_DHIGH"
#define HL_LN_D1LOW   "RM9LN_DLOW"
#define HL_LN_W1HIGH  "RM9LN_WHIGH"
#define HL_LN_W1LOW   "RM9LN_WLOW"
#define HL_LN_MN1HIGH "RM9LN_MHIGH"
#define HL_LN_MN1LOW  "RM9LN_MLOW"
// v48 (Item 3 - فیچر جدید): خط PDC (Previous Day Close) - فقط توی حالت Daily، همون توگل
// g_hlDailyOn - نه Weekly، نه Monthly.
#define HL_LN_D1CLOSE  "RM9LN_DCLOSE"
// v79 (FEAT-032): خط Open - قیمت باز-شدن. v83 (فیکس BUG گزارش‌شده - جزئیات کامل بالای
// UpdateDailyHL): شیفت از ۰ (کندل روز جاری) به ۱ اصلاح شد تا PDH/PDL/PDC/Open همه یک باکس
// بسته‌ی هم‌قاب از رِنج دیروز باشن؛ برچسب هم به "PDO" تغییر کرد. روی همون توگل واحد g_hlDailyOn
// سوار می‌شه - نه اینپوت/دکمه‌ی جدا.
#define HL_LN_D1OPEN   "RM9LN_DOPEN"
// v34.1 (Mahmoud feedback - line identification): small text labels sitting to the right of each
// H/L line so the trader can tell at a glance what each line is (e.g. "PDL" = Previous Day Low).
#define HL_LBL_D1HIGH  "RM9LB_DHIGH"
#define HL_LBL_D1LOW   "RM9LB_DLOW"
#define HL_LBL_W1HIGH  "RM9LB_WHIGH"
#define HL_LBL_W1LOW   "RM9LB_WLOW"
#define HL_LBL_MN1HIGH "RM9LB_MHIGH"
#define HL_LBL_MN1LOW  "RM9LB_MLOW"
#define HL_LBL_D1CLOSE "RM9LB_DCLOSE"  // v48 (Item 3)
#define HL_LBL_D1OPEN  "RM9LB_DOPEN"   // v79 (FEAT-032)
// Fibonacci R-Multiple - single reusable native OBJ_FIBO object, purely a manual drawing tool.
#define FIBO_RMULT_OBJ "RM9LN_FIBO_RMULT"
// v34 (Item 4): Fibonacci Measure Move - second, independent native OBJ_FIBO object, same manual-
// drawing philosophy as FIBO_RMULT_OBJ (no auto-anchor to trade data), own object name so the two
// tools never collide and can be dragged/repositioned independently of each other.
#define FIBO_MEASURE_OBJ "RM9LN_FIBO_MEASURE"
// v42 (Punch List follow-up): FIBO_RMULT_PREVIEW/FIBO_MEASURE_PREVIEW moved up next to the other
// Fibo arm-state globals (near FIBO_ARM_MS) - see the comment there for why.

// v34 (Item 1): shared contrast-aware color helper for every Tools drawing (Daily/Weekly/Monthly
// H/L, BE Ref Line, both Fibonacci tools) - same CHART_COLOR_BACKGROUND luminance logic
// UpdateCandleTimerChart() (v26.6) already uses, generalized to take a per-tool "on dark
// background" / "on light background" color pair instead of hardcoding one fixed color, so every
// Tools line stays both visually distinct from the others AND legible regardless of the trader's
// chart theme (previously fixed colors like the plain blue/orange PD/PW lines could go
// low-contrast on some chart themes).
color GetContrastColor(color forDarkBg, color forLightBg)
{
   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   int bgR = (int)(chartBg & 0xFF);
   int bgG = (int)((chartBg >> 8) & 0xFF);
   int bgB = (int)((chartBg >> 16) & 0xFF);
   double bgLuminance = 0.299*bgR + 0.587*bgG + 0.114*bgB; // same standard perceived-luminance formula as UpdateCandleTimerChart()
   return (bgLuminance > 140) ? forLightBg : forDarkBg;
}

// v33 (Part 1): same non-P-prefixed, MagicNumber-scoped naming convention as BasketAvgLineName()
// above - this is a DIFFERENT, read-only preview line (BE Ref Line toggle), kept under its own
// name so it never collides with the real BE Basket execution line that BasketAvgLineName() names.
string BERefLineName(bool isBuy) { return "RM9LN_BEREF_"+(isBuy?"BUY":"SELL")+"_"+IntegerToString(MagicNumber); }

// v34 (Items 3+5): PD/PW High-Low split into three fully independent toggles - Daily/Weekly/
// Monthly each with their own state, remove/update functions, and dashboard button. Reuses the
// same HLine() helper and the v33-final simple native-candle-read approach (iHigh()/iLow() shift 1
// directly off PERIOD_D1/PERIOD_W1/PERIOD_MN1) with the same history-readiness guard
// (iBars(...)<2 / <=0 checks) already proven working for Daily/Weekly.
// v48 (Item 3): PDC (D1CLOSE/LBL_D1CLOSE) هم اینجا اضافه شد - همون توگل Daily H/L، پاکسازی مشترک.
void RemoveDailyHL()   { ObjectDelete(0,HL_LN_D1HIGH);  ObjectDelete(0,HL_LN_D1LOW);  ObjectDelete(0,HL_LBL_D1HIGH);  ObjectDelete(0,HL_LBL_D1LOW); ObjectDelete(0,HL_LN_D1CLOSE); ObjectDelete(0,HL_LBL_D1CLOSE); ObjectDelete(0,HL_LN_D1OPEN); ObjectDelete(0,HL_LBL_D1OPEN); }

void RemoveWeeklyHL()  { ObjectDelete(0,HL_LN_W1HIGH);  ObjectDelete(0,HL_LN_W1LOW);  ObjectDelete(0,HL_LBL_W1HIGH);  ObjectDelete(0,HL_LBL_W1LOW); }

void RemoveMonthlyHL() { ObjectDelete(0,HL_LN_MN1HIGH); ObjectDelete(0,HL_LN_MN1LOW); ObjectDelete(0,HL_LBL_MN1HIGH); ObjectDelete(0,HL_LBL_MN1LOW); }

// v48 (Item 1 - چهارمین/نهایی تلاش، پیشنهاد خود Mahmoud): به‌جای هل‌دادن لنگر از عرض کل پنل
// رد بشه (که وسط چارت رو شلوغ می‌کرد)، این لیبل‌ها کلاً می‌رن سمت مقابل پنل - وقتی پنل باز و
// بالا-راسته، لیبل‌ها سمت چپ چارت می‌شینن؛ وقتی پنل باز و بالا-چپه، لیبل‌ها سمت راست می‌مونن
// (همون رفتار قبلی، چون اونجا دیگه پنل مزاحم نیست). وقتی پنل مینیمایزه هم اصلاً مزاحم نیست
// (بدنه‌ی پنل دیگه رسم نمی‌شه)، پس سمت راست پیش‌فرض کافیه.
bool ToolsLabelAnchorLeft() { return (!g_minimized && PanelRight); }

void UpdateDailyHL()
{
   if(!g_hlDailyOn) { RemoveDailyHL(); return; }
   if(iBars(Symbol(), PERIOD_D1) < 2) { RemoveDailyHL(); return; }
   double hi = iHigh(Symbol(), PERIOD_D1, 1);
   double lo = iLow (Symbol(), PERIOD_D1, 1);
   if(hi<=0 || lo<=0) { RemoveDailyHL(); return; }
   bool aLeft = ToolsLabelAnchorLeft();
   color c = GetContrastColor(C'80,180,255', C'0,90,170');  // blue family
   HLine(HL_LN_D1HIGH, hi, c, 1, STYLE_DASH);
   HLine(HL_LN_D1LOW,  lo, c, 1, STYLE_DASH);
   HLineLabel(HL_LBL_D1HIGH, hi, c, "PDH", true, aLeft);  // v34.1: Previous Day High; v43 (Item 5): above the line now
   HLineLabel(HL_LBL_D1LOW,  lo, c, "PDL", true, aLeft);  // v34.1: Previous Day Low; v43 (Item 5): above the line now

   // v48 (Item 3 - فیچر جدید): PDC (Previous Day Close) - فقط Daily، دقیقاً همون توگل بالا
   // (g_hlDailyOn) و همون history-readiness guard (iBars(...)<2 که همین تابع بالاتر چک کرده،
   // به‌علاوه‌ی چک close<=0 مخصوص خود این خط) - تا موقع لود نشدن هیستوری D1، خط اشتباه/صفر
   // کشیده نشه. رنگ کاملاً متفاوت از خانواده‌ی آبی High/Low همین ابزار و از رنگ‌های Weekly
   // (نارنجی)/Monthly (بنفش) هم جدا - خانواده‌ی سبز/زرد-سبز انتخاب شد تا تداخل بصری نداشته باشه.
   double pdc = iClose(Symbol(), PERIOD_D1, 1);
   if(pdc<=0) { ObjectDelete(0,HL_LN_D1CLOSE); ObjectDelete(0,HL_LBL_D1CLOSE); }
   else
   {
      color cClose = GetContrastColor(C'140,220,90', C'50,120,20');  // green family - distinct from PDH/PDL blue
      HLine(HL_LN_D1CLOSE, pdc, cClose, 1, STYLE_DASH);
      HLineLabel(HL_LBL_D1CLOSE, pdc, cClose, "PDC", true, aLeft);  // aboveLine=true, same convention as PDH/PDL
   }

   // v79 (FEAT-032 - فیچر جدید): خط Open - در v79 عمداً shift=0 (کندل روزِ جاری، هنوز در حال
   // شکل‌گیری) انتخاب شده بود، برخلاف PDH/PDL/PDC (شیفت=۱، کندل دیروزِ کامل‌شده).
   // فیکس (v83، گزارش Mahmoud ۲۰۲۶-۰۸-۲۰): این دقیقاً همون اختلافیه که باعث می‌شد خط Open غلط به
   // نظر برسه - این ابزار یک باکس بسته از رِنج *دیروز* رو نشون می‌ده (High/Low/Close همه شیفت=۱)،
   // ولی Open با شیفت=۰ یک مقدار کاملاً بی‌ربط از *امروز* رو وسط همون باکس می‌کشید - هر جای بازار
   // که امروز باشه، نه جایی که واقعاً به رِنج دیروز مربوط باشه؛ به همین خاطر محل خط "غلط"/بی‌ربط با
   // بقیه به نظر می‌رسید. فیکس: شیفت به ۱ تغییر کرد تا این خط هم واقعاً Previous Day Open باشه -
   // دقیقاً هم‌راستا و هم‌قاب با سه خط دیگه (منبع قیمت/HLine/HLineLabel هیچ‌کدوم عوض نشدن، فقط
   // همین یک عدد). برچسب هم از "OPEN" به "PDO" تغییر کرد تا با نام‌گذاری PDH/PDL/PDC هم‌خونی
   // داشته باشه و مقدار جدید (دیروز، نه امروز) رو درست نشون بده.
   double dOpen = iOpen(Symbol(), PERIOD_D1, 1);
   if(dOpen<=0) { ObjectDelete(0,HL_LN_D1OPEN); ObjectDelete(0,HL_LBL_D1OPEN); return; }
   color cOpen = GetContrastColor(C'230,230,235', C'90,90,95');  // white/grey family - distinct from High/Low/Close
   HLine(HL_LN_D1OPEN, dOpen, cOpen, 1, STYLE_DASH);
   HLineLabel(HL_LBL_D1OPEN, dOpen, cOpen, "PDO", true, aLeft);  // v83: "OPEN"->"PDO" - هم‌قرارداد PDH/PDL/PDC، بعد از فیکس شیفت بالا
}

void UpdateWeeklyHL()
{
   if(!g_hlWeeklyOn) { RemoveWeeklyHL(); return; }
   if(iBars(Symbol(), PERIOD_W1) < 2) { RemoveWeeklyHL(); return; }
   double hi = iHigh(Symbol(), PERIOD_W1, 1);
   double lo = iLow (Symbol(), PERIOD_W1, 1);
   if(hi<=0 || lo<=0) { RemoveWeeklyHL(); return; }
   bool aLeft = ToolsLabelAnchorLeft();  // v48 (Item 1) - ببین کامنت کامل بالای ToolsLabelAnchorLeft()
   color c = GetContrastColor(C'255,180,80', C'170,100,0');  // orange family
   HLine(HL_LN_W1HIGH, hi, c, 1, STYLE_DASH);
   HLine(HL_LN_W1LOW,  lo, c, 1, STYLE_DASH);
   HLineLabel(HL_LBL_W1HIGH, hi, c, "PWH", true, aLeft);  // v34.1: Previous Week High; v43 (Item 5): above the line now
   HLineLabel(HL_LBL_W1LOW,  lo, c, "PWL", true, aLeft);  // v34.1: Previous Week Low; v43 (Item 5): above the line now
}

// v34 (Item 5): Monthly H/L - new, same simple native-candle-read approach as Daily/Weekly, just
// off PERIOD_MN1 instead.
void UpdateMonthlyHL()
{
   if(!g_hlMonthlyOn) { RemoveMonthlyHL(); return; }
   if(iBars(Symbol(), PERIOD_MN1) < 2) { RemoveMonthlyHL(); return; }
   double hi = iHigh(Symbol(), PERIOD_MN1, 1);
   double lo = iLow (Symbol(), PERIOD_MN1, 1);
   if(hi<=0 || lo<=0) { RemoveMonthlyHL(); return; }
   bool aLeft = ToolsLabelAnchorLeft();  // v48 (Item 1) - ببین کامنت کامل بالای ToolsLabelAnchorLeft()
   color c = GetContrastColor(C'180,120,255', C'90,40,160');  // purple family - distinct from Daily/Weekly
   HLine(HL_LN_MN1HIGH, hi, c, 1, STYLE_DASH);
   HLine(HL_LN_MN1LOW,  lo, c, 1, STYLE_DASH);
   HLineLabel(HL_LBL_MN1HIGH, hi, c, "PMH", true, aLeft);  // v34.1: Previous Month High; v43 (Item 5): above the line now
   HLineLabel(HL_LBL_MN1LOW,  lo, c, "PML", true, aLeft);  // v34.1: Previous Month Low; v43 (Item 5): above the line now
}

// v34 (Item 2)/v34.4 (indicator side removed): the v33 single "Hide/Show All Drawings" toggle was
// split in base v34 into two independent toggles (chart objects + real attached indicators); the
// indicator toggle is now removed entirely per Mahmoud's decision - MT4 has no API to hide an
// attached indicator without deleting it (no counterpart to OBJPROP_TIMEFRAMES exists for
// indicators), so there was never a workable non-destructive "hide" for it. Only the objects
// toggle remains: hidden via OBJPROP_TIMEFRAMES=OBJ_NO_PERIODS (restores each object's EXACT
// original value on toggle-back).
void ToggleHideObjects()
{
   if(!g_objectsHidden)
   {
      int total = ObjectsTotal(0, -1, -1);
      ArrayResize(g_hiddenObjNames, total);
      ArrayResize(g_hiddenObjTF, total);
      g_hiddenObjCount = 0;
      for(int i=0;i<total;i++)
      {
         string nm = ObjectName(0, i, -1, -1);
         if(StringFind(nm, P) == 0) continue;  // skip the dashboard panel's own objects
         long tf = ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES);
         if(tf == OBJ_NO_PERIODS) continue;  // already hidden by the trader/another tool - leave it alone, don't "restore" it visible later
         g_hiddenObjNames[g_hiddenObjCount] = nm;
         g_hiddenObjTF[g_hiddenObjCount]    = tf;
         g_hiddenObjCount++;
         ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
      ArrayResize(g_hiddenObjNames, g_hiddenObjCount);
      ArrayResize(g_hiddenObjTF, g_hiddenObjCount);
      g_objectsHidden = true;
      SetStatus("Chart objects hidden ("+IntegerToString(g_hiddenObjCount)+")", C'150,160,180');
   }
   else
   {
      for(int i=0;i<g_hiddenObjCount;i++)
      {
         if(ObjectFind(0, g_hiddenObjNames[i]) < 0) continue;  // deleted while hidden - nothing to restore
         ObjectSetInteger(0, g_hiddenObjNames[i], OBJPROP_TIMEFRAMES, g_hiddenObjTF[i]);
      }
      g_hiddenObjCount = 0;
      ArrayResize(g_hiddenObjNames, 0);
      ArrayResize(g_hiddenObjTF, 0);
      g_objectsHidden = false;
      SetStatus("Chart objects restored", C'150,160,180');
   }
   ChartRedraw();
}

// v33 (Part 1, Tools item 4 - Break Even reference line): read-only preview of what the Basket
// Average BE price WOULD be right now, reusing GetBasketAveragePrice() (v14) - does NOT move any
// SL, does NOT touch ManualBE_BasketAverage()'s own line (BasketAvgLineName()) in any way.
void RemoveBERefLines()
{
   ObjectDelete(0, BERefLineName(true));
   ObjectDelete(0, BERefLineName(false));
}

void UpdateBERefLine()
{
   if(!g_beRefOn) { RemoveBERefLines(); return; }
   double avgBuy=0, avgSell=0;
   bool hasBuy  = GetBasketAveragePrice(true,  avgBuy);
   bool hasSell = GetBasketAveragePrice(false, avgSell);
   // v34 (Item 1): fixed clrAqua replaced with the shared contrast-aware helper - aqua family kept
   // as the "on dark background" anchor so the line's hue is unchanged on the default dark theme.
   color c = GetContrastColor(clrAqua, C'0,110,110');
   if(hasBuy)  HLine(BERefLineName(true),  avgBuy,  c, 1, STYLE_DOT);
   else        ObjectDelete(0, BERefLineName(true));
   if(hasSell) HLine(BERefLineName(false), avgSell, c, 1, STYLE_DOT);
   else        ObjectDelete(0, BERefLineName(false));
}

// v42 (Punch List, Part 1, Items 1+2+3): resets both Fibo tools back to their un-armed resting
// state - clears the arm/waiting flags, reverts both buttons to CLR_BTN_DEFAULT if present (safe
// no-op if minimized/on the other dashboard mode), and clears the deadline. Called on: a genuine
// placement completing (both chart points captured), the trader clicking an armed button again to
// cancel it, arming the OTHER tool (only one can be armed at a time), and the 5s auto-timeout in
// CheckButtonFlashExpiry() below.
void CancelFiboArm()
{
   if(ObjectFind(0,P+"BTN_FIBRMULT")>=0)  ObjectSetInteger(0,P+"BTN_FIBRMULT", OBJPROP_BGCOLOR, CLR_BTN_DEFAULT);
   if(ObjectFind(0,P+"BTN_FIBMEASURE")>=0) ObjectSetInteger(0,P+"BTN_FIBMEASURE",OBJPROP_BGCOLOR, CLR_BTN_DEFAULT);
   // v42 (Punch List follow-up, Mahmoud feedback): the live mouse-follow preview object (if the
   // trader was mid-drag, waiting on the 2nd click) never got a chance to be replaced by the real
   // instance - clean it up here too, on every cancellation path (manual cancel, re-arming the
   // other tool, or the 5s timeout), so it never gets stranded on the chart.
   ObjectDelete(0, FIBO_RMULT_PREVIEW);
   ObjectDelete(0, FIBO_MEASURE_PREVIEW);  // v79.1 (اصلاح): برگشت به آبجکت واحد OBJ_FIBO - دیگه چندزیرآبجکتی نیست
   ObjectDelete(0, LN_FIBOCURSOR);  // v42 follow-up: the cursor-following "click here" tag
   g_fiboArmedRR      = false;
   g_fiboArmedMeasure = false;
   g_fiboWaitingP2    = false;
   g_fiboArmDeadline  = 0;
}

// v42 (Punch List, Part 1, Items 1+2+3): arms toolId (1 = R/R, 2 = Measure Move) - turns that
// button the shared Tools-drawer active teal (CLR_TOOLS_ACTIVE, Item 4), resets the two-click
// point capture, and starts the 5s arm deadline. Always cancels any existing arm first, so arming
// one tool while the other is armed (or re-arming the same one) always starts clean.
void ArmFiboTool(int toolId)
{
   CancelFiboArm();
   if(toolId==1)
   {
      g_fiboArmedRR = true;
      if(ObjectFind(0,P+"BTN_FIBRMULT")>=0) ObjectSetInteger(0,P+"BTN_FIBRMULT",OBJPROP_BGCOLOR,CLR_TOOLS_ACTIVE);
      SetStatus("R/R: click base point on chart", GetFiboRRColor());  // v42 follow-up (Mahmoud feedback): matches the tool's actual line color
   }
   else
   {
      g_fiboArmedMeasure = true;
      if(ObjectFind(0,P+"BTN_FIBMEASURE")>=0) ObjectSetInteger(0,P+"BTN_FIBMEASURE",OBJPROP_BGCOLOR,CLR_TOOLS_ACTIVE);
      SetStatus("Measure Move: click base point on chart", GetFiboMeasureColor());  // v42 follow-up (Mahmoud feedback): matches the tool's actual line color
   }
   g_fiboArmDeadline = GetTickCount() + FIBO_ARM_MS;
   ChartRedraw();
}

// v26 (FEAT-018): آبجکت متنی شمارش معکوس کندل روی خود چارت (نه داخل پنل داشبورد) - عمداً با
// پیشوند "RM9_" (P) شروع نمی‌شه، دقیقاً به همون دلیل خط‌های TrailLineName/BELineName: اگه پیشوند
// P داشت، هر rebuild پنل (ObjectsDeleteAll(0,P) روی CHARTEVENT_CHART_CHANGE) پاکش می‌کرد و تا تیک
// بعدی از چارت محو می‌شد.
// R7: این #define توی جابه‌جایی اولیه‌ی این فاز جا افتاده بود - MetaEditor با خطای "undeclared
// identifier" پیداش کرد (بر خلاف تابع/global، #define صرفاً جایگزینی متنیه و ترتیب متنی واقعاً
// مهمه؛ forward-reference که برای تابع/global تأیید شده، برای #define کار نمی‌کنه) - این‌جا،
// درست قبل از اولین مصرفش، فیکس شد.
#define CANDLE_TIMER_OBJ "RM9LN_CANDLETIMER"

// اگه آبجکت شمارش معکوس روی چارت وجود داشته باشه، حذفش می‌کنه - هم از توگل OFF شدن صدا زده
// می‌شه (حذف فوری، بدون معطلی برای تیک بعدی) هم از خود UpdateCandleTimerChart() وقتی OFF باشه
void RemoveCandleTimerChart()
{
   if(ObjectFind(0,CANDLE_TIMER_OBJ)>=0) ObjectDelete(0,CANDLE_TIMER_OBJ);
}

// v26.3 (FEAT-018 fix): از OnTick() (ردیابی لحظه‌ای موقعیت) و OnTimer() (تضمین حداقل ۱ آپدیت در
// ثانیه روی نمادهای کم‌تیک) هر دو صدا زده می‌شه. فقط وقتی g_candleTimerOn روشنه چیزی رسم می‌کنه؛
// خاموش که باشه فقط RemoveCandleTimerChart() رو صدا می‌زنه (idempotent - اگه از قبل پاک شده باشه
// کاری نمی‌کنه). محاسبه: باقیمانده = (زمان شروع کندل جاری + طول تایم‌فریم به ثانیه) - زمان سرور
// جاری (تخمینی و نرم، از EstimateServerTime() - نه TimeCurrent() خام - v26.4). فرمت M:SS برای
// تایم‌فریم‌های کوچیک، H:MM:SS برای تایم‌فریم‌های بزرگ (H4/D1 و بالاتر).
// v95 (BUG-059 - تشخیصی موقت): اگه یه مرحله‌ی داخل توابع هر-تیک بیشتر از ۱۵۰ms طول بکشه، اسم مرحله
// رو لاگ می‌کنه (حداکثر ۱ خط در ثانیه) - برای پیدا کردن دقیق کدوم فراخوانی چارت قفل می‌شه.
// بعد از پیدا شدن علت حذف می‌شه.
bool  g_rmPerfLog = false;  // v98: لاگ‌های [RM-PERF] (تشخیصی BUG-059) پیش‌فرض خاموش - برای تشخیص دوباره true کن (PERF-001)
ulong g_slowStepLastPrintUs = 0;
void RM_SlowStep(string tag, ulong t0)
{
   ulong now = GetMicrosecondCount();
   if(!g_rmPerfLog) return;
   if(now - t0 < 150000) return;
   if(now - g_slowStepLastPrintUs < 1000000) return;
   g_slowStepLastPrintUs = now;
   Print("[RM-PERF] SLOWSTEP ", tag, " ", DoubleToStr((now - t0)/1000.0, 1), "ms");
}

// v95: کش برای مقادیری که هر تیک از چارت (UI thread) خونده می‌شدن ولی تقریباً عوض نمی‌شن
string   g_ctLastTxt     = "";
double   g_ctLastPrice   = 0;
datetime g_ctLastTime    = 0;
color    g_ctLastColor   = clrNONE;
color    g_ctBgColorCache = clrNONE;
uint     g_ctBgReadMs    = 0;
double   g_ctRangeCache  = 0;
uint     g_ctRangeReadMs = 0;

void UpdateCandleTimerChart(bool forceRedraw=false)
{
   // v79 (Item 4 - همیشه‌فعال): چک g_candleTimerOn حذف شد - این تابع دیگه همیشه رسم می‌کنه،
   // بدون وابستگی به هیچ توگلی.
   int periodSec = Period()*60;
   datetime barOpen = iTime(Symbol(), Period(), 0);
   datetime nowEst = EstimateServerTime();  // v26.4: نرم و لحظه‌به‌لحظه، نه کوانتیزه به تیک
   long remaining = (long)(barOpen + periodSec - nowEst);
   if(remaining < 0) remaining = 0;

   string txt;
   if(remaining >= 3600)
   {
      int h = (int)(remaining/3600);
      int m = (int)((remaining%3600)/60);
      int s = (int)(remaining%60);
      txt = StringFormat("%d:%02d:%02d", h, m, s);
   }
   else
   {
      int m = (int)(remaining/60);
      int s = (int)(remaining%60);
      txt = StringFormat("%d:%02d", m, s);
   }

   // v26.2 (FEAT-018 fix): جانمایی عوض شد - قبلاً روی های کندل جاری (ثابت، تا بسته‌شدن کندل
   // جابه‌جا نمی‌شد) بود؛ حالا دقیقاً روی خط Bid (قیمت زنده) نشسته و با هر تیک قیمت هم عمودی
   // (چون OBJPROP_PRICE=Bid) هم افقی (چون OBJPROP_TIME بر پایه‌ی nowEst) حرکت می‌کنه - دقیقاً مثل
   // نمونه‌ی مرجع. کمی جلوتر از لحظه‌ی فعلی (periodSec*2) قرار می‌گیره تا توی فضای خالی سمت راست
   // چارت بشینه، نه روی خودِ کندل در حال شکل‌گیری.
   // v26.3 (FEAT-018 fix): یه فاصله‌ی عمودی کوچیک بالای خود خط اضافه شد تا روش overlap نشه و
   // خواناتر باشه. فاصله بر اساس یه درصد ثابت از بازه‌ی قیمتی نمایش‌داده‌شده‌ی چارت (WindowPriceMax/
   // Min) حساب می‌شه، نه یه مقدار پیپ ثابت - چون این EA چندنمادیه (XAUUSD، فارکس، و غیره) و مقیاس
   // قیمتشون خیلی فرق داره؛ درصد از بازه‌ی زوم فعلی چارت روی هر نماد/زوم یه فاصله‌ی بصری تقریباً
   // یکسان می‌ده.
   // v95: بازه‌ی قیمتی دیده‌شده فقط برای یه فاصله‌ی بصری کوچیکه - هر تیک از چارت خونده نمی‌شه، حداکثر ۱ بار در ثانیه
   uint nowRdMs = GetTickCount();
   ulong tStep = GetMicrosecondCount();
   if(g_ctRangeCache <= 0 || forceRedraw || nowRdMs - g_ctRangeReadMs >= 1000)
   {
      double priceMax = WindowPriceMax(0);
      double priceMin = WindowPriceMin(0);
      g_ctRangeCache  = priceMax - priceMin;
      g_ctRangeReadMs = nowRdMs;
   }
   RM_SlowStep("CT:WindowPriceRange", tStep);
   double visibleRange = g_ctRangeCache;
   double yOffset = (visibleRange > 0) ? visibleRange * 0.015 : 0;
   double labelPrice = Bid + yOffset;

   // v26.6 (FEAT-018 fix): رنگ متن قبلاً ثابت clrWhite بود - روی پس‌زمینه‌ی روشن/سفید (که این پنل
   // پیش‌فرض برای تم تیره طراحی شده، ولی هر کسی می‌تونه رنگ چارتش رو عوض کنه) عملاً دیده نمی‌شد.
   // الان بر اساس رنگ واقعی پس‌زمینه‌ی چارت (CHART_COLOR_BACKGROUND) حساب می‌شه: luminance پس‌زمینه
   // رو می‌سنجه و بین سفید (روی پس‌زمینه‌ی تیره) یا مشکی (روی پس‌زمینه‌ی روشن) انتخاب می‌کنه - همیشه
   // کنتراست کافی داره، صرف‌نظر از تم چارت کاربر.
   // v95: رنگ پس‌زمینه‌ی چارت هم حداکثر هر ۲ ثانیه یه بار خونده می‌شه
   tStep = GetMicrosecondCount();
   if(g_ctBgColorCache == clrNONE || forceRedraw || nowRdMs - g_ctBgReadMs >= 2000)
   {
      g_ctBgColorCache = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
      g_ctBgReadMs = nowRdMs;
   }
   RM_SlowStep("CT:ChartGetInteger(BG)", tStep);
   color chartBg = g_ctBgColorCache;
   int bgR = (int)(chartBg & 0xFF);
   int bgG = (int)((chartBg >> 8) & 0xFF);
   int bgB = (int)((chartBg >> 16) & 0xFF);
   double bgLuminance = 0.299*bgR + 0.587*bgG + 0.114*bgB; // فرمول استاندارد luminance درک‌شده توسط چشم
   color txtColor = (bgLuminance > 140) ? clrBlack : clrWhite;

   // v95: اگه هیچ‌چیز (متن/قیمت/زمان/رنگ) عوض نشده، نه آبجکت دست می‌خوره نه ChartRedraw زده می‌شه
   // (قبلاً هر تیک ~۳۰ms ChartRedraw و - وقتی UI مشغول بود - تا ~۱۰۰۰ms قفل)
   if(!forceRedraw && txt == g_ctLastTxt && labelPrice == g_ctLastPrice && (nowEst + periodSec*2) == g_ctLastTime && txtColor == g_ctLastColor)
      return;
   g_ctLastTxt = txt; g_ctLastPrice = labelPrice; g_ctLastTime = nowEst + periodSec*2; g_ctLastColor = txtColor;

   tStep = GetMicrosecondCount();
   if(ObjectFind(0,CANDLE_TIMER_OBJ)<0) ObjectCreate(0,CANDLE_TIMER_OBJ,OBJ_TEXT,0,0,0);
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_TIME,  nowEst + periodSec*2);
   ObjectSetDouble (0,CANDLE_TIMER_OBJ,OBJPROP_PRICE, labelPrice);
   ObjectSetString (0,CANDLE_TIMER_OBJ,OBJPROP_TEXT,  txt);
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_COLOR, txtColor);
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_FONTSIZE, 12);
   ObjectSetString (0,CANDLE_TIMER_OBJ,OBJPROP_FONT,  "Arial Bold");
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_BACK, false);
   // v26.1 (FEAT-018 fix): لازمه چون این تابع از OnTimer() صدا زده می‌شه، مستقل از تیک واقعی -
   // بدون این، تغییر متن آبجکت تا تیک بعدی روی چارت دیده نمی‌شد و همون پرش/لگ قبلی ادامه پیدا می‌کرد
   // v26.5 (FEAT-018 fix): حالا شرطیه - فقط وقتی forceRedraw=true (از OnInit/OnTimer). از OnTick
   // صدا زده بشه (forceRedraw پیش‌فرض false)، چون خودِ MT4 با هر تیک واقعی چارت رو دوباره رسم
   // می‌کنه. مشکل: تکیه‌ی صرف روی رفرش ضمنی MT4 گاهی برای این آبجکتِ خاص (متنی، anchor به
   // قیمت/زمانِ دائم در حال تغییر) کافی نبود و ردّ محو نشده‌ی متن قبلی (ghosting) می‌موند - همون
   // پدیده‌ای که توی عکس دیده شد (دو عدد هم‌زمان).
   // v26.7 (FEAT-018 fix): راه‌حل میانه - throttle به‌جای همیشه/هیچ‌وقت. از OnTick با حداکثر هر
   // ۲۰۰ میلی‌ثانیه یه‌بار ChartRedraw() صریح می‌زنه (GetTickCount()، همون الگوی throttle که
   // خودِ پروژه برای rebuild پنل روی CHARTEVENT_CHART_CHANGE استفاده می‌کنه) - نه روی هر تیک
   // (که باعث لگ کلی چارت شده بود، v26.5)، نه هیچ‌وقت (که باعث ghosting شده بود، همین عکس).
   // v26.11 (FEAT-018 - reverted): یه فیکس امتحان شد که با تغییر متن، بدون توجه به throttle
   // فوراً ChartRedraw() بزنه - نتیجه بدتر شد (گزارش کاربر: "خراب‌تر شد")، پس به حالت throttle-
   // فقط v26.10 برگشت داده شد. جزئیات کامل و وضعیت باز این مشکل در changelog ثبت شده - برای
   // بررسی مجدد در آینده، نه یه فیکس دیگه در همین چرخه.
   bool doRedraw = forceRedraw;
   if(!doRedraw)
   {
      uint nowMs = GetTickCount();
      // v26.8: با uint، تفریق نامعادل به‌خودی‌خود در برابر overflow دوره‌ای GetTickCount() امنه
      // (حساب پیمانه‌ای استاندارد) - شرط جداگانه‌ی قبلی برای overflow دیگه لازم نیست.
      if(nowMs - g_ctLastRedrawMs >= 100)  // v26.10: حداکثر هر ۱۰۰ میلی‌ثانیه یه‌بار
         doRedraw = true;
   }
   RM_SlowStep("CT:ObjectSet", tStep);
   if(doRedraw)
   {
      tStep = GetMicrosecondCount();
      ChartRedraw();
      g_ctLastRedrawMs = GetTickCount();
      RM_SlowStep("CT:ChartRedraw", tStep);
   }
}

// v33 (Part 1, Tools item 6 - Fibonacci R-Multiple tool): creates a native OBJ_FIBO object with
// its retracement levels replaced by integer multiples (0R-5R) instead of standard Fibonacci
// ratios. Purely a manual drawing tool - no auto-anchor to Entry/SL/trade data of any kind, and
// left SELECTABLE so the trader can drag it exactly like MT4's native Fibonacci tool.
// v33.1 (Mahmoud feedback): two changes from the original v33 version -
// (1) Ray (extend lines to the right) was on by default (native OBJ_FIBO default) - now
//     explicitly turned off, same OBJPROP_RAY property already used for the MA OBJ_TREND
//     segments above.
// (2) Levels relabeled to match risk-multiple semantics instead of a plain "0R.."5R" count:
//     level 0 = SL (the anchor the trader drags to their stop price), level 1 = Entry (the other
//     anchor), and every level from 2 onward = Reward 1, 2, 3... (R1 sits exactly one more
//     SL-to-Entry distance beyond Entry, R2 two, etc. - the natural meaning of "R" once 0=SL and
//     1=Entry are fixed). Level count bumped 6->8 (SL, Entry, R1-R6) for a bit more headroom.
// v42 (Punch List, Item 1.1+1.2): no more fixed single object name / auto-anchor near the last 20
// bars - the anchor points (t1/p1, t2/p2) now come directly from the trader's own two chart
// clicks (captured by ArmFiboTool()/the OnChartEvent point-capture block), and objName is unique
// per placement (FIBO_RMULT_OBJ+"_"+seq from ArmFiboTool()'s caller) so multiple R/R instances can
// sit on the chart at once - no more overwriting/needing to delete the previous one first.
void CreateFiboRMultiple(string objName, datetime t1, double p1, datetime t2, double p2, bool isPreview=false)
{
   if(ObjectFind(0,objName)>=0) ObjectDelete(0,objName);  // defensive - names are unique per call, this should never actually hit
   ObjectCreate(0, objName, OBJ_FIBO, 0, t1, p1, t2, p2);

   // v79 (FEAT-034 - فیچر جدید): یک لول جدید صرفاً نمایشی اضافه شد - "2X"، دقیقاً نیمه‌راه فاصله‌ی
   // SL(0.0) تا Entry(1.0)، یعنی value=0.5 - همون استایل هندسی/رسمی بقیه‌ی لول‌های این ابزار
   // (خط پله‌ای Fibo، نه یه خط افقی مستقل جدا). از 8 لول (SL,Entry,R1..R6) به 9 لول رفت؛ چون
   // لول جدید بین SL و Entry می‌شینه (نه یه عدد صحیح ترتیبی جدید)، ساخت لیبل دیگه با فرمول
   // ساده‌ی index-based قبلی (i==0/i==1/else "R"+(i-1)) جواب نمی‌داد - به آرایه‌ی صریح مقدار/
   // لیبل (همون الگوی CreateFiboMeasureMove() پایین‌تر همین فایل) تبدیل شد. هیچ منطق محاسباتی/
   // اجرایی جدیدی اضافه نشده - صرفاً یه لول نمایشی دیگه‌ست، دقیقاً مثل R1..R6 موجود.
   int levelCount = 9;  // SL, 2X, Entry, R1..R6
   double levelVals[9] = {0.0, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0};
   string levelLbls[9] = {"SL", "2X", "Entry", "R1", "R2", "R3", "R4", "R5", "R6"};
   ObjectSetInteger(0, objName, OBJPROP_LEVELS, levelCount);
   // v34.4 (Item 4, overrides base v34's GetContrastColor() treatment for this tool specifically):
   // color now comes straight from the chart's own bullish-candle color instead of the dark/light
   // contrast-aware helper - read fresh every call so it tracks live if the trader changes it.
   // v42 (Punch List follow-up): now via GetFiboRRColor() (includes the Item 1.5 light-background
   // darkening) - shared with the cursor tag so both always match exactly.
   color lvlColor = GetFiboRRColor();
   for(int i=0;i<levelCount;i++)
   {
      ObjectSetDouble (0, objName, OBJPROP_LEVELVALUE, i, levelVals[i]);
      ObjectSetString (0, objName, OBJPROP_LEVELTEXT,  i, levelLbls[i]);
      ObjectSetInteger(0, objName, OBJPROP_LEVELCOLOR, i, lvlColor);
      ObjectSetInteger(0, objName, OBJPROP_LEVELSTYLE, i, STYLE_SOLID);  // v34 (Item 6): was STYLE_DOT - now solid
      ObjectSetInteger(0, objName, OBJPROP_LEVELWIDTH, i, 2);  // v34.1 (Mahmoud feedback): was 1, one degree thicker
   }
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lvlColor);
   // v33.1: MQL4 has a known quirk where OBJPROP_RAY_RIGHT alone isn't always honored on
   // programmatically-created OBJ_FIBO objects - setting both properties is the documented
   // workaround (both exist on Fibo; RAY_RIGHT is the one that actually matters here since Fibo
   // only ever extends right, never left).
   ObjectSetInteger(0, objName, OBJPROP_RAY, false);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, true);
   ChartRedraw();
   if(!isPreview) SetStatus("R/R placed - drag to fine-tune", GetFiboRRColor());  // v34.4 (Item 7): renamed from "Fib R-Multiple"; v42 follow-up: matches the tool's actual line color
}

// v34 (Item 4): Fibonacci Measure Move - second, independent OBJ_FIBO action button alongside the
// R-Multiple tool, same manual/draggable philosophy (no auto-anchor to trade data of any kind).
// Levels relabeled to plain measured-move semantics: level 0 = BASE, levels 1-2 = MEASURE 1,
// MEASURE 2. v34.1 (Mahmoud feedback): trimmed from the original 8-level headroom (matching
// R-Multiple) down to just 3 levels (BASE, MEASURE 1, MEASURE 2) - that's all this tool needs.
// v42 (Punch List, Item 1.1+1.2): same rework as CreateFiboRMultiple() above - explicit
// click-captured anchor points and a unique per-instance object name instead of a fixed single
// object auto-anchored near the last 20 bars.
// v49 (Punch List, Item 2): reworked from the 3-level BASE/MEASURE 1/MEASURE 2 set to a 5-level
// set built around the base range (BASE=0.0 .. MEASURE 1=1.0, the distance between the trader's
// two clicks):
//   -1.0  "MEASURE -1"  - retargeted projection marker: 1:1 mirror of the measured move on the
//                         OPPOSITE side of BASE (replaces the old level-2 "MEASURE 2", which was
//                         a 2x projection continuing in the SAME direction as MEASURE 1)
//   -0.3  "-30%"         - new reference line, 30% of the measured-move distance below BASE
//    0.0  "BASE"         - unchanged
//    1.0  "MEASURE 1"    - unchanged (the trader's second click - the move itself)
//    1.3  "+30%"          - new reference line, 30% of the measured-move distance above MEASURE 1
// The ±30% lines bracket the base range for judging how proportional a breakout move is; the
// ±1.0 markers give a symmetric 1:1 projection target in either direction instead of the old
// same-direction-only 2x target.
// v79.1 (اصلاح - Mahmoud): بازطراحی v79 اشتباه بود - اون توضیح (FEAT-030 با آبجکت‌های سفارشی/
// شید‌دار) در واقع مال یک ابزار کاملاً جدید در Executive Hub بود، نه این ابزار در پنل Utility.
// این ابزار به فرمت اصلی‌اش (native OBJ_FIBO، دقیقاً مثل قبل) برگشت - فقط لول‌ها/لیبل‌ها طبق
// تصویر مرجع Mahmoud به‌روز شدن. کدِ نسخه‌ی آبجکت-سفارشی (MMLine/MMLabel/MMRect/
// RemoveMeasureMoveTool) به Executive Hub منتقل شد (ExecutiveHub_v1.14.mq4 - دکمه‌ی Measure
// جدید در پنل Draw).
//
// نگاشت level→معنی (طبق تصویر مرجع؛ rangeSize = |p2-p1|):
//   -1.0  "measure"       - بیرون از high، هم‌فاصله‌ی کامل رِنج (بالاترین/پایین‌ترین خط، بسته به جهت)
//   -0.25 "range buffer"  - ۲۵٪ رِنج بیرون از high
//    0.0  "high"          - نقطه‌ی بیشینه‌ی قیمت بین دو کلیک (نه لزوماً کلیک اول)
//    0.5  "mid range"     - وسط دقیق high/low
//    1.0  "low"           - نقطه‌ی کمینه‌ی قیمت بین دو کلیک
//    1.25 "range buffer"  - ۲۵٪ رِنج بیرون از low
//    2.0  "MEASURE"       - بیرون از low، هم‌فاصله‌ی کامل رِنج
// نکته‌ی فنی: چون OBJ_FIBO لول ۰ رو همیشه دقیقاً روی anchor اول (t1/p1) و لول ۱ رو دقیقاً روی
// anchor دوم (t2/p2) می‌ذاره (نه بر اساس مقدار عددی)، قبل از ObjectCreate خودمون high/low رو با
// MathMax/MathMin تعیین می‌کنیم و anchor اول/دوم رو بر همون اساس مرتب می‌کنیم - این‌طوری صرف‌نظر
// از این‌که تریدر کدوم نقطه رو اول کلیک کرده، "high" همیشه واقعاً بالاتره و "low" همیشه واقعاً
// پایین‌تر.
// v106 (BUG-062): مجموعه‌ی لول‌ها دقیقاً لول‌های Fibonacci شخصی Mahmoud شد تا این ابزار لول‌های ابزار
// native او را عوض نکند. نگاشت جدید (۷ لول، به همین ترتیب):
//   0.0 "END" | 0.5 "50%" | 0.618 "61.8%" | 1.0 "START" | 1.236 "123.6%" | 1.618 "161.8%" | 2.0 "200%"
// لنگرها طبق ترتیب کلیک است (کلیک اول = سطح 0 = END، کلیک دوم = سطح 1 = START، مثل Fibo native؛ مرتب‌سازی high/low قبلی حذف شد، پس
// اکستنشن‌ها (1.236/1.618/2.0) همیشه در جهت سطح 0->1 ادامه می‌یابند. استایل: همه‌ی لول‌ها خط ممتد
// نازک (STYLE_SOLID، عرض ۱) تا با Weekly Map و خطوط High/Low (خط‌چین) اشتباه نشوند.
void CreateFiboMeasureMove(string objName, datetime t1, double p1, datetime t2, double p2, bool isPreview=false)
{
   if(ObjectFind(0,objName)>=0) ObjectDelete(0,objName);  // defensive - names are unique per call, this should never actually hit

   // v106 (BUG-062): لنگرها به همان ترتیب کلیک - OBJ_FIBO لول 0 را روی anchor اول و لول 1 را روی anchor دوم می‌گذارد
   ObjectCreate(0, objName, OBJ_FIBO, 0, t1, p1, t2, p2);

   int levelCount = 7;
   double levelVals[7] = {0.0, 0.5, 0.618, 1.0, 1.236, 1.618, 2.0};
   string levelLbls[7] = {"END", "50%", "61.8%", "START", "123.6%", "161.8%", "200%"};  // v106: تگ‌ها طبق Fibo native جابه‌جا: سطح 0 (کلیک اول)=END، سطح 1 (کلیک دوم)=START
   ObjectSetInteger(0, objName, OBJPROP_LEVELS, levelCount);
   color lvlColor = GetFiboMeasureColor();  // v49 (Punch List, Item 1): همون رنگ کنتراست‌دار قبلی
   // v79.2 (اصلاح - Mahmoud): همه‌ی ۷ لول یک استایل یکسان می‌گیرن - خط‌چین ریز (STYLE_DOT) به‌جای
   // ترکیب قبلی DASH/DASHDOTDOT؛ همون قرارداد رنگ/عرض دیگه، فقط استایل عوض شد.
   for(int i=0;i<levelCount;i++)
   {
      ObjectSetDouble (0, objName, OBJPROP_LEVELVALUE, i, levelVals[i]);
      ObjectSetString (0, objName, OBJPROP_LEVELTEXT,  i, levelLbls[i]);
      ObjectSetInteger(0, objName, OBJPROP_LEVELCOLOR, i, lvlColor);
      ObjectSetInteger(0, objName, OBJPROP_LEVELSTYLE, i, STYLE_SOLID);  // v106 (BUG-062): خط ممتد نازک (قبلاً STYLE_DOT)
      ObjectSetInteger(0, objName, OBJPROP_LEVELWIDTH, i, 1);
   }
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lvlColor);
   // Same RAY/RAY_RIGHT workaround as CreateFiboRMultiple() - no ray on either Fibo tool.
   ObjectSetInteger(0, objName, OBJPROP_RAY, false);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, true);
   ChartRedraw();
   if(!isPreview) SetStatus("Measure Move placed - drag to fine-tune", GetFiboMeasureColor());
}

//+------------------------------------------------------------------+
// v54 (فیچر جدید): Session Windows (SW / "KEY TIME") - در ابتدا سه باکس زمان+قیمت-anchor روی
// خود چارت بود (Tokyo/London/NewYork). FEAT-033 (v81) این رفتار را کاملاً حذف و با ۱۴ خط عمودی
// سراسری (OBJ_VLINE، خط‌چین، رنگ نزدیک بک‌گراند) جایگزین کرد - بدون توگل/حالت دوم، فقط همین یک
// رفتار جدید. دکمه‌ی toggle (BTN_SW در RM_Dashboard.mqh) و GlobalVariable پرسیستنس (GV_SW_ON)
// دست‌نخورده مانده‌اند - فقط چیزی که رسم می‌شود عوض شده.
//+------------------------------------------------------------------+
bool     g_swOn = false;  // Session Windows toggle - dashboard-driven, persisted via GlobalVariable (GV_SW_ON)
string   GV_SW_ON = "RM_SWOn_" + Symbol();
#define  SW_HISTORY_DAYS 30   // ~1 month of history lines for manual backtesting on the chart (per spec, دست‌نخورده از v54)
datetime g_swCullTime = 0;  // v95: مرز چپ برای ساخت خطوط Key Time (۰ = بدون محدودیت)
#define  SW_BOX_PREFIX   "RM9RC_SW_"   // اسم پیشوند از v54 مونده (فقط خط‌های عمودی می‌سازه، نه باکس)
#define  SW_LBL_PREFIX   "RM9LB_SW_"
// عمداً با پیشوند P (پنل) شروع نمی‌شن - دقیقاً همون دلیل CANDLE_TIMER_OBJ بالاتر همین فایل: اگه
// پیشوند P داشتن، هر rebuild پنل پاکشون می‌کرد.
string   g_swBoxNames[];   // اسم قدیمی (v54) مونده - حالا اسم خط‌های عمودی (OBJ_VLINE) رو نگه می‌داره
string   g_swLblNames[];
int      g_swObjCount = 0;

// FEAT-033 (v81) - جدول ثابت ۱۴ خط KEY TIME، همه به‌وقت نیویورک (طبق سند تسک). dayOffset=1 یعنی
// این خط به روز تقویمی نیویورکِ *قبل* از daysAgo جاری تعلق داره (مثلاً سشن عصر که از شب قبل
// شروع می‌شه) - با ST_GetNYCalendarDate هم‌معنی (daysAgo بزرگ‌تر = یک روز عقب‌تر)، پس این‌جا فقط
// با +1 به daysAgo پاس داده می‌شه، بدون منطق تاریخ جدا.
#define KEYTIME_LINE_COUNT 16  // v97: ۱۴ -> ۱۶ (دو خط فرعی جدید: ۱۲:۰۰ و ۰۵:۰۰ نیویورک = ۱۹:۰۰ و ۱۲:۰۰ وقت بروکر)
string KeyTime_Id(int i)
{
   string ids[KEYTIME_LINE_COUNT] = {"M1","M2","M3","M4","M5","M6","M7","M8","S1","S2","S3","S4","S5","S6","S7","S8"};
   return ids[i];
}
void KeyTime_GetLine(int i, int &h, int &m, bool &isMain, int &dayOffset)
{
   // اصلی (۸ تا، i=0..7) - جدول تسک، ستون نیویورک
   int mainH[8] = {17,20,21, 2, 3, 9,11,13};
   int mainM[8] = { 0, 0, 0, 0, 0,30, 0, 0};
   int mainOff[8] = {1,1,1,0,0,0,0,0};   // ۱۷:۰۰/۲۰:۰۰/۲۱:۰۰ = روز قبل (جدول تسک)
   // فرعی (۸ تا، i=8..15)
   // v97 (درخواست Mahmoud): دو خط فرعی جدید - ۱۹:۰۰ و ۱۲:۰۰ به‌وقت بروکر. بروکر همیشه = نیویورک + ۷
   // ساعت (سرور با DST آمریکا جابه‌جا می‌شه، ۱۷:۰۰ نیویورک = ۰۰:۰۰ بروکر)، پس: ۱۹:۰۰ بروکر = ۱۲:۰۰
   // نیویورک، ۱۲:۰۰ بروکر = ۰۵:۰۰ نیویورک. (لیبل زیر خط همیشه به‌وقت بروکره، پس همین ۱۹:۰۰/۱۲:۰۰ دیده می‌شه.)
   int subH[8] = { 0, 1, 6, 8,14,16,12, 5};
   int subM[8] = { 0, 0, 0,30, 0, 0, 0, 0};

   if(i<8)
   {
      h=mainH[i]; m=mainM[i]; isMain=true; dayOffset=mainOff[i];
   }
   else
   {
      int j=i-8;
      h=subH[j]; m=subM[j]; isMain=false; dayOffset=0;
   }
}

// رنگ خودکار نزدیک بک‌گراند چارت - هرچه blendPct کمتر، به بک‌گراند نزدیک‌تر (به‌سختی دیده می‌شه).
// خطوط اصلی درصد بیشتر (پررنگ‌تر) از فرعی می‌گیرن - طبق تسک "یک پله واضح‌تر".
color GetKeyTimeLineColor(bool isMain)
{
   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   int bgR = (int)(chartBg & 0xFF);
   int bgG = (int)((chartBg >> 8) & 0xFF);
   int bgB = (int)((chartBg >> 16) & 0xFF);
   double bgLuminance = 0.299*bgR + 0.587*bgG + 0.114*bgB;
   int refR, refG, refB;
   if(bgLuminance > 140) { refR=0;   refG=0;   refB=0;   } // بک‌گراند روشن -> به سمت سیاه بلند شو
   else                  { refR=255; refG=255; refB=255; } // بک‌گراند تیره -> به سمت سفید بلند شو

   // فیدبک Mahmoud (بعد از v81): کنتراست قبلی (26/11) هنوز خیلی محسوس بود - فضای بصری رو آلوده
   // می‌کرد. حالا خیلی نزدیک‌تر به بک‌گراند - به‌سختی دیده می‌شه، صرفاً یه مرجع کم‌رنگ.
   // فیدبک Mahmoud (v83): برعکس - حالا خیلی کم‌رنگ و به‌سختی دیدنی شده بودن. هر دو نوع خط دقیقاً
   // ۵ واحد درصد بیشتر از بک‌گراند فاصله می‌گیرن (12->17، 5->10) - فقط همین دو عدد؛ بقیه‌ی منطق
   // (تشخیص روشن/تیره بودن بک‌گراند، جهت بلندشدن رنگ) دست‌نخورده.
   // v106 (FEAT-047): دو عدد ثابت 17/10 با ورودی InpKeyTimeIntensity جایگزین شد (پیش‌فرض 30). خطوط اصلی
   // مستقیماً همان درصد؛ فرعی با همان نسبت قبلی 10:17 (در 30 -> 18، حداقل 8). عدد ساعت همان رنگ خط را
   // دارد (BuildOneKeyTimeLine)، پس بالا بردن شدت خوانایی عدد را هم بالا می‌برد. clamp بی‌صدا؛ رنگ فقط
   // موقع (باز)ساخته‌شدن خطوط خوانده می‌شود - هیچ تایمر/پولینگ جدیدی اضافه نشد.
   int kp = InpKeyTimeIntensity;
   if(kp < KEYTIME_INTENSITY_MIN) kp = KEYTIME_INTENSITY_MIN;
   if(kp > KEYTIME_INTENSITY_MAX) kp = KEYTIME_INTENSITY_MAX;
   int blendPct = kp;
   if(!isMain)
   {
      blendPct = (int)MathRound(kp * 10.0 / 17.0);
      if(blendPct < 1) blendPct = 1;  // کف ۸ برداشته شد (حداقل ورودی ۵): با کف ۸ فرعی از اصلی پررنگ‌تر می‌شد
   }
   int r = bgR + (int)((refR-bgR)*blendPct/100.0);
   int g = bgG + (int)((refG-bgG)*blendPct/100.0);
   int b = bgB + (int)((refB-bgB)*blendPct/100.0);
   return (color)(r | (g<<8) | (b<<16));
}

// v78 (بازنویسیِ Session Tools): منطقِ DST/NY->server + کشِ آفست به ماژولِ مشترکِ
// RM_SessionTime.mqh منتقل شد. IsUSDST_UTC/GetNYCalendarDate + کشِ static اینجا حذف و
// با ST_* جایگزین شدند (همان منبعی که Hub و Session Level هم استفاده می‌کنند). آفستِ سرور
// حالا پایدار است (کالیبره از تیکِ تازه + ذخیره در GlobalVariable)، پس سوییچِ تایم‌فریم
// (که این ابزارها را بازرسم می‌کند) و سکوتِ تیک/آخرِ هفته دیگر باکس را جابه‌جا نمی‌کنند، و
// زمان کاملاً تقویمی/قطعی است (immutable برای روزهای بسته). امضای این wrapper هم‌شکلِ قبلی
// نگه داشته شد تا فراخوان‌ها (BuildOneSessionBox) دست‌نخورده بمانند.
void ComputeSessionWindowServerTime(int daysAgo, int nyStartH, int nyStartM, int nyEndH, int nyEndM, datetime &outStart, datetime &outEnd)
{
   ST_ComputeSessionByDaysAgo(daysAgo, nyStartH, nyStartM, nyEndH, nyEndM, outStart, outEnd);
}

// v54.1: height cut to one-third. v54.2: bottom anchor bumped 2%->4% of visible price range (still
// not enough - see v54.3). v54.3 (فیکس - گزارش Mahmoud): مشکل ریشه‌ای این بود که لنگر از "پایین‌ترین
// قیمت دیده‌شده در کل بازه‌" حساب می‌شد - وقتی خودِ قیمت به همون ناحیه‌ی پایینی بازه‌ی دیده‌شده
// می‌رسید (که دقیقاً یعنی کندل‌های واقعی همون‌جا نشستن)، درصد از پایین باکس رو می‌برد داخل شکم
// همون کندل‌ها. راه‌حل واقعی: دیگه از درصد قیمت استفاده نمی‌شه - مستقیماً یه بافر پیکسلی ثابت از
// پایین کل ناحیه‌ی چارت (نزدیک نوار زمان) گرفته می‌شه، از طریق ChartXYToTimePrice() (تبدیل
// pixel -> price، همون تابعی که HLineLabel() هم برای تبدیل pixel -> time استفاده می‌کنه) - این
// بافر کاملاً به پیکسل صفحه‌ست، نه به بازه‌ی قیمت، پس مستقل از این‌که خود قیمت الان کجای بازه‌ی
// دیده‌شده باشه همیشه همون‌جا (بالای نوار زمان) می‌مونه. اگه تبدیل به هر دلیلی شکست بخوره (مثلاً
// یه ساب‌ویندوی غیرمنتظره)، به همون روش درصدی قبلی fallback می‌کنه.
void GetSessionWindowPriceRange(double &priceTop, double &priceBot)
{
   int chartH      = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int xPix        = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2;  // تبدیل pixel->price در MT4 مستقل از X است، فقط باید داخل بازه‌ی معتبر چارت باشه
   int marginBotPx = 14;  // فاصله‌ی پیکسلی پایین باکس از پایین کل ناحیه‌ی چارت - v54.4: از 26 به 14 (نزدیک‌تر به نوار زمان)
   int boxHPx      = 6;   // ارتفاع باکس به پیکسل - v54.4: از 9 به 6 (یک‌سوم دیگه کم شد)

   int subWinBot = -1, subWinTop = -1;
   datetime tDummy = 0;
   bool okBot = ChartXYToTimePrice(0, xPix, chartH-marginBotPx,        subWinBot, tDummy, priceBot);
   bool okTop = ChartXYToTimePrice(0, xPix, chartH-marginBotPx-boxHPx, subWinTop, tDummy, priceTop);

   if(!okBot || !okTop || subWinBot!=0 || subWinTop!=0)  // fallback ایمن - شکست تبدیل، یا نقطه داخل یه ساب‌ویندوی دیگه (نه چارت اصلی) افتاده
   {
      double pMax = WindowPriceMax(0);
      double pMin = WindowPriceMin(0);
      double range = pMax - pMin;
      if(range <= 0) { priceTop = Bid; priceBot = Bid; return; }
      priceBot = pMin + range*0.04;
      priceTop = pMin + range*0.05;
   }
}

// BUG-046 fix: تضمین می‌کنه چارت یه فضای خالی (Chart Shift) کافی سمت راست داشته باشه تا آبجکت‌های
// زمان‌محورِ فراتر از آخرین کندل واقعی (Time[0]) درست تخصیص/رندر بشن - بدون این، MT4 می‌تونه این
// آبجکت‌ها رو کج/نامرئی نگه داره تا وقتی کاربر دستی اسکرول کنه. اگه زمان هدف از Time[0] جلوتر
// نباشه، هیچ تغییری اعمال نمی‌شه (بدون side effect روی باکس‌های کاملاً تاریخی).
void SessionLevel_EnsureChartShift(datetime latestObjTime)
{
   if(ArraySize(Time) <= 0) return;
   if(latestObjTime <= Time[0]) return;
   if(ChartGetInteger(0, CHART_SHIFT) == 0)
      ChartSetInteger(0, CHART_SHIFT, true);
   double shiftSize = ChartGetDouble(0, CHART_SHIFT_SIZE);  // فیکس کامپایل: CHART_SHIFT_SIZE از نوع double است (درصد)، نه integer - برخلاف CHART_SHIFT خودش
   if(shiftSize < 20)
      ChartSetDouble(0, CHART_SHIFT_SIZE, 20);  // درصد از عرض چارت - فضای کافی برای باکس‌های فردا/امروزِ هنوز-شروع‌نشده
}

// v105: خبرهای USD داخل KEY TIME - قبل از RemoveSessionWindows/BuildSessionWindows تا فراخوانی‌هایشان بدون پروتوتایپ باشد
#include "RM_News.mqh"

void RemoveSessionWindows()
{
   RM_NewsRemove();  // v105
   for(int i=0; i<g_swObjCount; i++)
   {
      ObjectDelete(0, g_swBoxNames[i]);
      ObjectDelete(0, g_swLblNames[i]);
   }
   g_swObjCount = 0;
   ArrayResize(g_swBoxNames, 0);
   ArrayResize(g_swLblNames, 0);
}

// FEAT-033 (v81): یه خط عمودی سراسری (OBJ_VLINE، خط‌چین) + لیبل ساعتش زیرش می‌سازه (یا اگه از
// قبل وجود داره، آپدیت می‌کنه) و به آرایه‌ی ردیابی اضافه می‌کنه. ذخیره‌سازی داخلی بر پایه‌ی وقت
// نیویورک (h,m) - از همون ماژول مشترک RM_SessionTime.mqh (ST_ComputeSessionByDaysAgo) برای
// تبدیل به وقت سرور استفاده می‌شه؛ چون این تابع یه بازه (start,end) می‌خواد نه یه لحظه‌ی تکی، همون
// h,m برای هر دو پاس داده می‌شه و فقط outStart استفاده می‌شه (outEnd به‌خاطر منطق «رد از نیمه‌شب»
// همون تابع ممکنه یه روز جلوتر بره - این‌جا بی‌ربطه، نادیده گرفته می‌شه).
// لیبل نمایشی (برچسب زیر خط) همیشه به‌وقت بروکر است - همون outStart (که از قبل به وقت سرور/
// بروکر تبدیل شده) مستقیم با TimeHour/TimeMinute خونده می‌شه؛ پس اگه DST نیویورک عوض بشه، دفعه‌ی
// بعد که این تابع صدا زده بشه (day-reset/toggle/OnInit - همون‌جاهایی که BuildSessionWindows از
// قبل صدا زده می‌شه) لیبل خودش با مقدار درست بازسازی می‌شه - بدون دیسپچ جدید.
void BuildOneKeyTimeLine(int daysAgo, int lineIdx, int nyH, int nyM, bool isMain, color c)
{
   datetime t1, t2dummy;
   ST_ComputeSessionByDaysAgo(daysAgo, nyH, nyM, nyH, nyM, t1, t2dummy);
   // v95 (BUG-059): خطوطِ کاملاً بیرون از (چپِ) ناحیه‌ی دیده‌شده‌ی چارت ساخته نمی‌شن - قبلاً همیشه
   // ~۴۵۰ خط + ~۴۵۰ لیبل (۳۲ روز × ۱۴) ساخته می‌شد و هر ChartRedraw رو تا ~۱ ثانیه کند می‌کرد.
   // اسکرول به عقب CHARTEVENT_CHART_CHANGE می‌ده که همین تابع رو دوباره صدا می‌زنه، پس خطوط قدیمی‌تر
   // موقع اسکرول کشیده می‌شن.
   if(g_swCullTime > 0 && t1 < g_swCullTime) return;
   // BUG-046 fix (v59) - همون فضای رزرو سمت راست چارت، برای خط‌های امروز/فردا که هنوز کندل واقعی ندارن
   SessionLevel_EnsureChartShift(t1);

   string id      = KeyTime_Id(lineIdx);
   string lineName = SW_BOX_PREFIX + id + "_" + IntegerToString(daysAgo);
   string lblName  = SW_LBL_PREFIX + id + "_" + IntegerToString(daysAgo);

   double priceTop, priceBot;
   GetSessionWindowPriceRange(priceTop, priceBot);  // priceTop همون لنگر نزدیک-پایین‌چارت قبلی (v54) - برای لیبل زیر خط استفاده می‌شه

   if(ObjectFind(0,lineName)<0) ObjectCreate(0,lineName,OBJ_VLINE,0,t1,0);
   ObjectSetInteger(0,lineName,OBJPROP_TIME,  t1);
   ObjectSetInteger(0,lineName,OBJPROP_COLOR, c);
   ObjectSetInteger(0,lineName,OBJPROP_STYLE, STYLE_DASH);
   // فیکس (فیدبک Mahmoud - خط اصلی solid دیده می‌شد): محدودیت شناخته‌شده‌ی MT4 - اگه WIDTH بیشتر
   // از ۱ باشه، استایل خط‌چین (STYLE_DASH) کلاً نادیده گرفته می‌شه و خط solid رسم می‌شه، فارغ از
   // این‌که OBJPROP_STYLE چی باشه. پس هر ۱۴ خط باید عرض ۱ بمونن تا خط‌چین واقعاً کار کنه؛ تمایز
   // اصلی/فرعی کامل روی رنگ (GetKeyTimeLineColor بالا) می‌مونه، نه عرض.
   ObjectSetInteger(0,lineName,OBJPROP_WIDTH, 1);
   ObjectSetInteger(0,lineName,OBJPROP_BACK,  true);
   ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,lineName,OBJPROP_RAY,   false);

   // لیبل ساعت (به‌وقت بروکر - t1 از قبل به وقت سرور تبدیل شده) - زیر خط، نزدیک پایین چارت
   string hourLbl = StringFormat("%02d:%02d", TimeHour(t1), TimeMinute(t1));
   if(ObjectFind(0,lblName)<0) ObjectCreate(0,lblName,OBJ_TEXT,0,t1,priceTop);
   ObjectSetInteger(0,lblName,OBJPROP_TIME,  t1);
   ObjectSetDouble (0,lblName,OBJPROP_PRICE, priceTop);
   ObjectSetString (0,lblName,OBJPROP_TEXT,  hourLbl);
   ObjectSetInteger(0,lblName,OBJPROP_COLOR, c);
   ObjectSetInteger(0,lblName,OBJPROP_FONTSIZE, isMain ? 7 : 6);
   ObjectSetString (0,lblName,OBJPROP_FONT,  "Arial");
   ObjectSetInteger(0,lblName,OBJPROP_ANCHOR, ANCHOR_LOWER);
   ObjectSetInteger(0,lblName,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,lblName,OBJPROP_BACK,   false);

   ArrayResize(g_swBoxNames, g_swObjCount+1);
   ArrayResize(g_swLblNames, g_swObjCount+1);
   g_swBoxNames[g_swObjCount] = lineName;
   g_swLblNames[g_swObjCount] = lblName;
   g_swObjCount++;
}

// (دوباره‌)می‌سازه هر ۱۴ خط/لیبل - امروز به‌علاوه‌ی ~SW_HISTORY_DAYS روز تاریخچه (دست‌نخورده از
// v54 - همون حلقه‌ی daysAgo=-1..SW_HISTORY_DAYS و همون نقاط صدازده‌شدن: توگل روشن شدن، OnInit()
// اگه از ری‌استارت قبلی روشن بوده، و یه‌بار در هر day-reset).
void BuildSessionWindows()
{
   RemoveSessionWindows();
   if(!g_swOn) return;

   // v95 (BUG-059): مرز چپِ ناحیه‌ی دیده‌شده (یک روز حاشیه) - خطوط قدیمی‌تر از اون ساخته نمی‌شن
   g_swCullTime = 0;
   int firstVis = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   if(firstVis >= 0 && firstVis < Bars)
   {
      datetime leftT = iTime(Symbol(), Period(), firstVis);
      if(leftT > 0) g_swCullTime = leftT - 86400;
   }

   for(int daysAgo=-1; daysAgo<=SW_HISTORY_DAYS; daysAgo++)
   {
      for(int i=0; i<KEYTIME_LINE_COUNT; i++)
      {
         int h, m, dayOffset; bool isMain;
         KeyTime_GetLine(i, h, m, isMain, dayOffset);
         color c = GetKeyTimeLineColor(isMain);
         // dayOffset=1 -> این خط به روز تقویمی نیویورکِ قبل از daysAgo جاری تعلق داره (سشن عصر که
         // از شب قبل شروع می‌شه) - ST_GetNYCalendarDate(daysAgo+1,...) دقیقاً همون یک روز عقب‌تره.
         BuildOneKeyTimeLine(daysAgo+dayOffset, i, h, m, isMain, c);
      }
   }
   RM_NewsBuild();  // v105: خبرهای USD امروز (فقط از حافظه)
   ChartRedraw();
}

// هر تیک صدا زده می‌شه - فقط موقعیت عمودی (PRICE لیبل‌ها) رو با بازه‌ی قیمت دیده‌شده‌ی لحظه‌ای
// هماهنگ می‌کنه (زوم/اسکرول چارت)، بدون لمس زمان - خیلی ارزون. خودِ خط عمودی (OBJ_VLINE) قیمت
// نداره (سراسری/تمام‌ارتفاع)، پس فقط لیبل‌ها نیاز به sync دارن.
// v95 (BUG-059): این تابع هر تیک صدا زده می‌شد و هر بار چند فراخوانی هم‌گام با UI چارت
// (ChartGetInteger/ChartXYToTimePrice) می‌زد - ولی موقعیت لیبل‌ها فقط با زوم/اسکرول/تغییر اندازه‌ی
// چارت عوض می‌شه (که CHARTEVENT_CHART_CHANGE هم همون لحظه sync می‌کنه). الان از تیک حداکثر هر ۳
// ثانیه یه‌بار (شبکه‌ی ایمنی)، و بدون throttle از CHART_CHANGE با force=true. فقط اگه priceTop واقعاً
// عوض شده باشه آبجکت‌ها دست می‌خورن.
uint   g_swVertLastMs  = 0;
double g_swVertLastTop = 0;
void UpdateSessionWindowsVertical(bool force=false)
{
   if(!g_swOn || g_swObjCount<=0) return;
   uint nowMs = GetTickCount();
   if(!force && nowMs - g_swVertLastMs < 3000) return;
   g_swVertLastMs = nowMs;
   // v95: اگه کاربر بیشتر از مرز فعلی به عقب اسکرول کرده (و رویداد CHART_CHANGE به‌خاطر throttle ۱ثانیه‌ای
   // گم شده)، خطوط قدیمی‌تر رو دوباره بساز
   if(g_swCullTime > 0)
   {
      int fv = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
      if(fv >= 0 && fv < Bars)
      {
         datetime lt = iTime(Symbol(), Period(), fv);
         if(lt > 0 && lt - 86400 < g_swCullTime) { BuildSessionWindows(); return; }
      }
   }
   RM_NewsUpdateVertical();  // v105
   ulong tStep = GetMicrosecondCount();
   double priceTop, priceBot;
   GetSessionWindowPriceRange(priceTop, priceBot);
   RM_SlowStep("SW:GetPriceRange", tStep);
   if(!force && priceTop == g_swVertLastTop) return;
   g_swVertLastTop = priceTop;
   tStep = GetMicrosecondCount();
   for(int i=0; i<g_swObjCount; i++)
   {
      if(ObjectFind(0,g_swLblNames[i])>=0)
         ObjectSetDouble(0,g_swLblNames[i],OBJPROP_PRICE, priceTop);
   }
   RM_SlowStep("SW:ObjectSet", tStep);
}

void SaveSessionWindowsState()
{
   GlobalVariableSet(GV_SW_ON, g_swOn ? 1.0 : 0.0);
}

void LoadSessionWindowsState()
{
   if(GlobalVariableCheck(GV_SW_ON))
      g_swOn = (GlobalVariableGet(GV_SW_ON) != 0.0);
}

//+------------------------------------------------------------------+
//| v57 (فیچر جدید مستقل): Session Level                               |
//+------------------------------------------------------------------+
// هدف: مرزهای سه سشن (Tokyo/London/New York) روی چارت - همون سبک بصری باکس‌های باریک بالای
// SESSIONS (بالا، v54) که فقط شروع/پایان هر سشن رو نشون می‌ده (بدون خط کف/سقف قیمتی) - از
// GetSessionWindowPriceRange()/GetFiboRRColor() موجود (کاملاً عمومی، ربطی به منطق سشن ندارن)
// دوباره استفاده می‌شه. اما طبق تسک v57، خودِ منطق مرزبندی زمانی (DST/NY->UTC->سرور) از صفر
// بازنویسی شده - v54/SESSIONS منبع معتبری براش نیست، چون BUG-046 نشون داد MT4 آبجکت‌های
// زمان‌محور فراتر از آخرین کندل واقعی (زمانی که هنوز کندلی براش نساخته) رو بدون یه فضای رزرو
// شده‌ی صریح در سمت راست چارت (Chart Shift) درست تخصیص/رندر نمی‌کنه - باکس‌های "امروز" که هنوز
// شروع نشدن (یا باکس فردا، برای رسیدگی به لبه‌ی نیمه‌شب) دقیقاً همین حالتن. راه‌حل زیر
// (SessionLevel_EnsureChartShift) این مشکل رو مستقیماً با تضمین یه فضای خالی کافی سمت راست چارت
// دور می‌زنه، هر بار قبل از ساخت/آپدیت هر باکسی که زمانش از آخرین کندل واقعی جلوتره.
//
// این منطق (توابع SessionLevel_*) طبق تسک عمداً generic/reusable نگه داشته شده - قراره در v58
// (Session-entry tagging) هم مستقیماً صدا زده بشه، پس این‌جا (داخل خود EA، نه یه indicator جدا)
// می‌مونه.
bool     g_sessLvlOn = false;  // Session Level toggle - dashboard-driven, persisted via GlobalVariable (GV_SESSLVL_ON)
string   GV_SESSLVL_ON = "RM_SessLvlOn_" + Symbol();
#define  SESSLVL_HISTORY_DAYS 30   // ~1 month تاریخچه برای بک‌تست دستی روی چارت - هم‌راستا با SW_HISTORY_DAYS بالا
#define  SESSLVL_BOX_PREFIX   "RM9RC_SL_"
#define  SESSLVL_LBL_PREFIX   "RM9LB_SL_"
// عمداً با پیشوند P (پنل) شروع نمی‌شن - همون دلیل CANDLE_TIMER_OBJ/SW_BOX_PREFIX بالاتر همین
// فایل: اگه پیشوند P داشتن، هر rebuild پنل پاکشون می‌کرد.
string   g_slBoxNames[];
string   g_slLblNames[];
int      g_slLane[];        // v57.2: موازی با آرایه‌های بالا - کدوم لِین عمودی (0/1/2) این باکس رو نشون می‌ده
int      g_slObjCount = 0;

// v78 (بازنویسیِ Session Tools): SessionLevel_IsUSDST/SessionLevel_GetNYDate + کشِ static
// حذف و به ماژولِ مشترکِ RM_SessionTime.mqh منتقل شدند (همان یک منبع که SW و Hub هم استفاده
// می‌کنند - هر سه DST قبلاً منطقاً یکسان بودند، پس ادغام بی‌خطر است). آفستِ سرور حالا پایدار
// است، و چون Session Level سشنِ عبورکننده از نیمه‌شب (Tokyo 20:00->05:00) دارد، فیکسِ
// عبور-از-نیمه‌شبِ ماژول (end<=start -> +86400) آن را درست هندل می‌کند. امضای این wrapper
// هم‌شکلِ قبلی نگه داشته شد تا فراخوان‌ها دست‌نخورده بمانند.
void SessionLevel_ComputeServerTime(int daysAgo, int nyStartH, int nyStartM, int nyEndH, int nyEndM, datetime &outStart, datetime &outEnd)
{
   ST_ComputeSessionByDaysAgo(daysAgo, nyStartH, nyStartM, nyEndH, nyEndM, outStart, outEnd);
}

// v58 (Session-entry tagging): مشخص می‌کنه لحظه‌ی ورود یه معامله (زمان سرور - مثلاً
// OrderOpenTime()) توی کدوم سشن واقعی (Tokyo/London/NewYork) بوده - برای تحلیل
// win-rate-per-session در فاز C/D. فقط از SessionLevel_IsUSDST بالا (بدون تغییر) استفاده
// می‌کنه؛ چیزی از ظاهر/منطق بصری Session Level (باکس‌های چارت، v57) اینجا لمس نمی‌شه - این فقط
// یه تابع محاسباتی جدا برای تگ‌گذاریه.
//
// طبق تسک، سه قانون:
//   ۱) همپوشانی: وقتی چند سشن هم‌زمان فعالن، سشنی که دیرتر (جدیدتر) شروع شده ملاک قرار می‌گیره -
//      نه سشنی که زودتر شروع شده.
//   ۲) شکاف: با بازه‌های نهایی v57 (وقت نیویورک: Tokyo 20:00->05:00، London 03:00->12:00،
//      NewYork 09:00->18:00)، یه شکاف ۲ساعته‌ی بدون‌سشن بین بسته‌شدن NY و باز شدن Tokyo وجود
//      داره (18:00->20:00 وقت نیویورک) -> تگ "OUT OF TRADING SESSION".
//   ۳) این صرفاً یه تگ داده‌ایه - بدون هیچ هشدار/رنگ/مسدودکردنی روی داشبورد.
//
// پیاده‌سازی: زمان سرور -> UTC -> وقت نیویورک (دقیقه‌ی روز)، بعد عضویت در هر سه بازه (Tokyo با
// رد از نیمه‌شب) چک می‌شه. برای قانون همپوشانی، "چند دقیقه از شروع اسمی هر سشنِ فعال گذشته"
// حساب می‌شه - کمترین فاصله = دیرتر (جدیدتر) شروع شده = همون سشنی که باید برگرده.
string SessionLevel_TagForTime(datetime serverTime)
{
   // v78: آفستِ خامِ TimeCurrent()-TimeGMT() (که در سکوتِ تیک drift می‌کرد) با آفستِ
   // پایدارِ ماژول جایگزین شد؛ SessionLevel_IsUSDST هم -> ST_IsUSDST.
   int serverOffsetSec = ST_ServerOffsetSec();
   datetime utcTime = serverTime - serverOffsetSec;
   bool dst = ST_IsUSDST(utcTime);
   int nyOffsetSec = dst ? (-4*3600) : (-5*3600);
   datetime nyTime = utcTime + nyOffsetSec;

   int nyMinutes = TimeHour(nyTime)*60 + TimeMinute(nyTime);

   // بازه‌های نهایی v57 (وقت نیویورک، به دقیقه از نیمه‌شب): Tokyo 20:00->05:00 (1200->300، رد از
   // نیمه‌شب)، London 03:00->12:00 (180->720)، NewYork 09:00->18:00 (540->1080).
   bool inTokyo  = (nyMinutes>=1200 || nyMinutes<300);
   bool inLondon = (nyMinutes>=180  && nyMinutes<720);
   bool inNY     = (nyMinutes>=540  && nyMinutes<1080);

   if(!inTokyo && !inLondon && !inNY)
      return "OUT OF TRADING SESSION"; // شکاف ۱۸:۰۰->۲۰:۰۰ وقت نیویورک (سیدنی کم‌حجم)

   // چند دقیقه از شروع اسمی هر سشنِ فعال گذشته - غیرفعال‌ها یه مقدار خیلی بزرگ می‌گیرن که هیچ‌وقت
   // برنده‌ی مقایسه‌ی زیر نشن.
   int elapsedTokyo  = inTokyo  ? (((nyMinutes-1200)%1440+1440)%1440) : 999999;
   int elapsedLondon = inLondon ? (((nyMinutes-180) %1440+1440)%1440) : 999999;
   int elapsedNY     = inNY     ? (((nyMinutes-540) %1440+1440)%1440) : 999999;

   if(elapsedNY<=elapsedLondon && elapsedNY<=elapsedTokyo) return "NewYork";
   if(elapsedLondon<=elapsedTokyo)                         return "London";
   return "Tokyo";
}

void SessionLevel_RemoveWindows()
{
   for(int i=0; i<g_slObjCount; i++)
   {
      ObjectDelete(0, g_slBoxNames[i]);
      ObjectDelete(0, g_slLblNames[i]);
   }
   g_slObjCount = 0;
   ArrayResize(g_slBoxNames, 0);
   ArrayResize(g_slLblNames, 0);
   ArrayResize(g_slLane, 0);
}

// v57.2 (فیدبک Mahmoud - همپوشانی): سه بازه (Tokyo/London/NewYork) روی هم افتاده بودن، چون هر سه
// از یه لنگر ارتفاع مشترک استفاده می‌کردن - در حالی که این سه بازه از نظر زمانی خودشون با هم
// همپوشانی دارن (London هم با Tokyo هم با NewYork تداخل ساعتی داره)، پس اگه همزمان روی چارت
// دیده بشن باید هرکدوم روی یه "لِین" عمودی جدا بشینن. lane=0 نزدیک‌ترین به Key Time (پایین‌ترین)،
// lane=2 بالاترین. فاصله‌ی هر لِین از لِین بعدی = boxHPx (6) + یه گپ کوچک (2px) بین خودِ سه بازه -
// جدا از گپ بزرگ‌تر (4px) که lane=0 رو از باکس Key Time جدا نگه می‌داره.
void GetSessionLevelPriceRange(int lane, double &priceTop, double &priceBot)
{
   int chartH      = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int xPix        = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2;
   int boxHPx      = 6;
   int laneGapPx   = 2;   // فاصله‌ی بین خودِ سه لِین Session Level
   int keyTimeGapPx= 14;   // v57.4 (فیدبک Mahmoud): از 4 به 14 افزایش یافت - لیبل متنی Key Time (ANCHOR_LOWER) بالای باکسش رندر می‌شه، پس گپ قبلی (4px) برای عبور از زیر فونتش کافی نبود و باهاش تداخل بصری داشت
   int marginBotPx = 20 + keyTimeGapPx + lane*(boxHPx+laneGapPx);  // lane0=34, lane1=42, lane2=50

   int subWinBot = -1, subWinTop = -1;
   datetime tDummy = 0;
   bool okBot = ChartXYToTimePrice(0, xPix, chartH-marginBotPx,        subWinBot, tDummy, priceBot);
   bool okTop = ChartXYToTimePrice(0, xPix, chartH-marginBotPx-boxHPx, subWinTop, tDummy, priceTop);

   if(!okBot || !okTop || subWinBot!=0 || subWinTop!=0)
   {
      double pMax = WindowPriceMax(0);
      double pMin = WindowPriceMin(0);
      double range = pMax - pMin;
      if(range <= 0) { priceTop = Bid; priceBot = Bid; return; }
      double laneStep = 0.01;  // یه پله‌ی درصدی کوچیک بین لِین‌ها، فقط برای fallback (وقتی تبدیل pixel->price شکست بخوره)
      priceBot = pMin + range*(0.06 + lane*laneStep);
      priceTop = pMin + range*(0.07 + lane*laneStep);
   }
}

// v57.2: کدوم لِین عمودی (0/1/2) به هر لیبل سشن اختصاص داره - NewYork پایین‌ترین (نزدیک‌ترین به
// Key Time)، بعد London، بعد Tokyo بالاترین. ترتیب دلخواهه (فقط باید ثابت/بدون تداخل باشه).
int SessionLevel_LaneForLabel(string label)
{
   if(label=="Tokyo")  return 2;
   if(label=="London") return 1;
   return 0;  // NewYork (یا هر لیبل ناشناخته‌ی دیگه، ایمن)
}

// daysAgo می‌تونه منفی باشه (روز آینده) - ببین SessionLevel_GetNYDate بالا.
datetime g_slCullTime = 0;  // v95: مرز چپ ساخت باکس‌های Session Level (۰ = بدون محدودیت)
void SessionLevel_BuildOneBox(int daysAgo, string label, int sh, int sm, int eh, int em, color c)
{
   datetime t1, t2;
   SessionLevel_ComputeServerTime(daysAgo, sh, sm, eh, em, t1, t2);
   if(g_slCullTime > 0 && t2 < g_slCullTime) return;  // v95 (BUG-059): باکس‌های کاملاً چپِ ناحیه‌ی دیده‌شده ساخته نمی‌شن
   SessionLevel_EnsureChartShift(t2);  // BUG-046 fix - قبل از ساخت/آپدیت هر آبجکتی که ممکنه فراتر از Time[0] باشه

   string boxName = SESSLVL_BOX_PREFIX + label + "_" + IntegerToString(daysAgo);
   string lblName = SESSLVL_LBL_PREFIX + label + "_" + IntegerToString(daysAgo);

   int lane = SessionLevel_LaneForLabel(label);  // v57.2: هر سشن لِین عمودی خودش رو داره - بدون قاطی با بقیه
   double priceTop, priceBot;
   GetSessionLevelPriceRange(lane, priceTop, priceBot);

   if(ObjectFind(0,boxName)<0) ObjectCreate(0,boxName,OBJ_RECTANGLE,0,t1,priceBot,t2,priceTop);
   ObjectSetInteger(0,boxName,OBJPROP_TIME1,  t1);
   ObjectSetInteger(0,boxName,OBJPROP_TIME2,  t2);
   ObjectSetDouble (0,boxName,OBJPROP_PRICE1, priceBot);
   ObjectSetDouble (0,boxName,OBJPROP_PRICE2, priceTop);
   ObjectSetInteger(0,boxName,OBJPROP_COLOR,  c);
   ObjectSetInteger(0,boxName,OBJPROP_FILL,   true);
   ObjectSetInteger(0,boxName,OBJPROP_BACK,   true);
   ObjectSetInteger(0,boxName,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,boxName,OBJPROP_WIDTH,  1);
   ObjectSetInteger(0,boxName,OBJPROP_STYLE,  STYLE_SOLID);

   datetime tMid = t1 + (t2-t1)/2;
   if(ObjectFind(0,lblName)<0) ObjectCreate(0,lblName,OBJ_TEXT,0,tMid,priceTop);
   ObjectSetInteger(0,lblName,OBJPROP_TIME,  tMid);
   ObjectSetDouble (0,lblName,OBJPROP_PRICE, priceTop);
   ObjectSetString (0,lblName,OBJPROP_TEXT,  label);
   ObjectSetInteger(0,lblName,OBJPROP_COLOR, c);
   ObjectSetInteger(0,lblName,OBJPROP_FONTSIZE, 7);
   ObjectSetString (0,lblName,OBJPROP_FONT,  "Arial Bold");
   ObjectSetInteger(0,lblName,OBJPROP_ANCHOR, ANCHOR_LOWER);
   ObjectSetInteger(0,lblName,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,lblName,OBJPROP_BACK,   false);

   ArrayResize(g_slBoxNames, g_slObjCount+1);
   ArrayResize(g_slLblNames, g_slObjCount+1);
   ArrayResize(g_slLane,     g_slObjCount+1);
   g_slBoxNames[g_slObjCount] = boxName;
   g_slLblNames[g_slObjCount] = lblName;
   g_slLane[g_slObjCount]     = lane;
   g_slObjCount++;
}

// v57.1 (فیدبک Mahmoud - محدوده‌ها): سه بازه‌ی جدید - Tokyo 20:00->05:00 (از نیمه‌شب رد می‌شه)،
// London 03:00->12:00، New York 09:00->18:00 (همه به وقت نیویورک). daysAgo از -1 (فردا - تا
// سشن‌های هنوز-شروع‌نشده‌ی نزدیک لبه‌ی نیمه‌شب از قبل آماده باشن) تا SESSLVL_HISTORY_DAYS
// (تاریخچه) لوپ می‌زنه - دقیقاً همین "ساخت آبجکت‌های سشن آینده" جاییه که SessionLevel_EnsureChartShift
// بالا لازم می‌شه.
void SessionLevel_BuildWindows()
{
   SessionLevel_RemoveWindows();
   if(!g_sessLvlOn) return;
   g_slCullTime = 0;  // v95 (BUG-059): همون cull چپِ Key Time
   int slFirstVis = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   if(slFirstVis >= 0 && slFirstVis < Bars)
   {
      datetime slLeftT = iTime(Symbol(), Period(), slFirstVis);
      if(slLeftT > 0) g_slCullTime = slLeftT - 86400;
   }
   // v57.1 (فیدبک Mahmoud - رنگ): از GetFiboMeasureColor() (بر پایه‌ی رنگ بدنه‌ی کندل نزولی،
   // با کنتراست خودکار در برابر بک‌گراند از قبل داخل ResolveFiboLineColor()) استفاده می‌شه - نه
   // GetFiboRRColor() (بولیش) که Key Time استفاده می‌کنه - تا این دو ابزار همیشه رنگ متفاوت داشته
   // باشن، بدون کد جدید برای منطق کنتراست (از قبل موجوده و امتحان‌پس‌داده).
   color boxColor = GetSessionLevelBoxColor();  // v84: رنگ قبلی عیناً حفظ شد (GetFiboMeasureColor حالا خاکستری ثابت Measure Move است)

   for(int daysAgo=-1; daysAgo<=SESSLVL_HISTORY_DAYS; daysAgo++)
   {
      SessionLevel_BuildOneBox(daysAgo, "Tokyo",   20,0, 5,0,  boxColor);
      SessionLevel_BuildOneBox(daysAgo, "London",   3,0, 12,0, boxColor);
      SessionLevel_BuildOneBox(daysAgo, "NewYork",  9,0, 18,0, boxColor);
   }
   ChartRedraw();
}

// هر تیک صدا زده می‌شه - فقط موقعیت عمودی رو با بازه‌ی قیمت دیده‌شده هماهنگ می‌کنه، بدون لمس زمان.
// v57.2: سه لِین جدا (نه یه بازه‌ی مشترک) - هر لِین فقط یک‌بار در ابتدای تابع محاسبه می‌شه (نه به
// ازای هر آبجکت)، بعد بر اساس g_slLane[i] هر آبجکت به لِین خودش وصل می‌شه.
uint g_slVertLastMs = 0;  // v95 (BUG-059): همون throttle ۳ثانیه‌ای UpdateSessionWindowsVertical - CHART_CHANGE موقع زوم/اسکرول خودش rebuild می‌کنه
void SessionLevel_UpdateVertical()
{
   if(!g_sessLvlOn || g_slObjCount<=0) return;
   uint nowSlMs = GetTickCount();
   if(nowSlMs - g_slVertLastMs < 3000) return;
   g_slVertLastMs = nowSlMs;
   if(g_slCullTime > 0)  // v95: اگه کاربر بیشتر از مرز فعلی به عقب اسکرول کرده، دوباره بساز
   {
      int slFv = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
      if(slFv >= 0 && slFv < Bars)
      {
         datetime slLt = iTime(Symbol(), Period(), slFv);
         if(slLt > 0 && slLt - 86400 < g_slCullTime) { SessionLevel_BuildWindows(); return; }
      }
   }
   double laneTop[3] = {0,0,0}, laneBot[3] = {0,0,0};  // v57.3 (فیکس هشدار کامپایلر): مقداردهی اولیه‌ی صریح - GetSessionLevelPriceRange() همیشه هر دو خروجی رو قبل از استفاده پر می‌کنه، ولی کامپایلر بدون این مقداردهی اولیه نمی‌تونه اینو در حلقه‌ی زیر تشخیص بده
   for(int L=0; L<3; L++) GetSessionLevelPriceRange(L, laneTop[L], laneBot[L]);
   for(int i=0; i<g_slObjCount; i++)
   {
      int lane = g_slLane[i];
      if(lane<0 || lane>2) lane=0;  // ایمنی - نباید پیش بیاد، ولی fallback بی‌ضرر
      if(ObjectFind(0,g_slBoxNames[i])>=0)
      {
         ObjectSetDouble(0,g_slBoxNames[i],OBJPROP_PRICE1, laneBot[lane]);
         ObjectSetDouble(0,g_slBoxNames[i],OBJPROP_PRICE2, laneTop[lane]);
      }
      if(ObjectFind(0,g_slLblNames[i])>=0)
         ObjectSetDouble(0,g_slLblNames[i],OBJPROP_PRICE, laneTop[lane]);
   }
}

void SessionLevel_SaveState()
{
   GlobalVariableSet(GV_SESSLVL_ON, g_sessLvlOn ? 1.0 : 0.0);
}

void SessionLevel_LoadState()
{
   if(GlobalVariableCheck(GV_SESSLVL_ON))
      g_sessLvlOn = (GlobalVariableGet(GV_SESSLVL_ON) != 0.0);
}

//+------------------------------------------------------------------+
//| v85 (کار اول): History - باکس‌های معاملات بسته‌شده                  |
//+------------------------------------------------------------------+
// دکمه‌ی HISTORY (Utility، نیمه‌ی راست ردیف BE REF LINE). Toggle: روشن -> برای هر معامله‌ی بسته‌شده‌ی همین
// نماد/MagicNumber که CloseTime اش در HistoryDaysBack روز اخیر است، دو OBJ_RECTANGLE پرشده (همان تکنیک Session
// Level) رسم می‌شه: باکس روشن = قیمت ورود تا TP، باکس تیره = قیمت ورود تا SL. عرض افقی = دقیقاً OpenTime تا
// CloseTime همان معامله. داده از همان منبع ژورنال CSV (تاریخچه‌ی MT4 + Snapshot) - هیچ جمع‌آوری جدیدی نیست:
//   Entry = OrderOpenPrice، TP = OrderTakeProfit (= TP_Final ژورنال).
//   SL = SL اولیه‌ی Snapshot (ریسک واقعی برنامه‌ریزی‌شده) و اگه Snapshot نبود OrderStopLoss (= SL_Final ژورنال).
//        دلیل: SL_Final بعد از BE/Trailing ممکنه روی ورود یا سمت سود باشه و باکس ریسک صفر یا وارونه می‌شد.
// معاملات TP/SL صفر (یا SL روی ورود) باکس مربوطه رو ندارن.
#define HIST_BOX_PREFIX "RM9HIST_"
bool     g_histOn        = false;
string   GV_HIST_ON      = "RM_HistOn_" + Symbol();
int      g_histLastTotal = -1;   // OrdersHistoryTotal() لحظه‌ی آخرین رسم - تغییرش یعنی معامله‌ی تازه بسته شده
int      g_histDrawn     = 0;    // تعداد معامله‌هایی که آخرین بار رسم شد (برای پیام وضعیت)

void History_SaveState()
{
   GlobalVariableSet(GV_HIST_ON, g_histOn ? 1.0 : 0.0);
}

void History_LoadState()
{
   if(GlobalVariableCheck(GV_HIST_ON))
      g_histOn = (GlobalVariableGet(GV_HIST_ON) != 0.0);
}

void History_Remove()
{
   ObjectsDeleteAll(0, HIST_BOX_PREFIX);
   g_histDrawn = 0;
}

// کنتراست خودکار با همان منطق روشنی بک‌گراند GetFiboToolGrayColor (v84) / GetKeyTimeLineColor: رنگ ثابت سخت‌کد نیست.
// بک‌گراند تیره -> هر دو باکس از بک‌گراند روشن‌ترند (روشن = خاکستری روشن، تیره = خاکستری میانی)؛
// بک‌گراند روشن -> هر دو از بک‌گراند تیره‌ترند (روشن = کمی تیره‌تر از بک‌گراند، تیره = خیلی تیره‌تر).
void History_GetColors(color &lightBox, color &darkBox)
{
   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   double bgLum = 0.299*(chartBg & 0xFF) + 0.587*((chartBg >> 8) & 0xFF) + 0.114*((chartBg >> 16) & 0xFF);
   int lg, dg;
   if(bgLum >= 128)
   {
      lg = (int)MathMax(60.0, MathMin(215.0, bgLum - 45.0));
      dg = (int)MathMax(15.0, MathMin(lg - 45.0, bgLum - 115.0));
   }
   else
   {
      lg = (int)MathMin(225.0, MathMax(150.0, bgLum + 100.0));
      dg = (int)MathMin(lg - 45.0, MathMax(55.0, bgLum + 45.0));
   }
   lightBox = (color)(lg | (lg<<8) | (lg<<16));
   darkBox  = (color)(dg | (dg<<8) | (dg<<16));
}

// v100 (FEAT-046): ریشه‌هایی که باکس‌هایشان «توخالی» (فقط کادر) نمایش داده می‌شود - با کلیک روی مارکر Entry/Exit همان
// معامله toggle می‌شود (ToggleMarkTicketLabel). در آرایه می‌ماند تا History_Build (هر معامله‌ی تازه/تغییر روز) آن را از دست ندهد.
int g_histHollowRoots[];
int g_histHollowCount = 0;

bool History_IsHollow(int root)
{
   for(int i=0;i<g_histHollowCount;i++)
      if(g_histHollowRoots[i]==root) return true;
   return false;
}

void History_ApplyHollowStyle(string name, bool hollow)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetInteger(0, name, OBJPROP_FILL,  !hollow);
   ObjectSetInteger(0, name, OBJPROP_BACK,  !hollow);  // توخالی: جلوی بقیه‌ی باکس‌ها (پر) رسم شود تا کادرش زیر آن‌ها گم نشود
   ObjectSetInteger(0, name, OBJPROP_WIDTH, hollow ? 2 : 1);
}

// کلیک روی مارکر یک معامله: باکس‌های زنجیره‌ی آن (TP + SL) توخالی/پر می‌شوند. فقط چند ObjectSet روی آبجکت‌های موجود.
void History_SetHollow(int root, bool hollow)
{
   bool has = History_IsHollow(root);
   if(hollow && !has)
   {
      ArrayResize(g_histHollowRoots, g_histHollowCount+1);
      g_histHollowRoots[g_histHollowCount] = root;
      g_histHollowCount++;
   }
   else if(!hollow && has)
   {
      for(int i=0;i<g_histHollowCount;i++)
         if(g_histHollowRoots[i]==root)
         {
            for(int k=i;k<g_histHollowCount-1;k++) g_histHollowRoots[k] = g_histHollowRoots[k+1];
            g_histHollowCount--;
            ArrayResize(g_histHollowRoots, g_histHollowCount);
            break;
         }
   }
   string baseName = HIST_BOX_PREFIX + IntegerToString(root);
   History_ApplyHollowStyle(baseName + "_TP", hollow);
   History_ApplyHollowStyle(baseName + "_SL", hollow);
}

void History_DrawBox(string name, datetime t1, double p1, datetime t2, double p2, color c)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME1,  t1);
   ObjectSetInteger(0, name, OBJPROP_TIME2,  t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE1, p1);
   ObjectSetDouble (0, name, OBJPROP_PRICE2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR,  c);
   ObjectSetInteger(0, name, OBJPROP_FILL,   true);
   ObjectSetInteger(0, name, OBJPROP_BACK,   true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,  1);
   ObjectSetInteger(0, name, OBJPROP_STYLE,  STYLE_SOLID);
}

void History_Build()
{
   History_Remove();
   g_histLastTotal = OrdersHistoryTotal();
   if(!g_histOn) return;

   int days = (int)MathMax(1, HistoryDaysBack);
   datetime fromTime = TimeCurrent() - (datetime)days * 86400;

   color cLight, cDark;
   History_GetColors(cLight, cDark);

   double pt = MarketInfo(Symbol(), MODE_POINT);
   if(pt <= 0) pt = Point;

   // v89 (History - مرور معاملات): هر «زنجیره» (ریشه‌ی مشترک Half Close) فقط یک جفت باکس دارد که از لحظه‌ی باز شدن معامله‌ی مادر
   // تا بسته‌شدن «آخرین بخش» ادامه دارد؛ بخش‌های بسته‌شده‌ی زودتر باکس جدا نمی‌سازند. معامله‌ی تکی (ریشه = خودش) مثل قبل.
   // زنجیره‌ای که هنوز بخش بازی دارد (IsChainFullyClosed) رسم نمی‌شود و با بسته‌شدن آخرین بخش باکسش کامل ظاهر می‌شود -
   // همان قاعده‌ای که آمار Trading Reports دارد.
   int    gRoot[];  ArrayResize(gRoot, 0);
   datetime gOpen[]; ArrayResize(gOpen, 0);
   datetime gClose[]; ArrayResize(gClose, 0);
   double gEntry[]; ArrayResize(gEntry, 0);
   double gTP[];    ArrayResize(gTP, 0);
   double gSL[];    ArrayResize(gSL, 0);
   bool   gRootSeen[]; ArrayResize(gRootSeen, 0);   // v90 (FEAT-044): ردیف خودِ تیکت ریشه دیده شد؟ (قیمت ورود باکس = ورود ریشه، نه اولین ردیفِ دیده‌شده)
   int    gn = 0;

   int total = g_histLastTotal;
   for(int i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      datetime openTime  = OrderOpenTime();
      datetime closeTime = OrderCloseTime();
      if(closeTime <= 0 || closeTime < fromTime) continue;

      int    ticket = OrderTicket();
      int    root   = GetRootTicket(ticket);
      double entry  = OrderOpenPrice();
      double tp     = OrderTakeProfit();
      double sl     = OrderStopLoss();

      // SL اولیه (ریسک واقعی) از Snapshot ریشه، یا خودِ تیکت؛ بدون Snapshot همان SL_Final ژورنال
      int snap = FindSnapshotIndex(root);
      if(snap < 0) snap = FindSnapshotIndex(ticket);
      if(snap >= 0 && MathAbs(g_snapEntry[snap] - g_snapSL[snap]) > 0)
         sl = g_snapSL[snap];

      int k = -1;
      for(int q = 0; q < gn; q++)
         if(gRoot[q] == root) { k = q; break; }
      if(k < 0)
      {
         ArrayResize(gRoot, gn+1); ArrayResize(gOpen, gn+1); ArrayResize(gClose, gn+1);
         ArrayResize(gEntry, gn+1); ArrayResize(gTP, gn+1); ArrayResize(gSL, gn+1); ArrayResize(gRootSeen, gn+1);
         k = gn++;
         gRoot[k] = root; gOpen[k] = openTime; gClose[k] = closeTime;
         gEntry[k] = entry; gTP[k] = tp; gSL[k] = sl;
         gRootSeen[k] = (ticket == root);
      }
      else
      {
         if(openTime < gOpen[k]) gOpen[k] = openTime;                 // باز شدن مادر = زودترین
         if(ticket == root){ gEntry[k] = entry; gRootSeen[k] = true; }  // v90 (FEAT-044): قیمت ورود باکس = ورود خودِ ریشه، مستقل از ترتیب ردیف‌ها (ورود ادامه قیمت دیگری دارد)
         if(closeTime >= gClose[k])                                   // آخرین بخش: TP/SL نهایی را تعیین می‌کند
         {
            gClose[k] = closeTime;
            if(tp > 0) gTP[k] = tp;
            if(snap < 0 && sl > 0) gSL[k] = sl;
         }
      }
   }

   for(int g = 0; g < gn; g++)
   {
      if(!IsChainFullyClosed(gRoot[g])) continue;   // زنجیره‌ی نیمه‌باز: هنوز باکس نمی‌گیرد

      // v90 (FEAT-044): ردیف ریشه در بازه‌ی تاریخچه‌ی دیده‌شده نبود (مثلاً زودتر بسته شده) -> ورود از Snapshot ریشه
      if(!gRootSeen[g])
      {
         int sRoot = FindSnapshotIndex(gRoot[g]);
         if(sRoot >= 0 && g_snapEntry[sRoot] > 0) gEntry[g] = g_snapEntry[sRoot];
      }

      datetime t2 = gClose[g];
      if(t2 <= gOpen[g]) t2 = gOpen[g] + (datetime)MathMax(60, PeriodSeconds());

      string baseName = HIST_BOX_PREFIX + IntegerToString(gRoot[g]);
      if(gTP[g] > 0 && MathAbs(gTP[g] - gEntry[g]) >= pt)
      {
         History_DrawBox(baseName + "_TP", gOpen[g], gEntry[g], t2, gTP[g], cLight);
         if(History_IsHollow(gRoot[g])) History_ApplyHollowStyle(baseName + "_TP", true);
      }
      if(gSL[g] > 0 && MathAbs(gSL[g] - gEntry[g]) >= pt)
      {
         History_DrawBox(baseName + "_SL", gOpen[g], gEntry[g], t2, gSL[g], cDark);
         if(History_IsHollow(gRoot[g])) History_ApplyHollowStyle(baseName + "_SL", true);
      }
      g_histDrawn++;
   }
   ChartRedraw();
}

// هر تیک: فقط اگه تعداد تاریخچه عوض شده (معامله‌ی تازه بسته شد) دوباره رسم می‌کنه.
void History_Refresh()
{
   if(!g_histOn) return;
   if(OrdersHistoryTotal() != g_histLastTotal) History_Build();
}

//+------------------------------------------------------------------+
//| v57 (فیچر جدید مستقل): Entry/Exit Markers                          |
//+------------------------------------------------------------------+
// هدف: فلش آبی روی نقطه‌ی ورود واقعی هر معامله، فلش قرمز روی نقطه‌ی خروج واقعی (سبک History
// متاتریدر ۵) + یه خط‌چین که دو نقطه رو وصل می‌کنه - بدون هیچ رنگ‌بندی بر اساس نتیجه (برد/باخت
// بی‌ربطه؛ آبی/قرمز فقط یعنی "ورود"/"خروج"). بازه: معاملات بسته‌شده‌ی یک ماه گذشته + همه‌ی
// معاملات باز فعلی (بدون فلش خروج/خط‌چین، چون هنوز خارج نشدن). پیش‌فرض: خاموش.
bool     g_markersOn = false;
string   GV_MARKERS_ON = "RM_MarkersOn_" + Symbol();
#define  MARK_HISTORY_DAYS  30
#define  MARK_ENTRY_PREFIX  "RM9AR_ENT_"
#define  MARK_EXIT_PREFIX   "RM9AR_EXIT_"
#define  MARK_LINE_PREFIX   "RM9TL_MARK_"
// عمداً با پیشوند P (پنل) شروع نمی‌شن - همون دلیل بقیه‌ی ابزارهای این فایل.
string   g_markObjNames[];
int      g_markObjCount = 0;

// v59 (Item 3a - Ticket Label on Click): کدوم تیکت‌ها الان لیبل‌شون نشون داده می‌شه - جدا از
// g_markObjNames بالا نگه داشته می‌شه چون اون آرایه هر rebuild (هر کندل جدید، RefreshEntryExitMarkers)
// کامل پاک/دوباره‌ساخته می‌شه، ولی این‌جا "کدوم تیکت‌ها toggle شدن" باید بین rebuildها زنده بمونه -
// وگرنه با هر کندل جدید همه‌ی لیبل‌های باز شده دوباره مخفی می‌شدن.
int g_markLabelShownTickets[];
int g_markLabelShownCount = 0;
#define  MARK_LBL_ENTRY_PREFIX  "RM9LB_ENT_"
#define  MARK_LBL_EXIT_PREFIX   "RM9LB_EXIT_"

bool IsMarkLabelShown(int ticket)
{
   for(int i=0;i<g_markLabelShownCount;i++)
      if(g_markLabelShownTickets[i]==ticket) return true;
   return false;
}

// کلیک روی هر کدوم از دو فلش (Entry یا Exit) یک معامله، لیبل شماره‌ی تیکت کنار هر دوشون رو با هم
// toggle می‌کنه - فقط چند ObjectSetInteger ارزون روی آبجکت‌های موجود (بدون rebuild کامل).
void ToggleMarkTicketLabel(int ticket)
{
   bool nowShown = !IsMarkLabelShown(ticket);

   if(nowShown)
   {
      ArrayResize(g_markLabelShownTickets, g_markLabelShownCount+1);
      g_markLabelShownTickets[g_markLabelShownCount] = ticket;
      g_markLabelShownCount++;
   }
   else
   {
      for(int i=0;i<g_markLabelShownCount;i++)
      {
         if(g_markLabelShownTickets[i]==ticket)
         {
            for(int k=i;k<g_markLabelShownCount-1;k++)
               g_markLabelShownTickets[k] = g_markLabelShownTickets[k+1];
            g_markLabelShownCount--;
            ArrayResize(g_markLabelShownTickets, g_markLabelShownCount);
            break;
         }
      }
   }

   int tf = nowShown ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
   string entName = MARK_LBL_ENTRY_PREFIX+IntegerToString(ticket);
   string exitName = MARK_LBL_EXIT_PREFIX+IntegerToString(ticket);
   if(ObjectFind(0,entName)>=0)  ObjectSetInteger(0,entName, OBJPROP_TIMEFRAMES, tf);
   if(ObjectFind(0,exitName)>=0) ObjectSetInteger(0,exitName,OBJPROP_TIMEFRAMES, tf);
   // v100 (FEAT-046): هم‌زمان باکس‌های History همان معامله (زنجیره) توخالی/پر شوند - لیبل روشن = توخالی، لیبل مخفی = پر
   if(g_histOn) History_SetHollow(GetRootTicket(ticket), nowShown);
   ChartRedraw();
}

void EntryExitMarkers_Track(string objName)
{
   ArrayResize(g_markObjNames, g_markObjCount+1);
   g_markObjNames[g_markObjCount] = objName;
   g_markObjCount++;
}

void RemoveEntryExitMarkers()
{
   for(int i=0; i<g_markObjCount; i++)
      ObjectDelete(0, g_markObjNames[i]);
   g_markObjCount = 0;
   ArrayResize(g_markObjNames, 0);
}

// v59.2 (پیگیری - برگشت): RefreshMarkerColorForTicket() که این‌جا بود (v59.1) حذف شد - رنگ فلش/
// لیبل چارت دیگه بر اساس تگ عوض نمی‌شه (برگشت به آبی/قرمز ثابت، ببین EntryExitMarkers_BuildEntry/
// BuildExit پایین). تفکیک تگ‌خورده/نخورده حالا توی لیست پنجره‌ی Tag Trade (BuildTagWindow) انجام می‌شه.

// یه فلش ورود آبی (بالا برای Buy، پایین برای Sell - شکل فقط جهت رو نشون می‌ده، نه نتیجه) رو
// می‌سازه/آپدیت می‌کنه و به لیست ردیابی اضافه می‌کنه.
// v59 (Item 3a - Ticket Label on Click): لیبل متنی شماره‌ی تیکت، پیش‌فرض مخفی (OBJ_NO_PERIODS) -
// نمایش/مخفی‌شدنش فقط با ToggleMarkTicketLabel() (کلیک روی هر فلش) عوض می‌شه، نه این‌جا.
// v59.1 (پیگیری - فیدبک Mahmoud): سایز فونت قبلی (7) خیلی ریز بود و چون لیبل دقیقاً روی همون
// نقطه‌ی زمان/قیمت خودِ فلش می‌نشست (بدون هیچ فاصله‌ای)، با خودِ فلش قاطی/نامخوانا می‌شد. فیکس:
// (۱) FONTSIZE از 7 به 14 (دو برابر) رفت. (۲) یه فاصله‌ی عمودی واقعی بین لیبل و فلش اضافه شد -
// بر اساس درصد ثابتی از بازه‌ی قیمتی نمایش‌داده‌شده‌ی چارت (WindowPriceMax/Min)، دقیقاً همون
// الگوی موجود UpdateCandleTimerChart() (بالای همین فایل) - نه یک مقدار پیپ ثابت، چون این EA
// چندنمادیه (XAUUSD، فارکس، و غیره) و مقیاس قیمتشون خیلی فرق داره؛ درصد از بازه‌ی زوم فعلی روی
// هر نماد/زوم فاصله‌ی بصری تقریباً یکسانی می‌ده.
void EntryExitMarkers_BuildTicketLabel(string name, int ticket, datetime t, double p, color c, bool anchorAbove)
{
   double priceMax = WindowPriceMax(0);
   double priceMin = WindowPriceMin(0);
   double visibleRange = priceMax - priceMin;
   double gap = (visibleRange > 0) ? visibleRange * 0.02 : 0;
   double labelPrice = anchorAbove ? (p + gap) : (p - gap);

   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,t,labelPrice);
   ObjectSetInteger(0,name,OBJPROP_TIME,  t);
   ObjectSetDouble (0,name,OBJPROP_PRICE, labelPrice);
   ObjectSetString (0,name,OBJPROP_TEXT,  "#"+IntegerToString(ticket));
   ObjectSetInteger(0,name,OBJPROP_COLOR, c);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE, 14);
   ObjectSetString (0,name,OBJPROP_FONT,  "Arial Bold");
   ObjectSetInteger(0,name,OBJPROP_ANCHOR, anchorAbove ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,name,OBJPROP_BACK,   false);
   // پیش‌فرض مخفی، مگر اینکه این تیکت از قبل (قبل از این rebuild) toggle-شده/باز باشه - وگرنه با
   // هر کندل جدید (rebuild خودکار) لیبل‌های قبلاً بازشده دوباره مخفی می‌شدن.
   ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES, IsMarkLabelShown(ticket) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
   EntryExitMarkers_Track(name);
}

void EntryExitMarkers_BuildEntry(int ticket, datetime openT, double openP, bool isBuy, color entryColor)
{
   // v59.2 (پیگیری - برگشت): تلاش قبلی (v59.1) رنگ فلش/لیبل رو برای تیکت‌های تگ‌خورده به
   // CLR_TOOLS_ACTIVE عوض می‌کرد - ولی این باعث می‌شد فلش ورود (آبی) و فلش خروج (قرمز) هر دو یک
   // رنگ یکسان بشن و از هم قابل‌تشخیص نباشن (فیدبک Mahmoud). برگردونده شد به رنگ ثابت قبلی -
   // آبی برای ورود، قرمز برای خروج، مستقل از وضعیت تگ. تفکیک تگ‌خورده/نخورده حالا جای درستش رو
   // توی خودِ لیست پنجره‌ی Tag Trade (BuildTagWindow، پایین همین فایل) داره، نه روی فلش‌های چارت.
   string name = MARK_ENTRY_PREFIX + IntegerToString(ticket);
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,openT,openP);
   ObjectSetInteger(0,name,OBJPROP_TIME,  openT);
   ObjectSetDouble (0,name,OBJPROP_PRICE, openP);
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE, isBuy ? 233 : 234);  // wingdings up/down - جهت فقط، بدون معنی برد/باخت
   ObjectSetInteger(0,name,OBJPROP_COLOR,  entryColor);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,  2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,name,OBJPROP_BACK,   false);
   EntryExitMarkers_Track(name);

   // v59 (Item 3a): لیبل تیکت کنار فلش ورود - بالای فلش Buy (که خودش پایین کندل می‌شینه)، پایین فلش Sell
   EntryExitMarkers_BuildTicketLabel(MARK_LBL_ENTRY_PREFIX+IntegerToString(ticket), ticket, openT, openP, entryColor, isBuy);
}

void EntryExitMarkers_BuildExit(int ticket, datetime closeT, double closeP, bool isBuy, color exitColor)
{
   // v59.2 (پیگیری - برگشت): همون توضیح بالا (EntryExitMarkers_BuildEntry) - رنگ ثابت قبلی برگشت.
   string name = MARK_EXIT_PREFIX + IntegerToString(ticket);
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,closeT,closeP);
   ObjectSetInteger(0,name,OBJPROP_TIME,  closeT);
   ObjectSetDouble (0,name,OBJPROP_PRICE, closeP);
   // v57.4 (فیدبک Mahmoud - سایز، تلاش دوم): گلیف پرچم (کد 158) با هیچ WIDTH ای درست هم‌اندازه‌ی
   // فلش ورود نمی‌شد - چون گلیف‌های مختلف Wingdings مساحت ذاتاً متفاوتی دارن، تنظیم WIDTH به‌تنهایی
   // کافی نبود. راه‌حل قطعی: به‌جای گلیف متفاوت، از همون خانواده‌ی گلیف فلش (233/234) که فلش ورود
   // هم استفاده می‌کنه، ولی در جهت مخالف ورود استفاده می‌شه (مثلاً ورود Buy=بالا -> خروج=پایین) -
   // چون گلیف کاملاً یکسانه، سایز رندرشده هم تضمینی یکسانه؛ تشخیص "ورود"/"خروج" فقط از رنگ
   // (آبی/قرمز) میاد، نه از شکل جهت (که صرفاً معکوس همون قرارداد فلش وروده) - بدون رنگ‌بندی نتیجه.
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE, isBuy ? 234 : 233);
   ObjectSetInteger(0,name,OBJPROP_COLOR,  exitColor);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,  2);  // دقیقاً همون WIDTH فلش ورود - چون گلیف هم یکیه، این دو الان واقعاً هم‌اندازه‌ن
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,name,OBJPROP_BACK,   false);
   EntryExitMarkers_Track(name);

   // v59 (Item 3a): لیبل تیکت کنار فلش خروج - جهت anchor برعکس فلش ورود (گلیف خروج هم برعکس ورودیه، همون قرارداد بالا)
   EntryExitMarkers_BuildTicketLabel(MARK_LBL_EXIT_PREFIX+IntegerToString(ticket), ticket, closeT, closeP, exitColor, !isBuy);
}

void EntryExitMarkers_BuildLine(int ticket, datetime t1, double p1, datetime t2, double p2)
{
   string name = MARK_LINE_PREFIX + IntegerToString(ticket);
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);
   ObjectSetInteger(0,name,OBJPROP_TIME1,  t1);
   ObjectSetDouble (0,name,OBJPROP_PRICE1, p1);
   ObjectSetInteger(0,name,OBJPROP_TIME2,  t2);
   ObjectSetDouble (0,name,OBJPROP_PRICE2, p2);
   ObjectSetInteger(0,name,OBJPROP_COLOR,  C'130,130,140');
   // v57.5 (فیدبک Mahmoud - سایز ریزتر): WIDTH از قبل رو مینیمم MT4 بود (1) - جایی برای ریزتر شدن
   // نداشت. راه‌حل: خودِ الگوی خط از STYLE_DASH (خط‌چین با قطعات نسبتاً بلند) به STYLE_DOT (نقطه‌چین
   // ریز) تغییر کرد - از نظر بصری محسوس‌طور ریزتر/کم‌رنگ‌تر از قبل.
   ObjectSetInteger(0,name,OBJPROP_STYLE,  STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,  1);
   ObjectSetInteger(0,name,OBJPROP_RAY,    false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,name,OBJPROP_BACK,   true);
   EntryExitMarkers_Track(name);
}

// فیلتر MagicNumber + Symbol() (برخلاف CalcTradingReportStats/ExportTradeJournalCSV که فقط
// MagicNumber رو چک می‌کنن) - چون این آبجکت‌ها روی خودِ چارت رسم می‌شن، فقط معاملات همین نماد
// قابل‌نمایشن (یه آبجکت با زمان/قیمت نماد دیگه روی این چارت بی‌معنیه).
void BuildEntryExitMarkers()
{
   RemoveEntryExitMarkers();
   if(!g_markersOn) return;

   color entryColor = C'30,144,255';  // آبی - فقط "ورود"
   color exitColor  = C'220,60,60';   // قرمز - فقط "خروج"، مستقل از نتیجه
   datetime cutoff = TimeCurrent() - ((datetime)MARK_HISTORY_DAYS)*86400;

   int total = OrdersHistoryTotal();
   for(int i=0; i<total; i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(OrderCloseTime() < cutoff) continue;

      int      ticket  = OrderTicket();
      datetime openT   = OrderOpenTime();
      datetime closeT  = OrderCloseTime();
      double   openP   = OrderOpenPrice();
      double   closeP  = OrderClosePrice();
      bool     isBuy   = (OrderType()==OP_BUY);

      EntryExitMarkers_BuildEntry(ticket, openT, openP, isBuy, entryColor);
      EntryExitMarkers_BuildExit (ticket, closeT, closeP, isBuy, exitColor);
      EntryExitMarkers_BuildLine (ticket, openT, openP, closeT, closeP);
   }

   int openTotal = OrdersTotal();
   for(int i=0; i<openTotal; i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;

      int      ticket = OrderTicket();
      datetime openT  = OrderOpenTime();
      double   openP  = OrderOpenPrice();
      bool     isBuy  = (OrderType()==OP_BUY);

      // معامله‌ی باز - فقط فلش ورود (بدون فلش خروج/خط‌چین، چون هنوز خارج نشده)
      EntryExitMarkers_BuildEntry(ticket, openT, openP, isBuy, entryColor);
   }

   ChartRedraw();
}

// هر تیک صدا زده می‌شه ولی فقط یک‌بار در هر کندل جدید واقعاً rebuild می‌کنه (حجم لوپ روی کل
// تاریخچه/معاملات باز، برخلاف SessionLevel_UpdateVertical که فقط چندتا ObjectSetDouble ارزونه) -
// وقتی خاموشه فقط BuildEntryExitMarkers() (که خودش idempotent پاک می‌کنه) صدا زده می‌شه.
void RefreshEntryExitMarkers()
{
   if(!g_markersOn) return;
   static datetime lastBar = 0;
   datetime curBar = (ArraySize(Time)>0) ? Time[0] : 0;
   if(curBar != lastBar)
   {
      lastBar = curBar;
      BuildEntryExitMarkers();
   }
}

void SaveEntryExitMarkersState()
{
   GlobalVariableSet(GV_MARKERS_ON, g_markersOn ? 1.0 : 0.0);
}

void LoadEntryExitMarkersState()
{
   if(GlobalVariableCheck(GV_MARKERS_ON))
      g_markersOn = (GlobalVariableGet(GV_MARKERS_ON) != 0.0);
}

// v66 (آیتم ۱ - سازمان‌دهی پوشه‌ی اسکرین‌شات‌ها): یک‌بار در OnInit صدا زده می‌شه - زیرپوشه‌ی
// TRADE SCREENSHOTS رو زیر MQL4/Files می‌سازه (اگه از قبل نبود) تا اسکرین‌شات‌های لحظه‌ی خروج
// (v59) دیگه مستقیم توی ریشه‌ی Files ریخته نشن. FolderCreate() اگه پوشه از قبل وجود داشته باشه
// هم true برمی‌گردونه (بدون خطا) - پس فراخوانی امن در هر OnInit (حتی بعد از ری‌استارت‌های بعدی).
void EnsureScreenshotFolder()
{
   if(!FolderCreate(SCREENSHOT_FOLDER))
      Print("RM_Tools: EnsureScreenshotFolder - FolderCreate('"+SCREENSHOT_FOLDER+"') failed, error ", GetLastError());
}

//+------------------------------------------------------------------+
//| v59 (Item 2 - فیچر جدید مستقل): Chart Screenshot at Exit           |
//+------------------------------------------------------------------+
// هدف: لحظه‌ای که بسته‌شدن یک معامله تشخیص داده می‌شه (فقط Exit، نه Entry)، ChartScreenShot() از
// همون وضعیت بصری فعلی چارت گرفته می‌شه - شامل Entry/Exit Markers (اگه g_markersOn روشن باشه)
// بدون هیچ اجبار خاصی روی ظاهر چارت (هیچ تغییری روی هیچ toggle/آبجکتی اعمال نمی‌شه، فقط از
// وضعیت موجود عکس گرفته می‌شه). اسم فایل با Ticket کلید می‌خوره تا از ExportTradeJournalCSV()
// (RM_Reports.mqh) قابل ارجاع باشه. صدا زده می‌شه از CheckClosedTrades() (RM_CooldownEngine.mqh)،
// دقیقاً همون لحظه‌ای که یک تیکت ردیابی‌شده به‌عنوان "دیگه باز نیست" تشخیص داده می‌شه - این
// نزدیک‌ترین تیکی هست که EA می‌تونه به لحظه‌ی واقعی بسته‌شدن داشته باشه (بدون event زنده‌ی
// on-close از خود MT4)، پس یک تخمین بهترین‌تلاش از "وضعیت چارت لحظه‌ی خروج" است، نه تضمین دقیق
// به میلی‌ثانیه.
string ExitScreenshot_Filename(int ticket)
{
   return "RM_ExitShot_" + IntegerToString(MagicNumber) + "_" + IntegerToString(ticket) + ".png";
}

// v66 (آیتم ۱): مسیر نسبی کامل (پوشه + اسم فایل) - همون چیزی که هم به ChartScreenShot() هم به
// FileIsExist() پاس داده می‌شه، تا فایل واقعی روی دیسک همیشه از روی همین رشته قابل‌پیدا کردن باشه
// (چه از EA، چه دستی توسط Mahmoud توی MQL4\Files\TRADE SCREENSHOTS).
string ExitScreenshot_RelativePath(int ticket)
{
   return SCREENSHOT_FOLDER + "\\" + ExitScreenshot_Filename(ticket);
}

// v59.1 (پیگیری - فیکس باگ): گزارش Mahmoud - فلش خروج توی اسکرین‌شات دیده نمی‌شد. ریشه: توی
// OnTick()، این تابع (از CheckClosedTrades()) قبل از RefreshEntryExitMarkers() اجرا می‌شه؛
// مهم‌تر از اون، RefreshEntryExitMarkers() فقط یک‌بار در هر کندل جدید rebuild می‌کنه (throttled)،
// نه هر تیک - پس فلش خروج معامله‌ای که وسط کندل بسته شده، تا کندل بعد اصلاً ساخته نمی‌شد. صبر
// کردن برای کندل بعد هم راه‌حل درستی نیست - چون تا اون موقع قیمت جابه‌جا شده و عکس دیگه دقیقاً
// وضعیت لحظه‌ی خروج رو نشون نمی‌ده.
//
// فیکس (۲ بخش، به‌هم وابسته):
// ۱) درست قبل از عکس، مستقیم BuildEntryExitMarkers() (نسخه‌ی کامل، نه throttled) صدا زده می‌شه -
//    چون این تیکت همین الان توی History هست (OrderSelect با MODE_HISTORY قبل از این تابع توی
//    CheckClosedTrades() موفق شده)، فلش خروج فوری ساخته می‌شه.
// ۲) اگه g_markersOn خاموش بود، موقتاً روشن می‌شه (تا فلش‌ها اصلاً وجود داشته باشن که عکس بگیره)،
//    عکس ثبت می‌شه، بعد دقیقاً به همون حالت خاموش برمی‌گرده (BuildEntryExitMarkers خودش idempotent
//    پاک می‌کنه وقتی g_markersOn=false باشه). اگه از قبل روشن بود، هیچ تغییری توی toggle داده
//    نمی‌شه - روشن می‌مونه. این تغییر موقت فقط روی متغیر حافظه‌ست، نه GlobalVariable ذخیره‌شده
//    (SaveEntryExitMarkersState صدا زده نمی‌شه) - پس وضعیت persisted دست‌نخورده می‌مونه و دکمه‌ی
//    داشبورد هیچ‌وقت واقعاً toggle نمی‌شه (این همه synchronous و بدون هیچ ChartRedraw میانی به
//    کاربر اتفاق می‌افته - بدون پرش بصری قابل مشاهده روی دکمه).
// v66 (آیتم ۱): تنها تغییر این تابع - مسیر عکس از اسم خام به ExitScreenshot_RelativePath() (شامل
// زیرپوشه‌ی TRADE SCREENSHOTS) تغییر کرد. منطق گرفتن عکس (چه لحظه‌ای، با چه محتوایی) دست‌نخورده.
void TakeExitScreenshot(int ticket)
{
   bool wasOn = g_markersOn;
   if(!wasOn)
      g_markersOn = true;  // موقت - فقط برای این عکس

   BuildEntryExitMarkers();  // rebuild فوری (نه throttled) - فلش خروج این تیکت رو تضمین می‌کنه

   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(w<=0) w = 1024;  // فال‌بک محافظه‌کارانه اگه بعضی ترمینال‌ها موقتاً ۰ برگردونن
   if(h<=0) h = 768;
   ChartScreenShot(0, ExitScreenshot_RelativePath(ticket), w, h, ALIGN_RIGHT);

   if(!wasOn)
   {
      g_markersOn = false;  // دقیقاً به همون حالت خاموش قبلی برگرد
      RemoveEntryExitMarkers();
   }
}

// v59 (Item 2، اتصال CSV): ExportTradeJournalCSV() (RM_Reports.mqh) از این استفاده می‌کنه - همون
// قرارداد فال‌بک "N/A" که GetTagStrategy/GetTagSetup هم دارن (اگه فایل عکس این تیکت روی دیسک
// وجود نداشته باشه - مثلاً معامله‌ای که قبل از نصب v59 بسته شده - "N/A" برمی‌گرده، نه یه اسم فایل
// ساختگی).
// v66 (آیتم ۱): مقدار برگشتی حالا مسیر نسبی کامل (پوشه+اسم فایل) است، نه فقط اسم فایل - تا از
// روی خودِ ستون CSV بشه مسیر واقعی روی دیسک رو پیدا کرد.
string GetExitScreenshotName(int ticket)
{
   string relPath = ExitScreenshot_RelativePath(ticket);
   if(FileIsExist(relPath)) return relPath;
   return "N/A";
}

//+------------------------------------------------------------------+
//| v56 (Trade Tagging - Strategy/Setup)                              |
//+------------------------------------------------------------------+
// هدف: امکان تگ‌گذاری هر معامله (حتی بعد از بسته‌شدن) با یک Strategy و یک Setup زیرمجموعه‌ی
// همون Strategy. چون OrderComment() بعد از close قابل ادیت نیست، این مکانیزم کاملاً مستقل از
// اون - دو فایل جدا توی MQL4/Files (نه GlobalVariable، طبق درخواست صریح تسک):
//   ۱. RM_StrategySetups.txt  - لیست سلسله‌مراتبی Strategy -> Setups (فرمت "NAME: setup1, setup2")
//   ۲. RM_TradeTags.csv       - نگاشت Ticket -> Strategy/Setup (مستقل از OrderComment، قابل ادیت در هر زمان)
// بدون هیچ تغییری در منطق ریسک/محاسبات/کولداون/Snapshot موجود - این فقط یه لایه‌ی تگ‌گذاری/UI
// جدیده، مصرف‌کننده‌ی همون OrdersTotal()/OrdersHistoryTotal() که بقیه‌ی جاهای پروژه هم می‌خونن.
//
// 🅿️ Parking Lot (v56.5، تصمیم صریح Mahmoud - "قبول ولی راضی نیستم از نظر کلاس کار، بعداً راه
// بهتر پیدا کنیم"): افزودن Strategy/Setup جدید فعلاً از طریق ادیت مستقیم فایل RM_StrategySetups.txt
// انجام می‌شه (نه تایپ داخل چارت) - چون OBJ_EDIT روی این پنل، برای فوکوس‌گرفتن نیاز به
// SELECTABLE=true داره، و همین property باعث می‌شه مستطیل با درگ هم جابه‌جا بشه و دابل‌کلیکش
// پنجره‌ی Properties خود MT4 رو باز کنه - در MT4 این دو رفتار (تعامل‌پذیری/جابه‌جاشدنی‌بودن) از
// هم جدا نیستن. این همون خانواده‌ی BUG-004 قدیمی پروژه‌ست (فیلد RR که با یه دکمه‌ی چرخشی
// جایگزین OBJ_EDIT شد، نه فیکس شد). راه‌حل بهتر (اگه پیدا شد) باید این محدودیت رو دور بزنه -
// مثلاً یه مکانیزم ورودی متفاوت که SELECTABLE نخواد.

#define STRAT_FILE_NAME "RM_StrategySetups.txt"
#define TAG_FILE_NAME   "RM_TradeTags.csv"
#define TAG_WIN_PREFIX  "RM_TAG_"

// --- Strategy -> Setups (سلسله‌مراتبی) ---
string g_stratNames[];      // اسم هر Strategy
string g_stratSetupsCSV[];  // موازی با بالا - رشته‌ی Setupهای همون Strategy، با ", " از هم جدا
int    g_stratCount = 0;

// --- Ticket -> Strategy/Setup (مستقل از OrderComment) ---
int    g_tagTickets[];
string g_tagStrategy[];
string g_tagSetup[];
string g_tagMentalState[];  // v69 (FEAT-026): موازی با بالا - اختیاری، می‌تونه همیشه "" باشه
int    g_tagCount = 0;

// --- وضعیت پنجره‌ی تگ‌گذاری (UI روی چارت، پیشوند جدا از پنل اصلی RM9_) ---
bool   g_tagWindowOpen      = false;
int    g_tagStep            = 0;   // FEAT-037 (v81): 0=انتخاب معامله، 1=چک‌لیست کانتکست (جدید)، 2=انتخاب Strategy، 3=انتخاب Setup (+ Mental State اختیاری زیرش)
int    g_tagSelectedTicket  = -1;
string g_tagSelectedStrategy = "";
// v69 (FEAT-026 - Mental State Tag): انتخاب فعلی Mental State توی همین سشن پنجره‌ی تگ‌گذاری -
// کاملاً اختیاری، هیچ reminder/هشداری بهش وابسته نیست. مثل g_tagSelectedStrategy، فقط توی
// OpenTagWindow() ریست می‌شه (نه با دکمه‌ی BACK) - رفتار یکسان با بقیه‌ی state این پنجره.
string g_tagSelectedMentalState = "";
// FEAT-037 (v81 - چک‌لیست کانتکست): انتخاب فعلی هر ۵ چک‌باکس توی همین سشن پنجره‌ی تگ‌گذاری -
// دقیقاً هم‌الگوی g_tagSelectedMentalState بالا (فقط توی OpenTagWindow() ریست می‌شه، نه با BACK؛
// موقع انتخاب یه معامله از مقدار persisted همون تیکت لود می‌شه). پیش‌فرض هر ۵ تا false - طبق تسک.
bool   g_ctxSelLevel  = false;
bool   g_ctxSelCycle  = false;
bool   g_ctxSelTime   = false;
bool   g_ctxSelCandle = false;
bool   g_ctxSelNone   = false;
// v56.5: g_tagStratEditBuffer/g_tagSetupEditBuffer حذف شدن - دیگه هیچ OBJ_EDIT ای توی این
// پنجره نیست (ببین توضیح کامل بالای OpenTagWindow()).
// v80 (BUG-056): زمان (GetTickCount) آخرین OBJECT_CLICK روی پنجره‌ی تگ‌گذاری - برای نادیده‌گرفتن
// CHARTEVENT_CLICK دوقلوی همون کلیک در چک «کلیک بیرون پنجره» (RiskManager_EA_v80.mq4، OnChartEvent).
#define TAG_OBJCLICK_GUARD_MS 400
uint   g_tagLastObjClickMs = 0;
int    g_tagTodayTickets[]; // ایندکسش با دکمه‌های TAG_WIN_PREFIX+"TRADE_"+i هم‌راستاست (پر می‌شه توسط BuildTodayTicketList)

// v56: کاراکترهای جداکننده‌ی خود فرمت فایل (کاما/دونقطه) از متن آزاد تایپی تریدر حذف می‌شن -
// وگرنه یه اسم Strategy/Setup حاوی کاما یا دونقطه فرمت "NAME: s1, s2" یا "ticket,strategy,setup"
// رو به‌هم می‌ریزه. جایگزینی امن (به‌جای رد کردن ورودی) چون این یه محدودیت فرمت فایله، نه قانون تجاری.
// v56.5: فعلاً هیچ‌جا صدا زده نمی‌شه (مسیر تایپ داخل چارت کنار گذاشته شد - ببین Parking Lot بالا)،
// ولی نگه داشته شده - وقتی راه‌حل بهتری برای ورودی متنی پیدا شد، همین جا آماده‌ست.
string SanitizeTagText(string s)
{
   StringReplace(s, ",", "");
   StringReplace(s, ":", "");
   return s;
}

//+------------------------------------------------------------------+
// فایل ۱: Strategy -> Setups
//+------------------------------------------------------------------+
void SaveStrategySetupsFile()
{
   int handle = FileOpen(STRAT_FILE_NAME, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("RM_Tools: SaveStrategySetupsFile - FileOpen failed, error ", GetLastError());
      return;
   }
   for(int i=0;i<g_stratCount;i++)
      FileWrite(handle, g_stratNames[i] + ": " + g_stratSetupsCSV[i]);
   FileClose(handle);
}

void LoadStrategySetupsFile()
{
   ArrayResize(g_stratNames, 0);
   ArrayResize(g_stratSetupsCSV, 0);
   g_stratCount = 0;

   int handle = FileOpen(STRAT_FILE_NAME, FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) return; // فایل هنوز وجود نداره - EnsureStrategySetupsSeed() این حالت رو قبلش مدیریت می‌کنه

   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      StringTrimLeft(line); StringTrimRight(line);
      if(line=="") continue;

      int colonPos = StringFind(line, ":");
      if(colonPos<0) continue; // خط بدون فرمت درست - نادیده گرفته می‌شه

      string name = StringSubstr(line, 0, colonPos);
      string rest = StringSubstr(line, colonPos+1);
      StringTrimLeft(name);  StringTrimRight(name);
      StringTrimLeft(rest);  StringTrimRight(rest);
      if(name=="") continue;

      ArrayResize(g_stratNames,     g_stratCount+1);
      ArrayResize(g_stratSetupsCSV, g_stratCount+1);
      g_stratNames[g_stratCount]     = name;
      g_stratSetupsCSV[g_stratCount] = rest;
      g_stratCount++;
   }
   FileClose(handle);
}

// اگه فایل هنوز وجود نداره (اولین اجرا)، با seed مشخص‌شده در تسک ساخته می‌شه؛ در غیر این صورت
// فقط لود می‌شه (افزودن‌های قبلی تریدر دست‌نخورده می‌مونن - این تابع هیچ‌وقت overwrite نمی‌کنه
// اگه فایل از قبل باشه).
#define STRAT_LIST_VERSION      106   // v106 (STRAT-LIST): 80 -> 106؛ مهاجرت یک‌باره‌ی لیست (با بکاپ) روی هر ترمینال
#define GV_STRAT_LIST_VERSION   "RM_StratListVer"   // ترمینال‌محور (نه حساب‌محور): فایل هم مشترک بین حساب‌های همین ترمینال است

// لیست پیش‌فرض (v80، BUG-056) - تنها منبع؛ هم seed اولیه هم مهاجرت یک‌باره از این می‌نویسن.
void WriteDefaultStrategySetups()
{
   int handle = FileOpen(STRAT_FILE_NAME, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("RM_Tools: WriteDefaultStrategySetups - FileOpen failed, error ", GetLastError());
      return;
   }
   // v106 (STRAT-LIST): لیست جدید (۴ استراتژی)، جایگزین ۶ خط قبلی
   FileWrite(handle, "CYCLE_MATURITY: REJECTION_CANDLE, MTR_PB, MTR_LINE_BREAK, MTR_BREAKEVEN_RETEST");
   FileWrite(handle, "SPIKE_TRADING: BREAKOUT_CANDLE, SP2L_FIRST_PB_CANDLE, SP2L_50, BTB");
   FileWrite(handle, "CHANNEL_TRADING: TREND_LINE_TOUCH, PREVIOUS_LEG_50, REJECTION_CANDLE");
   FileWrite(handle, "RANGE_TRADING: EDGE_LIMIT, REJECTION_CANDLE");
   FileClose(handle);
}

// v80: فایل وجود نداره -> با لیست پیش‌فرض ساخته می‌شه. فایل وجود داره ولی نسخه‌ی لیست (GV) قدیمی‌تر
// از v80 است (یعنی هنوز لیست قبلی) -> *یک‌بار* با لیست جدید جایگزین می‌شه (نسخه‌ی قبلی به
// RM_StrategySetups_backup.txt کپی می‌شه) و GV ثبت می‌شه. از اون به بعد ادیت‌های دستی دست‌نخورده
// می‌مونن (مثل رفتار عمدی v56 - هیچ‌وقت هر اجرا overwrite نمی‌کنه).
void EnsureStrategySetupsSeed()
{
   bool haveVer = GlobalVariableCheck(GV_STRAT_LIST_VERSION) && (int)GlobalVariableGet(GV_STRAT_LIST_VERSION) >= STRAT_LIST_VERSION;

   if(!FileIsExist(STRAT_FILE_NAME))
   {
      WriteDefaultStrategySetups();
      GlobalVariableSet(GV_STRAT_LIST_VERSION, STRAT_LIST_VERSION);
   }
   else if(!haveVer)
   {
      if(!FileCopy(STRAT_FILE_NAME, 0, "RM_StrategySetups_backup.txt", FILE_REWRITE))
         Print("RM_Tools: strategy list backup failed, error ", GetLastError());
      WriteDefaultStrategySetups();
      GlobalVariableSet(GV_STRAT_LIST_VERSION, STRAT_LIST_VERSION);
      Print("RM_Tools: strategy list migrated to v", STRAT_LIST_VERSION, " default (old file backed up to RM_StrategySetups_backup.txt)");
   }
   LoadStrategySetupsFile();
}

int FindStrategyIndex(string name)
{
   for(int i=0;i<g_stratCount;i++)
      if(g_stratNames[i]==name) return i;
   return -1;
}

// می‌سازه اگه از قبل نبود (و فایل رو ذخیره می‌کنه)، وگرنه فقط index موجود رو برمی‌گردونه.
// v56.5: این تابع و AddSetupIfMissing زیرش فعلاً از هیچ‌جای UI صدا زده نمی‌شن (مسیر تایپ داخل
// چارت کنار گذاشته شد - ببین Parking Lot بالای فایل)، ولی به‌عنوان API آماده نگه داشته شدن -
// اگه بعداً یه مکانیزم ورودی جایگزین پیدا شد، این دو تابع همون منطق افزودن رو پوشش می‌دن.
int AddStrategyIfMissing(string name)
{
   if(name=="") return -1;
   int idx = FindStrategyIndex(name);
   if(idx>=0) return idx;

   ArrayResize(g_stratNames,     g_stratCount+1);
   ArrayResize(g_stratSetupsCSV, g_stratCount+1);
   g_stratNames[g_stratCount]     = name;
   g_stratSetupsCSV[g_stratCount] = "";
   g_stratCount++;
   SaveStrategySetupsFile();
   return g_stratCount-1;
}

// لیست Setupهای یک Strategy رو (trim‌شده، خالی‌ها حذف) توی آرایه‌ی out پر می‌کنه و تعدادش رو برمی‌گردونه.
int GetSetupsForStrategy(string stratName, string &out[])
{
   ArrayResize(out, 0);
   int idx = FindStrategyIndex(stratName);
   if(idx<0 || g_stratSetupsCSV[idx]=="") return 0;

   string parts[];
   int n = StringSplit(g_stratSetupsCSV[idx], ',', parts);
   int cnt=0;
   for(int i=0;i<n;i++)
   {
      string s = parts[i];
      StringTrimLeft(s); StringTrimRight(s);
      if(s=="") continue;
      ArrayResize(out, cnt+1);
      out[cnt] = s;
      cnt++;
   }
   return cnt;
}

// اگه Setup از قبل زیر این Strategy نباشه، اضافه‌اش می‌کنه (و فایل رو ذخیره می‌کنه). اگه خود
// Strategy هم هنوز نباشه (نباید پیش بیاد چون UI همیشه قبلش تضمینش می‌کنه)، اول اون رو هم می‌سازه.
void AddSetupIfMissing(string stratName, string setupName)
{
   if(setupName=="") return;

   int idx = FindStrategyIndex(stratName);
   if(idx<0) idx = AddStrategyIfMissing(stratName);
   if(idx<0) return;

   string existing[];
   int n = GetSetupsForStrategy(stratName, existing);
   for(int i=0;i<n;i++)
      if(existing[i]==setupName) return; // از قبل هست - دوباره اضافه نمی‌شه

   if(g_stratSetupsCSV[idx]=="") g_stratSetupsCSV[idx] = setupName;
   else                          g_stratSetupsCSV[idx] = g_stratSetupsCSV[idx] + ", " + setupName;

   SaveStrategySetupsFile();
}

//+------------------------------------------------------------------+
// v101 (BUG-054 خانواده‌ی «حالت مشترک» - تگ‌ها): آرایه‌های تگ (g_tag*/g_ctxTag*) فقط در OnInit از فایل CSV به حافظه‌ی هر
// نمونه لود می‌شدند و ذخیره‌ی تگ، *کل فایل* را از روی همان آرایه‌ی حافظه بازنویسی می‌کرد. نتیجه: (۱) تگی که روی چارت A
// زده می‌شد روی چارت B بدون ری‌استارت «تگ‌نخورده» می‌ماند (هشدار قرمز + Export ناقص)، (۲) بدتر: اگر روی B هم تگی زده
// می‌شد، فایل از روی حافظه‌ی کهنه‌ی B نوشته می‌شد و تگ A *پاک* می‌شد (lost update).
// راه‌حل (بدون I/O هر تیک): یک شمارنده‌ی نسخه‌ی GV (ترمینال‌محور - خود فایل‌ها هم ترمینال‌محورند) که هر Save بالا می‌برد؛ هر
// نمونه هر تیک فقط آن را (GlobalVariableGet، حافظه) با آخرین نسخه‌ی دیده‌شده مقایسه می‌کند و *فقط اگر عوض شده بود* فایل را
// دوباره می‌خواند. جدا از آن، قبل از هر تغییر/ذخیره‌ی تگ (رویداد کاربر، نادر) فایل همیشه تازه خوانده می‌شود (read-modify-write).
//+------------------------------------------------------------------+
#define GV_TAGFILE_VER    "RM_TagFileVer"
#define GV_CTXTAGFILE_VER "RM_CtxTagFileVer"
double g_tagVerSeen    = -1.0;
double g_ctxTagVerSeen = -1.0;

// بازکردن فایل با چند تلاش کوتاه (نمونه‌ی دیگر ممکن است لحظه‌ای در حال نوشتن باشد) و flagهای اشتراک خواندن/نوشتن
int RM_OpenSharedFile(string name, bool forWrite)
{
   int flags = forWrite ? (FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ) : (FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   int h = INVALID_HANDLE;
   for(int t=0; t<5; t++)
   {
      h = FileOpen(name, flags);
      if(h != INVALID_HANDLE) return h;
      if(!forWrite && !FileIsExist(name)) return INVALID_HANDLE;  // فایل اصلاً وجود ندارد - تلاش مجدد بی‌معنی
      Sleep(10);
   }
   return INVALID_HANDLE;
}

void RM_BumpTagVersion(string gvKey, double &seenVar)
{
   double prevSeen = seenVar;
   double v = CAS_AddToGlobal(gvKey, 1.0);
   if(prevSeen >= 0.0 && v == prevSeen + 1.0) seenVar = v;  // نمونه‌ی دیگری بین آخرین sync و این Save ننوشته؛ وگرنه sync بعدی دوباره می‌خواند
}

//+------------------------------------------------------------------+
// فایل ۲: Ticket -> Strategy/Setup
//+------------------------------------------------------------------+
void SaveTradeTagsFile()
{
   int handle = RM_OpenSharedFile(TAG_FILE_NAME, true);
   if(handle == INVALID_HANDLE)
   {
      Print("RM_Tools: SaveTradeTagsFile - FileOpen failed, error ", GetLastError());
      return;
   }
   // v69 (FEAT-026): ستون چهارم MentalState اضافه شد - اختیاری، اگه انتخاب نشده بود رشته‌ی
   // خالی ذخیره می‌شه (نه "N/A" - همون قرارداد Strategy/Setup که مقدار خام رو ذخیره می‌کنن و
   // فال‌بک "N/A" فقط لحظه‌ی خوندن/Export انجام می‌شه، نه لحظه‌ی ذخیره).
   FileWrite(handle, "Ticket,Strategy,Setup,MentalState");
   for(int i=0;i<g_tagCount;i++)
      FileWrite(handle, IntegerToString(g_tagTickets[i]) + "," + g_tagStrategy[i] + "," + g_tagSetup[i] + "," + g_tagMentalState[i]);
   FileClose(handle);
   RM_BumpTagVersion(GV_TAGFILE_VER, g_tagVerSeen);  // v101: نمونه‌های دیگر فایل را دوباره بخوانند
}

void LoadTradeTagsFile()
{
   // v101: اول فایل باز می‌شود، بعد آرایه‌ها خالی می‌شوند - اگر باز نشد (قفل لحظه‌ای نمونه‌ی دیگر) حافظه‌ی فعلی دست‌نخورده
   // می‌ماند (قبلاً اول خالی می‌شد و شکست باز کردن = «همه‌ی تگ‌ها پاک» تا ری‌استارت بعدی).
   int handle = RM_OpenSharedFile(TAG_FILE_NAME, false);
   if(handle == INVALID_HANDLE) return; // فایل هنوز وجود نداره - یعنی هنوز هیچ تیکتی تگ نخورده
   ArrayResize(g_tagTickets,     0);
   ArrayResize(g_tagStrategy,    0);
   ArrayResize(g_tagSetup,       0);
   ArrayResize(g_tagMentalState, 0);  // v69 (FEAT-026)
   g_tagCount = 0;

   bool firstLine = true;
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      StringTrimLeft(line); StringTrimRight(line);
      if(line=="") continue;

      if(firstLine)
      {
         firstLine = false;
         if(StringFind(line, "Ticket") == 0) continue; // خط هدر - رد می‌شه
      }

      string parts[];
      int n = StringSplit(line, ',', parts);
      if(n<3) continue;

      int ticket = (int)StringToInteger(parts[0]);
      if(ticket<=0) continue;

      // v69 (FEAT-026): فایل‌های قدیمی‌تر از v69 فقط ۳ ستون دارن (بدون MentalState) - برای
      // سازگاری عقب‌رو، اگه ستون چهارم موجود نبود مقدار خالی فرض می‌شه (نه خطا/رد کردن خط).
      string mentalState = (n>=4) ? parts[3] : "";

      ArrayResize(g_tagTickets,     g_tagCount+1);
      ArrayResize(g_tagStrategy,    g_tagCount+1);
      ArrayResize(g_tagSetup,       g_tagCount+1);
      ArrayResize(g_tagMentalState, g_tagCount+1);
      g_tagTickets[g_tagCount]     = ticket;
      g_tagStrategy[g_tagCount]    = parts[1];
      g_tagSetup[g_tagCount]       = parts[2];
      g_tagMentalState[g_tagCount] = mentalState;
      g_tagCount++;
   }
   FileClose(handle);
}

// v86 (FEAT-042 فاز ۱): جستوجوی دقیق (بدون map به ریشه) - فقط برای داخل همین فایل.
int FindTagIndexExact(int ticket)
{
   for(int i=0;i<g_tagCount;i++)
      if(g_tagTickets[i]==ticket) return i;
   return -1;
}

// v86 (FEAT-042 فاز ۱): خواندن تگ از ریشه‌ی زنجیره. ابتدا ریشه؛ اگر روی ریشه تگی نبود ولی روی خودِ تیکت (فرزند) تگ قدیمی
// ثبت شده بود (کپی v60 در Half Close)، همان خوانده می‌شود تا تگ‌های قدیمی از بین نروند.
int FindTagIndex(int ticket)
{
   int root = GetRootTicket(ticket);
   int idx = FindTagIndexExact(root);
   if(idx >= 0 || root == ticket) return idx;
   return FindTagIndexExact(ticket);
}

// تگ یه تیکت رو ست/آپدیت می‌کنه (قابل ادیت در هر زمان - retag یه تیکت از قبل تگ‌خورده هم همینجا
// پوشش داده می‌شه) و فایل رو ذخیره می‌کنه.
// v69 (FEAT-026): پارامتر چهارم mentalState اضافه شد - اختیاری (پیش‌فرض "")، پس کالرهای قدیمی‌تر
// (اگه جایی خارج از این نسخه مونده باشن) بدون تغییر کامپایل می‌شن.
void SetTradeTag(int ticket, string strategy, string setup, string mentalState="")
{
   // v86 (FEAT-042 فاز ۱): نوشتن همیشه روی ریشه - ویرایش تگ یک‌بار برای کل زنجیره (تگ قدیمیِ روی فرزند دست‌نخورده می‌ماند ولی
   // چون خواندن ریشه‌محور است، اولویت با ریشه است).
   RM_EnsureSnapshot(ticket);   // v101: ریشه‌ی درست (GetRootTicket) برای تیکتی که روی چارت دیگر ساخته شده
   ticket = GetRootTicket(ticket);
   LoadTradeTagsFile();         // v101: read-modify-write - حافظه‌ی کهنه فایل را بازنویسی (و تگ نمونه‌ی دیگر را پاک) نکند
   int idx = FindTagIndexExact(ticket);
   if(idx>=0)
   {
      g_tagStrategy[idx]    = strategy;
      g_tagSetup[idx]       = setup;
      g_tagMentalState[idx] = mentalState;
   }
   else
   {
      ArrayResize(g_tagTickets,     g_tagCount+1);
      ArrayResize(g_tagStrategy,    g_tagCount+1);
      ArrayResize(g_tagSetup,       g_tagCount+1);
      ArrayResize(g_tagMentalState, g_tagCount+1);
      g_tagTickets[g_tagCount]     = ticket;
      g_tagStrategy[g_tagCount]    = strategy;
      g_tagSetup[g_tagCount]       = setup;
      g_tagMentalState[g_tagCount] = mentalState;
      g_tagCount++;
   }
   SaveTradeTagsFile();
}

// v56: این دو تابع مستقیماً از ExportTradeJournalCSV() (v55، RM_Reports.mqh) صدا زده می‌شن تا
// ستون‌های Strategy/Setup به CSV اضافه بشن. برای تیکت بدون تگ -> "N/A"، هم‌راستا با فال‌بک موجود
// برای Snapshotهای نامعتبر (همون قرارداد قبلی، نه یه قرارداد جدید).
string GetTagStrategy(int ticket) { int idx=FindTagIndex(ticket); return (idx>=0) ? g_tagStrategy[idx] : "N/A"; }
string GetTagSetup(int ticket)    { int idx=FindTagIndex(ticket); return (idx>=0) ? g_tagSetup[idx]    : "N/A"; }

// v69 (FEAT-026 - Mental State Tag): دو نسخه، هم‌رده‌ی همون تفکیک PriorDayResult (کد خام در
// برابر رشته‌ی نمایشی). GetTagMentalStateRaw مقدار خام رو برمی‌گردونه (رشته‌ی خالی اگه انتخاب
// نشده - چه تیکت اصلاً تگ نخورده باشه چه تگ خورده ولی این فیلد رو خالی گذاشته باشه) - این نسخه
// برای وراثت به تیکت باقیمونده‌ی Half Close استفاده می‌شه (RM_TradeExecution.mqh) تا وضعیت
// «انتخاب نشده» درست منتقل بشه، نه رشته‌ی نمایشی "N/A". GetTagMentalState نسخه‌ی نمایشی/Export
// است - دقیقاً طبق تسک: اگه خالی بود "N/A" برگردون (نه رشته‌ی خالی توی CSV).
string GetTagMentalStateRaw(int ticket) { int idx=FindTagIndex(ticket); return (idx>=0) ? g_tagMentalState[idx] : ""; }
string GetTagMentalState(int ticket)
{
   string raw = GetTagMentalStateRaw(ticket);
   return (raw=="") ? "N/A" : raw;
}

// v69 (FEAT-026): لیست ثابت ۶ گزینه‌ی Mental State - یه جا تعریف شده و هم توی BuildTagWindow()
// (رسم دکمه‌ها) هم توی دیسپچ کلیک (RiskManager_EA_v69.mq4) استفاده می‌شه، تا متن دکمه‌ها و
// نگاشت index->متن همیشه دقیقاً هم‌راستا بمونن (بدون دو نسخه‌ی جدا از همون لیست که ممکنه از هم
// جدا بیفتن).
// v69.1 (فیدبک Mahmoud): برچسب‌ها از فارسی به انگلیسی کوتاه تغییر کردن - چون دکمه‌ها یک‌سومِ
// عرض پنل‌ان (همون تنگی که MONTHLY H/L رو مجبور کرد به M H/L کوتاه بشه، RM_Dashboard.mqh)، و
// حروف فارسی معمولاً از انگلیسی در همون اندازه‌ی فونت پهن‌ترن - عبارت‌های اصلی (آرام/مطمئن و
// بقیه) توی این پهنا بیرون می‌زدن. هر ۶ برچسب زیر یک کلمه‌ای/کوتاه نگه داشته شدن.
int GetMentalStateOptions(string &out[])
{
   ArrayResize(out, 6);
   out[0] = "Calm";
   out[1] = "Rushed";
   out[2] = "Stressed";
   out[3] = "Tired";
   out[4] = "Revenge";
   out[5] = "Overconf";
   return 6;
}

//+------------------------------------------------------------------+
//| FEAT-037 (v81) - چک‌لیست کانتکست پنج‌گزینه‌ای                        |
//+------------------------------------------------------------------+
// هدف: قبل از مراحل فعلی Tag Trade (Strategy->Setup->Mental State)، یه مرحله‌ی جدید و کاملاً
// مستقل - ۵ چک‌باکس مسطح، چندانتخابی (صفر تا هر تعداد). طبق تسک، این ماژول عمداً از کد فعلی
// Tag Trade کپی/وابسته نشده - دو فایل کاملاً جدا (مستقل از RM_StrategySetups.txt/RM_TradeTags.csv):
//   ۱. RM_ContextChecklist.txt - متن نمایشی ۵ گزینه (قابل‌ویرایش، الگوی seed/migration یکسان با
//      RM_StrategySetups.txt، ولی فایل/نسخه/GV کاملاً جدا)
//   ۲. RM_ContextTags.csv      - نگاشت Ticket -> ۵ Boolean (مستقل از RM_TradeTags.csv)
#define CTX_FILE_NAME      "RM_ContextChecklist.txt"
#define CTX_TAG_FILE_NAME  "RM_ContextTags.csv"

// ترتیب ثابت کلیدها (هیچ‌وقت از فایل خونده نمی‌شه - فقط متن نمایشی هر کلید از فایل میاد):
// 0=LEVEL (سطح کلیدی), 1=CYCLE (شفافیت سایکلی), 2=TIME (زمان کلیدی), 3=CANDLE (الگوی تأیید کندلی),
// 4=NONE (بدون تأیید چک‌لیستی - کاتچ‌آل)
string g_ctxLabels[5];

void CTX_SetDefaultLabels()
{
   g_ctxLabels[0] = "Key Level";
   g_ctxLabels[1] = "Cycle Clarity";
   g_ctxLabels[2] = "Key Time";
   g_ctxLabels[3] = "Candle Confirmation";
   g_ctxLabels[4] = "No Checklist Confirmation";
}

int CTX_KeyIndex(string key)
{
   if(key=="LEVEL")  return 0;
   if(key=="CYCLE")  return 1;
   if(key=="TIME")   return 2;
   if(key=="CANDLE") return 3;
   if(key=="NONE")   return 4;
   return -1;
}

void WriteDefaultContextChecklist()
{
   int handle = FileOpen(CTX_FILE_NAME, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("RM_Tools: WriteDefaultContextChecklist - FileOpen failed, error ", GetLastError());
      return;
   }
   FileWrite(handle, "LEVEL: Key Level");
   FileWrite(handle, "CYCLE: Cycle Clarity");
   FileWrite(handle, "TIME: Key Time");
   FileWrite(handle, "CANDLE: Candle Confirmation");
   FileWrite(handle, "NONE: No Checklist Confirmation");
   FileClose(handle);
}

void LoadContextChecklistFile()
{
   CTX_SetDefaultLabels();  // فال‌بک - اگه فایل نبود یا یه کلید توش نبود، همین پیش‌فرض می‌مونه

   int handle = FileOpen(CTX_FILE_NAME, FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) return;  // فایل هنوز نیست - EnsureContextChecklistSeed() این حالت رو قبلش مدیریت می‌کنه

   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      StringTrimLeft(line); StringTrimRight(line);
      if(line=="") continue;

      int colonPos = StringFind(line, ":");
      if(colonPos<0) continue;

      string key  = StringSubstr(line, 0, colonPos);
      string text = StringSubstr(line, colonPos+1);
      StringTrimLeft(key);  StringTrimRight(key);
      StringTrimLeft(text); StringTrimRight(text);
      if(text=="") continue;

      int idx = CTX_KeyIndex(key);
      if(idx>=0) g_ctxLabels[idx] = text;
   }
   FileClose(handle);
}

#define CTX_CHECKLIST_VERSION    81
#define GV_CTX_CHECKLIST_VERSION "RM_CtxChecklistVer"   // ترمینال‌محور، هم‌الگوی GV_STRAT_LIST_VERSION

// همون منطق EnsureStrategySetupsSeed() بالا - فایل نیست -> با seed ساخته می‌شه؛ فایل قدیمی‌تر از
// این نسخه -> یه‌بار بکاپ+جایگزینی؛ وگرنه دست‌نخورده لود می‌شه (ادیت دستی کاربر همیشه محفوظه).
void EnsureContextChecklistSeed()
{
   bool haveVer = GlobalVariableCheck(GV_CTX_CHECKLIST_VERSION) && (int)GlobalVariableGet(GV_CTX_CHECKLIST_VERSION) >= CTX_CHECKLIST_VERSION;

   if(!FileIsExist(CTX_FILE_NAME))
   {
      WriteDefaultContextChecklist();
      GlobalVariableSet(GV_CTX_CHECKLIST_VERSION, CTX_CHECKLIST_VERSION);
   }
   else if(!haveVer)
   {
      if(!FileCopy(CTX_FILE_NAME, 0, "RM_ContextChecklist_backup.txt", FILE_REWRITE))
         Print("RM_Tools: context checklist backup failed, error ", GetLastError());
      WriteDefaultContextChecklist();
      GlobalVariableSet(GV_CTX_CHECKLIST_VERSION, CTX_CHECKLIST_VERSION);
      Print("RM_Tools: context checklist migrated to v", CTX_CHECKLIST_VERSION, " default (old file backed up to RM_ContextChecklist_backup.txt)");
   }
   LoadContextChecklistFile();
}

// --- فایل ۲: Ticket -> ۵ Boolean (کاملاً مستقل از g_tagTickets/RM_TradeTags.csv) ---
int  g_ctxTagTickets[];
bool g_ctxTagLevel[];
bool g_ctxTagCycle[];
bool g_ctxTagTime[];
bool g_ctxTagCandle[];
bool g_ctxTagNone[];
int  g_ctxTagCount = 0;

void SaveContextTagsFile()
{
   int handle = RM_OpenSharedFile(CTX_TAG_FILE_NAME, true);
   if(handle == INVALID_HANDLE)
   {
      Print("RM_Tools: SaveContextTagsFile - FileOpen failed, error ", GetLastError());
      return;
   }
   FileWrite(handle, "Ticket,ContextLevelOK,ContextCycleClarityOK,ContextTimeOK,ContextCandleConfirmOK,ContextNone");
   for(int i=0;i<g_ctxTagCount;i++)
      FileWrite(handle, IntegerToString(g_ctxTagTickets[i]) + "," +
                (g_ctxTagLevel[i]  ? "1":"0") + "," +
                (g_ctxTagCycle[i]  ? "1":"0") + "," +
                (g_ctxTagTime[i]   ? "1":"0") + "," +
                (g_ctxTagCandle[i] ? "1":"0") + "," +
                (g_ctxTagNone[i]   ? "1":"0"));
   FileClose(handle);
   RM_BumpTagVersion(GV_CTXTAGFILE_VER, g_ctxTagVerSeen);  // v101
}

void LoadContextTagsFile()
{
   int handle = RM_OpenSharedFile(CTX_TAG_FILE_NAME, false);   // v101: اول باز می‌شود، بعد آرایه‌ها خالی (همان دلیل LoadTradeTagsFile)
   if(handle == INVALID_HANDLE) return;  // هنوز هیچ تیکتی چک‌لیست نخورده
   ArrayResize(g_ctxTagTickets, 0);
   ArrayResize(g_ctxTagLevel,   0);
   ArrayResize(g_ctxTagCycle,   0);
   ArrayResize(g_ctxTagTime,    0);
   ArrayResize(g_ctxTagCandle,  0);
   ArrayResize(g_ctxTagNone,    0);
   g_ctxTagCount = 0;

   bool firstLine = true;
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      StringTrimLeft(line); StringTrimRight(line);
      if(line=="") continue;

      if(firstLine)
      {
         firstLine = false;
         if(StringFind(line, "Ticket") == 0) continue;
      }

      string parts[];
      int n = StringSplit(line, ',', parts);
      if(n<6) continue;

      int ticket = (int)StringToInteger(parts[0]);
      if(ticket<=0) continue;

      ArrayResize(g_ctxTagTickets, g_ctxTagCount+1);
      ArrayResize(g_ctxTagLevel,   g_ctxTagCount+1);
      ArrayResize(g_ctxTagCycle,   g_ctxTagCount+1);
      ArrayResize(g_ctxTagTime,    g_ctxTagCount+1);
      ArrayResize(g_ctxTagCandle,  g_ctxTagCount+1);
      ArrayResize(g_ctxTagNone,    g_ctxTagCount+1);
      g_ctxTagTickets[g_ctxTagCount] = ticket;
      g_ctxTagLevel[g_ctxTagCount]   = (parts[1]=="1");
      g_ctxTagCycle[g_ctxTagCount]   = (parts[2]=="1");
      g_ctxTagTime[g_ctxTagCount]    = (parts[3]=="1");
      g_ctxTagCandle[g_ctxTagCount]  = (parts[4]=="1");
      g_ctxTagNone[g_ctxTagCount]    = (parts[5]=="1");
      g_ctxTagCount++;
   }
   FileClose(handle);
}

// v86 (FEAT-042 فاز ۱): همان الگوی FindTagIndex برای چک‌لیست کانتکست - جستجوی دقیق + نسخه‌ی ریشه‌محور با فال‌بک.
int FindCtxTagIndexExact(int ticket)
{
   for(int i=0;i<g_ctxTagCount;i++)
      if(g_ctxTagTickets[i]==ticket) return i;
   return -1;
}

int FindCtxTagIndex(int ticket)
{
   int root = GetRootTicket(ticket);
   int idx = FindCtxTagIndexExact(root);
   if(idx >= 0 || root == ticket) return idx;
   return FindCtxTagIndexExact(ticket);
}

// تگ چک‌لیست یه تیکت رو ست/آپدیت می‌کنه (هر ۵ فیلد با هم - این مرحله همیشه هر ۵ تا رو با هم
// می‌فرسته، برخلاف Strategy/Setup که تدریجی‌ان) و فایل رو ذخیره می‌کنه.
void SetContextTag(int ticket, bool bLevel, bool bCycle, bool bTime, bool bCandle, bool bNone)
{
   RM_EnsureSnapshot(ticket);       // v101: ریشه‌ی درست برای تیکتی که روی چارت دیگر ساخته شده
   ticket = GetRootTicket(ticket);  // v86 (FEAT-042 فاز ۱): نوشتن روی ریشه
   LoadContextTagsFile();           // v101: read-modify-write (همان دلیل SetTradeTag)
   int idx = FindCtxTagIndexExact(ticket);
   if(idx>=0)
   {
      g_ctxTagLevel[idx]  = bLevel;
      g_ctxTagCycle[idx]  = bCycle;
      g_ctxTagTime[idx]   = bTime;
      g_ctxTagCandle[idx] = bCandle;
      g_ctxTagNone[idx]   = bNone;
   }
   else
   {
      ArrayResize(g_ctxTagTickets, g_ctxTagCount+1);
      ArrayResize(g_ctxTagLevel,   g_ctxTagCount+1);
      ArrayResize(g_ctxTagCycle,   g_ctxTagCount+1);
      ArrayResize(g_ctxTagTime,    g_ctxTagCount+1);
      ArrayResize(g_ctxTagCandle,  g_ctxTagCount+1);
      ArrayResize(g_ctxTagNone,    g_ctxTagCount+1);
      g_ctxTagTickets[g_ctxTagCount] = ticket;
      g_ctxTagLevel[g_ctxTagCount]   = bLevel;
      g_ctxTagCycle[g_ctxTagCount]   = bCycle;
      g_ctxTagTime[g_ctxTagCount]    = bTime;
      g_ctxTagCandle[g_ctxTagCount]  = bCandle;
      g_ctxTagNone[g_ctxTagCount]    = bNone;
      g_ctxTagCount++;
   }
   SaveContextTagsFile();
}

// v101: هر تیک صدا زده می‌شود (OnTick) و در لحظه‌ی باز شدن پنجره‌ی تگ/Export. فقط دو GlobalVariableGet؛ فایل فقط وقتی نسخه
// عوض شده باشد خوانده می‌شود (یعنی نمونه‌ی دیگری تگ ذخیره کرده).
void RM_SyncTagsIfChanged()
{
   double v1 = GlobalVariableCheck(GV_TAGFILE_VER)    ? GlobalVariableGet(GV_TAGFILE_VER)    : 0.0;
   if(v1 != g_tagVerSeen)
   {
      bool firstSeen = (g_tagVerSeen < 0.0);   // اولین بار بعد از OnInit: خودِ OnInit فایل را خوانده؛ فقط نسخه را ثبت کن
      g_tagVerSeen = v1;
      if(!firstSeen)
      {
         LoadTradeTagsFile();
         Print("[RM-MI] tags refreshed (file changed) on ", RM_InstTag());
      }
   }
   double v2 = GlobalVariableCheck(GV_CTXTAGFILE_VER) ? GlobalVariableGet(GV_CTXTAGFILE_VER) : 0.0;
   if(v2 != g_ctxTagVerSeen)
   {
      bool firstSeen2 = (g_ctxTagVerSeen < 0.0);
      g_ctxTagVerSeen = v2;
      if(!firstSeen2)
      {
         LoadContextTagsFile();
         Print("[RM-MI] tags refreshed (file changed) on ", RM_InstTag(), " [context checklist]");
      }
   }
}

// گترهای Boolean (برای پرلود سشن پنجره‌ی تگ‌گذاری، موقع انتخاب یه معامله - پیش‌فرض false اگه
// تگ نخورده، طبق تسک: "تریدی که چک‌لیست برایش انجام نشد -> هر ۵ فیلد false")
bool GetCtxLevelBool(int ticket)  { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagLevel[idx]  : false; }
bool GetCtxCycleBool(int ticket)  { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagCycle[idx]  : false; }
bool GetCtxTimeBool(int ticket)   { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagTime[idx]   : false; }
bool GetCtxCandleBool(int ticket) { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagCandle[idx] : false; }
bool GetCtxNoneBool(int ticket)   { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagNone[idx]   : false; }

// گترهای رشته‌ای (برای CSV/اکسپورت ژورنال - ExportTradeJournalCSV، RM_Reports.mqh) - "true"/"false"،
// هم‌راستا با بقیه‌ی ستون‌های Boolean موجود همون CSV (duringLockStr و بقیه، v61).
string GetCtxLevelStr(int ticket)  { return GetCtxLevelBool(ticket)  ? "true" : "false"; }
string GetCtxCycleStr(int ticket)  { return GetCtxCycleBool(ticket)  ? "true" : "false"; }
string GetCtxTimeStr(int ticket)   { return GetCtxTimeBool(ticket)   ? "true" : "false"; }
string GetCtxCandleStr(int ticket) { return GetCtxCandleBool(ticket) ? "true" : "false"; }
string GetCtxNoneStr(int ticket)   { return GetCtxNoneBool(ticket)   ? "true" : "false"; }

//+------------------------------------------------------------------+
// لیست معاملات «امروز» (باز + بسته‌شده‌ی امروز) برای مرحله‌ی ۱ پنجره‌ی تگ‌گذاری
//+------------------------------------------------------------------+
// v56: مبنای «امروز» همون g_dayStart موجوده (iTime(Symbol(),PERIOD_D1,0) - همون مرز روزی که
// Daily Risk/Daily DD از قبل استفاده می‌کنن)، نه یه محاسبه‌ی جدید و جداگانه - طبق درخواست تسک،
// معاملات قدیمی‌تر عمداً بیرون از این لیستن (خارج از مسئولیت EA).
int BuildTodayTicketList(string &labels[])
{
   ArrayResize(labels, 0);
   ArrayResize(g_tagTodayTickets, 0);
   int cnt = 0;

   // معاملات باز (بدون فیلتر زمانی - هر معامله‌ی باز طبق تعریف "امروز" حساب می‌شه، حتی اگه از
   // چند روز قبل باز مونده باشه، چون هنوز فرصت تگ‌گذاری قبل از بسته‌شدنش هست)
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;

      int ticket = OrderTicket();
      string lbl = "#"+IntegerToString(ticket)+" "+OrderSymbol()+" "+((OrderType()==OP_BUY)?"BUY":"SELL")+" (OPEN)";
      ArrayResize(labels, cnt+1);
      ArrayResize(g_tagTodayTickets, cnt+1);
      labels[cnt] = lbl;
      g_tagTodayTickets[cnt] = ticket;
      cnt++;
   }

   // معاملات بسته‌شده‌ی امروز
   // v80 (BUG-056 کار سوم): از جدیدترین به قدیمی‌ترین (قبلاً قدیمی‌ترین اول). پنجره‌ی Tag Trade Scroll
   // نداره و ارتفاعش با تعداد ردیف‌ها بلند می‌شه؛ با ترتیب قبلی، تازه‌ترین معامله‌ی بسته‌شده همیشه *آخرِ*
   // لیست (پایین‌ترین ردیف) می‌افتاد و وقتی تعداد معاملات امروز زیاد بود از پایین چارت بیرون می‌زد -
   // یعنی «معامله‌ای که همین الان بستم توی لیست نیست» دقیقاً برای معاملات تازه. فیلتر (Magic/نوع/
   // g_dayStart) دست‌نخورده است.
   for(int j=OrdersHistoryTotal()-1;j>=0;j--)
   {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(OrderCloseTime()<g_dayStart) continue;

      int ticket = OrderTicket();
      string lbl = "#"+IntegerToString(ticket)+" "+OrderSymbol()+" "+((OrderType()==OP_BUY)?"BUY":"SELL")+" (CLOSED)";
      ArrayResize(labels, cnt+1);
      ArrayResize(g_tagTodayTickets, cnt+1);
      labels[cnt] = lbl;
      g_tagTodayTickets[cnt] = ticket;
      cnt++;
   }

   return cnt;
}

// v59 (Item 4 - یادآوری معاملات تگ‌نخورده): همون دامنه‌ی "امروز" که BuildTodayTicketList() بالا
// استفاده می‌کنه (باز + بسته‌شده‌ی امروز، همون مرز g_dayStart) - ولی بدون دست‌زدن به
// g_tagTodayTickets (اون آرایه مخصوص وضعیت پنجره‌ی تگ‌گذاریه؛ اگه این تابع هر تیک صداش بزنه و
// همزمان پنجره‌ی تگ‌گذاری باز باشه، ایندکس دکمه‌های اون پنجره ممکنه با محتوای واقعی‌ش ناهماهنگ
// بشه). فقط شمارش می‌کنه - هیچ آرایه‌ی سراسری دیگه‌ای رو تغییر نمی‌ده.
int CountUntaggedToday()
{
   // v86 (FEAT-042 فاز ۱): هر زنجیره (ریشه) فقط یک‌بار شمرده می‌شود؛ زنجیره «تگ‌خورده» است اگر خودش (ریشه‌محور) یا هر عضوش تگ داشته باشد.
   int  roots[];   ArrayResize(roots, 0);
   bool tagged[];  ArrayResize(tagged, 0);
   int  nRoots = 0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      CountUntaggedAddTicket(OrderTicket(), roots, tagged, nRoots);
   }
   for(int j=0;j<OrdersHistoryTotal();j++)
   {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(OrderCloseTime()<g_dayStart) continue;
      CountUntaggedAddTicket(OrderTicket(), roots, tagged, nRoots);
   }

   int untagged = 0;
   for(int k=0;k<nRoots;k++)
      if(!tagged[k]) untagged++;
   return untagged;
}

// v86 (FEAT-042 فاز ۱): کمکی CountUntaggedToday - ثبت یک تیکت زیر ریشه‌اش.
void CountUntaggedAddTicket(int ticket, int &roots[], bool &tagged[], int &nRoots)
{
   int  r = GetRootTicket(ticket);
   bool t = (FindTagIndex(ticket) >= 0);
   for(int x=0;x<nRoots;x++)
      if(roots[x]==r) { if(t) tagged[x] = true; return; }
   ArrayResize(roots,  nRoots+1);
   ArrayResize(tagged, nRoots+1);
   roots[nRoots]  = r;
   tagged[nRoots] = t;
   nRoots++;
}

//+------------------------------------------------------------------+
// پنجره‌ی تگ‌گذاری (UI روی چارت) - پیشوند جدا (TAG_WIN_PREFIX) از پنل اصلی (P="RM9_")، تا کلیک‌ها/
// rebuild این پنجره کاملاً مستقل از دیسپچ و لایه‌بندی پنل اصلی بمونه. جای ثابت (بالا-چپ) و
// بدون قابلیت درگ - محدودیت شناخته‌شده‌ی نسخه‌ی اول: momکنه با تنظیمات خاص Layout Scale/پنل
// همپوشانی داشته باشه؛ چون این یه پنجره‌ی موقتیه (باز->انتخاب->بسته)، نه بخش دائمی داشبورد،
// این یه محدودیت قابل قبوله (هم‌رده‌ی محدودیت‌های مستندشده‌ی دیگه‌ی پروژه مثل سقف RR=5).
// همچنین بدون Scroll - برای تعداد Strategy/Setup/معاملات-امروز معقول (چند تا تا چند ده‌تا) کافیه.
// v70 (Change 2 - پنجره دیگه با انتخاب Setup بسته نمی‌شه، فقط با X یا کلیک بیرون پنجره): این تابع
// دقیقاً همون فرمول هندسی BuildTagWindow() (rowH/hdrH/pad/winX/winY/winW/totalH، شامل شمارش
// ردیف‌های وابسته به g_tagStep) رو تکرار می‌کنه تا OnChartEvent بتونه تشخیص بده یه کلیک روی چارت
// واقعاً "بیرون از این پنجره"‌ست یا نه - همون الگوی IsOnPanel() برای پنل اصلی. اگه بعداً چیدمان
// BuildTagWindow() عوض شد، این تابع هم باید دستی هماهنگ بشه (نگه‌داشتن به‌عنوان تابع مستقل و ساده
// عمداً ترجیح داده شد به رفکتور مشترک، برای کمترین ریسک روی خودِ BuildTagWindow() تست‌شده‌ی v56-v69).
// FEAT-027 (v73): از این نسخه به بعد BuildTagWindow() توی استپ Setup (بعد از FEAT-037/v81 یعنی
// g_tagStep==3، قبلاً 2 بود) دو تا پنجره‌ی جدا می‌سازه (اصلی + Mental State سمت چپش، به‌خاطر
// overflow پایین چارت روی صفحه‌ی کوچیک) - این تابع هم به‌همون شکل برای هر دو تا جداگانه هندسه رو
// تکرار می‌کنه (پایین همین تابع).
bool IsOnTagWindow(int x, int y)
{
   if(!g_tagWindowOpen) return false;

   int rowH = SC(22);
   int hdrH = SC(24);
   int pad  = SC(4);

   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int winX   = PanelRight ? chartW - PW - PanelX : PanelX;
   int winW   = PW;
   int panelBottomY = PanelY + TH + (g_minimized ? 0 : ComputeBodyH());
   int winY   = panelBottomY + GP;

   string todayLabels[];
   string setupsList[];
   int todayCount  = (g_tagStep==0) ? BuildTodayTicketList(todayLabels) : 0;
   // FEAT-037 (v81): استپ‌ها یکی جابه‌جا شدن - 0=معامله، 1=چک‌لیست کانتکست (جدید)، 2=Strategy،
   // 3=Setup (+ Mental State). setupsCount حالا با g_tagStep==3 محاسبه می‌شه (قبلاً 2 بود).
   int setupsCount = (g_tagStep==3) ? GetSetupsForStrategy(g_tagSelectedStrategy, setupsList) : 0;

   // FEAT-027: Mental State دیگه ردیف‌هاش رو به ارتفاع همین ستون (پنجره‌ی اصلی) اضافه نمی‌کنه -
   // رفته توی پنجره‌ی جدا (چک جداگانه‌ش پایین همین تابع)، پس اینجا فقط setupsCount+1 (Setup + راهنما).
   // FEAT-037: g_tagStep==1 (چک‌لیست کانتکست) ۶ ردیف ثابته - ۵ چک‌باکس + ۱ دکمه‌ی NEXT.
   int contentRows = (g_tagStep==0) ? (todayCount>0 ? todayCount : 1) :
                     (g_tagStep==1) ? 6 :
                     (g_tagStep==2) ? g_stratCount+1 :
                                       setupsCount+1;
   int backRows = (g_tagStep>0) ? 1 : 0;
   int totalH   = pad + hdrH + pad + backRows*(rowH+pad) + contentRows*(rowH+pad) + pad;

   if(x>=winX && x<=winX+winW && y>=winY && y<=winY+totalH) return true;

   // FEAT-027: توی g_tagStep==3 (Setup) یه پنجره‌ی دوم (Mental State) هم سمت چپ پنجره‌ی اصلی بازه -
   // باید جداگانه چک بشه. وگرنه کلیک روی یکی از دکمه‌های Mental State (که OBJECT_CLICK درستش می‌کنه)
   // بلافاصله با همون CHARTEVENT_CLICK یه‌دونه‌ای (کامنت بالای این تابع - همون رفتار دوگانه‌ی
   // فایر شدن) به‌عنوان "کلیک بیرون پنجره" شناخته می‌شه و کل پنجره‌ی Tag Trade رو می‌بنده -
   // همون هندسه‌ای که BuildTagWindow() برای پنجره‌ی دوم می‌سازه، اینجا هم دقیقاً تکرار شده.
   // FEAT-037 (v81): این چک قبلاً g_tagStep==2 بود - با شیفت شماره‌ی استپ‌ها به 3 عوض شد.
   if(g_tagStep==3)
   {
      int mentalStateRows = 4;   // هدر + ۲ ردیف دکمه + Clear (همون عدد قبلی، فقط جابه‌جا شده)
      int mentalWinW    = winW;
      int mentalWinX    = MathMax(0, winX - mentalWinW - GP);
      int mentalWinY    = winY;
      int mentalTotalH  = pad + mentalStateRows*(rowH+pad) + pad;
      if(x>=mentalWinX && x<=mentalWinX+mentalWinW && y>=mentalWinY && y<=mentalWinY+mentalTotalH) return true;
   }

   return false;
}

//+------------------------------------------------------------------+
// === v90 (FEAT-044 فاز ۱): پنجره‌ی انتخاب زنجیره‌ی Scale-in (وقتی ۲+ زنجیره‌ی مجاز) ===
// هم‌سبک پنجره‌ی Tag Trade: زیر پنل، هم‌عرض PW، پیشوند جدا (SCL_WIN_PREFIX). هر ردیف: تیکت ریشه، جهت، قیمت ورود، تگ استراتژی، ریسک آزاد ($).
// بدون Scroll (تعداد زنجیره‌های هم‌زمان کم است). فهرست هر ~۱ ثانیه (از OnTick) تازه می‌شود؛ زنجیره‌ی بسته‌شده/سقف‌صفرشده خودکار حذف می‌شود.
//+------------------------------------------------------------------+
#define SCL_WIN_PREFIX "RM_SCL_"

void CloseScaleInPicker()
{
   if(!g_scaleInPickerOpen) { ObjectsDeleteAll(0, SCL_WIN_PREFIX); return; }
   ObjectsDeleteAll(0, SCL_WIN_PREFIX);
   g_scaleInPickerOpen = false;
   ChartRedraw();
}

string ShortTagText(string s, int maxLen)
{
   if(StringLen(s) <= maxLen) return s;
   return StringSubstr(s, 0, maxLen);
}

void BuildScaleInPicker()
{
   ObjectsDeleteAll(0, SCL_WIN_PREFIX);
   if(!g_scaleInPickerOpen) return;

   int corner = CORNER_LEFT_UPPER;
   int rowH = SC(22), hdrH = SC(24), pad = SC(4);
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int winX   = PanelRight ? chartW - PW - PanelX : PanelX;
   int winW   = PW;
   int panelBottomY = PanelY + TH + (g_minimized ? 0 : ComputeBodyH());
   int winY   = panelBottomY + GP;

   int n = ArraySize(g_scCandRoot);
   int totalH = pad + hdrH + pad + (n>0 ? n : 1)*(rowH+pad) + pad;

   RectC(SCL_WIN_PREFIX+"BG", winX, winY, winW, totalH, C'25,25,32', corner);
   int cy = winY + pad;
   BtnC(SCL_WIN_PREFIX+"HDR",   winX,             cy, winW-SC(24)-pad, hdrH, "Scale-in - pick a trade", C'85,55,130', corner, 7);
   BtnC(SCL_WIN_PREFIX+"CLOSE", winX+winW-SC(24), cy, SC(24),          hdrH, "X",                       C'120,40,40', corner, 8);
   cy += hdrH + pad;

   if(n == 0)
   {
      LblCC(SCL_WIN_PREFIX+"EMPTY", winX, cy, winW, rowH, "No eligible trade", clrSilver, 7, false, corner);
      return;
   }
   for(int i=0;i<n;i++)
   {
      int root = g_scCandRoot[i];
      string tag = ShortTagText(GetTagStrategy(root), 8);
      string lbl = "#"+IntegerToString(root)+" "+(g_scCandBuy[i]?"B":"S")+" "+DoubleToStr(g_scCandEntry[i],Digits)+" $"+DoubleToStr(g_scCandCap[i],0)+(tag!="N/A" ? " "+tag : "");
      BtnC(SCL_WIN_PREFIX+"ROW_"+IntegerToString(i), winX, cy, winW, rowH, lbl, C'60,60,70', corner, 7);
      cy += rowH + pad;
   }
}

void OpenScaleInPicker()
{
   if(g_tagWindowOpen) CloseTagWindow();   // هر دو زیر پنل و هم‌جایگاه‌اند
   g_scaleInPickerOpen = true;
   BuildScaleInPicker();
   ChartRedraw();
}

// کلیک روی ردیف i. زنجیره دوباره اعتبارسنجی می‌شود؛ اگر دیگر معتبر نیست فهرست تازه می‌شود و پیام می‌آید.
void ScaleInPickerSelect(int i)
{
   if(i < 0 || i >= ArraySize(g_scCandRoot)) return;
   int root = g_scCandRoot[i];
   string why;
   double cap = ScaleInCapUSD(root, why);
   if(cap <= 0)
   {
      SetStatus("Scale-in: #"+IntegerToString(root)+" no longer eligible ("+why+")", clrOrange);
      ScaleInPickerRefresh(true);
      return;
   }
   ScaleInSelectChain(root, cap);
}

// فهرست انتخابگر را با وضعیت زنده مقایسه و در صورت تفاوت دوباره می‌سازد؛ اگر خالی شد پنجره بسته و Scale-in خاموش می‌ماند.
// force=true: بدون throttle. اگر Scale-in روشن است (زنجیره انتخاب‌شده)، اعتبار آن را هم نگه می‌دارد (OnTick).
void ScaleInPickerRefresh(bool force=false)
{
   static uint lastTick = 0;
   uint nowTk = GetTickCount();
   if(!force && nowTk - lastTick < 1000) return;
   lastTick = nowTk;

   if(g_scaleInOn)
   {
      string why;
      if(ScaleInCapUSD(g_scaleInRoot, why) <= 0)
      {
         ScaleInTurnOff();
         if(g_step != STEP_IDLE){ g_step=STEP_IDLE; UpdateModeButtons(); ResetLines(); }
         SetStatus("Scale-in OFF: chain no longer eligible ("+why+")", clrOrange);
      }
      return;
   }
   if(!g_scaleInPickerOpen) return;

   int    oldRoot[]; double oldCap[];
   int oldN = ArraySize(g_scCandRoot);
   ArrayResize(oldRoot, oldN); ArrayResize(oldCap, oldN);
   for(int k=0;k<oldN;k++){ oldRoot[k] = g_scCandRoot[k]; oldCap[k] = g_scCandCap[k]; }

   string whyNone = "";
   int n = BuildScaleInCandidates(whyNone);
   if(n == 0)
   {
      CloseScaleInPicker();
      UpdateScaleInButton();
      SetStatus("Scale-in: "+whyNone, clrOrange);
      return;
   }
   bool changed = (n != oldN);
   for(int q=0; !changed && q<n; q++)
      if(oldRoot[q] != g_scCandRoot[q] || MathAbs(oldCap[q]-g_scCandCap[q]) >= 0.01) changed = true;
   if(changed){ BuildScaleInPicker(); ChartRedraw(); }
}

void CloseTagWindow()
{
   ObjectsDeleteAll(0, TAG_WIN_PREFIX);
   g_tagWindowOpen = false;
   UpdateTagTradesButton();  // v56: رنگ دکمه‌ی "TAG TRADES" رو برگردون به حالت غیرفعال (RM_Dashboard.mqh)
   ChartRedraw();
}

void OpenTagWindow()
{
   CloseScaleInPicker();  // v90 (FEAT-044): هر دو پنجره زیر پنل و هم‌جایگاه‌اند
   g_tagWindowOpen       = true;
   g_tagStep             = 0;
   g_tagSelectedTicket   = -1;
   g_tagSelectedStrategy = "";
   g_tagSelectedMentalState = "";  // v69 (FEAT-026): سشن جدید، انتخاب قبلی Mental State پاک می‌شه
   // FEAT-037 (v81): سشن جدید، انتخاب قبلی چک‌لیست کانتکست هم پاک می‌شه - هم‌الگوی Mental State بالا.
   g_ctxSelLevel = false; g_ctxSelCycle = false; g_ctxSelTime = false; g_ctxSelCandle = false; g_ctxSelNone = false;
   // v56.5 (Mahmoud - تصمیم نهایی بعد از تست OBJ_EDIT): افزودن Strategy/Setup جدید دیگه از داخل
   // چارت (تایپ توی باکس) انجام نمی‌شه - SELECTABLE لازم برای فوکوس تایپ، همون property‌ایه که
   // باعث جابه‌جا شدن راحت مستطیل با درگ می‌شه؛ توی MT4 این دو تا از هم جدا نیستن (همون خانواده‌ی
   // BUG-004 قدیمی پروژه که دقیقاً به همین دلیل OBJ_EDIT رو کلاً کنار گذاشت، نه فیکسش کرد).
   // به‌جاش: افزودن جدید = ادیت مستقیم فایل RM_StrategySetups.txt، و این‌جا هر بار که پنجره باز
   // می‌شه، فایل دوباره از دیسک خونده می‌شه - پس هر تغییر دستی همون لحظه توی لیست دیده می‌شه.
   LoadTradeTagsFile();         // v101: پنجره‌ی تگ باید آخرین وضعیت فایل (تگ‌های نمونه‌های دیگر) را نشان دهد
   LoadContextTagsFile();
   LoadStrategySetupsFile();
   LoadContextChecklistFile();  // FEAT-037: هم‌الگو - هر بار پنجره باز می‌شه، ویرایش دستی RM_ContextChecklist.txt دیده بشه
   UpdateTagTradesButton();  // v56: رنگ دکمه‌ی "TAG TRADES" رو به حالت فعال/teal ببر (RM_Dashboard.mqh)
   BuildTagWindow();
}

void BuildTagWindow()
{
   ObjectsDeleteAll(0, TAG_WIN_PREFIX);
   if(!g_tagWindowOpen) return;

   int corner = CORNER_LEFT_UPPER;
   int rowH   = SC(22);
   int hdrH   = SC(24);
   int pad    = SC(4);

   // v56.2 (فیکس واقعی - گزارش Mahmoud): علت اصلی "کادر سیاه خالی" ربطی به همپوشانی با پنل
   // اصلی نداشت (چون پنل سمت راست بود). علت واقعی: توی BuildPanel() خود پروژه صراحتاً مستند
   // شده - "MT4 draws later-created objects on top" - یعنی ترتیب SAKHT آبجکت مهمه، نه فقط
   // OBJPROP_ZORDER. پنل اصلی همیشه پس‌زمینه‌اش (BG) رو اول می‌سازه (قبل از دکمه‌ها) تا پشت
   // بمونه؛ نسخه‌ی قبلی این تابع برعکس عمل می‌کرد - BG رو آخر از همه می‌ساخت، پس روی همه‌ی
   // دکمه‌ها می‌نشست و کاملاً می‌پوشوندشون. فیکس: حالا دقیقاً همون الگوی BuildPanel() - ارتفاع
   // محتوا اول محاسبه می‌شه (بدون ساخت آبجکت)، بعد BG با همون ارتفاع ساخته می‌شه، و فقط بعدش
   // ردیف‌های محتوا روی BG ساخته می‌شن.
   //
   // جانمایی (فیدبک Mahmoud): به‌جای موقعیت ثابت، دقیقاً زیر خود داشبورد و هم‌سمت با اون
   // (همون x و همون عرض PW که BuildPanel() برای پنل اصلی استفاده می‌کنه) - نه یه گوشه‌ی جدا.
   int chartW  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int winX    = PanelRight ? chartW - PW - PanelX : PanelX;
   int winW    = PW;
   // پایین‌ترین لبه‌ی پنل اصلی همون‌طور (Minimized/بدنه‌ی کامل) که BuildPanel() محاسبه می‌کنه:
   // اگه Minimize باشه فقط TH (نوار عنوان)، وگرنه TH + ComputeBodyH() (بدنه‌ی کامل با هر Drawer‌ای که بازه).
   int panelBottomY = PanelY + TH + (g_minimized ? 0 : ComputeBodyH());
   int winY = panelBottomY + GP;  // یه فاصله‌ی کوچیک (همون GP پنل اصلی) زیر داشبورد

   // --- فاز ۱: محاسبه‌ی محتوا (بدون ساخت آبجکت) - همون داده‌ای که فاز ۲ برای رسم استفاده می‌کنه ---
   string todayLabels[];
   int    todayCount = 0;
   string setupsList[];
   int    setupsCount = 0;

   // FEAT-037 (v81): استپ‌ها شیفت شدن - 0=معامله، 1=چک‌لیست کانتکست (جدید)، 2=Strategy، 3=Setup.
   if(g_tagStep==0)
      todayCount = BuildTodayTicketList(todayLabels);
   else if(g_tagStep==3)
      setupsCount = GetSetupsForStrategy(g_tagSelectedStrategy, setupsList);

   // v69 (FEAT-026): استپ ۳ لیست Setup + ردیف راهنما رو نشون می‌ده.
   // FEAT-027 (v73): Mental State (۱ ردیف عنوان + ۲ ردیف دکمه + ۱ ردیف Clear = ۴ ردیف) دیگه اینجا
   // شمرده نمی‌شه و ارتفاع این پنجره رو زیاد نمی‌کنه - رفته توی پنجره‌ی دوم، جدا، سمت چپ همین پنجره
   // (پایین همین تابع، بعد از بستن بلوک g_tagStep==3). دلیل: روی صفحه‌ی کوچیک، این پنجره با Mental
   // State داخلش قبل از رسیدن تریدر به Setup/Mental State از پایین چارت می‌زد بیرون.
   // FEAT-037: استپ ۱ (چک‌لیست کانتکست) ثابت ۶ ردیفه - ۵ چک‌باکس + ۱ دکمه‌ی NEXT.
   int contentRows = (g_tagStep==0) ? (todayCount>0 ? todayCount : 1) :   // حداقل ۱ ردیف برای پیام "بدون معامله"
                     (g_tagStep==1) ? 6 :                       // FEAT-037: ۵ چک‌باکس + NEXT
                     (g_tagStep==2) ? g_stratCount+1 :          // +۱ برای ردیف راهنمای افزودن جدید
                                       setupsCount+1;            // +۱ راهنما (Mental State دیگه اینجا نیست)
   int backRows  = (g_tagStep>0) ? 1 : 0;
   int totalH    = pad + hdrH + pad + backRows*(rowH+pad) + contentRows*(rowH+pad) + pad;

   // --- فاز ۲: BG اول (طبق قرارداد پروژه - draw order، نه فقط ZORDER)، بعد محتوا روش ---
   RectC(TAG_WIN_PREFIX+"BG", winX, winY, winW, totalH, C'25,25,32', corner);

   int cy = winY + pad;

   // FEAT-037 (v81): چهار استپ به‌جای سه‌تا - چک‌لیست کانتکست بین انتخاب معامله و Strategy اضافه شد.
   string hdrText = (g_tagStep==0) ? "Tag Trade - 1/4: Select Trade" :
                     (g_tagStep==1) ? "Tag Trade - 2/4: Context Checklist" :
                     (g_tagStep==2) ? "Tag Trade - 3/4: Select Strategy" :
                                      "Tag Trade - 4/4: Select Setup ("+g_tagSelectedStrategy+")";
   BtnC(TAG_WIN_PREFIX+"HDR",   winX,               cy, winW-SC(24)-pad, hdrH, hdrText, C'50,54,68', corner, 7);
   BtnC(TAG_WIN_PREFIX+"CLOSE", winX+winW-SC(24),   cy, SC(24),          hdrH, "X",     C'120,40,40', corner, 8);
   cy += hdrH + pad;

   if(g_tagStep>0)
   {
      BtnC(TAG_WIN_PREFIX+"BACK", winX, cy, winW, rowH, "<< BACK", C'70,70,80', corner, 7);
      cy += rowH + pad;
   }

   if(g_tagStep==0)
   {
      if(todayCount==0)
      {
         LblCC(TAG_WIN_PREFIX+"EMPTY", winX, cy, winW, rowH, "No trades today", clrSilver, 7, false, corner);
         cy += rowH + pad;
      }
      else
      {
         // v59.2 (پیگیری - فیچر جدید، جای درست): بر خلاف تلاش قبلی (v59.1، فلش‌های چارت)، رنگ
         // تگ‌خورده/نخورده حالا دقیقاً همون‌جاست که Mahmoud خواسته - خودِ ردیف انتخاب معامله در این
         // پنجره. اگه این تیکت از قبل تگ خورده (GetTagStrategy != "N/A")، رنگ ردیفش همون
         // CLR_TOOLS_ACTIVE (فیروزه‌ای فعال، بدون رنگ جدید) می‌شه؛ وگرنه رنگ خاکستری پیش‌فرض قبلی.
         // این رنگ‌بندی هر بار که این پنجره باز/rebuild می‌شه از نو محاسبه می‌شه - نیازی به هیچ
         // live-update جداگانه‌ای نداره.
         for(int i=0;i<todayCount;i++)
         {
            color rowColor = (GetTagStrategy(g_tagTodayTickets[i])!="N/A") ? CLR_TOOLS_ACTIVE : C'60,60,70';
            BtnC(TAG_WIN_PREFIX+"TRADE_"+IntegerToString(i), winX, cy, winW, rowH, todayLabels[i], rowColor, corner, 7);
            cy += rowH + pad;
         }
      }
   }
   else if(g_tagStep==1)
   {
      // FEAT-037 (v81): چک‌لیست کانتکست - ۵ چک‌باکس مسطح و مستقل (چندانتخابی کامل)، بعدش دکمه‌ی
      // NEXT برای رفتن به Strategy. متن هر گزینه از فایل خارجی (g_ctxLabels، LoadContextChecklistFile)
      // میاد - قابل‌ویرایش دستی. رنگ فعال همون CLR_TOOLS_ACTIVE (هم‌رده‌ی هایلایت TRADE_/MENTAL_).
      bool ctxSel[5];
      ctxSel[0]=g_ctxSelLevel; ctxSel[1]=g_ctxSelCycle; ctxSel[2]=g_ctxSelTime; ctxSel[3]=g_ctxSelCandle; ctxSel[4]=g_ctxSelNone;
      for(int i=0;i<5;i++)
      {
         color cColor = ctxSel[i] ? CLR_TOOLS_ACTIVE : C'60,60,70';
         BtnC(TAG_WIN_PREFIX+"CTX_"+IntegerToString(i), winX, cy, winW, rowH, g_ctxLabels[i], cColor, corner, 7);
         cy += rowH + pad;
      }
      BtnC(TAG_WIN_PREFIX+"CTX_NEXT", winX, cy, winW, rowH, "NEXT >>", C'70,70,80', corner, 7);
      cy += rowH + pad;
   }
   else if(g_tagStep==2)
   {
      // v70 (Change 3): اگه این تیکت قبلاً تگ خورده، Strategy موجودش با همون CLR_TOOLS_ACTIVE
      // که ردیف‌های تگ‌خورده‌ی استپ ۰ و دکمه‌های Mental State استفاده می‌کنن هایلایت می‌شه -
      // فقط نمایشی، انتخاب خودکار/پرش استپ نیست، تریدر همچنان باید خودش کلیک کنه.
      string existStrat = GetTagStrategy(g_tagSelectedTicket);
      for(int i=0;i<g_stratCount;i++)
      {
         color stratColor = (existStrat!="N/A" && g_stratNames[i]==existStrat) ? CLR_TOOLS_ACTIVE : C'60,60,70';
         BtnC(TAG_WIN_PREFIX+"STRAT_"+IntegerToString(i), winX, cy, winW, rowH, g_stratNames[i], stratColor, corner, 7);
         cy += rowH + pad;
      }
      // v56.5 (Mahmoud - تصمیم نهایی): دیگه هیچ OBJ_EDIT/ADD ای این‌جا نیست (ببین توضیح کامل
      // بالای OpenTagWindow()) - فقط یه لیبل غیرقابل‌کلیک راهنما، هم‌رده‌ی همون کلاس محدودیت‌های
      // مستندشده‌ی پروژه (مثل سقف RR=5). افزودن Strategy جدید = ادیت مستقیم RM_StrategySetups.txt.
      LblCC(TAG_WIN_PREFIX+"STRAT_HINT", winX, cy, winW, rowH, "Add new: edit RM_StrategySetups.txt", clrSilver, 6, false, corner);
      cy += rowH + pad;
   }
   else // g_tagStep==3
   {
      // v70 (Change 3): همون منطق هایلایت Strategy بالا، برای Setup - ولی فقط وقتی معنی داره که
      // Strategy فعلاً انتخاب‌شده (g_tagSelectedStrategy) همون Strategy‌ایه که این تیکت قبلاً
      // زیرش تگ خورده بود؛ وگرنه (تریدر داره یه Strategy دیگه رو مرور می‌کنه) هیچ Setup‌ای از
      // این لیست هایلایت نمی‌شه، چون ربطی به تگ قبلی این تیکت نداره.
      string existStrat2 = GetTagStrategy(g_tagSelectedTicket);
      string existSetup  = GetTagSetup(g_tagSelectedTicket);
      bool   sameStratAsExisting = (existStrat2!="N/A" && existStrat2==g_tagSelectedStrategy);
      for(int i=0;i<setupsCount;i++)
      {
         color setupColor = (sameStratAsExisting && setupsList[i]==existSetup) ? CLR_TOOLS_ACTIVE : C'60,60,70';
         BtnC(TAG_WIN_PREFIX+"SETUP_"+IntegerToString(i), winX, cy, winW, rowH, setupsList[i], setupColor, corner, 7);
         cy += rowH + pad;
      }
      // v56.5: همون توضیح بالا - راهنمای غیرقابل‌کلیک به‌جای Edit/Add
      LblCC(TAG_WIN_PREFIX+"SETUP_HINT", winX, cy, winW, rowH, "Add new: edit RM_StrategySetups.txt", clrSilver, 6, false, corner);
      cy += rowH + pad;
   }

   // v69 (FEAT-026 - Mental State Tag): کاملاً اختیاری، هیچ reminder/هشداری بهش وابسته نیست.
   // انتخاب یه دکمه فقط g_tagSelectedMentalState رو ست/rebuild می‌کنه (نه ست/بستن پنجره - برخلاف
   // کلیک روی خودِ Setup که تگ رو نهایی و پنجره رو می‌بنده)، پس تریدر می‌تونه قبل یا بعد از انتخاب
   // Mental State هر ترتیبی که خواست Setup رو بزنه.
   // FEAT-027 (v73 - فیکس overflow پایین چارت روی صفحه‌ی کوچیک): این بخش دیگه زیر Setup توی همون
   // ستون/پنجره نیست - یه پنجره‌ی کاملاً جدا و کوچیک، سمت چپ پنجره‌ی اصلی، هم‌سطح با لبه‌ی بالای
   // اون (winY). طبق قرارداد خودِ پروژه (کامنت بالای BuildTagWindow() - BG همیشه اول ساخته می‌شه
   // تا پشت بمونه، وگرنه روی محتوا می‌شینه)، BG این پنجره‌ی دوم هم اول ساخته می‌شه، بعد محتوا.
   // محتوا (هدر + دکمه‌ها + Clear) دقیقاً همون‌طوری که بود - همون اسم آبجکت‌ها (MENTAL_HDR،
   // MENTAL_0..5، MENTAL_CLEAR)، فقط مختصات عوض شده؛ پس چک‌های OnChartEvent() برای این آبجکت‌ها
   // (که با StringFind روی اسم کار می‌کنن، نه مختصات) بدون تغییر درست کار می‌کنن. فقط خودِ BG یه
   // پیشوند اضافه‌ی مجزا (TAG_WIN_PREFIX+"MW_") می‌گیره تا از BG پنجره‌ی اصلی قابل‌تشخیص باشه -
   // چون این اسم هم با TAG_WIN_PREFIX شروع می‌شه، ObjectsDeleteAll(0, TAG_WIN_PREFIX) بالای همین
   // تابع همچنان هر دو پنجره رو با هم پاک می‌کنه.
   if(g_tagStep==3)  // FEAT-037 (v81): قبلاً g_tagStep==2 بود - با شیفت شماره‌ی استپ‌ها عوض شد
   {
      int mentalStateRows = 4;   // هدر + ۲ ردیف دکمه (۳تایی، جمعاً ۶ گزینه) + Clear
      int mentalWinW   = winW;   // همون عرض پنجره‌ی اصلی (PW) - "هم‌الگو"ی خواسته‌شده در تسک
      int mentalWinX   = MathMax(0, winX - mentalWinW - GP);  // چسبیده به چپِ پنجره‌ی اصلی؛ کلمپ به ۰ روی چارت خیلی باریک
      int mentalWinY   = winY;   // هم‌سطح با لبه‌ی بالای پنجره‌ی اصلی
      int mentalTotalH = pad + mentalStateRows*(rowH+pad) + pad;

      RectC(TAG_WIN_PREFIX+"MW_BG", mentalWinX, mentalWinY, mentalWinW, mentalTotalH, C'25,25,32', corner);

      int cy2 = mentalWinY + pad;
      LblCC(TAG_WIN_PREFIX+"MENTAL_HDR", mentalWinX, cy2, mentalWinW, rowH, "Mental State:", clrSilver, 7, false, corner);
      cy2 += rowH + pad;

      string mentalOpts[];
      int    mentalCount = GetMentalStateOptions(mentalOpts);
      // همون الگوی سه‌ستونی BuildPanel() (RM_Dashboard.mqh: toolsThirdW1/2/3)، فقط این‌بار روی
      // عرض پنجره‌ی دوم (mentalWinW) به‌جای winW - چون mentalWinW==winW عملاً همون اعداد قبلی‌ان.
      int mThirdW1 = (mentalWinW-2*GP)/3;
      int mThirdW2 = mThirdW1;
      int mThirdW3 = mentalWinW-2*GP-mThirdW1-mThirdW2;
      int mColW[3]; mColW[0]=mThirdW1; mColW[1]=mThirdW2; mColW[2]=mThirdW3;

      int mentalRows = (mentalCount + 2) / 3;  // سقف تقسیم بر ۳ - با ۶ گزینه‌ی فعلی دقیقاً ۲ ردیف
      for(int r=0; r<mentalRows; r++)
      {
         int rx = mentalWinX;
         for(int c=0; c<3; c++)
         {
            int mi = r*3+c;
            if(mi>=mentalCount) break;  // ردیف آخر ناقص (اگه تعداد گزینه‌ها مضرب ۳ نبود)
            string mName = TAG_WIN_PREFIX+"MENTAL_"+IntegerToString(mi);
            // v69: همون pattern هایلایت که تسک خواسته - رنگ فعال یکسان با رنگ ردیف‌های تگ‌خورده‌ی
            // TRADE_ بالا (CLR_TOOLS_ACTIVE)، نه یه رنگ جدید.
            color mColor = (g_tagSelectedMentalState==mentalOpts[mi]) ? CLR_TOOLS_ACTIVE : C'60,60,70';
            BtnC(mName, rx, cy2, mColW[c], rowH, mentalOpts[mi], mColor, corner, 6);
            FitBtnFontHalf(mName, mentalOpts[mi], mColW[c], 6);
            rx += mColW[c] + GP;
         }
         cy2 += rowH + pad;
      }

      BtnC(TAG_WIN_PREFIX+"MENTAL_CLEAR", mentalWinX, cy2, mentalWinW, rowH, "Clear", C'70,70,80', corner, 7);
      cy2 += rowH + pad;
   }

   ChartRedraw();
}

