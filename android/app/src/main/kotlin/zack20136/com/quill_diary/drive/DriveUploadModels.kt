package zack20136.com.quill_diary.drive

import org.json.JSONObject

/**
 * Google Drive 背景上傳工作狀態。
 * sessionUri 不進此 JSON，改由 Keystore 保護的安全儲存持有。
 *
 * 失敗、取消與完成都以刪除 job 表達；不持久化終態 phase。
 */
enum class DriveUploadPhase {
    STAGED,
    UPLOADING,
    WAITING_FOR_NETWORK,
    STATUS_PENDING,
    PRUNE_PENDING,
}

data class DriveUploadJob(
    val schemaVersion: Int = SCHEMA_VERSION,
    val jobId: String,
    val phase: DriveUploadPhase,
    val accountId: String,
    val accountEmail: String,
    val stagingPath: String,
    val fileName: String,
    val sizeBytes: Long,
    val md5: String = "",
    val remoteFileId: String = "",
    val confirmedOffset: Long = 0L,
    val retryCount: Int = 0,
    val nextRetryAtEpochMs: Long? = null,
    val lastErrorCode: String? = null,
    val lastErrorMessage: String? = null,
    val generation: Long = 0L,
    val updatedAtEpochMs: Long = System.currentTimeMillis(),
    val createdAtEpochMs: Long = System.currentTimeMillis(),
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "schemaVersion" to schemaVersion,
            "jobId" to jobId,
            "phase" to phase.name,
            "accountId" to accountId,
            "accountEmail" to accountEmail,
            "stagingPath" to stagingPath,
            "fileName" to fileName,
            "sizeBytes" to sizeBytes,
            "md5" to md5,
            "remoteFileId" to remoteFileId,
            "confirmedOffset" to confirmedOffset,
            "retryCount" to retryCount,
            "nextRetryAtEpochMs" to nextRetryAtEpochMs,
            "lastErrorCode" to lastErrorCode,
            "lastErrorMessage" to lastErrorMessage,
            "generation" to generation,
            "updatedAtEpochMs" to updatedAtEpochMs,
            "createdAtEpochMs" to createdAtEpochMs,
            "progressFraction" to progressFraction(),
        )

    fun progressFraction(): Double {
        if (sizeBytes <= 0L) {
            return 0.0
        }
        return (confirmedOffset.toDouble() / sizeBytes.toDouble()).coerceIn(0.0, 1.0)
    }

    fun isActive(): Boolean = true

    fun blocksConflictingActions(): Boolean = isActive()

    fun isRemoteCommittedPhase(): Boolean =
        phase == DriveUploadPhase.STATUS_PENDING ||
            phase == DriveUploadPhase.PRUNE_PENDING

    companion object {
        const val SCHEMA_VERSION = 1

        fun fromMap(raw: Map<*, *>): DriveUploadJob? {
            fun string(key: String): String {
                val value = raw[key] ?: return ""
                if (value === JSONObject.NULL) {
                    return ""
                }
                return value.toString().trim()
            }

            fun long(key: String, fallback: Long = 0L): Long {
                val value = raw[key] ?: return fallback
                if (value === JSONObject.NULL) {
                    return fallback
                }
                return when (value) {
                    is Number -> value.toLong()
                    else -> value.toString().toLongOrNull() ?: fallback
                }
            }

            fun int(key: String, fallback: Int = 0): Int {
                val value = raw[key] ?: return fallback
                if (value === JSONObject.NULL) {
                    return fallback
                }
                return when (value) {
                    is Number -> value.toInt()
                    else -> value.toString().toIntOrNull() ?: fallback
                }
            }

            val phaseName = string("phase")
            val phase =
                when (phaseName) {
                    "PREPARING" -> DriveUploadPhase.STAGED
                    "CLEANUP_PENDING" -> DriveUploadPhase.PRUNE_PENDING
                    else ->
                        runCatching { DriveUploadPhase.valueOf(phaseName) }.getOrNull()
                } ?: return null

            val md5 =
                string("md5").ifEmpty {
                    // 相容舊快照。
                    string("sha256")
                }
            val retryCount =
                if (raw.containsKey("retryCount")) {
                    int("retryCount")
                } else {
                    int("attemptCount")
                }

            return DriveUploadJob(
                schemaVersion = int("schemaVersion", SCHEMA_VERSION),
                jobId = string("jobId"),
                phase = phase,
                accountId = string("accountId"),
                accountEmail = string("accountEmail"),
                stagingPath = string("stagingPath"),
                fileName = string("fileName"),
                sizeBytes = long("sizeBytes"),
                md5 = md5,
                remoteFileId = string("remoteFileId"),
                confirmedOffset = long("confirmedOffset"),
                retryCount = retryCount,
                nextRetryAtEpochMs =
                    raw["nextRetryAtEpochMs"]?.let {
                        if (it === JSONObject.NULL) {
                            null
                        } else {
                            when (it) {
                                is Number -> it.toLong()
                                else -> it.toString().toLongOrNull()
                            }
                        }
                    },
                lastErrorCode = string("lastErrorCode").ifEmpty { null },
                lastErrorMessage = string("lastErrorMessage").ifEmpty { null },
                generation = long("generation"),
                updatedAtEpochMs = long("updatedAtEpochMs", System.currentTimeMillis()),
                createdAtEpochMs = long("createdAtEpochMs", System.currentTimeMillis()),
            )
        }
    }
}

data class DriveUploadFailureNotice(
    val jobId: String,
    val message: String,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "jobId" to jobId,
            "message" to message,
        )

    companion object {
        fun fromMap(raw: Map<*, *>): DriveUploadFailureNotice? {
            fun string(key: String): String {
                val value = raw[key] ?: return ""
                if (value === JSONObject.NULL) {
                    return ""
                }
                return value.toString().trim()
            }

            val jobId = string("jobId")
            if (jobId.isEmpty()) {
                return null
            }
            val message =
                string("message").ifEmpty {
                    string("errorMessage").ifEmpty {
                        "上次 Google Drive 備份未完成，已取消。請重新備份。"
                    }
                }
            return DriveUploadFailureNotice(jobId = jobId, message = message)
        }
    }
}

sealed class DriveUploadOutcome {
    data class WaitingNetwork(val job: DriveUploadJob) : DriveUploadOutcome()

    data class Committed(val job: DriveUploadJob) : DriveUploadOutcome()

    data class Failed(
        val code: String,
        val message: String,
    ) : DriveUploadOutcome()

    data object Cancelled : DriveUploadOutcome()
}
