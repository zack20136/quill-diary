# Google 文件

這裡整理 Quill Diary 與 Google 生態有關的文件，包括 Google Drive、OAuth、Google Play 上架、權限揭露與 Billing。

這一區不是產品核心主線，但如果你要把 Google 相關功能做完或送上 Play，應該從這裡開始。

## 文件分工

| 文件 | 內容 |
|------|------|
| [Google-Drive-OAuth-設定.md](./Google-Drive-OAuth-設定.md) | Google Sign-In、Drive API、OAuth client 與常見授權錯誤 |
| [Google-Play-上架.md](./Google-Play-上架.md) | Play 帳號、測試門檻、簽章、AAB、送審與資料揭露整備 |
| [Android-權限與資料揭露.md](./Android-權限與資料揭露.md) | Android 權限最小集、選圖與選檔流程、Data safety 對應 |
| [Google-Play-Billing.md](./Google-Play-Billing.md) | 支持頁 Billing（client-only）、商品 ID 與 Play Console 測試清單 |

## 該如何做

1. 先看 [Google-Drive-OAuth-設定.md](./Google-Drive-OAuth-設定.md)，把 Google Sign-In 與 Drive 授權打通
2. 再看 [Android-權限與資料揭露.md](./Android-權限與資料揭露.md)，確認權限與資料揭露沒有寫錯
3. 要準備上架時，看 [Google-Play-上架.md](./Google-Play-上架.md)
4. 支持功能與 Billing 測試，看 [Google-Play-Billing.md](./Google-Play-Billing.md)

## 目前定位

- Google Drive 備份屬於現有功能的一部分
- Google Play 上架屬於發佈整備
- Billing 已接入 app 端（client-only）；Play Console 商品與實機測試需手動完成

---

[← 返回文件目錄](../文件目錄.md)
