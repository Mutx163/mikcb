package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.RemoteViews

class TodayMediumWidgetProvider : BaseQingyuWidgetProvider() {
    override fun providerClass(): Class<out BaseQingyuWidgetProvider> =
        TodayMediumWidgetProvider::class.java

    companion object {
        fun updateAll(context: Context) {
            TodayMediumWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today_medium)
        val snapshot = TodayWidgetSupport.readSnapshotForWidget(context, appWidgetId)
        val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
        val style = snapshot?.backgroundStyle ?: "solid"
        val primaryColor = TodayWidgetSupport.primaryTextColor(style, context)
        val secondaryColor = TodayWidgetSupport.secondaryTextColor(style, context)

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
        // 课程色贯穿：主卡课程名左侧色条 + 课程名文字（档位关闭时恒回落中性色）。
        val accentCourse = if (snapshot == null || TodayWidgetSupport.isExamOngoing(snapshot)) {
            null
        } else if (TodayWidgetSupport.isShowingTomorrowCourses(snapshot)) {
            snapshot.tomorrowCourses.firstOrNull()
        } else {
            snapshot.highlightedCourse
        }
        TodayWidgetSupport.applyAccentBar(
            views,
            R.id.widget_medium_title_accent,
            TodayWidgetSupport.accentBar(snapshot, accentCourse, style, context),
        )
        views.setTextColor(
            R.id.widget_medium_title,
            TodayWidgetSupport.accentText(snapshot, accentCourse, style, context)
                ?: primaryColor,
        )
        views.setTextColor(R.id.widget_medium_time, primaryColor)
        views.setTextColor(R.id.widget_medium_meta, secondaryColor)
        views.setTextColor(R.id.widget_medium_exam, secondaryColor)
        views.setTextColor(R.id.widget_medium_footer, secondaryColor)
        val mediumStatusState = if (snapshot != null) {
            TodayWidgetSupport.displayStatusState(snapshot)
        } else {
            "no_course"
        }
        views.setTextColor(
            R.id.widget_medium_label,
            TodayWidgetSupport.accentText(snapshot, accentCourse, style, context)
                ?: TodayWidgetSupport.statusChipTextColor(
                    mediumStatusState,
                    style,
                    context,
                )
        )
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
            TodayWidgetSupport.applyAccentBar(views, R.id.widget_medium_row_1_accent, null)
            TodayWidgetSupport.applyAccentBar(views, R.id.widget_medium_row_2_accent, null)
            TodayWidgetSupport.applyAccentBar(views, R.id.widget_medium_row_3_accent, null)
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
            bindRow(views, 0, secondaryCourses.getOrNull(0), primaryColor, secondaryColor, snapshot, context, style)
            bindRow(views, 1, secondaryCourses.getOrNull(1), primaryColor, secondaryColor, snapshot, context, style)
            bindRow(views, 2, secondaryCourses.getOrNull(2), primaryColor, secondaryColor, snapshot, context, style)
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
            TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId)
        )
        appWidgetManager.updateAppWidget(appWidgetId, views)
        }

    private fun bindRow(
        views: RemoteViews,
        index: Int,
        course: TodayWidgetCourseInfo?,
        primaryColor: Int,
        secondaryColor: Int,
        snapshot: TodayWidgetSnapshotInfo? = null,
        context: Context? = null,
        style: String = "solid",
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
        val barId = when (index) {
            0 -> R.id.widget_medium_row_1_accent
            1 -> R.id.widget_medium_row_2_accent
            else -> R.id.widget_medium_row_3_accent
        }
        TodayWidgetSupport.applyAccentBar(
            views,
            barId,
            if (context == null) {
                null
            } else {
                TodayWidgetSupport.accentBar(snapshot, course, style, context)
            },
        )
        views.setTextColor(
            titleId,
            if (context == null) {
                primaryColor
            } else {
                TodayWidgetSupport.accentText(snapshot, course, style, context)
                    ?: primaryColor
            },
        )
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
