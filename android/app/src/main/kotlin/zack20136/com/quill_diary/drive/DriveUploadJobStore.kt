package zack20136.com.quill_diary.drive

import android.content.Context
import android.util.AtomicFile
import android.util.Base64
import org.json.JSONObject
import java.io.File
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.MessageDigest
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * 原子持久化上傳工作；session URI 以 Android Keystore 加密後另存。
 * 同一 process 共用單一實例，避免 Service／Bridge 各建一份導致寫入競態。
 *
 * 失敗、取消與完成都以刪除 job 表達；failure notice 另存供 App 提示。
 */
class DriveUploadJobStore private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val jobsDir: File =
        File(appContext.filesDir, "quill_diary/drive_upload_jobs").apply {
            mkdirs()
        }
    private val sessionStore =
        appContext.getSharedPreferences(SESSION_PREFS, Context.MODE_PRIVATE)
    private val lock = Any()

    fun readActiveJob(): DriveUploadJob? =
        synchronized(lock) {
            readActiveJobLocked()
        }

    fun readJob(jobId: String): DriveUploadJob? =
        synchronized(lock) {
            readJobLocked(jobId)
        }

    /** 無衝突時原子建立新工作；已有 active job 時回傳 null。 */
    fun createJobIfNoConflict(job: DriveUploadJob): DriveUploadJob? =
        synchronized(lock) {
            if (!isValidJobId(job.jobId)) {
                return null
            }
            if (readActiveJobLocked() != null) {
                return null
            }
            return persistLocked(
                job = job.copy(generation = 0L),
                expectedGeneration = null,
                mode = WriteMode.Create,
            )
        }

    /** CAS 更新；generation 不符或工作已刪時回傳 null。 */
    fun updateJobCas(
        job: DriveUploadJob,
        expectedGeneration: Long,
        durability: Durability = Durability.Critical,
    ): DriveUploadJob? =
        synchronized(lock) {
            persistLocked(
                job = job,
                expectedGeneration = expectedGeneration,
                mode = WriteMode.Cas,
                durability = durability,
            )
        }

    /**
     * 取消並清除 staging／session／job。
     * 已進入 STATUS_PENDING／PRUNE_PENDING 時拒絕。
     */
    fun cancelAndCleanup(jobId: String): DriveUploadJob? =
        synchronized(lock) {
            val existing = readJobLocked(jobId) ?: return null
            if (existing.isRemoteCommittedPhase()) {
                return null
            }
            cleanupStagingLocked(existing)
            deleteJobLocked(existing.jobId)
            return existing
        }

    /**
     * 終止未提交工作並寫入 failure notice。
     * 已進入 STATUS_PENDING／PRUNE_PENDING 時拒絕。
     */
    fun failAndCleanup(
        jobId: String,
        errorCode: String,
        message: String,
    ): DriveUploadJob? =
        synchronized(lock) {
            val existing = readJobLocked(jobId) ?: return null
            if (existing.isRemoteCommittedPhase()) {
                return null
            }
            val failed =
                existing.copy(
                    lastErrorCode = errorCode,
                    lastErrorMessage = message,
                )
            cleanupStagingLocked(failed)
            writeFailureNoticeLocked(
                DriveUploadFailureNotice(
                    jobId = failed.jobId,
                    message = message.ifBlank { "上次 Google Drive 備份未完成，已取消。請重新備份。" },
                ),
            )
            deleteJobLocked(failed.jobId)
            return failed
        }

    /** 讀取失敗提示；不清除，需使用者 ack。 */
    fun readFailureNotice(): DriveUploadFailureNotice? =
        synchronized(lock) {
            readFailureNoticeLocked()
        }

    fun ackFailure(jobId: String): Boolean =
        synchronized(lock) {
            val existing = readFailureNoticeLocked() ?: return false
            if (existing.jobId != jobId) {
                return false
            }
            sessionStore.edit().remove(FAILURE_NOTICE_KEY).commit()
            return true
        }

    fun markStatusRecorded(jobId: String): DriveUploadJob? =
        synchronized(lock) {
            val existing = readJobLocked(jobId) ?: return null
            if (existing.phase != DriveUploadPhase.STATUS_PENDING) {
                return null
            }
            return persistLocked(
                job = existing.copy(phase = DriveUploadPhase.PRUNE_PENDING),
                expectedGeneration = existing.generation,
                mode = WriteMode.Cas,
            )
        }

    /** 僅 PRUNE_PENDING 可 finalize；刪 staging 與 job。 */
    fun finalizeCommitted(jobId: String): DriveUploadJob? =
        synchronized(lock) {
            val existing = readJobLocked(jobId) ?: return null
            if (existing.phase != DriveUploadPhase.PRUNE_PENDING) {
                return null
            }
            cleanupStagingLocked(existing)
            deleteJobLocked(existing.jobId)
            return existing
        }

    fun getStateEnvelope(): Map<String, Any?> =
        synchronized(lock) {
            mapOf(
                "job" to readActiveJobLocked()?.toMap(),
                "failure" to readFailureNoticeLocked()?.toMap(),
            )
        }

    fun readSessionUri(jobId: String): String? {
        if (!isValidJobId(jobId)) {
            return null
        }
        val encoded = sessionStore.getString(sessionKey(jobId), null) ?: return null
        val decrypted = decrypt(encoded) ?: return null
        if (!DriveResumableUploader.isAllowedUploadLocation(decrypted)) {
            clearSessionUri(jobId)
            return null
        }
        return decrypted
    }

    fun writeSessionUri(jobId: String, sessionUri: String) {
        if (!isValidJobId(jobId)) {
            return
        }
        if (!DriveResumableUploader.isAllowedUploadLocation(sessionUri)) {
            return
        }
        sessionStore
            .edit()
            .putString(sessionKey(jobId), encrypt(sessionUri))
            .commit()
    }

    fun clearSessionUri(jobId: String) {
        if (!isValidJobId(jobId)) {
            return
        }
        sessionStore.edit().remove(sessionKey(jobId)).commit()
    }

    fun stagingRoot(): File =
        File(appContext.filesDir, "quill_diary/drive_upload_staging").apply {
            mkdirs()
        }

    fun isInsideStagingRoot(path: String): Boolean {
        val file = File(path)
        val root = stagingRoot().canonicalFile
        val canonical = runCatching { file.canonicalFile }.getOrNull() ?: return false
        return canonical.path == root.path ||
            canonical.path.startsWith(root.path + File.separator)
    }

    /** 清除沒有對應工作引用的 staging／partial。 */
    fun cleanupOrphanStaging() {
        val root = stagingRoot()
        val referenced =
            synchronized(lock) {
                listJobBaseFiles().mapNotNull { file ->
                    runCatching { readJobFile(file)?.stagingPath }.getOrNull()
                }.mapNotNull { path ->
                    runCatching { File(path).canonicalPath }.getOrNull()
                }.toSet()
            }
        root.listFiles()?.forEach { file ->
            if (!file.isFile) {
                return@forEach
            }
            val canonical = runCatching { file.canonicalPath }.getOrNull() ?: return@forEach
            if (file.name.endsWith(".partial") || !referenced.contains(canonical)) {
                file.delete()
            }
        }
    }

    /**
     * 冷啟動：若有未提交的殘留工作且 FGS 未在跑，視為程序中斷並清理。
     * 已 STATUS_PENDING／PRUNE_PENDING 則保留給 App 收尾。
     */
    fun abandonUncommittedIfPresent(message: String): DriveUploadJob? =
        synchronized(lock) {
            val existing = readActiveJobLocked() ?: return null
            if (existing.isRemoteCommittedPhase()) {
                return null
            }
            cleanupStagingLocked(existing)
            writeFailureNoticeLocked(
                DriveUploadFailureNotice(
                    jobId = existing.jobId,
                    message = message,
                ),
            )
            deleteJobLocked(existing.jobId)
            return existing
        }

    private fun readActiveJobLocked(): DriveUploadJob? {
        val jobs =
            listJobBaseFiles().mapNotNull { file ->
                runCatching { readJobFile(file) }.getOrNull()
            }
        return jobs.maxByOrNull { it.updatedAtEpochMs }
    }

    /** 含僅剩 `.json.bak` 的 AtomicFile 工作。 */
    private fun listJobBaseFiles(): List<File> {
        val files = jobsDir.listFiles() ?: return emptyList()
        val bases = linkedSetOf<String>()
        for (file in files) {
            if (!file.isFile) {
                continue
            }
            val name = file.name
            when {
                name.endsWith(".json.bak") -> bases.add(name.removeSuffix(".bak"))
                name.endsWith(".json") && !name.endsWith(".tmp") -> bases.add(name)
            }
        }
        return bases.map { File(jobsDir, it) }
    }

    private fun readJobLocked(jobId: String): DriveUploadJob? {
        if (!isValidJobId(jobId)) {
            return null
        }
        return runCatching { readJobFile(jobFile(jobId)) }.getOrNull()
    }

    private fun persistLocked(
        job: DriveUploadJob,
        expectedGeneration: Long?,
        mode: WriteMode,
        durability: Durability = Durability.Critical,
    ): DriveUploadJob? {
        if (!isValidJobId(job.jobId)) {
            return null
        }
        val existing = readJobLocked(job.jobId)
        when (mode) {
            WriteMode.Create -> {
                if (existing != null) {
                    return null
                }
            }
            WriteMode.Cas -> {
                if (expectedGeneration == null || existing?.generation != expectedGeneration) {
                    return null
                }
            }
        }
        val nextGeneration =
            when (mode) {
                WriteMode.Create -> 1L
                WriteMode.Cas -> (existing?.generation ?: job.generation) + 1L
            }
        val updated =
            job.copy(
                generation = nextGeneration,
                updatedAtEpochMs = System.currentTimeMillis(),
            )
        val target = jobFile(updated.jobId)
        val atomic = AtomicFile(target)
        val json = JSONObject()
        updated.toMap().forEach { (key, value) ->
            if (value == null) {
                json.put(key, JSONObject.NULL)
            } else {
                json.put(key, value)
            }
        }
        val bytes = json.toString().toByteArray(StandardCharsets.UTF_8)
        var stream: java.io.FileOutputStream? = null
        try {
            stream = atomic.startWrite()
            stream.write(bytes)
            stream.flush()
            if (durability == Durability.Critical) {
                stream.fd.sync()
            }
            atomic.finishWrite(stream)
            stream = null
        } catch (error: Throwable) {
            if (stream != null) {
                atomic.failWrite(stream)
            }
            throw error
        }
        return updated
    }

    private fun cleanupStagingLocked(job: DriveUploadJob) {
        if (isInsideStagingRoot(job.stagingPath)) {
            runCatching { File(job.stagingPath).delete() }
        }
        clearSessionUri(job.jobId)
    }

    private fun deleteJobLocked(jobId: String) {
        if (!isValidJobId(jobId)) {
            return
        }
        AtomicFile(jobFile(jobId)).delete()
        clearSessionUri(jobId)
    }

    private fun jobFile(jobId: String): File {
        require(isValidJobId(jobId)) { "invalid jobId" }
        return File(jobsDir, "$jobId.json")
    }

    private fun readJobFile(file: File): DriveUploadJob? {
        val atomic = AtomicFile(file)
        val bytes = atomic.readFully()
        val json = JSONObject(String(bytes, StandardCharsets.UTF_8))
        val map = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.opt(key)
            map[key] = if (value == JSONObject.NULL) null else value
        }
        return DriveUploadJob.fromMap(map)
    }

    private fun readFailureNoticeLocked(): DriveUploadFailureNotice? {
        val encoded = sessionStore.getString(FAILURE_NOTICE_KEY, null) ?: return null
        return runCatching {
            val json = JSONObject(encoded)
            val map = mutableMapOf<String, Any?>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val value = json.opt(key)
                map[key] = if (value == JSONObject.NULL) null else value
            }
            DriveUploadFailureNotice.fromMap(map)
        }.getOrNull()
    }

    private fun writeFailureNoticeLocked(notice: DriveUploadFailureNotice) {
        val json =
            JSONObject()
                .put("jobId", notice.jobId)
                .put("message", notice.message)
        sessionStore.edit().putString(FAILURE_NOTICE_KEY, json.toString()).commit()
    }

    private fun sessionKey(jobId: String): String = "session_$jobId"

    private fun encrypt(plain: String): String {
        val key = getOrCreateKey()
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val iv = cipher.iv
        val encrypted = cipher.doFinal(plain.toByteArray(StandardCharsets.UTF_8))
        val payload = ByteArray(iv.size + encrypted.size)
        System.arraycopy(iv, 0, payload, 0, iv.size)
        System.arraycopy(encrypted, 0, payload, iv.size, encrypted.size)
        return Base64.encodeToString(payload, Base64.NO_WRAP)
    }

    private fun decrypt(encoded: String): String? {
        return runCatching {
            val payload = Base64.decode(encoded, Base64.NO_WRAP)
            if (payload.size <= IV_SIZE) {
                return null
            }
            val iv = payload.copyOfRange(0, IV_SIZE)
            val cipherBytes = payload.copyOfRange(IV_SIZE, payload.size)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(cipherBytes), StandardCharsets.UTF_8)
        }.getOrNull()
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) {
            return existing.secretKey
        }
        val generator = KeyGenerator.getInstance("AES", ANDROID_KEYSTORE)
        val spec =
            android.security.keystore.KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or
                    android.security.keystore.KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(
                    android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE,
                )
                .setKeySize(256)
                .build()
        generator.init(spec)
        return generator.generateKey()
    }

    enum class Durability {
        /**
         * 進度寫入：AtomicFile 換檔（finishWrite 仍可能 sync），
         * 略過額外 fd.sync；可用 probe 校正。
         */
        Progress,

        /** 關鍵狀態：AtomicFile 換檔前再顯式 fsync。 */
        Critical,
    }

    private enum class WriteMode {
        Create,
        Cas,
    }

    companion object {
        private const val SESSION_PREFS = "quill_diary_drive_upload_sessions"
        private const val FAILURE_NOTICE_KEY = "upload_failure_notice"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "quill_diary_drive_upload_session"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_SIZE = 12
        private val JOB_ID_PATTERN =
            Regex(
                "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
            )

        @Volatile
        private var instance: DriveUploadJobStore? = null

        fun get(context: Context): DriveUploadJobStore {
            val existing = instance
            if (existing != null) {
                return existing
            }
            return synchronized(this) {
                instance ?: DriveUploadJobStore(context.applicationContext).also {
                    instance = it
                }
            }
        }

        fun isValidJobId(jobId: String): Boolean {
            val trimmed = jobId.trim()
            if (trimmed.isEmpty()) {
                return false
            }
            if (trimmed.contains('/') || trimmed.contains('\\') || trimmed.contains("..")) {
                return false
            }
            return JOB_ID_PATTERN.matches(trimmed)
        }

        fun sanitizeFileName(fileName: String): String? {
            val base = File(fileName.trim()).name
            if (base.isBlank() || base == "." || base == "..") {
                return null
            }
            if (base.contains('/') || base.contains('\\')) {
                return null
            }
            return base
        }

        fun md5Hex(file: File): String {
            val digest = MessageDigest.getInstance("MD5")
            file.inputStream().use { input ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) {
                        break
                    }
                    digest.update(buffer, 0, read)
                }
            }
            return digest.digest().joinToString("") { byte ->
                "%02x".format(byte)
            }
        }

        fun newJobId(): String = UUID.randomUUID().toString()
    }
}
