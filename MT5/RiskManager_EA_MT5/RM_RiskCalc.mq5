//+------------------------------------------------------------------+
//| RM_RiskCalc.mq5                                                    |
//| Risk Manager EA - Risk Calculation (MT5 Port, Stage 2)             |
//| پورت مستقیم از RM_RiskCalc.mqh (RiskManager EA v70, MQL4). طبق      |
//| Golden Rule این استیج: فرمول‌ها/آستانه‌ها/ترتیب عملیات عوض نشدن -    |
//| فقط فراخوانی‌های API از MT4 به MT5 ترجمه شدن (طبق جدول Stage 2).    |
//| این فایل به g_effRiskPerTrade/g_effMaxTotalRisk/g_effMaxDailyRisk/  |
//| g_effMaxWeeklyDD/g_effMaxMonthlyDD و GetDailyNetResultPercent()     |
//| وابسته‌ست - این‌ها هنوز پورت نشدن (بخشی از یه فایل دیگه، خارج از     |
//| اسکوپ این استیج طبق Stage2 Task Message). موقع لینک‌شدن به پروژه‌ی   |
//| کامل MT5، این وابستگی‌ها باید از همون فایلی که پورت می‌شن تأمین بشن. |
//+------------------------------------------------------------------+

// v38 (BUG-023): سقف‌های سخت روی Input های ریسک - اگه مقدار خام از سقف رد شده باشه، به سقف کلمپ
// می‌شه و Alert() هشدار می‌ده. باید قبل از BuildPanel() صدا زده بشه (دکمه‌ی Risk Toggle از
// g_effRiskPerTrade می‌خونه). فرمول‌های خودِ Risk/Drawdown دست‌نخورده می‌مونن.
// [Stage 2 judgment call #1] DoubleToStr() → DoubleToString(): DoubleToStr is an MT4-only legacy
// function and does not exist in MQL5 (MQL5 only has DoubleToString, which MT4 also gained later -
// the original file already used DoubleToString elsewhere, e.g. in CalcLot()'s MinLot Alert below).
// Not in the Stage 2 API table since it's a formatting call, not a calculation - flagged here rather
// than silently swapped. Output formatting (2 decimal places) is identical, no behavior change.
void ApplyRiskCeilings()
{
   g_effRiskPerTrade = RiskPerTrade;
   if(RiskPerTrade > RISKPERTRADE_CEILING)
   {
      g_effRiskPerTrade = RISKPERTRADE_CEILING;
      Alert("RM: RiskPerTrade ("+DoubleToString(RiskPerTrade,2)+"%) exceeds max "+DoubleToString(RISKPERTRADE_CEILING,2)+"% - clamped to ceiling");
   }

   g_effMaxTotalRisk = MaxTotalRisk;
   if(MaxTotalRisk > MAXTOTALRISK_CEILING)
   {
      g_effMaxTotalRisk = MAXTOTALRISK_CEILING;
      Alert("RM: MaxTotalRisk ("+DoubleToString(MaxTotalRisk,2)+"%) exceeds max "+DoubleToString(MAXTOTALRISK_CEILING,2)+"% - clamped to ceiling");
   }

   g_effMaxDailyRisk = MaxDailyNetLossAllowed;
   if(MaxDailyNetLossAllowed > MAXDAILYRISK_CEILING)
   {
      g_effMaxDailyRisk = MAXDAILYRISK_CEILING;
      Alert("RM: MaxDailyNetLossAllowed ("+DoubleToString(MaxDailyNetLossAllowed,2)+"%) exceeds max "+DoubleToString(MAXDAILYRISK_CEILING,2)+"% - clamped to ceiling");
   }

   g_effMaxWeeklyDD = MaxWeeklyNetLossAllowed;
   if(MaxWeeklyNetLossAllowed > MAXWEEKLYDD_CEILING)
   {
      g_effMaxWeeklyDD = MAXWEEKLYDD_CEILING;
      Alert("RM: MaxWeeklyNetLossAllowed ("+DoubleToString(MaxWeeklyNetLossAllowed,2)+"%) exceeds max "+DoubleToString(MAXWEEKLYDD_CEILING,2)+"% - clamped to ceiling");
   }

   g_effMaxMonthlyDD = MaxMonthlyNetLossAllowed;
   if(MaxMonthlyNetLossAllowed > MAXMONTHLYDD_CEILING)
   {
      g_effMaxMonthlyDD = MAXMONTHLYDD_CEILING;
      Alert("RM: MaxMonthlyNetLossAllowed ("+DoubleToString(MaxMonthlyNetLossAllowed,2)+"%) exceeds max "+DoubleToString(MAXMONTHLYDD_CEILING,2)+"% - clamped to ceiling");
   }
}

bool CheckLimits(string &reason, double riskPct=-1)
{
   if(riskPct<0) riskPct=g_effRiskPerTrade;
   double tot=GetTotalOpenRisk(),day=GetDailyRisk();
   if(tot+riskPct>g_effMaxTotalRisk){ reason="Open("+DoubleToString(tot,2)+"%)MAX"; return false; }
   if(EnableDailyDD && day+riskPct>g_effMaxDailyRisk){ reason="Daily("+DoubleToString(day,2)+"%)MAX"; return false; }
   return true;
}
// [Stage 2 judgment call #2] CheckLimits()'s error-string DoubleToStr() calls translated to
// DoubleToString() for the same reason as ApplyRiskCeilings() above (not in the API table, flagged
// for visibility). No formula/threshold/order-of-operations change.

double GetTotalOpenRisk()
{
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); if(bal<=0) return 0; double risk=0;
   // MT5: PositionsTotal()/PositionGetTicket(i)/PositionSelectByTicket(ticket) replace MT4's
   // OrdersTotal()/OrderSelect(i,SELECT_BY_POS,MODE_TRADES) per the Stage 2 API table. Loop order
   // (ascending index) and every filter/formula below is otherwise untouched.
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      // v3 (BUG-006 fix): فیلتر نماد حذف شد - الان مثل GetDailyRisk کل حساب رو بر اساس MagicNumber حساب می‌کنه
      // تا سقف MaxTotalRisk واقعاً ریسک کل حساب رو محدود کنه، نه فقط نماد چارت جاری
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetDouble(POSITION_SL)<=0) continue;
      // v20 (BUG-024 fix): محاسبه‌ی pip/pip-value الان بر اساس نماد خودِ اوردر (OrderSymbol) انجام
      // می‌شه، نه نماد چارت جاری - قبلاً برای اوردرهای غیر از نماد چارت (Multi-Symbol) کاملاً غلط بود
      string osym  = PositionGetString(POSITION_SYMBOL);
      double opt   = SymbolInfoDouble(osym, SYMBOL_POINT);
      double opipf = PipFactorForSymbol(osym);
      if(opt<=0) continue;
      double pips=MathAbs(PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_SL))/(opt*opipf);
      // v24 (BUG-027, same root cause as BUG-026): branch on MODE_PROFITCALCMODE
      // instead of trusting tickValue>0/tickSize>0. On Silver at
      // ErranteTrading-Demo2, tickValue and tickSize are both a nonzero 0.0001,
      // which passes a >0 check but produces a pval ~5000x too small (the
      // contract size), making Open Risk read effectively 0.00% for CFD
      // positions instead of their real risk. See CalcLot() for the same fix.
      double otickValue=SymbolInfoDouble(osym, SYMBOL_TRADE_TICK_VALUE);
      double otickSize =SymbolInfoDouble(osym, SYMBOL_TRADE_TICK_SIZE);
      // [Stage 2 judgment call #3 - the flagged PROFITCALCMODE mapping, full reasoning here,
      // referenced by short comment at every other call site]: MT4's MODE_PROFITCALCMODE returns
      // exactly 0 (Forex), 1 (CFD), or 2 (Futures), and the original code's branch condition is
      // simply "calcMode==0". MT5's SYMBOL_TRADE_CALC_MODE returns the richer ENUM_SYMBOL_CALC_MODE
      // (SYMBOL_CALC_MODE_FOREX, _FOREX_NO_LEVERAGE, _CFD, _CFDLEVERAGE, _CFDINDEX, _FUTURES,
      // _EXCH_FUTURES, _EXCH_FUTURES_FORTS, _EXCH_STOCKS, _EXCH_BONDS, _EXCH_STOCKS_MOEX,
      // _EXCH_BONDS_MOEX, _SERV_COLLATERAL). Decision: only SYMBOL_CALC_MODE_FOREX and
      // SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE take the tick-based Forex-mode path (the direct MT4
      // calcMode==0 equivalent); every other calc mode (CFD, CFD-leverage, CFD-index, futures,
      // exchange instruments, etc.) falls to the contract-size (else) branch, matching how MT4's
      // original code already treated calcMode 1 and 2 identically via its else branch. This
      // preserves XAU/USD's exact original behavior (Forex-mode symbols with valid tick data keep
      // the tick-based calc byte-for-byte) while extending the same "else = contract-size fallback"
      // logic to the additional MT5-only calc modes without inventing new formula branches.
      ENUM_SYMBOL_CALC_MODE ocalcMode=(ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(osym, SYMBOL_TRADE_CALC_MODE);
      bool oIsForexCalcMode=(ocalcMode==SYMBOL_CALC_MODE_FOREX || ocalcMode==SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE);
      double pval;
      if(oIsForexCalcMode && otickValue>0 && otickSize>0)
         pval=otickValue/otickSize*opt*opipf;
      else
         pval=SymbolInfoDouble(osym, SYMBOL_TRADE_CONTRACT_SIZE)*opt*opipf;
      if(pval!=pval || pval<=0 || pval>1e6) continue; // NaN/Inf/garbage guard, same as CalcLot
      risk+=pips*pval*PositionGetDouble(POSITION_VOLUME);
   }
   return risk/bal*100.0;
}

// v61 (bugfix - BUG-048): نسخه‌ی excluding از GetTotalOpenRisk بالا - دقیقاً همون حلقه/فرمول
// (فیلترها، pval، NaN/Inf guard - همه عیناً کپی‌شده)، فقط با یک تیکت مشخص که از جمع ریسک باز
// کنار گذاشته می‌شه. لازم برای این‌که بشه ریسک باز "قبل از" یک تیکت خاص (که همین الان تازه
// باز شده و از قبل جزو OrdersTotal() است) رو محاسبه کرد - خودِ GetTotalOpenRisk() بالا
// دست‌نخورده می‌مونه چون جاهای دیگه (CheckLimits/Dashboard) بدون استثنا لازمش دارن.
// [Stage 2 judgment call #4] excludeTicket parameter type: int → ulong. MT4 order tickets fit in a
// 32-bit int; MT5 position tickets are natively 64-bit (ulong, per PositionGetTicket()'s return
// type in the Stage 2 API table). Keeping this as `int` would silently truncate/mismatch large MT5
// ticket values and break the "==excludeTicket" comparison below - this is an API-surface
// consequence of the MT4→MT5 ticket type change, not a formula change, so it's called out here
// rather than left as a silent int. Any later-stage caller of this function will need to pass a
// ulong ticket accordingly.
double GetTotalOpenRiskExcludingTicket(ulong excludeTicket)
{
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); if(bal<=0) return 0; double risk=0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(ticket==excludeTicket) continue; // v61 bugfix (BUG-048): خودِ تیکت تازه‌بازشده حساب نشه
      if(PositionGetDouble(POSITION_SL)<=0) continue;
      string osym  = PositionGetString(POSITION_SYMBOL);
      double opt   = SymbolInfoDouble(osym, SYMBOL_POINT);
      double opipf = PipFactorForSymbol(osym);
      if(opt<=0) continue;
      double pips=MathAbs(PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_SL))/(opt*opipf);
      double otickValue=SymbolInfoDouble(osym, SYMBOL_TRADE_TICK_VALUE);
      double otickSize =SymbolInfoDouble(osym, SYMBOL_TRADE_TICK_SIZE);
      // PROFITCALCMODE mapping: see the full judgment-call comment in GetTotalOpenRisk() above -
      // same decision applied identically here (Forex/Forex-No-Leverage = tick path, else = contract-size path).
      ENUM_SYMBOL_CALC_MODE ocalcMode=(ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(osym, SYMBOL_TRADE_CALC_MODE);
      bool oIsForexCalcMode=(ocalcMode==SYMBOL_CALC_MODE_FOREX || ocalcMode==SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE);
      double pval;
      if(oIsForexCalcMode && otickValue>0 && otickSize>0)
         pval=otickValue/otickSize*opt*opipf;
      else
         pval=SymbolInfoDouble(osym, SYMBOL_TRADE_CONTRACT_SIZE)*opt*opipf;
      if(pval!=pval || pval<=0 || pval>1e6) continue; // NaN/Inf/garbage guard, same as CalcLot
      risk+=pips*pval*PositionGetDouble(POSITION_VOLUME);
   }
   return risk/bal*100.0;
}

// v10 (BUG-012): بازنویسی - قبلاً فقط مجموع ضررها بود؛ حالا نتیجه‌ی خالص واقعی% منهای ریسک باز (بدترین حالت)
// مقایسه با MaxDailyRisk در CheckLimits دست‌نخورده می‌مونه، فقط خودِ محاسبه عوض شده
// Depends on GetDailyNetResultPercent() - not part of RM_Config.mqh/RM_RiskCalc.mqh, therefore not
// ported in this stage (see file-header note). Formula itself is unchanged from MT4.
double GetDailyRisk()
{
   double projected = GetDailyNetResultPercent() - GetTotalOpenRisk();
   return (projected<0) ? MathAbs(projected) : 0.0;
}

// v61 (bugfix - BUG-048): نسخه‌ی excluding از GetDailyRisk بالا - همون فرمول (پروجکتد = نتیجه‌ی
// خالص روز منهای ریسک باز)، فقط با GetTotalOpenRiskExcludingTicket (پایین‌تر) به‌جای
// GetTotalOpenRisk. خودِ GetDailyRisk() بالا دست‌نخورده می‌مونه - جاهای دیگه (CheckLimits/
// Dashboard/CheckDrawdownLimits) بدون استثنا لازمش دارن.
double GetDailyRiskExcludingTicket(ulong excludeTicket)
{
   double projected = GetDailyNetResultPercent() - GetTotalOpenRiskExcludingTicket(excludeTicket);
   return (projected<0) ? MathAbs(projected) : 0.0;
}

// v21 (BUG-026): pval validation split into two explicit paths instead of one
// combined expression, so CFD-mode symbols with invalid MODE_TICKVALUE/
// MODE_TICKSIZE (e.g. Silver on some brokers, both showing 0.000) fall back to
// a contract-size-based calc instead of silently producing 0 or NaN.
// v51 (parking lot, found in v50 testing): پارامتر سوم alertOnBlock اضافه شد. قبلاً همیشه
// موقع بلاک‌شدن (pval نامعتبر یا lot زیر MinLot) بی‌قید و شرط Alert/Print می‌زد - از جمله
// وقتی این تابع فقط برای پیش‌نمایش زنده‌ی hover (MOUSE_MOVE) صدا زده می‌شد، یعنی تریدر قبل
// از هر تصمیمی با popup مواجه می‌شد. خودِ فرمول محاسبه‌ی لات (مسیر Forex/CFD، NaN/Inf guard،
// گرد کردن به LOTSTEP، کلمپ به MIN/MAXLOT) کاملاً دست‌نخورده می‌مونه - فقط دو بلاک Alert/Print
// زیر شرطی شدن به alertOnBlock. مقدار پیش‌فرض true تا رفتار همه‌ی caller های موجود (که آرگومان
// سوم رو پاس نمی‌دن) دقیقاً همون قبل بمونه؛ فقط caller پیش‌نمایش hover صریحاً false پاس می‌ده.
double CalcLot(double slPips,double riskPct,bool alertOnBlock=true)
{
   double bal=AccountInfoDouble(ACCOUNT_BALANCE),rAmt=bal*riskPct/100.0;
   // MT4 Symbol()/Digits/Point (implicit, current chart symbol) → MT5 _Symbol/_Digits/_Point
   // (predefined vars for the chart the EA/script is attached to) per the Stage 2 API table.
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double lotSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   // PROFITCALCMODE mapping: see the full judgment-call comment in GetTotalOpenRisk() above - same
   // decision applied here (Forex/Forex-No-Leverage = tick path, else = contract-size path).
   ENUM_SYMBOL_CALC_MODE calcMode=(ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_CALC_MODE);
   bool isForexCalcMode=(calcMode==SYMBOL_CALC_MODE_FOREX || calcMode==SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE);
   double pval;

   // v24 (BUG-026 real root cause): branch on MODE_PROFITCALCMODE rather than
   // on tickValue>0/tickSize>0. On Silver at ErranteTrading-Demo2, tickValue
   // and tickSize are BOTH a nonzero 0.0001 - technically "valid" by a >0
   // check, but the resulting tick-based pval is wrong by ~5000x (the
   // contract size) versus the MODE_LOTSIZE-derived value. A >0 check cannot
   // catch a nonzero-but-wrong tick value; PROFITCALCMODE (0=Forex,
   // 1=CFD, 2=Futures) is the broker's own declaration of which formula
   // applies, independent of whether tickValue/tickSize happen to look valid.
   if(isForexCalcMode && tickValue>0 && tickSize>0)
   {
      // Forex-mode path - unchanged from v20, so XAUUSD (Forex-mode,
      // real account, PROFITCALCMODE=0) lot calculation stays byte-for-byte
      // identical.
      pval=tickValue/tickSize*_Point*PipFactor();
   }
   else
   {
      // CFD/Futures path (calcMode 1 or 2), or Forex-mode with an invalid
      // tick value/size as a last-resort safety net: MT4 profit for
      // CFD/commodity instruments is price-difference x contract size x
      // lots, independent of the tick-value/tick-size ratio - so derive
      // pip value from contract size instead.
      pval=lotSize*_Point*PipFactor();
   }

   // v42 (Punch List, Part 6): the two BUG-026 diagnostic blocks (v22's unconditional Print() of
   // every raw value feeding this calculation, and v23's matching on-chart Comment() overlay) are
   // removed - BUG-026 was confirmed resolved back in v24 and these were always marked temporary,
   // pending final removal once confirmed. Only the diagnostic output is gone; the calculation
   // logic above/below (path selection, NaN/Inf/sanity guard, lot rounding/clamping) is untouched.

   // Explicit NaN/Inf guard regardless of which path computed pval - pval!=pval
   // is true only for NaN in MQL4, and the ceiling catches Inf/garbage that a
   // plain <=0 check would miss.
   if(pval!=pval || pval<=0 || pval>1e6 || slPips<=0)
   {
      if(alertOnBlock)
      {
         Alert("CalcLot: cannot determine pip value for ",_Symbol," — order blocked");
         Print("CalcLot: cannot determine pip value for ",_Symbol," — order blocked",
               " (tickValue=",tickValue,", tickSize=",tickSize,", pval=",pval,")");
      }
      return 0;
   }

   double lot=rAmt/(slPips*pval),step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lot=MathFloor(lot/step)*step;

   // v47 (BUG-039): قبلاً اگه lot محاسبه‌شده (بر پایه‌ی درصد ریسک واقعی) از MODE_MINLOT
   // بروکر کمتر بود، MathMax پایین‌تر بی‌صدا اون رو به حداقل مجاز بالا می‌برد - روی نمادهایی
   // با MinLot/LotStep درشت (مثل NQ100) این یعنی ریسک واقعی می‌تونست تقریباً دوبرابر درصد
   // تعریف‌شده بشه، کاملاً بی‌صدا. حالا مثل NaN/Inf guard بالا، به‌جای بزرگ‌کردن بی‌صدای لات،
   // معامله بلاک می‌شه: این ریسک روی این نماد/SL اصلاً قابل‌رعایت نیست.
   if(lot < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))
   {
      if(alertOnBlock)
      {
         Alert("RM: Calculated lot ("+DoubleToString(lot,2)+") is below broker's minimum ("+DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),2)+") for "+_Symbol+" - risk cannot be respected at this SL distance, trade blocked");
         Print("RM: CalcLot - lot below MinLot, blocking trade to avoid silent risk overshoot");
      }
      return 0;
   }

   double finalLot=NormalizeDouble(MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),MathMin(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),lot)),2);

   return finalLot;
}

double PipFactor(){ return (_Digits==5||_Digits==3)?10.0:1.0; }

// v20 (BUG-024): نسخه‌ی per-symbol از PipFactor - برای محاسبه‌ی ریسک اوردرهایی که نمادشون
// با نماد چارت جاری فرق داره (Multi-Symbol). از MarketInfo به‌جای Digits سراسری استفاده می‌کنه.
double PipFactorForSymbol(string sym)
{
   int dig=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   return (dig==5||dig==3)?10.0:1.0;
}

// v24 (BUG-026/027/028 - same root cause, consolidated): the correct $-per-pip
// value for a symbol, given its own Point and PipFactor. Branches on
// MarketInfo(sym,MODE_PROFITCALCMODE) instead of trusting tickValue>0/
// tickSize>0 - on Silver at ErranteTrading-Demo2, tickValue and tickSize are
// both a nonzero 0.0001, which passes a >0 check but produces a pip value
// ~5000x too small (the contract size). PROFITCALCMODE (0=Forex, 1=CFD,
// 2=Futures) is the broker's own declaration of which formula applies,
// independent of whether tickValue/tickSize happen to look superficially
// valid. Forex-mode with valid tick data keeps the original tick-based calc
// unchanged (XAUUSD's output is untouched); CFD/Futures, or Forex-mode with
// invalid tick data as a last-resort safety net, uses MODE_LOTSIZE-based
// contract-size calc instead. This is now the single place this logic lives -
// CalcLot(), GetTotalOpenRisk(), the chart SL/TP $ preview, the Trade
// Snapshot risk-in-$ capture, and the legacy no-snapshot fallback all call
// this instead of each carrying their own copy of the formula.
double GetPipValueForSymbol(string sym, double pt, double pf)
{
   double tickValue=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE);
   double tickSize =SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   // PROFITCALCMODE mapping: see the full judgment-call comment in GetTotalOpenRisk() above - same
   // decision applied here (Forex/Forex-No-Leverage = tick path, else = contract-size path).
   ENUM_SYMBOL_CALC_MODE calcMode =(ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE);
   bool isForexCalcMode=(calcMode==SYMBOL_CALC_MODE_FOREX || calcMode==SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE);
   double pval;
   if(isForexCalcMode && tickValue>0 && tickSize>0)
      pval=tickValue/tickSize*pt*pf;
   else
      pval=SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE)*pt*pf;
   if(pval!=pval || pval<=0 || pval>1e6) return 0; // NaN/Inf/garbage guard
   return pval;
}

// === v75.10 (MT4 v84 FEAT-038): Full -> 1/2 -> 1/4 -> 1/8 -> Full ===
int RiskStepDivisor(int step){ if(step==1) return 2; if(step==2) return 4; if(step==3) return 8; return 1; }
string RiskStepName(int step){ if(step==1) return "1/2"; if(step==2) return "1/4"; if(step==3) return "1/8"; return "Full"; }
double GetActiveRiskPct(){ return g_effRiskPerTrade/(double)RiskStepDivisor(g_riskStep); }
string FmtRiskPct(double v)
{
   string t = DoubleToString(v, 3);
   int dot = StringFind(t, ".");
   int len = StringLen(t);
   if(dot < 0) return t;
   while(len > dot + 3 && StringGetCharacter(t, len - 1) == '0') len--;
   return StringSubstr(t, 0, len);
}
void SetRiskStep(int step, bool persist = true)
{
   if(step < 0 || step > 3) step = 0;
   g_riskStep       = step;
   g_halfRiskActive = (step > 0);
   if(persist && StringLen(GV_RISK_STEP) > 0) GlobalVariableSet(GV_RISK_STEP, (double)step);
}
void CycleRiskStep(){ SetRiskStep((g_riskStep + 1) % 4); }
void LoadRiskStepState()
{
   GV_RISK_STEP = "RM_RiskStep_A" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_M" + IntegerToString(MagicNumber) + "_" + Symbol();
   int step = 0;
   if(GlobalVariableCheck(GV_RISK_STEP)) step = (int)MathRound(GlobalVariableGet(GV_RISK_STEP));
   SetRiskStep(step, false);
}
