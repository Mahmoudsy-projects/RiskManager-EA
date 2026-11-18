//+------------------------------------------------------------------+
//|                                              RM_SessionTime.mq5   |
//|  v75.0 (P0-1): ماژول آفست پایدار سرور->UTC - پورت MT5 از          |
//|  RM_SessionTime.mqh نسخه‌ی MT4 v107 (فقط بخش آفست؛ توابع بازار-محور |
//|  FEAT-060 و Key Time بخش P1 هستند و اینجا نیستند).                 |
//|                                                                    |
//|  مشکل قبلی MT5: آفست هر بار زنده از (int)(TimeCurrent()-TimeGMT())  |
//|  حساب می‌شد؛ TimeCurrent() آخر هفته/بازار ساکت کهنه است و آفست غلط   |
//|  (مثلاً چند ساعت) می‌داد، و هیچ شبکه‌ی ایمنی نداشت.                  |
//|                                                                    |
//|  اولویت خروجی: ۱) آفست زنده‌ی تأییدشده/GV (سه تیک متوالی روی یک      |
//|  مقدار)  ۲) اینپوت InpServerUtcOffsetMin (تابستانی آمریکا؛ زمستان    |
//|  خودکار -۶۰ دقیقه)  ۳) صفر.                                         |
//|  توابع IsUSDST_UTC/GetNYCalendarDate (RM_Tools.mq5) دست‌نخورده       |
//|  می‌مانند و فقط از این ماژول آفست می‌گیرند.                           |
//+------------------------------------------------------------------+
#ifndef RM_SESSIONTIME_MQ5
#define RM_SESSIONTIME_MQ5

input group "=== Server Time (v75.0 P0-1) ==="
// آفست سرور->UTC (دقیقه) - پیش‌فرض 180 (UTC+3 در US-DST؛ زمستان آمریکا خودکار یک ساعت کمتر = UTC+2).
// 99999 = خودکار (فقط تشخیص زنده). آفست زنده‌ی تأییدشده اولویت دارد؛ این عدد fallback وقتی هنوز
// کالیبره نشده یا بازار ساکته. روی بروکر غیر UTC+3 این عدد را عوض کن (یا 99999).
input int InpServerUtcOffsetMin = 180;   // v75.0 (P0-1): Server->UTC offset in US-DST/SUMMER (min); 180=UTC+3 (winter -60 auto), 99999=auto

#define ST_GV_OFFSET_KEY "RM_SrvUtcOffsetSec"
#define ST_GV_TICK_KEY   "RM_SrvUtcOffsetTick"

datetime g_stLastTick   = 0;
int      g_stOffsetSec  = 0;
bool     g_stHaveOffset = false;
bool     g_stLoadedGV   = false;
int      g_stAgreeVal   = -1234567;   // مقدار گِردشده‌ای که تیک‌های متوالی روش توافق دارند
int      g_stAgreeCount = 0;

// قاعده‌ی رسمی US DST (همان فرمول IsUSDST_UTC در RM_Tools.mq5؛ اینجا مستقل است چون این ماژول
// قبل از RM_Tools.mq5 include می‌شود): شروع دومین یکشنبه‌ی مارس 07:00 UTC، پایان اولین یکشنبه‌ی نوامبر 06:00 UTC.
bool ST_IsUSDST(datetime utcTime)
{
   MqlDateTime dtY; TimeToStruct(utcTime, dtY);
   int y = dtY.year;
   datetime marchFirst = StringToTime(IntegerToString(y) + ".03.01 00:00");
   MqlDateTime dtM; TimeToStruct(marchFirst, dtM);
   int dowM = dtM.day_of_week;
   int firstSunM  = (dowM == 0) ? 1 : (8 - dowM);
   int secondSunM = firstSunM + 7;
   datetime dstStart = StringToTime(IntegerToString(y) + ".03." + IntegerToString(secondSunM) + " 07:00");

   datetime novFirst = StringToTime(IntegerToString(y) + ".11.01 00:00");
   MqlDateTime dtN; TimeToStruct(novFirst, dtN);
   int dowN = dtN.day_of_week;
   int firstSunN  = (dowN == 0) ? 1 : (8 - dowN);
   datetime dstEnd = StringToTime(IntegerToString(y) + ".11." + IntegerToString(firstSunN) + " 06:00");

   return(utcTime >= dstStart && utcTime < dstEnd);
}

// آفست بر پایه‌ی «اینپوت تابستانی + قاعده‌ی US-DST» (تستر / کالیبره‌نشده). 99999 -> 0.
int ST_InputRuleOffsetAtUtc(datetime utcInstant)
{
   if(InpServerUtcOffsetMin == 99999) return(0);
   int summer = InpServerUtcOffsetMin * 60;
   return(ST_IsUSDST(utcInstant) ? summer : summer - 3600);
}

int ST_ServerOffsetSec()
{
   // (۰) استراتژی‌تستر: TimeGMT غیرقابل‌اتکا است -> اینپوت + قاعده (99999 -> 0).
   if(MQLInfoInteger(MQL_TESTER) != 0)
   {
      if(InpServerUtcOffsetMin != 99999)
         return(ST_InputRuleOffsetAtUtc(TimeCurrent() - InpServerUtcOffsetMin * 60));
      return(0);
   }

   // (۱) یک‌بار در هر اجرا: مقدار ذخیره‌شده (آفست + تیک کالیبراسیون) از GV.
   if(!g_stLoadedGV)
   {
      g_stLoadedGV = true;
      if(GlobalVariableCheck(ST_GV_OFFSET_KEY))
      {
         g_stOffsetSec  = (int)(MathRound(GlobalVariableGet(ST_GV_OFFSET_KEY) / 60.0) * 60.0);
         g_stHaveOffset = true;
      }
      if(GlobalVariableCheck(ST_GV_TICK_KEY))
         g_stLastTick = (datetime)GlobalVariableGet(ST_GV_TICK_KEY);
      Print("[ST-DIAG] GV-load | GVoffsetExists=", (GlobalVariableCheck(ST_GV_OFFSET_KEY)?"1":"0"),
            " loadedOffset=", g_stOffsetSec,
            " GVtick=", TimeToString(g_stLastTick, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            " | TimeCurrent=", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            " TimeGMT=", TimeToString(TimeGMT(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            " rawNow=", (int)(TimeCurrent()-TimeGMT()));
   }

   // (۲) فقط وقتی تیک واقعاً جلو رفته دوباره کالیبره کن؛ فقط وقتی چند تیک *متوالی* روی یک مقدار
   //     گِردشده توافق کنند آن را establish/persist کن (تیک کهنه تک‌بار است و شمارنده را ریست می‌کند).
   datetime tc = TimeCurrent();
   if(tc > g_stLastTick)
   {
      int raw = (int)(tc - TimeGMT());
      int rounded = (int)(MathRound((double)raw / 60.0) * 60.0);
      bool plausible = (raw != 0 && MathAbs(raw) <= 14 * 3600);
      g_stLastTick = tc;
      if(plausible)
      {
         if(rounded == g_stAgreeVal) g_stAgreeCount++;
         else { g_stAgreeVal = rounded; g_stAgreeCount = 1; }

         if(g_stAgreeCount >= 3 && (!g_stHaveOffset || rounded != g_stOffsetSec))
         {
            Print("[ST-DIAG] calibrate CONFIRMED | offset=", rounded,
                  " prev=", (g_stHaveOffset?g_stOffsetSec:-999999), " agree=", g_stAgreeCount);
            g_stOffsetSec  = rounded;
            g_stHaveOffset = true;
            GlobalVariableSet(ST_GV_OFFSET_KEY, (double)rounded);
            GlobalVariableSet(ST_GV_TICK_KEY,   (double)tc);
            GlobalVariablesFlush();   // v75.0 (P0-1): رویداد نادر؛ آفست بعد از بسته‌شدن غیرتمیز ترمینال هم بماند
         }
      }
      else
      {
         g_stAgreeCount = 0;
         Print("[ST-DIAG] calibrate SKIP(implausible) | raw=", raw);
      }
   }

   // (۳) اولویت خروجی: زنده/GV -> اینپوت(قاعده) -> 0
   int ret;
   string src;
   if(g_stHaveOffset)                      { ret = g_stOffsetSec; src = "live/GV"; }
   else if(InpServerUtcOffsetMin != 99999) { ret = ST_InputRuleOffsetAtUtc(TimeCurrent() - InpServerUtcOffsetMin*60); src = "input-fallback(rule)"; }
   else                                    { ret = 0; src = "default0"; }
   static int lastRet = -1234567;
   if(ret != lastRet)
   {
      Print("[ST-DIAG] offset RETURN=", ret, " source=", src);
      lastRet = ret;
   }
   return(ret);
}

// «الان» به UTC: زنده TimeGMT() (همیشه جاری)؛ در تستر از TimeCurrent() منهای آفست.
datetime ST_NowUTC()
{
   return (MQLInfoInteger(MQL_TESTER) != 0) ? (TimeCurrent() - ST_ServerOffsetSec()) : TimeGMT();
}

//+------------------------------------------------------------------+
//| v75.1 (MT4 v107 FEAT-060): DST بازارهای دیگر + ساعت محلی بازار -> UTC -> سرور (per-day).|
//| MT4 مرجع: RM_SessionTime.mqh. فقط API تبدیل شد (TimeToStruct به‌جای TimeYear/DayOfWeek). |
//+------------------------------------------------------------------+
#define ST_MKT_NY      0   // نیویورک (US rule)
#define ST_MKT_LONDON  1   // لندن (EU rule)، UTC+0 / +1
#define ST_MKT_BERLIN  2   // فرانکفورت/برلین (EU rule)، UTC+1 / +2
#define ST_MKT_TOKYO   3   // توکیو، UTC+9 ثابت
#define ST_MKT_SYDNEY  4   // سیدنی (AU rule)، UTC+10 / +11
#define ST_MKT_UTC     5   // UTC خام

// ساعت محلی سیدنی برای خط فرعی «۰۱:۰۰» Key Time. فقط همین یک عدد را عوض کن.
#define ST_SYDNEY_FINAL_HOUR_LOCAL 16

int ST_DayOfWeek(datetime t) { MqlDateTime d; TimeToStruct(t, d); return d.day_of_week; }
int ST_YearOf(datetime t)    { MqlDateTime d; TimeToStruct(t, d); return d.year; }

int ST_FirstSundayDay(int y, int month)
{
   datetime first = StringToTime(StringFormat("%04d.%02d.01 00:00", y, month));
   int dow = ST_DayOfWeek(first);
   return((dow == 0) ? 1 : (8 - dow));
}
int ST_LastSundayDay31(int y, int month)   // فقط ماه‌های ۳۱ روزه (مارس/اکتبر)
{
   datetime last = StringToTime(StringFormat("%04d.%02d.31 00:00", y, month));
   return(31 - ST_DayOfWeek(last));
}

bool ST_IsEUDST(datetime utcTime)
{
   int y = ST_YearOf(utcTime);
   datetime dstStart = StringToTime(StringFormat("%04d.03.%02d 01:00", y, ST_LastSundayDay31(y, 3)));
   datetime dstEnd   = StringToTime(StringFormat("%04d.10.%02d 01:00", y, ST_LastSundayDay31(y, 10)));
   return(utcTime >= dstStart && utcTime < dstEnd);
}

bool ST_IsAUDST(datetime utcTime)
{
   int y = ST_YearOf(utcTime);
   datetime dstEnd   = StringToTime(StringFormat("%04d.04.%02d 00:00", y, ST_FirstSundayDay(y, 4)))  - 8 * 3600;
   datetime dstStart = StringToTime(StringFormat("%04d.10.%02d 00:00", y, ST_FirstSundayDay(y, 10))) - 8 * 3600;
   return(utcTime < dstEnd || utcTime >= dstStart);
}

int ST_MarketStdOffsetSec(int market)
{
   switch(market)
   {
      case ST_MKT_NY:     return(-5 * 3600);
      case ST_MKT_LONDON: return(0);
      case ST_MKT_BERLIN: return(1 * 3600);
      case ST_MKT_TOKYO:  return(9 * 3600);
      case ST_MKT_SYDNEY: return(10 * 3600);
   }
   return(0);
}

int ST_MarketUtcOffsetSec(int market, datetime utcInstant)
{
   int off = ST_MarketStdOffsetSec(market);
   bool dst = false;
   if(market == ST_MKT_NY)                                      dst = ST_IsUSDST(utcInstant);
   else if(market == ST_MKT_LONDON || market == ST_MKT_BERLIN)  dst = ST_IsEUDST(utcInstant);
   else if(market == ST_MKT_SYDNEY)                             dst = ST_IsAUDST(utcInstant);
   return(dst ? off + 3600 : off);
}

datetime ST_MarketLocalToUtc(int market, datetime localRaw)
{
   datetime guess = localRaw - ST_MarketStdOffsetSec(market);
   return(localRaw - ST_MarketUtcOffsetSec(market, guess));
}

// تاریخ تقویمی نیویورک برای daysAgo روز قبل از امروز (منفی = آینده)
void ST_GetNYCalendarDate(int daysAgo, int &y, int &m, int &d)
{
   datetime nowUTC = ST_NowUTC();
   bool nowDst = ST_IsUSDST(nowUTC);
   int  nowNyOffSec = nowDst ? (-4 * 3600) : (-5 * 3600);
   datetime nowNY   = nowUTC + nowNyOffSec;
   datetime targetNY = nowNY - ((datetime)daysAgo) * 86400;
   MqlDateTime dt; TimeToStruct(targetNY, dt);
   y = dt.year; m = dt.mon; d = dt.day;
}

// آفست سرور->UTC برای یک لحظه‌ی UTC دلخواه (روز تاریخی). سرور با US-DST حرکت می‌کند: UTC+3 در US-DST، وگرنه UTC+2.
// آفست زنده منبع حقیقت «الان» است؛ برای روزهای دیگر فقط «دلتای قاعده» اضافه می‌شود. اگر آفست زنده با قاعده‌ی امروز
// نخواند، [ST-DIAG] چاپ می‌شود و برای همه‌ی روزها همان آفست زنده می‌ماند (رفتار محافظه‌کارانه v106).
int ST_ServerOffsetForUtc(datetime utcInstant)
{
   int live = ST_ServerOffsetSec();
   if(MQLInfoInteger(MQL_TESTER) != 0 || !g_stHaveOffset)
      return(ST_InputRuleOffsetAtUtc(utcInstant));

   datetime tc = TimeCurrent();
   datetime nowUtc = (tc > 0) ? (tc - live) : TimeGMT();
   int ruleNow = ST_IsUSDST(nowUtc) ? 10800 : 7200;
   static int stDiagLastKey = -1234567;
   if(live != ruleNow)
   {
      int key = live * 10 + (ST_IsUSDST(nowUtc) ? 1 : 0);
      if(key != stDiagLastKey)
      {
         Print("[ST-DIAG] offset-vs-rule MISMATCH | live=", live, " ruleToday=", ruleNow,
               " usDST=", (ST_IsUSDST(nowUtc)?"1":"0"), " -> using live offset for ALL days (no per-day delta)");
         stDiagLastKey = key;
      }
      return(live);
   }
   stDiagLastKey = -1234567;
   int ruleAt = ST_IsUSDST(utcInstant) ? 10800 : 7200;
   return(live + (ruleAt - ruleNow));
}

// یک روز تقویمی نیویورک (y/m/d) + شروع/پایان به وقت نیویورک -> بازه به وقت سرور. end<=start = رد از نیمه‌شب.
void ST_ComputeSessionServerTime(int y, int m, int d,
                                 int nyStartH, int nyStartM, int nyEndH, int nyEndM,
                                 datetime &outStart, datetime &outEnd)
{
   datetime nyMidnightRaw = StringToTime(StringFormat("%04d.%02d.%02d 00:00", y, m, d));
   bool dst = ST_IsUSDST(nyMidnightRaw + 12 * 3600);
   int nyOffsetSec = dst ? (-4 * 3600) : (-5 * 3600);

   datetime nyStartRaw = nyMidnightRaw + nyStartH * 3600 + nyStartM * 60;
   datetime nyEndRaw   = nyMidnightRaw + nyEndH   * 3600 + nyEndM   * 60;
   if(nyEndRaw <= nyStartRaw) nyEndRaw += 86400;

   datetime utcStartRaw = nyStartRaw - nyOffsetSec;
   datetime utcEndRaw   = nyEndRaw   - nyOffsetSec;
   outStart = utcStartRaw + ST_ServerOffsetForUtc(utcStartRaw);
   outEnd   = utcEndRaw   + ST_ServerOffsetForUtc(utcEndRaw);
}

void ST_ComputeSessionByDaysAgo(int daysAgo,
                                int nyStartH, int nyStartM, int nyEndH, int nyEndM,
                                datetime &outStart, datetime &outEnd)
{
   int y, m, d;
   ST_GetNYCalendarDate(daysAgo, y, m, d);
   ST_ComputeSessionServerTime(y, m, d, nyStartH, nyStartM, nyEndH, nyEndM, outStart, outEnd);
}

// نسخه‌ی market-aware: ساعت شروع/پایان = ساعت محلی بازار روی روز تقویمی y/m/d؛ DST همان بازار در همان لحظه.
void ST_ComputeSessionServerTimeMkt(int market, int y, int m, int d,
                                    int sH, int sM, int eH, int eM,
                                    datetime &outStart, datetime &outEnd)
{
   if(market == ST_MKT_NY) { ST_ComputeSessionServerTime(y, m, d, sH, sM, eH, eM, outStart, outEnd); return; }

   datetime midRaw   = StringToTime(StringFormat("%04d.%02d.%02d 00:00", y, m, d));
   datetime startRaw = midRaw + sH * 3600 + sM * 60;
   datetime endRaw   = midRaw + eH * 3600 + eM * 60;
   if(endRaw <= startRaw) endRaw += 86400;

   datetime utcStart = ST_MarketLocalToUtc(market, startRaw);
   datetime utcEnd   = ST_MarketLocalToUtc(market, endRaw);
   outStart = utcStart + ST_ServerOffsetForUtc(utcStart);
   outEnd   = utcEnd   + ST_ServerOffsetForUtc(utcEnd);
}

void ST_ComputeSessionByDaysAgoMkt(int daysAgo, int market,
                                   int sH, int sM, int eH, int eM,
                                   datetime &outStart, datetime &outEnd)
{
   int y, m, d;
   ST_GetNYCalendarDate(daysAgo, y, m, d);
   ST_ComputeSessionServerTimeMkt(market, y, m, d, sH, sM, eH, eM, outStart, outEnd);
}

#endif
