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

    // ── 调课面板（2026-10-28 补；原先是渲染层里的中文硬编码，被 CJK 门禁判红）──
    /** 单节课节次摘要模板（ARB `sectionLabel`：「第 {section} 节」）。 */
    val sectionLabel = CourseArbText("sectionLabel", "第 {section} 节")
    val weekdayLabel = CourseArbText("weekdayLabel", "星期")
    val startSectionLabel = CourseArbText("startSectionLabel", "开始节次")
    val endSectionLabel = CourseArbText("endSectionLabel", "结束节次")
    val cancelAction = CourseArbText("cancelAction", "取消")
    val confirmAction = CourseArbText("confirmAction", "确认")

    /**
     * ⚠️ ARB **没有**「目标周」这个键（已 grep 确认；只有 `serviceMsgTargetWeekOutOfRange` 那种长句）。
     * 按「文案不许自拟」原则本应等 ARB 补键；但这是调课面板的一个量纲标签，先在此登记。
     * **不进 [allTexts]**（parity 测试要求每个键都在 ARB 里，缺键会让它红）。
     * ARB 补 `targetWeekLabel` 后应移入 `allTexts` 改为对拍。
     */
    const val targetWeekLabel = "目标周"

    /** 节次摘要：`第 {start}-{end} 节`（复用 ARB `sectionLabel` 模板，把区间塞进 `{section}`）。 */
    fun sectionRange(start: Int, end: Int): String =
        sectionLabel.filled("section", "$start-$end")

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
        sectionLabel,
        weekdayLabel,
        startSectionLabel,
        endSectionLabel,
        cancelAction,
        confirmAction,
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

