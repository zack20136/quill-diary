# Google Drive OAuth 設定

這份文件整理 Quill Diary Android 版 Google Drive 備份/還原所需的 OAuth 設定。內容以目前程式碼為準，重點是分清楚：

- `oauth_config.xml` 內放的是哪一種 client ID
- Google Cloud Console 需要建立哪些 OAuth client
- Android 端目前實際使用哪個 scope
- 常見錯誤訊息對應到哪些設定問題

## 目前實作摘要

主要流程由 [`drive_backup_service.dart`](../../../lib/infrastructure/drive/drive_backup_service.dart) 透過 `google_sign_in` 7 執行：初始化、取得 Google 帳號，再由帳號的 `authorizationClient` 取得 Drive scope 授權。Android 互動式連線前，會先嘗試 [`MainActivity.kt`](../../../android/app/src/main/kotlin/zack20136/com/quill_diary/MainActivity.kt) 中保留的原生 Google Sign-In 後備流程；成功後仍回到 Dart 端取得 Drive API 授權。

Drive API 實際使用的授權範圍只有：

- `https://www.googleapis.com/auth/drive.appdata`

原生後備流程另會要求 email 與 ID token，但 ID token 沒有傳給 Drive API，也不是存取備份檔的憑證；Drive REST 請求使用的是 scope 授權所產生的存取權杖。

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

## 登入、授權與「已連線」的差異

Google 帳號驗證與 Drive API 授權是兩個步驟：

1. `GoogleSignIn.initialize(...)` 後取得或互動選擇帳號。
2. 對該帳號呼叫 `authorizationForScopes(...)`；若尚未授權，再呼叫 `authorizeScopes(...)`。

Android 設定頁的非互動式「已連線」快照目前由原生後備層判定，同時檢查：

- `GoogleSignIn.getLastSignedInAccount(...)`
- `GoogleSignIn.hasPermissions(account, Scope("https://www.googleapis.com/auth/drive.appdata"))`

兩者都成立才回報已連線；真正列出、上傳或下載 Drive 備份時，仍會由 Dart 端再次取得可用的 scope 授權。

`google_sign_in_android` 7 已改用 Android Credential Manager，但專案仍直接依賴 `play-services-auth`，保留上述 legacy Google Sign-In 後備與連線快照。Android 官方已將 legacy Google Sign-In 標為淘汰中；若移除這層，必須一起改寫 `MainActivity.kt`、連線狀態讀取、錯誤映射及相關測試。

## 常見錯誤與實際排查方向

### `access_denied`

可能代表使用者或組織政策拒絕授權，也可能是 consent screen／scope 設定未完成。不能只靠錯誤字串斷定單一原因。

先檢查：

- consent screen 是否完成
- Drive API 是否已啟用
- 授權畫面是否真的有要求 Drive `appdata` 權限

### `No credential`

表示 Credential Manager 沒有取得可用憑證；常見排查方向如下，但不能只靠這段訊息斷定是哪一項設定錯誤：

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

這是 legacy 原生後備流程的泛用登入失敗碼，也可能和裝置上的 Google Play services 或帳號狀態有關，不應直接等同 OAuth 設定錯誤。

優先回頭檢查：

- Drive API
- consent screen
- Android OAuth client
- Web OAuth client ID

### `[16] Account reauth failed`

代表既有帳號重新驗證失敗。若只發生在 Play 安裝版，可優先核對 Play App Signing SHA-1；也要檢查帳號狀態與裝置的 Google Play services。

### `canceled`

可能真的是使用者取消，但在 Android/Google Sign-In 上，也可能是底層 OAuth 設定錯誤後被包成取消。若反覆出現，仍要回查 SHA-1、package name、Web client ID 與 API 啟用狀態。

## 重新登入與重設會話

切換帳號時，Android 原生後備流程會依 `resetSession` 先：

1. `revokeAccess()`
2. `signOut()`
3. 重新發起登入

若沒有走成功，Dart 端會再以 `disconnect()`，失敗時退回 `signOut()`，清理 `google_sign_in` 會話後重新授權。這可用來強制重新選帳號或重新同意權限。

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
- [drive_backup_service.dart](../../../lib/infrastructure/drive/drive_backup_service.dart)
- [google_oauth_config.dart](../../../lib/infrastructure/drive/google_oauth_config.dart)
- [google_drive_oauth_errors.dart](../../../lib/infrastructure/drive/google_drive_oauth_errors.dart)

## 官方規範參考

- [Android：從 legacy Google Sign-In 遷移到 Credential Manager](https://developer.android.com/identity/sign-in/legacy-gsi-migration)
- [`google_sign_in` API：驗證與授權分離](https://pub.dev/documentation/google_sign_in/latest/)
- [`google_sign_in_android` 設定說明](https://pub.dev/packages/google_sign_in_android)
- [Google Drive `appDataFolder`](https://developers.google.com/workspace/drive/api/guides/appdata)

---

[返回開發文件索引](../README.md)
