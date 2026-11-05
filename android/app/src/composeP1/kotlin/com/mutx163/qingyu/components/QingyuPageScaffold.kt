package com.mutx163.qingyu.components

import android.animation.ValueAnimator
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
/** 顶栏/图标按钮的玻璃口径：小圆钮用薄磨砂，不做折射/高光（对齐发布版 `maxRefraction = 0`）。 */
private val QingyuChromeGlassSpec: GlassSpec = GlassSpecResolver.resolve(
    GlassTuning(
        blurSigmaDp = 18f,
        tintAlpha = 0f,
        vibrancy = 1.15f,
        rimStrength = 0f,
        rimWidthDp = 0f,
        refractionBandDp = 0f,
        refractionAmountDp = 0f,
        dispersion = 0f,
    ),
)

/**
 * 顶栏图标按钮（**左上返回键 + 右上动作键**）的唯一实现：门控玻璃圆底。
 *
 * ## 门控：只在「内容压到顶栏带下面」时出现（与发布版返回键同一条口径）
 *
 * 圆底的显隐由 [LocalQingyuBackButtonGlass] 一处决定——[QingyuPageScaffold] 用
 * [isContentUnderTopBar] 算一次后注入顶栏子树。**静止停在页顶时是裸图标**，内容压到
 * 顶栏带下面才长出圆底；这正是发布版 `HyperosBackButton` 的行为（光箭头 → 压带 → 圆底）。
 * 未注入的场合（手拼 `TopAppBar` 的页、独立预览）默认 `false`，同样画裸图标 —— 那些页本来
 * 也没有实时采样源，左边返回键与右边动作键形态一致，不会出现「一边有圆底一边没有」。
 *
 * ## 圆底长相（出现时）
 *
 * 44×44 圆底 + 磨砂玻璃 + 0.75dp 细边 + 小外浮影，深浅色都用亮白纱低 alpha：
 * 发布版 `HyperosBackButton` 的液态玻璃标准档圆底 + `HyperosGlassShadow.compactShadow`
 * （blur≈4 / offset≈1.5 的外浮影）。用共享玻璃件 + Compose 小阴影等价实现，没有自研动画。
 * 无实时玻璃能力（`backdrop == null` / 关模糊）时退化成同色半透明实底圆，观感一致。
 *
 * 2026-11-05 全站收口：返回键 [QingyuBackIconButton] 与各页 `actions` 槽里的右上动作键
 * **都走这一个实现**，槽里不许再裸写 `IconButton`（守卫 `TopBarActionGlassGuardTest`）。
 *
 * ## 无障碍：文案只念一次，且必须写进 `IconButton` 调用块
 *
 * 标签落在**按钮节点**上——`IconButton` 自己的 modifier 里 `.semantics { this.contentDescription = … }`，
 * 里面的 `Icon` 传 `null`，所以读屏只念一遍。因此 [contentDescription] 是必填参数、没有默认值。
 * `AccessibilitySemanticsGuardTest` 只读 `IconButton(...) { … }` 的调用块原文，那句语义**不能挪到
 * 外部 `val` 再传进来**，否则守卫看不到、判成「无标签纯图标按钮」。
 */
@Composable
fun QingyuGlassIconButton(
    onClick: () -> Unit,
    /** 读屏念的那句话。**必填、没有默认值**：纯图标按钮的标签只能由调用方给。 */
    contentDescription: String,
    icon: ImageVector,
    tint: Color? = null,
    modifier: Modifier = Modifier,
    /** 禁用态（例如「没有数据时不可导出」）：透传给官方 [IconButton]，只掐点击、不改配色。 */
    enabled: Boolean = true,
    /**
     * 自定义内容槽：加载中 / 导出中要在按钮里换成转圈时用。给了它就替代 [icon] 的绘制，
     * 无障碍文案仍取 [contentDescription]。
     */
    content: (@Composable () -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    val iconTint = tint ?: Color(QingyuTheme.actionIcon(dark))
    // 取成局部 val：下面在 lambda 里用，避免依赖「参数跨 lambda 智能转型」这种细节。
    val slot = content
    // 无障碍文案**落在按钮节点上**：两个分支的 `IconButton(...)` 都把
    // `.semantics { this.contentDescription = label }` 写在它自己的 modifier 里，图标则传 `null`
    // ——读屏只念一次（写在按钮上、图标不再重复一份），`AccessibilitySemanticsGuardTest`
    // 也能在 `IconButton` 调用块原文里直接看到这句标签（守卫只读调用块，不接受外部 `val` 传参）。
    val label = contentDescription
    // 按钮内容（图标或加载转圈）：圆底分支与裸图标分支共用同一份，形态不会分叉。
    val inner: @Composable () -> Unit = {
        if (slot != null) {
            slot()
        } else {
            Icon(
                imageVector = icon,
                // 文案已在按钮节点上，图标这里必须是 null，否则读屏念两遍。
                contentDescription = null,
                tint = iconTint,
            )
        }
    }
    // 门控：与返回键读同一个信号。静止在页顶 / 未注入 ⇒ 裸图标（就是收口前各页原样）。
    if (!LocalQingyuBackButtonGlass.current) {
        IconButton(
            onClick = onClick,
            enabled = enabled,
            // 调用方的 `modifier` 必须透传：裸图标分支是**默认态**（未注入门控 / 静止在页顶），
            // 丢掉它会让「靠 modifier 测量/占位」的调用方（如课程总览排序键的
            // `onGloballyPositioned`）静默失效——弹层锚点测不到，只能退到窗口右上角。
            modifier = modifier.semantics { this.contentDescription = label },
        ) { inner() }
        return
    }
    val backdrop = LocalQingyuPageBackdrop.current
    val veil = Color.White.copy(alpha = if (dark) 0.16f else 0.42f)
    val borderColor = Color.White.copy(alpha = if (dark) 0.18f else 0.55f)
    Box(
        modifier = modifier
            .size(44.dp)
            .shadow(elevation = 2.dp, shape = CircleShape, clip = false)
            .clip(CircleShape)
            .border(width = 0.75.dp, color = borderColor, shape = CircleShape),
    ) {
        val button: @Composable () -> Unit = {
            IconButton(
                onClick = onClick,
                enabled = enabled,
                modifier = Modifier
                    .fillMaxSize()
                    // 与裸图标分支同一句标签：文案在按钮节点上（读屏只念一次）。
                    .semantics { this.contentDescription = label },
            ) { inner() }
        }
        if (backdrop != null) {
            QingyuGlassSurface(
                backdrop = backdrop,
                spec = QingyuChromeGlassSpec,
                modifier = Modifier.fillMaxSize(),
                shape = CircleShape,
                tintBrush = SolidColor(veil),
                content = button,
            )
        } else {
            Box(modifier = Modifier.fillMaxSize().background(veil, CircleShape)) { button() }
        }
    }
}

/**
 * 顶栏图标按钮「圆底该不该出现」的**唯一门控**：内容是否已压到顶栏带下面。
 *
 * 发布版只有压带后才给圆底（静止是裸图标），左上返回键与右上动作键**共用这一个信号**：
 * 骨架在顶栏子树注入；不注入（手拼 `TopAppBar` 的页 / 独立预览）默认 `false` = 裸图标。
 *
 * 名字里的 `BackButton` 是历史名（守卫与既有调用点依赖字符串，未改名），语义已扩到
 * 整个顶栏 chrome。
 */
internal val LocalQingyuBackButtonGlass = staticCompositionLocalOf { false }

/**
 * 全站统一的「子页返回键」——就是 [QingyuGlassIconButton] 的一层薄封装（图标写死为
 * [MiuixIcons.ChevronBackward]、文案默认「返回」）。
 *
 * 门控在 [QingyuGlassIconButton] 里，所以这里不再自己判显隐：静止是裸箭头、压带后长出圆底，
 * 与右上动作键逐帧同步。
 */
@Composable
fun QingyuBackIconButton(
    onBack: () -> Unit,
    contentDescription: String = CommonUiStrings.back,
    tint: Color? = null,
) {
    QingyuGlassIconButton(
        onClick = onBack,
        contentDescription = contentDescription,
        icon = MiuixIcons.ChevronBackward,
        tint = tint,
    )
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
 * 3. [QingyuBlurredTopBar] 用共享玻璃件 `QingyuGlassSurface` 把**单档均匀磨砂**面垫在顶栏下，
 *    再叠一层两段线性白纱（顶浓 → 带底透明），同时顶栏底色改成 `Color.Transparent`。
 *
 * 三步缺一：只有 3 会采样到空气（黑/透明），只有 2 则毫无视觉变化。
 *
 * 2026-11-04 换方案：发布版 v2.1.4.1 的 `InspireHeaderBlur` 是一次变量模糊 + 两段线性白纱；
 * 旧的 miuix 多级渐进 stack（逐点弧度 + 锐化 overlay + dither）层数多、每帧重建多，读起来有
 * 一层层叠出来的廉价带且滑动发闪。现改为更稳更通透的「单档均匀磨砂 + 两段线性白纱」，
 * 模糊粗细仍对齐发布版 σ≈22。参数见 [QingyuTopBarBlur]。
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
    // 发布版口径：返回键的玻璃圆底只在「内容已压到顶栏带下面」时出现，停在页顶是光箭头。
    // 判据按栏型取量（见 [isContentUnderTopBar]）：可折叠大标题看 heightOffset（位置量），
    // 钉住的单行栏恒为 true（保留统一前的静止观感，别改成看滚动量）。
    val collapsibleTopBar = !smallTopBar && !adaptive.isWideScreen
    // 「内容已压到顶栏带下」**只算这一次**：顶栏的「实底 ↔ 玻璃纱」切换与返回键的玻璃圆底
    // 共用同一个信号（2026-11-05 修）。此前骨架看 `contentOffset`、顶栏内部看 `heightOffset`，
    // 两套信号会在同一帧给出相反答案 —— 用户看到的是「顶栏已经变实底了，返回键还挂着一圈
    // 玻璃圆底」。现在两边都读它；判据本体在 [isContentUnderTopBar]。
    val contentUnderHeader by remember(scrollBehavior, collapsibleTopBar) {
        derivedStateOf { isContentUnderTopBar(scrollBehavior, collapsibleTopBar) }
    }
    Scaffold(
        containerColor = pageBackground,
        topBar = {
            CompositionLocalProvider(
                // 返回键玻璃需要采样源（顶栏子树不在正文那层 CompositionLocalProvider 里，这里补一份）。
                LocalQingyuPageBackdrop provides backdrop,
                LocalQingyuBackButtonGlass provides contentUnderHeader,
            ) {
                QingyuBlurredTopBar(
                    backdrop = backdrop,
                    dark = dark,
                    pageBackground = pageBackground,
                    // 只有走大标题 TopAppBar 的分支可折叠（小标题 / 宽屏档不可折叠）。
                    collapsible = collapsibleTopBar,
                    // 同一个「压带」信号（见上方 contentUnderHeader）：顶栏据此切实底 / 玻璃纱。
                    underHeader = contentUnderHeader,
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
                                    // 必须把 scrollBehavior 传进来：官方 SmallTopAppBar 在
                                    // SideEffect 里把 heightOffsetLimit 钉成 0（固定不折叠）；
                                    // 不传的话它保持默认 -Float.MAX，onPreScroll 会整段吞掉一个
                                    // 方向的滚动 ⇒ 小标题页接上列表后变成「只能单向滚」。
                                    scrollBehavior = scrollBehavior,
                                )
                            }
                            adaptive.isWideScreen -> {
                                SmallTopAppBar(
                                    title = title,
                                    color = barColor,
                                    navigationIcon = backIconOrNull(showBackButton, onBack),
                                    actions = actions,
                                    // 宽屏档同样走 SmallTopAppBar，同样要钉 0，否则宽屏列表也只会单向滚。
                                    scrollBehavior = scrollBehavior,
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
 * 子页顶栏玻璃参数（2026-11-04 换方案：**单档均匀磨砂 + 两段线性白纱**）。
 *
 * ## 为什么换
 *
 * 旧实现走 miuix「多级渐进 stack + 锐化 overlay + dither」：层数多、每帧重建多，读起来有
 * 一层层叠出来的廉价带、滑动还会逐帧重糊发闪。发布版 v2.1.4.1（`InspireHeaderBlur`）是
 * **一次变量模糊** + 两段线性白纱（`tintGradient`：`[tint → transparent]`）+ 带底收 0。
 * 这里换成更稳更通透的等价做法：单档均匀高斯磨砂 + 两段线性白纱。
 *
 * ## 数值
 * - **半径 49dp**：miuix `sigma_px = 0.45 × radius_dp × density`，49 → σ≈22，对齐发布版
 *   `progressiveSigma = 22`（粗细一致，只是不再逐点渐进）。
 * - **白纱两段线性**：顶边满浓度 → 带底全透明（发布版 `tintGradient(bottomScale=0)`）。
 *   旧「前 62% 满浓度、末段才收」大半条是实心白板，显廉价，已废。
 * - **浅 white@0.62 / 暗色亮 white@0.24**：暗色必须用**亮 veil**（用灰 `#565656` 压在暗底上
 *   会发灰、读成脏/透明），对齐发布版 `_frostedScrimColor` 暗色 0.16~0.30 档。
 *
 * 改这里必须同步 `TopBarProgressiveBlurGuardTest`（新方案实质被它钉住）。
 */
internal object QingyuTopBarBlur {
    /** 单档模糊半径（dp），σ≈22 对齐发布版 progressiveSigma。 */
    const val MaxRadiusDp = 49f

    /** 浅色白纱 alpha（顶边满浓度，线性淡到带底 0）。 */
    const val LightTintAlpha = 0.62f

    /** 暗色**亮白纱** alpha（暗底上用亮 veil 才有对比）。 */
    const val DarkVeilAlpha = 0.24f
}

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
    Color.White.copy(
        alpha = if (dark) QingyuTopBarBlur.DarkVeilAlpha else QingyuTopBarBlur.LightTintAlpha,
    )

/**
 * 顶栏白纱（2026-11-04 换方案）：**两段纯线性 `[顶边 tint → 带底 transparent]`**。
 *
 * 发布版 `InspireHeaderBlur.tintGradient(bottomScale=0)` 就是两段线性；旧的
 * 「0→62% 满浓度、末段才收」大半条是实心白纱，读成一块廉价白板，已废。
 * 带底全透明 → 与下方清晰内容交界处不会切出横向硬边（配合下沿对齐内容起点）。
 */
private fun qingyuTopBarScrim(dark: Boolean): Brush {
    val tint = qingyuTopBarTint(dark)
    return Brush.verticalGradient(
        0.0f to tint,
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
 * 「内容已压到顶栏带下」的**唯一判据**（2026-11-05 统一；顶栏实底/玻璃纱与返回键玻璃共用）。
 *
 * ## 判据按栏型取量
 *
 * - **钉住的单行栏**（`smallTopBar` / 宽屏档）：**恒为玻璃纱**（返回 `true`）。这是统一前的
 *   顶栏内部判据（`if (!collapsible || state == null) true`）逐字保留——钉住栏的 `heightOffset`
 *   永远被 `SmallTopAppBar` 钉成 0，位置量给不出「压没压带」，而 `contentOffset` 只在滚动里
 *   才为负，拿它判会让静止态从「常白纱磨砂」掉成「平页底色」（2026-11-05 复核：这正是
 *   小标题页 / 宽屏档的观感回归，改法 = 保留旧语义，只统一「谁读这个值」）。
 * - **可折叠大标题栏**（`collapsible = true`）：看 `state.heightOffset`——它是**位置量**
 *   （0 = 完全展开 = 停在页顶），滚动收起时由 miuix 逐帧写入，回到顶部时被同一状态机夹回 0。
 *   于是「已到顶 ⇒ 自动关玻璃」是结构性成立的，不依赖任何额外判断。
 *   `heightOffsetLimit == 0` 表示大标题还没量出高度（首帧 / 标题为空），此时位置量恒 0 不可用，
 *   退回累积滚动量 `state.contentOffset`（≈ 列表滚动位移）——静止时它同样是 0，不会误开玻璃。
 *
 * ## 与返回键玻璃的关系
 *
 * 骨架算一次、经 `LocalQingyuBackButtonGlass` 下发给返回键，同时作为 `underHeader` 传给
 * [QingyuBlurredTopBar]。两处读**同一个值**，不会再出现「顶栏已经实底、返回键还挂着玻璃圆底」。
 */
private fun isContentUnderTopBar(
    scrollBehavior: ScrollBehavior,
    collapsible: Boolean,
): Boolean {
    // 钉住栏恒常驻玻璃纱（见上方注释：保留统一前的口径，不改静止观感）。
    if (!collapsible) return true
    val state = scrollBehavior.state
    if (state.heightOffsetLimit == 0f) {
        // 大标题还没量出高度：位置量不可用，退回累积滚动量。
        return state.contentOffset < -UnderHeaderScrollEpsilonPx
    }
    return state.heightOffset < -UnderHeaderScrollEpsilonPx
}

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
 * ## opaqueAtRest（2026-11-04 P1 / 2026-11-05 判据统一）
 *
 * Flutter 在「没有内容压到带下」时用**不透明页底色**衬底，内容滚上来才切玻璃纱。压带信号由
 * 骨架算一次（[isContentUnderTopBar]）后传进来：静止时 `onDrawSurface` 直接铺不透明
 * `pageBackground`，压带后切 [qingyuTopBarScrim]。**返回键的玻璃圆底读的是同一个值**——
 * 两处原先各用一套信号（骨架看 `contentOffset`、本栏看 `heightOffset`），会短暂出现
 * 「顶栏已实底、返回键还挂着玻璃圆底」。
 * **不可折叠栏**（骨架传入 `collapsible=false`，即小标题 / 宽屏档）永远保持常驻玻璃纱，避免回归。
 *
 * [backdrop] 为 null 时退化成普通 `Box`，与改动前的布局完全一致。
 */
@Composable
private fun QingyuBlurredTopBar(
    backdrop: LayerBackdrop?,
    dark: Boolean,
    pageBackground: Color,
    collapsible: Boolean,
    /** 「内容已压到顶栏带下」：骨架算一次（[isContentUnderTopBar]），返回键玻璃读同一份。 */
    underHeader: Boolean,
    content: @Composable () -> Unit,
) {
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
    val overhangPx = with(LocalDensity.current) { TopBarBlurOverhang.toPx() }
    // 顶栏下方「标题→正文」设计间距（见 [TopBarContentGap]）：算进本栏 Layout 高度，
    // 让 Scaffold 的 innerPadding.top 把这段一起让给内容，首个 item 不贴顶栏。
    // 可折叠大标题 8dp、小标题 4dp，与 Flutter 发布版一致。
    val contentGapPx = with(LocalDensity.current) {
        (if (collapsible) TopBarContentGap else TopBarContentGapSmall).roundToPx()
    }
    // scrim 只在 dark 变化时重建一次，不在 draw 期每帧新建 Brush（避免滚动期 GC 抖动）。
    val scrimBrush = remember(dark) { qingyuTopBarScrim(dark) }
    // 带底「渐回页底色」：单档均匀磨砂没有 blur→0 的收尾，若直接与内容交界会留一条模糊硬边。
    // 用最后 ~7%（正好是 TopBarContentGap 那段）由透明渐到页底色，把磨砂影像柔和压回底色。
    val bottomFadeBrush = remember(pageBackground) {
        Brush.verticalGradient(
            0.0f to Color.Transparent,
            0.93f to Color.Transparent,
            1.0f to pageBackground,
        )
    }
    Layout(
        content = {
            if (backdrop != null) {
                QingyuGlassSurface(
                    backdrop = backdrop,
                    spec = QingyuTopBarGlassSpec,
                    shape = RectangleShape,
                    // 单档均匀磨砂：不传渐进档（progressive = null ⇒ QingyuGlassSurface 走单次 blur，
                    // 不再建多级 stack/锐化/dither，薄而稳，治“一层层”的廉价带与逐帧重糊发闪）。
                    progressive = null,
                    onDrawSurface = {
                        if (underHeader) {
                            drawRect(brush = scrimBrush)
                            // 磨砂没有“模糊归零”的收尾：用最后一段渐回页底色压掉与内容的交界硬边。
                            drawRect(brush = bottomFadeBrush)
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
