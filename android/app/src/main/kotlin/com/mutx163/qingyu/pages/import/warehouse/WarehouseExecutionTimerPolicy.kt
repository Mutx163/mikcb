package com.mutx163.qingyu.pages.import.warehouse

/**
 * 教务导入「执行窗口预算」的纯逻辑（**无副作用、无时钟、无协程**，可在 JVM 单测里直测）。
 *
 * ## 为什么不是「从注入成功起 delay(30s)」
 *
 * 老实现是一条 `delay(30_000)` 到点就收尾。它把**用户读弹窗的时间**也计进了预算：
 * 页面弹一个「确认覆盖？」弹窗，用户低头回一条消息再回来点，30 秒早就过了，
 * 回来的路上对话框已经被 `cancelPendingDialog("timeout")` 掐掉——用户看着对话框消失，
 * 脚本的 Promise 拿到一个他从没给过的「取消」。
 *
 * 上游批准的模型是「**暂停即不可能超时**」：预算只累计没有用户交互的时间。
 *
 * ## 三条口径（改之前先读完）
 *
 * **执行窗口预算**：总预算 60 秒，只累计"没有用户交互"的时间。任何原生弹窗（showAlert/showSingleSelection/showPrompt）挂起期间计时暂停，用户应答后恢复——**暂停期不计入，且应答本身不重置预算**。不重置是刻意的：若每次应答都重开 60 秒，用户多次点击就等于没有上限。
 *
 * **不变量 ①**：进入超时收尾时 `pendingDialogCount` 必须为 0（否则是暂停逻辑失效的实现 bug，当场失败）。
 *
 * **不变量 ②**：超时分支不再调用 `cancelPendingDialog("timeout")`——在新模型下它不可达。
 *
 * 注意：加"宽限"会掩盖暂停逻辑失效。若要加，必须同时证明不变量 ① 仍然成立——否则宽限就成了失效的遮羞布。
 *
 * ## 状态机
 *
 * ```
 *             start(now)
 *   [未开始] ────────────► [计时中] ◄────────┐
 *                          │  ▲             │
 *                   pause  │  │ resume      │
 *                          ▼  │             │
 *                        [暂停中] ───────────┘
 *                          （reset() 任意态 → 未开始）
 * ```
 *
 * - 暂停时把当前这一段**账面化**进 [accumulatedMs]（暂停期间不再走表）；
 * - 恢复时只把段起点的游标挪到 `nowMs`，**不碰** [accumulatedMs] ——这就是「应答不重置预算」；
 * - [elapsedMs] 在暂停态返回 [accumulatedMs]（不含暂停段）。
 *
 * 时间基准由调用方给（`nowMs`），本类不认识 `System.currentTimeMillis()` /
 * `SystemClock.elapsedRealtime()`，也不需要真实等待——单测可以直接喂「10 分钟后」。
 */
class WarehouseExecutionTimerPolicy {

    /** 是否已经开始一次执行窗口（[start] 置真，[reset] 置假）。 */
    var started: Boolean = false
        private set

    /** 当前是否处于「用户交互挂起」的暂停态。 */
    var paused: Boolean = false
        private set

    /** 已经账面化的计时（毫秒）：只含「没有用户交互」的时间。 */
    var accumulatedMs: Long = 0L
        private set

    /** 当前这一段的起点；暂停态下无意义（已账面化）。 */
    private var segmentStartMs: Long = 0L

    /**
     * 开始/重开一次执行窗口：预算从 0 起算，不在暂停态。
     *
     * 重复调用等于重开（上一轮的累计直接丢掉）——「新一轮执行」本就该从满额开始。
     */
    fun start(nowMs: Long) {
        started = true
        paused = false
        accumulatedMs = 0L
        segmentStartMs = nowMs
    }

    /**
     * 进入用户交互挂起：把已经走过的一段账面化，之后 [elapsedMs] 不再增长。
     *
     * 未开始或已暂停时是 no-op（重复 pause 不许把同一段算两遍）。
     */
    fun pause(nowMs: Long) {
        if (!started || paused) return
        accumulatedMs += (nowMs - segmentStartMs).coerceAtLeast(0L)
        paused = true
    }

    /**
     * 用户应答 / 弹层被排空：恢复走表，**累计值原样保留**。
     *
     * 未开始或未暂停时是 no-op。这里刻意不做 `accumulatedMs = 0`：见类注释的
     * 「应答本身不重置预算」。
     */
    fun resume(nowMs: Long) {
        if (!started || !paused) return
        paused = false
        segmentStartMs = nowMs
    }

    /** 到 [nowMs] 为止**没有用户交互**的时间（暂停期为暂停那一刻的累计值）。 */
    fun elapsedMs(nowMs: Long): Long {
        if (!started) return 0L
        if (paused) return accumulatedMs
        return accumulatedMs + (nowMs - segmentStartMs).coerceAtLeast(0L)
    }

    /** 距预算上限还剩多少（不小于 0）；用于「剩余 ≤10s → 网络慢」这类纯展示判断。 */
    fun remainingMs(nowMs: Long, limitMs: Long): Long = (limitMs - elapsedMs(nowMs)).coerceAtLeast(0L)

    /**
     * 这一拍该不该收尾。
     *
     * **三个条件同时成立才为真**：已开始、不在暂停态、**没有挂起的原生弹窗**
     * （`pendingDialogCount == 0`）。最后一条是不变量 ① 的第一道闸：就算暂停接线坏了
     * （`paused` 没被置上），只要还有弹窗挂着就绝不放行——于是「用户读弹窗很久」
     * 在任何实现里都不会被超时掐掉。
     *
     * @param pendingDialogCount 当前挂起的原生弹窗数（宿主至多 1 个：脚本 await 串行发问）
     */
    fun shouldFire(nowMs: Long, limitMs: Long, pendingDialogCount: Int): Boolean =
        started &&
            !paused &&
            pendingDialogCount == 0 &&
            elapsedMs(nowMs) >= limitMs

    /** 复位到「未开始」（执行窗口收尾、页面换对象时调用；不影响任何账面语义之外的东西）。 */
    fun reset() {
        started = false
        paused = false
        accumulatedMs = 0L
        segmentStartMs = 0L
    }
}
