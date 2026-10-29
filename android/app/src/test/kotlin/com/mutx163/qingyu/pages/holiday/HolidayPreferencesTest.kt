package com.mutx163.qingyu.pages.holiday

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.calendar.HolidayCustomSaveException
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayPreferences
import com.mutx163.qingyu.calendar.HolidayType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.LocalDateTime

/**
 * 节假日持久化（`HolidayPreferences`，Dart `holiday_service.dart` 的 prefs 部分）的 JVM 单测。
 *
 * 三态是重点：**「没有数据」（空列表）与「数据坏了」（null）必须区分开**——
 * 混为一谈会导致一次保存把用户的自定义假期清零（Issue #52 审核 S4）。
 */
class HolidayPreferencesTest {

    @Test
    fun `年度数据写入后能原样读回`() {
        val store = InMemoryKeyValueStore()
        val prefs = HolidayPreferences(store)
        val data = HolidayData(
            year = 2026,
            version = 1,
            entries = listOf(
                HolidayEntry(at(2026, 10, 1), "国庆节", HolidayType.Vacation, "holiday-2026-0"),
                HolidayEntry(at(2026, 10, 10), "调休上班", HolidayType.AdjustedWorkday, "holiday-2026-0"),
            ),
        )

        prefs.saveYear(2026, data)

        assertEquals(data, prefs.loadYear(2026))
        assertTrue(
            "落盘键必须是 Flutter 侧读得到的 flutter.holiday_data_2026",
            store.rawSnapshot().containsKey("flutter.holiday_data_2026"),
        )
    }

    @Test
    fun `没有缓存时返回 null 而不是空数据`() {
        val store = InMemoryKeyValueStore()
        val prefs = HolidayPreferences(store)

        assertNull(prefs.loadYear(2027))
        assertTrue("读不到就不该凭空写出一个键", store.rawSnapshot().isEmpty())
    }

    @Test
    fun `年度缓存内容损坏时返回 null`() {
        val store = InMemoryKeyValueStore(mapOf("holiday_data_2026" to "{这一坨不是 JSON"))
        val prefs = HolidayPreferences(store)

        assertNull("坏缓存只能当作没缓存，不能假装「2026 年没有假期」", prefs.loadYear(2026))
    }

    @Test
    fun `清缓存后读回 null`() {
        val store = InMemoryKeyValueStore()
        val prefs = HolidayPreferences(store)
        prefs.saveYear(2026, HolidayData(2026, 1, emptyList()))

        prefs.clearYear(2026)

        assertNull(prefs.loadYear(2026))
        assertTrue(store.rawSnapshot().isEmpty())
    }

    @Test
    fun `自定义假期键不存在时返回空列表`() {
        val prefs = HolidayPreferences(InMemoryKeyValueStore())

        assertEquals(
            "键不存在是合法的「还没加过」，与损坏态（null）不是一回事",
            emptyList<HolidayEntry>(),
            prefs.loadCustomHolidays(),
        )
    }

    @Test
    fun `自定义假期内容损坏时返回 null`() {
        val brokenJson = InMemoryKeyValueStore(mapOf("custom_holidays" to "{不是数组"))
        assertNull(HolidayPreferences(brokenJson).loadCustomHolidays())

        // 合法 JSON 但不是数组（历史上被别的版本写成对象）也算损坏。
        val wrongShape = InMemoryKeyValueStore(mapOf("custom_holidays" to """{"a":1}"""))
        assertNull(HolidayPreferences(wrongShape).loadCustomHolidays())
    }

    @Test
    fun `自定义假期写盘后能原样读回`() {
        val store = InMemoryKeyValueStore()
        val prefs = HolidayPreferences(store)
        val entries = listOf(
            HolidayEntry(at(2026, 10, 1), "校庆", HolidayType.Vacation, "custom-1"),
            HolidayEntry(at(2026, 10, 2), "校庆", HolidayType.Vacation, "custom-1"),
        )

        prefs.saveCustomHolidays(entries)

        assertEquals(entries, prefs.loadCustomHolidays())
        assertTrue(store.rawSnapshot().containsKey("flutter.custom_holidays"))
    }

    @Test
    fun `单条坏记录被跳过而其余照常读回`() {
        val raw = """[
            {"date":"2026-10-01","name":"校庆","type":"vacation","groupId":"custom-1"},
            {"date":"坏日期","name":"坏条目","type":"vacation","groupId":"custom-1"},
            {"date":"2026-10-03","name":"校庆","type":"vacation","groupId":"custom-1"}
        ]"""
        val prefs = HolidayPreferences(InMemoryKeyValueStore(mapOf("custom_holidays" to raw)))

        val loaded = prefs.loadCustomHolidays()

        assertEquals("坏条目按条容错，不许整表判损坏", 2, loaded!!.size)
        assertEquals(at(2026, 10, 1), loaded[0].date)
        assertEquals(at(2026, 10, 3), loaded[1].date)
    }

    @Test
    fun `自定义假期写入失败时抛 HolidayCustomSaveException`() {
        val prefs = HolidayPreferences(ThrowingWriteStore(InMemoryKeyValueStore()))

        try {
            prefs.saveCustomHolidays(
                listOf(HolidayEntry(at(2026, 10, 1), "校庆", HolidayType.Vacation, "custom-1")),
            )
            fail("写盘失败必须抛出，否则用户会「看着存成功、重启即丢」")
        } catch (expected: HolidayCustomSaveException) {
            assertTrue(expected.cause != null)
        }
    }
}

/** 写盘一律失败的存储替身（模拟磁盘满）。 */
private class ThrowingWriteStore(delegate: KeyValueStore) : KeyValueStore by delegate {
    override fun putString(key: String, value: String) {
        throw IllegalStateException("disk full")
    }
}

private fun at(year: Int, month: Int, day: Int): LocalDateTime =
    LocalDateTime.of(year, month, day, 0, 0)
