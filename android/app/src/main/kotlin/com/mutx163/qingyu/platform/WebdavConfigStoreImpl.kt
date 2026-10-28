package com.mutx163.qingyu.platform

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.corruptBackupKey
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.pages.sync.WebdavConfigStore
import com.mutx163.qingyu.sync.WebdavSyncConfig

/**
 * [WebdavConfigStore] 的**生产实现**（纯 Kotlin，无 `android.*`——所以能在 JVM 单测里跑）。
 *
 * 云同步页此前一直是「裸重载 + 16 个空回调 + 假数据」；控制器重载
 * （`CloudSyncController`）早就写好了，缺的就是这个实现与快照存储。
 *
 * ## 三处口径（都去 Dart 核过，不是猜的）
 *
 * 1. **配置本体**：契约 key `webdav_sync_config_v1`（= `WebdavSyncConfig.PREFS_KEY`），
 *    值是 `toJson()` 的 JSON 对象，与 Dart `webdav_sync_config.dart` 同键同形。
 * 2. **写配置走「读-合并-写」**：设置存档里有 250+ 个 Dart 侧字段，整体覆盖会**静默清空**
 *    用户设置（本仓已有守卫测试在盯这条）。这里只覆盖 `WebdavSyncConfig` 自己拥有的键。
 * 3. **密码绝不进 prefs 明文**：Dart 用 `flutter_secure_storage`
 *    （`webdav_sync_credentials_store.dart:7` 的 key = `webdav_sync_password`；
 *    插件 Android 默认 `useEncryptedSharedPreferences=false`，走**自定义 AES-GCM 密码器 +
 *    Android KeyStore 保护的密钥**，见认领文件里的核对记录）。
 *    本实现用**同一个机制类别**（平台密钥库 + AES-GCM），但**另起一个键**（见 [PASSWORD_BLOB_KEY]）。
 *
 * @param store 键值存储（生产 = `PrefsKeyValueStore`，单测 = `InMemoryKeyValueStore`）。
 * @param cipher 密钥加密器（生产 = [KeystoreSecretCipher]，单测 = 可逆替身）。
 * @param nowMicros 坏值留档的时间戳来源，可注入以便断言留档名。
 */
class WebdavConfigStoreImpl(
    private val store: KeyValueStore,
    private val cipher: SecretCipher,
    private val nowMicros: () -> Long = { System.currentTimeMillis() * 1000L },
) : WebdavConfigStore {

    // ---------- 配置 ----------

    override fun loadConfig(): WebdavSyncConfig {
        val raw = store.getString(CONFIG_KEY)
        if (raw.isNullOrEmpty()) return WebdavSyncConfig()
        val decoded = MiniJson.tryParse(raw)
        if (decoded !is Map<*, *>) {
            archiveCorrupt(CONFIG_KEY)
            return WebdavSyncConfig()
        }
        val map = LinkedHashMap<String, Any?>()
        for ((key, value) in decoded) {
            if (key is String) map[key] = value
        }
        return try {
            WebdavSyncConfig.fromJson(map)
        } catch (_: Exception) {
            // 单键坏值不该把整份配置拉回默认（fromJson 本身已逐键容错，这里是兜底）。
            archiveCorrupt(CONFIG_KEY)
            WebdavSyncConfig()
        }
    }

    /** **读-合并-写**：只覆盖本配置拥有的键，盘上其余键（Dart 侧 250+）原样保留。 */
    override fun saveConfig(config: WebdavSyncConfig) {
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

    // ---------- 密码（只存密文） ----------

    override fun hasStoredPassword(): Boolean =
        !store.getString(PASSWORD_BLOB_KEY).isNullOrEmpty()

    override fun storePassword(password: String) {
        store.putString(PASSWORD_BLOB_KEY, cipher.encrypt(password))
    }

    override fun clearPassword() {
        store.remove(PASSWORD_BLOB_KEY)
    }

    /**
     * 读出密码（**不是** [WebdavConfigStore] 接口的一部分，供宿主在「已存过密码 → 直接重连」
     * 这类路径上用）。解不开（密钥失效/换机）返回 null，调用方按「没存过」处理。
     */
    fun readPassword(): String? =
        store.getString(PASSWORD_BLOB_KEY)?.let { cipher.decrypt(it) }

    // ---------- 设备标签（Dart 存在普通 prefs 里） ----------

    /** Dart `webdav_sync_credentials_store.dart:80-87`：`SharedPreferences` 的 `webdav_sync_device_label`。 */
    fun readDeviceLabel(): String? = store.getString(DEVICE_LABEL_KEY)?.trim()?.ifEmpty { null }

    fun writeDeviceLabel(label: String) {
        store.putString(DEVICE_LABEL_KEY, label.trim())
    }

    fun deleteDeviceLabel() {
        store.remove(DEVICE_LABEL_KEY)
    }

    // ---------- 内部 ----------

    private fun archiveCorrupt(key: String) {
        val backup = corruptBackupKey(key, nowMicros())
        store.archiveCorruptAndRemove(key, nowMicros())
        // 同 key 旧留档只留最近一份（与 TimetableStore 同一口径）。
        val prefix = "${key}_corrupt_backup_"
        store.keys().filter { it.startsWith(prefix) && it != backup }.forEach { store.remove(it) }
    }

    companion object {
        /** 契约 key：与 `WebdavSyncConfig.PREFS_KEY` 逐字一致（Dart `webdav_sync_config.dart`）。 */
        const val CONFIG_KEY = WebdavSyncConfig.PREFS_KEY

        /**
         * 密码密文的契约 key。
         *
         * **为什么不复用 Dart 的 `webdav_sync_password`**：
         * Dart 那个值存在 `flutter_secure_storage` 自己的 prefs 文件里、用插件私有的
         * AES-GCM + KeyStore 密钥包装格式（默认 `useEncryptedSharedPreferences=false`）。
         * 要「读到同一份值」就得在 Kotlin 里复刻那套私有格式（密钥别名、包装算法、
         * IV 序列化、`FlutterSecureStorageConfiguration:<name>` 里的算法/迁移标记），
         * 一旦插件升级就是静默失效——比重新输入一次密码糟得多。
         *
         * 而且**当前根本读不到**：`composeUi` 壳是**独立包名**（`.ui`），它的应用私有目录与
         * KeyStore 命名空间和正式版是两个，跨包共享在构造上就不可能。
         *
         * 所以这里用自己的一把 KeyStore 密钥 + 自己的键名，并把 `v2` 写进键名：
         * Phase 5（正式包接管）时若要做一次性迁移，能一眼区分「插件格式」与「我们的格式」。
         * 代价写清楚：**用户需要重新输入一次网盘密码**（不是静默丢数据）。
         */
        const val PASSWORD_BLOB_KEY = "mikcb_webdav_password_v2"

        /** Dart 同名字段（普通 prefs，非加密）。 */
        const val DEVICE_LABEL_KEY = "webdav_sync_device_label"
    }
}
