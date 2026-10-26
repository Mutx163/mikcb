package com.mutx163.qingyu.calendar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 周表达式解析测试（移植自 lib/services/week_expression_parser.dart 的纯函数部分）。
 *
 * 期望值来源：test/services/week_expression_parser_test.dart 逐条对照（[Dart抄录-测试]），
 * 另有 [Dart推演] 补充混合场景；warnings 载荷按 ServiceMessage 契约（[Dart抄录]）。
 */
class WeekExpressionParserTest {

    private fun parse(
        raw: String,
        semesterWeekCount: Int? = null,
        warnings: MutableList<String>? = null,
    ): List<Int> = WeekExpressionParser.parse(
        raw = raw,
        itemName = "周数",
        semesterWeekCount = semesterWeekCount,
        warnings = warnings,
    )

    // ---------- 基础区间 ----------

    @Test
    fun `parses simple range`() { // [Dart抄录-测试] week_expression_parser_test.dart:6-25
        assertEquals((1..16).toList(), parse("1-16"))
    }

    @Test
    fun `parses disjoint weeks with dun hao separator`() { // [Dart抄录-测试] :27-45
        assertEquals(
            listOf(1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16),
            parse("1-8、10-16"),
        )
    }

    @Test
    fun `parses comma separator too`() { // [Dart抄录] _tokenSeparatorPattern 含半角逗号
        assertEquals(listOf(1, 2, 4), parse("1,2、4"))
    }

    @Test
    fun `spaces are stripped before parsing`() { // [Dart抄录] :32-33 replaceAll(' ', '')
        assertEquals(listOf(1, 2, 10), parse("1-2 、 10"))
    }

    // ---------- 单/双周后缀与括号 ----------

    @Test
    fun `parses WakeUp odd-week suffix on range`() { // [Dart抄录-测试] :47-49
        assertEquals(listOf(7, 9, 11), parse("7-11单"))
    }

    @Test
    fun `parses WakeUp even-week suffix on range`() { // [Dart抄录-测试] :51-53
        assertEquals(listOf(2, 4), parse("1-5双"))
    }

    @Test
    fun `parses combined expression with per-token parity`() { // [Dart抄录-测试] :55-66
        assertEquals(
            listOf(1, 2, 3, 4, 5, 7, 9, 11),
            parse("1-5、7-11单"),
        )
    }

    @Test
    fun `parses parenthetical parity mode and strips section suffix`() { // [Dart抄录-测试] :68-75
        assertEquals(listOf(14, 15), parse("14-15(全部)[01-02-03-04节]"))
        assertEquals(listOf(14, 15), parse("14-15（全部）【01-02节】")) // 全角括号/方括号
        assertEquals(listOf(1, 3), parse("1-4(单)"))
        assertEquals(listOf(2, 4), parse("1-4(双)"))
    }

    @Test
    fun `parity suffix on single week token`() { // [Dart推演] token 级单双周也作用于单个数字
        assertEquals(listOf(7), parse("7单"))
        assertEquals(listOf(8), parse("8双"))
    }

    @Test
    fun `global parity only applies to single token without token parity`() { // [Dart抄录] :104-107
        // 全局 (单)：单 token、token 自身无单双后缀 → 整体按奇数过滤。
        assertEquals(listOf(1, 3), parse("1-4(单)"))
        // 多 token：全局括号模式不再整体过滤（避免 1-5、7-11(单) 被整串误过滤）。
        assertEquals(
            listOf(1, 2, 3, 4, 5, 7, 8, 9, 10, 11),
            parse("1-5、7-11(全部)"),
        )
    }

    @Test
    fun `global parity with token parity wins for token`() { // [Dart推演] token 级优先，全局失效
        // 两个 token 都有后缀 → anyTokenParity=true → 全局(双)失效。
        assertEquals(listOf(2, 4, 8), parse("1-4双、8(双)"))
    }

    // ---------- 错误路径 ----------

    @Test
    fun `rejects reversed range`() { // [Dart抄录-测试] :77-82 → week_range_invalid
        val e = assertThrowsService { parse("5-3") }
        assertEquals("week_range_invalid|itemName=周数", e)
    }

    @Test
    fun `rejects range exceeding 30`() { // [Dart抄录-测试] :105-110 → week_range_too_large
        val e = assertThrowsService { parse("1-31") }
        assertEquals("week_range_too_large|itemName=周数", e)
    }

    @Test
    fun `rejects zero or negative tokens`() { // [Dart抄录-测试] :91-110
        assertEquals("week_token_unrecognized|itemName=周数|token=abc", assertThrowsService { parse("abc") })
        assertEquals("week_token_unrecognized|itemName=周数|token=0", assertThrowsService { parse("0") })
        assertEquals("week_start_invalid|itemName=周数", assertThrowsService { parse("0-5") })
        // "-3-5" 不命中 range 正则 ^\d+-\d+$（services/week_expression_parser.dart:57），
        // 落到 int.tryParse 失败 → week_token_unrecognized，token 是整个 "-3-5"
        assertEquals("week_token_unrecognized|itemName=周数|token=-3-5", assertThrowsService { parse("-3-5") })
    }

    @Test
    fun `error payload carries item name from caller`() { // [Dart抄录] itemName 透传
        val e = org.junit.Assert.assertThrows(WeekExpressionException::class.java) {
            WeekExpressionParser.parse(
                raw = "5-3",
                itemName = "courses[3].周数",
                semesterWeekCount = null,
                warnings = null,
            )
        }
        assertEquals("week_range_invalid|itemName=courses[3].周数", e.message)
    }

    // ---------- 空输入 ----------

    @Test
    fun `empty and blank inputs yield empty list`() { // [Dart抄录-测试] :120-126
        assertEquals(emptyList<Int>(), parse(""))
        assertEquals(emptyList<Int>(), parse("   "))
    }

    // ---------- 学期周数钳制 ----------

    @Test
    fun `clamps weeks above semesterWeekCount and records warning`() { // [Dart抄录-测试] :128-142
        val warnings = mutableListOf<String>()
        assertEquals(
            (1..16).toList(),
            parse("1-20", semesterWeekCount = 16, warnings = warnings),
        )
        assertEquals(1, warnings.size)
        assertTrue(warnings[0].contains("16"))
        assertTrue(warnings[0].contains("20"))
        // 载荷形状：code|itemName=...|semesterWeekCount=16|weeks=17、18、19、20
        assertTrue(warnings[0].startsWith("weeks_exceed_semester_clamped|"))
        assertTrue(warnings[0].contains("itemName=周数"))
        assertTrue(warnings[0].contains("semesterWeekCount=16"))
        assertTrue(warnings[0].contains("weeks=17、18、19、20"))
    }

    @Test
    fun `no clamp without semesterWeekCount`() { // [Dart推演] null / <1 都跳过钳制
        assertEquals((1..30).toList(), parse("1-30"))
        assertEquals((1..20).toList(), parse("1-20"))
    }

    @Test
    fun `clamp skipped for invalid count or empty weeks`() { // [Dart抄录] :128 semesterWeekCount < 1 不钳
        val warnings = mutableListOf<String>()
        assertEquals(
            (1..20).toList(),
            parse("1-20", semesterWeekCount = 0, warnings = warnings),
        )
        assertEquals(0, warnings.size)
    }

    // ---------- 变体：weekExpression / suspendedWeekExpression 字段应用 ----------

    @Test
    fun `applyWeekExpressionFields expands expression into customWeeks`() { // [Dart抄录-测试] lan_edit_server_service_test.dart:971-992
        val slot = linkedMapOf<String, Any?>(
            "name" to "表达式课",
            "weekExpression" to "1-2、4",
        )
        WeekExpressionParser.applyWeekExpressionFields(slot, courseName = "表达式课", semesterWeekCount = 20)
        assertTrue(!slot.containsKey("weekExpression"))
        assertEquals(listOf(1L, 2L, 4L), slot["customWeeks"])
        assertEquals(1L, slot["startWeek"])
        assertEquals(4L, slot["endWeek"])
        assertEquals(false, slot["isOddWeek"])
        assertEquals(false, slot["isEvenWeek"])
    }

    @Test
    fun `applyWeekExpressionFields expands suspended expression`() { // [Dart抄录] lan_edit_provider_host.dart:470-479
        val slot = linkedMapOf<String, Any?>(
            "name" to "体育",
            "suspendedWeekExpression" to "1、3-5双",
        )
        WeekExpressionParser.applyWeekExpressionFields(slot, courseName = "体育", semesterWeekCount = 20)
        assertTrue(!slot.containsKey("suspendedWeekExpression"))
        assertEquals(listOf(1L, 4L), slot["suspendedWeeks"])
        // suspended 不动 startWeek/endWeek/isOdd/isEven。
        assertTrue(!slot.containsKey("customWeeks"))
        assertTrue(!slot.containsKey("startWeek"))
    }

    @Test
    fun `blank expressions leave slot untouched`() { // [Dart抄录] :455 isNotEmpty 守卫
        val slot = linkedMapOf<String, Any?>(
            "name" to "高数",
            "weekExpression" to "  ",
            "suspendedWeekExpression" to "",
        )
        WeekExpressionParser.applyWeekExpressionFields(slot, courseName = "高数", semesterWeekCount = 20)
        assertEquals(1, slot.size)
        assertTrue(slot.containsKey("name"))
    }

    @Test
    fun `empty parse result keeps customWeeks empty and skips week bounds`() { // [Dart抄录] :463 weeks.isNotEmpty 守卫
        val slot = linkedMapOf<String, Any?>(
            "name" to "高数",
            "weekExpression" to "10-8", // 反向区间 → 抛错
        )
        val e = org.junit.Assert.assertThrows(WeekExpressionException::class.java) {
            WeekExpressionParser.applyWeekExpressionFields(slot, courseName = "高数", semesterWeekCount = 20)
        }
        assertEquals("week_range_invalid|itemName=高数", e.message)
    }

    private fun assertThrowsService(block: () -> List<Int>): String {
        val e = org.junit.Assert.assertThrows(WeekExpressionException::class.java) {
            block()
            Unit
        }
        return e.message ?: ""
    }
}
