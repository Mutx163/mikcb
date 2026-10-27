package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDateTime

/**
 * 当日议程卡内部的**行内尺寸**（Dart `month_day_agenda.dart` 的实测值）。
 *
 * 与 [MonthOverviewMetrics] 同一套理由：这些是「一张卡内部」的行内间距，不进
 * 整页栅格的 [MonthMetrics]。逐条注明出处，避免 3 / 30 / 44 这类数字散进布局。
 */
internal object MonthAgendaMetrics {

    /** 行首强调竖条宽度。 */
    const val ACCENT_WIDTH = 3.0

    /** 行首强调竖条高度。 */
    const val ACCENT_HEIGHT = 30.0

    /** 竖条圆角。 */
    const val ACCENT_RADIUS = 2.0

    /** 竖条与钟点之间。 */
    const val ACCENT_GAP = 12.0

    /** 钟点列的固定宽度（左对齐，让所有标题的起始横线对齐）。 */
    const val CLOCK_WIDTH = 44.0

    /** 行的上下内边距。 */
    const val ROW_VERTICAL = 2.0

    /** 行圆角（点按水波纹范围）。 */
    const val ROW_RADIUS = 12.0

    /** 标题与副行之间。 */
    const val SUBTITLE_GAP = 2.0

    /** 正文区与右侧箭头之间。 */
    const val CHEVRON_GAP = 6.0

    /** 右侧箭头尺寸。 */
    const val CHEVRON_SIZE = 18.0

    /** 卡标题与内容之间（Dart `SizedBox(height: 12)`，比概览卡的 10 宽一点）。 */
    const val TITLE_GAP = 12.0

    /** 空态说明与「加课」按钮之间。 */
    const val EMPTY_ACTION_GAP = 12.0

    /** 「加课」胶囊的左右内边距。 */
    const val ACTION_PADDING_HORIZONTAL = 12.0

    /** 「加课」胶囊的上下内边距。 */
    const val ACTION_PADDING_VERTICAL = 6.0

    /** 「加课」胶囊圆角（999 = 全圆）。 */
    const val ACTION_RADIUS = 999.0

    /** 「加课」图标尺寸。 */
    const val ACTION_ICON_SIZE = 15.0

    /** 「加课」图标与文字之间。 */
    const val ACTION_ICON_GAP = 4.0
}

/**
 * 月视图选中日的**当日议程**（课程 + 考试 + 日程混排）。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_day_agenda.dart`（2026-10-27 的
 * 301 行那版）。那两轮返工的结论照抄：
 *
 * 1. **标题进卡**。旧实现把「10月24日」画在卡**外面**、直接压在壁纸上；用户那张
 *    壁纸是高饱和彩色斜带，深色标题压上去对比度很低，看起来像一段没对齐的散字。
 * 2. **卡是实底**。半透明卡会把壁纸透进来，读成「一块模糊的洞」而不是卡。
 *
 * 于是现在：**一块卡包住「标题 + 若干行」**，每行仍各自可点。
 *
 * @param rows 由 [MonthDayAgendaModel.build] 组装好并按钟点排过序的行。
 * @param onAddCourse 空态卡里的「加课」入口。null = 只留说明文字。
 *   空态是用户最可能想「补点什么」的时刻：这一天什么都没排，说一句「这天没有
 *   安排」然后就没了 —— 手里有活儿要记的人还得自己回首页找加课入口。
 */
@Composable
fun MonthDayAgenda(
    date: LocalDateTime,
    rows: List<MonthAgendaRow>,
    onRowTap: (MonthAgendaRow) -> Unit,
    modifier: Modifier = Modifier,
    onAddCourse: (() -> Unit)? = null,
) {
    val ink = MonthPanelSurface.ink()
    MonthPanelCard(
        title = MonthPanelText.agendaTitle(date.monthValue, date.dayOfMonth),
        modifier = modifier,
        // 议程卡标题与内容之间是 12（概览卡是 10）：Dart 两份原件的实测值不同，
        // 所以由卡壳开一个参数，而不是在内容里再塞一个 Spacer 把两层间距叠起来。
        titleGap = MonthAgendaMetrics.TITLE_GAP.dp,
    ) {
        if (MonthDayAgendaModel.isEmpty(rows)) {
            EmptyDayBody(ink = ink, onAddCourse = onAddCourse)
        } else {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(MonthMetrics.ROW_GAP.dp),
            ) {
                for (row in rows) {
                    AgendaRow(row = row, ink = ink, onTap = { onRowTap(row) })
                }
            }
        }
    }
}

/** 选中日什么都没有：一句说明 + 一个加课入口（都在卡内，不再另起一张卡）。 */
@Composable
private fun EmptyDayBody(
    ink: Color,
    onAddCourse: (() -> Unit)?,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = MonthText.agendaEmpty.zh,
            style = MiuixTheme.textStyles.footnote1,
            color = MonthPanelSurface.muted(ink),
        )
        if (onAddCourse != null) {
            Spacer(Modifier.height(MonthAgendaMetrics.EMPTY_ACTION_GAP.dp))
            AddCourseAction(ink = ink, onTap = onAddCourse)
        }
    }
}

/** 卡内的加课小按钮（描边胶囊，不抢卡内其它行）。 */
@Composable
private fun AddCourseAction(
    ink: Color,
    onTap: () -> Unit,
) {
    val secondary = MonthPanelSurface.muted(ink)
    MonthPanelRow(
        onClick = onTap,
        cornerRadius = MonthAgendaMetrics.ACTION_RADIUS.dp,
    ) {
        Row(
            modifier = Modifier
                .border(
                    width = 1.dp,
                    color = ink.copy(alpha = MonthInk.HAIRLINE.toFloat()),
                    shape = RoundedCornerShape(MonthAgendaMetrics.ACTION_RADIUS.dp),
                )
                .padding(
                    horizontal = MonthAgendaMetrics.ACTION_PADDING_HORIZONTAL.dp,
                    vertical = MonthAgendaMetrics.ACTION_PADDING_VERTICAL.dp,
                ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = MiuixIcons.Add,
                contentDescription = null,
                tint = secondary,
                modifier = Modifier.size(MonthAgendaMetrics.ACTION_ICON_SIZE.dp),
            )
            Spacer(Modifier.width(MonthAgendaMetrics.ACTION_ICON_GAP.dp))
            Text(
                text = MonthPanelText.addCourse.zh,
                style = MiuixTheme.textStyles.footnote1,
                fontWeight = FontWeight.SemiBold,
                color = secondary,
                maxLines = 1,
            )
        }
    }
}

/**
 * 卡内的一行议程：色条 + 钟点 + 标题/副行 + 箭头。
 *
 * ⚠️ 它**不再是一张卡**（卡由外面那层提供）：所以这里只画水波纹与内容，
 * 自带一个可点区域保证每行仍能独立点击。
 */
@Composable
private fun AgendaRow(
    row: MonthAgendaRow,
    ink: Color,
    onTap: () -> Unit,
) {
    // 行首竖条：考试固定红、其余用课程/日程自身色（与网格色带同一套语义色）。
    val accent = if (row.kind == MonthAgendaKind.EXAM) {
        MonthPanelAccents.examInk()
    } else {
        parseHexColorOrFallback(
            hex = row.colorHex,
            fallback = MiuixTheme.colorScheme.primary,
        )
    }
    val secondary = MonthPanelSurface.muted(ink)

    MonthPanelRow(
        onClick = onTap,
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = MonthAgendaMetrics.ROW_RADIUS.dp,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = MonthAgendaMetrics.ROW_VERTICAL.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .width(MonthAgendaMetrics.ACCENT_WIDTH.dp)
                    .height(MonthAgendaMetrics.ACCENT_HEIGHT.dp)
                    .background(
                        color = accent,
                        shape = RoundedCornerShape(MonthAgendaMetrics.ACCENT_RADIUS.dp),
                    ),
            )
            Spacer(Modifier.width(MonthAgendaMetrics.ACCENT_GAP.dp))
            Box(modifier = Modifier.width(MonthAgendaMetrics.CLOCK_WIDTH.dp)) {
                Text(
                    // 钟点缺失（课程节次映射不到作息时间）→ 占位，不留空。
                    text = row.clockText ?: CLOCK_PLACEHOLDER,
                    style = MiuixTheme.textStyles.footnote2,
                    fontWeight = FontWeight.SemiBold,
                    color = secondary,
                    maxLines = 1,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = row.title,
                    style = MiuixTheme.textStyles.body2,
                    fontWeight = FontWeight.SemiBold,
                    color = ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                val subtitle = row.subtitle
                if (!subtitle.isNullOrEmpty()) {
                    Spacer(Modifier.height(MonthAgendaMetrics.SUBTITLE_GAP.dp))
                    Text(
                        text = subtitle,
                        style = MiuixTheme.textStyles.footnote1,
                        color = secondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Spacer(Modifier.width(MonthAgendaMetrics.CHEVRON_GAP.dp))
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = MonthPanelSurface.muted(ink, MonthInk.TERTIARY),
                modifier = Modifier.size(MonthAgendaMetrics.CHEVRON_SIZE.dp),
            )
        }
    }
}

/**
 * 钟点缺失时的占位。
 *
 * 不是文案、不进 ARB：它是「没有值」的排版符号（Dart 原件同样写死 `'--:--'`），
 * 换成任何语言都不变。
 */
private const val CLOCK_PLACEHOLDER = "--:--"
