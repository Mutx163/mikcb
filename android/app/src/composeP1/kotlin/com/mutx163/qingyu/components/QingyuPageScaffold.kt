package com.mutx163.qingyu.components

import android.animation.ValueAnimator
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
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
import androidx.compose.ui.semantics.Role
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
/**
 * 顶栏右上动作键之间的横向间距。
 *
 * miuix 的 `TopAppBar` / `SmallTopAppBar` 只把 actions 包进 `Row(Arrangement.End)`，
 * 子项之间**没有**间距；共享玻璃钮是 44dp 圆底，多颗动作键就会贴成一排。
 * 8dp 与页面里的芯片 / 分组间距同一档，四颗并排时不拥挤、也不挤占标题。
 */
private val TopBarActionGap: Dp = 4.dp

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
 * 无实时玻璃能力（`backdrop == null` / 关模糊）时退化成实底圆：**必须先铺一层不透明页底色，
 * 再叠白纱**。只铺半透明白纱会把圆底下的 2dp 浮影透出来 —— 圆内被压成一块灰盘，边缘那圈
 * 0.75dp 白描边亮在灰盘上，肉眼就是「一大一小两个同心圈」（2026-11-08 版本更新页预览实报）。
 * 版本更新页不走 [QingyuPageScaffold]，本来就没有采样源，真机也走这条退化分支。
 *
 * 2026-11-05 全站收口：返回键 [QingyuBackIconButton] 与各页 `actions` 槽里的右上动作键
 * **都走这一个实现**，槽里不许再裸写 `IconButton`（守卫 `TopBarActionGlassGuardTest`）。
 *
 * ## 无障碍：文案只念一次，且必须写进按钮自己的 modifier 里
 *
 * 标签落在**可点击节点**上（裸图标分支的 `IconButton`、圆底分支的 clickable Box）——各自
 * modifier 里都写 `.semantics { this.contentDescription = … }`，里面的 `Icon` 传 `null`，
 * 所以读屏只念一遍。因此 [contentDescription] 是必填参数、没有默认值。
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
    // 无障碍文案**落在可点击节点上**：两个分支的按钮 modifier 里都写
    // `.semantics { this.contentDescription = label }`，图标则传 `null`
    // ——读屏只念一次（文案在按钮上、图标不再重复一份），且圆底分支的 Box 也保留同一句标签。
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
            // 圆底分支不能再套一颗 miuix `IconButton`：那组件自己带一层圆底（40dp 圆角 squircle
            // + 按压水波圈），与外层玻璃圆底同心叠成**双重圆圈**（2026-11-08 用户实报：更新页
            // 两颗按钮各自"有双重圈圈"）。改成普通可点击 Box + 同一句语义标签，只保留外层
            // 玻璃圆底这一层。裸图标分支仍用官方 `IconButton`（官方 demo 顶栏的用法，静止无圈）。
            val interactionSource = remember { MutableInteractionSource() }
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    // 与裸图标分支同一句标签：文案在可点击节点上（读屏只念一次）。
                    .clickable(
                        enabled = enabled,
                        role = Role.Button,
                        interactionSource = interactionSource,
                        onClick = onClick,
                    )
                    .semantics { this.contentDescription = label },
                contentAlignment = Alignment.Center,
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
            // 退化分支：先铺**不透明**页底色挡掉圆底下的浮影，再叠白纱。
            // 只叠半透明白纱的话，`shadow(2.dp)` 会从圆内透出来（圆内压成灰盘、边缘白描边
            // 反而更亮），一颗钮看着像两个同心圈 —— 2026-11-08 版本更新页预览就是这个。
            val base = Color(QingyuTheme.scaffoldBackground(dark))
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(base, CircleShape)
                    .background(veil, CircleShape),
            ) { button() }
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
 * [MiuixIcons.Back]、文案默认「返回」）。
 *
 * 门控在 [QingyuGlassIconButton] 里，所以这里不再自己判显隐：静止是裸箭头、压带后长出圆底，
 * 与右上动作键逐帧同步。
 *
 * ## 图标为什么是 [MiuixIcons.Back] 而不是 `ChevronBackward`
 *
 * 2026-11-08 用户实报（教务网页导入页）：「左上角的返回键是圆圈内的多边形，很奇怪」。
 * 迁移期用的是 OS4 那颗细尖「‹」(`ChevronBackward`)：它只有约 11dp 宽、转角是直角，
 * 放大到顶标圆底里就不再读作箭头，而是一块多边形色块。换成官方标准返回箭头 `Back`（「←」，
 * 有线杆、宽高比也像箭头）后，圆底里才是一颗读得懂的返回键。**不要再改回 `ChevronBackward`**：
 * 它在本仓的语义是「翻页/展开方向」（月视图、列表行尾箭头），不是导航返回。
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
        icon = MiuixIcons.Back,
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
 * 3. [QingyuBlurredTopBar] 用共享玻璃件 `QingyuGlassSurface` 把**均匀磨砂**面垫在顶栏下（模糊只做一次），
 *    再叠一层**顶部加重的白纱渐变**（顶浓 → 可见底边归 0），顶栏底色改成 `Color.Transparent`。
 *
 * 三步缺一：只有 3 会采样到空气（黑/透明），只有 2 则毫无视觉变化。
 *
 * 2026-11-07 / 11-08 迭代结论（真机依次否掉两种做法，现在的形态是第三种）：
 *
 * - miuix 官方渐进档（多层合成）在真机上只要滚动就闪（半分辨率堆栈 + 全分辨率 overlay 两层
 *   采样错位），且模糊面按展开高度固定、被可见栏高裁在渐变中途 → 底部切一条硬线；
 * - 单次模糊 + 离屏 alpha 掩膜（saveLayer + DstIn）会把玻璃自己一起收没 → 顶部变透明、看不到模糊；
 * - 现在：**模糊只做一次**，纵向权重接在模糊的 RenderEffect 链末端（`runtimeShaderEffect`，
 *   顶边 1 → 可见底边 0），白纱也用正常混合跟着可见栏高一起收到 0 —— 不靠掩膜、底边不硬切。
 *   2026-11-08 修过一版坐标方向写反（权重上下颠倒，可见栏几乎没有模糊）、以及白纱末尾
 *   “先全透、再压回页底色”的两档互揍（就是“长得奇怪”的那条硬边），参数见 [QingyuTopBarBlur]。
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
 * @param enableTopBarBlur 是否给页面内容挂顶栏实时模糊采样层；含 WebView / 视频 / 相机等
 *   自绘控件的页面传 `false`（否则会持续闪烁/重绘）。逐条说明见 [QingyuPageScaffoldBody]。
 */
@Composable
fun QingyuPageScaffold(
    title: String,
    onBack: () -> Unit,
    actions: @Composable RowScope.() -> Unit = {},
    bottomBar: (@Composable () -> Unit)? = null,
    smallTopBar: Boolean = false,
    maxContentWidth: Dp? = null,
    enableTopBarBlur: Boolean = true,
    content: @Composable QingyuPageContentScope.() -> Unit,
) {
    // ⚠️ 主题桥必须罩在**最外层**，把整个 `Scaffold`（顶栏、底栏、内容）都包进来。
    // 两个壳用的是无参 `MiuixTheme { }`（配色恒亮）；只包内容槽的话，miuix 的
    // `TopAppBar` / `SmallTopAppBar` 仍取亮色板 ⇒ 深色下全站约 50 页的顶栏发白。
    //
    // 嵌套安全（本项目既有的前提，仍然成立）：`QingyuPageTheme` 以**外层
    // `LocalQingyuBaseDensity`** 为基准缩放字号，桥套桥不会把倍率乘两次；四个外观形参
    // 的默认值取自 `LocalQingyuPageAppearance`，嵌套时读到的就是外层同一档 ⇒ 幂等。
    // 见 `QingyuPageTheme.kt:147-159`（字号）与 `:58-63`（默认继承外层）。
    QingyuPageTheme {
        QingyuPageScaffoldBody(
            title = title,
            onBack = onBack,
            actions = actions,
            bottomBar = bottomBar,
            smallTopBar = smallTopBar,
            maxContentWidth = maxContentWidth,
            enableTopBarBlur = enableTopBarBlur,
            content = content,
        )
    }
}

/**
 * 骨架主体（[QingyuPageScaffold] 的实现），**只由外面那层主题桥调用**。
 *
 * 单独抽出来，是为了让 [QingyuPageTheme] 能罩住 `Scaffold` 整体（含顶栏 / 底栏），
 * 同时保持参数列表与公开签名一一对应——51 处调用点零改动。
 */
@Composable
private fun QingyuPageScaffoldBody(
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
    // 右上动作键之间的横向间距。miuix 的 `SmallTopAppBar` / `TopAppBar` 只把 actions 包进
    // `Row(horizontalArrangement = Arrangement.End)`、**不给子项间距**，而共享玻璃钮是 44dp 圆底
    // ⇒ 多颗动作键（日志页有 4 颗）会严丝合缝贴成一排（2026-11-08 用户实报「间距太小」）。
    // 在骨架里统一补 8dp：页面仍然只写 `actions = { QingyuGlassIconButton(…) }`，不用各自套 Row。
    val topBarActions: @Composable RowScope.() -> Unit = {
        Row(
            horizontalArrangement = Arrangement.spacedBy(TopBarActionGap),
            verticalAlignment = Alignment.CenterVertically,
            content = actions,
        )
    }
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
                    // 绘制期读取：纵向渐隐要跟着可见底边收 0（不触发逐帧重组）。
                    barHeightOffsetPx = { scrollBehavior.state.heightOffset },
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
                                    actions = topBarActions,
                                    // 必须把 scrollBehavior 传进来：官方 SmallTopAppBar 在
                                    // SideEffect 里把 heightOffsetLimit 钉成 0（固定不折叠）；
                                    // 不传的话它保持默认 -Float.MAX，onPreScroll 会整段吞掉一个
                                    // 方向的滚动 ⇒ 小标题页接上列表后变成「只能单向滚」。
                                    scrollBehavior = scrollBehavior,
                                    // 标题左右内边距 26 → 8（2026-11-10 用户实报「诊断日志页标题被
                                    // 截成『应…』」）：miuix 的标题可用宽 = (屏宽 − 返回键 − 动作区) × 0.9，
                                    // 再被左右各 26 的内边距吃掉 52dp。四颗 44/48dp 动作球 + 返回键
                                    // 之后，400dp 屏只剩约 41dp 给文字（20sp 标题四个字要 ~80dp）。
                                    // 收到 8 后文字区约 88dp，「应用日志」恢复全文；动作球个数不变
                                    // （与发布版「四颗全露」一致）。
                                    titlePadding = 8.dp,
                                )
                            }
                            adaptive.isWideScreen -> {
                                SmallTopAppBar(
                                    title = title,
                                    color = barColor,
                                    navigationIcon = backIconOrNull(showBackButton, onBack),
                                    actions = topBarActions,
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
                                    actions = topBarActions,
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
                    // 列宽恒为 min(父宽, cap)：不加 fillMaxWidth 时，内容自己不铺满的页
                    // 会把整列缩到内容宽，居中位置跟着内容飘。
                    .widthIn(max = cap)
                    .fillMaxWidth()
                    .align(Alignment.TopCenter)
            } else {
                Modifier.fillMaxSize()
            }
            Box(modifier = contentModifier) {
                // 主题桥已在最外层（罩住顶栏 / 底栏 / 内容），这里不再重复包一层；
                // 只补「弹窗材质」的采样源：本地 fork 的 DialogContentLayout 玻璃分支与
                // 顶栏共用这条录像带采样页面内容，不另录第二份图层；backdrop 为 null 时
                // 消费方自动降级实心。
                CompositionLocalProvider(LocalQingyuPageBackdrop provides backdrop) {
                    QingyuPageContentScope(innerPadding, scrollBehavior).content()
                }
            }
        }
    }
}

/**
 * 子页顶栏玻璃参数（2026-11-08：**轻模糊 + 纵向权重 + 顶部加重的白纱**）。
 *
 * ## 方案（四次真机迭代后的稳定形态）
 *
 * - 模糊只做一次均匀高斯，半径 **26dp（σ≈12）**：σ22 会把内容抹成一块颜色，
 *   “上糊下清”在物理上就看不出来（用户 2026-11-07 多次实报）；
 * - 纵向权重乘在**模糊输出**上（`fadeEndFraction` + `QingyuVerticalFade` 着色器）：
 *   顶边 1.0、到**可见底边**归 0，坐标以 `y = 0` 为顶（Skia / AGSL 约定）；
 * - 白纱是正常混合的多段渐变：顶部 0.60，向下逐级变淡，**最后一段自己收到 0**。
 *
 * 2026-11-08 修掉的两个“长得奇怪”：
 * - 着色器按“原点在底部”算，权重上下颠倒 → 可见栏几乎没模糊，只剩白纱；
 * - 白纱末尾先到全透、再一下子压回不透明页底色（旧 0.84 / 1.0 两档）→ 栏底一条硬边 +
 *   中间一段清晰文字往外漏。现在末尾只有一档 `1.00f * f → transparent`，与模糊同步消失。
 *
 * 为什么不用另外两条路：
 * - miuix 官方渐进档：半分辨率堆栈 + 全分辨率 overlay 两层合成，真机滚动闪；
 * - 离屏掩膜（saveLayer + DstIn）：会把玻璃自己一起乘没，顶部变透明。
 *
 * ## 数值
 * - **半径 26dp**：σ≈12，保留可辨认的形状，渐变才看得出来。
 * - **白纱顶边**：浅 / 暗均 0.60（颜色 = 页面底色，不是纯白），向下 55% / 18% / 0。
 *
 * 改这里必须同步 `TopBarProgressiveBlurGuardTest`（方案实质被它钉住）。
 */
internal object QingyuTopBarBlur {
    /** 均匀模糊半径（dp）：σ≈12（0.45×26）。太大（σ22）会把内容抹成一块颜色，看不出“上糊下清”。 */
    const val MaxRadiusDp = 26f

    /**
     * 浅色白纱顶边 alpha。
     *
     * 颜色是页面底色（不是纯白，否则会比页面亮一档、收起时成一条白带）；浓度定在 0.60：
     * 0.78~0.82 会把下面的模糊整个盖住，看上去就只剩一条均匀白带（用户 2026-11-07/08 实报）。
     */
    const val LightTintAlpha = 0.60f

    /** 暗色顶边 alpha（同样是页面底色，不是纯白）。 */
    const val DarkVeilAlpha = 0.60f
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

/**
 * 顶栏叠色：[pageBackground] 本身（不是纯白）。
 *
 * 纯白会比页面底色亮一档 —— 后面没内容时整条顶栏就像一块白矩形，底边就是一条“分界线”。
 * 用页面底色后：没内容经过时它与页面同色（看不出来），有内容时才是磨砂霜。
 */
private fun qingyuTopBarTint(dark: Boolean, pageBackground: Color): Color =
    pageBackground.copy(
        alpha = if (dark) QingyuTopBarBlur.DarkVeilAlpha else QingyuTopBarBlur.LightTintAlpha,
    )

/**
 * 顶栏白纱：**正常混合**的多段垂直渐变，顶部最浓、向下逐级减弱、**可见底边归 0**。
 *
 * [fraction] = 当前可见栏高 / 模糊面高：大标题收起后可见栏变矮，白纱必须跟着收缩，
 * 否则会在面高度处才归零、被裁剪线切出一条硬边（用户 2026-11-07 实报的“均匀白带”）。
 *
 * 浓度控制在 0.6 左右：再厚就会把下面的模糊整个盖住，看上去就只剩一条均匀白带，
 * 反而看不出“渐变模糊”。
 *
 * ⚠️ 末尾**只有**一档 `1.00f * f → Transparent`，不要再加“0.84f 全透 + 1.0f 压回页底色”这种
 * 两档收尾：那会在栏底约 16% 的高度里从“内容完全看得见”直接跳到“全不透明页底色”，
 * 视觉上就是一条硬边 + 中间一段清晰文字往外漏（用户 2026-11-08 截图实报）。
 * 收尾由模糊自身的纵向权重负责（可见底边处权重已经是 0）。
 */
private fun qingyuTopBarScrim(dark: Boolean, fraction: Float, pageBackground: Color): Brush {
    val f = fraction.coerceIn(0.2f, 1f)
    val tint = qingyuTopBarTint(dark, pageBackground)
    return Brush.verticalGradient(
        0.00f to tint,
        0.35f * f to tint.copy(alpha = tint.alpha * 0.55f),
        0.70f * f to tint.copy(alpha = tint.alpha * 0.18f),
        1.00f * f to Color.Transparent,
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
    /**
     * 当前 `heightOffset`（px，≤0，滚动时逐帧变）。只用于**绘制期**算“可见栏高 / 模糊面高”：
     * 底边收尾要跟着可见底边，不能停在固定位置。在 draw lambda 里读，不引起逐帧重组。
     */
    barHeightOffsetPx: () -> Float,
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
    // scrim 每帧按可见比例重建（一条 4 段的 Brush）：不重建模糊层，不会抖。
    // （以前 remember(dark) 固定几何，收起时被裁在白纱中途，正是“均匀白带”的来源。）
    Layout(
        content = {
            if (backdrop != null) {
                val surfaceHeightPx = (bandHeightPx + contentGapPx).coerceAtLeast(1)
                QingyuGlassSurface(
                    backdrop = backdrop,
                    spec = QingyuTopBarGlassSpec,
                    shape = RectangleShape,
                    // 单次均匀模糊：不建多层合成，滚动期不会因两层采样错位而闪。
                    progressive = null,
                    // 纵向渐变权重：直接接在模糊的 RenderEffect 链上（不会被框架忽略），
                    // 顶部满强度、向下变清、可见底边归 0。
                    fadeEndFraction = if (underHeader) {
                        {
                            (surfaceHeightPx + barHeightOffsetPx())
                                .coerceIn(1f, surfaceHeightPx.toFloat()) / surfaceHeightPx
                        }
                    } else {
                        null
                    },
                    onDrawSurface = {
                        if (underHeader) {
                            // 顶部加重的白纱：正常混合叠在模糊上，跟着可见栏高一起收尾。
                            val visibleFraction = (surfaceHeightPx + barHeightOffsetPx())
                                .coerceIn(1f, surfaceHeightPx.toFloat()) / surfaceHeightPx
                            drawRect(brush = qingyuTopBarScrim(dark, visibleFraction, pageBackground))
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
            // 玻璃面高度 = 展开高度 + 标题→正文间距。可见栏高在滚动时变矮，但渐变权重
            // 按「可见高度 / 面高度」压缩、在可见底边归零 → 裁剪线落在全透明区，不会切出硬边。
            // 见 TopBarContentGap。
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
