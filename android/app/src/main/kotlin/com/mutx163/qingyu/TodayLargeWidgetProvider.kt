package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.RemoteViews

class TodayLargeWidgetProvider : BaseQingyuWidgetProvider() {
    override fun providerClass(): Class<out BaseQingyuWidgetProvider> =
        TodayLargeWidgetProvider::class.java

    companion object {
        fun updateAll(context: Context) {
            TodayLargeWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today_large)
        val snapshot = TodayWidgetSupport.readSnapshotForWidget(context, appWidgetId)
        val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
        val style = snapshot?.backgroundStyle ?: "solid"
        val primaryColor = TodayWidgetSupport.primaryTextColor(style, context)
        val secondaryColor = TodayWidgetSupport.secondaryTextColor(style, context)

        views.setInt(
            R.id.widget_large_card,
            "setBackgroundResource",
            TodayWidgetSupport.backgroundRes(
                style,
                snapshot?.cornerRadius ?: TodayWidgetSupport.DEFAULT_CORNER_RADIUS_DP,
            )
        )
        TodayWidgetSupport.applyAdaptiveVerticalPadding(
            views,
            R.id.widget_large_root,
            profile,
            baseVerticalDp = 14,
            heightAdjustmentDp =
                snapshot?.heightAdjustment ?: TodayWidgetSupport.DEFAULT_HEIGHT_ADJUSTMENT_DP,
            targetAspect = 1f,
        )
        views.setTextColor(R.id.widget_large_heading, secondaryColor)
        views.setTextColor(R.id.widget_large_week, secondaryColor)
        views.setTextColor(R.id.widget_large_title, primaryColor)
        views.setTextColor(R.id.widget_large_subtitle, secondaryColor)
        views.setTextColor(R.id.widget_large_exam, secondaryColor)
        views.setTextColor(R.id.widget_large_empty, secondaryColor)
        val largeStatusState = if (snapshot != null) {
            TodayWidgetSupport.displayStatusState(snapshot)
        } else {
            "no_course"
        }
        views.setInt(
            R.id.widget_large_heading,
            "setBackgroundResource",
            TodayWidgetSupport.statusBackgroundRes(largeStatusState, style)
        )

        if (snapshot == null) {
            views.setTextViewText(R.id.widget_large_heading, context.getString(R.string.widget_today_courses))
            views.setTextViewText(R.id.widget_large_week, context.getString(R.string.widget_app_name))
            views.setTextViewText(R.id.widget_large_title, context.getString(R.string.widget_today_list_title))
            views.setTextViewText(R.id.widget_large_subtitle, context.getString(R.string.widget_snapshot_hint))
            views.setViewVisibility(R.id.widget_large_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_large_empty, context.getString(R.string.widget_tap_to_open))
            views.setViewVisibility(R.id.widget_large_exam, View.GONE)
            setCourseRows(views, emptyList(), primaryColor, secondaryColor)
        } else {
            val isExamOngoing = TodayWidgetSupport.isExamOngoing(snapshot)
            val isShowingTomorrow = TodayWidgetSupport.isShowingTomorrowCourses(snapshot)
            views.setTextViewText(R.id.widget_large_heading, TodayWidgetSupport.headingText(context, snapshot))
            views.setTextViewText(
                R.id.widget_large_week,
                TodayWidgetSupport.rightInfoText(context, snapshot)
            )
            views.setTextViewText(
                R.id.widget_large_title,
                when {
                    isExamOngoing ->
                        TodayWidgetSupport.examDisplayName(snapshot)
                            ?: context.getString(R.string.widget_exam_fallback_name)
                    snapshot.state == "holiday" ->
                        snapshot.holidayName ?: context.getString(R.string.widget_on_holiday)
                    isShowingTomorrow -> context.getString(R.string.widget_tomorrow_list_title)
                    else -> context.getString(R.string.widget_today_list_title)
                }
            )
            views.setTextViewText(
                R.id.widget_large_subtitle,
                when {
                    isExamOngoing -> TodayWidgetSupport.examOngoingMetaText(context, snapshot)
                    snapshot.state == "holiday" -> context.getString(R.string.widget_rest_well)
                    isShowingTomorrow -> TodayWidgetSupport.footerText(context, snapshot)
                    snapshot.state == "no_course" -> context.getString(R.string.widget_no_schedule_today)
                    snapshot.state == "completed" -> TodayWidgetSupport.footerText(context, snapshot)
                    else -> TodayWidgetSupport.countdownText(context, snapshot)
                        ?: TodayWidgetSupport.footerText(context, snapshot)
                }
            )
            val emptyText = when {
                isExamOngoing -> ""
                isShowingTomorrow -> ""
                snapshot.state == "completed" && snapshot.tomorrowCourses.isEmpty() ->
                    context.getString(R.string.widget_today_ended)
                snapshot.state == "no_course" -> context.getString(R.string.widget_no_course_today)
                else -> ""
            }
            views.setViewVisibility(
                R.id.widget_large_empty,
                if (emptyText.isBlank()) View.GONE else View.VISIBLE
            )
            views.setTextViewText(R.id.widget_large_empty, emptyText)
            val examText = if (isExamOngoing) {
                null
            } else {
                TodayWidgetSupport.examCountdownText(context, snapshot)
            }
            if (examText != null) {
                views.setViewVisibility(R.id.widget_large_exam, View.VISIBLE)
                views.setTextViewText(R.id.widget_large_exam, examText)
            } else {
                views.setViewVisibility(R.id.widget_large_exam, View.GONE)
            }
            setCourseRows(
                views,
                when {
                    isExamOngoing -> emptyList()
                    isShowingTomorrow ->
                        snapshot.tomorrowCourses.take(TodayWidgetSupport.largeVisibleRows(profile))
                    snapshot.state == "completed" -> emptyList()
                    else ->
                        snapshot.visibleTodayCourses.take(
                            TodayWidgetSupport.largeVisibleRows(profile)
                        )
                },
                primaryColor,
                secondaryColor
            )
        }

        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.widget_large_heading,
            if (profile.isNarrow || profile.isShort) 10f else 11f
        )
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.widget_large_week,
            if (profile.isNarrow || profile.isShort) 10f else 11f
        )
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.widget_large_title,
            if (profile.isShort) 16f else 18f
        )
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.widget_large_subtitle,
            if (profile.isShort) 11f else 12f
        )
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.widget_large_empty,
            if (profile.isShort) 11f else 12f
        )

        views.setOnClickPendingIntent(
            R.id.widget_large_root,
            TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId)
        )
        appWidgetManager.updateAppWidget(appWidgetId, views)
        }

    private fun setCourseRows(
        views: RemoteViews,
        courses: List<TodayWidgetCourseInfo>,
        primaryColor: Int,
        secondaryColor: Int,
    ) {
        val rowIds = arrayOf(
            Triple(R.id.widget_large_row_1, R.id.widget_large_row_1_time, R.id.widget_large_row_1_title),
            Triple(R.id.widget_large_row_2, R.id.widget_large_row_2_time, R.id.widget_large_row_2_title),
            Triple(R.id.widget_large_row_3, R.id.widget_large_row_3_time, R.id.widget_large_row_3_title),
            Triple(R.id.widget_large_row_4, R.id.widget_large_row_4_time, R.id.widget_large_row_4_title),
            Triple(R.id.widget_large_row_5, R.id.widget_large_row_5_time, R.id.widget_large_row_5_title),
        )
        rowIds.forEachIndexed { index, triple ->
            val (rowId, timeId, titleId) = triple
            val course = courses.getOrNull(index)
            if (course == null) {
                views.setViewVisibility(rowId, View.GONE)
            } else {
                views.setViewVisibility(rowId, View.VISIBLE)
                views.setTextColor(timeId, secondaryColor)
                views.setTextColor(titleId, primaryColor)
                views.setTextViewText(timeId, "${course.startTime} - ${course.endTime}")
                val title = if (course.location.isNotBlank()) {
                    "${course.name} · ${course.location}"
                } else {
                    course.name
                }
                views.setTextViewText(titleId, title)
            }
        }
    }
}
