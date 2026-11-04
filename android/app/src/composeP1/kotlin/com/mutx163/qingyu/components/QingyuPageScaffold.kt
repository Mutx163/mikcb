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
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.CommonUiStrings
import com.mutx163.qingyu.components.glass.LocalQingyuPageBackdrop
import com.mutx163.qingyu.components.glass.QingyuGlassSurface
import com.mutx163.qingyu.core.GlassSpec
import com.mutx163.qingyu.core.GlassSpecResolver
import com.mutx163.qingyu.core.GlassTuning
import com.mutx163.qingyu.core.TopBarGlassBand
import com.mutx163.qingyu.pages.shell.ShellRootEntryRule
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.SmallTopAppBar
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.basic.TopAppBarDefaults
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.blur.ProgressiveBlur
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronBackward

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
            imageVector = MiuixIcons.ChevronBackward,
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

/**
 * 「顶栏该不该画返回键」的**唯一取法**（组合局部判据，2026-11-03）。
 *
 * 壳注入的根页标记（[LocalQingyuPageIsRootEntry]）经 [ShellRootEntryRule.shouldShowBackButton]
 * 收敛成一个布尔。消费者两类：[QingyuPageScaffold]（全站骨架）与**手拼顶栏的少数页面**
 * （任务清单 / 日程列表 / 课程总览 / 局域网传输——它们不走骨架，但取法必须同这一处，
 * 守卫 `RootEntryBackGuardTest` 钉住「谁再自己读 local 另判一套 → 红」）。
 */
@Composable
fun rememberShellShouldShowBackButton(): Boolean =
    ShellRootEntryRule.shouldShowBackButton(LocalQingyuPageIsRootEntry.current)

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
    /**
     * 是否给「页面内容」挂顶栏毛玻璃的实时采样层（`Modifier.layerBackdrop`）。
     *
     * 含 **WebView / 视频 / 相机等自绘控件** 的页面必须传 `false`：这些控件被录进实时
     * backdrop 层、随顶栏模糊逐帧重录时会出现**持续闪烁/重绘**（教务导入 WebView 实测）。
     * 关掉后顶栏退化为不透明页底色（无实时模糊），页面其余部分不受影响。
     * 默认 `true`，与既有页面观感完全一致。
     */
    enableTopBarBlur: Boolean = true,
    content: @Composable QingyuPageContentScope.() -> Unit,
) {
    val dark = isSystemInDarkTheme()
    // 每个页面实例一个折叠状态：返回后重新进入应从展开态开始。
    val scrollBehavior = MiuixScrollBehavior()
    // 返回键显隐的唯一判定（2026-11-03）：从底栏进入的根页没有上一级可回，不画返回键；
    // 推入的二级/更深页照常画。壳在 entry 分支注入页面栈的真实结构，这里一处消费——
    // 页面零传参，51 处调用点全站生效；取法本体在 rememberShellShouldShowBackButton
    // （手拼顶栏页与骨架共用同一份），纯函数在 ShellRootEntryRule（JVM 单测钉住）。
    val showBackButton = rememberShellShouldShowBackButton()
    // 顶栏与页面底色必须同源：模糊层靠它铺底，否则内容里的透明区
    // 会在大标题下糊出色块（`docs/guide/blur.md:105-118`）。
    val pageBackground = Color(QingyuTheme.scaffoldBackground(dark))
    val backdrop = rememberQingyuBlurBackdrop(pageBackground, enabled = enableTopBarBlur)
    val barColor = if (backdrop != null) Color.Transparent else pageBackground
    // 宽屏三档取值：页面显式传入的 maxContentWidth 优先，缺省时中宽/宽档用 640dp 默认值。
    val adaptive = rememberQingyuWindowAdaptive()
    val cap = maxContentWidth ?: adaptive.maxContentWidth
    Scaffold(
        containerColor = pageBackground,
        topBar = {
            QingyuBlurredTopBar(
                backdrop = backdrop,
                dark = dark,
                pageBackground = pageBackground,
                scrollBehavior = scrollBehavior,
                // 只有走大标题 TopAppBar 的分支可折叠（小标题 / 宽屏档不可折叠）。
                collapsible = !smallTopBar && !adaptive.isWideScreen,
            ) {
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
                    // 弹窗材质（本地 fork 的 DialogContentLayout 玻璃分支）与顶栏共用这条录像带
                    // 采样页面内容，不另录第二份图层；backdrop 为 null 时消费方自动降级实心。
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

    /** 浅色叠色：纯白（#FFFFFF），与深色叠色成对命名（2026-11-04 顶栏固定 tint 收口）。 */
    const val LightTintArgb = 0xFFFFFFFF

    /** 浅色叠色 alpha：纯白 70%。 */
    const val LightTintAlpha = 0.70f

    /** 深色叠色：中性灰 #565656，alpha 按 `sheetTintAlpha` 换算后为 0.475。 */
    const val DarkTintArgb = 0xFF565656
    const val DarkTintAlpha = 0.475f
}

private val QingyuTopBarGradient: ProgressiveBlur =
    ProgressiveBlur.Top.copy(curve = QingyuTopBarBlur.Curve)

/**
 * 顶栏带的固定玻璃口径（不读用户设置，与 Flutter 原版锁死的那一档一致）。
 *
 * 走统一 spec 解析：同一份 [GlassTuning] 在任何表面都得到同一份 [GlassSpec]，
 * 顶栏只是「旋钮值固定」而不是「另一套实现」。
 * 叠色由 `onDrawSurface` 单独画，所以这里 `tintAlpha = 0`；顶栏不做折射、不做高光。
 */
private val QingyuTopBarGlassSpec: GlassSpec = GlassSpecResolver.resolve(
    GlassTuning(
        blurSigmaDp = QingyuTopBarBlur.MaxRadiusDp,
        tintAlpha = 0f,
        vibrancy = 1f,
        rimStrength = 0f,
        rimWidthDp = 0f,
        refractionBandDp = 0f,
        refractionAmountDp = 0f,
        dispersion = 0f,
    ),
)

private fun qingyuTopBarTint(dark: Boolean): Color =
    if (dark) {
        Color(QingyuTopBarBlur.DarkTintArgb).copy(alpha = QingyuTopBarBlur.DarkTintAlpha)
    } else {
        Color(QingyuTopBarBlur.LightTintArgb).copy(alpha = QingyuTopBarBlur.LightTintAlpha)
    }

/**
 * 顶栏叠色 scrim 的**新形态**（2026-11-04 P1）：带内基本均匀、只在底部短渐隐。
 *
 * 旧形态从顶到底**整段线性**淡到透明，中段偏薄、与 Flutter 原版「一层独立线性纱」的
 * 观感有差。现在改成「前 ~62% 保持满浓度、末段 ~38% 收到透明」：带内读起来基本均匀，
 * 到正文交界处才柔和收尾——配合下沿 [TopBarBlurOverhang] 让这条渐隐尾巴落进正文顶部空隙，
 * 交界无硬边。
 *
 * 颜色口径不变：浅 White@0.70 / 深 #565656@0.475（`TopBarProgressiveBlurGuardTest` 钉死）。
 */
private fun qingyuTopBarScrim(dark: Boolean): Brush {
    val tint = qingyuTopBarTint(dark)
    return Brush.verticalGradient(
        0.0f to tint,
        0.62f to tint,
        1.0f to tint.copy(alpha = 0f),
    )
}

/**
 * 顶栏模糊下沿**向下多画**的高度上限（只向下画、不改布局高）。
 *
 * Flutter 的 `subpageBandBottomOverhang` 请求 20dp，被「大标题内容间距」封顶；这里取
 * `min(20dp, 大标题底部留白)`——本仓 miuix 该留白是 `TopAppBarDefaults.LargeTitleBottomPadding`
 * （4dp），所以实际外推 4dp，落在正文顶部那段设计留白里，不会真正盖住内容。
 */
private val TopBarBlurOverhang: Dp = minOf(20.dp, TopAppBarDefaults.LargeTitleBottomPadding)

/**
 * 顶栏与正文之间的**设计间距**（标题 → 正文），8dp。
 *
 * 对齐 Flutter 发布版：`HyperosMiuixTopAppBar.largeTitleContentGap = 8`，Dart 的
 * `HyperosBlurredHeader.contentTopInset` 把它算进 body 顶部 inset（`safeTop + 头栏 + gap`），
 * 小标题页另加 `_headerPaddingBottom = 4`。Compose 此前只把「栏体高度」报给 Scaffold，
 * 少了这段 ⇒ 首个 item 贴着（半透明）顶栏下沿、像顶进标题栏（用户 2026-11-04 实报）。
 *
 * 做法：让顶栏 Layout 的高度多报这一段（透明留白，模糊带尾巴落进来），Scaffold 的
 * `innerPadding.top` 随之为「栏体 + 间距」，所有页内容第一项自动落在顶栏下方；
 * 滚动时列表照旧从顶栏下穿过（边缘到边缘效果不变）。
 */
private val TopBarContentGap: Dp = 8.dp

/** 小标题（不可折叠）栏的「标题→正文」间距，4dp（Dart `_headerPaddingBottom = 4`）。 */
private val TopBarContentGapSmall: Dp = 4.dp

/** 可折叠大标题栏「内容已压到带下」的滚动判据（px）：`heightOffset < -该值` 即视为压带。 */
private const val UnderHeaderScrollEpsilonPx = 0.5f

/**
 * 顶栏渐进模糊：官方 `BlurredBar` 的等价物（`PageUtils.kt:126-168`），接官方**渐进档**，
 * 渲染走全站唯一实现 [QingyuGlassSurface]。
 *
 * ## 尺寸恒定（2026-11-04 P0，根除抖动 / 闪）
 *
 * 大标题 [TopAppBar] 的高度 = 常量高度 - `heightOffset`，`heightOffset` 由滚动逐帧写入。
 * 旧实现让模糊层跟顶栏同高，尺寸每帧变 ⇒ `progressiveTextureBlurEffect` 每次重建
 * RenderEffect、合成层重新分配纹理，真机读成「糊的东西一直在颤」。
 *
 * 现在模糊层只认**展开高度**（[TopBarGlassBand] 单档化）：展开高度只由首次测量确定、
 * 不随滚动变。`expandedHeightPx` 用**单调取大**缓存——只在高度变大时写一次状态，滚动收起
 * 时不再写、不再逐帧重组；`bandHeightPx` 用 `remember(expandedHeightPx)` 缓存成稳定 Int，
 * Layout 读它不会在滚动中被反复 invalidate。外层只按**真实栏高**做裁剪，裁剪在 draw 期
 * 发生、每帧变但**不触发模糊层重建**。
 *
 * ## 下沿 overhang（2026-11-04 P1）
 *
 * 模糊层向下多量 [TopBarBlurOverhang]（= min(20dp, 大标题内容间距)），把「底边归 0」的渐隐
 * 尾巴画进正文顶部空隙，交界处不留硬边。**只向下画、不改布局高**：Layout 仍报真实栏高、
 * 不挤正文，只把外层裁剪矩形下边界放宽 `overhang`，多出的尾巴落在正文顶部设计留白里。
 *
 * ## opaqueAtRest（2026-11-04 P1）
 *
 * Flutter 在「没有内容压到带下」时用**不透明页底色**衬底，内容滚上来才切玻璃纱。这里用
 * `state.heightOffset < 0`（可折叠栏一旦滚动）作压带信号：静止时 `onDrawSurface` 直接铺
 * 不透明 `pageBackground`，压带后切 [qingyuTopBarScrim]。**不可折叠栏**（骨架传入
 * `collapsible=false`，即小标题 / 宽屏档）永远保持常驻玻璃纱，避免回归。
 *
 * [backdrop] 为 null 时退化成普通 `Box`，与改动前的布局完全一致。
 */
@Composable
private fun QingyuBlurredTopBar(
    backdrop: LayerBackdrop?,
    dark: Boolean,
    pageBackground: Color,
    scrollBehavior: ScrollBehavior?,
    collapsible: Boolean,
    content: @Composable () -> Unit,
) {
    val state = scrollBehavior?.state
    // 展开高度只在「变大」时写一次（单调取大）：滚动收起不再写状态 → 不逐帧重组、尺寸恒定。
    var expandedHeightPx by remember { mutableIntStateOf(0) }
    // 模糊带高度只随 expandedHeightPx 变（几乎只算一次），remember 成稳定 Int：
    // 滚动中 Layout 读它不会反复 invalidate，模糊层尺寸不变。
    val bandHeightPx = remember(expandedHeightPx) {
        if (expandedHeightPx <= 0) {
            0
        } else {
            TopBarGlassBand.resolveBandHeightPx(
                currentHeightPx = expandedHeightPx.toFloat(),
                heightOffsetPx = 0f,
                heightOffsetLimitPx = 0f,
            )
        }
    }
    // 是否「内容已压到带下」：可折叠大标题栏滚动后 heightOffset<0 即视为压带。
    // 骨架已通过 [collapsible] 告知本栏是否可折叠（走大标题 TopAppBar）；不可折叠的小标题 /
    // 宽屏分支永远保持玻璃纱，避免回归。`heightOffset` 是 snapshot 状态，派生状态只在翻转时通知。
    val underHeader by remember(state, collapsible) {
        derivedStateOf {
            if (!collapsible || state == null) {
                true
            } else {
                state.heightOffset < -UnderHeaderScrollEpsilonPx
            }
        }
    }
    val overhangPx = with(LocalDensity.current) { TopBarBlurOverhang.toPx() }
    // 顶栏下方「标题→正文」设计间距（见 [TopBarContentGap]）：算进本栏 Layout 高度，
    // 让 Scaffold 的 innerPadding.top 把这段一起让给内容，首个 item 不贴顶栏。
    // 可折叠大标题 8dp、小标题 4dp，与 Flutter 发布版一致。
    val contentGapPx = with(LocalDensity.current) {
        (if (collapsible) TopBarContentGap else TopBarContentGapSmall).roundToPx()
    }
    // scrim 只在 dark 变化时重建一次，不在 draw 期每帧新建 Brush（避免滚动期 GC 抖动）。
    val scrimBrush = remember(dark) { qingyuTopBarScrim(dark) }
    Layout(
        content = {
            if (backdrop != null) {
                QingyuGlassSurface(
                    backdrop = backdrop,
                    spec = QingyuTopBarGlassSpec,
                    shape = RectangleShape,
                    progressive = QingyuTopBarGradient,
                    onDrawSurface = {
                        if (underHeader) {
                            drawRect(brush = scrimBrush)
                        } else {
                            // opaqueAtRest：无内容压带时铺不透明页底色（静止即实底）。
                            drawRect(color = pageBackground)
                        }
                    },
                )
            }
            Box(
                Modifier.onSizeChanged {
                    // 单调取大：只记录最大（展开）高度，滚动收起时不更新，避免逐帧写状态。
                    if (it.height > expandedHeightPx) expandedHeightPx = it.height
                },
            ) { content() }
        },
        modifier = Modifier.drawWithContent {
            // 裁剪下边界放宽 overhang：模糊层可向下多画一点（渐隐尾巴落进正文顶部空隙），
            // 但 Layout 报的高度仍是真实栏高 —— 不挤正文。
            clipRect(
                left = 0f,
                top = 0f,
                right = size.width,
                bottom = size.height + overhangPx,
            ) {
                this@drawWithContent.drawContent()
            }
        },
    ) { measurables, constraints ->
        val contentPlaceable = measurables.last().measure(constraints)
        val width = contentPlaceable.width.coerceAtLeast(constraints.minWidth)
        val height = contentPlaceable.height
        val blurPlaceable = if (backdrop != null && bandHeightPx > 0) {
            // 玻璃/模糊面高度要对齐到**真实底边**（栏体 + 标题→正文间距 = 本 Layout 底边 = 内容起点），
            // 这样 ProgressiveBlur 的零强度点（endFraction=1，映射到本面投影高度）正好落在内容起始处，
            // 底部平滑渐隐到 0；若仍只量到「栏体 + overhang」，零强度边会在内容上方留下一段错位带，
            // 表现为一条硬分界线（且滑动时副本与实时内容错位 → 闪）。见 TopBarContentGap。
            measurables.first().measure(Constraints.fixed(width, bandHeightPx + contentGapPx))
        } else {
            null
        }
        layout(width, height + contentGapPx) {
            blurPlaceable?.place(0, 0)
            contentPlaceable.place(0, 0)
        }
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
private fun rememberQingyuBlurBackdrop(pageBackground: Color, enabled: Boolean = true): LayerBackdrop? {
    // 关闭实时采样层（含 WebView/视频等自绘控件的页面走这条）：返回 null ⇒ 不挂
    // `layerBackdrop`、不逐帧重录内容，顶栏按不透明页底色绘制。
    if (!enabled) return null
    if (!isRuntimeShaderSupported() || !ValueAnimator.areAnimatorsEnabled()) return null
    return rememberLayerBackdrop {
        drawRect(pageBackground)
        drawContent()
    }
}
