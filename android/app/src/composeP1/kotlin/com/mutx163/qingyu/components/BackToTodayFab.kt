package com.mutx163.qingyu.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.liquid.InteractiveHighlight
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.core.HomeMaterialRenderSpec
import com.mutx163.qingyu.core.SurfaceMaterialState
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.tanh
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「今」悬浮胶囊（日视图「回今日」/ 周视图「回本周」共用的唯一实现）。
 *
 * ## 形态
 *
 * 用户口径是「玻璃胶囊上的一个『今』」——不是圆形/圆球，也不是实心色块：
 *
 * | 层 | 做法 | 缺了会怎样 |
 * |---|---|---|
 * | 底 | `drawBackdrop` + `vibrancy()` + `blur()`，液态档再叠 `lens()` | 只剩一块蒙雾的半透明塑料片，没有折射与边缘厚度 |
 * | 染色 | 主题主色 `primary × liquidTintAlpha` | 玻璃退化成灰色 |
 * | 亮棱 | 官方 `Highlight.GlassStrokeSmall*` | 胶囊与背景之间没有一条能读作「玻璃边缘」的细光 |
 * | 投影 | `dropShadow`（主色 40%、10dp、下移 4dp） | 钮像贴在卡片上，浮不起来 |
 * | 字 | `title3`（20sp）+ `shiftWeight(MEDIUM)`，主题 `onPrimary` | 小一号的字会让胶囊显得又矮又空 |
 *
 * 材质档跟随**玻璃坞**（`material.dock`），不是课卡：浮钮与底栏是同一族控件。
 * `FROST` 只模糊不折射，`LIQUID_GLASS` 才叠镜片；其余档（实体 / OFF）画实底，
 * 无壁纸或设备画不出着色器时同样回落实底——不对着空气做模糊。
 *
 * ## 手感
 *
 * 按下由 [InteractiveHighlight] 提亮并点亮指尖光斑，同时整块玻璃按 `pressProgress`
 * 放大、按拖动方向轻微拉伸；外层 `graphicsLayer` 用 `tanh` 阻尼跟手（位移约为手指的
 * 8%，越拖越钝）。松手后三者各自用弹簧归位。
 *
 * ## 出入场
 *
 * `AnimatedVisibility` + 官方 `fadeIn` / `scaleIn`（自底部中心 0.6 → 1，320ms；退场
 * 200ms）。与 miuix 自己的 Tooltip 是同一套原语，不是自绘动画。
 *
 * @param onClick 点击回调（日视图回今天那一天；周视图回到本周）。
 * @param label 屏上可见文字（调用方传单字「今」的既有键）。
 * @param contentDescription 读屏完整语义（调用方传各自域的既有键）。
 * @param visible 是否显示；切换时播放出入场动画。**不要**用 `if` 在外面包一层，
 *   否则退场动画没有机会播。
 * @param backdrop 页面壁纸录像层；`null` = 不采样（实底回落）。
 * @param material 材质快照（`SettingsMaterialModel.renderSpecOf` 的唯一出口）。
 * @param hasBackdrop 当前有没有可用壁纸；没有壁纸时一律实底。
 * @param alpha 整钮透明度（周视图的「浮钮透明度」设置作用在染色与文字上；日视图恒 1）。
 *   不包住整块玻璃——包住会让采样层失去背后内容。
 */
@Composable
fun BackToTodayFab(
    onClick: () -> Unit,
    label: String,
    contentDescription: String,
    visible: Boolean = true,
    backdrop: Backdrop? = null,
    material: HomeMaterialRenderSpec? = null,
    hasBackdrop: Boolean = false,
    alpha: Float = 1f,
    modifier: Modifier = Modifier,
) {
    val shape = remember { RoundedCornerShape(percent = 50) }
    val opacity = alpha.coerceIn(0f, 1f)
    val dark = isSystemInDarkTheme()
    val primary = MiuixTheme.colorScheme.primary
    val dockState = material?.dock
    // 与玻璃坞同一档：真有壁纸 + 设备支持 runtime shader + 坞本身就是玻璃材质。
    val glassActive = backdrop != null &&
        hasBackdrop &&
        isRuntimeShaderSupported() &&
        (dockState == SurfaceMaterialState.LIQUID_GLASS || dockState == SurfaceMaterialState.FROST)
    val liquid = dockState == SurfaceMaterialState.LIQUID_GLASS
    val solidColor = primary.copy(alpha = opacity)
    val tint = primary.copy(
        alpha = ((material?.liquidTintAlpha ?: FAB_DEFAULT_TINT_ALPHA) * opacity).coerceIn(0f, 1f),
    )
    val edgeLight = if (dark) Highlight.GlassStrokeSmallDark else Highlight.GlassStrokeSmallLight
    val shadow = remember(primary, opacity) {
        Shadow(
            radius = FAB_SHADOW_RADIUS_DP.dp,
            color = primary,
            alpha = FAB_SHADOW_ALPHA * opacity,
            offset = DpOffset(0.dp, FAB_SHADOW_OFFSET_Y_DP.dp),
        )
    }
    val density = LocalDensity.current
    val animationScope = rememberCoroutineScope()
    val interactionSource = remember { MutableInteractionSource() }
    val interactiveHighlight = remember(animationScope) {
        InteractiveHighlight(animationScope = animationScope)
    }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(FAB_ENTER_MS, easing = FastOutSlowInEasing)) +
            scaleIn(
                initialScale = FAB_APPEAR_SCALE,
                animationSpec = tween(FAB_ENTER_MS, easing = FastOutSlowInEasing),
                transformOrigin = TransformOrigin(0.5f, 1f),
            ),
        exit = fadeOut(tween(FAB_EXIT_MS)) +
            scaleOut(
                targetScale = FAB_APPEAR_SCALE,
                animationSpec = tween(FAB_EXIT_MS),
                transformOrigin = TransformOrigin(0.5f, 1f),
            ),
        modifier = modifier,
    ) {
        Box(
            modifier = Modifier.graphicsLayer {
                // 阴影与玻璃一起跟手；画到布局边界之外也不裁。
                clip = false
                val side = size.minDimension.toFloat().coerceAtLeast(1f)
                translationX = side * tanh(FAB_DRAG_FOLLOW * interactiveHighlight.offset.x / side)
                translationY = side * tanh(FAB_DRAG_FOLLOW * interactiveHighlight.offset.y / side)
            },
        ) {
            Row(
                modifier = Modifier
                    // 命中区下限 48dp；左右内边距留出「单字居中、胶囊不显扁」的呼吸。
                    .heightIn(min = BACK_TO_TODAY_FAB_MIN_HEIGHT_DP.dp)
                    .dropShadow(shape, shadow)
                    .semantics { this.contentDescription = contentDescription }
                    .clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        role = Role.Button,
                        onClick = onClick,
                    )
                    .then(
                        if (glassActive && backdrop != null) {
                            Modifier.drawBackdrop(
                                backdrop = backdrop,
                                shape = { shape },
                                effects = {
                                    // 窄件几何：带 / 位移都按矮边钳住，否则上下两条折射带
                                    // 会连成一整圈轮廓（与 Dart `narrowSurfaceMaxRefraction`
                                    // 同一口径：短边 × 0.28，钳在 8..14dp）。
                                    val maxRefractionDp = (BACK_TO_TODAY_FAB_MIN_HEIGHT_DP *
                                        FAB_NARROW_REFRACTION_RATIO)
                                        .coerceIn(
                                            FAB_NARROW_REFRACTION_MIN_DP,
                                            FAB_NARROW_REFRACTION_MAX_DP,
                                        )
                                    val bandPx = if (liquid) {
                                        with(density) {
                                            minOf(
                                                material?.liquidRefractionBand ?: 0f,
                                                maxRefractionDp,
                                            ).dp.toPx()
                                        }
                                    } else {
                                        0f
                                    }
                                    val amountPx = if (liquid) {
                                        with(density) {
                                            minOf(
                                                material?.liquidRefraction ?: 0f,
                                                maxRefractionDp,
                                            ).dp.toPx()
                                        }
                                    } else {
                                        0f
                                    }
                                    // 折射朝形状外采样：采样层先按位移撑起来。
                                    // ⚠️ 必须在 blur() 读 padding 之前抬。
                                    if (amountPx > 0f) {
                                        padding = maxOf(padding, amountPx)
                                    }
                                    vibrancy()
                                    val sigmaPx = with(density) {
                                        (material?.liquidBlurSigma ?: 0f).dp.toPx()
                                    }
                                    if (sigmaPx > 0f) blur(sigmaPx)
                                    if (bandPx > 0f && amountPx > 0f) {
                                        lens(
                                            refractionHeight = bandPx,
                                            refractionAmount = amountPx,
                                            chromaticAberration = material?.liquidDispersion ?: 0f,
                                        )
                                    }
                                },
                                highlight = { edgeLight },
                                layerBlock = {
                                    val height = size.height.toFloat().coerceAtLeast(1f)
                                    val width = size.width.toFloat().coerceAtLeast(1f)
                                    val press = interactiveHighlight.pressProgress
                                    val baseScale = 1f +
                                        with(density) { FAB_PRESS_GROW_DP.dp.toPx() } / height * press
                                    // 按拖动方向把胶囊拉长一点：横拖压扁高度、竖拖压窄宽度，
                                    // 读起来像一块被手指挤动的玻璃，而不是整体平移。
                                    val offset = interactiveHighlight.offset
                                    val maxStretch = with(density) { 1.dp.toPx() } / height
                                    val angle = atan2(offset.y, offset.x)
                                    scaleX = baseScale +
                                        maxStretch * abs(cos(angle) * offset.x / size.maxDimension) *
                                        (width / height).coerceAtMost(1f)
                                    scaleY = baseScale +
                                        maxStretch * abs(sin(angle) * offset.y / size.maxDimension) *
                                        (height / width).coerceAtMost(1f)
                                },
                                onDrawSurface = { drawRect(tint) },
                            )
                        } else {
                            Modifier.background(solidColor, shape)
                        },
                    )
                    .then(interactiveHighlight.modifier)
                    .then(interactiveHighlight.gestureModifier)
                    .padding(
                        horizontal = BACK_TO_TODAY_FAB_HORIZONTAL_PADDING_DP.dp,
                        vertical = BACK_TO_TODAY_FAB_VERTICAL_PADDING_DP.dp,
                    ),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = label,
                    style = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = MiuixTheme.colorScheme.onPrimary.copy(alpha = opacity),
                )
            }
        }
    }
}

/** 视觉高度下限（dp）；胶囊会随字号撑高，但不会低于 48dp 的命中下限。 */
const val BACK_TO_TODAY_FAB_MIN_HEIGHT_DP = 48f

/** 文字左右呼吸（dp）：单字居中后胶囊仍有足够的横向体量。 */
const val BACK_TO_TODAY_FAB_HORIZONTAL_PADDING_DP = 30f

/** 文字上下呼吸（dp）。 */
const val BACK_TO_TODAY_FAB_VERTICAL_PADDING_DP = 8f

/** 材质快照没给染色强度时的兜底（与 `HomeMaterialRenderSpec.liquidTintAlpha` 默认同值）。 */
private const val FAB_DEFAULT_TINT_ALPHA = 0.70f

/** 出入场的起止缩放：从底边中心长出来，而不是凭空出现。 */
private const val FAB_APPEAR_SCALE = 0.6f

private const val FAB_ENTER_MS = 320
private const val FAB_EXIT_MS = 200

/** 按下时高度方向的放大量（dp）；换算成比例后与钮高无关。 */
private const val FAB_PRESS_GROW_DP = 4f

/** 跟手位移的初始斜率（约手指位移的 8%，与底栏顶栏按钮同一手感）。 */
private const val FAB_DRAG_FOLLOW = 0.08f

/** 投影：主色、40%、10dp 模糊、下移 4dp。 */
private const val FAB_SHADOW_RADIUS_DP = 10f
private const val FAB_SHADOW_OFFSET_Y_DP = 4f
private const val FAB_SHADOW_ALPHA = 0.4f

/** 窄件折射：短边 × 0.28，钳在 8..14dp（Dart `narrowSurfaceMaxRefraction` 同口径）。 */
private const val FAB_NARROW_REFRACTION_RATIO = 0.28f
private const val FAB_NARROW_REFRACTION_MIN_DP = 8f
private const val FAB_NARROW_REFRACTION_MAX_DP = 14f
