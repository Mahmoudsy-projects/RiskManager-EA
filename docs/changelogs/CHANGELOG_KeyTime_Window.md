# Key Time WINDOW mode

MT4 and MT5 now cycle through OFF → FULL → COMPACT → WINDOW → OFF. The button shows `KEY TIME W` while WINDOW is active, and the status shows `Key Time: ON (WINDOW)`.

WINDOW displays the most recent elapsed Key Time and the nearest upcoming Key Time, with their broker-time labels. It considers all 16 main and secondary lines using the existing market calendars and DST rules. If two lines occur at the same instant, the first line in the existing schedule takes precedence, with main lines listed first.

The existing one-second timer advances the window without waiting for a price tick. At a boundary, the reached line and label stay in place while the older pair is replaced. The mode is saved in the existing per-symbol GlobalVariables. OFF, FULL, COMPACT, and economic news retain their existing behavior.
