package zack20136.com.quill_diary

import io.flutter.plugin.common.MethodChannel

internal class CapturedChannelResult : MethodChannel.Result {
    var successCount = 0
        private set
    var value: Any? = null
        private set
    var errorCode: String? = null
        private set

    override fun success(result: Any?) {
        check(successCount == 0 && errorCode == null)
        successCount++
        value = result
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        check(successCount == 0 && this.errorCode == null)
        this.errorCode = errorCode
    }

    override fun notImplemented() {
        error("測試呼叫了未實作的通道方法")
    }
}
