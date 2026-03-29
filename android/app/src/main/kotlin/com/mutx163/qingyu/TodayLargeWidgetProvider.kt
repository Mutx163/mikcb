package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class TodayLargeWidgetProvider : AppWidgetProvider() {
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
                ComponentName(context, TodayLargeWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_today_large)
            val snapshot = TodayWidgetSupport.readSnapshot(context)
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val style = snapshot?.backgroundStyle ?: "solid"
            val primaryColor = TodayWidgetSupport.primaryTextColor(style)
            val secondaryColor = TodayWidgetSupport.secondaryTextColor(style)

            views.setInt(
                R.id.widget_large_card,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(style, snapshot?.cornerRadius ?: 28)
            )
            TodayWidgetSupport.applySquareishPadding(
                views,
                R.id.widget_large_root,
                profile,
                baseHorizontalDp = 14,
                baseVerticalDp = 14,
                heightAdjustmentDp = snapshot?.heightAdjustment ?: 0,
                targetAspect = 1f,
            )
            views.setTextColor(R.id.widget_large_heading, secondaryColor)
            views.setTextColor(R.id.widget_large_week, secondaryColor)
            views.setTextColor(R.id.widget_large_title, primaryColor)
            views.setTextColor(R.id.widget_large_subtitle, secondaryColor)
            views.setTextColor(R.id.widget_large_empty, secondaryColor)
            views.setInt(
                R.id.widget_large_heading,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes(snapshot?.state ?: "no_course", style)
            )

            if (snapshot == null) {
                views.setTextViewText(R.id.widget_large_heading, "今日课程")
                views.setTextViewText(R.id.widget_large_week, "轻屿课表")
                views.setTextViewText(R.id.widget_large_title, "今日课程列表")
                views.setTextViewText(R.id.widget_large_subtitle, "打开应用后会生成今天的课程快照")
                views.setViewVisibility(R.id.widget_large_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_large_empty, "点击打开首页")
                setCourseRows(views, emptyList(), primaryColor, secondaryColor)
            } else {
                views.setTextViewText(R.id.widget_large_heading, "今日课程")
                views.setTextViewText(R.id.widget_large_week, "第${snapshot.currentWeek}周")
                views.setTextViewText(R.id.widget_large_title, "今日课程列表")
                views.setTextViewText(
                    R.id.widget_large_subtitle,
                    when (snapshot.state) {
                        "no_course" -> "今天没有课程安排"
                        "completed" -> TodayWidgetSupport.footerText(snapshot)
                        else -> TodayWidgetSupport.footerText(snapshot)
                    }
                )
                val emptyText = when (snapshot.state) {
                    "completed" -> "今天课程已结束"
                    "no_course" -> "今日无课"
                    else -> ""
                }
                views.setViewVisibility(
                    R.id.widget_large_empty,
                    if (emptyText.isBlank()) View.GONE else View.VISIBLE
                )
                views.setTextViewText(R.id.widget_large_empty, emptyText)
                setCourseRows(
                    views,
                    if (snapshot.state == "completed") {
                        emptyList()
                    } else {
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
                TodayWidgetSupport.buildLaunchPendingIntent(context, 30000 + appWidgetId)
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
}

