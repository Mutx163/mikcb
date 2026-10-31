package com.mutx163.qingyu

import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log

/**
 * 桌面上的一张小卡片实例（`listTodayWidgetInstances` 的一行）。
 *
 * [widgetType] 是 [WidgetProviderCatalog] 的卡型串（`compact` / `medium` / …）；
 * [boundProfileId] 为 null 表示「跟随当前课表」。
 */
data class HomeWidgetInstanceInfo(
    val appWidgetId: Int,
    val widgetType: String?,
    val boundProfileId: String?,
)

/**
 * 小组件相关的**系统能力**封装：请求添加到桌面、精确闹钟授权、实例查询、绑定落盘。
 *
 * ## 为什么要从 `MainActivity` 里搬出来
 *
 * 这五件事原本是 `MainActivity` 的私有方法，只服务 Flutter 通道
 * （Dart `home_widget_service.dart` 的 `canRequestPinWidget` / `requestPinWidget` /
 * `canScheduleExactAlarms` / `requestScheduleExactAlarm` / `listTodayWidgetInstances`）。
 * Compose 设置页（`composeP1` 的 `HomeWidgetHost`）要用同一批能力，但拿不到
 * Activity 的私有方法；各写一份的话，「返回值串」这种隐式协议会分叉
 * （一端回 `requested`、另一端回 `ok`，宿主就把成功当失败）。
 *
 * 所以逻辑**逐行照抄**到这里，`MainActivity` 的私有实现改成转调本对象，
 * 返回值字符串与分支顺序保持不变（Dart 侧的 `switch (result)` 依赖这些字面量）。
 *
 * ## 线程
 *
 * 全部是**同步**调用：`requestPinAppWidget` 只是把请求交给系统（真正的确认发生在
 * 系统弹窗里，结果要靠重新查询实例列表才知道），`startActivity` 也是排一次跳转。
 * 调用方本来就都在主线程（通道回调 / Compose 侧 `LaunchedEffect`）。
 */
object WidgetSystemActions {

    private const val TAG = "WidgetSystemActions"

    /** 桌面是否支持「请求把卡片添加到桌面」（`HomeWidgetService.canRequestPinWidget`）。 */
    fun canRequestPinWidget(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        val appWidgetManager = context.getSystemService(AppWidgetManager::class.java)
        return appWidgetManager?.isRequestPinAppWidgetSupported == true
    }

    /**
     * 请求系统把 [widgetType] 那张卡片加到桌面。
     *
     * 返回 `requested` / `unsupported` / `invalid_widget_type` / `failed`，
     * 与 `HomeWidgetPinRequestResult`（`home_widget_service.dart:129-134`）逐值对应。
     */
    fun requestPinWidget(context: Context, widgetType: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return "unsupported"
        }
        val appWidgetManager = context.getSystemService(AppWidgetManager::class.java)
            ?: return "unsupported"
        if (!appWidgetManager.isRequestPinAppWidgetSupported) {
            return "unsupported"
        }
        val provider = resolveWidgetProvider(context, widgetType) ?: return "invalid_widget_type"
        return if (appWidgetManager.requestPinAppWidget(provider, null, null)) {
            "requested"
        } else {
            "failed"
        }
    }

    /** Android 12+ 需要用户在系统里授予「闹钟和提醒」权限才能精确闹钟。 */
    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return true
        return alarmManager.canScheduleExactAlarms()
    }

    /**
     * 跳转系统「闹钟和提醒」授权页。
     *
     * 返回状态字符串：`launched` 已跳授权页；`fallback` ROM 未处理该 action，
     * 已回退应用详情页（含闹钟和提醒开关）；`not_required` S 以下无需授权；
     * `failed` 两次跳转都没起来。
     */
    fun requestScheduleExactAlarm(context: Context): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return "not_required"
        }
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:${context.packageName}")
            // 宿主可能传 Application Context（Compose 侧就是 `context.applicationContext`
            // 更稳），带这个 flag 才有用；传 Activity 时它无害（同一个任务栈里不会重复建栈）。
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            "launched"
        } catch (_: ActivityNotFoundException) {
            // 个别 ROM 未处理该 action 时退回应用详情页（含闹钟和提醒开关）——
            // Dart 侧 `HomeWidgetExactAlarmRequestResult.fallback` 就是这个分支。
            openAppDetailsSettings(context)
            "fallback"
        } catch (_: Exception) {
            "failed"
        }
    }

    /**
     * 列出桌面上已存在的今日课程系卡片（6 种）与它们的绑定。
     *
     * 顺序取 [WidgetProviderCatalog.todaySeries]——就是「各卡片绑定管理」与预览轮播
     * 的呈现顺序（`WidgetProviderCatalog` 的 KDoc 已经把这层约定写死了）。
     * 统计/考试卡不支持逐张绑定，**不在这里列出**（Dart `_loadWidgetInstances` 同）。
     */
    fun listTodayWidgetInstances(context: Context): List<HomeWidgetInstanceInfo> {
        val appWidgetManager = context.getSystemService(AppWidgetManager::class.java)
            ?: return emptyList()
        val bindings = WidgetBindingStore.allBindings(context)
        val instances = mutableListOf<HomeWidgetInstanceInfo>()
        for ((widgetType, providerClass) in WidgetProviderCatalog.todaySeries) {
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, providerClass))
            for (appWidgetId in ids) {
                instances.add(
                    HomeWidgetInstanceInfo(
                        appWidgetId = appWidgetId,
                        widgetType = widgetType,
                        boundProfileId = bindings[appWidgetId],
                    )
                )
            }
        }
        return instances
    }

    /**
     * 改写一张卡片的绑定，并让桌面上的卡片立刻按新课表重绘 + 重排刷新闹钟。
     *
     * 三件事必须一起做（Dart `_setWidgetBinding`，`settings_home_widget.dart:903-920`）：
     * 落绑定 → 重绘全部卡片 → 按新数据重排下一次刷新。只落绑定不重绘，用户要等到
     * 下一次定时刷新才看到变化。
     *
     * [profileId] 传 null = 「跟随当前课表」。
     */
    fun setWidgetBinding(context: Context, appWidgetId: Int, profileId: String?) {
        WidgetBindingStore.setBoundProfileId(context, appWidgetId, profileId)
        refreshAll(context)
    }

    /**
     * 让桌面上的小组件按**最新设置**重画一次，并重排下一次定时刷新。
     *
     * 两件事必须成对做：只重画不重排，下一次刷新还按旧数据的时间点走；只重排不重画，
     * 用户要等到下一个刷新周期才看见变化。设置页落盘成功后调用它（F20-B 起）。
     */
    fun refreshAll(context: Context) {
        TodayWidgetSupport.updateAll(context)
        HomeWidgetStorage.rescheduleRefresh(context)
    }

    /** 按最新权限档位重排小组件刷新闹钟（授权状态变化后调用）。 */
    fun rescheduleRefresh(context: Context) {
        HomeWidgetStorage.rescheduleRefresh(context)
    }

    private fun resolveWidgetProvider(context: Context, widgetType: String): ComponentName? {
        val providerClass = WidgetProviderCatalog.providerClass(widgetType) ?: return null
        return ComponentName(context, providerClass)
    }

    /**
     * 回退到「应用详情」页（里面有「闹钟和提醒」开关）。
     *
     * 与 `MainActivity.openAppDetailsSettings` 同一行为，只是这里只能拿到 Context，
     * 所以必须带 `FLAG_ACTIVITY_NEW_TASK`。
     */
    private fun openAppDetailsSettings(context: Context) {
        try {
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        } catch (error: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_OPEN_APP_DETAILS_FAILED, error)
        }
    }
}
