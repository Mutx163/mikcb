package com.mutx163.qingyu.pages.schedule

/**
 * 日程 (Schedule) 模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [ScheduleStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 命名与 ARB 键逐字一致（`scheduleListTitle` 等），便于 `grep` 双向核对。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板里的占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

fun String.filled(name: String, value: String): String = replace("{$name}", value)

object ScheduleStrings {

    // ── 日程列表页 (ScheduleListScreen) ──
    val scheduleListTitle = ArbText("scheduleListTitle", "日程安排")
    val addScheduleAction = ArbText("addScheduleAction", "添加日程")
    val scheduleListEmptyTitle = ArbText("scheduleListEmptyTitle", "暂无日程")
    val scheduleUpcomingSection = ArbText("scheduleUpcomingSection", "即将到来")
    val schedulePastSection = ArbText("schedulePastSection", "已过期")
    val schedulePausedSection = ArbText("schedulePausedSection", "已暂停")
    val deleteScheduleTitle = ArbText("deleteScheduleTitle", "删除日程")
    val deleteScheduleMessage = ArbText("deleteScheduleMessage", "确定删除日程 {title}？")
    val scheduleDeletedHint = ArbText("scheduleDeletedHint", "日程已删除")
    val scheduleBadgeLabel = ArbText("scheduleBadgeLabel", "日程")
    val scheduleOngoingLabel = ArbText("scheduleOngoingLabel", "进行中")
    val scheduleTimeRange = ArbText("scheduleTimeRange", "{start} – {end}")
    val scheduleWeeklyWithDay = ArbText("scheduleWeeklyWithDay", "每周 {day}")

    // ── 新增/编辑日程页 (AddScheduleItemScreen) ──
    val addScheduleTitle = ArbText("addScheduleTitle", "添加日程")
    val editScheduleTitle = ArbText("editScheduleTitle", "编辑日程")
    val scheduleQuickPresetSectionTitle = ArbText("scheduleQuickPresetSectionTitle", "快捷模板")
    val scheduleEnabledTitle = ArbText("scheduleEnabledTitle", "启用日程")
    val scheduleDisabledSubtitle = ArbText("scheduleDisabledSubtitle", "已暂停，不会显示提醒")
    val scheduleInfoSectionTitle = ArbText("scheduleInfoSectionTitle", "日程信息")
    val scheduleTitleRequired = ArbText("scheduleTitleRequired", "请输入日程标题")
    val scheduleTitleLabel = ArbText("scheduleTitleLabel", "日程标题")
    val scheduleTitleHint = ArbText("scheduleTitleHint", "例如：开组会、办证件、拿快递")
    val scheduleLocationLabel = ArbText("scheduleLocationLabel", "地点")
    val scheduleLocationHint = ArbText("scheduleLocationHint", "选填")
    val scheduleNoteLabel = ArbText("scheduleNoteLabel", "备注")
    val scheduleNoteHint = ArbText("scheduleNoteHint", "选填")
    val scheduleTimeSectionTitle = ArbText("scheduleTimeSectionTitle", "时间安排")
    val scheduleStartGroupLabel = ArbText("scheduleStartGroupLabel", "开始")
    val scheduleEndGroupLabel = ArbText("scheduleEndGroupLabel", "结束")
    val scheduleStartDateLabel = ArbText("scheduleStartDateLabel", "开始日期")
    val scheduleEndDateLabel = ArbText("scheduleEndDateLabel", "结束日期")
    val scheduleStartTimeLabel = ArbText("scheduleStartTimeLabel", "开始时间")
    val scheduleEndTimeLabel = ArbText("scheduleEndTimeLabel", "结束时间")
    val scheduleRepeatWeeklyHint = ArbText("scheduleRepeatWeeklyHint", "按开始日期对应的星期重复")
    val scheduleRepeatEndDateHint = ArbText("scheduleRepeatEndDateHint", "重复日程需要设置结束日期")
    val scheduleCrossDaySpanHint = ArbText("scheduleCrossDaySpanHint", "从 {start} 持续到 {end}")
    val scheduleRepeatSectionTitle = ArbText("scheduleRepeatSectionTitle", "重复设置")
    val scheduleRepeatNone = ArbText("scheduleRepeatNone", "不重复")
    val scheduleRepeatDaily = ArbText("scheduleRepeatDaily", "每天")
    val scheduleRepeatWeekly = ArbText("scheduleRepeatWeekly", "每周")
    val scheduleRepeatEndDateLabel = ArbText("scheduleRepeatEndDateLabel", "重复结束日期")
    val scheduleReminderSectionTitle = ArbText("scheduleReminderSectionTitle", "日程提醒")
    val scheduleReminderOff = ArbText("scheduleReminderOff", "不提醒")
    val scheduleReminderMinutes = ArbText("scheduleReminderMinutes", "提前 {minutes} 分钟")
    val scheduleReminderPermissionAction = ArbText("scheduleReminderPermissionAction", "检查通知权限")
    val scheduleReminderPermissionMissing =
        ArbText("scheduleReminderPermissionMissing", "通知权限未开启，日程仍会保存，但提醒可能无法送达")
    val scheduleAppearanceSectionTitle = ArbText("scheduleAppearanceSectionTitle", "显示样式")
    val customPaletteAction = ArbText("customPaletteAction", "调色盘自定义颜色")
    val selectStartTimeTitle = ArbText("selectStartTimeTitle", "选择开始时间")
    val selectEndTimeTitle = ArbText("selectEndTimeTitle", "选择结束时间")
    val scheduleTimeRangeInvalid = ArbText("scheduleTimeRangeInvalid", "结束时间必须晚于开始时间")
    val scheduleDateRangeInvalid = ArbText("scheduleDateRangeInvalid", "结束日期不能早于开始日期")
    val scheduleSavedHint = ArbText("scheduleSavedHint", "日程已添加")
    val scheduleUpdatedHint = ArbText("scheduleUpdatedHint", "日程已更新")
    val scheduleEditScopeTitle = ArbText("scheduleEditScopeTitle", "编辑范围")
    val scheduleEditScopeThis = ArbText("scheduleEditScopeThis", "仅本次")
    val scheduleEditScopeAll = ArbText("scheduleEditScopeAll", "全部重复日程")
    val scheduleOccurrenceEditHint = ArbText("scheduleOccurrenceEditHint", "你正在编辑这条重复日程的一次实例")
    val scheduleDeleteScopeTitle = ArbText("scheduleDeleteScopeTitle", "删除范围")
    val scheduleDeleteScopeThis = ArbText("scheduleDeleteScopeThis", "仅删除本次")
    val scheduleDeleteScopeAll = ArbText("scheduleDeleteScopeAll", "删除全部重复日程")

    // 快捷模板项标题
    val scheduleQuickPresetGroupMeeting = ArbText("scheduleQuickPresetGroupMeeting", "组会")
    val scheduleQuickPresetLecture = ArbText("scheduleQuickPresetLecture", "讲座")
    val scheduleQuickPresetMeeting = ArbText("scheduleQuickPresetMeeting", "会议")
    val scheduleQuickPresetDefense = ArbText("scheduleQuickPresetDefense", "答辩")
    val scheduleQuickPresetInterview = ArbText("scheduleQuickPresetInterview", "面试")
    val scheduleQuickPresetDining = ArbText("scheduleQuickPresetDining", "聚餐")
    val scheduleQuickPresetWorkout = ArbText("scheduleQuickPresetWorkout", "运动")
    val scheduleQuickPresetStudy = ArbText("scheduleQuickPresetStudy", "自习")
    val scheduleQuickPresetClinic = ArbText("scheduleQuickPresetClinic", "就诊")
    val scheduleQuickPresetCommute = ArbText("scheduleQuickPresetCommute", "出行")

    // 星期名
    val weekdayMon = ArbText("weekdayMon", "周一")
    val weekdayTue = ArbText("weekdayTue", "周二")
    val weekdayWed = ArbText("weekdayWed", "周三")
    val weekdayThu = ArbText("weekdayThu", "周四")
    val weekdayFri = ArbText("weekdayFri", "周五")
    val weekdaySat = ArbText("weekdaySat", "周六")
    val weekdaySun = ArbText("weekdaySun", "周日")

    // 通用按钮 / 提示
    val cancelAction = ArbText("cancelAction", "取消")
    val deleteAction = ArbText("deleteAction", "删除")
    val saveAction = ArbText("saveAction", "保存")
    val editAction = ArbText("editAction", "编辑")
    val saveFailed = ArbText("saveFailed", "保存失败")
    val deleteFailed = ArbText("deleteFailed", "删除失败")

    // ── 作息日期规则页 (ScheduleDateRuleScreen) ──
    val scheduleDateRuleSectionTitle = ArbText("scheduleDateRuleSectionTitle", "日期作息规则")
    val scheduleDateRuleSectionSubtitle =
        ArbText("scheduleDateRuleSectionSubtitle", "开始日自动套用模板为默认作息，最多 2 条；地点匹配优先")
    val scheduleDateRuleAdd = ArbText("scheduleDateRuleAdd", "添加日期规则")
    val scheduleDateRuleEdit = ArbText("scheduleDateRuleEdit", "编辑日期规则")
    val scheduleDateRuleEmpty = ArbText("scheduleDateRuleEmpty", "未设置日期规则")
    val scheduleDateRuleNameLabel = ArbText("scheduleDateRuleNameLabel", "规则名称")
    val scheduleDateRuleNameHint = ArbText("scheduleDateRuleNameHint", "例如：夏令时 / 冬令时")
    val scheduleDateRuleStartDate = ArbText("scheduleDateRuleStartDate", "开始日期")
    val scheduleDateRuleEndDate = ArbText("scheduleDateRuleEndDate", "结束日期")
    val scheduleDateRuleBoundScheme = ArbText("scheduleDateRuleBoundScheme", "使用时间模板")
    val scheduleDateRuleEnabled = ArbText("scheduleDateRuleEnabled", "启用")
    val scheduleDateRuleActiveToday = ArbText("scheduleDateRuleActiveToday", "今天在区间内")
    val scheduleDateRuleRangeSummary = ArbText("scheduleDateRuleRangeSummary", "{start}～{end}")
    val scheduleDateRuleMaxReached = ArbText("scheduleDateRuleMaxReached", "最多只能添加 2 条日期规则")
    val scheduleDateRuleNeedScheme = ArbText("scheduleDateRuleNeedScheme", "请先创建至少一套时间模板")
    val scheduleDateRuleNameRequired = ArbText("scheduleDateRuleNameRequired", "请填写规则名称")
    val scheduleDateRuleSaved = ArbText("scheduleDateRuleSaved", "日期规则已保存")
    val scheduleDateRuleSavedAndApplied =
        ArbText("scheduleDateRuleSavedAndApplied", "日期规则已保存，今天已更新所有课表的默认作息")
    val scheduleDateRuleSavedForFuture =
        ArbText("scheduleDateRuleSavedForFuture", "日期规则已保存，将在开始日期更新所有课表的默认作息")
    val scheduleDateRuleSavedButApplyFailed =
        ArbText("scheduleDateRuleSavedButApplyFailed", "日期规则已保存，但今日自动套用失败，请检查模板节数是否充足")
    val scheduleDateRuleDeleted = ArbText("scheduleDateRuleDeleted", "已删除日期规则")
    val scheduleDateRuleDeleteTitle = ArbText("scheduleDateRuleDeleteTitle", "删除日期规则？")
    val scheduleDateRuleDeleteMessage =
        ArbText("scheduleDateRuleDeleteMessage", "确定删除日期规则 {name}？已套用的作息不会自动恢复，需手动调整。")
    val scheduleDateRuleSaveFailed = ArbText("scheduleDateRuleSaveFailed", "保存失败：{reason}")
    val scheduleDateRuleErrorMax = ArbText("scheduleDateRuleErrorMax", "已达到 2 条上限")
    val scheduleDateRuleErrorOverlap = ArbText("scheduleDateRuleErrorOverlap", "日期区间与已有规则重叠")
    val scheduleDateRuleErrorInvalidDate = ArbText("scheduleDateRuleErrorInvalidDate", "日期格式无效")
    val scheduleDateRuleErrorEndBeforeStart =
        ArbText("scheduleDateRuleErrorEndBeforeStart", "结束日期不能早于开始日期")
    val scheduleDateRuleErrorSchemeRequired = ArbText("scheduleDateRuleErrorSchemeRequired", "请选择时间模板")
    val scheduleDateRuleErrorNameRequired = ArbText("scheduleDateRuleErrorNameRequired", "请填写名称")
    val locationTimeMatchUnknownScheme = ArbText("locationTimeMatchUnknownScheme", "未知时间模板")
    val locationTimeMatchSaveFailed = ArbText("locationTimeMatchSaveFailed", "保存失败")
    val serviceMsgTimeSchemeNotFound = ArbText("serviceMsgTimeSchemeNotFound", "时间模板不存在")

    /** 所有 ARB 文案清单，用于机械化单测逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            scheduleListTitle,
            addScheduleAction,
            scheduleListEmptyTitle,
            scheduleUpcomingSection,
            schedulePastSection,
            schedulePausedSection,
            deleteScheduleTitle,
            deleteScheduleMessage,
            scheduleDeletedHint,
            scheduleBadgeLabel,
            scheduleOngoingLabel,
            scheduleTimeRange,
            scheduleWeeklyWithDay,
            addScheduleTitle,
            editScheduleTitle,
            scheduleQuickPresetSectionTitle,
            scheduleEnabledTitle,
            scheduleDisabledSubtitle,
            scheduleInfoSectionTitle,
            scheduleTitleRequired,
            scheduleTitleLabel,
            scheduleTitleHint,
            scheduleLocationLabel,
            scheduleLocationHint,
            scheduleNoteLabel,
            scheduleNoteHint,
            scheduleTimeSectionTitle,
            scheduleStartGroupLabel,
            scheduleEndGroupLabel,
            scheduleStartDateLabel,
            scheduleEndDateLabel,
            scheduleStartTimeLabel,
            scheduleEndTimeLabel,
            scheduleRepeatWeeklyHint,
            scheduleRepeatEndDateHint,
            scheduleCrossDaySpanHint,
            scheduleRepeatSectionTitle,
            scheduleRepeatNone,
            scheduleRepeatDaily,
            scheduleRepeatWeekly,
            scheduleRepeatEndDateLabel,
            scheduleReminderSectionTitle,
            scheduleReminderOff,
            scheduleReminderMinutes,
            scheduleReminderPermissionAction,
            scheduleReminderPermissionMissing,
            scheduleAppearanceSectionTitle,
            customPaletteAction,
            selectStartTimeTitle,
            selectEndTimeTitle,
            scheduleTimeRangeInvalid,
            scheduleDateRangeInvalid,
            scheduleSavedHint,
            scheduleUpdatedHint,
            scheduleEditScopeTitle,
            scheduleEditScopeThis,
            scheduleEditScopeAll,
            scheduleOccurrenceEditHint,
            scheduleDeleteScopeTitle,
            scheduleDeleteScopeThis,
            scheduleDeleteScopeAll,
            scheduleQuickPresetGroupMeeting,
            scheduleQuickPresetLecture,
            scheduleQuickPresetMeeting,
            scheduleQuickPresetDefense,
            scheduleQuickPresetInterview,
            scheduleQuickPresetDining,
            scheduleQuickPresetWorkout,
            scheduleQuickPresetStudy,
            scheduleQuickPresetClinic,
            scheduleQuickPresetCommute,
            weekdayMon,
            weekdayTue,
            weekdayWed,
            weekdayThu,
            weekdayFri,
            weekdaySat,
            weekdaySun,
            cancelAction,
            deleteAction,
            saveAction,
            editAction,
            saveFailed,
            deleteFailed,
            scheduleDateRuleSectionTitle,
            scheduleDateRuleSectionSubtitle,
            scheduleDateRuleAdd,
            scheduleDateRuleEdit,
            scheduleDateRuleEmpty,
            scheduleDateRuleNameLabel,
            scheduleDateRuleNameHint,
            scheduleDateRuleStartDate,
            scheduleDateRuleEndDate,
            scheduleDateRuleBoundScheme,
            scheduleDateRuleEnabled,
            scheduleDateRuleActiveToday,
            scheduleDateRuleRangeSummary,
            scheduleDateRuleMaxReached,
            scheduleDateRuleNeedScheme,
            scheduleDateRuleNameRequired,
            scheduleDateRuleSaved,
            scheduleDateRuleSavedAndApplied,
            scheduleDateRuleSavedForFuture,
            scheduleDateRuleSavedButApplyFailed,
            scheduleDateRuleDeleted,
            scheduleDateRuleDeleteTitle,
            scheduleDateRuleDeleteMessage,
            scheduleDateRuleSaveFailed,
            scheduleDateRuleErrorMax,
            scheduleDateRuleErrorOverlap,
            scheduleDateRuleErrorInvalidDate,
            scheduleDateRuleErrorEndBeforeStart,
            scheduleDateRuleErrorSchemeRequired,
            scheduleDateRuleErrorNameRequired,
            locationTimeMatchUnknownScheme,
            locationTimeMatchSaveFailed,
            serviceMsgTimeSchemeNotFound,
        )
    }

    fun weekdayLabel(weekday: Int): String = when (weekday) {
        1 -> weekdayMon.zh
        2 -> weekdayTue.zh
        3 -> weekdayWed.zh
        4 -> weekdayThu.zh
        5 -> weekdayFri.zh
        6 -> weekdaySat.zh
        7 -> weekdaySun.zh
        else -> ""
    }
}
