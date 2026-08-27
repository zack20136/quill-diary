package zack20136.com.quill_diary.drive

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.atomic.AtomicInteger

class DriveRemoteFileCleanupTest {
    @Test
    fun 非法fileId不發請求() {
        val calls = AtomicInteger(0)
        val client = recordingClient(calls)
        DriveRemoteFileCleanup.bestEffortDelete(
            remoteFileId = "../evil",
            accessToken = "token",
            httpClient = client,
        )
        DriveRemoteFileCleanup.bestEffortDelete(
            remoteFileId = "",
            accessToken = "token",
            httpClient = client,
        )
        DriveRemoteFileCleanup.bestEffortDelete(
            remoteFileId = "ok-id",
            accessToken = "",
            httpClient = client,
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
        DriveRemoteFileCleanup.bestEffortDelete(
            remoteFileId = "abc-123_XYZ",
            accessToken = "token",
            httpClient = client,
        )
        assertEquals(1, calls.get())
        assertEquals("DELETE", method)
        assertTrue(url.endsWith("/files/abc-123_XYZ"))
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
}
