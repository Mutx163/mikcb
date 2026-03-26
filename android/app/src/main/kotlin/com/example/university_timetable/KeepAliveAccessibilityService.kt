package com.example.university_timetable

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class KeepAliveAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i("KeepAliveAccessibility", "Accessibility keep-alive service connected")
        UmengDiagnosticReporter.record(
            context = applicationContext,
            category = "keep_alive_accessibility_connected",
            message = "Accessibility keep-alive service connected",
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 保持最小实现，不处理任何页面内容。
    }

    override fun onInterrupt() {
        Log.i("KeepAliveAccessibility", "Accessibility keep-alive service interrupted")
    }
}
