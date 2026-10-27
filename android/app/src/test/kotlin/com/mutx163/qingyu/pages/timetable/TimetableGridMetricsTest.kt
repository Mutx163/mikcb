package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课表网格几何尺寸、时间轴配置与坐标映射单测。
 */
class TimetableGridMetricsTest {

    private val defaultConfig = TimetableGridConfig(
        totalSections = 12,
        sectionHeightDp = 64f,
        timeColumnWidthDp = 32f,
        headerHeightDp = 48f,
        visibleDaysCount = 7,
        cardHorizontalInsetDp = 2f,
        cardVerticalInsetDp = 2f,
    )

    @Test
    fun `默认 12 节次时间槽有效且时间格式正确`() {
        val slots = TimetableGridMetrics.defaultSectionTimeSlots(12)
        assertEquals(12, slots.size)

        for (i in slots.indices) {
            val slot = slots[i]
            assertEquals(i + 1, slot.section)
            assertTrue(slot.startTime.matches(Regex("""\d{2}:\d{2}""")))
            assertTrue(slot.endTime.matches(Regex("""\d{2}:\d{2}""")))
            assertTrue(slot.startTime < slot.endTime)
            assertEquals("${slot.startTime} - ${slot.endTime}", slot.formattedRange)
        }
    }

    @Test
    fun `calculateTotalHeight 与 calculateDayColumnWidth 计算正确`() {
        // totalHeight = 48 + 12 * 64 = 48 + 768 = 816
        assertEquals(816f, TimetableGridMetrics.calculateTotalHeight(defaultConfig), 0.001f)

        // 屏幕宽度 382dp，时间列 32dp，剩余 350dp，7 天单列宽 50dp
        val dayWidth = TimetableGridMetrics.calculateDayColumnWidth(382f, defaultConfig)
        assertEquals(50f, dayWidth, 0.001f)
    }

    @Test
    fun `calculateSectionTop 与 calculateSectionHeight 计算正确`() {
        // 第 1 节顶部偏移 0
        assertEquals(0f, TimetableGridMetrics.calculateSectionTop(1, defaultConfig), 0.001f)
        // 第 3 节顶部偏移 (3-1)*64 = 128
        assertEquals(128f, TimetableGridMetrics.calculateSectionTop(3, defaultConfig), 0.001f)

        // 第 1 节到第 2 节跨 2 节 = 128dp
        assertEquals(128f, TimetableGridMetrics.calculateSectionHeight(1, 2, defaultConfig), 0.001f)
        // 单节课 = 64dp
        assertEquals(64f, TimetableGridMetrics.calculateSectionHeight(4, 4, defaultConfig), 0.001f)
    }

    @Test
    fun `卡片分列宽度与 X 轴偏移计算（单列 vs 双列分切）`() {
        val dayWidth = 50f
        // 内边距 2dp，可用宽度 50 - 4 = 46dp

        // 1. 无重叠，单列
        val singleWidth = TimetableGridMetrics.calculateCardWidth(1, dayWidth, defaultConfig)
        val singleX = TimetableGridMetrics.calculateCardX(0, 1, dayWidth, defaultConfig)
        assertEquals(46f, singleWidth, 0.001f)
        assertEquals(2f, singleX, 0.001f)

        // 2. 双列分切
        val doubleWidth = TimetableGridMetrics.calculateCardWidth(2, dayWidth, defaultConfig)
        val col0X = TimetableGridMetrics.calculateCardX(0, 2, dayWidth, defaultConfig)
        val col1X = TimetableGridMetrics.calculateCardX(1, 2, dayWidth, defaultConfig)

        assertEquals(23f, doubleWidth, 0.001f)
        assertEquals(2f, col0X, 0.001f)
        assertEquals(25f, col1X, 0.001f) // 2 + 23 = 25
    }

    @Test
    fun `卡片顶部与高度扣除内边距`() {
        // 第 1 节到第 2 节：SectionTop = 0, CardTop = 2
        assertEquals(2f, TimetableGridMetrics.calculateCardTop(1, defaultConfig), 0.001f)
        // SectionHeight = 128, CardHeight = 128 - 4 = 124
        assertEquals(124f, TimetableGridMetrics.calculateCardHeight(1, 2, defaultConfig), 0.001f)
    }

    @Test
    fun `sectionAtOffset 准确反解手势 Y 坐标到节次`() {
        // 0dp -> 第 1 节
        assertEquals(1, TimetableGridMetrics.sectionAtOffset(0f, defaultConfig))
        // 63dp -> 第 1 节
        assertEquals(1, TimetableGridMetrics.sectionAtOffset(63f, defaultConfig))
        // 64dp -> 第 2 节
        assertEquals(2, TimetableGridMetrics.sectionAtOffset(64f, defaultConfig))
        // 700dp -> 700/64 = 10.93 -> 第 11 节
        assertEquals(11, TimetableGridMetrics.sectionAtOffset(700f, defaultConfig))
        // 超过最大节次钳制到 12
        assertEquals(12, TimetableGridMetrics.sectionAtOffset(9999f, defaultConfig))
    }

    @Test
    fun `dayOfWeekAtOffset 准确反解手势 X 坐标到星期几`() {
        val screenWidth = 382f // dayWidth = 50f
        // 落在时间轴区域（< 32dp）应返回 -1
        assertEquals(-1, TimetableGridMetrics.dayOfWeekAtOffset(15f, screenWidth, defaultConfig))

        // 32dp ~ 81dp 为周一 (day 1)
        assertEquals(1, TimetableGridMetrics.dayOfWeekAtOffset(32f, screenWidth, defaultConfig))
        assertEquals(1, TimetableGridMetrics.dayOfWeekAtOffset(81f, screenWidth, defaultConfig))

        // 82dp 为周二 (day 2)
        assertEquals(2, TimetableGridMetrics.dayOfWeekAtOffset(82f, screenWidth, defaultConfig))

        // 落在屏幕右侧边界为周日 (day 7)
        assertEquals(7, TimetableGridMetrics.dayOfWeekAtOffset(380f, screenWidth, defaultConfig))
    }
}
