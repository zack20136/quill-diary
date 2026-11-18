package zack20136.com.quill_diary.drive

import android.util.Log
import org.json.JSONObject
import java.io.IOException

/** 停止上傳時，先辨認已完成的備份，再處理遠端殘檔。 */
internal object DriveRemoteFileCleanup {
    private const val TAG = "DriveRemoteFileCleanup"
    private val SAFE_FILE_ID = Regex("^[A-Za-z0-9_-]+$")

    const val ERROR_CLEANUP_NEEDS_REAUTH = "cleanup_needs_reauth"
    const val ERROR_CLEANUP_ACCOUNT_MISMATCH = "cleanup_account_mismatch"

    enum class DeleteOutcome {
        /** 2xx／404，或非法 id／空白 token（視為無可刪物件）。 */
        Cleared,

        /** 網路或暫時性失敗，應保留 job 稍後重試。 */
        RetryLater,

        /** 401／非限流 403，應提示重連授權。 */
        AuthFailed,
    }

    sealed class CancelCleanupOutcome {
        data class RetainedCommitted(val job: DriveUploadJob) : CancelCleanupOutcome()

        data object ClearedLocal : CancelCleanupOutcome()

        data object RetryLater : CancelCleanupOutcome()

        /** 未登入或需使用者重新授權；保留 pending，UI 應允許重連原帳戶。 */
        data object NeedsReauth : CancelCleanupOutcome()

        /** 目前簽入帳戶與 job 不符；保留 pending，UI 應提示重連或放棄。 */
        data object AccountMismatch : CancelCleanupOutcome()
    }

    fun bestEffortDelete(
        remoteFileId: String,
        accessToken: String,
        httpClient: DriveHttpClient = UrlConnectionDriveHttpClient(),
    ): DeleteOutcome {
        val fileId = remoteFileId.trim()
        if (!isSafeFileId(fileId) || accessToken.isBlank()) {
            return DeleteOutcome.Cleared
        }
        return runCatching {
            val response =
                httpClient.execute(
                    DriveHttpRequest(
                        method = "DELETE",
                        url = "$DRIVE_FILES_URL/$fileId",
                        headers = mapOf("Authorization" to "Bearer $accessToken"),
                    ),
                )
            when {
                response.code in 200..299 || response.code == 404 -> DeleteOutcome.Cleared
                isAuthFailure(response.code, response.body) -> {
                    Log.w(TAG, "delete remote file auth HTTP ${response.code}")
                    DeleteOutcome.AuthFailed
                }
                else -> {
                    Log.w(TAG, "delete remote file HTTP ${response.code}")
                    DeleteOutcome.RetryLater
                }
            }
        }.getOrElse { error ->
            Log.w(TAG, "delete remote file failed", error)
            DeleteOutcome.RetryLater
        }
    }

    /**
     * CANCEL_CLEANUP_PENDING 收尾：查詢遠端後升 STATUS_PENDING，或刪殘檔再清本機。
     * worker 仍執行時，等待完成再查核及清理。
     */
    fun completeCancelCleanup(
        jobStore: DriveUploadJobStore,
        tokenProvider: DriveAccessTokenProvider,
        job: DriveUploadJob,
        workerAlive: Boolean,
        httpClient: DriveHttpClient = UrlConnectionDriveHttpClient(),
    ): CancelCleanupOutcome {
        val token =
            tokenProvider.getAccessToken().getOrElse { error ->
                Log.w(TAG, "cancel cleanup: token unavailable", error)
                return classifyTokenFailure(jobStore, job, error)
            }
        if (tokenProvider.matchTokenToJob(job, token) != null) {
            persistCleanupError(
                jobStore = jobStore,
                job = job,
                errorCode = ERROR_CLEANUP_ACCOUNT_MISMATCH,
            )
            return CancelCleanupOutcome.AccountMismatch
        }
        return completeCancelCleanup(
            jobStore = jobStore,
            accessToken = token.accessToken,
            job = job,
            workerAlive = workerAlive,
            httpClient = httpClient,
        )
    }

    fun completeCancelCleanup(
        jobStore: DriveUploadJobStore,
        accessToken: String,
        job: DriveUploadJob,
        workerAlive: Boolean,
        httpClient: DriveHttpClient = UrlConnectionDriveHttpClient(),
    ): CancelCleanupOutcome {
        val current = jobStore.readJob(job.jobId) ?: return CancelCleanupOutcome.ClearedLocal
        if (current.isRemoteCommittedPhase()) {
            return CancelCleanupOutcome.RetainedCommitted(current)
        }
        if (workerAlive) return CancelCleanupOutcome.RetryLater
        if (!current.isCancelCleanupPhase()) {
            jobStore.markCancelCleanupPending(current.jobId)
        }
        val working = jobStore.readJob(job.jobId) ?: return CancelCleanupOutcome.ClearedLocal
        if (working.isRemoteCommittedPhase()) {
            return CancelCleanupOutcome.RetainedCommitted(working)
        }
        if (accessToken.isBlank()) {
            persistCleanupError(
                jobStore = jobStore,
                job = working,
                errorCode = ERROR_CLEANUP_NEEDS_REAUTH,
            )
            return CancelCleanupOutcome.NeedsReauth
        }

        when (val lookup = lookupRemote(working, accessToken, httpClient)) {
            is RemoteLookup.Verified -> {
                val committed =
                    jobStore.updateJobCas(
                        lookup.job.copy(
                            phase = DriveUploadPhase.STATUS_PENDING,
                            confirmedOffset = lookup.job.sizeBytes,
                            lastErrorCode = null,

                        ),
                        expectedGeneration = working.generation,
                    )
                if (committed == null) {
                    val again = jobStore.readJob(working.jobId)
                    if (again != null && again.isRemoteCommittedPhase()) {
                        return CancelCleanupOutcome.RetainedCommitted(again)
                    }
                    return CancelCleanupOutcome.RetryLater
                }
                jobStore.clearSessionUri(committed.jobId)
                jobStore.ackFailure(committed.jobId)
                return CancelCleanupOutcome.RetainedCommitted(committed)
            }
            is RemoteLookup.PresentUnverified -> {
                var authFailed = false
                var retry = false
                for (remoteFileId in lookup.remoteFileIds) {
                    when (
                        bestEffortDelete(
                            remoteFileId = remoteFileId,
                            accessToken = accessToken,
                            httpClient = httpClient,
                        )
                    ) {
                        DeleteOutcome.AuthFailed -> authFailed = true
                        DeleteOutcome.RetryLater -> retry = true
                        DeleteOutcome.Cleared -> Unit
                    }
                }
                if (authFailed) {
                    return needsReauth(jobStore, working)
                }
                if (retry) {
                    return CancelCleanupOutcome.RetryLater
                }
                jobStore.cancelAndCleanup(working.jobId)
                return CancelCleanupOutcome.ClearedLocal
            }
            RemoteLookup.Absent -> {
                jobStore.cancelAndCleanup(working.jobId)
                return CancelCleanupOutcome.ClearedLocal
            }
            RemoteLookup.RetryLater -> return CancelCleanupOutcome.RetryLater
            RemoteLookup.NeedsReauth -> return needsReauth(jobStore, working)
        }
    }

    private fun needsReauth(
        jobStore: DriveUploadJobStore,
        job: DriveUploadJob,
    ): CancelCleanupOutcome {
        persistCleanupError(
            jobStore = jobStore,
            job = job,
            errorCode = ERROR_CLEANUP_NEEDS_REAUTH,
        )
        return CancelCleanupOutcome.NeedsReauth
    }

    /**
     * 使用者確認放棄清理：帳戶相符時盡力刪已知殘檔，再一律清本機 job。
     * 刪除失敗不阻擋解除鎖定。
     */
    fun abandonCancelCleanup(
        jobStore: DriveUploadJobStore,
        tokenProvider: DriveAccessTokenProvider,
        job: DriveUploadJob,
        httpClient: DriveHttpClient = UrlConnectionDriveHttpClient(),
    ) {
        val current = jobStore.readJob(job.jobId) ?: return
        if (current.isRemoteCommittedPhase()) {
            return
        }
        if (!current.isCancelCleanupPhase()) {
            jobStore.markCancelCleanupPending(current.jobId)
        }
        val working = jobStore.readJob(job.jobId) ?: return
        if (working.isRemoteCommittedPhase()) {
            return
        }
        val token = tokenProvider.getAccessToken().getOrNull()
        val accessToken =
            if (token != null && tokenProvider.matchTokenToJob(working, token) == null) {
                token.accessToken
            } else {
                null
            }
        abandonCancelCleanup(
            jobStore = jobStore,
            job = working,
            accessToken = accessToken,
            httpClient = httpClient,
        )
    }

    fun abandonCancelCleanup(
        jobStore: DriveUploadJobStore,
        job: DriveUploadJob,
        accessToken: String?,
        httpClient: DriveHttpClient = UrlConnectionDriveHttpClient(),
    ) {
        val current = jobStore.readJob(job.jobId) ?: return
        if (current.isRemoteCommittedPhase()) {
            return
        }
        if (!current.isCancelCleanupPhase()) {
            jobStore.markCancelCleanupPending(current.jobId)
        }
        val working = jobStore.readJob(job.jobId) ?: return
        if (working.isRemoteCommittedPhase()) {
            return
        }
        if (!accessToken.isNullOrBlank() &&
            completeCancelCleanup(jobStore, accessToken, working, workerAlive = false, httpClient = httpClient)
                is CancelCleanupOutcome.RetainedCommitted
        ) {
            return
        }
        jobStore.cancelAndCleanup(working.jobId)
    }

    private fun classifyTokenFailure(
        jobStore: DriveUploadJobStore,
        job: DriveUploadJob,
        error: Throwable,
    ): CancelCleanupOutcome {
        val tokenError = (error as? DriveAccessTokenProvider.TokenException)?.error
        return when (tokenError) {
            DriveAccessTokenProvider.TokenError.Transient ->
                CancelCleanupOutcome.RetryLater
            DriveAccessTokenProvider.TokenError.NeedsUserInteraction,
            DriveAccessTokenProvider.TokenError.NotSignedIn,
            DriveAccessTokenProvider.TokenError.Permanent,
            null,
            -> {
                persistCleanupError(
                    jobStore = jobStore,
                    job = job,
                    errorCode = ERROR_CLEANUP_NEEDS_REAUTH,
                )
                CancelCleanupOutcome.NeedsReauth
            }
        }
    }

    private fun persistCleanupError(
        jobStore: DriveUploadJobStore,
        job: DriveUploadJob,
        errorCode: String,
    ) {
        val current = jobStore.readJob(job.jobId) ?: return
        if (current.lastErrorCode == errorCode) {
            return
        }
        jobStore.updateJobCas(
            current.copy(
                lastErrorCode = errorCode,

            ),
            expectedGeneration = current.generation,
            durability = DriveUploadJobStore.Durability.Critical,
        )
    }

    private sealed class RemoteLookup {
        data class Verified(val job: DriveUploadJob) : RemoteLookup()

        data class PresentUnverified(val remoteFileIds: List<String>) : RemoteLookup()

        data object Absent : RemoteLookup()

        data object RetryLater : RemoteLookup()

        data object NeedsReauth : RemoteLookup()
    }

    private fun lookupRemote(
        job: DriveUploadJob,
        accessToken: String,
        httpClient: DriveHttpClient,
    ): RemoteLookup {
        if (job.remoteFileId.isNotBlank()) {
            when (val byId = getById(job, job.remoteFileId, accessToken, httpClient)) {
                is RemoteLookup.Absent -> Unit
                else -> return byId
            }
        }
        return listByUploadJobId(job, accessToken, httpClient)
    }

    private fun getById(
        job: DriveUploadJob,
        remoteFileId: String,
        accessToken: String,
        httpClient: DriveHttpClient,
    ): RemoteLookup {
        val fileId = remoteFileId.trim()
        if (!isSafeFileId(fileId)) {
            return RemoteLookup.Absent
        }
        val response =
            try {
                httpClient.execute(driveFileMetadataRequest(fileId, accessToken))
            } catch (_: IOException) {
                return RemoteLookup.RetryLater
            }
        return when (response.code) {
            200 -> interpretMetadata(job, response.body, remoteFileIdHint = fileId)
            404 -> RemoteLookup.Absent
            in 500..599 -> RemoteLookup.RetryLater
            else -> {
                if (isAuthFailure(response.code, response.body)) {
                    Log.w(TAG, "get remote file auth HTTP ${response.code}")
                    RemoteLookup.NeedsReauth
                } else {
                    Log.w(TAG, "get remote file HTTP ${response.code}")
                    RemoteLookup.RetryLater
                }
            }
        }
    }

    private fun listByUploadJobId(
        job: DriveUploadJob,
        accessToken: String,
        httpClient: DriveHttpClient,
    ): RemoteLookup {
        val response =
            try {
                httpClient.execute(driveFilesByUploadJobRequest(job.jobId, accessToken))
            } catch (_: IOException) {
                return RemoteLookup.RetryLater
            }
        if (response.code in 500..599) {
            return RemoteLookup.RetryLater
        }
        if (response.code != 200) {
            if (isAuthFailure(response.code, response.body)) {
                Log.w(TAG, "list remote files auth HTTP ${response.code}")
                return RemoteLookup.NeedsReauth
            }
            Log.w(TAG, "list remote files HTTP ${response.code}")
            return RemoteLookup.RetryLater
        }
        val files = runCatching { JSONObject(response.body).optJSONArray("files") }.getOrNull()
            ?: return RemoteLookup.RetryLater
        if (files.length() == 0) {
            return RemoteLookup.Absent
        }
        val verified = mutableListOf<DriveUploadJob>()
        val unverifiedIds = mutableListOf<String>()
        for (index in 0 until files.length()) {
            val item = files.optJSONObject(index) ?: return RemoteLookup.RetryLater
            val body = item.toString()
            val id = item.optString("id").trim()
            // 舊識別碼查無檔時，用工作識別碼認定清單中的檔案。
            when (val interpreted = interpretMetadata(job.copy(remoteFileId = ""), body, remoteFileIdHint = id)) {
                is RemoteLookup.Verified -> verified.add(interpreted.job)
                is RemoteLookup.PresentUnverified -> unverifiedIds.addAll(interpreted.remoteFileIds)
                else -> return RemoteLookup.RetryLater
            }
        }
        return when {
            verified.size == 1 && unverifiedIds.isEmpty() -> RemoteLookup.Verified(verified[0])
            verified.isNotEmpty() -> {
                if (verified.size == 1) {
                    var retry = false
                    for (id in unverifiedIds.distinct()) {
                        when (bestEffortDelete(id, accessToken, httpClient)) {
                            DeleteOutcome.AuthFailed -> return RemoteLookup.NeedsReauth
                            DeleteOutcome.RetryLater -> retry = true
                            DeleteOutcome.Cleared -> Unit
                        }
                    }
                    if (retry) {
                        RemoteLookup.RetryLater
                    } else {
                        RemoteLookup.Verified(verified[0])
                    }
                } else {
                    RemoteLookup.RetryLater
                }
            }
            unverifiedIds.isNotEmpty() ->
                RemoteLookup.PresentUnverified(unverifiedIds.distinct())
            else -> RemoteLookup.Absent
        }
    }

    private fun interpretMetadata(
        job: DriveUploadJob,
        body: String,
        remoteFileIdHint: String,
    ): RemoteLookup {
        val json = runCatching { JSONObject(body) }.getOrNull() ?: return RemoteLookup.RetryLater
        val id = json.optString("id").trim()
        val owner = json.optJSONObject("appProperties")?.optString("uploadJobId")?.trim()
        if (!isSafeFileId(id) || id != remoteFileIdHint || owner != job.jobId) return RemoteLookup.RetryLater
        DriveResumableUploader.verifyCompletion(job, body)?.let { return RemoteLookup.Verified(it) }

        val size = json.optString("size").toLongOrNull()
        val md5 = json.optString("md5Checksum").trim()
        val sizeMismatch = size != null && size != job.sizeBytes
        val checksumMismatch = md5.isNotBlank() && job.md5.isNotBlank() && !md5.equals(job.md5, ignoreCase = true)
        return if (sizeMismatch || checksumMismatch) {
            RemoteLookup.PresentUnverified(listOf(id))
        } else {
            RemoteLookup.RetryLater
        }
    }

    private fun isSafeFileId(fileId: String): Boolean =
        fileId.isNotEmpty() && SAFE_FILE_ID.matches(fileId)

    private fun isAuthFailure(code: Int, body: String): Boolean {
        if (code == 401) {
            return true
        }
        return code == 403 && !DriveResumableUploader.isRateLimit(body)
    }
}
