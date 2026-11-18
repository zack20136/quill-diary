package zack20136.com.quill_diary.drive

import org.junit.Assert.assertEquals
import org.junit.Test

class DriveUploadStopActionTest {
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
    fun 工作執行緒退出後已遠端提交則保留工作() {
        assertEquals(
            DriveUploadStopAction.KeepCommitted,
            resolveUploadStopAction(
                currentJob = job(DriveUploadPhase.STATUS_PENDING, remoteFileId = "file-1"),
            ),
        )
    }

    @Test
    fun 待清理也視為已完成() {
        assertEquals(
            DriveUploadStopAction.KeepCommitted,
            resolveUploadStopAction(
                currentJob = job(DriveUploadPhase.PRUNE_PENDING, remoteFileId = "file-3"),
            ),
        )
    }

    @Test
    fun 工作執行緒退出後未提交則先查核遠端再清理() {
        assertEquals(
            DriveUploadStopAction.ReconcileRemote,
            resolveUploadStopAction(
                currentJob = job(DriveUploadPhase.UPLOADING, remoteFileId = "file-2"),
            ),
        )
        assertEquals(
            DriveUploadStopAction.ReconcileRemote,
            resolveUploadStopAction(currentJob = null),
        )
        assertEquals(
            DriveUploadStopAction.ReconcileRemote,
            resolveUploadStopAction(
                currentJob = job(DriveUploadPhase.CANCEL_CLEANUP_PENDING),
            ),
        )
    }

    @Test
    fun 工作執行緒尚未退出時等待其結束() {
        assertEquals(
            DriveUploadStopAction.WaitForWorker,
            resolveUploadStopAction(
                currentJob = job(DriveUploadPhase.CANCEL_CLEANUP_PENDING),
                workerExited = false,
            ),
        )
    }

    @Test
    fun 工作執行緒尚未退出但已提交時仍保留工作() {
        assertEquals(
            DriveUploadStopAction.KeepCommitted,
            resolveUploadStopAction(
                currentJob = job(DriveUploadPhase.STATUS_PENDING, remoteFileId = "file-5"),
                workerExited = false,
            ),
        )
    }
}
