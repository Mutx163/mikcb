package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「沿用已有课程」契约（发布版 v2.1.4.1 `add_course_screen.dart` 的
 * `_showCourseTemplateSheet:1495-1509` / `_applyCourseTemplate:1479-1493` 与
 * `widgets/course_template_picker_sheet.dart`）。
 *
 * ⚠️ 其中「按课名升序」是**有意的改进**，不是发布版行为：发布版
 * `timetable_provider.dart:461-469` 按插入序、不排序（模型层 KDoc 已写明）。
 *
 * 直接断言**回填后的模型字段**与**排课行的教师 / 地点**，而不是「页面里出现了某个组件」：
 * 这类回填最容易在「改了共享信息、忘了同步条目」上悄悄错一半。
 */
class AddCourseTemplateModelTest {

    private fun course(
        id: String,
        name: String,
        teacher: String,
        location: String = "教学楼101",
        shortName: String? = "高数",
        description: String? = "微积分与线性代数",
        note: String? = "备注文本",
        color: String = "#2196F3",
        nature: CourseNature = CourseNature.REQUIRED,
    ): Course = Course(
        id = id,
        name = name,
        shortName = shortName,
        teacher = teacher,
        location = location,
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = 1,
        endWeek = 16,
        color = color,
        courseNature = nature,
        description = description,
        note = note,
    )

    private fun entry(
        id: String,
        dayOfWeek: Int,
        startSection: Int,
        endSection: Int,
        teacher: String = "旧教师",
        location: String = "旧教室",
    ) = AddCourseScheduleEntryData(
        id = id,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        teacher = teacher,
        location = location,
    )

    @Test
    fun `候选按课名分组 组内取第一门 整表按名称升序`() {
        val groups = AddCourseTemplateLogic.groups(
            listOf(
                course(id = "c1", name = "高等数学", teacher = "李老师", color = "#2196F3"),
                course(id = "c2", name = "大学英语", teacher = "王老师", color = "#EF4444"),
                // 同名课（真实课表里同名课会合并成一门，这里仍要只出一行、取第一门的信息）
                course(id = "c3", name = "高等数学", teacher = "后来的老师", color = "#22C55E"),
                // 脏数据：空名不进候选
                course(id = "c4", name = "   ", teacher = "无名"),
            ),
        )

        assertEquals("空名不应进入候选", 2, groups.size)
        assertEquals("整表按名称升序", listOf("大学英语", "高等数学"), groups.map { it.name })
        val math = groups.first { it.name == "高等数学" }
        assertEquals("组内取第一门课的教师", "李老师", math.teacher)
        assertEquals("组内取第一门课的颜色", "#2196F3", math.color)
        assertEquals("选中回填用的是代表课（第一门）", "c1", math.course.id)
    }

    @Test
    fun `回填六字段 描述优先 description 再回落 note`() {
        val fill = AddCourseTemplateLogic.fillFor(
            course(
                id = "c1",
                name = "高等数学",
                teacher = "李老师",
                shortName = "高数",
                description = "微积分",
                note = "备注",
                color = "#6366F1",
                nature = CourseNature.ELECTIVE,
            ),
        )
        assertEquals("高等数学", fill.name)
        assertEquals("高数", fill.shortName)
        assertEquals("李老师", fill.teacher)
        assertEquals("微积分", fill.description)
        assertEquals(CourseNature.ELECTIVE, fill.courseNature)
        assertEquals("#6366F1", fill.color)

        // description 为空串时发布版取的是 `description ?? note`——空串不等于 null，
        // 仍按空串回填（与 Dart 运算符语义逐字一致）。
        val withEmptyDescription = AddCourseTemplateLogic.fillFor(
            course(id = "c2", name = "大学英语", teacher = "王老师", description = "", note = "备注"),
        )
        assertEquals("", withEmptyDescription.description)

        // description 为 null 才回落 note。
        val onlyNote = AddCourseTemplateLogic.fillFor(
            course(id = "c3", name = "大学物理", teacher = "赵老师", description = null, note = "旧备注"),
        )
        assertEquals("旧备注", onlyNote.description)
    }

    @Test
    fun `回填把每条排课行教师地点同步成该课的 且不复制排课时间表`() {
        val source = course(id = "c1", name = "高等数学", teacher = "李老师", location = "主楼302")
        val before = listOf(
            entry(id = "e1", dayOfWeek = 3, startSection = 5, endSection = 6),
            entry(id = "e2", dayOfWeek = 7, startSection = 9, endSection = 10),
        )

        val after = AddCourseTemplateLogic.fillEntries(before, source)

        assertEquals("条数不变（不搬排课时间表）", before.size, after.size)
        after.forEachIndexed { index, filled ->
            assertEquals("第 $index 条教师同步", "李老师", filled.teacher)
            assertEquals("第 $index 条地点同步", "主楼302", filled.location)
            // 星期 / 节次 / 周次这些「排课时间表」字段必须原样保留。
            assertEquals(before[index].dayOfWeek, filled.dayOfWeek)
            assertEquals(before[index].startSection, filled.startSection)
            assertEquals(before[index].endSection, filled.endSection)
            assertEquals(before[index].startWeek, filled.startWeek)
            assertEquals(before[index].endWeek, filled.endWeek)
            assertEquals(before[index].id, filled.id)
        }
        assertNotEquals("同步前的旧教师必须真被替换", "旧教师", after.first().teacher)
        assertTrue("原列表不可被就地改动", before.first().teacher == "旧教师")
    }
}
