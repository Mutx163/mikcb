package com.mutx163.qingyu.pages.holiday

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.calendar.HolidayCustomSaveException
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayPreferences
import com.mutx163.qingyu.calendar.HolidayProvider
import com.mutx163.qingyu.calendar.HolidayRemoteGateway
import com.mutx163.qingyu.calendar.HolidayType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

/**
 * 节假日状态机（`HolidayProvider`）的 JVM 单测。
 *
 * 覆盖 audit §7「数据层」那一行：兜底顺序 / 缓存命中不再取网 / 损坏不覆盖 /
 * CRUD 往返 / 跨年合并 / 日志上限。
 *
 * 期望值来源：Dart `holiday_service.dart:105-162` 与
 * `timetable_holiday_service.dart:54-92` 的规则手算，不从实现里抄。
 */
class HolidayProviderTest {

    // 2026-10-01 是周四 → 那一周（09-28 周一 ~ 10-04 周日）只跨 2026 一年。
    private val clockAtNationalDay: () -> LocalDate = { LocalDate.of(2026, 10, 1) }
    private val timeNineSharp: () -> LocalTime = { LocalTime.of(9, 0, 12) }

    @Test
    fun `本地缓存命中时不再请求远端`() {
        val store = InMemoryKeyValueStore()
        val preferences = HolidayPreferences(store)
        preferences.saveYear(
            2026,
            HolidayData(2026, 1, listOf(entry(2026, 10, 1, "国庆节", HolidayType.Vacation, "holiday-2026-0"))),
        )
        val gateway = FakeGateway(emptyMap())
        val provider = HolidayProvider(gateway, preferences, { null }, clockAtNationalDay, timeNineSharp)

        provider.initialize()

        assertEquals("命中本地缓存就一步都不该联网", emptyList<Int>(), gateway.fetched)
        assertEquals(1, provider.snapshot.data!!.entries.size)
        assertEquals("2026 年：命中本地缓存 1 条，后台刷新中", provider.logs[0].message)
        assertEquals("时刻是已格式化的 HH:mm:ss", "09:00:12", provider.logs[0].time)
    }

    @Test
    fun `第二次初始化命中内存缓存且不再取网`() {
        val gateway = FakeGateway(
            mapOf(
                2026 to HolidayData(
                    2026,
                    1,
                    listOf(
                        entry(2026, 10, 1, "国庆节", HolidayType.Vacation, "holiday-2026-0"),
                        entry(2026, 10, 10, "调休上班", HolidayType.AdjustedWorkday, "holiday-2026-0"),
                    ),
                ),
            ),
        )
        val provider = HolidayProvider(
            gateway,
            HolidayPreferences(InMemoryKeyValueStore()),
            { null },
            clockAtNationalDay,
            timeNineSharp,
        )

        provider.initialize()
        assertEquals(listOf(2026), gateway.fetched)
        assertEquals("2026 年：远程拉取成功 2 条，已缓存", provider.logs[0].message)

        provider.initialize()

        assertEquals("第二遍必须命中内存缓存，不许再联网", listOf(2026), gateway.fetched)
        assertEquals("2026 年：命中内存缓存 2 条，后台刷新中", provider.logs[0].message)
    }

    @Test
    fun `远端失败时退到内置资产并把它落盘`() {
        val builtin = """
            {"year":2026,"version":1,"entries":[
              {"date":"2026-01-01","name":"元旦","type":"vacation","groupId":"new-year-2026"},
              {"date":"2026-01-04","name":"调休上班","type":"adjusted_workday","groupId":"new-year-2026"}
            ]}
        """.trimIndent()
        val preferences = HolidayPreferences(InMemoryKeyValueStore())
        val provider = HolidayProvider(
            FakeGateway(emptyMap()),
            preferences,
            { year -> if (year == 2026) builtin else null },
            clockAtNationalDay,
            timeNineSharp,
        )

        provider.initialize()

        assertEquals(2, provider.snapshot.data!!.entries.size)
        assertEquals("2026 年：加载内置数据 2 条", provider.logs[0].message)
        assertEquals("2026 年：远程拉取失败，使用内置资产兜底", provider.logs[1].message)
        assertEquals("2026 年：无缓存，正在拉取远程数据……", provider.logs[2].message)
        assertNotNull("非空兜底要落盘，下次启动才不用重新取网", preferences.loadYear(2026))
        assertEquals(2, preferences.loadYear(2026)!!.entries.size)
    }

    @Test
    fun `内置资产也没有该年数据时不把空结果写进缓存`() {
        val preferences = HolidayPreferences(InMemoryKeyValueStore())
        val provider = HolidayProvider(
            FakeGateway(emptyMap()),
            preferences,
            { null },
            clockAtNationalDay,
            timeNineSharp,
        )

        provider.initialize()

        assertEquals(0, provider.snapshot.data!!.entries.size)
        assertEquals("2026 年：加载内置数据 0 条", provider.logs[0].message)
        assertNull(
            "空兜底一旦落盘就等于宣布「这一年确定没有假期」，后续版本的资产永远读不到",
            preferences.loadYear(2026),
        )
    }

    @Test
    fun `12 月末那一周会把邻年数据一起合进来`() {
        // 2026-12-28 是周一，那一周 12-28 ~ 2027-01-03 跨年 → 要额外加载 2027。
        val gateway = FakeGateway(
            mapOf(
                2026 to HolidayData(
                    2026,
                    1,
                    listOf(entry(2026, 12, 31, "元旦", HolidayType.Vacation, "new-year-2026")),
                ),
                2027 to HolidayData(
                    2027,
                    1,
                    listOf(
                        entry(2027, 1, 1, "元旦", HolidayType.Vacation, "new-year-2026"),
                        entry(2027, 1, 2, "元旦", HolidayType.Vacation, "new-year-2026"),
                    ),
                ),
            ),
        )
        val provider = HolidayProvider(
            gateway,
            HolidayPreferences(InMemoryKeyValueStore()),
            { null },
            { LocalDate.of(2026, 12, 28) },
            timeNineSharp,
        )

        provider.initialize()

        assertEquals("当前年在前，邻年随后（与 Dart 的集合字面量顺序一致）", listOf(2026, 2027), gateway.fetched)
        val merged = provider.snapshot.data!!
        assertEquals("三个条目来自两份响应合并", 3, merged.entries.size)
        assertEquals("合并后仍标当前年", 2026, merged.year)
        assertTrue(merged.entries.any { it.date == at(2027, 1, 2) })
    }

    @Test
    fun `1 月初那一周会把上一年数据一起合进来`() {
        // 2026-01-01 是周四，那一周 2025-12-29 ~ 2026-01-04 → 要额外加载 2025。
        val gateway = FakeGateway(
            mapOf(
                2026 to HolidayData(2026, 1, listOf(entry(2026, 1, 1, "元旦", HolidayType.Vacation, "new-year-2026"))),
                2025 to HolidayData(2025, 1, listOf(entry(2025, 12, 31, "元旦", HolidayType.Vacation, "new-year-2025"))),
            ),
        )
        val provider = HolidayProvider(
            gateway,
            HolidayPreferences(InMemoryKeyValueStore()),
            { null },
            { LocalDate.of(2026, 1, 1) },
            timeNineSharp,
        )

        provider.initialize()

        assertEquals(listOf(2026, 2025), gateway.fetched)
        val merged = provider.snapshot.data!!
        assertEquals(2, merged.entries.size)
        assertTrue(merged.entries.any { it.date == at(2025, 12, 31) })
    }

    @Test
    fun `刷新强制走远端并覆盖本地缓存`() {
        val preferences = HolidayPreferences(InMemoryKeyValueStore())
        preferences.saveYear(
            2026,
            HolidayData(2026, 1, listOf(entry(2026, 10, 1, "旧数据", HolidayType.Vacation, "holiday-2026-0"))),
        )
        val gateway = FakeGateway(
            mapOf(
                2026 to HolidayData(
                    2026,
                    1,
                    listOf(
                        entry(2026, 10, 1, "国庆节", HolidayType.Vacation, "holiday-2026-0"),
                        entry(2026, 10, 2, "调休上班", HolidayType.AdjustedWorkday, "holiday-2026-0"),
                        entry(2026, 10, 3, "国庆节", HolidayType.Vacation, "holiday-2026-0"),
                    ),
                ),
            ),
        )
        val provider = HolidayProvider(gateway, preferences, { null }, clockAtNationalDay, timeNineSharp)

        provider.initialize()
        assertEquals("初始化时命中缓存，不联网", emptyList<Int>(), gateway.fetched)
        assertEquals(1, provider.snapshot.data!!.entries.size)

        provider.refresh()

        assertEquals("refresh 必须真的去取网", listOf(2026), gateway.fetched)
        assertEquals(3, provider.snapshot.data!!.entries.size)
        assertEquals("2026 年：远程拉取成功 3 条，已缓存", provider.logs[0].message)
        assertEquals("新数据要写回本地缓存", 3, preferences.loadYear(2026)!!.entries.size)
        assertFalse(provider.snapshot.refreshing)
    }

    @Test
    fun `自定义假期增删改往返`() {
        val preferences = HolidayPreferences(InMemoryKeyValueStore())
        val provider = HolidayProvider(
            FakeGateway(emptyMap()),
            preferences,
            { null },
            clockAtNationalDay,
            timeNineSharp,
        )
        provider.initialize()
        assertEquals(emptyList<HolidayEntry>(), provider.snapshot.customHolidays)
        assertFalse(provider.snapshot.customCorrupted)

        val schoolFestival = listOf(
            entry(2026, 10, 1, "校庆", HolidayType.Vacation, "custom-1"),
            entry(2026, 10, 2, "校庆", HolidayType.Vacation, "custom-1"),
        )
        provider.addCustomHolidays(schoolFestival)

        assertEquals(2, provider.snapshot.customHolidays.size)
        assertEquals("新增必须落盘", 2, provider.customHolidaysOrNull()!!.size)

        provider.updateCustomHoliday(
            "custom-1",
            listOf(entry(2026, 10, 5, "校庆改期", HolidayType.Vacation, "custom-1")),
        )

        val afterUpdate = provider.customHolidaysOrNull()!!
        assertEquals("整组替换：2 条变 1 条", 1, afterUpdate.size)
        assertEquals(at(2026, 10, 5), afterUpdate[0].date)
        assertEquals("校庆改期", afterUpdate[0].name)

        provider.addCustomHolidays(
            listOf(entry(2026, 11, 1, "校运会", HolidayType.Vacation, "custom-2")),
        )
        assertEquals(2, provider.customHolidaysOrNull()!!.size)

        provider.removeCustomHoliday("custom-1")

        val afterRemove = provider.customHolidaysOrNull()!!
        assertEquals(1, afterRemove.size)
        assertEquals("custom-2", afterRemove[0].groupId)
        assertEquals(1, provider.snapshot.customHolidays.size)
    }

    @Test
    fun `自定义假期损坏时拒绝覆盖且抛异常`() {
        val corrupt = "{这一坨不是 JSON 数组"
        val store = InMemoryKeyValueStore(mapOf("custom_holidays" to corrupt))
        val provider = HolidayProvider(
            FakeGateway(emptyMap()),
            HolidayPreferences(store),
            { null },
            clockAtNationalDay,
            timeNineSharp,
        )

        provider.initialize()

        assertTrue("损坏要能被界面看见（提示条）", provider.snapshot.customCorrupted)
        assertEquals(emptyList<HolidayEntry>(), provider.snapshot.customHolidays)
        assertNull(provider.customHolidaysOrNull())
        assertTrue(
            "未识别的键原样透传，界面照原样展示这条提示",
            provider.logs.any { it.message == "custom_holidays_corrupted" },
        )

        try {
            provider.addCustomHolidays(listOf(entry(2026, 10, 1, "校庆", HolidayType.Vacation, "custom-1")))
            fail("损坏态下必须拒绝写回，否则会把真实数据清零")
        } catch (_: HolidayCustomSaveException) {
            // 期望路径
        }

        assertEquals("损坏的原值必须原封不动留在盘上", corrupt, store.getString("custom_holidays"))
    }

    @Test
    fun `日志最多保留 50 条且最新在前`() {
        val gateway = FakeGateway(
            mapOf(
                2026 to HolidayData(
                    2026,
                    1,
                    listOf(
                        entry(2026, 10, 1, "国庆节", HolidayType.Vacation, "holiday-2026-0"),
                        entry(2026, 10, 2, "国庆节", HolidayType.Vacation, "holiday-2026-0"),
                    ),
                ),
            ),
        )
        val provider = HolidayProvider(
            gateway,
            HolidayPreferences(InMemoryKeyValueStore()),
            { null },
            clockAtNationalDay,
            timeNineSharp,
        )

        provider.initialize() // 1 条：远程拉取成功
        repeat(60) { provider.initialize() } // 每次 +1 条内存命中 → 共 61 条

        assertEquals("上限沿用 Dart 的 50", 50, provider.logs.size)
        assertEquals("最新的一条排在最前", "2026 年：命中内存缓存 2 条，后台刷新中", provider.logs[0].message)
        assertFalse(
            "61 条塞进 50 个位置 → 最老的 11 条被挤掉，远程拉取成功那条（最早）已经不在列表里",
            provider.logs.any { it.message == "2026 年：远程拉取成功 2 条，已缓存" },
        )
    }

    @Test
    fun `监听器在状态变化时收到通知`() {
        val provider = HolidayProvider(
            FakeGateway(emptyMap()),
            HolidayPreferences(InMemoryKeyValueStore()),
            { null },
            clockAtNationalDay,
            timeNineSharp,
        )
        var notified = 0
        val listener: () -> Unit = { notified++ }
        provider.addListener(listener)

        provider.initialize()
        assertEquals(1, notified)

        provider.refresh()
        assertEquals("refresh 前后各通知一次（亮 loading + 收尾）", 3, notified)

        provider.removeListener(listener)
        provider.initialize()
        assertEquals("移除后不再收到通知", 3, notified)
    }

    @Test
    fun `mergedData 把自定义假期并进官方数据`() {
        val gateway = FakeGateway(
            mapOf(
                2026 to HolidayData(
                    2026,
                    1,
                    listOf(entry(2026, 10, 1, "国庆节", HolidayType.Vacation, "holiday-2026-0")),
                ),
            ),
        )
        val provider = HolidayProvider(
            gateway,
            HolidayPreferences(InMemoryKeyValueStore()),
            { null },
            clockAtNationalDay,
            timeNineSharp,
        )
        provider.initialize()
        provider.addCustomHolidays(
            listOf(entry(2026, 10, 8, "校庆", HolidayType.Vacation, "custom-1")),
        )

        assertFalse("官方数据里没有 10-08", provider.snapshot.data!!.isHoliday(at(2026, 10, 8)))
        assertTrue("合并后月视图/小组件才认得出校庆", provider.mergedData()!!.isHoliday(at(2026, 10, 8)))
    }
}

/** 假网关：记录被问过哪几年，按年份查表返回（查不到 = 远端失败）。 */
private class FakeGateway(private val byYear: Map<Int, HolidayData?>) : HolidayRemoteGateway {

    val fetched = mutableListOf<Int>()

    override fun fetchYear(year: Int, log: (String) -> Unit): HolidayData? {
        fetched += year
        return byYear[year]
    }
}

private fun entry(
    year: Int,
    month: Int,
    day: Int,
    name: String,
    type: HolidayType,
    groupId: String,
): HolidayEntry = HolidayEntry(at(year, month, day), name, type, groupId)

private fun at(year: Int, month: Int, day: Int): LocalDateTime =
    LocalDateTime.of(year, month, day, 0, 0)
