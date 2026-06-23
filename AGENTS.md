# Agent 工作指引

本檔整理本專案對不同代理工具的工作規範。

## 全域要遵守

### 程式碼與架構

- 優先簡單、乾淨、好維護的設計；可讀性與長期維護性高於短期相容性。
- 接受破壞性修改：必要時可改 API、搬檔案、刪除多餘抽象，不必為了少改幾行而保留混亂結構。
- 積極重新命名：變數、函式、檔案、模組名稱若不能一眼看懂用途，就改名並更新所有引用；除非有明確過渡需求，不要保留 alias 或 deprecated 包裝。
- 避免過度抽象：不要為一兩行程式抽 helper、不要堆多餘介面層；先讀周邊慣例再動手，改動應像同一作者寫的。
- 變更範圍仍應對準任務：沒被要求時不要順手大改無關檔案；但若重構是完成任務的最簡路徑，可以直接做。

### 繁體中文

- 本專案 UI 文案以繁體中文為主，集中管理於 `lib/l10n/*.arb`，並透過 `context.l10n` / `AppLocalizations` 取用。
- 以 UTF-8 原文保留繁體中文；禁止把中文「修正」成 escape、HTML entity 或 `\uXXXX`，除非該檔案已有且必須保持一致。
- 不要把正常繁體字串當成 encoding 錯誤去替換、轉碼或刪除；若看到疑似亂碼，先確認是否只是顯示問題。
- 新增或修改 UI 字串時，放入對應的 ARB key，維持單一文案來源。
- 與使用者溝通時，若無特別要求，使用繁體中文回覆。

### 實務取向

- 能刪就刪：死碼、重複 widget、過時分支，清理優先於堆疊 workaround。
- 重構後確保引用與測試同步更新；不要留下半套 rename 或 broken import。
- 註解只解釋非 obvious 的業務邏輯；程式本身應能自我說明。

## Cursor 要遵守

- 遵守以上全域規範。

## Codex 要遵守

- 遵守以上+以下全域規範。

### Flutter 指令

本專案中的 Flutter 指令不要直接呼叫 `flutter ...`。

原因：
- 在這個 Windows / Codex 受管環境中，`flutter.bat` 容易殘留 `cmd.exe`、`dart.exe` 與 Flutter SDK cache lock 檔，造成後續指令卡住。

一律改用以下安全入口執行 Flutter：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 <flutter-args>
```

範例：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 --version
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 doctor -v
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 test
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 pub get
powershell -ExecutionPolicy Bypass -File .\tool\flutter-safe.ps1 run -d chrome
```

補充：
- 若先前有人直接執行過 `flutter ...` 而導致 lock 殘留，優先重新使用 `.\tool\flutter-safe.ps1`，不要再直接重跑 `flutter.bat`。
- 若需要診斷 Flutter 問題，先回報目前是否存在 `C:\Users\0219\flutter\bin\cache\lockfile` 與 `flutter.bat.lock`。
