# Google Drive OAuth 設定

Drive 只使用 `https://www.googleapis.com/auth/drive.appdata`，存取 App 的 `appDataFolder`。帳號登入與 Drive 授權是兩個步驟；實作見 [`drive_backup_service.dart`](../../../lib/infrastructure/drive/drive_backup_service.dart)。

## OAuth client 與 App 識別

| 項目 | 設定與用途 |
|------|------|
| Android OAuth client | 套件名稱 `zack20136.com.quill_diary` 加上實際安裝版本的簽章 SHA-1 |
| Web OAuth client | 提供 Android Google Sign-In 的 server client ID |
| `oauth_request_id_token` | [`oauth_config.xml`](../../../android/app/src/main/res/values/oauth_config.xml) 中的 **Web client ID**，不可填 Android client ID |
| 建置覆寫 | `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` 優先於原生 channel 回傳的 XML 設定 |

[`google_drive_oauth_errors.dart`](../../../lib/infrastructure/drive/google_drive_oauth_errors.dart) 維護的指紋：

| 憑證 | SHA-1 |
|------|------|
| Debug | `B0:B3:BC:E7:7C:68:8E:67:84:B4:B8:BB:FF:E5:A8:AE:24:6F:53:BB` |
| Release upload key | `3D:40:C1:59:06:52:4E:C5:76:2D:29:51:30:92:77:7C:54:D5:42:1C` |

Play 安裝版還需要 Play Console App Signing 的 SHA-1，不能只登記 upload key。簽章變更時同步程式內指紋與本文件。

## 設定流程

1. 在 Google Cloud Console 啟用 Google Drive API。
2. 在同一 Cloud 專案建立 Android OAuth client。每組「套件名稱＋簽章 SHA-1」分別登記；debug、側載 release 與 Play 安裝版不能只共用 upload key 那一筆。
3. 建立 Web OAuth client，把它的 client ID 填入 XML 或建置覆寫值。App 不需要也不能內嵌 Web client secret。
4. 完成 Google Auth Platform 的品牌、使用者對象與資料存取設定。App 名稱、首頁、支援聯絡方式與隱私政策須與實際發布版本一致；資料存取只加入 `drive.appdata`。
5. 測試狀態先加入測試帳號；對外發布前依 Console 完成正式發布與適用的品牌驗證，不能假設內部測試成功即代表一般使用者都可登入。是否需要其他驗證以實際 scope 與 Console 要求為準。
6. 先在開發安裝版測試，再從 Play 測試軌道安裝測試；從 App 設定連線，確認帳號登入後取得 Drive appdata scope，能上傳、列出、下載及還原備份。

公開隱私政策使用 `https://zack20136.github.io/quill-diary/privacy-policy`，並保留其中 Google API Limited Use 聲明。政策網址與 App 識別來源是 [`AppIdentifiers`](../../../lib/shared/app_identifiers.dart)。正式發布與驗證條件見 [OAuth 品牌驗證](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification)。

### 建置設定與簽章核對

平常修改 `oauth_config.xml` 即可；若 CI 或本機建置有傳入 `GOOGLE_SERVER_CLIENT_ID`，該值會覆蓋 XML。改 XML 後仍連到舊專案時，先檢查實際建置參數，解析實作見 [`google_oauth_config.dart`](../../../lib/infrastructure/drive/google_oauth_config.dart)。

```powershell
# repo 根目錄；只輸出各 variant 的憑證資訊，不修改簽章。
Push-Location android
try {
  .\gradlew.bat signingReport
} finally {
  Pop-Location
}
```

`signingReport` 只能核對本機持有的憑證；Play App Signing 憑證仍須從 Play Console 的應用程式完整性／App signing 頁取得。這裡沒有把 Play SHA-1 寫成 upload SHA-1，也不要把 keystore、密碼或 API Key 放進文件。

## 登入、授權與連線快照

Dart 端使用 `google_sign_in` 初始化並取得帳號，再由 `authorizationForScopes()`／`authorizeScopes()` 取得授權。Drive REST 使用 scope access token，不使用 ID token。

Android 互動連線先嘗試 [`MainActivity.kt`](../../../android/app/src/main/kotlin/zack20136/com/quill_diary/MainActivity.kt) 的原生後備流程，該流程另要求 email 與 ID token；成功後仍回 Dart 取得 Drive 授權。

非互動「已連線」快照同時要求 `getLastSignedInAccount()` 與 `hasPermissions(...drive.appdata)` 成立。真正列檔、上傳及下載時仍取得可用授權。

`google_sign_in_android` 使用 Credential Manager，專案另保留 `play-services-auth` legacy 後備。移除後備時須一起更新原生登入、連線快照、錯誤映射及測試。

## 常見錯誤

| 訊息 | 排查方向 |
|------|------|
| `access_denied` | 使用者／組織政策拒絕、consent screen、Drive API 或 scope 設定 |
| `No credential` | Web client ID、Android 套件／SHA-1、裝置憑證狀態 |
| `[10] Developer error` | Android OAuth client 與套件／簽章不一致，或誤填 Android client ID |
| `[12500] Sign in failed` | 原生後備的泛用錯誤；核對 OAuth 設定、Google Play services 與帳號 |
| `[16] Account reauth failed` | 帳號重新驗證；只在 Play 版發生時先核對 App Signing SHA-1 |
| `canceled` | 可能是使用者取消，也可能是底層設定錯誤被包裝；反覆出現時核對上述識別與設定 |

錯誤字串只能提供排查方向，不能單憑字串斷定原因。

排查時先記錄「安裝來源、套件名稱、簽章 SHA-1、實際 Web client ID 所屬專案、錯誤代碼」；不要收集 access token、ID token 或私人備份。Debug 正常但 Play 版失敗時，優先比對 Play App Signing SHA-1。帳號可登入但 Drive 沒權限時，檢查 scope 授權，不要把帳號存在當成授權成功。

切換帳號時，原生後備依 `resetSession` 執行 `revokeAccess()`、`signOut()` 後重新登入；失敗則由 Dart `disconnect()`，必要時退回 `signOut()`，再重新授權。

上傳中的帳號限制及取消後重連原帳號的例外，統一見[備份與還原](../功能/備份與還原.md#背景上傳生命週期)。

## 發布與回歸驗證

| 情境 | 預期結果 |
|------|------|
| 首次連線／取消授權 | 成功取得 appdata scope，或取消後維持可操作狀態 |
| 已連線重開 App | 快照能顯示帳號，真正存取時仍重新取得有效授權 |
| 撤銷授權後操作 | 能提示重新連線，不把舊快照當作有效 token |
| 切換 Google 帳號 | 備份清單屬於新帳號，不混用原帳號 token |
| 從 Play 安裝 | 同時驗證 OAuth App Signing 設定與實際 Drive 操作 |
| 上傳取消待清理 | 依備份文件重連原帳號對帳，不任意切換帳號 |

套件名稱、簽章、scope 或 MethodChannel 變更時，一起修改 Cloud 設定、Dart／Kotlin 載入與錯誤映射，並重新執行以上流程。Play 審查帳號與操作說明見[上架文件](Google-Play-上架.md#app-access-與審查操作說明)。

官方參考：[Credential Manager 遷移](https://developer.android.com/identity/sign-in/legacy-gsi-migration)、[google_sign_in](https://pub.dev/documentation/google_sign_in/latest/)、[Android 套件設定](https://pub.dev/packages/google_sign_in_android)、[appDataFolder](https://developers.google.com/workspace/drive/api/guides/appdata)。

[← 返回開發文件導覽](../README.md)
