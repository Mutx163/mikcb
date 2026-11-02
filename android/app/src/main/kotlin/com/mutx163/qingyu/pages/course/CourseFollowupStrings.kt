package com.mutx163.qingyu.pages.course

/**
 * 周视图课程弹层「后续弹层」族的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [CourseFollowupStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 顶层 [ArbText] 定义在同包的 `CourseOverviewStrings.kt:15`（每个模块目录各定义一份），
 * 本文件**复用、不重复定义**。
 *
 * 覆盖的 Dart 出处：`lib/widgets/course_followup_sheets.dart`（删除范围 `:99-150`、
 * 停课范围 `:152-209`、删除确认 `:211-276`、调课 `:278-735`）。
 */
object CourseFollowupStrings {

    // ── 删除范围（Dart `_CourseDeleteModeSheetBody`）──
    val deleteModeTitle = ArbText("deleteModeTitle", "删除方式")
    val deleteCourseAction = ArbText("deleteCourseAction", "删这个课")
    val deleteOccurrenceAction = ArbText("deleteOccurrenceAction", "删这节课")
    val deleteModeHintCurrentWeek = ArbText(
        "deleteModeHintCurrentWeek",
        "删除课程将移除全部周次，仅删除此节仅移除第 {week} 周课程",
    )
    val deleteModeHintUnavailable = ArbText(
        "deleteModeHintUnavailable",
        "当前卡片不是第 {week} 周的实际排课，所以只能删除整条排课",
    )

    // ── 停课范围（Dart `_CourseSuspendModeSheetBody`）──
    val suspendSheetTitle = ArbText("suspendSheetTitle", "停课")
    val suspendSheetSubtitle = ArbText("suspendSheetSubtitle", "选择停课范围")
    val suspendThisWeek = ArbText("suspendThisWeek", "停本周")
    val suspendThisWeekDesc = ArbText("suspendThisWeekDesc", "仅暂停当前周")
    val suspendAllWeeks = ArbText("suspendAllWeeks", "全部停")
    val suspendAllWeeksDesc = ArbText("suspendAllWeeksDesc", "暂停所有周次")
    val unsuspendAllWeeks = ArbText("unsuspendAllWeeks", "恢复全部")
    val unsuspendAllWeeksDesc = ArbText("unsuspendAllWeeksDesc", "恢复所有周次")
    val courseActionUnsuspend = ArbText("courseActionUnsuspend", "恢复")

    // ── 删除确认（Dart `_DeleteCourseConfirmSheetBody`）──
    // 标题与正文都由调用方给（Dart 的 `showDeleteCourseConfirmDialog(title:, message:)`
    // 用的是 `deleteScheduleTitle` / `deleteLessonTitle` 与两条长句），所以这里只要按钮。
    val deleteAction = ArbText("deleteAction", "删除")

    // ── 调课（Dart `_CourseRescheduleSheetBody`）──
    val rescheduleCurrentOccurrenceTitle = ArbText("rescheduleCurrentOccurrenceTitle", "调本周这节课")
    val rescheduleCurrentOccurrenceSubtitle = ArbText(
        "rescheduleCurrentOccurrenceSubtitle",
        "仅改第 {week} 周本节，原课该周移除，其他周不变",
    )
    val currentBadge = ArbText("currentBadge", "当前")
    val rescheduleTargetWeekLabel = ArbText("rescheduleTargetWeekLabel", "调到第几周")
    val startSectionLabel = ArbText("startSectionLabel", "开始节次")
    val endSectionLabel = ArbText("endSectionLabel", "结束节次")
    val locationLabel = ArbText("locationLabel", "上课地点")
    val manualInputLabel = ArbText("manualInputLabel", "手动填写")
    val locationPrefix = ArbText("locationPrefix", "地点：{value}")
    val selectLocationTitle = ArbText("selectLocationTitle", "选择教室")
    val confirmRescheduleAction = ArbText("confirmRescheduleAction", "确认调课")
    // 周次步进 ± 按钮的读屏描述（无障碍用，不直接上屏）
    val reschedulePreviousWeekAction = ArbText("reschedulePreviousWeekAction", "上一周")
    val rescheduleNextWeekAction = ArbText("rescheduleNextWeekAction", "下一周")

    // ── 通用按钮 ──
    val cancelAction = ArbText("cancelAction", "取消")
    val confirmAction = ArbText("confirmAction", "确认")
    val clearAction = ArbText("clearAction", "清空")

    // ── 量纲（Dart 用 `l10n.weekLabel(n)` / `l10n.sectionLabel(n)` 现填占位符）──
    val weekLabel = ArbText("weekLabel", "第 {week} 周")
    val sectionLabel = ArbText("sectionLabel", "第 {section} 节")

    // ── 星期（由调用方注入给各弹层；此处保留 7 条供 parity 对拍与默认注入）──
    val weekdayMon = ArbText("weekdayMon", "周一")
    val weekdayTue = ArbText("weekdayTue", "周二")
    val weekdayWed = ArbText("weekdayWed", "周三")
    val weekdayThu = ArbText("weekdayThu", "周四")
    val weekdayFri = ArbText("weekdayFri", "周五")
    val weekdaySat = ArbText("weekdaySat", "周六")
    val weekdaySun = ArbText("weekdaySun", "周日")

    /** 所有对接 ARB 的文案集合（Parity 测试用）。 */
    val allTexts: List<ArbText> = listOf(
        deleteModeTitle,
        deleteCourseAction,
        deleteOccurrenceAction,
        deleteModeHintCurrentWeek,
        deleteModeHintUnavailable,
        suspendSheetTitle,
        suspendSheetSubtitle,
        suspendThisWeek,
        suspendThisWeekDesc,
        suspendAllWeeks,
        suspendAllWeeksDesc,
        unsuspendAllWeeks,
        unsuspendAllWeeksDesc,
        courseActionUnsuspend,
        deleteAction,
        rescheduleCurrentOccurrenceTitle,
        rescheduleCurrentOccurrenceSubtitle,
        currentBadge,
        rescheduleTargetWeekLabel,
        startSectionLabel,
        endSectionLabel,
        locationLabel,
        manualInputLabel,
        locationPrefix,
        selectLocationTitle,
        confirmRescheduleAction,
        reschedulePreviousWeekAction,
        rescheduleNextWeekAction,
        cancelAction,
        confirmAction,
        clearAction,
        weekLabel,
        sectionLabel,
        weekdayMon,
        weekdayTue,
        weekdayWed,
        weekdayThu,
        weekdayFri,
        weekdaySat,
        weekdaySun,
    )

    /** 「第 N 周」。 */
    fun week(week: Int): String = weekLabel.filled("week", week.toString())

    /** 「第 N 节」。 */
    fun section(section: Int): String = sectionLabel.filled("section", section.toString())

    /** 「地点：X」。 */
    fun location(value: String): String = locationPrefix.filled("value", value)

    /** 默认的 7 条星期文案（周一到周日）；壳里另有注入来源时以注入为准。 */
    fun weekdayLabels(): List<String> = listOf(
        weekdayMon.zh,
        weekdayTue.zh,
        weekdayWed.zh,
        weekdayThu.zh,
        weekdayFri.zh,
        weekdaySat.zh,
        weekdaySun.zh,
    )
}
