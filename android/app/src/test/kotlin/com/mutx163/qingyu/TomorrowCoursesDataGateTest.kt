package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 桌面卡片「明天课程」这份数据的**计算**门禁（2026-10-06 审查）。
 *
 * 它和展示门禁 `isShowingTomorrowCourses` 是两条规则，必须分开：
 * 展示门禁决定"卡片整体切到明天"（只在今天已上完 / 今天没课时成立），
 * 计算门禁只决定"快照里要不要带上明天的课程列表"。
 *
 * 原先两者是同一条：`TodayWidgetSupport.kt:423` 只在 `completed`/`no_course`
 * 时才算明天课程，于是 `TodayStripWidgetProvider.kt:227-230` 那条
 * "今天还在上课 → 第三行放明日首课预告"的分支永远读到空列表，
 * 高长条卡（≥150dp）上那行写着注释里承诺的内容却永远是空白 ——
 * 注释（:224-226）与实现（:423）对同一条规则各写了一份、值不一样。
 *
 * 展示侧不动，因此放开计算门禁只会让那一行有内容，
 * 不会让任何卡片在上课中途把主行切成明天的课程。
 */
class TomorrowCoursesDataGateTest {
    @Test
    fun buildsTomorrowDataAfterTodayCoursesEnd() {
        // 既有行为：今天上完了 / 今天本来就没课。
        assertTrue(
            TodayWidgetSupport.shouldBuildTomorrowCourses(
                state = "completed",
                isHoliday = false,
                settingEnabled = true,
            ),
        )
        assertTrue(
            TodayWidgetSupport.shouldBuildTomorrowCourses(
                state = "no_course",
                isHoliday = false,
                settingEnabled = true,
            ),
        )
    }

    @Test
    fun buildsTomorrowDataWhileTodayIsStillRunning() {
        // 修复点：长条高卡在"进行中/还有下节"时也要展示明日首课预告，
        // 数据侧却按老门禁留空 → 那一行永远不出现。
        assertTrue(
            TodayWidgetSupport.shouldBuildTomorrowCourses(
                state = "ongoing",
                isHoliday = false,
                settingEnabled = true,
            ),
        )
        assertTrue(
            TodayWidgetSupport.shouldBuildTomorrowCourses(
                state = "upcoming",
                isHoliday = false,
                settingEnabled = true,
            ),
        )
    }

    @Test
    fun skipsHolidayStates() {
        // 假期整张卡走节假日口径，明天的课程不该顶上来。
        assertFalse(
            TodayWidgetSupport.shouldBuildTomorrowCourses(
                state = "holiday",
                isHoliday = false,
                settingEnabled = true,
            ),
        )
        assertFalse(
            TodayWidgetSupport.shouldBuildTomorrowCourses(
                state = "completed",
                isHoliday = true,
                settingEnabled = true,
            ),
        )
    }

    @Test
    fun obeysUserSetting() {
        assertFalse(
            TodayWidgetSupport.shouldBuildTomorrowCourses(
                state = "completed",
                isHoliday = false,
                settingEnabled = false,
            ),
        )
    }
}
