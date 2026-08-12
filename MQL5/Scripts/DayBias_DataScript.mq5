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
                                 InpNYPrevEndH, InpNYPrevEndM, outRange))
         return(true);
   }
   return(false);
}

//------------------------------------------------------------------
// یک روزِ معاملاتی (F1: لنگر = باکسِ توکیوِ شبِ قبل) را کامل پردازش می‌کند و در صورتِ موفقیت
// یک ردیفِ CSV می‌نویسد. false = روز skip شد (بدونِ پوشش تاریخی/بدونِ کندلِ کافی/هنوز کامل نشده).
//------------------------------------------------------------------
bool ProcessOneDay(int handle, string symbol, int daysAgo, int &green, int &yellow, int &red, int &assertFailures)
{
   SSessionRange tokyoLP, london, nyBox, nyPrev;

   // F1: باکسِ LP برای روزِ D = باکسِ توکیوِ شبِ منتهی به D (روزِ تقویمیِ D-1، یعنی daysAgo+1).
   if(!BL_ComputeSessionRange(symbol, daysAgo + 1, InpTokyoStartH, InpTokyoStartM, InpTokyoEndH, InpTokyoEndM, tokyoLP))
      return(false);

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
   BL_ComputeSessionRange(symbol, daysAgo, InpLondonStartH, InpLondonStartM, InpLondonEndH, InpLondonEndM, london);
   BL_ComputeSessionRange(symbol, daysAgo, InpNYBoxStartH, InpNYBoxStartM, InpNYBoxEndH, InpNYBoxEndM, nyBox);

   // نسخه‌ی ۳ (بندِ ۱): پنجره‌ی NY Edge از پایانِ سشنِ NY مرجع شروع می‌شود - عریض‌تر از پنجره‌ی
   // LP (که همچنان از بسته‌شدنِ باکسِ توکیو شروع می‌شود، دست‌نخورده). یک آرایه‌ی عریض می‌گیریم و
   // زیرآرایه‌ی LP را از داخلش برش می‌زنیم تا دو بار CopyRates روی بازه‌ی هم‌پوشان نزنیم.
   datetime nyWindowStart = nyPrev.end;

   MqlRates wideRates[];
   int wideN = CopyRates(symbol, PERIOD_M5, nyWindowStart, windowEnd - 1, wideRates);
   if(wideN <= 0) return(false);
   if(wideRates[0].time > wideRates[wideN - 1].time) ArrayReverse(wideRates); // اطمینان از ترتیبِ صعودیِ زمان

   // زیرآرایه‌ی LP: از اولین کندلی که زمانش >= بسته‌شدنِ باکسِ توکیو است.
   int lpStartIdx = 0;
   while(lpStartIdx < wideN && wideRates[lpStartIdx].time < tokyoLP.end) lpStartIdx++;
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
   fullDay.start = tokyoLP.end; fullDay.end = windowEnd;
   fullDay.open  = dayRates[0].open; fullDay.close = dayRates[lpCount - 1].close;
   fullDay.high  = dayHigh; fullDay.low = dayLow;
   fullDay.highTime = dayHighTime; fullDay.lowTime = dayLowTime;
   fullDay.barCount = lpCount;

   // --- LP: از اولین کندلِ بعد از بسته‌شدنِ باکسِ توکیو تا پایانِ پنجره (دست‌نخورده از نسخه‌ی ۲) ---
   SLPResult lp;
   LP_Detect(dayRates, lpCount, tokyoLP.high, tokyoLP.low, lp);

   // --- NY Edge: پنجره‌ی عریض (از پایانِ سشنِ NY مرجع)، رأی = لحظه‌ی بسته‌شدنِ باکسِ توکیو ---
   SNYEdgeState nyAtVote, nyEndOfDay;
   NY_Track(wideRates, wideN, nyPrev.high, nyPrev.low, tokyoLP.end, nyAtVote, nyEndOfDay);

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
      return(false);
   }

   // --- رنگِ روز ---
   string dayColor = DL_ComputeDayColor(lp, nyAtVote);
   if(dayColor == "Green") green++; else if(dayColor == "Yellow") yellow++; else red++;

   // --- R_Day ---
   double boxSize = tokyoLP.high - tokyoLP.low;
   string rDayStr = "";
   if(lp.finalDir != 0 && boxSize > 0)
   {
      double edge = (lp.finalDir > 0) ? tokyoLP.high : tokyoLP.low;
      double rVal = (lp.finalDir > 0) ? (dayHigh - edge) / boxSize : (edge - dayLow) / boxSize;
      if(rVal < 0) rVal = 0;
      rDayStr = CSV_Num(rVal, 3);
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
      CSV_TimeSec(tokyoLP.start) + "," + CSV_TimeSec(tokyoLP.end);

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

   for(int daysAgo = maxDaysAgo; daysAgo >= 1; daysAgo--)
   {
      if(ProcessOneDay(handle, symbol, daysAgo, colorGreen, colorYellow, colorRed, assertFailures))
         processed++;
      else
         skipped++;

      if(assertFailures > 0)
      {
         Print("DayBias: متوقف شد چون یک Assert فیل کرد — خروجی تا این نقطه معتبر است اما ناقص. لاگِ بالا را برایِ جزئیاتِ روزِ خطادار ببین.");
         break;
      }
   }

   FileClose(handle);

   Print("=== DayBias History Export Complete ===");
   Print("Symbol: ", symbol, "   Output: ", InpOutputFile);
   Print("Processed days: ", processed, "   Skipped days: ", skipped, "   Assert failures: ", assertFailures);
   Print("DayColor distribution -> Green: ", colorGreen, "  Yellow: ", colorYellow, "  Red: ", colorRed);
}
