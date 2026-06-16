# Google Play Billing

Quill Diary 的「贊助開發」採 **client-only Google Play Billing**：純贊助、無登入、無權益、無贊助紀錄、無後端驗證。

## 產品決策

- 收款方式：`Google Play Billing`
- 商品類型：`One-time product`（**consumable**，可重複購買；App 端須 `buyConsumable` + `consumePurchase`）
- 商品數量：**5 檔梯次**（由低到高：NT$50 / 100 / 300 / 1000 / 2000）
- 回饋：**無**（不解鎖功能、不去廣告、無徽章/會員/特殊內容）
- App **不寫死價格**；下表台灣價格僅供 Play Console 設定參考，實際以 `ProductDetails.price` 顯示

### Play Console 單次產品欄位

每個產品須填 **產品 ID、名稱、說明**（名稱與說明須準確、不得誤導使用者）。價格在 **購買選項** 裡設定，可為各區域設定不同價格。

- **交易類型**：購買（非租借）
- **數位內容或服務**：服務

### 商品清單

| 排序 | 產品 ID | 產品名稱 | 台灣價格 | 建議說明 |
| -: | --- | --- | ---: | --- |
| 1 | `sponsor_coffee` | 請開發者喝杯咖啡 | NT$50 | 謝謝你請開發者喝杯咖啡，這份鼓勵會支持 Quill Diary 持續開發與維護。 |
| 2 | `sponsor_snack` | 請開發者吃點心 | NT$100 | 謝謝你請開發者吃份點心，讓 Quill Diary 能繼續穩定改進。 |
| 3 | `sponsor_lunch` | 請開發者吃午餐 | NT$300 | 謝謝你請開發者吃頓午餐，這份支持會幫助 Quill Diary 持續變得更好。 |
| 4 | `sponsor_boost` | 大力支持 | NT$1000 | 謝謝你大力支持 Quill Diary，這份鼓勵會成為我們持續開發、維護與改善 App 的動力。 |
| 5 | `sponsor_super` | 大大大大大力支持 | NT$2000 | 謝謝你用超大力的方式支持 Quill Diary，這份心意會幫助我們更安心地投入長期開發與維護。 |

### App 顯示順序

```text
NT$50    請開發者喝杯咖啡
NT$100   請開發者吃點心
NT$300   請開發者吃午餐
NT$1000  大力支持
NT$2000  大大大大大力支持
```

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
| `TODO(manual:play-products)` | 建立 **5 個** consumable One-time product（上表 ID、名稱、說明），於購買選項設定區域價格後 **Activate** |
| `TODO(manual:internal-testing-aab)` | 上傳含 `BILLING` 權限的 AAB 至 **Internal testing** |
| `TODO(manual:license-testers)` | Play Console → License testing 加入測試 Gmail |
| `TODO(manual:test-matrix)` | 實機測：成功、取消、付款失敗、pending、重複購買、重開補單 |
| `TODO(manual:consume-complete)` | 確認 `consumePurchase` + `completePurchase` 正常，同一商品可再次購買 |

## 自動化與手動驗證

程式碼庫目前只自動驗證 `BillingConfig` 與 `GoogleBillingService` 的契約；商品建立、License testing、五檔商品查價、成功/取消/失敗/`pending`、`consumePurchase` 後可再次購買，以及 app 重開補抓未完成交易，仍需依 Play Console 與真機流程手動確認。這份文件中的 `TODO(manual:...)` 就是發布前必做的手動驗證清單，不是遺漏的產品需求。

## 未來擴充（本次不做）

若日後要提供權益或保存贊助紀錄，再補 Cloudflare Worker verify + D1。

## 官方參考

- [單次產品總覽 - Play 管理中心說明](https://support.google.com/googleplay/android-developer/answer/16430488?hl=zh-Hant)
- [One-time products | Play Billing | Android Developers](https://developer.android.com/google/play/billing/one-time-products)
- [Google Play billing system](https://developer.android.com/google/play/billing/)
- [Integrate the Google Play Billing Library](https://developer.android.com/google/play/billing/integrate.html)
- [One-time purchase lifecycle](https://developer.android.com/google/play/billing/lifecycle/one-time?hl=en)
- [Test your Billing integration](https://developer.android.com/google/play/billing/test?hl=en)
- [Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)

---

[← 返回 Google 文件](./README.md)
