package zack20136.com.quill_diary.drive

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

@RunWith(RobolectricTestRunner::class)
class DriveRemoteFileCleanupTest {
    private lateinit var store: DriveUploadJobStore

    @Before
    fun setUp() {
        store = freshDriveUploadJobStore()
    }

    @Test
    fun 非法檔案識別碼不發請求() {
        val calls = AtomicInteger(0)
        val client = recordingClient(calls)
        assertEquals(
            DriveRemoteFileCleanup.DeleteOutcome.Cleared,
            DriveRemoteFileCleanup.bestEffortDelete(
                remoteFileId = "../evil",
                accessToken = "token",
                httpClient = client,
            ),
        )
        assertEquals(
            DriveRemoteFileCleanup.DeleteOutcome.Cleared,
            DriveRemoteFileCleanup.bestEffortDelete(
                remoteFileId = "",
                accessToken = "token",
                httpClient = client,
            ),
        )
        assertEquals(
            DriveRemoteFileCleanup.DeleteOutcome.Cleared,
            DriveRemoteFileCleanup.bestEffortDelete(
                remoteFileId = "ok-id",
                accessToken = "",
                httpClient = client,
            ),
        )
        assertEquals(0, calls.get())
    }

    @Test
    fun 合法檔案識別碼會送刪除請求() {
        val calls = AtomicInteger(0)
        var method = ""
        var url = ""
        val client =
            recordingClient(calls) { request ->
                method = request.method
                url = request.url
            }
        assertEquals(
            DriveRemoteFileCleanup.DeleteOutcome.Cleared,
            DriveRemoteFileCleanup.bestEffortDelete(
                remoteFileId = "abc-123_XYZ",
                accessToken = "token",
                httpClient = client,
            ),
        )
        assertEquals(1, calls.get())
        assertEquals("DELETE", method)
        assertTrue(url.endsWith("/files/abc-123_XYZ"))
    }

    @Test
    fun 遠端無檔且上傳已停止則清除本機工作() {
        val job = createCancelCleanupJob(remoteFileId = "gone-id")
        val client =
            DriveHttpClient { request ->
                if (request.method == "GET" && request.url.contains("/files/gone-id")) {
                    DriveHttpResponse(404, emptyMap(), "")
                } else if (request.method == "GET" && request.url.contains("/files?")) {
                    DriveHttpResponse(200, emptyMap(), """{"files":[]}""")
                } else {
                    throw IOException("unexpected ${request.method} ${request.url}")
                }
            }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = job,
                workerAlive = false,
                httpClient = client,
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.ClearedLocal, outcome)
        assertNull(store.readJob(job.jobId))
        assertNull(store.readFailureNotice())
    }

    @Test
    fun 清除未提交的遺留工作時不寫入失敗提示() {
        val staging = File(store.stagingRoot(), "${UUID.randomUUID()}.zip")
        staging.writeBytes(ByteArray(2) { 1 })
        val leftover =
            store.createJobIfNoConflict(
                DriveUploadJob(
                    jobId = UUID.randomUUID().toString(),
                    phase = DriveUploadPhase.UPLOADING,
                    accountId = "acc",
                    accountEmail = "a@b.c",
                    stagingPath = staging.canonicalPath,
                    fileName = staging.name,
                    sizeBytes = 2L,
                    md5 = "deadbeef",
                    remoteFileId = "stale-id",
                ),
            )!!
        val client =
            DriveHttpClient { request ->
                if (request.method == "GET" && request.url.contains("/files/stale-id")) {
                    DriveHttpResponse(404, emptyMap(), "")
                } else if (request.method == "GET" && request.url.contains("/files?")) {
                    DriveHttpResponse(200, emptyMap(), """{"files":[]}""")
                } else {
                    throw IOException("unexpected ${request.method} ${request.url}")
                }
            }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = leftover,
                workerAlive = false,
                httpClient = client,
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.ClearedLocal, outcome)
        assertNull(store.readJob(leftover.jobId))
        assertNull(store.readFailureNotice())
        assertFalse(staging.exists())
    }

    @Test
    fun 上傳尚未停止時保留本機工作並延後查核遠端() {
        val job = createCancelCleanupJob(remoteFileId = "maybe-id")
        val calls = AtomicInteger(0)
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = job,
                workerAlive = true,
                httpClient = recordingClient(calls),
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.RetryLater, outcome)
        assertEquals(0, calls.get())
        assertNotNull(store.readJob(job.jobId))
        assertEquals(DriveUploadPhase.CANCEL_CLEANUP_PENDING, store.readJob(job.jobId)!!.phase)
    }

    @Test
    fun 刪除未驗證的遠端檔案後才清除本機工作() {
        val job = createCancelCleanupJob(remoteFileId = "partial-id", md5 = "aabb")
        val metadata =
            """{"id":"partial-id","size":"1","md5Checksum":"","appProperties":{"uploadJobId":"${job.jobId}"}}"""
        val deletes = AtomicInteger(0)
        val client =
            DriveHttpClient { request ->
                if (request.method == "DELETE") {
                    deletes.incrementAndGet()
                    DriveHttpResponse(204, emptyMap(), "")
                } else {
                    DriveHttpResponse(200, emptyMap(), metadata)
                }
            }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = job,
                workerAlive = false,
                httpClient = client,
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.ClearedLocal, outcome)
        assertEquals(1, deletes.get())
        assertNull(store.readJob(job.jobId))
    }

    @Test
    fun 確認遠端已完成後保留工作供成功收尾() {
        val job = createCancelCleanupJob(remoteFileId = "done-id", md5 = "ccddee", size = 3)
        val metadata =
            """{"id":"done-id","size":"3","md5Checksum":"ccddee","appProperties":{"uploadJobId":"${job.jobId}"}}"""
        val client =
            DriveHttpClient { _ ->
                DriveHttpResponse(200, emptyMap(), metadata)
            }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = job,
                workerAlive = false,
                httpClient = client,
            )
        val retained =
            outcome as DriveRemoteFileCleanup.CancelCleanupOutcome.RetainedCommitted
        assertEquals(DriveUploadPhase.STATUS_PENDING, retained.job.phase)
        assertEquals(DriveUploadPhase.STATUS_PENDING, store.readJob(job.jobId)!!.phase)
    }

    @Test
    fun 伺服器暫時失敗時保留工作供重試() {
        val job = createCancelCleanupJob(remoteFileId = "busy-id")
        val client =
            DriveHttpClient { _ ->
                DriveHttpResponse(503, emptyMap(), "")
            }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = job,
                workerAlive = false,
                httpClient = client,
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.RetryLater, outcome)
        assertNotNull(store.readJob(job.jobId))
    }

    @Test
    fun 保留已完成的備份並重試清除其他殘檔() {
        val job = createCancelCleanupJob(remoteFileId = "", md5 = "ccddee", size = 3)
        val verifiedBody =
            """{"id":"done-id","size":"3","md5Checksum":"ccddee","appProperties":{"uploadJobId":"${job.jobId}"}}"""
        val junkBody =
            """{"id":"junk-id","size":"1","md5Checksum":"","appProperties":{"uploadJobId":"${job.jobId}"}}"""
        val client =
            DriveHttpClient { request ->
                when {
                    request.method == "GET" && request.url.contains("/files?") ->
                        DriveHttpResponse(
                            200,
                            emptyMap(),
                            """{"files":[$verifiedBody,$junkBody]}""",
                        )
                    request.method == "DELETE" && request.url.endsWith("/files/junk-id") ->
                        DriveHttpResponse(503, emptyMap(), "")
                    else ->
                        throw IOException("unexpected ${request.method} ${request.url}")
                }
            }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = job,
                workerAlive = false,
                httpClient = client,
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.RetryLater, outcome)
        assertNotNull(store.readJob(job.jobId))
        assertEquals(DriveUploadPhase.CANCEL_CLEANUP_PENDING, store.readJob(job.jobId)!!.phase)
    }

    @Test
    fun 缺少權杖時記錄重新授權需求() {
        val job = createCancelCleanupJob(remoteFileId = "any-id")
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "   ",
                job = job,
                workerAlive = false,
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.NeedsReauth, outcome)
        val pending = store.readJob(job.jobId)
        assertNotNull(pending)
        assertEquals(
            DriveRemoteFileCleanup.ERROR_CLEANUP_NEEDS_REAUTH,
            pending!!.lastErrorCode,
        )
    }

    @Test
    fun 查詢遠端時授權失效會要求重連() {
        val job = createCancelCleanupJob(remoteFileId = "auth-id")
        val client =
            DriveHttpClient { request ->
                if (request.method == "GET" && request.url.contains("/files/auth-id")) {
                    DriveHttpResponse(401, emptyMap(), "")
                } else {
                    throw IOException("unexpected ${request.method} ${request.url}")
                }
            }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = job,
                workerAlive = false,
                httpClient = client,
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.NeedsReauth, outcome)
        val pending = store.readJob(job.jobId)
        assertNotNull(pending)
        assertEquals(
            DriveRemoteFileCleanup.ERROR_CLEANUP_NEEDS_REAUTH,
            pending!!.lastErrorCode,
        )
    }

    @Test
    fun 刪除殘檔時授權失效會保留工作待重連() {
        val job = createCancelCleanupJob(remoteFileId = "partial-id", md5 = "aabb")
        val metadata =
            """{"id":"partial-id","size":"1","md5Checksum":"","appProperties":{"uploadJobId":"${job.jobId}"}}"""
        val client =
            DriveHttpClient { request ->
                if (request.method == "DELETE") {
                    DriveHttpResponse(401, emptyMap(), "")
                } else {
                    DriveHttpResponse(200, emptyMap(), metadata)
                }
            }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = job,
                workerAlive = false,
                httpClient = client,
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.NeedsReauth, outcome)
        assertNotNull(store.readJob(job.jobId))
        assertEquals(
            DriveRemoteFileCleanup.ERROR_CLEANUP_NEEDS_REAUTH,
            store.readJob(job.jobId)!!.lastErrorCode,
        )
    }

    @Test
    fun 放棄清理無存取權杖仍清本機工作() {
        val job = createCancelCleanupJob(remoteFileId = "leftover-id")
        DriveRemoteFileCleanup.abandonCancelCleanup(
            jobStore = store,
            job = job,
            accessToken = null,
        )
        assertNull(store.readJob(job.jobId))
        assertNull(store.readFailureNotice())
    }

    @Test
    fun 放棄清理時會先驗證再刪除不完整遠端檔() {
        val job = createCancelCleanupJob(remoteFileId = "leftover-id")
        val deletes = AtomicInteger(0)
        val client =
            DriveHttpClient { request ->
                if (request.method == "DELETE") {
                    deletes.incrementAndGet()
                    DriveHttpResponse(204, emptyMap(), "")
                } else if (request.method == "GET" && request.url.contains("/files/leftover-id")) {
                    DriveHttpResponse(200, emptyMap(), """{"id":"leftover-id","size":"1","appProperties":{"uploadJobId":"${job.jobId}"}}""")
                } else {
                    throw IOException("unexpected ${request.method} ${request.url}")
                }
            }
        DriveRemoteFileCleanup.abandonCancelCleanup(
            jobStore = store,
            job = job,
            accessToken = "token",
            httpClient = client,
        )
        assertEquals(1, deletes.get())
        assertNull(store.readJob(job.jobId))
    }

    @Test
    fun 放棄清理時保留已驗證的遠端備份() {
        val job = createCancelCleanupJob(remoteFileId = "verified-id")
        val client = DriveHttpClient { request ->
            assertEquals("GET", request.method)
            DriveHttpResponse(
                200,
                emptyMap(),
                """{"id":"verified-id","size":"${job.sizeBytes}","md5Checksum":"${job.md5}","appProperties":{"uploadJobId":"${job.jobId}"}}""",
            )
        }

        DriveRemoteFileCleanup.abandonCancelCleanup(
            jobStore = store,
            job = job,
            accessToken = "token",
            httpClient = client,
        )

        assertEquals(DriveUploadPhase.STATUS_PENDING, store.readJob(job.jobId)?.phase)
    }

    @Test
    fun 舊遠端識別碼查無檔時仍可驗證工作清單中的備份() {
        val job = createCancelCleanupJob(remoteFileId = "old-id")
        val client = DriveHttpClient { request ->
            assertEquals("GET", request.method)
            if (request.url.contains("/files/old-id")) {
                DriveHttpResponse(404, emptyMap(), "")
            } else {
                val entry = """{"id":"current-id","size":"${job.sizeBytes}","md5Checksum":"${job.md5}","appProperties":{"uploadJobId":"${job.jobId}"}}"""
                DriveHttpResponse(200, emptyMap(), """{"files":[$entry]}""")
            }
        }
        val outcome = DriveRemoteFileCleanup.completeCancelCleanup(
            jobStore = store,
            accessToken = "token",
            job = job,
            workerAlive = false,
            httpClient = client,
        )

        assertTrue(outcome is DriveRemoteFileCleanup.CancelCleanupOutcome.RetainedCommitted)
        assertEquals("current-id", store.readJob(job.jobId)?.remoteFileId)
    }

    @Test
    fun 遠端回應缺少工作識別碼時保留待清理工作() {
        val job = createCancelCleanupJob(remoteFileId = "unknown-id")
        val client = DriveHttpClient { request ->
            assertEquals("GET", request.method)
            DriveHttpResponse(200, emptyMap(), """{"id":"unknown-id","size":"1"}""")
        }

        val outcome = DriveRemoteFileCleanup.completeCancelCleanup(
            jobStore = store,
            accessToken = "token",
            job = job,
            workerAlive = false,
            httpClient = client,
        )

        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.RetryLater, outcome)
        assertEquals(DriveUploadPhase.CANCEL_CLEANUP_PENDING, store.readJob(job.jobId)?.phase)
    }

    private fun createCancelCleanupJob(
        remoteFileId: String,
        md5: String = "deadbeef",
        size: Long = 2L,
    ): DriveUploadJob {
        val staging = File(store.stagingRoot(), "${UUID.randomUUID()}.zip")
        staging.writeBytes(ByteArray(size.toInt()) { 1 })
        val created =
            store.createJobIfNoConflict(
                DriveUploadJob(
                    jobId = UUID.randomUUID().toString(),
                    phase = DriveUploadPhase.UPLOADING,
                    accountId = "acc",
                    accountEmail = "a@b.c",
                    stagingPath = staging.canonicalPath,
                    fileName = staging.name,
                    sizeBytes = size,
                    md5 = md5,
                    remoteFileId = remoteFileId,
                ),
            )!!
        return store.markCancelCleanupPending(created.jobId)!!
    }

    private fun recordingClient(
        calls: AtomicInteger,
        onRequest: (DriveHttpRequest) -> Unit = {},
    ): DriveHttpClient = DriveHttpClient { request ->
        calls.incrementAndGet()
        onRequest(request)
        DriveHttpResponse(204, emptyMap(), "")
    }
}
