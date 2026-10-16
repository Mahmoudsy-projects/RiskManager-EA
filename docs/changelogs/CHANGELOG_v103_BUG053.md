# CHANGELOG v103 — BUG-053: استاپ محافظت‌شده (BE/Trailing) در Market Cooldown شمرده نشود

> ⚠️ **کامپایل نشده.** این نسخه در محیط بدون MetaEditor آماده شده؛ فقط بالانس `{}` `()` `[]` و diff با v102 بررسی شده. قبل از استفاده کامپایل و روی دمو تست کنید.

## مشکل
`hitSL` فقط قیمتی بود («در یا آن‌سوی SL فعلی») و سمت SL نسبت به ورود را نمی‌دید. معامله‌ای که SL آن به BE/سود منتقل شده و روی همان SL بسته می‌شد، به‌عنوان «استاپ» شمارنده‌ی Market را +1 می‌کرد (سه تا = قفل ۲ ساعته بدون هیچ ضرری).

## تغییر (فقط `RM_CooldownEngine.mqh` + شماره‌ی نسخه)
1. پرچم جدید: `slOnLossSide = isBuy ? (slPrice < openPrice) : (slPrice > openPrice)` — فقط مقایسه‌ی قیمت؛ SL دقیقاً روی ورود = سمت ضرر نیست. `slPrice` همان آخرین SL است (در `TrackOpenTrades` هر تیک همگام می‌شود). برای هر دو مسیر (Snapshot و fallback) مشترک است.
2. شاخه‌ی استاپ Market: `hitSL && !hitTP && slOnLossSide` (شامل پرچم `RM_CHAINDEFER_` — فقط برای استاپِ سمت ضرر ست می‌شود).
3. شاخه‌ی جدید قبل از `hitTP || reached1R`: `hitSL && !hitTP` (استاپ محافظت‌شده):
   - شمارنده‌ی Market، `g_lastStopCloseTime` و قفل: بدون هیچ تغییر.
   - Behavior: ریست به ۰ (با `[DEBUG-BEHCOUNT] Reset (SL-protected)`)؛ هرگز EarlyExit/Strike نمی‌شود.
   - `RemoveHalfExempt`, `SaveCooldownState`؛ صدا: سود ≥ ۰ → `SND_TARGET_REACHED`، وگرنه `SND_STOP_LOSS`.
   - `miOutcome = "Reset(SL-protected)"`.
   - لاگ: `[RM-MC] ticket=#n protectedStop sl= open= close= profit= mktCountUnchanged=`
4. `SnapRiskWeight` بدون تغییر (فقط روی استاپ‌های شمرده‌شده اعمال می‌شود).

## زنجیره (Chain)
`ProcessChainMarketStop` برای هر تیکت بسته‌شده صدا زده می‌شود و تصمیم را فقط با برایند زنجیره (`netR < -0.1R`) می‌گیرد، نه با `hitSL`؛ پس زنجیره‌ای که آخرین بخشش استاپ محافظت‌شده است و برایندش بهتر از -0.1R است، از قبل شمرده نمی‌شود. منطق زنجیره تغییر نکرد. اگر برایند زنجیره بدتر از -0.1R باشد (مثلاً بخش اول ضرر) همچنان درست شمرده می‌شود.

## ثبت CSV
ستون جدیدی اضافه نشد. در `RM_Reports.mqh` ستون Result با همان منطق قیمتی (`hitSL && !hitTP`) برای استاپ محافظت‌شده «SL» می‌نویسد (مثل قبل؛ تغییر داده نشد چون به شمارش Market ربطی ندارد).

## بدون تغییر
ریسک/لات، Behavior/Entry interval، Daily/Weekly/Monthly/Floating، Scale-in، تنظیمات مشترک، ستون‌های CSV (۴۷)، Hub v1.16، MQL4_Files، MT5.

## تست‌های پذیرش (T1–T10)
T1 SL سمت ضرر ← Market +1 | T2 BE دستی و بسته‌شدن روی SL ← Market ثابت، Behavior ریست، بدون EarlyExit، لاگ `[RM-MC]` | T3/T4 Trail به +0.5R (Buy/Sell) ← ثابت، بدون قفل، بدون Strike | T5 Auto BE ← `Reset(SL-protected)` در `[RM-MI]` | T6 دو استاپ ضرر، یک استاپ سودی، یک استاپ ضرر ← شمارنده ۱، ۲ (قفل در دومی)؛ استاپ سودی نه اضافه نه ریست | T7 TP ← `Reset(+1R/TP)` | T8 خروج زودهنگام ← EarlyExit مثل v102 | T9 Half Close + بخش آخر روی BE ← شمرده نشود | T10 دو چارت ← شمارنده هر دو ثابت، یک claim.
