package com.mutx163.qingyu.components

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.theme.ColorSchemeMode
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.theme.ThemeController
import top.yukonga.miuix.kmp.theme.darkColorScheme
import top.yukonga.miuix.kmp.theme.lightColorScheme

/**
 * 页面级主题桥：把自家色板填进官方 [MiuixTheme]，并跟随系统深色。
 *
 * ## 为什么需要它（一次真实缺陷）
 *
 * 两个页面壳（`PagesShellActivity.kt:54`、`ComposeP1Activity.kt:57`）写的是
 * 无参 `MiuixTheme { }`。官方这个重载的 `colors` 默认值直接取
 * `MiuixTheme.colorScheme`，也就是 [top.yukonga.miuix.kmp.theme.LocalColors]
 * 的静态默认值——**永远是亮色**（`Colors.kt:618`）。而页面正文取色走的是
 * `QingyuTheme.primaryText(dark)`，`dark` 来自 `isSystemInDarkTheme()`。
 *
 * 两者一错位，系统切深色后就会出现：页面底色 `#242424`、正文取白，
 * 而 `Card` 的默认色 `surfaceContainer` 仍是亮色板的 `#FFFFFF`
 * → **白字落在白卡片上，直接看不见**。这不是审美问题，是内容不可读。
 *
 * ## 为什么修在页面里，而不是改壳
 *
 * 两个壳在 Phase 3 台账 §6 是 Lead 专属写作用域，且被全部批次共用；
 * 改它们会立刻影响另外 11 个「进行中」的批次。用页面级包装先把已验收的
 * 页面修好，壳的彻底修复留作单独一次（届时删掉本文件的包装即可，
 * 因为映射逻辑都在 [qingyuLightColors] / [qingyuDarkColors] 里，可原样搬过去）。
 *
 * ## 为什么用 [ThemeController] 而不是 `MiuixTheme(colors = …)`
 *
 * 后者只认一份配色、不认明暗，系统切换时不会重组。前者按
 * `ColorSchemeMode.System` 在 `lightColors/darkColors` 之间自动切换
 * （`ThemeController.kt:236-241`），且把 `colorSchemeMode` 放进
 * CompositionLocal，弹层（`OverlayDialog` / `OverlayBottomSheet`）在
 * 同一棵树里能取到一致的配色。
 *
 * ## 只覆写必须覆写的槽位
 *
 * 依据 `docs/plans/2026-10-26-compose-phase3-prep.md` §2.1：Material 侧
 * 只有 primary/onPrimary 被主题色触碰，其余一切以 Hyperos/Miuix 色板为准。
 * 所以这里**不重播 fromSeed 全量**，只把页面底色、卡片、文字、分割线这几类
 * 语义槽对到 [QingyuTheme] 的同名取值上；未列出的槽位沿用官方默认。
 */
@Composable
fun QingyuPageTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    // 两份配色必须在 Composable 上下文里先算出来（`remember` 的 lambda 不是
    // @Composable 作用域，不能在里面调 @Composable 函数）。
    val lightColors = qingyuLightColors()
    val darkColors = qingyuDarkColors()
    val controller = androidx.compose.runtime.remember(lightColors, darkColors, dark) {
        ThemeController(
            colorSchemeMode = ColorSchemeMode.System,
            lightColors = lightColors,
            darkColors = darkColors,
            isDark = dark,
        )
    }
    MiuixTheme(controller = controller, content = content)
}

/** 亮色板：语义槽对齐 [QingyuTheme]，未列出的沿用官方默认值。 */
@Composable
private fun qingyuLightColors() = lightColorScheme(
    // 页面底色（Scaffold containerColor 与 Card 的对比基线）
    background = Color(QingyuTheme.scaffoldBackground(dark = false)),
    onBackground = Color(QingyuTheme.primaryText(dark = false)),
    onBackgroundVariant = Color(QingyuTheme.secondaryText(dark = false)),
    // surface / surfaceContainer 是 Scaffold 与 Card 的默认取色处；
    // 分开填是因为亮色板里页面底是 #F2F2F2、卡片是 #FFFFFF，必须有层次。
    surface = Color(QingyuTheme.scaffoldBackground(dark = false)),
    surfaceContainer = Color(QingyuTheme.card(dark = false)),
    onSurfaceContainer = Color(QingyuTheme.primaryText(dark = false)),
    onSurfaceContainerVariant = Color(QingyuTheme.secondaryText(dark = false)),
    surfaceContainerHigh = Color(QingyuTheme.card(dark = false)),
    surfaceContainerHighest = Color(QingyuTheme.surfaceContainerHighest(dark = false)),
    onSurfaceVariantSummary = Color(QingyuTheme.secondaryText(dark = false)),
    onSurfaceVariantActions = Color(QingyuTheme.actionIcon(dark = false)),
    primary = Color(QingyuTheme.primary(dark = false)),
    onPrimary = Color(QingyuTheme.onAccent(dark = false)),
    primaryVariant = Color(QingyuTheme.primary(dark = false)),
    secondary = Color(QingyuTheme.secondary(dark = false)),
    dividerLine = Color(QingyuTheme.dividerLine(dark = false)),
    outline = Color(QingyuTheme.outline(dark = false)),
    error = Color(QingyuTheme.error(dark = false)),
    onError = Color(QingyuTheme.onError(dark = false)),
)

/** 深色板：**这一份是本次修复的核心**——之前完全没有生效过。 */
@Composable
private fun qingyuDarkColors() = darkColorScheme(
    background = Color(QingyuTheme.scaffoldBackground(dark = true)),
    onBackground = Color(QingyuTheme.primaryText(dark = true)),
    onBackgroundVariant = Color(QingyuTheme.secondaryText(dark = true)),
    // 深色下卡片刻意取「最高级容器」而非与页底同色（见 QingyuTheme.card 注释：
    // 页底 #242424 与 surfaceContainer #242424 相同会让卡片在暗色下隐形）。
    surface = Color(QingyuTheme.scaffoldBackground(dark = true)),
    surfaceContainer = Color(QingyuTheme.card(dark = true)),
    onSurfaceContainer = Color(QingyuTheme.primaryText(dark = true)),
    onSurfaceContainerVariant = Color(QingyuTheme.secondaryText(dark = true)),
    surfaceContainerHigh = Color(QingyuTheme.card(dark = true)),
    surfaceContainerHighest = Color(QingyuTheme.surfaceContainerHighest(dark = true)),
    onSurfaceVariantSummary = Color(QingyuTheme.secondaryText(dark = true)),
    onSurfaceVariantActions = Color(QingyuTheme.actionIcon(dark = true)),
    primary = Color(QingyuTheme.primary(dark = true)),
    onPrimary = Color(QingyuTheme.onAccent(dark = true)),
    primaryVariant = Color(QingyuTheme.primary(dark = true)),
    secondary = Color(QingyuTheme.secondary(dark = true)),
    dividerLine = Color(QingyuTheme.dividerLine(dark = true)),
    outline = Color(QingyuTheme.outline(dark = true)),
    error = Color(QingyuTheme.error(dark = true)),
    onError = Color(QingyuTheme.onError(dark = true)),
)
