//+------------------------------------------------------------------+
//| RM_Common.mqh                                                    |
//| R8 (Architecture Refactor, Final Phase): خونه‌ی نهایی برای توابعی  |
//| که در R2 تا R7 عمداً در فایل اصلی نگه داشته شدن چون بین ۲+ ماژول   |
//| مختلف مشترک بودن. طبق grep دقیق در R8:                            |
//|                                                                    |
//| - HLine(): مصرف‌کننده‌ها RM_AutoActions.mqh + RM_Tools.mqh +        |
//|   RM_TradeExecution.mqh + RM_Trailing.mqh (۴ ماژول - در فرض اولیه  |
//|   R8 فقط ۲ ماژول (TradeExecution+Tools) تصور می‌شد؛ grep دو مصرف‌   |
//|   کننده‌ی دیگه هم پیدا کرد: AutoActions و Trailing)                 |
//| - HLineLabel(): مصرف‌کننده‌ها RM_AutoActions.mqh + RM_Tools.mqh      |
//| - GetBasketAveragePrice(): مصرف‌کننده‌ها RM_CooldownEngine.mqh +     |
//|   RM_Tools.mqh (UpdateBERefLine) + RM_TradeExecution.mqh            |
//| - BELineName(): مصرف‌کننده‌ها RM_AutoActions.mqh +                   |
//|   RM_CooldownEngine.mqh + RM_TradeExecution.mqh (۳ ماژول - در فرض   |
//|   اولیه R8 فقط RM_TradeExecution.mqh تصور می‌شد؛ grep دو مصرف‌کننده‌ی |
//|   دیگه هم پیدا کرد: AutoActions و CooldownEngine)                   |
//| - BasketAvgLineName(): مصرف‌کننده‌ها RM_CooldownEngine.mqh +         |
//|   RM_TradeExecution.mqh                                             |
//|                                                                    |
//| توجه: EstimateServerTime() از این فایل حذف شد - طبق grep فقط توسط  |
//| RM_Tools.mqh مصرف می‌شه (تک‌ماژوله، نه مشترک)، پس مستقیماً به داخل   |
//| RM_Tools.mqh منتقل شد، نه اینجا (globalهای g_ctLastServerSync/      |
//| g_ctLastLocalSync/g_ctLastEstimate از قبل همون‌جا مقیم بودن).       |
//|                                                                    |
//| PadL()/PadR() از این فایل حذف نشدن چون اصلاً مصرف‌کننده‌ی چندماژوله  |
//| ندارن (PadL فقط توسط RM_Dashboard.mqh مصرف می‌شه) و در Parking Lot   |
//| R2 تا R7 هم به‌عنوان آیتم مشترک ثبت نشده بودن - خارج از Scope این    |
//| فاز، دست‌نخورده در فایل اصلی باقی موندن.                            |
//|                                                                    |
//| وابستگی: MagicNumber (از RM_Config.mqh) - پس این فایل باید بعد از   |
//| RM_Config.mqh include بشه، نه قبلش.                                |
//+------------------------------------------------------------------+

void HLine(string n,double price,color clr,int w,int style)
{
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,n,OBJPROP_PRICE,price);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,w);
   ObjectSetInteger(0,n,OBJPROP_STYLE,style);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_BACK,true);
}

// v34.1 (Mahmoud feedback - line identification): small OBJ_TEXT label sitting just to the right
// of a horizontal reference line.
// v34.2 (Mahmoud feedback - label was sitting in the middle, not the right edge): the original
// "current bar + 2 bars" placement (same idea UpdateCandleTimerChart() uses) assumed the chart's
// blank right margin was small, but MT4's default right margin is usually much wider than 2 bars,
// so the label landed well short of the actual right edge.
// v34.3 (compile fix - "ChartXYToTime not defined"): v34.2 called the wrong function name -
// ChartXYToTime() doesn't exist in MQL4, the real function is ChartXYToTimePrice(), which this
// file already uses successfully elsewhere (see the CHARTEVENT_MOUSE_MOVE handler in
// OnChartEvent()) for exactly this kind of pixel-to-time/price conversion. Now uses that same
// proven function to ask the chart directly for the time coordinate a few pixels in from its
// current right edge - tracks the true visible right edge live as the trader scrolls/zooms.
// v42 (Punch List, Part 4): new optional aboveLine parameter (default false, so all 6 existing
// Daily/Weekly/Monthly H/L callers are byte-for-byte unaffected) - when true, switches the anchor
// from ANCHOR_RIGHT (vertically centered on the line - fine for a thin H/L line, but the Auto Half
// Close/Auto Trail preview labels were sitting directly on top of their own dashed line and hard to
// read) to ANCHOR_RIGHT_LOWER, which anchors the text's bottom-right corner at the point instead,
// so the text renders just above the line.
// v48 (Item 1 - چهارمین/نهایی تلاش، طبق پیشنهاد خود Mahmoud): تلاش سوم (هل‌دادن لنگر از
// عرض کل پنل رد بشه) کار می‌کرد ولی وسط چارت شلوغ می‌کرد - چیزی که Mahmoud نمی‌خواست. راه‌حل
// پیشنهادی خودش بهتره: کلاً این لیبل‌ها رو ببریم سمت مقابل پنل (چپ مانیتور، وقتی پنل
// PanelRight=true باشه) به‌جای اینکه دور پنل بپیچن و وسط صفحه بیفتن. anchorLeft پارامتر
// اختیاری جدیده (پیش‌فرض false - دقیقاً همون رفتار قبلی برای هر دو مصرف‌کننده‌ی دیگه‌ی این
// تابع که این پارامتر رو نمی‌دن). وقتی true باشه، لنگر از لبه‌ی راست چارت (chartW-marginPx)
// به لبه‌ی چپ (marginPx از صفر) منتقل می‌شه و جهت رشد متن هم برعکس می‌شه (ANCHOR_LEFT/
// ANCHOR_LEFT_LOWER به‌جای ANCHOR_RIGHT/ANCHOR_RIGHT_LOWER) - متن از لنگر به‌سمت راست رشد
// می‌کنه، نه چپ، پس داخل چارت می‌مونه نه بیرون از لبه‌ی چپ.
void HLineLabel(string n, double price, color clr, string txt, bool aboveLine=false, bool anchorLeft=false, int marginPx=8)
{
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int anchorX = anchorLeft ? marginPx : chartW-marginPx;
   int subWin = 0; datetime t = 0; double dummyPrice = 0;
   if(!ChartXYToTimePrice(0, anchorX, 0, subWin, t, dummyPrice))
      // v48 (Item 1، چهارمین تلاش): fallback هم جهت‌دار شد - قبلاً همیشه به سمت آینده/راست
      // بود که برای anchorLeft معنی نداشت؛ حالا برای سمت چپ به یه بار قدیمی‌تر می‌ره.
      t = anchorLeft ? iTime(Symbol(), PERIOD_CURRENT, 200) : iTime(Symbol(), PERIOD_CURRENT, 0) + Period()*60*10;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_TEXT,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_TIME,  t);
   ObjectSetDouble (0,n,OBJPROP_PRICE, price);
   ObjectSetString (0,n,OBJPROP_TEXT,  txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR, clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE, 8);
   ObjectSetString (0,n,OBJPROP_FONT,  "Arial Bold");
   // v48 (Item 1، چهارمین تلاش): سمت چپ برعکس سمت راسته - متن باید از لنگر به‌سمت راست رشد
   // کنه (ANCHOR_LEFT/ANCHOR_LEFT_LOWER)، نه چپ، وگرنه از لبه‌ی چپ چارت بیرون می‌زد.
   int anchorConst = anchorLeft ? (aboveLine ? ANCHOR_LEFT_LOWER  : ANCHOR_LEFT)
                                 : (aboveLine ? ANCHOR_RIGHT_LOWER : ANCHOR_RIGHT);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR, anchorConst);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,n,OBJPROP_BACK, false);
}

// v14 (Advanced Break Even - BasketAverage): میانگین وزنی قیمت ورود همه‌ی پوزیشن‌های
// هم‌بسکتِ جهت isBuy رو حساب می‌کنه (وزن = حجم OrderLots هر پوزیشن). بسکت یعنی:
// Magic Number یکسان + نماد یکسان + جهت یکسان (خرید و فروش هیچ‌وقت با هم میانگین‌گیری نمی‌شن).
// اگه هیچ پوزیشنی در اون جهت باز نباشه، false برمی‌گردونه و avgPrice دست‌نخورده می‌مونه.
bool GetBasketAveragePrice(bool isBuy, double &avgPrice)
{
   double sumVolPrice = 0, sumVol = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=Symbol()) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      bool buy=(OrderType()==OP_BUY);
      if(buy!=isBuy) continue;
      sumVolPrice += OrderOpenPrice()*OrderLots();
      sumVol      += OrderLots();
   }
   if(sumVol<=0) return false;
   avgPrice = NormalizeDouble(sumVolPrice/sumVol, Digits);
   return true;
}

string BELineName(int ticket)    { return "RM9LN_BE_"+IntegerToString(ticket); }
// v14 (Advanced Break Even - BasketAverage): خط میانگین بسکت - جدا برای بسکت خرید و بسکت فروش،
// چون هر دو ممکنه هم‌زمان باز باشن (مثلاً هج). با MagicNumber هم namespace می‌شه تا اگه چند نمونه‌ی
// EA با Magicهای متفاوت روی همون چارت باشن تداخل نکنن.
string BasketAvgLineName(bool isBuy) { return "RM9LN_BEAVG_"+(isBuy?"BUY":"SELL")+"_"+IntegerToString(MagicNumber); }
