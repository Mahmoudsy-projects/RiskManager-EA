//+------------------------------------------------------------------+
//| RM_Trailing.mqh                                                    |
//| Risk Manager EA - Trailing Stop Engine (Architecture Refactor, R7) |
//| استخراج‌شده از RiskManager_EA_v45_R6.mq4 - موتور Trailing Stop:      |
//| ردیابی تیکت‌های تحت Trailing (Add/Remove/IsTracked)، همگام‌سازی       |
//| دستی با معاملات باز (SyncManualTrailing)، اجرای واقعی Trailing هر    |
//| تیک (RunTrailingUpdate) و ریست ایمنی BUG-035 (EnsureTrailingReset).  |
//| صرفاً جابه‌جایی کد، بدون هیچ تغییر مقدار/رفتار (Golden Rule فاز R7).  |
//+------------------------------------------------------------------+

// === v7 (FEAT-002): وضعیت Trailing Stop - آرایه‌های ردیابی این ماژول ===
// g_trailCount عمداً در فایل اصلی می‌مونه (نه اینجا) - چون OnChartEvent (فایل اصلی، دائمی)
// مستقیم بهش دسترسی داره (ریست دستی g_trailCount=0 توی منوی Full Close) - طبق grep در همه‌ی
// فایل‌ها تأیید شد؛ تصمیم نهایی مالکیت در Parking Lot این فاز مستند شده.
bool     g_trailingButtonOn  = false;  // کلید اصلی موتور Trailing - با دکمه یا با Auto Trigger روشن می‌شه
int      g_trailTickets[];             // تیکت‌های در حال حاضر تحت ردیابی Trailing
double   g_trailExtreme[];             // v12: بالاترین های (خرید) / پایین‌ترین لو (فروش) ثبت‌شده - هم‌ایندکس با g_trailTickets
int      g_trailPeriod[];              // v13: تایم‌فریمی که Trailing این تیکت باهاش شروع شده - "قفل" می‌مونه حتی اگه بعداً تایم‌فریم چارت عوض بشه
datetime g_trailLastBar[];             // v13: آخرین زمان کندل پردازش‌شده، بر اساس همون تایم‌فریم قفل‌شده‌ی همین تیکت (نه چارت جاری)

//+------------------------------------------------------------------+
// v8 (BUG-010): نام‌گذاری خط‌های نشانه‌گر Trailing/BE بر اساس شماره‌ی تیکت معامله
// تا لحظه‌ی بسته‌شدن معامله بشه دقیقاً همون خط رو با ObjectDelete پیدا و پاک کرد.
// عمداً با پیشوند "RM9_" (P) شروع نمی‌شه تا موقع ObjectsDeleteAll(0,P) روی رویداد
// تغییر چارت، زودتر از موعد پاک نشه - فقط باید همزمان با بسته‌شدن معامله حذف بشه.
//+------------------------------------------------------------------+
string TrailLineName(int ticket) { return "RM9LN_TRAIL_"+IntegerToString(ticket); }

//+------------------------------------------------------------------+
// v7 (FEAT-002): Trailing Stop - توابع کمکی ردیابی تیکت‌ها
//+------------------------------------------------------------------+
bool IsTrailTracked(int ticket)
{
   for(int i=0;i<g_trailCount;i++)
      if(g_trailTickets[i]==ticket) return true;
   return false;
}

void AddTrailTicket(int ticket)
{
   if(IsTrailTracked(ticket)) return;

   // v18 (BUG-021): همین‌جا - لحظه‌ی واقعیِ فعال‌سازی Trailing برای این تیکت (چه با دکمه‌ی
   // دستی از طریق SyncManualTrailing، چه خودکار از طریق CheckAutoTrailingTrigger) - نه هر
   // به‌روزرسانی بعدی کندل در RunTrailingUpdate. به‌خاطر گارد بالا (IsTrailTracked)، این تابع
   // برای هر تیکت فقط یک‌بار واقعاً اجرا می‌شه، پس این چک هم دقیقاً یک‌بار در هر فعال‌سازی صدا زده می‌شه.
   CheckPrematureAction(ticket, "Trailing");

   ArrayResize(g_trailTickets,  g_trailCount+1);
   ArrayResize(g_trailExtreme,  g_trailCount+1);
   ArrayResize(g_trailPeriod,   g_trailCount+1);
   ArrayResize(g_trailLastBar,  g_trailCount+1);
   g_trailTickets[g_trailCount] = ticket;
   // v12: مرجع اولیه‌ی های/لو = قیمت لحظه‌ی شروع ردیابی. از این به بعد فقط عبور واقعی از
   // این مقدار باعث حرکت SL می‌شه، نه هر نوسان کوچیک کندل به کندل.
   if(OrderSelect(ticket, SELECT_BY_TICKET))
      g_trailExtreme[g_trailCount] = (OrderType()==OP_BUY) ? Bid : Ask;
   else
      g_trailExtreme[g_trailCount] = 0;
   // v13: تایم‌فریم فعلی چارت لحظه‌ی شروع Trailing این تیکت "قفل" می‌شه - حتی اگه بعداً
   // برای بررسی به تایم‌فریم دیگه‌ای بری، محاسبه‌ی این تیکت همچنان با همون تایم‌فریم اولیه ادامه پیدا می‌کنه
   g_trailPeriod[g_trailCount]  = Period();
   g_trailLastBar[g_trailCount] = iTime(Symbol(), Period(), 0);  // فقط از کندل بعدی به بعد اثر بذاره
   g_trailCount++;
}

// v50 (وراثت Trailing به تیکت باقیمونده‌ی Half Close): پیدا کردن index یک تیکت در آرایه‌ی
// Trailing - برخلاف IsTrailTracked (که فقط bool برمی‌گردونه)، این تابع خودِ index رو می‌ده
// تا صداکننده بتونه قبل از بسته‌شدن/حذف یک تیکت، مقادیر extreme/period/lastBar همون ردیف
// رو بخونه و نگه داره (مثلاً برای انتقال دقیق به تیکت باقیمونده‌ی Half Close).
int FindTrailIndex(int ticket)
{
   for(int i=0;i<g_trailCount;i++)
      if(g_trailTickets[i]==ticket) return i;
   return -1;
}

// v50 (وراثت Trailing به تیکت باقیمونده‌ی Half Close): برخلاف AddTrailTicket - که (۱) مرجع
// extreme رو با قیمت *لحظه‌ی الان* پر می‌کنه و (۲) هر بار CheckPrematureAction رو صدا می‌زنه
// (چون از نظر AddTrailTicket هر فراخوانی یعنی «یک فعال‌سازی جدید») - این تابع یک ردیف جدید
// رو مستقیماً با مقادیر از پیش‌تعیین‌شده (ارث‌بری‌شده از تیکت اصلی) اضافه می‌کنه، بدون هیچ‌کدوم
// از این دو کار. این عمداً درسته: انتقال وضعیت Trailing از تیکت اصلی به تیکت باقیمونده‌ی
// Half Close یک فعال‌سازی جدید نیست - همون معامله‌ست، فقط حجمش کمتر شده؛ SL باید دقیقاً از
// همون جایی که بود ادامه پیدا کنه، و CheckPrematureAction قبلاً یک‌بار (لحظه‌ی فعال‌سازی
// اصلی Trailing روی تیکت اصلی، داخل خودِ AddTrailTicket) اجرا شده - دوباره اجراش برای همون
// تصمیم منطقی نیست.
void InheritTrailTicket(int newTicket, double extreme, int period, datetime lastBar)
{
   if(IsTrailTracked(newTicket)) return; // ایمنی - عملاً نباید پیش بیاد

   ArrayResize(g_trailTickets,  g_trailCount+1);
   ArrayResize(g_trailExtreme,  g_trailCount+1);
   ArrayResize(g_trailPeriod,   g_trailCount+1);
   ArrayResize(g_trailLastBar,  g_trailCount+1);
   g_trailTickets[g_trailCount] = newTicket;
   g_trailExtreme[g_trailCount] = extreme;
   g_trailPeriod[g_trailCount]  = period;
   g_trailLastBar[g_trailCount] = lastBar;
   g_trailCount++;
}

void RemoveTrailTicketAt(int idx)
{
   for(int k=idx; k<g_trailCount-1; k++)
   {
      g_trailTickets[k]  = g_trailTickets[k+1];
      g_trailExtreme[k]  = g_trailExtreme[k+1];  // v12: هم‌ایندکس با g_trailTickets نگه داشته بشه
      g_trailPeriod[k]   = g_trailPeriod[k+1];   // v13
      g_trailLastBar[k]  = g_trailLastBar[k+1];  // v13
   }
   g_trailCount--;
   ArrayResize(g_trailTickets, g_trailCount);
   ArrayResize(g_trailExtreme, g_trailCount);
   ArrayResize(g_trailPeriod,  g_trailCount);
   ArrayResize(g_trailLastBar, g_trailCount);

   // v8 (BUG-009): اگه بعد از این حذف دیگه هیچ معامله‌ای زیر پوشش Trailing نمونده،
   // دکمه‌ی Trailing خودکار به حالت پیش‌فرض (خاموش) برمی‌گرده - دیگه چیزی برای ردیابی نیست
   if(g_trailCount==0 && g_trailingButtonOn)
   {
      g_trailingButtonOn = false;
      UpdateTrailButton();
      SetStatus("Trailing: OFF (trade closed)", C'150,150,150');
   }
}

// v8 (BUG-009 fix #2): حذف فوری یک تیکت مشخص از لیست Trailing - اگه توش بود.
// برخلاف RemoveTrailTicketAt که فقط از داخل RunTrailingUpdate (یک‌بار در هر کندل)
// صدا زده می‌شد، این تابع از CheckClosedTrades() که هر تیک اجرا می‌شه صدا زده می‌شه
// تا خاموش‌شدن دکمه معطل کندل بعدی نمونه.
void RemoveTrailTicket(int ticket)
{
   for(int i=0;i<g_trailCount;i++)
   {
      if(g_trailTickets[i]==ticket)
      {
         RemoveTrailTicketAt(i);
         return;
      }
   }
}

// دکمه‌ی Trailing روشنه: هر معامله‌ی باز (این EA) که هنوز زیر پوشش نیست، اضافه می‌شه
// این باعث می‌شه معاملات جدیدی که بعد از روشن‌شدن دکمه باز می‌شن هم خودکار وارد Trailing بشن
void SyncManualTrailing()
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(OrderStopLoss()<=0) continue;   // بدون SL قابل Trailing نیست
      AddTrailTicket(OrderTicket());
   }
}

// v7 (FEAT-002): اجرای واقعی Trailing - هر تیک صدا زده می‌شه، ولی هر تیکت فقط وقتی واقعاً
// پردازش می‌شه که یه کندل جدید روی تایم‌فریم قفل‌شده‌ی خودش بسته شده باشه (v13).
// v12 (اصلاح باگ منطقی): منطق قبلی حرکت هر کندل رو با کندل قبل از خودش مقایسه می‌کرد - یعنی
// هر نوسان کوچیک داخل یه رنج هم SL رو جلو می‌برد. منطق جدید: برای هر تیکت، بالاترین های
// (خرید) یا پایین‌ترین لو (فروش) از لحظه‌ی شروع ردیابی در g_trailExtreme ذخیره می‌شه. SL فقط
// وقتی جلو می‌ره که کندل تازه‌بسته‌شده واقعاً از این مرجع عبور کرده باشه - دقیقاً به اندازه‌ی
// همون اختلاف - و بعد مرجع خودش هم به‌روز می‌شه.
// v13 (فیکس تایم‌فریم): تایم‌فریم مبنا برای هر تیکت، همونیه که لحظه‌ی شروع Trailing این تیکت
// (در AddTrailTicket) قفل شده - نه تایم‌فریم فعلی چارت. اگه بعداً برای بررسی به تایم‌فریم
// دیگه‌ای بری، محاسبه‌ی این تیکت بی‌صدا عوض نمی‌شه و همچنان با تایم‌فریم اولیه ادامه پیدا می‌کنه.
// v39 (FEAT: Multiple Trailing Modes): تشخیص کندل جدید، انتخاب/حذف تیکت، چک برگشت‌به‌عقب،
// رعایت Stop Level و اعمال واقعی OrderModify/خط نشانه‌گر - همه مشترک بین دو حالت مونده‌ن؛
// فقط محاسبه‌ی خودِ newSL بر اساس TrailingMode شاخه می‌شه. حالت TRAIL_CANDLE دقیقاً همون
// منطق قبلی (شامل فیکس‌های BUG-015/BUG-016) رو بدون هیچ تغییری اجرا می‌کنه.
void RunTrailingUpdate()
{
   if(g_trailCount<=0) return;

   for(int i=g_trailCount-1; i>=0; i--)
   {
      int tk = g_trailTickets[i];
      if(!OrderSelect(tk, SELECT_BY_TICKET) || OrderCloseTime()>0)
      { RemoveTrailTicketAt(i); continue; }  // بسته شده - از لیست حذف

      // v13: کندل جدید فقط بر اساس تایم‌فریم قفل‌شده‌ی همین تیکت تشخیص داده می‌شه
      datetime curBarTime = iTime(Symbol(), g_trailPeriod[i], 0);
      if(curBarTime == g_trailLastBar[i]) continue;  // هنوز کندل جدیدی روی تایم‌فریم این تیکت بسته نشده
      g_trailLastBar[i] = curBarTime;

      bool buy   = (OrderType()==OP_BUY);
      double curSL = OrderStopLoss();
      if(curSL<=0) { RemoveTrailTicketAt(i); continue; }

      double newSL = 0;

      if(TrailingMode == TRAIL_CANDLE)
      {
         // v13: های/لوی کندلی که روی تایم‌فریم قفل‌شده‌ی این تیکت همین الان بسته شد
         double candleExtreme = buy ? iHigh(Symbol(), g_trailPeriod[i], 1) : iLow(Symbol(), g_trailPeriod[i], 1);

         bool madeNewExtreme = buy ? (candleExtreme > g_trailExtreme[i]) : (candleExtreme < g_trailExtreme[i]);
         if(!madeNewExtreme) continue;  // فقط نوسان داخل رنج قبلی بوده - SL دست نمی‌خوره

         double movement = MathAbs(candleExtreme - g_trailExtreme[i]);
         g_trailExtreme[i] = candleExtreme;  // مرجع جدید ثبت بشه، صرف‌نظر از اینکه SL بتونه جابه‌جا بشه یا نه

         newSL = NormalizeDouble(buy ? curSL+movement : curSL-movement, Digits);
      }
      else // TRAIL_EMA
      {
         // v39: EMA روی همون کندل بسته‌شده و همون تایم‌فریم قفل‌شده‌ی این تیکت (دقیقاً الگوی
         // g_trailPeriod[] موجود) - SL به مقدار EMA نزدیک می‌شه، ولی فقط در جهت سود پوزیشن
         // (چک برگشت‌به‌عقب پایین‌تر، مشترک با حالت Candle، همینو تضمین می‌کنه).
         double emaVal = iMA(Symbol(), g_trailPeriod[i], TrailingEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
         if(emaVal<=0) continue;  // EMA هنوز داده‌ی کافی نداره (مثلاً بلافاصله بعد از EA attach)
         newSL = NormalizeDouble(emaVal, Digits);
      }

      // هرگز به عقب برنگرده (چک ایمنی اضافه) - مشترک بین هر دو حالت
      if(buy  && newSL<=curSL) continue;
      if(!buy && newSL>=curSL) continue;

      // v7: رعایت حداقل فاصله‌ی مجاز بروکر (Stop Level) - اگه رعایت نشه، این کندل رد می‌شه
      // و منتظر کندل بعدی می‌مونیم (بدون تلاش برای نزدیک‌ترین مقدار مجاز)
      double stopLevel  = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
      double curPrice   = buy ? Bid : Ask;
      double distToPrice = buy ? (curPrice-newSL) : (newSL-curPrice);
      if(stopLevel>0 && distToPrice<stopLevel) continue;

      if(!OrderModify(tk, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrTeal))
         Print("RunTrailingUpdate: OrderModify failed for ticket ", tk, " (error ", GetLastError(), "), will retry next bar");
      else
         HLine(TrailLineName(tk), newSL, clrTeal, 1, STYLE_DOT); // v8 (BUG-010): خط نشانه‌گر Trailing - با شماره‌ی تیکت شناسایی می‌شه
   }
}

// v42 (Punch List, Part 5, BUG-035): the existing g_trailCount==0 reset inside RemoveTrailTicketAt()
// (BUG-009, v8) only fires at the exact moment a removal happens - Mahmoud's live testing found a
// case (full close, no remainder ticket) where g_trailingButtonOn was observed staying ON afterward,
// which then silently swept the NEXT unrelated trade into Trailing via the "if(g_trailingButtonOn)
// SyncManualTrailing()" line in OnTick() - the trader never asked for that. This is a per-tick
// consistency safety net, independent of which removal path ran (or didn't): if the button is ON
// but nothing is actually left to trail, force it off. Note this is explicitly narrower than the
// Half Close case Mahmoud called out as already correct - when a remainder ticket exists,
// g_trailCount stays >0 (nothing to reset) and this function does nothing.
void EnsureTrailingReset()
{
   if(g_trailingButtonOn && g_trailCount==0)
   {
      g_trailingButtonOn = false;
      UpdateTrailButton();
      SetStatus("Trailing: OFF (trade closed)", C'150,150,150');
   }
}
