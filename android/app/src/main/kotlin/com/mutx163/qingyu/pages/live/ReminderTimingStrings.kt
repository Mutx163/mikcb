package com.mutx163.qingyu.pages.live

/**
 * 「提醒时间」子屏 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [ReminderTimingStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。命名与 ARB 键逐字一致，便于 grep 双向核对。
 *
 * 复用 [LiveStrings] 文件里已有的顶层 `data class ArbText`（同包 public），
 * 因此**不需要**改动 `LiveStrings.kt`。
 */
object ReminderTimingStrings {

    // ── 页面标题与分组标签 ──
    val liveReminderTimingTitle = ArbText("liveReminderTimingTitle", "提醒时段")
    val liveReminderSwitchesTitle = ArbText("liveReminderSwitchesTitle", "提醒开关")
    val liveDisplayModeTitle = ArbText("liveDisplayModeTitle", "展示方式")
    val liveTimeThresholdTitle = ArbText("liveTimeThresholdTitle", "时间阈值")

    // ── 提醒开关组 ──
    val beforeClassReminderTitle = ArbText("beforeClassReminderTitle", "上课前提醒")
    val beforeClassReminderSubtitle = ArbText("beforeClassReminderSubtitle", "课程开始前 {minutes} 分钟弹出")
    val duringClassReminderTitle = ArbText("duringClassReminderTitle", "课中与下课提醒")
    val liveClassReminderLeadTitle = ArbText("liveClassReminderLeadTitle", "重点提醒切入时机")
    val liveClassReminderLeadOptionImmediate = ArbText("liveClassReminderLeadOptionImmediate", "一上课就切换")
    val liveClassReminderLeadOptionMinutes = ArbText("liveClassReminderLeadOptionMinutes", "下课前 {minutes} 分钟")

    // ── 切入时机效果摘要（`_buildLiveClassReminderLeadSummary`） ──
    val liveClassReminderLeadSummaryImmediate = ArbText(
        "liveClassReminderLeadSummaryImmediate",
        "一上课切重点提醒，下课前逐秒倒数",
    )
    val liveClassReminderLeadSummaryKeepNormal = ArbText(
        "liveClassReminderLeadSummaryKeepNormal",
        "课中普通通知，下课前切重点提醒",
    )
    val liveClassReminderLeadSummaryIsland = ArbText(
        "liveClassReminderLeadSummaryIsland",
        "课中普通通知，下课前切超级岛",
    )
    val liveClassReminderLeadSummaryFocused = ArbText(
        "liveClassReminderLeadSummaryFocused",
        "下课前开始重点提醒",
    )

    // ── 展示方式组 ──
    val duringClassStatusNotificationTitle = ArbText("duringClassStatusNotificationTitle", "课中状态栏通知")
    val duringClassStatusNotificationImmediate = ArbText(
        "duringClassStatusNotificationImmediate",
        "保留状态栏通知",
    )
    val duringClassStatusNotificationBeforeEnd = ArbText(
        "duringClassStatusNotificationBeforeEnd",
        "重点提醒前用普通通知",
    )
    val duringClassStatusNotificationPersistent = ArbText(
        "duringClassStatusNotificationPersistent",
        "全程显示普通通知",
    )
    val enableIslandDisplayTitle = ArbText("enableIslandDisplayTitle", "展示超级岛")

    // ── 时间阈值组 ──
    val beforeClassPopupLabel = ArbText("beforeClassPopupLabel", "上课前弹出时间")
    val beforeClassMinutesOption = ArbText("beforeClassMinutesOption", "{minutes} 分钟")
    val beforeEndSecondsLabel = ArbText("beforeEndSecondsLabel", "下课前秒级阈值")
    val beforeEndSecondsOption = ArbText("beforeEndSecondsOption", "{seconds} 秒")
    val duringEndTimeDisplayLabel = ArbText("duringEndTimeDisplayLabel", "课中时间样式")
    val liveDuringClassTimeNearest = ArbText("liveDuringClassTimeNearest", "最近时间")
    val liveDuringClassTimeTotal = ArbText("liveDuringClassTimeTotal", "总时间")

    /** 所有对接 ARB 的文案集合（用于 Parity 测试机械对拍）。 */
    val allTexts: List<ArbText> = listOf(
        liveReminderTimingTitle,
        liveReminderSwitchesTitle,
        liveDisplayModeTitle,
        liveTimeThresholdTitle,
        beforeClassReminderTitle,
        beforeClassReminderSubtitle,
        duringClassReminderTitle,
        liveClassReminderLeadTitle,
        liveClassReminderLeadOptionImmediate,
        liveClassReminderLeadOptionMinutes,
        liveClassReminderLeadSummaryImmediate,
        liveClassReminderLeadSummaryKeepNormal,
        liveClassReminderLeadSummaryIsland,
        liveClassReminderLeadSummaryFocused,
        duringClassStatusNotificationTitle,
        duringClassStatusNotificationImmediate,
        duringClassStatusNotificationBeforeEnd,
        duringClassStatusNotificationPersistent,
        enableIslandDisplayTitle,
        beforeClassPopupLabel,
        beforeClassMinutesOption,
        beforeEndSecondsLabel,
        beforeEndSecondsOption,
        duringEndTimeDisplayLabel,
        liveDuringClassTimeNearest,
        liveDuringClassTimeTotal,
    )

    // ── 格式化纯函数 ──

    /** 「上课前提醒」行副标题：「课程开始前 {minutes} 分钟弹出」。 */
    fun formatBeforeClassReminderSubtitle(minutes: Int): String =
        beforeClassReminderSubtitle.filled("minutes", minutes.toString())

    /**
     * 「重点提醒切入时机」单个选项文案：0 -> 「一上课就切换」，其余 -> 「下课前 N 分钟」。
     *
     * 对应 Dart `:155-162` 的 items（immediate 与 minutes(N) 两套标签）。
     */
    fun leadOptionText(minutes: Int): String =
        if (minutes == 0) {
            liveClassReminderLeadOptionImmediate.zh
        } else {
            liveClassReminderLeadOptionMinutes.filled("minutes", minutes.toString())
        }

    /** 切入时机摘要四种口径 -> 屏上文案（未知态按 FOCUSED 兜底，不崩）。 */
    fun leadSummaryText(summary: ReminderLeadSummary): String = when (summary) {
        ReminderLeadSummary.IMMEDIATE -> liveClassReminderLeadSummaryImmediate.zh
        ReminderLeadSummary.KEEP_NORMAL -> liveClassReminderLeadSummaryKeepNormal.zh
        ReminderLeadSummary.ISLAND -> liveClassReminderLeadSummaryIsland.zh
        ReminderLeadSummary.FOCUSED -> liveClassReminderLeadSummaryFocused.zh
    }

    /** 「课中状态栏通知」行副标题三种口径 -> 屏上文案。 */
    fun duringClassStatusHintText(hint: DuringClassStatusHint): String = when (hint) {
        DuringClassStatusHint.KEEP_STATUS_NOTIFICATION -> duringClassStatusNotificationImmediate.zh
        DuringClassStatusHint.NORMAL_THEN_LEAD -> duringClassStatusNotificationBeforeEnd.zh
        DuringClassStatusHint.PERSISTENT -> duringClassStatusNotificationPersistent.zh
    }

    /** 「课中时间样式」枚举 -> 屏上文案（Dart `liveDuringClassTimeDisplayModeLabel`）。 */
    fun displayModeText(mode: LiveDuringClassTimeDisplayMode): String = when (mode) {
        LiveDuringClassTimeDisplayMode.NEAREST -> liveDuringClassTimeNearest.zh
        LiveDuringClassTimeDisplayMode.TOTAL -> liveDuringClassTimeTotal.zh
    }

    /** 「上课前弹出时间」单个选项：「{minutes} 分钟」。 */
    fun formatBeforeClassMinutesOption(minutes: Int): String =
        beforeClassMinutesOption.filled("minutes", minutes.toString())

    /** 「下课前秒级阈值」单个选项：「{seconds} 秒」。 */
    fun formatBeforeEndSecondsOption(seconds: Int): String =
        beforeEndSecondsOption.filled("seconds", seconds.toString())
}
