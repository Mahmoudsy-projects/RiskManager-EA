//+------------------------------------------------------------------+
//| RM_Hub_PanelDrawLabel.mq5                                         |
//| Executive Hub — MT5 port, Stage 5e-i                               |
//| Ported from ExecutiveHub_v1_07.mq4                                 |
//|                                                                    |
//| SCOPE (per Stage5e-i_Task_Message.md): panel core, Draw tools,     |
//| Label tools, generic persistence helpers.                          |
//| NOT in this file: OnInit/OnDeinit/OnCalculate/OnTimer/OnChartEvent |
//| (5e-iv), POC_*/WMAP_*/SOB_*/NYE_*/MTFCP_* (5e-ii), EMA_* + buffer   |
//| setup (5e-iii). Those modules' button-name #defines and visibility |
//| booleans ARE declared here (CreateButtons/PositionButtons/         |
//| ApplyIndicatorsMinimizedState reference them directly) - this is   |
//| plain shared state, not module logic, so it isn't a "stub" in the  |
//| same sense as the EA port's stub functions. No actual POC_/WMAP_/  |
//| SOB_/NYE_/MTFCP_/EMA_ function was needed anywhere in this sub-    |
//| stage's scope - confirmed by reading every in-scope function.      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Inputs used by this sub-stage's functions                          |
//+------------------------------------------------------------------+
input color DefaultColorA      = clrSilver;
input color DefaultColorB      = clrDimGray;
input color DefaultColorC      = clrTurquoise;
input color DefaultColorD      = clrLightPink;
input int   DefaultBorderWidth = 2;
input color DefaultPathColor   = clrBlue;   // v1.14: پیش‌فرض Path ۱ آبی (قبلاً خاکستری)؛ رنگ ذخیره‌شده‌ی قبلی تغییری نمی‌کند
input int   DefaultPathWidth   = 2;
input color DefaultLineColor   = clrRed;
input int   DefaultLineWidth   = 3;
input color DefaultPath2Color  = clrRed;    // v1.14: Path ۲ - قرمز
input int   DefaultPath2Width  = 2;
input color DefaultLine2Color  = clrBlue;   // v1.14: Line ۲ - آبی
input int   DefaultLine2Width  = 3;
input int   PanelTopY          = 29;
input int   PanelWidth         = 195;
input int   BtnHeight          = 22;
input int   BtnGap             = 4;
input int   MasterBtnWidth     = 58;
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

//--- Floors chosen by inspecting each: BTNWIDTH_FLOOR is roughly the
//--- narrowest a BtnWidth-sized cell (Arial Bold, FontSize=7) can go before
//--- "GOLDEN ZONE"/"BREAKEVEN"/"LIQUIDITY" (the 3 longest LabelList
//--- entries) start clipping or crowding their button's edges.
//--- MASTERBTNWIDTH_FLOOR does the same for the 3 master buttons' own
//--- longest text ("Label -"/"Indicator -" style toggle labels).
//--- BTNGAP_FLOOR just keeps adjacent buttons from visually touching.
#define BTNWIDTH_FLOOR       50
#define MASTERBTNWIDTH_FLOOR 34
#define BTNGAP_FLOOR         1

input int   LabelDefaultFontSize  = 10;
input color LabelDefaultColor     = clrDimGray;
input int   LabelBtnHeight        = 18;

input color  HubBgColor     = C'22,25,35';
input color  HubBorderColor = C'50,54,68';

//+------------------------------------------------------------------+
//| Object name / key constants                                       |
//+------------------------------------------------------------------+
#define PFX          "DrawPanel_"
#define BTN_FA       PFX+"Btn_FillA"
#define BTN_FB       PFX+"Btn_FillB"
#define BTN_FC       PFX+"Btn_FillC"
#define BTN_FD       PFX+"Btn_FillD"
#define BTN_HA       PFX+"Btn_HollowA"
#define BTN_HB       PFX+"Btn_HollowB"
#define BTN_PATH     PFX+"Btn_Path"
#define BTN_LINE     PFX+"Btn_Line"
#define BTN_HLINE    PFX+"Btn_HLine"   // v1.10 (MT4 v1.15): خط افقی - یک کلیک، ray به راست
#define BTN_PATH2    PFX+"Btn_Path2"  // v1.14: Path دوم (پیش‌فرض قرمز، رنگ/ضخامت/استایل مستقل)
#define BTN_LINE2    PFX+"Btn_Line2"  // v1.14: Line دوم (پیش‌فرض آبی، مستقل)
#define BTN_DASH     PFX+"Btn_Dash"    // v1.10 (MT4 v1.15): خط‌چین - مثل Line
#define BTN_MEASURE  PFX+"Btn_Measure" // v1.11 (MT4 v1.14): RANGE - بیرون گرید، زیر سه دکمه‌ی مادر
#define MEASURE_PREVIEW_NAME PFX+"MeasurePreview"
#define BTN_MASTER_DRAW PFX+"Btn_MasterDraw"
#define PREVIEW_NAME PFX+"Preview"
#define PATH_PREVIEW_NAME PFX+"PathPreview"
#define LINE_PREVIEW_NAME PFX+"LinePreview"
//--- FEATURE (v1.08, Item 1): live label-position preview - same family as
//--- the 3 Draw-tool previews above, just for the armed Label grid.
#define LABEL_PREVIEW_NAME PFX+"LabelPreview"
#define TOOL_COUNT 2
#define TOOL_COUNT_ITEMS 12   // v1.10: ۸ -> ۱۰؛ v1.14: ۱۰ -> ۱۲ (Path 2 + Line 2)

#define BTN_MASTER_LABELS PFX+"Btn_MasterLabels"
// v1.11 (MT4 v1.15/v1.16): ۱۸ جایگاه ثابت؛ ۱۶ تای اول در گرید اصلی، ۲ تای آخر (SP2L, BTB) در فضای خالی زیر سه دکمه‌ی مادر.
// متن هر جایگاه از فایل RM_HubLabels.txt (MQL5\Files) خوانده می‌شود؛ HubLabelDefault فقط پیش‌فرض/seed است.
#define LABEL_COUNT      18
#define LABEL_GRID_COUNT 16
#define LABEL_MAX_CHARS  20
#define HUB_LABELS_FILE    "RM_HubLabels.txt"
#define HUB_LABELS_BACKUP  "RM_HubLabels_backup.txt"
#define HUB_LABELS_VERSION 116   // هم‌شماره با MT4 v1.16 - لیست پیش‌فرض جدید؛ مهاجرت یک‌باره با بکاپ
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
      if(StringGetCharacter(line, 0) == '#') continue;

      int colonPos = StringFind(line, ":");
      if(colonPos < 1) continue;

      string key  = StringSubstr(line, 0, colonPos);
      string text = StringSubstr(line, colonPos + 1);
      StringTrimLeft(key);  StringTrimRight(key);
      StringTrimLeft(text); StringTrimRight(text);

      int kc = StringGetCharacter(key, 0);
      if(kc != 'L' && kc != 'l') continue;
      int slot = (int)StringToInteger(StringSubstr(key, 1));
      if(slot < 1 || slot > LABEL_COUNT) continue;

      if(StringLen(text) > LABEL_MAX_CHARS) text = StringSubstr(text, 0, LABEL_MAX_CHARS);
      LabelList[slot - 1] = text;   // متن خالی عمداً پذیرفته می‌شود -> دکمه مخفی
   }
   FileClose(h);
}

// الگوی seed/مهاجرت: فایل نبود -> seed؛ فایل بود ولی نسخه‌ی GV قدیمی -> بکاپ + جایگزینی یک‌باره با پیش‌فرض.
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

// فونت دکمه با طول متن و عرض واقعی دکمه کوچک می‌شود (از ۷ تا حداقل ۵). تخمین Arial Bold ≈ 0.9 x فونت برای هر کاراکتر، با ۶ پیکسل حاشیه.
int HubLabelFontSize(string t)
{
   int n = StringLen(t);
   int w = (g_effBtnWidth > 0) ? g_effBtnWidth : 52;
   double avail = (double)(w - 6);
   int fs = 7;
   while(fs > 5 && (double)n * 0.9 * (double)fs > avail) fs--;
   return(fs);
}

#define BTN_MASTER_INDICATOR PFX+"Btn_MasterIndicator"

#define CLR_SUBTOGGLE_ACTIVE C'0,150,150'
#define CLR_INACTIVE_GRAY C'70,70,80'
#define HUB_BG_NAME    PFX+"HubBg"

//--- v1.12 (MT4 v1.17 FEAT-052): دکمه‌ی مادر چهارم «Theme» + کشوی ۷ تم رنگی چارت + «Original».
//--- THEME_ORIG_NAME = آبجکت مخفیِ نگه‌دارنده‌ی رنگ‌های اصلی چارت (قبل از اولین تم) - عمداً "Btn_" ندارد و
//--- در OnDeinit / RaiseHubPanelToFront پاک نمی‌شود (روی تغییر تایم‌فریم/ری‌لود/ری‌استارت و حتی حذف Hub می‌ماند).
#define BTN_MASTER_THEME PFX+"Btn_MasterTheme"
#define BTN_THEME_ORIG   PFX+"Btn_Theme_Orig"
#define THEME_COUNT      10   // v1.13: ۷ -> ۱۰ (تم‌های ۸، ۹، ۱۰ زیر سه دکمه‌ی مادر Indicator/Label/Draw)
#define THEME_GRID_COUNT 7    // تم‌های ۱..۷ در شبکه‌ی ۴ستونه؛ تم‌های ۸..۱۰ زیر مادرها؛ Original در جایگاه هشتم شبکه
#define THEME_KEEP       ((color)0x02000000)   // علامت «این رنگ را دست نزن» (Bid/Last برای تم‌های ۱-۷ و Original قدیمی TO1)
#define THEME_ORIG_NAME  PFX+"ThemeOrig"
//--- v1.16: دکمه‌ی Original برداشته شد و «Custom» جایش آمد: Custom (اعمال) + S (ذخیره‌ی رنگ‌های فعلی چارت) + R (پاک‌کردن). ذخیره در GlobalVariable
//--- سراسری ترمینال => روی همه‌ی چارت‌ها یکی است و تا R نزنید می‌ماند. BTN_THEME_ORIG فقط برای پاک‌کردن بقایای نسخه‌های قبل نگه داشته شده.
#define BTN_THEME_CUSTOM PFX+"Btn_Theme_Custom"
#define BTN_THEME_CSAVE  PFX+"Btn_Theme_CSave"
#define BTN_THEME_CRESET PFX+"Btn_Theme_CReset"
#define THEME_CUSTOM_IDX 99
#define GV_CUSTOM_SET    (PFX + "CustThm_Set")
#define GV_CUSTOM_FL     (PFX + "CustThm_Fl")
bool gThemeMinimized = true;   // کشوی Theme (چهارمین کشوی هم‌محل)
int  g_themeActive   = -1;     // اندیس تم فعال (0..9) یا -1 = هیچ (Original / ناشناخته)

//--- خواندن رنگ چارت برای محاسبات کنتراست. ChartSetInteger ممکن است ناهمگام باشد (خواندن بلافاصله بعدش مقدار قدیمی بدهد)،
//--- پس موقع recolour یک‌باره‌ی بعد از کلیک تم، رنگ‌های تازه مستقیم از این override می‌آیند (g_ovOn=true فقط داخل Theme_RecolourOnce).
bool  g_ovOn   = false;
color g_ovBg   = clrBlack;
color g_ovFg   = clrWhite;
color g_ovBull = clrWhite;
color g_ovBear = clrGray;
color Hub_ChartBg()   { return(g_ovOn ? g_ovBg   : (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND)); }
color Hub_ChartFg()   { return(g_ovOn ? g_ovFg   : (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND)); }
color Hub_ChartBull() { return(g_ovOn ? g_ovBull : (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BULL)); }
color Hub_ChartBear() { return(g_ovOn ? g_ovBear : (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR)); }

//--- کنتراست خودکارِ رنگ‌های ثابتِ آبجکت‌های Hub: اگر اختلاف luminance رنگ با پس‌زمینه کمتر از THEME_CONTRAST_MIN_DIFF باشد،
//--- رنگ را (روی پس‌زمینه‌ی تیره روشن‌تر / روی روشن تیره‌تر) در گام‌های ۳۰تایی جابه‌جا می‌کند؛ در غیر این‌صورت دقیقاً همان رنگ برمی‌گردد.
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

#define PANEL_ZORDER_BG      1000000
#define PANEL_ZORDER_FG      1000001
#define PANEL_ZORDER_FG_TOP  1000002

// --- Module 1/2/3 button names - real port target of 5e-ii/5e-iii, but
// --- CreateButtons()/PositionButtons()/ApplyIndicatorsMinimizedState() in
// --- THIS sub-stage's scope reference them directly, so the names + their
// --- plain boolean visibility state must exist here now.
#define BTN_POC          PFX+"Btn_POC"
#define BTN_WMAP PFX+"Btn_WMAP"
#define BTN_SOB  PFX+"Btn_SOB"
#define BTN_NYE  PFX+"Btn_NYE"
#define BTN_MTFCP PFX+"Btn_MTFCP"
#define BTN_EMA10    PFX+"Btn_EMA10"
#define BTN_EMA20    PFX+"Btn_EMA20"
#define BTN_EMA60    PFX+"Btn_EMA60"
#define BTN_EMA240   PFX+"Btn_EMA240"

bool pocActive      = false;   // [5e-ii scope - real logic] plain state only, referenced by CreateButtons()
bool wmapVisible    = false;   // [5e-ii scope - real logic] plain state only
bool sobVisible     = false;   // [5e-ii scope - real logic] plain state only
bool nyeVisible     = false;   // [5e-ii scope - real logic] plain state only
bool mtfcpVisible   = false;   // [5e-iii scope - real logic] plain state only
bool gShowEMA10  = true;       // [5e-iii scope - real logic] plain state only
bool gShowEMA20  = true;
bool gShowEMA60  = true;
bool gShowEMA240 = true;

//+------------------------------------------------------------------+
//| Panel-core state                                                   |
//+------------------------------------------------------------------+
bool g_hubNeedsRaise = false;  // consumed by OnTimer's 1s debounce - OnTimer is 5e-iv scope, declared
                                // here only because RaiseHubPanelToFront()'s own header comment refers
                                // to it; this sub-stage cannot test the actual ≤1/second throttle
                                // behaviour since the consuming loop doesn't exist yet (see report).

//+------------------------------------------------------------------+
//| Draw-tool state                                                    |
//+------------------------------------------------------------------+
enum DRAW_MODE { MODE_NONE, MODE_FILL_A, MODE_FILL_B, MODE_FILL_C, MODE_FILL_D, MODE_HOLLOW_A, MODE_HOLLOW_B, MODE_PATH, MODE_LINE, MODE_HLINE, MODE_DASH, MODE_MEASURE, MODE_PATH2, MODE_LINE2 };
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
color gHRayColor, gDashColor;   // v1.10: پیش‌فرض جدا برای خط افقی و Dash (مثل Line/Path)
int   gHRayWidth, gDashWidth;
color gPath2Color, gLine2Color;   // v1.14
int   gPath2Width, gLine2Width, gPath2Style, gLine2Style;
int   gHRayStyle, gDashStyle;
int   gWidth, gPathWidth, gLineWidth;
int   gStyle, gPathStyle, gLineStyle;
int   gCounter = 0;
bool  gDrawMinimized = false;

//+------------------------------------------------------------------+
//| Label-tool state                                                   |
//+------------------------------------------------------------------+
string armedLabel = "";
color  gLabelColor;
int    gLabelFontSize;
bool   gLabelsMinimized = false;

bool   gIndicatorsMinimized = false;

//+------------------------------------------------------------------+
//| IsHubPanelOwnedObject / RaiseHubPanelToFront                       |
//| Ported literally as-is (delete-and-recreate approach) per the task |
//| message's explicit instruction - do NOT assume MT5 handles visual  |
//| stacking differently until 5e-iv can test it with real clicks.     |
//+------------------------------------------------------------------+
bool IsHubPanelOwnedObject(string name)
{
   if(name == HUB_BG_NAME) return(true);
   if(StringFind(name, "Btn_") >= 0) return(true);
   return(false);
}

void RaiseHubPanelToFront()
{
   ObjectDelete(0, HUB_BG_NAME);
   ObjectDelete(0, BTN_MASTER_DRAW);
   ObjectDelete(0, BTN_MASTER_LABELS);
   ObjectDelete(0, BTN_MASTER_INDICATOR);
   ObjectDelete(0, BTN_MASTER_THEME);   // v1.12: فقط دکمه‌ها؛ آبجکت مخفیِ THEME_ORIG_NAME عمداً دست‌نخورده
   for(int ti = 0; ti < THEME_COUNT; ti++)
      ObjectDelete(0, Theme_BtnName(ti));
   ObjectDelete(0, BTN_THEME_ORIG);
   ObjectDelete(0, BTN_THEME_CUSTOM); ObjectDelete(0, BTN_THEME_CSAVE); ObjectDelete(0, BTN_THEME_CRESET);   // v1.16

   string toolNames[TOOL_COUNT_ITEMS] = {BTN_FA, BTN_FB, BTN_FC, BTN_FD, BTN_HA, BTN_HB, BTN_PATH, BTN_LINE, BTN_PATH2, BTN_LINE2, BTN_HLINE, BTN_DASH};
   for(int i = 0; i < TOOL_COUNT_ITEMS; i++)
      ObjectDelete(0, toolNames[i]);
   ObjectDelete(0, BTN_MEASURE);   // v1.11: بیرون آرایه‌ی TOOL_COUNT_ITEMS

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
   ApplyThemeMinimizedState();   // v1.12
   //--- BUG-FIX (v1.07, lag): single redraw here now that the Apply*
   //--- functions no longer redraw themselves.
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Panel core                                                         |
//+------------------------------------------------------------------+
void CreateButtons()
{
   // باید همین اول ساخته بشه، قبل از هر دکمه‌ای - چون MT4 آبجکت‌ها رو بر
   // اساس ترتیب ساخت روی هم می‌کشه (نه OBJPROP_ZORDER که فقط اولویت کلیکه)،
   // پس اگه این بعد از دکمه‌ها ساخته/آپدیت بشه، روی دکمه‌ها می‌شینه و
   // قایمشون می‌کنه - دقیقاً همون باگی که Mahmoud گزارش داد.
   // [MT5 NOTE] whether MT5 shares this creation-order-decides-visual-stacking
   // behaviour is exactly the open question flagged for 5e-iv - ported as-is.
   UpdateHubBackground();

   CreateOneButton(BTN_FA, "Shade 1", gColorA);
   CreateOneButton(BTN_FB, "Shade 2", gColorB);
   CreateOneButton(BTN_FC, "Shade 3", gColorC);
   CreateOneButton(BTN_FD, "Shade 4", gColorD);
   CreateOneButton(BTN_HA, "Rectangle 1", gColorA);
   CreateOneButton(BTN_HB, "Rectangle 2", gColorB);
   CreateOneButton(BTN_PATH, "Path", gPathColor);
   CreateOneButton(BTN_LINE, "Line", gLineColor);
   CreateOneButton(BTN_PATH2, "Path 2", gPath2Color);   // v1.14
   CreateOneButton(BTN_LINE2, "Line 2", gLine2Color);   // v1.14
   CreateOneButton(BTN_HLINE, "Horizontal Line", gHRayColor);   // v1.10
   ObjectSetInteger(0, BTN_HLINE, OBJPROP_FONTSIZE, 6);         // متن بلندتر؛ با فونت ۷ روی عرض‌های کوچک‌شده بیرون می‌زند
   CreateOneButton(BTN_DASH, "Dash Line", gDashColor);          // v1.10
   CreateOneButton(BTN_MEASURE, "RANGE", CLR_INACTIVE_GRAY);    // v1.11: توگل‌مانند (خاکستری=غیرفعال / فیروزه‌ای=مسلح)
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

   Theme_CreateButtons();   // v1.12 (FEAT-052): دکمه‌ی مادر چهارم + کشوی Theme
}

void ApplyDrawMinimizedState()
{
   if(gDrawMinimized) CancelDrawing();

   long tf = gDrawMinimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
   string names[TOOL_COUNT_ITEMS] = {BTN_FA, BTN_FB, BTN_FC, BTN_FD, BTN_HA, BTN_HB, BTN_PATH, BTN_LINE, BTN_PATH2, BTN_LINE2, BTN_HLINE, BTN_DASH};
   for(int i = 0; i < TOOL_COUNT_ITEMS; i++)
      ObjectSetInteger(0, names[i], OBJPROP_TIMEFRAMES, tf);
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_TIMEFRAMES, tf);   // v1.11: بیرون آرایه‌ی گرید ولی همان show/hide
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
   // v1.12 (FEAT-052): دکمه‌ی مادر چهارم Theme
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
   int gridXStart = xStart + 4 * (g_effMasterBtnWidth + g_effBtnGap);   // v1.12: ۴ دکمه‌ی مادر (قبلاً ۳)
   int gridRow0Y = PanelTopY;
   int gridRow1YTools = gridRow0Y + BtnHeight + g_effBtnGap;
   int gridRow1YLabels = gridRow1YTools;   // v1.11: ردیف دوم لیبل = ردیف دوم بلوک چپ (ارتفاع Master)

   // v1.11 (MT4 v1.14): دکمه‌ی RANGE (Measure Move) و جایگاه‌های SP2L/BTB دقیقاً در فضای خالی ردیف۱ زیر سه دکمه‌ی مادر
   // می‌نشینند؛ عرضشان کل آن فضا (سه مادر + دو gap) را پر می‌کند. (در v1.12 با دکمه‌ی Theme: ۴ مادر + ۳ gap)
   int measureBtnWidth = 4 * g_effMasterBtnWidth + 3 * g_effBtnGap;   // v1.12: با دکمه‌ی Theme، فضای زیر مادرها ۴ دکمه + ۳ gap
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_XDISTANCE, xStart);
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_YDISTANCE, gridRow1YTools);
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_XSIZE, measureBtnWidth);

   //--- ۱۰ ابزار رسم، شبکه‌ی ۲ردیفی (TOOL_COUNT=2 ردیف)، افقی جلو می‌ره،
   //--- سمت راست ۳ دکمه‌ی مادر
   string toolNames[TOOL_COUNT_ITEMS] = {BTN_FA, BTN_FB, BTN_FC, BTN_FD, BTN_HA, BTN_HB, BTN_PATH, BTN_LINE, BTN_PATH2, BTN_LINE2, BTN_HLINE, BTN_DASH};
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
      ObjectSetInteger(0, LabelButtonName(i), OBJPROP_XDISTANCE, gridXStart + col * (g_effBtnWidth + g_effBtnGap));
      ObjectSetInteger(0, LabelButtonName(i), OBJPROP_YDISTANCE, row == 0 ? gridRow0Y : gridRow1YLabels);
      ObjectSetInteger(0, LabelButtonName(i), OBJPROP_XSIZE, g_effBtnWidth);
   }
   // v1.11: جایگاه‌های ۱۷ و ۱۸ (SP2L, BTB) در فضای خالی زیر سه دکمه‌ی مادر (همان ناحیه‌ای که در تب Draw دکمه‌ی RANGE می‌گیرد)
   // - عرض پنل عوض نمی‌شود.
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
   // هر ۱۸ دکمه دقیقاً ارتفاع Master؛ فونت با عرض مؤثر فعلی دوباره تنظیم می‌شود.
   for(int li = 0; li < LABEL_COUNT; li++)
   {
      string lnm = LabelButtonName(li);
      ObjectSetInteger(0, lnm, OBJPROP_YSIZE, BtnHeight);
      ObjectSetInteger(0, lnm, OBJPROP_FONTSIZE, HubLabelFontSize(LabelList[li]));
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

   Theme_PositionButtons(gridXStart, gridRow0Y, gridRow1YTools, xStart);   // v1.12 (FEAT-052): ۷ تم + Original (۲ ردیف × ۴ ستون)

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
   return(ComputeContentWidth(g_effBtnWidth, g_effMasterBtnWidth, g_effBtnGap));
}

//+------------------------------------------------------------------+
//| FEATURE (v1.08, Item 2): same math PanelContentWidth() always had, |
//| pulled out so it can be evaluated for ANY (btnW, masterW, gap)     |
//| triple - RecomputeEffectiveSizes() below calls it once with the    |
//| raw inputs (the "full size" baseline) and PanelContentWidth() now  |
//| calls it with whatever the current effective sizes are.            |
//+------------------------------------------------------------------+
//--- v1.13: عرض یکسان همه‌ی دکمه‌های تب Theme. سه دکمه‌ی ۸/۹/۱۰ دقیقاً زیر ۴ دکمه‌ی مادر را پر می‌کنند (بدون جای خالی)
//--- و شبکه‌ی ۴×۲ سمت راست (۱..۷ + Original) همین عرض را دارد.
int ThemeBtnW(int masterW, int gap)
{
   return((4 * masterW + gap) / 3);
}

int ComputeContentWidth(int btnW, int masterW, int gap)
{
   int masterRowWidth = 4 * masterW + 3 * gap;   // v1.12: ۴ دکمه‌ی مادر (Indicator/Label/Draw/Theme)

   int gridWidth = 0;
   if(!gDrawMinimized)
      gridWidth = GridCols(TOOL_COUNT_ITEMS) * btnW + (GridCols(TOOL_COUNT_ITEMS) - 1) * gap;
   else if(!gLabelsMinimized)
      gridWidth = GridCols(LABEL_GRID_COUNT) * btnW + (GridCols(LABEL_GRID_COUNT) - 1) * gap;   // v1.11: فقط ۱۶ جایگاه گرید
   else if(!gIndicatorsMinimized)
      gridWidth = GridCols(9) * btnW + (GridCols(9) - 1) * gap;
   else if(!gThemeMinimized)
      gridWidth = 4 * ThemeBtnW(masterW, gap) + 3 * gap;   // v1.13: ۴ ستون؛ عرض هر دکمه‌ی تم = یک‌سوم عرض ردیف ۴ دکمه‌ی مادر (همه‌ی ۱۱ دکمه هم‌اندازه)

   if(gridWidth == 0)
      return(masterRowWidth); // هیچ کشویی باز نیست - فقط عرض ۳ دکمه‌ی مادر
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
   int fullWidth = ComputeContentWidth(BtnWidth, MasterBtnWidth, BtnGap);

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
      return;
   }

   double ratio = (double)MathMax(available, 0) / (double)fullWidth;

   int candidateBtnWidth       = (int)MathRound(BtnWidth * ratio);
   int candidateMasterBtnWidth = (int)MathRound(MasterBtnWidth * ratio);
   int candidateBtnGap         = (int)MathRound(BtnGap * ratio);

   g_effBtnWidth       = (int)MathMax(BTNWIDTH_FLOOR, MathMin(BtnWidth, candidateBtnWidth));
   g_effMasterBtnWidth = (int)MathMax(MASTERBTNWIDTH_FLOOR, MathMin(MasterBtnWidth, candidateMasterBtnWidth));
   g_effBtnGap         = (int)MathMax(BTNGAP_FLOOR, MathMin(BtnGap, candidateBtnGap));

   //--- FIX (found live, Mahmoud's narrow-window test): the floor above is
   //--- a *readability* target, not a *fits-on-screen* guarantee - on a
   //--- narrow enough chart, content sized at the floor can still be wider
   //--- than chartWidth itself (which is already UsableChartWidth(), i.e.
   //--- already net of RiskManager EA's reserved zone), which is exactly
   //--- what let the Hub grid overlap RiskManager EA's own panel. Not
   //--- overlapping another indicator's panel is a hard correctness
   //--- requirement, not a nice-to-have - readability has to lose this
   //--- trade-off in extreme cases, so if the floored size still doesn't
   //--- fit within chartWidth, scale down BELOW the floor (no minimum other
   //--- than staying visually non-zero) until it does. This never fires on
   //--- a normal-width chart - it's strictly a last-resort safety net for
   //--- windows too narrow for even the floor to satisfy.
   int flooredContentWidth = ComputeContentWidth(g_effBtnWidth, g_effMasterBtnWidth, g_effBtnGap);
   if(flooredContentWidth > chartWidth && chartWidth > 0)
   {
      double emergencyRatio = (double)chartWidth / (double)flooredContentWidth;
      g_effBtnWidth       = (int)MathMax(1, MathRound(g_effBtnWidth       * emergencyRatio));
      g_effMasterBtnWidth = (int)MathMax(1, MathRound(g_effMasterBtnWidth * emergencyRatio));
      g_effBtnGap         = (int)MathMax(0, MathRound(g_effBtnGap         * emergencyRatio));
   }
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
      row1HeightPx = BtnHeight + g_effBtnGap;   // v1.11: ارتفاع Master
   else if(!gIndicatorsMinimized)
      row1HeightPx = BtnHeight + g_effBtnGap;
   else if(!gThemeMinimized)
      row1HeightPx = BtnHeight + g_effBtnGap;   // v1.12
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
   all[4] = BTN_HA; all[5] = BTN_HB; all[6] = BTN_PATH; all[7] = BTN_LINE; all[8] = BTN_PATH2; all[9] = BTN_LINE2; all[10] = BTN_HLINE; all[11] = BTN_DASH;

   color fullColors[TOOL_COUNT_ITEMS];
   fullColors[0] = gColorA; fullColors[1] = gColorB; fullColors[2] = gColorC; fullColors[3] = gColorD;
   fullColors[4] = gColorA; fullColors[5] = gColorB; fullColors[6] = gPathColor; fullColors[7] = gLineColor; fullColors[8] = gPath2Color; fullColors[9] = gLine2Color; fullColors[10] = gHRayColor; fullColors[11] = gDashColor;

   int activeIdx = -1;
   if(mode == MODE_FILL_A)   activeIdx = 0;
   if(mode == MODE_FILL_B)   activeIdx = 1;
   if(mode == MODE_FILL_C)   activeIdx = 2;
   if(mode == MODE_FILL_D)   activeIdx = 3;
   if(mode == MODE_HOLLOW_A) activeIdx = 4;
   if(mode == MODE_HOLLOW_B) activeIdx = 5;
   if(mode == MODE_PATH)     activeIdx = 6;
   if(mode == MODE_LINE)     activeIdx = 7;
   if(mode == MODE_PATH2)    activeIdx = 8;   // v1.14
   if(mode == MODE_LINE2)    activeIdx = 9;   // v1.14
   if(mode == MODE_HLINE)    activeIdx = 10;  // v1.10
   if(mode == MODE_DASH)     activeIdx = 11;  // v1.10

   for(int i = 0; i < TOOL_COUNT_ITEMS; i++)
      ObjectSetInteger(0, all[i], OBJPROP_BGCOLOR, (i == activeIdx) ? fullColors[i] : DimColor(fullColors[i]));

   // v1.11: RANGE رنگ کاربر ندارد؛ همان قرارداد teal/gray توگل‌های دیگر
   ObjectSetInteger(0, BTN_MEASURE, OBJPROP_BGCOLOR, (mode == MODE_MEASURE) ? CLR_SUBTOGGLE_ACTIVE : CLR_INACTIVE_GRAY);
}

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
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Draw tools                                                         |
//+------------------------------------------------------------------+
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
         // v1.11 (MT4 v1.14): زیرآبجکت‌های ابزار Range با _LN<i>/_LB<i>/_RC<j> تمام می‌شوند - همان منطق گروه‌بندی Path
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
      // [MT5 translation, CORRECTED after live compiler feedback from Mahmoud] my first pass
      // assumed OBJPROP_TIME1/TIME2/PRICE1/PRICE2 existed in MT5 under those names - they don't.
      // MT5 has no per-point property constants at all; instead OBJPROP_TIME/OBJPROP_PRICE take
      // the point index (0 or 1) as a 4th argument. Point 1 -> index 0, point 2 -> index 1.
      g_groupSnapT1[n] = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 0);
      g_groupSnapP1[n] = ObjectGetDouble(0, nm, OBJPROP_PRICE, 0);
      g_groupSnapT2[n] = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 1);
      g_groupSnapP2[n] = ObjectGetDouble(0, nm, OBJPROP_PRICE, 1);
   }
}

//+------------------------------------------------------------------+
//| v1.14: جابه‌جایی گروهی Path / Path 2 مستقل از ترتیب رویداد کلیک.   |
//| مشکل: در MT5 اسنپ‌شات گروه فقط هنگام رویداد OBJECT_CLICK ساخته می‌شد؛ |
//| اگر آن رویداد قبل از شروع درگ نمی‌رسید (یا نرسیده بود)، فقط همان    |
//| قطعه جابه‌جا می‌شد. حالا موقعیت همه‌ی قطعه‌های Path همیشه در یک    |
//| اسنپ‌شات سراسری نگه داشته می‌شود (هنگام ساخت قطعه، شروع Hub و بعد   |
//| از هر درگ) و درگ هر قطعه، بقیه‌ی قطعه‌های همان مسیر را هم می‌برد.  |
//+------------------------------------------------------------------+
string   g_pathSnapNames[];
datetime g_pathSnapT1[];
double   g_pathSnapP1[];
datetime g_pathSnapT2[];
double   g_pathSnapP2[];

bool IsPathSegName(string nm)
{
   if(StringFind(nm, "_seg") < 0) return(false);
   return(StringFind(nm, PFX + "Path_") == 0 || StringFind(nm, PFX + "Path2_") == 0);
}

int PathSnap_Find(string nm)
{
   for(int i = 0; i < ArraySize(g_pathSnapNames); i++)
      if(g_pathSnapNames[i] == nm) return(i);
   return(-1);
}

void PathSnap_Store(string nm)
{
   int i = PathSnap_Find(nm);
   if(i < 0)
   {
      i = ArraySize(g_pathSnapNames);
      ArrayResize(g_pathSnapNames, i + 1);
      ArrayResize(g_pathSnapT1, i + 1);
      ArrayResize(g_pathSnapP1, i + 1);
      ArrayResize(g_pathSnapT2, i + 1);
      ArrayResize(g_pathSnapP2, i + 1);
      g_pathSnapNames[i] = nm;
   }
   g_pathSnapT1[i] = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 0);
   g_pathSnapP1[i] = ObjectGetDouble(0, nm, OBJPROP_PRICE, 0);
   g_pathSnapT2[i] = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 1);
   g_pathSnapP2[i] = ObjectGetDouble(0, nm, OBJPROP_PRICE, 1);
}

void PathSnap_Rebuild()
{
   ArrayResize(g_pathSnapNames, 0);
   int total = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < total; i++)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(IsPathSegName(nm)) PathSnap_Store(nm);
   }
}

void HandlePathGroupDrag(string draggedName)
{
   int idx = PathSnap_Find(draggedName);
   if(idx < 0) { PathSnap_Store(draggedName); return; }

   datetime newT1 = (datetime)ObjectGetInteger(0, draggedName, OBJPROP_TIME, 0);
   double   newP1 = ObjectGetDouble(0, draggedName, OBJPROP_PRICE, 0);
   datetime newT2 = (datetime)ObjectGetInteger(0, draggedName, OBJPROP_TIME, 1);
   double   newP2 = ObjectGetDouble(0, draggedName, OBJPROP_PRICE, 1);

   long   dT1 = (long)newT1 - (long)g_pathSnapT1[idx];
   double dP1 = newP1 - g_pathSnapP1[idx];
   long   dT2 = (long)newT2 - (long)g_pathSnapT2[idx];
   double dP2 = newP2 - g_pathSnapP2[idx];

   // v1.14b: در MT5 هنگام درگ، زمان هر دو سر به نزدیک‌ترین کندل گرد می‌شود، پس دلتای دو سر دقیقاً برابر نیست
   // (لاگ واقعی: dT1=1144 ولی whole=false). «کل قطعه جابه‌جا شد» = هر دو سر حرکت کرده‌اند و دلتاها نزدیک‌اند؛
   // درگ یک سر = دلتای سر دیگر صفر.
   int ps = PeriodSeconds(); if(ps <= 0) ps = 60;
   bool p1Moved = (dT1 != 0 || MathAbs(dP1) > 0.0000001);
   bool p2Moved = (dT2 != 0 || MathAbs(dP2) > 0.0000001);
   double dPmax = MathMax(MathAbs(dP1), MathAbs(dP2));
   bool whole = p1Moved && p2Moved && (MathAbs((double)(dT1 - dT2)) <= 2.0 * ps) && (MathAbs(dP1 - dP2) <= 0.25 * dPmax + 0.0000001);
   if(!whole || (dT1 == 0 && dP1 == 0))
   {
      PathSnap_Store(draggedName);   // فقط یک سر قطعه عوض شده (یا حرکتی نبوده): فقط همان قطعه
      return;
   }

   // v1.14c: گرد شدن زمان به کندل باعث می‌شد دو سر قطعه‌ی کشیده‌شده کمی نابرابر جابه‌جا شوند و رأس مشترک با قطعه‌ی بعدی
   // از هم جدا شود (شکل مسیر عوض می‌شد). راه‌حل: خودِ قطعه هم دقیقاً با همان دلتای سر اول (جابه‌جایی صلب) تنظیم می‌شود.
   {
      datetime fixT2 = (datetime)((long)g_pathSnapT2[idx] + dT1);
      double   fixP2 = g_pathSnapP2[idx] + dP1;
      ObjectMove(0, draggedName, 1, fixT2, fixP2);
   }
   string prefix = StringSubstr(draggedName, 0, StringFind(draggedName, "_seg") + 4);
   int n = ArraySize(g_pathSnapNames);
   for(int i = 0; i < n; i++)
   {
      if(i == idx) continue;
      string nm = g_pathSnapNames[i];
      if(StringFind(nm, prefix) != 0) continue;
      if(ObjectFind(0, nm) < 0) continue;
      ObjectMove(0, nm, 0, (datetime)((long)g_pathSnapT1[i] + dT1), g_pathSnapP1[i] + dP1);
      ObjectMove(0, nm, 1, (datetime)((long)g_pathSnapT2[i] + dT1), g_pathSnapP2[i] + dP1);
      PathSnap_Store(nm);
   }
   PathSnap_Store(draggedName);
   ChartRedraw();
}

void HandleGroupDrag(string draggedName)
{
   if(IsPathSegName(draggedName)) { HandlePathGroupDrag(draggedName); return; }   // v1.14
   int idx = -1;
   for(int i = 0; i < ArraySize(g_groupSnapNames); i++)
      if(g_groupSnapNames[i] == draggedName) { idx = i; break; }
   if(idx < 0) return;

   // [MT5 translation, corrected] same OBJPROP_TIME/OBJPROP_PRICE + point-index fix as above.
   datetime newT1 = (datetime)ObjectGetInteger(0, draggedName, OBJPROP_TIME, 0);
   double   newP1 = ObjectGetDouble(0, draggedName, OBJPROP_PRICE, 0);
   datetime newT2 = (datetime)ObjectGetInteger(0, draggedName, OBJPROP_TIME, 1);
   double   newP2 = ObjectGetDouble(0, draggedName, OBJPROP_PRICE, 1);

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

void CancelDrawing()
{
   drawMode   = MODE_NONE;
   clickState = CLICK_IDLE;
   pathHasPoint = false;
   HighlightActiveButton(MODE_NONE);
   if(ObjectFind(0, PREVIEW_NAME) >= 0) ObjectDelete(0, PREVIEW_NAME);
   if(ObjectFind(0, PATH_PREVIEW_NAME) >= 0) ObjectDelete(0, PATH_PREVIEW_NAME);
   if(ObjectFind(0, LINE_PREVIEW_NAME) >= 0) ObjectDelete(0, LINE_PREVIEW_NAME);
   RemoveMeasureTool(MEASURE_PREVIEW_NAME);   // v1.11: پیش‌نمایش چندآبجکتی (نه یک آبجکت تکی)
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

color ModeColor(DRAW_MODE mode)
{
   return(Theme_ContrastSafe(ModeColorRaw(mode)));   // v1.12: رنگ خام از کنتراست خودکار رد می‌شود؛ رنگ دکمه‌های پنل همچنان رنگ خام کاربر است
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
   ObjectSetInteger(0, PATH_PREVIEW_NAME, OBJPROP_COLOR, Theme_ContrastSafe((drawMode == MODE_PATH2) ? gPath2Color : gPathColor));   // v1.14
   ObjectMove(0, PATH_PREVIEW_NAME, 0, t1, p1);
   ObjectMove(0, PATH_PREVIEW_NAME, 1, t2, p2);
}

void FinalizePathSegment(datetime t1, double p1, datetime t2, double p2)
{
   pathSegCounter++;
   bool isP2 = (drawMode == MODE_PATH2);   // v1.14: Path ۲ پیشوند «Path2_» (گروه‌بندی با _seg مثل Path)
   string name = PFX + (isP2 ? "Path2_" : "Path_") + pathSessionId + "_seg" + (string)pathSegCounter;

   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(isP2 ? gPath2Color : gPathColor));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, isP2 ? gPath2Width : gPathWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, isP2 ? gPath2Style : gPathStyle);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   PathSnap_Store(name);   // v1.14: موقعیت قطعه‌ی تازه در اسنپ‌شات سراسری
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
   ObjectSetInteger(0, LINE_PREVIEW_NAME, OBJPROP_COLOR, Theme_ContrastSafe((drawMode == MODE_DASH) ? gDashColor : ((drawMode == MODE_LINE2) ? gLine2Color : gLineColor)));   // v1.10 + v1.12 + v1.14
   ObjectMove(0, LINE_PREVIEW_NAME, 0, t1, p1);
   ObjectMove(0, LINE_PREVIEW_NAME, 1, t2, p2);
}

// v1.10 (MT4 v1.15): نام «HRay_» / «Dash_» عمداً شامل «Line_» نیست تا ویرایش این دو ابزار پیش‌فرض Line را عوض نکند.
void FinalizeHRay(datetime t1, double p1)
{
   gCounter++;
   string name = PFX + "HRay_" + (string)TimeLocal() + "_" + (string)gCounter;
   int ps = PeriodSeconds();
   if(ps <= 0) ps = 60;
   // خط افقی از نقطه‌ی کلیک تا بی‌نهایت سمت راست: OBJ_TREND افقی با RAY_RIGHT
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t1 + ps, p1);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gHRayColor));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, gHRayWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, gHRayStyle);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

// v1.10 (MT4 v1.15): Dash Line - همان دو‌کلیک و Shift-snap ابزار Line؛ سبک خط‌چین نازک.
void FinalizeDash(datetime t1, double p1, datetime t2, double p2)
{
   if(ObjectFind(0, LINE_PREVIEW_NAME) >= 0) ObjectDelete(0, LINE_PREVIEW_NAME);

   gCounter++;
   string name = PFX + "Dash_" + (string)TimeLocal() + "_" + (string)gCounter;

   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gDashColor));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, gDashWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, gDashStyle);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

// v1.14: Line دوم - مثل Line ولی نام «Line2_» (که شامل «Line_» نیست) و پیش‌فرض‌های مستقل
void FinalizeLine2(datetime t1, double p1, datetime t2, double p2)
{
   if(ObjectFind(0, LINE_PREVIEW_NAME) >= 0) ObjectDelete(0, LINE_PREVIEW_NAME);

   gCounter++;
   string name = PFX + "Line2_" + (string)TimeLocal() + "_" + (string)gCounter;

   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gLine2Color));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, gLine2Width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, gLine2Style);
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
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gLineColor));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, gLineWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, gLineStyle);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
//| Label tools                                                        |
//+------------------------------------------------------------------+
string LabelButtonName(int idx)
{
   // v1.11: نام آبجکت بر اساس شماره‌ی جایگاه (نه متن) - چون متن حالا از فایل قابل‌ویرایش است (تکراری/خالی/کاراکتر خاص نباید نام را خراب کند)
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
         ObjectSetInteger(0, name, OBJPROP_XSIZE, g_effBtnWidth);
         ObjectSetInteger(0, name, OBJPROP_YSIZE, BtnHeight);   // v1.11: ارتفاع Master (هم‌ردیف با ابزارها)
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
      // v1.11: جایگاه خالی در RM_HubLabels.txt = دکمه همیشه مخفی (حتی وقتی تب Label باز است)
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
   ObjectSetInteger(0, LABEL_PREVIEW_NAME, OBJPROP_COLOR, Theme_ContrastSafe(gLabelColor));
   ObjectSetInteger(0, LABEL_PREVIEW_NAME, OBJPROP_FONTSIZE, gLabelFontSize);
   ObjectMove(0, LABEL_PREVIEW_NAME, 0, t, p);
}

void DeleteLabelPreview()
{
   if(ObjectFind(0, LABEL_PREVIEW_NAME) >= 0) ObjectDelete(0, LABEL_PREVIEW_NAME);
}

void PlaceLabel(string text, datetime t, double p)
{
   gCounter++;
   string clean = text;
   StringReplace(clean, " ", "_");
   string name = PFX + "Lbl_" + clean + "_" + (string)TimeLocal() + "_" + (string)gCounter;

   ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Theme_ContrastSafe(gLabelColor));
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, gLabelFontSize);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
//| Generic persistence helpers                                        |
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

color ComputeContrastGray()
{
   long bg = (long)Hub_ChartBg();   // v1.12: override-aware
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
//| v1.11 (پورت از MT4 Hub v1.14): ابزار Measure Move (دکمه‌ی RANGE)    |
//| high/low از مقدار عددی دو نقطه‌ی کلیک (MathMax/MathMin) - جهت کلیک مهم |
//| نیست. نگاشت (range = high-low):                                    |
//|   measure = high+1.00*range، range buffer = high+0.25*range، high،  |
//|   mid range، low، range buffer = low-0.25*range، MEASURE = low-1.00*range |
//| ۷ خط (OBJ_TREND نقطه‌چین) + ۲ مستطیل پر (high..buffer بالا، low..buffer |
//| پایین) + ۷ لیبل (OBJ_TEXT). صرفاً بصری. isPreview=true: مخفی/غیرقابل‌انتخاب |
//+------------------------------------------------------------------+
#define MEAS_LEVEL_COUNT 7
// رنگ‌ها زنده از رنگ‌های Shade/Rectangle همین Hub: خط‌ها = Rectangle 2 (gColorB)، مستطیل بالا = Shade 4 (gColorD)، پایین = Shade 3 (gColorC)
color MeasLineColor()      { return(Theme_ContrastSafe(gColorB)); }   // v1.12: + کنتراست خودکار
color MeasBufTopColor()    { return(Theme_ContrastSafe(gColorD)); }
color MeasBufBottomColor() { return(Theme_ContrastSafe(gColorC)); }

string MeasLineName(string base, int i)  { return(base+"_LN"+IntegerToString(i)); }
string MeasLabelName(string base, int i) { return(base+"_LB"+IntegerToString(i)); }
string MeasRectName(string base, int j)  { return(base+"_RC"+IntegerToString(j)); }

void MeasLine(string n, datetime t1, datetime t2, double priceLevel, color clr, int w, int style, bool isPreview)
{
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_TREND,0,t1,priceLevel,t2,priceLevel);
   // [MT5] ثابت‌های OBJPROP_TIME1/PRICE1 وجود ندارند: OBJPROP_TIME/OBJPROP_PRICE با اندیس نقطه
   ObjectSetInteger(0,n,OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0,n,OBJPROP_PRICE, 0, priceLevel);
   ObjectSetInteger(0,n,OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0,n,OBJPROP_PRICE, 1, priceLevel);
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
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_TEXT,0,t,price);
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
   ObjectSetInteger(0,n,OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0,n,OBJPROP_PRICE, 0, priceA);
   ObjectSetInteger(0,n,OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0,n,OBJPROP_PRICE, 1, priceB);
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
   // MeasLine/MeasLabel/MeasRect الگوی «اگر نبود بساز، وگرنه فقط به‌روز کن» دارند؛ پس پیش‌نمایش هر ۱۵۰ms حذف/ساخت مجدد نمی‌شود.
   double high  = MathMax(p1,p2);
   double low   = MathMin(p1,p2);
   double range = high-low;
   if(range<=0) { RemoveMeasureTool(base); return; }

   double levelPrices[MEAS_LEVEL_COUNT];
   levelPrices[0] = high + 1.00*range;  // measure
   levelPrices[1] = high + 0.25*range;  // range buffer
   levelPrices[2] = high;               // high
   levelPrices[3] = (high+low)/2.0;     // mid range
   levelPrices[4] = low;                // low
   levelPrices[5] = low  - 0.25*range;  // range buffer
   levelPrices[6] = low  - 1.00*range;  // MEASURE

   string levelLbls[MEAS_LEVEL_COUNT] = {"measure","range buffer","high","mid range","low","range buffer","MEASURE"};

   color lineClr = MeasLineColor();
   for(int i=0;i<MEAS_LEVEL_COUNT;i++)
   {
      MeasLine(MeasLineName(base,i), t1, t2, levelPrices[i], lineClr, 1, STYLE_DOT, isPreview);
      bool isOuterMeasure = (i==0 || i==MEAS_LEVEL_COUNT-1);
      int fsz = isOuterMeasure ? 8 : 7;
      MeasLabel(MeasLabelName(base,i), t2, levelPrices[i], lineClr, levelLbls[i], fsz, isPreview);
   }

   // حین پیش‌نمایش دو مستطیل ساخته نمی‌شوند (سنگین‌ترین بخش)؛ فقط ۷ خط. با کلیک دوم ساخته می‌شوند.
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
   // پیشوند «Range_» - هم‌نام دکمه‌ی RANGE و همان چیزی که ماشه‌ی گروه‌بندی/سلکت-یک‌جا دنبالش می‌گردد
   string base = PFX + "Range_" + (string)TimeLocal() + "_" + (string)gCounter;
   BuildMeasureTool(base, t1, p1, t2, p2, false);
}

//+------------------------------------------------------------------+
//| v1.12 (پورت از MT4 Hub v1.17 FEAT-052) - Chart Themes              |
//| دکمه‌ی مادر Theme + کشوی ۷ تم + Original. هر کلیک فقط یک‌بار رنگ‌های   |
//| چارتِ فعلی را عوض می‌کند؛ بدون تایمر/polling. فقط چارت فعلی.            |
//+------------------------------------------------------------------+
//--- جدول ثابت ۱۰ تم (v1.13). ستون Button = رنگ Bull candle. Line/Vol/Ask/Stop حالا برای هر تم جدا؛ Bid/Last فقط
//--- برای تم‌های ۴، ۸، ۹، ۱۰ تعیین شده و برای بقیه THEME_KEEP (دست‌نخورده) است.
color THEME_BG[THEME_COUNT]     = {C'169,169,169', C'0,0,0',       C'0,0,0',       C'0,0,0',     C'192,192,192', C'0,0,0',       C'16,20,26',    C'255,255,255', C'255,255,255', C'255,255,255'};
color THEME_FG[THEME_COUNT]     = {C'0,0,0',       C'255,255,255', C'255,255,255', C'255,255,255', C'0,0,0',      C'255,255,255', C'210,214,220', C'0,0,0',       C'0,0,0',       C'0,0,0'};
color THEME_GRID[THEME_COUNT]   = {C'0,0,0',       C'128,128,128', C'128,128,128', C'35,38,46',  C'128,128,128', C'128,128,128', C'35,38,46',    C'192,192,192', C'241,236,242', C'241,236,242'};
color THEME_BARUP[THEME_COUNT]  = {C'0,0,0',       C'218,165,32',  C'0,100,0',     C'255,255,255', C'0,0,0',      C'211,211,211', C'38,166,154',  C'0,0,0',       C'0,0,0',       C'31,137,126'};
color THEME_BARDN[THEME_COUNT]  = {C'0,0,0',       C'192,192,192', C'218,165,32',  C'102,102,102', C'0,0,0',      C'128,0,0',     C'239,83,80',   C'0,0,0',       C'178,34,34',   C'0,0,0'};
color THEME_BULL[THEME_COUNT]   = {C'95,158,160',  C'218,165,32',  C'0,100,0',     C'240,240,240', C'255,255,255', C'211,211,211', C'38,166,154',  C'255,255,255', C'255,255,255', C'192,241,236'};
color THEME_BEAR[THEME_COUNT]   = {C'253,245,230', C'192,192,192', C'218,165,32',  C'0,0,0',     C'128,128,128', C'128,0,0',     C'239,83,80',   C'0,0,0',       C'255,179,179', C'255,255,255'};
color THEME_LINE[THEME_COUNT]   = {C'105,105,105', C'105,105,105', C'105,105,105', C'105,105,105', C'105,105,105', C'105,105,105', C'105,105,105', C'0,0,0',       C'86,186,132',  C'86,186,132'};
color THEME_VOL[THEME_COUNT]    = {C'105,105,105', C'105,105,105', C'105,105,105', C'105,105,105', C'105,105,105', C'105,105,105', C'105,105,105', C'0,128,0',     C'38,166,154',  C'38,166,154'};
color THEME_ASK[THEME_COUNT]    = {C'166,90,62',   C'166,90,62',   C'166,90,62',   C'166,90,62', C'166,90,62',   C'166,90,62',   C'166,90,62',   C'192,192,192', C'239,83,80',   C'239,83,80'};
color THEME_STOP[THEME_COUNT]   = {C'122,59,52',   C'122,59,52',   C'122,59,52',   C'122,59,52', C'122,59,52',   C'122,59,52',   C'122,59,52',   C'255,69,0',    C'239,83,80',   C'239,83,80'};
color THEME_BID[THEME_COUNT]    = {THEME_KEEP, THEME_KEEP, THEME_KEEP, C'192,192,192', THEME_KEEP, THEME_KEEP, THEME_KEEP, C'192,192,192', C'38,166,154', C'38,166,154'};
color THEME_LAST[THEME_COUNT]   = {THEME_KEEP, THEME_KEEP, THEME_KEEP, C'192,192,192', THEME_KEEP, THEME_KEEP, THEME_KEEP, C'192,192,192', C'156,186,240', C'156,186,240'};

//--- کدگذاری فشرده (base64 دستی) برای ذخیره‌ی Original داخل متن آبجکت مخفی (v1.13: فرمت TO2 با ۱۳ رنگ؛ TO1 قدیمی ۱۱ رنگ هنوز خوانده می‌شود):
//--- "TO2:" + ۱۳ رنگ x ۴ کاراکتر + ۳ کاراکتر ماسک clrNONE + ۱ کاراکتر پرچم‌ها = ۶۰ کاراکتر
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
   string s = "TO2:";
   int mask = 0;
   for(int i = 0; i < 13; i++)
   {
      int v = 0;
      if(c[i] == clrNONE) mask |= (1 << i);
      else if(c[i] == THEME_KEEP) v = 0;
      else                v = (int)c[i];
      for(int k = 3; k >= 0; k--)
         s += Theme_B64Char((v >> (6 * k)) & 63);
   }
   s += Theme_B64Char(mask & 63);
   s += Theme_B64Char((mask >> 6) & 63);
   s += Theme_B64Char((mask >> 12) & 63);
   int fl = (grid ? 1 : 0) | (shift ? 2 : 0) | (askLine ? 4 : 0) | ((mode & 3) << 3);
   s += Theme_B64Char(fl);
   return(s);
}

bool Theme_Decode(string s, color &c[], bool &grid, bool &shift, bool &askLine, int &mode)
{
   int nCol = 0, maskLen = 0;
   string tag = StringSubstr(s, 0, 4);
   if(tag == "TO2:" && StringLen(s) == 60) { nCol = 13; maskLen = 3; }
   else if(tag == "TO1:" && StringLen(s) == 51) { nCol = 11; maskLen = 2; }   // فرمت قدیمی Hub 1.12
   else return(false);
   int mpos = 4 + nCol * 4;
   int mask = 0;
   for(int m = 0; m < maskLen; m++)
   {
      int mv = Theme_B64Val(StringSubstr(s, mpos + m, 1));
      if(mv < 0) return(false);
      mask |= (mv << (6 * m));
   }
   int fl = Theme_B64Val(StringSubstr(s, mpos + maskLen, 1));
   if(fl < 0) return(false);
   for(int i = 0; i < nCol; i++)
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
   if(nCol == 11) { c[11] = THEME_KEEP; c[12] = THEME_KEEP; }   // Original قدیمی: Bid/Last ثبت نشده -> دست‌نخورده
   grid    = ((fl & 1) != 0);
   shift   = ((fl & 2) != 0);
   askLine = ((fl & 4) != 0);
   mode    = (fl >> 3) & 3;
   return(true);
}

//--- ترتیب ۱۳ رنگ: 0 Background, 1 Foreground, 2 Grid, 3 BarUp, 4 BarDown, 5 CandleBull, 6 CandleBear,
//--- 7 LineGraph, 8 Volumes, 9 Ask, 10 StopLevels, 11 Bid, 12 Last
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
   c[11] = (color)ChartGetInteger(0, CHART_COLOR_BID);
   c[12] = (color)ChartGetInteger(0, CHART_COLOR_LAST);
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
   if(c[11] != THEME_KEEP) ChartSetInteger(0, CHART_COLOR_BID,  c[11]);   // v1.13
   if(c[12] != THEME_KEEP) ChartSetInteger(0, CHART_COLOR_LAST, c[12]);
   ChartSetInteger(0, CHART_SHOW_GRID,         grid);
   ChartSetInteger(0, CHART_SHIFT,             shift);
   ChartSetInteger(0, CHART_MODE,              mode);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE,     askLine);
}

//--- Original: یک‌بار، دقیقاً قبل از اولین تم روی این چارت ذخیره می‌شود و بعدش هرگز بازنویسی نمی‌شود (فقط اگر آبجکت نباشد یا
//--- متنش خراب باشد دوباره ساخته می‌شود). اگر ذخیره نشد، تم اعمال نمی‌شود (جلوگیری از گم‌شدن رنگ‌های کاربر).
bool Theme_EnsureOriginalStored()
{
   color tc[13]; bool tg, ts, ta; int tm;
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

//--- v1.16: تم Custom - ذخیره‌ی سراسری (GlobalVariable) ۱۳ رنگ + Grid/Shift/AskLine/Mode
bool Theme_CustomExists()
{
   return(GlobalVariableCheck(GV_CUSTOM_SET) && GlobalVariableGet(GV_CUSTOM_SET) != 0.0);
}

bool Theme_CustomLoad(color &c[], bool &grid, bool &shift, bool &askLine, int &mode)
{
   if(!Theme_CustomExists()) return(false);
   for(int i = 0; i < 13; i++)
   {
      string k = PFX + "CustThm_c" + IntegerToString(i);
      if(!GlobalVariableCheck(k)) return(false);
      c[i] = (color)(long)GlobalVariableGet(k);
   }
   int fl = (int)GlobalVariableGet(GV_CUSTOM_FL);
   grid    = ((fl & 1) != 0);
   shift   = ((fl & 2) != 0);
   askLine = ((fl & 4) != 0);
   mode    = (fl >> 3) & 3;
   return(true);
}

void Theme_CustomSaveCurrent()
{
   color c[13]; bool g, s, a; int m;
   Theme_ReadChart(c, g, s, a, m);
   for(int i = 0; i < 13; i++)
      GlobalVariableSet(PFX + "CustThm_c" + IntegerToString(i), (double)(long)c[i]);
   int fl = (g ? 1 : 0) | (s ? 2 : 0) | (a ? 4 : 0) | ((m & 3) << 3);
   GlobalVariableSet(GV_CUSTOM_FL, (double)fl);
   GlobalVariableSet(GV_CUSTOM_SET, 1.0);
   g_themeActive = THEME_CUSTOM_IDX;
   Theme_RefreshButtons();
   ChartRedraw();
   Print("ExecutiveHub: Custom theme saved from the current chart colours (applies to all charts).");
}

void Theme_CustomReset()
{
   GlobalVariableSet(GV_CUSTOM_SET, 0.0);
   if(g_themeActive == THEME_CUSTOM_IDX) g_themeActive = -1;
   Theme_RefreshButtons();
   ChartRedraw();
   Print("ExecutiveHub: Custom theme cleared.");
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
   if(Theme_CustomExists())   // v1.16: اگر چارت با Custom ذخیره‌شده یکی است
   {
      color cu[13]; bool cg, cs, ca; int cm;
      if(Theme_CustomLoad(cu, cg, cs, ca, cm) && bg == cu[0] && fg == cu[1] && bull == cu[5] && bear == cu[6])
         return(THEME_CUSTOM_IDX);
   }
   return(-1);
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
   ObjectSetInteger(0, name, OBJPROP_XSIZE, g_effBtnWidth);
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
   ObjectDelete(0, BTN_THEME_ORIG);   // v1.16: بقایای نسخه‌ی قبل
   Theme_CreateOneButton(BTN_THEME_CUSTOM, "Custom", 6, "Custom theme (your saved chart colours, same on all charts)");
   Theme_CreateOneButton(BTN_THEME_CSAVE,  "S", 7, "SAVE the current chart colours as Custom (set colours first with F8)");
   Theme_CreateOneButton(BTN_THEME_CRESET, "R", 7, "RESET: clear the saved Custom theme");
   Theme_RefreshButtons();
}

//--- پس‌زمینه‌ی هر دکمه = رنگ Bull همان تم (فعال: کامل، غیرفعال: کم‌رنگ با DimColor)؛ متن سیاه/سفید بر اساس luminance؛
//--- اگر پس‌زمینه به رنگ بدنه‌ی پنل (HubBgColor) خیلی نزدیک باشد (مثلاً تم ۳ فعال) دورِ روشن می‌گیرد.
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
   if(ObjectFind(0, BTN_THEME_CUSTOM) >= 0)   // v1.16
   {
      color cbg = CLR_INACTIVE_GRAY;
      color cu[13]; bool cg, cs, ca; int cm;
      if(Theme_CustomExists() && Theme_CustomLoad(cu, cg, cs, ca, cm))
         cbg = (g_themeActive == THEME_CUSTOM_IDX) ? cu[5] : DimColor(cu[5]);
      bool needB = (MathAbs(Theme_Lum(cbg) - Theme_Lum(HubBgColor)) < 40);
      ObjectSetInteger(0, BTN_THEME_CUSTOM, OBJPROP_BORDER_COLOR, needB ? (color)C'200,200,200' : cbg);
      ObjectSetInteger(0, BTN_THEME_CUSTOM, OBJPROP_BGCOLOR, cbg);
      ObjectSetInteger(0, BTN_THEME_CUSTOM, OBJPROP_COLOR, (Theme_Lum(cbg) > 140) ? clrBlack : clrWhite);
   }
   string sbtn[2]; sbtn[0] = BTN_THEME_CSAVE; sbtn[1] = BTN_THEME_CRESET;
   for(int q = 0; q < 2; q++)
      if(ObjectFind(0, sbtn[q]) >= 0)
      {
         ObjectSetInteger(0, sbtn[q], OBJPROP_BORDER_COLOR, CLR_INACTIVE_GRAY);
         ObjectSetInteger(0, sbtn[q], OBJPROP_BGCOLOR, CLR_INACTIVE_GRAY);
         ObjectSetInteger(0, sbtn[q], OBJPROP_COLOR, clrWhite);
      }
}

void ApplyThemeMinimizedState()
{
   long tf = gThemeMinimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
   for(int i = 0; i < THEME_COUNT; i++)
      ObjectSetInteger(0, Theme_BtnName(i), OBJPROP_TIMEFRAMES, tf);
   ObjectSetInteger(0, BTN_THEME_CUSTOM, OBJPROP_TIMEFRAMES, tf);   // v1.16
   ObjectSetInteger(0, BTN_THEME_CSAVE,  OBJPROP_TIMEFRAMES, tf);
   ObjectSetInteger(0, BTN_THEME_CRESET, OBJPROP_TIMEFRAMES, tf);
   ObjectSetString(0, BTN_MASTER_THEME, OBJPROP_TEXT, gThemeMinimized ? "Theme +" : "Theme −");
   ObjectSetInteger(0, BTN_MASTER_THEME, OBJPROP_BGCOLOR, gThemeMinimized ? CLR_INACTIVE_GRAY : clrSeaGreen);
   //--- (v1.07 lag rule) بدون UpdateHubBackground()/ChartRedraw() - صدازننده‌ها PositionButtons() و یک ChartRedraw() دارند.
}

//--- شبکه‌ی ۲ ردیف × ۴ ستون، سمت راست ۴ دکمه‌ی مادر: ردیف ۰ = تم ۱..۴، ردیف ۱ = تم ۵..۷ + Original.
//--- v1.13: تم‌های ۸، ۹، ۱۰ در فضای خالی ردیف ۱ زیر سه دکمه‌ی مادر Indicator/Label/Draw (هم‌عرض مادرها).
void Theme_PositionButtons(int gridX, int row0Y, int row1Y, int masterX)
{
   // v1.14: ترتیب خواندن پشت‌سرهم: ردیف ۱ (بالا، سمت راست) = ۱..۴؛ ردیف ۲ = ۵،۶،۷ (زیر مادرها) سپس ۸،۹،۱۰ و Original (شبکه)
   int tw = ThemeBtnW(g_effMasterBtnWidth, g_effBtnGap);
   for(int i = 0; i < THEME_COUNT; i++)   // v1.16: Original حذف شد؛ جایگاه ۱۱ام برای Custom/S/R
   {
      string nm = Theme_BtnName(i);
      int x, y;
      if(i < 4)                      { x = gridX + i * (tw + g_effBtnGap);              y = row0Y; }   // ۱..۴
      else if(i < 7)                 { x = masterX + (i - 4) * (tw + g_effBtnGap);      y = row1Y; }   // ۵..۷ زیر مادرها
      else                           { x = gridX + (i - 7) * (tw + g_effBtnGap);        y = row1Y; }   // ۸..۱۰ و Original (i==10 -> ستون ۴م)
      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, nm, OBJPROP_XSIZE, tw);
      ObjectSetInteger(0, nm, OBJPROP_YSIZE, BtnHeight);
   }
   // v1.16: جایگاه ستون ۴م ردیف ۲ = Custom (۴۸٪) + S + R
   int slotX = gridX + 3 * (tw + g_effBtnGap);
   int mg = 2;
   int cW = tw * 48 / 100;
   int sW = (tw - cW - 2 * mg) / 2;
   int rW = tw - cW - sW - 2 * mg;
   ObjectSetInteger(0, BTN_THEME_CUSTOM, OBJPROP_XDISTANCE, slotX);
   ObjectSetInteger(0, BTN_THEME_CUSTOM, OBJPROP_YDISTANCE, row1Y);
   ObjectSetInteger(0, BTN_THEME_CUSTOM, OBJPROP_XSIZE, cW);
   ObjectSetInteger(0, BTN_THEME_CUSTOM, OBJPROP_YSIZE, BtnHeight);
   ObjectSetInteger(0, BTN_THEME_CSAVE, OBJPROP_XDISTANCE, slotX + cW + mg);
   ObjectSetInteger(0, BTN_THEME_CSAVE, OBJPROP_YDISTANCE, row1Y);
   ObjectSetInteger(0, BTN_THEME_CSAVE, OBJPROP_XSIZE, sW);
   ObjectSetInteger(0, BTN_THEME_CSAVE, OBJPROP_YSIZE, BtnHeight);
   ObjectSetInteger(0, BTN_THEME_CRESET, OBJPROP_XDISTANCE, slotX + cW + mg + sW + mg);
   ObjectSetInteger(0, BTN_THEME_CRESET, OBJPROP_YDISTANCE, row1Y);
   ObjectSetInteger(0, BTN_THEME_CRESET, OBJPROP_XSIZE, rW);
   ObjectSetInteger(0, BTN_THEME_CRESET, OBJPROP_YSIZE, BtnHeight);
}
