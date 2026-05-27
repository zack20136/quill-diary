# Android 權限與上架風險

最後確認日期：2026-05-27

## 結論

目前這個專案的 Android 權限不需要額外補相片或舊版儲存權限。

保留的最小權限集為：

- `android.permission.INTERNET`
- `android.permission.USE_BIOMETRIC`

不需要手動新增：

- `READ_MEDIA_IMAGES`
- `READ_EXTERNAL_STORAGE`
- `WRITE_EXTERNAL_STORAGE`
- `CAMERA`

## 為什麼不需要相片權限

相片挑選流程在 [editor_page.dart](C:/Users/0219/Projects/00/quill-lock-diary/lib/features/editor/pages/editor_page.dart:1770)：

- 先呼叫 `pickMultiImage()`
- 失敗時 fallback 到 `pickImage(source: ImageSource.gallery)`

目前流程只有「選取既有相片」，沒有：

- `ImageSource.camera`
- 拍照
- 錄影
- 寫回系統相簿

因此 app 本身不需要主動宣告相機權限，也不需要手動加媒體讀取權限。

## 為什麼 `image_picker` / `file_picker` 也不要求手動加讀圖權限

目前使用的 plugin 行為如下：

- `image_picker_android` 會使用系統 Photo Picker 或 `ACTION_GET_CONTENT`
- `file_picker` 走系統檔案選取流程

這兩條路徑是透過系統 picker 讓使用者主動選檔，不是 app 直接掃描整個媒體庫，所以不需要在 manifest 額外宣告 `READ_MEDIA_IMAGES` 或舊版 `READ_EXTERNAL_STORAGE`。

另外，plugin manifest 也沒有要求專案手動加入相片讀取權限：

- `image_picker_android` 主要帶入 `FileProvider` 與 Photo Picker backport service
- `file_picker` 只帶入 `GET_CONTENT` 的 `queries`

## 為什麼目前也不需要 `CAMERA`

程式碼沒有使用：

- `ImageSource.camera`
- 相機拍照 intent
- 錄影功能

所以現在加入 `CAMERA` 權限只會增加 Play 審核與 Data safety 解釋成本，沒有實際收益。

如果未來新增拍照或錄影功能，再補：

- Android manifest 的 `CAMERA`
- 對應平台使用說明
- Play Console 權限與資料揭露

## Google Sign-In / Drive 備份的 Android 風險點

這個專案有：

- Google Sign-In
- Google Drive appData 備份

在 Android 權限層面，這兩項主要只依賴：

- `INTERNET`

但在 Google Play 審核與資料揭露層面，不能只看 manifest 權限，還要注意：

- 是否有登入流程
- 是否會把備份上傳到 Google Drive
- 是否會傳輸日記資料、附件或加密檔
- Data safety、隱私權政策、商店描述三者是否一致

也就是說：Android 權限雖然精簡，但 Play Console 的資料揭露仍然要如實填寫。

## 已確認的 Android 設定

- [AndroidManifest.xml](C:/Users/0219/Projects/00/quill-lock-diary/android/app/src/main/AndroidManifest.xml:2) 只保留 `INTERNET`
- [AndroidManifest.xml](C:/Users/0219/Projects/00/quill-lock-diary/android/app/src/main/AndroidManifest.xml:3) 保留 `USE_BIOMETRIC`
- [AndroidManifest.xml](C:/Users/0219/Projects/00/quill-lock-diary/android/app/src/main/AndroidManifest.xml:6) 已改成正式顯示名稱 `Quill Lock Diary`
- [AndroidManifest.xml](C:/Users/0219/Projects/00/quill-lock-diary/android/app/src/main/AndroidManifest.xml:34) 的 Impeller 註解已清理

## 未來若功能改變，哪些情況要重新檢查

出現以下任一情況時，要重新檢查 Android 權限與上架資料：

- 新增拍照
- 新增錄影
- 新增直接讀取媒體庫
- 新增背景上傳
- 新增分享到外部儲存空間
- 新增需要高風險權限的原生功能

## Android 上架前最小檢查清單

- Manifest 沒有多餘權限
- 實際功能沒有偷偷使用相機或直接掃描媒體庫
- Data safety 有揭露 Google Sign-In / Drive 備份相關資料流
- 隱私權政策有說明備份、登入與資料保存方式
- 若 app 有登入或解鎖門檻，Play Console 的 `App access` 要提供審核說明
