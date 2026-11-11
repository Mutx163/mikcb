package com.mutx163.qingyu.statistics

/**
 * 「最长连续上课天数」的**唯一算法实现**（P1-12，2026-11-11）。
 *
 * ## 为什么单独一个文件
 *
 * 这条算法此前有两份逐行相同的副本：统计页走 `StatisticsService.calculateLongestStreak`
 * （`List<CourseStub>`），桌面统计小组件走根包的 `WidgetStatsLogic.calculateLongestStreak`
 * （`List<WidgetSourceCourse>`）。两份“镜像”已经各自演化出小差异（widget 侧多一条
 * `day !in 1..7` 守卫），同一份课表可能给出两个数。现在算法本体只留在这里，两侧只负责
 * 把各自的课程模型折成**同一种输入**：[hasClassOnDay]。
 *
 * ## 输入契约为什么不直接用课程 DTO
 *
 * 审计建议「widget 侧适配成 `CourseStub` 再调 `StatisticsService`」，这里**故意不那样做**：
 * `WidgetSourceCourse` 没有 `teacher`、`courseNature` 是 `String` 而 `CourseStub` 要枚举，
 * 硬转要造 `teacher = ""` 这种假字段，等于把两个域用假数据绑在一起。这条算法真正需要的
 * 信息只有一个「这一周哪几天有课」的布尔向量，把契约缩到它才是真去重。
 *
 * ## 口径（与 Dart `statistics_service.dart` `_calculateLongestStreak` 一致）
 *
 * - 只看**本周排课覆盖了星期几**（由调用方按 `countActiveWeeks(...) > 0` 折出向量）；
 * - 向量**展开两轮**（14 天）单趟扫描，周日→周一自然接上，所以跨周边界能连起来；
 * - 上限 7 天（一整周排满仍算 7）。
 */
internal object LongestStreakLogic {

    const val DAYS_IN_WEEK = 7

    /**
     * @param hasClassOnDay 长度为 [DAYS_IN_WEEK] 的布尔向量，下标 0 = 周一 … 6 = 周日
     * @return 最长连续上课天数，0..7
     */
    fun longestStreak(hasClassOnDay: BooleanArray): Int {
        require(hasClassOnDay.size == DAYS_IN_WEEK) {
            // 开发者向异常消息（不上屏），按 CJK 棘轮用英文。
            "hasClassOnDay must be a $DAYS_IN_WEEK-day boolean vector (got ${hasClassOnDay.size})"
        }
        val expanded = hasClassOnDay + hasClassOnDay
        var maxStreak = 0
        var currentStreak = 0
        for (hasClass in expanded) {
            if (hasClass) {
                currentStreak++
                if (currentStreak > maxStreak) maxStreak = currentStreak
            } else {
                currentStreak = 0
            }
        }
        return maxStreak.coerceIn(0, DAYS_IN_WEEK)
    }
}
