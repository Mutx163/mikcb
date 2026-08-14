package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class StatsMediumWidgetProvider : AppWidgetProvider() {
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
                ComponentName(context, StatsMediumWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, StatsMediumWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_stats_medium)
            val snapshot = StatsWidgetSupport.readSnapshot(context)
            if (snapshot == null) {
                views.setTextViewText(R.id.stats_week, context.getString(R.string.widget_stats_no_data))
                views.setTextViewText(R.id.stats_sections, "--")
                views.setTextViewText(R.id.stats_progress_text, "")
                views.setTextViewText(R.id.stats_delta, context.getString(R.string.widget_tap_to_open))
                views.setTextViewText(R.id.stats_nature, "")
                views.setTextViewText(R.id.stats_streak, "")
                views.setProgressBar(R.id.stats_progress, 0, 1, false)
            } else {
                views.setTextViewText(
                    R.id.stats_week,
                    context.getString(R.string.widget_stats_week, snapshot.currentWeek),
                )
                views.setTextViewText(
                    R.id.stats_sections,
                    context.getString(R.string.widget_stats_week_sections, snapshot.weekSections),
                )
                views.setTextViewText(
                    R.id.stats_delta,
                    StatsWidgetSupport.deltaLabel(context, snapshot.deltaVsLastWeek),
                )
                val total = if (snapshot.semesterTotal > 0) snapshot.semesterTotal else 1
                val progress = snapshot.semesterDone.coerceIn(0, snapshot.semesterTotal)
                views.setProgressBar(R.id.stats_progress, progress, total, false)
                views.setTextViewText(
                    R.id.stats_progress_text,
                    context.getString(R.string.widget_stats_progress, snapshot.semesterDone, snapshot.semesterTotal),
                )
                views.setTextViewText(
                    R.id.stats_nature,
                    context.getString(R.string.widget_stats_nature, snapshot.requiredCount, snapshot.electiveCount),
                )
                views.setTextViewText(
                    R.id.stats_streak,
                    context.getString(R.string.widget_stats_streak, snapshot.longestStreak),
                )
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
