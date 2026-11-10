package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature

/**
 * 「沿用已有课程」的模型层（发布版 `add_course_screen.dart` 的
 * `_showCourseTemplateSheet` / `_applyCourseTemplate` 与
 * `widgets/course_template_picker_sheet.dart`）。
 *
 * 只做两件纯计算，页面不自己拼：
 * 1. **候选分组**：按课名分组；组的名片信息取该组**第一门课**
 *    （Dart `_buildCourseTile` 里 `final representative = group.courses.first`）。
 *    ⚠️ **排序是有意偏离**：发布版按插入序、不排序（见 [AddCourseTemplateLogic.groups]）。
 * 2. **回填**：课名 / 简称 / 教师 / 描述（`description ?? note ?? ''`）/ 性质 / 颜色六字段，
 *    **加上**把当前每条排课记录的教师与地点同步成该课的（Dart `_applyCourseTemplate`
 *    的 `for` 循环）。**不复制排课时间表**：发布版也不带，星期 / 节次 / 周次原样保留。
 */
data class AddCourseTemplateGroup(
    /** 课名（组名，已 trim；页面标题与去重都按它）。 */
    val name: String,
    /** 组内第一门课的教师（列表副标题）。 */
    val teacher: String,
    /** 组内第一门课的颜色（名片底色）。 */
    val color: String,
    /** 组内代表课——选中后按它回填（Dart 返回的是 `group.courses.first`）。 */
    val course: Course,
)

/** 回填到共享信息卡的六个字段（Dart `_applyCourseTemplate` 的前六行）。 */
data class AddCourseTemplateFill(
    val name: String,
    val shortName: String,
    val teacher: String,
    val description: String,
    val courseNature: CourseNature,
    val color: String,
)

object AddCourseTemplateLogic {

    /**
     * 课表里的课程 → 候选分组：按课名分组、组内取第一门课。
     *
     * ⚠️ **排序是有意偏离，不是复刻**：发布版 `timetable_provider.dart:461-469` 只
     * `putIfAbsent` 后按**插入序**遍历、不排序；这里 `sortedBy(name)` 是**有意的改进**
     * （课名升序更好找），别写成「对齐发布版」。
     *
     * 空名 / 纯空白名不参与（发布版的组名不会为空，这里防脏数据造出无名行）。
     */
    fun groups(courses: List<Course>): List<AddCourseTemplateGroup> =
        courses
            .filter { it.name.isNotBlank() }
            .groupBy { it.name.trim() }
            .map { (name, list) ->
                val head = list.first()
                AddCourseTemplateGroup(
                    name = name,
                    teacher = head.teacher,
                    color = head.color,
                    course = head,
                )
            }
            .sortedBy { it.name }

    /** 六字段回填值（Dart `_applyCourseTemplate` 前六行，描述取 `description ?? note ?? ''`）。 */
    fun fillFor(course: Course): AddCourseTemplateFill = AddCourseTemplateFill(
        name = course.name,
        shortName = course.shortName.orEmpty(),
        teacher = course.teacher,
        description = course.description ?: course.note ?: "",
        courseNature = course.courseNature,
        color = course.color,
    )

    /**
     * 每条排课记录的教师 / 地点同步成该课的，其余字段（星期 / 节次 / 周次 / 备注等）原样保留。
     *
     * 发布版 `_applyCourseTemplate` 只改这两个字段、**不搬排课时间**；这里同样一条不增不减。
     */
    fun fillEntries(
        entries: List<AddCourseScheduleEntryData>,
        course: Course,
    ): List<AddCourseScheduleEntryData> = entries.map {
        it.copy(teacher = course.teacher, location = course.location)
    }
}
