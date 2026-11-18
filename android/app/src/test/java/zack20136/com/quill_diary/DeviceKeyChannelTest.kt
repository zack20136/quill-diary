package zack20136.com.quill_diary

import android.util.Base64
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class DeviceKeyChannelTest {
    private val channel = DeviceKeyChannel(FragmentActivity())
    private val vaultId = "existing-vault"
    private val slotId = "dev_android_keystore_plain_$vaultId"
    private val alias = "quill_diary.device_wrap.plain.$vaultId"
    private val plaintext = listOf(0, 65, 128, 255)

    @Before
    fun setUp() {
        AndroidKeystoreTestSupport.install()
    }

    @Test
    fun 包裝後可透過原通道解包無號位元組() {
        val wrapped = call(
            "wrapWithDeviceKey",
            mapOf("vaultId" to vaultId, "keystoreAuthKind" to "plain", "plaintext" to plaintext),
        ).value as Map<*, *>

        assertEquals(setOf("slotId", "nonce", "ciphertext", "platform"), wrapped.keys)
        assertEquals(slotId, wrapped["slotId"])
        assertEquals(plaintext, unwrap(wrapped))
    }

    @Test
    fun 舊裝置封裝可解包並以新隨機數重新包裝() {
        val key = SecretKeySpec(ByteArray(32) { it.toByte() }, "AES")
        AndroidKeystoreTestSupport.keys[alias] = key
        val oldNonce = ByteArray(12) { it.toByte() }
        val existingCipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(128, oldNonce))
        }
        val oldWrapped = mapOf(
            "slotId" to slotId,
            "nonce" to Base64.encodeToString(oldNonce, Base64.NO_WRAP),
            "ciphertext" to Base64.encodeToString(
                existingCipher.doFinal(plaintext.map(Int::toByte).toByteArray()),
                Base64.NO_WRAP,
            ),
        )
        assertEquals(plaintext, unwrap(oldWrapped))

        val rewrapped = call(
            "rewrapTrustedRecoveryKey",
            mapOf(
                "vaultId" to vaultId,
                "sourceSlotId" to slotId,
                "keystoreAuthKind" to "plain",
                "nonce" to oldWrapped["nonce"],
                "ciphertext" to oldWrapped["ciphertext"],
            ),
        ).value as Map<*, *>
        assertEquals(plaintext, rewrapped["recoveryWrapKey"])
        assertNotEquals(oldWrapped["nonce"], rewrapped["nonce"])
        assertEquals(plaintext, unwrap(rewrapped))
    }

    @Test
    fun 其他日記庫的裝置槽位會拒絕解包() {
        val result = CapturedChannelResult()
        channel.handleCall(
            MethodCall("unwrapWithDeviceKey", mapOf("vaultId" to "another-vault", "slotId" to slotId)),
            result,
        )
        assertEquals("device_key_invalidated", result.errorCode)
        assertEquals(0, result.successCount)
    }

    private fun unwrap(wrapped: Map<*, *>): Any? =
        call(
            "unwrapWithDeviceKey",
            mapOf(
                "vaultId" to vaultId,
                "slotId" to wrapped["slotId"],
                "nonce" to wrapped["nonce"],
                "ciphertext" to wrapped["ciphertext"],
            ),
        ).value

    private fun call(method: String, arguments: Map<String, Any?>): CapturedChannelResult =
        CapturedChannelResult().also { result ->
            channel.handleCall(MethodCall(method, arguments), result)
            assertNull(result.errorCode)
            assertEquals(1, result.successCount)
        }
}
