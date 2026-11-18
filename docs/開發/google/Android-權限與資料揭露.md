# Android 權限與資料揭露

以[主 Manifest](../../../android/app/src/main/AndroidManifest.xml)及當次 release AAB 的 merged manifest 為準；依賴可能合併額外權限與套件查詢，勿引用舊 `build/` 產物。

## 主 Manifest 權限

| 權限 | 實際用途 | 授權方式 |
|------|------|------|
| `android.permission.INTERNET` | AI、Google Sign-In、Drive、Play Billing，含既有工作的對帳、清理與交易收尾 | 一般權限 |
| `android.permission.ACCESS_NETWORK_STATE` | Drive 上傳等待網路後重試 | 一般權限 |
| `android.permission.USE_BIOMETRIC` | 可信裝置與 session 重新驗證 | 一般權限；系統驗證視窗另行確認身分 |
| `com.android.vending.BILLING` | 一次性支持、Billing 可用性與未完成交易查詢 | Manifest 宣告；購買由 Play 確認 |
| `android.permission.FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_DATA_SYNC` | 使用者觸發後的 Drive dataSync 前景服務 | 一般權限；啟動及執行時間另受平台限制 |
| `android.permission.POST_NOTIFICATIONS` | 上傳進度與停止動作 | Android 13+ 執行時權限，上傳前檢查／請求 |
| `android.permission.WAKE_LOCK` | 上傳期間避免休眠，完成或中斷即釋放 | 一般權限 |

主 Manifest 不要求相機、錄音、`READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO`、`READ_EXTERNAL_STORAGE`、`WRITE_EXTERNAL_STORAGE` 或 `MANAGE_EXTERNAL_STORAGE`；鎖定的 `image_picker_android`、`android_file_picker`、`flutter_image_compress` 也未合併這些權限。

`image_picker` 的[鎖定版本](../../../pubspec.lock)在 API 36+ 使用 Photo Picker，較舊系統預設走 `ACTION_GET_CONTENT`。一般檔案走系統選檔，資料夾匯入只遞迴選定範圍，不掃描整個儲存空間。單次選取不需廣泛媒體權限；核心功能無法由挑選器完成時，才依 [Play 政策](https://support.google.com/googleplay/android-developer/answer/14115180)申請及宣告。

其他權限邊界：

- 聯絡人：不讀通訊錄，不需 `READ_CONTACTS`；日後單次選取使用系統挑選器。見[政策公告](https://support.google.com/googleplay/android-developer/answer/16926792)。
- 位置、簡訊與通話紀錄：無精確／背景位置、`READ_SMS`、`READ_CALL_LOG`；`dataSync` 服務只做手動備份，不做定位或地理圍欄。
- 區網：target API 36 使用 `INTERNET`，不新增 `NEARBY_WIFI_DEVICES` 或提前請求 `ACCESS_LOCAL_NETWORK`。升至 target API 37+ 時，須處理 Android 17 的 `ACCESS_LOCAL_NETWORK` 授權、拒絕與撤銷；HTTP、HTTPS 均受影響，網址驗證不能取代授權。見[區網權限](https://developer.android.com/privacy-and-security/local-network-permission)。
- 廣告 ID：目前無廣告。確認 release manifest 無 `com.google.android.gms.permission.AD_ID`；若 SDK 合併，移除該權限，Console 維持無廣告。

生物辨識由系統驗證，App 不取得指紋／臉部影像。`drive.appdata` 是獨立 OAuth scope，只授權 App 專用 Drive 空間，不授予整個 Drive、通訊錄或裝置儲存權限。

URI grant 僅涵蓋選定項目；content URI 複製分支會嘗試釋放 `AndroidPlatformFile.safHandle`，外部寫入 tree URI 不取得永久授權。選檔及暫存規則見[備份與還原](../功能/備份與還原.md#外部選檔與暫存)。升級套件須實機驗證挑選、Activity 重建與取消清理。

Android 13+ 拒絕通知仍可啟動前景服務；須建立通知，但通知抽屜不顯示，Task Manager 仍有提示。App 也檢查全 App／上傳頻道通知；不可見時可在設定頁 Google Drive 區塊查看進度並停止可取消的上傳。見[通知規則](https://developer.android.com/develop/ui/compose/notifications/notification-permission)與[備份驗收](../功能/備份與還原.md#背景上傳生命週期)。

依賴另合併 `androidx.biometric:biometric` 的 `USE_FINGERPRINT` 相容權限，以及 `androidx.core:core` 保護內部 receiver 的 `{applicationId}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`（signature）。兩者均不另跳執行時授權視窗；發布前以當次 manifest merger report 核對來源。

## 套件查詢與系統備份

`<queries>` 只控制套件可見性，不授予存取權限；涉及 PROCESS_TEXT、HTTP／HTTPS VIEW、GET_CONTENT 及 Billing service，以 merged manifest 核對。

`android:allowBackup="false"` 關閉雲端 Auto Backup，但 Android 12+ 部分廠牌仍可能允許裝置移轉。主 Manifest 已引用 `res/xml/backup_rules.xml` 與 `res/xml/data_extraction_rules.xml`，排除 file、database、sharedpref、root、external 及對應 device-protected 領域。前者供 Android 11 以下使用，後者分別設定 Android 12+ 的雲端備份與裝置移轉；兩種 XML 結構不同，須各自保留。系統備份與裝置移轉仍需在實機驗證。復原金鑰的複製按鈕及選取選單都由原生剪貼簿附加敏感標記。

## 網路傳輸

[`network_security_config.xml`](../../../android/app/src/main/res/xml/network_security_config.xml) 預設允許 cleartext，對 openai.com、anthropic.com、googleapis.com 關閉。AI 另由 `validateAiEndpoint` 在送憑證前限制：

- 內建雲端服務固定使用 HTTPS。
- Custom 的 HTTP 只接受 loopback、IPv4 私有網段及 IPv6 ULA，拒絕主機名稱、link-local 及公網 HTTP。
- 不跟隨重新導向，不略過 TLS 驗證。

target SDK 沿用 [Gradle](../../../android/app/build.gradle.kts) 的 Flutter 設定，升版時重查區網與 dataSync 限制。

## Play Console Data safety

依實際資料流填寫，不由權限清單直接推導。純本機處理不屬離機 collection；傳到第三方仍可能屬 collection。使用者主動傳送可能符合 sharing 例外，但不自動豁免 collection；發布時逐項核對[官方定義與例外](https://support.google.com/googleplay/android-developer/answer/10787469)。

| 資料流 | 揭露重點 |
|------|------|
| 本機日記、人物與索引 | 預設本機加密；人物名冊納入正式備份，分析 SQLite 為衍生快取 |
| AI | 分支對話、提示詞、圖片及認證資訊直接送指定服務；分身另含選取日記、匯入聊天、目前記憶／風格、中間證據與試聊 |
| AI 隱私與備份 | 代號不保證匿名，不遮蔽照片；完成聊天全分支與正式分身納入加密備份，分身草稿／匯入材料排除。遠端暫存清理不等於刪除全部紀錄 |
| Drive | ZIP 經 HTTPS 寫入 `appDataFolder`；外層未加密，含明文復原 metadata 與釘選 ID，歷史 ZIP 可能另含明文標籤，不能整份視為端對端加密豁免 |
| 生物辨識 | 系統驗證結果，不取得生物特徵原始資料 |
| 付款 | Play 處理付款；App 啟動即查詢 Billing 可用性與未完成交易，回呼含商品與交易識別，不保存永久權益 |
| HTTP 自訂服務 | 區網 HTTP 的文字、照片與憑證未加密，須納入傳輸加密判斷 |

細節見[隱私權政策](../../privacy-policy.md)、[AI](../功能/AI.md)及[備份生命週期](../功能/備份與還原.md#背景上傳生命週期)。

### 表單填寫依據

以下為填寫底稿，須涵蓋當次版本全部功能與 SDK；不代表已提交 Console，自備 Key 或無開發者伺服器也不代表無蒐集。

| 表單項目 | 本專案應採用的依據 |
|------|------|
| 蒐集／分享資料 | 列出 AI、Google 登入、Drive、Billing 及 SDK 離機資料，再套官方定義與例外 |
| 必要或可選 | AI 與 Drive 為選用功能；Billing 啟動查詢另行核對，不全屬點擊購買才發生。功能內必要欄位不等於全 App 必填 |
| 用途 | AI、備份與交易屬 App 功能；Google 連結另核對帳戶管理。主程式無廣告／行銷用途 |
| 暫時處理 | Files API 及服務商留存不等於僅記憶體處理；`store: false` 不保證零留存 |
| 資料分享例外 | 按實際揭露／同意核對使用者主動傳送的 sharing 例外，不能直接豁免 collection |
| 傳輸加密 | Google／內建 AI 用 HTTPS，Custom 可用區網 HTTP；核對第三方服務例外後才判斷是否勾選「全部」加密 |
| 刪除方式 | 按政策列出本機、Drive 與服務商管理方式；本機刪除不代表 AI 遠端已刪除 |
| 帳戶建立／刪除 | 本機建庫不是線上帳戶；Google 僅供選用 Drive，依表單核對第三方登入，不宣稱可刪除 Google 帳戶 |
| 安全認證 | 無獨立安全審查證據不勾選，自動測試不能當成認證 |

付款例外涵蓋服務直接取得、App 未存取的卡號等資料，交易回呼另核對。自有雲端備份例外要求 App 不蒐集／存取相關資料，本專案會建立及讀取備份，不能直接套用。

### 資料類型逐項核對

| 可能對應的 Console 類型 | 實際資料與核對範圍 |
|------|------|
| 其他使用者產生內容 | 上表 AI 文字與分身材料、Drive 備份內容與歷史 ZIP 的明文標籤等 metadata |
| 相片 | 送至 AI 的附圖；原圖留本機，傳送副本清理 metadata，但不遮蔽影像 |
| 檔案與文件 | Drive ZIP、交付外部的 Markdown／HTML／附件，按收件端與操作判斷 collection／sharing |
| 姓名、電子郵件地址、使用者 ID | Google 顯示名稱、Email、SDK 帳戶識別及文字中的身分資訊；代號不保證匿名 |
| 購買記錄 | Billing 回呼的商品與交易狀態，不因未保存永久權益就免核對 |
| 裝置或其他 ID、診斷、App 活動 | 主程式無分析／廣告後端，仍須逐一核對發布版 SDK |

聊天可能包含其他敏感資料；按當次 Console 分類、公開政策及服務商處理補齊，未知不填成已確認無蒐集。

## 發布核對

變更權限、Drive scope、後端／分析 SDK 或 Billing 型態時，同步公開政策與 Console。流程見[Google Play 上架](Google-Play-上架.md)。

1. 產生當次 release AAB，以 Android Studio／Play App Bundle Explorer 或同次 merged manifest 核對套件、版本、min／target SDK。
2. 比對全部權限、服務型態與 `queries`，追查主專案／依賴來源，保留必要設定。
3. 確認無意外相機、麥克風或廣泛儲存／媒體權限；確需新增時先完成揭露與審查。
4. 對齊 Data safety、dataSync declaration、政策及影片，保存該 AAB 核對結果。

官方參考：[SAF](https://developer.android.com/training/data-storage/shared/documents-files)、[套件可見性](https://developer.android.com/training/package-visibility/declaring)、[allowBackup](https://developer.android.com/guide/topics/manifest/application-element)、[前景服務逾時](https://developer.android.com/develop/background-work/services/fgs/timeout)。

[← 返回開發文件導覽](../README.md)
