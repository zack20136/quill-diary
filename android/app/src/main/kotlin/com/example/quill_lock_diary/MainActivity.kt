package com.example.quill_lock_diary

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
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
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "ensureKey" -> result.success(ensureKey(call))
                    "hasKey" -> result.success(hasKey(call))
                    "wrapWithDeviceKey" -> result.success(wrapWithDeviceKey(call))
                    "unwrapWithDeviceKey" -> result.success(unwrapWithDeviceKey(call))
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
        val alias = aliasFor(vaultId)
        if (!hasAlias(alias)) {
            createKey(alias)
        }
        return mapOf(
            "slotId" to slotIdFor(vaultId),
            "platform" to platformLabel(),
        )
    }

    private fun hasKey(call: MethodCall): Boolean {
        return hasAlias(aliasFor(requireVaultId(call)))
    }

    private fun wrapWithDeviceKey(call: MethodCall): Map<String, Any> {
        val vaultId = requireVaultId(call)
        ensureAlias(vaultId)
        val plaintext = requireByteArray(call.argument<List<Int>>("plaintext"), "plaintext")
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, requireSecretKey(vaultId))
        val ciphertext = cipher.doFinal(plaintext)
        return mapOf(
            "slotId" to slotIdFor(vaultId),
            "nonce" to encode(cipher.iv),
            "ciphertext" to encode(ciphertext),
            "platform" to platformLabel(),
        )
    }

    private fun unwrapWithDeviceKey(call: MethodCall): List<Int> {
        val vaultId = requireVaultId(call)
        val slotId = call.argument<String>("slotId") ?: ""
        if (slotId != slotIdFor(vaultId)) {
            throw IllegalArgumentException("Device slot id mismatch.")
        }
        val nonce = decode(requireString(call, "nonce"))
        val ciphertext = decode(requireString(call, "ciphertext"))
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            requireSecretKey(vaultId),
            GCMParameterSpec(GCM_TAG_BITS, nonce),
        )
        return cipher.doFinal(ciphertext).map { byteValue ->
            byteValue.toInt() and 0xFF
        }
    }

    private fun deleteKey(call: MethodCall) {
        val alias = aliasFor(requireVaultId(call))
        val keyStore = loadKeyStore()
        if (keyStore.containsAlias(alias)) {
            keyStore.deleteEntry(alias)
        }
    }

    private fun ensureAlias(vaultId: String) {
        if (!hasAlias(aliasFor(vaultId))) {
            createKey(aliasFor(vaultId))
        }
    }

    private fun createKey(alias: String) {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE,
        )
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .build()
        keyGenerator.init(spec)
        keyGenerator.generateKey()
    }

    private fun hasAlias(alias: String): Boolean {
        return loadKeyStore().containsAlias(alias)
    }

    private fun requireSecretKey(vaultId: String): SecretKey {
        val entry = loadKeyStore().getEntry(aliasFor(vaultId), null)
            ?: throw IllegalStateException("Keystore alias is missing.")
        if (entry !is KeyStore.SecretKeyEntry) {
            throw IllegalStateException("Keystore entry is not a secret key.")
        }
        return entry.secretKey
    }

    private fun loadKeyStore(): KeyStore {
        return KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    }

    private fun aliasFor(vaultId: String): String {
        return "quill_lock_diary.device_wrap.$vaultId"
    }

    private fun slotIdFor(vaultId: String): String {
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

    companion object {
        private const val CHANNEL_NAME = "quill_lock_diary/device_key_bridge"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128
    }
}
