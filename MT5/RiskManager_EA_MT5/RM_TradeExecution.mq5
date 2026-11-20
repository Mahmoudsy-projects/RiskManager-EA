//+------------------------------------------------------------------+
//| RM_TradeExecution.mq5                                              |
//| Risk Manager EA - Trade Execution (MT5 Port, Stage 3)               |
//| پورت مستقیم از RM_TradeExecution.mqh (RiskManager EA v70, MQL4).     |
//| Golden Rule: فرمول‌ها/آستانه‌ها/ترتیب عملیات عوض نشدن - فقط           |
//| فراخوانی‌های API معاملاتی از MT4 به MT5 ترجمه شدن. حساب هدف          |
//| Hedging است - هر پوزیشن (حتی هم‌جهت یا مخالف‌جهت روی یک نماد)        |
//| مستقل باقی می‌مونه، دقیقاً مثل اوردرهای مستقل MT4.                    |
//|                                                                     |
//| این فایل به تعداد زیادی global/function از ماژول‌های دیگه (که هنوز   |
//| پورت نشدن: RM_Snapshot.mqh, RM_Dashboard.mqh, RM_CooldownEngine.mqh,|
//| RM_Trailing.mqh, RM_Tools.mqh, RM_DrawdownEngine.mqh, و globalهای   |
//| خودِ .mq4 اصلی) وابسته‌ست. طبق دستور Stage 3، این‌ها استاب compile-   |
//| only می‌گیرن، نه پیاده‌سازی واقعی - جزئیات کامل در گزارش.             |
//+------------------------------------------------------------------+

// === v41 (BUG-018): SL Tampering Protection - قانون ۱ (حذف کامل SL) نیاز به یه پنجره‌ی
// grace period ۵ثانیه‌ای داره تا تشخیص بده SL=0 موقتیه (تریدر داره SL جدید می‌ذاره) یا واقعی.
// دقیقاً همون الگوی in-memory تیکت‌های Trailing (g_trailTickets/g_trailLastBar) و Auto Half
// Done بالا - در GlobalVariable ذخیره نمی‌شه چون پنجره‌ی ۵ثانیه‌ای به‌قدری کوتاهه که از دست
// رفتنش با یه ری‌استارت همزمان EA عملاً بی‌اهمیته (لیست Pending Tracking هم از قبل همین فلسفه رو داره).
// [Stage 3 judgment call] int[] → ulong[]: MT5 position tickets are natively 64-bit (ulong), same
// reasoning as Stage 2's GetTotalOpenRiskExcludingTicket judgment call. Every ticket-holding array
// and parameter in this file follows the same int→ulong change.
ulong    g_slZeroTickets[];
datetime g_slZeroDetectedTime[];
int      g_slZeroCount = 0;

// v41 (Mahmoud feedback): برخلاف g_snapSL (Snapshot، immutable، همیشه SL لحظه‌ی بازشدنه) و
// g_trackedSL (هر تیک بدون فیلتر با OrderStopLoss() فعلی sync می‌شه، حتی وقتی صفره)، این
// آرایه فقط با آخرین SL معتبر (غیرصفر) دیده‌شده به‌روز می‌شه. دلیل: وقتی تریدر بعد از چندبار
// جابه‌جایی مشروع SL (BE دستی، Trailing، و غیره) بالاخره هیجانی می‌شه و کامل حذفش می‌کنه،
// برگردوندن به SL خیلی اولیه‌ی معامله اشتباهه - چون تا اون لحظه قیمت به احتمال زیاد از همون
// SL اولیه رد شده. نقطه‌ی برگشت درست، آخرین جایی‌ست که SL واقعاً آنجا بوده، نه اولین جا.
// مثل g_slZero بالا، فقط in-memory - پنجره‌ای که با ری‌استارت همزمان از دست بره ناچیزه، و
// فال‌بک محافظه‌کارانه (g_snapSL) برای اون حالت نادر همیشه در دسترسه.
ulong    g_lastSLTickets[];
double   g_lastSLValue[];
int      g_lastSLCount = 0;

// v47 (BUG-040): CheckSLTampering() قبلاً به‌ازای هر تشخیص (نه هر تیکت) AddBehaviorStrike()
// صدا می‌زد - اگه تریدر ۲-۳ بار پشت‌سرهم قبل از فهمیدن ماجرا تلاش می‌کرد، هر تلاش یه Strike
// جدا می‌گرفت و ممکن بود خیلی زود Behavior Cooldown قفل بشه. فیکس: هر تیکت حداکثر یک Strike
// به‌خاطر تمپرینگ SL (صرف‌نظر از این‌که چندبار تشخیص داده بشه یا کدوم قانون - ۱ یا ۲ - فایر
// کنه)؛ تصحیح SL و Alert/Print همچنان هر بار اجرا می‌شن، فقط جریمه‌ی رفتاری تکراری حذف می‌شه.
// عمداً یه آرایه‌ی مجزا از g_snapStriked (RM_Snapshot.mqh) - اون یکی مخصوص «اقدام زودهنگام»ه
// (BE/Half Close قبل از +1R)، یه دسته‌ی رفتاری کاملاً متفاوت از تمپرینگ SL؛ قاطی‌کردنشون یعنی
// اگه یه تیکت قبلاً به‌خاطر اقدام زودهنگام Strike گرفته، تمپرینگ روش دیگه هیچ‌وقت Strike
// نگیره - که اشتباهه. مثل g_slZero/g_lastSL بالا، فقط in-memory (نه GlobalVariable) - همون
// فلسفه‌ی محافظه‌کارانه: پنجره‌ای که با ری‌استارت همزمان EA از دست بره ناچیزه. مثل خود جدول
// Snapshot (g_snapStriked)، با بسته‌شدن تیکت هم پاک نمی‌شه - چون تیکت هیچ‌وقت تکرار نمی‌شه،
// بی‌فایده موندنش توی آرایه فقط حافظه مصرف می‌کنه، نه اشتباه رفتاری.
ulong    g_tamperStrikedTickets[];
int      g_tamperStrikedCount = 0;

// v75.0 (P0، MT4 v101 BUG-054): پرچم «قبلاً Strike دستکاری SL خورده» حالا GV حساب‌محور هم دارد
// (RM_TAMPERSTRIKED_A<حساب>_M<مجیک>_<تیکت>)؛ بین چارت‌ها مشترک است و با ری‌استارت EA از بین نمی‌رود.
string TamperStrikedKey(ulong ticket)
{
   return "RM_TAMPERSTRIKED_A" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + IntegerToString(ticket);
}

bool IsAlreadyTamperStriked(ulong ticket)
{
   for(int i=0;i<g_tamperStrikedCount;i++)
      if(g_tamperStrikedTickets[i]==ticket) return true;
   return GlobalVariableCheck(TamperStrikedKey(ticket));
}

void MarkTamperStriked(ulong ticket)
{
   if(!GlobalVariableCheck(TamperStrikedKey(ticket)))
   {
      GlobalVariableSet(TamperStrikedKey(ticket), 1.0);   // پرچم مشترک و ماندگار
      GlobalVariablesFlush();                              // رویداد نادر (فقط روی Strike دستکاری)
   }
   for(int ti=0;ti<g_tamperStrikedCount;ti++)
      if(g_tamperStrikedTickets[ti]==ticket) return;
   ArrayResize(g_tamperStrikedTickets, g_tamperStrikedCount+1);
   g_tamperStrikedTickets[g_tamperStrikedCount] = ticket;
   g_tamperStrikedCount++;
}

//+------------------------------------------------------------------+
// [Stage 3, NEW] MT5 order-submission helpers.
// MT4's single-call OrderSend()/OrderModify()/OrderClose() become MT5's MqlTradeRequest struct +
// OrderSend(request,result). Rather than rebuild that struct/filling-mode/logging boilerplate at
// each of this file's ~8 call sites, one shared helper per action type is used. This is plumbing
// introduced BY the API change itself, not a redesign - every call site below still computes its
// own lot/price/sl/tp exactly as the original MT4 code did and just hands those same values to a
// different (MT5-shaped) transport. No formula/threshold/order-of-operations changed.
//+------------------------------------------------------------------+

// [Stage 3 judgment call #1 - flagged in task, explicit decision] Filling mode: MT5 requires
// request.type_filling, and the wrong one causes a silent order rejection on some brokers. Not
// hardcoded - read the symbol's actual supported modes from SYMBOL_FILLING_MODE and prefer, in
// order: FOK -> IOC -> RETURN. RETURN is the universal fallback every broker/account type accepts
// (including Hedging accounts, the confirmed target mode for this stage), so it's last, not first -
// FOK/IOC are tried first because they're the closer conceptual match to MT4's single
// immediate-or-reject OrderSend() call. This is MT5's own documented fallback pattern, not an
// invented one.
ENUM_ORDER_TYPE_FILLING RM_GetFillingMode(string symbol)
{
   int filling = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

// [Stage 3 judgment call #2 - flagged in task, explicit decision] Stops level / freeze level
// (SYMBOL_TRADE_STOPS_LEVEL / SYMBOL_TRADE_FREEZE_LEVEL): checked the original ProcessClick()/
// AutoExecute() carefully - neither performs any distance-from-price validation before calling
// OrderSend(). SL/TP are sent exactly as computed and the broker itself accepts or rejects them.
// Per the Golden Rule, NO new blocking/validation logic is added here to match that - a broker
// rejection for stops-too-close now surfaces as a non-DONE retcode in the RM_LogTradeResult() print
// below, exactly as it previously surfaced via GetLastError() in MT4's failure branch. If the
// original had added such a check somewhere I missed, this decision needs revisiting - flagging
// this explicitly rather than silently assuming "no check needed."

// Shared retcode/ticket/price/volume logging - Stage 3 task requirement: print these four fields
// after every OrderSend() call so Mahmoud can see success/failure without hunting the Trade tab.
void RM_LogTradeResult(string action, MqlTradeRequest &req, MqlTradeResult &res)
{
   Print("RM_Trade[",action,"]: retcode=",res.retcode," (",res.comment,") ",
         "order=",res.order," deal=",res.deal," price=",DoubleToString(res.price,_Digits),
         " volume=",DoubleToString(res.volume,2));
}

// [Stage 3 judgment call #3] MT4's OrderSend()/OrderModify()/OrderClose() returned a single bool.
// TRADE_RETCODE_DONE is the direct equivalent of "fully succeeded." TRADE_RETCODE_DONE_PARTIAL (a
// partial fill) is also treated as success here, since MT4's model had no partial-fill concept to
// compare against and a partial fill still means SOME volume was opened/closed - callers can read
// res.volume for the actual filled amount if they need it. This does not change any risk math -
// CalcLot()'s output volume is what's requested either way.
bool RM_IsDoneRetcode(uint retcode)
{
   return (retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_DONE_PARTIAL);
}

// MT4: OrderSend(symbol, OP_BUY/OP_SELL, lot, price, slippage, sl, tp, comment, magic, 0, color)
// for a MARKET order -> MT5: TRADE_ACTION_DEAL. Returns the resulting position ticket (0 on
// failure). In Hedging mode (confirmed target account mode) a new position's ticket equals the
// ticket of the order that opened it, so res.order is the correct value to hand back to callers
// that expect "the ticket," matching how MT4's OrderSend() return value was used everywhere below.
ulong RM_SendMarketOrder(string symbol, bool isBuy, double lot, double sl, double tp, int slippage,
                          string comment, int magic, MqlTradeResult &outResult)
{
   MqlTradeRequest req; ZeroMemory(req);
   MqlTradeResult  res; ZeroMemory(res);

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = symbol;
   req.volume       = lot;
   req.type         = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price        = isBuy ? SymbolInfoDouble(symbol,SYMBOL_ASK) : SymbolInfoDouble(symbol,SYMBOL_BID);
   req.sl           = sl;
   req.tp           = tp;
   req.deviation    = slippage;      // MT4 slippage parameter -> request.deviation, same concept, new field name
   req.magic        = magic;
   req.comment      = comment;
   req.type_filling = RM_GetFillingMode(symbol);

   bool sent = OrderSend(req, res);
   RM_LogTradeResult("MarketOrder", req, res);
   outResult = res;
   if(!sent || !RM_IsDoneRetcode(res.retcode)) return 0;
   return res.order;
}

// MT4: OrderSend(symbol, OP_BUYLIMIT/OP_SELLLIMIT/OP_BUYSTOP/OP_SELLSTOP, lot, price, slippage, sl,
// tp, comment, magic, 0, color) -> MT5: TRADE_ACTION_PENDING.
ulong RM_SendPendingOrder(string symbol, ENUM_ORDER_TYPE type, double lot, double price, double sl,
                           double tp, int slippage, string comment, int magic, MqlTradeResult &outResult)
{
   MqlTradeRequest req; ZeroMemory(req);
   MqlTradeResult  res; ZeroMemory(res);

   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = symbol;
   req.volume       = lot;
   req.type         = type;
   req.price        = price;
   req.sl           = sl;
   req.tp           = tp;
   req.deviation    = slippage;
   req.magic        = magic;
   req.comment      = comment;
   req.type_filling = RM_GetFillingMode(symbol);
   // [Stage 3 judgment call #4] MT4's OrderSend() call for pendings passes expiration=0 (never
   // expires / GTC). ORDER_TIME_GTC is the direct MT5 equivalent, not a new choice.
   req.type_time    = ORDER_TIME_GTC;

   bool sent = OrderSend(req, res);
   RM_LogTradeResult("PendingOrder", req, res);
   outResult = res;
   if(!sent || !RM_IsDoneRetcode(res.retcode)) return 0;
   return res.order;
}

// MT4: OrderModify(ticket, openPrice, sl, tp, 0, color) on an OPEN POSITION -> MT5: TRADE_ACTION_SLTP.
// (Distinct from TRADE_ACTION_MODIFY, which is for editing a still-pending order's price/SL/TP -
// not used anywhere in this file, since ManualBE/ManualBE_BasketAverage/CheckSLTampering only ever
// call OrderModify() on already-open positions in the original, never on pendings.)
bool RM_ModifyPositionSLTP(ulong ticket, double sl, double tp)
{
   if(!PositionSelectByTicket(ticket)) return false;

   MqlTradeRequest req; ZeroMemory(req);
   MqlTradeResult  res; ZeroMemory(res);
   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = PositionGetString(POSITION_SYMBOL);
   req.sl       = sl;
   req.tp       = tp;

   bool sent = OrderSend(req, res);
   RM_LogTradeResult("ModifySLTP", req, res);
   return sent && RM_IsDoneRetcode(res.retcode);
}

// MT4: OrderClose(ticket, lots, price, slippage, color) (full OR partial - same call, smaller
// `lots` for a partial close) -> MT5: TRADE_ACTION_DEAL with request.position=ticket, opposite
// request.type, request.volume=amount to close. Same action for full or partial, matching MT4.
bool RM_ClosePosition(ulong ticket, double volume, int slippage, MqlTradeResult &outResult)
{
   if(!PositionSelectByTicket(ticket)) return false;
   string symbol  = PositionGetString(POSITION_SYMBOL);
   long   posType = PositionGetInteger(POSITION_TYPE);

   MqlTradeRequest req; ZeroMemory(req);
   MqlTradeResult  res; ZeroMemory(res);
   req.action       = TRADE_ACTION_DEAL;
   req.position     = ticket;
   req.symbol       = symbol;
   req.volume       = volume;
   req.type         = (posType==POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY; // opposite direction closes the position
   req.price        = (posType==POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol,SYMBOL_BID) : SymbolInfoDouble(symbol,SYMBOL_ASK);
   req.deviation    = slippage;
   req.type_filling = RM_GetFillingMode(symbol);

   bool sent = OrderSend(req, res);
   RM_LogTradeResult("ClosePosition", req, res);
   outResult = res;
   return sent && RM_IsDoneRetcode(res.retcode);
}

//+------------------------------------------------------------------+
// Trade Execution — Entry / Break Even / Half Close / Full Close / منوها
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void ProcessClick(double price)
{
   if(g_step==STEP_ENTRY)
   {
      g_entryPrice=price;
      ObjectDelete(0,LN_CUR);
      HLine(LN_ENT,price,clrDodgerBlue,2,STYLE_DASH);
      // v36 (Change 5): لیبل متنی "Entry" کنار خط ورود - قبلاً فقط خط بدون متن بود
      if(ObjectFind(0, LN_ENT+"_LBL") >= 0) ObjectDelete(0, LN_ENT+"_LBL");
      ObjectCreate(0, LN_ENT+"_LBL", OBJ_TEXT, 0, TimeCurrent(), price);
      ObjectSetString(0,  LN_ENT+"_LBL", OBJPROP_TEXT,      "Entry");
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_COLOR,     clrWhite);
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_FONTSIZE,  9);
      ObjectSetString(0,  LN_ENT+"_LBL", OBJPROP_FONT,      "Arial Bold");
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_ANCHOR,    ANCHOR_LOWER);
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_BACK,      false);
      g_step=STEP_SL;
      SetStatus(">> Click: SL level",clrYellow);
      ChartRedraw();
   }
   else if(g_step==STEP_SL)
   {
      g_slPrice=price;
      ObjectDelete(0,LN_CUR);
      ObjectDelete(0,LN_CUR+"_LBL");
      ObjectDelete(0,LN_TYPE); // v36 (Change 5): پیش‌نمایش نوع سفارش کنار cursor دیگه لازم نیست
      // [Stage 3] MT4 Ask/Bid (implicit, live globals) -> MT5 SymbolInfoDouble(_Symbol, SYMBOL_ASK/BID).
      // Cached once per function call, same as every other translated site in this file.
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ref=(g_mode==MODE_MARKET)?(ask+bid)/2.0:g_entryPrice;
      g_isBuy=(g_slPrice<ref);
      // v75.13 (MT4 v90 FEAT-044): Scale-in فعال است -> ورود جدید باید هم‌جهت زنجیره‌ی انتخاب‌شده باشد (جهت از طرف کلیک SL معلوم شد). اگر مخالف بود
      // رد می‌شود، Scale-in روشن می‌ماند تا تریدر دوباره امتحان کند؛ اگر زنجیره دیگر معتبر نیست (بسته شد / سقف صفر شد) Scale-in خاموش می‌شود.
      if(g_scaleInOn)
      {
         string whyVal;
         double capVal = ScaleInCapUSD(g_scaleInRoot, whyVal);
         if(capVal <= 0)
         {
            g_step=STEP_IDLE; ResetLines(); UpdateModeButtons();
            ScaleInTurnOff();
            SetStatus("Scale-in refused: "+whyVal, clrRed);
            ChartRedraw();
            return;
         }
         if(g_isBuy != ScaleInChainIsBuy(g_scaleInRoot))
         {
            g_step=STEP_IDLE; ResetLines(); UpdateModeButtons();
            SetStatus("Scale-in: must be same direction ("+(ScaleInChainIsBuy(g_scaleInRoot)?"BUY":"SELL")+") - retry", clrRed);
            ChartRedraw();
            return;
         }
      }
      if(g_mode==MODE_MARKET) g_entryPrice=g_isBuy?ask:bid;
      double dist=MathAbs(g_entryPrice-g_slPrice);
      g_tpPrice=NormalizeDouble(g_isBuy?g_entryPrice+dist*g_riskReward:g_entryPrice-dist*g_riskReward,_Digits);
      HLine(LN_ENT,g_entryPrice,clrDodgerBlue,2,STYLE_DASH);
      HLine(LN_SL, g_slPrice,   clrRed,       2,STYLE_SOLID);
      HLine(LN_TP, g_tpPrice,   clrLimeGreen, 2,STYLE_SOLID);

      // محاسبه سود/ضرر دلاری
      // BUG-036 (v44): همون فیکس پیش‌نمایش زنده‌ی بالا (MOUSE_MOVE) - این بلاک هم درست قبل از
      // AutoExecute() صدا زده می‌شه و لیبل‌های نهایی SL/TP رو می‌سازه، پس باید همون riskToUse
      // (نصف‌شده وقتی Half Risk فعاله) رو ببینه، نه g_effRiskPerTrade خام رو.
      double slPipsCalc = MathAbs(g_entryPrice-g_slPrice)/(_Point*PipFactor());
      double previewRisk = GetEntryRiskPct();   // v75.13: در حالت Scale-in سقف زنجیره، وگرنه همان GetActiveRiskPct()
      double lot  = CalcLot(slPipsCalc, previewRisk);
      double pipVal = GetPipValueForSymbol(_Symbol, _Point, PipFactor());
      double tpPipsCalc = MathAbs(g_tpPrice - g_entryPrice) / (_Point*PipFactor());
      double lossAmt   = NormalizeDouble(lot * slPipsCalc * pipVal, 2);
      double profitAmt = NormalizeDouble(lot * tpPipsCalc * pipVal, 2);

      // لیبل روی خط SL
      if(ObjectFind(0, LN_SL+"_LBL") >= 0) ObjectDelete(0, LN_SL+"_LBL");
      ObjectCreate(0, LN_SL+"_LBL", OBJ_TEXT, 0, TimeCurrent(), g_slPrice);
      ObjectSetString(0,  LN_SL+"_LBL", OBJPROP_TEXT,      "Stop Loss  -$"+DoubleToString(lossAmt,2));
      ObjectSetInteger(0, LN_SL+"_LBL", OBJPROP_COLOR,     clrWhite);
      ObjectSetInteger(0, LN_SL+"_LBL", OBJPROP_FONTSIZE,  9);
      ObjectSetString(0,  LN_SL+"_LBL", OBJPROP_FONT,      "Arial Bold");
      ObjectSetInteger(0, LN_SL+"_LBL", OBJPROP_ANCHOR,    ANCHOR_LOWER);
      ObjectSetInteger(0, LN_SL+"_LBL", OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, LN_SL+"_LBL", OBJPROP_BACK,      false);

      // لیبل روی خط TP
      if(ObjectFind(0, LN_TP+"_LBL") >= 0) ObjectDelete(0, LN_TP+"_LBL");
      ObjectCreate(0, LN_TP+"_LBL", OBJ_TEXT, 0, TimeCurrent(), g_tpPrice);
      ObjectSetString(0,  LN_TP+"_LBL", OBJPROP_TEXT,      "Target  +$"+DoubleToString(profitAmt,2));
      ObjectSetInteger(0, LN_TP+"_LBL", OBJPROP_COLOR,     clrWhite);
      ObjectSetInteger(0, LN_TP+"_LBL", OBJPROP_FONTSIZE,  9);
      ObjectSetString(0,  LN_TP+"_LBL", OBJPROP_FONT,      "Arial Bold");
      ObjectSetInteger(0, LN_TP+"_LBL", OBJPROP_ANCHOR,    ANCHOR_LOWER);
      ObjectSetInteger(0, LN_TP+"_LBL", OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, LN_TP+"_LBL", OBJPROP_BACK,      false);

      // لیبل روی خط Entry - v36 (Change 5): توی Market mode تا همین لحظه خط Entry اصلاً وجود
      // نداشت (چون قیمت ورود تا کلیک SL معلوم نبود)، پس لیبلش هم باید همینجا برای اولین بار
      // ساخته بشه؛ توی Pending mode از STEP_ENTRY از قبل هست، اینجا فقط رفرش می‌شه.
      if(ObjectFind(0, LN_ENT+"_LBL") >= 0) ObjectDelete(0, LN_ENT+"_LBL");
      ObjectCreate(0, LN_ENT+"_LBL", OBJ_TEXT, 0, TimeCurrent(), g_entryPrice);
      ObjectSetString(0,  LN_ENT+"_LBL", OBJPROP_TEXT,      "Entry");
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_COLOR,     clrWhite);
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_FONTSIZE,  9);
      ObjectSetString(0,  LN_ENT+"_LBL", OBJPROP_FONT,      "Arial Bold");
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_ANCHOR,    ANCHOR_LOWER);
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, LN_ENT+"_LBL", OBJPROP_BACK,      false);
      ObjectSetString(0,P+"L_ENT",OBJPROP_TEXT,"Entry:"+DoubleToString(g_entryPrice,_Digits));
      ObjectSetString(0,P+"L_SL2",OBJPROP_TEXT,"SL:   "+DoubleToString(g_slPrice,_Digits));
      ObjectSetString(0,P+"L_TP2",OBJPROP_TEXT,"TP:   "+DoubleToString(g_tpPrice,_Digits));
      g_step=STEP_IDLE;
      ChartRedraw();
      AutoExecute();
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// === v75.13 (MT4 v90 FEAT-044 فاز ۱): جریان دکمه‌ی Scale-in ===
// ScaleInTurnOff: دکمه را خاموش می‌کند (بعد از اجرا / Cancel / زنجیره‌ی نامعتبر) و پنجره‌ی انتخابگر را می‌بندد.
// ScaleInSelectChain: زنجیره‌ی انتخاب‌شده را ثبت و دکمه را بنفش می‌کند. ScaleInButtonClick: رفتار کلیک روی دکمه (۰ / ۱ / ۲+ زنجیره‌ی مجاز).
//+------------------------------------------------------------------+
void ScaleInTurnOff()
{
   g_scaleInOn   = false;
   g_scaleInRoot = 0;
   CloseScaleInPicker();
   UpdateScaleInButton();
}

string ScaleInChainInfoText(ulong root, double capUSD)
{
   int idxRoot = FindSnapshotIndex(root);
   string dir = ScaleInChainIsBuy(root) ? "BUY" : "SELL";
   string tag = (idxRoot>=0) ? GetTagStrategy(root) : "N/A";
   if(StringLen(tag) > 8) tag = StringSubstr(tag,0,8);
   return "Scale-in "+dir+" | $"+DoubleToString(capUSD,2)+(tag!="N/A" ? " | "+tag : "");
}

void ScaleInSelectChain(ulong root, double capUSD)
{
   g_scaleInOn   = true;
   g_scaleInRoot = root;
   CloseScaleInPicker();
   UpdateScaleInButton();
   SetStatus(ScaleInChainInfoText(root, capUSD), C'170,110,230');
}

void ScaleInButtonClick()
{
   // کلیک وقتی روشن است => خاموش (Cancel)
   if(g_scaleInOn || g_scaleInPickerOpen)
   {
      bool wasOn = g_scaleInOn;
      ScaleInTurnOff();
      if(g_step != STEP_IDLE){ g_step=STEP_IDLE; UpdateModeButtons(); ResetLines(); }
      SetStatus(wasOn ? "Scale-in: OFF" : "Scale-in: cancelled", clrOrange);
      return;
   }
   if(!IsTradingAllowed()) return;  // قفل‌های Cooldown/DD همچنان برقرارند (همان رفتار Market/Pending)

   // ورود در حال انجام (کلیک SL/Entry منتظر) با ریسک عادی شروع شده؛ برای شروع تمیز زیر Scale-in لغو می‌شود
   if(g_step != STEP_IDLE){ g_step=STEP_IDLE; UpdateModeButtons(); ResetLines(); }
   string whyNone = "";
   int n = BuildScaleInCandidates(whyNone);
   if(n == 0)
   {
      UpdateScaleInButton();
      SetStatus("Scale-in: "+whyNone, clrOrange);
      return;
   }
   if(n == 1)
   {
      ScaleInSelectChain(g_scCandRoot[0], g_scCandCap[0]);
      return;
   }
   OpenScaleInPicker();   // ۲+ زنجیره: انتخابگر (RM_Tools.mq5)
   SetStatus("Scale-in: pick a trade ("+IntegerToString(n)+")", C'170,110,230');
}

void AutoExecute()
{
   // check cooldown
   if(!IsTradingAllowed())
   {
      string cdMsg = "";
      if(g_mktCooldownEnd>0 && TimeCurrent()<g_mktCooldownEnd) cdMsg="Market Cooldown active";
      else cdMsg="Behavior Cooldown active";
      SetStatus("BLOCKED: "+cdMsg, clrRed);
      return;
   }
   string reason="";
   // v75.13 (MT4 v90 FEAT-044): Scale-in - اعتبار زنجیره و جهت دوباره (لحظه‌ی EXECUTE) چک می‌شود؛ ریسک از سقف زنده‌ی زنجیره می‌آید، نه از دکمه‌ی Full/Half.
   bool    scaleIn   = g_scaleInOn;
   ulong   scRoot    = g_scaleInRoot;
   double  scCapUSD  = 0.0;
   if(scaleIn)
   {
      string scWhy;
      scCapUSD = ScaleInCapUSD(scRoot, scWhy);
      if(scCapUSD <= 0)
      {
         ResetLines(); ScaleInTurnOff();
         SetStatus("Scale-in refused: "+scWhy, clrRed);
         return;
      }
      if(g_isBuy != ScaleInChainIsBuy(scRoot))
      {
         ResetLines();
         SetStatus("Scale-in: must be same direction as chain - retry", clrRed);
         return;
      }
   }
   // v9.4: اگه Half Risk فعال باشه، فقط برای همین یک ورود ریسک نصف می‌شه
   double riskToUse = GetEntryRiskPct();   // v75.13: منبع واحد ریسک فعلی (Full/1/2/1/4/1/8)؛ در حالت Scale-in سقف زنجیره
   if(!CheckLimits(reason, riskToUse)){ SetStatus("BLOCKED:"+reason,clrRed); Alert("RM:"+reason); return; }
   // v75.13 (MT4 v91): ورود Scale-in از نوع Market - فاصله‌ی SL از قیمت واقعیِ لحظه‌ی اجرا (Ask/Bid) حساب می‌شود، نه قیمت کلیک؛
   // چون بین کلیک و EXECUTE قیمت حرکت می‌کند و ریسک ورود از سقف زنجیره بیشتر می‌شد. ورودهای عادی بدون تغییر.
   double refEntryForLot = g_entryPrice;
   if(scaleIn && g_mode==MODE_MARKET)
   {
      refEntryForLot = g_isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if((g_isBuy && g_slPrice >= refEntryForLot) || (!g_isBuy && g_slPrice <= refEntryForLot))
      {
         ResetLines();
         SetStatus("Scale-in: price already beyond SL - retry", clrRed);
         return;
      }
   }
   double slPips=MathAbs(refEntryForLot-g_slPrice)/(_Point*PipFactor());
   double lot=CalcLot(slPips,riskToUse);
   if(lot<=0)
   {
      if(scaleIn) SetStatus("Scale-in: lot below broker minimum for $"+DoubleToString(scCapUSD,2)+" - widen/adjust SL", clrRed);   // Scale-in روشن می‌ماند
      else        SetStatus("Lot=0",clrRed);
      return;
   }
   ulong ticket=0;
   string cmt="RM_RR"+DoubleToString(g_riskReward,1);
   double sl=NormalizeDouble(g_slPrice,_Digits),tp=NormalizeDouble(g_tpPrice,_Digits);
   MqlTradeResult tres; ZeroMemory(tres);
   if(g_mode==MODE_MARKET)
      ticket=RM_SendMarketOrder(_Symbol, g_isBuy, lot, sl, tp, Slippage, cmt, MagicNumber, tres);
   else
   {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double mid=(ask+bid)/2.0; ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)-1; bool haveType=false;
      if( g_isBuy&&g_entryPrice<mid){ type=ORDER_TYPE_BUY_LIMIT;  haveType=true; }
      if( g_isBuy&&g_entryPrice>mid){ type=ORDER_TYPE_BUY_STOP;   haveType=true; }
      if(!g_isBuy&&g_entryPrice>mid){ type=ORDER_TYPE_SELL_LIMIT; haveType=true; }
      if(!g_isBuy&&g_entryPrice<mid){ type=ORDER_TYPE_SELL_STOP;  haveType=true; }
      if(!haveType){ SetStatus("Pending type error",clrRed); return; }
      ticket=RM_SendPendingOrder(_Symbol, type, lot, g_entryPrice, sl, tp, Slippage, cmt, MagicNumber, tres);
   }
   if(ticket>0)
   {
      // v11 (FEAT-016): Trade Snapshot - رکورد تغییرناپذیر همین لحظه (Market یا Pending) ثبت می‌شه.
      // مقادیر مستقیم از خود اردر (نه از متغیرهای موقت g_entryPrice/g_slPrice) خونده می‌شن تا
      // دقیقاً همون چیزی باشه که بروکر واقعاً ثبت کرده.
      if(PositionSelectByTicket(ticket))
      {
         double snapEntry = PositionGetDouble(POSITION_PRICE_OPEN);
         double snapSL    = PositionGetDouble(POSITION_SL);
         double snapSLPips = MathAbs(snapEntry-snapSL)/(_Point*PipFactor());
         double snapPipVal = GetPipValueForSymbol(_Symbol, _Point, PipFactor());
         double snapRiskUSD = snapSLPips * snapPipVal * PositionGetDouble(POSITION_VOLUME);
         double snapBal = AccountInfoDouble(ACCOUNT_BALANCE);
         double snapRiskPct = (snapBal>0) ? snapRiskUSD/snapBal*100.0 : 0;
         // v19 (BUG-022): g_halfRiskActive در همین لحظه (نه بعداً از روی درصد ریسک یا حجم لات)
         // ثبت می‌شه - این همون فلگ صریحی که EA در لحظه‌ی باز شدن معامله واقعاً داشته.

         // v61 (فیلدهای رفتاری لحظه‌ی باز شدن معامله، ۱ از ۳): برای Market، لحظه‌ی «فعال‌شدن
         // واقعی» دقیقاً همین‌جا و همین الانه، پس مقادیر واقعی همین‌جا خونده می‌شن. برای
         // Pending، این لحظه فقط «ثبت» است نه فعال‌شدن واقعی (که ممکنه دقایق/ساعت‌ها بعد،
         // در CheckPendingActivation اتفاق بیفته) - پس فقط placeholder (صفر/false) پاس داده
         // می‌شه؛ مقدار واقعی بعداً با SetSnapshotBehaviorFieldsAtActivation پر می‌شه
         // (RM_CooldownEngine.mqh) دقیقاً در لحظه‌ی فعال‌شدن واقعی.
         double behErrAtOpen = 0.0; bool duringLock = false; bool intervalViol = false;
         double dailyPctAtOpen = 0.0, weeklyPctAtOpen = 0.0;
         // v64 (آیتم ۱ - PriorDayResult): placeholder برای Pending (N/A=-2) - دقیقاً هم‌الگوی
         // ۵ فیلد رفتاری v61 بالا؛ مقدار واقعی بعداً در CheckPendingActivation پر می‌شه.
         double priorDayResultAtOpen = -2.0;
         // v64 (آیتم ۶ - TimeframeAtOpen): placeholder برای Pending (0=N/A) - همون الگوی
         // PriorDayResult بالا؛ مقدار واقعی بعداً در CheckPendingActivation پر می‌شه.
         double timeframeAtOpen = 0.0;
         // v75.13 (MT4 v90 FEAT-044): پارامترهای ورود ادامه. وزن = ریسک واقعی ورود ÷ ریسک Full (balance x RiskPerTrade%) در همین لحظه، کلمپ (0,1].
         // ریشه = ریشه‌ی زنجیره‌ی هدف؛ RiskBase = ریسک ریشه (پایه‌ی R زنجیره)؛ RiskUSD خودِ پوزیشن همان snapRiskUSD واقعی می‌ماند.
         double  wStep   = 1.0 / (double)RiskStepDivisor(g_riskStep);
         bool    wasHalf = g_halfRiskActive;
         ulong   rootForSnap = ticket;
         double  riskBaseForSnap = 0.0;
         if(scaleIn)
         {
            double fullRiskUSD = AccountInfoDouble(ACCOUNT_BALANCE)*g_effRiskPerTrade/100.0;
            double w = (fullRiskUSD>0) ? snapRiskUSD/fullRiskUSD : 1.0;
            if(w > 1.0) w = 1.0;
            if(w <= 0.0) w = 0.0001;
            wStep = w; wasHalf = false;
            rootForSnap = scRoot;
            int idxScRoot = FindSnapshotIndex(scRoot);
            riskBaseForSnap = (idxScRoot>=0) ? SnapRiskBase(idxScRoot) : 0.0;
            if(snapRiskUSD > scCapUSD + 0.01)
               Print("RM WARNING: Scale-in entry risk $", DoubleToString(snapRiskUSD,2), " exceeds cap $", DoubleToString(scCapUSD,2), " (ticket #", ticket, ")");
         }
         if(g_mode == MODE_MARKET)
         {
            duringLock      = IsCooldownLockActiveNow();
            intervalViol    = scaleIn ? false : WouldViolateEntryInterval();   // v75.13: ورود ادامه معاف
            behErrAtOpen    = GetBehaviorErrorTotal();
            // v61 bugfix (BUG-048): GetTotalOpenRisk() (که GetDailyRisk/GetWeeklyDrawdown داخلی
            // ازش استفاده می‌کنن) این تیکت تازه‌ساخته‌شده رو هم چون از قبل جزو OrdersTotal()
            // است حساب می‌کرد - یعنی این دو فیلد به‌جای «قبل از این معامله»، «شامل خودِ این
            // معامله» رو نشون می‌دادن. فیکس: نسخه‌ی Excluding (RM_RiskCalc.mqh/
            // RM_DrawdownEngine.mqh) که همین تیکت رو از جمع ریسک باز کنار می‌ذاره.
            dailyPctAtOpen  = (g_effMaxDailyRisk>0) ? (GetDailyRiskExcludingTicket(ticket)/g_effMaxDailyRisk*100.0)      : 0.0;
            weeklyPctAtOpen = (g_effMaxWeeklyDD>0)  ? (GetWeeklyDrawdownExcludingTicket(ticket)/g_effMaxWeeklyDD*100.0)  : 0.0;
            // v64: برای Market، لحظه‌ی فعال‌شدن واقعی همین‌جاست - مقدار زنده‌ی g_priorDayResultCode
            // (RiskManager_EA_v64.mq4/RM_DrawdownEngine.mqh) همین الان خونده می‌شه.
            priorDayResultAtOpen = g_priorDayResultCode;
            // v64: برای Market، لحظه‌ی فعال‌شدن واقعی همین‌جاست - تایم‌فریم زنده‌ی چارت.
            timeframeAtOpen = (double)Period();
         }

         SaveTradeSnapshot(ticket, snapEntry, snapSL, snapRiskUSD, snapRiskPct, (datetime)PositionGetInteger(POSITION_TIME), (int)PositionGetInteger(POSITION_MAGIC), 0.0, false, wasHalf,
                           behErrAtOpen, duringLock, intervalViol, false, dailyPctAtOpen, weeklyPctAtOpen,
                           priorDayResultAtOpen, 0, -1.0, timeframeAtOpen, 0.0, wStep,
                           rootForSnap, scaleIn, riskBaseForSnap);   // v75.13 (MT4 v86/v90): ریشه / ادامه / پایه‌ی R

         // v61: رویداد «باز شدن وسط قفل Cooldown» - برای Market عملاً همیشه false می‌مونه چون
         // IsTradingAllowed() بالاتر (شروع AutoExecute) قبلاً جلوی اجرا رو گرفته بود؛ فقط برای
         // تقارن/درستی در حالت‌های لبه‌ای اینجا هم چک می‌شه. تخلف Entry Interval توسط خودِ
         // RunEntryIntervalCheck پایین‌تر شمارش می‌شه (تا دوبار شمرده نشه).
         if(g_mode == MODE_MARKET && duringLock) IncrementBehaviorErrorTotal();
      }
      // v74.5 (HF5): پندینگِ هنوز-فعال‌نشده پوزیشن ندارد، پس PositionSelectByTicket بالا false بود و
      // Snapshot ساخته نمی‌شد (باگ B7). مثل MT4 (OrderOpenPrice/OrderStopLoss/OrderLots/OrderOpenTime
      // خودِ اردر) همین‌جا از روی خودِ اردر ثبت می‌شه. در حساب Hedging تیکت پوزیشنِ بعد از فعال‌شدن
      // دقیقاً همین تیکت اردره، پس هیچ re-key لازم نیست. فیلدهای «لحظه‌ی باز شدن» placeholder می‌مونن
      // و CheckPendingActivation هنگام فعال‌شدن واقعی پرشون می‌کنه.
      else if(g_mode != MODE_MARKET && OrderSelect(ticket))
      {
         double pEntry    = OrderGetDouble(ORDER_PRICE_OPEN);
         double pSL       = OrderGetDouble(ORDER_SL);
         double pSLPips   = MathAbs(pEntry-pSL)/(_Point*PipFactor());
         double pPipVal   = GetPipValueForSymbol(_Symbol, _Point, PipFactor());
         double pRiskUSD  = pSLPips * pPipVal * OrderGetDouble(ORDER_VOLUME_CURRENT);
         double pBal      = AccountInfoDouble(ACCOUNT_BALANCE);
         double pRiskPct  = (pBal>0) ? pRiskUSD/pBal*100.0 : 0;
         // v75.13 (MT4 v90): ورود ادامه‌ی Pending - همان منطق وزن/ریشه/پایه‌ی R
         double  pwStep = 1.0/(double)RiskStepDivisor(g_riskStep);
         bool    pWasHalf = g_halfRiskActive;
         ulong   pRoot = ticket;
         double  pBase = 0.0;
         if(scaleIn)
         {
            double pFull = pBal*g_effRiskPerTrade/100.0;
            double pw = (pFull>0) ? pRiskUSD/pFull : 1.0;
            if(pw > 1.0) pw = 1.0;
            if(pw <= 0.0) pw = 0.0001;
            pwStep = pw; pWasHalf = false;
            pRoot = scRoot;
            int idxPRoot = FindSnapshotIndex(scRoot);
            pBase = (idxPRoot>=0) ? SnapRiskBase(idxPRoot) : 0.0;
            if(pRiskUSD > scCapUSD + 0.01)
               Print("RM WARNING: Scale-in pending risk $", DoubleToString(pRiskUSD,2), " exceeds cap $", DoubleToString(scCapUSD,2), " (order #", ticket, ")");
         }
         SaveTradeSnapshot(ticket, pEntry, pSL, pRiskUSD, pRiskPct, (datetime)OrderGetInteger(ORDER_TIME_SETUP), (int)OrderGetInteger(ORDER_MAGIC), 0.0, false, pWasHalf,
                           0.0, false, false, false, 0.0, 0.0,
                           -2.0, 0, -1.0, 0.0, 0.0, pwStep,
                           pRoot, scaleIn, pBase);
         Print("[RM-PEND] snapshot created for order #"+IntegerToString(ticket)+" (pending; position id will equal the order ticket, source=placement) risk="+DoubleToString(pRiskUSD,2)+" halfRisk="+(g_halfRiskActive?"1":"0"));
      }

      // v9.6: دیگه بعد از معامله ریست نمی‌شه؛ حالت ریسک (Full/Half) تا کلیک بعدی همون می‌مونه
      bool wasHalfRisk = (g_halfRiskActive && !scaleIn);
      string riskTag = RiskStepName(g_riskStep);
      // === v9.8: زمان واقعی فعال‌شدن ملاک Behavior Strike است ===
      // Market: همین الان فعال شده -> فوراً چک کن
      // Pending: هنوز فعال نشده -> فقط برای ردیابی بعدی ثبتش کن
      if(g_mode == MODE_MARKET)
         RunEntryIntervalCheck(scaleIn);   // v75.13: ورود ادامه -> بدون Strike و بدون به‌روزرسانی g_lastEntryTime
      else
         AddPendingTrack(ticket);
      // ====================================================================

      string okMsg = "OK #"+IntegerToString(ticket)+" "+(g_isBuy?"BUY":"SELL")+" "+DoubleToString(lot,2)+"L";
      if(scaleIn) okMsg += " [Scale-in "+IntegerToString(scRoot)+"]";
      else if(wasHalfRisk) okMsg += " ["+riskTag+" Risk]"; // v8 (BUG-011): تگ روی همون خط وضعیت، نه خط جدا
      SetStatus(okMsg, clrLimeGreen);
      ResetLines();
      if(scaleIn) ScaleInTurnOff();   // v75.13: یک‌بارمصرف - بعد از اجرا خودکار خاموش
      // پاک کردن آبجکت‌های خودکار MT4 (Arrow و Trendline مربوط به اردر)
      string tickStr = "#"+IntegerToString(ticket);
      for(int i=ObjectsTotal(0)-1; i>=0; i--)
      {
         string objName = ObjectName(0,i);
         if(StringFind(objName, tickStr) >= 0)
            ObjectDelete(0, objName);
      }
   }
   else SetStatus("Err retcode "+IntegerToString(tres.retcode),clrRed);
   UpdateRiskDisplay();
}

void ManualBE()
{
   // v14 (Advanced Break Even): همون دکمه‌ی موجود - بر اساس Input تصمیم می‌گیره کدوم منطق اجرا بشه.
   // هیچ دکمه‌ی جدیدی اضافه نشده. حالت پیش‌فرض (BE_INDIVIDUAL) دقیقاً همون رفتار قبلی v13 و قبل‌تره.
   if(BreakEvenMode==BE_BASKET_AVERAGE)
   {
      ManualBE_BasketAverage();
      StartButtonFlash(P+"BTN_BE", CLR_FLASH_BE, g_beFlashEnd);  // v30: کلیک ثبت شد - چه پوزیشنی جابه‌جا شده باشه چه نه
      return;
   }

   int n=0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      // [Stage 3] این چک در MT5 عملاً همیشه true می‌مونه (لیست Position فقط BUY/SELL داره، هیچ‌وقت
      // Pending توش نیست - برخلاف لیست ترکیبی MT4) - برای وفاداری ساختاری نگه داشته شده، بی‌ضرره.
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      bool buy=(posType==POSITION_TYPE_BUY);
      // v7 (FEAT-011): همینجا هم اسپرد لحظه‌ای لحاظ می‌شه تا BE دستی هم واقعاً صفر-به-بالا باشه
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double spreadPrice = ask-bid;
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double nsl = buy ? NormalizeDouble(op+spreadPrice,_Digits)
                        : NormalizeDouble(op-spreadPrice,_Digits);
      if((buy&&bid>nsl)||(!buy&&ask<nsl))
      {
         if(RM_ModifyPositionSLTP(tk, nsl, PositionGetDouble(POSITION_TP)))
         {
            n++;
            HLine(BELineName(tk), nsl, clrAqua, 1, STYLE_DOT); // v8 (BUG-010): خط نشانه‌گر BE
            CheckPrematureAction(tk, "BE"); // v18 (BUG-021)
         }
      }
   }
   SetStatus("BE: "+IntegerToString(n)+" trades",clrAqua);
   StartButtonFlash(P+"BTN_BE", CLR_FLASH_BE, g_beFlashEnd);  // v30 (Button Click Feedback)
}

// v14 (Advanced Break Even - BasketAverage): وقتی BreakEvenMode = BasketAverage باشه، دکمه‌ی
// Break Even این تابع رو صدا می‌زنه به‌جای منطق Individual بالا. بسکت خرید و بسکت فروش جدا
// محاسبه و اعمال می‌شن (اگه هر دو هم‌زمان باز باشن). SL هر پوزیشنِ یه بسکت، به میانگین وزنی
// همون بسکت + اسپرد لحظه‌ای (گرفته‌شده دقیقاً در لحظه‌ی زدن دکمه) منتقل می‌شه - نه به نقطه‌ی
// ورود خودش. هیچ اثری روی Trailing، Half Close، محاسبه‌ی لات/ریسک یا منطق Individual بالا نداره.
//
// [Stage 3 - NOT a translation, flagging per instructions] GetBasketAveragePrice() itself is
// called here but defined outside RM_TradeExecution.mqh (not in this stage's source, likely
// RM_Trailing.mqh or RM_AutoActions.mqh - neither provided). Its exact weighted-average formula is
// therefore unknown to me and NOT reproduced/guessed anywhere in this port - the call below is left
// exactly as the original called it (same signature, same by-reference bool+double pattern), so
// once its real source is ported this line needs no changes. See report: this is a stop-and-ask
// item, not a silent guess.
void ManualBE_BasketAverage()
{
   int n=0;
   double avgBuy=0, avgSell=0;
   bool hasBuy  = GetBasketAveragePrice(true,  avgBuy);
   bool hasSell = GetBasketAveragePrice(false, avgSell);

   // v14 (فیدبک کاربر): اسپرد لحظه‌ای رو یه بار، در همون لحظه‌ی زدن دکمه، به میانگین بسکت اضافه می‌کنیم -
   // دقیقاً همون منطق FEAT-011 که توی Individual/CheckAutoBE هست (nsl = op + spread، نه فقط op).
   // بدون این، با میانگینِ خام، SL می‌تونست دقیقاً روی میانگین بخوره و به‌خاطر اسپرد یه ضرر خیلی کوچیک بده.
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double spreadPrice = ask-bid;
   if(hasBuy)  avgBuy  = NormalizeDouble(avgBuy  + spreadPrice, _Digits);
   if(hasSell) avgSell = NormalizeDouble(avgSell - spreadPrice, _Digits);

   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;

      bool buy=(posType==POSITION_TYPE_BUY);
      if(buy  && !hasBuy)  continue;
      if(!buy && !hasSell) continue;

      double nsl = buy ? avgBuy : avgSell;
      // همون محافظتِ منطق Individual: فقط وقتی قیمت لحظه‌ای واقعاً جلوتر از نقطه‌ی میانگین(+اسپرد)ه اعمال می‌شه،
      // وگرنه ممکنه SL بلافاصله باعث استاپ‌اوت بشه (مثلاً وقتی میانگین هنوز طرف ضرره).
      if((buy && bid>nsl) || (!buy && ask<nsl))
      {
         if(RM_ModifyPositionSLTP(tk, nsl, PositionGetDouble(POSITION_TP)))
         {
            n++;
            HLine(BasketAvgLineName(buy), nsl, clrAqua, 1, STYLE_DOT); // v14: خط میانگین بسکت روی چارت
            CheckPrematureAction(tk, "BE Basket"); // v18 (BUG-021)
         }
      }
   }

   if(!hasBuy && !hasSell)
   {
      SetStatus("BE Basket: no positions", clrAqua);
      return;
   }
   string msg = "BE Basket: "+IntegerToString(n)+" trades";
   if(hasBuy)  msg += " | Buy@"+DoubleToString(avgBuy,_Digits);
   if(hasSell) msg += " | Sell@"+DoubleToString(avgSell,_Digits);
   SetStatus(msg, clrAqua);
}

// v37 PART A (تست تشخیصی): پارامتر onlyProfitable اضافه شد - فعلاً بدون مقدار پیش‌فرض و بدون
// منوی UI - فقط برای تست اینکه خودِ تغییر امضای تابع مشکلی نداره. BTN_HALF فعلاً موقتاً با
// HalfClose(false) صدا زده می‌شه (دقیقاً همون رفتار قدیمی تک‌کلیکی) تا این بخش رو جدا از تغییرات
// UI بشه تست کرد.
// v40 (FEAT-019): هسته‌ی Half Close برای یک تیکت مشخص، با درصد دلخواه - از داخل بدنه‌ی قدیمی
// HalfClose() استخراج شده (بدون هیچ تغییر رفتاری - همون فرمول NormalizeDouble(lots*درصد,2)،
// همون ترتیب عملیات‌ها) تا هم مسیر دستی/تأییدی (با درصد ثابت 50) و هم Auto Half Close جدید
// (با درصد قابل‌تنظیم AutoHalfClosePercent) از یک منطق core استفاده کنن - چیزی دوباره‌نویسی
// نشده. reasonTag فقط برای متن Print/Alert داخل CheckPrematureAction فرق می‌کنه (تشخیص
// دستی/خودکار در لاگ)، تأثیری روی خودِ منطق Strike نداره. true برمی‌گردونه یعنی واقعاً بسته شد.
bool HalfCloseTicket(ulong tkt, double closePercent, string reasonTag)
{
   if(!PositionSelectByTicket(tkt)) return false;
   if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) return false;
   long posType=PositionGetInteger(POSITION_TYPE);
   if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) return false;

   // v40: هر بار این تابع صدا زده می‌شه، از صفر شروع می‌شه - صفر یعنی هیچ تیکت باقیمونده‌ی
   // جدیدی ساخته نشد (مثلاً چون OrderClose کل لات رو بست، نه فقط بخشی ازش).
   g_lastHalfCloseRemainderTicket = 0;

   // v50 (وراثت Trailing به باقیمونده): قبل از هر تغییری، اگه tkt همین الان زیر پوشش
   // Trailing بود، وضعیت دقیقش (extreme/period/lastBar) همین‌جا ذخیره می‌شه - چون بعد از
   // بسته‌شدن این تیکت، RemoveTrailTicket (در CheckClosedTrades، تیک بعدی) این ردیف رو از
   // آرایه‌ی Trailing پاک می‌کنه. اگه tkt اصلاً زیر پوشش Trailing نبود (هنوز فعال نشده بود)،
   // trailIdx منفی می‌مونه و پایین‌تر هیچ وراثتی اعمال نمی‌شه - باقیمونده فقط طبق منطق عادی
   // (دکمه‌ی دستی روشن / Auto Trigger) واجدشرایط می‌مونه، دقیقاً مثل قبل.
   bool     inheritTrailing      = false;
   double   inheritTrailExtreme  = 0;
   int      inheritTrailPeriod   = 0;
   datetime inheritTrailLastBar  = 0;
   int trailIdx = FindTrailIndex(tkt);
   if(trailIdx>=0)
   {
      inheritTrailing     = true;
      inheritTrailExtreme = g_trailExtreme[trailIdx];
      inheritTrailPeriod  = g_trailPeriod[trailIdx];
      inheritTrailLastBar = g_trailLastBar[trailIdx];
   }

   // v9.3: اگه لحظه‌ی Half Close قیمت به TP1 (+1R) رسیده باشه، این تیکت از
   // Behavior Cooldown معاف می‌شه (چون این یک اقدام منظبط روی هدف بوده، نه خروج زودهنگام)
   bool buy   = (posType==POSITION_TYPE_BUY);
   double op  = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL);
   double slDist = MathAbs(op-sl);
   // v75.18: قیمت/MinLot از نماد خودِ پوزیشن (نه چارت جاری)
   string tSym = PositionGetString(POSITION_SYMBOL);
   double ask=SymbolInfoDouble(tSym,SYMBOL_ASK), bid=SymbolInfoDouble(tSym,SYMBOL_BID);
   double curPrice = buy?bid:ask;
   bool reachedTP1 = (slDist>0) && (buy ? (curPrice>=op+slDist) : (curPrice<=op-slDist));
   if(reachedTP1) AddHalfExempt(tkt);

   double closeLots = NormalizeDouble(PositionGetDouble(POSITION_VOLUME)*(closePercent/100.0), 2);
   if(closeLots<SymbolInfoDouble(tSym,SYMBOL_VOLUME_MIN)) closeLots=SymbolInfoDouble(tSym,SYMBOL_VOLUME_MIN);

   // v11 (FEAT-016): لیست تیکت‌های باز قبل از Half Close - برای تشخیص تیکت جدیدی که MT4
   // ممکنه برای باقیمونده‌ی این پوزیشن بسازه (طبق کشف v8: تیکت اصلی بسته می‌شه و یک تیکت
   // جدید برای باقیمونده باز می‌شه)
   // [Stage 3 note] MT5 partial closes on a position DO NOT create a new position ticket the way
   // MT4 could create a new order ticket for the remainder - the same position ticket simply has
   // its POSITION_VOLUME reduced. This pre/post-ticket-list comparison is kept verbatim below
   // (harmless - it will just find no new ticket, same as if MT4 hadn't split it), but in practice
   // this block is expected to be a no-op on MT5. Flagged in the report as a platform behavior
   // difference worth Mahmoud's awareness, not silently "fixed" by removing the block.
   ulong preTickets[];
   CaptureOpenTickets(preTickets);

   MqlTradeResult tres; ZeroMemory(tres);
   if(!RM_ClosePosition(tkt, closeLots, Slippage, tres)) return false;

   // v18 (BUG-021): اگه این تیکت هرگز واقعاً به +1R نرسیده بود، این Half Close یک
   // اقدام مدیریتی زودهنگام حساب می‌شه - Behavior strike اضافه می‌شه.
   CheckPrematureAction(tkt, reasonTag);

   // v11 (FEAT-016): اگه تیکت جدیدی برای باقیمونده ساخته شده، Snapshot همون لحظه
   // (بدون هیچ تغییری) به تیکت جدید کپی می‌شه - وگرنه ردیابی R باقیمونده گم می‌شه
   ulong postTickets[];
   CaptureOpenTickets(postTickets);
   for(int q=0;q<ArraySize(postTickets);q++)
   {
      ulong candidate = postTickets[q];
      if(candidate==tkt) continue;
      if(TicketInList(candidate, preTickets)) continue; // از قبل هم باز بود - جدید نیست
      if(!PositionSelectByTicket(candidate)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber || PositionGetString(POSITION_SYMBOL)!=tSym) continue;   // v75.18

      // v40 (FEAT-019): این همون تیکت باقیمونده‌ست - صداکننده (مثل CheckAutoHalfCloseTrigger)
      // می‌تونه از روی این متغیر تشخیص بده و اگه لازمه وضعیت خودش رو هم به باقیمونده منتقل کنه.
      g_lastHalfCloseRemainderTicket = candidate;

      int idxOld = FindSnapshotIndex(tkt);
      if(idxOld>=0)
         // v18 (BUG-021): MaxFavorableR هم به تیکت باقیمونده منتقل می‌شه - از نظر
         // قیمتی هر دو همون معامله‌ان، فقط حجم فرق کرده؛ R ای که قبلاً لمس شده نباید
         // برای باقیمونده از صفر شروع بشه (وگرنه یک BE/Trailing درست بعد از Half Close
         // اشتباهاً «زودهنگام» علامت می‌خوره).
         // v18 (BUG-021 refinement): وضعیت «Strike‌گرفته» هم منتقل می‌شه - اگه معامله‌ی
         // اصلی از قبل Strike گرفته، باقیمونده نباید دوباره بتونه یک Strike جدید بگیره.
         // v19 (BUG-022): WasHalfRisk هم منتقل می‌شه - باقیمونده همون معامله‌ست، پس
         // باید همون وضعیت Full/Half Risk لحظه‌ی ورود اصلی رو حفظ کنه.
         // v61: شش فیلد رفتاری لحظه‌ی باز شدن هم به باقیمونده منتقل می‌شن - از نظر قیمتی/رفتاری
         // هر دو همون معامله‌ان (فقط حجم فرق کرده)، پس این مقادیر برای باقیمونده هم دقیقاً
         // همون‌هایی‌ان که برای معامله‌ی اصلی ثبت شده بودن؛ شامل SLTampered هم می‌شه - اگه
         // معامله‌ی اصلی از قبل تمپرینگ داشته، باقیمونده هم باید همون وضعیت رو نشون بده.
         // v64: PriorDayResult و SLLoosenedCount هم به همون دلیل منتقل می‌شن - یک معامله‌ان،
         // فقط حجم تقسیم شده؛ SLLoosenedCount تا این لحظه هم باید برای باقیمونده حفظ بشه.
         SaveTradeSnapshot(candidate, g_snapEntry[idxOld], g_snapSL[idxOld],
                           g_snapRiskUSD[idxOld], g_snapRiskPct[idxOld],
                           g_snapOpenTime[idxOld], g_snapMagic[idxOld],
                           g_snapMaxFavR[idxOld], g_snapStriked[idxOld],
                           g_snapWasHalfRisk[idxOld],
                           g_snapBehaviorErrorCountAtOpen[idxOld], g_snapOpenedDuringCooldownLock[idxOld],
                           g_snapEntryIntervalViolation[idxOld], g_snapSLTampered[idxOld],
                           g_snapDailyRiskUsedPctAtOpen[idxOld], g_snapWeeklyDDUsedPctAtOpen[idxOld],
                           g_snapPriorDayResult[idxOld], g_snapSLLoosenedCount[idxOld],
                           -1.0, g_snapTimeframeAtOpen[idxOld],
                           g_snapMinFavR[idxOld], g_snapRiskWeight[idxOld]);  // v66 (آیتم ۲ب): MAE هم منتقل می‌شه - همون دلیل MaxFavR بالا، یک معامله‌ان فقط حجم تقسیم شده
         // v64: BehaviorErrorsThisTrade عمداً -1.0 (پیش‌فرض «هنوز بسته نشده») گذاشته شده - این
         // مقدار مال لحظه‌ی بسته‌شدن خودِ تیکت باقیمونده‌ست، نه چیزی که از تیکت اصلی به ارث برسه؛
         // خودش وقتی نهایتاً از CheckClosedTrades رد بشه، مقدار واقعی‌ش رو می‌گیره. TimeframeAtOpen
         // برعکس - همون لحظه‌ی باز شدن اصلی معامله‌ست (فقط حجم عوض شده)، پس به ارث می‌رسه.

      // v60 (وراثت تگ به باقیمونده): دقیقاً همون الگوی وراثت Snapshot بالا - اگه تیکت اصلی
      // (tkt) از قبل تگ Strategy/Setup داشت (v56)، همون تگ به تیکت باقیمونده هم منتقل می‌شه؛
      // وگرنه باقیمونده با N/A شروع می‌کرد چون تگ‌ها بر اساس شماره‌ی تیکت ذخیره می‌شن و تیکت
      // باقیمونده یک شماره‌ی کاملاً جدیده. فقط وقتی تیکت اصلی واقعاً تگ داشت این کار انجام
      // می‌شه (FindTagIndex>=0) تا برای معاملات تگ‌نخورده یک ردیف N/A اضافی توی آرایه‌ی تگ‌ها
      // ساخته نشه - GetTagStrategy/GetTagSetup موجود، بدون تگ رو خودشون N/A برمی‌گردونن.
      // v69 (FEAT-026): چهارمین آرگومان (Mental State) هم منتقل می‌شه - از GetTagMentalStateRaw
      // (نه GetTagMentalState) استفاده می‌شه چون این یکی مقدار خام رو برمی‌گردونه (رشته‌ی خالی
      // اگه انتخاب نشده بود)؛ نسخه‌ی دیگه فال‌بک "N/A" داره که فقط برای نمایش/Export مناسبه، نه
      // برای ذخیره‌سازی خام توی g_tagMentalState (وگرنه یه معامله‌ی بدون Mental State انتخاب‌شده
      // بعد از این وراثت با مقدار literal "N/A" ذخیره می‌شد، نه رشته‌ی خالی).
      if(FindTagIndex(tkt)>=0)
         SetTradeTag(candidate, GetTagStrategy(tkt), GetTagSetup(tkt), GetTagMentalStateRaw(tkt));

      // v50 (وراثت Trailing به باقیمونده): اگه بالاتر مشخص شد tkt واقعاً زیر پوشش Trailing
      // بود، همون وضعیت دقیق (نه شروع از نو) به تیکت باقیمونده منتقل می‌شه - از
      // InheritTrailTicket استفاده می‌شه (نه AddTrailTicket)، چون AddTrailTicket مرجع
      // extreme رو با قیمت *لحظه‌ی الان* پر می‌کنه و دوباره CheckPrematureAction رو صدا
      // می‌زنه - این یک فعال‌سازی جدید نیست، ادامه‌ی همون تصمیمیه که قبلاً روی تیکت اصلی
      // گرفته شده. اگه tkt زیر پوشش Trailing نبود، اینجا هیچ کاری انجام نمی‌شه - باقیمونده
      // فقط طبق منطق عادی (دکمه‌ی دستی / Auto Trigger) بعداً واجدشرایط می‌شه، بدون فعال‌سازی زودهنگام.
      if(inheritTrailing)
         InheritTrailTicket(candidate, inheritTrailExtreme, inheritTrailPeriod, inheritTrailLastBar);

      break; // فقط یک تیکت جدید در هر بار Half Close روی یک پوزیشن انتظار می‌ره
   }
   return true;
}

void HalfClose(bool onlyProfitable, bool chartOnly=false)
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      if(chartOnly && PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;   // v75.18: ACTIVE CHART
      if(onlyProfitable && PositionGetDouble(POSITION_PROFIT)<=0) continue;

      // v40: درصد 50 هاردکد شده - همون رفتار قدیمی تک‌کلیکی، بدون هیچ تغییری
      if(HalfCloseTicket(tk, 50.0, "Half Close")) n++;
   }
   string halfTag = chartOnly ? "Half Chart: " : (onlyProfitable ? "Half Profit: " : "Half: ");
   SetStatus(halfTag+IntegerToString(n)+" trades",clrYellow);
   StartButtonFlash(P+"BTN_HALF", CLR_FLASH_HALF, g_halfFlashEnd);  // v30 (Button Click Feedback)
}

// v15 (Advanced Close Management): رفتار اصلی Full Close - دست‌نخورده. کل حساب رو می‌بنده
// (همه‌ی نمادها با همین Magic Number)، مطابق فلسفه‌ی قبلی پروژه که Full Close باید سراسری باشه.
void FullClose()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      ulong tkFC = tk;
      double vol = PositionGetDouble(POSITION_VOLUME);
      MqlTradeResult tres; ZeroMemory(tres);
      if(RM_ClosePosition(tkFC, vol, Slippage, tres))
      {
         n++;
         CheckPrematureAction(tkFC, "Manual Close (Full)"); // v18 (BUG-021)
      }
   }
   SetStatus("Close: "+IntegerToString(n)+" trades",clrLimeGreen);
   // v30 (Button Click Feedback): BTN_FULL از قبل توسط CloseFullCloseMenu() (که همیشه قبل از
   // FullClose() صدا زده می‌شه - خط OnChartEvent مربوط به SUB_CLOSEALL) دوباره ساخته شده، پس اینجا
   // امن قابل رنگ‌آمیزیه.
   StartButtonFlash(P+"BTN_FULL", CLR_FLASH_FULL, g_fullFlashEnd);
}

// v15 (گزینه‌ی ۲ از منوی Full Close): فقط معاملات باز روی نماد چارت جاری (همون Magic Number) بسته می‌شن
void CloseChartPositions()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      ulong tkCC = tk;
      double vol = PositionGetDouble(POSITION_VOLUME);
      MqlTradeResult tres; ZeroMemory(tres);
      if(RM_ClosePosition(tkCC, vol, Slippage, tres))
      {
         n++;
         CheckPrematureAction(tkCC, "Manual Close (Chart)"); // v18 (BUG-021)
      }
   }
   SetStatus("Close Chart: "+IntegerToString(n)+" trades",clrLimeGreen);
}

// v15 (گزینه‌ی ۳ از منوی Full Close): فقط معاملاتی که الان OrderProfit() > 0 هستن - مستقل از نماد
void CloseProfitablePositions()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      if(PositionGetDouble(POSITION_PROFIT)<=0) continue;
      ulong tkCP = tk;
      double vol = PositionGetDouble(POSITION_VOLUME);
      MqlTradeResult tres; ZeroMemory(tres);
      if(RM_ClosePosition(tkCP, vol, Slippage, tres))
      {
         n++;
         CheckPrematureAction(tkCP, "Manual Close (Profit)"); // v18 (BUG-021)
      }
   }
   SetStatus("Close Profit: "+IntegerToString(n)+" trades",clrLimeGreen);
}

// v15 (گزینه‌ی ۴ از منوی Full Close): فقط معاملاتی که الان OrderProfit() < 0 هستن - مستقل از نماد
void CloseLosingPositions()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      if(PositionGetDouble(POSITION_PROFIT)>=0) continue;
      ulong tkCL = tk;
      double vol = PositionGetDouble(POSITION_VOLUME);
      MqlTradeResult tres; ZeroMemory(tres);
      if(RM_ClosePosition(tkCL, vol, Slippage, tres))
      {
         n++;
         CheckPrematureAction(tkCL, "Manual Close (Loss)"); // v18 (BUG-021)
      }
   }
   SetStatus("Close Loss: "+IntegerToString(n)+" trades",clrOrange);
}

// [Stage 3] Everything below this point (menus, select-window, SL-zero/lastSL/tamper tracking
// helpers, CheckSLTampering) uses only Object*/Chart* drawing calls (identical between MT4 build
// 600+ and MT5 - no translation needed) plus the same Position-based loop pattern already
// established above. Comments/structure preserved verbatim; only ticket types (int->ulong) and the
// same Order*->Position* substitutions apply.

// v28 (Change 6): Close submenu is now a 2x2 grid ("Close All"/"Close Chart" on top, "Close
// Profit"/"Close Loss" below), sized like the rest of the panel's buttons instead of v27's
// full-width stacked rows. It opens at g_closeMenuAnchorX/Y/W - the exact spot BuildPanel() last
// placed the Close button's row (Full Close/Trailing row in FULL, the 4-button action row in
// COMPACT) - so this still doesn't need to duplicate any layout math.
// v28 (Change 7): if the Performance box (FULL mode only) is open, it's collapsed first (and
// remembered via g_perfWasOpenBeforeSubmenu) to free up room / declutter the view while a close
// action is being chosen; CloseFullCloseMenu() restores it only if it was actually open.
// v28 (Change 6): everything except the Close button and this grid reads as neutral/grey while
// open - GreyOutPanel() dims every other colored object; a full BuildPanel() rebuild on close
// naturally restores true colors (and the true Performance state), so no manual color-restore
// bookkeeping is needed.
void OpenFullCloseMenu()
{
   // v31: BTN_FULL only exists on the Trading dashboard now (Change 1/4), so this is only ever
   // reachable while g_dashboardMode==DASH_TRADING - the check is kept for clarity/safety rather
   // than dropped.
   g_perfWasOpenBeforeSubmenu = g_perfDrawerOpen;
   if(g_dashboardMode==DASH_TRADING && g_perfDrawerOpen)
      g_perfDrawerOpen = false;

   g_fullCloseMenuOpen = true;
   ObjectsDeleteAll(0, P);
   BuildPanel();   // rebuilds the base panel (Performance collapsed for room); also refreshes g_closeMenuAnchorX/Y/W

   int corner = CORNER_LEFT_UPPER;
   // v45 (Punch List Round 3, Item 1 - third pass, supplementary): split no longer dead-even -
   // column 1 holds the longest caption in the whole grid ("CLOSE WINNERS", 13 chars) while column
   // 2's two captions (11/12 chars) are close to each other and don't need the extra room as much,
   // so a small slice of width is shifted from column 2 to column 1. Total grid width unchanged.
   int mwSplitDelta = SC(6);
   int mw   = (g_closeMenuAnchorW - CLOSE_GRID_GAP) / 2;
   int mwL  = mw + mwSplitDelta;
   int mwR  = mw - mwSplitDelta;
   int mh   = CLOSE_GRID_ROW_H;
   int mx0  = g_closeMenuAnchorX;
   int mx1  = g_closeMenuAnchorX + mwL + CLOSE_GRID_GAP;
   int my0  = g_closeMenuAnchorY;
   int my1  = g_closeMenuAnchorY + mh + CLOSE_GRID_GAP;

   // v45 (Punch List Round 3, Item 2): all 4 captions unified to ALL CAPS (CLOSE WINNERS/CLOSE
   // LOSERS were already caps since v36 - "Close All"/"Close Chart" now match instead of the
   // mixed Title Case they had).
   BtnC(P+"SUB_CLOSEALL",    mx0, my0, mwL, mh, "CLOSE ALL",    TH_CL_ALL, corner, 8);
   BtnC(P+"SUB_CLOSECHART",  mx1, my0, mwR, mh, "CLOSE CHART",  TH_CL_CHART, corner, 8);
   BtnC(P+"SUB_CLOSEPROFIT", mx0, my1, mwL, mh, "CLOSE WINNERS", TH_CL_WIN, corner, 8);
   BtnC(P+"SUB_CLOSELOSS",   mx1, my1, mwR, mh, "CLOSE LOSERS",  TH_CL_LOSS, corner, 8);

   // v45 (Punch List Round 3, Item 1): same width-aware font-fit class already used for
   // BTN_RISKTOGGLE (v44) - previously only BtnC's static sz=8 applied here, so "CLOSE WINNERS"
   // (13 chars) and "CLOSE LOSERS" (12 chars) never went through any shared fit call and could
   // render visibly mismatched against each other once Layout Scale shrank the grid (e.g. 90%).
   // Both now run through the exact same call with their own actual box width, so they always
   // land on the same font-size logic instead of silently diverging.
   // v45 (Punch List Round 3, Item 1 - third pass): the estimate-based approach (character count x
   // ratio) in FitBtnFontHalf still wasn't tight enough for "CLOSE WINNERS" (13 chars) in this
   // narrow half-width box at 90% Layout Scale - twice now (see FitBtnFontHalf's own comment for
   // the padding fix that also wasn't sufficient on its own). Rather than tune the estimate a third
   // time with another guessed ratio, both captions are pinned directly to size 6 - the smallest
   // font this panel already uses anywhere (SCF's own floor, see its header comment), so this isn't
   // introducing a new, untested size. Guarantees both buttons render at the exact same size (the
   // original ask) and removes the estimation step - and its risk of being wrong a third time -
   // entirely for this specific pair.
   int clFs = (g_themeId==RM_THEME_MONO) ? 8 : 6;   // MT5: 8 (MT4 7) - small sizes render pixelated   // v110 P4: در تم Mono هر چهار دکمه هم‌اندازه (۷)
   FitBtnFontHalf(P+"SUB_CLOSEPROFIT", "CLOSE WINNERS", mwL, clFs);
   FitBtnFontHalf(P+"SUB_CLOSELOSS",   "CLOSE LOSERS",  mwR, clFs);
   if(g_themeId==RM_THEME_MONO)
   {
      ObjectSetInteger(0,P+"SUB_CLOSEALL",OBJPROP_FONTSIZE,SCF(7)); ObjectSetInteger(0,P+"SUB_CLOSECHART",OBJPROP_FONTSIZE,SCF(7));
      FitBtnFontHalf(P+"SUB_CLOSEALL","CLOSE ALL",mwL,8); FitBtnFontHalf(P+"SUB_CLOSECHART","CLOSE CHART",mwR,8);
      BtnBg(P+"BTN_FULL", TH_ACTIVE);   // BULK CLOSE تیل = منو باز است؛ بقیه‌ی پنل خاکستری نمی‌شود
   }
   else
   GreyOutPanel("BTN_FULL");
   ChartRedraw();
}

void CloseFullCloseMenu()
{
   ObjectDelete(0, P+"SUB_CLOSEALL");
   ObjectDelete(0, P+"SUB_CLOSECHART");
   ObjectDelete(0, P+"SUB_CLOSEPROFIT");
   ObjectDelete(0, P+"SUB_CLOSELOSS");
   g_fullCloseMenuOpen = false;

   // Change 7: only re-expand if it was open before the submenu forced it collapsed - never force
   // it open if the trader had manually collapsed it beforehand.
   if(g_dashboardMode==DASH_TRADING && g_perfWasOpenBeforeSubmenu)
      g_perfDrawerOpen = true;

   // full rebuild restores every button/box's true color in one step (see OpenFullCloseMenu note)
   ObjectsDeleteAll(0, P);
   BuildPanel();
   ChartRedraw();
}

// v37 PART B: Half Close دیگه فوری اجرا نمی‌شه - همون مکانیزم OpenFullCloseMenu، ولی چون فقط
// ۲ گزینه داره (Half Close All / Profitable Only) به‌جای گرید ۲×۲، یه ردیف تکی با ۲ دکمه‌ی
// هم‌عرض ساخته می‌شه - دقیقاً جای همون ردیف BE/Half Close.
void OpenHalfCloseMenu()
{
   g_perfWasOpenBeforeSubmenu = g_perfDrawerOpen;
   if(g_dashboardMode==DASH_TRADING && g_perfDrawerOpen)
      g_perfDrawerOpen = false;

   g_halfCloseMenuOpen = true;
   ObjectsDeleteAll(0, P);
   BuildPanel();

   int corner = CORNER_LEFT_UPPER;
   int mw  = (g_halfCloseMenuAnchorW - CLOSE_GRID_GAP) / 2;
   int mh  = CLOSE_GRID_ROW_H;
   int mx0 = g_halfCloseMenuAnchorX;
   int mx1 = g_halfCloseMenuAnchorX + mw + CLOSE_GRID_GAP;
   int my0 = g_halfCloseMenuAnchorY;

   // v75.18 (MT4 v111): گرید 2x2 - HALF ALL | ACTIVE CHART / HALF WINNERS | BY TRADE (همیشه در دسترس)
   int my1 = my0 + mh + CLOSE_GRID_GAP;
   BtnC(P+"SUB_HALFALL",    mx0, my0, mw, mh, "HALF ALL",      TH_CL_ALL,   corner, 8);
   BtnC(P+"SUB_HALFCHART",  mx1, my0, mw, mh, "ACTIVE CHART",  TH_CL_CHART, corner, 8);
   BtnC(P+"SUB_HALFPROFIT", mx0, my1, mw, mh, "HALF WINNERS",  TH_CL_WIN,   corner, 8);
   BtnC(P+"SUB_HALFSELECT", mx1, my1, mw, mh, "BY TRADE",      TH_CL_SEL,   corner, 8);

   if(g_themeId!=RM_THEME_MONO) GreyOutPanel("BTN_HALF");   // v110 P4: در تم Mono پنل خاکستری نمی‌شود
   ChartRedraw();
}

void CloseHalfCloseMenu()
{
   ObjectDelete(0, P+"SUB_HALFALL");
   ObjectDelete(0, P+"SUB_HALFPROFIT");
   ObjectDelete(0, P+"SUB_HALFCHART");   // v75.18
   ObjectDelete(0, P+"SUB_HALFSELECT");  // v59 (Item 1): سومین دکمه‌ی زیرمنو، اگه ساخته شده باشه
   g_halfCloseMenuOpen = false;

   if(g_dashboardMode==DASH_TRADING && g_perfWasOpenBeforeSubmenu)
      g_perfDrawerOpen = true;

   ObjectsDeleteAll(0, P);
   BuildPanel();
   ChartRedraw();
}

//+------------------------------------------------------------------+
// v59 (Item 1 - Trade Identification): هدف‌گیری تک‌تیکت توی بسکت
//+------------------------------------------------------------------+
// مشکل: HalfCloseTicket() از قبل کاملاً per-ticket کار می‌کنه (پارامتر tkt)، ولی هیچ مسیر UIای
// برای انتخاب یک تیکت خاص از بین چند معامله‌ی باز روی یک نماد وجود نداشت - فقط "همه" یا "همه‌ی
// سودده". این بخش هیچ منطق Half Close ای رو تغییر نمی‌ده - فقط یک لایه‌ی انتخاب تیکت روی همون
// HalfCloseTicket() موجود اضافه می‌کنه.
//
// تعداد معاملات باز همین نماد (فقط با همین Magic Number) - برای تصمیم اینکه دکمه‌ی سوم
// ("Select Trade") توی OpenHalfCloseMenu() نشون داده بشه یا نه (فقط وقتی >=2).
int CountSymbolOpenTickets()
{
   int n=0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;
      n++;
   }
   return n;
}

#define HALFSEL_WIN_PREFIX "RM_HSEL_"
bool g_halfSelWindowOpen = false;
ulong g_halfSelTickets[];   // ایندکسش با دکمه‌های HALFSEL_WIN_PREFIX+"ROW_"+i هم‌راستاست

void CloseHalfSelectWindow()
{
   ObjectsDeleteAll(0, HALFSEL_WIN_PREFIX);
   g_halfSelWindowOpen = false;
   ChartRedraw();
}

// یک ردیف پنجره‌ی انتخاب: Ticket + کامنت/تگ + R فعلی (زنده). همون تعریف R که HalfCloseTicket()
// خودش برای تشخیص reachedTP1 استفاده می‌کنه (فاصله‌ی SL از Entry = 1R) - دوباره پیاده‌سازی
// نشده، فقط همون فرمول با متغیرهای محلی این‌جا تکرار شده (نه یک قرارداد جدید).
void BuildHalfSelectWindow()
{
   ObjectsDeleteAll(0, HALFSEL_WIN_PREFIX);
   if(!g_halfSelWindowOpen) return;

   ArrayResize(g_halfSelTickets, 0);
   string labels[];
   int cnt = 0;

   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;

      ulong  tkt    = tk;
      bool   buy    = (posType==POSITION_TYPE_BUY);
      double op     = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl     = PositionGetDouble(POSITION_SL);
      double slDist = MathAbs(op-sl);
      string psym   = PositionGetString(POSITION_SYMBOL);   // v75.18: قیمت از نماد خود پوزیشن
      double curPr  = buy ? SymbolInfoDouble(psym,SYMBOL_BID) : SymbolInfoDouble(psym,SYMBOL_ASK);
      string rTxt   = "N/A";
      if(slDist>0)
      {
         double rVal = buy ? (curPr-op)/slDist : (op-curPr)/slDist;
         rTxt = DoubleToString(rVal,2)+"R";
      }

      // کامنت/تگ: اگه این تیکت از قبل Strategy تگ خورده (v56، RM_Tools.mqh)، همون نشون داده
      // می‌شه؛ وگرنه OrderComment() خام (همیشه در دسترسه، حتی برای تیکت‌های تگ‌نخورده).
      string tagStrat = GetTagStrategy(tkt);
      string tagTxt   = (tagStrat!="N/A") ? tagStrat : PositionGetString(POSITION_COMMENT);

      // (R حذف شد؛ فلش ▲/▼ در MT4 نمایش داده نمی‌شد - برگشت به BUY/SELL)
      string lbl = psym+" "+(buy?"BUY":"SELL")+" "+DoubleToString(PositionGetDouble(POSITION_VOLUME),2)+
                   " | #"+IntegerToString(tkt);   // v75.18: متن کوتاه

      ArrayResize(labels, cnt+1);
      ArrayResize(g_halfSelTickets, cnt+1);
      labels[cnt] = lbl;
      g_halfSelTickets[cnt] = tkt;
      cnt++;
   }

   // --- لایه‌بندی: همون الگوی دقیق BuildTagWindow() (RM_Tools.mqh) - زیر خودِ داشبورد، هم‌سمت و هم‌عرض ---
   int corner = CORNER_LEFT_UPPER;
   int rowH   = SC(22);
   int hdrH   = SC(24);
   int pad    = SC(4);

   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int winX   = PanelRight ? chartW - PW - PanelX : PanelX;
   int winW   = PW;
   int panelBottomY = PanelY + TH + (g_minimized ? 0 : ComputeBodyH());
   int winY   = panelBottomY + GP;

   int contentRows = (cnt>0) ? cnt : 1;  // حداقل ۱ ردیف برای پیام "بدون معامله"
   int totalH = pad + hdrH + pad + contentRows*(rowH+pad) + pad;

   RectWin(HALFSEL_WIN_PREFIX+"BG", winX, winY, winW, totalH, corner);
   winX += RM_WinInset(); winW -= 2*RM_WinInset();   // v110 P4h

   int cy = winY + pad;
   BtnC(HALFSEL_WIN_PREFIX+"HDR",   winX,             cy, winW-SC(24)-pad, hdrH, "Half Close - Select Trade", TH_HDR, corner, 7);
   BtnC(HALFSEL_WIN_PREFIX+"CLOSE", winX+winW-SC(24), cy, SC(24),          hdrH, "X",     TH_XBTN, corner, 8);
   cy += hdrH + pad;

   if(cnt==0)
   {
      LblCC(HALFSEL_WIN_PREFIX+"EMPTY", winX, cy, winW, rowH, "No open trades", TH_SILVER, 7, false, corner);
   }
   else
   {
      for(int r=0;r<cnt;r++)
      {
         BtnC(HALFSEL_WIN_PREFIX+"ROW_"+IntegerToString(r), winX, cy, winW, rowH, labels[r], TH_ROW, corner, 8);
         cy += rowH + pad;
      }
   }

   ChartRedraw();
}

void OpenHalfSelectWindow()
{
   g_halfSelWindowOpen = true;
   BuildHalfSelectWindow();
}

//+------------------------------------------------------------------+
// SL Tampering Protection (BUG-018) — منتقل‌شده به این فاز چون Snapshot در R3 هنوز نبود
//+------------------------------------------------------------------+

// === v41 (BUG-018): SL Tampering Protection - توابع کمکی ردیابی «تیکت‌هایی که همین الان
// SL=0 دارن» - همون الگوی دقیق IsTrailTracked/AddTrailTicket/RemoveTrailTicket بالا ===
int FindSLZeroIndex(ulong ticket)
{
   for(int i=0;i<g_slZeroCount;i++)
      if(g_slZeroTickets[i]==ticket) return i;
   return -1;
}

void AddSLZeroTicket(ulong ticket)
{
   if(FindSLZeroIndex(ticket)>=0) return;
   ArrayResize(g_slZeroTickets,      g_slZeroCount+1);
   ArrayResize(g_slZeroDetectedTime, g_slZeroCount+1);
   g_slZeroTickets[g_slZeroCount]      = ticket;
   g_slZeroDetectedTime[g_slZeroCount] = TimeCurrent();
   g_slZeroCount++;
}

void RemoveSLZeroTicketAt(int idx)
{
   for(int k=idx;k<g_slZeroCount-1;k++)
   {
      g_slZeroTickets[k]      = g_slZeroTickets[k+1];
      g_slZeroDetectedTime[k] = g_slZeroDetectedTime[k+1];
   }
   g_slZeroCount--;
   ArrayResize(g_slZeroTickets,      g_slZeroCount);
   ArrayResize(g_slZeroDetectedTime, g_slZeroCount);
}

// v41 (BUG-018): حذف فوری یه تیکت مشخص از لیست ردیابی SL=0 - چه چون تیکت بسته شده (از
// CheckClosedTrades)، چه چون تریدر خودش قبل از اتمام grace period یه SL معتبر جدید گذاشته
// (از داخل خود CheckSLTampering) - همون الگوی RemoveTrailTicket بالا.
void RemoveSLZeroTicket(ulong ticket)
{
   int idx = FindSLZeroIndex(ticket);
   if(idx>=0) RemoveSLZeroTicketAt(idx);
}

// === v41 (Mahmoud feedback): توابع کمکی «آخرین SL معتبر ثبت‌شده» - همون الگوی دقیق
// FindSLZeroIndex/AddSLZeroTicket بالا، فقط این‌بار مقدار (SL) هم نگه داشته می‌شه نه فقط زمان ===
int FindLastSLIndex(ulong ticket)
{
   for(int i=0;i<g_lastSLCount;i++)
      if(g_lastSLTickets[i]==ticket) return i;
   return -1;
}

// v41: هر تیک که این تیکت SL معتبر (غیرصفر) داره صدا زده می‌شه - چه اولین‌بار (اضافه)، چه
// بعدی‌ها (فقط مقدار به‌روز می‌شه). عمداً هیچ گاردی نداره که مقدار عوض نشده باشه - چون فرقی
// نداره، هر تیک همینطوری هم همین مقدار رو دوباره می‌نوشت.
void UpdateLastSL(ulong ticket, double slValue)
{
   int idx = FindLastSLIndex(ticket);
   if(idx>=0) { g_lastSLValue[idx] = slValue; return; }

   ArrayResize(g_lastSLTickets, g_lastSLCount+1);
   ArrayResize(g_lastSLValue,   g_lastSLCount+1);
   g_lastSLTickets[g_lastSLCount] = ticket;
   g_lastSLValue[g_lastSLCount]   = slValue;
   g_lastSLCount++;
}

// v41: حذف فوری یه تیکت از لیست ردیابی «آخرین SL معتبر» - با بسته‌شدن تیکت صدا زده می‌شه
// (از CheckClosedTrades) - همون دلیل RemoveTrailTicket/RemoveSLZeroTicket بالا.
void RemoveLastSLTicket(ulong ticket)
{
   int idx = FindLastSLIndex(ticket);
   if(idx<0) return;
   for(int k=idx;k<g_lastSLCount-1;k++)
   {
      g_lastSLTickets[k] = g_lastSLTickets[k+1];
      g_lastSLValue[k]   = g_lastSLValue[k+1];
   }
   g_lastSLCount--;
   ArrayResize(g_lastSLTickets, g_lastSLCount);
   ArrayResize(g_lastSLValue,   g_lastSLCount);
}

//+------------------------------------------------------------------+
// v41 (BUG-018): SL Tampering Protection - هر تیک، روی همه‌ی پوزیشن‌های باز این EA اجرا
// می‌شه. دو قانون مستقل و جداگانه:
//   قانون ۱ (حذف کامل SL): OrderStopLoss()==0 روی تیکتی که Snapshot اولیه‌ش SL معتبر داشته.
//      فوری هشدار + ۵ثانیه grace period (شاید تریدر داره SL جدید می‌ذاره) و بعدش اگه هنوز
//      صفره، خودکار به آخرین SL معتبر ثبت‌شده‌ی این تیکت (g_lastSLValue، نه SL لحظه‌ی بازشدن
//      معامله) برگردونده می‌شه - v41 (Mahmoud feedback): چون تا لحظه‌ی حذف، SL معمولاً چندبار
//      به‌صورت مشروع جابه‌جا شده (BE، Trailing، دستی) و قیمت به احتمال زیاد از SL خیلی اولیه
//      رد شده؛ برگشت به همون SL اولیه دیگه معنی نداره و می‌تونه نادرست باشه.
//   قانون ۲ (عقب‌کشیدن/Widening SL): فقط وقتی فاصله‌ی SL فعلی از فاصله‌ی اصلی (بر مبنای همون
//      SL لحظه‌ی بازشدن معامله - Snapshot، v11) بیشتر از MaxSLWidenMultiplier برابر بشه.
//      تنگ‌کردن SL (کاهش ریسک) هیچ‌وقت محدود نمی‌شه - طبق فلسفه‌ی asymmetric-risk پروژه
//      ("کم‌کردن ریسک یه کلیکه، زیادکردنش اصطکاک داره").
// هر دو قانون Strike خودشون رو از طریق AddBehaviorStrike() (همون مسیر BUG-021) اضافه می‌کنن.
//
// [Stage 3 — stop-and-ask flag, see report] This entire function depends on g_snapEntry/g_snapSL,
// populated only by SaveTradeSnapshot() at trade-open time (AutoExecute(), above) and read back via
// FindSnapshotIndex() - both of which live in RM_Snapshot.mqh, not yet ported. Until that module is
// real (not stubbed), FindSnapshotIndex() has nothing to find and this function cannot fire on
// MT5, regardless of how correctly the OrderModify->TRADE_ACTION_SLTP translation below is done.
// The translation itself is complete and faithful; it is NOT independently testable yet.
//+------------------------------------------------------------------+
void CheckSLTampering()
{
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long posType=PositionGetInteger(POSITION_TYPE);
      if(posType!=POSITION_TYPE_BUY && posType!=POSITION_TYPE_SELL) continue;

      ulong tkt = tk;

      // بدون Snapshot معتبر نمی‌شه فاصله‌ی اصلی ریسک رو محاسبه کرد - مثل بقیه‌ی جاهای پروژه
      // که به Snapshot متکی‌ان، محافظه‌کارانه نادیده گرفته می‌شه (نه اقدام اشتباه روی داده‌ی ناقص)
      int snapIdx = FindSnapshotIndex(tkt);
      if(snapIdx<0) continue;

      double entry  = g_snapEntry[snapIdx];
      double origSL = g_snapSL[snapIdx];
      if(origSL<=0) continue; // این معامله از ابتدا SL معتبر نداشته - چیزی برای محافظت وجود نداره

      double origDist = MathAbs(entry-origSL);
      if(origDist<=0) continue; // فاصله‌ی صفر - غیرقابل‌محاسبه، نادیده گرفته می‌شه

      bool   buy   = (posType==POSITION_TYPE_BUY);
      double curSL = PositionGetDouble(POSITION_SL);

      // v41 (Mahmoud feedback): قبل از هر تصمیمی - اگه همین الان SL معتبره، به‌عنوان «آخرین
      // SL معتبر» این تیکت ثبت/به‌روز می‌شه. این مقدار (نه g_snapSL) مبنای برگشت قانون ۱ می‌شه.
      // v64 (آیتم ۳ - SLLoosenedCount): *قبل* از این‌که UpdateLastSL مقدار قبلی رو overwrite کنه،
      // مقایسه می‌شه که آیا این یه تغییر واقعیه و اگه هست، در کدوم جهت - کاملاً مستقل از قانون
      // ۱/۲ زیر (حتی جابه‌جایی کاملاً مجاز هم شمرده می‌شه، چون این یه سیگنال رفتاری است، نه تخلف).
      // فقط جهت افزایش ریسک (دورتر از قیمت) شمرده می‌شه؛ تنگ‌تر کردن (BE/Trailing/دستی) نادیده
      // گرفته می‌شه. اولین ثبت یک تیکت تازه (لیست هنوز چیزی برای این تیکت نداره) با هیچی مقایسه
      // نمی‌شه - شمارش فقط از دومین مقدار معتبر به بعد معنا داره.
      if(curSL!=0)
      {
         int lastIdxForLoosenCheck = FindLastSLIndex(tkt);
         if(lastIdxForLoosenCheck>=0)
         {
            double prevKnownSL = g_lastSLValue[lastIdxForLoosenCheck];
            if(curSL != prevKnownSL)
            {
               // v64 (فیدبک محمود - نسخه‌ی اصلاح‌شده): آستانه‌ی نویز نسبت به فاصله‌ی اصلی ریسک
               // (origDist، همون مبنایی که قانون ۲ پایین هم ازش استفاده می‌کنه) محاسبه می‌شه -
               // نه نسبت به قیمت چارت. جابه‌جایی‌های کمتر از SL_LOOSEN_NOISE_THRESHOLD_PCT درصد
               // از origDist نادیده گرفته می‌شن، حتی اگه از نظر جهت loosening باشن.
               double movePct = MathAbs(curSL - prevKnownSL) / origDist * 100.0;
               if(movePct >= SL_LOOSEN_NOISE_THRESHOLD_PCT)
               {
                  bool loosened = buy ? (curSL < prevKnownSL) : (curSL > prevKnownSL);
                  if(loosened) IncrementSLLoosenedCount(tkt);
               }
            }
         }
         UpdateLastSL(tkt, curSL);
      }

      // === قانون ۱: حذف کامل SL ===
      if(curSL==0)
      {
         int zIdx = FindSLZeroIndex(tkt);
         if(zIdx<0)
         {
            AddSLZeroTicket(tkt);
            Alert("RM: SL removed entirely on ticket #"+IntegerToString(tkt)+" - auto-restoring to last known SL in 5s if not reset");
            SetStatus("SL removed! Auto-restore in 5s (#"+IntegerToString(tkt)+")", clrRed);
         }
         else if(TimeCurrent()-g_slZeroDetectedTime[zIdx] >= 5)
         {
            // v41 (Mahmoud feedback): برگشت به آخرین SL معتبر ثبت‌شده (g_lastSLValue)، نه به
            // origSL (SL لحظه‌ی بازشدن معامله). فال‌بک به origSL فقط برای حالت نادر و
            // محافظه‌کارانه‌ای‌ست که هیچ‌وقت SL معتبری بعد از باز شدن معامله ثبت نشده باشه
            // (مثلاً ری‌استارت EA درست قبل از اولین تیکی که SL معتبر رو می‌دید).
            int lastIdx = FindLastSLIndex(tkt);
            double restoreTarget = (lastIdx>=0) ? g_lastSLValue[lastIdx] : origSL;
            double restoreSL = NormalizeDouble(restoreTarget, _Digits);
            if(RM_ModifyPositionSLTP(tkt, restoreSL, PositionGetDouble(POSITION_TP)))
            {
               RemoveSLZeroTicket(tkt);
               UpdateLastSL(tkt, restoreSL); // v41: خود همین بازگردانی هم یه SL معتبر جدیده
               // v47 (BUG-040): Strike فقط بار اول به‌ازای این تیکت - تصحیح SL بالا (که همیشه
               // باید اجرا بشه) از این چک مستقل نگه داشته شده، فقط خود AddBehaviorStrike گارد شده.
               if(!IsAlreadyTamperStriked(tkt))
               {
                  AddBehaviorStrike("SL fully removed then auto-restored to last known stop (ticket #"+IntegerToString(tkt)+")");
                  MarkTamperStriked(tkt);
                  // v61: فیلد SLTamperedFlag روی Snapshot این تیکت پرچم‌گذاری می‌شه + یک واحد
                  // به شمارنده‌ی یکپارچه‌ی رفتاری (برای BehaviorErrorCountAtOpen معاملات بعدی)
                  // اضافه می‌شه - دقیقاً هم‌جا/هم‌گارد با خود Strike (یک‌بار به‌ازای هر تیکت).
                  MarkSnapshotTampered(tkt);
                  IncrementBehaviorErrorTotal();
               }
            }
            else
               Print("RM: CheckSLTampering - OrderModify (restore SL) failed for ticket ", tkt, " (error ", GetLastError(), "), will retry next tick");
         }
         continue; // تا SL دوباره معتبر نشه، چک قانون ۲ روی همین تیکت بی‌معنیه
      }

      // اگه این تیکت قبلاً توی لیست ردیابی SL=0 بود ولی الان یه SL معتبر داره (تریدر خودش
      // قبل از اتمام grace period درستش کرده)، از لیست پاک می‌شه - بدون Strike (طبق دستور
      // صریح: "شاید تریدر وسط تنظیم یه SL جدید معتبره"). SL جدید همچنان زیر چک قانون ۲ می‌ره.
      if(FindSLZeroIndex(tkt)>=0) RemoveSLZeroTicket(tkt);

      // === قانون ۲: عقب‌کشیدن (Widening) SL === (همیشه بر مبنای origDist اصلی - Snapshot)
      // v46 (BUG-038 - تصحیح BUG-018): MathAbs فاصله‌ی مطلق از Entry رو حساب می‌کنه و جهت رو
      // نادیده می‌گیره. وقتی Auto Trailing معامله رو خیلی جلو می‌بره (SL از Entry رد می‌شه و
      // می‌ره توی سود)، curDist دوباره شروع به زیادشدن می‌کنه - دقیقاً مثل عقب‌کشیدن واقعی به
      // سمت ضرر - و این چک اشتباهاً فایر می‌شه. اگه SL همین الان روی سمت امن Entry باشه (برای
      // Buy: curSL >= entry، برای Sell: curSL <= entry) ریسک واقعی صفر یا منفیه، پس تمپرینگ
      // بی‌معنیه - مهم نیست SL چقدر جلو رفته باشه.
      bool onSafeSide = buy ? (curSL >= entry) : (curSL <= entry);
      if(onSafeSide) continue; // ریسک واقعی صفر یا منفی - تمپرینگ بی‌معنیه، صرف‌نظر از فاصله

      double curDist = MathAbs(entry-curSL);
      double maxDist = origDist*MaxSLWidenMultiplier;
      if(curDist <= maxDist) continue; // داخل محدوده‌ی مجاز - یا حتی تنگ‌تر شده (BE/Trailing)

      // v41: «آخرین نقطه‌ی قابل‌قبول» - دقیقاً روی مرز multiplier، در همون جهتی که SL این
      // معامله منطقاً باید باشه (پایین‌تر از Entry برای Buy، بالاتر از Entry برای Sell)
      double lastAcceptableSL = NormalizeDouble(buy ? entry-maxDist : entry+maxDist, _Digits);

      if(RM_ModifyPositionSLTP(tkt, lastAcceptableSL, PositionGetDouble(POSITION_TP)))
      {
         Alert("RM: SL widened beyond "+DoubleToString(MaxSLWidenMultiplier,1)+"x original risk on ticket #"+IntegerToString(tkt)+" - auto-corrected to last acceptable point");
         SetStatus("SL widening corrected (#"+IntegerToString(tkt)+")", clrOrange);
         // v47 (BUG-040): Strike فقط بار اول به‌ازای این تیکت - Alert/SetStatus/تصحیح SL بالا
         // و UpdateLastSL پایین همیشه اجرا می‌شن، فقط خود AddBehaviorStrike گارد شده.
         if(!IsAlreadyTamperStriked(tkt))
         {
            AddBehaviorStrike("SL widened beyond "+DoubleToString(MaxSLWidenMultiplier,1)+"x original risk (ticket #"+IntegerToString(tkt)+")");
            MarkTamperStriked(tkt);
            // v61: همون افزودن Snapshot flag + شمارنده‌ی یکپارچه که در قانون ۱ بالا هم انجام شد
            MarkSnapshotTampered(tkt);
            IncrementBehaviorErrorTotal();
         }
         UpdateLastSL(tkt, lastAcceptableSL); // v41: تصحیح خودکار هم یه SL معتبر جدیده
      }
      else
         Print("RM: CheckSLTampering - OrderModify (widen correction) failed for ticket ", tkt, " (error ", GetLastError(), "), will retry next tick");
   }
}

//+------------------------------------------------------------------+
//| v75.4 (پورت MT4 v80 FEAT-031): Auto Close At Time                  |
//+------------------------------------------------------------------+
// وقتی EnableAutoCloseAtHour=true و ساعت *سرور* (TimeCurrent()، بدون تبدیل منطقه‌ی زمانی) به AutoCloseTime (HH:MM)
// برسد، همه‌ی پوزیشن‌های باز (همین Magic) با همان FullClose() موجود بسته می‌شوند. با false کاملاً no-op است.
// جلوگیری از تکرار: پرچم persisted GV_AUTOCLOSE_DAY (تاریخ yyyymmdd سرور) *همان لحظه‌ی اجرا* ست می‌شود.
// پنجره‌ی اجرا: فقط از مرز تا AUTOCLOSE_WINDOW_SEC ثانیه بعدش (ری‌استارت ساعت‌ها بعد، چیزی نمی‌بندد).
#define AUTOCLOSE_WINDOW_SEC   300
#define AUTOCLOSE_MAX_ATTEMPTS 3
int    g_autoCloseSecOfDay   = -1;   // ثانیه از ابتدای روز سرور؛ -1 = غیرفعال/نامعتبر
int    g_autoCloseAttempts   = 0;
double g_autoCloseAttemptDay = 0;

bool AutoClose_AllDigits(string s)
{
   int n = StringLen(s);
   if(n<1 || n>2) return false;
   for(int i=0;i<n;i++)
   {
      int c = StringGetCharacter(s, i);
      if(c<48 || c>57) return false;
   }
   return true;
}

bool AutoClose_ParseTime(string txt, int &secOfDay)
{
   StringTrimLeft(txt); StringTrimRight(txt);
   string parts[];
   if(StringSplit(txt, ':', parts) != 2) return false;
   StringTrimLeft(parts[0]); StringTrimRight(parts[0]);
   StringTrimLeft(parts[1]); StringTrimRight(parts[1]);
   if(!AutoClose_AllDigits(parts[0]) || !AutoClose_AllDigits(parts[1])) return false;
   int h = (int)StringToInteger(parts[0]);
   int m = (int)StringToInteger(parts[1]);
   if(h<0 || h>23 || m<0 || m>59) return false;
   secOfDay = h*3600 + m*60;
   return true;
}

void InitAutoCloseAtHour()
{
   g_autoCloseSecOfDay = -1;
   if(!EnableAutoCloseAtHour) return;
   int sec;
   if(!AutoClose_ParseTime(AutoCloseTime, sec))
   {
      Print("RM AutoClose: INVALID AutoCloseTime '", AutoCloseTime, "' (expected HH:MM, 00:00-23:59) - Auto Close DISABLED");
      Alert("Risk Manager: AutoCloseTime '", AutoCloseTime, "' is invalid (use HH:MM). Auto Close At Time is DISABLED.");
      return;
   }
   g_autoCloseSecOfDay = sec;
   Print("RM AutoClose: armed - all open positions will be closed daily at ", AutoCloseTime, " broker/server time");
}

int AutoClose_CountOpen()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      long pt=PositionGetInteger(POSITION_TYPE);
      if(pt!=POSITION_TYPE_BUY && pt!=POSITION_TYPE_SELL) continue;
      n++;
   }
   return n;
}

void CheckAutoCloseAtHour()
{
   if(!EnableAutoCloseAtHour || g_autoCloseSecOfDay < 0) return;

   datetime now = TimeCurrent();   // وقت سرور/بروکر - مقایسه‌ی مستقیم
   MqlDateTime dt; TimeToStruct(now, dt);
   int secNow = dt.hour*3600 + dt.min*60 + dt.sec;
   if(secNow < g_autoCloseSecOfDay) return;
   if(secNow - g_autoCloseSecOfDay > AUTOCLOSE_WINDOW_SEC) return;

   double dayKey = (double)(dt.year*10000 + dt.mon*100 + dt.day);
   if(GlobalVariableCheck(GV_AUTOCLOSE_DAY) && GlobalVariableGet(GV_AUTOCLOSE_DAY) == dayKey) return;

   if(g_autoCloseAttemptDay != dayKey) { g_autoCloseAttemptDay = dayKey; g_autoCloseAttempts = 0; }
   GlobalVariableSet(GV_AUTOCLOSE_DAY, dayKey);   // اول پرچم، بعد بستن

   int openBefore = AutoClose_CountOpen();
   Print("RM AutoClose: ", AutoCloseTime, " reached (server ", TimeToString(now, TIME_DATE|TIME_SECONDS), ") - open positions: ", openBefore);
   if(openBefore == 0) return;

   FullClose();

   int left = AutoClose_CountOpen();
   if(left > 0)
   {
      g_autoCloseAttempts++;
      if(g_autoCloseAttempts < AUTOCLOSE_MAX_ATTEMPTS)
      {
         Print("RM AutoClose: ", left, " position(s) still open after attempt ", g_autoCloseAttempts, " - will retry");
         GlobalVariableDel(GV_AUTOCLOSE_DAY);
      }
      else
      {
         Print("RM AutoClose: WARNING - ", left, " position(s) still open after ", g_autoCloseAttempts, " attempts");
         Alert("Auto Close At Time: ", left, " position(s) could NOT be closed - check platform manually!");
      }
   }
   else
      Alert("Auto Close At Time: all ", openBefore, " position(s) closed at ", AutoCloseTime, " (broker time)");
}
