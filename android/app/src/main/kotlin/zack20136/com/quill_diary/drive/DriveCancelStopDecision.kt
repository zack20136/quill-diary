package zack20136.com.quill_diary.drive

/**
 * 使用者停止上傳後的本機／遠端收尾決策（純邏輯，便於單元測試）。
 *
 * [snapshotBeforeStop]：呼叫停止當下的 job 快照。
 * [jobAfterSettle]：傳輸執行緒落定後的 job。
 * [workerSettled]：上傳 Future 是否已結束（含逾時後仍卡住＝false）。
 */
object DriveCancelStopDecision {
    enum class LocalAction {
        /** 遠端已驗證完成，保留 STATUS_PENDING／PRUNE_PENDING 給 App 收尾。 */
        RetainCommitted,

        /** worker 已退出且未遠端提交：查詢／刪遠端殘檔後清本機。 */
        CleanupLocal,

        /** worker 尚未退出：保留 CANCEL_CLEANUP_PENDING，等 finally／冷啟動再清。 */
        AwaitWorker,
    }

    data class Plan(
        val localAction: LocalAction,
        /** CleanupLocal 時可帶入已知 remoteFileId；查無檔時仍可依 jobId list。 */
        val remoteFileIdToDelete: String?,
    )

    fun plan(
        snapshotBeforeStop: DriveUploadJob?,
        jobAfterSettle: DriveUploadJob?,
        workerSettled: Boolean = true,
    ): Plan {
        if (jobAfterSettle != null && jobAfterSettle.isRemoteCommittedPhase()) {
            return Plan(LocalAction.RetainCommitted, remoteFileIdToDelete = null)
        }
        if (!workerSettled) {
            return Plan(LocalAction.AwaitWorker, remoteFileIdToDelete = null)
        }
        return Plan(
            localAction = LocalAction.CleanupLocal,
            remoteFileIdToDelete = firstNonBlankRemoteId(jobAfterSettle, snapshotBeforeStop),
        )
    }

    private fun firstNonBlankRemoteId(vararg jobs: DriveUploadJob?): String? =
        jobs.asSequence()
            .mapNotNull { job -> job?.remoteFileId?.takeIf { it.isNotBlank() } }
            .firstOrNull()
}
