package com.mutx163.qingyu

import android.content.Context
import com.mutx163.qingyu.app.TimetableRepository

/**
 * 把「日程变化 → 重排提醒」接起来。
 *
 * ## 链路
 *
 * `ScheduleItemService`（增 / 改 / 删）→ `TimetableRepository.syncExamReminders()`
 * → 本协调器安装的纯 Kotlin 回调 → [ScheduleReminderScheduler.reconcile]。
 *
 * ## 为什么要单独一层
 *
 * 仓储在 `app/` 包，必须保持纯 Kotlin（所有泳道的 L0 单测共用）；调度器用到
 * AlarmManager / Notification，只能待在 Android 侧。回调是两边唯一不互相依赖的接缝。
 *
 * ## 幂等
 *
 * 安装时立刻排一次（冷启动补排），之后每次日程变更再排一次；[ScheduleReminderScheduler.reconcile]
 * 本身整表重排、可重复调用。
 */
object ScheduleReminderCoordinator {

    fun install(context: Context, repository: TimetableRepository) {
        val appContext = context.applicationContext
        repository.onScheduleRemindersChanged = {
            ScheduleReminderScheduler.reconcile(appContext, repository.snapshot.scheduleItems)
        }
        // 冷启动补排：上次进程被杀时排好的闹钟仍在系统里，这里按当前数据整表对齐。
        ScheduleReminderScheduler.reconcile(appContext, repository.snapshot.scheduleItems)
    }
}
