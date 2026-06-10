# Google Play Billing

這份文件是 Quill Diary 的 Billing 規劃文件，不是已完成串接的實作文件。

目前 `SupportPage` 仍是「尚未開放」狀態，以下內容主要用來保留產品決策、文案方向與未來接入步驟。

## 目前決策

- 帳號類型：`Personal`
- 收款方式：`Google Play Billing`
- 商品類型：`One-time product`
- 產品 ID：`support_developer_repeat`
- 商品名稱：`支持開發者`
- 商品模式：可重複支持
- 商品回饋：不解鎖任何額外功能

## 為什麼這樣設計

目標是：

- 避免外部 donate 的政策灰區
- 讓使用者在 app 內直接支持開發者
- 不把支持行為包裝成 Premium 或會員制

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

## Play Console 端要準備什麼

- 建立一個 `One-time product`
- Product ID：`support_developer_repeat`
- Title：`支持開發者`
- Description：`一次性支持開發者，不解鎖任何額外功能。`
- 建立後記得 `Activate`
- 設定至少一個 `License tester`

## 該如何做

如果未來真的要接 Billing，建議按這個順序做：

1. 先在 Play Console 建立並啟用商品
2. 準備測試帳號
3. 在 app 端接上 Billing client
4. 查詢 `ProductDetails`
5. 顯示商品價格與說明
6. 發起購買
7. 接收 purchase callback
8. 驗證購買結果
9. `consume` 購買
10. 顯示成功訊息

## 為什麼一定要 consume

這個商品的決策是可重複支持。

因此每次成功購買後，都要 `consume` 該筆購買，否則通常無法再次購買同一商品。

## 建議實作順序

初期可先做：

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

- Support 頁不再顯示「尚未開放」
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

---

[← 返回 Google 文件](./README.md)
