package com.mutx163.qingyu.theme

/**
 * Miuix 色板转录（亮 / 暗两套 ARGB 常量）。
 *
 * Dart 源：`lib/ui/hyperos/hyperos_miuix_spec.dart`
 * - 亮：`HyperosMiuixLightColors`（同文件 `:99-154`）
 * - 暗：`HyperosMiuixDarkColors`（同文件 `:160-215`）
 * - mikcb 实测覆写：`settingsBackground/PrimaryText/SecondaryText/Pressed`
 *  （同文件 `:65-68`）
 * - 图标彩豆：`HyperosIconColors`（`lib/ui/hyperos/hyperos_tokens.dart:124-135`）
 *
 * 对照表：`docs/plans/2026-10-26-compose-phase3-prep.md` §2.1。
 *
 * 纯 Kotlin + Int ARGB，不依赖 Compose / Miuix / android.graphics：
 * 主源集全变体可编译（非 P1 变体没有 Compose runtime，见
 * `android/app/build.gradle:186-202` 注释），JVM 单测与真机走同一公式。
 * Int 写法：`0xFF3482FFL.toInt()`（字面量超 Int 上限，先按 Long 再转回，
 * 得到与 Dart `Color(0xFF3482FF)` 一致的负 Int）。
 *
 * Miuix 侧形参名以 Phase 3 开工对照 0.9.4 实物为准（准备文档标「待定」），
 * 这里只定槽位语义；composeP1 接线层按语义逐项填入
 * `lightColorScheme()/darkColorScheme()`。
 */
object QingyuLightPalette {
    val PRIMARY = 0xFF3482FFL.toInt()
    val ON_PRIMARY = 0xFFFFFFFFL.toInt()
    val PRIMARY_VARIANT = 0xFF3482FFL.toInt()
    val ON_PRIMARY_VARIANT = 0xFFAECDFFL.toInt()
    val ERROR = 0xFFE94634L.toInt()
    val ON_ERROR = 0xFFFFFFFFL.toInt()
    val SUCCESS = 0xFF0E8043L.toInt()
    val ERROR_CONTAINER = 0xFFFDF6F4L.toInt()
    val ON_ERROR_CONTAINER = 0xFF410002L.toInt()
    val DISABLED_PRIMARY = 0xFFC2D9FFL.toInt()
    val DISABLED_ON_PRIMARY = 0xFFF3F8FFL.toInt()
    val DISABLED_PRIMARY_BUTTON = 0xFFC2D9FFL.toInt()
    val DISABLED_ON_PRIMARY_BUTTON = 0xFFFFFFFFL.toInt()
    val DISABLED_PRIMARY_SLIDER = 0xFFB8CFF5L.toInt()
    val PRIMARY_CONTAINER = 0xFF5D9BFFL.toInt()
    val ON_PRIMARY_CONTAINER = 0xFFFFFFFFL.toInt()
    val SECONDARY = 0xFFE6E6E6L.toInt()
    val ON_SECONDARY = 0xFFFFFFFFL.toInt()
    val SECONDARY_VARIANT = 0xFFF0F0F0L.toInt()
    val ON_SECONDARY_VARIANT = 0xFF303030L.toInt()
    val DISABLED_SECONDARY = 0xFFF0F0F0L.toInt()
    val DISABLED_ON_SECONDARY = 0xFFFCFCFCL.toInt()
    val DISABLED_SECONDARY_VARIANT = 0xFFF2F2F2L.toInt()
    val DISABLED_ON_SECONDARY_VARIANT = 0xFFB2B2B2L.toInt()
    val SECONDARY_CONTAINER = 0xFFF0F0F0L.toInt()
    val ON_SECONDARY_CONTAINER = 0xFFA9A9A9L.toInt()
    val SECONDARY_CONTAINER_VARIANT = 0xFFF0F0F0L.toInt()
    val ON_SECONDARY_CONTAINER_VARIANT = 0xFFA8A8A8L.toInt()
    val TERTIARY_CONTAINER = 0xFFEAF2FFL.toInt()
    val ON_TERTIARY_CONTAINER = 0xFF3482FFL.toInt()
    val TERTIARY_CONTAINER_VARIANT = 0xFFEAF2FFL.toInt()
    /** Miuix 默认页底（mikcb 用实测覆写，见 [QingyuMikcbOverrides]）。 */
    val BACKGROUND = 0xFFFFFFFFL.toInt()
    /** Miuix 默认页底墨（mikcb 用实测覆写，见 [QingyuMikcbOverrides]）。 */
    val ON_BACKGROUND = 0xFF000000L.toInt()
    val ON_BACKGROUND_VARIANT = 0xFF8C93B0L.toInt()
    val SURFACE = 0xFFF7F7F7L.toInt()
    val ON_SURFACE = 0xFF000000L.toInt()
    val SURFACE_VARIANT = 0xFFFFFFFFL.toInt()
    val ON_SURFACE_SECONDARY = 0xCC000000L.toInt()
    /** Miuix 默认次墨（mikcb 用实测覆写，见 [QingyuMikcbOverrides]）。 */
    val ON_SURFACE_VARIANT_SUMMARY = 0x99000000L.toInt()
    val ON_SURFACE_VARIANT_ACTIONS = 0x66000000L.toInt()
    val DISABLED_ON_SURFACE = 0xFFB2B2B2L.toInt()
    val SURFACE_CONTAINER = 0xFFFFFFFFL.toInt()
    val ON_SURFACE_CONTAINER = 0xFF000000L.toInt()
    val ON_SURFACE_CONTAINER_VARIANT = 0xFF959595L.toInt()
    val SURFACE_CONTAINER_HIGH = 0xFFE8E8E8L.toInt()
    val ON_SURFACE_CONTAINER_HIGH = 0xFFA2A2A2L.toInt()
    val SURFACE_CONTAINER_HIGHEST = 0xFFE8E8E8L.toInt()
    val ON_SURFACE_CONTAINER_HIGHEST = 0xFF000000L.toInt()
    val OUTLINE = 0xFFD9D9D9L.toInt()
    val DIVIDER_LINE = 0xFFE0E0E0L.toInt()
    /** Black @ 30%。 */
    val WINDOW_DIMMING = 0x4D000000L.toInt()
    val SLIDER_KEY_POINT = 0x4DA3B3CDL.toInt()
    val SLIDER_KEY_POINT_FOREGROUND = 0xFF6EB5FFL.toInt()
    val SLIDER_BACKGROUND = 0x0F000000L.toInt()
}

object QingyuDarkPalette {
    val PRIMARY = 0xFF277AF7L.toInt()
    val ON_PRIMARY = 0xFFFFFFFFL.toInt()
    val PRIMARY_VARIANT = 0xFF0073DDL.toInt()
    val ON_PRIMARY_VARIANT = 0xFF99C7F1L.toInt()
    val ERROR = 0xFFF12522L.toInt()
    val ON_ERROR = 0xFFFFFFFFL.toInt()
    val SUCCESS = 0xFF3FD684L.toInt()
    val ERROR_CONTAINER = 0xFF2E0603L.toInt()
    val ON_ERROR_CONTAINER = 0xFFFFDAD6L.toInt()
    val DISABLED_PRIMARY = 0xFF253E64L.toInt()
    val DISABLED_ON_PRIMARY = 0xFF677993L.toInt()
    val DISABLED_PRIMARY_BUTTON = 0xFF253E64L.toInt()
    val DISABLED_ON_PRIMARY_BUTTON = 0xFF677893L.toInt()
    val DISABLED_PRIMARY_SLIDER = 0xFF44587CL.toInt()
    val PRIMARY_CONTAINER = 0xFF338FE4L.toInt()
    val ON_PRIMARY_CONTAINER = 0xFFFFFFFFL.toInt()
    val SECONDARY = 0xFF505050L.toInt()
    val ON_SECONDARY = 0xFFFFFFFFL.toInt()
    val SECONDARY_VARIANT = 0xFF434343L.toInt()
    val ON_SECONDARY_VARIANT = 0xFFD9D9D9L.toInt()
    val DISABLED_SECONDARY = 0xFF3F3F3FL.toInt()
    val DISABLED_ON_SECONDARY = 0xFF797979L.toInt()
    val DISABLED_SECONDARY_VARIANT = 0xFF404040L.toInt()
    val DISABLED_ON_SECONDARY_VARIANT = 0xFF707170L.toInt()
    val SECONDARY_CONTAINER = 0xFF434343L.toInt()
    val ON_SECONDARY_CONTAINER = 0xFF7C7C7CL.toInt()
    val SECONDARY_CONTAINER_VARIANT = 0xFF4F4F4FL.toInt()
    val ON_SECONDARY_CONTAINER_VARIANT = 0xFF959595L.toInt()
    val TERTIARY_CONTAINER = 0xFF2B3B54L.toInt()
    val ON_TERTIARY_CONTAINER = 0xFF4788FFL.toInt()
    val TERTIARY_CONTAINER_VARIANT = 0xFF505050L.toInt()
    val BACKGROUND = 0xFF242424L.toInt()
    val ON_BACKGROUND = 0xE6FFFFFFL.toInt()
    val ON_BACKGROUND_VARIANT = 0xFF787E96L.toInt()
    val SURFACE = 0xFF000000L.toInt()
    val ON_SURFACE = 0xFFF2F2F2L.toInt()
    val SURFACE_VARIANT = 0xFF242424L.toInt()
    val ON_SURFACE_SECONDARY = 0xCCFFFFFFL.toInt()
    val ON_SURFACE_VARIANT_SUMMARY = 0x80FFFFFFL.toInt()
    val ON_SURFACE_VARIANT_ACTIONS = 0x66FFFFFFL.toInt()
    val DISABLED_ON_SURFACE = 0xFF666666L.toInt()
    val SURFACE_CONTAINER = 0xFF242424L.toInt()
    val ON_SURFACE_CONTAINER = 0xE6FFFFFFL.toInt()
    val ON_SURFACE_CONTAINER_VARIANT = 0xFF737373L.toInt()
    val SURFACE_CONTAINER_HIGH = 0xFF242424L.toInt()
    val ON_SURFACE_CONTAINER_HIGH = 0xFF666666L.toInt()
    val SURFACE_CONTAINER_HIGHEST = 0xFF2D2D2DL.toInt()
    val ON_SURFACE_CONTAINER_HIGHEST = 0xFFE9E9E9L.toInt()
    val OUTLINE = 0xFF404040L.toInt()
    val DIVIDER_LINE = 0xFF393939L.toInt()
    /** Black @ 60%。 */
    val WINDOW_DIMMING = 0x99000000L.toInt()
    val SLIDER_KEY_POINT = 0x4D7A8AA6L.toInt()
    val SLIDER_KEY_POINT_FOREGROUND = 0xFF5DAAFFL.toInt()
    val SLIDER_BACKGROUND = 0x26FFFFFFL.toInt()
}

/**
 * mikcb 实测覆写（HyperOS「设置」首页量出来的值，优先于 Miuix 默认）。
 *
 * - 页底用 settingsBackground（亮 `#FFF2F2F2`），不用 Miuix `background #FFFFFFFF`；
 * - 主文字用 settingsPrimaryText（亮 `#FF333333`），不用 `onBackground #FF000000`；
 * - 次文字用 settingsSecondaryText（亮 `#FF999999`），不用
 *   `onSurfaceVariantSummary #99000000`。
 * 分支见 `lib/ui/hyperos/hyperos_theme.dart:15-41`，[QingyuTheme] 负责按深浅选边。
 */
object QingyuMikcbOverrides {
    val SETTINGS_BACKGROUND = 0xFFF2F2F2L.toInt()
    val SETTINGS_PRIMARY_TEXT = 0xFF333333L.toInt()
    val SETTINGS_SECONDARY_TEXT = 0xFF999999L.toInt()
    val SETTINGS_PRESSED = 0xFFE0E0E0L.toInt()
}

/**
 * 图标彩豆（`HyperosIconColors`，`hyperos_tokens.dart:124-135`）。
 *
 * Miuix `colorScheme` 无对应槽：Compose 侧保留为应用层 token，不进主题桥。
 */
object QingyuIconColors {
    val BLUE = 0xFF3482FFL.toInt()
    val GREEN = 0xFF10C550L.toInt()
    val ORANGE = 0xFFFF6B00L.toInt()
    val PURPLE = 0xFF8B5CF6L.toInt()
    val TEAL = 0xFF14B8A6L.toInt()
    val RED = 0xFFFA382EL.toInt()
    val YELLOW = 0xFFF5A623L.toInt()
    val INDIGO = 0xFF6366F1L.toInt()
    val CYAN = 0xFF06B6D4L.toInt()
}

/**
 * 与深浅无关的固定 token。
 *
 * - DESTRUCTIVE：危险操作强调色（`hyperos_theme.dart:132-134`），亮暗同值，
 *   不与 Miuix error 合并；
 * - FIELD_LABEL_*：输入框浮动小标签墨（同文件 `:197-201`），AA 对比度档。
 */
object QingyuFixedTokens {
    val DESTRUCTIVE = 0xFFE05D44L.toInt()
    val FIELD_LABEL_LIGHT = 0xFF5A5A5AL.toInt()
    val FIELD_LABEL_DARK = 0xFFB8B8B8L.toInt()
}
