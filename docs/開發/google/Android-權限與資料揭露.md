# Android 權限與資料揭露

這份文件整理 Quill Diary Android 版目前實際宣告的權限、用途，以及對應到 Google Play `Data safety` 與審查時應注意的範圍。內容以實作為準，來源主要是 `android/app/src/main/AndroidManifest.xml`、設定頁功能與隱私政策。

## 目前實際宣告的權限

截至目前，`AndroidManifest.xml` 只宣告了 3 個權限：

- `android.permission.INTERNET`
- `android.permission.USE_BIOMETRIC`
- `com.android.vending.BILLING`

沒有宣告下列常見高風險權限：

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

## 不是權限，但仍需留意的 `queries`

Manifest 另外宣告了 `queries`，這不是執行時權限，而是 Android 套件可見性查詢：

- `android.intent.action.PROCESS_TEXT` + `text/plain`
- `android.intent.action.VIEW` + `https`
- `android.intent.action.VIEW` + `http`

這些設定用來讓 App 查詢可處理文字分享或外部連結的目標，不代表 App 有額外讀取裝置資料的能力。

## 圖片與檔案存取的實際做法

Quill Diary 目前支援圖片與附件，但做法不是要求廣泛儲存權限，而是透過系統挑選器取得使用者明確選取的內容。

- 圖片選取使用 `image_picker`
- 檔案選取使用 `file_picker`
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

這表示 App 不依賴 Android Auto Backup 將資料自動備份到系統雲端。資料保存與還原主要由 App 自己的本機/Google Drive 備份流程處理。

## Play Console `Data safety` 填寫原則

這裡只列程式碼已能確認的邊界，實際表單欄位名稱仍以當下 Play Console 為準。

| 資料/能力 | 目前實作事實 | 填寫時應注意 |
|------|-------------|-------------|
| 日記內容 | 儲存在本機加密 vault；不會自動傳到開發者伺服器 | 若宣告資料蒐集，必須先有新的實作依據 |
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

## 參考實作

- [AndroidManifest.xml](../../../android/app/src/main/AndroidManifest.xml)
- [privacy-policy.md](../../privacy-policy.md)
- [Google-Drive-OAuth-設定.md](./Google-Drive-OAuth-設定.md)
- [Google-Play-Billing.md](./Google-Play-Billing.md)

---

[返回開發文件索引](../README.md)
