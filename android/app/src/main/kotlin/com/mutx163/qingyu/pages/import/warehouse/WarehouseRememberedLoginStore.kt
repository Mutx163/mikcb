package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.core.MiniJson

/**
 * 「记住的教务账号 / 密码」的落盘层：**只以密文落盘**。
 *
 * ## 为什么必须是密文
 *
 * 这是学校教务系统的登录口令，泄露等于别人能登进用户的教务系统看成绩、改选课。
 * 所以这里**不许**直接 `store.putString(key, password)`：所有写盘路径都先过注入的
 * [encrypt]（生产实现是 `KeystoreSecretCipher`：AndroidKeyStore 里的 AES-256-GCM，
 * 密钥不出密钥库）。JVM 单测注入一个「一定改变内容」的替身，于是
 * 「盘上字节里不含明文」这条断言能在 L0 上跑（与 `WebdavConfigStoreImpl` 同一套做法）。
 *
 * ## 为什么收的是两个函数而不是 `SecretCipher` 接口
 *
 * L0 模块自测（`scripts/test-kotlin-module.ps1`）**不收 `platform/` 目录**（那里是
 * Android/KeyStore 胶水层，见脚本里的共享目录白名单）。本文件属模型层，一引用
 * `platform.SecretCipher` 就会让整个 `pages/import/warehouse` 的 L0 编译直接红。
 * 收函数引用后：模型层零 Android 依赖、照样能在 JVM 上断言「落盘不是明文」，
 * 加密能力仍由平台层注入（`KeystoreSecretCipher::encrypt` / `::decrypt`），没有降级。
 *
 * ## 键名逐字抄 Dart
 *
 * `lib/services/warehouse_import_preferences_service.dart`：
 * - 密文键 `warehouse_secure_remembered_login_<adapterId>`（[SECURE_PREFIX]）
 * - 旧明文键 `warehouse_remembered_login_<adapterId>`（[LEGACY_PREFIX]，**只读一次做迁移，之后只删**）
 *
 * 为什么迁移旧明文而不是直接忽略：老版本 App 把凭据以 JSON 明文写在普通 prefs 里，
 * 那份明文只要还在盘上，就仍然是「明文口令」。迁进密钥库后立刻删掉旧键，等于顺手把
 * 遗留的明文隐患清掉；不迁的话用户会发现自己「之前记的密码全没了」。
 *
 * ## 解不开怎么办
 *
 * [decrypt] 返回 `null` 一律按「没存过」处理，并**删掉解不开的那条密文**
 * （否则每次进页面都白试一次）：换机恢复 / 系统升级 / 用户改锁屏凭证都会让
 * AndroidKeyStore 条目失效，这时该引导用户重输，而不是把登录页炸掉。
 *
 * ## 迁移边界（发布版 v2.1.4.1 的旧密文：读不到，也不主动清）
 *
 * 本类只能读两类键：本仓写的密文（[SECURE_PREFIX]）与旧版**明文**键（[LEGACY_PREFIX]，
 * 读完即删）。发布版把凭据交给 `flutter_secure_storage`，落在**它自己的**文件/Keystore
 * 条目下——键名与加密密钥都不在这里，所以：
 * - **升级用户必须重登一次教务**：旧凭据本版读不出来，这是已拍板的升级行为，不在代码里
 *   伪造「迁移成功」，也不弹假的补救提示（升级清单与更新日志负责告知）；
 * - **旧密文仍留在系统应用数据目录里，本版不主动清除**：没有对应密钥，删了也无法校验
 *   是不是凭据；重登后新密文写在本类自己的键上，旧残留不影响使用。
 *
 * 这两点写在这里是为了防「以为升级能自动带上账号」和「以为进设置清一次就能删干净」两类误判。
 */
class WarehouseRememberedLoginStore(
    private val store: KeyValueStore,
    /** 明文 → 密文（生产 = `KeystoreSecretCipher::encrypt`）。实现必须保证输出与输入不同。 */
    private val encrypt: (String) -> String,
    /** 密文 → 明文；解不开回 `null`（生产 = `KeystoreSecretCipher::decrypt`，内部吞异常）。 */
    private val decrypt: (String) -> String?,
) {

    /** 读已记住的凭据；没有 / 解不开 / 内容坏了都回 `null`（语义 = 「没存过」）。 */
    fun rememberedLogin(adapterId: String): WarehouseRememberedLogin? {
        val key = secureKey(adapterId)
        val blob = store.getString(key)
        if (!blob.isNullOrEmpty()) {
            val plaintext = decrypt(blob)
            val login = plaintext?.let { decodeRememberedLogin(it) }
            if (login != null) {
                dropLegacy(adapterId)
                return login
            }
            // 密钥失效或密文坏了：删掉，别每进一次页面都白失败一次。
            store.remove(key)
        }
        return migrateLegacy(adapterId)
    }

    /**
     * 存凭据：加密后写盘；账号密码都空的视为「清除」。
     *
     * 写完顺手删掉旧明文键——迁移发生在读路径上，但用户也可能**先**存新的再读，
     * 那条旧明文同样不能留。
     */
    fun saveRememberedLogin(adapterId: String, login: WarehouseRememberedLogin) {
        if (login.username.isEmpty() && login.password.isEmpty()) {
            clearRememberedLogin(adapterId)
            return
        }
        store.putString(secureKey(adapterId), encrypt(encodeRememberedLogin(login)))
        dropLegacy(adapterId)
    }

    /** 清除（用户选「不记住」/ 删除学校适配器 / 登出时应调这里）。 */
    fun clearRememberedLogin(adapterId: String) {
        store.remove(secureKey(adapterId))
        dropLegacy(adapterId)
    }

    /**
     * 旧明文键的迁移：读出来、按当前格式重新加密落盘、删掉明文。
     *
     * 解不开（不是合法 JSON / 键被写坏）就只删不留：留着只是把明文继续摆在盘上。
     */
    private fun migrateLegacy(adapterId: String): WarehouseRememberedLogin? {
        val legacyKey = LEGACY_PREFIX + adapterId
        val raw = store.getString(legacyKey)
        if (raw.isNullOrEmpty()) {
            return null
        }
        val login = decodeRememberedLogin(raw)
        store.remove(legacyKey)
        if (login == null) {
            return null
        }
        store.putString(secureKey(adapterId), encrypt(encodeRememberedLogin(login)))
        return login
    }

    private fun dropLegacy(adapterId: String) {
        store.remove(LEGACY_PREFIX + adapterId)
    }

    companion object {
        /** 密文键前缀（Dart `_secureRememberedLoginPrefix` 逐字一致）。 */
        const val SECURE_PREFIX = "warehouse_secure_remembered_login_"

        /** 旧**明文**键前缀（Dart `_rememberedLoginPrefix`）；只用于迁移与删除。 */
        const val LEGACY_PREFIX = "warehouse_remembered_login_"

        /** AndroidKeyStore 里的密钥别名（与 WebDAV 口令分开，互不影响失效范围）。 */
        const val KEY_ALIAS = "mikcb_warehouse_login_v1"

        fun secureKey(adapterId: String): String = SECURE_PREFIX + adapterId

        /**
         * 序列化成与 Dart `WarehouseRememberedLogin.toJson()` 同形状的 JSON
         * （`username` / `password` / `host`）：将来若有工具读这份密文，形状对得上。
         */
        fun encodeRememberedLogin(login: WarehouseRememberedLogin): String = MiniJson.encode(
            linkedMapOf(
                "username" to login.username,
                "password" to login.password,
                "host" to login.host,
            ),
        )

        /**
         * 解析凭据 JSON；形状不对（不是对象 / 两个字段都空）回 `null`。
         *
         * 与 Dart `_decodeRememberedLogin` 同口径：空账号空密码视为「没有存过」，
         * 不当成「存了一个空的」。
         */
        fun decodeRememberedLogin(raw: String?): WarehouseRememberedLogin? {
            val text = raw?.trim().orEmpty()
            if (text.isEmpty()) {
                return null
            }
            val parsed = MiniJson.tryParse(text) as? Map<*, *> ?: return null
            val login = WarehouseRememberedLogin(
                username = (parsed["username"] as? String).orEmpty(),
                password = (parsed["password"] as? String).orEmpty(),
                host = (parsed["host"] as? String).orEmpty(),
            )
            if (login.username.isEmpty() && login.password.isEmpty()) {
                return null
            }
            return login
        }
    }
}
