package zack20136.com.quill_diary.drive

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.lang.ref.WeakReference
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import zack20136.com.quill_diary.MainActivity

/**
 * Dart ↔ 原生背景上傳橋接。
 * 重 I/O 走單一背景執行緒；通知權限維持主執行緒。
 */
object DriveUploadBridge {
    const val METHOD_CHANNEL = "quill_diary/drive_upload"
    const val EVENT_CHANNEL = "quill_diary/drive_upload_events"
    const val NOTIFICATION_CHANNEL_ID = "quill_diary_drive_upload"

    private val listeners = CopyOnWriteArrayList<EventChannel.EventSink>()
    private val pendingNotificationResult = AtomicReference<MethodChannel.Result?>(null)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private var activityRef: WeakReference<Activity>? = null
    private var appContextRef: WeakReference<Context>? = null

    fun attachActivity(activity: Activity) {
        activityRef = WeakReference(activity)
    }

    fun detachActivity(activity: Activity) {
        val current = activityRef?.get()
        if (current === activity || current == null) {
            activityRef = null
            clearPendingNotificationPermission()
        }
    }

    fun register(flutterEngine: FlutterEngine, context: Context) {
        listeners.clear()
        val appContext = context.applicationContext
        appContextRef = WeakReference(appContext)
        if (context is Activity) {
            attachActivity(context)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                handleMethod(appContext, call, result)
            } catch (error: Throwable) {
                result.error(
                    "drive_upload_error",
                    error.message ?: "Drive upload bridge failed.",
                    null,
                )
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                private var currentSink: EventChannel.EventSink? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events != null) {
                        currentSink = events
                        listeners.add(events)
                        ioExecutor.execute {
                            val envelope = readStateEnvelope(appContext)
                            mainHandler.post { events.success(envelope) }
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    val sink = currentSink
                    currentSink = null
                    if (sink != null) {
                        listeners.remove(sink)
                    }
                }
            },
        )
    }

  fun emitStateEnvelope(context: Context? = null) {
    val appContext = context?.applicationContext ?: appContextRef?.get() ?: return
    val envelope = DriveUploadJobStore.get(appContext).getStateEnvelope()
    val deliver = {
      val failed = ArrayList<EventChannel.EventSink>()
      for (sink in listeners) {
        val ok = runCatching { sink.success(envelope) }.isSuccess
        if (!ok) {
          failed.add(sink)
        }
      }
      if (failed.isNotEmpty()) {
        listeners.removeAll(failed.toSet())
      }
    }
    if (Looper.myLooper() == Looper.getMainLooper()) {
      deliver()
    } else {
      mainHandler.post(deliver)
    }
  }

  fun completeNotificationPermission(granted: Boolean) {
        val pending = pendingNotificationResult.getAndSet(null) ?: return
        pending.success(granted)
    }

    fun clearPendingNotificationPermission() {
        val pending = pendingNotificationResult.getAndSet(null) ?: return
        runCatching { pending.success(false) }
    }

    private fun readStateEnvelope(context: Context): Map<String, Any?> {
        val jobStore = DriveUploadJobStore.get(context)
        // 含 startForegroundService→onCreate 空窗；避免誤清剛建立的 STAGED job。
        val serviceBusy =
            BackupUploadForegroundService.isActiveOrStarting() ||
                BackupUploadForegroundService.isUploadWorkerAlive()
        if (!serviceBusy) {
            val active = jobStore.readActiveJob()
            if (active != null && active.isCancelCleanupPhase()) {
                DriveRemoteFileCleanup.completeCancelCleanup(
                    jobStore = jobStore,
                    tokenProvider = DriveAccessTokenProvider(context.applicationContext),
                    job = active,
                    workerAlive = false,
                )
            } else {
                jobStore.abandonUncommittedIfPresent(
                    "上次 Google Drive 備份未完成，已取消。請重新備份。",
                )
            }
        }
        return jobStore.getStateEnvelope()
    }

    private fun handleMethod(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val jobStore = DriveUploadJobStore.get(context)
        when (call.method) {
            "getState" -> {
                ioExecutor.execute {
                    replySuccess(result, readStateEnvelope(context))
                }
            }
            "prepareStagingPath" -> prepareStagingPath(jobStore, call, result)
            "startUpload" -> startUpload(context, jobStore, call, result)
            "cancelUpload" -> cancelUpload(context, jobStore, result)
            "ackFailure" -> {
                val jobId = call.argument<String>("jobId")?.trim().orEmpty()
                ioExecutor.execute {
                    jobStore.ackFailure(jobId)
                    emitStateEnvelope()
                    replySuccess(result, null)
                }
            }
            "markStatusRecorded" -> {
                val jobId = call.argument<String>("jobId")?.trim().orEmpty()
                ioExecutor.execute {
                    jobStore.markStatusRecorded(jobId)
                    emitStateEnvelope()
                    replySuccess(result, jobStore.getStateEnvelope())
                }
            }
            "finalizeCommitted" -> {
                val jobId = call.argument<String>("jobId")?.trim().orEmpty()
                ioExecutor.execute {
                    jobStore.finalizeCommitted(jobId)
                    emitStateEnvelope()
                    replySuccess(result, null)
                }
            }
            "notificationsAuthorized" -> {
                result.success(areNotificationsAuthorized(context))
            }
            "requestNotificationPermission" -> {
                requestNotificationPermission(context, result)
            }
            "consumeOpenDriveBackup" -> {
                val activity = activityRef?.get() as? MainActivity
                result.success(activity?.consumeOpenDriveBackupRequest() == true)
            }
            else -> result.notImplemented()
        }
    }

    private fun prepareStagingPath(
        jobStore: DriveUploadJobStore,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val rawName = call.argument<String>("fileName")?.trim().orEmpty()
        val fileName = DriveUploadJobStore.sanitizeFileName(rawName)
        if (fileName == null) {
            result.error("invalid_args", "fileName is required.", null)
            return
        }
        ioExecutor.execute {
            try {
                jobStore.cleanupOrphanStaging()
                val root = jobStore.stagingRoot()
                val staging = File(root, "${System.currentTimeMillis()}_$fileName")
                val canonical = staging.canonicalFile
                if (!jobStore.isInsideStagingRoot(canonical.path)) {
                    replyError(result, "staging_invalid", "暫存備份路徑不合法。")
                    return@execute
                }
                replySuccess(result, canonical.absolutePath)
            } catch (error: Throwable) {
                replyError(
                    result,
                    "drive_upload_error",
                    error.message ?: "prepareStagingPath failed.",
                )
            }
        }
    }

    private fun startUpload(
        context: Context,
        jobStore: DriveUploadJobStore,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val stagingPath = call.argument<String>("stagingPath")?.trim().orEmpty()
        val rawName = call.argument<String>("fileName")?.trim().orEmpty()
        val fileName = DriveUploadJobStore.sanitizeFileName(rawName)
        val sizeBytes =
            when (val raw = call.argument<Any>("sizeBytes")) {
                is Number -> raw.toLong()
                else -> raw?.toString()?.toLongOrNull() ?: -1L
            }
        if (stagingPath.isEmpty() || fileName == null || sizeBytes < 0) {
            result.error("invalid_args", "缺少上傳必要參數。", null)
            return
        }
        ioExecutor.execute {
            var createdJobId: String? = null
            try {
                val staging = File(stagingPath)
                if (!staging.isFile || staging.length() != sizeBytes) {
                    replyError(result, "staging_invalid", "暫存備份檔無效。")
                    return@execute
                }
                val canonical = staging.canonicalFile
                if (!jobStore.isInsideStagingRoot(canonical.path)) {
                    replyError(result, "staging_invalid", "暫存備份路徑不合法。")
                    return@execute
                }
                val account =
                    DriveAccessTokenProvider(context).currentAccountSnapshot()
                        ?: run {
                            replyError(result, "needs_authorization", "請先連結 Google 帳戶。")
                            return@execute
                        }
                val md5 = DriveUploadJobStore.md5Hex(canonical)
                val job =
                    DriveUploadJob(
                        jobId = DriveUploadJobStore.newJobId(),
                        phase = DriveUploadPhase.STAGED,
                        accountId = account.first,
                        accountEmail = account.second,
                        stagingPath = canonical.path,
                        fileName = fileName,
                        sizeBytes = sizeBytes,
                        md5 = md5,
                    )
                val saved =
                    jobStore.createJobIfNoConflict(job)
                        ?: run {
                            replyError(result, "job_in_progress", "已有進行中的 Google Drive 上傳。")
                            return@execute
                        }
                createdJobId = saved.jobId
                // 先標記／啟動 FGS，再 emit／回傳，縮短 createJob 與 pendingStart 之間的空窗。
                val started =
                    BackupUploadForegroundService.startOrMarkInterrupted(context, saved.jobId)
                if (!started) {
                    createdJobId = null
                    val envelope = jobStore.getStateEnvelope()
                    replyError(
                        result,
                        "fgs_start_not_allowed",
                        envelope["failure"]?.let { (it as Map<*, *>)["message"]?.toString() }
                            ?: "無法在背景啟動上傳。請保持 App 顯示在畫面上後再試。",
                        envelope,
                    )
                    return@execute
                }
                emitStateEnvelope()
                replySuccess(result, jobStore.getStateEnvelope())
            } catch (error: Throwable) {
                val jobId = createdJobId
                if (jobId != null) {
                    jobStore.failAndCleanup(
                        jobId,
                        errorCode = "start_failed",
                        message = error.message ?: "無法啟動 Google Drive 上傳。",
                    )
                    emitStateEnvelope()
                }
                replyError(
                    result,
                    "drive_upload_error",
                    error.message ?: "startUpload failed.",
                    if (jobId != null) jobStore.getStateEnvelope() else null,
                )
            }
        }
    }

    private fun cancelUpload(
        context: Context,
        jobStore: DriveUploadJobStore,
        result: MethodChannel.Result,
    ) {
        ioExecutor.execute {
            try {
                val job = jobStore.readActiveJob()
                if (job != null && job.isRemoteCommittedPhase()) {
                    replyError(
                        result,
                        "cancel_not_allowed",
                        "遠端備份已完成，無法取消。",
                        jobStore.getStateEnvelope(),
                    )
                    return@execute
                }
                if (job != null && job.isCancelCleanupPhase()) {
                    if (!BackupUploadForegroundService.isUploadWorkerAlive()) {
                        DriveRemoteFileCleanup.completeCancelCleanup(
                            jobStore = jobStore,
                            tokenProvider = DriveAccessTokenProvider(context.applicationContext),
                            job = job,
                            workerAlive = false,
                        )
                    }
                    emitStateEnvelope()
                    replySuccess(result, null)
                    return@execute
                }
                if (BackupUploadForegroundService.isRunning()) {
                    // 先讓 FGS 中止傳輸並落定，再清本機；勿在此先 cancelAndCleanup。
                    BackupUploadForegroundService.requestStopAndAwait(context)
                } else if (job != null) {
                    cancelInactiveJob(context, jobStore, job)
                }
                emitStateEnvelope()
                val after = jobStore.readActiveJob()
                replySuccess(
                    result,
                    if (after != null && after.isRemoteCommittedPhase()) {
                        jobStore.getStateEnvelope()
                    } else {
                        null
                    },
                )
            } catch (error: Throwable) {
                replyError(
                    result,
                    "drive_upload_error",
                    error.message ?: "cancelUpload failed.",
                )
            }
        }
    }

    /** Service 未在跑時的本機取消：標記後查詢／刪遠端殘檔再清 job。 */
    private fun cancelInactiveJob(
        context: Context,
        jobStore: DriveUploadJobStore,
        job: DriveUploadJob,
    ) {
        if (!job.isRemoteCommittedPhase()) {
            jobStore.markCancelCleanupPending(job.jobId)
        }
        val current = jobStore.readJob(job.jobId) ?: return
        DriveRemoteFileCleanup.completeCancelCleanup(
            jobStore = jobStore,
            tokenProvider = DriveAccessTokenProvider(context.applicationContext),
            job = current,
            workerAlive = false,
        )
    }

    private fun requestNotificationPermission(
        context: Context,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(areNotificationsAuthorized(context))
            return
        }
        if (areNotificationsAuthorized(context)) {
            result.success(true)
            return
        }
        val activity = activityRef?.get() as? MainActivity
        if (activity == null) {
            result.success(false)
            return
        }
        if (pendingNotificationResult.get() != null) {
            result.error("permission_in_progress", "通知權限請求進行中。", null)
            return
        }
        pendingNotificationResult.set(result)
        if (!activity.launchNotificationPermissionRequest()) {
            pendingNotificationResult.compareAndSet(result, null)
            result.success(false)
        }
    }

    private fun areNotificationsAuthorized(context: Context): Boolean {
        val notificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return notificationsEnabled
        }
        val permissionGranted =
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        if (!permissionGranted || !notificationsEnabled) {
            return false
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return true
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return true
        val channel = manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) ?: return true
        return channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun replySuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun replyError(
        result: MethodChannel.Result,
        code: String,
        message: String,
        details: Any? = null,
    ) {
        mainHandler.post { result.error(code, message, details) }
    }
}
