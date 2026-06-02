# Google Drive OAuth 設定（Android）

Google Drive 備份功能在 Android 上依賴 Google Sign-In 與 Google Drive API 授權。

## 目標流程

正確設定完成後，使用者在 App 內應看到這條流程：

1. 按下 `連結 Google Drive`
2. 出現 Google 帳號選擇器
3. 選擇帳號
4. 出現 Google Drive 權限頁
5. 同意授權
6. App 顯示已連結帳號，例如 `姓名 (email)` 或 `email`

如果只出現帳號選擇器、沒有出現 Drive 權限頁，通常是 OAuth 設定不完整。

## 必要設定

同一個 Google Cloud 專案中需要完成：

- 啟用 `Google Drive API`
- 建立 `Android application` OAuth client
- 建立 `Web application` OAuth client
- 完成 OAuth consent screen 設定

## 專案內設定位置

| 位置 | 用途 |
| --- | --- |
| `android/app/src/main/res/values/oauth_config.xml` | 設定 Android 使用的 Web client id |
| `lib/config/oauth_config.dart` | 讀取 Android / iOS OAuth 設定 |
| `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` | 覆寫 Android 使用的 Web client id |

### `oauth_config.xml`

`oauth_request_id_token` 必須填入同一個 GCP 專案下的 **Web OAuth client ID**。

## Android 端需要對上的項目

Cloud Console 內的 Android OAuth client 必須與實際 APK / AAB 一致：

- package name
- SHA-1

最常見錯誤是：

- `oauth_request_id_token` 放錯成 Android client id
- Web client id 與 Android client 不在同一個 GCP 專案
- Cloud Console 的 SHA-1 跟實際簽章不一致

## App 內如何判定「連結成功」

設定頁現在會用兩個條件一起判定：

1. 是否有目前登入中的 Google 帳號
2. 該帳號是否已取得 Google Drive scope 授權

只有兩者都成立，才會顯示：

- 已連結 Google Drive
- 帳號資訊，例如 `姓名 (email)` 或 `email`
- 可進一步執行上傳／列出／下載備份

如果只有登入痕跡、沒有 Drive scope，UI 仍會視為「尚未連結」。

## 常見錯誤

### 選完帳號後沒有出現 Drive 權限頁

優先檢查：

- `oauth_config.xml` 是否填的是 Web OAuth client id
- Android OAuth client 的 package name 是否正確
- Android OAuth client 的 SHA-1 是否正確
- Google Drive API 是否已啟用

### `access_denied`

通常代表權限授權被拒絕，或 OAuth 設定不一致，導致 Drive scope 無法正常核發。

### `admin_policy_enforced`

代表帳號所屬的公司或學校組織政策禁止此 App 存取 Google Drive。請改用個人帳號，或由管理員放行。

### `No credential`

通常表示 Google Sign-In / OAuth 設定異常，優先檢查：

- Google Play 服務是否正常
- Web client id 是否正確
- Android OAuth client 與 SHA-1 是否正確

## 重新連結

如果之前授權過、現在需要改帳號或重走授權流程：

1. 在 App 內按 `重新連結 Google Drive`
2. 重新選擇帳號並完成授權

這個動作會重置目前的 Google Sign-In session，再重新建立新的 Drive 授權狀態。
