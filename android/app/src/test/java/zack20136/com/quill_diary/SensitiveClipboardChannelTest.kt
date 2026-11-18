package zack20136.com.quill_diary

import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class SensitiveClipboardChannelTest {
    @Test
    fun 複製文字保留內容並附加敏感標記() {
        val context = RuntimeEnvironment.getApplication()
        SensitiveClipboardChannel.copy(context, "0123-4567")
        val clip = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        assertEquals("0123-4567", clip.primaryClip!!.getItemAt(0).text.toString())
        assertTrue(clip.primaryClipDescription!!.extras!!.getBoolean(ClipDescription.EXTRA_IS_SENSITIVE))
    }
}
