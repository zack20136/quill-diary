# Android 權限與資料揭露

權限來源是[主 Manifest](../../../android/app/src/main/AndroidManifest.xml)與當次 release AAB 的 merged manifest。依賴可能合併額外權限與套件查詢，舊 `build/` 產物不能代表目前原始碼。

## 主 Manifest 權限

| 權限 | 實際用途 |
|------|------|
| `android.permission.INTERNET` | 使用者設定的 AI、Google Sign-In、Drive 與 Play Billing |
| `android.permission.ACCESS_NETWORK_STATE` | Drive 上傳等待網路後重試 |
| `android.permission.USE_BIOMETRIC` | 可信裝置與 session 重新驗證 |
| `com.android.vending.BILLING` | 一次性支持購買 |
| `android.permission.FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_DATA_SYNC` | 使用者觸發後的 Drive dataSync 前景服務 |
| `android.permission.POST_NOTIFICATIONS` | Android 13+ 上傳進度與停止動作；拒絕仍可上傳，但通知抽屜可能不顯示 |
| `android.permission.WAKE_LOCK` | 上傳期間避免休眠，完成或中斷即釋放 |

主 Manifest 不要求相機、錄音、`READ_MEDIA_IMAGES`、`READ_EXTERNAL_STORAGE` 或 `WRITE_EXTERNAL_STORAGE`。圖片使用 `image_picker`，一般檔案使用系統選檔，只處理使用者選取項目，不掃描整個相簿或儲存空間。材料化與授權釋放見[備份與還原](../功能/備份與還原.md#外部選檔與-materialize)。

生物辨識權限不代表 App 能讀取指紋或臉部影像；驗證由系統處理。選檔取消不應留下附件；選到的 URI／暫存檔只供本次操作，使用後釋放 grant。維護 `file_picker` 或 `image_picker` 版本時，除了 widget 測試，仍要在 Android 驗證系統挑選、Activity 重建及取消後清理。

Android 13+ 通知權限可被拒絕。上傳服務仍須依平台規則啟動前景服務，App 不能以未顯示通知抽屜推論服務沒有執行。通知的進度、停止與帳號清理狀態，依[備份生命週期](../功能/備份與還原.md#背景上傳生命週期)驗收。

依賴可合併生物辨識相容權限 `USE_FINGERPRINT` 與 AndroidX 的 `{applicationId}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`；後者為內部 signature 權限。發布前仍須核對當次產物。

## 套件查詢與系統備份

`<queries>` 是套件可見性設定，不授予執行時權限。主設定與依賴涉及 PROCESS_TEXT、HTTP／HTTPS VIEW、GET_CONTENT，以及 Billing service 查詢；以 merged manifest 確認實際集合。

`android:allowBackup="false"` 關閉 Android 雲端 Auto Backup；Android 12+ 部分裝置廠牌仍可能允許裝置到裝置移轉，不能宣稱此屬性阻擋所有搬機路徑。

## 網路傳輸

[`network_security_config.xml`](../../../android/app/src/main/res/xml/network_security_config.xml) 的 base 允許 cleartext，只對 openai.com、anthropic.com、googleapis.com 關閉。自訂 AI 區網 IP 無法靜態列舉，實際限制由 `validateAiEndpoint` 在送出憑證前執行：

- 內建雲端服務固定使用 HTTPS。
- Custom 的 HTTP 只接受 loopback、IPv4 私有網段及 IPv6 ULA，拒絕主機名稱、link-local 及公網 HTTP。
- 不跟隨重新導向，不略過 TLS 驗證。

target SDK 由 [Gradle](../../../android/app/build.gradle.kts) 的 Flutter 設定提供；調整 target SDK 時一併核對 Android 區網存取與前景服務要求。

## Play Console Data safety

資料與實作邊界如下；表單分類、collection／sharing 定義及例外，發布當天重新核對[官方說明](https://support.google.com/googleplay/android-developer/answer/10787469)。使用者主動操作不等於 collection 全面豁免。

| 資料流 | 揭露重點 |
|------|------|
| 本機日記、人物與索引 | 預設在裝置加密處理；人物名冊屬正式備份資料，人物分析 SQLite 為衍生快取 |
| AI 聊天 | 目前分支、提示詞、圖片及認證資訊直接送到使用者選定服務，須依內容與服務核對 collection／sharing |
| AI 隱藏與留存 | 文字代號不保證匿名，不遮蔽照片；完成聊天的所有分支納入完整備份，遠端暫存清理不代表服務商刪除全部紀錄 |
| Drive | ZIP 經 HTTPS 寫入 `appDataFolder`；ZIP 外層未加密，含明文 recovery metadata、標籤與釘選 ID，不能把整份上傳視為端對端加密例外 |
| 生物辨識 | 系統驗證結果，不取得生物特徵原始資料 |
| 付款 | 由 Google Play 處理，App 不保存付款憑證或永久權益 |
| HTTP 自訂服務 | 區網 HTTP 的文字、照片與憑證未加密；填寫傳輸加密答案時必須揭露這條路徑 |

完整資料揭露見[隱私權政策](../../privacy-policy.md)。AI 資料流程見[AI 聊天日記](../功能/AI-聊天日記.md)，Drive 上傳、取消及清理狀態見[備份與還原](../功能/備份與還原.md#背景上傳生命週期)。

### 表單填寫依據

以下是依 repo 資料流整理的填寫底稿，不代表已提交到 Console。應以當次版本的全部功能與依賴判定，不能因「沒有開發者伺服器」或「使用者自備金鑰」就直接填成完全不蒐集資料。

| 表單項目 | 本專案應採用的依據 |
|------|------|
| 蒐集／分享資料 | 先列 AI、Google 登入、Drive、Billing 與其 SDK 的離機資料，再套官方定義及例外；純本機加密處理不列成遠端蒐集 |
| 必要或可選 | 一般日記可不連 Google、不用 AI、不購買；相關離機資料可依可選功能填寫，不能把功能內必要欄位誤寫成全 App 必填 |
| 用途 | AI 生成、Drive 備份與交易收尾對應 App 功能；Google 帳號連結另核對帳號管理。主程式沒有將這些資料用於廣告或行銷 |
| 暫時處理 | 遠端 Files API 與服務商留存不能只視為記憶體內暫時處理；`store: false` 也不是零留存保證 |
| 資料分享例外 | 使用者明確啟動的第三方傳送可能符合 sharing 例外，仍須對照實際揭露／同意；不會自動排除 collection |
| 傳輸加密 | Google 與內建 AI 使用 HTTPS，Custom 可用區網 HTTP。官方另有使用者連結其他服務的說明；未確認適用例外前，不能只依 HTTPS 路徑勾選「全部」加密 |
| 刪除方式 | 依公開政策列出本機刪除、Drive 備份刪除及服務商管理方式；本機刪除不等於已刪除 AI 遠端紀錄 |
| 帳號建立／刪除 | 本機建庫與復原金鑰不是開發者線上帳號，Google 登入用於可選 Drive。依當次表單確認第三方登入的適用性，不宣稱 App 可以刪除 Google 帳號 |
| 安全認證 | 沒有獨立安全驗證證據，不勾選已通過獨立安全審查；自動測試通過不能當成認證 |

### 資料類型逐項核對

| 可能對應的 Console 類型 | 實際資料與核對範圍 |
|------|------|
| 其他使用者產生內容 | AI 的聊天文字、提示詞、生成請求；Drive 明文標籤等 metadata。不能只因正文加密就忽略 ZIP 其他內容 |
| 相片 | 使用者附加並送至 AI 的圖片；原圖仍留本機，傳送副本清理 metadata，不遮蔽影像內容 |
| 檔案與文件 | Drive 完整備份，以及使用者交付至外部位置的 Markdown／HTML／附件；依收件端與實際操作判斷 collection／sharing |
| 姓名、電子郵件地址、使用者 ID | Google 登入的顯示名稱、Email 與 SDK 帳號識別；使用者在文字中主動提供的身分資料也不能由隱私代號保證消失 |
| 購買記錄 | Billing 回呼的商品與交易狀態。App 不保存永久權益，仍要確認套件／Google Play 的實際處理 |
| 裝置或其他 ID、診斷、App 活動 | 主程式沒有自建分析／廣告後端；仍須逐一核對發布版 SDK，不能僅憑本機日記定位替依賴填「無」 |

自由輸入的聊天可能包含其他敏感資料，這張表不代表只需勾選這些類型。最後答案要與 Console 當下分類、對外政策和實際提供商處理一致；不要把未知項目當作已確認不蒐集。

## 發布核對

新增權限、變更 Drive scope、導入後端／分析 SDK 或改變 Billing 型態時，同步校正公開政策與 Play Console。以當次 AAB 核對套件名稱、版本、min／target SDK、全部權限及 `<queries>`；上架流程見[Google Play 上架](Google-Play-上架.md)。

1. 重新產生本次 release AAB，再使用 Android Studio／Play App Bundle Explorer 檢查 Manifest；若讀本機 merged manifest，先確認檔案來自同一次建置。
2. 把全部 `uses-permission`、服務型態、`queries` 與上表比對，追查新增項目來自主專案還是哪個套件。不要刪除套件必要設定只為縮短清單。
3. 確認沒有意外新增相機、麥克風、廣泛儲存或媒體庫權限；若功能真的需要新增，先完成對應使用者揭露與 Play 權限審查。
4. 同步檢查 Data safety、dataSync declaration、隱私政策及審查影片，並保留該 AAB 的權限核對結果。

官方參考：[SAF](https://developer.android.com/training/data-storage/shared/documents-files)、[套件可見性](https://developer.android.com/training/package-visibility/declaring)、[allowBackup](https://developer.android.com/guide/topics/manifest/application-element)、[前景服務逾時](https://developer.android.com/develop/background-work/services/fgs/timeout)。

[← 返回開發文件導覽](../README.md)
