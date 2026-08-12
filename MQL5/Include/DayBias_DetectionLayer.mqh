//+------------------------------------------------------------------+
//|                                     DayBias_DetectionLayer.mqh   |
//| لایه‌ی تشخیص Day Bias — طبق «تعریف‌های مکانیکی فریزشده» (بخش ۳ سندِ  |
//| دستورکار): LP (باکس توکیو)، NY Edge (سشن NY روز قبل)، رنگ روز.       |
//| همه‌ی محاسبات روی M5.                                                |
//+------------------------------------------------------------------+
#ifndef DAYBIAS_DETECTIONLAYER_MQH
#define DAYBIAS_DETECTIONLAYER_MQH

#include "DayBias_BoxLayer.mqh"

//------------------------------------------------------------------
// LP — بخش ۳.۱
//------------------------------------------------------------------
struct SLPResult
{
   bool     hasBreak;
   int      firstDir;         // +1 Buy، -1 Sell، 0 = هیچ شکست معتبری پیدا نشد
   datetime firstTime;
   double   firstBodyRatio;
   bool     reached1R;        // جهتِ اول پیش از سوییپ به ۱R رسید
   datetime flipTime;         // زمانِ سوییپ (۰ اگر سوییپ رخ نداده)
   string   label;            // Buy / Sell / Sweep_Buy / Sweep_Sell / NoDirection
   int      finalDir;         // جهتِ نهاییِ لیبل (برای R_Day)، ۰ اگر NoDirection
};

// بررسیِ یک «leg»: آیا جهتِ dir از startIdx تا پایانِ آرایه، قبل از عبور از oppEdge
// به target می‌رسد؟  1=رسید به target، 0=سوییپ شد (oppEdge لمس/عبور شد)، -1=هیچ‌کدام تا پایانِ روز.
// اگر یک کندل هم‌زمان هر دو شرط را داشته باشد، محافظه‌کارانه سوییپ در نظر گرفته می‌شود
// (نمی‌توان ترتیبِ درون‌کندلی را از OHLC اثبات کرد).
int LP_CheckLeg(const MqlRates &rates[], int count, int startIdx, int dir, double target, double oppEdge, datetime &eventTime)
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
      if(sweepHit)  { eventTime = rates[i].time; return(0); }
      if(targetHit) { eventTime = rates[i].time; return(1); }
   }
   return(-1);
}

int LP_FindBarIndex(const MqlRates &rates[], int count, datetime t)
{
   for(int i = 0; i < count; i++)
      if(rates[i].time == t) return(i);
   return(-1);
}

// rates باید از اولین کندلِ بعد از بسته‌شدنِ باکسِ توکیو تا پایانِ روز باشد (ترتیبِ صعودی).
void LP_Detect(const MqlRates &rates[], int count, double boxHigh, double boxLow, SLPResult &out)
{
   out.hasBreak = false; out.firstDir = 0; out.firstTime = 0; out.firstBodyRatio = 0;
   out.reached1R = false; out.flipTime = 0; out.label = "NoDirection"; out.finalDir = 0;

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

   int leg1 = LP_CheckLeg(rates, count, breakIdx, out.firstDir, target1, oppEdge1, out.flipTime);

   if(leg1 == 1)
   {
      out.reached1R = true;
      out.label = (out.firstDir > 0) ? "Buy" : "Sell";
      out.finalDir = out.firstDir;
      return;
   }

   if(leg1 != 0)
      return; // نه ۱R نه سوییپ تا پایانِ روز -> NoDirection (out.flipTime هرگز ست نشد)

   // سوییپ رخ داد؛ جهتِ دوم از لبه‌ی مقابل با همان قانون سنجیده می‌شود (حداکثر یک فلیپ در روز).
   int dir2        = -out.firstDir;
   double edge2     = oppEdge1;
   double target2   = edge2 + dir2 * boxSize;
   double oppEdge2  = edge1;
   datetime dummyFlip = 0;
   int flipIdx = LP_FindBarIndex(rates, count, out.flipTime);
   int leg2 = (flipIdx >= 0) ? LP_CheckLeg(rates, count, flipIdx, dir2, target2, oppEdge2, dummyFlip) : -1;

   if(leg2 == 1)
   {
      out.label = (dir2 > 0) ? "Sweep_Buy" : "Sweep_Sell";
      out.finalDir = dir2;
   }
   // leg2 == 0 (برگشت به لبه‌ی اول) یا -1 (هیچ‌کدام تا پایانِ روز) -> NoDirection (پیش‌فرض)
}

//------------------------------------------------------------------
// NY Edge — بخش ۳.۲
//------------------------------------------------------------------
struct SNYEdgeState
{
   bool     broken;
   int      breakDir;      // +1/-1
   datetime breakTime;
   int      sweepDir;      // آخرین سوییپِ تأییدشده (اگر broken نشده باشد)، وگرنه بی‌اثر
   double   maxPenHigh;     // بیشینه‌ی نفوذِ بالای لبه‌ی بالا تا این لحظه ($)
   double   maxPenLow;      // بیشینه‌ی نفوذِ زیرِ لبه‌ی پایین تا این لحظه ($)
   bool     pendingHigh;    // نفوذِ بالا رخ داده و هنوز با یک کندلِ کامل تأیید نشده
   bool     pendingLow;
};

void NY_ResetState(SNYEdgeState &s)
{
   s.broken = false; s.breakDir = 0; s.breakTime = 0;
   s.sweepDir = 0;
   s.maxPenHigh = 0; s.maxPenLow = 0;
   s.pendingHigh = false; s.pendingLow = false;
}

string NY_StatusLabel(const SNYEdgeState &s)
{
   if(s.broken) return(s.breakDir > 0 ? "Break_Buy" : "Break_Sell");
   if(s.sweepDir != 0) return(s.sweepDir > 0 ? "Sweep_Buy" : "Sweep_Sell");
   return("Silent");
}

// rates باید کل روز را از نیمه‌شبِ نیویورک تا پایانِ روز پوشش دهد (ترتیبِ صعودی).
// voteMoment = زمانِ بسته‌شدنِ باکسِ توکیو؛ atVote = وضعیت تا آخرینِ کندلی که پیش از این
// لحظه بسته شده (کندل‌های با open time >= voteMoment در رأی لحاظ نمی‌شوند).
void NY_Track(const MqlRates &rates[], int count, double prevHigh, double prevLow,
              datetime voteMoment, SNYEdgeState &atVote, SNYEdgeState &endOfDay)
{
   double range      = prevHigh - prevLow;
   double threshHigh = prevHigh + 0.23 * range;
   double threshLow  = prevLow  - 0.23 * range;

   SNYEdgeState state;
   NY_ResetState(state);
   NY_ResetState(atVote);
   bool voteCaptured = false;

   for(int i = 0; i < count; i++)
   {
      if(!voteCaptured && rates[i].time >= voteMoment)
      {
         atVote = state;
         voteCaptured = true;
      }

      if(!state.broken)
      {
         if(rates[i].close > threshHigh)
         {
            state.broken = true; state.breakDir = 1; state.breakTime = rates[i].time;
         }
         else if(rates[i].close < threshLow)
         {
            state.broken = true; state.breakDir = -1; state.breakTime = rates[i].time;
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
               if(state.pendingHigh) { state.sweepDir = -1; state.pendingHigh = false; }
               if(state.pendingLow)  { state.sweepDir = 1;  state.pendingLow  = false; }
            }
         }
      }
   }

   if(!voteCaptured) atVote = state; // لحظه‌ی رأی بعد از آخرین کندلِ روز بود (نباید معمولاً رخ دهد)
   endOfDay = state;
}

//------------------------------------------------------------------
// رنگ روز — بخش ۳.۳
//
// نکته‌ی تفسیری (چون متنِ سند در این نقطه دو مبنای زمانیِ متفاوت را ترکیب می‌کند):
// «رأیِ LP در لحظه‌ی رأی» را به‌صورت رویدادمحور می‌خوانیم (D1، هر زمان از روز که رخ دهد)،
// نه ساعت‌محور مثلِ NY_AtVote؛ چون خودِ شکستِ LP طبق تعریف حتماً *بعد* از بسته‌شدنِ باکسِ
// توکیو رخ می‌دهد. «LP=Sweep» یعنی رویدادِ سوییپ در طولِ روز رخ داده (flipTime ست شده)،
// صرف‌نظر از این‌که جهتِ دوم نهایتاً به Sweep_X برسد یا به NoDirection سقوط کند.
// موردی که سند صریحاً پوشش نداده: وقتی LP هنوز هیچ شکستی نداشته (NoDirection بدونِ سوییپ)
// -> اینجا مثلِ Silent، زرد در نظر گرفته شده (سیگنالِ ناکافی، نه تضاد). این تفسیر باید با
// تستِ راستی‌آزمایی دستیِ بخشِ ۶ (به‌خصوص کیسِ ۱۱ اوت ۲۰۲۶) چک/تأیید شود.
//------------------------------------------------------------------
string DL_ComputeDayColor(const SLPResult &lp, const SNYEdgeState &nyAtVote)
{
   if(lp.flipTime != 0) return("Red");                                   // LP سوییپ شد

   bool nySilent = (!nyAtVote.broken && nyAtVote.sweepDir == 0);
   if(nySilent) return("Yellow");                                        // NY_AtVote = Silent

   if(lp.firstDir == 0) return("Yellow");                                // LP هنوز شکستی نداشته تا این لحظه

   int nyDir = nyAtVote.broken ? nyAtVote.breakDir : nyAtVote.sweepDir;
   return(lp.firstDir == nyDir ? "Green" : "Red");
}

#endif // DAYBIAS_DETECTIONLAYER_MQH
