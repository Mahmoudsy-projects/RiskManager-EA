//+------------------------------------------------------------------+
//| RM_Reports.mqh                                                     |
//| Risk Manager EA - Trading Reports Stats (Architecture Refactor, R7)|
//| استخراج‌شده از RiskManager_EA_v45_R6.mq4 - CalcTradingReportStats()، |
//| موتور آماری درایور "Trading Reports" (Win Rate/Profit Factor/Avg    |
//| R:R/Expectancy/Drawdown/Trade Count)، امضای کامل دست‌نخورده. هیچ     |
//| global اختصاصی‌ای نداره - g_reportsDrawerOpen/g_reportsPeriod حالت   |
//| UI درایورن (نه دیتای این تابع) و در فایل اصلی/Dashboard می‌مونن.     |
//| صرفاً جابه‌جایی کد، بدون تغییر مقدار/رفتار (Golden Rule فاز R7).      |
//+------------------------------------------------------------------+

// === v35 (Utility Phase A, Part 2): shared scan function for the "Trading Reports" drawer. New
// function, built alongside (not by refactoring) CalcNetResultR/CalcNetResultRB/CalcNetResultPercent
// above - reuses the same OrdersHistoryTotal()/MODE_HISTORY filter pattern (MagicNumber,
// OrderCloseTime()>=periodStart, OP_BUY/OP_SELL only) those three already use, per Mahmoud's
// explicit request to keep this addition low-risk and NOT touch the three existing functions.
// One deliberate difference: this loop runs OLDEST-FIRST (ascending SELECT_BY_POS index), not
// newest-first like the other three - needed so the running R curve used for the Drawdown metric
// is built in chronological order. Order doesn't matter for the other three (they only sum), so
// this isn't "the same loop", just the same filter conditions.
//
// All six output metrics are purely statistical/derived - nothing here is written to a
// GlobalVariable or any other persisted store, and nothing here feeds the existing Weekly/Monthly
// DD lock system (GetWeeklyDrawdown()/GetMonthlyDrawdown()/CheckDrawdownLimits() are untouched).
//
// R-based metrics (Avg R:R, Expectancy, Drawdown) can only be computed for tickets that still have
// a Trade Snapshot (g_snapRiskUSD>0) - same conservative fallback already used by CalcNetResultR:
// a closed trade from before Snapshot tracking existed (or with a corrupted/zero snapshot) is simply
// excluded from those three, exactly like it's excluded from Daily/Weekly/Monthly R today. Win
// Rate/Profit Factor/Trade Count don't depend on the Snapshot at all - they use OrderProfit()+
// OrderSwap()+OrderCommission() directly, so they cover every closed trade in the period regardless
// of Snapshot availability.
//
// Avg R:R is the realized PAYOFF RATIO (average winning trade's R : average losing trade's R),
// intentionally NOT the same figure as Expectancy - Expectancy folds win rate into the number,
// Avg R:R deliberately does not, so the two boxes on the dashboard never show a duplicate value.
// Expectancy is reported in R (not $) - a $ expectancy would drift with account balance/lot sizing
// choices (Half Risk, position size changes) the same way raw $ P/L already does elsewhere on this
// panel, whereas R already accounts for that (see CalcNetResultR's own header comment) - so R is
// the more directly comparable figure across trades of different risk size, and matches the
// existing R/RB convention already established by the Performance box above.
//
// v45 (Punch List Round 3, Item 4 - BUG-037): MT4's own partial-close behavior writes a Half Close
// into history as TWO SEPARATE ROWS THAT SHARE THE SAME OrderTicket() (one row for the portion that
// got closed, one for whatever's left when the remainder is later closed too) - this loop used to
// treat every history row as its own trade, so a single Half-Closed position silently counted as 2
// trades toward Trade Count/Win Rate/the R-curve. On an account with dozens of trades this just
// blends in (a couple of split rows lost in the noise); on a brand-new account where the ENTIRE
// sample is that one Half-Closed position, it reads back as the same trade's numbers effectively
// duplicated (the exact "-1.00R -1.00R"-style report Mahmoud flagged) - which is why the 32-trade
// account looked fine and the 1-trade account didn't. Fix: history rows are first collapsed by
// ticket (summing their $ results) into one logical trade per ticket, oldest-first by close time,
// and every metric below is computed from that deduplicated list instead of the raw row list.
//
// v45 (Punch List Round 3, Item 5): alongside the existing R-based drawdown curve, a second $-based
// curve (cumUSD/peakUSD/maxDDUSD) is built in the same pass - same peak-to-trough logic, just in $
// instead of R. maxDrawdownPct converts that $ figure to % against the SAME period-start balance
// basis GetWeeklyDrawdown()/GetMonthlyDrawdown() already use (not a flat R-to-% conversion, which
// would use the wrong denominator - R is normalized to a single trade's risk, % needs to be
// normalized to account balance, and those two are not interchangeable).
void CalcTradingReportStats(datetime periodStart, double periodStartBalance, double &winRatePct, double &profitFactor,
                             double &avgRR, double &expectancyR, double &maxDrawdownR, double &maxDrawdownPct, int &tradeCount)
{
   // --- Pass 1: collapse raw history rows into one logical trade per CHAIN (v87 - FEAT-042 فاز ۲; BUG-037 قبلاً per-ticket) ---
   // کلید یکی‌سازی = GetRootTicket(تیکت): Half Close پشت‌سرهم یک زنجیره = یک معامله. معامله‌ی تکی (ریشه = خودش) دقیقاً مثل قبل.
   // dedupTickets[] حالا ریشه‌ی زنجیره را نگه می‌دارد؛ Snapshot ریشه همان RiskUSD کاملِ مشترک همه‌ی بخش‌هاست.
   int      dedupTickets[];    ArrayResize(dedupTickets, 0);
   double   dedupNetUSD[];     ArrayResize(dedupNetUSD, 0);
   datetime dedupCloseTime[];  ArrayResize(dedupCloseTime, 0);
   int      dedupCount = 0;

   int total = OrdersHistoryTotal();
   for(int i=0; i<total; i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderCloseTime()<periodStart) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;

      int    ticket = GetRootTicket(OrderTicket());
      double netUSD = OrderProfit()+OrderSwap()+OrderCommission();
      datetime ct   = OrderCloseTime();

      int found = -1;
      for(int k=0;k<dedupCount;k++)
         if(dedupTickets[k]==ticket) { found=k; break; }

      if(found>=0)
      {
         dedupNetUSD[found] += netUSD;  // بخش‌های یک زنجیره (یا ردیف‌های هم‌تیکت MT4) - سود خالص مجموع
         if(ct > dedupCloseTime[found]) dedupCloseTime[found] = ct;  // زمان بسته‌شدن = آخرین بخش
      }
      else
      {
         ArrayResize(dedupTickets,   dedupCount+1);
         ArrayResize(dedupNetUSD,    dedupCount+1);
         ArrayResize(dedupCloseTime, dedupCount+1);
         dedupTickets[dedupCount]   = ticket;
         dedupNetUSD[dedupCount]    = netUSD;
         dedupCloseTime[dedupCount] = ct;
         dedupCount++;
      }
   }

   // v87: بخش‌هایی از یک زنجیره که «قبل از» شروع بازه بسته شده‌اند (مثلاً Half Close دیشب، باقی‌مانده امروز) در حلقه‌ی بالا رد شده‌اند.
   // زنجیره‌ای که آخرین بخشش داخل بازه بسته شده، باید سود خالص «کلِ» زنجیره را داشته باشد - اعضا از Snapshot (ریشه‌ی مشترک) پیدا و
   // با OrderSelect بر اساس تیکت اضافه می‌شوند. فقط برای زنجیره‌های چندتیکتی اجرا می‌شود (هزینه‌ی ناچیز).
   for(int g=0; g<dedupCount; g++)
   {
      if(ChainMemberCount(dedupTickets[g]) <= 1) continue;
      for(int m=0; m<g_snapCount; m++)
      {
         int rm = (g_snapRootTicket[m] > 0) ? g_snapRootTicket[m] : g_snapTickets[m];
         if(rm != dedupTickets[g]) continue;
         if(!OrderSelect(g_snapTickets[m], SELECT_BY_TICKET, MODE_HISTORY)) continue;
         if(OrderCloseTime() <= 0 || OrderCloseTime() >= periodStart) continue;  // بخش‌های داخل بازه قبلاً جمع شده‌اند
         dedupNetUSD[g] += OrderProfit()+OrderSwap()+OrderCommission();
      }
   }

   // v87: زنجیره‌ی نیمه‌باز (حتی یک تیکت باز با همین ریشه - شامل Pending) در هیچ آماری نمی‌آید تا آخرین بخش بسته شود.
   {
      int keep = 0;
      for(int c=0; c<dedupCount; c++)
      {
         if(!IsChainFullyClosed(dedupTickets[c])) continue;
         dedupTickets[keep]   = dedupTickets[c];
         dedupNetUSD[keep]    = dedupNetUSD[c];
         dedupCloseTime[keep] = dedupCloseTime[c];
         keep++;
      }
      dedupCount = keep;
      ArrayResize(dedupTickets,   dedupCount);
      ArrayResize(dedupNetUSD,    dedupCount);
      ArrayResize(dedupCloseTime, dedupCount);
   }

   // oldest-first by close time - insertion sort (trade counts here are small; simplicity over
   // speed) - needed so the running R/$ curves below are built in chronological order.
   for(int a=1;a<dedupCount;a++)
   {
      int      tTicket = dedupTickets[a];
      double   tNet     = dedupNetUSD[a];
      datetime tClose   = dedupCloseTime[a];
      int b = a-1;
      while(b>=0 && dedupCloseTime[b]>tClose)
      {
         dedupTickets[b+1]   = dedupTickets[b];
         dedupNetUSD[b+1]    = dedupNetUSD[b];
         dedupCloseTime[b+1] = dedupCloseTime[b];
         b--;
      }
      dedupTickets[b+1]   = tTicket;
      dedupNetUSD[b+1]    = tNet;
      dedupCloseTime[b+1] = tClose;
   }

   // --- Pass 2: same statistics as before, now over the deduplicated logical-trade list ---
   tradeCount = 0;
   int    wins       = 0;
   double sumWinUSD  = 0, sumLossUSD = 0;  // $ basis - Win Rate/Profit Factor need no Snapshot

   int    winRCount  = 0, lossRCount = 0;  // R basis - Snapshot-dependent subset
   double sumWinR    = 0, sumLossR   = 0;  // sumLossR kept as a positive magnitude
   double cumR       = 0, peakR      = 0, maxDD    = 0;
   double cumUSD     = 0, peakUSD    = 0, maxDDUSD = 0;  // v45 (Item 5): parallel $ curve for the % figure

   for(int j=0;j<dedupCount;j++)
   {
      double netUSD = dedupNetUSD[j];
      tradeCount++;
      if(netUSD>0)      { wins++; sumWinUSD += netUSD; }
      else if(netUSD<0) { sumLossUSD += -netUSD; }
      // breakeven (netUSD==0) trades count toward Trade Count only, same as every other metric here

      cumUSD += netUSD;
      if(cumUSD>peakUSD) peakUSD = cumUSD;
      double ddUSD = peakUSD-cumUSD;
      if(ddUSD>maxDDUSD) maxDDUSD = ddUSD;

      int idx = FindSnapshotIndex(dedupTickets[j]);
      if(idx<0 || SnapRiskBase(idx)<=0) continue;  // no Snapshot - excluded from every R-based metric below, same fallback as CalcNetResultR

      // v90 (FEAT-044): idx = Snapshot «ریشه»ی زنجیره؛ پایه‌ی R = RiskBaseUSD آن (برای معامله‌ی عادی/ریشه = RiskUSD خودش، عدد قبلی بدون تغییر).
      double tradeR = netUSD/SnapRiskBase(idx);
      if(tradeR>0)      { winRCount++;  sumWinR  += tradeR; }
      else if(tradeR<0) { lossRCount++; sumLossR += -tradeR; }

      cumR += tradeR;
      if(cumR>peakR) peakR = cumR;
      double dd = peakR-cumR;
      if(dd>maxDD) maxDD = dd;
   }

   winRatePct = (tradeCount>0) ? 100.0*wins/tradeCount : 0.0;
   if(sumLossUSD>0)      profitFactor = sumWinUSD/sumLossUSD;
   else if(sumWinUSD>0)  profitFactor = -1.0;  // sentinel: no losing trades at all - "infinite" PF, formatted separately by the caller
   else                  profitFactor = 0.0;

   double avgWinR  = (winRCount>0)  ? sumWinR/winRCount   : 0.0;
   double avgLossR = (lossRCount>0) ? sumLossR/lossRCount : 0.0;
   avgRR = (avgLossR>0) ? avgWinR/avgLossR : 0.0;  // payoff ratio - 0 means "no losing trades in period yet, ratio undefined"

   int rCount = winRCount+lossRCount;
   // Expectancy = (Win% x AvgWinR) - (Loss% x AvgLossR), over the Snapshot-valid subset only -
   // matches the formula from spec exactly; mathematically equal to (sumWinR-sumLossR)/rCount, but
   // written out explicitly here to match the spec's formula rather than a shortcut.
   expectancyR = (rCount>0)
                 ? ((double)winRCount/rCount)*avgWinR - ((double)lossRCount/rCount)*avgLossR
                 : 0.0;

   maxDrawdownR   = maxDD;     // always >= 0 - caller renders it as a negative figure
   maxDrawdownPct = (periodStartBalance>0) ? maxDDUSD/periodStartBalance*100.0 : 0.0;  // v45 (Item 5) - always >= 0, same convention as maxDrawdownR
}

//+------------------------------------------------------------------+
// v55 (CSV Export - Trade Journal پایه): خروجی خام CSV از معاملات بسته‌شده به MQL4/Files.
// این صرفاً یک لایه‌ی خواندن-و-نوشتن روی داده‌ی موجوده (Trade Snapshot + تاریخچه‌ی سفارش‌ها) -
// هیچ تغییری در منطق ریسک/محاسبات/شمارنده‌های رفتاری موجود نمی‌ده و هیچ GlobalVariable‌ای
// نمی‌نویسه/تغییر نمی‌ده.
//
// طبقه‌بندی SL/TP/EarlyExit اینجا mirror می‌کنه (read-only) همون منطق hitSL/hitTP/reached1R که
// CheckClosedTrades() (RM_CooldownEngine.mqh) از قبل استفاده می‌کنه: origDist/oneR/tolPrice از
// روی Trade Snapshot همون تیکت (immutable - هیچ‌وقت با BE/Trailing عوض نمی‌شه)، hitSL/hitTP
// خالص بر مبنای فاصله‌ی قیمت (نه $) با همون تلورانس ۱۰٪ (v52، BUG-045). تنها تفاوت: اونجا
// slPrice از g_trackedSL (mirror زنده‌ی SL در لحظه‌ی بسته‌شدن) میاد، اینجا چون این تابع می‌تونه
// معاملات بسته‌شده‌ی خیلی قدیمی‌تر (خارج از عمر همین سشن EA) رو هم پوشش بده، مستقیم از
// OrderStopLoss()/OrderTakeProfit() تاریخچه خونده می‌شه - همون مقداری که در لحظه‌ی بسته‌شدن
// روی سفارش بوده، پس معادل همون mirror زنده‌ست.
//
// فیلتر فقط بر اساس MagicNumber است (نه Symbol()) - همون قرارداد CalcTradingReportStats بالا
// (تیکت‌ها در کل حساب یکتان طبق RM_Snapshot.mqh، پس این EA می‌تونه معاملات چند نماد رو زیر
// همین Magic پوشش بده؛ به همین خاطر ستون Symbol هم در CSV هست).
//
// بدون Trade Snapshot معتبر برای یک تیکت (معامله‌ی خیلی قدیمی، قبل از نصب v11) - همون فال‌بک
// محافظه‌کارانه‌ی CalcTradingReportStats: TradeR/RiskUSD/RiskPct خالی می‌مونن و Result برابر
// "N/A" می‌شه (به‌جای حدس زدن با یه مبنای غیرقابل‌اعتماد).
//
// هر ردیف خامِ MODE_HISTORY (نه هر تیکت منحصربه‌فرد) یک ردیف CSV می‌شه - برخلاف
// CalcTradingReportStats که ردیف‌های Half Close با تیکت مشترک رو جمع می‌کنه (BUG-037)، اینجا
// عمداً جمع نمی‌شن چون این یه Export خام سطح-سفارش برای مصرف بیرونی (فاز C) است، نه یه آمار
// تجمعی سطح-معامله - هر ردیف تاریخچه، دقیقاً همون‌طور که MT4 ذخیره‌اش کرده، یک ردیف CSV می‌شه.
//
// v56 (Trade Tagging - Strategy/Setup): دو ستون آخر (Strategy/Setup) از یه نگاشت کاملاً مستقل
// از Snapshot میان - GetTagStrategy()/GetTagSetup() (RM_Tools.mqh)، که خودشون از فایل جدای
// RM_TradeTags.csv می‌خونن (نه از OrderComment - چون OrderComment بعد از close قابل ادیت نیست).
// برای تیکت‌های تگ‌نخورده -> "N/A"، هم‌راستا با فال‌بک "بدون Snapshot معتبر" بالا.
// v57 (BUG-047 - فیکس نام‌گذاری): قبلاً هر export یه فایل جدید با timestamp می‌ساخت
// (RM_TradeJournal_<Magic>_<timestamp>.csv) - چون هر export کل تاریخچه رو از نو می‌نویسه (نه
// فقط معاملات جدید)، این یعنی پوشه با هر کلیک پر از فایل‌های تکراری/قدیمی می‌شد. فیکس: اسم ثابت
// بدون timestamp - همیشه همون فایل overwrite می‌شه. چون محتوا هر بار کامل بازسازی می‌شه، از دست
// دادن نسخه‌ی قبلی هیچ داده‌ای رو از بین نمی‌بره.
bool ExportTradeJournalCSV(string &outFilename)
{
   // v101 (BUG-054): خروجی فایل کامل از حافظه‌ی همین نمونه ساخته می‌شود؛ اگر Snapshot/تگِ تیکتی روی چارت دیگر ساخته شده و هنوز
   // sync نشده بود، ردیفش «خالی/N/A» می‌رفت و فایل خوبِ نمونه‌ی دیگر را بازنویسی می‌کرد. قبل از ساخت فایل (رویداد، نه هر تیک) sync.
   RM_SyncSnapshotsFromGV();
   RM_SyncTagsIfChanged();
   string filename = "RM_TradeJournal_" + IntegerToString(MagicNumber) + ".csv";

   int handle = FileOpen(filename, FILE_CSV|FILE_WRITE, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("RM_Reports: ExportTradeJournalCSV - FileOpen failed, error ", GetLastError());
      return false;
   }

   // v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله - اولین از سه ورژن): شش ستون جدید در انتها
   // اضافه شدن - ترتیب/محتوای ستون‌های موجود دست‌نخورده می‌مونه.
   // v64 (شش مورد مستقل): چهار ستون داده‌ای جدید در انتها - PriorDayResult (آیتم ۱)، ProfitUSD
   // (آیتم ۲)، SLLoosenedCount (آیتم ۳)، BehaviorErrorsThisTrade (آیتم ۴، با فیکس آیتم ۵)،
   // TimeframeAtOpen (آیتم ۶) - باز هم ترتیب/محتوای ستون‌های موجود دست‌نخورده.
   // v66 (آیتم ۲الف/ب): دو ستون جدید دیگه در انتها - MaxFavR (فیلد موجود از فاز A، فقط حالا
   // expose شده به CSV، صفر منطق جدید) و MinFavR (فیلد جدید، قرینه‌ی MAE). هر دو تیک‌به‌تیک،
   // فقط تا لحظه‌ی بسته‌شدن معامله - هیچ محاسبه‌ای بعد از close.
   // v69 (FEAT-026 - Mental State Tag): یه ستون دیگه در انتهای همه‌چیز - ترتیب/محتوای ستون‌های
   // موجود دست‌نخورده می‌مونه، هم‌رده‌ی همون قرارداد v61/v64/v66 بالا.
   // FEAT-037 (v81 - چک‌لیست کانتکست): پنج ستون دیگه در انتهای همه‌چیز - از یه نگاشت کاملاً مستقل
   // میان (GetCtxLevelStr/GetCtxCycleStr/GetCtxTimeStr/GetCtxCandleStr/GetCtxNoneStr، RM_Tools.mqh)،
   // که خودشون از فایل جدای RM_ContextTags.csv می‌خونن (مستقل از RM_TradeTags.csv/Strategy/Setup).
   // برای تیکت‌هایی که این مرحله انجام نشده -> "false" (طبق تسک، نه "N/A" - این ۵ فیلد Boolean‌ان،
   // نه رشته‌ی انتخابی مثل Strategy/Setup).
   // BUG-052/FEAT-036 (v82): هشت ستون دیگه در انتهای همه‌چیز - ترتیب/محتوای ستون‌های موجود
   // دست‌نخورده می‌مونه، هم‌قرارداد نسخه‌های قبلی بالا.
   FileWrite(handle, "Ticket","Symbol","Direction","OpenTime","CloseTime","Lots","Entry","SL",
             "ClosePrice","RiskUSD","RiskPct","TradeR","WasHalfRisk","Result","Strategy","Setup","Session","Screenshot",
             "BehaviorErrorCountAtOpen","OpenedDuringCooldownLock","EntryIntervalViolation","SLTamperedFlag",
             "DailyRiskUsedPctAtOpen","WeeklyDDUsedPctAtOpen",
             "PriorDayResult","ProfitUSD","SLLoosenedCount","BehaviorErrorsThisTrade","TimeframeAtOpen",
             "MaxFavR","MinFavR","MentalState",
             "ContextLevelOK","ContextCycleClarityOK","ContextTimeOK","ContextCandleConfirmOK","ContextNone",
             "SL_Final","TP_Final","Slippage_USD","Slippage_R","CloseReason_Server","Spread_AtClose","ServerHour_Close","IsEAManaged",
             "RiskStepWeight",
             "RootTicket");  // v86 (FEAT-042 فاز ۱): ستون جدید فقط در انتها (قرارداد FEAT-036)؛ v84 (FEAT-038 Addendum): ستون جدید فقط در انتها - ترتیب/محتوای ستون‌های قبلی (از جمله WasHalfRisk) دست‌نخورده

   int total = OrdersHistoryTotal();
   for(int i=0; i<total; i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue; // v55: same OP_BUY/OP_SELL-only filter as CalcTradingReportStats above (excludes balance/credit history rows)

      int      ticket     = OrderTicket();
      string   sym        = OrderSymbol();
      bool     isBuy      = (OrderType()==OP_BUY);
      datetime openTime   = OrderOpenTime();
      datetime closeTime  = OrderCloseTime();
      double   lots       = OrderLots();
      double   openPrice  = OrderOpenPrice();
      double   slPrice    = OrderStopLoss();
      double   tpPrice    = OrderTakeProfit();
      double   closePrice = OrderClosePrice();
      double   profit     = OrderProfit()+OrderSwap()+OrderCommission();

      int symDigits = (int)MarketInfo(sym, MODE_DIGITS);
      if(symDigits<=0) symDigits = Digits; // فال‌بک محافظه‌کارانه اگه MarketInfo نتونه جواب بده

      double riskUSD = 0.0, riskPct = 0.0, tradeR = 0.0;
      bool   wasHalfRisk = false;
      double riskStepWeight = 1.0;  // v84 (FEAT-038 Addendum)
      string tradeRStr   = "N/A";
      string result      = "N/A";

      // FEAT-036 (v82): مقدار پیش‌فرض N/A - فقط وقتی Result واقعاً SL یا TP باشه (+ Snapshot/
      // origDist معتبر) پایین‌تر پر می‌شن.
      double slippageUSD = 0.0, slippageR = 0.0;
      bool   slippageValid = false;

      int snapIdx = FindSnapshotIndex(ticket);
      if(snapIdx>=0 && MathAbs(g_snapEntry[snapIdx]-g_snapSL[snapIdx])>0)
      {
         riskUSD     = g_snapRiskUSD[snapIdx];
         riskPct     = g_snapRiskPct[snapIdx];
         wasHalfRisk = g_snapWasHalfRisk[snapIdx];
         riskStepWeight = SnapRiskWeight(snapIdx);  // v84 (FEAT-038 Addendum)

         double origDist = MathAbs(g_snapEntry[snapIdx]-g_snapSL[snapIdx]); // ثابت، هیچ‌وقت با BE/Trailing کوچیک نمی‌شه
         double tolPrice = origDist*0.10;
         // BUG-052 (v82 fix): mirror دقیق فیکس جهت‌دار CheckClosedTrades (RM_CooldownEngine.mqh) -
         // قبلاً |close-SL|<=tol بدون جهت بود، پس استاپ‌های اسلیپ‌خورده (آن‌سوی SL) به‌غلط
         // EarlyExit می‌شدن. حالا: «روی یا آن‌سوی SL» = SL؛ فقط جهت مخالف (بهتر از سطح) نه.
         bool   hitSL    = isBuy ? (closePrice <= slPrice + tolPrice)
                                  : (closePrice >= slPrice - tolPrice);

         bool hitTP = false;
         if(tpPrice>0)
         {
            double tpDist = MathAbs(tpPrice-openPrice);
            double tpTol  = tpDist*0.10;
            // BUG-052 (v82 fix): قرینه‌ی فیکس SL - «روی یا آن‌سوی TP» = TP
            hitTP = isBuy ? (closePrice >= tpPrice - tpTol)
                          : (closePrice <= tpPrice + tpTol);
         }

         bool reached1R = (riskUSD>0 && profit >= riskUSD*0.95);

         if(riskUSD>0)
         {
            tradeR    = profit/riskUSD;
            tradeRStr = DoubleToString(tradeR,2);
         }

         if(hitSL && !hitTP)         result = "SL";
         else if(hitTP || reached1R) result = "TP";
         else                        result = "EarlyExit";

         // FEAT-036 (v82): Slippage_USD/Slippage_R - اختلاف جهت‌دار ClosePrice با سطحی که واقعاً
         // Result رو تعیین کرد (SL یا TP)؛ مثبت = بدتر از همون سطح. برای EarlyExit/بدون سطح مشخص
         // (و بدون origDist معتبر) معنا نداره - پایین‌تر (بعد از این بلوک) "N/A" می‌مونه.
         if(origDist>0 && riskUSD>0 && (result=="SL" || result=="TP"))
         {
            double level = (result=="SL") ? slPrice : tpPrice;
            double dollarPerUnit = riskUSD/origDist; // همون ثابت $-به-ازای-واحد-قیمت که CheckClosedTrades استفاده می‌کنه
            double slipPriceSigned = isBuy ? (level-closePrice) : (closePrice-level); // مثبت=بدتر از سطح
            slippageUSD   = slipPriceSigned*dollarPerUnit;
            slippageR     = slippageUSD/riskUSD;
            slippageValid = true;
         }
      }

      // v62 (تفکیک ExitReason - EmergencyClose در برابر خروج دستی): این چک عمداً *بعد* از بلوک
      // بالا و مستقل از snapIdx است - اگه EmergencyCloseAll() (Floating DD Protection) این تیکت
      // رو بسته باشه، Result همیشه "EmergencyClose" می‌شه، حتی اگه قیمت بسته‌شدن به‌طور تصادفی
      // نزدیک SL/TP بوده باشه (چون دلیل واقعی بسته‌شدن اقدام حفاظتی سیستم بوده، نه SL/TP/تصمیم
      // تریدر) - فقط همین ستون CSV رو عوض می‌کنه، هیچ اثری روی hitSL/hitTP بالا یا شمارنده‌های
      // Market/Behavior Cooldown (که در CheckClosedTrades، RM_CooldownEngine.mqh، دست‌نخورده
      // موندن) نداره.
      if(WasEmergencyClosed(ticket)) result = "EmergencyClose";

      // v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله): برخلاف بلوک بالا که علاوه‌بر snapIdx>=0
      // به فاصله‌ی معتبر Entry/SL هم نیاز داره (برای طبقه‌بندی SL/TP)، این شش فیلد کاملاً
      // مستقل از اون فاصله‌ان - فقط به وجود یک Snapshot معتبر برای این تیکت نیاز دارن.
      string behErrStr     = "N/A";
      string duringLockStr = "N/A";
      string intervalStr   = "N/A";
      string tamperStr     = "N/A";
      string dailyPctStr   = "N/A";
      string weeklyPctStr  = "N/A";
      if(snapIdx>=0)
      {
         behErrStr     = DoubleToString(g_snapBehaviorErrorCountAtOpen[snapIdx], 0);
         duringLockStr = g_snapOpenedDuringCooldownLock[snapIdx] ? "true" : "false";
         intervalStr   = g_snapEntryIntervalViolation[snapIdx]   ? "true" : "false";
         tamperStr     = g_snapSLTampered[snapIdx]                ? "true" : "false";
         dailyPctStr   = DoubleToString(g_snapDailyRiskUsedPctAtOpen[snapIdx], 2);
         weeklyPctStr  = DoubleToString(g_snapWeeklyDDUsedPctAtOpen[snapIdx], 2);
      }

      // v64 (آیتم ۱ - PriorDayResult / آیتم ۳ - SLLoosenedCount): همون فال‌بک "بدون Snapshot
      // معتبر -> N/A" بالا. آیتم ۲ (ProfitUSD) این‌جا نیست چون مستقل از Snapshot است - از روی
      // `profit` بالا (که از قبل برای Result/TradeR محاسبه شده) مستقیم خونده می‌شه.
      string priorDayResultStr = "N/A";
      string slLoosenedStr     = "N/A";
      if(snapIdx>=0)
      {
         priorDayResultStr = PriorDayResultCodeToString(g_snapPriorDayResult[snapIdx]);
         slLoosenedStr     = IntegerToString(g_snapSLLoosenedCount[snapIdx]);
      }

      // v64 (آیتم ۴ - BehaviorErrorsThisTrade): سنتینل -1 یعنی این تیکت هیچ‌وقت با v64+ بسته
      // نشده (تاریخی/هنوز باز/بدون Snapshot معتبر) - محافظه‌کارانه N/A، نه یه عدد حدسی.
      string behErrThisTradeStr = "N/A";
      if(snapIdx>=0 && g_snapBehaviorErrorsThisTrade[snapIdx] >= 0)
         behErrThisTradeStr = DoubleToString(g_snapBehaviorErrorsThisTrade[snapIdx], 0);

      // v64 (آیتم ۶ - TimeframeAtOpen):
      string timeframeAtOpenStr = "N/A";
      if(snapIdx>=0)
         timeframeAtOpenStr = TimeframeCodeToString(g_snapTimeframeAtOpen[snapIdx]);

      // v66 (آیتم ۲الف/ب - MaxFavR/MinFavR): همون فال‌بک «بدون Snapshot معتبر -> N/A» بالا.
      // MaxFavR از قبل (v18، BUG-021) وجود داشت، فقط الان expose می‌شه؛ MinFavR کاملاً جدیده،
      // ولی از همون آرایه/مکانیزم تیک‌به‌تیک می‌خونه - هیچ محاسبه‌ای اینجا (لحظه‌ی export) انجام
      // نمی‌شه، فقط مقدار از قبل ذخیره‌شده خونده می‌شه.
      string maxFavRStr = "N/A";
      string minFavRStr = "N/A";
      if(snapIdx>=0)
      {
         maxFavRStr = DoubleToString(g_snapMaxFavR[snapIdx], 2);
         minFavRStr = DoubleToString(g_snapMinFavR[snapIdx], 2);
      }

      // FEAT-036 (v82): هفت ستون جدید - همه در انتهای همه‌چیز اضافه می‌شن (ترتیب/محتوای ستون‌های
      // موجود دست‌نخورده، هم‌قرارداد v61/v64/v66/v69/FEAT-037 بالا).
      //
      // SL_Final/TP_Final: صرفاً همون slPrice/tpPrice بالا (از OrderStopLoss/OrderTakeProfit
      // تاریخچه خونده شدن که از قبل، طبق خودِ MT4، آخرین مقدار ثبت‌شده قبل از بسته‌شدنه - یعنی
      // اگه AutoBE/Trailing/دستی SL رو جابه‌جا کرده باشن، این دو ستون خودشون به‌روز اومدن؛ هیچ
      // ردیابی جدیدی لازم نبود) - فقط با اسم صریح‌تر، مستقل از ستون قدیمی SL بالا (که دست‌نخورده
      // می‌مونه تا مصرف‌کننده‌های موجود CSV نشکنن).
      string slFinalStr = DoubleToString(slPrice, symDigits);
      string tpFinalStr = (tpPrice>0) ? DoubleToString(tpPrice, symDigits) : "N/A";

      // Slippage_USD/Slippage_R: از بلوک بالا (فقط برای Result==SL/TP با Snapshot معتبر پر شده)
      string slippageUSDStr = slippageValid ? DoubleToString(slippageUSD,2) : "N/A";
      string slippageRStr   = slippageValid ? DoubleToString(slippageR,2)   : "N/A";

      // CloseReason_Server: تگ کامنت دیل روی خود سفارش - "[sl]"/"[tp]" یا خالی (نه N/A - طبق
      // متن تسک، بستن دستی باید CloseReason_Server خالی داشته باشه، نه N/A)
      string orderCmt = OrderComment();
      string closeReasonServer = "";
      if(StringFind(orderCmt, "[sl]") >= 0)      closeReasonServer = "[sl]";
      else if(StringFind(orderCmt, "[tp]") >= 0) closeReasonServer = "[tp]";

      // Spread_AtClose: مقدار persisted ثبت‌شده توی CheckClosedTrades لحظه‌ی تشخیص بسته‌شدن
      // (RM_CooldownEngine.mqh) - "N/A" اگه این تیکت قبل از نصب v82 بسته شده باشه
      double spreadAtCloseVal;
      string spreadAtCloseStr = GetSpreadAtClose(ticket, spreadAtCloseVal) ? DoubleToString(spreadAtCloseVal, symDigits) : "N/A";

      // ServerHour_Close: مستقیم از closeTime (وقت سرور بروکر - همون مبنایی که بقیه‌ی پروژه،
      // مثل AutoClose At Time، همه‌جا استفاده می‌کنه) - بدون هیچ تبدیل منطقه‌ی زمانی
      string serverHourCloseStr = IntegerToString(TimeHour(closeTime));

      // IsEAManaged: مرز داده‌ی پاک/ناپاک - true فقط وقتی این تیکت واقعاً یک Trade Snapshot معتبر
      // داره (یعنی از AutoExecute این EA باز شده، نه یک اردر دستی/بیرونی با همین Magic Number)
      string isEAManagedStr = (snapIdx>=0) ? "true" : "false";

      FileWrite(handle, ticket, sym, (isBuy ? "Buy" : "Sell"),
                TimeToString(openTime,  TIME_DATE|TIME_SECONDS),
                TimeToString(closeTime, TIME_DATE|TIME_SECONDS),
                DoubleToString(lots,2),
                DoubleToString(openPrice,  symDigits),
                DoubleToString(slPrice,    symDigits),
                DoubleToString(closePrice, symDigits),
                (snapIdx>=0 ? DoubleToString(riskUSD,2) : "N/A"),
                (snapIdx>=0 ? DoubleToString(riskPct,2) : "N/A"),
                tradeRStr,
                (snapIdx>=0 ? (wasHalfRisk ? "true" : "false") : "N/A"),
                result,
                GetTagStrategy(ticket),   // v56 (Trade Tagging): مستقل از Snapshot - "N/A" اگه این تیکت هنوز تگ نخورده (RM_Tools.mqh)
                GetTagSetup(ticket),
                SessionLevel_TagForTime(openTime),  // v58 (Session-entry tagging): Tokyo/London/NewYork/OUT OF TRADING SESSION - بر اساس لحظه‌ی OpenTime، صرفاً یه ستون داده‌ای (RM_Tools.mqh)
                GetExitScreenshotName(ticket),  // v59 (Item 2 - Chart Screenshot at Exit)، v66 (آیتم ۱ - حالا مسیر نسبی کامل شامل زیرپوشه‌ی TRADE SCREENSHOTS) - "N/A" اگه وجود نداره (RM_Tools.mqh)
                behErrStr, duringLockStr, intervalStr, tamperStr, dailyPctStr, weeklyPctStr,  // v61
                priorDayResultStr, DoubleToString(profit,2), slLoosenedStr, behErrThisTradeStr, timeframeAtOpenStr,  // v64 (شش مورد مستقل)
                maxFavRStr, minFavRStr,  // v66 (آیتم ۲الف/ب)
                GetTagMentalState(ticket),  // v69 (FEAT-026): مستقل از Snapshot، مثل GetTagStrategy/GetTagSetup بالا - "N/A" اگه انتخاب نشده بود (RM_Tools.mqh)
                GetCtxLevelStr(ticket), GetCtxCycleStr(ticket), GetCtxTimeStr(ticket), GetCtxCandleStr(ticket), GetCtxNoneStr(ticket),  // FEAT-037 (v81): مستقل از Snapshot/Strategy/Setup - "false" اگه این مرحله انجام نشده بود (RM_Tools.mqh)
                slFinalStr, tpFinalStr, slippageUSDStr, slippageRStr, closeReasonServer, spreadAtCloseStr, serverHourCloseStr, isEAManagedStr,
                (snapIdx>=0 ? DoubleToString(riskStepWeight,3) : "N/A"),
                IntegerToString(GetRootTicket(ticket)));  // v86 (FEAT-042 فاز ۱): RootTicket - هر ردیف همچنان یک تیکت؛ بدون Snapshot/قبل از v86 = خودِ تیکت;  // v84 (FEAT-038 Addendum)  // BUG-052/FEAT-036 (v82)
   }

   FileClose(handle);
   outFilename = filename;
   return true;
}
