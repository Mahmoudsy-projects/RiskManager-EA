//+------------------------------------------------------------------+
//| RM_MainEA_DashboardHelpers.mq5                                     |
//| Risk Manager EA - main .mq4 extract (MT5 Port, Stage 5c-i)         |
//| پورت مستقیم چند تابع/ثابت کوچیک از خودِ RiskManager_EA_v70.mq4 که    |
//| RM_Dashboard.mq5 مستقیم بهشون وابسته‌ست: RectC, PadR, PadL,          |
//| RRGlowColors, BestFitMonoFont, IsBreakEvenActive - همه‌شون کوچیک و   |
//| خودکفان (نه بخشی از یه ماژول کامل)، طبق همون فلسفه‌ی الحاق            |
//| RM_Common.mqh به Stage 3 و GetFloatingPLPercent/EmergencyCloseAll   |
//| به Stage 4. به‌علاوه‌ی هر ثابت رنگ/نسبت که RM_Dashboard.mq5 مستقیم    |
//| استفاده می‌کنه - این‌ها فقط #define/مقدار خام‌ان، نه منطق، پس بدون     |
//| هیچ تغییری کپی شدن (مقادیر دقیقاً از سورس اصلی گرفته شده، حدس زده    |
//| نشدن). Golden Rule: فرمول‌ها/ترتیب عملیات دست‌نخورده - فقط API        |
//| معاملاتی (در IsBreakEvenActive) ترجمه شده.                          |
//+------------------------------------------------------------------+

// --- ثابت‌های رنگ/زمان‌بندی/چیدمان (از main .mq4، بدون تغییر) ---
#define BTN_FLASH_MS     5000
#define CLR_BTN_DEFAULT  C'70,70,80'
#define CLR_TOOLS_ACTIVE C'0,150,150'
#define CLR_FLASH_BE     C'150,80,200'
#define CLR_FLASH_HALF   C'210,175,20'
#define CLR_FLASH_FULL   C'200,60,140'

#define CLR_NEUTRAL      C'190,190,195'
#define CLR_APPROACHING  clrOrange
#define CLR_BREACHED     clrRed
#define WARN_RATIO       0.85

#define RISK_BG_FULL      C'55,55,62'
#define RISK_BORDER_FULL  C'120,45,45'
#define RISK_BG_HALF      C'85,85,95'
#define RISK_BORDER_HALF  C'195,60,60'
#define RISK_BG_Q4        C'100,100,112'
#define RISK_BORDER_Q4    C'215,80,80'
#define RISK_BG_Q8        C'115,115,130'
#define RISK_BORDER_Q8    C'235,105,105'

#define RR_BG_LO_R 55
#define RR_BG_LO_G 55
#define RR_BG_LO_B 62
#define RR_BG_HI_R 140
#define RR_BG_HI_G 140
#define RR_BG_HI_B 150
#define RR_BORDER_LO_R 65
#define RR_BORDER_LO_G 65
#define RR_BORDER_LO_B 75
#define RR_BORDER_HI_R 235
#define RR_BORDER_HI_G 235
#define RR_BORDER_HI_B 240

#define MP_BASE_GREY     C'142,142,158'

#define PERF_MONO_CHAR_RATIO 0.78
#define ARIALBOLD_CHAR_RATIO 0.68

// v74.4 (HF4): one place to change the dashboard panel font. Segoe UI renders crisper than Arial at
// 8-9 pt on Windows (ClearType hinting). If the font is missing MT5 falls back to its default font.
// Chart-overlay labels (price lines, candle timer) and the Performance Consolas rows are unchanged.
#define RM_UI_FONT_BOLD "Segoe UI Bold"
#define RM_UI_FONT_REG  "Segoe UI"

#define PANEL_ZORDER_BG      1000000
#define PANEL_ZORDER_FG      1000001
#define PANEL_ZORDER_FG_TOP  1000002
#define PERF_PCT_W_RATIO 0.52

#define TOOLS_ROW_COUNT 6
#define REPORTS_ROW_COUNT 3

#define ACTION_MSG_SECONDS 4

// --- state globals RM_Dashboard.mq5 reads/writes but doesn't own ---
enum EDashboardMode { DASH_TRADING, DASH_UTILITY };
int      g_statusBoxTop = 0;
datetime g_actionMsgUntil = 0;
double   g_layoutScale = 1.0;
// [Stage 5c-i] GV_DASH_MODE's original value is "RM_DashMode_" + Symbol() - per-symbol persistence.
// Kept identical here (Symbol() still valid in MQL5, per the established Stage 2 pattern).
string   GV_DASH_MODE = "RM_DashMode_" + Symbol();

// v32 (Global Layout Scaling): scales a geometry value (width/height/gap/margin) and rounds to the
// nearest pixel - used pervasively throughout RM_Dashboard.mq5 (SC(195), SC(30), etc.) but, like
// RectC/PadR/PadL above, actually defined in the main .mq4, not in RM_Dashboard.mqh's own function
// list. Small and self-contained - same proactive-port reasoning as the rest of this file.
int SC(int v)
{
   return (int)MathRound(v * g_layoutScale);
}

void RectC(string n,int x,int y,int w,int h,color bg, int corner=CORNER_LEFT_UPPER)
{
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);     ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);  ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);  ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_ZORDER, PANEL_ZORDER_BG);
}

// v36 (Change 1): پد کردن رشته با فاصله سمت راست (چپ‌چین) تا عرض ثابت w برسه.
string PadR(string s,int w)
{
   while(StringLen(s)<w) s = s+" ";
   return s;
}

// v36 (Change 1): پد کردن رشته با فاصله سمت چپ (راست‌چین) تا عرض ثابت w برسه.
string PadL(string s,int w)
{
   while(StringLen(s)<w) s = " "+s;
   return s;
}

// v29 revision 3: RR's background/border color ramp (1-5 -> grey-to-accent gradient).
void RRGlowColors(double rr, color &bg, color &border)
{
   int level = (int)MathRound(rr);
   if(level<1) level=1;
   if(level>5) level=5;
   double t = (level-1)/4.0;
   int bgR = RR_BG_LO_R + (int)((RR_BG_HI_R-RR_BG_LO_R)*t);
   int bgG = RR_BG_LO_G + (int)((RR_BG_HI_G-RR_BG_LO_G)*t);
   int bgB = RR_BG_LO_B + (int)((RR_BG_HI_B-RR_BG_LO_B)*t);
   bg = (color)(bgR | (bgG<<8) | (bgB<<16));
   int brR = RR_BORDER_LO_R + (int)((RR_BORDER_HI_R-RR_BORDER_LO_R)*t);
   int brG = RR_BORDER_LO_G + (int)((RR_BORDER_HI_G-RR_BORDER_LO_G)*t);
   int brB = RR_BORDER_LO_B + (int)((RR_BORDER_HI_B-RR_BORDER_LO_B)*t);
   border = (color)(brR | (brG<<8) | (brB<<16));
}

// v36 (Change 1 revision): largest Consolas font size that fits len characters in boxW pixels.
int BestFitMonoFont(int len, int boxW)
{
   int sizes[5] = {10,9,8,7,6};
   int pad = SC(6);
   int avail = boxW - pad;
   int chosen = 6;
   for(int i=0;i<5;i++)
   {
      int sz = sizes[i];
      int estW = (int)(len * SCF(sz) * PERF_MONO_CHAR_RATIO);
      chosen = sz;
      if(estW <= avail) break;
   }
   return SCF(chosen);
}

// v8 (BUG-011): true اگه حداقل یک معامله‌ی باز این EA فعلاً SL‌اش طرف سود نسبت به قیمت ورود باشه.
// [Stage 5c-i] MT4's OrdersTotal()/OrderSelect(SELECT_BY_POS,MODE_TRADES) loop -> MT5
// PositionsTotal()/PositionGetTicket()/PositionSelectByTicket() - the same established pattern
// from every prior stage's position loops.
bool IsBreakEvenActive()
{
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      double sl = PositionGetDouble(POSITION_SL);
      if(sl<=0) continue;
      bool buy = (posType==POSITION_TYPE_BUY);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      if(buy  && sl>=op) return true;
      if(!buy && sl<=op) return true;
   }
   return false;
}
