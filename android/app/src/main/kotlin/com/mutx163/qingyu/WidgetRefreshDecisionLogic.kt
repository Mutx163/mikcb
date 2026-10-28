package com.mutx163.qingyu

/**
 * 桌面小组件「要不要唤醒刷新」的**纯判据**——不碰 Android、不读盘，可 JVM 直测。
 *
 * ## 为什么单独抽出来
 *
 * 课表变更后唤醒桌面小组件（[WidgetRefreshBridge] → 宿主 `TodayWidgetSupport.updateAll`）
 * 原先没有可单测的判据：什么时候该刷、什么时候该跳过，全靠调用点口口相传。
 * 三条真正会踩坑的判据被抽到这里，每条都配一条人推期望值的单测：
 *
 * 1. **连续两次变更去重**（[shouldRefreshOnChange]）：一次编辑会触发多次等值通知
 *    （换档/落盘/换周各发一次），内容签名没变就不该重复刷，否则桌面卡片频繁重建、
 *    闪一下就重排。
 * 2. **跨天才刷新**（[isDayChanged]）：闹钟/周期 tick 在同一个自然日内反复响，
 *    除了「跨过午夜」这一次（让卡片离开昨日态），不应该每次都刷。
 * 3. **今天有课才刷新**（[hasClassToday]）：当天一门课都没有的 tick 没有可翻的状态，
 *    刷了也是同一张图，白白耗电。跨天除外——跨天必须刷，好让卡片换到新的一天。
 *
 * 三条判据在 [shouldWakeOnTimeTick] 里合成「定时 tick 是否唤醒」：跨天 **或** 今天有课。
 * 注意**内容变更**不走这条合成——真实内容变了就必须刷，去重只看签名，不看今天有没有课
 * （见 [shouldRefreshOnChange]）。
 */
internal object WidgetRefreshDecisionLogic {

    /**
     * 内容变更去重：只有内容签名真的变了才刷。
     *
     * [previousSignature] 为 null 表示「还没有基线」（首刷），此时只要有内容就刷。
     * 空签名（理论不该出现）视为无效，不刷——避免把「读不到内容」误判成「内容变了」。
     */
    fun shouldRefreshOnChange(previousSignature: String?, newSignature: String): Boolean {
        if (newSignature.isBlank()) return false
        return newSignature != previousSignature
    }

    /**
     * 是否跨天：上次刷新的日历日（epoch day）与今天不是同一天即为跨天。
     *
     * [lastRefreshEpochDay] 为 null 表示还没刷过（首刷），视为跨天（必须刷一次建立基线）。
     */
    fun isDayChanged(lastRefreshEpochDay: Long?, todayEpochDay: Long): Boolean {
        return lastRefreshEpochDay == null || lastRefreshEpochDay != todayEpochDay
    }

    /** 今天是否有课：今日课程数 > 0。负数按 0 处理（数据异常不该触发刷新）。 */
    fun hasClassToday(todayCourseCount: Int): Boolean = todayCourseCount > 0

    /**
     * 定时 tick（闹钟 / WorkManager 周期刷新）是否该唤醒刷新：**跨天 或 今天有课**。
     *
     * 同日无课 → 不刷（省电）；跨天 → 必刷（换日）；同日有课 → 刷（课程状态会随时间翻转，
     * 如「进行中/即将上课/已结束」）。
     */
    fun shouldWakeOnTimeTick(
        todayCourseCount: Int,
        lastRefreshEpochDay: Long?,
        todayEpochDay: Long,
    ): Boolean = isDayChanged(lastRefreshEpochDay, todayEpochDay) || hasClassToday(todayCourseCount)

    /**
     * 内容签名的稳定拼接：把各字段按固定顺序、固定分隔符连起来。
     *
     * 用不可见的分隔符 `\u001F`（Unit Separator）而不是逗号，是为了避免字段本身含逗号时
     * 两份不同的内容拼出同一个签名（例如 `["a,b"]` 与 `["a","b"]`）。各段 trim 掉首尾空白，
     * 防止无关的空格差异造成「假变更」→ 无效重刷。
     */
    fun buildChangeSignature(parts: List<String>): String =
        parts.joinToString(separator = SIGNATURE_SEPARATOR) { it.trim() }

    private const val SIGNATURE_SEPARATOR = "\u001F"
}
