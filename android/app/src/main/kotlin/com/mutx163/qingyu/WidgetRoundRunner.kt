package com.mutx163.qingyu

import java.util.concurrent.Executor

/**
 * 「一轮刷新最多等多久」的执行器（纯 JVM，可 L0 直测）。
 *
 * ## 为什么需要它
 *
 * 原来的串行器是一句话：任务丢进单线程队列，前一轮跑完才轮到下一轮。**但如果某一轮
 * 不是抛异常、而是卡死**（binder 卡住、SharedPreferences 锁、OEM 裁剪的 API 阻塞），
 * 那条线程永远不返回，后面所有轮次（含 15 分钟兜底）就永远排队——`finish()` 也交不回去，
 * 广播被系统当 ANR。异常路径在 `WidgetRefreshRunner` 里已经修好，这里是**卡死路径**的保底。
 *
 * ## 做法（不改串行结构，只加超时）
 *
 * 串行线程不再直接跑 `block`，而是**起一条专用线程跑 block、自己最多等 timeoutMillis**：
 * - block 正常结束 ⇒ 串行线程立刻继续下一轮（与原来一致，只多一次线程切换）；
 * - block 卡死 ⇒ 串行线程在 timeout 后调用 [onTimeout]（调用方负责记日志 + 幂等的
 *   reschedule/finish），然后继续处理队列里的下一轮。
 *
 * ## 代价（如实）
 *
 * 被放弃的那条线程杀不掉，它会一直挂着（zombie）。真出现卡死时，可能出现「上一轮
 * zombie 还在跑、下一轮已经开始」的短暂并发——这是用一致性换可用性的取舍：
 * 宁可多一次并发，也不要整个刷新链永久停死。正常路径没有这个代价。
 */
internal class WidgetRoundRunner(
    private val executor: Executor,
) {

    /**
     * 提交一轮。串行线程最多等 [timeoutMillis]；超时判定为「卡死」并回调 [onTimeout]。
     *
     * 注意：`onTimeout` 可能和 block 里的 finally **同时**执行，调用方必须自己做幂等
     * （同一个 reschedule / finish 只能真跑一次）。
     */
    fun submit(
        timeoutMillis: Long,
        onTimeout: () -> Unit,
        block: () -> Unit,
    ) {
        executor.execute {
            val round = Thread(block, ROUND_THREAD_NAME)
            round.isDaemon = true
            round.start()
            round.join(timeoutMillis)
            if (round.isAlive) {
                onTimeout()
            }
        }
    }

    companion object {
        const val ROUND_THREAD_NAME = "widget-refresh-round"
    }
}
