package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * AI 解析结果 → 课程模型（[AiImageImportCourseModel]）单测。
 *
 * 钉住落盘前必须正确的东西：钟点来自哪张节次表、周次怎么展开、选/必修怎么映射、
 * 哪些条目必须跳过。跳过数要能回到界面上（`importCourseRecordsDropped`），不许静默丢课。
 */
class AiImageImportCourseModelTest {

    private val sections = TimetableSettings.DEFAULT_SECTIONS

    private fun parsed(
        name: String = "高等数学",
        teacher: String = " 张老师 ",
        location: String = " A101 ",
        dayOfWeek: Int = 2,
        startSection: Int = 1,
        endSection: Int = 2,
        customWeeks: List<Int> = listOf(3, 1, 2, 2),
        courseNature: String = "elective",
        note: String = " 班级 ",
    ) = AiParsedCourse(
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        customWeeks = customWeeks,
        courseNature = courseNature,
        note = note,
    )

    @Test
    fun `按节次表填钟点 周次排序去重 选修映射 文本去空白`() {
        val conversion = AiImageImportCourseModel.convert(
            courses = listOf(parsed()),
            sections = sections,
            semesterWeekCount = 20,
            idFactory = { "ai-test" },
        )

        assertEquals(0, conversion.droppedCount)
        val course = conversion.courses.single()
        assertEquals("ai-test", course.id)
        assertEquals("高等数学", course.name)
        assertEquals("张老师", course.teacher)
        assertEquals("A101", course.location)
        assertEquals(2, course.dayOfWeek)
        // 默认节次表：第 1 节 08:00-08:45，第 2 节 08:55-09:40。
        assertEquals("08:00", course.startTime)
        assertEquals("09:40", course.endTime)
        assertEquals(listOf(1, 2, 3), course.customWeeks)
        assertEquals(1, course.startWeek)
        assertEquals(3, course.endWeek)
        assertEquals(CourseNature.ELECTIVE, course.courseNature)
        assertEquals("班级", course.note)
    }

    @Test
    fun `中文选修也映射为选修 必修与未知值回落必修`() {
        fun natureOf(raw: String) = AiImageImportCourseModel.convert(
            courses = listOf(parsed(courseNature = raw)),
            sections = sections,
            semesterWeekCount = 20,
        ).courses.single().courseNature

        assertEquals(CourseNature.ELECTIVE, natureOf("选修"))
        assertEquals(CourseNature.REQUIRED, natureOf("必修"))
        assertEquals(CourseNature.REQUIRED, natureOf("required"))
        assertEquals(CourseNature.REQUIRED, natureOf("whatever"))
    }

    @Test
    fun `周次为空按整学期每周处理 备注为空落 null`() {
        val course = AiImageImportCourseModel.convert(
            courses = listOf(parsed(customWeeks = emptyList(), note = "   ")),
            sections = sections,
            semesterWeekCount = 20,
        ).courses.single()

        assertEquals((1..20).toList(), course.customWeeks)
        assertEquals(1, course.startWeek)
        assertEquals(20, course.endWeek)
        assertNull(course.note)
    }

    @Test
    fun `空课名 星期越界 节次超出当前表 都跳过并计数`() {
        val conversion = AiImageImportCourseModel.convert(
            courses = listOf(
                parsed(name = "   "),
                parsed(dayOfWeek = 0),
                parsed(endSection = sections.size + 1),
                parsed(dayOfWeek = 7),
            ),
            sections = sections,
            semesterWeekCount = 20,
        )

        assertEquals(3, conversion.droppedCount)
        assertEquals(1, conversion.courses.size)
        assertEquals(7, conversion.courses.single().dayOfWeek)
    }

    @Test
    fun `requiredSectionCount 取最大结束节次 空列表为 0`() {
        assertEquals(0, AiImageImportCourseModel.requiredSectionCount(emptyList<AiParsedCourse>()))
        assertEquals(
            7,
            AiImageImportCourseModel.requiredSectionCount(
                listOf(parsed(endSection = 3), parsed(endSection = 7)),
            ),
        )
        assertTrue(AiImageImportCourseModel.requiredSectionCount(listOf(parsed(endSection = 1))) >= 1)
    }
}
