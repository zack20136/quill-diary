package zack20136.com.quill_diary.drive

import android.accounts.Account
import android.content.Context
import com.google.android.gms.auth.GoogleAuthException
import com.google.android.gms.auth.GoogleAuthUtil
import com.google.android.gms.auth.UserRecoverableAuthException
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.common.api.Scope
import java.io.IOException

class DriveAccessTokenProvider(private val context: Context) {
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

    fun currentAccountSnapshot(): Pair<String, String>? {
        val account = GoogleSignIn.getLastSignedInAccount(context) ?: return null
        if (!GoogleSignIn.hasPermissions(account, Scope(DRIVE_APPDATA_SCOPE))) {
            return null
        }
        val email = account.email?.trim().orEmpty()
        if (email.isEmpty()) {
            return null
        }
        // id 缺失時保持空字串，不要用 email 偽裝成 accountId。
        val id = account.id?.trim().orEmpty()
        return id to email
    }

    fun ensureAccountMatches(
        job: DriveUploadJob,
        token: TokenResult? = null,
    ): TokenError? {
        if (token != null) {
            return matchTokenToJob(job, token)
        }
        val snapshot = currentAccountSnapshot()
        if (snapshot == null) {
            return TokenError.NeedsUserInteraction
        }
        val (accountId, accountEmail) = snapshot
        return matchIds(job, accountId, accountEmail)
    }

    fun matchTokenToJob(job: DriveUploadJob, token: TokenResult): TokenError? =
        matchIds(job, token.accountId, token.accountEmail)

    private fun matchIds(
        job: DriveUploadJob,
        accountId: String,
        accountEmail: String,
    ): TokenError? {
        // 有 accountId 時以 ID 為準；僅在缺少 ID 時退回比較 email。
        if (job.accountId.isNotBlank()) {
            if (accountId != job.accountId) {
                return TokenError.Permanent
            }
            return null
        }
        if (!accountEmail.equals(job.accountEmail, ignoreCase = true)) {
            return TokenError.Permanent
        }
        return null
    }

    fun getAccessToken(clearCache: Boolean = false): Result<TokenResult> {
        val signedIn = GoogleSignIn.getLastSignedInAccount(context)
        if (signedIn == null ||
            !GoogleSignIn.hasPermissions(signedIn, Scope(DRIVE_APPDATA_SCOPE))
        ) {
            return Result.failure(
                TokenException(TokenError.NeedsUserInteraction),
            )
        }
        val email = signedIn.email?.trim().orEmpty()
        if (email.isEmpty() || signedIn.account == null) {
            return Result.failure(
                TokenException(TokenError.NotSignedIn),
            )
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
                    signedIn.account as Account,
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
            Result.failure(
                TokenException(TokenError.NeedsUserInteraction),
            )
        } catch (_: GoogleAuthException) {
            Result.failure(
                TokenException(
                    TokenError.Permanent,
                ),
            )
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
