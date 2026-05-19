# QuillLockDiary

離線優先的 Android 日記 App。

專案核心目標是把日記內容、附件與索引資料都留在本機，並用自訂的 `LDJ2` 加密格式與 `Recovery Key` 保護資料。應用程式同時支援：

- 加密日記與附件儲存
- 受信任裝置解鎖
- Recovery Key 重建存取
- 本機備份 / 還原
- Google Drive 備份同步

## 目前架構

專案採用 `feature-first + 薄分層`：

- `lib/features/`
  - 功能主入口，包含頁面、provider、state 與 feature-specific UI。
- `lib/domain/`
  - 穩定資料模型與 value object。
- `lib/infrastructure/`
  - 加密、儲存、索引、裝置安全、Google Drive 等外部邊界實作。
- `lib/shared/`
  - 共用 provider、樣式、widget、工具函式。
- `lib/app/`
  - App shell，例如 router、theme、root widget。

## 主要資料流

1. 使用者建立或輸入 `Recovery Key`
2. App 導出 recovery wrapping key
3. Vault 內容以 `LDJ2` 格式加密，並透過 trusted device slot / recovery slot 保存可解鎖資訊
4. 受信任裝置可直接還原 session；失效時改由 `Recovery Key` 重建
5. SQLite index 只在解鎖 session 期間開啟

## 重要限制

- 目前只支援 Android
- trusted device 採破壞性策略：舊版不相容資料會要求重新輸入 `Recovery Key`
- 測試與驗證以靜態檢查、單元測試與手動流程驗證為主

## 目錄與文件

- [docs/文件索引.md](docs/文件索引.md)：文件入口
- [docs/產品與架構總覽.md](docs/產品與架構總覽.md)：整體設計與目錄說明
- [docs/加密流程.md](docs/加密流程.md)：LDJ2 寫入與包裝流程
- [docs/解密流程.md](docs/解密流程.md)：trusted device / Recovery Key 解鎖流程
- [docs/其他主要流程.md](docs/其他主要流程.md)：session、備份、還原、索引等流程
- [docs/實作與資料設計.md](docs/實作與資料設計.md)：主要型別與模組責任
- [docs/google_drive_oauth_setup.md](docs/google_drive_oauth_setup.md)：Google Drive OAuth 設定

## 開發注意事項

- 這個 repo 目前以 Android 實機流程、檔案結構與加密資料一致性為主要驗證基準。
- 若要修改 session、trusted device、Recovery Key、index database，請先同步更新對應文件。
- 若 trusted state 與現在版本不相容，預期行為是清除受信任裝置資訊並要求重新輸入 `Recovery Key`。
