//+------------------------------------------------------------------+
//| RM_MainEA_FloatingDD.mq5                                           |
//| Risk Manager EA - main .mq4 extract (MT5 Port, Stage 4)            |
//| پورت مستقیم دو تابع کوچیک از خودِ RiskManager_EA_v70.mq4 (نه یه       |
//| ماژول .mqh) که RM_DrawdownEngine.mq5 مستقیم بهشون وابسته‌ست:         |
//| GetFloatingPLPercent() و EmergencyCloseAll(). طبق دستور صریح تسک -   |
//| اضافه‌شدن پیش‌دستانه به اسکوپ Stage 4، همون فلسفه‌ی الحاق              |
//| RM_Common.mqh به Stage 3. Golden Rule: فرمول‌ها/ترتیب عملیات          |
//| دست‌نخورده - فقط API معاملاتی ترجمه شده.                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| v9.5: Floating Drawdown Protection                                |
//+------------------------------------------------------------------+
double GetFloatingPLPercent()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal<=0) return 0;
   double floatingPL = 0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;   // v74.3 (HF2, A2): ALL symbols of this EA (denominator was already the whole-account balance)
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      floatingPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      // [Stage 4 judgment call] MT4's OrderProfit()+OrderSwap()+OrderCommission() included
      // commission because MT4 orders carry a per-order commission field even while open. MT5
      // positions have POSITION_PROFIT and POSITION_SWAP, but NO position-level commission field -
      // commission in MT5 is only recorded per-DEAL (at open/close), not accrued on the open
      // position itself. There is no live "unrealized commission" to add here since none has been
      // charged yet for a still-open position (nothing to sum from an empty deal list for this
      // period). This is a genuine floating-PL definition gap between platforms, not a formula I
      // chose to drop - flagged explicitly rather than silently omitted.
   }
   return floatingPL/bal*100.0;
}

void EmergencyCloseAll()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;   // v74.3 (HF2, A2): every symbol; each position is closed at its OWN symbol's price (RM_ClosePosition uses POSITION_SYMBOL)
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      string posSym = PositionGetString(POSITION_SYMBOL);
      // v62 (تفکیک ExitReason - EmergencyClose): قبل از بستن، تیکت به آرایه‌ی موقت
      // g_emergencyClosedTickets[] (RM_CooldownEngine.mqh) اضافه می‌شه تا CheckClosedTrades این
      // بسته‌شدن رو به‌عنوان اقدام حفاظتی سیستم (نه خروج دستی تریدر) تشخیص بده. هیچ تغییری در
      // منطق پایین (چی رو کِی می‌بنده) داده نشده.
      // v74.3 (HF2, A2): the shared flag (GV RM_EMERGENCY_<ticket>) is set BEFORE the close request, so whichever chart
      // classifies the closed position labels it EmergencyClosed (not EarlyExit + Behavior strike). The in-memory
      // list is kept only for this chart's own symbol (it is consumed by this chart's CheckClosedTrades).
      MarkEmergencyClosed(tk);
      if(posSym == _Symbol)
      {
         ArrayResize(g_emergencyClosedTickets, g_emergencyClosedCount+1);
         g_emergencyClosedTickets[g_emergencyClosedCount] = tk;
         g_emergencyClosedCount++;
      }
      // v6 (BUG-007 fix): نتیجه‌ی OrderClose چک می‌شه؛ اگه بسته نشد (ریکوت/آف‌کوتز و...)، یه بار دیگه با قیمت تازه امتحان می‌شه
      double vol = PositionGetDouble(POSITION_VOLUME);
      MqlTradeResult tres; ZeroMemory(tres);
      bool closed = RM_ClosePosition(tk, vol, Slippage, tres);
      if(!closed && !PositionSelectByTicket(tk))
         closed = true;   // v74.3 (HF2, A2): already gone = another chart closed it - success, not a failure
      if(!closed)
      {
         int err = GetLastError();
         Print("EmergencyCloseAll: OrderClose failed for ticket ", tk, " (error ", err, "), retrying once");
         // [Stage 4] MT4's RefreshRates() has no MT5 equivalent/no-op needed - MT5's
         // SymbolInfoDouble()/SymbolInfoTick() calls (inside RM_ClosePosition -> RM_GetFillingMode
         // and the price fields) always read live tick data directly, there is no separate
         // "refresh the cached rates" step to call first.
         MqlTradeResult tres2; ZeroMemory(tres2);
         if(PositionSelectByTicket(tk))
         {
            double vol2 = PositionGetDouble(POSITION_VOLUME);
            closed = RM_ClosePosition(tk, vol2, Slippage, tres2);
         }
         else
            closed = true;   // v74.3 (HF2, A2): disappeared between the two attempts (closed by another chart)
         if(!closed && !PositionSelectByTicket(tk))
            closed = true;
         if(!closed)
         {
            Print("EmergencyCloseAll: retry failed for ticket ", tk, " (error ", GetLastError(), ") - position still open!");
            GlobalVariableDel("RM_EMERGENCY_" + IntegerToString(tk));   // v74.3 (HF2): it was NOT closed by the system - drop the flag
            Alert("Emergency Close FAILED for ticket ", tk, " - check platform manually!");
         }
      }
   }
}
