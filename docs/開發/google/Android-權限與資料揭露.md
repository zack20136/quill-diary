# Android 權限與資料揭露

這份文件整理 Quill Diary Android 版目前實際宣告的權限、用途，以及對應到 Google Play `Data safety` 與審查時應注意的範圍。主 Manifest 用來確認 App 主動宣告的項目；送審前則以「當次送審 AAB 對應的」release variant merged manifest 為最終依據，因為套件依賴也可能合併權限與 `queries`。`build/` 下舊建置留下的檔案可能已過期，不能當成目前原始碼的證據。

## 主 Manifest 直接宣告的權限

[`android/app/src/main/AndroidManifest.xml`](../../../android/app/src/main/AndroidManifest.xml) 直接宣告 3 個權限：

- `android.permission.INTERNET`
- `android.permission.USE_BIOMETRIC`
- `com.android.vending.BILLING`

主 Manifest 與工作區現存的最近一次 release merged manifest 都沒有下列常見高風險權限；後者可能是舊建置，送審前仍須重新產生：

- `READ_MEDIA_IMAGES`
- `READ_EXTERNAL_STORAGE`
- `WRITE_EXTERNAL_STORAGE`
- `CAMERA`
- `RECORD_AUDIO`

## 權限用途對照

| 權限 | 用途 | 對應功能 |
|------|------|----------|
| `INTERNET` | 連線到 Google 服務 | Google Sign-In、Google Drive 備份/還原、Google Play Billing |
| `USE_BIOMETRIC` | 呼叫 Android 生物辨識驗證 | 裝置綁定解鎖、會話重新驗證 |
| `BILLING` | 啟用 Google Play Billing | 一次性支持購買 |

## 依賴合併加入的項目

工作區現存的最近一次 release merged manifest 另外包含：

| 項目 | 來源與用途 |
|------|------------|
| `android.permission.USE_FINGERPRINT` | 生物辨識相容依賴合併加入，配合較舊 Android 生物辨識 API |
| `android.permission.ACCESS_NETWORK_STATE` | Google／Billing 網路元件合併加入，用來判斷網路狀態 |
| `{applicationId}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX 自動建立的 signature-level 內部權限，限制非匯出動態 receiver；不是使用者授予的執行時權限 |

這些項目不是主 Manifest 主動新增的產品能力，但會出現在實際送出的 App Bundle。依賴版本改動後必須重新產生 merged manifest 核對，不能只看本文件的既有清單。

## 不是權限，但仍需留意的 `queries`

主 Manifest 與依賴合併後的 `queries` 包含下列 intent／service 查詢。它們不是執行時權限，而是 Android 套件可見性設定：

- `android.intent.action.PROCESS_TEXT` + `text/plain`
- `android.intent.action.VIEW` + `https`
- `android.intent.action.VIEW` + `http`
- `android.intent.action.GET_CONTENT` + `*/*`
- `com.android.vending.billing.InAppBillingService.BIND`
- `com.google.android.apps.play.billingtestcompanion.BillingOverrideService.BIND`

`GET_CONTENT` 只讓系統挑選器列出可處理使用者選檔動作的 App，不等於廣泛檔案存取權限；Billing service 查詢只用來尋找 Google Play Billing 服務。這些設定也不會授予聯絡人、媒體庫或整個儲存空間的讀取能力。

## 圖片與檔案存取的實際做法

Quill Diary 目前支援圖片與附件，但做法不是要求廣泛儲存權限，而是透過系統挑選器取得使用者明確選取的內容。

- 圖片選取使用 `image_picker`
- 檔案選取使用 `file_picker`（目前實際版本與升級注意事項見 [備份與還原.md](../功能/備份與還原.md#外部選檔與-materialize)）
- App 只處理使用者當次挑選的 `content://` 或暫存檔案
- 沒有自行掃描相簿、整個儲存空間或下載資料夾

因此目前不需要 `READ_MEDIA_IMAGES`、`READ_EXTERNAL_STORAGE` 或 `WRITE_EXTERNAL_STORAGE`。

## 備份相關的資料邊界

本機完整備份與還原由使用者手動選檔。Google Drive 備份則只在使用者主動連線帳號後啟用，且 scope 限定為：

- `https://www.googleapis.com/auth/drive.appdata`

也就是只存取 App 自己的 `appDataFolder`，不是整個 Google Drive。

## `allowBackup` 設定

`application` 目前設定：

- `android:allowBackup="false"`

這會停用 Android 的雲端 Auto Backup，App 的資料保存與還原主要由自己的本機／Google Drive 備份流程處理。不過 Android 官方註明：Android 12 以上在部分裝置廠牌上，`allowBackup="false"` 不一定能停用裝置到裝置移轉，因此不能把這個屬性描述成所有系統搬機路徑的絕對阻擋。

## Play Console `Data safety` 填寫原則

這裡只列程式碼已能確認的邊界，實際表單欄位名稱仍以當下 Play Console 為準。

Google Play 的定義中，只在使用者裝置上處理、沒有送出裝置的資料不算「蒐集」。送出裝置的端對端加密資料，只有在開發者與所有中介者皆無法讀取、僅傳送者與接收者持有必要金鑰時，才不需揭露為蒐集；「由使用者主動觸發」是 sharing 的例外條件之一，不能直接當成 collection 的全面豁免。最終答案仍要依當次 App、所有第三方 SDK 與 Play 表單逐項判斷，不能只複製本表。

| 資料/能力 | 目前實作事實 | 填寫時應注意 |
|------|-------------|-------------|
| 日記內容 | 儲存在本機加密 vault；不會自動傳到開發者伺服器 | 若宣告資料蒐集，必須先有新的實作依據 |
| 人物名冊 | 姓名、別名、關係、生日、備註等由使用者輸入，保存在本機加密 `people.json.enc` | 使用者主動建立的加密完整備份會包含；SQLite 人物分析索引不會包含 |
| Google Drive 備份 | 只在使用者主動啟用後，透過 Google 帳號把備份寫入 `appDataFolder` | 屬使用者觸發的 Google Drive 備份流程，不是預設背景同步 |
| 生物辨識 | 僅用於裝置端驗證 | 不代表 App 取得可外送的生物特徵資料 |
| 付款資訊 | 由 Google Play 處理 | App 不自行保存信用卡或付款憑證 |
| 網路連線 | 用於 Google Sign-In、Drive、Billing | 若未來加入自家 API，再重新檢查文件與揭露 |

## 變更前必查

只要碰到下列項目，就必須同步更新這份文件與 Play Console 揭露：

- `AndroidManifest.xml` 新增或移除權限
- 圖片/檔案流程改成需要廣泛媒體或儲存權限
- 新增相機、麥克風、定位、聯絡人等能力
- Google Drive scope 改動
- 新增自家後端 API、分析或廣告 SDK
- Billing 行為改成訂閱、會員或跨裝置權益同步

## 送審前最終核對

release AAB 建置完成後，以 release merged manifest 或 Play Console App Bundle Explorer 核對下列項目：

- `package`／`applicationId`、`versionCode`、`versionName`
- `minSdk`、`targetSdk`
- 所有 `<uses-permission>`（包含依賴合併項目）
- 所有 `<queries>` intent 與 service

當次送審產物的 merged manifest 是該 AAB 權限與版本資訊的最終核對來源；[`pubspec.yaml`](../../../pubspec.yaml)、Gradle 與主 Manifest 則分別是版本、Android 建置設定與直接宣告的來源。若 merged manifest 的版本和 `pubspec.yaml` 不一致，先重新建置，不要拿舊的 `build/` 快取送審。

## 參考實作

- [AndroidManifest.xml](../../../android/app/src/main/AndroidManifest.xml)
- [privacy-policy.md](../../privacy-policy.md)
- [Google-Drive-OAuth-設定.md](./Google-Drive-OAuth-設定.md)
- [Google-Play-Billing.md](./Google-Play-Billing.md)

## 官方規範參考

- [Android Storage Access Framework](https://developer.android.com/training/data-storage/shared/documents-files)
- [Android 套件可見性與 `<queries>`](https://developer.android.com/training/package-visibility/declaring)
- [Android `<application>` 的 `allowBackup`](https://developer.android.com/guide/topics/manifest/application-element)
- [Google Play Data safety 填寫說明](https://support.google.com/googleplay/android-developer/answer/10787469)

---

[返回開發文件索引](../README.md)
