package com.mutx163.qingyu.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.import.IcsImportModel
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导出 → 导入往返回归（2026-11-04，ICS 导出前缀补齐）。
 *
 * 有损来自**导出缺前缀**，不是导入 bug：Dart 导出给每一行加
 * `Teacher:` / `Location:` / `Description:` / `Note:` / `Session note:`
 * （ics_export_service.dart:323-336），Kotlin 曾只写裸行，导入只能按位置猜。
 * 本测试只验证导出侧修复后的往返，**不允许改导入去猜**。
 */
/**
 * ## 跨层说明（这是形态，不是债）
 *
 * 本文件在 `transfer/`，刻意引用了 `pages/import` 的 `IcsImportModel`：
 *
 * - `transfer`：ICS 导出侧（`IcsSerializer` 及其前缀/换行口径）；
 * - `pages/import`：ICS 导入侧模型（解析入口）；
 * - `core`：课程数据模型（往返比对的对象）。
 *
 * 为什么跨层：这条测试的判据是**往返一致**（导出再导入后，`Teacher:` / `Location:` 等
 * 前缀信息不丢）。只测导出侧看不出「导出了但导入读不到」，只测导入侧看不出「导入解析对
 * 但导出从没写过那个前缀」——两边都对、接起来丢字段，正是这条往返要抓的。
 */
class CourseExportRoundTripTest {

    private val fixedNow = LocalDateTime.of(2026, 11, 4, 12, 0)
    private val semesterStart = LocalDateTime.of(2026, 3, 2, 0, 0)

    @Test
    fun roundTrip_empty_teacher_does_not_steal_location_tail() {
        // 回归：空教师 + LOCATION「外语楼 B203」时，旧实现会把末段 `B203` 当教师。
        // 导出补 `Location:` 行后，导入走 explicitLocation 分支，教师保持空串、地点原样。
        val source = course(teacher = "", location = "外语楼 B203")
        val ics = exportIcs(listOf(source))

        assertTrue(unfold(ics).contains("Location: 外语楼 B203"))

        val imported = IcsImportModel.parseWakeUpSchedule(ics, fixedNow).courses.single()
        assertEquals("", imported.teacher)
        assertEquals("外语楼 B203", imported.location)
    }

    @Test
    fun roundTrip_preserves_description_and_note() {
        // 回归：裸行简介/备注会被当成位置式教师/地点并丢失；加前缀后逐字段保留。
        val source = course(
            teacher = "张老师",
            location = "教学楼A101",
            description = "上课带电脑",
            note = "第3周交作业",
        )
        val ics = exportIcs(listOf(source))

        assertTrue(unfold(ics).contains("Description: 上课带电脑"))
        assertTrue(unfold(ics).contains("Note: 第3周交作业"))

        val imported = IcsImportModel.parseWakeUpSchedule(ics, fixedNow).courses.single()
        assertEquals(source.name, imported.name)
        assertEquals(source.teacher, imported.teacher)
        assertEquals(source.location, imported.location)
        assertEquals(source.description, imported.description)
        assertEquals(source.note, imported.note)
    }

    /** 导出按 RFC 5545 在 75 字节处折行；断言 DESCRIPTION 内容前先还原折行。 */
    private fun unfold(ics: String): String = ics.replace("\r\n ", "")

    private fun exportIcs(courses: List<Course>): String {
        val collected = collectCourseEvents(
            profileId = "p1",
            courses = courses,
            semesterStartDate = semesterStart,
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 3, 31, 0, 0),
        )
        val events = collected.events.sortedWith(Comparator { left, right -> compareIcsEvents(left, right) })
        return IcsSerializer.serializeCalendar(
            calendarName = "往返回归",
            fromDate = LocalDateTime.of(2026, 3, 1, 0, 0),
            toDate = LocalDateTime.of(2026, 3, 31, 0, 0),
            generatedAt = fixedNow,
            events = events,
        )
    }

    private fun course(
        teacher: String,
        location: String,
        description: String? = null,
        note: String? = null,
    ): Course = Course(
        id = "course-1",
        name = "高等数学",
        teacher = teacher,
        location = location,
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = 1,
        endWeek = 1,
        description = description,
        note = note,
    )
}
