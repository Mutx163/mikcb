package com.mutx163.qingyu.pages.settings

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.absoluteOffset
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import kotlinx.coroutines.delay

/**
 * 外观编辑页的**沉浸式页面壳**：整屏暗底 + 中间一张「真课表页等比缩尺卡」+
 * 顶部一行 chrome + 底部两颗圆钮。**没有滚动、没有设置列表**。
 *
 * Dart 原件：`lib/screens/settings/settings_appearance_editor.dart`（2649 行）。
 * 本文件只负责「几何 + 卡片 + 装配」，上下 chrome 在 [AppearanceEditorChrome]，
 * 草稿 / 落盘 / 两个弹层在 `app/AppearanceEditorHost.kt`。
 *
 * ## 与 Dart「方案 A（烤图）」的等价物：活树缩放，而不是截图
 *
 * Dart 把真首页按整屏 1:1 渲染在页面底层，再由 `PreviewBakeBoundary` 录成一帧位图、
 * 卡片显示那张图（`:56-73` 的类注释写了为什么不是 `FittedBox` 活树直显：玻璃采样链
 * 在非原生尺度下坐标折算会漂）。Kotlin 侧没有那套玻璃烤图机制，这里用**同一棵树、
 * 原生尺度排版、只在外层做 `graphicsLayer` 缩放**：
 *
 * * 卡片里的课表页拿到的约束是 `requiredSize(整屏尺寸)` —— 它按**整屏 1:1** 排版，
 *   与真实课表页逐参一致，不另排一套「小屏布局」；
 * * 缩放在绘制层完成（`graphicsLayer(scaleX, scaleY, origin = (0,0))`），不改变
 *   子树里任何一次 layout/measure，于是「原样缩小」这件事成立；
 * * 外层 `clip` 到屏幕圆角 × 缩放比的圆角矩形，多余部分被裁掉。
 *
 * 这就是 Dart 类注释里「直接用首页那份代码、观感一致」在 Compose 里的对应做法；
 * 也不是自研控件：`graphicsLayer` / `clip` 都是官方 Compose 绘制原语，卡片本身没有
 * 任何自定义亚像素绘制。（将来若接回 miuix 的玻璃采样，需要重新评估这一层。）
 *
 * ## 卡片不是第二个可操作首页
 *
 * [consumeAllPointerEvents] 在 **Initial pass** 把每个 pointer change 都消费掉：
 * 点击、长按、拖动、滚动全部到不了子树。比「外层 `clickable` 吞点击」更彻底——
 * 拖动和滚动不会被漏掉。语义上等于 Dart 的 `IgnorePointer`（`:1776`）。
 *
 * ## 日 / 周分段只动预览
 *
 * 分段状态是**本页自己的** `remember`，初值取 [initialDayView]（= 持久化的
 * `timetableHomeViewMode`，Dart `:203-204` 的 `_dayPreview`）；切换只改这个局部值，
 * **不写回 `timetableHomeViewMode`**，也不写任何浏览位置 —— 等价于 Dart 的
 * `TimetableHomePreviewScope`「预览模式下不写回访状态」（`:195` 那条注释）。
 *
 * ## 加载罩
 *
 * [previewReady] 为 false 时盖整页（转圈 + 通用「加载中」），淡出后从树上摘掉。
 * Kotlin 这份预览是活树、首帧就有内容，所以宿主通常传 `true`（罩子不进树）；参数
 * 保留是为了将来预览改成异步图源时能直接复用 Dart 那套三态门。
 *
 * @param initialDayView 预览初始停在日课表（true）还是周课表（false）。
 * @param onCancel 「取消」：宿主回滚到进页快照后返回（Dart `:735-740`，不是什么都不做）。
 * @param onDone 「完成」：保留改动并返回（Dart `:672-675`）。
 * @param onAdjustWallpaper 底部「调整壁纸」圆钮：宿主开壁纸面板。
 * @param onMaterial 底部「材质」圆钮：宿主开材质面板。
 * @param previewReady 首帧预览是否已就绪；false 时显示加载罩。
 * @param preview 卡片内容槽：宿主在这里放**真课表页**（周 / 日由参数选）。
 *   **不要**在这里自己做缩放或裁剪，那两件事由本文件负责。
 */
@Composable
fun AppearanceEditorScreen(
    initialDayView: Boolean,
    onCancel: () -> Unit,
    onDone: () -> Unit,
    onAdjustWallpaper: () -> Unit,
    onMaterial: () -> Unit,
    modifier: Modifier = Modifier,
    previewReady: Boolean = true,
    preview: @Composable (dayView: Boolean) -> Unit,
) {
    // 状态栏图标：Dart 用 `AnnotatedRegion<SystemUiOverlayStyle>(value: light)`（`:1598-1600`），
    // 也就是「暗底 → 浅色图标」。Compose 侧等价物是窗口的 insets controller；离开本页
    // 时恢复（壳只在自己的主题变化时重设，不会替我们恢复）。
    ApplyLightSystemBarIcons()

    val density = LocalDensity.current
    val screenWidth = LocalConfiguration.current.screenWidthDp.dp
    val screenHeight = LocalConfiguration.current.screenHeightDp.dp
    // Dart 取 `media.padding.top / bottom`（`:1587-1588`）：状态栏与导航栏/手势条。
    // `systemBars` 与它的口径一致（Dart 侧 MediaQuery.padding 在 edge-to-edge 下就是这两条）。
    //
    // ⚠️ `WindowInsets.systemBars` 是 **@Composable 属性**，必须先取到实例再进
    // `with(density) { }`（那个 lambda 不是 @Composable，直接写会编译不过）。
    val systemBars = WindowInsets.systemBars
    val topInset = with(density) { systemBars.getTop(this).toDp() }
    val bottomInset = with(density) { systemBars.getBottom(this).toDp() }

    var dayView by remember { mutableStateOf(initialDayView) }
    // 加载罩三态里的「还在树上」：淡出跑完才移除（见 [AppearanceEditorLoadingCover]）。
    var coverMounted by remember { mutableStateOf(!previewReady) }
    LaunchedEffect(previewReady) {
        if (!previewReady) {
            // 兜底：图源出问题时不能让用户对着永远转的圈干等（Dart `_previewCoverMaxWait`，`:301`）。
            delay(APPEARANCE_EDITOR_COVER_MAX_WAIT_MS)
            coverMounted = false
        } else {
            // 淡出这段还留在树上，动画跑完再摘（Dart `onFadedOut`，`:1860-1864`）。
            delay(APPEARANCE_EDITOR_COVER_FADE_MS.toLong())
            coverMounted = false
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(AppearanceEditorScrim),
    ) {
        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            val geometry = appearanceEditorCardGeometry(
                areaWidth = maxWidth,
                areaHeight = maxHeight,
                screenWidth = screenWidth,
                screenHeight = screenHeight,
                topInset = topInset,
                bottomInset = bottomInset,
            )
            val cardShape = RoundedCornerShape(geometry.radius)

            // ── 中间那张卡：整屏尺寸的真课表页，等比缩进来 ──────────────
            // 位置用 `absoluteOffset`（不跟随 RTL 镜像）：Dart 的 `Positioned(left:)`
            // 也是物理左边；卡片横向居中、纵向居中于「上下 chrome 之间」那条带（`:1647-1650`）。
            Box(
                modifier = Modifier
                    .absoluteOffset(x = geometry.cardLeft, y = geometry.cardTop)
                    .size(width = geometry.cardWidth, height = geometry.cardHeight)
                    // 浮影：Dart 是 `0x66000000 / blur 32 / spread 2`（`:1835-1841`）。
                    // 官方 `Modifier.shadow` 没有 spread 参数，2dp 的扩张用 elevation 的
                    // 平台模糊近似（颜色固定 40% 黑，不跟主题）。
                    .shadow(
                        elevation = APPEARANCE_EDITOR_CARD_SHADOW_BLUR,
                        shape = cardShape,
                        clip = false,
                        ambientColor = AppearanceEditorCardShadow,
                        spotColor = AppearanceEditorCardShadow,
                    )
                    .clip(cardShape)
                    // 预览图出来之前那块底：与整页暗底同色，避免先白一下（Dart 卡片
                    // 在没图时是 `SizedBox.expand()`，透出来的是暗底，`:1815-1817`）。
                    .background(AppearanceEditorScrim),
            ) {
                Box(
                    modifier = Modifier
                        // 整屏 1:1 排版：这是「原样缩小」而不是「另排小屏布局」的根。
                        .requiredSize(width = screenWidth, height = screenHeight)
                        // 缩放在绘制层，layout 尺寸仍是整屏 ⇒ 子树里的每一次 measure
                        // 都与真实课表页相同（理由见文件头）。
                        .graphicsLayer {
                            scaleX = geometry.scale
                            scaleY = geometry.scale
                            transformOrigin = TransformOrigin(0f, 0f)
                        }
                        // 预览不是第二个可操作首页：所有输入在这里被吃掉。
                        .consumeAllPointerEvents(),
                ) {
                    preview(dayView)
                }
            }

            // ── 上下 chrome：位置固定，弹层打开期间不动 ─────────────────
            // Dart 口径（2026-09-19）：弹窗打开时上下 chrome **保持常显、位置不变**
            // （`:780-782`），所以它们跟卡片一样是这一层的常驻子节点，不随弹层隐藏。
            AppearanceEditorTopChrome(
                dayView = dayView,
                onDayViewChange = { dayView = it },
                onCancel = onCancel,
                onDone = onDone,
                topInset = topInset,
                modifier = Modifier.align(Alignment.TopCenter),
            )
            AppearanceEditorBottomChrome(
                onAdjustWallpaper = onAdjustWallpaper,
                onMaterial = onMaterial,
                bottomInset = bottomInset,
                modifier = Modifier.align(Alignment.BottomCenter),
            )

            // ── 加载罩：Stack 的最后一个子节点 = 盖住卡片与上下 chrome ────
            if (coverMounted) {
                AppearanceEditorLoadingCover(
                    visible = !previewReady,
                    label = SettingsStringsExt1.commonLoadingLabel.zh,
                    modifier = Modifier
                        .fillMaxSize()
                        // 完全盖住期间连点击一起挡（Dart 的 `ColoredBox` 命中测试是 opaque 的）。
                        .consumeAllPointerEvents(),
                )
            }
        }
    }
}

/** 加载罩兜底时长：Dart `_previewCoverMaxWait = Duration(seconds: 6)`（`:301`）。 */
internal const val APPEARANCE_EDITOR_COVER_MAX_WAIT_MS = 6_000L

/**
 * 把每个 pointer change 在 **Initial pass** 消费掉。
 *
 * 只在 Initial 阶段消费才挡得住子树：`clickable` / `LazyColumn` 在 Main 阶段读到
 * `isConsumed = true` 就不再响应。`awaitPointerEvent(PointerEventPass.Final)` 那种写法
 * 只能事后观察、挡不住。
 */
internal fun Modifier.consumeAllPointerEvents(): Modifier = pointerInput(Unit) {
    awaitPointerEventScope {
        while (true) {
            awaitPointerEvent(PointerEventPass.Initial).changes.forEach { change -> change.consume() }
        }
    }
}

/**
 * 在**本页停留期间**把状态栏/导航栏图标切成浅色（暗底上的可读性），离开时还原。
 *
 * 为什么是命令式：Compose 没有 `AnnotatedRegion<SystemUiOverlayStyle>` 的等价物，
 * 系统栏外观唯一入口是窗口的 insets controller。壳只在自己的明暗主题变化时设置一次
 * （`PagesShellActivity.applyShellSystemBars`），不区分当前是哪一页 —— 所以这一页
 * 必须自己临时覆盖、并在 `onDispose` 还原，否则返回设置页后状态栏会一直停在浅色。
 */
@Composable
private fun ApplyLightSystemBarIcons() {
    val view = LocalView.current
    val context = LocalContext.current
    DisposableEffect(view) {
        val window = context.findActivity()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val previousStatus = controller?.isAppearanceLightStatusBars
        val previousNavigation = controller?.isAppearanceLightNavigationBars
        controller?.isAppearanceLightStatusBars = false
        controller?.isAppearanceLightNavigationBars = false
        onDispose {
            if (controller != null) {
                previousStatus?.let { controller.isAppearanceLightStatusBars = it }
                previousNavigation?.let { controller.isAppearanceLightNavigationBars = it }
            }
        }
    }
}

/**
 * 从 `LocalContext` 往上找宿主 `Activity`。
 *
 * 不能直接 `context as? Activity`：Activity 里的 Compose 上下文经常是
 * `ContextThemeWrapper`（主题包了一层），直接转型会得到 null、系统栏一句话都设不上。
 */
private fun Context.findActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}

// ─────────────────────────────────────────────── 几何（逐数照抄 Dart）

/**
 * 屏幕圆角兜底值（逻辑像素）。
 *
 * Dart 侧这个数从平台通道读（`AndroidAnimationScaleService.displayCornerRadiusDp`），
 * 拿不到时回落到 `kPageCornerRadiusFallbackDp = 28`
 * （`lib/models/page_corner_radius.dart:16`）。Kotlin 侧目前**没有**读屏幕圆角的
 * 平台层，所以先取同一个兜底值 —— 卡片圆角 = 这个值 × 缩放比（Dart `:1638-1642`）。
 * 将来补了平台读数，改这一处即可。
 */
internal val APPEARANCE_EDITOR_SCREEN_CORNER_RADIUS_DP: Dp = 28.dp

/** 卡片浮影模糊半径：Dart `blurRadius: 32`（`:1838`）。 */
internal val APPEARANCE_EDITOR_CARD_SHADOW_BLUR: Dp = 32.dp

/**
 * 卡片相对可用宽度的上限比例：Dart `_cardMaxWidthFactor = 0.86`（`:109-114`）。
 *
 * 2026-09-20 从 0.82 提到 0.86，配合「顶部收成一行、底部圆钮下移」——竖屏上高度
 * 通常才是限制项，这个系数只在宽/矮窗口上兜底。
 */
internal const val APPEARANCE_EDITOR_CARD_MAX_WIDTH_FACTOR = 0.86f

/** 顶部净空扣除项：Dart `topInset + 16 + 40 + 18`（`:1624`）。 */
private val TopChromeReserve = 16.dp + 40.dp + 18.dp

/** 底部净空扣除项：Dart `bottomInset + 24 + 56 + 8 + 18`（`:1625`）。 */
private val BottomChromeReserve = 24.dp + 56.dp + 8.dp + 18.dp

/** 卡片可用高度的下限：Dart `.clamp(120.0, double.infinity)`（`:1628`）。 */
private val MinCardBandHeight = 120.dp

/**
 * 卡片的落点几何（单位都是 dp / 无单位缩放比）。
 *
 * 字段与 Dart `LayoutBuilder` 里那批局部变量一一对应（`:1624-1650`），命名尽量贴原变量，
 * 免得两边对不上。
 */
internal data class AppearanceEditorCardGeometry(
    /** 卡片相对整屏的缩放比（Dart `scale`，`:1632`）。 */
    val scale: Float,
    /** 卡片宽（= 整屏宽 × scale，Dart `cardWidth`）。 */
    val cardWidth: Dp,
    /** 卡片高（= 整屏高 × scale，Dart `cardHeight`）。 */
    val cardHeight: Dp,
    /** 卡片左边（横向居中，Dart `cardLeft`）。 */
    val cardLeft: Dp,
    /** 卡片上边（纵向居中于「上下 chrome 之间」那条带，Dart `cardTop`）。 */
    val cardTop: Dp,
    /** 卡片圆角（= 屏幕圆角 × scale，再夹到 cardHeight/2，Dart `cardRadius`）。 */
    val radius: Dp,
    /** 顶部留给 chrome 的净空。 */
    val topReserve: Dp,
    /** 底部留给 chrome 的净空。 */
    val bottomReserve: Dp,
    /** 上下净空之间那条带的高度（卡片在其中居中）。 */
    val availableHeight: Dp,
)

/**
 * 按 Dart 的几何公式算出卡片矩形（`:1617-1650` 的 `LayoutBuilder` 逐行对应）。
 *
 * 之所以抽成纯函数：这页唯一「看得见的错」就是卡片偏了/大小不对，而这类几何数值
 * 应当能被逐数断言（不需要真机）：本函数不读 `BoxWithConstraintsScope`、不碰任何
 * Compose 组合，输入输出都是数值，将来补单测时不用重构。公式里**没有任何手工修正项**
 * —— Dart 明确撤掉了「视觉重心」偏移（`:1643-1646`：加过一版，结果卡片压到底部按钮净空里）。
 *
 * @param areaWidth / areaHeight 整页可用区（`BoxWithConstraints` 的约束）。
 * @param screenWidth / screenHeight 整屏逻辑尺寸（Dart `media.size`）。
 * @param topInset / bottomInset 系统栏高度。
 * @param screenCornerRadius 屏幕圆角（见 [APPEARANCE_EDITOR_SCREEN_CORNER_RADIUS_DP]）。
 */
internal fun appearanceEditorCardGeometry(
    areaWidth: Dp,
    areaHeight: Dp,
    screenWidth: Dp,
    screenHeight: Dp,
    topInset: Dp,
    bottomInset: Dp,
    screenCornerRadius: Dp = APPEARANCE_EDITOR_SCREEN_CORNER_RADIUS_DP,
): AppearanceEditorCardGeometry {
    val topReserve = topInset + TopChromeReserve
    val bottomReserve = bottomInset + BottomChromeReserve
    val availableHeight =
        (areaHeight - topReserve - bottomReserve).coerceAtLeast(MinCardBandHeight)
    val availableWidth = areaWidth * APPEARANCE_EDITOR_CARD_MAX_WIDTH_FACTOR
    // 保持整屏宽高比、完整放下（不裁切）：取宽/高两个方向缩放比的较小者（`:1632-1635`）。
    val widthScale = if (screenWidth.value > 0f) availableWidth.value / screenWidth.value else 0f
    val heightScale = if (screenHeight.value > 0f) availableHeight.value / screenHeight.value else 0f
    val scale = minOf(widthScale, heightScale)
    val cardWidth = screenWidth * scale
    val cardHeight = screenHeight * scale
    val radius = minOf(screenCornerRadius * scale, cardHeight / 2f)
    val cardCenterY = topReserve + availableHeight / 2f
    return AppearanceEditorCardGeometry(
        scale = scale,
        cardWidth = cardWidth,
        cardHeight = cardHeight,
        cardLeft = (areaWidth - cardWidth) / 2f,
        cardTop = cardCenterY - cardHeight / 2f,
        radius = radius,
        topReserve = topReserve,
        bottomReserve = bottomReserve,
        availableHeight = availableHeight,
    )
}
