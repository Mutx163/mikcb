package com.mutx163.qingyu.pages.timetable.day

/**
 * 日视图「短日纵向补白」的算术（纯函数；JVM 单测：`DayViewScrollTailTest`）。
 *
 * ## 为什么需要它
 *
 * 列表的纵向可滚范围 = 内容高 − 视口高。这条件在真实课表里经常落空：
 *
 * - **只有一节课 / 没课（且有待办带）**：内容比视口矮 ⇒ 范围是 0，上下滑一动不动，
 *   读起来就是「日视图有时候上下滑完全没反应」；
 * - **内容只比视口高一点**：范围只有几十 dp，一次用力的上滑就见底 ——
 *   此后上滑当然没反应、只能下滑；下滑回顶部又把那点余量「攒」回来，于是又能上滑。
 *   用户报的「不能上滑、只能下滑，下滑以后又可以上滑」就是这一段。
 *
 * 两种症状同一个病根：**短内容没有任何可滚距离**。补丁的做法是在列表末尾挂一条
 * 空白（[KEY]），把可滚范围的**下限**抬到视口的一小块（[MIN_RANGE_FRACTION]）：
 * 短日因此有稳定、可预期的响应，长日算出来是 0，一点不受影响。
 *
 * 为什么补到「下限」而不是「一口气补一整屏」：补一整屏会让长日也多出一大段空白，
 * 而真正需要补的只有「本来就滚不动」的那几天。
 */
internal object DayViewScrollTail {

    /**
     * 补白 item 的 key。
     *
     * `visibleItemsInfo` / `totalItemsCount` 都要按它把补白自己摘出去：
     * 摘不干净就会把「补白高度」当成内容高度，越补越长。
     */
    const val KEY: String = "day-scroll-tail"

    /**
     * 补白之后的可滚范围下限（视口高度的比例）。
     *
     * 取 1/5 屏：一次轻扫（约 1/4 屏）就能走完、边界清清楚楚，又不会在
     * 「一节课」那天空出一大块。改这个数要同步 [DayViewScrollTailTest]。
     */
    const val MIN_RANGE_FRACTION: Float = 0.2f

    /**
     * 读到**真实内容**（不含补白）的总高，单位 px；读不到时返回 `null`。
     *
     * 只有两个条件同时成立才可信：
     *
     * 1. **列表停在顶部**（`firstVisibleItemIndex == 0`）。滚下去以后，最后一条的
     *    `offset + size` 只是「贴着视口底边」的位置，不是内容真高 —— 照着算会给
     *    长列表凭空补一大段白，而且每滚一次补一段。
     * 2. **最后一条真实条目已经露出来**。它没露出来，说明内容本来就比一屏长，
     *    不需要补。
     *
     * 返回 `null` 时调用方必须**保持上一次的补白**、不能归零：补白本身参与内容
     * 长度，滚到一半把它撤掉，滚动位置会被当场夹回去，页面跳一下。
     *
     * @param lastRealVisibleIndex 最后一条「非补白」条目的 index（没有则 `null`）。
     * @param lastRealVisibleBottomPx 该条目的 `offset + size`（没有则任意值，不会用）。
     */
    fun naturalContentPx(
        firstVisibleItemIndex: Int,
        totalItemsCount: Int,
        lastRealVisibleIndex: Int?,
        lastRealVisibleBottomPx: Int,
    ): Int? {
        if (firstVisibleItemIndex != 0) return null
        // 补白 item 常驻（高度 0 时也在树里），所以真实末项 = 总数 − 2。
        val lastRealIndex = totalItemsCount - 2
        if (lastRealIndex < 1) return null
        if (lastRealVisibleIndex != lastRealIndex) return null
        return lastRealVisibleBottomPx
    }

    /**
     * 补白高度（px）：把可滚范围抬到视口的 [MIN_RANGE_FRACTION]。
     *
     * 内容已经够长（范围 ≥ 下限）⇒ 返回 0，等价于没有这条补白。
     *
     * @param contentHeightPx 真实内容 + 列表自带的底部避让（避让本来就算在可滚范围里）。
     */
    fun tailHeightPx(viewportHeightPx: Int, contentHeightPx: Int): Int {
        if (viewportHeightPx <= 0 || contentHeightPx <= 0) return 0
        val minRangePx = viewportHeightPx * MIN_RANGE_FRACTION
        val currentRangePx = contentHeightPx - viewportHeightPx
        return (minRangePx - currentRangePx).toInt().coerceAtLeast(0)
    }
}
