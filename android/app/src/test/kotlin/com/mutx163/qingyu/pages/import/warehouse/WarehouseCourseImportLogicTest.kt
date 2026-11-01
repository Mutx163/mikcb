package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.CourseNature
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F32：适配脚本回传课程数组的解析（对齐 Dart `warehouse_course_import_logic.dart`）。
 *
 * 重点钉住 Dart 侧踩过的两类坑：
 * - 一条脏记录不许让整批导入作废；
 * - 只有钟点、没有节次的早读课不许被静默丢掉。
 */
class WarehouseCourseImportLogicTest {

    private var nextId = 0

    private fun idFactory(): String = "course-${nextId++}"

    private fun parse(
        raw: List<Any?>,
        onSkip: ((WarehouseCourseImportLogic.SkipReason, String?, Throwable?) -> Unit)? = null,
    ) = WarehouseCourseImportLogic.parse(
        rawCourses = raw,
        idFactory = { idFactory() },
        unknownTeacher = "未知教师",
        unknownLocation = "未知地点",
        onSkip = onSkip,
    )

    @Test
    fun `完整记录按字段解析 周次去重升序`() {
        val courses = parse(
            listOf(
                mapOf(
                    "name" to "高等数学",
                    "teacher" to "张老师",
                    "position" to "A101",
                    "day" to 2,
                    "startSection" to 3,
                    "endSection" to 4,
                    "weeks" to listOf(5, 1, 3, 3, 2),
                ),
            ),
        )

        assertEquals(1, courses.size)
        val course = courses.single()
        assertEquals("高等数学", course.name)
        assertEquals("张老师", course.teacher)
        assertEquals("A101", course.location)
        assertEquals(2, course.dayOfWeek)
        assertEquals(3, course.startSection)
        assertEquals(4, course.endSection)
        assertEquals(listOf(1, 2, 3, 5), course.customWeeks)
        assertEquals(1, course.startWeek)
        assertEquals(5, course.endWeek)
    }

    @Test
    fun `JS 常见脏形状 字符串数字与数字布尔都能收`() {
        val courses = parse(
            listOf(
                mapOf(
                    "name" to "大学英语",
                    "day" to "3",
                    "startSection" to 1.0,
                    "endSection" to "2",
                    "weeks" to listOf("1", 2.0, 3),
                    "isCustomTime" to 1,
                    "customStartTime" to "8:05",
                    "customEndTime" to "9:35",
                ),
            ),
        )

        val course = courses.single()
        assertEquals(3, course.dayOfWeek)
        assertEquals(1, course.startSection)
        assertEquals(2, course.endSection)
        assertTrue(course.hasCustomTime)
        assertEquals("08:05", course.startTime)
        assertEquals("09:35", course.endTime)
    }

    @Test
    fun `只有钟点没有节次的早读课排进第 1 节 不许整条丢掉`() {
        val courses = parse(
            listOf(
                mapOf(
                    "name" to "早读",
                    "day" to 1,
                    "weeks" to listOf(1, 2, 3),
                    "customStartTime" to "07:10",
                    "customEndTime" to "07:40",
                ),
            ),
        )

        val course = courses.single()
        assertEquals(1, course.startSection)
        assertEquals(1, course.endSection)
        assertTrue(course.hasCustomTime)
        assertEquals("07:10", course.startTime)
    }

    @Test
    fun `倒挂钟点不算自定义时间 又没有节次就判不可用`() {
        val skipped = mutableListOf<WarehouseCourseImportLogic.SkipReason>()
        val courses = parse(
            listOf(
                mapOf(
                    "name" to "实验",
                    "day" to 3,
                    "weeks" to listOf(1),
                    "customStartTime" to "10:00",
                    "customEndTime" to "09:00",
                ),
            ),
        ) { reason, _, _ -> skipped.add(reason) }

        assertTrue(courses.isEmpty())
        assertEquals(listOf(WarehouseCourseImportLogic.SkipReason.UNUSABLE), skipped)
    }

    @Test
    fun `越界星期直接拒收 不夹到相邻一天`() {
        val skipped = mutableListOf<WarehouseCourseImportLogic.SkipReason>()
        val courses = parse(
            listOf(
                mapOf("name" to "周日课", "day" to 0, "startSection" to 1, "endSection" to 2, "weeks" to listOf(1)),
                mapOf("name" to "超界课", "day" to 8, "startSection" to 1, "endSection" to 2, "weeks" to listOf(1)),
            ),
        ) { reason, _, _ -> skipped.add(reason) }

        assertTrue(courses.isEmpty())
        assertEquals(
            listOf(
                WarehouseCourseImportLogic.SkipReason.UNUSABLE,
                WarehouseCourseImportLogic.SkipReason.UNUSABLE,
            ),
            skipped,
        )
    }

    @Test
    fun `单条记录类型异常只丢它自己 其他记录照常导入`() {
        val skipped = mutableListOf<WarehouseCourseImportLogic.SkipReason>()
        val courses = parse(
            listOf(
                mapOf(
                    "name" to "好课",
                    "day" to 2,
                    "startSection" to 1,
                    "endSection" to 2,
                    "weeks" to listOf(1),
                ),
                // 非字符串键：Dart 的 cast 会抛，整条按 malformed 丢掉。
                mapOf(1 to "坏课", "name" to "坏课", "day" to 2, "weeks" to listOf(1)),
                "not a record",
            ),
        ) { reason, _, _ -> skipped.add(reason) }

        assertEquals(1, courses.size)
        assertEquals("好课", courses.single().name)
        assertEquals(
            listOf(
                WarehouseCourseImportLogic.SkipReason.MALFORMED,
                WarehouseCourseImportLogic.SkipReason.MALFORMED,
            ),
            skipped,
        )
    }

    @Test
    fun `越界周次被削时上报 partialWeeks 但课仍进来`() {
        val skipped = mutableListOf<WarehouseCourseImportLogic.SkipReason>()
        val courses = parse(
            listOf(
                mapOf(
                    "name" to "周次残缺",
                    "day" to 4,
                    "startSection" to 1,
                    "endSection" to 2,
                    "weeks" to listOf(1, 2, 99, -1),
                ),
            ),
        ) { reason, _, _ -> skipped.add(reason) }

        assertEquals(listOf(1, 2), courses.single().customWeeks)
        assertEquals(listOf(WarehouseCourseImportLogic.SkipReason.PARTIAL_WEEKS), skipped)
    }

    @Test
    fun `字段缺失的必填项判不可用 并带上尽力读出的课名`() {
        val names = mutableListOf<String?>()
        val courses = parse(
            listOf(mapOf("name" to "缺节次", "day" to 2, "weeks" to listOf(1))),
        ) { _, name, _ -> names.add(name) }

        assertTrue(courses.isEmpty())
        assertEquals(listOf("缺节次"), names)
    }

    @Test
    fun `未知教师与地点用宿主传进来的占位文案`() {
        val course = parse(
            listOf(
                mapOf(
                    "name" to "无教师课",
                    "day" to 5,
                    "startSection" to 1,
                    "endSection" to 2,
                    "weeks" to listOf(1),
                ),
            ),
        ).single()

        assertEquals("未知教师", course.teacher)
        assertEquals("未知地点", course.location)
    }

    @Test
    fun `选修课性质被保留`() {
        val course = parse(
            listOf(
                mapOf(
                    "name" to "选修课",
                    "day" to 5,
                    "startSection" to 1,
                    "endSection" to 2,
                    "weeks" to listOf(1),
                    "courseNature" to "elective",
                ),
            ),
        ).single()

        assertEquals(CourseNature.ELECTIVE, course.courseNature)
    }

    @Test
    fun `空周次与空课名都判不可用`() {
        val courses = parse(
            listOf(
                mapOf("name" to "", "day" to 1, "startSection" to 1, "endSection" to 2, "weeks" to listOf(1)),
                mapOf("name" to "没周次", "day" to 1, "startSection" to 1, "endSection" to 2, "weeks" to emptyList<Int>()),
            ),
        )

        assertTrue(courses.isEmpty())
    }

    @Test
    fun `时钟规范化拒绝畸形串`() {
        assertNull(WarehouseCourseImportLogic.normalizeClock("8:555"))
        assertNull(WarehouseCourseImportLogic.normalizeClock("25:00"))
        assertNull(WarehouseCourseImportLogic.normalizeClock("abc"))
        assertEquals("08:05", WarehouseCourseImportLogic.normalizeClock(" 8:05 "))
        // 秒是两位时按 Dart 同口径接受，秒被丢弃。
        assertEquals("08:05", WarehouseCourseImportLogic.normalizeClock("8:05:30"))
    }
}
