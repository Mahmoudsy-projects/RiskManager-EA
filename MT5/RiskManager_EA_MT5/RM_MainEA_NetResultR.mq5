//+------------------------------------------------------------------+
//| RM_MainEA_NetResultR.mq5                                          |
//| Risk Manager EA - MT5 Port. GAP FOUND 2026-08-06, ported by main   |
//| chat directly (not through a task-chat dispatch/test cycle like    |
//| every other file in this port) - see the note below before trusting|
//| this the same way as everything else.                             |
//|                                                                     |
//| Source: RiskManager_EA_v70.mq4's CalcNetResultR/CalcNetResultRB    |
//| (main .mq4, v11/v25 FEAT-016/017) - never assigned to any EA port  |
//| stage. Discovered only because assembling the final package        |
//| exposed the placeholder stubs (GetDailyR() etc, always returning   |
//| 0.0) that every stage's "nothing stubbed" checks had walked past,  |
//| since these functions only feed a cosmetic dashboard R-value       |
//| display - no stage's test matrix ever exercised them.              |
//|                                                                     |
//| Golden Rule followed: mirrors RM_DrawdownEngine.mq5's already-      |
//| proven, live-tested CalcNetResultPercent() two-pass structure      |
//| exactly (Pass 1 collect DEAL_POSITION_ID/profit/swap/commission    |
//| under the wide selection; Pass 2 re-select by position, confirm    |
//| ownership via the OPENING deal's magic, only then sum) - same      |
//| Stage 4/5b bug class this pattern was built to avoid. Only the     |
//| final per-deal formula differs (R-based via Snapshot risk, not     |
//| %-based via balance).                                              |
//|                                                                     |
//| NOT YET LIVE-TESTED. Formulas match the MT4 source exactly and the |
//| translation pattern is proven elsewhere in this project, but this  |
//| specific file has not been through the compile-on-real-MT5 +       |
//| live-demo-test cycle every other file in this port went through.   |
//| Recommend a quick spot-check once compiled: open 2+ trades in a    |
//| day, confirm the dashboard's Daily R value is a sane number.       |
//+------------------------------------------------------------------+

// === v11 (FEAT-016) MT5 port: R تجمعی یک دوره. همون الگوی دقیق
// CalcNetResultPercent (Pass 1 گسترده + Pass 2 با posId ذخیره‌شده و چک
// مجیک روی دیل بازشدن) - فقط جمع نهایی بر مبنای R (تقسیم بر
// g_snapRiskUSD همون Snapshot) به‌جای درصد بالانس. منطق/آستانه عوض نشده،
// فقط API از MT4 به MT5 ترجمه شده.
double CalcNetResultR(datetime periodStart)
{
   if(!HistorySelect(periodStart, TimeCurrent())) return 0;

   ulong  outDeals[];    ArrayResize(outDeals,0);
   ulong  outPosIds[];   ArrayResize(outPosIds,0);
   double outProfit[];   ArrayResize(outProfit,0);
   double outSwap[];     ArrayResize(outSwap,0);
   double outComm[];     ArrayResize(outComm,0);
   int total = HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket==0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType!=DEAL_TYPE_BUY && dealType!=DEAL_TYPE_SELL) continue;
      // v74.2 (HF3, B3): no symbol filter - R / RB are shown in the Performance panel (display only), account-wide,
      // so every chart shows the same numbers. Snapshots of positions opened on other charts are pulled lazily.

      int n=ArraySize(outDeals);
      ArrayResize(outDeals,n+1);  ArrayResize(outPosIds,n+1);
      ArrayResize(outProfit,n+1); ArrayResize(outSwap,n+1); ArrayResize(outComm,n+1);
      outDeals[n]  = dealTicket;
      outPosIds[n] = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      outProfit[n] = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      outSwap[n]   = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      outComm[n]   = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   }

   double totalR=0;
   for(int j=0;j<ArraySize(outDeals);j++)
   {
      ulong posId = outPosIds[j];
      bool oursOpen=false;
      if(HistorySelectByPosition(posId))
      {
         int posDeals = HistoryDealsTotal();
         for(int k=0;k<posDeals;k++)
         {
            ulong pd = HistoryDealGetTicket(k);
            if(pd==0) continue;
            if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_IN && HistoryDealGetInteger(pd, DEAL_MAGIC)==MagicNumber)
               oursOpen = true;
         }
      }
      if(!oursOpen) continue;

      int idx = FindSnapshotIndex(posId);
      if(idx<0) continue;               // بدون Snapshot - مثل نسخه‌ی اصلی، قابل محاسبه نیست
      if(SnapRiskBase(idx)<=0) continue;   // v75.13 (MT4 v90): پایه‌ی R زنجیره (ورود ادامه = ریسک ریشه؛ معامله‌ی عادی = RiskUSD خودش)

      totalR += (outProfit[j]+outSwap[j]+outComm[j])/SnapRiskBase(idx);
   }
   return totalR;
}

double GetDailyR()   { return CalcNetResultR(g_dayStart); }
double GetWeeklyR()  { return CalcNetResultR(g_weekStart); }
double GetMonthlyR() { return CalcNetResultR(g_monthStart); }

// === v25 (FEAT-017) MT5 port: RB (Base R) - نسخه‌ی وزن‌دهی‌شده‌ی R؛ معامله‌ی
// Half Risk (g_snapWasHalfRisk) با ضریب 0.5 به‌جای 1.0 جمع می‌شه. کاملاً
// مستقل از CalcNetResultR - همون Pass 1/2 بالا، فقط ضریب اضافه.
double CalcNetResultRB(datetime periodStart)
{
   if(!HistorySelect(periodStart, TimeCurrent())) return 0;

   ulong  outDeals[];    ArrayResize(outDeals,0);
   ulong  outPosIds[];   ArrayResize(outPosIds,0);
   double outProfit[];   ArrayResize(outProfit,0);
   double outSwap[];     ArrayResize(outSwap,0);
   double outComm[];     ArrayResize(outComm,0);
   int total = HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket==0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType!=DEAL_TYPE_BUY && dealType!=DEAL_TYPE_SELL) continue;
      // v74.2 (HF3, B3): no symbol filter - R / RB are shown in the Performance panel (display only), account-wide,
      // so every chart shows the same numbers. Snapshots of positions opened on other charts are pulled lazily.

      int n=ArraySize(outDeals);
      ArrayResize(outDeals,n+1);  ArrayResize(outPosIds,n+1);
      ArrayResize(outProfit,n+1); ArrayResize(outSwap,n+1); ArrayResize(outComm,n+1);
      outDeals[n]  = dealTicket;
      outPosIds[n] = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      outProfit[n] = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      outSwap[n]   = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      outComm[n]   = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   }

   double totalRB=0;
   for(int j=0;j<ArraySize(outDeals);j++)
   {
      ulong posId = outPosIds[j];
      bool oursOpen=false;
      if(HistorySelectByPosition(posId))
      {
         int posDeals = HistoryDealsTotal();
         for(int k=0;k<posDeals;k++)
         {
            ulong pd = HistoryDealGetTicket(k);
            if(pd==0) continue;
            if(HistoryDealGetInteger(pd, DEAL_ENTRY)==DEAL_ENTRY_IN && HistoryDealGetInteger(pd, DEAL_MAGIC)==MagicNumber)
               oursOpen = true;
         }
      }
      if(!oursOpen) continue;

      int idx = FindSnapshotIndex(posId);
      if(idx<0) continue;
      if(SnapRiskBase(idx)<=0) continue;   // v75.13 (MT4 v90)

      double tradeR = (outProfit[j]+outSwap[j]+outComm[j])/SnapRiskBase(idx);
      double factor = SnapRiskWeight(idx);
      totalRB += tradeR*factor;
   }
   return totalRB;
}

double GetDailyRB()   { return CalcNetResultRB(g_dayStart); }
double GetWeeklyRB()  { return CalcNetResultRB(g_weekStart); }
double GetMonthlyRB() { return CalcNetResultRB(g_monthStart); }
