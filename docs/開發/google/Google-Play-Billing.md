# Google Play Billing

這份文件整理 Quill Diary 目前的 Google Play Billing 實作方式、商品設定原則與送審時需要對齊的邊界。內容以現有程式碼為準。

## 目前實作摘要

Quill Diary 的 Billing 流程目前是：

- 只支援 Google Play
- 只做一次性贊助購買
- 不提供訂閱
- 不解鎖額外功能
- 不依賴自家後端驗單或權益同步

程式設計上屬於 client-only 的一次性贊助流程。

## 商品 ID

目前程式碼內建的商品順序如下：

1. `sponsor_coffee`
2. `sponsor_snack`
3. `sponsor_lunch`
4. `sponsor_boost`
5. `sponsor_super`

來源：

- [billing_catalog.dart](../../../lib/infrastructure/billing/billing_catalog.dart)

Play Console 內商品 ID 必須與這份清單完全一致。

## 商品型態與購買方式

目前 App 使用：

- `buyConsumable(autoConsume: false)`

完成購買後，再由 Android 端主動執行：

- `consumePurchase(...)`
- `completePurchase(...)`

這代表目前設計是：

- 商品在 Play Console 應建立為一次性商品
- App 端把它當成可重複購買的 consumable 贊助項目處理

## 啟動與商品載入流程

`GoogleBillingService.initialize()` 目前會：

1. 檢查 Billing 是否可用
2. 訂閱 `purchaseStream`
3. 呼叫 `restorePurchases()`

之後商品清單透過：

- `queryProductDetails(BillingConfig.sponsorProductIds)`

載入，再依 `sponsorProductIdsOrdered` 排序給 UI 顯示。

這表示：

- App 啟動時會先接手未完成交易
- 商品順序不是 Play Console 回傳順序，而是程式碼固定順序

## UI 顯示邏輯

贊助頁不自訂固定價格字串，主要使用 Play 回傳的在地化內容：

- `product.title`
- `product.description`
- `product.price`

因此文件或商店說明不應把固定金額寫死成系統真相；真正顯示給使用者的是 Play Console 當下商品設定與地區化價格。

## 購買狀態處理

目前程式碼會處理：

- `pending`
- `error`
- `canceled`
- `purchased`
- `restored`

其中：

- `purchased` 會進入最終處理
- `restored` 也會進入最終處理

最終處理在 Android 上會先 consume，再視需要 complete，完成後把 UI 狀態切到 `thanks`。

## 隱私與資料邊界

從文案與流程可以確認目前邊界是：

- 付款由 Google Play 處理
- App 不保存贊助紀錄作為永久權益
- App 不因贊助解鎖功能
- 贊助流程不會讀取日記 vault 內容

這些敘述已反映在設定頁文案與隱私政策，送審與商店說明要保持一致。

## Play Console 商品設定原則

建立商品時，至少要保持以下一致：

- 商品 ID 與程式碼一致
- 商品已啟用
- 型態符合一次性贊助用途
- 商品標題與描述不要宣稱訂閱、會員、Premium 權益或功能解鎖

適合的描述方向：

- 一次性支持
- 贊助開發
- 不含額外功能

避免的描述方向：

- 訂閱
- 會員
- 解鎖進階功能
- 去廣告權益

## 建議測試重點

上架或改商品前，至少檢查：

1. 五個商品都能成功查到
2. 商品顯示順序符合程式碼
3. 購買成功後會進入 `thanks`
4. `pending`、取消、錯誤狀態都有合理回饋
5. consume + complete 後可再次購買
6. `restorePurchases()` 不會造成重複錯誤狀態

## 變更前必查

只要碰到下列變更，就應同步更新這份文件、隱私政策與商店說明：

- 商品 ID 清單改動
- Billing 型態從 consumable 改成 non-consumable 或 subscription
- 新增後端驗單、權益同步或贊助紀錄保存
- 贊助後解鎖功能
- UI 不再使用 Play 回傳的 title/description/price

## 參考實作

- [google_billing_service.dart](../../../lib/infrastructure/billing/google_billing_service.dart)
- [billing_catalog.dart](../../../lib/infrastructure/billing/billing_catalog.dart)
- [billing_providers.dart](../../../lib/application/settings/billing_providers.dart)
- [support_page.dart](../../../lib/presentation/settings/pages/support_page.dart)
- [privacy-policy.md](../../privacy-policy.md)

---

[返回開發文件索引](../README.md)
