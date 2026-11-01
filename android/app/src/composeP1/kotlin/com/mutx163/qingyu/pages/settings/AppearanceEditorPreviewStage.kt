package com.mutx163.qingyu.pages.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import top.yukonga.miuix.kmp.nav.core.NavCornerClipMode
import top.yukonga.miuix.kmp.nav.core.NavDisplay
import top.yukonga.miuix.kmp.nav.core.NavDisplayEffects
import top.yukonga.miuix.kmp.nav.core.NavKey
import top.yukonga.miuix.kmp.nav.core.navBackStackOf
import top.yukonga.miuix.kmp.nav.transition.NavTransitions

/**
 * 外观编辑页**预览区**的舞台：把真首页按整屏 1:1 排版、整体缩进卡片，并可选地
 * 在卡片里**真实重放**一次页面转场。
 *
 * ## 为什么是「真重放」而不是一段假动画
 *
 * 重放用的是官方 `miuix-nav` 的 `NavDisplay`：
 *
 * * 转场几何与全站其它页面**同一套**（`NavTransitions.MiuixDefault`）；
 * * 前缘圆角「洞」由官方 `NavDisplayEffects` 的 `cornerClipMode = Leading` 提供，
 *   半径按缩尺比收小（[AppearanceEditorTransitionSpec.previewNotchRadiusDp]）；
 * * 被覆盖的那一屏是**真首页缩尺树**（宿主注入的 `preview` 槽），上层是外观编辑页
 *   自己的暗底 + 官方 chrome（`AppearanceEditorTopChrome` / `AppearanceEditorBottomChrome`
 *   按同一缩放比排进整屏 1:1 的盒子里）。
 *
 * 所以卡片里发生的事与真机上页面进出**同源**：同一份官方转场、同一份真内容，
 * 只是整个舞台被缩到了卡片大小。不是把一段录好的动画贴上去。
 *
 * ## 与 Dart 的关系（先读，别误判）
 *
 * * Dart 本页的入场 / 退场是**缩放转场**（首页缩进卡片、退出再长回全屏），不是滑动；
 *   miuix-nav v1 没有缩放 / 共享元素预设，自动转场也无法按页覆盖（壳属于 Lead），
 *   所以 Kotlin 壳里这一页实际走的是官方滑动转场。本舞台演示的就是**这条真实路径**。
 * * Dart 出货态的「前缘圆角」是**关闭**的（[AppearanceEditorTransitionSpec.NOTCH_SHIPPED_ENABLED]
 *   = false，直角、没有洞）。演示默认把洞打开（[NOTCH_PREVIEW_ENABLED]），这样用户
 *   能看见「洞是怎么开的」；把那个常量改成 false 就与 Dart 出货观感一致。
 * * 演示只影响这一页的预览区：它有自己的返回栈与 `NavDisplay`，不碰壳的全站转场。
 *
 * ## 开关
 *
 * [APPEARANCE_EDITOR_TRANSITION_PREVIEW_ENABLED] 是总开关（[AppearanceEditorScreen] 的
 * `enableTransitionPreview` 参数默认取它）。关掉时预览区退回纯静态缩尺卡，不建
 * 嵌套 `NavDisplay`。
 */

/** 预览区转场重放的总开关（编译期常量；关掉后不建嵌套 `NavDisplay`）。 */
internal const val APPEARANCE_EDITOR_TRANSITION_PREVIEW_ENABLED = true

/**
 * 进页后等多久开始重放（毫秒）。
 *
 * 必须大于壳的页面转场时长（`NavTransitions.MiuixDefault` 程序化一步约 500ms，
 * 且会按用户「动效速度」放大），否则重放会叠在真实转场上、读成两次动画。
 */
internal const val APPEARANCE_EDITOR_REPLAY_START_DELAY_MS = 900L

/** 上层页面停稳后停留多久再退回（毫秒）。给用户看清「洞收掉、页面盖满」。 */
internal const val APPEARANCE_EDITOR_REPLAY_HOLD_MS = 500L

/** 演示用的两条返回栈路由（纯内存栈，不要求 @Serializable）。 */
private object AppearanceReplayBase : NavKey

private object AppearanceReplayEditor : NavKey

/**
 * 预览区舞台。
 *
 * @param dayView 缩尺首页看日课表还是周课表（只动预览，不写回真实浏览状态）。
 * @param scale 整屏 → 卡片的缩放比（[AppearanceEditorCardBox.scale]）。
 * @param screenWidth / screenHeight 整屏逻辑尺寸：缩尺首页按这个尺寸 1:1 排版。
 * @param topInset / bottomInset 系统栏高度：迷你 chrome 也要按同一套边距排。
 * @param replayTransition 是否重放转场；false 时只画静态缩尺卡。
 * @param preview 宿主注入的真课表页（日 / 周由 [dayView] 选）。
 */
@Composable
internal fun AppearanceEditorPreviewStage(
    dayView: Boolean,
    scale: Float,
    screenWidth: Dp,
    screenHeight: Dp,
    topInset: Dp,
    bottomInset: Dp,
    replayTransition: Boolean,
    modifier: Modifier = Modifier,
    preview: @Composable (dayView: Boolean) -> Unit,
) {
    // 所有输入都在这一层被吃掉：预览不是第二个可操作首页（Dart `IgnorePointer`，`:1776`）。
    // 演示里的 mini chrome 也不该能点。
    Box(modifier = modifier.consumeAllPointerEvents()) {
        if (replayTransition) {
            AppearanceTransitionReplay(
                dayView = dayView,
                scale = scale,
                screenWidth = screenWidth,
                screenHeight = screenHeight,
                topInset = topInset,
                bottomInset = bottomInset,
                preview = preview,
            )
        } else {
            ScaledFullScreenPage(
                scale = scale,
                screenWidth = screenWidth,
                screenHeight = screenHeight,
            ) {
                preview(dayView)
            }
        }
    }
}

/**
 * 静态缩尺：把 [screenWidth] × [screenHeight] 的整屏页面按 [scale] 画进卡片。
 *
 * 缩放在**绘制层**完成（`graphicsLayer`），不改子树任何一次 layout/measure ——
 * 这是「原样缩小」而不是「另排一套小屏布局」的根（外壳拿到的约束仍是整屏尺寸）。
 *
 * ⚠️ **不能用 `Modifier.requiredSize(整屏)` 再套 `graphicsLayer`**（2026-11-01 真机
 * 事故）：整屏页面比卡片大，`requiredSize` 遇到「内容超出父约束」时会把**上报尺寸
 * 收缩到父约束**、并把超出的内容**居中**（Compose 的 `Placeable.apparentToRealOffset`）。
 * 居中量 = (卡片 − 整屏) / 2，而卡片本身就是略缩并居中于屏幕的 —— 两者相消后页面左上角
 * 正好落回**屏幕**左上角，卡片这个窗口只看见页面右下角一块：标题行 / 星期栏 / 时间列 /
 * 左侧几列全被裁掉，「回本周」浮钮跑到卡片左半边。见 [fullScreenPageScaled]。
 */
@Composable
private fun ScaledFullScreenPage(
    scale: Float,
    screenWidth: Dp,
    screenHeight: Dp,
    content: @Composable () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize()) {
        Box(modifier = Modifier.fullScreenPageScaled(scale, screenWidth, screenHeight)) {
            content()
        }
    }
}

/**
 * 让内容按整屏尺寸 1:1 排版、再按 [scale] 缩进父容器，并**钉在父容器左上角**。
 *
 * 这里必须是自定义布局，不能用 `requiredSize`：
 *
 * * 内容（整屏 400×866dp）比父容器（卡片约 284×614dp）大；
 * * `requiredSize` 的语义是「父约束不生效」，但父布局只看到**收缩后**的尺寸，超出的
 *   那一截被**居中**（`Placeable.apparentToRealOffset`）；
 * * 于是页面的左上角被推出去 (卡片 − 整屏)/2 —— 数值上恰好等于卡片自身在屏幕上的偏移，
 *   看起来就是「预览里显示的是整页的右下角一块」。
 *
 * 改用 `layout`：内容仍拿固定的整屏约束（保证 1:1 排版），但**原样上报父给尺寸**、
 * 页面 `place(0, 0)`。上报更大的尺寸会重新触发上面那套收缩 + 居中，所以这里绝不能
 * 报页面尺寸。
 */
private fun Modifier.fullScreenPageScaled(
    scale: Float,
    screenWidth: Dp,
    screenHeight: Dp,
): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(
        Constraints.fixed(screenWidth.roundToPx(), screenHeight.roundToPx()),
    )
    layout(constraints.maxWidth, constraints.maxHeight) {
        placeable.place(0, 0)
    }
}.graphicsLayer {
    scaleX = scale
    scaleY = scale
    transformOrigin = TransformOrigin(0f, 0f)
}

/**
 * 嵌套的官方导航：底层 = 真首页缩尺，顶层 = 迷你外观编辑页。
 *
 * 进页后等 [APPEARANCE_EDITOR_REPLAY_START_DELAY_MS] 再 push，停
 * [APPEARANCE_EDITOR_REPLAY_HOLD_MS] 后 pop —— 一次完整的「进页 / 退页」。
 * 只播一次（[played]），之后预览区就是静止的缩尺首页。
 */
@Composable
private fun AppearanceTransitionReplay(
    dayView: Boolean,
    scale: Float,
    screenWidth: Dp,
    screenHeight: Dp,
    topInset: Dp,
    bottomInset: Dp,
    preview: @Composable (dayView: Boolean) -> Unit,
) {
    val backStack = remember { navBackStackOf(AppearanceReplayBase) }
    var played by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (played) return@LaunchedEffect
        played = true
        delay(APPEARANCE_EDITOR_REPLAY_START_DELAY_MS)
        if (backStack.size == 1) {
            backStack.add(AppearanceReplayEditor)
        }
        delay(APPEARANCE_EDITOR_REPLAY_HOLD_MS)
        if (backStack.lastOrNull() == AppearanceReplayEditor) {
            backStack.removeLastOrNull()
        }
    }

    // 洞半径按缩尺比收小：预览里的一屏 = 真机一屏 × scale（见
    // AppearanceEditorTransitionSpec.previewNotchRadiusDp 的注释）。
    val notchRadius = appearanceEditorPreviewNotchRadius(scale)
    val effects = remember(notchRadius) {
        NavDisplayEffects(
            // 预览默认把 Dart 出货态关掉的洞**开出来**，方便看清官方切口形态；
            // 改成 NOTCH_PREVIEW_ENABLED = false 即与出货一致（直角、无洞）。
            enableCornerClip = AppearanceEditorTransitionSpec.NOTCH_PREVIEW_ENABLED,
            cornerClipRadius = notchRadius,
            cornerClipMode = NavCornerClipMode.Leading,
            // 压暗上限与 Dart 同值（hyperos_miuix_spec.dart:766）。
            dimAmount = AppearanceEditorTransitionSpec.DIM_AMOUNT,
            // 洞后面露出的就是被覆盖页自己的像素；这层底色只在卡片边界外/过渡边缘兜底，
            // 必须与整页暗底同值，否则接管那一帧会闪一下（Dart 同一条契约）。
            backdropColor = AppearanceEditorScrim,
        )
    }

    NavDisplay(
        backStack = backStack,
        modifier = Modifier.fillMaxSize(),
        onBack = {
            // 演示自己的栈：若这次系统返回落到嵌套显示上，只退掉演示这一层；
            // 没落到这里时仍由外层页面的 BackHandler 处理（= 取消本页）。
            if (backStack.size > 1) backStack.removeLastOrNull()
        },
        transition = NavTransitions.MiuixDefault,
        effects = effects,
    ) {
        entry<AppearanceReplayBase> {
            ScaledFullScreenPage(
                scale = scale,
                screenWidth = screenWidth,
                screenHeight = screenHeight,
            ) {
                preview(dayView)
            }
        }
        entry<AppearanceReplayEditor> {
            MiniAppearanceEditorPage(
                dayView = dayView,
                scale = scale,
                screenWidth = screenWidth,
                screenHeight = screenHeight,
                topInset = topInset,
                bottomInset = bottomInset,
            )
        }
    }
}

/**
 * 演示里的上层页面：外观编辑页的**暗底 + 上下 chrome**，按整屏 1:1 排好后同比缩进卡片。
 *
 * 不再套一层缩尺预览卡（那会递归）；它要说明的只是「转场里上层页面是什么样子」。
 * chrome 用的是本页真实组件，不是另画的近似件——所以字号、胶囊、圆钮、分段全都与真页一致。
 */
@Composable
private fun MiniAppearanceEditorPage(
    dayView: Boolean,
    scale: Float,
    screenWidth: Dp,
    screenHeight: Dp,
    topInset: Dp,
    bottomInset: Dp,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            // 洞裁的是这一层的边（entry 边界 = 卡片大小），所以底色必须画在这里。
            .background(AppearanceEditorScrim),
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Box(
                // 与 [ScaledFullScreenPage] 同一条：整屏 1:1 排版、钉在卡片左上角再缩放
                // （不能用 `requiredSize`，它会把超出卡片的内容居中，见 [fullScreenPageScaled]）。
                modifier = Modifier
                    .fullScreenPageScaled(scale, screenWidth, screenHeight)
                    .background(AppearanceEditorScrim),
            ) {
                AppearanceEditorTopChrome(
                    dayView = dayView,
                    onDayViewChange = {},
                    onCancel = {},
                    onDone = {},
                    topInset = topInset,
                    modifier = Modifier.align(Alignment.TopCenter),
                )
                AppearanceEditorBottomChrome(
                    onAdjustWallpaper = {},
                    onMaterial = {},
                    bottomInset = bottomInset,
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }
        }
    }
}

/**
 * 当前预览的缩放比与屏幕圆角（给调用方在组合外算洞半径用；避免两处各写一遍乘法）。
 *
 * 与 [AppearanceEditorTransitionSpec.previewNotchRadiusDp] 同一口径。
 */
internal fun appearanceEditorPreviewNotchRadius(scale: Float): Dp =
    AppearanceEditorTransitionSpec.previewNotchRadiusDp(
        deviceCornerRadiusDp = AppearanceEditorTransitionSpec.SCREEN_CORNER_FALLBACK_DP,
        scale = scale,
    ).dp
