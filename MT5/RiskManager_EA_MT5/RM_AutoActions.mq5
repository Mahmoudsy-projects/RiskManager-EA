//+------------------------------------------------------------------+
//| RM_AutoActions.mq5                                                 |
//| Risk Manager EA - Auto Trigger Actions (MT5 Port, Stage 4)         |
//| پورت مستقیم از RM_AutoActions.mqh (RiskManager EA v70, MQL4).       |
//| Golden Rule: فرمول‌ها/آستانه‌ها/ترتیب عملیات عوض نشدن.                |
//+------------------------------------------------------------------+

// === v40 (FEAT-019): Auto Half Close - لیست تیکت‌هایی که Auto Half Close براشون قبلاً اجرا
// شده - دقیقاً همون الگوی in-memory تیکت‌های Trailing (g_trailTickets) - تا هر تیک دوباره
// اجرا نشه و روی همون تیکت بارها بخشی از باقیمونده رو نبنده. مثل ردیابی Trailing، فقط در
// حافظه‌ست (نه GlobalVariable) - با بسته‌شدن کامل تیکت پاک می‌شه (RemoveAutoHalfDone در
// CheckClosedTrades، هم‌جا با RemoveTrailTicket).
ulong    g_autoHalfDoneTickets[];
int      g_autoHalfDoneCount = 0;
// v40: خروجی جانبی HalfCloseTicket() - اگه آخرین فراخوانی یک تیکت باقیمونده‌ی جدید ساخت،
// شماره‌ش اینجا ذخیره می‌شه (صفر یعنی نساخت) تا CheckAutoHalfCloseTrigger بتونه وضعیت
// «قبلاً Auto Half Close شده» رو به باقیمونده هم منتقل کنه.
// [Stage 4 note] این متغیر توی RM_TradeExecution.mq5 (Stage 3) هم declare شده (همون‌جا که
// HalfCloseTicket() خودش تعریف شده) - طبق همون فایل اصلی MT4 که این global یک‌بار در فایل اصلی
// تعریف می‌شد و از هر دو ماژول قابل‌دسترسی بود. این فایل باید همیشه بعد از RM_TradeExecution.mq5
// include بشه (همون ترتیبی که وابستگی‌های دیگه‌ی این پروژه هم رعایت می‌کنن) تا g_lastHalfCloseRemainderTicket
// از همون‌جا در دسترس باشه - این‌جا دوباره تعریف نشده تا تعریف تکراری/تداخل پیش نیاد.

// v40 (Mahmoud feedback): خط‌های پیش‌نمایش (خط‌چین، نه خط توپر مثل خط واقعی Trailing/BE بالا) -
// نشون می‌دن Auto Half Close / Auto Trailing (اگه فعال باشن) از کدوم قیمت به بعد شروع می‌شن.
// همون الگوی نام‌گذاری بر اساس شماره‌ی تیکت.
string AutoHalfPreviewLineName(ulong ticket)   { return "RM9LN_AHPRE_"+IntegerToString(ticket); }

string AutoHalfPreviewLabelName(ulong ticket)  { return "RM9LB_AHPRE_"+IntegerToString(ticket); }

string AutoTrailPreviewLineName(ulong ticket)  { return "RM9LN_ATPRE_"+IntegerToString(ticket); }

string AutoTrailPreviewLabelName(ulong ticket) { return "RM9LB_ATPRE_"+IntegerToString(ticket); }

// v48 (فیچر جدید - درخواست Mahmoud بعد از تست v48): همون الگوی دقیق AutoHalf/AutoTrail بالا -
// Auto BE هم حالا خط پیش‌نمایش خودش رو داره (قبلاً هیچ نشونه‌ای روی چارت نبود که تریدر بفهمه
// Auto BE کجا/کی فعال می‌شه، فقط بعد از trigger خوردن، دکمه‌ی دستی BE خط واقعی می‌کشید).
string BEPreviewLineName(ulong ticket)  { return "RM9LN_BEPRE_"+IntegerToString(ticket); }

string BEPreviewLabelName(ulong ticket) { return "RM9LB_BEPRE_"+IntegerToString(ticket); }

// === v40 (FEAT-019): Auto Half Close "already fired" helpers - همون الگوی دقیق
// IsHalfExempt/AddHalfExempt/RemoveHalfExempt بالا و IsTrailTracked/AddTrailTicket ===
bool IsAutoHalfDone(ulong ticket)
{
   for(int i=0;i<g_autoHalfDoneCount;i++)
      if(g_autoHalfDoneTickets[i]==ticket) return true;
   return false;
}

void AddAutoHalfDone(ulong ticket)
{
   if(IsAutoHalfDone(ticket)) return;
   ArrayResize(g_autoHalfDoneTickets, g_autoHalfDoneCount+1);
   g_autoHalfDoneTickets[g_autoHalfDoneCount] = ticket;
   g_autoHalfDoneCount++;
}

void RemoveAutoHalfDone(ulong ticket)
{
   for(int i=0;i<g_autoHalfDoneCount;i++)
   {
      if(g_autoHalfDoneTickets[i]==ticket)
      {
         for(int k=i;k<g_autoHalfDoneCount-1;k++)
            g_autoHalfDoneTickets[k]=g_autoHalfDoneTickets[k+1];
         g_autoHalfDoneCount--;
         ArrayResize(g_autoHalfDoneTickets, g_autoHalfDoneCount);
         return;
      }
   }
}

// اگه Auto Trailing فعال باشه، هر معامله‌ای که به RR تعیین‌شده برسه خودکار وارد Trailing می‌شه
// و دکمه/وضعیت هم به‌صورت خودکار روی ON سینک می‌شه
void CheckAutoTrailingTrigger()
{
   if(!EnableAutoTrailing) return;
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      if(IsTrailTracked(tk)) continue;
      double op=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL);
      if(sl<=0) continue;
      double slDist=MathAbs(op-sl);
      if(slDist<=0) continue;
      bool buy=(posType==POSITION_TYPE_BUY);
      double cur=buy?bid:ask;
      double curR = buy ? (cur-op)/slDist : (op-cur)/slDist;
      if(curR >= AutoTrailingTriggerRR)
      {
         AddTrailTicket(tk);
         if(!g_trailingButtonOn)
         {
            g_trailingButtonOn = true;
            UpdateTrailButton();
            SetStatus("Auto Trailing started", C'0,180,180');
         }
      }
   }
}

// v40 (FEAT-019): همون الگوی دقیق CheckAutoTrailingTrigger بالا - اگه Auto Half Close فعال
// باشه، هر معامله‌ای که به RR تعیین‌شده برسه، خودکار یک‌بار HalfCloseTicket() صدا زده می‌شه
// (با درصد AutoHalfClosePercent). g_autoHalfDoneTickets تضمین می‌کنه هر تیکت فقط یک‌بار
// trigger بشه - وگرنه هر تیک بعدی که هنوز curR بالای آستانه‌ست، دوباره بخشی از باقیمونده رو
// می‌بست. نکته‌ی BUG-021: چون HalfCloseTicket از همون CheckPrematureAction موجود استفاده
// می‌کنه، محافظت «قبل از +1R» خودکار و بدون هیچ کد اضافه‌ای هم اینجا اعمال می‌شه - برای
// تنظیمات معمول (AutoHalfCloseTriggerRR >= 1) تا لحظه‌ی trigger شدن، g_snapMaxFavR این تیکت
// از قبل به‌خاطر UpdateSnapshotMaxFavorableR (هر تیک، مستقل از Half Close) از ۰٫۹۵ رد شده،
// پس هیچ Strike غیرمنتظره‌ای ثبت نمی‌شه. اگه AutoHalfCloseTriggerRR غیرمعمول زیر ۱ تنظیم بشه،
// Strike به‌درستی ثبت می‌شه - چون واقعاً یک اقدام مدیریتی زودهنگامه، دقیقاً همون محافظتی که
// از قبل برای Half Close دستی هم وجود داشت؛ نیازی به حالت خاص جداگانه نیست.
void CheckAutoHalfCloseTrigger()
{
   if(!EnableAutoHalfClose) return;
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      if(IsAutoHalfDone(tk)) continue;
      double op=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL);
      if(sl<=0) continue;
      double slDist=MathAbs(op-sl);
      if(slDist<=0) continue;
      bool buy=(posType==POSITION_TYPE_BUY);
      double cur=buy?bid:ask;
      double curR = buy ? (cur-op)/slDist : (op-cur)/slDist;
      if(curR >= AutoHalfCloseTriggerRR)
      {
         // v40: مارک کردن قبل از فراخوانی HalfCloseTicket - حتی اگه OrderClose به هر
         // دلیلی (مثلاً خطای بروکر) شکست بخوره، دیگه هر تیک دوباره تلاش نمی‌کنه؛ رفتار
         // یک‌بارمصرف Auto Trigger، هماهنگ با فلسفه‌ی بقیه‌ی این پروژه (مثل AddTrailTicket).
         AddAutoHalfDone(tk);
         if(HalfCloseTicket(tk, AutoHalfClosePercent, "Auto Half Close"))
         {
            SetStatus("Auto Half Close: "+DoubleToString(AutoHalfClosePercent,0)+"% @ "+DoubleToString(curR,2)+"R", C'210,175,20');
            // v40: اگه MT4 برای باقیمونده‌ی این پوزیشن یک تیکت جدید ساخته، اون تیکت هم
            // «قبلاً Auto Half Close شده» علامت می‌خوره - وگرنه تیک بعدی چون curR باقیمونده
            // هنوز بالای آستانه‌ست، دوباره trigger می‌شد و مدام از باقیمونده می‌بست.
            // [Stage 4 note] روی MT5، طبق یافته‌ی Stage 3، Half Close تیکت جدید نمی‌سازه -
            // g_lastHalfCloseRemainderTicket عملاً همیشه 0 می‌مونه و این بلوک در عمل no-op است؛
            // دست‌نخورده نگه داشته شده برای وفاداری ساختاری و ایمنی در برابر رفتار احتمالاً
            // متفاوت بعضی بروکرها.
            if(g_lastHalfCloseRemainderTicket>0) AddAutoHalfDone(g_lastHalfCloseRemainderTicket);
         }
      }
   }
}

// v49 (Punch List, Item 4): HLine() (RM_Common.mqh) creates an OBJ_HLINE, which always spans the
// full chart edge-to-edge - fine for the Daily/Weekly/Monthly H/L and PDC lines that use it, but
// with several trades open at once the three dashed Auto Half/Auto Trail/Auto BE preview lines
// below cluttered the whole visible chart. This is a preview-only helper, used ONLY by
// UpdateAutoTriggerPreviewLines() below (not shared - single consumer, kept local to this file
// same as EstimateServerTime()/RM_Tools.mqh precedent) - draws a short, non-ray OBJ_TREND segment
// instead, running from the chart's current left visible edge out to ~10% of the visible chart
// width, so the trigger price is still clearly marked without a line running under the live price
// action on the right side of the chart. Recomputed on every call (same as HLine()), so it tracks
// live as the trader scrolls/zooms, same as HLineLabel()'s existing right-edge tracking.
void PreviewHLine(string n, double price, color clr, int w, int style)
{
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int rightX = (int)(chartW * 0.10);  // ~10% of visible width from the left, per Mahmoud's request
   int subWin = 0; datetime tLeft = 0, tRight = 0; double dummyPrice = 0;
   if(!ChartXYToTimePrice(0, 0, 0, subWin, tLeft, dummyPrice))
      tLeft = iTime(_Symbol, PERIOD_CURRENT, 200);  // fallback: same pattern as HLineLabel()'s anchorLeft fallback
   if(!ChartXYToTimePrice(0, rightX, 0, subWin, tRight, dummyPrice))
      tRight = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_TREND,0,tLeft,price,tRight,price);
   ObjectSetInteger(0,n,OBJPROP_TIME,  0, tLeft);
   ObjectSetDouble (0,n,OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0,n,OBJPROP_TIME,  1, tRight);
   ObjectSetDouble (0,n,OBJPROP_PRICE, 1, price);
   ObjectSetInteger(0,n,OBJPROP_COLOR,  clr);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,  w);
   ObjectSetInteger(0,n,OBJPROP_STYLE,  style);
   ObjectSetInteger(0,n,OBJPROP_RAY_LEFT,  false);
   ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,n,OBJPROP_BACK, true);
}

// v40 (Mahmoud feedback): پیش‌نمایش بصری سطح فعال‌سازی Auto Half Close / Auto Trailing - یک
// خط خط‌چین (STYLE_DASH، در تضاد بصری با STYLE_DOT خط واقعی Trailing/BE) که همون لحظه‌ی باز
// شدن معامله ظاهر می‌شه و تا وقتی این ویژگی واقعاً trigger بشه می‌مونه؛ همون فرمول curR که
// CheckAutoHalfCloseTrigger/CheckAutoTrailingTrigger برای خودِ تصمیم استفاده می‌کنن، اینجا
// فقط برای محاسبه‌ی محل خط به‌کار رفته - صرفاً بصریه، هیچ اثری روی منطق واقعی trigger نداره.
// اگه Auto Half Close/Trailing خاموش باشه یا قبلاً trigger شده باشه، خط پاک می‌شه (یا اصلاً
// ساخته نمی‌شه) - از جمله وقتی تریدر با دکمه‌ی دستی Trailing رو زودتر روشن کنه (چون در اون
// حالت IsTrailTracked بلافاصله true می‌شه و دیگه به پیش‌نمایش نیازی نیست، خط واقعی جاش می‌شینه).
void UpdateAutoTriggerPreviewLines()
{
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      bool buy = (posType==POSITION_TYPE_BUY);
      double op = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL);
      double slDist = (sl>0) ? MathAbs(op-sl) : 0;

      string ahLine = AutoHalfPreviewLineName(tk), ahLbl = AutoHalfPreviewLabelName(tk);
      if(EnableAutoHalfClose && !IsAutoHalfDone(tk) && slDist>0)
      {
         double ahPrice = NormalizeDouble(buy ? op+slDist*AutoHalfCloseTriggerRR : op-slDist*AutoHalfCloseTriggerRR, _Digits);
         PreviewHLine(ahLine, ahPrice, C'210,175,20', 1, STYLE_DASH);  // v49 (Punch List, Item 4): was HLine() (full chart width)
         HLineLabel(ahLbl, ahPrice, C'210,175,20', "Auto Half @"+DoubleToString(AutoHalfCloseTriggerRR,1)+"R", true, true);  // v49 (Punch List, Item 4 follow-up): anchorLeft=true - label now sits on the left with the line (was right-anchored, which no longer matched the width-capped line)
      }
      else
      {
         ObjectDelete(0, ahLine);
         ObjectDelete(0, ahLbl);
      }

      string atLine = AutoTrailPreviewLineName(tk), atLbl = AutoTrailPreviewLabelName(tk);
      if(EnableAutoTrailing && !IsTrailTracked(tk) && slDist>0)
      {
         double atPrice = NormalizeDouble(buy ? op+slDist*AutoTrailingTriggerRR : op-slDist*AutoTrailingTriggerRR, _Digits);
         PreviewHLine(atLine, atPrice, clrTeal, 1, STYLE_DASH);  // v49 (Punch List, Item 4): was HLine() (full chart width)
         HLineLabel(atLbl, atPrice, clrTeal, "Auto Trail @"+DoubleToString(AutoTrailingTriggerRR,1)+"R", true, true);  // v49 (Punch List, Item 4 follow-up): anchorLeft=true - label now sits on the left with the line
      }
      else
      {
         ObjectDelete(0, atLine);
         ObjectDelete(0, atLbl);
      }

      // v48 (فیچر جدید - درخواست Mahmoud): همون الگوی دقیق دو بلوک بالا برای Auto BE - قبلاً
      // هیچ خط راهنمایی روی چارت نبود که نشون بده Auto BE کجا (چه قیمتی) قراره فعال بشه؛ فقط
      // بعد از trigger خوردن یه خط لحظه‌ای می‌اومد (که با فیکس Item 2 همین‌جا بالاتر، دیگه
      // اصلاً نمی‌مونه). شرط نمایش دقیقاً همون شرط trigger واقعی توی CheckAutoBE() - یعنی هنوز
      // SL به سمت BE نرفته (buy: sl<op / sell: sl>op) - پس همین که Auto BE واقعاً اجرا بشه،
      // این شرط خودش false می‌شه و خط/لیبل توی همون تیک از طریق شاخه‌ی else پایین پاک می‌شه -
      // بدون نیاز به کد اضافه‌ی جداگانه (دقیقاً همون رفتاری که Mahmoud برای Half Close/Trailing
      // توصیف کرد: "بعد از تاچ‌شدن هم باید این خط پاک بشه").
      string bePreLine = BEPreviewLineName(tk), bePreLbl = BEPreviewLabelName(tk);
      bool beNotYetTriggered = (buy ? sl<op : sl>op);
      if(AutoBE && sl>0 && slDist>0 && beNotYetTriggered)
      {
         double bePrice = NormalizeDouble(buy ? op+slDist*BEatR : op-slDist*BEatR, _Digits);
         PreviewHLine(bePreLine, bePrice, clrAqua, 1, STYLE_DASH);  // v49 (Punch List, Item 4): was HLine() (full chart width)
         HLineLabel(bePreLbl, bePrice, clrAqua, "Auto BE @"+DoubleToString(BEatR,1)+"R", true, true);  // v49 (Punch List, Item 4 follow-up): anchorLeft=true - label now sits on the left with the line
      }
      else
      {
         ObjectDelete(0, bePreLine);
         ObjectDelete(0, bePreLbl);
      }
   }
}

void CheckAutoBE()
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetDouble(POSITION_SL)<=0) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      bool buy=(posType==POSITION_TYPE_BUY);
      double op=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),dist=MathAbs(op-sl);
      // v6 (BUG-008 fix): نتیجه‌ی OrderModify چک می‌شه؛ اگه ناموفق بود لاگ می‌شه.
      // نیازی به retry دستی نیست چون تا وقتی SL جابه‌جا نشده، شرط تیک بعدی دوباره true می‌مونه و خودش امتحان می‌شه.
      // v7 (FEAT-011): اسپرد لحظه‌ای واقعی رو به محاسبه‌ی BE اضافه می‌کنیم تا سطح محافظت‌شده
      // هزینه‌ی واقعی اجرا رو هم پوشش بده و ضررهای کوچیک ناشی از اسپرد رخ نده
      double spreadPrice = ask-bid;
      if(buy&&bid>=op+dist*BEatR&&sl<op)
      {
         double nsl=NormalizeDouble(op+spreadPrice+BEextra*_Point*PipFactor(),_Digits);
         if(bid>nsl)
         {
            if(RM_ModifyPositionSLTP(tk,nsl,PositionGetDouble(POSITION_TP)))
            {
               // v48 (Item 2 - BUG fix): قبلاً اینجا HLine(BELineName(...)) خط نشانه‌گر BE رو
               // می‌کشید و همون‌جا رها می‌کرد - تا وقتی خود معامله بسته نمی‌شد (پاکسازی توی
               // RM_CooldownEngine.mqh) یا داشبورد Minimize/Maximize نمی‌شد (rebuild کامل پنل)،
               // روی چارت باقی می‌موند. حالا همون لحظه‌ای که Auto BE واقعاً اجرا می‌شه (OrderModify
               // موفق)، همین خط صریحاً ObjectDelete می‌شه - بدون نیاز به بسته‌شدن معامله یا
               // rebuild پنل. دکمه‌ی BE دستی (ManualBE در RM_TradeExecution.mqh) دست‌نخورده
               // می‌مونه - این فیکس فقط مسیر Auto BE رو پوشش می‌ده.
               ObjectDelete(0, BELineName(tk));
               CheckPrematureAction(tk, "Auto BE"); // v18 (BUG-021)
            }
            else
               Print("CheckAutoBE: OrderModify failed for ticket ", tk, " (error ", GetLastError(), "), will retry next tick");
         }
      }
      if(!buy&&ask<=op-dist*BEatR&&sl>op)
      {
         double nsl=NormalizeDouble(op-spreadPrice-BEextra*_Point*PipFactor(),_Digits);
         if(ask<nsl)
         {
            if(RM_ModifyPositionSLTP(tk,nsl,PositionGetDouble(POSITION_TP)))
            {
               // v48 (Item 2 - BUG fix): همون فیکس بالا - sell branch
               ObjectDelete(0, BELineName(tk));
               CheckPrematureAction(tk, "Auto BE"); // v18 (BUG-021)
            }
            else
               Print("CheckAutoBE: OrderModify failed for ticket ", tk, " (error ", GetLastError(), "), will retry next tick");
         }
      }
   }
}
