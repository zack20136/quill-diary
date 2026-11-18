package zack20136.com.quill_diary

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.realm.DynamicRealm
import io.realm.DynamicRealmObject
import io.realm.Realm
import io.realm.RealmConfiguration
import java.io.File

internal object EasyDiaryRealmChannel {
    private const val CHANNEL_NAME = "quill_diary/easy_diary_realm"
    private const val REALM_SCHEMA_VERSION = 24L
    private const val DIARY_CLASS = "Diary"
    private const val ORIGIN_SEQUENCE_FIELD = "originSequence"

    fun register(flutterEngine: FlutterEngine, applicationContext: Context) {
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
                        val entries = readDiaries(path)
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

    private fun readDiaries(realmFilePath: String): List<Map<String, Any?>> {
        val realmFile = File(realmFilePath)
        require(realmFile.isFile) { "找不到 Realm 檔案：$realmFilePath" }

        val config =
            RealmConfiguration.Builder()
                .name(realmFile.name)
                .directory(realmFile.parentFile!!)
                .schemaVersion(REALM_SCHEMA_VERSION)
                .build()

        DynamicRealm.getInstance(config).use { realm ->
            realm.refresh()
            val results =
                realm.where(DIARY_CLASS)
                    .equalTo(ORIGIN_SEQUENCE_FIELD, 0)
                    .findAll()

            val entries = mutableListOf<Map<String, Any?>>()
            for (index in 0 until results.size) {
                val diary = results[index] ?: continue
                entries.add(mapDiary(diary))
            }
            return entries
        }
    }

    private fun mapDiary(diary: DynamicRealmObject): Map<String, Any?> {
        val photos = mutableListOf<Map<String, String?>>()
        val photoUris = diary.getList("photoUris")
        if (photoUris != null) {
            for (index in 0 until photoUris.size) {
                val photo = photoUris[index] ?: continue
                val rawUri = photo.getString("photoUri")?.trim().orEmpty()
                if (rawUri.isEmpty() || rawUri.startsWith("content:")) {
                    continue
                }
                val photoKey = photoKeyFromUri(rawUri)
                if (photoKey.isEmpty()) {
                    continue
                }
                photos.add(
                    mapOf(
                        "photoKey" to photoKey,
                        "mimeType" to photo.getString("mimeType"),
                    ),
                )
            }
        }

        return mapOf(
            "title" to diary.getString("title"),
            "contents" to diary.getString("contents"),
            "dateString" to diary.getString("dateString"),
            "currentTimeMillis" to diary.getLong("currentTimeMillis"),
            "isEncrypt" to diary.getBoolean("isEncrypt"),
            "photos" to photos,
        )
    }

    /** 與 Easy Diary `PhotoUri.getFilePath` 相同：以 URI 路徑的 base name 對應 Photos 檔名。 */
    private fun photoKeyFromUri(rawUri: String): String {
        val withoutQuery = rawUri.substringBefore('?').substringBefore('#')
        val lastSlash = withoutQuery.lastIndexOf('/')
        return if (lastSlash >= 0) {
            withoutQuery.substring(lastSlash + 1)
        } else {
            withoutQuery
        }
    }
}
