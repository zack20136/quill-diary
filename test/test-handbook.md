# 測試手則

這份手則用來維持目前的測試分層與命名一致，避免 `test/` 再度回到散落、重疊、難維護的狀態。程式碼與文案規範另見 [`AGENTS.md`](../AGENTS.md)。

## 分層原則

- `application/`：放 flow、controller、coordinator、provider wiring 等流程協調測試。
- `presentation/`：放 page、widget、presentation state 與 feature-local provider 測試。
- `infrastructure/`、`domain/`、`shared/`：放基礎設施、純領域邏輯與跨功能純規則測試。
- `helpers/`：測試支援層，依職責拆到 `shared`、`session`、`storage`、`vault`、`presentation/*`；不要堆在 `test/` 根目錄。
- `smoke/`：只保留少量 app / 跨模組煙霧案例，不承擔核心規則與細部互動驗證。
- 若某個測試同時驗證多個職責，優先下放到更底層，或拆成更小的測試。

### 單元測試 vs widget 測試

- **單元測試**：驗證純函式、資料轉換、狀態規則，不依賴 widget tree。例：`editor_body_blocks_test.dart` 驗證 `insertCheckboxAtLineIndex`、`tailLinesAfterCheckboxInsert`。
- **Widget 測試**：驗證 UI 整合、焦點、鍵盤、模式切換等單元測試難覆蓋的行為。例：`editor_hybrid_body_test.dart` 驗證刪除最後一個任務項目後回到純文字編輯器。
- 同一條規則不要 unit 與 widget 各寫一份幾乎相同的案例；widget 測試應聚焦「整合後才有的差異」。

## 命名原則

- 測試名稱以繁體中文為主，直接描述行為與結果。
- 名稱要能看出場景、條件、預期，例如：
  - `正確復原金鑰可通過驗證`
  - `鎖定且已連線時會停用帳戶操作`
  - `在行末插入且後方還有內容時不會插入多餘空白行`
  - `刪除最後一個任務項目後會回到純文字編輯器`
- `group` 可用 API / 類別名稱（如 `insertCheckboxAtLineIndex`），但 `test` / `testWidgets` 內文仍用繁體中文描述行為。
- 避免含糊字眼，例如「正常」、「應該可以」、「測試一個功能」。

## 檔案與目錄

- 同一 domain 的測試放在 `test/application/<domain>/`、`test/presentation/<domain>/`，或對應的 `test/infrastructure/*`、`test/domain/`、`test/shared/`。
- 新增 helper 時先判斷 domain：
  - 跨測試主題：`test/helpers/app_test_theme.dart`、`test/helpers/shared/test_l10n.dart`
  - 單一功能：`test/helpers/presentation/<domain>/`，例如 `editor_test_scope.dart` 提供 `editorTestApp`、`pumpEditorHybridBody`
  - fake / stub：放在對應 domain 的 `helpers/presentation/<domain>/`，不要在各測試檔重複 `_wrap` 或自建 MaterialApp。
- 煙霧測試統一放在 `test/smoke/`；不要把完整 widget / controller 測試塞進 smoke，也不要把 smoke 案例散回各 domain。

## 執行方式

- 新增或搬移測試後，至少執行對應目錄一次，確認沒有 import 斷裂或命名誤植。
- 範例：

```powershell
# Cursor 可直接使用 flutter test
flutter test test/application/editor/

# Codex 請改用 AGENTS.md 中的 flutter-safe.ps1
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 test test/application/editor/
```

## 寫測試前先檢查

1. 這個測試是否已被其他更底層測試覆蓋。
2. 這個行為屬於核心規則、`test/application/<domain>`、`test/presentation/<domain>`、`infrastructure`，還是 `smoke`。
3. 測試名稱是否直接說出條件與預期。
4. 是否使用現有的 helper（`editorTestApp`、`appTestTheme`、`FakeEditorActions` 等），而不是再造一份新的 fake 或 `_wrap`。
5. 是否真的需要新增測試；若只是重複驗證同一條規則，應刪除或合併（例如兩個 widget 測試都只驗證「backspace 刪除空任務項目」時，保留涵蓋範圍較完整的那一個）。
6. 這個測試會在哪個行為被改壞？若答案只是某個預設值、文案、清單或常數的內容，就不要寫。
7. 量測對話框或捲軸時，以使用者看得到的表面為準（例如外層 Dialog 或可見的 thumb），不要只量內層透明元件。

## 不寫的測試

以下測試只會在目錄、文案或常數變動時壞掉，不保護任何行為：

- **預設值與目錄內容**：斷言預設模型、預設選項、預設色票、預設標籤。預設改動屬於產品決策；要驗證的是「未儲存時會套用目錄預設」這類行為，用 `defaultConnection(...)` 等屬性驗證，不寫死 ID。
- **完整清單或排序**：整份模型清單、分頁標題、section 標題的逐項比對。改用數量、相對順序或屬性（例如「啟用的模型排在前面」）。
- **只為確認文案存在的斷言**：用字面句子或 ARB 值逐字比對文案，文案一改就失效。需要顯示錯誤或提示時，改用 `testL10n.<key>` 參照，且只在行為需要被看見時寫。
- **常數回射與平凡 getter**：資料表、色票或路由字串的內容，純布林組合，純 `copyWith` 或建構子預設值。
- **配色與間距回射**：主題色票、圖示前景、圓角、內距、對話框寬度百分比、卡片高度。改外觀不該讓測試失敗。
- **只為確認不 overflow 的字級矩陣**：同一組按鈕在多種寬度與字級各點一次，且沒有新的互動規則。留下一個會真的擋操作的邊界即可。
- **同一規則的重複案例**：同一輸入與輸出在單元與 widget、或兩個檔案中各寫一次。Widget 測試只留畫面上才看得到的差異，例如按鈕是否出現、捲動是否跟手、鎖定後是否清掉輸入；控制器已經鎖住的規則不要再寫一份。

例外：隱私代號 `⟦P…⟧` 的規則句、資料格式的往返、遷移與損壞拒讀，即使看起來像文案或預設值也要保留。

## 守門測試

`test/meta/test_hygiene_test.dart` 會掃描所有 `*_test.dart`，擋下以下寫法：

- `defaultConnection(...)` 等讀取目錄預設的 `expect`，同時寫死目錄模型 ID。
- 同一個 `expect` 寫死三個以上目錄模型 ID（完整清單）。
- `expect` 內的字串與 `lib/l10n/*.arb` 某個文案相同（含中文或空白、12 字以上）。

被擋下時先改寫成行為斷言或 `testL10n.<key>` 參照。確實需要例外時，在守門測試的 `_allowedViolations` 附上理由，不要刪除規則本身。

## 相容性與生命週期案例

- 索引 schema 升級不能只對目前 schema 呼叫初始化。測試應先建立前一版真實缺欄/缺表形狀、插入既有資料，再由新版開啟，確認結構補建且原資料保留。
- 完整備份結構若新增正式資料，至少要有「建立資料 → 建立備份 → 修改現況 → 還原」的 round-trip，確認還原的是備份當下內容，且仍可正常解密與查詢。
- lazy provider 或保留式分頁的 widget 測試應同時覆蓋啟動前不讀取、首次進入才讀取，以及離開後是否依產品策略保留或釋放，避免只驗證畫面文字。

## 維護提醒

- 先整理結構與 helper，再處理重疊案例。
- 繁體中文字串要保留原文，不要轉成 escape 或亂改 encoding。
- 功能收斂或實驗回退後，記得同步刪除只服務舊方案的測試與 helper，避免測試繼續維護已不存在的 API。
