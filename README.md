# Quill Diary

Quill Diary 是以 Android 為主要平台的離線加密日記 App。本 repo 提供原始碼、開發入口與公開文件來源。

## 專案定位

- 以復原金鑰為根的本機加密日記庫
- 可信裝置、裝置鎖與生物辨識解鎖
- 只在有效解鎖 session 期間可用的加密搜尋索引
- 加密人物名冊與可重建的姓名/別名查詢快取
- Markdown 編輯、任務清單、預覽與本機加密草稿
- 完整備份與還原，以及 Markdown/HTML 可攜式匯入匯出
- Google Drive `appDataFolder` 備份與還原；由使用者觸發，不是即時同步
- Google Play 一次性支持，不提供訂閱、會員或額外功能解鎖

目前產品僅支援 Android。`linux/`、`macos/`、`windows/` 與 `web/` 仍保留 Flutter 平台骨架，但不在目前支援範圍。

## 文件入口

- 開發文件導覽：[docs/開發/README.md](docs/開發/README.md)
- 架構總覽：[docs/開發/架構/系統架構.md](docs/開發/架構/系統架構.md)
- 模組速查：[docs/開發/架構/模組參考.md](docs/開發/架構/模組參考.md)
- Google/OAuth/上架整備：
  [Android 權限與資料揭露](docs/開發/google/Android-權限與資料揭露.md)、
  [Google Drive OAuth 設定](docs/開發/google/Google-Drive-OAuth-設定.md)、
  [Google Play 上架](docs/開發/google/Google-Play-上架.md)、
  [Google Play Billing](docs/開發/google/Google-Play-Billing.md)
- 公開首頁（GitHub Pages）：[docs/index.md](docs/index.md)
- 隱私權政策：[docs/privacy-policy.md](docs/privacy-policy.md)
- 第三方聲明：[docs/third-party-notices.md](docs/third-party-notices.md)

文件與程式碼不一致時，以 `lib/`、`android/`、`lib/app/app_identifiers.dart` 與 `lib/l10n/*.arb` 的實作為準。

## 開發注意事項

- UI 文案集中於 `lib/l10n/*.arb`
- 公開法律頁與 GitHub Pages URL 需維持穩定：
  - `https://zack20136.github.io/quill-diary/privacy-policy`
  - `https://zack20136.github.io/quill-diary/third-party-notices`

## 授權與品牌

- 原始碼以 [GNU Affero General Public License v3.0 or later](LICENSE)（AGPL-3.0-or-later）發布。若你修改並發布本程式，需依授權條款提供對應完整原始碼。
- **Quill Diary** 名稱、圖示與 Google Play 商店素材屬於作者品牌，不隨 AGPL 一併授權。
- App 內「支持開發者」屬自願性一次性支持，不提供功能解鎖。
- 若需閉源商用授權，請透過 [GitHub Issues](https://github.com/zack20136/quill-diary/issues) 聯絡作者。
