package zack20136.com.quill_diary.drive

import org.json.JSONObject

/**
 * Google Drive 背景上傳工作狀態。
 * sessionUri 不進此 JSON，改由 Keystore 保護的安全儲存持有。
 *
 * 失敗、取消與完成都以刪除 job 表達；不持久化終態 phase。
 */
internal enum class DriveUploadPhase {
    STAGED,
    UPLOADING,
    WAITING_FOR_NETWORK,
    STATUS_PENDING,
    PRUNE_PENDING,
    CANCEL_CLEANUP_PENDING,
}

internal enum class DriveUploadStopAction {
    KeepCommitted,
    ReconcileRemote,
    WaitForWorker,
}

internal fun resolveUploadStopAction(
    currentJob: DriveUploadJob?,
    workerExited: Boolean = true,
): DriveUploadStopAction =
    when {
        currentJob?.isRemoteCommittedPhase() == true -> DriveUploadStopAction.KeepCommitted
        !workerExited -> DriveUploadStopAction.WaitForWorker
        else -> DriveUploadStopAction.ReconcileRemote
    }

internal data class DriveUploadJob(
    val schemaVersion: Int = SCHEMA_VERSION,
    val jobId: String,
    val phase: DriveUploadPhase,
    val accountId: String,
    val accountEmail: String,
    val stagingPath: String,
    val fileName: String,
    val sizeBytes: Long,
    val md5: String = "",
    val backupIdentity: Map<String, String>? = null,
    val backupPurpose: String? = null,
    val remoteFileId: String = "",
    val confirmedOffset: Long = 0L,
    val retryCount: Int = 0,
    val nextRetryAtEpochMs: Long? = null,
    val lastErrorCode: String? = null,
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
            "backupIdentity" to backupIdentity,
            "backupPurpose" to backupPurpose,
            "remoteFileId" to remoteFileId,
            "confirmedOffset" to confirmedOffset,
            "retryCount" to retryCount,
            "nextRetryAtEpochMs" to nextRetryAtEpochMs,
            "lastErrorCode" to lastErrorCode,
            // 舊版工作可能帶有原始例外文字；不得再透過持久狀態／EventChannel 洩漏。
            "lastErrorMessage" to null,
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

    /** 與設定頁一致採無條件捨去，未完成時不提早顯示 100%。 */
    fun progressPercent(): Int {
        if (sizeBytes <= 0L) {
            return 0
        }
        val boundedOffset = confirmedOffset.coerceIn(0L, sizeBytes)
        return ((boundedOffset * 100L) / sizeBytes).toInt()
    }

    fun isRemoteCommittedPhase(): Boolean =
        phase == DriveUploadPhase.STATUS_PENDING ||
            phase == DriveUploadPhase.PRUNE_PENDING

    fun isCancelCleanupPhase(): Boolean =
        phase == DriveUploadPhase.CANCEL_CLEANUP_PENDING

    companion object {
        const val SCHEMA_VERSION = 1

        fun fromMap(raw: Map<*, *>): DriveUploadJob? {
            fun string(key: String) = raw.jobString(key)
            fun long(key: String, fallback: Long = 0L) = raw[key].jobLongOrNull() ?: fallback
            fun int(key: String, fallback: Int = 0): Int =
                when (val value = raw[key]) {
                    is Number -> value.toInt()
                    else -> value?.toString()?.toIntOrNull() ?: fallback
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
                backupIdentity = readBackupIdentity(raw["backupIdentity"]),
                backupPurpose = string("backupPurpose").takeIf { it == "normal" || it == "preservation" },
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
                nextRetryAtEpochMs = raw["nextRetryAtEpochMs"].jobLongOrNull(),
                lastErrorCode = string("lastErrorCode").ifEmpty { null },
                generation = long("generation"),
                updatedAtEpochMs = long("updatedAtEpochMs", System.currentTimeMillis()),
                createdAtEpochMs = long("createdAtEpochMs", System.currentTimeMillis()),
            )
        }
    }
}

internal data class DriveUploadFailureNotice(
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
            val jobId = raw.jobString("jobId")
            if (jobId.isEmpty()) {
                return null
            }
            val message =
                raw.jobString("message").ifEmpty {
                    raw.jobString("errorMessage")
                }
            return DriveUploadFailureNotice(jobId = jobId, message = message)
        }
    }
}

internal sealed class DriveUploadOutcome {
    data class WaitingNetwork(val job: DriveUploadJob) : DriveUploadOutcome()

    data class Committed(val job: DriveUploadJob) : DriveUploadOutcome()

    data class Failed(val code: String) : DriveUploadOutcome()

    data object Cancelled : DriveUploadOutcome()
}

private val KDF_FINGERPRINT_PATTERN = Regex("[a-f0-9]{64}")

private fun readBackupIdentity(value: Any?): Map<String, String>? {
    val (vaultId, fingerprint) = when (value) {
        is Map<*, *> -> (value["vault_id"] as? String) to (value["kdf_fingerprint"] as? String)
        is JSONObject -> value.optString("vault_id") to value.optString("kdf_fingerprint")
        else -> return null
    }
    if (vaultId.isNullOrBlank() || fingerprint == null || !KDF_FINGERPRINT_PATTERN.matches(fingerprint)) {
        return null
    }
    return mapOf("vault_id" to vaultId, "kdf_fingerprint" to fingerprint)
}

private fun Map<*, *>.jobString(key: String): String =
    this[key].takeUnless { it === JSONObject.NULL }?.toString()?.trim().orEmpty()

private fun Any?.jobLongOrNull(): Long? =
    when (this) {
        is Number -> toLong()
        else -> this?.toString()?.toLongOrNull()
    }
