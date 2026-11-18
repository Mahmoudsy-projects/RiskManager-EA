# EA MT5 v75.9 — ۱۵ ستون جدید CSV ژورنال (پورت MT4 v81 / v82 / v84 / v86)

NOT COMPILED — لطفاً کامپایل و تست کنید. Hub بدون تغییر (1.12).

## نتیجه‌ی بررسی «زنجیره‌ها»
در MT5 (حساب hedging) Half Close تیکت جدید نمی‌سازد؛ همان پوزیشن کوچک می‌شود و هر Deal خروجی یک ردیف CSV می‌دهد (همه با یک Ticket). پس زنجیره‌ی MT4 به‌صورت بومی با شناسه‌ی پوزیشن حل است و **RootTicket = Ticket**. آمار و Cooldown در MT5 از قبل «برایندِ کل پوزیشن» را می‌شمارند (مثل قانون زنجیره‌ی MT4).

## ستون‌های جدید (فقط در انتها؛ ۳۲ ستون قبلی بدون تغییر)
| ستون | منبع در MT5 |
|---|---|
| ContextLevelOK … ContextNone (۵ ستون) | فعلاً همیشه `false` (چک‌لیست Context در P5 پورت می‌شود؛ مثل MT4 برای مرحله‌ی انجام‌نشده) |
| SL_Final / TP_Final | `DEAL_SL` / `DEAL_TP` همان Deal خروجی (N/A اگر ۰) |
| Slippage_USD / Slippage_R | مثل MT4: فقط وقتی Result=SL/TP و Snapshot معتبر؛ مثبت = بدتر از سطح |
| CloseReason_Server | `[sl]` / `[tp]` از `DEAL_REASON`؛ بستن دستی/EA = خالی |
| Spread_AtClose | اسپرد لحظه‌ی تشخیص بسته‌شدن (GV `RM_SPREADCLOSE_A<acct>_M<magic>_<id>`)؛ فقط برای Deal نهاییِ پوزیشن، برای Half Close میانی N/A |
| ServerHour_Close | ساعت سرور از CloseTime |
| IsEAManaged | true اگر Snapshot معتبر دارد |
| RiskStepWeight | `1.000` (پله‌ی ریسک هنوز پورت نشده؛ بسته‌ی بعد) / N/A بدون Snapshot |
| RootTicket | = Ticket |

## تغییرهای رفتاری (مثل MT4)
- طبقه‌بندی Result: `hitTP` حالا از `DEAL_TP` خوانده می‌شود (قبلاً در MT5 همیشه false بود)، و سطح SL برای تشخیص «استاپ» = SL نهایی Deal (اگر ۰ بود SL اولیه‌ی Snapshot) – مثل MT4 BUG-052.
- ستون `SL` قبلی دست‌نخورده (SL اولیه‌ی Snapshot)؛ SL نهایی در `SL_Final` است.
- خواندن ردیف‌های قبلی (HF6) حالا تعداد ستون را از هدر فایل می‌خواند، پس فایل ۳۲ستونه‌ی قدیمی درست ارتقا می‌یابد (اولین Export هدر جدید را می‌نویسد).

## تست‌ها
- C1: فایل CSV قدیمی را نگه دارید؛ EA را اجرا کنید و یک معامله ببندید → هدر ۴۷ستونه و ردیف‌های قدیمی سالم (ستون‌های جدید برایشان N/A/خالی).
- C2: معامله‌ی SL‌خورده → Result=SL، CloseReason_Server=[sl]، Slippage معنی‌دار، SL_Final پر.
- C3: معامله با TP → Result=TP، CloseReason_Server=[tp]، TP_Final پر.
- C4: بستن دستی → CloseReason_Server خالی.
- C5: Half Close و بعد بستن نهایی → دو ردیف با یک Ticket و RootTicket یکسان؛ Spread_AtClose فقط روی ردیف آخر.
- C6: IsEAManaged: معامله‌ی باز‌شده با EA = true؛ معامله‌ی دستی با همان Magic = false.
- C7: ServerHour_Close با ساعت سرور بروکر بخواند.
- ⚠️ اگر DEAL_SL/DEAL_TP در بروکر شما ۰ برگردد، SL_Final/TP_Final = N/A می‌شود و فقط Result به SL اولیه تکیه می‌کند؛ لطفاً در C2/C3 گزارش بدهید.

نسخه: "75.90".
