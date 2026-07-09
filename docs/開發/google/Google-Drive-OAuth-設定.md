# Google Drive OAuth 設定

這份文件整理 Quill Diary Android 版 Google Drive 備份/還原所需的 OAuth 設定。內容以目前程式碼為準，重點是分清楚：

- `oauth_config.xml` 內放的是哪一種 client ID
- Google Cloud Console 需要建立哪些 OAuth client
- Android 端目前實際使用哪個 scope
- 常見錯誤訊息對應到哪些設定問題

## 目前實作摘要

Android 原生登入流程由 [`MainActivity.kt`](../../../android/app/src/main/kotlin/zack20136/com/quill_diary/MainActivity.kt) 負責，Google Drive 備份只要求：

- Google 帳號 email
- ID token
- Drive scope `https://www.googleapis.com/auth/drive.appdata`

這代表 App 只存取自己在 Google Drive `appDataFolder` 下的資料，不是整個雲端硬碟。

## 需要的設定項目

Google Cloud Console 需要至少準備：

1. 啟用 `Google Drive API`
2. 一組 `Android application` OAuth client
3. 一組 `Web application` OAuth client
4. 完成 OAuth consent screen

用途分工如下：

| 項目 | 用途 |
|------|------|
| Android OAuth client | 對應 Android App 的 `package name` 與 SHA-1 |
| Web OAuth client | 提供 Android Google Sign-In 要求的 `server client id` |

## `oauth_config.xml` 要放什麼

[`android/app/src/main/res/values/oauth_config.xml`](../../../android/app/src/main/res/values/oauth_config.xml) 目前使用：

- `oauth_request_id_token`

這個值必須是：

- `Web OAuth client ID`

不能放：

- Android OAuth client ID

程式碼與註解都已明確假設這裡是 Web client ID。

## Android 端 client ID 來源優先順序

`lib/infrastructure/drive/google_oauth_config.dart` 目前的 Android `serverClientId` 解析順序是：

1. `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`
2. Android `MethodChannel` `quill_diary/oauth_config` 回傳的 `oauth_config.xml`

也就是說：

- 平常可直接靠 `oauth_config.xml`
- 若要在特定建置流程覆寫，可用 `GOOGLE_SERVER_CLIENT_ID`

## 目前固定識別資訊

目前程式碼中的 Android 套件名稱是：

- `zack20136.com.quill_diary`

[`google_drive_oauth_errors.dart`](../../../lib/infrastructure/drive/google_drive_oauth_errors.dart) 內同步維護了目前要對照的 SHA-1：

| 類型 | SHA-1 |
|------|------|
| Debug | `B0:B3:BC:E7:7C:68:8E:67:84:B4:B8:BB:FF:E5:A8:AE:24:6F:53:BB` |
| Release / Upload keystore | `3D:40:C1:59:06:52:4E:C5:76:2D:29:51:30:92:77:7C:54:D5:42:1C` |

若 App 是從 Google Play 安裝，還要另外把：

- Play Console `App signing` 頁面的 SHA-1

也加進 Google Cloud Console 的 Android OAuth client，否則 release/Play 環境可能登入失敗。

## 設定流程

1. 在 Google Cloud Console 啟用 `Google Drive API`
2. 建立 Android OAuth client，`package name` 填 `zack20136.com.quill_diary`
3. 把 debug、upload keystore、Play App Signing 的 SHA-1 都補齊到 Android OAuth client
4. 建立 Web OAuth client
5. 把 Web OAuth client ID 寫入 `oauth_config.xml` 的 `oauth_request_id_token`
6. 完成 OAuth consent screen
7. 安裝 App，從設定頁執行「連線 Google Drive」
8. 確認登入完成後，App 能取得帳號與 Drive `appdata` 權限

## 如何判定「已連線」

Android 端目前不是只有看 Google 帳號是否登入，而是同時檢查：

- `GoogleSignIn.getLastSignedInAccount(...)`
- `GoogleSignIn.hasPermissions(account, Scope("https://www.googleapis.com/auth/drive.appdata"))`

兩者都成立，才會回報已連線。

## 常見錯誤與實際排查方向

### `access_denied`

通常代表使用者拒絕授權，或 consent screen / scope 設定仍未完成。

先檢查：

- consent screen 是否完成
- Drive API 是否已啟用
- 授權畫面是否真的有要求 Drive `appdata` 權限

### `No credential`

通常表示 Google Sign-In 設定本身就不成立。

先檢查：

- `oauth_config.xml` 是否填了 Web client ID
- Android OAuth client 的 `package name` 是否正確
- Android OAuth client 的 SHA-1 是否補齊

### `[10] Developer error`

這通常是 Android OAuth client 與 App 識別資訊不一致。

先檢查：

- `package name`
- SHA-1
- `oauth_request_id_token` 是否誤填 Android client ID

### `[12500] Sign in failed`

這類錯誤多半也是 OAuth 設定不完整或 scope/consent screen 問題。

優先回頭檢查：

- Drive API
- consent screen
- Android OAuth client
- Web OAuth client ID

### `[16] Account reauth failed`

常見於 release 或 Play 安裝版只補了 upload SHA-1，沒補 Play App Signing SHA-1。

### `canceled`

可能真的是使用者取消，但在 Android/Google Sign-In 上，也可能是底層 OAuth 設定錯誤後被包成取消。若反覆出現，仍要回查 SHA-1、package name、Web client ID 與 API 啟用狀態。

## 重新登入與重設會話

Android 原生流程支援 `resetSession`。當使用者要求重新連線時，程式會先：

1. `revokeAccess()`
2. `signOut()`
3. 重新發起登入

這可用來強制要求重新選帳號或重新同意權限。

## 變更前必查

只要碰到下列變更，就必須回頭更新這份文件與 GCP 設定：

- `package name` 變更
- keystore / SHA-1 變更
- `oauth_config.xml` 改名或欄位改動
- Google Drive scope 改動
- `MethodChannel` 名稱或 OAuth 載入流程改動
- Play App Signing 啟用或更換金鑰

## 參考實作

- [oauth_config.xml](../../../android/app/src/main/res/values/oauth_config.xml)
- [MainActivity.kt](../../../android/app/src/main/kotlin/zack20136/com/quill_diary/MainActivity.kt)
- [google_oauth_config.dart](../../../lib/infrastructure/drive/google_oauth_config.dart)
- [google_drive_oauth_errors.dart](../../../lib/infrastructure/drive/google_drive_oauth_errors.dart)

---

[返回開發文件索引](../README.md)
