package com.mutx163.qingyu

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class KeepAliveAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        KeepAliveAccessibilityStatus.markServiceConnected(true)
        Log.i("KeepAliveAccessibility", "Accessibility keep-alive service connected")
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "keep_alive_accessibility_connected",
            message = "Accessibility keep-alive service connected",
        )
        // Trigger an immediate widget refresh and ensure the WorkManager
        // periodic backup is scheduled, so widgets stay updated even when
        // AlarmManager alarms are suppressed by MIUI/HyperOS.
        try {
            TodayWidgetSupport.updateAll(applicationContext)
            HomeWidgetStorage.rescheduleRefresh(applicationContext)
            WidgetRefreshWorker.ensureScheduled(applicationContext)
        } catch (e: Exception) {
            Log.w("KeepAliveAccessibility", "Failed to refresh widget on connect", e)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 保持最小实现，不处理任何页面内容。
    }

    override fun onInterrupt() {
        Log.i("KeepAliveAccessibility", "Accessibility keep-alive service interrupted")
    }

    override fun onUnbind(intent: Intent?): Boolean {
        KeepAliveAccessibilityStatus.markServiceConnected(false)
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        KeepAliveAccessibilityStatus.markServiceConnected(false)
        super.onDestroy()
    }
}

