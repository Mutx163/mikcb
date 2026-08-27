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

/**
 * 课程统计横向长条 4×1：单行展示 [周数徽章 | 本周节数 | 环比 | 迷你学期进度条]。
 * 进度条限宽防拉伸；高度过矮或无数据时自动隐藏。
 */
class StatsStripWidgetProvider : AppWidgetProvider() {
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
                ComponentName(context, StatsStripWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, StatsStripWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_stats_strip)
            val snapshot = StatsWidgetSupport.readSnapshot(context)
            val chrome = StatsWidgetSupport.readChrome(context)
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val primaryColor = TodayWidgetSupport.primaryTextColor(chrome.backgroundStyle)
            val secondaryColor = TodayWidgetSupport.secondaryTextColor(chrome.backgroundStyle)

            views.setInt(
                R.id.widget_card,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(chrome.backgroundStyle, chrome.cornerRadius),
            )
            TodayWidgetSupport.applyAdaptiveVerticalPadding(
                views,
                R.id.widget_root,
                profile,
                baseVerticalDp = 8,
                heightAdjustmentDp = chrome.heightAdjustment,
                targetAspect = 4f,
            )

            // 周数徽章
            views.setTextViewText(
                R.id.stats_strip_week,
                if (snapshot != null) {
                    context.getString(R.string.widget_stats_week, snapshot.currentWeek)
                } else {
                    context.getString(R.string.widget_stats_no_data)
                }
            )
            views.setInt(
                R.id.stats_strip_week,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes("upcoming", chrome.backgroundStyle),
            )
            views.setTextColor(R.id.stats_strip_week, secondaryColor)

            // 本周节数 + 环比
            if (snapshot == null) {
                views.setTextViewText(R.id.stats_strip_sections, "--")
                views.setTextViewText(R.id.stats_strip_delta, context.getString(R.string.widget_tap_to_open))
                views.setProgressBar(R.id.stats_strip_progress, 100, 0, false)
            } else {
                views.setTextViewText(
                    R.id.stats_strip_sections,
                    context.getString(R.string.widget_stats_week_sections, snapshot.weekSections),
                )
                views.setTextViewText(
                    R.id.stats_strip_delta,
                    StatsWidgetSupport.deltaLabel(context, snapshot.deltaVsLastWeek),
                )
                val max = if (snapshot.semesterTotal > 0) snapshot.semesterTotal else 1
                val done = snapshot.semesterDone.coerceIn(0, max)
                views.setProgressBar(R.id.stats_strip_progress, max, done, false)
            }
            views.setTextColor(R.id.stats_strip_sections, primaryColor)
            views.setTextColor(R.id.stats_strip_delta, secondaryColor)

            // gradient 背景下进度条换白色系（RemoteViews 着色 API 需 30+，低版本保留蓝色兜底）。
            // 反射的是 ProgressBar 的 setter 名，必须写成 *TintList 形式。
            if (chrome.backgroundStyle == "gradient" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                views.setColorStateList(
                    R.id.stats_strip_progress,
                    "setProgressTintList",
                    ColorStateList.valueOf(Color.WHITE),
                )
                views.setColorStateList(
                    R.id.stats_strip_progress,
                    "setProgressBackgroundTintList",
                    ColorStateList.valueOf(Color.parseColor("#33FFFFFF")),
                )
            }

            // 自适应：横条天然矮高度，内容不按 isShort 门控；仅窄宽度时逐级收起次要信息。
            val compact = profile.isShort
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_strip_week,
                if (compact) 10f else 11f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_strip_sections,
                if (compact) 13f else 15f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_strip_delta,
                if (compact) 10f else 12f,
            )
            // 收起门限按当前字号档实测需求设定：chip / 环比 / 进度条都是固定宽度，
            // 宽度不足时被裁掉的是卡片右边界外的视图，因此宁可整项隐藏。
            val progressMinWidthDp = if (compact) 250 else 290
            val deltaMinWidthDp = if (compact) 360 else 400
            views.setViewVisibility(
                R.id.stats_strip_progress,
                if (snapshot != null && profile.widthDp >= progressMinWidthDp) {
                    View.VISIBLE
                } else {
                    View.GONE
                },
            )
            views.setViewVisibility(
                R.id.stats_strip_delta,
                if (profile.widthDp >= deltaMinWidthDp) View.VISIBLE else View.GONE,
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, 40000 + appWidgetId),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
