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
import java.util.Locale
import kotlin.math.roundToInt

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
            TodayWidgetSupport.applyAdaptiveVerticalPadding(
                views,
                R.id.widget_root,
                profile,
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
                views.setTextViewText(R.id.stats_nature, "")
                views.setProgressBar(R.id.stats_bar, 100, 0, false)
                views.setViewVisibility(R.id.stats_nature, View.GONE)
                views.setViewVisibility(R.id.stats_extra_pct, View.GONE)
            } else {
                val max = if (snapshot.semesterTotal > 0) snapshot.semesterTotal else 1
                val done = snapshot.semesterDone.coerceIn(0, max)
                views.setProgressBar(R.id.stats_bar, max, done, false)
                views.setTextViewText(
                    R.id.stats_sections,
                    context.getString(R.string.widget_stats_week_sections, snapshot.weekSections),
                )
                views.setTextViewText(
                    R.id.stats_delta,
                    StatsWidgetSupport.deltaLabel(context, snapshot.deltaVsLastWeek),
                )
                // 单行只放百分比：合并长句在 2 列宽摆位必然截断。
                val percent = ((done.toDouble() / max) * 100).roundToInt()
                views.setTextViewText(
                    R.id.stats_extra_pct,
                    context.getString(R.string.widget_stats_percent, percent),
                )
                views.setTextViewText(
                    R.id.stats_nature,
                    context.getString(R.string.widget_stats_nature, snapshot.requiredCount, snapshot.electiveCount),
                )
            }
            views.setTextColor(R.id.stats_sections, primaryColor)
            views.setTextColor(R.id.stats_delta, secondaryColor)
            views.setTextColor(R.id.stats_nature, secondaryColor)
            views.setTextColor(R.id.stats_extra_pct, secondaryColor)

            // gradient 背景下进度条换白色系（RemoteViews.setColorStateList 需 API 31+，
            // 低版本保留布局里的蓝色兜底；反射 setter 名必须是 *TintList 形式）。
            if (chrome.backgroundStyle == "gradient" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setColorStateList(
                    R.id.stats_bar,
                    "setProgressTintList",
                    ColorStateList.valueOf(Color.WHITE),
                )
                views.setColorStateList(
                    R.id.stats_bar,
                    "setProgressBackgroundTintList",
                    ColorStateList.valueOf(Color.parseColor("#33FFFFFF")),
                )
            }

            // 明细行按高度/宽度分档：矮卡只留核心三行，正常方卡全量显示。
            // 无数据时文本已置空，保持 GONE，避免空行高+边距在小卡上白占高度。
            val showDetail = snapshot != null && !profile.isShort && !profile.isNarrow
            views.setViewVisibility(R.id.stats_nature, if (showDetail) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.stats_extra_pct, if (showDetail) View.VISIBLE else View.GONE)

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
                TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
