//+------------------------------------------------------------------+
//|                                       DayBias_DataScript.mq5     |
//| اسکریپتِ فقط-خواندنیِ استخراجِ تاریخچه‌ی Day Bias Scorecard (XAUUSD). |
//| هیچ اردر/مودیفای‌ای ارسال نمی‌شود؛ فقط CopyRates + نوشتنِ یک CSV.     |
//| طبقِ سندِ دستورکار: MQL5/Files/DayBias_History_XAUUSD.csv           |
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
input int InpNYPrevStartH = 9,  InpNYPrevStartM = 0,  InpNYPrevEndH = 18, InpNYPrevEndM = 0; // سشنِ کاملِ NY روزِ قبل (NY Edge)

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
// یک روزِ تقویمیِ نیویورک را کامل پردازش می‌کند و در صورتِ موفقیت یک ردیفِ CSV می‌نویسد.
// false = روز skip شد (بدونِ پوشش تاریخی/بدونِ کندلِ کافی).
//------------------------------------------------------------------
bool ProcessOneDay(int handle, string symbol, int daysAgo, int &green, int &yellow, int &red)
{
   SSessionRange fullDay, tokyo, london, nyBox, nyPrev;

   // روزِ کامل (نیمه‌شب تا نیمه‌شبِ نیویورک) — هم برای اکسترمم/زمانِ روز، هم چارچوبِ تشخیص.
   if(!BL_ComputeSessionRange(symbol, daysAgo, 0, 0, 0, 0, fullDay))
      return(false);

   // باکسِ LP الزامی است — طبقِ گاردِ پوشش تاریخچه، بدونِ آن کلِ روز skip می‌شود.
   if(!BL_ComputeSessionRange(symbol, daysAgo, InpTokyoStartH, InpTokyoStartM, InpTokyoEndH, InpTokyoEndM, tokyo))
      return(false);

   // بدونِ سشنِ NY روزِ قبل، NY Edge قابلِ محاسبه نیست — این هم الزامی است.
   if(!BL_ComputeSessionRange(symbol, daysAgo + 1, InpNYPrevStartH, InpNYPrevStartM, InpNYPrevEndH, InpNYPrevEndM, nyPrev))
      return(false);

   // لندن/باکسِ NY روزِ جاری اختیاری‌اند: فقط ستون‌های خامِ CSV را پر می‌کنند، skip کلِ روز را باعث نمی‌شوند.
   BL_ComputeSessionRange(symbol, daysAgo, InpLondonStartH, InpLondonStartM, InpLondonEndH, InpLondonEndM, london);
   BL_ComputeSessionRange(symbol, daysAgo, InpNYBoxStartH, InpNYBoxStartM, InpNYBoxEndH, InpNYBoxEndM, nyBox);

   MqlRates dayRates[];
   int n = CopyRates(symbol, PERIOD_M5, fullDay.start, fullDay.end - 1, dayRates);
   if(n <= 0) return(false);
   if(dayRates[0].time > dayRates[n - 1].time) ArrayReverse(dayRates); // اطمینان از ترتیبِ صعودیِ زمان

   double dayHigh = dayRates[0].high, dayLow = dayRates[0].low;
   datetime dayHighTime = dayRates[0].time, dayLowTime = dayRates[0].time;
   for(int i = 1; i < n; i++)
   {
      if(dayRates[i].high > dayHigh) { dayHigh = dayRates[i].high; dayHighTime = dayRates[i].time; }
      if(dayRates[i].low  < dayLow)  { dayLow  = dayRates[i].low;  dayLowTime  = dayRates[i].time; }
   }

   // --- LP: از اولین کندلِ بعد از بسته‌شدنِ باکسِ توکیو تا پایانِ روز ---
   int lpStartIdx = 0;
   while(lpStartIdx < n && dayRates[lpStartIdx].time < tokyo.end) lpStartIdx++;
   int lpCount = n - lpStartIdx;

   SLPResult lp;
   if(lpCount > 0)
   {
      MqlRates lpRates[];
      ArrayResize(lpRates, lpCount);
      for(int i = 0; i < lpCount; i++) lpRates[i] = dayRates[lpStartIdx + i];
      LP_Detect(lpRates, lpCount, tokyo.high, tokyo.low, lp);
   }
   else
   {
      lp.hasBreak = false; lp.firstDir = 0; lp.firstTime = 0; lp.firstBodyRatio = 0;
      lp.reached1R = false; lp.flipTime = 0; lp.label = "NoDirection"; lp.finalDir = 0;
   }

   // --- NY Edge: کلِ روز، از نیمه‌شبِ نیویورک ---
   SNYEdgeState nyAtVote, nyEndOfDay;
   NY_Track(dayRates, n, nyPrev.high, nyPrev.low, tokyo.end, nyAtVote, nyEndOfDay);

   // --- رنگِ روز ---
   string dayColor = DL_ComputeDayColor(lp, nyAtVote);
   if(dayColor == "Green") green++; else if(dayColor == "Yellow") yellow++; else red++;

   // --- R_Day ---
   double boxSize = tokyo.high - tokyo.low;
   string rDayStr = "";
   if(lp.finalDir != 0 && boxSize > 0)
   {
      double edge = (lp.finalDir > 0) ? tokyo.high : tokyo.low;
      double rVal = (lp.finalDir > 0) ? (dayHigh - edge) / boxSize : (edge - dayLow) / boxSize;
      if(rVal < 0) rVal = 0;
      rDayStr = CSV_Num(rVal, 3);
   }

   // --- عمقِ نفوذِ NY در لحظه‌ی رأی ---
   double penDepth = MathMax(nyAtVote.maxPenHigh, nyAtVote.maxPenLow);
   double nyRange  = nyPrev.high - nyPrev.low;
   double penPct   = (nyRange > 0) ? (penDepth / nyRange * 100.0) : 0.0;

   int y, m, d;
   ST_GetNYCalendarDate(daysAgo, y, m, d);

   string row =
      StringFormat("%04d-%02d-%02d", y, m, d) + "," +
      CSV_Num(tokyo.high, g_digits) + "," + CSV_Num(tokyo.low, g_digits) + "," + CSV_Num(boxSize, g_digits) + "," +
      CSV_Dir(lp.firstDir) + "," + CSV_Time(lp.firstTime) + "," +
      (lp.hasBreak ? CSV_Num(lp.firstBodyRatio, 3) : "") + "," +
      (lp.hasBreak ? CSV_Bool(lp.reached1R) : "") + "," +
      lp.label + "," + CSV_Time(lp.flipTime) + "," +
      CSV_Num(nyPrev.high, g_digits) + "," + CSV_Num(nyPrev.low, g_digits) + "," + CSV_Num(nyRange, g_digits) + "," +
      NY_StatusLabel(nyAtVote) + "," + CSV_Num(penDepth, g_digits) + "," + CSV_Num(penPct, 2) + "," +
      NY_StatusLabel(nyEndOfDay) + "," + CSV_Time(nyEndOfDay.breakTime) + "," +
      dayColor + "," + rDayStr + "," +
      CSV_Range4(tokyo, g_digits) + "," + CSV_Range4(london, g_digits) + "," +
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

   for(int daysAgo = maxDaysAgo; daysAgo >= 1; daysAgo--)
   {
      if(ProcessOneDay(handle, symbol, daysAgo, colorGreen, colorYellow, colorRed))
         processed++;
      else
         skipped++;
   }

   FileClose(handle);

   Print("=== DayBias History Export Complete ===");
   Print("Symbol: ", symbol, "   Output: ", InpOutputFile);
   Print("Processed days: ", processed, "   Skipped days: ", skipped);
   Print("DayColor distribution -> Green: ", colorGreen, "  Yellow: ", colorYellow, "  Red: ", colorRed);
}
