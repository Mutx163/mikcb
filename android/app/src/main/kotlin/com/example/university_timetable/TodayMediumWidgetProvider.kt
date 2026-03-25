package com.example.university_timetable

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class TodayMediumWidgetProvider : AppWidgetProvider() {
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
                ComponentName(context, TodayMediumWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_today_medium)
            val snapshot = TodayWidgetSupport.readSnapshot(context)
            val style = snapshot?.backgroundStyle ?: "solid"
            val primaryColor = TodayWidgetSupport.primaryTextColor(style)
            val secondaryColor = TodayWidgetSupport.secondaryTextColor(style)

            views.setInt(
                R.id.widget_medium_root,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(style)
            )
            views.setTextColor(R.id.widget_medium_label, secondaryColor)
            views.setTextColor(R.id.widget_medium_title, primaryColor)
            views.setTextColor(R.id.widget_medium_time, primaryColor)
            views.setTextColor(R.id.widget_medium_meta, secondaryColor)
            views.setTextColor(R.id.widget_medium_footer, secondaryColor)
            views.setInt(
                R.id.widget_medium_label,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes(snapshot?.state ?: "no_course", style)
            )

            if (snapshot == null) {
                views.setTextViewText(R.id.widget_medium_label, "今日课程")
                views.setTextViewText(R.id.widget_medium_title, "今日无课")
                views.setTextViewText(R.id.widget_medium_time, "稍后打开应用同步")
                views.setTextViewText(R.id.widget_medium_meta, "轻屿课表")
                views.setTextViewText(R.id.widget_medium_footer, "点击打开首页")
                setRowVisibility(views, false, false, false)
            } else {
                views.setTextViewText(
                    R.id.widget_medium_label,
                    TodayWidgetSupport.statusText(snapshot.state)
                )
                views.setTextViewText(
                    R.id.widget_medium_title,
                    TodayWidgetSupport.heroCourseName(snapshot)
                )
                views.setTextViewText(
                    R.id.widget_medium_time,
                    TodayWidgetSupport.heroTimeText(snapshot)
                )
                views.setTextViewText(
                    R.id.widget_medium_meta,
                    TodayWidgetSupport.heroMetaText(snapshot)
                )
                views.setTextViewText(
                    R.id.widget_medium_footer,
                    TodayWidgetSupport.footerText(snapshot)
                )

                val secondaryCourses = TodayWidgetSupport.secondaryCourses(snapshot, 3)
                bindRow(views, 0, secondaryCourses.getOrNull(0), primaryColor, secondaryColor)
                bindRow(views, 1, secondaryCourses.getOrNull(1), primaryColor, secondaryColor)
                bindRow(views, 2, secondaryCourses.getOrNull(2), primaryColor, secondaryColor)
            }

            views.setOnClickPendingIntent(
                R.id.widget_medium_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, 20000 + appWidgetId)
            )
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun bindRow(
            views: RemoteViews,
            index: Int,
            course: TodayWidgetCourseInfo?,
            primaryColor: Int,
            secondaryColor: Int,
        ) {
            val rowIds = arrayOf(
                Triple(R.id.widget_medium_row_1, R.id.widget_medium_row_1_time, R.id.widget_medium_row_1_title),
                Triple(R.id.widget_medium_row_2, R.id.widget_medium_row_2_time, R.id.widget_medium_row_2_title),
                Triple(R.id.widget_medium_row_3, R.id.widget_medium_row_3_time, R.id.widget_medium_row_3_title),
            )
            val (rowId, timeId, titleId) = rowIds[index]
            if (course == null) {
                views.setViewVisibility(rowId, View.GONE)
                return
            }
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setTextColor(timeId, secondaryColor)
            views.setTextColor(titleId, primaryColor)
            views.setTextViewText(timeId, "${course.startTime} - ${course.endTime}")
            views.setTextViewText(titleId, course.name)
        }

        private fun setRowVisibility(
            views: RemoteViews,
            row1: Boolean,
            row2: Boolean,
            row3: Boolean,
        ) {
            views.setViewVisibility(R.id.widget_medium_row_1, if (row1) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_medium_row_2, if (row2) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_medium_row_3, if (row3) View.VISIBLE else View.GONE)
        }
    }
}
