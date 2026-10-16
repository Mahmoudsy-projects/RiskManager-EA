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
input int InpServerUtcOffsetMin = 180;   // Server->UTC offset (min); 180=UTC+3 (default), 99999=auto

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
   if(IsTesting())
   {
      if(InpServerUtcOffsetMin != 99999)
         return(InpServerUtcOffsetMin * 60);
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
   else if(InpServerUtcOffsetMin != 99999)  { rmDiagRet = InpServerUtcOffsetMin*60; rmDiagSrc = "input-fallback"; }
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

   int off = ST_ServerOffsetSec();
   outStart = utcStartRaw + off;
   outEnd   = utcEndRaw   + off;

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
