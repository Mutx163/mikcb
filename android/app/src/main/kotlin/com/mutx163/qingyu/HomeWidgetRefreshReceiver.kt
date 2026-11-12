package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 桌面卡片的**定时刷新入口**（课程边界闹钟、开机、覆盖安装、改时间/时区）。
 *
 * ## 为什么整轮刷新搬到后台
 *
 * `onReceive` 跑在主线程。一轮刷新要「解析整份课表档案 + 逐张构建 RemoteViews」，
 * 7 个今日/考试 Provider + 3 个统计 Provider 各一张卡时，光 `timetable_profiles`
 * 就要全量解析约 14 次（`TodayWidgetSupport.readActiveProfileJson` 一次/卡，
 * `StatsWidgetSupport` 两次/卡，重排再一次）。叠在广播回调里，就是用户正在用 App
 * 时（同一个进程、同一条主线程）掉帧的直接来源。
 *
 * 所以这里用 `goAsync()` 把整段交给 [WidgetRefreshSerial] 的单线程串行器，
 * 与 [WidgetRefreshHost] / [WidgetRefreshWorker] 排队，避免并发 `rescheduleRefresh`
 * 互抢闹钟的 cancel/set。
 *
 * ## 为什么不是简单 try/catch
 *
 * 见 [WidgetRefreshRunner]：**异常路径也必须重排闹钟**。原先 `updateAll` 一抛，
 * `rescheduleRefresh` 就不执行，卡片会静默停更到进程重启 —— 那是个真 bug，不是性能问题。
 * 现在由 runner 的 `finally` 保证 `reschedule` + `finish` 一定执行，重试一次仍在 runner 里。
 */
class HomeWidgetRefreshReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                // 桌面 0 个小部件 ⇒ 这个刷新广播本不该来（闹钟已停 / BOOT 时没卡片），直接忽略。
                if (!WidgetRefreshGate.shouldSchedule(HomeWidgetStorage.widgetInstanceCounts(context))) {
                    return
                }
                val appContext = context.applicationContext
                // goAsync 把 PendingResult 交出来：主线程立刻返回，真正的刷新在
                // widget-refresh 线程上跑；整段必须在广播时限内 finish()（runner 的 finally 保证）。
                val pendingResult = goAsync()
                // 幂等壳：正常路径（runner 的 finally）与卡死路径（onTimeout）都会想跑
                // reschedule / finish，二者只许真跑一次。
                val rescheduled = AtomicBoolean(false)
                val finished = AtomicBoolean(false)
                fun rescheduleOnce() {
                    if (!rescheduled.compareAndSet(false, true)) return
                    try {
                        HomeWidgetStorage.rescheduleRefresh(appContext)
                    } catch (error: Throwable) {
                        Log.w(TAG, "widget refresh: reschedule failed", error)
                    }
                }

                fun finishOnce() {
                    if (!finished.compareAndSet(false, true)) return
                    try {
                        pendingResult.finish()
                    } catch (error: Throwable) {
                        Log.w(TAG, "widget refresh: finish failed", error)
                    }
                }

                val runner = WidgetRefreshRunner(
                    updateAll = {
                        // Don't overwrite Flutter-synced snapshot with native-computed data.
                        // TodayWidgetSupport.readSnapshot already falls back to native
                        // computation when no synced snapshot exists.
                        TodayWidgetSupport.updateAll(appContext)
                        StatsWidgetSupport.updateAll(appContext)
                    },
                    reschedule = { rescheduleOnce() },
                    finish = { finishOnce() },
                    onError = { stage, error ->
                        Log.w(TAG, "widget refresh failed at [$stage]; alarm reschedule still runs", error)
                    },
                )
                // 卡死保底：block 在专用线程上跑，串行线程最多等 ROUND_TIMEOUT_MILLIS；
                // 超时就由这里把重新排程与广播交还系统，然后继续下一轮。
                WidgetRefreshSerial.executeGuarded(
                    onTimeout = {
                        Log.w(
                            TAG,
                            "widget refresh stuck > ${WidgetRefreshSerial.ROUND_TIMEOUT_MILLIS}ms; forcing reschedule + finish",
                        )
                        rescheduleOnce()
                        finishOnce()
                    },
                    block = { runner.run() },
                )
            }
        }
    }

    companion object {
        private const val TAG = "HomeWidgetRefresh"
    }
}
