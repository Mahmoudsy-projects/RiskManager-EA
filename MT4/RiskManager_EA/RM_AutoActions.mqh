//+------------------------------------------------------------------+
//| RM_AutoActions.mqh                                                 |
//| Risk Manager EA - Auto Trigger Actions (Architecture Refactor, R7) |
//| استخراج‌شده از RiskManager_EA_v45_R6.mq4 - Auto Trailing/Auto Half   |
//| Close/Auto BE (تشخیص/شروع، نه مکانیک پیوسته‌ی Trailing خودش)، خطوط   |
//| پیش‌نمایش سطح فعال‌سازی (UpdateAutoTriggerPreviewLines)، و کمکی‌های   |
//| ردیابی «قبلاً Auto Half Close شده» (Is/Add/RemoveAutoHalfDone - در    |
//| اسکوپ اصلی توضیح داده نشده بودن، ولی چون تنها مصرف‌کننده‌ی            |
//| g_autoHalfDoneTickets/g_autoHalfDoneCount همینا هستن، اینجا اومدن -  |
//| Parking Lot این فاز رو ببین). وابستگی یک‌طرفه به RM_Trailing.mqh     |
//| (IsTrailTracked/AddTrailTicket) - این ماژول هیچ‌وقت از AutoActions   |
//| چیزی نمی‌خواد. صرفاً جابه‌جایی کد، بدون تغییر مقدار/رفتار.            |
//+------------------------------------------------------------------+

// === v40 (FEAT-019): Auto Half Close - لیست تیکت‌هایی که Auto Half Close براشون قبلاً اجرا
// شده - دقیقاً همون الگوی in-memory تیکت‌های Trailing (g_trailTickets) - تا هر تیک دوباره
// اجرا نشه و روی همون تیکت بارها بخشی از باقیمونده رو نبنده. مثل ردیابی Trailing، فقط در
// حافظه‌ست (نه GlobalVariable) - با بسته‌شدن کامل تیکت پاک می‌شه (RemoveAutoHalfDone در
// CheckClosedTrades، هم‌جا با RemoveTrailTicket).
int      g_autoHalfDoneTickets[];
int      g_autoHalfDoneCount = 0;
// v40: خروجی جانبی HalfCloseTicket() - اگه آخرین فراخوانی یک تیکت باقیمونده‌ی جدید ساخت،
// شماره‌ش اینجا ذخیره می‌شه (صفر یعنی نساخت) تا CheckAutoHalfCloseTrigger بتونه وضعیت
// «قبلاً Auto Half Close شده» رو به باقیمونده هم منتقل کنه.
int      g_lastHalfCloseRemainderTicket = 0;

// v40 (Mahmoud feedback): خط‌های پیش‌نمایش (خط‌چین، نه خط توپر مثل خط واقعی Trailing/BE بالا) -
// نشون می‌دن Auto Half Close / Auto Trailing (اگه فعال باشن) از کدوم قیمت به بعد شروع می‌شن.
// همون الگوی نام‌گذاری بر اساس شماره‌ی تیکت.
string AutoHalfPreviewLineName(int ticket)   { return "RM9LN_AHPRE_"+IntegerToString(ticket); }

string AutoHalfPreviewLabelName(int ticket)  { return "RM9LB_AHPRE_"+IntegerToString(ticket); }

string AutoTrailPreviewLineName(int ticket)  { return "RM9LN_ATPRE_"+IntegerToString(ticket); }

string AutoTrailPreviewLabelName(int ticket) { return "RM9LB_ATPRE_"+IntegerToString(ticket); }

// v48 (فیچر جدید - درخواست Mahmoud بعد از تست v48): همون الگوی دقیق AutoHalf/AutoTrail بالا -
// Auto BE هم حالا خط پیش‌نمایش خودش رو داره (قبلاً هیچ نشونه‌ای روی چارت نبود که تریدر بفهمه
// Auto BE کجا/کی فعال می‌شه، فقط بعد از trigger خوردن، دکمه‌ی دستی BE خط واقعی می‌کشید).
string BEPreviewLineName(int ticket)  { return "RM9LN_BEPRE_"+IntegerToString(ticket); }

string BEPreviewLabelName(int ticket) { return "RM9LB_BEPRE_"+IntegerToString(ticket); }

// === v40 (FEAT-019): Auto Half Close "already fired" helpers - همون الگوی دقیق
// IsHalfExempt/AddHalfExempt/RemoveHalfExempt بالا و IsTrailTracked/AddTrailTicket ===
// v101 (BUG-054): لیست «قبلاً Auto Half Close شده» فقط حافظه‌ی همان نمونه بود. با دو چارت هم‌نماد، هر دو نمونه روی +RR
// تیکت را Half Close می‌کردند؛ و چون نمونه‌ی دوم تیکت باقی‌مانده را در لیست خودش نداشت، باقی‌مانده را دوباره Half Close
// می‌کرد. حالا یک GV حساب‌محور (RM_AUTOHALF_A<حساب>_M<مجیک>_<تیکت>) هم‌زمان claim اتمیک و پرچم «انجام شد» است:
// IsAutoHalfDone حافظه یا GV را چک می‌کند؛ فقط نمونه‌ای که claim (RM_ClaimKey) را بگیرد Half Close می‌زند.
string AutoHalfDoneKey(int ticket) { return "RM_AUTOHALF_A" + IntegerToString(AccountNumber()) + "_M" + IntegerToString(MagicNumber) + "_" + IntegerToString(ticket); }

bool IsAutoHalfDone(int ticket)
{
   for(int i=0;i<g_autoHalfDoneCount;i++)
      if(g_autoHalfDoneTickets[i]==ticket) return true;
   return GlobalVariableCheck(AutoHalfDoneKey(ticket));
}

// فقط حافظه‌ی محلی (بعد از شکست claim یا برای صرفه‌جویی در GV خواندن)
void AddAutoHalfDoneLocal(int ticket)
{
   for(int i=0;i<g_autoHalfDoneCount;i++)
      if(g_autoHalfDoneTickets[i]==ticket) return;
   ArrayResize(g_autoHalfDoneTickets, g_autoHalfDoneCount+1);
   g_autoHalfDoneTickets[g_autoHalfDoneCount] = ticket;
   g_autoHalfDoneCount++;
}

void AddAutoHalfDone(int ticket)
{
   GlobalVariableSet(AutoHalfDoneKey(ticket), (double)Period());  // v101: پرچم مشترک (بدون شرط؛ برای تیکت باقی‌مانده هم صدا زده می‌شود)
   AddAutoHalfDoneLocal(ticket);
}

void RemoveAutoHalfDone(int ticket)
{
   if(GlobalVariableCheck(AutoHalfDoneKey(ticket))) GlobalVariableDel(AutoHalfDoneKey(ticket));  // v101: تیکت بسته شده؛ دیگر کسی نیاز ندارد
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
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      int tk = OrderTicket();
      if(IsTrailTracked(tk)) continue;
      double op=OrderOpenPrice(), sl=OrderStopLoss();
      if(sl<=0) continue;
      double slDist=MathAbs(op-sl);
      if(slDist<=0) continue;
      bool buy=(OrderType()==OP_BUY);
      double cur=buy?Bid:Ask;
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
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      int tk = OrderTicket();
      if(IsAutoHalfDone(tk)) continue;
      double op=OrderOpenPrice(), sl=OrderStopLoss();
      if(sl<=0) continue;
      double slDist=MathAbs(op-sl);
      if(slDist<=0) continue;
      bool buy=(OrderType()==OP_BUY);
      double cur=buy?Bid:Ask;
      double curR = buy ? (cur-op)/slDist : (op-cur)/slDist;
      if(curR >= AutoHalfCloseTriggerRR)
      {
         // v40: مارک کردن قبل از فراخوانی HalfCloseTicket - حتی اگه OrderClose به هر
         // دلیلی (مثلاً خطای بروکر) شکست بخوره، دیگه هر تیک دوباره تلاش نمی‌کنه؛ رفتار
         // یک‌بارمصرف Auto Trigger، هماهنگ با فلسفه‌ی بقیه‌ی این پروژه (مثل AddTrailTicket).
         // v101 (BUG-054): claim اتمیک - فقط یک نمونه‌ی هم‌نماد Half Close می‌زند (هم claim هم پرچم «انجام شد»)
         double ahOwner = 0.0;
         if(!RM_ClaimKey(AutoHalfDoneKey(tk), (double)Period(), ahOwner))
         {
            AddAutoHalfDoneLocal(tk);
            Print("[RM-MI] Auto Half Close #", tk, " skipped on ", RM_InstTag(), " (already fired by ", RM_TfName(ahOwner), ")");
            continue;
         }
         AddAutoHalfDoneLocal(tk);
         if(HalfCloseTicket(tk, AutoHalfClosePercent, "Auto Half Close"))
         {
            SetStatus("Auto Half Close: "+DoubleToStr(AutoHalfClosePercent,0)+"% @ "+DoubleToStr(curR,2)+"R", C'210,175,20');
            // v40: اگه MT4 برای باقیمونده‌ی این پوزیشن یک تیکت جدید ساخته، اون تیکت هم
            // «قبلاً Auto Half Close شده» علامت می‌خوره - وگرنه تیک بعدی چون curR باقیمونده
            // هنوز بالای آستانه‌ست، دوباره trigger می‌شد و مدام از باقیمونده می‌بست.
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
      tLeft = iTime(Symbol(), PERIOD_CURRENT, 200);  // fallback: same pattern as HLineLabel()'s anchorLeft fallback
   if(!ChartXYToTimePrice(0, rightX, 0, subWin, tRight, dummyPrice))
      tRight = iTime(Symbol(), PERIOD_CURRENT, 0);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_TREND,0,tLeft,price,tRight,price);
   ObjectSetInteger(0,n,OBJPROP_TIME1,  tLeft);
   ObjectSetDouble (0,n,OBJPROP_PRICE1, price);
   ObjectSetInteger(0,n,OBJPROP_TIME2,  tRight);
   ObjectSetDouble (0,n,OBJPROP_PRICE2, price);
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
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      int tk = OrderTicket();
      bool buy = (OrderType()==OP_BUY);
      double op = OrderOpenPrice(), sl = OrderStopLoss();
      double slDist = (sl>0) ? MathAbs(op-sl) : 0;

      string ahLine = AutoHalfPreviewLineName(tk), ahLbl = AutoHalfPreviewLabelName(tk);
      if(EnableAutoHalfClose && !IsAutoHalfDone(tk) && slDist>0)
      {
         double ahPrice = NormalizeDouble(buy ? op+slDist*AutoHalfCloseTriggerRR : op-slDist*AutoHalfCloseTriggerRR, Digits);
         PreviewHLine(ahLine, ahPrice, C'210,175,20', 1, STYLE_DASH);  // v49 (Punch List, Item 4): was HLine() (full chart width)
         HLineLabel(ahLbl, ahPrice, C'210,175,20', "Auto Half @"+DoubleToStr(AutoHalfCloseTriggerRR,1)+"R", true, true);  // v49 (Punch List, Item 4 follow-up): anchorLeft=true - label now sits on the left with the line (was right-anchored, which no longer matched the width-capped line)
      }
      else
      {
         ObjectDelete(0, ahLine);
         ObjectDelete(0, ahLbl);
      }

      string atLine = AutoTrailPreviewLineName(tk), atLbl = AutoTrailPreviewLabelName(tk);
      if(EnableAutoTrailing && !IsTrailTracked(tk) && slDist>0)
      {
         double atPrice = NormalizeDouble(buy ? op+slDist*AutoTrailingTriggerRR : op-slDist*AutoTrailingTriggerRR, Digits);
         PreviewHLine(atLine, atPrice, clrTeal, 1, STYLE_DASH);  // v49 (Punch List, Item 4): was HLine() (full chart width)
         HLineLabel(atLbl, atPrice, clrTeal, "Auto Trail @"+DoubleToStr(AutoTrailingTriggerRR,1)+"R", true, true);  // v49 (Punch List, Item 4 follow-up): anchorLeft=true - label now sits on the left with the line
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
         double bePrice = NormalizeDouble(buy ? op+slDist*BEatR : op-slDist*BEatR, Digits);
         PreviewHLine(bePreLine, bePrice, clrAqua, 1, STYLE_DASH);  // v49 (Punch List, Item 4): was HLine() (full chart width)
         HLineLabel(bePreLbl, bePrice, clrAqua, "Auto BE @"+DoubleToStr(BEatR,1)+"R", true, true);  // v49 (Punch List, Item 4 follow-up): anchorLeft=true - label now sits on the left with the line
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
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol()||OrderMagicNumber()!=MagicNumber) continue;
      if(OrderStopLoss()<=0) continue;
      bool buy=(OrderType()==OP_BUY);
      double op=OrderOpenPrice(),sl=OrderStopLoss(),dist=MathAbs(op-sl);
      // v6 (BUG-008 fix): نتیجه‌ی OrderModify چک می‌شه؛ اگه ناموفق بود لاگ می‌شه.
      // نیازی به retry دستی نیست چون تا وقتی SL جابه‌جا نشده، شرط تیک بعدی دوباره true می‌مونه و خودش امتحان می‌شه.
      // v7 (FEAT-011): اسپرد لحظه‌ای واقعی رو به محاسبه‌ی BE اضافه می‌کنیم تا سطح محافظت‌شده
      // هزینه‌ی واقعی اجرا رو هم پوشش بده و ضررهای کوچیک ناشی از اسپرد رخ نده
      double spreadPrice = Ask-Bid;
      if(buy&&Bid>=op+dist*BEatR&&sl<op)
      {
         double nsl=NormalizeDouble(op+spreadPrice+BEextra*Point*PipFactor(),Digits);
         if(Bid>nsl)
         {
            if(OrderModify(OrderTicket(),op,nsl,OrderTakeProfit(),0,clrAqua))
            {
               // v48 (Item 2 - BUG fix): قبلاً اینجا HLine(BELineName(...)) خط نشانه‌گر BE رو
               // می‌کشید و همون‌جا رها می‌کرد - تا وقتی خود معامله بسته نمی‌شد (پاکسازی توی
               // RM_CooldownEngine.mqh) یا داشبورد Minimize/Maximize نمی‌شد (rebuild کامل پنل)،
               // روی چارت باقی می‌موند. حالا همون لحظه‌ای که Auto BE واقعاً اجرا می‌شه (OrderModify
               // موفق)، همین خط صریحاً ObjectDelete می‌شه - بدون نیاز به بسته‌شدن معامله یا
               // rebuild پنل. دکمه‌ی BE دستی (ManualBE در RM_TradeExecution.mqh) دست‌نخورده
               // می‌مونه - این فیکس فقط مسیر Auto BE رو پوشش می‌ده.
               ObjectDelete(0, BELineName(OrderTicket()));
               CheckPrematureAction(OrderTicket(), "Auto BE"); // v18 (BUG-021)
            }
            else
               Print("CheckAutoBE: OrderModify failed for ticket ", OrderTicket(), " (error ", GetLastError(), "), will retry next tick");
         }
      }
      if(!buy&&Ask<=op-dist*BEatR&&sl>op)
      {
         double nsl=NormalizeDouble(op-spreadPrice-BEextra*Point*PipFactor(),Digits);
         if(Ask<nsl)
         {
            if(OrderModify(OrderTicket(),op,nsl,OrderTakeProfit(),0,clrAqua))
            {
               // v48 (Item 2 - BUG fix): همون فیکس بالا - sell branch
               ObjectDelete(0, BELineName(OrderTicket()));
               CheckPrematureAction(OrderTicket(), "Auto BE"); // v18 (BUG-021)
            }
            else
               Print("CheckAutoBE: OrderModify failed for ticket ", OrderTicket(), " (error ", GetLastError(), "), will retry next tick");
         }
      }
   }
}
