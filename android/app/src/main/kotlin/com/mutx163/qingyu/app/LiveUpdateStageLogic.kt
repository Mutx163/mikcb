package com.mutx163.qingyu.app

/**
 * 「实时活动当前阶段」的**唯一算法实现**（P1-13，2026-11-11）。
 *
 * ## 背景：这条判定原先有三份
 *
 * - `LiveUpdateScheduler.liveSchedulerResolveStage`（纯函数，算法本体）与其
 *   `LiveUpdateScheduler.resolveStage` 适配层——这一对内部一致；
 * - `LiveUpdateService.resolveStage`——**独立实现**，与本体有两处语义分叉：
 *   1. 它没有「连堂课屏蔽点」概念：调度侧会把课前窗口起点抬到上一节课结束后的
 *      `blockedUntil`，服务侧完全不知道 ⇒ 连堂课场景两侧可能给出不同阶段；
 *   2. 课前窗口 `lead == 0` 的含义不同：服务把 0 当「调用方没给窗口，信任 start」，
 *      本体把 0 当「窗口宽 0，课前阶段不出现」。
 *
 * 现在算法只留在这里，两处调用方都是薄转调。**两处分叉没有悄悄选边**，而是被
 * 做成签名里的显式参数：
 *
 * - [blockedUntilMillis]：连堂课屏蔽点。调度侧传实际值；服务侧传 `null`
 *   （服务本就没有这个概念——**行为差异保留**，是否让服务也吃屏蔽点属于
 *   用户可见的阶段变化，留给后续真机专项，不在本笔）。
 * - [beforeClassLeadMillis]：课前窗口宽度。`null` = 没给窗口（信任 start），
 *   `0` = 窗口宽 0（课前阶段不出现）。调度侧传 `liveShowBeforeClassMinutes * 60_000`，
 *   服务侧传 `beforeClassLeadMillis.takeIf { it > 0 }`。
 *
 * 阶段字符串对外契约不变：`beforeClass` / `duringClassStatusBar` / `beforeEnd` /
 * `duringClass`，`null` 表示当前不上岛。
 *
 * ## 调用方
 *
 * - `LiveUpdateScheduler.liveSchedulerResolveStage`（保留原签名，转调本实现）；
 * - `LiveUpdateService.resolveStage`（转调本实现）。
 */
internal object LiveUpdateStageLogic {

    const val BEFORE_CLASS = "beforeClass"
    const val DURING_CLASS_STATUS_BAR = "duringClassStatusBar"
    const val BEFORE_END = "beforeEnd"
    const val DURING_CLASS = "duringClass"

    /**
     * @param blockedUntilMillis 连堂课屏蔽点：课前窗口起点不得早于它；`null` = 无屏蔽
     * @param beforeClassLeadMillis 课前窗口宽度；`null` = 调用方未提供窗口（信任 start 时刻）
     */
    fun resolveStage(
        nowMillis: Long,
        startAtMillis: Long,
        endAtMillis: Long,
        blockedUntilMillis: Long? = null,
        beforeClassLeadMillis: Long? = null,
        liveClassReminderStartMinutes: Int = 0,
        endReminderLeadMillis: Long = 600_000L,
        enableBeforeClass: Boolean = true,
        enableDuringClass: Boolean = true,
        enableBeforeEnd: Boolean = true,
        promoteDuringClass: Boolean = true,
        showDuringClassNotification: Boolean = true,
    ): String? {
        if (nowMillis >= endAtMillis) {
            return null
        }
        if (beforeClassLeadMillis != null) {
            // 窗口起点 = max(开课前 lead, 上一节课结束后的屏蔽点)。
            val aheadTime = maxOf(
                startAtMillis - beforeClassLeadMillis,
                blockedUntilMillis ?: Long.MIN_VALUE,
            )
            if (nowMillis < aheadTime) {
                return null
            }
        } else if (blockedUntilMillis != null && nowMillis < blockedUntilMillis) {
            // 没有课前窗口时，屏蔽点仍是一道硬门槛。
            return null
        }
        if (nowMillis < startAtMillis) {
            return if (enableBeforeClass) BEFORE_CLASS else null
        }

        val reminderStartMillis = if (liveClassReminderStartMinutes == 0) {
            startAtMillis
        } else {
            maxOf(startAtMillis, endAtMillis - liveClassReminderStartMinutes * 60_000L)
        }
        if (liveClassReminderStartMinutes > 0 && nowMillis < reminderStartMillis) {
            // 「课中提醒」窗口之前的课中阶段只上状态栏（不上岛）。
            return if (enableDuringClass && showDuringClassNotification) {
                DURING_CLASS_STATUS_BAR
            } else {
                null
            }
        }
        if (liveClassReminderStartMinutes > 0) {
            return if (enableBeforeEnd) {
                BEFORE_END
            } else if (canDisplayDuring(enableDuringClass, promoteDuringClass, showDuringClassNotification)) {
                DURING_CLASS
            } else {
                null
            }
        }

        val endReminderStart = maxOf(startAtMillis, endAtMillis - endReminderLeadMillis)
        if (nowMillis >= endReminderStart) {
            return if (enableBeforeEnd) {
                BEFORE_END
            } else if (canDisplayDuring(enableDuringClass, promoteDuringClass, showDuringClassNotification)) {
                DURING_CLASS
            } else {
                null
            }
        }
        return if (canDisplayDuring(enableDuringClass, promoteDuringClass, showDuringClassNotification)) {
            DURING_CLASS
        } else {
            null
        }
    }

    /** 下课提醒窗口之前的课中阶段能否展示（状态栏通知或上岛二者其一）。 */
    fun canDisplayDuring(
        enableDuringClass: Boolean,
        promoteDuringClass: Boolean,
        showDuringClassNotification: Boolean,
    ): Boolean = enableDuringClass && (promoteDuringClass || showDuringClassNotification)
}
