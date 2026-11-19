//+------------------------------------------------------------------+
//| RM_Hub_Modules123.mq5                                              |
//| Executive Hub — MT5 port, Stage 5e-ii                              |
//| Ported from ExecutiveHub_v1_07.mq4                                 |
//|                                                                    |
//| SCOPE (per Stage5e-ii_Task_Message.md): POC, Weekly Map, shared    |
//| DST/time helpers, Session Opening Box, NY Edge, MTF Candle Preview.|
//| NOT in this file: EMA_* + buffer setup (5e-iii), OnInit/OnDeinit/  |
//| OnCalculate/OnTimer/OnChartEvent (5e-iv). Depends on Stage 5e-i's  |
//| RM_Hub_PanelDrawLabel.mq5 for panel constants (PFX, BTN_MASTER_*,  |
//| CLR_SUBTOGGLE_ACTIVE, CLR_INACTIVE_GRAY) and the module button     |
//| names/visibility booleans it already declared (BTN_POC, BTN_WMAP,  |
//| BTN_SOB, BTN_NYE, BTN_MTFCP, pocActive, wmapVisible, sobVisible,   |
//| nyeVisible, mtfcpVisible) - NOT redeclared here to avoid duplicate |
//| definition errors when both files are #included together.         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Inputs                                                             |
//+------------------------------------------------------------------+
input int     POC_BucketCount           = 100;
input double  POC_ExhaustionSegmentPct  = 25.0;
input color   POC_LineColor       = clrDodgerBlue;
input int     POC_LineWidth       = 3;
input color   POC_LVN_Color       = clrLightSkyBlue;
input int     POC_LVN_Width       = 1;
input color   POC_Exhaustion_Color = clrDeepPink;
input int     POC_Exhaustion_Width = 4;
input int     POC_LabelFontSize   = 9;
input int     POC_LabelRightMargin = 8;
input int     POC_LabelAboveLineGap = 4;

input color WMAP_ColorExtreme       = clrSilver;
input color WMAP_ColorExtreme_Light = clrDimGray;
input color WMAP_ColorInner         = clrDimGray;
input color WMAP_ColorInner_Light   = clrGray;
input color WMAP_ColorExtension     = clrGainsboro;
input color WMAP_ColorExtension_Light = C'40,40,40';
input bool  WMAP_ShowInnerLevels = true;
input bool  WMAP_ShowExtensions  = true;
input bool  WMAP_ShowLabels      = true;
input int   WMAP_LabelXOffset    = 6;
input int   WMAP_FontSize        = 8;

input bool   SOB_EnableTokyo         = true;
input bool   SOB_EnableLondon        = false;
input bool   SOB_EnableNewYork       = false;
input string SOB_TokyoStart          = "09:00";   // Tokyo local (JST) - v1.09 (MT4 v1.18)
input string SOB_TokyoEnd            = "10:00";   // Tokyo local (JST) - v1.09
input color  SOB_TokyoColor          = clrYellow;
input string SOB_LondonStart         = "08:00";   // London local (EU DST rule) - v1.09 (was NY 03:00)
input string SOB_LondonEnd           = "09:00";   // London local - v1.09 (was NY 04:00)
input color  SOB_LondonColor         = clrLimeGreen;
input string SOB_NewYorkStart        = "08:30";
input string SOB_NewYorkEnd          = "09:30";
input color  SOB_NewYorkColor        = clrBlue;
input int    SOB_ProjectionLevels       = 3;
input bool   SOB_ShowOpeningBox         = true;
input bool   SOB_ShowProjectionLevels   = true;
input bool   SOB_CurrentDayOnly         = true;
input int    SOB_ShowLastXDays          = 30;
input int    SOB_OpeningFillTransparency = 70;
input int    SOB_ProjectionLineWidth    = 1;
input int    SOB_EdgeLineWidth          = 2;
input ENUM_TIMEFRAMES SOB_BaseTimeframe = PERIOD_M5;

input string NYE_NewYorkStart           = "09:00";
input string NYE_NewYorkEnd             = "18:00";
input color  NYE_EdgeColor              = clrDodgerBlue;
input int    NYE_EdgeLineWidth          = 1;
input ENUM_TIMEFRAMES NYE_BaseTimeframe = PERIOD_M5;

input ENUM_TIMEFRAMES MTFCP_PreviewTF      = PERIOD_H1;
input int             MTFCP_CandleCount   = 3;
input int             MTFCP_GapPx         = 270;
input int             MTFCP_SlotWidthPx   = 52;
input double          MTFCP_BodyWidthRatio = 0.65;
input bool             MTFCP_ShowCountdown = true;
input bool             MTFCP_ShowLiveConnector = true;
enum ENUM_ConnSource
{
   CONN_SRC_LAST_CLOSED = 0, // Last CLOSED candle (recommended when the reference TF is your decision criterion)
   CONN_SRC_LIVE         = 1  // Live/forming candle (previous default behavior)
};
input ENUM_ConnSource  MTFCP_ConnectorSource = CONN_SRC_LAST_CLOSED;
input color            MTFCP_BullColorInp     = clrNONE;
input color            MTFCP_BearColorInp     = clrNONE;
input color            MTFCP_LabelColorInp    = clrNONE;
input bool             MTFCP_DimHistorical = true;
input color            MTFCP_HistoricalColorInp = clrNONE;
input bool             MTFCP_AutoEnableChartShift = true;
input bool             MTFCP_EnsureContrast = true;
input int              MTFCP_ContrastMinDiff = 45;
input int              MTFCP_ContrastShift   = 90;
input bool             MTFCP_Debug         = false;

//+------------------------------------------------------------------+
//| Module 1 - POC                                                     |
//+------------------------------------------------------------------+
#define POC_PFX          "POC_"
#define POC_LINE_POC     POC_PFX+"POC"
#define POC_LINE_LVN     POC_PFX+"LVN"
#define POC_LINE_EXH     POC_PFX+"Exhaustion"
#define POC_LBL_POC      POC_PFX+"POC_Label"
#define POC_LBL_LVN      POC_PFX+"LVN_Label"
#define POC_LBL_EXH      POC_PFX+"Exhaustion_Label"
#define POC_TRACK_VLINE  POC_PFX+"TrackLine"
#define POC_TRACK_LABEL  POC_PFX+"TrackLabel"

bool           pocLevelsActive = false;
double         gPocPrice, gLvnPrice, gExhPrice;

//+------------------------------------------------------------------+
//| Module 1 - Weekly Map                                              |
//+------------------------------------------------------------------+
#define WMAP_PFX "WMAP_"
datetime g_lastWeekTime = 0;

//+------------------------------------------------------------------+
//| Module 2 - Session Opening Box                                     |
//+------------------------------------------------------------------+
#define SOB_PFX "SOB_"
datetime sobLastBarTime = 0;

//+------------------------------------------------------------------+
//| Module 2 - NY Edge                                                 |
//+------------------------------------------------------------------+
#define NYE_PFX "NYE_"
datetime nyeLastBarTime = 0;

//+------------------------------------------------------------------+
//| Module 3 - MTF Candle Preview                                      |
//+------------------------------------------------------------------+
#define MTFCP_PFX "MTFCP_"
datetime mtfcpLastSourceBarTime = 0;
int      mtfcpPrevConnHighSegCount = 0;
int      mtfcpPrevConnLowSegCount  = 0;

//+------------------------------------------------------------------+
//| POC (Point of Control)                                             |
//+------------------------------------------------------------------+
bool LoadPOCActive()
{
   string gvName = "POC_Active_" + Symbol();
   if(GlobalVariableCheck(gvName))
      return(GlobalVariableGet(gvName) != 0);
   return(false);
}

void SavePOCActive(bool active)
{
   string gvName = "POC_Active_" + Symbol();
   GlobalVariableSet(gvName, active ? 1.0 : 0.0);
}

void POC_CleanupLegacyObjects()
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, "PAL_") == 0)
         ObjectDelete(0, nm);
   }
}

void SetPOCButtonActive(bool active)
{
   HubSetBg(BTN_POC, active ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

void POC_DeleteTrackObjects()
{
   if(ObjectFind(0, POC_TRACK_VLINE) >= 0) ObjectDelete(0, POC_TRACK_VLINE);
   if(ObjectFind(0, POC_TRACK_LABEL) >= 0) ObjectDelete(0, POC_TRACK_LABEL);
}

void POC_DeleteLevels()
{
   string names[6] = {POC_LINE_POC, POC_LINE_LVN, POC_LINE_EXH, POC_LBL_POC, POC_LBL_LVN, POC_LBL_EXH};
   for(int i = 0; i < 6; i++)
      if(ObjectFind(0, names[i]) >= 0) ObjectDelete(0, names[i]);
}

void POC_CalculateAndDraw(datetime t1, datetime t2)
{
   datetime rangeStart = MathMin(t1, t2);
   datetime rangeEnd   = MathMax(t1, t2);

   int shiftStart = iBarShift(Symbol(), Period(), rangeStart, false);
   int shiftEnd   = iBarShift(Symbol(), Period(), rangeEnd, false);
   int barFrom = MathMax(shiftStart, shiftEnd);
   int barTo   = MathMin(shiftStart, shiftEnd);

   int totalBars = barFrom - barTo + 1;
   if(totalBars < 3)
   {
      Alert("POC: selected range is too small - please choose a larger range.");
      return;
   }

   double rangeHigh = -1, rangeLow = -1;
   for(int i = barTo; i <= barFrom; i++)
   {
      double h = iHigh(Symbol(), Period(), i);
      double l = iLow(Symbol(), Period(), i);
      if(rangeHigh < 0 || h > rangeHigh) rangeHigh = h;
      if(rangeLow  < 0 || l < rangeLow)  rangeLow  = l;
   }
   if(rangeHigh <= rangeLow) return;

   int    bucketCount = MathMax(10, POC_BucketCount);
   double bucketSize   = (rangeHigh - rangeLow) / bucketCount;

   double volProfile[];
   ArrayResize(volProfile, bucketCount);
   ArrayInitialize(volProfile, 0.0);

   for(int i = barTo; i <= barFrom; i++)
      POC_DistributeCandleVolume(i, rangeLow, bucketSize, bucketCount, volProfile);

   int pocIdx = 0, lvnIdx = 0;
   double pocVal = -1, lvnVal = -1;
   for(int b = 0; b < bucketCount; b++)
   {
      if(volProfile[b] > pocVal) { pocVal = volProfile[b]; pocIdx = b; }
      if(lvnVal < 0 || volProfile[b] < lvnVal) { lvnVal = volProfile[b]; lvnIdx = b; }
   }
   double pocPrice = rangeLow + (pocIdx + 0.5) * bucketSize;
   double lvnPrice = rangeLow + (lvnIdx + 0.5) * bucketSize;

   double pct    = MathMax(1.0, MathMin(100.0, POC_ExhaustionSegmentPct));
   int    segBars = MathMax(1, (int)MathRound(totalBars * pct / 100.0));
   int    segTo   = barTo;
   int    segFrom = MathMin(barFrom, barTo + segBars - 1);

   double exhProfile[];
   ArrayResize(exhProfile, bucketCount);
   ArrayInitialize(exhProfile, 0.0);
   for(int i = segTo; i <= segFrom; i++)
      POC_DistributeCandleVolume(i, rangeLow, bucketSize, bucketCount, exhProfile);

   int exhIdx = 0; double exhVal = -1;
   for(int b = 0; b < bucketCount; b++)
      if(exhProfile[b] > exhVal) { exhVal = exhProfile[b]; exhIdx = b; }
   double exhPrice = rangeLow + (exhIdx + 0.5) * bucketSize;

   datetime lineStartTime = iTime(Symbol(), Period(), barFrom);
   POC_DrawLevel(POC_LINE_POC, lineStartTime, pocPrice, POC_LineColor, POC_LineWidth);
   POC_DrawLevel(POC_LINE_LVN, lineStartTime, lvnPrice, POC_LVN_Color, POC_LVN_Width);
   POC_DrawLevel(POC_LINE_EXH, lineStartTime, exhPrice, POC_Exhaustion_Color, POC_Exhaustion_Width);

   gPocPrice = pocPrice;
   gLvnPrice = lvnPrice;
   gExhPrice = exhPrice;
   pocLevelsActive = true;

   POC_CreateOrUpdateLabel(POC_LBL_POC, "POC",              pocPrice, POC_LineColor);
   POC_CreateOrUpdateLabel(POC_LBL_LVN, "LVN",               lvnPrice, POC_LVN_Color);
   POC_CreateOrUpdateLabel(POC_LBL_EXH, "Exhaustion Point",  exhPrice, POC_Exhaustion_Color);
}

void POC_DistributeCandleVolume(int shift, double rangeLow, double bucketSize, int bucketCount, double &profile[])
{
   double h = iHigh(Symbol(), Period(), shift);
   double l = iLow(Symbol(), Period(), shift);
   // [Translation decision, stated explicitly per task request] MT5 splits MT4's single "volume"
   // concept into tick volume and real volume. MT4 only ever had one kind of volume (tick count),
   // so this maps to iVolume() = TICK volume in MT5, not real volume - iVolume() itself is a
   // compatibility wrapper that already returns tick volume, so no signature change is needed here,
   // just documenting the deliberate choice per the task's explicit request not to assume silently.
   long   vol = iVolume(Symbol(), Period(), shift);

   int bStart = (int)MathFloor((l - rangeLow) / bucketSize);
   int bEnd   = (int)MathFloor((h - rangeLow) / bucketSize);
   if(bStart < 0) bStart = 0;
   if(bEnd >= bucketCount) bEnd = bucketCount - 1;
   if(bEnd < bStart) bEnd = bStart;

   int span = bEnd - bStart + 1;
   double volPerBucket = (double)vol / span;

   for(int b = bStart; b <= bEnd; b++)
      profile[b] += volPerBucket;
}

void POC_DrawLevel(string lineName, datetime startTime, double price, color clr, int width)
{
   clr = Theme_ContrastSafe(clr);   // v1.12
   if(ObjectFind(0, lineName) >= 0) ObjectDelete(0, lineName);
   ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, price, TimeCurrent() + PeriodSeconds() * 20, price);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
}

void POC_CreateOrUpdateLabel(string lblName, string text, double price, color clr)
{
   clr = Theme_ContrastSafe(clr);   // v1.12
   if(ObjectFind(0, lblName) < 0)
   {
      ObjectCreate(0, lblName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lblName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, lblName, OBJPROP_ZORDER, 99);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, POC_LabelFontSize);
   }
   ObjectSetString(0, lblName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lblName, OBJPROP_XDISTANCE, POC_LabelRightMargin);
   ObjectSetInteger(0, lblName, OBJPROP_YDISTANCE, POC_PriceToY(price) - POC_LabelAboveLineGap);
}

int POC_PriceToY(double price)
{
   int    height   = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   double priceMax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double priceMin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   if(priceMax <= priceMin) return(0);
   double ratio = (priceMax - price) / (priceMax - priceMin);
   return((int)MathRound(ratio * height));
}

void POC_RepositionLabels()
{
   if(ObjectFind(0, POC_LBL_POC) >= 0) ObjectSetInteger(0, POC_LBL_POC, OBJPROP_YDISTANCE, POC_PriceToY(gPocPrice) - POC_LabelAboveLineGap);
   if(ObjectFind(0, POC_LBL_LVN) >= 0) ObjectSetInteger(0, POC_LBL_LVN, OBJPROP_YDISTANCE, POC_PriceToY(gLvnPrice) - POC_LabelAboveLineGap);
   if(ObjectFind(0, POC_LBL_EXH) >= 0) ObjectSetInteger(0, POC_LBL_EXH, OBJPROP_YDISTANCE, POC_PriceToY(gExhPrice) - POC_LabelAboveLineGap);
}

void POC_UpdateTrackLine(datetime t)
{
   if(ObjectFind(0, POC_TRACK_VLINE) < 0)
   {
      ObjectCreate(0, POC_TRACK_VLINE, OBJ_VLINE, 0, t, 0);
      ObjectSetInteger(0, POC_TRACK_VLINE, OBJPROP_COLOR, Theme_ContrastSafe(clrSilver));   // v1.12
      ObjectSetInteger(0, POC_TRACK_VLINE, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, POC_TRACK_VLINE, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, POC_TRACK_VLINE, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, POC_TRACK_VLINE, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, POC_TRACK_VLINE, OBJPROP_BACK, true);
   }
   else
      ObjectMove(0, POC_TRACK_VLINE, 0, t, 0);
}

void POC_UpdateTrackLabel(int x, int y, string text)
{
   if(ObjectFind(0, POC_TRACK_LABEL) < 0)
   {
      ObjectCreate(0, POC_TRACK_LABEL, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, POC_TRACK_LABEL, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, POC_TRACK_LABEL, OBJPROP_COLOR, Theme_ContrastSafe(clrYellow));   // v1.12
      ObjectSetInteger(0, POC_TRACK_LABEL, OBJPROP_FONTSIZE, POC_LabelFontSize);
      ObjectSetInteger(0, POC_TRACK_LABEL, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, POC_TRACK_LABEL, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, POC_TRACK_LABEL, OBJPROP_ZORDER, 101);
   }
   ObjectSetInteger(0, POC_TRACK_LABEL, OBJPROP_XDISTANCE, x + 15);
   ObjectSetInteger(0, POC_TRACK_LABEL, OBJPROP_YDISTANCE, MathMax(y - 15, 2));
   ObjectSetString(0, POC_TRACK_LABEL, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| ماژول ۱ - Weekly Map: پایداری، محاسبه، رسم (عیناً از نسخه‌ی مستقل)    |
//+------------------------------------------------------------------+
bool LoadWMAPVisible()
{
   string gvName = "WeeklyMap_Visible_" + Symbol();
   if(GlobalVariableCheck(gvName))
      return(GlobalVariableGet(gvName) != 0);
   return(false);
}

void SaveWMAPVisible(bool visible)
{
   string gvName = "WeeklyMap_Visible_" + Symbol();
   GlobalVariableSet(gvName, visible ? 1.0 : 0.0);
}

void SetWMAPButtonColor()
{
   HubSetBg(BTN_WMAP, wmapVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

int WMAP_PriceToPixelY(double price)
{
   int x = 0, y = 0;
   // [MT5 translation] MT4's implicit Time[0] series array doesn't exist in MT5 - replaced with
   // iTime(Symbol(), Period(), 0), same compatibility-function choice already made for the rest of
   // this file's historical-bar access (matches the EA port's Stage 1 audit decision).
   ChartTimePriceToXY(0, 0, iTime(Symbol(), Period(), 0), price, x, y);
   return(y);
}

int WMAP_LastClosedWeekShift()
{
   datetime t0 = iTime(Symbol(), PERIOD_W1, 0);
   int periodSec = PeriodSeconds(PERIOD_W1);
   if(periodSec <= 0) periodSec = 7 * 24 * 3600;
   datetime closeTime0 = t0 + periodSec;
   if(TimeCurrent() >= closeTime0)
      return(0);
   return(1);
}

//+------------------------------------------------------------------+
//| BUG-FIX (v1.01, Bug 1): contrast-aware color picker - same pattern|
//| already proven in RM_Tools.mqh's GetContrastColor(forDarkBg,      |
//| forLightBg): read chart background, compute perceived luminance   |
//| (0.299R + 0.587G + 0.114B), and pick between two pre-defined      |
//| variants using a threshold of 140. No per-pixel proximity math.   |
//+------------------------------------------------------------------+
color WMAP_GetContrastColor(color forDarkBg, color forLightBg)
{
   long bg = (long)Hub_ChartBg();   // v1.12: override-aware
   int r = (int)(bg & 0xFF);
   int g = (int)((bg >> 8) & 0xFF);
   int b = (int)((bg >> 16) & 0xFF);
   double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
   if(luminance < 140)
      return(Theme_ContrastSafe(forDarkBg));   // v1.12: روی تم‌های بینابینی هم خوانا بماند
   return(Theme_ContrastSafe(forLightBg));
}

// v1.10 (MT4 v1.15): سطوح ادامه‌دار. گام = (WH-WL)/4. هر وقت قیمت از بالاترین/پایین‌ترین سطح رسم‌شده عبور کند، یک گام
// دیگر در همان جهت اضافه می‌شود (تکرارشونده) تا همیشه یک خط جلوی قیمت باشد. g_wmapKUp/KDown = تعداد گام‌های بالای WH و پایین WL
// (حداقل ۱ = همان WH+25% / WL-25% قبلی). قیمت مرجع = بیشینه/کمینه‌ی هفته‌ی جاری (ویک‌ها هم) و Bid؛ پس بعد از برگشت قیمت،
// سطوح اضافه‌شده می‌مانند. سقف WMAP_MAX_EXTRA_STEPS برای هر طرف.
#define WMAP_MAX_EXTRA_STEPS 40
int g_wmapKUp   = 1;
int g_wmapKDown = 1;

// true اگر تعداد گام‌ها نسبت به آخرین رسم تغییر کرده (و globalها را به‌روز می‌کند)
bool WMAP_RefreshExtras()
{
   int shift = WMAP_LastClosedWeekShift();
   double wh = iHigh(Symbol(), PERIOD_W1, shift);
   double wl = iLow(Symbol(), PERIOD_W1, shift);
   double range = wh - wl;
   int kUp = 1, kDown = 1;

   if(range > 0 && wh > 0 && wl > 0)
   {
      double step = range * 0.25;
      double bid  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double pMax = bid, pMin = bid;
      if(shift >= 1)   // هفته‌ی جاری از آخرین هفته‌ی بسته‌شده جداست -> ویک‌هایش هم حساب می‌شود
      {
         double ch = iHigh(Symbol(), PERIOD_W1, 0), cl = iLow(Symbol(), PERIOD_W1, 0);
         if(ch > pMax) pMax = ch;
         if(cl > 0 && cl < pMin) pMin = cl;
      }
      if(pMax > wh) kUp   = (int)MathMax(1.0, MathFloor((pMax - wh) / step) + 1.0);
      if(pMin < wl) kDown = (int)MathMax(1.0, MathFloor((wl - pMin) / step) + 1.0);
      if(kUp   > WMAP_MAX_EXTRA_STEPS) kUp   = WMAP_MAX_EXTRA_STEPS;
      if(kDown > WMAP_MAX_EXTRA_STEPS) kDown = WMAP_MAX_EXTRA_STEPS;
   }

   bool changed = (kUp != g_wmapKUp || kDown != g_wmapKDown);
   g_wmapKUp   = kUp;
   g_wmapKDown = kDown;
   return(changed);
}

void WMAP_GetLevels(double &prices[], string &tags[], color &cols[])
{
   int shift = WMAP_LastClosedWeekShift();
   double wh = iHigh(Symbol(), PERIOD_W1, shift);
   double wl = iLow(Symbol(), PERIOD_W1, shift);
   double range = wh - wl;

   int extraUp   = g_wmapKUp   - 1;   // گام‌های بعد از WH+25%
   int extraDown = g_wmapKDown - 1;   // گام‌های بعد از WL-25%
   int total = 7 + extraUp + extraDown;
   ArrayResize(prices, total);
   ArrayResize(tags, total);
   ArrayResize(cols, total);

   color colExtreme   = WMAP_GetContrastColor(WMAP_ColorExtreme,   WMAP_ColorExtreme_Light);
   color colInner     = WMAP_GetContrastColor(WMAP_ColorInner,     WMAP_ColorInner_Light);
   color colExtension = WMAP_GetContrastColor(WMAP_ColorExtension, WMAP_ColorExtension_Light);

   prices[0] = wh;                 tags[0] = "WH";     cols[0] = colExtreme;
   prices[1] = wl;                 tags[1] = "WL";     cols[1] = colExtreme;
   prices[2] = wl + range * 0.25;  tags[2] = "25%";    cols[2] = colInner;
   prices[3] = wl + range * 0.50;  tags[3] = "50%";    cols[3] = colInner;
   prices[4] = wl + range * 0.75;  tags[4] = "75%";    cols[4] = colInner;
   prices[5] = wh + range * 0.25;  tags[5] = "WH+25%"; cols[5] = colExtension;
   prices[6] = wl - range * 0.25;  tags[6] = "WL-25%"; cols[6] = colExtension;

   // v1.10: ایندکس 7.. = ادامه‌ها (اول گام‌های بالا، بعد پایین)؛ همه هم‌رنگ و هم‌دسته با WH+25%/WL-25%
   for(int u = 0; u < extraUp; u++)
   {
      int iu = 7 + u;
      int k = u + 2;
      prices[iu] = wh + range * 0.25 * k;
      tags[iu]   = "WH+" + IntegerToString(25 * k) + "%";
      cols[iu]   = colExtension;
   }
   for(int d = 0; d < extraDown; d++)
   {
      int id2 = 7 + extraUp + d;
      int k = d + 2;
      prices[id2] = wl - range * 0.25 * k;
      tags[id2]   = "WL-" + IntegerToString(25 * k) + "%";
      cols[id2]   = colExtension;
   }
}

void WMAP_DrawAll()
{
   WMAP_RefreshExtras();   // v1.10: تعداد گام‌های ادامه‌دار را قبل از ساخت لیست سطوح به‌روز کن
   double prices[]; string tags[]; color cols[];
   WMAP_GetLevels(prices, tags, cols);
   if(prices[0] == 0 || prices[1] == 0) return;

   int nLevels = ArraySize(prices);
   for(int i = 0; i < nLevels; i++)
   {
      bool isInner     = (i >= 2 && i <= 4);
      bool isExtension = (i >= 5);
      if(isInner && !WMAP_ShowInnerLevels)
      {
         ObjectDelete(0, WMAP_PFX + "Line_" + IntegerToString(i));
         ObjectDelete(0, WMAP_PFX + "Label_" + IntegerToString(i));
         continue;
      }
      if(isExtension && !WMAP_ShowExtensions)
      {
         ObjectDelete(0, WMAP_PFX + "Line_" + IntegerToString(i));
         ObjectDelete(0, WMAP_PFX + "Label_" + IntegerToString(i));
         continue;
      }

      string lineName = WMAP_PFX + "Line_" + IntegerToString(i);
      WMAP_SetHLine(lineName, prices[i], cols[i]);

      if(WMAP_ShowLabels)
      {
         string labelName = WMAP_PFX + "Label_" + IntegerToString(i);
         WMAP_SetTagLabel(labelName, tags[i], prices[i], cols[i]);
      }
   }

   // v1.10: اگر تعداد سطوح کم شده (مثلاً هفته‌ی جدید)، آبجکت‌های اضافه‌ی قبلی حذف شوند
   for(int j = nLevels; j < 7 + 2 * (WMAP_MAX_EXTRA_STEPS - 1); j++)
   {
      ObjectDelete(0, WMAP_PFX + "Line_" + IntegerToString(j));
      ObjectDelete(0, WMAP_PFX + "Label_" + IntegerToString(j));
   }
}

void WMAP_SetHLine(string name, double price, color col)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
   else
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
}

void WMAP_SetTagLabel(string name, string text, double price, color col)
{
   int y = WMAP_PriceToPixelY(price) + 4;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, WMAP_FontSize);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, WMAP_LabelXOffset);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void WMAP_UpdateLabelPositions()
{
   if(!WMAP_ShowLabels) return;

   double prices[]; string tags[]; color cols[];
   WMAP_GetLevels(prices, tags, cols);
   if(prices[0] == 0 || prices[1] == 0) return;

   int nLevelsU = ArraySize(prices);   // v1.10: شامل سطوح ادامه‌دار
   for(int i = 0; i < nLevelsU; i++)
   {
      bool isInner     = (i >= 2 && i <= 4);
      bool isExtension = (i >= 5);
      if(isInner && !WMAP_ShowInnerLevels) continue;
      if(isExtension && !WMAP_ShowExtensions) continue;

      string labelName = WMAP_PFX + "Label_" + IntegerToString(i);
      if(ObjectFind(0, labelName) < 0) continue;
      int y = WMAP_PriceToPixelY(prices[i]) + 4;
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, y);
   }
}

//+------------------------------------------------------------------+
//| موتور تایم‌زون مشترک — هم Session Opening Box هم NY Edge از همین    |
//| یه نسخه استفاده می‌کنن (پیاده‌سازیشون قبلاً عیناً یکی بود، پس فقط یه  |
//| نسخه نگه داشته شد، نه دوتای تکراری). پورت‌شده از RiskManager_EA_v69  |
//| — آفست بروکر خودکار با TimeCurrent()-TimeGMT() خونده می‌شه.          |
//|                                                                    |
//| [MT5 translation, same fragile-DST pattern as the EA port's       |
//| Stage 5d] TimeYear()/TimeMonth()/TimeDay()/TimeDayOfWeek() are     |
//| MQL4-only - no MQL5 equivalent by those names. Replaced with       |
//| TimeToStruct(datetime, MqlDateTime&) + reading .year/.mon/.day/    |
//| .day_of_week. Formula/thresholds UNCHANGED - only the source of    |
//| each date component changed. MqlDateTime.day_of_week uses the same |
//| 0=Sunday..6=Saturday convention as MT4's TimeDayOfWeek(), so this  |
//| is a pure API substitution, not a logic change.                   |
//|                                                                    |
//| Hand-traced against the EA port's already-confirmed 2026 US DST   |
//| dates (start 2026.03.08 07:00 UTC, end 2026.11.01 06:00 UTC),      |
//| reused here rather than re-derived: 2026.03.01 is a Sunday         |
//| (dowM=0 -> firstSunM=1 -> secondSunM=8 -> March 8, matches).       |
//| 2026.11.01 is also a Sunday (dowN=0 -> firstSunN=1 -> Nov 1,       |
//| matches). Confirmed independently via a Python weekday check       |
//| during this port (both are Sundays), not just copied from memory. |
//+------------------------------------------------------------------+
// v1.09 (P2، MT4 Hub 1.18): موتور زمان به ماژول مشترک RM_SessionTime.mq5 منتقل شد (آفست پایدار + DST همان روز + بازارِ هر سشن).
// این سه wrapper هم‌امضای قبلی ماندند تا NY Edge دست‌نخورده بماند.
bool IsUSDST(datetime utcTime) { return ST_IsUSDST(utcTime); }

void GetNYDate(int daysAgo, int &y, int &m, int &d) { ST_GetNYCalendarDate(daysAgo, y, m, d); }

void ComputeServerTime(int daysAgo, int nyStartH, int nyStartM, int nyEndH, int nyEndM, datetime &outStart, datetime &outEnd)
{
   ST_ComputeSessionByDaysAgo(daysAgo, nyStartH, nyStartM, nyEndH, nyEndM, outStart, outEnd);
}

int ParseHHMM(string hhmm)
{
   string parts[];
   int n = StringSplit(hhmm, ':', parts);
   if(n < 2) return(0);
   return((int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]));
}

//+------------------------------------------------------------------+
//| Module 2 - Session Opening Box                                     |
//+------------------------------------------------------------------+
bool LoadSOBVisible()
{
   string gvName = "SOB_Visible_" + Symbol();
   if(GlobalVariableCheck(gvName))
      return(GlobalVariableGet(gvName) != 0);
   return(false);
}

void SaveSOBVisible(bool visible)
{
   string gvName = "SOB_Visible_" + Symbol();
   GlobalVariableSet(gvName, visible ? 1.0 : 0.0);
}

void SetSOBButtonColor()
{
   HubSetBg(BTN_SOB, sobVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

void SOB_Recalculate()
{
   ObjectsDeleteAll(0, SOB_PFX);
   int days = SOB_CurrentDayOnly ? 2 : MathMax(1, SOB_ShowLastXDays);

   // v1.09 (MT4 Hub 1.18، FEAT-060): هر سشن با ساعت محلی بازار خودش (DST همان بازار، per-day)
   if(SOB_EnableTokyo)   SOB_ProcessSession("Tokyo",   SOB_TokyoStart,   SOB_TokyoEnd,   SOB_TokyoColor,   days, ST_MKT_TOKYO);
   if(SOB_EnableLondon)  SOB_ProcessSession("London",  SOB_LondonStart,  SOB_LondonEnd,  SOB_LondonColor,  days, ST_MKT_LONDON);
   if(SOB_EnableNewYork) SOB_ProcessSession("NewYork", SOB_NewYorkStart, SOB_NewYorkEnd, SOB_NewYorkColor, days, ST_MKT_NY);
}

void SOB_ProcessSession(string sessionName, string startStr, string endStr, color col, int days, int mkt = ST_MKT_NY)   // v1.09: + market
{
   col = Theme_ContrastSafe(col);   // v1.12: رنگ ثابتِ ورودی روی تم‌های روشن خوانا بماند
   int startMin = ParseHHMM(startStr);
   int endMin   = ParseHHMM(endStr);
   int sh = startMin / 60, sm = startMin % 60;
   int eh = endMin / 60,   em = endMin % 60;

   // v1.09 (MT4 Hub 1.19 fix): d از -1 شروع می‌شود («روز» هر بازار روی تقویم نیویورک شمرده می‌شود؛ بین ۰۰:۰۰ UTC تا نیمه‌شب
   // نیویورک تاریخ توکیو/لندن یک روز جلوتر است، پس باکس «امروز توکیو» همان d=-1 است). d=-1 وقتی تاریخ‌ها هم‌روزند آینده
   // است و SOB_ProcessOneDay خودش آن را رد می‌کند.
   for(int d = -1; d < days; d++)
   {
      datetime boxStart, boxEnd;
      ST_ComputeSessionByDaysAgoMkt(d, mkt, sh, sm, eh, em, boxStart, boxEnd);   // NY = مسیر قبلی
      bool drawn = SOB_ProcessOneDay(sessionName, boxStart, boxEnd, col, d);
      // v1.09 (MT4 Hub 1.20): SOB_CurrentDayOnly = فقط «آخرین» باکس شروع‌شده‌ی هر سشن و بعد توقف
      if(SOB_CurrentDayOnly && drawn) break;
   }
}

bool SOB_ProcessOneDay(string sessionName, datetime boxStart, datetime boxEnd, color col, int dayIndex)   // v1.09: bool (true = باکس رسم شد)
{
   int shiftStart = iBarShift(Symbol(), SOB_BaseTimeframe, boxStart, false);
   int shiftEnd   = iBarShift(Symbol(), SOB_BaseTimeframe, boxEnd, false);
   if(shiftStart < 0 || shiftEnd < 0) return(false);
   if(shiftStart <= shiftEnd) return(false);
   // v1.09 (MT4 Hub 1.12 guard): اگر تاریخچه‌ی M5 هنوز تا شروع باکس لود نشده، این دور را رد کن (High/Low وابسته به TF چارت نشود)
   int baseBars = iBars(Symbol(), SOB_BaseTimeframe);
   if(baseBars <= 0) return(false);
   if(iTime(Symbol(), SOB_BaseTimeframe, baseBars - 1) > boxStart) return(false);

   double boxHigh = -1, boxLow = -1;
   for(int i = shiftEnd; i <= shiftStart; i++)
   {
      double h = iHigh(Symbol(), SOB_BaseTimeframe, i);
      double l = iLow(Symbol(), SOB_BaseTimeframe, i);
      if(boxHigh < 0 || h > boxHigh) boxHigh = h;
      if(boxLow  < 0 || l < boxLow)  boxLow  = l;
   }
   if(boxHigh <= boxLow) return(false);

   datetime dayEnd = boxEnd - (boxEnd % 86400) + 86400;
   int dayEndShift = iBarShift(Symbol(), SOB_BaseTimeframe, dayEnd, false);
   if(dayEndShift < 0) dayEndShift = 0;

   string tag = sessionName + "_" + IntegerToString(dayIndex);

   if(SOB_ShowOpeningBox)
   {
      SOB_DrawBox(tag, boxStart, boxEnd, boxHigh, boxLow, col);
      SOB_DrawEdgeLine(tag, "High", boxEnd, dayEnd, boxHigh, col);
      SOB_DrawEdgeLine(tag, "Low",  boxEnd, dayEnd, boxLow,  col);
      SOB_DrawBoxSizeLabel(tag, boxStart, boxEnd, boxHigh, boxHigh - boxLow, col);
   }

   if(!SOB_ShowProjectionLevels) return(true);

   int breakoutShift = -1;
   int direction = 0;
   for(int i = shiftEnd - 1; i >= dayEndShift; i--)
   {
      double c = iClose(Symbol(), SOB_BaseTimeframe, i);
      if(c > boxHigh) { breakoutShift = i; direction = 1; }
      if(c < boxLow)  { breakoutShift = i; direction = -1; }
   }
   if(breakoutShift < 0) return(true);

   datetime breakoutTime = iTime(Symbol(), SOB_BaseTimeframe, breakoutShift);
   double boxSize = boxHigh - boxLow;

   for(int lvl = 1; lvl <= SOB_ProjectionLevels; lvl++)
   {
      double price = (direction > 0) ? (boxHigh + lvl * boxSize) : (boxLow - lvl * boxSize);
      SOB_DrawProjectionLine(tag, lvl, breakoutTime, dayEnd, price, col);
   }
   return(true);
}

color SOB_BlendTowardWhite(color c, int pct)
{
   int r = (int)(c & 0xFF);
   int g = (int)((c >> 8) & 0xFF);
   int b = (int)((c >> 16) & 0xFF);
   pct = MathMax(0, MathMin(100, pct));
   r = r + (255 - r) * pct / 100;
   g = g + (255 - g) * pct / 100;
   b = b + (255 - b) * pct / 100;
   return((color)(r + g * 256 + b * 65536));
}

void SOB_DrawBox(string tag, datetime t1, datetime t2, double high, double low, color col)
{
   string name = SOB_PFX + tag + "_Box";
   color fillColor = SOB_BlendTowardWhite(col, SOB_OpeningFillTransparency);

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, high, t2, low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, fillColor);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SOB_DrawBoxSizeLabel(string tag, datetime t1, datetime t2, double topPrice, double boxSize, color col)
{
   string name = SOB_PFX + tag + "_SizeLabel";
   string txt = "$" + DoubleToString(boxSize, 2);
   datetime tMid = t1 + (t2 - t1) / 2;

   ObjectCreate(0, name, OBJ_TEXT, 0, tMid, topPrice);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LOWER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SOB_DrawEdgeLine(string tag, string edgeName, datetime t1, datetime t2, double price, color col)
{
   string name = SOB_PFX + tag + "_" + edgeName;
   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, SOB_EdgeLineWidth);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SOB_DrawProjectionLine(string tag, int lvl, datetime t1, datetime t2, double price, color col)
{
   string name = SOB_PFX + tag + "_Proj" + IntegerToString(lvl);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, SOB_ProjectionLineWidth);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Module 2 - NY Edge                                                 |
//+------------------------------------------------------------------+
bool LoadNYEVisible()
{
   string gvName = "NYE_Visible_" + Symbol();
   if(GlobalVariableCheck(gvName))
      return(GlobalVariableGet(gvName) != 0);
   return(false);
}

void SaveNYEVisible(bool visible)
{
   string gvName = "NYE_Visible_" + Symbol();
   GlobalVariableSet(gvName, visible ? 1.0 : 0.0);
}

void SetNYEButtonColor()
{
   HubSetBg(BTN_NYE, nyeVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

void NYE_Recalculate()
{
   ObjectsDeleteAll(0, NYE_PFX);

   int startMin = ParseHHMM(NYE_NewYorkStart);
   int endMin   = ParseHHMM(NYE_NewYorkEnd);
   int sh = startMin / 60, sm = startMin % 60;
   int eh = endMin / 60,   em = endMin % 60;

   // BUG-FIX (v1.01, Bug 2): loop now starts at daysAgo=-1 (today, and if
   // needed tomorrow) instead of daysAgo=1 (yesterday) - same root cause and
   // same fix as RiskManager EA's BUG-046 (Key Time / Session Level), which
   // uses this exact -1 starting value in both SessionLevel_BuildWindows()
   // and the Session Windows build loop in RM_Tools.mqh.
   // [Port note] the MT4 source ALREADY has this fix applied (confirmed by
   // reading the real file directly, as instructed) - ported as-is, no
   // further correction needed here.
   for(int daysAgo = -1; daysAgo <= 5; daysAgo++)
   {
      datetime boxStart, boxEnd;
      ComputeServerTime(daysAgo, sh, sm, eh, em, boxStart, boxEnd);
      if(NYE_DrawEdge(boxStart, boxEnd, nyeLastBarTime, NYE_EdgeColor))
         break;
   }
}

bool NYE_DrawEdge(datetime boxStart, datetime boxEnd, datetime lineEnd, color col)
{
   col = Theme_ContrastSafe(col);   // v1.12
   int shiftStart = iBarShift(Symbol(), NYE_BaseTimeframe, boxStart, false);
   int shiftEnd   = iBarShift(Symbol(), NYE_BaseTimeframe, boxEnd, false);
   if(shiftStart < 0 || shiftEnd < 0) return(false);
   if(shiftStart <= shiftEnd) return(false);

   double boxHigh = -1, boxLow = -1;
   for(int i = shiftEnd; i <= shiftStart; i++)
   {
      double h = iHigh(Symbol(), NYE_BaseTimeframe, i);
      double l = iLow(Symbol(), NYE_BaseTimeframe, i);
      if(boxHigh < 0 || h > boxHigh) boxHigh = h;
      if(boxLow  < 0 || l < boxLow)  boxLow  = l;
   }
   if(boxHigh <= boxLow) return(false);

   NYE_DrawBoxOutline(boxStart, boxEnd, boxHigh, boxLow, col);
   NYE_DrawDottedLine("High", boxEnd, lineEnd, boxHigh, col);
   NYE_DrawDottedLine("Low",  boxEnd, lineEnd, boxLow,  col);
   NYE_DrawEdgeLabel("HighLbl", "NYH", lineEnd, boxHigh, col);
   NYE_DrawEdgeLabel("LowLbl",  "NYL", lineEnd, boxLow,  col);
   return(true);
}

void NYE_DrawBoxOutline(datetime t1, datetime t2, double high, double low, color col)
{
   string name = NYE_PFX + "Box";
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, high, t2, low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_FILL, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void NYE_DrawDottedLine(string edgeName, datetime t1, datetime t2, double price, color col)
{
   string name = NYE_PFX + edgeName;
   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, NYE_EdgeLineWidth);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void NYE_DrawEdgeLabel(string edgeName, string txt, datetime t, double price, color col)
{
   string name = NYE_PFX + edgeName;
   ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LOWER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Module 3 - MTF Candle Preview                                      |
//+------------------------------------------------------------------+
bool LoadMTFCPVisible()
{
   string gvName = "MTFCandlePreview_Visible_" + Symbol();
   if(GlobalVariableCheck(gvName))
      return(GlobalVariableGet(gvName) != 0);
   return(false);
}

void SaveMTFCPVisible(bool visible)
{
   string gvName = "MTFCandlePreview_Visible_" + Symbol();
   GlobalVariableSet(gvName, visible ? 1.0 : 0.0);
}

void SetMTFCPButtonColor()
{
   HubSetBg(BTN_MTFCP, mtfcpVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

color MTFCP_ContrastSafeColor(color c)
{
   if(!MTFCP_EnsureContrast) return(c);

   long bg = (long)Hub_ChartBg();   // v1.12: override-aware
   int bgR = (int)(bg & 0xFF), bgG = (int)((bg >> 8) & 0xFF), bgB = (int)((bg >> 16) & 0xFF);
   int cR  = (int)(c  & 0xFF), cG  = (int)((c  >> 8) & 0xFF), cB  = (int)((c  >> 16) & 0xFF);

   double bgLum = 0.299 * bgR + 0.587 * bgG + 0.114 * bgB;
   double cLum  = 0.299 * cR  + 0.587 * cG  + 0.114 * cB;
   if(MathAbs(bgLum - cLum) >= MTFCP_ContrastMinDiff) return(c);

   int shift = MTFCP_ContrastShift;
   int nR, nG, nB;
   if(bgLum < 128)
   {
      nR = (int)MathMin(255, cR + shift);
      nG = (int)MathMin(255, cG + shift);
      nB = (int)MathMin(255, cB + shift);
   }
   else
   {
      nR = (int)MathMax(0, cR - shift);
      nG = (int)MathMax(0, cG - shift);
      nB = (int)MathMax(0, cB - shift);
   }
   return((color)(nR | (nG << 8) | (nB << 16)));
}

color MTFCP_BullColor()
{
   color c = (MTFCP_BullColorInp != clrNONE) ? MTFCP_BullColorInp : Hub_ChartBull();   // v1.12: override-aware
   return(MTFCP_ContrastSafeColor(c));
}

color MTFCP_BearColor()
{
   color c = (MTFCP_BearColorInp != clrNONE) ? MTFCP_BearColorInp : Hub_ChartBear();   // v1.12
   return(MTFCP_ContrastSafeColor(c));
}

color MTFCP_LabelColor()
{
   color c = (MTFCP_LabelColorInp != clrNONE) ? MTFCP_LabelColorInp : Hub_ChartFg();   // v1.12
   return(MTFCP_ContrastSafeColor(c));
}

color MTFCP_HistoricalColor()
{
   color c = (MTFCP_HistoricalColorInp != clrNONE) ? MTFCP_HistoricalColorInp : clrDimGray;
   return(MTFCP_ContrastSafeColor(c));
}

double MTFCP_HighestVisibleHigh()
{
   double hh = iHigh(Symbol(), MTFCP_PreviewTF, 0);
   for(int s = 0; s < MTFCP_CandleCount; s++)
   {
      double h = iHigh(Symbol(), MTFCP_PreviewTF, s);
      if(h > hh) hh = h;
   }
   return(hh);
}

double MTFCP_LowestVisibleLow()
{
   double ll = iLow(Symbol(), MTFCP_PreviewTF, 0);
   for(int s = 0; s < MTFCP_CandleCount; s++)
   {
      double l = iLow(Symbol(), MTFCP_PreviewTF, s);
      if(l > 0 && (ll == 0 || l < ll)) ll = l;
   }
   return(ll);
}

string MTFCP_TFName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return("M1");
      case PERIOD_M5:  return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H4:  return("H4");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN1");
      default:         return(IntegerToString(tf));
   }
}

string MTFCP_FormatCountdown(int totalSeconds)
{
   int h = totalSeconds / 3600;
   int m = (totalSeconds % 3600) / 60;
   int s = totalSeconds % 60;
   if(h > 0) return(StringFormat("%d:%02d:%02d", h, m, s));
   return(StringFormat("%d:%02d", m, s));
}

int MTFCP_RealTimeToPixelX(datetime t)
{
   int x = 0, y = 0;
   // [MT5 translation] MT4's implicit Bid predefined variable doesn't exist in MT5 - replaced with
   // SymbolInfoDouble(Symbol(), SYMBOL_BID), same substitution already established in the EA port.
   ChartTimePriceToXY(0, 0, t, SymbolInfoDouble(Symbol(), SYMBOL_BID), x, y);
   return(x);
}

int MTFCP_PriceToPixelY(double price)
{
   int x = 0, y = 0;
   // [MT5 translation] Time[0] -> iTime(Symbol(), Period(), 0), same as WMAP_PriceToPixelY above.
   ChartTimePriceToXY(0, 0, iTime(Symbol(), Period(), 0), price, x, y);
   return(y);
}

int MTFCP_OriginX()
{
   int chartSec = PeriodSeconds(Period());
   if(chartSec <= 0) chartSec = 60;
   // [MT5 translation] Time[0] -> iTime(Symbol(), Period(), 0), same substitution as above.
   datetime originTime = iTime(Symbol(), Period(), 0) + chartSec;
   return(MTFCP_RealTimeToPixelX(originTime));
}

void MTFCP_EnsureChartShift()
{
   if(!(bool)ChartGetInteger(0, CHART_SHIFT))
      ChartSetInteger(0, CHART_SHIFT, true);

   long chartWidthPx = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   if(chartWidthPx <= 0) return;

   double neededPx = MTFCP_GapPx + (MTFCP_SlotWidthPx * MTFCP_CandleCount) + 20;
   double neededPct = (neededPx / (double)chartWidthPx) * 100.0;
   if(neededPct < 10.0) neededPct = 10.0;
   if(neededPct > 50.0) neededPct = 50.0;

   double currentPct = ChartGetDouble(0, CHART_SHIFT_SIZE);
   if(neededPct > currentPct)
      ChartSetDouble(0, CHART_SHIFT_SIZE, neededPct);
}

int MTFCP_AnchorX()
{
   return(MTFCP_OriginX() + MTFCP_GapPx);
}

void MTFCP_SetRectLabel(string name, int xDist, int yDist, int xSize, int ySize, color col)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xDist);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, xSize);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, ySize);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, col);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
}

void MTFCP_DrawDashedHBar(string namePrefix, int leftX, int widthPx, int y, color col, int &prevCount)
{
   int dashLen = 4, gapLen = 3, period = dashLen + gapLen;
   int n = 0;
   for(n = 0; n * period < widthPx; n++)
   {
      int segX = leftX + n * period;
      int segW = (int)MathMin(dashLen, widthPx - n * period);
      if(segW <= 0) break;
      string nm = MTFCP_PFX + namePrefix + "_" + IntegerToString(n);
      MTFCP_SetRectLabel(nm, segX, y, segW, 1, col);
   }
   for(int k = n; k < prevCount; k++)
   {
      string nm = MTFCP_PFX + namePrefix + "_" + IntegerToString(k);
      ObjectDelete(0, nm);
   }
   prevCount = n;
}

void MTFCP_DrawSlot(int i, int shift, int anchorX)
{
   double o = iOpen(Symbol(), MTFCP_PreviewTF, shift);
   double h = iHigh(Symbol(), MTFCP_PreviewTF, shift);
   double l = iLow(Symbol(), MTFCP_PreviewTF, shift);
   double c = iClose(Symbol(), MTFCP_PreviewTF, shift);
   if(o == 0 || h == 0 || l == 0) return;

   bool bull = (c >= o);
   bool isLive = (i == MTFCP_CandleCount - 1);
   color col;
   if(!isLive && MTFCP_DimHistorical)
      col = MTFCP_HistoricalColor();
   else
      col = bull ? MTFCP_BullColor() : MTFCP_BearColor();

   int slotStartX = anchorX + i * MTFCP_SlotWidthPx;
   int centerX    = slotStartX + MTFCP_SlotWidthPx / 2;

   int halfBodyPx = (int)(MTFCP_SlotWidthPx * MTFCP_BodyWidthRatio / 2.0);
   if(halfBodyPx < 1) halfBodyPx = 1;
   int bodyLeftX  = centerX - halfBodyPx;
   int bodyWidthPx = halfBodyPx * 2;

   int halfWickPx = 1;
   int wickLeftX  = centerX - halfWickPx;
   int wickWidthPx = halfWickPx * 2;

   double bodyTop    = MathMax(o, c);
   double bodyBottom = MathMin(o, c);
   if(bodyTop == bodyBottom)
   {
      // [MT5 translation] MT4's MarketInfo(sym, MODE_POINT) doesn't exist in MT5 - replaced with
      // SymbolInfoDouble(sym, SYMBOL_POINT), same substitution already established in the EA port.
      double tick = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
      bodyTop += tick;
   }

   int yBodyA = MTFCP_PriceToPixelY(bodyTop);
   int yBodyB = MTFCP_PriceToPixelY(bodyBottom);
   int yBodyTop    = MathMin(yBodyA, yBodyB);
   int bodyHeightPx = MathMax(yBodyA, yBodyB) - yBodyTop;
   if(bodyHeightPx < 1) bodyHeightPx = 1;

   int yWickA = MTFCP_PriceToPixelY(h);
   int yWickB = MTFCP_PriceToPixelY(l);
   int yWickTop    = MathMin(yWickA, yWickB);
   int wickHeightPx = MathMax(yWickA, yWickB) - yWickTop;
   if(wickHeightPx < 1) wickHeightPx = 1;

   string bodyName = MTFCP_PFX + "Body_" + IntegerToString(i);
   MTFCP_SetRectLabel(bodyName, bodyLeftX, yBodyTop, bodyWidthPx, bodyHeightPx, col);

   string wickName = MTFCP_PFX + "Wick_" + IntegerToString(i);
   MTFCP_SetRectLabel(wickName, wickLeftX, yWickTop, wickWidthPx, wickHeightPx, col);

   if(i == MTFCP_CandleCount - 1)
      MTFCP_DrawTFNameLabel(anchorX);
}

void MTFCP_DrawLiveConnector(int anchorX)
{
   int shift, i;
   if(MTFCP_ConnectorSource == CONN_SRC_LIVE)
   {
      shift = 0;
      i = MTFCP_CandleCount - 1;
   }
   else
   {
      shift = 1;
      i = MTFCP_CandleCount - 2;
   }

   double h = iHigh(Symbol(), MTFCP_PreviewTF, shift);
   double l = iLow(Symbol(), MTFCP_PreviewTF, shift);
   if(h == 0 || l == 0) return;

   int originX = anchorX - MTFCP_GapPx;
   int targetX = anchorX + i * MTFCP_SlotWidthPx + MTFCP_SlotWidthPx / 2;

   int leftX  = MathMin(originX, targetX);
   int widthPx = MathAbs(targetX - originX);
   if(widthPx < 1) widthPx = 1;

   color col = MTFCP_LabelColor();

   int yH = MTFCP_PriceToPixelY(h);
   MTFCP_DrawDashedHBar("ConnHigh", leftX, widthPx, yH, col, mtfcpPrevConnHighSegCount);

   int yL = MTFCP_PriceToPixelY(l);
   MTFCP_DrawDashedHBar("ConnLow", leftX, widthPx, yL, col, mtfcpPrevConnLowSegCount);
}

void MTFCP_DrawTFNameLabel(int anchorX)
{
   string name = MTFCP_PFX + "TFName";
   int midX = anchorX + (MTFCP_SlotWidthPx * MTFCP_CandleCount) / 2;
   double topPrice = MTFCP_HighestVisibleHigh() + (SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 200);
   int y = MTFCP_PriceToPixelY(topPrice);

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, midX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, MTFCP_LabelColor());
   ObjectSetString(0, name, OBJPROP_TEXT, MTFCP_TFName(MTFCP_PreviewTF));
}

void MTFCP_UpdateCountdownLabel()
{
   int periodSecPreview = PeriodSeconds(MTFCP_PreviewTF);
   if(periodSecPreview <= 0) periodSecPreview = 60;
   datetime closeTime = iTime(Symbol(), MTFCP_PreviewTF, 0) + periodSecPreview;
   int remaining = (int)(closeTime - TimeCurrent());
   if(remaining < 0) remaining = 0;

   string txt = MTFCP_FormatCountdown(remaining);

   int anchorX = MTFCP_AnchorX();
   int midX = anchorX + (MTFCP_SlotWidthPx * MTFCP_CandleCount) / 2;
   double bottomPrice = MTFCP_LowestVisibleLow() - (SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 200);
   int y = MTFCP_PriceToPixelY(bottomPrice);

   string name = MTFCP_PFX + "Countdown";
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, midX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, MTFCP_LabelColor());
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

void MTFCP_DrawAll()
{
   int anchorX = MTFCP_AnchorX();
   for(int i = 0; i < MTFCP_CandleCount; i++)
   {
      int shift = MTFCP_CandleCount - 1 - i;
      MTFCP_DrawSlot(i, shift, anchorX);
   }
   if(MTFCP_ShowLiveConnector)
      MTFCP_DrawLiveConnector(anchorX);
}

void MTFCP_UpdateLiveCandle()
{
   int anchorX = MTFCP_AnchorX();
   int i = MTFCP_CandleCount - 1;
   MTFCP_DrawSlot(i, 0, anchorX);
   if(MTFCP_ShowLiveConnector)
      MTFCP_DrawLiveConnector(anchorX);
}

void MTFCP_PrintDebugInfo()
{
   int anchorX = MTFCP_AnchorX();
   string txt = "";
   txt += "=== MTF Candle Preview DEBUG ===\n";
   txt += "OriginX = " + IntegerToString(MTFCP_OriginX()) + "   GapPx = " + IntegerToString(MTFCP_GapPx) + "   AnchorX = " + IntegerToString(anchorX) + "\n";
   for(int i = 0; i < MTFCP_CandleCount; i++)
   {
      int shift = MTFCP_CandleCount - 1 - i;
      double o = iOpen(Symbol(), MTFCP_PreviewTF, shift);
      double h = iHigh(Symbol(), MTFCP_PreviewTF, shift);
      double l = iLow(Symbol(), MTFCP_PreviewTF, shift);
      double c = iClose(Symbol(), MTFCP_PreviewTF, shift);
      // [MT5 translation] MT4's implicit Digits (current-symbol digit count) doesn't exist in MT5 -
      // replaced with _Digits, same substitution already established throughout the EA port.
      txt += "i=" + IntegerToString(i) + " shift=" + IntegerToString(shift)
           + " O=" + DoubleToString(o, _Digits) + " H=" + DoubleToString(h, _Digits)
           + " L=" + DoubleToString(l, _Digits) + " C=" + DoubleToString(c, _Digits) + "\n";
   }
   Comment(txt);
}
