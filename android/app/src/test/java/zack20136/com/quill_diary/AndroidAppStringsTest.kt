package zack20136.com.quill_diary

import android.content.Context
import android.content.res.Configuration
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class AndroidAppStringsTest {
    private val context get() = RuntimeEnvironment.getApplication()

    @Before
    fun setUp() {
        context.getSharedPreferences("drive_upload_localization", Context.MODE_PRIVATE)
            .edit().clear().commit()
    }

    @Test
    fun 尚未選擇語言時不受系統英文影響() {
        val localized = AndroidAppStrings.localizedContext(contextFor(Locale.ENGLISH))

        assertEquals(Locale.TAIWAN, localized.resources.configuration.locales[0])
    }

    @Test
    fun 無效語言會取代舊偏好並回退繁體中文() {
        AndroidAppStrings.setLanguageCode(context, "en")

        AndroidAppStrings.setLanguageCode(context, "ja")

        assertEquals(Locale.TAIWAN, AndroidAppStrings.localizedContext(context).resources.configuration.locales[0])
    }

    @Test
    fun 英文偏好會保存並套用至原生通知和驗證提示() {
        val chineseContext = contextFor(Locale.TAIWAN)
        val englishContext = contextFor(Locale.ENGLISH)
        AndroidAppStrings.setLanguageCode(chineseContext, " EN ")

        for (resource in listOf(R.string.drive_upload_notification_title, R.string.device_key_wrap_prompt)) {
            val actual = AndroidAppStrings.string(chineseContext, resource)
            assertEquals(englishContext.getString(resource), actual)
            assertNotEquals(chineseContext.getString(resource), actual)
        }
    }

    private fun contextFor(locale: Locale): Context =
        context.createConfigurationContext(
            Configuration(context.resources.configuration).apply { setLocale(locale) },
        )
}
