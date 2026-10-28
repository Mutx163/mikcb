package com.mutx163.qingyu.platform

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * [SecretCipher] 的 Android 实现：**平台密钥库（AndroidKeyStore）+ AES-256-GCM**。
 *
 * ## 与 Dart 侧的关系（去核过，不是猜的）
 *
 * Dart 用 `flutter_secure_storage` 10.3.x。其 Android 侧默认
 * `useEncryptedSharedPreferences=false`（`FlutterSecureStorageConfig.java:20`），走的是插件
 * **自定义密码器**：存储算法 `AES_GCM_NoPadding`、密钥包装 `RSA_ECB_OAEPwithSHA_256andMGF1Padding`
 * （`DEFAULT_STORAGE_CIPHER_ALGORITHM` / `DEFAULT_KEY_CIPHER_ALGORITHM`），密钥由 AndroidKeyStore
 * 保护，值写在名为 `FlutterSecureStorage` 的 prefs 里、key 带固定前缀
 * `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg`，另有
 * `FlutterSecureStorageConfiguration:<name>` 存算法/迁移标记。
 *
 * 本类**不复刻那套私有格式**，只对齐「机制类别」：同样是平台密钥库 + AES-GCM。
 * 理由（也写在 [WebdavConfigStoreImpl.PASSWORD_BLOB_KEY] 的 KDoc 里）：复刻插件的私有
 * 密钥包装格式会随插件升级静默失效；而且 `composeUi` 壳是独立包名，本来就读不到正式版的
 * 密钥库命名空间与私有目录。代价是**用户要重新输一次密码**，不是静默丢数据。
 *
 * ## 密钥失效怎么办
 *
 * [decrypt] 一律**吞掉异常返回 null**（与 Dart `readPassword` 的 `on PlatformException → null`
 * 同一口径）：换机恢复 / 系统升级 / 用户改锁屏凭证都会让 KeyStore 条目失效，
 * 那时应退化为「当作没存过、引导重输」，而不是把配置加载炸掉。
 *
 * ⚠️ 本类**只能真机验**（JVM 单测没有 AndroidKeyStore）。JVM 侧验的是
 * 「落盘内容不含明文」这条组合断言，见 `WebdavConfigStoreImplTest`。
 */
class KeystoreSecretCipher(
    private val alias: String = DEFAULT_ALIAS,
) : SecretCipher {

    override fun encrypt(plaintext: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val body = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        val blob = cipher.iv + body
        val encoded = Base64.encodeToString(blob, Base64.NO_WRAP)
        // 防御性断言：密文里出现明文说明加密没生效（比如算法被替换成恒等变换）。
        require(!encoded.contains(plaintext)) { "cipher output must not contain plaintext" }
        return encoded
    }

    override fun decrypt(ciphertext: String): String? = try {
        val blob = Base64.decode(ciphertext, Base64.NO_WRAP)
        if (blob.size <= IV_BYTES) {
            null
        } else {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey(),
                GCMParameterSpec(TAG_BITS, blob, 0, IV_BYTES),
            )
            String(cipher.doFinal(blob, IV_BYTES, blob.size - IV_BYTES), Charsets.UTF_8)
        }
    } catch (_: Exception) {
        // 密钥失效 / 密文损坏：按「没存过」处理，由调用方引导重输。
        null
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getEntry(alias, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val DEFAULT_ALIAS = "mikcb_webdav_password_v2"
        const val IV_BYTES = 12
        const val TAG_BITS = 128
    }
}
