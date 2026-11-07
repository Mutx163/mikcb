package com.mutx163.qingyu.pages.timetable.month

/**
 * 月视图用到的全部 ARB 文案（`lib/l10n/app_zh.arb`）。
 *
 * **逐字抄录，不许改写**：每一条都在 [MonthViewStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。表里只收录月视图真正上屏的 `monthView*` / `monthOverview*` 键。
 *
 * ⚠️ 本文件由 `tool/gen_month_view_strings.py` 从 ARB 直接生成，**不要手改**；
 * ARB 改了要重新生成，否则对拍测试会指出差异。
 */
object MonthViewStrings {

    val monthViewTitle = ArbText("monthViewTitle", "月视图")
    val monthViewPreviousMonth = ArbText("monthViewPreviousMonth", "上个月")
    val monthViewNextMonth = ArbText("monthViewNextMonth", "下个月")
    val monthViewBackToCurrentMonthShort = ArbText("monthViewBackToCurrentMonthShort", "今天")
    val monthViewYearSegment = ArbText("monthViewYearSegment", "{year}年")
    val monthViewMonthSegment = ArbText("monthViewMonthSegment", "{month}月")
    val monthViewHolidayBadge = ArbText("monthViewHolidayBadge", "休")
    val monthViewAdjustedWorkdayBadge = ArbText("monthViewAdjustedWorkdayBadge", "班")
    val monthViewAgendaTitle = ArbText("monthViewAgendaTitle", "{month}月{day}日")
    val monthViewAgendaEmpty = ArbText("monthViewAgendaEmpty", "这天没有安排")
    val monthViewAgendaAddCourse = ArbText("monthViewAgendaAddCourse", "加课")
    val monthViewEmptyMonthTitle = ArbText("monthViewEmptyMonthTitle", "这个月还没有安排")
    val monthViewEmptyMonthHint = ArbText("monthViewEmptyMonthHint", "先加一节课，日历上就会显示圆点")
    val monthOverviewTitle = ArbText("monthOverviewTitle", "本月概览")
    val monthOverviewDaysTitle = ArbText("monthOverviewDaysTitle", "本月有安排的日子")
    val monthOverviewScheduledDays = ArbText("monthOverviewScheduledDays", "有安排 {count} 天")
    val monthOverviewMoreDays = ArbText("monthOverviewMoreDays", "还有 {count} 天")
    val monthViewDaySemantics = ArbText("monthViewDaySemantics", "{month}月{day}日")
    val monthViewCourseCountSemantics = ArbText("monthViewCourseCountSemantics", "{count}节课")
    val monthViewExamCountSemantics = ArbText("monthViewExamCountSemantics", "{count}场考试")
    val monthViewScheduleCountSemantics = ArbText("monthViewScheduleCountSemantics", "{count}个日程")

    /** ARB 里的原始键值对：`(键, 中文原文)`，供逐字对拍测试扫全集。 */
    val allTexts: List<ArbText> = listOf(
        monthViewTitle,
        monthViewPreviousMonth,
        monthViewNextMonth,
        monthViewBackToCurrentMonthShort,
        monthViewYearSegment,
        monthViewMonthSegment,
        monthViewHolidayBadge,
        monthViewAdjustedWorkdayBadge,
        monthViewAgendaTitle,
        monthViewAgendaEmpty,
        monthViewAgendaAddCourse,
        monthViewEmptyMonthTitle,
        monthViewEmptyMonthHint,
        monthOverviewTitle,
        monthOverviewDaysTitle,
        monthOverviewScheduledDays,
        monthOverviewMoreDays,
        monthViewDaySemantics,
        monthViewCourseCountSemantics,
        monthViewExamCountSemantics,
        monthViewScheduleCountSemantics,
    )
}

/**
 * ARB 文本句柄：键名 + 中文原文 + 占位符填充。
 *
 * 与 `pages/timetable/TimetableStrings.kt` 里那份同构（那边是周视图的）。之所以不跨包
 * 复用：两边各自的对拍测试按包定位 ARB 键，共用会让「谁漏了键」变模糊。
 */
typealias ArbText = com.mutx163.qingyu.app.ArbText
