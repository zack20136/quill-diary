# QuillLockDiary

以 Flutter 撰寫的**離線優先**日記 App：正文以 Markdown 儲存在本機 vault，檔案在磁碟上皆為 **`LDJ2` 加密格式**；日常使用透過 Android 硬體保護的受信任裝置金鑰快速解鎖，必要時以 **Recovery Key（v2+，Argon2id）** 救援。

## 功能亮點

- **本地加密 vault**：日記為 `.md.enc`、附件為 `*.enc`，索引為 SQLite（可由加密檔重建）。
- **雙軌解密**：同一檔案的 `fileKey` 同時以「裝置槽（Keystore）」與「Recovery 槽」包裝，日常與換機兼得。
- **Recovery Key**：高熵隨機字串經 Argon2id 導出 *wrapping key*（非直接當對稱鑰 encrypt 正文）。
- **備份**：本機 `.jbackup` zip 快照、可上傳至 Google Drive（僅加密包）。
- **匯出**：在已解鎖 session 下匯出**明文** Markdown 目錄與附件副本（離開 vault）。

## 目前支援範圍

| 項目 | 說明 |
|------|------|
| **正式支援平台** | Android（裝置金鑰依 Android Keystore 橋接實作） |
| **加密格式** | 僅 `LDJ2` / Recovery Key **v2+** |
| **非 Android** | 不提供對應的裝置金鑰與資料操作 |
| **舊版 vault** | 不提供相容或 migration |

詳見 [`docs/文件索引.md`](docs/文件索引.md)。

## 執行與開發

```bash
flutter pub get
flutter run   # 目標請選 Android 裝置或模擬器
```

發行建置請使用一般 Flutter/Android 流程（例如 `flutter build apk`）。

> 本 repo 仍以產品行為與手動驗證為主；`flutter analyze` / `flutter test` 並非主要指標。

## Vault 在本機的路徑（摘要）

Application support 底下會有 `quill_lock_diary/`，其中 `vault/` 保存加密內容：

- `recovery.json` — vault 識別、Argon2id 參數與 hint（不含 Recovery Key 本體）
- `manifest.json.enc` — 摘要資訊的加密 Manifest，並用來**驗證**使用者輸入的 Recovery Key
- `entries/**.md.enc` — 加密日記正文（內為 YAML front matter + Markdown）
- `assets/**/*.enc` — 加密附件

同層另有：

- `index/journal_index.sqlite` — Drift/SQLite 索引（位於 vault 外）

## 安全與邊界（請一讀）

- **Recovery Key 不會完整寫入一般檔案**；請使用者自行離線備份 Recovery Key。
- **已解鎖裝置**上的惡意軟體（鍵盤、螢幕錄影）不在威脅模型內。
- Google Drive **只存放加密備份**，不代替 Recovery Key。
- Keystore／受信任資料損壞時，必須以 Recovery Key **重新註冊裝置**並觸發檔案的 **rewrap**（見文件）。

## 文件導覽

| 文件 | 用途 |
|------|------|
| [`docs/文件索引.md`](docs/文件索引.md) | `docs/` 目錄的文件導覽 |
| [`docs/google_drive_oauth_setup.md`](docs/google_drive_oauth_setup.md) | Google Drive 備份需要的 Android / iOS OAuth 設定 |
| [`docs/加密流程.md`](docs/加密流程.md) | LDJ2、`fileKey`、裝置槽與 Recovery 槽如何產出 |
| [`docs/解密流程.md`](docs/解密流程.md) | 信任裝置路徑與 Recovery Key 路徑如何取得 `fileKey` 並解密 |
| [`docs/其他主要流程.md`](docs/其他主要流程.md) | Session、驗證、rewrap、索引、備份／還原、匯出 |
| [`docs/產品與架構總覽.md`](docs/產品與架構總覽.md) | 專案定位、穩定架構決策、支援範圍與威脅模型 |
| [`docs/實作與資料設計.md`](docs/實作與資料設計.md) | 資料模型、front matter、路徑與實作邊界摘要 |

實際演算法與表位元組對應可對照：`lib/infrastructure/crypto/crypto_service.dart`、`lib/infrastructure/storage/vault_repository.dart`。
