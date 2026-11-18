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
import org.robolectric.RuntimeEnvironment
import java.io.File
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
class DriveUploadJobStoreTest {
    private lateinit var store: DriveUploadJobStore

    @Before
    fun setUp() {
        store = freshDriveUploadJobStore()
    }

    private fun stagingFile(name: String, bytes: ByteArray): File {
        val root = store.stagingRoot()
        val file = File(root, name)
        file.writeBytes(bytes)
        return file.canonicalFile
    }

    private fun newJob(staging: File, size: Long = staging.length()): DriveUploadJob {
        val md5 = DriveUploadJobStore.md5Hex(staging)
        return DriveUploadJob(
            jobId = UUID.randomUUID().toString(),
            phase = DriveUploadPhase.STAGED,
            accountId = "acc",
            accountEmail = "a@b.c",
            stagingPath = staging.path,
            fileName = staging.name,
            sizeBytes = size,
            md5 = md5,
        )
    }

    @Test
    fun 備份世代持久化後重新讀取仍綁定原工作() {
        val staging = stagingFile("identity.zip", byteArrayOf(1, 2, 3))
        val identity = mapOf("vault_id" to "vault", "kdf_fingerprint" to "a".repeat(64))
        val created = store.createJobIfNoConflict(newJob(staging).copy(backupIdentity = identity, backupPurpose = "normal"))!!
        val read = store.readJob(created.jobId)!!
        assertEquals(identity, read.backupIdentity)
        assertEquals("normal", read.backupPurpose)
        assertEquals(created.generation, read.generation)
    }

    @Test
    fun 惡意工作識別碼不得讀寫() {
        assertNull(store.readJob("../etc/passwd"))
        assertNull(store.readJob("not-a-uuid"))
        assertNull(store.cancelAndCleanup("../evil"))
        assertNull(store.recordUploadFailure("../evil", "x", "y"))
    }

    @Test
    fun 沒有進行中的工作時可建立新工作() {
        val staging = stagingFile("ok.zip", byteArrayOf(1, 2, 3))
        val created = store.createJobIfNoConflict(newJob(staging))
        assertNotNull(created)
        assertEquals(1L, created!!.generation)
        assertEquals(DriveUploadPhase.STAGED, created.phase)
        assertTrue(created.md5.isNotBlank())
    }

    @Test
    fun 有進行中的工作時拒絕另建工作() {
        val a = stagingFile("a.zip", byteArrayOf(1))
        val b = stagingFile("b.zip", byteArrayOf(2))
        assertNotNull(store.createJobIfNoConflict(newJob(a)))
        assertNull(store.createJobIfNoConflict(newJob(b)))
    }

    @Test
    fun 拒絕寫入過期的工作版本() {
        val staging = stagingFile("cas.zip", byteArrayOf(9))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val updated =
            store.updateJobCas(
                created.copy(phase = DriveUploadPhase.UPLOADING),
                expectedGeneration = created.generation,
            )
        assertNotNull(updated)
        assertEquals(2L, updated!!.generation)
        assertNull(
            store.updateJobCas(
                updated.copy(confirmedOffset = 1),
                expectedGeneration = created.generation,
            ),
        )
    }

    @Test
    fun 舊版本無法復原已刪除的工作() {
        val staging = stagingFile("gone.zip", byteArrayOf(3))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        store.recordUploadFailure(created.jobId, "test", "gone")
        assertNull(
            store.updateJobCas(
                created.copy(phase = DriveUploadPhase.UPLOADING),
                expectedGeneration = created.generation,
            ),
        )
        assertNull(store.readJob(created.jobId))
    }

    @Test
    fun 拒絕暫存根目錄以外的路徑() {
        val outside = File.createTempFile("outside", ".bin")
        outside.writeBytes(byteArrayOf(7, 7, 7))
        try {
            assertFalse(store.isInsideStagingRoot(outside.absolutePath))
            val staging = stagingFile("inside.zip", byteArrayOf(1))
            assertTrue(store.isInsideStagingRoot(staging.path))
        } finally {
            outside.delete()
        }
    }

    @Test
    fun 失敗時清除工作並保留提示() {
        val staging = stagingFile("fail.zip", byteArrayOf(4, 5))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val failed =
            store.recordUploadFailure(
                created.jobId,
                "abandoned",
                "上次備份未完成，請重新備份。",
            )
        assertNotNull(failed)
        assertNull(store.readJob(created.jobId))
        assertFalse(File(created.stagingPath).exists())
        val notice = store.readFailureNotice()
        assertNotNull(notice)
        assertEquals(created.jobId, notice!!.jobId)
        assertEquals("上次備份未完成，請重新備份。", notice.message)
        // 讀取不清除
        assertNotNull(store.readFailureNotice())
    }

    @Test
    fun 確認對應工作後才清除失敗提示() {
        val staging = stagingFile("ack.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        store.recordUploadFailure(created.jobId, "x", "msg")
        assertFalse(store.ackFailure("wrong-id"))
        assertTrue(store.ackFailure(created.jobId))
        assertNull(store.readFailureNotice())
    }

    @Test
    fun 取消清理刪除備份暫存與工作() {
        val staging = stagingFile("cancel.zip", byteArrayOf(4, 5))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val cancelled = store.cancelAndCleanup(created.jobId)
        assertNotNull(cancelled)
        assertNull(store.readJob(created.jobId))
        assertFalse(File(created.stagingPath).exists())
    }

    @Test
    fun 取消不會刪除等待記錄成功的工作() {
        val staging = stagingFile("comm.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val committed =
            store.updateJobCas(
                created.copy(
                    phase = DriveUploadPhase.STATUS_PENDING,
                    remoteFileId = "remote",
                ),
                expectedGeneration = created.generation,
            )!!
        assertNull(store.cancelAndCleanup(committed.jobId))
        assertNotNull(store.readJob(committed.jobId))
        assertTrue(File(committed.stagingPath).exists())
    }

    @Test
    fun 取消不會刪除等待清理舊備份的工作() {
        val staging = stagingFile("prune.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val pending =
            store.updateJobCas(
                created.copy(phase = DriveUploadPhase.STATUS_PENDING, remoteFileId = "r"),
                expectedGeneration = created.generation,
            )!!
        val prune =
            store.markStatusRecorded(pending.jobId)!!
        assertNull(store.cancelAndCleanup(prune.jobId))
        assertNotNull(store.readJob(prune.jobId))
    }

    @Test
    fun 記錄成功後可進入清理舊備份階段() {
        val staging = stagingFile("status.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        assertNull(store.markStatusRecorded(created.jobId))
        val pending =
            store.updateJobCas(
                created.copy(phase = DriveUploadPhase.STATUS_PENDING, remoteFileId = "r"),
                expectedGeneration = created.generation,
            )!!
        val prune = store.markStatusRecorded(pending.jobId)
        assertNotNull(prune)
        assertEquals(DriveUploadPhase.PRUNE_PENDING, prune!!.phase)
    }

    @Test
    fun 清理舊備份階段才允許完成收尾() {
        val staging = stagingFile("fin.zip", byteArrayOf(1, 2))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        assertNull(store.finalizeCommitted(created.jobId))
        val pending =
            store.updateJobCas(
                created.copy(phase = DriveUploadPhase.STATUS_PENDING, remoteFileId = "r"),
                expectedGeneration = created.generation,
            )!!
        assertNull(store.finalizeCommitted(pending.jobId))
        val prune = store.markStatusRecorded(pending.jobId)!!
        val finalized = store.finalizeCommitted(prune.jobId)
        assertNotNull(finalized)
        assertNull(store.readJob(prune.jobId))
        assertFalse(File(prune.stagingPath).exists())
    }

    @Test
    fun 失敗不會刪除等待取消清理的工作() {
        val staging = stagingFile("keep-cancel.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        store.markCancelCleanupPending(created.jobId)
        assertNull(store.recordUploadFailure(created.jobId, "x", "y"))
        assertEquals(
            DriveUploadPhase.CANCEL_CLEANUP_PENDING,
            store.readActiveJob()!!.phase,
        )
        assertNull(store.readFailureNotice())
    }

    @Test
    fun 只有未提交的工作可標記取消清理() {
        val staging = stagingFile("cancel-pending.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val pending = store.markCancelCleanupPending(created.jobId)
        assertNotNull(pending)
        assertEquals(DriveUploadPhase.CANCEL_CLEANUP_PENDING, pending!!.phase)
        assertEquals(pending.jobId, store.markCancelCleanupPending(pending.jobId)!!.jobId)
        store.cancelAndCleanup(pending.jobId)

        val committedStaging = stagingFile("cancel-committed.zip", byteArrayOf(2))
        val created2 = store.createJobIfNoConflict(newJob(committedStaging))!!
        val committed =
            store.updateJobCas(
                created2.copy(phase = DriveUploadPhase.STATUS_PENDING, remoteFileId = "r"),
                expectedGeneration = created2.generation,
            )!!
        assertNull(store.markCancelCleanupPending(committed.jobId))
        assertEquals(DriveUploadPhase.STATUS_PENDING, store.readJob(committed.jobId)!!.phase)
    }

    @Test
    fun 已標記取消的工作可完成本機清理() {
        val staging = stagingFile("cancel-ok.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val pending = store.markCancelCleanupPending(created.jobId)!!
        val cancelled = store.cancelAndCleanup(pending.jobId)
        assertNotNull(cancelled)
        assertNull(store.readJob(pending.jobId))
        assertFalse(File(pending.stagingPath).exists())
    }

    @Test
    fun 取消清理中只允許更新錯誤或提交已驗證結果() {
        val staging = stagingFile("cas-cancel.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val pending = store.markCancelCleanupPending(created.jobId)!!
        assertNull(
            store.updateJobCas(
                pending.copy(phase = DriveUploadPhase.UPLOADING, confirmedOffset = 1),
                expectedGeneration = pending.generation,
            ),
        )
        assertNull(
            store.updateJobCas(
                pending.copy(confirmedOffset = 1),
                expectedGeneration = pending.generation,
            ),
        )
        val withError = store.updateJobCas(
            pending.copy(lastErrorCode = "cleanup_needs_reauth"),
            expectedGeneration = pending.generation,
        )!!
        assertEquals("cleanup_needs_reauth", store.readJob(pending.jobId)!!.lastErrorCode)
        val committed =
            store.updateJobCas(
                withError.copy(
                    phase = DriveUploadPhase.STATUS_PENDING,
                    remoteFileId = "r",
                    confirmedOffset = pending.sizeBytes,
                ),
                expectedGeneration = withError.generation,
            )
        assertNotNull(committed)
        assertEquals(DriveUploadPhase.STATUS_PENDING, committed!!.phase)
    }

    @Test
    fun 連續寫入進度會保留最新確認位置() {
        val staging = stagingFile("progress.zip", ByteArray(100))
        val created = store.createJobIfNoConflict(newJob(staging, size = 100))!!
        val first =
            store.updateJobCas(
                created.copy(phase = DriveUploadPhase.UPLOADING, confirmedOffset = 25),
                expectedGeneration = created.generation,
                durability = DriveUploadJobStore.Durability.Progress,
            )!!
        val second =
            store.updateJobCas(
                first.copy(confirmedOffset = 50),
                expectedGeneration = first.generation,
                durability = DriveUploadJobStore.Durability.Progress,
            )!!

        val persisted = store.readJob(created.jobId)!!
        assertEquals(created.jobId, persisted.jobId)
        assertEquals(DriveUploadPhase.UPLOADING, persisted.phase)
        assertEquals(50L, persisted.confirmedOffset)
        assertEquals(second.generation, persisted.generation)
    }

    @Test
    fun 工作狀態同時回傳進行中工作與失敗提示() {
        val staging = stagingFile("env.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val active = store.getStateEnvelope()
        assertNotNull(active["job"])
        assertNull(active["failure"])
        store.recordUploadFailure(created.jobId, "x", "fail msg")
        val withFailure = store.getStateEnvelope()
        assertNull(withFailure["job"])
        assertNotNull(withFailure["failure"])
    }

    @Test
    fun 清除孤兒同時保留有效工作引用的暫存和工作網址() {
        val staging = stagingFile("active.zip", byteArrayOf(1))
        val active = store.createJobIfNoConflict(newJob(staging))!!
        val orphan = stagingFile("orphan.zip.partial", byteArrayOf(2))
        val orphanId = UUID.randomUUID().toString()
        val abandonedJob = File(jobsDirectory(), "$orphanId.json.new").apply {
            writeText("uncommitted")
        }
        val url = "https://www.googleapis.com/upload/drive/v3/files?upload_id=sample"
        store.writeSessionUri(orphanId, url)
        store.writeSessionUri(active.jobId, url)

        store.cleanupAbandonedUploadFiles()

        assertTrue(staging.exists())
        assertFalse(orphan.exists())
        assertFalse(abandonedJob.exists())
        assertNull(store.readSessionUri(orphanId))
        assertEquals(url, store.readSessionUri(active.jobId))
    }

    @Test
    fun 工作紀錄讀不到時保留無法確認用途的暫存() {
        val staging = stagingFile("unknown.zip", byteArrayOf(1))
        File(jobsDirectory(), "${UUID.randomUUID()}.json").writeText("{")

        store.cleanupAbandonedUploadFiles()

        assertTrue(staging.exists())
    }

    @Test
    fun 已有遠端識別碼的失敗工作保留對帳所需資訊() {
        val staging = stagingFile("interrupted.zip", byteArrayOf(1))
        val active = store.createJobIfNoConflict(newJob(staging).copy(remoteFileId = "remote-id"))!!

        val failed = store.recordUploadFailure(active.jobId, "completion_mismatch", "測試失敗")

        assertEquals(DriveUploadPhase.CANCEL_CLEANUP_PENDING, failed?.phase)
        assertEquals("remote-id", store.readJob(active.jobId)?.remoteFileId)
        assertEquals(active.jobId, store.readFailureNotice()?.jobId)
        assertTrue(staging.exists())
    }

    @Test
    fun 上傳工作網址可加密保存並讀回() {
        val staging = stagingFile("sess.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val uri = "https://www.googleapis.com/upload/drive/v3/files?upload_id=abc"
        store.writeSessionUri(created.jobId, uri)
        assertEquals(uri, store.readSessionUri(created.jobId))
        store.clearSessionUri(created.jobId)
        assertNull(store.readSessionUri(created.jobId))
    }

    private fun jobsDirectory(): File =
        File(RuntimeEnvironment.getApplication().filesDir, "quill_diary/drive_upload_jobs")
}
