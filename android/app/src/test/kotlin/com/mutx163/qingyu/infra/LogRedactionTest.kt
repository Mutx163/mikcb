package com.mutx163.qingyu.infra

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日志脱敏单测。
 *
 * 期望值来源：
 * - Dart 逐行（app_debug_log.dart 注释的各条形态：`a|b` 逐段、overflowNames
 *   吃空白、`keywords=[…]` 吃 `]`、changeSamples 吃行尾、续行 `^` 匹配）；
 * - Dart 测试口径（test/logging/app_debug_log_redaction*_test.dart 的绕过用例方向）；
 * - 人推边界：大小写、非表键、嵌套 JSON 文本、快照子树、空列表。
 */
class LogRedactionTest {

    // ---------- isPersonalLogFieldKey ----------

    @Test
    fun `lookup is case insensitive`() {
        assertTrue(isPersonalLogFieldKey("course"))
        assertTrue(isPersonalLogFieldKey("COURSE"))
        // 人推：camelCase 键小写后仍命中（Dart lower 索引口径）。
        assertTrue(isPersonalLogFieldKey("CourseName"))
        assertTrue(isPersonalLogFieldKey("OVERFLOWNAMES"))
        assertFalse(isPersonalLogFieldKey("samples"))
        assertFalse(isPersonalLogFieldKey("schoolName"))
    }

    // ---------- redactPersonalFields ----------

    @Test
    fun `scalar field redacts to boundary`() {
        // `a|b` 拼接逐段命中，id/计数保留。
        assertEquals("course=** id=12", redactPersonalFields("course=高等数学 id=12"))
        assertEquals("COURSE=**", redactPersonalFields("COURSE=X"))
        assertEquals("samples=12", redactPersonalFields("samples=12"))
    }

    @Test
    fun `continuation line start matches`() {
        // 人推：multiline ^ 让续行开头的 key 也命中。
        assertEquals("line1\ncourse=**", redactPersonalFields("line1\ncourse=高等数学"))
    }

    @Test
    fun `comma list eats to blank but keeps following keys`() {
        // overflowNames 吃到空白为止，同行后面的 changeSamples 仍能处理。
        val out = redactPersonalFields("overflowNames=高等数学,大学英语 next=1")
        assertEquals("overflowNames=** next=1", out)
    }

    @Test
    fun `keywords bracket form eats to bracket`() {
        // 生产形态 keywords=[一教(exact)|六教(regex)]。
        val out = redactPersonalFields("keywords=[一教(exact)|六教(regex)] tail=1")
        assertEquals("keywords=** tail=1", out)
    }

    @Test
    fun `change samples eat to end of line`() {
        // changeSamples 用 " || " 分隔、元素内有 key 形态 token，只能吃到行尾。
        val out = redactPersonalFields("head=1 changeSamples=A|id|need=9-9 || B|id tail=x")
        assertEquals("head=1 changeSamples=**", out)
    }

    @Test
    fun `non personal keys untouched`() {
        assertEquals("schoolName=xx id=1", redactPersonalFields("schoolName=xx id=1"))
        assertEquals("", redactPersonalFields(""))
    }

    // ---------- redactPersonalFieldValue / Map / List ----------

    @Test
    fun `personal key masks whole value`() {
        assertEquals("**", redactPersonalFieldValue("courseName", "高等数学"))
        assertEquals("**", redactPersonalFieldValue("COURSE", "x"))
    }

    @Test
    fun `plain scalar keeps text`() {
        // 人推：非个人键的数字 500 → 文本 "500"。
        assertEquals("500", redactPersonalFieldValue("code", 500))
    }

    @Test
    fun `nested map redacts recursively`() {
        // 人推：Dart 同口径——map 递归后非个人值变文本。
        val out = redactPersonalFieldValue(
            "data",
            linkedMapOf<String, Any?>("name" to "高等数学", "id" to 7),
        )
        assertEquals(linkedMapOf("name" to "**", "id" to "7"), out)
    }

    @Test
    fun `json text container redacts after parsing`() {
        val out = redactPersonalFieldValue(
            "statusJson",
            "{\"course\": \"高等数学\", \"count\": 3}",
        )
        assertEquals(linkedMapOf("course" to "**", "count" to "3"), out)
    }

    @Test
    fun `non json text falls back to regex`() {
        assertEquals("a=1", redactPersonalFieldValue("data", "a=1"))
    }

    @Test
    fun `list redacts items and keeps bracket shape`() {
        assertEquals("[]", redactPersonalFieldList(emptyList()))
        assertEquals(
            "[{name=**}]",
            redactPersonalFieldList(listOf(linkedMapOf<String, Any?>("name" to "a"))),
        )
    }

    @Test
    fun `redact map keeps keys and shortens values`() {
        val out = redactPersonalFieldMap(
            linkedMapOf<Any?, Any?>("course" to "x", "count" to 3),
        )
        assertEquals(linkedMapOf("course" to "**", "count" to "3"), out)
    }

    // ---------- redactedLiveDebugSnapshot ----------

    @Test
    fun `snapshot masks course derived subtrees and keeps switches`() {
        val out = redactedLiveDebugSnapshot(
            linkedMapOf<Any?, Any?>(
                "notification" to linkedMapOf("title" to "高等数学"),
                "switches" to linkedMapOf("enabled" to true),
                "summary" to "课程 · 教室",
                "course" to "高等数学",
            ),
        )
        assertEquals("**", out["notification"])
        assertEquals("**", out["summary"])
        assertEquals("**", out["course"])
        assertEquals(linkedMapOf("enabled" to "true"), out["switches"])
    }

    @Test
    fun `snapshot without derived subtrees only redacts table keys`() {
        val out = redactedLiveDebugSnapshot(linkedMapOf<Any?, Any?>("count" to 5))
        assertEquals(linkedMapOf("count" to "5"), out)
    }
}
