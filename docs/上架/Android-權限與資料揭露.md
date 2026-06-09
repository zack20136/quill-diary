# Android 權限與資料揭露

最後更新：2026-05-27

## 結論

目前這個專案的 Android 權限維持最小集即可：

- `android.permission.INTERNET`
- `android.permission.USE_BIOMETRIC`

不需要手動新增：

- `READ_MEDIA_IMAGES`
- `READ_EXTERNAL_STORAGE`
- `WRITE_EXTERNAL_STORAGE`
- `CAMERA`

## 為什麼不需要相片權限

目前圖片流程只做：

- `pickMultiImage()`
- `pickImage(source: ImageSource.gallery)`

也就是只讓使用者透過系統 picker 選取既有圖片，沒有：

- 拍照
- 錄影
- 直接掃描媒體庫
- 寫回系統相簿

所以 app 不需要手動宣告相片或相機權限。

## plugin 層面的結論

- `image_picker_android` 主要用系統 Photo Picker / `ACTION_GET_CONTENT`
- `file_picker` 走系統檔案選取流程

因此目前不需要手動加：

- `READ_MEDIA_IMAGES`
- `READ_EXTERNAL_STORAGE`

## Play Console 仍要揭露什麼

雖然 Android 權限很精簡，但送審與 Data safety 還是要如實揭露：

- Google Sign-In
- Google Drive 備份
- 圖片與附件選取
- 本機解鎖與資料保存流程

## 什麼情況要重新檢查

如果之後新增以下功能，就要重新評估 Android 權限：

- 拍照
- 錄影
- 直接讀取媒體庫
- 背景上傳
- 對外部儲存空間寫入

## 最小檢查清單

- Manifest 沒有多餘權限
- 程式碼沒有 `ImageSource.camera`
- Data safety 與實際資料流一致
- 商店頁與隱私權政策沒有誤導

## 相關檔案

- [AndroidManifest.xml](C:/Users/0219/Projects/00/quill-diary/android/app/src/main/AndroidManifest.xml)
- [editor_page.dart](C:/Users/0219/Projects/00/quill-diary/lib/features/editor/pages/editor_page.dart)
