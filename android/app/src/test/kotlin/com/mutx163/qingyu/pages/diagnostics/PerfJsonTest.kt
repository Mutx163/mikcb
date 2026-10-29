package com.mutx163.qingyu.pages.diagnostics

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 「复制 JSON 快照 / 导出 json」那份文本的逐字口径（Dart `JsonEncoder.withIndent('  ')`）。
 *
 * 为什么值得单独钉：差分脚本按行对比两个版本的快照。缩进宽度、键序、`120.0` 还是 `120`
 * 任何一处漂了，脚本读到的就是「字段抖动」而不是「这一页变慢了」。
 */
class PerfJsonTest {

    @Test
    fun `缩进两空格 键序按传入顺序 整数 double 带点零`() {
        val value = linkedMapOf<String, Any?>(
            "refreshRateHz" to 120.0,
            "cpuCount" to 8,
            "pages" to listOf(
                linkedMapOf(
                    "page" to "home",
                    "fps" to "59.9",
                    "rssDeltaKb" to null,
                ),
            ),
        )
        assertEquals(
            """
            {
              "refreshRateHz": 120.0,
              "cpuCount": 8,
              "pages": [
                {
                  "page": "home",
                  "fps": "59.9",
                  "rssDeltaKb": null
                }
              ]
            }
            """.trimIndent(),
            perfSnapshotJsonText(value),
        )
    }

    @Test
    fun `空列表与空对象写在一行`() {
        val value = linkedMapOf<String, Any?>(
            "pages" to emptyList<Any?>(),
            "totals" to emptyMap<String, Any?>(),
        )
        assertEquals(
            "{\n  \"pages\": [],\n  \"totals\": {}\n}",
            perfSnapshotJsonText(value),
        )
    }

    @Test
    fun `字符串转义与 Dart 一致`() {
        assertEquals(
            "\"a\\\"b\\\\c\\nd\\te\"",
            perfSnapshotJsonText("a\"b\\c\nd\te"),
        )
        // 非 ASCII 原样输出（Dart 默认不转成 \uXXXX）
        assertEquals("\"设备\"", perfSnapshotJsonText("设备"))
    }

    @Test
    fun `布尔与长整数`() {
        assertEquals("true", perfSnapshotJsonText(true))
        assertEquals("false", perfSnapshotJsonText(false))
        assertEquals("1712345678901", perfSnapshotJsonText(1_712_345_678_901L))
    }

    @Test
    fun `非整数值的 double 按最短形态输出`() {
        assertEquals("59.9", perfSnapshotJsonText(59.9))
        assertEquals("0.0", perfSnapshotJsonText(0.0))
        assertEquals("8.3", perfSnapshotJsonText(8.3))
    }
}
