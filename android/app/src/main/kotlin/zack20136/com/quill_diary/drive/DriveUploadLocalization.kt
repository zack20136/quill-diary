package zack20136.com.quill_diary.drive

import android.content.Context
import android.content.res.Configuration
import androidx.annotation.StringRes
import java.util.Locale

/** Drive 背景服務使用的 App 語言；不依賴 FlutterEngine 或系統語言。 */
object DriveUploadLocalization {
    private const val PREFERENCES_NAME = "drive_upload_localization"
    private const val LANGUAGE_CODE_KEY = "language_code"
    const val LANGUAGE_ZH = "zh"
    const val LANGUAGE_EN = "en"

    fun setLanguageCode(context: Context, rawLanguageCode: String?): String {
        val languageCode = normalizeLanguageCode(rawLanguageCode)
        context.applicationContext
            .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(LANGUAGE_CODE_KEY, languageCode)
            .apply()
        return languageCode
    }

    fun languageCode(context: Context): String {
        val stored =
            context.applicationContext
                .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getString(LANGUAGE_CODE_KEY, null)
        return normalizeLanguageCode(stored)
    }

    fun localizedContext(context: Context): Context {
        val locale =
            when (languageCode(context)) {
                LANGUAGE_EN -> Locale.ENGLISH
                else -> Locale.TAIWAN
            }
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(locale)
        return context.createConfigurationContext(configuration)
    }

    fun string(
        context: Context,
        @StringRes resourceId: Int,
        vararg arguments: Any,
    ): String = localizedContext(context).getString(resourceId, *arguments)

    fun normalizeLanguageCode(rawLanguageCode: String?): String =
        when (rawLanguageCode?.trim()?.lowercase(Locale.ROOT)) {
            LANGUAGE_EN -> LANGUAGE_EN
            LANGUAGE_ZH -> LANGUAGE_ZH
            else -> LANGUAGE_ZH
        }
}
