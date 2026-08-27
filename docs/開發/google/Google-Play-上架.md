# Google Play 上架

這份文件整理 Quill Diary 目前影響 Google Play 上架的實作資訊與手動作業。內容以程式碼、Android 建置設定與公開文件為準，不保留無法從 repo 驗證的推測。

## 目前 App 基本事實

從程式碼可確認：

- 平台定位目前是 Android
- Android `applicationId`/`namespace`：`zack20136.com.quill_diary`
- `minSdk`：`30`
- `targetSdk` 由 Flutter/Android 建置設定解析；以當次 release merged manifest 為準
- 版本以 [`pubspec.yaml`](../../../pubspec.yaml) 的 `version:` 為準；送審前確認 `versionCode` 已遞增
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

這裡設定的是本機用來簽署上傳 AAB 的 upload key。若已啟用 Play App Signing，Google 會再使用獨立的 app signing key 簽署交付給使用者的 APK；兩者的憑證指紋不能混用。OAuth 等 API 服務通常要登記實際安裝版本的 Play App Signing SHA-1，而不只 upload key SHA-1。

可參考範本：

- [android/key.properties.example](../../../android/key.properties.example)

## 版本與識別資訊

目前 release 會直接使用 Flutter 提供的版本資訊：

- `versionCode = flutter.versionCode`
- `versionName = flutter.versionName`

而這些值在本專案來自 [`pubspec.yaml`](../../../pubspec.yaml) 的 `version:`（勿在本文件寫死版號）。

每次送審前至少要再確認：

- `applicationId` 沒被意外改動
- `versionCode` 已遞增
- `versionName` 符合本次釋出版本

## Play 商店頁面需與實作一致的功能描述

目前 App 具備且可從 repo 驗證的重點功能：

- 本機加密日記
- 生物辨識/復原金鑰解鎖流程
- 全文搜尋與索引
- 加密人物名冊與依姓名/別名產生的可重建分析索引
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

Play 的隱私政策要求 URL 可公開存取、非 PDF、不可由一般訪客編輯且不受地區限制；政策內容還要能識別 App/開發者、說明資料存取與分享方式、保護措施、保留與刪除方式及聯絡管道。不能只確認網址存在。

## 會隨時間更新的 Play 外部門檻

以下不是 repo 常數，送審當天仍應重查官方政策：

- 自 2026 年 8 月 31 日起，手機/平板的新 App 與更新需 target Android 16（API 36）以上；既有 App 至少 target Android 15（API 35），才能繼續對較新 Android 裝置的新使用者顯示。官方另提供符合條件者申請延至 2026 年 11 月 1 日的機制。
- 自 2026 年 9 月 30 日起，Play 套件必須符合 Android 開發者驗證與套件名稱註冊要求。Google 會嘗試自動註冊符合條件的既有與新 App，但仍應到 Play Console 的 Android developer verification 頁確認 `zack20136.com.quill_diary` 狀態。

target API 不合規可能阻擋更新送審，或限制既有 App 對較新裝置的新使用者可見；它不等同於所有使用者都看不到整個商店頁。若頁面消失，還要檢查發布軌道、國家/地區、裝置相容性、帳號與政策狀態。

## 與 Google 服務有關的送審重點

由於目前實作包含下列能力：

- Google Sign-In
- Google Drive `appDataFolder` 備份
- Google Play Billing

所以上架前要一併確認：

- `Data safety` 是否仍符合目前權限與資料流
- `App access`/審查說明是否有交代 Google Drive 連線流程
- Billing 商品是否已建立並啟用
- OAuth 設定是否已補齊 Play App Signing SHA-1
- Foreground service declaration（見下節）是否已填寫並附示範影片

## Foreground service（dataSync）declaration

target Android 14（API 34）以上並使用 `FOREGROUND_SERVICE_DATA_SYNC` 時，Play Console 需要 foreground service declaration。本 App 對應：

- FGS type：`TYPE_DATA_SYNC`
- Use case：`Network transfer: Backup and restore`
- 功能描述：使用者手動建立備份 ZIP（內含加密 vault 與部分明文 metadata），並上傳至 Google Drive `appDataFolder`；不是排程或常駐背景同步
- 為何不可任意延後：使用者剛建立的備份需儘快送達其 Drive，否則其他裝置/重裝後無法立刻還原
- 中斷影響：同一 FGS 存活期間可在網路恢復後自動重試；遠端完成驗證前若服務或程序異常終止，則清除本機 staging 與 job，下次開啟 App 顯示一次失敗提示，使用者需重新備份。使用者主動停止時先進入 `CANCEL_CLEANUP_PENDING`，不建立失敗提示；worker 退出後（或下次啟動）再查詢／刪除未完成的遠端殘檔。已進入 `STATUS_PENDING` 或 `PRUNE_PENDING` 時則保留狀態供 App 下次收尾，不會重新上傳。在 Android 15+ 裝置上，target Android 15（API 35）以上 App 的 dataSync 共用額度用盡也會終止尚未提交完成的上傳
- 示範影片建議內容：連結 Google Drive → 點上傳 → 顯示進度通知 → 切換到其他 App → 通知仍在更新 → 按停止或完成後返回 App

官方也建議部分使用者主動網路傳輸改用 User-Initiated Data Transfer job。本版保留 dataSync FGS，declaration 需對齊「使用者主動觸發、即時顯示進度、可從通知列停止；遠端完成驗證前若程序異常終止，需重新備份」。

## 建議送審檢查清單

1. 確認 `pubspec.yaml` 版本號
2. 確認 `applicationId` 仍為 `zack20136.com.quill_diary`
3. 確認 `android/key.properties` 與 release keystore 可用
4. 產出 release `AAB`
5. 以 release merged manifest 或 App Bundle Explorer 核對套件名稱、版本、SDK、所有權限與 `queries`
6. 確認隱私政策 URL 可公開存取
7. 確認 Play Console 的開發者驗證與套件名稱註冊狀態
8. 對照 [`Android-權限與資料揭露.md`](./Android-權限與資料揭露.md) 更新 `Data safety`
9. 對照 [`Google-Drive-OAuth-設定.md`](./Google-Drive-OAuth-設定.md) 檢查 OAuth 與 Play App Signing SHA-1
10. 確認 OAuth consent screen 使用目前公開隱私政策，且政策包含 Google API Limited Use 聲明
11. 填寫 dataSync foreground service declaration，並附上能展示啟動、背景進度、停止與完成流程的示範影片
12. 對照 [`Google-Play-Billing.md`](./Google-Play-Billing.md) 檢查商品與說明
13. 檢查商店頁文字不要宣稱未實作功能

當次送審 AAB 的 release merged manifest 是該產物版本與權限的最終核對來源；`build/` 中舊產物不能代表目前 `pubspec.yaml`。若 Play 商店頁面或版本不可見，仍需另外到 Play Console 檢查發布軌道、國家/地區、裝置相容性與政策狀態；這些外部狀態無法只從 repo 判定。

## 變更前必查

只要碰到下列變更，就應同步檢查這份文件與 Play Console：

- `applicationId`、版本號、`minSdk` 或 target API 變更
- release signing 流程變更
- 公開 URL 變更
- Google Drive/OAuth 流程變更
- Billing 型態改成訂閱、會員或權益制
- 權限、資料流或隱私政策變更

## 參考實作

- [android/app/build.gradle.kts](../../../android/app/build.gradle.kts)
- [android/key.properties.example](../../../android/key.properties.example)
- [pubspec.yaml](../../../pubspec.yaml)
- [lib/app/app_identifiers.dart](../../../lib/app/app_identifiers.dart)
- [privacy-policy.md](../../privacy-policy.md)

## 官方規範參考

- [Google Play target API 時程](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Google Play 套件名稱註冊](https://support.google.com/googleplay/android-developer/answer/16984799)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Google Play 使用者資料與隱私政策](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Google Play App access](https://support.google.com/googleplay/android-developer/answer/15748846)

---

[返回開發文件索引](../README.md)
