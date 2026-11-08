package com.mutx163.qingyu.pages.timetable.day

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 星期栏跨周滑动的几何口径（对齐 Dart `timetable_weekday_header.dart:400-463`）。
 *
 * 这里固定的是「页号小数 → 哪一行在滑、滑多少、选中条在哪一格」这条换算；
 * 像素表现由真机看（本项目纪律：JVM 单测通过不等于界面对）。
 */
class WeekdayHeaderSlideTest {

    @Test
    fun `静止在周内某天时不跨周且选中格位是整数`() {
        // 第 2 周周三：page = 7 + 2 = 9（7 天可见）。
        val slide = WeekdayHeaderSlideResolver.resolve(
            pagePosition = 9f,
            visibleDayCount = 7,
            totalWeeks = 20,
        )
        assertFalse("静止页不应判成跨周", slide.crossing)
        assertEquals(0f, slide.progress, 0f)
        assertEquals(2, slide.outgoingWeek)
        assertEquals(2f, slide.outgoingSelection, 0f)
    }

    @Test
    fun `周内拖动只移动选中条不整体平移`() {
        // 第 1 周周三→周四之间：整条栏不动，只有选中条在小数格位上。
        val slide = WeekdayHeaderSlideResolver.resolve(
            pagePosition = 2.4f,
            visibleDayCount = 7,
            totalWeeks = 20,
        )
        assertFalse(slide.crossing)
        assertEquals(1, slide.outgoingWeek)
        assertEquals(2.4f, slide.outgoingSelection, 1e-5f)
    }

    @Test
    fun `周日滑向次周周一时整条跟手平移`() {
        // 7 天可见：第 1 周周日 = page 6；page 6.25 表示已向下一周走了 1/4。
        val quarter = WeekdayHeaderSlideResolver.resolve(6.25f, 7, 20)
        assertTrue(quarter.crossing)
        assertEquals(0.25f, quarter.progress, 1e-5f)
        assertEquals(1, quarter.outgoingWeek)
        assertEquals(2, quarter.incomingWeek)
        assertEquals(6f, quarter.outgoingSelection, 0f)
        assertEquals(0f, quarter.incomingSelection, 0f)
        assertTrue("未过半时选中条留在滑出行", quarter.showSelectionOnOutgoing)

        // 过半后选中条交接到滑入行（Dart `extrasOnOutgoing = progress < 0.5`）。
        val past = WeekdayHeaderSlideResolver.resolve(6.5f, 7, 20)
        assertFalse(past.showSelectionOnOutgoing)
    }

    @Test
    fun `跨过整页后回到不跨周的新一周`() {
        // 7.0 = 第 2 周周一：上一步滑入的整行正好落到原位，接缝无跳变。
        val slide = WeekdayHeaderSlideResolver.resolve(7f, 7, 20)
        assertFalse(slide.crossing)
        assertEquals(1, slide.weekIndex)
        assertEquals(2, slide.outgoingWeek)
        assertEquals(0f, slide.outgoingSelection, 0f)
    }

    @Test
    fun `隐藏周末时按 5 天口径跨周`() {
        // 第 1 周周五 = page 4；4.3 正在滑向第 2 周周一。
        val slide = WeekdayHeaderSlideResolver.resolve(4.3f, 5, 20)
        assertTrue(slide.crossing)
        assertEquals(0.3f, slide.progress, 1e-5f)
        assertEquals(1, slide.outgoingWeek)
        assertEquals(2, slide.incomingWeek)
        assertEquals(4f, slide.outgoingSelection, 0f)
    }

    @Test
    fun `页号夹在学期内且负数与NaN回落到第一周`() {
        val clamped = WeekdayHeaderSlideResolver.resolve(999f, 7, 20)
        assertEquals(19, clamped.weekIndex)
        assertEquals(20, clamped.outgoingWeek)

        for (bad in listOf(-3f, Float.NaN, Float.POSITIVE_INFINITY)) {
            val slide = WeekdayHeaderSlideResolver.resolve(bad, 7, 20)
            assertEquals("输入 $bad 应回落到第 1 周", 0, slide.weekIndex)
            assertEquals(1, slide.outgoingWeek)
        }
    }

    @Test
    fun `与全局页号换算严格互逆`() {
        for (visibleDays in listOf(listOf(1, 2, 3, 4, 5), (1..7).toList())) {
            for (week in 1..20) {
                for (dayOfWeek in visibleDays) {
                    val page = DayViewPaging.globalPage(visibleDays, week, dayOfWeek)
                    val slide = WeekdayHeaderSlideResolver.resolve(
                        pagePosition = page.toFloat(),
                        visibleDayCount = visibleDays.size,
                        totalWeeks = 20,
                    )
                    assertFalse("页 $page 静止时不该跨周", slide.crossing)
                    assertEquals(week, slide.outgoingWeek)
                    assertEquals(
                        visibleDays.indexOf(dayOfWeek).toFloat(),
                        slide.outgoingSelection,
                        0f,
                    )
                }
            }
        }
    }
}
