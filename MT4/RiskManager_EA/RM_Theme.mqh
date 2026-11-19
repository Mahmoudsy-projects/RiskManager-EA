//+------------------------------------------------------------------+
//|                                                     RM_Theme.mqh |
//|  v110 (Phase 1 - New Graphic Design): جدول رنگ‌های داشبورد.       |
//|  همه‌ی رنگ‌های RM_Dashboard.mqh از این‌جا می‌آیند. فعلاً فقط تم     |
//|  Classic (ظاهر فعلی، بدون هیچ تغییر) تعریف شده؛ تم D (Mono Gray)  |
//|  در Phase 3 به‌عنوان تم دوم اضافه می‌شود.                         |
//+------------------------------------------------------------------+
#define RM_THEME_CLASSIC 0
#define RM_THEME_MONO    1   // v110 P3: Theme D - Mono Gray
int g_themeId = RM_THEME_CLASSIC;
color TH_BEVEL_LT, TH_BEVEL_SH, TH_MP_BASE, TH_RISK_BG, TH_BTN_BD;
color TH_CL_ALL, TH_CL_CHART, TH_CL_WIN, TH_CL_LOSS, TH_CL_SEL;   // v110 P4: دکمه‌های Close/Half Close
color TH_WIN_BG, TH_ROW, TH_ROW2, TH_HDR, TH_XBTN, TH_SCALEIN_HDR, TH_SILVER;   // v110 P4: پنجره‌های Tag/Scale-in   // v110 P3

// ---- پنل و قاب‌ها
color TH_PANEL_BG, TH_TITLEBAR, TH_ALERT_BG, TH_BOX_BG;
// ---- دکمه‌ها
color TH_BTN, TH_BTN_DARK, TH_TAB, TH_TAB_ACTIVE, TH_DRAWER, TH_DRAWER_OPEN, TH_SEL_BLUE;
color TH_ACTIVE, TH_ACTIVE_ALT, TH_MARKET, TH_PENDING;
color TH_DIS_BG, TH_DIS_TXT, TH_DIS_TXT2;
// ---- Scale-in / Risk
color TH_SCALEIN_BG, TH_SCALEIN_BD, TH_RISK_PURPLE;
// ---- Cooldown
color TH_CD_BG, TH_CD_BG_ALERT, TH_CD_BG_WARN;
// ---- متن‌ها و وضعیت
color TH_WHITE, TH_STATUS2, TH_NEUTRAL, TH_BEH_TXT, TH_TRAIL_TXT;
color TH_RED, TH_OK, TH_ORANGE, TH_AQUA;
// ---- فلش دکمه‌های اکشن
color TH_FLASH_BE, TH_FLASH_HALF, TH_FLASH_FULL;

void RM_ThemeInit(int id)
{
   g_themeId = id;
   // ----- Classic (ظاهر فعلی EA، دقیقاً همان مقدارهای قبلی) -----
   TH_PANEL_BG = C'22,25,35';   TH_TITLEBAR = C'35,38,52';   TH_ALERT_BG = C'26,29,40';   TH_BOX_BG = C'30,30,38';
   TH_BTN = C'70,70,80';        TH_BTN_DARK = C'55,55,62';   TH_TAB = C'60,64,80';        TH_TAB_ACTIVE = C'40,130,60';
   TH_DRAWER = C'50,54,68';     TH_DRAWER_OPEN = C'75,80,95'; TH_SEL_BLUE = C'70,110,170';
   TH_ACTIVE = C'0,150,150';    TH_ACTIVE_ALT = C'0,110,170'; TH_MARKET = C'30,130,220';   TH_PENDING = C'190,140,0';
   TH_DIS_BG = C'40,40,45';     TH_DIS_TXT = C'80,80,85';    TH_DIS_TXT2 = C'110,110,115';
   TH_SCALEIN_BG = C'120,70,175'; TH_SCALEIN_BD = C'165,115,225'; TH_RISK_PURPLE = C'170,110,230';
   TH_CD_BG = C'38,38,42';      TH_CD_BG_ALERT = C'80,20,20'; TH_CD_BG_WARN = C'55,42,25';
   TH_WHITE = clrWhite;         TH_STATUS2 = C'110,110,135'; TH_NEUTRAL = C'190,190,195'; TH_BEH_TXT = C'255,165,0'; TH_TRAIL_TXT = C'0,180,180';
   TH_RED = clrRed;             TH_OK = clrLimeGreen;        TH_ORANGE = clrOrange;       TH_AQUA = clrAqua;
   TH_FLASH_BE = C'150,80,200'; TH_FLASH_HALF = C'210,175,20'; TH_FLASH_FULL = C'200,60,140';
   TH_BEVEL_LT = C'120,120,130'; TH_BEVEL_SH = C'20,20,24'; TH_MP_BASE = C'142,142,158'; TH_RISK_BG = C'55,55,62'; TH_BTN_BD = C'20,20,24';
   TH_CL_ALL = C'170,45,45'; TH_CL_CHART = C'150,95,35'; TH_CL_WIN = C'40,130,60'; TH_CL_LOSS = C'150,45,45'; TH_CL_SEL = C'70,90,120';
   TH_WIN_BG = C'25,25,32'; TH_ROW = C'60,60,70'; TH_ROW2 = C'70,70,80'; TH_HDR = C'50,54,68'; TH_XBTN = C'120,40,40'; TH_SCALEIN_HDR = C'85,55,130'; TH_SILVER = clrSilver;
   if(id==RM_THEME_MONO)
   {
      // ----- Theme D: Mono Gray (روشن) - پالت README -----
      TH_PANEL_BG = C'228,228,228'; TH_TITLEBAR = C'228,228,228'; TH_ALERT_BG = C'212,212,212'; TH_BOX_BG = C'212,212,212';
      TH_BTN = C'242,242,242';      TH_BTN_DARK = C'216,216,216'; TH_TAB = C'208,208,208';      TH_TAB_ACTIVE = C'14,124,134';
      TH_DRAWER = C'196,196,196';   TH_DRAWER_OPEN = C'184,184,184'; TH_SEL_BLUE = C'14,124,134';
      TH_ACTIVE = C'14,124,134';    TH_ACTIVE_ALT = C'47,109,181'; TH_MARKET = C'14,124,134';    TH_PENDING = C'14,124,134';
      TH_DIS_BG = C'206,206,206';   TH_DIS_TXT = C'150,150,150';  TH_DIS_TXT2 = C'150,150,150';
      TH_SCALEIN_BG = C'14,124,134'; TH_SCALEIN_BD = C'10,85,96'; TH_RISK_PURPLE = C'14,124,134';
      TH_CD_BG = C'212,212,212';    TH_CD_BG_ALERT = C'240,196,196'; TH_CD_BG_WARN = C'240,222,186';
      TH_WHITE = C'26,26,26';       TH_STATUS2 = C'89,89,89';     TH_NEUTRAL = C'89,89,89';     TH_BEH_TXT = C'176,96,0'; TH_TRAIL_TXT = C'14,124,134';
      TH_RED = C'192,32,32';        TH_OK = C'31,122,74';         TH_ORANGE = C'176,96,0';      TH_AQUA = C'14,124,134';
      TH_FLASH_BE = C'170,140,205'; TH_FLASH_HALF = C'226,184,70'; TH_FLASH_FULL = C'214,120,150';
      TH_CL_ALL = C'176,74,74'; TH_CL_CHART = C'184,122,48'; TH_CL_WIN = C'58,138,90'; TH_CL_LOSS = C'138,58,58'; TH_CL_SEL = C'90,110,140';
      TH_WIN_BG = C'228,228,228'; TH_ROW = C'242,242,242'; TH_ROW2 = C'226,226,226'; TH_HDR = C'196,196,196'; TH_XBTN = C'176,64,64'; TH_SCALEIN_HDR = C'14,124,134'; TH_SILVER = C'89,89,89';
      TH_BEVEL_LT = C'255,255,255'; TH_BEVEL_SH = C'122,122,122'; TH_MP_BASE = C'255,255,255'; TH_RISK_BG = C'255,255,255'; TH_BTN_BD = C'122,122,122';
   }
}
