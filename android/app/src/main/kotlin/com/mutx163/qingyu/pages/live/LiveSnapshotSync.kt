package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.core.MiniJson

/**
 * 「设置落盘 → 原生岛快照」的桥（纯 Kotlin，零 Android 依赖）。
 *
 * ## 为什么需要它
 *
 * 超级岛的显示设置在 Dart 侧由 `TimetableLiveActivityService.syncScheduleSnapshot`
 * 组装快照、经通道写进 `LiveUpdateScheduler.snapshot_json`；原生岛只读那一份。
 * Compose 壳的显示设置页（[LiveDisplayStore]）只写 `timetable_settings`，
 * 与岛之间**没有第二条通路** ⇒ 壳里改了显示设置，岛纹丝不动。
 *
 * 本文件补的就是这一段：落盘后由 [LiveSnapshotSyncRegistry] 通知一个 [LiveSnapshotSyncer]，
 * 后者把新设置并进既有快照并调用 `LiveUpdateScheduler.syncSnapshot`。
 *
 * ## 为什么是「合并」而不是「全量重建」
 *
 * 快照里不只有设置，还有 `courses` / `currentWeek` / `semesterStartMillis` /
 * 节假日等——这些 Compose 壳并不拥有，也造不出与 Dart 逐字一致的课程 JSON。
 * 所以只替换 `settings` 子树：它与 Dart `buildLiveSnapshotSettingsJson`
 * （`miui_live_activities_service.dart:28-31`）= `settings.toJson()` + 版本号 是同一份结构。
 * 课程等其余字段原样保留，**不会**因为改一个开关就把岛上的课表清空。
 */
fun interface LiveSnapshotSyncer {
    /**
     * 把刚落盘的整份设置同步到原生岛。
     *
     * @param settingsJson 读回的 `timetable_settings`（`TimetableStore.loadSettingsJson()`）。
     */
    fun sync(settingsJson: Map<String, Any?>)
}

/**
 * 进程级注册点。
 *
 * 为什么不把 [LiveSnapshotSyncer] 塞进 [LiveDisplayStore] 的构造参数：宿主（`LiveDisplayHost`
 * 等）本批不归本次改动，构造签名一改就要连环改。这里由壳 Activity 在启动时
 * `install(...)` 一次，存储层在每次落盘后调用 [syncIfInstalled]。
 *
 * 单测可 `install(fake)` 断言「改设置 → 用到了新值」。
 */
object LiveSnapshotSyncRegistry {

    @Volatile
    private var installed: LiveSnapshotSyncer? = null

    /** 挂上（或换掉）同步器；传 null = 卸下。 */
    fun install(syncer: LiveSnapshotSyncer?) {
        installed = syncer
    }

    /** 有同步器就调用，没有则静默跳过（例如纯 JVM 单测里未挂）。 */
    fun syncIfInstalled(settingsJson: Map<String, Any?>) {
        installed?.sync(settingsJson)
    }
}

/**
 * 快照的「换 settings 子树」内核（纯函数，可直接 JVM 单测）。
 */
object LiveSnapshotBuilder {

    const val KEY_SETTINGS = "settings"
    const val KEY_EXPANDED_DETAIL_SCHEMA_VERSION = "liveExpandedDetailSchemaVersion"

    /**
     * 展开详情写法版本号。
     *
     * ⚠️ 与原生 `LiveUpdateScheduler.EXPANDED_DETAIL_SCHEMA_VERSION`（`LiveUpdateScheduler.kt:759`）
     * 和 Dart `kLiveExpandedDetailSchemaVersion`（`miui_live_activities_service.dart:22`）**必须同值**。
     * 这里不引用原生那个常量：`LiveUpdateScheduler.kt` 带 Android 依赖，进不了本纯 Kotlin 层的
     * L0 classpath。Dart 侧同样是自己抄一份并注明「必须与原生同值」，沿用同一纪律。
     */
    const val EXPANDED_DETAIL_SCHEMA_VERSION = 1

    /**
     * 把 [settingsJson] 并进既有快照的 `settings` 子树，返回新的快照 JSON。
     *
     * 合并规则：**先铺既有 settings**（保住 `sections` / `semesterWeekCount` 等壳不拥有的键），
     * **再铺新设置**（用户刚改的 live* 键生效），最后写入展开详情版本号。
     *
     * @return 无既有快照 / 解析失败时返回 null（调用方据此放弃本轮同步，不造空课表快照）。
     */
    fun withSettings(existingSnapshotJson: String?, settingsJson: Map<String, Any?>): String? {
        if (existingSnapshotJson.isNullOrBlank()) return null
        val root = MiniJson.tryParse(existingSnapshotJson) as? Map<String, Any?> ?: return null

        val existingSettings = root[KEY_SETTINGS] as? Map<String, Any?>
        val mergedSettings = LinkedHashMap<String, Any?>()
        if (existingSettings != null) mergedSettings.putAll(existingSettings)
        mergedSettings.putAll(settingsJson)
        mergedSettings[KEY_EXPANDED_DETAIL_SCHEMA_VERSION] = EXPANDED_DETAIL_SCHEMA_VERSION

        val out = LinkedHashMap<String, Any?>(root)
        out[KEY_SETTINGS] = mergedSettings
        return MiniJson.encode(out)
    }
}
