# Google Play Billing

Billing 僅提供 Google Play 一次性支持，不訂閱、不解鎖功能、不保存永久權益，也不讀取日記。流程在裝置端處理，沒有自家後端驗單或跨裝置權益同步。

## 商品與顯示

[`billing_catalog.dart`](../../../lib/infrastructure/billing/billing_catalog.dart) 的固定順序為：

1. `sponsor_coffee`
2. `sponsor_snack`
3. `sponsor_lunch`
4. `sponsor_boost`
5. `sponsor_super`

Play Console 應建立並啟用相同 ID 的一次性商品。App 使用可重複購買的 consumable 流程；支持頁使用 Play 回傳的 title、description、price，不寫死價格。商品描述須符合一次性支持及沒有額外功能的實際行為。

### Play Console 設定步驟

1. 在 `zack20136.com.quill_diary` 對應的 App 建立上述五個一次性商品，確認商品 ID 大小寫完全一致。
2. 為各商品提供標題、描述、售價與可購買地區，啟用實際要發布的購買選項／商品。價格由 Console 管理，不在 App 或本文件固定。
3. 標題可依序使用「請我喝杯咖啡」、「請我吃點心」、「請我吃午餐」、「給開發一點鼓勵」、「大力支持開發」；描述統一表達「一次性支持 Quill Diary 開發，不含訂閱或額外功能」。這是建議文案，實際顯示以 Play 商品設定為準。
4. 上傳可測試的簽章版本至測試軌道，設定測試人員與 license testers，再使用對應 Google 帳號測試。參加測試軌道與成為 license tester 是不同設定；非測試付款方式可能真實扣款。
5. 從 Play 安裝該軌道版本，確認支持頁讀到五項商品與在地化價格，並完成一次購買、取消及再次購買。

測試帳號、付款測試方式與 Billing Lab 操作依 [Google Play Billing 測試指南](https://developer.android.com/google/play/billing/test)；不能只用 widget mock 測試代替實際交易驗收。

## 交易生命週期

[`GoogleBillingService`](../../../lib/infrastructure/billing/google_billing_service.dart) 初始化時檢查可用性、訂閱 `purchaseStream` 並呼叫 `restorePurchases()`，接手未完成交易。商品查詢後依 catalog 順序排序。

| 狀態 | 處理 |
|------|------|
| `pending` | 顯示等待 |
| `error`、`canceled` | 顯示對應結果並解除等待 |
| `purchased`、`restored` | 最終處理；成功後顯示感謝 |

購買使用 `buyConsumable(autoConsume: false)`。Android 先 `consumePurchase()`，再依 `pendingCompletePurchase` 呼叫 `completePurchase()`，不能因畫面已顯示感謝就省略交易收尾。確認時限及退款規則以[套件文件](https://pub.dev/packages/in_app_purchase)與[Play 一次性商品生命週期](https://developer.android.com/google/play/billing/lifecycle/one-time)為準。

目前裝置端方案適用於不建立永久權益的支持用途。若改成解鎖功能、保存權益或高價值商品，須依[Play 安全建議](https://developer.android.com/google/play/billing/security)重新設計驗證與後端，並同步隱私政策及商店說明。

consume／complete 失敗時不能直接當成成功；App 會回報錯誤，後續初始化接手仍未完成的交易。已消耗的支持不會還原成永久購買紀錄，也不應以 `restorePurchases()` 承諾跨裝置恢復支持歷史。

## 審查與資料揭露用說明

> 支持開發者是自願的一次性 App 內購買。購買不提供訂閱、會員、去廣告或功能解鎖；未購買也能使用所有功能。商品與付款由 Google Play 處理，價格依 Play 顯示。App 在裝置端完成交易收尾，不建立自家帳號、付款資料庫或跨裝置權益。

「App 不保存永久權益」不代表沒有處理交易資料：Billing 回呼仍含商品與交易識別資訊，SDK 的資料處理也須納入 Data safety 核對。不要把支持稱為慈善捐款，也不要用「永久解鎖」作為商品描述。

## 商品載入失敗排查

| 狀況 | 優先檢查 |
|------|------|
| Billing 不可用 | 裝置是否有可用 Play 商店、目前帳號與網路狀態 |
| `no_products`／部分商品未找到 | `notFoundProductIds`、商品 ID、啟用狀態、地區及實際發布的 App |
| `query_failed`／`init_failed` | Play 服務、帳號與網路；重試初始化，不直接改商品 ID |
| 只能購買一次 | consume 是否成功，之後的 complete 是否仍待處理 |
| Debug 正常但測試軌道異常 | 安裝來源、套件名稱、選取的付款帳號與 license tester 設定 |

狀態與 I/O 在 [`GoogleBillingService`](../../../lib/infrastructure/billing/google_billing_service.dart)；Provider 在 [`billing_providers.dart`](../../../lib/application/settings/billing_providers.dart)，畫面在 [`support_page.dart`](../../../lib/presentation/settings/pages/support_page.dart)。

## 發布驗證

- 五項商品可查詢，顯示順序與在地化價格正確。
- 等待、取消、錯誤、成功與 restored 均可收尾。
- consume／complete 成功後可再次購買，重新啟動可接手未完成交易。
- 付款由 Play 處理，App 不保存付款憑證或支持紀錄作為永久權益。

權限見[Android 權限與資料揭露](Android-權限與資料揭露.md)，公開說明見[隱私權政策](../../privacy-policy.md)。

[← 返回開發文件導覽](../README.md)
