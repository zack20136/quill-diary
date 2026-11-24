package zack20136.com.quill_diary

import android.content.Context
import android.os.StatFs
import android.system.Os
import android.system.OsConstants
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.io.IOException

internal object RestoreStorageChannel {
    fun register(engine: FlutterEngine, context: Context) {
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(
            messenger,
            "quill_diary/restore_storage",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            try {
                val path = File(call.arguments as String).canonicalFile
                require(path.toPath().startsWith(context.filesDir.canonicalFile.toPath()))
                when (call.method) {
                    "availableBytes" -> result.success(StatFs(path.path).availableBytes)
                    "syncDirectory", "syncTree" -> {
                        sync(path, call.method == "syncTree")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("restore_storage", "Restore storage operation failed.", null)
            }
        }
    }

    private fun sync(file: File, tree: Boolean) {
        val path = file.path
        val isDirectory = OsConstants.S_ISDIR(Os.lstat(path).st_mode)
        if (tree && isDirectory) {
            val children = file.listFiles() ?: throw IOException("Failed to list restore directory")
            children.forEach { sync(it, true) }
        }
        val descriptor = Os.open(path, OsConstants.O_RDONLY or OsConstants.O_NOFOLLOW, 0)
        try {
            Os.fsync(descriptor)
        } finally {
            Os.close(descriptor)
        }
    }
}
