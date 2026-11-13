package com.mutx163.qingyu.widgetdata

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * [WeekendMoodLogic] 的纯逻辑单测（零 Android 依赖，可 L0 直跑）。
 *
 * ## 为什么单独建这个文件
 *
 * 卡片有**两份**同口径判据（KDoc 在两边都写了「逐条同口径」）：
 * 1. [WeekendMoodLogic.resolve]（`widgetdata/`，快照组装用）；
 * 2. `widgetResolveWeekendMood`（`WidgetHolidayLogic.kt`，App 被杀后卡片自算用）。
 * 后者所在文件带 `android.jar` / `R.*` 依赖，**L0 编译不了**，所以它的用例只能在 L2 跑。
 * 本文件专门钉前者：让「周五不得在周末满课时宣布周末」这条判据有一条
 * **能 L0 直跑、能咬合探针**的证据链，而不是全部押在 L2。
 *
 * 两份实现的用例必须同时存在——它们哪天分叉，就会出现「重启后文案变了」。
 */
class WeekendMoodLogicTest {

    @Test
    fun `周五-周末排了课就不宣布周末`() {
        // 用户实报（2026-11）：周末满课（周六周日都有课），周五仍弹「周末要开始了」。
        // 旧判据只有「今天有没有课上完 + 明天补不补班」，永远看不到周末的课表。
        assertEquals(
            WeekendMoodData.NONE,
            WeekendMoodLogic.resolve(
                dayOfWeek = 5,
                hasAnyCourseToday = false,
                hasRemainingCourseToday = false,
                hasCourseOnWeekend = true,
                isHolidayToday = false,
                isAdjustedWorkdayToday = false,
                isAdjustedWorkdayTomorrow = false,
            ),
        )
    }

    @Test
    fun `周五-周末没课仍然显示即将周末`() {
        // 反向：不能把判据改成一刀切（否则「周末要开始了」这条文案永远不出现）。
        assertEquals(
            WeekendMoodData.AHEAD,
            WeekendMoodLogic.resolve(
                dayOfWeek = 5,
                hasAnyCourseToday = false,
                hasRemainingCourseToday = false,
                hasCourseOnWeekend = false,
                isHolidayToday = false,
                isAdjustedWorkdayToday = false,
                isAdjustedWorkdayTomorrow = false,
            ),
        )
    }

    @Test
    fun `周末当天的既有口径不受新入参影响`() {
        assertEquals(
            WeekendMoodData.REST,
            WeekendMoodLogic.resolve(
                dayOfWeek = 6,
                hasAnyCourseToday = false,
                hasRemainingCourseToday = false,
                hasCourseOnWeekend = true,
                isHolidayToday = false,
                isAdjustedWorkdayToday = false,
                isAdjustedWorkdayTomorrow = false,
            ),
        )
        assertEquals(
            WeekendMoodData.NONE,
            WeekendMoodLogic.resolve(
                dayOfWeek = 6,
                hasAnyCourseToday = true,
                hasRemainingCourseToday = false,
                hasCourseOnWeekend = false,
                isHolidayToday = false,
                isAdjustedWorkdayToday = false,
                isAdjustedWorkdayTomorrow = false,
            ),
        )
    }
}
