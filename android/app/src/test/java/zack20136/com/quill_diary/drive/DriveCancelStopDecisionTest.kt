package zack20136.com.quill_diary.drive

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import zack20136.com.quill_diary.drive.DriveCancelStopDecision.LocalAction

class DriveCancelStopDecisionTest {
    private fun job(
        phase: DriveUploadPhase,
        remoteFileId: String = "",
    ): DriveUploadJob =
        DriveUploadJob(
            jobId = "11111111-1111-1111-1111-111111111111",
            phase = phase,
            accountId = "acc",
            accountEmail = "a@example.com",
            stagingPath = "/tmp/s.zip",
            fileName = "backup.zip",
            sizeBytes = 10L,
            remoteFileId = remoteFileId,
        )

    @Test
    fun 落定後已遠端提交則保留且不刪檔() {
        val plan =
            DriveCancelStopDecision.plan(
                snapshotBeforeStop = job(DriveUploadPhase.UPLOADING, remoteFileId = "file-1"),
                jobAfterSettle = job(DriveUploadPhase.STATUS_PENDING, remoteFileId = "file-1"),
            )
        assertEquals(LocalAction.RetainCommitted, plan.localAction)
        assertNull(plan.remoteFileIdToDelete)
    }

    @Test
    fun 落定後仍上傳中則清本機並刪快照遠端檔() {
        val uploading = job(DriveUploadPhase.UPLOADING, remoteFileId = "file-2")
        val plan = DriveCancelStopDecision.plan(uploading, uploading)
        assertEquals(LocalAction.CleanupLocal, plan.localAction)
        assertEquals("file-2", plan.remoteFileIdToDelete)
    }

    @Test
    fun 落定後job已消失則依快照刪遠端殘檔() {
        val plan =
            DriveCancelStopDecision.plan(
                snapshotBeforeStop = job(DriveUploadPhase.UPLOADING, remoteFileId = "orphan"),
                jobAfterSettle = null,
            )
        assertEquals(LocalAction.CleanupLocal, plan.localAction)
        assertEquals("orphan", plan.remoteFileIdToDelete)
    }

    @Test
    fun 無遠端檔id時只清本機() {
        val staged = job(DriveUploadPhase.STAGED)
        val plan = DriveCancelStopDecision.plan(staged, staged)
        assertEquals(LocalAction.CleanupLocal, plan.localAction)
        assertNull(plan.remoteFileIdToDelete)
    }

    @Test
    fun PRUNE_PENDING也視為已完成() {
        val plan =
            DriveCancelStopDecision.plan(
                snapshotBeforeStop = null,
                jobAfterSettle = job(DriveUploadPhase.PRUNE_PENDING, remoteFileId = "file-3"),
            )
        assertEquals(LocalAction.RetainCommitted, plan.localAction)
        assertNull(plan.remoteFileIdToDelete)
    }
}
