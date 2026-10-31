package com.mutx163.qingyu.pages.task

/**
 * 任务模块文案常量（逐字对齐 `lib/l10n/app_zh.arb`）。
 *
 * 对拍：`test/.../pages/task/TaskStringsParityTest.kt`（2026-10-29 补。
 * 此前本注释就写着「通过单元测试逐条对拍」，但仓里并没有 task 的 parity 测试——
 * 审核 misc-wiring P2-2 记的正是这条「注释说了一件没有的事」）。
 * 新增文案时**同时**把它加进那张对照表，否则新的字没有任何测试钉住。
 */
object TaskStrings {
    const val taskListTitle = "任务清单"
    const val addTask = "添加任务"
    const val editTask = "编辑任务"
    const val saveTask = "保存任务"

    const val taskTitleLabel = "任务标题"
    const val taskTitleHint = "例如：完成第三章习题"
    const val taskTitleRequired = "请输入任务标题"

    const val taskNoteLabel = "备注"
    const val taskNoteHint = "补充说明 可选"

    const val taskDueDateLabel = "截止日期"
    const val taskNoDueDate = "无截止日期"
    const val taskDueDateHint = "日视图不显示，只在「全部」里看得到"

    const val taskUndatedHintSubtitle = "它们在「今日」「本周」里看不到"
    fun taskUndatedHint(count: Int): String = "$count 条作业没设日期"

    const val taskCourseLabel = "来源课程"
    const val taskCourseFilter = "课程筛选"
    const val taskAllCourses = "全部课程"
    const val taskNoCourse = "无关联课程"

    const val taskAllFilter = "全部"
    const val taskTodayFilter = "今日"
    const val taskWeekFilter = "本周"

    const val taskOverdueSection = "已逾期"
    const val taskCompletedSection = "已完成"

    const val taskNoTasks = "还没有任务"
    const val taskNoTasksForToday = "今日没有待办任务"
    const val taskNoTasksForWeek = "本周没有待办任务"
    const val taskNoTasksForCourse = "这个课程暂无任务"

    const val taskDelete = "删除任务"
    const val taskDeleteConfirm = "确定删除这个任务吗？"

    const val taskHomeworkDefaultTitle = "课程作业"
    const val taskAddFromCourse = "添加任务"
    const val taskViewCourse = "查看课程"

    const val taskSaved = "任务已保存"
    const val taskUpdated = "任务已更新"
    const val taskDeleted = "任务已删除"

    const val saveFailed = "保存失败"
    const val cancelAction = "取消"
    const val deleteAction = "删除"

    // ── 日期选择器（`TaskPickerSheets` 用）──
    // 「取消」沿用上面的 [cancelAction]（与 ARB `cancelAction` 同值）。
    const val confirmAction = "确认"          // 与 ARB `confirmAction` 同值
    // 日期量纲标签（任务页滚轮用）。
    // 2026-10-30：ARB 已补键 `datePickerYear` / `datePickerMonth` / `datePickerDay`
    // （六份 ARB 同步），因此不再是「ARB 里没有的野生字符串」——
    // `TaskStringsParityTest.日期量纲标签与 ARB 逐字一致` 会拿这里的值跟 ARB 逐字比对。
    // 本文件是纯常量对象（任务域各处把 `TaskStrings.xxx` 当 String 直接拼），
    // 所以保持 `const val` 形态，不改成 ArbText（那会强迫 12 处调用点都加 `.zh`）。
    // 考试页的日期滚轮（`ExamPickerSheets`）用同一组 ARB 键，两处同源。
    const val datePickerYear = "年"
    const val datePickerMonth = "月"
    const val datePickerDay = "日"

    const val serviceMsgLinkedCourseNotFound = "关联的课程不存在"

    fun weekLabel(week: Long): String = "第 $week 周"
    fun dayTaskBandCountSummary(count: Int): String = "作业 $count 项"
    fun dayTaskBandOverdueBadge(days: Int): String = "逾期 $days 天"
    fun dayTaskBandOverdueMore(count: Int): String = "还有 $count 项逾期"
}
