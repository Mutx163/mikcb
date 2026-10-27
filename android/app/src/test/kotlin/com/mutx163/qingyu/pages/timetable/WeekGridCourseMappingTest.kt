package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课表周网格课程布局、周次过滤与同天重叠分列计算单测。
 */
class WeekGridCourseMappingTest {

    @Test
    fun `TimetableCourse 的激活与停课状态判定按预期工作`() {
        val course = TimetableCourse(
            id = "c1",
            name = "计算机网络",
            dayOfWeek = 1,
            startSection = 1,
            endSection = 2,
            weeks = listOf(1, 2, 3, 4, 5),
            suspendedWeeks = listOf(3),
        )

        assertTrue(course.isActiveInWeek(1))
        assertTrue(course.isActiveInWeek(2))
        assertFalse("第 3 周停课应返回 false", course.isActiveInWeek(3))
        assertTrue(course.isActiveInWeek(4))
        assertFalse("第 6 周不在上课周次中", course.isActiveInWeek(6))

        val suspendedCourse = course.copy(isSuspended = true)
        assertFalse("全局停课后任何周次均不激活", suspendedCourse.isActiveInWeek(1))
    }

    @Test
    fun `isSectionOverlapping 准确判定节次是否有交集`() {
        val c1 = TimetableCourse(id = "1", name = "A", dayOfWeek = 1, startSection = 1, endSection = 2)
        val c2 = TimetableCourse(id = "2", name = "B", dayOfWeek = 1, startSection = 2, endSection = 3)
        val c3 = TimetableCourse(id = "3", name = "C", dayOfWeek = 1, startSection = 3, endSection = 4)
        val c4 = TimetableCourse(id = "4", name = "D", dayOfWeek = 1, startSection = 4, endSection = 5)

        // c1 (1-2) 与 c2 (2-3) 在第 2 节重叠
        assertTrue(WeekGridCourseMapping.isSectionOverlapping(c1, c2))
        // c1 (1-2) 与 c3 (3-4) 无重叠
        assertFalse(WeekGridCourseMapping.isSectionOverlapping(c1, c3))
        // c2 (2-3) 与 c3 (3-4) 在第 3 节重叠
        assertTrue(WeekGridCourseMapping.isSectionOverlapping(c2, c3))
        // c1 (1-2) 与 c4 (4-5) 无重叠
        assertFalse(WeekGridCourseMapping.isSectionOverlapping(c1, c4))
    }

    @Test
    fun `同天无重叠课程各自分配独立列轨道且冲突标记为假`() {
        val courses = listOf(
            TimetableCourse(
                id = "c1",
                name = "高等数学",
                dayOfWeek = 1,
                startSection = 1,
                endSection = 2,
                weeks = listOf(1, 2, 3),
            ),
            TimetableCourse(
                id = "c2",
                name = "大学英语",
                dayOfWeek = 1,
                startSection = 3,
                endSection = 4,
                weeks = listOf(1, 2, 3),
            ),
        )

        val result = WeekGridCourseMapping.filterAndPlaceCoursesForWeek(courses, week = 1)
        val mondayCourses = result[1] ?: error("周一应有课程")
        assertEquals(2, mondayCourses.size)

        val card1 = mondayCourses.first { it.course.id == "c1" }
        assertEquals(0, card1.colIndex)
        assertEquals(1, card1.totalCols)
        assertFalse(card1.isConflicting)
        assertTrue(card1.isCurrentWeek)
        assertEquals(1.0f, card1.opacity, 0.001f)

        val card2 = mondayCourses.first { it.course.id == "c2" }
        assertEquals(0, card2.colIndex)
        assertEquals(1, card2.totalCols)
        assertFalse(card2.isConflicting)
        assertTrue(card2.isCurrentWeek)
    }

    @Test
    fun `两门课完全重叠时各自分配不同 colIndex 且 totalCols 为 2 并标记冲突`() {
        val courses = listOf(
            TimetableCourse(
                id = "c1",
                name = "操作系统",
                dayOfWeek = 2,
                startSection = 1,
                endSection = 2,
                weeks = listOf(1),
            ),
            TimetableCourse(
                id = "c2",
                name = "编译原理",
                dayOfWeek = 2,
                startSection = 1,
                endSection = 2,
                weeks = listOf(1),
            ),
        )

        val result = WeekGridCourseMapping.filterAndPlaceCoursesForWeek(courses, week = 1)
        val tuesdayCourses = result[2] ?: error("周二应有课程")
        assertEquals(2, tuesdayCourses.size)

        val card1 = tuesdayCourses.first { it.course.id == "c1" }
        val card2 = tuesdayCourses.first { it.course.id == "c2" }

        assertEquals(2, card1.totalCols)
        assertEquals(2, card2.totalCols)
        assertTrue(card1.isConflicting)
        assertTrue(card2.isConflicting)

        // colIndex 应为 0 和 1（互不相同）
        val indices = setOf(card1.colIndex, card2.colIndex)
        assertEquals(setOf(0, 1), indices)

        // 冲突课程透明度应应用
        assertEquals(WeekGridCourseMapping.CONFLICT_COURSE_OPACITY, card1.opacity, 0.001f)
    }

    @Test
    fun `三门课在同一时段完全重叠时分配 3 列`() {
        val courses = listOf(
            TimetableCourse(id = "c1", name = "A", dayOfWeek = 3, startSection = 5, endSection = 6, weeks = listOf(2)),
            TimetableCourse(id = "c2", name = "B", dayOfWeek = 3, startSection = 5, endSection = 6, weeks = listOf(2)),
            TimetableCourse(id = "c3", name = "C", dayOfWeek = 3, startSection = 5, endSection = 6, weeks = listOf(2)),
        )

        val result = WeekGridCourseMapping.filterAndPlaceCoursesForWeek(courses, week = 2)
        val wedCourses = result[3] ?: error("周三应有课程")
        assertEquals(3, wedCourses.size)

        for (card in wedCourses) {
            assertEquals(3, card.totalCols)
            assertTrue(card.isConflicting)
        }
        val colIndices = wedCourses.map { it.colIndex }.sorted()
        assertEquals(listOf(0, 1, 2), colIndices)
    }

    @Test
    fun `复杂交错重叠时贪心复用轨道（A跨1-4，B占1-2，C占3-4）`() {
        val courses = listOf(
            TimetableCourse(id = "cA", name = "长课A", dayOfWeek = 4, startSection = 1, endSection = 4, weeks = listOf(1)),
            TimetableCourse(id = "cB", name = "短课B", dayOfWeek = 4, startSection = 1, endSection = 2, weeks = listOf(1)),
            TimetableCourse(id = "cC", name = "短课C", dayOfWeek = 4, startSection = 3, endSection = 4, weeks = listOf(1)),
        )

        val result = WeekGridCourseMapping.filterAndPlaceCoursesForWeek(courses, week = 1)
        val thuCourses = result[4] ?: error("周四应有课程")
        assertEquals(3, thuCourses.size)

        val cardA = thuCourses.first { it.course.id == "cA" }
        val cardB = thuCourses.first { it.course.id == "cB" }
        val cardC = thuCourses.first { it.course.id == "cC" }

        // 总列宽只需 2 列
        assertEquals(2, cardA.totalCols)
        assertEquals(2, cardB.totalCols)
        assertEquals(2, cardC.totalCols)

        // A 与 B 同在第 1 节开始，分配不同列（0 和 1）；C (第 3 节开始) 与 B (第 2 节结束) 互不重叠，复用同一轨道
        assertEquals(setOf(0, 1), setOf(cardA.colIndex, cardB.colIndex))
        assertEquals(cardB.colIndex, cardC.colIndex)

        assertTrue(cardA.isConflicting)
        assertTrue(cardB.isConflicting)
        assertTrue(cardC.isConflicting)
    }

    @Test
    fun `非本周课程以灰卡与降低透明度展示`() {
        val courses = listOf(
            TimetableCourse(
                id = "c1",
                name = "单周课",
                dayOfWeek = 5,
                startSection = 1,
                endSection = 2,
                weeks = listOf(1, 3, 5),
                color = "#FF0000",
            ),
        )

        // 查看第 2 周（非上课周）
        val result = WeekGridCourseMapping.filterAndPlaceCoursesForWeek(courses, week = 2, showNonCurrentWeeks = true)
        val friCourses = result[5] ?: error("周五应有课程")
        assertEquals(1, friCourses.size)

        val card = friCourses.first()
        assertFalse(card.isCurrentWeek)
        assertEquals(WeekGridCourseMapping.NON_CURRENT_WEEK_COLOR_HEX, card.displayColor)
        assertEquals(WeekGridCourseMapping.NON_CURRENT_WEEK_OPACITY, card.opacity, 0.001f)

        // 若关闭 showNonCurrentWeeks，该课程应被过滤
        val hiddenResult = WeekGridCourseMapping.filterAndPlaceCoursesForWeek(courses, week = 2, showNonCurrentWeeks = false)
        assertTrue(hiddenResult[5]?.isEmpty() ?: true)
    }

    @Test
    fun `buildWeekDayColumns 组装 7 天完整列并正确标记今天`() {
        val mapped = mapOf(
            1 to listOf(
                WeekCourseCardModel(
                    course = TimetableCourse(id = "1", name = "A", dayOfWeek = 1, startSection = 1, endSection = 2),
                    dayOfWeek = 1,
                    startSection = 1,
                    endSection = 2,
                    sectionSpan = 2,
                    isCurrentWeek = true,
                )
            )
        )

        val columns = WeekGridCourseMapping.buildWeekDayColumns(mapped, todayDayOfWeek = 3)
        assertEquals(7, columns.size)

        assertEquals("周一", columns[0].dayName)
        assertFalse(columns[0].isToday)
        assertEquals(1, columns[0].courses.size)

        assertEquals("周三", columns[2].dayName)
        assertTrue("周三应标记为今天", columns[2].isToday)
        assertEquals(0, columns[2].courses.size)
    }
}
