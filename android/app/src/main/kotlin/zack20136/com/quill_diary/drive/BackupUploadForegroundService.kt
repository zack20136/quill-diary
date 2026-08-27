package zack20136.com.quill_diary.drive

import android.app.ForegroundServiceStartNotAllowedException
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import zack20136.com.quill_diary.MainActivity
import zack20136.com.quill_diary.R
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.abs

/**
 * dataSync 前景服務：持有 resumable uploader，不依賴 FlutterEngine。
 * 本機狀態刪除委派 JobStore；Service 只管 transport／通知／wake lock／網路重試。
 */
class BackupUploadForegroundService : Service() {
    private val executor = Executors.newSingleThreadExecutor()
    private val scheduler: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var uploadFuture: Future<*>? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var uploader: DriveResumableUploader? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private val stopRequested = AtomicBoolean(false)
    private val terminationGeneration = AtomicLong(0L)
    private var pendingRetry: Future<*>? = null
    private val retryLock = Any()

    private var lastProgressEmitAtMs = 0L
    private var lastEmittedProgressFraction = -1.0
    private var lastEmittedPhase: DriveUploadPhase? = null

    private lateinit var jobStore: DriveUploadJobStore
    private lateinit var tokenProvider: DriveAccessTokenProvider

    override fun onCreate() {
        super.onCreate()
        running = true
        // onCreate 後改以 running 為準，清除 startForegroundService 與 onCreate 之間的保護旗標。
        pendingStartJobId = null
        jobStore = DriveUploadJobStore.get(applicationContext)
        tokenProvider = DriveAccessTokenProvider(applicationContext)
        ensureNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                handleUserStop(startId)
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val jobId = intent.getStringExtra(EXTRA_JOB_ID)
                if (jobId.isNullOrBlank() || stopRequested.get()) {
                    stopSelfSafely(startId)
                    return START_NOT_STICKY
                }
                startUpload(jobId, startId)
            }
            else -> stopSelfSafely(startId)
        }
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        val fence = terminationGeneration.incrementAndGet()
        uploader?.abortTransport()
        val job = jobStore.readActiveJob()
        if (job != null &&
            !job.isRemoteCommittedPhase() &&
            !job.isCancelCleanupPhase()
        ) {
            val failed =
                jobStore.failAndCleanup(
                    job.jobId,
                    errorCode = "fgs_timeout",
                    message = "系統暫停背景上傳，Google Drive 備份已取消。",
                )
            if (failed != null && terminationGeneration.get() == fence) {
                DriveUploadBridge.emitStateEnvelope(applicationContext)
                notifyFailed(failed)
            }
        }
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf(startId)
    }

    override fun onDestroy() {
        running = false
        pendingStartJobId = null
        unregisterNetworkCallback()
        pendingRetry?.cancel(false)
        uploader?.abortTransport()
        uploadFuture?.cancel(true)
        val job = jobStore.readActiveJob()
        if (job != null &&
            !job.isRemoteCommittedPhase() &&
            !job.isCancelCleanupPhase()
        ) {
            jobStore.failAndCleanup(
                job.jobId,
                errorCode = "service_destroyed",
                message = "上次 Google Drive 備份未完成，已取消。請重新備份。",
            )
            DriveUploadBridge.emitStateEnvelope(applicationContext)
        }
        uploadWorkerAlive = false
        releaseWakeLock()
        executor.shutdownNow()
        scheduler.shutdownNow()
        super.onDestroy()
    }

    private fun startUpload(jobId: String, startId: Int) {
        if (stopRequested.get() || uploadFuture?.isDone == false) {
            return
        }
        val fenceAtStart = terminationGeneration.get()
        val job = jobStore.readJob(jobId)
        if (job == null) {
            stopSelfSafely(startId)
            return
        }
        if (job.isRemoteCommittedPhase()) {
            if (job.phase == DriveUploadPhase.STATUS_PENDING) {
                DriveUploadBridge.emitStateEnvelope(applicationContext)
            }
            stopSelfSafely(startId)
            return
        }
        if (job.isCancelCleanupPhase()) {
            uploadWorkerAlive = true
            uploadFuture =
                executor.submit {
                    try {
                        finishCancelCleanupFromWorker(job.jobId, startId)
                    } finally {
                        uploadWorkerAlive = false
                    }
                }
            return
        }

        resetProgressThrottle()

        val notification = buildProgressNotification(job)
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } catch (error: Throwable) {
            markFailedForStartFailure(applicationContext, jobId, error)
            stopSelfSafely(startId)
            return
        }
        acquireWakeLock()
        registerNetworkCallback()

        uploadWorkerAlive = true
        uploadFuture =
            executor.submit {
                val localFence = fenceAtStart
                try {
                    if (stopRequested.get() || terminationGeneration.get() != localFence) {
                        return@submit
                    }
                    val activeUploader = DriveResumableUploader(jobStore, tokenProvider)
                    uploader = activeUploader
                    val currentJob = jobStore.readJob(jobId) ?: return@submit
                    val outcome =
                        activeUploader.run(currentJob) { updated ->
                            if (terminationGeneration.get() != localFence || stopRequested.get()) {
                                return@run
                            }
                            maybeEmitProgress(updated)
                        }
                    if (terminationGeneration.get() != localFence || stopRequested.get()) {
                        return@submit
                    }
                    mainHandler.post { handleOutcome(outcome, localFence, startId) }
                } catch (error: Throwable) {
                    if (terminationGeneration.get() != localFence || stopRequested.get()) {
                        return@submit
                    }
                    mainHandler.post {
                        finishFailure(
                            jobId,
                            startId = startId,
                            errorCode = "unexpected",
                            message = error.message ?: "上傳發生未預期錯誤。",
                        )
                    }
                } finally {
                    uploader = null
                    releaseWakeLock()
                    try {
                        finishCancelCleanupFromWorker(jobId, startId)
                    } finally {
                        uploadWorkerAlive = false
                    }
                }
            }
    }

    private fun handleOutcome(outcome: DriveUploadOutcome, fence: Long, startId: Int) {
        if (terminationGeneration.get() != fence || stopRequested.get()) {
            return
        }
        when (outcome) {
            is DriveUploadOutcome.Committed -> finishCommitted(outcome.job, startId)
            is DriveUploadOutcome.WaitingNetwork -> {
                DriveUploadBridge.emitStateEnvelope(applicationContext)
                updateProgressNotification(outcome.job)
                scheduleMaybeRetry(outcome.job.jobId)
            }
            is DriveUploadOutcome.Failed ->
                finishFailure(
                    jobId = jobStore.readActiveJob()?.jobId ?: "",
                    startId = startId,
                    errorCode = outcome.code,
                    message = outcome.message,
                )
            DriveUploadOutcome.Cancelled -> finishCancellation(startId)
        }
    }

    /** timer 與 network callback 都切到 main thread 再走唯一 maybeRetry。 */
    private fun scheduleMaybeRetry(jobId: String) {
        synchronized(retryLock) {
            pendingRetry?.cancel(false)
            if (stopRequested.get()) {
                return
            }
            val job = jobStore.readJob(jobId) ?: return
            if (job.phase != DriveUploadPhase.WAITING_FOR_NETWORK) {
                return
            }
            val delayMs =
                ((job.nextRetryAtEpochMs ?: System.currentTimeMillis()) - System.currentTimeMillis())
                    .coerceAtLeast(NETWORK_RETRY_DEBOUNCE_MS)
            pendingRetry =
                scheduler.schedule(
                    { mainHandler.post { maybeRetry(jobId) } },
                    delayMs,
                    TimeUnit.MILLISECONDS,
                )
        }
    }

    private fun maybeRetry(jobId: String) {
        if (stopRequested.get() || uploadFuture?.isDone == false) {
            return
        }
        val job = jobStore.readJob(jobId) ?: return
        if (job.phase != DriveUploadPhase.WAITING_FOR_NETWORK) {
            return
        }
        if (job.retryCount >= DriveResumableUploader.MAX_ATTEMPTS) {
            finishFailure(
                jobId = job.jobId,
                startId = null,
                errorCode = "max_attempts",
                message = "上傳重試次數過多，Google Drive 備份已取消。",
            )
            return
        }
        val now = System.currentTimeMillis()
        val nextAt = job.nextRetryAtEpochMs ?: now
        if (now < nextAt) {
            scheduleMaybeRetry(jobId)
            return
        }
        startUpload(jobId, startId = 0)
    }

    /**
     * 使用者停止：先標記 CANCEL_CLEANUP_PENDING、中止 HTTP、等上傳執行緒落定，
     * 再依決策保留成功、立即清理，或留下 pending 等 worker finally。
     * 不在主執行緒阻塞。
     */
    private fun handleUserStop(startId: Int) {
        stopRequested.set(true)
        terminationGeneration.incrementAndGet()
        val snapshot = jobStore.readActiveJob()
        if (snapshot != null && !snapshot.isRemoteCommittedPhase()) {
            jobStore.markCancelCleanupPending(snapshot.jobId)
        }
        pendingRetry?.cancel(false)
        uploader?.cancelUser()
        val futureToAwait = uploadFuture
        scheduler.execute {
            awaitUploadFutureSettled(futureToAwait)
            try {
                finishUserStop(
                    snapshot = snapshot,
                    startId = startId,
                    workerSettled = futureToAwait == null || futureToAwait.isDone,
                )
            } finally {
                completeStopAwaiter()
            }
        }
    }

    private fun awaitUploadFutureSettled(future: Future<*>?) {
        if (future == null) {
            return
        }
        try {
            future.get(UPLOAD_STOP_AWAIT_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        } catch (_: TimeoutException) {
            future.cancel(true)
            uploader?.abortTransport()
        } catch (_: Exception) {
            // 已結束或中斷。
        }
    }

    private fun finishUserStop(
        snapshot: DriveUploadJob?,
        startId: Int?,
        workerSettled: Boolean,
    ) {
        pendingRetry?.cancel(false)
        val after = jobStore.readActiveJob()
        val plan =
            DriveCancelStopDecision.plan(
                snapshotBeforeStop = snapshot,
                jobAfterSettle = after,
                workerSettled = workerSettled,
            )
        when (plan.localAction) {
            DriveCancelStopDecision.LocalAction.RetainCommitted -> {
                after?.let(::notifyCommitted)
                DriveUploadBridge.emitStateEnvelope(applicationContext)
                stopSelfSafely(startId)
            }
            DriveCancelStopDecision.LocalAction.CleanupLocal -> {
                val job = after ?: snapshot
                if (job != null) {
                    applyCancelCleanupOutcome(
                        DriveRemoteFileCleanup.completeCancelCleanup(
                            jobStore = jobStore,
                            tokenProvider = tokenProvider,
                            job = job,
                            workerAlive = false,
                        ),
                    )
                }
                DriveUploadBridge.emitStateEnvelope(applicationContext)
                getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
                stopSelfSafely(startId)
            }
            DriveCancelStopDecision.LocalAction.AwaitWorker -> {
                val pending = jobStore.readActiveJob() ?: after ?: snapshot
                if (pending != null) {
                    updateProgressNotification(pending)
                }
                DriveUploadBridge.emitStateEnvelope(applicationContext)
                // worker finally 會完成清理並 stopSelf。
            }
        }
    }

    private fun finishCancelCleanupFromWorker(jobId: String, startId: Int) {
        val job = jobStore.readJob(jobId) ?: return
        if (!job.isCancelCleanupPhase()) {
            if (stopRequested.get() && !job.isRemoteCommittedPhase()) {
                // 停止已發出但尚未寫入 pending（競態）：補標記後清理。
                jobStore.markCancelCleanupPending(job.jobId)
            } else {
                return
            }
        }
        val current = jobStore.readJob(jobId) ?: return
        if (!current.isCancelCleanupPhase()) {
            return
        }
        val outcome =
            DriveRemoteFileCleanup.completeCancelCleanup(
                jobStore = jobStore,
                tokenProvider = tokenProvider,
                job = current,
                workerAlive = false,
            )
        mainHandler.post {
            applyCancelCleanupOutcome(outcome)
            DriveUploadBridge.emitStateEnvelope(applicationContext)
            getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
            stopSelfSafely(startId)
        }
    }

    private fun applyCancelCleanupOutcome(outcome: DriveRemoteFileCleanup.CancelCleanupOutcome) {
        when (outcome) {
            is DriveRemoteFileCleanup.CancelCleanupOutcome.RetainedCommitted ->
                notifyCommitted(outcome.job)
            DriveRemoteFileCleanup.CancelCleanupOutcome.ClearedLocal,
            DriveRemoteFileCleanup.CancelCleanupOutcome.RetryLater,
            -> Unit
        }
    }

    private fun finishCommitted(job: DriveUploadJob, startId: Int) {
        DriveUploadBridge.emitStateEnvelope(applicationContext)
        notifyCommitted(job)
        stopSelfSafely(startId)
    }

    private fun finishFailure(
        jobId: String,
        startId: Int?,
        errorCode: String,
        message: String,
    ) {
        pendingRetry?.cancel(false)
        if (jobId.isNotBlank()) {
            val failed = jobStore.failAndCleanup(jobId, errorCode, message)
            if (failed != null) {
                notifyFailed(failed)
            }
        }
        DriveUploadBridge.emitStateEnvelope(applicationContext)
        stopSelfSafely(startId)
    }

    private fun finishCancellation(startId: Int? = null) {
        // uploader 主動回報 Cancelled（非通知列／Bridge 停止路徑）時沿用同一收尾。
        val snapshot = jobStore.readActiveJob()
        if (snapshot != null && !snapshot.isRemoteCommittedPhase()) {
            jobStore.markCancelCleanupPending(snapshot.jobId)
        }
        finishUserStop(
            snapshot = snapshot,
            startId = startId,
            workerSettled = true,
        )
    }

    private fun stopSelfSafely(startId: Int? = null) {
        unregisterNetworkCallback()
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (startId != null && startId > 0) {
            stopSelf(startId)
        } else {
            stopSelf()
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) {
            return
        }
        val powerManager = getSystemService(PowerManager::class.java) ?: return
        wakeLock =
            powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "quill_diary:drive_upload",
            ).also {
                it.setReferenceCounted(false)
                it.acquire(6 * 60 * 60 * 1000L)
            }
    }

    private fun releaseWakeLock() {
        runCatching {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        }
        wakeLock = null
    }

    private fun registerNetworkCallback() {
        if (networkCallback != null) {
            return
        }
        val connectivity = getSystemService(ConnectivityManager::class.java) ?: return
        val callback =
            object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    onValidatedNetwork()
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: NetworkCapabilities,
                ) {
                    if (networkCapabilities.hasCapability(
                            NetworkCapabilities.NET_CAPABILITY_VALIDATED,
                        )
                    ) {
                        onValidatedNetwork()
                    }
                }
            }
        networkCallback = callback
        val request =
            NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                .build()
        runCatching { connectivity.registerNetworkCallback(request, callback) }
    }

    private fun onValidatedNetwork() {
        val job = jobStore.readActiveJob() ?: return
        if (job.phase == DriveUploadPhase.WAITING_FOR_NETWORK &&
            uploadFuture?.isDone != false &&
            !stopRequested.get()
        ) {
            mainHandler.post { maybeRetry(job.jobId) }
        }
    }

    private fun unregisterNetworkCallback() {
        val callback = networkCallback ?: return
        val connectivity = getSystemService(ConnectivityManager::class.java)
        runCatching { connectivity?.unregisterNetworkCallback(callback) }
        networkCallback = null
    }

    private fun resetProgressThrottle() {
        lastProgressEmitAtMs = 0L
        lastEmittedProgressFraction = -1.0
        lastEmittedPhase = null
    }

    private fun maybeEmitProgress(job: DriveUploadJob) {
        val now = System.currentTimeMillis()
        val phaseChanged = job.phase != lastEmittedPhase
        if (job.phase == DriveUploadPhase.UPLOADING && !phaseChanged) {
            val progressDelta = abs(job.progressFraction() - lastEmittedProgressFraction)
            val elapsed = now - lastProgressEmitAtMs
            if (elapsed < PROGRESS_EMIT_MIN_INTERVAL_MS &&
                progressDelta < PROGRESS_EMIT_MIN_DELTA
            ) {
                return
            }
        }
        lastProgressEmitAtMs = now
        lastEmittedProgressFraction = job.progressFraction()
        lastEmittedPhase = job.phase
        DriveUploadBridge.emitStateEnvelope(applicationContext)
        mainHandler.post { updateProgressNotification(job) }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.drive_upload_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = getString(R.string.drive_upload_notification_channel_description)
                setShowBadge(false)
            }
        manager.createNotificationChannel(channel)
    }

    private fun buildProgressNotification(job: DriveUploadJob): Notification {
        val percent = (job.progressFraction() * 100).toInt().coerceIn(0, 100)
        val content =
            when (job.phase) {
                DriveUploadPhase.WAITING_FOR_NETWORK ->
                    getString(R.string.drive_upload_notification_waiting_network)
                DriveUploadPhase.CANCEL_CLEANUP_PENDING ->
                    getString(R.string.drive_upload_notification_cancel_cleanup)
                else ->
                    getString(R.string.drive_upload_notification_progress, job.fileName, percent)
            }
        val builder =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_upload)
                .setContentTitle(getString(R.string.drive_upload_notification_title))
                .setContentText(content)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setContentIntent(openAppPendingIntent())
                .setPriority(NotificationCompat.PRIORITY_LOW)
        if (job.phase != DriveUploadPhase.CANCEL_CLEANUP_PENDING) {
            builder.addAction(
                0,
                getString(R.string.drive_upload_notification_stop),
                stopPendingIntent(),
            )
        }
        if (job.phase == DriveUploadPhase.UPLOADING || job.phase == DriveUploadPhase.STAGED) {
            builder.setProgress(100, percent, false)
        } else {
            builder.setProgress(0, 0, true)
        }
        return builder.build()
    }

    private fun updateProgressNotification(job: DriveUploadJob) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.notify(NOTIFICATION_ID, buildProgressNotification(job))
    }

    private fun notifyCommitted(job: DriveUploadJob) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_upload_done)
                .setContentTitle(getString(R.string.drive_upload_notification_title))
                .setContentText(
                    getString(R.string.drive_upload_notification_completed, job.fileName),
                )
                .setOnlyAlertOnce(true)
                .setAutoCancel(true)
                .setContentIntent(openAppPendingIntent())
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
        manager.notify(COMPLETION_NOTIFICATION_ID, notification)
        manager.cancel(NOTIFICATION_ID)
    }

    private fun notifyFailed(job: DriveUploadJob) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_notify_error)
                .setContentTitle(getString(R.string.drive_upload_notification_title))
                .setContentText(getString(R.string.drive_upload_notification_failed))
                .setOnlyAlertOnce(true)
                .setAutoCancel(true)
                .setContentIntent(openAppPendingIntent())
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .build()
        manager.notify(COMPLETION_NOTIFICATION_ID, notification)
        manager.cancel(NOTIFICATION_ID)
    }

    private fun openAppPendingIntent(): PendingIntent {
        val intent =
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_OPEN_DRIVE_BACKUP, true)
            }
        return PendingIntent.getActivity(
            this,
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun stopPendingIntent(): PendingIntent {
        val intent =
            Intent(this, BackupUploadForegroundService::class.java).apply {
                action = ACTION_STOP
            }
        return PendingIntent.getService(
            this,
            2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        const val ACTION_START = "zack20136.com.quill_diary.drive.START"
        const val ACTION_STOP = "zack20136.com.quill_diary.drive.STOP"
        const val EXTRA_JOB_ID = "jobId"
        const val EXTRA_OPEN_DRIVE_BACKUP = "openDriveBackup"
        private const val CHANNEL_ID = DriveUploadBridge.NOTIFICATION_CHANNEL_ID
        private const val NOTIFICATION_ID = 44021
        private const val COMPLETION_NOTIFICATION_ID = 44022
        private const val NETWORK_RETRY_DEBOUNCE_MS = 2_000L
        private const val PROGRESS_EMIT_MIN_INTERVAL_MS = 2_000L
        private const val PROGRESS_EMIT_MIN_DELTA = 0.05
        private const val UPLOAD_STOP_AWAIT_TIMEOUT_MS = 15_000L

        @Volatile
        private var running: Boolean = false

        /**
         * startForegroundService 已成功、但 onCreate 尚未執行時的保護。
         * 避免 getState／EventChannel 在空窗誤判為程序中斷而 abandon。
         */
        @Volatile
        private var pendingStartJobId: String? = null

        /** 上傳 worker 執行中（含 finally 收尾）；冷啟動不得在此期間因 404 刪 job。 */
        @Volatile
        private var uploadWorkerAlive: Boolean = false

        private val stopAwaiter = AtomicReference<CompletableFuture<Unit>?>(null)

        fun isRunning(): Boolean = running

        /** Service 已在跑，或已請求啟動且尚未 onCreate／失敗清理。 */
        fun isActiveOrStarting(): Boolean = running || pendingStartJobId != null

        fun isUploadWorkerAlive(): Boolean = uploadWorkerAlive

        /** 嘗試啟動 FGS；失敗時 failAndCleanup 並回傳 false。 */
        fun startOrMarkInterrupted(context: Context, jobId: String): Boolean {
            val appContext = context.applicationContext
            val intent =
                Intent(appContext, BackupUploadForegroundService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_JOB_ID, jobId)
                }
            // 必須在 startForegroundService 之前設置，堵住回傳後到 onCreate 的空窗。
            pendingStartJobId = jobId
            return try {
                androidx.core.content.ContextCompat.startForegroundService(appContext, intent)
                true
            } catch (error: Throwable) {
                pendingStartJobId = null
                markFailedForStartFailure(appContext, jobId, error)
                false
            }
        }

        fun markFailedForStartFailure(
            context: Context,
            jobId: String,
            error: Throwable,
        ): DriveUploadJob? {
            pendingStartJobId = null
            val message =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    error is ForegroundServiceStartNotAllowedException
                ) {
                    "無法在背景啟動上傳。請保持 App 顯示在畫面上後再試。"
                } else {
                    error.message ?: "無法啟動背景上傳服務。"
                }
            val failed =
                DriveUploadJobStore.get(context).failAndCleanup(
                    jobId,
                    errorCode = "fgs_start_not_allowed",
                    message = message,
                )
            DriveUploadBridge.emitStateEnvelope(context.applicationContext)
            return failed
        }

        fun stop(context: Context) {
            val intent =
                Intent(context, BackupUploadForegroundService::class.java).apply {
                    action = ACTION_STOP
                }
            context.startService(intent)
        }

        /**
         * 送出停止並等待 Service 完成 abort／落定／cleanup。
         * 逾時仍回傳（收尾可能仍在背景繼續）。
         */
        fun requestStopAndAwait(
            context: Context,
            timeoutMs: Long = UPLOAD_STOP_AWAIT_TIMEOUT_MS + 5_000L,
        ) {
            val future = CompletableFuture<Unit>()
            stopAwaiter.set(future)
            try {
                stop(context)
                runCatching {
                    future.get(timeoutMs, TimeUnit.MILLISECONDS)
                }
            } finally {
                stopAwaiter.compareAndSet(future, null)
            }
        }

        private fun completeStopAwaiter() {
            stopAwaiter.getAndSet(null)?.complete(Unit)
        }
    }
}
