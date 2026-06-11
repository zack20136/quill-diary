# Google Play Billing

Quill Diary 的「贊助開發」採 **client-only Google Play Billing**：純贊助、無登入、無權益、無贊助紀錄、無後端驗證。

## 產品決策

- 收款方式：`Google Play Billing`
- 商品類型：`One-time product`（consumable，可重複購買）
- 商品數量：**5 檔梯次**（由低到高，中間一檔標「常用」）
- 商品 ID：

| ID | 建議定位 | 參考定價（台灣） | 參考定價（美國） |
|----|----------|------------------|------------------|
| `sponsor_coffee` | 喝杯咖啡 | NT$30 | US$0.99 |
| `sponsor_snack` | 點心支持 | NT$60 | US$1.99 |
| `sponsor_lunch` | 午餐加油（**常用**） | NT$150 | US$4.99 |
| `sponsor_treat` | 加碼支持 | NT$300 | US$9.99 |
| `sponsor_cheer` | 盛意支持 | NT$600 | US$19.99 |

- 回饋：**無**（不解鎖功能、不去廣告、無徽章/會員/特殊內容）
- App **不寫死價格**；上表僅供 Play Console 設定參考，實際以 `ProductDetails.price` 顯示

## 文案原則

可以寫：

- `支持開發者`
- `一次性支持開發者，不解鎖任何額外功能。`

不要寫：

- `Donate` / `Donation`
- `Premium` / `會員` / `支持者專屬`
- `解鎖更多功能`

## App 端流程

1. App 啟動時訂閱 `purchaseStream`
2. 贊助頁 `queryProductDetails` 載入五檔商品
3. 使用者點「支持 {價格}」→ `buyConsumable`
4. `pending` / `error` / `canceled` / `purchased` 依狀態顯示訊息
5. `purchased` → 感謝 → `consumePurchase` → `completePurchase`（若需要）
6. **不**在本機持久化「已贊助」狀態

相關程式：

- [`lib/services/google_billing_service.dart`](../../../lib/services/google_billing_service.dart)
- [`lib/features/settings/pages/support_page.dart`](../../../lib/features/settings/pages/support_page.dart)
- [`lib/config/billing_config.dart`](../../../lib/config/billing_config.dart)

## Play Console 手動設定

| TODO | 你要做的事 |
|------|------------|
| `TODO(manual:play-products)` | 建立 **5 個** consumable One-time product（上表 ID），定價後 **Activate** |
| `TODO(manual:internal-testing-aab)` | 上傳含 `BILLING` 權限的 AAB 至 **Internal testing** |
| `TODO(manual:license-testers)` | Play Console → License testing 加入測試 Gmail |
| `TODO(manual:test-matrix)` | 實機測：成功、取消、付款失敗、pending、重複購買、重開補單 |
| `TODO(manual:consume-complete)` | 確認 `consumePurchase` + `completePurchase` 正常，同一商品可再次購買 |

## 必測情境

- 五檔商品皆能查詢並顯示 Play 價格
- 成功購買、取消、付款失敗、pending
- consume 成功後可再次購買
- app 重開後補抓未完成交易

## 未來擴充（本次不做）

若日後要提供權益或保存贊助紀錄，再補 Cloudflare Worker verify + D1。

## 官方參考

- [Google Play billing system](https://developer.android.com/google/play/billing/)
- [Integrate the Google Play Billing Library](https://developer.android.com/google/play/billing/integrate.html)
- [One-time purchase lifecycle](https://developer.android.com/google/play/billing/lifecycle/one-time?hl=en)
- [Test your Billing integration](https://developer.android.com/google/play/billing/test?hl=en)
- [Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)

---

[← 返回 Google 文件](./README.md)
