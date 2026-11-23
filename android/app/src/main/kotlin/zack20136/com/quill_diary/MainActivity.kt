package zack20136.com.quill_diary

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import zack20136.com.quill_diary.drive.BackupUploadForegroundService
import zack20136.com.quill_diary.drive.DriveSignInChannel
import zack20136.com.quill_diary.drive.DriveUploadBridge

class MainActivity : FlutterFragmentActivity() {
    private val deviceKeyChannel = DeviceKeyChannel(this)
    private val driveSignInChannel = DriveSignInChannel(this)
    private val documentFileChannels = DocumentFileChannels(this)
    private var pendingOpenDriveBackup = false

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            DriveUploadBridge.completeNotificationPermission(granted)
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SensitiveClipboardChannel.register(flutterEngine, applicationContext)
        EasyDiaryRealmChannel.register(flutterEngine, applicationContext)
        MediaStoreExportChannel.register(flutterEngine, applicationContext)
        DriveUploadBridge.register(flutterEngine, this)
        deviceKeyChannel.register(flutterEngine)
        driveSignInChannel.register(flutterEngine)
        documentFileChannels.register(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureOpenDriveBackupExtra(intent)
    }

    override fun onResume() {
        super.onResume()
        DriveUploadBridge.attachActivity(this)
        captureOpenDriveBackupExtra(intent)
    }

    override fun onDestroy() {
        documentFileChannels.onDirectoryResult(Activity.RESULT_CANCELED, null)
        driveSignInChannel.cancelPendingSignIn()
        DriveUploadBridge.detachActivity(this)
        super.onDestroy()
    }

    /** 回傳 false 表示無法發起請求（例如 Activity 已結束）。 */
    internal fun launchNotificationPermissionRequest(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            DriveUploadBridge.completeNotificationPermission(true)
            return true
        }
        if (isFinishing || isDestroyed) {
            return false
        }
        return try {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            true
        } catch (_: Throwable) {
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            DriveSignInChannel.SIGN_IN_REQUEST_CODE -> driveSignInChannel.onSignInResult(data)
            DocumentFileChannels.DIRECTORY_REQUEST_CODE -> documentFileChannels.onDirectoryResult(resultCode, data)
            else -> super.onActivityResult(requestCode, resultCode, data)
        }
    }

    internal fun consumeOpenDriveBackupRequest(): Boolean {
        val pending = pendingOpenDriveBackup
        pendingOpenDriveBackup = false
        return pending
    }

    private fun captureOpenDriveBackupExtra(intent: Intent?) {
        if (intent?.getBooleanExtra(
                BackupUploadForegroundService.EXTRA_OPEN_DRIVE_BACKUP,
                false,
            ) == true
        ) {
            pendingOpenDriveBackup = true
            intent.removeExtra(BackupUploadForegroundService.EXTRA_OPEN_DRIVE_BACKUP)
        }
    }
}
