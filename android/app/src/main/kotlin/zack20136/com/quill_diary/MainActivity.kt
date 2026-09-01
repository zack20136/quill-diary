package zack20136.com.quill_diary

import android.Manifest
import android.app.KeyguardManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import zack20136.com.quill_diary.drive.BackupUploadForegroundService
import zack20136.com.quill_diary.drive.DriveAuthErrorCode
import zack20136.com.quill_diary.drive.DriveUploadBridge
import zack20136.com.quill_diary.drive.DriveUploadLocalization

class MainActivity : FlutterFragmentActivity() {
    private var pendingGoogleDriveAuthResult: MethodChannel.Result? = null
    private var pendingDirectoryPickerResult: MethodChannel.Result? = null
    private var googleDriveSignInClient: GoogleSignInClient? = null
    private var pendingOpenDriveBackup: Boolean = false

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            DriveUploadBridge.completeNotificationPermission(granted)
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EasyDiaryRealmChannel.register(flutterEngine, applicationContext)
        MediaStoreExportChannel.register(flutterEngine, applicationContext)
        DriveUploadBridge.attachActivity(this)
        DriveUploadBridge.register(flutterEngine, this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OAUTH_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getServerClientId" -> {
                    val id = getString(R.string.oauth_request_id_token).trim()
                    result.success(if (id.isEmpty()) null else id)
                }
                "signInGoogleDrive" -> signInGoogleDrive(call, result)
                "getGoogleDriveConnectionSnapshot" -> getGoogleDriveConnectionSnapshot(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_KEY_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "ensureKey" -> result.success(ensureKey(call))
                    "hasKey" -> result.success(hasKey(call))
                    "canUseDeviceCredential" -> result.success(canUseDeviceCredential())
                    "canUseBiometric" -> result.success(canUseBiometric())
                    "getDeviceAuthCapabilities" -> result.success(getDeviceAuthCapabilities())
                    "purgeInactiveDeviceKeys" -> {
                        purgeInactiveDeviceKeys(call)
                        result.success(null)
                    }
                    "wrapWithDeviceKey" -> wrapWithDeviceKey(call, result)
                    "unwrapWithDeviceKey" -> unwrapWithDeviceKey(call, result)
                    "rewrapTrustedRecoveryKey" -> rewrapTrustedRecoveryKey(call, result)
                    "deleteKey" -> {
                        deleteKey(call)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                completeDeviceKeyError(result, error)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SAF_FILE_COPY_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "copyFileToTree" -> copyFileToSafTree(call, result)
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "saf_file_copy_error",
                    error.message ?: "Unknown SAF file copy error.",
                    null,
                )
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DIRECTORY_PICKER_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "pickWritableDirectoryTree" -> pickWritableDirectoryTree(call, result)
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "directory_picker_error",
                    error.message ?: "Unknown directory picker error.",
                    null,
                )
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONTENT_URI_IMPORT_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "copyUriToPath" -> copyUriToPath(call, result)
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "content_uri_import_error",
                    error.message ?: "Unknown content URI import error.",
                    null,
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureOpenDriveBackupExtra(intent)
    }

    override fun onResume() {
        super.onResume()
        DriveUploadBridge.attachActivity(this)
        captureOpenDriveBackupExtra(intent)
    }

    override fun onDestroy() {
        DriveUploadBridge.detachActivity(this)
        super.onDestroy()
    }

    /** 回傳 false 表示無法發起請求（例如 Activity 已結束）。 */
    fun launchNotificationPermissionRequest(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            DriveUploadBridge.completeNotificationPermission(true)
            return true
        }
        if (isFinishing || isDestroyed) {
            return false
        }
        return try {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            true
        } catch (_: Throwable) {
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == GOOGLE_DRIVE_SIGN_IN_REQUEST_CODE) {
            handleGoogleDriveSignInResult(data)
            return
        }
        if (requestCode == DIRECTORY_PICK_REQUEST_CODE) {
            handleDirectoryPickerResult(resultCode, data)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    fun consumeOpenDriveBackupRequest(): Boolean {
        val pending = pendingOpenDriveBackup
        pendingOpenDriveBackup = false
        return pending
    }

    private fun captureOpenDriveBackupExtra(intent: Intent?) {
        if (intent?.getBooleanExtra(
                BackupUploadForegroundService.EXTRA_OPEN_DRIVE_BACKUP,
                false,
            ) == true
        ) {
            pendingOpenDriveBackup = true
            intent.removeExtra(BackupUploadForegroundService.EXTRA_OPEN_DRIVE_BACKUP)
        }
    }

    private fun pickWritableDirectoryTree(call: MethodCall, result: MethodChannel.Result) {
        if (pendingDirectoryPickerResult != null) {
            result.error(
                "directory_picker_in_progress",
                "資料夾選擇進行中，請稍候。",
                null,
            )
            return
        }

        val prompt = call.argument<String>("prompt")?.trim().orEmpty()
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addCategory(Intent.CATEGORY_DEFAULT)
            if (prompt.isNotEmpty()) {
                putExtra(DocumentsContract.EXTRA_PROMPT, prompt)
            }
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        }
        if (intent.resolveActivity(packageManager) == null) {
            result.error("directory_picker_unavailable", "此裝置無法開啟資料夾選擇器。", null)
            return
        }

        pendingDirectoryPickerResult = result
        startActivityForResult(intent, DIRECTORY_PICK_REQUEST_CODE)
    }

    private fun handleDirectoryPickerResult(resultCode: Int, data: Intent?) {
        val pending = pendingDirectoryPickerResult
        pendingDirectoryPickerResult = null
        if (pending == null) {
            return
        }

        if (resultCode != RESULT_OK || data?.data == null) {
            pending.success(null)
            return
        }

        // OPEN_DOCUMENT_TREE 回傳的 URI 已含本次工作階段的讀寫授權，無需 takePersistableUriPermission。
        pending.success(data.data!!.toString())
    }

    private fun getGoogleDriveConnectionSnapshot(result: MethodChannel.Result) {
        val account = GoogleSignIn.getLastSignedInAccount(this)
        if (account != null && hasDriveAppDataPermission(account)) {
            result.success(googleDriveAccountPayload(account))
            return
        }
        result.success(null)
    }

    private fun signInGoogleDrive(call: MethodCall, result: MethodChannel.Result) {
        if (pendingGoogleDriveAuthResult != null) {
            result.error(
                "google_drive_auth_in_progress",
                driveString(R.string.drive_auth_in_progress),
                null,
            )
            return
        }

        val serverClientId = requireString(call, "serverClientId")
        val resetSession = call.argument<Boolean>("resetSession") ?: false
        val signInClient = createGoogleDriveSignInClient(serverClientId)
        googleDriveSignInClient = signInClient

        if (!resetSession) {
            val existingAccount = GoogleSignIn.getLastSignedInAccount(this)
            if (existingAccount != null && hasDriveAppDataPermission(existingAccount)) {
                result.success(googleDriveAccountPayload(existingAccount))
                return
            }
        }

        pendingGoogleDriveAuthResult = result
        if (resetSession) {
            signInClient.revokeAccess().addOnCompleteListener {
                signInClient.signOut().addOnCompleteListener {
                    launchGoogleDriveSignIn(signInClient)
                }
            }
        } else {
            launchGoogleDriveSignIn(signInClient)
        }
    }

    private fun createGoogleDriveSignInClient(serverClientId: String): GoogleSignInClient {
        val signInOptions =
            GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestEmail()
                .requestIdToken(serverClientId)
                .requestScopes(Scope(GOOGLE_DRIVE_APPDATA_SCOPE))
                .build()
        return GoogleSignIn.getClient(this, signInOptions)
    }

    private fun launchGoogleDriveSignIn(signInClient: GoogleSignInClient) {
        startActivityForResult(signInClient.signInIntent, GOOGLE_DRIVE_SIGN_IN_REQUEST_CODE)
    }

    private fun handleGoogleDriveSignInResult(data: Intent?) {
        val pendingResult = pendingGoogleDriveAuthResult ?: return
        pendingGoogleDriveAuthResult = null
        try {
            val account = GoogleSignIn.getSignedInAccountFromIntent(data)
                .getResult(ApiException::class.java)
                ?: run {
                    pendingResult.error(
                        "google_drive_account_missing",
                        driveString(R.string.drive_auth_account_missing),
                        null,
                    )
                    return
                }
            if (!hasDriveAppDataPermission(account)) {
                pendingResult.error(
                    "google_drive_scope_missing",
                    driveString(R.string.drive_auth_scope_missing),
                    null,
                )
                return
            }
            pendingResult.success(googleDriveAccountPayload(account))
        } catch (error: ApiException) {
            Log.e(TAG, "Google Drive sign-in failed with status ${error.statusCode}.", error)
            pendingResult.error(
                googleDriveAuthErrorCode(error.statusCode, error.localizedMessage),
                googleDriveAuthErrorMessage(error),
                null,
            )
        } catch (error: Throwable) {
            Log.e(TAG, "Google Drive sign-in failed.", error)
            pendingResult.error(
                "google_drive_auth_failed",
                driveString(R.string.drive_auth_failed),
                null,
            )
        }
    }

    private fun hasDriveAppDataPermission(account: GoogleSignInAccount): Boolean {
        return GoogleSignIn.hasPermissions(account, Scope(GOOGLE_DRIVE_APPDATA_SCOPE))
    }

    private fun googleDriveAccountPayload(account: GoogleSignInAccount): Map<String, Any?> {
        return mapOf(
            "email" to account.email,
            "displayName" to account.displayName,
        )
    }

    private fun googleDriveAuthErrorMessage(error: ApiException): String {
        val detail = error.localizedMessage?.trim()
        return when (googleDriveAuthErrorCode(error.statusCode, detail)) {
            DriveAuthErrorCode.CONFIGURATION ->
                driveString(R.string.drive_auth_configuration_error)
            DriveAuthErrorCode.NETWORK -> driveString(R.string.drive_auth_network_error)
            DriveAuthErrorCode.REAUTH -> driveString(R.string.drive_auth_reauth_error)
            DriveAuthErrorCode.UNAVAILABLE -> driveString(R.string.drive_auth_unavailable)
            DriveAuthErrorCode.CANCELLED -> driveString(R.string.drive_auth_cancelled)
            else -> driveString(R.string.drive_auth_failed)
        }
    }

    private fun googleDriveAuthErrorCode(statusCode: Int, detail: String?): String =
        DriveAuthErrorCode.fromApiStatus(statusCode, detail)

    private fun driveString(resourceId: Int): String =
        DriveUploadLocalization.string(this, resourceId)

    private fun canUseDeviceCredential(): Boolean {
        val keyguard = getSystemService(KeyguardManager::class.java)
        return keyguard.isDeviceSecure
    }

    private fun canUseBiometric(): Boolean {
        val biometricManager = BiometricManager.from(this)
        return biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS
    }

    private fun getDeviceAuthCapabilities(): Map<String, Boolean> {
        return mapOf(
            "deviceCredential" to canUseDeviceCredential(),
            "biometricStrong" to canUseBiometric(),
        )
    }

    private fun purgeInactiveDeviceKeys(call: MethodCall) {
        val vaultId = requireVaultId(call)
        val keepKind = requireAuthKind(call)
        val keyStore = loadKeyStore()
        for (kind in AuthKind.entries) {
            if (kind == keepKind) {
                continue
            }
            val alias = aliasFor(vaultId, kind)
            if (keyStore.containsAlias(alias)) {
                keyStore.deleteEntry(alias)
            }
        }
    }

    private fun ensureKey(call: MethodCall): Map<String, Any> {
        val vaultId = requireVaultId(call)
        val kind = requireAuthKind(call)
        val alias = aliasFor(vaultId, kind)
        if (!hasAlias(alias)) {
            createKey(alias, kind)
        }
        return mapOf(
            "slotId" to slotIdFor(vaultId, kind),
            "platform" to platformLabel(),
        )
    }

    private fun hasKey(call: MethodCall): Boolean {
        val vaultId = requireVaultId(call)
        return AuthKind.entries.any { hasAlias(aliasFor(vaultId, it)) }
    }

    private fun wrapWithDeviceKey(call: MethodCall, result: MethodChannel.Result) {
        try {
            val vaultId = requireVaultId(call)
            val kind = requireAuthKind(call)
            ensureAlias(vaultId, kind)
            val plaintext = requireByteArray(call.argument<List<Int>>("plaintext"), "plaintext")
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, requireSecretKey(vaultId, kind))

            if (kind == AuthKind.PLAIN) {
                val ciphertext = cipher.doFinal(plaintext)
                result.success(
                    mapOf(
                        "slotId" to slotIdFor(vaultId, kind),
                        "nonce" to encode(cipher.iv),
                        "ciphertext" to encode(ciphertext),
                        "platform" to platformLabel(),
                    ),
                )
                return
            }

            val onSuccess = { authedCipher: Cipher ->
                val ciphertext = authedCipher.doFinal(plaintext)
                result.success(
                    mapOf(
                        "slotId" to slotIdFor(vaultId, kind),
                        "nonce" to encode(authedCipher.iv),
                        "ciphertext" to encode(ciphertext),
                        "platform" to platformLabel(),
                    ),
                )
            }
            authenticateCipher(
                cipher = cipher,
                kind = kind,
                reason = WRAP_PROMPT_REASON,
                result = result,
                onSuccess = onSuccess,
            )
        } catch (error: Throwable) {
            completeDeviceKeyError(result, error)
        }
    }

    private fun unwrapWithDeviceKey(call: MethodCall, result: MethodChannel.Result) {
        try {
            val vaultId = requireVaultId(call)
            val slotId = call.argument<String>("slotId") ?: ""
            val kind = authKindFromSlotId(slotId, vaultId)
            val nonce = decode(requireString(call, "nonce"))
            val ciphertext = decode(requireString(call, "ciphertext"))
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                requireSecretKey(vaultId, kind),
                GCMParameterSpec(GCM_TAG_BITS, nonce),
            )

            if (kind == AuthKind.PLAIN) {
                result.success(
                    cipher.doFinal(ciphertext).map { byteValue ->
                        byteValue.toInt() and 0xFF
                    },
                )
                return
            }

            val onSuccess = { authedCipher: Cipher ->
                result.success(
                    authedCipher.doFinal(ciphertext).map { byteValue ->
                        byteValue.toInt() and 0xFF
                    },
                )
            }
            authenticateCipher(
                cipher = cipher,
                kind = kind,
                reason = UNWRAP_PROMPT_REASON,
                result = result,
                onSuccess = onSuccess,
            )
        } catch (error: Throwable) {
            completeDeviceKeyError(result, error)
        }
    }

    private fun rewrapTrustedRecoveryKey(call: MethodCall, result: MethodChannel.Result) {
        try {
            val vaultId = requireVaultId(call)
            val sourceSlotId = call.argument<String>("sourceSlotId") ?: ""
            val sourceKind = authKindFromSlotId(sourceSlotId, vaultId)
            val targetKind = requireAuthKind(call)
            val nonce = decode(requireString(call, "nonce"))
            val ciphertext = decode(requireString(call, "ciphertext"))

            val completeRewrap = { plaintext: ByteArray ->
                try {
                    deliverRewrapResult(
                        vaultId = vaultId,
                        targetKind = targetKind,
                        plaintext = plaintext,
                        result = result,
                    )
                } catch (error: Throwable) {
                    completeDeviceKeyError(result, error)
                }
            }

            if (sourceKind == AuthKind.PLAIN) {
                val cipher = Cipher.getInstance(TRANSFORMATION)
                cipher.init(
                    Cipher.DECRYPT_MODE,
                    requireSecretKey(vaultId, sourceKind),
                    GCMParameterSpec(GCM_TAG_BITS, nonce),
                )
                completeRewrap(cipher.doFinal(ciphertext))
                return
            }

            val decryptCipher = Cipher.getInstance(TRANSFORMATION)
            decryptCipher.init(
                Cipher.DECRYPT_MODE,
                requireSecretKey(vaultId, sourceKind),
                GCMParameterSpec(GCM_TAG_BITS, nonce),
            )
            authenticateCipher(
                cipher = decryptCipher,
                kind = sourceKind,
                reason = REWRAP_PROMPT_REASON,
                result = result,
                onSuccess = { authedCipher ->
                    completeRewrap(authedCipher.doFinal(ciphertext))
                },
            )
        } catch (error: Throwable) {
            completeDeviceKeyError(result, error)
        }
    }

    private fun deliverRewrapResult(
        vaultId: String,
        targetKind: AuthKind,
        plaintext: ByteArray,
        result: MethodChannel.Result,
    ) {
        ensureAlias(vaultId, targetKind)
        val encryptCipher = Cipher.getInstance(TRANSFORMATION)
        encryptCipher.init(Cipher.ENCRYPT_MODE, requireSecretKey(vaultId, targetKind))

        if (targetKind == AuthKind.PLAIN) {
            val newCiphertext = encryptCipher.doFinal(plaintext)
            result.success(
                mapOf(
                    "recoveryWrapKey" to plaintext.map { byteValue -> byteValue.toInt() and 0xFF },
                    "slotId" to slotIdFor(vaultId, targetKind),
                    "nonce" to encode(encryptCipher.iv),
                    "ciphertext" to encode(newCiphertext),
                    "platform" to platformLabel(),
                ),
            )
            return
        }

        val onSuccess = { authedCipher: Cipher ->
            val newCiphertext = authedCipher.doFinal(plaintext)
            result.success(
                mapOf(
                    "recoveryWrapKey" to plaintext.map { byteValue -> byteValue.toInt() and 0xFF },
                    "slotId" to slotIdFor(vaultId, targetKind),
                    "nonce" to encode(authedCipher.iv),
                    "ciphertext" to encode(newCiphertext),
                    "platform" to platformLabel(),
                ),
            )
        }
        authenticateCipher(
            cipher = encryptCipher,
            kind = targetKind,
            reason = REWRAP_PROMPT_REASON,
            result = result,
            onSuccess = onSuccess,
        )
    }

    private fun deleteKey(call: MethodCall) {
        val vaultId = requireVaultId(call)
        val keyStore = loadKeyStore()
        for (kind in AuthKind.entries) {
            val alias = aliasFor(vaultId, kind)
            if (keyStore.containsAlias(alias)) {
                keyStore.deleteEntry(alias)
            }
        }
    }

    private fun ensureAlias(vaultId: String, kind: AuthKind) {
        val alias = aliasFor(vaultId, kind)
        if (!hasAlias(alias)) {
            createKey(alias, kind)
        }
    }

    private fun createKey(alias: String, kind: AuthKind) {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE,
        )
        val builder =
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
        when (kind) {
            AuthKind.PLAIN -> Unit
            AuthKind.DEVICE_CREDENTIAL -> {
                builder.setUserAuthenticationParameters(
                    0,
                    KeyProperties.AUTH_DEVICE_CREDENTIAL,
                )
                builder.setUserAuthenticationRequired(true)
            }
            AuthKind.BIOMETRIC -> {
                builder.setUserAuthenticationParameters(
                    0,
                    (
                        KeyProperties.AUTH_BIOMETRIC_STRONG or
                            KeyProperties.AUTH_DEVICE_CREDENTIAL
                    ),
                )
                builder.setUserAuthenticationRequired(true)
            }
        }
        val spec = builder.build()
        keyGenerator.init(spec)
        keyGenerator.generateKey()
    }

    private fun hasAlias(alias: String): Boolean {
        return loadKeyStore().containsAlias(alias)
    }

    private fun requireSecretKey(vaultId: String, kind: AuthKind): SecretKey {
        val entry =
            loadKeyStore().getEntry(aliasFor(vaultId, kind), null)
                ?: throw IllegalStateException("Keystore alias is missing.")
        if (entry !is KeyStore.SecretKeyEntry) {
            throw IllegalStateException("Keystore entry is not a secret key.")
        }
        return entry.secretKey
    }

    private fun loadKeyStore(): KeyStore {
        return KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    }

    private fun aliasFor(vaultId: String, kind: AuthKind): String {
        return "quill_diary.device_wrap.${kind.wire}.$vaultId"
    }

    private fun slotIdFor(vaultId: String, kind: AuthKind): String {
        return "dev_android_keystore_${kind.wire}_$vaultId"
    }

    private fun authKindFromSlotId(slotId: String, vaultId: String): AuthKind {
        return when {
            slotId == slotIdFor(vaultId, AuthKind.PLAIN) -> AuthKind.PLAIN
            slotId == slotIdFor(vaultId, AuthKind.DEVICE_CREDENTIAL) -> AuthKind.DEVICE_CREDENTIAL
            slotId == slotIdFor(vaultId, AuthKind.BIOMETRIC) -> AuthKind.BIOMETRIC
            else -> throw IllegalArgumentException("Device slot id mismatch.")
        }
    }

    private fun platformLabel(): String {
        return "android_keystore_api_${Build.VERSION.SDK_INT}"
    }

    private fun requireVaultId(call: MethodCall): String {
        return requireString(call, "vaultId")
    }

    private fun requireAuthKind(call: MethodCall): AuthKind {
        val raw = call.argument<String>("keystoreAuthKind")
            ?: throw IllegalArgumentException("keystoreAuthKind is required.")
        return AuthKind.fromWire(raw)
    }

    private fun requireString(call: MethodCall, name: String): String {
        return call.argument<String>(name)
            ?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("$name is required.")
    }

    private fun requireByteArray(values: List<Int>?, name: String): ByteArray {
        if (values == null) {
            throw IllegalArgumentException("$name is required.")
        }
        return values.map { intValue ->
            (intValue and 0xFF).toByte()
        }.toByteArray()
    }

    private fun encode(bytes: ByteArray): String {
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    private fun decode(value: String): ByteArray {
        return Base64.decode(value, Base64.NO_WRAP)
    }

    private fun authenticateCipher(
        cipher: Cipher,
        kind: AuthKind,
        reason: String,
        result: MethodChannel.Result,
        onSuccess: (Cipher) -> Unit,
    ) {
        if (rejectIfDeviceCredentialUnavailable(kind, result)) {
            return
        }
        val authenticators =
            when (kind) {
                AuthKind.PLAIN ->
                    throw IllegalStateException("Plain keys do not require authentication.")
                AuthKind.DEVICE_CREDENTIAL ->
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL
                AuthKind.BIOMETRIC ->
                    (
                        BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            BiometricManager.Authenticators.DEVICE_CREDENTIAL
                    )
            }
        val prompt =
            BiometricPrompt(
                this,
                ContextCompat.getMainExecutor(this),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authResult: BiometricPrompt.AuthenticationResult,
                    ) {
                        val authedCipher = authResult.cryptoObject?.cipher
                        if (authedCipher == null) {
                            result.error(
                                "device_key_auth_failed",
                                "Authentication succeeded but cipher is unavailable.",
                                null,
                            )
                            return
                        }
                        try {
                            onSuccess(authedCipher)
                        } catch (error: Throwable) {
                            result.error(
                                "device_key_invalidated",
                                error.message ?: "Device key operation failed after authentication.",
                                null,
                            )
                        }
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        val (code, message) = mapAuthenticationError(errorCode, errString)
                        result.error(code, message, null)
                    }
                },
            )
        val promptBuilder =
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("Quill Diary")
                .setSubtitle(reason)
                .setAllowedAuthenticators(authenticators)
        prompt.authenticate(
            promptBuilder.build(),
            BiometricPrompt.CryptoObject(cipher),
        )
    }

    private fun rejectIfDeviceCredentialUnavailable(
        kind: AuthKind,
        result: MethodChannel.Result,
    ): Boolean {
        if (kind == AuthKind.PLAIN) {
            return false
        }
        if (canUseDeviceCredential()) {
            return false
        }
        result.error(
            "device_key_no_device_credential",
            DEVICE_CREDENTIAL_REQUIRED_MESSAGE,
            null,
        )
        return true
    }

    private fun mapAuthenticationError(
        errorCode: Int,
        errString: CharSequence,
    ): Pair<String, String> {
        val detail = errString.toString().trim()
        return when (errorCode) {
            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
            BiometricPrompt.ERROR_USER_CANCELED,
            BiometricPrompt.ERROR_CANCELED,
            -> "device_key_auth_cancelled" to detail.ifEmpty { "使用者已取消裝置驗證。" }
            BiometricPrompt.ERROR_TIMEOUT ->
                "device_key_auth_timeout" to detail.ifEmpty { "驗證逾時，請再試一次。" }
            BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL ->
                "device_key_no_device_credential" to DEVICE_CREDENTIAL_REQUIRED_MESSAGE
            BiometricPrompt.ERROR_NO_BIOMETRICS ->
                "device_key_biometric_not_enrolled" to BIOMETRIC_ENROLLMENT_REQUIRED_MESSAGE
            BiometricPrompt.ERROR_LOCKOUT,
            BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
            ->
                "device_key_auth_lockout" to detail.ifEmpty { "驗證失敗次數過多，請稍後再試。" }
            else -> "device_key_auth_failed" to detail.ifEmpty { "裝置驗證失敗。" }
        }
    }

    private fun completeDeviceKeyError(result: MethodChannel.Result, error: Throwable) {
        val (code, message) = mapDeviceKeyError(error)
        result.error(code, message, null)
    }

    private fun mapDeviceKeyError(error: Throwable): Pair<String, String> {
        val detail = error.message?.trim().orEmpty()
        val lowerDetail = detail.lowercase()
        if (lowerDetail.contains("at least one biometric must be enrolled")) {
            return "device_key_biometric_not_enrolled" to BIOMETRIC_ENROLLMENT_REQUIRED_MESSAGE
        }
        if (lowerDetail.contains("no_device_credential")) {
            return "device_key_no_device_credential" to DEVICE_CREDENTIAL_REQUIRED_MESSAGE
        }
        return "device_key_invalidated" to detail.ifEmpty { "Device key operation failed." }
    }

    private fun copyUriToPath(call: MethodCall, result: MethodChannel.Result) {
        val sourceUriString = call.argument<String>("sourceUri")?.trim().orEmpty()
        val destinationPath = call.argument<String>("destinationPath")?.trim().orEmpty()

        if (sourceUriString.isEmpty() || destinationPath.isEmpty()) {
            result.error("invalid_args", "缺少 sourceUri 或 destinationPath。", null)
            return
        }

        val destinationFile = File(destinationPath)
        destinationFile.parentFile?.mkdirs()

        try {
            contentResolver.openInputStream(Uri.parse(sourceUriString))?.use { input ->
                destinationFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            } ?: run {
                result.error("open_input_failed", "無法讀取選取的檔案。", null)
                return
            }
            result.success(null)
        } catch (error: IOException) {
            deleteIfExists(destinationFile)
            result.error(
                "copy_failed",
                error.message ?: "複製檔案失敗。",
                null,
            )
        } catch (error: SecurityException) {
            deleteIfExists(destinationFile)
            result.error("open_input_failed", "無法讀取選取的檔案。", null)
        } catch (error: Exception) {
            deleteIfExists(destinationFile)
            result.error(
                "copy_failed",
                error.message ?: "複製檔案失敗。",
                null,
            )
        }
    }

    private fun deleteIfExists(file: File) {
        if (file.exists()) {
            file.delete()
        }
    }

    private fun copyFileToSafTree(call: MethodCall, result: MethodChannel.Result) {
        val treeUriString = call.argument<String>("treeUri")?.trim().orEmpty()
        val sourcePath = call.argument<String>("sourcePath")?.trim().orEmpty()
        val fileName = call.argument<String>("fileName")?.trim().orEmpty()
        val mimeType = call.argument<String>("mimeType")?.trim().orEmpty()
            .ifEmpty { "application/octet-stream" }

        if (treeUriString.isEmpty() || sourcePath.isEmpty() || fileName.isEmpty()) {
            result.error("invalid_args", "缺少 treeUri、sourcePath 或 fileName。", null)
            return
        }

        val sourceFile = File(sourcePath)
        if (!sourceFile.isFile) {
            result.error("source_missing", "找不到要複製的來源檔案。", null)
            return
        }

        val treeUri = Uri.parse(treeUriString)
        val parentDocumentUri =
            if (DocumentsContract.isTreeUri(treeUri)) {
                DocumentsContract.buildDocumentUriUsingTree(
                    treeUri,
                    DocumentsContract.getTreeDocumentId(treeUri),
                )
            } else {
                treeUri
            }
        val createdUri =
            try {
                DocumentsContract.createDocument(contentResolver, parentDocumentUri, mimeType, fileName)
            } catch (error: SecurityException) {
                result.error(
                    "create_document_failed",
                    "沒有寫入此資料夾的權限，請重新選擇資料夾並允許存取。",
                    null,
                )
                return
            }
        if (createdUri == null) {
            result.error("create_document_failed", "無法在選擇的資料夾建立檔案。", null)
            return
        }

        try {
            contentResolver.openOutputStream(createdUri, "w")?.use { output ->
                sourceFile.inputStream().use { input ->
                    input.copyTo(output)
                }
            } ?: throw IOException("無法開啟輸出串流。")
            result.success(createdUri.toString())
        } catch (error: Exception) {
            try {
                DocumentsContract.deleteDocument(contentResolver, createdUri)
            } catch (_: Exception) {
                // 刪除半成品失敗時仍回報原始錯誤。
            }
            result.error("copy_failed", error.message ?: "複製檔案失敗。", null)
        }
    }

    private enum class AuthKind(val wire: String) {
        PLAIN("plain"),
        DEVICE_CREDENTIAL("deviceCredential"),
        BIOMETRIC("biometric"),
        ;

        companion object {
            fun fromWire(raw: String): AuthKind {
                return entries.firstOrNull { it.wire == raw }
                    ?: throw IllegalArgumentException("Unknown keystoreAuthKind: $raw")
            }
        }
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val OAUTH_CHANNEL_NAME = "quill_diary/oauth_config"
        private const val DEVICE_KEY_CHANNEL_NAME = "quill_diary/device_key_bridge"
        private const val SAF_FILE_COPY_CHANNEL_NAME = "quill_diary/saf_file_copy"
        private const val CONTENT_URI_IMPORT_CHANNEL_NAME = "quill_diary/content_uri_import"
        private const val DIRECTORY_PICKER_CHANNEL_NAME = "quill_diary/directory_picker"
        private const val GOOGLE_DRIVE_SIGN_IN_REQUEST_CODE = 43021
        private const val DIRECTORY_PICK_REQUEST_CODE = 43022
        private const val GOOGLE_DRIVE_APPDATA_SCOPE =
            "https://www.googleapis.com/auth/drive.appdata"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
        private const val WRAP_PROMPT_REASON = "請驗證裝置身分以保護恢復金鑰"
        private const val UNWRAP_PROMPT_REASON = "請驗證裝置身分以解鎖恢復金鑰"
        private const val REWRAP_PROMPT_REASON = "正在更新解鎖設定，請完成驗證"
        private const val DEVICE_CREDENTIAL_REQUIRED_MESSAGE =
            "請先在裝置設定中建立螢幕鎖，才能使用此解鎖方式。"
        private const val BIOMETRIC_ENROLLMENT_REQUIRED_MESSAGE =
            "啟用生物驗證前，請先到裝置設定新增至少一種生物辨識。"
    }
}
