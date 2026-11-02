package com.mutx163.qingyu.components

import android.content.res.Configuration
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Density
import com.mutx163.qingyu.theme.QingyuTheme
import com.mutx163.qingyu.theme.QingyuTypography
import top.yukonga.miuix.kmp.theme.ColorSchemeMode
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.theme.ThemeController
import top.yukonga.miuix.kmp.theme.darkColorScheme
import top.yukonga.miuix.kmp.theme.lightColorScheme

/**
 * 当前生效的外观档位（种子色 / 字重 / 字族 / 字号）。
 *
 * 由最外层 [QingyuPageTheme]（壳 Activity）写入；页面里再包一层无参
 * [QingyuPageTheme] 时**默认继承**这组值，而不是回到出厂默认。
 *
 * 2026-11-02 修：页面骨架（`QingyuPageScaffold`）与十几个独立页面都会自己再包
 * 一层无参 `QingyuPageTheme { }`。那层的形参默认值原来是「种子色 null、字重 400、
 * 字族 null、字号 1.0」——于是壳里选的主题色 / 字重 / 字体被页面这一层**静默覆盖**
 * 回默认值：外观页改完设置，页面正文纹丝不动，只有壳自己的顶栏 / 坞跟着变。
 * 这不是某页漏接，是「嵌套包裹时默认值不该重置外层」。
 *
 * 用 `staticCompositionLocalOf` 而不是 `compositionLocalOf`：外观设置一变本来就该
 * 整树换肤，不需要逐读取点追踪依赖。
 */
private data class QingyuPageAppearance(
    val seedColor: String? = null,
    val userFontWeight: Int = QingyuTypography.WEIGHT_DEFAULT,
    val fontFamily: FontFamily? = null,
    val textScale: Float = 1f,
)

private val LocalQingyuPageAppearance = staticCompositionLocalOf { QingyuPageAppearance() }

/**
 * 字号缩放**之前**的基准 density。
 *
 * 页面嵌套 [QingyuPageTheme] 时，外层已经按 `textScale` 放大过 `fontScale`；
 * 内层若拿外层的 density 再乘一次，字号会被平方放大（1.2 → 1.44）。
 * 所以把「还没缩放的基准」单独记一份，每一层都从基准乘一次，结果与只包一层相同。
 */
private val LocalQingyuBaseDensity = staticCompositionLocalOf<Density?> { null }

/**
 * 页面级主题桥：把自家色板填进官方 [MiuixTheme]，并承载「外观设置」的几项映射：
 * 明暗档（[isDark]）、主题种子色（[seedColor]）、应用字重 / 字族 / 字号（[rememberQingyuTextStyles]）。
 *
 * ## 嵌套包裹：默认继承外层，不重置
 *
 * 页面骨架和独立页面都会自己再包一层无参 [QingyuPageTheme]。四个外观形参的默认值
 * 因此取 [LocalQingyuPageAppearance]（外层写入的当前档位），**不是**出厂默认——
 * 否则页面这一层会把壳里选的主题色 / 字重 / 字体静默覆盖回去。
 * 显式传参仍然以传参为准（例如壳 Activity 从设置模型读出真值）。
 *
 * ## 明暗与「系统深色」的关系
 *
 * [isDark] 由外壳按「主题模式 + 系统」解析后传入，默认 `isSystemInDarkTheme()`。这里除了
 * 交给 [ThemeController]，还会覆盖 `LocalConfiguration` 的 `uiMode` 深色位——页面里 91 处
 * 直接调 `isSystemInDarkTheme()` 取色，覆盖后它们自动与主题档同口径，不必逐页改。
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
fun QingyuPageTheme(
    /** 明暗档：由外壳按「外观设置的主题模式 + 系统」解析后传入（默认跟随系统）。 */
    isDark: Boolean = isSystemInDarkTheme(),
    /** 主题种子色（`themeSeedColor` 的十六进制串）；null = 不派生，用固定蓝。 */
    seedColor: String? = LocalQingyuPageAppearance.current.seedColor,
    userFontWeight: Int = LocalQingyuPageAppearance.current.userFontWeight,
    fontFamily: FontFamily? = LocalQingyuPageAppearance.current.fontFamily,
    /** 应用字号倍率（`appTextScale`）：1.0 = 不变。 */
    textScale: Float = LocalQingyuPageAppearance.current.textScale,
    content: @Composable () -> Unit,
) {
    // 两份配色必须在 Composable 上下文里先算出来（`remember` 的 lambda 不是
    // @Composable 作用域，不能在里面调 @Composable 函数）。
    val lightColors = qingyuLightColors(seedColor)
    val darkColors = qingyuDarkColors(seedColor)
    // 字阶同理：`rememberQingyuTextStyles` 是 @Composable，要在外面先取。
    val textStyles = rememberQingyuTextStyles(
        userFontWeight = userFontWeight,
        fontFamily = fontFamily,
    )
    val controller = androidx.compose.runtime.remember(lightColors, darkColors, isDark) {
        ThemeController(
            colorSchemeMode = ColorSchemeMode.System,
            lightColors = lightColors,
            darkColors = darkColors,
            isDark = isDark,
        )
    }

    // ── 把「应用主题模式」广播给整棵子树 ─────────────────────────────────────
    //
    // 91 处页面代码直接调 `isSystemInDarkTheme()` 去取 `QingyuTheme.xxx(dark)`。若只把
    // 官方 `MiuixTheme` 的明暗改掉、不覆盖 `LocalConfiguration`，会出现「卡片按深色、
    // 正文按亮色」的错位。`isSystemInDarkTheme()` 读的就是 `LocalConfiguration.uiMode`
    // （Compose 源码），所以在这里覆盖一次，全站取值口径就跟着 `isDark` 走，
    // 不必逐页改那 91 处。
    val baseConfig = LocalConfiguration.current
    val effectiveConfig = androidx.compose.runtime.remember(baseConfig, isDark) {
        withNightMode(baseConfig, isDark)
    }

    // 字号倍率：只缩放 `fontScale`（sp→px），不动 `density`（dp→px），
    // 于是布局尺寸不变、只有文字按比例放大/缩小——与 Dart `appTextScale` 的口径一致。
    //
    // 嵌套包裹时取「缩放前的基准」（见 [LocalQingyuBaseDensity]），否则同一档
    // 字号会被外层、内层各乘一次。
    val baseDensity = LocalQingyuBaseDensity.current ?: LocalDensity.current
    val effectiveDensity = androidx.compose.runtime.remember(baseDensity, textScale) {
        if (textScale == 1f) {
            baseDensity
        } else {
            Density(baseDensity.density, baseDensity.fontScale * textScale)
        }
    }

    CompositionLocalProvider(
        LocalQingyuPageAppearance provides QingyuPageAppearance(
            seedColor = seedColor,
            userFontWeight = userFontWeight,
            fontFamily = fontFamily,
            textScale = textScale,
        ),
        LocalQingyuBaseDensity provides baseDensity,
        LocalConfiguration provides effectiveConfig,
        LocalDensity provides effectiveDensity,
    ) {
        // ⚠️ textStyles 必须显式传：
        //
        // 官方 `MiuixTheme(controller = …, content = …)` 的 `textStyles` 默认值取的是
        // `MiuixTheme.textStyles`，也就是**当前组合里的** LocalTextStyles。在页面这一层
        // 那已经是我们自己注入过的（壳那层先注入），所以"不传"看起来也"能工作"——
        // 但一旦有页面在更外层被单独使用（预览、测试、未来的独立宿主），就会静默回落到
        // 官方默认字阶，用户字重与系统粗体当场失效。显式传是防这种静默回落。
        MiuixTheme(controller = controller, textStyles = textStyles, content = content)
    }
}

/** 复制一份配置，只把 `uiMode` 的深色位改成 [dark]（其余字段原样保留）。 */
private fun withNightMode(base: Configuration, dark: Boolean): Configuration {
    val mode = if (dark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
    val uiMode = (base.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or mode
    return Configuration(base).apply { this.uiMode = uiMode }
}

/** 亮色板：语义槽对齐 [QingyuTheme]，未列出的沿用官方默认值。 */
@Composable
private fun qingyuLightColors(seedHex: String?) = lightColorScheme(
    // 页面底色（Scaffold containerColor 与 Card 的对比基线）
    background = Color(QingyuTheme.scaffoldBackground(dark = false)),
    onBackground = Color(QingyuTheme.primaryText(dark = false)),
    onBackgroundVariant = Color(QingyuTheme.secondaryText(dark = false)),
    // 官方弹层默认取这两槽：`OverlayBottomSheet` 标题用 onSurface、`OverlayDialog` 的
    // `summary` 正文用 onSurfaceSecondary。官方默认值是纯黑 / 80% 黑，与本仓 #333 / #999
    // 对不上，会表现为「弹层标题比页面标题更黑、次级正文像主文本」。
    onSurface = Color(QingyuTheme.primaryText(dark = false)),
    onSurfaceSecondary = Color(QingyuTheme.secondaryText(dark = false)),
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
    primary = Color(QingyuTheme.primary(seedHex, dark = false)),
    onPrimary = Color(QingyuTheme.onAccent(dark = false)),
    primaryVariant = Color(QingyuTheme.primary(seedHex, dark = false)),
    secondary = Color(QingyuTheme.secondary(dark = false)),
    dividerLine = Color(QingyuTheme.dividerLine(dark = false)),
    outline = Color(QingyuTheme.outline(dark = false)),
    error = Color(QingyuTheme.error(dark = false)),
    onError = Color(QingyuTheme.onError(dark = false)),
)

/** 深色板：**这一份是本次修复的核心**——之前完全没有生效过。 */
@Composable
private fun qingyuDarkColors(seedHex: String?) = darkColorScheme(
    background = Color(QingyuTheme.scaffoldBackground(dark = true)),
    onBackground = Color(QingyuTheme.primaryText(dark = true)),
    onBackgroundVariant = Color(QingyuTheme.secondaryText(dark = true)),
    // 弹层标题 / 对话框次级正文，口径同亮色板（见上方注释）。
    onSurface = Color(QingyuTheme.primaryText(dark = true)),
    onSurfaceSecondary = Color(QingyuTheme.secondaryText(dark = true)),
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
    primary = Color(QingyuTheme.primary(seedHex, dark = true)),
    onPrimary = Color(QingyuTheme.onAccent(dark = true)),
    primaryVariant = Color(QingyuTheme.primary(seedHex, dark = true)),
    secondary = Color(QingyuTheme.secondary(dark = true)),
    dividerLine = Color(QingyuTheme.dividerLine(dark = true)),
    outline = Color(QingyuTheme.outline(dark = true)),
    error = Color(QingyuTheme.error(dark = true)),
    onError = Color(QingyuTheme.onError(dark = true)),
)
