# Google Drive OAuth 設定（Android）

Google Drive 備份功能所需的 Android OAuth 設定。

> 正式版本目前以 Android 為主。iOS 若未提供 `GOOGLE_IOS_CLIENT_ID` 與 `GOOGLE_IOS_REVERSED_CLIENT_ID`，設定頁的 Google Drive 區塊會顯示「尚未設定」並停用按鈕。

## 必要項目

- Android application OAuth client
- Web application OAuth client

## 設定步驟

1. 在 [Google Cloud Console](https://console.cloud.google.com/) 建立專案
2. 啟用 Google Drive API
3. 建立 Android OAuth client（套件名稱 + SHA-1）
4. 建立 Web OAuth client
5. 將 Web client id 提供給 app 使用

## 專案中的使用方式

- Android 原生層從資源檔提供 `serverClientId`
- Flutter 端初始化 Google Sign-In 時讀取此值
- iOS 需以 `--dart-define=GOOGLE_IOS_CLIENT_ID=...` 與 Xcode 的 `GOOGLE_IOS_REVERSED_CLIENT_ID` 設定；未設定時 UI 預先停用 Drive 入口

## 相關檔案

| 檔案 | 用途 |
|------|------|
| `lib/config/oauth_config.dart` | OAuth 讀取邏輯與 iOS 是否已設定 |
| `android/app/src/main/res/values/oauth_config.xml` | `oauth_request_id_token`（Web client id） |
| `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` | 覆寫 Web client id |
| `--dart-define=GOOGLE_IOS_CLIENT_ID=...` | iOS OAuth client id |
| `ios/Runner/Info.plist` | `GIDClientID` / URL scheme 占位 |

## 驗證重點

- Google Sign-In 能正常登入
- 可列出 Drive 備份
- 可上傳新備份
- 可下載並還原既有備份

## 相關文件

- [備份與還原.md](./備份與還原.md) — Drive 備份與還原流程

---

[← 返回文件目錄](./文件目錄.md)
