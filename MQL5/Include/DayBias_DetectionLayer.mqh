//+------------------------------------------------------------------+
//|                                     DayBias_DetectionLayer.mqh   |
//| لایه‌ی تشخیص Day Bias — طبق «تعریف‌های مکانیکی فریزشده» (بخش ۳ سندِ  |
//| دستورکار) + اصلاحاتِ نسخه‌ی ۲ (ClaudeCode_Fixes_v2_DayBias، ۱۲ اوت   |
//| ۲۰۲۶): LP (باکس توکیو)، NY Edge (سشن NY روزِ معاملاتیِ قبل)، رنگ روز. |
//| همه‌ی محاسبات روی M5. پنجره‌ی روزِ ورودی (rates) را DataScript.mq5    |
//| طبقِ F1 می‌سازد: از بسته‌شدنِ باکسِ توکیویِ D تا شروعِ باکسِ روزِ بعد.    |
//+------------------------------------------------------------------+
#ifndef DAYBIAS_DETECTIONLAYER_MQH
#define DAYBIAS_DETECTIONLAYER_MQH

#include "DayBias_BoxLayer.mqh"

//------------------------------------------------------------------
// LP — بخش ۳.۱ (+ F6/F7 نسخه‌ی ۲)
//------------------------------------------------------------------
struct SLPResult
{
   bool     hasBreak;
   int      firstDir;         // +1 Buy، -1 Sell، 0 = هیچ شکست معتبری پیدا نشد
   datetime firstTime;
   double   firstBodyRatio;
   bool     reached1R;        // جهتِ اول پیش از سوییپ به ۱R رسید
   datetime flipTime;         // زمانِ سوییپِ تأییدشده (F6: فقط وقتی لیبلِ نهایی Sweep_* باشد؛ وگرنه ۰)
   datetime oneRTime;         // F6: زمانِ رسیدن به ۱R برایِ جهتِ نهاییِ قفل‌شده (چه مستقیم چه بعدِ سوییپ)؛ ۰ اگر هرگز نرسید
   string   label;            // Buy / Sell / Sweep_Buy / Sweep_Sell / NoDirection
   int      finalDir;         // جهتِ نهاییِ لیبل (برای R_Day)، ۰ اگر NoDirection
};

// بررسیِ یک «leg»: آیا جهتِ dir از startIdx تا پایانِ آرایه، قبل از عبور از oppEdge
// به target می‌رسد؟  1=رسید به target (targetTime ست می‌شود)، 0=سوییپ شد (sweepTime ست می‌شود)،
// -1=هیچ‌کدام تا پایانِ روز. اگر یک کندل هم‌زمان هر دو شرط را داشته باشد، محافظه‌کارانه سوییپ در
// نظر گرفته می‌شود (نمی‌توان ترتیبِ درون‌کندلی را از OHLC اثبات کرد) — طبقِ F7.
int LP_CheckLeg(const MqlRates &rates[], int count, int startIdx, int dir, double target, double oppEdge,
                datetime &sweepTime, datetime &targetTime)
{
   for(int i = startIdx; i < count; i++)
   {
      bool sweepHit, targetHit;
      if(dir > 0)
      {
         sweepHit  = (rates[i].low  <= oppEdge);
         targetHit = (rates[i].high >= target);
      }
      else
      {
         sweepHit  = (rates[i].high >= oppEdge);
         targetHit = (rates[i].low  <= target);
      }
      if(sweepHit)  { sweepTime  = rates[i].time; return(0); }
      if(targetHit) { targetTime = rates[i].time; return(1); }
   }
   return(-1);
}

int LP_FindBarIndex(const MqlRates &rates[], int count, datetime t)
{
   for(int i = 0; i < count; i++)
      if(rates[i].time == t) return(i);
   return(-1);
}

// rates باید از اولین کندلِ بعد از بسته‌شدنِ باکسِ توکیو تا پایانِ پنجره‌ی روزِ معاملاتی
// (F1: تا شروعِ باکسِ روزِ معاملاتیِ بعد) باشد — ترتیبِ صعودی.
void LP_Detect(const MqlRates &rates[], int count, double boxHigh, double boxLow, SLPResult &out)
{
   out.hasBreak = false; out.firstDir = 0; out.firstTime = 0; out.firstBodyRatio = 0;
   out.reached1R = false; out.flipTime = 0; out.oneRTime = 0; out.label = "NoDirection"; out.finalDir = 0;

   double boxSize = boxHigh - boxLow;
   int breakIdx = -1;

   for(int i = 0; i < count; i++)
   {
      double range = rates[i].high - rates[i].low;
      double body  = MathAbs(rates[i].close - rates[i].open);
      bool bodyOk  = (body >= 0.5 * range);

      if(rates[i].close > boxHigh && rates[i].close > rates[i].open && bodyOk)
      {
         out.firstDir = 1; breakIdx = i;
         out.firstBodyRatio = (range > 0 ? body / range : 1.0);
         break;
      }
      if(rates[i].close < boxLow && rates[i].close < rates[i].open && bodyOk)
      {
         out.firstDir = -1; breakIdx = i;
         out.firstBodyRatio = (range > 0 ? body / range : 1.0);
         break;
      }
   }

   if(breakIdx < 0)
      return; // NoDirection - هیچ کندلی شرطِ شکستِ معتبر را پاس نکرد

   out.hasBreak  = true;
   out.firstTime = rates[breakIdx].time;

   double edge1    = (out.firstDir > 0) ? boxHigh : boxLow;
   double target1   = edge1 + out.firstDir * boxSize;
   double oppEdge1  = (out.firstDir > 0) ? boxLow : boxHigh;

   datetime sweepTime1 = 0, targetTime1 = 0;
   int leg1 = LP_CheckLeg(rates, count, breakIdx, out.firstDir, target1, oppEdge1, sweepTime1, targetTime1);

   if(leg1 == 1)
   {
      out.reached1R = true;
      out.label = (out.firstDir > 0) ? "Buy" : "Sell";
      out.finalDir = out.firstDir;
      out.oneRTime = targetTime1;
      return;
   }

   if(leg1 != 0)
      return; // نه ۱R نه سوییپ تا پایانِ پنجره -> NoDirection (flipTime/oneRTime هرگز ست نشدند)

   // سوییپ رخ داد؛ جهتِ دوم از لبه‌ی مقابل با همان قانون سنجیده می‌شود (حداکثر یک فلیپ در روز).
   // توجه (F6/تستِ پذیرشِ ۵): flipTime فقط در صورتِ تأییدِ نهاییِ Sweep_* commit می‌شود؛ یک سوییپِ
   // خام که جهتِ دوم هم به ۱R نرسد، NoDirection می‌ماند و flipTime خالی می‌ماند.
   int dir2        = -out.firstDir;
   double edge2     = oppEdge1;
   double target2   = edge2 + dir2 * boxSize;
   double oppEdge2  = edge1;
   datetime dummySweep2 = 0, targetTime2 = 0;
   int flipIdx = LP_FindBarIndex(rates, count, sweepTime1);
   int leg2 = (flipIdx >= 0) ? LP_CheckLeg(rates, count, flipIdx, dir2, target2, oppEdge2, dummySweep2, targetTime2) : -1;

   if(leg2 == 1)
   {
      out.flipTime = sweepTime1;
      out.label = (dir2 > 0) ? "Sweep_Buy" : "Sweep_Sell";
      out.finalDir = dir2;
      out.oneRTime = targetTime2;
   }
   // leg2 == 0 (برگشت به لبه‌ی اول) یا -1 (هیچ‌کدام تا پایانِ پنجره) -> NoDirection (پیش‌فرض)
}

//------------------------------------------------------------------
// NY Edge — بخش ۳.۲ (+ F3 نسخه‌ی ۲: اسکن فقط از لحظه‌ی رأی، PreExisting)
//------------------------------------------------------------------
struct SNYEdgeState
{
   bool     broken;
   int      breakDir;      // +1/-1
   datetime breakTime;
   int      sweepDir;      // آخرین سوییپِ تأییدشده (اگر broken نشده باشد)، وگرنه بی‌اثر
   bool     preExisting;    // F3: در لحظه‌ی شروعِ اسکن (بسته‌شدنِ باکس) قیمت از قبل فراتر از آستانه بود
   int      preExistingDir;
   double   penDepth;       // عمقِ نفوذِ ($) مربوط به وضعیتِ فعلی (Break/Sweep/PreExisting)؛ ۰ برای Silent
   double   maxPenHigh;     // داخلی: بیشینه‌ی نفوذِ در حالِ انتظارِ بالای لبه‌ی بالا (برایِ تشخیصِ سوییپ)
   double   maxPenLow;      // داخلی: بیشینه‌ی نفوذِ در حالِ انتظارِ زیرِ لبه‌ی پایین
   bool     pendingHigh;    // نفوذِ بالا رخ داده و هنوز با یک کندلِ کامل تأیید نشده
   bool     pendingLow;
};

void NY_ResetState(SNYEdgeState &s)
{
   s.broken = false; s.breakDir = 0; s.breakTime = 0;
   s.sweepDir = 0;
   s.preExisting = false; s.preExistingDir = 0;
   s.penDepth = 0;
   s.maxPenHigh = 0; s.maxPenLow = 0;
   s.pendingHigh = false; s.pendingLow = false;
}

string NY_StatusLabel(const SNYEdgeState &s)
{
   if(s.preExisting) return(s.preExistingDir > 0 ? "PreExisting_Buy" : "PreExisting_Sell");
   if(s.broken) return(s.breakDir > 0 ? "Break_Buy" : "Break_Sell");
   if(s.sweepDir != 0) return(s.sweepDir > 0 ? "Sweep_Buy" : "Sweep_Sell");
   return("Silent");
}

// جهتِ +1/-1/۰ از یک وضعیتِ NY — برایِ مقایسه‌ی رنگِ روز (F5)، مستقل از این‌که وضعیت
// Break/Sweep/PreExisting باشد.
int NY_StateDir(const SNYEdgeState &s)
{
   if(s.preExisting) return(s.preExistingDir);
   if(s.broken) return(s.breakDir);
   return(s.sweepDir);
}

// نسخه‌ی ۳ (ClaudeCode_FixList_DayBias_v3.md، بندِ ۱): rates باید پنجره‌ی *کاملِ* ارزیابیِ
// NY Edge را پوشش دهد — از پایانِ سشنِ NY مرجع (نه از بسته‌شدنِ باکسِ توکیو؛ آن مرز بیش‌ازحد
// دیر بود و باعث می‌شد NY_AtVote همیشه Silent باشد) تا انتهایِ پنجره‌ی روزِ D — ترتیبِ صعودی.
// voteMoment = لحظه‌ی بسته‌شدنِ باکسِ توکیویِ D (جدا از شروعِ این آرایه). دو خروجی:
//   atVote    = عکسِ فوریِ ماشین‌وضعیت درست قبل از پردازشِ اولین کندلی که زمانش >= voteMoment است.
//   endOfDay  = وضعیتِ نهایی بعد از پردازشِ کاملِ آرایه.
// PreExisting فقط اگر قیمت در همان لحظه‌یِ *شروعِ این آرایه* (پایانِ سشنِ NY مرجع) از قبل
// فراتر از آستانه باشد (نادر - گپِ آخرِ هفته)؛ در غیرِ این‌صورت اسکنِ رویدادمحورِ Break/Sweep
// از همان کندلِ اول شروع می‌شود.
void NY_Track(const MqlRates &rates[], int count, double prevHigh, double prevLow,
              datetime voteMoment, SNYEdgeState &atVote, SNYEdgeState &endOfDay)
{
   double range      = prevHigh - prevLow;
   double threshHigh = prevHigh + 0.23 * range;
   double threshLow  = prevLow  - 0.23 * range;

   SNYEdgeState state;
   NY_ResetState(state);

   if(count > 0)
   {
      double startPrice = rates[0].open; // قیمتِ دقیقاً در لحظه‌ی شروعِ پنجره (پایانِ سشنِ NY مرجع)
      if(startPrice > threshHigh)
      {
         state.preExisting = true; state.preExistingDir = 1;
         state.penDepth = startPrice - prevHigh;
      }
      else if(startPrice < threshLow)
      {
         state.preExisting = true; state.preExistingDir = -1;
         state.penDepth = prevLow - startPrice;
      }
   }

   bool voteCaptured = false;
   if(state.preExisting) { atVote = state; voteCaptured = true; } // از همان لحظه‌ی صفر تعیین‌تکلیف شده

   for(int i = 0; i < count; i++)
   {
      if(!voteCaptured && rates[i].time >= voteMoment)
      {
         atVote = state; // عکسِ فوری درست قبل از این کندل - رویدادِ خودِ این کندل هنوز لحاظ نشده
         voteCaptured = true;
      }

      if(state.broken || state.preExisting)
         continue; // وضعیت قفل شده؛ رویدادهای بعدی بی‌اثرند - اما اسکن ادامه می‌یابد تا atVote درست‌جا capture شود

      if(rates[i].close > threshHigh)
      {
         state.broken = true; state.breakDir = 1; state.breakTime = rates[i].time;
         state.penDepth = rates[i].close - prevHigh;
      }
      else if(rates[i].close < threshLow)
      {
         state.broken = true; state.breakDir = -1; state.breakTime = rates[i].time;
         state.penDepth = prevLow - rates[i].close;
      }
      else
      {
         if(rates[i].high > prevHigh)
         {
            double pen = rates[i].high - prevHigh;
            if(pen > state.maxPenHigh) state.maxPenHigh = pen;
            state.pendingHigh = true;
         }
         if(rates[i].low < prevLow)
         {
            double pen = prevLow - rates[i].low;
            if(pen > state.maxPenLow) state.maxPenLow = pen;
            state.pendingLow = true;
         }
         bool fullyInside = (rates[i].high <= prevHigh && rates[i].low >= prevLow);
         if(fullyInside)
         {
            if(state.pendingHigh) { state.sweepDir = -1; state.penDepth = state.maxPenHigh; state.pendingHigh = false; }
            if(state.pendingLow)  { state.sweepDir = 1;  state.penDepth = state.maxPenLow;  state.pendingLow  = false; }
         }
      }
   }

   if(!voteCaptured) atVote = state; // voteMoment بعد از آخرین کندلِ آرایه بود (نباید معمولاً رخ دهد)
   endOfDay = state;
}

//------------------------------------------------------------------
// F4 — Assert تعریفِ Break: هر لیبلی که با "Break" شروع شود باید نفوذش >= ۲۳٪ باشد.
// می‌بایست همیشه به‌صورتِ ساختاری برقرار باشد (thresh = prevEdge ± 23%×range و close از آن
// عبور کرده)؛ نقض = باگِ واقعی، نه دادهٔ مرزی.
//------------------------------------------------------------------
bool DL_AssertBreakPenetration(string nyLabel, double penPct)
{
   if(StringSubstr(nyLabel, 0, 5) == "Break")
      return(penPct >= 23.0 - 0.001);
   return(true);
}

// نسخه‌ی ۳ (بندِ ۱، آخرین بولت): هر NY_BreakTime باید داخلِ پنجره‌ی ارزیابیِ NY Edge باشد
// (>= پایانِ سشنِ NY مرجع، < انتهایِ پنجره‌ی روزِ D). breakTime==0 یعنی بریکی رخ نداده، معتبر است.
bool DL_AssertBreakTimeInWindow(datetime breakTime, datetime windowStart, datetime windowEnd)
{
   if(breakTime == 0) return(true);
   return(breakTime >= windowStart && breakTime < windowEnd);
}

//------------------------------------------------------------------
// رنگ روز — بخش ۳.۳ (F5 نسخه‌ی ۲: فرمولِ مصوب، بدونِ حالتِ ویژه‌ی «هنوز شکستی نداشته»)
//
// if LP_FirstBreak وجود ندارد یا LP در لحظه رأی Sweep شده (لیبلِ نهایی Sweep_*) -> Red
// elif NY_AtVote == Silent -> Yellow
// elif جهتِ LP_FirstBreak == جهتِ NY_AtVote -> Green
// else -> Red
//
// توجه: رأیِ LP رویدادمحور است (اولین شکستِ معتبر، هر زمان از پنجره‌ی روز که رخ دهد)، نه
// ساعت‌محور مثلِ NY_AtVote — چون خودِ شکستِ LP طبق تعریف حتماً *بعد* از بسته‌شدنِ باکسِ توکیو
// رخ می‌دهد، درحالی‌که رأیِ NY دقیقاً در لحظه‌ی بسته‌شدنِ باکس سنجیده می‌شود.
//------------------------------------------------------------------
string DL_ComputeDayColor(const SLPResult &lp, const SNYEdgeState &nyAtVote)
{
   // نسخه‌ی ۳ (ClaudeCode_FixList_DayBias_v3.md، بندِ ۲): تثبیتِ رسمی — روزی که تا لحظه‌ی
   // رأی هیچ کندلِ M5 شرطِ شکستِ معتبرِ باکس را پاس نکرده (LP_FirstBreak_Dir خالی، lp.hasBreak
   // == false) همیشه Red است؛ حالتِ ویژه‌ی جداگانه (مثلاً Yellow) ندارد.
   if(!lp.hasBreak) return("Red");

   // LP سوییپِ تأییدشده داشته (لیبلِ نهایی Sweep_*) -> هم Red.
   if(lp.flipTime != 0) return("Red");

   string nyLabel = NY_StatusLabel(nyAtVote);
   if(nyLabel == "Silent") return("Yellow");

   int nyDir = NY_StateDir(nyAtVote);
   return(lp.firstDir == nyDir ? "Green" : "Red");
}

//------------------------------------------------------------------
// نسخه‌ی ۵ (ClaudeCode_Spec_DayBias_v5_TokyoBracket.md) — ستون‌های صرفاً-مشاهده‌ای برایِ
// بک‌تستِ استراتژیِ کاندیدِ «Tokyo Bracket». هیچ اثری روی LP_Detect/DL_ComputeDayColor/assertهایِ
// موجود ندارد؛ فقط دوباره روی همان rates (بعد از یک شکستِ معتبر) اسکن می‌کند و leg۱/leg۲ را با
// همان LP_CheckLeg موجود (بدونِ تغییر در خودش) بازتولید می‌کند تا با ماشین‌وضعیتِ اصلی هم‌راستا بماند.
//------------------------------------------------------------------
struct SBracketMetrics
{
   bool     hasData;              // false اگر lp.hasBreak==false (همه‌ی مقادیرِ زیر بی‌معنی‌اند)
   double   breakCloseOvershoot;  // $ - همیشه >= 0
   datetime retestTime;           // اولین لمسِ مجددِ لبه بعد از کلوزِ کندلِ شکست؛ ۰=هرگز
   bool     retestBefore1R;
   bool     retestWithinTokyo;
   double   maxDepthPct;          // بیشینه‌ی نفوذِ به داخلِ باکس، ٪ ارتفاعِ باکس (>۱۰۰ یعنی سوییپ)
   datetime maxDepthTime;         // ۰ اگر maxDepthPct<=0
   bool     rawSweepOccurred;     // عبور از لبه‌ی مقابل قبل از ۱R (مستقل از این‌که لیبلِ نهایی Sweep_* شد یا نه)
   double   trade2MaxR;           // فقط معنادار اگر rawSweepOccurred
   bool     trade2StopHit;        // فقط معنادار اگر rawSweepOccurred
   datetime reach1RTime;          // ۱R برایِ ترید ۱ (جهتِ اول)؛ ۰ اگر نرسید (شاملِ روزهایِ سوییپ - آنجا ترید۱ استاپ خورده)
   datetime depth50Time;          // اولین لحظه‌ی نفوذِ >=۵۰٪ در همان بازه‌ی «قبل از ۱R»؛ ۰ اگر هرگز
};

void BR_ResetMetrics(SBracketMetrics &m)
{
   m.hasData = false;
   m.breakCloseOvershoot = 0;
   m.retestTime = 0; m.retestBefore1R = false; m.retestWithinTokyo = false;
   m.maxDepthPct = 0; m.maxDepthTime = 0;
   m.rawSweepOccurred = false;
   m.trade2MaxR = 0; m.trade2StopHit = false;
   m.reach1RTime = 0;
   m.depth50Time = 0;
}

// rates/count/boxHigh/boxLow/lp: همان‌هایی که به LP_Detect داده شد و از آن برگشت (بدونِ تغییر).
// tokyoSessionEnd: مرزِ «پایانِ سشنِ کاملِ توکیو» برایِ RetestWithinTokyo - v5.1: ۰۵:۰۰ به وقتِ
// نیویورک (تأییدشده با کاربر)، نه باکسِ SOB یک‌ساعته؛ نگاه کن به DataScript.mq5.
void LP_ComputeBracketMetrics(const MqlRates &rates[], int count, double boxHigh, double boxLow,
                               const SLPResult &lp, datetime tokyoSessionEnd, SBracketMetrics &out)
{
   BR_ResetMetrics(out);
   if(!lp.hasBreak) return;
   out.hasData = true;

   int breakIdx = LP_FindBarIndex(rates, count, lp.firstTime);
   if(breakIdx < 0) return; // نباید رخ دهد؛ گاردِ دفاعی محض

   int dir = lp.firstDir;
   double boxSize = boxHigh - boxLow;
   double edge    = (dir > 0) ? boxHigh : boxLow;
   double oppEdge = (dir > 0) ? boxLow  : boxHigh;
   double target1 = edge + dir * boxSize;

   out.breakCloseOvershoot = MathAbs(rates[breakIdx].close - edge);

   // گاردِ دفاعی: boxSize<=0 (باکسِ تخت، عملاً هرگز با دیتایِ واقعی رخ نمی‌دهد) یعنی درصدهایِ
   // نفوذ/R تعریف‌نشده‌اند (تقسیم بر صفر) — مثلِ گاردِ boxSize>0 که R_Day هم در DataScript.mq5 دارد.
   if(boxSize <= 0) return;

   // ۱) بازتولیدِ leg۱ (همان LP_CheckLeg موجود، بدونِ تغییر) فقط برایِ Reach1R_Time — این باید مستقل
   //    از سرنوشتِ leg۲ باشد، چون «ترید ۱» دقیقاً با اولین برخورد به oppEdge استاپ می‌خورد (تعریفِ Sweep).
   datetime sweepTime1 = 0, targetTime1 = 0;
   int leg1 = LP_CheckLeg(rates, count, breakIdx, dir, target1, oppEdge, sweepTime1, targetTime1);
   if(leg1 == 1) out.reach1RTime = targetTime1;
   out.rawSweepOccurred = (leg1 == 0);

   // ۲) اسکنِ retest + عمقِ نفوذ: از اولین کندلِ *بعد از* کندلِ شکست (breakIdx+1)، طبقِ تعریفِ
   //    مرزیِ v5 («از کلوزِ کندلِ شکست»، نه از بازشدنش). retest در کلِ باقی‌ماندهِ روز جستجو می‌شود
   //    (مستقل از ۱R/سوییپ)؛ عمقِ نفوذ فقط تا لحظه‌ی سوییپ/۱R (هرکدام زودتر) دنبال می‌شود.
   bool depthTrackingOpen = true;

   // v5.1 — فیکسِ کیسِ مرزی (ریشه‌یابیِ Assertِ فیل‌شده در ۲۰۲۶-۰۴-۲۴): اگر خودِ کندلِ شکست
   // به‌قدری پرنوسان بوده که هم‌زمان لبه‌ی مقابل/هدفِ ۱R را هم لمس کرده، leg۱ (که از خودِ breakIdx
   // شروع می‌شود، بدونِ تغییر) آن را همان‌جا سوییپ/۱R حساب می‌کند - اما حلقه‌ی زیر از breakIdx+۱
   // شروع می‌شود و آن کندل را هرگز نمی‌بیند. بدونِ این گارد، RawSweepOccurred=1 می‌شد بدونِ اینکه
   // MaxDepthIntoBox_Before1R_Pct عمقِ آن کندل را لحاظ کند (ناسازگاریِ Assertِ نسخه‌ی ۵).
   if(sweepTime1 == rates[breakIdx].time)
   {
      double depthAtBreak = (dir > 0) ? (edge - rates[breakIdx].low) / boxSize * 100.0
                                       : (rates[breakIdx].high - edge) / boxSize * 100.0;
      if(depthAtBreak > out.maxDepthPct) { out.maxDepthPct = depthAtBreak; out.maxDepthTime = rates[breakIdx].time; }
      if(out.maxDepthPct >= 50.0 && out.depth50Time == 0) out.depth50Time = rates[breakIdx].time;
      depthTrackingOpen = false; // پنجره‌ی «قبل از ۱R» همان‌جا (کندلِ شکست) با سوییپ بسته شد
   }
   else if(targetTime1 == rates[breakIdx].time)
   {
      depthTrackingOpen = false; // ۱R همان کندلِ شکست رسید؛ پنجره‌ی «قبل از ۱R» خالی است
   }

   for(int i = breakIdx + 1; i < count; i++)
   {
      bool touchesEdge = (dir > 0) ? (rates[i].low <= edge) : (rates[i].high >= edge);
      if(touchesEdge && out.retestTime == 0)
      {
         out.retestTime = rates[i].time;
         // تساوی هم‌زمان با Reach1R_Time (همان کندل): محافظه‌کارانه «قبل/هم‌زمان» حساب می‌شود، چون
         // ترتیبِ درون‌کندلی از OHLC اثبات‌پذیر نیست (همان اصلِ پذیرفته‌شده‌ی LP_CheckLeg).
         out.retestBefore1R = (out.reach1RTime == 0) || (rates[i].time <= out.reach1RTime);
         out.retestWithinTokyo = (rates[i].time < tokyoSessionEnd);
      }

      if(depthTrackingOpen)
      {
         bool sweepHitHere  = (dir > 0) ? (rates[i].low  <= oppEdge) : (rates[i].high >= oppEdge);
         bool targetHitHere = (dir > 0) ? (rates[i].high >= target1) : (rates[i].low  <= target1);
         double depthCandle = (dir > 0) ? (edge - rates[i].low) / boxSize * 100.0
                                         : (rates[i].high - edge) / boxSize * 100.0;

         if(sweepHitHere)
         {
            if(depthCandle > out.maxDepthPct) { out.maxDepthPct = depthCandle; out.maxDepthTime = rates[i].time; }
            if(out.maxDepthPct >= 50.0 && out.depth50Time == 0) out.depth50Time = rates[i].time;
            depthTrackingOpen = false; // پنجره‌ی «قبل از ۱R» اینجا با سوییپ تمام شد
         }
         else if(targetHitHere)
         {
            depthTrackingOpen = false; // ۱R رسید؛ خودِ این کندل داخلِ پنجره‌ی «قبل از ۱R» حساب نمی‌شود
         }
         else if(depthCandle > 0)
         {
            if(depthCandle > out.maxDepthPct) { out.maxDepthPct = depthCandle; out.maxDepthTime = rates[i].time; }
            if(out.maxDepthPct >= 50.0 && out.depth50Time == 0) out.depth50Time = rates[i].time;
         }
      }
   }

   // ۳) اگر سوییپِ خام رخ داد، «ترید ۲» (ورود در لبه‌ی مقابل، استاپ = لبه‌ی اول) را بازتولید کن —
   //    خامِ بدونِ شرطِ ۱R (طبقِ سندِ v5، برخلافِ لیبلِ Sweep_* که فقط >=۱R را قبول می‌کند).
   if(out.rawSweepOccurred)
   {
      int dir2       = -dir;
      double edge2    = oppEdge;
      double target2  = edge2 + dir2 * boxSize;
      double oppEdge2 = edge;
      int flipIdx = LP_FindBarIndex(rates, count, sweepTime1);
      if(flipIdx >= 0)
      {
         double maxR = 0;
         for(int i = flipIdx; i < count; i++)
         {
            double rNow = (dir2 > 0) ? (rates[i].high - edge2) / boxSize : (edge2 - rates[i].low) / boxSize;
            if(rNow > maxR) maxR = rNow;
         }
         out.trade2MaxR = maxR;

         datetime dummySweep2 = 0, targetTime2 = 0;
         int leg2 = LP_CheckLeg(rates, count, flipIdx, dir2, target2, oppEdge2, dummySweep2, targetTime2);
         out.trade2StopHit = (leg2 == 0);
      }
   }
}

// نسخه‌ی ۵، بندِ ۴.۲ — پنج ناوردایِ سازگاریِ داخلی که سندِ v5 به‌صراحت خواسته assert شوند.
// rDayVal = همان مقدارِ R_Day که DataScript.mq5 برایِ این روز محاسبه کرده (۰ اگر NoDirection).
bool BR_AssertConsistency(const SLPResult &lp, const SBracketMetrics &bm, double rDayVal, string &outReason)
{
   if(!bm.hasData) return(true);

   bool isSweepLabel = (StringSubstr(lp.label, 0, 6) == "Sweep_");

   // v5.1: >=۱۰۰٪ (نه صرفاً >۱۰۰٪ دقیق) - لمسِ دقیقاً روی لبه‌ی مقابل (بدونِ آورشوت) هم طبقِ تعریفِ
   // مکانیکیِ Sweep («عبور از لبه، حتی شدو» - LP_CheckLeg با <=/>= چک می‌کند) یک سوییپِ معتبر است.
   if(isSweepLabel && !(bm.rawSweepOccurred && bm.maxDepthPct >= 100.0 - 0.001))
   { outReason = "Sweep_* label but RawSweepOccurred/MaxDepthIntoBox_Before1R_Pct inconsistent"; return(false); }

   if(lp.hasBreak && lp.reached1R && bm.maxDepthPct > 100.0)
   { outReason = "LP_Reached1R=1 without sweep but MaxDepthIntoBox_Before1R_Pct>100"; return(false); }

   if(bm.retestBefore1R && (bm.retestTime == 0 || (bm.reach1RTime != 0 && bm.retestTime > bm.reach1RTime)))
   { outReason = "RetestTouch_Before1R=1 but timing inconsistent"; return(false); }

   if(bm.rawSweepOccurred && bm.trade2MaxR >= 1.0 && isSweepLabel && rDayVal < bm.trade2MaxR - 0.001)
   { outReason = "Trade2_MaxR>=1 with Sweep_* label but R_Day inconsistent"; return(false); }

   if(bm.depth50Time != 0 && bm.maxDepthPct < 50.0)
   { outReason = "Depth50_Time set but MaxDepthIntoBox_Before1R_Pct<50"; return(false); }

   if((bm.maxDepthTime != 0) != (bm.maxDepthPct > 0.0))
   { outReason = "MaxDepth_Time / MaxDepthIntoBox_Before1R_Pct presence mismatch"; return(false); }

   return(true);
}

//------------------------------------------------------------------
// نسخه‌ی ۶ (ClaudeCode_Spec_DayBias_v6_ReEntry.md) — ستون‌های صرفاً-مشاهده‌ای برایِ ایده‌ی
// «بازیافت» (re-entry لیمیت رویِ لبه بعد از خروجِ ترید ۱ در ۱R) + داده‌های عمومیِ مسیرِ روز.
// همه بر مبنایِ جهتِ *تأییدشده* (lp.finalDir) و لبه‌ی متناظرش - برایِ روزهایِ Sweep_* یعنی جهتِ دوم
// و لبه‌ی مقابل (دقیقاً همان edge/dir که R_Day خودش در DataScript.mq5 برایِ روزهایِ سوییپ استفاده
// می‌کند - سازگاریِ EOD_R<=R_Day به همین همسان‌سازی متکی است). فقط برایِ روزهایی پر می‌شود که جهتی
// تأیید شده (lp.finalDir!=0، معادلِ LP_1R_Time غیرِخالی)؛ NoDirection همیشه کاملاً خالی است - چون
// بدونِ جهتِ تأییدشده، «مضربِ باکس» و «لبه» تعریفی ندارند (همانندِ R_Day که برایِ NoDirection خالی است).
//------------------------------------------------------------------
struct SReEntryMetrics
{
   bool     hasData;                   // lp.hasBreak && lp.finalDir!=0 (وگرنه همه‌ی ۱۰ ستون خالی)
   datetime postR1TouchTime;           // ستونِ ۱، ۰=هرگز برنگشت
   double   postTouchMaxR;             // ستونِ ۲، فقط اگر ستونِ ۱ پر
   double   postTouchMaxDepthPct;      // ستونِ ۳، فقط اگر ستونِ ۱ پر
   bool     postTouchReached2RBefore;  // ستونِ ۴، فقط اگر ستونِ ۱ پر
   datetime firstTouch1_5RTime;        // ستونِ ۵-الف
   datetime firstTouch2RTime;          // ستونِ ۵-ب
   datetime firstTouch3RTime;          // ستونِ ۵-ج
   double   pullbackAfter2RDepthPct;   // ستونِ ۶، فقط اگر ستونِ ۵-ب پر؛ می‌تواند منفی باشد
   double   eodR;                      // ستونِ ۷، می‌تواند منفی باشد
   datetime timeAtMaxR;                // ستونِ ۸
   datetime postTouchCross50Time;      // v6.1، ستونِ ۹، فقط اگر ستونِ ۱ پر
   datetime postTouchCross75Time;      // v6.1، ستونِ ۱۰، فقط اگر ستونِ ۱ پر
};

void RE_ResetMetrics(SReEntryMetrics &m)
{
   m.hasData = false;
   m.postR1TouchTime = 0; m.postTouchMaxR = 0; m.postTouchMaxDepthPct = 0; m.postTouchReached2RBefore = false;
   m.firstTouch1_5RTime = 0; m.firstTouch2RTime = 0; m.firstTouch3RTime = 0;
   m.pullbackAfter2RDepthPct = 0;
   m.eodR = 0; m.timeAtMaxR = 0;
   m.postTouchCross50Time = 0; m.postTouchCross75Time = 0;
}

// rates/count/boxHigh/boxLow/lp: همان‌هایی که به LP_Detect داده شد (بدونِ تغییر). dayHighTime/
// dayLowTime/dayCloseVal: از پنجره‌ی *کاملِ* روز (DataScript.mq5) - برایِ خودکفا بودنِ Time_At_MaxR/EOD_R.
void LP_ComputeReEntryMetrics(const MqlRates &rates[], int count, double boxHigh, double boxLow,
                               const SLPResult &lp, datetime dayHighTime, datetime dayLowTime, double dayCloseVal,
                               SReEntryMetrics &out)
{
   RE_ResetMetrics(out);
   if(!lp.hasBreak || lp.finalDir == 0 || lp.oneRTime == 0) return; // NoDirection یا هرگز به ۱R نرسید

   int dir = lp.finalDir;
   double boxSize = boxHigh - boxLow;
   double edge    = (dir > 0) ? boxHigh : boxLow;

   out.hasData = true;
   if(boxSize <= 0) return; // گاردِ دفاعیِ همسانِ v5 (باکسِ تخت، عملاً هرگز رخ نمی‌دهد)

   // بندِ ۳ سند: روزهایِ Sweep_* نسبت به جهتِ دوم و لبه‌ی مقابل سنجیده می‌شوند - anchor برایِ شروعِ
   // اسکنِ «مسیرِ جهتِ تأییدشده» برایِ آن‌ها flipTime (شروعِ leg۲) است، نه firstTime (شروعِ leg۱).
   bool isSweepLabel = (StringSubstr(lp.label, 0, 6) == "Sweep_");
   datetime anchorTime = isSweepLabel ? lp.flipTime : lp.firstTime;
   int anchorIdx = LP_FindBarIndex(rates, count, anchorTime);
   if(anchorIdx < 0) return; // گاردِ دفاعیِ محض

   // --- بندِ ۵: FirstTouch_1.5R/2R/3R، از anchorIdx (شاملِ خودش، مثلِ leg۱/LP_CheckLeg) تا پایانِ روز ---
   double level15 = edge + dir * 1.5 * boxSize;
   double level2  = edge + dir * 2.0 * boxSize;
   double level3  = edge + dir * 3.0 * boxSize;
   for(int i = anchorIdx; i < count; i++)
   {
      bool hit15 = (dir > 0) ? (rates[i].high >= level15) : (rates[i].low <= level15);
      bool hit2  = (dir > 0) ? (rates[i].high >= level2)  : (rates[i].low <= level2);
      bool hit3  = (dir > 0) ? (rates[i].high >= level3)  : (rates[i].low <= level3);
      if(hit15 && out.firstTouch1_5RTime == 0) out.firstTouch1_5RTime = rates[i].time;
      if(hit2  && out.firstTouch2RTime   == 0) out.firstTouch2RTime   = rates[i].time;
      if(hit3  && out.firstTouch3RTime   == 0) out.firstTouch3RTime   = rates[i].time;
   }

   // --- بندِ ۶: Pullback_After2R_MaxDepthPct، فقط اگر ۲R زده شد؛ از کندلِ *بعدِ* لمسِ ۲R تا پایانِ
   //    روز - همان مقیاسِ MaxDepth (۰=لبه، ۱۰۰=لبه‌ی مقابل)؛ اگر هرگز به لبه برنگشت، منفی می‌ماند
   //    (فاصله‌ی همچنان‌بیرون‌ازباکس تا لبه).
   if(out.firstTouch2RTime != 0)
   {
      int touch2Idx = LP_FindBarIndex(rates, count, out.firstTouch2RTime);
      if(touch2Idx >= 0)
      {
         double worst = (dir > 0) ? rates[touch2Idx].low : rates[touch2Idx].high;
         for(int i = touch2Idx + 1; i < count; i++)
         {
            if(dir > 0) { if(rates[i].low  < worst) worst = rates[i].low;  }
            else        { if(rates[i].high > worst) worst = rates[i].high; }
         }
         out.pullbackAfter2RDepthPct = (dir > 0) ? (edge - worst) / boxSize * 100.0
                                                  : (worst - edge) / boxSize * 100.0;
      }
   }

   // --- بندِ ۱-۴: بازیافتِ بعد از ۱R، از کندلِ *بعدِ* LP_1R_Time (طبقِ همان قراردادِ «بعد از کلوز» -
   //    مثلِ RetestTouch_Time در v5) تا پایانِ روز ---
   int r1Idx = LP_FindBarIndex(rates, count, lp.oneRTime);
   if(r1Idx >= 0)
   {
      for(int i = r1Idx + 1; i < count; i++)
      {
         bool touches = (dir > 0) ? (rates[i].low <= edge) : (rates[i].high >= edge);
         if(touches) { out.postR1TouchTime = rates[i].time; break; }
      }

      if(out.postR1TouchTime != 0)
      {
         out.postTouchReached2RBefore = (out.firstTouch2RTime != 0 && out.firstTouch2RTime < out.postR1TouchTime);

         int touchIdx = LP_FindBarIndex(rates, count, out.postR1TouchTime);
         double maxR = 0, maxDepth = 0;
         for(int i = touchIdx + 1; i < count; i++)
         {
            double rNow = (dir > 0) ? (rates[i].high - edge) / boxSize : (edge - rates[i].low) / boxSize;
            if(rNow > maxR) maxR = rNow;
            double depthNow = (dir > 0) ? (edge - rates[i].low) / boxSize * 100.0
                                         : (rates[i].high - edge) / boxSize * 100.0;
            if(depthNow > maxDepth) maxDepth = depthNow;
            // v6.1: اولین لحظه‌ی عبورِ عمق از ۵۰٪/۷۵٪ (برایِ بهینه‌سازیِ استاپِ ورودِ دوم بینِ این دو سطح).
            if(depthNow > 50.0 && out.postTouchCross50Time == 0) out.postTouchCross50Time = rates[i].time;
            if(depthNow > 75.0 && out.postTouchCross75Time == 0) out.postTouchCross75Time = rates[i].time;
         }
         out.postTouchMaxR = maxR;
         out.postTouchMaxDepthPct = maxDepth;
      }
   }

   // --- بندِ ۷/۸: EOD_R (کلوزِ پایانِ روز، می‌تواند منفی باشد) و Time_At_MaxR (کپیِ خودکفایِ
   //    DayHigh_Time/DayLow_Time طبقِ جهتِ تأییدشده) ---
   out.eodR = (dir > 0) ? (dayCloseVal - edge) / boxSize : (edge - dayCloseVal) / boxSize;
   out.timeAtMaxR = (dir > 0) ? dayHighTime : dayLowTime;
}

// نسخه‌ی ۶، بندِ ۴ — چهار ناوردایِ سازگاریِ داخلی که سندِ v6 به‌صراحت خواسته assert شوند.
// rDayVal = همان مقدارِ R_Day که DataScript.mq5 برایِ این روز محاسبه کرده.
bool RE_AssertConsistency(const SLPResult &lp, const SReEntryMetrics &re, double rDayVal, string &outReason)
{
   if(!re.hasData) return(true);

   // معادلِ «PostTouch_MaxR پر ⟹ PostR1_EdgeTouch_Time پر و >= Reach1R_Time»: چون Reach1R_Time (v5)
   // برایِ روزهایِ Sweep_* همیشه خالی است (طبقِ تعریفِ خودش)، مقایسه با LP_1R_Time انجام می‌شود که
   // معادلِ عمومی‌ترِ همان مفهوم برایِ هر دو حالت است؛ با ساختِ کد postR1TouchTime همیشه یا ۰ است یا
   // اکیداً بعد از lp.oneRTime.
   if(re.postR1TouchTime != 0 && re.postR1TouchTime <= lp.oneRTime)
   { outReason = "PostR1_EdgeTouch_Time <= LP_1R_Time (should be strictly after)"; return(false); }

   if(re.firstTouch2RTime != 0 && rDayVal < 2.0 - 0.01)
   { outReason = "FirstTouch_2R_Time set but R_Day<2"; return(false); }

   if(re.postTouchReached2RBefore && !(re.firstTouch2RTime != 0 && re.firstTouch2RTime <= re.postR1TouchTime))
   { outReason = "PostTouch_Reached2R_Before=1 but FirstTouch_2R_Time timing inconsistent"; return(false); }

   if(re.eodR > rDayVal + 0.001)
   { outReason = "EOD_R>R_Day"; return(false); }

   // v6.1
   if(re.postTouchCross75Time != 0 && !(re.postTouchMaxDepthPct > 75.0))
   { outReason = "PostTouch_Cross75_Time set but PostTouch_MaxDepthPct<=75"; return(false); }

   if(re.postTouchCross50Time != 0 && !(re.postTouchMaxDepthPct > 50.0))
   { outReason = "PostTouch_Cross50_Time set but PostTouch_MaxDepthPct<=50"; return(false); }

   if(re.postTouchCross75Time != 0 && !(re.postTouchCross50Time != 0 && re.postTouchCross50Time <= re.postTouchCross75Time))
   { outReason = "PostTouch_Cross75_Time set but PostTouch_Cross50_Time missing/later"; return(false); }

   if((re.postTouchCross50Time != 0 && re.postTouchCross50Time < re.postR1TouchTime) ||
      (re.postTouchCross75Time != 0 && re.postTouchCross75Time < re.postR1TouchTime))
   { outReason = "PostTouch_Cross50/75_Time earlier than PostR1_EdgeTouch_Time"; return(false); }

   return(true);
}

#endif // DAYBIAS_DETECTIONLAYER_MQH
