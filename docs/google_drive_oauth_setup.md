# Google Drive OAuth 設定

本專案用 [`google_sign_in`](https://pub.dev/packages/google_sign_in) 加上 Google Drive API 來做備份／還原。維護上只要記住兩件事：

- **Android** 要提供 **Web OAuth Client ID** 給 `GoogleSignIn.initialize(serverClientId: ...)`
- **iOS** 要在 `Info.plist` 補齊 Google Sign-In 需要的欄位

## 你需要準備的 OAuth 用戶端

| 類型 | 用途 | 寫進專案哪裡 |
|------|------|--------------|
| **Web application** | Android 的 `serverClientId`，也同時提供 iOS 的 `GIDServerClientID` | `android/app/src/main/res/values/oauth_config.xml` 的 `oauth_request_id_token`，或 `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` |
| **Android** | 讓 Google 信任指定的套件名稱與簽章 SHA-1 | 只在 Google Cloud Console 建立，不寫進 repo |
| **iOS** | 給 iOS Google Sign-In 使用 | `ios/Runner/Info.plist` 的 `GIDClientID` |

三者都應建立在同一個 Google Cloud 專案，並完成 OAuth 同意畫面設定。

## 專案內對應位置

- Android 套件名稱：[`android/app/build.gradle.kts`](../android/app/build.gradle.kts) 的 `applicationId`
- Android Web Client ID：[`android/app/src/main/res/values/oauth_config.xml`](../android/app/src/main/res/values/oauth_config.xml)
- Android 讀取邏輯：[`lib/config/oauth_config.dart`](../lib/config/oauth_config.dart)
- iOS 設定：[`ios/Runner/Info.plist`](../ios/Runner/Info.plist)

## Google Cloud 設定檢查清單

1. 到 [Google Cloud Console](https://console.cloud.google.com/) 選定或建立專案。
2. 啟用 **Google Drive API**。
3. 完成 **OAuth 同意畫面**；若專案仍在測試狀態，把要登入的帳號加到測試使用者。
4. 建立 **Android OAuth 用戶端**：
   - 套件名稱必須等於 `applicationId`
   - SHA-1 必須來自實際簽署該安裝檔的 keystore
5. 建立 **Web application OAuth 用戶端**，把 Client ID 填進 `oauth_request_id_token`。
6. iOS 需要另外建立 **iOS OAuth 用戶端**，並讓 Bundle ID 與 Xcode 專案一致。

## Android

預設做法是把 Web Client ID 寫進 [`oauth_config.xml`](../android/app/src/main/res/values/oauth_config.xml)：

```xml
<string name="oauth_request_id_token">你的-web-client-id.apps.googleusercontent.com</string>
```

若你不想把值寫死在 repo，也可以在執行或 CI 時覆寫：

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=你的-web-client-id.apps.googleusercontent.com
```

只要 `GOOGLE_SERVER_CLIENT_ID` 非空，程式就不會再向 Android 原生讀取 XML。

## iOS

請在 [`ios/Runner/Info.plist`](../ios/Runner/Info.plist) 補上：

1. `GIDServerClientID`：填入和 Android 相同的 **Web Client ID**
2. `GIDClientID`：填入 **iOS OAuth 用戶端** 的 Client ID
3. `CFBundleURLTypes` 的 `CFBundleURLSchemes`：填入 iOS Client ID 的 `REVERSED_CLIENT_ID`

如果 iOS Client ID 是：

```text
123456789-abc.apps.googleusercontent.com
```

那對應的 URL Scheme 會是：

```text
com.googleusercontent.apps.123456789-abc
```

若出現 `No credential available`，通常代表 iOS OAuth 用戶端或 `Info.plist` 仍未設定完整。

## SHA-1（Windows）

```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

## 常見問題

### 可以用個人 Google 帳號建立 GCP 專案嗎？

可以。大多數獨立開發情境都沒問題，但仍要注意測試使用者、專案移交與預算警示。

### Web Client ID 可以放在 repo 嗎？

通常可以，但如果 repo 是公開的，仍建議評估是否改用本機或 CI 注入。

### 哪些東西不能 commit？

不要把正式 keystore 密碼、後端金鑰或其他敏感憑證提交到 git。
