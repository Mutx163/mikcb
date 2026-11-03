package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.MiniJson
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [HolidayData] / [HolidayEntry] 的**损坏输入**与优先级边界用例。
 *
 * 期望值来源：lib/models/holiday_entry.dart。
 * - 单条坏条目跳过、好条目保留（:170-186）；
 * - `version` 缺省 1，非数字抛（:190-198）；
 * - 自定义假期 > 调休上班 > 法定假期（:102-140）；
 * - `_dateKey` 年份不补零、月日补零（:228-233）。
 */
class HolidayDataCorruptInputTest {

    private fun entry(
        date: String,
        name: String = "假期",
        type: String = "vacation",
        groupId: String? = null,
    ): HolidayEntry = HolidayEntry.fromJson(
        linkedMapOf("date" to date, "name" to name, "type" to type, "groupId" to groupId),
    )

    // ---------- 结构性损坏 ----------

    @Test
    fun `entries 非列表按空且 year version 原样保留`() {
        val data = HolidayData.fromJson(
            linkedMapOf("year" to 2026L, "version" to 3L, "entries" to "not-a-list"),
        )

        assertEquals(2026, data.year)
        assertEquals(3, data.version)
        assertEquals(emptyList<HolidayEntry>(), data.entries)
        // 写回是空数组而不是 null，旧解析器不会因此炸。
        assertEquals(emptyList<Any?>(), data.toJson()["entries"])
    }

    @Test
    fun `单条坏条目跳过好条目保留`() {
        val data = HolidayData.fromJson(
            linkedMapOf(
                "year" to 2026L,
                "entries" to listOf(
                    // groupId 是数字：Dart `as String?` 抛 TypeError → 整条跳过。
                    mapOf("date" to "2026-10-01", "name" to "国庆", "type" to "vacation", "groupId" to 1),
                    // date 非字符串。
                    mapOf("date" to 20260102, "name" to "坏日期"),
                    // name 空白。
                    mapOf("date" to "2026-10-03", "name" to "   "),
                    // 好条目。
                    mapOf("date" to "2026-10-04", "name" to "调休上班", "type" to "adjusted_workday"),
                ),
            ),
        )

        assertEquals(1, data.entries.size)
        assertEquals(LocalDateTime.of(2026, 10, 4, 0, 0), data.entries.single().date)
        assertEquals(HolidayType.AdjustedWorkday, data.entries.single().type)
    }

    @Test
    fun `year 缺失或非数字整份拒绝且 NaN 也拒绝`() {
        assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(linkedMapOf("entries" to emptyList<Any?>()))
        }
        assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(linkedMapOf("year" to "abc"))
        }
        assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(linkedMapOf("year" to Double.NaN))
        }
        // 数字字符串可用（远端接口常以字符串下发年份）。
        assertEquals(2026, HolidayData.fromJson(linkedMapOf("year" to "2026")).year)
    }

    @Test
    fun `version 非数字抛且缺省为一`() {
        assertEquals(1, HolidayData.fromJson(linkedMapOf("year" to 2026L)).version)
        assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(linkedMapOf("year" to 2026L, "version" to "v2"))
        }
        assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(linkedMapOf("year" to 2026L, "version" to Double.NEGATIVE_INFINITY))
        }
    }

    @Test
    fun `未知 type 回落法定假期而不是丢条目`() {
        // Dart firstWhere orElse → vacation；写回时归一成 "vacation"。
        val data = HolidayData.fromJson(
            linkedMapOf(
                "year" to 2026L,
                "entries" to listOf(mapOf("date" to "2026-05-01", "name" to "劳动节", "type" to "weird")),
            ),
        )

        assertEquals(HolidayType.Vacation, data.entries.single().type)
        assertEquals("vacation", data.entries.single().toJson()["type"])
    }

    // ---------- 优先级 ----------

    @Test
    fun `调休上班日优先于同日法定假期`() {
        val data = HolidayData(
            2026,
            1,
            listOf(
                entry("2026-10-01", "国庆", "vacation"),
                entry("2026-10-01", "调休上班", "adjusted_workday"),
            ),
        )

        assertFalse("同一天既是假期又是上班日 → 按上班处理", data.isHoliday(LocalDateTime.of(2026, 10, 1, 12, 0)))
        assertTrue(data.isAdjustedWorkday(LocalDateTime.of(2026, 10, 1, 0, 0)))
        // 快照键同步为空，桌面小组件不会把当天课表灰掉。
        assertEquals(emptyList<String>(), data.holidayDateKeysForSnapshot())
    }

    @Test
    fun `自定义假期覆盖调休上班`() {
        val data = HolidayData(
            2026,
            1,
            listOf(
                entry("2026-10-01", "调休上班", "adjusted_workday"),
                entry("2026-10-01", "自建放假", "vacation", groupId = "custom-oct"),
            ),
        )

        assertTrue(data.isHoliday(LocalDateTime.of(2026, 10, 1, 9, 0)))
        assertFalse("自定义假期接管后不算上班日", data.isAdjustedWorkday(LocalDateTime.of(2026, 10, 1, 9, 0)))
    }

    // ---------- 闰年与快照键 ----------

    @Test
    fun `闰年 2-29 可解析且快照键为不补零年份`() {
        val data = HolidayData.fromJson(
            linkedMapOf(
                "year" to 2024L,
                "entries" to listOf(
                    mapOf("date" to "2024-02-29", "name" to "自建假期", "type" to "vacation", "groupId" to "custom-leap"),
                    // 同一天再来一条：快照键要按日期去重。
                    mapOf("date" to "2024-02-29T08:00:00.000", "name" to "重复", "type" to "adjusted_restday"),
                ),
            ),
        )

        assertEquals(
            LocalDateTime.of(2024, 2, 29, 0, 0),
            data.entryForDate(LocalDateTime.of(2024, 2, 29, 23, 59))?.date,
        )
        assertTrue(data.isHoliday(LocalDateTime.of(2024, 2, 29, 0, 0)))
        assertEquals(listOf("2024-02-29"), data.holidayDateKeysForSnapshot())
    }

    @Test
    fun `快照键按日期升序且跨年不错位`() {
        val data = HolidayData(
            2026,
            1,
            listOf(
                entry("2026-01-02", "元旦后"),
                entry("2025-12-31", "跨年"),
                entry("2026-01-01", "元旦"),
            ),
        )

        assertEquals(
            listOf("2025-12-31", "2026-01-01", "2026-01-02"),
            data.holidayDateKeysForSnapshot(),
        )
        // 编码后再解码，条目集合不变。
        val reparsed = HolidayData.fromJson(MiniJson.parse(data.toJsonString()) as Map<String, Any?>)
        assertEquals(data.year, reparsed.year)
        assertEquals(data.entries, reparsed.entries)
    }
}
