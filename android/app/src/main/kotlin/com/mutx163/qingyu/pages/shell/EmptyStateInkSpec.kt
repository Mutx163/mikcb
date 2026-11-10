package com.mutx163.qingyu.pages.shell

/**
 * 空态判墨：把「这块空态压在什么底上」解析成标题 / 说明两个 ARGB。
 *
 * ## 为什么放在 `pages/shell`（而不是 composeP1）
 *
 * 判墨只有一条依赖——[HomeBackgroundModel.inkOverWallpaperArgb]（壁纸 / 页底亮度决定翻黑还是翻白），
 * 它就在 `pages/shell`。放在这里有两个好处：
 * 1. 不造成 `core → pages` 的反向依赖；
 * 2. 这里的纯 Kotlin 面能被 `scripts/test-kotlin-module.ps1 -Module pages/shell` 直接编进 JVM
 *    单测（composeP1 不在 L0 的 classpath 上，`Color` 也进不了纯 Kotlin 测试）。
 *
 * Compose 侧 ([com.mutx163.qingyu.components.QingyuEmptyState]) 只负责把两个 ARGB 包成 `Color`，
 * 判墨规则本身只有这一份。
 *
 * ## 三档来源
 *
 * - [Theme]：页面主题墨（绝大多数页，空态压在页底上）；
 * - [OverBackdrop]：压在壁纸 / 自定义页底上（日视图；以后凡是「首页背景透上来」的页都用它）；
 * - [OnPhoto]：字直接压在照片上、发布版就是固定白字（壁纸取景页那种），不采样、不翻面。
 */
sealed interface EmptyStateInk {
    data object Theme : EmptyStateInk

    data object OnPhoto : EmptyStateInk

    /**
     * @param wallpaperLuminance 空态背后壁纸的平均亮度；null = 没壁纸 / 还没量到
     * @param pageBackgroundLuminance 没壁纸时文字实际压着的页底亮度（自定义页底色优先）
     * @param configuredArgbHex 用户自定义的字色（如 `weekdayBarFontColorLight/Dark`，`#RRGGBB` / `#AARRGGBB`）
     * @param defaultInkHex 那组设置的内置默认值；等于它视作「没改过」⇒ 按亮度翻黑白
     */
    data class OverBackdrop(
        val wallpaperLuminance: Double? = null,
        val pageBackgroundLuminance: Double? = null,
        val configuredArgbHex: String? = null,
        val defaultInkHex: String? = null,
    ) : EmptyStateInk
}

/** 判墨结果：标题与说明两个 ARGB（无 Compose 类型，JVM 可直接断言）。 */
data class EmptyStateColorsArgb(
    val titleArgb: Int,
    val bodyArgb: Int,
)

/** 与判墨相关的固定值（沉浸照片上的两档白，发布版壁纸取景页同款）。 */
object EmptyStateInkSpec {
    /** 标题：白 86%（发布版 `homePageWallpaperFileMissingTitle` 那一档）。 */
    val OnPhotoTitleArgb: Int = 0xDBFFFFFF.toInt()

    /** 说明：白 60%。 */
    val OnPhotoBodyArgb: Int = 0x99FFFFFF.toInt()
}

/**
 * 判墨：[ink] → 标题 / 说明两色。
 *
 * 有壁纸优先用壁纸亮度（字真压在照片上）；没壁纸用页底亮度（自定义深色页底也能翻对）。
 * 亮度都未知 ⇒ 主题原色——这一条是 2026-11-09 用户实报「壁纸/页底是黑的、字也是黑的」的修法。
 * 副标题永远是标题墨压淡一档（[HomeBackgroundModel.mutedInkOverWallpaperArgb]），
 * 自定义字色 / 壁纸翻面时两行不会一冷一暖。
 *
 * @param themeTitleArgb 主题主文字色（`QingyuTheme.primaryText(dark)`）
 * @param themeBodyArgb 主题次级文字色（`QingyuTheme.secondaryText(dark)`）
 */
fun resolveEmptyStateColorsArgb(
    ink: EmptyStateInk,
    themeTitleArgb: Int,
    themeBodyArgb: Int,
): EmptyStateColorsArgb = when (ink) {
    EmptyStateInk.Theme -> EmptyStateColorsArgb(
        titleArgb = themeTitleArgb,
        bodyArgb = themeBodyArgb,
    )

    EmptyStateInk.OnPhoto -> EmptyStateColorsArgb(
        titleArgb = EmptyStateInkSpec.OnPhotoTitleArgb,
        bodyArgb = EmptyStateInkSpec.OnPhotoBodyArgb,
    )

    is EmptyStateInk.OverBackdrop -> {
        val backdrop = ink.wallpaperLuminance ?: ink.pageBackgroundLuminance
        val configuredArgb = HomeBackgroundModel.parseInkArgb(ink.configuredArgbHex)
        // 亮度未知且没有自定义色 ⇒ 整组回主题墨（说明保留主题次级色，**不能**拿标题墨再压淡：
        // 那样 0xFF666666 会变成 0xB3333333，等于把「主题说明色」换成了「压淡的标题色」）。
        if (backdrop == null && configuredArgb == null) {
            EmptyStateColorsArgb(
                titleArgb = themeTitleArgb,
                bodyArgb = themeBodyArgb,
            )
        } else {
            val titleArgb = HomeBackgroundModel.inkOverWallpaperArgb(
                configuredArgb = configuredArgb,
                fallbackArgb = themeTitleArgb,
                wallpaperLuminance = backdrop,
                builtInDefaultArgb = HomeBackgroundModel.parseInkArgb(ink.defaultInkHex),
            )
            EmptyStateColorsArgb(
                titleArgb = titleArgb,
                bodyArgb = HomeBackgroundModel.mutedInkOverWallpaperArgb(titleArgb),
            )
        }
    }
}
