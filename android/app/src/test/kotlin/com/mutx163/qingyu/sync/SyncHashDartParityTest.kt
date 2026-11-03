package com.mutx163.qingyu.sync

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * D4：`contentSha256` 必须与 Dart `jsonEncode` **逐字节**一致，否则同一份快照
 * 两端各算一个哈希，同步会把自己写的数据误判成对方冲突。
 *
 * 期望值全部由 Dart 2.x 实测产出（`jsonEncode` + `crypto.sha256`），不是猜的：
 * 见 docs/plans 之外的实证脚本输出（指数区间、`1.0`/`1`、`-0.0`、大整数边界）。
 */
class SyncHashDartParityTest {

    /** (double 值, Dart `jsonEncode` 实际输出)。 */
    private val dartDoubleFixtures: List<Pair<Double, String>> = listOf(
        1.0 to "1.0",
        -1.0 to "-1.0",
        0.0 to "0.0",
        -0.0 to "-0.0",
        0.1 to "0.1",
        0.5 to "0.5",
        0.30000000000000004 to "0.30000000000000004",
        1.2345678901234567 to "1.2345678901234567",
        100.0 to "100.0",
        120.0 to "120.0",
        1_000_000.0 to "1000000.0",
        1e20 to "100000000000000000000.0",
        1e21 to "1e+21",
        1e22 to "1e+22",
        1e23 to "1e+23",
        1e100 to "1e+100",
        1.7976931348623157e308 to "1.7976931348623157e+308",
        1e-5 to "0.00001",
        1e-6 to "0.000001",
        1e-7 to "1e-7",
        1e-8 to "1e-8",
        1.5e-10 to "1.5e-10",
        1e-100 to "1e-100",
        1234567890123456.0 to "1234567890123456.0",
        12345678901234567890.0 to "12345678901234567000.0",
        2.5 to "2.5",
        3.5 to "3.5",
        0.000123456 to "0.000123456",
        1234567890123456.5 to "1234567890123456.5",
        // 次正规数：Dart 输出 `5e-324`，JDK 17 的 Double.toString 是 `4.9E-324`。
        4.9e-324 to "5e-324",
    )

    @Test
    fun `double 渲染逐条对齐 Dart jsonEncode`() {
        for ((value, expected) in dartDoubleFixtures) {
            assertEquals("value=$value", expected, dartJsonNumber(value))
        }
    }

    @Test
    fun `整数与 double 不混淆`() {
        assertEquals("1", canonicalJson(1))
        assertEquals("1", canonicalJson(1L))
        assertEquals("1.0", canonicalJson(1.0))
        assertEquals("-0.0", canonicalJson(-0.0))
        assertEquals("0.0", canonicalJson(0.0))
    }

    /** Dart 实测：`jsonEncode(fixture)` 的完整输出。 */
    private fun fixture(): Map<String, Any?> = linkedMapOf(
        "app" to "mikcb",
        "backupType" to "sync",
        "counts" to linkedMapOf<String, Any?>("a" to 1, "b" to 2.5, "c" to 1e21),
        "empty" to emptyList<Any?>(),
        "flag" to true,
        "nested" to linkedMapOf<String, Any?>(
            "negativeZero" to -0.0,
            "ratio" to 1e-7,
            "text" to "é/中文\t\u0001",
        ),
        "nil" to null,
        "schemaVersion" to 2,
        "tiny" to 1e-6,
        "whole" to 100.0,
    )

    @Test
    fun `整个快照的 canonical JSON 与 Dart 逐字节一致`() {
        assertEquals(
            """{"app":"mikcb","backupType":"sync","counts":{"a":1,"b":2.5,"c":1e+21},"empty":[],"flag":true,"nested":{"negativeZero":-0.0,"ratio":1e-7,"text":"é/中文\t\u0001"},"nil":null,"schemaVersion":2,"tiny":0.000001,"whole":100.0}""",
            canonicalJson(fixture()),
        )
        assertEquals(
            "cecfa46631e6fea5c21b3915db46fd49c92a5a2febed111ec7c4162e4737e5a4",
            computeContentSha256(fixture()),
        )
    }

    @Test
    fun `哈希前剔除信封键后与 Dart 一致`() {
        val payload = linkedMapOf<String, Any?>(
            "exportedAt" to "2026-01-01T00:00:00.000",
            "deviceId" to "dev-x",
            "contentSha256" to "deadbeef",
            "x" to 1e21,
        )
        assertEquals(
            "f4bcbb57bdf54b5b595d88096406c936d86bf0b6dd316d0ad2b4d2504c610403",
            computeContentSha256(payload),
        )
    }

    @Test
    fun `字符串转义口径与 Dart 一致`() {
        // Dart 实测：控制字符 \u0001 转义；DEL / U+2028 / U+2029 / 非 ASCII 原样输出。
        assertEquals("\"\\u0001\"", canonicalJson("\u0001"))
        assertEquals("\"\u007f\"", canonicalJson("\u007f"))
        assertEquals("\"\u2028\"", canonicalJson("\u2028"))
        assertEquals("\"\u2029\"", canonicalJson("\u2029"))
        assertEquals("\"a/b\"", canonicalJson("a/b"))
        assertEquals("\"quote\\\"here\"", canonicalJson("quote\"here"))
        assertEquals("\"back\\\\slash\"", canonicalJson("back\\slash"))
        assertEquals("\"tab\\there\"", canonicalJson("tab\there"))
        assertEquals("\"nl\\nhere\"", canonicalJson("nl\nhere"))
    }
}
