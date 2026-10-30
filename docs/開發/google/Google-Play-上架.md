# Google Play 上架

這份文件整理 Quill Diary 目前影響 Google Play 上架的實作資訊與手動作業。內容以程式碼、Android 建置設定與公開文件為準，不保留無法從 repo 驗證的推測。

## 目前 App 基本事實

從程式碼可確認：

- 平台定位目前是 Android
- Android `applicationId`/`namespace`：`zack20136.com.quill_diary`
- `minSdk`：`30`
- `compileSdk` 與 `targetSdk` 跟 [`android/app/build.gradle.kts`](../../../android/app/build.gradle.kts) 的 Flutter 設定，目前都是 API 36；不在 Gradle 另寫死數字。送審前仍以該次 release merged manifest 為準
- 版本以 [`pubspec.yaml`](../../../pubspec.yaml) 的 `version:` 為準；送審前確認 `versionCode` 已遞增
- release 建置要求實體簽章設定，不允許用 debug signing 發 release

對應來源：

- [`android/app/build.gradle.kts`](../../../android/app/build.gradle.kts)
- [`pubspec.yaml`](../../../pubspec.yaml)

## 發布前準備

需備妥 Play Developer 帳號、upload keystore、`android/key.properties`、可用的 OAuth 設定、已啟用的支持商品，以及公開隱私政策。先讓 Play 測試軌道的安裝版完成實機驗收，再送正式版；新帳號適用的測試門檻與正式發布資格以 Console 顯示為準。

這份文件提供建置、商店文案與審查說明；Data safety 的逐項依據集中在[Android 權限與資料揭露](Android-權限與資料揭露.md#表單填寫依據)，OAuth 與商品操作分別見[Drive 設定](Google-Drive-OAuth-設定.md)、[Billing 設定](Google-Play-Billing.md)。

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

## 建置與產物核對

先依範本在本機建立 `android/key.properties`，確認 keystore 路徑及四個欄位可用；不要把 keystore、密碼或測試金鑰加入 Git。版本從 `pubspec.yaml` 的 `versionName+versionCode` 取得，也要檢查 CI 是否另外覆寫版本或 OAuth client ID。

Codex 在 repo 根目錄使用安全入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 pub get
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 analyze
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 test
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 build appbundle --release
```

預設 AAB 位於 `build/app/outputs/bundle/release/app-release.aab`。上傳前核對這次產物的套件名稱、版本、min／target SDK、簽章、權限與服務宣告。AAB 不能直接當 APK 安裝；從 Play 測試軌道安裝，才能驗證交付簽章、OAuth 與 Billing 的整合結果。保存本次 AAB、測試結果與 Console 宣告紀錄；不要拿舊 build 檔當作本次證據。

## 商店文字底稿

短說明：

> 本機加密日記，整理文字、圖片與人物；可選 AI 聊天寫作及手動備份。

完整說明可使用下列內容，再配合本次實機截圖與實際受眾調整：

> Quill Diary 讓您在裝置上記錄生活，使用標題、標籤、人物、搜尋與任務清單整理日記，並加入圖片及檔案附件。
>
> 日記庫在本機加密保存，可使用裝置驗證與復原金鑰管理存取。請妥善保存復原金鑰；開發者無法替您找回。完整備份可移轉日記庫，Markdown／HTML 匯出則便於自行保存與閱讀。
>
> AI 聊天寫作是可選功能，需要自行設定服務與 API Key，可能由服務商計費。目前分支的文字、提示詞及附圖會直接傳給您選擇的服務；文字隱藏不會遮蔽照片，也不保證匿名。生成結果可再編輯後儲存為日記。
>
> Google Drive 提供使用者手動啟動的完整備份與還原，不是跨裝置即時同步。Google Play 的一次性支持是自願購買，不含訂閱或額外功能。

不要宣稱所有功能完全離線、全部資料都不離機、AI 完全匿名或零留存。完整 ZIP 外層未加密且含部分明文 metadata，不能把「本機加密」延伸成所有匯出與所有傳輸都端對端加密。截圖只能使用合成日記、人物與圖片，不展示 API Key、復原金鑰或私人帳號。

## 隱私政策與公開連結

程式碼中的公開網址由 `AppIdentifiers` 維護，目前應對應到：

- 隱私政策：`https://zack20136.github.io/quill-diary/privacy-policy`
- 第三方授權：`https://zack20136.github.io/quill-diary/third-party-notices`

相關來源：

- [lib/shared/app_identifiers.dart](../../../lib/shared/app_identifiers.dart)
- [docs/privacy-policy.md](../../privacy-policy.md)

若變更 GitHub Pages 路徑、repo 名稱或對外 URL，必須一起檢查上述檔案與 Play Console 連結。

Play 的隱私政策要求 URL 可公開存取、非 PDF、不可由一般訪客編輯且不受地區限制；政策內容還要能識別 App/開發者、說明資料存取與分享方式、保護措施、保留與刪除方式及聯絡管道。不能只確認網址存在。

## 發布時核對的外部要求

自 2026 年 8 月 31 日起，手機 App 的新提交與更新必須 target Android 16（API 36）。本專案目前由 Flutter 帶入的 compile／target 已是 API 36，符合這個送審門檻，不必申請延到 2026 年 11 月 1 日。下一個年度的 API 門檻不寫進 repo；送審當天仍核對官方 [target API 時程](https://support.google.com/googleplay/android-developer/answer/11926878)，並以該次 release merged manifest 為準。

開發者驗證不是程式設定。到 Play Console 首頁確認本 App 已註冊；Play 上多數 App 會自動註冊，沒有註冊的要手動完成，否則可能從商店下架。2026 年 9 月 30 日起，巴西、印尼、新加坡、泰國的參與商店開始要求驗證；全球擴大是 2027。依據見[開發者驗證／套件註冊](https://support.google.com/googleplay/android-developer/answer/16984799)。

權限政策不需要改 Manifest。相片與影片、聯絡人、位置、簡訊與通話紀錄都沒有廣泛存取；圖片與檔案走系統挑選器。Console 若詢問相片／影片廣泛存取，回答不需要，不要提交 `READ_MEDIA_IMAGES` 或 `READ_MEDIA_VIDEO` 宣告。廣告宣告維持沒有廣告。對照與不要新增的權限見[Android 權限與資料揭露](Android-權限與資料揭露.md#主-manifest-權限)。

發布軌道、地區、相容性及帳號政策仍以 Console 顯示為準，無法只從 repo 判定。

## App content 與審查資料

| 項目 | 本版填寫與交付依據 |
|------|------|
| 隱私政策 | 使用上節公開 URL，確認 App 內連結與 Google OAuth consent screen 一致 |
| Data safety | 使用權限文件的資料流與分類表；包含 AI、Drive、Google Sign-In、Billing 及發布版 SDK |
| App access | 一般日記不需線上帳號；Drive 與 AI 有外部憑證／授權條件，依下節提供完整審查存取 |
| 廣告 | 主程式目前沒有廣告功能；發布前核對 SDK 與產物，不因 Google Play Billing 就填成廣告 |
| 目標對象與內容分級 | 依真實目標年齡、AI 對話與內容能力回答，不在文件預填分級結果。公開政策不是專為 13 歲以下設計，不能因此宣稱已符合 Families 要求 |
| AI 生成內容 | 依下節檢查回報入口與受限制內容防護；自備 API Key 不代表政策自動豁免 |
| Foreground service | 宣告 dataSync、備份用途、延後／中斷影響，提供能實際重現的示範影片 |
| App 內商品 | 五項一次性支持，沒有訂閱或功能解鎖，商品已啟用且可在測試版查詢 |

### App access 與審查操作說明

不要只填「所有功能無限制」：本機日記可直接使用，但 Drive 需要 Google 登入及授權，AI 需要可連線的服務與模型。依 [App access 官方要求](https://support.google.com/googleplay/android-developer/answer/15748846)，在 Console 提供審查所需帳號與清楚操作方式；測試憑證須能在審查期間持續使用，不受一次性驗證、地區或短期到期阻擋。

本機功能的操作順序：

1. 完成功能介紹，選「建立新的日記庫」，在設定建立並保存本次產生的復原金鑰。這是裝置上的加密日記庫，不是註冊開發者線上帳號。
2. 返回首頁，新增合成日記，測試標題、標籤、圖片、任務清單、正式儲存、搜尋與編輯。
3. 設定解鎖方式後鎖定，再以裝置驗證或剛保存的復原金鑰解鎖。不能提供另一個日記庫的固定金鑰作為本機通用密碼。
4. 在設定建立本機備份，修改合成日記後還原，確認使用建立該備份時的金鑰。
5. 連結審查可用的 Google 帳號並同意 Drive appdata 授權，測試上傳、通知、停止及還原。審查帳號與存取安排填在 Console，不能寫入 repo。
6. 在 AI 設定填入審查用服務、Base URL（Custom 才需要）、協定、模型與 API Key，測試連線後從首頁新增入口開始聊天，附圖、生成日記並正式儲存。
7. 開啟「支持開發者」，確認商品與 Play 購買介面；購買不是使用其他功能的前置條件。

AI 審查服務應使用受控測試專案、無私人資料且有足夠額度；區網／loopback 服務通常無法供遠端審查使用。送審期間不要撤銷審查金鑰或關閉端點，完成後再撤銷。Google OAuth 若仍只允許指定測試帳號，須讓審查帳號可完成授權，或先完成適用的正式發布設定。

下列英文底稿需與 Console 專用欄位的實際 Google／AI 存取資料一起提交；它不是已提供憑證的證明：

> Quill Diary stores an encrypted diary locally. No developer account or purchase is required for local diary features. On first launch, finish the introduction, choose Create a new vault, and create and save the generated recovery key in Settings. Return home to create, edit and search test entries. Use this generated key when testing recovery.
>
> Google Drive backup is optional. Use the review account information supplied in App access, connect Google Drive in Settings, grant appdata access, then upload a backup. The upload has a progress notification and a Stop action. Restore uses the recovery key associated with that backup.
>
> AI writing is optional. Use the review provider, endpoint, protocol, model and API key supplied in App access. Test the connection in AI settings, start a chat from the home creation menu, send synthetic text or an image, generate a diary and save it. One-time support purchases do not unlock features.

### AI 生成內容的送審缺口

Google Play 的 [AI 生成內容政策](https://support.google.com/googleplay/android-developer/answer/13985936)要求適用 App 有 App 內內容回報／標記機制，並防止產生受限制內容。目前 repo 的聊天功能未提供這種回報入口；外開 GitHub Issues 不能直接寫成已具備 App 內回報。

因此，這一項尚未完成送審條件核對。提交含聊天功能的版本前，需確認適用範圍並完成所需回報及內容防護、驗證回報處理流程，再同步資料揭露。若回報會傳送聊天內容，必須讓使用者確認範圍，不能外送未經同意的整份私密日記或原圖；也不能僅以服務商可能過濾內容替代 App 的政策檢查。

## Foreground service（dataSync）declaration

target Android 14（API 34）以上並使用 `FOREGROUND_SERVICE_DATA_SYNC` 時，Play Console 需要 foreground service declaration。本 App 對應：

- FGS type：`TYPE_DATA_SYNC`
- Use case：`Network transfer: Backup and restore`
- 功能描述：使用者手動建立備份 ZIP（內含加密 vault 與部分明文 metadata），並上傳至 Google Drive `appDataFolder`；不是排程或常駐背景同步
- 為何不可任意延後：使用者剛建立的備份需儘快送達其 Drive，否則其他裝置/重裝後無法立刻還原
- 中斷影響：同一 FGS 存活期間可在網路恢復後自動重試。遠端完成驗證前若使用者停止、dataSync 額度逾時、服務或程序異常終止，先進入 `CANCEL_CLEANUP_PENDING` 對帳（已完成則記錄成功，否則清殘檔），不建立失敗提示；對帳完成前不能開始新的上傳。已進入 `STATUS_PENDING` 或 `PRUNE_PENDING` 則保留供 App 收尾。授權失效、重試耗盡或無法啟動前景服務仍提示失敗並需重新備份。Android 15+（target API 35+）的 dataSync 共用額度用盡也會終止尚未遠端驗證完成的上傳。細節見 [../功能/備份與還原.md](../功能/備份與還原.md)
- 示範影片建議內容：連結 Google Drive → 點上傳 → 顯示進度通知 → 切換到其他 App → 通知仍在更新 → 按停止或完成後返回 App

官方也建議部分使用者主動網路傳輸改用 User-Initiated Data Transfer job。本版保留 dataSync FGS，declaration 需對齊「使用者主動觸發、即時顯示進度、可從通知列停止；遠端完成驗證前若程序中斷，會對帳後保留成功或清除殘檔，不跨程序續傳」。

### Declaration 文字與影片

可依 Console 各欄位分別貼入以下底稿，不要把內部狀態代碼當作面向審查者的唯一解釋：

| 欄位 | 說明底稿 |
|------|------|
| 使用的功能 | 使用者在設定手動要求將日記庫完整備份上傳至自己的 Google Drive appDataFolder。前景服務只負責已交接的備份上傳 |
| 延後啟動的影響 | 使用者無法即時取得剛建立的雲端備份，換機或重裝前必須等待上傳確認完成；App 因而在操作後立即啟動並顯示進度 |
| 中斷的影響 | 中斷前若尚未驗證遠端完成，App 對帳後保留已完成備份或刪除未完成殘檔；不宣稱跨程序續傳。未成功備份時須重新操作 |
| 使用者控制 | 功能由使用者按鈕觸發；通知列顯示進度與停止。完成、取消或系統終止後依生命週期收尾，不常駐排程同步 |

影片腳本：以送審版本及合成日記開始 → 設定連結 Google Drive → 使用者點上傳 → 拍到進度通知 → 切到其他 App 顯示仍在上傳 → 回到 App 顯示完成。另示範第二次上傳從通知按停止，拍到清理完成及可重新操作。過程不要揭露金鑰或私人帳號；連結必須能讓審查者直接觀看，不需另外申請權限。

影片錄製與網址是發布時的實際產物，repo 無法預先虛構；提交前將真實影片連結填入 Console。官方欄位與示範要求見 [FGS declaration 說明](https://support.google.com/googleplay/android-developer/answer/13392821)。

## 發行版授權檢查

依鎖定套件版本與建置輸出確認第三方授權。Flutter 會將套件的 LICENSE 彙入 asset bundle 供 [LicenseRegistry](https://api.flutter.dev/flutter/foundation/LicenseRegistry-class.html) 使用；官方沒有 `flutter pub licenses` 指令。對外摘要使用[第三方聲明](../../third-party-notices.md)，不要把工具操作寫進公開法律頁。

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
13. 檢查商店文案符合 AI 自備服務／金鑰、Drive 手動備份與 Billing 一次性支持的實作
14. 核對第三方授權資訊及公開頁連結
15. 提交可用的 App access 憑證與操作說明，確認 AI／Google 功能不會卡在登入、額度或地區限制
16. 完成 AI 內容政策缺口核對，依真實功能填寫目標對象、內容分級及廣告宣告
17. 檢查測試軌道安裝版的首次啟動、鎖定還原、備份、AI、圖片與交易；確認 Console 沒有未完成的必要宣告

當次送審 AAB 的 release merged manifest 是該產物版本與權限的最終核對來源；`build/` 中舊產物不能代表目前 `pubspec.yaml`。若 Play 商店頁面或版本不可見，仍需另外到 Play Console 檢查發布軌道、國家/地區、裝置相容性與政策狀態；這些外部狀態無法只從 repo 判定。

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
