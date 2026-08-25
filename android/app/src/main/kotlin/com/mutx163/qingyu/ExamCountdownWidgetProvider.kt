package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * 考试倒计时卡 2×2：巨型数字排版 [徽章 | 天数大字+单位 | 考试名 | 日期·地点]。
 * 与现有列表/统计形态完全区分的新样式；数据复用今日快照的考试字段。
 */
class ExamCountdownWidgetProvider : AppWidgetProvider() {
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
                ComponentName(context, ExamCountdownWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, ExamCountdownWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_exam_card)
            val snapshot = TodayWidgetSupport.readSnapshot(context)
            val style = snapshot?.backgroundStyle ?: "solid"
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val primaryColor = TodayWidgetSupport.primaryTextColor(style)
            val secondaryColor = TodayWidgetSupport.secondaryTextColor(style)

            views.setInt(
                R.id.widget_card,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(style, snapshot?.cornerRadius ?: 28),
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
            val hasExam = snapshot?.nextExamName != null
            when {
                snapshot == null || !hasExam -> {
                    views.setTextViewText(R.id.exam_days, "--")
                    views.setTextViewText(R.id.exam_day_unit, "")
                    views.setTextViewText(R.id.exam_name, context.getString(R.string.widget_exam_none))
                    views.setTextViewText(R.id.exam_meta, context.getString(R.string.widget_tap_to_open))
                }
                isExamOngoing -> {
                    views.setTextViewText(
                        R.id.exam_days,
                        context.getString(R.string.widget_exam_until, snapshot.nextExamEndTime ?: ""),
                    )
                    views.setTextViewText(R.id.exam_day_unit, "")
                    views.setTextViewText(
                        R.id.exam_name,
                        TodayWidgetSupport.examDisplayName(snapshot)
                            ?: context.getString(R.string.widget_exam_fallback_name),
                    )
                    views.setTextViewText(R.id.exam_meta, examMeta(snapshot))
                }
                (snapshot.nextExamDaysUntil ?: 0) == 0 -> {
                    views.setTextViewText(R.id.exam_days, context.getString(R.string.widget_exam_today_big))
                    views.setTextViewText(R.id.exam_day_unit, "")
                    views.setTextViewText(
                        R.id.exam_name,
                        TodayWidgetSupport.examDisplayName(snapshot)
                            ?: context.getString(R.string.widget_exam_fallback_name),
                    )
                    views.setTextViewText(R.id.exam_meta, examMeta(snapshot))
                }
                else -> {
                    val days = snapshot.nextExamDaysUntil ?: 0
                    views.setTextViewText(R.id.exam_days, days.toString())
                    views.setTextViewText(R.id.exam_day_unit, context.getString(R.string.widget_exam_unit_day))
                    views.setTextViewText(
                        R.id.exam_name,
                        TodayWidgetSupport.examDisplayName(snapshot)
                            ?: context.getString(R.string.widget_exam_fallback_name),
                    )
                    views.setTextViewText(R.id.exam_meta, examMeta(snapshot))
                }
            }
            views.setTextColor(R.id.exam_days, primaryColor)
            views.setTextColor(R.id.exam_day_unit, secondaryColor)
            views.setTextColor(R.id.exam_name, primaryColor)
            views.setTextColor(R.id.exam_meta, secondaryColor)

            // 无考试时隐藏大字号下的空单位行。
            views.setViewVisibility(
                R.id.exam_day_unit,
                if (snapshot == null || !hasExam || isExamOngoing ||
                    (snapshot.nextExamDaysUntil ?: 0) == 0
                ) {
                    View.GONE
                } else {
                    View.VISIBLE
                }
            )

            // 自适应：矮高度压大字号；窄宽度缩名称行。
            TodayWidgetSupport.setTextSizeSp(views, R.id.exam_chip, if (profile.isShort) 10f else 11f)
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.exam_days,
                when {
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
                TodayWidgetSupport.buildLaunchPendingIntent(context, 50000 + appWidgetId),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun examMeta(snapshot: com.mutx163.qingyu.TodayWidgetSnapshotInfo): String {
            // yyyy-MM-dd → MM-dd；拼接地点（有则显示）。
            val date = snapshot.nextExamDate.orEmpty()
            val shortDate = if (date.length >= 10) date.substring(5) else date
            val location = snapshot.nextExamLocation.orEmpty()
            return listOf(shortDate, location)
                .filter { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
                .joinToString(" · ")
        }
    }
}
