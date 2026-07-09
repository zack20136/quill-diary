# Google Play 上架

這份文件整理 Quill Diary 目前對 Google Play 上架真正有影響的實作資訊與手動作業點。內容以程式碼、Android 建置設定與公開文件為準，不保留無法從 repo 驗證的推測。

## 目前 App 基本事實

從程式碼可確認：

- 平台定位目前是 Android
- Android `applicationId` / `namespace`：`zack20136.com.quill_diary`
- `minSdk`：`30`
- 版本來源：`pubspec.yaml`
- 目前版本：`1.0.0+12`
- release 建置要求實體簽章設定，不允許用 debug signing 發 release

對應來源：

- [`android/app/build.gradle.kts`](../../../android/app/build.gradle.kts)
- [`pubspec.yaml`](../../../pubspec.yaml)

## 上架前必備項目

1. Google Play Developer 帳號
2. 完整的 release keystore 與 `android/key.properties`
3. 可產生 release `AAB` 的建置環境
4. 已完成的隱私政策頁面
5. 已確認的 `Data safety`、`App access`、Billing 與 Google Drive 敘述

## Release 簽章規則

`android/app/build.gradle.kts` 目前會在 release 任務啟動時檢查：

- `android/key.properties`
- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

只要缺其中任何一項，`assembleRelease`、`bundleRelease` 等 release 任務就會直接失敗。

可參考範本：

- [android/key.properties.example](../../../android/key.properties.example)

## 版本與識別資訊

目前 release 會直接使用 Flutter 提供的版本資訊：

- `versionCode = flutter.versionCode`
- `versionName = flutter.versionName`

而這些值在本專案來自 [`pubspec.yaml`](../../../pubspec.yaml) 的：

- `version: 1.0.0+12`

每次送審前至少要再確認：

- `applicationId` 沒被意外改動
- `versionCode` 已遞增
- `versionName` 符合本次釋出版本

## Play 商店頁面需與實作一致的功能描述

目前 App 具備且可從 repo 驗證的重點功能：

- 本機加密日記
- 生物辨識/復原金鑰解鎖流程
- 全文搜尋與索引
- 本機完整備份與還原
- Google Drive 備份與還原
- Google Play Billing 一次性支持

如果商店頁文案提到這些能力，內容必須與實作一致，特別是：

- Google Drive 不是整個雲端同步，而是使用者主動啟用的備份
- Billing 不是訂閱，也不解鎖額外功能

## 隱私政策與公開連結

程式碼中的公開網址由 `AppIdentifiers` 維護，目前應對應到：

- 隱私政策：`https://zack20136.github.io/quill-diary/privacy-policy`
- 第三方授權：`https://zack20136.github.io/quill-diary/third-party-notices`

相關來源：

- [lib/app/app_identifiers.dart](../../../lib/app/app_identifiers.dart)
- [docs/privacy-policy.md](../../privacy-policy.md)

若變更 GitHub Pages 路徑、repo 名稱或對外 URL，必須一起檢查上述檔案與 Play Console 連結。

## 與 Google 服務有關的送審重點

由於目前實作包含下列能力：

- Google Sign-In
- Google Drive `appDataFolder` 備份
- Google Play Billing

所以上架前要一併確認：

- `Data safety` 是否仍符合目前權限與資料流
- `App access` / 審查說明是否有交代 Google Drive 連線流程
- Billing 商品是否已建立並啟用
- OAuth 設定是否已補齊 Play App Signing SHA-1

## 建議送審檢查清單

1. 確認 `pubspec.yaml` 版本號
2. 確認 `applicationId` 仍為 `zack20136.com.quill_diary`
3. 確認 `android/key.properties` 與 release keystore 可用
4. 產出 release `AAB`
5. 確認隱私政策 URL 可公開存取
6. 對照 [`Android-權限與資料揭露.md`](./Android-權限與資料揭露.md) 更新 `Data safety`
7. 對照 [`Google-Drive-OAuth-設定.md`](./Google-Drive-OAuth-設定.md) 檢查 OAuth 與 Play App Signing SHA-1
8. 對照 [`Google-Play-Billing.md`](./Google-Play-Billing.md) 檢查商品與說明
9. 檢查商店頁文字不要宣稱未實作功能

## 變更前必查

只要碰到下列變更，就應同步檢查這份文件與 Play Console：

- `applicationId`、版本號、`minSdk` 或 target API 變更
- release signing 流程變更
- 公開 URL 變更
- Google Drive / OAuth 流程變更
- Billing 型態改成訂閱、會員或權益制
- 權限、資料流或隱私政策變更

## 參考實作

- [android/app/build.gradle.kts](../../../android/app/build.gradle.kts)
- [android/key.properties.example](../../../android/key.properties.example)
- [pubspec.yaml](../../../pubspec.yaml)
- [lib/app/app_identifiers.dart](../../../lib/app/app_identifiers.dart)
- [privacy-policy.md](../../privacy-policy.md)

---

[返回開發文件索引](../README.md)
