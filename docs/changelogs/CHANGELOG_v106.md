# CHANGELOG v106 — شدت Key Time، سطوح جدید Measure Move، لیست جدید Strategy/Setup

> ⚠️ **کامپایل نشده.** فقط بالانس `{}` `()` `[]` (بعد از حذف کامنت و رشته) و diff با v105 بررسی شده. قبل از استفاده در MetaEditor کامپایل و اول روی دمو (XAUUSD) تست کنید.
> Hub بدون تغییر (v1.17، بایت‌به‌بایت یکسان). MT5 دست نخورده. ریسک، لات، Cooldown، DD، Behavior، Entry Interval، Scale-in، تنظیمات مشترک و CSV (۴۷ ستون، `RootTicket` آخر) بدون تغییر.

## ۱) FEAT-047 — شدت خطوط Key Time
- ورودی جدید **`InpKeyTimeIntensity`** (عدد صحیح، درصد، پیش‌فرض **۳۰**) با برچسب «Key Time line intensity (%)». گروه جدید «Key Time Lines (v106)» در `RM_Config.mqh`. تنظیم نمایشیِ هر چارت است؛ جزو ۲۲ ورودی مشترک نیست و Publish نمی‌شود.
- `GetKeyTimeLineColor()` (در `RM_Tools.mqh`): به‌جای اعداد ثابت ۱۷ و ۱۰، خطوط اصلی مستقیماً همین درصد را می‌گیرند و خطوط فرعی با همان نسبت قبلی: `round(درصد × 10 / 17)`، حداقل ۱ (کف ۸ قبلی برداشته شد تا در ورودی‌های کم، فرعی از اصلی پررنگ‌تر نشود). در مقدار پیش‌فرض: اصلی ۳۰، فرعی ۱۸.
- عدد ساعت همان رنگ خودش را دارد، پس بالا بردن شدت خوانایی عدد را هم بالا می‌برد.
- **بازه‌ی مجاز ۵ تا ۸۰** و خارج از آن بی‌صدا clamp می‌شود (حداقل ۵ به درخواست شما، برای تست مقادیر کم‌رنگ).
- رنگ فقط هنگام (باز)ساخته شدن خطوط خوانده می‌شود. تایمر، polling یا redraw جدید اضافه نشد. خطوط خبر USD رنگ ثابت خودشان را دارند و از این ورودی تأثیر نمی‌گیرند.

## ۲) BUG-062 — سطوح جدید MEASURE MOVE
- `CreateFiboMeasureMove()` حالا دقیقاً ۷ سطح Fibonacci شخصی شما را می‌سازد، به همین ترتیب: `0.0 END`، `0.5 50%`، `0.618 61.8%`، `1.0 START`، `1.236 123.6%`، `1.618 161.8%`، `2.0 200%`.
- لنگرها طبق **ترتیب کلیک** است: کلیک اول = سطح ۰ (تگ END)، کلیک دوم = سطح ۱ (تگ START)، مثل Fibo native شما. مرتب‌سازی قبلی high/low حذف شد، پس سطوح ۱.۲۳۶ و ۱.۶۱۸ و ۲.۰ همیشه بعد از سطح ۱ و در جهت سطح ۰ به ۱ ادامه می‌یابند.
- همه‌ی سطوح **خط ممتد نازک** (`STYLE_SOLID`، عرض ۱) شدند تا با خط‌چین‌های Weekly Map و High/Low اشتباه نشوند. رنگ همان `GetFiboMeasureColor()` است.
- دکمه، کپشن، جایگاه در پنل Utility، جریان «آماده‌سازی و دو کلیک»، پیش‌نمایش هنگام درگ، `FIBO_ARM_MS`، نام یکتای هر آبجکت، قابلیت انتخاب/درگ، نبودن ray و پیام‌های وضعیت بدون تغییر. ابزار R/R (`CreateFiboRMultiple`) دست نخورده. کدِ هندلینگ کلیک در فایل اصلی هم تغییری نکرد (از قبل P1 و P2 را به ترتیب کلیک می‌فرستاد).

## ۳) STRAT-LIST — لیست جدید Strategy/Setup
لیست پیش‌فرض (در `WriteDefaultStrategySetups()` و فایل `MQL4_Files/RM_StrategySetups.txt`) دقیقاً این ۴ خط است:
```
CYCLE_MATURITY: REJECTION_CANDLE, MTR_PB, MTR_LINE_BREAK, MTR_BREAKEVEN_RETEST
SPIKE_TRADING: BREAKOUT_CANDLE, SP2L_FIRST_PB_CANDLE, SP2L_50, BTB
CHANNEL_TRADING: TREND_LINE_TOUCH, PREVIOUS_LEG_50, REJECTION_CANDLE
RANGE_TRADING: EDGE_LIMIT, REJECTION_CANDLE
```
- `STRAT_LIST_VERSION` از ۸۰ به **۱۰۶** رسید. منطق مهاجرت (`EnsureStrategySetupsSeed`) دست نخورده است.
- ⚠️ **نصب روی ترمینالِ موجود:** در اولین اجرای v106، لیست قدیمی **یک‌بار** در `RM_StrategySetups_backup.txt` بکاپ می‌شود و لیست جدید جایگزین می‌شود؛ لاگ: `strategy list migrated to v106 default`. از آن به بعد ادیت‌های دستی شما دیگر overwrite نمی‌شوند.
- تگ‌های قدیمی با نام‌های قدیمی مهم نیستند و کد تبدیل ننوشتم. در کل کد هیچ وابستگی به نام‌های حذف‌شده (`CONTINUOUS_LEG1/2/3`، `SPIKE_BREAKOUT`، `LP`، `EXHAUSTION_CANDLE`، `SP2L_PB`، `PB`، `BREAKOUT`، `DISCOUNT`) پیدا نشد؛ فقط خودِ لیست پیش‌فرض و فایل txt بود.

## فایل‌ها
- `RiskManager_EA_v106.mq4` (جایگزین `_v105`): نسخه ۱۰۶.۰۰ و ۳ خط کامنت هدر
- `RM_Config.mqh`: ورودی و دو `#define` حداقل/حداکثر
- `RM_Tools.mqh`: `GetKeyTimeLineColor`، `CreateFiboMeasureMove`، `STRAT_LIST_VERSION`، `WriteDefaultStrategySetups`
- `MQL4_Files/RM_StrategySetups.txt`: ۴ خط جدید
- بقیه (از جمله `RM_News.mqh` و Hub v1.17) بدون تغییر

## تست پذیرش (دمو، XAUUSD)
1. ورودی ۳۰ روی چارت تیره و روشن (تم ۲ و ۵ Hub): خطوط و عدد ساعت واضح‌تر از v105 ولی نه سنگین؛ اصلی‌ها قوی‌تر از فرعی‌ها.
2. ورودی ۵ (حداقل)، ۱۲ و ۸۰ بدون خطا؛ مقدار ۲ یا ۱۰۰ بی‌صدا به ۵ یا ۸۰ می‌رسد؛ در همه‌ی مقادیر اصلی‌ها پررنگ‌تر از فرعی‌هاست.
3. تغییر تم چارت: رنگ Key Time بعد از redraw عادی (زوم/اسکرول) هماهنگ می‌شود.
4. MEASURE MOVE بالا و پایین: ۷ سطح با لیبل‌های END، 50%، 61.8%، START، 123.6%، 161.8%، 200%؛ اکستنشن‌ها بعد از START (سطح ۱)؛ خط ممتد نازک؛ پیش‌نمایش درگ کار می‌کند؛ آبجکت قابل جابه‌جایی است.
5. Fibonacci native → MEASURE MOVE → دوباره Fibonacci native: سطوح native دست نخورده.
6. R/R و بقیه‌ی دکمه‌های Utility بدون تغییر.
7. ری‌استارت روی ترمینال موجود: لاگ مهاجرت، ساخت `RM_StrategySetups_backup.txt`، ۴ استراتژی جدید در Tag Trade؛ ری‌استارت دوم ادیت‌های دستی را overwrite نمی‌کند.
8. پنجره‌ی Tag Trade با طولانی‌ترین نام‌ها (`SP2L_FIRST_PB_CANDLE`، `MTR_BREAKEVEN_RETEST`): کامل خوانا و بدون بیرون‌زدگی.
9. رگرسیون: Cooldown، DD، Behavior، ثبت سفارش، Hub: بدون تغییر.
