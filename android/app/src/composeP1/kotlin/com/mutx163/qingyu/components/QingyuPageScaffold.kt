package com.mutx163.qingyu.components

import android.animation.ValueAnimator
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.unit.Dp
import com.mutx163.qingyu.app.CommonUiStrings
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.SmallTopAppBar
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.blur.BlendColorEntry
import top.yukonga.miuix.kmp.blur.BlurColors
import top.yukonga.miuix.kmp.blur.BlurDefaults
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.blur.textureBlur
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back

/**
 * 全站统一的「子页返回键」。
 *
 * ## 为什么要有这个文件（一次真实的一致性问题）
 *
 * 迁移期各页各写返回键，出现了好几种样子：图标有的用 [MiuixIcons.Back]、
 * 有的把 `Basic.ArrowRight` 转 180°（形状不同）；底色有的显式透明、有的走默认；
 * 颜色有的取 `actionIcon`、有的取 `onBackground`；位置有的在官方 [TopAppBar]
 * 里、有的塞进手写 `Row` 再各自加内边距。用户实测反馈「各不一样」。
 *
 * 这里把「官方顶栏 + 标准左箭头」收成唯一一套实现，页面只声明标题和返回回调。
 *
 * ## 两个骨架变体
 *
 * - [smallTopBar] = false（默认）：官方 [TopAppBar]，带可折叠大标题。适合本来
 *   就用大标题的页面（关于 / 导入 / 大多数列表页）。
 * - [smallTopBar] = true：官方 [SmallTopAppBar]，单行小标题、不可折叠。适合原本
 *   就是小标题的页面，避免强行塞一个大标题改变版式。
 *
 * 两个变体共用同一个 [QingyuBackIconButton]，所以返回键的图标、颜色、命中区、
 * 位置完全一致。
 */
@Composable
fun QingyuBackIconButton(
    onBack: () -> Unit,
    contentDescription: String = CommonUiStrings.back,
    tint: Color? = null,
) {
    val dark = isSystemInDarkTheme()
    IconButton(onClick = onBack) {
        Icon(
            imageVector = MiuixIcons.Back,
            contentDescription = contentDescription,
            tint = tint ?: Color(QingyuTheme.actionIcon(dark)),
        )
    }
}

/** 内容槽拿到的东西：内边距与顶栏折叠行为。 */
class QingyuPageContentScope(
    val innerPadding: PaddingValues,
    val scrollBehavior: ScrollBehavior,
)

/**
 * 全站统一的页面骨架：官方顶栏 + 返回键 + 顶栏毛玻璃。
 *
 * ## 顶栏毛玻璃（照抄官方配方）
 *
 * 出处：`docs/reference/miuix-demo/example/shared/src/commonMain/kotlin/utils/PageUtils.kt:115-168`
 * 与 `MainPage.kt:99-119`、`:256-305`。官方是三步，顺序与依赖不能换：
 *
 * 1. [rememberQingyuBlurBackdrop] 造一个「录像带」（`LayerBackdrop`），并先铺一层页面底色；
 * 2. `Modifier.layerBackdrop(backdrop)` 挂在**页面内容**容器上，把已画出的像素录进去；
 * 3. [QingyuBlurredTopBar] 用 `Modifier.textureBlur(backdrop, RectangleShape, blurRadius = 25f,
 *    colors = 页面底色@0.8)` 把模糊面垫在顶栏下，同时顶栏底色改成 `Color.Transparent`。
 *
 * 三步缺一：只有 3 会采样到空气（黑/透明），只有 2 则毫无视觉变化。
 *
 * ## 退化路径（都回到改动前的样子，不会白屏/闪烁）
 *
 * 见 [rememberQingyuBlurBackdrop]：设备不支持 `RuntimeShader`，或系统关了动画/移除动画时
 * 直接返回 null；此时不挂录屏层、不挂模糊修饰符、顶栏继续用不透明页面底色。
 *
 * ## 宽屏
 *
 * 官方 demo 的宽屏做法在**壳层**（`AppContent.kt:251-276` 用 `NavigationRail` 包住 NavHost、
 * 由 `shouldShowSplitPane()` 判宽）和**页面自身**（`WideScreenContent` 双栏）协作完成；
 * 页面用的 `AdaptiveTopAppBar` 也只是 demo 自己的 `utils` 辅助函数，不是 miuix 组件。
 * 共享骨架无法替页面做这件事，只提供**默认关闭**的 [maxContentWidth] 做保守增强。
 *
 * @param maxContentWidth 非 null 时把内容列限制到该宽度并在宽屏上水平居中；null（默认）保持原样。
 *   不默认开启：官方 demo 在宽屏上并不限制内容宽度，且官方 [TopAppBar] 的大标题是左对齐、
 *   不受这个约束影响——默认打开会让大标题与内容列错开，所以只留作显式选择。
 */
@Composable
fun QingyuPageScaffold(
    title: String,
    onBack: () -> Unit,
    actions: @Composable RowScope.() -> Unit = {},
    bottomBar: (@Composable () -> Unit)? = null,
    smallTopBar: Boolean = false,
    maxContentWidth: Dp? = null,
    content: @Composable QingyuPageContentScope.() -> Unit,
) {
    val dark = isSystemInDarkTheme()
    // 每个页面实例一个折叠状态：返回后重新进入应从展开态开始。
    val scrollBehavior = MiuixScrollBehavior()
    // 顶栏与页面底色必须同源：模糊层靠它铺底，否则内容里的透明区
    // 会在大标题下糊出色块（`docs/guide/blur.md:105-118`）。
    val pageBackground = Color(QingyuTheme.scaffoldBackground(dark))
    val backdrop = rememberQingyuBlurBackdrop(pageBackground)
    val barColor = if (backdrop != null) Color.Transparent else pageBackground
    Scaffold(
        containerColor = pageBackground,
        topBar = {
            QingyuBlurredTopBar(backdrop = backdrop, pageBackground = pageBackground) {
                if (smallTopBar) {
                    SmallTopAppBar(
                        title = title,
                        color = barColor,
                        navigationIcon = { QingyuBackIconButton(onBack = onBack) },
                        actions = actions,
                    )
                } else {
                    TopAppBar(
                        title = title,
                        color = barColor,
                        largeTitle = title,
                        scrollBehavior = scrollBehavior,
                        navigationIcon = { QingyuBackIconButton(onBack = onBack) },
                        actions = actions,
                    )
                }
            }
        },
        bottomBar = { bottomBar?.invoke() },
    ) { innerPadding ->
        // 内容容器：官方把「录像带」挂在这一层（`MainPage.kt:305`）。
        // 不支持模糊时完全不挂，省掉一层图层录制。
        Box(
            modifier = Modifier
                .fillMaxSize()
                .then(if (backdrop != null) Modifier.layerBackdrop(backdrop) else Modifier),
        ) {
            val cap = maxContentWidth
            val contentModifier = if (cap != null) {
                Modifier
                    .fillMaxHeight()
                    .widthIn(max = cap)
                    .align(Alignment.TopCenter)
            } else {
                Modifier.fillMaxSize()
            }
            Box(modifier = contentModifier) {
                // 页面主题桥兜住深色：壳用的是无参 MiuixTheme{ }（配色恒亮），
                // 不在这里兜一层，深色下卡片仍是白底而正文取白字 → 内容不可读。
                QingyuPageTheme {
                    QingyuPageContentScope(innerPadding, scrollBehavior).content()
                }
            }
        }
    }
}

/**
 * 顶栏毛玻璃：官方 `BlurredBar` 的等价物（`PageUtils.kt:126-168`）。
 *
 * 只接官方**均匀模糊**一档：`RectangleShape` 通栏 + `blurRadius = 25f` +
 * 页面底色 80% 不透明度压住背景。官方另一档「渐进模糊」
 * （`progressiveTextureBlur` + `ProgressiveBlur.Top.copy(curve = 2.2f)`）由 demo 的
 * `blurStyle` 设置切换；本仓没有这个设置，不接第二套。
 *
 * [backdrop] 为 null 时退化成普通 `Box`，与改动前的布局完全一致。
 */
@Composable
private fun QingyuBlurredTopBar(
    backdrop: LayerBackdrop?,
    pageBackground: Color,
    content: @Composable () -> Unit,
) {
    val modifier = if (backdrop != null) {
        Modifier.textureBlur(
            backdrop = backdrop,
            shape = RectangleShape,
            blurRadius = 25f,
            colors = qingyuBarBlurColors(pageBackground),
        )
    } else {
        Modifier
    }
    Box(modifier = modifier) { content() }
}

/** 官方 `barBlurColors()`（`PageUtils.kt:163-168`）：通栏面用页面底色 80% 压住背景。 */
@Composable
private fun qingyuBarBlurColors(pageBackground: Color): BlurColors = BlurDefaults.blurColors(
    blendColors = listOf(
        BlendColorEntry(color = pageBackground.copy(alpha = 0.8f)),
    ),
)

/**
 * 造顶栏模糊的采样源（官方 `rememberBlurBackdrop()`，`PageUtils.kt:115-124`）。
 *
 * 退化条件（任一不满足就返回 null，调用方一律走「无模糊」分支，观感与改动前完全一致）：
 * - `isRuntimeShaderSupported()` 为 false：blur / blend 全部依赖 API 33 的 `RuntimeShader`；
 * - 系统「关闭动画 / 移除动画」（`ValueAnimator.areAnimatorsEnabled()` 为 false）：
 *   这是系统级「减少动效」偏好；用户明确关掉动效时不再额外做实时模糊。
 *
 * `drawRect(pageBackground)` 不能省：`layerBackdrop` 只录自己这一层，不含父级底色；
 * 内容若有透明区，模糊会把颜色扩散成色块（`docs/guide/blur.md:105-118`）。
 */
@Composable
private fun rememberQingyuBlurBackdrop(pageBackground: Color): LayerBackdrop? {
    if (!isRuntimeShaderSupported() || !ValueAnimator.areAnimatorsEnabled()) return null
    return rememberLayerBackdrop {
        drawRect(pageBackground)
        drawContent()
    }
}
