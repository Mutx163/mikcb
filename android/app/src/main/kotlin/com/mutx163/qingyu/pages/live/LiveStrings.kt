package com.mutx163.qingyu.pages.live

/**
 * 实时活动与超级岛模块 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [LiveStringsParityTest] 里与 ARB
 * 机械比对，键缺失或值被改写都会红。
 *
 * 命名与 ARB 键逐字一致（`liveSettingsTitle` 等），便于 grep 双向核对。
 */
typealias ArbText = com.mutx163.qingyu.app.ArbText

object LiveStrings {

    // ── 页面标题与分组 ──
    val liveActivitySettingsTitle = ArbText("liveActivitySettingsTitle", "实时活动设置")
    val liveSettingsTitle = ArbText("liveSettingsTitle", "超级岛与通知")
    val enableIslandDisplayTitle = ArbText("enableIslandDisplayTitle", "展示超级岛")

    // ── 提醒时段与开关 ──
    val beforeClassReminderTitle = ArbText("beforeClassReminderTitle", "上课前提醒")
    val beforeClassReminderSubtitle = ArbText("beforeClassReminderSubtitle", "课程开始前 {minutes} 分钟弹出")
    val duringClassReminderTitle = ArbText("duringClassReminderTitle", "课中与下课提醒")

    // ── 时间阈值与切入 ──
    val beforeClassPopupLabel = ArbText("beforeClassPopupLabel", "上课前弹出时间")
    val beforeClassMinutesOption = ArbText("beforeClassMinutesOption", "{minutes} 分钟")
    val liveClassReminderLeadTitle = ArbText("liveClassReminderLeadTitle", "重点提醒切入时机")
    val liveClassReminderLeadOptionImmediate = ArbText("liveClassReminderLeadOptionImmediate", "一上课就切换")
    val liveClassReminderLeadOptionMinutes = ArbText("liveClassReminderLeadOptionMinutes", "下课前 {minutes} 分钟")

    // ── 显示项配置 ──
    val showCountdownTitle = ArbText("showCountdownTitle", "显示倒计时")
    val showCourseNameTitle = ArbText("showCourseNameTitle", "显示课程名")
    val showLocationTitle = ArbText("showLocationTitle", "显示地点")
    val preferShortNameTitle = ArbText("preferShortNameTitle", "优先显示课程简称")
    val liveIslandVisualTitle = ArbText("liveIslandVisualTitle", "胶囊左侧图标")
    val liveIslandExpandedPreviewTitle = ArbText("liveIslandExpandedPreviewTitle", "展开态预览")
    val liveDisplaySummaryCountdown = ArbText("liveDisplaySummaryCountdown", "倒计时 {style}")

    // ── 实时活动预览 ──
    val liveIslandPreviewTitle = ArbText("liveIslandPreviewTitle", "超级岛预览")
    val liveIslandPreviewStageBeforeClass = ArbText("liveIslandPreviewStageBeforeClass", "即将上课")
    val liveIslandPreviewStageInClass = ArbText("liveIslandPreviewStageInClass", "上课中")
    val liveIslandPreviewStageBeforeEnd = ArbText("liveIslandPreviewStageBeforeEnd", "下课提醒")
    val liveIslandPreviewUntilClassStart = ArbText("liveIslandPreviewUntilClassStart", "距上课 {time}")
    val liveIslandPreviewUntilClassEnd = ArbText("liveIslandPreviewUntilClassEnd", "距下课 {time}")

    // ── 预览样例数据 ──
    val liveIslandPreviewSampleCourse = ArbText("liveIslandPreviewSampleCourse", "高等数学")
    val liveIslandPreviewSampleCourseShort = ArbText("liveIslandPreviewSampleCourseShort", "高数")
    val liveIslandPreviewSampleLocation = ArbText("liveIslandPreviewSampleLocation", "三教-401")
    val liveIslandPreviewSampleTeacher = ArbText("liveIslandPreviewSampleTeacher", "张老师")
    val liveIslandPreviewSampleNextClass = ArbText("liveIslandPreviewSampleNextClass", "大学物理")
    val liveIslandPreviewSampleNote = ArbText("liveIslandPreviewSampleNote", "带教材与习题册")
    val liveIslandPreviewTitleBeforeClass = ArbText("liveIslandPreviewTitleBeforeClass", "即将上课：{course}")
    val liveIslandPreviewTitleBeforeEnd = ArbText("liveIslandPreviewTitleBeforeEnd", "下课提醒：{course}")

    // ── 通用操作 ──
    val resetDefaultAction = ArbText("resetDefaultAction", "恢复默认")
    val saveFailed = ArbText("saveFailed", "保存失败")
    val cancelAction = ArbText("cancelAction", "取消")

    // ── 语义别名（对齐 Prompt 提示词） ──
    val liveIslandSettingsTitle get() = liveSettingsTitle
    val liveActivityEnableTitle get() = enableIslandDisplayTitle
    val liveActivityEnableSubtitle = ArbText(
        "liveActivityEnableSubtitle",
        "在锁屏和状态栏胶囊中实时展示课程信息与倒计时",
    )
    val liveIslandStyleTitle = ArbText("liveIslandStyleTitle", "实时活动样式")
    val liveReminderBeforeClass get() = beforeClassReminderTitle
    val liveReminderInProgress get() = duringClassReminderTitle
    val liveReminderDismissAfterClass = ArbText("liveReminderDismissAfterClass", "下课后驻留时间")
    val livePreviewDemoCourse get() = liveIslandPreviewSampleCourse
    val saveSuccess = ArbText("liveSaveSuccess", "设置已保存")

    // ── 所有对接 ARB 的文案集合（用于 Parity 测试机械对拍） ──
    val allTexts: List<ArbText> = listOf(
        liveSettingsTitle,
        enableIslandDisplayTitle,
        beforeClassReminderTitle,
        beforeClassReminderSubtitle,
        duringClassReminderTitle,
        beforeClassPopupLabel,
        beforeClassMinutesOption,
        liveClassReminderLeadTitle,
        liveClassReminderLeadOptionImmediate,
        liveClassReminderLeadOptionMinutes,
        showCountdownTitle,
        showCourseNameTitle,
        showLocationTitle,
        preferShortNameTitle,
        liveIslandVisualTitle,
        liveIslandExpandedPreviewTitle,
        liveDisplaySummaryCountdown,
        liveIslandPreviewTitle,
        liveIslandPreviewStageBeforeClass,
        liveIslandPreviewStageInClass,
        liveIslandPreviewStageBeforeEnd,
        liveIslandPreviewUntilClassStart,
        liveIslandPreviewUntilClassEnd,
        liveIslandPreviewSampleCourse,
        liveIslandPreviewSampleCourseShort,
        liveIslandPreviewSampleLocation,
        liveIslandPreviewSampleTeacher,
        liveIslandPreviewSampleNextClass,
        liveIslandPreviewSampleNote,
        liveIslandPreviewTitleBeforeClass,
        liveIslandPreviewTitleBeforeEnd,
        resetDefaultAction,
        saveFailed,
        cancelAction,
        liveActivitySettingsTitle,
        liveActivityEnableSubtitle,
        liveIslandStyleTitle,
        liveReminderDismissAfterClass,
        saveSuccess,
    )

    // ── 格式化纯函数 ──
    fun formatBeforeClassMinutes(minutes: Int): String =
        beforeClassMinutesOption.filled("minutes", minutes.toString())

    fun formatUntilClassStart(timeStr: String): String =
        liveIslandPreviewUntilClassStart.filled("time", timeStr)

    fun formatUntilClassEnd(timeStr: String): String =
        liveIslandPreviewUntilClassEnd.filled("time", timeStr)

    fun formatCountdown(totalSeconds: Long): String {
        val safeSeconds = totalSeconds.coerceAtLeast(0)
        val m = safeSeconds / 60
        val s = safeSeconds % 60
        return "%02d:%02d".format(m, s)
    }

    fun formatLeadMinutes(minutes: Int): String =
        "提前 $minutes 分钟"

    fun formatKeepMinutes(minutes: Int): String =
        if (minutes <= 0) "不驻留（立即结束）" else "下课后保留 $minutes 分钟"
}
