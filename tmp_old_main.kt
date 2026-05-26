package zack20136.com.quill_lock_diary

import android.app.KeyguardManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
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
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OAUTH_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getServerClientId" -> {
                    val id = getString(R.string.oauth_request_id_token).trim()
                    result.success(if (id.isEmpty()) null else id)
                }
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
            if (kind == AuthKind.PLAIN) {
                onSuccess(cipher)
            } else {
                authenticateCipher(
                    cipher = cipher,
                    kind = kind,
                    reason = "隢?霅?蝵桐誑靽風?亥?摨?,
                    result = result,
                    onSuccess = onSuccess,
                )
            }
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

            val onSuccess = { authedCipher: Cipher ->
                result.success(
                    authedCipher.doFinal(ciphertext).map { byteValue ->
                        byteValue.toInt() and 0xFF
                    },
                )
            }
            if (kind == AuthKind.PLAIN) {
                onSuccess(cipher)
            } else {
                authenticateCipher(
                    cipher = cipher,
                    kind = kind,
                    reason = "隢?霅?蝵桐誑閫???亥?摨?,
                    result = result,
                    onSuccess = onSuccess,
                )
            }
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
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    builder.setUserAuthenticationParameters(
                        0,
                        KeyProperties.AUTH_DEVICE_CREDENTIAL,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    builder.setUserAuthenticationValidityDurationSeconds(0)
                }
                builder.setUserAuthenticationRequired(true)
            }
            AuthKind.BIOMETRIC -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    builder.setUserAuthenticationParameters(
                        0,
                        KeyProperties.AUTH_BIOMETRIC_STRONG,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    builder.setUserAuthenticationValidityDurationSeconds(0)
                }
                builder
                    .setUserAuthenticationRequired(true)
                    .setInvalidatedByBiometricEnrollment(true)
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
                AuthKind.DEVICE_CREDENTIAL ->
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL
                AuthKind.BIOMETRIC ->
                    BiometricManager.Authenticators.BIOMETRIC_STRONG
                AuthKind.PLAIN -> throw IllegalStateException("Plain keys do not require authentication.")
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
                .setTitle("QuillLockDiary")
                .setSubtitle(reason)
                .setAllowedAuthenticators(authenticators)
        if (kind == AuthKind.BIOMETRIC) {
            promptBuilder.setNegativeButtonText("??")
        }
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
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
    }
}
