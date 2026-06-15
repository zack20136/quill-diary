package zack20136.com.quill_diary

import android.content.ContentValues
import android.content.Context
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

object MediaStoreExportChannel {
    const val CHANNEL_NAME = "quill_diary/media_store_export"
    private const val DOWNLOADS_MARKER_FILE = "README.txt"
    private const val DOWNLOADS_MARKER_BODY =
        "Quill Diary exports appear in this folder.\n"

    fun register(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "saveImageToPictures" -> saveImageToPictures(context, call, result)
                    "ensureDownloadsSubfolder" -> ensureDownloadsSubfolder(context, result)
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(
                    "media_store_export_error",
                    error.message ?: "MediaStore 操作失敗。",
                    null,
                )
            }
        }
    }

    private fun exportSubfolder(context: Context): String =
        context.getString(R.string.user_export_subfolder)

    private fun ensureDownloadsSubfolder(context: Context, result: MethodChannel.Result) {
        if (downloadsMarkerExists(context)) {
            result.success(null)
            return
        }

        val relativePath = "Download/${exportSubfolder(context)}"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, DOWNLOADS_MARKER_FILE)
            put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val resolver = context.contentResolver
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values)
        if (uri == null) {
            result.error("insert_failed", "無法建立 Download 子資料夾。", null)
            return
        }

        try {
            resolver.openOutputStream(uri)?.use { output ->
                output.write(DOWNLOADS_MARKER_BODY.toByteArray(Charsets.UTF_8))
                output.flush()
            } ?: throw IOException("無法開啟輸出串流。")

            val publishValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(uri, publishValues, null, null)
            result.success(null)
        } catch (error: Exception) {
            try {
                resolver.delete(uri, null, null)
            } catch (_: Exception) {
                // 刪除半成品失敗時仍回報原始錯誤。
            }
            result.error(
                "write_failed",
                error.message ?: "無法建立 Download 子資料夾。",
                null,
            )
        }
    }

    private fun downloadsMarkerExists(context: Context): Boolean {
        val subfolder = exportSubfolder(context)
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection =
            "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
        val selectionArgs = arrayOf("%$subfolder%", DOWNLOADS_MARKER_FILE)
        context.contentResolver.query(collection, projection, selection, selectionArgs, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    return true
                }
            }
        return false
    }

    private fun saveImageToPictures(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null || bytes.isEmpty()) {
            result.error("invalid_args", "bytes 不可為空。", null)
            return
        }
        val fileName = call.argument<String>("fileName")?.trim().orEmpty()
        if (fileName.isEmpty()) {
            result.error("invalid_args", "fileName 不可為空。", null)
            return
        }
        val mimeType = call.argument<String>("mimeType")?.trim().orEmpty()
            .ifEmpty { "image/jpeg" }

        val relativePath = "Pictures/${exportSubfolder(context)}"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val resolver = context.contentResolver
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values)
        if (uri == null) {
            result.error("insert_failed", "無法建立媒體項目。", null)
            return
        }

        try {
            resolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: throw IOException("無法開啟輸出串流。")

            val publishValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(uri, publishValues, null, null)
            result.success(fileName)
        } catch (error: Exception) {
            try {
                resolver.delete(uri, null, null)
            } catch (_: Exception) {
                // 刪除半成品失敗時仍回報原始錯誤。
            }
            result.error(
                "write_failed",
                error.message ?: "寫入圖片失敗。",
                null,
            )
        }
    }
}
