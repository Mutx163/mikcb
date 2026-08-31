package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.util.Locale
import kotlin.math.roundToInt

/**
 * 课程统计横向长条 4×1：单行展示 [周数徽章 | 本周节数 | 环比 | 迷你学期进度条]。
 * 进度条限宽防拉伸；高度过矮或无数据时自动隐藏。
 */
class StatsStripWidgetProvider : BaseQingyuWidgetProvider() {
    override fun providerClass(): Class<out BaseQingyuWidgetProvider> =
        StatsStripWidgetProvider::class.java

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
            StatsStripWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_stats_strip)
        val snapshot = StatsWidgetSupport.readSnapshot(context)
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

        // gradient 背景下进度条换白色系（RemoteViews.setColorStateList 需 API 31+，
        // 低版本保留蓝色兜底）。
        // 反射的是 ProgressBar 的 setter 名，必须写成 *TintList 形式。
        if (chrome.backgroundStyle == "gradient" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
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
        // 宽度不足时被裁掉的是卡片右边界外的视图，因此宁可整项隐藏或换短句。
        // 环比两档显示：宽档用完整「较上周 ±N 节」，中档用「±N 节」缩写——
        // 否则真机 4 列（约 330-390dp）会整项隐藏，加权节数文本在中部撑出大空档。
        val progressMinWidthDp = if (compact) 250 else 290
        val deltaShortMinWidthDp = if (compact) 300 else 330
        val deltaFullMinWidthDp = if (compact) 400 else 440
        views.setViewVisibility(
            R.id.stats_strip_progress,
            if (snapshot != null && profile.widthDp >= progressMinWidthDp) {
                View.VISIBLE
            } else {
                View.GONE
            },
        )
        val showDelta = snapshot != null && profile.widthDp >= deltaShortMinWidthDp
        if (showDelta) {
            views.setTextViewText(
                R.id.stats_strip_delta,
                if (profile.widthDp >= deltaFullMinWidthDp) {
                    StatsWidgetSupport.deltaLabel(context, snapshot.deltaVsLastWeek)
                } else {
                    StatsWidgetSupport.deltaShortLabel(context, snapshot.deltaVsLastWeek)
                },
            )
            views.setTextColor(R.id.stats_strip_delta, secondaryColor)
        }
        views.setViewVisibility(
            R.id.stats_strip_delta,
            if (showDelta) View.VISIBLE else View.GONE,
        )

        // 高度足够时亮出第二行：完整环比沉到左端、右端放进度百分比与日均，
        // 拉高后的横条不再是上下全空的孤零零一线。
        val twoLine = profile.heightDp >= 92
        views.setViewVisibility(
            R.id.strip_sub_row,
            if (twoLine) View.VISIBLE else View.GONE,
        )
        if (twoLine && snapshot != null) {
            views.setTextViewText(
                R.id.stats_strip_sub_left,
                StatsWidgetSupport.deltaLabel(context, snapshot.deltaVsLastWeek),
            )
            val maxTotal = if (snapshot.semesterTotal > 0) snapshot.semesterTotal else 1
            val percent = (
                (snapshot.semesterDone.coerceIn(0, maxTotal).toDouble() / maxTotal) * 100
                ).roundToInt()
            val dailyAvg = String.format(Locale.getDefault(), "%.1f", snapshot.weekSections / 5.0)
            views.setTextViewText(
                R.id.stats_strip_sub_right,
                context.getString(R.string.widget_stats_percent, percent) + " · " +
                    context.getString(R.string.widget_stats_daily, dailyAvg),
            )
            views.setTextColor(R.id.stats_strip_sub_left, secondaryColor)
            views.setTextColor(R.id.stats_strip_sub_right, secondaryColor)
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_strip_sub_left,
                if (compact) 10f else 11f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.stats_strip_sub_right,
                if (compact) 10f else 11f,
            )
        }

        // 第三行：高度充裕时的学期进度与连续天数摘要。
        // 用短进度句，保证 4×1 最小宽度下也不被 ellipsize 成「0.…」。
        val sub2Text = if (profile.heightDp >= 150 && snapshot != null && snapshot.semesterTotal > 0) {
            context.getString(R.string.widget_stats_progress_short, snapshot.semesterDone, snapshot.semesterTotal) +
                " · " + context.getString(R.string.widget_stats_streak, snapshot.longestStreak)
        } else {
            ""
        }
        views.setViewVisibility(
            R.id.stats_strip_sub2,
            if (sub2Text.isNotBlank()) View.VISIBLE else View.GONE,
        )
        views.setTextViewText(R.id.stats_strip_sub2, sub2Text)
        views.setTextColor(R.id.stats_strip_sub2, secondaryColor)
        TodayWidgetSupport.setTextSizeSp(views, R.id.stats_strip_sub2, if (compact) 10f else 11f)

        views.setOnClickPendingIntent(
            R.id.widget_root,
            TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId),
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
