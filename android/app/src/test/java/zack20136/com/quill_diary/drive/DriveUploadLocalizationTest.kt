package zack20136.com.quill_diary.drive

import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import zack20136.com.quill_diary.R

@RunWith(RobolectricTestRunner::class)
class DriveUploadLocalizationTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        context
            .getSharedPreferences("drive_upload_localization", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    @Test
    fun 未設定語言時回退繁體中文() {
        assertEquals(DriveUploadLocalization.LANGUAGE_ZH, DriveUploadLocalization.languageCode(context))
        assertEquals(
            "Google Drive 備份",
            DriveUploadLocalization.string(context, R.string.drive_upload_notification_title),
        )
    }

    @Test
    fun 非法語言回退繁體中文() {
        assertEquals(
            DriveUploadLocalization.LANGUAGE_ZH,
            DriveUploadLocalization.setLanguageCode(context, "ja"),
        )
        assertEquals(
            "上傳發生未預期錯誤。",
            DriveUploadLocalization.string(context, R.string.drive_upload_error_unexpected),
        )
    }

    @Test
    fun 英文語言會保存並讀取英文資源() {
        assertEquals(
            DriveUploadLocalization.LANGUAGE_EN,
            DriveUploadLocalization.setLanguageCode(context, "en"),
        )
        assertEquals(DriveUploadLocalization.LANGUAGE_EN, DriveUploadLocalization.languageCode(context))
        assertEquals(
            "Google Drive backup",
            DriveUploadLocalization.string(context, R.string.drive_upload_notification_title),
        )
    }
}
