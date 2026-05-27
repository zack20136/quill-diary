# Google Play 上架指南

最後確認日期：2026-05-27  
適用對象：準備把 Android App 上架到 Google Play 的個人開發者或小型團隊

## 先講結論

- 可以用你個人的 Google 帳號建立 Play Console 開發者帳號。
- 如果你是個人名義上架，選 `Personal` 帳號即可。
- 如果你是公司、工作室、商業品牌，或提供特定高風險服務，應改用 `Organization` 帳號。
- 新的個人帳號在正式上架前，通常必須先完成封閉測試門檻，不能一建立帳號就直接上 Production。
- 新 app 上架 Google Play，應以 `Android App Bundle (.aab)` 為主，不是 APK。
- release 簽章金鑰一定要保管好；如果你未來要更新同一個 app，簽章鏈不能亂換。

## 你可以用個人帳號嗎

可以。Google Play 官方有兩種開發者帳號：

- `Personal`
- `Organization`

`Personal` 適合：

- 個人作品
- 學生作品
- 興趣專案
- 小型獨立開發者

`Organization` 適合：

- 公司或工作室名義發行
- 商業品牌對外上架
- 政府或正式機構
- 某些 Google 明確要求必須用組織帳號的服務類型

官方也明講，個人帳號與組織帳號都可以上架、都可以營利。差別主要在驗證資料與公開資訊。

## 我該選 Personal 還是 Organization

### 選 `Personal` 的情況

如果這個 app：

- 由你個人維護
- 不需要掛公司名稱
- 不是金融、投資、借貸、交易所、加密資產錢包等高風險類型

通常直接選 `Personal` 就夠。

### 選 `Organization` 的情況

如果這個 app：

- 是公司產品
- 希望公開顯示公司而不是個人身分
- 有團隊分工、要讓品牌更正式
- 屬於金融產品或其他 Google 明列應用組織帳號的類型

就應該選 `Organization`。

### 重要差異

- `Personal`：可以用個人 Google 帳號建立，但新帳號正式上架前有額外測試門檻。
- `Organization`：建立時通常需要 `D-U-N-S number` 做組織驗證。
- 官方說明目前不支援把帳號類型從個人直接改成組織，所以一開始就要選對方向。

## 建立開發者帳號前要準備什麼

### 共通條件

- 年滿 18 歲
- 一個可登入的 Google 帳號
- 可刷卡的付款方式
- 可收驗證碼的 email 與電話
- 可對應真實身分或真實組織的 Google Payments Profile

### 註冊費

- Google Play 開發者帳號註冊費是一次性 `US$25`
- 不是月費，也不是年費
- 可用信用卡或金融卡付款，實際可用卡別依地區而定

### `Personal` 帳號通常要準備

- Developer name：商店上顯示的開發者名稱，可與法定姓名不同
- Legal name：法定姓名
- Legal address：法定地址
- Contact email / phone：Google 用來聯絡你的聯絡方式
- Developer email：顯示在 Google Play 開發者資訊上的 email

### `Organization` 帳號通常要準備

- 組織名稱
- 組織地址
- 組織電話
- 組織網站
- 聯絡人姓名
- 聯絡 email / phone
- Developer email / phone
- `D-U-N-S number`

## 個人帳號最容易踩到的限制

如果你的 `Personal` 開發者帳號是 **2023-11-13 之後建立**，要注意：

- 在申請正式上架到 `Production` 之前，必須先跑 `Closed testing`
- 至少要有 `12` 位 tester
- 這些 tester 必須連續 opt-in 至少 `14` 天
- 達成後才能申請 production access

另外，官方也要求新的個人帳號在正式可上架前，需用 `Play Console` 手機 app 驗證你確實持有 Android 裝置。

這代表如果你要用個人帳號上架，實務上請把測試期一起排進時程，不要以為今天申請帳號、今天就能正式上線。

## 建立帳號後，到正式上架前的完整流程

## 1. 建立 Play Console 開發者帳號

- 用 Google 帳號註冊 Play Console
- 接受 Developer Distribution Agreement
- 支付一次性 `US$25`
- 選擇 `Personal` 或 `Organization`
- 完成身分與聯絡方式驗證

## 2. 建立 app 項目

在 Play Console 內：

- 建立 app
- 選預設語言
- 填 app 名稱
- 指定是 app 或 game
- 指定免費或付費
- 填使用者可聯絡的 email
- 接受政策聲明與 Play App Signing 條款

### 這一步要特別注意

- `package name` 要先想清楚
- Google Play 上的 package name 具唯一性，而且建立後不能重用
- 不要用隨便測試的名稱直接上正式商店

## 3. 準備 release 簽章

你需要一組正式 release 用的 keystore。

在這個專案裡，目前 release build 需要：

- `android/key.properties`
- 對應的 keystore 檔，例如 `android/upload-keystore.jks`

`key.properties` 內會填：

```properties
storeFile=upload-keystore.jks
storePassword=你的_keystore密碼
keyAlias=你的key別名
keyPassword=你的key密碼
```

### 這組金鑰為什麼重要

- 它代表 app 的簽章身分
- 後續更新同一個 app 時，需要延續同一條簽章鏈
- 如果你弄丟金鑰或密碼，之後發版會很麻煩

### `upload key` 跟 `app signing key`

Google Play 目前支援 `Play App Signing`。建立第一個 release 時，你可以設定：

- 使用 Google 產生的 app signing key
- 或使用你自己提供的 app signing key

實務上常見做法是：

- 把 Google Play 當作最終 app signing key 管理方
- 你本地端保留 `upload key`
- 之後上傳新的 AAB 時，用 `upload key` 簽

這樣即使 upload key 遺失，還有機會透過 Google Play 流程申請重設 upload key；但前提是你有正確使用 Play App Signing。

## 4. 建議用 AAB，不要以 APK 當正式上架格式

Google Play 對新 app 的正式發佈格式重點是：

- 使用 `Android App Bundle (.aab)`
- Google Play 會依裝置組態產生最佳化 APK 交付給使用者

實務上：

- 本機測試可以用 APK
- 真正要上 Play，請準備 AAB

Flutter 常見做法是最後產出：

- `app-release.aab`

## 5. 補齊商店頁素材

你需要準備：

- App 名稱
- 簡短說明
- 完整說明
- App 圖示
- 功能截圖
- Feature graphic（若當前頁面要求）
- 類別
- 聯絡資訊
- 隱私權政策連結

### 素材注意事項

- 文案不要誇大不存在的功能
- 截圖要和實際 app 一致
- 商店文案、功能描述、Data safety、隱私權政策彼此要一致

## 6. 完成 App content 與政策表單

這一段通常是第一次上架最花時間的地方。

### 你至少要注意這些

- `Data safety`
- `Content rating`
- `App access`
- `Ads` 宣告
- 是否屬於兒童 / 家庭政策範圍
- 是否使用敏感權限

## 7. Data safety 不是可選，是必填

Google Play 要求：

- 發佈到 closed / open / production track 的 app，都要完成 Data safety 表單
- 就算你聲稱「完全不收資料」，也仍然要填表
- 同時仍要提供隱私權政策連結

### 實作上你要先盤點

- app 自己收了哪些資料
- 第三方 SDK 收了哪些資料
- 是否有帳號系統
- 是否收集裝置識別、分析資料、崩潰資料、照片、檔案、位置、聯絡資訊等
- 傳輸與儲存是否有加密

### 對這個專案特別要注意

如果你的 app 有：

- 本機日記內容
- 圖片附件
- Google Drive 備份
- Google Sign-In

就不能只看你自己寫的程式，也要一起盤點 SDK 與雲端流程是否涉及資料收集、傳輸、分享、同步或備份。

## 8. 隱私權政策要先準備好

Google Play 政策要求 app 在 Play Console 提供隱私權政策連結，而且 app 內也要能看到隱私權政策文字或連結。

隱私權政策至少應說明：

- 開發者或公司資訊
- 聯絡方式
- 收集哪些資料
- 如何使用資料
- 是否分享給第三方
- 如何保護資料
- 保存與刪除政策

### 很常見的錯誤

- 商店頁說不收資料，但隱私權政策又寫會收分析資料
- 有 Google 登入、雲端備份，卻說完全沒有資料傳輸
- 只貼空白模板或 generic policy，和實際 app 不一致

## 9. 內容分級要填對

每個新 app 都要完成 `Content rating` 問卷。

注意：

- 沒填會變成 `Unrated`
- 無分級的 app 可能被下架或無法上架
- 如果之後功能改變，會影響分級答案，必須重填

### 這個專案的常見判斷

如果它是一般日記 app，通常不代表自動是高分級；但如果：

- 允許使用者上傳公開內容
- 有社交互動
- 顯示成人內容
- 有使用者生成且未妥善管控的內容

分級與問卷答案就要更小心。

## 10. App access 要能讓審核員進得去

如果你的 app 有：

- 登入牆
- PIN / 密碼 / 生物驗證
- 需要特殊身分才能看到主要功能

通常需要在 Play Console 提供審核說明，讓 Google 審核員可以進入 app 測試。

對這個專案尤其重要，因為它本身就有：

- 解鎖機制
- 可能的本機保護或受信任裝置流程

如果審核員打不開主要畫面、也沒有測試帳號或操作說明，審核很容易卡住。

## 11. 敏感權限要額外小心

Google Play 在 release 過程會檢查權限。

如果 app 使用高風險或敏感權限，可能需要額外填 `Permissions declaration form`，例如：

- SMS
- Call log
- 高敏感背景權限

### 對這個專案

一般日記 app 常見的是：

- 相簿 / 檔案選取
- 相機
- 通知

這些雖然不一定屬最高風險，但商店描述、Data safety、實際功能與權限用途都要對得上。

## 12. Target API 要符合當前規定

依 Google Play 官方目前資料，從 **2025-08-31** 起：

- 新 app 與 app 更新都必須 target `Android 15`，也就是 `API level 35` 或更高，才能提交到 Google Play

這是會變動的政策，因此你在真正送審前，應再次核對官方 target API 規定。

### 對這個專案的實務意義

你送審前要確認：

- `targetSdkVersion` 符合當前 Google Play 要求
- 用到的 plugin 與 Android 設定能在對應 API level 正常運作

## 13. 先測試，再上 Production

建議流程：

1. 本機測試 debug / release build
2. 先上 `Internal testing`
3. 再上 `Closed testing`
4. 整理回饋、修 bug
5. 確認商店頁、政策、Data safety、隱私權政策都一致
6. 再上 `Production`

### 如果你是新的個人帳號

要特別記得：

- Closed test 至少 `12` 人
- 持續 `14` 天
- 達標後才能申請 production access

## 14. 上架前的最小檢查清單

### 帳號與法務

- 已建立 Play Console 帳號
- 帳號類型選對
- 已完成身分驗證
- 聯絡資訊可正常收信、收簡訊
- 若要用組織帳號，已備妥 `D-U-N-S number`

### Android 建置

- 可成功產出 release 用 AAB
- 已設定正式簽章 keystore
- `android/key.properties` 不會提交到 git
- `versionCode` 有遞增
- `versionName` 已確認
- `applicationId` / package name 已定案

### 商店資料

- App 名稱確認
- 短描述 / 長描述完成
- icon / 截圖完成
- 類別確認
- 聯絡方式確認
- 隱私權政策網址可公開訪問

### Play Console 表單

- Data safety 完成
- Content rating 完成
- App access 說明完成
- Ads 宣告完成
- 權限宣告完成

### 發版流程

- 先 internal test
- 若為新個人帳號，closed test 達標
- 再送 production

## 15. 這個專案目前特別要注意的點

基於目前 repo 狀態，至少要注意：

- Release 簽章已被專案強制要求，沒有 `android/key.properties` 就不能 build release
- 正式上架請優先產 `AAB`，不要只停在 `APK`
- app 內涉及本機保護、解鎖流程、Google Drive 備份與可能的登入流程，Data safety、隱私權政策、App access 都要先對齊
- 若你要走個人帳號，請把 `12 人 / 14 天 closed test` 納入時程

## 16. 建議你採用的實際策略

如果你現在是個人開發、想先把 app 上架：

1. 用你的個人 Google 帳號建立 `Personal` 開發者帳號
2. 接受 `US$25` 一次性註冊費
3. 完成身分與裝置驗證
4. 建立正式 release keystore
5. 先準備 AAB
6. 先上 internal testing
7. 再完成 closed testing 門檻
8. 同步完成：
  - 隱私權政策
  - Data safety
  - Content rating
  - App access 說明
9. 確認 target API 與權限宣告沒問題
10. 再送 production

如果你確定這個 app 未來要品牌化、商業化、多人協作，或代表正式組織：

1. 一開始就考慮用 `Organization`
2. 先準備 `D-U-N-S number`
3. 把付款、報稅、隱私政策、客服聯絡窗口一起規劃

## 17. 常見誤解

### 「我用個人帳號就不能賺錢」

錯。個人帳號也可以營利。

### 「我先隨便用個人帳號，之後再改成組織」

不要預設可以輕鬆切換。官方目前不支援直接把個人帳號改成組織帳號，應在建立前選對。

### 「上架只要把 APK 丟上去就好」

不對。對新的正式上架流程，重點是 AAB、簽章、商店頁素材、Data safety、Content rating、測試流程與政策合規。

### 「我沒有收資料，所以不用隱私權政策」

不對。Google Play 的 Data safety 流程要求即使不收資料，也仍要填表並提供隱私權政策連結。

### 「我先用 release build 過了就一定能上架」

不對。build 成功只是技術條件之一，政策、審核、商店頁內容、測試門檻同樣會擋你。

## 18. 官方參考資料

- Play Console 入門與註冊費  
[Get started with Play Console](https://support.google.com/googleplay/android-developer/answer/6112435?hl=en)
- 帳號類型  
[Choose a developer account type](https://support.google.com/googleplay/android-developer/answer/13634885?hl=en-EN)
- 建立帳號所需資料  
[Required information to create a Play Console developer account](https://support.google.com/googleplay/android-developer/answer/13628312?hl=en)
- 建立 app 與 App Bundle / Play App Signing  
[Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en)
- 個人帳號測試要求  
[App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- Data safety  
[Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en-EN)
- Content rating  
[Content Ratings](https://support.google.com/googleplay/android-developer/answer/9898843?hl=en)
- 發版流程  
[Prepare and roll out a release](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en-GB)
- Target API 規定  
[Target API level requirements for Google Play apps](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)

## 19. 文件使用建議

如果你要真的開始上架，建議把工作拆成 4 份：

1. Play Console 帳號建立與驗證
2. Android release 簽章與 AAB 產出
3. 隱私權政策 / Data safety / 權限盤點
4. Closed testing 與正式上架排程

這樣比較不會把技術建置、法務文案與審核流程混在一起。