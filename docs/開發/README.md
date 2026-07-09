# 開發文件導覽

這裡是 Quill Diary 的內部開發文件入口。`docs/開發/` 不會透過 GitHub Pages 發布，重點是幫開發者快速找到架構、資料保護模型與上架整備資訊。

## 先講結論

- `docs/開發/README.md` 是唯一的開發文件入口，Google 子題不再有額外總入口頁。
- 建議先讀架構，再讀安全與資料，最後依任務進到功能或 Google 文件。
- 若文件內容與實作不一致，以 `lib/`、`android/`、`lib/app/app_identifiers.dart` 與 `lib/l10n/*.arb` 為準。

## 先看哪幾份

1. [架構/系統架構.md](./架構/系統架構.md)
2. [架構/模組參考.md](./架構/模組參考.md)
3. 依主題再往下分流到安全、資料、功能或 Google 相關文件

## 依任務分流

- 想先理解整體結構：看 [架構/系統架構.md](./架構/系統架構.md)
- 想快速找 provider、service 或檔案責任：看 [架構/模組參考.md](./架構/模組參考.md)
- 想理解解鎖、可信裝置、timeout、resume：看 [安全/解鎖與會話.md](./安全/解鎖與會話.md)
- 想理解 LDJ2、recovery slot、索引金鑰衍生：看 [安全/加密格式.md](./安全/加密格式.md)
- 想理解搜尋索引何時開、何時重建：看 [資料/索引資料庫.md](./資料/索引資料庫.md)
- 想理解正式資料搬移、完整備份或可攜式匯出：看 [功能/備份與還原.md](./功能/備份與還原.md)
- 想理解草稿、附件、任務清單編輯：看 [功能/日記編輯器.md](./功能/日記編輯器.md)
- 想處理 Google Drive、Play 上架、Billing：
  看 [google/Android-權限與資料揭露.md](./google/Android-權限與資料揭露.md)、
  [google/Google-Drive-OAuth-設定.md](./google/Google-Drive-OAuth-設定.md)、
  [google/Google-Play-上架.md](./google/Google-Play-上架.md)、
  [google/Google-Play-Billing.md](./google/Google-Play-Billing.md)

## 主題分流

### 架構

| 文件 | 內容 |
|------|------|
| [架構/系統架構.md](./架構/系統架構.md) | 專案分層、主要模組、資料落點與高層邊界 |
| [架構/模組參考.md](./架構/模組參考.md) | 型別、Provider、核心服務與儲存子模組速查 |

### 安全

| 文件 | 內容 |
|------|------|
| [安全/解鎖與會話.md](./安全/解鎖與會話.md) | 啟動、鎖定、解鎖模式、timeout、resume 與 session 流程 |
| [安全/加密格式.md](./安全/加密格式.md) | LDJ2、兩層金鑰、recovery slot 與 manifest 驗證 |

### 資料

| 文件 | 內容 |
|------|------|
| [資料/索引資料庫.md](./資料/索引資料庫.md) | 搜尋索引的開啟、同步、重建與資料邊界 |

### 功能

| 文件 | 內容 |
|------|------|
| [功能/備份與還原.md](./功能/備份與還原.md) | 完整備份、本機 / 外部交付、可攜式匯入匯出、還原後處理 |
| [功能/日記編輯器.md](./功能/日記編輯器.md) | 編輯模式、草稿、附件、任務清單、預覽與正式儲存 |
| [功能/個人化設定.md](./功能/個人化設定.md) | 語言、主題、自動鎖定、圖片品質與排版偏好 |

### Google / 發布整備

| 文件 | 內容 |
|------|------|
| [google/Android-權限與資料揭露.md](./google/Android-權限與資料揭露.md) | Android 權限最小集、Data safety 與送審揭露對照 |
| [google/Google-Drive-OAuth-設定.md](./google/Google-Drive-OAuth-設定.md) | Google Sign-In、Drive API、OAuth client 與 SHA-1 設定 |
| [google/Google-Play-上架.md](./google/Google-Play-上架.md) | Play 帳號、封閉測試、AAB、公開頁面與送審整備 |
| [google/Google-Play-Billing.md](./google/Google-Play-Billing.md) | 「支持開發者」的 client-only Billing 策略與手動驗證 |

## 文件邊界

- `README.md` 只放 repo 首頁與高層入口，不承載細部規格
- `docs/` 根目錄只放公開頁面與對外穩定 URL 對應檔案
- `docs/開發/` 才是工程細節與維護筆記
- 若某份文件已經說明自己的責任邊界，其他文件應盡量用連結引用，不重複整段敘述

## 維護提醒

- 文件只描述目前程式碼已存在的行為，不把規劃當成已實作
- 若文件與程式碼不一致，以 `lib/`、`android/` 與 `lib/app/app_identifiers.dart` 為準
- App 內介紹、法律與設定文案來源集中於 `lib/l10n/*.arb` 與 `lib/presentation/settings/about_tab_catalog.dart`
- 公開法律頁面：[`docs/privacy-policy.md`](../privacy-policy.md)、[`docs/third-party-notices.md`](../third-party-notices.md)
