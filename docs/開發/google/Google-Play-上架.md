# Google Play 上架

本文件是 Google Play 建置、Console 宣告與審查的入口，以程式碼、Android 設定及公開文件為準。

## 目前 App 基本事實

- 平台定位目前是 Android
- Android `applicationId`/`namespace`：`zack20136.com.quill_diary`
- `minSdk`：`30`
- `compileSdk`／`targetSdk` 沿用 [Gradle](../../../android/app/build.gradle.kts) 的 Flutter 設定，目前皆 API 36；送審以當次 release merged manifest 為準
- 版本以 [`pubspec.yaml`](../../../pubspec.yaml) 的 `version:` 為準；送審前確認 `versionCode` 已遞增
- release 建置要求實體簽章設定，不允許用 debug signing 發 release

## 發布前準備

備妥 Play Developer 帳戶、upload keystore、`android/key.properties`、OAuth、已啟用商品與公開隱私政策。先完成 Play 測試軌道實機驗收；新帳戶測試門檻與發布資格依 Console。

細節見[權限與 Data safety](Android-權限與資料揭露.md#表單填寫依據)、[Drive OAuth](Google-Drive-OAuth-設定.md)及 [Billing](Google-Play-Billing.md)。

## Release 簽章規則

依[範本](../../../android/key.properties.example)建立 `android/key.properties`，填妥 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`；任一缺漏都會使 release 任務失敗。

本機以 upload key 簽署 AAB；Play App Signing 另用 app signing key 簽署交付 APK。OAuth 須登記實際安裝版本的 SHA-1，兩者不能混用。

## 建置與產物核對

確認 keystore 路徑可用，勿將 keystore、密碼或測試金鑰加入 Git。版本來自 `pubspec.yaml`，另檢查 CI 的版本與 OAuth client ID 覆寫。

Codex 在 repo 根目錄使用安全入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 pub get
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 analyze
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 test
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 build appbundle --release
```

產物為 `build/app/outputs/bundle/release/app-release.aab`。核對套件、版本、SDK、簽章、權限、服務及 `queries`，保存 AAB、測試與 Console 紀錄。AAB 不能直接安裝；以 Play 測試軌道驗證交付簽章、OAuth 與 Billing，勿引用舊 build 作為當次證據。

## 商店文字底稿

短說明：

> 本機加密日記，整理文字、圖片與人物；可選 AI 聊天寫作及手動備份。

完整文案與圖片說明集中在[商店素材](../../play-store-assets/store-listing.md)，送審時須涵蓋：

- 本機加密與復原金鑰責任；完整備份可移轉，Markdown／HTML 為可閱讀匯出。
- AI 自備服務與 Key、可能計費、資料直接外送；分身另含選取日記、匯入聊天、人物記憶、風格與試聊。文字隱藏不處理照片，也不保證匿名或零留存。
- 正式分身納入加密完整備份，未完成更新與匯入材料排除；ZIP 外層及部分 metadata 未加密。
- Drive 為手動備份而非即時同步；一次性支持無訂閱或功能解鎖。

勿宣稱完全離線、資料全不離機或所有匯出／傳輸皆端對端加密。截圖只用合成資料，不展示金鑰或私人帳戶。

## 隱私政策與公開連結

公開網址由 [`AppIdentifiers`](../../../lib/shared/app_identifiers.dart) 維護：

- 隱私政策：`https://zack20136.github.io/quill-diary/privacy-policy`
- 第三方授權：`https://zack20136.github.io/quill-diary/third-party-notices`

變更 Pages 路徑、repo 名稱或 URL 時，同步[隱私政策](../../privacy-policy.md)與 Console。政策須公開、非 PDF、不可由訪客編輯、不受地區限制，並載明 App／開發者、資料處理與分享、保護、保留刪除及聯絡方式。

## 發布時核對的外部要求

2026 年 8 月 31 日起，手機 App 新提交與更新須 target API 36；目前 Flutter 設定符合。送審時仍核對官方 [target API 時程](https://support.google.com/googleplay/android-developer/answer/11926878)及當次 release merged manifest。

開發者驗證與套件註冊不是程式設定，且須分開看兩項要求：

- **Play 套件註冊**：2026 年 9 月 30 日起適用所有 Play 套件，未註冊可能遭下架。至 Play Console 確認身分驗證與套件狀態；未自動完成者須手動註冊。見[套件註冊要求](https://support.google.com/googleplay/android-developer/answer/16984799)。
- **裝置端安裝保護**：2026 年 9 月 30 日起，先於巴西、印尼、新加坡、泰國的參與商店及認證 Android 7+ 裝置實施，2027 年再擴大；此時程不豁免 Play 套件註冊。見[Android 驗證時程](https://developer.android.com/developer-verification)。

目前無廣告，也不需相片／影片廣泛存取宣告；圖片與檔案走系統挑選器。其他敏感權限及 Manifest 核對見[權限文件](Android-權限與資料揭露.md#主-manifest-權限)。

發布軌道、地區、相容性及帳戶政策仍以 Console 顯示為準，無法只從 repo 判定。

## App content 與審查資料

| 項目 | 填寫與交付依據 |
|------|------|
| 隱私政策 | 使用上節公開 URL，確認 App 內連結與 Google OAuth consent screen 一致 |
| Data safety | 使用權限文件的資料流與分類表；包含 AI、Drive、Google Sign-In、Billing 及發布版 SDK |
| App access | 一般日記不需線上帳戶；Drive 與 AI 有外部憑證／授權條件，依下節提供完整審查存取 |
| 廣告 | 主程式目前沒有廣告功能；發布前核對 SDK 與產物，不因 Google Play Billing 就填成廣告 |
| 目標對象與內容分級 | 依真實目標年齡、AI 對話與內容能力回答，不在文件預填分級結果。公開政策不是專為 13 歲以下設計，不能因此宣稱已符合 Families 要求 |
| AI 生成內容 | 依下節檢查回報入口與受限制內容防護；自備 API Key 不代表政策自動豁免 |
| Foreground service | 宣告 dataSync、備份用途、延後／中斷影響，提供能實際重現的示範影片 |
| App 內商品 | 五項一次性支持，沒有訂閱或功能解鎖，商品已啟用且可在測試版查詢 |

### App access 與審查操作說明

本機日記可直接使用，Drive／AI 仍需帳戶、授權或服務憑證。依 [App access 要求](https://support.google.com/googleplay/android-developer/answer/15748846)在 Console 提供英文操作說明與可重複使用、無地區／一次性驗證／短期到期限制的存取資料，勿只填「所有功能無限制」。

本機功能的操作順序：

1. 完成介紹，選「建立新的日記庫」，在設定建立並保存本次復原金鑰；不需註冊開發者帳戶。
2. 返回首頁，新增合成日記，測試標題、標籤、圖片、任務清單、正式儲存、搜尋與編輯。
3. 設定解鎖方式、鎖定後重新驗證。復原測試使用本庫金鑰，不能用其他日記庫的金鑰當通用密碼。
4. 在設定建立本機備份，修改合成日記後還原，確認使用建立該備份時的金鑰。
5. 連結審查用 Google 帳戶並授權 appdata，測試上傳、通知、停止及還原；通知拒絕／頻道關閉時改由設定頁查看與停止。帳戶資料只填 Console。
6. 在 AI 設定填入審查用服務、Base URL（Custom 才需要）、協定、模型與 API Key，測試連線後從首頁新增入口開始聊天，附圖、生成日記並正式儲存。
7. 開啟「支持開發者」，確認商品與 Play 購買介面；購買不是使用其他功能的前置條件。

AI 使用無私人資料、額度充足的受控測試專案及遠端可連端點，送審期間維持 Key 有效，完成後撤銷。OAuth 須允許審查帳戶授權，或先完成正式發布設定；區網／loopback 通常無法供遠端審查。

以下英文底稿須搭配 Console 欄位中的實際 Google／AI 存取資料：

> Quill Diary stores an encrypted diary locally. No developer account or purchase is required for local diary features. On first launch, finish the introduction, choose Create a new vault, and create and save the generated recovery key in Settings. Return home to create, edit and search test entries. Use this generated key when testing recovery.
>
> Google Drive backup is optional. Use the review account information supplied in App access, connect Google Drive in Settings, grant appdata access, then upload a backup. Allow notifications to see progress and a Stop action. If notifications are disabled, view progress and stop an active upload in the Google Drive section of Settings. Restore uses the recovery key associated with that backup.
>
> AI writing is optional. Use the review provider, endpoint, protocol, model and API key supplied in App access. Test the connection in AI settings, start a chat from the home creation menu, send synthetic text or an image, generate a diary and save it. One-time support purchases do not unlock features.

### AI 生成內容的送審缺口

Google Play 的 [AI 生成內容政策](https://support.google.com/googleplay/android-developer/answer/13985936)要求適用 App 有 App 內內容回報／標記機制，並防止產生受限制內容。目前 repo 的聊天功能未提供這種回報入口；外開 GitHub Issues 不能直接寫成已具備 App 內回報。

送審前須確認適用範圍、補齊所需回報與內容防護並驗證流程；服務商過濾不能取代 App 的政策檢查。回報若外送聊天或圖片，須由使用者確認範圍並同步資料揭露。

## Foreground service（dataSync）declaration

target API 34+ 並使用 `FOREGROUND_SERVICE_DATA_SYNC` 須提交 declaration。目前為 `TYPE_DATA_SYNC`，use case 為 `Network transfer: Backup and restore`，實際說明見下表。

同一服務存活期間可在網路恢復後重試；遠端驗證前的停止、系統逾時或程序中斷先對帳，保留已完成檔或清殘檔，不建立失敗提示，也不跨程序續傳；對帳完成前不能新上傳。驗證後保留成功收尾狀態；授權失效、重試耗盡或 FGS 啟動失敗仍須提示並重新備份。額度及內部狀態見[備份生命週期](../功能/備份與還原.md#背景上傳生命週期)。後續若改用官方建議的 User-Initiated Data Transfer job，再同步 declaration。

### Declaration 文字與影片

依 Console 欄位填入以下底稿：

| 欄位 | 說明底稿 |
|------|------|
| 使用的功能 | 使用者手動將完整備份 ZIP（加密日記庫及部分明文 metadata）上傳至自己的 Drive appDataFolder，前景服務只負責交接後上傳 |
| 延後啟動的影響 | 使用者無法即時取得剛建立的雲端備份，換機或重裝前必須等待上傳確認完成；App 因而在操作後立即啟動並顯示進度 |
| 中斷的影響 | 中斷前若尚未驗證遠端完成，App 對帳後保留已完成備份或刪除未完成殘檔；不宣稱跨程序續傳。未成功備份時須重新操作 |
| 使用者控制 | 功能由使用者按鈕觸發；App 內顯示進度並可停止，通知可用時也提供進度與停止。通知處理見[權限文件](Android-權限與資料揭露.md)。完成、取消或系統終止後依生命週期收尾，不常駐排程同步 |

影片使用送審版與合成資料：連結 Drive → 點上傳 → 顯示通知 → 切換 App 仍有進度 → 回 App 顯示完成；另示範通知停止、清理完成及可重新操作。勿揭露金鑰／私人帳戶，將免申請權限即可觀看的真實影片 URL 填入 Console。見 [FGS declaration 要求](https://support.google.com/googleplay/android-developer/answer/13392821)。

## 發行版授權檢查

依鎖定套件版本與建置輸出確認第三方授權。Flutter 會將套件的 LICENSE 彙入 asset bundle 供 [LicenseRegistry](https://api.flutter.dev/flutter/foundation/LicenseRegistry-class.html) 使用；官方沒有 `flutter pub licenses` 指令。對外摘要使用[第三方聲明](../../third-party-notices.md)，不要把工具操作寫進公開法律頁。

## 建議送審檢查清單

1. 確認版本遞增、套件名稱及 release 簽章，產出本次 AAB；Manifest 核對見[權限文件](Android-權限與資料揭露.md#發布核對)。
2. 確認開發者驗證、套件註冊與 Console 必要宣告均完成。
3. 核對公開法律頁、第三方授權與 OAuth consent screen，保留 Google API Limited Use 聲明。
4. 依[權限文件](Android-權限與資料揭露.md)更新 Data safety；依實際功能填寫目標對象、內容分級與廣告宣告。
5. 依 [OAuth](Google-Drive-OAuth-設定.md) 與 [Billing](Google-Play-Billing.md) 文件驗證 App Signing SHA-1、授權、商品及交易。
6. 提交 dataSync declaration、示範影片及可用的英文 App access 憑證／說明。
7. 核對 AI 內容回報與防護缺口，以及商店文案中的外送、備份與支持說明。
8. 用測試軌道安裝版驗收首次啟動、鎖定、還原、備份、AI、圖片與交易，保存結果。

商店頁面或版本不可見時，另查 Console 的軌道、國家／地區、裝置相容性與政策狀態，repo 無法判定這些外部設定。

## 官方規範參考

- [Google Play target API 時程](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Google Play 套件名稱註冊](https://support.google.com/googleplay/android-developer/answer/16984799)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Google Play 使用者資料與隱私政策](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Google Play App access](https://support.google.com/googleplay/android-developer/answer/15748846)
- [相片與影片權限](https://support.google.com/googleplay/android-developer/answer/14115180)
- [2026-04-15 政策公告](https://support.google.com/googleplay/android-developer/answer/16926792)

---

[返回開發文件索引](../README.md)
