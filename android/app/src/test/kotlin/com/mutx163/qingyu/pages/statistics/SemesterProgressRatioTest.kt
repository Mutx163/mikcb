package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.statistics.SemesterProgress
import com.mutx163.qingyu.statistics.SemesterProgressPhase
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 学期进度比例的唯一钳位入口（[semesterProgressRatio]）。
 *
 * 口径：**有意偏离 Dart**，统一钳到 0..1（Dart 会印出 156%）。
 * `SemesterProgressModel` 与 `CourseStatisticsModel` 两处都调这里，
 * 本测试钉住钳位行为，防止第三次偏移。
 */
class SemesterProgressRatioTest {

    private fun progress(
        start: LocalDate? = LocalDate.of(2026, 9, 1),
        done: Int,
        total: Int,
    ) = SemesterProgress(
        semesterStartDate = start,
        currentDate = if (start != null) LocalDate.of(2027, 1, 5) else null,
        semesterEndDate = if (start != null) LocalDate.of(2027, 1, 10) else null,
        weeksElapsed = 19,
        totalWeeks = 20,
        sectionsDone = done,
        sectionsTotal = total,
        remainingSections = 0,
        phase = if (start != null) SemesterProgressPhase.IN_PROGRESS else SemesterProgressPhase.ESTIMATED,
    )

    @Test
    fun `已上节数超过计划时钳到一`() {
        // 换课/加课导致 156/100 = 156%：钳到 100%，不出现 156%
        assertEquals(1.0, semesterProgressRatio(progress(done = 156, total = 100)), 1e-9)
    }

    @Test
    fun `负数比例钳到零`() {
        // 坏数据（已上节数为负）不能画成负进度
        assertEquals(0.0, semesterProgressRatio(progress(done = -10, total = 100)), 1e-9)
    }

    @Test
    fun `正常值原样保留`() {
        assertEquals(0.5, semesterProgressRatio(progress(done = 96, total = 192)), 1e-9)
        assertEquals(1.0 / 3.0, semesterProgressRatio(progress(done = 1, total = 3)), 1e-9)
        assertEquals(0.0, semesterProgressRatio(progress(done = 0, total = 192)), 1e-9)
    }

    @Test
    fun `空数据与无开学日无课时时为零`() {
        // 无统计数据：null 直接给 0
        assertEquals(0.0, semesterProgressRatio(null), 1e-9)
        // 无开学日、也没有课表 → 总课时 0，算不出进度（也避免除零）
        assertEquals(0.0, semesterProgressRatio(progress(start = null, done = 0, total = 0)), 1e-9)
    }

    @Test
    fun `无开学日但按周估算有课时时仍按节数比例`() {
        // Dart models:272 的 percent 是节数口径，与开学日无关：
        // 40/200 在「按周估算」下仍显示 20%，这里保持不变（只有越界才钳）。
        assertEquals(0.2, semesterProgressRatio(progress(start = null, done = 40, total = 200)), 1e-9)
    }
}
