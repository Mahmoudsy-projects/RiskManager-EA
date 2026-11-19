//+------------------------------------------------------------------+
//| RM_Hub_Main.mq5                                                    |
//| Executive Hub — MT5 port, Stage 5e-iv                              |
//| Ported from ExecutiveHub_v1_07.mq4                                 |
//|                                                                    |
//| SCOPE (per Stage5e-iv_Task_Message.md): OnInit, OnDeinit,           |
//| OnCalculate, OnTimer, plus the final reconciled #property block.   |
//| NOT in this file: OnChartEvent (~780 lines, deliberately deferred  |
//| to 5e-v - real clicking still does nothing until then, same as    |
//| every prior sub-stage).                                            |
//|                                                                    |
//| This IS the real, final top-level compiled file - #includes all    |
//| three prior sub-stages' module files and owns the one true         |
//| #property block. Attach this directly; no separate test harness    |
//| wrapper needed this stage, since OnInit/OnCalculate/OnTimer ARE    |
//| the real entry points the terminal now drives automatically.       |
//+------------------------------------------------------------------+
#property copyright "MAHMOUD SEYEDI"
#property description "Executive Hub"
#property description "Toggle-button drawing + labeling + indicator tools in"
#property description "one unified, minimize-able panel."
#property description "Drawn shapes/labels are independent, selectable chart"
#property description "objects that persist even if this indicator is removed -"
#property description "delete them manually if needed."
#property version   "1.17"   // v1.16: تم Custom (جایگزین Original؛ Custom/S/R، ذخیره‌ی سراسری). v1.15: حذف Print تشخیصی [HUB-PATHGROUP]. v1.14: ابزارهای Path ۲ و Line ۲ + ترتیب شماره‌ی تم‌ها (v1.13: تم‌های ۸-۱۰)
#property strict
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   7
#property indicator_color1 Silver
#property indicator_color2 Gray
#property indicator_color3 DimGray
#property indicator_color4 DarkSlateGray
#property indicator_color5 SeaGreen
#property indicator_color6 IndianRed
#property indicator_color7 Gray

#include "RM_SessionTime.mq5"        // v1.09 (P2، MT4 Hub 1.18): ماژول مشترک زمان سشن (byte-identical با EA)
#include "RM_Hub_PanelDrawLabel.mq5"
#include "RM_Hub_Modules123.mq5"
#include "RM_Hub_EMAOverlay.mq5"

//+------------------------------------------------------------------+
//| [Gap found at compile, Stage 5e-iv] these two live in the MT4      |
//| source's panel-core global-state region (same neighborhood as     |
//| g_hubNeedsRaise, which 5e-i DID declare) but were missed in 5e-i   |
//| because none of that sub-stage's 41 requested functions actually   |
//| used them - only OnInit()/OnTimer() (this stage) do. Declared here |
//| rather than retroactively editing RM_Hub_PanelDrawLabel.mq5, since  |
//| this stage is their only real consumer.                            |
//+------------------------------------------------------------------+
datetime gHubLastInteraction = 0;
#define HUB_AUTO_MINIMIZE_IDLE_SECONDS 60

//+------------------------------------------------------------------+
//| v1.12 (FEAT-052): اعمال تم. در Main است چون به ماژول‌های ۱-۳ وابسته است. |
//+------------------------------------------------------------------+
//--- themeIdx: 0..9 = تم ۱..۱۰؛ -1 = Original. یک بار رنگ‌ها را روی چارتِ فعلی می‌نویسد، آبجکت‌های Hub را یک‌بار بازرنگ می‌کند،
//--- دکمه‌ها را به‌روز می‌کند و یک ChartRedraw() می‌زند.
void Theme_Apply(int themeIdx)
{
   color cc[13]; bool cg, cs, ca; int cm;
   if(themeIdx >= 0 && themeIdx < THEME_COUNT)
   {
      if(!Theme_EnsureOriginalStored())
      {
         Print("ExecutiveHub: Theme - could not store the Original chart colours; the theme was NOT applied.");
         return;
      }
      cc[0] = THEME_BG[themeIdx];   cc[1] = THEME_FG[themeIdx];    cc[2] = THEME_GRID[themeIdx];
      cc[3] = THEME_BARUP[themeIdx]; cc[4] = THEME_BARDN[themeIdx];
      cc[5] = THEME_BULL[themeIdx]; cc[6] = THEME_BEAR[themeIdx];
      cc[7] = THEME_LINE[themeIdx]; cc[8] = THEME_VOL[themeIdx];
      cc[9] = THEME_ASK[themeIdx];  cc[10] = THEME_STOP[themeIdx];
      cc[11] = THEME_BID[themeIdx]; cc[12] = THEME_LAST[themeIdx];   // v1.13
      cg = false; cs = true; ca = true; cm = (int)CHART_CANDLES;
   }
   else
   {
      if(ObjectFind(0, THEME_ORIG_NAME) < 0 ||
         !Theme_Decode(ObjectGetString(0, THEME_ORIG_NAME, OBJPROP_TEXT), cc, cg, cs, ca, cm))
      {
         Print("ExecutiveHub: Theme - no stored Original on this chart (no theme has been applied here yet).");
         return;
      }
      themeIdx = -1;
   }

   Theme_WriteChart(cc, cg, cs, ca, cm);
   g_themeActive = themeIdx;
   Theme_RecolourOnce(cc[0], cc[1], cc[5], cc[6]);
   Theme_RefreshButtons();
   ChartRedraw();   // تنها ChartRedraw این کلیک
}

//--- بازرنگ یک‌باره‌ی آبجکت‌های Hub بعد از تغییر تم؛ از همان توابعی که شاخه‌ی CHART_CHANGE و ماژول‌ها دارند. رنگ‌های تازه از
//--- override (g_ov*) گرفته می‌شود چون ChartGetInteger درست بعد از ChartSetInteger ممکن است هنوز مقدار قدیمی بدهد.
//--- v1.16: اعمال تم Custom (سراسری). اگر هنوز ذخیره نشده فقط پیام می‌دهد.
void Theme_ApplyCustom()
{
   color cc[13]; bool cg, cs, ca; int cm;
   if(!Theme_CustomLoad(cc, cg, cs, ca, cm))
   {
      Print("ExecutiveHub: Custom theme is empty - set your chart colours (F8), then press S to save.");
      return;
   }
   if(!Theme_EnsureOriginalStored())
   {
      Print("ExecutiveHub: Theme - could not store the safety copy of the chart colours; Custom was NOT applied.");
      return;
   }
   Theme_WriteChart(cc, cg, cs, ca, cm);
   g_themeActive = THEME_CUSTOM_IDX;
   Theme_RecolourOnce(cc[0], cc[1], cc[5], cc[6]);
   Theme_RefreshButtons();
   ChartRedraw();
}

void Theme_RecolourOnce(color bg, color fg, color bull, color bear)
{
   g_ovBg = bg; g_ovFg = fg; g_ovBull = bull; g_ovBear = bear;
   g_ovOn = true;

   EMA_ApplyGrayscaleColors();                    // رنگ پلات‌های EMA (بافر اندیکاتور)
   if(wmapVisible) WMAP_DrawAll();                // خطوط + تگ‌های Weekly Map
   if(pocLevelsActive) POC_RecolourLevels();      // خطوط/لیبل‌های POC که روی تغییر تایم‌فریم می‌مانند
   if(sobVisible) SOB_Recalculate();              // Session Opening Box
   if(nyeVisible) NYE_Recalculate();              // NY Edge
   if(mtfcpVisible)                               // MTF Candle Preview
   {
      MTFCP_DrawAll();
      if(MTFCP_ShowCountdown) MTFCP_UpdateCountdownLabel();
   }
   gLabelColor = LoadPersistedLabelColor();       // رنگ پیش‌فرض ابزار Label (اگر دستی تعیین نشده باشد خودکار است)

   g_ovOn = false;
}

void POC_RecolourLevels()
{
   if(ObjectFind(0, POC_LINE_POC) >= 0) ObjectSetInteger(0, POC_LINE_POC, OBJPROP_COLOR, Theme_ContrastSafe(POC_LineColor));
   if(ObjectFind(0, POC_LINE_LVN) >= 0) ObjectSetInteger(0, POC_LINE_LVN, OBJPROP_COLOR, Theme_ContrastSafe(POC_LVN_Color));
   if(ObjectFind(0, POC_LINE_EXH) >= 0) ObjectSetInteger(0, POC_LINE_EXH, OBJPROP_COLOR, Theme_ContrastSafe(POC_Exhaustion_Color));
   if(ObjectFind(0, POC_LBL_POC) >= 0)  ObjectSetInteger(0, POC_LBL_POC, OBJPROP_COLOR, Theme_ContrastSafe(POC_LineColor));
   if(ObjectFind(0, POC_LBL_LVN) >= 0)  ObjectSetInteger(0, POC_LBL_LVN, OBJPROP_COLOR, Theme_ContrastSafe(POC_LVN_Color));
   if(ObjectFind(0, POC_LBL_EXH) >= 0)  ObjectSetInteger(0, POC_LBL_EXH, OBJPROP_COLOR, Theme_ContrastSafe(POC_Exhaustion_Color));
}

//+------------------------------------------------------------------+
int OnInit()
{
   ST_ServerOffsetSec();   // v1.09 (P2): GV آفست پایدار را زود لود می‌کند
   EnsureHubLabelsSeed();  // v1.11: قبل از هر چیزی که LabelList را می‌خواند (CreateLabelButtons، ...)
   gColorA = LoadPersistedColor("ColorA", DefaultColorA);
   gColorB = LoadPersistedColor("ColorB", DefaultColorB);
   gColorC = LoadPersistedColor("ColorC", DefaultColorC);
   gColorD = LoadPersistedColor("ColorD", DefaultColorD);
   gWidth  = LoadPersistedInt("Width", DefaultBorderWidth);
   gStyle  = LoadPersistedInt("Style", STYLE_SOLID);
   gPathColor = LoadPersistedColor("PathColor", DefaultPathColor);
   gPathWidth = LoadPersistedInt("PathWidth", DefaultPathWidth);
   gPathStyle = LoadPersistedInt("PathStyle", STYLE_SOLID);
   gLineColor = LoadPersistedColor("LineColor", DefaultLineColor);
   gLineWidth = LoadPersistedInt("LineWidth", DefaultLineWidth);
   gLineStyle = LoadPersistedInt("LineStyle", STYLE_SOLID);
   gHRayColor = LoadPersistedColor("HRayColor", gLineColor);   // v1.10 (MT4 v1.15)
   gHRayWidth = LoadPersistedInt("HRayWidth", gLineWidth);
   gHRayStyle = LoadPersistedInt("HRayStyle", STYLE_SOLID);
   gPath2Color = LoadPersistedColor("Path2Color", DefaultPath2Color);   // v1.14
   gPath2Width = LoadPersistedInt("Path2Width", DefaultPath2Width);
   gPath2Style = LoadPersistedInt("Path2Style", STYLE_SOLID);
   gLine2Color = LoadPersistedColor("Line2Color", DefaultLine2Color);
   gLine2Width = LoadPersistedInt("Line2Width", DefaultLine2Width);
   gLine2Style = LoadPersistedInt("Line2Style", STYLE_SOLID);
   gDashColor = LoadPersistedColor("DashColor", gLineColor);
   gDashWidth = LoadPersistedInt("DashWidth", 1);
   gDashStyle = LoadPersistedInt("DashStyle", STYLE_DASH);
   gDrawMinimized = LoadPersistedBool("DrawMinimized");

   gLabelColor      = LoadPersistedLabelColor();
   gLabelFontSize   = LoadPersistedInt("LabelFontSize", LabelDefaultFontSize);
   gLabelsMinimized = LoadPersistedBool("LabelsMinimized");

   gIndicatorsMinimized = LoadPersistedBool("IndicatorsMinimized");
   gThemeMinimized      = LoadPersistedBool("ThemeMinimized");   // v1.12 (FEAT-052)

   // اولین‌بار (بدون هیچ کلید ذخیره‌شده‌ای)، هر سه کشو جمع‌شده باشن - چون
   // حالا هم‌محلن (mutual exclusion)، بازبودن هرسه‌تاشون هم‌زمان روی هم
   // می‌افتاد و شلوغ می‌شد
   if(!GlobalVariableCheck(PFX + "DrawMinimized_" + Symbol()))       gDrawMinimized = true;
   if(!GlobalVariableCheck(PFX + "LabelsMinimized_" + Symbol()))     gLabelsMinimized = true;
   if(!GlobalVariableCheck(PFX + "IndicatorsMinimized_" + Symbol())) gIndicatorsMinimized = true;
   if(!GlobalVariableCheck(PFX + "ThemeMinimized_" + Symbol()))      gThemeMinimized = true;   // v1.12
   g_themeActive = Theme_DetectActive();   // v1.12: فقط خواندن؛ رنگی عوض نمی‌شود

   //--- FEATURE (v1.08, Item 2): must run before CreateButtons()/
   //--- CreateLabelButtons() so their very first ObjectCreate() calls
   //--- already size buttons with the right (possibly shrunk) width - see
   //--- RecomputeEffectiveSizes(). PositionButtons() below recomputes again
   //--- (cheap - pure arithmetic, no object churn) so it stays correct on
   //--- every later call path too, not just this first one.
   RecomputeEffectiveSizes();

   CreateButtons();
   CreateLabelButtons();
   PositionButtons();
   ApplyDrawMinimizedState();
   ApplyLabelsMinimizedState();
   ApplyIndicatorsMinimizedState();
   ApplyThemeMinimizedState();   // v1.12
   PathSnap_Rebuild();           // v1.14: اسنپ‌شات سراسری قطعه‌های Path برای جابه‌جایی گروهی
   ChartRedraw();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   //--- BUG-FIX (v1.02): needed so OnChartEvent actually receives
   //--- CHARTEVENT_OBJECT_CREATE - see RaiseHubPanelToFront(). [Note: real
   //--- OnChartEvent isn't ported until 5e-v, so this event is enabled but
   //--- has nowhere to go yet - harmless, matches every prior sub-stage's
   //--- "clicking does nothing yet" state.]
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);

   //--- FEATURE (v1.01, Feature 4): start the idle clock at EA load, not at
   //--- zero - avoids an immediate false "already idle" auto-collapse before
   //--- the trader has interacted with the Hub at all this session.
   gHubLastInteraction = TimeCurrent();

   //--- ماژول ۱: POC (رفتار عیناً از POC.mq4 مستقل، فقط دکمه‌اش حالا
   //--- زیرمجموعه‌ی ردیف Indicator هاب می‌شینه، نه یه دکمه‌ی مجزا)
   pocActive = LoadPOCActive();
   SetPOCButtonActive(pocActive);
   POC_CleanupLegacyObjects();
   if(ObjectFind(0, POC_LINE_POC) >= 0 && ObjectFind(0, POC_LINE_LVN) >= 0 && ObjectFind(0, POC_LINE_EXH) >= 0)
   {
      // [MT5 translation - carried forward from the OBJPROP_TIME/PRICE sweep flagged in 5e-i/5e-ii]
      // these are the exact 3 legacy ObjectGet(name, prop) call sites 5e-ii's report identified as
      // living in OnInit() rather than any POC_* function - fixed here, now that OnInit is in scope.
      gPocPrice = ObjectGetDouble(0, POC_LINE_POC, OBJPROP_PRICE, 0);
      gLvnPrice = ObjectGetDouble(0, POC_LINE_LVN, OBJPROP_PRICE, 0);
      gExhPrice = ObjectGetDouble(0, POC_LINE_EXH, OBJPROP_PRICE, 0);
      pocLevelsActive = true;
      POC_CreateOrUpdateLabel(POC_LBL_POC, "POC",             gPocPrice, POC_LineColor);
      POC_CreateOrUpdateLabel(POC_LBL_LVN, "LVN",              gLvnPrice, POC_LVN_Color);
      POC_CreateOrUpdateLabel(POC_LBL_EXH, "Exhaustion Point", gExhPrice, POC_Exhaustion_Color);
   }

   //--- ماژول ۱: Weekly Map (رفتار عیناً از WEEKLY_MAP.mq4 مستقل)
   wmapVisible = LoadWMAPVisible();
   SetWMAPButtonColor();
   EventSetTimer(1);
   if(wmapVisible)
   {
      g_lastWeekTime = 0; // force a full recompute right away
      WMAP_DrawAll();
   }
   else
   {
      ObjectsDeleteAll(0, WMAP_PFX);
   }

   //--- ماژول ۲: Session Opening Box
   sobVisible = LoadSOBVisible();
   SetSOBButtonColor();
   if(sobVisible) sobLastBarTime = 0;

   //--- ماژول ۲: NY Edge
   nyeVisible = LoadNYEVisible();
   SetNYEButtonColor();
   if(nyeVisible) nyeLastBarTime = 0;

   //--- ماژول ۳: MTF Candle Preview
   mtfcpVisible = LoadMTFCPVisible();
   SetMTFCPButtonColor();
   if(MTFCP_CandleCount < 2 || MTFCP_CandleCount > 12)
      Alert("MTF Candle Preview: MTFCP_CandleCount should be between 2 and 12.");
   if(MTFCP_SlotWidthPx < 4)
      Alert("MTF Candle Preview: MTFCP_SlotWidthPx is very small, candles may not render clearly.");
   ObjectsDeleteAll(0, MTFCP_PFX);
   mtfcpLastSourceBarTime = 0;
   if(mtfcpVisible && MTFCP_AutoEnableChartShift)
      MTFCP_EnsureChartShift();
   if(mtfcpVisible)
      MTFCP_DrawAll();

   //--- ماژول ۳: EMA Overlay - دیگه دکمه‌ی master نداره، فقط ۴ تفکیک‌شده
   //--- (طبق تصمیم Mahmoud: داشتن هر دو گیج‌کننده بود و باگ‌دار)
   gShowEMA10  = LoadPersistedBool("ShowEMA10_v3");
   gShowEMA20  = LoadPersistedBool("ShowEMA20_v3");
   gShowEMA60  = LoadPersistedBool("ShowEMA60_v3");
   gShowEMA240 = LoadPersistedBool("ShowEMA240_v3");
   // اولین‌بار (بدون هیچ کلید ذخیره‌شده‌ای)، پیش‌فرض true بمونه، نه false
   // (چون LoadPersistedBool وقتی چیزی ذخیره نشده false برمی‌گردونه - اینجا
   // چک می‌کنیم آیا واقعاً کلیدها وجود دارن یا نه)
   if(!GlobalVariableCheck(PFX + "ShowEMA10_v3_" + Symbol()))  gShowEMA10  = true;
   if(!GlobalVariableCheck(PFX + "ShowEMA20_v3_" + Symbol()))  gShowEMA20  = true;
   if(!GlobalVariableCheck(PFX + "ShowEMA60_v3_" + Symbol()))  gShowEMA60  = true;
   if(!GlobalVariableCheck(PFX + "ShowEMA240_v3_" + Symbol())) gShowEMA240 = true;

   // [Stage 5e-iii deliverable] replaces the MT4 source's inline SetIndexBuffer/SetIndexEmptyValue/
   // SetIndexLabel block (lines 566-604 of the original) - EMA_RegisterBuffers() does all of that,
   // PLUS creates the iMA/iATR handles EMA_Recalculate() needs, PLUS applies the critical
   // ArraySetAsSeries() fix found live during 5e-iii testing (without it, every EMA buffer silently
   // wrote to the wrong chronological position - see the 5e-iii report for the full story).
   EMA_RegisterBuffers();

   // [TEST diagnostic, additive only - no logic changed above] confirms persisted state actually
   // loaded on this attach, for Mahmoud's test item 1 (re-attach after a first run should show
   // non-default values here if anything was toggled/saved in a previous session).
   Print("[TEST] OnInit complete. gDrawMinimized=", gDrawMinimized, " gLabelsMinimized=", gLabelsMinimized,
         " gIndicatorsMinimized=", gIndicatorsMinimized, " pocActive=", pocActive, " wmapVisible=", wmapVisible,
         " sobVisible=", sobVisible, " nyeVisible=", nyeVisible, " mtfcpVisible=", mtfcpVisible,
         " gShowEMA10/20/60/240=", gShowEMA10, "/", gShowEMA20, "/", gShowEMA60, "/", gShowEMA240);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // [TEST diagnostic, additive only] confirms OnDeinit ran, for Mahmoud's test item 2.
   Print("[TEST] OnDeinit running, reason=", reason, " - removing panel-owned objects, leaving user drawings untouched.");
   ObjectDelete(0, BTN_FA);
   ObjectDelete(0, BTN_FB);
   ObjectDelete(0, BTN_FC);
   ObjectDelete(0, BTN_FD);
   ObjectDelete(0, BTN_HA);
   ObjectDelete(0, BTN_HB);
   ObjectDelete(0, BTN_PATH);
   ObjectDelete(0, BTN_LINE);
   ObjectDelete(0, BTN_HLINE);   // v1.10
   ObjectDelete(0, BTN_DASH);    // v1.10
   ObjectDelete(0, BTN_PATH2);   // v1.14
   ObjectDelete(0, BTN_LINE2);   // v1.14
   ObjectDelete(0, BTN_MEASURE); // v1.11
   RemoveMeasureTool(MEASURE_PREVIEW_NAME);   // v1.11: پیش‌نمایش شاید نیمه‌کاره باز مانده باشد
   ObjectDelete(0, BTN_MASTER_DRAW);
   ObjectDelete(0, PREVIEW_NAME);
   ObjectDelete(0, PATH_PREVIEW_NAME);
   ObjectDelete(0, LINE_PREVIEW_NAME);
   ObjectDelete(0, BTN_MASTER_LABELS);
   ObjectDelete(0, LABEL_PREVIEW_NAME);
   for(int i = 0; i < LABEL_COUNT; i++)
      ObjectDelete(0, LabelButtonName(i));
   ObjectDelete(0, BTN_MASTER_INDICATOR);
   ObjectDelete(0, BTN_MASTER_THEME);   // v1.12: فقط دکمه‌ها؛ آبجکت مخفیِ THEME_ORIG_NAME عمداً دست‌نخورده
   for(int ti = 0; ti < THEME_COUNT; ti++)
      ObjectDelete(0, Theme_BtnName(ti));
   ObjectDelete(0, BTN_THEME_ORIG);
   ObjectDelete(0, BTN_THEME_CUSTOM); ObjectDelete(0, BTN_THEME_CSAVE); ObjectDelete(0, BTN_THEME_CRESET);   // v1.16
   ObjectDelete(0, HUB_BG_NAME);
   HubDeleteShadows();   // v1.17

   //--- ماژول ۱ - POC: فقط دکمه و کرسور تشخیصی پاک می‌شن؛ خطوط POC/LVN/Exhaustion
   //--- عمداً دست‌نخورده می‌مونن (مثل قبل، برای بقا روی تغییر تایم‌فریم)
   ObjectDelete(0, BTN_POC);
   POC_DeleteTrackObjects();

   //--- ماژول ۱ - Weekly Map
   EventKillTimer();
   ObjectsDeleteAll(0, WMAP_PFX);
   ObjectDelete(0, BTN_WMAP);

   //--- ماژول ۲ - Session Opening Box: باکس/پروجکشن‌ها هر تیک بازسازی می‌شن،
   //--- پس پاک‌کردنشون توی Deinit مشکلی نداره (بلافاصله بعد از TF-change دوباره کشیده می‌شن)
   ObjectsDeleteAll(0, SOB_PFX);
   ObjectDelete(0, BTN_SOB);

   //--- ماژول ۲ - NY Edge
   ObjectsDeleteAll(0, NYE_PFX);
   ObjectDelete(0, BTN_NYE);

   //--- ماژول ۳ - MTF Candle Preview
   ObjectsDeleteAll(0, MTFCP_PFX);
   ObjectDelete(0, BTN_MTFCP);
   Comment("");

   //--- ماژول ۳ - EMA Overlay (فقط دکمه‌ها؛ بافرها با تغییر تایم‌فریم خودکار
   //--- دوباره محاسبه می‌شن، نیازی به پاک‌سازی خاصی ندارن)
   ObjectDelete(0, BTN_EMA10);
   ObjectDelete(0, BTN_EMA20);
   ObjectDelete(0, BTN_EMA60);
   ObjectDelete(0, BTN_EMA240);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
   //--- ماژول ۱ - POC: برچسب‌های کنار نوار قیمت رو با هر تیک به‌روز نگه می‌داره
   if(pocLevelsActive) POC_RepositionLabels();

   //--- ماژول ۱ - Weekly Map: فقط وقتی هفته‌ی جدید بسته شد بازمحاسبه می‌کنه
   datetime lastClosedWeek = iTime(Symbol(), PERIOD_W1, WMAP_LastClosedWeekShift());
   bool weekChanged = (lastClosedWeek != g_lastWeekTime);
   if(weekChanged)
      g_lastWeekTime = lastClosedWeek;
   if(wmapVisible)
   {
      // v1.10: redraw also when price ran past the last drawn level (WMAP_RefreshExtras detects new steps)
      if(weekChanged || WMAP_RefreshExtras())
         WMAP_DrawAll();
      else
         WMAP_UpdateLabelPositions();
   }

   //--- ماژول ۲ - Session Opening Box: فقط با کندل جدید (تایم‌فریم پایه‌ی
   //--- خودش) بازمحاسبه می‌کنه، مستقل از NY Edge یا تایم‌فریم چارت فعلی
   if(sobVisible)
   {
      datetime sobBarTime = iTime(Symbol(), SOB_BaseTimeframe, 0);
      if(sobBarTime != sobLastBarTime)
      {
         sobLastBarTime = sobBarTime;
         SOB_Recalculate();
      }
   }

   //--- ماژول ۲ - NY Edge: مشابه، مستقل با تایم‌فریم پایه‌ی خودش
   if(nyeVisible)
   {
      datetime nyeBarTime = iTime(Symbol(), NYE_BaseTimeframe, 0);
      if(nyeBarTime != nyeLastBarTime)
      {
         nyeLastBarTime = nyeBarTime;
         NYE_Recalculate();
      }
   }

   //--- ماژول ۳ - MTF Candle Preview
   if(mtfcpVisible)
   {
      datetime mtfcpLiveBarTime = iTime(Symbol(), MTFCP_PreviewTF, 0);
      if(mtfcpLiveBarTime != mtfcpLastSourceBarTime)
      {
         mtfcpLastSourceBarTime = mtfcpLiveBarTime;
         MTFCP_DrawAll();
      }
      else
      {
         MTFCP_UpdateLiveCandle();
      }
      if(MTFCP_ShowCountdown) MTFCP_UpdateCountdownLabel();
      if(MTFCP_Debug) MTFCP_PrintDebugInfo();
   }

   //--- ماژول ۳ - EMA Overlay: همیشه محاسبه می‌شه (بافرمحوره)، فقط استایل
   //--- نمایش هر خط بر اساس gShowEMA10/20/60/240 عوض می‌شه (دیگه دکمه‌ی
   //--- master نداره - طبق تصمیم Mahmoud)
   EMA_Recalculate(rates_total, prev_calculated);

   return(rates_total);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   ST_ServerOffsetSec();   // v1.09 (P2): کالیبراسیون سه‌تیکی آفست (MT5 مصرف‌کننده‌ی دوره‌ای ندارد)
   //--- ترسیم خودکار (self-healing) - دقیقاً همون الگوی BUG-033 که توی
   //--- Risk Manager EA حل شده بود: "Delete All Objects" دستی از متاتریدر
   //--- همه‌ی ابجکت‌ها رو پاک می‌کنه، از جمله پنل ما - هیچ قفلی هم نیست که
   //--- جلوش رو بگیره. هر ثانیه (توی همین تایمر ۱هرتزی موجود، بدون تایمر
   //--- جدید) چک می‌کنیم اولین ابجکتی که می‌سازیم (پس‌زمینه‌ی داشبورد) هنوز
   //--- هست یا نه - اگه نبود، یعنی پاک شده، پس کل پنل رو از نو می‌سازیم.
   CheckHubIntegrity();

   //--- ماژول ۱ - Weekly Map: تگ‌های کنار محور قیمت رو با تایمر هم به‌روز نگه می‌داره
   //--- (علاوه بر OnCalculate)، دقیقاً مثل نسخه‌ی مستقل قبلی
   if(wmapVisible)
      WMAP_UpdateLabelPositions();

   //--- ماژول ۳ - MTF Candle Preview: safety net برای Chart Shift + شمارش معکوس
   if(mtfcpVisible)
   {
      if(MTFCP_AutoEnableChartShift)
         MTFCP_EnsureChartShift();
      if(MTFCP_ShowCountdown)
         MTFCP_UpdateCountdownLabel();
   }

   //--- FEATURE (v1.01, Feature 4): auto-minimize whichever category is
   //--- currently expanded after HUB_AUTO_MINIMIZE_IDLE_SECONDS of no click
   //--- on any Hub object. Reuses the exact same collapse code path
   //--- (SavePersistedBool + Apply*MinimizedState) the master button's own
   //--- click handler already uses, so persistence/visual update stays
   //--- consistent. Only one category can ever be expanded at a time, so at
   //--- most one of these three fires.
   if(TimeCurrent() - gHubLastInteraction >= HUB_AUTO_MINIMIZE_IDLE_SECONDS)
   {
      bool collapsed = false;
      if(!gDrawMinimized)
      {
         gDrawMinimized = true;
         SavePersistedBool("DrawMinimized", true);
         ApplyDrawMinimizedState();
         collapsed = true;
      }
      else if(!gLabelsMinimized)
      {
         gLabelsMinimized = true;
         SavePersistedBool("LabelsMinimized", true);
         ApplyLabelsMinimizedState();
         collapsed = true;
      }
      else if(!gIndicatorsMinimized)
      {
         gIndicatorsMinimized = true;
         SavePersistedBool("IndicatorsMinimized", true);
         ApplyIndicatorsMinimizedState();
         collapsed = true;
      }
      else if(!gThemeMinimized)   // v1.12 (FEAT-052)
      {
         gThemeMinimized = true;
         SavePersistedBool("ThemeMinimized", true);
         ApplyThemeMinimizedState();
         collapsed = true;
      }
      //--- BUG-FIX (v1.07, lag): Apply*MinimizedState() no longer calls
      //--- UpdateHubBackground()/ChartRedraw() itself (see those
      //--- functions) - PositionButtons() (which shrinks the panel back
      //--- down now that a category closed) + one ChartRedraw() belong here
      //--- instead, same as the master-button click handlers.
      if(collapsed)
      {
         PositionButtons();
         ChartRedraw();
         // [TEST diagnostic, additive only] confirms auto-minimize fired, for Mahmoud's test item 4.
         Print("[TEST] Auto-minimize fired after ", HUB_AUTO_MINIMIZE_IDLE_SECONDS, "s idle - collapsed a category.");
      }
   }

   //--- BUG-FIX (v1.03): debounced raise - see g_hubNeedsRaise. At most one
   //--- RaiseHubPanelToFront() per second, regardless of how many objects
   //--- were created since the last tick.
   if(g_hubNeedsRaise)
   {
      g_hubNeedsRaise = false;
      RaiseHubPanelToFront();
   }
}

//+------------------------------------------------------------------+
//| [Gap found while porting 5e-v] POC's two-click point-selection      |
//| state - lives entirely inside OnChartEvent()'s guards, so none of   |
//| 5e-ii's 13 POC_* functions ever needed it, and it was correctly      |
//| left undeclared until now, its only real consumer.                  |
//+------------------------------------------------------------------+
enum POC_STATE_ENUM { POC_IDLE, POC_WAIT_FIRST_CLICK, POC_WAIT_SECOND_CLICK };
POC_STATE_ENUM pocState          = POC_IDLE;
bool            pocSkipNextClick = false;
datetime        pocFirstClickTime = 0;

//+------------------------------------------------------------------+
//| OnChartEvent() - Stage 5e-v, the final function of the whole Hub.  |
//| Ported as the same sequence of independent, sequential `if` guards |
//| it already is in the MT4 source - not restructured into a switch,  |
//| per the task's explicit instruction (same rule as the EA port's    |
//| own OnChartEvent in Stage 5c-ii).                                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   //--- FEATURE (v1.01, Feature 4): any click on any Hub-owned object (all
   //--- share the PFX prefix - master buttons, all Draw/Label/Indicator
   //--- sub-buttons) resets the idle clock. Deliberately NOT scoped to a
   //--- single button list, so it stays correct if more Hub buttons are
   //--- added later without needing to touch this spot again.
   if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, PFX) == 0)
      gHubLastInteraction = TimeCurrent();

   //--- BUG-FIX (v1.02, Bug 3 follow-up; debounced in v1.03 - see
   //--- g_hubNeedsRaise): don't raise the panel synchronously here - just
   //--- mark it dirty. IsHubPanelOwnedObject() filters out the panel's own
   //--- objects so their own recreation (in OnTimer) doesn't re-mark dirty.
   //--- [5e-v empirical question] whether MT5 even needs this mechanism is
   //--- exactly what this stage's live testing answers - see the report.
   if(id == CHARTEVENT_OBJECT_CREATE && !IsHubPanelOwnedObject(sparam))
      g_hubNeedsRaise = true;

   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int keyFlags = (int)StringToInteger(sparam);
      gShiftHeld = (keyFlags & 4) != 0;
   }

   //--- ماژول ۱ - POC: کرسور دنبال‌کننده‌ی موس حین انتخاب نقطه‌ی ۱/۲
   //--- (بدون ChartRedraw صریح - درسِ لگ که قبلاً از این دقیقاً همین بخش
   //--- در نسخه‌ی مستقل POC گرفتیم؛ MT4 خودش با چرخه‌ی طبیعی رفرش می‌کنه)
   if(id == CHARTEVENT_MOUSE_MOVE && (pocState == POC_WAIT_FIRST_CLICK || pocState == POC_WAIT_SECOND_CLICK))
   {
      static uint pocLastMoveMs = 0;
      uint pocNowMs = GetTickCount();
      if(pocNowMs - pocLastMoveMs < 60) return;
      pocLastMoveMs = pocNowMs;

      int pmx = (int)lparam, pmy = (int)dparam;
      datetime pocMTime; double pocMPrice; int pocSubWindow;
      if(ChartXYToTimePrice(0, pmx, pmy, pocSubWindow, pocMTime, pocMPrice))
      {
         int pocShift = iBarShift(Symbol(), Period(), pocMTime, false);
         datetime pocSnapped = iTime(Symbol(), Period(), pocShift);
         POC_UpdateTrackLine(pocSnapped);
      }
      string pocHint = (pocState == POC_WAIT_FIRST_CLICK) ? "Select point 1" : "Select point 2";
      POC_UpdateTrackLabel(pmx, pmy, pocHint);
      ChartRedraw(); // [MT5 behavioral fix] same reasoning as the drawing previews below.
      return;
   }

   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      HandleGroupDrag(sparam);
      return;
   }

   if(id == CHARTEVENT_CLICK)
   {
      if(skipDeselectOnce)
         skipDeselectOnce = false;
      else if(g_selectedPathPrefix != "")
      {
         DeselectPathGroup(g_selectedPathPrefix);
         g_selectedPathPrefix = "";
      }
   }

   //--- ماژول ۱ - POC: ثبت نقطه‌ی اول/دوم روی چارت
   if(id == CHARTEVENT_CLICK && (pocState == POC_WAIT_FIRST_CLICK || pocState == POC_WAIT_SECOND_CLICK))
   {
      if(pocSkipNextClick)
      {
         pocSkipNextClick = false;
         return;
      }

      datetime pocClickTime; double pocClickPrice; int pocSubWindow2;
      if(!ChartXYToTimePrice(0, (int)lparam, (int)dparam, pocSubWindow2, pocClickTime, pocClickPrice))
         return;

      int      pocBarShift    = iBarShift(Symbol(), Period(), pocClickTime, false);
      datetime pocSnappedTime = iTime(Symbol(), Period(), pocBarShift);

      if(pocState == POC_WAIT_FIRST_CLICK)
      {
         pocFirstClickTime = pocSnappedTime;
         pocState = POC_WAIT_SECOND_CLICK;
      }
      else if(pocState == POC_WAIT_SECOND_CLICK)
      {
         if(pocSnappedTime == pocFirstClickTime) return; // کلیک تکراری روی همون کندل؛ نادیده گرفته می‌شود
         pocState = POC_IDLE;
         POC_DeleteTrackObjects();
         POC_CalculateAndDraw(pocFirstClickTime, pocSnappedTime);
      }
      return;
   }

   if(id == CHARTEVENT_CHART_CHANGE)
   {
      PositionButtons();
      if(pocLevelsActive) POC_RepositionLabels();
      if(wmapVisible) WMAP_UpdateLabelPositions();
      if(mtfcpVisible)
      {
         if(MTFCP_AutoEnableChartShift) MTFCP_EnsureChartShift();
         MTFCP_DrawAll(); // همه‌چیز پیکسل‌محوره، پس با زوم/اسکرول باید دوباره کشیده بشه
      }
      EMA_ApplyGrayscaleColors(); // اگه بک‌گراند/تم چارت عوض شده باشه
   }

   if(id == CHARTEVENT_OBJECT_CLICK && (StringFind(sparam, PFX + "Path_") == 0 || StringFind(sparam, PFX + "Path2_") == 0))
   {
      SelectWholeGroup(sparam);
      return;
   }

   // v1.11 (MT4 v1.14): کلیک روی هر زیرآبجکتی از یک نمونه‌ی Range، کل همان نمونه (۷خط+۷لیبل+۲مستطیل) را با هم سلکت می‌کند
   if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, PFX + "Range_") == 0)
   {
      SelectWholeGroup(sparam);
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_MASTER_DRAW)
   {
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_STATE, false);
      skipNextClick = true;
      gDrawMinimized = !gDrawMinimized;
      SavePersistedBool("DrawMinimized", gDrawMinimized);
      // mutual exclusion: فقط یکی از سه کشو هم‌زمان باز می‌مونه - اگه این
      // یکی رو باز کردیم، اون دوتای دیگه رو ببند (اگه باز بودن)
      if(!gDrawMinimized)
      {
         if(!gLabelsMinimized) { gLabelsMinimized = true; SavePersistedBool("LabelsMinimized", true); ApplyLabelsMinimizedState(); }
         if(!gIndicatorsMinimized) { gIndicatorsMinimized = true; SavePersistedBool("IndicatorsMinimized", true); ApplyIndicatorsMinimizedState(); }
         if(!gThemeMinimized) { gThemeMinimized = true; SavePersistedBool("ThemeMinimized", true); ApplyThemeMinimizedState(); }   // v1.12
      }
      //--- BUG-FIX (v1.05): width (and thus xStart/background) now depends
      //--- on which category is open (see PanelContentWidth()) - so
      //--- switching categories must reposition everything, not just
      //--- toggle visibility.
      PositionButtons();
      ApplyDrawMinimizedState();
      //--- BUG-FIX (v1.07, lag): single redraw for the whole click, instead
      //--- of up to 3 (one per Apply*MinimizedState() call) - see those
      //--- functions' comments.
      ChartRedraw();
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_MASTER_LABELS)
   {
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_STATE, false);
      skipNextClick = true;
      gLabelsMinimized = !gLabelsMinimized;
      SavePersistedBool("LabelsMinimized", gLabelsMinimized);
      if(!gLabelsMinimized)
      {
         if(!gDrawMinimized) { gDrawMinimized = true; SavePersistedBool("DrawMinimized", true); ApplyDrawMinimizedState(); }
         if(!gIndicatorsMinimized) { gIndicatorsMinimized = true; SavePersistedBool("IndicatorsMinimized", true); ApplyIndicatorsMinimizedState(); }
         if(!gThemeMinimized) { gThemeMinimized = true; SavePersistedBool("ThemeMinimized", true); ApplyThemeMinimizedState(); }   // v1.12
      }
      PositionButtons();
      ApplyLabelsMinimizedState();
      ChartRedraw();
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_MASTER_INDICATOR)
   {
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_STATE, false);
      skipNextClick = true;
      gIndicatorsMinimized = !gIndicatorsMinimized;
      SavePersistedBool("IndicatorsMinimized", gIndicatorsMinimized);
      if(!gIndicatorsMinimized)
      {
         if(!gDrawMinimized) { gDrawMinimized = true; SavePersistedBool("DrawMinimized", true); ApplyDrawMinimizedState(); }
         if(!gLabelsMinimized) { gLabelsMinimized = true; SavePersistedBool("LabelsMinimized", true); ApplyLabelsMinimizedState(); }
         if(!gThemeMinimized) { gThemeMinimized = true; SavePersistedBool("ThemeMinimized", true); ApplyThemeMinimizedState(); }   // v1.12
      }
      PositionButtons();
      ApplyIndicatorsMinimizedState();
      ChartRedraw();
      return;
   }

   //--- v1.12 (FEAT-052): دکمه‌ی مادر Theme - چهارمین کشوی هم‌محل (باز شدنش بقیه را می‌بندد و برعکس)
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_MASTER_THEME)
   {
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_STATE, false);
      skipNextClick = true;
      gThemeMinimized = !gThemeMinimized;
      SavePersistedBool("ThemeMinimized", gThemeMinimized);
      if(!gThemeMinimized)
      {
         if(!gDrawMinimized) { gDrawMinimized = true; SavePersistedBool("DrawMinimized", true); ApplyDrawMinimizedState(); }
         if(!gLabelsMinimized) { gLabelsMinimized = true; SavePersistedBool("LabelsMinimized", true); ApplyLabelsMinimizedState(); }
         if(!gIndicatorsMinimized) { gIndicatorsMinimized = true; SavePersistedBool("IndicatorsMinimized", true); ApplyIndicatorsMinimizedState(); }
      }
      PositionButtons();
      ApplyThemeMinimizedState();
      ChartRedraw();
      return;
   }

   //--- v1.12 (FEAT-052): کلیک روی یکی از ۷ دکمه‌ی تم یا Original. فقط روی همین کلیک اجرا می‌شود؛ هیچ تایمر/polling ندارد.
   if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, PFX + "Btn_Theme_") == 0)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      skipNextClick = true;
      int themeIdx = -2;
      if(sparam == BTN_THEME_CUSTOM)        { Theme_ApplyCustom();      return; }   // v1.16
      else if(sparam == BTN_THEME_CSAVE)    { Theme_CustomSaveCurrent(); return; }
      else if(sparam == BTN_THEME_CRESET)   { Theme_CustomReset();       return; }
      else
      {
         int themeNum = (int)StringToInteger(StringSubstr(sparam, StringLen(PFX + "Btn_Theme_")));
         if(themeNum >= 1 && themeNum <= THEME_COUNT) themeIdx = themeNum - 1;
      }
      if(themeIdx >= -1)
         Theme_Apply(themeIdx);
      return;
   }

   //--- ماژول ۱ - کلیک دکمه‌ی POC
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_POC)
   {
      ObjectSetInteger(0, BTN_POC, OBJPROP_STATE, false);
      pocSkipNextClick = true;
      CancelDrawing();
      DisarmLabel();

      if(!pocActive)
      {
         pocActive = true;
         SetPOCButtonActive(true);
         pocState = POC_WAIT_FIRST_CLICK;
      }
      else
      {
         pocActive = false;
         SetPOCButtonActive(false);
         pocState = POC_IDLE;
         pocLevelsActive = false;
         POC_DeleteTrackObjects();
         POC_DeleteLevels();
      }
      SavePOCActive(pocActive);
      ChartRedraw();
      return;
   }

   //--- ماژول ۱ - کلیک دکمه‌ی Weekly Map
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_WMAP)
   {
      ObjectSetInteger(0, BTN_WMAP, OBJPROP_STATE, false);
      skipNextClick = true;
      wmapVisible = !wmapVisible;
      SetWMAPButtonColor();
      if(wmapVisible)
         WMAP_DrawAll();
      else
         ObjectsDeleteAll(0, WMAP_PFX);
      SaveWMAPVisible(wmapVisible);
      ChartRedraw();
      return;
   }

   //--- ماژول ۲ - کلیک دکمه‌ی Session Opening Box
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_SOB)
   {
      ObjectSetInteger(0, BTN_SOB, OBJPROP_STATE, false);
      skipNextClick = true;
      sobVisible = !sobVisible;
      SetSOBButtonColor();
      if(sobVisible)
      {
         sobLastBarTime = 0; // force a fresh full recompute right away
         SOB_Recalculate();
      }
      else
         ObjectsDeleteAll(0, SOB_PFX);
      SaveSOBVisible(sobVisible);
      ChartRedraw();
      return;
   }

   //--- ماژول ۲ - کلیک دکمه‌ی NY Edge
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_NYE)
   {
      ObjectSetInteger(0, BTN_NYE, OBJPROP_STATE, false);
      skipNextClick = true;
      nyeVisible = !nyeVisible;
      SetNYEButtonColor();
      if(nyeVisible)
      {
         nyeLastBarTime = iTime(Symbol(), NYE_BaseTimeframe, 0);
         NYE_Recalculate();
      }
      else
         ObjectsDeleteAll(0, NYE_PFX);
      SaveNYEVisible(nyeVisible);
      ChartRedraw();
      return;
   }

   //--- ماژول ۳ - کلیک دکمه‌ی MTF Candle Preview
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_MTFCP)
   {
      ObjectSetInteger(0, BTN_MTFCP, OBJPROP_STATE, false);
      skipNextClick = true;
      mtfcpVisible = !mtfcpVisible;
      SetMTFCPButtonColor();
      if(mtfcpVisible)
      {
         if(MTFCP_AutoEnableChartShift) MTFCP_EnsureChartShift();
         mtfcpLastSourceBarTime = 0; // force a fresh full redraw, not stale pre-hide state
         MTFCP_DrawAll();
         if(MTFCP_ShowCountdown) MTFCP_UpdateCountdownLabel();
      }
      else
      {
         ObjectsDeleteAll(0, MTFCP_PFX);
         Comment("");
      }
      SaveMTFCPVisible(mtfcpVisible);
      ChartRedraw();
      return;
   }

   //--- ماژول ۳ - کلیک هرکدوم از ۴ دکمه‌ی جدای خطوط EMA (طبق خواسته‌ی
   //--- Mahmoud - روشن/خاموش لحظه‌ای هر خط، بدون نیاز به باز کردن Properties.
   //--- دکمه‌ی master حذف شد چون داشتن هر دو با هم گیج‌کننده و باگ‌دار بود -
   //--- فقط این ۴ تای تفکیک‌شده مونده)
   if(id == CHARTEVENT_OBJECT_CLICK && (sparam == BTN_EMA10 || sparam == BTN_EMA20 || sparam == BTN_EMA60 || sparam == BTN_EMA240))
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      skipNextClick = true;

      if(sparam == BTN_EMA10)  { gShowEMA10  = !gShowEMA10;  SavePersistedBool("ShowEMA10_v3",  gShowEMA10); }
      if(sparam == BTN_EMA20)  { gShowEMA20  = !gShowEMA20;  SavePersistedBool("ShowEMA20_v3",  gShowEMA20); }
      if(sparam == BTN_EMA60)  { gShowEMA60  = !gShowEMA60;  SavePersistedBool("ShowEMA60_v3",  gShowEMA60); }
      if(sparam == BTN_EMA240) { gShowEMA240 = !gShowEMA240; SavePersistedBool("ShowEMA240_v3", gShowEMA240); }

      SetEMAButtonColors();
      EMA_ApplyIndexStyles();
      ChartRedraw();
      return;
   }

   for(int i = 0; i < LABEL_COUNT; i++)
   {
      if(id == CHARTEVENT_OBJECT_CLICK && sparam == LabelButtonName(i))
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         skipNextClick = true;
         CancelDrawing();

         if(armedLabel == LabelList[i])
         {
            DisarmLabel();
         }
         else
         {
            DisarmLabel();
            armedLabel = LabelList[i];
            HubSetBg(sparam, CLR_SUBTOGGLE_ACTIVE);
         }
         ChartRedraw();
         return;
      }
   }

   if(id == CHARTEVENT_OBJECT_CLICK && (sparam == BTN_FA || sparam == BTN_FB || sparam == BTN_FC || sparam == BTN_FD || sparam == BTN_HA || sparam == BTN_HB || sparam == BTN_PATH || sparam == BTN_LINE || sparam == BTN_PATH2 || sparam == BTN_LINE2 || sparam == BTN_HLINE || sparam == BTN_DASH || sparam == BTN_MEASURE))
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      skipNextClick = true;
      DisarmLabel();

      DRAW_MODE clicked = MODE_NONE;
      if(sparam == BTN_FA)   clicked = MODE_FILL_A;
      if(sparam == BTN_FB)   clicked = MODE_FILL_B;
      if(sparam == BTN_FC)   clicked = MODE_FILL_C;
      if(sparam == BTN_FD)   clicked = MODE_FILL_D;
      if(sparam == BTN_HA)   clicked = MODE_HOLLOW_A;
      if(sparam == BTN_HB)   clicked = MODE_HOLLOW_B;
      if(sparam == BTN_PATH) clicked = MODE_PATH;
      if(sparam == BTN_LINE) clicked = MODE_LINE;
      if(sparam == BTN_PATH2) clicked = MODE_PATH2;   // v1.14
      if(sparam == BTN_LINE2) clicked = MODE_LINE2;   // v1.14
      if(sparam == BTN_HLINE) clicked = MODE_HLINE;   // v1.10
      if(sparam == BTN_DASH)  clicked = MODE_DASH;    // v1.10
      if(sparam == BTN_MEASURE) clicked = MODE_MEASURE;   // v1.11

      if(drawMode == clicked)
      {
         CancelDrawing();
      }
      else
      {
         CancelDrawing();
         drawMode = clicked;
         if(clicked == MODE_PATH || clicked == MODE_PATH2)
         {
            pathHasPoint = false;
            gCounter++;
            pathSessionId  = (string)TimeLocal() + "_" + (string)gCounter;
            pathSegCounter = 0;
         }
         else
         {
            clickState = CLICK_WAIT_FIRST;
         }
         HighlightActiveButton(drawMode);
      }
      ChartRedraw();
      return;
   }

   //--- [MT5 translation] legacy 2-arg ObjectGet(name, prop) has no MT5 equivalent - same fix
   //--- pattern established since 5e-i, applied to the remaining 11 sites in this function. All of
   //--- these properties (COLOR/WIDTH/STYLE/FONTSIZE) are single-value, not per-point, so no 4th
   //--- (point-index) argument is needed here - unlike the TIME/PRICE fix sites from earlier stages.
   if(id == CHARTEVENT_OBJECT_CHANGE && StringFind(sparam, PFX + "Lbl_") == 0)
   {
      color newLblColor = (color)ObjectGetInteger(0, sparam, OBJPROP_COLOR);
      if(newLblColor != gLabelColor)
      {
         gLabelColor = newLblColor;
         SavePersistedColor("LabelColor", gLabelColor);
      }
      int newLblFont = (int)ObjectGetInteger(0, sparam, OBJPROP_FONTSIZE);
      if(newLblFont != gLabelFontSize)
      {
         gLabelFontSize = newLblFont;
         SavePersistedInt("LabelFontSize", gLabelFontSize);
      }
      return;
   }

   if(id == CHARTEVENT_OBJECT_CHANGE && StringFind(sparam, PFX) == 0 && sparam != PREVIEW_NAME && sparam != PATH_PREVIEW_NAME && sparam != LINE_PREVIEW_NAME)
   {
      // v1.14: ویرایش Path۲/Line۲ پیش‌فرض خودِ همان ابزار را عوض می‌کند (نام «Path2_»/«Line2_» شامل «Path_»/«Line_» نیست)
      if(StringFind(sparam, "Path2_") >= 0 || StringFind(sparam, "Line2_") >= 0)
      {
         bool isP2 = (StringFind(sparam, "Path2_") >= 0);
         color c2 = (color)ObjectGetInteger(0, sparam, OBJPROP_COLOR);
         int   w2 = (int)ObjectGetInteger(0, sparam, OBJPROP_WIDTH);
         int   s2 = (int)ObjectGetInteger(0, sparam, OBJPROP_STYLE);
         if(isP2)
         {
            if(c2 != gPath2Color) { gPath2Color = c2; SavePersistedColor("Path2Color", gPath2Color); HighlightActiveButton(drawMode); }
            if(w2 != gPath2Width) { gPath2Width = w2; SavePersistedInt("Path2Width", gPath2Width); }
            if(s2 != gPath2Style) { gPath2Style = s2; SavePersistedInt("Path2Style", gPath2Style); }
         }
         else
         {
            if(c2 != gLine2Color) { gLine2Color = c2; SavePersistedColor("Line2Color", gLine2Color); HighlightActiveButton(drawMode); }
            if(w2 != gLine2Width) { gLine2Width = w2; SavePersistedInt("Line2Width", gLine2Width); }
            if(s2 != gLine2Style) { gLine2Style = s2; SavePersistedInt("Line2Style", gLine2Style); }
         }
         return;
      }

      if(StringFind(sparam, "Path_") >= 0)
      {
         color newPathColor = (color)ObjectGetInteger(0, sparam, OBJPROP_COLOR);
         if(newPathColor != gPathColor)
         {
            gPathColor = newPathColor;
            SavePersistedColor("PathColor", gPathColor);
            HighlightActiveButton(drawMode);
         }
         int newPathWidth = (int)ObjectGetInteger(0, sparam, OBJPROP_WIDTH);
         if(newPathWidth != gPathWidth)
         {
            gPathWidth = newPathWidth;
            SavePersistedInt("PathWidth", gPathWidth);
         }
         int newPathStyle = (int)ObjectGetInteger(0, sparam, OBJPROP_STYLE);
         if(newPathStyle != gPathStyle)
         {
            gPathStyle = newPathStyle;
            SavePersistedInt("PathStyle", gPathStyle);
         }
         return;
      }

      // v1.10 (MT4 v1.15): ویرایش خط افقی / Dash پیش‌فرض خودِ همان ابزار را عوض می‌کند، نه Line را
      bool isHRay = (StringFind(sparam, "HRay_") >= 0);
      if(isHRay || StringFind(sparam, "Dash_") >= 0)
      {
         color newCol = (color)ObjectGetInteger(0, sparam, OBJPROP_COLOR);
         int   newW   = (int)ObjectGetInteger(0, sparam, OBJPROP_WIDTH);
         int   newSt  = (int)ObjectGetInteger(0, sparam, OBJPROP_STYLE);
         if(isHRay)
         {
            if(newCol != gHRayColor) { gHRayColor = newCol; SavePersistedColor("HRayColor", gHRayColor); HighlightActiveButton(drawMode); }
            if(newW   != gHRayWidth) { gHRayWidth = newW;   SavePersistedInt("HRayWidth", gHRayWidth); }
            if(newSt  != gHRayStyle) { gHRayStyle = newSt;  SavePersistedInt("HRayStyle", gHRayStyle); }
         }
         else
         {
            if(newCol != gDashColor) { gDashColor = newCol; SavePersistedColor("DashColor", gDashColor); HighlightActiveButton(drawMode); }
            if(newW   != gDashWidth) { gDashWidth = newW;   SavePersistedInt("DashWidth", gDashWidth); }
            if(newSt  != gDashStyle) { gDashStyle = newSt;  SavePersistedInt("DashStyle", gDashStyle); }
         }
         return;
      }

      if(StringFind(sparam, "Line_") >= 0)
      {
         color newLineColor = (color)ObjectGetInteger(0, sparam, OBJPROP_COLOR);
         if(newLineColor != gLineColor)
         {
            gLineColor = newLineColor;
            SavePersistedColor("LineColor", gLineColor);
            HighlightActiveButton(drawMode);
         }
         int newLineWidth = (int)ObjectGetInteger(0, sparam, OBJPROP_WIDTH);
         if(newLineWidth != gLineWidth)
         {
            gLineWidth = newLineWidth;
            SavePersistedInt("LineWidth", gLineWidth);
         }
         int newLineStyle = (int)ObjectGetInteger(0, sparam, OBJPROP_STYLE);
         if(newLineStyle != gLineStyle)
         {
            gLineStyle = newLineStyle;
            SavePersistedInt("LineStyle", gLineStyle);
         }
         return;
      }

      color newColor = (color)ObjectGetInteger(0, sparam, OBJPROP_COLOR);
      if(StringFind(sparam, "_A_") >= 0)
      {
         gColorA = newColor;
         SavePersistedColor("ColorA", gColorA);
         RefreshButtonColors();
      }
      else if(StringFind(sparam, "_B_") >= 0)
      {
         gColorB = newColor;
         SavePersistedColor("ColorB", gColorB);
         RefreshButtonColors();
      }
      else if(StringFind(sparam, "_C_") >= 0)
      {
         gColorC = newColor;
         SavePersistedColor("ColorC", gColorC);
         RefreshButtonColors();
      }
      else if(StringFind(sparam, "_D_") >= 0)
      {
         gColorD = newColor;
         SavePersistedColor("ColorD", gColorD);
         RefreshButtonColors();
      }

      int newWidth = (int)ObjectGetInteger(0, sparam, OBJPROP_WIDTH);
      if(newWidth != gWidth)
      {
         gWidth = newWidth;
         SavePersistedInt("Width", gWidth);
      }

      int newStyle = (int)ObjectGetInteger(0, sparam, OBJPROP_STYLE);
      if(newStyle != gStyle)
      {
         gStyle = newStyle;
         SavePersistedInt("Style", gStyle);
      }
      return;
   }

   //--- FEATURE (v1.08, Item 1): live label-position preview while a label
   //--- is armed - same rate-limited-ChartRedraw pattern as the 3 Draw-tool
   //--- previews right below, PLUS an explicit ChartRedraw() (see below).
   //--- FIX (v1.08, per Mahmoud's live test): throttle tightened from the
   //--- Draw-tool previews' 150ms down to 60ms - matching POC's own
   //--- cursor-follow guard above, which Mahmoud never reported as
   //--- stepping. The residual "کمتر شده اما هست" stepping after the
   //--- ChartRedraw() fix is most likely just this interval itself (each
   //--- throttle window is a visible jump at fast mouse speeds) - 60ms
   //--- halves the jump size without going back to redrawing on every
   //--- single mouse-move event.
   if(id == CHARTEVENT_MOUSE_MOVE && armedLabel != "")
   {
      static uint lastLabelMoveMs = 0;
      uint nowMsLbl = GetTickCount();
      if(nowMsLbl - lastLabelMoveMs < 60) return;
      lastLabelMoveMs = nowMsLbl;

      datetime lpTime; double lpPrice; int lpSub;
      //--- JUDGMENT CALL (v1.08): deliberately NOT bar-shift-snapped the way
      //--- POC's own cursor-follow is (see the POC CHARTEVENT_MOUSE_MOVE
      //--- guard above). PlaceLabel() itself - see the CHARTEVENT_CLICK
      //--- handler further below - places at the raw ChartXYToTimePrice()
      //--- result, unsnapped. Snapping the preview to a bar while the real
      //--- click lands off-bar would make the preview lie about where the
      //--- label will actually go, so this mirrors PlaceLabel()'s own
      //--- (unsnapped) positioning exactly instead of POC's bar-snap, which
      //--- exists for POC's own different purpose.
      if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, lpSub, lpTime, lpPrice))
      {
         UpdateLabelPreview(armedLabel, lpTime, lpPrice);
         //--- FIX (v1.08, per Mahmoud's live test): the rectangle/line/path
         //--- previews move smoothly on MT4 without an explicit ChartRedraw()
         //--- (see their own comments - relying on MT4's natural refresh
         //--- cycle was a deliberate lag-avoidance choice made earlier in
         //--- this project). OBJ_TEXT apparently doesn't get that same free
         //--- ride here - Mahmoud confirmed the label preview visibly
         //--- "stepped" rather than following smoothly on MT4, and per the
         //--- Stage 5e-v MT5 work, MT5 doesn't auto-redraw on object-property
         //--- changes at all - so this ChartRedraw() is confirmed necessary
         //--- on both platforms independently, included here without
         //--- needing to rediscover the lag first.
         ChartRedraw();
      }
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE && (drawMode == MODE_PATH || drawMode == MODE_PATH2) && pathHasPoint)
   {
      static uint lastPathMoveMs = 0;
      uint nowMsP = GetTickCount();
      if(nowMsP - lastPathMoveMs < 150) return;
      lastPathMoveMs = nowMsP;

      datetime mTimeP; double mPriceP; int subWindowP;
      if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, subWindowP, mTimeP, mPriceP))
      {
         UpdatePathPreview(pathTime, pathPrice, mTimeP, mPriceP);
         ChartRedraw(); // [MT5 behavioral fix] same reasoning as the rectangle/shade preview above.
      }
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE && (drawMode == MODE_LINE || drawMode == MODE_LINE2 || drawMode == MODE_DASH) && clickState == CLICK_WAIT_SECOND)
   {
      static uint lastLineMoveMs = 0;
      uint nowMsL = GetTickCount();
      if(nowMsL - lastLineMoveMs < 150) return;
      lastLineMoveMs = nowMsL;

      int mx = (int)lparam, my = (int)dparam;
      datetime t2; double p2;
      if(gShiftHeld)
         ApplyShiftSnap(firstPixelX, firstPixelY, mx, my, firstTime, firstPrice, t2, p2);
      else
      {
         int sub;
         if(!ChartXYToTimePrice(0, mx, my, sub, t2, p2)) return;
      }
      UpdateLinePreview(firstTime, firstPrice, t2, p2);
      ChartRedraw(); // [MT5 behavioral fix] same reasoning as the rectangle/shade preview above.
      return;
   }

   // v1.11 (MT4 v1.14): پیش‌نمایش زنده‌ی Measure - همان الگوی throttle‌شده‌ی Line ولی ۷ خط (BuildMeasureTool با isPreview=true)
   if(id == CHARTEVENT_MOUSE_MOVE && drawMode == MODE_MEASURE && clickState == CLICK_WAIT_SECOND)
   {
      static uint lastMeasMoveMs = 0;
      uint nowMsM = GetTickCount();
      if(nowMsM - lastMeasMoveMs < 150) return;
      lastMeasMoveMs = nowMsM;

      int mxM = (int)lparam, myM = (int)dparam;
      datetime t2M; double p2M;
      if(gShiftHeld)
         ApplyShiftSnap(firstPixelX, firstPixelY, mxM, myM, firstTime, firstPrice, t2M, p2M);
      else
      {
         int subM;
         if(!ChartXYToTimePrice(0, mxM, myM, subM, t2M, p2M)) return;
      }
      BuildMeasureTool(MEASURE_PREVIEW_NAME, firstTime, firstPrice, t2M, p2M, true);
      ChartRedraw();
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE && clickState == CLICK_WAIT_SECOND && drawMode != MODE_LINE && drawMode != MODE_LINE2 && drawMode != MODE_DASH && drawMode != MODE_MEASURE)
   {
      static uint lastMoveMs = 0;
      uint nowMs = GetTickCount();
      if(nowMs - lastMoveMs < 150) return;
      lastMoveMs = nowMs;

      datetime mTime; double mPrice; int subWindow;
      if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, subWindow, mTime, mPrice))
      {
         UpdatePreview(firstTime, firstPrice, mTime, mPrice);
         // [MT5 behavioral fix, found live] the MT4 source deliberately omits ChartRedraw() here
         // (comment: MT4's own natural refresh cycle was enough, added redraw caused lag before).
         // That assumption doesn't hold on MT5 - Mahmoud observed ~1s delay before the preview
         // started following the mouse, consistent with MT5 only auto-redrawing on a new price
         // tick rather than on object changes. Rate-limited to the same 150ms as the update above,
         // so the added cost is small.
         ChartRedraw();
      }
      return;
   }

   if(id == CHARTEVENT_CLICK && (drawMode == MODE_PATH || drawMode == MODE_PATH2))
   {
      if(skipNextClick)
      {
         skipNextClick = false;
         return;
      }
      HandlePathClick((int)lparam, (int)dparam);
      return;
   }

   if(id == CHARTEVENT_CLICK)
   {
      if(skipNextClick)
      {
         skipNextClick = false;
         return;
      }

      if(armedLabel != "")
      {
         datetime lt; double lp; int lsub;
         if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, lsub, lt, lp))
         {
            PlaceLabel(armedLabel, lt, lp);
            DisarmLabel();
         }
         return;
      }

      if(clickState == CLICK_IDLE) return;

      int cx = (int)lparam, cy = (int)dparam;
      datetime clickTime; double clickPrice; int subWindow;
      if(!ChartXYToTimePrice(0, cx, cy, subWindow, clickTime, clickPrice))
         return;

      if(clickState == CLICK_WAIT_FIRST && drawMode == MODE_HLINE)
      {
         // v1.10: Horizontal Line - تک‌کلیک؛ بعد از رسم حالت ابزار تمام می‌شود
         FinalizeHRay(clickTime, clickPrice);
         CancelDrawing();
         ChartRedraw();
         return;
      }

      if(clickState == CLICK_WAIT_FIRST)
      {
         firstTime   = clickTime;
         firstPrice  = clickPrice;
         firstPixelX = cx;
         firstPixelY = cy;
         clickState  = CLICK_WAIT_SECOND;
      }
      else if(clickState == CLICK_WAIT_SECOND)
      {
         if(drawMode == MODE_LINE || drawMode == MODE_LINE2 || drawMode == MODE_DASH)
         {
            datetime t2 = clickTime; double p2 = clickPrice;
            if(gShiftHeld)
               ApplyShiftSnap(firstPixelX, firstPixelY, cx, cy, firstTime, firstPrice, t2, p2);
            if(t2 == firstTime && p2 == firstPrice) return;
            if(drawMode == MODE_DASH) FinalizeDash(firstTime, firstPrice, t2, p2);   // v1.10
            else if(drawMode == MODE_LINE2) FinalizeLine2(firstTime, firstPrice, t2, p2);   // v1.14
            else                      FinalizeLine(firstTime, firstPrice, t2, p2);
            CancelDrawing();
         }
         else if(drawMode == MODE_MEASURE)   // v1.11
         {
            datetime t2 = clickTime; double p2 = clickPrice;
            if(gShiftHeld)
               ApplyShiftSnap(firstPixelX, firstPixelY, cx, cy, firstTime, firstPrice, t2, p2);
            if(t2 == firstTime && p2 == firstPrice) return;
            FinalizeMeasure(firstTime, firstPrice, t2, p2);
            CancelDrawing();
         }
         else
         {
            if(clickTime == firstTime) return;
            FinalizeRectangle(firstTime, firstPrice, clickTime, clickPrice, drawMode);
            CancelDrawing();
         }
      }
   }
}
