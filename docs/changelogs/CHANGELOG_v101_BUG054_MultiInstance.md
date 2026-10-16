# v101 — BUG-054 / 055 / 057 (Multi-Instance / Shared State) — MT4 only

> هشدار: کامپایل MQL4 در محیط توسعه انجام نشد (فقط بالانس براکت، diff و diff -q). قبل از استفاده فایل .ex4 قدیمی را حذف و در MetaEditor کامپایل کنید.

## نکتهٔ اول: چه چیزی باگ MT4 نبود
- BUG-055/057 روی MT4 «فیلتر Symbol» نبود؛ ریشه، **Snapshot فقط در حافظهٔ هر چارت** بود (چارت دوم تیکت چارت اول را نمی‌دید → R/RB/آمار متفاوت).
- GlobalVariableها در MT4 per-terminal هستند و بین چارت‌ها مشترک‌اند؛ مشکل از «چک و ست غیراتمی» و «حافظهٔ محلی» بود.

## تغییرات
- **Claim اتمیک بستن هر تیکت** (RM_CooldownEngine): mutex با GlobalVariableSetOnCondition (`RM_CLAIMLOCK_A<acct>_M<magic>_`) + کلید `RM_CLOSECLAIM_A.._M.._<ticket>`. فقط برندهٔ claim استرایک/ریست/آمار را اجرا می‌کند؛ بقیه log `[RM-MI] ... skipped` می‌زنند و تیکت را از لیست حذف می‌کنند.
- **Chain claim یک‌بار به‌ازای root** (ProcessChainMarketStop، با RM_ClaimKey).
- **Snapshot reload/sync**: `RM_EnsureSnapshot`، `RM_SyncSnapshotsFromGV`، `RM_RefreshChainSnapshots`، `RM_SnapshotAutoSync` (شمارندهٔ نسخه `RM_SNAPVER`؛ بدون اسکن per-tick). MaxFavR/MinFavR یکنواخت (monotonic) روی GV.
- **Cooldown**: lock-end بازار/رفتار و LastEntry هر تیک از GV خوانده می‌شود.
- **پرچم‌های مشترک**: HalfExempt، AutoHalfDone، TamperStriked (GV-backed + claim).
- **Tags**: reload قبل از save (رفع lost-update)، open با share-flag و retry، شمارندهٔ نسخه `RM_TagFileVer`/`RM_CtxTagFileVer` و `RM_SyncTagsIfChanged()`؛ بدون I/O per-tick.
- **Reports**: CSV قبل از export، snapshot و tag را sync می‌کند (فایل full-rewrite است؛ ردیف تکراری ندارد).
- لاگ‌ها `[RM-MI]`؛ `#property version "101.00"`؛ `g_rmPerfLog` همچنان false.

## محدودیت‌ها (مستند، بدون تغییر)
- Claim فقط در یک ترمینال معتبر است؛ at-most-once (کرش وسط پردازش retry نمی‌شود).
- اگر lock timeout شود: fallback غیراتمی + warning.
- `iTime(Symbol())` برای شروع دوره‌ها per-symbol است؛ EmergencyCloseAll و floating-P/L با Symbol() فیلتر می‌شوند؛ کلید lock-end per-symbol ولی شمارنده‌ها account-wide؛ لیست pending بعد از restart چارت از دست می‌رود؛ ریست شمارنده در rollover ممکن است race داشته باشد؛ CancelOrphanContinuationPendings فیلتر symbol ندارد.
- `g_riskStep` و انتخاب Scale-in per-chart ماندند.

## فایل‌های تغییرکرده
RiskManager_EA_v101.mq4، RM_CooldownEngine، RM_Snapshot، RM_AutoActions، RM_TradeExecution، RM_Tools، RM_Reports.
بدون تغییر (byte-identical): RM_Common, Config, Dashboard, DrawdownEngine, RiskCalc, SessionTime, Trailing, ExecutiveHub_MT4 v1.16, MQL4_Files.

## تست T1–T9
T1 SL هم‌سمبل، T2 EarlyExit، T3 +1R/TP، T4 chain، T5 باز در یک چارت/بسته در دیگری، T6 tag، T7 چندسمبل (کارایی)، T8 restart، T9 رگرسیون — لاگ‌های `[RM-MI]` برای هر مورد خروجی مشخص دارند.

## اصلاح تکمیلی (BUG-055 اصلی: قفل account-wide)
- `GV_MKT_END` و `GV_BEH_END` از per-symbol به account-wide (`A<حساب>_M<مجیک>`) تغییر کرد؛ حالا ۴ استاپ روی هر نماد، قفل را روی همهٔ چارت‌ها/نمادها می‌نشاند (شمارنده‌ها از قبل account-wide بودند).
- `GV_LAST_ENTRY` (فاصلهٔ ورود) عمداً per-symbol ماند.
- کلیدهای قدیمی per-symbol بی‌اثر و بی‌خطرند (خودبه‌خود منقضی می‌شوند). قفلِ فعالِ لحظهٔ ارتقا از قبلی منتقل نمی‌شود.
- جایگزین بخش «کلید lock-end per-symbol» در محدودیت‌ها.

## اصلاح تکمیلی ۲ (حفاظت حساب روی همهٔ نمادها)
- `GetFloatingPLPercent()` و `EmergencyCloseAll()` (Floating DD Protection): فیلتر `Symbol()` حذف شد؛ مجموع شناور و بستن اضطراری روی همهٔ نمادهای همین Magic/حساب.
- بستن با قیمت خودِ نمادِ معامله (`MarketInfo(OrderSymbol())`) انجام می‌شود، نه Bid/Ask چارت جاری.
- اگر چند چارت هم‌زمان Emergency را اجرا کنند و معامله‌ای را نمونهٔ دیگر بسته باشد، آلارم «FAILED» کاذب نمی‌خورد.
- پرچم `EmergencyClosed` (برای برچسب CSV) همان لحظه روی GV ثبت می‌شود تا برندهٔ claim هر چارتی باشد درست برچسب بخورد؛ اگر بستن شکست خورد پاک می‌شود.
- دکمهٔ CLOSE ALL (`FullClose`) از قبل همهٔ نمادها را می‌بست و Close Chart فقط نماد چارت؛ بدون تغییر.
