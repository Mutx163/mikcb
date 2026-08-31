package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class TodayCompactWidgetProvider : AppWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayCompactWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }


    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        // 卡片被移除时清掉绑定档案与专属快照，防止孤儿数据越积越多。
        appWidgetIds.forEach { appWidgetId ->
            WidgetBindingStore.remove(context, appWidgetId)
            HomeWidgetStorage.clearWidgetSnapshot(context, appWidgetId)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayCompactWidgetProvider::class.java)
            )
            ids.forEach { appWidgetId ->
                updateWidget(context, manager, appWidgetId)
            }
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_today_compact)
            val snapshot = TodayWidgetSupport.readSnapshotForWidget(context, appWidgetId)
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val state = snapshot?.state ?: "no_course"
            val backgroundStyle = snapshot?.backgroundStyle ?: "solid"
            val primaryTextColor = TodayWidgetSupport.primaryTextColor(backgroundStyle, context)
            val secondaryTextColor = TodayWidgetSupport.secondaryTextColor(backgroundStyle, context)

            views.setInt(
                R.id.widget_card,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(
                    backgroundStyle,
                    snapshot?.cornerRadius ?: TodayWidgetSupport.DEFAULT_CORNER_RADIUS_DP
                )
            )
            TodayWidgetSupport.applyAdaptiveVerticalPadding(
                views,
                R.id.widget_root,
                profile,
                baseVerticalDp = 14,
                heightAdjustmentDp =
                    snapshot?.heightAdjustment ?: TodayWidgetSupport.DEFAULT_HEIGHT_ADJUSTMENT_DP,
                targetAspect = 1f,
            )
            val isExamOngoing = snapshot != null && TodayWidgetSupport.isExamOngoing(snapshot)
            val isShowingTomorrow = snapshot != null && TodayWidgetSupport.isShowingTomorrowCourses(snapshot)
            val displayState = if (snapshot != null) {
                TodayWidgetSupport.displayStatusState(snapshot)
            } else {
                state
            }
            views.setTextViewText(
                R.id.widget_status,
                if (snapshot != null) {
                    TodayWidgetSupport.displayStatusText(context, snapshot)
                } else {
                    TodayWidgetSupport.statusText(context, state)
                }
            )
            views.setTextViewText(
                R.id.widget_course_name,
                when {
                    snapshot == null -> context.getString(R.string.widget_no_course_today)
                    isExamOngoing ->
                        TodayWidgetSupport.examDisplayName(snapshot)
                            ?: context.getString(R.string.widget_exam_fallback_name)
                    state == "holiday" ->
                        snapshot.holidayName ?: context.getString(R.string.widget_on_holiday)
                    isShowingTomorrow -> snapshot.tomorrowCourses.first().name
                    state == "completed" -> context.getString(R.string.widget_today_courses)
                    else -> TodayWidgetSupport.heroCourseName(context, snapshot)
                }
            )
            views.setTextViewText(
                R.id.widget_meta,
                when {
                    snapshot == null -> context.getString(R.string.widget_tap_to_open)
                    isExamOngoing -> TodayWidgetSupport.examOngoingMetaText(context, snapshot)
                    state == "holiday" -> {
                        val examText = TodayWidgetSupport.examCountdownText(context, snapshot)
                        examText ?: context.getString(R.string.widget_rest_well)
                    }
                    isShowingTomorrow -> {
                        val first = snapshot.tomorrowCourses.first()
                        val time = "${first.startTime} - ${first.endTime}"
                        val base = if (snapshot.showLocation && first.location.isNotBlank()) {
                            "$time\n${first.location}"
                        } else {
                            time
                        }
                        val examText = TodayWidgetSupport.examCountdownText(context, snapshot)
                        if (examText != null) "$base\n$examText" else base
                    }
                    state == "no_course" -> {
                        val examText = TodayWidgetSupport.examCountdownText(context, snapshot)
                        examText ?: context.getString(R.string.widget_take_a_break)
                    }
                    state == "completed" -> {
                        val examText = TodayWidgetSupport.examCountdownText(context, snapshot)
                        examText ?: buildString {
                            append(context.getString(R.string.widget_today_ended_short))
                            // 补一行今日节数，避免下半张卡片只剩一句占位话。
                            if (snapshot.totalTodayCourseCount > 0) {
                                append("\n")
                                append(
                                    context.getString(
                                        R.string.widget_today_count,
                                        snapshot.totalTodayCourseCount,
                                    )
                                )
                            }
                        }
                    }
                    else -> {
                        val cd = TodayWidgetSupport.countdownText(context, snapshot)
                        val base = if (cd != null) {
                            val loc = snapshot.highlightedCourse?.location.orEmpty()
                            if (snapshot.showLocation && loc.isNotBlank()) "$cd\n$loc" else cd
                        } else {
                            TodayWidgetSupport.compactMetaText(context, snapshot)
                        }
                        val examText = TodayWidgetSupport.examCountdownText(context, snapshot)
                        if (examText != null) "$base\n$examText" else base
                    }
                }
            )
            views.setTextColor(R.id.widget_status, secondaryTextColor)
            views.setTextColor(R.id.widget_course_name, primaryTextColor)
            views.setTextColor(R.id.widget_meta, secondaryTextColor)
            views.setInt(
                R.id.widget_status,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes(displayState, backgroundStyle)
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_status,
                if (profile.isNarrow || profile.isShort) 10f else 11f
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_course_name,
                when {
                    profile.isShort -> 16f
                    profile.isWide -> 19f
                    else -> 18f
                }
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_meta,
                if (profile.isNarrow || profile.isShort) 11f else 12f
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

