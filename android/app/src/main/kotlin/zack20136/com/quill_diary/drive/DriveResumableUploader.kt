package zack20136.com.quill_diary.drive

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.min
import kotlin.random.Random

/** 除最後一塊外，Drive 上傳區塊須為 256 KiB 的倍數。 */
internal class DriveResumableUploader(
    private val jobStore: DriveUploadJobStore,
    private val tokenProvider: DriveAccessTokenProvider,
    private val httpClient: DriveHttpClient = UrlConnectionDriveHttpClient(),
) {
    private val userCancel = AtomicBoolean(false)

    fun cancelUser() {
        userCancel.set(true)
        abortTransport()
    }

    /** 只斷開進行中的 HTTP，不改業務狀態。 */
    fun abortTransport() {
        httpClient.disconnectActive()
    }

    fun run(
        initialJob: DriveUploadJob,
        onUpdate: (DriveUploadJob) -> Unit,
    ): DriveUploadOutcome {
        var job = initialJob
        if (userCancel.get()) {
            return DriveUploadOutcome.Cancelled
        }

        if (job.isRemoteCommittedPhase()) {
            return DriveUploadOutcome.Committed(job)
        }

        if (job.retryCount >= MAX_ATTEMPTS) {
            return DriveUploadOutcome.Failed(
                code = "max_attempts",
            )
        }

        when (val verified = ensureStaging(job, onUpdate)) {
            is StagingResult.Failed -> return verified.outcome
            is StagingResult.Ready -> job = verified.job
        }

        val accountError = tokenProvider.checkSignedInAccount(job)
        if (accountError != null) {
            return handleTokenError(job, accountError, onUpdate)
        }

        if (job.remoteFileId.isBlank()) {
            when (val idOutcome = allocateRemoteFileId(job, onUpdate)) {
                is AllocateIdResult.Success -> job = idOutcome.job
                is AllocateIdResult.Outcome -> return idOutcome.outcome
            }
        }

        lookupCommittedFile(job, onUpdate)?.let { return it }

        val initialTokenResult = tokenProvider.getAccessToken()
        if (initialTokenResult.isFailure) {
            val error =
                (initialTokenResult.exceptionOrNull() as? DriveAccessTokenProvider.TokenException)
                    ?.error
                    ?: DriveAccessTokenProvider.TokenError.Transient
            return handleTokenError(job, error, onUpdate)
        }
        val initialToken = initialTokenResult.getOrThrow()
        val initialAccountError = tokenProvider.matchTokenToJob(job, initialToken)
        if (initialAccountError != null) {
            return handleTokenError(job, initialAccountError, onUpdate)
        }
        var accessToken = initialToken.accessToken
        var tokenRefreshedForChunk = false
        var sessionRecreates = 0

        job =
            persistOrAbort(
                job.copy(
                    phase = DriveUploadPhase.UPLOADING,
                    lastErrorCode = null,

                ),
                onUpdate,
            ) ?: return DriveUploadOutcome.Cancelled

        var sessionUri = jobStore.readSessionUri(job.jobId)
        if (sessionUri.isNullOrBlank()) {
            when (
                val created =
                    createSession(
                        job = job,
                        accessToken = accessToken,
                        onUpdate = onUpdate,
                        allowTokenRefresh = true,
                    )
            ) {
                is CreateSessionResult.Success -> {
                    sessionUri = created.sessionUri
                    job = created.job
                    accessToken = created.accessToken
                }
                is CreateSessionResult.Outcome -> return created.outcome
            }
        }

        when (
            val probed =
                probeOffset(
                    job = job,
                    sessionUri = sessionUri!!,
                    accessToken = accessToken,
                    onUpdate = onUpdate,
                    allowTokenRefresh = true,
                    sessionRecreates = sessionRecreates,
                )
        ) {
            is ProbeResult.Committed -> return DriveUploadOutcome.Committed(probed.job)
            is ProbeResult.Ready -> {
                job = probed.job
                sessionUri = probed.sessionUri
                accessToken = probed.accessToken
                sessionRecreates = probed.sessionRecreates
            }
            is ProbeResult.Outcome -> return probed.outcome
        }

        val file = File(job.stagingPath)
        while (job.confirmedOffset < job.sizeBytes) {
            if (userCancel.get()) {
                return DriveUploadOutcome.Cancelled
            }

            val start = job.confirmedOffset
            val endExclusive = min(start + CHUNK_SIZE, job.sizeBytes)
            val length = (endExclusive - start).toInt()
            val contentRange = "bytes $start-${endExclusive - 1}/${job.sizeBytes}"
            val response =
                try {
                    httpClient.execute(
                        DriveHttpRequest(
                            method = "PUT",
                            url = sessionUri!!,
                            headers =
                                mapOf(
                                    "Authorization" to "Bearer $accessToken",
                                    "Content-Length" to length.toString(),
                                    "Content-Range" to contentRange,
                                    "Content-Type" to "application/zip",
                                ),
                            body =
                                DriveHttpBody.FileRange(
                                    file = file,
                                    offset = start,
                                    length = length,
                                ),
                        ),
                    )
                } catch (_: IOException) {
                    if (userCancel.get()) {
                        return DriveUploadOutcome.Cancelled
                    }
                    return waitingForNetwork(
                        job.copy(
                            retryCount = job.retryCount + 1,
                            lastErrorCode = "network",

                            nextRetryAtEpochMs =
                                System.currentTimeMillis() +
                                    backoffMs(job.retryCount + 1, null),
                        ),
                        onUpdate,
                    )
                }

            when (response.code) {
                200, 201 -> {
                    val completed =
                        verifyCompletionWithMetadata(job, response.body, accessToken)
                    if (completed == null) {
                        return DriveUploadOutcome.Failed(
                            code = "completion_mismatch",
                        )
                    }
                    return commitPending(completed, onUpdate)
                }
                308 -> {
                    val nextOffset = parseNextOffset(response.headers["range"], job.sizeBytes)
                    if (nextOffset == null) {
                        return DriveUploadOutcome.Failed(
                            code = "invalid_range",
                        )
                    }
                    tokenRefreshedForChunk = false
                    val progressed =
                        job.copy(
                            confirmedOffset = nextOffset,
                            phase = DriveUploadPhase.UPLOADING,
                        )
                    // 立即保存伺服器確認進度，讓設定頁和通知一致。
                    job =
                        persistOrAbort(
                            progressed,
                            onUpdate,
                            durability = DriveUploadJobStore.Durability.Progress,
                        ) ?: return DriveUploadOutcome.Cancelled
                }
                401 -> {
                    if (tokenRefreshedForChunk) {
                        return handleTokenError(
                            job,
                            DriveAccessTokenProvider.TokenError.NeedsUserInteraction,
                            onUpdate,
                        )
                    }
                    when (val refreshed = refreshAccessToken(job, onUpdate)) {
                        is TokenRefreshResult.Failed -> return refreshed.outcome
                        is TokenRefreshResult.Ok -> {
                            accessToken = refreshed.accessToken
                            tokenRefreshedForChunk = true
                        }
                    }
                }
                404 -> {
                    if (sessionRecreates >= 1) {
                        return DriveUploadOutcome.Failed(
                            code = "session_expired",
                        )
                    }
                    jobStore.clearSessionUri(job.jobId)
                    sessionRecreates += 1
                    when (
                        val created =
                            createSession(
                                job = job,
                                accessToken = accessToken,
                                onUpdate = onUpdate,
                                allowTokenRefresh = true,
                            )
                    ) {
                        is CreateSessionResult.Success -> {
                            accessToken = created.accessToken
                            when (
                                val probed =
                                    probeOffset(
                                        job = created.job,
                                        sessionUri = created.sessionUri,
                                        accessToken = created.accessToken,
                                        onUpdate = onUpdate,
                                        allowTokenRefresh = true,
                                        sessionRecreates = sessionRecreates,
                                    )
                            ) {
                                is ProbeResult.Committed ->
                                    return DriveUploadOutcome.Committed(probed.job)
                                is ProbeResult.Ready -> {
                                    job = probed.job
                                    sessionUri = probed.sessionUri
                                    accessToken = probed.accessToken
                                    sessionRecreates = probed.sessionRecreates
                                }
                                is ProbeResult.Outcome -> return probed.outcome
                            }
                        }
                        is CreateSessionResult.Outcome -> return created.outcome
                    }
                }
                429, 500, 502, 503, 504 -> {
                    return waitingForNetwork(
                        job =
                            job.copy(
                                retryCount = job.retryCount + 1,
                                lastErrorCode = "http_${response.code}",

                                nextRetryAtEpochMs =
                                    System.currentTimeMillis() +
                                        backoffMs(job.retryCount + 1, response),
                            ),
                        onUpdate = onUpdate,
                    )
                }
                403 -> {
                    if (isRateLimit(response.body)) {
                        return waitingForNetwork(
                            job =
                                job.copy(
                                    retryCount = job.retryCount + 1,
                                    lastErrorCode = "rate_limited",

                                    nextRetryAtEpochMs =
                                        System.currentTimeMillis() +
                                            backoffMs(job.retryCount + 1, response),
                                ),
                            onUpdate = onUpdate,
                        )
                    }
                    return DriveUploadOutcome.Failed(
                        code = "forbidden",
                    )
                }
                else -> {
                    return DriveUploadOutcome.Failed(
                        code = "http_${response.code}",
                    )
                }
            }
        }

        return when (val existing = lookupCommittedFile(job, onUpdate)) {
            is DriveUploadOutcome -> existing
            else ->
                DriveUploadOutcome.Failed(
                    code = "incomplete",
                )
        }
    }

    private sealed class StagingResult {
        data class Ready(val job: DriveUploadJob) : StagingResult()

        data class Failed(val outcome: DriveUploadOutcome) : StagingResult()
    }

    private sealed class AllocateIdResult {
        data class Success(val job: DriveUploadJob) : AllocateIdResult()

        data class Outcome(val outcome: DriveUploadOutcome) : AllocateIdResult()
    }

    private sealed class CreateSessionResult {
        data class Success(
            val job: DriveUploadJob,
            val sessionUri: String,
            val accessToken: String,
        ) : CreateSessionResult()

        data class Outcome(val outcome: DriveUploadOutcome) : CreateSessionResult()
    }

    private sealed class ProbeResult {
        data class Ready(
            val job: DriveUploadJob,
            val sessionUri: String,
            val accessToken: String,
            val sessionRecreates: Int,
        ) : ProbeResult()

        data class Committed(val job: DriveUploadJob) : ProbeResult()

        data class Outcome(val outcome: DriveUploadOutcome) : ProbeResult()
    }

    private sealed class TokenRefreshResult {
        data class Ok(val accessToken: String) : TokenRefreshResult()

        data class Failed(val outcome: DriveUploadOutcome) : TokenRefreshResult()
    }

    /**
     * 信任 enqueue 時寫入的 md5；僅檢查存在、staging root 與長度。
     * md5 空白時才算一次並回寫。
     */
    private fun ensureStaging(
        job: DriveUploadJob,
        onUpdate: (DriveUploadJob) -> Unit,
    ): StagingResult {
        val staging = File(job.stagingPath)
        if (!staging.isFile ||
            staging.length() != job.sizeBytes ||
            !jobStore.isInsideStagingRoot(job.stagingPath)
        ) {
            return StagingResult.Failed(
                DriveUploadOutcome.Failed(
                    code = "staging_invalid",
                ),
            )
        }
        if (job.md5.isNotBlank()) {
            return StagingResult.Ready(job)
        }
        val computed = DriveUploadJobStore.md5Hex(staging)
        val saved =
            persistOrAbort(job.copy(md5 = computed), onUpdate)
                ?: return StagingResult.Failed(DriveUploadOutcome.Cancelled)
        return StagingResult.Ready(saved)
    }

    private fun allocateRemoteFileId(
        job: DriveUploadJob,
        onUpdate: (DriveUploadJob) -> Unit,
    ): AllocateIdResult {
        var allowTokenRefresh = true
        while (true) {
            if (userCancel.get()) {
                return AllocateIdResult.Outcome(DriveUploadOutcome.Cancelled)
            }
            val tokenResult = tokenProvider.getAccessToken(clearCache = !allowTokenRefresh)
            if (tokenResult.isFailure) {
                val error =
                    (tokenResult.exceptionOrNull() as? DriveAccessTokenProvider.TokenException)
                        ?.error
                        ?: DriveAccessTokenProvider.TokenError.Transient
                return AllocateIdResult.Outcome(handleTokenError(job, error, onUpdate))
            }
            val token = tokenResult.getOrThrow()
            val accountError = tokenProvider.matchTokenToJob(job, token)
            if (accountError != null) {
                return AllocateIdResult.Outcome(handleTokenError(job, accountError, onUpdate))
            }
            val accessToken = token.accessToken
            val response =
                try {
                    httpClient.execute(
                        DriveHttpRequest(
                            method = "GET",
                            url =
                                "https://www.googleapis.com/drive/v3/files/generateIds" +
                                    "?count=1&space=appDataFolder&type=files",
                            headers = mapOf("Authorization" to "Bearer $accessToken"),
                        ),
                    )
                } catch (_: IOException) {
                    if (userCancel.get()) {
                        return AllocateIdResult.Outcome(DriveUploadOutcome.Cancelled)
                    }
                    return AllocateIdResult.Outcome(
                        waitingForNetwork(
                            job.copy(
                                retryCount = job.retryCount + 1,
                                lastErrorCode = "generate_id",

                                nextRetryAtEpochMs =
                                    System.currentTimeMillis() +
                                        backoffMs(job.retryCount + 1, null),
                            ),
                            onUpdate,
                        ),
                    )
                }
            when (response.code) {
                in 200..299 -> {
                    val ids = JSONObject(response.body).optJSONArray("ids")
                    val id = ids?.optString(0)?.trim().orEmpty()
                    if (id.isEmpty()) {
                        return AllocateIdResult.Outcome(
                            DriveUploadOutcome.Failed(
                                code = "generate_id",
                            ),
                        )
                    }
                    val saved =
                        persistOrAbort(job.copy(remoteFileId = id), onUpdate)
                            ?: return AllocateIdResult.Outcome(DriveUploadOutcome.Cancelled)
                    return AllocateIdResult.Success(saved)
                }
                401 -> {
                    if (!allowTokenRefresh) {
                        return AllocateIdResult.Outcome(
                            handleTokenError(
                                job,
                                DriveAccessTokenProvider.TokenError.NeedsUserInteraction,
                                onUpdate,
                            ),
                        )
                    }
                    allowTokenRefresh = false
                }
                403 -> {
                    if (isRateLimit(response.body)) {
                        return AllocateIdResult.Outcome(
                            waitingForNetwork(
                                job.copy(
                                    retryCount = job.retryCount + 1,
                                    lastErrorCode = "rate_limited",

                                    nextRetryAtEpochMs =
                                        System.currentTimeMillis() +
                                            backoffMs(job.retryCount + 1, response),
                                ),
                                onUpdate,
                            ),
                        )
                    }
                    return AllocateIdResult.Outcome(
                        handleTokenError(
                            job,
                            DriveAccessTokenProvider.TokenError.NeedsUserInteraction,
                            onUpdate,
                        ),
                    )
                }
                429, 500, 502, 503, 504 -> {
                    return AllocateIdResult.Outcome(
                        waitingForNetwork(
                            job.copy(
                                retryCount = job.retryCount + 1,
                                lastErrorCode = "http_${response.code}",

                                nextRetryAtEpochMs =
                                    System.currentTimeMillis() +
                                        backoffMs(job.retryCount + 1, response),
                            ),
                            onUpdate,
                        ),
                    )
                }
                in 400..499 -> {
                    return AllocateIdResult.Outcome(
                        DriveUploadOutcome.Failed(
                            code = "http_${response.code}",
                        ),
                    )
                }
                else -> {
                    return AllocateIdResult.Outcome(
                        waitingForNetwork(
                            job.copy(
                                retryCount = job.retryCount + 1,
                                lastErrorCode = "http_${response.code}",

                                nextRetryAtEpochMs =
                                    System.currentTimeMillis() +
                                        backoffMs(job.retryCount + 1, response),
                            ),
                            onUpdate,
                        ),
                    )
                }
            }
        }
    }

    private fun commitPending(
        verified: DriveUploadJob,
        onUpdate: (DriveUploadJob) -> Unit,
    ): DriveUploadOutcome {
        // 取消與完成相撞時仍須保存成功，避免對帳誤刪成品。
        val committed =
            persistOrAbort(
                verified.copy(
                    phase = DriveUploadPhase.STATUS_PENDING,
                    confirmedOffset = verified.sizeBytes,
                ),
                onUpdate,
                ignoreUserCancel = true,
            ) ?: return DriveUploadOutcome.Cancelled
        jobStore.clearSessionUri(committed.jobId)
        return DriveUploadOutcome.Committed(committed)
    }

    private fun createSession(
        job: DriveUploadJob,
        accessToken: String,
        onUpdate: (DriveUploadJob) -> Unit,
        allowTokenRefresh: Boolean,
    ): CreateSessionResult {
        if (userCancel.get()) {
            return CreateSessionResult.Outcome(DriveUploadOutcome.Cancelled)
        }
        val metadata =
            JSONObject()
                .put("id", job.remoteFileId)
                .put("name", job.fileName)
                .put("parents", JSONArray().put("appDataFolder"))
                .put(
                    "appProperties",
                    JSONObject()
                        .put("uploadJobId", job.jobId)
                        .put("md5", job.md5),
                )
                .toString()
                .toByteArray(StandardCharsets.UTF_8)

        val response =
            try {
                httpClient.execute(
                    DriveHttpRequest(
                        method = "POST",
                        url =
                            "https://www.googleapis.com/upload/drive/v3/files" +
                                "?uploadType=resumable&fields=id,size,md5Checksum,appProperties",
                        headers =
                            mapOf(
                                "Authorization" to "Bearer $accessToken",
                                "Content-Type" to "application/json; charset=UTF-8",
                                "Content-Length" to metadata.size.toString(),
                                "X-Upload-Content-Type" to "application/zip",
                                "X-Upload-Content-Length" to job.sizeBytes.toString(),
                            ),
                        body = DriveHttpBody.Bytes(metadata),
                    ),
                )
            } catch (_: IOException) {
                if (userCancel.get()) {
                    return CreateSessionResult.Outcome(DriveUploadOutcome.Cancelled)
                }
                return CreateSessionResult.Outcome(
                    waitingForNetwork(
                        job.copy(
                            retryCount = job.retryCount + 1,
                            lastErrorCode = "network",

                            nextRetryAtEpochMs =
                                System.currentTimeMillis() +
                                    backoffMs(job.retryCount + 1, null),
                        ),
                        onUpdate,
                    ),
                )
            }

        when (response.code) {
            200 -> {
                val location = response.headers["location"]
                if (location.isNullOrBlank() || !isAllowedUploadLocation(location)) {
                    return CreateSessionResult.Outcome(
                        DriveUploadOutcome.Failed(
                            code = "missing_session",
                        ),
                    )
                }
                jobStore.writeSessionUri(job.jobId, location)
                val updated =
                    persistOrAbort(job.copy(phase = DriveUploadPhase.UPLOADING), onUpdate)
                        ?: return CreateSessionResult.Outcome(DriveUploadOutcome.Cancelled)
                return CreateSessionResult.Success(updated, location, accessToken)
            }
            401 -> {
                if (!allowTokenRefresh) {
                    return CreateSessionResult.Outcome(
                        handleTokenError(
                            job,
                            DriveAccessTokenProvider.TokenError.NeedsUserInteraction,
                            onUpdate,
                        ),
                    )
                }
                return when (val refreshed = refreshAccessToken(job, onUpdate)) {
                    is TokenRefreshResult.Failed ->
                        CreateSessionResult.Outcome(refreshed.outcome)
                    is TokenRefreshResult.Ok ->
                        createSession(
                            job,
                            refreshed.accessToken,
                            onUpdate,
                            allowTokenRefresh = false,
                        )
                }
            }
            409 -> {
                when (val existing = lookupCommittedFile(job, onUpdate)) {
                    is DriveUploadOutcome.Committed ->
                        return CreateSessionResult.Outcome(existing)
                    is DriveUploadOutcome -> return CreateSessionResult.Outcome(existing)
                    else -> {
                        return CreateSessionResult.Outcome(
                            DriveUploadOutcome.Failed(
                                code = "conflict",
                            ),
                        )
                    }
                }
            }
            429, 500, 502, 503, 504 ->
                return CreateSessionResult.Outcome(
                    waitingForNetwork(
                        job.copy(
                            retryCount = job.retryCount + 1,
                            lastErrorCode = "http_${response.code}",
                            nextRetryAtEpochMs =
                                System.currentTimeMillis() +
                                    backoffMs(job.retryCount + 1, response),
                        ),
                        onUpdate,
                    ),
                )
            else -> {
                return CreateSessionResult.Outcome(
                    DriveUploadOutcome.Failed(
                        code = "http_${response.code}",
                    ),
                )
            }
        }
    }

    private fun probeOffset(
        job: DriveUploadJob,
        sessionUri: String,
        accessToken: String,
        onUpdate: (DriveUploadJob) -> Unit,
        allowTokenRefresh: Boolean,
        sessionRecreates: Int,
    ): ProbeResult {
        val response =
            try {
                httpClient.execute(
                    DriveHttpRequest(
                        method = "PUT",
                        url = sessionUri,
                        headers =
                            mapOf(
                                "Authorization" to "Bearer $accessToken",
                                "Content-Length" to "0",
                                "Content-Range" to "bytes */${job.sizeBytes}",
                            ),
                    ),
                )
            } catch (_: IOException) {
                if (userCancel.get()) {
                    return ProbeResult.Outcome(DriveUploadOutcome.Cancelled)
                }
                return ProbeResult.Outcome(
                    waitingForNetwork(
                        job.copy(
                            retryCount = job.retryCount + 1,
                            lastErrorCode = "network",

                            nextRetryAtEpochMs =
                                System.currentTimeMillis() +
                                    backoffMs(job.retryCount + 1, null),
                        ),
                        onUpdate,
                    ),
                )
            }

        return when (response.code) {
            200, 201 -> {
                val completed = verifyCompletionWithMetadata(job, response.body, accessToken)
                if (completed == null) {
                    ProbeResult.Outcome(
                        DriveUploadOutcome.Failed(
                            code = "completion_mismatch",
                        ),
                    )
                } else {
                    when (val committed = commitPending(completed, onUpdate)) {
                        is DriveUploadOutcome.Committed -> ProbeResult.Committed(committed.job)
                        else -> ProbeResult.Outcome(committed)
                    }
                }
            }
            308 -> {
                val nextOffset = parseNextOffset(response.headers["range"], job.sizeBytes)
                if (nextOffset == null) {
                    ProbeResult.Outcome(
                        DriveUploadOutcome.Failed(
                            code = "invalid_range",
                        ),
                    )
                } else {
                    val updated =
                        persistOrAbort(job.copy(confirmedOffset = nextOffset), onUpdate)
                            ?: return ProbeResult.Outcome(DriveUploadOutcome.Cancelled)
                    ProbeResult.Ready(
                        job = updated,
                        sessionUri = sessionUri,
                        accessToken = accessToken,
                        sessionRecreates = sessionRecreates,
                    )
                }
            }
            401 -> {
                if (!allowTokenRefresh) {
                    return ProbeResult.Outcome(
                        handleTokenError(
                            job,
                            DriveAccessTokenProvider.TokenError.NeedsUserInteraction,
                            onUpdate,
                        ),
                    )
                }
                return when (val refreshed = refreshAccessToken(job, onUpdate)) {
                    is TokenRefreshResult.Failed -> ProbeResult.Outcome(refreshed.outcome)
                    is TokenRefreshResult.Ok ->
                        probeOffset(
                            job,
                            sessionUri,
                            refreshed.accessToken,
                            onUpdate,
                            allowTokenRefresh = false,
                            sessionRecreates = sessionRecreates,
                        )
                }
            }
            404 -> {
                if (sessionRecreates >= 1) {
                    return ProbeResult.Outcome(
                        DriveUploadOutcome.Failed(
                            code = "session_expired",
                        ),
                    )
                }
                jobStore.clearSessionUri(job.jobId)
                when (
                    val created =
                        createSession(job, accessToken, onUpdate, allowTokenRefresh = true)
                ) {
                    is CreateSessionResult.Success ->
                        probeOffset(
                            job = created.job,
                            sessionUri = created.sessionUri,
                            accessToken = created.accessToken,
                            onUpdate = onUpdate,
                            allowTokenRefresh = true,
                            sessionRecreates = sessionRecreates + 1,
                        )
                    is CreateSessionResult.Outcome -> ProbeResult.Outcome(created.outcome)
                }
            }
            429, 500, 502, 503, 504 ->
                ProbeResult.Outcome(
                    waitingForNetwork(
                        job.copy(
                            retryCount = job.retryCount + 1,
                            nextRetryAtEpochMs =
                                System.currentTimeMillis() +
                                    backoffMs(job.retryCount + 1, response),
                        ),
                        onUpdate,
                    ),
                )
            else -> {
                ProbeResult.Outcome(
                    DriveUploadOutcome.Failed(
                        code = "http_${response.code}",
                    ),
                )
            }
        }
    }

    private fun lookupCommittedFile(
        job: DriveUploadJob,
        onUpdate: (DriveUploadJob) -> Unit,
    ): DriveUploadOutcome? {
        if (job.remoteFileId.isBlank()) {
            return null
        }
        val tokenResult = tokenProvider.getAccessToken()
        if (tokenResult.isFailure) {
            return null
        }
        val token = tokenResult.getOrThrow()
        if (tokenProvider.matchTokenToJob(job, token) != null) {
            return null
        }
        val accessToken = token.accessToken
        val byId =
            try {
                httpClient.execute(driveFileMetadataRequest(job.remoteFileId, accessToken))
            } catch (_: IOException) {
                return null
            }
        if (byId.code == 200) {
            val verified = verifyCompletionWithMetadata(job, byId.body, accessToken)
            if (verified != null) {
                return commitPending(verified, onUpdate)
            }
        }

        val listed =
            try {
                httpClient.execute(driveFilesByUploadJobRequest(job.jobId, accessToken))
            } catch (_: IOException) {
                return null
            }
        if (listed.code != 200) {
            return null
        }
        val files = JSONObject(listed.body).optJSONArray("files") ?: return null
        val matches = mutableListOf<DriveUploadJob>()
        for (index in 0 until files.length()) {
            val item = files.optJSONObject(index) ?: continue
            val verified = verifyCompletionWithMetadata(job, item.toString(), accessToken)
                ?: continue
            matches.add(verified)
        }
        return when (matches.size) {
            0 -> null
            1 -> commitPending(matches[0], onUpdate)
            else ->
                DriveUploadOutcome.Failed(
                    code = "conflict",
                )
        }
    }

    private fun verifyCompletionWithMetadata(
        job: DriveUploadJob,
        body: String,
        accessToken: String,
    ): DriveUploadJob? {
        val fromBody = verifyCompletion(job, body)
        if (fromBody != null) {
            return fromBody
        }
        if (body.isBlank()) {
            return null
        }
        val json = runCatching { JSONObject(body) }.getOrNull() ?: return null
        val id = json.optString("id").trim()
        if (id.isEmpty()) {
            return null
        }
        val remoteMd5 = json.optString("md5Checksum").trim()
        if (remoteMd5.isNotEmpty()) {
            return null
        }
        val metadata =
            try {
                httpClient.execute(
                    DriveHttpRequest(
                        method = "GET",
                        url =
                            "https://www.googleapis.com/drive/v3/files/$id" +
                                "?fields=id,size,md5Checksum,appProperties",
                        headers = mapOf("Authorization" to "Bearer $accessToken"),
                    ),
                )
            } catch (_: IOException) {
                return null
            }
        if (metadata.code != 200) {
            return null
        }
        return verifyCompletion(job, metadata.body)
    }

    private fun waitingForNetwork(
        job: DriveUploadJob,
        onUpdate: (DriveUploadJob) -> Unit,
    ): DriveUploadOutcome {
        val updated =
            persistOrAbort(
                job.copy(
                    phase = DriveUploadPhase.WAITING_FOR_NETWORK,
                    lastErrorCode = job.lastErrorCode ?: "network",

                ),
                onUpdate,
            ) ?: return DriveUploadOutcome.Cancelled
        return DriveUploadOutcome.WaitingNetwork(updated)
    }

    private fun handleTokenError(
        job: DriveUploadJob,
        error: DriveAccessTokenProvider.TokenError,
        onUpdate: (DriveUploadJob) -> Unit,
    ): DriveUploadOutcome {
        return when (error) {
            DriveAccessTokenProvider.TokenError.NeedsUserInteraction,
            DriveAccessTokenProvider.TokenError.NotSignedIn,
            -> {
                DriveUploadOutcome.Failed(
                    code = "authorization",
                )
            }
            DriveAccessTokenProvider.TokenError.Permanent -> {
                DriveUploadOutcome.Failed(
                    code = "authorization",
                )
            }
            DriveAccessTokenProvider.TokenError.Transient ->
                waitingForNetwork(
                    job.copy(
                        lastErrorCode = "token_transient",

                        retryCount = job.retryCount + 1,
                        nextRetryAtEpochMs =
                            System.currentTimeMillis() + backoffMs(job.retryCount + 1, null),
                    ),
                    onUpdate,
                )
        }
    }

    private fun refreshAccessToken(
        job: DriveUploadJob,
        onUpdate: (DriveUploadJob) -> Unit,
    ): TokenRefreshResult {
        val refreshed = tokenProvider.getAccessToken(clearCache = true)
        if (refreshed.isFailure) {
            val error =
                (refreshed.exceptionOrNull() as? DriveAccessTokenProvider.TokenException)
                    ?.error
                    ?: DriveAccessTokenProvider.TokenError.NeedsUserInteraction
            return TokenRefreshResult.Failed(handleTokenError(job, error, onUpdate))
        }
        val token = refreshed.getOrThrow()
        val accountError = tokenProvider.matchTokenToJob(job, token)
        if (accountError != null) {
            return TokenRefreshResult.Failed(handleTokenError(job, accountError, onUpdate))
        }
        return TokenRefreshResult.Ok(token.accessToken)
    }

    private fun persistOrAbort(
        job: DriveUploadJob,
        onUpdate: (DriveUploadJob) -> Unit,
        durability: DriveUploadJobStore.Durability = DriveUploadJobStore.Durability.Critical,
        ignoreUserCancel: Boolean = false,
    ): DriveUploadJob? {
        if (!ignoreUserCancel && userCancel.get()) {
            return null
        }
        val current = jobStore.readJob(job.jobId) ?: return null
        val saved =
            jobStore.updateJobCas(
                job,
                expectedGeneration = current.generation,
                durability = durability,
            ) ?: return null
        onUpdate(saved)
        return saved
    }

    companion object {
        const val CHUNK_SIZE: Long = 8L * 1024L * 1024L
        const val MAX_ATTEMPTS: Int = 12

        private val ALLOWED_UPLOAD_HOSTS =
            setOf(
                "www.googleapis.com",
                "upload.googleapis.com",
            )

        fun isAllowedUploadLocation(location: String): Boolean {
            val uri = runCatching { URI(location) }.getOrNull() ?: return false
            if (!uri.scheme.equals("https", ignoreCase = true)) {
                return false
            }
            if (!uri.userInfo.isNullOrEmpty()) {
                return false
            }
            if (!uri.fragment.isNullOrEmpty()) {
                return false
            }
            val port = uri.port
            if (port != -1 && port != 443) {
                return false
            }
            val host = uri.host?.lowercase() ?: return false
            if (!ALLOWED_UPLOAD_HOSTS.contains(host)) {
                return false
            }
            val path = uri.path.orEmpty()
            return path.contains("/upload/drive/") || path.contains("/drive/")
        }

        internal fun verifyCompletion(job: DriveUploadJob, body: String): DriveUploadJob? {
            if (body.isBlank()) {
                return null
            }
            return runCatching {
                val json = JSONObject(body)
                val id = json.optString("id").trim()
                if (id.isEmpty()) {
                    return null
                }
                if (job.remoteFileId.isNotBlank() && id != job.remoteFileId) {
                    return null
                }
                val size = json.optString("size").toLongOrNull()
                if (size == null || size != job.sizeBytes) {
                    return null
                }
                val props = json.optJSONObject("appProperties") ?: return null
                val remoteJobId = props.optString("uploadJobId").trim()
                if (remoteJobId != job.jobId) {
                    return null
                }
                if (job.md5.isBlank()) {
                    return null
                }
                val remoteMd5 = json.optString("md5Checksum").trim()
                if (remoteMd5.isEmpty()) {
                    return null
                }
                if (!remoteMd5.equals(job.md5, ignoreCase = true)) {
                    return null
                }
                job.copy(remoteFileId = id)
            }.getOrNull()
        }

        fun parseNextOffset(rangeHeader: String?, totalBytes: Long): Long? {
            if (rangeHeader.isNullOrBlank()) {
                return 0L
            }
            val match =
                Regex("""bytes=(\d+)-(\d+)""", RegexOption.IGNORE_CASE)
                    .find(rangeHeader.trim())
                    ?: return null
            val start = match.groupValues[1].toLongOrNull() ?: return null
            val end = match.groupValues[2].toLongOrNull() ?: return null
            if (start != 0L) {
                return null
            }
            if (end < 0 || end >= totalBytes) {
                return null
            }
            return end + 1
        }

        fun isRateLimit(body: String): Boolean {
            val lower = body.lowercase()
            return lower.contains("ratelimitexceeded") ||
                lower.contains("userratelimitexceeded")
        }

        fun backoffMs(
            attempt: Int,
            response: DriveHttpResponse?,
            random: Random = Random.Default,
        ): Long {
            val retryAfter = response?.headers?.get("retry-after")?.toLongOrNull()
            if (retryAfter != null && retryAfter > 0) {
                return retryAfter * 1000L
            }
            val base = min(60_000L, (1L shl attempt.coerceAtMost(6)) * 1000L)
            val jitter = random.nextLong(0L, 1000L)
            return base + jitter
        }
    }
}
