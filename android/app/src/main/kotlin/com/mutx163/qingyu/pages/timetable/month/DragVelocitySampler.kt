package com.mutx163.qingyu.pages.timetable.month

/**
 * 抬手速度估计：**按位移增量累加**，不用 `VelocityTracker`。
 *
 * ## 为什么不能用 `VelocityTracker`
 *
 * `VelocityTracker.addPosition(...)` 吃的是**指针在拖拽节点局部坐标系里的绝对位置**。
 * 月视图这块拖拽区（`MonthPanelDragArea`）的上边缘**本身在动**：日历收起时卡片变矮、
 * 面板从下方长上来，面板上沿跟着上移两三百 dp。于是局部 y 的变化 =
 * 「手指的位移」+「面板上沿的反向位移」，两者量级相当、方向相反。
 *
 * 2026-11-11 真机实测（bench 包，25 次面板拖拽）：
 *
 * * **20/25 次**算出来的速度方向与实际位移方向相反；
 * * 模长只有实际均速的 1/10 左右（例：56ms 内手指走了 −206dp，均速 −3645dp/s，
 *   算出来是 **+552dp/s**）。
 *
 * 后果比「数字难看」严重：`MonthPanelModel.settleTarget` 的判据是「明确的甩动方向
 * 压倒一切」，于是松手后按反方向吸附 —— 用户看到的是「上滑收起，一松手又弹回展开」、
 * 「下拉展开，一松手又缩回去」，也就是「上滑滑不上去、下拉拉不下来」。
 *
 * ## 口径
 *
 * 采样的是**每个指针事件的位移增量**（`position - previousPosition`，这个差值不受
 * 节点自身移动影响，因为两个位置是在同一时刻的同一坐标系里取的），时间取事件时间。
 * 速度 = 窗口内位移之和 ÷ 窗口时长，单位与传入的位移一致（传 px 得 px/s）。
 *
 * 手感取舍：
 * * 窗口默认 80ms —— 够压掉单帧抖动，又不至于把「起手慢、末尾快」的甩动平均掉；
 * * 至少留两个样本；样本不足或时间差 ≤ 0 时返回 0（交给「看行程」那条判据）；
 * * 乱序样本（时间倒退）直接丢弃，不参与拟合。
 */
class DragVelocitySampler(private val windowMs: Long = DEFAULT_WINDOW_MS) {

    private val times = ArrayDeque<Long>()
    private val deltas = ArrayDeque<Float>()
    private var lastTimeMs: Long = Long.MIN_VALUE

    /** 开始一次新手势：清空所有样本（必须在 `awaitFirstDown` 之后调用）。 */
    fun reset() {
        times.clear()
        deltas.clear()
        lastTimeMs = Long.MIN_VALUE
    }

    /**
     * 记一个采样点。
     *
     * @param timeMillis 事件时间（`PointerInputChange.uptimeMillis`），必须单调不减。
     * @param delta 相对上一个事件的位移增量（px 或 dp，本次手势内保持一致即可）。
     */
    fun add(timeMillis: Long, delta: Float) {
        if (timeMillis < lastTimeMs) return // 乱序 / 重复时间戳：丢掉，别污染拟合
        lastTimeMs = timeMillis
        if (times.isEmpty()) {
            // 第一个样本只当**时间锚点**：它前面没有区间，位移无处归属。
            times.addLast(timeMillis)
            return
        }
        times.addLast(timeMillis)
        deltas.addLast(delta)
        while (times.size > 2 && timeMillis - times.first() > windowMs) {
            times.removeFirst()
            deltas.removeFirst()
        }
    }

    /**
     * 窗口内平均速度（单位/秒）。
     *
     * @return 样本不足两个、或时间差为 0 时返回 0（调用方据此回落到「看行程」判据）。
     */
    fun velocityPerSecond(): Float {
        if (times.size < 2) return 0f
        val span = times.last() - times.first()
        if (span <= 0L) return 0f
        var sum = 0f
        for (delta in deltas) sum += delta
        return sum * 1000f / span
    }

    companion object {
        /** 滑窗长度（毫秒）。见类注释「手感取舍」。 */
        const val DEFAULT_WINDOW_MS = 80L
    }
}
