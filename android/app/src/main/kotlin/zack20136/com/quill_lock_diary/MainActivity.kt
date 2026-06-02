package zack20136.com.quill_lock_diary

import android.app.KeyguardManager
import android.content.Intent
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
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
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterFragmentActivity() {
    private var pendingGoogleDriveAuthResult: MethodChannel.Result? = null
    private var googleDriveSignInClient: GoogleSignInClient? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EasyDiaryRealmChannel.register(flutterEngine, applicationContext)

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
                    "wrapWithDeviceKey" -> wrapWithDeviceKey(call, result)
                    "unwrapWithDeviceKey" -> unwrapWithDeviceKey(call, result)
                    "deleteKey" -> {
                        deleteKey(call)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "device_key_error",
                    error.message ?: "Unknown device key error.",
                    null,
                )
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == GOOGLE_DRIVE_SIGN_IN_REQUEST_CODE) {
            handleGoogleDriveSignInResult(data)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun signInGoogleDrive(call: MethodCall, result: MethodChannel.Result) {
        if (pendingGoogleDriveAuthResult != null) {
            result.error(
                "google_drive_auth_in_progress",
                "Google Drive sign-in is already in progress.",
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
                ?: throw IllegalStateException("Google account is unavailable after sign-in.")
            if (!hasDriveAppDataPermission(account)) {
                throw IllegalStateException("Google Drive scope is missing after sign-in.")
            }
            pendingResult.success(googleDriveAccountPayload(account))
        } catch (error: ApiException) {
            pendingResult.error(
                "google_drive_auth_failed",
                "[${error.statusCode}] ${error.localizedMessage ?: "Google account sign-in failed."}",
                null,
            )
        } catch (error: Throwable) {
            pendingResult.error(
                "google_drive_auth_failed",
                error.message ?: "Google account sign-in failed.",
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

    private fun canUseDeviceCredential(): Boolean {
        val keyguard = getSystemService(KeyguardManager::class.java)
        return keyguard.isDeviceSecure
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
            result.error(
                "device_key_invalidated",
                error.message ?: "Unable to wrap data with device key.",
                null,
            )
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
            result.error(
                "device_key_invalidated",
                error.message ?: "Unable to unwrap data with device key.",
                null,
            )
        }
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
        return "quill_lock_diary.device_wrap.${kind.wire}.$vaultId"
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
                        val code =
                            when (errorCode) {
                                BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                                BiometricPrompt.ERROR_USER_CANCELED,
                                BiometricPrompt.ERROR_CANCELED,
                                BiometricPrompt.ERROR_TIMEOUT,
                                BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> "device_key_auth_cancelled"
                                else -> "device_key_auth_failed"
                            }
                        result.error(code, errString.toString(), null)
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
        private const val OAUTH_CHANNEL_NAME = "quill_lock_diary/oauth_config"
        private const val DEVICE_KEY_CHANNEL_NAME = "quill_lock_diary/device_key_bridge"
        private const val GOOGLE_DRIVE_SIGN_IN_REQUEST_CODE = 43021
        private const val GOOGLE_DRIVE_APPDATA_SCOPE =
            "https://www.googleapis.com/auth/drive.appdata"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
        private const val WRAP_PROMPT_REASON = "請驗證身分以保護復原金鑰"
        private const val UNWRAP_PROMPT_REASON = "請驗證身分以解鎖復原金鑰"
    }
}
