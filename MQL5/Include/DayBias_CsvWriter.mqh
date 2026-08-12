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

// مثلِ CSV_Time اما با ثانیه — برایِ ستون‌های تشخیصیِ BoxStart_Server/BoxEnd_Server (نسخه‌ی ۳،
// بندِ ۳) که هدفشان دقیقاً کشفِ جیترِ زیرِ-دقیقه‌ای در محاسبه‌ی آفستِ سرور است.
string CSV_TimeSec(datetime t)
{
   if(t == 0) return("");
   MqlDateTime s;
   TimeToStruct(t, s);
   return(StringFormat("%04d-%02d-%02d %02d:%02d:%02d", s.year, s.mon, s.day, s.hour, s.min, s.sec));
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

// نسخه‌ی ۲ (F6): یک ستونِ جدیدِ اختیاری LP_1R_Time بعد از LP_FlipTime اضافه شد — زمانِ رسیدنِ
// جهتِ نهاییِ قفل‌شده به ۱R (چه مستقیم چه بعدِ سوییپ)؛ خودِ LP_FlipTime دیگر با آن مخلوط نمی‌شود.
// نسخه‌ی ۳ (بندِ ۳): دو ستونِ تشخیصیِ BoxStart_Server/BoxEnd_Server در انتها اضافه شد — زمانِ
// سرورِ MT5 که واقعاً برایِ باکسِ توکیویِ LP استفاده شد، تا کاربر بتواند مستقیماً روی چارت چک کند.
// نسخه‌ی ۵ (ClaudeCode_Spec_DayBias_v5_TokyoBracket.md): ۱۱ ستونِ صرفاً-مشاهده‌ای برایِ بک‌تستِ
// استراتژیِ کاندیدِ Tokyo Bracket، بعد از BoxStart_Server/BoxEnd_Server. هیچ ستونِ موجودی تغییر نکرد.
// نسخه‌ی ۶ (ClaudeCode_Spec_DayBias_v6_ReEntry.md): ۱۰ ستونِ صرفاً-مشاهده‌ایِ دیگر برایِ ایده‌ی
// «بازیافت» + داده‌های عمومیِ مسیرِ روز، در انتها. هیچ ستونِ موجودی تغییر نکرد.
// نسخه‌ی ۶.۱ (ClaudeCode_Spec_DayBias_v6_1.md): دو ستونِ تکمیلیِ ترتیبِ رویدادها (عبورِ عمق از
// ۵۰٪/۷۵٪ بعد از لمسِ بازیافتی)، در انتها. هیچ ستونِ موجودی تغییر نکرد.
const string CSV_HEADER =
   "Date,BoxHigh,BoxLow,BoxSize,LP_FirstBreak_Dir,LP_FirstBreak_Time,LP_FirstBreak_BodyRatio,"
   "LP_Reached1R,LP_Label,LP_FlipTime,LP_1R_Time,NY_PrevHigh,NY_PrevLow,NY_PrevRange,NY_AtVote,"
   "NY_AtVote_PenetrationDepth$,NY_AtVote_PenetrationPct,NY_EndOfDay,NY_BreakTime,DayColor,R_Day,"
   "Tokyo_Open,Tokyo_High,Tokyo_Low,Tokyo_Close,London_Open,London_High,London_Low,London_Close,"
   "NY_Open,NY_High,NY_Low,NY_Close,FullDay_Open,FullDay_High,FullDay_Low,FullDay_Close,"
   "DayHigh_Time,DayLow_Time,BoxStart_Server,BoxEnd_Server,"
   "BreakClose_Overshoot$,RetestTouch_Time,RetestTouch_Before1R,RetestWithinTokyo,"
   "MaxDepthIntoBox_Before1R_Pct,RawSweepOccurred,Trade2_MaxR,Trade2_StopHit,"
   "Reach1R_Time,MaxDepth_Time,Depth50_Time,"
   "PostR1_EdgeTouch_Time,PostTouch_MaxR,PostTouch_MaxDepthPct,PostTouch_Reached2R_Before,"
   "FirstTouch_1_5R_Time,FirstTouch_2R_Time,FirstTouch_3R_Time,Pullback_After2R_MaxDepthPct,"
   "EOD_R,Time_At_MaxR,PostTouch_Cross50_Time,PostTouch_Cross75_Time";

#endif // DAYBIAS_CSVWRITER_MQH
