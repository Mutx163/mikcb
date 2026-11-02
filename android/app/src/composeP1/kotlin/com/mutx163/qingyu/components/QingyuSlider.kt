package com.mutx163.qingyu.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.NonRestartableComposable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.BasicComponentDefaults
import top.yukonga.miuix.kmp.basic.Slider
import top.yukonga.miuix.kmp.basic.SliderColors
import top.yukonga.miuix.kmp.basic.SliderDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.ArrowRight
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 官方 [Slider] + **点轨道直接跳到点击位置**。
 *
 * ## 为什么需要这一层
 *
 * miuix 0.9.4 的 `Slider` 只挂了一个 `Modifier.draggable`（源码
 * `miuix-ui/.../basic/Slider.kt` 的触摸分支）——纯点一下（按下即抬起、没有越过
 * touch slop）`draggable` 根本不会启动，回调一次都不发。用户看到的就是
 * 「点某个位置没反应，只能按住圆点拖」。Flutter 侧的 `MiuixSlider` 有
 * `onTapUp → _jumpTo`（`lib/src/theme/miuix/components/miuix_slider.dart:375-434`），
 * 迁移到 Compose 后这个能力丢了，这里补回来。
 *
 * ## 为什么是这个写法
 *
 * - 只加**一层点击手势**，视觉、动画、按压反馈、触感全部仍由官方 `Slider` 负责；
 * - `pointerInput` 挂在官方 `Slider` 的 `modifier` 上 = 官方 `draggable` 的**外层**。
 *   Main pass 由内向外派发：`draggable` 先看到 down（它要等 slop，不会消费），
 *   随后这里消费 down —— 于是包在滑杆外面的可点行（如 `BasicComponent` 的
 *   行点击）不会再收到这次点击，点到轨道是「调值」而不是「弹对话框」；
 * - 数值换算与官方同一口径，见 [SliderTapMath]。
 *
 * 例外登记：`docs/reference/miuix-component-first-standard.md` §例外审批登记。
 */
@Composable
fun QingyuSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    valueRange: ClosedFloatingPointRange<Float> = 0f..1f,
    steps: Int = 0,
    onValueChangeFinished: (() -> Unit)? = null,
    reverseDirection: Boolean = false,
    height: Dp = SliderDefaults.MinHeight,
    colors: SliderColors = SliderDefaults.sliderColors(),
    hapticEffect: SliderDefaults.SliderHapticEffect = SliderDefaults.DefaultHapticEffect,
    showKeyPoints: Boolean = false,
    keyPoints: List<Float>? = null,
    magnetThreshold: Float = 0.02f,
) {
    val trackHeightPx = with(LocalDensity.current) { height.toPx() }
    val layoutDirection = LocalLayoutDirection.current
    // miuix 自己在 RTL 下把方向反过来；点击换算必须跟它一致。
    val effectiveReverseDirection =
        if (layoutDirection == LayoutDirection.Rtl) !reverseDirection else reverseDirection

    val currentOnValueChange by rememberUpdatedState(onValueChange)
    val currentOnValueChangeFinished by rememberUpdatedState(onValueChangeFinished)

    val tapModifier = if (enabled) {
        modifier.pointerInput(
            valueRange,
            steps,
            keyPoints,
            magnetThreshold,
            effectiveReverseDirection,
            trackHeightPx,
        ) {
            awaitEachGesture {
                // requireUnconsumed = false：官方 `Slider` 的 `draggable` 在内层，
                // 它先看到 down 但不消费（要等 touch slop），这里接住。
                val down = awaitFirstDown(requireUnconsumed = false)
                // 消费 down：包在滑杆外的可点行（`BasicComponent` 的 onClick）
                // 不应把「点轨道调值」当成「点整行」。滚动容器不受影响
                // （`scrollable` / `draggable` 接受已消费的 down，只等 slop）。
                down.consume()

                var tappedUp: PointerInputChange? = null
                while (true) {
                    val event = awaitPointerEvent()
                    val change = event.changes.firstOrNull { it.id == down.id } ?: break
                    if (change.isConsumed) break
                    if (!change.pressed) {
                        tappedUp = change
                        break
                    }
                    // 越过 touch slop 就是拖 / 滚，不是点击；交给官方 draggable
                    // 与父级滚动，别在手指抬起时补一次跳值。
                    if ((change.position - down.position).getDistance() > viewConfiguration.touchSlop) {
                        break
                    }
                }

                if (tappedUp != null) {
                    tappedUp.consume()
                    val newValue = SliderTapMath.valueForTap(
                        tapX = tappedUp.position.x,
                        trackWidthPx = size.width.toFloat(),
                        trackHeightPx = trackHeightPx,
                        valueRange = valueRange,
                        steps = steps,
                        keyPoints = keyPoints,
                        magnetThreshold = magnetThreshold,
                        reverseDirection = effectiveReverseDirection,
                    )
                    currentOnValueChange(newValue)
                    currentOnValueChangeFinished?.invoke()
                }
            }
        }
    } else {
        modifier
    }

    Slider(
        value = value,
        onValueChange = onValueChange,
        modifier = tapModifier,
        enabled = enabled,
        valueRange = valueRange,
        steps = steps,
        onValueChangeFinished = onValueChangeFinished,
        reverseDirection = reverseDirection,
        height = height,
        colors = colors,
        hapticEffect = hapticEffect,
        showKeyPoints = showKeyPoints,
        keyPoints = keyPoints,
        magnetThreshold = magnetThreshold,
    )
}

/**
 * 官方 `preference.SliderPreference` 的逐字副本，唯一改动：内层 `Slider` →
 * [QingyuSlider]（补「点轨道跳到点击位置」）。
 *
 * 为什么不能直接包官方 `SliderPreference`：它没把内层 `Slider` 的 `modifier`
 * 开放出来，外面再套一层点击层会被它自己的 `BasicComponent` 行点击抢先消费，
 * 而且几何要按组件内部布局去猜。副本与官方 0.9.4 源码逐行对齐，官方升级时
 * 只需重新比对这一份（入口很小）。
 */
@Composable
@NonRestartableComposable
fun QingyuSliderPreference(
    value: Float,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    title: String? = null,
    summary: String? = null,
    valueText: String? = null,
    onClick: (() -> Unit)? = null,
    enabled: Boolean = true,
    valueRange: ClosedFloatingPointRange<Float> = 0f..1f,
    steps: Int = 0,
    onValueChangeFinished: (() -> Unit)? = null,
    reverseDirection: Boolean = false,
    sliderHeight: Dp = SliderDefaults.MinHeight,
    sliderColors: SliderColors = SliderDefaults.sliderColors(),
    hapticEffect: SliderDefaults.SliderHapticEffect = SliderDefaults.DefaultHapticEffect,
    showKeyPoints: Boolean = false,
    keyPoints: List<Float>? = null,
    magnetThreshold: Float = 0.02f,
    insideMargin: PaddingValues = BasicComponentDefaults.InsideMargin,
) {
    val showArrow = onClick != null
    val showEndArea = valueText != null || showArrow

    BasicComponent(
        modifier = modifier,
        insideMargin = insideMargin,
        title = title,
        summary = summary,
        endActions = if (showEndArea) {
            {
                Row(
                    modifier = Modifier
                        .padding(end = 8.dp)
                        .align(Alignment.CenterVertically)
                        .weight(1f, fill = false),
                ) {
                    if (valueText != null) {
                        Text(
                            text = valueText,
                            fontSize = MiuixTheme.textStyles.body2.fontSize,
                            color = if (enabled) {
                                MiuixTheme.colorScheme.onSurfaceVariantActions
                            } else {
                                MiuixTheme.colorScheme.disabledOnSecondaryVariant
                            },
                        )
                    }
                }
                if (showArrow) {
                    QingyuSliderPreferenceArrowIcon(enabled = enabled)
                }
            }
        } else {
            null
        },
        bottomAction = {
            QingyuSlider(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.fillMaxWidth(),
                enabled = enabled,
                valueRange = valueRange,
                steps = steps,
                onValueChangeFinished = onValueChangeFinished,
                reverseDirection = reverseDirection,
                height = sliderHeight,
                colors = sliderColors,
                hapticEffect = hapticEffect,
                showKeyPoints = showKeyPoints,
                keyPoints = keyPoints,
                magnetThreshold = magnetThreshold,
            )
        },
        onClick = onClick,
        enabled = enabled,
    )
}

@Composable
private fun RowScope.QingyuSliderPreferenceArrowIcon(
    enabled: Boolean,
) {
    // 与官方 `ArrowPreferenceDefaults.endActionColors()` 取同一组色（它是
    // `internal fun color(enabled)`，跨模块调不到，这里按同样规则取色）。
    val color = if (enabled) {
        MiuixTheme.colorScheme.onSurfaceVariantActions
    } else {
        MiuixTheme.colorScheme.disabledOnSecondaryVariant
    }
    val tintFilter = remember(color) { ColorFilter.tint(color) }
    val layoutDirection = LocalLayoutDirection.current
    Image(
        modifier = Modifier
            .size(width = 10.dp, height = 16.dp)
            .graphicsLayer {
                scaleX = if (layoutDirection == LayoutDirection.Rtl) -1f else 1f
            }
            .align(Alignment.CenterVertically),
        imageVector = MiuixIcons.Basic.ArrowRight,
        contentDescription = null,
        colorFilter = tintFilter,
    )
}
