package zack20136.com.quill_diary

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.realm.Realm

object EasyDiaryRealmChannel {
    const val CHANNEL_NAME = "quill_diary/easy_diary_realm"

    fun register(flutterEngine: FlutterEngine, applicationContext: android.content.Context) {
        Realm.init(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "readDiaryBackup" -> {
                        val path = call.argument<String>("realmPath")
                        if (path.isNullOrBlank()) {
                            result.error(
                                "invalid_argument",
                                "realmPath is required.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        val entries = EasyDiaryRealmReader.readDiaries(path)
                        result.success(mapOf("entries" to entries))
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "easy_diary_realm_error",
                    error.message ?: "Unable to read Easy Diary backup.",
                    null,
                )
            }
        }
    }
}
