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
            // 与今日系列同源的外观设置：背景风格 / 圆角 / 高度微调。
            val chrome = StatsWidgetSupport.readChrome(context)
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val primaryColor = TodayWidgetSupport.primaryTextColor(chrome.backgroundStyle)
            val secondaryColor = TodayWidgetSupport.secondaryTextColor(chrome.backgroundStyle)

            views.setInt(
                R.id.widget_card,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(chrome.backgroundStyle, chrome.cornerRadius),
            )
            TodayWidgetSupport.applySquareishPadding(
                views,
                R.id.widget_root,
                profile,
                baseHorizontalDp = 14,
                baseVerticalDp = 14,
                heightAdjustmentDp = chrome.heightAdjustment,
                targetAspect = 1f,
            )

            // 周数 chip：与今日组件同一套徽章底色与配色。
            views.setTextViewText(
                R.id.stats_week,
                if (snapshot != null) {
                    context.getString(R.string.widget_stats_week, snapshot.currentWeek)
                } else {
                    context.getString(R.string.widget_stats_no_data)
                }
            )
            views.setInt(
                R.id.stats_week,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes("upcoming", chrome.backgroundStyle),
            )
            views.setTextColor(R.id.stats_week, secondaryColor)

            if (snapshot == null) {
                views.setTextViewText(R.id.stats_sections, "--")
                views.setTextViewText(R.id.stats_delta, context.getString(R.string.widget_tap_to_open))
            } else {
                views.setTextViewText(
                    R.id.stats_sections,
                    context.getString(R.string.widget_stats_week_sections, snapshot.weekSections),
                )
                views.setTextViewText(
                    R.id.stats_delta,
                    StatsWidgetSupport.deltaLabel(context, snapshot.deltaVsLastWeek),
                )
            }
            views.setTextColor(R.id.stats_sections, primaryColor)
            views.setTextColor(R.id.stats_delta, secondaryColor)

            // 按实际尺寸画像自适应字号（对齐 TodayCompact 的分档）。
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_week,
                if (profile.isNarrow || profile.isShort) 10f else 11f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_sections,
                when {
                    profile.isShort -> 16f
                    profile.isWide -> 20f
                    else -> 18f
                },
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_delta,
                if (profile.isNarrow || profile.isShort) 11f else 12f,
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, 20000 + appWidgetId),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
