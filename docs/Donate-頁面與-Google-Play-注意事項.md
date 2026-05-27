# Donate 頁面與 Google Play 注意事項

最後確認日期：2026-05-27

## 先講結論

- 你可以用 `Personal` 個人開發者帳號做 donate 相關功能。
- 但「能不能放 donate 頁面」不是只看帳號類型，而是看你的付款流程是否符合 Google Play Payments policy。
- 最安全的前提是：這個 donate 真的是**純贊助**，不是在賣 app 內數位功能、會員權益、去廣告、貼圖、徽章、早鳥內容或任何數位回饋。
- 如果 donate 付款後會讓使用者拿到任何 app 內數位好處，通常就不是單純 donate，而是**數位商品 / 數位服務交易**，必須走 Google Play Billing，否則有被下架或停權風險。

## 你可以用個人帳號嗎

可以。

Google Play 官方說明：

- `Personal` 和 `Organization` 帳號都可以營利
- `Personal` 適合個人使用、學生、興趣開發者、獨立開發者

所以如果這個 donate 是你個人作品的贊助頁，帳號類型本身不是阻礙。

但要注意：

- 如果你透過 Google Play 的付費 app 或 app 內購營利，會牽涉付款資料驗證
- 若你的 app 在 Google Play 上屬於「monetize」狀態，Google 可能會要求你建立 merchant / payments profile
- 官方也說 merchant 帳號的法定地址會顯示在 Google Play 上

換句話說：

- 單純個人帳號可以做
- 但如果走 Play Billing，會進入正式金流與商業資訊揭露範圍

## Donate 有哪幾種做法

### 1. 純贊助，完全沒有任何數位回饋

這是最接近「真正 donate」的情況。

官方 FAQ 提到：

- 如果是使用者直接給 creator 的 tip / contribution
- 且 **100% 款項都給 creator**
- 且 **付款不會換到任何數位內容或服務**
- 包括 stickers、badges、special emojis 這類都不行

那 Google 會把這類付款視為 `peer-to-peer payment`，不強制要求使用 Google Play Billing。

### 這代表什麼

如果你的 donate 頁面是：

- 支持作者
- 不解鎖任何內容
- 不去廣告
- 不加功能
- 不給特殊稱號
- 不給貼圖、徽章、感謝卡、會員權限

那它比較有機會被視為可接受的純贊助。

### 2. Donate 後給數位回饋

如果使用者 donate 後拿到任何數位利益，例如：

- 解鎖新功能
- 去廣告
- 額外主題
- 特殊徽章
- 會員標記
- 提前看內容
- 附加內容
- 在 app 內顯示「支持者專屬」效果

那實質上就不是純 donate，而是 app 內數位交易。

這種情況依 Google Play Payments policy，通常就必須使用 `Google Play Billing`。

### 3. 外部連結到 Patreon / Buy Me a Coffee / 綠界 / 你自己的網站

這種做法**不是一定不行**，但風險取決於它是不是符合前面那種「純贊助例外」。

如果你導出去的頁面是：

- 純贊助
- 不提供任何數位權益
- 100% 給創作者

那有機會符合政策例外。

但如果外部頁面其實是在賣：

- 會員
- 專屬內容
- app 內數位功能
- 解鎖碼
- 任何數位回饋

那就非常容易踩到「在 app 內導引用戶去外部付款購買數位內容」的政策紅線。

## 哪些做法最容易被鎖 / 被下架

以下是高風險做法：

- 在 donate 按鈕背後賣 `去廣告`
- donate 後解鎖 `Premium`
- donate 後送 app 內徽章、貼圖、special emoji、稱號
- 在 app 內明確引導使用者去外站購買 app 內數位功能
- 用「贊助」包裝，實際上是賣數位會員或功能
- 商店頁、app 文案、Data safety、隱私權政策彼此說法不一致

### 為什麼風險高

官方 Payments policy 明講：

- Play app 內若要求或接受付款來取得 app 功能、數位內容、數位服務，原則上必須使用 Google Play Billing
- 除了明確例外情況外，app 不得在 app 內把使用者導向其他付款方式

所以最容易出事的，不是「有 donate 頁」本身，而是：

- donate 和 app 內功能之間有沒有交換關係
- 你是不是在規避 Google Play Billing

## 你如果只想放一個安全的 Donate 頁，建議怎麼做

### 建議做法

- donate 文案只寫「支持開發者 / 支持專案」
- 明確寫出「贊助不會解鎖任何 app 功能或數位內容」
- 贊助後 app 體驗完全不改變
- 不要給 app 內徽章、稱號、特效、會員頁
- 不要寫成「升級」「解鎖」「支持者版」「去廣告方案」
- 若要外連付款頁，目的地要清楚、單純、可預期

### 建議避免

- donate 與 app 內權益綁在一起
- donate 方案價格對應功能等級
- 在 app 內做太像商城或付費升級的 UI
- 在商店頁寫「可贊助解鎖更多功能」

## 如果我要做 Donate 頁，我需要準備什麼

## 1. 先決定 donate 的性質

先把這件事講清楚：

- 是純贊助
- 還是實際上要賣數位功能

這是最重要的分界線。

### 若是純贊助

你要準備：

- 一段很明確的文案，說明「不提供任何數位回饋」
- 一個安全的付款目的地
- 隱私權政策 / 支持頁面 / FAQ 說明
- 必要時的審核說明，避免 Google 誤判你在賣數位服務

### 若是賣數位功能

你要準備：

- Google Play Billing 整合
- Play Console 產品設定
- payments / merchant profile
- 定價、退款、稅務、產品說明

而這時候就不應再用「只是 donate」的心態設計它。

## 2. 付款目的地

若走純贊助外部付款，常見會是：

- 自己網站
- Patreon
- Buy Me a Coffee
- 其他收款平台

你要確認：

- 付款頁是 HTTPS
- 不會誤導到別的頁面
- 付款頁不會宣稱會提供 app 內數位權益
- 付款頁條款、退款、聯絡方式清楚

## 3. app 內文案

建議至少準備：

- donate 頁標題
- 一段明確說明
- 一段政策風險最低的提示文

### 建議文案方向

可以寫：

- 支持這個專案持續開發
- 贊助不會解鎖任何功能
- 這是一筆自願支持，不影響 app 使用權限

不要寫：

- 升級支持者版
- 贊助解鎖更多功能
- 斗內後獲得專屬標記
- 付費支持即可去廣告

## 4. 隱私權政策與說明頁

如果 donate 會跳到外部頁面，建議至少準備：

- 誰在收款
- 收款平台是誰
- 哪些資料會被外部平台處理
- 如有退款或客服方式，要怎麼聯絡

如果你 app 本身不處理信用卡資料，也要寫清楚：

- 支付資料由外部平台處理
- app 不直接儲存付款卡號

## 5. Play Console / 商店頁要注意什麼

### 不要在商店頁暗示數位功能交易

如果是純 donate：

- 商店頁不要寫成付費升級
- 不要寫出像 subscription / premium unlock 的描述
- 不要讓 Google 認為你在規避 Play Billing

### App access / 審核說明

如果 donate 頁隱藏很深，通常問題不大。

但如果 donate 頁：

- 是主畫面重要入口
- 有登入流程
- 會跳外站
- 有多層付款說明

建議在送審時準備一段簡短說明：

- 這是自願性支持頁
- 不提供任何數位內容、功能或會員權益
- 付款由外部服務處理

## 6. 稅務與收款現實問題

如果你只是把人導到外部 donate 平台：

- Google Play 不一定會替你處理那筆款項
- 稅務、發票、平台抽成、收款身分、退款流程，通常要看你用的外部平台

如果你改走 Google Play Billing：

- 你要準備 payments profile / merchant 設定
- 可能需要驗證付款方式
- 法定地址可能會顯示在 Google Play

## 7. 用個人帳號做 donate，會不會被鎖

### 短答案

- `Personal` 帳號本身不會因為 donate 就自動被鎖
- 真正風險在於你有沒有違反 Payments policy

### 高風險情況

最容易被判違規的是：

- 你用 donate 名義繞過 Google Play Billing
- 你把外部付款和 app 內數位功能綁在一起
- 你在 app 內明確引導用戶去外部付款買 app 內好處

### 低風險情況

比較低風險的是：

- donate 是自願支持
- 沒有任何數位權益
- 文案寫得很清楚
- 外部頁面也沒有偷偷賣 app 內功能

### 仍然要注意

即使你主觀上覺得只是 donate，Google 審核仍可能從以下角度判斷：

- UI 是否像付費升級
- 外部頁面是否實際賣數位內容
- donate 後 app 體驗是否改變
- 文案是否暗示有交換價值

所以不能只靠「我叫它 donate」來降低風險。

## 8. 我對這個專案的建議

如果你這個 app 想加 donate 頁，我建議先選一種，不要混：

### 路線 A：純贊助頁

適合你只是想讓人支持開發。

建議規則：

- donate 不解鎖任何功能
- donate 後 app 完全不變
- 文案明確寫「不提供數位回饋」
- 可以外連到支持頁
- 不要把 donate 做成 Premium、會員或功能包

### 路線 B：正式付費功能

適合你其實想賣：

- 去廣告
- 雲端功能
- 額外主題
- 支持者徽章
- Premium 功能

這種就不要假裝 donate，應直接走：

- Google Play Billing
- 明確產品定義
- Play Console monetization 設定

## 9. 實作前檢查清單

在你開始做 donate 頁之前，先回答這些問題：

- 付款後，使用者會不會拿到任何 app 內功能？
- 付款後，使用者會不會拿到任何視覺徽章或特殊身分？
- 付款頁是不是在賣數位權益？
- donate 文案會不會讓審核覺得是付費升級？
- 如果 Google 審核問你這頁用途，你能不能一句話說清楚？

如果以上任何一題答案偏向「會」，就不要把它當成純 donate 頁。

## 10. 建議的文件與準備物

如果你要上這個功能，建議至少準備：

- 一份 donate 頁 UI 文案
- 一份審核用說明文字
- 一份隱私權政策補充
- 一份對外支持頁 / FAQ
- 一份內部判斷紀錄，寫清楚：
  - 是否提供數位權益
  - 是否使用外部付款
  - 是否需要 Google Play Billing

## 11. 官方參考資料

- Payments policy  
  [Payments](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en)
- Payments policy FAQ  
  [Understanding Google Play’s Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)
- 帳號類型  
  [Choose a developer account type](https://support.google.com/googleplay/android-developer/answer/13634885?hl=en-EN)
- 建立帳號與 payments profile  
  [Required information to create a Play Console developer account](https://support.google.com/googleplay/android-developer/answer/13628312?hl=en)
- 已驗證帳號顯示資訊  
  [View and manage your developer account information](https://support.google.com/googleplay/android-developer/answer/13634081?hl=en)

## 12. 最實際的決策建議

如果你只是想讓使用者單純支持你：

- 用個人帳號可以
- 做純 donate 頁可以
- 但不要提供任何 app 內數位回饋

如果你其實想把 donate 當成支持者功能包：

- 不要走外部 donate 偽裝
- 直接規劃成正式 app 內購
- 用 Google Play Billing 做

這樣最不容易被審核打回或後續出政策問題。
