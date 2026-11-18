package zack20136.com.quill_diary.drive

import android.content.Context
import android.util.AtomicFile
import android.util.Base64
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.MessageDigest
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import zack20136.com.quill_diary.AndroidAppStrings
import zack20136.com.quill_diary.R

/**
 * 原子持久化上傳工作；session URI 以 Android Keystore 加密後另存。
 * 上傳服務和通道共用同一把鎖。
 */
internal class DriveUploadJobStore private constructor(context: Context) {
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

    /** 已在遠端完成的備份必須交給成功流程收尾。 */
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

    fun markCancelCleanupPending(jobId: String): DriveUploadJob? =
        synchronized(lock) {
            val existing = readJobLocked(jobId) ?: return null
            if (existing.isRemoteCommittedPhase()) {
                return null
            }
            if (existing.isCancelCleanupPhase()) {
                return existing
            }
            return persistLocked(
                job = existing.copy(phase = DriveUploadPhase.CANCEL_CLEANUP_PENDING),
                expectedGeneration = existing.generation,
                mode = WriteMode.Cas,
            )
        }

    /** 已開始取消對帳的工作仍要保留遠端清理資訊。 */
    fun recordUploadFailure(
        jobId: String,
        errorCode: String,
        message: String,
    ): DriveUploadJob? =
        synchronized(lock) {
            val existing = readJobLocked(jobId) ?: return null
            if (existing.isRemoteCommittedPhase() || existing.isCancelCleanupPhase()) {
                return null
            }
            val failed = existing.copy(lastErrorCode = errorCode)
            val needsRemoteCleanup =
                existing.remoteFileId.isNotBlank() ||
                    existing.confirmedOffset > 0L ||
                    sessionStore.contains(sessionKey(jobId))
            val pending =
                if (needsRemoteCleanup) {
                    persistLocked(
                        job = failed.copy(phase = DriveUploadPhase.CANCEL_CLEANUP_PENDING),
                        expectedGeneration = existing.generation,
                        mode = WriteMode.Cas,
                    ) ?: return null
                } else {
                    null
                }
            writeFailureNoticeLocked(
                DriveUploadFailureNotice(
                    jobId = failed.jobId,
                    message =
                        message.ifBlank {
                            AndroidAppStrings.string(
                                appContext,
                                R.string.drive_upload_failure_default,
                            )
                        },
                ),
            )
            if (pending == null) {
                cleanupStagingLocked(failed)
                deleteJobLocked(jobId)
            }
            return pending ?: failed
        }

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
        return canonical.path.startsWith(root.path + File.separator)
    }

    fun cleanupAbandonedUploadFiles() {
        synchronized(lock) {
            val committedJobFiles = listJobBaseFiles() ?: return
            val referenced = mutableSetOf<String>()
            for (file in committedJobFiles) {
                // 讀不到已提交的工作時，無法判斷哪份暫存仍有用途。
                val job = runCatching { readJobFile(file) }.getOrNull() ?: return
                if (job.stagingPath.isBlank() || !isInsideStagingRoot(job.stagingPath)) return
                val path = runCatching { File(job.stagingPath).canonicalPath }.getOrNull() ?: return
                referenced.add(path)
            }
            stagingRoot().listFiles()?.forEach { file ->
                val path = runCatching { file.canonicalPath }.getOrNull() ?: return@forEach
                if (file.isFile && isInsideStagingRoot(path) && path !in referenced) {
                    file.delete()
                }
            }
            val committedNames = committedJobFiles.map { it.name }.toSet()
            jobsDir.listFiles()?.forEach { file ->
                val baseName = file.name.removeSuffix(".new")
                if (file.isFile &&
                    file.name.endsWith(".json.new") &&
                    isValidJobId(baseName.removeSuffix(".json")) &&
                    baseName !in committedNames
                ) {
                    file.delete()
                }
            }
            val orphanedSessions = sessionStore.all.keys.filter { key ->
                val id = key.removePrefix("session_")
                id != key && isValidJobId(id) && "$id.json" !in committedNames
            }
            if (orphanedSessions.isNotEmpty()) {
                val editor = sessionStore.edit()
                orphanedSessions.forEach(editor::remove)
                editor.commit()
            }
        }
    }

    private fun readActiveJobLocked(): DriveUploadJob? {
        val jobs =
            listJobBaseFiles().orEmpty().mapNotNull { file ->
                runCatching { readJobFile(file) }.getOrNull()
            }
        return jobs.maxByOrNull { it.updatedAtEpochMs }
    }

    /** 含僅剩 `.json.bak` 的 AtomicFile 工作。 */
    private fun listJobBaseFiles(): List<File>? {
        val files = jobsDir.listFiles() ?: return null
        val bases = linkedSetOf<String>()
        for (file in files) {
            if (!file.isFile) {
                continue
            }
            val name = file.name
            when {
                name.endsWith(".json.bak") -> bases.add(name.removeSuffix(".bak"))
                name.endsWith(".json") -> bases.add(name)
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
                // 取消清理中只接受錯誤更新或遠端驗證成功，不能恢復上傳或改動內容。
                if (existing.isCancelCleanupPhase() &&
                    job.phase != DriveUploadPhase.STATUS_PENDING &&
                    job.copy(lastErrorCode = existing.lastErrorCode) != existing
                ) {
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
        val bytes = updated.toMap().toDriveJson().toString().toByteArray(StandardCharsets.UTF_8)
        var stream: FileOutputStream? = null
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
            val partial = "${job.stagingPath}.partial"
            if (isInsideStagingRoot(partial)) {
                runCatching { File(partial).delete() }
            }
        }
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
        return DriveUploadJob.fromMap(json.toDriveMap())?.takeIf {
            it.jobId == file.nameWithoutExtension && it.schemaVersion == DriveUploadJob.SCHEMA_VERSION
        }
    }

    private fun readFailureNoticeLocked(): DriveUploadFailureNotice? {
        val encoded = sessionStore.getString(FAILURE_NOTICE_KEY, null) ?: return null
        return runCatching {
            DriveUploadFailureNotice.fromMap(JSONObject(encoded).toDriveMap())?.let { notice ->
                if (notice.message.isBlank()) {
                    notice.copy(
                        message =
                            AndroidAppStrings.string(
                                appContext,
                                R.string.drive_upload_failure_default,
                            ),
                    )
                } else {
                    notice
                }
            }
        }.getOrNull()
    }

    private fun writeFailureNoticeLocked(notice: DriveUploadFailureNotice) {
        val json = notice.toMap().toDriveJson()
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
        /** 進度可由伺服器校正，略過額外的檔案同步。 */
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

private fun JSONObject.toDriveMap(): Map<String, Any?> =
    keys().asSequence().associateWith { key -> opt(key).takeUnless { it === JSONObject.NULL } }

private fun Map<String, Any?>.toDriveJson(): JSONObject =
    JSONObject().also { json ->
        for ((key, value) in this) {
            json.put(
                key,
                when (value) {
                    null -> JSONObject.NULL
                    is Map<*, *> -> JSONObject(value)
                    else -> value
                },
            )
        }
    }
