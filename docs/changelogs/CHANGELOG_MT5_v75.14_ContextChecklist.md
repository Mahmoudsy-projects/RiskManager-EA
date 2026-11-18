# EA MT5 v75.14 — چک‌لیست کانتکست (FEAT-037 / P5)   [کامپایل نشده]
پورت با منطق یکسان از MT4 v81. Hub بدون تغییر (1.16).

## رفتار
- پنجره‌ی Tag Trade از ۳ مرحله به ۴ مرحله رسید: ۱) انتخاب ترید ۲) **چک‌لیست کانتکست** ۳) Strategy ۴) Setup (+ Mental State).
- مرحله‌ی ۲: پنج چک‌باکس مستقل و چندانتخابی (صفر تا هر تعداد): Key Level، Cycle Clarity، Key Time، Candle Confirmation، No Checklist Confirmation. دکمه‌ی NEXT >> به Strategy می‌برد.
- هر کلیک بلافاصله ذخیره می‌شود (بستن پنجره بدون NEXT چیزی را از دست نمی‌دهد). اگر برای آن ترید قبلاً انجام شده باشد، موقع باز شدن از قبل تیک‌خورده است.
- ذخیره روی ترید اصلی زنجیره (Scale-in) انجام و از همان خوانده می‌شود، مثل تگ استراتژی.
- CSV ژورنال: ستون‌های ContextLevelOK / ContextCycleClarityOK / ContextTimeOK / ContextCandleConfirmOK / ContextNone حالا مقدار واقعی true/false دارند. ترید بدون چک‌لیست = هر ۵ false.

## فایل‌ها (در پوشه‌ی Files ترمینال، خودکار ساخته می‌شوند)
- RM_ContextChecklist.txt : متن پنج گزینه (قابل‌ویرایش؛ هر بار پنجره باز شود دوباره خوانده می‌شود). فرمت: `LEVEL: متن`.
- RM_ContextTags.csv : نگاشت Ticket → ۵ مقدار. بین چارت‌ها هم‌گام است (قفل + نسخه‌ی GlobalVariable مثل تگ‌ها).

## تست پیشنهادی
1) Tag Trades → ترید → مرحله‌ی ۲ را ببین (۵ گزینه + NEXT) → دو گزینه تیک بزن → NEXT → Strategy → Setup.
2) پنجره را ببند و دوباره باز کن و همان ترید را انتخاب کن: دو گزینه باید تیک‌خورده باشد.
3) بعد از بسته‌شدن ترید، فایل RM_TradeJournal_*.csv: پنج ستون Context مقدار درست داشته باشند.
4) ورود ادامه‌ای Scale-in: کانتکست ترید اصلی را نشان بدهد.
فایل‌ها: RM_Tools.mq5, RM_MainEventHandlers.mq5, RM_Reports.mq5, RM_RiskManager_Main.mq5 (نسخه)
