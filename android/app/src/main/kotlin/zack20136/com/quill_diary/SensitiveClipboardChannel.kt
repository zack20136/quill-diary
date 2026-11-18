package zack20136.com.quill_diary

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.PersistableBundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

internal object SensitiveClipboardChannel {
    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "quill_diary/sensitive_clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method != "copy") {
                    result.notImplemented()
                } else {
                    val text = call.argument<String>("text")
                    if (text == null) {
                        result.error("invalid_args", "Missing clipboard text", null)
                    } else {
                        try {
                            copy(context, text)
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("clipboard_unavailable", "Sensitive clipboard unavailable", null)
                        }
                    }
                }
            }
    }

    fun copy(context: Context, text: String) {
        val clip = ClipData.newPlainText("", text)
        clip.description.extras = PersistableBundle().apply {
            putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
        }
        context.getSystemService(ClipboardManager::class.java).setPrimaryClip(clip)
    }
}
