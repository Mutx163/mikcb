package com.mutx163.qingyu.platform

import android.content.Context

/**
 * 旧版（Dart `flutter_secure_storage`）凭据**只读探测器**。
 *
 * 升级后新版的 Kotlin 密文键（`mikcb_webdav_password_v2` /
 * `qingyu_couple_webdav`）里没有密码，但旧插件的
 * `FlutterSecureStorage` prefs 文件仍在同一 UID 下。这里只回答「旧键在不在」，
 * **不解析文件内容、不尝试解密**——自动迁移已被裁决为不做（成本大于重输一次），
 * 探测只用于触发一次「请重输网盘密码」提示。
 *
 * 键名按**后缀**匹配，不拼插件私有前缀：`flutter_secure_storage` 的键前缀是
 * `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg` + `_`，属于插件私有格式，
 * 版本升级可能变化；后缀 `webdav_sync_password` / `couple_webdav_password` 是我们自己的键名，
 * 稳定得多。
 */
interface LegacyCredentialProbe {

    /**
     * 旧插件 prefs 里是否存在以 [keySuffix] 结尾的键。
     *
     * 任何读取异常都按「不存在」处理：探测失败最多是不弹提示（退回现状），
     * 不能误弹、更不能把页面搞崩。
     */
    fun hasLegacyPassword(keySuffix: String): Boolean
}

/**
 * Android 实现：读 `FlutterSecureStorage` 这个 SharedPreferences 文件的键名集合。
 *
 * 只读 `all.keys`，不反序列化任何值；整个读取过程吞 `Throwable`（含 prefs 文件损坏）。
 */
class AndroidLegacyCredentialProbe(context: Context) : LegacyCredentialProbe {

    private val appContext = context.applicationContext

    override fun hasLegacyPassword(keySuffix: String): Boolean = try {
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .all
            .keys
            .any { it.endsWith(keySuffix) }
    } catch (_: Throwable) {
        false
    }

    private companion object {
        /** `flutter_secure_storage` Android 默认存储文件名。 */
        const val PREFS_NAME = "FlutterSecureStorage"
    }
}
