# MT5 v75.0 — فاز P0 «پایدارسازی» (روی پایه‌ی v74.6 پذیرفته‌شده)
⚠️ **کامپایل نشده.** اگر خطای کامپایل داد متنش را بفرست. هاب 1.08 دست‌نخورده (byte-identical).

## آیتم‌های P0
| # | وضعیت | فایل / تابع | مرجع MT4 |
|---|---|---|---|
| P0-1 آفست پایدار سرور | DONE | `RM_SessionTime.mq5` (جدید): `ST_ServerOffsetSec()`، `ST_NowUTC()`؛ ورودی `InpServerUtcOffsetMin` (180 پیش‌فرض، 99999 خودکار)؛ جایگزین ۳ مورد `TimeCurrent()-TimeGMT()` در `RM_Tools.mq5` و `GetNYCalendarDate`/`SessionLevel_GetNYDate`. اولویت: زنده/GV ← قانون ورودی (تابستانی، زمستان −60 دقیقه) ← 0. گارد توافق ۳ تیک. `IsUSDST_UTC` و `GetNYCalendarDate` حفظ شدند. | MT4 v107 `RM_SessionTime.mqh` |
| P0-2 حفظ مود داشبورد با تغییر تایم‌فریم | DONE | `LoadDashboardModeState` با `UninitializeReason()`: حفظ برای CHARTCHANGE/PARAMETERS/ACCOUNT، وگرنه TRADING | MT4 v104 |
| P0-3 لیست تیکت‌های امروز | DONE | `BuildTodayTicketList`: جدیدترین اول، یک ردیف برای هر پوزیشن، فقط بسته‌شده‌ها | MT4 BUG-056 |
| P0-4 گزارش‌ها | DONE | `CalcTradingReportStats`: پوزیشن باز (حتی نیمه‌بسته) شمرده نمی‌شود | MT4 `IsChainFullyClosed` |
| P0-5 تایمر کندل + PDO | DONE | تایمر همیشه روشن (`g_candleTimerOn=true`، دکمه و بلوک کلیک حذف؛ BE REF LINE عرض کامل ردیف، هیچ کنترل دیگری جابه‌جا نشد). خط **PDO** (`RM9LN_DOPEN`/`RM9LB_DOPEN`، شیفت ۱، خط‌چین، رنگ `GetContrastColor(C'230,230,235',C'90,90,95')`) در `UpdateDailyHL` + `RemoveDailyHL` | MT4 v79 / FEAT-032 |

انحراف‌ها از MT4 (گزارش): (الف) در MT5 مصرف‌کننده‌ی دوره‌ای آفست (News/Key Time) نیست، پس `ST_ServerOffsetSec()` از OnTimer هم صدا زده می‌شود. (ب) اصلاح اضافه: همان گارد `PositionSelectByTicket` در `CountUntaggedTodayCompute` (همان ریشه‌ی ردیف تکراری).

## آیتم‌های تازه (توافق‌شده در گفتگو)
1. **پرچم‌های ماندگار** `HalfExempt` و `TamperStriked` با GV (`RM_HALFEXEMPT_A<حساب>_M<مجیک>_<تیکت>`، `RM_TAMPERSTRIKED_A…`)، `GlobalVariablesFlush()` روی رویداد، برنده‌ی claim GV را پاک می‌کند و بازنده فقط حافظه‌ی محلی (`RemoveHalfExemptLocal`). ← رفع Strike اشتباه بعد از ری‌استارت EA (تیکت 124459854). پاکسازی GVهای قدیمی‌تر از ۳۰ روز در OnInit. (MT4 v101 BUG-054)
2. **Sync تگ** از OnTimer: `SyncTagsIfChanged()` (از قبل در MT5 بود، فقط هنگام جست‌وجو صدا زده می‌شد؛ حالا دوره‌ای هم) — یک GlobalVariableGet در هر ثانیه.
3. **لاگ دلیل OnDeinit**: `[RM-DEINIT] reason=… (متن)` + flush نهایی.
4. **بازیابی بسته‌شدن‌ها در OnInit** (`RM_ReconcileClosedAtInit`): تاریخچه‌ی ۴۸ ساعت اخیر؛ پوزیشن بسته‌شده‌ی همین نماد که Snapshot دارد و claim ندارد وارد صف طبقه‌بندی عادی می‌شود (`[RM-RECON]`). SL/TP از DEAL_SL/DEAL_TP دیل خروج. claim از دوباره‌شماری جلوگیری می‌کند. محدودیت: SL ردیابی‌شده‌ی لحظه‌ای نیست، آخرین SL ثبت‌شده در دیل خروج است.

## تست‌ها (XAUUSD، دمو)
T1–T11 مطابق متن تسک (جلسه‌ی عادی همان v74.5؛ آخر هفته/ری‌استارت ترمینال با بازار بسته: آفست ثابت؛ ورودی 99999 و 120؛ مود Utility + تغییر تایم‌فریم؛ تگ‌ویندو با نیمه‌بسته؛ گزارش‌ها؛ تایمر کندل؛ PDH/PDL/PDC/PDO؛ رگرسیون؛ ۱۰ دقیقه بیکار با ۳ چارت بدون `[RM-PERF]`).
| # | تست تازه | انتظار |
|---|---|---|
| N1 | Half Close بالای TP1، EA را Remove/Add کن، بعد بقیه را ببند | Strike رفتاری نمی‌خورد |
| N2 | همین تست با دو چارت هم‌نماد | فقط یک بار پردازش، بدون Strike |
| N3 | EA را remove کن، پوزیشن را ببند، EA را دوباره attach کن | `[RM-RECON]` و طبقه‌بندی/CSV درست |
| N4 | تگ را روی چارت A بزن | چارت B حداکثر ~۱ ثانیه بعد می‌بیند |
| N5 | EA را بردار/تایم‌فریم عوض کن | خط `[RM-DEINIT]` با دلیل درست |

## ریسک‌های مشاهده‌شده (دست نخورده)
فریز ۳۰ ثانیه‌ای OnTimer (candleTimer ≈12s + panelIntegrity ≈18s) هنوز بی‌علت قطعی؛ دیاگنوستیک `[RM-PERF]` نگه داشته شد. در هاب MT5 (`RM_Hub_Modules123.mq5` خطوط ~546/588/612) هنوز `TimeCurrent()-TimeGMT()` خام است (P2).
