package zack20136.com.quill_diary.drive

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class DriveResumableUploaderTest {
    private fun sampleJob(
        jobId: String = "11111111-1111-1111-1111-111111111111",
        sizeBytes: Long = 10,
        md5: String = "d41d8cd98f00b204e9800998ecf8427e",
        remoteFileId: String = "file-1",
    ): DriveUploadJob =
        DriveUploadJob(
            jobId = jobId,
            phase = DriveUploadPhase.UPLOADING,
            accountId = "acc",
            accountEmail = "a@b.c",
            stagingPath = "/tmp/x.zip",
            fileName = "x.zip",
            sizeBytes = sizeBytes,
            md5 = md5,
            remoteFileId = remoteFileId,
        )

    @Test
    fun 沒有_Range_時從零開始() {
        assertEquals(0L, DriveResumableUploader.parseNextOffset(null, 1000L))
        assertEquals(0L, DriveResumableUploader.parseNextOffset("", 1000L))
    }

    @Test
    fun 有效_Range_回傳下一個位元組() {
        assertEquals(
            8L * 1024L * 1024L,
            DriveResumableUploader.parseNextOffset("bytes=0-8388607", 20L * 1024L * 1024L),
        )
    }

    @Test
    fun 超出範圍的_Range_會拒絕() {
        assertNull(DriveResumableUploader.parseNextOffset("bytes=0-999", 500L))
        assertNull(DriveResumableUploader.parseNextOffset("bytes=abc-def", 500L))
    }

    @Test
    fun 非零起點的_Range_會拒絕() {
        assertNull(DriveResumableUploader.parseNextOffset("bytes=100-199", 1000L))
    }

    @Test
    fun 上傳_Location_必須是_HTTPS_Google_API() {
        assertTrue(
            DriveResumableUploader.isAllowedUploadLocation(
                "https://www.googleapis.com/upload/drive/v3/files?upload_id=abc",
            ),
        )
        assertTrue(
            DriveResumableUploader.isAllowedUploadLocation(
                "https://upload.googleapis.com/upload/drive/v3/files?upload_id=abc",
            ),
        )
        assertFalse(
            DriveResumableUploader.isAllowedUploadLocation(
                "http://www.googleapis.com/upload/drive/v3/files?upload_id=abc",
            ),
        )
        assertFalse(
            DriveResumableUploader.isAllowedUploadLocation(
                "https://evil.example/upload/drive/v3/files",
            ),
        )
    }

    @Test
    fun 可辨識常見_rate_limit_回應() {
        assertTrue(
            DriveResumableUploader.isRateLimit(
                """{"error":{"errors":[{"reason":"rateLimitExceeded"}]}}""",
            ),
        )
        assertFalse(DriveResumableUploader.isRateLimit("""{"error":"forbidden"}"""))
    }

    @Test
    fun verifyCompletion_驗證_id_大小_jobId_與_md5() {
        val md5 = "098f6bcd4621d373cade4e832627b4f6"
        val job =
            sampleJob(
                md5 = md5,
                sizeBytes = 42,
            )
        val okBody =
            """
            {"id":"file-1","size":"42","md5Checksum":"$md5","appProperties":{"uploadJobId":"${job.jobId}","md5":"$md5"}}
            """.trimIndent()
        assertNotNull(DriveResumableUploader.verifyCompletion(job, okBody))

        assertNull(DriveResumableUploader.verifyCompletion(job, ""))
        assertNull(
            DriveResumableUploader.verifyCompletion(
                job,
                """{"id":"other","size":"42","md5Checksum":"$md5","appProperties":{"uploadJobId":"${job.jobId}","md5":"$md5"}}""",
            ),
        )
        assertNull(
            DriveResumableUploader.verifyCompletion(
                job,
                """{"id":"file-1","size":"41","md5Checksum":"$md5","appProperties":{"uploadJobId":"${job.jobId}","md5":"$md5"}}""",
            ),
        )
        assertNull(
            DriveResumableUploader.verifyCompletion(
                job,
                """{"id":"file-1","size":"42","md5Checksum":"$md5","appProperties":{"uploadJobId":"wrong","md5":"$md5"}}""",
            ),
        )
        assertNull(
            DriveResumableUploader.verifyCompletion(
                job,
                """{"id":"file-1","size":"42","md5Checksum":"00000000000000000000000000000000","appProperties":{"uploadJobId":"${job.jobId}","md5":"$md5"}}""",
            ),
        )
        assertNull(
            DriveResumableUploader.verifyCompletion(
                job,
                """{"id":"file-1","size":"42","appProperties":{"uploadJobId":"${job.jobId}","md5":"$md5"}}""",
            ),
        )
    }

    @Test
    fun verifyCompletion_缺_md5Checksum_回傳_null_供查_metadata() {
        val md5 = "098f6bcd4621d373cade4e832627b4f6"
        val job = sampleJob(md5 = md5, sizeBytes = 42)
        val body =
            """
            {"id":"file-1","size":"42","appProperties":{"uploadJobId":"${job.jobId}","md5":"$md5"}}
            """.trimIndent()
        assertNull(DriveResumableUploader.verifyCompletion(job, body))
    }

    @Test
    fun backoff_尊重_Retry_After_並有上限() {
        val withRetry =
            DriveResumableUploader.HttpResponse(
                code = 429,
                headers = mapOf("retry-after" to "7"),
                body = "",
            )
        assertEquals(7000L, DriveResumableUploader.backoffMs(1, withRetry))
        val capped = DriveResumableUploader.backoffMs(20, null)
        assertTrue(capped in 60_000L..61_000L)
    }

    @Test
    fun DriveUploadJob_isRemoteCommittedPhase() {
        val job = sampleJob().copy(phase = DriveUploadPhase.STATUS_PENDING)
        assertTrue(job.isRemoteCommittedPhase())
        assertTrue(job.blocksConflictingActions())
        assertFalse(
            sampleJob().copy(phase = DriveUploadPhase.UPLOADING).isRemoteCommittedPhase(),
        )
    }

    @Test
    fun fromMap_把_JSONObject_NULL_當成_null() {
        val job =
            DriveUploadJob.fromMap(
                mapOf(
                    "jobId" to "11111111-1111-1111-1111-111111111111",
                    "phase" to "UPLOADING",
                    "accountId" to "a",
                    "accountEmail" to "a@b.c",
                    "stagingPath" to "/tmp/x",
                    "fileName" to "x.zip",
                    "sizeBytes" to 10,
                    "md5" to "abc",
                    "remoteFileId" to "f",
                    "lastErrorCode" to org.json.JSONObject.NULL,
                    "lastErrorMessage" to org.json.JSONObject.NULL,
                    "nextRetryAtEpochMs" to org.json.JSONObject.NULL,
                ),
            )
        assertNull(job!!.lastErrorCode)
        assertNull(job.lastErrorMessage)
        assertNull(job.nextRetryAtEpochMs)
    }

    @Test
    fun fromMap_相容舊_sha256_與_attemptCount() {
        val job =
            DriveUploadJob.fromMap(
                mapOf(
                    "jobId" to "11111111-1111-1111-1111-111111111111",
                    "phase" to "UPLOADING",
                    "accountId" to "a",
                    "accountEmail" to "a@b.c",
                    "stagingPath" to "/tmp/x",
                    "fileName" to "x.zip",
                    "sizeBytes" to 10,
                    "sha256" to "legacy-md5-value",
                    "attemptCount" to 3,
                ),
            )
        assertEquals("legacy-md5-value", job!!.md5)
        assertEquals(3, job.retryCount)
    }

    @Test
    fun SCHEMA_VERSION_維持為_1() {
        assertEquals(1, DriveUploadJob.SCHEMA_VERSION)
    }

    @Test
    fun jobId_與檔名安全檢查() {
        assertTrue(
            DriveUploadJobStore.isValidJobId("11111111-1111-1111-1111-111111111111"),
        )
        assertFalse(DriveUploadJobStore.isValidJobId("../etc/passwd"))
        assertEquals("backup.zip", DriveUploadJobStore.sanitizeFileName("backup.zip"))
        assertNull(DriveUploadJobStore.sanitizeFileName(".."))
    }

    @Test
    fun md5Hex_對實際檔案可驗證() {
        val file = File.createTempFile("drive_md5", ".bin")
        try {
            file.writeBytes(byteArrayOf(1, 2, 3, 4, 5))
            val md5 = DriveUploadJobStore.md5Hex(file)
            assertEquals(32, md5.length)
            val job = sampleJob(md5 = md5, sizeBytes = 5).copy(stagingPath = file.absolutePath)
            val body =
                """
                {"id":"file-1","size":"5","md5Checksum":"$md5","appProperties":{"uploadJobId":"${job.jobId}","md5":"$md5"}}
                """.trimIndent()
            assertNotNull(DriveResumableUploader.verifyCompletion(job, body))
        } finally {
            file.delete()
        }
    }
}
