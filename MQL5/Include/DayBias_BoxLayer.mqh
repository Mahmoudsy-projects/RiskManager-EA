//+------------------------------------------------------------------+
//|                                          DayBias_BoxLayer.mqh    |
//| لایه‌ی باکس Day Bias — محاسبه‌ی پنجره‌های سشن (توکیو/لندن/نیویورک/   |
//| روزِ کامل) دقیقاً با همان روشِ SOB: زمان‌بندی از RM_SessionTime.mqh  |
//| (تقویم نیویورک + DSTِ همان روز + آفستِ پایدارِ سرور)، سپس High/Low   |
//| از کندل‌های M5 داخلِ پنجره. فقط خواندن OHLC — بدونِ منطقِ شکستِ SOB    |
//| (آن ماژول نمایشی است و طبق دستور کار عمداً اینجا استفاده نمی‌شود).    |
//|                                                                    |
//| مستقل از DetectionLayer/CsvWriter تا در پروژه‌های دیگرِ MT5 هم        |
//| قابلِ استفاده باشد.                                                 |
//+------------------------------------------------------------------+
#ifndef DAYBIAS_BOXLAYER_MQH
#define DAYBIAS_BOXLAYER_MQH

#include "RM_SessionTime.mqh"

// یک پنجره‌ی سشن با OHLC آن روی M5.
struct SSessionRange
{
   bool     valid;
   datetime start;      // به وقتِ سرور، شاملِ خودش
   datetime end;         // لنگرِ پایانِ سشن به وقتِ سرور؛ شاملِ بودن/نبودنِ کندلِ open==end به inclusiveEnd بستگی دارد
   double   open;
   double   high;
   double   low;
   double   close;
   datetime highTime;
   datetime lowTime;
   int      barCount;
};

void BL_ResetRange(SSessionRange &r)
{
   r.valid = false;
   r.start = 0; r.end = 0;
   r.open = 0; r.high = 0; r.low = 0; r.close = 0;
   r.highTime = 0; r.lowTime = 0;
   r.barCount = 0;
}

// آیا شروعِ پنجره در محدوده‌ی تاریخچه‌ی M5 موجود پوشش داده می‌شود؟
// این همان «گارد پوشش تاریخچه»ی بندِ ۲ سندِ دستورکار است.
bool BL_HasHistoryCoverage(string symbol, datetime winStart)
{
   datetime firstDate = (datetime)SeriesInfoInteger(symbol, PERIOD_M5, SERIES_FIRSTDATE);
   if(firstDate == 0) return(false);
   return(winStart >= firstDate);
}

// محاسبه‌ی OHLC یک پنجره‌ی سشن از کندل‌های M5.
// inclusiveEnd=true → بازه‌ی دوسر بسته [start,end] (تعریفِ v4 برای باکس‌های SOB: کندلی که
//   open آن == end هم عضوِ باکس است — طبقِ ریشه‌یابیِ رفتارِ SOB زنده، تأییدشده با ۱۳ کندلِ
//   باکسِ توکیو). inclusiveEnd=false → بازه‌ی نیم‌بازِ [start,end) — برایِ پنجره‌هایی که end
//   لنگرِ سشنِ *بعدی* است، نه خودِ باکس (این پروژه دیگر از این حالت استفاده نمی‌کند چون
//   FullDay دیگر با BL_ComputeSessionRange ساخته نمی‌شود؛ برایِ استفاده‌ی عمومی نگه داشته شده).
// outRange.start/end همیشه همان لنگرهای محاسبه‌شده‌ی سشن‌اند؛ inclusiveEnd فقط تعیین می‌کند
// کدام کندل‌ها در High/Low/Open/Close شرکت کنند، نه این‌که چه چیزی گزارش شود.
// false برمی‌گرداند اگر: پوشش تاریخی نباشد، پنجره هنوز کامل نشده باشد (روزِ جاری)،
// یا هیچ کندلی در بازه نباشد (تعطیلی/شنبه).
bool BL_ComputeSessionRange(string symbol, int daysAgo,
                             int nyStartH, int nyStartM, int nyEndH, int nyEndM,
                             bool inclusiveEnd,
                             SSessionRange &outRange)
{
   BL_ResetRange(outRange);

   datetime start, end;
   ST_ComputeSessionByDaysAgo(daysAgo, nyStartH, nyStartM, nyEndH, nyEndM, start, end);

   if(!BL_HasHistoryCoverage(symbol, start))
      return(false);

   // اگر کندلِ open==end هم عضوِ باکس است، آن کندل واقعاً در end+M5 بسته می‌شود؛ گاردِ
   // «روزِ جاریِ ناقص» باید همان لحظه را چک کند، نه end را.
   datetime lastCandleCloses = inclusiveEnd ? (end + PeriodSeconds(PERIOD_M5)) : end;
   if(!ST_IsClosedServerTime(lastCandleCloses))
      return(false);

   datetime copyEnd = inclusiveEnd ? end : (end - 1);
   MqlRates rates[];
   int copied = CopyRates(symbol, PERIOD_M5, start, copyEnd, rates);
   if(copied <= 0)
      return(false);

   // مستندات MQL5 بین نسخه‌ها/حالت‌های آرایه در جهتِ ترتیبِ زمانی متناقض بوده؛
   // به‌جای فرض کردن، صریحاً چک می‌کنیم.
   bool ascending = (copied == 1) || (rates[0].time <= rates[copied - 1].time);
   int firstIdx = ascending ? 0 : copied - 1;
   int lastIdx  = ascending ? copied - 1 : 0;

   outRange.start = start;
   outRange.end   = end;
   outRange.open  = rates[firstIdx].open;
   outRange.close = rates[lastIdx].close;
   outRange.high  = rates[0].high;
   outRange.low   = rates[0].low;
   outRange.highTime = rates[0].time;
   outRange.lowTime  = rates[0].time;
   for(int i = 1; i < copied; i++)
   {
      if(rates[i].high > outRange.high) { outRange.high = rates[i].high; outRange.highTime = rates[i].time; }
      if(rates[i].low  < outRange.low)  { outRange.low  = rates[i].low;  outRange.lowTime  = rates[i].time; }
   }
   outRange.barCount = copied;
   outRange.valid = true;
   return(true);
}

#endif // DAYBIAS_BOXLAYER_MQH
