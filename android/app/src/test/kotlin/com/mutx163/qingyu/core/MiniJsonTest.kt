package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * MiniJson 基础行为：人推期望值（对照 Dart jsonEncode/jsonDecode 的语义）。
 *
 * 来源标记：
 * - [人推]：由 Dart `dart:convert` 的公开语义逐条推出；
 * - [Dart推演]：对照 lib/models/course.dart 等处对 jsonEncode 的使用方式。
 */
class MiniJsonTest {

    // ---------- 解码 ----------

    @Test
    fun `parse flat object with scalar types`() { // [人推]
        val v = MiniJson.parse("""{"a":1,"b":true,"c":null,"d":"x","e":-2}""")
            as Map<*, *>
        assertEquals(1L, v["a"])
        assertEquals(true, v["b"])
        assertNull(v["c"])
        assertEquals("x", v["d"])
        assertEquals(-2L, v["e"])
    }

    @Test
    fun `parse nested containers preserve order`() { // [人推] Dart Map/List 保插入序
        val v = MiniJson.parse("""{"z":[1,{"k":"v"}],"a":2}""") as Map<*, *>
        assertEquals(listOf("z", "a"), v.keys.toList())
        val list = v["z"] as List<*>
        assertEquals(1L, list[0])
        assertEquals("v", (list[1] as Map<*, *>)["k"])
    }

    @Test
    fun `parse double vs long distinguishes by literal`() { // [人推]
        val v = MiniJson.parse("""{"i":3,"d":3.0,"e":2.5e2,"neg":-0.5}""") as Map<*, *>
        assertEquals(3L, v["i"])
        assertEquals(3.0, v["d"])
        assertEquals(250.0, v["e"])
        assertEquals(-0.5, v["neg"])
    }

    @Test
    fun `parse long beyond int range`() { // [人推] Dart int 是 64 位
        val v = MiniJson.parse("""{"n":10000000000}""") as Map<*, *>
        assertEquals(10000000000L, v["n"])
    }

    @Test
    fun `parse escapes`() { // [人推] JSON 标准转义集
        val v = MiniJson.parse("""{"s":"a\nb\"c\\d\/e\tf"}""") as Map<*, *>
        assertEquals("a\nb\"c\\d/e\tf", v["s"])
    }

    @Test
    fun `parse unicode escape`() { // [人推]
        val v = MiniJson.parse("""{"s":"\u4e2d\u6587"}""") as Map<*, *>
        assertEquals("中文", v["s"])
    }

    @Test
    fun `parse rejects trailing garbage`() { // [人推] jsonDecode 会抛
        assertThrows(DartFormatException::class.java) {
            MiniJson.parse("""{"a":1} junk""")
        }
    }

    @Test
    fun `parse rejects malformed object and literal`() { // [人推]
        assertThrows(DartFormatException::class.java) { MiniJson.parse("""{"a" 1}""") }
        assertThrows(DartFormatException::class.java) { MiniJson.parse("""tru""") }
        assertThrows(DartFormatException::class.java) { MiniJson.parse("""[1,]""") }
        assertThrows(DartFormatException::class.java) { MiniJson.parse("""{}d""") }
    }

    @Test
    fun `tryParse returns null on garbage`() { // [人推] 宽松入口
        assertNull(MiniJson.tryParse("not json"))
        assertNull(MiniJson.tryParse(null))
        assertEquals(1L, MiniJson.tryParse("1"))
    }

    // ---------- 编码 ----------

    @Test
    fun `encode round trip`() { // [人推]
        val src = linkedMapOf<String, Any?>(
            "a" to 1L,
            "b" to arrayListOf(true, null, "x"),
            "c" to 1.5,
            "d" to "中\"文\\",
        )
        val encoded = MiniJson.encode(src)
        assertEquals(src, MiniJson.parse(encoded))
    }

    @Test
    fun `encode double whole value keeps trailing zero like dart`() { // [人推] jsonEncode(1.0)=="1.0"
        assertEquals("1.0", MiniJson.encode(1.0))
        assertEquals("-2.5", MiniJson.encode(-2.5))
        assertEquals("0.1", MiniJson.encode(0.1))
    }

    @Test
    fun `encode keeps non ascii raw like dart`() { // [人推] Dart jsonEncode 不转义非 ASCII
        val encoded = MiniJson.encode(mapOf("k" to "中文"))
        assertEquals("""{"k":"中文"}""", encoded)
    }

    @Test
    fun `encode control chars escaped`() { // [人推]
        val encoded = MiniJson.encode("a\nb")
        assertEquals("\"a\\nb\"", encoded)
    }

    @Test
    fun `encode map follows iteration order`() { // [Dart推演] toJson 用 Map 字面量，序即写入序
        val encoded = MiniJson.encode(linkedMapOf("b" to 2L, "a" to 1L))
        assertEquals("""{"b":2,"a":1}""", encoded)
    }

    @Test
    fun `encode nested empty containers`() { // [人推]
        assertEquals("""{"a":[],"b":{}}""", MiniJson.encode(linkedMapOf("a" to emptyList<Any?>(), "b" to emptyMap<Any?, Any?>())))
    }

    @Test
    fun `sections signature style list encode`() { // [Dart推演] time_scheme_logic.sectionsSignature 的形状
        val sections = listOf(
            linkedMapOf("startTime" to "08:00", "endTime" to "08:45"),
            linkedMapOf("startTime" to "08:55", "endTime" to "09:40"),
        )
        assertTrue(MiniJson.encode(sections).startsWith("""[{"startTime":"08:00"""))
    }
}
