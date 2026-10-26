package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Phase 0 双向兼容测试（A→B / B→A 的 B 侧编解码器契约）。
 *
 * 金标准样本由 JDK 独立生成（GenGolden：ObjectOutputStream + MIME Base64），
 * 与被测实现零共享代码——期望值是人推的/独立来源的，不是从实现抄的。
 *
 * 对应 Dart 侧读回验证（B→A 的 A 侧）在 test/services/legacy_prefs_codec_test.dart，
 * 两侧必须同时绿，「Kotlin 写 → Flutter 读」的回退保证才成立。
 */
class FlutterPrefsCodecTest {

    // "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu" —— shared_preferences_android
    // LegacySharedPreferencesPlugin.java:36 的 LIST_IDENTIFIER，逐字节冻结。
    private val listPrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

    // DOUBLE_PREFIX（:41），注意末尾句点；本仓 double 实际只有 1 个写方但契约必须覆盖。
    private val doublePrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

    /** GenGolden 对 ["高数", "英语 B201", "x"] 的输出：85 字节序列化 + MIME(76,'\n')。 */
    private val goldenList = listOf("高数", "英语 B201", "x")
    private val goldenEncoded =
        "rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAADdwQAAAAD\n" +
            "dAAG6auY5pWwdAAL6Iux6K+tIEIyMDF0AAF4eA=="

    // ---------- A→B：Flutter 写出的值，Kotlin 必须能读 ----------

    @Test
    fun decodeFlutterGolden_list() {
        assertEquals(goldenList, FlutterPrefsCodec.decodeStringList(listPrefix + goldenEncoded))
    }

    @Test
    fun decodeFlutterGolden_double() {
        // 插件把 double 存成前缀 + Double.toString；"3.14" 必须还原成 3.14
        assertEquals(3.14, FlutterPrefsCodec.decodeDouble(doublePrefix + "3.14"), 0.0)
    }

    @Test
    fun decodeFlutterGolden_doubleNegative() {
        assertEquals(-0.5, FlutterPrefsCodec.decodeDouble(doublePrefix + "-0.5"), 0.0)
    }

    @Test
    fun decode_withoutPrefix_throws() {
        // 缺前缀 = 不是 List 编码（可能是普通字符串被误传）——必须抛，不能静默返回垃圾
        assertThrows(IllegalArgumentException::class.java) {
            FlutterPrefsCodec.decodeStringList(goldenEncoded)
        }
    }

    // ---------- B→A：Kotlin 写出的值，Flutter（同一套 Java 反序列化）必须能读 ----------
    // 这里用「与 GenGolden 相同的独立 JVM 原语」验证字节级等价：
    // Kotlin 产出的字符串必须与金标准逐字节一致，等价于插件 ObjectInputStream 能读回。

    @Test
    fun encodeStringList_byteIdenticalToGolden() {
        assertEquals(listPrefix + goldenEncoded, FlutterPrefsCodec.encodeStringList(goldenList))
    }

    @Test
    fun encodeStringList_emptyList() {
        // 空列表也要按同结构走：反序列化回空列表
        val encoded = FlutterPrefsCodec.encodeStringList(emptyList())
        assertEquals(true, FlutterPrefsCodec.decodeStringList(encoded).isEmpty())
    }

    @Test
    fun encodeDecodeRoundtrip_specialCharacters() {
        val tricky = listOf("", "a\nb", "引号\"x", "emoji🎓", "rO0ABXNy（伪造序列化头）")
        val encoded = FlutterPrefsCodec.encodeStringList(tricky)
        assertEquals(tricky, FlutterPrefsCodec.decodeStringList(encoded))
    }

    @Test
    fun encodeDecodeRoundtrip_longList_lineWrapping() {
        // >76 字符的负载必然触发 MIME 换行——这是与 android Base64 flag=0 对齐的关键点
        val long = listOf("x".repeat(200))
        val encoded = FlutterPrefsCodec.encodeStringList(long)
        assertEquals(long, FlutterPrefsCodec.decodeStringList(encoded))
        assertEquals(true, encoded.contains("\n"))
    }

    @Test
    fun encodeDouble_matchesPluginFormat() {
        val encoded = FlutterPrefsCodec.encodeDouble(3.14)
        assertEquals(doublePrefix + "3.14", encoded)
        assertEquals(3.14, FlutterPrefsCodec.decodeDouble(encoded), 0.0)
    }

    @Test
    fun decodeDouble_withoutPrefix_throws() {
        assertThrows(IllegalArgumentException::class.java) {
            FlutterPrefsCodec.decodeDouble("3.14")
        }
    }
}
