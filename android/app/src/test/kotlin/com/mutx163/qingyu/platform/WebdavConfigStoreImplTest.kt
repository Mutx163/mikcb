package com.mutx163.qingyu.platform

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.WebdavSyncConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [WebdavConfigStoreImpl] 的读写 / 合并写 / **密码不落明文** 测试（纯 JVM）。
 *
 * ## 关于「密码不落明文」这条断言怎么才算数
 *
 * 真正的加密在 `KeystoreSecretCipher` 里，用 AndroidKeyStore——JVM 单测里没有它，
 * 所以这里注入一个**可逆替身**，断言的是**组合关系**：
 *
 * > 存储层写下去的任何字节，都必须是「密码器输出」，而**不是**用户输入的明文。
 *
 * 也就是说这条测试保证的是「**这一层**不会把明文写盘」（哪怕密码器换成真的，
 * 落盘的也只是密码器的输出）。真密码器的行为只能在真机验，认领文件里列了对照项。
 */
class WebdavConfigStoreImplTest {

    private val fixedMicros = 1_700_000_000_000_000L

    /** 可逆替身：输出 = 前缀 + 反转明文（保证与明文不同，便于断言）。 */
    private class ReversibleTestCipher : SecretCipher {
        override fun encrypt(plaintext: String): String = "$PREFIX${plaintext.reversed()}"
        override fun decrypt(ciphertext: String): String? =
            if (ciphertext.startsWith(PREFIX)) {
                ciphertext.removePrefix(PREFIX).reversed()
            } else {
                null
            }

        companion object {
            const val PREFIX = "test-blob:"
        }
    }

    /** 模拟「密钥失效 / 换机恢复」：解不开。 */
    private class UndecryptableCipher : SecretCipher {
        override fun encrypt(plaintext: String): String = "opaque-blob"
        override fun decrypt(ciphertext: String): String? = null
    }

    private fun newStore(initial: Map<String, String> = emptyMap()): Pair<InMemoryKeyValueStore, WebdavConfigStoreImpl> {
        val raw = InMemoryKeyValueStore(initial)
        return raw to WebdavConfigStoreImpl(raw, ReversibleTestCipher(), nowMicros = { fixedMicros })
    }

    // ---------- 配置 ----------

    @Test
    fun loadConfigOnMissingKeyReturnsDartDefaults() {
        val (_, store) = newStore()

        val config = store.loadConfig()

        assertEquals(WebdavSyncConfig.DEFAULT_JIANGUOYUN_BASE_URL, config.baseUrl)
        assertEquals(WebdavSyncConfig.DEFAULT_REMOTE_FOLDER, config.remoteFolder)
        assertFalse(config.enabled)
    }

    @Test
    fun saveConfigRoundTripsThroughTheDartKey() {
        val (raw, store) = newStore()
        val config = WebdavSyncConfig(
            enabled = true,
            baseUrl = "https://dav.example.com/dav/",
            remoteFolder = "/Apps/qingyu-sync/",
            username = "alice",
            maxBackupCount = 7,
        )

        store.saveConfig(config)

        // 契约 key 必须与 Dart 一致（WebdavSyncConfig.PREFS_KEY）。
        assertTrue(raw.rawSnapshot().containsKey("flutter.${WebdavSyncConfig.PREFS_KEY}"))
        val loaded = store.loadConfig()
        assertEquals("https://dav.example.com/dav/", loaded.baseUrl)
        assertEquals("alice", loaded.username)
        assertEquals(7, loaded.maxBackupCount)
        assertTrue(loaded.enabled)
    }

    @Test
    fun saveConfigMergesAndKeepsUnknownKeys() {
        // 设置存档里 Dart 侧有 250+ 个我们不认识的键；整体覆盖会静默清空用户设置。
        val (raw, store) = newStore(
            mapOf(
                WebdavSyncConfig.PREFS_KEY to
                    """{"enabled":false,"username":"old","cornerRadius":22,
                       "themeSeedColor":"#FF5722","nested":{"a":[1,2]}}""",
            ),
        )

        store.saveConfig(WebdavSyncConfig(enabled = true, username = "new"))

        val written = MiniJson.parse(
            raw.getString(WebdavSyncConfig.PREFS_KEY)!!,
        ) as Map<*, *>
        assertEquals(22, (written["cornerRadius"] as Number).toInt())
        assertEquals("#FF5722", written["themeSeedColor"])
        assertEquals("""{"a":[1,2]}""", MiniJson.encode(written["nested"]))
        // 本层拥有的键确实改了。
        assertEquals(true, written["enabled"])
        assertEquals("new", written["username"])
    }

    @Test
    fun corruptConfigIsArchivedAndFallsBackToDefaults() {
        val (raw, store) = newStore(mapOf(WebdavSyncConfig.PREFS_KEY to "[1,2,3]"))

        val config = store.loadConfig()

        assertEquals(WebdavSyncConfig.DEFAULT_REMOTE_FOLDER, config.remoteFolder)
        assertEquals(
            "[1,2,3]",
            raw.rawSnapshot()["flutter.${WebdavSyncConfig.PREFS_KEY}_corrupt_backup_$fixedMicros"],
        )
        assertFalse(raw.contains(WebdavSyncConfig.PREFS_KEY))
    }

    // 密码（只存密文；键名与 Dart 的 flutter_secure_storage 不同，见实现里的 KDoc）

    @Test
    fun passwordIsNeverPersistedInPlaintext() {
        val (raw, store) = newStore()
        val password = "s3cr3t-" + "坚果云-" + "pw"

        store.storePassword(password)

        // ① 整份盘上内容里，任何一条值都不许包含明文（含我们自己的键、含别人的键）。
        val leaked = raw.rawSnapshot().filterValues { it.contains(password) }
        assertTrue("落盘内容里出现了明文密码：$leaked", leaked.isEmpty())
        // ② 也不许出现「明文出现在任何键名里」这种荒唐情况。
        assertTrue(raw.rawSnapshot().keys.none { it.contains(password) })
        // ③ 密文确实写进去了，而且能解回来（否则「没明文」可能只是「什么都没存」）。
        assertTrue(store.hasStoredPassword())
        assertEquals(password, store.readPassword())
    }

    @Test
    fun hasStoredPasswordIsFalseBeforeStoringAndAfterClearing() {
        val (_, store) = newStore()
        assertFalse(store.hasStoredPassword())

        store.storePassword("pw")
        assertTrue(store.hasStoredPassword())

        store.clearPassword()
        assertFalse(store.hasStoredPassword())
        assertNull(store.readPassword())
    }

    @Test
    fun readPasswordReturnsNullWhenKeyIsGoneButFlagStillTrue() {
        // 密钥失效（换机恢复/系统升级）：解不开就按「没存过」处理，不抛异常。
        val raw = InMemoryKeyValueStore()
        val store = WebdavConfigStoreImpl(raw, UndecryptableCipher(), nowMicros = { fixedMicros })

        store.storePassword("pw")

        assertTrue("密文还在盘上，所以「存过」为真", store.hasStoredPassword())
        assertNull("但解不开时读回 null，引导重输", store.readPassword())
    }

    @Test
    fun passwordBlobKeyIsDistinctFromTheDartSecureStorageKey() {
        // 我们**故意不复用** Dart 的 webdav_sync_password（那是 flutter_secure_storage 的私有格式）。
        // 键名不同是这条决策的可检查证据。
        assertFalse(
            WebdavConfigStoreImpl.PASSWORD_BLOB_KEY.contains("webdav_sync_password"),
        )
    }

    // ---------- 设备标签 ----------

    @Test
    fun deviceLabelRoundTripsTrimmedAndUsesTheDartKey() {
        val (raw, store) = newStore()

        store.writeDeviceLabel("  我的手机  ")

        assertEquals("我的手机", store.readDeviceLabel())
        assertEquals("我的手机", raw.getString("webdav_sync_device_label"))

        store.deleteDeviceLabel()
        assertNull(store.readDeviceLabel())
    }
}
