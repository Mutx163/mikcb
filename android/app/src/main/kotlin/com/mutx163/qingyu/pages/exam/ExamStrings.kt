package com.mutx163.qingyu.pages.exam

import com.mutx163.qingyu.core.ExamReminderPreset

/**
 * 考试模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [ExamStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 命名与 ARB 键逐字一致（`examListTitle` 等），便于 `grep` 双向核对。
 */
typealias ArbText = com.mutx163.qingyu.app.ArbText

object ExamStrings {

    // ── 考试列表页 (ExamListScreen) ──
    val examListTitle = ArbText("examListTitle", "考试安排")
    val addExam = ArbText("addExam", "添加考试")
    val noExams = ArbText("noExams", "暂无考试安排")
    val examPassed = ArbText("examPassed", "已结束")
    val deleteExam = ArbText("deleteExam", "删除考试")
    val deleteExamConfirm = ArbText("deleteExamConfirm", "确定删除考试 {name}？")

    // ── 概览卡 ──
    val examToday = ArbText("examToday", "今天有考试")
    val daysUntilExam = ArbText("daysUntilExam", "距离考试还有 {days} 天")
    val examOverviewInProgress = ArbText("examOverviewInProgress", "考试进行中")
    val examOverviewLiveBadge = ArbText("examOverviewLiveBadge", "进行中")
    val examOverviewUntilTime = ArbText("examOverviewUntilTime", "至 {time}")
    val examOverviewTodayCount = ArbText("examOverviewTodayCount", "今日 {count} 场")
    val examOverviewUpcomingCount = ArbText("examOverviewUpcomingCount", "共 {count} 场")
    val examOverviewReminderOn = ArbText("examOverviewReminderOn", "已设提醒")
    val examOverviewReminderOff = ArbText("examOverviewReminderOff", "未设提醒")
    val examOverviewCountdownUnit = ArbText("examOverviewCountdownUnit", "天后")
    val examCountdownToday = ArbText("examCountdownToday", "今天")
    val examCountdownDays = ArbText("examCountdownDays", "{days} 天后")
    val examTimeRange = ArbText("examTimeRange", "{start} – {end}")

    // ── 添加/编辑考试页 (AddExamScreen) ──
    val editExam = ArbText("editExam", "编辑考试")
    val saveExam = ArbText("saveExam", "保存考试")
    val linkCourse = ArbText("linkCourse", "关联课程")
    val linkCourseRequired = ArbText("linkCourseRequired", "请选择关联课程")
    val noCoursesInCurrentProfile = ArbText("noCoursesInCurrentProfile", "当前课表已经没有课程")
    val examDefaultName = ArbText("examDefaultName", "期末考试")
    val examNameLabel = ArbText("examNameLabel", "考试名称")
    val examNameRequired = ArbText("examNameRequired", "请输入考试名称")
    val examDateLabel = ArbText("examDateLabel", "考试日期")
    val examDateHint = ArbText("examDateHint", "请选择日期")
    val examDateRequired = ArbText("examDateRequired", "请选择考试日期")
    val examDateWeekPickerTitle = ArbText("examDateWeekPickerTitle", "选择考试日期")
    val examStartTimeLabel = ArbText("examStartTimeLabel", "开始时间")
    val examEndTimeLabel = ArbText("examEndTimeLabel", "结束时间")
    val examEndTimeBeforeStart = ArbText("examEndTimeBeforeStart", "结束时间不能早于开始时间")
    val examLocationLabel = ArbText("examLocationLabel", "考场")
    val examLocationHint = ArbText("examLocationHint", "留空则使用上课教室")
    val sameAsClassroom = ArbText("sameAsClassroom", "同上课教室")
    val examSeatLabel = ArbText("examSeatLabel", "座位号")
    val examReminderLabel = ArbText("examReminderLabel", "提醒设置")
    val examNoteLabel = ArbText("examNoteLabel", "备注")
    val weekPickerCalendarTooltip = ArbText("weekPickerCalendarTooltip", "使用日历选择")
    val thisWeekLabel = ArbText("thisWeekLabel", "本周")
    val selectStartTimeTitle = ArbText("selectStartTimeTitle", "选择开始时间")
    val selectEndTimeTitle = ArbText("selectEndTimeTitle", "选择结束时间")

    // ── 提醒预设 ──
    val examReminderNone = ArbText("examReminderNone", "不提醒")
    val examReminderMin30 = ArbText("examReminderMin30", "考前 30 分钟")
    val examReminderHour1 = ArbText("examReminderHour1", "考前 1 小时")
    val examReminderHour1AndMin30 = ArbText("examReminderHour1AndMin30", "考前 1 小时 + 30 分钟")
    val examReminderDay1 = ArbText("examReminderDay1", "考前 1 天")
    val examReminderDay1AndHour1 = ArbText("examReminderDay1AndHour1", "考前 1 天 + 1 小时")
    val examReminderCustom = ArbText("examReminderCustom", "自定义")
    val examReminderOffsetMinutes = ArbText("examReminderOffsetMinutes", "考前 {minutes} 分钟")
    val examReminderOffsetHours = ArbText("examReminderOffsetHours", "考前 {hours} 小时")
    val examReminderOffsetDays = ArbText("examReminderOffsetDays", "考前 {days} 天")

    // ── 自定义提醒 ──
    val examReminderCustomEmpty = ArbText("examReminderCustomEmpty", "请至少选择一个提醒时间")
    val examReminderCustomEmptyHint = ArbText("examReminderCustomEmptyHint", "还没有自定义提醒，点下方添加")
    val examReminderAddCustom = ArbText("examReminderAddCustom", "添加提醒")
    val examReminderAddCustomTitle = ArbText("examReminderAddCustomTitle", "自定义提醒时间")
    val examReminderAddCustomHint = ArbText("examReminderAddCustomHint", "设置距离考试开始前多久提醒，可添加多个")
    val examReminderPickerDays = ArbText("examReminderPickerDays", "天")
    val examReminderPickerHours = ArbText("examReminderPickerHours", "小时")
    val examReminderPickerMinutes = ArbText("examReminderPickerMinutes", "分钟")
    val examReminderCustomAlreadyAdded = ArbText("examReminderCustomAlreadyAdded", "该提醒时间已添加")
    val examReminderCustomInvalid = ArbText("examReminderCustomInvalid", "请设置大于 0 的提醒时间")

    // 星期名
    val weekdayMon = ArbText("weekdayMon", "周一")
    val weekdayTue = ArbText("weekdayTue", "周二")
    val weekdayWed = ArbText("weekdayWed", "周三")
    val weekdayThu = ArbText("weekdayThu", "周四")
    val weekdayFri = ArbText("weekdayFri", "周五")
    val weekdaySat = ArbText("weekdaySat", "周六")
    val weekdaySun = ArbText("weekdaySun", "周日")

    // 星期短名（按钮上只放一个字，ARB `weekdayShortMonday..Sunday`）。
    // 2026-10-29 质量审核：`ExamPickerSheets` 原先用 `weekdayLabel(..).removePrefix("周")`
    // 现拼短名，等于在渲染层硬编码中文「周」；改成直接读 ARB 短名。
    val weekdayShortMon = ArbText("weekdayShortMonday", "一")
    val weekdayShortTue = ArbText("weekdayShortTuesday", "二")
    val weekdayShortWed = ArbText("weekdayShortWednesday", "三")
    val weekdayShortThu = ArbText("weekdayShortThursday", "四")
    val weekdayShortFri = ArbText("weekdayShortFriday", "五")
    val weekdayShortSat = ArbText("weekdayShortSaturday", "六")
    val weekdayShortSun = ArbText("weekdayShortSunday", "日")

    // 日期滚轮的年 / 月 / 日后缀（`ExamPickerSheets` 的三列滚轮）。
    val datePickerYear = ArbText("datePickerYear", "年")
    val datePickerMonth = ArbText("datePickerMonth", "月")
    val datePickerDay = ArbText("datePickerDay", "日")

    // 通用按钮 / 提示
    val weekLabel = ArbText("weekLabel", "第 {week} 周")
    val cancelAction = ArbText("cancelAction", "取消")
    val deleteAction = ArbText("deleteAction", "删除")
    val confirmAction = ArbText("confirmAction", "确认")
    val saveFailed = ArbText("saveFailed", "保存失败")

    /** 所有 ARB 文案清单，用于机械化单测逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            examListTitle,
            addExam,
            noExams,
            examPassed,
            deleteExam,
            deleteExamConfirm,
            examToday,
            daysUntilExam,
            examOverviewInProgress,
            examOverviewLiveBadge,
            examOverviewUntilTime,
            examOverviewTodayCount,
            examOverviewUpcomingCount,
            examOverviewReminderOn,
            examOverviewReminderOff,
            examOverviewCountdownUnit,
            examCountdownToday,
            examCountdownDays,
            examTimeRange,
            editExam,
            saveExam,
            linkCourse,
            linkCourseRequired,
            noCoursesInCurrentProfile,
            examDefaultName,
            examNameLabel,
            examNameRequired,
            examDateLabel,
            examDateHint,
            examDateRequired,
            examDateWeekPickerTitle,
            examStartTimeLabel,
            examEndTimeLabel,
            examEndTimeBeforeStart,
            examLocationLabel,
            examLocationHint,
            sameAsClassroom,
            examSeatLabel,
            examReminderLabel,
            examNoteLabel,
            weekPickerCalendarTooltip,
            thisWeekLabel,
            selectStartTimeTitle,
            selectEndTimeTitle,
            examReminderNone,
            examReminderMin30,
            examReminderHour1,
            examReminderHour1AndMin30,
            examReminderDay1,
            examReminderDay1AndHour1,
            examReminderCustom,
            examReminderOffsetMinutes,
            examReminderOffsetHours,
            examReminderOffsetDays,
            examReminderCustomEmpty,
            examReminderCustomEmptyHint,
            examReminderAddCustom,
            examReminderAddCustomTitle,
            examReminderAddCustomHint,
            examReminderPickerDays,
            examReminderPickerHours,
            examReminderPickerMinutes,
            examReminderCustomAlreadyAdded,
            examReminderCustomInvalid,
            weekdayMon,
            weekdayTue,
            weekdayWed,
            weekdayThu,
            weekdayFri,
            weekdaySat,
            weekdaySun,
            weekdayShortMon,
            weekdayShortTue,
            weekdayShortWed,
            weekdayShortThu,
            weekdayShortFri,
            weekdayShortSat,
            weekdayShortSun,
            datePickerYear,
            datePickerMonth,
            datePickerDay,
            weekLabel,
            cancelAction,
            deleteAction,
            confirmAction,
            saveFailed,
        )
    }

    /** 星期名（1=周一 … 7=周日，越界返回空串，对齐 `enum_localizations` 的分支）。 */
    fun weekdayLabel(weekday: Int): String = when (weekday) {
        1 -> weekdayMon.text
        2 -> weekdayTue.text
        3 -> weekdayWed.text
        4 -> weekdayThu.text
        5 -> weekdayFri.text
        6 -> weekdaySat.text
        7 -> weekdaySun.text
        else -> ""
    }

    /** 星期短名（1=周一 … 7=周日，越界返回空串）。取 ARB `weekdayShortMonday..Sunday`。 */
    fun weekdayShortLabel(weekday: Int): String = when (weekday) {
        1 -> weekdayShortMon.text
        2 -> weekdayShortTue.text
        3 -> weekdayShortWed.text
        4 -> weekdayShortThu.text
        5 -> weekdayShortFri.text
        6 -> weekdayShortSat.text
        7 -> weekdayShortSun.text
        else -> ""
    }

    /** 提醒预设名（对齐 `lib/l10n/enum_localizations.dart:examReminderPresetLabel`）。 */
    fun presetLabel(preset: ExamReminderPreset): String = when (preset) {
        ExamReminderPreset.NONE -> examReminderNone.text
        ExamReminderPreset.MIN_30 -> examReminderMin30.text
        ExamReminderPreset.HOUR_1 -> examReminderHour1.text
        ExamReminderPreset.HOUR_1_AND_MIN_30 -> examReminderHour1AndMin30.text
        ExamReminderPreset.DAY_1 -> examReminderDay1.text
        ExamReminderPreset.DAY_1_AND_HOUR_1 -> examReminderDay1AndHour1.text
        ExamReminderPreset.CUSTOM -> examReminderCustom.text
    }
}
