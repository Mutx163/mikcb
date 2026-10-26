package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * HolidayEntry / HolidayData 模型与 JSON 契约测试。
 *
 * 期望值来源：
 * - [Dart抄录]：lib/models/holiday_entry.dart 的判定与字段名逐字对照；
 * - [Dart抄录-测试]：test/services/holiday_service_test.dart 的既有断言；
 * - [Dart推演]：按 Dart jsonEncode/类型转换公开语义推出。
 */
class HolidayModelsTest {

    private fun entry(
        y: Int,
        m: Int,
        d: Int,
        name: String = "国庆节",
        type: HolidayType = HolidayType.Vacation,
        groupId: String? = "g1",
    ) = HolidayEntry(
        date = DartTime.dateTime(y, m, d),
        name = name,
        type = type,
        groupId = groupId,
    )

    private fun data(vararg entries: HolidayEntry) =
        HolidayData(year = 2026, version = 1, entries = entries.toList())

    // ---------- HolidayType ----------

    @Test
    fun `holiday type json values match dart contract`() { // [Dart抄录] holiday_entry.dart:16-20
        assertEquals("vacation", HolidayType.Vacation.value)
        assertEquals("adjusted_workday", HolidayType.AdjustedWorkday.value)
        assertEquals("adjusted_restday", HolidayType.AdjustedRestday.value)
    }

    @Test
    fun `unknown type value falls back to vacation`() { // [Dart抄录] holiday_entry.dart:22-27 firstWhere orElse
        assertEquals(HolidayType.Vacation, HolidayType.fromValue("vacation"))
        assertEquals(HolidayType.AdjustedWorkday, HolidayType.fromValue("adjusted_workday"))
        assertEquals(HolidayType.AdjustedRestday, HolidayType.fromValue("adjusted_restday"))
        assertEquals(HolidayType.Vacation, HolidayType.fromValue("bogus"))
        assertEquals(HolidayType.Vacation, HolidayType.fromValue(null))
    }

    // ---------- HolidayEntry 判定 ----------

    @Test
    fun `adjustedRestday should hide courses`() { // [Dart抄录-测试] holiday_service_test.dart:840-850
        val e = entry(2026, 10, 1, type = HolidayType.AdjustedRestday)
        assertTrue(e.shouldHideCourses)
        assertFalse(e.isAdjustedWorkday)
    }

    @Test
    fun `vacation should hide courses`() { // [Dart抄录-测试] holiday_service_test.dart:852-862
        val e = entry(2026, 10, 1)
        assertTrue(e.shouldHideCourses)
        assertFalse(e.isAdjustedWorkday)
    }

    @Test
    fun `adjustedWorkday does not hide courses`() { // [Dart抄录-测试] holiday_service_test.dart:864-874
        val e = entry(2026, 9, 27, name = "调休上班", type = HolidayType.AdjustedWorkday)
        assertFalse(e.shouldHideCourses)
        assertTrue(e.isAdjustedWorkday)
    }

    // ---------- HolidayEntry JSON ----------

    @Test
    fun `toJson keeps dart field names and truncates date to 10 chars`() { // [Dart抄录] holiday_entry.dart:58-63
        val e = HolidayEntry(
            date = DartTime.dateTime(2026, 10, 1, 15, 30),
            name = "国庆节",
            type = HolidayType.Vacation,
            groupId = "holiday-2026-0",
        )
        val json = e.toJson()
        assertEquals(
            linkedSetOf("date", "name", "type", "groupId"),
            json.keys.toSet(),
        )
        assertEquals("2026-10-01", json["date"])
        assertEquals("国庆节", json["name"])
        assertEquals("vacation", json["type"])
        assertEquals("holiday-2026-0", json["groupId"])
    }

    @Test
    fun `toJson keeps null groupId as explicit null`() { // [Dart推演] Dart jsonEncode(null) → null 键保留
        val json = entry(2026, 10, 1, groupId = null).toJson()
        assertTrue(json.containsKey("groupId"))
        assertNull(json["groupId"])
        assertEquals(
            """{"date":"2026-10-01","name":"国庆节","type":"vacation","groupId":null}""",
            MiniJson.encode(json),
        )
    }

    @Test
    fun `fromJson parses date-only and datetime strings`() { // [Dart抄录] holiday_entry.dart:65-84 DateTime.tryParse
        val e1 = HolidayEntry.fromJson(mapOf("date" to "2026-10-01", "name" to "国庆节"))
        assertEquals(2026, e1.date.year)
        assertEquals(10, e1.date.monthValue)
        assertEquals(1, e1.date.dayOfMonth)
        assertEquals(HolidayType.Vacation, e1.type)
        assertNull(e1.groupId)

        val e2 = HolidayEntry.fromJson(
            mapOf(
                "date" to "2026-10-01 15:30:00",
                "name" to "国庆节",
                "type" to "adjusted_workday",
                "groupId" to "g2",
            ),
        )
        assertEquals(15, e2.date.hour)
        assertEquals(HolidayType.AdjustedWorkday, e2.type)
        assertEquals("g2", e2.groupId)
    }

    @Test
    fun `fromJson structural missing fields throw`() { // [Dart抄录] holiday_entry.dart:66-77 错误文案逐字
        val e1 = assertThrows(DartFormatException::class.java) {
            HolidayEntry.fromJson(mapOf("name" to "国庆节"))
        }
        assertEquals("missing holiday date", e1.message)

        val e2 = assertThrows(DartFormatException::class.java) {
            HolidayEntry.fromJson(mapOf("date" to "   ", "name" to "国庆节"))
        }
        assertEquals("missing holiday date", e2.message)

        val e3 = assertThrows(DartFormatException::class.java) {
            HolidayEntry.fromJson(mapOf("date" to "not-a-date", "name" to "国庆节"))
        }
        assertEquals("invalid holiday date: not-a-date", e3.message)

        val e4 = assertThrows(DartFormatException::class.java) {
            HolidayEntry.fromJson(mapOf("date" to "2026-10-01"))
        }
        assertEquals("missing holiday name", e4.message)
    }

    // ---------- HolidayData 判定 ----------

    @Test
    fun `entryForDate ignores time component`() { // [Dart抄录-测试] holiday_service_test.dart:1407-1423
        val d = data(entry(2026, 10, 1))
        assertEquals("国庆节", d.entryForDate(DartTime.dateTime(2026, 10, 1, 15, 30))?.name)
        assertNull(d.entryForDate(DartTime.dateTime(2026, 10, 2)))
    }

    @Test
    fun `isHoliday true for vacation day and false for adjacent day`() { // [Dart抄录-测试] holiday_service_test.dart:1371-1387
        val d = data(entry(2026, 10, 1))
        assertTrue(d.isHoliday(DartTime.dateTime(2026, 10, 1)))
        assertFalse(d.isHoliday(DartTime.dateTime(2026, 10, 2)))
    }

    @Test
    fun `time-of-day does not leak into holiday match`() { // [Dart抄录-测试] holiday_service_test.dart:791-824
        val d = data(entry(2026, 10, 1))
        assertTrue(d.isHoliday(DartTime.dateTime(2026, 10, 1, 23, 59, 59)))
        assertFalse(d.isHoliday(DartTime.dateTime(2026, 10, 2)))
    }

    @Test
    fun `adjusted workday beats vacation on the same day`() { // [Dart抄录] holiday_entry.dart:117-136
        val d = data(
            entry(2026, 10, 1),
            entry(2026, 10, 1, name = "调休上班", type = HolidayType.AdjustedWorkday),
        )
        assertFalse(d.isHoliday(DartTime.dateTime(2026, 10, 1)))
    }

    @Test
    fun `custom rest overrides makeup workday`() { // [Dart抄录] holiday_entry.dart:117-136,186-199
        val d = data(
            entry(2026, 10, 1, name = "调休上班", type = HolidayType.AdjustedWorkday),
            entry(2026, 10, 1, name = "我要休息", groupId = "custom-999"),
        )
        assertTrue(d.isHoliday(DartTime.dateTime(2026, 10, 1)))
        assertFalse(d.isAdjustedWorkday(DartTime.dateTime(2026, 10, 1)))
    }

    @Test
    fun `custom prefix matters for custom priority`() { // [Dart抄录] holiday_entry.dart:211-212
        // groupId 不以 custom- 开头 → 不享受自定义优先级，调休上班仍胜出。
        val d = data(
            entry(2026, 10, 1, name = "调休上班", type = HolidayType.AdjustedWorkday),
            entry(2026, 10, 1, name = "我要休息", groupId = "holiday-x"),
        )
        assertFalse(d.isHoliday(DartTime.dateTime(2026, 10, 1)))
        assertTrue(d.isAdjustedWorkday(DartTime.dateTime(2026, 10, 1)))
    }

    @Test
    fun `adjustedRestday hides courses`() { // [Dart抄录] shouldHideCourses 含 adjusted_restday
        val d = data(entry(2026, 10, 1, type = HolidayType.AdjustedRestday))
        assertTrue(d.isHoliday(DartTime.dateTime(2026, 10, 1)))
    }

    @Test
    fun `isAdjustedWorkday true only on workday entries`() { // [Dart抄录-测试] holiday_service_test.dart:1389-1405
        val d = data(entry(2026, 9, 27, name = "调休上班", type = HolidayType.AdjustedWorkday))
        assertTrue(d.isAdjustedWorkday(DartTime.dateTime(2026, 9, 27)))
        assertFalse(d.isAdjustedWorkday(DartTime.dateTime(2026, 9, 28)))
    }

    // ---------- 快照键 ----------

    @Test
    fun `dateKey pads month and day but not year`() { // [Dart抄录] holiday_entry.dart:180-183 逐字对齐
        assertEquals("2026-01-01", HolidayData.dateKey(DartTime.dateTime(2026, 1, 1)))
        assertEquals("2026-12-31", HolidayData.dateKey(DartTime.dateTime(2026, 12, 31)))
        assertEquals("999-01-01", HolidayData.dateKey(DartTime.dateTime(999, 1, 1)))
    }

    @Test
    fun `holiday snapshot keys exclude custom-covered makeup and workdays`() { // [Dart抄录] holiday_entry.dart:142-156
        val d = HolidayData(
            year = 2026,
            version = 1,
            entries = listOf(
                entry(2026, 10, 1, groupId = "holiday-2026-0"),
                entry(2026, 10, 2, groupId = "holiday-2026-0"),
                entry(2026, 10, 1, name = "我要休息", groupId = "custom-999"),
                entry(2026, 9, 27, name = "调休上班", type = HolidayType.AdjustedWorkday, groupId = "holiday-2026-0"),
            ),
        )
        assertEquals(listOf("2026-10-01", "2026-10-02"), d.holidayDateKeysForSnapshot())
    }

    @Test
    fun `adjusted workday snapshot keys respect custom rest override`() { // [Dart抄录] holiday_entry.dart:161-178
        val d = HolidayData(
            year = 2026,
            version = 1,
            entries = listOf(
                entry(2026, 9, 27, name = "调休上班", type = HolidayType.AdjustedWorkday, groupId = "holiday-2026-0"),
                entry(2026, 10, 10, name = "调休上班", type = HolidayType.AdjustedWorkday, groupId = "holiday-2026-0"),
                entry(2026, 10, 10, name = "我要休息", groupId = "custom-999"),
            ),
        )
        assertEquals(listOf("2026-09-27"), d.adjustedWorkdayDateKeysForSnapshot())
    }

    // ---------- 分组 ----------

    @Test
    fun `entriesForGroup filters and sorts by date`() { // [Dart抄录] holiday_entry.dart:203-206
        val d = HolidayData(
            year = 2026,
            version = 1,
            entries = listOf(
                entry(2026, 10, 3, groupId = "g1"),
                entry(2026, 10, 1, groupId = "g2"),
                entry(2026, 10, 1, groupId = "g1"),
            ),
        )
        assertEquals(
            listOf("2026-10-01", "2026-10-03"),
            d.entriesForGroup("g1").map { HolidayData.dateKey(it.date) },
        )
    }

    // ---------- HolidayData JSON ----------

    @Test
    fun `data json roundtrip preserves data`() { // [Dart抄录-测试] holiday_service_test.dart:1339-1369
        val original = HolidayData(
            year = 2026,
            version = 7,
            entries = listOf(
                entry(2026, 10, 1, groupId = "holiday-2026-0"),
                entry(2026, 9, 27, name = "调休上班", type = HolidayType.AdjustedWorkday, groupId = "holiday-2026-0"),
            ),
        )
        val restored = HolidayData.fromJsonString(original.toJsonString())
        assertEquals(2026, restored.year)
        assertEquals(7, restored.version)
        assertEquals(2, restored.entries.size)
        assertEquals("国庆节", restored.entries[0].name)
        assertEquals(HolidayType.Vacation, restored.entries[0].type)
        assertEquals(HolidayType.AdjustedWorkday, restored.entries[1].type)
    }

    @Test
    fun `data fromJson accepts int double and string year`() { // [Dart抄录] holiday_entry.dart:220-235
        assertEquals(2026, HolidayData.fromJson(mapOf("year" to 2026L)).year)
        assertEquals(2026, HolidayData.fromJson(mapOf("year" to 2026.0)).year)
        assertEquals(2026, HolidayData.fromJson(mapOf("year" to "2026")).year)
        // 缺 version 默认 1；小数 version 截断。
        assertEquals(1, HolidayData.fromJson(mapOf("year" to 2026L)).version)
        assertEquals(7, HolidayData.fromJson(mapOf("year" to 2026L, "version" to 7L)).version)
        assertEquals(7, HolidayData.fromJson(mapOf("year" to 2026L, "version" to 7.7)).version)
    }

    @Test
    fun `data fromJson rejects missing or bad year`() { // [Dart抄录] holiday_entry.dart:229-234 错误文案
        val e1 = assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(mapOf("version" to 1L))
        }
        assertEquals("missing holiday year", e1.message)

        val e2 = assertThrows(DartFormatException::class.java) {
            HolidayData.fromJson(mapOf("year" to "abc"))
        }
        assertEquals("invalid holiday year: abc", e2.message)
    }

    @Test
    fun `data fromJson skips bad entries keeps good ones`() { // [Dart抄录] holiday_entry.dart:237-250 逐条容错
        val d = HolidayData.fromJson(
            mapOf(
                "year" to 2026L,
                "entries" to listOf(
                    mapOf<String, Any?>("date" to "2026-10-01", "name" to "国庆节"),
                    42L, // 非 Map 条目直接跳过
                    mapOf<String, Any?>("date" to "2026-10-02"), // 缺 name → 跳过
                    mapOf<String, Any?>("date" to "2026-10-03", "name" to "元旦"),
                ),
            ),
        )
        assertEquals(2, d.entries.size)
        assertEquals("国庆节", d.entries[0].name)
        assertEquals("元旦", d.entries[1].name)
    }

    @Test
    fun `data fromJson tolerates missing or non-list entries`() { // [Dart抄录] holiday_entry.dart:237-239
        assertEquals(0, HolidayData.fromJson(mapOf("year" to 2026L)).entries.size)
        assertEquals(
            0,
            HolidayData.fromJson(mapOf("year" to 2026L, "entries" to 5L)).entries.size,
        )
    }
}
