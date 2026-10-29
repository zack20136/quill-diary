# 開發文件導覽

先讀[系統架構](架構/系統架構.md)，需要查型別、Provider 或服務時使用[模組參考](架構/模組參考.md)。各主題文件描述資料流程與重要規則；實作與文件不一致時，以程式碼校正文件。

| 分類 | 文件 |
|------|------|
| 架構 | [系統架構](架構/系統架構.md)、[模組參考](架構/模組參考.md) |
| 安全 | [解鎖與會話](安全/解鎖與會話.md)、[加密格式](安全/加密格式.md) |
| 資料 | [索引資料庫](資料/索引資料庫.md) |
| 功能 | [首次啟動](功能/首次啟動.md)、[日記編輯器](功能/日記編輯器.md)、[AI 聊天日記](功能/AI-聊天日記.md)、[人物與姓名查詢](功能/人物與姓名查詢.md)、[個人化設定](功能/個人化設定.md) |
| 資料轉移與維護 | [備份與還原](功能/備份與還原.md)、[日記庫檢查與修復](功能/日記庫檢查與修復.md) |
| Google 與發布 | [Android 權限與資料揭露](google/Android-權限與資料揭露.md)、[Google Drive OAuth 設定](google/Google-Drive-OAuth-設定.md)、[Google Play 上架](google/Google-Play-上架.md)、[Google Play Billing](google/Google-Play-Billing.md) |

專案規範見 [AGENTS.md](../../AGENTS.md)，測試分層與執行方式見[測試手則](../../test/test-handbook.md)。Codex 執行 Flutter 必須使用 `tool/flutter-safe.ps1`。

開發文件保留資料格式、狀態轉換、失敗清理與程式入口；Google 文件另外提供設定步驟、實機驗收、Console 填寫依據及審查說明。上架總入口是 [Google Play 上架](google/Google-Play-上架.md)，其中也列出尚需完成的送審條件；文件底稿不代表 Console 或實機驗證已完成。

本目錄由 `docs/_config.yml` 排除，不會發布至 GitHub Pages。公開文件為[首頁](../index.md)、[隱私權政策](../privacy-policy.md)與[第三方聲明](../third-party-notices.md)。
