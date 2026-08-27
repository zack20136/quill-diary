# Quill Diary 隱私權政策

**生效日期：2026 年 8 月 27 日**

本政策說明 Quill Diary（Android 套件名稱：`zack20136.com.quill_diary`，以下簡稱「本 App」）如何處理你的資料。本 App 以離線、本機加密為核心設計，預設不建立線上帳號系統，也不會主動收集或上傳你的日記內容。

本頁是 Quill Diary 對外公開的資料處理說明。若本政策與 App 的實際資料處理方式不一致，請依本頁聯絡方式通知；開發者會校正實作或更新政策，不能以非公開說明取代本頁揭露。

## 快速摘要

- 日記內容、人物名冊、附件、草稿、搜尋索引與多數設定預設保存在你的裝置上
- 本 App 不內建廣告 SDK，也不以追蹤使用者為目的蒐集資料
- 只有在你主動使用 Google Drive 備份、系統檔案選取或 Google Play 購買時，才會與對應平台服務互動
- 本 App 不會把日記明文上傳到開發者控制的伺服器

## 1. 適用範圍

本政策適用於你透過 Google Play 或其他合法來源取得並使用的 Quill Diary Android 版本，以及本 App 提供的本機儲存、備份、匯入匯出、支持開發者與 Google Drive 備份相關功能。

## 2. 我們如何處理你的資料

### 2.1 預設情況：不收集日記內容

在正常使用中，你的日記標題、內文、日記內標籤、人物名冊、附件、草稿與搜尋索引主要保存在你的裝置上，並以加密形式儲存。復原設定及部分輔助 metadata 會以明文保存在 App 私有空間，包括 `recovery.json`、已建立的標籤目錄與釘選項目 ID；它們不包含日記內文或附件內容。開發者不會自動收到、讀取或上傳這些資料。

### 2.2 僅在你主動操作時涉及的資料

| 功能 | 可能涉及的資料 | 說明 |
|------|----------------|------|
| Google Drive 備份 | Google 帳號識別碼、電子郵件地址與顯示名稱，以及你主動上傳的備份 ZIP | 僅在你連結 Google 帳號並執行 Drive 備份或還原時發生。帳號資訊用於顯示目前帳號並確認上傳所屬帳號。ZIP 外層未另外加密；其中日記、附件與人物名冊為加密格式，但包含明文復原 metadata，以及存在時的標籤目錄與釘選項目 ID。Android 可在你觸發後於背景完成上傳並以通知顯示進度；不是自動排程同步 |
| 選取圖片或檔案 | 你透過 Android 系統選取器挑選的檔案 | 本 App 只處理你明確選取的項目，不會掃描整個相簿或儲存空間 |
| 生物辨識或裝置驗證解鎖 | 驗證是否成功的結果 | 驗證由 Android 系統處理；本 App 不會取得你的生物特徵原始資料 |
| 支持開發者 | Google Play 購買流程所需資料 | 付款與交易驗證由 Google Play 處理；本 App 不保存支持紀錄，也不會因支持而讀取你的日記內容 |

### 2.3 我們不會做的事

- 不內嵌廣告或第三方追蹤 SDK
- 不出售你的個人資料
- 不建立開發者自有雲端帳號系統來收集日記內容
- 不將日記明文上傳至開發者控制的伺服器

## 3. 本機資料存放

本 App 在你的裝置上可能建立或保存下列資料：

- 正式日記庫（例如 `vault/` 下的加密內容）
- 加密人物名冊（姓名、別名、關係、生日、備註等由你輸入的資料）
- 編輯草稿（例如 `drafts/` 下的加密草稿與待上傳附件暫存）
- 搜尋索引資料庫
- 復原金鑰相關 metadata 與可信裝置設定
- 你主動建立的本機完整備份副本
- Google Drive 上傳期間建立的 App 私有暫存備份
- Google Drive 背景上傳的工作狀態與所屬帳號識別資訊；工作完成、取消或失敗清理後不再保留於該工作
- App 偏好設定與解鎖模式設定

上述資料的控制權在你。若你清除 App 資料或解除安裝 App，通常會一併移除 App 沙盒中的本機資料；但若你曾將檔案匯出到外部資料夾、Downloads 或 Google Drive，這些副本需要由你自行刪除。

## 4. Android 權限

本 App 的主 Android Manifest 直接宣告下列權限：

- **`android.permission.INTERNET`**：用於 Google Sign-In、Google Drive 備份，以及 Google Play Billing 商品查詢與付款流程
- **`android.permission.ACCESS_NETWORK_STATE`**：用於判斷網路狀態，讓同一次 Google Drive 背景上傳可在恢復連線後重試
- **`android.permission.USE_BIOMETRIC`**：用於可信裝置的生物辨識解鎖
- **`com.android.vending.BILLING`**：用於 App 內「支持開發者」的一次性 Google Play 購買流程
- **`android.permission.FOREGROUND_SERVICE`** 與 **`FOREGROUND_SERVICE_DATA_SYNC`**：僅在你主動備份到 Google Drive 後，用於以前景服務完成該次上傳
- **`android.permission.POST_NOTIFICATIONS`**：用於顯示 Google Drive 上傳進度（Android 13+）；開始上傳前會請求，拒絕時仍可能完成上傳，但通知抽屜可能不顯示進度與停止按鈕
- **`android.permission.WAKE_LOCK`**：僅在上傳執行期間持有，完成或中斷即釋放，避免裝置休眠中斷傳輸

建置時，生物辨識與 Billing 相關依賴另會合併 `android.permission.USE_FINGERPRINT` 等相容性權限。系統選檔與 Billing 服務的套件查詢不是聯絡人或廣泛檔案存取權限。

本 App 目前不要求相機、錄音或直接讀取整個媒體庫的權限。圖片與一般檔案附件是透過 Android 系統提供的選取流程取得。

## 5. 資料分享與第三方服務

除下列情況外，開發者不會向第三方分享你的日記內容：

- **你主動備份到 Google Drive**：備份 ZIP 會存放在你的 Google 帳號關聯空間，並受 Google 服務條款與隱私政策規範；ZIP 外層未另外加密，其中日記、附件與人物名冊為加密格式，但包含明文復原 metadata，以及存在時的標籤目錄與釘選項目 ID
- **你主動匯出資料**：例如匯出至本機資料夾、Downloads 或可攜式 Markdown/HTML 檔案；後續保存位置由你決定
- **依法配合**：若有適用法令、法院命令或有效法律程序要求，我們可能在法律允許範圍內配合；但本 App 預設不持有你的日記明文

### Google API 資料使用限制

本 App 從 Google API 取得的資訊只用於使用者可見的 Google 帳號連結、Google Drive 備份與還原功能，不用於廣告、使用者追蹤或其他無關用途，也不會傳送到開發者控制的伺服器。

本 App 對 Google API 資訊的使用與傳輸遵守 [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)，包括 Limited Use 要求。

與 Google 服務之間的傳輸使用 HTTPS。App 私有空間中的日記、附件、人物名冊、草稿與搜尋索引依前述方式加密；復原設定與部分輔助 metadata，以及完整備份 ZIP 外層，則不另行加密。

## 6. 資料保留與刪除

你可以透過下列方式管理或移除資料：

- 在 App 內刪除日記、人物、附件或草稿
- 刪除本機完整備份檔
- 刪除 Google Drive 上的備份 ZIP
- 清除 App 資料或解除安裝 App
- 中斷 Google Drive 連線

補充說明：

- 清除 App 資料或解除安裝後，通常會移除 App 沙盒內的日記庫（包含人物名冊）、草稿、索引與偏好資料
- 若你曾匯出檔案到外部資料夾、Downloads 或其他位置，這些副本需要由你自行刪除
- 若你曾上傳備份到 Google Drive，Drive 內副本也需要由你自行刪除
- 遠端完成驗證前的 Google Drive 上傳若因服務或程序異常終止，不會跨程序續傳；App 會清除對應的私有暫存備份，並在下次開啟時提示失敗
- 使用者主動停止上傳時會清除該次工作，不會另外建立失敗提示；若停止當下遠端傳輸尚未結束，App 可能先保留清理狀態，並在下次啟動時重試刪除未完成的遠端檔
- 若遠端檔案已完成驗證，App 會保留必要狀態，並在下次啟動或回到前景時繼續記錄成功結果與清理舊備份，不會重新上傳檔案

## 7. 兒童隱私

本 App 並非專為 13 歲以下兒童設計。我們不會故意蒐集兒童的個人資料。

## 8. 政策變更

我們可能因功能調整、法規更新或商店政策要求而更新本政策。若有重大變更，會更新本頁的生效日期；若 App 內有對應入口，也會同步調整相關說明。

## 9. 聯絡方式

若你對本政策或資料處理方式有疑問，請透過 GitHub Issues 聯絡：

<https://github.com/zack20136/quill-diary/issues>

GitHub Issues 預設為公開內容，請勿在問題中貼上日記內容、復原金鑰、備份檔、Google 帳號識別資訊或其他敏感資料。

---

[← 返回首頁](./index.md)
