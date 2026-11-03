package com.mutx163.qingyu.components

import android.animation.ValueAnimator
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.unit.Dp
import com.mutx163.qingyu.app.CommonUiStrings
import com.mutx163.qingyu.components.glass.LocalQingyuPageBackdrop
import com.mutx163.qingyu.pages.shell.ShellRootEntryRule
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.SmallTopAppBar
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.blur.BlurColors
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.blur.ProgressiveBlur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.progressiveTextureBlurEffect
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
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

/**
 * 当前页面是否处在**「从底栏进入的根页」**环境（页面栈的栈底主屏）。
 *
 * 由壳在 miuix-nav 的 entry 分支注入：栈底主屏（`ShellRoute.Dock`）= `true`，
 * 推入页（`ShellRoute.Page` / `ZoomPage`）= `false`——页面栈的真实结构由壳声明，
 * 页面自己不传「我是不是根」的布尔。不注入（null）= 无壳环境（缩尺预览卡、独立预览），
 * 骨架保持原行为（显示返回键）。消费方只有 [QingyuPageScaffold]（经
 * [ShellRootEntryRule.shouldShowBackButton]），一处判定、全站生效。
 */
val LocalQingyuPageIsRootEntry = staticCompositionLocalOf<Boolean?> { null }

/** 内容槽拿到的东西：内边距与顶栏折叠行为。 */
class QingyuPageContentScope(
    val innerPadding: PaddingValues,
    val scrollBehavior: ScrollBehavior,
)

/**
 * 顶栏导航槽的内容：根页（[showBackButton] 为 false）给**空**——即 miuix
 * `navigationIcon` 参数的默认值形态（官方「无返回键」的用法），不画任何东西；
 * 其余页面给标准返回键。显隐判据见 [ShellRootEntryRule.shouldShowBackButton]。
 */
private fun backIconOrNull(
    showBackButton: Boolean,
    onBack: () -> Unit,
): @Composable () -> Unit =
    if (showBackButton) {
        { QingyuBackIconButton(onBack = onBack) }
    } else {
        {}
    }

/**
 * 全站统一的页面骨架：官方顶栏 + 返回键 + 顶栏毛玻璃。
 *
 * ## 顶栏毛玻璃（渐进模糊，对齐 Flutter 原版）
 *
 * 采样链路仍照抄官方三步（`PageUtils.kt:115-168`、`MainPage.kt:99-119`、`:256-305`），
 * 顺序与依赖不能换：
 *
 * 1. [rememberQingyuBlurBackdrop] 造一个「录像带」（`LayerBackdrop`），并先铺一层页面底色；
 * 2. `Modifier.layerBackdrop(backdrop)` 挂在**页面内容**容器上，把已画出的像素录进去；
 * 3. [QingyuBlurredTopBar] 用 `drawBackdrop + progressiveTextureBlurEffect` 把**渐进**
 *    模糊面垫在顶栏下（上沿最强、到顶栏底边收敛到 0），同时顶栏底色改成 `Color.Transparent`。
 *
 * 三步缺一：只有 3 会采样到空气（黑/透明），只有 2 则毫无视觉变化。
 *
 * 为什么不用官方 demo 的均匀档 / 也不用 demo 的 `curve = 2.2f`：Flutter 原版子页顶栏
 * 锁死的是渐进档（`2026-09-23-lock-subpage-progressive-blur.md`），参数换算写在
 * [QingyuTopBarBlur] 上；Compose 迁移时先接了均匀档，本次补回原版观感。
 *
 * ## 退化路径（都回到改动前的样子，不会白屏/闪烁）
 *
 * 见 [rememberQingyuBlurBackdrop]：设备不支持 `RuntimeShader`，或系统关了动画/移除动画时
 * 直接返回 null；此时不挂录屏层、不挂模糊修饰符、顶栏继续用不透明页面底色。
 *
 * ## 宽屏（2026-11-03 第一批落地，判据见 core/QingyuAdaptiveRules.kt）
 *
 * 三档以**窗口宽度**为准（紧凑 <600dp / 中宽 / 宽屏），页面侧零改动，全部由骨架兜底：
 *
 * - **中宽与宽档**：内容列限宽 640dp 居中（[maxContentWidth] 缺省时由骨架给默认值）；
 *   顶栏内容同步限制到**同一根内容列**（毛玻璃面仍然通栏），大标题 / 返回键 / 动作键
 *   与正文共用一条左缘——不这么做的话标题贴窗口边缘、正文居中，两套左缘错开
 *   （这正是本骨架旧注释里「默认限宽会让大标题与内容列错开」那条顾虑的解法）。
 * - **宽屏档**：可折叠大标题换成单行 [SmallTopAppBar]（demo `AdaptiveTopAppBar` 的等价
 *   做法）。本仓 miuix 版本没有 demo 的 `defaultWindowInsetsPadding` 参数，内边距行为
 *   与现有 `smallTopBar` 分支保持一致；[scrollBehavior] 照常下发，小标题变体不吃折叠、无副作用。
 * - **紧凑档**（手机竖屏 <600dp）：与宽屏适配落地前逐像素一致。
 *
 * 壳层（Rail 批次）接入后应通过 [QingyuLocalWindowAdaptive] 在根部注入统一取值；
 * 未注入时骨架按窗口自算，平板 / 折叠屏竖屏宽窗立即生效，不依赖壳层改造。
 *
 * @param maxContentWidth 页面显式限宽；null（默认）时中宽/宽档自动用 640dp，紧凑档不限宽。
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
    // 返回键显隐的唯一判定（2026-11-03）：从底栏进入的根页没有上一级可回，不画返回键；
    // 推入的二级/更深页照常画。壳在 entry 分支注入页面栈的真实结构，这里一处消费——
    // 页面零传参，51 处调用点全站生效；判据本体在 ShellRootEntryRule（纯函数 + JVM 单测）。
    val showBackButton = ShellRootEntryRule.shouldShowBackButton(LocalQingyuPageIsRootEntry.current)
    // 顶栏与页面底色必须同源：模糊层靠它铺底，否则内容里的透明区
    // 会在大标题下糊出色块（`docs/guide/blur.md:105-118`）。
    val pageBackground = Color(QingyuTheme.scaffoldBackground(dark))
    val backdrop = rememberQingyuBlurBackdrop(pageBackground)
    val barColor = if (backdrop != null) Color.Transparent else pageBackground
    // 宽屏三档取值：页面显式传入的 maxContentWidth 优先，缺省时中宽/宽档用 640dp 默认值。
    val adaptive = rememberQingyuWindowAdaptive()
    val cap = maxContentWidth ?: adaptive.maxContentWidth
    Scaffold(
        containerColor = pageBackground,
        topBar = {
            QingyuBlurredTopBar(backdrop = backdrop, dark = dark) {
                // 宽屏/中宽档把顶栏内容限制到与正文同一根内容列（毛玻璃面仍然通栏）：
                // 限宽只包内容、不包模糊面，标题/返回键/动作键与正文左缘保持对齐。
                // 宽屏档的大标题换成单行小标题（demo AdaptiveTopAppBar 的等价分支），
                // 小标题在通栏窗口上不再有「32sp 大标题 + 永远收不起」的观感问题。
                val bar: @Composable () -> Unit = {
                    when {
                        smallTopBar -> {
                            SmallTopAppBar(
                                title = title,
                                color = barColor,
                                navigationIcon = backIconOrNull(showBackButton, onBack),
                                actions = actions,
                            )
                        }
                        adaptive.isWideScreen -> {
                            SmallTopAppBar(
                                title = title,
                                color = barColor,
                                navigationIcon = backIconOrNull(showBackButton, onBack),
                                actions = actions,
                            )
                        }
                        else -> {
                            TopAppBar(
                                title = title,
                                color = barColor,
                                largeTitle = title,
                                scrollBehavior = scrollBehavior,
                                navigationIcon = backIconOrNull(showBackButton, onBack),
                                actions = actions,
                            )
                        }
                    }
                }
                if (cap != null) {
                    Box(modifier = Modifier.fillMaxWidth()) {
                        Box(
                            modifier = Modifier
                                .align(Alignment.TopCenter)
                                .widthIn(max = cap),
                        ) {
                            bar()
                        }
                    }
                } else {
                    bar()
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
                    // 弹窗玻璃（GlassOverlayDialog）与顶栏共用这条录像带采样页面内容，
                    // 不另录第二份图层；backdrop 为 null（能力门控关闭）时玻璃自动降级实心。
                    CompositionLocalProvider(LocalQingyuPageBackdrop provides backdrop) {
                        QingyuPageContentScope(innerPadding, scrollBehavior).content()
                    }
                }
            }
        }
    }
}

/**
 * 子页顶栏渐进模糊的参数（对齐 Flutter 原版 `InspireHeaderBlur`，不是官方 demo 的取值）。
 *
 * ## 为什么是这几个数
 *
 * - **半径 49dp**：Flutter 渐进档的固定高斯 sigma = 22 逻辑 px
 *   （`lib/ui/hyperos/inspire/inspire_header_blur.dart` 的 `progressiveSigma`）。
 *   miuix 的换算是 `sigma_px = 0.45 × radius_dp × density`，22 / 0.45 ≈ 48.9 → 49dp。
 * - **曲线 0.5**：Flutter 的强度分布是 `easeInSine(1 - t)`（1/3 处 50%、1/2 处 29%）；
 *   miuix 的强度是 `1 - smoothstep(t)^curve`，curve = 0.5 时约为 1/3 处 49%、
 *   1/2 处 29%（误差 < 1 个百分点）。官方 demo 的 2.2 是「前重后轻」的陡降，
 *   不对应产品原版。
 * - **叠色**：Flutter 是**独立**的一层线性 scrim（不跟模糊曲线收）：浅色 white@0.70、
 *   深色 #565656@0.475（`hyperos_blurred_header.dart` 的 `_frostedScrimColor`）。
 *   所以这里用 `onDrawSurface` 另画，不塞进 `BlurColors`——后者会被 ramp 一起调制，
 *   中段会比原版淡。
 *
 * 改这里必须同步 `TopBarProgressiveBlurGuardTest`（数字与接线都被它钉住）。
 */
internal object QingyuTopBarBlur {
    /** 顶边满强度处的半径（dp）。 */
    const val MaxRadiusDp = 49f

    /** miuix 幂曲线，复现 Flutter 的 `easeInSine(1 - t)`。 */
    const val Curve = 0.5f

    /** 浅色叠色：纯白 70%。 */
    const val LightTintAlpha = 0.70f

    /** 深色叠色：中性灰 #565656，alpha 按 `sheetTintAlpha` 换算后为 0.475。 */
    const val DarkTintArgb = 0xFF565656
    const val DarkTintAlpha = 0.475f
}

private val QingyuTopBarGradient: ProgressiveBlur =
    ProgressiveBlur.Top.copy(curve = QingyuTopBarBlur.Curve)

private fun qingyuTopBarTint(dark: Boolean): Color =
    if (dark) {
        Color(QingyuTopBarBlur.DarkTintArgb).copy(alpha = QingyuTopBarBlur.DarkTintAlpha)
    } else {
        Color.White.copy(alpha = QingyuTopBarBlur.LightTintAlpha)
    }

/**
 * 顶栏渐进模糊：官方 `BlurredBar` 的等价物（`PageUtils.kt:126-168`），但接的是官方
 * **渐进档**（`drawBackdrop(progressiveGradient = …) + progressiveTextureBlurEffect`）。
 *
 * 渐变自顶边满强度（[QingyuTopBarBlur.MaxRadiusDp]）向下连续衰减，到顶栏盒底正好为 0，
 * 所以顶栏与正文交界处没有一条硬边；叠色是另一层线性 scrim（见 [QingyuTopBarBlur]），
 * 也一并淡到透明。
 *
 * ⚠️ `progressiveGradient` 不能漏传：漏了会让 draw 路径**静默**退回单级均匀模糊
 * （不报错，只是清晰端不再真正锐利）。它和 effects 里的 `gradient` 应当用同一份，
 * 否则两套口径会漂——实际驱动 ramp 的是 `progressiveGradient` 这一份。
 *
 * [backdrop] 为 null 时退化成普通 `Box`，与改动前的布局完全一致。
 */
@Composable
private fun QingyuBlurredTopBar(
    backdrop: LayerBackdrop?,
    dark: Boolean,
    content: @Composable () -> Unit,
) {
    Box {
        if (backdrop != null) {
            val tint = qingyuTopBarTint(dark)
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .drawBackdrop(
                        backdrop = backdrop,
                        shape = { RectangleShape },
                        effects = {
                            progressiveTextureBlurEffect(
                                blurRadiusX = QingyuTopBarBlur.MaxRadiusDp,
                                gradient = QingyuTopBarGradient,
                                // 叠色单独画（见 [QingyuTopBarBlur]），这里不留混合层。
                                colors = BlurColors(),
                            )
                        },
                        progressiveGradient = QingyuTopBarGradient,
                        onDrawSurface = {
                            drawRect(
                                brush = Brush.verticalGradient(
                                    colors = listOf(tint, tint.copy(alpha = 0f)),
                                ),
                            )
                        },
                    ),
            )
        }
        content()
    }
}

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
