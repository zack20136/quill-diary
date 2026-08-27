package zack20136.com.quill_diary.drive

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.min
import kotlin.random.Random

/**
 * Google Drive resumable upload（raw HTTP）。
 * chunk 固定 8 MiB，非最後一塊必須為 256 KiB 倍數。
 */
class DriveResumableUploader(
    private val jobStore: DriveUploadJobStore,
    private val tokenProvider: DriveAccessTokenProvider,
    private val httpClient: HttpClient = DefaultHttpClient(),
) {
    interface HttpClient {
        fun execute(request: HttpRequest): HttpResponse

        fun disconnectActive() {}
    }

    sealed class HttpBody {
        data class Bytes(val data: ByteArray) : HttpBody()

        data class FileRange(
            val file: File,
            val offset: Long,
            val length: Int,
        ) : HttpBody()
    }

    data class HttpRequest(
        val method: String,
        val url: String,
        val headers: Map<String, String>,
        val body: HttpBody? = null,
    )

    data class HttpResponse(
        val code: Int,
        val headers: Map<String, String>,
        val body: String,
    )

    class DefaultHttpClient : HttpClient {
        private val activeConnection = AtomicReference<HttpURLConnection?>(null)

        override fun execute(request: HttpRequest): HttpResponse {
            val connection = (URL(request.url).openConnection() as HttpURLConnection)
            activeConnection.set(connection)
            try {
                connection.requestMethod = request.method
                connection.connectTimeout = 30_000
                connection.readTimeout = 120_000
                connection.instanceFollowRedirects = false
                connection.doInput = true
                request.headers.forEach { (key, value) ->
                    connection.setRequestProperty(key, value)
                }
                when (val body = request.body) {
                    is HttpBody.Bytes -> {
                        connection.doOutput = true
                        connection.setFixedLengthStreamingMode(body.data.size)
                        connection.outputStream.use { output ->
                            output.write(body.data)
                            output.flush()
                        }
                    }
                    is HttpBody.FileRange -> {
                        connection.doOutput = true
                        connection.setFixedLengthStreamingMode(body.length)
                        RandomAccessFile(body.file, "r").use { raf ->
                            raf.seek(body.offset)
                            val buffer = ByteArray(STREAM_BUFFER_SIZE)
                            var remaining = body.length
                            connection.outputStream.use { output ->
                                while (remaining > 0) {
                                    val toRead = min(buffer.size, remaining)
                                    val n = raf.read(buffer, 0, toRead)
                                    if (n < 0) {
                                        throw IOException("無法讀取備份檔區塊。")
                                    }
                                    output.write(buffer, 0, n)
                                    remaining -= n
                                }
                                output.flush()
                            }
                        }
                    }
                    null -> Unit
                }
                val code = connection.responseCode
                val stream =
                    if (code in 200..299 || code == 308) {
                        connection.inputStream
                    } else {
                        connection.errorStream ?: connection.inputStream
                    }
                val responseBody = readLimitedBody(stream)
                val headers = mutableMapOf<String, String>()
                connection.headerFields?.forEach { (key, values) ->
                    if (key != null && !values.isNullOrEmpty()) {
                        headers[key.lowercase()] = values.last()
                    }
                }
                return HttpResponse(code = code, headers = headers, body = responseBody)
            } finally {
                connection.disconnect()
                activeConnection.compareAndSet(connection, null)
            }
        }

        override fun disconnectActive() {
            activeConnection.getAndSet(null)?.disconnect()
        }

        private fun readLimitedBody(stream: InputStream?): String {
            if (stream == null) {
                return ""
            }
            return stream.bufferedReader(StandardCharsets.UTF_8).use { reader ->
                val builder = StringBuilder()
                val buffer = CharArray(8 * 1024)
                var total = 0
                while (true) {
                    val n = reader.read(buffer)
                    if (n < 0) {
                        break
                    }
                    val room = MAX_RESPONSE_BODY_BYTES - total
                    if (room <= 0) {
                        break
                    }
                    val write = min(n, room)
                    builder.append(buffer, 0, write)
                    total += write
                    if (write < n) {
                        break
                    }
                }
                builder.toString()
            }
        }
    }

    private val userCancel = AtomicBoolean(false)

    /** 使用者取消：標記後斷線；run() 回傳 Cancelled，由 Service 清理。 */
    fun cancelUser() {
        userCancel.set(true)
        abortTransport()
    }

    /** 只斷開進行中的 HTTP，不改業務狀態。 */
    fun abortTransport() {
        httpClient.disconnectActive()
    }

    fun isCancelled(): Boolean = userCancel.get()

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
                message = "上傳重試次數過多，Google Drive 備份已取消。",
            )
        }

        when (val verified = ensureStaging(job, onUpdate)) {
            is StagingResult.Failed -> return verified.outcome
            is StagingResult.Ready -> job = verified.job
        }

        val accountError = tokenProvider.ensureAccountMatches(job)
        if (accountError != null) {
            return handleTokenError(job, accountError, onUpdate)
        }

        if (job.remoteFileId.isBlank()) {
            when (val idOutcome = allocateRemoteFileId(job, onUpdate)) {
                is AllocateIdResult.Success -> job = idOutcome.job
                is AllocateIdResult.Outcome -> return idOutcome.outcome
            }
        }

        when (val existing = lookupCommittedFile(job, onUpdate)) {
            is DriveUploadOutcome -> return existing
            else -> Unit
        }

        val initialTokenResult = tokenProvider.getAccessToken()
        if (initialTokenResult.isFailure) {
            val error =
                (initialTokenResult.exceptionOrNull() as? DriveAccessTokenProvider.TokenException)
                    ?.error
                    ?: DriveAccessTokenProvider.TokenError.Transient("無法取得授權。")
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
        var chunksSincePersist = 0
        var lastProgressPersistAtMs = System.currentTimeMillis()

        job =
            persistOrAbort(
                job.copy(
                    phase = DriveUploadPhase.UPLOADING,
                    lastErrorCode = null,
                    lastErrorMessage = null,
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
                        HttpRequest(
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
                                HttpBody.FileRange(
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
                            lastErrorMessage = "等待網路連線後繼續上傳。",
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
                            message = "上傳完成回應與預期檔案不符。",
                        )
                    }
                    return commitPending(completed, onUpdate)
                }
                308 -> {
                    val nextOffset = parseNextOffset(response.headers["range"], job.sizeBytes)
                    if (nextOffset == null) {
                        return DriveUploadOutcome.Failed(
                            code = "invalid_range",
                            message = "伺服器回傳的上傳進度無效。",
                        )
                    }
                    tokenRefreshedForChunk = false
                    val progressed =
                        job.copy(
                            confirmedOffset = nextOffset,
                            phase = DriveUploadPhase.UPLOADING,
                        )
                    chunksSincePersist += 1
                    val now = System.currentTimeMillis()
                    val shouldPersist =
                        chunksSincePersist >= PROGRESS_PERSIST_EVERY_CHUNKS ||
                            (now - lastProgressPersistAtMs >= PROGRESS_PERSIST_INTERVAL_MS)
                    if (shouldPersist) {
                        job =
                            persistOrAbort(
                                progressed,
                                onUpdate,
                                durability = DriveUploadJobStore.Durability.Progress,
                            ) ?: return DriveUploadOutcome.Cancelled
                        chunksSincePersist = 0
                        lastProgressPersistAtMs = now
                    } else {
                        job = progressed
                        onUpdate(job)
                    }
                }
                401 -> {
                    if (tokenRefreshedForChunk) {
                        return handleTokenError(
                            job,
                            DriveAccessTokenProvider.TokenError.NeedsUserInteraction(null),
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
                            message = "上傳工作階段失效，Google Drive 備份已取消。",
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
                                    chunksSincePersist = 0
                                    lastProgressPersistAtMs = System.currentTimeMillis()
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
                                lastErrorMessage = "上傳暫時失敗，稍後會自動重試。",
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
                                    lastErrorMessage = "上傳請求過於頻繁，稍後重試。",
                                    nextRetryAtEpochMs =
                                        System.currentTimeMillis() +
                                            backoffMs(job.retryCount + 1, response),
                                ),
                            onUpdate = onUpdate,
                        )
                    }
                    return DriveUploadOutcome.Failed(
                        code = "forbidden",
                        message = "Google Drive 權限不足，請重新連結後再備份。",
                    )
                }
                else -> {
                    return DriveUploadOutcome.Failed(
                        code = "http_${response.code}",
                        message = "上傳失敗（HTTP ${response.code}）。",
                    )
                }
            }
        }

        return when (val existing = lookupCommittedFile(job, onUpdate)) {
            is DriveUploadOutcome -> existing
            else ->
                DriveUploadOutcome.Failed(
                    code = "incomplete",
                    message = "上傳未完成，請重試。",
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
                    message = "本機暫存備份已遺失或內容不一致，請重新建立備份。",
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
                        ?: DriveAccessTokenProvider.TokenError.Transient("無法取得授權。")
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
                        HttpRequest(
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
                                lastErrorMessage = "暫時無法配置遠端檔案 ID。",
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
                                message = "Google Drive 未回傳檔案 ID。",
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
                                DriveAccessTokenProvider.TokenError.NeedsUserInteraction(null),
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
                                    lastErrorMessage = "上傳請求過於頻繁，稍後重試。",
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
                            DriveAccessTokenProvider.TokenError.NeedsUserInteraction(null),
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
                                lastErrorMessage = "暫時無法配置遠端檔案 ID。",
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
                            message = "無法配置遠端檔案 ID（HTTP ${response.code}）。",
                        ),
                    )
                }
                else -> {
                    return AllocateIdResult.Outcome(
                        waitingForNetwork(
                            job.copy(
                                retryCount = job.retryCount + 1,
                                lastErrorCode = "http_${response.code}",
                                lastErrorMessage = "暫時無法配置遠端檔案 ID。",
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
        // 遠端內容已驗證通過：即使使用者剛按停止，仍必須寫入 STATUS_PENDING，
        // 否則 finishUserStop 會把已完成的 Drive 檔當殘檔刪掉。
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
                    HttpRequest(
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
                        body = HttpBody.Bytes(metadata),
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
                            lastErrorMessage = "等待網路連線後繼續上傳。",
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
                            message = "無法建立 Google Drive 上傳工作階段。",
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
                            DriveAccessTokenProvider.TokenError.NeedsUserInteraction(null),
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
                                message = "Google Drive 檔案衝突，請重新建立備份。",
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
                        message = "無法建立上傳工作階段（HTTP ${response.code}）。",
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
                    HttpRequest(
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
                            lastErrorMessage = "等待網路連線後繼續上傳。",
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
                            message = "上傳完成回應與預期檔案不符。",
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
                            message = "伺服器回傳的上傳進度無效。",
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
                            DriveAccessTokenProvider.TokenError.NeedsUserInteraction(null),
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
                            message = "上傳工作階段失效，Google Drive 備份已取消。",
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
                        message = "無法查詢上傳進度（HTTP ${response.code}）。",
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
                httpClient.execute(
                    HttpRequest(
                        method = "GET",
                        url =
                            "https://www.googleapis.com/drive/v3/files/${job.remoteFileId}" +
                                "?fields=id,name,size,md5Checksum,appProperties",
                        headers = mapOf("Authorization" to "Bearer $accessToken"),
                    ),
                )
            } catch (_: IOException) {
                return null
            }
        if (byId.code == 200) {
            val verified = verifyCompletionWithMetadata(job, byId.body, accessToken)
            if (verified != null) {
                return commitPending(verified, onUpdate)
            }
        }

        val query =
            "appProperties has { key='uploadJobId' and value='${job.jobId}' } and trashed = false"
        val listed =
            try {
                httpClient.execute(
                    HttpRequest(
                        method = "GET",
                        url =
                            "https://www.googleapis.com/drive/v3/files" +
                                "?spaces=appDataFolder" +
                                "&q=${java.net.URLEncoder.encode(query, "UTF-8")}" +
                                "&fields=files(id,name,size,md5Checksum,appProperties)",
                        headers = mapOf("Authorization" to "Bearer $accessToken"),
                    ),
                )
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
                    message = "Google Drive 檔案衝突，請重新建立備份。",
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
                    HttpRequest(
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
                    lastErrorMessage = job.lastErrorMessage ?: "等待網路連線後繼續上傳。",
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
            is DriveAccessTokenProvider.TokenError.NeedsUserInteraction,
            is DriveAccessTokenProvider.TokenError.NotSignedIn,
            -> {
                DriveUploadOutcome.Failed(
                    code = "authorization",
                    message = "Google Drive 授權已失效，請重新連結後再備份。",
                )
            }
            is DriveAccessTokenProvider.TokenError.Permanent -> {
                DriveUploadOutcome.Failed(
                    code = "authorization",
                    message = error.message,
                )
            }
            is DriveAccessTokenProvider.TokenError.Transient ->
                waitingForNetwork(
                    job.copy(
                        lastErrorCode = "token_transient",
                        lastErrorMessage = error.message,
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
                    ?: DriveAccessTokenProvider.TokenError.NeedsUserInteraction(null)
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

        private const val MAX_RESPONSE_BODY_BYTES = 512 * 1024
        private const val STREAM_BUFFER_SIZE = 64 * 1024
        private const val PROGRESS_PERSIST_EVERY_CHUNKS = 4
        private const val PROGRESS_PERSIST_INTERVAL_MS = 30_000L

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
            response: HttpResponse?,
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
