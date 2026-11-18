package zack20136.com.quill_diary.drive

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File

@RunWith(RobolectricTestRunner::class)
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
    fun 沒有Range時從零開始() {
        assertEquals(0L, DriveResumableUploader.parseNextOffset(null, 1000L))
        assertEquals(0L, DriveResumableUploader.parseNextOffset("", 1000L))
    }

    @Test
    fun 有效Range回傳下一個位元組() {
        assertEquals(
            8L * 1024L * 1024L,
            DriveResumableUploader.parseNextOffset("bytes=0-8388607", 20L * 1024L * 1024L),
        )
    }

    @Test
    fun 超出範圍的Range會拒絕() {
        assertNull(DriveResumableUploader.parseNextOffset("bytes=0-999", 500L))
        assertNull(DriveResumableUploader.parseNextOffset("bytes=abc-def", 500L))
    }

    @Test
    fun 非零起點的Range會拒絕() {
        assertNull(DriveResumableUploader.parseNextOffset("bytes=100-199", 1000L))
    }

    @Test
    fun 不同Drive帳戶無法接手備份上傳() {
        val provider = DriveAccessTokenProvider(RuntimeEnvironment.getApplication())
        val job = sampleJob()
        val otherAccount = DriveAccessTokenProvider.TokenResult("token", "other-id", job.accountEmail)

        assertEquals(DriveAccessTokenProvider.TokenError.Permanent, provider.matchTokenToJob(job, otherAccount))
        val historicalJob = job.copy(accountId = "")
        assertNull(provider.matchTokenToJob(historicalJob, otherAccount.copy(accountEmail = "A@B.C")))
        assertEquals(
            DriveAccessTokenProvider.TokenError.Permanent,
            provider.matchTokenToJob(historicalJob, otherAccount.copy(accountEmail = "other@example.com")),
        )
    }

    @Test
    fun 上傳Location必須是HTTPSGoogleAPI() {
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
    fun 可辨識常見限流回應() {
        assertTrue(
            DriveResumableUploader.isRateLimit(
                """{"error":{"errors":[{"reason":"rateLimitExceeded"}]}}""",
            ),
        )
        assertFalse(DriveResumableUploader.isRateLimit("""{"error":"forbidden"}"""))
    }

    @Test
    fun 遠端識別碼大小與校驗皆符合才視為完成() {
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
    fun 缺少遠端校驗值時不能視為完成() {
        val md5 = "098f6bcd4621d373cade4e832627b4f6"
        val job = sampleJob(md5 = md5, sizeBytes = 42)
        val body =
            """
            {"id":"file-1","size":"42","appProperties":{"uploadJobId":"${job.jobId}","md5":"$md5"}}
            """.trimIndent()
        assertNull(DriveResumableUploader.verifyCompletion(job, body))
    }

    @Test
    fun 重試遵循伺服器等待時間且有上限() {
        val withRetry =
            DriveHttpResponse(
                code = 429,
                headers = mapOf("retry-after" to "7"),
                body = "",
            )
        assertEquals(7000L, DriveResumableUploader.backoffMs(1, withRetry))
        val capped = DriveResumableUploader.backoffMs(20, null)
        assertTrue(capped in 60_000L..61_000L)
    }

    @Test
    fun 只有成功收尾階段視為遠端已提交() {
        val job = sampleJob().copy(phase = DriveUploadPhase.STATUS_PENDING)
        assertTrue(job.isRemoteCommittedPhase())
        assertTrue(job.copy(phase = DriveUploadPhase.PRUNE_PENDING).isRemoteCommittedPhase())
        assertFalse(
            sampleJob().copy(phase = DriveUploadPhase.UPLOADING).isRemoteCommittedPhase(),
        )
    }

    @Test
    fun 進度百分比無條件捨去且只有完整上傳顯示100() {
        assertEquals(0, sampleJob(sizeBytes = 1000).copy(confirmedOffset = 0).progressPercent())
        assertEquals(29, sampleJob(sizeBytes = 100).copy(confirmedOffset = 29).progressPercent())
        assertEquals(12, sampleJob(sizeBytes = 1000).copy(confirmedOffset = 129).progressPercent())
        assertEquals(99, sampleJob(sizeBytes = 1000).copy(confirmedOffset = 999).progressPercent())
        assertEquals(100, sampleJob(sizeBytes = 1000).copy(confirmedOffset = 1000).progressPercent())
        assertEquals(100, sampleJob(sizeBytes = 1000).copy(confirmedOffset = 1200).progressPercent())
        assertEquals(0, sampleJob(sizeBytes = 1000).copy(confirmedOffset = -1).progressPercent())
        assertEquals(0, sampleJob(sizeBytes = 0).copy(confirmedOffset = 1).progressPercent())
    }

    @Test
    fun 工作欄位的JSON空值會解析為空值() {
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
                    "nextRetryAtEpochMs" to org.json.JSONObject.NULL,
                ),
            )
        assertNull(job!!.lastErrorCode)
        assertNull(job.nextRetryAtEpochMs)
    }

    @Test
    fun 舊工作原始錯誤文字不會出現在輸出() {
        val oldMap = sampleJob().toMap() + ("lastErrorMessage" to "HTTP 503: /private/backup.zip")
        val job = requireNotNull(DriveUploadJob.fromMap(oldMap))

        assertEquals(oldMap["jobId"], job.jobId)
        assertTrue(job.toMap().containsKey("lastErrorMessage"))
        assertNull(job.toMap()["lastErrorMessage"])
    }

    @Test
    fun 舊工作可讀取原校驗值與重試次數() {
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
    fun 工作識別碼與檔名安全檢查() {
        assertTrue(
            DriveUploadJobStore.isValidJobId("11111111-1111-1111-1111-111111111111"),
        )
        assertFalse(DriveUploadJobStore.isValidJobId("../etc/passwd"))
        assertEquals("backup.zip", DriveUploadJobStore.sanitizeFileName("backup.zip"))
        assertNull(DriveUploadJobStore.sanitizeFileName(".."))
    }

    @Test
    fun 實際備份的MD5可核對遠端檔案() {
        val file = File.createTempFile("drive_md5", ".bin")
        try {
            file.writeBytes(byteArrayOf(1, 2, 3, 4, 5))
            val md5 = DriveUploadJobStore.md5Hex(file)
            assertEquals("7cfdd07889b3295d6a550914ab35e068", md5)
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
