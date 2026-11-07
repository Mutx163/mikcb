package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayEntry
import com.mutx163.qingyu.calendar.HolidayType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 节假日主页面「加载态 vs 空态」的判据（2026-11-05 新增）。
 *
 * ## 修的是什么
 *
 * 修前 `buildPageData` 只认 `official == null` 一种情况，于是**首屏加载中**（远端超时
 * 8 秒，`HolidayService.TIMEOUT_MILLIS`）页面显示的是「近期没有节假日」——一句假话：
 * 用户确实可能在放假。现在 `loading` 期间：
 *
 * 1. 法定节假日区块显示一行「正在加载节假日数据…」，不出「近期没有节假日」；
 * 2. 自定义假期区块不出「暂无自定义假期」（列表还没读出来）；
 * 3. 区块小标题退回不带年份的「法定节假日」，不再渲染「 年法定节假日」这种半个模板。
 *
 * 损坏态优先于加载态：那是「读到了但解不开」，与「还没读」是两件事。
 */
class SettingsHolidayLoadingStateTest {

    private val today = LocalDate.of(2026, 10, 1)

    private fun data(
        loading: Boolean,
        official: HolidayData? = null,
        corrupted: Boolean = false,
        custom: List<HolidayEntry> = emptyList(),
    ): HolidayPageData = SettingsHolidayPage.buildPageData(
        enableHolidayMarking = true,
        official = official,
        customHolidays = custom,
        customCorrupted = corrupted,
        today = today,
        loading = loading,
    )

    private fun page(data: HolidayPageData) = SettingsHolidayPage.spec(SettingsPageState(), data)

    private fun official(): HolidayData = HolidayData(
        year = 2026,
        version = 1,
        entries = listOf(
            HolidayEntry(
                date = LocalDateTime.of(2026, 10, 1, 0, 0),
                name = "国庆节",
                type = HolidayType.Vacation,
                groupId = "national-day-2026",
            ),
        ),
    )

    @Test
    fun `加载中显示加载行 而不是近期没有节假日`() {
        val spec = page(data(loading = true))

        val row = spec.row("holiday.loading")
        assertEquals("holidayDataLoading", row.titleKey)
        assertEquals("正在加载节假日数据…", row.title)
        assertTrue("加载行不可点（纯提示）", !row.enabled)

        assertNull(
            "加载中不许出现「近期没有节假日」的假空态",
            spec.rows().firstOrNull { it.id == "holiday.officialEmpty" },
        )
        assertNull(
            "加载中也不许出现「暂无自定义假期」",
            spec.rows().firstOrNull { it.id == "holiday.customEmpty" },
        )
    }

    @Test
    fun `加载中区块标题退回不带年份的法定节假日`() {
        val label = page(data(loading = true))
            .flatten()
            .filterIsInstance<SettingsLabel>()
            .first { it.id == "holiday.section.official" }
        assertEquals("holidayStatutoryLabel", label.textKey)
        assertEquals("法定节假日", label.text)
    }

    @Test
    fun `加载结束后没有数据才显示空态`() {
        val spec = page(data(loading = false))

        assertNull(
            "加载结束才有资格说「没有」",
            spec.rows().firstOrNull { it.id == "holiday.loading" },
        )
        assertEquals(
            "holidayNoUpcoming",
            spec.row("holiday.officialEmpty").titleKey,
        )
        assertEquals("customHolidayEmpty", spec.row("holiday.customEmpty").titleKey)
    }

    @Test
    fun `有数据的年份仍用带年份的小标题`() {
        val spec = page(data(loading = false, official = official()))
        val label = spec.flatten()
            .filterIsInstance<SettingsLabel>()
            .first { it.id == "holiday.section.official" }
        assertEquals("holidayDataYearLabel", label.textKey)
        assertEquals("2026 年法定节假日", label.text)
        assertNull(
            "有数据就不该有加载行",
            spec.rows().firstOrNull { it.id == "holiday.loading" },
        )
    }

    @Test
    fun `加载中但数据已到 仍显示真数据而不是加载行`() {
        // 防御：加载标记只顶替空态。真拿到了年份与条目就先显示，别拿加载行盖住真数据。
        val spec = page(data(loading = true, official = official()))
        assertNull(
            "有条目时不该再出加载行",
            spec.rows().firstOrNull { it.id == "holiday.loading" },
        )
        assertEquals("国庆节", spec.row("holiday.official.0").title)
        val label = spec.flatten()
            .filterIsInstance<SettingsLabel>()
            .first { it.id == "holiday.section.official" }
        assertEquals("holidayDataYearLabel", label.textKey)
        assertEquals("2026 年法定节假日", label.text)
    }

    @Test
    fun `损坏态优先于加载态`() {        val spec = page(data(loading = true, corrupted = true))
        assertEquals(
            "customHolidayCorrupted 是「读到了但解不开」，比「还没读」优先",
            "customHolidayCorrupted",
            spec.row("holiday.customCorrupted").titleKey,
        )
        assertNull(spec.rows().firstOrNull { it.id == "holiday.customEmpty" })
    }
}
