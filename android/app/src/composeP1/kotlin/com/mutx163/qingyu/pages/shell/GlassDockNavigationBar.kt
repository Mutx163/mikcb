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
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.ui.graphics.toArgb
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.components.glass.GlassDockSpecular
import com.mutx163.qingyu.components.glass.glassRimAlpha
import com.mutx163.qingyu.components.liquid.DampedDragAnimation
import com.mutx163.qingyu.components.liquid.InnerShadow
import com.mutx163.qingyu.components.liquid.InteractiveHighlight
import com.mutx163.qingyu.components.liquid.innerShadow
import com.mutx163.qingyu.components.liquid.lens
import com.mutx163.qingyu.components.liquid.rememberCombinedBackdrop
import com.mutx163.qingyu.components.liquid.vibrancy
import com.mutx163.qingyu.pages.settings.GlassDockIconVectors
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.LiquidGlassTuning
import com.mutx163.qingyu.pages.settings.SurfaceMaterialState
import com.mutx163.qingyu.theme.QingyuTheme
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
 * 圆钮（药丸右侧独立按钮）该画哪个图标。
 *
 * ## 取值顺序（Dart `timetable_home_page_assembly.dart:363-381` 同口径）
 *
 * 1. 用户在「圆钮图标」里挑的名字（`settings.glassDockButtonIconName`）→
 *    [GlassDockIconVectors.byName]；
 * 2. 名字为空 / 未知 / 矢量表缺项 → [HomeNavIcons.iconOf] 给圆钮**绑定动作**的目录图标。
 *
 * 圆钮默认绑定 `addCourse`，所以「没自定义」时画的就是那个默认加号（
 * `glassDockButtonEntryId` 缺省值）。把圆钮改成别的动作（如「概览」）时，
 * 第 2 步回退的是该动作自己的图标，不会画成加号误导用户。
 *
 * ## 为什么回退也放这里
 *
 * 宿主同时决定「点下去做什么」与「画什么」。两处的默认值一旦各写一份、日后分叉，
 * 就会出现按钮画着 A、点下去做 B。**也不在这里复制图标表**：名字 → 矢量只经
 * [GlassDockIconVectors.byName]，与设置挑选页共用同一份键表（156 项）。
 *
 * @param chosenName `TimetableSettingsModel.glassDockButtonIconName`；null = 用户没自定义。
 * @param roundActionId `HomeDockNavModel.roundButtonAction(...)` 的结果（缺省 `addCourse`）。
 */
fun glassDockRoundButtonIcon(
    chosenName: String?,
    roundActionId: String,
): ImageVector {
    val custom = chosenName
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?.let { GlassDockIconVectors.byName(it) }
    return custom ?: HomeNavIcons.iconOf(roundActionId)
}

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
 * @param trailingContent 药丸**右侧的独立圆钮**（Flutter 玻璃坞那个「加课」按钮，
 *   `settings.glassDockShowAddButton` 打开时才有）。放在这里而不是宿主里各画一份：
 *   底部避让（手势条内缩）、居中与左右留白只有一处口径，宿主各写一遍必然漂。
 *   为空时药丸照旧居中、宽度上限仍是 [maxWidthDp]。
 * @param isTab 这一格点下去会不会**换主屏内容**（= 选中指示器该不该跟过去）。
 *   默认全部算 tab。底栏条目并非都能当主屏内容：点开是**推一层页面**的条目
 *   （外观编辑器、加课这类表单页）主屏其实没换，指示器必须留在原来的视图上 ——
 *   否则页面退回来以后，底栏还亮着那一格（2026-11-01 用户报的现象）。
 */
@Composable
fun GlassDockNavigationBar(
    items: List<GlassDockItem>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    backdrop: Backdrop? = null,
    /**
     * 材质快照（`SettingsMaterialModel.renderSpecOf`）。null = 老行为（恒液态档）。
     *
     * 2026-11-01 之前坞不读任何材质设置：总闸关掉、作用范围关掉、八根旋钮怎么拖，
     * 屏幕上的药丸一模一样。现在按 [HomeMaterialRenderSpec.dock] 分三档：
     * 实体（不采样）/ 磨砂（模糊、不折射）/ 液态（模糊 + 折射 + 染色）。
     */
    material: HomeMaterialRenderSpec? = null,
    /**
     * 药丸底下那条壁纸的亮度（0~1，来自 `HomeBackgroundModel.InkBands.dock`）。
     * null = 底下不是壁纸（内嵌实色页 / 没有壁纸），墨色按主题面判。
     * 判据本身在 [DockInkRule]：标签与图标共用同一份结果，不在这里各算一套。
     */
    wallpaperLuminance: Double? = null,
    /**
     * 这一页底下是否是**壁纸**（周 / 日 / 月视图为 true；任务、设置等内嵌实色页为 false）。
     * 仅用于「壁纸页但亮度未知」时保守取浅墨兜底，见下方 `unknownWallpaperBackdrop`。
     */
    overWallpaper: Boolean = false,
    modifier: Modifier = Modifier,
    maxWidthDp: Int = 380,
    trailingContent: (@Composable () -> Unit)? = null,
    isTab: (index: Int) -> Boolean = { true },
) {
    if (items.isEmpty()) return
    // `selectedIndex == -1` 是**合法状态**，不是越界：当前主屏内容不在底栏排列里时
    // （例如用户把「日课表」从底栏删了、却仍停在日视图），Dart 整栏不亮、不画指示器
    // （`soft_glass_tab_bar.dart:225,343`）。钳成 0 会硬亮一格**根本没打开**的视图，
    // 用户以为点错了（2026-10-31 审核 P1-4）。拖拽/动画仍需要一个数值起点，所以
    // `safeIndex` 只给内部用，屏上表现由 [hasSelection] 决定。
    val hasSelection = selectedIndex in items.indices
    val safeIndex = if (hasSelection) selectedIndex else 0
    val colors = MiuixTheme.colorScheme
    val accentColor = colors.primary
    val surfaceContainer = colors.surfaceContainer
    val isDark = surfaceContainer.luminanceIsDark()

    // 只有「有采样源 + 设备支持 runtime shader + 这一表面不是实体档」才走液态/磨砂。
    // 少判 isRuntimeShaderSupported 会在低版本机上得到黑块而不是"没效果"。
    //
    // 三档来源是 `SettingsMaterialModel.renderSpecOf`（总闸 / 作用范围 / 无 shader
    // 系统降级都已折算好）：null = 没传材质（老行为，恒液态）。
    val density = LocalDensity.current
    val dockSurface = material?.dock
    val liquidDock = dockSurface == null || dockSurface == SurfaceMaterialState.LIQUID_GLASS
    val frostedDock = dockSurface == SurfaceMaterialState.FROST
    val isBlurActive = backdrop != null &&
        isRuntimeShaderSupported() &&
        dockSurface != SurfaceMaterialState.SOLID &&
        dockSurface != SurfaceMaterialState.OFF
    val containerColor = when {
        !isBlurActive -> surfaceContainer
        // 实体/无采样源：不透明底（老降级同款）。
        // 磨砂：仍模糊，但比液态厚一点、没有折射。
        frostedDock -> surfaceContainer.copy(alpha = 0.55f)
        // 液态：染色强度就是材质面板那根 `tintAlpha`（0 = 全透，0.9 = 最厚）。
        liquidDock && material != null ->
            surfaceContainer.copy(alpha = material.liquidTintAlpha.coerceIn(0f, 0.9f))
        else -> surfaceContainer.copy(alpha = 0.4f)
    }

    // ── 标签 / 图标墨色（唯一判据 DockInkRule，2026-11-03）──
    //
    // 以前固定取 `colors.onBackground`：浅色主题 + 暗壁纸就是「近黑的字压暗照片」，
    // 深色主题 + 亮壁纸反过来；药丸染色强度从 0 拉到 0.9 时也没有任何跟随。
    // 现在把「药丸染色 + 底下壁纸」合成成一个有效亮度，再按 Dart 旧版那条 0.45 阈值
    // 翻黑 / 白。壁纸亮度只在真有采样、且宿主确认「这一页底下是壁纸」时参与
    //（`wallpaperLuminance == null` ⇒ 内嵌实色页，按主题面判）。
    val surfaceLuminance = HomeBackgroundModel.relativeLuminance(surfaceContainer.toArgb())
    val dockLuminance = DockInkRule.effectiveLuminance(
        surfaceLuminance = surfaceLuminance,
        wallpaperLuminance = if (isBlurActive) wallpaperLuminance else null,
        tintAlpha = containerColor.alpha.toDouble(),
    )
    // 兜底：壁纸页 + 玻璃在采样 + 壁纸亮度**未知**（缓存冷 / 异步未到）时，别拿纯白
    // `surfaceContainer` 判深墨——那会把近黑字压在半透明深/黑药丸上，看不见（2026-11-04）。
    // 保守取浅墨（`DockInkRule.resolve(0.0)` ⇒ useLightInk=true），真值到位后自动精确翻面。
    val unknownWallpaperBackdrop = overWallpaper && isBlurActive && wallpaperLuminance == null
    val inkState = if (unknownWallpaperBackdrop) {
        DockInkRule.resolve(0.0, isDarkTheme = isDark)
    } else {
        DockInkRule.resolve(dockLuminance, isDarkTheme = isDark)
    }
    // 墨色本体仍是主题令牌（与课表顶栏同一套近白 / 近黑），不在这里写死色值。
    val baseInk = Color(QingyuTheme.primaryText(dark = inkState.useLightInk))
    val selectedInk = if (inkState.selectedUsesAccent) {
        accentColor
    } else {
        baseInk.copy(alpha = inkState.selectedAlpha)
    }
    val unselectedInk = baseInk.copy(alpha = inkState.unselectedAlpha)
    val dockBlurRadiusPx = with(density) {
        (material?.liquidBlurSigma ?: GlassDockGeometry.GlassBlurRadiusDp).dp.toPx()
    }
    // 折射两根旋钮 → miuix 透镜的两项（带宽度 / 位移量），以出厂档为 1 倍基准。
    // 磨砂档不折射；实体档连采样都不做（上面已关）。
    val refractionAmountScale =
        (material?.liquidRefraction ?: LiquidGlassTuning.DEFAULT_REFRACTION.toFloat()) /
            LiquidGlassTuning.DEFAULT_REFRACTION.toFloat()
    val refractionBandScale =
        (material?.liquidRefractionBand ?: LiquidGlassTuning.DEFAULT_REFRACTION_BAND.toFloat()) /
            LiquidGlassTuning.DEFAULT_REFRACTION_BAND.toFloat()
    // 边光强度：出厂 0.2 对应原来的 0.75 alpha；旋钮拉到 0 就完全不要边光。
    // 口径与课卡同一份实现（components/glass/GlassHighlights.kt 的 glassRimAlpha）。
    val rimHighlightAlpha = glassRimAlpha(material?.liquidRimStrength)

    val pillShape = remember { CircleShape }
    val isLtr = LocalLayoutDirection.current == LayoutDirection.Ltr
    val animationScope = rememberCoroutineScope()
    val tabsCount = items.size

    // ② 层的录像带：把"图标+文字"录下来，供 ③ 层连同背景一起采样。
    val tabsBackdrop = rememberLayerBackdrop()
    val combinedBackdrop = backdrop?.let { rememberCombinedBackdrop(it, tabsBackdrop) }

    var totalWidthPx by remember { mutableFloatStateOf(0f) }

    // 槽宽 = 栏宽 + 槽数派生，**不能**只在 `onSizeChanged` 里算一次并存起来。
    // 2026-10-28 审计 E6：底栏槽位现在可由用户在设置里增删（`glassDockActions`），
    // 「槽数变了、栏宽没变」是常规路径（3 槽 ↔ 4 槽，栏宽都受 maxWidthDp 夹住）；
    // 旧写法此时仍用上一次的槽宽，指示器会停在栏中间，点哪一格都错位。
    val contentPaddingPx = with(density) { GlassDockGeometry.GlassContentPaddingDp.dp.toPx() }
    val tabWidthPx by remember(tabsCount, contentPaddingPx) {
        derivedStateOf {
            if (totalWidthPx <= 0f) {
                0f
            } else {
                GlassDockGeometry.glassSlotWidthPx(
                    containerWidthPx = totalWidthPx,
                    itemCount = tabsCount,
                    paddingPx = contentPaddingPx,
                )
            }
        }
    }

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
    // 拖拽回调记得住旧 lambda：`isTab` 每帧可能换（条目表随设置变），必须取最新。
    val isTabUpdated by rememberUpdatedState(isTab)
    // 同理：`hasSelection` 也是组合期算的，释放回调里要用最新值。
    val hasSelectionUpdated by rememberUpdatedState(hasSelection)

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
                if (isTabUpdated(targetIndex)) {
                    // `!hasSelection`：当前主屏内容不在底栏排列里（整栏不亮）时，
                    // 点第一格也必须上报 —— 否则 `currentIndex` 初值就是 0，点它永远
                    // 不触发（2026-11-01 审计发现的死点）。
                    if (currentIndex != targetIndex || !hasSelectionUpdated) {
                        currentIndex = targetIndex
                        onSelectUpdated(targetIndex)
                    }
                    updateValue(targetIndex.toFloat())
                } else {
                    // 推页条目：主屏没换，指示器弹回真正的选中格（否则页面退回来还亮着它）。
                    onSelectUpdated(targetIndex)
                    updateValue(currentIndex.toFloat())
                }
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

    /**
     * 点某一格。
     *
     * 推页条目（[isTab] 为 false）**不挪指示器** —— 主屏没换，选中态只能由外部
     * `selectedIndex` 驱动（`LaunchedEffect(safeIndex)` 里同步并播动画）。
     * 以前这里不问类型就地挪，退出外观编辑页后底栏还亮着那一格（2026-11-01 用户报）。
     */
    fun activateTab(index: Int) {
        if (!isTabUpdated(index)) {
            onSelectUpdated(index)
            dampedDrag.animateToValue(currentIndex.toFloat())
            return
        }
        if (currentIndex != index || !hasSelectionUpdated) {
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
            // 选中墨色跟**报告的选中项**走（safeIndex），不跟拖动中的动画索引：
            // 否则手指拖过中间格时中间格会先亮一下。
            val itemInk = if (hasSelection && index == safeIndex) selectedInk else unselectedInk
            Column(
                modifier = Modifier
                    .semantics(mergeDescendants = true) {
                        selected = hasSelection && index == currentIndex
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
                // 图标与文字共用这一份 [itemInk]（判据只有 DockInkRule 一处）：
                // 以前图标吃的是 `LocalContentColor` 的主题墨色、文字有时被另一层
                // provider 覆盖，于是会出现「图标还行、字发灰」。
                CompositionLocalProvider(LocalContentColor provides itemInk) {
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
                            style = labelStyle.shiftWeight(
                                if (hasSelection && index == currentIndex) {
                                    QingyuWeightDelta.SEMIBOLD
                                } else {
                                    0
                                },
                            ),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        // 宽屏（≥ 428dp）时 `maxWidthDp` 生效，药丸不能再贴着左边留一大片空白
        // —— 2026-10-28 审计 E5（480dp 屏右侧空 76dp）。Column 默认横向对齐是 Start。
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(
            modifier = Modifier
                .padding(
                    // 底部内边距的口径在 HomeFloatingMetrics 一份：首页两颗浮钮要按
                    // 「药丸占用」避让，不能在这里和页面各写一遍（写两遍必然漂）。
                    bottom = HomeFloatingMetrics
                        .dockBottomPaddingDp(navBarBottomPadding.value)
                        .dp,
                    start = 24.dp,
                    end = 24.dp,
                )
                .widthIn(max = maxWidthDp.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                // 药丸吃掉剩余宽度；圆钮出现时自动让出「按钮宽 + 8dp 间距」，
                // 而不是把整组推出屏幕（窄屏 5 槽 + 圆钮的实测宽度就是这么来的）。
                modifier = Modifier.weight(1f),
                contentAlignment = Alignment.CenterStart,
            ) {
            // ── ① 外壳胶囊 ──
            //
            // ⚠️ 这一层与 ③ 指示器在 demo 里是**同一个 Box 的直接子节点**，中间不再包
            // 一层 4dp 内边距；那 4dp 是 Row 自己 `.height().padding(4.dp)` 的内边距。
            // 这里曾经多包了一层：玻璃因此比 demo 窄 8dp、整体还右下各偏 4dp，而指示器
            // 仍按外层坐标摆放 —— 结果选中块在左端贴死玻璃边、右端却空出 4dp，两端不对称。
            CompositionLocalProvider(LocalContentColor provides unselectedInk) {
                Row(
                    modifier = Modifier
                        .selectableGroup()
                        .onSizeChanged { coords ->
                            // 只记栏宽：槽宽由它 + 槽数派生（见上方 `tabWidthPx`）。
                            // 两侧各让出一个内边距；少减一侧（写成 `- 4`）每格就偏大
                            // 4/n dp，末格的右边界会正好压在玻璃边缘上（一点余量不留），
                            // 按下放大立刻从那儿顶出去。
                            totalWidthPx = coords.width.toFloat()
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
                                        blur(dockBlurRadiusPx)
                                        // 磨砂档（作用范围关）只糊不折射；液态档才叠透镜。
                                        if (liquidDock) {
                                            lens(
                                                refractionHeight = with(density) {
                                                    (GlassDockGeometry.RefractionHeightDp *
                                                        refractionBandScale).dp.toPx()
                                                },
                                                refractionAmount = with(density) {
                                                    (GlassDockGeometry.RefractionAmountDp *
                                                        refractionAmountScale).dp.toPx()
                                                },
                                            )
                                        }
                                    },
                                    highlight = {
                                        baseHighlight.value.copy(alpha = rimHighlightAlpha)
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
                                    blur(dockBlurRadiusPx)
                                    if (liquidDock) {
                                        lens(
                                            refractionHeight = with(density) {
                                                (GlassDockGeometry.RefractionHeightDp *
                                                    refractionBandScale).dp.toPx()
                                            },
                                            refractionAmount = with(density) {
                                                (GlassDockGeometry.RefractionAmountDp *
                                                    refractionAmountScale).dp.toPx()
                                            },
                                        )
                                    }
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
            // 无选中态（-1）连指示器都不画：留一块空白比亮错一格诚实。
            if (hasSelection && tabWidthPx > 0f) {
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
                                        if (liquidDock) {
                                            lens(
                                                refractionHeight = with(density) {
                                                    (GlassDockGeometry.IndicatorRefractionHeightDp *
                                                        progress * refractionBandScale).dp.toPx()
                                                },
                                                refractionAmount = with(density) {
                                                    (GlassDockGeometry.IndicatorRefractionAmountDp *
                                                        progress * refractionAmountScale).dp.toPx()
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
                                        }
                                    },
                                    highlight = {
                                        pillHighlight.value.copy(
                                            alpha = dampedDrag.pressProgress *
                                                rimHighlightAlpha,
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
            // ── ④ 右侧独立圆钮（Flutter 玻璃坞的「加课」按钮）──
            // 只有宿主传了才画；间距 8dp 与 Dart 一致（`timetable_glass_dock.dart:124-135`）。
            if (trailingContent != null) {
                Spacer(modifier = Modifier.width(8.dp))
                trailingContent()
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
