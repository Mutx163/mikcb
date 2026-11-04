package com.mutx163.qingyu.platform

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.pages.sync.CoupleConfigStorePort
import com.mutx163.qingyu.sync.CoupleWebdavConfig

/**
 * [CoupleConfigStorePort] 的**生产实现**（纯 Kotlin，无 `android.*`——`KeyValueStore` 与
 * `SecretCipher` 都是接口，所以本类连 JVM 单测都能跑，只是不在 L0 的模块 classpath 里）。
 *
 * ## 三处口径（去 Dart 核过）
 *
 * 1. **配置本体**：契约 key `couple_webdav_config_v1`（= `CoupleWebdavConfig.PREFS_KEY`），
 *    值是 `toJson()` 的 JSON 对象，与 Dart `couple_webdav_config.dart` 同键同形；
 * 2. **写配置走「读-合并-写」**：设置存档里还有 250+ 个 Dart 侧字段，整体覆盖会静默清空
 *    用户设置（`WebdavConfigStoreImpl` 的 KDoc 记着同一条坑）。这里只覆盖本配置自己的键；
 * 3. **密码绝不进 prefs 明文**：Dart 用 `flutter_secure_storage`（key `couple_webdav_password`），
 *    与云同步的主密码**不是同一个**。本实现同样分成两把：配置键 + 独立密文键
 *    [PASSWORD_BLOB_KEY]，密钥由 AndroidKeyStore 保护（由注入的 cipher 决定）。
 *
 * 换机 / 密钥失效时 [readPassword] 返回 null（cipher 自己吞异常），调用方按
 * 「没存过密码」处理 → 引导重输，而不是把整份配置读崩。
 */
class CoupleConfigStoreImpl(
    private val store: KeyValueStore,
    private val cipher: SecretCipher,
    private val nowMicros: () -> Long = { System.currentTimeMillis() * 1000L },
) : CoupleConfigStorePort {

    override fun loadConfig(): CoupleWebdavConfig {
        val raw = store.getString(CONFIG_KEY)
        if (raw.isNullOrEmpty()) return CoupleWebdavConfig()
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is Map<*, *>) {
            archiveCorrupt()
            return CoupleWebdavConfig()
        }
        val map = LinkedHashMap<String, Any?>()
        for ((key, value) in decoded) {
            if (key is String) map[key] = value
        }
        return try {
            CoupleWebdavConfig.fromJson(map)
        } catch (_: Exception) {
            archiveCorrupt()
            CoupleWebdavConfig()
        }
    }

    override fun saveConfig(config: CoupleWebdavConfig) {
        val merged = LinkedHashMap<String, Any?>()
        val existing = store.getString(CONFIG_KEY)
        if (!existing.isNullOrEmpty()) {
            val decoded = MiniJson.tryParse(existing)
            if (decoded is Map<*, *>) {
                for ((key, value) in decoded) {
                    if (key is String) merged[key] = value
                }
            }
        }
        merged.putAll(config.toJson())
        store.putString(CONFIG_KEY, MiniJson.encode(merged))
    }

    override fun hasStoredPassword(): Boolean =
        !store.getString(PASSWORD_BLOB_KEY).isNullOrEmpty()

    override fun readPassword(): String? =
        store.getString(PASSWORD_BLOB_KEY)?.let { cipher.decrypt(it) }

    override fun storePassword(password: String) {
        store.putString(PASSWORD_BLOB_KEY, cipher.encrypt(password))
    }

    override fun clearPassword() {
        store.remove(PASSWORD_BLOB_KEY)
    }

    private fun archiveCorrupt() {
        store.archiveCorruptAndRemove(CONFIG_KEY, nowMicros())
    }

    companion object {
        /** 契约 key：与 Dart `CoupleWebdavConfig.prefsKey` 逐字一致。 */
        const val CONFIG_KEY: String = CoupleWebdavConfig.PREFS_KEY

        /**
         * 密码密文键。
         *
         * **刻意不等于** Dart 的 `couple_webdav_password`：同名只会让后来者误以为「两个实现
         * 共用一份密码」。旧值**不是读不到**——`applicationId` 已于 2026-10-29 统一为
         * `com.mutx163.qingyu`（`android/app/build.gradle:7`、`:146` 记录 flavor 合并），旧版
         * `FlutterSecureStorage.xml` 仍在同一 UID 下、技术可读；不复用是**成本取舍**（复刻插件
         * 私有格式会随插件升级静默失效）。换了键的代价是用户重输一次，不是静默丢数据
         * （与 `WebdavConfigStoreImpl.PASSWORD_BLOB_KEY` 同一条取舍）。
         */
        const val PASSWORD_BLOB_KEY: String = "couple_webdav_password_blob_v1"
    }
}
