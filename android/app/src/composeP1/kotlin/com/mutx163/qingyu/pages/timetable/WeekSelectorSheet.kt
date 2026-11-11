package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 周次选择弹层（Dart `lib/widgets/week_selector_picker_sheet.dart`，230 行）。
 *
 * ## 为什么重做（2026-10-31）
 *
 * 旧实现是「居中的 `Dialog` + 双层 16dp 内边距 + 5 列 + 只写数字 + 固定 220dp 高」，
 * 用户口径「看起来非常奇怪」。逐条对照 Dart 后发现 9 处走样，这里全部按 Dart 重写：
 *
 * | # | Dart（出处） | 旧实现 | 现在 |
 * |---|---|---|---|
 * | 1 | 底部弹层（`showHomeHyperosSheet`） | 居中 `Dialog` | `QingyuSheet`（底部弹层） |
 * | 2 | 内容内边距 `16/16/16/24`（`:47`） | `Card(padding 16)` + `Column(padding 16)` = 双层 | 由套件统一给（16 侧边 + 底部让位） |
 * | 3 | 标题 `选择周次`，17sp（`HyperosTokens.titleSize`）`sheetTitle` | `body1` 加粗 + 右上角关闭叉 | 17sp / w400 / 左对齐（交给套件标题行，见下节；无关闭叉——Dart 靠下拉/点外部收起） |
 * | 4 | 说明行「共 N 周」13sp（`:44` / `:64-72`），左右各再缩 16 | 无 | 有 |
 * | 5 | 网格 **4 列**，`mainAxisSpacing/crossAxisSpacing = 10`，`childAspectRatio = 1.55`（`:87-92`） | 5 列、间距 8、`height(220.dp)` 写死 | 4 列 / 间距 10 / 宽高比 1.55（高度随宽度走，不再写死） |
 * | 6 | 格子文案「第 N 周」（`:96` `goToWeekLabel`） | 只写数字 | 「第 N 周」 |
 * | 7 | 格子最小高 40、圆角 16（`HyperosMiuixButton.cornerRadius` 经 `clampCornerRadius`，`:150-155`） | 高约 36、圆角 8 | 宽高比 1.55 自然高 ≈54、圆角 16 |
 * | 8 | 三态配色（`:160-187`）：选中=主题色实底 + `onPrimary`；**本周**=主题色 12% + 主题色字 + 主题色描边；其余=中性底 | 选中/本周都用主题色，其余用卡片色、无描边 | 照 Dart 三态 |
 * | 9 | 浏览周 ≠ 本周时，底部追加整宽「回本周」按钮（`:109-117`） | 无 | 有 |
 *
 * ## 与 Dart 的两处已知差异
 *
 * - Dart 的列表限高是「屏高 × 0.42」并自带滚动；这里**不单独限高**：20 周 = 5 行，整块内容
 *   通常一屏放得下，超了由 [QingyuSheet] 的外层滚动接管（比在弹层里再套一层滚动稳）。
 * - Dart 的格子文案用 `FittedBox(scaleDown)` 兜窄屏；这里同样 `maxLines = 1` + 不换行，
 *   4 列在 360dp 屏上每格约 74dp、「第 20 周」≈60dp，放得下，所以不额外做缩放。
 *
 * ## 标题已收回套件标题行（2026-11-11）
 *
 * 之前是 `QingyuSheet(show, onDismissRequest)` **不传 `title`**、在正文顶部**自绘**一行
 * `headline1` 标题 + 8dp `Spacer`：miuix 那行空标题位（6 + 12dp）照旧占着，标题再叠在它
 * 下面，顶部白占一段。现在改为 `title = TimetableStrings.selectWeekTitle.text`，
 * **空档位由标题占用**，正文顶部不再多一层。
 *
 * 三处随之变化的数值（其余一律未动）：
 *
 * - **标题→说明行**：自绘时期 = 8dp `Spacer` + 说明行自带 8dp = **16dp**；现在 = miuix
 *   标题行行内下边距 12dp + 说明行自带 8dp = **20dp**（**+4dp**）。不补不扣：
 *   这 4dp 是 [QingyuSheetDefaults.TitleLineHeight] 里登记的上游缺口（发布版 16dp vs
 *   miuix 行内 12dp），补的话 54 个弹层顶部统一再抬 4dp。
 * - **标题行高**：自绘用 `headline1` 原样行高（平台默认 ≈1.35）；套件按发布版钉
 *   `20.4sp`（17sp × 1.2）。行更紧 1 像素级，属发布版口径。
 * - **标题颜色**：自绘用 `Color(QingyuTheme.primaryText(dark))`，套件标题用
 *   `MiuixTheme.colorScheme.onSurface`；后者在 `QingyuPageTheme` 里就填的是同一个表达式
 *   （`QingyuPageTheme.kt` 的 `qingyuLightColors` / `qingyuDarkColors`），**像素级相同**。
 *
 * @param show 是否显示。
 * @param availableWeeks 可选周次（Dart `settings.availableWeeks`）。
 * @param visibleWeek 当前正在浏览的周（Dart `weekPager.visibleWeek`）。
 * @param currentSemesterWeek 按开学日算出的真实本周；`null` = 算不出（学期未配置）。
 * @param onDismiss 关闭。
 * @param onSelect 选中某一周（Dart `jumpToWeek`）。
 */
@Composable
fun WeekSelectorSheet(
    show: Boolean,
    availableWeeks: List<Int>,
    visibleWeek: Int,
    currentSemesterWeek: Int?,
    onDismiss: () -> Unit,
    onSelect: (Int) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val accent = Color(QingyuTheme.primary(dark = dark))
    val onAccent = Color(QingyuTheme.onAccent(dark))
    val neutralCell = Color(QingyuTheme.secondary(dark))

    // Dart `:38-39`：只有「能算出本周」且「浏览的不是本周」时才出现回本周。
    val showBackToCurrent = currentSemesterWeek != null && visibleWeek != currentSemesterWeek

    QingyuSheet(
        show = show,
        onDismissRequest = onDismiss,
        // 标题交给套件标题行：它的口径就是发布版（17sp / w400 / 左对齐 / 行高 1.2，
        // 见 `QingyuSheetDefaults.TitleLineHeight`），不再在这里自绘一行 + 8dp 间距。
        title = TimetableStrings.selectWeekTitle.text,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // 标题已在套件标题行里（2026-11-11 收回），正文直接从说明行开始：
            // 标题→说明行 = miuix 标题行下边距 12dp + 说明行自带 8dp = 20dp
            // （自绘时期是 8dp Spacer + 8dp = 16dp，多 4dp；那 4dp 是套件里登记的上游缺口，不补）。

            // ── 说明行「共 N 周」（Dart `:59-74`：13sp 次要色，左右各再缩 16）──
            Text(
                text = TimetableStrings.availableWeeks(availableWeeks.size),
                style = MiuixTheme.textStyles.footnote1,
                color = secondaryText,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )
            Spacer(modifier = Modifier.height(16.dp))

            // ── 网格：4 列 / 间距 10 / 宽高比 1.55（Dart `:87-92`）──
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(GRID_SPACING),
            ) {
                availableWeeks.chunked(GRID_COLUMNS).forEach { rowWeeks ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(GRID_SPACING),
                    ) {
                        rowWeeks.forEach { week ->
                            WeekCell(
                                week = week,
                                selected = week == visibleWeek,
                                current = week == currentSemesterWeek,
                                accent = accent,
                                onAccent = onAccent,
                                neutral = neutralCell,
                                text = primaryText,
                                dark = dark,
                                modifier = Modifier.weight(1f),
                                onClick = { onSelect(week) },
                            )
                        }
                        // 末行不足 4 个时补占位，保持格子宽度与上面几行一致。
                        repeat(GRID_COLUMNS - rowWeeks.size) {
                            Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }
            }

            // ── 回本周（Dart `:109-117`：14dp 间距 + 整宽按钮）──
            if (showBackToCurrent) {
                Spacer(modifier = Modifier.height(14.dp))
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = TimetableStrings.backToCurrentWeekAction.text,
                    onClick = { onSelect(currentSemesterWeek) },
                )
            }
        }
    }
}

/**
 * 一格周次（Dart `_WeekSelectorCell` `:129-230`）。
 *
 * 三态：
 * - **选中**（正在浏览）：主题色实底 + `onPrimary` 字（`:162-177`）；
 * - **本周**（按开学日算出的真实周）：主题色 12% 底 + 主题色字 + 主题色描边（`:164-182`）；
 * - 其余：中性底 + 主墨色字，无描边。
 */
@Composable
private fun WeekCell(
    week: Int,
    selected: Boolean,
    current: Boolean,
    accent: Color,
    onAccent: Color,
    neutral: Color,
    text: Color,
    dark: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val background = when {
        selected -> accent
        current -> accent.copy(alpha = 0.12f)
        else -> neutral
    }
    val labelColor = when {
        selected -> onAccent
        current -> accent
        else -> text
    }
    // 本周的浅色井在浅底上会融掉，Dart 给它一圈主题色描边（`:181-182`）。
    val edge = if (current && !selected) {
        accent.copy(alpha = if (dark) 0.55f else 0.38f)
    } else {
        Color.Transparent
    }
    Box(
        modifier = modifier
            .aspectRatio(CELL_ASPECT_RATIO)
            .clip(RoundedCornerShape(CELL_CORNER))
            .background(background)
            .border(width = if (current && !selected) 1.dp else 0.dp, color = edge, shape = RoundedCornerShape(CELL_CORNER))
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = TimetableStrings.goToWeek(week),
            style = MiuixTheme.textStyles.body2,
            color = labelColor,
            maxLines = 1,
            overflow = TextOverflow.Clip,
            softWrap = false,
            textAlign = TextAlign.Center,
        )
    }
}

/** 网格列数（Dart `crossAxisCount = 4`，`:88`）。 */
private const val GRID_COLUMNS = 4

/** 格间距（Dart `mainAxisSpacing = crossAxisSpacing = 10`，`:90-91`）。 */
private val GRID_SPACING = 10.dp

/** 格子宽高比（Dart `childAspectRatio = 1.55`，`:91`）。 */
private const val CELL_ASPECT_RATIO = 1.55f

/** 格子圆角（Dart `clampCornerRadius(HyperosMiuixButton.cornerRadius = 16, minHeight = 40)` = 16）。 */
private val CELL_CORNER = 16.dp
