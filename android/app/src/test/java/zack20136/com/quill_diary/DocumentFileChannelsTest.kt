package zack20136.com.quill_diary

import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ResolveInfo
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import java.io.File
import java.io.IOException
import java.io.InputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class DocumentFileChannelsTest {
    @Test
    fun 取消選擇資料夾會回傳空值並允許重選() {
        Robolectric.buildActivity(Activity::class.java).setup().use { controller ->
            val activity = controller.get()
            val chooser = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addCategory(Intent.CATEGORY_DEFAULT)
            shadowOf(activity.packageManager).addResolveInfoForIntent(
                chooser,
                ResolveInfo().apply {
                    activityInfo = ActivityInfo().apply {
                        packageName = activity.packageName
                        name = "android.app.Activity"
                    }
                },
            )
            val channels = DocumentFileChannels(activity)
            val call = MethodCall("pickWritableDirectoryTree", null)

            val cancelled = CapturedChannelResult()
            channels.pickWritableDirectoryTree(call, cancelled)
            val started = shadowOf(activity).nextStartedActivityForResult
            assertEquals(DocumentFileChannels.DIRECTORY_REQUEST_CODE, started.requestCode)
            channels.onDirectoryResult(Activity.RESULT_CANCELED, null)
            assertEquals(1, cancelled.successCount)
            assertNull(cancelled.value)

            val selected = CapturedChannelResult()
            val uri = Uri.parse("content://test/tree/backup")
            channels.pickWritableDirectoryTree(call, selected)
            channels.onDirectoryResult(Activity.RESULT_OK, Intent().setData(uri))
            assertEquals(uri.toString(), selected.value)
        }
    }

    @Test
    fun URI串流中斷會清除已寫入的半成品() {
        Robolectric.buildActivity(Activity::class.java).setup().use { controller ->
            val activity = controller.get()
            val source = Uri.parse("content://test/entry")
            val destination = File(activity.cacheDir, "backup.zip")
            var copiedFirstByte = false
            var closed = false
            shadowOf(activity.contentResolver).registerInputStream(source, object : InputStream() {
                override fun read(): Int {
                    if (copiedFirstByte) throw IOException("測試串流中斷")
                    assertTrue(destination.isFile)
                    copiedFirstByte = true
                    return 42
                }

                override fun close() {
                    closed = true
                }
            })
            val result = CapturedChannelResult()
            DocumentFileChannels(activity).copyUriToPath(
                MethodCall(
                    "copyUriToPath",
                    mapOf("sourceUri" to source.toString(), "destinationPath" to destination.path),
                ),
                result,
            )

            assertTrue(copiedFirstByte)
            assertTrue(closed)
            assertEquals("copy_failed", result.errorCode)
            assertFalse(destination.exists())
        }
    }
}
