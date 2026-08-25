package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * 今日课程横宽版 4×2：左栏当前/下一节课主信息，右栏接下来两节课列表。
 * 横向大矩形形态，与竖向"概览 2×4"互为补充。
 */
class TodayWideWidgetProvider : AppWidgetProvider() {
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
                ComponentName(context, TodayWideWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayWideWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_today_wide)
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
                baseHorizontalDp = 16,
                baseVerticalDp = 12,
                heightAdjustmentDp = snapshot?.heightAdjustment ?: 0,
                targetAspect = 2f,
            )

            val state = snapshot?.state ?: "no_course"
            val displayState = if (snapshot != null) {
                TodayWidgetSupport.displayStatusState(snapshot)
            } else {
                state
            }
            val isExamOngoing = snapshot != null && TodayWidgetSupport.isExamOngoing(snapshot)

            // 左栏：状态徽章 + 主课程 + 时间（倒计时优先）· 地点
            views.setTextViewText(
                R.id.widget_wide_status,
                if (snapshot != null) {
                    TodayWidgetSupport.displayStatusText(context, snapshot)
                } else {
                    TodayWidgetSupport.statusText(context, state)
                }
            )
            views.setInt(
                R.id.widget_wide_status,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes(displayState, style),
            )
            views.setTextColor(R.id.widget_wide_status, secondaryColor)

            views.setTextViewText(
                R.id.widget_wide_course,
                when {
                    snapshot == null -> context.getString(R.string.widget_no_course_today)
                    isExamOngoing ->
                        TodayWidgetSupport.examDisplayName(snapshot)
                            ?: context.getString(R.string.widget_exam_fallback_name)
                    state == "holiday" -> snapshot.holidayName ?: context.getString(R.string.widget_on_holiday)
                    else -> TodayWidgetSupport.heroCourseName(context, snapshot)
                }
            )
            views.setTextColor(R.id.widget_wide_course, primaryColor)

            val timePart = when {
                snapshot == null -> context.getString(R.string.widget_tap_to_open)
                isExamOngoing -> TodayWidgetSupport.examOngoingMetaText(context, snapshot)
                state == "holiday" -> TodayWidgetSupport.examCountdownText(context, snapshot)
                    ?: context.getString(R.string.widget_rest_well)
                state == "no_course" -> context.getString(R.string.widget_take_a_break)
                state == "completed" -> context.getString(R.string.widget_today_ended_short)
                else -> TodayWidgetSupport.countdownText(context, snapshot)
                    ?: TodayWidgetSupport.heroTimeText(context, snapshot)
            }
            val location = snapshot?.highlightedCourse?.location.orEmpty()
            val metaText = if (timePart.isNotBlank() && snapshot != null && !isExamOngoing &&
                state != "holiday" && state != "completed" && state != "no_course" &&
                snapshot.showLocation && location.isNotBlank()
            ) {
                timePart + " · " + location
            } else {
                timePart
            }
            views.setTextViewText(R.id.widget_wide_meta, metaText)
            views.setTextColor(R.id.widget_wide_meta, secondaryColor)

            // 右栏：接下来两节课 + 周数
            val isShowingTomorrow = snapshot != null && TodayWidgetSupport.isShowingTomorrowCourses(snapshot)
            views.setTextViewText(
                R.id.widget_wide_right_label,
                if (isShowingTomorrow) {
                    context.getString(R.string.widget_tomorrow_courses)
                } else {
                    context.getString(R.string.widget_status_upcoming)
                }
            )
            views.setTextViewText(
                R.id.widget_wide_week,
                if (state == "holiday") {
                    context.getString(R.string.widget_week_holiday, snapshot?.currentWeek ?: 1)
                } else {
                    context.getString(R.string.widget_week_number, snapshot?.currentWeek ?: 1)
                }
            )
            views.setTextColor(R.id.widget_wide_right_label, secondaryColor)
            views.setTextColor(R.id.widget_wide_week, secondaryColor)

            val upcoming = if (snapshot == null) {
                emptyList()
            } else {
                TodayWidgetSupport.secondaryCourses(snapshot, 2)
            }
            bindRow(views, R.id.widget_wide_row_1, R.id.widget_wide_row_1_time, R.id.widget_wide_row_1_title, upcoming.getOrNull(0), secondaryColor, primaryColor)
            bindRow(views, R.id.widget_wide_row_2, R.id.widget_wide_row_2_time, R.id.widget_wide_row_2_title, upcoming.getOrNull(1), secondaryColor, primaryColor)

            // 自适应字号；窄宽度时右栏退化为只显示周数行。
            TodayWidgetSupport.setTextSizeSp(views, R.id.widget_wide_status, if (profile.isShort) 10f else 11f)
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_wide_course,
                when {
                    profile.isShort -> 17f
                    profile.widthDp >= 320 -> 22f
                    else -> 20f
                },
            )
            TodayWidgetSupport.setTextSizeSp(views, R.id.widget_wide_meta, if (profile.isShort) 11f else 13f)

            views.setOnClickPendingIntent(
                R.id.widget_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, 60000 + appWidgetId),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun bindRow(
            views: RemoteViews,
            rowId: Int,
            timeId: Int,
            titleId: Int,
            course: TodayWidgetCourseInfo?,
            secondaryColor: Int,
            primaryColor: Int,
        ) {
            if (course == null) {
                views.setViewVisibility(rowId, View.GONE)
                return
            }
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setTextViewText(timeId, course.startTime + " - " + course.endTime)
            views.setTextViewText(titleId, course.name)
            views.setTextColor(timeId, secondaryColor)
            views.setTextColor(titleId, primaryColor)
        }
    }
}
