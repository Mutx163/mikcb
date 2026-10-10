package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import kotlin.math.roundToInt

class StatsCompactWidgetProvider : BaseQingyuWidgetProvider() {
    override fun providerClass(): Class<out BaseQingyuWidgetProvider> =
        StatsCompactWidgetProvider::class.java

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
            StatsCompactWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_stats_compact)
        val snapshot = StatsWidgetSupport.readSnapshot(context)
        // 与今日系列同源的外观设置：背景风格 / 圆角 / 高度微调。
        val chrome = StatsWidgetSupport.readChrome(context)
        val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
        val primaryColor = TodayWidgetSupport.primaryTextColor(chrome.backgroundStyle, context)
        val secondaryColor = TodayWidgetSupport.secondaryTextColor(chrome.backgroundStyle, context)

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
        views.applyInk(
            R.id.stats_week,
            WidgetInk.CHIP_STRONG,
            chrome.backgroundStyle,
            context,
        )

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
        views.applyInk(
            R.id.stats_sections,
            WidgetInk.PRIMARY,
            chrome.backgroundStyle,
            context,
            fallback = primaryColor,
        )
        views.applyInk(
            R.id.stats_delta,
            WidgetInk.SECONDARY,
            chrome.backgroundStyle,
            context,
            fallback = secondaryColor,
        )
        views.applyInk(
            R.id.stats_nature,
            WidgetInk.SECONDARY,
            chrome.backgroundStyle,
            context,
            fallback = secondaryColor,
        )
        views.applyInk(
            R.id.stats_extra_pct,
            WidgetInk.SECONDARY,
            chrome.backgroundStyle,
            context,
            fallback = secondaryColor,
        )

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

        // 明细行按「内容真实需要的高度 vs 格位可用高度」分档，不再拍固定阈值：
        // isShort/isNarrow 直接 0 行；其余按格位高度 − 双层内边距算可用空间，
        // 取能装下的最多明细行数（2=必修·选修+已上%，1=只留必修·选修，0=全收），
        // 避免最后一行被垂直居中布局裁出卡外（用户 2×2 格位实测被裁）。
        // 判据与预算口径见 TodayWidgetSupport.statsCompactDetailRowCount。
        val detailRows = if (snapshot != null && !profile.isShort && !profile.isNarrow) {
            TodayWidgetSupport.statsCompactDetailRowCount(profile, chrome.heightAdjustment)
        } else {
            0
        }
        views.setViewVisibility(R.id.stats_nature, if (detailRows >= 1) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.stats_extra_pct, if (detailRows >= 2) View.VISIBLE else View.GONE)

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
