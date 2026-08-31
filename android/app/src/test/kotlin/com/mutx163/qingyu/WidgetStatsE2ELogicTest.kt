package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * buildSnapshot 全链路用例（数据与被移除的 JSON 版本一致），
 * 走纯函数重载，不触碰 org.json——android.jar 里 org.json.* 是 stub，
 * JVM 单测一碰就抛 RuntimeException("Stub!")（见 WidgetHolidayLogicTest 的注释）。
 */
class WidgetStatsE2ELogicTest {

    private fun course(
        name: String,
        dayOfWeek: Int,
        startSection: Int,
        endSection: Int,
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        suspendedWeeks: List<Int>? = null,
        courseNature: String = "required",
    ) = WidgetSourceCourse(
        id = name,
        name = name,
        shortName = null,
        location = "",
        startTime = "08:00",
        endTime = "09:40",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = null,
        suspendedWeeks = suspendedWeeks,
        courseNature = courseNature,
    )

    @Test
    fun buildSnapshotWithoutSemesterStart() {
        val courses = listOf(
            course("数学", dayOfWeek = 1, startSection = 1, endSection = 2),
            course(
                "英语",
                dayOfWeek = 3,
                startSection = 3,
                endSection = 4,
                endWeek = 8,
                isEvenWeek = true,
                suspendedWeeks = listOf(6),
                courseNature = "elective",
            ),
            course("体育", dayOfWeek = 5, startSection = 5, endSection = 6, startWeek = 2, endWeek = 4, courseNature = "elective"),
        )
        val snap = WidgetStatsLogic.buildSnapshot(
            courses = courses,
            profileName = "测试课表",
            persistedWeek = 3,
            semesterWeekCount = 16,
            semesterStartMillis = null,
            nowMillis = 1000L,
        )!!
        assertEquals("测试课表", snap.profileName)
        assertEquals(3, snap.currentWeek)
        // 第 3 周：数学 2 节 + 体育 2 节（英语双周不上）→ 4 节 2 门
        assertEquals(4, snap.weekSections)
        assertEquals(2, snap.weekCourseCount)
        // 上周（第 2 周）：数学 2 + 英语 2（双周）+ 体育 2 = 6 → delta = -2
        assertEquals(-2, snap.deltaVsLastWeek)
        // 学期总课时：数学 32 + 英语（双周 4 周停课 1 → 3 周）× 2 = 6 + 体育 6 → 44
        assertEquals(44, snap.semesterTotal)
        // 无开学日期：整周估算 done = 数学 3×2 + 英语（1..3 双周仅第 2 周）1×2 + 体育 2×2 = 12
        assertEquals(12, snap.semesterDone)
        assertEquals(1, snap.requiredCount)
        assertEquals(2, snap.electiveCount)
        // 每周覆盖周一/周三/周五 → 最长连续 1 天
        assertEquals(1, snap.longestStreak)
    }

    @Test
    fun buildSnapshotBeforeSemesterStartShortCircuits() {
        // 开学日期在未来：labelWeek 夹到 1，semesterDone 入口短路为 0（评审要求补的链路）。
        val farFuture = System.currentTimeMillis() + 30L * 86_400_000L
        val snap = WidgetStatsLogic.buildSnapshot(
            courses = listOf(course("数学", dayOfWeek = 1, startSection = 1, endSection = 2)),
            profileName = "未来课表",
            persistedWeek = 1,
            semesterWeekCount = 16,
            semesterStartMillis = farFuture,
            nowMillis = System.currentTimeMillis(),
        )!!
        assertEquals(1, snap.currentWeek)
        assertEquals(0, snap.semesterDone)
        assertEquals(32, snap.semesterTotal)
    }

    @Test
    fun buildSnapshotWithSemesterMidTermMondayStart() {
        // 开学 = 第 1 周周一；今天 = 第 3 周周二（day 15 当天零点起）。
        // 周一课 2 节 + 周三课 2 节：完整周 1-2 共 8 节，第 3 周周一已上 2 节 → 10。
        val mondayStart = WidgetStatsLogic.dayStartOf(System.currentTimeMillis())
        val today = mondayStart + 15L * 86_400_000L
        val snap = WidgetStatsLogic.buildSnapshot(
            courses = listOf(
                course("数学", dayOfWeek = 1, startSection = 1, endSection = 2),
                course("英语", dayOfWeek = 3, startSection = 1, endSection = 2),
            ),
            profileName = "校历课表",
            persistedWeek = 3,
            semesterWeekCount = 16,
            semesterStartMillis = mondayStart,
            nowMillis = today,
        )!!
        assertEquals(3, snap.currentWeek)
        assertEquals(10, snap.semesterDone)
        assertEquals(64, snap.semesterTotal)
    }
}
