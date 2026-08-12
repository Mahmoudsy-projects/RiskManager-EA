//+------------------------------------------------------------------+
//|                                       DayBias_DataScript.mq5     |
//| اسکریپتِ فقط-خواندنیِ استخراجِ تاریخچه‌ی Day Bias Scorecard (XAUUSD). |
//| هیچ اردر/مودیفای‌ای ارسال نمی‌شود؛ فقط CopyRates + نوشتنِ یک CSV.     |
//| طبقِ سندِ دستورکار: MQL5/Files/DayBias_History_XAUUSD.csv           |
//|                                                                    |
//| نسخه‌ی ۲ (ClaudeCode_Fixes_v2_DayBias، ۱۲ اوت ۲۰۲۶) — F1/F2:         |
//| لنگرِ روزِ معاملاتی اصلاح شد. باکسِ LP برایِ روزِ D دیگر باکسِ عصرِ      |
//| همان روز نیست؛ باکسِ عصرِ *شبِ منتهی به D* (روزِ تقویمیِ قبل) است، و     |
//| پنجره‌ی ارزیابی LP/NY از بسته‌شدنِ همان باکس تا شروعِ باکسِ روزِ بعد     |
//| است (نه نیمه‌شب تا نیمه‌شبِ تقویمی). این چیزی است که در نسخه‌ی ۱ باعثِ  |
//| حذفِ کاملِ جمعه‌ها می‌شد (باکسِ عصرِ جمعه بعد از بسته‌شدنِ بازارِ هفته    |
//| هیچ کندلی ندارد) و پنجره‌ی تشخیصِ LP را به فقط ۳ ساعتِ آخرِ روز         |
//| (۲۱:۰۰-۲۴:۰۰) محدود می‌کرد.                                          |
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
input int InpNYPrevStartH = 9,  InpNYPrevStartM = 0,  InpNYPrevEndH = 18, InpNYPrevEndM = 0; // سشنِ کاملِ NY روزِ معاملاتیِ قبل (NY Edge) — F2

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

   datetime windowStart = tokyoLP.end;

   // F2: مرجعِ NY Edge = آخرین روزِ معاملاتیِ قبل از D (نه لزوماً روزِ تقویمیِ قبل).
   if(!FindPrevTradingDayNYSession(symbol, daysAgo, nyPrev))
      return(false);

   // لندن/باکسِ NY روزِ جاری اختیاری‌اند: فقط ستون‌های خامِ CSV را پر می‌کنند، skip کلِ روز را باعث نمی‌شوند.
   // این‌ها متعلق به روزِ تقویمیِ D خودش‌اند (که در داخلِ پنجره‌ی ارزیابیِ D قرار می‌گیرند).
   BL_ComputeSessionRange(symbol, daysAgo, InpLondonStartH, InpLondonStartM, InpLondonEndH, InpLondonEndM, london);
   BL_ComputeSessionRange(symbol, daysAgo, InpNYBoxStartH, InpNYBoxStartM, InpNYBoxEndH, InpNYBoxEndM, nyBox);

   MqlRates dayRates[];
   int n = CopyRates(symbol, PERIOD_M5, windowStart, windowEnd - 1, dayRates);
   if(n <= 0) return(false);
   if(dayRates[0].time > dayRates[n - 1].time) ArrayReverse(dayRates); // اطمینان از ترتیبِ صعودیِ زمان

   double dayHigh = dayRates[0].high, dayLow = dayRates[0].low;
   datetime dayHighTime = dayRates[0].time, dayLowTime = dayRates[0].time;
   for(int i = 1; i < n; i++)
   {
      if(dayRates[i].high > dayHigh) { dayHigh = dayRates[i].high; dayHighTime = dayRates[i].time; }
      if(dayRates[i].low  < dayLow)  { dayLow  = dayRates[i].low;  dayLowTime  = dayRates[i].time; }
   }

   SSessionRange fullDay;
   BL_ResetRange(fullDay);
   fullDay.valid = true;
   fullDay.start = windowStart; fullDay.end = windowEnd;
   fullDay.open  = dayRates[0].open; fullDay.close = dayRates[n - 1].close;
   fullDay.high  = dayHigh; fullDay.low = dayLow;
   fullDay.highTime = dayHighTime; fullDay.lowTime = dayLowTime;
   fullDay.barCount = n;

   // --- LP: از اولین کندلِ پنجره (بلافاصله بعد از بسته‌شدنِ باکسِ توکیو) تا پایانِ پنجره ---
   SLPResult lp;
   LP_Detect(dayRates, n, tokyoLP.high, tokyoLP.low, lp);

   // --- NY Edge: کلِ پنجره، از لحظه‌ی بسته‌شدنِ باکسِ توکیو (F3: بدونِ نشتِ رویدادِ پیش از آن) ---
   SNYEdgeState nyAtVote, nyEndOfDay;
   NY_Track(dayRates, n, nyPrev.high, nyPrev.low, tokyoLP.close, nyAtVote, nyEndOfDay);

   // --- F4: Assert تعریفِ Break (باید همیشه ساختاراً برقرار باشد؛ نقض = باگ) ---
   double nyRange     = nyPrev.high - nyPrev.low;
   double atVotePct   = (nyRange > 0) ? (nyAtVote.penDepth   / nyRange * 100.0) : 0.0;
   double endOfDayPct = (nyRange > 0) ? (nyEndOfDay.penDepth / nyRange * 100.0) : 0.0;
   string nyAtVoteLabel   = NY_StatusLabel(nyAtVote);
   string nyEndOfDayLabel = NY_StatusLabel(nyEndOfDay);

   if(!DL_AssertBreakPenetration(nyAtVoteLabel, atVotePct) ||
      !DL_AssertBreakPenetration(nyEndOfDayLabel, endOfDayPct))
   {
      int y2, m2, d2;
      ST_GetNYCalendarDate(daysAgo, y2, m2, d2);
      PrintFormat("DayBias ASSERT FAILED (F4): Date=%04d-%02d-%02d AtVote=%s(%.2f%%) EndOfDay=%s(%.2f%%) — Break با نفوذِ کمتر از ۲۳٪، احتمالِ باگ در DetectionLayer.",
                  y2, m2, d2, nyAtVoteLabel, atVotePct, nyEndOfDayLabel, endOfDayPct);
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
      CSV_Time(dayHighTime) + "," + CSV_Time(dayLowTime);

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

   int handle = FileOpen(InpOutputFile, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("DayBias: خطا در بازکردنِ فایلِ خروجی، کد: ", GetLastError());
      return;
   }
   FileWriteString(handle, CSV_HEADER + "\r\n");

   datetime firstDate = (datetime)SeriesInfoInteger(symbol, PERIOD_M5, SERIES_FIRSTDATE);
   int maxDaysAgo = (int)((TimeCurrent() - firstDate) / 86400) + 3; // بافرِ کوچک، گاردِ پوشش خودش دقیق skip می‌کند
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
         Print("DayBias: متوقف شد چون تست Assert (F4) فیل کرد — خروجی تا این نقطه معتبر است اما ناقص. لاگِ بالا را برایِ جزئیاتِ روزِ خطادار ببین.");
         break;
      }
   }

   FileClose(handle);

   Print("=== DayBias History Export Complete ===");
   Print("Symbol: ", symbol, "   Output: ", InpOutputFile);
   Print("Processed days: ", processed, "   Skipped days: ", skipped, "   Assert failures: ", assertFailures);
   Print("DayColor distribution -> Green: ", colorGreen, "  Yellow: ", colorYellow, "  Red: ", colorRed);
}
