package com.mutx163.qingyu


/** 唤醒小组件刷新的原因，随 [WidgetRefreshRequest] 一起交给宿主，便于日志与去重诊断。 */
enum class WidgetRefreshReason {
    /** 课表内容真的变了（新增/编辑/删除/换档/换周），签名与上次不同。 */
    TIMETABLE_CHANGED,

    /** 定时 tick 撞上跨天：让卡片离开昨日态、换到新的一天。 */
    TIME_TICK_DAY_CHANGED,

    /** 定时 tick 今天有课：刷新课程状态（进行中/即将上课/已结束）。 */
    TIME_TICK_CLASS_TODAY,
}

/**
 * 一次刷新请求。[contentSignature] 是触发时的内容签名（定时 tick 时为当前签名），
 * 仅供宿主打日志/排查「为什么刷/为什么没刷」，不参与决策。
 */
data class WidgetRefreshRequest(
    val reason: WidgetRefreshReason,
    val contentSignature: String?,
)

/**
 * 「课表变更事件 → 刷新判据」的纯桥接层：**不碰任何 Android / 盘**，可 JVM 直测。
 *
 * ## 分工
 *
 * - 本类只负责**判断要不要刷、为什么刷**（判据在 [WidgetRefreshDecisionLogic]），
 *   真正把「刷」落成 `TodayWidgetSupport.updateAll(context)` + `HomeWidgetStorage.rescheduleRefresh(context)`
 *   是宿主在构造时传入的 [onRefresh] 回调——那是 Android 胶水，属宿主/壳侧接线，不在本类。
 * - 因此本类能脱离 `TimetableRepository` 单独单测：只要塞三个取值 lambda + 一个 sink 即可。
 *
 * ## 两路刺激，判据不同（这是本类存在的意义）
 *
 * - **内容变更** [onTimetableChanged]：**只去重，不看今天有没有课**。内容真变了就必须刷，
 *   哪怕今天没课（变更可能影响明天/本周显示）。
 * - **定时 tick** [onTimeTick]：**跨天 或 今天有课**才刷（省电），见
 *   [WidgetRefreshDecisionLogic.shouldWakeOnTimeTick]。
 *
 * ## 基线（[seedBaseline]）
 *
 * 订阅建立后**必须先**调一次 [seedBaseline] 登记当前签名与当天，否则首个等值通知会被当成
 * 「内容变了」而多刷一次。典型接线：
 *
 * ```
 * val bridge = WidgetRefreshBridge(签名, 今日课程数, 今日epochDay) { req -> // updateAll + reschedule }
 * bridge.seedBaseline()
 * val sub = repository.observe { bridge.onTimetableChanged() }
 * // ...
 * sub.close()
 * ```
 */
class WidgetRefreshBridge(
    private val contentSignature: () -> String,
    private val todayCourseCount: () -> Int,
    private val todayEpochDay: () -> Long,
    private val onRefresh: (WidgetRefreshRequest) -> Unit,
) {
    private var lastSignature: String? = null
    private var lastRefreshEpochDay: Long? = null

    /** 登记基线：把「订阅这一刻」的签名与当天记为已消费，避免订阅瞬间空刷一次。 */
    fun seedBaseline() {
        lastSignature = contentSignature()
        lastRefreshEpochDay = todayEpochDay()
    }

    /**
     * 课表发生一次写入（新增/编辑/删除/换档/换周）时调用。
     * 内容签名与上次不同才唤起刷新；连续两次等值变更只刷第一次。
     */
    fun onTimetableChanged() {
        val signature = contentSignature()
        if (!WidgetRefreshDecisionLogic.shouldRefreshOnChange(lastSignature, signature)) return
        lastSignature = signature
        lastRefreshEpochDay = todayEpochDay()
        onRefresh(WidgetRefreshRequest(WidgetRefreshReason.TIMETABLE_CHANGED, signature))
    }

    /**
     * 定时 tick（闹钟响 / WorkManager 周期刷新）时调用。
     * 跨天 或 今天有课才刷；同日无课直接跳过。
     */
    fun onTimeTick() {
        val count = todayCourseCount()
        val today = todayEpochDay()
        if (!WidgetRefreshDecisionLogic.shouldWakeOnTimeTick(count, lastRefreshEpochDay, today)) return
        val reason = if (WidgetRefreshDecisionLogic.isDayChanged(lastRefreshEpochDay, today)) {
            WidgetRefreshReason.TIME_TICK_DAY_CHANGED
        } else {
            WidgetRefreshReason.TIME_TICK_CLASS_TODAY
        }
        lastRefreshEpochDay = today
        onRefresh(WidgetRefreshRequest(reason, lastSignature))
    }
}
