package com.example.university_timetable

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class TodayCompactWidgetProvider : AppWidgetProvider() {
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
                ComponentName(context, TodayCompactWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayCompactWidgetProvider::class.java)
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
            val views = RemoteViews(context.packageName, R.layout.widget_today_compact)
            val snapshot = TodayWidgetSupport.readSnapshot(context)
            val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
            val state = snapshot?.state ?: "no_course"
            val backgroundStyle = snapshot?.backgroundStyle ?: "solid"
            val primaryTextColor = TodayWidgetSupport.primaryTextColor(backgroundStyle)
            val secondaryTextColor = TodayWidgetSupport.secondaryTextColor(backgroundStyle)

            views.setInt(
                R.id.widget_card,
                "setBackgroundResource",
                TodayWidgetSupport.backgroundRes(
                    backgroundStyle,
                    snapshot?.cornerRadius ?: 28
                )
            )
            TodayWidgetSupport.applySquareishPadding(
                views,
                R.id.widget_root,
                profile,
                baseHorizontalDp = 14,
                baseVerticalDp = 14,
                heightAdjustmentDp = snapshot?.heightAdjustment ?: 0,
                targetAspect = 1f,
            )
            views.setTextViewText(R.id.widget_status, TodayWidgetSupport.statusText(state))
            views.setTextViewText(
                R.id.widget_course_name,
                when {
                    snapshot == null -> "今日无课"
                    state == "completed" -> "今天课程"
                    else -> TodayWidgetSupport.heroCourseName(snapshot)
                }
            )
            views.setTextViewText(
                R.id.widget_meta,
                when {
                    snapshot == null -> "点击打开首页"
                    state == "no_course" -> "留一点时间给自己"
                    state == "completed" -> "今天课程已经结束"
                    else -> TodayWidgetSupport.compactMetaText(snapshot)
                }
            )
            views.setTextColor(R.id.widget_status, secondaryTextColor)
            views.setTextColor(R.id.widget_course_name, primaryTextColor)
            views.setTextColor(R.id.widget_meta, secondaryTextColor)
            views.setInt(
                R.id.widget_status,
                "setBackgroundResource",
                TodayWidgetSupport.statusBackgroundRes(state, backgroundStyle)
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_status,
                if (profile.isNarrow || profile.isShort) 10f else 11f
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_course_name,
                when {
                    profile.isShort -> 16f
                    profile.isWide -> 19f
                    else -> 18f
                }
            )
            TodayWidgetSupport.setTextSizeSp(
                views,
                R.id.widget_meta,
                if (profile.isNarrow || profile.isShort) 11f else 12f
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                TodayWidgetSupport.buildLaunchPendingIntent(context, 10000 + appWidgetId)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
