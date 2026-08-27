package zack20136.com.quill_diary.drive

import android.util.Log

/**
 * 取消上傳後盡力刪除可能殘留的 Drive 檔，失敗不拋出。
 */
object DriveRemoteFileCleanup {
    private const val TAG = "DriveRemoteFileCleanup"
    private const val FILES_API = "https://www.googleapis.com/drive/v3/files/"
    private val SAFE_FILE_ID = Regex("^[A-Za-z0-9_-]+$")

    fun bestEffortDelete(
        tokenProvider: DriveAccessTokenProvider,
        remoteFileId: String,
        httpClient: DriveResumableUploader.HttpClient = DriveResumableUploader.DefaultHttpClient(),
    ) {
        val token =
            tokenProvider.getAccessToken().getOrElse { error ->
                Log.w(TAG, "skip delete: token unavailable", error)
                return
            }
        bestEffortDelete(
            remoteFileId = remoteFileId,
            accessToken = token.accessToken,
            httpClient = httpClient,
        )
    }

    fun bestEffortDelete(
        remoteFileId: String,
        accessToken: String,
        httpClient: DriveResumableUploader.HttpClient = DriveResumableUploader.DefaultHttpClient(),
    ) {
        val fileId = remoteFileId.trim()
        if (!isSafeFileId(fileId) || accessToken.isBlank()) {
            return
        }
        runCatching {
            val response =
                httpClient.execute(
                    DriveResumableUploader.HttpRequest(
                        method = "DELETE",
                        url = FILES_API + fileId,
                        headers = mapOf("Authorization" to "Bearer $accessToken"),
                    ),
                )
            if (response.code !in 200..299 && response.code != 404) {
                Log.w(TAG, "delete remote file HTTP ${response.code}")
            }
        }.onFailure { error ->
            Log.w(TAG, "delete remote file failed", error)
        }
    }

    private fun isSafeFileId(fileId: String): Boolean =
        fileId.isNotEmpty() && SAFE_FILE_ID.matches(fileId)
}
