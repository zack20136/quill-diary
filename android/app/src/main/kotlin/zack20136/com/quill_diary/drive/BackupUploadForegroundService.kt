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
import androidx.core.content.ContextCompat
import zack20136.com.quill_diary.MainActivity
import zack20136.com.quill_diary.AndroidAppStrings
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

/** Drive 上傳可在 FlutterEngine 關閉時繼續執行。 */
class BackupUploadForegroundService : Service() {
    private val executor = Executors.newSingleThreadExecutor()
    private val scheduler: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var uploadFuture: Future<*>? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var uploader: DriveResumableUploader? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private val stopRequested = AtomicBoolean(false)
    private val stopEpoch = AtomicLong(0L)
    private var pendingRetry: Future<*>? = null
    private val retryLock = Any()

    private lateinit var jobStore: DriveUploadJobStore
    private lateinit var tokenProvider: DriveAccessTokenProvider

    override fun onCreate() {
        super.onCreate()
        running = true
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
            ACTION_REFRESH_LOCALIZATION -> {
                ensureNotificationChannel()
                jobStore.readActiveJob()?.let(::updateProgressNotification)
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
        beginCancelCleanupInterrupt()
        pendingRetry?.cancel(false)
        uploader?.abortTransport()
        publishAfterInterrupt()
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf(startId)
    }

    override fun onDestroy() {
        running = false
        pendingStartJobId = null
        beginCancelCleanupInterrupt()
        unregisterNetworkCallback()
        pendingRetry?.cancel(false)
        uploader?.abortTransport()
        uploadFuture?.cancel(true)
        releaseWakeLock()
        executor.shutdownNow()
        scheduler.shutdownNow()
        val terminated =
            runCatching {
                executor.awaitTermination(EXECUTOR_SHUTDOWN_AWAIT_MS, TimeUnit.MILLISECONDS)
            }.getOrDefault(false)
        if (terminated) {
            uploadWorkerAlive = false
            publishAfterInterrupt()
        } else {
            // 執行緒可能仍卡住：保留 uploadWorkerAlive，避免 getState 對尚在跑的 HTTP 誤刪。
            DriveUploadBridge.emitStateEnvelope(applicationContext)
        }
        super.onDestroy()
    }

    private fun beginCancelCleanupInterrupt() {
        stopRequested.set(true)
        stopEpoch.incrementAndGet()
        persistCancelCleanupIfUncommitted()
    }

    private fun persistCancelCleanupIfUncommitted(job: DriveUploadJob? = jobStore.readActiveJob()) {
        if (job != null && !job.isRemoteCommittedPhase()) {
            jobStore.markCancelCleanupPending(job.jobId)
        }
    }

    private fun publishAfterInterrupt() {
        if (!hasLiveUploadWorker()) {
            DriveUploadBridge.scheduleCancelCleanupReconcile(applicationContext)
        } else {
            DriveUploadBridge.emitStateEnvelope(applicationContext)
        }
    }

    private fun wasUploadInterrupted(workerStartEpoch: Long): Boolean =
        stopEpoch.get() != workerStartEpoch || stopRequested.get()

    private fun startUpload(jobId: String, startId: Int) {
        if (stopRequested.get() || hasLiveUploadWorker()) {
            return
        }
        val stopEpochAtStart = stopEpoch.get()
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
            submitUploadWorker {
                finishCancelCleanupFromWorker(job.jobId, startId)
            }
            return
        }

        val notification = buildProgressNotification(job)
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } catch (error: Throwable) {
            recordStartFailure(applicationContext, jobId, error)
            stopSelfSafely(startId)
            return
        }
        acquireWakeLock()
        registerNetworkCallback()

        submitUploadWorker {
            runUploadWorker(jobId, stopEpochAtStart, startId)
        }
    }

    private fun submitUploadWorker(block: () -> Unit) {
        uploadWorkerAlive = true
        uploadFuture =
            executor.submit {
                try {
                    block()
                } finally {
                    uploadWorkerAlive = false
                }
            }
    }

    private fun runUploadWorker(jobId: String, workerStartEpoch: Long, startId: Int) {
        try {
            if (wasUploadInterrupted(workerStartEpoch)) {
                return
            }
            val activeUploader = DriveResumableUploader(jobStore, tokenProvider)
            uploader = activeUploader
            val currentJob = jobStore.readJob(jobId) ?: return
            val outcome =
                activeUploader.run(currentJob) { updated ->
                    if (!wasUploadInterrupted(workerStartEpoch)) {
                        publishProgress(updated)
                    }
                }
            if (wasUploadInterrupted(workerStartEpoch)) {
                return
            }
            mainHandler.post { handleOutcome(outcome, workerStartEpoch, startId) }
        } catch (error: Throwable) {
            if (wasUploadInterrupted(workerStartEpoch)) {
                return
            }
            mainHandler.post {
                finishFailure(
                    jobId,
                    startId = startId,
                    errorCode = "unexpected",
                    message = localizedFailureMessage("unexpected"),
                )
            }
        } finally {
            uploader = null
            releaseWakeLock()
            finishCancelCleanupFromWorker(jobId, startId)
        }
    }

    private fun handleOutcome(outcome: DriveUploadOutcome, workerStartEpoch: Long, startId: Int) {
        if (wasUploadInterrupted(workerStartEpoch)) {
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
                    message = localizedFailureMessage(outcome.code),
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
        if (stopRequested.get() || hasLiveUploadWorker()) {
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
                message = localizedFailureMessage("max_attempts"),
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

    /** 等待 worker 退出時，不阻塞主執行緒。 */
    private fun handleUserStop(startId: Int) {
        beginCancelCleanupInterrupt()
        val snapshot = jobStore.readActiveJob()
        pendingRetry?.cancel(false)
        uploader?.cancelUser()
        val futureToAwait = uploadFuture
        scheduler.execute {
            awaitUploadFutureSettled(futureToAwait)
            try {
                finishUserStop(snapshot = snapshot, startId = startId)
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
        }
    }

    private fun finishUserStop(
        snapshot: DriveUploadJob?,
        startId: Int?,
    ) {
        pendingRetry?.cancel(false)
        val after = jobStore.readActiveJob()
        when (
            resolveUploadStopAction(
                currentJob = after,
                // Future.cancel 後仍須等 worker 實際退出。
                workerExited = !hasLiveUploadWorker(),
            )
        ) {
            DriveUploadStopAction.KeepCommitted -> {
                after?.let(::notifyCommitted)
                DriveUploadBridge.emitStateEnvelope(applicationContext)
                stopSelfSafely(startId)
            }
            DriveUploadStopAction.ReconcileRemote -> {
                val job = after ?: snapshot
                if (job != null) {
                    publishCleanupResultAndStop(
                        runCancelCleanup(job),
                        startId,
                    )
                } else {
                    DriveUploadBridge.emitStateEnvelope(applicationContext)
                    stopSelfSafely(startId)
                }
            }
            DriveUploadStopAction.WaitForWorker -> {
                val pending = jobStore.readActiveJob() ?: after ?: snapshot
                if (pending != null) {
                    updateProgressNotification(pending)
                }
                DriveUploadBridge.emitStateEnvelope(applicationContext)
            }
        }
    }

    private fun finishCancelCleanupFromWorker(jobId: String, startId: Int) {
        val job = jobStore.readJob(jobId) ?: return
        if (!job.isCancelCleanupPhase()) {
            if (!stopRequested.get() || job.isRemoteCommittedPhase()) {
                return
            }
            // 停止已發出但尚未寫入 pending（競態）：補標記後清理。
            persistCancelCleanupIfUncommitted(job)
        }
        val current = jobStore.readJob(jobId) ?: return
        if (!current.isCancelCleanupPhase()) {
            return
        }
        val outcome = runCancelCleanup(current)
        mainHandler.post { publishCleanupResultAndStop(outcome, startId) }
    }

    private fun runCancelCleanup(job: DriveUploadJob): DriveRemoteFileCleanup.CancelCleanupOutcome =
        DriveRemoteFileCleanup.completeCancelCleanup(
            jobStore = jobStore,
            tokenProvider = tokenProvider,
            job = job,
            workerAlive = false,
        )

    private fun publishCleanupResultAndStop(
        outcome: DriveRemoteFileCleanup.CancelCleanupOutcome,
        startId: Int?,
    ) {
        if (outcome is DriveRemoteFileCleanup.CancelCleanupOutcome.RetainedCommitted) {
            notifyCommitted(outcome.job)
        }
        DriveUploadBridge.emitStateEnvelope(applicationContext)
        getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
        stopSelfSafely(startId)
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
            val failed = jobStore.recordUploadFailure(jobId, errorCode, message)
            if (failed != null) {
                notifyFailed()
            }
        }
        DriveUploadBridge.emitStateEnvelope(applicationContext)
        stopSelfSafely(startId)
    }

    private fun finishCancellation(startId: Int? = null) {
        val snapshot = jobStore.readActiveJob()
        persistCancelCleanupIfUncommitted(snapshot)
        finishUserStop(snapshot = snapshot, startId = startId)
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
            !hasLiveUploadWorker() &&
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

    private fun publishProgress(job: DriveUploadJob) {
        DriveUploadBridge.emitStateEnvelope(applicationContext)
        mainHandler.post { updateProgressNotification(job) }
    }

    private fun ensureNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                localizedString(R.string.drive_upload_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description =
                    localizedString(R.string.drive_upload_notification_channel_description)
                setShowBadge(false)
            }
        manager.createNotificationChannel(channel)
    }

    private fun buildProgressNotification(job: DriveUploadJob): Notification {
        val percent = job.progressPercent()
        val content =
            when (job.phase) {
                DriveUploadPhase.WAITING_FOR_NETWORK ->
                    localizedString(R.string.drive_upload_notification_waiting_network)
                DriveUploadPhase.CANCEL_CLEANUP_PENDING ->
                    localizedString(R.string.drive_upload_notification_cancel_cleanup)
                else ->
                    localizedString(
                        R.string.drive_upload_notification_progress,
                        job.fileName,
                        percent,
                    )
            }
        val builder =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_upload)
                .setContentTitle(localizedString(R.string.drive_upload_notification_title))
                .setContentText(content)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setContentIntent(openAppPendingIntent())
                .setPriority(NotificationCompat.PRIORITY_LOW)
        if (job.phase != DriveUploadPhase.CANCEL_CLEANUP_PENDING) {
            builder.addAction(
                0,
                localizedString(R.string.drive_upload_notification_stop),
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
                .setContentTitle(localizedString(R.string.drive_upload_notification_title))
                .setContentText(
                    localizedString(
                        R.string.drive_upload_notification_completed,
                        job.fileName,
                    ),
                )
                .setOnlyAlertOnce(true)
                .setAutoCancel(true)
                .setContentIntent(openAppPendingIntent())
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
        manager.notify(COMPLETION_NOTIFICATION_ID, notification)
        manager.cancel(NOTIFICATION_ID)
    }

    private fun notifyFailed() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_notify_error)
                .setContentTitle(localizedString(R.string.drive_upload_notification_title))
                .setContentText(localizedString(R.string.drive_upload_notification_failed))
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

    private fun localizedString(resourceId: Int, vararg arguments: Any): String =
        AndroidAppStrings.string(this, resourceId, *arguments)

    private fun localizedFailureMessage(errorCode: String): String {
        val httpStatus = errorCode.removePrefix("http_").toIntOrNull()
        if (httpStatus != null) {
            return localizedString(R.string.drive_upload_error_http, httpStatus)
        }
        val resourceId =
            when (errorCode) {
                "max_attempts" -> R.string.drive_upload_error_max_attempts
                "completion_mismatch" -> R.string.drive_upload_error_completion_mismatch
                "invalid_range" -> R.string.drive_upload_error_invalid_range
                "session_expired" -> R.string.drive_upload_error_session_expired
                "forbidden" -> R.string.drive_upload_error_forbidden
                "incomplete" -> R.string.drive_upload_error_incomplete
                "staging_invalid" -> R.string.drive_upload_error_staging_invalid
                "generate_id" -> R.string.drive_upload_error_generate_id
                "missing_session" -> R.string.drive_upload_error_missing_session
                "conflict" -> R.string.drive_upload_error_conflict
                "authorization" -> R.string.drive_upload_error_authorization
                "start_failed" -> R.string.drive_upload_error_start_failed
                "fgs_start_not_allowed" -> R.string.drive_upload_error_fgs_start_not_allowed
                else -> R.string.drive_upload_error_unexpected
            }
        return localizedString(resourceId)
    }

    companion object {
        const val ACTION_START = "zack20136.com.quill_diary.drive.START"
        const val ACTION_STOP = "zack20136.com.quill_diary.drive.STOP"
        const val ACTION_REFRESH_LOCALIZATION =
            "zack20136.com.quill_diary.drive.REFRESH_LOCALIZATION"
        const val EXTRA_JOB_ID = "jobId"
        const val EXTRA_OPEN_DRIVE_BACKUP = "openDriveBackup"
        private const val CHANNEL_ID = DriveUploadBridge.NOTIFICATION_CHANNEL_ID
        private const val NOTIFICATION_ID = 44021
        private const val COMPLETION_NOTIFICATION_ID = 44022
        private const val NETWORK_RETRY_DEBOUNCE_MS = 2_000L
        private const val UPLOAD_STOP_AWAIT_TIMEOUT_MS = 15_000L
        private const val EXECUTOR_SHUTDOWN_AWAIT_MS = 1_000L

        @Volatile
        private var running: Boolean = false

        /** 啟動服務期間保護剛建立的工作，避免被狀態查詢誤清。 */
        @Volatile
        private var pendingStartJobId: String? = null

        /** 上傳 worker 執行中（含 finally 收尾）；冷啟動不得在此期間因 404 刪 job。 */
        @Volatile
        private var uploadWorkerAlive: Boolean = false

        private val stopAwaiter = AtomicReference<CompletableFuture<Unit>?>(null)

        fun isRunning(): Boolean = running

        fun isActiveOrStarting(): Boolean = running || pendingStartJobId != null

        fun hasLiveUploadWorker(): Boolean = uploadWorkerAlive

        fun startOrRecordFailure(context: Context, jobId: String): Boolean {
            val appContext = context.applicationContext
            val intent =
                Intent(appContext, BackupUploadForegroundService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_JOB_ID, jobId)
                }
            // 必須在 startForegroundService 之前設置，堵住回傳後到 onCreate 的空窗。
            pendingStartJobId = jobId
            return try {
                ContextCompat.startForegroundService(appContext, intent)
                true
            } catch (error: Throwable) {
                pendingStartJobId = null
                recordStartFailure(appContext, jobId, error)
                false
            }
        }

        private fun recordStartFailure(
            context: Context,
            jobId: String,
            error: Throwable,
        ) {
            pendingStartJobId = null
            val message =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    error is ForegroundServiceStartNotAllowedException
                ) {
                    AndroidAppStrings.string(
                        context,
                        R.string.drive_upload_error_fgs_start_not_allowed,
                    )
                } else {
                    AndroidAppStrings.string(
                        context,
                        R.string.drive_upload_error_start_failed,
                    )
                }
            DriveUploadJobStore.get(context).recordUploadFailure(
                jobId,
                errorCode = "fgs_start_not_allowed",
                message = message,
            )
            DriveUploadBridge.emitStateEnvelope(context.applicationContext)
        }

        fun stop(context: Context) {
            val intent =
                Intent(context, BackupUploadForegroundService::class.java).apply {
                    action = ACTION_STOP
                }
            context.startService(intent)
        }

        fun refreshLocalization(context: Context) {
            if (!running) {
                return
            }
            val intent =
                Intent(context, BackupUploadForegroundService::class.java).apply {
                    action = ACTION_REFRESH_LOCALIZATION
                }
            context.startService(intent)
        }

        /** 等待逾時後，收尾仍可能在背景繼續。 */
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
