package com.mutx163.qingyu.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.SmallTitle
import top.yukonga.miuix.kmp.basic.SmallTitleDefaults
import top.yukonga.miuix.kmp.basic.VerticalScrollBar
import top.yukonga.miuix.kmp.basic.rememberScrollBarAdapter
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic

/**
 * 页面骨架：**官方 `LazyColumn` 配方**的本地封装。
 *
 * ## 为什么必须换掉 `Column + verticalScroll`
 *
 * 迁移期各页普遍写成 `Column(Modifier.verticalScroll(rememberScrollState()))`。
 * 这在官方 demo 里**一处都没有**——`SettingsPage.kt:120`、`ArrowSection.kt:44` 全是 `LazyColumn`。
 * `verticalScroll` 的代价不是「少个滚动条」：
 *
 * 1. **不做惰性组合**：`Column` 的每个子项都会全部 measure + compose；
 * 2. **拿不到滚动条**：`VerticalScrollBar` 需要 `ScrollBarAdapter`（来自 `LazyListState`），
 *    `Column` 给不了，于是全站没有滚动条；
 * 3. **拿不到官方滚动修饰**：末端触感与过度滚动都挂在 `Modifier` 上，要配 `LazyColumn`。
 *
 * ## 官方骨架三件套（本组件就是这三件的合体）
 *
 * 出处 `docs/reference/miuix-demo/example/shared/src/commonMain/kotlin/utils/PageUtils.kt:42-72`
 * （`pageScrollModifiers` / `pageContentPadding`）与 `SettingsPage.kt:96-210`（实际接线）。
 *
 * ## 尺寸刻度（照抄，别自己估）
 *
 * 页面横向 0 → Card 外边距 12 → `*Preference` 自带 16 ⇒ 文字左缘 **28dp**，
 * 与 `SmallTitle` 自带的 28dp 对齐。所以 [horizontalPadding] 传 [QingyuPageCardMargin]。
 *
 * ## 结构约定（与官方一致）
 *
 * ```kotlin
 * QingyuPageList(innerPadding = inner) {
 *     item { QingyuCard { SwitchPreference(...); ArrowPreference(...) } }  // 一组 = 一个 item
 *     item { QingyuSectionTitle("下一组") }
 * }
 * ```
 *
 * 官方就是把「一整张 Card 里的多个 Preference」放在**同一个 item** 里
 * （`SettingsPage.kt:120-302`），不是一行一个 item。
 *
 * @param innerPadding 来自 `Scaffold` 的 `innerPadding`（顶栏已吃掉系统栏顶部）
 * @param contentPadding 额外底部留白（例如底部 dock 高度）
 * @param enableScrollEndHaptic 滚到头是否轻震（官方 demo 由设置项控制，默认开）
 */
@Composable
fun QingyuPageList(
    innerPadding: PaddingValues,
    modifier: Modifier = Modifier,
    state: LazyListState = rememberLazyListState(),
    contentPadding: PaddingValues = PaddingValues(0.dp),
    enableScrollEndHaptic: Boolean = true,
    scrollBehavior: ScrollBehavior? = null,
    horizontalPadding: Dp = 0.dp,
    verticalArrangement: Arrangement.Vertical = Arrangement.Top,
    showScrollBar: Boolean = true,
    content: LazyListScope.() -> Unit,
) {
    val layoutDirection = LocalLayoutDirection.current
    val top = innerPadding.calculateTopPadding()
    val bottom = innerPadding.calculateBottomPadding() + contentPadding.calculateBottomPadding()
    val start = horizontalPadding + contentPadding.calculateStartPadding(layoutDirection)
    val end = horizontalPadding + contentPadding.calculateEndPadding(layoutDirection)
    val padding = PaddingValues(start = start, top = top, end = end, bottom = bottom)

    Box(modifier = modifier.fillMaxSize()) {
        LazyColumn(
            state = state,
            // 官方 pageScrollModifiers 的三件：末端触感 + 过度滚动 + 顶栏联动
            modifier = Modifier
                .then(if (enableScrollEndHaptic) Modifier.scrollEndHaptic() else Modifier)
                .overScrollVertical()
                .then(
                    if (scrollBehavior != null) {
                        Modifier.nestedScroll(scrollBehavior.nestedScrollConnection)
                    } else {
                        Modifier
                    },
                )
                .fillMaxHeight(),
            contentPadding = padding,
            verticalArrangement = verticalArrangement,
            content = content,
        )

        if (showScrollBar) {
            VerticalScrollBar(
                adapter = rememberScrollBarAdapter(state),
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .fillMaxHeight(),
                trackPadding = padding,
            )
        }
    }
}

/**
 * 建一个可折叠顶栏的滚动行为，同时喂给 `TopAppBar` 与 [QingyuPageList]。
 *
 * 注意返回类型是 [ScrollBehavior]（接口）而不是 `MiuixScrollBehavior`——
 * 后者是官方工厂函数，不是类型名（写成类型会报 Unresolved reference）。
 */
@Composable
fun rememberQingyuScrollBehavior(): ScrollBehavior = MiuixScrollBehavior()

/**
 * 页面里的分组标题：官方 `SmallTitle` 的语义包装。
 *
 * 迁移期各页手写成 `Text(style = footnote1, color = sectionLabel, padding(start = 4.dp, …))`。
 * 官方用 `SmallTitle(text = …)`（`SettingsPage.kt` 多处）：自带 `subtitle` 字阶、
 * 主题色与 **28dp 左缘**，正好对上「页面 0 → Card 12 → Preference 16」那条轴线。
 */
@Composable
fun QingyuSectionTitle(
    text: String,
    modifier: Modifier = Modifier,
    /**
     * 标题文字的内边距。默认是官方 `SmallTitle` 的 28dp 横向——用于
     * **列表本身没有横向内边距**的页面。
     *
     * 若列表已经统一加了 12dp（`horizontalPadding = QingyuPageCardMargin`），
     * 这里要传 `PaddingValues(horizontal = 16.dp, vertical = 8.dp)`，
     * 才能和卡内 16dp 的文字左缘一起落在 28dp 轴线上；继续用默认值会变成 40dp。
     */
    insideMargin: PaddingValues = SmallTitleDefaults.InsideMargin,
) {
    Box(modifier = modifier.fillMaxWidth()) {
        SmallTitle(text = text, insideMargin = insideMargin)
    }
}

/** 页面内 Card 的统一外边距（官方 12dp；配合 Preference 自带 16 得文字左缘 28）。 */
val QingyuPageCardMargin: Dp = 12.dp

/**
 * 分组之间的竖向间距（官方 demo 统一 12dp）。
 *
 * 保留这个别名是因为已有页面在用（`pages/statistics/charts/WeekStatsView.kt`）；
 * 它等价于 `Arrangement.spacedBy(12.dp)` 里那个 12，语义上叫「分段间距」更好读。
 */
val QingyuSectionGap: Dp = 12.dp
