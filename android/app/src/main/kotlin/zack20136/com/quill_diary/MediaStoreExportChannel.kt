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
                    error.message ?: "MediaStore export failed.",
                    null,
                )
            }
        }
    }

    private fun exportSubfolder(context: Context): String =
        context.getString(R.string.user_export_subfolder)

    private fun ensureDownloadsSubfolder(
        context: Context,
        result: MethodChannel.Result,
    ) {
        // Do not create marker files such as README.txt just to materialize the folder.
        // The directory will be created naturally when the user actually exports a file.
        exportSubfolder(context)
        result.success(null)
    }

    private fun saveImageToPictures(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null || bytes.isEmpty()) {
            result.error("invalid_args", "bytes is required.", null)
            return
        }

        val fileName = call.argument<String>("fileName")?.trim().orEmpty()
        if (fileName.isEmpty()) {
            result.error("invalid_args", "fileName is required.", null)
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
        val collection = MediaStore.Images.Media.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY,
        )
        val uri = resolver.insert(collection, values)
        if (uri == null) {
            result.error("insert_failed", "Unable to create the image entry.", null)
            return
        }

        try {
            resolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: throw IOException("Unable to open output stream.")

            val publishValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(uri, publishValues, null, null)
            result.success(fileName)
        } catch (error: Exception) {
            try {
                resolver.delete(uri, null, null)
            } catch (_: Exception) {
                // Ignore cleanup failures.
            }
            result.error(
                "write_failed",
                error.message ?: "Unable to save the image.",
                null,
            )
        }
    }
}
