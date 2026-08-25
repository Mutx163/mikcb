package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * 今日课程横向长条 4×1：单行展示 [状态徽章 | 课程名 | 时间/倒计时 | 周数]。
 * 渲染规范与 Today 系列同源：背景全家桶、状态 chip、尺寸画像自适应。
 */
class TodayStripWidgetProvider : AppWidgetProvider() {
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
                ComponentName(context, TodayStripWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayStripWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_today_strip)
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
                baseHorizontalDp = 12,
                baseVerticalDp = 8,
                heightAdjustmentDp = snapshot?.heightAdjustment ?: 0,
                targetAspect = 4f,
            )

            val state = snapshot?.state ?: "no_course"
            val displayState = if (snapshot != null) {
                TodayWidgetSupport.displayStatusState(snapshot)
            } else {
                state
            }
            val isExamOngoing = snapshot != null && TodayWidgetSupport.isExamOngoing(snapshot)
            val isShowingTomorrow = snapshot != null && TodayWidgetSupport.isShowingTomorrowCourses(snapshot)

            // 状态徽章
            views.setTextViewText(
                R.id.widget_strip_status,
                if (snapshot != null) {
                    TodayWidgetSupport.displayStatusText(context, snapshot)
                } else {
                    TodayWidgetSupport.statusText(context, state)
                }
            )
            views.setInt(
                R.id.widget_strip_status,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes(displayState, style),
            )
            views.setTextColor(R.id.widget_strip_status, secondaryColor)

            // 主课程名（信息优先级最高，宽度不足时最后截断）
            views.setTextViewText(
                R.id.widget_strip_course,
                when {
                    snapshot == null -> context.getString(R.string.widget_no_course_today)
                    isExamOngoing ->
                        TodayWidgetSupport.examDisplayName(snapshot)
                            ?: context.getString(R.string.widget_exam_fallback_name)
                    state == "holiday" -> snapshot.holidayName ?: context.getString(R.string.widget_on_holiday)
                    isShowingTomorrow -> snapshot.tomorrowCourses.first().name
                    else -> TodayWidgetSupport.heroCourseName(context, snapshot)
                }
            )
            views.setTextColor(R.id.widget_strip_course, primaryColor)

            // 时间 / 倒计时
            val metaText = when {
                snapshot == null -> context.getString(R.string.widget_tap_to_open)
                isExamOngoing -> TodayWidgetSupport.examOngoingMetaText(context, snapshot)
                state == "holiday" -> TodayWidgetSupport.examCountdownText(context, snapshot)
                    ?: context.getString(R.string.widget_rest_well)
                isShowingTomorrow -> snapshot.tomorrowCourses.first().let { course ->
                    course.startTime + " - " + course.endTime
                }
                state == "completed" -> context.getString(R.string.widget_today_ended_short)
                state == "no_course" -> ""
                else -> TodayWidgetSupport.countdownText(context, snapshot)
                    ?: TodayWidgetSupport.heroTimeText(context, snapshot)
            }
            views.setTextViewText(R.id.widget_strip_meta, metaText)
            views.setTextColor(R.id.widget_strip_meta, secondaryColor)

            // 周数（最次要信息，窄宽度时隐藏）
            views.setTextViewText(
                R.id.widget_strip_week,
                if (state == "holiday") {
                    context.getString(R.string.widget_week_holiday, snapshot?.currentWeek ?: 1)
                } else {
                    context.getString(R.string.widget_week_number, snapshot?.currentWeek ?: 1)
                }
            )
            views.setTextColor(R.id.widget_strip_week, secondaryColor)

            // 横条自适应：矮高度降字号；窄宽度先隐藏周数、再隐藏时间。
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_strip_status,
                if (profile.isShort) 10f else 11f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_strip_course,
                if (profile.isShort) 13f else 15f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_strip_meta,
                if (profile.isShort) 10f else 12f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_strip_week,
                if (profile.isShort) 10f else 11f,
            )
            views.setViewVisibility(
                R.id.widget_strip_week,
                if (profile.widthDp < 230) View.GONE else View.VISIBLE,
            )
            views.setViewVisibility(
                R.id.widget_strip_meta,
                if (profile.widthDp < 160) View.GONE else View.VISIBLE,
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, 30000 + appWidgetId),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
