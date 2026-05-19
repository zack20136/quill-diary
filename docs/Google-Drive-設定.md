# Google Drive 設定

Google Drive 備份功能所需的 Android OAuth 設定。

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

## 相關檔案

| 檔案 | 用途 |
|------|------|
| `lib/config/oauth_config.dart` | OAuth 讀取邏輯與優先順序 |
| `android/app/src/main/res/values/oauth_config.xml` | `oauth_request_id_token`（Web client id） |
| `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` | 覆寫 Web client id |

## 驗證重點

- Google Sign-In 能正常登入
- 可列出 Drive 備份
- 可上傳新備份
- 可下載並還原既有備份
