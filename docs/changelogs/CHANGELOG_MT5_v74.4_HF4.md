# CHANGELOG MT5 v74.4 — HF4: Emergency بدون Strike + بهبود پنل (فقط MT5، بر پایه‌ی v74.3)

> ⚠️ **کامپایل نشده** (فقط تعادل `{}` `()` `[]` و diff بررسی شده). `.ex5` قدیمی را پاک کن، `RM_RiskManager_Main.mq5` را کامپایل کن و اگر خطایی آمد متنش را بفرست. **ارتقا را وقتی هیچ قفلی فعال نیست انجام بده.**

**پایه:** v74.3 ← **خروجی:** v74.4 r2 (`"74.41"`). Hub بدون تغییر (1.08). MT4 دست‌نخورده.
**فایل‌های تغییرکرده (۷):** `RM_Config`، `RM_CooldownEngine`، `RM_Dashboard`، `RM_DrawdownEngine`، `RM_MainEA_DashboardHelpers`، `RM_Tools`، `RM_RiskManager_Main` (فقط نسخه). بقیه byte-identical با v74.3.

## 1) Emergency Close دیگر Strike رفتاری نمی‌زند
- ترید بسته‌شده توسط Emergency Close (پرچم `RM_EMERGENCY_<ticket>`) در `CheckClosedTrades` دیگر به‌عنوان EarlyExit حساب نمی‌شود و `GV_BEH_COUNT` و شمارنده‌ی خطای رفتاری را زیاد نمی‌کند.
- لاگ: `[RM-EMERG] pos=#... closed by Emergency Close - no Behavior strike`.
- بقیه‌ی مسیرها (SL، TP/+1R، Protected Stop، بستن دستی) بدون تغییر. CSV همچنان `EmergencyClose` می‌نویسد.

## 2) ترتیب Inputs
- گروه **Floating Drawdown Protection** از وسط تنظیمات به بالای «Risk Limits: Daily» (بعد از Per-Trade / Total Open) رفت. فقط ترتیب نمایش؛ نام و مقدار متغیرها و فایل‌های `.set` ثابت.

## 3) پنل
- **فونت:** همه‌ی دکمه‌ها و لیبل‌های پنل → `Segoe UI Bold` / `Segoe UI` (ثابت‌های `RM_UI_FONT_BOLD/REG` در `RM_MainEA_DashboardHelpers.mq5`؛ تغییر فونت = عوض کردن همان دو خط). ردیف‌های Consolas پنل Performance و لیبل‌های روی چارت (خط‌ها، تایمر کندل) تغییر نکردند.
- **سایز:** دکمه‌های Utility (Tools و Trading Reports) از ۷ → ۸ (برای از بین بردن حالت پیکسلی).
- **دکمه ریسک:** متن `Full 0.25%` / `Half 0.125%` (قبلاً `Full Risk: 0.25%` که به سایز ۶ کوچک می‌شد).
- **Floating:** `Floating: -0.10% / 2.00%` (مقدار لحظه‌ای / سقف `InpMaxFloatingDDPercent`). اگر `InpEnableFloatingDD=false` فقط مقدار لحظه‌ای. رنگ‌ها مثل قبل.

## 4) لاگ
- `RM v74 startup-grace diag` حداکثر یک خط در ثانیه برای هر چارت (قبلاً در هر تیک).

## تست‌ها (روی دمو)
- **T1:** `InpMaxFloatingDDPercent` را موقتاً پایین بیاور و Emergency را فعال کن. انتظار: ترید(ها) بسته شوند، CSV `EmergencyClose` بنویسد، **شمارنده Behavior زیاد نشود**، در لاگ `[RM-EMERG] ... no Behavior strike` بیاید، و `[DEBUG-BEHCOUNT] Strike` برای آن تیکت‌ها نباشد.
- **T2:** بستن دستی زیر +1R هنوز Strike بزند (رگرسیون).
- **T3:** Inputs: گروه Floating قبل از Daily باشد؛ مقدارهای قبلی (۲٪ و true) سر جایشان.
- **T4:** پنل Trading: خط `Floating: x% / 2.00%` درست و رنگ‌ها (نارنجی نزدیک سقف، قرمز در سقف) مثل قبل. دکمه ریسک با Full و Half کامل دیده شود و کوچک نشود.
- **T5:** پنل Utility: دکمه‌ها (Candle Timer، D/W/M H/L، Markers، Export CSV، Tag Trades، Session، Key Time، Trading Reports با سه تب) خوانا، بدون بریدگی و بدون پیکسلی.
- **T6:** در LayoutScale دیگر (مثلاً 90 یا 80) متن دکمه‌ها بیرون نزند.
- **T7:** اگر فونت Segoe UI روی سیستم نبود و پنل بد دیده شد، بگو تا ثابت‌ها را عوض کنم.
- **T8:** بعد از ری‌استارت EA، لاگ `startup-grace diag` حداکثر ثانیه‌ای یک خط (نه ده‌ها خط در ثانیه).
- **T9:** رگرسیون HF1/HF2/HF3 (تگ، Performance، قفل‌ها، Claim) بدون تغییر.

## 5) r2 — پنجره Tag Trade درشت‌تر (فیدبک بعد از تست)
- مرحله ۱ (انتخاب ترید): بدون تغییر (برچسب‌ها بلندند).
- مرحله ۲ و ۳ (Strategy / Setup): ردیف‌ها بلندتر (۳۰ به‌جای ۲۲) و فونت تا ۱۰ (خودکار با عرض متن)، دکمه BACK ۹، متن راهنمای `Add new...` ۸.
- پنجره Mental State: پهن‌تر (تا ۲۷۰ پیکسل، محدود به فضای خالی سمت چپ)، ردیف‌ها ۳۰، فونت دکمه‌ها تا ۱۰ (قبلاً ثابت ۶)، `Clear` و هدر ۹.
- هندسه‌ی ردیف/پنجره برای رسم و برای تشخیص کلیک از یک تابع مشترک (`TagRowH`, `TagMentalWinW`) می‌آید تا کلیک داخل پنجره اشتباهاً «بیرون» حساب نشود.

## تست‌های r2
- **T10:** Tag Trade → مرحله Strategy و Setup: دکمه‌ها درشت و خوانا، بدون بریدگی؛ BACK/X درست کار کنند.
- **T11:** Mental State: هر ۶ گزینه + Clear درشت، کلیک روی آن‌ها پنجره را نبندد و انتخاب ثبت شود.
- **T12:** با LayoutScale دیگر (90/80) و با پنل در چپ/راست چارت، پنجره‌ها از چارت بیرون نزنند.
- **T13:** مرحله انتخاب ترید هنوز فشرده و کامل است. Half Close + Tag (تست قبلی) هنوز یک ردیف.

## عمداً تغییر نکرد
منطق قفل‌ها، دوره‌ها، Claim، Tag، Hub، MT4.
