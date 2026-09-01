package zack20136.com.quill_diary.drive

import org.junit.Assert.assertEquals
import org.junit.Test

class DriveAuthErrorCodeTest {
    @Test
    fun 偽裝成取消的_12501_會回傳設定錯誤碼() {
        assertEquals(
            DriveAuthErrorCode.CONFIGURATION,
            DriveAuthErrorCode.fromApiStatus(
                12501,
                "Account reauth failed while activity is cancelled by the user",
            ),
        )
    }

    @Test
    fun 真正取消的_12501_會回傳取消錯誤碼() {
        assertEquals(
            DriveAuthErrorCode.CANCELLED,
            DriveAuthErrorCode.fromApiStatus(12501, "User canceled"),
        )
    }
}
