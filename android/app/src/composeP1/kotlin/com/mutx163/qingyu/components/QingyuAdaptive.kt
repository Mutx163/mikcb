package com.mutx163.qingyu.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.QingyuAdaptiveRules

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
        QingyuWindowAdaptive(
            isWideScreen = QingyuAdaptiveRules.isWideScreen(widthDp, heightDp),
            maxContentWidth = if (QingyuAdaptiveRules.shouldLimitContentWidth(widthDp)) {
                QingyuAdaptiveRules.DEFAULT_MAX_CONTENT_WIDTH_DP.dp
            } else {
                null
            },
        )
    }
}
