package com.mutx163.qingyu

/**
 * `HomeWidgetStorage.clearSnapshot` 的**清除范围**（纯逻辑，可 JVM 直测）。
 *
 * ## 语义修正（2026-11-06 第五轮，hy2 指出语义被扩权）
 *
 * `clearSnapshot` 的真实调用场景是「**当前算不出快照时撤过期快照**」
 * （Dart `timetable_live_activity_service.dart:1195-1202`），**不是清数据/登出**。
 * 所以只清「全局课表快照 + 刷新点缓存」这两个过期件。**绝不清**：
 * - `widget_binding_*`：用户在设置页配的卡片绑定，是**用户资产**；
 * - `widget_snapshot_*`：每卡专属快照是另一套（Flutter 为绑定卡单独生成），
 *   不属「当次失败」；`clearSnapshot` 也没有 appWidgetId 上下文去判定哪张失败。
 *
 * 清完 `updateAll` 让卡片走「实时计算 → 失败 → 无快照」的自然分支（`readSnapshot`
 * 本就优先实时计算，`TodayWidgetSupport.kt:184-203`），不会因为清 prefs 变空态。
 */
internal object WidgetSnapshotDataKeys {

    /** 全局课表快照 key（与 `HomeWidgetStorage.KEY_SNAPSHOT_JSON` 同值）。 */
    const val KEY_SNAPSHOT_JSON = "snapshot_json"

    /** 刷新时间点缓存 key。 */
    const val KEY_REFRESH_TIMES_JSON = "refresh_times_json"

    /**
     * 给定 `home_widget_prefs` 里的全部 key，返回「撤过期快照」应删的那一批。
     *
     * **只含两个全局过期件**；绑定（`widget_binding_*`）与每卡专属快照
     * （`widget_snapshot_*`）一个不碰。
     */
    fun keysToClear(allKeys: Set<String>): Set<String> =
        allKeys.filter { it == KEY_SNAPSHOT_JSON || it == KEY_REFRESH_TIMES_JSON }.toSet()
}
