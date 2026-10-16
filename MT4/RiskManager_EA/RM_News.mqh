//+------------------------------------------------------------------+
//| Risk Manager EA - RM_News.mqh                                    |
//| v105 (FEAT: خبرهای USD داخل KEY TIME)                              |
//+------------------------------------------------------------------+
// خبرهای USD با اهمیت قرمز (High) و نارنجی (Medium) — فقط روز جاری (روز تقویمی سرور/بروکر) — با دکمه‌ی KEY TIME
// (g_swOn) روشن/خاموش می‌شوند. هر خبر یک خط عمودی «پر» (خط‌چین‌های KEY TIME از آن‌ها جدا می‌مانند) به رنگ قرمز/نارنجی +
// لیبل ساعت (وقت بروکر) و بالای آن اسم خبر.
//
// منبع: فید رسمی هفتگی ForexFactory (JSON، ساعت با آفست ISO). هر ۱ ساعت یک‌بار (برای کل ترمینال، نه هر چارت) خوانده می‌شود:
//  - تلاش ساعتی با GV مشترک RM_NEWS_TRY_A<acct> (CAS) تا چند چارت همزمان درخواست نزنند.
//  - نتیجه در فایل مشترک RM_News_USD.txt (پوشه‌ی Common) ذخیره می‌شود؛ بقیه‌ی چارت‌ها با تغییر GV RM_NEWS_STAMP_A<acct> آن را می‌خوانند.
//  - قطع بودن فیلترشکن/اینترنت: بی‌صدا فایل قبلی می‌ماند؛ تلاش بعدی ۱۵ دقیقه بعد.
//  - اگر هیچ فایل/فیدی نبود: فهرست ثابت (NFP: جمعه‌ی اول ماه ۰۸:۳۰ نیویورک، FOMC: روزهای تصمیم ۱۴:۰۰ نیویورک) با ستاره (*).
// نیاز: Tools > Options > Expert Advisors > Allow WebRequest for listed URL  +  https://nfs.faireconomy.media
// هیچ I/O در OnTick نیست؛ فقط OnTimer (۱ ثانیه) با throttle ۲۰ ثانیه و فقط وقتی KEY TIME روشن است.

#define NEWS_URL          "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
#define NEWS_FILE         "RM_News_USD.txt"
#define NEWS_PFX          "RM9NW_"
#define NEWS_MAX          150
#define NEWS_REFRESH_SEC  3600
#define NEWS_RETRY_SEC    900
#define NEWS_CHECK_SEC    20
#define NEWS_GROUP_MAX    24

datetime g_newsUtc[NEWS_MAX];
int      g_newsImp[NEWS_MAX];      // 2 = High (قرمز)، 1 = Medium (نارنجی)
string   g_newsTitle[NEWS_MAX];
int      g_newsCount     = 0;
bool     g_newsLoaded    = false;  // فایل کش حداقل یک‌بار برای این چارت خوانده شد
bool     g_newsFeedOk    = false;  // داده‌ی واقعی (فید/کش) داریم؛ false = فهرست ثابت
double   g_newsStampSeen = -1;
datetime g_newsNextCheck = 0;
bool     g_newsWarned    = false;
datetime g_ngT[NEWS_GROUP_MAX];     // گروه‌های امروز (سراسری تا کامپایلر هشدار «uninitialized» ندهد)
int      g_ngImp[NEWS_GROUP_MAX];
string   g_ngName[NEWS_GROUP_MAX];
string   g_ngFull[NEWS_GROUP_MAX];
int      g_newsGroups    = 0;
double   g_newsLastTop   = 0;

string RM_NewsGvStamp() { return "RM_NEWS_STAMP_A" + IntegerToString(AccountNumber()); }
string RM_NewsGvTry()   { return "RM_NEWS_TRY_A"   + IntegerToString(AccountNumber()); }

// مقدار رشته‌ای یک کلید در یک شیء JSON تخت ("key":"value")
string RM_NewsJVal(string obj, string key)
{
   string pat = "\"" + key + "\":\"";
   int p = StringFind(obj, pat);
   if(p < 0) return("");
   p += StringLen(pat);
   int q = StringFind(obj, "\"", p);
   if(q < 0) return("");
   return(StringSubstr(obj, p, q - p));
}

// "2026-10-09T08:30:00-04:00" -> UTC (datetime بدون تایم‌زون)
datetime RM_NewsParseIso(string s)
{
   if(StringLen(s) < 19) return(0);
   datetime loc = StringToTime(StringSubstr(s,0,4) + "." + StringSubstr(s,5,2) + "." + StringSubstr(s,8,2) + " " +
                               StringSubstr(s,11,2) + ":" + StringSubstr(s,14,2));
   if(loc <= 0) return(0);
   int off = 0;
   if(StringLen(s) >= 25)
   {
      int sg = (StringGetChar(s,19) == '-') ? -1 : 1;
      off = sg * ((int)StringToInteger(StringSubstr(s,20,2)) * 3600 + (int)StringToInteger(StringSubstr(s,23,2)) * 60);
   }
   return((datetime)((long)loc - off));
}

// فقط USD و High/Medium را نگه می‌دارد. true = حداقل یک شیء JSON دیده شد (پاسخ معتبر)، حتی اگر هیچ خبر USD مهمی نباشد.
bool RM_NewsParse(string json)
{
   g_newsCount = 0;
   int pos = 0, len = StringLen(json), seen = 0;
   while(pos < len)
   {
      int a = StringFind(json, "{", pos);
      if(a < 0) break;
      int b = StringFind(json, "}", a);
      if(b < 0) break;
      pos = b + 1;
      string obj = StringSubstr(json, a, b - a + 1);
      if(RM_NewsJVal(obj, "date") == "") continue;
      seen++;
      if(g_newsCount >= NEWS_MAX) continue;
      if(RM_NewsJVal(obj, "country") != "USD") continue;
      string imp = RM_NewsJVal(obj, "impact");
      int ii = 0;
      if(imp == "High") ii = 2; else if(imp == "Medium") ii = 1;
      if(ii == 0) continue;
      datetime u = RM_NewsParseIso(RM_NewsJVal(obj, "date"));
      if(u <= 0) continue;
      string t = RM_NewsJVal(obj, "title");
      StringReplace(t, "\\", "");
      StringReplace(t, "|", "/");
      g_newsUtc[g_newsCount]   = u;
      g_newsImp[g_newsCount]   = ii;
      g_newsTitle[g_newsCount] = t;
      g_newsCount++;
   }
   return(seen > 0);
}

bool RM_NewsWriteCache()
{
   int h = FileOpen(NEWS_FILE, FILE_WRITE | FILE_TXT | FILE_COMMON);
   if(h == INVALID_HANDLE) return(false);
   FileWrite(h, "RMNEWS1");
   for(int i = 0; i < g_newsCount; i++)
      FileWrite(h, IntegerToString((int)g_newsUtc[i]) + "|" + IntegerToString(g_newsImp[i]) + "|" + g_newsTitle[i]);
   FileClose(h);
   return(true);
}

bool RM_NewsReadCache()
{
   int h = FileOpen(NEWS_FILE, FILE_READ | FILE_TXT | FILE_COMMON);
   if(h == INVALID_HANDLE) return(false);
   if(FileReadString(h) != "RMNEWS1") { FileClose(h); return(false); }
   g_newsCount = 0;
   while(!FileIsEnding(h) && g_newsCount < NEWS_MAX)
   {
      string ln = FileReadString(h);
      int p1 = StringFind(ln, "|");
      if(p1 < 0) continue;
      int p2 = StringFind(ln, "|", p1 + 1);
      if(p2 < 0) continue;
      g_newsUtc[g_newsCount]   = (datetime)StringToInteger(StringSubstr(ln, 0, p1));
      g_newsImp[g_newsCount]   = (int)StringToInteger(StringSubstr(ln, p1 + 1, p2 - p1 - 1));
      g_newsTitle[g_newsCount] = StringSubstr(ln, p2 + 1);
      g_newsCount++;
   }
   FileClose(h);
   g_newsFeedOk = true;
   return(true);
}

void RM_NewsEnsureLoaded()
{
   if(g_newsLoaded) return;
   g_newsLoaded = true;
   RM_NewsReadCache();
   g_newsStampSeen = GlobalVariableCheck(RM_NewsGvStamp()) ? GlobalVariableGet(RM_NewsGvStamp()) : 0;
}

// فهرست ثابت (فقط وقتی فید/کش نیست): NFP و روزهای تصمیم FOMC 2026؛ فقط برای «امروز نیویورک»
void RM_NewsLoadFixed()
{
   g_newsCount = 0;
   int y, m, d;
   ST_GetNYCalendarDate(0, y, m, d);
   datetime nyDay = StringToTime(StringFormat("%04d.%02d.%02d 00:00", y, m, d));
   int nyDow = TimeDayOfWeek(nyDay);
   datetime s1, s2;
   if(nyDow == 5 && d <= 7)   // اولین جمعه‌ی ماه
   {
      ST_ComputeSessionServerTime(y, m, d, 8, 30, 8, 30, s1, s2);
      g_newsUtc[g_newsCount] = (datetime)((long)s1 - ST_ServerOffsetSec());
      g_newsImp[g_newsCount] = 2;
      g_newsTitle[g_newsCount] = "NFP*";
      g_newsCount++;
   }
   if(y == 2026)
   {
      int fm[8] = {1, 3, 4, 6, 7, 9, 10, 12};
      int fd[8] = {28, 18, 29, 17, 29, 16, 28, 9};
      for(int i = 0; i < 8; i++)
         if(fm[i] == m && fd[i] == d)
         {
            ST_ComputeSessionServerTime(y, m, d, 14, 0, 14, 0, s1, s2);
            g_newsUtc[g_newsCount] = (datetime)((long)s1 - ST_ServerOffsetSec());
            g_newsImp[g_newsCount] = 2;
            g_newsTitle[g_newsCount] = "FOMC*";
            g_newsCount++;
         }
   }
}

// اسم کوتاه برای لیبل
string RM_NewsShort(string t)
{
   if(StringFind(t, "Non-Farm") >= 0)            return("NFP");
   if(StringFind(t, "Core CPI") >= 0)            return("Core CPI");
   if(StringFind(t, "CPI") >= 0)                 return("CPI");
   if(StringFind(t, "Core PPI") >= 0)            return("Core PPI");
   if(StringFind(t, "PPI") >= 0)                 return("PPI");
   if(StringFind(t, "Core PCE") >= 0)            return("Core PCE");
   if(StringFind(t, "FOMC Statement") >= 0)      return("FOMC");
   if(StringFind(t, "Federal Funds Rate") >= 0)  return("FOMC Rate");
   if(StringFind(t, "FOMC Press") >= 0)          return("FOMC Presser");
   if(StringFind(t, "FOMC Meeting Minutes") >= 0)return("FOMC Minutes");
   if(StringFind(t, "Powell") >= 0)              return("Powell");
   if(StringFind(t, "Unemployment Claims") >= 0) return("Claims");
   if(StringFind(t, "Unemployment Rate") >= 0)   return("Unemp");
   if(StringFind(t, "Average Hourly") >= 0)      return("AHE");
   if(StringFind(t, "Retail Sales") >= 0)        return("Retail");
   if(StringFind(t, "GDP") >= 0)                 return("GDP");
   if(StringFind(t, "ISM Manufacturing") >= 0)   return("ISM Mfg");
   if(StringFind(t, "ISM Services") >= 0)        return("ISM Svc");
   if(StringFind(t, "ADP") >= 0)                 return("ADP");
   if(StringFind(t, "JOLTS") >= 0)               return("JOLTS");
   if(StringFind(t, "Consumer Sentiment") >= 0)  return("UoM Sent");
   if(StringFind(t, "Inflation Expectations") >= 0) return("UoM Infl");
   if(StringFind(t, "Durable Goods") >= 0)       return("Durables");
   if(StringLen(t) > 16) return(StringSubstr(t, 0, 16));
   return(t);
}

void RM_NewsRemove()
{
   for(int i = 0; i < g_newsGroups; i++)
   {
      ObjectDelete(0, NEWS_PFX + "L" + IntegerToString(i));
      ObjectDelete(0, NEWS_PFX + "T" + IntegerToString(i));
      ObjectDelete(0, NEWS_PFX + "N" + IntegerToString(i));
   }
   g_newsGroups  = 0;
   g_newsLastTop = 0;
}

// قیمتِ لیبل ساعت (همان لنگر KEY TIME) و لیبل اسم (حدود ۱۳ پیکسل بالاتر)
void RM_NewsPrices(double &pTime, double &pName)
{
   double pBot;
   GetSessionWindowPriceRange(pTime, pBot);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int xPix   = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2;
   int sw = -1; datetime td = 0;
   if(!ChartXYToTimePrice(0, xPix, chartH - 14 - 6 - 13, sw, td, pName) || sw != 0)
      pName = pTime + (WindowPriceMax(0) - WindowPriceMin(0)) * 0.02;
}

// (دوباره) خط‌ها و لیبل‌های خبرهای امروز را می‌سازد؛ فقط از حافظه می‌خواند.
void RM_NewsBuild()
{
   RM_NewsRemove();
   if(!g_swOn) return;
   RM_NewsEnsureLoaded();
   if(!g_newsFeedOk) RM_NewsLoadFixed();

   int off = ST_ServerOffsetSec();
   datetime nowS = TimeCurrent();
   datetime d0 = (datetime)((long)nowS - ((long)nowS % 86400));

   int gn = 0;
   for(int z = 0; z < NEWS_GROUP_MAX; z++) { g_ngT[z] = 0; g_ngImp[z] = 0; g_ngName[z] = ""; g_ngFull[z] = ""; }
   for(int i = 0; i < g_newsCount; i++)
   {
      datetime t = (datetime)((long)g_newsUtc[i] + off);
      if(t < d0 || t >= d0 + 86400) continue;
      string sh = RM_NewsShort(g_newsTitle[i]);
      int k = -1;
      for(int j = 0; j < gn; j++) if(g_ngT[j] == t) { k = j; break; }
      if(k < 0)
      {
         if(gn >= NEWS_GROUP_MAX) continue;
         k = gn++;
         g_ngT[k] = t; g_ngImp[k] = g_newsImp[i]; g_ngName[k] = sh; g_ngFull[k] = g_newsTitle[i];
      }
      else
      {
         if(g_newsImp[i] > g_ngImp[k]) g_ngImp[k] = g_newsImp[i];
         if(StringFind("/" + g_ngName[k] + "/", "/" + sh + "/") < 0) g_ngName[k] += "/" + sh;
         g_ngFull[k] += " | " + g_newsTitle[i];
      }
   }

   double pTime, pName;
   RM_NewsPrices(pTime, pName);
   for(int k = 0; k < gn; k++)
   {
      color c = (g_ngImp[k] >= 2) ? C'230,60,60' : C'240,150,40';
      string id = IntegerToString(k);
      string ln = NEWS_PFX + "L" + id, tm = NEWS_PFX + "T" + id, nm = NEWS_PFX + "N" + id;
      SessionLevel_EnsureChartShift(g_ngT[k]);

      if(ObjectFind(0, ln) < 0) ObjectCreate(0, ln, OBJ_VLINE, 0, g_ngT[k], 0);
      ObjectSetInteger(0, ln, OBJPROP_TIME,  g_ngT[k]);
      ObjectSetInteger(0, ln, OBJPROP_COLOR, c);
      ObjectSetInteger(0, ln, OBJPROP_STYLE, STYLE_SOLID);   // پر - متمایز از خط‌چین‌های KEY TIME
      ObjectSetInteger(0, ln, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, ln, OBJPROP_BACK,  true);
      ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ln, OBJPROP_RAY, false);
      ObjectSetString (0, ln, OBJPROP_TOOLTIP, g_ngFull[k]);

      if(ObjectFind(0, tm) < 0) ObjectCreate(0, tm, OBJ_TEXT, 0, g_ngT[k], pTime);
      ObjectSetInteger(0, tm, OBJPROP_TIME,  g_ngT[k]);
      ObjectSetDouble (0, tm, OBJPROP_PRICE, pTime);
      ObjectSetString (0, tm, OBJPROP_TEXT,  StringFormat("%02d:%02d", TimeHour(g_ngT[k]), TimeMinute(g_ngT[k])));
      ObjectSetInteger(0, tm, OBJPROP_COLOR, c);
      ObjectSetInteger(0, tm, OBJPROP_FONTSIZE, 7);
      ObjectSetString (0, tm, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, tm, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, tm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, tm, OBJPROP_BACK, false);

      string shown = g_ngName[k];
      if(StringLen(shown) > 26) shown = StringSubstr(shown, 0, 24) + "..";
      if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TEXT, 0, g_ngT[k], pName);
      ObjectSetInteger(0, nm, OBJPROP_TIME,  g_ngT[k]);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, pName);
      ObjectSetString (0, nm, OBJPROP_TEXT,  shown);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 8);
      ObjectSetString (0, nm, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetString (0, nm, OBJPROP_TOOLTIP, g_ngFull[k]);
   }
   g_newsGroups  = gn;
   g_newsLastTop = pTime;
}

// فقط موقعیت عمودی لیبل‌ها (زوم/اسکرول) - از UpdateSessionWindowsVertical صدا زده می‌شود (حداکثر هر ۳ ثانیه)
void RM_NewsUpdateVertical()
{
   if(!g_swOn || g_newsGroups <= 0) return;
   double pTime, pName;
   RM_NewsPrices(pTime, pName);
   if(pTime == g_newsLastTop) return;
   g_newsLastTop = pTime;
   for(int k = 0; k < g_newsGroups; k++)
   {
      string id = IntegerToString(k);
      if(ObjectFind(0, NEWS_PFX + "T" + id) >= 0) ObjectSetDouble(0, NEWS_PFX + "T" + id, OBJPROP_PRICE, pTime);
      if(ObjectFind(0, NEWS_PFX + "N" + id) >= 0) ObjectSetDouble(0, NEWS_PFX + "N" + id, OBJPROP_PRICE, pName);
   }
}

// تلاش ساعتیِ مشترک (CAS) - true فقط برای یک چارتی که برنده شد
bool RM_NewsClaimRefresh(datetime now)
{
   string k = RM_NewsGvTry();
   if(!GlobalVariableCheck(k)) { GlobalVariableSet(k, (double)now); return(true); }
   double last = GlobalVariableGet(k);
   if((double)now - last < NEWS_REFRESH_SEC) return(false);
   return(GlobalVariableSetOnCondition(k, (double)now, last));
}

bool RM_NewsFetch()
{
   char post[], res[];
   string rh = "";
   ArrayResize(post, 0);
   ResetLastError();
   int code = WebRequest("GET", NEWS_URL, "User-Agent: Mozilla/5.0\r\n", 4000, post, res, rh);
   if(code == -1)
   {
      int e = GetLastError();
      if(!g_newsWarned)
      {
         g_newsWarned = true;
         if(e == 4060) Print("[RM-NEWS] WebRequest not allowed. Add https://nfs.faireconomy.media in Tools > Options > Expert Advisors > Allow WebRequest. Using cached/fixed list.");
         else          Print("[RM-NEWS] feed unavailable (error ", e, ") - using cached/fixed list; retry in ", NEWS_RETRY_SEC/60, " min");
      }
      return(false);
   }
   if(code != 200) { Print("[RM-NEWS] feed HTTP ", code, " - using cached/fixed list"); return(false); }
   string body = CharArrayToString(res, 0, WHOLE_ARRAY, CP_UTF8);
   if(!RM_NewsParse(body)) { Print("[RM-NEWS] feed parse failed - using cached/fixed list"); return(false); }
   g_newsFeedOk = true;
   g_newsWarned = false;
   RM_NewsWriteCache();
   double stamp = (double)TimeLocal();
   GlobalVariableSet(RM_NewsGvStamp(), stamp);
   g_newsStampSeen = stamp;
   Print("[RM-NEWS] feed refreshed by ", RM_InstTag(), ": ", g_newsCount, " USD High/Medium events this week");
   return(true);
}

// از OnTimer (۱ ثانیه) صدا زده می‌شود؛ throttle ۲۰ ثانیه، فقط وقتی KEY TIME روشن است
void RM_NewsTick()
{
   if(!g_swOn || IsTesting()) return;
   datetime now = TimeLocal();
   if(now < g_newsNextCheck) return;
   g_newsNextCheck = now + NEWS_CHECK_SEC;

   bool changed = false;
   if(!g_newsLoaded) { RM_NewsEnsureLoaded(); changed = true; }
   double stamp = GlobalVariableCheck(RM_NewsGvStamp()) ? GlobalVariableGet(RM_NewsGvStamp()) : 0;
   if(stamp != g_newsStampSeen)
   {
      g_newsStampSeen = stamp;
      if(RM_NewsReadCache()) changed = true;
   }
   if(RM_NewsClaimRefresh(now))
   {
      if(RM_NewsFetch()) changed = true;
      else GlobalVariableSet(RM_NewsGvTry(), (double)((long)now - NEWS_REFRESH_SEC + NEWS_RETRY_SEC));   // شکست -> ۱۵ دقیقه بعد دوباره
   }
   if(changed) RM_NewsBuild();
}
