package com.mutx163.qingyu.pages.timetable

/**
 * 首页顶栏玻璃带当前该显示哪一页（0 起）。
 *
 * 2026-11-01 起，周视图的星期栏从「每一页 pager 内部」提到了共享玻璃带上，
 * 因此它不再跟手指横向滑动；同时也不能直接读 `pagerState.currentPage` ——
 * 那个值在滑过半页时就跳，标题与日期会在拖动过程中来回改字（观感像在抖）。
 *
 * 口径：
 * - 手指还按着、或松手后的吸附动画还没结束（[isScrollInProgress] = true）
 *   ⇒ 保持 [previousPage]，也就是上一次落定时的页；
 * - 完全停稳（false）⇒ 跟 [currentPage]，即用户最终落在的那一页。
 *
 * 这是纯函数（在 main 源集、无 Compose 依赖），供 JVM 单测钉住；
 * 界面层只负责把它接到 `snapshotFlow` 上。
 *
 * @param currentPage pager 当前页（滑动中 = 离吸附位最近的那页）。
 * @param isScrollInProgress pager 是否还在滚动 / 吸附。
 * @param previousPage 上一次落定后显示的页；首帧传 `currentPage`。
 */
fun chromeDisplayedPage(
    currentPage: Int,
    isScrollInProgress: Boolean,
    previousPage: Int,
): Int = if (isScrollInProgress) previousPage else currentPage
