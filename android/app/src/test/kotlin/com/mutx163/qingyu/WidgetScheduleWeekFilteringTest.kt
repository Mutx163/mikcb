package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 桌面卡刷新排程用的周次（2026-10-02 审查）。
 *
 * `findNextRefreshAtMillis` 原先调私有的 `calculateWeekForDate`，
 * 那个函数是给卡片**显示**用的：它把周次钳进 `1..semesterWeekCount`，
 * 还把"开学日之前"强行算成第 1 周。快照侧 :285-288 的注释早就写明了
 * 筛课不能用钳过的周（"Clamping to the last teaching week after the term ends
 * would revive endWeek=N courses on every matching weekday forever"），
 * 但排程那侧没跟上：学期结束后，每个与最后一周课表星期相符的日子
 * 都照样按那天的铃点排精确闹钟与倒计时刷新 —— 卡片写着"无课"，闹钟天天排。
 */
class WidgetScheduleWeekFilteringTest {
    @Test
    fun returnsCalendarWeekInsideTerm() {
        assertEquals(
            8,
            TodayWidgetSupport.widgetScheduleWeekForFiltering(
                semesterStartMillis = 1_750_000_000_000L,
                fallbackWeek = 1,
                semesterWeekCount = 20,
                scheduleWeek = 8,
            ),
        )
    }

    @Test
    fun refusesToClampAfterTermEnds() {
        // 旧实现在这里返回 20 → 放假期间天天按最后一周排闹钟。
        assertNull(
            TodayWidgetSupport.widgetScheduleWeekForFiltering(
                semesterStartMillis = 1_750_000_000_000L,
                fallbackWeek = 20,
                semesterWeekCount = 20,
                scheduleWeek = 21,
            ),
        )
    }

    @Test
    fun refusesToReviveWeekOneBeforeSemesterStarts() {
        // 旧实现把开学日之前钳成第 1 周 → 开学前那些星期相符的日子照样排闹钟。
        assertNull(
            TodayWidgetSupport.widgetScheduleWeekForFiltering(
                semesterStartMillis = 1_750_000_000_000L,
                fallbackWeek = 1,
                semesterWeekCount = 20,
                scheduleWeek = 0,
            ),
        )
    }

    @Test
    fun usesStoredWeekOnlyWhenSemesterStartIsUnknown() {
        assertEquals(
            5,
            TodayWidgetSupport.widgetScheduleWeekForFiltering(
                semesterStartMillis = null,
                fallbackWeek = 5,
                semesterWeekCount = 20,
                scheduleWeek = 0,
            ),
        )
        // 档内 currentWeek 被写歪时退回教学周范围内，保持原语义。
        assertEquals(
            20,
            TodayWidgetSupport.widgetScheduleWeekForFiltering(
                semesterStartMillis = null,
                fallbackWeek = 99,
                semesterWeekCount = 20,
                scheduleWeek = 99,
            ),
        )
    }

    @Test
    fun degenerateSemesterYieldsNoSchedule() {
        assertNull(
            TodayWidgetSupport.widgetScheduleWeekForFiltering(
                semesterStartMillis = 1_750_000_000_000L,
                fallbackWeek = 1,
                semesterWeekCount = 0,
                scheduleWeek = 1,
            ),
        )
    }
}
