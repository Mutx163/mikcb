package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * 今日课程横宽版 4×2：左栏当前/下一节课主信息，右栏接下来两节课列表。
 * 横向大矩形形态，与竖向"概览 2×4"互为补充。
 */
class TodayWideWidgetProvider : BaseQingyuWidgetProvider() {
    override fun providerClass(): Class<out BaseQingyuWidgetProvider> =
        TodayWideWidgetProvider::class.java

    companion object {
        fun updateAll(context: Context) {
            TodayWideWidgetProvider().updateAll(context)
        }
    }

    override fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today_wide)
        val snapshot = TodayWidgetSupport.readSnapshotForWidget(context, appWidgetId)
        val style = snapshot?.backgroundStyle ?: "solid"
        val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
        val primaryColor = TodayWidgetSupport.primaryTextColor(style, context)
        val secondaryColor = TodayWidgetSupport.secondaryTextColor(style, context)

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
            baseVerticalDp = 12,
            heightAdjustmentDp =
                snapshot?.heightAdjustment ?: TodayWidgetSupport.DEFAULT_HEIGHT_ADJUSTMENT_DP,
            targetAspect = 2f,
        )

        val state = snapshot?.state ?: "no_course"
        val displayState = if (snapshot != null) {
            TodayWidgetSupport.displayStatusState(snapshot)
        } else {
            state
        }
        val isExamOngoing = snapshot != null && TodayWidgetSupport.isExamOngoing(snapshot)
        val isShowingTomorrow = snapshot != null && TodayWidgetSupport.isShowingTomorrowCourses(snapshot)
        // 结束/无课且无明日可列：右栏没有任何行内容，整栏收起、左栏铺满全宽。
        val isSparseEnded = snapshot != null && !isExamOngoing && !isShowingTomorrow &&
            (state == "completed" || state == "no_course")

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
        views.setTextColor(
            R.id.widget_wide_status,
            TodayWidgetSupport.statusChipTextColor(displayState, style, context)
        )

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
            state == "no_course" ->
                if (isSparseEnded) {
                    TodayWidgetSupport.rightInfoText(context, snapshot)
                } else {
                    context.getString(R.string.widget_take_a_break)
                }
            state == "completed" ->
                if (isSparseEnded) {
                    TodayWidgetSupport.rightInfoText(context, snapshot)
                } else {
                    context.getString(R.string.widget_today_ended_short)
                }
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

        // 右栏列宽实测：卡片左右内边距共 32dp，两栏等分后再扣掉 16dp 栏间距。
        val rightColumnWidthDp = (profile.widthDp - 48) / 2f
        // 一行课目的时间串约需 80dp 列宽才不被裁掉。
        val showRightRows = rightColumnWidthDp >= 80f && !isSparseEnded
        // 无行内容（结束态/列宽不足）时整栏收起，避免只留孤立表头，
        // 同时把宽度让给左栏主信息。
        val showRightColumn = showRightRows
        val upcoming = if (snapshot == null || !showRightRows) {
            emptyList()
        } else {
            TodayWidgetSupport.secondaryCourses(snapshot, 2)
        }
        bindRow(views, R.id.widget_wide_row_1, R.id.widget_wide_row_1_time, R.id.widget_wide_row_1_title, upcoming.getOrNull(0), secondaryColor, primaryColor)
        bindRow(views, R.id.widget_wide_row_2, R.id.widget_wide_row_2_time, R.id.widget_wide_row_2_title, upcoming.getOrNull(1), secondaryColor, primaryColor)
        views.setViewVisibility(
            R.id.widget_wide_right,
            if (showRightColumn) View.VISIBLE else View.GONE,
        )

        // 自适应字号：矮高度压主课程字号；高度充裕时主副信息整体升档，
        // 配合弹性分布把卡面撑满。
        val tall = profile.heightDp >= 230
        TodayWidgetSupport.setTextSizeSp(views, R.id.widget_wide_status, if (profile.isShort) 10f else 11f)
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.widget_wide_course,
            when {
                profile.isShort -> 17f
                tall && profile.widthDp >= 320 -> 28f
                tall -> 26f
                profile.widthDp >= 320 -> 22f
                else -> 20f
            },
        )
        TodayWidgetSupport.setTextSizeSp(
            views,
            R.id.widget_wide_meta,
            if (profile.isShort) 11f else if (tall) 15f else 13f,
        )
        TodayWidgetSupport.setTextSizeSp(views, R.id.widget_wide_row_1_time, if (tall) 11f else 10f)
        TodayWidgetSupport.setTextSizeSp(views, R.id.widget_wide_row_1_title, if (tall) 15f else 13f)
        TodayWidgetSupport.setTextSizeSp(views, R.id.widget_wide_row_2_time, if (tall) 11f else 10f)
        TodayWidgetSupport.setTextSizeSp(views, R.id.widget_wide_row_2_title, if (tall) 15f else 13f)

        // 底部锚定信息行：档案名 · 今日 N 节 / 明日 N 节等，占住下边缘。
        views.setTextViewText(
            R.id.widget_wide_footer,
            if (snapshot != null) {
                TodayWidgetSupport.footerText(context, snapshot)
            } else {
                context.getString(R.string.widget_tap_to_open)
            },
        )
        views.setTextColor(R.id.widget_wide_footer, secondaryColor)
        TodayWidgetSupport.setTextSizeSp(views, R.id.widget_wide_footer, if (profile.isShort) 10f else 11f)

        views.setOnClickPendingIntent(
            R.id.widget_root,
            TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId),
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
