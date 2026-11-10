# Google Drive OAuth 設定

Drive API 只要求 `https://www.googleapis.com/auth/drive.appdata`，不存取整個 Drive。帳戶登入與 Drive 授權分開處理，實作見 [`drive_backup_service.dart`](../../../lib/infrastructure/drive/drive_backup_service.dart)。

此非敏感 OAuth scope 獨立於 Android 權限、URI grant 及 email／ID token。[appDataFolder](https://developers.google.com/workspace/drive/api/guides/appdata) 是 App 專用隱藏空間，備份由 App 管理，中斷連線不會刪除。

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
2. 在同一專案分別登記 debug、側載 release 與 Play 安裝版的「套件名稱＋簽章 SHA-1」，建立 Android OAuth client。
3. 建立 Web OAuth client，將 client ID 填入 XML 或建置覆寫值；不得內嵌 Web client secret。
4. 設定 Google Auth Platform 品牌、使用者對象及 `drive.appdata`；名稱、首頁、支援聯絡方式與隱私政策須對齊發布版本。
5. 測試期間加入測試帳戶；對外發布前完成 Console 要求的正式發布與品牌驗證。測試帳戶成功不代表所有人都可登入。
6. 分別用開發版及 Play 測試軌道安裝版驗證登入、scope、備份上傳、列出、下載與還原。

隱私政策使用 [`AppIdentifiers`](../../../lib/shared/app_identifiers.dart) 的 `https://zack20136.github.io/quill-diary/privacy-policy`，保留 Google API Limited Use 聲明。驗證條件見 [OAuth 品牌驗證](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification)。

### 建置設定與簽章核對

修改 XML 後仍連到舊專案時，先檢查 CI／本機的 `GOOGLE_SERVER_CLIENT_ID` 覆寫；解析見 [`google_oauth_config.dart`](../../../lib/infrastructure/drive/google_oauth_config.dart)。

```powershell
# repo 根目錄；只輸出各 variant 的憑證資訊，不修改簽章。
Push-Location android
try {
  .\gradlew.bat signingReport
} finally {
  Pop-Location
}
```

`signingReport` 僅列本機憑證；Play App Signing SHA-1 從 Console 的應用程式完整性／App signing 頁取得。keystore、密碼及 API Key 不寫入文件。

## 登入、授權與連線快照

Dart 端以 `google_sign_in` 取得帳戶，再用 `authorizationForScopes()`／`authorizeScopes()` 取得 Drive access token；REST 不使用 ID token。Android 互動連線先嘗試 [`MainActivity.kt`](../../../android/app/src/main/kotlin/zack20136/com/quill_diary/MainActivity.kt) 的原生後備（要求 email／ID token），成功後回 Dart 取得 Drive 授權。

非互動快照要求 `getLastSignedInAccount()` 與 `hasPermissions(...drive.appdata)` 同時成立；實際 I/O 仍須取得有效授權。套件使用 Credential Manager，專案另保留 `play-services-auth` legacy 後備；移除時同步更新原生登入、快照、錯誤映射與測試。

## 常見錯誤

| 訊息 | 排查方向 |
|------|------|
| `access_denied` | 使用者／組織政策拒絕、consent screen、Drive API 或 scope 設定 |
| `No credential` | Web client ID、Android 套件／SHA-1、裝置憑證狀態 |
| `[10] Developer error` | Android OAuth client 與套件／簽章不一致，或誤填 Android client ID |
| `[12500] Sign in failed` | 原生後備的泛用錯誤；核對 OAuth 設定、Google Play services 與帳戶 |
| `[16] Account reauth failed` | 帳戶重新驗證；只在 Play 版發生時先核對 App Signing SHA-1 |
| `canceled` | 可能是使用者取消，也可能是底層設定錯誤被包裝；反覆出現時核對上述識別與設定 |

錯誤字串僅供排查。記錄安裝來源、套件名稱、SHA-1、Web client ID 所屬專案與錯誤碼，不收集 token 或私人備份。僅 Play 版失敗時優先查 App Signing SHA-1；登入成功但無法存取 Drive 時查 scope。

切換帳戶時，原生後備依 `resetSession` 執行 `revokeAccess()`、`signOut()` 後重新登入；失敗則由 Dart `disconnect()`，必要時退回 `signOut()`，再重新授權。

上傳中的帳戶限制及取消後重連原帳戶的例外，統一見[備份與還原](../功能/備份與還原.md#背景上傳生命週期)。

## 發布與回歸驗證

| 情境 | 預期結果 |
|------|------|
| 首次連線／取消授權 | 成功取得 appdata scope，或取消後維持可操作狀態 |
| 已連線重開 App | 快照能顯示帳戶，真正存取時仍重新取得有效授權 |
| 撤銷授權後操作 | 能提示重新連線，不把舊快照當作有效 token |
| 切換 Google 帳戶 | 備份清單屬於新帳戶，不混用原帳戶 token |
| 從 Play 安裝 | 同時驗證 OAuth App Signing 設定與實際 Drive 操作 |
| 上傳取消待清理 | 依備份文件重連原帳戶對帳，不任意切換帳戶 |

變更套件名稱、簽章、scope 或 MethodChannel 時，同步 Cloud 設定、Dart／Kotlin 與錯誤映射，再跑上表驗證。審查存取見[上架文件](Google-Play-上架.md#app-access-與審查操作說明)。

官方參考：[Credential Manager 遷移](https://developer.android.com/identity/sign-in/legacy-gsi-migration)、[google_sign_in](https://pub.dev/documentation/google_sign_in/latest/)、[Android 套件設定](https://pub.dev/packages/google_sign_in_android)、[appDataFolder](https://developers.google.com/workspace/drive/api/guides/appdata)。

[← 返回開發文件導覽](../README.md)
