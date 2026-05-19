# Google Drive OAuth 設定

## 用途

Google Drive 備份功能需要 Android 端可用的 OAuth 設定。

## 必要項目

- Android application OAuth client
- Web application OAuth client

## 專案中的使用方式

- Android 原生層會從資源檔提供 `serverClientId`
- Flutter 端初始化 Google Sign-In 時會讀取這個值

## 建議設定步驟

1. 在 Google Cloud Console 建立專案
2. 啟用 Google Drive API
3. 建立 Android OAuth client
4. 建立 Web OAuth client
5. 將 Web client id 提供給 app 使用

## 專案檔案

- `lib/config/oauth_config.dart`
  - 定義 OAuth 讀取邏輯與優先順序
- Android 資源設定
  - 供原生層讀取 `serverClientId`

## 驗證重點

- Google Sign-In 能正常登入
- 可列出 Drive 備份
- 可上傳新備份
- 可下載並還原既有備份
