package com.mutx163.qingyu.pages.task

import com.mutx163.qingyu.app.AppLocaleRuntime

/**
 * 任务模块文案常量（逐字对齐 `lib/l10n/app_zh.arb`）。
 *
 * 对拍：`test/.../pages/task/TaskStringsParityTest.kt`（2026-10-29 补。
 * 此前本注释就写着「通过单元测试逐条对拍」，但仓里并没有 task 的 parity 测试——
 * 审核 misc-wiring P2-2 记的正是这条「注释说了一件没有的事」）。
 * 新增文案时**同时**把它加进那张对照表，否则新的字没有任何测试钉住。
 */
object TaskStrings {
    val taskListTitle: String get() = AppLocaleRuntime.text("taskListTitle", "任务清单")
    val addTask: String get() = AppLocaleRuntime.text("taskAddFromCourse", "添加任务")
    val editTask: String get() = AppLocaleRuntime.text("editTask", "编辑任务")
    val saveTask: String get() = AppLocaleRuntime.text("saveTask", "保存任务")

    val taskTitleLabel: String get() = AppLocaleRuntime.text("taskTitleLabel", "任务标题")
    val taskTitleHint: String get() = AppLocaleRuntime.text("taskTitleHint", "例如：完成第三章习题")
    val taskTitleRequired: String get() = AppLocaleRuntime.text("taskTitleRequired", "请输入任务标题")

    val taskNoteLabel: String get() = AppLocaleRuntime.text("taskNoteLabel", "备注")
    val taskNoteHint: String get() = AppLocaleRuntime.text("taskNoteHint", "补充说明 可选")

    val taskDueDateLabel: String get() = AppLocaleRuntime.text("taskDueDateLabel", "截止日期")
    val taskNoDueDate: String get() = AppLocaleRuntime.text("taskNoDueDate", "无截止日期")
    val taskDueDateHint: String get() = AppLocaleRuntime.text("taskDueDateHint", "日视图不显示，只在「全部」里看得到")

    val taskUndatedHintSubtitle: String get() = AppLocaleRuntime.text("taskUndatedHintSubtitle", "它们在「今日」「本周」里看不到")
    fun taskUndatedHint(count: Int): String = "$count 条作业没设日期"

    val taskCourseLabel: String get() = AppLocaleRuntime.text("taskCourseLabel", "来源课程")
    val taskCourseFilter: String get() = AppLocaleRuntime.text("taskCourseFilter", "课程筛选")
    val taskAllCourses: String get() = AppLocaleRuntime.text("taskAllCourses", "全部课程")
    val taskNoCourse: String get() = AppLocaleRuntime.text("taskNoCourse", "无关联课程")

    val taskAllFilter: String get() = AppLocaleRuntime.text("taskAllFilter", "全部")
    val taskTodayFilter: String get() = AppLocaleRuntime.text("taskTodayFilter", "今日")
    val taskWeekFilter: String get() = AppLocaleRuntime.text("taskWeekFilter", "本周")

    val taskOverdueSection: String get() = AppLocaleRuntime.text("taskOverdueSection", "已逾期")
    val taskCompletedSection: String get() = AppLocaleRuntime.text("taskCompletedSection", "已完成")

    val taskNoTasks: String get() = AppLocaleRuntime.text("taskNoTasks", "还没有任务")
    val taskNoTasksForToday: String get() = AppLocaleRuntime.text("taskNoTasksForToday", "今日没有待办任务")
    val taskNoTasksForWeek: String get() = AppLocaleRuntime.text("taskNoTasksForWeek", "本周没有待办任务")
    val taskNoTasksForCourse: String get() = AppLocaleRuntime.text("taskNoTasksForCourse", "这个课程暂无任务")

    val taskDelete: String get() = AppLocaleRuntime.text("taskDelete", "删除任务")
    val taskDeleteConfirm: String get() = AppLocaleRuntime.text("taskDeleteConfirm", "确定删除这个任务吗？")

    val taskHomeworkDefaultTitle: String get() = AppLocaleRuntime.text("taskHomeworkDefaultTitle", "课程作业")
    val taskAddFromCourse: String get() = AppLocaleRuntime.text("taskAddFromCourse", "添加任务")
    val taskViewCourse: String get() = AppLocaleRuntime.text("taskViewCourse", "查看课程")

    val taskSaved: String get() = AppLocaleRuntime.text("taskSaved", "任务已保存")
    val taskUpdated: String get() = AppLocaleRuntime.text("taskUpdated", "任务已更新")
    val taskDeleted: String get() = AppLocaleRuntime.text("taskDeleted", "任务已删除")

    val saveFailed: String get() = AppLocaleRuntime.text("saveFailed", "保存失败")
    val cancelAction: String get() = AppLocaleRuntime.text("cancelAction", "取消")
    val deleteAction: String get() = AppLocaleRuntime.text("deleteAction", "删除")

    // ── 日期选择器（`TaskPickerSheets` 用）──
    // 「取消」沿用上面的 [cancelAction]（与 ARB `cancelAction` 同值）。
    const val confirmAction = "确认"          // 与 ARB `confirmAction` 同值
    // 日期量纲标签（任务页滚轮用）。
    // 2026-10-30：ARB 已补键 `datePickerYear` / `datePickerMonth` / `datePickerDay`
    // （六份 ARB 同步），因此不再是「ARB 里没有的野生字符串」——
    // `TaskStringsParityTest.日期量纲标签与 ARB 逐字一致` 会拿这里的值跟 ARB 逐字比对。
    // 本文件是纯常量对象（任务域各处把 `TaskStrings.xxx` 当 String 直接拼），
    // 所以保持 `const val` 形态，不改成 ArbText（那会强迫 12 处调用点都加 `.text`）。
    // 考试页的日期滚轮（`ExamPickerSheets`）用同一组 ARB 键，两处同源。
    val datePickerYear: String get() = AppLocaleRuntime.text("datePickerYear", "年")
    val datePickerMonth: String get() = AppLocaleRuntime.text("datePickerMonth", "月")
    val datePickerDay: String get() = AppLocaleRuntime.text("datePickerDay", "日")

    val serviceMsgLinkedCourseNotFound: String get() = AppLocaleRuntime.text("serviceMsgLinkedCourseNotFound", "关联的课程不存在")

    fun weekLabel(week: Long): String = "第 $week 周"
    fun dayTaskBandCountSummary(count: Int): String = "作业 $count 项"
    fun dayTaskBandOverdueBadge(days: Int): String = "逾期 $days 天"
    fun dayTaskBandOverdueMore(count: Int): String = "还有 $count 项逾期"
}
