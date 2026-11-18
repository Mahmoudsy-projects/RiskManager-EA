//+------------------------------------------------------------------+
//| RM_Tools.mq5                                                       |
//| Risk Manager EA - Chart Tools & Utility Drawings (MT5 Port,         |
//| Stage 5d)                                                          |
//| پورت مستقیم از RM_Tools.mqh (RiskManager EA v70، بزرگ‌ترین فایل      |
//| پروژه). Golden Rule: فرمول‌ها/آستانه‌ها/ترتیب عملیات دست‌نخورده.       |
//|                                                                     |
//| [Stage 5d - judgment calls خلاصه، جزئیات کامل در گزارش]:             |
//| ۱) TimeYear/TimeMonth/TimeDay/TimeDayOfWeek/TimeHour/TimeMinute      |
//|    (توابع فقط-MT4) → TimeToStruct(دیت‌تایم، MqlDateTime&) و خوندن     |
//|    فیلدهای .year/.mon/.day/.day_of_week/.hour/.min. طبق مستندات      |
//|    رسمی MQL5، قرارداد day_of_week (۰=یکشنبه..۶=شنبه) دقیقاً همون      |
//|    قرارداد TimeDayOfWeek() نسخه‌ی MT4 است - محاسبه‌ی DST هیچ تغییر     |
//|    فرمولی نداشت، فقط منبع خوندن هر جزء زمان عوض شد. ردیابی دستی      |
//|    کامل (تاریخ واقعی DST 2026) در گزارش آورده شده.                   |
//| ۲) Time[0]/ArraySize(Time) (آرایه‌ی ضمنی سری MT4) → iTime(_Symbol,    |
//|    PERIOD_CURRENT, 0) با چک Bars(_Symbol,PERIOD_CURRENT)>0.          |
//| ۳) BuildEntryExitMarkers/BuildTodayTicketList/CountUntaggedToday:     |
//|    اسکن OrdersHistoryTotal/OrderSelect(MODE_HISTORY) → همون الگوی     |
//|    Deal-محور Stage 4/5b (HistorySelectByPosition، یک پوزیشن = یک     |
//|    ردیف). جزئیات پیامد بصری این تصمیم (نشانگر خروج پارشیال Half      |
//|    Close) در گزارش.                                                 |
//| ۴) تیکت int → ulong، همون الگوی همیشگی هر استیج قبلی.                |
//+------------------------------------------------------------------+

// === v42 (Punch List, Part 1): Fibo arm-state ===
// [Stage 5d] این globalها قبلاً به‌عنوان Stub در Stage 5c-ii ثبت شده بودن (چون OnChartEvent
// بهشون وابسته بود) - الان که خودِ RM_Tools.mq5 واقعی می‌شه، این‌جا تعریف می‌شن؛ فایل Stub این
// استیج (RM_Stage5d_Stubs.mqh) دیگه این‌ها رو نداره.
bool     g_fiboArmedRR      = false;
bool     g_fiboArmedMeasure = false;
bool     g_fiboWaitingP2    = false;
datetime g_fiboP1Time       = 0;
double   g_fiboP1Price      = 0;
uint     g_fiboArmDeadline  = 0;
int      g_fiboInstanceSeq  = 0;
#define FIBO_ARM_MS     10000
#define FIBO_RMULT_PREVIEW   "RM9LN_FIBO_RMULT_PREVIEW"
#define FIBO_MEASURE_PREVIEW "RM9LN_FIBO_MEASURE_PREVIEW"

// === v26 (FEAT-018): Tools drawer + Candle Timer ===
bool    g_candleTimerOn   = true;   // v75.0 (P0-5، MT4 v79): همیشه روشن؛ دکمه‌ی توگل حذف شد
bool    g_rmPerfLog       = false;  // v74.1 (HF1 A1): diagnostic-print switch (default OFF); gates the repeated [DEBUG-MARKERS] lines
string  g_ctLastTxt       = "";     // v74.1 (HF1 A1): last candle-timer text (redraw only when it changes)
datetime g_ctLastServerSync = 0;
datetime g_ctLastLocalSync  = 0;
datetime g_ctLastEstimate   = 0;
uint     g_ctLastRedrawMs   = 0;

datetime EstimateServerTime()
{
   if(TimeCurrent() != g_ctLastServerSync)
   {
      g_ctLastServerSync = TimeCurrent();
      g_ctLastLocalSync  = TimeLocal();
   }
   datetime est = (g_ctLastServerSync == 0) ? TimeCurrent() : g_ctLastServerSync + (TimeLocal() - g_ctLastLocalSync);
   if(est < g_ctLastEstimate) est = g_ctLastEstimate;
   g_ctLastEstimate = est;
   return est;
}

bool     g_hlDailyOn     = false;
bool     g_hlWeeklyOn    = false;
bool     g_hlMonthlyOn   = false;
bool     g_beRefOn       = false;

bool     g_objectsHidden    = false;
string   g_hiddenObjNames[];
long     g_hiddenObjTF[];
int      g_hiddenObjCount = 0;

#define HL_LN_D1HIGH  "RM9LN_DHIGH"
#define HL_LN_D1LOW   "RM9LN_DLOW"
#define HL_LN_W1HIGH  "RM9LN_WHIGH"
#define HL_LN_W1LOW   "RM9LN_WLOW"
#define HL_LN_MN1HIGH "RM9LN_MHIGH"
#define HL_LN_MN1LOW  "RM9LN_MLOW"
#define HL_LN_D1CLOSE  "RM9LN_DCLOSE"
#define HL_LN_D1OPEN   "RM9LN_DOPEN"   // v75.0 (P0-5، MT4 FEAT-032/v83): Previous Day Open
#define HL_LBL_D1HIGH  "RM9LB_DHIGH"
#define HL_LBL_D1LOW   "RM9LB_DLOW"
#define HL_LBL_W1HIGH  "RM9LB_WHIGH"
#define HL_LBL_W1LOW   "RM9LB_WLOW"
#define HL_LBL_MN1HIGH "RM9LB_MHIGH"
#define HL_LBL_MN1LOW  "RM9LB_MLOW"
#define HL_LBL_D1CLOSE "RM9LB_DCLOSE"
#define HL_LBL_D1OPEN  "RM9LB_DOPEN"   // v75.0 (P0-5)
#define FIBO_RMULT_OBJ "RM9LN_FIBO_RMULT"
#define FIBO_MEASURE_OBJ "RM9LN_FIBO_MEASURE"

string GV_CANDLE_TIMER = "RM_CandleTimerOn_" + _Symbol;

color GetContrastColor(color forDarkBg, color forLightBg)
{
   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   int bgR = (int)(chartBg & 0xFF);
   int bgG = (int)((chartBg >> 8) & 0xFF);
   int bgB = (int)((chartBg >> 16) & 0xFF);
   double bgLuminance = 0.299*bgR + 0.587*bgG + 0.114*bgB;
   return (bgLuminance > 140) ? forLightBg : forDarkBg;
}

string BERefLineName(bool isBuy) { return "RM9LN_BEREF_"+(isBuy?"BUY":"SELL")+"_"+IntegerToString(MagicNumber); }

void RemoveDailyHL()   { ObjectDelete(0,HL_LN_D1HIGH);  ObjectDelete(0,HL_LN_D1LOW);  ObjectDelete(0,HL_LBL_D1HIGH);  ObjectDelete(0,HL_LBL_D1LOW); ObjectDelete(0,HL_LN_D1CLOSE); ObjectDelete(0,HL_LBL_D1CLOSE); ObjectDelete(0,HL_LN_D1OPEN); ObjectDelete(0,HL_LBL_D1OPEN); }   // v75.0 (P0-5): PDO هم
void RemoveWeeklyHL()  { ObjectDelete(0,HL_LN_W1HIGH);  ObjectDelete(0,HL_LN_W1LOW);  ObjectDelete(0,HL_LBL_W1HIGH);  ObjectDelete(0,HL_LBL_W1LOW); }
void RemoveMonthlyHL() { ObjectDelete(0,HL_LN_MN1HIGH); ObjectDelete(0,HL_LN_MN1LOW); ObjectDelete(0,HL_LBL_MN1HIGH); ObjectDelete(0,HL_LBL_MN1LOW); }

bool ToolsLabelAnchorLeft() { return (!g_minimized && PanelRight); }

void UpdateDailyHL()
{
   if(!g_hlDailyOn) { RemoveDailyHL(); return; }
   if(iBars(_Symbol, PERIOD_D1) < 2) { RemoveDailyHL(); return; }
   double hi = iHigh(_Symbol, PERIOD_D1, 1);
   double lo = iLow (_Symbol, PERIOD_D1, 1);
   if(hi<=0 || lo<=0) { RemoveDailyHL(); return; }
   bool aLeft = ToolsLabelAnchorLeft();
   color c = GetContrastColor(C'80,180,255', C'0,90,170');
   HLine(HL_LN_D1HIGH, hi, c, 1, STYLE_DASH);
   HLine(HL_LN_D1LOW,  lo, c, 1, STYLE_DASH);
   HLineLabel(HL_LBL_D1HIGH, hi, c, "PDH", true, aLeft);
   HLineLabel(HL_LBL_D1LOW,  lo, c, "PDL", true, aLeft);

   double pdc = iClose(_Symbol, PERIOD_D1, 1);
   if(pdc<=0) { ObjectDelete(0,HL_LN_D1CLOSE); ObjectDelete(0,HL_LBL_D1CLOSE); }   // v75.0 (P0-5): دیگر return نمی‌کند تا به PDO برسد
   else
   {
      color cClose = GetContrastColor(C'140,220,90', C'50,120,20');
      HLine(HL_LN_D1CLOSE, pdc, cClose, 1, STYLE_DASH);
      HLineLabel(HL_LBL_D1CLOSE, pdc, cClose, "PDC", true, aLeft);
   }

   // v75.0 (P0-5، MT4 FEAT-032 + v83): PDO = Previous Day Open؛ shift=1 (همان کندل کامل‌شده‌ی دیروز مثل
   // PDH/PDL/PDC)، همان توگل واحد g_hlDailyOn، سبک خط‌چین، خانواده‌ی رنگی سفید/خاکستری، برچسب "PDO" بالای خط.
   double dOpen = iOpen(_Symbol, PERIOD_D1, 1);
   if(dOpen<=0) { ObjectDelete(0,HL_LN_D1OPEN); ObjectDelete(0,HL_LBL_D1OPEN); return; }
   color cOpen = GetContrastColor(C'230,230,235', C'90,90,95');
   HLine(HL_LN_D1OPEN, dOpen, cOpen, 1, STYLE_DASH);
   HLineLabel(HL_LBL_D1OPEN, dOpen, cOpen, "PDO", true, aLeft);
}

void UpdateWeeklyHL()
{
   if(!g_hlWeeklyOn) { RemoveWeeklyHL(); return; }
   if(iBars(_Symbol, PERIOD_W1) < 2) { RemoveWeeklyHL(); return; }
   double hi = iHigh(_Symbol, PERIOD_W1, 1);
   double lo = iLow (_Symbol, PERIOD_W1, 1);
   if(hi<=0 || lo<=0) { RemoveWeeklyHL(); return; }
   bool aLeft = ToolsLabelAnchorLeft();
   color c = GetContrastColor(C'255,180,80', C'170,100,0');
   HLine(HL_LN_W1HIGH, hi, c, 1, STYLE_DASH);
   HLine(HL_LN_W1LOW,  lo, c, 1, STYLE_DASH);
   HLineLabel(HL_LBL_W1HIGH, hi, c, "PWH", true, aLeft);
   HLineLabel(HL_LBL_W1LOW,  lo, c, "PWL", true, aLeft);
}

void UpdateMonthlyHL()
{
   if(!g_hlMonthlyOn) { RemoveMonthlyHL(); return; }
   if(iBars(_Symbol, PERIOD_MN1) < 2) { RemoveMonthlyHL(); return; }
   double hi = iHigh(_Symbol, PERIOD_MN1, 1);
   double lo = iLow (_Symbol, PERIOD_MN1, 1);
   if(hi<=0 || lo<=0) { RemoveMonthlyHL(); return; }
   bool aLeft = ToolsLabelAnchorLeft();
   color c = GetContrastColor(C'180,120,255', C'90,40,160');
   HLine(HL_LN_MN1HIGH, hi, c, 1, STYLE_DASH);
   HLine(HL_LN_MN1LOW,  lo, c, 1, STYLE_DASH);
   HLineLabel(HL_LBL_MN1HIGH, hi, c, "PMH", true, aLeft);
   HLineLabel(HL_LBL_MN1LOW,  lo, c, "PML", true, aLeft);
}

// [Stage 5d] ObjectsTotal(0,-1,-1)/ObjectName(0,i,-1,-1) already use the 3-arg chart_id form -
// confirmed identical between MQL4 (build 600+) and MQL5, no translation needed.
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
         if(StringFind(nm, P) == 0) continue;
         long tf = ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES);
         if(tf == OBJ_NO_PERIODS) continue;
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
         if(ObjectFind(0, g_hiddenObjNames[i]) < 0) continue;
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

   // [Stage 5d fix, found live during Mahmoud's Stage 5d testing] this preview line must mirror
   // the same live-spread adjustment ManualBE_BasketAverage() (RM_TradeExecution.mq5) applies to
   // the real SL, or the preview silently disagrees with what the button actually does - with a
   // single position the raw average equals entry exactly, hiding the discrepancy completely.
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double spreadPrice = ask-bid;
   if(hasBuy)  avgBuy  = NormalizeDouble(avgBuy  + spreadPrice, _Digits);
   if(hasSell) avgSell = NormalizeDouble(avgSell - spreadPrice, _Digits);

   color c = GetContrastColor(clrAqua, C'0,110,110');
   if(hasBuy)  HLine(BERefLineName(true),  avgBuy,  c, 1, STYLE_DOT);
   else        ObjectDelete(0, BERefLineName(true));
   if(hasSell) HLine(BERefLineName(false), avgSell, c, 1, STYLE_DOT);
   else        ObjectDelete(0, BERefLineName(false));
}

void CancelFiboArm()
{
   if(ObjectFind(0,P+"BTN_FIBRMULT")>=0)  ObjectSetInteger(0,P+"BTN_FIBRMULT", OBJPROP_BGCOLOR, CLR_BTN_DEFAULT);
   if(ObjectFind(0,P+"BTN_FIBMEASURE")>=0) ObjectSetInteger(0,P+"BTN_FIBMEASURE",OBJPROP_BGCOLOR, CLR_BTN_DEFAULT);
   ObjectDelete(0, FIBO_RMULT_PREVIEW);
   ObjectDelete(0, FIBO_MEASURE_PREVIEW);
   ObjectDelete(0, LN_FIBOCURSOR);
   g_fiboArmedRR      = false;
   g_fiboArmedMeasure = false;
   g_fiboWaitingP2    = false;
   g_fiboArmDeadline  = 0;
}

void ArmFiboTool(int toolId)
{
   CancelFiboArm();
   if(toolId==1)
   {
      g_fiboArmedRR = true;
      if(ObjectFind(0,P+"BTN_FIBRMULT")>=0) ObjectSetInteger(0,P+"BTN_FIBRMULT",OBJPROP_BGCOLOR,CLR_TOOLS_ACTIVE);
      SetStatus("R/R: click base point on chart", GetFiboRRColor());
   }
   else
   {
      g_fiboArmedMeasure = true;
      if(ObjectFind(0,P+"BTN_FIBMEASURE")>=0) ObjectSetInteger(0,P+"BTN_FIBMEASURE",OBJPROP_BGCOLOR,CLR_TOOLS_ACTIVE);
      SetStatus("Measure Move: click base point on chart", GetFiboMeasureColor());
   }
   g_fiboArmDeadline = GetTickCount() + FIBO_ARM_MS;
   ChartRedraw();
}

#define CANDLE_TIMER_OBJ "RM9LN_CANDLETIMER"

void RemoveCandleTimerChart()
{
   if(ObjectFind(0,CANDLE_TIMER_OBJ)>=0) ObjectDelete(0,CANDLE_TIMER_OBJ);
}

// [Stage 5d] Period()*60 (MT4, minutes->seconds) -> PeriodSeconds(PERIOD_CURRENT) (MT5, direct
// seconds - avoids Stage 4's already-documented Period()-above-M59 pitfall). iTime(Symbol(),
// Period(),0) -> iTime(_Symbol, PERIOD_CURRENT, 0). Bid -> SymbolInfoDouble(_Symbol, SYMBOL_BID).
void UpdateCandleTimerChart(bool forceRedraw=false)
{
   // v75.0 (P0-5، MT4 v79): چک g_candleTimerOn حذف شد - همیشه رسم می‌کند.

   int periodSec = PeriodSeconds(PERIOD_CURRENT);
   datetime barOpen = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime nowEst = EstimateServerTime();
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

   double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);
   double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
   double visibleRange = priceMax - priceMin;
   double yOffset = (visibleRange > 0) ? visibleRange * 0.015 : 0;
   double labelPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID) + yOffset;

   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   int bgR = (int)(chartBg & 0xFF);
   int bgG = (int)((chartBg >> 8) & 0xFF);
   int bgB = (int)((chartBg >> 16) & 0xFF);
   double bgLuminance = 0.299*bgR + 0.587*bgG + 0.114*bgB;
   color txtColor = (bgLuminance > 140) ? clrBlack : clrWhite;

   bool ctCreated = false;
   if(ObjectFind(0,CANDLE_TIMER_OBJ)<0) { ObjectCreate(0,CANDLE_TIMER_OBJ,OBJ_TEXT,0,0,0); ctCreated = true; }
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_TIME,  nowEst + periodSec*2);
   ObjectSetDouble (0,CANDLE_TIMER_OBJ,OBJPROP_PRICE, labelPrice);
   ObjectSetString (0,CANDLE_TIMER_OBJ,OBJPROP_TEXT,  txt);
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_COLOR, txtColor);
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_FONTSIZE, 12);
   ObjectSetString (0,CANDLE_TIMER_OBJ,OBJPROP_FONT,  "Arial Bold");
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,CANDLE_TIMER_OBJ,OBJPROP_BACK, false);
   // v74.1 (HF1 A1): redraw only when the countdown text changed (or the object was just created),
   // not forced every second / every 100 ms. forceRedraw kept in the signature for callers.
   bool doRedraw = (ctCreated || txt != g_ctLastTxt);
   g_ctLastTxt = txt;
   if(doRedraw)
   {
      ChartRedraw();
      g_ctLastRedrawMs = GetTickCount();
   }
}

void CreateFiboRMultiple(string objName, datetime t1, double p1, datetime t2, double p2, bool isPreview=false)
{
   // v75.7 (باگ فلش سطوح پیش‌فرض فیبو): پیش‌نمایش هر حرکت موس حذف/ساخت مجدد می‌شد و هر ObjectCreate سطوح پیش‌فرض فیبو
   // (۰/۲۳.۶/۳۸.۲...) را با رنگ پیش‌فرض می‌ساخت؛ ترد گرافیکی ترمینال می‌توانست وسط تنظیم سطوح آن را رسم کند (فلش).
   // راه‌حل: (۱) پیش‌نمایشِ موجود فقط جابه‌جا می‌شود (بدون حذف/ساخت)، (۲) شیء تازه تا پایان تنظیم سطوح روی هیچ تایم‌فریمی دیده نمی‌شود.
   if(isPreview && ObjectFind(0,objName)>=0)
   {
      ObjectSetInteger(0, objName, OBJPROP_TIME,  0, t1);
      ObjectSetDouble (0, objName, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(0, objName, OBJPROP_TIME,  1, t2);
      ObjectSetDouble (0, objName, OBJPROP_PRICE, 1, p2);
      ChartRedraw();
      return;
   }
   if(ObjectFind(0,objName)>=0) ObjectDelete(0,objName);
   ObjectCreate(0, objName, OBJ_FIBO, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);   // v75.7: مخفی تا آماده شدن

   // v75.8 (پورت MT4 v79 FEAT-034): ۹ لول - «2X» نیمه‌راهِ SL تا Entry (value=0.5)؛ فقط نمایشی
   int levelCount = 9;  // SL, 2X, Entry, R1..R6
   double levelVals[9] = {0.0, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0};
   string levelLbls[9] = {"SL", "2X", "Entry", "R1", "R2", "R3", "R4", "R5", "R6"};
   ObjectSetInteger(0, objName, OBJPROP_LEVELS, levelCount);
   color lvlColor = GetFiboRRColor();
   for(int i=0;i<levelCount;i++)
   {
      ObjectSetDouble (0, objName, OBJPROP_LEVELVALUE, i, levelVals[i]);
      ObjectSetString (0, objName, OBJPROP_LEVELTEXT,  i, levelLbls[i]);
      ObjectSetInteger(0, objName, OBJPROP_LEVELCOLOR, i, lvlColor);
      ObjectSetInteger(0, objName, OBJPROP_LEVELSTYLE, i, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_LEVELWIDTH, i, 2);
   }
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lvlColor);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);    // v75.12: خط وصل ابتدا–انتها خط‌چینِ ریز (Dot، دومین گزینه‌ی خط‌چین)؛ سطوح همچنان ممتد
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);            // استایل نقطه‌چین فقط با ضخامت ۱ دیده می‌شود
   ObjectSetInteger(0, objName, OBJPROP_RAY, false);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, true);
   ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);   // v75.7: حالا که همه‌ی سطوح آماده است نمایش بده
   ChartRedraw();
   if(!isPreview) SetStatus("R/R placed - drag to fine-tune", GetFiboRRColor());
}

void CreateFiboMeasureMove(string objName, datetime t1, double p1, datetime t2, double p2, bool isPreview=false)
{
   if(isPreview && ObjectFind(0,objName)>=0)   // v75.7: همان اصلاح پیش‌نمایش R/R
   {
      ObjectSetInteger(0, objName, OBJPROP_TIME,  0, t1);
      ObjectSetDouble (0, objName, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(0, objName, OBJPROP_TIME,  1, t2);
      ObjectSetDouble (0, objName, OBJPROP_PRICE, 1, p2);
      ChartRedraw();
      return;
   }
   if(ObjectFind(0,objName)>=0) ObjectDelete(0,objName);
   ObjectCreate(0, objName, OBJ_FIBO, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);   // v75.7: مخفی تا آماده شدن

   // v75.8 (پورت MT4 v106 BUG-062): ۷ لول طبق Fibo native؛ لول 0 (کلیک اول)=END، لول 1 (کلیک دوم)=START
   int levelCount = 7;
   double levelVals[7]  = {0.0, 0.5, 0.618, 1.0, 1.236, 1.618, 2.0};
   string levelLbls[7]  = {"END", "50%", "61.8%", "START", "123.6%", "161.8%", "200%"};
   ObjectSetInteger(0, objName, OBJPROP_LEVELS, levelCount);
   color lvlColor = GetFiboMeasureColor();
   for(int i=0;i<levelCount;i++)
   {
      ObjectSetDouble (0, objName, OBJPROP_LEVELVALUE, i, levelVals[i]);
      ObjectSetString (0, objName, OBJPROP_LEVELTEXT,  i, levelLbls[i]);
      ObjectSetInteger(0, objName, OBJPROP_LEVELCOLOR, i, lvlColor);
      ObjectSetInteger(0, objName, OBJPROP_LEVELSTYLE, i, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_LEVELWIDTH, i, 1);   // v75.8: خط ممتد نازک مثل MT4 v106
   }
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lvlColor);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);    // v75.12: خط وصل ابتدا–انتها خط‌چینِ ریز (Dot، دومین گزینه‌ی خط‌چین)؛ سطوح همچنان ممتد
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);            // استایل نقطه‌چین فقط با ضخامت ۱ دیده می‌شود
   ObjectSetInteger(0, objName, OBJPROP_RAY, false);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, true);
   ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);   // v75.7
   ChartRedraw();
   if(!isPreview) SetStatus("Measure Move placed - drag to fine-tune", GetFiboMeasureColor());
}

void SaveCandleTimerState()
{
   GlobalVariableSet(GV_CANDLE_TIMER, g_candleTimerOn ? 1.0 : 0.0);
}

void LoadCandleTimerState()
{
   g_candleTimerOn = true;   // v75.0 (P0-5، MT4 v79): همیشه روشن؛ مقدار ذخیره‌شده‌ی قدیمی نادیده گرفته می‌شود
}

//+------------------------------------------------------------------+
// v54 (فیچر جدید): Session Windows (SW / "Key Time")
//+------------------------------------------------------------------+
bool     g_swOn = false;
string   GV_SW_ON = "RM_SWOn_" + _Symbol;
#define  SW_HISTORY_DAYS 30
#define  SW_BOX_PREFIX   "RM9RC_SW_"
#define  SW_LBL_PREFIX   "RM9LB_SW_"
string   g_swBoxNames[];
string   g_swLblNames[];
int      g_swObjCount = 0;
datetime g_swCullTime = 0;   // v75.1 (MT4 v95): مرز چپ برای ساخت خطوط Key Time (۰ = بدون محدودیت)
// v75.1 (MT4 v107 FEAT-061): حالت نمایش KEY TIME - 0=FULL (هر ۱۶ خط)، 1=COMPACT (فقط خطوط اصلی).
// دکمه‌ی KEY TIME چرخه می‌زند: OFF -> FULL -> COMPACT -> OFF؛ در GlobalVariable ذخیره می‌شود.
#define  KEYTIME_MODE_FULL     0
#define  KEYTIME_MODE_COMPACT  1
int      g_swMode = KEYTIME_MODE_FULL;
string   GV_SW_MODE = "RM_SWMode_" + _Symbol;

// [Stage 5d - THE flagged DST translation] IsUSDST_UTC(): formula/thresholds unchanged from the
// original - only the source of each date component changed (TimeYear/TimeDayOfWeek, MT4-only ->
// TimeToStruct()+MqlDateTime fields, MT5). MQL5's MqlDateTime.day_of_week uses the SAME convention
// as MT4's TimeDayOfWeek() (0=Sunday..6=Saturday, confirmed against official MQL5 documentation) -
// so this translation is a pure API substitution, not a logic change. See the Stage 5d report for
// the full hand-traced verification against real 2026 US DST dates.
bool IsUSDST_UTC(datetime utcTime)
{
   MqlDateTime dtY; TimeToStruct(utcTime, dtY);
   int y = dtY.year;

   datetime marchFirst = StringToTime(IntegerToString(y)+".03.01 00:00");
   MqlDateTime dtM; TimeToStruct(marchFirst, dtM);
   int dowM = dtM.day_of_week;                         // 0=Sunday..6=Saturday, same convention as MT4's TimeDayOfWeek()
   int firstSunM  = (dowM==0) ? 1 : (8-dowM);
   int secondSunM = firstSunM + 7;
   datetime dstStart = StringToTime(IntegerToString(y)+".03."+IntegerToString(secondSunM)+" 07:00");

   datetime novFirst = StringToTime(IntegerToString(y)+".11.01 00:00");
   MqlDateTime dtN; TimeToStruct(novFirst, dtN);
   int dowN = dtN.day_of_week;
   int firstSunN  = (dowN==0) ? 1 : (8-dowN);
   datetime dstEnd = StringToTime(IntegerToString(y)+".11."+IntegerToString(firstSunN)+" 06:00");

   return (utcTime >= dstStart && utcTime < dstEnd);
}

void GetNYCalendarDate(int daysAgo, int &y, int &m, int &d)
{
   datetime nowUTC = ST_NowUTC();   // v75.0 (P0-1): زنده TimeGMT()، در تستر از آفست پایدار
   bool nowDst = IsUSDST_UTC(nowUTC);
   int nowNyOffSec = nowDst ? (-4*3600) : (-5*3600);
   datetime nowNY = nowUTC + nowNyOffSec;
   datetime targetNY = nowNY - ((datetime)daysAgo)*86400;
   MqlDateTime dt; TimeToStruct(targetNY, dt);
   y = dt.year; m = dt.mon; d = dt.day;
}

void ComputeSessionWindowServerTime(int daysAgo, int nyStartH, int nyStartM, int nyEndH, int nyEndM, datetime &outStart, datetime &outEnd)
{
   // v75.1 (MT4 v107): محاسبه به ماژول مشترک RM_SessionTime منتقل شد (آفست هر روز با DST همان روز)
   ST_ComputeSessionByDaysAgo(daysAgo, nyStartH, nyStartM, nyEndH, nyEndM, outStart, outEnd);
}

void GetSessionWindowPriceRange(double &priceTop, double &priceBot)
{
   int chartH      = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int xPix        = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2;
   int marginBotPx = 14;
   int boxHPx      = 6;

   int subWinBot = -1, subWinTop = -1;
   datetime tDummy = 0;
   bool okBot = ChartXYToTimePrice(0, xPix, chartH-marginBotPx,        subWinBot, tDummy, priceBot);
   bool okTop = ChartXYToTimePrice(0, xPix, chartH-marginBotPx-boxHPx, subWinTop, tDummy, priceTop);

   if(!okBot || !okTop || subWinBot!=0 || subWinTop!=0)
   {
      double pMax = ChartGetDouble(0, CHART_PRICE_MAX);
      double pMin = ChartGetDouble(0, CHART_PRICE_MIN);
      double range = pMax - pMin;
      if(range <= 0) { priceTop = SymbolInfoDouble(_Symbol,SYMBOL_BID); priceBot = priceTop; return; }
      priceBot = pMin + range*0.04;
      priceTop = pMin + range*0.05;
   }
}

void RemoveSessionWindows()
{
   RM_NewsRemove();   // v75.3 (MT4 v105): خطوط خبر USD هم با KEY TIME پاک می‌شوند
   for(int i=0; i<g_swObjCount; i++)
   {
      ObjectDelete(0, g_swBoxNames[i]);
      ObjectDelete(0, g_swLblNames[i]);
   }
   g_swObjCount = 0;
   ArrayResize(g_swBoxNames, 0);
   ArrayResize(g_swLblNames, 0);
}

// v75.1 (MT4 v81 FEAT-033 / v97 / v107): KEY TIME = ۱۶ خط عمودی سراسری (OBJ_VLINE، خط‌چین، رنگ نزدیک بک‌گراند)
// به‌جای سه باکس قدیمی. هر خط یک «بازار لنگر» دارد و ساعتش ساعت محلی همان بازار است (DST همان بازار، per-day).
#define KEYTIME_LINE_COUNT 16
string KeyTime_Id(int i)
{
   string ids[KEYTIME_LINE_COUNT] = {"M1","M2","M3","M4","M5","M6","M7","M8","S1","S2","S3","S4","S5","S6","S7","S8"};
   return ids[i];
}
void KeyTime_GetLine(int i, int &h, int &m, bool &isMain, int &dayOffset, int &mkt)
{
   // اصلی (i=0..7):   M1 NY17(روز قبل)  M2 Tokyo open  M3 Tokyo+1h  M4 Frankfurt  M5 London  M6 NY09:30  M7 NY11  M8 NY13
   int mainH[8]   = {17,  9, 10,  8,  8,  9, 11, 13};
   int mainM[8]   = { 0,  0,  0,  0,  0, 30,  0,  0};
   int mainOff[8] = { 1,  1,  1,  0,  0,  0,  0,  0};
   int mainMkt[8] = {ST_MKT_NY, ST_MKT_TOKYO, ST_MKT_TOKYO, ST_MKT_BERLIN, ST_MKT_LONDON, ST_MKT_NY, ST_MKT_NY, ST_MKT_NY};
   // فرعی (i=8..15):  S1 Tokyo13  S2 Sydney  S3 Tokyo19  S4 NY08:30  S5 NY14  S6 NY16  S7 London17  S8 Tokyo18
   int subH[8]   = {13, ST_SYDNEY_FINAL_HOUR_LOCAL, 19,  8, 14, 16, 17, 18};
   int subM[8]   = { 0,  0,  0, 30,  0,  0,  0,  0};
   int subMkt[8] = {ST_MKT_TOKYO, ST_MKT_SYDNEY, ST_MKT_TOKYO, ST_MKT_NY, ST_MKT_NY, ST_MKT_NY, ST_MKT_LONDON, ST_MKT_TOKYO};
   if(i<8) { h=mainH[i]; m=mainM[i]; isMain=true; dayOffset=mainOff[i]; mkt=mainMkt[i]; }
   else    { int j=i-8; h=subH[j]; m=subM[j]; isMain=false; dayOffset=0; mkt=subMkt[j]; }
}

// رنگ خودکار نزدیک بک‌گراند چارت؛ شدت از ورودی InpKeyTimeIntensity (clamp 5..80). فرعی با نسبت 10:17.
color GetKeyTimeLineColor(bool isMain)
{
   color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   int bgR = (int)(chartBg & 0xFF);
   int bgG = (int)((chartBg >> 8) & 0xFF);
   int bgB = (int)((chartBg >> 16) & 0xFF);
   double bgLuminance = 0.299*bgR + 0.587*bgG + 0.114*bgB;
   int refR, refG, refB;
   if(bgLuminance > 140) { refR=0;   refG=0;   refB=0;   }
   else                  { refR=255; refG=255; refB=255; }
   int kp = InpKeyTimeIntensity;
   if(kp < KEYTIME_INTENSITY_MIN) kp = KEYTIME_INTENSITY_MIN;
   if(kp > KEYTIME_INTENSITY_MAX) kp = KEYTIME_INTENSITY_MAX;
   int blendPct = kp;
   if(!isMain)
   {
      blendPct = (int)MathRound(kp * 10.0 / 17.0);
      if(blendPct < 1) blendPct = 1;
   }
   int r = bgR + (int)((refR-bgR)*blendPct/100.0);
   int g = bgG + (int)((refG-bgG)*blendPct/100.0);
   int b = bgB + (int)((refB-bgB)*blendPct/100.0);
   return (color)(r | (g<<8) | (b<<16));
}

void BuildOneKeyTimeLine(int daysAgo, int lineIdx, int nyH, int nyM, bool isMain, color c, int mkt = ST_MKT_NY, int dayOffset = 0)
{
   // nyH/nyM = ساعت محلی بازار mkt. NY = مسیر قدیمی؛ بقیه market-aware.
   datetime t1, t2dummy;
   if(mkt == ST_MKT_NY)
      ST_ComputeSessionByDaysAgo(daysAgo, nyH, nyM, nyH, nyM, t1, t2dummy);
   else
      ST_ComputeSessionByDaysAgoMkt(daysAgo - dayOffset, mkt, nyH, nyM, nyH, nyM, t1, t2dummy);
   // MT4 v95 (BUG-059): خطوط کاملاً چپِ ناحیه‌ی دیده‌شده ساخته نمی‌شوند (اسکرول به عقب با CHART_CHANGE دوباره می‌سازد)
   if(g_swCullTime > 0 && t1 < g_swCullTime) return;
   SessionLevel_EnsureChartShift(t1);

   string id       = KeyTime_Id(lineIdx);
   string lineName = SW_BOX_PREFIX + id + "_" + IntegerToString(daysAgo);
   string lblName  = SW_LBL_PREFIX + id + "_" + IntegerToString(daysAgo);

   double priceTop, priceBot;
   GetSessionWindowPriceRange(priceTop, priceBot);   // لنگر نزدیک پایین چارت برای لیبل

   if(ObjectFind(0,lineName)<0) ObjectCreate(0,lineName,OBJ_VLINE,0,t1,0);
   ObjectSetInteger(0,lineName,OBJPROP_TIME,  t1);
   ObjectSetInteger(0,lineName,OBJPROP_COLOR, c);
   ObjectSetInteger(0,lineName,OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0,lineName,OBJPROP_WIDTH, 1);   // عرض >1 استایل خط‌چین را نادیده می‌گیرد
   ObjectSetInteger(0,lineName,OBJPROP_BACK,  true);
   ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,lineName,OBJPROP_RAY,   false);

   // لیبل ساعت به وقت بروکر (t1 از قبل وقت سرور است)
   MqlDateTime lt; TimeToStruct(t1, lt);
   string hourLbl = StringFormat("%02d:%02d", lt.hour, lt.min);
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

void BuildSessionWindows()
{
   RemoveSessionWindows();
   if(!g_swOn) return;

   // MT4 v95: مرز چپ ناحیه‌ی دیده‌شده (یک روز حاشیه)
   g_swCullTime = 0;
   int firstVis = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   if(firstVis >= 0 && firstVis < Bars(_Symbol, PERIOD_CURRENT))
   {
      datetime leftT = iTime(_Symbol, PERIOD_CURRENT, firstVis);
      if(leftT > 0) g_swCullTime = leftT - 86400;
   }

   for(int daysAgo=-1; daysAgo<=SW_HISTORY_DAYS; daysAgo++)
   {
      for(int i=0; i<KEYTIME_LINE_COUNT; i++)
      {
         int h, m, dayOffset, mkt; bool isMain;
         KeyTime_GetLine(i, h, m, isMain, dayOffset, mkt);
         if(g_swMode == KEYTIME_MODE_COMPACT && !isMain) continue;   // COMPACT = فقط خطوط اصلی
         color c = GetKeyTimeLineColor(isMain);
         BuildOneKeyTimeLine(daysAgo+dayOffset, i, h, m, isMain, c, mkt, dayOffset);
      }
   }
   RM_NewsBuild();   // v75.3 (MT4 v105): خبرهای USD امروز (فقط از حافظه)
   ChartRedraw();
}

// فقط موقعیت عمودی لیبل‌ها را با بازه‌ی قیمت دیده‌شده هماهنگ می‌کند (خط عمودی قیمت ندارد). حداکثر هر ۳ ثانیه.
void UpdateSessionWindowsVertical()
{
   if(!g_swOn || g_swObjCount<=0) return;
   static uint   swLastMs = 0;
   static double swLastMax = 0, swLastMin = 0;
   static int    swLastH = 0, swLastCnt = 0;
   if((int)(GetTickCount() - swLastMs) < 3000) return;
   swLastMs = GetTickCount();
   // MT4 v95: اگر کاربر بیشتر از مرز فعلی به عقب اسکرول کرده، خطوط قدیمی‌تر را دوباره بساز
   if(g_swCullTime > 0)
   {
      int fv = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
      if(fv >= 0 && fv < Bars(_Symbol, PERIOD_CURRENT))
      {
         datetime lt = iTime(_Symbol, PERIOD_CURRENT, fv);
         if(lt > 0 && lt - 86400 < g_swCullTime) { BuildSessionWindows(); return; }
      }
   }
   RM_NewsUpdateVertical();   // v75.3: لیبل‌های خبر با زوم/اسکرول پایین چارت بمانند
   double swMax = ChartGetDouble(0, CHART_PRICE_MAX), swMin = ChartGetDouble(0, CHART_PRICE_MIN);
   int    swH   = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(swMax==swLastMax && swMin==swLastMin && swH==swLastH && g_swObjCount==swLastCnt) return;
   swLastMax = swMax; swLastMin = swMin; swLastH = swH; swLastCnt = g_swObjCount;
   double priceTop, priceBot;
   GetSessionWindowPriceRange(priceTop, priceBot);
   for(int i=0; i<g_swObjCount; i++)
   {
      if(ObjectFind(0,g_swLblNames[i])>=0)
         ObjectSetDouble(0,g_swLblNames[i],OBJPROP_PRICE, priceTop);
   }
}

void SaveSessionWindowsState()
{
   GlobalVariableSet(GV_SW_ON, g_swOn ? 1.0 : 0.0);
   GlobalVariableSet(GV_SW_MODE, (double)g_swMode);
}

void LoadSessionWindowsState()
{
   if(GlobalVariableCheck(GV_SW_ON))
      g_swOn = (GlobalVariableGet(GV_SW_ON) != 0.0);
   // نبودن GV = FULL
   g_swMode = (GlobalVariableCheck(GV_SW_MODE) && (int)GlobalVariableGet(GV_SW_MODE) == KEYTIME_MODE_COMPACT) ? KEYTIME_MODE_COMPACT : KEYTIME_MODE_FULL;
}

//+------------------------------------------------------------------+
//| v57 (فیچر جدید مستقل): Session Level                               |
//+------------------------------------------------------------------+
bool     g_sessLvlOn = false;
string   GV_SESSLVL_ON = "RM_SessLvlOn_" + _Symbol;
// v75.2 (MT4 v107 FEAT-063): حالت نمایش SESSION - 0=COMPACT (نوار باریک پایین)، 1=EXPANDED (باکس High..Low روی کندل‌ها).
// چرخه: OFF -> COMPACT -> EXPANDED -> OFF؛ در GV ذخیره می‌شود؛ نبودن GV = COMPACT.
#define  SL_MODE_COMPACT   0
#define  SL_MODE_EXPANDED  1
#define  SL_EXP_BLEND_PCT  30           // درصد رنگ سشن روی بک‌گراند (آلفا نداریم؛ «شفافیت» = ترکیب رنگ با بک‌گراند)
#define  SL_HL_TF          PERIOD_M15   // تایم‌فریم محاسبه‌ی High/Low سشن (مستقل از TF چارت)
int      g_slMode = SL_MODE_COMPACT;
string   GV_SESSLVL_MODE = "RM_SessLvlMode_" + _Symbol;
datetime g_slLastHLBar = 0;             // آخرین کندل M15 که EXPANDED با آن ساخته شد (بازسازی فقط با کندل جدید)
datetime g_slCullTime  = 0;             // مرز چپ ساخت باکس‌ها (۰ = بدون محدودیت)
#define  SESSLVL_HISTORY_DAYS 30
#define  SESSLVL_BOX_PREFIX   "RM9RC_SL_"
#define  SESSLVL_LBL_PREFIX   "RM9LB_SL_"
string   g_slBoxNames[];
string   g_slLblNames[];
int      g_slLane[];
int      g_slObjCount = 0;

// [Stage 5d - same DST translation as IsUSDST_UTC() above, independently re-implemented per source
// (v57 comment: "IsUSDST_UTC is not an authoritative source for this")]
bool SessionLevel_IsUSDST(datetime utcTime)
{
   MqlDateTime dtY; TimeToStruct(utcTime, dtY);
   int y = dtY.year;

   datetime marchFirst = StringToTime(IntegerToString(y)+".03.01 00:00");
   MqlDateTime dtM; TimeToStruct(marchFirst, dtM);
   int dowM = dtM.day_of_week;
   int firstSunM  = (dowM==0) ? 1 : (8-dowM);
   int secondSunM = firstSunM + 7;
   datetime dstStart = StringToTime(IntegerToString(y)+".03."+IntegerToString(secondSunM)+" 07:00");

   datetime novFirst = StringToTime(IntegerToString(y)+".11.01 00:00");
   MqlDateTime dtN; TimeToStruct(novFirst, dtN);
   int dowN = dtN.day_of_week;
   int firstSunN  = (dowN==0) ? 1 : (8-dowN);
   datetime dstEnd = StringToTime(IntegerToString(y)+".11."+IntegerToString(firstSunN)+" 06:00");

   return (utcTime >= dstStart && utcTime < dstEnd);
}

void SessionLevel_GetNYDate(int daysAgo, int &y, int &m, int &d)
{
   datetime nowUTC = ST_NowUTC();   // v75.0 (P0-1)
   bool nowDst = SessionLevel_IsUSDST(nowUTC);
   int nowNyOffSec = nowDst ? (-4*3600) : (-5*3600);
   datetime nowNY = nowUTC + nowNyOffSec;
   datetime targetNY = nowNY - ((datetime)daysAgo)*86400;
   MqlDateTime dt; TimeToStruct(targetNY, dt);
   y = dt.year; m = dt.mon; d = dt.day;
}

// v75.1 (MT4 v107 FEAT-060): + پارامتر بازار (پیش‌فرض NY). ساعت‌ها = ساعت محلی همان بازار، DST همان بازار (per-day).
void SessionLevel_ComputeServerTime(int daysAgo, int nyStartH, int nyStartM, int nyEndH, int nyEndM, datetime &outStart, datetime &outEnd, int mkt = ST_MKT_NY)
{
   if(mkt == ST_MKT_NY) ST_ComputeSessionByDaysAgo(daysAgo, nyStartH, nyStartM, nyEndH, nyEndM, outStart, outEnd);
   else                 ST_ComputeSessionByDaysAgoMkt(daysAgo, mkt, nyStartH, nyStartM, nyEndH, nyEndM, outStart, outEnd);
}

// [Stage 5d] TimeHour()/TimeMinute() (MT4-only) -> TimeToStruct()+.hour/.min - the SAME translation
// pattern as the DST functions above, found and applied here too (not explicitly named in the task's
// warning, but the identical underlying issue).
string SessionLevel_TagForTime(datetime serverTime)
{
   int serverOffsetSec = ST_ServerOffsetSec();   // v75.0 (P0-1): آفست پایدار به‌جای TimeCurrent()-TimeGMT() خام
   datetime utcTime = serverTime - serverOffsetSec;
   bool dst = SessionLevel_IsUSDST(utcTime);
   int nyOffsetSec = dst ? (-4*3600) : (-5*3600);
   datetime nyTime = utcTime + nyOffsetSec;

   MqlDateTime dtNy; TimeToStruct(nyTime, dtNy);
   int nyMinutes = dtNy.hour*60 + dtNy.min;

   bool inTokyo  = (nyMinutes>=1200 || nyMinutes<300);
   bool inLondon = (nyMinutes>=180  && nyMinutes<720);
   bool inNY     = (nyMinutes>=540  && nyMinutes<1080);

   if(!inTokyo && !inLondon && !inNY)
      return "OUT OF TRADING SESSION";

   int elapsedTokyo  = inTokyo  ? (((nyMinutes-1200)%1440+1440)%1440) : 999999;
   int elapsedLondon = inLondon ? (((nyMinutes-180) %1440+1440)%1440) : 999999;
   int elapsedNY     = inNY     ? (((nyMinutes-540) %1440+1440)%1440) : 999999;

   if(elapsedNY<=elapsedLondon && elapsedNY<=elapsedTokyo) return "NewYork";
   if(elapsedLondon<=elapsedTokyo)                         return "London";
   return "Tokyo";
}

// [Stage 5d] MT4's implicit Time[] series array (ArraySize(Time), Time[0]) has no MQL5 equivalent -
// translated to iTime(_Symbol, PERIOD_CURRENT, 0) with a Bars()>0 readiness check, the same pattern
// already established for candle-timer/H-L functions above.
void SessionLevel_EnsureChartShift(datetime latestObjTime)
{
   if(Bars(_Symbol, PERIOD_CURRENT) <= 0) return;
   datetime latestBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(latestObjTime <= latestBarTime) return;
   if(ChartGetInteger(0, CHART_SHIFT) == 0)
      ChartSetInteger(0, CHART_SHIFT, true);
   double shiftSize = ChartGetDouble(0, CHART_SHIFT_SIZE);
   if(shiftSize < 20)
      ChartSetDouble(0, CHART_SHIFT_SIZE, 20);
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

void GetSessionLevelPriceRange(int lane, double &priceTop, double &priceBot)
{
   int chartH      = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int xPix        = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2;
   int boxHPx      = 6;
   int laneGapPx   = 2;
   int keyTimeGapPx= 14;
   int marginBotPx = 20 + keyTimeGapPx + lane*(boxHPx+laneGapPx);

   int subWinBot = -1, subWinTop = -1;
   datetime tDummy = 0;
   bool okBot = ChartXYToTimePrice(0, xPix, chartH-marginBotPx,        subWinBot, tDummy, priceBot);
   bool okTop = ChartXYToTimePrice(0, xPix, chartH-marginBotPx-boxHPx, subWinTop, tDummy, priceTop);

   if(!okBot || !okTop || subWinBot!=0 || subWinTop!=0)
   {
      double pMax = ChartGetDouble(0, CHART_PRICE_MAX);
      double pMin = ChartGetDouble(0, CHART_PRICE_MIN);
      double range = pMax - pMin;
      if(range <= 0) { priceTop = SymbolInfoDouble(_Symbol,SYMBOL_BID); priceBot = priceTop; return; }
      double laneStep = 0.01;
      priceBot = pMin + range*(0.06 + lane*laneStep);
      priceTop = pMin + range*(0.07 + lane*laneStep);
   }
}

int SessionLevel_LaneForLabel(string label)
{
   if(label=="Tokyo")  return 2;
   if(label=="London") return 1;
   return 0;
}

// High/Low واقعی بازه‌ی [t1,t2) (تا «الان» اگر سشن هنوز تمام نشده) از کندل‌های SL_HL_TF.
// false = سشن هنوز شروع نشده / دیتای تاریخچه کافی نیست -> باکس ساخته نمی‌شود.
bool SessionLevel_GetHL(datetime t1, datetime t2, double &hi, double &lo)
{
   datetime nowT = TimeCurrent();
   if(t1 >= nowT) return(false);
   int bars = iBars(_Symbol, SL_HL_TF);
   if(bars <= 0) return(false);
   if(iTime(_Symbol, SL_HL_TF, bars - 1) > t1) return(false);
   datetime tEnd = (t2 < nowT) ? t2 : nowT;
   int sOld = iBarShift(_Symbol, SL_HL_TF, t1, false);        // اندیس بزرگ‌تر = قدیمی‌تر
   int sNew = iBarShift(_Symbol, SL_HL_TF, tEnd - 1, false);
   if(sOld < 0 || sNew < 0) return(false);
   if(sOld > sNew && iTime(_Symbol, SL_HL_TF, sOld) < t1) sOld--;   // کندل قبل از شروع (شکاف بازار) حساب نشود
   if(sOld < sNew) return(false);
   int cnt = sOld - sNew + 1;
   int ih = iHighest(_Symbol, SL_HL_TF, MODE_HIGH, cnt, sNew);
   int il = iLowest (_Symbol, SL_HL_TF, MODE_LOW,  cnt, sNew);
   if(ih < 0 || il < 0) return(false);
   hi = iHigh(_Symbol, SL_HL_TF, ih);
   lo = iLow (_Symbol, SL_HL_TF, il);
   return(hi > lo);
}

// رنگ EXPANDED: توکیو زرد، لندن سبز، نیویورک آبی - ترکیب‌شده با بک‌گراند چارت (باکس پشت کندل‌هاست).
color SessionLevel_ExpandedColor(string label, bool forText)
{
   color base = (label=="Tokyo") ? clrYellow : ((label=="London") ? clrLimeGreen : clrDodgerBlue);
   if(forText) return(base);
   color bg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   int bR=(int)(bg&0xFF), bG=(int)((bg>>8)&0xFF), bB=(int)((bg>>16)&0xFF);
   int fR=(int)(base&0xFF), fG=(int)((base>>8)&0xFF), fB=(int)((base>>16)&0xFF);
   int r = bR + (int)((fR-bR)*SL_EXP_BLEND_PCT/100.0);
   int g = bG + (int)((fG-bG)*SL_EXP_BLEND_PCT/100.0);
   int b = bB + (int)((fB-bB)*SL_EXP_BLEND_PCT/100.0);
   return((color)(r | (g<<8) | (b<<16)));
}

// حالت EXPANDED: باکس پر High..Low سشن پشت کندل‌ها؛ lane=-1 یعنی «قیمت ثابت» (UpdateVertical دستش نمی‌زند).
void SessionLevel_BuildOneBoxExpanded(int daysAgo, string label, datetime t1, datetime t2)
{
   double hi, lo;
   if(!SessionLevel_GetHL(t1, t2, hi, lo)) return;
   SessionLevel_EnsureChartShift(t2);
   string boxName = SESSLVL_BOX_PREFIX + label + "_" + IntegerToString(daysAgo);
   string lblName = SESSLVL_LBL_PREFIX + label + "_" + IntegerToString(daysAgo);
   color  cBox = SessionLevel_ExpandedColor(label, false);
   color  cTxt = SessionLevel_ExpandedColor(label, true);

   if(ObjectFind(0,boxName)<0) ObjectCreate(0,boxName,OBJ_RECTANGLE,0,t1,lo,t2,hi);
   ObjectSetInteger(0,boxName,OBJPROP_TIME,0,  t1);
   ObjectSetInteger(0,boxName,OBJPROP_TIME,1,  t2);
   ObjectSetDouble (0,boxName,OBJPROP_PRICE,0, lo);
   ObjectSetDouble (0,boxName,OBJPROP_PRICE,1, hi);
   ObjectSetInteger(0,boxName,OBJPROP_COLOR,  cBox);
   ObjectSetInteger(0,boxName,OBJPROP_FILL,   true);
   ObjectSetInteger(0,boxName,OBJPROP_BACK,   true);
   ObjectSetInteger(0,boxName,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,boxName,OBJPROP_WIDTH,  1);
   ObjectSetInteger(0,boxName,OBJPROP_STYLE,  STYLE_SOLID);

   datetime tMid = t1 + (t2-t1)/2;
   if(ObjectFind(0,lblName)<0) ObjectCreate(0,lblName,OBJ_TEXT,0,tMid,hi);
   ObjectSetInteger(0,lblName,OBJPROP_TIME,  tMid);
   ObjectSetDouble (0,lblName,OBJPROP_PRICE, hi);
   ObjectSetString (0,lblName,OBJPROP_TEXT,  label);
   ObjectSetInteger(0,lblName,OBJPROP_COLOR, cTxt);
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
   g_slLane[g_slObjCount]     = -1;
   g_slObjCount++;
}

void SessionLevel_BuildOneBox(int daysAgo, string label, int sh, int sm, int eh, int em, color c, int mkt = ST_MKT_NY)
{
   datetime t1, t2;
   SessionLevel_ComputeServerTime(daysAgo, sh, sm, eh, em, t1, t2, mkt);
   if(g_slCullTime > 0 && t2 < g_slCullTime) return;   // MT4 v95: باکس‌های کاملاً چپ ناحیه‌ی دیده‌شده ساخته نمی‌شوند
   if(g_slMode == SL_MODE_EXPANDED) { SessionLevel_BuildOneBoxExpanded(daysAgo, label, t1, t2); return; }
   SessionLevel_EnsureChartShift(t2);

   string boxName = SESSLVL_BOX_PREFIX + label + "_" + IntegerToString(daysAgo);
   string lblName = SESSLVL_LBL_PREFIX + label + "_" + IntegerToString(daysAgo);

   int lane = SessionLevel_LaneForLabel(label);
   double priceTop, priceBot;
   GetSessionLevelPriceRange(lane, priceTop, priceBot);

   if(ObjectFind(0,boxName)<0) ObjectCreate(0,boxName,OBJ_RECTANGLE,0,t1,priceBot,t2,priceTop);
   ObjectSetInteger(0,boxName,OBJPROP_TIME,0,  t1);
   ObjectSetInteger(0,boxName,OBJPROP_TIME,1,  t2);
   ObjectSetDouble (0,boxName,OBJPROP_PRICE,0, priceBot);
   ObjectSetDouble (0,boxName,OBJPROP_PRICE,1, priceTop);
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

void SessionLevel_BuildWindows()
{
   SessionLevel_RemoveWindows();
   if(!g_sessLvlOn) return;
   g_slCullTime = 0;   // MT4 v95: مرز چپ ناحیه‌ی دیده‌شده (یک روز حاشیه)
   int slFirstVis = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   if(slFirstVis >= 0 && slFirstVis < Bars(_Symbol, PERIOD_CURRENT))
   {
      datetime slLeftT = iTime(_Symbol, PERIOD_CURRENT, slFirstVis);
      if(slLeftT > 0) g_slCullTime = slLeftT - 86400;
   }
   g_slLastHLBar = iTime(_Symbol, SL_HL_TF, 0);   // v75.2 (FEAT-063)
   color boxColor = GetSessionLevelBoxColor();   // v75.5: رنگ Session Level مستقل از رنگ خاکستری R/R و Measure

   for(int daysAgo=-1; daysAgo<=SESSLVL_HISTORY_DAYS; daysAgo++)
   {
      // v75.1 (MT4 v107 FEAT-060): ساعت محلی هر بازار با DST خودش: Tokyo 09:00-18:00 JST، London 08:00-17:00 لندن، NewYork 09:00-18:00 نیویورک
      SessionLevel_BuildOneBox(daysAgo, "Tokyo",    9,0, 18,0, boxColor, ST_MKT_TOKYO);
      SessionLevel_BuildOneBox(daysAgo, "London",   8,0, 17,0, boxColor, ST_MKT_LONDON);
      SessionLevel_BuildOneBox(daysAgo, "NewYork",  9,0, 18,0, boxColor, ST_MKT_NY);
   }
   ChartRedraw();
}

void SessionLevel_UpdateVertical()
{
   if(!g_sessLvlOn) return;
   // v74.1 (HF1 A1): same throttle as UpdateSessionWindowsVertical (3 s, only on visible-range change)
   static uint   slLastMs = 0;
   static double slLastMax = 0, slLastMin = 0;
   static int    slLastH = 0, slLastCnt = 0;
   if((int)(GetTickCount() - slLastMs) < 3000) return;
   slLastMs = GetTickCount();
   // v75.2 (MT4 v95): اگر کاربر بیشتر از مرز فعلی به عقب اسکرول کرده، باکس‌های قدیمی‌تر را دوباره بساز
   if(g_slCullTime > 0)
   {
      int slFv = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
      if(slFv >= 0 && slFv < Bars(_Symbol, PERIOD_CURRENT))
      {
         datetime slLt = iTime(_Symbol, PERIOD_CURRENT, slFv);
         if(slLt > 0 && slLt - 86400 < g_slCullTime) { SessionLevel_BuildWindows(); return; }
      }
   }
   // v75.2 (FEAT-063): EXPANDED - باکس‌ها قیمت واقعی دارند؛ فقط با کندل M15 جدید High/Low سشن در جریان بازسازی می‌شود
   if(g_slMode == SL_MODE_EXPANDED)
   {
      datetime hlBar = iTime(_Symbol, SL_HL_TF, 0);
      if(hlBar != g_slLastHLBar) SessionLevel_BuildWindows();
      return;
   }
   if(g_slObjCount<=0) return;
   double slMax = ChartGetDouble(0, CHART_PRICE_MAX), slMin = ChartGetDouble(0, CHART_PRICE_MIN);
   int    slH   = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(slMax==slLastMax && slMin==slLastMin && slH==slLastH && g_slObjCount==slLastCnt) return;
   slLastMax = slMax; slLastMin = slMin; slLastH = slH; slLastCnt = g_slObjCount;
   double laneTop[3] = {0,0,0}, laneBot[3] = {0,0,0};
   for(int L=0; L<3; L++) GetSessionLevelPriceRange(L, laneTop[L], laneBot[L]);
   for(int i=0; i<g_slObjCount; i++)
   {
      int lane = g_slLane[i];
      if(lane<0 || lane>2) lane=0;
      if(ObjectFind(0,g_slBoxNames[i])>=0)
      {
         ObjectSetDouble(0,g_slBoxNames[i],OBJPROP_PRICE,0, laneBot[lane]);
         ObjectSetDouble(0,g_slBoxNames[i],OBJPROP_PRICE,1, laneTop[lane]);
      }
      if(ObjectFind(0,g_slLblNames[i])>=0)
         ObjectSetDouble(0,g_slLblNames[i],OBJPROP_PRICE, laneTop[lane]);
   }
}

void SessionLevel_SaveState()
{
   GlobalVariableSet(GV_SESSLVL_ON, g_sessLvlOn ? 1.0 : 0.0);
   GlobalVariableSet(GV_SESSLVL_MODE, (double)g_slMode);   // v75.2 (FEAT-063)
}

void SessionLevel_LoadState()
{
   if(GlobalVariableCheck(GV_SESSLVL_ON))
      g_sessLvlOn = (GlobalVariableGet(GV_SESSLVL_ON) != 0.0);
   // نبودن GV = COMPACT = رفتار قبلی
   g_slMode = (GlobalVariableCheck(GV_SESSLVL_MODE) && (int)GlobalVariableGet(GV_SESSLVL_MODE) == SL_MODE_EXPANDED) ? SL_MODE_EXPANDED : SL_MODE_COMPACT;
}

//+------------------------------------------------------------------+
//| v57 (فیچر جدید مستقل): Entry/Exit Markers                          |
//+------------------------------------------------------------------+
bool     g_markersOn = false;
string   GV_MARKERS_ON = "RM_MarkersOn_" + _Symbol;
#define  MARK_HISTORY_DAYS  30
#define  MARK_ENTRY_PREFIX  "RM9AR_ENT_"
#define  MARK_EXIT_PREFIX   "RM9AR_EXIT_"
#define  MARK_LINE_PREFIX   "RM9TL_MARK_"
string   g_markObjNames[];
int      g_markObjCount = 0;

// [Stage 5d] ticket type ulong throughout, same established pattern as every prior stage.
ulong g_markLabelShownTickets[];
int g_markLabelShownCount = 0;
#define  MARK_LBL_ENTRY_PREFIX  "RM9LB_ENT_"
#define  MARK_LBL_EXIT_PREFIX   "RM9LB_EXIT_"

bool IsMarkLabelShown(ulong ticket)
{
   for(int i=0;i<g_markLabelShownCount;i++)
      if(g_markLabelShownTickets[i]==ticket) return true;
   return false;
}

void ToggleMarkTicketLabel(ulong ticket)
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
   if(g_histOn) History_SetHollow(ticket, nowShown);   // v75.11 (MT4 v100 FEAT-046): لیبل روشن = باکس‌ها توخالی
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

void EntryExitMarkers_BuildTicketLabel(string name, ulong ticket, datetime t, double p, color c, bool anchorAbove)
{
   double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);
   double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
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
   ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES, IsMarkLabelShown(ticket) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
   EntryExitMarkers_Track(name);
}

void EntryExitMarkers_BuildEntry(ulong ticket, datetime openT, double openP, bool isBuy, color entryColor)
{
   string name = MARK_ENTRY_PREFIX + IntegerToString(ticket);
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,openT,openP);
   ObjectSetInteger(0,name,OBJPROP_TIME,  openT);
   ObjectSetDouble (0,name,OBJPROP_PRICE, openP);
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE, isBuy ? 233 : 234);
   ObjectSetInteger(0,name,OBJPROP_COLOR,  entryColor);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,  2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,name,OBJPROP_BACK,   false);
   EntryExitMarkers_Track(name);

   EntryExitMarkers_BuildTicketLabel(MARK_LBL_ENTRY_PREFIX+IntegerToString(ticket), ticket, openT, openP, entryColor, isBuy);
}

void EntryExitMarkers_BuildExit(ulong ticket, datetime closeT, double closeP, bool isBuy, color exitColor)
{
   string name = MARK_EXIT_PREFIX + IntegerToString(ticket);
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,closeT,closeP);
   ObjectSetInteger(0,name,OBJPROP_TIME,  closeT);
   ObjectSetDouble (0,name,OBJPROP_PRICE, closeP);
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE, isBuy ? 234 : 233);
   ObjectSetInteger(0,name,OBJPROP_COLOR,  exitColor);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,  2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,name,OBJPROP_BACK,   false);
   EntryExitMarkers_Track(name);

   EntryExitMarkers_BuildTicketLabel(MARK_LBL_EXIT_PREFIX+IntegerToString(ticket), ticket, closeT, closeP, exitColor, !isBuy);
}

void EntryExitMarkers_BuildLine(ulong ticket, datetime t1, double p1, datetime t2, double p2)
{
   string name = MARK_LINE_PREFIX + IntegerToString(ticket);
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,  t1);
   ObjectSetDouble (0,name,OBJPROP_PRICE,0, p1);
   ObjectSetInteger(0,name,OBJPROP_TIME,1,  t2);
   ObjectSetDouble (0,name,OBJPROP_PRICE,1, p2);
   ObjectSetInteger(0,name,OBJPROP_COLOR,  C'130,130,140');
   ObjectSetInteger(0,name,OBJPROP_STYLE,  STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,  1);
   ObjectSetInteger(0,name,OBJPROP_RAY,    false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,name,OBJPROP_BACK,   true);
   EntryExitMarkers_Track(name);
}

// [Stage 5d - deal-based history translation, same mapping decision as CheckClosedTrades()/
// CalcTradingReportStats() (Stage 4/5b)] MT4's OrdersHistoryTotal()/OrderSelect(MODE_HISTORY) loop
// treated one order ticket as one trade - Half Close created a second, distinct MT4 ticket, so each
// physically showed its own entry/exit arrow pair (both entries at the same point, two separate
// exit points - the partial-close price and the final-close price). MT5 doesn't split tickets on
// partial close, so a Half-Closed position is one ticket with possibly 2+ OUT deals. Applying the
// established "one position = one classification event" collapsing here means a half-closed
// position now gets exactly ONE entry marker and ONE exit marker (at the position's FINAL close,
// using the last OUT deal) instead of MT4's two exit markers (one per partial close event). This is
// a genuine, deliberate visual behavior difference from MT4 - flagged explicitly, not silently
// dropped - consistent with the same "trader's one decision, not one per fill" philosophy already
// established for CalcTradingReportStats(). Open price/time and direction come from the position's
// IN deal (same reliable-magic reasoning as Stage 4/5b).
void BuildEntryExitMarkers()
{
   RemoveEntryExitMarkers();
   if(g_rmPerfLog) Print("[DEBUG-MARKERS] BuildEntryExitMarkers enter, g_markersOn=", g_markersOn);
   if(!g_markersOn) return;

   color entryColor = C'30,144,255';
   color exitColor  = C'220,60,60';
   datetime cutoff = TimeCurrent() - ((datetime)MARK_HISTORY_DAYS)*86400;

   bool histOk = HistorySelect(cutoff, TimeCurrent());
   if(g_rmPerfLog) Print("[DEBUG-MARKERS] HistorySelect(", cutoff, ",", TimeCurrent(), ") = ", histOk,
         " HistoryDealsTotal=", HistoryDealsTotal());
   if(histOk)
   {
      // Pass 1: collect candidate OUT deals for this symbol, under the wide selection. Also capture
      // each deal's DEAL_POSITION_ID right here, while the wide HistorySelect() is still the active
      // selection - reading it later, inside Pass 2, after HistorySelectByPosition() has already
      // narrowed the selection for an earlier position, returns 0/garbage for deals outside that
      // narrowed scope. Same root cause as the Stage 4/5b DEAL_POSITION_ID finding, just not yet
      // applied here - found live during Stage 5d testing (Mahmoud), fixed now.
      ulong outDeals[]; ArrayResize(outDeals,0);
      ulong outDealPosIds[]; ArrayResize(outDealPosIds,0);
      int total = HistoryDealsTotal();
      for(int i=0;i<total;i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket==0) continue;
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
         long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         if(dealType!=DEAL_TYPE_BUY && dealType!=DEAL_TYPE_SELL) continue;
         if(HistoryDealGetString(dealTicket, DEAL_SYMBOL)!=_Symbol) continue;
         int n=ArraySize(outDeals); ArrayResize(outDeals,n+1); outDeals[n]=dealTicket;
         ArrayResize(outDealPosIds,n+1); outDealPosIds[n]=(ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      }
      if(g_rmPerfLog) Print("[DEBUG-MARKERS] Pass1 outDeals found=", ArraySize(outDeals));

      // Pass 2: collapse by position - one position = one entry/exit marker pair, using the LAST
      // OUT deal per position for the exit point (see header comment above).
      ulong seenPosIds[]; ArrayResize(seenPosIds,0);
      for(int oi=0; oi<ArraySize(outDeals); oi++)
      {
         ulong posId = outDealPosIds[oi];
         bool already=false;
         for(int s=0;s<ArraySize(seenPosIds);s++) if(seenPosIds[s]==posId) { already=true; break; }
         if(already) continue;
         int n=ArraySize(seenPosIds); ArrayResize(seenPosIds,n+1); seenPosIds[n]=posId;

         if(!HistorySelectByPosition(posId)) continue;
         int posDeals = HistoryDealsTotal();
         bool oursOpen=false; bool isBuy=true;
         datetime openT=0, closeT=0; double openP=0, closeP=0;
         for(int d=0; d<posDeals; d++)
         {
            ulong pd = HistoryDealGetTicket(d);
            if(pd==0) continue;
            if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_IN)
            {
               if(HistoryDealGetInteger(pd, DEAL_MAGIC)==MagicNumber) oursOpen=true;
               isBuy = (HistoryDealGetInteger(pd, DEAL_TYPE)==DEAL_TYPE_BUY);
               openT = (datetime)HistoryDealGetInteger(pd, DEAL_TIME);
               openP = HistoryDealGetDouble(pd, DEAL_PRICE);
            }
            else if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_OUT)
            {
               datetime dt = (datetime)HistoryDealGetInteger(pd, DEAL_TIME);
               if(dt>=closeT) { closeT=dt; closeP=HistoryDealGetDouble(pd, DEAL_PRICE); }
            }
         }
         if(!oursOpen) continue;

         EntryExitMarkers_BuildEntry(posId, openT, openP, isBuy, entryColor);
         EntryExitMarkers_BuildExit (posId, closeT, closeP, isBuy, exitColor);
         EntryExitMarkers_BuildLine (posId, openT, openP, closeT, closeP);
         if(g_rmPerfLog) Print("[DEBUG-MARKERS] Built closed-position marker pair, posId=", posId,
               " openP=", openP, " closeP=", closeP);
      }
   }

   int openTotal = PositionsTotal();
   if(g_rmPerfLog) Print("[DEBUG-MARKERS] Open positions to mark (entry-only)=", openTotal);
   for(int i=0; i<openTotal; i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;

      datetime openT = (datetime)PositionGetInteger(POSITION_TIME);
      double   openP = PositionGetDouble(POSITION_PRICE_OPEN);
      bool     isBuy = (posType==POSITION_TYPE_BUY);

      EntryExitMarkers_BuildEntry(tk, openT, openP, isBuy, entryColor);
   }

   ChartRedraw();
}


//+------------------------------------------------------------------+
//| v75.11 (پورت MT4 v85/v89/v90/v100 FEAT-046): History - باکس‌های معاملات بسته‌شده |
//+------------------------------------------------------------------+
// دکمه‌ی HISTORY (Utility، نیمه‌ی راست ردیف BE REF LINE). روشن: برای هر «پوزیشن» بسته‌شده‌ی همین نماد/مجیک که
// CloseTime اش در HistoryDaysBack روز اخیر است، دو OBJ_RECTANGLE: روشن = ورود تا TP، تیره = ورود تا SL.
// عرض = اولین Deal ورود تا آخرین Deal خروج. در MT5 هر پوزیشن (حتی با Half Close) = یک زنجیره = یک جفت باکس؛ پوزیشنی که
// هنوز بازه (حتی نیمه‌باز) رسم نمی‌شود.
//   Entry = قیمت Deal ورود؛ TP = DEAL_TP آخرین Deal خروج؛
//   SL = SL اولیه‌ی Snapshot (ریسک واقعی)، وگرنه DEAL_SL آخرین Deal خروج (SL بعد از BE/Trailing ممکنه وارونه باشد).
// TP/SL صفر (یا روی ورود) = آن باکس رسم نمی‌شود.
#define HIST_BOX_PREFIX "RM9HIST_"
bool     g_histOn        = false;
string   GV_HIST_ON      = "";   // در History_LoadState ساخته می‌شود
long     g_histLastSig   = -1;
int      g_histDrawn     = 0;
ulong    g_histHollowRoots[];
int      g_histHollowCount = 0;

void History_SaveState()
{
   if(StringLen(GV_HIST_ON)==0) GV_HIST_ON = "RM_HistOn_A" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + _Symbol;
   GlobalVariableSet(GV_HIST_ON, g_histOn ? 1.0 : 0.0);
}

void History_LoadState()
{
   GV_HIST_ON = "RM_HistOn_A" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + _Symbol;
   if(GlobalVariableCheck(GV_HIST_ON)) g_histOn = (GlobalVariableGet(GV_HIST_ON) != 0.0);
}

void History_Remove()
{
   ObjectsDeleteAll(0, HIST_BOX_PREFIX);
   g_histDrawn = 0;
}

// کنتراست خودکار نسبت به بک‌گراند (همان منطق MT4)
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

bool History_IsHollow(ulong root)
{
   for(int i=0;i<g_histHollowCount;i++)
      if(g_histHollowRoots[i]==root) return true;
   return false;
}

void History_ApplyHollowStyle(string name, bool hollow)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetInteger(0, name, OBJPROP_FILL,  !hollow);
   ObjectSetInteger(0, name, OBJPROP_BACK,  !hollow);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, hollow ? 2 : 1);
}

// کلیک روی مارکر Entry/Exit یک معامله: باکس‌های آن توخالی/پر می‌شوند (لیبل تیکت روشن = توخالی)
void History_SetHollow(ulong root, bool hollow)
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
   string baseName = HIST_BOX_PREFIX + IntegerToString((long)root);
   History_ApplyHollowStyle(baseName + "_TP", hollow);
   History_ApplyHollowStyle(baseName + "_SL", hollow);
}

void History_DrawBox(string name, datetime t1, double p1, datetime t2, double p2, color c)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
   ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR,  c);
   ObjectSetInteger(0, name, OBJPROP_FILL,   true);
   ObjectSetInteger(0, name, OBJPROP_BACK,   true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,  1);
   ObjectSetInteger(0, name, OBJPROP_STYLE,  STYLE_SOLID);
}

// امضای پوزیشن‌های باز این نماد/مجیک: تغییرش = معامله‌ی تازه باز/بسته شد
long History_OpenSig()
{
   long sig = 0; int cnt = 0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      sig += (long)tk; cnt++;
   }
   return sig*16 + cnt;
}

bool History_PositionIsOpen(ulong posId)
{
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==posId) return true;
   }
   return false;
}

void History_Build()
{
   History_Remove();
   g_histLastSig = History_OpenSig();
   if(!g_histOn) return;

   int days = (int)MathMax(1, HistoryDaysBack);
   datetime fromTime = TimeCurrent() - (datetime)days * 86400;

   color cLight, cDark;
   History_GetColors(cLight, cDark);
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0) pt = _Point;

   // Pass 1: شناسه‌ی پوزیشن‌هایی که Deal خروجشان در بازه است (قبل از HistorySelectByPosition جمع می‌شود - همان درس v74.1 HF1)
   ulong posIds[]; ArrayResize(posIds, 0);
   if(!HistorySelect(fromTime, TimeCurrent() + 86400)) return;
   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
   {
      ulong dt = HistoryDealGetTicket(i);
      if(dt==0) continue;
      if(HistoryDealGetInteger(dt, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      long ty = HistoryDealGetInteger(dt, DEAL_TYPE);
      if(ty!=DEAL_TYPE_BUY && ty!=DEAL_TYPE_SELL) continue;
      if(HistoryDealGetString(dt, DEAL_SYMBOL)!=_Symbol) continue;
      ulong pid = (ulong)HistoryDealGetInteger(dt, DEAL_POSITION_ID);
      bool dup = false;
      for(int q=0; q<ArraySize(posIds); q++) if(posIds[q]==pid){ dup=true; break; }
      if(dup) continue;
      int n = ArraySize(posIds); ArrayResize(posIds, n+1); posIds[n] = pid;
   }

   // Pass 2: هر پوزیشن
   for(int p=0; p<ArraySize(posIds); p++)
   {
      ulong posId = posIds[p];
      if(History_PositionIsOpen(posId)) continue;           // هنوز (نیمه‌)باز: باکس ندارد
      if(!HistorySelectByPosition(posId)) continue;
      int pd = HistoryDealsTotal();
      bool oursOpen = false;
      datetime openT = 0, closeT = 0;
      double entry = 0, tp = 0, sl = 0;
      for(int d=0; d<pd; d++)
      {
         ulong dk = HistoryDealGetTicket(d);
         if(dk==0) continue;
         long en = HistoryDealGetInteger(dk, DEAL_ENTRY);
         datetime t = (datetime)HistoryDealGetInteger(dk, DEAL_TIME);
         if(en==DEAL_ENTRY_IN)
         {
            if(HistoryDealGetInteger(dk, DEAL_MAGIC)==MagicNumber) oursOpen = true;
            if(openT==0 || t < openT){ openT = t; entry = HistoryDealGetDouble(dk, DEAL_PRICE); }
         }
         else if(en==DEAL_ENTRY_OUT && t >= closeT)
         {
            closeT = t;
            tp = HistoryDealGetDouble(dk, DEAL_TP);
            sl = HistoryDealGetDouble(dk, DEAL_SL);
         }
      }
      if(!oursOpen || openT==0 || closeT==0) continue;
      if(closeT < fromTime) continue;

      int snap = FindSnapshotIndex(posId);
      if(snap >= 0 && MathAbs(g_snapEntry[snap] - g_snapSL[snap]) > 0)
      {
         sl = g_snapSL[snap];
         if(g_snapEntry[snap] > 0) entry = g_snapEntry[snap];
      }

      datetime t2 = closeT;
      if(t2 <= openT) t2 = openT + (datetime)MathMax(60, PeriodSeconds());
      string baseName = HIST_BOX_PREFIX + IntegerToString((long)posId);
      if(tp > 0 && MathAbs(tp - entry) >= pt)
      {
         History_DrawBox(baseName + "_TP", openT, entry, t2, tp, cLight);
         if(History_IsHollow(posId)) History_ApplyHollowStyle(baseName + "_TP", true);
      }
      if(sl > 0 && MathAbs(sl - entry) >= pt)
      {
         History_DrawBox(baseName + "_SL", openT, entry, t2, sl, cDark);
         if(History_IsHollow(posId)) History_ApplyHollowStyle(baseName + "_SL", true);
      }
      g_histDrawn++;
   }
   ChartRedraw();
}

datetime g_histRebuildAt = 0;
void History_Refresh()
{
   if(!g_histOn) return;
   if(History_OpenSig() != g_histLastSig)
   {
      History_Build();
      g_histRebuildAt = TimeLocal() + 3;   // ثبت Deal در تاریخچه ممکن است چند ثانیه عقب بیفتد -> یک بازسازی دوم
   }
   else if(g_histRebuildAt > 0 && TimeLocal() >= g_histRebuildAt)
   {
      g_histRebuildAt = 0;
      History_Build();
   }
}

// [Stage 5d] MT4's implicit Time[0] -> iTime(_Symbol, PERIOD_CURRENT, 0), same pattern as
// SessionLevel_EnsureChartShift() above.
void RefreshEntryExitMarkers()
{
   // v74.1 (HF1 A1): rebuild on position open/close events (this symbol + magic), NOT on every new bar.
   // Signature = count + ticket sum of our open positions. A close is also rebuilt right away by
   // TakeExitScreenshot() in CheckClosedTrades; the user toggle rebuilds from the button handler.
   if(!g_markersOn) return;
   static long lastSig = -1;
   long sig = 0; int cnt = 0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      sig += (long)tk; cnt++;
   }
   sig = sig*16 + cnt;
   if(lastSig == -1) { lastSig = sig; return; }   // first call after load: OnInit / toggle already built
   if(sig != lastSig)
   {
      lastSig = sig;
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

void EnsureScreenshotFolder()
{
   if(!FolderCreate(SCREENSHOT_FOLDER))
      Print("RM_Tools: EnsureScreenshotFolder - FolderCreate('"+SCREENSHOT_FOLDER+"') failed, error ", GetLastError());
}

//+------------------------------------------------------------------+
//| v59 (Item 2): Chart Screenshot at Exit                             |
//+------------------------------------------------------------------+
string ExitScreenshot_Filename(ulong ticket)
{
   return "RM_ExitShot_" + IntegerToString(MagicNumber) + "_" + IntegerToString(ticket) + ".png";
}

string ExitScreenshot_RelativePath(ulong ticket)
{
   return SCREENSHOT_FOLDER + "\\" + ExitScreenshot_Filename(ticket);
}

// [Stage 5d] ChartScreenShot()/FolderCreate()/FileIsExist() confirmed identical API in MQL5 - direct
// port, no translation needed (per task's note). ticket param is now ulong.
void TakeExitScreenshot(ulong ticket)
{
   bool wasOn = g_markersOn;
   if(g_rmPerfLog) Print("[DEBUG-MARKERS] TakeExitScreenshot enter, ticket=", ticket, " wasOn=", wasOn);
   if(!wasOn)
      g_markersOn = true;

   BuildEntryExitMarkers();

   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(w<=0) w = 1024;
   if(h<=0) h = 768;
   ChartScreenShot(0, ExitScreenshot_RelativePath(ticket), w, h, ALIGN_RIGHT);

   if(!wasOn)
   {
      g_markersOn = false;
      RemoveEntryExitMarkers();
   }
   if(g_rmPerfLog) Print("[DEBUG-MARKERS] TakeExitScreenshot exit, ticket=", ticket, " g_markersOn now=", g_markersOn);
}

string GetExitScreenshotName(ulong ticket)
{
   string relPath = ExitScreenshot_RelativePath(ticket);
   if(FileIsExist(relPath)) return relPath;
   return "N/A";
}

//+------------------------------------------------------------------+
//| v56 (Trade Tagging - Strategy/Setup)                              |
//+------------------------------------------------------------------+
#define STRAT_FILE_NAME "RM_StrategySetups.txt"
#define TAG_FILE_NAME   "RM_TradeTags.csv"
// v74.2 (HF3, tag sharing): terminal-wide GlobalVariables shared by every chart running the EA.
#define GV_TAG_VER      "RM_TagFileVer"    // bumped on every tag-file write; other charts reload when it differs
#define GV_TAG_LOCK     "RM_TagFileLock"   // short write mutex (value = TimeLocal seconds, stale after 3 s)
#define TAG_WIN_PREFIX  "RM_TAG_"

string g_stratNames[];
string g_stratSetupsCSV[];
int    g_stratCount = 0;

// [Stage 5d] ticket type ulong throughout, same established pattern.
ulong  g_tagTickets[];
string g_tagStrategy[];
string g_tagSetup[];
string g_tagMentalState[];
int    g_tagCount = 0;
double g_tagLoadedVer = -1;   // v74.2 (HF3): GV_TAG_VER value this chart's in-memory tag list was loaded at

bool   g_tagWindowOpen      = false;
int    g_tagStep            = 0;
uint   g_tagLastObjClickMs  = 0;   // v74.1 (HF1 B5, MT4 v80 BUG-056): time of the last OBJECT_CLICK on the tag window
ulong  g_tagSelectedTicket  = 0;
string g_tagSelectedStrategy = "";
string g_tagSelectedMentalState = "";
ulong  g_tagTodayTickets[];

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
   int handle = FileOpen(STRAT_FILE_NAME, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
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

   int handle = FileOpen(STRAT_FILE_NAME, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE) return;

   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      StringTrimLeft(line); StringTrimRight(line);
      if(line=="") continue;

      int colonPos = StringFind(line, ":");
      if(colonPos<0) continue;

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

// v75.6 (پورت MT4 v80/v106/v107): لیست پیش‌فرض جدید + مهاجرت یک‌باره (با بکاپ). نسخه‌ی لیست در GV ترمینال‌محور.
#define STRAT_LIST_VERSION      107
#define GV_STRAT_LIST_VERSION   "RM_StratListVer"

// لیست پیش‌فرض - تنها منبع؛ هم seed اولیه هم مهاجرت یک‌باره از این می‌نویسند.
void WriteDefaultStrategySetups()
{
   int handle = FileOpen(STRAT_FILE_NAME, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE)
   {
      Print("RM_Tools: WriteDefaultStrategySetups - FileOpen failed, error ", GetLastError());
      return;
   }
   FileWrite(handle, "CYCLE_MATURITY: REJECTION_CANDLE, MTR_PB, MTR_LINE_BREAK, MTR_BREAKEVEN_RETEST, TR-BREAKOUT");
   FileWrite(handle, "SPIKE_TRADING: BREAKOUT_CANDLE, SP2L_FIRST_PB_CANDLE, SP2L_50, BTB");
   FileWrite(handle, "CHANNEL_TRADING: TREND_LINE_TOUCH, PREVIOUS_LEG_50, REJECTION_CANDLE");
   FileWrite(handle, "RANGE_TRADING: EDGE_LIMIT, REJECTION_CANDLE");
   FileClose(handle);
}

// فایل نیست -> لیست پیش‌فرض. فایل هست ولی نسخه‌ی GV قدیمی‌تر -> *یک‌بار* بکاپ (RM_StrategySetups_backup.txt) و
// جایگزینی با لیست جدید (اگر نسخه >= 106 باشد فقط TR-BREAKOUT اضافه می‌شود). بعد از آن ویرایش‌های دستی دست‌نخورده می‌مانند.
void EnsureStrategySetupsSeed()
{
   int  storedVer = GlobalVariableCheck(GV_STRAT_LIST_VERSION) ? (int)GlobalVariableGet(GV_STRAT_LIST_VERSION) : 0;
   bool haveVer   = (storedVer >= STRAT_LIST_VERSION);

   if(!FileIsExist(STRAT_FILE_NAME))
   {
      WriteDefaultStrategySetups();
      GlobalVariableSet(GV_STRAT_LIST_VERSION, STRAT_LIST_VERSION);
   }
   else if(!haveVer)
   {
      if(!FileCopy(STRAT_FILE_NAME, 0, "RM_StrategySetups_backup.txt", FILE_REWRITE))
         Print("RM_Tools: strategy list backup failed, error ", GetLastError());
      if(storedVer >= 106)
      {
         LoadStrategySetupsFile();
         AddSetupIfMissing("CYCLE_MATURITY", "TR-BREAKOUT");
         Print("RM_Tools: strategy list migrated to v", STRAT_LIST_VERSION, " (added TR-BREAKOUT only; backup in RM_StrategySetups_backup.txt)");
      }
      else
      {
         WriteDefaultStrategySetups();
         Print("RM_Tools: strategy list migrated to v", STRAT_LIST_VERSION, " default (old file backed up to RM_StrategySetups_backup.txt)");
      }
      GlobalVariableSet(GV_STRAT_LIST_VERSION, STRAT_LIST_VERSION);
   }
   LoadStrategySetupsFile();
}

int FindStrategyIndex(string name)
{
   for(int i=0;i<g_stratCount;i++)
      if(g_stratNames[i]==name) return i;
   return -1;
}

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

void AddSetupIfMissing(string stratName, string setupName)
{
   if(setupName=="") return;

   int idx = FindStrategyIndex(stratName);
   if(idx<0) idx = AddStrategyIfMissing(stratName);
   if(idx<0) return;

   string existing[];
   int n = GetSetupsForStrategy(stratName, existing);
   for(int i=0;i<n;i++)
      if(existing[i]==setupName) return;

   if(g_stratSetupsCSV[idx]=="") g_stratSetupsCSV[idx] = setupName;
   else                          g_stratSetupsCSV[idx] = g_stratSetupsCSV[idx] + ", " + setupName;

   SaveStrategySetupsFile();
}

//+------------------------------------------------------------------+
// فایل ۲: Ticket -> Strategy/Setup
//+------------------------------------------------------------------+
// v74.2 (HF3): short cross-chart write mutex (GlobalVariableSetOnCondition = atomic). A lock left behind
// by a crashed terminal is taken over after 3 s. Returns true if this chart now holds the lock.
bool TagLockAcquire()
{
   for(int i=0;i<40;i++)   // up to ~200 ms
   {
      double nowSec = (double)TimeLocal();
      if(!GlobalVariableCheck(GV_TAG_LOCK)) GlobalVariableSet(GV_TAG_LOCK, 0.0);
      if(GlobalVariableSetOnCondition(GV_TAG_LOCK, nowSec, 0.0)) return true;
      double held = GlobalVariableGet(GV_TAG_LOCK);
      if(held > 0 && nowSec - held > 3.0 && GlobalVariableSetOnCondition(GV_TAG_LOCK, nowSec, held)) return true;
      Sleep(5);
   }
   return false;
}
void TagLockRelease() { GlobalVariableSet(GV_TAG_LOCK, 0.0); }

void SaveTradeTagsFile()
{
   int handle = FileOpen(TAG_FILE_NAME, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE)
   {
      Print("RM_Tools: SaveTradeTagsFile - FileOpen failed, error ", GetLastError());
      return;
   }
   FileWrite(handle, "Ticket,Strategy,Setup,MentalState");
   for(int i=0;i<g_tagCount;i++)
      FileWrite(handle, IntegerToString(g_tagTickets[i]) + "," + g_tagStrategy[i] + "," + g_tagSetup[i] + "," + g_tagMentalState[i]);
   FileClose(handle);
   // v74.2 (HF3): announce the new file version AFTER it is completely written; this chart's own copy is current.
   double ver = (GlobalVariableCheck(GV_TAG_VER) ? GlobalVariableGet(GV_TAG_VER) : 0.0) + 1.0;
   GlobalVariableSet(GV_TAG_VER, ver);
   g_tagLoadedVer = ver;
}

void LoadTradeTagsFile()
{
   ArrayResize(g_tagTickets,     0);
   ArrayResize(g_tagStrategy,    0);
   ArrayResize(g_tagSetup,       0);
   ArrayResize(g_tagMentalState, 0);
   g_tagCount = 0;
   // v74.2 (HF3): remember which file version this load corresponds to (read BEFORE the file, so a write
   // that lands meanwhile just triggers one more reload next time).
   g_tagLoadedVer = GlobalVariableCheck(GV_TAG_VER) ? GlobalVariableGet(GV_TAG_VER) : 0.0;

   int handle = FileOpen(TAG_FILE_NAME, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE) return;

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
      if(n<3) continue;

      // [Stage 5d] (int)StringToInteger -> (ulong)StringToInteger, same cast-safety reasoning
      // established in Stage 5a's LoadTradeSnapshots() (StringToInteger returns a positive long for
      // a numeric ticket string; converting to ulong is lossless).
      ulong ticket = (ulong)StringToInteger(parts[0]);
      if(ticket<=0) continue;

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

// v74.2 (HF3): reload the tag file if another chart changed it since this chart last loaded it.
// Cheap (one GlobalVariableGet) when nothing changed; skipped while another chart is mid-write.
void SyncTagsIfChanged()
{
   double ver = GlobalVariableCheck(GV_TAG_VER) ? GlobalVariableGet(GV_TAG_VER) : 0.0;
   if(ver == g_tagLoadedVer) return;
   if(GlobalVariableCheck(GV_TAG_LOCK) && GlobalVariableGet(GV_TAG_LOCK) > 0 &&
      (double)TimeLocal() - GlobalVariableGet(GV_TAG_LOCK) <= 3.0) return;   // a writer is active - try next call
   LoadTradeTagsFile();
}

int FindTagIndexExact(ulong ticket)
{
   SyncTagsIfChanged();   // v74.2 (HF3): every lookup sees tags made on other charts
   for(int i=0;i<g_tagCount;i++)
      if(g_tagTickets[i]==ticket) return i;
   return -1;
}

// v75.13 (MT4 v86 FEAT-042): خواندن تگ از ریشه‌ی زنجیره - ورود ادامه (Scale-in) تگ ریشه‌ی خود را می‌خواند. اگر روی ریشه تگی نبود ولی روی خودِ پوزیشن
// تگ ثبت شده بود همان خوانده می‌شود.
int FindTagIndex(ulong ticket)
{
   ulong root = GetRootTicket(ticket);
   int idx = FindTagIndexExact(root);
   if(idx >= 0 || root == ticket) return idx;
   return FindTagIndexExact(ticket);
}

void SetTradeTag(ulong ticket, string strategy, string setup, string mentalState="")
{
   // v74.2 (HF3): lock -> reload latest -> modify -> save, so two charts never overwrite each other's tags.
   bool locked = TagLockAcquire();
   if(!locked) Print("[RM-TAGS] write lock busy - saving without lock");
   else if((GlobalVariableCheck(GV_TAG_VER) ? GlobalVariableGet(GV_TAG_VER) : 0.0) != g_tagLoadedVer)
      LoadTradeTagsFile();   // another chart wrote since our last load: take its version first (our own lock is held)
   ticket = GetRootTicket(ticket);   // v75.13 (MT4 v86): نوشتن همیشه روی ریشه - ویرایش تگ یک‌بار برای کل زنجیره
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
   if(locked) TagLockRelease();
}

string GetTagStrategy(ulong ticket) { int idx=FindTagIndex(ticket); return (idx>=0) ? g_tagStrategy[idx] : "N/A"; }
string GetTagSetup(ulong ticket)    { int idx=FindTagIndex(ticket); return (idx>=0) ? g_tagSetup[idx]    : "N/A"; }

string GetTagMentalStateRaw(ulong ticket) { int idx=FindTagIndex(ticket); return (idx>=0) ? g_tagMentalState[idx] : ""; }
string GetTagMentalState(ulong ticket)
{
   string raw = GetTagMentalStateRaw(ticket);
   return (raw=="") ? "N/A" : raw;
}

// === v75.14 (MT4 v81 FEAT-037 / P5): چک‌لیست کانتکست - ۵ چک‌باکس مستقل، ذخیره در RM_ContextTags.csv (Ticket -> ۵ Boolean) و متن گزینه‌ها
// در RM_ContextChecklist.txt (قابل‌ویرایش). مستقل از RM_TradeTags.csv و RM_StrategySetups.txt. روی ریشه‌ی زنجیره ذخیره/خوانده می‌شود (Scale-in).
#define CTX_FILE_NAME      "RM_ContextChecklist.txt"
#define CTX_TAG_FILE_NAME  "RM_ContextTags.csv"
#define GV_CTX_TAG_VER     "RM_CtxTagFileVer"          // با هر نوشتن فایل کانتکست بالا می‌رود؛ چارت‌های دیگر وقتی فرق کند دوباره می‌خوانند
#define CTX_CHECKLIST_VERSION    81
#define GV_CTX_CHECKLIST_VERSION "RM_CtxChecklistVer"

bool   g_ctxSelLevel  = false;
bool   g_ctxSelCycle  = false;
bool   g_ctxSelTime   = false;
bool   g_ctxSelCandle = false;
bool   g_ctxSelNone   = false;

// 0=LEVEL, 1=CYCLE, 2=TIME, 3=CANDLE, 4=NONE (ترتیب ثابت؛ فقط متن نمایشی از فایل می‌آید)
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
   CTX_SetDefaultLabels();   // فال‌بک اگر فایل/کلید نبود
   int handle = FileOpen(CTX_FILE_NAME, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE) return;
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

// فایل نیست -> seed؛ فایل قدیمی‌تر از این نسخه -> یک‌بار بکاپ + جایگزینی؛ وگرنه دست‌نخورده (ویرایش دستی محفوظ).
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

ulong  g_ctxTagTickets[];
bool   g_ctxTagLevel[];
bool   g_ctxTagCycle[];
bool   g_ctxTagTime[];
bool   g_ctxTagCandle[];
bool   g_ctxTagNone[];
int    g_ctxTagCount = 0;
double g_ctxTagLoadedVer = -1;

void SaveContextTagsFile()
{
   int handle = FileOpen(CTX_TAG_FILE_NAME, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
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
   double ver = (GlobalVariableCheck(GV_CTX_TAG_VER) ? GlobalVariableGet(GV_CTX_TAG_VER) : 0.0) + 1.0;   // بعد از کامل‌شدن فایل اعلام می‌شود
   GlobalVariableSet(GV_CTX_TAG_VER, ver);
   g_ctxTagLoadedVer = ver;
}

void LoadContextTagsFile()
{
   ArrayResize(g_ctxTagTickets, 0);
   ArrayResize(g_ctxTagLevel,   0);
   ArrayResize(g_ctxTagCycle,   0);
   ArrayResize(g_ctxTagTime,    0);
   ArrayResize(g_ctxTagCandle,  0);
   ArrayResize(g_ctxTagNone,    0);
   g_ctxTagCount = 0;
   g_ctxTagLoadedVer = GlobalVariableCheck(GV_CTX_TAG_VER) ? GlobalVariableGet(GV_CTX_TAG_VER) : 0.0;   // قبل از خواندن فایل

   int handle = FileOpen(CTX_TAG_FILE_NAME, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE) return;

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
      ulong ticket = (ulong)StringToInteger(parts[0]);
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

// اگر چارت دیگری فایل کانتکست را عوض کرده باشد دوباره می‌خواند (همان الگوی SyncTagsIfChanged؛ قفل نوشتن مشترک با تگ‌ها).
void SyncCtxTagsIfChanged()
{
   double ver = GlobalVariableCheck(GV_CTX_TAG_VER) ? GlobalVariableGet(GV_CTX_TAG_VER) : 0.0;
   if(ver == g_ctxTagLoadedVer) return;
   if(GlobalVariableCheck(GV_TAG_LOCK) && GlobalVariableGet(GV_TAG_LOCK) > 0 &&
      (double)TimeLocal() - GlobalVariableGet(GV_TAG_LOCK) <= 3.0) return;
   LoadContextTagsFile();
}

int FindCtxTagIndexExact(ulong ticket)
{
   SyncCtxTagsIfChanged();
   for(int i=0;i<g_ctxTagCount;i++)
      if(g_ctxTagTickets[i]==ticket) return i;
   return -1;
}

int FindCtxTagIndex(ulong ticket)
{
   ulong root = GetRootTicket(ticket);
   int idx = FindCtxTagIndexExact(root);
   if(idx >= 0 || root == ticket) return idx;
   return FindCtxTagIndexExact(ticket);
}

// هر ۵ فیلد با هم؛ lock -> آخرین نسخه -> تغییر -> ذخیره (دو چارت هم‌زمان همدیگر را بازنویسی نکنند).
void SetContextTag(ulong ticket, bool bLevel, bool bCycle, bool bTime, bool bCandle, bool bNone)
{
   bool locked = TagLockAcquire();
   if(!locked) Print("[RM-TAGS] write lock busy - saving context without lock");
   else if((GlobalVariableCheck(GV_CTX_TAG_VER) ? GlobalVariableGet(GV_CTX_TAG_VER) : 0.0) != g_ctxTagLoadedVer)
      LoadContextTagsFile();
   ticket = GetRootTicket(ticket);   // نوشتن روی ریشه‌ی زنجیره
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
   if(locked) TagLockRelease();
}

bool GetCtxLevelBool(ulong ticket)  { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagLevel[idx]  : false; }
bool GetCtxCycleBool(ulong ticket)  { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagCycle[idx]  : false; }
bool GetCtxTimeBool(ulong ticket)   { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagTime[idx]   : false; }
bool GetCtxCandleBool(ulong ticket) { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagCandle[idx] : false; }
bool GetCtxNoneBool(ulong ticket)   { int idx=FindCtxTagIndex(ticket); return (idx>=0) ? g_ctxTagNone[idx]   : false; }

// رشته‌ای برای CSV ژورنال: "true"/"false"؛ تریدی که چک‌لیست برایش انجام نشده = هر ۵ false
string GetCtxLevelStr(ulong ticket)  { return GetCtxLevelBool(ticket)  ? "true" : "false"; }
string GetCtxCycleStr(ulong ticket)  { return GetCtxCycleBool(ticket)  ? "true" : "false"; }
string GetCtxTimeStr(ulong ticket)   { return GetCtxTimeBool(ticket)   ? "true" : "false"; }
string GetCtxCandleStr(ulong ticket) { return GetCtxCandleBool(ticket) ? "true" : "false"; }
string GetCtxNoneStr(ulong ticket)   { return GetCtxNoneBool(ticket)   ? "true" : "false"; }

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
// لیست معاملات «امروز» (باز + بسته‌شده‌ی امروز) برای مرحله‌ی ۱ پنجره‌ی تگ‌گذاری
//+------------------------------------------------------------------+
// [Stage 5d - same deal-based collapsing decision as BuildEntryExitMarkers() above] a Half-Closed
// position now appears exactly ONCE in today's ticket list (not twice, as MT4's two-ticket split
// would have shown) - a natural side effect of position IDs staying constant across partial closes
// on MT5, requiring no explicit dedup code here (unlike CalcTradingReportStats(), which needed
// deliberate collapsing because MT4's history rows themselves were what needed merging).
int BuildTodayTicketList(string &labels[])
{
   ArrayResize(labels, 0);
   ArrayResize(g_tagTodayTickets, 0);
   int cnt = 0;

   int openTotal = PositionsTotal();
   for(int i=0;i<openTotal;i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;

      string lbl = "#"+IntegerToString(tk)+" "+PositionGetString(POSITION_SYMBOL)+" "+((posType==POSITION_TYPE_BUY)?"BUY":"SELL")+" (OPEN)";
      ArrayResize(labels, cnt+1);
      ArrayResize(g_tagTodayTickets, cnt+1);
      labels[cnt] = lbl;
      g_tagTodayTickets[cnt] = tk;
      cnt++;
   }

   if(HistorySelect(g_dayStart, TimeCurrent()))
   {
      ulong outDeals[]; ArrayResize(outDeals,0);
      ulong outDealPosIds[]; ArrayResize(outDealPosIds,0); // v74.1 (HF1 B5/B6): captured in Pass 1, under the wide selection
      int total = HistoryDealsTotal();
      for(int i=0;i<total;i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket==0) continue;
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
         long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         if(dealType!=DEAL_TYPE_BUY && dealType!=DEAL_TYPE_SELL) continue;
         int n=ArraySize(outDeals); ArrayResize(outDeals,n+1); outDeals[n]=dealTicket;
         ArrayResize(outDealPosIds,n+1); outDealPosIds[n]=(ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      }

      ulong seenPosIds[]; ArrayResize(seenPosIds,0);
      // v75.0 (P0-3، MT4 v80/BUG-056): جدیدترین بسته‌شده اول (قبلاً قدیمی‌ترین اول؛ پنجره‌ی Tag اسکرول ندارد و
      // تازه‌ترین معامله از پایین چارت بیرون می‌زد). outDeals به ترتیب زمان است، پس از آخر به اول می‌رویم.
      for(int oi=ArraySize(outDeals)-1; oi>=0; oi--)
      {
         ulong posId = outDealPosIds[oi]; // v74.1 (HF1 B5/B6): never read DEAL_POSITION_ID after HistorySelectByPosition
         bool already=false;
         for(int s=0;s<ArraySize(seenPosIds);s++) if(seenPosIds[s]==posId) { already=true; break; }
         if(already) continue;
         int n=ArraySize(seenPosIds); ArrayResize(seenPosIds,n+1); seenPosIds[n]=posId;

         // v75.0 (P0-3): پوزیشنی که هنوز باز است (Half Close شده) فقط یک‌بار و به‌صورت (OPEN) در لیست بالا آمده؛
         // دوباره به‌صورت (CLOSED) نیاید (ردیف تکراری). در هج، شماره‌ی پوزیشن = شماره‌ی تیکت باز.
         if(PositionSelectByTicket(posId)) continue;

         if(!HistorySelectByPosition(posId)) continue;
         int posDeals = HistoryDealsTotal();
         bool oursOpen=false; bool isBuy=true; string sym="";
         for(int d=0; d<posDeals; d++)
         {
            ulong pd = HistoryDealGetTicket(d);
            if(pd==0) continue;
            if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_IN)
            {
               if(HistoryDealGetInteger(pd, DEAL_MAGIC)==MagicNumber) oursOpen=true;
               isBuy = (HistoryDealGetInteger(pd, DEAL_TYPE)==DEAL_TYPE_BUY);
               sym = HistoryDealGetString(pd, DEAL_SYMBOL);
            }
         }
         if(!oursOpen) continue;

         string lbl = "#"+IntegerToString(posId)+" "+sym+" "+(isBuy?"BUY":"SELL")+" (CLOSED)";
         ArrayResize(labels, cnt+1);
         ArrayResize(g_tagTodayTickets, cnt+1);
         labels[cnt] = lbl;
         g_tagTodayTickets[cnt] = posId;
         cnt++;
      }
   }

   return cnt;
}

// [Stage 5d - same deal-based collapsing as BuildTodayTicketList() above]
// v74.1 (HF1 A1): cached wrapper. The result only changes when a deal is added (close), a position
// opens/closes, a tag is added or the day changes, so the history scan with one HistorySelectByPosition
// per closed position runs only then (checked at most once per second), not on every tick.
int CountUntaggedToday()
{
   static bool     cValid = false;
   static int      cVal   = 0;
   static datetime cDay   = 0;
   static int      cTag   = -1;
   static int      cPos   = -1;
   static int      cDeals = -1;
   static uint     cMs    = 0;

   SyncTagsIfChanged();   // v74.2 (HF3): pick up tags made on other charts before the cache key is compared
   int posNow = PositionsTotal();
   bool keyChanged = (!cValid || cDay != g_dayStart || cTag != g_tagCount || cPos != posNow);
   if(!keyChanged && (int)(GetTickCount() - cMs) < 1000) return cVal;
   cMs = GetTickCount();

   int dealsNow = -1;
   if(HistorySelect(g_dayStart, TimeCurrent())) dealsNow = HistoryDealsTotal();
   if(!keyChanged && dealsNow >= 0 && dealsNow == cDeals) return cVal;

   cVal   = CountUntaggedTodayCompute();
   cValid = (dealsNow >= 0);
   cDay   = g_dayStart; cTag = g_tagCount; cPos = posNow; cDeals = dealsNow;
   return cVal;
}

int CountUntaggedTodayCompute()
{
   int untagged = 0;
   int openTotal = PositionsTotal();
   for(int i=0;i<openTotal;i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      if(FindTagIndex(tk)<0) untagged++;
   }

   if(HistorySelect(g_dayStart, TimeCurrent()))
   {
      ulong outDeals[]; ArrayResize(outDeals,0);
      ulong outDealPosIds[]; ArrayResize(outDealPosIds,0); // v74.1 (HF1 B5/B6): captured in Pass 1, under the wide selection
      int total = HistoryDealsTotal();
      for(int i=0;i<total;i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket==0) continue;
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
         long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         if(dealType!=DEAL_TYPE_BUY && dealType!=DEAL_TYPE_SELL) continue;
         int n=ArraySize(outDeals); ArrayResize(outDeals,n+1); outDeals[n]=dealTicket;
         ArrayResize(outDealPosIds,n+1); outDealPosIds[n]=(ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      }

      ulong seenPosIds[]; ArrayResize(seenPosIds,0);
      for(int oi=0; oi<ArraySize(outDeals); oi++)
      {
         ulong posId = outDealPosIds[oi]; // v74.1 (HF1 B5/B6): never read DEAL_POSITION_ID after HistorySelectByPosition
         bool already=false;
         for(int s=0;s<ArraySize(seenPosIds);s++) if(seenPosIds[s]==posId) { already=true; break; }
         if(already) continue;
         int n=ArraySize(seenPosIds); ArrayResize(seenPosIds,n+1); seenPosIds[n]=posId;

         if(PositionSelectByTicket(posId)) continue;   // v75.0 (P0-3): پوزیشن باز-نیمه‌بسته قبلاً در حلقه‌ی بالا شمرده شده؛ دوباره نشمار

         if(!HistorySelectByPosition(posId)) continue;
         int posDeals = HistoryDealsTotal();
         bool oursOpen=false;
         for(int d=0; d<posDeals; d++)
         {
            ulong pd = HistoryDealGetTicket(d);
            if(pd==0) continue;
            if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_IN && HistoryDealGetInteger(pd, DEAL_MAGIC)==MagicNumber)
               oursOpen=true;
         }
         if(!oursOpen) continue;
         if(FindTagIndex(posId)<0) untagged++;
      }
   }
   return untagged;
}

//+------------------------------------------------------------------+
// پنجره‌ی تگ‌گذاری (UI روی چارت)
//+------------------------------------------------------------------+
// v74.4 (HF5): Strategy / Setup / Mental State steps use taller rows and bigger text; the Select Trade step
// (long ticket labels) keeps the old compact rows. Both BuildTagWindow() and IsOnTagWindow() use these helpers
// so the click-hit geometry always mirrors what is drawn.
int TagRowH() { return (g_tagStep>0) ? SC(30) : SC(22); }

// Mental State window: wider than the main window (bigger buttons), but never wider than the free space to its left.
int TagMentalWinW(int winX, int winW)
{
   int w = SC(270);
   int room = winX - GP;
   if(w > room) w = room;
   if(w < winW) w = winW;
   return w;
}

bool IsOnTagWindow(int x, int y)
{
   if(!g_tagWindowOpen) return false;

   int rowH = TagRowH();
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
   int setupsCount = (g_tagStep==3) ? GetSetupsForStrategy(g_tagSelectedStrategy, setupsList) : 0;   // v75.14 (FEAT-037): استپ‌ها شیفت شدند (۱=کانتکست)

   // FEAT-027: Mental State no longer adds its rows to this (main) window's height - it moved to
   // its own separate window (checked independently below), so this is just setupsCount+1 (Setup
   // list + hint row).
   int contentRows = (g_tagStep==0) ? (todayCount>0 ? todayCount : 1) :
                     (g_tagStep==1) ? 6 :                // v75.14: ۵ چک‌باکس + NEXT
                     (g_tagStep==2) ? g_stratCount+1 :
                                       setupsCount+1;
   int backRows = (g_tagStep>0) ? 1 : 0;
   int totalH   = pad + hdrH + pad + backRows*(rowH+pad) + contentRows*(rowH+pad) + pad;

   if(x>=winX && x<=winX+winW && y>=winY && y<=winY+totalH) return true;

   // FEAT-027: at g_tagStep==2 a second (Mental State) window is also open, to the left of the
   // main one - must be checked separately. Without this, a click on a Mental State button (which
   // OBJECT_CLICK handles first) gets immediately followed by the same-coordinate CHARTEVENT_CLICK
   // (the established dual-firing behavior from earlier stages), which would land outside the main
   // window's old single-window bounds and be read as "click outside -> close the window". Geometry
   // here must exactly mirror what BuildTagWindow() builds the second window with.
   if(g_tagStep==3)
   {
      int mentalStateRows = 4;   // هدر + ۲ ردیف دکمه + Clear (همون عدد قبلی، فقط جابه‌جا شده)
      int mentalWinW    = TagMentalWinW(winX, winW);
      int mentalWinX    = MathMax(0, winX - mentalWinW - GP);
      int mentalWinY    = winY;
      int mentalTotalH  = pad + mentalStateRows*(rowH+pad) + pad;
      if(x>=mentalWinX && x<=mentalWinX+mentalWinW && y>=mentalWinY && y<=mentalWinY+mentalTotalH) return true;
   }

   return false;
}

void CloseTagWindow()
{
   ObjectsDeleteAll(0, TAG_WIN_PREFIX);
   g_tagWindowOpen = false;
   UpdateTagTradesButton();
   ChartRedraw();
}

void OpenTagWindow()
{
   CloseScaleInPicker();   // v75.13 (MT4 v90): هر دو پنجره زیر پنل و هم‌جایگاه‌اند
   g_tagWindowOpen       = true;
   g_tagStep             = 0;
   g_tagSelectedTicket   = 0;
   g_tagSelectedStrategy = "";
   g_tagSelectedMentalState = "";
   g_ctxSelLevel = false; g_ctxSelCycle = false; g_ctxSelTime = false; g_ctxSelCandle = false; g_ctxSelNone = false;   // v75.14 (FEAT-037)
   LoadContextTagsFile();         // آخرین وضعیت (چارت‌های دیگر)
   LoadStrategySetupsFile();
   LoadContextChecklistFile();    // ویرایش دستی RM_ContextChecklist.txt همان لحظه دیده شود
   UpdateTagTradesButton();
   BuildTagWindow();
}

// [Stage 5d empty-label check] every LblCC/BtnC call below has real, non-empty text - no instance
// of Stage 5c-i's empty-string "Label" quirk was found in this window, confirmed by direct
// inspection.
void BuildTagWindow()
{
   ObjectsDeleteAll(0, TAG_WIN_PREFIX);
   if(!g_tagWindowOpen) return;

   int corner = CORNER_LEFT_UPPER;
   int rowH   = TagRowH();   // v74.4 (HF5): taller rows after the Select Trade step
   int hdrH   = SC(24);
   int pad    = SC(4);

   int chartW  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int winX    = PanelRight ? chartW - PW - PanelX : PanelX;
   int winW    = PW;
   int panelBottomY = PanelY + TH + (g_minimized ? 0 : ComputeBodyH());
   int winY = panelBottomY + GP;

   string todayLabels[];
   int    todayCount = 0;
   string setupsList[];
   int    setupsCount = 0;

   if(g_tagStep==0)
      todayCount = BuildTodayTicketList(todayLabels);
   else if(g_tagStep==3)
      setupsCount = GetSetupsForStrategy(g_tagSelectedStrategy, setupsList);

   // FEAT-027 (v73): Mental State (1 header + 2 button rows + 1 Clear = 4 rows) is no longer
   // counted here and no longer adds to this window's height - it moved into a second, separate
   // window to the left (built below, after this g_tagStep==2 block closes). Reason: on a small
   // screen, this window with Mental State inside it ran off the bottom of the chart before the
   // trader even reached Setup/Mental State.
   int contentRows = (g_tagStep==0) ? (todayCount>0 ? todayCount : 1) :
                     (g_tagStep==1) ? 6 :                // v75.14: ۵ چک‌باکس + NEXT
                     (g_tagStep==2) ? g_stratCount+1 :
                                       setupsCount+1;
   int backRows  = (g_tagStep>0) ? 1 : 0;
   int totalH    = pad + hdrH + pad + backRows*(rowH+pad) + contentRows*(rowH+pad) + pad;

   RectC(TAG_WIN_PREFIX+"BG", winX, winY, winW, totalH, C'25,25,32', corner);

   int cy = winY + pad;

   string hdrText = (g_tagStep==0) ? "Tag Trade - 1/4: Select Trade" :
                     (g_tagStep==1) ? "Tag Trade - 2/4: Context Checklist" :
                     (g_tagStep==2) ? "Tag Trade - 3/4: Select Strategy" :
                                      "Tag Trade - 4/4: Select Setup ("+g_tagSelectedStrategy+")";
   BtnC(TAG_WIN_PREFIX+"HDR",   winX,               cy, winW-SC(24)-pad, hdrH, hdrText, C'50,54,68', corner, 7);
   BtnC(TAG_WIN_PREFIX+"CLOSE", winX+winW-SC(24),   cy, SC(24),          hdrH, "X",     C'120,40,40', corner, 8);
   cy += hdrH + pad;

   if(g_tagStep>0)
   {
      BtnC(TAG_WIN_PREFIX+"BACK", winX, cy, winW, rowH, "<< BACK", C'70,70,80', corner, 9);
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
      // v75.14 (MT4 v81 FEAT-037): چک‌لیست کانتکست - ۵ چک‌باکس مستقل (چندانتخابی کامل) + NEXT. متن از RM_ContextChecklist.txt.
      bool ctxSel[5];
      ctxSel[0]=g_ctxSelLevel; ctxSel[1]=g_ctxSelCycle; ctxSel[2]=g_ctxSelTime; ctxSel[3]=g_ctxSelCandle; ctxSel[4]=g_ctxSelNone;
      for(int ci=0; ci<5; ci++)
      {
         color cColor = ctxSel[ci] ? CLR_TOOLS_ACTIVE : C'60,60,70';
         string cName = TAG_WIN_PREFIX+"CTX_"+IntegerToString(ci);
         BtnC(cName, winX, cy, winW, rowH, g_ctxLabels[ci], cColor, corner, 10);
         FitBtnFontBig(cName, g_ctxLabels[ci], winW, 10);
         cy += rowH + pad;
      }
      BtnC(TAG_WIN_PREFIX+"CTX_NEXT", winX, cy, winW, rowH, "NEXT >>", C'70,70,80', corner, 9);
      cy += rowH + pad;
   }
   else if(g_tagStep==2)
   {
      string existStrat = GetTagStrategy(g_tagSelectedTicket);
      for(int i=0;i<g_stratCount;i++)
      {
         color stratColor = (existStrat!="N/A" && g_stratNames[i]==existStrat) ? CLR_TOOLS_ACTIVE : C'60,60,70';
         BtnC(TAG_WIN_PREFIX+"STRAT_"+IntegerToString(i), winX, cy, winW, rowH, g_stratNames[i], stratColor, corner, 10);
         FitBtnFontBig(TAG_WIN_PREFIX+"STRAT_"+IntegerToString(i), g_stratNames[i], winW, 10);   // v74.4 (HF5)
         cy += rowH + pad;
      }
      LblCC(TAG_WIN_PREFIX+"STRAT_HINT", winX, cy, winW, rowH, "Add new: edit RM_StrategySetups.txt", clrSilver, 8, false, corner);
      cy += rowH + pad;
   }
   else // g_tagStep==3
   {
      string existStrat2 = GetTagStrategy(g_tagSelectedTicket);
      string existSetup  = GetTagSetup(g_tagSelectedTicket);
      bool   sameStratAsExisting = (existStrat2!="N/A" && existStrat2==g_tagSelectedStrategy);
      for(int i=0;i<setupsCount;i++)
      {
         color setupColor = (sameStratAsExisting && setupsList[i]==existSetup) ? CLR_TOOLS_ACTIVE : C'60,60,70';
         BtnC(TAG_WIN_PREFIX+"SETUP_"+IntegerToString(i), winX, cy, winW, rowH, setupsList[i], setupColor, corner, 10);
         FitBtnFontBig(TAG_WIN_PREFIX+"SETUP_"+IntegerToString(i), setupsList[i], winW, 10);   // v74.4 (HF5)
         cy += rowH + pad;
      }
      LblCC(TAG_WIN_PREFIX+"SETUP_HINT", winX, cy, winW, rowH, "Add new: edit RM_StrategySetups.txt", clrSilver, 8, false, corner);
      cy += rowH + pad;
   }

   // FEAT-027 (v73 - narrow-screen bottom-of-chart overflow fix): this section is no longer under
   // Setup in the same column/window - a fully separate, small window, to the left of the main
   // one, level with its top edge (winY). Per this project's own convention (comment above
   // BuildTagWindow() - BG is always built first so it stays behind, otherwise it sits on top of
   // the content), this second window's BG is also built first, then its content. Content (header +
   // buttons + Clear) is exactly as it was - same object names (MENTAL_HDR, MENTAL_0..5,
   // MENTAL_CLEAR), only the coordinates changed - so OnChartEvent()'s checks for these objects
   // (which match by StringFind on the name, not position) work correctly with zero changes. Only
   // the BG itself gets an extra, distinct sub-prefix (TAG_WIN_PREFIX+"MW_") to be distinguishable
   // from the main window's own BG - since this name still starts with TAG_WIN_PREFIX,
   // ObjectsDeleteAll(0, TAG_WIN_PREFIX) at the top of this function still clears both windows
   // together.
   if(g_tagStep==3)
   {
      int mentalStateRows = 4;   // header + 2 button rows (3-across, 6 options total) + Clear
      int mentalWinW   = TagMentalWinW(winX, winW);   // v74.4 (HF5): wider than the main window (was = winW) so the bigger captions fit
      int mentalWinX   = MathMax(0, winX - mentalWinW - GP);  // flush against the main window's left edge; clamped to 0 on a very narrow chart
      int mentalWinY   = winY;   // level with the main window's own top edge
      int mentalTotalH = pad + mentalStateRows*(rowH+pad) + pad;

      RectC(TAG_WIN_PREFIX+"MW_BG", mentalWinX, mentalWinY, mentalWinW, mentalTotalH, C'25,25,32', corner);

      int cy2 = mentalWinY + pad;
      LblCC(TAG_WIN_PREFIX+"MENTAL_HDR", mentalWinX, cy2, mentalWinW, rowH, "Mental State:", clrSilver, 9, false, corner);
      cy2 += rowH + pad;

      string mentalOpts[];
      int    mentalCount = GetMentalStateOptions(mentalOpts);
      // Same 3-column pattern as BuildPanel() (RM_Dashboard.mq5: toolsThirdW1/2/3), just against
      // this second window's own width (mentalWinW) instead of winW - since mentalWinW==winW these
      // are numerically the same values as before anyway.
      int mThirdW1 = (mentalWinW-2*GP)/3;
      int mThirdW2 = mThirdW1;
      int mThirdW3 = mentalWinW-2*GP-mThirdW1-mThirdW2;
      int mColW[3]; mColW[0]=mThirdW1; mColW[1]=mThirdW2; mColW[2]=mThirdW3;

      int mentalRows = (mentalCount + 2) / 3;  // ceil division by 3 - exactly 2 rows with the current 6 options
      for(int r=0; r<mentalRows; r++)
      {
         int rx = mentalWinX;
         for(int c=0; c<3; c++)
         {
            int mi = r*3+c;
            if(mi>=mentalCount) break;  // incomplete last row (if option count isn't a multiple of 3)
            string mName = TAG_WIN_PREFIX+"MENTAL_"+IntegerToString(mi);
            color mColor = (g_tagSelectedMentalState==mentalOpts[mi]) ? CLR_TOOLS_ACTIVE : C'60,60,70';
            BtnC(mName, rx, cy2, mColW[c], rowH, mentalOpts[mi], mColor, corner, 10);
            FitBtnFontBig(mName, mentalOpts[mi], mColW[c], 10);   // v74.4 (HF5): was fixed size 6
            rx += mColW[c] + GP;
         }
         cy2 += rowH + pad;
      }

      BtnC(TAG_WIN_PREFIX+"MENTAL_CLEAR", mentalWinX, cy2, mentalWinW, rowH, "Clear", C'70,70,80', corner, 9);
      cy2 += rowH + pad;
   }

   ChartRedraw();
}

// v75.3 (MT4 v105): خبرهای USD داخل KEY TIME
#include "RM_News.mq5"


//+------------------------------------------------------------------+
// === v75.13 (MT4 v90 FEAT-044 فاز ۱): پنجره‌ی انتخاب زنجیره‌ی Scale-in (وقتی ۲+ زنجیره‌ی مجاز) ===
// هم‌سبک پنجره‌ی Tag Trade: زیر پنل، هم‌عرض PW، پیشوند جدا (SCL_WIN_PREFIX). هر ردیف: شماره‌ی ریشه، جهت، قیمت ورود، تگ استراتژی، ریسک آزاد ($).
// فهرست هر ~۱ ثانیه (از OnTick/OnTimer) تازه می‌شود؛ زنجیره‌ی بسته‌شده/سقف‌صفرشده خودکار حذف می‌شود.
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
      ulong root = g_scCandRoot[i];
      string tag = ShortTagText(GetTagStrategy(root), 8);
      string lbl = "#"+IntegerToString(root)+" "+(g_scCandBuy[i]?"B":"S")+" "+DoubleToString(g_scCandEntry[i],_Digits)+" $"+DoubleToString(g_scCandCap[i],0)+(tag!="N/A" ? " "+tag : "");
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
   ulong root = g_scCandRoot[i];
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

   ulong  oldRoot[]; double oldCap[];
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
