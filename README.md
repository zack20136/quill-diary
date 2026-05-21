# QuillLockDiary

離線優先的 Android 日記 App。日記、附件與索引都留在本機，以 `LDJ2` 加密格式與復原金鑰保護。

## 核心能力

- 加密日記與附件儲存
- 本機受信任裝置解鎖
- 復原金鑰重建存取
- 本機備份／還原
- Google Drive 備份同步

## 開發

```bash
flutter test
```

- 目前只支援 Android
- 測試分層於 `test/crypto`、`test/database`、`test/vault`、`test/session`、`test/storage`、`test/infrastructure`、`test/security`、`test/domain`、`test/features`、`test/codec`、`test/shared`；共用 fake 與 harness 在 `test/helpers/`
- 修改 session、本機受信任裝置、復原金鑰或索引資料庫時，請同步更新 [docs](docs/文件目錄.md)

## 文件

詳細設計與流程說明請從 **[docs/文件目錄.md](docs/文件目錄.md)** 進入。
