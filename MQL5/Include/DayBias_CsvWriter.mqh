//+------------------------------------------------------------------+
//|                                        DayBias_CsvWriter.mqh     |
//| فرمتِ ستون‌ها و هدرِ CSV برای Day Bias Scorecard (بخش ۴ سندِ         |
//| دستورکار). عمداً بدونِ FILE_CSV/FileWrite ساخته شده تا اعشار همیشه   |
//| «.» بماند (FILE_CSV به لوکیلِ ترمینال وابسته است و در بعضی لوکیل‌ها   |
//| اعشار را «,» می‌کند که با جداکننده‌ی ستون تداخل پیدا می‌کند).          |
//+------------------------------------------------------------------+
#ifndef DAYBIAS_CSVWRITER_MQH
#define DAYBIAS_CSVWRITER_MQH

#include "DayBias_BoxLayer.mqh"

string CSV_Num(double v, int digits)
{
   return(DoubleToString(v, digits));
}

string CSV_Time(datetime t)
{
   if(t == 0) return("");
   MqlDateTime s;
   TimeToStruct(t, s);
   return(StringFormat("%04d-%02d-%02d %02d:%02d", s.year, s.mon, s.day, s.hour, s.min));
}

string CSV_Dir(int dir)
{
   if(dir > 0) return("Buy");
   if(dir < 0) return("Sell");
   return("");
}

string CSV_Bool(bool b) { return(b ? "1" : "0"); }

// چهار ستونِ Open,High,Low,Close یک پنجره‌ی سشن؛ اگر نامعتبر باشد (مثلاً لندن/NY-باکس
// در ابتدای تاریخچه پوشش نداشته)، خالی نوشته می‌شود بدونِ skipِ کلِ روز.
string CSV_Range4(const SSessionRange &r, int digits)
{
   if(!r.valid) return(",,,");
   return(CSV_Num(r.open, digits) + "," + CSV_Num(r.high, digits) + "," +
          CSV_Num(r.low, digits)  + "," + CSV_Num(r.close, digits));
}

const string CSV_HEADER =
   "Date,BoxHigh,BoxLow,BoxSize,LP_FirstBreak_Dir,LP_FirstBreak_Time,LP_FirstBreak_BodyRatio,"
   "LP_Reached1R,LP_Label,LP_FlipTime,NY_PrevHigh,NY_PrevLow,NY_PrevRange,NY_AtVote,"
   "NY_AtVote_PenetrationDepth$,NY_AtVote_PenetrationPct,NY_EndOfDay,NY_BreakTime,DayColor,R_Day,"
   "Tokyo_Open,Tokyo_High,Tokyo_Low,Tokyo_Close,London_Open,London_High,London_Low,London_Close,"
   "NY_Open,NY_High,NY_Low,NY_Close,FullDay_Open,FullDay_High,FullDay_Low,FullDay_Close,"
   "DayHigh_Time,DayLow_Time";

#endif // DAYBIAS_CSVWRITER_MQH
