package com.mutx163.qingyu.app

import com.mutx163.qingyu.FlutterPrefsCodec

/**
 * Phase 3.5 · L1：**冻结格式的键值存储抽象**（2026-10-28 定稿，签名冻结）。
 *
 * ## 为什么要有这一层
 *
 * Phase 3 把页面搬完了，但没有任何东西给它们提供数据——`TimetableCoursePort` 是个
 * **全仓 0 实现的接口**，壳里 137 处回调是空的。这一层是接线的地基：
 * 上层（仓储）只跟本接口打交道，于是**能在 JVM 上完整测出读写语义**，
 * 而 Android 的 `SharedPreferences` 细节被挡在 [PrefsKeyValueStore] 里。
 *
 * ## 两条铁律
 *
 * 1. **本接口收的是「契约 key」，不带前缀**（如 `timetable_profiles`）。
 *    Dart 侧 `flutter.` 前缀由插件自动加，**Kotlin 侧必须显式加**——这一步在实现里做，
 *    调用方永远不要自己拼前缀（见[数据契约](../docs/plans/2026-10-26-data-contract.md) §1.1）。
 * 2. **`List<String>` 一律走 [FlutterPrefsCodec]**，调用方不许自己 Base64。
 *    本仓 4 个生产 key 用它：`courses`（legacy 只读）、`teacher_records`、
 *    `location_records`、`warehouse_recent_school_ids`。
 *
 * ## 为什么 `archiveCorruptAndRemove` 要收时间戳
 *
 * Dart 侧用「微秒时间戳」给损坏值留档（`storage_service.dart:557-576`）。
 * 时间戳由**调用方传入**而不是在这里取 `System.currentTimeMillis()`，
 * 是为了让「留档名对不对」能在 JVM 上被断言——否则测试只能写「大致像」。
 */
interface KeyValueStore {

    fun getString(key: String): String?

    /** 键不存在或类型不符时返回 [default]。 */
    fun getInt(key: String, default: Int): Int

    /** 键不存在或类型不符时返回 [default]。 */
    fun getBool(key: String, default: Boolean): Boolean

    /**
     * 读 `List<String>`：**返回值已解码**。
     *
     * 返回 `null` 只表示「键不存在」；**解码失败要抛**，不许静默返回空列表——
     * 空列表是合法数据（用户真的没有课），与「数据坏了」必须区分开，
     * 否则坏数据会被当成空课表覆盖掉。
     */
    fun getStringList(key: String): List<String>?

    fun putString(key: String, value: String)

    fun putInt(key: String, value: Int)

    fun putBool(key: String, value: Boolean)

    fun putStringList(key: String, value: List<String>)

    fun remove(key: String)

    fun contains(key: String): Boolean

    /**
     * **损坏值自愈**：把原值留档到 [corruptBackupKey] 再删原 key，返回留档用的 key。
     *
     * 与 Dart 同口径：坏数据必须留档，不能静默吞掉（否则用户数据无声消失、
     * 事后连「坏在哪」都查不到）。[micros] 由调用方给，便于断言。
     */
    fun archiveCorruptAndRemove(key: String, micros: Long): String

    /** 当前存在的**契约 key**（不含前缀），供损坏扫描与对账用。 */
    fun keys(): Set<String>
}

/** 留档 key 的命名：`{key}_corrupt_backup_{微秒时间戳}`（Dart `storage_service.dart:557`）。 */
fun corruptBackupKey(key: String, micros: Long): String = "${key}_corrupt_backup_$micros"

/**
 * 冻结格式的**编码规则**（纯 Kotlin，无 Android 依赖）。
 *
 * 抽出来是为了让 [InMemoryKeyValueStore] 与 `PrefsKeyValueStore` 共用同一套规则：
 * 两边规则若各写一份，「测试用的内存实现」就会比真实现宽松，测出来的绿是假的。
 */
object FrozenValueCodec {

    /** 所有 key 的落盘前缀（Dart 插件自动加的那一段）。 */
    const val KEY_PREFIX = "flutter."

    /** 契约 key → 落盘 key。 */
    fun physicalKey(key: String): String = KEY_PREFIX + key

    /** 落盘 key → 契约 key；不属于本前缀的返回 null（原生侧自有 key 不归我们管）。 */
    fun logicalKey(physicalKey: String): String? =
        physicalKey.removePrefix(KEY_PREFIX).takeIf { physicalKey.startsWith(KEY_PREFIX) }

    fun encodeStringList(list: List<String>): String = FlutterPrefsCodec.encodeStringList(list)

    fun decodeStringList(encoded: String): List<String> = FlutterPrefsCodec.decodeStringList(encoded)

    fun encodeDouble(value: Double): String = FlutterPrefsCodec.encodeDouble(value)

    fun decodeDouble(encoded: String): Double = FlutterPrefsCodec.decodeDouble(encoded)
}

/**
 * [KeyValueStore] 的**内存实现**。
 *
 * ## 它存在的唯一理由是「能在 JVM 上测」
 *
 * Gradle 的 JVM 单测里没有 `SharedPreferences`，所以仓储层的读写语义只能靠一个
 * 忠实的内存替身来验证。它**按真实现的同一套规则**处理前缀与编码
 * （经 [FrozenValueCodec]），所以在这里测出来的行为对真实现同样成立。
 *
 * ⚠️ 它**不是**生产实现，别在 App 代码里用它。
 */
class InMemoryKeyValueStore(
    initial: Map<String, String> = emptyMap(),
) : KeyValueStore {

    /** 落盘 key → 原始字符串值（与真实现一致：只存字符串）。 */
    private val raw = LinkedHashMap<String, String>()

    init {
        initial.forEach { (key, value) ->
            raw[FrozenValueCodec.physicalKey(key)] = value
        }
    }

    /** 供测试断言「盘上到底写了什么」——真实现里这是读 prefs 文件。 */
    fun rawSnapshot(): Map<String, String> = LinkedHashMap(raw)

    override fun getString(key: String): String? = raw[FrozenValueCodec.physicalKey(key)]

    override fun getInt(key: String, default: Int): Int =
        raw[FrozenValueCodec.physicalKey(key)]?.toIntOrNull() ?: default

    override fun getBool(key: String, default: Boolean): Boolean =
        raw[FrozenValueCodec.physicalKey(key)]?.let { it == "true" } ?: default

    override fun getStringList(key: String): List<String>? {
        val encoded = raw[FrozenValueCodec.physicalKey(key)] ?: return null
        return FrozenValueCodec.decodeStringList(encoded)
    }

    override fun putString(key: String, value: String) {
        raw[FrozenValueCodec.physicalKey(key)] = value
    }

    override fun putInt(key: String, value: Int) {
        raw[FrozenValueCodec.physicalKey(key)] = value.toString()
    }

    override fun putBool(key: String, value: Boolean) {
        raw[FrozenValueCodec.physicalKey(key)] = value.toString()
    }

    override fun putStringList(key: String, value: List<String>) {
        raw[FrozenValueCodec.physicalKey(key)] = FrozenValueCodec.encodeStringList(value)
    }

    override fun remove(key: String) {
        raw.remove(FrozenValueCodec.physicalKey(key))
    }

    override fun contains(key: String): Boolean = raw.containsKey(FrozenValueCodec.physicalKey(key))

    override fun archiveCorruptAndRemove(key: String, micros: Long): String {
        val physical = FrozenValueCodec.physicalKey(key)
        val backup = FrozenValueCodec.physicalKey(corruptBackupKey(key, micros))
        raw[physical]?.let { raw[backup] = it }
        raw.remove(physical)
        return corruptBackupKey(key, micros)
    }

    override fun keys(): Set<String> = raw.keys.mapNotNull { FrozenValueCodec.logicalKey(it) }.toSet()
}
