# 測試手則

這份手則用來維持目前的測試分層與命名一致，避免 `test/` 再度回到散落、重疊、難維護的狀態。程式碼與文案規範另見 [`AGENTS.md`](../AGENTS.md)。

## 分層原則

- `config`、`crypto`、`database`、`storage`、`vault` 等目錄：放最值得長期維護的核心規則。
- `features/<domain>/`：放該功能的 application / presentation 測試（unit、controller、widget），例如 `test/features/editor/editor_body_blocks_test.dart`。
- `infrastructure/`、`domain/`：放基礎設施與純領域邏輯測試。
- `helpers/`：測試支援層，依職責拆到 `shared`、`session`、`storage`、`vault`、`features/*`；不要堆在 `test/` 根目錄。
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
  - `鎖定且已連線時會停用帳號操作`
  - `在行末插入且後方還有內容時不會插入多餘空白行`
  - `刪除最後一個任務項目後會回到純文字編輯器`
- `group` 可用 API / 類別名稱（如 `insertCheckboxAtLineIndex`），但 `test` / `testWidgets` 內文仍用繁體中文描述行為。
- 避免含糊字眼，例如「正常」、「應該可以」、「測試一個功能」。

## 檔案與目錄

- 同一 domain 的測試放在 `test/features/<domain>/`（或對應的 `storage/`、`vault/` 等目錄）。
- 新增 helper 時先判斷 domain：
  - 跨測試主題：`test/helpers/app_test_theme.dart`、`test/helpers/shared/test_l10n.dart`
  - 單一功能：`test/helpers/features/<domain>/`，例如 `editor_test_scope.dart` 提供 `editorTestApp`、`pumpEditorHybridBody`
  - fake / stub：放在對應 domain 的 `helpers/features/<domain>/`，不要在各測試檔重複 `_wrap` 或自建 MaterialApp。
- 煙霧測試統一放在 `test/smoke/`；不要把完整 widget / controller 測試塞進 smoke，也不要把 smoke 案例散回各 domain。

## 執行方式

- 新增或搬移測試後，至少執行對應目錄一次，確認沒有 import 斷裂或命名誤植。
- 範例：

```powershell
# Cursor 可直接使用 flutter test
flutter test test/features/editor/

# Codex 請改用 AGENTS.md 中的 flutter-safe.ps1
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 test test/features/editor/
```

## 寫測試前先檢查

1. 這個測試是否已被其他更底層測試覆蓋。
2. 這個行為屬於核心規則、`features/<domain>`、`infrastructure`，還是 `smoke`。
3. 測試名稱是否直接說出條件與預期。
4. 是否使用現有的 helper（`editorTestApp`、`appTestTheme`、`FakeEditorActions` 等），而不是再造一份新的 fake 或 `_wrap`。
5. 是否真的需要新增測試；若只是重複驗證同一條規則，應刪除或合併（例如兩個 widget 測試都只驗證「backspace 刪除空任務項目」時，保留涵蓋範圍較完整的那一個）。

## 維護提醒

- 先整理結構與 helper，再處理重疊案例。
- 繁體中文字串要保留原文，不要轉成 escape 或亂改 encoding。
- 功能收斂或實驗回退後，記得同步刪除只服務舊方案的測試與 helper，避免測試繼續維護已不存在的 API。
