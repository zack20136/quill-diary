# Google Play 上架

這份文件整理 Quill Diary 目前的 Google Play 上架重點，包括帳號型態、測試門檻、簽章、AAB 與送審前整備。

## 目前結論

- 可以用個人帳號上架
- 新個人帳號正式上架前，通常要先完成封閉測試門檻
- 正式送審應使用 `AAB`
- 送審前要再次確認 `targetSdk` 與當期 Play 要求一致

## 帳號型態

### `Personal`

適合：

- 個人作品
- 小型獨立開發
- 沒有公司主體

注意：

- 可以營利
- 若有營利，Google Play 會顯示完整地址
- 新個人帳號通常要先完成 `12 位 tester / 14 天` 的封閉測試

### `Organization`

適合：

- 公司或品牌名義上架
- 未來會多人協作
- 不想直接以個人身分出現在商店頁

## 上架前要準備什麼

- Google Play 開發者帳號
- 已完成驗證的 payments profile
- release 簽章
- `AAB`
- 商店頁素材
- 隱私權政策
- Data safety
- Content rating
- App access 說明

## 與這個專案直接相關的點

這個專案目前有：

- Google Sign-In
- Google Drive 備份
- 本機解鎖流程
- 圖片與附件選取
- 支持開發者（Google Play Billing）

所以上架時要特別對齊：

- Data safety
- 隱私權政策
- App access
- 權限用途說明
- Billing 商品、付款描述與支持頁文案

## 簽章

Android release 目前需要正式簽章。

至少要有：

- `android/key.properties`
- 對應 keystore

參考檔案：

- [`android/key.properties.example`](../../../android/key.properties.example)

## 該如何做

1. 決定使用 `Personal` 或 `Organization` 帳號
2. 準備並驗證 payments profile
3. 確認 release 簽章與 keystore 可正常使用
4. 確認正式產物是 `AAB`
5. 準備商店頁素材、隱私權政策、Data safety、Content rating、App access
6. 檢查 `package name`、`versionCode`、`targetSdk`
7. 若是新個人帳號，先完成封閉測試門檻
8. 最後再送審

## 隱私權政策 URL

Play Console「Privacy policy」欄位請填入：

`https://zack20136.github.io/quill-diary/privacy-policy`

來源文件：[docs/privacy-policy.md](../../privacy-policy.md)

**維護注意**：公開 URL 以 `AppIdentifiers.privacyPolicyUrl` / `thirdPartyNoticesUrl` 為準；頁面原始檔在 `docs/` 根目錄。開發文件在 `docs/介紹/`（Jekyll 已 exclude，不會發布）。

### 啟用 GitHub Pages

1. 確認 GitHub repo 為 **public**（Pages 網址須與 `AppIdentifiers` 中的 repo 名稱一致，目前為 `quill-diary`）
2. 進入 repo **Settings → Pages**
3. Source 選 **Deploy from a branch**
4. Branch 選 `main`，資料夾選 **`/docs`**
5. 儲存後等待數分鐘，用瀏覽器確認下列 URL 可開啟：
   - `https://zack20136.github.io/quill-diary/`
   - `https://zack20136.github.io/quill-diary/privacy-policy`
   - `https://zack20136.github.io/quill-diary/third-party-notices`
6. App 內亦可從設定頁進入「隱私權政策」

## 最小檢查清單

- `package name` 已定案
- `versionCode` 會遞增
- release 簽章可正常產出
- `AAB` 可成功建置
- 商店頁文案完成
- 隱私權政策可公開訪問（`https://zack20136.github.io/quill-diary/privacy-policy`）
- Data safety 已填
- Content rating 已填
- App access 已填
- 封閉測試門檻已達成

## 官方參考

- [Choose a developer account type](https://support.google.com/googleplay/android-developer/answer/13634885?hl=en-EN)
- [Required information to create a Play Console developer account](https://support.google.com/googleplay/android-developer/answer/13628312?hl=en)
- [Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en)
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en-EN)
- [Target API level requirements for Google Play apps](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)

---

[← 返回 Google 文件](./README.md)
