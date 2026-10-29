package com.mutx163.qingyu.pages.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.EaseOut
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.liquid.DampedDragAnimation
import com.mutx163.qingyu.components.liquid.InnerShadow
import com.mutx163.qingyu.components.liquid.InteractiveHighlight
import com.mutx163.qingyu.components.liquid.innerShadow
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.rememberCombinedBackdrop
import com.mutx163.qingyu.components.liquid.vibrancy
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sign
import kotlin.math.sin
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.highlight.BloomStroke
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.blur.highlight.LightPosition
import top.yukonga.miuix.kmp.blur.highlight.LightSource
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.blur.sensor.rememberDeviceTilt
import top.yukonga.miuix.kmp.theme.LocalContentColor
import top.yukonga.miuix.kmp.theme.MiuixTheme

/** 底栏的一个条目。 */
data class GlassDockItem(
    val icon: ImageVector,
    val label: String?,
    val contentDescription: String? = null,
)

/**
 * **液态玻璃底部导航栏**——四层结构，照官方 demo 的
 * `component/liquid/LiquidGlassNavigationBar.kt` 装配。
 *
 * ## 四层各干什么（缺一层就不是液态玻璃）
 *
 * | 层 | 手段 | 少了它会发生什么 |
 * |---|---|---|
 * | ① 外壳胶囊 | `drawBackdrop` + `vibrancy` + `blur(4dp)` + `lens(24dp)` + 扫光 + 按压放大 | 退回「半透明 + 模糊」= 一块蒙雾的塑料片 |
 * | ② 图标折射副本 | 同一份内容 `alpha(0)` 再画一遍，录进 `tabsBackdrop` | 图标是"贴"在玻璃上的，不跟着玻璃一起弯 —— 一眼假 |
 * | ③ 滑动指示器 | `combinedBackdrop` + `lens(色散 0.5)` + `innerShadow` + 速度形变 | 选中态只是一块纯色圆角，没有玻璃厚度与彩虹边 |
 * | ④ 无采样源降级 | 半透明实底，**不调** `blur()` | 没背景却去模糊 = 模糊空气，得到一块脏灰 |
 *
 * ## 数值来源（不许在别处另写一份）
 *
 * 几何与动效数值全部来自 [GlassDockGeometry]（26 例单测钉住，含咬合探针）；
 * 材质与着色器来自 `miuix-blur` 官方引擎；`lens` / `vibrancy` / `innerShadow` /
 * `CombinedBackdrop` / `DampedDragAnimation` / `InteractiveHighlight` 六个件
 * **miuix 0.9.4 发布物里没有**，按 Apache-2.0 从官方 demo 整段搬进
 * `components/liquid/`（见各文件头部说明）。
 *
 * ## 与 miuix `GlassNavigationBarDefaults` 的一处**有意分歧**
 *
 * 按下时**内容缩小、指示器放大**（[GlassDockGeometry.IndicatorPressGrowScale] > 1）。
 * miuix 的 Android 版只有"内容压暗"，没有指示器放大；demo 的 iOS 版有。
 * 这里取 demo 版：用户要的是"液态玻璃"，而那正是 iOS 那套的手感。
 *
 * @param items 条目（2~5 个）。
 * @param selectedIndex 当前选中，越界会被钳住。
 * @param onSelect 点选回调；**点当前项也会回调**，是否忽略由调用方决定。
 * @param backdrop 背景采样源（宿主用 `Modifier.layerBackdrop` 提供）。
 *   为空时走第 ④ 层降级。
 */
@Composable
fun GlassDockNavigationBar(
    items: List<GlassDockItem>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    backdrop: Backdrop? = null,
    modifier: Modifier = Modifier,
    maxWidthDp: Int = 380,
) {
    if (items.isEmpty()) return
    val safeIndex = selectedIndex.coerceIn(0, items.lastIndex)
    val colors = MiuixTheme.colorScheme
    val accentColor = colors.primary
    val tabContentColor = colors.onBackground
    val surfaceContainer = colors.surfaceContainer
    val isDark = surfaceContainer.luminanceIsDark()

    // 只有「有采样源 + 设备支持 runtime shader」才走液态档。
    // 少判 isRuntimeShaderSupported 会在低版本机上得到黑块而不是"没效果"。
    val isBlurActive = backdrop != null && isRuntimeShaderSupported()
    val containerColor =
        if (isBlurActive) surfaceContainer.copy(alpha = 0.4f) else surfaceContainer

    val pillShape = remember { CircleShape }
    val density = LocalDensity.current
    val isLtr = LocalLayoutDirection.current == LayoutDirection.Ltr
    val animationScope = rememberCoroutineScope()
    val tabsCount = items.size

    // ② 层的录像带：把"图标+文字"录下来，供 ③ 层连同背景一起采样。
    val tabsBackdrop = rememberLayerBackdrop()
    val combinedBackdrop = backdrop?.let { rememberCombinedBackdrop(it, tabsBackdrop) }

    var totalWidthPx by remember { mutableFloatStateOf(0f) }
    var tabWidthPx by remember { mutableFloatStateOf(0f) }

    // 拖拽越界时的橡皮筋位移：手指拖出栏外，整块玻璃跟着偏一点（最多 4dp）再弹回。
    val offsetAnimation = remember { Animatable(0f) }
    val rubberBandPx = with(density) { 4.dp.toPx() }
    val panelOffset by remember(rubberBandPx) {
        derivedStateOf {
            if (totalWidthPx == 0f) {
                0f
            } else {
                val fraction = (offsetAnimation.value / totalWidthPx).coerceIn(-1f, 1f)
                rubberBandPx * fraction.sign * EaseOut.transform(abs(fraction))
            }
        }
    }

    var currentIndex by remember { mutableIntStateOf(safeIndex) }
    val onSelectUpdated by rememberUpdatedState(onSelect)

    /** 屏幕 x → 条目下标。与内容区那个 `4dp` 内边距同源。 */
    fun indexAt(positionX: Float): Int {
        if (tabWidthPx == 0f) return currentIndex
        val horizontalPaddingPx = with(density) {
            GlassDockGeometry.GlassContentPaddingDp.dp.toPx()
        }
        val logicalX = if (isLtr) positionX else totalWidthPx - positionX
        return ((logicalX - horizontalPaddingPx) / tabWidthPx)
            .toInt()
            .coerceIn(0, tabsCount - 1)
    }

    // 五通道弹簧：位置 / 速度 / 按压进度 / X 缩放 / Y 缩放。
    // 这是「手感」的全部来源，别用单个 animateFloatAsState 替代。
    val dampedDrag = remember(animationScope, tabsCount, density, isLtr) {
        DampedDragAnimation(
            animationScope = animationScope,
            initialValue = safeIndex.toFloat(),
            valueRange = 0f..(tabsCount - 1).toFloat(),
            visibilityThreshold = 0.001f,
            initialScale = 1f,
            // >1：指示器按下时**放大**（见类注释里那处有意分歧）。
            pressedScale = GlassDockGeometry.IndicatorPressGrowScale,
            canDrag = { position -> position.x in 0f..totalWidthPx },
            onDragStarted = { position ->
                updateValue(indexAt(position.x).toFloat())
            },
            onDragStopped = {
                val targetIndex = targetValue.roundToInt().coerceIn(0, tabsCount - 1)
                if (currentIndex != targetIndex) {
                    currentIndex = targetIndex
                    onSelectUpdated(targetIndex)
                }
                updateValue(targetIndex.toFloat())
                animationScope.launch {
                    offsetAnimation.animateTo(0f, spring(1f, 300f, 0.5f))
                }
            },
            onDragCancelled = {
                updateValue(currentIndex.toFloat())
                animationScope.launch {
                    offsetAnimation.animateTo(0f, spring(1f, 300f, 0.5f))
                }
            },
            onDrag = { _, dragAmount ->
                if (tabWidthPx > 0f && dragAmount.x != 0f) {
                    updateValue(
                        (targetValue + dragAmount.x / tabWidthPx * if (isLtr) 1f else -1f)
                            .coerceIn(0f, (tabsCount - 1).toFloat()),
                    )
                    animationScope.launch {
                        offsetAnimation.snapTo(offsetAnimation.value + dragAmount.x)
                    }
                }
            },
        )
    }

    // 外部改选中（比如壳里点了别处）时同步过来并播动画。
    LaunchedEffect(safeIndex) {
        if (currentIndex != safeIndex) {
            currentIndex = safeIndex
            dampedDrag.animateToValue(safeIndex.toFloat())
        }
    }

    fun activateTab(index: Int) {
        if (currentIndex != index) {
            currentIndex = index
            onSelectUpdated(index)
        }
        dampedDrag.animateToValue(index.toFloat())
    }

    // 指尖光斑：位置跟着指示器中心走（不是跟手指，那样会脱开玻璃）。
    // 必须 keyed on dampedDrag —— 闭包捕获它，捕获旧值会让光斑卡住不动。
    val interactiveHighlight = remember(animationScope, isLtr, dampedDrag) {
        InteractiveHighlight(
            animationScope = animationScope,
            position = { layerSize, _ ->
                Offset(
                    x = if (isLtr) {
                        (dampedDrag.value + 0.5f) * tabWidthPx + panelOffset
                    } else {
                        layerSize.width - (dampedDrag.value + 0.5f) * tabWidthPx + panelOffset
                    },
                    y = layerSize.height / 2f,
                )
            },
        )
    }

    // 扫光跟随重力方向（"倾灯"）：手机倾向哪边，玻璃边缘的高光就在哪边。
    // 只在绘制期读 .value，避免传感器 50Hz 写入触发整棵树重组。
    //
    // ⚠️ 重力角只算**一次**并复用：`rememberQuantizedGravityAngle()` 内部会调
    // `rememberDeviceTilt()`，也就是注册一个 SENSOR_DELAY_GAME 监听。两个高光各调一次
    // = 两份监听 + 两遍平滑 + 每帧两个新 DeviceTilt（2026-10-29 审计第 6 条）。
    val gravityAngle = rememberQuantizedGravityAngle()
    val baseHighlight = rememberGravityRotatedHighlight(
        base = GlassDockSpecular,
        extraDegrees = -45f,
        gravityAngle = gravityAngle,
    )
    val pillHighlight = rememberGravityRotatedHighlight(
        base = GlassDockSpecular,
        extraDegrees = 90f,
        gravityAngle = gravityAngle,
    )

    val navBarBottomPadding = WindowInsets.navigationBars
        .only(WindowInsetsSides.Bottom)
        .asPaddingValues()
        .calculateBottomPadding()

    // 标签字阶：正常档走 footnote2（11sp，与 `GlassDockGeometry.LabelSizeSp` 同值），
    // 系统字体放大到阈值以上时换 body1（16sp，与 `LargeLabelSizeSp` 同值）。
    // 走 textStyles 而不是裸 fontSize —— 字族与用户字重才能跟着主题走。
    val labelStyle = labelTextStyle()

    /** 条目内容。**被复用三次**：外壳、② 折射副本、③ 指示器副本。 */
    val tabsContent: @Composable RowScope.() -> Unit = {
        items.forEachIndexed { index, item ->
            Column(
                modifier = Modifier
                    .semantics(mergeDescendants = true) {
                        selected = index == currentIndex
                        role = Role.Tab
                        // 只在**没有可见文字**时才回退到 contentDescription：
                        // mergeDescendants 会把子 Text 合并进来，两样都给读屏就念两遍
                        // （"课表，课表"）。demo 一项都不设，只靠 Text 说话。
                        if (item.label == null) {
                            item.contentDescription?.let { contentDescription = it }
                        }
                        onClick {
                            activateTab(index)
                            true
                        }
                    }
                    .weight(1f)
                    .fillMaxHeight(),
                verticalArrangement = Arrangement.spacedBy(
                    GlassDockGeometry.IconLabelGapDp.dp,
                    Alignment.CenterVertically,
                ),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    modifier = Modifier.size(GlassDockGeometry.GlassIconSizeDp.dp),
                    imageVector = item.icon,
                    // 装饰性：相邻的文字已经说明了这一项是什么，
                    // 这里再给 contentDescription 会让读屏念两遍。
                    contentDescription = null,
                )
                val label = item.label
                if (label != null) {
                    Text(
                        text = label,
                        style = labelStyle,
                        fontWeight = if (index == currentIndex) {
                            FontWeight.SemiBold
                        } else {
                            FontWeight.Normal
                        },
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }

    Column(modifier = modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .padding(
                    bottom = if (navBarBottomPadding != 0.dp) {
                        8.dp + navBarBottomPadding
                    } else {
                        36.dp
                    },
                    start = 24.dp,
                    end = 24.dp,
                )
                .widthIn(max = maxWidthDp.dp)
                .fillMaxWidth(),
            contentAlignment = Alignment.CenterStart,
        ) {
            // ── ① 外壳胶囊 ──
            //
            // ⚠️ 这一层与 ③ 指示器在 demo 里是**同一个 Box 的直接子节点**，中间不再包
            // 一层 4dp 内边距；那 4dp 是 Row 自己 `.height().padding(4.dp)` 的内边距。
            // 这里曾经多包了一层：玻璃因此比 demo 窄 8dp、整体还右下各偏 4dp，而指示器
            // 仍按外层坐标摆放 —— 结果选中块在左端贴死玻璃边、右端却空出 4dp，两端不对称。
            CompositionLocalProvider(LocalContentColor provides tabContentColor) {
                Row(
                    modifier = Modifier
                        .selectableGroup()
                        .onSizeChanged { coords ->
                            totalWidthPx = coords.width.toFloat()
                            // 两侧各让出一个内边距。少减一侧（写成 `- 4`）每格就偏大
                            // 4/n dp，末格的右边界会正好压在玻璃边缘上（一点余量不留），
                            // 按下放大立刻从那儿顶出去。
                            tabWidthPx = GlassDockGeometry.glassSlotWidthPx(
                                containerWidthPx = totalWidthPx,
                                itemCount = tabsCount,
                                paddingPx = with(density) {
                                    GlassDockGeometry.GlassContentPaddingDp.dp.toPx()
                                },
                            )
                        }
                        .graphicsLayer { translationX = panelOffset }
                        .dropShadow(
                            shape = pillShape,
                            shadow = Shadow(
                                radius = 10.dp,
                                color = Color.Black,
                                // 亮色主题下更淡：深色阴影压在浅色页面上会显出一圈灰边。
                                alpha = if (isDark) 0.2f else 0.1f,
                            ),
                        )
                        .then(
                            if (isBlurActive && backdrop != null) {
                                Modifier.drawBackdrop(
                                    backdrop = backdrop,
                                    shape = { pillShape },
                                    effects = {
                                        // 采样层要够大：盖住折射带与按压放大伸出量。
                                        // ⚠️ 必须在 blur() 读它之前抬起来。
                                        padding = maxOf(
                                            padding,
                                            with(density) {
                                                GlassDockGeometry.SamplingPaddingReachDp.dp.toPx()
                                            },
                                        )
                                        vibrancy()
                                        blur(
                                            with(density) {
                                                GlassDockGeometry.GlassBlurRadiusDp.dp.toPx()
                                            },
                                        )
                                        lens(
                                            refractionHeight = with(density) {
                                                GlassDockGeometry.RefractionHeightDp.dp.toPx()
                                            },
                                            refractionAmount = with(density) {
                                                GlassDockGeometry.RefractionAmountDp.dp.toPx()
                                            },
                                        )
                                    },
                                    highlight = {
                                        baseHighlight.value.copy(alpha = 0.75f)
                                    },
                                    layerBlock = {
                                        // 按压时整块玻璃放大一点点：宽度是按比例算的，
                                        // 所以窄屏上不会把药丸撑出栏外。
                                        val width = size.width.coerceAtLeast(1f)
                                        val s = lerpFloat(
                                            1f,
                                            1f + with(density) { 16.dp.toPx() } / width,
                                            dampedDrag.pressProgress,
                                        )
                                        scaleX = s
                                        scaleY = s
                                    },
                                    onDrawSurface = { drawRect(containerColor) },
                                )
                            } else {
                                Modifier.background(containerColor, pillShape)
                            },
                        )
                        .then(
                            if (isBlurActive) {
                                interactiveHighlight.modifier
                                    .then(interactiveHighlight.gestureModifier)
                            } else {
                                Modifier
                            },
                        )
                        .then(dampedDrag.modifier)
                        .height(GlassDockGeometry.HeightDp.dp)
                        .padding(GlassDockGeometry.GlassContentPaddingDp.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    content = tabsContent,
                )
            }

            // ── ② 图标折射副本 ──
            //
            // 这份副本 `alpha(0f)` 看不见，唯一作用是把自己**录进 tabsBackdrop**：
            // ③ 层采样 combinedBackdrop（背景 + 这份副本）时，图标就跟着玻璃一起被
            // lens 折射了。没有它，图标是"贴"在玻璃上的一层贴纸，一眼假。
            if (isBlurActive && backdrop != null) {
                CompositionLocalProvider(LocalContentColor provides accentColor) {
                    Row(
                        modifier = Modifier
                            .clearAndSetSemantics {}
                            .alpha(0f)
                            .layerBackdrop(tabsBackdrop)
                            .graphicsLayer { translationX = panelOffset }
                            .drawBackdrop(
                                backdrop = backdrop,
                                shape = { pillShape },
                                effects = {
                                    // 与 ① 同一条纪律：采样层要在 blur() 读它之前抬起来。
                                    // 少了这一句，lens() 事后把 padding 抬到 24dp，会命中 miuix
                                    // `apply()` 里「blur 的 clamp 已过期 → 重跑整段 effects」那条分支
                                    // ⇒ 每次更新都白算两遍 blur + lens（2026-10-29 审计第 4 条）。
                                    padding = maxOf(
                                        padding,
                                        with(density) {
                                            GlassDockGeometry.SamplingPaddingReachDp.dp.toPx()
                                        },
                                    )
                                    vibrancy()
                                    blur(
                                        with(density) {
                                            GlassDockGeometry.GlassBlurRadiusDp.dp.toPx()
                                        },
                                    )
                                    lens(
                                        refractionHeight = with(density) {
                                            GlassDockGeometry.RefractionHeightDp.dp.toPx()
                                        },
                                        refractionAmount = with(density) {
                                            GlassDockGeometry.RefractionAmountDp.dp.toPx()
                                        },
                                    )
                                },
                                onDrawSurface = { drawRect(containerColor) },
                            )
                            .then(interactiveHighlight.modifier)
                            // 与真内容同高（药丸高减上下内边距，demo 是 64-8=56）：
                            // 用满高会让折射出来的图标比真图标错开 4dp，选中时看着"虚"。
                            .height(GlassDockGeometry.GlassInnerHeightDp.dp)
                            .padding(
                                horizontal = GlassDockGeometry.GlassContentPaddingDp.dp,
                            ),
                        verticalAlignment = Alignment.CenterVertically,
                        content = tabsContent,
                    )
                }
            }

            // ── ③ 滑动指示器 ──
            //
            // ⚠️ 这里**故意不裁切**，与 demo 一致：指示器按下放大（×1.39）、快速滑动
            // 甩尾拉伸时，这块玻璃会从药丸轮廓里探出去一点点 —— 那是"液态"该有的样子
            // （玻璃被挤出来）。2026-10-28 曾为了消掉"超出"加过一层
            // `matchParentSize() + clip(pillShape)`，用户随即指出「激活态玻璃被底栏框住
            // 了」：放大被切平、边光与折射也没了。所以那层已删。
            //
            // 静止时左右各留 4dp 只由**水平**两件事保证：下面这个
            // `.padding(horizontal = GlassContentPaddingDp)` 给出基址、`tabWidthPx`
            // 用 `(W - 2×padding)/n` 给出步进（`GlassDockGeometry.glassSlotWidthPx`）。
            // 与 [GlassDockGeometry.GlassInnerHeightDp] 无关 —— 那个是竖直方向。
            // 要再动这里，先看 demo 的同一段。
            if (tabWidthPx > 0f) {
                val tabWidthDp = with(density) { tabWidthPx.toDp() }
                Box(
                    modifier = Modifier
                        .padding(horizontal = GlassDockGeometry.GlassContentPaddingDp.dp)
                        .graphicsLayer {
                            val progressOffset = dampedDrag.value * tabWidthPx
                            translationX = if (isLtr) {
                                progressOffset + panelOffset
                            } else {
                                -progressOffset + panelOffset
                            }
                        }
                        .then(
                            if (isBlurActive && combinedBackdrop != null) {
                                Modifier.drawBackdrop(
                                    backdrop = combinedBackdrop,
                                    shape = { pillShape },
                                    effects = {
                                        val progress = dampedDrag.pressProgress
                                        lens(
                                            refractionHeight = with(density) {
                                                (GlassDockGeometry.IndicatorRefractionHeightDp *
                                                    progress).dp.toPx()
                                            },
                                            refractionAmount = with(density) {
                                                (GlassDockGeometry.IndicatorRefractionAmountDp *
                                                    progress).dp.toPx()
                                            },
                                            depthEffect = true,
                                            // 色散版本每像素要 7 次 `content.eval`，而它只在
                                            // 「按下那一下」看得见。常开等于静止时也在付 7 倍采样。
                                            // 切成 0 会走无配色的那条 shader（两条都按 key 缓存，
                                            // 来回切不产生编译），2026-10-29 审计第 3 条。
                                            chromaticAberration =
                                                if (dampedDrag.pressProgress > 0.01f) {
                                                    GlassDockGeometry.IndicatorDispersion
                                                } else {
                                                    0f
                                                },
                                        )
                                    },
                                    highlight = {
                                        pillHighlight.value.copy(
                                            alpha = dampedDrag.pressProgress,
                                        )
                                    },
                                    layerBlock = {
                                        scaleX = dampedDrag.scaleX
                                        scaleY = dampedDrag.scaleY
                                        // 甩尾：速度越快，横向越拉长、纵向越压扁。
                                        // 这是"玻璃被甩出去"的观感来源。
                                        val v = dampedDrag.velocity / 10f
                                        scaleX /= 1f - (v * 0.75f).coerceIn(-0.2f, 0.2f)
                                        scaleY *= 1f - (v * 0.25f).coerceIn(-0.2f, 0.2f)
                                    },
                                    onDrawSurface = {
                                        val progress = dampedDrag.pressProgress
                                        // 静止时一层淡底，按下时淡出换成更深的压痕。
                                        drawRect(
                                            color = if (!isDark) {
                                                Color.Black.copy(alpha = 0.1f)
                                            } else {
                                                Color.White.copy(alpha = 0.1f)
                                            },
                                            alpha = 1f - progress,
                                        )
                                        drawRect(Color.Black.copy(alpha = 0.03f * progress))
                                    },
                                )
                            } else {
                                // 降级：一块淡色圆角，没有折射与内阴影。
                                Modifier
                                    .clip(pillShape)
                                    .background(accentColor.copy(alpha = 0.15f), pillShape)
                            },
                        )
                        .innerShadow(shape = pillShape) {
                            if (!isBlurActive) return@innerShadow null
                            // 静止时 radius/alpha 都是 0，但返回非 null 依然会录一层离屏层、
                            // 做两次 clipPath draw。直接不返回是最省的（2026-10-29 审计第 5 条）。
                            if (dampedDrag.pressProgress <= 0.01f) return@innerShadow null
                            InnerShadow(
                                radius = GlassDockGeometry.IndicatorInnerShadowRadiusDp.dp *
                                    dampedDrag.pressProgress,
                                color = Color.Black.copy(alpha = 0.15f),
                                alpha = dampedDrag.pressProgress,
                            )
                        }
                        // 药丸高减上下内边距（demo 是 56 = 64-8）：与玻璃四周各留 4dp。
                        // 用满高的话指示器与玻璃上下边齐平，一放大就顶出边。
                        .height(GlassDockGeometry.GlassInnerHeightDp.dp)
                        .width(tabWidthDp),
                )
            }
        }
    }
}

/** 线性插值。Compose 的 `lerp` 在 `androidx.compose.ui.util` 里，这里省一个 import。 */
private fun lerpFloat(start: Float, stop: Float, fraction: Float): Float =
    start + (stop - start) * fraction

/**
 * 底栏标签的字阶。
 *
 * 正常档 = `footnote2`（11sp，与 `GlassDockGeometry.LabelSizeSp` 同值）；
 * 系统字体放大到 [GlassDockGeometry.LargeLabelScaleThreshold] 以上时 = `body1`
 * （16sp，与 `LargeLabelSizeSp` 同值）。
 *
 * 为什么走 `textStyles` 而不是裸 `fontSize`：裸字号会整体覆盖主题样式，
 * 把 `fontFamily` 与用户字重一起丢掉（全仓 655 处的同类问题见
 * `.agents/notes/implemented/feature/2026-10-27-compose-textstyles-injection.md`）。
 */
@Composable
private fun labelTextStyle(): TextStyle {
    val fontScale = LocalConfiguration.current.fontScale
    val styles = MiuixTheme.textStyles
    return if (fontScale >= GlassDockGeometry.LargeLabelScaleThreshold) {
        styles.body1
    } else {
        styles.footnote2
    }
}

/**
 * 玻璃边缘的扫光（specular）。
 *
 * 与 miuix 的 `Highlight.GlassStrokeMiddleLight` 不同：这里用 `dualPeak = true`
 * （两个 180° 对置的峰），所以**上下两条边同时**有高光，读起来更像一根玻璃棒
 * 而不是一块有厚度的板。这是 demo 为指示器单独调的预设。
 */
private val GlassDockSpecular: Highlight = Highlight(
    width = 1.dp,
    alpha = 1f,
    style = BloomStroke(
        color = Color.White.copy(alpha = 0.12f),
        innerBlurRadius = 2.0.dp,
        primaryLight = LightSource(
            position = LightPosition(0.5f, -0.3f, -0.05f),
            color = Color.White,
            intensity = 1f,
        ),
        secondaryLight = LightSource(
            position = LightPosition(0.5f, 0.8f, -0.5f),
            color = Color.White,
            intensity = 0.4f,
        ),
        dualPeak = true,
    ),
)

// 与 `HighlightStyle.kt` 的 LIGHT_REF 保持一致（那里是光源参考点）。
private const val LIGHT_REF_X = 0.5f
private const val LIGHT_REF_Y = 0.7f

/** 平面内重力方向的有效下限：`|g_xy| > 0.1`（约 6° 倾角）才认为有方向。 */
private const val GRAVITY_DIR_THRESHOLD_SQ = 0.01f

/** 重力方向量化步长 3°：更细的变化人眼看不出来，量化能省掉大量无效重绘。 */
private const val GRAVITY_ANGLE_STEP_RAD = (3.0 * PI / 180.0).toFloat()

/**
 * 屏幕平面内的重力方向角（弧度，量化到 3°）。
 *
 * 返回 [State] 是为了把读取推迟到**绘制期**：传感器以约 50Hz 写入，
 * 在组合期读会让整个调用作用域每帧重组。
 */
@Composable
private fun rememberQuantizedGravityAngle(): State<Float> {
    val tiltState = rememberDeviceTilt()
    return remember(tiltState) {
        derivedStateOf {
            val tilt = tiltState.value
            val gx = tilt.gravityX
            val gy = tilt.gravityY
            val gMagSq = gx * gx + gy * gy
            if (gMagSq > GRAVITY_DIR_THRESHOLD_SQ) {
                (atan2(gy, gx) / GRAVITY_ANGLE_STEP_RAD).roundToInt() * GRAVITY_ANGLE_STEP_RAD
            } else {
                // 接近平放时平面内方向不稳定，钉在 (0, -1)。
                (-PI / 2).toFloat()
            }
        }
    }
}

/**
 * 把 [base] 的 `dualPeak` 主光源转到重力方向 + [extraDegrees]。
 *
 * 只在绘制期读 `.value`（见 [rememberQuantizedGravityAngle]）；旋转后的副本会缓存，
 * 只有跨过量化步长时才重新分配。
 */
@Composable
private fun rememberGravityRotatedHighlight(
    base: Highlight,
    extraDegrees: Float,
    /** 由调用方算好一次后复用的重力角，见调用处注释。 */
    gravityAngle: State<Float>,
): State<Highlight> {
    return remember(gravityAngle, base, extraDegrees) {
        derivedStateOf {
            val baseStyle = base.style as BloomStroke
            val basePrimary = baseStyle.primaryLight
            val rad = gravityAngle.value + (extraDegrees * PI / 180.0).toFloat()
            base.copy(
                style = baseStyle.copy(
                    primaryLight = basePrimary.copy(
                        position = LightPosition(
                            x = LIGHT_REF_X + cos(rad),
                            y = LIGHT_REF_Y + sin(rad),
                            z = basePrimary.position.z,
                        ),
                    ),
                ),
            )
        }
    }
}

/** 判断一个颜色够不够暗（用来决定阴影与压痕的极性）。 */
private fun Color.luminanceIsDark(): Boolean {
    val r = red
    val g = green
    val b = blue
    // Rec.709 相对亮度；这里只需要一个阈值判断，不必走完整的 sRGB 线性化。
    return (0.2126f * r + 0.7152f * g + 0.0722f * b) < 0.5f
}
