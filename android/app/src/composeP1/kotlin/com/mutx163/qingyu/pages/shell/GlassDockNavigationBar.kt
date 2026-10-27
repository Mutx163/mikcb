package com.mutx163.qingyu.pages.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.squircle.squircleBackground
import top.yukonga.miuix.kmp.theme.MiuixTheme

/** 底栏的一个条目。 */
data class GlassDockItem(
    val icon: ImageVector,
    val label: String?,
    val contentDescription: String? = null,
)

/**
 * **底部玻璃导航栏**（药丸形态，miuix `GlassNavigationBar` 的语义）。
 *
 * ## 为什么本仓要自己装配这一个组件
 *
 * miuix 0.9.4 的 Kotlin 侧没有玻璃导航栏：`NavigationBar` / `FloatingNavigationBar`
 * 都是**纯色**（`squircleBackground(color = colorScheme.surface)`），
 * `GlassNavigationBar` 只存在于 Flutter 移植（`flutter_miuix` 1.2.0）。
 *
 * 所以这里做的是「用官方玻璃引擎装配导航栏」，**不是**重写材质：
 * 抓下层 [Backdrop]、`blur()`、边缘扫光 [Highlight] 全部来自 `miuix-blur`；
 * 几何与动效数值全部来自 [GlassDockGeometry]（20 例单测钉住，含三次咬合探针）。
 *
 * ## 交互刻意不照 Material 走
 *
 * 用户对旧底栏的原话是「点击效果也不对」。旧实现是 Material 涟漪 + 松手才变色，
 * 中间没有任何反馈。这里换成 miuix 那套：
 *
 * 1. **没有 ripple**：涟漪在圆角药丸上会糊成一整块灰；
 * 2. 按下立刻把内容压到 [GlassDockGeometry.PressedContentAlpha]，松手弹回；
 * 3. 选中项的指示器是一颗**自己滑过去**的药丸（左右边界两条不同刚度的弹簧，
 *    所以是「先伸出、再收拢」，不是整块平移）；
 * 4. 手指按住横向划动时指示器跟着走（[GlassDockGeometry.dragTarget] 的粘连拉伸），
 *    换格那一刻才落位。
 *
 * ## 降级
 *
 * [backdrop] 为空时只画半透明实底，**不调** `blur()` —— 没有采样源却去模糊，
 * 拿到的是「模糊了空气」，看起来像一块脏灰。
 *
 * @param items 条目（2~5 个）。
 * @param selectedIndex 当前选中，越界会被钳住。
 * @param onSelect 点选回调；**点当前项也会回调**，是否忽略由调用方决定。
 * @param backdrop 背景采样源（宿主用 `Modifier.layerBackdrop` 提供）。
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
    val dark = MiuixTheme.colorScheme.background.luminance() < 0.5f
    val neutral = if (dark) Color.White else Color.Black
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()

    var barWidth by remember { mutableStateOf(0f) }
    var pressedIndex by remember { mutableIntStateOf(-1) }
    var positioned by remember { mutableStateOf(false) }

    val indicatorLeft = remember { Animatable(0f) }
    val indicatorRight = remember { Animatable(0f) }

    // 两个弹簧刚度不同才是 miuix 的手感：左边界跟手快（响应 0.15s），
    // 右边界慢（0.4s），于是换格时看起来像「先伸长、再收拢」，而不是整块平移。
    val leftSpring = spring<Float>(
        dampingRatio = GlassDockGeometry.DragSpringDamping,
        stiffness = GlassDockGeometry.springStiffness(GlassDockGeometry.DragSpringResponse),
    )
    val rightSpring = spring<Float>(
        dampingRatio = GlassDockGeometry.IndicatorSpringDamping,
        stiffness = GlassDockGeometry.springStiffness(GlassDockGeometry.IndicatorSpringResponse),
    )

    // 指示器落位。⚠️ 依赖里必须有 barWidth：宽度是首帧布局后才量到的，
    // 那时 selectedIndex 没变、宽度还是 0，只等 index 会让指示器永久停在 0
    // ——「选中项高亮偏在左边」正是这么来的。
    LaunchedEffect(items.size, safeIndex, barWidth) {
        if (barWidth <= 0f) return@LaunchedEffect
        val span = GlassDockGeometry.indicatorSpanFor(safeIndex, barWidth, items.size)
        if (!positioned) {
            indicatorLeft.snapTo(span.left)
            indicatorRight.snapTo(span.right)
            positioned = true
        } else {
            indicatorLeft.animateTo(span.left, leftSpring)
            indicatorRight.animateTo(span.right, rightSpring)
        }
    }

    /** 拖拽跟手：把当前指针位置对应的拉伸区间直接砸到指示器上（不走弹簧）。 */
    suspend fun followPointer(pointerX: Float, index: Int) {
        if (barWidth <= 0f) return
        val width = GlassDockGeometry.slotWidth(barWidth, items.size) +
            GlassDockGeometry.IndicatorOverhangDp * 2f
        val span = GlassDockGeometry.indicatorSpanFor(index, barWidth, items.size)
        // delta 用「指针相对该格中心的偏移」表达：正 = 手在格子右边，指示器往右拉。
        val center = span.left + span.width / 2f
        val target = GlassDockGeometry.dragTarget(
            left = span.left,
            width = width,
            containerWidth = barWidth,
            delta = pointerX - center,
            changedItem = false,
        )
        indicatorLeft.snapTo(target.left)
        indicatorRight.snapTo(target.right)
    }

    val pressed = pressedIndex >= 0
    val indicatorColor = if (pressed) {
        neutral.copy(alpha = if (dark) 0.26f else 0.16f)
    } else {
        neutral.copy(alpha = if (dark) 0.12f else 0.06f)
    }

    Box(modifier = modifier.fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
        Box(
            modifier = Modifier
                .widthIn(max = maxWidthDp.dp)
                .fillMaxWidth()
                .padding(horizontal = 12.dp)
                .navigationBarsPadding()
                .padding(bottom = 10.dp)
                .height(GlassDockGeometry.HeightDp.dp)
                .glassDockSurface(backdrop = backdrop, dark = dark)
                .onSizeChanged { barWidth = it.width.toFloat() }
                .pointerInput(items.size, barWidth) {
                    var dragIndex = safeIndex
                    detectHorizontalDragGestures(
                        onDragStart = { offset ->
                            dragIndex = GlassDockGeometry.itemAt(
                                x = offset.x,
                                containerWidth = barWidth,
                                itemCount = items.size,
                            )
                        },
                        onDragEnd = {
                            // 松手交还弹簧：LaunchedEffect 会把它吸到当前选中格。
                            positioned = true
                        },
                        onDragCancel = { positioned = true },
                        onHorizontalDrag = { change, _ ->
                            change.consume()
                            scope.launch { followPointer(change.position.x, dragIndex) }
                            val next = GlassDockGeometry.itemAt(
                                x = change.position.x,
                                containerWidth = barWidth,
                                itemCount = items.size,
                            )
                            if (next != dragIndex) {
                                dragIndex = next
                                onSelect(next)
                            }
                        },
                    )
                },
        ) {
            // 指示器：最底层。宽度 = 两个弹簧之差，位置用 offset ——
            // 每帧只挪坐标、不触发重新测量（42 格的教训，别在底栏重演）。
            Box(
                modifier = Modifier
                    .offset { IntOffset(indicatorLeft.value.roundToInt(), 0) }
                    .width(
                        with(density) {
                            (indicatorRight.value - indicatorLeft.value)
                                .coerceAtLeast(0f)
                                .toDp()
                        },
                    )
                    .height(
                        (GlassDockGeometry.HeightDp -
                            GlassDockGeometry.IndicatorPaddingVerticalDp * 2).dp,
                    )
                    .padding(vertical = GlassDockGeometry.IndicatorPaddingVerticalDp.dp)
                    .clip(CircleShape)
                    .squircleBackground(
                        color = indicatorColor,
                        cornerRadius = (GlassDockGeometry.HeightDp / 2).dp,
                    ),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                for (index in items.indices) {
                    Box(modifier = Modifier.weight(1f)) {
                        GlassDockTab(
                            item = items[index],
                            selected = index == safeIndex,
                            onPressChanged = { isPressed ->
                                pressedIndex = if (isPressed) index else -1
                            },
                            onTap = { onSelect(index) },
                        )
                    }
                }
            }
        }
    }
}

/** 单个条目：图标 + 可选标签；按下压暗并按比例缩放，**没有涟漪**。 */
@Composable
private fun GlassDockTab(
    item: GlassDockItem,
    selected: Boolean,
    onPressChanged: (Boolean) -> Unit,
    onTap: () -> Unit,
) {
    var pressed by remember { mutableStateOf(false) }
    val tint = MiuixTheme.colorScheme.onBackground
    val alpha = if (pressed) GlassDockGeometry.PressedContentAlpha else 1f
    val scale = if (pressed) GlassDockGeometry.pressScale(GlassDockGeometry.HeightDp) else 1f
    val label = item.label
    val description = item.contentDescription

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .height(GlassDockGeometry.HeightDp.dp)
            .graphicsLayer {
                this.alpha = alpha
                scaleX = scale
                scaleY = scale
            }
            .pointerInput(Unit) {
                detectTapGestures(
                    onPress = {
                        pressed = true
                        onPressChanged(true)
                        tryAwaitRelease()
                        pressed = false
                        onPressChanged(false)
                    },
                    onTap = { onTap() },
                )
            }
            .semantics {
                this.selected = selected
                role = Role.Tab
                if (description != null) contentDescription = description
            }
            .padding(vertical = GlassDockGeometry.ContentVerticalPaddingDp.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = item.icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(GlassDockGeometry.IconSizeDp.dp),
        )
        if (label != null) {
            Spacer(Modifier.height(2.dp))
            Text(
                text = label,
                color = tint,
                maxLines = 2,
                textAlign = TextAlign.Center,
                overflow = TextOverflow.Ellipsis,
                fontSize = GlassDockGeometry.LabelSizeSp.sp,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            )
        }
    }
}

/**
 * 玻璃表面：官方 `miuix-blur` 引擎 + 圆角扫光。
 *
 * 参数只在这里出现一次 —— 壳、展示页、以后的独立坞都用它，各写一份必然漂。
 *
 * ⚠️ 必须 `@Composable`：`squircleBackground` 是 @Composable 的 Modifier 扩展
 * （它要在组合期读 `LocalSquircleEnabled`）。
 *
 * @param backdrop 为空时走半透明实底，不调 `blur()`。
 */
@Composable
private fun Modifier.glassDockSurface(backdrop: Backdrop?, dark: Boolean): Modifier {
    val radius = (GlassDockGeometry.HeightDp / 2).dp
    val base = clip(CircleShape).squircleBackground(
        color = if (dark) GlassDockFallback.DarkFill else GlassDockFallback.LightFill,
        cornerRadius = radius,
    )
    if (backdrop == null) return base
    val shape = CircleShape
    return base.drawBackdrop(
        backdrop = backdrop,
        shape = { shape },
        // `effects` 的 receiver 是 BackdropEffectScope（本身是 Density），
        // 所以 dp → px 在这里能直接算。
        effects = { blur(GlassDockFallback.blurRadiusDp.dp.toPx()) },
        highlight = {
            if (dark) Highlight.GlassStrokeMiddleDark else Highlight.GlassStrokeMiddleLight
        },
    )
}

/**
 * 无采样源时的降级外观（与 Flutter 侧 `familyFallsBackToSolid` 同一口径）。
 *
 * 数值不要另调：用户在两套界面之间看到同一块底栏深浅不一样，会以为是两个 App。
 */
private object GlassDockFallback {
    val LightFill = Color.White.copy(alpha = 0.72f)
    val DarkFill = Color(0xFF2A2A2A).copy(alpha = 0.72f)

    /** 与 miuix `puredThinGlass` 的 20dp 一致。 */
    const val blurRadiusDp = 20f
}
