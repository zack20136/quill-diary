package zack20136.com.quill_diary.drive

import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

@RunWith(RobolectricTestRunner::class)
class DriveRemoteFileCleanupTest {
    private lateinit var context: Context
    private lateinit var store: DriveUploadJobStore

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        val field = DriveUploadJobStore::class.java.getDeclaredField("instance")
        field.isAccessible = true
        field.set(null, null)
        store = DriveUploadJobStore.get(context)
    }

    @Test
    fun 非法fileId不發請求() {
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
    fun 合法fileId會送DELETE() {
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
    fun 取消清理_GET_404且worker已退出則刪本機() {
        val job = createCancelCleanupJob(remoteFileId = "gone-id")
        val client =
            ScriptedHttpClient { request ->
                if (request.method == "GET" && request.url.contains("/files/gone-id")) {
                    DriveResumableUploader.HttpResponse(404, emptyMap(), "")
                } else if (request.method == "GET" && request.url.contains("/files?")) {
                    DriveResumableUploader.HttpResponse(200, emptyMap(), """{"files":[]}""")
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
    }

    @Test
    fun 取消清理_GET_404但worker仍活著則保留pending() {
        val job = createCancelCleanupJob(remoteFileId = "maybe-id")
        val client =
            ScriptedHttpClient { request ->
                if (request.method == "GET" && request.url.contains("/files/maybe-id")) {
                    DriveResumableUploader.HttpResponse(404, emptyMap(), "")
                } else if (request.method == "GET" && request.url.contains("/files?")) {
                    DriveResumableUploader.HttpResponse(200, emptyMap(), """{"files":[]}""")
                } else {
                    throw IOException("unexpected ${request.method} ${request.url}")
                }
            }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = store,
                accessToken = "token",
                job = job,
                workerAlive = true,
                httpClient = client,
            )
        assertEquals(DriveRemoteFileCleanup.CancelCleanupOutcome.RetryLater, outcome)
        assertNotNull(store.readJob(job.jobId))
        assertEquals(DriveUploadPhase.CANCEL_CLEANUP_PENDING, store.readJob(job.jobId)!!.phase)
    }

    @Test
    fun 取消清理_未驗證檔會DELETE後清本機() {
        val job = createCancelCleanupJob(remoteFileId = "partial-id", md5 = "aabb")
        val metadata =
            """{"id":"partial-id","size":"2","md5Checksum":"","appProperties":{"uploadJobId":"${job.jobId}"}}"""
        val deletes = AtomicInteger(0)
        val client =
            ScriptedHttpClient { request ->
                if (request.method == "DELETE") {
                    deletes.incrementAndGet()
                    DriveResumableUploader.HttpResponse(204, emptyMap(), "")
                } else {
                    DriveResumableUploader.HttpResponse(200, emptyMap(), metadata)
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
    fun 取消清理_驗證通過則升STATUS_PENDING() {
        val job = createCancelCleanupJob(remoteFileId = "done-id", md5 = "ccddee", size = 3)
        val metadata =
            """{"id":"done-id","size":"3","md5Checksum":"ccddee","appProperties":{"uploadJobId":"${job.jobId}"}}"""
        val client =
            ScriptedHttpClient { _ ->
                DriveResumableUploader.HttpResponse(200, emptyMap(), metadata)
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
    fun 取消清理_5xx則RetryLater() {
        val job = createCancelCleanupJob(remoteFileId = "busy-id")
        val client =
            ScriptedHttpClient { _ ->
                DriveResumableUploader.HttpResponse(503, emptyMap(), "")
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
        onRequest: (DriveResumableUploader.HttpRequest) -> Unit = {},
    ): DriveResumableUploader.HttpClient =
        object : DriveResumableUploader.HttpClient {
            override fun execute(
                request: DriveResumableUploader.HttpRequest,
            ): DriveResumableUploader.HttpResponse {
                calls.incrementAndGet()
                onRequest(request)
                return DriveResumableUploader.HttpResponse(204, emptyMap(), "")
            }
        }

    private class ScriptedHttpClient(
        private val handler: (DriveResumableUploader.HttpRequest) -> DriveResumableUploader.HttpResponse,
    ) : DriveResumableUploader.HttpClient {
        override fun execute(
            request: DriveResumableUploader.HttpRequest,
        ): DriveResumableUploader.HttpResponse = handler(request)
    }
}
