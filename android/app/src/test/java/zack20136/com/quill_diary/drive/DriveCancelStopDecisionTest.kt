package zack20136.com.quill_diary.drive

import org.junit.Assert.assertEquals
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
    fun 落定後已遠端提交則RetainCommitted() {
        assertEquals(
            LocalAction.RetainCommitted,
            DriveCancelStopDecision.plan(
                jobAfterSettle = job(DriveUploadPhase.STATUS_PENDING, remoteFileId = "file-1"),
            ),
        )
    }

    @Test
    fun PRUNE_PENDING也視為已完成() {
        assertEquals(
            LocalAction.RetainCommitted,
            DriveCancelStopDecision.plan(
                jobAfterSettle = job(DriveUploadPhase.PRUNE_PENDING, remoteFileId = "file-3"),
            ),
        )
    }

    @Test
    fun 落定後未遠端提交則CleanupLocal() {
        assertEquals(
            LocalAction.CleanupLocal,
            DriveCancelStopDecision.plan(
                jobAfterSettle = job(DriveUploadPhase.UPLOADING, remoteFileId = "file-2"),
            ),
        )
        assertEquals(
            LocalAction.CleanupLocal,
            DriveCancelStopDecision.plan(jobAfterSettle = null),
        )
        assertEquals(
            LocalAction.CleanupLocal,
            DriveCancelStopDecision.plan(
                jobAfterSettle = job(DriveUploadPhase.CANCEL_CLEANUP_PENDING),
            ),
        )
    }

    @Test
    fun worker尚未退出則AwaitWorker() {
        assertEquals(
            LocalAction.AwaitWorker,
            DriveCancelStopDecision.plan(
                jobAfterSettle = job(DriveUploadPhase.CANCEL_CLEANUP_PENDING),
                workerSettled = false,
            ),
        )
    }

    @Test
    fun worker尚未退出但已遠端提交仍RetainCommitted() {
        assertEquals(
            LocalAction.RetainCommitted,
            DriveCancelStopDecision.plan(
                jobAfterSettle = job(DriveUploadPhase.STATUS_PENDING, remoteFileId = "file-5"),
                workerSettled = false,
            ),
        )
    }
}
