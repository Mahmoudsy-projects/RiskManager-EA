//+------------------------------------------------------------------+
//| RM_Dashboard.mqh                                                  |
//| Risk Manager EA - Dashboard (Architecture Refactor, R2)            |
//| استخراج‌شده از RiskManager_EA_v45_R1.mq4 - شامل BuildPanel و همه‌ی   |
//| توابع رسم/آپدیت پنل (نه ابزارهای روی چارت مثل H/L یا Trailing).    |
//| صرفاً جابه‌جایی کد، بدون هیچ تغییر مقدار/رفتار (Golden Rule فاز R2).|
//+------------------------------------------------------------------+

// === Panel layout constants (v28/v32) - scaled once per session by ApplyLayoutScale() ===

// panel dimensions - v28 (Dashboard Visual Polish Part 1, Change 1): panel widened 145->210 and
// every row given more breathing room so font sizes could meaningfully increase (v27's compaction
// made text too small/cramped, per Mahmoud's screenshot). All geometry below is derived from named
// constants and a running layout cursor in BuildPanel()/ComputeBodyH() instead of one-off
// magic-number y-offsets, so FULL/COMPACT and the collapsible drawers stay in sync automatically -
// this replaces v27's BH/BH_COMPACT/BH_PERF_OPEN_EXTRA/BH_TOOLS_OPEN_EXTRA constant scheme.
// v32 (Global Layout Scaling): every one of these was a fixed #define literal through v31. They're
// now global variables computed once by ApplyLayoutScale() (called from OnInit(), before the first
// BuildPanel()) from the LayoutScale input - same names, same meaning, just no longer compile-time
// constants, so a single multiplier can scale all of them together. CW stays a macro (PW/MX are
// still plain arithmetic wherever it expands, just against variables now instead of literals).
int PW, TH, MX, GP;
#define CW   (PW-2*MX)  // body content width

// v28 (Change 3): true single merged background behind Status + Open Risk + Floating (3 lines,
// one shared RectC instead of v27's three adjacent BG_STATUS/BG_OPEN/BG_FDD boxes)
int ALERT_H;    // v28 revision 2: 70->56 - still had room to condense per feedback
int STATUS_H;   // status sub-area - v28 revision 2: 30->24
int SUBROW_H;   // Open Risk / Floating sub-rows - v28 revision 2: 20->16

int RISKRR_H;   // Full Risk / RR row
int SCALEIN_H;  // v90 (FEAT-044): Scale-in row - thin full-width row above MARKET/PENDING

int MP_H;       // v28 (Change 4, revised): MARKET ORDER/PENDING ORDER made taller than
                 // surrounding rows - grown further (44->56) to fit the stacked 2-line
                 // bold "MARKET"/"ORDER" labels from the revision round

int ACT_H;      // BE/Half Close, Full Close/Trailing rows (FULL mode)
int CD_H;       // Mkt CD / Beh CD row

int PERF_HDR_H;   // v28 (Change 5): "Performance" header/toggle button
int PERF_ROW_H;   // each Daily/Weekly/Monthly line inside the merged box
int PERF_BOX_PAD; // top/bottom padding inside the merged Performance box
int PERF_ROW_FONT; // v28 revision (bugfix): fixed shared font size for all 3 Performance
                           // rows - previously each row auto-sized independently off its own text
                           // length, which made "Monthly P/L" (a few chars longer) render smaller
                           // than "Daily P/L"/"Weekly P/L" for no functional reason
// v36 (Change 1 revision - Mahmoud feedback): فونت ثابت برای همه‌ی حساب‌ها کار نمی‌کنه - یه حساب
// با اعداد ۱ رقمی (RB +0.0) زیادی ریز می‌شه، حساب دیگه‌ای با اعداد ۴-۵ رقمی (RB +14056.3) سرریز
// می‌کنه. این دو آرایه طول متن واقعی هر ردیف (Daily/Weekly/Monthly) رو نگه می‌دارن تا فونت هر بار
// بر اساس بلندترین متنِ همون لحظه محاسبه بشه - ولی هر سه ردیف همیشه از یه فونت مشترک استفاده
// می‌کنن (همون قانون قدیمی PERF_ROW_FONT که نذاشت ردیف‌ها مستقل از هم اندازه بگیرن و از تراز خارج بشن).
int g_perfPctLen[3]; // index 0=Daily,1=Weekly,2=Monthly - طول متن ستون % (یا کل متن قفل DD)
int g_perfRbLen[3];  // همون برای ستون R/RB

int PERF_MONO_FONT; // v36 (Change 1 bugfix): the padded Consolas text used for column alignment
                     // is wider per character than the old proportional Arial text was, so reusing
                     // PERF_ROW_FONT (8) overflowed the row boxes badly (Mahmoud's screenshot -
                     // text spilling past both edges and overlapping the neighboring column).
                     // v36 revision: no longer applied directly - kept only as the absolute floor
                     // BestFitMonoFont() falls back to when even the smallest candidate overflows.

int TOOLS_HDR_H;  // "Tools" drawer header (unchanged behavior from v26/v27)
int TOOLS_ROW_H;  // Candle Timer row inside the drawer (also reused for every v33 Tools row - all
                   // rows in the drawer are the same height)

// v35 (Utility Phase A, Part 2): "Trading Reports" drawer geometry - header (same shape as
// TOOLS_HDR_H/BTN_PERF), a 3-way Daily/Weekly/Monthly tab row, and a merged stats box holding
// REPORTS_ROW_COUNT rows of two metrics each (six metrics total, same "two labels per row" split
// BuildPanel() already uses for the Performance box).
int REPORTS_HDR_H;   // "Trading Reports" drawer header
int REPORTS_TAB_H;   // Daily/Weekly/Monthly tab row
int REPORTS_ROW_H;   // each metric row inside the merged stats box
int REPORTS_BOX_PAD; // top/bottom padding inside the merged stats box
int REPORTS_ROW_FONT; // fixed shared font size for all metric rows - same reasoning as PERF_ROW_FONT


// === Panel build / hit-test / integrity ===


// v32: scales a font size the same way, then applies the same kind of floor FitBoxFont()/
// FitBoxFontBig() already use for their own smallest auto-shrink step (they never go below 6) -
// so no scaled font, even at 80%, can drop below the smallest size already proven legible
// elsewhere on this panel.
int SCF(int sz)
{
   int s = (int)MathRound(sz * g_layoutScale);
   if(s < 6) s = 6;
   return s;
}


// v32: sets every scaled layout constant above from the current LayoutScale input. Called once
// from OnInit(), before the first BuildPanel() - LayoutScale is Input-only (EA restart to apply
// a change), so these never need recomputing mid-session.
void ApplyLayoutScale()
{
   g_layoutScale = (double)LayoutScale / 100.0;

   PW = SC(195); TH = SC(30); MX = SC(5); GP = SC(5);

   STATUS_H = SC(24);
   SUBROW_H = SC(16);
   // v43 (Item 4): margin/gap = SC(3); ALERT_H grown from the old exact-fit SC(56) to
   // STATUS_H+2*SUBROW_H+4*ALERT_PAD so there's room for an equal top margin, equal gap between
   // Status/Open-Risk, equal gap between Open-Risk/Floating, and equal bottom margin (see
   // BuildPanel() for the actual line placement using this).
   ALERT_PAD = SC(3);
   ALERT_H  = STATUS_H + SUBROW_H*3 + ALERT_PAD*5;  // v99 (FEAT-045): یک ردیف جدید L_RISKINFO (درصد ریسک + حالت) بین Status و Open Risk

   RISKRR_H = SC(30);
   SCALEIN_H = SC(18);   // v90 (FEAT-044)
   MP_H     = SC(56);

   ACT_H = SC(28);
   CD_H  = SC(26);

   PERF_HDR_H    = SC(26);
   PERF_ROW_H    = SC(22);
   PERF_BOX_PAD  = SC(4);
   PERF_ROW_FONT = SCF(8);
   PERF_MONO_FONT = SCF(6);

   TOOLS_HDR_H = SC(26);
   TOOLS_ROW_H = SC(26);

   // v35 (Utility Phase A, Part 2): Trading Reports drawer
   REPORTS_HDR_H   = SC(26);
   REPORTS_TAB_H   = SC(22);
   REPORTS_ROW_H   = SC(20);
   REPORTS_BOX_PAD = SC(4);
   REPORTS_ROW_FONT = SCF(8);

   CLOSE_GRID_ROW_H = SC(30);
   CLOSE_GRID_GAP   = SC(5);
}


// v34 (BUG-033): MT4's manual "Delete All Objects" removes every chart object, including the
// dashboard panel's own objects - there is no true object "lock" that survives it (OBJPROP_SELECTABLE
// only affects mouse interaction with the object, not Delete-All). Self-healing check instead: once
// per second (reusing this existing 1Hz OnTimer(), no second timer added), verify that the titlebar
// background - the very first object BuildPanel() creates, and the only one guaranteed to exist
// regardless of Trading/Utility mode OR minimized state - still exists via ObjectFind(). If it's
// missing, immediately call BuildPanel() to fully reconstruct the dashboard (BuildPanel() already
// refreshes every display at the end of a rebuild, so nothing else needs to be called here). Applies
// equally to both Trading and Utility, since both go through the same BuildPanel(). The trader should
// see at most a sub-second flash, never a permanently broken/missing panel.
void CheckPanelIntegrity()
{
   if(ObjectFind(0, P+"TITLEBAR") < 0) BuildPanel();
}


void StartButtonFlash(string objName, color flashColor, uint &deadline)
{
   if(ObjectFind(0, objName) < 0) return;  // Minimized یا COMPACT/FULL دیگه‌ای که این دکمه توش نیست
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, flashColor);
   deadline = GetTickCount() + BTN_FLASH_MS;
   ChartRedraw();
}


// v30 (Button Click Feedback - Part 1): هر ثانیه (از OnTimer) صدا زده می‌شه - هر سه دکمه رو مستقل
// چک می‌کنه و هر کدوم که ددلاینش رسیده باشه رو به رنگ خاکستری پیش‌فرض برمی‌گردونه و غیرفعالش می‌کنه
// (deadline=0). تفریق uint با کست به int به‌جای مقایسه‌ی مستقیم، تا سرریز GetTickCount() (که هر
// ~49.7 روز اتفاق می‌افته) باعث محاسبه‌ی غلط نشه.
void CheckButtonFlashExpiry()
{
   uint now = GetTickCount();
   if(g_beFlashEnd != 0 && (int)(now - g_beFlashEnd) >= 0)
   {
      if(ObjectFind(0,P+"BTN_BE")>=0) ObjectSetInteger(0,P+"BTN_BE",OBJPROP_BGCOLOR,CLR_BTN_DEFAULT);
      g_beFlashEnd = 0;
      ChartRedraw();
   }
   if(g_halfFlashEnd != 0 && (int)(now - g_halfFlashEnd) >= 0)
   {
      if(ObjectFind(0,P+"BTN_HALF")>=0) ObjectSetInteger(0,P+"BTN_HALF",OBJPROP_BGCOLOR,CLR_BTN_DEFAULT);
      g_halfFlashEnd = 0;
      ChartRedraw();
   }
   if(g_fullFlashEnd != 0 && (int)(now - g_fullFlashEnd) >= 0)
   {
      if(ObjectFind(0,P+"BTN_FULL")>=0) ObjectSetInteger(0,P+"BTN_FULL",OBJPROP_BGCOLOR,CLR_BTN_DEFAULT);
      g_fullFlashEnd = 0;
      ChartRedraw();
   }
   // v60 (EXPORT CSV Feedback): همون الگوی سه بلوک بالا - بعد از ۵ ثانیه به CLR_BTN_DEFAULT برمی‌گرده
   if(g_exportFlashEnd != 0 && (int)(now - g_exportFlashEnd) >= 0)
   {
      if(ObjectFind(0,P+"BTN_EXPORTCSV")>=0) ObjectSetInteger(0,P+"BTN_EXPORTCSV",OBJPROP_BGCOLOR,CLR_BTN_DEFAULT);
      g_exportFlashEnd = 0;
      ChartRedraw();
   }
   // v42 (Punch List, Item 1.3): R/R and Measure Move are now "arm, then click the chart" tools
   // (see the g_fiboArmed* globals above) - if the trader arms one but doesn't finish clicking
   // both chart points within FIBO_ARM_MS, auto-disarm back to grey so the button never gets
   // stuck colored and the next click always starts a clean, fresh placement.
   if((g_fiboArmedRR || g_fiboArmedMeasure) && g_fiboArmDeadline != 0 && (int)(now - g_fiboArmDeadline) >= 0)
   {
      CancelFiboArm();
      SetStatus("Cancelled - timed out", clrOrange);
      ChartRedraw();
   }
}


//+------------------------------------------------------------------+
bool IsOnPanel(int x, int y)
{
   // v28: now delegates to ComputeBodyH() (declared just above BuildPanel()) instead of
   // duplicating the height formula - keeps this in sync automatically with FULL/COMPACT, the
   // Performance/Tools drawers, AND the Close submenu's reserved COMPACT-mode space (Change 6),
   // so clicks on any of those always register as "on panel" instead of being misrouted as chart clicks.
   int bodyH = ComputeBodyH();
   int h = g_minimized ? TH : TH+bodyH;
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int px = PanelRight ? chartW - PW - PanelX : PanelX;
   return (x>=px && x<=px+PW && y>=PanelY && y<=PanelY+h);
}


// v27 (Change 1): Floating P/L moved into the merged Open Risk/Floating alert box under Status -
// that box now exists in BOTH dashboard modes (previously FULL-only), so the early-return for
// COMPACT is removed. Color logic (text color 4-way + background exceeded-threshold tint) is
// byte-for-byte the same as v26, just writing to the repositioned L_FDD/BG_FDD objects.
void UpdateFloatingDisplay()
{
   if(g_minimized) return;
   double floatPct = GetFloatingPLPercent();
   // v29 (Part 3): 4-way green/white/yellow/red replaced with the panel-wide grey/orange/red
   // 3-state rule - Floating P/L has a real forbidden zone (the emergency-close threshold).
   color c;
   if(floatPct <= -InpMaxFloatingDDPercent)                 c = CLR_BREACHED;
   else if(floatPct <= -InpMaxFloatingDDPercent*WARN_RATIO) c = CLR_APPROACHING;
   else                                                     c = CLR_NEUTRAL;
   string fddTxt = "Floating: "+DoubleToStr(floatPct,2)+"% / "+DoubleToStr(MathAbs(InpMaxFloatingDDPercent),2)+"%";   // v102: مثل Open Risk (فعلی / سقف)
   SetLbl(P+"L_FDD", fddTxt, c);
   // v42 (Punch List, Part 2): FitBoxFontBig()'s size-10 default sat flush against the row below
   // (the Status box - STATUS_H+SUBROW_H+SUBROW_H - has zero spare margin) - one point smaller,
   // same length-based shrink thresholds otherwise, paired with the BuildPanel() y-nudge above.
   int fddSz = 9;
   int fddLen = StringLen(fddTxt);
   if(fddLen > 36)      fddSz = 6;
   else if(fddLen > 25) fddSz = 8;
   ObjectSetInteger(0, P+"L_FDD", OBJPROP_FONTSIZE, SCF(fddSz));
   // v28 (Change 3): the dedicated BG_FDD background no longer exists (Floating now lives inside
   // the single merged BG_ALERT box) - the 4-way text color scale above (green/white/yellow/red)
   // already flags a critical breach, so no alert information is lost by dropping the tint.
}


void SaveDashboardModeState()
{
   GlobalVariableSet(GV_DASH_MODE, (double)g_dashboardMode);
}


void LoadDashboardModeState()
{
   // v104: ورود به اکسپرت (اجرای تازه/ری‌استارت ترمینال/Attach) همیشه روی صفحه‌ی Trading باز می‌شود.
   // فقط در تغییر تایم‌فریم/نماد، تغییر پارامتر یا تعویض حساب (همان اکسپرت در حال کار) حالت قبلی حفظ می‌شود.
   int rsn = UninitializeReason();
   bool keepSaved = (rsn == REASON_CHARTCHANGE || rsn == REASON_PARAMETERS || rsn == REASON_ACCOUNT);
   if(keepSaved && GlobalVariableCheck(GV_DASH_MODE))
      g_dashboardMode = (EDashboardMode)(int)GlobalVariableGet(GV_DASH_MODE);
   else
   {
      g_dashboardMode = DASH_TRADING;
      SaveDashboardModeState();
   }
}


// v84 (FEAT-038 Addendum): شمارنده‌ی Market حالا می‌تونه مضرب 0.125 باشه؛ تا 3 رقم اعشار، صفرهای انتهایی حذف (حداقل 1 رقم) -> 1.5 مثل قبل، 0.25، 0.125
string FmtStopCount(double v)
{
   string t = DoubleToStr(v, 3);
   int dot = StringFind(t, ".");
   int len = StringLen(t);
   if(dot < 0) return t;
   while(len > dot + 2 && StringGetChar(t, len - 1) == '0') len--;
   return StringSubstr(t, 0, len);
}

//+------------------------------------------------------------------+
// Update cooldown display on panel
//+------------------------------------------------------------------+
void UpdateCooldownDisplay()
{
   if(g_minimized) return;

   // Market/Behavior Cooldown and Weekly/Monthly DD boxes only exist on the Trading dashboard
   // (renamed v31 from FULL). Enforcement (locks/counters) keeps running in the background
   // regardless of mode - only the on-screen display is skipped here.
   if(g_dashboardMode==DASH_TRADING)
   {
      string mktTxt="", behTxt="";
      color  mktClr=CLR_NEUTRAL, behClr=CLR_NEUTRAL;
      color  mktBg, behBg;

      datetime now = TimeCurrent();

      // Market CD - v29 (Part 3): 3-way "255,150,150"/red scheme replaced with the panel-wide
      // grey/orange/red rule (a real forbidden zone exists here - the lock itself). Text and
      // BG_MKT background both follow the same 3 states now.
      if(g_mktCooldownEnd>0 && now<g_mktCooldownEnd)
      {
         int rem = (int)(g_mktCooldownEnd - now);
         int hh=rem/3600, mm=(rem%3600)/60, ss=rem%60;
         mktTxt = "Mkt CD: "+IntegerToString(hh)+":"+StringFormat("%02d",mm)+":"+StringFormat("%02d",ss);
         mktClr = CLR_BREACHED;
         mktBg  = C'80,20,20';
      }
      else
      {
         // v19 (BUG-022): g_mktStopCount is now fractional (Half Risk stops add 0.5) - show
         // one decimal place only when it's actually fractional (e.g. "1.5/3"), otherwise
         // keep the plain whole-number look (e.g. "2/3") to match the pre-v19 display.
         bool isFractional = (MathAbs(g_mktStopCount - MathRound(g_mktStopCount)) > 0.001);
         string mktCountTxt = isFractional ? DoubleToStr(g_mktStopCount,1) : IntegerToString((int)MathRound(g_mktStopCount));  // v99 (FEAT-045): حداکثر یک رقم اعشار (سه رقم از کادر بیرون می‌زد)  // v84 (FEAT-038 Addendum): با گام 0.25/0.125 یک رقم اعشار گمراه‌کننده بود (0.25 -> "0.3")
         mktTxt = "Mkt CD: "+mktCountTxt+"/"+IntegerToString(MarketCDCount);
         if(g_mktStopCount >= MarketCDCount*WARN_RATIO) { mktClr = CLR_APPROACHING; mktBg = C'55,42,25'; }
         else                                           { mktClr = CLR_NEUTRAL;     mktBg = C'38,38,42'; }
      }
      ObjectSetInteger(0,P+"BG_MKT",OBJPROP_BGCOLOR,mktBg);

      // Behavior CD - v29 (Part 3): same grey/orange/red rule now applied consistently. Previously
      // this box's background never changed dynamically (only Market's did) and the text used a
      // fixed blue/orange scheme unrelated to the panel-wide philosophy - both now match Market CD.
      if(g_behCooldownEnd>0 && now<g_behCooldownEnd)
      {
         int rem = (int)(g_behCooldownEnd - now);
         int hh=rem/3600, mm=(rem%3600)/60, ss=rem%60;
         behTxt = "Beh CD: "+IntegerToString(hh)+":"
                  +StringFormat("%02d",mm)+":"+StringFormat("%02d",ss);
         behClr = CLR_BREACHED;
         behBg  = C'80,20,20';
      }
      else
      {
         behTxt = "Beh CD: "+IntegerToString(g_behCount)+"/"+IntegerToString(BehaviorCDCount);
         if(g_behCount >= BehaviorCDCount*WARN_RATIO) { behClr = CLR_APPROACHING; behBg = C'55,42,25'; }
         else                                         { behClr = CLR_NEUTRAL;     behBg = C'38,38,42'; }
      }
      ObjectSetInteger(0,P+"BG_BEH",OBJPROP_BGCOLOR,behBg);

      SetLbl(P+"L_MKTCD", mktTxt, mktClr);
      SetLbl(P+"L_BEHCD", behTxt, behClr);
      // v102: Market CD هم مثل Behavior CD (BUG-032) نیمه‌عرض است؛ در حالت قفل ("Mkt CD: 1:59:30") با FitBoxFontBig از کادر بیرون می‌زد.
      // حالا width-aware (همان محاسبه‌ی عرض cdw1 که BuildPanel با آن ساخته).
      int mktBoxW = (CW-GP)/2;
      FitBoxFontHalf(P+"L_MKTCD", mktTxt, mktBoxW);
      // v33 (BUG-032): L_BEHCD switched to the width-aware FitBoxFontHalf() - cdw2 recomputed
      // here from the same CW/GP the box was actually built with (BuildPanel()'s cdw1/cdw2 are
      // local to that function, so this mirrors that same math rather than introducing a new
      // stored global just to carry one width across functions).
      int behBoxW = CW - GP - (CW-GP)/2;
      FitBoxFontHalf(P+"L_BEHCD", behTxt, behBoxW); // v9->v33: was FitBoxFontBig(), see BUG-032 above


      // v27 (Change 2): Weekly/Monthly P/L rows only exist when the "📊 Performance" box is
      // expanded - same guard pattern as UpdatePLDisplay()'s Daily row. Enforcement (the actual
      // lock trigger in CheckDrawdownLimits()) is completely separate and keeps running
      // regardless of whether this box is visible.
      if(ObjectFind(0,P+"L_WDD")>=0)
      {
         datetime now2 = TimeCurrent();

         // Weekly - v29 (Part 3): green/red-by-sign replaced with the grey/orange/red 3-state rule
         // (MaxWeeklyDD is a real forbidden zone - it can trigger the weekly lock). Only the
         // percentage segment (L_WDD) is colored; the R/RB segment (L_WDD_RB) always stays
         // CLR_NEUTRAL. When locked, the countdown text takes over L_WDD as before and L_WDD_RB
         // is simply cleared so no stale R/RB text sits next to it.
         string wddTxt, wRbTxt="";
         color  wc;
         if(g_weeklyLockEnd>0 && now2<g_weeklyLockEnd)
         {
            int rem=(int)(g_weeklyLockEnd-now2);
            int hh=rem/3600,mm=(rem%3600)/60,ss=rem%60;
            wddTxt = "Weekly DD: "+IntegerToString(hh)+":"+StringFormat("%02d",mm)+":"+StringFormat("%02d",ss);
            wc = CLR_BREACHED;
            // v28 (Change 5): BG_WDD no longer exists (Weekly now lives inside the single merged
            // BG_PERF box) - the red lock-countdown text above already flags this state.
         }
         else
         {
            double wpl=GetWeeklyNetResultPercent();
            double wR =GetWeeklyR();  // v11 (FEAT-016) - منطق دست‌نخورده
            double wRB=GetWeeklyRB(); // v25 (FEAT-017) - منطق دست‌نخورده
            double wLossMag = -wpl;
            if(wLossMag >= g_effMaxWeeklyDD)                 wc = CLR_BREACHED;
            else if(wLossMag >= g_effMaxWeeklyDD*WARN_RATIO) wc = CLR_APPROACHING;
            else                                        wc = CLR_NEUTRAL;
            // v36 (Change 1): همون پد ثابت-عرض که در UpdatePLDisplay() برای Daily استفاده شد
            wddTxt = PadR("Weekly",7)+PadL((wpl>=0?"+":"")+DoubleToStr(wpl,2),5)+"%";
            wRbTxt = PadL((wR>=0?"+":"")+DoubleToStr(wR,1),4)+"R "+PadL((wRB>=0?"+":"")+DoubleToStr(wRB,1),4)+"RB";  // v42 (Punch List, Part 3): number-before-label order now matches R (was "RB +0.0", label-before-number)
         }
         SetLbl(P+"L_WDD", wddTxt, wc);
         SetLbl(P+"L_WDD_RB", wRbTxt, CLR_NEUTRAL);
         // v36 (Change 1 revision): فونت اینجا دیگه مستقیم ست نمی‌شه - فقط طول متن رو کش می‌کنیم؛
         // UpdatePLDisplay() هر تیک بعد از این تابع صدا زده می‌شه و یه فونت مشترک برای هر سه ردیف
         // (بر اساس بلندترین طول بین Daily/Weekly/Monthly) محاسبه و روی هر ۶ آبجکت اعمال می‌کنه.
         g_perfPctLen[1] = StringLen(wddTxt);
         g_perfRbLen[1]  = StringLen(wRbTxt);

         // Monthly - same treatment as Weekly above
         string mddTxt, mRbTxt="";
         color  mc;
         if(g_monthlyLockEnd>0 && now2<g_monthlyLockEnd)
         {
            int rem=(int)(g_monthlyLockEnd-now2);
            int dd2=rem/86400,hh=(rem%86400)/3600,mm=(rem%3600)/60;
            mddTxt = "Monthly DD: "+IntegerToString(dd2)+"d "+IntegerToString(hh)+":"+StringFormat("%02d",mm);
            mc = CLR_BREACHED;
            // v28 (Change 5): BG_MDD no longer exists (Monthly now lives inside the single merged
            // BG_PERF box) - the red lock-countdown text above already flags this state.
         }
         else
         {
            double mpl=GetMonthlyNetResultPercent();
            double mR =GetMonthlyR();  // v11 (FEAT-016) - منطق دست‌نخورده
            double mRB=GetMonthlyRB(); // v25 (FEAT-017) - منطق دست‌نخورده
            double mLossMag = -mpl;
            if(mLossMag >= g_effMaxMonthlyDD)                 mc = CLR_BREACHED;
            else if(mLossMag >= g_effMaxMonthlyDD*WARN_RATIO) mc = CLR_APPROACHING;
            else                                         mc = CLR_NEUTRAL;
            // v36 (Change 1): همون پد ثابت-عرض که در UpdatePLDisplay() برای Daily استفاده شد
            mddTxt = PadR("Monthly",7)+PadL((mpl>=0?"+":"")+DoubleToStr(mpl,2),5)+"%";
            mRbTxt = PadL((mR>=0?"+":"")+DoubleToStr(mR,1),4)+"R "+PadL((mRB>=0?"+":"")+DoubleToStr(mRB,1),4)+"RB";  // v42 (Punch List, Part 3): number-before-label order now matches R (was "RB +0.0", label-before-number)
         }
         SetLbl(P+"L_MDD", mddTxt, mc);
         SetLbl(P+"L_MDD_RB", mRbTxt, CLR_NEUTRAL);
         // v36 (Change 1 revision): همون توضیح Weekly بالا - فقط طول متن کش می‌شه
         g_perfPctLen[2] = StringLen(mddTxt);
         g_perfRbLen[2]  = StringLen(mRbTxt);
      }
   }

   UpdateModeButtons();
   ChartRedraw();
}


//+------------------------------------------------------------------+
// v8 (BUG-011): نوار وضعیت یک‌خطی - همون کادر پیام‌های اکشن لحظه‌ای (L_STATUS) رو
// برای نمایش وضعیت دائمی سیستم هم استفاده می‌کنه. وقتی SetStatus() یه پیام اکشن
// می‌ذاره (مثلاً "Trailing: ON")، g_actionMsgUntil ست می‌شه و این تابع تا اون لحظه
// چیزی رو بازنویسی نمی‌کنه؛ بعد از رد شدن زمان، دوباره وضعیت دائمی سیستم رو می‌نویسه.
// مستقیم روی L_STATUS می‌نویسه (نه از طریق SetStatus) تا تایمر پیام اکشن ریست نشه.
// اطلاعاتی محضه - هیچ منطق معاملاتی رو تغییر نمی‌ده. اولویت طبق درخواست:
// Monthly Lock > Weekly Lock > Daily Limit > Market CD > Behavior CD > Trailing ON > BE Active > Ready
//+------------------------------------------------------------------+
void UpdateSystemStatus()
{
   if(g_minimized) return;

   // پیام اکشن لحظه‌ای هنوز روی صفحه‌ست - وضعیت دائمی رو بعداً می‌نویسیم
   if(TimeCurrent() < g_actionMsgUntil) return;

   datetime now = TimeCurrent();
   string txt; color clr;

   if(g_monthlyLockEnd>0 && now<g_monthlyLockEnd)
   { txt="MONTHLY DRAWDOWN LOCK"; clr=clrRed; }
   else if(g_weeklyLockEnd>0 && now<g_weeklyLockEnd)
   { txt="WEEKLY DRAWDOWN LOCK"; clr=clrRed; }
   // v51 (Parking Lot #1): الان قفل Daily هم persisted شد (g_dailyLockEnd) - نمایش وضعیت از روی
   // خودِ قفل می‌خونه، نه فقط مقایسه‌ی زنده‌ی EnableDailyDD/GetDailyRisk، وگرنه بعد از خاموش‌کردن
   // EnableDailyDD وسط قفل، این خط اشتباهاً READY نشون می‌داد در حالی که IsTradingAllowed() هنوز
   // بلاک می‌کنه. مقایسه‌ی زنده‌ی قبلی به‌عنوان fallback نگه داشته شده تا لحظه‌ی رسیدن به آستانه
   // (قبل از این‌که CheckDrawdownLimits() قفل رو واقعاً بسازه) هم روی داشبورد دیده بشه.
   else if(g_dailyLockEnd>0 && now<g_dailyLockEnd)
   { txt="DAILY DRAWDOWN LOCK"; clr=clrRed; }
   else if(EnableDailyDD && GetDailyRisk() >= g_effMaxDailyRisk)
   { txt="DAILY DRAWDOWN LIMIT REACHED"; clr=clrRed; }
   else if(g_mktCooldownEnd>0 && now<g_mktCooldownEnd)
   { txt="MARKET COOLDOWN ACTIVE"; clr=clrRed; }
   else if(g_behCooldownEnd>0 && now<g_behCooldownEnd)
   { txt="BEHAVIOR COOLDOWN ACTIVE"; clr=C'255,165,0'; }
   else if(g_trailingButtonOn)
   { txt="TRAILING ON"; clr=C'0,180,180'; }
   else if(IsBreakEvenActive())
   { txt="BREAK EVEN ACTIVE"; clr=clrAqua; }
   else
   { txt="READY TO TRADE"; clr=clrLimeGreen; }

   ObjectSetString(0,P+"L_STATUS",OBJPROP_TEXT,txt);
   ObjectSetInteger(0,P+"L_STATUS",OBJPROP_COLOR,clr);
   FitBoxFont(P+"L_STATUS", txt); // v8 (BUG-014): سایز فونت رو با طول متن تطبیق بده تا از کادر بیرون نزنه
   // v43 (Item 4): +ALERT_PAD, same reasoning as SetStatus()/SetStatus2() - row1's slot now starts
   // ALERT_PAD below the box top instead of flush with it.
   ObjectSetInteger(0,P+"L_STATUS",OBJPROP_YDISTANCE, g_statusBoxTop + ALERT_PAD + SC(14));
   ChartRedraw();
}

// v59 (Item 4 - یادآوری معاملات تگ‌نخورده): L_STATUS2 از v9.4 به بعد استفاده نمی‌شد ("دیگه از v8
// به بعد برای وضعیت دائمی استفاده نمی‌شه" - کامنت بالای SetStatus2()، RiskManager_EA_vXX.mq4) -
// همون خط دوم بی‌استفاده اینجا برای این یادآوری استفاده می‌شه، بدون هیچ دست‌کاری در زنجیره‌ی
// اولویت اصلی L_STATUS (بالا، UpdateSystemStatus) - این صرفاً یک یادآوریه، نه یک قفل/وضعیت
// جدید که بخواد با Monthly/Weekly/Daily Lock یا Cooldownها رقابت کنه. فقط یادآوری - هیچ چیزی
// مسدود نمی‌شه (طبق مشخصات تسک).
void UpdateUntaggedReminder()
{
   if(g_minimized) return;
   // پیام اکشن لحظه‌ای (SetStatus) خودش L_STATUS2 رو خالی می‌کنه و چیدمان تک‌خطی رو موقتاً
   // برمی‌گردونه - تا اون لحظه تموم نشه این‌جا دست نمی‌زنیم، وگرنه هر کلیک روی هر دکمه‌ای
   // لحظه‌ای این یادآوری رو با چیدمان اشتباه پس می‌داد.
   if(TimeCurrent() < g_actionMsgUntil) return;

   int untagged = CountUntaggedToday();  // RM_Tools.mqh

   if(untagged>0)
   {
      string msg = IntegerToString(untagged) + (untagged==1 ? " trade untagged" : " trades untagged");
      ObjectSetString (0,P+"L_STATUS2",OBJPROP_TEXT,  msg);
      ObjectSetInteger(0,P+"L_STATUS2",OBJPROP_COLOR, clrRed);
      // v2/v43 چیدمان دوخطی: خط اول کمی بالاتر، خط دوم پایین‌تر - همون افست‌های SetStatus2()
      ObjectSetInteger(0,P+"L_STATUS",  OBJPROP_YDISTANCE, g_statusBoxTop + ALERT_PAD + SC(12) - SC(6));
      ObjectSetInteger(0,P+"L_STATUS2", OBJPROP_YDISTANCE, g_statusBoxTop + ALERT_PAD + SC(12) + SC(6));
   }
   else
   {
      ObjectSetString(0,P+"L_STATUS2",OBJPROP_TEXT,"");
      ObjectSetInteger(0,P+"L_STATUS", OBJPROP_YDISTANCE, g_statusBoxTop + ALERT_PAD + SC(14));
   }
   ChartRedraw();
}


// v28 (Change 6): dims every panel object except the Close button and the (separately-created)
// submenu grid to a neutral grey while the submenu is open. Deliberately does not attempt to
// remember/restore original colors - CloseFullCloseMenu() always does a full BuildPanel() rebuild,
// which recreates every object with its correct color from scratch.
void GreyOutPanel(string exceptName)
{
   string names[16];
   names[0]="TITLEBAR";       names[1]="BTN_DASH_TRADING"; names[2]="BTN_DASH_UTILITY";
   names[3]="BG_ALERT";
   names[4]="BTN_RISKTOGGLE"; names[5]="BTN_RR";
   names[6]="BTN_MARKET";     names[7]="BTN_PENDING";
   names[8]="BTN_BE";         names[9]="BTN_HALF";       names[10]="BTN_TRAIL";
   names[11]="BG_MKT";        names[12]="BG_BEH";
   names[13]="BTN_PERF";      names[14]="BG_PERF";       names[15]="BTN_FULL";

   color grey = C'55,55,62';
   for(int i=0;i<ArraySize(names);i++)
   {
      if(names[i]==exceptName) continue;
      string n = P+names[i];
      if(ObjectFind(0,n)<0) continue;
      // buttons and rectangle-labels both expose OBJPROP_BGCOLOR
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,grey);
   }
   ChartRedraw();
}


// v7 (FEAT-002): CancelPending() حذف شد - دکمه‌ی Del Pending دیگه روی داشبورد وجود نداره
// و جاش رو دکمه‌ی Trailing گرفته (طبق پلن توسعه‌ی نسخه‌ی v7)

// v28 (Dashboard Visual Polish Part 1): pure function of current dashboard state - no object
// creation, just arithmetic - so BuildPanel() (to size the BG rectangle up front) and IsOnPanel()
// (hit-testing, called on every mouse move/click) always agree on the current body height without
// duplicating the layout logic in two places. Order/sizes here MUST match the row-by-row cursor in
// BuildPanel() below exactly.
int ComputeBodyH()
{
   // v28 revision (bugfix): this was missing the top GP margin between the titlebar and the first
   // row (BuildPanel()'s cursor starts at y+TH+GP, not y+TH) - the BG rectangle came out 5px too
   // short, so the last row visually overflowed the panel's dark background in COMPACT mode
   // (buttons "sticking out" past the bottom edge, per Mahmoud's screenshot).
   // v31 (Dashboard Architecture: Trading + Utility Split): only the alert/status box is common to
   // both dashboards now (Change 3) - everything else is Trading-only (Risk/RR, Market/Pending,
   // BE/Half/Full Close/Trailing, Mkt/Beh CD, Performance) or Utility-only (Tools, Change 2/4).
   // The old COMPACT 4-button action row and its reserved Close-submenu space are gone entirely -
   // Full Close (and therefore its submenu) no longer exists outside Trading.
   int h = GP;
   h += ALERT_H+GP;
   if(g_dashboardMode==DASH_TRADING)
   {
      h += RISKRR_H+GP;
      h += SCALEIN_H+GP;   // v90 (FEAT-044): Scale-in row (must mirror BuildPanel)
      h += MP_H+GP;
      h += ACT_H+GP;   // BE / Half Close row
      h += ACT_H+GP;   // Full Close / Trailing row
      h += CD_H+GP;    // Mkt CD / Beh CD row
      h += PERF_HDR_H;
      h += g_perfDrawerOpen ? (3 + PERF_ROW_H*3 + PERF_BOX_PAD*2 + GP) : GP;
   }
   else // DASH_UTILITY
   {
      h += TOOLS_HDR_H;
      // v43 (Item 3): Tools header is now a static separator (no expand/collapse) - its rows are
      // always visible, so this contribution is unconditional now (previously gated on
      // g_toolsDrawerOpen). Same "3 + row + GP" shape as before, per row.
      h += 3 + TOOLS_ROW_COUNT*TOOLS_ROW_H + TOOLS_ROW_COUNT*GP;

      // v35 (Utility Phase A, Part 2): "Trading Reports" drawer - second module, sits directly
      // below Tools. Same "3 + content + GP" shape: top padding, tab row + gap, merged stats box
      // (REPORTS_ROW_COUNT rows + top/bottom padding), then the trailing GP. Must mirror the exact
      // shape BuildPanel() draws below, or clicks near the bottom of the panel will misregister
      // (see IsOnPanel(), which delegates to this function).
      h += REPORTS_HDR_H;
      h += g_reportsDrawerOpen
           ? (3 + REPORTS_TAB_H+GP + REPORTS_ROW_COUNT*REPORTS_ROW_H + REPORTS_BOX_PAD*2 + GP)
           : GP;

      // v43 (Item 2): Risk Lab / Journal / AI Coach placeholder rows removed entirely from the
      // layout (see BuildPanel()) - no height contribution from them anymore.
   }
   return h;
}


//+------------------------------------------------------------------+
// BuildPanel - with minimize/rebuild support
// v28 (Dashboard Visual Polish Part 1): full width/layout rework (Changes 1-5, 8). Body content is
// now laid out with a running cursor (cy) instead of one-off yy+N magic-number offsets, so the
// FULL/COMPACT layouts and the two collapsible drawers all stay consistent automatically. See
// ComputeBodyH() above for the matching height calculation used by IsOnPanel()/OpenFullCloseMenu().
//+------------------------------------------------------------------+
void BuildPanel()
{
   // v15: هر rebuild کامل پنل (minimize/expand، تعویض FULL/COMPACT، resize چارت) قبلش
   // ObjectsDeleteAll(0,P) صدا زده می‌شه که دکمه‌های موقت زیرمنوی Full Close رو هم پاک می‌کنه.
   // v28: خود پرچم g_fullCloseMenuOpen دیگه اینجا force-reset نمی‌شه (برخلاف v27) - چون
   // OpenFullCloseMenu() حالا خودش قبل از این rebuild صداش می‌زنه و می‌خواد flag=true از این
   // rebuild زنده بمونه (تا ComputeBodyH() توی حالت COMPACT جای کشوی Close رو رزرو کنه). هر
   // مسیر دیگه‌ای که باعث rebuild می‌شه (Minimize، تعویض FULL/COMPACT، Performance/Tools toggle)
   // از قبل توسط گارد ابتدای OBJECT_CLICK در OnChartEvent مطمئن می‌شه که منو بسته‌ست.

   // همیشه از corner چپ استفاده می‌کنیم
   // اگه PanelRight=true، X رو از عرض چارت حساب می‌کنیم
   int corner = CORNER_LEFT_UPPER;
   int chartW  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int x = PanelRight ? chartW - PW - PanelX : PanelX;
   int y = PanelY;

   // Titlebar - v28 (Change 1): taller (24->30) with bigger title font; FULL/COMPACT toggle still
   // inline beside the title (kept from v27 Change 3), just repositioned/enlarged for the wider panel.
   RectC(P+"TITLEBAR", x, y, PW, TH, C'35,38,52', corner);
   BtnC(P+"BTN_MIN", x+SC(5), y+SC(6), SC(18), SC(18), g_minimized?"+":"-", C'60,64,80', corner, 8);
   // v29 (Part 2): "RISK MANAGER" was getting clipped against the FULL/COMPACT toggle in the 195px
   // titlebar - title moved left (closer to BTN_MIN) and dropped one font size, and FULL/COMPACT
   // tightened/shifted slightly to free up room, so the full title is legible with no overlap.
   // v31: FULL/COMPACT renamed to Trading/Utility (Change 1) - both labels are now 7 characters
   // (same as COMPACT was), so Trading's button widens to match Utility's instead of reusing FULL's
   // narrower 40px slot; total footprint/right margin is otherwise unchanged.
   // v32: every offset/size below is now SC()-wrapped so the whole title bar (button, title text,
   // and the two mode-toggle buttons) shrinks/grows in lockstep with PW instead of PW scaling while
   // these stayed fixed (which would have pushed BTN_DASH_UTILITY past the panel's right edge at
   // smaller scales, or left an oversized gap at 100%).
   LblC(P+"TITLE", x+SC(24), y+SC(10), "RISK MANAGER", clrWhite, 7, true, corner);
   BtnC(P+"BTN_DASH_TRADING", x+PW-SC(94), y+SC(6), SC(44), SC(18), "Trading",
        (g_dashboardMode==DASH_TRADING) ? C'40,130,60' : C'60,64,80', corner, 6);
   BtnC(P+"BTN_DASH_UTILITY", x+PW-SC(48), y+SC(6), SC(44), SC(18), "Utility",
        (g_dashboardMode==DASH_UTILITY) ? C'40,130,60' : C'60,64,80', corner, 6);

   if(g_minimized) { ChartRedraw(); return; }

   // Body background - sized up front via ComputeBodyH() so it can be drawn first (and therefore
   // sit behind every row created below it - MT4 draws later-created objects on top).
   int bodyH = ComputeBodyH();
   RectC(P+"BG", x, y+TH, PW, bodyH, C'22,25,35', corner);

   int cy = y + TH + GP;      // running layout cursor
   int bx = x + MX;           // body content left edge
   int cw = CW;                // body content width

   // v28 (Change 3): TRUE single merged background behind Status (2 lines) + Open Risk + Floating -
   // one shared RectC (BG_ALERT) instead of v27's three adjacent BG_STATUS/BG_OPEN/BG_FDD boxes.
   // Still three separate text objects/lines - only the container behind them is unified. Each
   // line keeps its own independent text-color feedback logic (see UpdateRiskDisplay()/
   // UpdateFloatingDisplay()); only the per-row BACKGROUND tinting from v27 is dropped since there's
   // now one shared background to tint, and the text color already carries the same information.
   RectC(P+"BG_ALERT", bx, cy, cw, ALERT_H, C'26,29,40', corner);
   g_statusBoxTop = cy;   // v2: ذخیره برای استفاده در SetStatus/SetStatus2
   // v43 (Item 4): row slots now sit at cy+ALERT_PAD, cy+ALERT_PAD+STATUS_H+ALERT_PAD, and
   // cy+ALERT_PAD+STATUS_H+ALERT_PAD+SUBROW_H+ALERT_PAD - i.e. top margin, both inter-line gaps,
   // and the bottom margin (box bottom is cy+ALERT_H, which by construction of ALERT_H is exactly
   // ALERT_PAD below where the Floating row ends) are all the same ALERT_PAD, replacing the old
   // flush-top/ad-hoc-nudge stack.
   LblCC(P+"L_STATUS",  bx, cy+ALERT_PAD, cw, STATUS_H, "", clrLimeGreen,    9, false, corner, 0);
   LblCC(P+"L_STATUS2", bx, cy+ALERT_PAD, cw, STATUS_H, "", C'110,110,135',  7, false, corner, 6);
   // v29 (Part 3): initial placeholder color changed from clrLimeGreen to CLR_NEUTRAL (grey) to
   // match the new 3-state rule's normal state - both are overwritten on the first UpdateRiskDisplay()/
   // UpdateFloatingDisplay() tick anyway, this is just so nothing flashes green before that.
   // v99 (FEAT-045): خط ثابت «درصد ریسک + حالت» - همیشه دیده می‌شود (قبلاً درصد روی دکمه‌ی Risk بود و با دکمه‌های 1/4 و 1/8 ریز می‌شد)
   LblCC(P+"L_RISKINFO", bx, cy+ALERT_PAD*2+STATUS_H, cw, SUBROW_H, "Risk: "+DoubleToStr(g_effRiskPerTrade,2)+"% | Full", CLR_NEUTRAL, 8, false, corner);
   LblCC(P+"L_TRISK",   bx, cy+ALERT_PAD*3+STATUS_H+SUBROW_H, cw, SUBROW_H, "Open Risk: 0.00%/"+DoubleToStr(g_effMaxTotalRisk,2)+"%", CLR_NEUTRAL, 8, false, corner);
   LblCC(P+"L_FDD",     bx, cy+ALERT_PAD*4+STATUS_H+SUBROW_H*2, cw, SUBROW_H, "Floating: 0.00% / "+DoubleToStr(MathAbs(InpMaxFloatingDDPercent),2)+"%", CLR_NEUTRAL, 8, false, corner);
   cy += ALERT_H + GP;

   // v31 (Dashboard Architecture: Trading + Utility Split, Change 1/4): Risk/RR, Market/Pending,
   // and every action/monitoring row below now build ONLY inside Trading. Utility is a dedicated
   // workspace for supporting tools, not a condensed trading dashboard - v28 Change 8's COMPACT
   // 4-button action row, and the Risk/RR + Market/Pending rows that used to build unconditionally
   // for both modes, are removed here entirely (not just hidden).
   if(g_dashboardMode==DASH_TRADING)
   {
      // Full Risk / RR row
      // v29 revision 3 (Mahmoud feedback - Risk/RR are settings, not actions): both buttons stay
      // within the dark grey palette at all times - state is shown mainly via a subtle
      // OBJPROP_BORDER_COLOR accent plus a small background brightness shift, never a bright fill.
      // Placeholder grey here is immediately overwritten by UpdateHalfRiskButton()/UpdateRRButton()
      // at the end of this function (RISK_BG/BORDER_FULL/HALF for Risk, RRGlowColors() bg+border
      // ramp for RR).
      int rrW1 = (cw-GP)/2, rrW2 = cw-GP-rrW1;
      BtnC(P+"BTN_RISKTOGGLE", bx,         cy, rrW1, RISKRR_H, "Risk: Full", C'70,70,80', corner, 8);  // v99 (FEAT-045): دکمه فقط حالت را نشان می‌دهد؛ درصد در خط L_RISKINFO بالای پنل
      BtnC(P+"BTN_RR",         bx+rrW1+GP, cy, rrW2, RISKRR_H, RRLabelText(),      C'70,70,80', corner, 8);  // v45 (Punch List Round 3, Item 3)
      cy += RISKRR_H + GP;

      // v90 (FEAT-044 فاز ۱): ردیف نازک Scale-in بالای MARKET/PENDING. خاکستری = خاموش/غیرفعال، بنفش = روشن. رنگ/متن توسط UpdateScaleInButton() تنظیم می‌شود.
      BtnC(P+"BTN_SCALEIN", bx, cy, cw, SCALEIN_H, "Scale-in: OFF", C'55,55,62', corner, 8);
      cy += SCALEIN_H + GP;

      // v28 (Change 4, revised again): MT4 buttons don't render "\n" as a line break in their
      // caption (confirmed by Mahmoud's screenshot - it just showed as one line) - switched to the
      // same overlay technique used everywhere else in this file: an unlabeled OBJ_BUTTON for the
      // background/click target (BTN_MARKET/BTN_PENDING - unchanged object names, so the existing
      // click-handler code needs no changes), with two separate bold OBJ_LABEL text lines drawn on
      // top of it. Labels are non-clickable (SELECTABLE=false, same as every other LblCC() in this
      // file), so clicks anywhere in the button's area still land on the button underneath.
      int mpW1 = (cw-GP)/2, mpW2 = cw-GP-mpW1;
      // v29 revision 2 (Mahmoud feedback): Market/Pending are the panel's primary action buttons -
      // now built with MP_BASE_GREY, a lighter grey than the rest of the panel's controls (~2-3
      // brightness levels above C'70,70,80'), so they naturally draw the eye even while inactive.
      // Accent colors (blue/orange) still apply once a mode is actually selected - see
      // UpdateModeButtons() below.
      BtnC(P+"BTN_MARKET",  bx,         cy, mpW1, MP_H, "", MP_BASE_GREY, corner, 9);
      BtnC(P+"BTN_PENDING", bx+mpW1+GP, cy, mpW2, MP_H, "", MP_BASE_GREY, corner, 9);
      // v29 (BUG-031 fix): the overlay labels were SELECTABLE=false already, but MT4's click hit-testing
      // on overlapping objects is governed separately by OBJPROP_ZORDER - a label with equal-or-higher
      // Z-order than the button beneath it can still intercept clicks. Explicitly give the buttons a
      // higher Z-order than their overlay labels so a click anywhere in the button rect always reaches
      // the button, regardless of which object is visually on top.
      // v45 (Item 6): was a plain "1" - now PANEL_ZORDER_FG_TOP, the same relative +1 step above the
      // rest of the panel's buttons/labels (PANEL_ZORDER_FG), just moved onto the new elevated base
      // that also lifts the whole panel above external chart objects. See PANEL_ZORDER_* comment.
      ObjectSetInteger(0,P+"BTN_MARKET",  OBJPROP_ZORDER, PANEL_ZORDER_FG_TOP);
      ObjectSetInteger(0,P+"BTN_PENDING", OBJPROP_ZORDER, PANEL_ZORDER_FG_TOP);
      // v29: stacked label lines tightened - previously each line centered within its own MP_H/2 half,
      // leaving a large gap between the two lines (~28px center-to-center). Now both lines are centered
      // around the button's true vertical midpoint with a fixed, much tighter gap between their centers.
      int mpMidY   = cy + MP_H/2;
      int mpHalfGap = SC(8);   // v32: scaled - half of the desired vertical gap between the two stacked line centers
      LblCC(P+"L_MKT1", bx,         mpMidY-mpHalfGap, mpW1, 0, "MARKET",  clrWhite, 10, true, corner, 0);
      LblCC(P+"L_MKT2", bx,         mpMidY+mpHalfGap, mpW1, 0, "ORDER",   clrWhite, 10, true, corner, 0);
      LblCC(P+"L_PND1", bx+mpW1+GP, mpMidY-mpHalfGap, mpW2, 0, "PENDING", clrWhite, 10, true, corner, 0);
      LblCC(P+"L_PND2", bx+mpW1+GP, mpMidY+mpHalfGap, mpW2, 0, "ORDER",   clrWhite, 10, true, corner, 0);
      // v45 (Item 6): was a plain "0" - now PANEL_ZORDER_FG (LblCC's own new default already sets
      // this; kept explicit here so the BUG-031 "button beats its own label" relationship stays
      // self-documenting at the call site instead of relying on a default set two functions away).
      ObjectSetInteger(0,P+"L_MKT1", OBJPROP_ZORDER, PANEL_ZORDER_FG);
      ObjectSetInteger(0,P+"L_MKT2", OBJPROP_ZORDER, PANEL_ZORDER_FG);
      ObjectSetInteger(0,P+"L_PND1", OBJPROP_ZORDER, PANEL_ZORDER_FG);
      ObjectSetInteger(0,P+"L_PND2", OBJPROP_ZORDER, PANEL_ZORDER_FG);
      cy += MP_H + GP;

      // BE / Half Close - v29 revision (Mahmoud feedback): these are one-shot actions with no
      // persistent "active" state (unlike Market/Pending or Trailing), so they now default to
      // the same neutral grey as everything else instead of a fixed blue/orange - nothing here
      // should read as "currently active" when nothing has actually happened yet.
      int aw1 = (cw-GP)/2, aw2 = cw-GP-aw1;
      g_halfCloseMenuAnchorX = bx; g_halfCloseMenuAnchorY = cy; g_halfCloseMenuAnchorW = cw;  // v37 PART B
      BtnC(P+"BTN_BE",   bx,         cy, aw1, ACT_H, "Break Even", C'70,70,80', corner, 9);
      BtnC(P+"BTN_HALF", bx+aw1+GP,  cy, aw2, ACT_H, "Half Close", C'70,70,80', corner, 9);
      cy += ACT_H + GP;

      // Full Close / Trailing - v28 (Change 6): this row's position is remembered as the Close
      // submenu's anchor, exactly like v27 anchored its stacked submenu to BTN_FULL's row.
      // v29 revision (Mahmoud feedback): Full Close is a one-shot action, same reasoning as
      // BE/Half Close above - default grey. Trailing genuinely IS a persistent ON/OFF toggle, so
      // it keeps its dynamic teal/grey coloring unchanged; label renamed to "Auto Trail" in v39
      // (Mahmoud feedback) to match the two-word naming convention of the other action buttons
      // (state is still shown by color alone, not by an ON/OFF text suffix).
      g_closeMenuAnchorX = bx; g_closeMenuAnchorY = cy; g_closeMenuAnchorW = cw;
      BtnC(P+"BTN_FULL",  bx,        cy, aw1, ACT_H, "BULK CLOSE", C'70,70,80', corner, 9);
      BtnC(P+"BTN_TRAIL", bx+aw1+GP, cy, aw2, ACT_H, "Auto Trail",
           g_trailingButtonOn?C'0,150,150':C'70,70,80', corner, 9);
      cy += ACT_H + GP;

      // Mkt CD / Beh CD - unchanged from v27 Change 4 (still two independently-colored halves,
      // only this task's Changes 3/5 merge the alert box and Performance box, not this row)
      int cdw1 = (cw-GP)/2, cdw2 = cw-GP-cdw1;
      // v29 (Part 3): initial placeholder colors changed to the neutral grey/dark-grey pair used
      // by the 3-state rule's normal state - overwritten on the first UpdateCooldownDisplay() tick.
      RectC(P+"BG_MKT",  bx,         cy, cdw1, CD_H, C'38,38,42', corner);
      LblCC(P+"L_MKTCD", bx,         cy, cdw1, CD_H, "Mkt CD: 0/"+IntegerToString(MarketCDCount), CLR_NEUTRAL, 8, false, corner, 0);
      RectC(P+"BG_BEH",  bx+cdw1+GP, cy, cdw2, CD_H, C'38,38,42', corner);
      LblCC(P+"L_BEHCD", bx+cdw1+GP, cy, cdw2, CD_H, "Beh CD: 0/"+IntegerToString(BehaviorCDCount), CLR_NEUTRAL, 8, false, corner, 0);
      cy += CD_H + GP;

      // v28 (Change 5): TRUE single merged background behind Daily/Weekly/Monthly - one shared
      // BG_PERF RectC instead of v27's three individual BG_DPL/BG_WDD/BG_MDD color blocks. Still
      // three separate compact one-line rows with RB-as-prefix, unchanged from v27 - background/
      // container change only, per spec. Threshold-based background tinting on lock (previously on
      // BG_WDD/BG_MDD individually) is dropped along with those objects; the text itself already
      // turns red and the countdown text still appears, so no alarm information is actually lost.
      // v29 revision (Mahmoud feedback): open-state color changed from blue to a lighter neutral
      // grey, consistent with removing saturated colors from every "no real active/inactive
      // meaning" control - open vs. closed is still visible (lighter vs. darker grey), just no
      // longer a separate hue.
      BtnC(P+"BTN_PERF", bx, cy, cw, PERF_HDR_H,
           (g_perfDrawerOpen ? "[-] Performance" : "[+] Performance"),
           g_perfDrawerOpen ? C'75,80,95' : C'50,54,68', corner, 8);
      cy += PERF_HDR_H;

      if(g_perfDrawerOpen)
      {
         cy += SC(3);  // v32: scaled drawer top padding
         int perfBoxH = PERF_ROW_H*3 + PERF_BOX_PAD*2;
         RectC(P+"BG_PERF", bx, cy, cw, perfBoxH, C'30,30,38', corner);
         // v29 (Part 3): each row split into two label objects so only the P/L percentage can
         // follow the grey/orange/red 3-state rule while the Trade R and RB figures stay
         // permanently grey (they have no limit/lock tied to them). Left segment holds the
         // "<Period> P/L: x.xx%" text (colored), right segment holds "x.xR   RB x.x" (always
         // CLR_NEUTRAL). PERF_PCT_W splits the shared row width between the two.
         int pctW = (int)(cw*PERF_PCT_W_RATIO), rbW = cw-pctW;
         LblCC(P+"L_DPL",    bx,      cy+PERF_BOX_PAD,              pctW, PERF_ROW_H, PadR("Daily",7)+PadL("+0.00",5)+"%",   CLR_NEUTRAL, PERF_MONO_FONT, false, corner, 0);
         LblCC(P+"L_DPL_RB", bx+pctW, cy+PERF_BOX_PAD,              rbW,  PERF_ROW_H, PadL("+0.0",4)+"R "+PadL("+0.0",4)+"RB", CLR_NEUTRAL, PERF_MONO_FONT, false, corner, 0);
         LblCC(P+"L_WDD",    bx,      cy+PERF_BOX_PAD+PERF_ROW_H,   pctW, PERF_ROW_H, PadR("Weekly",7)+PadL("+0.00",5)+"%",  CLR_NEUTRAL, PERF_MONO_FONT, false, corner, 0);
         LblCC(P+"L_WDD_RB", bx+pctW, cy+PERF_BOX_PAD+PERF_ROW_H,   rbW,  PERF_ROW_H, PadL("+0.0",4)+"R "+PadL("+0.0",4)+"RB", CLR_NEUTRAL, PERF_MONO_FONT, false, corner, 0);
         LblCC(P+"L_MDD",    bx,      cy+PERF_BOX_PAD+PERF_ROW_H*2, pctW, PERF_ROW_H, PadR("Monthly",7)+PadL("+0.00",5)+"%", CLR_NEUTRAL, PERF_MONO_FONT, false, corner, 0);
         LblCC(P+"L_MDD_RB", bx+pctW, cy+PERF_BOX_PAD+PERF_ROW_H*2, rbW,  PERF_ROW_H, PadL("+0.0",4)+"R "+PadL("+0.0",4)+"RB", CLR_NEUTRAL, PERF_MONO_FONT, false, corner, 0);
         // v36 (Change 1): فونت مونواسپیس (Consolas) روی هر ۶ آبجکت ردیف Performance - چون
         // SetLbl() فقط TEXT/COLOR رو آپدیت می‌کنه نه FONT، همین یه بار در BuildPanel() کافیه.
         // با فونت متغیر-عرض قبلی (Arial پیش‌فرض)، حتی متن پد شده هم تراز نمی‌موند چون هر کاراکتر
         // عرض متفاوتی داشت؛ با فونت مونواسپیس هر کاراکتر عرض یکسان داره پس عمود هم ستون‌ها می‌افتن.
         ObjectSetString(0, P+"L_DPL",    OBJPROP_FONT, "Consolas");
         ObjectSetString(0, P+"L_DPL_RB", OBJPROP_FONT, "Consolas");
         ObjectSetString(0, P+"L_WDD",    OBJPROP_FONT, "Consolas");
         ObjectSetString(0, P+"L_WDD_RB", OBJPROP_FONT, "Consolas");
         ObjectSetString(0, P+"L_MDD",    OBJPROP_FONT, "Consolas");
         ObjectSetString(0, P+"L_MDD_RB", OBJPROP_FONT, "Consolas");
         cy += perfBoxH + GP;
      }
      else cy += GP;
      // v31 (Change 2/4): the "🛠️ Tools" drawer that used to sit here (below Performance) is gone
      // from Trading entirely - it now lives on Utility instead, below.

      UpdateModeButtons();
      UpdateHalfRiskButton();
      UpdateRRButton();
      UpdateTrailButton();
   }
   else // v31 (Change 2): DASH_UTILITY - dedicated workspace for supporting tools. Only the
        // alert/status box (built above, common to both dashboards - Change 3) and the Tools
        // drawer live here; no trading controls of any kind. Replaces v28 Change 8's condensed
        // 4-button COMPACT action row entirely (not a resize of it - Utility isn't a smaller
        // Trading dashboard, it's a different dashboard with a different purpose).
   {
      // v43 (Item 3): "Tools" is now a plain static section separator, not an expand/collapse
      // toggle - the buttons below are always visible. Reasoning: ~99% of the time a trader opens
      // the Utility dashboard at all, it's specifically to use one of these tools, so the old
      // path (open Utility -> open Tools drawer -> pick tool) had one extra click for almost no
      // benefit. BTN_TOOLS object name kept as-is for the header label/background, but it no
      // longer has a click handler (see OnChartEvent()) and no longer carries [+]/[-] state.
      BtnC(P+"BTN_TOOLS", bx, cy, cw, TOOLS_HDR_H, "Tools", C'50,54,68', corner, 8);
      cy += TOOLS_HDR_H;

      {
         cy += SC(3);  // v32: scaled section top padding
         // v34.4 (Item 2): with Remove Indicators gone the remaining count is even (8 items) -
         // uniform 2-per-row grid, half-width buttons throughout, replacing the mixed
         // half/third/full-width rows from the base v34 design.
         int toolsHalfW1 = (cw-GP)/2, toolsHalfW2 = cw-GP-toolsHalfW1;

         // Row 1: BE Ref Line (v79، Item 4: دکمه‌ی CANDLE TIMER که قبلاً اینجا نیمی از این ردیف
         // رو می‌گرفت حذف شد - شمارش معکوس کندل حالا همیشه از OnInit() فعاله، نیازی به دکمه
         // نداره. جای خالی حاصل با گسترش BE REF LINE به کل عرض ردیف - بدون گپ - جبران شد؛ بقیه‌ی
         // دکمه‌ها/چیدمان کلی پنل دست‌نخورده موند.
         // v34.4 (Item 3): ON/OFF suffix dropped from the label text - color alone (teal=on,
         // grey=off) now carries the state, same convention BTN_TRAIL already established in v29.
         // v85 (کار اول): دکمه‌ی تمام‌عرض BE REF LINE نصف شد - نیمه‌ی چپ همان BE REF LINE (عملکرد بدون تغییر)،
         // نیمه‌ی راست دکمه‌ی جدید HISTORY (باکس معاملات بسته‌شده - RM_Tools.mqh).
         BtnC(P+"BTN_BEREF", bx, cy, toolsHalfW1, TOOLS_ROW_H, "BE REF LINE",
              g_beRefOn ? C'0,150,150' : C'70,70,80', corner, 7);
         FitBtnFontHalf(P+"BTN_BEREF", "BE REF LINE", toolsHalfW1, 7);
         BtnC(P+"BTN_HISTORY", bx+toolsHalfW1+GP, cy, toolsHalfW2, TOOLS_ROW_H, "HISTORY",
              g_histOn ? C'0,150,150' : C'70,70,80', corner, 7);
         FitBtnFontHalf(P+"BTN_HISTORY", "HISTORY", toolsHalfW2, 7);
         cy += TOOLS_ROW_H + GP;

         // Row 2 (v54 rework - was a 2-button "Daily H/L | Weekly H/L" row, Monthly H/L sat in a
         // separate Row 3 next to Hide Objects): Daily/Weekly/Monthly H/L merged into a single
         // 3-button row to free up a row for Session Windows below - same equal-thirds geometry
         // already proven by the Trading Reports drawer's Daily/Weekly/Monthly tab row
         // (repTabW1/2/3 further down this file).
         // v54.1 (فیکس - گزارش Mahmoud): "DAILY H/L"/"WEEKLY H/L"/"MONTHLY H/L" توی خونه‌های
         // یک‌سومی جا نمی‌شدن (اسکرین‌شات: "MONTHLY H/L" با حرف اول بریده‌شده رندر می‌شد) -
         // خلاصه‌نویسی شدن به "D H/L"/"W H/L"/"M H/L".
         int toolsThirdW1 = (cw-2*GP)/3;
         int toolsThirdW2 = toolsThirdW1;
         int toolsThirdW3 = cw-2*GP-toolsThirdW1-toolsThirdW2;
         BtnC(P+"BTN_HLDAILY", bx, cy, toolsThirdW1, TOOLS_ROW_H, "D H/L",
              g_hlDailyOn ? C'0,150,150' : C'70,70,80', corner, 7);
         BtnC(P+"BTN_HLWEEKLY", bx+toolsThirdW1+GP, cy, toolsThirdW2, TOOLS_ROW_H, "W H/L",
              g_hlWeeklyOn ? C'0,150,150' : C'70,70,80', corner, 7);
         BtnC(P+"BTN_HLMONTHLY", bx+toolsThirdW1+GP+toolsThirdW2+GP, cy, toolsThirdW3, TOOLS_ROW_H, "M H/L",
              g_hlMonthlyOn ? C'0,150,150' : C'70,70,80', corner, 7);
         // v54.1: kept as a safety net even with the shorter captions - never enlarges past sz=7,
         // only shrinks further if a narrower box width at low Layout Scale still needs it.
         FitBtnFontHalf(P+"BTN_HLDAILY",   "D H/L", toolsThirdW1, 7);
         FitBtnFontHalf(P+"BTN_HLWEEKLY",  "W H/L", toolsThirdW2, 7);
         FitBtnFontHalf(P+"BTN_HLMONTHLY", "M H/L", toolsThirdW3, 7);
         cy += TOOLS_ROW_H + GP;

         // Row 3 (v54): Session Windows | Hide Objects - SW takes the slot Monthly H/L used to sit
         // in before the row-2 merge above freed it up.
         // v54.1 (فیکس - گزارش Mahmoud): "SESSION WINDOWS" هم توی خونه‌ی نصفی جا نمی‌شد - به
         // "SESSIONS" کوتاه شد.
         // v57.4 (فیدبک Mahmoud - جابه‌جایی): جای BTN_MARKERS و BTN_SW (KEY TIME) با هم عوض شد -
         // این ردیف حالا MARKERS | Hide Objects رو نشون می‌ده؛ Row 6 پایین‌تر حالا SESSION | KEY
         // TIME رو نشون می‌ده. فقط جانمایی/موقعیت عوض شده - خودِ گلوبال‌ها/کلیک‌هندلرها دست‌نخورده.
         BtnC(P+"BTN_MARKERS", bx, cy, toolsHalfW1, TOOLS_ROW_H, "MARKERS",
              g_markersOn ? C'0,150,150' : C'70,70,80', corner, 7);
         FitBtnFontHalf(P+"BTN_MARKERS", "MARKERS", toolsHalfW1, 7);
         // v42 (Punch List, Item 1.4): active color harmonized to CLR_TOOLS_ACTIVE (the same
         // teal every other Tools drawer toggle uses) - was C'190,140,0' (amber), a leftover
         // one-off that didn't match the rest of the drawer.
         BtnC(P+"BTN_HIDEOBJ", bx+toolsHalfW1+GP, cy, toolsHalfW2, TOOLS_ROW_H,
              g_objectsHidden ? "Show Objects" : "Hide Objects",
              g_objectsHidden ? CLR_TOOLS_ACTIVE : C'70,70,80', corner, 7);
         cy += TOOLS_ROW_H + GP;

         // Row 4 (Items 7+8): R/R | Measure Move - renamed from "Fib R-Multiple"/"Fib Measure
         // Move". Both rest at the same grey as every other Tools button (CLR_BTN_DEFAULT).
         // v42 (Punch List, Item 1.1+1.2+1.3): now "arm, then click the chart" placement tools -
         // BtnC's initial color reflects g_fiboArmed* so a panel rebuild (window resize, timeframe
         // switch) mid-arm doesn't leave the button visually out of sync with the flag.
         BtnC(P+"BTN_FIBRMULT", bx, cy, toolsHalfW1, TOOLS_ROW_H, "RISK/REWARD",
              g_fiboArmedRR ? CLR_TOOLS_ACTIVE : CLR_BTN_DEFAULT, corner, 7);
         BtnC(P+"BTN_FIBMEASURE", bx+toolsHalfW1+GP, cy, toolsHalfW2, TOOLS_ROW_H, "MEASURE MOVE",
              g_fiboArmedMeasure ? CLR_TOOLS_ACTIVE : CLR_BTN_DEFAULT, corner, 7);
         cy += TOOLS_ROW_H + GP;

         // Row 5 (v55: تمام‌عرض "EXPORT CSV" - v56: نصف/نصف شد تا "TAG TRADES" هم جا بشه، بدون
         // نیاز به افزایش TOOLS_ROW_COUNT - همون الگوی v54 که برای جا دادن Session Windows،
         // Daily/Weekly/Monthly H/L رو از دو نصفی به یه سه‌تایی تبدیل کرد). هر دو Action-style
         // (نه Toggle) - رنگ ثابت CLR_BTN_DEFAULT برای هر دو.
         BtnC(P+"BTN_EXPORTCSV", bx, cy, toolsHalfW1, TOOLS_ROW_H, "EXPORT CSV", CLR_BTN_DEFAULT, corner, 7);
         // v56 (Trade Tagging): وقتی پنجره‌ی تگ‌گذاری بازه، رنگش CLR_TOOLS_ACTIVE می‌شه - همون
         // قرارداد رنگی toggle-مانند بقیه‌ی ابزارهای این درایور (حتی با اینکه خودِ رفتار باز/بسته
         // شدنش یه Action روی این دکمه‌ست، نه یه state دائمی مثل Candle Timer/SW).
         BtnC(P+"BTN_TAGTRADES", bx+toolsHalfW1+GP, cy, toolsHalfW2, TOOLS_ROW_H, "TAG TRADES",
              g_tagWindowOpen ? CLR_TOOLS_ACTIVE : CLR_BTN_DEFAULT, corner, 7);
         cy += TOOLS_ROW_H + GP;

         // Row 6 (v57, Item 3): Session Level | Entry/Exit Markers - هر دو toggle جدید با هم در
         // یک ردیف نصف/نصف اضافه شدن (نه هرکدوم یک ردیف تمام‌عرض جدا) طبق تصمیم صریح تسک: عدد
         // فرد ردیف/دکمه لایه‌بندی هم‌ردیف‌های نصفی رو خراب می‌کنه. رنگ toggle همون قرارداد
         // teal=on/grey=off که BTN_SW/BTN_CANDLETIMER استفاده می‌کنن.
         // v57.4 (فیدبک Mahmoud): این ردیف حالا SESSION | KEY TIME رو نشون می‌ده - BTN_MARKERS به
         // Row 3 بالا منتقل شد (جاش رو با BTN_SW عوض کردیم). کپشن Session Level هم از "SESS LVL"
         // به "SESSION" ساده شد.
         BtnC(P+"BTN_SESSLVL", bx, cy, toolsHalfW1, TOOLS_ROW_H, "SESSION",
              g_sessLvlOn ? C'0,150,150' : C'70,70,80', corner, 7);
         FitBtnFontHalf(P+"BTN_SESSLVL", "SESSION", toolsHalfW1, 7);
         BtnC(P+"BTN_SW", bx+toolsHalfW1+GP, cy, toolsHalfW2, TOOLS_ROW_H, "KEY TIME",
              g_swOn ? C'0,150,150' : C'70,70,80', corner, 7);
         FitBtnFontHalf(P+"BTN_SW", "KEY TIME", toolsHalfW2, 7);
         cy += TOOLS_ROW_H + GP;
      }

      // v35 (Utility Phase A, Part 2): "Trading Reports" drawer - second module, directly below
      // Tools. Same collapsible header mechanic (BtnC toggle, full rebuild on click - see
      // OnChartEvent()). Defaults CLOSED, like Tools (not Performance).
      BtnC(P+"BTN_REPORTS", bx, cy, cw, REPORTS_HDR_H,
           (g_reportsDrawerOpen ? "[-] Trading Reports" : "[+] Trading Reports"),
           g_reportsDrawerOpen ? C'75,80,95' : C'50,54,68', corner, 8);
      cy += REPORTS_HDR_H;

      if(g_reportsDrawerOpen)
      {
         cy += SC(3);  // v32-style scaled drawer top padding, same as Tools/Performance

         // Daily/Weekly/Monthly tab row - three equal thirds, selected tab highlighted blue-grey
         // (same accent used elsewhere for a non-forbidden-zone "selected" state, distinct from
         // the toggle teal and the action-button greys). Actual color/text refresh on click is
         // handled by UpdateReportsDisplay() (no full rebuild needed - see OnChartEvent()).
         int repTabW1 = (cw-2*GP)/3;
         int repTabW2 = repTabW1;
         int repTabW3 = cw-2*GP-repTabW1-repTabW2;
         BtnC(P+"BTN_REP_DAILY", bx, cy, repTabW1, REPORTS_TAB_H, "DAILY",
              (g_reportsPeriod==0) ? C'70,110,170' : C'55,55,62', corner, 7);
         BtnC(P+"BTN_REP_WEEKLY", bx+repTabW1+GP, cy, repTabW2, REPORTS_TAB_H, "WEEKLY",
              (g_reportsPeriod==1) ? C'70,110,170' : C'55,55,62', corner, 7);
         BtnC(P+"BTN_REP_MONTHLY", bx+repTabW1+GP+repTabW2+GP, cy, repTabW3, REPORTS_TAB_H, "MONTHLY",
              (g_reportsPeriod==2) ? C'70,110,170' : C'55,55,62', corner, 7);
         cy += REPORTS_TAB_H + GP;

         // Merged stats box - REPORTS_ROW_COUNT rows x 2 metrics each, same "one shared RectC
         // background, split label objects per row" pattern as BG_PERF above. All six metric
         // labels are CLR_NEUTRAL always - this is a statistical report box, not a limit/lock
         // display, so the grey/orange/red 3-state rule (WARN_RATIO etc.) intentionally does not
         // apply here (see UpdateReportsDisplay()).
         int repBoxH = REPORTS_ROW_COUNT*REPORTS_ROW_H + REPORTS_BOX_PAD*2;
         RectC(P+"BG_REPORTS", bx, cy, cw, repBoxH, C'30,30,38', corner);
         // v45 (Mahmoud feedback after Item 5): DD row got longer once "(-X.X%)" was added, so the
         // left column now reads cramped/flush against the box's left edge while the right column
         // (shorter PF/Exp/Trades strings) leaves visible spare room on the right - all 6 items
         // nudged right together by a small inset to use that spare room, box itself (bx/cw) unchanged.
         int repInset = SC(10);
         int repX     = bx + repInset;
         int repColW  = cw/2;
         LblCC(P+"L_REP_WINRATE", repX,         cy+REPORTS_BOX_PAD,                 repColW,        REPORTS_ROW_H, "Win Rate: --", CLR_NEUTRAL, REPORTS_ROW_FONT, false, corner, 0);
         LblCC(P+"L_REP_PF",      repX+repColW, cy+REPORTS_BOX_PAD,                 cw-repColW-repInset, REPORTS_ROW_H, "PF: --",       CLR_NEUTRAL, REPORTS_ROW_FONT, false, corner, 0);
         LblCC(P+"L_REP_AVGRR",   repX,         cy+REPORTS_BOX_PAD+REPORTS_ROW_H,   repColW,        REPORTS_ROW_H, "Avg R:R: --",  CLR_NEUTRAL, REPORTS_ROW_FONT, false, corner, 0);
         LblCC(P+"L_REP_EXP",     repX+repColW, cy+REPORTS_BOX_PAD+REPORTS_ROW_H,   cw-repColW-repInset, REPORTS_ROW_H, "Exp: --",      CLR_NEUTRAL, REPORTS_ROW_FONT, false, corner, 0);
         LblCC(P+"L_REP_DD",      repX,         cy+REPORTS_BOX_PAD+REPORTS_ROW_H*2, repColW,        REPORTS_ROW_H, "DD: --",       CLR_NEUTRAL, REPORTS_ROW_FONT, false, corner, 0);
         LblCC(P+"L_REP_COUNT",   repX+repColW, cy+REPORTS_BOX_PAD+REPORTS_ROW_H*2, cw-repColW-repInset, REPORTS_ROW_H, "Trades: --",   CLR_NEUTRAL, REPORTS_ROW_FONT, false, corner, 0);
         cy += repBoxH + GP;
      }
      else cy += GP;

      // v43 (Item 2): Risk Lab / Journal / AI Coach placeholder rows removed entirely (not just
      // dimmed/inactive as of v34.4) - none of the three have real designs yet, so they shouldn't
      // set expectations. They'll be added back properly once each has an actual design. See
      // ComputeBodyH() - PLACEHOLDER_ROW_COUNT contribution removed there to match.
   }

   // v31: Update*() calls for Trading-only controls are guarded above (inside the DASH_TRADING
   // branch) since those objects don't exist on Utility at all - calling them unconditionally
   // would target non-existent BTN_MARKET/BTN_RISKTOGGLE/BTN_RR/BTN_TRAIL objects. The alert box
   // is common to both dashboards (Change 3), so its Update*() calls stay unconditional here;
   // UpdatePLDisplay() already has its own DASH_UTILITY early-return.
   UpdateRiskDisplay();
   UpdatePLDisplay();
   UpdateFloatingDisplay();
   UpdateReportsDisplay();  // v35: no-ops internally (ObjectFind guard) unless the drawer is open
   ChartRedraw();
}


// v7 (FEAT-002): آپدیت ظاهر و متن دکمه‌ی Trailing (ON = فیروزه‌ای، OFF = خاکستری خنثی)
void UpdateTrailButton()
{
   if(ObjectFind(0,P+"BTN_TRAIL")<0) return;  // Minimized, or on Utility where this button doesn't exist
   // v31: BTN_TRAIL now only ever exists on Trading (v28 Change 8's condensed COMPACT/Utility
   // action row with the shortened "Trl" label is gone), so the label is always the full text -
   // the compact/full label branch this used to need is no longer reachable.
   // v29 revision (Mahmoud feedback): dropped the ":ON"/":OFF" text suffix entirely - the color
   // (teal vs grey) is now the only state indicator.
   // v39 (Mahmoud feedback): label renamed "Trail" -> "Auto Trail" to match the two-word naming
   // convention of the other action buttons (BULK CLOSE, Break Even, Half Close). Functionality
   // (manual toggle + Auto Trigger) is unchanged - this is a label-only edit.
   ObjectSetInteger(0,P+"BTN_TRAIL",OBJPROP_BGCOLOR, g_trailingButtonOn?C'0,150,150':C'70,70,80');
   ObjectSetString (0,P+"BTN_TRAIL",OBJPROP_TEXT, "Auto Trail");
   ChartRedraw();
}


// v79 (Item 4): UpdateCandleTimerButton() حذف شد - دکمه‌ی متناظرش (BTN_CANDLETIMER) دیگه
// وجود نداره؛ شمارش معکوس کندل همیشه‌فعاله و نیازی به آپدیت رنگ/متن دکمه نداره.


// v33/v34: same ON=teal/OFF=grey convention as UpdateCandleTimerButton() above, one helper per
// remaining Tools toggle button. Each guards on ObjectFind() first, same as UpdateTrailButton() -
// the drawer may be collapsed or the trader may be on Trading (not that this drawer exists there)
// when these fire.
// v34 (Items 3+5): PD/PW's single UpdatePDPWButton() replaced by three independent helpers.
void UpdateHLDailyButton()
{
   if(ObjectFind(0,P+"BTN_HLDAILY")<0) return;
   ObjectSetInteger(0,P+"BTN_HLDAILY",OBJPROP_BGCOLOR, g_hlDailyOn?C'0,150,150':C'70,70,80');
   ObjectSetString (0,P+"BTN_HLDAILY",OBJPROP_TEXT,   "D H/L");  // v54.1: shortened from "DAILY H/L" - see BuildPanel()
   ChartRedraw();
}


void UpdateHLWeeklyButton()
{
   if(ObjectFind(0,P+"BTN_HLWEEKLY")<0) return;
   ObjectSetInteger(0,P+"BTN_HLWEEKLY",OBJPROP_BGCOLOR, g_hlWeeklyOn?C'0,150,150':C'70,70,80');
   ObjectSetString (0,P+"BTN_HLWEEKLY",OBJPROP_TEXT,   "W H/L");  // v54.1: shortened from "WEEKLY H/L" - see BuildPanel()
   ChartRedraw();
}


void UpdateHLMonthlyButton()
{
   if(ObjectFind(0,P+"BTN_HLMONTHLY")<0) return;
   ObjectSetInteger(0,P+"BTN_HLMONTHLY",OBJPROP_BGCOLOR, g_hlMonthlyOn?C'0,150,150':C'70,70,80');
   ObjectSetString (0,P+"BTN_HLMONTHLY",OBJPROP_TEXT,   "M H/L");  // v54.1: shortened from "MONTHLY H/L" - see BuildPanel()
   ChartRedraw();
}


// v34 (Item 2): Hide/Show's single UpdateHideShowButton() replaced with just the objects helper -
// v34.4 removed the indicator side (UpdateHideIndButton()) entirely along with the feature.
void UpdateHideObjButton()
{
   if(ObjectFind(0,P+"BTN_HIDEOBJ")<0) return;
   ObjectSetInteger(0,P+"BTN_HIDEOBJ",OBJPROP_BGCOLOR, g_objectsHidden?CLR_TOOLS_ACTIVE:C'70,70,80');
   ObjectSetString (0,P+"BTN_HIDEOBJ",OBJPROP_TEXT,   g_objectsHidden?"Show Objects":"Hide Objects");
   ChartRedraw();
}


void UpdateBERefButton()
{
   if(ObjectFind(0,P+"BTN_BEREF")<0) return;
   ObjectSetInteger(0,P+"BTN_BEREF",OBJPROP_BGCOLOR, g_beRefOn?C'0,150,150':C'70,70,80');
   ObjectSetString (0,P+"BTN_BEREF",OBJPROP_TEXT,   "BE REF LINE");
   ChartRedraw();
}

// v85: همان قرارداد teal=روشن / خاکستری=خاموش بقیه‌ی دکمه‌های Tools
void UpdateHistoryButton()
{
   if(ObjectFind(0,P+"BTN_HISTORY")<0) return;
   ObjectSetInteger(0,P+"BTN_HISTORY",OBJPROP_BGCOLOR, g_histOn?C'0,150,150':C'70,70,80');
   ObjectSetString (0,P+"BTN_HISTORY",OBJPROP_TEXT,   "HISTORY");
   ChartRedraw();
}


// v54: same ON=teal/OFF=grey convention as UpdateCandleTimerButton()/UpdateBERefButton() above.
// v57.1 (فیدبک Mahmoud - نام‌گذاری): کپشن از "SESSIONS" به "KEY TIME" تغییر کرد - خودِ توگل/گلوبال
// (g_swOn) دست‌نخورده.
void UpdateSWButton()
{
   if(ObjectFind(0,P+"BTN_SW")<0) return;
   ObjectSetInteger(0,P+"BTN_SW",OBJPROP_BGCOLOR, g_swOn?C'0,150,150':C'70,70,80');
   ObjectSetString (0,P+"BTN_SW",OBJPROP_TEXT,   "KEY TIME");
   ChartRedraw();
}

// v57: همون الگوی UpdateSWButton بالا - Session Level (فیچر جدید مستقل، ببین RM_Tools.mqh).
// کپشن ساده‌شده "SESSION" (v57.4) - ببین توضیح BuildPanel() ردیف ۶.
void UpdateSessLvlButton()
{
   if(ObjectFind(0,P+"BTN_SESSLVL")<0) return;
   ObjectSetInteger(0,P+"BTN_SESSLVL",OBJPROP_BGCOLOR, g_sessLvlOn?C'0,150,150':C'70,70,80');
   ObjectSetString (0,P+"BTN_SESSLVL",OBJPROP_TEXT,   "SESSION");
   ChartRedraw();
}

// v57: همون الگو - Entry/Exit Markers. کپشن کوتاه‌شده "MARKERS".
void UpdateMarkersButton()
{
   if(ObjectFind(0,P+"BTN_MARKERS")<0) return;
   ObjectSetInteger(0,P+"BTN_MARKERS",OBJPROP_BGCOLOR, g_markersOn?C'0,150,150':C'70,70,80');
   ObjectSetString (0,P+"BTN_MARKERS",OBJPROP_TEXT,   "MARKERS");
   ChartRedraw();
}

// v56 (Trade Tagging): همون الگوی UpdateSWButton بالا - رنگ دکمه‌ی "TAG TRADES" رو با
// g_tagWindowOpen هماهنگ می‌کنه، بدون نیاز به rebuild کامل پنل (OpenTagWindow/CloseTagWindow،
// RM_Tools.mqh، این رو صدا می‌زنن).
void UpdateTagTradesButton()
{
   if(ObjectFind(0,P+"BTN_TAGTRADES")<0) return;
   ObjectSetInteger(0,P+"BTN_TAGTRADES",OBJPROP_BGCOLOR, g_tagWindowOpen?CLR_TOOLS_ACTIVE:CLR_BTN_DEFAULT);
   ChartRedraw();
}


void UpdateRiskDisplay()
{
   if(g_minimized) return;
   double tot=GetTotalOpenRisk();
   // v29 (Part 3): green/orange 2-state replaced with the full panel-wide grey/orange/red 3-state
   // rule (Open Risk has a real forbidden zone - MaxTotalRisk blocks new entries once reached).
   color trc;
   if(tot>=g_effMaxTotalRisk)                 trc = CLR_BREACHED;
   else if(tot>=g_effMaxTotalRisk*WARN_RATIO) trc = CLR_APPROACHING;
   else                                  trc = CLR_NEUTRAL;
   string trTxt = "Open Risk: "+DoubleToStr(tot,2)+"%/"+DoubleToStr(g_effMaxTotalRisk,2)+"%";
   SetLbl(P+"L_TRISK",trTxt,trc);
   // v99 (FEAT-045): خط ثابت ریسک ورود. حالت عادی: «Risk: 0.25% | Full» (یا 1/2، 1/4، 1/8).
   // Scale-in روشن: «Risk: 0.13% | Scale-in $18.70» - هم درصد (مهم‌تر، اول) هم سقف دلاری مؤثر. درصد از GetEntryRiskPct().
   string riTxt; color riClr = CLR_NEUTRAL;
   if(g_scaleInOn)
   {
      string riWhy; double riCap = ScaleInCapUSD(g_scaleInRoot, riWhy);
      riClr = C'170,110,230';
      if(riCap > 0) riTxt = "Risk: "+FmtRiskPct(GetEntryRiskPct())+"% | Scale-in $"+DoubleToStr(riCap,2);
      else          riTxt = "Risk: - | Scale-in (no cap)";
   }
   else riTxt = "Risk: "+FmtRiskPct(GetActiveRiskPct())+"% | "+RiskStepName(g_riskStep);
   SetLbl(P+"L_RISKINFO",riTxt,riClr);
   static string lastRiTxt = "";
   // v94 (BUG-059): ChartRedraw() اینجا هر تیک صدا زده می‌شد و طبق لاگ [RM-PERF] تقریباً هر بار ~۱۰۰۰ms کل تیک (و چارت) را متوقف می‌کرد
   // (ChartRedraw همگام با رشته‌ی رسم چارت است). متن Open Risk فقط وقتی عوض می‌شود که معامله/SL/سقف عوض شود - پس فقط همان‌وقت بازرسم می‌کنیم.
   static string lastTrTxt = "";
   static color  lastTrClr = clrNONE;
   bool trChanged = (trTxt != lastTrTxt || trc != lastTrClr || riTxt != lastRiTxt);
   lastRiTxt = riTxt;
   lastTrTxt = trTxt; lastTrClr = trc;
   // v10 (corrected): Daily Risk box removed (redundant with Daily P/L box below) - GetDailyRisk()
   // still runs in CheckLimits() to block new entries, just no longer displayed here.
   // v28 (Change 3): the dedicated BG_OPEN background no longer exists (Open Risk now lives inside
   // the single merged BG_ALERT box) - the orange/green text color above already carries the same
   // near-limit warning, so no information is lost by dropping the separate background tint.
   if(trChanged) ChartRedraw();
}


// v27 (Change 2): آپدیت ردیف فشرده‌ی Daily P/L داخل باکس "📊 Performance" - همیشه مقدار خام
// "نتیجه‌ی خالص واقعی%" رو نشون می‌ده (بدون کم کردن ریسک باز فعلی، منطق دست‌نخورده). فقط در
// داشبورد Trading و فقط وقتی هم پنل Minimize نشده و هم باکس Performance باز باشه ساخته/آپدیت می‌شه.
// فرمت جدید طبق اسپک: "Daily P/L: 0.00%   0.0R   RB 0.0" - یک خط، بدون "of X%"، RB به‌عنوان
// پیشوند نه پسوند. سه مقدار % / R / RB دقیقاً همون GetDailyNetResultPercent()/GetDailyR()/
// GetDailyRB() قدیمی‌ان - فقط نمایششون تک‌رنگ و تک‌خطی شده (قبلاً سه رنگ/سه خط بود).
// v31: گارد DASH_COMPACT به DASH_UTILITY تغییر نام داد (Trading/Utility rename) - منطق دست‌نخورده.
void UpdatePLDisplay()
{
   if(g_minimized) return;
   if(g_dashboardMode==DASH_UTILITY) return;
   if(ObjectFind(0,P+"L_DPL")<0) return; // پنل هنوز در داشبورد Trading بازسازی نشده یا باکس Performance بسته‌ست

   double dpl = GetDailyNetResultPercent();
   double dR  = GetDailyR();   // v11 (FEAT-016) - منطق دست‌نخورده
   double dRB = GetDailyRB();  // v25 (FEAT-017) - منطق دست‌نخورده
   // v29 (Part 3): simple green(>=0)/red(<0) replaced with the panel-wide grey/orange/red rule -
   // Daily P/L has a real forbidden zone (MaxDailyRisk can trigger a lock). Only the percentage
   // segment (L_DPL) is colored; the R/RB segment (L_DPL_RB) always stays CLR_NEUTRAL, regardless
   // of sign, since those figures have no limit/lock tied to them.
   // v36 (Change 1): لیبل با PadR() به عرض ثابت ۱۳ کاراکتر پد می‌شه (پوشش "Monthly P/L:" که
   // بلندترینه) و بخش عددی با PadL() راست‌چین می‌شه - همراه با فونت مونواسپیس روی این آبجکت
   // (تنظیم‌شده در BuildPanel)، یعنی % همیشه از یه پیکسل ثابت شروع می‌شه، فارغ از طول لیبل ردیف.
   string dplTxt = PadR("Daily",7)+PadL((dpl>=0?"+":"")+DoubleToStr(dpl,2),5)+"%";
   string dRbTxt = PadL((dR>=0?"+":"")+DoubleToStr(dR,1),4)+"R "+PadL((dRB>=0?"+":"")+DoubleToStr(dRB,1),4)+"RB";  // v42 (Punch List, Part 3): number-before-label order now matches R (was "RB +0.0", label-before-number) - also 1 char shorter, giving BestFitMonoFont() a bit more room
   double dplLossMag = -dpl; // positive when in loss; forbidden zone is a loss magnitude, not a gain
   color dc;
   if(dplLossMag >= g_effMaxDailyRisk)                 dc = CLR_BREACHED;
   else if(dplLossMag >= g_effMaxDailyRisk*WARN_RATIO) dc = CLR_APPROACHING;
   else                                           dc = CLR_NEUTRAL;
   SetLbl(P+"L_DPL", dplTxt, dc);
   SetLbl(P+"L_DPL_RB", dRbTxt, CLR_NEUTRAL);
   g_perfPctLen[0] = StringLen(dplTxt);
   g_perfRbLen[0]  = StringLen(dRbTxt);
   // v36 (Change 1 revision - Mahmoud feedback): فونت ثابت (PERF_MONO_FONT) جواب نداد - یه حساب
   // با اعداد کوچیک بیش‌ازحد ریز می‌شد، حساب دیگه‌ای با RB چند-رقمی (مثلاً +14056.3) سرریز می‌کرد.
   // حالا هر تیک بلندترین متن بین هر سه ردیف (Daily/Weekly/Monthly - که UpdateCooldownDisplay()
   // همین تیک قبل از این تابع کش کرده) پیدا می‌شه و یه فونت مشترک محاسبه می‌شه که همون بلندترین
   // متن رو جا می‌کنه؛ چون فونت مشترکه (نه جدا برای هر ردیف)، سه ردیف همیشه هم‌سایز و هم‌تراز
   // می‌مونن - دقیقاً همون قانونی که این کامنت‌های قدیمی زیر توضیح می‌دن.
   // v28 revision (bugfix): was FitBoxFontBig(), which auto-sizes PER ROW based on that row's own
   // text length - since "Monthly P/L:" is a few characters longer than "Daily P/L:"/"Weekly P/L:",
   // it was crossing the auto-shrink threshold on its own and rendering smaller than the other two
   // (visible in Mahmoud's screenshot). All three Performance rows now share one fixed size
   // instead of being sized independently, so they always match.
   int maxPctLen = MathMax(g_perfPctLen[0], MathMax(g_perfPctLen[1], g_perfPctLen[2]));
   int maxRbLen  = MathMax(g_perfRbLen[0],  MathMax(g_perfRbLen[1],  g_perfRbLen[2]));
   int pctW = (int)(CW*PERF_PCT_W_RATIO), rbW = CW-pctW;
   int pctFont = BestFitMonoFont(maxPctLen, pctW);
   int rbFont  = BestFitMonoFont(maxRbLen,  rbW);
   // v36 (فیدبک Mahmoud): قبلاً پرسنت و R/RB هرکدوم فونت خودشون رو جدا محاسبه می‌کردن (چون
   // عرض جعبه‌شون و طول متنشون فرق داره) که باعث می‌شد % بزرگ‌تر از R/RB دیده بشه. حالا یه فونت
   // مشترک برای هر ۶ آبجکت استفاده می‌شه (کوچیک‌ترین بین این دو، تا هر دو ستون جا بشن).
   int perfFont = MathMin(pctFont, rbFont);
   ObjectSetInteger(0, P+"L_DPL",    OBJPROP_FONTSIZE, perfFont);
   ObjectSetInteger(0, P+"L_WDD",    OBJPROP_FONTSIZE, perfFont);
   ObjectSetInteger(0, P+"L_MDD",    OBJPROP_FONTSIZE, perfFont);
   ObjectSetInteger(0, P+"L_DPL_RB", OBJPROP_FONTSIZE, perfFont);
   ObjectSetInteger(0, P+"L_WDD_RB", OBJPROP_FONTSIZE, perfFont);
   ObjectSetInteger(0, P+"L_MDD_RB", OBJPROP_FONTSIZE, perfFont);
}


// v35 (Utility Phase A, Part 2): آپدیت محتوای کشوی "Trading Reports" - رنگ سه تب (بر اساس
// g_reportsPeriod) و شش متریک آماری داخل باکس. فقط روی داشبورد Utility و فقط وقتی کشو باز باشه
// آبجکت‌ها وجود دارن - مثل UpdatePLDisplay/UpdateBERefButton و بقیه، با گارد ObjectFind() به‌سادگی
// no-op می‌شه در غیر این صورت (پنل هنوز بازسازی نشده، کشو بسته‌ست، Minimize شده، یا داشبورد Trading-ه).
// این یه گزارش آماریه - رنگ‌بندی 3-حالته grey/orange/red (که برای Open Risk/Daily P/L و... استفاده
// می‌شه چون یه forbidden zone واقعی دارن) عمداً اینجا اعمال نمی‌شه؛ همه‌چیز همیشه CLR_NEUTRAL می‌مونه.
void UpdateReportsDisplay()
{
   if(g_minimized) return;
   if(g_dashboardMode==DASH_TRADING) return;
   if(ObjectFind(0,P+"L_REP_WINRATE")<0) return; // کشو بسته‌ست یا پنل هنوز بازسازی نشده

   // رنگ تب انتخاب‌شده
   ObjectSetInteger(0,P+"BTN_REP_DAILY",  OBJPROP_BGCOLOR, (g_reportsPeriod==0) ? C'70,110,170' : C'55,55,62');
   ObjectSetInteger(0,P+"BTN_REP_WEEKLY", OBJPROP_BGCOLOR, (g_reportsPeriod==1) ? C'70,110,170' : C'55,55,62');
   ObjectSetInteger(0,P+"BTN_REP_MONTHLY",OBJPROP_BGCOLOR, (g_reportsPeriod==2) ? C'70,110,170' : C'55,55,62');

   datetime periodStart        = g_dayStart;
   double   periodStartBalance = g_dayStartBalance;  // v45 (Item 5): همون مبنای % که Daily/Weekly/Monthly DD ازش استفاده می‌کنن
   if(g_reportsPeriod==1)      { periodStart = g_weekStart;  periodStartBalance = g_weekStartBalance;  }
   else if(g_reportsPeriod==2) { periodStart = g_monthStart; periodStartBalance = g_monthStartBalance; }

   double winRatePct, profitFactor, avgRR, expectancyR, maxDrawdownR, maxDrawdownPct;
   int    tradeCount;
   CalcTradingReportStats(periodStart, periodStartBalance, winRatePct, profitFactor, avgRR, expectancyR, maxDrawdownR, maxDrawdownPct, tradeCount);

   string winRateTxt = (tradeCount>0) ? "Win Rate: "+DoubleToStr(winRatePct,1)+"%" : "Win Rate: --";

   string pfTxt;
   if(tradeCount==0)        pfTxt = "PF: --";
   else if(profitFactor<0)  pfTxt = "PF: Inf";  // sentinel from CalcTradingReportStats - wins with zero losses
   else                     pfTxt = "PF: "+DoubleToStr(profitFactor,2);

   // avgRR==0 covers both "no trades" and "no losing trades yet" (see CalcTradingReportStats) -
   // either way the payoff ratio isn't a meaningful number to show, so both fall back to "--".
   string avgRRTxt = (avgRR>0) ? "Avg R:R  1:"+DoubleToStr(avgRR,1) : "Avg R:R: --";

   string expTxt = (tradeCount>0) ? "Exp: "+(expectancyR>=0?"+":"")+DoubleToStr(expectancyR,2)+"R" : "Exp: --";

   // v45 (Punch List Round 3, Item 5): % اضافه شد کنار R (نه جایگزینش - Avg R:R/Expectancy ذاتاً
   // R-based می‌مونن) - فرمت "DD: -8.16R (-X.X%)"، طبق تصمیم مستندشده در چت اصلی.
   string ddTxt = (tradeCount>0) ? "DD: -"+DoubleToStr(MathAbs(maxDrawdownR),2)+"R (-"+DoubleToStr(MathAbs(maxDrawdownPct),1)+"%)" : "DD: --";

   string countTxt = "Trades: "+IntegerToString(tradeCount);

   // v29 (Part 3): همه‌ی شش لیبل عمداً CLR_NEUTRAL - این باکس یه گزارش آماریه، نه یه نمایشگر با
   // forbidden zone؛ قانون رنگ‌بندی 3-حالته (grey/orange/red) اینجا کاربرد نداره.
   SetLbl(P+"L_REP_WINRATE", winRateTxt, CLR_NEUTRAL);
   SetLbl(P+"L_REP_PF",      pfTxt,      CLR_NEUTRAL);
   SetLbl(P+"L_REP_AVGRR",   avgRRTxt,   CLR_NEUTRAL);
   SetLbl(P+"L_REP_EXP",     expTxt,     CLR_NEUTRAL);
   SetLbl(P+"L_REP_DD",      ddTxt,      CLR_NEUTRAL);
   SetLbl(P+"L_REP_COUNT",   countTxt,   CLR_NEUTRAL);
}


// v29 revision 3 (Mahmoud feedback - Risk/RR are settings, not actions): dark grey button surface
// at all times, with a thin muted red border (BORDER_COLOR) carrying most of the state signal -
// Full Risk = dark grey + thin dark red border, Half Risk = slightly lighter grey + slightly
// brighter (still muted) red border. Replaces the previous whole-button red glow.
void UpdateHalfRiskButton()
{
   // v84 (FEAT-038): اسم تابع برای سازگاری با فراخوان‌ها (BuildPanel / کلیک) همان ماند؛ حالا ۴ پله را رسم می‌کند.
   int boxW = (int)ObjectGetInteger(0,P+"BTN_RISKTOGGLE",OBJPROP_XSIZE);
   color bg = RISK_BG_FULL, bd = RISK_BORDER_FULL;
   if(g_riskStep == 1)      { bg = RISK_BG_HALF; bd = RISK_BORDER_HALF; }
   else if(g_riskStep == 2) { bg = RISK_BG_Q4;   bd = RISK_BORDER_Q4;   }
   else if(g_riskStep == 3) { bg = RISK_BG_Q8;   bd = RISK_BORDER_Q8;   }
   string txt = "Risk: "+RiskStepName(g_riskStep);  // v99 (FEAT-045): فقط حالت (Full / 1/2 / 1/4 / 1/8)؛ درصد در L_RISKINFO
   ObjectSetInteger(0,P+"BTN_RISKTOGGLE",OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,P+"BTN_RISKTOGGLE",OBJPROP_BORDER_COLOR,bd);
   ObjectSetString (0,P+"BTN_RISKTOGGLE",OBJPROP_TEXT,txt);
   FitBtnFontHalf(P+"BTN_RISKTOGGLE", txt, boxW);  // متن پله‌های کم‌ریسک بلندتره؛ فونت خودکار کوچک می‌شود
   UpdateRiskDisplay();  // v99 (FEAT-045): خط L_RISKINFO هم‌زمان با تغییر پله بروز شود (نه منتظر تیک بعدی)
   ChartRedraw();
}


// v45 (Punch List Round 3, Item 3): RR همیشه یه عدد صحیح بین ۱ تا ۵ هست (CycleRR فقط با گام ۱.۰
// جلو می‌ره) - قبلاً یه طرف بدون اعشار و طرف دیگه با یه رقم اعشار نوشته می‌شد ("RR 1:3.0")، الان هر
// دو طرف صحیح و هم‌فرمت‌ان ("RR 1:3"). یه تابع مشترک، هم برای کپشن دکمه هم برای پیام Status، تا
// دوباره از هم جدا نیفتن.
string RRRatioText()
{
   return "1:"+IntegerToString((int)MathRound(g_riskReward));
}

string RRLabelText()
{
   return "RR "+RRRatioText();
}


void UpdateRRButton()
{
   ObjectSetString(0, P+"BTN_RR", OBJPROP_TEXT, RRLabelText());  // v45 (Punch List Round 3, Item 3)
   color rrBg, rrBorder;
   RRGlowColors(g_riskReward, rrBg, rrBorder);
   ObjectSetInteger(0, P+"BTN_RR", OBJPROP_BGCOLOR, rrBg);
   ObjectSetInteger(0, P+"BTN_RR", OBJPROP_BORDER_COLOR, rrBorder);
   ChartRedraw();

   // اگه خط TP از قبل روی چارت تنظیم شده، با RR جدید بازمحاسبه‌اش کن
   if(g_tpPrice != 0 && g_entryPrice != 0 && g_slPrice != 0)
   {
      double dist = MathAbs(g_entryPrice - g_slPrice);
      if(dist > 0)
         g_tpPrice = NormalizeDouble(g_isBuy ? g_entryPrice+dist*g_riskReward : g_entryPrice-dist*g_riskReward, Digits);
   }
}


// v90 (FEAT-044): دکمه‌ی Scale-in - خاموش: خاکستری (قفل Cooldown/DD: تیره‌تر)، روشن: بنفش (= حالت ریسک تغییریافته).
void UpdateScaleInButton()
{
   if(ObjectFind(0,P+"BTN_SCALEIN") < 0) return;
   bool locked = !IsTradingAllowed();
   color bg  = C'55,55,62';
   color bd  = C'55,55,62';
   color txt = clrWhite;
   string t  = "Scale-in: OFF";
   if(g_scaleInOn)
   {
      bg = C'120,70,175'; bd = C'165,115,225'; t = "Scale-in: ON";
   }
   else if(locked)
   {
      bg = C'40,40,45'; bd = C'40,40,45'; txt = C'110,110,115';
   }
   ObjectSetInteger(0,P+"BTN_SCALEIN",OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,P+"BTN_SCALEIN",OBJPROP_BORDER_COLOR,bd);
   ObjectSetInteger(0,P+"BTN_SCALEIN",OBJPROP_COLOR,txt);
   ObjectSetString (0,P+"BTN_SCALEIN",OBJPROP_TEXT,t);
   UpdateRiskDisplay();  // v99 (FEAT-045): خط L_RISKINFO با روشن/خاموش شدن Scale-in هماهنگ شود
}

void UpdateModeButtons()
{
   UpdateScaleInButton();   // v90 (FEAT-044): هم‌زمان با قفل/باز شدن Market/Pending رنگ دکمه هم هماهنگ می‌شود
   bool locked = !IsTradingAllowed();
   int corner = PanelRight ? CORNER_RIGHT_UPPER : CORNER_LEFT_UPPER;

   if(locked)
   {
      ObjectSetInteger(0,P+"BTN_MARKET",  OBJPROP_BGCOLOR, C'40,40,45');
      ObjectSetInteger(0,P+"BTN_PENDING", OBJPROP_BGCOLOR, C'40,40,45');
      // v28 revision: MARKET/PENDING labels moved off the button caption (Change 4) onto separate
      // overlay label objects - color them here instead of the (now always-empty) button text.
      ObjectSetInteger(0,P+"L_MKT1", OBJPROP_COLOR, C'80,80,85');
      ObjectSetInteger(0,P+"L_MKT2", OBJPROP_COLOR, C'80,80,85');
      ObjectSetInteger(0,P+"L_PND1", OBJPROP_COLOR, C'80,80,85');
      ObjectSetInteger(0,P+"L_PND2", OBJPROP_COLOR, C'80,80,85');
      return;
   }

   // v29 revision 2 (Mahmoud feedback): reset color updated to MP_BASE_GREY to match the new
   // lighter base set in BuildPanel() - Market/Pending stay visually "brighter" than the rest of
   // the panel's grey controls even while inactive/unselected.
   ObjectSetInteger(0,P+"BTN_MARKET",  OBJPROP_BGCOLOR, MP_BASE_GREY);
   ObjectSetInteger(0,P+"BTN_PENDING", OBJPROP_BGCOLOR, MP_BASE_GREY);
   ObjectSetInteger(0,P+"L_MKT1", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0,P+"L_MKT2", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0,P+"L_PND1", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0,P+"L_PND2", OBJPROP_COLOR, clrWhite);

   if(g_step != STEP_IDLE)
   {
      if(g_mode==MODE_MARKET)  ObjectSetInteger(0,P+"BTN_MARKET",  OBJPROP_BGCOLOR, C'30,130,220');
      if(g_mode==MODE_PENDING) ObjectSetInteger(0,P+"BTN_PENDING", OBJPROP_BGCOLOR, C'190,140,0');
   }
}


// v8 (BUG-014): کادرهای وضعیت/کول‌داون عرض ثابتی دارن (PW-8 پیکسل)؛ متن‌های بلند مثل
// "BEHAVIOR COOLDOWN ACTIVE" یا "Beh CD: 0:51:14" با فونت پیش‌فرض (۷) ممکنه از عرض
// کادر رد بشن و بزنن بیرون. این تابع عمومیه - روی هر لیبلی که همین عرض کادر رو داره
// (وضعیت، Market Cooldown، Behavior Cooldown) قابل استفاده‌ست و سایز فونت رو بر اساس
// طول متن خودکار کوچیک‌تر می‌کنه تا همیشه جا بشه.
// v28 (Change 1): base size and length thresholds raised to take advantage of the wider panel
// (145->210px) - boxes can now hold noticeably more characters before needing to shrink.
void FitBoxFont(string objName, string txt)
{
   int sz = 9;
   int len = StringLen(txt);
   if(len > 36)      sz = 6;
   else if(len > 25) sz = 8;
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, SCF(sz));  // v32: scaled, floor unchanged (SCF already clamps to 6)
}


// v9: bigger-font variant for the 5 bottom info boxes (Market CD, Behavior CD, Weekly DD,
// Monthly DD, Floating P/L) - user reported text too small/hard to read there. Kept separate
// from FitBoxFont (still used for the Status bar) so Status isn't affected by this change.
void FitBoxFontBig(string objName, string txt)
{
   int sz = 10;
   int len = StringLen(txt);
   if(len > 36)      sz = 7;
   else if(len > 25) sz = 9;
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, SCF(sz));  // v32: scaled, floor unchanged (SCF already clamps to 6)
}


// v33 (BUG-032): FitBoxFontBig()'s length-only thresholds (25/36 chars) were tuned for a
// FULL-width box - Behavior CD shares its row with Market CD (half-width each, cdw2 in
// BuildPanel()), so the active-lock countdown format ("Beh CD: 0:53:26", 15 chars) never crossed
// either threshold and stayed at size 10, wide enough to overflow the narrower box even though
// the same length fits fine in a full-width one. Width-aware instead: estimates each candidate
// font size's rendered width (Arial-ish ~0.62 * fontsize px per character, same rough ratio this
// panel's manual layout math already leans on elsewhere) against the box's actual pixel width and
// picks the largest size that clears it, falling back to the existing 6-floor if none do - same
// "shrink font dynamically" spirit as FitBoxFont()/FitBoxFontBig(), just box-width-aware.
void FitBoxFontHalf(string objName, string txt, int boxW)
{
   int sizes[5] = {10,9,8,7,6};
   int pad = SC(8);  // left/right breathing room inside the box
   int avail = boxW - pad;
   int chosen = 6;
   for(int i=0;i<5;i++)
   {
      int sz = sizes[i];
      int estW = (int)(StringLen(txt) * SCF(sz) * 0.62);
      chosen = sz;
      if(estW <= avail) break;
   }
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, SCF(chosen));
}


// v44 (Punch List Round 2, Item 1 - BTN_RISKTOGGLE text overflow when Half Risk active): same
// width-aware "largest size that clears the box" approach as FitBoxFontHalf() above, but tuned
// with ARIALBOLD_CHAR_RATIO since panel buttons (BtnC) render in "Arial Bold", not plain Arial.
// maxSz caps the top candidate at the button's own original design size (8, per its BtnC call)
// so the Full Risk caption - which already fits - is never enlarged past its normal look; only
// text that would overflow gets shrunk.
//
// v45 (Punch List Round 3, Item 1 - still cramped on CLOSE WINNERS at 90% Layout Scale after the
// first pass): `pad` was only ever subtracted once, i.e. modeling a caption box with a margin on
// ONE side only - close enough for BTN_RISKTOGGLE's wider box that it never visibly overflowed,
// but not conservative enough for the close-submenu grid's narrower box with a longer 13-char
// caption ("CLOSE WINNERS") - the estimate could still pass as "fits" at a size that MT4 actually
// clips/crowds against the button's real (both-sides) internal margin. Subtracting `pad` from both
// sides makes every estimate more conservative (only ever picks an equal-or-smaller font than
// before, never larger), so this can't newly overflow anything that used to fit.
void FitBtnFontHalf(string objName, string txt, int boxW, int maxSz=8)
{
   int sizes[3] = {8,7,6};
   int pad = SC(8);
   int avail = boxW - pad*2;
   int chosen = 6;
   for(int i=0;i<3;i++)
   {
      int sz = sizes[i];
      if(sz > maxSz) continue;
      int estW = (int)(StringLen(txt) * SCF(sz) * ARIALBOLD_CHAR_RATIO);
      chosen = sz;
      if(estW <= avail) break;
   }
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, SCF(chosen));
}


void SetLbl(string n,string t,color c)
{ ObjectSetString(0,n,OBJPROP_TEXT,t); ObjectSetInteger(0,n,OBJPROP_COLOR,c); }


void ResetLines()
{
   g_entryPrice=0; g_slPrice=0; g_tpPrice=0; g_step=STEP_IDLE;
   ObjectDelete(0,LN_CUR); ObjectDelete(0,LN_ENT); ObjectDelete(0,LN_SL); ObjectDelete(0,LN_TP);
   ObjectDelete(0,LN_SL+"_LBL"); ObjectDelete(0,LN_TP+"_LBL"); ObjectDelete(0,LN_CUR+"_LBL");
   ObjectDelete(0,LN_ENT+"_LBL"); ObjectDelete(0,LN_TYPE); // v36 (Change 5)
   ObjectSetString(0,P+"L_ENT",OBJPROP_TEXT,"Entry: --");
   ObjectSetString(0,P+"L_SL2",OBJPROP_TEXT,"SL:    --");
   ObjectSetString(0,P+"L_TP2",OBJPROP_TEXT,"TP:    --");
   ObjectSetString(0,P+"L_DIR",OBJPROP_TEXT,"Dir:   --");
   ChartRedraw();
}


void LblC(string n,int x,int y,string t,color c,int sz=7,bool bold=false,int corner=CORNER_LEFT_UPPER)
{
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,t);        ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,SCF(sz));  ObjectSetInteger(0,n,OBJPROP_CORNER,corner);  // v32: scaled
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   if(bold) ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,n,OBJPROP_ZORDER, PANEL_ZORDER_FG);  // v45 (Item 6) - see PANEL_ZORDER_* comment
}


// v9.4: لیبل وسط‌چین داخل یک کادر (مشابه چینش متن دکمه‌ها) - مختصات کادر می‌گیره نه نقطه مطلق
void LblCC(string n,int bx,int by,int bw,int bh,string t,color c,int sz=7,bool bold=false,int corner=CORNER_LEFT_UPPER,int yOffset=0)
{
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,bx+bw/2);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,by+bh/2+yOffset);
   ObjectSetString(0,n,OBJPROP_TEXT,t);        ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,SCF(sz));  ObjectSetInteger(0,n,OBJPROP_CORNER,corner);  // v32: scaled
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_CENTER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   if(bold) ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,n,OBJPROP_ZORDER, PANEL_ZORDER_FG);  // v45 (Item 6) - see PANEL_ZORDER_* comment
}


void BtnC(string n,int x,int y,int w,int h,string t,color bg,int corner=CORNER_LEFT_UPPER,int sz=7)
{
   ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);     ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString(0,n,OBJPROP_TEXT,t);        ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clrWhite); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,SCF(sz));  // v32: scaled
   ObjectSetInteger(0,n,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   // v36 (Change 3): همه‌ی دکمه‌های پنل حالا Bold هستن برای خوانایی بهتر - یه تغییر اینجا کافیه،
   // چون همه‌ی ۳۴ دکمه‌ی پنل از همین تابع مشترک ساخته می‌شن (نیازی به دست زدن تک‌تک محل صداشون نیست).
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   // v45 (Item 6): همون منطق - یه تغییر اینجا برای Z-order هر ۳۴ دکمه رو هم‌زمان بالا می‌بره.
   // BTN_MARKET/BTN_PENDING بلافاصله بعد از این فراخوانی خودشون صریحاً به PANEL_ZORDER_FG_TOP
   // ست می‌شن (BUG-031) - این مقدار پیش‌فرض فقط برای بقیه‌ی ۳۲ دکمه معتبر می‌مونه.
   ObjectSetInteger(0,n,OBJPROP_ZORDER, PANEL_ZORDER_FG);
}


void Lbl(string n,int x,int y,string t,color c,int sz=7,bool bold=false)
{
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,t);        ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz);  ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   if(bold) ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
}

