package zack20136.com.quill_lock_diary

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
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

    private fun ensureKey(call: MethodCall): Map<String, Any> {
        val vaultId = requireVaultId(call)
        val requiresAuth = call.argument<Boolean>("userAuthenticationRequired") == true
        val alias = aliasFor(vaultId, requiresAuth)
        if (!hasAlias(alias)) {
            createKey(alias, requiresAuth)
        }
        return mapOf(
            "slotId" to slotIdFor(vaultId, requiresAuth),
            "platform" to platformLabel(),
        )
    }

    private fun hasKey(call: MethodCall): Boolean {
        val vaultId = requireVaultId(call)
        return hasAlias(aliasFor(vaultId, true)) || hasAlias(aliasFor(vaultId, false))
    }

    private fun wrapWithDeviceKey(call: MethodCall, result: MethodChannel.Result) {
        try {
            val vaultId = requireVaultId(call)
            val requiresAuth = call.argument<Boolean>("userAuthenticationRequired") == true
            ensureAlias(vaultId, requiresAuth)
            val plaintext = requireByteArray(call.argument<List<Int>>("plaintext"), "plaintext")
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, requireSecretKey(vaultId, requiresAuth))

            val onSuccess = { authedCipher: Cipher ->
                val ciphertext = authedCipher.doFinal(plaintext)
                result.success(
                    mapOf(
                        "slotId" to slotIdFor(vaultId, requiresAuth),
                        "nonce" to encode(authedCipher.iv),
                        "ciphertext" to encode(ciphertext),
                        "platform" to platformLabel(),
                    ),
                )
            }
            if (requiresAuth) {
                authenticateCipher(
                    cipher = cipher,
                    reason = "請驗證裝置以保護日記庫",
                    result = result,
                    onSuccess = onSuccess,
                )
            } else {
                onSuccess(cipher)
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
            val requiresAuth = requiresAuthentication(slotId, vaultId)
            val nonce = decode(requireString(call, "nonce"))
            val ciphertext = decode(requireString(call, "ciphertext"))
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                requireSecretKey(vaultId, requiresAuth),
                GCMParameterSpec(GCM_TAG_BITS, nonce),
            )

            val onSuccess = { authedCipher: Cipher ->
                result.success(
                    authedCipher.doFinal(ciphertext).map { byteValue ->
                        byteValue.toInt() and 0xFF
                    },
                )
            }
            if (requiresAuth) {
                authenticateCipher(
                    cipher = cipher,
                    reason = "請驗證裝置以解鎖日記庫",
                    result = result,
                    onSuccess = onSuccess,
                )
            } else {
                onSuccess(cipher)
            }
        } catch (error: Throwable) {
            when (error) {
                is LegacySlotIdException ->
                    result.error(
                        "device_key_legacy_slot",
                        error.message ?: "Legacy device slot is no longer supported.",
                        null,
                    )

                else ->
                    result.error(
                        "device_key_invalidated",
                        error.message ?: "Unable to unwrap data with device key.",
                        null,
                    )
            }
        }
    }

    private fun deleteKey(call: MethodCall) {
        val vaultId = requireVaultId(call)
        val keyStore = loadKeyStore()
        for (alias in listOf(aliasFor(vaultId, true), aliasFor(vaultId, false))) {
            if (keyStore.containsAlias(alias)) {
                keyStore.deleteEntry(alias)
            }
        }
    }

    private fun ensureAlias(vaultId: String, requiresAuth: Boolean) {
        if (!hasAlias(aliasFor(vaultId, requiresAuth))) {
            createKey(aliasFor(vaultId, requiresAuth), requiresAuth)
        }
    }

    private fun createKey(alias: String, requiresAuth: Boolean) {
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
        if (requiresAuth) {
            builder
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)
        }
        val spec = builder.build()
        keyGenerator.init(spec)
        keyGenerator.generateKey()
    }

    private fun hasAlias(alias: String): Boolean {
        return loadKeyStore().containsAlias(alias)
    }

    private fun requireSecretKey(vaultId: String, requiresAuth: Boolean): SecretKey {
        val entry =
            loadKeyStore().getEntry(aliasFor(vaultId, requiresAuth), null)
                ?: throw IllegalStateException("Keystore alias is missing.")
        if (entry !is KeyStore.SecretKeyEntry) {
            throw IllegalStateException("Keystore entry is not a secret key.")
        }
        return entry.secretKey
    }

    private fun loadKeyStore(): KeyStore {
        return KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    }

    private fun aliasFor(vaultId: String, requiresAuth: Boolean): String {
        val mode = if (requiresAuth) "auth" else "plain"
        return "quill_lock_diary.device_wrap.$mode.$vaultId"
    }

    private fun slotIdFor(vaultId: String, requiresAuth: Boolean): String {
        val mode = if (requiresAuth) "auth" else "plain"
        return "dev_android_keystore_${mode}_$vaultId"
    }

    private fun legacySlotIdFor(vaultId: String): String {
        return "dev_android_keystore_$vaultId"
    }

    private fun platformLabel(): String {
        return "android_keystore_api_${Build.VERSION.SDK_INT}"
    }

    private fun requireVaultId(call: MethodCall): String {
        return requireString(call, "vaultId")
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

    private fun requiresAuthentication(slotId: String, vaultId: String): Boolean {
        return when (slotId) {
            slotIdFor(vaultId, true) -> true
            slotIdFor(vaultId, false) -> false
            legacySlotIdFor(vaultId) -> throw LegacySlotIdException()
            else -> throw IllegalArgumentException("Device slot id mismatch.")
        }
    }

    private fun authenticateCipher(
        cipher: Cipher,
        reason: String,
        result: MethodChannel.Result,
        onSuccess: (Cipher) -> Unit,
    ) {
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
        val promptInfo =
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("QuillLockDiary")
                .setSubtitle(reason)
                .setNegativeButtonText("取消")
                .build()
        prompt.authenticate(
            promptInfo,
            BiometricPrompt.CryptoObject(cipher),
        )
    }

    companion object {
        private const val OAUTH_CHANNEL_NAME = "quill_lock_diary/oauth_config"
        private const val DEVICE_KEY_CHANNEL_NAME = "quill_lock_diary/device_key_bridge"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
    }
}

private class LegacySlotIdException : IllegalStateException(
    "Legacy trusted device data is no longer supported.",
)
