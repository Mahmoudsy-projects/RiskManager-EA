//+------------------------------------------------------------------+
//| RM_Reports.mq5                                                     |
//| Risk Manager EA - Trading Reports & Trade Journal (MT5 Port,       |
//| Stage 5b). پورت مستقیم از RM_Reports.mqh (RiskManager EA v70).      |
//| Golden Rule: فرمول‌ها/آستانه‌ها/ترتیب عملیات عوض نشدن - فقط           |
//| فراخوانی‌های API تاریخچه از MT4 به MT5 ترجمه شدن، با همون الگوی      |
//| Stage 4 (HistorySelect + HistoryDealsTotal/HistoryDealGetTicket،    |
//| DEAL_ENTRY_OUT، DEAL_POSITION_ID به‌جای تیکت).                       |
//|                                                                     |
//| [Stage 5b - critical distinction, per task instructions, stated in |
//| my own words] این دو تابع به‌طور عمدی دو رفتار متضاد نسبت به         |
//| تجمیع (dedup) دارن، و این تضاد باید حفظ بشه:                        |
//|                                                                     |
//| CalcTradingReportStats() یک آمار سطح-معامله است (Win Rate, Trade     |
//| Count, R-curve). یک پوزیشن Half-Close-شده، از نظر تریدر، هنوز یک     |
//| «تصمیم معاملاتی» واحده - نه دوتا. BUG-037 دقیقاً همین رو در MT4 حل    |
//| کرد: چون MT4 پارشیال کلوز رو به‌عنوان دو ردیف تاریخچه‌ی جدا (با یک    |
//| OrderTicket مشترک) ذخیره می‌کرد، بدون تجمیع، یک معامله دوبار در       |
//| Trade Count/Win Rate/منحنی R شمرده می‌شد. روی MT5، مسئله دقیقاً       |
//| همینه - فقط شکلش عوض شده: به‌جای «دو ردیف تاریخچه با یک OrderTicket   |
//| مشترک»، الان «چند Deal با یک DEAL_POSITION_ID مشترک» داریم. راه‌حل     |
//| هم مفهوماً یکیه: قبل از محاسبه‌ی هر آماری، همه‌چیز رو بر اساس همون     |
//| شناسه‌ی مشترک (OrderTicket در MT4، DEAL_POSITION_ID در MT5) جمع کن -  |
//| نه یه رویکرد جدید، بلکه ترجمه‌ی مستقیم همون منطق BUG-037 به مدل Deal  |
//| محور MT5 (دقیقاً همون الگویی که Stage 4 برای CheckClosedTrades() جا  |
//| انداخت).                                                             |
//|                                                                     |
//| ExportTradeJournalCSV() برعکسه: یک Export خام سطح-سفارش برای مصرف    |
//| بیرونیه (پایپ‌لاین Excel/Notion)، نه یه آمار تجمعی. هدفش اینه که هر   |
//| «رویداد بسته‌شدن» (چه پارشیال چه نهایی) دقیقاً همون‌طور که واقعاً       |
//| اتفاق افتاده، یک ردیف مستقل بشه - چون مصرف‌کننده‌ی بیرونی (مثلاً یه    |
//| اسپردشیت Excel که هر بسته‌شدن رو جدا می‌خواد ببینه) به جزئیات هر       |
//| رویداد جدا نیاز داره، نه به خلاصه‌ی تجمیع‌شده‌ی معامله. اگه اینجا هم    |
//| مثل تابع بالا تجمیع می‌کردیم، دقیقاً همون داده‌ای که Export قراره       |
//| فراهم کنه (جزئیات هر رویداد بسته‌شدن، جدا از هم) از بین می‌رفت.        |
//| پس روی MT5: هر Deal بسته‌شدن (DEAL_ENTRY_OUT) - چه پارشیال چه نهایی - |
//| دقیقاً یک ردیف CSV می‌شه؛ هیچ تجمیعی بر اساس DEAL_POSITION_ID انجام    |
//| نمی‌شه. این دقیقاً همون شکل ردیف-به-ازای-هر-رویداد-بسته‌شدنه که نسخه‌ی  |
//| اصلی MT4 همیشه داشت، فقط API زیرینش (Deal به‌جای Order History Row)   |
//| عوض شده.                                                             |
//+------------------------------------------------------------------+

// === v35 (Utility Phase A, Part 2) / v45 (BUG-037) ===
// [Stage 5b] ترجمه‌ی کامل به مدل Deal-محور MT5، طبق الگوی Stage 4:
// Pass 1: با یک HistorySelect(periodStart, now) پهن، هر Deal خروجی (DEAL_ENTRY_OUT) که واقعاً
//   معامله‌ست (DEAL_TYPE_BUY/SELL) رو پیدا می‌کنیم و بر اساس DEAL_POSITION_ID یکتاسازی می‌کنیم -
//   این خودِ عمل «یکتاسازی» معادل مستقیم بلوک dedupTickets/dedupNetUSD نسخه‌ی اصلیه، فقط با
//   DEAL_POSITION_ID به‌جای OrderTicket().
// Pass 2: برای هر position ID یکتا، HistorySelectByPosition() صدا زده می‌شه تا (الف) مجموع
//   profit+swap+commission همه‌ی Dealهای خروجی اون پوزیشن جمع بشه (= dedupNetUSD همون پوزیشن،
//   دقیقاً هم‌معنی جمع‌شدن دو ردیف Half Close در نسخه‌ی اصلی)، (ب) Magic واقعی از روی Deal
//   ورودی (IN) چک بشه - نه Deal خروجی، طبق یافته‌ی Stage 4 (بستن دستی/خودکار توسط بروکر Magic
//   قابل‌اعتمادی روی Deal خروجی نداره؛ Deal ورودی چون توسط خودِ EA با request.magic ثبت شده،
//   قابل‌اعتماده). این انحراف از توضیح تسک («فیلتر بر اساس DEAL_MAGIC==MagicNumber») عمدیه و
//   بر پایه‌ی باگ واقعی کشف‌شده در Stage 4 است - مستند شده، نه حدس سایلنت.
// Pass 3: همون آمار قبلی (بدون تغییر فرمول)، این‌بار روی لیست یکتاشده.
void CalcTradingReportStats(datetime periodStart, double periodStartBalance, double &winRatePct, double &profitFactor,
                             double &avgRR, double &expectancyR, double &maxDrawdownR, double &maxDrawdownPct, int &tradeCount)
{
   winRatePct=0; profitFactor=0; avgRR=0; expectancyR=0; maxDrawdownR=0; maxDrawdownPct=0; tradeCount=0;

   ulong    dedupPosIds[];    ArrayResize(dedupPosIds, 0);
   double   dedupNetUSD[];    ArrayResize(dedupNetUSD, 0);
   datetime dedupCloseTime[]; ArrayResize(dedupCloseTime, 0);
   int      dedupCount = 0;

   if(!HistorySelect(periodStart, TimeCurrent())) return; // نمی‌شه تاریخچه رو خوند - همه‌چیز صفر می‌مونه

   // --- Pass 1: جمع‌آوری position IDهای یکتا با حداقل یک Deal خروجی در این بازه ---
   ulong candidatePosIds[]; ArrayResize(candidatePosIds, 0);
   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket==0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType!=DEAL_TYPE_BUY && dealType!=DEAL_TYPE_SELL) continue;

      ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      bool already=false;
      for(int c=0;c<ArraySize(candidatePosIds);c++) if(candidatePosIds[c]==posId) { already=true; break; }
      if(!already) { int n=ArraySize(candidatePosIds); ArrayResize(candidatePosIds,n+1); candidatePosIds[n]=posId; }
   }

   // --- Pass 2: برای هر پوزیشن یکتا، مجموع سود/ضرر خروجی‌ها + آخرین زمان بسته‌شدن + Magic واقعی ---
   for(int p=0;p<ArraySize(candidatePosIds);p++)
   {
      ulong posId = candidatePosIds[p];
      // v75.0 (P0-4، معادل IsChainFullyClosed در MT4): پوزیشنی که Half Close شده ولی هنوز باز است «کامل بسته» نیست؛
      // فقط وقتی کامل بسته شد (یک‌بار، با مجموع خالص همه‌ی Dealهای خروجی) در Win Rate/PF/R شمرده می‌شود.
      // یک PositionSelectByTicket ارزان؛ هیچ اسکن تاریخچه‌ی تازه‌ای اضافه نشد.
      if(PositionSelectByTicket(posId)) continue;
      if(!HistorySelectByPosition(posId)) continue;
      int posDeals = HistoryDealsTotal();
      double sumNet = 0; datetime lastClose = 0; bool oursOpen=false;
      for(int d=0; d<posDeals; d++)
      {
         ulong pd = HistoryDealGetTicket(d);
         if(pd==0) continue;
         if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_IN && HistoryDealGetInteger(pd, DEAL_MAGIC)==MagicNumber)
            oursOpen = true;
         if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_OUT)
         {
            sumNet += HistoryDealGetDouble(pd, DEAL_PROFIT) + HistoryDealGetDouble(pd, DEAL_SWAP) + HistoryDealGetDouble(pd, DEAL_COMMISSION);
            datetime dt = (datetime)HistoryDealGetInteger(pd, DEAL_TIME);
            if(dt>lastClose) lastClose = dt;
         }
      }
      if(!oursOpen) continue;
      if(lastClose < periodStart) continue; // آخرین بسته‌شدنش قبل از شروع بازه بوده - این پوزیشن به این دوره تعلق نداره

      // v75.13 (MT4 v90): کلید یکی‌سازی = ریشه‌ی زنجیره؛ ورود(های) ادامه‌ی Scale-in با ریشه‌ی هدف یک معامله حساب می‌شوند
      // (سود خالص مجموع، زمان بسته‌شدن = آخرین بخش، پایه‌ی R = RiskBase ریشه). معامله‌ی تکی (ریشه = خودش) دقیقاً مثل قبل.
      ulong rootId = GetRootTicket(posId);
      int found = -1;
      for(int k=0;k<dedupCount;k++) if(dedupPosIds[k]==rootId){ found = k; break; }
      if(found >= 0)
      {
         dedupNetUSD[found] += sumNet;
         if(lastClose > dedupCloseTime[found]) dedupCloseTime[found] = lastClose;
         continue;
      }
      ArrayResize(dedupPosIds,   dedupCount+1);
      ArrayResize(dedupNetUSD,   dedupCount+1);
      ArrayResize(dedupCloseTime,dedupCount+1);
      dedupPosIds[dedupCount]    = rootId;
      dedupNetUSD[dedupCount]    = sumNet;
      dedupCloseTime[dedupCount] = lastClose;
      dedupCount++;
   }

   // v75.13: زنجیره‌ای که ریشه‌اش قبل از شروع بازه بسته شده ولی ورود ادامه‌اش داخل بازه است، باید سود خالص «کلِ» زنجیره را داشته باشد.
   // فقط برای زنجیره‌های چندعضوی (ورود ادامه) اجرا می‌شود؛ هزینه‌ی ناچیز.
   for(int g=0; g<dedupCount; g++)
   {
      if(ChainMemberCount(dedupPosIds[g]) <= 1) continue;
      for(int m=0; m<g_snapCount; m++)
      {
         ulong rm = (g_snapRootTicket[m] > 0) ? g_snapRootTicket[m] : g_snapTickets[m];
         if(rm != dedupPosIds[g]) continue;
         if(PositionSelectByTicket(g_snapTickets[m])) continue;
         if(!HistorySelectByPosition(g_snapTickets[m])) continue;
         double  memNet = 0; datetime memLast = 0; int nd = HistoryDealsTotal();
         for(int d2=0; d2<nd; d2++)
         {
            ulong pd2 = HistoryDealGetTicket(d2);
            if(pd2==0) continue;
            if(HistoryDealGetInteger(pd2, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
            memNet += HistoryDealGetDouble(pd2, DEAL_PROFIT) + HistoryDealGetDouble(pd2, DEAL_SWAP) + HistoryDealGetDouble(pd2, DEAL_COMMISSION);
            datetime t2 = (datetime)HistoryDealGetInteger(pd2, DEAL_TIME);
            if(t2 > memLast) memLast = t2;
         }
         if(memLast <= 0 || memLast >= periodStart) continue;   // بخش‌های داخل بازه قبلاً جمع شده‌اند
         dedupNetUSD[g] += memNet;
      }
   }

   // v75.13: زنجیره‌ی نیمه‌باز (حتی یک پوزیشن باز یا Pending منتظر با همین ریشه) در هیچ آماری نمی‌آید تا آخرین بخش بسته شود.
   {
      int keep = 0;
      for(int c=0; c<dedupCount; c++)
      {
         if(!IsChainFullyClosed(dedupPosIds[c])) continue;
         dedupPosIds[keep]    = dedupPosIds[c];
         dedupNetUSD[keep]    = dedupNetUSD[c];
         dedupCloseTime[keep] = dedupCloseTime[c];
         keep++;
      }
      dedupCount = keep;
      ArrayResize(dedupPosIds,   dedupCount);
      ArrayResize(dedupNetUSD,   dedupCount);
      ArrayResize(dedupCloseTime,dedupCount);
   }

   // oldest-first by close time - همون insertion sort نسخه‌ی اصلی
   for(int a=1;a<dedupCount;a++)
   {
      ulong    tPos   = dedupPosIds[a];
      double   tNet   = dedupNetUSD[a];
      datetime tClose = dedupCloseTime[a];
      int b = a-1;
      while(b>=0 && dedupCloseTime[b]>tClose)
      {
         dedupPosIds[b+1]    = dedupPosIds[b];
         dedupNetUSD[b+1]    = dedupNetUSD[b];
         dedupCloseTime[b+1] = dedupCloseTime[b];
         b--;
      }
      dedupPosIds[b+1]    = tPos;
      dedupNetUSD[b+1]    = tNet;
      dedupCloseTime[b+1] = tClose;
   }

   // --- Pass 3: همون آمار قبلی، بدون تغییر فرمول، روی لیست یکتاشده ---
   int    wins       = 0;
   double sumWinUSD  = 0, sumLossUSD = 0;

   int    winRCount  = 0, lossRCount = 0;
   double sumWinR    = 0, sumLossR   = 0;
   double cumR       = 0, peakR      = 0, maxDD    = 0;
   double cumUSD     = 0, peakUSD    = 0, maxDDUSD = 0;

   for(int j=0;j<dedupCount;j++)
   {
      double netUSD = dedupNetUSD[j];
      tradeCount++;
      if(netUSD>0)      { wins++; sumWinUSD += netUSD; }
      else if(netUSD<0) { sumLossUSD += -netUSD; }

      cumUSD += netUSD;
      if(cumUSD>peakUSD) peakUSD = cumUSD;
      double ddUSD = peakUSD-cumUSD;
      if(ddUSD>maxDDUSD) maxDDUSD = ddUSD;

      int idx = FindSnapshotIndex(dedupPosIds[j]);
      if(idx<0 || SnapRiskBase(idx)<=0) continue;

      // v75.13 (MT4 v90): idx = Snapshot «ریشه»ی زنجیره؛ پایه‌ی R = RiskBase آن (معامله‌ی عادی = RiskUSD خودش، عدد قبلی بدون تغییر).
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
   else if(sumWinUSD>0)  profitFactor = -1.0;
   else                  profitFactor = 0.0;

   double avgWinR  = (winRCount>0)  ? sumWinR/winRCount   : 0.0;
   double avgLossR = (lossRCount>0) ? sumLossR/lossRCount : 0.0;
   avgRR = (avgLossR>0) ? avgWinR/avgLossR : 0.0;

   int rCount = winRCount+lossRCount;
   expectancyR = (rCount>0)
                 ? ((double)winRCount/rCount)*avgWinR - ((double)lossRCount/rCount)*avgLossR
                 : 0.0;

   maxDrawdownR   = maxDD;
   maxDrawdownPct = (periodStartBalance>0) ? maxDDUSD/periodStartBalance*100.0 : 0.0;
}

//+------------------------------------------------------------------+
// v55 (CSV Export) / [Stage 5b port]
//
// [Stage 5b judgment call - SL/TP historical retrieval, flagged per task instructions] MT4's
// history ORDER retains OrderStopLoss()/OrderTakeProfit() at whatever value they were at THAT
// specific close event - meaning a Half Close's two rows could legitimately show two different SL
// values if BE/Trailing moved the stop between the partial close and the final close. MT5 DEALS
// carry no SL/TP field at all - a deal is only price/volume/profit/time, nothing about the
// position's protective levels at that moment. There is no MT5 API that reconstructs "what was
// this position's SL at deal #X's exact historical moment" once that moment has passed - this is a
// genuine capability gap between the two platforms' history models, not something a translation can
// paper over.
//   - SL column: falls back to the Trade Snapshot's ORIGINAL (open-time) SL (g_snapSL) when a valid
//     Snapshot exists, "N/A" otherwise. This is a semantic change worth flagging clearly: it reports
//     the position's starting SL, not necessarily the live SL at each specific closing event (which
//     is what MT4 showed for a moved stop). For a position whose SL was never adjusted before
//     closing, this is identical to the original. For one where BE/Trailing moved it, this column
//     will now show the same (original) SL on every row for that position, rather than each row's
//     own historical value.
//   - TP column: no persisted historical source exists at all - g_trackedTP (Stage 4) only covers
//     currently-OPEN positions and is removed from tracking the moment a position closes, so by the
//     time this export function runs against closed history, that data is already gone. This column
//     is "N/A" for every row until a future stage adds TP to the Trade Snapshot itself (a real
//     product decision, not something to invent unilaterally here - flagged, not silently patched).
//
// طبقه‌بندی SL/TP/EarlyExit، فیلتر فقط-MagicNumber (نه Symbol)، نام فایل ثابت بدون timestamp
// (BUG-047) و منطق "بدون Snapshot معتبر -> N/A" همگی دست‌نخورده حفظ شدن.
//
// [Stage 5b - no dedup, per design] هر Deal خروجی یک ردیف مستقل CSV می‌شه - نه بر اساس
// DEAL_POSITION_ID جمع می‌شه، نه فیلتر می‌شه. Ticket ستون CSV از DEAL_POSITION_ID پر می‌شه (معادل
// OrderTicket مشترک دو ردیف Half Close در نسخه‌ی اصلی) - یعنی یک پوزیشن Half-Close-شده دقیقاً
// مثل قبل، دو ردیف با یک شماره Ticket مشترک در CSV می‌شه.
bool ExportTradeJournalCSV(string &outFilename)
{
   string filename = "RM_TradeJournal_" + IntegerToString(MagicNumber) + ".csv";

   // v74.6 (HF6): این تابع کل فایل رو از تاریخچه+Snapshot از نو می‌نویسه. اگه Snapshot یک معامله دیگه
   // در دسترس نباشه (مثلاً GlobalVariableها بعد از بسته‌شدن غیرتمیز ترمینال از دست رفته‌ن)، ردیف قبلاً
   // درست‌نوشته‌شده‌ی همون معامله با N/A بازنویسی می‌شد. پس قبل از باز کردن فایل برای نوشتن، ردیف‌های
   // فعلی خونده می‌شن (کلید = Ticket|CloseTime) و فقط ستون‌های وابسته به Snapshot، فقط وقتی Snapshot
   // نیست و ردیف قبلی N/A نبود، از همون ردیف قبلی برداشته می‌شن. ردیف‌های قدیمی هرگز پر/بازنویسی
   // نمی‌شن (فقط حفظ). فقط روی export (بستن معامله/دکمه)، نه هر تیک.
   string oldKey[];  ArrayResize(oldKey, 0);
   string oldVal[];  ArrayResize(oldVal, 0);   // فیلدهای هر ردیف پشت‌سرهم؛ تعداد فیلد از خود هدر فایل قدیمی خوانده می‌شود
   int    oldStride = 0;                        // v75.9: قبلاً ثابت ۳۲ بود؛ حالا فایل‌های ۳۲ستونه (قدیمی) و ۴۷ستونه (جدید) هر دو درست خوانده می‌شوند
   int rh = FileOpen(filename, FILE_CSV|FILE_READ|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ',');
   if(rh != INVALID_HANDLE)
   {
      while(!FileIsEnding(rh))                // هدر: تا انتهای خط اول
      {
         FileReadString(rh);
         oldStride++;
         if(FileIsLineEnding(rh) || oldStride > 200) break;
      }
      if(oldStride >= 32 && oldStride <= 200)
      {
         while(!FileIsEnding(rh))
         {
            string fv[];
            ArrayResize(fv, oldStride);
            for(int fc=0; fc<oldStride; fc++) fv[fc] = FileReadString(rh);
            bool rowOk = true;
            if(!FileIsLineEnding(rh) && !FileIsEnding(rh))   // ردیف با تعداد فیلد غیرعادی - نادیده گرفته می‌شه
            {
               rowOk = false;
               while(!FileIsLineEnding(rh) && !FileIsEnding(rh)) FileReadString(rh);
            }
            if(!rowOk || fv[0]=="") continue;
            int on = ArraySize(oldKey);
            ArrayResize(oldKey, on+1);
            ArrayResize(oldVal, (on+1)*oldStride);
            oldKey[on] = fv[0] + "|" + fv[4];
            for(int fc2=0; fc2<oldStride; fc2++) oldVal[on*oldStride+fc2] = fv[fc2];
         }
      }
      FileClose(rh);
   }

   int handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("RM_Reports: ExportTradeJournalCSV - FileOpen failed, error ", GetLastError());
      return false;
   }

   FileWrite(handle, "Ticket","Symbol","Direction","OpenTime","CloseTime","Lots","Entry","SL",
             "ClosePrice","RiskUSD","RiskPct","TradeR","WasHalfRisk","Result","Strategy","Setup","Session","Screenshot",
             "BehaviorErrorCountAtOpen","OpenedDuringCooldownLock","EntryIntervalViolation","SLTamperedFlag",
             "DailyRiskUsedPctAtOpen","WeeklyDDUsedPctAtOpen",
             "PriorDayResult","ProfitUSD","SLLoosenedCount","BehaviorErrorsThisTrade","TimeframeAtOpen",
             "MaxFavR","MinFavR","MentalState",
             "ContextLevelOK","ContextCycleClarityOK","ContextTimeOK","ContextCandleConfirmOK","ContextNone",
             "SL_Final","TP_Final","Slippage_USD","Slippage_R","CloseReason_Server","Spread_AtClose","ServerHour_Close","IsEAManaged",
             "RiskStepWeight",
             "RootTicket");   // v75.9 (پورت MT4 v81/v82/v84/v86): ۱۵ ستون جدید فقط در انتها (قرارداد FEAT-036) - ترتیب/محتوای ۳۲ ستون قبلی دست‌نخورده

   if(!HistorySelect(0, TimeCurrent())) { FileClose(handle); outFilename=filename; return true; } // تاریخچه‌ی خالی/غیرقابل‌خوندن - CSV فقط با هدر می‌مونه

   // Pass 1: جمع‌آوری هر Deal خروجی واقعی + همه‌ی مقادیرش که فقط زیر انتخاب پهن تاریخچه قابل‌خوندنن
   // (posId, symbol, حجم, قیمت, زمان, سود) - همه، همین‌جا، قبل از هر HistorySelectByPosition.
   //
   // [Stage 5b bug fix - کشف‌شده حین تست زنده‌ی همین استیج، و به‌طور بازگشتی روی
   // CalcNetResultPercent (RM_DrawdownEngine.mq5، Stage 4) هم اعمال شد] فرض اولیه‌ی من (خوندن بر
   // اساس تیکت مستقل از انتخاب فعلیه) اشتباه بود: بعد از هر HistorySelectByPosition، خوندن
   // property های یک Deal *دیگه* (خارج از همون پوزیشن باریک‌شده) صفر برمی‌گردونه - نه مقدار
   // واقعی. اگه posId رو داخل Pass 2 (بعد از این‌که یه پوزیشن قبلی قبلاً انتخاب رو باریک کرده)
   // می‌خوندیم، همه‌ی Dealهای بعد از اولی posId=0 می‌گرفتن و همه رد می‌شدن - دقیقاً همون چیزی که
   // توی تست زنده دیدیم (فایل CSV فقط هدر داشت). راه‌حل: هر چیزی که از خودِ این Deal لازمه، همین‌جا
   // (زیر انتخاب پهن، قبل از هر باریک‌شدنی) خونده و ذخیره می‌شه؛ Pass 2 فقط از این مقادیر
   // ذخیره‌شده استفاده می‌کنه، هیچ‌وقت دوباره از تاریخچه نمی‌خونتشون.
   ulong    outDeals[];    ArrayResize(outDeals, 0);
   ulong    outPosIds[];   ArrayResize(outPosIds, 0);
   string   outSymbols[];  ArrayResize(outSymbols, 0);
   double   outLots[];     ArrayResize(outLots, 0);
   double   outClosePx[];  ArrayResize(outClosePx, 0);
   datetime outCloseTm[];  ArrayResize(outCloseTm, 0);
   double   outProfit[];   ArrayResize(outProfit, 0);
   double   outDealSL[];   ArrayResize(outDealSL, 0);    // v75.9: SL/TP ثبت‌شده روی خودِ Deal خروجی (MT5 build >= 1930 فیلد DEAL_SL/DEAL_TP دارد)
   double   outDealTP[];   ArrayResize(outDealTP, 0);
   long     outReason[];   ArrayResize(outReason, 0);    // v75.9: DEAL_REASON (SL/TP سروری یا دستی/EA)
   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket==0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType!=DEAL_TYPE_BUY && dealType!=DEAL_TYPE_SELL) continue;

      int n=ArraySize(outDeals);
      ArrayResize(outDeals,n+1);   ArrayResize(outPosIds,n+1);  ArrayResize(outSymbols,n+1);
      ArrayResize(outLots,n+1);    ArrayResize(outClosePx,n+1); ArrayResize(outCloseTm,n+1);
      ArrayResize(outProfit,n+1);
      ArrayResize(outDealSL,n+1);  ArrayResize(outDealTP,n+1);  ArrayResize(outReason,n+1);
      outDealSL[n]  = HistoryDealGetDouble(dealTicket, DEAL_SL);
      outDealTP[n]  = HistoryDealGetDouble(dealTicket, DEAL_TP);
      outReason[n]  = HistoryDealGetInteger(dealTicket, DEAL_REASON);
      outDeals[n]   = dealTicket;
      outPosIds[n]  = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      outSymbols[n] = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      outLots[n]    = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);   // حجمِ همین رویداد بسته‌شدن، نه کل پوزیشن - هم‌معنی OrderLots() نسخه‌ی اصلی روی یک ردیف پارشیال
      outClosePx[n] = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      outCloseTm[n] = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      outProfit[n]  = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   }

   // Pass 2: برای هر Deal خروجی، فقط از مقادیر ذخیره‌شده‌ی بالا استفاده می‌کنیم؛ تنها کاری که اینجا
   // از تاریخچه می‌خونیم، Deal ورودی (IN) همون پوزیشنه - که چون خودِ همون پوزیشن رو انتخاب کردیم
   // (نه یه پوزیشن دیگه)، درست می‌خونه.
   for(int oi=0; oi<ArraySize(outDeals); oi++)
   {
      ulong    posId      = outPosIds[oi];
      string   sym        = outSymbols[oi];
      double   lots       = outLots[oi];
      double   closePrice = outClosePx[oi];
      datetime closeTime  = outCloseTm[oi];
      double   profit     = outProfit[oi];
      double   dealSL     = outDealSL[oi];
      double   dealTP     = outDealTP[oi];
      long     dealReason = outReason[oi];
      // v75.9: آیا این Deal، آخرین Deal خروجیِ همین پوزیشن است؟ (Spread_AtClose فقط برای بسته‌شدن نهایی ثبت می‌شود)
      bool     isFinalExit = true;
      for(int lo=0; lo<ArraySize(outDeals); lo++)
         if(lo!=oi && outPosIds[lo]==posId && outCloseTm[lo]>closeTime) { isFinalExit = false; break; }

      // Magic واقعی + جهت + زمان/قیمت باز شدن - از Deal ورودی (IN) همون پوزیشن، نه از این Deal
      // خروجی (طبق یافته‌ی Stage 4، Magic روی Deal خروجی قابل‌اعتماد نیست).
      bool     oursOpen = false;
      bool     isBuy    = true;
      datetime openTime = 0;
      double   openPrice = 0;
      if(HistorySelectByPosition(posId))
      {
         int posDeals = HistoryDealsTotal();
         for(int d=0; d<posDeals; d++)
         {
            ulong pd = HistoryDealGetTicket(d);
            if(pd==0) continue;
            if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_IN)
            {
               if(HistoryDealGetInteger(pd, DEAL_MAGIC)==MagicNumber) oursOpen = true;
               isBuy     = (HistoryDealGetInteger(pd, DEAL_TYPE)==DEAL_TYPE_BUY);
               openTime  = (datetime)HistoryDealGetInteger(pd, DEAL_TIME);
               openPrice = HistoryDealGetDouble(pd, DEAL_PRICE);
            }
         }
      }
      if(!oursOpen) continue;

      int symDigits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      if(symDigits<=0) symDigits = _Digits; // فال‌بک محافظه‌کارانه اگه SymbolInfoInteger نتونه جواب بده

      double riskUSD = 0.0, riskPct = 0.0, tradeR = 0.0;
      bool   wasHalfRisk = false;
      double riskWeightVal = 1.0;
      string tradeRStr   = "N/A";
      string result      = "N/A";
      string slStr       = "N/A"; // [Stage 5b judgment call - see header] Snapshot's original SL, not per-event live SL
      string tpStr       = "N/A"; // [Stage 5b judgment call - see header] no historical source for closed positions at all

      // v75.9: مقادیر پیش‌فرض ستون‌های جدید (فقط وقتی Result واقعاً SL یا TP باشد و Snapshot معتبر باشد پر می‌شوند)
      double slippageUSD = 0.0, slippageR = 0.0;
      bool   slippageValid = false;
      string slFinalStr = (dealSL>0) ? DoubleToString(dealSL, symDigits) : "N/A";
      string tpFinalStr = (dealTP>0) ? DoubleToString(dealTP, symDigits) : "N/A";

      int snapIdx = FindSnapshotIndex(posId);
      if(snapIdx>=0 && MathAbs(g_snapEntry[snapIdx]-g_snapSL[snapIdx])>0)
      {
         riskUSD     = g_snapRiskUSD[snapIdx];
         riskPct     = g_snapRiskPct[snapIdx];
         wasHalfRisk = g_snapWasHalfRisk[snapIdx];
         riskWeightVal = SnapRiskWeight(snapIdx);
         slStr       = DoubleToString(g_snapSL[snapIdx], symDigits);

         double origDist = MathAbs(g_snapEntry[snapIdx]-g_snapSL[snapIdx]);
         double tolPrice = origDist*0.10;
         // v75.9 (MT4 v82 BUG-052): سطح SL = SL نهایی ثبت‌شده روی Deal (مثل OrderStopLoss تاریخچه‌ی MT4)؛ اگر Deal مقدار نداشت (0)،
         // SL اولیه‌ی Snapshot. جهت‌دار: «روی یا آن‌سوی SL» = استاپ.
         double slLevelForHit = (dealSL>0) ? dealSL : g_snapSL[snapIdx];
         bool   hitSL    = isBuy ? (closePrice <= slLevelForHit + tolPrice) : (closePrice >= slLevelForHit - tolPrice);
         bool   hitTP    = false;
         if(dealTP>0)
         {
            double tpDist = MathAbs(dealTP-openPrice);
            double tpTol  = tpDist*0.10;
            hitTP = isBuy ? (closePrice >= dealTP - tpTol) : (closePrice <= dealTP + tpTol);
         }

         bool reached1R = (riskUSD>0 && profit >= riskUSD*0.95);

         if(riskUSD>0)
         {
            tradeR    = profit/riskUSD;
            tradeRStr = DoubleToString(tradeR,2);
         }

         // v75.9: hitTP حالا از DEAL_TP همان Deal خوانده می‌شود (قبلاً همیشه false بود)؛ طبقه‌بندی دقیقاً مثل MT4: SL / TP (یا +1R) / EarlyExit.
         if(hitSL && !hitTP)           result = "SL";
         else if(hitTP || reached1R)   result = "TP";
         else                          result = "EarlyExit";

         // Slippage_USD/Slippage_R (MT4 v82 FEAT-036): فقط وقتی Result==SL/TP و Snapshot معتبر؛ مثبت = بدتر از سطح
         if(origDist>0 && riskUSD>0 && (result=="SL" || result=="TP"))
         {
            double lvl = (result=="SL") ? slLevelForHit : dealTP;
            if(lvl>0)
            {
               double dollarPerUnit = riskUSD/origDist;
               double slipPriceSigned = isBuy ? (lvl-closePrice) : (closePrice-lvl);
               slippageUSD   = slipPriceSigned*dollarPerUnit;
               slippageR     = slippageUSD/riskUSD;
               slippageValid = true;
            }
         }
      }

      if(WasEmergencyClosed(posId)) result = "EmergencyClose";

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

      string priorDayResultStr = "N/A";
      string slLoosenedStr     = "N/A";
      if(snapIdx>=0)
      {
         priorDayResultStr = PriorDayResultCodeToString(g_snapPriorDayResult[snapIdx]);
         slLoosenedStr     = IntegerToString(g_snapSLLoosenedCount[snapIdx]);
      }

      string behErrThisTradeStr = "N/A";
      if(snapIdx>=0 && g_snapBehaviorErrorsThisTrade[snapIdx] >= 0)
         behErrThisTradeStr = DoubleToString(g_snapBehaviorErrorsThisTrade[snapIdx], 0);

      string timeframeAtOpenStr = "N/A";
      if(snapIdx>=0)
         timeframeAtOpenStr = TimeframeCodeToString(g_snapTimeframeAtOpen[snapIdx]);

      string maxFavRStr = "N/A";
      string minFavRStr = "N/A";
      if(snapIdx>=0)
      {
         maxFavRStr = DoubleToString(g_snapMaxFavR[snapIdx], 2);
         minFavRStr = DoubleToString(g_snapMinFavR[snapIdx], 2);
      }

      string riskUSDStr = (snapIdx>=0 ? DoubleToString(riskUSD,2) : "N/A");
      string riskPctStr = (snapIdx>=0 ? DoubleToString(riskPct,2) : "N/A");
      string halfRiskStr = (snapIdx>=0 ? (wasHalfRisk ? "true" : "false") : "N/A");

      bool restoredFromOld = false;   // v75.9: ردیف از فایل قبلی بازیابی شد (Snapshot از دست رفته بود)
      // v74.6 (HF6): Snapshot نیست -> ستون‌های وابسته به Snapshot از ردیف قبلی همین معامله (اگه N/A نبود)
      if(snapIdx<0 && oldStride>0)
      {
         string mkey = IntegerToString(posId) + "|" + TimeToString(closeTime, TIME_DATE|TIME_SECONDS);
         for(int mo=0; mo<ArraySize(oldKey); mo++)
         {
            if(oldKey[mo] != mkey) continue;
            if(oldVal[mo*oldStride+7] == "N/A") break;   // ردیف قبلی هم خالی بوده - چیزی برای حفظ نیست
            slStr        = oldVal[mo*oldStride+7];
            riskUSDStr   = oldVal[mo*oldStride+9];
            riskPctStr   = oldVal[mo*oldStride+10];
            tradeRStr    = oldVal[mo*oldStride+11];
            halfRiskStr  = oldVal[mo*oldStride+12];
            if(result == "N/A") result = oldVal[mo*oldStride+13];
            behErrStr = oldVal[mo*oldStride+18];  duringLockStr = oldVal[mo*oldStride+19];  intervalStr = oldVal[mo*oldStride+20];
            tamperStr = oldVal[mo*oldStride+21];  dailyPctStr = oldVal[mo*oldStride+22];    weeklyPctStr = oldVal[mo*oldStride+23];
            priorDayResultStr = oldVal[mo*oldStride+24];  slLoosenedStr = oldVal[mo*oldStride+26];
            behErrThisTradeStr = oldVal[mo*oldStride+27];  timeframeAtOpenStr = oldVal[mo*oldStride+28];
            maxFavRStr = oldVal[mo*oldStride+29];  minFavRStr = oldVal[mo*oldStride+30];
            restoredFromOld = true;
            break;
         }
      }

      // v75.9: ستون‌های جدید
      string slippageUSDStr = slippageValid ? DoubleToString(slippageUSD,2) : "N/A";
      string slippageRStr   = slippageValid ? DoubleToString(slippageR,2)   : "N/A";
      string closeReasonServer = "";   // مثل MT4: بستن دستی/EA = خالی (نه N/A)
      if(dealReason==DEAL_REASON_SL)      closeReasonServer = "[sl]";
      else if(dealReason==DEAL_REASON_TP) closeReasonServer = "[tp]";
      double spreadAtCloseVal = 0.0;
      string spreadAtCloseStr = (isFinalExit && GetSpreadAtClose(posId, spreadAtCloseVal)) ? DoubleToString(spreadAtCloseVal, symDigits) : "N/A";
      MqlDateTime closeDt; TimeToStruct(closeTime, closeDt);
      string serverHourCloseStr = IntegerToString(closeDt.hour);   // وقت سرور بروکر، بدون تبدیل منطقه‌ی زمانی
      bool   isManaged = (snapIdx>=0 || restoredFromOld);
      string isEAManagedStr = isManaged ? "true" : "false";
      string riskStepWeightStr = (isManaged && snapIdx>=0) ? DoubleToString(riskWeightVal,3) : (isManaged ? "1.000" : "N/A");   // v75.10: وزن واقعی پله‌ی ریسک

      FileWrite(handle, posId, sym, (isBuy ? "Buy" : "Sell"),
                TimeToString(openTime,  TIME_DATE|TIME_SECONDS),
                TimeToString(closeTime, TIME_DATE|TIME_SECONDS),
                DoubleToString(lots,2),
                DoubleToString(openPrice,  symDigits),
                slStr,
                DoubleToString(closePrice, symDigits),
                riskUSDStr,
                riskPctStr,
                tradeRStr,
                halfRiskStr,
                result,
                GetTagStrategy(posId),   // stub this stage - RM_Tools.mqh not yet ported
                GetTagSetup(posId),      // stub this stage
                SessionLevel_TagForTime(openTime),  // stub this stage
                GetExitScreenshotName(posId),       // stub this stage
                behErrStr, duringLockStr, intervalStr, tamperStr, dailyPctStr, weeklyPctStr,
                priorDayResultStr, DoubleToString(profit,2), slLoosenedStr, behErrThisTradeStr, timeframeAtOpenStr,
                maxFavRStr, minFavRStr,
                GetTagMentalState(posId),
                GetCtxLevelStr(posId), GetCtxCycleStr(posId), GetCtxTimeStr(posId), GetCtxCandleStr(posId), GetCtxNoneStr(posId),   // Context×5 (MT4 FEAT-037، v75.14 P5): مقدار واقعی چک‌لیست؛ انجام‌نشده = هر ۵ "false"
                slFinalStr, tpFinalStr, slippageUSDStr, slippageRStr, closeReasonServer, spreadAtCloseStr, serverHourCloseStr, isEAManagedStr,
                riskStepWeightStr,
                IntegerToString(GetRootTicket(posId)));   // RootTicket: Half Close همان پوزیشن را کوچک می‌کند؛ ریشه فقط برای ورود ادامه (Scale-in) فرق دارد (v75.13)
   }

   FileClose(handle);
   outFilename = filename;
   return true;
}
