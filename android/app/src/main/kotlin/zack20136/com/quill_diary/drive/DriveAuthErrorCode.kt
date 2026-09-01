package zack20136.com.quill_diary.drive

/** Google Play 服務狀態碼轉成 Flutter 可穩定處理的 Drive 授權錯誤碼。 */
object DriveAuthErrorCode {
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

    fun isConfigurationDetail(detail: String?): Boolean {
        val normalized = detail?.lowercase().orEmpty()
        return normalized.contains("activity is cancelled by the user") ||
            normalized.contains("account reauth failed") ||
            normalized.contains("account auth failed")
    }
}
