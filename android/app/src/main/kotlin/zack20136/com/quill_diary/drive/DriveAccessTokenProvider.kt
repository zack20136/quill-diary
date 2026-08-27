package zack20136.com.quill_diary.drive

import android.accounts.Account
import android.content.Context
import android.content.Intent
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
        data class NeedsUserInteraction(val recoveryIntent: Intent?) : TokenError()

        data class NotSignedIn(val message: String) : TokenError()

        data class Transient(val message: String) : TokenError()

        data class Permanent(val message: String) : TokenError()
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
            return TokenError.NeedsUserInteraction(null)
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
                return TokenError.Permanent("Google 帳戶已變更，請在 App 內重新開始備份。")
            }
            return null
        }
        if (!accountEmail.equals(job.accountEmail, ignoreCase = true)) {
            return TokenError.Permanent("Google 帳戶已變更，請在 App 內重新開始備份。")
        }
        return null
    }

    fun getAccessToken(clearCache: Boolean = false): Result<TokenResult> {
        val signedIn = GoogleSignIn.getLastSignedInAccount(context)
        if (signedIn == null ||
            !GoogleSignIn.hasPermissions(signedIn, Scope(DRIVE_APPDATA_SCOPE))
        ) {
            return Result.failure(
                TokenException(TokenError.NeedsUserInteraction(null)),
            )
        }
        val email = signedIn.email?.trim().orEmpty()
        if (email.isEmpty() || signedIn.account == null) {
            return Result.failure(
                TokenException(TokenError.NotSignedIn("尚未完成 Google 帳號登入。")),
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
        } catch (error: UserRecoverableAuthException) {
            Result.failure(
                TokenException(TokenError.NeedsUserInteraction(error.intent)),
            )
        } catch (error: GoogleAuthException) {
            Result.failure(
                TokenException(
                    TokenError.Permanent(error.message ?: "Google 授權失敗。"),
                ),
            )
        } catch (error: IOException) {
            Result.failure(
                TokenException(
                    TokenError.Transient(error.message ?: "暫時無法取得授權。"),
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
