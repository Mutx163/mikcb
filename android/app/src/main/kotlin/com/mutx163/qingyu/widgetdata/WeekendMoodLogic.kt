package com.mutx163.qingyu.widgetdata

/**
 * 桌面小组件的「周末文案」档位判定（移植 lib/domain/weekend_mood_logic.dart:55-81）。
 *
 * 为什么**不**把周末算成假期：假期态会连带清空当天的课程列表，周末有课的人会被
 * 抹掉课程。这里只做一件事：在「今天确实一节课都没排」的空位上把文案换成周末文案，
 * **绝不参与课程过滤**。
 *
 * 与 Kotlin 既有实现 WidgetHolidayLogic.widgetResolveWeekendMood 逐条同口径
 * （App 活着时由 Flutter 算好推给卡片，App 被杀后卡片自己重算；判定不一致会出现
 * 「重启后文案变了」）。
 */
object WeekendMoodLogic {

    /**
     * 判定今天该显示哪档周末文案。
     *
     * @param dayOfWeek 1=周一 … 7=周日
     * @param hasAnyCourseToday 当天**排了**课（含已停课）——停课也算「排了课」。
     * @param hasRemainingCourseToday 今天还有正在上或还没开始的课。
     * @param isHolidayToday 法定假期/调休休息（假期有自己的文案，不叠加）。
     * @param isAdjustedWorkdayToday/Tomorrow 调休补班日（补班的周六日要上班）。
     */
    fun resolve(
        dayOfWeek: Int,
        hasAnyCourseToday: Boolean,
        hasRemainingCourseToday: Boolean,
        isHolidayToday: Boolean,
        isAdjustedWorkdayToday: Boolean,
        isAdjustedWorkdayTomorrow: Boolean,
    ): WeekendMoodData {
        if (isHolidayToday) return WeekendMoodData.NONE
        val isWeekend = dayOfWeek == 6 || dayOfWeek == 7
        if (isWeekend) {
            if (isAdjustedWorkdayToday || hasAnyCourseToday) return WeekendMoodData.NONE
            return WeekendMoodData.REST
        }
        // 周五：明天必然是周六或周日（星期跨月跨年连续），只看明天是不是补班。
        if (dayOfWeek == 5) {
            if (isAdjustedWorkdayTomorrow || hasRemainingCourseToday) return WeekendMoodData.NONE
            return WeekendMoodData.AHEAD
        }
        return WeekendMoodData.NONE
    }
}
