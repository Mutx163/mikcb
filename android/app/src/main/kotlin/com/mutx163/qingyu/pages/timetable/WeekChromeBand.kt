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

/**
 * 周网格「自动充满」节高的可用高基准（dp）：**只减下穿带高，不减带下沿缝**。
 *
 * 下穿那一截是视口多出来的、被玻璃盖住的部分，不属于可见网格区，必须减回去，
 * 否则每一节都会被撑高。带下沿缝（与 `DAY_VIEW_TOP_SEAM_DP` 同口径的 14dp）是
 * 排在留白里的额外空间，**不许**从这里再减一次 —— 减了每节就矮 14dp，一屏十几节
 * 累积下来底部长出一条空带。
 *
 * 纯函数（在 main 源集、无 Compose 依赖），供 JVM 单测钉住：`TimetableWeekBandSeamTest`。
 *
 * @param contentHeightDp 网格盒子高（dp）
 * @param bandUnderlapDp 下穿带高（dp，0 = 没下穿）
 */
fun weekGridSectionBasisDp(contentHeightDp: Float, bandUnderlapDp: Float): Float {
    val content = contentHeightDp.coerceAtLeast(0f)
    val underlap = bandUnderlapDp.coerceIn(0f, content)
    return content - underlap
}

