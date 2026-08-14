package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class StatsCompactWidgetProvider : AppWidgetProvider() {
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
                ComponentName(context, StatsCompactWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, StatsCompactWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_stats_compact)
            val snapshot = StatsWidgetSupport.readSnapshot(context)
            if (snapshot == null) {
                views.setTextViewText(R.id.stats_week, context.getString(R.string.widget_stats_no_data))
                views.setTextViewText(R.id.stats_sections, "--")
                views.setTextViewText(R.id.stats_delta, context.getString(R.string.widget_tap_to_open))
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
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
