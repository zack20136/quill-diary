package zack20136.com.quill_diary.drive

import android.util.Log
import org.json.JSONObject
import java.io.IOException
import java.net.URLEncoder

/**
 * 取消上傳後盡力刪除可能殘留的 Drive 檔，失敗不拋出。
 * 亦負責 CANCEL_CLEANUP_PENDING 的查詢／刪除收尾。
 */
object DriveRemoteFileCleanup {
    private const val TAG = "DriveRemoteFileCleanup"
    private const val FILES_API = "https://www.googleapis.com/drive/v3/files/"
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

        /** 未登入或需使用者重新授權；保留 pending，UI 應允許重連原帳號。 */
        data object NeedsReauth : CancelCleanupOutcome()

        /** 目前簽入帳號與 job 不符；保留 pending，UI 應提示重連或放棄。 */
        data object AccountMismatch : CancelCleanupOutcome()
    }

    fun bestEffortDelete(
        tokenProvider: DriveAccessTokenProvider,
        remoteFileId: String,
        httpClient: DriveResumableUploader.HttpClient = DriveResumableUploader.DefaultHttpClient(),
    ): DeleteOutcome {
        val token =
            tokenProvider.getAccessToken().getOrElse { error ->
                Log.w(TAG, "skip delete: token unavailable", error)
                return DeleteOutcome.RetryLater
            }
        return bestEffortDelete(
            remoteFileId = remoteFileId,
            accessToken = token.accessToken,
            httpClient = httpClient,
        )
    }

    fun bestEffortDelete(
        remoteFileId: String,
        accessToken: String,
        httpClient: DriveResumableUploader.HttpClient = DriveResumableUploader.DefaultHttpClient(),
    ): DeleteOutcome {
        val fileId = remoteFileId.trim()
        if (!isSafeFileId(fileId) || accessToken.isBlank()) {
            return DeleteOutcome.Cleared
        }
        return runCatching {
            val response =
                httpClient.execute(
                    DriveResumableUploader.HttpRequest(
                        method = "DELETE",
                        url = FILES_API + fileId,
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
     * [workerAlive] 為 true 時，查無檔不得刪本機。
     */
    fun completeCancelCleanup(
        jobStore: DriveUploadJobStore,
        tokenProvider: DriveAccessTokenProvider,
        job: DriveUploadJob,
        workerAlive: Boolean,
        httpClient: DriveResumableUploader.HttpClient = DriveResumableUploader.DefaultHttpClient(),
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
        httpClient: DriveResumableUploader.HttpClient = DriveResumableUploader.DefaultHttpClient(),
    ): CancelCleanupOutcome {
        val current = jobStore.readJob(job.jobId) ?: return CancelCleanupOutcome.ClearedLocal
        if (current.isRemoteCommittedPhase()) {
            return CancelCleanupOutcome.RetainedCommitted(current)
        }
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
                            lastErrorMessage = null,
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
                if (workerAlive) {
                    return CancelCleanupOutcome.RetryLater
                }
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
     * 使用者確認放棄清理：帳號相符時盡力刪已知殘檔，再一律清本機 job。
     * 刪除失敗不阻擋解除鎖定。
     */
    fun abandonCancelCleanup(
        jobStore: DriveUploadJobStore,
        tokenProvider: DriveAccessTokenProvider,
        job: DriveUploadJob,
        httpClient: DriveResumableUploader.HttpClient = DriveResumableUploader.DefaultHttpClient(),
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
        httpClient: DriveResumableUploader.HttpClient = DriveResumableUploader.DefaultHttpClient(),
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
        if (!accessToken.isNullOrBlank()) {
            bestEffortDeleteKnownRemotes(working, accessToken, httpClient)
        }
        jobStore.cancelAndCleanup(working.jobId)
    }

    private fun bestEffortDeleteKnownRemotes(
        job: DriveUploadJob,
        accessToken: String,
        httpClient: DriveResumableUploader.HttpClient,
    ) {
        val ids = linkedSetOf<String>()
        if (job.remoteFileId.isNotBlank()) {
            ids.add(job.remoteFileId.trim())
        }
        when (val listed = listByUploadJobId(job, accessToken, httpClient)) {
            is RemoteLookup.PresentUnverified -> ids.addAll(listed.remoteFileIds)
            is RemoteLookup.Verified -> {
                val id = listed.job.remoteFileId.trim()
                if (id.isNotEmpty()) {
                    ids.add(id)
                }
            }
            else -> Unit
        }
        for (id in ids) {
            bestEffortDelete(remoteFileId = id, accessToken = accessToken, httpClient = httpClient)
        }
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
        if (current.lastErrorCode == errorCode && current.lastErrorMessage == null) {
            return
        }
        jobStore.updateJobCas(
            current.copy(
                lastErrorCode = errorCode,
                lastErrorMessage = null,
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
        httpClient: DriveResumableUploader.HttpClient,
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
        httpClient: DriveResumableUploader.HttpClient,
    ): RemoteLookup {
        val fileId = remoteFileId.trim()
        if (!isSafeFileId(fileId)) {
            return RemoteLookup.Absent
        }
        val response =
            try {
                httpClient.execute(
                    DriveResumableUploader.HttpRequest(
                        method = "GET",
                        url =
                            FILES_API + fileId +
                                "?fields=id,name,size,md5Checksum,appProperties",
                        headers = mapOf("Authorization" to "Bearer $accessToken"),
                    ),
                )
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
        httpClient: DriveResumableUploader.HttpClient,
    ): RemoteLookup {
        val query =
            "appProperties has { key='uploadJobId' and value='${job.jobId}' } and trashed = false"
        val response =
            try {
                httpClient.execute(
                    DriveResumableUploader.HttpRequest(
                        method = "GET",
                        url =
                            "https://www.googleapis.com/drive/v3/files" +
                                "?spaces=appDataFolder" +
                                "&q=${URLEncoder.encode(query, "UTF-8")}" +
                                "&fields=files(id,name,size,md5Checksum,appProperties)",
                        headers = mapOf("Authorization" to "Bearer $accessToken"),
                    ),
                )
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
        if (files == null || files.length() == 0) {
            return RemoteLookup.Absent
        }
        val verified = mutableListOf<DriveUploadJob>()
        val unverifiedIds = mutableListOf<String>()
        for (index in 0 until files.length()) {
            val item = files.optJSONObject(index) ?: continue
            val body = item.toString()
            val id = item.optString("id").trim()
            when (val interpreted = interpretMetadata(job, body, remoteFileIdHint = id)) {
                is RemoteLookup.Verified -> verified.add(interpreted.job)
                is RemoteLookup.PresentUnverified -> unverifiedIds.addAll(interpreted.remoteFileIds)
                else -> if (id.isNotEmpty()) unverifiedIds.add(id)
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
        val verified = DriveResumableUploader.verifyCompletion(job, body)
        if (verified != null) {
            return RemoteLookup.Verified(verified)
        }
        if (body.isBlank()) {
            return RemoteLookup.PresentUnverified(listOf(remoteFileIdHint))
        }
        val json = runCatching { JSONObject(body) }.getOrNull()
        val id = json?.optString("id")?.trim().orEmpty().ifEmpty { remoteFileIdHint }
        if (id.isEmpty()) {
            return RemoteLookup.Absent
        }
        return RemoteLookup.PresentUnverified(listOf(id))
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
