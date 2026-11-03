package com.mutx163.qingyu.platform.permission

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * 权限流程的 Android 适配薄封装（有 `android.*` 依赖，不进 JVM 单测；逻辑判定在 [PermissionFlow]）。
 *
 * 各权限场景（天气定位 / 日程通知 / 相机 / 日历）共用的三个系统动作：
 * 查权限、查「还能不能问」、跳系统设置页。宿主不得自拼 Intent——
 * 跳设置这步历史上已在 `QrCameraHost` / `GuidePermissionProbe` 各抄过一份私有实现，
 * 新接线一律走这里，不再添第四份。
 */
object PermissionSystemActions {

    /** Android 13 对应的版本号（POST_NOTIFICATIONS 引入版）。 */
    private const val API_TIRAMISU = 33

    /** 一个运行时权限是否已授予。 */
    fun isGranted(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    /** 一组运行时权限是否至少授予了一个（天气定位 FINE/COARSE 二选一即算可用）。 */
    fun anyGranted(context: Context, vararg permissions: String): Boolean =
        permissions.any { isGranted(context, it) }

    /**
     * 通知是否可用：Android 13+ 看 POST_NOTIFICATIONS 运行时权限；
     * 低版本无此权限，看系统通知总开关（与旧版 `MainActivity.hasNotificationPermission` 同口径）。
     */
    fun notificationsGranted(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= API_TIRAMISU) {
            isGranted(context, Manifest.permission.POST_NOTIFICATIONS)
        } else {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        }

    /** 拒绝后系统是否还会再给弹框机会（`shouldShowRequestPermissionRationale` 的直译）。 */
    fun canAskAgain(activity: Activity, permission: String): Boolean =
        ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)

    /** 跳应用详情设置页（永久拒绝后的兜底出口）。返回是否成功拉起。 */
    fun openAppDetailsSettings(context: Context): Boolean = try {
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
        true
    } catch (_: Exception) {
        // 个别定制 ROM 没有应用详情页：不崩，文案里已告诉用户去哪开。
        false
    }

    /** 跳本应用的通知设置页（通知权限拒绝后的引导出口）。返回是否成功拉起。 */
    fun openNotificationSettings(context: Context): Boolean = try {
        context.startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
        true
    } catch (_: Exception) {
        openAppDetailsSettings(context)
    }

    /** 在 ContextWrapper 链上找宿主 Activity（launcher 回调里查 rationale 需要它）。 */
    fun findHostActivity(context: Context): Activity? {
        var current: Context? = context
        while (current is ContextWrapper) {
            if (current is Activity) return current
            current = current.baseContext
        }
        return null
    }
}
