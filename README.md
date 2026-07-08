# Quill Diary

Quill Diary 是一款為 Android 設計的離線加密日記 App。

它把重點放在一件事上：讓你能安心記錄真正私密的內容，而且資料始終由你自己掌握。

## 核心特色

- 本機加密保存日記，內容不以明文形式留在裝置上
- 首次使用須建立復原金鑰後，才能讀寫日記庫
- 支援裝置信任與復原金鑰，兼顧日常解鎖速度與資料救援能力
- 解鎖後即可全文搜尋，快速找回過去的片段、標籤與關鍵字
- 支援 Google Drive 備份與還原，可將完整加密備份上傳到雲端保存
- 提供 Markdown 日記編輯器與草稿機制，支援任務清單互動編輯與預覽，編輯中斷後也能接續完成
- 提供個人化設定，可調整自動鎖定、主題顏色、圖片品質與日記排版
- 支援完整備份與還原，保留整個日記庫的結構與內容
- 支援可攜式匯入與匯出，方便整理、搬移或轉存日記資料
- 提供「支持開發者」頁面，透過 Google Play 一次性支持，不解鎖任何額外功能

## 為什麼它不一樣

多數筆記或日記工具把同步與雲端放在第一位，Quill Diary 則把私密性與本機掌控放在前面。

這個專案不是把加密當成附加功能，而是從日記建立、解鎖、搜尋、編輯到備份，都圍繞同一套本機保護邏輯來設計。

你可以把它理解成：

- 一個真的以私人日記為核心的 App
- 一個可以搜尋、備份、還原、匯出的加密資料庫
- 一個在日常使用與資料安全之間取得平衡的離線工具

## 平台

目前僅支援 Android。

## 文件入口

想了解架構、解鎖流程、加密格式、索引、備份與編輯器（含混合編輯、任務清單與預覽）行為，請從 [docs/介紹/文件目錄.md](docs/介紹/文件目錄.md) 進入。

Google Drive、Google Play、權限揭露與 Billing 相關整備，請看 [docs/介紹/google/README.md](docs/介紹/google/README.md)。

文件與程式碼不一致時，以 `lib/` 內實作為準。

## 授權與贊助

- 原始碼以 [GNU Affero General Public License v3.0](LICENSE)（AGPL-3.0）發布。若你修改並發布本程式（含 App 發行），須以相同授權公開對應的完整原始碼。
- 第三方字體與依賴套件聲明：[docs/third-party-notices.md](docs/third-party-notices.md)
- **Quill Diary** 名稱、圖示與 Google Play 商店 listing 為作者品牌，不隨程式碼授權一併轉讓。
- App 內「支持開發者」為自願贊助，不解鎖任何額外功能。若需閉源商用授權，請透過 [GitHub Issues](https://github.com/zack20136/quill-diary/issues) 聯絡作者。

## 隱私權政策

- 完整文字：[docs/privacy-policy.md](docs/privacy-policy.md)
- 公開網頁（Google Play 送審與 App 內連結）：<https://zack20136.github.io/quill-diary/privacy-policy>
- App 內亦可從設定頁進入「隱私權政策」
