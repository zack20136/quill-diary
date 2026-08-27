package zack20136.com.quill_diary.drive

import android.content.Context
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
    fun 惡意_jobId_不得讀寫() {
        assertNull(store.readJob("../etc/passwd"))
        assertNull(store.readJob("not-a-uuid"))
        assertNull(store.cancelAndCleanup("../evil"))
        assertNull(store.failAndCleanup("../evil", "x", "y"))
    }

    @Test
    fun 無衝突時可建立工作且_generation_從_1_開始() {
        val staging = stagingFile("ok.zip", byteArrayOf(1, 2, 3))
        val created = store.createJobIfNoConflict(newJob(staging))
        assertNotNull(created)
        assertEquals(1L, created!!.generation)
        assertEquals(DriveUploadPhase.STAGED, created.phase)
        assertTrue(created.md5.isNotBlank())
    }

    @Test
    fun 已有_active_時拒絕第二個工作() {
        val a = stagingFile("a.zip", byteArrayOf(1))
        val b = stagingFile("b.zip", byteArrayOf(2))
        assertNotNull(store.createJobIfNoConflict(newJob(a)))
        assertNull(store.createJobIfNoConflict(newJob(b)))
    }

    @Test
    fun generation_不符時_CAS_拒絕() {
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
    fun 刪除後不得以舊_generation_復活() {
        val staging = stagingFile("gone.zip", byteArrayOf(3))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        store.failAndCleanup(created.jobId, "test", "gone")
        assertNull(
            store.updateJobCas(
                created.copy(phase = DriveUploadPhase.UPLOADING),
                expectedGeneration = created.generation,
            ),
        )
        assertNull(store.readJob(created.jobId))
    }

    @Test
    fun isInsideStagingRoot_拒絕_root_外路徑() {
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
    fun failAndCleanup_清除工作並寫入_failure_notice() {
        val staging = stagingFile("fail.zip", byteArrayOf(4, 5))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val failed =
            store.failAndCleanup(
                created.jobId,
                "abandoned",
                "上次 Google Drive 備份未完成，已取消。",
            )
        assertNotNull(failed)
        assertNull(store.readJob(created.jobId))
        assertFalse(File(created.stagingPath).exists())
        val notice = store.readFailureNotice()
        assertNotNull(notice)
        assertEquals(created.jobId, notice!!.jobId)
        assertEquals("上次 Google Drive 備份未完成，已取消。", notice.message)
        // 讀取不清除
        assertNotNull(store.readFailureNotice())
    }

    @Test
    fun ackFailure_才清除_failure_notice() {
        val staging = stagingFile("ack.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        store.failAndCleanup(created.jobId, "x", "msg")
        assertFalse(store.ackFailure("wrong-id"))
        assertTrue(store.ackFailure(created.jobId))
        assertNull(store.readFailureNotice())
    }

    @Test
    fun cancelAndCleanup_刪除_staging_與工作() {
        val staging = stagingFile("cancel.zip", byteArrayOf(4, 5))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val cancelled = store.cancelAndCleanup(created.jobId)
        assertNotNull(cancelled)
        assertNull(store.readJob(created.jobId))
        assertFalse(File(created.stagingPath).exists())
    }

    @Test
    fun cancelAndCleanup_拒絕_STATUS_PENDING() {
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
    fun cancelAndCleanup_拒絕_PRUNE_PENDING() {
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
    fun markStatusRecorded_僅_STATUS_PENDING_可轉_PRUNE_PENDING() {
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
    fun finalizeCommitted_僅_PRUNE_PENDING_可完成() {
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
    fun abandonUncommittedIfPresent_清理未提交工作() {
        val staging = stagingFile("abandon.zip", byteArrayOf(9))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val abandoned =
            store.abandonUncommittedIfPresent("程序中斷，已取消。")
        assertNotNull(abandoned)
        assertEquals(created.jobId, abandoned!!.jobId)
        assertNull(store.readActiveJob())
        assertFalse(File(created.stagingPath).exists())
        assertNotNull(store.readFailureNotice())
    }

    @Test
    fun abandonUncommittedIfPresent_保留_STATUS_PENDING() {
        val staging = stagingFile("keep.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        store.updateJobCas(
            created.copy(phase = DriveUploadPhase.STATUS_PENDING, remoteFileId = "r"),
            expectedGeneration = created.generation,
        )
        assertNull(store.abandonUncommittedIfPresent("不應清理。"))
        assertNotNull(store.readActiveJob())
        assertTrue(File(created.stagingPath).exists())
    }

    @Test
    fun getStateEnvelope_回傳_job_與_failure() {
        val staging = stagingFile("env.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val active = store.getStateEnvelope()
        assertNotNull(active["job"])
        assertNull(active["failure"])
        store.failAndCleanup(created.jobId, "x", "fail msg")
        val withFailure = store.getStateEnvelope()
        assertNull(withFailure["job"])
        assertNotNull(withFailure["failure"])
    }

    @Test
    fun cleanupOrphanStaging_清除無引用檔案() {
        val staging = stagingFile("orphan.zip", byteArrayOf(9, 9))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        store.failAndCleanup(created.jobId, "x", "y")
        val orphan = stagingFile("lonely.zip", byteArrayOf(1))
        assertTrue(orphan.exists())
        store.cleanupOrphanStaging()
        assertFalse(orphan.exists())
    }

    @Test
    fun sessionUri_加密往返() {
        val staging = stagingFile("sess.zip", byteArrayOf(1))
        val created = store.createJobIfNoConflict(newJob(staging))!!
        val uri = "https://www.googleapis.com/upload/drive/v3/files?upload_id=abc"
        store.writeSessionUri(created.jobId, uri)
        assertEquals(uri, store.readSessionUri(created.jobId))
        store.clearSessionUri(created.jobId)
        assertNull(store.readSessionUri(created.jobId))
    }

    @Test
    fun md5Hex_對小檔可重複() {
        val file = File.createTempFile("drive_md5", ".bin")
        try {
            file.writeBytes(byteArrayOf(1, 2, 3, 4, 5))
            val first = DriveUploadJobStore.md5Hex(file)
            val second = DriveUploadJobStore.md5Hex(file)
            assertEquals(first, second)
            assertEquals(32, first.length)
        } finally {
            file.delete()
        }
    }
}
