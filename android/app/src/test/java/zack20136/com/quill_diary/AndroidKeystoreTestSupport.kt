package zack20136.com.quill_diary

import android.security.keystore.KeyGenParameterSpec
import java.io.InputStream
import java.io.OutputStream
import java.security.Key
import java.security.KeyStore
import java.security.KeyStoreSpi
import java.security.Provider
import java.security.SecureRandom
import java.security.Security
import java.security.cert.Certificate
import java.security.spec.AlgorithmParameterSpec
import java.util.Collections
import java.util.Date
import java.util.concurrent.ConcurrentHashMap
import javax.crypto.KeyGeneratorSpi
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec

/** JVM 沒有 AndroidKeyStore；此替身只驗證儲存流程，不代表硬體金鑰安全驗證。 */
object AndroidKeystoreTestSupport {
    val keys = ConcurrentHashMap<String, Key>()

    fun install() {
        keys.clear()
        if (Security.getProvider("AndroidKeyStore")?.info == "JVM test keystore") {
            Security.removeProvider("AndroidKeyStore")
        }
        if (Security.getProvider("AndroidKeyStore") == null) {
            Security.addProvider(
                object : Provider("AndroidKeyStore", 1.0, "JVM test keystore") {
                    init {
                        put("KeyStore.AndroidKeyStore", MemoryAndroidKeyStoreSpi::class.java.name)
                        put("KeyGenerator.AES", MemoryAndroidAesKeyGeneratorSpi::class.java.name)
                    }
                },
            )
        }
    }
}

class MemoryAndroidAesKeyGeneratorSpi : KeyGeneratorSpi() {
    private var alias = ""
    private var size = 256
    private var random = SecureRandom()
    override fun engineInit(random: SecureRandom) {
        this.random = random
    }

    override fun engineInit(keysize: Int, random: SecureRandom) {
        size = keysize
        this.random = random
    }

    override fun engineInit(params: AlgorithmParameterSpec, random: SecureRandom) {
        val spec = params as KeyGenParameterSpec
        alias = spec.keystoreAlias
        size = spec.keySize
        this.random = random
    }

    override fun engineGenerateKey(): SecretKey {
        val bytes = ByteArray(size / 8).also(random::nextBytes)
        return SecretKeySpec(bytes, "AES").also { AndroidKeystoreTestSupport.keys[alias] = it }
    }
}

class MemoryAndroidKeyStoreSpi : KeyStoreSpi() {
    override fun engineGetEntry(
        alias: String,
        protection: KeyStore.ProtectionParameter?,
    ): KeyStore.Entry? =
        (AndroidKeystoreTestSupport.keys[alias] as? SecretKey)?.let { KeyStore.SecretKeyEntry(it) }

    override fun engineGetKey(alias: String, password: CharArray?): Key? =
        AndroidKeystoreTestSupport.keys[alias]

    override fun engineGetCertificateChain(alias: String): Array<Certificate>? = null
    override fun engineGetCertificate(alias: String): Certificate? = null
    override fun engineGetCreationDate(alias: String): Date? =
        if (engineContainsAlias(alias)) Date(0) else null

    override fun engineSetKeyEntry(
        alias: String,
        key: Key,
        password: CharArray?,
        chain: Array<out Certificate>?,
    ) {
        AndroidKeystoreTestSupport.keys[alias] = key
    }

    override fun engineSetKeyEntry(alias: String, key: ByteArray, chain: Array<out Certificate>?) =
        throw UnsupportedOperationException()
    override fun engineSetCertificateEntry(alias: String, cert: Certificate) =
        throw UnsupportedOperationException()

    override fun engineDeleteEntry(alias: String) {
        AndroidKeystoreTestSupport.keys.remove(alias)
    }

    override fun engineAliases() = Collections.enumeration(AndroidKeystoreTestSupport.keys.keys)
    override fun engineContainsAlias(alias: String) = AndroidKeystoreTestSupport.keys.containsKey(alias)
    override fun engineSize() = AndroidKeystoreTestSupport.keys.size
    override fun engineIsKeyEntry(alias: String) = engineContainsAlias(alias)
    override fun engineIsCertificateEntry(alias: String) = false
    override fun engineGetCertificateAlias(cert: Certificate): String? = null
    override fun engineStore(stream: OutputStream?, password: CharArray?) {}
    override fun engineLoad(stream: InputStream?, password: CharArray?) {}
}
