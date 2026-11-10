# Google Play Billing

Billing 僅提供 Google Play 一次性支持，不訂閱、不解鎖功能、不保存永久權益，也不讀取日記。流程在裝置端處理，沒有自家後端驗單或跨裝置權益同步。

## 商品與顯示

[`billing_catalog.dart`](../../../lib/infrastructure/billing/billing_catalog.dart) 固定順序為 `sponsor_coffee`、`sponsor_snack`、`sponsor_lunch`、`sponsor_boost`、`sponsor_super`。Console 建立相同 ID 的一次性商品，App 以 consumable 流程支援重複購買，顯示 Play 回傳的 title、description、price。

### Play Console 設定步驟

1. 在 `zack20136.com.quill_diary` 建立上述五項商品，ID 大小寫須一致；設定標題、描述、售價、地區並啟用購買選項。
2. 建議標題依序為「請我喝杯咖啡」、「請我吃點心」、「請我吃午餐」、「給開發一點鼓勵」、「大力支持開發」；描述明示「一次性支持 Quill Diary 開發，不含訂閱或額外功能」。
3. 上傳簽章版至測試軌道，分別設定測試人員與 license testers；兩者不同，非測試付款方式可能真實扣款。
4. 從 Play 安裝，確認五項商品與在地化價格，測試購買、取消及再次購買。

帳戶、測試付款與 Billing Lab 操作見[官方測試指南](https://developer.android.com/google/play/billing/test)；widget mock 不能取代實際交易驗收。

## 交易生命週期

App 啟動透過 `sponsorBillingLifecycleProvider` 初始化 [`GoogleBillingService`](../../../lib/infrastructure/billing/google_billing_service.dart)：檢查可用性、訂閱 `purchaseStream`、呼叫 `restorePurchases()` 接手未完成交易。商品查詢與新購買由各自入口啟動，不會自動購買；隱私政策與 Data safety 須揭露啟動互動。

| 狀態 | 處理 |
|------|------|
| `pending` | 顯示等待 |
| `error`、`canceled` | 顯示對應結果並解除等待 |
| `purchased`、`restored` | 最終處理；成功後顯示感謝 |

購買使用 `buyConsumable(autoConsume: false)`；Android 先 `consumePurchase()`，再依 `pendingCompletePurchase` 呼叫 `completePurchase()`。時限及退款規則見[套件文件](https://pub.dev/packages/in_app_purchase)與[Play 商品生命週期](https://developer.android.com/google/play/billing/lifecycle/one-time)。

目前裝置端方案適用於不建立永久權益的支持用途。若改成解鎖功能、保存權益或高價值商品，須依[Play 安全建議](https://developer.android.com/google/play/billing/security)重新設計驗證與後端，並同步隱私政策及商店說明。

consume／complete 失敗會回報錯誤，後續初始化接手未完成交易；已消耗的支持不會恢復成永久紀錄或跨裝置支持歷史。

## 審查與資料揭露用說明

> 支持開發者是自願的一次性購買，不含訂閱或功能解鎖。商品、價格與付款由 Google Play 提供，App 在裝置端完成交易，不建立自家帳戶、付款資料庫或跨裝置權益。

Billing 回呼的商品、交易識別及 SDK 資料處理仍須納入 Data safety。商品不得描述為慈善捐款或永久解鎖。

## 商品載入失敗排查

| 狀況 | 優先檢查 |
|------|------|
| Billing 不可用 | 裝置是否有可用 Play 商店、目前帳戶與網路狀態 |
| `no_products`／部分商品未找到 | `notFoundProductIds`、商品 ID、啟用狀態、地區及實際發布的 App |
| `query_failed`／`init_failed` | Play 服務、帳戶與網路；重試初始化，不直接改商品 ID |
| 只能購買一次 | consume 是否成功，之後的 complete 是否仍待處理 |
| Debug 正常但測試軌道異常 | 安裝來源、套件名稱、選取的付款帳戶與 license tester 設定 |

組裝見 [`billing_providers.dart`](../../../lib/application/settings/billing_providers.dart)，畫面見 [`support_page.dart`](../../../lib/presentation/settings/pages/support_page.dart)。

## 發布驗證

- 五項商品可查詢，顯示順序與在地化價格正確。
- 等待、取消、錯誤、成功與 restored 均可收尾。
- consume／complete 成功後可再次購買，重新啟動可接手未完成交易。
- 付款由 Play 處理，App 不保存付款憑證或支持紀錄作為永久權益。

權限見[Android 權限與資料揭露](Android-權限與資料揭露.md)，公開說明見[隱私權政策](../../privacy-policy.md)。

[← 返回開發文件導覽](../README.md)
