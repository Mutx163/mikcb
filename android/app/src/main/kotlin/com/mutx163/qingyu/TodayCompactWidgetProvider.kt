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
            val snapshot = TodayWidgetSupport.readSnapshot(context)
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val state = snapshot?.state ?: "no_course"
            val backgroundStyle = snapshot?.backgroundStyle ?: "solid"
            val primaryTextColor = TodayWidgetSupport.primaryTextColor(backgroundStyle)
            val secondaryTextColor = TodayWidgetSupport.secondaryTextColor(backgroundStyle)

            views.setInt(
                R.id.widget_card,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(
                    backgroundStyle,
                    snapshot?.cornerRadius ?: 28
                )
            )
            TodayWidgetSupport.applySquareishPadding(
                views,
                R.id.widget_root,
                profile,
                baseHorizontalDp = 14,
                baseVerticalDp = 14,
                heightAdjustmentDp = snapshot?.heightAdjustment ?: 0,
                targetAspect = 1f,
            )
            val isShowingTomorrow = (state == "completed" || state == "no_course") && (snapshot?.tomorrowCourses?.isNotEmpty() == true)
            views.setTextViewText(
                R.id.widget_status,
                if (isShowingTomorrow) {
                    context.getString(R.string.widget_tomorrow_courses)
                } else {
                    TodayWidgetSupport.statusText(context, state)
                }
            )
            views.setTextViewText(
                R.id.widget_course_name,
                when {
                    snapshot == null -> context.getString(R.string.widget_no_course_today)
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
                    state == "holiday" -> context.getString(R.string.widget_rest_well)
                    isShowingTomorrow -> {
                        val first = snapshot.tomorrowCourses.first()
                        val time = "${first.startTime} - ${first.endTime}"
                        if (snapshot.showLocation && first.location.isNotBlank()) "$time\n${first.location}" else time
                    }
                    state == "no_course" -> context.getString(R.string.widget_take_a_break)
                    state == "completed" -> context.getString(R.string.widget_today_ended_short)
                    else -> {
                    val cd = TodayWidgetSupport.countdownText(context, snapshot)
                    if (cd != null) {
                        val loc = snapshot.highlightedCourse?.location.orEmpty()
                        if (snapshot.showLocation && loc.isNotBlank()) "$cd\n$loc" else cd
                    } else {
                        TodayWidgetSupport.compactMetaText(context, snapshot)
                    }
                }
                }
            )
            views.setTextColor(R.id.widget_status, secondaryTextColor)
            views.setTextColor(R.id.widget_course_name, primaryTextColor)
            views.setTextColor(R.id.widget_meta, secondaryTextColor)
            views.setInt(
                R.id.widget_status,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes(state, backgroundStyle)
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
                TodayWidgetSupport.buildLaunchPendingIntent(context, 10000 + appWidgetId)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

