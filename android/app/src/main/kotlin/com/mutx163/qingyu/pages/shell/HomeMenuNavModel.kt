package com.mutx163.qingyu.pages.shell

/**
 * 首页右上角「更多」菜单（八宫格 / 列表档）**条目排列**的解析 —— 纯 Kotlin。
 *
 * ## 它解决的是什么
 *
 * Flutter 版这一格的条目是用户可编排的（设置 → 外观 → 自定义八宫格按钮，
 * `lib/screens/settings/settings_home_menu_editor.dart`），渲染时走
 * `resolveHomeGridMenuEntries(settings)`（`lib/widgets/home_menu_catalog.dart:499-533`）：
 * 读 `homeGridMenuActions`、丢掉目录里查不到或不可见的 id、去重保序；
 * 空表**或只剩钉住项**时回退 `HomeGridMenu.defaultActions`
 * （`timetable_settings_enums.dart:179-188`：8 项，含钉住的 `settings`）。
 *
 * Compose 壳此前把这一格写死成上面那 8 个默认项（`TimetableMenuDefaults.entries()`），
 * 于是「自定义八宫格按钮」页改了**一点效果都没有** —— 用户排的顺序、加的入口
 * 在首页上全不出现。本对象是那段解析逻辑在 Kotlin 侧的唯一落点。
 *
 * ## 「只剩钉住项」为什么要当未配置
 *
 * Dart 侧这条自愈有具体来历（`home_menu_catalog.dart:520-526`）：历史版本对空排列做
 * normalize 时会钉入 `settings`，把「从没配置过」的档位固化成单入口；再叠加编辑器
 * 入口一度缺失，用户就再也加不回来。所以「只有一个 settings」不当作真配置，
 * 直接回退默认 8 项。Compose 侧口径必须一致，否则升级到这里的用户会看到只剩一格。
 *
 * ## 可支持性由调用方注入
 *
 * 与 [HomeDockNavModel] 同一条理由：`pages/shell` 的 L0 单测只编本目录 + 共享模型，
 * 这里不 import 设置目录与壳页面映射；「这个 id 本仓有没有去处」作为谓词传入。
 */
object HomeMenuNavModel {

    /** `HomeGridMenu.pinnedActionId`（`timetable_settings_enums.dart:170`）：钉死的「课表设置」。 */
    const val PINNED_ID = "settings"

    /** `HomeGridMenu.maxSlots`（`:166`）：4 列 × 2 行。 */
    const val MAX_SLOTS = 8

    /** `HomeGridMenu.defaultActions`（`:179-188`），顺序即屏上顺序。 */
    val DEFAULT_IDS: List<String> = listOf(
        "overview",
        "statistics",
        "addCourse",
        "exams",
        "tasks",
        "importCourses",
        PINNED_ID,
        "support",
    )

    /**
     * 解析「更多」菜单排列。
     *
     * @param raw 用户存档里的 `homeGridMenuActions`（可为空，可能含旧版残留 id）。
     * @param isSupported 该 id 在本仓点得开吗（目录未知 / 页面未移植 ⇒ false，丢弃）。
     */
    fun resolveIds(
        raw: List<String>,
        isSupported: (String) -> Boolean,
    ): List<String> {
        val resolved = ArrayList<String>(raw.size)
        for (id in raw) {
            if (id.isBlank() || resolved.contains(id)) continue
            if (!isSupported(id)) continue
            resolved.add(id)
            if (resolved.size >= MAX_SLOTS) break
        }
        // 空表，或「只剩钉住项」⇒ 视作未配置，回退默认（Dart 同一判据）。
        val degenerate = resolved.size == 1 && resolved[0] == PINNED_ID
        if (resolved.isEmpty() || degenerate) {
            val fallback = ArrayList<String>(DEFAULT_IDS.size)
            for (id in DEFAULT_IDS) {
                if (isSupported(id)) fallback.add(id)
            }
            return fallback
        }
        return resolved
    }
}
