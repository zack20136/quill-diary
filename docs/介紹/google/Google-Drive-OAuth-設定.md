# Google Drive OAuth 設定

這份文件整理 Android 版 Google Drive 備份所需的 Google Sign-In 與 OAuth 設定。

目標很單純：讓使用者可以在 App 內正確連結 Google 帳號，取得 Google Drive 授權，並正常使用雲端備份。

## 你要完成什麼

正確設定完成後，使用者在 App 內應該看到這條流程：

1. 按下 `連結 Google Drive`
2. 跳出 Google 帳號選擇器
3. 選擇帳號
4. 跳出 Google Drive 權限頁
5. 同意授權
6. App 顯示已連結帳號，例如 `姓名 (email)` 或 `email`

如果只有選帳號、沒有出現 Drive 權限頁，通常就是 OAuth 設定不完整。

## 必要設定

同一個 Google Cloud 專案中，至少要完成以下幾項：

- 啟用 `Google Drive API`
- 建立 `Android application` OAuth client
- 建立 `Web application` OAuth client
- 完成 OAuth consent screen 設定

## 專案內設定位置

| 位置 | 用途 |
|------|------|
| `android/app/src/main/res/values/oauth_config.xml` | 提供 Android 使用的 Web client id |
| `lib/infrastructure/drive/google_oauth_config.dart` | 讀取 Android / iOS OAuth 設定 |
| `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` | 覆寫 Android 使用的 Web client id |

`oauth_request_id_token` 必須填同一個 GCP 專案下的 **Web OAuth client ID**，不是 Android client id。

## Android 端要對上的資料

Cloud Console 內的 Android OAuth client 必須和實際安裝包一致。

- package name：`zack20136.com.quill_diary`
- SHA-1：依安裝方式登記對應指紋

| 安裝方式 | SHA-1 |
|------|------|
| debug（本機開發） | `B0:B3:BC:E7:7C:68:8E:67:84:B4:B8:BB:FF:E5:A8:AE:24:6F:53:BB` |
| release / upload keystore | `3D:40:C1:59:06:52:4E:C5:76:2D:29:51:30:92:77:7C:54:D5:42:1C` |
| Google Play 安裝版 | 以 Play Console 的 App signing SHA-1 為準 |

## 該如何做

1. 在同一個 Google Cloud 專案啟用 `Google Drive API`
2. 建立 Android OAuth client，填入正確的 package name 與 SHA-1
3. 建立 Web OAuth client
4. 把 Web OAuth client id 填進 `oauth_config.xml`
5. 完成 OAuth consent screen 設定
6. 在裝置上重新走一次 `連結 Google Drive`
7. 確認流程中真的有出現 Drive 權限頁

本機查 SHA-1 可用：

```bash
cd android
./gradlew :app:signingReport
```

## App 內如何判定已連結

設定頁會同時檢查兩件事：

1. 目前是否有登入中的 Google 帳號
2. 這個帳號是否已取得 Google Drive scope

只有兩者都成立，UI 才會視為已連結。

## 常見錯誤

### 選完帳號後沒有出現 Drive 權限頁

優先檢查：

- `oauth_config.xml` 是否填成 Web client id
- Android OAuth client 的 package name 是否正確
- Android OAuth client 的 SHA-1 是否正確
- Google Drive API 是否已啟用

### `access_denied`

通常代表權限被拒絕，或 OAuth 設定不一致，導致 Drive scope 無法正常核發。

### `admin_policy_enforced`

代表帳號所屬組織政策禁止此 App 存取 Google Drive。改用個人帳號，或由管理員放行。

### `No credential`

通常代表 Google Sign-In / OAuth 設定異常，優先檢查：

- Google Play 服務是否正常
- Web client id 是否正確
- Android OAuth client 與 SHA-1 是否正確

### `[16] Account reauth failed`

常見於 release 或 Play 安裝版，優先檢查：

- GCP 是否已登記正確的 release 或 Play App signing SHA-1
- App 內重新連結是否有重跑授權流程

`google_sign_in` 在 Android 上有時會把 OAuth 設定錯誤誤報成 `canceled`，不要只看字面判斷成使用者取消。

## 重新連結

如果之前授權過，現在需要改帳號或重走授權流程：

1. 在 App 內按 `重新連結 Google Drive`
2. 重新選帳號
3. 重新完成授權

---

[← 返回 Google 文件](./README.md)
