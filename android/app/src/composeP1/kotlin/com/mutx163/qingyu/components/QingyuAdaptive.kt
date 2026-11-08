package com.mutx163.qingyu.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.QingyuAdaptiveRules
import top.yukonga.miuix.kmp.basic.NavigationRailDefaults

/**
 * 页面骨架消费的宽屏自适应取值，由 [rememberQingyuWindowAdaptive] 按**窗口宽度**算出。
 *
 * @param isWideScreen 宽屏档（≥840dp，或 ≥600dp 且横扁）：可折叠大标题收成单行小标题。
 * @param maxContentWidth 内容列上限；null = 紧凑档保持通栏（现状），非 null = 限宽居中。
 */
class QingyuWindowAdaptive(
    val isWideScreen: Boolean,
    val maxContentWidth: Dp?,
)

/**
 * 壳层注入 seam（对应官方 demo `AppContent.kt:154` 的 `LocalIsWideScreen`）。
 *
 * 壳层的 Rail 批次接入后，应在 `PagesShell` 根部用 `CompositionLocalProvider` 注入
 * 以**内容区宽度**算出的取值（Rail 占掉左侧宽度后，内容区宽 ≠ 窗口宽，页面自算会失真）。
 *
 * 默认 null = 壳层尚未注入，骨架按窗口尺寸自算——平板 / 折叠屏内屏竖持这类
 * **不解锁横屏也存在的宽窗**立即生效，不依赖壳层改造。判据与全部数值都在
 * core/QingyuAdaptiveRules.kt（纯 Kotlin，L0 可测），本文件只做 Compose 接线。
 */
val QingyuLocalWindowAdaptive = staticCompositionLocalOf<QingyuWindowAdaptive?> { null }

/**
 * 读当前窗口的宽屏自适应取值：壳层注入优先；未注入时按 [LocalWindowInfo] 的容器尺寸
 * 自算（与 demo `AdaptiveUtils.kt:12-21` 同一读法，拿的是真实窗口而非设备型号）。
 */
@Composable
fun rememberQingyuWindowAdaptive(): QingyuWindowAdaptive {
    val injected = QingyuLocalWindowAdaptive.current
    if (injected != null) return injected
    val density = LocalDensity.current
    val containerSize = LocalWindowInfo.current.containerSize
    return remember(containerSize, density) {
        val widthDp = with(density) { containerSize.width.toDp().value }
        val heightDp = with(density) { containerSize.height.toDp().value }
        qingyuAdaptiveFor(widthDp, heightDp)
    }
}

/** 由一组 dp 尺寸换算页面自适应取值（限宽列 = 640dp 或不限）。 */
private fun qingyuAdaptiveFor(widthDp: Float, heightDp: Float): QingyuWindowAdaptive =
    QingyuWindowAdaptive(
        isWideScreen = QingyuAdaptiveRules.isWideScreen(widthDp, heightDp),
        maxContentWidth = if (QingyuAdaptiveRules.shouldLimitContentWidth(widthDp)) {
            QingyuAdaptiveRules.DEFAULT_MAX_CONTENT_WIDTH_DP.dp
        } else {
            null
        },
    )

/**
 * 壳层 Rail 的取值包：Rail 是否显示、是否展开、注入给页面的内容区自适应值。
 */
class QingyuShellRailAdaptive(
    val railVisible: Boolean,
    val railExpanded: Boolean,
    val contentAdaptive: QingyuWindowAdaptive,
)

/**
 * 壳层专用（第 2 批）：按**窗口宽**判 Rail 显示 / 展开；Rail 出现后，给页面注入按
 * **内容区宽**（窗口宽 − Rail 宽）算的取值——否则限宽列会对着 Rail 底下的区域居中。
 *
 * Rail 宽度直接取 miuix 官方常量（[NavigationRailDefaults.MinWidth] / [ExpandedWidth]），
 * 不自抄一份。展开/收起动画期间实际宽度在两值之间过渡，页面取值按目标宽度跳变即可
 * （640dp 上限在动画两端都成立）。
 *
 * @param railEnabled 壳层传入的「用户要不要导航」：玻璃坞形态 = true；classic 档用户
 *   显式关掉了导航，宽屏也不加回 Rail（保持用户的选择，[railVisible] 恒 false）。
 */
@Composable
fun rememberQingyuShellRailAdaptive(railEnabled: Boolean = true): QingyuShellRailAdaptive {
    val density = LocalDensity.current
    val containerSize = LocalWindowInfo.current.containerSize
    return remember(containerSize, density, railEnabled) {
        val widthDp = with(density) { containerSize.width.toDp().value }
        val heightDp = with(density) { containerSize.height.toDp().value }
        val railVisible = railEnabled && QingyuAdaptiveRules.isWideScreen(widthDp, heightDp)
        val expanded = railVisible && QingyuAdaptiveRules.shouldExpandNavigationRail(widthDp)
        val railWidth = if (railVisible) {
            if (expanded) NavigationRailDefaults.ExpandedWidth else NavigationRailDefaults.MinWidth
        } else {
            0.dp
        }
        val area = QingyuAdaptiveRules.contentAreaAdaptive(widthDp, heightDp, railWidth.value)
        QingyuShellRailAdaptive(
            railVisible = railVisible,
            railExpanded = expanded,
            contentAdaptive = QingyuWindowAdaptive(
                isWideScreen = area.isWideScreen,
                maxContentWidth = if (area.limitContentWidth) {
                    QingyuAdaptiveRules.DEFAULT_MAX_CONTENT_WIDTH_DP.dp
                } else {
                    null
                },
            ),
        )
    }
}

/**
 * 弹层正文的限高（`heightIn(max = …)` 用）：高窗口 = 屏高 × [fraction]，
 * 矮窗口（横屏 / 分屏 / 自由窗口）自动放宽。
 *
 * 为什么收成一处：全仓原本 16 个调用点各自写 `screenHeightDp * 比例`，矮窗下同一个
 * 问题要改 16 遍，且新页面很容易漏。判据本体在 [QingyuAdaptiveRules.sheetMaxHeightDp]
 * （纯 Kotlin，L0 可测）；本函数只做 Compose 接线，读数仍是 `screenHeightDp`
 * ——与改造前完全同源，所以高窗口（手机竖屏 / 平板竖屏）逐像素不变。
 */
@Composable
fun rememberSheetMaxHeight(fraction: Float): Dp {
    val screenHeightDp = LocalConfiguration.current.screenHeightDp
    return remember(screenHeightDp, fraction) {
        QingyuAdaptiveRules.sheetMaxHeightDp(screenHeightDp.toFloat(), fraction).dp
    }
}

/**
 * 写死 dp 上限的弹层用：矮窗口下夹到「屏高 − 180dp」，高窗口原样返回 [desired]。
 *
 * 与 [rememberSheetMaxHeight] 同一套账；区别是调用方本来就有个固定上限（380 / 420dp）。
 */
@Composable
fun rememberCappedSheetHeight(desired: Dp): Dp {
    val screenHeightDp = LocalConfiguration.current.screenHeightDp
    return remember(screenHeightDp, desired) {
        QingyuAdaptiveRules.cappedSheetHeightDp(screenHeightDp.toFloat(), desired.value).dp
    }
}
