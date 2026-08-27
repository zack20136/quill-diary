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

    enum class DeleteOutcome {
        /** 2xx／404，或非法 id／空白 token（視為無可刪物件）。 */
        Cleared,

        /** 網路或暫時性失敗，應保留 job 稍後重試。 */
        RetryLater,
    }

    sealed class CancelCleanupOutcome {
        data class RetainedCommitted(val job: DriveUploadJob) : CancelCleanupOutcome()

        data object ClearedLocal : CancelCleanupOutcome()

        data object RetryLater : CancelCleanupOutcome()
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
                return CancelCleanupOutcome.RetryLater
            }
        if (tokenProvider.matchTokenToJob(job, token) != null) {
            return CancelCleanupOutcome.RetryLater
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
            return CancelCleanupOutcome.RetryLater
        }

        when (val lookup = lookupRemote(working, accessToken, httpClient)) {
            is RemoteLookup.Verified -> {
                val committed =
                    jobStore.updateJobCas(
                        lookup.job.copy(
                            phase = DriveUploadPhase.STATUS_PENDING,
                            confirmedOffset = lookup.job.sizeBytes,
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
                var retry = false
                for (remoteFileId in lookup.remoteFileIds) {
                    when (
                        bestEffortDelete(
                            remoteFileId = remoteFileId,
                            accessToken = accessToken,
                            httpClient = httpClient,
                        )
                    ) {
                        DeleteOutcome.RetryLater -> retry = true
                        DeleteOutcome.Cleared -> Unit
                    }
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
        }
    }

    private sealed class RemoteLookup {
        data class Verified(val job: DriveUploadJob) : RemoteLookup()

        data class PresentUnverified(val remoteFileIds: List<String>) : RemoteLookup()

        data object Absent : RemoteLookup()

        data object RetryLater : RemoteLookup()
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
                Log.w(TAG, "get remote file HTTP ${response.code}")
                RemoteLookup.RetryLater
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
                    for (id in unverifiedIds.distinct()) {
                        bestEffortDelete(id, accessToken, httpClient)
                    }
                    RemoteLookup.Verified(verified[0])
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
}
