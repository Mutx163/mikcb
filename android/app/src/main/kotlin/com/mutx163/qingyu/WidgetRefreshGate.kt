package com.mutx163.qingyu

/**
 * 桌面小部件刷新调度的**纯逻辑闸门**（无 Android 依赖，可 JVM 直测）。
 *
 * ## 为什么需要它（用户报的真实耗电问题）
 *
 * 用户本机 bugreport：桌面上**一个小部件实例都没有**，应用却仍在为
 * `android.appwidget.action.APPWIDGET_UPDATE` 每分钟设一个 `RTC_WAKEUP` 闹钟
 * （21 小时 629 次，全机第一，把整机从 suspend 里每 63 秒拽出来一次）。
 *
 * 根因有两条：
 * 1. 10 个 `AppWidgetProvider` 的 `updatePeriodMillis` 全是 0 ⇒ 刷新完全靠
 *    [HomeWidgetStorage.rescheduleRefresh] 维护的自定义 alarm，系统不管；
 * 2. 原先「该不该调度」只看「有没有课表数据」，不看「桌面上到底有没有卡片」，
 *    于是「装过又删光」之后闹钟照跑。
 *
 * [shouldSchedule] 把判据收成一句话：**只要还有任意一个 Provider 的实例，就该调度；
 * 全部归零就停**。[HomeWidgetStorage.rescheduleRefresh] 与
 * [BaseQingyuWidgetProvider.onDisabled] 共用这一处判据，避免两边各写一份又漂移。
 */
internal object WidgetRefreshGate {

    /**
     * 是否还需要调度桌面刷新。
     *
     * @param instanceCounts 每个已注册 Provider 当前的实例数（`getAppWidgetIds(...).size`）。
     *        传空列表 ⇒ 一个 Provider 都没注册/都没实例 ⇒ 不调度。
     * @return `true` = 至少一个 Provider 有实例，需要继续调度。
     */
    fun shouldSchedule(instanceCounts: List<Int>): Boolean = instanceCounts.any { it > 0 }
}
