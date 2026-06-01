# Google Drive OAuth 設定（Android）

Google Drive 備份功能在 Android 上依賴 Google Sign-In 與 Google Drive API 授權。
若設定正確，流程應該是：

1. App 叫出 Google 帳號選擇器
2. 使用者選擇帳號
3. Google 顯示 Drive 權限頁
4. 使用者按允許
5. App 成功進入 Google Drive 備份流程

如果流程卡在不同位置，代表問題來源不同。

## 必備設定

需要在同一個 Google Cloud 專案中建立並確認：

- Android application OAuth client
- Web application OAuth client
- 已啟用 Google Drive API
- OAuth consent screen 已完成可用狀態

## 專案對應位置

| 位置 | 用途 |
|------|------|
| `android/app/src/main/res/values/oauth_config.xml` | `oauth_request_id_token`，必須填入 Web OAuth client id |
| `lib/config/oauth_config.dart` | Android / iOS 讀取 Google OAuth 設定 |
| `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` | 可覆寫 Android 使用的 Web client id |
| `ios/Runner/Info.plist` | iOS 的 `GIDClientID` / URL scheme |

## Android 端重點

- `oauth_request_id_token` 必須是同一個 GCP 專案下的 **Web application client ID**
- Cloud Console 中必須另外建立 **Android OAuth client**
- Android OAuth client 的：
  - 套件名稱必須對應目前 app 的 `applicationId`
  - SHA-1 必須對應你現在實際簽署 APK / AAB 所用的金鑰

如果 Web client id、Android client、套件名稱、SHA-1 不匹配，常見現象就是：

- Google 帳號選擇器有出現
- 選完帳號後 **完全沒有出現 Google Drive 權限頁**
- App 直接跳回來並顯示授權失敗 / 授權需要處理

## 故障現象對照

### 1. 帳號選擇器有出現，但權限頁沒出現

優先檢查：

- `oauth_request_id_token` 是否真的是 Web OAuth client id
- Cloud Console 是否有建立 Android OAuth client
- Android OAuth client 的套件名稱是否正確
- Android OAuth client 的 SHA-1 是否正確
- Google Drive API 是否啟用

這種情況通常 **不是** 單純的帳號拒絕授權殘留。

### 2. 有出現權限頁，但使用者按了拒絕

先做：

- App 內先按 `連結 Google Drive`
- 若已連結過，改按 `重新連結 Google Drive`
- 若仍有問題，到 Google 帳號的第三方連線管理移除 App 存取權後重試

### 3. 出現 `admin_policy_enforced`

這代表帳號所屬的公司 / 學校組織政策禁止這個第三方 App 存取 Google 資料。
需要組織管理員放行，不是重新登入能解。

### 4. 出現 `No credential`

優先檢查：

- Android 上的 Google Play 服務
- Google Sign-In / OAuth 設定
- `oauth_request_id_token`、Android client、SHA-1 是否一致

## 建議驗證流程

### 設定正確時

1. 按 `連結 Google Drive`
2. 出現 Google 帳號選擇器
3. 選帳號後出現 Google Drive 權限頁
4. 按允許
5. App 顯示已連結 Google Drive
6. 之後可直接上傳備份或從雲端還原

### 設定錯誤時

1. 按 `連結 Google Drive`，或在已連結狀態下按 `重新連結 Google Drive`
2. 出現 Google 帳號選擇器
3. 選帳號後直接失敗
4. 權限頁完全沒有出現

這時應優先查 OAuth / SHA-1，不要只重試帳號。
