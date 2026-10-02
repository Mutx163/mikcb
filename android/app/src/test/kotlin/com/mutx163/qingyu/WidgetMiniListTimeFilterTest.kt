package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 迷你列表卡"还剩几节"的时间过滤（2026-10-02 审查）。
 *
 * 旧实现：`SimpleDateFormat("HH:mm", Locale.getDefault())` 出一个字符串，
 * 再 `c.endTime > nowTime` 按字典序比（TodayMiniListWidgetProvider.kt:99-106）。
 * 两处都会错：默认 Locale 用阿拉伯-印度数字时比较双方根本不是同一套字符；
 * 教务适配器下发的钟点没补零时（`8:00`）`'8' > '1'` 让已结束的课继续占位。
 */
class WidgetMiniListTimeFilterTest {
    @Test
    fun keepsOnlyCoursesThatHaveNotFinished() {
        assertTrue(TodayWidgetSupport.miniListShouldListCourse("10:30", 600))
        // 结束时刻等于现在：这节课已经上完。
        assertFalse(TodayWidgetSupport.miniListShouldListCourse("10:30", 630))
        assertFalse(TodayWidgetSupport.miniListShouldListCourse("10:30", 631))
        assertTrue(TodayWidgetSupport.miniListShouldListCourse("23:59", 0))
        assertFalse(TodayWidgetSupport.miniListShouldListCourse("00:00", 0))
    }

    @Test
    fun unpaddedClockIsComparedAsTimeNotText() {
        // 09:00 时 `"8:00" > "09:00"` 在字典序里为真 → 已结束的课被列出来。
        assertFalse(TodayWidgetSupport.miniListShouldListCourse("8:00", 540))
        assertTrue(TodayWidgetSupport.miniListShouldListCourse("8:00", 420))
    }

    @Test
    fun endOfDayMarkerIsHandled() {
        // 晚自习写成 24:00 = 次日零点，一定晚于当天任何时刻。
        assertTrue(TodayWidgetSupport.miniListShouldListCourse("24:00", 1380))
    }

    @Test
    fun keepsRowWhenClockIsUnparseable() {
        // 解析不了就保留这一行：宁可多列，也不把用户课表里的课吞掉。
        assertTrue(TodayWidgetSupport.miniListShouldListCourse("上午8点", 540))
        assertTrue(TodayWidgetSupport.miniListShouldListCourse("", 540))
        assertTrue(TodayWidgetSupport.miniListShouldListCourse(null, 540))
        assertTrue(TodayWidgetSupport.miniListShouldListCourse("25:00", 540))
    }

    @Test
    fun defaultLocaleFormatterIsNotComparableWithStoredAsciiTimes() {
        // 旧实现失真的根因：快照里存的 endTime 是 ASCII，
        // 而按默认 Locale 格式化出的 nowTime 在 ar 等 Locale 下是阿拉伯-印度数字。
        val localized = SimpleDateFormat("HH:mm", Locale("ar")).format(Date())
        assertTrue(
            "期望非 ASCII 数字，实得: $localized",
            localized.any { it.code > 127 },
        )
    }
}
