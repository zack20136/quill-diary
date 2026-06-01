package zack20136.com.quill_lock_diary

import io.realm.DynamicRealm
import io.realm.DynamicRealmObject
import io.realm.RealmConfiguration
import java.io.File

/**
 * 以 DynamicRealm 讀取 Easy Diary 備份內的 diary.realm 快照（無需嵌入完整 Kotlin 模型）。
 */
object EasyDiaryRealmReader {
    private const val SCHEMA_VERSION = 24L
    private const val DIARY_CLASS = "Diary"
    private const val ORIGIN_SEQUENCE_FIELD = "originSequence"

    fun readDiaries(realmFilePath: String): List<Map<String, Any?>> {
        val realmFile = File(realmFilePath)
        require(realmFile.isFile) { "找不到 Realm 檔案：$realmFilePath" }

        val config =
            RealmConfiguration.Builder()
                .name(realmFile.name)
                .directory(realmFile.parentFile!!)
                .schemaVersion(SCHEMA_VERSION)
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

    /** 與 Easy Diary [PhotoUri.getFilePath] 相同：以 URI 路徑的 base name 對應 Photos 檔名。 */
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
