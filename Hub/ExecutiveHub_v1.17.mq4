//+------------------------------------------------------------------+
//|                                                ExecutiveHub.mq4   |
//|                   Executive Hub — v1.14 (MT4)                     |
//|  Author: MAHMOUD SEYEDI                                           |
//|                                                                    |
//|  هاب اجرایی واحد — همه‌ی ابزارهای «ابجکت‌محور» (که به‌خاطر نداشتن       |
//|  بافر اندیکاتور، محدودیت سقف ۸ بافر MT4 شاملشون نمی‌شه) زیر یه سقف:   |
//|  Drawing Panel + Labeling + POC + Weekly Map + MTF Candle Preview   |
//|  + Session Opening Box + NY Edge + EMA Overlay (۷ بافر، جمعاً با     |
//|  بقیه که صفر بافرن هنوز زیر سقفه).                                  |
//|                                                                    |
//|  ردیف بالا (وسط‌چین): [Indicator] [Label] [Draw] Shade1...Line       |
//|  - دکمه‌ی «Indicator»: مینیمایز/بازکردن ۱۰ دکمه‌ی اندیکاتور، در ۲     |
//|    ردیف زیر ردیف‌های Label، هم‌ستون با ابزارهای بالا: POC، WMAP، SOB،  |
//|    NY-EDGE، MTFCP، EMA (master)، EMA10، EMA20، EMA60، EMA240.       |
//|  - EMA: علاوه بر دکمه‌ی master، ۴ دکمه‌ی جدا برای هر خط (طبق خواسته‌ی  |
//|    Mahmoud) - روشن/خاموش لحظه‌ای بدون نیاز به Properties.            |
//|                                                                    |
//|  Ichimoku Multi Timeframe، MTF MACD، MTF RSI عمداً از این هاب        |
//|  بیرون موندن (بافرشون جمعاً از سقف ۸ رد می‌شه) - مستقل با toggle       |
//|  خودشون باقی می‌مونن.                                                |
//|                                                                    |
//|  ماژول‌ها به ترتیب ادغام شدن (هرکدوم جدا تست شد):                    |
//|    ماژول ۱: POC + Weekly Map                                        |
//|    ماژول ۲: Session Opening Box + NY Edge (موتور تایم‌زون مشترک)     |
//|    ماژول ۳: MTF Candle Preview + EMA Overlay                        |
//+------------------------------------------------------------------+
//--- v1.17 (FEAT-052): 4th master button "Theme" + drawer of 7 chart colour themes and "Original" (one-shot, per chart); Hub-drawn objects get automatic contrast on any theme.
//--- v1.16: Label tab geometry (all 18 buttons = Master height, narrower label width) + new default label list.
//--- v1.15: (1) Label slots editable via RM_HubLabels.txt, 18 slots (SP2L, BTB added);
//---        (2) Weekly Map keeps adding WH+/WL- steps as price runs past the last level;
//---        (3) two new Draw tools: Horizontal Line (1 click, ray to the right) and Dash Line.
#property copyright "MAHMOUD SEYEDI"
#property description "Executive Hub"
#property description "Toggle-button drawing + labeling + indicator tools in"
#property description "one unified, minimize-able panel."
#property description "Drawn shapes/labels are independent, selectable chart"
#property description "objects that persist even if this indicator is removed -"
#property description "delete them manually if needed."
#property version   "1.17"
#property strict
#property indicator_chart_window
#property indicator_buffers 7

//--- ماژول ۳ - EMA Overlay: ۷ بافر واقعی اندیکاتور - این تنها ماژولی از
//--- ۶ ماژول ادغام‌شده‌ست که واقعاً بافر مصرف می‌کنه (بقیه صفر بافرن، فقط
//--- ابجکت). ۷ زیر سقف ۸تای MQL4 جا می‌شه، چون Ichimoku/MACD/RSI (که هرکدوم
//--- بافر زیاد دارن) عمداً از این هاب بیرون موندن.
#property indicator_color1 Silver
#property indicator_color2 Gray
#property indicator_color3 DimGray
#property indicator_color4 DarkSlateGray
#property indicator_color5 SeaGreen
#property indicator_color6 IndianRed
#property indicator_color7 Gray

// v1.11 (بازنویسیِ Session Tools): موتورِ زمانِ سشن (DST/NY->server + آفستِ پایدار)
// به ماژولِ مشترکِ RM_SessionTime.mqh منتقل شد - همان فایلِ canonical که RiskManager EA
// هم استفاده می‌کند (نسخه‌ی byte-identical در پوشه‌ی این Hub هم قرار دارد).
#include "RM_SessionTime.mqh"


//--- Enum های مورد نیاز Input های ماژول ۳ (باید قبل از استفاده تعریف بشن)
enum ENUM_ConnSource
{
   CONN_SRC_LAST_CLOSED = 0, // Last CLOSED candle (recommended when the reference TF is your decision criterion)
   CONN_SRC_LIVE         = 1  // Live/forming candle (previous default behavior)
};

enum ENUM_DISPLAY_MODE
{
   Mode_FourLines     = 0, // Ladder: all 4 EMAs drawn as separate lines
   Mode_ActiveCloud   = 1, // Static 20/60 cloud + separate EMA240 line
   Mode_MomentumColor = 2  // EMA60 colored Bullish/Bearish/Neutral; EMA10/20/240 stay grayscale
};

//--- Inputs: drawing tools
input color DefaultColorA      = clrSilver;   // Shade 1 color (light gray)
input color DefaultColorB      = clrDimGray;  // Shade 2 color (dark gray)
input color DefaultColorC      = clrTurquoise; // Shade 3 color (turquoise blue)
input color DefaultColorD      = clrLightPink; // Shade 4 color (light pink)
input int   DefaultBorderWidth = 2;
input color DefaultPathColor   = clrGray;     // Default Path color (gray theme)
input int   DefaultPathWidth   = 2;
input color DefaultLineColor   = clrRed;      // Default Line color
input int   DefaultLineWidth   = 3;
input int   PanelTopY          = 29;   // distance from the top of the chart - tuned by Mahmoud to line up with Risk Manager EA's own header row
input int   PanelWidth         = 195;  // matches Risk Manager EA's own PW=195 exactly - FIX (v1.08, per Mahmoud's live test): now actually USED (see UsableChartWidth()) to reserve that much space on the right so the Hub's own centering/shrink math never lets it creep under RiskManager EA's own top-right panel on a narrow chart. Was previously just a documentation value with no code effect.
input int   BtnHeight          = 22;
input int   BtnGap             = 4;
input int   MasterBtnWidth     = 58;   // 4 master buttons (Ind/Label/Draw/Theme) v1.17 (FEAT-052) side by side must fit PanelWidth

//--- Inputs: legacy names kept for the rest of the file's math -
//--- BtnWidth is now the width of ONE cell in the 2-column grid (tools,
//--- labels, indicators all wrap at TOOL_COUNT=2 columns to fit PanelWidth)
input int   BtnWidth           = 90;

//--- FIX (v1.08, Item 2 follow-up - per Mahmoud's live test): shrinking only
//--- once content would literally overflow the chart wasn't aggressive
//--- enough - on a borderline window (content only marginally wider than
//--- the chart) the shrink was nearly invisible, so the panel still felt
//--- like it "takes up a lot of room" even though it technically fit.
//--- HubMaxWidthFraction lets the shrink trigger earlier/more visibly: the
//--- panel now targets AT MOST this fraction of the chart's width before
//--- starting to shrink, not just "don't go off-screen". Lower = shrinks
//--- earlier and more. Tune to taste - I can't see your actual screen size.
input double HubMaxWidthFraction = 0.60; // panel targets at most this fraction of chart width (Item 2 auto-shrink trigger)

//--- FEATURE (v1.08, Item 2): "effective" (computed, not raw input) versions
//--- of BtnWidth/MasterBtnWidth/BtnGap - same naming spirit as RiskManager
//--- EA's own g_effRiskPerTrade pattern. On a narrow chart/window an
//--- expanded category's grid can extend off-screen (PanelContentWidth(),
//--- computed at full size, exceeds the chart's own width) - RecomputeEffectiveSizes()
//--- scales these three down from the raw inputs (which stay untouched as
//--- the "at full size" baseline) whenever that happens, down to a floor
//--- that keeps every label's text - including the longest ones ("GOLDEN
//--- ZONE", "BREAKEVEN", "LIQUIDITY") - legible and non-overlapping. Used
//--- EVERYWHERE the raw inputs used to be read for sizing/positioning.
int g_effBtnWidth       = 0;
int g_effMasterBtnWidth = 0;
int g_effBtnGap         = 0;
int g_effLabelBtnWidth  = 0;   // v1.16: عرض مؤثر دکمه‌های گرید لیبل (جدا از g_effBtnWidth که Draw/Indicator دارند)

//--- Floors chosen by inspecting each: BTNWIDTH_FLOOR is roughly the
//--- narrowest a BtnWidth-sized cell (Arial Bold, FontSize=7) can go before
//--- "GOLDEN ZONE"/"BREAKEVEN"/"LIQUIDITY" (the 3 longest LabelList
//--- entries) start clipping or crowding their button's edges.
//--- MASTERBTNWIDTH_FLOOR does the same for the 4 master buttons' own
//--- longest text ("Label -"/"Indicator -" style toggle labels).
//--- BTNGAP_FLOOR just keeps adjacent buttons from visually touching.
//--- JUDGMENT CALL (v1.08): chosen from the button geometry/font metrics
//--- alone - Mahmoud, please eyeball the floor on a real narrow MT4 chart/
//--- window during testing and tell me if any of the three needs nudging;
//--- this environment can't render MT4's own button font to verify visually.
#define BTNWIDTH_FLOOR       62
#define MASTERBTNWIDTH_FLOOR 42
#define BTNGAP_FLOOR         2
#define LABELBTNWIDTH_FLOOR  36   // v1.16: کف عرض دکمه‌ی لیبل وقتی پنل برای چارت کوچک جمع می‌شود

//--- Inputs: labeling panel
input int   LabelDefaultFontSize  = 10;
input color LabelDefaultColor     = clrDimGray; // fallback only if auto-contrast can't be computed
input int   LabelBtnHeight        = 18;   // v1.16: دیگر استفاده نمی‌شود - ارتفاع دکمه‌های لیبل = BtnHeight (ارتفاع Master)
input int   LabelBtnWidth         = 52;   // v1.16: عرض دکمه‌های گرید لیبل (بر پایه‌ی بلندترین نام پیش‌فرض "3 PUSH" + حاشیه)

//--- Inputs: Module 1 - POC (Volume Profile Point of Control)
input int     POC_BucketCount           = 100;  // Number of price buckets (profile resolution)
input double  POC_ExhaustionSegmentPct  = 25.0; // Final % of range used for Exhaustion Point
input color   POC_LineColor       = clrDodgerBlue;     // POC line - bright blue
input int     POC_LineWidth       = 3;
input color   POC_LVN_Color       = clrLightSkyBlue;   // LVN - light blue
input int     POC_LVN_Width       = 1;
input color   POC_Exhaustion_Color = clrDeepPink;      // Exhaustion Point - pink
input int     POC_Exhaustion_Width = 4;
input int     POC_LabelFontSize   = 9;
input int     POC_LabelRightMargin = 8;  // Label distance from right edge of chart (px) - near price scale
input int     POC_LabelAboveLineGap = 4; // Label distance above the line (px)

//--- Inputs: Module 1 - Weekly Map
//--- BUG-FIX (v1.01, Bug 1): each color role now has a dark-background AND
//--- light-background variant, chosen at draw time via WMAP_GetContrastColor()
//--- (same luminance-threshold pattern as RM_Tools.mqh's GetContrastColor()).
//--- The original single inputs become the dark-background variant (default
//--- value unchanged, so existing dark-theme setups look identical); the new
//--- *_Light inputs are the variant used when the chart background is light.
input color WMAP_ColorExtreme       = clrSilver;      // WH / WL line color - dark chart bg (base gray)
input color WMAP_ColorExtreme_Light = clrDimGray;     // WH / WL line color - light chart bg
input color WMAP_ColorInner         = clrDimGray;     // 25% / 50% / 75% line color - dark chart bg (dimmer gray)
input color WMAP_ColorInner_Light   = clrGray;        // 25% / 50% / 75% line color - light chart bg
input color WMAP_ColorExtension     = clrGainsboro;   // WH+25% / WL-25% line color - dark chart bg (brighter gray)
input color WMAP_ColorExtension_Light = C'40,40,40';  // WH+25% / WL-25% line color - light chart bg
input bool  WMAP_ShowInnerLevels = true;         // Show 25% / 50% / 75% internal levels
input bool  WMAP_ShowExtensions  = true;         // Show WH+25% / WL-25% extension levels
input bool  WMAP_ShowLabels      = true;         // Show left-edge text tags (WH, WL, 50%, ...)
input int   WMAP_LabelXOffset    = 6;            // Tag distance from the left edge of the chart, in pixels
input int   WMAP_FontSize        = 8;            // Tag font size

//--- Inputs: Module 2 - Session Opening Box (SOB)
input bool   SOB_EnableTokyo         = true;
input bool   SOB_EnableLondon        = false; // only Tokyo is backtested/used for now
input bool   SOB_EnableNewYork       = false; // only Tokyo is backtested/used for now
input string SOB_TokyoStart          = "20:00";
input string SOB_TokyoEnd            = "21:00";
input color  SOB_TokyoColor          = clrYellow;
input string SOB_LondonStart         = "03:00";
input string SOB_LondonEnd           = "04:00";
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

//--- Inputs: Module 2 - NY Edge
input string NYE_NewYorkStart           = "09:00";
input string NYE_NewYorkEnd             = "18:00";
input color  NYE_EdgeColor              = clrDodgerBlue;
input int    NYE_EdgeLineWidth          = 1;
input ENUM_TIMEFRAMES NYE_BaseTimeframe = PERIOD_M5;

//--- Inputs: Module 3 - MTF Candle Preview
input ENUM_TIMEFRAMES MTFCP_PreviewTF      = PERIOD_H1;
input int             MTFCP_CandleCount   = 3;
input int             MTFCP_GapPx         = 270;
input int             MTFCP_SlotWidthPx   = 52;
input double          MTFCP_BodyWidthRatio = 0.65;
input bool             MTFCP_ShowCountdown = true;
input bool             MTFCP_ShowLiveConnector = true;
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

//--- Inputs: Module 3 - EMA Overlay
input ENUM_DISPLAY_MODE EMA_DisplayMode = Mode_FourLines;
input int EMA1_Period = 10;
input int EMA2_Period = 20;
input int EMA3_Period = 60;
input int EMA4_Period = 240;
input double EMA_Mode3_GapFilter    = 0.001;
input color  EMA_Mode3_BullishColor = clrSeaGreen;
input color  EMA_Mode3_BearishColor = clrIndianRed;
input color  EMA_Mode3_NeutralColor = clrGray;

//--- نام ابجکت‌ها/کلیدها — ابزارهای رسم
#define PFX          "DrawPanel_"
#define BTN_FA       PFX+"Btn_FillA"
#define BTN_FB       PFX+"Btn_FillB"
#define BTN_FC       PFX+"Btn_FillC"
#define BTN_FD       PFX+"Btn_FillD"
#define BTN_HA       PFX+"Btn_HollowA"
#define BTN_HB       PFX+"Btn_HollowB"
#define BTN_PATH     PFX+"Btn_Path"
#define BTN_LINE     PFX+"Btn_Line"
// v1.14 (اصلاح): دکمه‌ی جدید Measure - در فضای خالی زیر سه دکمه‌ی مادر (Ind+/Label+/Draw-)
// می‌شینه، نه توی گرید ۸تایی اصلی (TOOL_COUNT_ITEMS دست‌نخورده موند تا چیدمان گرید عوض نشه).
// v1.15: دو ابزار جدید خط - داخل گرید Draw (۸ -> ۱۰ آیتم، ۴ -> ۵ ستون؛ عرض Draw از Label و Indicator کمتر می‌مونه)
#define BTN_HLINE    PFX+"Btn_HLine"
#define BTN_DASH     PFX+"Btn_Dash"
#define BTN_MEASURE  PFX+"Btn_Measure"
#define MEASURE_PREVIEW_NAME PFX+"MeasurePreview"
#define BTN_MASTER_DRAW PFX+"Btn_MasterDraw"
#define PREVIEW_NAME PFX+"Preview"
#define PATH_PREVIEW_NAME PFX+"PathPreview"
#define LINE_PREVIEW_NAME PFX+"LinePreview"
//--- FEATURE (v1.08, Item 1): live label-position preview - same family as
//--- the 3 Draw-tool previews above, just for the armed Label grid.
#define LABEL_PREVIEW_NAME PFX+"LabelPreview"
#define TOOL_COUNT 2
#define TOOL_COUNT_ITEMS 10

//--- نام ابجکت‌ها/کلیدها — برچسب‌گذاری
#define BTN_MASTER_LABELS PFX+"Btn_MasterLabels"
// v1.15: تعداد ثابت ۱۸ جایگاه؛ ۱۶ تای اول در گرید اصلی، ۲ تای آخر (SP2L, BTB) در فضای خالی زیر سه دکمه‌ی مادر.
// متن هر جایگاه از فایل خارجی RM_HubLabels.txt خوانده می‌شود (HubLabelDefault فقط پیش‌فرض/seed است).
#define LABEL_COUNT      18
#define LABEL_GRID_COUNT 16
#define LABEL_MAX_CHARS  20
#define HUB_LABELS_FILE    "RM_HubLabels.txt"
#define HUB_LABELS_BACKUP  "RM_HubLabels_backup.txt"
#define HUB_LABELS_VERSION 116   // v1.16: لیست پیش‌فرض جدید -> مهاجرت یک‌باره با بکاپ (بعدش ویرایش‌های دستی دست‌نخورده می‌مانند)
#define GV_HUB_LABELS_VERSION "RM_HubLabelsVer"
string LabelList[LABEL_COUNT];

string HubLabelDefault(int i)
{
   string d[LABEL_COUNT] = {
      "LEG 1", "LEG 2", "LEG 3", "TR", "SP", "CH", "HH", "LL",
      "3 PUSH", "D-B/T", "POI", "LQ", "BR", "MM", "EQ-L", "EQ-H",
      "SP2L", "BTB"
   };
   if(i < 0 || i >= LABEL_COUNT) return("");
   return(d[i]);
}

// فایل: یک خط به ازای هر جایگاه، فرمت "L01: LEG 1" ... "L18: BTB". متن خالی (مثلاً "L05:") = آن دکمه مخفی.
// خط‌های شروع‌شده با # توضیح‌اند. جایگاهی که در فایل نباشد پیش‌فرض خودش را می‌گیرد.
void WriteDefaultHubLabels()
{
   int h = FileOpen(HUB_LABELS_FILE, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      Print("ExecutiveHub: WriteDefaultHubLabels - FileOpen failed, error ", GetLastError());
      return;
   }
   FileWrite(h, "# Executive Hub label slots (Label tab). Edit the text after the colon; leave it empty to hide that button.");
   FileWrite(h, "# Slot count is fixed at 18. Max " + IntegerToString(LABEL_MAX_CHARS) + " characters per label. Changes apply the next time the Hub starts.");
   for(int i = 0; i < LABEL_COUNT; i++)
      FileWrite(h, "L" + (i + 1 < 10 ? "0" : "") + IntegerToString(i + 1) + ": " + HubLabelDefault(i));
   FileClose(h);
}

void LoadHubLabels()
{
   for(int i = 0; i < LABEL_COUNT; i++)
      LabelList[i] = HubLabelDefault(i);

   int h = FileOpen(HUB_LABELS_FILE, FILE_READ|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      StringTrimLeft(line); StringTrimRight(line);
      if(line == "") continue;
      if(StringGetChar(line, 0) == '#') continue;

      int colonPos = StringFind(line, ":");
      if(colonPos < 1) continue;

      string key  = StringSubstr(line, 0, colonPos);
      string text = StringSubstr(line, colonPos + 1);
      StringTrimLeft(key);  StringTrimRight(key);
      StringTrimLeft(text); StringTrimRight(text);

      int kc = StringGetChar(key, 0);
      if(kc != 'L' && kc != 'l') continue;
      int slot = (int)StringToInteger(StringSubstr(key, 1));
      if(slot < 1 || slot > LABEL_COUNT) continue;

      if(StringLen(text) > LABEL_MAX_CHARS) text = StringSubstr(text, 0, LABEL_MAX_CHARS);
      LabelList[slot - 1] = text;   // متن خالی عمداً پذیرفته می‌شود -> دکمه مخفی
   }
   FileClose(h);
}

// همان الگوی EnsureContextChecklistSeed: فایل نبود -> seed؛ فایل بود ولی نسخه‌ی GV قدیمی -> بکاپ + جایگزینی یک‌باره با پیش‌فرض.
void EnsureHubLabelsSeed()
{
   bool haveVer = GlobalVariableCheck(GV_HUB_LABELS_VERSION) && (int)GlobalVariableGet(GV_HUB_LABELS_VERSION) >= HUB_LABELS_VERSION;

   if(!FileIsExist(HUB_LABELS_FILE))
   {
      WriteDefaultHubLabels();
      GlobalVariableSet(GV_HUB_LABELS_VERSION, HUB_LABELS_VERSION);
   }
   else if(!haveVer)
   {
      if(!FileCopy(HUB_LABELS_FILE, 0, HUB_LABELS_BACKUP, FILE_REWRITE))
         Print("ExecutiveHub: label file backup failed, error ", GetLastError());
      WriteDefaultHubLabels();
      GlobalVariableSet(GV_HUB_LABELS_VERSION, HUB_LABELS_VERSION);
      Print("ExecutiveHub: label file migrated to v", HUB_LABELS_VERSION, " default (old file backed up to ", HUB_LABELS_BACKUP, ")");
   }
   LoadHubLabels();
}

// فونت دکمه با طول متن کوچک می‌شود (عرض دکمه بر مبنای ۱۱ کاراکتر GOLDEN ZONE تنظیم شده): ۷ تا ۱۱ کاراکتر، بعد متناسب، حداقل ۵.
int HubLabelFontSize(string t)
{
   // v1.16: فونت بر اساس عرض واقعی دکمه (g_effLabelBtnWidth) و طول متن. تخمین Arial Bold حروف بزرگ ≈ 0.9 x اندازه‌ی فونت پیکسل
   // برای هر کاراکتر، با ۶ پیکسل حاشیه؛ از ۷ شروع و تا حداقل ۵ کم می‌شود. نام‌هایی که با فونت ۵ هم جا نشوند در لبه‌ی دکمه بریده نمایش داده
   // می‌شوند (با عرض پیش‌فرض ۵۲، حدود ۱۰ کاراکتر با فونت ۵ جا می‌شود - نه ۲۰).
   int n = StringLen(t);
   int w = (g_effLabelBtnWidth > 0) ? g_effLabelBtnWidth : LabelBtnWidth;
   double avail = (double)(w - 6);
   int fs = 7;
   while(fs > 5 && (double)n * 0.9 * (double)fs > avail) fs--;
   return(fs);
}

//--- نام دکمه‌ی مادر Indicator — پایه‌ی هاب اجرایی؛ ابزارهای زیرش (POC،
//--- Weekly Map، MTF Candle Preview، Session Opening Box، NY Edge، EMA)
//--- در مراحل بعدی (ماژول ۱، ۲، ۳) اضافه می‌شن
#define BTN_MASTER_INDICATOR PFX+"Btn_MasterIndicator"

//--- v1.17 (FEAT-052): دکمه‌ی مادر چهارم «Theme» + کشوی ۷ تم رنگی چارت + «Original».
//--- THEME_ORIG_NAME = آبجکت مخفیِ نگه‌دارنده‌ی رنگ‌های اصلی چارت (قبل از اولین تم) - عمداً "Btn_" ندارد و
//--- در OnDeinit / RaiseHubPanelToFront پاک نمی‌شود (روی تغییر تایم‌فریم/ری‌لود/ری‌استارت و حتی حذف Hub می‌ماند).
#define BTN_MASTER_THEME PFX+"Btn_MasterTheme"
#define BTN_THEME_ORIG   PFX+"Btn_Theme_Orig"
#define THEME_COUNT      7
#define THEME_ORIG_NAME  PFX+"ThemeOrig"

//--- v1.17 (FEAT-052): خواندن رنگ چارت برای محاسبات کنتراست. ChartSetInteger در MT4 ممکن است async باشد (خواندن
//--- بلافاصله بعدش مقدار قدیمی بدهد)، پس موقع recolour یک‌باره‌ی بعد از کلیک تم، رنگ‌های تازه مستقیم از این override
//--- می‌آیند (g_ovOn=true فقط داخل Theme_RecolourOnce)؛ در بقیه‌ی زمان‌ها همان ChartGetInteger قبلی است.
bool  g_ovOn   = false;
color g_ovBg   = clrBlack;
color g_ovFg   = clrWhite;
color g_ovBull = clrWhite;
color g_ovBear = clrGray;
color Hub_ChartBg()   { return(g_ovOn ? g_ovBg   : (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND)); }
color Hub_ChartFg()   { return(g_ovOn ? g_ovFg   : (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND)); }
color Hub_ChartBull() { return(g_ovOn ? g_ovBull : (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BULL)); }
color Hub_ChartBear() { return(g_ovOn ? g_ovBear : (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR)); }

//--- v1.17 (FEAT-052): کنتراست خودکارِ رنگ‌های ثابتِ آبجکت‌های Hub. هم‌سبک MTFCP_ContrastSafeColor: اگر اختلاف
//--- luminance رنگ با پس‌زمینه کمتر از THEME_CONTRAST_MIN_DIFF باشد، رنگ را (روی پس‌زمینه‌ی تیره روشن‌تر / روی روشن
//--- تیره‌تر) در گام‌های ۳۰تایی جابه‌جا می‌کند تا کنتراست کافی شود؛ در غیر این‌صورت دقیقاً همان رنگ برمی‌گردد.
#define THEME_CONTRAST_MIN_DIFF 45
color Theme_ContrastSafe(color c)
{
   if(c == clrNONE) return(c);
   long bg = (long)Hub_ChartBg();
   int bgR = (int)(bg & 0xFF), bgG = (int)((bg >> 8) & 0xFF), bgB = (int)((bg >> 16) & 0xFF);
   int cR  = (int)(c  & 0xFF), cG  = (int)((c  >> 8) & 0xFF), cB  = (int)((c  >> 16) & 0xFF);
   double bgLum = 0.299 * bgR + 0.587 * bgG + 0.114 * bgB;
   double cLum  = 0.299 * cR  + 0.587 * cG  + 0.114 * cB;
   if(MathAbs(bgLum - cLum) >= THEME_CONTRAST_MIN_DIFF) return(c);

   int nR = cR, nG = cG, nB = cB;
   for(int k = 1; k <= 8; k++)
   {
      int sh = 30 * k;
      if(bgLum < 128)
      {
         nR = (int)MathMin(255, cR + sh); nG = (int)MathMin(255, cG + sh); nB = (int)MathMin(255, cB + sh);
      }
      else
      {
         nR = (int)MathMax(0, cR - sh); nG = (int)MathMax(0, cG - sh); nB = (int)MathMax(0, cB - sh);
      }
      double nLum = 0.299 * nR + 0.587 * nG + 0.114 * nB;
      if(MathAbs(bgLum - nLum) >= THEME_CONTRAST_MIN_DIFF) break;
   }
   return((color)(nR | (nG << 8) | (nB << 16)));
}

//--- پس‌زمینه‌ی یکپارچه‌ی داشبورد + عنوان بالاش (طبق خواسته‌ی Mahmoud که حس
//--- یه پنل واحد مثل Risk Manager EA بده، نه دکمه‌های ول روی چارت)
input color  HubBgColor     = C'22,25,35';   // exact same body background as Risk Manager EA's own dashboard (from its source: RectC(P+"BG", ..., C'22,25,35', ...))
input color  HubBorderColor = C'50,54,68';   // matches the subtle border tone used elsewhere in Risk Manager EA's UI
#define CLR_SUBTOGGLE_ACTIVE C'0,150,150'    // exact same teal Risk Manager EA uses for its own active sub-toggles (Candle Timer, D H/L, Key Time, ...) - the 3 MASTER buttons (Draw/Label/Indicator) stay green, only the toggles UNDER them use this
#define CLR_INACTIVE_GRAY C'70,70,80'        // exact same gray Risk Manager EA uses for its own inactive/off buttons - used everywhere a button means "off/inactive", EXCEPT the Draw tab (where gray can be an actual chosen drawing color, not a state indicator)
#define HUB_BG_NAME    PFX+"HubBg"

//--- BUG-FIX (v1.01, Bug 3): 3-tier z-order scheme, reused exactly from
//--- RM_Dashboard.mqh (v45, "Punch List Round 3, Item 6"). Not just one big
//--- number on the background alone - if only the background got a huge
//--- z-order, it would win click-priority over the buttons/labels drawn on
//--- top of it too (higher z-order wins the click in MT4's object model),
//--- exactly backwards from the goal. All three tiers move together,
//--- preserving whatever relative internal ordering the Hub panel already
//--- has (background < ordinary buttons/labels < anything that must sit
//--- above even its own label), just shifted onto a base far above anything
//--- any indicator's own drawings (Weekly Map/NY Edge/MTF Candle Preview)
//--- could ever use by default.
#define PANEL_ZORDER_BG      1000000
#define PANEL_ZORDER_FG      1000001
#define PANEL_ZORDER_FG_TOP  1000002

//--- ماژول ۱: POC — نام‌ها با پیشوند مستقل POC_ (نه PFX هاب) تا با کلید
//--- GlobalVariable قبلی (نسخه‌ی مستقل POC.mq4) سازگار بمونه و تنظیمات
//--- ذخیره‌شده‌ی Mahmoud از دست نره
#define POC_PFX          "POC_"
#define POC_LINE_POC     POC_PFX+"POC"
#define POC_LINE_LVN     POC_PFX+"LVN"
#define POC_LINE_EXH     POC_PFX+"Exhaustion"
#define POC_LBL_POC      POC_PFX+"POC_Label"
#define POC_LBL_LVN      POC_PFX+"LVN_Label"
#define POC_LBL_EXH      POC_PFX+"Exhaustion_Label"
#define POC_TRACK_VLINE  POC_PFX+"TrackLine"
#define POC_TRACK_LABEL  POC_PFX+"TrackLabel"
#define BTN_POC          PFX+"Btn_POC"

enum POC_STATE_ENUM { POC_IDLE, POC_WAIT_FIRST_CLICK, POC_WAIT_SECOND_CLICK };
POC_STATE_ENUM pocState       = POC_IDLE;
bool           pocActive      = false;
bool           pocSkipNextClick = false; // جدا از skipNextClick هاب، چون POC منطق کلیک مستقل خودش رو داره
datetime       pocFirstClickTime = 0;
bool           pocLevelsActive = false;
double         gPocPrice, gLvnPrice, gExhPrice;

//--- ماژول ۱: Weekly Map — نام‌ها با پیشوند مستقل WMAP_
#define WMAP_PFX "WMAP_"
#define BTN_WMAP PFX+"Btn_WMAP"
bool     wmapVisible = false;
datetime g_lastWeekTime = 0;

//--- ماژول ۲: Session Opening Box — پیشوند مستقل SOB_
#define SOB_PFX "SOB_"
#define BTN_SOB  PFX+"Btn_SOB"
bool     sobVisible = false;
datetime sobLastBarTime = 0;

//--- ماژول ۲: NY Edge — پیشوند مستقل NYE_
#define NYE_PFX "NYE_"
#define BTN_NYE  PFX+"Btn_NYE"
bool     nyeVisible = false;
datetime nyeLastBarTime = 0;

//--- ماژول ۳: MTF Candle Preview — پیشوند مستقل MTFCP_
#define MTFCP_PFX "MTFCP_"
#define BTN_MTFCP PFX+"Btn_MTFCP"
bool     mtfcpVisible = false;
datetime mtfcpLastSourceBarTime = 0;
int      mtfcpPrevConnHighSegCount = 0;
int      mtfcpPrevConnLowSegCount  = 0;

//--- ماژول ۳: EMA Overlay — ۷ بافر واقعی + ۴ دکمه‌ی جدای هر خط (طبق
//--- خواسته‌ی Mahmoud) + یه دکمه‌ی master. ShowEMA10/20/60/240 دیگه فقط
//--- input نیستن - runtime قابل‌تغییرن (مثل بقیه‌ی toggle ها، پایدار با
//--- GlobalVariable)، ورودی‌های قبلی فقط مقدار پیش‌فرض اولین‌بار هستن.
#define BTN_EMA10    PFX+"Btn_EMA10"
#define BTN_EMA20    PFX+"Btn_EMA20"
#define BTN_EMA60    PFX+"Btn_EMA60"
#define BTN_EMA240   PFX+"Btn_EMA240"
bool gShowEMA10  = true;
bool gShowEMA20  = true;
bool gShowEMA60  = true;
bool gShowEMA240 = true;

//--- BUG-FIX (v1.02, Bug 3 follow-up): Mahmoud confirmed the v1.01 z-order
//--- bump fixed CLICK precedence but the panel can still render VISUALLY
//--- behind things drawn after it - because MT4 actually layers objects by
//--- CREATION ORDER, not OBJPROP_ZORDER (ZORDER is click-priority only in
//--- this build - the project already knew this; see the comment in
//--- CreateButtons() about why UpdateHubBackground() must run first). The
//--- real fix: whenever ANY object is created on the chart after the panel
//--- (a WMAP/NYE/MTFCP/POC redraw, the trader's own Draw-tool shapes, or
//--- anything else, present or future), delete-and-recreate every panel
//--- object so the panel becomes the most-recently-created stack again and
//--- renders on top. Hooked to CHARTEVENT_OBJECT_CREATE in OnChartEvent().
//--- NOTE: placed here (after all BTN_*/TOOL_COUNT_ITEMS/LABEL_COUNT
//--- #defines it references) rather than up near PANEL_ZORDER_* - #define
//--- macros need textual precedence before first use in MQL4, unlike
//--- functions/globals which support forward-references.
//+------------------------------------------------------------------+
//| Every object this function recreates has "Btn_" in its name (all
//| buttons - master, tool, label, indicator toggle - see their #defines)
//| except the background itself (HUB_BG_NAME). Anything else the Hub
//| creates (drawn rectangles/paths/lines/labels, their live drag previews)
//| uses a different naming pattern and must be treated as "external" -
//| i.e. it should trigger a raise, not be mistaken for an already-on-top
//| panel object. This distinction is also what prevents infinite recursion:
//| recreating panel objects here fires more OBJECT_CREATE events, but those
//| all resolve to true (panel-owned) and get skipped.
//+------------------------------------------------------------------+
bool IsHubPanelOwnedObject(string name)
{
   if(name == HUB_BG_NAME) return(true);
   if(StringFind(name, "Btn_") >= 0) return(true);
   if(name == THEME_ORIG_NAME) return(true);   // v1.17 (FEAT-052): ساخت آبجکت مخفیِ Original نباید raise پنل راه بیندازد
   return(false);
}

void RaiseHubPanelToFront()
{
   ObjectDelete(0, HUB_BG_NAME);
   ObjectDelete(0, BTN_MASTER_DRAW);
   ObjectDelete(0, BTN_MASTER_LABELS);
   ObjectDelete(0, BTN_MASTER_INDICATOR);
   ObjectDelete(0, BTN_MASTER_THEME);   // v1.17 (FEAT-052): فقط دکمه‌ها؛ آبجکت مخفیِ THEME_ORIG_NAME عمداً دست‌نخورده
   for(int ti = 0; ti < THEME_COUNT; ti++)
      ObjectDelete(0, Theme_BtnName(ti));
   ObjectDelete(0, BTN_THEME_ORIG);

   string toolNames[TOOL_COUNT_ITEMS] = {BTN_FA, BTN_FB, BTN_FC, BTN_FD, BTN_HA, BTN_HB, BTN_PATH, BTN_LINE, BTN_HLINE, BTN_DASH};
   for(int i = 0; i < TOOL_COUNT_ITEMS; i++)
      ObjectDelete(0, toolNames[i]);
   ObjectDelete(0, BTN_MEASURE);  // v1.14 (اصلاح): بیرون آرایه‌ی TOOL_COUNT_ITEMS، پس جدا حذف می‌شه

   for(int i = 0; i < LABEL_COUNT; i++)
      ObjectDelete(0, LabelButtonName(i));

   string indicatorBtns[9] = {BTN_POC, BTN_WMAP, BTN_SOB, BTN_NYE, BTN_MTFCP,
                               BTN_EMA10, BTN_EMA20, BTN_EMA60, BTN_EMA240};
   for(int i = 0; i < 9; i++)
      ObjectDelete(0, indicatorBtns[i]);

   //--- these already read current state (pocActive, wmapVisible, drawMode,
   //--- gDrawMinimized, ...) when (re)building each object, so colors,
   //--- text, and minimized/expanded state come back exactly as they were -
   //--- no separate "restore" step needed.
   RecomputeEffectiveSizes(); // v1.08, Item 2 - see OnInit()'s own call for why
   CreateButtons();
   CreateLabelButtons();
   PositionButtons();
   ApplyDrawMinimizedState();
   ApplyLabelsMinimizedState();
   ApplyIndicatorsMinimizedState();
   ApplyThemeMinimizedState();   // v1.17 (FEAT-052)
   //--- BUG-FIX (v1.07, lag): single redraw here now that the Apply*
   //--- functions no longer redraw themselves.
   ChartRedraw();
}

double Ema10Buffer[];
double Ema20Buffer[];
double Ema60Buffer[];
double Ema240Buffer[];
double Ema60BullBuffer[];
double Ema60BearBuffer[];
double Ema60NeutBuffer[];

//--- حالت‌های رسم
// v1.14 (اصلاح - انتقال از RiskManager EA v79): ابزار Measure Move (که قبلاً اشتباهاً توی پنل
// Utility ریسک‌منیجر با فرمت آبجکت‌های سفارشی/شید‌دار پیاده شده بود) درست‌جاش همینجاست - در
// پنل Draw هاب، کنار بقیه‌ی ابزارهای رسم دستی (Shade/Rectangle/Path/Line). MODE_MEASURE مثل
// MODE_LINE یک ابزار دو-کلیکی‌ست، ولی به‌جای یک خط تکی، ۷ خط + ۲ ناحیه‌ی شید‌دار (همون فرمت
// گرافیکی که قبلاً برای RM_Tools.mqh نوشته شده بود) رسم می‌کنه.
enum DRAW_MODE { MODE_NONE, MODE_FILL_A, MODE_FILL_B, MODE_FILL_C, MODE_FILL_D, MODE_HOLLOW_A, MODE_HOLLOW_B, MODE_PATH, MODE_LINE, MODE_MEASURE, MODE_HLINE, MODE_DASH };
DRAW_MODE drawMode = MODE_NONE;

enum CLICK_STATE { CLICK_IDLE, CLICK_WAIT_FIRST, CLICK_WAIT_SECOND };
CLICK_STATE clickState = CLICK_IDLE;
bool     skipNextClick = false;
datetime firstTime = 0;
double   firstPrice = 0;
int      firstPixelX = 0;
int      firstPixelY = 0;
bool     gShiftHeld = false;

bool     pathHasPoint  = false;
datetime pathTime      = 0;
double   pathPrice     = 0;
string   pathSessionId = "";
int      pathSegCounter = 0;
uint     g_lastClickMs = 0;
int      g_lastClickX  = -1000;
int      g_lastClickY  = -1000;

string   g_selectedPathPrefix = "";
bool     skipDeselectOnce     = false;

string   g_groupSnapNames[];
datetime g_groupSnapT1[];
double   g_groupSnapP1[];
datetime g_groupSnapT2[];
double   g_groupSnapP2[];

color gColorA, gColorB, gColorC, gColorD, gPathColor, gLineColor;
int   gWidth, gPathWidth, gLineWidth;
int   gStyle, gPathStyle, gLineStyle;
// v1.15 (revision): Horizontal Line و Dash Line هرکدام پیش‌فرض مستقل خودشان را دارند (رنگ/ضخامت/سبک) که با ویرایش
// آبجکت روی چارت عوض و ذخیره می‌شود - دقیقاً مثل Line و Path؛ ولی از پیش‌فرض Line جدا هستند.
color gHRayColor, gDashColor;
int   gHRayWidth, gDashWidth;
int   gHRayStyle, gDashStyle;
int   gCounter = 0;
bool  gDrawMinimized = false;

string armedLabel = "";
color  gLabelColor;
int    gLabelFontSize;
bool   gLabelsMinimized = false;

bool   gIndicatorsMinimized = false; // پایه‌ی هاب - ابزارهای زیرش در مراحل بعدی اضافه می‌شن
bool   gThemeMinimized = true;       // v1.17 (FEAT-052): کشوی Theme (چهارمین کشوی هم‌محل)
int    g_themeActive = -1;           // v1.17 (FEAT-052): اندیس تم فعال (0..6) یا -1 = هیچ (Original / ناشناخته)

//--- FEATURE (v1.01, Feature 4): auto-minimize idle tracking. Single "last
//--- Hub interaction" timestamp updated on ANY click on ANY Hub-owned object
//--- (identified by the PFX prefix shared by every Hub object name) - not a
//--- separate timer per category. Since only one of the three categories
//--- (Draw/Label/Indicator) can ever be expanded at a time (mutual exclusion,
//--- confirmed by Mahmoud), at most one auto-collapse ever fires per idle
//--- period. Hub-only - RiskManager EA's own RM_Dashboard.mqh panel is a
//--- completely separate file/prefix and is untouched by this.
datetime gHubLastInteraction = 0;
#define HUB_AUTO_MINIMIZE_IDLE_SECONDS 60

//--- BUG-FIX (v1.03): the v1.02 fix called RaiseHubPanelToFront() (which
//--- deletes/recreates ~40 panel objects) SYNCHRONOUSLY on every single
//--- CHARTEVENT_OBJECT_CREATE. During OnInit(), WMAP_DrawAll() and
//--- MTFCP_DrawAll() alone create dozens of objects (7 lines + 7 labels for
//--- Weekly Map, up to 2x MTFCP_CandleCount for the candle preview) - each
//--- one queues its own OBJECT_CREATE event, which fires right after
//--- OnInit() returns. A ~40-object burst turned into ~1,600 delete/recreate
//--- calls processed back-to-back right on attach - this is what caused the
//--- multi-second hang (and very likely the RiskManager EA panel corruption
//--- in the same screenshot, since MT4's chart-object churn shares the same
//--- UI thread across every indicator/EA on the chart).
//---
//--- Fix: debounce. OBJECT_CREATE just sets this flag; the existing
//--- 1-second OnTimer() does at most ONE raise per second, collapsing any
//--- burst (40 objects or 4) into a single RaiseHubPanelToFront() call. The
//--- panel may now take up to ~1s to reclaim the top layer after something
//--- new is drawn instead of being instant - a deliberate trade-off, since
//--- this is a purely cosmetic z-order concern and the previous "instant"
//--- version is what caused the hang.
bool g_hubNeedsRaise = false;

//+------------------------------------------------------------------+
int OnInit()
{
   EnsureHubLabelsSeed();  // v1.15: قبل از هر چیزی که LabelList رو می‌خونه (CreateLabelButtons، ...)

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
   // v1.15 (revision): اولین‌بار (قبل از هر ویرایشی) از پیش‌فرض‌های فعلی Line شروع می‌کنند؛ Dash: خط‌چین نازک
   gHRayColor = LoadPersistedColor("HRayColor", gLineColor);
   gHRayWidth = LoadPersistedInt("HRayWidth", gLineWidth);
   gHRayStyle = LoadPersistedInt("HRayStyle", STYLE_SOLID);
   gDashColor = LoadPersistedColor("DashColor", gLineColor);
   gDashWidth = LoadPersistedInt("DashWidth", 1);
   gDashStyle = LoadPersistedInt("DashStyle", STYLE_DASH);
   gDrawMinimized = LoadPersistedBool("DrawMinimized");

   gLabelColor      = LoadPersistedLabelColor();
   gLabelFontSize   = LoadPersistedInt("LabelFontSize", LabelDefaultFontSize);
   gLabelsMinimized = LoadPersistedBool("LabelsMinimized");

   gIndicatorsMinimized = LoadPersistedBool("IndicatorsMinimized");
   gThemeMinimized      = LoadPersistedBool("ThemeMinimized");   // v1.17 (FEAT-052)

   // اولین‌بار (بدون هیچ کلید ذخیره‌شده‌ای)، هر سه کشو جمع‌شده باشن - چون
   // حالا هم‌محلن (mutual exclusion)، بازبودن هرسه‌تاشون هم‌زمان روی هم
   // می‌افتاد و شلوغ می‌شد
   if(!GlobalVariableCheck(PFX + "DrawMinimized_" + Symbol()))       gDrawMinimized = true;
   if(!GlobalVariableCheck(PFX + "LabelsMinimized_" + Symbol()))     gLabelsMinimized = true;
   if(!GlobalVariableCheck(PFX + "IndicatorsMinimized_" + Symbol())) gIndicatorsMinimized = true;
   if(!GlobalVariableCheck(PFX + "ThemeMinimized_" + Symbol()))      gThemeMinimized = true;   // v1.17 (FEAT-052)
   //--- v1.17 (FEAT-052): فقط برای هایلایت دکمه‌ها - اگر رنگ فعلی چارت دقیقاً یکی از ۷ تم باشد همان فعال نشان داده می‌شود.
   //--- (یک‌بار در شروع؛ هیچ اعمال مجددی روی چارت انجام نمی‌شود.)
   g_themeActive = Theme_DetectActive();

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
   ApplyThemeMinimizedState();   // v1.17 (FEAT-052)
   ChartRedraw();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   //--- BUG-FIX (v1.02): needed so OnChartEvent actually receives
   //--- CHARTEVENT_OBJECT_CREATE - see RaiseHubPanelToFront().
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
      gPocPrice = ObjectGet(POC_LINE_POC, OBJPROP_PRICE1);
      gLvnPrice = ObjectGet(POC_LINE_LVN, OBJPROP_PRICE1);
      gExhPrice = ObjectGet(POC_LINE_EXH, OBJPROP_PRICE1);
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

   SetIndexBuffer(0, Ema10Buffer);
   SetIndexBuffer(1, Ema20Buffer);
   SetIndexBuffer(2, Ema60Buffer);
   SetIndexBuffer(3, Ema240Buffer);
   SetIndexBuffer(4, Ema60BullBuffer);
   SetIndexBuffer(5, Ema60BearBuffer);
   SetIndexBuffer(6, Ema60NeutBuffer);
   for(int b3 = 0; b3 < 7; b3++)
      SetIndexEmptyValue(b3, EMPTY_VALUE);

   EMA_ApplyIndexStyles();
   SetEMAButtonColors();

   if(EMA_DisplayMode == Mode_ActiveCloud)
   {
      SetIndexLabel(0, "EMA " + IntegerToString(EMA2_Period));
      SetIndexLabel(1, "EMA " + IntegerToString(EMA3_Period));
      SetIndexLabel(2, "EMA " + IntegerToString(EMA4_Period));
      SetIndexLabel(3, NULL); SetIndexLabel(4, NULL); SetIndexLabel(5, NULL); SetIndexLabel(6, NULL);
   }
   else if(EMA_DisplayMode == Mode_MomentumColor)
   {
      SetIndexLabel(0, "EMA " + IntegerToString(EMA1_Period));
      SetIndexLabel(1, "EMA " + IntegerToString(EMA2_Period));
      SetIndexLabel(2, NULL);
      SetIndexLabel(3, "EMA " + IntegerToString(EMA4_Period));
      SetIndexLabel(4, "EMA " + IntegerToString(EMA3_Period) + " (Bullish)");
      SetIndexLabel(5, "EMA " + IntegerToString(EMA3_Period) + " (Bearish)");
      SetIndexLabel(6, "EMA " + IntegerToString(EMA3_Period) + " (Neutral)");
   }
   else
   {
      SetIndexLabel(0, "EMA " + IntegerToString(EMA1_Period));
      SetIndexLabel(1, "EMA " + IntegerToString(EMA2_Period));
      SetIndexLabel(2, "EMA " + IntegerToString(EMA3_Period));
      SetIndexLabel(3, "EMA " + IntegerToString(EMA4_Period));
      SetIndexLabel(4, NULL); SetIndexLabel(5, NULL); SetIndexLabel(6, NULL);
   }
   EMA_ApplyGrayscaleColors();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, BTN_FA);
   ObjectDelete(0, BTN_FB);
   ObjectDelete(0, BTN_FC);
   ObjectDelete(0, BTN_FD);
   ObjectDelete(0, BTN_HA);
   ObjectDelete(0, BTN_HB);
   ObjectDelete(0, BTN_PATH);
   ObjectDelete(0, BTN_LINE);
   ObjectDelete(0, BTN_HLINE);  // v1.15
   ObjectDelete(0, BTN_DASH);   // v1.15
   ObjectDelete(0, BTN_MEASURE);  // v1.14 (اصلاح)
   RemoveMeasureTool(MEASURE_PREVIEW_NAME);  // v1.14 (اصلاح): پیش‌نمایش شاید نیمه‌کاره باز مونده باشه
   ObjectDelete(0, BTN_MASTER_DRAW);
   ObjectDelete(0, PREVIEW_NAME);
   ObjectDelete(0, PATH_PREVIEW_NAME);
   ObjectDelete(0, LINE_PREVIEW_NAME);
   ObjectDelete(0, BTN_MASTER_LABELS);
   ObjectDelete(0, LABEL_PREVIEW_NAME);
   for(int i = 0; i < LABEL_COUNT; i++)
      ObjectDelete(0, LabelButtonName(i));
   ObjectDelete(0, BTN_MASTER_INDICATOR);
   //--- v1.17 (FEAT-052): فقط دکمه‌های Theme پاک می‌شوند. آبجکت مخفیِ THEME_ORIG_NAME (رنگ‌های Original) عمداً پاک
   //--- نمی‌شود - نه روی تغییر تایم‌فریم/ری‌لود، نه روی حذف Hub (تا با نصب دوباره‌ی Hub دکمه‌ی Original هنوز کار کند).
   ObjectDelete(0, BTN_MASTER_THEME);
   for(int ti = 0; ti < THEME_COUNT; ti++)
      ObjectDelete(0, Theme_BtnName(ti));
   ObjectDelete(0, BTN_THEME_ORIG);
   ObjectDelete(0, HUB_BG_NAME);

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
      // v1.15: redraw also when price ran past the last drawn level (WMAP_RefreshExtras detects new steps)
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

void OnTimer()
{
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
      else if(!gThemeMinimized)   // v1.17 (FEAT-052)
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
//| اگه پس‌زمینه‌ی داشبورد (اولین ابجکتی که می‌سازیم، همیشه باید وجود        |
//| داشته باشه) پیدا نشه - یعنی یه "Delete All Objects" دستی همه‌چیز رو    |
//| پاک کرده - کل پنل (دکمه‌ها + پس‌زمینه) از نو ساخته می‌شه.                |
//+------------------------------------------------------------------+
void CheckHubIntegrity()
{
   if(ObjectFind(0, HUB_BG_NAME) < 0)
   {
      CreateButtons();
      CreateLabelButtons();
      PositionButtons();
      ApplyDrawMinimizedState();
      ApplyLabelsMinimizedState();
      ApplyIndicatorsMinimizedState();
      ApplyThemeMinimizedState();   // v1.17 (FEAT-052)
      ChartRedraw();
   }
}


//+------------------------------------------------------------------+
color LoadPersistedColor(string key, color fallback)
{
   string gvName = PFX + key + "_" + Symbol();
   if(GlobalVariableCheck(gvName))
      return((color)(int)GlobalVariableGet(gvName));
   return(fallback);
}

void SavePersistedColor(string key, color value)
{
   string gvName = PFX + key + "_" + Symbol();
   GlobalVariableSet(gvName, (double)(int)value);
}

int LoadPersistedInt(string key, int fallback)
{
   string gvName = PFX + key + "_" + Symbol();
   if(GlobalVariableCheck(gvName))
      return((int)GlobalVariableGet(gvName));
   return(fallback);
}

void SavePersistedInt(string key, int value)
{
   string gvName = PFX + key + "_" + Symbol();
   GlobalVariableSet(gvName, (double)value);
}

bool LoadPersistedBool(string key)
{
   string gvName = PFX + key + "_" + Symbol();
   if(GlobalVariableCheck(gvName))
      return(GlobalVariableGet(gvName) != 0);
   return(false);
}

void SavePersistedBool(string key, bool value)
{
   string gvName = PFX + key + "_" + Symbol();
   GlobalVariableSet(gvName, value ? 1.0 : 0.0);
}

//+------------------------------------------------------------------+
color ComputeContrastGray()
{
   long bg = (long)Hub_ChartBg();   // v1.17 (FEAT-052): override-aware
   int r = (int)(bg & 0xFF);
   int g = (int)((bg >> 8) & 0xFF);
   int b = (int)((bg >> 16) & 0xFF);
   double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
   if(luminance < 128)
      return(clrSilver);
   return(clrDimGray);
}

color LoadPersistedLabelColor()
{
   string gvName = PFX + "LabelColor_" + Symbol();
   if(GlobalVariableCheck(gvName))
      return((color)(int)GlobalVariableGet(gvName));
   color auto_ = ComputeContrastGray();
   return(auto_ != 0 ? auto_ : LabelDefaultColor);
}

//+------------------------------------------------------------------+
//| ماژول ۱ - POC: پایداری وضعیت روشن/خاموش (کلید عیناً همون کلید نسخه‌ی  |
//| مستقل قبلی، تا تنظیمات ذخیره‌شده‌ی Mahmoud از دست نره)                |
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
   ObjectSetInteger(0, BTN_POC, OBJPROP_BGCOLOR, active ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
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
   clr = Theme_ContrastSafe(clr);   // v1.17 (FEAT-052)
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
   clr = Theme_ContrastSafe(clr);   // v1.17 (FEAT-052)
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
      ObjectSetInteger(0, POC_TRACK_VLINE, OBJPROP_COLOR, Theme_ContrastSafe(clrSilver));   // v1.17 (FEAT-052)
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
      ObjectSetInteger(0, POC_TRACK_LABEL, OBJPROP_COLOR, Theme_ContrastSafe(clrYellow));   // v1.17 (FEAT-052)
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
   ObjectSetInteger(0, BTN_WMAP, OBJPROP_BGCOLOR, wmapVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

int WMAP_PriceToPixelY(double price)
{
   int x = 0, y = 0;
   ChartTimePriceToXY(0, 0, Time[0], price, x, y);
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
   long bg = (long)Hub_ChartBg();   // v1.17 (FEAT-052): override-aware
   int r = (int)(bg & 0xFF);
   int g = (int)((bg >> 8) & 0xFF);
   int b = (int)((bg >> 16) & 0xFF);
   double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
   if(luminance < 140)
      return(Theme_ContrastSafe(forDarkBg));   // v1.17 (FEAT-052): روی تم‌های بینابینی (مثلاً ۱۶۹ و ۱۹۲) هم خوانا بماند
   return(Theme_ContrastSafe(forLightBg));
}

// v1.15: سطوح ادامه‌دار. گام = (WH-WL)/4 (همان ۲۵٪ رنج). هر وقت قیمت از بالاترین/پایین‌ترین سطح رسم‌شده عبور کنه،
// یک گام دیگه در همان جهت اضافه می‌شه (تکرارشونده) تا همیشه یک خط جلوی قیمت باشه. g_wmapKUp/g_wmapKDown = تعداد گام‌های
// بالای WH و پایین WL که الان رسم شده (حداقل ۱ = همان WH+25% / WL-25% قبلی). قیمت مرجع = بیشینه/کمینه‌ی هفته‌ی جاری
// (ویک‌ها هم) و Bid؛ پس بعد از برگشت قیمت، سطوح اضافه‌شده می‌مونن. سقف WMAP_MAX_EXTRA_STEPS برای هر طرف (محافظ).
#define WMAP_MAX_EXTRA_STEPS 40
int g_wmapKUp   = 1;
int g_wmapKDown = 1;

// true اگه تعداد گام‌ها نسبت به آخرین رسم تغییر کرده (و globalها رو به‌روز می‌کنه)
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
      double pMax = Bid, pMin = Bid;
      if(shift >= 1)   // هفته‌ی جاری از آخرین هفته‌ی بسته‌شده جداست -> ویک‌هاش هم حساب می‌شه
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

   // v1.15: ایندکس 7.. = ادامه‌ها (اول گام‌های بالا، بعد گام‌های پایین)؛ همه هم‌رنگ و هم‌دسته با WH+25%/WL-25%
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
   WMAP_RefreshExtras();   // v1.15: تعداد گام‌های ادامه‌دار رو قبل از ساخت لیست سطوح به‌روز کن
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

   // v1.15: اگه تعداد سطوح کم شده (مثلاً هفته‌ی جدید)، آبجکت‌های اضافه‌ی قبلی حذف بشن
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

   int nLevelsU = ArraySize(prices);
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
//| موتورِ تایم‌زون (DST / NY->UTC->server) به ماژولِ مشترکِ            |
//| RM_SessionTime.mqh منتقل شد (بازنویسیِ Session Tools).            |
//| توابعِ IsUSDST/GetNYDate/ComputeServerTime + کشِ آفستِ static اینجا |
//| حذف و با ST_* در آن ماژول جایگزین شدند - همان یک منبع که EA هم      |
//| استفاده می‌کند. آفستِ سرور حالا پایدار است (کالیبره از تیکِ تازه +   |
//| ذخیره در GlobalVariable)، پس سوییچِ تایم‌فریم (ری‌لودِ اندیکاتور) و   |
//| سکوتِ تیک/آخرِ هفته دیگر باکس را جابه‌جا نمی‌کنند.                    |
//| فراخوانی: ST_ComputeSessionByDaysAgo(daysAgo, sh,sm,eh,em, t1,t2)  |
//| (امضای هم‌شکلِ ComputeServerTimeِ قبلی).                            |
//+------------------------------------------------------------------+


int ParseHHMM(string hhmm)
{
   string parts[];
   int n = StringSplit(hhmm, ':', parts);
   if(n < 2) return(0);
   return((int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]));
}

//+------------------------------------------------------------------+
//| ماژول ۲ - Session Opening Box                                     |
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
   ObjectSetInteger(0, BTN_SOB, OBJPROP_BGCOLOR, sobVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

void SOB_Recalculate()
{
   ObjectsDeleteAll(0, SOB_PFX);
   int days = SOB_CurrentDayOnly ? 2 : MathMax(1, SOB_ShowLastXDays);

   if(SOB_EnableTokyo)   SOB_ProcessSession("Tokyo",   SOB_TokyoStart,   SOB_TokyoEnd,   SOB_TokyoColor,   days);
   if(SOB_EnableLondon)  SOB_ProcessSession("London",  SOB_LondonStart,  SOB_LondonEnd,  SOB_LondonColor,  days);
   if(SOB_EnableNewYork) SOB_ProcessSession("NewYork", SOB_NewYorkStart, SOB_NewYorkEnd, SOB_NewYorkColor, days);

   // v1.10 (فیکس - تحقیق «باکس SOB چند کندل جامونده»، ۲۰۲۶-۰۸-۰۸): این تابع تنها ماژولی بود که
   // طبق قاعده‌ی v1.07 («هر ماژول باید دقیقاً یه ChartRedraw() در انتهای منطق خودش داشته باشه»)
   // این خط رو نداشت. داده‌ی داخلی (boxStart/boxEnd) همیشه درست به‌روز می‌شد (تأیید‌شده با
   // build تشخیصی)، ولی بدون این خط، نمایش گاهی تا محرک بعدی (zoom/toggle) رفرش نمی‌شد.
   ChartRedraw();
}

void SOB_ProcessSession(string sessionName, string startStr, string endStr, color col, int days)
{
   col = Theme_ContrastSafe(col);   // v1.17 (FEAT-052): رنگ ثابتِ ورودی (مثلاً زرد) روی تم‌های روشن خوانا بماند
   int startMin = ParseHHMM(startStr);
   int endMin   = ParseHHMM(endStr);
   int sh = startMin / 60, sm = startMin % 60;
   int eh = endMin / 60,   em = endMin % 60;

   for(int d = 0; d < days; d++)
   {
      datetime boxStart, boxEnd;
      ST_ComputeSessionByDaysAgo(d, sh, sm, eh, em, boxStart, boxEnd);
      SOB_ProcessOneDay(sessionName, boxStart, boxEnd, col, d);
   }
}

void SOB_ProcessOneDay(string sessionName, datetime boxStart, datetime boxEnd, color col, int dayIndex)
{
   int shiftStart = iBarShift(Symbol(), SOB_BaseTimeframe, boxStart, false);
   int shiftEnd   = iBarShift(Symbol(), SOB_BaseTimeframe, boxEnd, false);
   if(shiftStart < 0 || shiftEnd < 0) return;
   if(shiftStart <= shiftEnd) return;

   // v1.12 (فیکس - حسابِ واقعیِ XChief): آفست تأیید شد پایدار است (10800 روی هر TF)، پس علتِ
   // تغییرِ اندازه با تایم‌فریم این بود: وقتی چارت روی TFِ بالاتر از base (M5) است، تاریخچه‌ی M5
   // ممکن است به‌قدرِ کافی عقب لود نشده باشد؛ آن‌وقت iBarShift/iHigh/iLow دیتای ناقص می‌دهند و
   // High/Low به TFِ چارت وابسته می‌شود. گارد: اگر قدیمی‌ترین کندلِ M5ِ لودشده هنوز شروعِ باکس را
   // نمی‌پوشاند، این دور را رد کن - همین دسترسی MT4 را وادار به بک‌فیلِ M5 می‌کند و دورِ بعد از
   // دیتای کامل رسم می‌شود (مستقل از TFِ چارت).
   int baseBars = iBars(Symbol(), SOB_BaseTimeframe);
   if(baseBars <= 0) return;
   if(iTime(Symbol(), SOB_BaseTimeframe, baseBars - 1) > boxStart) return;  // M5 history not deep enough yet

   double boxHigh = -1, boxLow = -1;
   for(int i = shiftEnd; i <= shiftStart; i++)
   {
      double h = iHigh(Symbol(), SOB_BaseTimeframe, i);
      double l = iLow(Symbol(), SOB_BaseTimeframe, i);
      if(boxHigh < 0 || h > boxHigh) boxHigh = h;
      if(boxLow  < 0 || l < boxLow)  boxLow  = l;
   }
   if(boxHigh <= boxLow) return;

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

   if(!SOB_ShowProjectionLevels) return;

   int breakoutShift = -1;
   int direction = 0;
   for(int i = shiftEnd - 1; i >= dayEndShift; i--)
   {
      double c = iClose(Symbol(), SOB_BaseTimeframe, i);
      if(c > boxHigh) { breakoutShift = i; direction = 1; }
      if(c < boxLow)  { breakoutShift = i; direction = -1; }
   }
   if(breakoutShift < 0) return;

   datetime breakoutTime = iTime(Symbol(), SOB_BaseTimeframe, breakoutShift);
   double boxSize = boxHigh - boxLow;

   for(int lvl = 1; lvl <= SOB_ProjectionLevels; lvl++)
   {
      double price = (direction > 0) ? (boxHigh + lvl * boxSize) : (boxLow - lvl * boxSize);
      SOB_DrawProjectionLine(tag, lvl, breakoutTime, dayEnd, price, col);
   }
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
//| ماژول ۲ - NY Edge                                                 |
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
   ObjectSetInteger(0, BTN_NYE, OBJPROP_BGCOLOR, nyeVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
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
   for(int daysAgo = -1; daysAgo <= 5; daysAgo++)
   {
      datetime boxStart, boxEnd;
      ST_ComputeSessionByDaysAgo(daysAgo, sh, sm, eh, em, boxStart, boxEnd);
      if(NYE_DrawEdge(boxStart, boxEnd, nyeLastBarTime, NYE_EdgeColor))
         break;
   }
}

bool NYE_DrawEdge(datetime boxStart, datetime boxEnd, datetime lineEnd, color col)
{
   col = Theme_ContrastSafe(col);   // v1.17 (FEAT-052)
   int shiftStart = iBarShift(Symbol(), NYE_BaseTimeframe, boxStart, false);
   int shiftEnd   = iBarShift(Symbol(), NYE_BaseTimeframe, boxEnd, false);
   if(shiftStart < 0 || shiftEnd < 0) return(false);
   if(shiftStart <= shiftEnd) return(false);

   // v1.12 (فیکس - همان گاردِ SOB): اگر تاریخچه‌ی base timeframe هنوز شروعِ باکس را نمی‌پوشاند،
   // رسم نکن (وگرنه High/Low از دیتای ناقصِ M5 می‌آید و با TFِ چارت عوض می‌شود).
   int baseBars = iBars(Symbol(), NYE_BaseTimeframe);
   if(baseBars <= 0) return(false);
   if(iTime(Symbol(), NYE_BaseTimeframe, baseBars - 1) > boxStart) return(false);

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
//| ماژول ۳ - MTF Candle Preview (عیناً از نسخه‌ی مستقل، فقط پیشوند       |
//| MTFCP_ روی هر تابع/متغیر عمومی اضافه شده تا با بقیه‌ی هاب تداخل نکنه) |
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
   ObjectSetInteger(0, BTN_MTFCP, OBJPROP_BGCOLOR, mtfcpVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

color MTFCP_ContrastSafeColor(color c)
{
   if(!MTFCP_EnsureContrast) return(c);

   long bg = (long)Hub_ChartBg();   // v1.17 (FEAT-052): override-aware
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
   color c = (MTFCP_BullColorInp != clrNONE) ? MTFCP_BullColorInp : Hub_ChartBull();   // v1.17 (FEAT-052): override-aware
   return(MTFCP_ContrastSafeColor(c));
}

color MTFCP_BearColor()
{
   color c = (MTFCP_BearColorInp != clrNONE) ? MTFCP_BearColorInp : Hub_ChartBear();   // v1.17 (FEAT-052): override-aware
   return(MTFCP_ContrastSafeColor(c));
}

color MTFCP_LabelColor()
{
   color c = (MTFCP_LabelColorInp != clrNONE) ? MTFCP_LabelColorInp : Hub_ChartFg();   // v1.17 (FEAT-052): override-aware
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
   ChartTimePriceToXY(0, 0, t, Bid, x, y);
   return(x);
}

int MTFCP_PriceToPixelY(double price)
{
   int x = 0, y = 0;
   ChartTimePriceToXY(0, 0, Time[0], price, x, y);
   return(y);
}

int MTFCP_OriginX()
{
   int chartSec = PeriodSeconds(Period());
   if(chartSec <= 0) chartSec = 60;
   datetime originTime = Time[0] + chartSec;
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
      double tick = MarketInfo(Symbol(), MODE_POINT);
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
   double topPrice = MTFCP_HighestVisibleHigh() + (MarketInfo(Symbol(), MODE_POINT) * 200);
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
   double bottomPrice = MTFCP_LowestVisibleLow() - (MarketInfo(Symbol(), MODE_POINT) * 200);
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
      txt += "i=" + IntegerToString(i) + " shift=" + IntegerToString(shift)
           + " O=" + DoubleToString(o, Digits) + " H=" + DoubleToString(h, Digits)
           + " L=" + DoubleToString(l, Digits) + " C=" + DoubleToString(c, Digits) + "\n";
   }
   Comment(txt);
}

//+------------------------------------------------------------------+
//| ماژول ۳ - EMA Overlay (عیناً از نسخه‌ی مستقل v3.22)                  |
//+------------------------------------------------------------------+
void SetEMAButtonColors()
{
   ObjectSetInteger(0, BTN_EMA10,  OBJPROP_BGCOLOR, gShowEMA10  ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   ObjectSetInteger(0, BTN_EMA20,  OBJPROP_BGCOLOR, gShowEMA20  ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   ObjectSetInteger(0, BTN_EMA60,  OBJPROP_BGCOLOR, gShowEMA60  ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   ObjectSetInteger(0, BTN_EMA240, OBJPROP_BGCOLOR, gShowEMA240 ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

//+------------------------------------------------------------------+
//| v3.20 منطق: EMA20/EMA60 توی Mode_ActiveCloud یه ابر جفتی تشکیل      |
//| می‌دن (DRAW_HISTOGRAM به هر دو بافر نیاز داره)، پس نمی‌شه جدا مخفیشون |
//| کرد؛ توی Mode_MomentumColor هم مخفی‌کردن EMA60 هر سه سگمنت رنگی رو    |
//| باهم مخفی می‌کنه. این‌ها محدودیت‌های ذاتی خودِ حالت‌هان، نه باگ.        |
//+------------------------------------------------------------------+
void EMA_ApplyIndexStyles()
{
   if(EMA_DisplayMode == Mode_ActiveCloud)
   {
      bool showCloud = (gShowEMA20 && gShowEMA60);
      SetIndexStyle(0, showCloud ? DRAW_HISTOGRAM : DRAW_NONE, STYLE_SOLID, 0);
      SetIndexStyle(1, showCloud ? DRAW_HISTOGRAM : DRAW_NONE, STYLE_SOLID, 0);
      SetIndexStyle(2, gShowEMA240 ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 2);
      SetIndexStyle(3, DRAW_NONE);
      SetIndexStyle(4, DRAW_NONE);
      SetIndexStyle(5, DRAW_NONE);
      SetIndexStyle(6, DRAW_NONE);
   }
   else if(EMA_DisplayMode == Mode_MomentumColor)
   {
      SetIndexStyle(0, gShowEMA10 ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 1);
      SetIndexStyle(1, gShowEMA20 ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 1);
      SetIndexStyle(2, DRAW_NONE);
      SetIndexStyle(3, gShowEMA240 ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 2);
      SetIndexStyle(4, gShowEMA60 ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 2);
      SetIndexStyle(5, gShowEMA60 ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 2);
      SetIndexStyle(6, gShowEMA60 ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 2);
   }
   else
   {
      SetIndexStyle(0, gShowEMA10  ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 1);
      SetIndexStyle(1, gShowEMA20  ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 2);
      SetIndexStyle(2, gShowEMA60  ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 3);
      SetIndexStyle(3, gShowEMA240 ? DRAW_LINE : DRAW_NONE, STYLE_SOLID, 4);
      SetIndexStyle(4, DRAW_NONE);
      SetIndexStyle(5, DRAW_NONE);
      SetIndexStyle(6, DRAW_NONE);
   }
}

void EMA_ApplyGrayscaleColors()
{
   color bg = Hub_ChartBg();   // v1.17 (FEAT-052): override-aware
   int r = (int)(bg & 0xFF);
   int g = (int)((bg >> 8) & 0xFF);
   int b = (int)((bg >> 16) & 0xFF);
   double luminance = (r * 0.299) + (g * 0.587) + (b * 0.114);
   bool isDark = (luminance < 128);

   //--- v1.17 (FEAT-052): همه‌ی رنگ‌های خطوط از Theme_ContrastSafe رد می‌شوند - فقط وقتی کنتراست با پس‌زمینه کمتر از ۴۵
   //--- باشد (مثلاً خاکستری ۱۵۰ روی پس‌زمینه‌ی ۱۶۹) جابه‌جا می‌شوند؛ در بقیه‌ی حالت‌ها رنگ دقیقاً همان قبلی است.
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

   if(EMA_DisplayMode == Mode_FourLines)
   {
      for(int shift = limit; shift >= 0; shift--)
      {
         Ema10Buffer[shift]  = iMA(NULL, 0, EMA1_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
         Ema20Buffer[shift]  = iMA(NULL, 0, EMA2_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
         Ema60Buffer[shift]  = iMA(NULL, 0, EMA3_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
         Ema240Buffer[shift] = iMA(NULL, 0, EMA4_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
      }
      return;
   }

   if(EMA_DisplayMode == Mode_ActiveCloud)
   {
      for(int shift = limit; shift >= 0; shift--)
      {
         Ema10Buffer[shift]  = iMA(NULL, 0, EMA2_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
         Ema20Buffer[shift]  = iMA(NULL, 0, EMA3_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
         Ema60Buffer[shift]  = iMA(NULL, 0, EMA4_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
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
      double ema10  = iMA(NULL, 0, EMA1_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
      double ema20  = iMA(NULL, 0, EMA2_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
      double ema60  = iMA(NULL, 0, EMA3_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
      double ema240 = iMA(NULL, 0, EMA4_Period, 0, MODE_EMA, PRICE_CLOSE, shift);
      double atr14  = iATR(NULL, 0, 14, shift);
      double closeP = iClose(NULL, 0, shift);
      double highP  = iHigh(NULL, 0, shift);
      double lowP   = iLow(NULL, 0, shift);

      int idxHH15_1 = iHighest(NULL, 0, MODE_HIGH, 15, shift + 1);
      int idxHH15_2 = iHighest(NULL, 0, MODE_HIGH, 15, shift + 2);
      int idxHH30_1 = iHighest(NULL, 0, MODE_HIGH, 30, shift + 1);
      int idxHH30_2 = iHighest(NULL, 0, MODE_HIGH, 30, shift + 2);
      double hh15_1 = (idxHH15_1 >= 0) ? iHigh(NULL, 0, idxHH15_1) : highP;
      double hh15_2 = (idxHH15_2 >= 0) ? iHigh(NULL, 0, idxHH15_2) : highP;
      double hh30_1 = (idxHH30_1 >= 0) ? iHigh(NULL, 0, idxHH30_1) : highP;
      double hh30_2 = (idxHH30_2 >= 0) ? iHigh(NULL, 0, idxHH30_2) : highP;
      double prevHigh = iHigh(NULL, 0, shift + 1);

      bool crossHigh15 = (highP > hh15_1) && (prevHigh <= hh15_2);
      bool crossHigh30 = (highP > hh30_1) && (prevHigh <= hh30_2);
      bool newSwingHigh = crossHigh15 || crossHigh30;
      bool gapOkHigh = (workHigh <= 0) || (MathAbs(highP - workHigh) > closeP * EMA_Mode3_GapFilter);
      if(newSwingHigh && gapOkHigh)
         workHigh = highP;

      int idxLL15_1 = iLowest(NULL, 0, MODE_LOW, 15, shift + 1);
      int idxLL15_2 = iLowest(NULL, 0, MODE_LOW, 15, shift + 2);
      int idxLL30_1 = iLowest(NULL, 0, MODE_LOW, 30, shift + 1);
      int idxLL30_2 = iLowest(NULL, 0, MODE_LOW, 30, shift + 2);
      double ll15_1 = (idxLL15_1 >= 0) ? iLow(NULL, 0, idxLL15_1) : lowP;
      double ll15_2 = (idxLL15_2 >= 0) ? iLow(NULL, 0, idxLL15_2) : lowP;
      double ll30_1 = (idxLL30_1 >= 0) ? iLow(NULL, 0, idxLL30_1) : lowP;
      double ll30_2 = (idxLL30_2 >= 0) ? iLow(NULL, 0, idxLL30_2) : lowP;
      double prevLow = iLow(NULL, 0, shift + 1);

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

//+------------------------------------------------------------------+
void CreateButtons()
{
   // باید همین اول ساخته بشه، قبل از هر دکمه‌ای - چون MT4 آبجکت‌ها رو بر
   // اساس ترتیب ساخت روی هم می‌کشه (نه OBJPROP_ZORDER که فقط اولویت کلیکه)،
   // پس اگه این بعد از دکمه‌ها ساخته/آپدیت بشه، روی دکمه‌ها می‌شینه و
   // قایمشون می‌کنه - دقیقاً همون باگی که Mahmoud گزارش داد.
   UpdateHubBackground();

   CreateOneButton(BTN_FA, "Shade 1", gColorA);
   CreateOneButton(BTN_FB, "Shade 2", gColorB);
   CreateOneButton(BTN_FC, "Shade 3", gColorC);
   CreateOneButton(BTN_FD, "Shade 4", gColorD);
   CreateOneButton(BTN_HA, "Rectangle 1", gColorA);
   CreateOneButton(BTN_HB, "Rectangle 2", gColorB);
   CreateOneButton(BTN_PATH, "Path", gPathColor);
   CreateOneButton(BTN_LINE, "Line", gLineColor);
   CreateOneButton(BTN_HLINE, "Horizontal Line", gHRayColor);  // v1.15
   ObjectSetInteger(0, BTN_HLINE, OBJPROP_FONTSIZE, 6);         // متن بلندتره؛ با فونت ۷ روی عرض‌های کوچک‌شده می‌زنه بیرون
   CreateOneButton(BTN_DASH, "Dash Line", gDashColor);          // v1.15
   // v1.14 (اصلاح): دکمه‌ی Measure - توگل‌مانند (خاکستری=غیرفعال/فیروزه‌ای=مسلح)، نه رنگ‌محور
   // مثل بقیه‌ی ابزارهای رسم (چون رنگش قابل‌تنظیم توسط کاربر نیست) - رنگ اولیه توسط
   // HighlightActiveButton(drawMode) پایین‌تر همین تابع ست می‌شه.
   CreateOneButton(BTN_MEASURE, "RANGE", CLR_INACTIVE_GRAY);
   HighlightActiveButton(drawMode); // اول کم‌رنگ کردن همه (drawMode اولش MODE_NONE هست)

   //--- ماژول ۱ - دکمه‌های اندیکاتور (POC، Weekly Map)
   CreateOneButton(BTN_POC, "POC", pocActive ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   CreateOneButton(BTN_WMAP, "WMAP", wmapVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);

   //--- ماژول ۲ - دکمه‌های اندیکاتور (Session Opening Box، NY Edge)
   CreateOneButton(BTN_SOB, "SOB", sobVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   CreateOneButton(BTN_NYE, "NY-EDGE", nyeVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);

   //--- ماژول ۳ - دکمه‌های اندیکاتور (MTF Candle Preview، EMA master + ۴ خط جدا)
   CreateOneButton(BTN_MTFCP, "MTFCP", mtfcpVisible ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   CreateOneButton(BTN_EMA10, "EMA10", gShowEMA10 ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   CreateOneButton(BTN_EMA20, "EMA20", gShowEMA20 ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   CreateOneButton(BTN_EMA60, "EMA60", gShowEMA60 ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
   CreateOneButton(BTN_EMA240, "EMA240", gShowEMA240 ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);

   if(ObjectFind(0, BTN_MASTER_DRAW) < 0)
   {
      ObjectCreate(0, BTN_MASTER_DRAW, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_XSIZE, g_effMasterBtnWidth);
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_YSIZE, BtnHeight);
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_BGCOLOR, clrSeaGreen);
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_ZORDER, PANEL_ZORDER_FG);
   }

   if(ObjectFind(0, BTN_MASTER_LABELS) < 0)
   {
      ObjectCreate(0, BTN_MASTER_LABELS, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_XSIZE, g_effMasterBtnWidth);
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_YSIZE, BtnHeight);
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_BGCOLOR, clrSeaGreen);
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_ZORDER, PANEL_ZORDER_FG);
   }

   if(ObjectFind(0, BTN_MASTER_INDICATOR) < 0)
   {
      ObjectCreate(0, BTN_MASTER_INDICATOR, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_XSIZE, g_effMasterBtnWidth);
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_YSIZE, BtnHeight);
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_BGCOLOR, clrSeaGreen);
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_ZORDER, PANEL_ZORDER_FG);
   }

   Theme_CreateButtons();   // v1.17 (FEAT-052): دکمه‌ی مادر چهارم + کشوی Theme
}

void ApplyDrawMinimizedState()
{
   if(gDrawMinimized) CancelDrawing();

   long tf = gDrawMinimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
   string names[TOOL_COUNT_ITEMS] = {BTN_FA, BTN_FB, BTN_FC, BTN_FD, BTN_HA, BTN_HB, BTN_PATH, BTN_LINE, BTN_HLINE, BTN_DASH};
   for(int i = 0; i < TOOL_COUNT_ITEMS; i++)
      ObjectSetInteger(0, names[i], OBJPROP_TIMEFRAMES, tf);
   // v1.14 (اصلاح): BTN_MEASURE عمداً بیرون آرایه‌ی TOOL_COUNT_ITEMS/گرید موند (تا چیدمان گرید
   // اصلی دست‌نخورده بمونه - فضای خالی زیر دکمه‌های مادر) ولی باید همون رفتار show/hide رو داشته
   // باشه که بقیه‌ی ابزارهای Draw دارن.
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_TIMEFRAMES, tf);
   ObjectSetString(0, BTN_MASTER_DRAW, OBJPROP_TEXT, gDrawMinimized ? "Draw +" : "Draw −");
   ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_BGCOLOR, gDrawMinimized ? CLR_INACTIVE_GRAY : clrSeaGreen);
   //--- BUG-FIX (v1.07, lag): UpdateHubBackground()+ChartRedraw() removed
   //--- from here - every caller of this function already calls
   //--- PositionButtons() (which itself calls UpdateHubBackground()) around
   //--- the same state change, so this was pure duplicate work. Callers now
   //--- do ONE ChartRedraw() at the very end of their own logic instead of
   //--- each Apply*MinimizedState() call redrawing separately (up to 3x per
   //--- click when switching categories - the actual cause of the reported
   //--- click-lag). See the project's own established lesson on this exact
   //--- pattern in the POC mouse-move handler above.
}

void CreateOneButton(string name, string text, color bg)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, g_effBtnWidth);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, BtnHeight);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER_FG);
   }
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
}

void PositionButtons()
{
   //--- FEATURE (v1.08, Item 2): must run before anything below reads
   //--- g_effBtnWidth/g_effMasterBtnWidth/g_effBtnGap - this is the one
   //--- function every caller (OnInit, CHARTEVENT_CHART_CHANGE, every
   //--- master-button category switch) already goes through, so recomputing
   //--- here keeps the effective sizes correct on every path for free.
   RecomputeEffectiveSizes();

   //--- BUG-FIX (v1.04, Requirement 1): panel centers horizontally in
   //--- PanelRightMargin removed entirely (its only purpose was that
   //--- right-anchor; kept as a dead, misleadingly-named input would be
   //--- worse than removing it - nothing else in the file referenced it).
   //--- Still CORNER_LEFT_UPPER (no need to change that), just xStart is now
   //--- the true center-of-chart calculation instead of an offset from the
   //--- right edge. Recomputing chartWidth fresh here (already did before)
   //--- is what makes this auto-recenter on resize - see the
   //--- CHARTEVENT_CHART_CHANGE handler that already calls PositionButtons().
   //--- FIX (v1.08): UsableChartWidth() (not the raw chart width) - keeps
   //--- Hub's centering out of RiskManager EA's reserved top-right zone.
   int chartWidth = UsableChartWidth();
   int contentWidth = PanelContentWidth();
   int xStart = MathMax(0, (chartWidth - contentWidth) / 2);

   //--- ردیف اصلی: سه دکمه‌ی مادر Indicator/Label/Draw کنار هم، توی همون عرض
   //--- FEATURE (v1.08, Item 2): XSIZE now also set HERE (not just at
   //--- creation) - previously only CreateButtons() set it once, so a chart
   //--- resize repositioned the master buttons but never actually shrank
   //--- them. This is what makes the shrink apply live on resize.
   ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_XDISTANCE, xStart);
   ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_YDISTANCE, PanelTopY);
   ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_XSIZE, g_effMasterBtnWidth);
   ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_XDISTANCE, xStart + 1 * (g_effMasterBtnWidth + g_effBtnGap));
   ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_YDISTANCE, PanelTopY);
   ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_XSIZE, g_effMasterBtnWidth);
   ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_XDISTANCE, xStart + 2 * (g_effMasterBtnWidth + g_effBtnGap));
   ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_YDISTANCE, PanelTopY);
   ObjectSetInteger(0, BTN_MASTER_DRAW, OBJPROP_XSIZE, g_effMasterBtnWidth);
   // v1.17 (FEAT-052): دکمه‌ی مادر چهارم Theme
   ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_XDISTANCE, xStart + 3 * (g_effMasterBtnWidth + g_effBtnGap));
   ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_YDISTANCE, PanelTopY);
   ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_XSIZE, g_effMasterBtnWidth);

   //--- BUG-FIX (v1.06) - per Mahmoud: grid must sit to the RIGHT of the 3
   //--- master buttons, not below them - the old "below" layout wasted a
   //--- full row of width next to the master buttons whenever the grid was
   //--- wider than 3 buttons. Grid row 0 now shares the master row's own Y
   //--- (PanelTopY); grid row 1 sits directly under row 0 - only 2 total
   //--- row-heights tall instead of 3 (1 master row + 2 grid rows before).
   //--- چون فقط یکی از سه‌تا کشو (Indicator/Label/Draw) هم‌زمان باز می‌مونه
   //--- (mutual exclusion)، گرید هیچ‌وقت با گرید دیگه‌ای هم‌زمان دیده
   //--- نمی‌شه، پس همه از همون gridXStart/gridRow0Y/gridRow1Y استفاده می‌کنن.
   int gridXStart = xStart + 4 * (g_effMasterBtnWidth + g_effBtnGap);   // v1.17 (FEAT-052): ۴ دکمه‌ی مادر (قبلاً ۳)
   int gridRow0Y = PanelTopY;
   int gridRow1YTools = gridRow0Y + BtnHeight + g_effBtnGap;
   int gridRow1YLabels = gridRow1YTools;  // v1.16: ردیف دوم گرید لیبل = ردیف دوم بلوک چپ (ارتفاع Master) - قبلاً با LabelBtnHeight=18 یک ردیف بالاتر بود

   // v1.14 (اصلاح): دکمه‌ی Measure - دقیقاً توی فضای خالیِ ردیف۱ (زیر سه دکمه‌ی مادر
   // Ind+/Label+/Draw-) که قبلاً هیچ آبجکتی نداشت؛ عرضش کل اون فضای خالی رو پر می‌کنه (سه
   // دکمه‌ی مادر + دو gap بینشون) تا هیچ گپ خالی/بی‌دلیلی نمونه. فقط وقتی Draw باز باشه دیده
   // می‌شه (ApplyDrawMinimizedState همون تایم‌فریم‌محور که بقیه‌ی ابزارهای Draw دارن رو داره).
   // v1.17 (FEAT-052): با دکمه‌ی مادر چهارم، «فضای خالیِ زیر دکمه‌های مادر» ۴ دکمه + ۳ gap است؛ RANGE و جایگاه‌های SP2L/BTB
   // همچنان کل آن را پر می‌کنند (همان قاعده‌ی «بدون جای خالی»). برای برگشت به عرض قبلی: 3 * ... + 2 * ...
   int measureBtnWidth = 4 * g_effMasterBtnWidth + 3 * g_effBtnGap;
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_XDISTANCE, xStart);
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_YDISTANCE, gridRow1YTools);
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_XSIZE, measureBtnWidth);

   //--- ۸ ابزار رسم، شبکه‌ی ۲ردیفی (TOOL_COUNT=2 ردیف)، افقی جلو می‌ره،
   //--- سمت راست ۳ دکمه‌ی مادر
   string toolNames[TOOL_COUNT_ITEMS] = {BTN_FA, BTN_FB, BTN_FC, BTN_FD, BTN_HA, BTN_HB, BTN_PATH, BTN_LINE, BTN_HLINE, BTN_DASH};
   for(int i = 0; i < TOOL_COUNT_ITEMS; i++)
   {
      int row = i % TOOL_COUNT;
      int col = i / TOOL_COUNT;
      ObjectSetInteger(0, toolNames[i], OBJPROP_XDISTANCE, gridXStart + col * (g_effBtnWidth + g_effBtnGap));
      ObjectSetInteger(0, toolNames[i], OBJPROP_YDISTANCE, row == 0 ? gridRow0Y : gridRow1YTools);
      ObjectSetInteger(0, toolNames[i], OBJPROP_XSIZE, g_effBtnWidth);
   }

   //--- ۱۶ دکمه‌ی برچسب، شبکه‌ی ۲ردیفی، سمت راست ۳ دکمه‌ی مادر
   for(int i = 0; i < LABEL_GRID_COUNT; i++)
   {
      int row = i % TOOL_COUNT;
      int col = i / TOOL_COUNT;
      ObjectSetInteger(0, LabelButtonName(i), OBJPROP_XDISTANCE, gridXStart + col * (g_effLabelBtnWidth + g_effBtnGap));
      ObjectSetInteger(0, LabelButtonName(i), OBJPROP_YDISTANCE, row == 0 ? gridRow0Y : gridRow1YLabels);
      ObjectSetInteger(0, LabelButtonName(i), OBJPROP_XSIZE, g_effLabelBtnWidth);
   }
   // v1.15: جایگاه‌های ۱۷ و ۱۸ (SP2L, BTB) در فضای خالی زیر سه دکمه‌ی مادر (همان ناحیه‌ای که در تب Draw
   // دکمه‌ی RANGE می‌گیره) - عرض پنل عوض نمی‌شه. Y همان ردیف RANGE (زیر مادرها با فاصله‌ی gap).
   {
      int extraN = LABEL_COUNT - LABEL_GRID_COUNT;
      int extraGap = g_effBtnGap;
      int extraW = (measureBtnWidth - (extraN - 1) * extraGap) / extraN;
      for(int e = 0; e < extraN; e++)
      {
         string en = LabelButtonName(LABEL_GRID_COUNT + e);
         int w = (e == extraN - 1) ? (measureBtnWidth - e * (extraW + extraGap)) : extraW;
         ObjectSetInteger(0, en, OBJPROP_XDISTANCE, xStart + e * (extraW + extraGap));
         ObjectSetInteger(0, en, OBJPROP_YDISTANCE, gridRow1YTools);
         ObjectSetInteger(0, en, OBJPROP_XSIZE, w);
      }
   }
   // v1.16: هر ۱۸ دکمه دقیقاً ارتفاع Master؛ فونت با عرض مؤثر فعلی (که با کوچک‌شدن چارت عوض می‌شود) دوباره تنظیم می‌شود.
   // برای SP2L/BTB که عرضشان از بلوک Master می‌آید، فونت بر مبنای همان عرض واقعی است.
   for(int li = 0; li < LABEL_COUNT; li++)
   {
      string ln = LabelButtonName(li);
      ObjectSetInteger(0, ln, OBJPROP_YSIZE, BtnHeight);
      ObjectSetInteger(0, ln, OBJPROP_FONTSIZE, HubLabelFontSize(LabelList[li]));
   }

   //--- ۹ دکمه‌ی اندیکاتور، شبکه‌ی ۲ردیفی، سمت راست ۳ دکمه‌ی مادر
   string indicatorBtns[9] = {BTN_POC, BTN_WMAP, BTN_SOB, BTN_NYE, BTN_MTFCP,
                               BTN_EMA10, BTN_EMA20, BTN_EMA60, BTN_EMA240};
   for(int ind = 0; ind < 9; ind++)
   {
      int row = ind % TOOL_COUNT;
      int col = ind / TOOL_COUNT;
      ObjectSetInteger(0, indicatorBtns[ind], OBJPROP_XDISTANCE, gridXStart + col * (g_effBtnWidth + g_effBtnGap));
      ObjectSetInteger(0, indicatorBtns[ind], OBJPROP_YDISTANCE, row == 0 ? gridRow0Y : gridRow1YTools);
      ObjectSetInteger(0, indicatorBtns[ind], OBJPROP_XSIZE, g_effBtnWidth);
   }

   Theme_PositionButtons(gridXStart, gridRow0Y, gridRow1YTools);   // v1.17 (FEAT-052): ۷ تم + Original (۲ ردیف × ۴ ستون)

   UpdateHubBackground();
}

//+------------------------------------------------------------------+
//| BUG-FIX (v1.05): number of COLUMNS needed to lay out n items in a |
//| fixed TOOL_COUNT (=2) rows, filling column-by-column (ceil(n/2)). |
//+------------------------------------------------------------------+
int GridCols(int n)
{
   return((n + TOOL_COUNT - 1) / TOOL_COUNT);
}

//+------------------------------------------------------------------+
//| عرض واقعی محتوا - BUG-FIX (v1.06): حالا مجموع عرض ۳ دکمه‌ی مادر +      |
//| گرید سمت راستشون (اگه کدوم کشو بازه) - قبلاً max() این دوتا بود چون    |
//| گرید زیر دکمه‌های مادر می‌اومد؛ الان چون کنار همن، باید جمع بشن نه max. |
//+------------------------------------------------------------------+
int PanelContentWidth()
{
   return(ComputeContentWidth(g_effBtnWidth, g_effMasterBtnWidth, g_effBtnGap, g_effLabelBtnWidth));
}

//+------------------------------------------------------------------+
//| FEATURE (v1.08, Item 2): same math PanelContentWidth() always had, |
//| pulled out so it can be evaluated for ANY (btnW, masterW, gap)     |
//| triple - RecomputeEffectiveSizes() below calls it once with the    |
//| raw inputs (the "full size" baseline) and PanelContentWidth() now  |
//| calls it with whatever the current effective sizes are.            |
//+------------------------------------------------------------------+
int ComputeContentWidth(int btnW, int masterW, int gap, int labelW)
{
   int masterRowWidth = 4 * masterW + 3 * gap;   // v1.17 (FEAT-052): ۴ دکمه‌ی مادر (Indicator/Label/Draw/Theme)

   int gridWidth = 0;
   if(!gDrawMinimized)
      gridWidth = GridCols(TOOL_COUNT_ITEMS) * btnW + (GridCols(TOOL_COUNT_ITEMS) - 1) * gap;
   else if(!gLabelsMinimized)
      gridWidth = GridCols(LABEL_GRID_COUNT) * labelW + (GridCols(LABEL_GRID_COUNT) - 1) * gap;  // v1.16: عرض مخصوص لیبل (نه btnW)  // v1.15: فقط ۱۶ جایگاه گرید؛ ۲ جایگاه آخر زیر مادرها می‌شینن
   else if(!gIndicatorsMinimized)
      gridWidth = GridCols(9) * btnW + (GridCols(9) - 1) * gap;
   else if(!gThemeMinimized)
      gridWidth = 4 * labelW + 3 * gap;   // v1.17 (FEAT-052): ۴ ستون دکمه‌ی هم‌اندازه‌ی لیبل (۲ ردیف: ۱..۴ / ۵..۷ + Original)

   if(gridWidth == 0)
      return(masterRowWidth); // هیچ کشویی باز نیست - فقط عرض ۴ دکمه‌ی مادر (v1.17 FEAT-052)
   return(masterRowWidth + gap + gridWidth);
}

//+------------------------------------------------------------------+
//| FIX (v1.08, per Mahmoud's live test): RiskManager EA anchors its   |
//| own panel at the chart's top-right corner (PanelRight=true, width  |
//| PW=195 - see its own docs). Executive Hub centers across the FULL  |
//| chart width, unaware of that reserved zone - on a wide chart the   |
//| centered Hub never reaches that far right anyway, but on a narrow  |
//| chart it can. This is the single choke point every Hub layout      |
//| function reads chart width through, instead of calling             |
//| ChartGetInteger(CHART_WIDTH_IN_PIXELS) directly - it just pretends |
//| the chart is PanelWidth px narrower on the right, so every         |
//| downstream calculation (centering, shrink target, background)      |
//| naturally stays clear of RiskManager EA's own space without any of |
//| them needing to know WHY.                                          |
//+------------------------------------------------------------------+
int UsableChartWidth()
{
   int rawWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   return(MathMax(0, rawWidth - PanelWidth));
}

//+------------------------------------------------------------------+
//| FEATURE (v1.08, Item 2): recomputes g_effBtnWidth/g_effMasterBtnWidth/ |
//| g_effBtnGap from the raw inputs + current chart width + whichever   |
//| category (if any) is currently expanded (grid width differs per     |
//| category - Draw's 8 items vs Label's 16 vs Indicator's 9 - so this  |
//| must be re-run whenever either the chart resizes OR the open        |
//| category changes; every call site funnels through PositionButtons() |
//| which already covers both).                                        |
//+------------------------------------------------------------------+
void RecomputeEffectiveSizes()
{
   //--- FIX (v1.08): UsableChartWidth() (not the raw chart width) - see its
   //--- own comment above for why.
   int chartWidth = UsableChartWidth();
   int fullWidth = ComputeContentWidth(BtnWidth, MasterBtnWidth, BtnGap, LabelBtnWidth);

   //--- FIX (v1.08, Item 2 follow-up): available is now the SMALLER of (a)
   //--- the hard off-screen-prevention margin (chartWidth - 8, as before -
   //--- this floor never changes regardless of HubMaxWidthFraction, so the
   //--- panel can never actually run off the visible chart even if
   //--- HubMaxWidthFraction is set to 1.0) and (b) Mahmoud's own target
   //--- fraction of chart width - whichever is smaller wins, so the panel
   //--- shrinks as soon as EITHER condition calls for it.
   int hardMargin   = chartWidth - 8;
   int targetMargin = (int)MathRound(chartWidth * HubMaxWidthFraction);
   int available = MathMin(hardMargin, targetMargin);

   if(chartWidth <= 0 || fullWidth <= available)
   {
      g_effBtnWidth       = BtnWidth;
      g_effMasterBtnWidth = MasterBtnWidth;
      g_effBtnGap         = BtnGap;
      g_effLabelBtnWidth  = LabelBtnWidth;
      return;
   }

   double ratio = (double)MathMax(available, 0) / (double)fullWidth;

   int candidateBtnWidth       = (int)MathRound(BtnWidth * ratio);
   int candidateMasterBtnWidth = (int)MathRound(MasterBtnWidth * ratio);
   int candidateBtnGap         = (int)MathRound(BtnGap * ratio);

   g_effBtnWidth       = (int)MathMax(BTNWIDTH_FLOOR, MathMin(BtnWidth, candidateBtnWidth));
   g_effMasterBtnWidth = (int)MathMax(MASTERBTNWIDTH_FLOOR, MathMin(MasterBtnWidth, candidateMasterBtnWidth));
   g_effBtnGap         = (int)MathMax(BTNGAP_FLOOR, MathMin(BtnGap, candidateBtnGap));
   g_effLabelBtnWidth  = (int)MathMax(LABELBTNWIDTH_FLOOR, MathMin(LabelBtnWidth, (int)MathRound(LabelBtnWidth * ratio)));  // v1.16
}

//+------------------------------------------------------------------+
//| پس‌زمینه‌ی یکپارچه‌ی تیره - طوری که کل مجموعه حس یه داشبورد واحد بده     |
//| (مثل Risk Manager EA)، نه دکمه‌های ول روی چارت. عنوان بالاش طبق         |
//| خواسته‌ی Mahmoud کامل حذف شد (فضای لازمش همیشه بیشتر از فاصله‌ی بین     |
//| ردیف‌ها بود، پس تمیز درنمی‌اومد). ارتفاعش پویاست: بسته به اینکه کدوم    |
//| کشو (اگه کدوم) بازه، کوتاه یا بلندتر می‌شه.                            |
//+------------------------------------------------------------------+
void UpdateHubBackground()
{
   //--- FIX (v1.08): UsableChartWidth() (not the raw chart width) - see its
   //--- own comment above for why.
   int chartWidth = UsableChartWidth();
   int contentWidth = PanelContentWidth();
   int xStart = MathMax(0, (chartWidth - contentWidth) / 2);

   int pad = 4; // همون فاصله‌ای که بین ردیف‌ها هم هست (BtnGap=4) - یکدست

   int bgX = xStart - pad;
   int bgY = PanelTopY - pad;
   int bgWidth = contentWidth + 2 * pad;

   //--- BUG-FIX (v1.06): گرید حالا کنار دکمه‌های مادره نه زیرشون - پس
   //--- ارتفاع کل همیشه ۲ ردیفه (ردیف۰ = هم‌سطح دکمه‌های مادر، ردیف۱ = فقط
   //--- زیر گرید)، نه ۳ ردیف (۱ ردیف مادر + ۲ ردیف گرید) مثل قبل. وقتی هیچ
   //--- کشویی باز نیست، فقط همون ۱ ردیف دکمه‌های مادر می‌مونه.
   int row1HeightPx = BtnHeight + g_effBtnGap; // پیش‌فرض: Draw/Indicator
   bool anyOpen = true;
   if(!gDrawMinimized)
      row1HeightPx = BtnHeight + g_effBtnGap;
   else if(!gLabelsMinimized)
      row1HeightPx = BtnHeight + g_effBtnGap;  // v1.16: دکمه‌های لیبل هم ارتفاع Master
   else if(!gIndicatorsMinimized)
      row1HeightPx = BtnHeight + g_effBtnGap;
   else if(!gThemeMinimized)
      row1HeightPx = BtnHeight + g_effBtnGap;   // v1.17 (FEAT-052)
   else
      anyOpen = false;

   int bgHeight = BtnHeight + pad; // فقط ردیف۰ (هم‌سطح دکمه‌های مادر)
   if(anyOpen)
      bgHeight += row1HeightPx; // + ردیف۱ گرید
   //--- BUG-FIX (v1.07): Mahmoud reported the bottom edge sat flush against
   //--- the last row of toggle buttons (0px margin) - row1HeightPx already
   //--- includes BtnGap as the gap BETWEEN row0 and row1, but nothing was
   //--- added for a bottom margin below row1 itself. Add the same `pad`
   //--- used at the top, for symmetry.
   bgHeight += pad;

   //--- باید همیشه قبل از دکمه‌ها ساخته/آپدیت بشه (نه بعدش) - MT4 ترتیب
   //--- بصری آبجکت‌ها رو بر اساس ترتیب ساخت تعیین می‌کنه
   if(ObjectFind(0, HUB_BG_NAME) < 0)
   {
      ObjectCreate(0, HUB_BG_NAME, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_BACK, false);
      ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_ZORDER, PANEL_ZORDER_BG);
   }
   ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_XDISTANCE, bgX);
   ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_YDISTANCE, bgY);
   ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_XSIZE, bgWidth);
   ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_YSIZE, bgHeight);
   ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_BGCOLOR, HubBgColor);
   ObjectSetInteger(0, HUB_BG_NAME, OBJPROP_COLOR, HubBorderColor);
}

void RefreshButtonColors()
{
   // فقط دوباره HighlightActiveButton رو صدا می‌زنیم تا رنگ‌های تازه هم با
   // همون منطق کم‌رنگ/کامل (بسته به اینکه کدوم ابزار الان فعاله) اعمال بشن -
   // نه اینکه مستقیم رنگ کامل بذاریم و حالت کم‌رنگ ابزارهای غیرفعال از بین بره
   HighlightActiveButton(drawMode);
}

//+------------------------------------------------------------------+
//| کم‌رنگ‌کردن یه رنگ (بردنش به سمت خاکستری خنثی) - برای نشون‌دادن حالت    |
//| «غیرفعال» بدون دست‌زدن به BORDER_COLOR (که سه‌بعدی بومی رو خراب می‌کنه) |
//+------------------------------------------------------------------+
color DimColor(color c)
{
   int r = (int)(c & 0xFF);
   int g = (int)((c >> 8) & 0xFF);
   int b = (int)((c >> 16) & 0xFF);
   int gray = 130;
   int pct = 55; // چقدر به سمت خاکستری بره - ۰=رنگ اصلی، ۱۰۰=کاملاً خاکستری
   r = r + (gray - r) * pct / 100;
   g = g + (gray - g) * pct / 100;
   b = b + (gray - b) * pct / 100;
   return((color)(r + g * 256 + b * 65536));
}

void HighlightActiveButton(DRAW_MODE mode)
{
   //--- به‌جای OBJPROP_STATE (که به‌اندازه‌ی کافی محسوس نبود) یا
   //--- OBJPROP_BORDER_COLOR (که سه‌بعدی بومی رو برای همیشه تخت می‌کنه)،
   //--- از کنتراست رنگ خودِ دکمه استفاده می‌کنیم: غیرفعال = کم‌رنگ، فعال =
   //--- رنگ اصلی کامل. طبق پیشنهاد Mahmoud.
   string all[TOOL_COUNT_ITEMS];
   all[0] = BTN_FA; all[1] = BTN_FB; all[2] = BTN_FC; all[3] = BTN_FD;
   all[4] = BTN_HA; all[5] = BTN_HB; all[6] = BTN_PATH; all[7] = BTN_LINE; all[8] = BTN_HLINE; all[9] = BTN_DASH;

   color fullColors[TOOL_COUNT_ITEMS];
   fullColors[0] = gColorA; fullColors[1] = gColorB; fullColors[2] = gColorC; fullColors[3] = gColorD;
   fullColors[4] = gColorA; fullColors[5] = gColorB; fullColors[6] = gPathColor; fullColors[7] = gLineColor; fullColors[8] = gHRayColor; fullColors[9] = gDashColor;

   int activeIdx = -1;
   if(mode == MODE_FILL_A)   activeIdx = 0;
   if(mode == MODE_FILL_B)   activeIdx = 1;
   if(mode == MODE_FILL_C)   activeIdx = 2;
   if(mode == MODE_FILL_D)   activeIdx = 3;
   if(mode == MODE_HOLLOW_A) activeIdx = 4;
   if(mode == MODE_HOLLOW_B) activeIdx = 5;
   if(mode == MODE_PATH)     activeIdx = 6;
   if(mode == MODE_LINE)     activeIdx = 7;
   if(mode == MODE_HLINE)    activeIdx = 8;  // v1.15
   if(mode == MODE_DASH)     activeIdx = 9;  // v1.15

   for(int i = 0; i < TOOL_COUNT_ITEMS; i++)
      ObjectSetInteger(0, all[i], OBJPROP_BGCOLOR, (i == activeIdx) ? fullColors[i] : DimColor(fullColors[i]));

   // v1.14 (اصلاح): BTN_MEASURE بیرون آرایه‌ی بالاست (رنگ کاربر-تعریف‌شده نداره) - همون قرارداد
   // teal/gray توگل‌های دیگه‌ی پروژه (Candle Timer، D H/L و...) رو می‌گیره، نه منطق کم‌رنگ/کامل.
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_BGCOLOR, (mode == MODE_MEASURE) ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

void SelectWholeGroup(string clickedName)
{
   string groupPrefix = "";
   int segPos = StringFind(clickedName, "_seg");
   if(segPos >= 0)
      groupPrefix = StringSubstr(clickedName, 0, segPos + 4);
   else
   {
      int fillPos   = StringFind(clickedName, "_fill");
      int borderPos = StringFind(clickedName, "_border");
      if(fillPos >= 0)        groupPrefix = StringSubstr(clickedName, 0, fillPos);
      else if(borderPos >= 0) groupPrefix = StringSubstr(clickedName, 0, borderPos);
      else
      {
         // v1.14 (اصلاح - ابزار Range): زیرآبجکت‌های این ابزار با _LN<i>/_LB<i>/_RC<j> تمام
         // می‌شن (خط/لیبل/مستطیل) - همون منطق گروه‌بندی Path، فقط پسوند فرق داره.
         int lnPos = StringFind(clickedName, "_LN");
         int lbPos = StringFind(clickedName, "_LB");
         int rcPos = StringFind(clickedName, "_RC");
         if(lnPos >= 0)      groupPrefix = StringSubstr(clickedName, 0, lnPos);
         else if(lbPos >= 0) groupPrefix = StringSubstr(clickedName, 0, lbPos);
         else if(rcPos >= 0) groupPrefix = StringSubstr(clickedName, 0, rcPos);
      }
   }
   if(groupPrefix == "") return;

   if(g_selectedPathPrefix != "" && g_selectedPathPrefix != groupPrefix)
      DeselectPathGroup(g_selectedPathPrefix);

   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, groupPrefix) == 0)
         ObjectSetInteger(0, nm, OBJPROP_SELECTED, true);
   }
   g_selectedPathPrefix = groupPrefix;
   skipDeselectOnce     = true;
   BuildGroupSnapshot(groupPrefix);
   ChartRedraw();
}

void DeselectPathGroup(string prefix)
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, prefix) == 0)
         ObjectSetInteger(0, nm, OBJPROP_SELECTED, false);
   }
   ArrayResize(g_groupSnapNames, 0);
   ChartRedraw();
}

void BuildGroupSnapshot(string prefix)
{
   ArrayResize(g_groupSnapNames, 0);
   int total = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < total; i++)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, prefix) != 0) continue;

      int n = ArraySize(g_groupSnapNames);
      ArrayResize(g_groupSnapNames, n + 1);
      ArrayResize(g_groupSnapT1, n + 1);
      ArrayResize(g_groupSnapP1, n + 1);
      ArrayResize(g_groupSnapT2, n + 1);
      ArrayResize(g_groupSnapP2, n + 1);

      g_groupSnapNames[n] = nm;
      g_groupSnapT1[n] = (datetime)ObjectGet(nm, OBJPROP_TIME1);
      g_groupSnapP1[n] = ObjectGet(nm, OBJPROP_PRICE1);
      g_groupSnapT2[n] = (datetime)ObjectGet(nm, OBJPROP_TIME2);
      g_groupSnapP2[n] = ObjectGet(nm, OBJPROP_PRICE2);
   }
}

void HandleGroupDrag(string draggedName)
{
   int idx = -1;
   for(int i = 0; i < ArraySize(g_groupSnapNames); i++)
      if(g_groupSnapNames[i] == draggedName) { idx = i; break; }
   if(idx < 0) return;

   datetime newT1 = (datetime)ObjectGet(draggedName, OBJPROP_TIME1);
   double   newP1 = ObjectGet(draggedName, OBJPROP_PRICE1);
   datetime newT2 = (datetime)ObjectGet(draggedName, OBJPROP_TIME2);
   double   newP2 = ObjectGet(draggedName, OBJPROP_PRICE2);

   long   deltaT1 = (long)newT1 - (long)g_groupSnapT1[idx];
   double deltaP1 = newP1 - g_groupSnapP1[idx];
   long   deltaT2 = (long)newT2 - (long)g_groupSnapT2[idx];
   double deltaP2 = newP2 - g_groupSnapP2[idx];

   bool wholeShapeMoved = (deltaT1 == deltaT2) && (MathAbs(deltaP1 - deltaP2) < 0.0000001);
   if(!wholeShapeMoved || (deltaT1 == 0 && deltaP1 == 0))
   {
      BuildGroupSnapshot(g_selectedPathPrefix);
      return;
   }

   for(int i = 0; i < ArraySize(g_groupSnapNames); i++)
   {
      if(i == idx) continue;
      string nm = g_groupSnapNames[i];
      ObjectMove(0, nm, 0, g_groupSnapT1[i] + (int)deltaT1, g_groupSnapP1[i] + deltaP1);
      ObjectMove(0, nm, 1, g_groupSnapT2[i] + (int)deltaT1, g_groupSnapP2[i] + deltaP1);
   }

   BuildGroupSnapshot(g_selectedPathPrefix);
   ChartRedraw();
}

//+------------------------------------------------------------------+
string LabelButtonName(int idx)
{
   // v1.15: نام آبجکت بر اساس شماره‌ی جایگاه (نه متن لیبل) - چون متن حالا از فایل قابل‌ویرایش است
   // (تکراری/خالی/کاراکتر خاص نباید نام آبجکت رو خراب کنه).
   return(PFX + "LblBtn_" + IntegerToString(idx));
}

void CreateLabelButtons()
{
   for(int i = 0; i < LABEL_COUNT; i++)
   {
      string name = LabelButtonName(i);
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XSIZE, g_effLabelBtnWidth);  // v1.16
         ObjectSetInteger(0, name, OBJPROP_YSIZE, BtnHeight);          // v1.16: ارتفاع Master
         ObjectSetString(0, name, OBJPROP_TEXT, LabelList[i]);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, HubLabelFontSize(LabelList[i]));
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, CLR_INACTIVE_GRAY);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER_FG);
      }
   }
}

void ApplyLabelsMinimizedState()
{
   for(int i = 0; i < LABEL_COUNT; i++)
   {
      // v1.15: جایگاه خالی در RM_HubLabels.txt = دکمه همیشه مخفی (حتی وقتی تب Label باز است)
      long tf = (gLabelsMinimized || LabelList[i] == "") ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
      ObjectSetInteger(0, LabelButtonName(i), OBJPROP_TIMEFRAMES, tf);
   }
   ObjectSetString(0, BTN_MASTER_LABELS, OBJPROP_TEXT, gLabelsMinimized ? "Label +" : "Label −");
   ObjectSetInteger(0, BTN_MASTER_LABELS, OBJPROP_BGCOLOR, gLabelsMinimized ? CLR_INACTIVE_GRAY : clrSeaGreen);
   //--- BUG-FIX (v1.07, lag): see ApplyDrawMinimizedState() - same reasoning.
}

//+------------------------------------------------------------------+
//| پایه‌ی هاب اجرایی — فعلاً هیچ دکمه‌ی زیرمجموعه‌ای نداره (ماژول ۱ در    |
//| دور بعدی: POC + Weekly Map). ساختارش رو از الان آماده می‌کنیم تا با   |
//| هر ماژول جدید فقط کافیه یه آرایه‌ی جدید به لیست تایم‌فریم‌ها اضافه بشه. |
//+------------------------------------------------------------------+
void ApplyIndicatorsMinimizedState()
{
   long tf = gIndicatorsMinimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
   string indicatorBtnsAll[9] = {BTN_POC, BTN_WMAP, BTN_SOB, BTN_NYE, BTN_MTFCP,
                                  BTN_EMA10, BTN_EMA20, BTN_EMA60, BTN_EMA240};
   for(int ind = 0; ind < 9; ind++)
      ObjectSetInteger(0, indicatorBtnsAll[ind], OBJPROP_TIMEFRAMES, tf);
   ObjectSetString(0, BTN_MASTER_INDICATOR, OBJPROP_TEXT, gIndicatorsMinimized ? "Ind +" : "Ind −");
   ObjectSetInteger(0, BTN_MASTER_INDICATOR, OBJPROP_BGCOLOR, gIndicatorsMinimized ? CLR_INACTIVE_GRAY : clrSeaGreen);
   //--- BUG-FIX (v1.07, lag): see ApplyDrawMinimizedState() - same reasoning.
}

//+------------------------------------------------------------------+
//| v1.17 (FEAT-052) - Chart Themes                                   |
//| دکمه‌ی مادر Theme + کشوی ۷ تم رنگی + Original. هر کلیک فقط یک‌بار       |
//| رنگ‌های چارتِ فعلی را عوض می‌کند؛ هیچ تایمر/polling/اعمال مجدد (روی      |
//| ری‌لود، تغییر تایم‌فریم یا ری‌استارت) وجود ندارد - MT4 رنگ‌ها را با خودِ   |
//| چارت ذخیره می‌کند. فقط چارتِ فعلی؛ Bid line / مقیاس / autoscroll /      |
//| حجم on-off / جداکننده‌ی دوره‌ها دست‌نخورده.                            |
//+------------------------------------------------------------------+
//--- جدول ثابت ۷ تم (بدون input و فایل). ستون Button = رنگ Bull candle.
color THEME_BG[THEME_COUNT]     = {C'169,169,169', C'0,0,0',       C'0,0,0',       C'24,24,24',  C'192,192,192', C'0,0,0',       C'16,20,26'};
color THEME_FG[THEME_COUNT]     = {C'0,0,0',       C'255,255,255', C'255,255,255', C'255,255,255', C'0,0,0',      C'255,255,255', C'210,214,220'};
color THEME_GRID[THEME_COUNT]   = {C'0,0,0',       C'128,128,128', C'128,128,128', C'35,38,46',  C'128,128,128', C'128,128,128', C'35,38,46'};
color THEME_BARUP[THEME_COUNT]  = {C'0,0,0',       C'218,165,32',  C'0,100,0',     C'96,96,96',  C'0,0,0',       C'211,211,211', C'38,166,154'};
color THEME_BARDN[THEME_COUNT]  = {C'0,0,0',       C'192,192,192', C'218,165,32',  C'53,60,66',  C'0,0,0',       C'128,0,0',     C'239,83,80'};
color THEME_BULL[THEME_COUNT]   = {C'95,158,160',  C'218,165,32',  C'0,100,0',     C'240,240,240', C'255,255,255', C'211,211,211', C'38,166,154'};
color THEME_BEAR[THEME_COUNT]   = {C'253,245,230', C'192,192,192', C'218,165,32',  C'115,128,142', C'128,128,128', C'128,0,0',     C'239,83,80'};
#define THEME_LINE_CLR C'105,105,105'   // Line graph (مشترک همه‌ی تم‌ها)
#define THEME_VOL_CLR  C'105,105,105'   // Volumes
#define THEME_ASK_CLR  C'166,90,62'     // Ask line
#define THEME_STOP_CLR C'122,59,52'     // Stop levels

//--- کدگذاری فشرده (base64 دستی، ۵۱ کاراکتر < ۶۳) برای ذخیره‌ی Original داخل متن آبجکت مخفی:
//--- "TO1:" + ۱۱ رنگ x ۴ کاراکتر + ۲ کاراکتر ماسک clrNONE + ۱ کاراکتر پرچم‌ها (grid/shift/askLine + mode)
string THEME_B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

string Theme_B64Char(int v)
{
   return(StringSubstr(THEME_B64, v & 63, 1));
}

int Theme_B64Val(string ch)
{
   return(StringFind(THEME_B64, ch));
}

string Theme_Encode(color &c[], bool grid, bool shift, bool askLine, int mode)
{
   string s = "TO1:";
   int mask = 0;
   for(int i = 0; i < 11; i++)
   {
      int v = 0;
      if(c[i] == clrNONE) mask |= (1 << i);
      else                v = (int)c[i];
      for(int k = 3; k >= 0; k--)
         s += Theme_B64Char((v >> (6 * k)) & 63);
   }
   s += Theme_B64Char(mask & 63);
   s += Theme_B64Char((mask >> 6) & 63);
   int fl = (grid ? 1 : 0) | (shift ? 2 : 0) | (askLine ? 4 : 0) | ((mode & 3) << 3);
   s += Theme_B64Char(fl);
   return(s);
}

bool Theme_Decode(string s, color &c[], bool &grid, bool &shift, bool &askLine, int &mode)
{
   if(StringLen(s) != 51 || StringSubstr(s, 0, 4) != "TO1:") return(false);
   int m0 = Theme_B64Val(StringSubstr(s, 48, 1));
   int m1 = Theme_B64Val(StringSubstr(s, 49, 1));
   int fl = Theme_B64Val(StringSubstr(s, 50, 1));
   if(m0 < 0 || m1 < 0 || fl < 0) return(false);
   int mask = m0 | (m1 << 6);
   for(int i = 0; i < 11; i++)
   {
      int v = 0;
      for(int k = 0; k < 4; k++)
      {
         int d = Theme_B64Val(StringSubstr(s, 4 + i * 4 + k, 1));
         if(d < 0) return(false);
         v = (v << 6) | d;
      }
      c[i] = (((mask >> i) & 1) != 0) ? clrNONE : (color)v;
   }
   grid    = ((fl & 1) != 0);
   shift   = ((fl & 2) != 0);
   askLine = ((fl & 4) != 0);
   mode    = (fl >> 3) & 3;
   return(true);
}

//--- ترتیب ۱۱ رنگ: 0 Background, 1 Foreground, 2 Grid, 3 BarUp, 4 BarDown, 5 CandleBull, 6 CandleBear,
//--- 7 LineGraph, 8 Volumes, 9 Ask, 10 StopLevels
void Theme_ReadChart(color &c[], bool &grid, bool &shift, bool &askLine, int &mode)
{
   c[0]  = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   c[1]  = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   c[2]  = (color)ChartGetInteger(0, CHART_COLOR_GRID);
   c[3]  = (color)ChartGetInteger(0, CHART_COLOR_CHART_UP);
   c[4]  = (color)ChartGetInteger(0, CHART_COLOR_CHART_DOWN);
   c[5]  = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BULL);
   c[6]  = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
   c[7]  = (color)ChartGetInteger(0, CHART_COLOR_CHART_LINE);
   c[8]  = (color)ChartGetInteger(0, CHART_COLOR_VOLUME);
   c[9]  = (color)ChartGetInteger(0, CHART_COLOR_ASK);
   c[10] = (color)ChartGetInteger(0, CHART_COLOR_STOP_LEVEL);
   grid    = (ChartGetInteger(0, CHART_SHOW_GRID) != 0);
   shift   = (ChartGetInteger(0, CHART_SHIFT) != 0);
   askLine = (ChartGetInteger(0, CHART_SHOW_ASK_LINE) != 0);
   mode    = (int)ChartGetInteger(0, CHART_MODE);
}

void Theme_WriteChart(color &c[], bool grid, bool shift, bool askLine, int mode)
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND,  c[0]);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND,  c[1]);
   ChartSetInteger(0, CHART_COLOR_GRID,        c[2]);
   ChartSetInteger(0, CHART_COLOR_CHART_UP,    c[3]);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN,  c[4]);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, c[5]);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, c[6]);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE,  c[7]);
   ChartSetInteger(0, CHART_COLOR_VOLUME,      c[8]);
   ChartSetInteger(0, CHART_COLOR_ASK,         c[9]);
   ChartSetInteger(0, CHART_COLOR_STOP_LEVEL,  c[10]);
   ChartSetInteger(0, CHART_SHOW_GRID,         grid);
   ChartSetInteger(0, CHART_SHIFT,             shift);
   ChartSetInteger(0, CHART_MODE,              mode);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE,     askLine);
}

//--- Original: یک‌بار، دقیقاً قبل از اولین تم روی این چارت ذخیره می‌شود و بعدش هرگز بازنویسی نمی‌شود (فقط اگر آبجکت
//--- نباشد یا متنش خراب/ناشناخته باشد دوباره ساخته می‌شود). اگر ذخیره نشد، تم اعمال نمی‌شود (جلوگیری از گم‌شدن رنگ‌های کاربر).
bool Theme_EnsureOriginalStored()
{
   color tc[11]; bool tg, ts, ta; int tm;
   if(ObjectFind(0, THEME_ORIG_NAME) >= 0)
   {
      if(Theme_Decode(ObjectGetString(0, THEME_ORIG_NAME, OBJPROP_TEXT), tc, tg, ts, ta, tm))
         return(true);   // قبلاً ذخیره شده - دست نزن
   }

   Theme_ReadChart(tc, tg, ts, ta, tm);
   string enc = Theme_Encode(tc, tg, ts, ta, tm);

   if(ObjectFind(0, THEME_ORIG_NAME) < 0)
   {
      if(!ObjectCreate(0, THEME_ORIG_NAME, OBJ_LABEL, 0, 0, 0))
      {
         Print("ExecutiveHub: Theme - cannot create the hidden Original-store object, error ", GetLastError());
         return(false);
      }
   }
   ObjectSetInteger(0, THEME_ORIG_NAME, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);   // روی هیچ تایم‌فریمی دیده نمی‌شود
   ObjectSetInteger(0, THEME_ORIG_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, THEME_ORIG_NAME, OBJPROP_XDISTANCE, -100);              // بیرون از صفحه (دفاع دوم)
   ObjectSetInteger(0, THEME_ORIG_NAME, OBJPROP_YDISTANCE, -100);
   ObjectSetInteger(0, THEME_ORIG_NAME, OBJPROP_COLOR, clrNONE);
   ObjectSetInteger(0, THEME_ORIG_NAME, OBJPROP_FONTSIZE, 1);
   ObjectSetInteger(0, THEME_ORIG_NAME, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, THEME_ORIG_NAME, OBJPROP_HIDDEN, true);
   ObjectSetString(0, THEME_ORIG_NAME, OBJPROP_TEXT, enc);

   if(ObjectGetString(0, THEME_ORIG_NAME, OBJPROP_TEXT) != enc)   // متن کوتاه/خراب شد؟ (محدودیت طول)
   {
      Print("ExecutiveHub: Theme - Original-store text was not kept intact; theme NOT applied.");
      ObjectDelete(0, THEME_ORIG_NAME);
      return(false);
   }
   return(true);
}

//--- اندیس تمی که رنگ فعلی چارت دقیقاً با آن می‌خواند (Background + Foreground + Bull + Bear) یا -1. فقط در OnInit.
int Theme_DetectActive()
{
   color bg   = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   color fg   = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   color bull = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BULL);
   color bear = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
   for(int i = 0; i < THEME_COUNT; i++)
      if(bg == THEME_BG[i] && fg == THEME_FG[i] && bull == THEME_BULL[i] && bear == THEME_BEAR[i])
         return(i);
   return(-1);
}

//--- themeIdx: 0..6 = تم ۱..۷؛ -1 = Original. یک بار رنگ‌ها را روی چارتِ فعلی می‌نویسد، آبجکت‌های Hub را یک‌بار بازرنگ می‌کند،
//--- دکمه‌ها را به‌روز می‌کند و یک ChartRedraw() می‌زند.
void Theme_Apply(int themeIdx)
{
   color cc[11]; bool cg, cs, ca; int cm;
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
      cc[7] = THEME_LINE_CLR;       cc[8] = THEME_VOL_CLR;
      cc[9] = THEME_ASK_CLR;        cc[10] = THEME_STOP_CLR;
      cg = false; cs = true; ca = true; cm = CHART_CANDLES;
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
   ChartRedraw();   // تنها ChartRedraw این کلیک (SOB_Recalculate اگر روشن باشد خودش یکی می‌زند - رفتار قبلی آن تابع)
}

//--- بازرنگ یک‌باره‌ی آبجکت‌های Hub بعد از تغییر تم. از همان توابعی استفاده می‌کند که شاخه‌ی CHARTEVENT_CHART_CHANGE
//--- (EMA_ApplyGrayscaleColors / MTFCP_DrawAll) و ماژول‌ها قبلاً داشتند؛ لوپ یا تایمر جدید نیست. رنگ‌های تازه را از
//--- override (g_ov*) می‌گیرد چون ChartGetInteger درست بعد از ChartSetInteger ممکن است هنوز مقدار قدیمی بدهد.
void Theme_RecolourOnce(color bg, color fg, color bull, color bear)
{
   g_ovBg = bg; g_ovFg = fg; g_ovBull = bull; g_ovBear = bear;
   g_ovOn = true;

   EMA_ApplyGrayscaleColors();                    // رنگ پلات‌های EMA (بافر اندیکاتور)
   if(wmapVisible) WMAP_DrawAll();                // خطوط + تگ‌های Weekly Map
   if(pocLevelsActive) POC_RecolourLevels();      // خطوط/لیبل‌های POC که روی تغییر تایم‌فریم می‌مانند
   if(sobVisible) SOB_Recalculate();              // Session Opening Box (رنگ ثابت ورودی -> کنتراست خودکار)
   if(nyeVisible) NYE_Recalculate();              // NY Edge
   if(mtfcpVisible)                               // MTF Candle Preview (کندل‌ها/کانکتور/لیبل‌ها)
   {
      MTFCP_DrawAll();
      if(MTFCP_ShowCountdown) MTFCP_UpdateCountdownLabel();
   }
   gLabelColor = LoadPersistedLabelColor();       // رنگ پیش‌فرض ابزار Label (اگر کاربر دستی تعیین نکرده باشد خودکار است)

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

//--- دکمه‌ها ------------------------------------------------------------
string Theme_BtnName(int i)
{
   return(PFX + "Btn_Theme_" + IntegerToString(i + 1));
}

double Theme_Lum(color c)
{
   return(0.299 * (int)(c & 0xFF) + 0.587 * (int)((c >> 8) & 0xFF) + 0.114 * (int)((c >> 16) & 0xFF));
}

void Theme_CreateOneButton(string name, string text, int fontSize, string tip)
{
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, g_effLabelBtnWidth);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, BtnHeight);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER_FG);
}

void Theme_CreateButtons()
{
   if(ObjectFind(0, BTN_MASTER_THEME) < 0)
   {
      ObjectCreate(0, BTN_MASTER_THEME, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_XSIZE, g_effMasterBtnWidth);
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_YSIZE, BtnHeight);
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_BGCOLOR, clrSeaGreen);
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_ZORDER, PANEL_ZORDER_FG);
   }
   for(int i = 0; i < THEME_COUNT; i++)
      Theme_CreateOneButton(Theme_BtnName(i), IntegerToString(i + 1), 8, "Theme " + IntegerToString(i + 1));
   Theme_CreateOneButton(BTN_THEME_ORIG, "Original", 6, "Original chart colours (before the first theme)");
   Theme_RefreshButtons();
}

//--- پس‌زمینه‌ی هر دکمه = رنگ Bull همان تم (فعال: کامل، غیرفعال: کم‌رنگ با DimColor - همان قرارداد دکمه‌های Draw)؛ متن
//--- سیاه/سفید بر اساس luminance پس‌زمینه‌ی نمایش‌داده‌شده؛ اگر پس‌زمینه به رنگ بدنه‌ی پنل (HubBgColor) خیلی نزدیک باشد
//--- (مثلاً تم ۳ فعال) دورِ روشن می‌گیرد - اگر OBJPROP_BORDER_COLOR روی OBJ_BUTTON در این build پذیرفته نشد، پس‌زمینه کمی
//--- به سفید نزدیک می‌شود.
void Theme_RefreshButtons()
{
   for(int i = 0; i < THEME_COUNT; i++)
   {
      string nm = Theme_BtnName(i);
      if(ObjectFind(0, nm) < 0) continue;

      color bg = (i == g_themeActive) ? THEME_BULL[i] : DimColor(THEME_BULL[i]);
      bool needBorder = (MathAbs(Theme_Lum(bg) - Theme_Lum(HubBgColor)) < 40);
      color bd = needBorder ? (color)C'200,200,200' : bg;
      if(!ObjectSetInteger(0, nm, OBJPROP_BORDER_COLOR, bd) && needBorder)
         bg = SOB_BlendTowardWhite(bg, 35);
      ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, (Theme_Lum(bg) > 140) ? clrBlack : clrWhite);
   }
   if(ObjectFind(0, BTN_THEME_ORIG) >= 0)
   {
      ObjectSetInteger(0, BTN_THEME_ORIG, OBJPROP_BORDER_COLOR, CLR_INACTIVE_GRAY);
      ObjectSetInteger(0, BTN_THEME_ORIG, OBJPROP_BGCOLOR, CLR_INACTIVE_GRAY);
      ObjectSetInteger(0, BTN_THEME_ORIG, OBJPROP_COLOR, clrWhite);
   }
}

void ApplyThemeMinimizedState()
{
   long tf = gThemeMinimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
   for(int i = 0; i < THEME_COUNT; i++)
      ObjectSetInteger(0, Theme_BtnName(i), OBJPROP_TIMEFRAMES, tf);
   ObjectSetInteger(0, BTN_THEME_ORIG, OBJPROP_TIMEFRAMES, tf);
   ObjectSetString(0, BTN_MASTER_THEME, OBJPROP_TEXT, gThemeMinimized ? "Theme +" : "Theme −");
   ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_BGCOLOR, gThemeMinimized ? CLR_INACTIVE_GRAY : clrSeaGreen);
   //--- (v1.07 lag rule) بدون UpdateHubBackground()/ChartRedraw() - صدازننده‌ها PositionButtons() و یک ChartRedraw() دارند.
}

//--- شبکه‌ی ۲ ردیف × ۴ ستون، سمت راست ۴ دکمه‌ی مادر: ردیف ۰ = تم ۱..۴، ردیف ۱ = تم ۵..۷ + Original. عرض دکمه‌ها = عرض مؤثر دکمه‌ی لیبل.
void Theme_PositionButtons(int gridX, int row0Y, int row1Y)
{
   for(int i = 0; i <= THEME_COUNT; i++)
   {
      string nm = (i < THEME_COUNT) ? Theme_BtnName(i) : BTN_THEME_ORIG;
      int row = i / 4;
      int col = i % 4;
      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, gridX + col * (g_effLabelBtnWidth + g_effBtnGap));
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, (row == 0) ? row0Y : row1Y);
      ObjectSetInteger(0, nm, OBJPROP_XSIZE, g_effLabelBtnWidth);
      ObjectSetInteger(0, nm, OBJPROP_YSIZE, BtnHeight);
   }
   ObjectSetInteger(0, BTN_THEME_ORIG, OBJPROP_FONTSIZE, HubLabelFontSize("Original"));
}

void DisarmLabel()
{
   if(armedLabel != "")
   {
      for(int i = 0; i < LABEL_COUNT; i++)
         if(LabelList[i] == armedLabel)
            ObjectSetInteger(0, LabelButtonName(i), OBJPROP_BGCOLOR, CLR_INACTIVE_GRAY);
   }
   armedLabel = "";
   //--- FEATURE (v1.08, Item 1): every path that cancels/consumes an armed
   //--- label (toggling the same label off, arming a different one, an
   //--- actual placement click, or switching to Draw/Indicator) already
   //--- calls DisarmLabel() - so deleting the preview here covers all of
   //--- them in one place, exactly as the task asked for.
   DeleteLabelPreview();
}

void PlaceLabel(string text, datetime t, double p)
{
   gCounter++;
   string clean = text;
   StringReplace(clean, " ", "_");
   string name = PFX + "Lbl_" + clean + "_" + (string)TimeLocal() + "_" + (string)gCounter;

   ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gLabelColor));   // v1.17 (FEAT-052)
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, gLabelFontSize);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

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

   if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, PFX + "Path_") == 0)
   {
      SelectWholeGroup(sparam);
      return;
   }

   // v1.14 (اصلاح - ابزار Range): همون مکانیزم گروه‌بندی/سلکت-یک‌جای Path - کلیک روی هر
   // زیرآبجکتی از یک نمونه‌ی Range، کل همون نمونه (۷خط+۷لیبل+۲مستطیل) رو با هم سلکت می‌کنه؛
   // برای پاک‌کردن دیگه لازم نیست تک‌تک سلکت بشن - یک Delete کل مجموعه رو پاک می‌کنه.
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
         if(!gThemeMinimized) { gThemeMinimized = true; SavePersistedBool("ThemeMinimized", true); ApplyThemeMinimizedState(); }   // v1.17 (FEAT-052)
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
         if(!gThemeMinimized) { gThemeMinimized = true; SavePersistedBool("ThemeMinimized", true); ApplyThemeMinimizedState(); }   // v1.17 (FEAT-052)
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
         if(!gThemeMinimized) { gThemeMinimized = true; SavePersistedBool("ThemeMinimized", true); ApplyThemeMinimizedState(); }   // v1.17 (FEAT-052)
      }
      PositionButtons();
      ApplyIndicatorsMinimizedState();
      ChartRedraw();
      return;
   }

   //--- v1.17 (FEAT-052): دکمه‌ی مادر Theme - چهارمین کشوی هم‌محل (باز شدنش بقیه را می‌بندد و برعکس)
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

   //--- v1.17 (FEAT-052): کلیک روی یکی از ۷ دکمه‌ی تم یا Original. فقط روی همین کلیک اجرا می‌شود؛ هیچ تایمر/polling ندارد.
   if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, PFX + "Btn_Theme_") == 0)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      skipNextClick = true;
      int themeIdx = -2;
      if(sparam == BTN_THEME_ORIG)
         themeIdx = -1;
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
            ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, CLR_SUBTOGGLE_ACTIVE);
         }
         ChartRedraw();
         return;
      }
   }

   if(id == CHARTEVENT_OBJECT_CLICK && (sparam == BTN_FA || sparam == BTN_FB || sparam == BTN_FC || sparam == BTN_FD || sparam == BTN_HA || sparam == BTN_HB || sparam == BTN_PATH || sparam == BTN_LINE || sparam == BTN_HLINE || sparam == BTN_DASH || sparam == BTN_MEASURE))
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
      if(sparam == BTN_HLINE) clicked = MODE_HLINE;  // v1.15
      if(sparam == BTN_DASH)  clicked = MODE_DASH;   // v1.15
      if(sparam == BTN_MEASURE) clicked = MODE_MEASURE;  // v1.14 (اصلاح)

      if(drawMode == clicked)
      {
         CancelDrawing();
      }
      else
      {
         CancelDrawing();
         drawMode = clicked;
         if(clicked == MODE_PATH)
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

   if(id == CHARTEVENT_OBJECT_CHANGE && StringFind(sparam, PFX + "Lbl_") == 0)
   {
      color newLblColor = (color)ObjectGet(sparam, OBJPROP_COLOR);
      if(newLblColor != gLabelColor)
      {
         gLabelColor = newLblColor;
         SavePersistedColor("LabelColor", gLabelColor);
      }
      int newLblFont = (int)ObjectGet(sparam, OBJPROP_FONTSIZE);
      if(newLblFont != gLabelFontSize)
      {
         gLabelFontSize = newLblFont;
         SavePersistedInt("LabelFontSize", gLabelFontSize);
      }
      return;
   }

   if(id == CHARTEVENT_OBJECT_CHANGE && StringFind(sparam, PFX) == 0 && sparam != PREVIEW_NAME && sparam != PATH_PREVIEW_NAME && sparam != LINE_PREVIEW_NAME)
   {
      if(StringFind(sparam, "Path_") >= 0)
      {
         color newPathColor = (color)ObjectGet(sparam, OBJPROP_COLOR);
         if(newPathColor != gPathColor)
         {
            gPathColor = newPathColor;
            SavePersistedColor("PathColor", gPathColor);
            HighlightActiveButton(drawMode);
         }
         int newPathWidth = (int)ObjectGet(sparam, OBJPROP_WIDTH);
         if(newPathWidth != gPathWidth)
         {
            gPathWidth = newPathWidth;
            SavePersistedInt("PathWidth", gPathWidth);
         }
         int newPathStyle = (int)ObjectGet(sparam, OBJPROP_STYLE);
         if(newPathStyle != gPathStyle)
         {
            gPathStyle = newPathStyle;
            SavePersistedInt("PathStyle", gPathStyle);
         }
         return;
      }

      if(StringFind(sparam, "Line_") >= 0)
      {
         color newLineColor = (color)ObjectGet(sparam, OBJPROP_COLOR);
         if(newLineColor != gLineColor)
         {
            gLineColor = newLineColor;
            SavePersistedColor("LineColor", gLineColor);
            HighlightActiveButton(drawMode);
         }
         int newLineWidth = (int)ObjectGet(sparam, OBJPROP_WIDTH);
         if(newLineWidth != gLineWidth)
         {
            gLineWidth = newLineWidth;
            SavePersistedInt("LineWidth", gLineWidth);
         }
         int newLineStyle = (int)ObjectGet(sparam, OBJPROP_STYLE);
         if(newLineStyle != gLineStyle)
         {
            gLineStyle = newLineStyle;
            SavePersistedInt("LineStyle", gLineStyle);
         }
         return;
      }

      // v1.15 (revision): Horizontal Line / Dash Line - هر ویرایش روی چارت، پیش‌فرض خودِ همان ابزار را عوض و ذخیره می‌کند
      // (مثل Line/Path). پیش‌فرض‌های Line و مستطیل‌ها عمداً دست نمی‌خورند چون این دو ابزار برای خودشان جدا نگه داشته می‌شوند.
      bool isHRay = (StringFind(sparam, "HRay_") >= 0);
      if(isHRay || StringFind(sparam, "Dash_") >= 0)
      {
         color newCol = (color)ObjectGet(sparam, OBJPROP_COLOR);
         int   newW   = (int)ObjectGet(sparam, OBJPROP_WIDTH);
         int   newSt  = (int)ObjectGet(sparam, OBJPROP_STYLE);
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

      color newColor = (color)ObjectGet(sparam, OBJPROP_COLOR);
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

      int newWidth = (int)ObjectGet(sparam, OBJPROP_WIDTH);
      if(newWidth != gWidth)
      {
         gWidth = newWidth;
         SavePersistedInt("Width", gWidth);
      }

      int newStyle = (int)ObjectGet(sparam, OBJPROP_STYLE);
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
         //--- "stepped" rather than following smoothly. This is exactly the
         //--- rate-limited ChartRedraw() the original task flagged as the
         //--- Stage 5e-v MT5 fix "in case MT4 needs it too" - turns out MT4
         //--- needs it for this object type. Still throttled to the same
         //--- 150ms as the position update above, so this doesn't reopen
         //--- the original click-lag problem (ChartRedraw() fires at most
         //--- ~6-7x/sec, not once per mouse-move event).
         ChartRedraw();
      }
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE && drawMode == MODE_PATH && pathHasPoint)
   {
      static uint lastPathMoveMs = 0;
      uint nowMsP = GetTickCount();
      if(nowMsP - lastPathMoveMs < 150) return;
      lastPathMoveMs = nowMsP;

      datetime mTimeP; double mPriceP; int subWindowP;
      if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, subWindowP, mTimeP, mPriceP))
         UpdatePathPreview(pathTime, pathPrice, mTimeP, mPriceP);
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE && (drawMode == MODE_LINE || drawMode == MODE_DASH) && clickState == CLICK_WAIT_SECOND)  // v1.15: Dash همان رفتار Line
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
      return;
   }

   // v1.14 (اصلاح): پیش‌نمایش زنده‌ی Measure - همون الگوی throttle-شده‌ی MODE_LINE بالا، ولی
   // preview کامل ۷خط/۲مستطیل (BuildMeasureTool با isPreview=true) به‌جای یک خط تکی.
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
      ChartRedraw();  // BuildMeasureTool شامل چند آبجکت جداست (نه یک OBJ_TREND تکی مثل خط پیش‌نمایش خط) - رفرش صریح لازمه تا نلگه
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE && clickState == CLICK_WAIT_SECOND && drawMode != MODE_LINE && drawMode != MODE_DASH && drawMode != MODE_MEASURE)
   {
      static uint lastMoveMs = 0;
      uint nowMs = GetTickCount();
      if(nowMs - lastMoveMs < 150) return;
      lastMoveMs = nowMs;

      datetime mTime; double mPrice; int subWindow;
      if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, subWindow, mTime, mPrice))
         UpdatePreview(firstTime, firstPrice, mTime, mPrice);
      return;
   }

   if(id == CHARTEVENT_CLICK && drawMode == MODE_PATH)
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
         // v1.15: Horizontal Line - تک‌کلیک، بدون مرحله‌ی دوم؛ مثل بقیه‌ی ابزارها بعد از رسم، حالت ابزار تمام می‌شه.
         FinalizeHRay(clickTime, clickPrice);
         CancelDrawing();
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
         if(drawMode == MODE_LINE || drawMode == MODE_DASH)
         {
            datetime t2 = clickTime; double p2 = clickPrice;
            if(gShiftHeld)
               ApplyShiftSnap(firstPixelX, firstPixelY, cx, cy, firstTime, firstPrice, t2, p2);
            if(t2 == firstTime && p2 == firstPrice) return;
            if(drawMode == MODE_DASH) FinalizeDash(firstTime, firstPrice, t2, p2);  // v1.15
            else                      FinalizeLine(firstTime, firstPrice, t2, p2);
            CancelDrawing();
         }
         else if(drawMode == MODE_MEASURE)  // v1.14 (اصلاح)
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

void CancelDrawing()
{
   drawMode   = MODE_NONE;
   clickState = CLICK_IDLE;
   pathHasPoint = false;
   HighlightActiveButton(MODE_NONE);
   if(ObjectFind(0, PREVIEW_NAME) >= 0) ObjectDelete(0, PREVIEW_NAME);
   if(ObjectFind(0, PATH_PREVIEW_NAME) >= 0) ObjectDelete(0, PATH_PREVIEW_NAME);
   if(ObjectFind(0, LINE_PREVIEW_NAME) >= 0) ObjectDelete(0, LINE_PREVIEW_NAME);
   RemoveMeasureTool(MEASURE_PREVIEW_NAME);  // v1.14 (اصلاح): preview چند-آبجکتیه (نه یک آبجکت تکی مثل LINE_PREVIEW_NAME)
}

void UpdatePreview(datetime t1, double p1, datetime t2, double p2)
{
   color previewColor = ModeColor(drawMode);
   if(ObjectFind(0, PREVIEW_NAME) < 0)
   {
      ObjectCreate(0, PREVIEW_NAME, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, PREVIEW_NAME, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, PREVIEW_NAME, OBJPROP_FILL, false);
      ObjectSetInteger(0, PREVIEW_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, PREVIEW_NAME, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, PREVIEW_NAME, OBJPROP_BACK, false);
   }
   ObjectSetInteger(0, PREVIEW_NAME, OBJPROP_COLOR, previewColor);
   ObjectMove(0, PREVIEW_NAME, 0, t1, p1);
   ObjectMove(0, PREVIEW_NAME, 1, t2, p2);
}

//+------------------------------------------------------------------+
//| FEATURE (v1.08, Item 1): live label-position preview - reuses the  |
//| exact pattern proven by UpdatePreview()/UpdatePathPreview()/        |
//| UpdateLinePreview() above (create-once-then-move, non-selectable,   |
//| hidden from the object list). OBJ_TEXT here instead of OBJ_TREND/   |
//| OBJ_RECTANGLE so it shows the armed label's real text, not just a   |
//| dashed outline - there's no equivalent "outline-only" look for text.|
//+------------------------------------------------------------------+
void UpdateLabelPreview(string text, datetime t, double p)
{
   if(ObjectFind(0, LABEL_PREVIEW_NAME) < 0)
   {
      ObjectCreate(0, LABEL_PREVIEW_NAME, OBJ_TEXT, 0, t, p);
      ObjectSetInteger(0, LABEL_PREVIEW_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, LABEL_PREVIEW_NAME, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, LABEL_PREVIEW_NAME, OBJPROP_BACK, false);
   }
   ObjectSetString(0, LABEL_PREVIEW_NAME, OBJPROP_TEXT, text);
   ObjectSetInteger(0, LABEL_PREVIEW_NAME, OBJPROP_COLOR, Theme_ContrastSafe(gLabelColor));   // v1.17 (FEAT-052)
   ObjectSetInteger(0, LABEL_PREVIEW_NAME, OBJPROP_FONTSIZE, gLabelFontSize);
   ObjectMove(0, LABEL_PREVIEW_NAME, 0, t, p);
}

void DeleteLabelPreview()
{
   if(ObjectFind(0, LABEL_PREVIEW_NAME) >= 0) ObjectDelete(0, LABEL_PREVIEW_NAME);
}

// v1.17 (FEAT-052): ModeColor حالا رنگ خام (ModeColorRaw) را از کنتراست خودکار رد می‌کند؛ رنگ دکمه‌های پنل هنوز رنگ خام کاربر است.
color ModeColor(DRAW_MODE mode)
{
   return(Theme_ContrastSafe(ModeColorRaw(mode)));
}

color ModeColorRaw(DRAW_MODE mode)
{
   if(mode == MODE_FILL_A || mode == MODE_HOLLOW_A) return(gColorA);
   if(mode == MODE_FILL_B || mode == MODE_HOLLOW_B) return(gColorB);
   if(mode == MODE_FILL_C) return(gColorC);
   if(mode == MODE_FILL_D) return(gColorD);
   return(clrGray);
}

bool ModeIsFill(DRAW_MODE mode)
{
   return(mode == MODE_FILL_A || mode == MODE_FILL_B || mode == MODE_FILL_C || mode == MODE_FILL_D);
}

string ModeGroupTag(DRAW_MODE mode)
{
   if(mode == MODE_FILL_A || mode == MODE_HOLLOW_A) return("_A_");
   if(mode == MODE_FILL_B || mode == MODE_HOLLOW_B) return("_B_");
   if(mode == MODE_FILL_C) return("_C_");
   if(mode == MODE_FILL_D) return("_D_");
   return("_A_");
}

void FinalizeRectangle(datetime t1, double p1, datetime t2, double p2, DRAW_MODE mode)
{
   if(ObjectFind(0, PREVIEW_NAME) >= 0) ObjectDelete(0, PREVIEW_NAME);

   gCounter++;
   string name = PFX + ModeGroupTag(mode) + (string)TimeLocal() + "_" + (string)gCounter;
   color  clr  = ModeColor(mode);
   bool   fill = ModeIsFill(mode);

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, gStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, gWidth);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, fill);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

void HandlePathClick(int x, int y)
{
   uint nowMs = GetTickCount();
   bool isDoubleClick = pathHasPoint
                        && (nowMs - g_lastClickMs < 400)
                        && (MathAbs(x - g_lastClickX) < 6)
                        && (MathAbs(y - g_lastClickY) < 6);

   g_lastClickMs = nowMs;
   g_lastClickX  = x;
   g_lastClickY  = y;

   if(isDoubleClick)
   {
      CancelDrawing();
      return;
   }

   datetime t; double p; int sub;
   if(!ChartXYToTimePrice(0, x, y, sub, t, p)) return;

   if(!pathHasPoint)
   {
      pathTime  = t;
      pathPrice = p;
      pathHasPoint = true;
   }
   else
   {
      FinalizePathSegment(pathTime, pathPrice, t, p);
      pathTime  = t;
      pathPrice = p;
   }
}

void UpdatePathPreview(datetime t1, double p1, datetime t2, double p2)
{
   if(ObjectFind(0, PATH_PREVIEW_NAME) < 0)
   {
      ObjectCreate(0, PATH_PREVIEW_NAME, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, PATH_PREVIEW_NAME, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, PATH_PREVIEW_NAME, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, PATH_PREVIEW_NAME, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, PATH_PREVIEW_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, PATH_PREVIEW_NAME, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, PATH_PREVIEW_NAME, OBJPROP_BACK, false);
   }
   ObjectSetInteger(0, PATH_PREVIEW_NAME, OBJPROP_COLOR, Theme_ContrastSafe(gPathColor));   // v1.17 (FEAT-052)
   ObjectMove(0, PATH_PREVIEW_NAME, 0, t1, p1);
   ObjectMove(0, PATH_PREVIEW_NAME, 1, t2, p2);
}

void FinalizePathSegment(datetime t1, double p1, datetime t2, double p2)
{
   pathSegCounter++;
   string name = PFX + "Path_" + pathSessionId + "_seg" + (string)pathSegCounter;

   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gPathColor));   // v1.17 (FEAT-052)
   ObjectSetInteger(0, name, OBJPROP_WIDTH, gPathWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, gPathStyle);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

void ApplyShiftSnap(int x1, int y1, int x2, int y2, datetime t1, double p1, datetime &outT, double &outP)
{
   int dxPix = x2 - x1;
   int dyPix = y2 - y1;

   int sub;
   datetime t; double p;
   if(!ChartXYToTimePrice(0, x2, y2, sub, t, p))
   {
      outT = t1;
      outP = p1;
      return;
   }

   if(MathAbs(dxPix) >= MathAbs(dyPix))
   {
      outT = t;
      outP = p1;
   }
   else
   {
      outT = t1;
      outP = p;
   }
}

void UpdateLinePreview(datetime t1, double p1, datetime t2, double p2)
{
   if(ObjectFind(0, LINE_PREVIEW_NAME) < 0)
   {
      ObjectCreate(0, LINE_PREVIEW_NAME, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, LINE_PREVIEW_NAME, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, LINE_PREVIEW_NAME, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, LINE_PREVIEW_NAME, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, LINE_PREVIEW_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, LINE_PREVIEW_NAME, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, LINE_PREVIEW_NAME, OBJPROP_BACK, false);
   }
   ObjectSetInteger(0, LINE_PREVIEW_NAME, OBJPROP_COLOR, Theme_ContrastSafe((drawMode == MODE_DASH) ? gDashColor : gLineColor));  // v1.15 (revision) + v1.17 (FEAT-052)
   ObjectMove(0, LINE_PREVIEW_NAME, 0, t1, p1);
   ObjectMove(0, LINE_PREVIEW_NAME, 1, t2, p2);
}

// v1.15: نام آبجکت‌های دو ابزار جدید عمداً شامل "Line_" نیست ("HRay_" / "Dash_") - هندلر OBJECT_CHANGE برای نام‌های
// "Line_" رنگ/ضخامت/سبک پیش‌فرض ابزار Line رو تغییر می‌داد؛ نباید ویرایش این دو ابزار، پیش‌فرض Line رو دستکاری کنه.
void FinalizeHRay(datetime t1, double p1)
{
   gCounter++;
   string name = PFX + "HRay_" + (string)TimeLocal() + "_" + (string)gCounter;
   int ps = PeriodSeconds();
   if(ps <= 0) ps = 60;
   // خط افقی از نقطه‌ی کلیک تا بی‌نهایت سمت راست: OBJ_TREND افقی با RAY_RIGHT (نه OBJ_HLINE که دو طرفه‌ست و نه پاره‌خط محدود)
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t1 + ps, p1);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gHRayColor));   // v1.17 (FEAT-052)
   ObjectSetInteger(0, name, OBJPROP_WIDTH, gHRayWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, gHRayStyle);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

// v1.15: Dash Line - همان دو‌کلیک و همان Shift-snap ابزار Line؛ فقط سبک خط‌چین نازک (STYLE_DASH با ضخامت ۱ - در MT4
// سبک‌های خط‌چین فقط روی ضخامت ۱ رسم می‌شن، پس "نازک" عملاً الزامیه). رنگ = همان رنگ ابزار Line.
void FinalizeDash(datetime t1, double p1, datetime t2, double p2)
{
   if(ObjectFind(0, LINE_PREVIEW_NAME) >= 0) ObjectDelete(0, LINE_PREVIEW_NAME);

   gCounter++;
   string name = PFX + "Dash_" + (string)TimeLocal() + "_" + (string)gCounter;

   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gDashColor));   // v1.17 (FEAT-052)
   ObjectSetInteger(0, name, OBJPROP_WIDTH, gDashWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, gDashStyle);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

void FinalizeLine(datetime t1, double p1, datetime t2, double p2)
{
   if(ObjectFind(0, LINE_PREVIEW_NAME) >= 0) ObjectDelete(0, LINE_PREVIEW_NAME);

   gCounter++;
   string name = PFX + "Line_" + (string)TimeLocal() + "_" + (string)gCounter;

   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gLineColor));   // v1.17 (FEAT-052)
   ObjectSetInteger(0, name, OBJPROP_WIDTH, gLineWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, gLineStyle);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
//| v1.14 (اصلاح - FEAT-030 اصلی، درست‌جاش اینجاست نه RiskManager EA):  |
//| ابزار Measure Move - همون طراحی مرجعی که Mahmoud با تصویر فرستاد:  |
//| high/low بر اساس مقدار عددی واقعی تعیین می‌شن (MathMax/MathMin روی  |
//| دو نقطه‌ی کلیک‌شده)، نه ترتیب کلیک - پس جهت خط‌ها همیشه درسته صرف‌نظر |
//| از این‌که تریدر اول کجا کلیک کرده. نگاشت (rangeSize = high-low):    |
//|   measure       = high + 1.00×range   (بالاترین خط)                |
//|   range buffer  = high + 0.25×range                                |
//|   high          = high                                             |
//|   mid range     = (high+low)/2                                     |
//|   low           = low                                              |
//|   range buffer  = low  - 0.25×range                                |
//|   MEASURE       = low  - 1.00×range   (پایین‌ترین خط)              |
//| ۷ خط (OBJ_TREND، خط‌چین) + ۲ ناحیه‌ی شید‌دار (OBJ_RECTANGLE پرشده،   |
//| بین high/low و هر کدوم از دو range buffer) + ۷ لیبل (OBJ_TEXT).     |
//| صرفاً بصری - بدون هیچ منطق محاسباتی/اجرایی دیگه. isPreview=true     |
//| یعنی زیرآبجکت‌ها مخفی از Object List و غیرقابل‌انتخاب می‌مونن (مثل     |
//| LINE_PREVIEW_NAME)؛ isPreview=false یعنی دقیقاً مثل بقیه‌ی اشکال     |
//| دستی این پروژه (Line/Rectangle) - قابل‌انتخاب و توی Object List.     |
//+------------------------------------------------------------------+
#define MEAS_LEVEL_COUNT 7
// v1.14.1 (اصلاح - Mahmoud): رنگ‌ها دیگه ثابت نیستن - زنده از همون رنگ‌های Shade/Rectangle این
// مجموعه‌ی Draw خونده می‌شن، تا اگه کاربر رنگ Shade 3/4 یا Rectangle 2 رو عوض کنه، ابزار Range
// هم خودش‌به‌خود هماهنگ بمونه. خط‌ها هم‌رنگ Rectangle 2 (gColorB)، مستطیل بالا هم‌رنگ Shade 4
// (gColorD)، مستطیل پایین هم‌رنگ Shade 3 (gColorC).
color MeasLineColor() { return Theme_ContrastSafe(gColorB); }   // هم‌رنگ Rectangle 2 (v1.17 FEAT-052: + کنتراست خودکار)
color MeasBufTopColor()    { return Theme_ContrastSafe(gColorD); }   // هم‌رنگ Shade 4 - مستطیل بالا (سمت high/measure)
color MeasBufBottomColor() { return Theme_ContrastSafe(gColorC); }   // هم‌رنگ Shade 3 - مستطیل پایین (سمت low/MEASURE)

string MeasLineName(string base, int i)  { return base+"_LN"+IntegerToString(i); }
string MeasLabelName(string base, int i) { return base+"_LB"+IntegerToString(i); }
string MeasRectName(string base, int j)  { return base+"_RC"+IntegerToString(j); }

void MeasLine(string n, datetime t1, datetime t2, double priceLevel, color clr, int w, int style, bool isPreview)
{
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_TREND,0,t1,priceLevel,t2,priceLevel);
   ObjectSetInteger(0,n,OBJPROP_TIME1,  t1);
   ObjectSetDouble (0,n,OBJPROP_PRICE1, priceLevel);
   ObjectSetInteger(0,n,OBJPROP_TIME2,  t2);
   ObjectSetDouble (0,n,OBJPROP_PRICE2, priceLevel);
   ObjectSetInteger(0,n,OBJPROP_COLOR,  clr);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,  w);
   ObjectSetInteger(0,n,OBJPROP_STYLE,  style);
   ObjectSetInteger(0,n,OBJPROP_RAY_LEFT,  false);
   ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, !isPreview);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN, isPreview);
   ObjectSetInteger(0,n,OBJPROP_BACK, false);
}

void MeasLabel(string n, datetime t, double price, color clr, string txt, int fontSize, bool isPreview)
{
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_TEXT,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_TIME,  t);
   ObjectSetDouble (0,n,OBJPROP_PRICE, price);
   ObjectSetString (0,n,OBJPROP_TEXT,  txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR, clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE, fontSize);
   ObjectSetString (0,n,OBJPROP_FONT,  "Arial Bold");
   ObjectSetInteger(0,n,OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, !isPreview);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN, isPreview);
   ObjectSetInteger(0,n,OBJPROP_BACK, false);
}

void MeasRect(string n, datetime t1, datetime t2, double priceA, double priceB, color clr, bool isPreview)
{
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE,0,t1,priceA,t2,priceB);
   ObjectSetInteger(0,n,OBJPROP_TIME1,  t1);
   ObjectSetDouble (0,n,OBJPROP_PRICE1, priceA);
   ObjectSetInteger(0,n,OBJPROP_TIME2,  t2);
   ObjectSetDouble (0,n,OBJPROP_PRICE2, priceB);
   ObjectSetInteger(0,n,OBJPROP_COLOR,  clr);
   ObjectSetInteger(0,n,OBJPROP_STYLE,  STYLE_SOLID);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,  1);
   ObjectSetInteger(0,n,OBJPROP_FILL,   true);
   ObjectSetInteger(0,n,OBJPROP_BACK,   true);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, !isPreview);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN, isPreview);
}

void RemoveMeasureTool(string base)
{
   for(int i=0;i<MEAS_LEVEL_COUNT;i++)
   {
      ObjectDelete(0, MeasLineName(base,i));
      ObjectDelete(0, MeasLabelName(base,i));
   }
   ObjectDelete(0, MeasRectName(base,0));
   ObjectDelete(0, MeasRectName(base,1));
}

void BuildMeasureTool(string base, datetime t1, double p1, datetime t2, double p2, bool isPreview)
{
   // v1.14.2 (اصلاح - لگ Mahmoud): RemoveMeasureTool(base) که این‌جا بود، هر تیک پیش‌نمایش
   // (هر ۱۵۰ms، هم‌نرخ Line/Path) هر ۱۶ زیرآبجکت رو حذف و از نو می‌ساخت - برخلاف بقیه‌ی
   // ابزارهای این پنل (UpdateLinePreview/UpdatePathPreview) که فقط ObjectMove می‌زنن روی
   // همون آبجکت‌های موجود. حذف شد - MeasLine/MeasLabel/MeasRect خودشون از قبل الگوی
   // «فقط اگه نبود بساز، وگرنه فقط آپدیت کن» رو دارن (همون ObjectFind guard که HLine/
   // PreviewHLine هم دارن)، پس دیگه لازم نیست. برای نمونه‌های نهایی (اسم یکتا per-placement)
   // بی‌اثره چون ObjectFind همیشه پیدا نمی‌کنه و مستقیم می‌سازه - رفتار نهایی هیچ فرقی نکرد.

   double high  = MathMax(p1,p2);
   double low   = MathMin(p1,p2);
   double range = high-low;
   if(range<=0) { RemoveMeasureTool(base); return; }  // دو کلیک روی یک قیمت - چیزی برای رسم نیست؛ اگه پیش‌نمایش قبلی مونده بود پاکش کن

   double levelPrices[MEAS_LEVEL_COUNT];
   levelPrices[0] = high + 1.00*range;  // measure
   levelPrices[1] = high + 0.25*range;  // range buffer
   levelPrices[2] = high;               // high
   levelPrices[3] = (high+low)/2.0;     // mid range
   levelPrices[4] = low;                // low
   levelPrices[5] = low  - 0.25*range;  // range buffer
   levelPrices[6] = low  - 1.00*range;  // MEASURE

   string levelLbls[MEAS_LEVEL_COUNT] = {"measure","range buffer","high","mid range","low","range buffer","MEASURE"};

   // v1.14.1 (اصلاح - Mahmoud): همه‌ی ۷ خط یک استایل یکسان می‌گیرن - "خط‌چین ریز" (STYLE_DOT)،
   // به‌جای تمایز قبلی DASH/DASHDOTDOT بین measure/MEASURE و بقیه؛ همیشه یک ظاهر منظم و یکدست.
   color lineClr = MeasLineColor();
   for(int i=0;i<MEAS_LEVEL_COUNT;i++)
   {
      MeasLine(MeasLineName(base,i), t1, t2, levelPrices[i], lineClr, 1, STYLE_DOT, isPreview);
      bool isOuterMeasure = (i==0 || i==MEAS_LEVEL_COUNT-1);
      int fsz = isOuterMeasure ? 8 : 7;
      MeasLabel(MeasLabelName(base,i), t2, levelPrices[i], lineClr, levelLbls[i], fsz, isPreview);
   }

   // v1.14.1 (اصلاح - Mahmoud): مستطیل بالا هم‌رنگ Shade 4، مستطیل پایین هم‌رنگ Shade 3.
   // v1.14.3 (اصلاح - لگ Mahmoud، ادامه‌ی v1.14.2): حین پیش‌نمایش (isPreview=true، یعنی هنوز
   // کلیک دوم نخورده) دو مستطیل اصلاً ساخته نمی‌شن - فقط ۷ خط. رکتنگل سنگین‌ترین بخش هر تیکه
   // (OBJ_RECTANGLE با FILL/BACK)؛ نیازی نیست تا قبل از کلیک دوم دیده بشه. اگه از پیش‌نمایش
   // قبلی مونده باشه (مثلاً همین الان از حالت "بدون رنج" به حالت معتبر برگشتیم)، پاک می‌شن.
   if(isPreview)
   {
      ObjectDelete(0, MeasRectName(base,0));
      ObjectDelete(0, MeasRectName(base,1));
   }
   else
   {
      MeasRect(MeasRectName(base,0), t1, t2, levelPrices[2], levelPrices[1], MeasBufTopColor(),    isPreview);  // high..range buffer (بالا) - Shade 4
      MeasRect(MeasRectName(base,1), t1, t2, levelPrices[4], levelPrices[5], MeasBufBottomColor(), isPreview);  // low..range buffer (پایین) - Shade 3
   }
}

void FinalizeMeasure(datetime t1, double p1, datetime t2, double p2)
{
   RemoveMeasureTool(MEASURE_PREVIEW_NAME);
   gCounter++;
   // v1.14.1 (اصلاح - Mahmoud): پیشوند اشکال نهایی از "Measure_" به "Range_" تغییر کرد - هم‌نام
   // با اسم جدید دکمه (RANGE)، هم چیزی که ماشه‌ی گروه‌بندی/سلکت-یک‌جا (OnChartEvent، پایین‌تر
   // همین فایل) دنبالش می‌گرده.
   string base = PFX + "Range_" + (string)TimeLocal() + "_" + (string)gCounter;
   BuildMeasureTool(base, t1, p1, t2, p2, false);
}
//+------------------------------------------------------------------+
