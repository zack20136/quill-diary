# Quill Diary

離線優先的 Android 日記 App。日記、附件與索引都留在本機，以 `LDJ2` 加密格式與復原金鑰保護。

## 核心能力

- 加密日記與附件儲存
- 可信裝置解鎖
- 復原金鑰重建存取
- 編輯器本地加密草稿（手動儲存前不寫入日記庫）
- 首頁全文子字串搜尋
- 本機備份 / 還原（App 內與外部 `.jbackup`，自動保留最新 5 份）
- Google Drive 備份同步（雲端亦保留最新 5 份）

## 搜尋

- 首頁搜尋保證命中標題、標籤與完整內文的任意子字串
- 搜尋索引只在解鎖 session 期間開啟，鎖定後關閉
- 搜尋資料屬於衍生快取；新增、編輯、匯入會即時更新，還原或升級後可重建
- 詳細設計見 [docs/索引資料庫.md](docs/索引資料庫.md)

## 開發

```bash
flutter test
```

- 目前只支援 Android
- 測試分層於 `test/crypto`、`test/database`、`test/vault`、`test/session`、`test/storage`、`test/infrastructure`、`test/security`、`test/domain`、`test/features`、`test/codec`、`test/shared`；共用 fake 與 harness 在 `test/helpers/`
- 修改 session、可信裝置、復原金鑰或索引資料庫時，請同步更新 [docs](docs/文件目錄.md)

## 文件

詳細設計與流程說明請從 **[docs/文件目錄.md](docs/文件目錄.md)** 進入。
