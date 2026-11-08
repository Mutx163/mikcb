package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.Image
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.R
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageContentScope
import com.mutx163.qingyu.components.QingyuPageScaffold as SharedPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 三个页面共用的官方骨架。
 *
 * ## 为什么要有这个文件（一次返工换来的教训）
 *
 * 第一版三页是我用「Card + Text + 一行写死的『返回』文字」硬拼的，用户实测反馈
 * 「和官方示例差得远、有廉价感」。逐条对下来原因是：
 * 1. 顶栏是手写的文字按钮，不是官方 [TopAppBar]；
 * 2. 一行图标都没画——官方图标包（`miuix-icons`，155 个）其实早就依赖了，
 *    是我没去用（当时误查了另一个 artifact，以为只有 5 个图标）；
 * 3. 行用 `Modifier.clickable`，没有官方卡片的按压反馈；
 * 4. 没接自家色板（[QingyuTheme]），用的是组件库默认值；
 * 5. 间距/字号是我估的。
 *
 * 这个文件把 1/3/4 统一收口，页面只负责内容，避免再次各写各的。
 */

/**
 * 页面骨架：官方顶栏进 [Scaffold] 的 `topBar` 槽位 + 官方底色 + 可折叠大标题。
 *
 * ## 为什么必须放进 `topBar` 槽位（2026-10-27 返工）
 *
 * 第一版把 [TopAppBar] 塞在 `Scaffold` 的 content 里（`Column { TopAppBar(); content() }`）。
 * 官方 [TopAppBar] 自己就会加 `WindowInsets.systemBars` 的顶部内边距
 * （`TopAppBar.kt:806`），而 `Scaffold` 在 `topBar` 为空时又把同一份系统栏内边距
 * 塞进 `contentWindowInsets`，一并交给 `innerPadding`——两者叠起来，
 * 状态栏高度被算了两遍，标题整体下移约一个状态栏的高度。
 *
 * 放进槽位后职责就清了：**顶栏自己吃状态栏，内容只吃顶栏高度 + 底部手势条**。
 *
 * ## 为什么必须传 `largeTitle` 与 `scrollBehavior`
 *
 * Dart 侧这三页走 `HyperosSubpage`，它 `overlayHeader = true` 且
 * `collapsibleLargeTitle = true` 都是**默认值**（`hyperos_page.dart:150-170`），
 * 也就是现版本这些页面本来就有可折叠大标题。官方 [TopAppBar] 的
 * `largeTitle` 默认等于 `title`、`scrollBehavior` 默认 `null`：
 * 不传 `largeTitle` 会白送一个 32sp 大标题，不传 `scrollBehavior` 则**永不折叠**，
 * 白占约 60dp。两处都补齐才对得上现版本。
 *
 * 调用方要把 [androidx.compose.ui.input.nestedscroll.nestedScroll] 挂到滚动容器上，
 * 否则折叠行为收不到滚动手势（各页已经挂好）。
 */
/**
 * 关于页族的页面骨架：直接转发到 [com.mutx163.qingyu.components.QingyuPageScaffold]
 * （官方 [TopAppBar] + 标准左箭头），保留这层包装只为不动 5 个关于页的调用点。
 *
 * 内容槽类型 [QingyuPageContentScope] 也已上移到 `components`，因此
 * `innerPadding` / `scrollBehavior` 两个属性照旧可用。
 */
@Composable
fun QingyuPageScaffold(
    title: String,
    onBack: () -> Unit,
    actions: @Composable RowScope.() -> Unit = {},
    bottomBar: (@Composable () -> Unit)? = null,
    /**
     * 传 true 走单行固定顶栏（官方 `SmallTopAppBar`）；默认仍是可折叠大标题。
     *
     * 2026-11-08：版本更新页改成「无标题 + 左右两颗胶囊」时需要这条通道，
     * 这里只是原样转发给 [SharedPageScaffold]，不改其余行为。
     */
    smallTopBar: Boolean = false,
    content: @Composable QingyuPageContentScope.() -> Unit,
) {
    SharedPageScaffold(
        title = title,
        onBack = onBack,
        actions = actions,
        bottomBar = bottomBar,
        smallTopBar = smallTopBar,
        content = content,
    )
}

// 分组小标题原先在这里自己拼（13sp + `start = 4.dp` + 次要文字色），对不齐官方那条
// 28dp 轴线（页面 0 → Card 外边距 12 → Preference 自带 16）。2026-10-28 已删除，
// 关于域三页统一改用 `components/QingyuSectionTitle`（官方 SmallTitle，自带 28dp 左缘）。
// 这里不再提供第二套实现——第二套就是「各页各写各的」的起点。

/**
 * 列表行：官方 [Card] 的可点击重载（**带按压反馈**）+ 行首图标 + 行尾箭头。
 *
 * 用 Card 的 `onClick` 而不是 `Modifier.clickable`，按压反馈由官方组件给，
 * 手感与系统一致——这正是第一版「廉价感」的来源之一。
 */
@Composable
fun QingyuRow(
    title: String,
    subtitle: String? = null,
    icon: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    onClick: (() -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    val content: @Composable () -> Unit = {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            icon?.invoke()
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                subtitle?.takeIf { it.isNotEmpty() }?.let { sub ->
                    Text(
                        text = sub,
                        style = MiuixTheme.textStyles.footnote1,
                        lineHeight = 18.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
            if (trailing != null) {
                trailing()
            } else if (onClick != null) {
                Icon(
                    imageVector = MiuixIcons.ChevronForward,
                    contentDescription = null,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
        }
    }

    // 行内边距 16dp：与官方 `*Preference` 自带的内边距同值。配合列表的
    // `horizontalPadding = QingyuPageCardMargin`（12dp）得到文字左缘 12 + 16 = 28，
    // 正好落在官方那条轴线上（原先写 14dp 会差 2dp，分组标题与行文字对不齐）。
    val margin = PaddingValues(horizontal = 16.dp, vertical = 12.dp)
    if (onClick == null) {
        QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = margin) { content() }
    } else {
        QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = margin, onClick = onClick) { content() }
    }
}

// ── 关于族共享视觉参数（2026-11-03 版面收口：关于页 / 更新页 / 捐助页 / 高级选项一套刻度） ──

/** 列表条目间距：全族统一 12dp（官方 demo 分段间距；此前关于页独写 8dp，已收编）。 */
val AboutPageListSpacing: Arrangement.Vertical = Arrangement.spacedBy(QingyuPageCardMargin)

/**
 * [AboutPageListSpacing] 的**内容居中版**：同样 12dp 间距，额外把整组内容在视口里垂直居中
 * ——用于内容通常不满一屏、又不该在底部留一大片空白的页面（如「版本更新」页）。
 * 内容超过一屏时 LazyColumn 不会居中，照常从顶部排列并可滚动。
 *
 * 名字沿用 `AboutPageListSpacing` 前缀：它仍是**全族共享的列表间距常量**，页面不许写死间距。
 */
val AboutPageListSpacingCentered: Arrangement.Vertical =
    Arrangement.spacedBy(QingyuPageCardMargin, Alignment.CenterVertically)

/** 列表底部额外留白：全族统一 24dp（叠在 [QingyuPageList] 的 innerPadding.bottom 之上）。 */
val AboutPageListBottomPadding: Dp = 24.dp

/**
 * 关于族统一的「应用图标身份块」（圆角 = 尺寸 × 24/84，与 Flutter `AppIconBadge` 同比例）。
 *
 * ## 只画**一层**
 *
 * 历史根因（2026-11-04 用户反馈「一个大图标上又叠了一个小图标，还有两个点」）：
 * 自适应启动图被拆成 `ic_launcher_background`（不透明整图，与 Flutter
 * `assets/branding/launcher_icon.png` 逐像素一致）与 `ic_launcher_foreground`
 * （只含安全区内的前景、四周透明）两枚 PNG。以前把两枚都按 `ContentScale.Crop` 铺满同一
 * 方块——背景层已经是完整图标，再把前景层按 1:1 叠上去，就等于在正常图标上又叠了一个
 * 偏小的图标（前景层的边角露出成「多余的两个点」）。
 *
 * 正确做法：**只画背景层那一枚**（它本身就是完整、不透明的 App 图标）。这样是干净的单层
 * logo，无重影、无多余的点；也避免 `painterResource(applicationInfo.icon)` 在 API26+ 解析到
 * adaptive-icon XML 直接抛异常（进页闪退）。
 *
 * 实现只此一份：`ic_launcher_background` 字面量只允许出现在本文件
 * （[AboutStyleRatchetGuardTest] 钉着），关于页头部卡与更新页（检查中 / 状态卡）共用。
 */
@Composable
fun AboutAppIconBadge(size: Dp) {
    Image(
        painter = painterResource(id = R.mipmap.ic_launcher_background),
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = Modifier
            .size(size)
            .clip(RoundedCornerShape(size * 24f / 84f)),
    )
}
