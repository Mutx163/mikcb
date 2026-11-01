package com.mutx163.qingyu.pages.timetable

import androidx.activity.compose.BackHandler
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.vibrancy
import kotlin.math.roundToInt
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.DropdownImpl
import top.yukonga.miuix.kmp.basic.DropdownItem
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.highlight.BloomStroke
import top.yukonga.miuix.kmp.blur.highlight.Highlight
import top.yukonga.miuix.kmp.blur.highlight.LightPosition
import top.yukonga.miuix.kmp.blur.highlight.LightSource
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.MiuixPopupUtils
import top.yukonga.miuix.kmp.utils.SinkFeedback

/**
 * 首页右上「更多」按钮 + 它的**容器变换菜单**（按钮本部长成菜单面板）。
 *
 * ## 为什么要自研
 *
 * 这是登记在 `docs/reference/miuix-component-first-standard.md`「例外审批登记」
 * 的第三条：miuix 0.9.4 的弹层全部是「锚在触发控件旁边、尺寸由内容决定」的独立
 * 浮层（`overlay/` 只有四个件），没有「按钮本身长成面板」这种形态；唯一带
 * `Morph` 的是级联菜单内部「一级列表缩到 0.95 + 二级面板从**行**里长出」，
 * 跨的是「行 → 面板」而不是「按钮 → 面板」，且绑死在官方 `DropdownItem` 数据
 * 结构与官方定位器上，抽不出来给自绘容器用。
 *
 * **自研的只有容器这一层**：菜单行仍用官方 [DropdownImpl]（文字、图标格、
 * 内边距、对勾、子菜单箭头、选中态全部来自 miuix）。
 *
 * ## 几何
 *
 * 按钮与面板是**同一个节点**：宽度 40dp → 200dp、高度 40dp → 菜单内容自然高、
 * 圆角固定 24dp（40dp 宽时被形状自动钳成正圆，所以收起态不需要第二个形状）。
 * 数值全部来自 [HomeMenuMorphModel]（纯函数 + JVM 单测逐数钉住），本文件不重复
 * 推导任何插值。
 *
 * ## 玻璃材质
 *
 * 传了 [backdrop] 且设备支持 RuntimeShader 时，面板用 `miuix-blur` 采样背景画
 * 玻璃（vibrancy + 高斯 + 边缘折射），与顶栏玻璃带、底栏玻璃坞同一套；
 * 不满足条件就退回主题实色，不会出现"模糊空气"的脏灰块。
 *
 * ## 为什么浮层必须是**同一个窗口**
 *
 * `Backdrop` 是靠 `positionInWindow()` 换算采样区域的（`LayerBackdrop.drawBackdrop`
 * 里 `localPositionOf` / 窗口坐标兜底）。放进 `androidx.compose.ui.window.Popup`
 * 这类**独立窗口**里，两边坐标系不同，采到的就是错位的一小块。所以这里用 miuix
 * 自己的同窗口浮层宿主 `MiuixPopupUtils.PopupLayout`，位置由我们按锚点窗口坐标
 * 自己摆（`ListPopupLayout` 也是这么做的）。
 *
 * ## 二级（「添加」三选）
 *
 * 在同一面板内原地展开：点「添加」把它的三个子项插在它下面、容器高度跟着弹到
 * 新高度；再点一次收回。**不另起第二个浮层** —— 那会变成两块材质不同的面板
 * 叠在一起，与「一张面板在变形」的观感打架。
 *
 * @param items 菜单条目（含二级子项），顺序即屏上顺序。
 * @param contentDescription 触发按钮的无障碍名。
 * @param onSelect 点中一个**叶子**条目时回传它的 id；本组件不认识路由。
 * @param backdrop 背景采样源（页面的 `rememberLayerBackdrop()`）；null = 画实色。
 */
@Composable
fun HomeMenuMorphButton(
    items: List<TimetableMenuItem>,
    contentDescription: String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
    backdrop: Backdrop? = null,
) {
    var open by remember { mutableStateOf(false) }
    var expandedSubmenuId by remember { mutableStateOf<String?>(null) }
    val reveal = remember { Animatable(0f) }
    // miuix 浮层宿主用 MutableState 控制显隐；它与 `open` 的差别只在「退场这段」：
    // 收起动画跑完才把它置 false，浮层才会跟着卸载。
    val popupVisible = remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    // 触发按钮在**窗口**里的位置；浮层靠它把自己摆到按钮的右上角。
    var anchorBounds by remember { mutableStateOf(Rect.Zero) }
    // 浮层宿主自己相对窗口的原点（Scaffold 可能不在窗口左上角）。
    var hostOrigin by remember { mutableStateOf(Offset.Zero) }

    /** 展开：容器用中等刚度弹簧长出去（过冲一点点，读起来"弹一下"）。 */
    fun openMenu() {
        if (open) return
        expandedSubmenuId = null
        open = true
        popupVisible.value = true
        scope.launch {
            // 上一次「选中后立即收起」可能把进度留在 1（那条协程会随页面切走被
            // 取消），所以每次展开都先从 0 起步，不能假设它还是 0。
            reveal.snapTo(0f)
            reveal.animateTo(
                targetValue = 1f,
                animationSpec = spring(
                    dampingRatio = 0.77f,
                    stiffness = 220f,
                    visibilityThreshold = 0.0001f,
                ),
            )
        }
    }

    /** 收起（点窗外 / 返回键）：先缩回按钮、动画跑完才卸载浮层，否则会看到面板原地消失。 */
    fun closeMenu() {
        if (!open) return
        scope.launch {
            reveal.animateTo(
                targetValue = 0f,
                animationSpec = spring(
                    dampingRatio = 0.85f,
                    stiffness = 650f,
                    visibilityThreshold = 0.0001f,
                ),
            )
            open = false
            expandedSubmenuId = null
            popupVisible.value = false
        }
    }

    /**
     * 选中一项：**立即**收起并执行，不播退场。
     *
     * 浮层收起来的那半截会盖在新页面上，选中即走比"收得漂亮"重要。
     */
    fun selectAndClose(id: String) {
        open = false
        expandedSubmenuId = null
        popupVisible.value = false
        scope.launch { reveal.snapTo(0f) }
        onSelect(id)
    }

    BackHandler(enabled = open) { closeMenu() }

    val density = LocalDensity.current
    val progress = reveal.value
    val panelWidthDp = HomeMenuMorphModel.widthDp(progress).dp
    val panelWidthPx = with(density) { panelWidthDp.toPx() }

    Box(
        modifier = modifier.onGloballyPositioned { anchorBounds = it.boundsInWindow() },
    ) {
        HomeMenuTriggerButton(
            contentDescription = contentDescription,
            onClick = { openMenu() },
        )

        MiuixPopupUtils.PopupLayout(
            visible = popupVisible,
            enableWindowDim = false,
            enableBackHandler = false,
            enterTransition = EnterTransition.None,
            exitTransition = ExitTransition.None,
            // 跟着当前 Scaffold 走（首页就在壳的 Scaffold 里），不弹到最外层。
            renderInRootScaffold = false,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .onGloballyPositioned { hostOrigin = it.positionInWindow() },
            ) {
                // 点面板之外的任何地方都收起。铺满全屏放在面板下面，面板自己在上。
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                            onClick = { closeMenu() },
                        ),
                )

                HomeMenuMorphPanel(
                    reveal = reveal,
                    items = items,
                    expandedSubmenuId = expandedSubmenuId,
                    backdrop = backdrop,
                    onToggleSubmenu = { id ->
                        expandedSubmenuId = if (expandedSubmenuId == id) null else id
                    },
                    onSelect = { id -> selectAndClose(id) },
                    modifier = Modifier.offset {
                        IntOffset(
                            // 面板右缘钉住按钮右缘、上缘钉住按钮上缘：向左向下长出去。
                            x = (anchorBounds.right - hostOrigin.x - panelWidthPx).roundToInt(),
                            y = (anchorBounds.top - hostOrigin.y).roundToInt(),
                        )
                    },
                )
            }
        }
    }
}

/**
 * 顶栏「更多」那颗圆形按钮。
 *
 * 两档菜单形态共用同一个样子，缺一不可：
 * * 列表档（容器变换）的**收起态就是这颗按钮** —— 面板在进度 0 时尺寸等于它，
 *   所以变形起止两帧严丝合缝，不能两边各画一份、颜色或圆角差一点就会跳；
 * * 八宫格档只借它当触发器（点开的是 `QingyuSheet` 底部弹层）。
 *
 * 底色走 `surfaceContainer`（与面板、与官方菜单行同色），图标走
 * `onSurfaceContainer`。按压反馈用官方 `SinkFeedback`（= `PressFeedbackType.Sink`
 * 的底层，下沉 0.94 + 弹簧）—— 官方 `IconButton` 不开放 `indication`，拿不到这档缩放。
 */
@Composable
fun HomeMenuTriggerButton(
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressFeedback = remember { SinkFeedback() }
    Box(
        modifier = modifier
            .size(HomeMenuMorphModel.TRIGGER_DIAMETER_DP.dp)
            .clip(RoundedCornerShape(HomeMenuMorphModel.PANEL_CORNER_RADIUS_DP.dp))
            .background(MiuixTheme.colorScheme.surfaceContainer)
            .clickable(
                interactionSource = interaction,
                indication = pressFeedback,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = MiuixIcons.More,
            contentDescription = contentDescription,
            tint = MiuixTheme.colorScheme.onSurfaceContainer,
            modifier = Modifier.size(TimetableTopBarMetrics.ICON.dp),
        )
    }
}

/**
 * 正在变形的面板本体。
 *
 * 内容列**始终按面板满宽排版**（`requiredWidth` + 不限高测量），再整体按
 * `当前宽 / 面板宽` 缩下去 —— 这样文字不会在变形过程中反复重排，只是被等比缩放；
 * 缩放中心固定在右上角，与容器右缘对齐。
 */
@Composable
private fun HomeMenuMorphPanel(
    reveal: Animatable<Float, AnimationVector1D>,
    items: List<TimetableMenuItem>,
    expandedSubmenuId: String?,
    backdrop: Backdrop?,
    onToggleSubmenu: (String) -> Unit,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val triggerPx = with(density) { HomeMenuMorphModel.TRIGGER_DIAMETER_DP.dp.toPx() }
    val panelWidthDp = HomeMenuMorphModel.PANEL_WIDTH_DP.dp

    // 内容自然高度：只由内容决定（不限高测量），不跟面板当前高度互相追 —— 否则
    // 高度动画会自己喂自己，收敛不了。
    var contentHeightPx by remember { mutableIntStateOf(0) }
    val animatedContentHeight = remember { Animatable(0f) }
    LaunchedEffect(contentHeightPx) {
        if (contentHeightPx > 0) {
            // 第一次量到就**直接落位**，不能从 0 动画过去 —— 那会让面板高度在
            // 打开的头几帧从 0 长起来，观感是"先压扁再撑开"。
            if (animatedContentHeight.value <= 0f) {
                animatedContentHeight.snapTo(contentHeightPx.toFloat())
            } else {
                animatedContentHeight.animateTo(
                    targetValue = contentHeightPx.toFloat(),
                    animationSpec = spring(dampingRatio = 0.9f, stiffness = 480f),
                )
            }
        }
    }
    // 首帧内容还没量过（`contentHeightPx == 0`）时退回按钮直径，绝不能让高度
    // 插值到 0 —— 那会在打开的第一帧把面板压扁一下。
    val targetContentPx = when {
        animatedContentHeight.value > 0f -> animatedContentHeight.value
        contentHeightPx > 0 -> contentHeightPx.toFloat()
        else -> triggerPx
    }

    val rows = remember(items, expandedSubmenuId) {
        homeMenuMorphRows(items, expandedSubmenuId)
    }

    // ⚠️ 这里在组合期读 `reveal.value`：宽度/高度是布局量，只能在这里读；变化范围
    // 只有本面板这棵子树（行表已 `remember` 住），不会波及顶栏其它内容。
    val progress = reveal.value
    val widthDp = HomeMenuMorphModel.widthDp(progress).dp
    val heightPx = HomeMenuMorphModel.heightPx(progress, triggerPx, targetContentPx)
    val contentScale = HomeMenuMorphModel.contentScale(with(density) { widthDp.toPx() })
    val contentAlpha = HomeMenuMorphModel.contentAlpha(progress)
    val shape = RoundedCornerShape(HomeMenuMorphModel.PANEL_CORNER_RADIUS_DP.dp)
    val containerColor = MiuixTheme.colorScheme.surfaceContainer

    // 玻璃：有采样源 + 设备支持 RuntimeShader 才画。两者缺一就退回实色，
    // 而不是"模糊空气"（那会得到一块脏灰）。
    val glassBackdrop = backdrop?.takeIf { isRuntimeShaderSupported() }
    // 展开进度 → 玻璃三件套（薄→厚 / 透→实 / 收→满）由模型层一处插值。
    val blurPx = with(density) { HomeMenuMorphModel.glassBlurDp(progress).dp.toPx() }
    val tintAlpha = HomeMenuMorphModel.glassTintAlpha(progress)
    val rimAlpha = HomeMenuMorphModel.rimAlphaScale(progress)
    // 折射带也随进度张开一半：收起态是 40dp 小圆，整条折射带一上来就把它整个包住了。
    val refractionBandPx = with(density) {
        (HomeMenuMorphModel.PANEL_REFRACTION_BAND_DP *
            (0.5f + 0.5f * progress.coerceIn(0f, 1f))).dp.toPx()
    }
    val refractionAmountPx = with(density) {
        HomeMenuMorphModel.PANEL_REFRACTION_AMOUNT_DP.dp.toPx()
    }

    Box(
        modifier = modifier
            .width(widthDp)
            .height(with(density) { heightPx.toDp() })
            .shadow(
                elevation = (2f + 10f * progress.coerceIn(0f, 1f)).dp,
                shape = shape,
                clip = false,
            )
            .then(
                if (glassBackdrop != null) {
                    Modifier.drawBackdrop(
                        backdrop = glassBackdrop,
                        shape = { shape },
                        effects = {
                            // 折射要往形状外采样：先把采样层按位移量撑起来。
                            // ⚠️ 必须在 blur() 读 padding 之前抬（同玻璃坞 / 顶栏带）。
                            padding = maxOf(padding, refractionAmountPx)
                            vibrancy()
                            blur(blurPx)
                            lens(
                                refractionHeight = refractionBandPx,
                                refractionAmount = refractionAmountPx,
                            )
                        },
                        // 边缘光：玻璃的"厚边"高光，是它读起来像一块玻璃而不是一张
                        // 半透明纸的关键。强度随展开进度收放（收起态收敛成一圈淡边）。
                        highlight = { glassPanelSpecular.copy(alpha = rimAlpha) },
                        onDrawSurface = { drawRect(containerColor.copy(alpha = tintAlpha)) },
                    )
                } else {
                    Modifier.clip(shape).background(containerColor)
                },
            ),
    ) {
        MenuRowsColumn(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .requiredWidth(panelWidthDp)
                // unbounded：跳出「面板当前高度」的约束，量出内容自己的高度。
                .wrapContentHeight(align = Alignment.Top, unbounded = true)
                .onSizeChanged { contentHeightPx = it.height }
                .graphicsLayer {
                    alpha = contentAlpha
                    scaleX = contentScale
                    scaleY = contentScale
                    // 右上角为缩放中心：变形全程内容右缘与容器右缘重合。
                    transformOrigin = TransformOrigin(1f, 0f)
                },
        ) {
            rows.forEachIndexed { index, row ->
                DropdownImpl(
                    item = DropdownItem(
                        text = row.label,
                        icon = { iconModifier ->
                            Icon(
                                imageVector = row.icon,
                                contentDescription = null,
                                modifier = iconModifier,
                            )
                        },
                    ),
                    optionSize = rows.size,
                    isSelected = false,
                    index = index,
                    hasSubmenu = row.hasSubmenu,
                    isFirst = index == 0,
                    isLast = index == rows.lastIndex,
                    onSelectedIndexChange = {
                        if (row.hasSubmenu) onToggleSubmenu(row.id) else onSelect(row.id)
                    },
                )
            }
        }
    }
}

/**
 * 把每一行都拉满面板宽度，并按内容高度纵向堆叠。
 *
 * ## 为什么不能直接用 `Column`
 *
 * 官方 [DropdownImpl] 的行是**自适应宽度**的（它内部的 `Row` 没有 `fillMaxWidth`）。
 * 官方弹层之所以铺满，是 `ListPopupColumn` 在**测量时**把子项约束成
 * 「`minWidth = maxWidth` = 弹层宽」（`basic/ListPopup.kt` 的 `MeasurePolicy`
 * 里那行 `childConstraints`）。直接用 `Column` 时行只按自身内容宽度排版、
 * 全部贴在左边 —— 观感就是「菜单内容只在面板左半边、右边一大片空底」。
 *
 * ## 为什么不用官方 `ListPopupColumn`
 *
 * 它把宽度钳在 200~288dp，并且**只按前 8 项**估高（`MAX_ITEMS_FOR_HEIGHT = 8`）；
 * 二级展开后有 11 行，会被它按 8 行的高度裁掉。所以这里只取它「强制子项等宽」
 * 这一个动作，自己量一遍。
 */
@Composable
private fun MenuRowsColumn(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Layout(content = content, modifier = modifier) { measurables, constraints ->
        // 外面套了 `requiredWidth`，宽度一定是一个确定值。
        val width = constraints.maxWidth
        val placeables = measurables.map { measurable ->
            measurable.measure(
                Constraints(minWidth = width, maxWidth = width, minHeight = 0),
            )
        }
        val height = placeables.sumOf { it.height }
        layout(width, height) {
            var y = 0
            placeables.forEach { placeable ->
                placeable.placeRelative(0, y)
                y += placeable.height
            }
        }
    }
}

/**
 * 面板玻璃的边缘光（specular）。
 *
 * 用官方 `BloomStroke`：`dualPeak = true` 让**对置两条边同时**有高光（读起来是一块
 * 有厚度的玻璃，而不是只在一边反光的塑料片）。颜色只有 0.14 白，因为它是**叠加**
 * 在玻璃边上的 —— 拉高会直接糊成白框。
 */
private val glassPanelSpecular: Highlight = Highlight(
    width = 1.dp,
    alpha = 1f,
    style = BloomStroke(
        color = Color.White.copy(alpha = 0.14f),
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

/**
 * 一行菜单（渲染用的扁平表）。
 *
 * [hasSubmenu] = 这一行是二级触发器（官方口径：`DropdownImpl` 给它画箭头而不是对勾）；
 * 展开时它的子项被**插在它后面**，而不是替换整张表 —— 用户随时能看见自己点开了哪一项。
 */
private data class HomeMenuMorphRow(
    val id: String,
    val label: String,
    val icon: ImageVector,
    val hasSubmenu: Boolean,
)

private fun homeMenuMorphRows(
    items: List<TimetableMenuItem>,
    expandedSubmenuId: String?,
): List<HomeMenuMorphRow> = buildList {
    items.forEach { item ->
        add(
            HomeMenuMorphRow(
                id = item.id,
                label = item.label,
                icon = item.icon,
                hasSubmenu = item.children.isNotEmpty(),
            ),
        )
        if (item.children.isNotEmpty() && item.id == expandedSubmenuId) {
            item.children.forEach { child ->
                add(
                    HomeMenuMorphRow(
                        id = child.id,
                        label = child.label,
                        icon = child.icon,
                        hasSubmenu = false,
                    ),
                )
            }
        }
    }
}
