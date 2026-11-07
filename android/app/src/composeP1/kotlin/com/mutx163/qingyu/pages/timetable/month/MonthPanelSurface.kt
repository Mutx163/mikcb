package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.CardColors
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 月视图**信息区卡片的材质**：填充色、墨色、圆角 —— 唯一来源。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_panel_surface.dart`（2026-10-27
 * 的 66 行那版）。Dart 那份的头注释记着两轮返工（先是「面板里的灰卡」、再是
 * 「玻璃卡」），结论只有一句：
 *
 * > 卡片是**实底**的，与上半那张日历卡同一档；卡与卡之间露出背景，靠圆角与
 * > 缝区分，不靠灰白差。
 *
 * ⚠️ **2026-11-07 修正**：旧实现取 `colorScheme.surface`（亮色 = 页底 #F2F2F2）
 * 当卡面，而日历卡走 `QingyuCard` 默认的 `surfaceContainer`（#FFFFFF）。结果
 * 「同一档」在代码里并不成立，无壁纸时信息卡还会和页底同色、卡界直接消失。
 * 现在两者统一到 `surfaceContainer`，卡面差异只由投影表达（日历卡高一档）。
 *
 * ## 与 Dart 版的三处对应关系
 *
 * | Dart | 这里 |
 * |---|---|
 * | `monthInfoCardFill(context)` = `colorScheme.surface` | [MonthPanelSurface.fill] |
 * | `monthInfoCardInk(...)`（按卡面亮度算墨） | [MonthPanelSurface.ink] |
 * | `DayViewAgendaSurface(forceSolid: true, radius: ...)` | [MonthPanelCard] 里的 `QingyuCard` |
 *
 * **没有逐字移植墨色计算**：Dart 那套 `cardSurfaceInk` 是为「玻璃卡可能透壁纸、
 * 于是按卡面实际亮度判黑白」服务的。Compose 侧这张卡是**主题实底**（主题已经
 * 处理了深浅），墨色直接用主题 `onSurface` 就恒正确 —— 照抄那套计算反而会
 * 引入一个「按壁纸亮度判色」的旁路，而 Compose 页面根本没有屏级壁纸亮度读数。
 *
 * ## 为什么信息卡没有投影
 *
 * [MonthMetrics.CARD_SHADOW_ALPHA] 是 Dart `CourseSurface` 的投影强度。Miuix 的
 * 卡片语言里**没有投影**（`BasicCard` = squircle 实底 + 无 elevation），照搬
 * 一条 Flutter 投影会在 miuix 页面上显得脏。
 *
 * 日历卡是**唯一的例外**：它压在满屏壁纸上，没有投影时白卡边界只能靠色差读，
 * 所以 `MonthCalendarCard` 自己补了一层 6% 黑投影。这是**有意的两级**：
 * 日历卡高一层（白 + 投影），信息卡平铺（白 + 无投影）；圆角 24 / 20 再补一级。
 * 不要把它读成「两张卡完全同档」——同档的是**卡面颜色**，不是层级。
 */
object MonthPanelSurface {

    /** 信息卡圆角（= [MonthMetrics.CARD_RADIUS]，20dp，与日视图议程卡同档）。 */
    val Radius = MonthMetrics.CARD_RADIUS.dp

    /** 卡面填充（主题 `surfaceContainer`：亮色 #FFFFFF / 暗色 #2D2D2D，与日历卡同源）。 */
    @Composable
    fun fill(): Color = MiuixTheme.colorScheme.surfaceContainer

    /** 卡内主墨色（卡标题、议程行标题、概览大数字）。 */
    @Composable
    fun ink(): Color = MiuixTheme.colorScheme.onSurfaceContainer

    /** [QingyuCard] 的配色：实底 + 主题墨，与上面两个函数同源。 */
    @Composable
    fun cardColors(): CardColors = CardDefaults.defaultColors(
        color = fill(),
        contentColor = ink(),
    )

    /**
     * 墨色降一档（Dart `ink.withValues(alpha: MonthInk.x)`）。
     *
     * 只允许传 [MonthInk] 里的档位：这五档是按**对比度**定的，随手传一个
     * 0.4 这类数字会掉到 3:1 以下（[MonthInk] 的注释里有实测值）。
     * 11sp 及以下的说明文字请用 [MonthInk.SECONDARY]，不要用 [MonthInk.TERTIARY]。
     */
    fun muted(base: Color, level: Double = MonthInk.SECONDARY): Color =
        base.copy(alpha = level.toFloat())
}

/**
 * 信息区的**通用卡壳**：圆角实底卡 + 卡内标题（+ 可选右端附属信息）+ 内容。
 *
 * 把「标题 + 内容」收进同一张卡是 Dart 2026-10-23 那轮的核心结构改动：标题浮在
 * 壁纸上时，用户在高饱和壁纸上读到的是一段找不到归属的碎字。Compose 页面没有
 * 壁纸，但结构照搬 —— 一张卡 = 一个语义块，卡里的第一行就是它的标题。
 *
 * ⚠️ **卡内上下内边距与标题行高是 [MonthPanelChrome] 那一份**：概览的「本月有
 * 安排的日子」要按卡高反算能列几行，账必须与这里的真实占位同源，否则会溢出
 * （算多了）或留白（算少了）。
 */
@Composable
fun MonthPanelCard(
    title: String,
    modifier: Modifier = Modifier,
    trailing: String? = null,
    /** 标题与内容之间的间距。概览卡 10（Dart `_InfoCard.titleGap`）、议程卡 12。 */
    titleGap: Dp = MonthPanelChrome.CARD_TITLE_GAP.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    val ink = MonthPanelSurface.ink()
    QingyuCard(
        modifier = modifier,
        cornerRadius = MonthPanelSurface.Radius,
        // 内边距自己给：Dart 那张卡是「左右 14 / 上下 13」，与 Miuix 的 16 不同，
        // 而上下 13 参与 [MonthPanelChrome] 的高度账，必须精确。
        insideMargin = PaddingValues(0.dp),
        colors = MonthPanelSurface.cardColors(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = MonthMetrics.CARD_PADDING.dp,
                    end = MonthMetrics.CARD_PADDING.dp,
                    top = MonthPanelChrome.CARD_PADDING_VERTICAL.dp,
                    bottom = MonthPanelChrome.CARD_PADDING_VERTICAL.dp,
                ),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = title,
                    modifier = Modifier.weight(1f),
                    // 14dp = body2（Dart MonthType.title；官方 body2 实际就是 14sp）
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.BOLD),
                    color = ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (trailing != null) {
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = trailing,
                        // 11dp = footnote2（Dart MonthType.caption）
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                        // 11dp = footnote2（Dart MonthType.caption）；这是 11sp 小字，
                        // 用 SECONDARY（亮色约 5.7:1），不能用 TERTIARY（约 3.2:1）。
                        color = MonthPanelSurface.muted(ink, MonthInk.SECONDARY),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Spacer(Modifier.height(titleGap))
            content()
        }
    }
}

/**
 * 概览 / 今日议程共用的**行容器**：可点、带圆角水波纹。
 *
 * 卡片本身不可点（它是容器），所以按压反馈落在行上 —— 与 Dart 的
 * `Material(type: transparency) + InkWell` 同义。Compose 侧的点按指示由
 * `MiuixTheme` 注入的 `LocalIndication` 提供，不需要自备 ripple。
 */
@Composable
fun MonthPanelRow(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = MonthMetrics.CELL_RADIUS.dp,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = modifier
            // ⚠️ **不**在这里 `fillMaxWidth`：整行可点的（预览行 / 议程行）由调用方
            // 自己传，而「加课」胶囊要按内容宽 —— 收口时一旦写死，胶囊就变成一条
            // 通栏按钮。
            // clip 必须在 clickable 之前：水波纹要落在圆角里，不能溢出成方形。
            .clip(RoundedCornerShape(cornerRadius))
            .clickable(onClick = onClick),
    ) {
        content()
    }
}

/**
 * 信息区一列卡之间的**竖向排布**（概览卡 → 有安排的日子卡）。
 *
 * 抽出来只为让「卡缝 = [MonthMetrics.ITEM_GAP]、左右外沿 = [MonthMetrics.CARD_INSET]」
 * 只在页面壳里写一次 —— Dart 侧这两条是 `_buildInfoArea` 里的两个 padding，
 * 换页时容易漏。
 */
@Composable
fun MonthPanelColumn(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(MonthMetrics.ITEM_GAP.dp),
        content = content,
    )
}
