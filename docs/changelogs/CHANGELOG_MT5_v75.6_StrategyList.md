# EA MT5 v75.6 — لیست پیش‌فرض استراتژی/ستاپ (پورت MT4 v80 / v106 / v107)

NOT COMPILED — لطفاً کامپایل و تست کنید. Hub بدون تغییر (1.12).

## لیست جدید
- CYCLE_MATURITY: REJECTION_CANDLE, MTR_PB, MTR_LINE_BREAK, MTR_BREAKEVEN_RETEST, TR-BREAKOUT
- SPIKE_TRADING: BREAKOUT_CANDLE, SP2L_FIRST_PB_CANDLE, SP2L_50, BTB
- CHANNEL_TRADING: TREND_LINE_TOUCH, PREVIOUS_LEG_50, REJECTION_CANDLE
- RANGE_TRADING: EDGE_LIMIT, REJECTION_CANDLE

(قبلاً در MT5: «BTB: A,B,C,+A,+B,+C» و «LP: BREAKOUT, DISCOUNT».)

## رفتار
- فایل `RM_StrategySetups.txt` نبود → با لیست جدید ساخته می‌شود.
- فایل قدیمی بود → **یک‌بار** بکاپ به `RM_StrategySetups_backup.txt` و جایگزینی با لیست جدید (نسخه‌ی لیست در GV `RM_StratListVer`). بعد از آن ویرایش‌های دستی هرگز overwrite نمی‌شوند.
- اگر قبلاً لیست ۱۰۶ بوده، فقط TR-BREAKOUT اضافه می‌شود.
- ⚠️ اگر در MT5 ستاپ‌های دستی اضافه کرده‌اید، بعد از اولین اجرا در فایل بکاپ هستند، نه در لیست فعال.

## تست‌ها
- S1: فایل قدیمی را نگه دارید و EA را اجرا کنید → لیست جدید، و فایل backup با محتوای قبلی.
- S2: پنجره‌ی تگ معامله (Strategy → Setup) ۴ استراتژی و ستاپ‌هایشان را نشان دهد.
- S3: یک ستاپ دستی در فایل اضافه کنید، EA را ری‌استارت کنید → دست‌نخورده بماند.
- S4: فایل را پاک کنید → دوباره با لیست جدید ساخته شود.

نسخه: "75.60".
