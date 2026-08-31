package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * 考试倒计时卡 2×2：巨型数字排版 [徽章 | 天数大字+单位 | 考试名 | 日期·地点]。
 * 与现有列表/统计形态完全区分的新样式；数据复用今日快照的考试字段。
 */
class ExamCountdownWidgetProvider : BaseQingyuWidgetProvider() {
    override fun providerClass(): Class<out BaseQingyuWidgetProvider> =
        ExamCountdownWidgetProvider::class.java

    companion object {
        fun updateAll(context: Context) {
            ExamCountdownWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_exam_card)
        val snapshot = TodayWidgetSupport.readSnapshot(context)
        val style = snapshot?.backgroundStyle ?: "solid"
        val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
        val primaryColor = TodayWidgetSupport.primaryTextColor(style)
        val secondaryColor = TodayWidgetSupport.secondaryTextColor(style)

        views.setInt(
            R.id.widget_card,
            "setBackgroundResource",
            TodayWidgetSupport.backgroundRes(
                style,
                snapshot?.cornerRadius ?: TodayWidgetSupport.DEFAULT_CORNER_RADIUS_DP,
            ),
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

        // 徽章：固定"考试倒计时"，进行中切"考试中"。
        views.setTextViewText(
            R.id.exam_chip,
            if (isExamOngoing) {
                context.getString(R.string.widget_status_exam_ongoing)
            } else {
                context.getString(R.string.widget_exam_card_chip)
            }
        )
        views.setInt(
            R.id.exam_chip,
            "setBackgroundResource",
            TodayWidgetSupport.statusBackgroundRes(
                if (isExamOngoing) "ongoing" else "upcoming",
                style,
            ),
        )
        views.setTextColor(R.id.exam_chip, secondaryColor)

        // 大字区：常规显示天数，今天考试显示"今天"，进行中显示结束时间，无数据显示占位。
        val endTimeText = snapshot?.nextExamEndTime.orEmpty()
            .takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
        val daysUntil = snapshot?.nextExamDaysUntil ?: 0
        val noExam = snapshot == null || snapshot.nextExamName == null
        // 「数字天数」与「-- 占位」都是短数字形态，保持超大字号；
        // 「今天」/「In exam」/「10:30」这类文案必须降档，否则 44sp 在 2×2 卡里必然左右裁切。
        val bigIsNumeric = noExam || (!isExamOngoing && daysUntil > 0)
        // 只有「数字 + 天」这一形态需要单位行。
        val numericDays = !noExam && !isExamOngoing && daysUntil > 0
        views.setTextViewText(
            R.id.exam_days,
            when {
                noExam -> "--"
                isExamOngoing -> endTimeText
                    ?: context.getString(R.string.widget_status_exam_ongoing)
                daysUntil == 0 -> context.getString(R.string.widget_exam_today_big)
                else -> daysUntil.toString()
            },
        )
        views.setTextViewText(
            R.id.exam_day_unit,
            if (numericDays) context.getString(R.string.widget_exam_unit_day) else "",
        )
        views.setTextViewText(
            R.id.exam_name,
            snapshot?.takeIf { !noExam }?.let {
                TodayWidgetSupport.examDisplayName(it)
                    ?: context.getString(R.string.widget_exam_fallback_name)
            } ?: context.getString(R.string.widget_exam_none),
        )
        views.setTextViewText(
            R.id.exam_meta,
            snapshot?.takeIf { !noExam }?.let { examMeta(it) }
                ?: context.getString(R.string.widget_tap_to_open),
        )
        views.setTextColor(R.id.exam_days, primaryColor)
        views.setTextColor(R.id.exam_day_unit, secondaryColor)
        views.setTextColor(R.id.exam_name, primaryColor)
        views.setTextColor(R.id.exam_meta, secondaryColor)

        // 单位行只服务「数字 + 天」形态，其余形态隐藏避免空行占位。
        views.setViewVisibility(
            R.id.exam_day_unit,
            if (numericDays) View.VISIBLE else View.GONE,
        )
        // 用户把 2×2 竖向拉到一行高时四行放不下会被上下同时裁切，先让出地点行。
        views.setViewVisibility(
            R.id.exam_meta,
            if (profile.heightDp < 100) View.GONE else View.VISIBLE,
        )

        // 自适应：矮高度压大字号；窄宽度缩名称行。
        TodayWidgetSupport.setTextSizeSp(views, R.id.exam_chip, if (profile.isShort) 10f else 11f)
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.exam_days,
            when {
                !bigIsNumeric -> if (profile.isShort) 20f else 26f
                profile.isShort -> 30f
                profile.isWide -> 52f
                else -> 44f
            },
        )
        TodayWidgetSupport.setTextSizeSp(views, R.id.exam_day_unit, if (profile.isShort) 11f else 13f)
        TodayWidgetSupport.setTextSizeSp(views, R.id.exam_name, if (profile.isShort) 12f else 14f)
        TodayWidgetSupport.setTextSizeSp(views, R.id.exam_meta, if (profile.isShort) 10f else 11f)

        views.setOnClickPendingIntent(
            R.id.widget_root,
            TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId),
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
