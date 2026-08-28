package zack20136.com.quill_diary.drive

/**
 * 使用者停止上傳後的本機收尾決策（純邏輯，便於單元測試）。
 *
 * [jobAfterSettle]：傳輸執行緒落定後的 job。
 * [workerSettled]：上傳 worker 是否已退出（以 `uploadWorkerAlive` 為準；
 * `Future.cancel` 後 `isDone` 不代表執行緒已結束）。
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

    fun plan(
        jobAfterSettle: DriveUploadJob?,
        workerSettled: Boolean = true,
    ): LocalAction {
        if (jobAfterSettle != null && jobAfterSettle.isRemoteCommittedPhase()) {
            return LocalAction.RetainCommitted
        }
        if (!workerSettled) {
            return LocalAction.AwaitWorker
        }
        return LocalAction.CleanupLocal
    }
}
