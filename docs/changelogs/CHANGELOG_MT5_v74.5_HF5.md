# CHANGELOG MT5 v74.5 — HF5: ترید‌هایی که با Pending باز می‌شوند Snapshot نداشتند (فقط MT5، بر پایه‌ی v74.4 r2)

> ⚠️ **کامپایل نشده** (فقط تعادل `{}` `()` `[]` و diff بررسی شده). `.ex5` قدیمی را پاک کن، `RM_RiskManager_Main.mq5` را کامپایل کن و اگر خطایی آمد متنش را بفرست. **ارتقا را وقتی هیچ قفلی فعال نیست انجام بده.**

**پایه:** v74.4 r2 (`"74.41"`) ← **خروجی:** v74.5 (`"74.50"`). Hub بدون تغییر (1.08، byte-identical). MT4 دست‌نخورده.
**فایل‌های تغییرکرده (۵):** `RM_TradeExecution`، `RM_Snapshot`، `RM_CooldownEngine`، `RM_MainEventHandlers`، `RM_RiskManager_Main` (فقط نسخه). بقیه byte-identical با v74.4 r2. فقط یک خط حذف شده (نسخه)؛ بقیه‌ی diff افزودنی است.

## 1) ریشه‌ی باگ (تأییدشده در کد)
- `AutoExecute()` (`RM_TradeExecution.mq5`) برای Market و Pending یک مسیر دارد: Snapshot فقط داخل `if(PositionSelectByTicket(ticket))` ساخته می‌شد. برای Pending در لحظه‌ی ثبت **پوزیشنی وجود ندارد** → شرط false → `SaveTradeSnapshot` هرگز صدا زده نمی‌شد.
- `CheckPendingActivation()` هنگام فعال‌شدن فقط `SetSnapshotBehaviorFieldsAtActivation` را صدا می‌زد که اگر Snapshot نباشد بی‌صدا `return` می‌کند → Snapshot هیچ‌وقت ساخته نمی‌شد.
- MT4 این مشکل را نداشت چون `OrderSelect` هم برای Pending کار می‌کند و Snapshot از روی خودِ اردر ثبت می‌شد.

### اثر روی ترید‌های Pending-origin (قبل از HF5) — آیتم به آیتم
- **Market/Behavior Cooldown** (`CheckClosedTrades`، `RM_CooldownEngine.mq5` ~654–709): **حذف نمی‌شد**؛ مسیر Fallback قدیمی (بدون Snapshot) اجرا می‌شد: `hitSL` از SL ردیابی‌شده (جهت‌دار، BUG-052/053 سر جایش)، ولی (الف) وزن Half Risk اعمال نمی‌شد (همیشه +1.0، خط ~752)، (ب) `reached1R` با فاصله‌ی SL **فعلی** حساب می‌شد (بعد از BE/Trail مبنای R کوچک می‌شود → احتمال تشخیص اشتباه «+۱R» و ریست Behavior)، (پ) `SetSnapshotBehaviorErrorsThisTrade` اجرا نمی‌شد (خط ~872).
- **Premature/EarlyExit**: `MaxFavR/MinFavR` ردیابی نمی‌شد (`UpdateSnapshotMaxFavorableR` بدون Snapshot خارج می‌شود) → قاعده‌ی «قبل از +۱R» درست کار نمی‌کرد.
- **CSV / Reports / Performance R / SL Tamper / MaxFavR/MinFavR / TimeframeAtOpen / فیلدهای رفتاری لحظه‌ی باز شدن:** همه `N/A` یا صفر، دقیقاً مثل ردیف‌های گزارش‌شده.
- **Tag/Mental State:** کار می‌کرد (کلیدش position ID است) و تغییر نکرده.

## 2) طراحی (کوچک‌ترین راه)
- **Hedging:** تیکت پوزیشنِ بعد از فعال‌شدن Pending = تیکت همان اردر. پس Snapshot همان لحظه‌ی ثبت زیر **همان تیکت** در همان طرح GlobalVariable (`RM_SNAP_*`) ذخیره می‌شود؛ هیچ re-key و هیچ `OnTradeTransaction` لازم نیست.
- **لحظه‌ی ثبت** (مثل MT4): SL، قیمت، حجم، ریسک `$`/`%`، `WasHalfRisk` (= `g_halfRiskActive` همان لحظه)، زمان ثبت. در `AutoExecute` شاخه‌ی `else if(g_mode != MODE_MARKET && OrderSelect(ticket))` (اضافه، مسیر Market دست‌نخورده).
- **لحظه‌ی فعال‌شدن:** `CheckPendingActivation` (که از قبل بود) فیلدهای «لحظه‌ی باز شدن» (شمارنده خطا، قفل، Entry Interval، Daily/Weekly%، PriorDay، تایم‌فریم) را پر می‌کند. حالا Snapshot وجود دارد پس واقعاً کار می‌کند.
- **ری‌استارت / تغییر تایم‌فریم:** `RM_PendingResumeAtInit()` (یک‌بار در OnInit) پندینگ‌های زنده‌ی همین نماد/Magic را دوباره در لیست ردیابی می‌گذارد. اگر Pending وقتی EA اجرا نبود فعال شد، Snapshotِ زمان ثبت هست و لاگ می‌زند `source=placement` (فیلدهای لحظه‌ی باز شدن placeholder می‌مانند).
- **چند چارت:** Snapshot را فقط چارتِ ثبت‌کننده می‌سازد (و `SaveTradeSnapshot` خودش تکراری را رد می‌کند). پردازش فعال‌شدن با `ClaimPendingActivation` (کلید جدا `RM_PendClaim_<login>_<ticket>`، `GlobalVariableSetOnCondition`) فقط یک‌بار انجام می‌شود → شمارنده/Entry Interval دوبار نمی‌خورد. claimهای قدیمی (>۷ روز) در OnInit پاک می‌شوند.
- **Pendingهای ثبت‌شده قبل از HF5** (Snapshot ندارند): هنگام فعال‌شدن، Snapshot از روی خود پوزیشن (قیمت/SL/حجم؛ `WasHalfRisk=false` چون نامعلوم) ساخته می‌شود. لاگ `source=fill-fallback`.
- **لغو/انقضا:** اگر اردر از لیست ردیابی ناپدید شود، تاریخچه (`HistoryOrderSelect` + `ORDER_STATE`) نگاه می‌شود؛ فقط اگر `CANCELED/EXPIRED/REJECTED` بود `DropPendingSnapshot` کلیدها را از GV و حافظه پاک می‌کند. اگر `FILLED` بود (فعال و همان لحظه بسته‌شده بین دو تیک) یا تاریخچه خوانده نشد، Snapshot **نگه داشته می‌شود**.

## 3) لاگ‌ها (فقط روی رویداد، نه هر تیک)
- `[RM-PEND] snapshot created for order #… (pending; … source=placement)`
- `[RM-PEND] snapshot completed at fill for position #… (from order #…, source=fill)`
- `[RM-PEND] snapshot created for position #… (… source=fill-fallback …)`
- `[RM-PEND] snapshot created for position #… (… source=placement - … EA was not running at the fill)`
- `[RM-PEND] pending order #… ended without a fill (ORDER_STATE_…) - snapshot removed`

## تست‌ها (MT5 دمو، XAUUSD)
| # | سناریو | انتظار |
|---|---|---|
| T1 | Pending LIMIT با دکمه‌ی EA، پر شود، به TP برسد | ردیف CSV کامل (SL، RiskUSD، RiskPct، TradeR، Result=TP، شمارنده‌ها، تایم‌فریم، MaxFavR/MinFavR) |
| T2 | Pending STOP، پر شود، SL بخورد | Result=SL، TradeR≈-1، شمارنده Market +1 با وزن درست، Performance به‌روز |
| T3 | همان، ولی قبل از SL به BE ببر | Protected stop: Market ثابت، Behavior ریست، بدون EarlyExit |
| T4 | پر شود، قبل از +۱R دستی ببند | Result=EarlyExit و Strike Behavior مثل Market |
| T5 | Tag بزن | تگ ذخیره/نمایش؛ فیلدهای CSV پر |
| T6 | Pending بگذار، EA را بردار/چارت را ببند، پر شود، EA را برگردان | Snapshot هست، لاگ `source=placement`، بدون کرش |
| T7 | Pending را دستی لغو کن؛ یکی با expiry بگذار و منقضی شود | لاگ `ended without a fill … snapshot removed`؛ GV `RM_SNAP_*_<ticket>` وجود ندارد (Tools → GlobalVariables) |
| T8 | دو چارت با EA، Pending پر شود | فقط یک بار پردازش (لاگ `[RM-PEND]` یک‌بار)، Cooldown دوبار نخورد |
| T9 | Half Risk فعال هنگام ثبت Pending | `WasHalfRisk` ثبت و وزن 0.5 اعمال |
| T10 | رگرسیون: Market، BE، Half Close، Emergency، Floating DD، D/W/M، قفل‌ها، Tag | بدون تغییر |
| T11 | ۱۰ دقیقه بیکار با ۳ چارت | هیچ کار دوره‌ای جدید؛ `[RM-PERF]` بدون stall |

## ریسک‌های مشاهده‌شده که **عمداً اصلاح نشد** (فقط فهرست)
- `g_tamperStrikedTickets` و `g_halfExemptTickets` فقط در حافظه‌اند (MT4 v101 روی GV)؛ بعد از ری‌استارت گم می‌شوند.
- Snapshotهای بسته‌شده هرگز پاک نمی‌شوند (فقط انقضای ~۴ هفته‌ای GV)؛ اگر Pending وقتی EA خاموش بود دستی لغو شود، Snapshot یتیم تا انقضا می‌ماند.
- Partial fill: ریسک `$` Snapshot بر مبنای حجم کامل اردر است.
- اگر چارتِ ثبت‌کننده بسته شود و هیچ EA دیگری روی همان نماد/Magic نباشد، فیلدهای لحظه‌ی باز شدن placeholder می‌مانند (لاگ `source=placement` در ری‌استارت بعدی).
- مسیر Fallback قدیمی `CheckClosedTrades` برای تیکت‌های بدون Snapshot هنوز هست (برای معاملات قبل از HF5).

## عمداً تغییر نکرد
مسیر Market، Half Close/BE/Trailing/Emergency، BUG-052/053، HF2/HF3/HF4، قفل‌ها و claim بسته‌شدن، Tag، ستون‌های CSV (قدیمی بازنویسی نمی‌شود)، Hub، MT4.
