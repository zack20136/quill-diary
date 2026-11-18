package zack20136.com.quill_diary

import android.app.KeyguardManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.annotation.StringRes
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal class DeviceKeyChannel(private val activity: FragmentActivity) {
    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler(::handleCall)
    }

    internal fun handleCall(call: MethodCall, result: MethodChannel.Result) {
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

    private fun canUseDeviceCredential(): Boolean {
        val keyguard = activity.getSystemService(KeyguardManager::class.java)
        return keyguard.isDeviceSecure
    }

    private fun canUseBiometric(): Boolean {
        val biometricManager = BiometricManager.from(activity)
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
        deleteAliases(vaultId = requireVaultId(call), keepKind = requireAuthKind(call))
    }

    private fun ensureKey(call: MethodCall): Map<String, Any> {
        val vaultId = requireVaultId(call)
        val kind = requireAuthKind(call)
        ensureAlias(vaultId, kind)
        return mapOf(
            "slotId" to slotIdFor(vaultId, kind),
            "platform" to platformLabel(),
        )
    }

    private fun hasKey(call: MethodCall): Boolean {
        val vaultId = requireVaultId(call)
        return DeviceKeyAuthKind.entries.any { hasAlias(aliasFor(vaultId, it)) }
    }

    private fun wrapWithDeviceKey(call: MethodCall, result: MethodChannel.Result) {
        val vaultId = requireVaultId(call)
        val kind = requireAuthKind(call)
        ensureAlias(vaultId, kind)
        val plaintext = requireByteArray(call.argument<List<Int>>("plaintext"), "plaintext")
        val cipher = initEncryptCipher(vaultId, kind)
        withAuthorizedCipher(cipher, kind, R.string.device_key_wrap_prompt, result) { authorized ->
            result.success(wrappedKeyPayload(vaultId, kind, authorized, plaintext))
        }
    }

    private fun unwrapWithDeviceKey(call: MethodCall, result: MethodChannel.Result) {
        val vaultId = requireVaultId(call)
        val kind = authKindFromSlotId(call.argument<String>("slotId").orEmpty(), vaultId)
        val nonce = decode(requireString(call, "nonce"))
        val ciphertext = decode(requireString(call, "ciphertext"))
        val cipher = initDecryptCipher(vaultId, kind, nonce)
        withAuthorizedCipher(cipher, kind, R.string.device_key_unwrap_prompt, result) { authorized ->
            result.success(authorized.doFinal(ciphertext).toUnsignedBytes())
        }
    }

    private fun rewrapTrustedRecoveryKey(call: MethodCall, result: MethodChannel.Result) {
        val vaultId = requireVaultId(call)
        val sourceKind = authKindFromSlotId(call.argument<String>("sourceSlotId").orEmpty(), vaultId)
        val targetKind = requireAuthKind(call)
        val nonce = decode(requireString(call, "nonce"))
        val ciphertext = decode(requireString(call, "ciphertext"))
        val sourceCipher = initDecryptCipher(vaultId, sourceKind, nonce)
        withAuthorizedCipher(sourceCipher, sourceKind, R.string.device_key_rewrap_prompt, result) { authorized ->
            val plaintext = authorized.doFinal(ciphertext)
            try {
                // 來源金鑰通過驗證後，才能建立目標金鑰。
                ensureAlias(vaultId, targetKind)
                val targetCipher = initEncryptCipher(vaultId, targetKind)
                withAuthorizedCipher(targetCipher, targetKind, R.string.device_key_rewrap_prompt, result) { target ->
                    val wrapped = wrappedKeyPayload(vaultId, targetKind, target, plaintext)
                    result.success(wrapped + ("recoveryWrapKey" to plaintext.toUnsignedBytes()))
                }
            } catch (error: Throwable) {
                completeDeviceKeyError(result, error)
            }
        }
    }

    private fun initEncryptCipher(vaultId: String, kind: DeviceKeyAuthKind): Cipher =
        Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.ENCRYPT_MODE, requireSecretKey(vaultId, kind))
        }

    private fun initDecryptCipher(vaultId: String, kind: DeviceKeyAuthKind, nonce: ByteArray): Cipher =
        Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.DECRYPT_MODE, requireSecretKey(vaultId, kind), GCMParameterSpec(GCM_TAG_BITS, nonce))
        }

    private fun wrappedKeyPayload(
        vaultId: String,
        kind: DeviceKeyAuthKind,
        cipher: Cipher,
        plaintext: ByteArray,
    ): Map<String, Any> {
        val ciphertext = cipher.doFinal(plaintext)
        return mapOf(
            "slotId" to slotIdFor(vaultId, kind),
            "nonce" to encode(cipher.iv),
            "ciphertext" to encode(ciphertext),
            "platform" to platformLabel(),
        )
    }

    private fun ByteArray.toUnsignedBytes(): List<Int> = map { it.toInt() and 0xFF }

    private fun deleteKey(call: MethodCall) {
        deleteAliases(vaultId = requireVaultId(call))
    }

    private fun deleteAliases(vaultId: String, keepKind: DeviceKeyAuthKind? = null) {
        val keyStore = loadKeyStore()
        for (kind in DeviceKeyAuthKind.entries) {
            if (kind == keepKind) continue
            val alias = aliasFor(vaultId, kind)
            if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
        }
    }

    private fun ensureAlias(vaultId: String, kind: DeviceKeyAuthKind) {
        val alias = aliasFor(vaultId, kind)
        if (!hasAlias(alias)) {
            createKey(alias, kind)
        }
    }

    private fun createKey(alias: String, kind: DeviceKeyAuthKind) {
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
            DeviceKeyAuthKind.PLAIN -> Unit
            DeviceKeyAuthKind.DEVICE_CREDENTIAL -> {
                builder.setUserAuthenticationParameters(
                    0,
                    KeyProperties.AUTH_DEVICE_CREDENTIAL,
                )
                builder.setUserAuthenticationRequired(true)
            }
            DeviceKeyAuthKind.BIOMETRIC -> {
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

    private fun requireSecretKey(vaultId: String, kind: DeviceKeyAuthKind): SecretKey {
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

    private fun aliasFor(vaultId: String, kind: DeviceKeyAuthKind): String {
        return "quill_diary.device_wrap.${kind.wire}.$vaultId"
    }

    private fun slotIdFor(vaultId: String, kind: DeviceKeyAuthKind): String {
        return "dev_android_keystore_${kind.wire}_$vaultId"
    }

    private fun authKindFromSlotId(slotId: String, vaultId: String): DeviceKeyAuthKind {
        return DeviceKeyAuthKind.entries.firstOrNull { slotIdFor(vaultId, it) == slotId }
            ?: throw IllegalArgumentException("Device slot id mismatch.")
    }

    private fun platformLabel(): String {
        return "android_keystore_api_${Build.VERSION.SDK_INT}"
    }

    private fun requireVaultId(call: MethodCall): String {
        return requireString(call, "vaultId")
    }

    private fun requireAuthKind(call: MethodCall): DeviceKeyAuthKind {
        val raw = call.argument<String>("keystoreAuthKind")
            ?: throw IllegalArgumentException("keystoreAuthKind is required.")
        return DeviceKeyAuthKind.fromWire(raw)
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

    private fun withAuthorizedCipher(
        cipher: Cipher,
        kind: DeviceKeyAuthKind,
        @StringRes promptSubtitle: Int,
        result: MethodChannel.Result,
        onSuccess: (Cipher) -> Unit,
    ) {
        val authenticators = when (kind) {
            DeviceKeyAuthKind.PLAIN -> {
                onSuccess(cipher)
                return
            }
            DeviceKeyAuthKind.DEVICE_CREDENTIAL ->
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            DeviceKeyAuthKind.BIOMETRIC ->
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL
        }
        if (!canUseDeviceCredential()) {
            result.error("device_key_no_device_credential", DEVICE_CREDENTIAL_REQUIRED_MESSAGE, null)
            return
        }

        val prompt =
            BiometricPrompt(
                activity,
                ContextCompat.getMainExecutor(activity),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authResult: BiometricPrompt.AuthenticationResult,
                    ) {
                        val authorizedCipher = authResult.cryptoObject?.cipher
                        if (authorizedCipher == null) {
                            result.error(
                                "device_key_auth_failed",
                                "Authentication succeeded but cipher is unavailable.",
                                null,
                            )
                            return
                        }
                        try {
                            onSuccess(authorizedCipher)
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
                .setTitle(activity.getString(R.string.app_name))
                .setSubtitle(AndroidAppStrings.string(activity, promptSubtitle))
                .setAllowedAuthenticators(authenticators)
        prompt.authenticate(
            promptBuilder.build(),
            BiometricPrompt.CryptoObject(cipher),
        )
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

    private enum class DeviceKeyAuthKind(val wire: String) {
        PLAIN("plain"),
        DEVICE_CREDENTIAL("deviceCredential"),
        BIOMETRIC("biometric"),
        ;

        companion object {
            fun fromWire(raw: String): DeviceKeyAuthKind {
                return entries.firstOrNull { it.wire == raw }
                    ?: throw IllegalArgumentException("Unknown keystoreAuthKind: $raw")
            }
        }
    }

    private companion object {
        const val CHANNEL_NAME = "quill_diary/device_key_bridge"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
        private const val DEVICE_CREDENTIAL_REQUIRED_MESSAGE =
            "請先在裝置設定中建立螢幕鎖，才能使用此解鎖方式。"
        private const val BIOMETRIC_ENROLLMENT_REQUIRED_MESSAGE =
            "啟用生物驗證前，請先到裝置設定新增至少一種生物辨識。"
    }
}
