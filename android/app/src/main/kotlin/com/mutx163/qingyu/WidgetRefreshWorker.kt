package com.mutx163.qingyu

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * WorkManager-based backup for widget refresh.
 *
 * On MIUI/HyperOS, enabling an accessibility service can prevent
 * AlarmManager.setExactAndAllowWhileIdle() from firing, which breaks
 * the primary widget refresh mechanism (HomeWidgetRefreshReceiver).
 *
 * This worker runs every 15 minutes (WorkManager minimum) and triggers
 * a widget update + reschedule, ensuring the widget stays fresh even
 * when AlarmManager alarms are suppressed.
 */
class WidgetRefreshWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        // 一次取快照，后面判零实例与重排都消费它（不再各自遍历 10 类）。
        val widgetIds = HomeWidgetStorage.collectWidgetIds(applicationContext)
        // 桌面没有任何小部件实例 ⇒ 不为不存在的卡片空跑（用户报的耗电问题）。
        if (!WidgetRefreshGate.shouldSchedule(HomeWidgetStorage.widgetInstanceCounts(widgetIds))) {
            // 先取消自己再退出：periodic work 不会因为一次 return 就消失；0 卡片时
            // 这个任务应自我取消（BOOT 后系统自恢复的下一跑也会在这里自取消）。
            cancel(applicationContext)
            return Result.success()
        }
        return try {
            TodayWidgetSupport.updateAll(applicationContext)
            StatsWidgetSupport.updateAll(applicationContext)
            HomeWidgetStorage.rescheduleRefresh(applicationContext, widgetIds)
            Result.success()
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_WIDGET_REFRESH_WORKER_FAILED, e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "WidgetRefreshWorker"
        private const val WORK_NAME = "home_widget_periodic_refresh"

        /**
         * Enqueue a periodic widget refresh.
         *
         * 用 `KEEP` 而不是 `UPDATE`：UPDATE 会把 15 分钟周期重置成「最后一次调用后 15 分钟」，
         * 高频 `ensureScheduled`（每次广播 / 每次重排）会让 Worker 被无限推迟。
         * 代价：忽略新 request 的配置变更（当前 request 没有额外配置，暂无影响）。
         * ⚠️ 「cancel 之后 KEEP 能否重新入队」未在本机验证，标 L2 / 真机确认。
         */
        fun ensureScheduled(context: Context) {
            ensureScheduled(context, HomeWidgetStorage.collectWidgetIds(context))
        }

        /** 消费调用方已经取好的 id 快照（一次广播只该取一次）。 */
        internal fun ensureScheduled(
            context: Context,
            widgetIds: Map<Class<out BaseQingyuWidgetProvider>, IntArray>,
        ) {
            // 零实例不排周期任务：否则桌面上 0 个小部件仍会每 15 分钟空跑一次
            //（用户报的耗电问题里，WorkManager 兜底绕过了闹钟的零实例门）。
            if (!WidgetRefreshGate.shouldSchedule(HomeWidgetStorage.widgetInstanceCounts(widgetIds))) {
                cancel(context)
                return
            }
            val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(
                15, TimeUnit.MINUTES,
            ).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                // KEEP 而非 UPDATE：重复 ensureScheduled（每次广播/每次重排）不该把 15 分钟
                // 周期重置成「最后一次调用后 15 分钟」，否则高频刷新会无限推迟 Worker。
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        /**
         * Cancel the periodic refresh (e.g. when widget is removed).
         */
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
