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
 * ## 超时保底（卡死路径）
 *
 * 异常路径由 [WidgetRefreshRunner] 的 `finally` 兜住；**卡死**（不抛异常、线程不返回）
 * 兜不住，会把后续所有轮次连同 `finish()` 一起拖死。所以每一轮都走
 * [WidgetRoundRunner]：block 跑在专用线程上，串行线程最多等 [ROUND_TIMEOUT_MILLIS]，
 * 超时后回调调用方给的 `onTimeout`（记日志 + 幂等 reschedule/finish），串行线程继续下一轮。
 *
 * 阈值 8s 的依据：`goAsync` 的广播必须在前台广播 10s 窗口内 `finish()`，留 2s 余量；
 * 正常一轮（每卡解析自己那份档案 + 构建 RemoteViews）实测虽是零，但按体量估算在百毫秒级，
 * 8s 只会命中真正的卡死，不会误杀慢设备。
 */
internal object WidgetRefreshSerial {

    /** 一轮刷新的超时上限：8s（前台广播 10s 窗口留 2s 余量）。 */
    const val ROUND_TIMEOUT_MILLIS = 8_000L

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "widget-refresh").apply { isDaemon = true }
    }

    private val rounds = WidgetRoundRunner(executor)

    /** 给挂起函数用（[WidgetRefreshWorker.doWork]）。 */
    val dispatcher: CoroutineDispatcher = executor.asCoroutineDispatcher()

    /** 给回调式入口用（receiver / host），不带超时（只用于必须立刻返回的轻活）。 */
    fun execute(block: () -> Unit) {
        executor.execute(block)
    }

    /**
     * 带超时的一轮刷新：超时后回调 [onTimeout] 并继续处理队列。
     *
     * [onTimeout] 与 block 的 `finally` 可能同时执行，调用方必须自己保证幂等
     * （同一个 reschedule / finish 只真跑一次）。
     */
    fun executeGuarded(
        timeoutMillis: Long = ROUND_TIMEOUT_MILLIS,
        onTimeout: () -> Unit,
        block: () -> Unit,
    ) {
        rounds.submit(timeoutMillis, onTimeout, block)
    }
}
