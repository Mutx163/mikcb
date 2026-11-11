package com.mutx163.qingyu

/**
 * 一次桌面小组件刷新的执行骨架（纯 Kotlin、零 Android 依赖，可 JVM 直测）。
 *
 * ## 为什么要有它
 *
 * 原先 [HomeWidgetRefreshReceiver.onReceive] 在主线程里顺序执行
 * 「updateAll → rescheduleRefresh」。`updateAll` 一旦抛异常（档案 JSON 半截、单张
 * RemoteViews 布局坏、OEM 裁剪的 API 缺失……），后面的 `rescheduleRefresh` 就不再执行
 * —— 精确闹钟没有重排，桌面卡片会**静默停更到进程重启**，用户只看到时间不动。
 *
 * 本类把这段顺序钉成契约：
 *
 * 1. [updateAll] 失败重试一次（同轮），仍失败只记日志 —— 桌面保留上一帧旧卡；
 * 2. 无论成功失败，[reschedule] 与 [finish] 都必须执行
 *    （`finish` = `PendingResult.finish()`，广播必须在系统时限内交还）；
 * 3. [reschedule] / [finish] 自己抛异常时吞掉并记日志，**不许再向外抛** ——
 *    否则线程池里的异常会丢掉 PendingResult 的 finish，等于同样的静默停更。
 *
 * Android 侧只负责注入三个 lambda（见 receiver），逻辑全在这里，测试也在这里钉。
 */
internal class WidgetRefreshRunner(
    private val updateAll: () -> Unit,
    private val reschedule: () -> Unit,
    private val finish: () -> Unit,
    private val onError: (stage: String, error: Throwable) -> Unit = { _, _ -> },
) {

    fun run() {
        try {
            attemptUpdate()
        } finally {
            safely(STAGE_RESCHEDULE) { reschedule() }
            safely(STAGE_FINISH) { finish() }
        }
    }

    /**
     * 刷新一次；失败再试一次。
     *
     * 只重试 [Exception]：`Error`（OOM / StackOverflow）再跑一遍只会把进程拖得更死，
     * 留一层 `finally` 保证调度照旧重排就够了。
     */
    private fun attemptUpdate() {
        try {
            updateAll()
        } catch (error: Exception) {
            onError(STAGE_UPDATE, error)
            try {
                updateAll()
            } catch (retryError: Exception) {
                onError(STAGE_RETRY, retryError)
            }
        }
    }

    private inline fun safely(stage: String, block: () -> Unit) {
        try {
            block()
        } catch (error: Throwable) {
            onError(stage, error)
        }
    }

    companion object {
        const val STAGE_UPDATE = "update"
        const val STAGE_RETRY = "retry"
        const val STAGE_RESCHEDULE = "reschedule"
        const val STAGE_FINISH = "finish"
    }
}
