package com.mutx163.qingyu.platform

import android.content.Context
import android.content.SharedPreferences
import com.mutx163.qingyu.app.FrozenValueCodec
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.corruptBackupKey
import java.io.IOException

/**
 * [KeyValueStore] 的 **Android 实现**（`FlutterSharedPreferences` + `flutter.` 前缀）。
 *
 * 编码规则**一行都不在这里写**：前缀与 `List<String>` 的编解码全部走 [FrozenValueCodec]，
 * 与 [com.mutx163.qingyu.app.InMemoryKeyValueStore] 共用同一套规则。
 * 两边规则若各写一份，「测试用的内存实现」就会比真实现宽松，测出来的绿是假的。
 *
 * ## 为什么放在 `platform/` 而不是 `app/`
 *
 * `scripts/test-kotlin-module.ps1` 的「纯 Kotlin」判定是**整目录**的：`app/` 里只要出现
 * 一个 `import android.*`，整个 `app/` 会被静默跳过，全队 L0 里 app 的符号立刻全 Unresolved。
 * 所以 Android 胶水（Context / SharedPreferences）一律留在本目录。
 *
 * ## 三个刻意的实现选择
 *
 * 1. **写用 `commit()` 而不是 `apply()`**：契约要求「杀进程重开数据还在」。
 *    `apply()` 只保证内存立即可见、磁盘异步落，进程紧接着被杀就会丢。
 *    本存储只在用户动作（加课/改课/切档案）时写，频率低，同步写可接受；
 *    Dart 侧插件（`LegacySharedPreferencesPlugin`）同样是 `commit()`。
 * 2. **`getInt` 走 `prefs.all` 再判类型**：Flutter 插件把 `int` 落盘成 **`Long`**
 *    （`prefs.edit().putLong(key, value)`），直接 `getInt` 会抛 `ClassCastException`。
 *    这里对 Int / Long / String 三种历史形态都收，类型不符才回落默认值。
 * 3. **`getStringList` 解码失败照抛**：接口 KDoc 的硬要求——空列表是合法数据
 *    （用户真的没课），与「数据坏了」必须分开。留档自愈由
 *    [com.mutx163.qingyu.app.TimetableStore] 在**知道该 key 语义**的那一层做。
 * 4. **写失败（`commit()` 返回 false）抛 [IOException]**：磁盘满 / IO 异常时
 *    `commit()` 不抛异常、只返回 false；把布尔丢掉等于「界面显示成功、重启数据回退」。
 *    上层契约（`TimetableRepository` / `TimetableCourseService`）写的是
 *    「先落盘，失败则内存与监听者都不动」——靠的就是这一层把失败变成异常，
 *    服务的快照回滚与宿主的失败提示才有机会生效。`KeyValueStore` 的签名是冻结的
 *    （不能改成返回 Boolean / Result），异常是唯一不破坏签名又能被上层感知的通道。
 */
class PrefsKeyValueStore(context: Context) : KeyValueStore {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun getString(key: String): String? =
        prefs.getString(FrozenValueCodec.physicalKey(key), null)

    override fun getInt(key: String, default: Int): Int {
        val raw = readRaw(key) ?: return default
        return when (raw) {
            is Int -> raw
            // Flutter 插件写 int 用的是 putLong。
            is Long -> if (raw in Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong()) raw.toInt() else default
            is String -> raw.toIntOrNull() ?: default
            else -> default
        }
    }

    /**
     * 与 [getInt] 同一套宽松口径：Flutter 插件落 `int` 用 `putLong` ⇒ 盘上是 `Long`；
     * 别的实现可能落成 `Int` 或数字字符串，三种都收，类型不符才回落默认值。
     *
     * 不用 `prefs.getLong(...)`：它遇到 String 类型会抛 `ClassCastException`，
     * 把「一条脏数据」升级成「读配置就崩」。
     */
    override fun getLong(key: String, default: Long): Long {
        val raw = readRaw(key) ?: return default
        return when (raw) {
            is Long -> raw
            is Int -> raw.toLong()
            is String -> raw.toLongOrNull() ?: default
            else -> default
        }
    }

    override fun getBool(key: String, default: Boolean): Boolean {
        val raw = readRaw(key) ?: return default
        return when (raw) {
            is Boolean -> raw
            is String -> when (raw.lowercase()) {
                "true" -> true
                "false" -> false
                else -> default
            }
            else -> default
        }
    }

    override fun getStringList(key: String): List<String>? {
        val encoded = prefs.getString(FrozenValueCodec.physicalKey(key), null) ?: return null
        // 解码失败**故意不 catch**：抛出去，让上层按「数据坏了」留档处理。
        return FrozenValueCodec.decodeStringList(encoded)
    }

    /**
     * `commit()` 返回 false（磁盘满 / IO 异常）时抛 [IOException]；不抛等于写失败被吞掉。
     *
     * 注意**不 catch 任何东西再转述**：上层（服务回滚 / 宿主提示）需要的是「这次写失败」本身。
     */
    private fun SharedPreferences.Editor.commitOrThrow(key: String) {
        if (!commit()) {
            throw IOException("SharedPreferences commit failed for key: $key")
        }
    }

    override fun putString(key: String, value: String) {
        prefs.edit().putString(FrozenValueCodec.physicalKey(key), value).commitOrThrow(key)
    }

    override fun putInt(key: String, value: Int) {
        // 与 Flutter 插件逐字节一致：int 落盘为 Long。
        prefs.edit().putLong(FrozenValueCodec.physicalKey(key), value.toLong()).commitOrThrow(key)
    }

    override fun putLong(key: String, value: Long) {
        // 与 Dart `prefs.setInt` 同类型、同步落盘（理由见类注释第 1 条）。
        prefs.edit().putLong(FrozenValueCodec.physicalKey(key), value).commitOrThrow(key)
    }

    override fun putBool(key: String, value: Boolean) {
        prefs.edit().putBoolean(FrozenValueCodec.physicalKey(key), value).commitOrThrow(key)
    }

    override fun putStringList(key: String, value: List<String>) {
        prefs.edit()
            .putString(FrozenValueCodec.physicalKey(key), FrozenValueCodec.encodeStringList(value))
            .commitOrThrow(key)
    }

    override fun remove(key: String) {
        prefs.edit().remove(FrozenValueCodec.physicalKey(key)).commitOrThrow(key)
    }

    override fun contains(key: String): Boolean =
        prefs.contains(FrozenValueCodec.physicalKey(key))

    override fun archiveCorruptAndRemove(key: String, micros: Long): String {
        val physical = FrozenValueCodec.physicalKey(key)
        val backupPhysical = FrozenValueCodec.physicalKey(corruptBackupKey(key, micros))
        val raw = prefs.getString(physical, null)
        val editor = prefs.edit()
        if (raw != null) editor.putString(backupPhysical, raw)
        editor.remove(physical)
        // 留档与原 key 的删除必须一起落盘：先删后写失败等于把坏数据弄丢。
        // 这一笔失败同样要抛：留档丢了的后果比普通写失败更严重。
        editor.commitOrThrow(key)
        return corruptBackupKey(key, micros)
    }

    override fun keys(): Set<String> =
        prefs.all.keys.mapNotNull { FrozenValueCodec.logicalKey(it) }.toSet()

    /** 类型无关读取：Flutter 的 `int` 是 Long、`bool` 是 Boolean、其余是 String。 */
    private fun readRaw(key: String): Any? = prefs.all[FrozenValueCodec.physicalKey(key)]

    companion object {
        /** 数据契约 §1.1：文件名冻结。 */
        const val PREFS_NAME = "FlutterSharedPreferences"
    }
}
