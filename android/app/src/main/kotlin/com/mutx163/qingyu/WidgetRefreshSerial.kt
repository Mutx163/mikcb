package com.mutx163.qingyu

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.asCoroutineDispatcher
import java.util.concurrent.Executors

/**
 * 所有「桌面小组件刷新」入口共用的**单线程串行器**。
 *
 * ## 为什么必须串行
 *
 * 三条入口做的是同一件事（`updateAll` + `rescheduleRefresh`）：
 * 1. 广播/闹钟入口 [HomeWidgetRefreshReceiver]（现在的 goAsync 后台段）；
 * 2. App 内改完课表后的 [WidgetRefreshHost]（250ms 去抖后）；
 * 3. 15 分钟兜底的 [WidgetRefreshWorker]。
 *
 * `HomeWidgetStorage.rescheduleRefresh` 内部是「cancel 旧闹钟 → 算下一个刷新点 → set 新闹钟」。
 * 两条线程并发跑时，A 的 cancel 可能撤掉 B 刚 set 的闹钟，或两个 set 先后覆盖成更晚的时间点
 * —— 结果是**漏一次课堂边界刷新**，而漏刷一次在桌面上就是「卡还在上节课」。
 *
 * 刷新本身不是高频操作（用户编辑、课堂边界、15 分钟兜底），串行不会有吞吐损失，
 * 却能把这个竞态直接消掉。
 *
 * 线程名固定为 `widget-refresh`，`logcat` 里一眼认得出是谁在刷卡片。
 */
internal object WidgetRefreshSerial {

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "widget-refresh").apply { isDaemon = true }
    }

    /** 给挂起函数用（[WidgetRefreshWorker.doWork]）。 */
    val dispatcher: CoroutineDispatcher = executor.asCoroutineDispatcher()

    /** 给回调式入口用（receiver / host）。 */
    fun execute(block: () -> Unit) {
        executor.execute(block)
    }
}
