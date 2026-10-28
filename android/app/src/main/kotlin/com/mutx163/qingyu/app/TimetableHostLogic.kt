package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile

/**
 * 课表宿主的显示偏好。
 *
 * 为什么是**入参**而不是从 `settings` 读：`core.TimetableSettings` 是本族裁定的四键子集
 * （sections / activeTimeSchemeId / semesterWeekCount / semesterStartDate），没有
 * `timetableHideWeekends` / `timetableTimeColumnWidthMode` / `sectionHeight` /
 * `longPressEmptySlotToAddCourseEnabled`。完整设置模型由设置族移植，在那之前这几个值
 * 由壳接线层注入。
 *
 * 默认值全部取 **Dart 默认**，不取渲染层签名默认：Dart `sectionHeight` 默认 68
 * （`models/timetable_settings.dart:754`），而 `TimetableWeekPage` 的签名默认是 64
 * ——后者只是「没人传时的占位」，不是产品默认值。
 *
 * 放在纯 Kotlin 侧（而不是 Compose 文件里）是为了让这些默认值能被 JVM 测试钉住；
 * 渲染层只负责把 [sectionHeightDp] 包成 `Dp`。
 */
data class TimetableHostDisplayPrefs(
    val hideWeekends: Boolean = false,
    val wideTimeColumn: Boolean = false,
    val sectionHeightDp: Float = TimetableHostLogic.DEFAULT_SECTION_HEIGHT_DP,
    val longPressEmptySlotToAddCourseEnabled: Boolean = false,
)

/**
 * Phase 3.5 · L4 宿主层的**纯逻辑**（无 `android.*`、无 Compose）。
 *
 * 为什么单独放这里：`scripts/test-kotlin-module.ps1` 的「纯 Kotlin」判定是**整目录**的
 * ——`app/` 里只要出现一个 `import android.*`，整个目录会被静默跳过，全队 JVM 测试立刻
 * Unresolved。宿主层真正碰 Android / Compose 的部分在
 * `composeP1/.../app/TimetableHost.kt`，本文件只放能在 JVM 上断言的部分。
 *
 * 每条判据都能在 Dart 侧找到出处（见各函数注释），**期望值是人推的**，不从实现抄。
 */
object TimetableHostLogic {

    /** 首次启动兜底档案名（`storage_service.dart:1645` 的 `name: '默认课表'`）。 */
    const val DEFAULT_PROFILE_NAME = "默认课表"

    /** 时间列窄档宽度（`domain/timetable_layout.dart:12-17`）。 */
    const val NARROW_TIME_COLUMN_WIDTH_DP = 34f

    /** 时间列宽档宽度（同上）。 */
    const val WIDE_TIME_COLUMN_WIDTH_DP = 40f

    /** 节次行高默认值（`models/timetable_settings.dart:754` 的 `sectionHeight = 68`）。 */
    const val DEFAULT_SECTION_HEIGHT_DP = 68f

    /**
     * 可见星期几（Dart `visibleDayNumbers`，`domain/timetable_layout.dart:6-10`）：
     * 隐藏周末 → 周一到周五；否则周一到周日。
     *
     * 期望值：`false` → `[1,2,3,4,5,6,7]`；`true` → `[1,2,3,4,5]`。
     */
    fun visibleDayNumbers(hideWeekends: Boolean): List<Int> =
        if (hideWeekends) listOf(1, 2, 3, 4, 5) else listOf(1, 2, 3, 4, 5, 6, 7)

    /**
     * 时间列宽度（Dart `timeColumnWidth`，`domain/timetable_layout.dart:12-17`）：
     * 宽档 40、窄档 34。**单位是 dp 的数值**，Dp 包装留给渲染层（本文件不许 import Compose）。
     */
    fun timeColumnWidthDp(wide: Boolean): Float =
        if (wide) WIDE_TIME_COLUMN_WIDTH_DP else NARROW_TIME_COLUMN_WIDTH_DP

    /**
     * 空档加课是否放行（Dart `timetable_empty_slot_layer.dart:46`：
     * `if (!settings.longPressEmptySlotToAddCourseEnabled || span <= 0)` 就整个隐藏标记格）。
     *
     * 两个条件都要成立才允许：开关打开**且**这一格真有可用跨度。
     * 期望值（手推）：
     * - `(enabled=true,  span=1)`  -> true（开关开着、单格跨度 1）
     * - `(enabled=true,  span=0)`  -> false（没有可落课的空档，开关开着也不放行）
     * - `(enabled=false, span=1)`  -> false（开关关着）
     * - `(enabled=false, span=0)`  -> false
     * - `(enabled=true,  span=-1)` -> false（负跨度同样不算空档）
     */
    fun shouldAllowEmptySlotAdd(longPressToAddCourseEnabled: Boolean, span: Int): Boolean =
        longPressToAddCourseEnabled && span > 0

    /**
     * 顶部标题显示的档案名。
     *
     * 口径（人推）：
     * 1. `activeProfileId` 命中某档 → 用该档的 `name`；名字是空白 → [TimetableProfile.UNNAMED]
     *    （Dart `timetable_profile.dart` 的解析兜底名「未命名课表」）；
     * 2. 没命中（id 为 null 或指向不存在的档）→ 退到**第一份**档，同样按空白兜底；
     * 3. 一份档都没有 → [DEFAULT_PROFILE_NAME]（首启种子档名，`storage_service.dart:1645`）。
     */
    fun resolveProfileName(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
    ): String {
        val active = profiles.firstOrNull { it.id == activeProfileId } ?: profiles.firstOrNull()
        if (active == null) return DEFAULT_PROFILE_NAME
        return active.name.takeIf { it.isNotBlank() } ?: TimetableProfile.UNNAMED
    }

    /**
     * 生效的作息模板（Dart 侧 `settings.activeTimeSchemeId` 的路由口径）：
     * 命中 [activeTimeSchemeId] 用它；id 为 null 或指向不存在的档 → 退到第一份；
     * 一份都没有 → `null`（此时页面自己回落到 `settings.sections`，
     * 见 `TimetableWeekPage.kt:126-127`，宿主不要自己造节次表）。
     */
    fun resolveActiveTimeScheme(
        schemes: List<TimeScheme>,
        activeTimeSchemeId: String?,
    ): TimeScheme? =
        schemes.firstOrNull { it.id == activeTimeSchemeId } ?: schemes.firstOrNull()
}
