package com.mutx163.qingyu.app

/**
 * 课程操作弹层的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [CourseActionStringsParityTest] 里与 ARB 机械比对。
 * 键名与 ARB 键逐字一致，便于 grep 双向核对。
 *
 * ⚠️ 类型名是 [CourseArbText] 而**不是** `ArbText`：本仓的 `ArbText` 是**每个模块目录各定义
 * 一份**的顶层类（`pages/course/CourseOverviewStrings.kt:15` 等），`app/` 包里目前没有。
 * 本包同时有多条泳道在写（设置族、课表族），在这里新增一个通用名 `ArbText` 有与别人撞名
 * 的风险（同包同名 = 编译不过），所以取一个本文件专属的名字。
 */
data class CourseArbText(val key: String, val zh: String) {
    /** 把 `{name}` 占位符换成 [value]（与 ARB 模板同口径）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)
}

object CourseActionStrings {

    // ── 主操作 ──
    val courseActionEditPrimary = CourseArbText("courseActionEditPrimary", "编辑课程")
    val courseActionRescheduleSecondary = CourseArbText("courseActionRescheduleSecondary", "调课")
    val courseActionSuspendSecondary = CourseArbText("courseActionSuspendSecondary", "停课")
    val courseActionUnsuspend = CourseArbText("courseActionUnsuspend", "恢复")
    val courseActionDeleteSecondary = CourseArbText("courseActionDeleteSecondary", "删除")

    // ── 附加操作 ──
    val classAlarmActionLabel = CourseArbText("classAlarmActionLabel", "设这节课的闹钟")
    val courseTaskAction = CourseArbText("courseTaskAction", "作业")

    // ── 说明与兜底 ──
    val courseActionSheetNotice = CourseArbText(
        "courseActionSheetNotice",
        "你正在查看第 {week} 周，如该时段突发考试或冲突，可立即在下方执行快速调课或停课",
    )
    val unknownTeacher = CourseArbText("unknownTeacher", "未知教师")
    val unknownLocation = CourseArbText("unknownLocation", "未知地点")
    val courseActionPartnerReadOnlyNotice = CourseArbText(
        "courseActionPartnerReadOnlyNotice",
        "这是对方课表中的课程，仅供查看，无法编辑或调课",
    )

    /** 所有对接 ARB 的文案集合（Parity 测试用）。 */
    val allTexts: List<CourseArbText> = listOf(
        courseActionEditPrimary,
        courseActionRescheduleSecondary,
        courseActionSuspendSecondary,
        courseActionUnsuspend,
        courseActionDeleteSecondary,
        classAlarmActionLabel,
        courseTaskAction,
        courseActionSheetNotice,
        unknownTeacher,
        unknownLocation,
        courseActionPartnerReadOnlyNotice,
    )

    /** `courseActionSheetNotice` 的周次填充。 */
    fun notice(week: Int): String = courseActionSheetNotice.filled("week", week.toString())

    /** 教师 / 地点的空值兜底（Dart `course_action_sheet.dart:768-775`）。 */
    fun teacherOrUnknown(teacher: String): String =
        teacher.ifBlank { unknownTeacher.zh }

    fun locationOrUnknown(location: String): String =
        location.ifBlank { unknownLocation.zh }

    /** 停课按钮的当前文案：已停课显示「恢复」（Dart `:898-900`）。 */
    fun suspendButtonLabel(suspendedThisWeek: Boolean): String =
        if (suspendedThisWeek) courseActionUnsuspend.zh else courseActionSuspendSecondary.zh
}

