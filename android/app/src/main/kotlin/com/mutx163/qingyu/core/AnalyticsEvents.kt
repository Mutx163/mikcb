package com.mutx163.qingyu.core

/**
 * 埋点事件名常量表（2026-11-03 建立管道时从调用点盘点而来）。
 *
 * 事件在服务层发出（`TimetableCourseService` / `ScheduleItemService` /
 * `TimetableExamService` 的 `port.logEvent(...)` / `port.logExamEvent(...)`），
 * 2026-11-03 之前 [com.mutx163.qingyu.app.TimetableRepository.logEvent] 一直是空实现，
 * 这些名字只存在于调用点的字符串字面量里。本表把它们收拢成常量，
 * 并由 `AnalyticsEventsGuardTest`（读源码文本）钉住「调用点与常量表一致」：
 * 在服务层新增事件名而忘记登记到这里 ⇒ 守卫红。
 *
 * 事件名风格沿用 Dart 侧 snake_case，不改名（改名等于埋点断代）。
 */
object AnalyticsEvents {

    // ---------- 课程域（TimetableCourseService） ----------

    /** 新建单条课程。参数：day_of_week / section_count / has_short_name。 */
    const val COURSE_CREATED = "course_created"

    /** 修改单条课程。参数：day_of_week / section_count / has_short_name。 */
    const val COURSE_UPDATED = "course_updated"

    /** 删除单条课程。参数：remaining_course_count。 */
    const val COURSE_DELETED = "course_deleted"

    /** 新建一组课次（同一门课多条课次一起落）。参数：schedule_count / remaining_course_count。 */
    const val COURSE_GROUP_CREATED = "course_group_created"

    /** 整组替换课次。参数：schedule_count / remaining_course_count。 */
    const val COURSE_GROUP_UPDATED = "course_group_updated"

    /** 删除课程组（连同组上课次与挂的考试、作业）。参数：remaining_course_count。 */
    const val COURSE_GROUP_DELETED = "course_group_deleted"

    /** 清空整份课表。参数：cleared_course_count。 */
    const val COURSES_CLEARED = "courses_cleared"

    /** 新建作业。参数：has_course / has_due_date。 */
    const val TASK_CREATED = "task_created"

    /** 删除作业。参数：remaining_task_count。 */
    const val TASK_DELETED = "task_deleted"

    // ---------- 日程域（ScheduleItemService） ----------

    /** 新建日程条目。参数：has_location / has_note。 */
    const val SCHEDULE_ITEM_CREATED = "schedule_item_created"

    /** 修改整个系列。参数：has_location / has_note。 */
    const val SCHEDULE_ITEM_UPDATED = "schedule_item_updated"

    /** 删除整个系列。参数：remaining_schedule_item_count。 */
    const val SCHEDULE_ITEM_DELETED = "schedule_item_deleted"

    /** 只删某一次发生（系列其余保留）。参数：schedule_item_id / occurrence_date。 */
    const val SCHEDULE_ITEM_OCCURRENCE_DELETED = "schedule_item_occurrence_deleted"

    /** 只改某一次发生（系列其余保留）。参数：schedule_item_id / occurrence_date。 */
    const val SCHEDULE_ITEM_OCCURRENCE_UPDATED = "schedule_item_occurrence_updated"

    // ---------- 考试域（TimetableExamService，经 logExamEvent 转发） ----------

    /** 新建考试。参数：has_location / has_seat。 */
    const val EXAM_CREATED = "exam_created"

    /** 修改考试。参数：exam_id。 */
    const val EXAM_UPDATED = "exam_updated"

    /** 删除考试。参数：remaining_exam_count。 */
    const val EXAM_DELETED = "exam_deleted"

    /** 全部已登记事件名；守卫测试用它对拍调用点字符串字面量。 */
    val ALL: Set<String> = setOf(
        COURSE_CREATED,
        COURSE_UPDATED,
        COURSE_DELETED,
        COURSE_GROUP_CREATED,
        COURSE_GROUP_UPDATED,
        COURSE_GROUP_DELETED,
        COURSES_CLEARED,
        TASK_CREATED,
        TASK_DELETED,
        SCHEDULE_ITEM_CREATED,
        SCHEDULE_ITEM_UPDATED,
        SCHEDULE_ITEM_DELETED,
        SCHEDULE_ITEM_OCCURRENCE_DELETED,
        SCHEDULE_ITEM_OCCURRENCE_UPDATED,
        EXAM_CREATED,
        EXAM_UPDATED,
        EXAM_DELETED,
    )
}
