//+------------------------------------------------------------------+
//| RM_Common.mq5                                                     |
//| Risk Manager EA - Shared Utilities (MT5 Port, Stage 3 addendum)    |
//| پورت مستقیم از RM_Common.mqh (RiskManager EA v70, MQL4). طبق        |
//| Golden Rule: فرمول‌ها/آستانه‌ها/ترتیب عملیات عوض نشدن - فقط           |
//| فراخوانی‌های API از MT4 به MT5 ترجمه شدن. باید بعد از RM_Config.mq5  |
//| include بشه (به MagicNumber وابسته‌ست) - همون ترتیب نسخه‌ی MT4.       |
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
      // [Stage 3 judgment call - found during this port, not in the Stage 3 API table]
      // Period()*60*10: MT4's Period() returns raw MINUTES (e.g. 60 for H1). MT5's Period() returns
      // an ENUM_TIMEFRAMES value whose underlying integers are NOT raw minutes for anything above
      // M1-M59 (e.g. PERIOD_H1=16385, PERIOD_D1=16408) - Period()*60*10 would compute a wildly wrong
      // offset on MT5 if translated literally. MT5's direct equivalent for "how many seconds does
      // one bar of the current period span" is PeriodSeconds(PERIOD_CURRENT); the original's
      // Period()*60 (minutes->seconds) becomes PeriodSeconds(PERIOD_CURRENT) directly (already in
      // seconds), keeping the same "10 bars back" fallback distance.
      t = anchorLeft ? iTime(_Symbol, PERIOD_CURRENT, 200) : iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT)*10;
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
//
// [Stage 3] MT4 OrdersTotal()/OrderSelect(SELECT_BY_POS,MODE_TRADES) loop -> MT5
// PositionsTotal()/PositionGetTicket()/PositionSelectByTicket(), same pattern as every other loop
// ported in RM_TradeExecution.mq5. Weighted-average formula itself (sumVolPrice/sumVol) is
// byte-for-byte unchanged - this is the exact function ManualBE_BasketAverage() (Stage 3) calls,
// now no longer a stub/unknown.
bool GetBasketAveragePrice(bool isBuy, double &avgPrice)
{
   double sumVolPrice = 0, sumVol = 0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      bool buy=(posType==POSITION_TYPE_BUY);
      if(buy!=isBuy) continue;
      sumVolPrice += PositionGetDouble(POSITION_PRICE_OPEN)*PositionGetDouble(POSITION_VOLUME);
      sumVol      += PositionGetDouble(POSITION_VOLUME);
   }
   if(sumVol<=0) return false;
   avgPrice = NormalizeDouble(sumVolPrice/sumVol, _Digits);
   return true;
}

// [Stage 3] int ticket -> ulong ticket, same reasoning as every other ticket-typed
// parameter/array in this port (Stage 2's GetTotalOpenRiskExcludingTicket judgment call).
string BELineName(ulong ticket)    { return "RM9LN_BE_"+IntegerToString(ticket); }
// v14 (Advanced Break Even - BasketAverage): خط میانگین بسکت - جدا برای بسکت خرید و بسکت فروش،
// چون هر دو ممکنه هم‌زمان باز باشن (مثلاً هج). با MagicNumber هم namespace می‌شه تا اگه چند نمونه‌ی
// EA با Magicهای متفاوت روی همون چارت باشن تداخل نکنن.
string BasketAvgLineName(bool isBuy) { return "RM9LN_BEAVG_"+(isBuy?"BUY":"SELL")+"_"+IntegerToString(MagicNumber); }
