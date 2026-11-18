package zack20136.com.quill_diary.drive

import org.robolectric.RuntimeEnvironment
import zack20136.com.quill_diary.AndroidKeystoreTestSupport

internal fun freshDriveUploadJobStore(): DriveUploadJobStore {
    AndroidKeystoreTestSupport.install()
    // Robolectric 每個案例有新的應用程式目錄，不能沿用前一個 store。
    DriveUploadJobStore::class.java.getDeclaredField("instance").apply {
        isAccessible = true
        set(null, null)
    }
    return DriveUploadJobStore.get(RuntimeEnvironment.getApplication())
}
