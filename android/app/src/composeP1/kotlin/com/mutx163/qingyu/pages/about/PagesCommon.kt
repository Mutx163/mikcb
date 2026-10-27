package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuPageTheme
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
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward

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
 * 内容槽收到的两样东西：内边距，以及顶栏的折叠行为。
 *
 * 折叠行为必须交给内容去挂 `nestedScroll`——只把 `scrollBehavior` 传给顶栏，
 * 顶栏收不到滚动手势，大标题就会「参数传了但不折叠」。
 */
class QingyuPageContentScope(
    val innerPadding: PaddingValues,
    val scrollBehavior: ScrollBehavior,
)

@Composable
fun QingyuPageScaffold(
    title: String,
    onBack: () -> Unit,
    actions: @Composable RowScope.() -> Unit = {},
    content: @Composable QingyuPageContentScope.() -> Unit,
) {
    val dark = isSystemInDarkTheme()
    // 每个页面实例一个折叠状态：返回后重新进入应从展开态开始。
    val scrollBehavior = MiuixScrollBehavior()
    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        topBar = {
            TopAppBar(
                title = title,
                largeTitle = title,
                scrollBehavior = scrollBehavior,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = "返回",
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
                actions = actions,
            )
        },
    ) { innerPadding ->
        // 页面主题桥兜住深色：两个壳用的是无参 MiuixTheme{ }（配色恒亮），
        // 不在这里兜一层，深色下卡片仍是白底而正文取白字 → 内容不可读。
        QingyuPageTheme {
            QingyuPageContentScope(innerPadding, scrollBehavior).content()
        }
    }
}

/**
 * 分组小标题（Dart 侧 `HyperosSectionLabel`）。
 *
 * 字号 13 / 次要文字色，与 Flutter 侧的分组标签同档（`hyperos_typography` 的
 * footnote 档），不再各页各估。
 */
@Composable
fun QingyuSectionLabel(text: String) {
    val dark = isSystemInDarkTheme()
    Text(
        text = text,
        fontSize = 13.sp,
        color = Color(QingyuTheme.sectionLabel(dark)),
        modifier = Modifier.padding(start = 4.dp, top = 12.dp, bottom = 4.dp),
    )
}

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
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                subtitle?.takeIf { it.isNotEmpty() }?.let { sub ->
                    Text(
                        text = sub,
                        fontSize = 12.sp,
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

    val margin = PaddingValues(horizontal = 14.dp, vertical = 12.dp)
    if (onClick == null) {
        Card(modifier = Modifier.fillMaxWidth(), insideMargin = margin) { content() }
    } else {
        Card(modifier = Modifier.fillMaxWidth(), insideMargin = margin, onClick = onClick) { content() }
    }
}
