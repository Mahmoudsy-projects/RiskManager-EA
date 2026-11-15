//+------------------------------------------------------------------+
//|                                              RM_SessionTime.mqh   |
//|  ماژولِ زمانِ سشن — تک‌منبعِ مشترک بینِ RiskManager EA و Executive   |
//|  Hub. (فایلِ canonical: نسخه‌ی byte-identical در هر دو پوشه قرار     |
//|  می‌گیرد. فقط این نسخه ویرایش می‌شود و به پوشه‌ی دیگر کپی می‌شود.)    |
//|                                                                    |
//|  چرا وجود دارد: قبلاً سه پیاده‌سازیِ تقریباً یکسانِ NY->UTC->server   |
//|  (Session Windows، Session Level، Hub/SOB/NY Edge) داشتیم که هم     |
//|  تکراری بودند هم هر کدام یک باگِ مشترک داشتند. اینجا یک‌بار، درست.   |
//|                                                                    |
//|  دو تضمینِ اصلی:                                                    |
//|   ۱) DSTِ *همان روزِ* هدف (نه امروز) — بازه‌ی تاریخی از مرزِ مارس/     |
//|      نوامبر رد می‌شود، پس هر روز با DSTِ خودش محاسبه می‌شود.          |
//|   ۲) آفستِ سرور->UTC *پایدار*: فقط از تیکِ تازه کالیبره، در یک       |
//|      GlobalVariable ذخیره (تا ری‌لودِ اندیکاتور/سوییچِ تایم‌فریم و     |
//|      سکوتِ تیک/آخرِ هفته آن را خراب نکند). نتیجه: بازمحاسبه‌ی روزِ     |
//|      بسته همیشه همان باکس را می‌دهد → immutable، بدونِ تکیه به حافظه. |
//|                                                                    |
//|  بروکر-مستقل: آفست زنده از همین بروکر خوانده می‌شود، هیچ عددِ ثابتی   |
//|  hardcode نشده.                                                    |
//+------------------------------------------------------------------+
#ifndef RM_SESSIONTIME_MQH
#define RM_SESSIONTIME_MQH

// ورودیِ آفستِ سرور->UTC (دقیقه). پیش‌فرض 180 (UTC+3) — چون هر ۴ بروکرِ استفاده‌شده UTC+3 اند.
// 99999 = خودکار (تشخیصِ زنده). فلسفه‌ی این ماژول: اگر عددِ صریح داده شود، مبنای امن است؛ ولی
// آفستِ زنده‌ی تأییدشده (وقتی موجود باشد) اولویتِ بالاتری دارد. پس 180 هم برای زنده (به‌عنوان
// fallback در سکوت/کالیبره‌نشده) و هم برای بک‌تست (مستقیم) درست کار می‌کند - بدونِ سوییچِ دستی.
// روی بروکرِ غیرِ UTC+3 باید این عدد را عوض کنی (یا 99999 برای خودکار بگذاری).
// v107 (FEAT-060): در استراتژی‌تستر (و وقتی هنوز آفستِ زنده کالیبره نشده) این عدد = آفستِ *تابستانیِ آمریکا* (US-DST) است
// (180=UTC+3)؛ زمستانِ آمریکا خودکار یک ساعت کمتر (UTC+2) از روی قاعده‌ی US-DST اعمال می‌شود. 99999 = خودکار (بدونِ تغییر).
input int InpServerUtcOffsetMin = 180;   // v107: Server->UTC offset in US-DST/SUMMER (min); 180=UTC+3 (winter=-60 auto), 99999=auto

// نامِ GlobalVariable برای پایدارسازیِ آفست + زمانِ تیکی که باهاش کالیبره شد.
#define ST_GV_OFFSET_KEY "RM_SrvUtcOffsetSec"
#define ST_GV_TICK_KEY   "RM_SrvUtcOffsetTick"

//+------------------------------------------------------------------+
//| قاعده‌ی رسمیِ US DST — یکسان در هر سه پیاده‌سازیِ قبلی (تأیید‌شده).    |
//| شروع: دومین یکشنبه‌ی مارس 07:00 UTC | پایان: اولین یکشنبه‌ی نوامبر    |
//| 06:00 UTC. utcTime باید دور از خودِ لبه‌ی نیمه‌شب باشد (ورودی معمولاً |
//| «ظهرِ همان روز» است) تا اعوجاجِ لبه اثر نگذارد.                      |
//+------------------------------------------------------------------+
bool ST_IsUSDST(datetime utcTime)
{
   int y = TimeYear(utcTime);
   datetime marchFirst = StringToTime(IntegerToString(y) + ".03.01 00:00");
   int dowM = TimeDayOfWeek(marchFirst);              // 0=Sunday..6=Saturday
   int firstSunM  = (dowM == 0) ? 1 : (8 - dowM);     // اولین یکشنبه‌ی مارس
   int secondSunM = firstSunM + 7;                    // دومین یکشنبه‌ی مارس
   datetime dstStart = StringToTime(IntegerToString(y) + ".03." + IntegerToString(secondSunM) + " 07:00");

   datetime novFirst = StringToTime(IntegerToString(y) + ".11.01 00:00");
   int dowN = TimeDayOfWeek(novFirst);
   int firstSunN  = (dowN == 0) ? 1 : (8 - dowN);     // اولین یکشنبه‌ی نوامبر
   datetime dstEnd = StringToTime(IntegerToString(y) + ".11." + IntegerToString(firstSunN) + " 06:00");

   return(utcTime >= dstStart && utcTime < dstEnd);
}

//+------------------------------------------------------------------+
//| v107 (FEAT-060): DSTِ بازارهای دیگر + تبدیلِ «ساعتِ محلیِ بازار» -> سرور.  |
//| قواعد: EU = آخرین یکشنبه‌ی مارس -> آخرین یکشنبه‌ی اکتبر (سوییچ ۰۱:۰۰ UTC)؛ |
//| AU/Sydney = DST از اولین یکشنبه‌ی اکتبر تا اولین یکشنبه‌ی آوریل؛ JP = ندارد.|
//+------------------------------------------------------------------+
#define ST_MKT_NY      0   // نیویورک (US rule)
#define ST_MKT_LONDON  1   // لندن (EU rule)، UTC+0 / +1
#define ST_MKT_BERLIN  2   // فرانکفورت/برلین (EU rule)، UTC+1 / +2
#define ST_MKT_TOKYO   3   // توکیو، UTC+9 ثابت (بدونِ DST)
#define ST_MKT_SYDNEY  4   // سیدنی (AU rule)، UTC+10 / +11
#define ST_MKT_UTC     5   // UTC خام

// v107: ساعتِ محلیِ سیدنی برای خطِ فرعیِ «۰۱:۰۰» Key Time (ساعتِ پایانیِ سشنِ سیدنی). فقط همین یک عدد را عوض کن.
#define ST_SYDNEY_FINAL_HOUR_LOCAL 16

// v107: روزِ ماهِ (۱..۳۱) اولین/آخرین یکشنبه‌ی ماه. آخرین‌یکشنبه فقط برای ماه‌های ۳۱‌روزه (مارس/اکتبر) استفاده می‌شود.
int ST_FirstSundayDay(int y, int month)
{
   datetime first = StringToTime(StringFormat("%04d.%02d.01 00:00", y, month));
   int dow = TimeDayOfWeek(first);
   return((dow == 0) ? 1 : (8 - dow));
}
int ST_LastSundayDay31(int y, int month)
{
   datetime last = StringToTime(StringFormat("%04d.%02d.31 00:00", y, month));
   return(31 - TimeDayOfWeek(last));
}

bool ST_IsEUDST(datetime utcTime)
{
   int y = TimeYear(utcTime);
   datetime dstStart = StringToTime(StringFormat("%04d.03.%02d 01:00", y, ST_LastSundayDay31(y, 3)));
   datetime dstEnd   = StringToTime(StringFormat("%04d.10.%02d 01:00", y, ST_LastSundayDay31(y, 10)));
   return(utcTime >= dstStart && utcTime < dstEnd);
}

// AU (نیمکره‌ی جنوبی): DST از اولین یکشنبه‌ی اکتبر ۰۲:۰۰ AEST (= شنبه ۱۶:۰۰ UTC) تا اولین یکشنبه‌ی آوریل
// ۰۳:۰۰ AEDT (= شنبه ۱۶:۰۰ UTC). سال را دور می‌زند: ژانویه..آوریل و اکتبر..دسامبر = DST.
bool ST_IsAUDST(datetime utcTime)
{
   int y = TimeYear(utcTime);
   datetime dstEnd   = StringToTime(StringFormat("%04d.04.%02d 00:00", y, ST_FirstSundayDay(y, 4)))  - 8 * 3600;
   datetime dstStart = StringToTime(StringFormat("%04d.10.%02d 00:00", y, ST_FirstSundayDay(y, 10))) - 8 * 3600;
   return(utcTime < dstEnd || utcTime >= dstStart);
}

// آفستِ استانداردِ (بدونِ DST) هر بازار نسبت به UTC (ثانیه)
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
   return(0);   // ST_MKT_UTC
}

// آفستِ محلی->UTC بازار در یک لحظه‌ی UTC (ثانیه؛ local = utc + offset)
int ST_MarketUtcOffsetSec(int market, datetime utcInstant)
{
   int off = ST_MarketStdOffsetSec(market);
   bool dst = false;
   if(market == ST_MKT_NY)                                  dst = ST_IsUSDST(utcInstant);
   else if(market == ST_MKT_LONDON || market == ST_MKT_BERLIN) dst = ST_IsEUDST(utcInstant);
   else if(market == ST_MKT_SYDNEY)                         dst = ST_IsAUDST(utcInstant);
   return(dst ? off + 3600 : off);
}

// ساعتِ دیواریِ محلیِ بازار (به‌صورت «raw») -> UTC. DST در همان لحظه‌ی واقعی (نه ظهرِ روز) سنجیده می‌شود.
datetime ST_MarketLocalToUtc(int market, datetime localRaw)
{
   datetime guess = localRaw - ST_MarketStdOffsetSec(market);
   return(localRaw - ST_MarketUtcOffsetSec(market, guess));
}

// آفستِ سرور بر پایه‌ی «اینپوتِ تابستانی + قاعده‌ی US-DST» (تستر / زمانِ کالیبره‌نشده). 99999 -> ۰ (مثلِ قبل).
int ST_InputRuleOffsetAtUtc(datetime utcInstant)
{
   if(InpServerUtcOffsetMin == 99999) return(0);
   int summer = InpServerUtcOffsetMin * 60;
   return(ST_IsUSDST(utcInstant) ? summer : summer - 3600);
}

//+------------------------------------------------------------------+
//| تاریخِ تقویمیِ نیویورک برای daysAgo روز قبل از امروز.                |
//| daysAgo منفی = آینده (امروز/فردا) — عمداً پشتیبانی می‌شود چون بعضی   |
//| ابزارها باکسِ «هنوز شروع‌نشده» را هم از قبل می‌سازند.                 |
//| DST برای «الان» فقط جهتِ یافتنِ روزِ تقویمیِ درستِ نیویورک استفاده     |
//| می‌شود؛ محاسبه‌ی خودِ بازه پایین‌تر با DSTِ همان روز انجام می‌شود.     |
//+------------------------------------------------------------------+
void ST_GetNYCalendarDate(int daysAgo, int &y, int &m, int &d)
{
   // v78.4 (فیکسِ بک‌تست): در استراتژی‌تستر TimeGMT() به ساعتِ واقعیِ سیستم اشاره می‌کند (نه زمانِ
   // شبیه‌سازی‌شده‌ی تستر)، پس «الان»ِ نیویورک غلط محاسبه می‌شد و باکس‌ها روی تاریخِ اشتباه می‌افتادند
   // یا اصلاً دیتا پیدا نمی‌شد. در تستر «الان»ِ UTC را از TimeCurrent() (زمانِ شبیه‌سازیِ سرور) منهای
   // آفست می‌سازیم. در حالتِ زنده همان TimeGMT() (که همیشه جاری است) دست‌نخورده می‌ماند.
   datetime nowUTC = IsTesting() ? (TimeCurrent() - ST_ServerOffsetSec()) : TimeGMT();
   bool nowDst = ST_IsUSDST(nowUTC);
   int  nowNyOffSec = nowDst ? (-4 * 3600) : (-5 * 3600);
   datetime nowNY   = nowUTC + nowNyOffSec;
   datetime targetNY = nowNY - ((datetime)daysAgo) * 86400;
   y = TimeYear(targetNY);
   m = TimeMonth(targetNY);
   d = TimeDay(targetNY);
}

//+------------------------------------------------------------------+
//| آفستِ سرور->UTC (ثانیه)، پایدار و بروکر-مستقل.                       |
//|  - فقط از تیکِ تازه (TimeCurrent جلو رفته) کالیبره می‌شود؛ سکوتِ تیک |
//|    (آخرِ هفته/قطعی) هیچ‌وقت خرابش نمی‌کند.                            |
//|  - مقدارِ معتبر در GlobalVariable ذخیره می‌شود تا ری‌لودِ اندیکاتور   |
//|    (سوییچِ تایم‌فریم) و سکوتِ تیک آن را از دست ندهند.                 |
//|  - راوِ ۰ نادیده گرفته می‌شود: یا بروکر واقعاً UTC است (آن‌وقت پیش‌   |
//|    فرضِ ۰ درست است)، یا محیطی است که TimeGMT==TimeCurrent می‌دهد     |
//|    (مثلِ بعضی تسترها) که باید به مقدارِ ذخیره‌شده/ورودی تکیه کنیم.    |
//+------------------------------------------------------------------+
datetime g_stLastTick   = 0;
int      g_stOffsetSec  = 0;
bool     g_stHaveOffset = false;
bool     g_stLoadedGV   = false;
int      g_stAgreeVal   = -1234567;   // v78.3: مقدارِ گِردشده‌ای که تیک‌های متوالی رویش توافق دارند
int      g_stAgreeCount = 0;          // تعدادِ تیک‌های متوالیِ موافق (برای تأییدِ چند-تیکه)

int ST_ServerOffsetSec()
{
   // (۰) استراتژی‌تستر: کالیبراسیونِ زنده (TimeCurrent/TimeGMT) در تستر غیرقابل‌اتکاست و GV هم
   //     ممکن است منتقل نشود. اگر آفستِ دستی داده شده، مستقیم همان (مسیرِ بک‌تست)؛ وگرنه صریحاً ۰
   //     (باکس‌ها آشکارا غلط می‌مانند تا کاربر آفست بدهد - نه یک کالیبراسیونِ گمراه‌کننده که حتی
   //     ممکن است GVِ زنده را هم خراب کند).
   // v107 (FEAT-060): در تستر اینپوت = آفستِ تابستانیِ آمریکا؛ زمستان/تابستانِ «الانِ شبیه‌سازی» از قاعده‌ی US-DST.
   if(IsTesting())
   {
      if(InpServerUtcOffsetMin != 99999)
         return(ST_InputRuleOffsetAtUtc(TimeCurrent() - InpServerUtcOffsetMin * 60));
      return(0);
   }

   // (۱) یک‌بار در هر اجرا، مقدارِ ذخیره‌شده (آفست + زمانِ تیکِ کالیبراسیون) را از GV بخوان.
   //     زمانِ تیک هم پایدار می‌شود تا بعد از ری‌لودِ اندیکاتور بدانیم آخرین کالیبراسیون
   //     روی کدام تیک بوده - وگرنه اولین فراخوانیِ بعد از ری‌لود، تیکِ فریزشده را «تازه»
   //     فرض می‌کرد و drift را می‌پذیرفت.
   if(!g_stLoadedGV)
   {
      g_stLoadedGV = true;
      if(GlobalVariableCheck(ST_GV_OFFSET_KEY))
      {
         // گِرد به نزدیک‌ترین دقیقه - اگر GV از نسخه‌ی قبل مقدارِ گِردنشده (مثلِ 10799) داشت.
         g_stOffsetSec  = (int)(MathRound(GlobalVariableGet(ST_GV_OFFSET_KEY) / 60.0) * 60.0);
         g_stHaveOffset = true;
      }
      if(GlobalVariableCheck(ST_GV_TICK_KEY))
         g_stLastTick = (datetime)GlobalVariableGet(ST_GV_TICK_KEY);
      // [ST-DIAG] لحظه‌ی load ماژول: چه چیزی در GV بود + وضعیتِ فعلیِ ساعت‌ها (کلیدِ خواب/بیداری)
      Print("[ST-DIAG] GV-load | GVoffsetExists=", (GlobalVariableCheck(ST_GV_OFFSET_KEY)?"1":"0"),
            " loadedOffset=", g_stOffsetSec,
            " GVtick=", TimeToStr(g_stLastTick, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            " | TimeCurrent=", TimeToStr(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            " TimeGMT=", TimeToStr(TimeGMT(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            " rawNow=", (int)(TimeCurrent()-TimeGMT()));
   }

   // (۲) فقط وقتی تیک واقعاً *جلو* رفته (تیکِ تازه، نه فریزشده) دوباره کالیبره کن.
   //     چون g_stLastTick از GV آمده، در سکوتِ تیک/بعدِ ری‌لود، TimeCurrent == آخرین تیک
   //     است → شرط برقرار نمی‌شود → مقدارِ پایدار حفظ می‌شود (بدونِ drift).
   datetime tc = TimeCurrent();
   if(tc > g_stLastTick)
   {
      int raw = (int)(tc - TimeGMT());
      int rmDiagRounded = (int)(MathRound((double)raw / 60.0) * 60.0);   // گِرد به دقیقه (فیکسِ جیترِ ۱ ثانیه، v78.1)
      bool plausible = (raw != 0 && MathAbs(raw) <= 14 * 3600);          // آفستِ منطقیِ تایم‌زون
      g_stLastTick = tc;   // مصرفِ تیک
      // v78.3 (فیکس ریشه‌ای - لاگِ 08.17): گاردِ ±۲hِ v78.2 نمی‌توانست از آفستِ خرابِ GV بازیابی کند
      // (established=-31380 را باور می‌کرد و 10800ِ درست را رد می‌کرد). راه‌حل: یک تیکِ کهنه گذرا و
      // تک‌بار است (و چون TimeGMT جلو می‌رود، حتی چند تیکِ کهنه‌ی پیاپی هم rawِ *متفاوت* می‌دهند)،
      // پس فقط وقتی چند تیکِ *متوالی* روی یک مقدارِ گِردشده توافق کنند آن را establish/persist کن.
      // مقدارِ درست در بازارِ باز روی ده‌ها تیکِ پیاپی ثابت است → establish می‌شود (حتی اگر GV خراب
      // بود، خودبه‌خود بازیابی می‌کند)؛ تیکِ کهنه → شمارنده ریست → هیچ‌وقت establish نمی‌شود.
      if(plausible)
      {
         if(rmDiagRounded == g_stAgreeVal) g_stAgreeCount++;
         else { g_stAgreeVal = rmDiagRounded; g_stAgreeCount = 1; }

         if(g_stAgreeCount >= 3 && (!g_stHaveOffset || rmDiagRounded != g_stOffsetSec))
         {
            Print("[ST-DIAG] calibrate CONFIRMED | offset=", rmDiagRounded,
                  " prev=", (g_stHaveOffset?g_stOffsetSec:-999999), " agree=", g_stAgreeCount,
                  " tc=", TimeToStr(tc, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  " gmt=", TimeToStr(TimeGMT(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
            g_stOffsetSec  = rmDiagRounded;
            g_stHaveOffset = true;
            GlobalVariableSet(ST_GV_OFFSET_KEY, (double)rmDiagRounded);
            GlobalVariableSet(ST_GV_TICK_KEY,   (double)tc);
         }
      }
      else
      {
         g_stAgreeCount = 0;   // تیکِ نامعتبر توافق را می‌شکند
         Print("[ST-DIAG] calibrate SKIP(implausible) | raw=", raw,
               " tc=", TimeToStr(tc, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      }
   }

   // (۳) اولویتِ خروجی (v78.4 - تورِ ایمنیِ خودکار، بدونِ سوییچِ دستیِ کاربر):
   //     ۱) آفستِ زنده/GVِ تأییدشده (دقیق‌ترین)  →  ۲) اینپوتِ ثابت به‌عنوان fallback  →  ۳) ۰.
   //     یعنی در حالتِ عادی زنده، و اگر هنوز کالیبره نشده/سکوت بود، به‌جای ۰ از اینپوت استفاده شود.
   int rmDiagRet;
   string rmDiagSrc;
   if(g_stHaveOffset)                       { rmDiagRet = g_stOffsetSec;            rmDiagSrc = "live/GV"; }
   else if(InpServerUtcOffsetMin != 99999)  { rmDiagRet = ST_InputRuleOffsetAtUtc(TimeCurrent() - InpServerUtcOffsetMin*60); rmDiagSrc = "input-fallback(rule)"; }   // v107: اینپوت=تابستانی، زمستان از قاعده
   else                                     { rmDiagRet = 0;                        rmDiagSrc = "default0"; }
   // [ST-DIAG] مقدارِ برگشتی - فقط وقتی تغییر می‌کند (تا لاگ نترکد)
   static int rmDiagLastRet = -1234567;
   if(rmDiagRet != rmDiagLastRet)
   {
      Print("[ST-DIAG] offset RETURN=", rmDiagRet, " source=", rmDiagSrc,
            " tc=", TimeToStr(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      rmDiagLastRet = rmDiagRet;
   }
   return(rmDiagRet);
}

//+------------------------------------------------------------------+
//| v107 (FEAT-060): آفستِ سرور->UTC برای یک لحظه‌ی UTCِ دلخواه (روزِ تاریخی).|
//| قاعده: سرورِ بروکر با US-DST حرکت می‌کند: UTC+3 در US-DST، وگرنه UTC+2.   |
//| کالیبراسیونِ زنده (ST_ServerOffsetSec) منبعِ حقیقتِ «الان» می‌ماند؛      |
//| برای روزهای دیگر فقط «دلتای قاعده» نسبت به الان به آن اضافه می‌شود. اگر   |
//| آفستِ زنده با قاعده‌ی امروز نخواند، [ST-DIAG] چاپ می‌شود و (محافظه‌کارانه)|
//| برای همه‌ی روزها همان آفستِ زنده می‌ماند (رفتارِ v106) - نه دلتای قاعده.  |
//| فقط در زمانِ (باز)ساخت صدا زده می‌شود؛ هیچ اسکنِ per-tick ندارد.         |
//+------------------------------------------------------------------+
int ST_ServerOffsetForUtc(datetime utcInstant)
{
   int live = ST_ServerOffsetSec();   // اول صدا زده می‌شود تا کالیبراسیون/GV به‌روز شود
   if(IsTesting() || !g_stHaveOffset)
      return(ST_InputRuleOffsetAtUtc(utcInstant));   // تستر یا هنوز کالیبره‌نشده: اینپوتِ تابستانی + قاعده

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

//+------------------------------------------------------------------+
//| یک روزِ تقویمیِ مشخصِ نیویورک (y/m/d) + ساعت:دقیقه‌ی شروع/پایان (به   |
//| وقتِ نیویورک) -> بازه‌ی معادل به وقتِ سرور. کاملاً قطعی برای یک       |
//| ورودیِ ثابت (DSTِ همان روز + آفستِ پایدار) → مبنای immutable.        |
//| اگر end<=start یعنی سشن از نیمه‌شبِ نیویورک رد می‌شود (مثلِ توکیو)،   |
//| یک روز به پایان اضافه می‌شود.                                       |
//+------------------------------------------------------------------+
void ST_ComputeSessionServerTime(int y, int m, int d,
                                 int nyStartH, int nyStartM, int nyEndH, int nyEndM,
                                 datetime &outStart, datetime &outEnd)
{
   datetime nyMidnightRaw = StringToTime(StringFormat("%04d.%02d.%02d 00:00", y, m, d));
   bool dst = ST_IsUSDST(nyMidnightRaw + 12 * 3600);   // چک در «ظهرِ» همان روز - دور از لبه‌ی نیمه‌شب
   int nyOffsetSec = dst ? (-4 * 3600) : (-5 * 3600);  // EDT=-4, EST=-5

   datetime nyStartRaw = nyMidnightRaw + nyStartH * 3600 + nyStartM * 60;
   datetime nyEndRaw   = nyMidnightRaw + nyEndH   * 3600 + nyEndM   * 60;
   if(nyEndRaw <= nyStartRaw) nyEndRaw += 86400;       // عبور از نیمه‌شبِ نیویورک

   // UTC = NY - nyOffsetSec (nyOffsetSec منفی است، پس عملاً +۴/+۵ ساعت)
   datetime utcStartRaw = nyStartRaw - nyOffsetSec;
   datetime utcEndRaw   = nyEndRaw   - nyOffsetSec;

   // v107 (FEAT-060): آفستِ سرور *per-day* (قاعده‌ی US-DST کالیبره با آفستِ زنده) - نه یک آفستِ تکِ «الان» برای همه‌ی روزها.
   outStart = utcStartRaw + ST_ServerOffsetForUtc(utcStartRaw);
   outEnd   = utcEndRaw   + ST_ServerOffsetForUtc(utcEndRaw);

   // v91: چاپ تشخیصی [ST-DIAG] box حذف شد (به‌خاطر static مشترک بین چند پنجره، تقریباً با هر محاسبه چاپ می‌کرد - ~۸۱ هزار خط در روز).
}

//+------------------------------------------------------------------+
//| میان‌بر: مستقیماً با daysAgo (ترکیبِ دو تابعِ بالا) - امضایی هم‌شکلِ   |
//| ComputeSessionWindowServerTime/ComputeServerTimeِ قبلی تا جایگزینیِ  |
//| محلِ فراخوانی حداقلی باشد.                                          |
//+------------------------------------------------------------------+
void ST_ComputeSessionByDaysAgo(int daysAgo,
                                int nyStartH, int nyStartM, int nyEndH, int nyEndM,
                                datetime &outStart, datetime &outEnd)
{
   int y, m, d;
   ST_GetNYCalendarDate(daysAgo, y, m, d);
   ST_ComputeSessionServerTime(y, m, d, nyStartH, nyStartM, nyEndH, nyEndM, outStart, outEnd);
}

//+------------------------------------------------------------------+
//| v107 (FEAT-060): نسخه‌ی market-aware. ساعتِ شروع/پایان = ساعتِ *محلیِ     |
//| بازار* روی روزِ تقویمیِ y/m/d؛ DSTِ همان بازار در همان لحظه اعمال می‌شود، |
//| بعد با آفستِ per-day سرور به وقتِ سرور تبدیل می‌شود. NY عیناً به مسیرِ    |
//| قدیمی (ST_ComputeSessionServerTime) می‌رود. end<=start = رد از نیمه‌شب.   |
//+------------------------------------------------------------------+
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

// daysAgo همان معنای قبلی را دارد (روزِ تقویمیِ نیویورک برای شمارنده‌ی روز؛ منفی = آینده)؛ تاریخِ همان روز
// روی تقویمِ *بازارِ هدف* اعمال می‌شود (مثلاً توکیو 09:00-18:00 روی همان تاریخ = 00:00-09:00 UTC).
void ST_ComputeSessionByDaysAgoMkt(int daysAgo, int market,
                                   int sH, int sM, int eH, int eM,
                                   datetime &outStart, datetime &outEnd)
{
   int y, m, d;
   ST_GetNYCalendarDate(daysAgo, y, m, d);
   ST_ComputeSessionServerTimeMkt(market, y, m, d, sH, sM, eH, eM, outStart, outEnd);
}

//+------------------------------------------------------------------+
//| آیا این بازه کاملاً در گذشته (بسته) است؟ برای تصمیمِ «قفل/immutable».|
//| از بیشترین بینِ TimeCurrent و زمانِ آخرین کندلِ چارت استفاده می‌شود   |
//| تا در سکوتِ تیک هم درست بماند.                                       |
//+------------------------------------------------------------------+
bool ST_IsClosedServerTime(datetime serverEnd)
{
   datetime nowSrv = TimeCurrent();
   datetime lastBar = iTime(Symbol(), Period(), 0);
   if(lastBar > nowSrv) nowSrv = lastBar;
   return(serverEnd <= nowSrv);
}

#endif // RM_SESSIONTIME_MQH
