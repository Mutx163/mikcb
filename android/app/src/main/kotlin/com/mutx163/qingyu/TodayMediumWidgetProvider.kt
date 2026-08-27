package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class TodayMediumWidgetProvider : AppWidgetProvider() {
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
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val style = snapshot?.backgroundStyle ?: "solid"
            val primaryColor = TodayWidgetSupport.primaryTextColor(style)
            val secondaryColor = TodayWidgetSupport.secondaryTextColor(style)

            views.setInt(
                R.id.widget_medium_card,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(
                    style,
                    snapshot?.cornerRadius ?: TodayWidgetSupport.DEFAULT_CORNER_RADIUS_DP,
                )
            )
            TodayWidgetSupport.applyAdaptiveVerticalPadding(
                views,
                R.id.widget_medium_root,
                profile,
                baseVerticalDp = 14,
                heightAdjustmentDp =
                    snapshot?.heightAdjustment ?: TodayWidgetSupport.DEFAULT_HEIGHT_ADJUSTMENT_DP,
                targetAspect = 0.5f,
            )
            views.setTextColor(R.id.widget_medium_label, secondaryColor)
            views.setTextColor(R.id.widget_medium_title, primaryColor)
            views.setTextColor(R.id.widget_medium_time, primaryColor)
            views.setTextColor(R.id.widget_medium_meta, secondaryColor)
            views.setTextColor(R.id.widget_medium_exam, secondaryColor)
            views.setTextColor(R.id.widget_medium_footer, secondaryColor)
            val mediumStatusState = if (snapshot != null) {
                TodayWidgetSupport.displayStatusState(snapshot)
            } else {
                "no_course"
            }
            views.setInt(
                R.id.widget_medium_label,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes(mediumStatusState, style)
            )

            if (snapshot == null) {
                views.setTextViewText(R.id.widget_medium_label, context.getString(R.string.widget_today_courses))
                views.setTextViewText(R.id.widget_medium_title, context.getString(R.string.widget_no_course_today))
                views.setTextViewText(R.id.widget_medium_time, context.getString(R.string.widget_sync_later))
                views.setTextViewText(R.id.widget_medium_meta, context.getString(R.string.widget_app_name))
                views.setTextViewText(R.id.widget_medium_footer, context.getString(R.string.widget_tap_to_open))
                views.setViewVisibility(R.id.widget_medium_exam, View.GONE)
                setRowVisibility(views, false, false, false)
            } else {
                val isExamOngoing = TodayWidgetSupport.isExamOngoing(snapshot)
                val isShowingTomorrow = TodayWidgetSupport.isShowingTomorrowCourses(snapshot)
                views.setTextViewText(
                    R.id.widget_medium_label,
                    TodayWidgetSupport.displayStatusText(context, snapshot)
                )
                views.setTextViewText(
                    R.id.widget_medium_title,
                    if (isExamOngoing) {
                        TodayWidgetSupport.examDisplayName(snapshot)
                            ?: context.getString(R.string.widget_exam_fallback_name)
                    } else {
                        TodayWidgetSupport.heroCourseName(context, snapshot)
                    }
                )
                views.setTextViewText(
                    R.id.widget_medium_time,
                    when {
                        isExamOngoing -> TodayWidgetSupport.examOngoingMetaText(context, snapshot)
                        isShowingTomorrow -> TodayWidgetSupport.heroTimeText(context, snapshot)
                        else -> TodayWidgetSupport.countdownText(context, snapshot)
                            ?: TodayWidgetSupport.heroTimeText(context, snapshot)
                    }
                )
                views.setTextViewText(
                    R.id.widget_medium_meta,
                    if (isExamOngoing) {
                        val rawLocation = snapshot.nextExamLocation.orEmpty()
                        if (rawLocation.isNotBlank() && !rawLocation.equals("null", ignoreCase = true)) {
                            rawLocation
                        } else {
                            context.getString(R.string.widget_status_exam_ongoing)
                        }
                    } else {
                        TodayWidgetSupport.heroMetaText(context, snapshot)
                    }
                )
                views.setTextViewText(
                    R.id.widget_medium_footer,
                    TodayWidgetSupport.footerText(context, snapshot)
                )
                // Primary chrome already shows live exam; avoid duplicating the exam line.
                val examText = if (isExamOngoing) {
                    null
                } else {
                    TodayWidgetSupport.examCountdownText(context, snapshot)
                }
                if (examText != null) {
                    views.setViewVisibility(R.id.widget_medium_exam, View.VISIBLE)
                    views.setTextViewText(R.id.widget_medium_exam, examText)
                } else {
                    views.setViewVisibility(R.id.widget_medium_exam, View.GONE)
                }

                val secondaryCourses = TodayWidgetSupport.secondaryCourses(
                    snapshot,
                    TodayWidgetSupport.mediumVisibleRows(profile)
                )
                bindRow(views, 0, secondaryCourses.getOrNull(0), primaryColor, secondaryColor)
                bindRow(views, 1, secondaryCourses.getOrNull(1), primaryColor, secondaryColor)
                bindRow(views, 2, secondaryCourses.getOrNull(2), primaryColor, secondaryColor)
            }

            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_medium_label,
                if (profile.isNarrow || profile.isShort) 10f else 11f
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_medium_title,
                if (profile.isShort) 15f else 17f
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_medium_time,
                if (snapshot != null && TodayWidgetSupport.countdownText(context, snapshot) != null) {
                    if (profile.isShort) 13f else 14f
                } else if (profile.isShort) 13f else 14f
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_medium_meta,
                if (profile.isShort) 11f else 12f
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_medium_footer,
                if (profile.isShort) 9f else 10f
            )

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

