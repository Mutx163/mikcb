package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class HomeWidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                // Don't overwrite Flutter-synced snapshot with native-computed data.
                // TodayWidgetSupport.readSnapshot already falls back to native
                // computation when no synced snapshot exists.
                TodayWidgetSupport.updateAll(context)
                HomeWidgetStorage.rescheduleRefresh(context)
            }
        }
    }
}

