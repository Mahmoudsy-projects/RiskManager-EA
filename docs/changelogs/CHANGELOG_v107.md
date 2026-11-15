# CHANGELOG v107 — FEAT-060 / FEAT-061 / FEAT-062

> ⚠️ **هشدار: این نسخه کامپایل نشده است.** فقط بالانس براکت (بعد از حذف string/comment) و شبیه‌سازی پایتونِ منطقِ DST انجام شد. قبل از استفاده در MetaEditor کامپایل و تست‌های T1–T10 اجرا شود.

Base: EA v106.00 + Hub 1.17 → EA v107.00 (`RiskManager_EA_v107.mq4`) + Hub 1.18.

## FEAT-060 — DST خودکارِ لنگرشده به بازار
- `RM_SessionTime.mqh` (کپی byte-identical در EA و Hub):
  - جدید: `ST_IsEUDST`, `ST_IsAUDST`, `ST_MarketStdOffsetSec`, `ST_MarketUtcOffsetSec`, `ST_MarketLocalToUtc`, بازارها `ST_MKT_NY/LONDON/BERLIN/TOKYO/SYDNEY/UTC`.
  - جدید: `ST_ServerOffsetForUtc(utc)` — آفستِ سرور per-day: UTC+3 در US-DST وگرنه UTC+2، کالیبره با آفستِ زنده (`ST_ServerOffsetSec` همچنان منبعِ حقیقتِ «الان»). عدم‌تطابقِ زنده/قاعده → `[ST-DIAG] offset-vs-rule MISMATCH` و برای همه‌ی روزها همان آفستِ زنده.
  - جدید: `ST_ComputeSessionServerTimeMkt` / `ST_ComputeSessionByDaysAgoMkt` (market-aware). امضای `ST_ComputeSessionByDaysAgo` و `ST_ComputeSessionServerTime` دست‌نخورده (فقط آفستِ داخلی per-day شد). فیکسِ عبور از نیمه‌شب سر جایش.
  - تستر: ورودی `InpServerUtcOffsetMin` = آفستِ **تابستانیِ آمریکا**؛ زمستان خودکار −۶۰ دقیقه. 99999 = مثل قبل. لیبلِ ورودی اصلاح شد. همین قاعده برای حالتِ زنده‌ی کالیبره‌نشده (fallback) هم اعمال می‌شود.
- `RM_Tools.mqh`: جدولِ ۱۶ خطِ Key Time با بازارِ لنگر (M1 NY17؛ M2/M3 توکیو ۰۹/۱۰ JST؛ M4 فرانکفورت ۰۸؛ M5 لندن ۰۸؛ M6–M8 NY؛ S1 توکیو ۱۳ JST؛ S2 سیدنی ثابتِ `ST_SYDNEY_FINAL_HOUR_LOCAL`=۱۶؛ S3 توکیو ۱۹؛ S4–S6 NY؛ S7 لندن ۱۷؛ S8 توکیو ۱۸). نام/رنگ/ترتیب/تعدادِ خطوط و culling v95/96 بدون تغییر.
- باکس‌های Session Level: Tokyo ۰۹–۱۸ JST (=۰۰–۰۹ UTC)، London ۰۸–۱۷ لندن، NewYork ۰۹–۱۸ نیویورک.
- `SessionLevel_TagForTime` (تگِ CSV) عمداً دست‌نخورده — `// TODO v108`.

## FEAT-061 — Key Time FULL / COMPACT
دکمه‌ی KEY TIME حالا سه‌حالتی: OFF → ON(FULL، پیش‌فرض) → COMPACT (فقط ۸ خطِ اصلی) → OFF. حالت در GV `RM_SWMode_<symbol>` ذخیره می‌شود؛ نبودنِ GV = FULL.

## FEAT-062 — TR-BREAKOUT
پنجمین Setupِ CYCLE_MATURITY. `STRAT_LIST_VERSION` 106→107. مهاجرت از v106: بکاپ `RM_StrategySetups_backup.txt` سپس فقط افزودنِ TR-BREAKOUT (ویرایش‌های کاربر حفظ). از نسخه‌های <106: رفتارِ قبلی (بکاپ + لیست پیش‌فرض).
بررسیِ CSV: نویسنده‌ها (`SaveTradeTagsFile`، `ExportTradeJournalCSV` با `FILE_CSV`,`,`) هیچ فاصله‌ی ابتدایی اضافه نمی‌کنند؛ Setup از `GetSetupsForStrategy` (trim‌شده) می‌آید. تنها مسیرِ trimنشده خواندنِ دستیِ `RM_TradeTags.csv` است. باگِ واضحی نبود → تغییری داده نشد.

## فایل‌های تغییرکرده
`RM_SessionTime.mqh`، `RM_Tools.mqh`، `RM_Dashboard.mqh` (کپشن/رنگِ دکمه)، `RiskManager_EA_v107.mq4` (نسخه، هندلرِ BTN_SW)، `MT4/MQL4_Files/RM_StrategySetups.txt` (نمونه‌ی پیش‌فرض). بقیه‌ی فایل‌ها MD5-identical با v106.
