//+------------------------------------------------------------------+
//|                                       DayBias_DataScript.mq5     |
//| اسکریپتِ فقط-خواندنیِ استخراجِ تاریخچه‌ی Day Bias Scorecard (XAUUSD). |
//| هیچ اردر/مودیفای‌ای ارسال نمی‌شود؛ فقط CopyRates + نوشتنِ یک CSV.     |
//| طبقِ سندِ دستورکار: MQL5/Files/DayBias_History_XAUUSD.csv           |
//|                                                                    |
//| نسخه‌ی ۲ (ClaudeCode_Fixes_v2_DayBias، ۱۲ اوت ۲۰۲۶) — F1/F2:         |
//| لنگرِ روزِ معاملاتی اصلاح شد. باکسِ LP برایِ روزِ D دیگر باکسِ عصرِ      |
//| همان روز نیست؛ باکسِ عصرِ *شبِ منتهی به D* (روزِ تقویمیِ قبل) است، و     |
//| پنجره‌ی ارزیابی LP از بسته‌شدنِ همان باکس تا شروعِ باکسِ روزِ بعد است.   |
//|                                                                    |
//| نسخه‌ی ۳ (ClaudeCode_FixList_DayBias_v3، ۱۲ اوت ۲۰۲۶) — سه اصلاح:    |
//|  ۱) پنجره‌ی ارزیابیِ NY Edge (نه LP) عریض‌تر شد: از پایانِ سشنِ NY      |
//|     مرجع تا انتهایِ پنجره‌ی روزِ D — نسخه‌ی ۲ آن را از بسته‌شدنِ باکسِ   |
//|     توکیو شروع می‌کرد که بیش‌ازحد دیر بود (NY_AtVote هرگز Break/Sweep |
//|     نمی‌شد، ۸۳٪ Silent). NY_AtVote حالا عکسِ فوریِ لحظه‌ی بسته‌شدنِ     |
//|     باکسِ توکیو در وسطِ همین پنجره‌ی عریض‌تر است.                      |
//|  ۲) رفتارِ «بدون شکستِ LP -> Red» صراحتاً مستند شد (DetectionLayer).  |
//|  ۳) کالیبراسیونِ آفستِ سرور به TimeTradeServer() تغییر کرد            |
//|     (RM_SessionTime.mqh) + دو ستونِ تشخیصیِ BoxStart_Server/          |
//|     BoxEnd_Server در انتهای CSV، برایِ راستی‌آزماییِ مستقیمِ کاربر.     |
//|                                                                    |
//| نسخه‌ی ۴ (ClaudeCode_FixList_DayBias_v4، ۱۲ اوت ۲۰۲۶) — تعریفِ باکس:  |
//|  باکسِ SOB دوسر بسته است: کندلی که open آن == BoxEnd هم عضوِ باکس     |
//|  است (توکیوِ پیش‌فرض = ۱۳ کندل، نه ۱۲) — طبقِ ریشه‌یابیِ رفتارِ SOB      |
//|  زنده. BoxLayer.mqh یک پارامترِ inclusiveEnd گرفته (اینجا true برایِ  |
//|  توکیو/لندن/NY-باکس/سشنِ NY مرجع). پیامدِ لازم: باکس ۵ دقیقه دیرتر    |
//|  واقعاً بسته می‌شود، پس مرزِ «اولین کندلِ بعد از باکس» (LP) و «لحظه‌ی   |
//|  رأی» (NY_AtVote) هر دو به BoxEnd+۵دقیقه منتقل شدند. ماشین‌وضعیتِ     |
//|  LP/NY Edge و فرمولِ DayColor دست‌نخورده‌اند. BoxStart_Server/         |
//|  BoxEnd_Server همچنان همان لنگرهای نامی (۲۰:۰۰/۲۱:۰۰ NY) را گزارش    |
//|  می‌کنند.                                                            |
//|                                                                    |
//| نسخه‌ی ۵ (ClaudeCode_Spec_DayBias_v5_TokyoBracket، ۱۲ اوت ۲۰۲۶) —     |
//|  ۱۱ ستونِ صرفاً-مشاهده‌ای برایِ بک‌تستِ استراتژیِ Tokyo Bracket، بعد از  |
//|  BoxStart_Server/BoxEnd_Server. هیچ ستون/منطقِ موجودی تغییر نکرد -    |
//|  DetectionLayer.mqh's LP_ComputeBracketMetrics دوباره روی همان       |
//|  dayRates اسکن می‌کند و leg۱/leg۲ را با همان LP_CheckLeg بازتولید     |
//|  می‌کند. نکته‌ی مهم برایِ کاربر: ستونِ RetestWithinTokyo با تعریفِ فعلیِ|
//|  «پایانِ سشنِ توکیو» (=BoxEnd نامی/۲۱:۰۰ NY) ساختاراً همیشه ۰ می‌شود -  |
//|  چون تشخیصِ LP از BoxEnd+۵دقیقه شروع می‌شود و retest حتماً بعد از یک   |
//|  کندلِ دیگر است، پس زمانش همیشه > ۲۱:۰۰ خواهد بود. تا روشن‌شدنِ منظورِ  |
//|  دقیقِ «سشنِ توکیو» (باکسِ ۱ساعته یا یک سشنِ عریض‌ترِ آسیایی)، همین      |
//|  تعریفِ نامی استفاده شده - به کاربر گزارش شد.                         |
//|                                                                    |
//| نسخه‌ی ۵.۱ (ClaudeCode_FixList_DayBias_v5_1، ۱۲ اوت ۲۰۲۶):            |
//|  بندِ ۱: یک Assert فیل‌شده دیگر کلِ اجرا را متوقف نمی‌کند: آن روز رد     |
//|  می‌شود (بدونِ ردیفِ CSV؛ لاگِ کاملِ تاریخ+مقادیر همچنان در Journal چاپ  |
//|  می‌شود)، حلقه تا آخرِ تاریخچه ادامه می‌یابد، و در خلاصه‌ی پایانی لیستِ   |
//|  تاریخ‌هایِ رد‌شده چاپ می‌شود.                                          |
//|  بندِ ۲: RetestWithinTokyo حالا با پایانِ *سشنِ کاملِ* توکیو (۰۵:۰۰ NY،  |
//|  طبقِ تأییدِ کاربر - نه باکسِ SOB یک‌ساعته) مقایسه می‌شود؛ ورودیِ جدیدِ    |
//|  InpTokyoSessionEndH/M اضافه شد.                                    |
//|  ریشه‌یابیِ Assertِ فیل‌شده در ۲۰۲۶-۰۴-۲۴ (لیبلِ Sweep_Sell): کندلِ      |
//|  شکست خودش هم‌زمان لبه‌ی مقابل را هم لمس کرده (کندلِ بسیار پرنوسانِ روزِ |
//|  بعدِ باکسِ ۵۹.۱۶$) - leg۱ (که از خودِ کندلِ شکست شروع می‌شود) این را     |
//|  سوییپ حساب می‌کند، اما حلقه‌ی عمقِ DetectionLayer.mqh از کندلِ *بعدی*   |
//|  شروع می‌شود (طبقِ تعریفِ صریحِ سند) و آن کندل را هرگز نمی‌دید -          |
//|  MaxDepthIntoBox_Before1R_Pct صفر می‌ماند درحالی‌که RawSweepOccurred=1  |
//|  بود. فیکس: عمقِ خودِ کندلِ سوییپ/۱R اگر هم‌زمان با کندلِ شکست باشد،      |
//|  مستقیماً از OHLCش لحاظ می‌شود (LP_ComputeBracketMetrics). آستانه‌ی      |
//|  Assertِ Sweep_* هم از >۱۰۰٪ دقیق به >=۱۰۰٪ (با تلورانسِ ۰.۰۰۱، مثلِ    |
//|  Assertِ F4) تغییر کرد - لمسِ دقیقاً روی لبه (بدونِ آورشوت) هم طبقِ      |
//|  تعریفِ مکانیکیِ Sweep («حتی شدو») یک سوییپِ معتبر است.                  |
//|                                                                    |
//| نسخه‌ی ۶ (ClaudeCode_Spec_DayBias_v6_ReEntry، ۱۲ اوت ۲۰۲۶) —          |
//|  ۱۰ ستونِ صرفاً-مشاهده‌ایِ دیگر در انتهایِ CSV، برایِ ایده‌ی «بازیافت»      |
//|  (re-entry لیمیت رویِ لبه بعد از خروجِ نصف در ۱R) + داده‌های عمومیِ     |
//|  مسیرِ روز (لمسِ ۱.۵R/۲R/۳R، پول‌بک بعد از ۲R، R پایانِ روز). هیچ        |
//|  ستون/منطقِ موجودی تغییر نکرد. همه بر مبنایِ جهتِ *تأییدشده*             |
//|  (LP_Label != NoDirection) - برایِ روزهایِ Sweep_* یعنی جهتِ دوم و       |
//|  لبه‌ی مقابل (دقیقاً همان edge/dir که R_Day خودش استفاده می‌کند)، پس     |
//|  DetectionLayer.mqh's LP_ComputeReEntryMetrics از anchor متفاوتی      |
//|  (flipTime برایِ Sweep_*، firstTime در غیرِ این‌صورت) اسکن را شروع       |
//|  می‌کند - نه دوباره از leg۱ مثلِ v5's LP_ComputeBracketMetrics.         |
//|                                                                    |
//| نسخه‌ی ۶.۱ (ClaudeCode_Spec_DayBias_v6_1، ۱۲ اوت ۲۰۲۶) — دو ستونِ      |
//|  تکمیلیِ ترتیبِ رویدادها: PostTouch_Cross50_Time/Cross75_Time، زمانِ    |
//|  اولین عبورِ عمق از ۵۰٪/۷۵٪ ارتفاعِ باکس *بعد از* لمسِ بازیافتی          |
//|  (ستونِ PostR1_EdgeTouch_Time)؛ فقط برایِ روزهایی پر که آن لمس رخ داده. |
//|  همان حلقه‌ی محاسبه‌ی PostTouch_MaxDepthPct (v6) این دو را هم همزمان    |
//|  ثبت می‌کند - بدونِ اسکنِ اضافه.                                       |
//+------------------------------------------------------------------+
#property copyright "RiskManager-EA"
#property script_show_inputs
#property strict

#include <DayBias_BoxLayer.mqh>
#include <DayBias_DetectionLayer.mqh>
#include <DayBias_CsvWriter.mqh>

input string InpSymbol     = "XAUUSD";                    // نماد (خالی = نمادِ چارتِ جاری)
input string InpOutputFile = "DayBias_History_XAUUSD.csv"; // در MQL5/Files/

input int InpTokyoStartH  = 20, InpTokyoStartM = 0,  InpTokyoEndH = 21, InpTokyoEndM = 0;  // باکسِ توکیو (LP)
// v5.1 (بندِ ۲): پایانِ سشنِ *کاملِ* توکیو (نه باکسِ SOB یک‌ساعته) — طبقِ تأییدِ کاربر، ۰۵:۰۰ به وقتِ
// نیویورک (صبحِ روزِ D). فقط برایِ ستونِ RetestWithinTokyo استفاده می‌شود؛ روی باکس/LP/رنگِ روز اثر ندارد.
input int InpTokyoSessionEndH = 5, InpTokyoSessionEndM = 0;  // پایانِ سشنِ کاملِ توکیو (برایِ RetestWithinTokyo)
input int InpLondonStartH = 3,  InpLondonStartM = 0,  InpLondonEndH = 4,  InpLondonEndM = 0;  // باکسِ لندن (فقط لاگِ خام)
input int InpNYBoxStartH  = 8,  InpNYBoxStartM = 30, InpNYBoxEndH = 9,  InpNYBoxEndM = 30; // باکسِ NY روزِ جاری (فقط لاگِ خام)
input int InpNYPrevStartH = 9,  InpNYPrevStartM = 0,  InpNYPrevEndH = 18, InpNYPrevEndM = 0; // سشنِ کاملِ NY روزِ معاملاتیِ قبل (NY Edge)

// F2: حداکثر تعداد روزِ عقب‌گردِ تقویمی برای پیدا کردنِ آخرین روزِ معاملاتیِ دارایِ سشنِ NY
// (آخرِ هفته = ۲ روز؛ بافرِ اضافه برایِ تعطیلاتِ رسمیِ متوالی).
#define NY_PREV_MAX_LOOKBACK 6

int g_digits;

//------------------------------------------------------------------
bool EnsureHistoryLoaded(string symbol)
{
   MqlRates rates[];
   for(int attempt = 0; attempt < 50; attempt++)
   {
      int copied = CopyRates(symbol, PERIOD_M5, 0, 10, rates);
      if(copied > 0) return(true);
      Sleep(200);
   }
   return(false);
}

//------------------------------------------------------------------
// F2: آخرین روزِ معاملاتیِ قبل از D که سشنِ NY دارد را پیدا می‌کند (روزهای بدونِ کندل -
// آخرِ هفته/تعطیلی - را skip می‌کند، خودِ D را skip نمی‌کند).
//------------------------------------------------------------------
bool FindPrevTradingDayNYSession(string symbol, int daysAgo, SSessionRange &outRange)
{
   for(int back = 1; back <= NY_PREV_MAX_LOOKBACK; back++)
   {
      if(BL_ComputeSessionRange(symbol, daysAgo + back, InpNYPrevStartH, InpNYPrevStartM,
                                 InpNYPrevEndH, InpNYPrevEndM, true, outRange))
         return(true);
   }
   return(false);
}

//------------------------------------------------------------------
// یک روزِ معاملاتی (F1: لنگر = باکسِ توکیوِ شبِ قبل) را کامل پردازش می‌کند و در صورتِ موفقیت
// یک ردیفِ CSV می‌نویسد. false = روز skip شد (بدونِ پوشش تاریخی/بدونِ کندلِ کافی/هنوز کامل نشده).
//------------------------------------------------------------------
bool ProcessOneDay(int handle, string symbol, int daysAgo, int &green, int &yellow, int &red, int &assertFailures,
                   int &v5BreakDays, int &v5ConfirmedDays, int &v5RetestBefore1RCount, double &v5SumMaxDepthConfirmed,
                   int &v5RawSweepCount, int &v5Trade2StopHitCount, string &failedDates,
                   int &v6PostR1TouchCount, double &v6SumPostTouchMaxR, int &v6Reached2RBeforeCount,
                   int &v61Cross50Count, int &v61Cross75Count, string &v61SampleRows, int &v61SampleCount)
{
   SSessionRange tokyoLP, london, nyBox, nyPrev;

   // F1: باکسِ LP برای روزِ D = باکسِ توکیوِ شبِ منتهی به D (روزِ تقویمیِ D-1، یعنی daysAgo+1).
   // v4: inclusiveEnd=true (باکسِ دوسر بسته - کندلِ open==BoxEnd هم عضوِ باکس است).
   if(!BL_ComputeSessionRange(symbol, daysAgo + 1, InpTokyoStartH, InpTokyoStartM, InpTokyoEndH, InpTokyoEndM, true, tokyoLP))
      return(false);

   // v4: بسته‌شدنِ واقعیِ باکس؛ چون کندلِ open==tokyoLP.end حالا عضوِ باکس است، آن کندل در
   // tokyoLP.end + ۵دقیقه بسته می‌شود. مرزِ LP و لحظه‌ی رأیِ NY باید همین لحظه را مبنا بگیرند.
   datetime tokyoCloseInstant = tokyoLP.end + PeriodSeconds(PERIOD_M5);

   // مرزِ پایانِ پنجره = شروعِ باکسِ توکیوِ روزِ بعد (شبِ خودِ D، یعنی همان daysAgo قدیمی).
   // این فقط یک محاسبه‌ی ساعتی است (بدونِ نیاز به کندلِ واقعی آنجا) — طبقِ F1 دقیقاً بندِ پنجره را
   // بدونِ وابستگی به این‌که آن باکس خودش کندل دارد یا نه (مثلاً عصرِ جمعه) تعیین می‌کند.
   datetime windowEnd, windowEndBoxCloseUnused;
   ST_ComputeSessionByDaysAgo(daysAgo, InpTokyoStartH, InpTokyoStartM, InpTokyoEndH, InpTokyoEndM,
                               windowEnd, windowEndBoxCloseUnused);
   if(!ST_IsClosedServerTime(windowEnd))
      return(false); // روزِ معاملاتی هنوز کامل نشده (جاری/آینده)

   // F2: مرجعِ NY Edge = آخرین روزِ معاملاتیِ قبل از D (نه لزوماً روزِ تقویمیِ قبل).
   if(!FindPrevTradingDayNYSession(symbol, daysAgo, nyPrev))
      return(false);

   // لندن/باکسِ NY روزِ جاری اختیاری‌اند: فقط ستون‌های خامِ CSV را پر می‌کنند، skip کلِ روز را باعث نمی‌شوند.
   // این‌ها متعلق به روزِ تقویمیِ D خودش‌اند (که در داخلِ پنجره‌ی ارزیابیِ D قرار می‌گیرند).
   BL_ComputeSessionRange(symbol, daysAgo, InpLondonStartH, InpLondonStartM, InpLondonEndH, InpLondonEndM, true, london);
   BL_ComputeSessionRange(symbol, daysAgo, InpNYBoxStartH, InpNYBoxStartM, InpNYBoxEndH, InpNYBoxEndM, true, nyBox);

   // نسخه‌ی ۳ (بندِ ۱): پنجره‌ی NY Edge از پایانِ سشنِ NY مرجع شروع می‌شود - عریض‌تر از پنجره‌ی
   // LP (که همچنان از بسته‌شدنِ باکسِ توکیو شروع می‌شود، دست‌نخورده). یک آرایه‌ی عریض می‌گیریم و
   // زیرآرایه‌ی LP را از داخلش برش می‌زنیم تا دو بار CopyRates روی بازه‌ی هم‌پوشان نزنیم.
   // v4: چون nyPrev هم دوسر بسته است، سشنِ مرجع واقعاً در nyPrev.end+۵دقیقه تمام می‌شود.
   datetime nyWindowStart = nyPrev.end + PeriodSeconds(PERIOD_M5);

   MqlRates wideRates[];
   int wideN = CopyRates(symbol, PERIOD_M5, nyWindowStart, windowEnd - 1, wideRates);
   if(wideN <= 0) return(false);
   if(wideRates[0].time > wideRates[wideN - 1].time) ArrayReverse(wideRates); // اطمینان از ترتیبِ صعودیِ زمان

   // زیرآرایه‌ی LP: از اولین کندلی که زمانش >= بسته‌شدنِ واقعیِ باکسِ توکیو است (v4: tokyoCloseInstant،
   // نه tokyoLP.end - وگرنه کندلِ خودِ باکس اشتباهاً «بعد از باکس» حساب می‌شد).
   int lpStartIdx = 0;
   while(lpStartIdx < wideN && wideRates[lpStartIdx].time < tokyoCloseInstant) lpStartIdx++;
   int lpCount = wideN - lpStartIdx;
   if(lpCount <= 0) return(false); // بینِ بسته‌شدنِ باکس و انتهایِ پنجره هیچ کندلی نبود

   MqlRates dayRates[];
   ArrayResize(dayRates, lpCount);
   for(int i = 0; i < lpCount; i++) dayRates[i] = wideRates[lpStartIdx + i];

   double dayHigh = dayRates[0].high, dayLow = dayRates[0].low;
   datetime dayHighTime = dayRates[0].time, dayLowTime = dayRates[0].time;
   for(int i = 1; i < lpCount; i++)
   {
      if(dayRates[i].high > dayHigh) { dayHigh = dayRates[i].high; dayHighTime = dayRates[i].time; }
      if(dayRates[i].low  < dayLow)  { dayLow  = dayRates[i].low;  dayLowTime  = dayRates[i].time; }
   }

   SSessionRange fullDay;
   BL_ResetRange(fullDay);
   fullDay.valid = true;
   fullDay.start = tokyoCloseInstant; fullDay.end = windowEnd;
   fullDay.open  = dayRates[0].open; fullDay.close = dayRates[lpCount - 1].close;
   fullDay.high  = dayHigh; fullDay.low = dayLow;
   fullDay.highTime = dayHighTime; fullDay.lowTime = dayLowTime;
   fullDay.barCount = lpCount;

   // --- LP: از اولین کندلِ بعد از بسته‌شدنِ باکسِ توکیو تا پایانِ پنجره (دست‌نخورده از نسخه‌ی ۲) ---
   SLPResult lp;
   LP_Detect(dayRates, lpCount, tokyoLP.high, tokyoLP.low, lp);

   // --- NY Edge: پنجره‌ی عریض (از پایانِ سشنِ NY مرجع)، رأی = لحظه‌ی بسته‌شدنِ باکسِ توکیو ---
   SNYEdgeState nyAtVote, nyEndOfDay;
   NY_Track(wideRates, wideN, nyPrev.high, nyPrev.low, tokyoCloseInstant, nyAtVote, nyEndOfDay);

   // --- F4: Assert تعریفِ Break (باید همیشه ساختاراً برقرار باشد؛ نقض = باگ) ---
   double nyRange     = nyPrev.high - nyPrev.low;
   double atVotePct   = (nyRange > 0) ? (nyAtVote.penDepth   / nyRange * 100.0) : 0.0;
   double endOfDayPct = (nyRange > 0) ? (nyEndOfDay.penDepth / nyRange * 100.0) : 0.0;
   string nyAtVoteLabel   = NY_StatusLabel(nyAtVote);
   string nyEndOfDayLabel = NY_StatusLabel(nyEndOfDay);

   bool assertOk = DL_AssertBreakPenetration(nyAtVoteLabel, atVotePct) &&
                   DL_AssertBreakPenetration(nyEndOfDayLabel, endOfDayPct) &&
                   DL_AssertBreakTimeInWindow(nyAtVote.breakTime, nyWindowStart, windowEnd) &&
                   DL_AssertBreakTimeInWindow(nyEndOfDay.breakTime, nyWindowStart, windowEnd);

   if(!assertOk)
   {
      int y2, m2, d2;
      ST_GetNYCalendarDate(daysAgo, y2, m2, d2);
      PrintFormat("DayBias ASSERT FAILED: Date=%04d-%02d-%02d AtVote=%s(%.2f%%,BreakTime=%s) EndOfDay=%s(%.2f%%,BreakTime=%s) Window=[%s,%s) — احتمالِ باگ در DetectionLayer.",
                  y2, m2, d2, nyAtVoteLabel, atVotePct, CSV_TimeSec(nyAtVote.breakTime),
                  nyEndOfDayLabel, endOfDayPct, CSV_TimeSec(nyEndOfDay.breakTime),
                  CSV_TimeSec(nyWindowStart), CSV_TimeSec(windowEnd));
      assertFailures++;
      failedDates += (StringLen(failedDates) > 0 ? "," : "") + StringFormat("%04d-%02d-%02d", y2, m2, d2);
      return(false);
   }

   // --- رنگِ روز ---
   string dayColor = DL_ComputeDayColor(lp, nyAtVote);
   if(dayColor == "Green") green++; else if(dayColor == "Yellow") yellow++; else red++;

   // --- R_Day ---
   double boxSize = tokyoLP.high - tokyoLP.low;
   double rVal = 0;
   string rDayStr = "";
   if(lp.finalDir != 0 && boxSize > 0)
   {
      double edge = (lp.finalDir > 0) ? tokyoLP.high : tokyoLP.low;
      rVal = (lp.finalDir > 0) ? (dayHigh - edge) / boxSize : (edge - dayLow) / boxSize;
      if(rVal < 0) rVal = 0;
      rDayStr = CSV_Num(rVal, 3);
   }

   // --- نسخه‌ی ۵: ستون‌های Tokyo Bracket ---
   // v5.1 (بندِ ۲، حل‌شده): «پایانِ سشنِ توکیو» برایِ RetestWithinTokyo دیگر باکسِ SOB یک‌ساعته
   // (tokyoLP.end = ۲۱:۰۰ NY) نیست - طبقِ تأییدِ کاربر، سشنِ کاملِ توکیو تا ۰۵:۰۰ به وقتِ نیویورکِ
   // صبحِ روزِ D ادامه دارد. با مرزِ قدیم این ستون ساختاراً همیشه ۰ بود (retest حتماً بعد از
   // BoxEnd+۵دقیقه است)؛ با مرزِ جدید معنادار می‌شود.
   datetime tokyoSessionStartUnused, tokyoSessionEnd;
   ST_ComputeSessionByDaysAgo(daysAgo + 1, InpTokyoStartH, InpTokyoStartM, InpTokyoSessionEndH, InpTokyoSessionEndM,
                               tokyoSessionStartUnused, tokyoSessionEnd);

   SBracketMetrics bm;
   LP_ComputeBracketMetrics(dayRates, lpCount, tokyoLP.high, tokyoLP.low, lp, tokyoSessionEnd, bm);

   string brReason;
   if(!BR_AssertConsistency(lp, bm, rVal, brReason))
   {
      int y3, m3, d3;
      ST_GetNYCalendarDate(daysAgo, y3, m3, d3);
      PrintFormat("DayBias ASSERT FAILED (v5 Tokyo Bracket): Date=%04d-%02d-%02d Label=%s Reason=%s",
                  y3, m3, d3, lp.label, brReason);
      assertFailures++;
      failedDates += (StringLen(failedDates) > 0 ? "," : "") + StringFormat("%04d-%02d-%02d", y3, m3, d3);
      return(false);
   }

   if(bm.hasData)
   {
      v5BreakDays++;
      if(lp.label != "NoDirection") v5ConfirmedDays++;
      if(bm.retestBefore1R) v5RetestBefore1RCount++;
      if(lp.label != "NoDirection") v5SumMaxDepthConfirmed += bm.maxDepthPct;
      if(bm.rawSweepOccurred)
      {
         v5RawSweepCount++;
         if(bm.trade2StopHit) v5Trade2StopHitCount++;
      }
   }

   // --- نسخه‌ی ۶: ستون‌های بازیافت + مسیرِ عمومیِ روز ---
   SReEntryMetrics re;
   LP_ComputeReEntryMetrics(dayRates, lpCount, tokyoLP.high, tokyoLP.low, lp, dayHighTime, dayLowTime,
                             fullDay.close, re);

   string reReason;
   if(!RE_AssertConsistency(lp, re, rVal, reReason))
   {
      int y4, m4, d4;
      ST_GetNYCalendarDate(daysAgo, y4, m4, d4);
      PrintFormat("DayBias ASSERT FAILED (v6 Re-Entry): Date=%04d-%02d-%02d Label=%s Reason=%s",
                  y4, m4, d4, lp.label, reReason);
      assertFailures++;
      failedDates += (StringLen(failedDates) > 0 ? "," : "") + StringFormat("%04d-%02d-%02d", y4, m4, d4);
      return(false);
   }

   if(re.hasData && re.postR1TouchTime != 0)
   {
      v6PostR1TouchCount++;
      v6SumPostTouchMaxR += re.postTouchMaxR;
      if(re.postTouchReached2RBefore) v6Reached2RBeforeCount++;

      if(re.postTouchCross50Time != 0) v61Cross50Count++;
      if(re.postTouchCross75Time != 0) v61Cross75Count++;

      // v6.1، تستِ پذیرشِ ۳: چند نمونه ردیفِ دارایِ هر دو زمان برایِ مرورِ انسانی.
      if(re.postTouchCross50Time != 0 && re.postTouchCross75Time != 0 && v61SampleCount < 5)
      {
         int ys, ms, ds;
         ST_GetNYCalendarDate(daysAgo, ys, ms, ds);
         v61SampleRows += StringFormat("%04d-%02d-%02d(Cross50=%s,Cross75=%s) ", ys, ms, ds,
                                        CSV_Time(re.postTouchCross50Time), CSV_Time(re.postTouchCross75Time));
         v61SampleCount++;
      }
   }

   int y, m, d;
   ST_GetNYCalendarDate(daysAgo, y, m, d);

   string row =
      StringFormat("%04d-%02d-%02d", y, m, d) + "," +
      CSV_Num(tokyoLP.high, g_digits) + "," + CSV_Num(tokyoLP.low, g_digits) + "," + CSV_Num(boxSize, g_digits) + "," +
      CSV_Dir(lp.firstDir) + "," + CSV_Time(lp.firstTime) + "," +
      (lp.hasBreak ? CSV_Num(lp.firstBodyRatio, 3) : "") + "," +
      (lp.hasBreak ? CSV_Bool(lp.reached1R) : "") + "," +
      lp.label + "," + CSV_Time(lp.flipTime) + "," + CSV_Time(lp.oneRTime) + "," +
      CSV_Num(nyPrev.high, g_digits) + "," + CSV_Num(nyPrev.low, g_digits) + "," + CSV_Num(nyRange, g_digits) + "," +
      nyAtVoteLabel + "," + CSV_Num(nyAtVote.penDepth, g_digits) + "," + CSV_Num(atVotePct, 2) + "," +
      nyEndOfDayLabel + "," + CSV_Time(nyEndOfDay.breakTime) + "," +
      dayColor + "," + rDayStr + "," +
      CSV_Range4(tokyoLP, g_digits) + "," + CSV_Range4(london, g_digits) + "," +
      CSV_Range4(nyBox, g_digits) + "," + CSV_Range4(fullDay, g_digits) + "," +
      CSV_Time(dayHighTime) + "," + CSV_Time(dayLowTime) + "," +
      CSV_TimeSec(tokyoLP.start) + "," + CSV_TimeSec(tokyoLP.end) + "," +
      (bm.hasData ? CSV_Num(bm.breakCloseOvershoot, g_digits) : "") + "," +
      (bm.hasData ? CSV_Time(bm.retestTime) : "") + "," +
      (bm.hasData ? CSV_Bool(bm.retestBefore1R) : "") + "," +
      (bm.hasData ? CSV_Bool(bm.retestWithinTokyo) : "") + "," +
      (bm.hasData ? CSV_Num(bm.maxDepthPct, 2) : "") + "," +
      (bm.hasData ? CSV_Bool(bm.rawSweepOccurred) : "") + "," +
      ((bm.hasData && bm.rawSweepOccurred) ? CSV_Num(bm.trade2MaxR, 3) : "") + "," +
      ((bm.hasData && bm.rawSweepOccurred) ? CSV_Bool(bm.trade2StopHit) : "") + "," +
      (bm.hasData ? CSV_Time(bm.reach1RTime) : "") + "," +
      (bm.hasData ? CSV_Time(bm.maxDepthTime) : "") + "," +
      (bm.hasData ? CSV_Time(bm.depth50Time) : "") + "," +
      ((re.hasData && re.postR1TouchTime != 0) ? CSV_Time(re.postR1TouchTime) : "") + "," +
      ((re.hasData && re.postR1TouchTime != 0) ? CSV_Num(re.postTouchMaxR, 3) : "") + "," +
      ((re.hasData && re.postR1TouchTime != 0) ? CSV_Num(re.postTouchMaxDepthPct, 2) : "") + "," +
      ((re.hasData && re.postR1TouchTime != 0) ? CSV_Bool(re.postTouchReached2RBefore) : "") + "," +
      (re.hasData ? CSV_Time(re.firstTouch1_5RTime) : "") + "," +
      (re.hasData ? CSV_Time(re.firstTouch2RTime) : "") + "," +
      (re.hasData ? CSV_Time(re.firstTouch3RTime) : "") + "," +
      ((re.hasData && re.firstTouch2RTime != 0) ? CSV_Num(re.pullbackAfter2RDepthPct, 2) : "") + "," +
      (re.hasData ? CSV_Num(re.eodR, 3) : "") + "," +
      (re.hasData ? CSV_Time(re.timeAtMaxR) : "") + "," +
      ((re.hasData && re.postR1TouchTime != 0) ? CSV_Time(re.postTouchCross50Time) : "") + "," +
      ((re.hasData && re.postR1TouchTime != 0) ? CSV_Time(re.postTouchCross75Time) : "");

   FileWriteString(handle, row + "\r\n");
   return(true);
}

//------------------------------------------------------------------
void OnStart()
{
   string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   g_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   if(!EnsureHistoryLoaded(symbol))
   {
      Print("DayBias: تاریخچه‌ی M5 برای ", symbol, " در دسترس نیست.");
      return;
   }

   // نسخه‌ی ۳ (بندِ ۳): آفستِ سرور استفاده‌شده (بعد از فیکسِ TimeTradeServer()) را چاپ کن تا
   // مستقیماً روی حسابِ واقعی قابلِ‌راستی‌آزمایی باشد.
   int offsetSec = ST_ServerOffsetSec();
   PrintFormat("DayBias: Server-UTC offset = %d sec (%.2f h) [via TimeTradeServer()-TimeGMT()]",
               offsetSec, offsetSec / 3600.0);

   int handle = FileOpen(InpOutputFile, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("DayBias: خطا در بازکردنِ فایلِ خروجی، کد: ", GetLastError());
      return;
   }
   FileWriteString(handle, CSV_HEADER + "\r\n");

   datetime firstDate = (datetime)SeriesInfoInteger(symbol, PERIOD_M5, SERIES_FIRSTDATE);
   int maxDaysAgo = (int)((TimeTradeServer() - firstDate) / 86400) + 3; // بافرِ کوچک، گاردِ پوشش خودش دقیق skip می‌کند
   if(maxDaysAgo < 1) maxDaysAgo = 1;

   int processed = 0, skipped = 0;
   int colorGreen = 0, colorYellow = 0, colorRed = 0;
   int assertFailures = 0;
   string failedDates = "";

   // نسخه‌ی ۵، تستِ پذیرشِ ۴: sanity توزیعی برایِ مرورِ انسانی قبل از تحویلِ CSV.
   int v5BreakDays = 0, v5ConfirmedDays = 0, v5RetestBefore1RCount = 0, v5RawSweepCount = 0, v5Trade2StopHitCount = 0;
   double v5SumMaxDepthConfirmed = 0;

   // نسخه‌ی ۶، تستِ پذیرشِ ۳: sanity - v5ConfirmedDays همان مخرجِ «روزهایِ تأییدشده» است (re.hasData
   // دقیقاً معادلِ bm.hasData && lp.label!=NoDirection است).
   int v6PostR1TouchCount = 0, v6Reached2RBeforeCount = 0;
   double v6SumPostTouchMaxR = 0;

   // نسخه‌ی ۶.۱، تستِ پذیرشِ ۳: تعدادِ Cross50/Cross75 (مخرج = v6PostR1TouchCount) + چند نمونه ردیف.
   int v61Cross50Count = 0, v61Cross75Count = 0, v61SampleCount = 0;
   string v61SampleRows = "";

   // v5.1: یک Assert فیل‌شده دیگر کلِ اجرا را متوقف نمی‌کند — فقط همان روز رد می‌شود (لاگِ کامل
   // بالای این خلاصه چاپ شده) و حلقه تا آخرِ تاریخچه ادامه می‌یابد.
   for(int daysAgo = maxDaysAgo; daysAgo >= 1; daysAgo--)
   {
      if(ProcessOneDay(handle, symbol, daysAgo, colorGreen, colorYellow, colorRed, assertFailures,
                       v5BreakDays, v5ConfirmedDays, v5RetestBefore1RCount, v5SumMaxDepthConfirmed,
                       v5RawSweepCount, v5Trade2StopHitCount, failedDates,
                       v6PostR1TouchCount, v6SumPostTouchMaxR, v6Reached2RBeforeCount,
                       v61Cross50Count, v61Cross75Count, v61SampleRows, v61SampleCount))
         processed++;
      else
         skipped++;
   }

   FileClose(handle);

   Print("=== DayBias History Export Complete ===");
   Print("Symbol: ", symbol, "   Output: ", InpOutputFile);
   Print("Processed days: ", processed, "   Skipped days: ", skipped, "   Assert failures: ", assertFailures);
   if(assertFailures > 0)
      PrintFormat("%d روز با خطای Assert رد شدند (بدونِ ردیفِ CSV، جزئیات در لاگِ بالا): %s", assertFailures, failedDates);
   Print("DayColor distribution -> Green: ", colorGreen, "  Yellow: ", colorYellow, "  Red: ", colorRed);

   PrintFormat("=== Tokyo Bracket (v5) Sanity ===");
   PrintFormat("Days with a first break: %d (of which %d confirmed = not NoDirection)", v5BreakDays, v5ConfirmedDays);
   if(v5BreakDays > 0)
      PrintFormat("Retest-before-1R rate: %.1f%% (%d/%d)", 100.0 * v5RetestBefore1RCount / v5BreakDays, v5RetestBefore1RCount, v5BreakDays);
   if(v5ConfirmedDays > 0)
      PrintFormat("Avg MaxDepthIntoBox_Before1R_Pct on confirmed days: %.1f%%", v5SumMaxDepthConfirmed / v5ConfirmedDays);
   PrintFormat("Raw sweep occurred: %d days", v5RawSweepCount);
   if(v5RawSweepCount > 0)
      PrintFormat("Trade2_StopHit rate: %.1f%% (%d/%d)", 100.0 * v5Trade2StopHitCount / v5RawSweepCount, v5Trade2StopHitCount, v5RawSweepCount);

   PrintFormat("=== Re-Entry (v6) Sanity ===");
   if(v5ConfirmedDays > 0)
   {
      PrintFormat("PostR1_EdgeTouch rate on confirmed days: %.1f%% (%d/%d)",
                  100.0 * v6PostR1TouchCount / v5ConfirmedDays, v6PostR1TouchCount, v5ConfirmedDays);
      PrintFormat("Reached2R_Before rate (of PostR1 touches): %s",
                  v6PostR1TouchCount > 0 ? StringFormat("%.1f%% (%d/%d)", 100.0 * v6Reached2RBeforeCount / v6PostR1TouchCount, v6Reached2RBeforeCount, v6PostR1TouchCount) : "n/a");
   }
   if(v6PostR1TouchCount > 0)
      PrintFormat("Avg PostTouch_MaxR (on days that touched back): %.2fR", v6SumPostTouchMaxR / v6PostR1TouchCount);

   PrintFormat("=== Re-Entry Depth Sequencing (v6.1) Sanity ===");
   if(v6PostR1TouchCount > 0)
   {
      PrintFormat("Cross50 rate (of PostR1 touches): %.1f%% (%d/%d)",
                  100.0 * v61Cross50Count / v6PostR1TouchCount, v61Cross50Count, v6PostR1TouchCount);
      PrintFormat("Cross75 rate (of PostR1 touches): %.1f%% (%d/%d)",
                  100.0 * v61Cross75Count / v6PostR1TouchCount, v61Cross75Count, v6PostR1TouchCount);
   }
   if(v61SampleCount > 0)
      PrintFormat("Sample rows with both Cross50/Cross75: %s", v61SampleRows);
}
