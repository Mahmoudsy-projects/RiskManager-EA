//+------------------------------------------------------------------+
//|                                           RM_DashboardExport.mqh |
//|  v109: داشبورد معاملات (HTML) بدون DLL                              |
//|   - RM_EnsureDashboardFiles(): در OnInit، اگر RM_Dashboard.html در MQL5\Files نبود یا نسخه‌اش |
//|     قدیمی بود، از متن Base64 داخل EA (RM_DashboardHtml.mqh) می‌نویسد.                      |
//|   - RM_WriteDashboardData(): بعد از هر Export CSV، همان CSV را به RM_Dashboard_Data.js تبدیل |
//|     می‌کند (کنار HTML)؛ HTML با <script src> آن را می‌خواند - بدون drag&drop.              |
//|  فقط داخل MQL5\Files می‌نویسد و هیچ برنامه‌ای اجرا نمی‌کند.                                  |
//+------------------------------------------------------------------+
#include "RM_DashboardHtml.mq5"
#define RM_DASH_HTML_NAME "RM_Dashboard.html"
#define RM_DASH_DATA_NAME "RM_Dashboard_Data.js"

int RM_B64Val(int c)
{
   if(c>='A' && c<='Z') return c-'A';
   if(c>='a' && c<='z') return c-'a'+26;
   if(c>='0' && c<='9') return c-'0'+52;
   if(c=='+') return 62;
   if(c=='/') return 63;
   return -1;
}

// دیکد Base64 همه‌ی تکه‌ها به آرایه‌ی بایت (UTF-8 خام)
int RM_DashDecodeHtml(uchar &out[])
{
   int cap = 0;
   for(int k=0; k<RM_DASH_B64_COUNT; k++) cap += StringLen(g_rmDashB64[k]);
   ArrayResize(out, cap/4*3 + 4);
   int n = 0, acc = 0, bits = 0;
   for(int k=0; k<RM_DASH_B64_COUNT; k++)
   {
      string s = g_rmDashB64[k];
      int len = StringLen(s);
      for(int i=0; i<len; i++)
      {
         int c = StringGetCharacter(s, i);
         if(c == '=') break;
         int v = RM_B64Val(c);
         if(v < 0) continue;
         acc = (acc << 6) | v;
         bits += 6;
         if(bits >= 8)
         {
            bits -= 8;
            out[n] = (uchar)((acc >> bits) & 0xFF);
            n++;
            acc = acc & ((1 << bits) - 1);
         }
      }
   }
   return n;
}

bool RM_DashHtmlIsCurrent()
{
   if(!FileIsExist(RM_DASH_HTML_NAME)) return false;
   int h = FileOpen(RM_DASH_HTML_NAME, FILE_READ|FILE_BIN);
   if(h == INVALID_HANDLE) return false;
   uchar head[];
   ArrayResize(head, 40);
   int got = (int)FileReadArray(h, head, 0, 40);
   FileClose(h);
   if(got <= 0) return false;
   string s = CharArrayToString(head, 0, got, CP_ACP);
   return (StringFind(s, RM_DASH_VERSION_MARK) >= 0);
}

string RM_DashPath(string name)
{
   return TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + name;
}

void RM_WriteDashboardData(string csvName)
{
   int hin = FileOpen(csvName, FILE_READ|FILE_TXT|FILE_ANSI);
   if(hin == INVALID_HANDLE) return;
   int hout = FileOpen(RM_DASH_DATA_NAME, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(hout == INVALID_HANDLE) { FileClose(hin); return; }
   FileWriteString(hout, "window.RM_DASH_META={account:\"" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\",generated:\"" +
                         TimeToString(TimeLocal(), TIME_DATE|TIME_MINUTES) + "\"};\r\nwindow.RM_CSV_LINES=[\r\n");
   while(!FileIsEnding(hin))
   {
      string line = FileReadString(hin);
      if(StringLen(line) == 0) continue;
      StringReplace(line, "\\", "\\\\");
      StringReplace(line, "\"", "\\\"");
      FileWriteString(hout, "\"" + line + "\",\r\n");
   }
   FileWriteString(hout, "\"\"];\r\n");
   FileClose(hin);
   FileClose(hout);
}

void RM_EnsureDashboardFiles()
{
   if(!RM_DashHtmlIsCurrent())
   {
      uchar bytes[];
      int n = RM_DashDecodeHtml(bytes);
      int h = FileOpen(RM_DASH_HTML_NAME, FILE_WRITE|FILE_BIN);
      if(h != INVALID_HANDLE)
      {
         FileWriteArray(h, bytes, 0, n);
         FileClose(h);
         Print("[RM-DASH] Dashboard written: ", RM_DashPath(RM_DASH_HTML_NAME));
      }
      else Print("[RM-DASH] Could not write ", RM_DASH_HTML_NAME, ", error ", GetLastError());
   }
   string csvName = "RM_TradeJournal_" + IntegerToString(MagicNumber) + ".csv";
   if(!FileIsExist(RM_DASH_DATA_NAME) && FileIsExist(csvName)) RM_WriteDashboardData(csvName);
   Print("[RM-DASH] Open in Chrome: ", RM_DashPath(RM_DASH_HTML_NAME));
}
