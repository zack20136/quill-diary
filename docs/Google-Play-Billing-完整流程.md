# Google Play Billing 完整流程

最後更新：2026-05-27

## 文件目的

這份文件整理的是：如何在 **Quill Lock Diary** 導入 **Google Play Billing**，做一個 **可重複購買** 的「支持開發者」商品。

這份文件同時涵蓋：

- Play Console 前置準備
- 個人帳號收款與隱私風險
- 商品設計
- Flutter / Android 實作流程
- 測試流程
- 上架前檢查清單

## 最終決策

本專案採用以下方案：

- 帳號類型：`Personal`
- 收款方式：`Google Play Billing`
- 商品型態：`One-time product`
- 商品定位：`支持開發者`
- 商品回饋：**不提供任何額外功能**
- 購買模式：**可重複支持**
- 建議產品 ID：`support_developer_repeat`

## 先講結論

如果目標是：

- 使用者能在 app 內支持開發者
- 不想走外部付款頁
- 不想踩 Google Play Payments policy
- 不提供 Premium、去廣告、徽章或會員權益

那最穩定的做法就是：

- 用 Google Play Billing
- 做一個「支持開發者」的一次性商品
- 讓它 **可重複購買**
- 每次購買後 **consume**

---

## 1. 產品定位與政策邊界

## 1.1 這不是慈善捐款

雖然產品目的接近 donate，但在 Google Play 內部，這份文件不把它定義成：

- `donation`
- `tax-exempt donation`
- 慈善捐款

而是定義成：

- `支持開發者`
- `一次性支持`

原因是：

- 這樣比較不會落入外部 donate / policy 灰區
- 也比較不容易讓使用者誤會是公益捐款或可抵稅款項

## 1.2 不能提供任何數位回饋

這個商品購買後：

- 不解鎖功能
- 不去廣告
- 不給 Premium
- 不給徽章
- 不給特殊頁面
- 不給支持者標記
- 不改變 app 任何功能行為

這是整個方案能維持簡單、低風險的核心前提。

## 1.3 為什麼改成可重複支持

本專案最終決策是 **可重複支持**，理由如下：

- 使用者之後若想再次支持，不需要新增第二個商品
- 不會出現「買過一次後按鈕就失效」的體驗問題
- 符合 donate / tip 類型商品的直覺使用方式

技術上這表示：

- 這個商品要走 **consume** 流程
- 不能只做 acknowledge 後永久已購

---

## 2. 個人帳號收款的最佳做法

## 2.1 可以用個人帳號

Google Play 允許 `Personal` 帳號營利，也可以搭配 payments profile 收款。

但要注意：

- 如果 app 有營利，Google Play 會顯示你的完整地址
- 個人帳號的公開 developer email 也會顯示在 Google Play

參考：

- [Choose a developer account type](https://support.google.com/googleplay/android-developer/answer/13634885?hl=en-EN)
- [Required information to create a Play Console developer account](https://support.google.com/googleplay/android-developer/answer/13628312?hl=en)
- [View and manage your developer account information](https://support.google.com/googleplay/android-developer/answer/13634081?hl=en)

## 2.2 最低騷擾實務方案

如果你要用 `Personal` 帳號 + Play Billing，建議這樣做：

- `Developer name` 用品牌名，不用本名
- 準備一個專用 `developer email`，不要用私人主信箱
- 準備 app 專屬網站，放 FAQ、隱私權政策與支援頁
- Store listing 的聯絡方式以專用信箱與網站為主
- 購買說明要非常清楚，減少購買糾紛

### 建議對外公開資訊

- Developer name：`Quill Lock Diary`
- Developer email：專用 app/support 信箱
- Website：專屬網站或支援頁

### 不建議

- 公開私人主信箱
- 把 app 支援直接綁定生活用手機
- 用模糊文案讓使用者誤以為付款後會解鎖功能

## 2.3 你不能避免的事

如果你營利，Google Play 仍可能顯示：

- 法定姓名
- 完整地址

這是 Google Play 規則，不是 app 內程式能解決的。

---

## 3. Play Console 前置準備

## 3.1 你需要先完成

- 已建立 Google Play 開發者帳號
- 已建立此 app 的 Play Console 專案
- 已建立 payments profile / merchant 相關收款資料
- 已能產出正式 release AAB
- 已完成正式簽章設定

## 3.2 商品型態

本專案建議商品型態：

- `One-time product`

但使用方式上當作：

- 可重複支持的 consumable 商品

## 3.3 建議商品資料

- Product ID：`support_developer_repeat`
- Title：`支持開發者`
- Description：`一次性支持開發者，不解鎖任何額外功能。`

如果未來要做多價位，可另外增加：

- `support_developer_small`
- `support_developer_medium`
- `support_developer_large`

但第一版建議只做一個商品。

## 3.4 文案原則

可以寫：

- `支持開發者`
- `一次性支持開發者，不解鎖任何額外功能`
- `感謝你支持 Quill Lock Diary 持續開發`

不要寫：

- `Donate`
- `Donation`
- `Premium`
- `支持者專屬`
- `解鎖更多功能`
- `贊助後享更多服務`

---

## 4. Play Console 商品建立流程

## 4.1 建立商品

在 Play Console：

- `Monetize with Play`
- `Products`
- `In-app products` / `One-time products`
- 建立商品

填入：

- Product ID
- Title
- Description
- Price

## 4.2 啟用商品

建立完後要：

- 儲存
- `Activate`

未啟用的商品，app 端通常查不到。

## 4.3 測試帳號

在 Play Console 設定：

- `License testers`

至少要有：

- 一個自己的測試 Google 帳號
- 一台已登入該帳號的 Android 裝置

---

## 5. 專案端要新增什麼

## 5.1 目前 repo 狀態

目前 repo 尚未接入 Google Play Billing：

- `pubspec.yaml` 內沒有 Billing 套件
- `lib/` 內沒有 billing service / purchase state
- Android 端也尚未納入 billing 流程

所以這是一次全新導入。

## 5.2 建議的程式結構

建議至少新增：

- `lib/features/support/`
- `lib/features/support/pages/support_page.dart`
- `lib/features/support/providers/support_providers.dart`
- `lib/infrastructure/billing/play_billing_service.dart`
- `lib/features/support/state/support_purchase_state.dart`

## 5.3 Android 端要確認的事

要確認最終 merged manifest 有：

- `com.android.vending.BILLING`

如果使用 Flutter Billing 套件，有些情況會自動處理；但仍要驗證最終輸出。

---

## 6. App 內實作流程

Google Play Billing 的完整流程如下：

1. 初始化 Billing client
2. 連線到 Google Play
3. 查詢 `ProductDetails`
4. 顯示商品資訊
5. 使用者點擊支持
6. 呼叫購買流程
7. 接收 purchase callback
8. 驗證購買狀態
9. consume 購買
10. 顯示成功訊息並記錄支持結果

參考：

- [Google Play billing system](https://developer.android.com/google/play/billing/)
- [Integrate the Google Play Billing Library into your app](https://developer.android.com/google/play/billing/integrate.html)

## 6.1 初始化與連線

你需要：

- 建立 Billing client
- 註冊 purchase updates listener
- 在支持頁開啟時確認 client ready

要處理：

- 初次連線失敗
- 暫時無法連線
- 使用者從背景回來時的狀態補抓

## 6.2 查詢商品

流程：

- 用 `support_developer_repeat`
- 查詢 `ProductDetails`
- 讀取 Play 回傳的名稱、價格、說明

注意：

- 價格不要寫死在 app
- UI 以 Play 回傳資料為準
- 查不到商品時要有 fallback UI

## 6.3 發起購買

使用者點按支持按鈕後：

- 建立 `BillingFlowParams`
- 呼叫 `launchBillingFlow`

UI 建議：

- 主按鈕：`支持開發者`
- 補充文字：`這筆付款不會解鎖任何額外功能`

## 6.4 接收購買結果

你要處理：

- success
- cancelled
- error
- pending

不要做的事：

- 不要只要按下購買就直接顯示成功
- 不要跳過 purchase callback 判斷

---

## 7. 可重複支持的核心處理

## 7.1 為什麼這次一定要 consume

因為本專案的商品是：

- 一次性商品
- 可重複支持

所以每次購買完成後，都要讓該商品回到可再次購買狀態。  
這代表你需要在成功處理後：

- **consume purchase**

如果只做 acknowledge：

- 使用者通常就不能用同一商品再買一次

## 7.2 建議流程

每次購買成功後：

1. 確認 purchase state 正常
2. 記錄本次 purchase token / order 資訊
3. 完成你自己的「已收到支持」內部處理
4. 呼叫 consume
5. consume 成功後才把 UI 恢復為可再次購買

## 7.3 本地記錄建議

即使不提供額外功能，也建議記錄：

- 最近一次支持時間
- 最近一次 purchase token
- 最近一次 consume 狀態
- 最近一次錯誤原因

用途：

- 排查客服問題
- 避免重複處理同一筆 callback
- 之後若要接後端驗證更容易銜接

---

## 8. 後端驗證

## 8.1 最安全做法

最安全的做法是：

- app 取得 `purchaseToken`
- 傳到你的 backend
- backend 用 Google Play Developer API 驗證

參考：

- [Play Billing security](https://developer.android.com/google/play/billing/security)
- [One-time purchase lifecycle](https://developer.android.com/google/play/billing/lifecycle/one-time?hl=en)

## 8.2 如果第一版沒有後端

可以先做 app 端版，但要知道限制：

- 較難做完整對帳
- 較難防偽造
- 較難處理退款 / 撤銷 / 重播事件

### 第一版建議

第一版可接受：

- app 端完成購買流程
- app 端 consume
- app 端保存最小支持記錄

之後若營運真的啟動，再補 backend 驗證。

---

## 9. 支持頁 UI 建議

## 9.1 頁面結構

建議支持頁至少包含：

- 頁面標題：`支持開發者`
- 一段說明文字
- 價格與商品卡片
- 購買按鈕
- 購買中狀態
- 成功 / 失敗 / 取消提示

## 9.2 建議文案

主說明可用：

`這是一筆一次性支持，用來幫助 Quill Lock Diary 持續開發。購買後不會解鎖任何額外功能。`

成功提示可用：

`感謝你的支持。`

## 9.3 不要做的 UI

- 不要做成 Premium 卡
- 不要做等級方案暗示權益差異
- 不要在付款後出現任何支持者專屬標記

---

## 10. 測試流程

參考：

- [Test your Google Play Billing Library integration](https://developer.android.com/google/play/billing/test?hl=en)

## 10.1 必測情境

- 查得到商品
- 查不到商品
- 成功購買
- 使用者取消
- 暫時失敗
- pending
- consume 成功
- consume 失敗
- app 重啟後可正確補抓未完成交易
- 同一商品可再次購買

## 10.2 測試工具

可用：

- License testers
- Internal testing
- Play Billing Lab

## 10.3 上線前至少要確認

- 支持頁價格正確
- 付款後沒有解鎖任何功能
- 商品可重複購買
- 錯誤訊息不會誤導

---

## 11. 上架前檢查清單

### Play Console

- 已建立 payments profile
- 已建立 `support_developer_repeat`
- 商品已啟用
- 已設定 license testers

### 專案端

- 已加入 Billing 套件
- 已完成 billing service
- 已完成支持頁 UI
- 已完成 purchase callback 處理
- 已完成 consume 流程
- 已完成本地狀態記錄

### 文案與政策

- 商品名稱不是 donate / donation
- app 內文案已清楚寫明「不解鎖任何功能」
- 商店頁不暗示 Premium 或升級
- 隱私權政策已提到付款由 Google Play 處理

### 驗證

- Internal testing 通過
- 實機購買測試通過
- 可重複購買流程通過

---

## 12. 常見錯誤

### 1. 把這個商品當成不可重複購買

錯。這份方案已定案為可重複支持，所以要規劃 consume。

### 2. 只做 acknowledge

對這個方案不合適。  
因為你要讓使用者未來還能再次支持。

### 3. 價格硬寫死

錯。價格要來自 `ProductDetails`。

### 4. donate 文案暗示功能交換

高風險。這會讓商品定位變得模糊，增加審核與客訴風險。

### 5. 使用私人主信箱做公開客服

不建議。這會直接增加騷擾風險。

---

## 13. 官方參考資料

- Play Billing 總覽  
  [Google Play billing system](https://developer.android.com/google/play/billing/)
- 整合流程  
  [Integrate the Google Play Billing Library into your app](https://developer.android.com/google/play/billing/integrate.html)
- one-time product 生命週期  
  [One-time purchase lifecycle](https://developer.android.com/google/play/billing/lifecycle/one-time?hl=en)
- 安全與驗證  
  [Play Billing security](https://developer.android.com/google/play/billing/security)
- 測試  
  [Test your Google Play Billing Library integration](https://developer.android.com/google/play/billing/test?hl=en)
- 建立 app 內商品  
  [Create an in-app product](https://support.google.com/googleplay/android-developer/answer/1153481?hl=en)
- 產品型態  
  [Understand in-app product types and catalog considerations](https://support.google.com/googleplay/android-developer/answer/14590082?hl=en)
- Payments policy  
  [Payments](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en)
- Payments policy FAQ  
  [Understanding Google Play’s Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)
- 個人帳號與公開資訊  
  [Required information to create a Play Console developer account](https://support.google.com/googleplay/android-developer/answer/13628312?hl=en)
- 開發者資訊管理  
  [View and manage your developer account information](https://support.google.com/googleplay/android-developer/answer/13634081?hl=en)

## 14. 本專案的直接執行建議

下一步建議依序做：

1. 在 Play Console 建立 `support_developer_repeat`
2. 準備專用 developer/support email
3. 準備 app 支援網站或最小 FAQ 頁
4. 決定 Flutter Billing 套件
5. 在 app 內新增支持頁
6. 實作 query / purchase / consume 流程
7. 用 license tester 跑完整測試

如果之後要進一步實作，這份文件的前提已經定案：

- 商品名稱：`支持開發者`
- 產品 ID：`support_developer_repeat`
- 模式：`可重複支持`
- 回饋：`無額外功能`
