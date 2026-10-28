package com.mutx163.qingyu.platform.guide

import android.Manifest
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.mutx163.qingyu.KeepAliveAccessibilityService
import com.mutx163.qingyu.KeepAliveAccessibilityStatus
import com.mutx163.qingyu.UmengDiagnosticReporter
import com.mutx163.qingyu.pages.guide.GuidePermissionAction
import com.mutx163.qingyu.pages.guide.GuidePermissionState
import java.util.Locale

/**
 * 引导页「系统权限」页的**真实平台探针**（纯 Android 层，不进 JVM 单测 classpath）。
 *
 * 把 Dart 原版 `lib/screens/user_guide_screen.dart` 依赖的 6 项系统状态探测 / 设置跳转
 * 集中到一个 object 里，供宿主（`ShellPageIndex`）注入给渲染层：
 * - [probe] 一次性读齐 6 项状态，产出 [GuidePermissionState]；
 * - [open] 按行点击的 [GuidePermissionAction] 拉起对应系统设置页，全部 `runCatching` 兜底不崩。
 *
 * 探测/跳转逻辑照抄 `MainActivity.kt`（那里是 private 方法，这里复制必要实现，**不改 MainActivity**）：
 * 通知（:1938）、超级岛（:1983/2255/2275）、自启动（:2526 → `UmengDiagnosticReporter`）、
 * 电池（:1992）、保活（:2532 → `KeepAliveAccessibilityStatus`）、勿扰（:2505）。
 *
 * 通知 / 焦点通知 / 无障碍 / 勿扰等检测与跳转都用 `applicationContext`，因为宿主可能从
 * 非 Activity 上下文调用；`startActivity` 一律加 `FLAG_ACTIVITY_NEW_TASK`。
 */
object GuidePermissionProbe {

    private const val TAG = "GuidePermissionProbe"

    /** `POST_PROMOTED_NOTIFICATIONS`（与 MainActivity 的私有常量同值）。 */
    private const val POST_PROMOTED_NOTIFICATIONS_PERMISSION =
        "android.permission.POST_PROMOTED_NOTIFICATIONS"

    /** 一次性读齐 6 项真实权限状态（全部非 null，探测完即 [GuidePermissionState.isLoading] == false）。 */
    fun probe(context: Context): GuidePermissionState {
        val app = context.applicationContext
        return GuidePermissionState(
            notification = probeNotification(app),
            promotedIsland = canPostPromotedNotifications(app),
            promotedDeclared = isPromotedPermissionDeclared(app),
            // resolveAutoStartStatus 返回 allowed/denied/unknown；unknown 乐观视为开启（同 Dart 引导页）。
            autoStart = UmengDiagnosticReporter.resolveAutoStartStatus(app) != "denied",
            batteryUnrestricted = isIgnoringBatteryOptimizations(app),
            keepAliveAccessibility = KeepAliveAccessibilityStatus.isEnabled(app),
            doNotDisturbAccess = isDoNotDisturbAccessGranted(app),
        )
    }

    /** 点某一行 → 拉起对应系统设置页（不会抛异常）。 */
    fun open(context: Context, action: GuidePermissionAction) {
        val app = context.applicationContext
        runCatching {
            when (action) {
                GuidePermissionAction.Notification -> openNotificationSettings(app)
                GuidePermissionAction.PromotedIsland -> openPromotedSettings(app)
                GuidePermissionAction.AutoStart -> openAutoStartSettings(app)
                GuidePermissionAction.Battery -> openBatteryOptimizationSettings(app)
                GuidePermissionAction.KeepAliveAccessibility -> openAccessibilitySettings(app)
                GuidePermissionAction.DoNotDisturbAccess -> openDoNotDisturbAccessSettings(app)
            }
        }.onFailure { Log.w(TAG, "打开权限设置页失败：$action", it) }
    }

    // ---------------------------------------------------------------- 探测

    private fun probeNotification(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        }
    }

    private fun canPostPromotedNotifications(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 36) return false
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return false
        return manager.canPostPromotedNotifications()
    }

    private fun isPromotedPermissionDeclared(context: Context): Boolean {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_PERMISSIONS,
                )
            }
            packageInfo.requestedPermissions?.contains(POST_PROMOTED_NOTIFICATIONS_PERMISSION) == true
        } catch (e: Exception) {
            Log.w(TAG, "读取超级岛权限声明失败", e)
            false
        }
    }

    private fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        return powerManager?.isIgnoringBatteryOptimizations(context.packageName) == true
    }

    private fun isDoNotDisturbAccessGranted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        return manager?.isNotificationPolicyAccessGranted == true
    }

    // ---------------------------------------------------------------- 跳转设置

    private fun openNotificationSettings(context: Context) {
        try {
            context.startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                },
            )
        } catch (e: Exception) {
            Log.w(TAG, "打开通知设置失败", e)
            openAppDetailsSettings(context)
        }
    }

    private fun openPromotedSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= 36) {
            try {
                context.startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    },
                )
                return
            } catch (_: ActivityNotFoundException) {
                // 落到通知设置。
            } catch (_: Exception) {
                // 落到通知设置。
            }
        }
        openNotificationSettings(context)
    }

    private fun openAutoStartSettings(context: Context) {
        val brand = Build.BRAND.lowercase(Locale.ROOT)
        val intents = mutableListOf<Intent>()

        when (brand) {
            "xiaomi", "poco", "redmi" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity",
                    )
                }
                intents += Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                    component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.permissions.PermissionsEditorActivity",
                    )
                    putExtra("extra_pkgname", context.packageName)
                    putExtra("package_name", context.packageName)
                }
            }
            "oppo", "realme", "oneplus" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.oppo.safe",
                        "com.oppo.safe.permission.startup.StartupAppListActivity",
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.startupapp.StartupAppListActivity",
                    )
                }
                if (brand == "oneplus") {
                    intents += Intent().apply {
                        component = ComponentName(
                            "com.oneplus.security",
                            "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                        )
                    }
                }
            }
            "vivo" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.iqoo.secure",
                        "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                    )
                }
            }
            "huawei", "honor" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.optimize.process.ProtectActivity",
                    )
                }
            }
            "samsung" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.ui.battery.BatteryActivity",
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.battery.ui.BatteryActivity",
                    )
                }
            }
            "asus" -> {
                intents += Intent().apply {
                    component = ComponentName(
                        "com.asus.mobilemanager",
                        "com.asus.mobilemanager.autostart.AutoStartActivity",
                    )
                }
                intents += Intent().apply {
                    component = ComponentName(
                        "com.asus.mobilemanager",
                        "com.asus.mobilemanager.powersaver.PowerSaverSettings",
                    )
                }
            }
        }

        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                return
            } catch (_: Exception) {
                // 试下一个。
            }
        }

        openAppDetailsSettings(context)
    }

    private fun openBatteryOptimizationSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                context.startActivity(
                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        data = Uri.parse("package:${context.packageName}")
                    },
                )
                return
            } catch (_: Exception) {
                // 落到电池优化列表。
            }
            try {
                context.startActivity(
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    },
                )
                return
            } catch (_: Exception) {
                // 落到应用详情。
            }
        }
        openAppDetailsSettings(context)
    }

    private fun openAccessibilitySettings(context: Context) {
        try {
            context.startActivity(
                Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra("package_name", context.packageName)
                    putExtra("android.intent.extra.PACKAGE_NAME", context.packageName)
                    putExtra(
                        "android.intent.extra.COMPONENT_NAME",
                        ComponentName(context, KeepAliveAccessibilityService::class.java)
                            .flattenToString(),
                    )
                },
            )
            return
        } catch (_: ActivityNotFoundException) {
            // 落到无障碍总页。
        } catch (_: Exception) {
            // 落到无障碍总页。
        }

        try {
            context.startActivity(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        } catch (_: Exception) {
            openAppDetailsSettings(context)
        }
    }

    private fun openDoNotDisturbAccessSettings(context: Context) {
        try {
            context.startActivity(
                Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        } catch (e: Exception) {
            Log.w(TAG, "打开勿扰策略设置失败", e)
            openAppDetailsSettings(context)
        }
    }

    private fun openAppDetailsSettings(context: Context) {
        try {
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    data = Uri.parse("package:${context.packageName}")
                },
            )
        } catch (e: Exception) {
            Log.w(TAG, "打开应用详情设置失败", e)
        }
    }
}
