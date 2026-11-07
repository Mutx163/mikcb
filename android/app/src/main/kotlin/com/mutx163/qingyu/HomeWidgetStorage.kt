package com.mutx163.qingyu

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object HomeWidgetStorage {
    private const val PREFS_NAME = "home_widget_prefs"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"
    private const val KEY_REFRESH_TIMES_JSON = "refresh_times_json"
    private const val KEY_WIDGET_SNAPSHOT_PREFIX = "widget_snapshot_"
    private const val REQUEST_CODE_REFRESH = 4201

    fun syncSnapshot(context: Context, snapshot: Map<String, Any?>) {
        val payload = JSONObject(snapshot).toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, payload)
            .apply()
        TodayWidgetSupport.updateAll(context)
        // 调度（含 WorkManager 兜底）统一由 rescheduleRefresh 收口：那里一次判定实例数，
        // 非零时闹钟+Worker 一起排，零实例时一起撤 —— 避免两处各自判零造成不一致。
        rescheduleRefresh(context)
    }

    fun clearSnapshot(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        // 语义 = **「当前算不出快照时撤过期快照」**（Dart timetable_live_activity_service.dart:1195-1202），
        // 不是清数据/登出：只清全局快照 + 刷新点。绑定（widget_binding_*，用户资产）与
        // 每卡专属快照（widget_snapshot_*，另一套）一个不碰。
        val editor = prefs.edit()
        WidgetSnapshotDataKeys.keysToClear(prefs.all.keys).forEach { editor.remove(it) }
        editor.apply()
        // 清完 updateAll：读快照优先实时计算（TodayWidgetSupport.kt:184-203），实时失败时
        // **回落到未清的专属快照、绑定卡按绑定 profile 渲染**（不是空态）—— 如实记录。
        TodayWidgetSupport.updateAll(context)
        rescheduleRefresh(context)
    }

    fun scheduleRefresh(context: Context, triggerAtMillis: List<Long>) {
        val payload = JSONArray(triggerAtMillis).toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_REFRESH_TIMES_JSON, payload)
            .apply()
        rescheduleRefresh(context)
    }

    fun getSnapshotJson(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT_JSON, null)
    }

    /**
     * 按 appWidgetId 存一张绑定卡片的专属快照（Flutter 为绑定课表单独生成）。
     * 未绑定的卡片不写这份，渲染继续走全局快照/实时计算。
     */
    fun syncWidgetSnapshot(context: Context, appWidgetId: Int, snapshot: Map<String, Any?>) {
        val payload = JSONObject(snapshot).toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(widgetSnapshotKey(appWidgetId), payload)
            .apply()
        TodayWidgetSupport.updateAll(context)
        rescheduleRefresh(context)
    }

    fun getWidgetSnapshotJson(context: Context, appWidgetId: Int): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(widgetSnapshotKey(appWidgetId), null)
    }

    /** 绑定被移除或绑定的课表已消失时，清掉该卡片的专属快照。 */
    fun clearWidgetSnapshot(context: Context, appWidgetId: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(widgetSnapshotKey(appWidgetId))
            .apply()
        TodayWidgetSupport.updateAll(context)
    }

    fun getRefreshTimesJson(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_REFRESH_TIMES_JSON, null)
    }

    /** 本应用注册的全部桌面小部件 Provider（`updatePeriodMillis` 全为 0，刷新靠自定义 alarm）。 */
    private val WIDGET_PROVIDER_CLASSES: List<Class<out BaseQingyuWidgetProvider>> = listOf(
        TodayCompactWidgetProvider::class.java,
        TodayMiniListWidgetProvider::class.java,
        TodayMediumWidgetProvider::class.java,
        TodayLargeWidgetProvider::class.java,
        TodayWideWidgetProvider::class.java,
        TodayStripWidgetProvider::class.java,
        StatsCompactWidgetProvider::class.java,
        StatsMediumWidgetProvider::class.java,
        StatsStripWidgetProvider::class.java,
        ExamCountdownWidgetProvider::class.java,
    )

    /**
     * **一次遍历**查全 10 类的实例 id。
     *
     * 用户报的耗电问题里，每次系统广播会被 10 个 Provider 各收一遍；若每个 Provider 内部
     * 又各自遍历 10 类（`allWidgetIds` / `widgetInstanceCounts` / `ensureScheduled` 各一份），
     * 一次广播就是 ~130 次跨进程 `getAppWidgetIds`。这里收成一份快照，所有消费方共用。
     *
     * 不做事后时间缓存：快照「按次新鲜」，避免又引入时序窗口。
     */
    internal fun collectWidgetIds(
        context: Context,
    ): Map<Class<out BaseQingyuWidgetProvider>, IntArray> {
        val manager = AppWidgetManager.getInstance(context)
        return WIDGET_PROVIDER_CLASSES.associateWith { cls ->
            manager.getAppWidgetIds(ComponentName(context, cls))
        }
    }

    /** 每个已注册 Provider 当前的实例数（消费快照，不再自己遍历）。 */
    internal fun widgetInstanceCounts(
        widgetIds: Map<Class<out BaseQingyuWidgetProvider>, IntArray>,
    ): List<Int> = widgetIds.values.map { it.size }

    /** 便捷重载：调用方没有快照时自行取一次（只取一次）。 */
    internal fun widgetInstanceCounts(context: Context): List<Int> =
        widgetInstanceCounts(collectWidgetIds(context))

    /** 本应用全部 widget 实例 id 的并集（消费快照）。 */
    internal fun allWidgetIds(
        widgetIds: Map<Class<out BaseQingyuWidgetProvider>, IntArray>,
    ): Set<Int> = widgetIds.values.flatMap { it.toList() }.toSet()

    internal fun allWidgetIds(context: Context): Set<Int> =
        allWidgetIds(collectWidgetIds(context))

    fun rescheduleRefresh(context: Context) {
        rescheduleRefresh(context, collectWidgetIds(context))
    }

    /** 消费调用方已经取好的 id 快照（一次广播只该取一次）。 */
    internal fun rescheduleRefresh(
        context: Context,
        widgetIds: Map<Class<out BaseQingyuWidgetProvider>, IntArray>,
    ) {
        // **先判后撤**：确认桌面上真的一个小部件实例都没有，才撤闹钟与 WorkManager。
        // 反过来（先撤再判）会在「第一张卡刚加、getAppWidgetIds 还没反映」的窗口里
        // 把精确闹钟和 15 分钟兜底一起弄死，且没有任何补偿 —— hy 复核指出的误伤。
        if (!WidgetRefreshGate.shouldSchedule(widgetInstanceCounts(widgetIds))) {
            cancelRefreshAlarm(context)
            WidgetRefreshWorker.cancel(context)
            return
        }
        // 非零：重排（先撤旧闹钟，避免残留两份）。
        cancelRefreshAlarm(context)
        val nowMillis = System.currentTimeMillis()
        // 刷新点 = 当前课表 + 所有已绑定课表的并集：TA 第三节课开始时
        // 闹钟也必须响，不能只按当前课表的时间调度。
        val nextTriggerAtMillis = buildList {
            add(TodayWidgetSupport.findNextRefreshAtMillis(context, nowMillis))
            for ((_, profileId) in WidgetBindingStore.allBindings(context)) {
                if (profileId == WidgetBindingStore.COUPLE_MERGED_BINDING_ID) {
                    // 情侣合并视图：刷新点=我的当前课表+TA 课表（按周偏移平移
                    // 后）并集；状态/倒计时也按合并快照判定，TA 课开课倒计时
                    // 才能逐分钟走字。
                    val coupleSource =
                        TodayWidgetSupport.buildCoupleMergedSource(context) ?: continue
                    add(
                        TodayWidgetSupport.findNextRefreshAtMillis(
                            context,
                            nowMillis,
                            profileJson = coupleSource.myProfileJson,
                            coursesOverride = coupleSource.mergedCourses,
                            snapshotOverride = TodayWidgetSupport
                                .buildCoupleMergedSnapshotFromFlutterState(context, nowMillis),
                        ),
                    )
                    continue
                }
                val profileJson =
                    TodayWidgetSupport.readProfileJsonById(context, profileId) ?: continue
                add(TodayWidgetSupport.findNextRefreshAtMillis(context, nowMillis, profileJson))
            }
        }
            .filterNotNull()
            .filter { it > nowMillis }
            .minOrNull()
            ?: loadRefreshTimes(context)
                .filter { it > nowMillis }
                .minOrNull()
            ?: run {
                // 算不出下一次刷新点：仍要保证 WorkManager 兜底在，不许「只剩取消没有补偿」。
                WidgetRefreshWorker.ensureScheduled(context, widgetIds)
                return
            }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildRefreshPendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextTriggerAtMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextTriggerAtMillis,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                nextTriggerAtMillis,
                pendingIntent
            )
        }
        // 正向收尾：非零实例必须「闹钟已排 + WorkManager 已排」，不许只剩取消没有补偿。
        WidgetRefreshWorker.ensureScheduled(context, widgetIds)
    }

    internal fun cancelRefreshAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildRefreshPendingIntent(context))
    }

    private fun buildRefreshPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, HomeWidgetRefreshReceiver::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            component = ComponentName(context, HomeWidgetRefreshReceiver::class.java)
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_REFRESH,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun refreshSnapshotFromFlutterState(context: Context): Boolean {
        val snapshot = TodayWidgetSupport.buildSnapshotFromFlutterState(context) ?: return false
        val payload = JSONObject().apply {
            put("profileName", snapshot.profileName)
            put("currentWeek", snapshot.currentWeek)
            put("state", snapshot.state)
            put("backgroundStyle", snapshot.backgroundStyle)
            put("showLocation", snapshot.showLocation)
            put("showCountdown", snapshot.showCountdown)
            put("hideCompletedCourses", snapshot.hideCompletedCourses)
            put("heightAdjustment", snapshot.heightAdjustment)
            put("cornerRadius", snapshot.cornerRadius)
            put("totalTodayCourseCount", snapshot.totalTodayCourseCount)
            put("todayCourses", coursesToJson(snapshot.todayCourses))
            put("visibleTodayCourses", coursesToJson(snapshot.visibleTodayCourses))
            put("highlightedCourse", snapshot.highlightedCourse?.let(::courseToJson))
            put("nextCourse", snapshot.nextCourse?.let(::courseToJson))
        }.toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, payload)
            .apply()
        return true
    }

    private fun coursesToJson(courses: List<TodayWidgetCourseInfo>): JSONArray {
        return JSONArray().apply {
            courses.forEach { put(courseToJson(it)) }
        }
    }

    private fun courseToJson(course: TodayWidgetCourseInfo): JSONObject {
        return JSONObject().apply {
            put("id", course.id)
            put("name", course.name)
            put("shortName", course.shortName)
            put("location", course.location)
            put("startTime", course.startTime)
            put("endTime", course.endTime)
        }
    }

    private fun widgetSnapshotKey(appWidgetId: Int) = "$KEY_WIDGET_SNAPSHOT_PREFIX$appWidgetId"

    private fun loadRefreshTimes(context: Context): List<Long> {
        val payload = getRefreshTimesJson(context) ?: return emptyList()
        return try {
            val json = JSONArray(payload)
            buildList {
                for (index in 0 until json.length()) {
                    add(json.optLong(index))
                }
            }.filter { it > 0L }
        } catch (_: Exception) {
            emptyList()
        }
    }
}

