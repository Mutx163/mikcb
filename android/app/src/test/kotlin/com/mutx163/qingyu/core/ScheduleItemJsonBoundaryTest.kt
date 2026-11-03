package com.mutx163.qingyu.core

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [ScheduleItem] JSON 解析的**边界**用例（错误分支 / 缺字段 / 超长值）。
 *
 * 期望值来源：lib/models/schedule_item.dart 的同口径实现。
 * - 日期钳制：`_resolveNormalizedEndDate`（schedule_item.dart:468-478）；
 * - id 缺失/空白抛（:203-273 的 fromJson）；
 * - `exceptionDates` 兼容三个旧键名（:235-236）；写入只写 `exceptionDates`（:193）。
 */
class ScheduleItemJsonBoundaryTest {

    private fun parse(json: String): ScheduleItem = ScheduleItem.fromJsonString(json)

    // ---------- endDate 钳制（本次修复的回归锚点） ----------

    @Test
    fun `endDate 早于 startDate 时钳到 startDate 且 occursOn 不空转`() {
        val item = parse(
            """{"id":"s1","title":"复习","startDate":"2026-03-10","endDate":"2026-03-01"}""",
        )

        // Dart `_resolveNormalizedEndDate`：end < start → start。
        assertEquals(LocalDateTime.of(2026, 3, 10, 0, 0), item.endDate)
        assertEquals(LocalDateTime.of(2026, 3, 10, 0, 0), item.startDate)
        assertTrue(item.occursOn(LocalDateTime.of(2026, 3, 10, 0, 0)))
        // 钳制前 [03-01, 03-10] 会让 03-09 也命中；钳制后区间退化成单日。
        assertFalse(item.occursOn(LocalDateTime.of(2026, 3, 9, 0, 0)))
        // 写回必须是钳制后的值，否则 Kotlin 与 Dart 的存档会越漂越远。
        assertEquals("2026-03-10T00:00:00.000", item.toJson()["endDate"])
        assertEquals("2026-03-10T00:00:00.000", item.toJson()["date"])
    }

    @Test
    fun `startDate 缺失时 endDate 钳到旧键 date 而不是 now`() {
        // 旧档案只有 `date`，没有 startDate/endDate（schedule_item.dart:183-186）。
        val legacyOnly = parse("""{"id":"s1","title":"旧档","date":"2026-03-10"}""")
        assertEquals(LocalDateTime.of(2026, 3, 10, 0, 0), legacyOnly.startDate)
        assertEquals(LocalDateTime.of(2026, 3, 10, 0, 0), legacyOnly.endDate)

        // startDate 从 date 回落，endDate 早于它 → 仍要钳到 date 那天。
        val clamped = parse(
            """{"id":"s1","title":"旧档","date":"2026-03-10","endDate":"2026-01-05"}""",
        )
        assertEquals(LocalDateTime.of(2026, 3, 10, 0, 0), clamped.endDate)
    }

    @Test
    fun `endDate 与 startDate 同日不越界且 round trip 稳定`() {
        // createdAt/updatedAt 必须一起给出：缺省时两次解析各取一次 now()，不可比。
        val item = parse(
            """{"id":"s1","title":"单日","startDate":"2026-03-10","endDate":"2026-03-10",
               "createdAt":"2026-03-01T09:00:00.000","updatedAt":"2026-03-01T09:00:00.000"}""",
        )
        val reparsed = parse(MiniJson.encode(item.toJson()))

        assertEquals(item, reparsed)
    }

    // ---------- 损坏输入 ----------

    @Test
    fun `exceptionDates 非列表或元素坏掉时按空且不吞整条`() {
        val notList = parse(
            """{"id":"s1","title":"x","startDate":"2026-03-10","exceptionDates":"2026-03-11"}""",
        )
        assertEquals(emptyList<LocalDateTime>(), notList.exceptionDates)

        val mixed = parse(
            """{"id":"s1","title":"x","startDate":"2026-03-10",
               "exceptionDates":["2026-03-11",42,null,{"d":1},"not-a-date"]}""",
        )
        // 只有能解析的那一条留下；坏元素逐条丢弃，不影响整条日程。
        assertEquals(listOf(LocalDateTime.of(2026, 3, 11, 0, 0)), mixed.exceptionDates)
    }

    @Test
    fun `旧键名 exceptions 与 excludedDates 仍能读到`() {
        val viaExceptions = parse(
            """{"id":"s1","title":"x","startDate":"2026-03-10","exceptions":["2026-03-11"]}""",
        )
        assertEquals(listOf(LocalDateTime.of(2026, 3, 11, 0, 0)), viaExceptions.exceptionDates)

        val viaExcluded = parse(
            """{"id":"s1","title":"x","startDate":"2026-03-10","excludedDates":["2026-03-11"]}""",
        )
        assertEquals(listOf(LocalDateTime.of(2026, 3, 11, 0, 0)), viaExcluded.exceptionDates)
    }

    @Test
    fun `例外日期去重后升序排列`() {
        // 同一日期三种写法（含时分秒）会归一成同一个日历日。
        val item = parse(
            """{"id":"s1","title":"x","startDate":"2026-03-10",
               "exceptionDates":["2026-03-12T18:00:00.000","2026-03-11","2026-03-12"]}""",
        )
        assertEquals(
            listOf(LocalDateTime.of(2026, 3, 11, 0, 0), LocalDateTime.of(2026, 3, 12, 0, 0)),
            item.exceptionDates,
        )
    }

    @Test
    fun `id 缺失空白或非字符串分别按 Dart 口径处理`() {
        assertThrows(DartFormatException::class.java) { parse("""{"title":"x"}""") }
        assertThrows(DartFormatException::class.java) { parse("""{"id":"   ","title":"x"}""") }
        // 数字 id 在 Dart 侧 `?.toString()` 后可用，不当坏条目丢掉。
        assertEquals("42", parse("""{"id":42,"title":"x"}""").id)
    }

    @Test
    fun `enabled 为字符串 false 不猜布尔而是按缺省 true`() {
        val item = parse("""{"id":"s1","title":"x","startDate":"2026-03-10","enabled":"false"}""")
        assertTrue("字符串 'false' 没有合理真值，按缺省 true", item.enabled)

        val realFalse = parse("""{"id":"s1","title":"x","startDate":"2026-03-10","enabled":false}""")
        assertFalse(realFalse.enabled)
    }

    @Test
    fun `提醒分钟非正数与类型错都按无提醒`() {
        assertNull(parse("""{"id":"s1","title":"x","startDate":"2026-03-10","reminderMinutesBefore":0}""").reminderMinutesBefore)
        assertNull(parse("""{"id":"s1","title":"x","startDate":"2026-03-10","reminderMinutesBefore":-5}""").reminderMinutesBefore)
        assertNull(parse("""{"id":"s1","title":"x","startDate":"2026-03-10","reminderMinutesBefore":"abc"}""").reminderMinutesBefore)
        assertEquals(
            15L,
            parse("""{"id":"s1","title":"x","startDate":"2026-03-10","reminderMinutesBefore":"15"}""")
                .reminderMinutesBefore ?: -1L,
        )
    }

    // ---------- 超长值 ----------

    @Test
    fun `超长标题备注与地点原样保留不截断`() {
        val longTitle = "标".repeat(20_000)
        val longNote = "注".repeat(20_000)
        val item = parse(
            MiniJson.encode(
                linkedMapOf(
                    "id" to "s1",
                    "title" to longTitle,
                    "note" to longNote,
                    "location" to "L".repeat(20_000),
                    "startDate" to "2026-03-10",
                ),
            ),
        )

        assertEquals(longTitle, item.title)
        assertEquals(longNote, item.note)
        assertEquals("L".repeat(20_000), item.location)
        // 编码-解码一轮后长度与内容都不变。
        assertEquals(longTitle, (MiniJson.parse(item.toJsonString()) as Map<*, *>)["title"])
    }
}
