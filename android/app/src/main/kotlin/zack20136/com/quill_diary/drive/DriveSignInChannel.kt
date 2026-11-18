package zack20136.com.quill_diary.drive

import android.content.Intent
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import zack20136.com.quill_diary.AndroidAppStrings
import zack20136.com.quill_diary.R

internal class DriveSignInChannel(private val activity: FlutterFragmentActivity) {
    private var pendingSignInResult: MethodChannel.Result? = null

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getServerClientId" -> {
                    val id = activity.getString(R.string.google_drive_web_client_id).trim()
                    result.success(if (id.isEmpty()) null else id)
                }
                "signInGoogleDrive" -> signInGoogleDrive(call, result)
                "getGoogleDriveConnectionSnapshot" -> getGoogleDriveConnectionSnapshot(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun getGoogleDriveConnectionSnapshot(result: MethodChannel.Result) {
        result.success(signedInDriveAccount()?.let(::googleDriveAccountPayload))
    }

    private fun signedInDriveAccount(): GoogleSignInAccount? =
        GoogleSignIn.getLastSignedInAccount(activity)?.takeIf(::hasDriveAppDataPermission)

    private fun signInGoogleDrive(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSignInResult != null) {
            result.error(
                "google_drive_auth_in_progress",
                driveString(R.string.drive_auth_in_progress),
                null,
            )
            return
        }

        val serverClientId = call.argument<String>("serverClientId")?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("serverClientId is required.")
        val resetSession = call.argument<Boolean>("resetSession") ?: false
        val signInClient = createGoogleDriveSignInClient(serverClientId)

        if (!resetSession) {
            signedInDriveAccount()?.let { account ->
                result.success(googleDriveAccountPayload(account))
                return
            }
        }

        pendingSignInResult = result
        if (resetSession) {
            signInClient.revokeAccess().addOnCompleteListener {
                signInClient.signOut().addOnCompleteListener {
                    launchGoogleDriveSignIn(signInClient)
                }
            }
        } else {
            launchGoogleDriveSignIn(signInClient)
        }
    }

    private fun createGoogleDriveSignInClient(serverClientId: String): GoogleSignInClient {
        val signInOptions =
            GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestEmail()
                .requestIdToken(serverClientId)
                .requestScopes(Scope(DriveAccessTokenProvider.DRIVE_APPDATA_SCOPE))
                .build()
        return GoogleSignIn.getClient(activity, signInOptions)
    }

    private fun launchGoogleDriveSignIn(signInClient: GoogleSignInClient) {
        val pending = pendingSignInResult ?: return
        try {
            activity.startActivityForResult(signInClient.signInIntent, SIGN_IN_REQUEST_CODE)
        } catch (_: Exception) {
            pendingSignInResult = null
            pending.error(DriveAuthErrorCode.UNAVAILABLE, authErrorMessage(DriveAuthErrorCode.UNAVAILABLE), null)
        }
    }

    fun cancelPendingSignIn() {
        val pending = pendingSignInResult ?: return
        pendingSignInResult = null
        val code = DriveAuthErrorCode.CANCELLED
        pending.error(code, authErrorMessage(code), null)
    }

    fun onSignInResult(data: Intent?) {
        val pendingResult = pendingSignInResult ?: return
        pendingSignInResult = null
        try {
            val account = GoogleSignIn.getSignedInAccountFromIntent(data)
                .getResult(ApiException::class.java)
                ?: run {
                    pendingResult.error(
                        "google_drive_account_missing",
                        driveString(R.string.drive_auth_account_missing),
                        null,
                    )
                    return
                }
            if (!hasDriveAppDataPermission(account)) {
                pendingResult.error(
                    "google_drive_scope_missing",
                    driveString(R.string.drive_auth_scope_missing),
                    null,
                )
                return
            }
            pendingResult.success(googleDriveAccountPayload(account))
        } catch (error: ApiException) {
            Log.w(TAG, "Google Drive sign-in failed with status ${error.statusCode}.")
            val code = DriveAuthErrorCode.fromApiStatus(error.statusCode, error.localizedMessage)
            pendingResult.error(code, authErrorMessage(code), null)
        } catch (_: Throwable) {
            pendingResult.error(
                DriveAuthErrorCode.FAILED,
                driveString(R.string.drive_auth_failed),
                null,
            )
        }
    }

    private fun googleDriveAccountPayload(account: GoogleSignInAccount): Map<String, Any?> {
        return mapOf(
            "email" to account.email,
            "displayName" to account.displayName,
        )
    }

    private fun authErrorMessage(code: String): String =
        when (code) {
            DriveAuthErrorCode.CONFIGURATION ->
                driveString(R.string.drive_auth_configuration_error)
            DriveAuthErrorCode.NETWORK -> driveString(R.string.drive_auth_network_error)
            DriveAuthErrorCode.REAUTH -> driveString(R.string.drive_auth_reauth_error)
            DriveAuthErrorCode.UNAVAILABLE -> driveString(R.string.drive_auth_unavailable)
            DriveAuthErrorCode.CANCELLED -> driveString(R.string.drive_auth_cancelled)
            else -> driveString(R.string.drive_auth_failed)
        }

    private fun driveString(resourceId: Int): String =
        AndroidAppStrings.string(activity, resourceId)

    companion object {
        const val SIGN_IN_REQUEST_CODE = 43021
        private const val CHANNEL_NAME = "quill_diary/oauth_config"
        private const val TAG = "DriveSignInChannel"
    }
}
