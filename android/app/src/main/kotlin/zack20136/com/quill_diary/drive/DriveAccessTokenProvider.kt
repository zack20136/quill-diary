package zack20136.com.quill_diary.drive

import android.content.Context
import com.google.android.gms.auth.GoogleAuthException
import com.google.android.gms.auth.GoogleAuthUtil
import com.google.android.gms.auth.UserRecoverableAuthException
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.common.api.Scope
import java.io.IOException

internal class DriveAccessTokenProvider(private val context: Context) {
    data class TokenResult(
        val accessToken: String,
        val accountId: String,
        val accountEmail: String,
    )

    sealed class TokenError {
        data object NeedsUserInteraction : TokenError()

        data object NotSignedIn : TokenError()

        data object Transient : TokenError()

        data object Permanent : TokenError()
    }

    fun currentAccountIdentity(): DriveAccountIdentity? {
        val account = GoogleSignIn.getLastSignedInAccount(context) ?: return null
        if (!hasDriveAppDataPermission(account)) {
            return null
        }
        val email = account.email?.trim().orEmpty()
        if (email.isEmpty()) {
            return null
        }
        // id 缺失時保持空字串，不要用 email 偽裝成 accountId。
        val id = account.id?.trim().orEmpty()
        return DriveAccountIdentity(id = id, email = email)
    }

    fun checkSignedInAccount(job: DriveUploadJob): TokenError? {
        val account = currentAccountIdentity() ?: return TokenError.NeedsUserInteraction
        return matchIds(job, account.id, account.email)
    }

    fun matchTokenToJob(job: DriveUploadJob, token: TokenResult): TokenError? =
        matchIds(job, token.accountId, token.accountEmail)

    private fun matchIds(
        job: DriveUploadJob,
        accountId: String,
        accountEmail: String,
    ): TokenError? {
        // 有 accountId 時以 ID 為準；僅在缺少 ID 時退回比較 email。
        val matches =
            if (job.accountId.isNotBlank()) accountId == job.accountId
            else accountEmail.equals(job.accountEmail, ignoreCase = true)
        return if (matches) null else TokenError.Permanent
    }

    fun getAccessToken(clearCache: Boolean = false): Result<TokenResult> {
        val signedIn = GoogleSignIn.getLastSignedInAccount(context)
        if (signedIn == null ||
            !hasDriveAppDataPermission(signedIn)
        ) {
            return Result.failure(TokenException(TokenError.NeedsUserInteraction))
        }
        val email = signedIn.email?.trim().orEmpty()
        val googleAccount = signedIn.account
        if (email.isEmpty() || googleAccount == null) {
            return Result.failure(TokenException(TokenError.NotSignedIn))
        }
        val accountId = signedIn.id?.trim().orEmpty()
        return try {
            if (clearCache) {
                val cached = lastTokenCache
                if (cached != null) {
                    runCatching {
                        GoogleAuthUtil.clearToken(context, cached)
                    }
                }
            }
            val token =
                GoogleAuthUtil.getToken(
                    context,
                    googleAccount,
                    OAUTH2_SCOPE,
                )
            lastTokenCache = token
            Result.success(
                TokenResult(
                    accessToken = token,
                    accountId = accountId,
                    accountEmail = email,
                ),
            )
        } catch (_: UserRecoverableAuthException) {
            Result.failure(TokenException(TokenError.NeedsUserInteraction))
        } catch (_: GoogleAuthException) {
            Result.failure(TokenException(TokenError.Permanent))
        } catch (_: IOException) {
            Result.failure(
                TokenException(
                    TokenError.Transient,
                ),
            )
        }
    }

    class TokenException(val error: TokenError) : Exception(error.toString())

    companion object {
        const val DRIVE_APPDATA_SCOPE =
            "https://www.googleapis.com/auth/drive.appdata"
        private const val OAUTH2_SCOPE = "oauth2:$DRIVE_APPDATA_SCOPE"

        @Volatile
        private var lastTokenCache: String? = null
    }
}

internal data class DriveAccountIdentity(val id: String, val email: String)

internal fun hasDriveAppDataPermission(account: GoogleSignInAccount): Boolean =
    GoogleSignIn.hasPermissions(account, Scope(DriveAccessTokenProvider.DRIVE_APPDATA_SCOPE))

/** Google Play 服務狀態碼轉成 Flutter 可穩定處理的 Drive 授權錯誤碼。 */
internal object DriveAuthErrorCode {
    const val CONFIGURATION = "google_drive_auth_configuration"
    const val NETWORK = "google_drive_auth_network"
    const val REAUTH = "google_drive_auth_reauth"
    const val UNAVAILABLE = "google_drive_auth_unavailable"
    const val CANCELLED = "google_drive_auth_cancelled"
    const val FAILED = "google_drive_auth_failed"

    fun fromApiStatus(statusCode: Int, detail: String?): String =
        when (statusCode) {
            10 -> CONFIGURATION
            7 -> NETWORK
            16 -> REAUTH
            12500 -> UNAVAILABLE
            12501 ->
                if (isConfigurationDetail(detail)) {
                    CONFIGURATION
                } else {
                    CANCELLED
                }
            else -> FAILED
        }

    private fun isConfigurationDetail(detail: String?): Boolean {
        val normalized = detail?.lowercase().orEmpty()
        return normalized.contains("activity is cancelled by the user") ||
            normalized.contains("account reauth failed") ||
            normalized.contains("account auth failed")
    }
}
