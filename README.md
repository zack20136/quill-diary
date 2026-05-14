# QuillLockDiary

一個以 Flutter 製作的離線加密日記 App。日記內容以 Markdown 儲存，資料會寫入本機 vault，並透過 `Recovery Key + 受信任裝置` 管理解鎖流程。

## 目前支援範圍

- 正式支援平台：Android
- 僅支援新格式資料：`LDJ2` 加密格式與 `Recovery Key v2+`
- Web 預覽模式已移除
- 非 Android 平台目前不提供模擬解鎖或資料操作

## 主要流程

1. 第一次啟動時建立 Recovery Key。
2. 建立後，當前裝置會註冊為受信任裝置。
3. 後續可透過受信任裝置直接開啟 session，或在需要時用 Recovery Key 重新解鎖。
4. 可建立本地備份、匯出 Markdown，並支援 Google Drive 備份還原。

## 注意事項

- 舊版 vault / recovery metadata 不提供相容或 migration。
- 若受信任裝置資料失效，請改用 Recovery Key 重新註冊裝置。
- `flutter analyze` 與 `flutter test` 目前不作為這個專案的主要驗證方式。
