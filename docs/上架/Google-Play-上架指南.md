# Google Play 上架指南

最後更新：2026-05-27

## 結論

- 可以用個人帳號上架。
- 新個人帳號正式上架前，要先完成封閉測試門檻。
- 正式送審請用 `AAB`，不是 `APK`。
- 這個專案目前 Android `targetSdk` 已符合 Google Play 對 `API 35+` 的要求。

## 帳號怎麼選

### `Personal`

適合：

- 個人作品
- 小型獨立開發
- 沒有公司主體

注意：

- 可以營利
- 如果有營利，Google Play 會顯示完整地址
- 新個人帳號通常需要先做 `12 位 tester / 14 天` 的封閉測試

### `Organization`

適合：

- 公司或品牌名義上架
- 未來會多人協作
- 不希望個人身分直接掛在商店頁

## 上架前要準備什麼

- Google Play 開發者帳號
- 已完成驗證的 payments profile
- App 簽章設定
- release 用 `AAB`
- 商店頁素材
- 隱私權政策
- Data safety
- Content rating
- App access 說明

## 簽章

這個專案的 Android release 目前要求正式簽章。

至少需要：

- `android/key.properties`
- 對應 keystore

參考：

- [key.properties.example](C:/Users/0219/Projects/00/quill-diary/android/key.properties.example)

## 送審格式

正式上架請優先使用：

- `Android App Bundle (.aab)`

不要把 `APK` 當成正式發佈格式。

## 這個專案目前要注意的上架點

- 有 Google Sign-In
- 有 Google Drive 備份
- 有本機解鎖流程
- 有附件 / 圖片選取

所以送審時要特別對齊：

- Data safety
- 隱私權政策
- App access
- 權限用途說明

## 最小檢查清單

- `package name` 已定案
- `versionCode` 會遞增
- release 簽章可正常產出
- `AAB` 可成功建置
- 商店頁文案完成
- 隱私權政策可公開訪問
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
