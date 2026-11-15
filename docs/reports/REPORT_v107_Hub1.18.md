# گزارش تحویل — EA v107.00 + Executive Hub 1.18

وضعیت نهایی: روی `main` مرج شده (PR #5، #6، #7؛ کامیت `441b572`). **همه‌ی تست‌های پذیرش T1–T10 توسط Mahmoud روی حساب/دمو تأیید شد (۲۰۲۶-۱۱-۱۵).** کد را من نمی‌توانستم کامپایل کنم؛ کامپایل را Mahmoud در MetaEditor انجام داد (یک خطا پیدا شد و رفع شد، پایین ببین).

## ۱. نسخه‌ها
- EA: `RiskManager_EA_v107.mq4`، `#property version "107.00"` (تغییرنام از v106).
- Hub: `ExecutiveHub_v1.18.mq4`، version "1.18" (تغییرنام از 1.17).
- `STRAT_LIST_VERSION` = 107.

## ۲. بالانس براکت (بعد از حذف string/comment؛ باز/بسته)
| فایل | `{ }` | `( )` | `[ ]` |
|---|---|---|---|
| RM_SessionTime.mqh (EA و Hub یکی) | 33/33 | 209/209 | 0/0 |
| RM_Tools.mqh | 276/276 | 1706/1706 | 294/294 |
| RM_Dashboard.mqh | 101/101 | 759/759 | 37/37 |
| RiskManager_EA_v107.mq4 | 195/195 | 1411/1411 | 86/86 |
| ExecutiveHub_v1.18.mq4 | 448/448 | 2944/2944 | 256/256 |

## ۳. MD5
- `RM_SessionTime.mqh` در EA و Hub: `0be37e8c08765ff997514f627f046595` (byte-identical).
- فایل‌های دست‌نخورده (طبق compare روی GitHub فقط فایل‌های بند ۴ تغییر کرده‌اند): RM_AutoActions `9efaf975…`، RM_Common `29c308a1…`، RM_Config `442f5ea3…`، RM_CooldownEngine `8c11c88a…`، RM_DrawdownEngine `330884d2…`، RM_News `046038f8…`، RM_Reports `d3a3842c…`، RM_RiskCalc `d4576524…`، RM_Snapshot `a6304905…`، RM_TradeExecution `1bd01aff…`، RM_Trailing `f0b04c6f…`.

## ۴. خلاصه‌ی diff به‌ازای فایل
- `RM_SessionTime.mqh` (+164/−6): لیبل ورودی `InpServerUtcOffsetMin` (آفست تابستانی)؛ جدید `ST_IsEUDST`، `ST_IsAUDST`، `ST_FirstSundayDay`، `ST_LastSundayDay31`، `ST_MarketStdOffsetSec`، `ST_MarketUtcOffsetSec`، `ST_MarketLocalToUtc`، `ST_InputRuleOffsetAtUtc`، `ST_ServerOffsetForUtc` (آفست per-day)، `ST_ComputeSessionServerTimeMkt`، `ST_ComputeSessionByDaysAgoMkt`؛ ثابت‌های `ST_MKT_*` و `ST_SYDNEY_FINAL_HOUR_LOCAL`؛ شاخه‌ی تستر و fallback در `ST_ServerOffsetSec`؛ `ST_ComputeSessionServerTime` حالا آفست per-day می‌گیرد. امضای `ST_ComputeSessionByDaysAgo` و فیکس عبور از نیمه‌شب دست‌نخورده.
- `RM_Tools.mqh` (+176/−30): جدول `KeyTime_GetLine` (+پارامتر `mkt`)، `BuildOneKeyTimeLine` (+`mkt`,`dayOffset`)، حلقه‌ی `BuildSessionWindows`؛ حالت FULL/COMPACT (`g_swMode`, GV `RM_SWMode_<sym>`)؛ `SessionLevel_ComputeServerTime`/`SessionLevel_BuildOneBox` (+`mkt`)، بازه‌های Tokyo/London/NY در `SessionLevel_BuildWindows`؛ FEAT-063 (`SessionLevel_GetHL`، `SessionLevel_ExpandedColor`، `SessionLevel_BuildOneBoxExpanded`، `g_slMode`, GV `RM_SessLvlMode_<sym>`، شاخه‌ی EXPANDED در `SessionLevel_UpdateVertical`)؛ `// TODO v108` روی `SessionLevel_TagForTime`؛ لیست پیش‌فرض + `EnsureStrategySetupsSeed` (مهاجرت ۱۰۶→۱۰۷).
- `RM_Dashboard.mqh` (+17/−10): کپشن/رنگ دکمه‌های KEY TIME و SESSION (دو جا هرکدام).
- `RiskManager_EA_v107.mq4` (+15/−5): version و header؛ هندلر `BTN_SW` و `BTN_SESSLVL` (چرخه‌ی سه‌حالتی).
- `ExecutiveHub_v1.18.mq4` (+16/−12): version/changelog؛ پیش‌فرض‌های SOB (Tokyo 09:00–10:00 JST، London 08:00–09:00، NY 08:30–09:30 بدون تغییر)؛ `SOB_Recalculate`/`SOB_ProcessSession` با پارامتر بازار. NY Edge دست‌نخورده (مسیر NY؛ آفست per-day خودکار).
- `MQL4_Files/RM_StrategySetups.txt` (+1/−1): TR-BREAKOUT در نمونه‌ی پیش‌فرض.
- docs: `CHANGELOG_v107.md`، `CHANGELOG_Hub_1.18.md`، راهنمای فارسی v107 (راهنمای v106 + ضمیمه)؛ README.

## ۵. جدول لنگر Key Time (نهایی)
M1 NY 17:00 (روز قبل) | M2 Tokyo 09:00 JST | M3 Tokyo 10:00 | M4 Berlin 08:00 | M5 London 08:00 | M6 NY 09:30 | M7 NY 11:00 | M8 NY 13:00 | S1 Tokyo 13:00 | S2 Sydney `ST_SYDNEY_FINAL_HOUR_LOCAL`=16 | S3 Tokyo 19:00 | S4 NY 08:30 | S5 NY 14:00 | S6 NY 16:00 | S7 London 17:00 | S8 Tokyo 18:00. نام آبجکت‌ها/رنگ/ترتیب/تعداد ۱۶ و culling v95/96 بدون تغییر.

## ۶. تصمیم‌هایی که متفاوت از پیام تسک است (تأیید شده توسط Mahmoud یا گزارش‌شده)
1. **London close در هفته‌ی ناهمسان اکتبر = ۲۰:۰۰ بروکر** (هفته‌ی عادی ۱۹:۰۰)؛ مقدار «۱۹→۱۸» در تسک با قاعده نمی‌خواند. نگه‌داشته شد.
2. **عدم‌تطابق آفست زنده/قاعده:** به‌جای «زنده برای امروز + دلتای قاعده برای بقیه»، برای همه‌ی روزها همان آفست زنده + `[ST-DIAG] offset-vs-rule MISMATCH` (دلتا روی مقدار غیرعادی می‌توانست +۴ بدهد).
3. **FEAT-061 در همین نسخه آمد:** KEY TIME سه‌حالتی OFF→FULL→COMPACT→OFF (خاموش‌کردن از FULL دو کلیک). پذیرفته شد.
4. **FEAT-063 (خارج از تسک، به درخواست Mahmoud حین کار):** SESSION سه‌حالتی OFF→COMPACT→EXPANDED→OFF؛ EXPANDED = باکس High..Low (از M15) پشت کندل‌ها، Tokyo زرد/London سبز/NY آبی، «شفافیت» با ترکیب رنگ و پس‌زمینه (`SL_EXP_BLEND_PCT`=30؛ MT4 آلفا ندارد)، بازسازی فقط با کندل M15 جدید.
5. fallback زنده‌ی کالیبره‌نشده هم مثل تستر اینپوت را «تابستانی» می‌گیرد و زمستان را از قاعده کم می‌کند (فراتر از متن بند ۳.۱).
6. Hub Tokyo SOB حالا «صبحِ همان روز» است (d=0 امروز، d=1 دیروز)؛ قبلاً d=0 باکس آینده‌ی امشب بود. در تعطیلات بازار (مثلاً یکشنبه) با `SOB_CurrentDayOnly` چیزی رسم نمی‌شود (رفتار مورد انتظار؛ پیشنهاد v108: تا ۵ روز عقب‌تر).
7. مهاجرت لیست استراتژی از v106 فایل را بازنویسی می‌کند؛ خطوط بدون «:» حذف می‌شوند (فقط در بکاپ می‌مانند). برای فایل بدون چنین خطی اثری ندارد.
8. نمونه‌ی `MQL4_Files/RM_StrategySetups.txt` در ریپو هم TR-BREAKOUT گرفت (Mahmoud: فایل شخصی نیست؛ لیست پیش‌فرض است).

## ۷. خطای کامپایل پیدا‌شده
`no #import declaration` روی `RM_Tools.mqh:2061`: پروتوتایپ جداگانه‌ی `AddSetupIfMissing` (MQL4 پروتوتایپ بدون بدنه را import می‌گیرد). پروتوتایپ حذف شد؛ ترتیب تعریف توابع در MQL4 آزاد است.

## ۸. نتایج آزمون (انجام‌شده توسط Mahmoud)
- T1 زمستان (۱۳ نوامبر): Tokyo باکس/SOB ۰۲:۰۰–۰۳:۰۰، خطوط Tokyo ۰۲:۰۰/۰۳:۰۰ ✓.
- T2/T4: ۳۰ اکتبر باکس Tokyo ۰۳:۰۰–۰۴:۰۰ و ۲ نوامبر ۰۲:۰۰–۰۳:۰۰ (جابه‌جایی در مرز ۱ نوامبر) ✓.
- T3: هفته‌ی ناهمسان اکتبر (۲۷ اکتبر): Frankfurt ۱۰:۰۰، London ۱۱:۰۰، NY 09:30=۱۶:۳۰، ۱۱:۰۰/۱۳:۰۰ NY = ۱۸:۰۰/۲۰:۰۰، راه‌اندازی NY ۰۰:۰۰ ✓. روز عادی ۵ نوامبر: Frankfurt ۰۹:۰۰، London ۱۰:۰۰ ✓.
- T5: خطوط NY مثل v106 ✓. T6: باکس‌های Tokyo/London/NY (۲۷ اکتبر و ۵ نوامبر) ✓ (پایان باکس NY روی طلا به‌خاطر استراحت روزانه روی ۰۰:۰۰ دیده می‌شود، صحیح است).
- T7: Hub بدون EA ✓ (SOB خالی در یکشنبه = بازار بسته، نه باگ). T8: لیست جدید، بکاپ، تگ‌کردن با دمو بیت‌کوین و Setup در CSV ✓. T9: استراتژی‌تستر ✓. T10: News (ForexFactory؛ Core PPI ۱۵:۳۰)، Cooldown (بعد از بستن معامله‌ی دمو +۱ واحد)، Reports/CSV ✓.
- COMPACT (Key Time) و EXPANDED (Session) ✓.

## ۸.۱ بررسی CSV (FEAT-062)
نویسنده‌ها (`SaveTradeTagsFile` و `ExportTradeJournalCSV` با `FILE_CSV`,`,`) فاصله‌ی ابتدایی اضافه نمی‌کنند؛ Setup از `GetSetupsForStrategy` (trim‌شده) می‌آید. تنها مسیر trim‌نشده: خواندن دستی `RM_TradeTags.csv`. تغییری داده نشد.

## ۹. چیزهایی که بدون کامپایل/تست قابل تأیید نبود و حالا تأیید شده
همه‌ی موارد بالا (کامپایل EA/Hub، مسیر کالیبراسیون زنده، تستر). تنها باقی‌مانده: تگ Session در CSV عمداً با قاعده‌ی v57 است (`TODO v108`)؛ ردیف‌های قدیمی هرگز بازنویسی نمی‌شوند.

## ۱۰. موارد باز / v108
- `SessionLevel_TagForTime` (فاز B).
- Hub SOB در تعطیلات: نمایش آخرین باکس موجود.
- برچسب‌های `mt4-v107` و `hub-v1.18` (نمی‌شد از محیط ساخت؛ Mahmoud دستی بسازد).
- Notion: صفحه‌ی «MT4 v107 + Hub 1.18 — FEAT-060/061/062/063» به‌روز شد.
