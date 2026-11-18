package zack20136.com.quill_diary

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

internal class DocumentFileChannels(private val activity: Activity) {
    private val contentResolver get() = activity.contentResolver
    private var pendingDirectoryResult: MethodChannel.Result? = null

    fun register(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        registerChannel(
            MethodChannel(messenger, "quill_diary/directory_picker"),
            "pickWritableDirectoryTree",
            "directory_picker_error",
            "Unknown directory picker error.",
            ::pickWritableDirectoryTree,
        )
        registerChannel(
            MethodChannel(messenger, "quill_diary/content_uri_import"),
            "copyUriToPath",
            "content_uri_import_error",
            "Unknown content URI import error.",
            ::copyUriToPath,
        )
        registerChannel(
            MethodChannel(messenger, "quill_diary/saf_file_copy"),
            "copyFileToTree",
            "saf_file_copy_error",
            "Unknown SAF file copy error.",
            ::copyFileToSafTree,
        )
    }

    private fun registerChannel(
        channel: MethodChannel,
        method: String,
        errorCode: String,
        fallbackMessage: String,
        handle: (MethodCall, MethodChannel.Result) -> Unit,
    ) {
        channel.setMethodCallHandler { call, result ->
            if (call.method != method) {
                result.notImplemented()
            } else {
                try {
                    handle(call, result)
                } catch (error: Throwable) {
                    result.error(errorCode, error.message ?: fallbackMessage, null)
                }
            }
        }
    }

    internal fun pickWritableDirectoryTree(call: MethodCall, result: MethodChannel.Result) {
        if (pendingDirectoryResult != null) {
            result.error(
                "directory_picker_in_progress",
                "資料夾選擇進行中，請稍候。",
                null,
            )
            return
        }

        val prompt = call.argument<String>("prompt")?.trim().orEmpty()
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addCategory(Intent.CATEGORY_DEFAULT)
            if (prompt.isNotEmpty()) {
                putExtra(DocumentsContract.EXTRA_PROMPT, prompt)
            }
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        }
        if (intent.resolveActivity(activity.packageManager) == null) {
            result.error("directory_picker_unavailable", "此裝置無法開啟資料夾選擇器。", null)
            return
        }

        pendingDirectoryResult = result
        try {
            activity.startActivityForResult(intent, DIRECTORY_REQUEST_CODE)
        } catch (error: Exception) {
            pendingDirectoryResult = null
            throw error
        }
    }

    fun onDirectoryResult(resultCode: Int, data: Intent?) {
        val pending = pendingDirectoryResult ?: return
        pendingDirectoryResult = null
        // 只使用選擇器回傳的暫時讀寫授權。
        pending.success(data?.data?.toString().takeIf { resultCode == Activity.RESULT_OK })
    }

    internal fun copyUriToPath(call: MethodCall, result: MethodChannel.Result) {
        val sourceUriString = call.argument<String>("sourceUri")?.trim().orEmpty()
        val destinationPath = call.argument<String>("destinationPath")?.trim().orEmpty()

        if (sourceUriString.isEmpty() || destinationPath.isEmpty()) {
            result.error("invalid_args", "缺少 sourceUri 或 destinationPath。", null)
            return
        }

        val destinationFile = File(destinationPath)
        destinationFile.parentFile?.mkdirs()

        var openedDestination = false
        try {
            contentResolver.openInputStream(Uri.parse(sourceUriString))?.use { input ->
                destinationFile.outputStream().use { output ->
                    openedDestination = true
                    input.copyTo(output)
                }
            } ?: run {
                result.error("open_input_failed", "無法讀取選取的檔案。", null)
                return
            }
            result.success(null)
        } catch (_: SecurityException) {
            if (openedDestination) destinationFile.delete()
            result.error("open_input_failed", "無法讀取選取的檔案。", null)
        } catch (error: Exception) {
            if (openedDestination) destinationFile.delete()
            result.error("copy_failed", error.message ?: "複製檔案失敗。", null)
        }
    }

    private fun copyFileToSafTree(call: MethodCall, result: MethodChannel.Result) {
        val treeUriString = call.argument<String>("treeUri")?.trim().orEmpty()
        val sourcePath = call.argument<String>("sourcePath")?.trim().orEmpty()
        val fileName = call.argument<String>("fileName")?.trim().orEmpty()
        val mimeType = call.argument<String>("mimeType")?.trim().orEmpty()
            .ifEmpty { "application/octet-stream" }

        if (treeUriString.isEmpty() || sourcePath.isEmpty() || fileName.isEmpty()) {
            result.error("invalid_args", "缺少 treeUri、sourcePath 或 fileName。", null)
            return
        }

        val sourceFile = File(sourcePath)
        if (!sourceFile.isFile) {
            result.error("source_missing", "找不到要複製的來源檔案。", null)
            return
        }

        val treeUri = Uri.parse(treeUriString)
        val parentDocumentUri =
            if (DocumentsContract.isTreeUri(treeUri)) {
                DocumentsContract.buildDocumentUriUsingTree(
                    treeUri,
                    DocumentsContract.getTreeDocumentId(treeUri),
                )
            } else {
                treeUri
            }
        val createdUri =
            try {
                DocumentsContract.createDocument(contentResolver, parentDocumentUri, mimeType, fileName)
            } catch (error: SecurityException) {
                result.error(
                    "create_document_failed",
                    "沒有寫入此資料夾的權限，請重新選擇資料夾並允許存取。",
                    null,
                )
                return
            }
        if (createdUri == null) {
            result.error("create_document_failed", "無法在選擇的資料夾建立檔案。", null)
            return
        }

        try {
            contentResolver.openOutputStream(createdUri, "w")?.use { output ->
                sourceFile.inputStream().use { input ->
                    input.copyTo(output)
                }
            } ?: throw IOException("無法開啟輸出串流。")
            result.success(createdUri.toString())
        } catch (error: Exception) {
            try {
                DocumentsContract.deleteDocument(contentResolver, createdUri)
            } catch (_: Exception) {
                // 刪除半成品失敗時仍回報原始錯誤。
            }
            result.error("copy_failed", error.message ?: "複製檔案失敗。", null)
        }
    }

    companion object {
        const val DIRECTORY_REQUEST_CODE = 43022
    }
}
