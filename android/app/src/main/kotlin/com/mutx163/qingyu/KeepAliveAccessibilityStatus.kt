package com.mutx163.qingyu

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager

object KeepAliveAccessibilityStatus {
    private const val TAG = "KeepAliveAccessibility"

    @Volatile
    private var runtimeConnected = false

    fun markServiceConnected(connected: Boolean) {
        runtimeConnected = connected
    }

    fun isEnabled(context: Context): Boolean {
        if (runtimeConnected) {
            return true
        }
        if (isEnabledViaAccessibilityManager(context)) {
            return true
        }
        return isEnabledViaSecureSettings(context)
    }

    private fun isEnabledViaAccessibilityManager(context: Context): Boolean {
        return try {
            val manager =
                context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
                    ?: return false
            val expectedComponentId = normalizedExpectedComponentId(context)
            manager.getEnabledAccessibilityServiceList(
                AccessibilityServiceInfo.FEEDBACK_ALL_MASK
            ).any { serviceInfo ->
                val resolvedService = serviceInfo.resolveInfo?.serviceInfo
                val resolvedComponentId = if (resolvedService != null) {
                    normalizeComponentId(
                        "${resolvedService.packageName}/${resolvedService.name}",
                        context.packageName,
                    )
                } else {
                    null
                }
                normalizeComponentId(serviceInfo.id, context.packageName) == expectedComponentId ||
                    resolvedComponentId == expectedComponentId
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to inspect enabled accessibility services", e)
            false
        }
    }

    private fun isEnabledViaSecureSettings(context: Context): Boolean {
        val accessibilityEnabled = try {
            Settings.Secure.getInt(
                context.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED,
                0,
            ) == 1
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read accessibility master switch", e)
            false
        }
        if (!accessibilityEnabled) {
            return false
        }
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val expectedComponentId = normalizedExpectedComponentId(context)
        return enabledServices
            .split(':')
            .map { normalizeComponentId(it, context.packageName) }
            .any { it == expectedComponentId }
    }

    private fun normalizedExpectedComponentId(context: Context): String {
        val component = ComponentName(context, KeepAliveAccessibilityService::class.java)
        return normalizeComponentId(component.flattenToString(), context.packageName)
    }

    private fun normalizeComponentId(rawComponentId: String, packageName: String): String {
        val normalized = rawComponentId.trim()
        val separatorIndex = normalized.indexOf('/')
        if (separatorIndex <= 0 || separatorIndex == normalized.length - 1) {
            return normalized
        }
        val componentPackage = normalized.substring(0, separatorIndex)
        val componentClass = normalized.substring(separatorIndex + 1)
        val resolvedClass = if (componentClass.startsWith(".")) {
            componentPackage + componentClass
        } else {
            componentClass
        }
        val resolvedPackage = componentPackage.ifBlank { packageName }
        return "$resolvedPackage/$resolvedClass"
    }
}
