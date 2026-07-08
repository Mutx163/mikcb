package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class TodayMiniListWidgetProvider : AppWidgetProvider() {
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
            updateAll(context)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayMiniListWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_today_mini_list)
            val snapshot = TodayWidgetSupport.readSnapshot(context)
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val style = snapshot?.backgroundStyle ?: "solid"
            val primaryColor = TodayWidgetSupport.primaryTextColor(style)
            val secondaryColor = TodayWidgetSupport.secondaryTextColor(style)

            views.setInt(
                R.id.widget_mini_card,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(style, snapshot?.cornerRadius ?: 28)
            )
            TodayWidgetSupport.applySquareishPadding(
                views,
                R.id.widget_mini_root,
                profile,
                baseHorizontalDp = 10,
                baseVerticalDp = 10,
                heightAdjustmentDp = snapshot?.heightAdjustment ?: 0,
                targetAspect = 1f,
            )
            views.setTextColor(R.id.widget_mini_heading, secondaryColor)
            views.setTextColor(R.id.widget_mini_week, secondaryColor)
            views.setTextColor(R.id.widget_mini_empty, secondaryColor)
            views.setTextColor(R.id.widget_mini_more, secondaryColor)
            views.setInt(
                R.id.widget_mini_heading,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes(snapshot?.state ?: "no_course", style)
            )

            val isShowingTomorrow = snapshot != null
                && (snapshot.state == "completed" || snapshot.state == "no_course")
                && snapshot.tomorrowCourses.isNotEmpty()
            if (snapshot == null) {
                views.setTextViewText(R.id.widget_mini_heading, context.getString(R.string.widget_today_courses))
                views.setTextViewText(R.id.widget_mini_week, context.getString(R.string.widget_app_name))
                views.setViewVisibility(R.id.widget_mini_empty, View.VISIBLE)
                views.setViewVisibility(R.id.widget_mini_more, View.GONE)
                views.setTextViewText(R.id.widget_mini_empty, context.getString(R.string.widget_open_app_sync))
                bindRow(views, 0, null, primaryColor, secondaryColor, false, style)
                bindRow(views, 1, null, primaryColor, secondaryColor, false, style)
                bindRow(views, 2, null, primaryColor, secondaryColor, false, style)
            } else {
                views.setTextViewText(
                    R.id.widget_mini_heading,
                    if (isShowingTomorrow) {
                        context.getString(R.string.widget_tomorrow_courses)
                    } else {
                        context.getString(R.string.widget_today_courses)
                    }
                )
                views.setTextViewText(
                    R.id.widget_mini_week,
                    if (isShowingTomorrow) {
                        context.getString(R.string.widget_week_number, snapshot.tomorrowWeek)
                    } else {
                        context.getString(R.string.widget_week_number, snapshot.currentWeek)
                    }
                )
                val maxRows = TodayWidgetSupport.miniListVisibleRows(profile)
                val rows = if (isShowingTomorrow) {
                    snapshot.tomorrowCourses.take(maxRows)
                } else if (snapshot.state == "completed") {
                    emptyList()
                } else {
                    val highlighted = snapshot.highlightedCourse
                    val nowTime = java.text.SimpleDateFormat(
                        "HH:mm", java.util.Locale.getDefault()
                    ).format(java.util.Date())
                    val ordered = mutableListOf<TodayWidgetCourseInfo>()
                    if (highlighted != null) ordered.add(highlighted)
                    for (c in snapshot.visibleTodayCourses) {
                        if (c.id == highlighted?.id) continue
                        if (c.endTime > nowTime) ordered.add(c)
                    }
                    ordered.take(maxRows)
                }
                val emptyText = when {
                    rows.isNotEmpty() -> ""
                    snapshot.state == "completed" && snapshot.tomorrowCourses.isEmpty() ->
                        context.getString(R.string.widget_today_ended)
                    snapshot.state == "no_course" -> context.getString(R.string.widget_no_course_today)
                    else -> ""
                }
                views.setViewVisibility(
                    R.id.widget_mini_empty,
                    if (emptyText.isBlank()) View.GONE else View.VISIBLE
                )
                views.setTextViewText(R.id.widget_mini_empty, emptyText)
                val remainingCount = when {
                    isShowingTomorrow -> (snapshot.tomorrowCourses.size - rows.size).coerceAtLeast(0)
                    snapshot.state == "completed" -> 0
                    else -> (snapshot.visibleTodayCourses.size - rows.size).coerceAtLeast(0)
                }
                views.setViewVisibility(
                    R.id.widget_mini_more,
                    if (remainingCount > 0) View.VISIBLE else View.GONE
                )
                views.setTextViewText(
                    R.id.widget_mini_more,
                    context.getString(R.string.widget_more_courses, remainingCount),
                )
                bindRow(
                    views,
                    0,
                    rows.getOrNull(0),
                    primaryColor,
                    secondaryColor,
                    isShowingTomorrow,
                    style,
                )
                bindRow(
                    views,
                    1,
                    rows.getOrNull(1),
                    primaryColor,
                    secondaryColor,
                    false,
                    style,
                )
                bindRow(
                    views,
                    2,
                    if (maxRows >= 3) rows.getOrNull(2) else null,
                    primaryColor,
                    secondaryColor,
                    false,
                    style,
                )
            }

            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_mini_heading,
                if (profile.isNarrow || profile.isShort) 9f else 10f
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_mini_week,
                if (profile.isNarrow || profile.isShort) 9f else 10f
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_mini_empty,
                if (profile.isShort) 10f else 11f
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_mini_more,
                if (profile.isShort) 8f else 9f
            )

            views.setOnClickPendingIntent(
                R.id.widget_mini_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, 15000 + appWidgetId)
            )
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun bindRow(
            views: RemoteViews,
            index: Int,
            course: TodayWidgetCourseInfo?,
            primaryColor: Int,
            secondaryColor: Int,
            isHighlighted: Boolean,
            style: String,
            countdown: String? = null,
        ) {
            val rowIds = arrayOf(
                Triple(R.id.widget_mini_row_1, R.id.widget_mini_row_1_time, R.id.widget_mini_row_1_title),
                Triple(R.id.widget_mini_row_2, R.id.widget_mini_row_2_time, R.id.widget_mini_row_2_title),
                Triple(R.id.widget_mini_row_3, R.id.widget_mini_row_3_time, R.id.widget_mini_row_3_title),
            )
            val (rowId, timeId, titleId) = rowIds[index]
            if (course == null) {
                views.setViewVisibility(rowId, View.GONE)
                return
            }
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setInt(
                rowId,
                "setBackgroundResource",
                when {
                    !isHighlighted -> android.R.color.transparent
                    style == "gradient" -> R.drawable.widget_row_highlight_light
                    else -> R.drawable.widget_row_highlight
                }
            )
            views.setTextColor(timeId, if (isHighlighted) primaryColor else secondaryColor)
            views.setTextColor(titleId, primaryColor)
            TodayWidgetSupport.setTextSizeSp(views, timeId, 9f)
            TodayWidgetSupport.setTextSizeSp(views, titleId, 11f)
            views.setTextViewText(
                timeId,
                when {
                    countdown != null && course.location.isNotBlank() ->
                        "$countdown · ${course.location}"
                    countdown != null -> countdown
                    course.location.isNotBlank() ->
                        "${course.startTime} · ${course.location}"
                    else -> course.startTime
                }
            )
            views.setTextViewText(titleId, course.name)
        }
    }
}

