package com.mutx163.qingyu

/**
 * 同一次系统广播被多个组件各收一遍时的**去重**（纯逻辑，可 JVM 直测）。
 *
 * 用户报的耗电问题里：一次 `APPWIDGET_UPDATE` 广播会被 10 个 `AppWidgetProvider`
 * 各收一遍，若每个都 `rescheduleRefresh` / `updateAll` 就是 10 倍放大。
 * 这里用短窗口只放行第一个，其余同批组件直接跳过。
 *
 * ## 200ms 是经验值（如实标注，别当精确契约）
 *
 * 正常一次系统广播的 10 个组件在几十毫秒内到达，200ms 足够合并；若某 ROM 把它拆成
 * 间隔 >200ms 的多次派发，会各算一次（最多放大到 2 次，不是 10 次）。
 *
 * ## force 判据是「集合内容」，不是数量
 *
 * 系统加卡时通常发**全量 ids**（`size < allIds.size` 判不出来），所以这里记住上一次广播的
 * 「全部 widget id 并集」：本次出现**上次没有的新 id** ⇒ 强制重排（加卡必然触发）；
 * 纯重复广播才走 200ms 窗口。`onEnabled`（首次启用）另走显式 `force`。
 */
internal class BroadcastDedupe(private val windowMillis: Long) {

    private var lastHandledAt: Long? = null
    private var lastIds: Set<Int> = emptySet()

    /**
     * @param nowMillis 单调时钟（调用方用 `SystemClock.elapsedRealtime()`）
     * @param currentIds 本次「全部 widget id 并集」；同批 10 个 Provider 应传同一份
     * @param force 显式强制（`onEnabled` 首次启用等必达来源）
     * @return 本次是否应真正处理（同批内只有第一个返回 true；出现新 id 或 `force` 时恒 true）
     */
    fun shouldHandle(
        nowMillis: Long,
        currentIds: Set<Int> = emptySet(),
        force: Boolean = false,
    ): Boolean {
        val hasNewId = currentIds.any { it !in lastIds }
        lastIds = currentIds
        if (force || hasNewId) {
            lastHandledAt = nowMillis
            return true
        }
        val last = lastHandledAt
        if (last != null && nowMillis - last < windowMillis) return false
        lastHandledAt = nowMillis
        return true
    }
}
