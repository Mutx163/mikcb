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

    /**
     * 发布版 `HomeGridMenu.defaultActions`（tag `v2.1.4.1`
     * `lib/models/settings/timetable_settings_enums.dart:170-178`），顺序即屏上顺序。
     *
     * 2026-11-10 用户拍板「默认就跟旧版本一致」：这里必须与发布 tag 的集合逐项一致
     * （首项是 `update`，且**不含** `tasks`）。发布版注释原文写明这是
     * 「v2.0.5.5 已发布版本的默认排列（不含后来新增的任务入口）」。
     */
    val DEFAULT_IDS: List<String> = listOf(
        "update",
        "overview",
        "statistics",
        "addCourse",
        "exams",
        "importCourses",
        PINNED_ID,
        "support",
    )

    // ── 「弹层动作」型目录条目（不是一个页面）──────────────────────────────
    //
    // Dart 的目录项只要能查到就保留，点下来 `HomeMenuEntry.open` 自己决定是推页
    // 还是当场弹层（`home_menu_catalog.dart:92-100` 的 courseRecolor 弹重配色面板、
    // `:101-118` 的 shareTimetable 直接分享）。Compose 侧曾经把「有没有页面」当成
    // 唯一判据，于是这两个合法条目在渲染时被静默丢掉 —— 用户排列里排了它们时，
    // 8 个槽位只画 7 格（2026-11-09 用户报的「只显示 7 格」同源判据）。
    //
    // 有去处 = 页面映射里有，**或**在本白名单里。八宫格与底栏必须共用这一条判据。

    /** 「课表重新配色」：点了当场弹配色面板，不是一个页面。 */
    const val ACTION_COURSE_RECOLOR = "courseRecolor"

    /** 「分享课表图片」：点了当场分享当前视图，不是一个页面。 */
    const val ACTION_SHARE_TIMETABLE = "shareTimetable"

    /** 弹层动作白名单（见上面的常量注释）。 */
    val MENU_ACTION_IDS: Set<String> = setOf(ACTION_COURSE_RECOLOR, ACTION_SHARE_TIMETABLE)

    /** 该 id 是「弹层动作」而不是页面。 */
    fun isMenuAction(id: String): Boolean = id in MENU_ACTION_IDS

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
