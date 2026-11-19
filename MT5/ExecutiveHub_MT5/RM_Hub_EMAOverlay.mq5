//+------------------------------------------------------------------+
//| RM_Hub_EMAOverlay.mq5                                              |
//| Executive Hub — MT5 port, Stage 5e-iii                             |
//| Ported from ExecutiveHub_v1_07.mq4                                 |
//|                                                                    |
//| SCOPE (per Stage5e-iii_Task_Message.md): SetEMAButtonColors,       |
//| EMA_ApplyIndexStyles, EMA_ApplyGrayscaleColors, EMA_Recalculate,   |
//| plus the buffer-registration block from MT4's OnInit() (lines      |
//| 566-599), separated into its own callable EMA_RegisterBuffers()    |
//| for 5e-iv's OnInit() to call.                                      |
//|                                                                    |
//| Depends on Stage 5e-i's RM_Hub_PanelDrawLabel.mq5 for BTN_EMA10/   |
//| 20/60/240, CLR_SUBTOGGLE_ACTIVE, CLR_INACTIVE_GRAY, and the        |
//| gShowEMA10/20/60/240 booleans it already declared - NOT redeclared |
//| here to avoid duplicate-definition errors when both are #included. |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Inputs                                                             |
//+------------------------------------------------------------------+
enum ENUM_DISPLAY_MODE
{
   Mode_FourLines     = 0, // Ladder: all 4 EMAs drawn as separate lines
   Mode_ActiveCloud   = 1, // Static 20/60 cloud + separate EMA240 line
   Mode_MomentumColor = 2  // EMA60 colored Bullish/Bearish/Neutral; EMA10/20/240 stay grayscale
};

input ENUM_DISPLAY_MODE EMA_DisplayMode = Mode_FourLines;
input int EMA1_Period = 10;
input int EMA2_Period = 20;
input int EMA3_Period = 60;
input int EMA4_Period = 240;
input double EMA_Mode3_GapFilter    = 0.001;
input color  EMA_Mode3_BullishColor = clrSeaGreen;
input color  EMA_Mode3_BearishColor = clrIndianRed;
input color  EMA_Mode3_NeutralColor = clrGray;

//+------------------------------------------------------------------+
//| Indicator buffers (7 real plot buffers, index 0-6)                 |
//+------------------------------------------------------------------+
double Ema10Buffer[];
double Ema20Buffer[];
double Ema60Buffer[];
double Ema240Buffer[];
double Ema60BullBuffer[];
double Ema60BearBuffer[];
double Ema60NeutBuffer[];

//+------------------------------------------------------------------+
//| [MT5 architectural addition, not a mechanical rename] MQL4's flat  |
//| iMA(symbol, tf, period, shift, method, price, bar_shift) call      |
//| that returns a double directly DOES NOT EXIST in MQL5 - iMA()/     |
//| iATR() in MQL5 return an indicator HANDLE (int) instead, and the   |
//| actual values must be read via CopyBuffer(). This is different     |
//| from iHigh/iLow/iClose/iHighest/iLowest/iBarShift, which MQL5 DOES |
//| keep as direct-value compatibility functions (confirmed against   |
//| the official MQL5 "Timeseries and Indicators Access" function      |
//| list) - iMA/iATR are simply not on that list. No mechanical rename |
//| fixes this; it requires a handle + CopyBuffer restructure. See     |
//| EMA_RegisterBuffers() (handle creation) and EMA_Recalculate()      |
//| (CopyBuffer usage) below, and the Stage 5e-iii report for the full |
//| explanation of this judgment call.                                |
//+------------------------------------------------------------------+
int h_ema1 = INVALID_HANDLE;
int h_ema2 = INVALID_HANDLE;
int h_ema3 = INVALID_HANDLE;
int h_ema4 = INVALID_HANDLE;
int h_atr14 = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| EMA_RegisterBuffers() - the OnInit-callable seam 5e-iv needs.      |
//| Ports the buffer-registration block from MT4 OnInit() (lines       |
//| 566-599), plus creates the iMA/iATR handles EMA_Recalculate()      |
//| depends on (a genuinely new step MT4 never needed - grouped here   |
//| because handle creation, like SetIndexBuffer, is conceptually      |
//| "OnInit-time setup", and 5e-iv's OnInit() is the correct one-time  |
//| call site for both).                                               |
//|                                                                    |
//| [MT5 translation, per task's explicit API notes]                   |
//| SetIndexBuffer(i, arr) -> SetIndexBuffer(i, arr, INDICATOR_DATA)   |
//|   - all 7 buffers are plotted calculation results, not color-index |
//|     or calc-only buffers, so INDICATOR_DATA is correct for all 7.  |
//| SetIndexEmptyValue(i, v) -> PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, v) |
//| SetIndexLabel(i, text) -> PlotIndexSetString(i, PLOT_LABEL, text)  |
//|   - the NULL ("no label") cases use "" (empty string), confirmed   |
//|     as MQL5's documented equivalent for PLOT_LABEL - not the       |
//|     literal string "NULL", which the task flagged as a trap.       |
//+------------------------------------------------------------------+
void EMA_RegisterBuffers()
{
   SetIndexBuffer(0, Ema10Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, Ema20Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, Ema60Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, Ema240Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, Ema60BullBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, Ema60BearBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, Ema60NeutBuffer, INDICATOR_DATA);
   // [REAL BUG, found live during Mahmoud's Stage 5e-iii testing] indicator buffers registered via
   // SetIndexBuffer are NOT automatically series-indexed (index 0 = most recent bar) in MQL5 -
   // despite this being a very common assumption carried over from MT4. Without explicitly setting
   // this, every Ema*Buffer[shift] write in EMA_Recalculate() below lands at the wrong chronological
   // position - confirmed live: values ended up running backward through time relative to the real
   // price series (a red flag pattern: old EMA values appearing on the chart's recent/right side).
   // This single missing call was the actual root cause of "nothing visible on chart" - the earlier
   // CopyBuffer-timing and PLOT_-property-timing hypotheses were both red herrings; data and plot
   // properties were correct the whole time, only the buffer's own index direction was wrong.
   ArraySetAsSeries(Ema10Buffer, true);
   ArraySetAsSeries(Ema20Buffer, true);
   ArraySetAsSeries(Ema60Buffer, true);
   ArraySetAsSeries(Ema240Buffer, true);
   ArraySetAsSeries(Ema60BullBuffer, true);
   ArraySetAsSeries(Ema60BearBuffer, true);
   ArraySetAsSeries(Ema60NeutBuffer, true);
   for(int b3 = 0; b3 < 7; b3++)
      PlotIndexSetDouble(b3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   EMA_ApplyIndexStyles();
   SetEMAButtonColors();

   if(EMA_DisplayMode == Mode_ActiveCloud)
   {
      PlotIndexSetString(0, PLOT_LABEL, "EMA " + IntegerToString(EMA2_Period));
      PlotIndexSetString(1, PLOT_LABEL, "EMA " + IntegerToString(EMA3_Period));
      PlotIndexSetString(2, PLOT_LABEL, "EMA " + IntegerToString(EMA4_Period));
      PlotIndexSetString(3, PLOT_LABEL, ""); PlotIndexSetString(4, PLOT_LABEL, "");
      PlotIndexSetString(5, PLOT_LABEL, ""); PlotIndexSetString(6, PLOT_LABEL, "");
   }
   else if(EMA_DisplayMode == Mode_MomentumColor)
   {
      PlotIndexSetString(0, PLOT_LABEL, "EMA " + IntegerToString(EMA1_Period));
      PlotIndexSetString(1, PLOT_LABEL, "EMA " + IntegerToString(EMA2_Period));
      PlotIndexSetString(2, PLOT_LABEL, "");
      PlotIndexSetString(3, PLOT_LABEL, "EMA " + IntegerToString(EMA4_Period));
      PlotIndexSetString(4, PLOT_LABEL, "EMA " + IntegerToString(EMA3_Period) + " (Bullish)");
      PlotIndexSetString(5, PLOT_LABEL, "EMA " + IntegerToString(EMA3_Period) + " (Bearish)");
      PlotIndexSetString(6, PLOT_LABEL, "EMA " + IntegerToString(EMA3_Period) + " (Neutral)");
   }
   else
   {
      PlotIndexSetString(0, PLOT_LABEL, "EMA " + IntegerToString(EMA1_Period));
      PlotIndexSetString(1, PLOT_LABEL, "EMA " + IntegerToString(EMA2_Period));
      PlotIndexSetString(2, PLOT_LABEL, "EMA " + IntegerToString(EMA3_Period));
      PlotIndexSetString(3, PLOT_LABEL, "EMA " + IntegerToString(EMA4_Period));
      PlotIndexSetString(4, PLOT_LABEL, ""); PlotIndexSetString(5, PLOT_LABEL, ""); PlotIndexSetString(6, PLOT_LABEL, "");
   }
   EMA_ApplyGrayscaleColors();

   // [New step, MT4 had no equivalent] create the iMA/iATR handles EMA_Recalculate() needs -
   // see the file header comment for why this can't be a flat per-call function like MT4's iMA().
   h_ema1  = iMA(Symbol(), Period(), EMA1_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ema2  = iMA(Symbol(), Period(), EMA2_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ema3  = iMA(Symbol(), Period(), EMA3_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ema4  = iMA(Symbol(), Period(), EMA4_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_atr14 = iATR(Symbol(), Period(), 14);
}

void SetEMAButtonColors()
{
   HubSetBg(BTN_EMA10, gShowEMA10 ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   HubSetBg(BTN_EMA20, gShowEMA20 ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   HubSetBg(BTN_EMA60, gShowEMA60 ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   HubSetBg(BTN_EMA240, gShowEMA240 ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

//+------------------------------------------------------------------+
//| v3.20 منطق: EMA20/EMA60 توی Mode_ActiveCloud یه ابر جفتی تشکیل      |
//| می‌دن (DRAW_HISTOGRAM به هر دو بافر نیاز داره)، پس نمی‌شه جدا مخفیشون |
//| کرد؛ توی Mode_MomentumColor هم مخفی‌کردن EMA60 هر سه سگمنت رنگی رو    |
//| باهم مخفی می‌کنه. این‌ها محدودیت‌های ذاتی خودِ حالت‌هان، نه باگ.        |
//|                                                                    |
//| [MT5 translation, per task's explicit API note] SetIndexStyle(i,   |
//| draw, style, width) split into 3 calls. Where the MT4 source only  |
//| called the 2-arg form (draw type only, e.g. "SetIndexStyle(3,      |
//| DRAW_NONE)"), only PLOT_DRAW_TYPE is set here too - style/width     |
//| were never specified by the source for those buffers either, so    |
//| this preserves the original's intent exactly rather than inventing |
//| style/width values that weren't there.                             |
//+------------------------------------------------------------------+
void EMA_ApplyIndexStyles()
{
   if(EMA_DisplayMode == Mode_ActiveCloud)
   {
      bool showCloud = (gShowEMA20 && gShowEMA60);
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, showCloud ? DRAW_HISTOGRAM : DRAW_NONE);
      PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 0);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, showCloud ? DRAW_HISTOGRAM : DRAW_NONE);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 0);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, gShowEMA240 ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(2, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 2);
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   else if(EMA_DisplayMode == Mode_MomentumColor)
   {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, gShowEMA10 ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, gShowEMA20 ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, gShowEMA240 ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(3, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 2);
      PlotIndexSetInteger(4, PLOT_DRAW_TYPE, gShowEMA60 ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(4, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(4, PLOT_LINE_WIDTH, 2);
      PlotIndexSetInteger(5, PLOT_DRAW_TYPE, gShowEMA60 ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(5, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(5, PLOT_LINE_WIDTH, 2);
      PlotIndexSetInteger(6, PLOT_DRAW_TYPE, gShowEMA60 ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(6, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(6, PLOT_LINE_WIDTH, 2);
   }
   else
   {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, gShowEMA10  ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, gShowEMA20  ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, gShowEMA60  ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(2, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 3);
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, gShowEMA240 ? DRAW_LINE : DRAW_NONE);
      PlotIndexSetInteger(3, PLOT_LINE_STYLE, STYLE_SOLID);
      PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 4);
      PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE);
   }
}

void EMA_ApplyGrayscaleColors()
{
   color bg = Hub_ChartBg();   // v1.12: override-aware
   int r = (int)(bg & 0xFF);
   int g = (int)((bg >> 8) & 0xFF);
   int b = (int)((bg >> 16) & 0xFF);
   double luminance = (r * 0.299) + (g * 0.587) + (b * 0.114);
   bool isDark = (luminance < 128);

   if(EMA_DisplayMode == Mode_ActiveCloud)
   {
      color cloudClr = isDark ? (color)C'150,150,150' : (color)C'110,110,110';
      color lineClr  = isDark ? (color)C'230,230,230' : (color)C'30,30,30';
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, Theme_ContrastSafe(cloudClr));
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, Theme_ContrastSafe(cloudClr));
      PlotIndexSetInteger(2, PLOT_LINE_COLOR, Theme_ContrastSafe(lineClr));
      return;
   }

   if(EMA_DisplayMode == Mode_MomentumColor)
   {
      color g10  = isDark ? (color)C'140,140,140' : (color)C'150,150,150';
      color g20  = isDark ? (color)C'120,120,120' : (color)C'130,130,130';
      color g240 = isDark ? (color)C'80,80,80'    : (color)C'90,90,90';
      PlotIndexSetInteger(0, PLOT_LINE_COLOR, Theme_ContrastSafe(g10));
      PlotIndexSetInteger(1, PLOT_LINE_COLOR, Theme_ContrastSafe(g20));
      PlotIndexSetInteger(3, PLOT_LINE_COLOR, Theme_ContrastSafe(g240));
      PlotIndexSetInteger(4, PLOT_LINE_COLOR, Theme_ContrastSafe(EMA_Mode3_BullishColor));
      PlotIndexSetInteger(5, PLOT_LINE_COLOR, Theme_ContrastSafe(EMA_Mode3_BearishColor));
      PlotIndexSetInteger(6, PLOT_LINE_COLOR, Theme_ContrastSafe(EMA_Mode3_NeutralColor));
      return;
   }

   color c1, c2, c3, c4;
   if(isDark)
   {
      c1 = C'140,140,140'; c2 = C'120,120,120'; c3 = C'100,100,100'; c4 = C'80,80,80';
   }
   else
   {
      c1 = C'150,150,150'; c2 = C'130,130,130'; c3 = C'110,110,110'; c4 = C'90,90,90';
   }
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, Theme_ContrastSafe(c1));
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, Theme_ContrastSafe(c2));
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, Theme_ContrastSafe(c3));
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, Theme_ContrastSafe(c4));
}

//+------------------------------------------------------------------+
//| محاسبه‌ی هر تیک EMA - عیناً منطق نسخه‌ی مستقل، فقط early-return ها به  |
//| return ساده تبدیل شدن (چون این تابع void هست، نه OnCalculate خودش)  |
//|                                                                    |
//| [MT5 translation - the big one, see file header] every iMA(...,    |
//| shift) call is replaced with an index into a range CopyBuffer()'d  |
//| ONCE at the top of this function (not per-shift - CopyBuffer per   |
//| iteration inside a shift loop would work but re-issues a call for  |
//| every single bar, which is both slow and not how MQL5 code is      |
//| normally written; copying the whole needed range once is the       |
//| standard idiomatic pattern). iHighest/iLowest/iHigh/iLow/iClose    |
//| stay as direct compatibility calls (confirmed on MQL5's official    |
//| list) - only iMA/iATR needed this restructure. Symbol()/Period()   |
//| used instead of NULL/0, matching this file's own established       |
//| convention elsewhere (POC/SOB/NYE/MTFCP all already do this).       |
//+------------------------------------------------------------------+
void EMA_Recalculate(int rates_total, int prev_calculated)
{
   static bool emaColorsApplied = false;
   if(!emaColorsApplied)
   {
      EMA_ApplyGrayscaleColors();
      emaColorsApplied = true;
   }

   bool fullRecalc = (prev_calculated <= 0);
   int limit = rates_total - 1 - prev_calculated;
   if(fullRecalc || limit >= rates_total) limit = rates_total - 1;
   if(limit < 0) limit = 0;

   // Copy the [0..limit] range once per handle - covers every shift the loops below touch.
   int need = limit + 1;
   double ema1arr[], ema2arr[], ema3arr[], ema4arr[], atrArr[];
   ArraySetAsSeries(ema1arr, true); ArraySetAsSeries(ema2arr, true);
   ArraySetAsSeries(ema3arr, true); ArraySetAsSeries(ema4arr, true);
   ArraySetAsSeries(atrArr, true);
   bool ok = true;
   int got1 = CopyBuffer(h_ema1, 0, 0, need, ema1arr);
   int got2 = CopyBuffer(h_ema2, 0, 0, need, ema2arr);
   int got3 = CopyBuffer(h_ema3, 0, 0, need, ema3arr);
   int got4 = CopyBuffer(h_ema4, 0, 0, need, ema4arr);
   int got5 = 0;
   ok = (got1==need) && (got2==need) && (got3==need) && (got4==need);
   if(EMA_DisplayMode == Mode_MomentumColor)
   {
      got5 = CopyBuffer(h_atr14, 0, 0, need, atrArr);
      ok = ok && (got5==need);
   }
   // [DEBUG-EMACOPY, temporary diagnostic - same pattern as the EA port's DEBUG-MARKERS] pinpoints
   // whether CopyBuffer is returning fewer bars than requested right after handle creation (a known
   // MT5 gotcha: a freshly-created handle's underlying calculation may not be ready on the very
   // first call). If ok=false here, that's why nothing gets written to the plot buffers this call.
   // v1.08: this used to print on EVERY call (several times per second per chart, 8+ MB of log per
   // session). Now it prints only when CopyBuffer is NOT ready, at most 5 times per chart.
   static int s_emaCopyFailPrints = 0;
   if(!ok && s_emaCopyFailPrints < 5)
   {
      s_emaCopyFailPrints++;
      Print("[DEBUG-EMACOPY] not ready: need=", need, " got1=", got1, " got2=", got2, " got3=", got3, " got4=", got4,
            " got5=", got5, " handles=", h_ema1, ",", h_ema2, ",", h_ema3, ",", h_ema4, ",", h_atr14);
   }
   if(!ok) return; // handles not ready / not enough history yet - try again next call, same as
                    // MT4 implicitly would if iMA() returned an incomplete value early on.

   if(EMA_DisplayMode == Mode_FourLines)
   {
      for(int shift = limit; shift >= 0; shift--)
      {
         Ema10Buffer[shift]  = ema1arr[shift];
         Ema20Buffer[shift]  = ema2arr[shift];
         Ema60Buffer[shift]  = ema3arr[shift];
         Ema240Buffer[shift] = ema4arr[shift];
      }
      return;
   }

   if(EMA_DisplayMode == Mode_ActiveCloud)
   {
      for(int shift = limit; shift >= 0; shift--)
      {
         Ema10Buffer[shift]  = ema2arr[shift];
         Ema20Buffer[shift]  = ema3arr[shift];
         Ema60Buffer[shift]  = ema4arr[shift];
         Ema240Buffer[shift] = EMPTY_VALUE;
      }
      return;
   }

   //--- Mode_MomentumColor ---
   static bool   mc_initialized     = false;
   static int    mc_stateClosed     = 0;
   static double mc_swingHighClosed = 0;
   static double mc_swingLowClosed  = 0;

   if(fullRecalc || !mc_initialized)
   {
      mc_stateClosed     = 0;
      mc_swingHighClosed = 0;
      mc_swingLowClosed  = 0;
      mc_initialized     = true;
   }

   int    workState = mc_stateClosed;
   double workHigh  = mc_swingHighClosed;
   double workLow   = mc_swingLowClosed;

   for(int shift = limit; shift >= 0; shift--)
   {
      double ema10  = ema1arr[shift];
      double ema20  = ema2arr[shift];
      double ema60  = ema3arr[shift];
      double ema240 = ema4arr[shift];
      double atr14  = atrArr[shift];
      double closeP = iClose(Symbol(), Period(), shift);
      double highP  = iHigh(Symbol(), Period(), shift);
      double lowP   = iLow(Symbol(), Period(), shift);

      int idxHH15_1 = iHighest(Symbol(), Period(), MODE_HIGH, 15, shift + 1);
      int idxHH15_2 = iHighest(Symbol(), Period(), MODE_HIGH, 15, shift + 2);
      int idxHH30_1 = iHighest(Symbol(), Period(), MODE_HIGH, 30, shift + 1);
      int idxHH30_2 = iHighest(Symbol(), Period(), MODE_HIGH, 30, shift + 2);
      double hh15_1 = (idxHH15_1 >= 0) ? iHigh(Symbol(), Period(), idxHH15_1) : highP;
      double hh15_2 = (idxHH15_2 >= 0) ? iHigh(Symbol(), Period(), idxHH15_2) : highP;
      double hh30_1 = (idxHH30_1 >= 0) ? iHigh(Symbol(), Period(), idxHH30_1) : highP;
      double hh30_2 = (idxHH30_2 >= 0) ? iHigh(Symbol(), Period(), idxHH30_2) : highP;
      double prevHigh = iHigh(Symbol(), Period(), shift + 1);

      bool crossHigh15 = (highP > hh15_1) && (prevHigh <= hh15_2);
      bool crossHigh30 = (highP > hh30_1) && (prevHigh <= hh30_2);
      bool newSwingHigh = crossHigh15 || crossHigh30;
      bool gapOkHigh = (workHigh <= 0) || (MathAbs(highP - workHigh) > closeP * EMA_Mode3_GapFilter);
      if(newSwingHigh && gapOkHigh)
         workHigh = highP;

      int idxLL15_1 = iLowest(Symbol(), Period(), MODE_LOW, 15, shift + 1);
      int idxLL15_2 = iLowest(Symbol(), Period(), MODE_LOW, 15, shift + 2);
      int idxLL30_1 = iLowest(Symbol(), Period(), MODE_LOW, 30, shift + 1);
      int idxLL30_2 = iLowest(Symbol(), Period(), MODE_LOW, 30, shift + 2);
      double ll15_1 = (idxLL15_1 >= 0) ? iLow(Symbol(), Period(), idxLL15_1) : lowP;
      double ll15_2 = (idxLL15_2 >= 0) ? iLow(Symbol(), Period(), idxLL15_2) : lowP;
      double ll30_1 = (idxLL30_1 >= 0) ? iLow(Symbol(), Period(), idxLL30_1) : lowP;
      double ll30_2 = (idxLL30_2 >= 0) ? iLow(Symbol(), Period(), idxLL30_2) : lowP;
      double prevLow = iLow(Symbol(), Period(), shift + 1);

      bool crossLow15 = (lowP < ll15_1) && (prevLow >= ll15_2);
      bool crossLow30 = (lowP < ll30_1) && (prevLow >= ll30_2);
      bool newSwingLow = crossLow15 || crossLow30;
      bool gapOkLow = (workLow <= 0) || (MathAbs(lowP - workLow) > closeP * EMA_Mode3_GapFilter);
      if(newSwingLow && gapOkLow)
         workLow = lowP;

      bool bullishBOS = (workHigh > 0) && (closeP > workHigh) && (closeP > ema60);
      bool bearishBOS = (workLow  > 0) && (closeP < workLow)  && (closeP < ema60);
      bool isRange     = (MathAbs(ema20 - ema60) < 0.35 * atr14);

      int newState = workState;
      if(bullishBOS) newState = 1;
      else if(bearishBOS) newState = -1;
      else if(isRange) newState = 0;
      else if(closeP > ema60 && ema10 > ema20) newState = 1;
      else if(closeP < ema60 && ema10 < ema20) newState = -1;

      Ema60BullBuffer[shift] = EMPTY_VALUE;
      Ema60BearBuffer[shift] = EMPTY_VALUE;
      Ema60NeutBuffer[shift] = EMPTY_VALUE;

      if(newState == 1)       Ema60BullBuffer[shift] = ema60;
      else if(newState == -1) Ema60BearBuffer[shift] = ema60;
      else                     Ema60NeutBuffer[shift] = ema60;

      if(newState != workState)
      {
         if(workState == 1)       Ema60BullBuffer[shift] = ema60;
         else if(workState == -1) Ema60BearBuffer[shift] = ema60;
         else                      Ema60NeutBuffer[shift] = ema60;
      }

      workState = newState;

      Ema10Buffer[shift]  = ema10;
      Ema20Buffer[shift]  = ema20;
      Ema240Buffer[shift] = ema240;
      Ema60Buffer[shift]  = EMPTY_VALUE;

      if(shift >= 1)
      {
         mc_stateClosed     = workState;
         mc_swingHighClosed = workHigh;
         mc_swingLowClosed  = workLow;
      }
   }
}
