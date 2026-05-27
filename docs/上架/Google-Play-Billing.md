# Google Play Billing

最後更新：2026-05-27

## 本專案決策

- 帳號類型：`Personal`
- 收款方式：`Google Play Billing`
- 商品類型：`One-time product`
- 產品 ID：`support_developer_repeat`
- 商品名稱：`支持開發者`
- 商品模式：可重複支持
- 商品回饋：不解鎖任何額外功能

## 為什麼這樣做

這個方案的目標是：

- 避免外部 donate 的政策灰區
- 讓使用者直接在 app 內支持開發者
- 不把支持行為包裝成 Premium 或會員

## 文案原則

可以寫：

- `支持開發者`
- `一次性支持開發者，不解鎖任何額外功能。`

不要寫：

- `Donate`
- `Donation`
- `Premium`
- `支持者專屬`
- `解鎖更多功能`

## 個人帳號收款的最佳做法

個人帳號可以收款，但要接受：

- 若 app 營利，Google Play 會顯示完整地址
- 開發者 email 會公開

為了降低被騷擾的機率，建議：

- `Developer name` 用品牌名，不用本名
- `developer email` 用專用信箱，不用私人主信箱
- 準備支援網站或 FAQ 頁
- 用清楚文案減少購買糾紛

## Play Console 要做什麼

### 1. 建立商品

建立一個 `One-time product`：

- Product ID：`support_developer_repeat`
- Title：`支持開發者`
- Description：`一次性支持開發者，不解鎖任何額外功能。`

### 2. 啟用商品

建立後要：

- 儲存
- `Activate`

### 3. 設定測試帳號

- 設定 `License testers`
- 至少準備一個實際測試用 Google 帳號

## App 端實作流程

1. 初始化 Billing client
2. 連線 Google Play
3. 查詢 `ProductDetails`
4. 顯示商品價格與說明
5. 發起購買
6. 接收 purchase callback
7. 驗證購買結果
8. **consume**
9. 顯示成功訊息

## 為什麼一定要 consume

這個商品的決策是 **可重複支持**。

所以每次成功購買後，都要：

- consume 該筆購買

否則使用者之後通常無法再買同一個商品。

## 第一版建議

第一版可以先做：

- app 端完整購買流程
- app 端 consume
- 本地記錄最近一次支持結果

後續若要提高安全性，再補：

- backend 驗證 purchase token

## 必測情境

- 查得到商品
- 查不到商品
- 成功購買
- 使用者取消
- pending
- consume 成功
- consume 失敗
- app 重開後補抓未完成交易
- 同一商品可再次購買

## 上線前檢查

- 商品已建立並啟用
- 價格從 Play 回傳，不寫死
- 購買後不解鎖任何功能
- 可重複購買流程正常
- 隱私權政策有說明付款由 Google Play 處理

## 官方參考

- [Google Play billing system](https://developer.android.com/google/play/billing/)
- [Integrate the Google Play Billing Library into your app](https://developer.android.com/google/play/billing/integrate.html)
- [One-time purchase lifecycle](https://developer.android.com/google/play/billing/lifecycle/one-time?hl=en)
- [Play Billing security](https://developer.android.com/google/play/billing/security)
- [Test your Google Play Billing Library integration](https://developer.android.com/google/play/billing/test?hl=en)
- [Create an in-app product](https://support.google.com/googleplay/android-developer/answer/1153481?hl=en)
- [Payments](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en)
- [Understanding Google Play’s Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)
