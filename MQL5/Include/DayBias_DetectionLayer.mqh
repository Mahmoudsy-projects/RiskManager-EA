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

#endif // DAYBIAS_DETECTIONLAYER_MQH
