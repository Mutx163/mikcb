package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Build
import android.view.View
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
                baseHorizontalDp = 16,
                baseVerticalDp = 16,
                heightAdjustmentDp = chrome.heightAdjustment,
                targetAspect = 0.5f,
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
                views.setTextViewText(R.id.stats_progress_text, "")
                views.setTextViewText(R.id.stats_sections, "--")
                views.setTextViewText(R.id.stats_delta, context.getString(R.string.widget_tap_to_open))
                views.setTextViewText(R.id.stats_nature, "")
                views.setTextViewText(R.id.stats_streak, "")
                views.setProgressBar(R.id.stats_progress, 100, 0, false)
            } else {
                val max = if (snapshot.semesterTotal > 0) snapshot.semesterTotal else 1
                val done = snapshot.semesterDone.coerceIn(0, max)
                views.setProgressBar(R.id.stats_progress, max, done, false)
                views.setTextViewText(
                    R.id.stats_progress_text,
                    context.getString(R.string.widget_stats_progress, snapshot.semesterDone, snapshot.semesterTotal),
                )
                views.setTextViewText(
                    R.id.stats_sections,
                    context.getString(R.string.widget_stats_week_sections, snapshot.weekSections),
                )
                views.setTextViewText(
                    R.id.stats_delta,
                    StatsWidgetSupport.deltaLabel(context, snapshot.deltaVsLastWeek),
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
            views.setTextColor(R.id.stats_progress_text, secondaryColor)
            views.setTextColor(R.id.stats_sections, primaryColor)
            views.setTextColor(R.id.stats_delta, secondaryColor)
            views.setTextColor(R.id.stats_nature, secondaryColor)
            views.setTextColor(R.id.stats_streak, secondaryColor)

            // gradient 背景下进度条换白色系（RemoteViews 着色 API 需 31+，低版本保留蓝色兜底）。
            if (chrome.backgroundStyle == "gradient" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setColorStateList(
                    R.id.stats_progress,
                    "setProgressTint",
                    ColorStateList.valueOf(Color.WHITE),
                )
                views.setColorStateList(
                    R.id.stats_progress,
                    "setProgressBackgroundTint",
                    ColorStateList.valueOf(Color.parseColor("#33FFFFFF")),
                )
            }

            // 按实际尺寸画像自适应字号；矮高度时收起底部信息行避免挤压。
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_week,
                if (profile.isNarrow || profile.isShort) 10f else 11f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_sections,
                when {
                    profile.isShort -> 15f
                    profile.isWide -> 22f
                    else -> 20f
                },
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_delta,
                if (profile.isNarrow || profile.isShort) 11f else 12f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_nature,
                if (profile.isNarrow || profile.isShort) 11f else 12f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_streak,
                if (profile.isNarrow || profile.isShort) 11f else 12f,
            )
            views.setViewVisibility(
                R.id.stats_nature_row,
                if (profile.isShort) View.GONE else View.VISIBLE,
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, 20000 + appWidgetId),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
