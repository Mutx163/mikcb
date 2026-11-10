package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「已有教师 / 地点」候选契约（发布版 `timetable_provider.dart` 的
 * `uniqueTeachers` / `uniqueLocations`；调用点 `add_course_screen.dart:917/:933`、
 * `course_followup_sheets.dart:421`）。
 *
 * 断言的是**弹层实际会拿到的候选实例**，不是「页面里出现了某个组件」：
 * 这条链最容易在「教师/地点两行接上了，但候选传了空表」上假完成。
 *
 * 输入口径：日程地点由调用方拍平成 `List<String?>`（本模型不依赖日程模型，L0 可编）。
 */
class CourseFieldSuggestionModelTest {

    private fun course(
        id: String,
        teacher: String = "",
        location: String = "",
    ): Course = Course(
        id = id,
        name = "课程-$id",
        teacher = teacher,
        location = location,
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    @Test
    fun `教师与地点各自去重 精确比对不折叠大小写`() {
        val suggestions = CourseFieldSuggestionLogic.build(
            courses = listOf(
                course("c1", teacher = "李老师", location = "主楼302"),
                course("c2", teacher = "李老师", location = "主楼302"),
                course("c3", teacher = "王老师", location = "A101"),
                // Dart `Set<String>` 是精确比对：大小写不同算两条，不自行合并。
                course("c4", teacher = "lily", location = "a101"),
            ),
        )

        assertEquals(listOf("lily", "李老师", "王老师").sorted(), suggestions.teachers.sorted())
        assertEquals(listOf("A101", "a101", "主楼302").sorted(), suggestions.locations.sorted())
        assertEquals("精确去重：教师 3 条（李老师只算一次）", 3, suggestions.teachers.size)
        assertEquals("精确去重：地点 3 条（A101 与 a101 不合并）", 3, suggestions.locations.size)
        assertTrue("自然序：应等于自身排序", suggestions.teachers == suggestions.teachers.sorted())
    }

    @Test
    fun `空表与空白值都不进候选`() {
        assertEquals(CourseFieldSuggestions.EMPTY, CourseFieldSuggestionLogic.build(emptyList()))

        val suggestions = CourseFieldSuggestionLogic.build(
            courses = listOf(
                course("c1", teacher = "  ", location = ""),
                course("c2", teacher = "李老师", location = "  "),
            ),
        )
        assertEquals(listOf("李老师"), suggestions.teachers)
        assertTrue("纯空格地点不进候选", suggestions.locations.isEmpty())
    }

    @Test
    fun `日程地点计入候选 教师不受日程影响`() {
        val suggestions = CourseFieldSuggestionLogic.build(
            courses = listOf(course("c1", teacher = "李老师", location = "主楼302")),
            // 日程地点：调用方拍平成 List<String?> 传进来（null = 该日程没填地点）。
            scheduleLocations = listOf("图书馆", "主楼302", null),
        )
        assertEquals("教师只来自课程", listOf("李老师"), suggestions.teachers)
        assertEquals("地点 = 课程 ∪ 日程，去重升序", listOf("主楼302", "图书馆").sorted(), suggestions.locations)
    }

    @Test
    fun `稳定排序 同一批输入多次调用结果一致`() {
        val courses = listOf(
            course("c1", location = "B区"),
            course("c2", location = "A区"),
            course("c3", location = "C区"),
        )
        val first = CourseFieldSuggestionLogic.build(courses)
        val second = CourseFieldSuggestionLogic.build(courses)
        assertEquals(first, second)
        assertEquals(listOf("A区", "B区", "C区").sorted(), first.locations)
    }
}
