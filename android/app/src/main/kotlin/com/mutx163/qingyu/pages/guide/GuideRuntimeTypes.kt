package com.mutx163.qingyu.pages.guide

/**
 * 引导页宿主 ↔ 渲染层的运行时契约（Lead 冻结，双方只读，不许改这个文件）。
 *
 * 设计原则：
 * - 这些类型是**纯 Kotlin、零 Android 依赖**，所以既能被 main 的模型/单测编译，
 *   也能被 composeP1 的渲染层引用；
 * - 渲染层（`UserGuidePage.kt`）只依赖这里的类型 + 回调，不自己探测系统状态、不自己写设置；
 * - 真实权限探测与设置读写都由宿主（壳 `ShellPageIndex` + `platform/guide/GuidePermissionProbe`
 *   + `UserGuideModel`/`GuideSettingsMapping`）注入。
 *
 * 对应 Flutter 原版 `lib/screens/user_guide_screen.dart` 的六项真实权限：
 * 通知、超级岛/焦点通知、自启动、电池无限制、无障碍保活、勿扰访问。
 */

/**
 * 六项权限的真实状态。
 *
 * `null` 表示**还没探测过**：UI 应显示中性/加载态，**不要**把它当成“未开启”吓人
 * （对齐 Dart 的 `_isLoading` 与 `LivePermissionStatus.UNKNOWN` 语义）。
 */
data class GuidePermissionState(
    /** 通知权限（Dart `_hasNotificationPermission`）。 */
    val notification: Boolean? = null,
    /** 超级岛/焦点通知可发（Dart `_canPostPromoted`）。 */
    val promotedIsland: Boolean? = null,
    /** 超级岛权限是否已在清单声明（Dart `_hasPromotedPermission`，决定“已开启待生效”还是“建议检查”）。 */
    val promotedDeclared: Boolean = false,
    /** 自启动（Dart `_isAutoStartEnabled`）。 */
    val autoStart: Boolean? = null,
    /** 电池无限制（Dart `_isIgnoringBatteryOptimizations`）。 */
    val batteryUnrestricted: Boolean? = null,
    /** 无障碍保活服务（Dart `_isKeepAliveAccessibilityEnabled`）。 */
    val keepAliveAccessibility: Boolean? = null,
    /** 勿扰模式访问权限（Dart `_hasDoNotDisturbAccess`）。 */
    val doNotDisturbAccess: Boolean? = null,
) {
    /** 任一项仍为 null ⇒ 仍在加载，权限页应显示加载态。 */
    val isLoading: Boolean
        get() = notification == null ||
            promotedIsland == null ||
            autoStart == null ||
            batteryUnrestricted == null ||
            keepAliveAccessibility == null ||
            doNotDisturbAccess == null
}

/** 权限行点击后要宿主去做的动作（拉起系统设置页 / 请求权限）。 */
enum class GuidePermissionAction {
    Notification,
    PromotedIsland,
    AutoStart,
    Battery,
    KeepAliveAccessibility,
    DoNotDisturbAccess,
}

/** 深浅色模式（对应 Flutter `AppThemeMode`，仅供个性化页展示与写回）。 */
enum class GuideThemeMode {
    SYSTEM,
    LIGHT,
    DARK,
}

/** 个性化页只读快照（宿主从 `TimetableSettingsModel` 推导后传入）。 */
data class GuideSettingsSnapshot(
    /** 首页菜单样式是否为宫格（Dart `homeMenuStyle == HomeMenuStyle.grid`）。 */
    val homeMenuGrid: Boolean = false,
    /** 默认材质是否为实体纯色（false = 液态玻璃，对齐 Dart `GlassModeChoice`）。 */
    val materialSolid: Boolean = false,
    /** 深浅色模式。 */
    val themeMode: GuideThemeMode = GuideThemeMode.SYSTEM,
    /** 当前主题色种子（hex，对应 `ForuiTheme.seedHex`）。 */
    val seedHex: String = "",
)

/** 个性化页的写回补丁（宿主据此改 `TimetableSettingsModel` 并落盘）。 */
sealed interface GuideSettingsPatch {
    /** 首页菜单样式：true=宫格，false=列表。 */
    data class HomeMenuGrid(val grid: Boolean) : GuideSettingsPatch

    /** 默认材质：true=实体纯色，false=液态玻璃。 */
    data class MaterialSolid(val solid: Boolean) : GuideSettingsPatch

    /** 深浅色模式。 */
    data class ThemeMode(val mode: GuideThemeMode) : GuideSettingsPatch

    /** 主题色种子（hex）。 */
    data class SeedColor(val hex: String) : GuideSettingsPatch
}

/** 主题色板的一个选项（渲染层画色块用）：hex + 人类可读名称。 */
data class GuideSeedOption(
    val hex: String,
    val label: String,
)
