# گزارش FEAT-052 — Executive Hub v1.17 (Themes)

⚠️ کامپایل نشده؛ فقط بالانس و diff.

## ۱. Diff و بالانس
- Hub 1.16 → 1.17: ۵۱ hunk، ~۵۰۰ خط اضافه، ۴۲ خط تغییریافته (فقط خواندن رنگ چارت، پوشاندن رنگ ثابت با کنتراست، چیدمان ۴ دکمه‌ی مادر).
- بالانس (با حذف رشته/کامنت): v1.16: `()`2488 `[]`190 `{}`387 — v1.17: `()`2944 `[]`256 `{}`448 — همه متعادل، بدون mismatch.
- md5: ۴۸ فایل دیگر (EA، MQL4_Files، RM_SessionTime، changelogها) دقیقاً یکسان؛ فقط فایل Hub فرق دارد.

## ۲. دکمه‌ی چهارم و Original
- توابع تغییرکرده: `CreateButtons`، `PositionButtons` (شروع grid روی `3→4` دکمه، `measureBtnWidth=4m+3gap`)، `ComputeContentWidth` (`masterRowWidth=4m+3gap` + شاخه‌ی Theme)، `UpdateHubBackground` (ارتفاع ردیف کشو)، `RecomputeEffectiveSizes/UsableChartWidth` (بدون تغییر منطق؛ ۴ دکمه حساب می‌شوند)، `RaiseHubPanelToFront`، `OnInit/OnDeinit`، `CheckHubIntegrity`، زنجیره‌ی auto-minimize در `OnTimer`، `OnChartEvent` (سه هندلر مادر قبلی Theme را هم می‌بندند + هندلر جدید). جدید: `Theme_*`, `ApplyThemeMinimizedState`.
- Original: آبجکت مخفی `PFX+"ThemeOrig"` (OBJ_LABEL، hidden، OBJ_NO_PERIODS، خارج از صفحه، base64 ۵۱ کاراکتر). در `OnDeinit` پاک نمی‌شود؛ با برداشتن Hub می‌ماند (تصمیم پیش‌فرض)، با تغییر تایم‌فریم/ری‌لود/ریستارت هم. `IsHubPanelOwnedObject` آن را «متعلق به Hub» می‌شناسد اما raise پنل آن را حذف نمی‌کند.

## ۳. هوک بازرنگ و فهرست آبجکت‌ها
- هوک: `Theme_RecolourOnce()` ← `EMA_ApplyGrayscaleColors`, `WMAP_DrawAll`, `POC_RecolourLevels`, `SOB_Recalculate`, `NYE_Recalculate`, `MTFCP_DrawAll` (+countdown)، همه فقط یک‌بار در کلیک؛ بدون تایمر/لوپ جدید.
- **رنگ ثابت که کنتراست خودکار گرفت** (`Theme_ContrastSafe`): ابزارهای Draw (Line/HRay/Dash/Path/Label و پیش‌نمایش‌ها)، Measure (`MeasLine/BufTop/BufBottom`)، `ModeColor`، Weekly Map (`WMAP_GetContrastColor`)، EMA (کل `PlotIndexSetInteger`ها)، POC (خطوط، لیبل‌ها، track line/label)، SOB، NYE، رنگ‌های MTFCP (ورودی ثابت).
- **از قبل خودکار (بدون تغییر منطق، فقط با override تازه خوانده می‌شوند)**: `ComputeContrastGray`، MTFCP Bull/Bear/Label با ورودی `clrNONE`، رنگ‌های خنثی/خاکستری EMA.
- شبیه‌سازی: تم‌های ۲،۳،۴،۶،۷ تقریباً بدون جابه‌جایی؛ تم ۱ (bg 169) و ۵ (bg 192) چند رنگ را جابه‌جا می‌کنند (WMAP inner، EMA10/20، POC LVN، SOB زرد، Draw: silver/turquoise/lightpink/gray).
- **استثنا**: دکمه‌ی تم ۶ مطابق تسک حاشیه ندارد چون Bull آن (211) روی پنل تیره دیده می‌شود؛ فقط تم ۳ حاشیه‌ی روشن می‌گیرد (قانون روشنایی به‌جای فهرست ثابت ۳ و ۶).

## ۴. فهرست فقط‌خواندنی EA (ورودی FEAT-052b)
- `RM_TradeExecution.mqh`: خطوط Entry/SL/TP و لیبل‌های `*_LBL` با `clrWhite` (خطوط ~۸۳–۱۷۰) — روی تم‌های روشن ۱ و ۵ ناخوانا؛ رنگ خود خطوط Entry/SL/TP ثابت.
- BE و basket (aqua)، خطوط trail (teal) و auto-high `C'210,175,20'` — ثابت.
- `RiskManager_EA_v105.mq4`: خطوط preview و لیبل `clrWhite` (~خط ۳۳۳۶) — ثابت.
- `RM_Tools.mqh`: فلش‌های ورود/خروج و خط اتصال؛ `C'130,130,140'` (~خط ۱۶۹۱) — ثابت.
- `RM_News.mqh`: رنگ‌های ثابت High (قرمز) / Medium (نارنجی) برای خبر.
- خودکار از قبل: Key Time (`GetKeyTimeLineColor`)، `GetContrastColor`، `ResolveFiboLineColor`.
(فهرست از خواندن کد؛ شماره‌خط‌ها تقریبی.)

## ۵. ریسک‌ها (بدون رفع)
1. کامپایل‌نشده — خطای نحوی/نوع در MetaEditor ممکن است.
2. هندلر `CHARTEVENT_OBJECT_CHANGE` رنگ ویرایش‌شده‌ی آبجکت را در رنگ پیش‌فرض ماندگار می‌نویسد؛ با رنگ‌گذاری کنتراست ممکن است رنگ «شیفت‌خورده» به‌جای رنگ اصلی ذخیره شود (drift).
3. اگر کاربر قبل از اولین تم دستی چارت را رنگ کرده، همان Original است (طبق طراحی)؛ اگر Original خراب شد با تم بعدی دوباره از رنگ فعلی (ممکن است تم‌شده) ساخته می‌شود.
4. `ChartSetInteger` ناهمگام: از override موقت استفاده شد؛ رنگ‌های Hub که خارج از این مسیر چارت را بخوانند تا چند ms قدیمی‌اند.
5. `SOB_Recalculate` (و شاید NYE) خودش `ChartRedraw` می‌زند → در کلیک ممکن است بیش از یکی باشد (رفتار قبلی آن توابع).
6. RANGE و SP2L/BTB برای جلوگیری از فضای خالی پهن‌تر شدند (تغییر جزئی چیدمان).
7. با ۴ دکمه‌ی مادر عرض حداقلی پنل بیشتر شد؛ در چارت‌های خیلی باریک shrink فعال می‌شود.
8. آبجکت Original با Hub باقی می‌ماند (در Objects List با Show hidden دیده می‌شود).
9. تشخیص تم فعال (`Theme_DetectActive`) فقط در OnInit و فقط با ۴ رنگ؛ تغییر دستی رنگ دیگر تم را «فعال» نشان نمی‌دهد/می‌دهد.

## ۶. بسته و changelog
- `RiskManager_Workstation_v105_Hub1.17.zip` — فایل Hub: `ExecutiveHub_MT4/ExecutiveHub_v1.17.mq4`
- `CHANGELOG_Hub_v1.17_FEAT052_Themes.md` (ریشه‌ی بسته)
