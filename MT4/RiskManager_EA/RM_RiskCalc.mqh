//+------------------------------------------------------------------+
//| RM_RiskCalc.mqh                                                    |
//| Risk Manager EA - Risk Calculation (Architecture Refactor, R5)     |
//| استخراج‌شده از RiskManager_EA_v45_R4.mq4 - توابع محاسبه‌ی ریسک        |
//| (ApplyRiskCeilings/CheckLimits/GetTotalOpenRisk/GetDailyRisk/       |
//| CalcLot/PipFactor/PipFactorForSymbol/GetPipValueForSymbol).         |
//| صرفاً جابه‌جایی کد، بدون هیچ تغییر مقدار/رفتار (Golden Rule فاز R5).  |
//+------------------------------------------------------------------+

// v38 (BUG-023): سقف‌های سخت روی Input های ریسک - اگه مقدار خام از سقف رد شده باشه، به سقف کلمپ
// می‌شه و Alert() هشدار می‌ده. باید قبل از BuildPanel() صدا زده بشه (دکمه‌ی Risk Toggle از
// g_effRiskPerTrade می‌خونه). فرمول‌های خودِ Risk/Drawdown دست‌نخورده می‌مونن.
void ApplyRiskCeilings()
{
   g_effRiskPerTrade = RiskPerTrade;
   if(RiskPerTrade > RISKPERTRADE_CEILING)
   {
      g_effRiskPerTrade = RISKPERTRADE_CEILING;
      Alert("RM: RiskPerTrade ("+DoubleToStr(RiskPerTrade,2)+"%) exceeds max "+DoubleToStr(RISKPERTRADE_CEILING,2)+"% - clamped to ceiling");
   }

   g_effMaxTotalRisk = MaxTotalRisk;
   if(MaxTotalRisk > MAXTOTALRISK_CEILING)
   {
      g_effMaxTotalRisk = MAXTOTALRISK_CEILING;
      Alert("RM: MaxTotalRisk ("+DoubleToStr(MaxTotalRisk,2)+"%) exceeds max "+DoubleToStr(MAXTOTALRISK_CEILING,2)+"% - clamped to ceiling");
   }

   g_effMaxDailyRisk = MaxDailyNetLossAllowed;
   if(MaxDailyNetLossAllowed > MAXDAILYRISK_CEILING)
   {
      g_effMaxDailyRisk = MAXDAILYRISK_CEILING;
      Alert("RM: MaxDailyNetLossAllowed ("+DoubleToStr(MaxDailyNetLossAllowed,2)+"%) exceeds max "+DoubleToStr(MAXDAILYRISK_CEILING,2)+"% - clamped to ceiling");
   }

   g_effMaxWeeklyDD = MaxWeeklyNetLossAllowed;
   if(MaxWeeklyNetLossAllowed > MAXWEEKLYDD_CEILING)
   {
      g_effMaxWeeklyDD = MAXWEEKLYDD_CEILING;
      Alert("RM: MaxWeeklyNetLossAllowed ("+DoubleToStr(MaxWeeklyNetLossAllowed,2)+"%) exceeds max "+DoubleToStr(MAXWEEKLYDD_CEILING,2)+"% - clamped to ceiling");
   }

   g_effMaxMonthlyDD = MaxMonthlyNetLossAllowed;
   if(MaxMonthlyNetLossAllowed > MAXMONTHLYDD_CEILING)
   {
      g_effMaxMonthlyDD = MAXMONTHLYDD_CEILING;
      Alert("RM: MaxMonthlyNetLossAllowed ("+DoubleToStr(MaxMonthlyNetLossAllowed,2)+"%) exceeds max "+DoubleToStr(MAXMONTHLYDD_CEILING,2)+"% - clamped to ceiling");
   }
}

// === v84 (FEAT-038): دکمه‌ی ریسک چندحالته - Full -> 1/2 -> 1/4 -> 1/8 -> Full ===
// g_riskStep تنها منبع حقیقت است. GetActiveRiskPct() تنها جایی‌ست که «درصد ریسک فعلی» ساخته می‌شه و
// هر سه مسیر CalcLot (پیش‌نمایش زنده، لیبل‌های نهایی، AutoExecute) از همین می‌خونن. TradeR مستقیم از این
// متغیر نمی‌خونه؛ از RiskUSD ذخیره‌شده‌ی Snapshot (لات واقعی x فاصله SL) محاسبه می‌شه، پس برای هر پله درسته.
int RiskStepDivisor(int step)
{
   if(step == 1) return 2;
   if(step == 2) return 4;
   if(step == 3) return 8;
   return 1;
}

string RiskStepName(int step)
{
   if(step == 1) return "1/2";
   if(step == 2) return "1/4";
   if(step == 3) return "1/8";
   return "Full";
}

double GetActiveRiskPct()
{
   return g_effRiskPerTrade / (double)RiskStepDivisor(g_riskStep);
}

// فقط برای نمایش روی دکمه: حداکثر ۳ رقم اعشار، صفرهای انتهایی حذف ولی حداقل ۲ رقم می‌مونه: 0.25 / 0.125 / 0.063 / 0.031
// (مقدار واقعی ریسک و لات با دقت کامل محاسبه می‌شه - این تابع فقط متن دکمه رو کوتاه می‌کنه)
string FmtRiskPct(double v)
{
   string t = DoubleToStr(v, 3);
   int dot = StringFind(t, ".");
   int len = StringLen(t);
   if(dot < 0) return t;
   while(len > dot + 3 && StringGetChar(t, len - 1) == '0') len--;
   return StringSubstr(t, 0, len);
}

void SetRiskStep(int step, bool persist = true)
{
   if(step < 0 || step > 3) step = 0;
   g_riskStep       = step;
   g_halfRiskActive = (step > 0);  // مشتق: «هر پله‌ی کاهش‌یافته» - مصرف‌کننده‌های قدیمی Snapshot/WasHalfRisk
   if(persist && StringLen(GV_RISK_STEP) > 0) GlobalVariableSet(GV_RISK_STEP, (double)step);
}

void CycleRiskStep()
{
   SetRiskStep((g_riskStep + 1) % 4);
}

void LoadRiskStepState()
{
   int step = 0;
   if(GlobalVariableCheck(GV_RISK_STEP)) step = (int)MathRound(GlobalVariableGet(GV_RISK_STEP));
   SetRiskStep(step, false);
}

bool CheckLimits(string &reason, double riskPct=-1)
{
   if(riskPct<0) riskPct=g_effRiskPerTrade;
   double tot=GetTotalOpenRisk(),day=GetDailyRisk();
   if(tot+riskPct>g_effMaxTotalRisk){ reason="Open("+DoubleToStr(tot,2)+"%)MAX"; return false; }
   if(EnableDailyDD && day+riskPct>g_effMaxDailyRisk){ reason="Daily("+DoubleToStr(day,2)+"%)MAX"; return false; }
   return true;
}

double GetTotalOpenRisk()
{
   double bal=AccountBalance(); if(bal<=0) return 0; double risk=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      // v3 (BUG-006 fix): فیلتر نماد حذف شد - الان مثل GetDailyRisk کل حساب رو بر اساس MagicNumber حساب می‌کنه
      // تا سقف MaxTotalRisk واقعاً ریسک کل حساب رو محدود کنه، نه فقط نماد چارت جاری
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderStopLoss()<=0) continue;
      // v20 (BUG-024 fix): محاسبه‌ی pip/pip-value الان بر اساس نماد خودِ اوردر (OrderSymbol) انجام
      // می‌شه، نه نماد چارت جاری - قبلاً برای اوردرهای غیر از نماد چارت (Multi-Symbol) کاملاً غلط بود
      string osym  = OrderSymbol();
      double opt   = MarketInfo(osym,MODE_POINT);
      double opipf = PipFactorForSymbol(osym);
      if(opt<=0) continue;
      double pips=MathAbs(OrderOpenPrice()-OrderStopLoss())/(opt*opipf);
      // v24 (BUG-027, same root cause as BUG-026): branch on MODE_PROFITCALCMODE
      // instead of trusting tickValue>0/tickSize>0. On Silver at
      // ErranteTrading-Demo2, tickValue and tickSize are both a nonzero 0.0001,
      // which passes a >0 check but produces a pval ~5000x too small (the
      // contract size), making Open Risk read effectively 0.00% for CFD
      // positions instead of their real risk. See CalcLot() for the same fix.
      double otickValue=MarketInfo(osym,MODE_TICKVALUE);
      double otickSize =MarketInfo(osym,MODE_TICKSIZE);
      int    ocalcMode =(int)MarketInfo(osym,MODE_PROFITCALCMODE);
      double pval;
      if(ocalcMode==0 && otickValue>0 && otickSize>0)
         pval=otickValue/otickSize*opt*opipf;
      else
         pval=MarketInfo(osym,MODE_LOTSIZE)*opt*opipf;
      if(pval!=pval || pval<=0 || pval>1e6) continue; // NaN/Inf/garbage guard, same as CalcLot
      risk+=pips*pval*OrderLots();
   }
   return risk/bal*100.0;
}

// v61 (bugfix - BUG-048): نسخه‌ی excluding از GetTotalOpenRisk بالا - دقیقاً همون حلقه/فرمول
// (فیلترها، pval، NaN/Inf guard - همه عیناً کپی‌شده)، فقط با یک تیکت مشخص که از جمع ریسک باز
// کنار گذاشته می‌شه. لازم برای این‌که بشه ریسک باز "قبل از" یک تیکت خاص (که همین الان تازه
// باز شده و از قبل جزو OrdersTotal() است) رو محاسبه کرد - خودِ GetTotalOpenRisk() بالا
// دست‌نخورده می‌مونه چون جاهای دیگه (CheckLimits/Dashboard) بدون استثنا لازمش دارن.
double GetTotalOpenRiskExcludingTicket(int excludeTicket)
{
   double bal=AccountBalance(); if(bal<=0) return 0; double risk=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderTicket()==excludeTicket) continue; // v61 bugfix (BUG-048): خودِ تیکت تازه‌بازشده حساب نشه
      if(OrderStopLoss()<=0) continue;
      string osym  = OrderSymbol();
      double opt   = MarketInfo(osym,MODE_POINT);
      double opipf = PipFactorForSymbol(osym);
      if(opt<=0) continue;
      double pips=MathAbs(OrderOpenPrice()-OrderStopLoss())/(opt*opipf);
      double otickValue=MarketInfo(osym,MODE_TICKVALUE);
      double otickSize =MarketInfo(osym,MODE_TICKSIZE);
      int    ocalcMode =(int)MarketInfo(osym,MODE_PROFITCALCMODE);
      double pval;
      if(ocalcMode==0 && otickValue>0 && otickSize>0)
         pval=otickValue/otickSize*opt*opipf;
      else
         pval=MarketInfo(osym,MODE_LOTSIZE)*opt*opipf;
      if(pval!=pval || pval<=0 || pval>1e6) continue; // NaN/Inf/garbage guard, same as CalcLot
      risk+=pips*pval*OrderLots();
   }
   return risk/bal*100.0;
}

// v10 (BUG-012): بازنویسی - قبلاً فقط مجموع ضررها بود؛ حالا نتیجه‌ی خالص واقعی% منهای ریسک باز (بدترین حالت)
// مقایسه با MaxDailyRisk در CheckLimits دست‌نخورده می‌مونه، فقط خودِ محاسبه عوض شده
double GetDailyRisk()
{
   double projected = GetDailyNetResultPercent() - GetTotalOpenRisk();
   return (projected<0) ? MathAbs(projected) : 0.0;
}

// v61 (bugfix - BUG-048): نسخه‌ی excluding از GetDailyRisk بالا - همون فرمول (پروجکتد = نتیجه‌ی
// خالص روز منهای ریسک باز)، فقط با GetTotalOpenRiskExcludingTicket (پایین‌تر) به‌جای
// GetTotalOpenRisk. خودِ GetDailyRisk() بالا دست‌نخورده می‌مونه - جاهای دیگه (CheckLimits/
// Dashboard/CheckDrawdownLimits) بدون استثنا لازمش دارن.
double GetDailyRiskExcludingTicket(int excludeTicket)
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
   double bal=AccountBalance(),rAmt=bal*riskPct/100.0;
   double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize=MarketInfo(Symbol(),MODE_TICKSIZE);
   double lotSize=MarketInfo(Symbol(),MODE_LOTSIZE);
   int    calcMode=(int)MarketInfo(Symbol(),MODE_PROFITCALCMODE);
   double pval;

   // v24 (BUG-026 real root cause): branch on MODE_PROFITCALCMODE rather than
   // on tickValue>0/tickSize>0. On Silver at ErranteTrading-Demo2, tickValue
   // and tickSize are BOTH a nonzero 0.0001 - technically "valid" by a >0
   // check, but the resulting tick-based pval is wrong by ~5000x (the
   // contract size) versus the MODE_LOTSIZE-derived value. A >0 check cannot
   // catch a nonzero-but-wrong tick value; PROFITCALCMODE (0=Forex,
   // 1=CFD, 2=Futures) is the broker's own declaration of which formula
   // applies, independent of whether tickValue/tickSize happen to look valid.
   if(calcMode==0 && tickValue>0 && tickSize>0)
   {
      // Forex-mode path - unchanged from v20, so XAUUSD (Forex-mode,
      // real account, PROFITCALCMODE=0) lot calculation stays byte-for-byte
      // identical.
      pval=tickValue/tickSize*Point*PipFactor();
   }
   else
   {
      // CFD/Futures path (calcMode 1 or 2), or Forex-mode with an invalid
      // tick value/size as a last-resort safety net: MT4 profit for
      // CFD/commodity instruments is price-difference x contract size x
      // lots, independent of the tick-value/tick-size ratio - so derive
      // pip value from contract size instead.
      pval=lotSize*Point*PipFactor();
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
         Alert("CalcLot: cannot determine pip value for ",Symbol()," — order blocked");
         Print("CalcLot: cannot determine pip value for ",Symbol()," — order blocked",
               " (tickValue=",tickValue,", tickSize=",tickSize,", pval=",pval,")");
      }
      return 0;
   }

   double lot=rAmt/(slPips*pval),step=MarketInfo(Symbol(),MODE_LOTSTEP);
   lot=MathFloor(lot/step)*step;

   // v47 (BUG-039): قبلاً اگه lot محاسبه‌شده (بر پایه‌ی درصد ریسک واقعی) از MODE_MINLOT
   // بروکر کمتر بود، MathMax پایین‌تر بی‌صدا اون رو به حداقل مجاز بالا می‌برد - روی نمادهایی
   // با MinLot/LotStep درشت (مثل NQ100) این یعنی ریسک واقعی می‌تونست تقریباً دوبرابر درصد
   // تعریف‌شده بشه، کاملاً بی‌صدا. حالا مثل NaN/Inf guard بالا، به‌جای بزرگ‌کردن بی‌صدای لات،
   // معامله بلاک می‌شه: این ریسک روی این نماد/SL اصلاً قابل‌رعایت نیست.
   if(lot < MarketInfo(Symbol(),MODE_MINLOT))
   {
      if(alertOnBlock)
      {
         Alert("RM: Calculated lot ("+DoubleToString(lot,2)+") is below broker's minimum ("+DoubleToString(MarketInfo(Symbol(),MODE_MINLOT),2)+") for "+Symbol()+" - risk cannot be respected at this SL distance, trade blocked");
         Print("RM: CalcLot - lot below MinLot, blocking trade to avoid silent risk overshoot");
      }
      return 0;
   }

   double finalLot=NormalizeDouble(MathMax(MarketInfo(Symbol(),MODE_MINLOT),MathMin(MarketInfo(Symbol(),MODE_MAXLOT),lot)),2);

   return finalLot;
}

double PipFactor(){ return (Digits==5||Digits==3)?10.0:1.0; }

// v20 (BUG-024): نسخه‌ی per-symbol از PipFactor - برای محاسبه‌ی ریسک اوردرهایی که نمادشون
// با نماد چارت جاری فرق داره (Multi-Symbol). از MarketInfo به‌جای Digits سراسری استفاده می‌کنه.
double PipFactorForSymbol(string sym)
{
   int dig=(int)MarketInfo(sym,MODE_DIGITS);
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
   double tickValue=MarketInfo(sym,MODE_TICKVALUE);
   double tickSize =MarketInfo(sym,MODE_TICKSIZE);
   int    calcMode =(int)MarketInfo(sym,MODE_PROFITCALCMODE);
   double pval;
   if(calcMode==0 && tickValue>0 && tickSize>0)
      pval=tickValue/tickSize*pt*pf;
   else
      pval=MarketInfo(sym,MODE_LOTSIZE)*pt*pf;
   if(pval!=pval || pval<=0 || pval>1e6) return 0; // NaN/Inf/garbage guard
   return pval;
}

//+------------------------------------------------------------------+
// === v90 (FEAT-044 فاز ۱): Scale-in - ورود ادامه با ریسک آزاد‌شده‌ی یک زنجیره (حالت ۱: محافظه‌کار) ===
// هیچ‌کدام از توابع بالا (GetTotalOpenRisk، CalcLot، CheckLimits) تغییر نکرده‌اند. این بلوک فقط توابع جدید و مستقل است.
// سقف حالت ۱ = max(0, RiskUSD ریشه - ریسک بازِ زنده‌ی علامت‌دار زنجیره). «ریسک بازِ زنده» از SL زنده‌ی سفارش‌ها می‌آید
// (نه Snapshot): SL فراتر از ورود (سود قفل‌شده) ریسک *منفی* حساب می‌شود و سقف را بزرگ‌تر می‌کند. سود بانک‌شده لحاظ نمی‌شود (حالت ۲، فاز ۲).
//+------------------------------------------------------------------+
// (متغیرهای سراسری g_scaleInOn / g_scaleInRoot / g_scCand* در فایل اصلی .mq4 کنار g_riskStep تعریف شده‌اند - ترتیب include)

// ریسک بازِ زنده‌ی علامت‌دار (دلار) برای همه‌ی بخش‌های بازِ BUY/SELL یک زنجیره. Pending حساب نمی‌شود (ریسکی ندارد تا پر شود).
// ok=false اگر یکی از بخش‌های باز SL ندارد یا ارزش پیپ نامعتبر است (ریسک نامعلوم -> سقف صفر، محافظه‌کارانه).
// openParts = تعداد بخش‌های باز؛ isBuy/sym = جهت و نماد زنجیره (از اولین بخش باز).
// توجه: OrderSelect(MODE_TRADES) سفارش جاری را عوض می‌کند - فراخواننده اگر لازم دارد دوباره OrderSelect کند.
double GetChainLiveOpenRiskUSD(int root, bool &ok, int &openParts, bool &isBuy, string &sym)
{
   ok = true; openParts = 0; isBuy = true; sym = "";
   double risk = 0.0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      int ty = OrderType();
      if(ty!=OP_BUY && ty!=OP_SELL) continue;
      if(GetRootTicket(OrderTicket()) != root) continue;

      string osym = OrderSymbol();
      if(openParts==0){ isBuy = (ty==OP_BUY); sym = osym; }
      openParts++;

      double sl = OrderStopLoss();
      if(sl <= 0){ ok = false; continue; }
      double opt   = MarketInfo(osym,MODE_POINT);
      double opipf = PipFactorForSymbol(osym);
      if(opt<=0){ ok = false; continue; }
      double pval  = GetPipValueForSymbol(osym, opt, opipf);
      if(pval<=0){ ok = false; continue; }
      double signedDist = (ty==OP_BUY) ? (OrderOpenPrice()-sl) : (sl-OrderOpenPrice());  // >0 = هنوز ریسک؛ <0 = سود قفل‌شده
      risk += signedDist/(opt*opipf) * pval * OrderLots();
   }
   return risk;
}

// آیا برای این ریشه یک سفارش Pending (پر‌نشده) وجود دارد؟ (ورود ادامه‌ی منتظرِ پر شدن)
bool ChainHasPendingOrder(int root)
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      int ty = OrderType();
      if(ty==OP_BUY || ty==OP_SELL) continue;
      if(GetRootTicket(OrderTicket()) == root) return true;
   }
   return false;
}

// سقف حالت ۱ (دلار) برای یک ریشه. کمتر/مساوی صفر = مجاز نیست؛ why دلیل کوتاه (برای نوار وضعیت).
// شرایط: Snapshot ریشه موجود، حداقل یک بخش باز هم‌نماد با چارت، همه‌ی بخش‌های باز SL دارند، Pending منتظری در زنجیره نیست.
double ScaleInCapUSD(int root, string &why)
{
   why = "";
   int idxRoot = FindSnapshotIndex(root);
   if(idxRoot < 0 || g_snapRiskUSD[idxRoot] <= 0){ why = "no root risk record"; return 0.0; }

   bool ok; int parts; bool isBuy; string sym;
   double live = GetChainLiveOpenRiskUSD(root, ok, parts, isBuy, sym);
   if(parts <= 0)       { why = "chain not open"; return 0.0; }
   if(sym != Symbol())  { why = "other symbol"; return 0.0; }
   if(!ok)              { why = "open part without SL"; return 0.0; }
   if(ChainHasPendingOrder(root)){ why = "pending continuation waiting"; return 0.0; }

   double cap = g_snapRiskUSD[idxRoot] - live;
   if(cap < 0.01)       { why = "no freed risk"; return 0.0; }
   return cap;
}

// جهت زنجیره (true=BUY). فقط وقتی معنا دارد که بخش بازی باشد.
bool ScaleInChainIsBuy(int root)
{
   bool ok; int parts; bool isBuy; string sym;
   GetChainLiveOpenRiskUSD(root, ok, parts, isBuy, sym);
   return isBuy;
}

// فهرست زنجیره‌های مجاز (باز، هم‌نماد، سقف>0، بدون Pending منتظر). آرایه‌ها هم‌ایندکس. خروجی = تعداد.
// whyNone: اگر صفر شد، دلیل کوتاه برای نوار وضعیت.
int BuildScaleInCandidates(string &whyNone)
{
   ArrayResize(g_scCandRoot,0); ArrayResize(g_scCandCap,0); ArrayResize(g_scCandBuy,0); ArrayResize(g_scCandEntry,0);
   int n = 0, seenRoots = 0;
   string lastWhy = "";
   int    roots[]; ArrayResize(roots,0);

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      int ty = OrderType();
      if(ty!=OP_BUY && ty!=OP_SELL) continue;
      if(OrderSymbol()!=Symbol()) continue;
      int r = GetRootTicket(OrderTicket());
      bool dup = false;
      for(int k=0;k<seenRoots;k++) if(roots[k]==r){ dup = true; break; }
      if(dup) continue;
      ArrayResize(roots, seenRoots+1); roots[seenRoots] = r; seenRoots++;
   }

   for(int q=0;q<seenRoots;q++)
   {
      string why;
      double cap = ScaleInCapUSD(roots[q], why);
      if(cap <= 0){ lastWhy = why; continue; }
      int idxRoot = FindSnapshotIndex(roots[q]);
      ArrayResize(g_scCandRoot,n+1); ArrayResize(g_scCandCap,n+1); ArrayResize(g_scCandBuy,n+1); ArrayResize(g_scCandEntry,n+1);
      g_scCandRoot[n]  = roots[q];
      g_scCandCap[n]   = cap;
      g_scCandBuy[n]   = ScaleInChainIsBuy(roots[q]);
      g_scCandEntry[n] = (idxRoot>=0) ? g_snapEntry[idxRoot] : 0.0;
      n++;
   }
   if(n == 0) whyNone = (seenRoots==0) ? "no open trade" : lastWhy;
   return n;
}

// درصدِ ریسکِ ورود. در حالت Scale-in = سقف زنده‌ی زنجیره‌ی انتخاب‌شده به درصد بالانس (دکمه‌ی Full/Half نادیده)؛ وگرنه همان GetActiveRiskPct().
// ضریب (1+1e-9) فقط جلوی خطای ممیز شناور را می‌گیرد که لات دقیقاً-روی-مرز را یک پله پایین نبرد (لات به LotStep پایین گرد می‌شود،
// پس ریسک واقعی هیچ‌وقت از سقف بیشتر نمی‌شود جز حداکثر ~1e-9 نسبی). CalcLot دست‌نخورده است.
double GetEntryRiskPct()
{
   if(!g_scaleInOn) return GetActiveRiskPct();
   string why;
   double cap = ScaleInCapUSD(g_scaleInRoot, why);
   double bal = AccountBalance();
   if(cap <= 0 || bal <= 0) return 0.0;
   return cap/bal*100.0*(1.0+1e-9);
}
