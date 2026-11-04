package com.mutx163.qingyu.pages.timetable

/**
 * 外部周次 → 周 pager 目标页（Dart `WeekPagerController.syncWeekPageWithProvider` 的判据部分，
 * `lib/controllers/week_pager_controller.dart:206-274`）。
 *
 * ## 为什么需要
 *
 * 页面把 `initialWeek` 只喂给 `rememberPagerState` 的**初值**：之后 provider 的
 * `currentWeek` 变了（换课表档、改学期起点/总周数、跨零点自动进周），pager 仍停在旧周，
 * 用户看到「换了档但还停在上一档那一周」。Dart 在 build 里每帧收敛一次，
 * Compose 侧用 `LaunchedEffect(initialWeek, pageCount)` 做同一件事。
 *
 * 三条判据与 Dart 同义：
 * - 手势/动画进行中**不抢页**（Dart `_hasPendingLocalWeekTransition`）；
 * - 目标页 = clamp 到 `1..pageCount` 的周次减一；
 * - 已在目标页则不重复跳（Dart `lastObservedWeekPage == targetPage` 提前返回）。
 *
 * 返回 `null` = 本次无需同步（调用方直接跳过）。
 */
object WeekPagerSync {

    fun targetPage(
        externalWeek: Int,
        pageCount: Int,
        currentPage: Int,
        isScrollInProgress: Boolean,
    ): Int? {
        if (isScrollInProgress) return null
        val total = pageCount.coerceAtLeast(1)
        val page = (externalWeek - 1).coerceIn(0, total - 1)
        return page.takeIf { it != currentPage }
    }
}
