package zack20136.com.quill_diary

import android.content.Context
import android.content.res.Configuration
import androidx.annotation.StringRes
import java.util.Locale

/** 在 Flutter 尚未啟動時，原生通知仍使用 App 已選擇的語言。 */
internal object AndroidAppStrings {
    private const val PREFERENCES_NAME = "drive_upload_localization"
    private const val LANGUAGE_CODE_KEY = "language_code"
    private const val LANGUAGE_ZH = "zh"
    private const val LANGUAGE_EN = "en"

    fun setLanguageCode(context: Context, rawLanguageCode: String?): String {
        val languageCode = normalizeLanguageCode(rawLanguageCode)
        context.applicationContext
            .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(LANGUAGE_CODE_KEY, languageCode)
            .apply()
        return languageCode
    }

    private fun languageCode(context: Context): String {
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

    private fun normalizeLanguageCode(rawLanguageCode: String?): String =
        when (rawLanguageCode?.trim()?.lowercase(Locale.ROOT)) {
            LANGUAGE_EN -> LANGUAGE_EN
            else -> LANGUAGE_ZH
        }
}
