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


    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        // 卡片被移除时清掉绑定档案与专属快照，防止孤儿数据越积越多。
        appWidgetIds.forEach { appWidgetId ->
            WidgetBindingStore.remove(context, appWidgetId)
            HomeWidgetStorage.clearWidgetSnapshot(context, appWidgetId)
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
            val snapshot = TodayWidgetSupport.readSnapshotForWidget(context, appWidgetId)
            val style = snapshot?.backgroundStyle ?: "solid"
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val primaryColor = TodayWidgetSupport.primaryTextColor(style)
            val secondaryColor = TodayWidgetSupport.secondaryTextColor(style)

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
                baseVerticalDp = 8,
                heightAdjustmentDp =
                    snapshot?.heightAdjustment ?: TodayWidgetSupport.DEFAULT_HEIGHT_ADJUSTMENT_DP,
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
                // 结束态（走不到明日分支）：meta 不再重复「已经结束」，
                // 改为今日节数摘要，与标题形成信息互补。
                state == "completed" ->
                    if (snapshot.totalTodayCourseCount > 0) {
                        context.getString(R.string.widget_today_count, snapshot.totalTodayCourseCount)
                    } else {
                        ""
                    }
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
            val compact = profile.isShort
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_strip_status,
                if (compact) 10f else 11f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_strip_course,
                if (compact) 13f else 15f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_strip_meta,
                if (compact) 10f else 12f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_strip_week,
                if (compact) 10f else 11f,
            )
            // 收起门限按当前字号档的实测需求设定：单行里 chip / 时间 / 周数都是
            // wrap_content，会先于加权的课程名被满足，宽度不足时若仍显示尾部
            // 视图，被裁掉的是它们而不是课程名（课程名另有 48dp 保底）。
            val metaMinWidthDp = if (compact) 260 else 300
            val weekMinWidthDp = if (compact) 330 else 380
            views.setViewVisibility(
                R.id.widget_strip_week,
                if (profile.widthDp < weekMinWidthDp) View.GONE else View.VISIBLE,
            )
            views.setViewVisibility(
                R.id.widget_strip_meta,
                if (profile.widthDp < metaMinWidthDp) View.GONE else View.VISIBLE,
            )

            views.setViewVisibility(
                R.id.strip_sub_row,
                if (profile.heightDp >= 92) View.VISIBLE else View.GONE,
            )
            // 第二行补充信息：进行中→地点；明日可列→首课地点；
            // 结束且无明日→周数+日期。与主行各字段互不重复。
            if (snapshot != null && profile.heightDp >= 92) {
                val subLeft = when {
                    state == "holiday" -> ""
                    isExamOngoing ->
                        snapshot.nextExamLocation.orEmpty()
                            .takeIf { snapshot.showLocation && it.isNotBlank() } ?: ""
                    state == "ongoing" || state == "upcoming" ->
                        snapshot.highlightedCourse?.location
                            ?.takeIf { snapshot.showLocation && it.isNotBlank() } ?: ""
                    isShowingTomorrow ->
                        snapshot.tomorrowCourses.firstOrNull()?.location
                            ?.takeIf { snapshot.showLocation && it.isNotBlank() } ?: ""
                    else -> TodayWidgetSupport.rightInfoText(context, snapshot)
                }
                views.setTextViewText(R.id.strip_sub_left, subLeft)
                views.setTextColor(R.id.strip_sub_left, secondaryColor)
            }
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.strip_sub_left,
                if (compact) 10f else 11f,
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.strip_sub_right,
                if (compact) 10f else 11f,
            )

            // 第三行：高度充裕时放延伸信息——进行中→明日首课预告；
            // 已结束且明日可列→明日第二节；考试期→考试倒计时行。
            val sub2Text = if (profile.heightDp >= 150 && snapshot != null) {
                when {
                    state == "holiday" -> ""
                    isExamOngoing ->
                        TodayWidgetSupport.examCountdownText(context, snapshot) ?: ""
                    state == "ongoing" || state == "upcoming" ->
                        snapshot.tomorrowCourses.firstOrNull()?.let {
                            context.getString(R.string.widget_tomorrow_courses) + " " + it.startTime
                        } ?: ""
                    isShowingTomorrow ->
                        snapshot.tomorrowCourses.getOrNull(1)?.let { it.startTime + " " + it.name } ?: ""
                    else -> ""
                }
            } else {
                ""
            }
            views.setViewVisibility(
                R.id.strip_sub2,
                if (sub2Text.isNotBlank()) View.VISIBLE else View.GONE,
            )
            views.setTextViewText(R.id.strip_sub2, sub2Text)
            views.setTextColor(R.id.strip_sub2, secondaryColor)
            TodayWidgetSupport.setTextSizeSp(views, R.id.strip_sub2, if (compact) 10f else 11f)

            views.setOnClickPendingIntent(
                R.id.widget_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, appWidgetId),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
