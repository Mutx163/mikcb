package com.mutx163.qingyu.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet

/**
 * **底部弹层套件**：全 App 的底栏弹层都应该走这里，不要直接调 `OverlayBottomSheet`。
 *
 * ## 为什么需要它（这是 2026-10-30 全量审核的结论）
 *
 * miuix 的 `OverlayBottomSheet` 有两个默认值与本仓口径**不一样**，而它们都不会编译报错、
 * 只有真机上盯屏才看得出来 —— 于是 35 个调用点里 31 个都带着同样的毛病：
 *
 * | # | miuix 默认 | 本仓口径（Dart 出处） | 症状 |
 * |---|---|---|---|
 * | S1 | `insideMargin = DpSize(24.dp, 0.dp)` | 16dp（`hyperosMiuixBottomSheetInsideMargin`） | 再叠上内容自己那 16dp 就是单边 40dp，卡片被挤成中间窄条、两边各空一大块 |
 * | S2 | 只 `imePadding()`（只让键盘） | 手势区/导航栏 + 16dp 呼吸（`bottomGapInsetOf`） | 最后一排按钮贴到屏幕最下沿、被小白条压住（Dart 侧当年原话：「调课停课什么的都到底部屏幕外面去了」） |
 *
 * 这两个值**必须由套件统一给**，理由与 `QingyuPageScaffold` 一样：让每个调用方自己记得，
 * 就一定会有漏的；漏了只在真机上看得出。
 *
 * ## 底部让位为什么要走 `bottomInset` 参数
 *
 * 让位必须加在**滚动内容的里面**，不能垫在滚动视口外面：垫在外面时视口会在离屏幕底
 * 一段距离的地方停住，那一截永远是空的（Dart 侧同一处踩过，见
 * `lib/ui/hyperos/miuix_bottom_sheet.dart` 的 `scrollableBottomGap` 那段长注释）。
 * 所以：
 * - 内容**不**滚动（默认）：套件自己套 `verticalScroll`，并在末尾补 `Spacer(bottomInset)`；
 * - 内容**自己**滚动（内部有 `LazyColumn` / 自己的 `verticalScroll`）：调用方把
 *   [QingyuSheetContentScope.bottomInset] 塞进列表的 `contentPadding` / 末尾 spacer。
 *
 * ## 与 Dart 的一处刻意不同
 *
 * Dart 把把手条**悬浮**在内容之上（`dragHandleOverlaysContent`），所以内容从面板上沿开始；
 * miuix Compose 0.9.4 的 `OverlayBottomSheet` 没有这个开关，把手条恒占 24dp、且无标题时
 * 还会多出一条 18dp 的空标题行。这 42dp 顶部留白是**组件能力缺口**，不是本套件能消掉的
 *（审核报告 §五 已登记）。所以别把内容自己的顶部间距再加一遍。
 *
 * @param show 是否显示。
 * @param onDismissRequest 点空白 / 返回键时回调。
 * @param title 弹层标题；`null` = 不画（内容自绘标题时用）。
 * @param startAction 标题行左侧动作（如关闭键）。
 * @param endAction 标题行右侧动作（如提交键）。
 * @param contentPadsHorizontally 内容**自己**带了左右内边距时置 `true`：此时框架侧横向
 *   内边距归零，避免叠加成 32~40dp。
 *   ⚠️ **带阈值，别机械照字面判**：内容自带的是 **4dp 这类微调**（本仓常见的面板内小推手）
 *   时应当传 `false` —— 归零会让内容只剩单边 4dp，比 16dp 口径更糟。经验线是
 *   「自带 ≥ 12dp 才算内容的主边距」。判据的意图是「归零后没有任何通栏元素被贴到面板边」，
 *   不是「源码里出现过 padding(horizontal」（两个泳道都在这条上反过车，见审核报告 §五）。
 * @param contentScrolls 内容**自己**管滚动时置 `true`：本组件不再套 `verticalScroll`，
 *   底部让位由内容自己用 [QingyuSheetContentScope.bottomInset] 落实。
 *   ⚠️ **两种布局，让位落点不同**：
 *   - 滚动区**直通屏幕底**（列表是最后一块）⇒ 把 `bottomInset` 塞进列表的 `contentPadding`；
 *   - 滚动区**下面还有固定件**（例如固定底部按钮排在列表之外）⇒ 让位要垫在**固定件之后**；
 *     塞进列表 `contentPadding` 会在固定按钮上方造出一截空白。
 * @param scrollState 外部滚动状态。调用方需要「换内容后滚回顶部」这类操作时传进来；
 *   不传则本组件自己记一个。⚠️ 只在 `contentScrolls = false` 时有意义。
 * @param maxHeightFraction 限高（屏高比例）。`null` = 不额外限高（交给内容自己）。
 * @param content 内容；`this` 是可滚动列作用域，[QingyuSheetContentScope.bottomInset] 是
 *   「系统手势区 + 16dp」的让位值。
 */
@Composable
fun QingyuSheet(
    show: Boolean,
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    title: String? = null,
    startAction: (@Composable () -> Unit)? = null,
    endAction: (@Composable () -> Unit)? = null,
    contentPadsHorizontally: Boolean = false,
    contentScrolls: Boolean = false,
    scrollState: ScrollState? = null,
    maxHeightFraction: Float? = null,
    content: @Composable QingyuSheetContentScope.() -> Unit,
) {
    OverlayBottomSheet(
        show = show,
        modifier = modifier,
        title = title,
        startAction = startAction,
        endAction = endAction,
        // S1：本仓口径 16dp；内容自带左右内边距时置 0，绝不叠成 32+。
        insideMargin = DpSize(if (contentPadsHorizontally) 0.dp else QingyuSheetDefaults.InsideMargin, 0.dp),
        onDismissRequest = onDismissRequest,
    ) {
        // S2：底部让位 = 系统手势区 + 16dp 呼吸。
        val bottomInset = WindowInsets.navigationBars
            .asPaddingValues()
            .calculateBottomPadding() + QingyuSheetDefaults.ContentBottomGap
        val scope = QingyuSheetContentScope(bottomInset = bottomInset)
        var columnModifier = Modifier.fillMaxWidth()
        if (maxHeightFraction != null) {
            val maxHeight = (LocalConfiguration.current.screenHeightDp * maxHeightFraction).dp
            columnModifier = columnModifier.heightIn(max = maxHeight)
        }
        if (!contentScrolls) {
            // 内容不滚动时由本组件套滚动：这样「限高」与「底部让位在滚动内容里」两件事
            // 同时成立（垫在视口外面就是那截永远空的板）。
            columnModifier = columnModifier.verticalScroll(scrollState ?: rememberScrollState())
        }
        Column(modifier = columnModifier) {
            scope.content()
            if (!contentScrolls) {
                Spacer(modifier = Modifier.height(bottomInset))
            }
        }
    }
}

/**
 * [QingyuSheet] 内容的作用域。
 *
 * 目前只带一个值，但**必须用作用域而不是让调用方自己算**：底部让位的口径将来若要
 * 跟着系统手势栏变（三键导航 / 全屏手势高度不同），只有这里一处要改。
 */
class QingyuSheetContentScope internal constructor(
    /**
     * 底部让位 = 系统手势区高度 + [QingyuSheetDefaults.ContentBottomGap]。
     *
     * `contentScrolls = true` 时由调用方落实（列表 `contentPadding` / 末尾 `Spacer`）；
     * 否则套件已经补好了，调用方不用管。
     */
    val bottomInset: Dp,
)

/** [QingyuSheet] 的口径常量。数值来源都在 KDoc 里，别在这里发明新值。 */
object QingyuSheetDefaults {

    /**
     * 弹层内容的左右内边距。
     *
     * = `lib/ui/hyperos/miuix_bottom_sheet.dart` 的 `hyperosMiuixBottomSheetInsideMargin`（16）。
     * miuix 默认 24；Dart 侧那句注释就是当年把 24 改回 16 的账。
     */
    val InsideMargin: Dp = 16.dp

    /**
     * 底部呼吸（系统手势区之外那一截）。
     *
     * = `hyperosMiuixBottomSheetContentBottomGap`（16）。
     */
    val ContentBottomGap: Dp = 16.dp
}
