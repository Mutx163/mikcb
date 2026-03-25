package com.example.university_timetable

import android.content.Context
import android.util.Log
import com.umeng.umcrash.UMCrash
import java.util.concurrent.ConcurrentHashMap

object UmengDiagnosticReporter {
    private const val TAG = "UmengDiagnostic"
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_ACCEPTED_PRIVACY_POLICY = "flutter.accepted_privacy_policy"
    private const val THROTTLE_WINDOW_MILLIS = 2 * 60 * 1000L

    private val lastReportedAt = ConcurrentHashMap<String, Long>()

    fun report(
        context: Context,
        category: String,
        message: String,
        throwable: Throwable? = null,
        stackTrace: String? = null,
        dedupeKey: String = category,
        extras: Map<String, Any?> = emptyMap(),
    ) {
        if (!hasPrivacyConsent(context)) {
            return
        }
        UmengApplication.initializeAnalyticsIfNeeded(context.applicationContext)
        if (!UmengApplication.isAnalyticsInitialized()) {
            return
        }
        if (shouldThrottle(dedupeKey)) {
            return
        }

        try {
            val payload = buildString {
                appendLine("category=$category")
                appendLine("message=$message")
                if (extras.isNotEmpty()) {
                    appendLine("extras=")
                    extras.forEach { (key, value) ->
                        appendLine("  $key=${value ?: "null"}")
                    }
                }
                if (!stackTrace.isNullOrBlank()) {
                    appendLine("stackTrace=")
                    appendLine(stackTrace)
                }
                if (throwable != null) {
                    appendLine("throwable=")
                    appendLine(Log.getStackTraceString(throwable))
                }
            }.trim()

            UMCrash.generateCustomLog(payload, category.take(64))
        } catch (error: Exception) {
            Log.w(TAG, "Failed to upload Umeng diagnostic log", error)
        }
    }

    private fun hasPrivacyConsent(context: Context): Boolean {
        return context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_ACCEPTED_PRIVACY_POLICY, false)
    }

    private fun shouldThrottle(dedupeKey: String): Boolean {
        val now = System.currentTimeMillis()
        val last = lastReportedAt[dedupeKey]
        if (last != null && now - last < THROTTLE_WINDOW_MILLIS) {
            return true
        }
        lastReportedAt[dedupeKey] = now
        return false
    }
}
