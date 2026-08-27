package zack20136.com.quill_diary.drive

/**
 * 使用者停止上傳後的本機／遠端收尾決策（純邏輯，便於單元測試）。
 *
 * [snapshotBeforeStop]：呼叫停止當下的 job 快照。
 * [jobAfterSettle]：傳輸執行緒落定後的 job。
 */
object DriveCancelStopDecision {
    enum class LocalAction {
        /** 遠端已驗證完成，保留 STATUS_PENDING／PRUNE_PENDING 給 App 收尾。 */
        RetainCommitted,

        /** 未遠端提交：清除本機 job／staging。 */
        CleanupLocal,
    }

    data class Plan(
        val localAction: LocalAction,
        /** 非空時應對該 Drive 檔做 best-effort DELETE。 */
        val remoteFileIdToDelete: String?,
    )

    fun plan(
        snapshotBeforeStop: DriveUploadJob?,
        jobAfterSettle: DriveUploadJob?,
    ): Plan {
        if (jobAfterSettle != null && jobAfterSettle.isRemoteCommittedPhase()) {
            return Plan(LocalAction.RetainCommitted, remoteFileIdToDelete = null)
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
