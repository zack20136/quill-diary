# Android 權限與資料揭露

這份文件整理 Quill Diary 目前在 Android 上實際需要的權限，以及送審時該如何對應 Data safety 與資料揭露。

## 目前權限結論

這個專案目前只需要最小權限集：

- `android.permission.INTERNET`
- `android.permission.USE_BIOMETRIC`
- `com.android.vending.BILLING`（Google Play 支持開發者）

目前不需要手動新增：

- `READ_MEDIA_IMAGES`
- `READ_EXTERNAL_STORAGE`
- `WRITE_EXTERNAL_STORAGE`
- `CAMERA`

## 為什麼不需要相片或相機權限

目前圖片流程只做：

- `pickMultiImage()`
- `pickImage(source: ImageSource.gallery)`

也就是透過系統 picker 選取既有圖片，沒有：

- 拍照
- 錄影
- 直接掃描媒體庫
- 寫回系統相簿

所以不需要手動宣告相片或相機權限。

## 檔案選取也是同樣原則

- `image_picker_android` 主要走系統 Photo Picker 或 `ACTION_GET_CONTENT`
- `file_picker` 走系統檔案選取流程

因此目前不需要額外宣告儲存讀寫權限。

## 送審仍要揭露什麼

即使權限很少，Play Console 仍要如實揭露資料流與功能用途，例如：

- Google Sign-In
- Google Drive 備份
- 圖片與附件選取
- 本機解鎖與資料保存流程

## 該如何做

1. 先檢查 `AndroidManifest.xml`，確認沒有多餘權限
2. 檢查程式碼目前沒有使用 `ImageSource.camera`
3. 整理實際資料流，對齊 Data safety
4. 確認商店頁與隱私權政策沒有把權限用途寫錯
5. 若未來新增拍照、錄影、媒體庫直讀或背景上傳，再重新評估權限

## 什麼情況要重新檢查

若未來新增以下能力，就要重新檢查 Android 權限與資料揭露：

- 拍照
- 錄影
- 直接讀取媒體庫
- 背景上傳
- 對外部儲存空間直接寫入

## 最小檢查清單

- Manifest 沒有多餘權限
- 程式碼沒有 `ImageSource.camera`
- Data safety 與實際資料流一致
- 商店頁與隱私權政策沒有誤導

## 相關檔案

- [AndroidManifest.xml](../../../android/app/src/main/AndroidManifest.xml)
- [editor_page.dart](../../../lib/presentation/editor/pages/editor_page.dart)

---

[← 返回 Google 文件](./README.md)
