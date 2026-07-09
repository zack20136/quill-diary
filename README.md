# Quill Diary

Quill Diary 是以 Android 為主要目標平台的離線加密日記 App。這個 repo 主要提供開發入口、架構定位與文件索引，讓維護者能快速對照實作、資料保護邊界與公開頁面來源。

## 專案定位

- Flutter App，主要技術棧為 `flutter_riverpod`、`go_router`、`drift`、`sqlite3`
- 日記、附件、草稿與搜尋索引都圍繞同一套本機加密模型運作
- 支援可信裝置、生物辨識、復原金鑰與解鎖 session 管理
- 提供本機完整備份、Google Drive 加密備份、Markdown / HTML 匯入匯出
- 已接入 Google Play Billing 的一次性支持流程

目前產品範圍以 Android 為主。`linux/`、`macos/`、`windows/`、`web/` 目錄仍保留 Flutter 預設平台骨架，但不是目前主要支援目標；UI 文案也已明確標示「Quill Diary 目前僅支援 Android」。

## 專案結構

- `lib/app/`：App shell、router、theme、公開常數與整體入口
- `lib/presentation/`：頁面、widget 與畫面層互動
- `lib/application/`：session、editor、restore、settings 等流程協調
- `lib/infrastructure/`：加密、儲存、搜尋索引、Google Drive、Billing、偏好設定
- `lib/domain/`：穩定型別、value object 與跨模組共用模型
- `test/`：依功能與分層拆分的測試
- `docs/`：公開頁面與開發文件來源

## 核心能力

- 以復原金鑰為根的本機加密日記庫
- 可信裝置、裝置鎖、生物辨識三種解鎖模式
- 只在有效解鎖 session 期間可用的加密搜尋索引
- Markdown 編輯、任務清單混排、預覽與本地加密草稿
- 完整備份 / 還原，以及 Markdown / HTML 可攜式匯入匯出
- Google Drive `appDataFolder` 加密備份與還原，不是跨裝置即時同步
- Google Play 一次性支持功能，不提供訂閱、會員或額外功能解鎖

## 文件入口

- 開發文件導覽：[docs/開發/README.md](docs/開發/README.md)
- 架構總覽：[docs/開發/架構/系統架構.md](docs/開發/架構/系統架構.md)
- 模組速查：[docs/開發/架構/模組參考.md](docs/開發/架構/模組參考.md)
- Google / OAuth / 上架整備：
  [Android 權限與資料揭露](docs/開發/google/Android-權限與資料揭露.md)、
  [Google Drive OAuth 設定](docs/開發/google/Google-Drive-OAuth-設定.md)、
  [Google Play 上架](docs/開發/google/Google-Play-上架.md)、
  [Google Play Billing](docs/開發/google/Google-Play-Billing.md)
- 公開首頁（GitHub Pages）：[docs/index.md](docs/index.md)
- 隱私權政策：[docs/privacy-policy.md](docs/privacy-policy.md)
- 第三方聲明：[docs/third-party-notices.md](docs/third-party-notices.md)

閱讀順序建議：

1. 先看 [docs/開發/README.md](docs/開發/README.md)
2. 再看 [docs/開發/架構/系統架構.md](docs/開發/架構/系統架構.md)
3. 需要速查責任邊界時，看 [docs/開發/架構/模組參考.md](docs/開發/架構/模組參考.md)

文件與程式碼不一致時，以 `lib/` 內實作、`android/` 設定、`lib/app/app_identifiers.dart` 常數與 `lib/l10n/*.arb` 文案來源為準。

## 開發注意事項

- 本專案在 Codex / Windows 環境禁止直接執行 `flutter ...`，請改用 `powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 <args>`
- UI 文案集中於 `lib/l10n/*.arb`
- 公開法律頁與 GitHub Pages URL 需維持穩定：
  - `https://zack20136.github.io/quill-diary/privacy-policy`
  - `https://zack20136.github.io/quill-diary/third-party-notices`
- Google Drive 備份、OAuth、Billing、權限與上架文件調整時，請同步檢查 `docs/開發/google/`、`docs/index.md`、`lib/app/app_identifiers.dart` 與 Android 實作

## 授權與品牌

- 原始碼以 [GNU Affero General Public License v3.0](LICENSE)（AGPL-3.0）發布。若你修改並發布本程式，需公開對應完整原始碼。
- **Quill Diary** 名稱、圖示與 Google Play 商店素材屬於作者品牌，不隨 AGPL 一併授權。
- App 內「支持開發者」屬自願性一次性支持，不提供功能解鎖。
- 若需閉源商用授權，請透過 [GitHub Issues](https://github.com/zack20136/quill-diary/issues) 聯絡作者。
