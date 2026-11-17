# CHANGELOG Hub 1.20 — SOB_CurrentDayOnly فقط یک باکس

> ⚠️ **کامپایل نشده؛ تست با Mahmoud.** فقط حلقه‌ی `SOB_ProcessSession` و نوع برگشتیِ `SOB_ProcessOneDay` (`void` → `bool`) عوض شده.

`ExecutiveHub_v1.19.mq4` → `ExecutiveHub_v1.20.mq4` (version "1.20"). `RM_SessionTime.mqh` و EA دست‌نخورده‌اند.

## مشکل
با `SOB_CurrentDayOnly=true` هم باکسِ امروز و هم باکسِ روز قبل نشان داده می‌شد. علت: در 1.19 حلقه از d=-1 شروع می‌شد و `days=2` (یعنی ۳ دور: -1، 0، 1) هر باکسِ شروع‌شده را رسم می‌کرد.

## رفع
`SOB_ProcessOneDay` حالا `true` برمی‌گرداند اگر باکس واقعاً رسم شد. وقتی `SOB_CurrentDayOnly=true` است، حلقه بعد از اولین باکسِ رسم‌شده برای هر سشن متوقف می‌شود: یعنی «آخرین باکسِ شروع‌شده» (امروز؛ اگر امروز هنوز شروع نشده، آخرین روزِ دارای دیتا). با `SOB_CurrentDayOnly=false` رفتار همان قبل است (`SOB_ShowLastXDays` روز).
